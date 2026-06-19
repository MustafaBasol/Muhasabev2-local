const { mkdtempSync, rmSync, existsSync } = require('fs');
const { tmpdir } = require('os');
const { join } = require('path');
const { spawn } = require('child_process');
const sqlite3 = require('sqlite3');

const root = join(__dirname, '..');
const entryCandidates = [
  join(root, 'dist', 'src', 'main.js'),
  join(root, 'dist', 'main.js'),
];
const entry = entryCandidates.find(existsSync);
if (!entry) {
  throw new Error('Build output not found. Run npm run build first.');
}

const workDir = mkdtempSync(join(tmpdir(), 'comptario-native-local-'));
const databasePath = join(workDir, 'comptario.db');
const port = 32000 + Math.floor(Math.random() * 1000);
const baseUrl = `http://127.0.0.1:${port}`;
const childEnv = {
  ...process.env,
  APP_EDITION: 'native-local',
  DATABASE_TYPE: 'sqlite',
  DATABASE_PATH: databasePath,
  NODE_ENV: 'production',
  PORT: String(port),
  JWT_SECRET: 'native-local-validation-jwt-secret-0123456789-abcdef',
  JWT_REFRESH_SECRET:
    'native-local-validation-refresh-secret-0123456789-abcdef',
  CSRF_SECRET: 'native-local-validation-csrf-secret-0123456789-abcdef',
  EMAIL_VERIFICATION_REQUIRED: 'false',
  MAIL_PROVIDER: 'log',
  STRIPE_ENABLED: 'false',
  TURNSTILE_SECRET_KEY: '',
  REDIS_HOST: '',
  CORS_ORIGINS: baseUrl,
};

let output = '';
const child = spawn(process.execPath, [entry], {
  cwd: root,
  env: childEnv,
  stdio: ['ignore', 'pipe', 'pipe'],
  windowsHide: true,
});
child.stdout.on('data', (chunk) => {
  output += chunk.toString();
});
child.stderr.on('data', (chunk) => {
  output += chunk.toString();
});

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const requestJson = async (path, init) => {
  const response = await fetch(`${baseUrl}${path}`, init);
  const text = await response.text();
  let body;
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { raw: text };
  }
  if (!response.ok) {
    throw new Error(
      `${init?.method || 'GET'} ${path} failed (${response.status}): ${text}`,
    );
  }
  return body;
};

const waitForHealth = async () => {
  for (let attempt = 0; attempt < 120; attempt += 1) {
    if (child.exitCode !== null) {
      throw new Error(`Backend exited early (${child.exitCode}).\n${output}`);
    }
    try {
      const response = await fetch(`${baseUrl}/api/health`);
      if (response.ok) {
        const text = await response.text();
        return {
          status: response.status,
          body: text,
        };
      }
    } catch {
      // Startup and first migration may take a few seconds.
    }
    await wait(500);
  }
  throw new Error(`Backend health check timed out.\n${output}`);
};

const readPragmas = () =>
  new Promise((resolve, reject) => {
    const database = new sqlite3.Database(databasePath);
    database.get('PRAGMA journal_mode', (error, row) => {
      database.close();
      if (error) return reject(error);
      resolve({ journalMode: row?.journal_mode });
    });
  });

const run = async () => {
  const health = await waitForHealth();
  const pragmas = await readPragmas();
  if (String(pragmas.journalMode).toLowerCase() !== 'wal') {
    throw new Error(`Unexpected SQLite PRAGMA settings: ${JSON.stringify(pragmas)}`);
  }
  const email = `native-${Date.now()}@example.com`;
  const registration = await requestJson('/api/auth/register', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      email,
      password: 'NativeLocal!Pass123456',
      firstName: 'Native',
      lastName: 'Local',
      companyName: 'Native Local Validation',
    }),
  });

  if (!registration.token || registration.tenant?.subscriptionPlan !== 'enterprise') {
    throw new Error('Registration did not create a native-local enterprise tenant.');
  }
  if (
    registration.tenant?.maxUsers !== -1 ||
    registration.tenant?.effectiveMaxUsers !== -1
  ) {
    throw new Error('Native-local plan limits were not disabled.');
  }

  const authHeaders = {
    authorization: `Bearer ${registration.token}`,
    'content-type': 'application/json',
  };
  const customer = await requestJson('/api/customers', {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      name: 'SQLite Validation Customer',
      email: 'sqlite-customer@example.com',
    }),
  });
  const customers = await requestJson('/api/customers', {
    headers: { authorization: `Bearer ${registration.token}` },
  });
  if (!customer.id || !customers.some((item) => item.id === customer.id)) {
    throw new Error('Customer create/read validation failed.');
  }

  console.log(
    JSON.stringify(
      {
        health,
        pragmas,
        databasePath,
        redisConfigured: false,
        registration: 'ok',
        nativeLocalPlan: 'ok',
        customerCreateRead: 'ok',
      },
      null,
      2,
    ),
  );
};

run()
  .catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    console.error(output);
    process.exitCode = 1;
  })
  .finally(async () => {
    child.kill();
    await wait(500);
    if (process.exitCode !== 1) {
      rmSync(workDir, { recursive: true, force: true });
    } else {
      console.error(`Validation database preserved for inspection: ${workDir}`);
    }
  });

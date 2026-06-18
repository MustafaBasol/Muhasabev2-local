/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string;
  readonly VITE_EMAIL_VERIFICATION_REQUIRED: string;
  readonly VITE_TURNSTILE_SITE_KEY: string;
  readonly VITE_CAPTCHA_DEV_BYPASS: string;
  readonly VITE_LOCAL_MODE: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

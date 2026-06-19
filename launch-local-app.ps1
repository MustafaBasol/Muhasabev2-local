[CmdletBinding()]
param()

# Legacy launcher name. Keep one implementation so all shortcuts use the same
# Docker prerequisite flow and customer-facing messages.
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $Root 'comptario-local.ps1')
exit $LASTEXITCODE

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$NodeExe,
    [Parameter(Mandatory = $true)]
    [string]$BackendRoot,
    [Parameter(Mandatory = $true)]
    [string]$StdoutLog,
    [Parameter(Mandatory = $true)]
    [string]$StderrLog
)

$ErrorActionPreference = 'Stop'
Set-Location $BackendRoot
& $NodeExe 'dist\src\main.js' 1>> $StdoutLog 2>> $StderrLog
exit $LASTEXITCODE


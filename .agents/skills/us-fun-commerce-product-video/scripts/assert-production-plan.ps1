param(
  [Parameter(Mandatory=$true)][string]$ProjectDirectory,
  [ValidateSet('planning','frames','video','jobs')][string]$Stage = 'planning'
)
$ErrorActionPreference = 'Stop'
$nodeCommand = Get-Command node -ErrorAction SilentlyContinue
$nodePath = if ($null -ne $nodeCommand) { $nodeCommand.Source } else {
  Join-Path ([Environment]::GetFolderPath('UserProfile')) '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe'
}
if (-not (Test-Path -LiteralPath $nodePath -PathType Leaf)) { throw '未找到 Node.js；请使用 Codex 自带 Node.js 运行库。' }
$output = & $nodePath (Join-Path $PSScriptRoot 'production-plan.mjs') validate --project $ProjectDirectory --stage $Stage 2>&1
if ($LASTEXITCODE -ne 0) { throw (($output | ForEach-Object { [string]$_ }) -join "`n") }
$output

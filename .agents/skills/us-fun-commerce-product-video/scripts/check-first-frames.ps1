param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectDirectory
)

$ErrorActionPreference = 'Stop'
try {
  $null = & (Join-Path $PSScriptRoot 'assert-production-plan.ps1') -ProjectDirectory $ProjectDirectory -Stage frames
  [pscustomobject]@{status='ready_for_video'; ready=$true; missing=@()} | ConvertTo-Json -Depth 4
} catch {
  [pscustomobject]@{status='blocked'; ready=$false; missing=@($_.Exception.Message)} | ConvertTo-Json -Depth 4
}

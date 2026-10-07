param(
  [Parameter(Mandatory=$true)][string]$ProjectDirectory,
  [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$UserConfirmation
)
$ErrorActionPreference = 'Stop'
# Call only after the user has reviewed these images and explicitly said to continue.
$validation = & (Join-Path $PSScriptRoot 'assert-production-plan.ps1') -ProjectDirectory $ProjectDirectory -Stage planning | ConvertFrom-Json
$plan = Get-Content -LiteralPath (Join-Path $ProjectDirectory 'production-plan.json') -Raw -Encoding utf8 | ConvertFrom-Json
$config = $plan.production
$expected = @('S01','S02','S03','S04','S05')
if (@($plan.shots).Count -ne 5 -or @(Compare-Object $expected @($plan.shots.id | Sort-Object -Unique)).Count) { throw '必须包含 S01-S05。' }
$frames = foreach ($job in $plan.shots) {
  $frame = [string]$job.first_frame
  if (-not [IO.Path]::IsPathRooted($frame)) { $frame = Join-Path $ProjectDirectory $frame }
  [pscustomobject]@{shot=$job.id; path=(Resolve-Path -LiteralPath $frame).Path; sha256=(Get-FileHash -LiteralPath $frame -Algorithm SHA256).Hash}
}
[pscustomobject]@{status='approved'; approved_at=(Get-Date).ToString('o'); user_confirmation=$UserConfirmation; model=$config.model; resolution=$config.resolution; frame_plan_sha256=$validation.frame_plan_sha256; frames=@($frames)} |
  ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $ProjectDirectory 'first-frame-review.json') -Encoding utf8

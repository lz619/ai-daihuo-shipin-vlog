param(
  [string]$ProjectsDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'projects'),
  [switch]$Submit,
  [ValidateSet('720P', '1080P', '4K')][string]$Resolution,
  [ValidateRange(5, 60)][int]$PollIntervalSeconds = 10,
  [ValidateRange(1, 120)][int]$TimeoutMinutes = 30
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $ProjectsDirectory -PathType Container)) { throw "项目根目录不存在：$ProjectsDirectory" }
$checkScript = Join-Path $PSScriptRoot 'check-first-frames.ps1'
$runScript = Join-Path $PSScriptRoot 'run-buming-omni-1.1-batch.ps1'
if (-not (Test-Path -LiteralPath $checkScript) -or -not (Test-Path -LiteralPath $runScript)) { throw '缺少就绪检查或视频批处理脚本。' }

$report = @()
$projects = @(Get-ChildItem -LiteralPath $ProjectsDirectory -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'image-to-video-jobs.json') })
foreach ($project in $projects) {
  $ready = & $checkScript -ProjectDirectory $project.FullName | ConvertFrom-Json
  if ($ready.status -ne 'ready_for_video') {
    $report += [pscustomobject]@{ sku = $project.Name; status = $ready.status; submitted = $false; detail = $ready }
    continue
  }
  if (-not $Submit) {
    $report += [pscustomobject]@{ sku = $project.Name; status = 'ready_for_video'; submitted = $false; detail = '已通过检查；使用 -Submit 才会产生付费图生视频任务。' }
    continue
  }
  try {
    $runParams = @{ ProjectDirectory = $project.FullName; PollIntervalSeconds = $PollIntervalSeconds; TimeoutMinutes = $TimeoutMinutes }
    if (-not [string]::IsNullOrWhiteSpace($Resolution)) { $runParams.Resolution = $Resolution }
    $result = & $runScript @runParams | ConvertFrom-Json
    $report += [pscustomobject]@{ sku = $project.Name; status = $result.status; submitted = $true; detail = $result }
  } catch {
    $report += [pscustomobject]@{ sku = $project.Name; status = 'submission_failed'; submitted = $true; detail = $_.Exception.Message }
  }
}
[pscustomobject]@{ mode = $(if ($Submit) { 'submit' } else { 'check_only' }); projects = $report } | ConvertTo-Json -Depth 12

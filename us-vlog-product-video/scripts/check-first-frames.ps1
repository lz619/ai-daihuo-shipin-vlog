param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectDirectory
)

$ErrorActionPreference = 'Stop'
$jobsPath = Join-Path $ProjectDirectory 'image-to-video-jobs.json'
if (-not (Test-Path -LiteralPath $jobsPath)) {
  [pscustomobject]@{ status = 'waiting_for_planning'; ready = $false; missing = @('尚未生成 image-to-video-jobs.json') } | ConvertTo-Json -Depth 4
  exit 0
}

$configuration = Get-Content -LiteralPath $jobsPath -Raw -Encoding utf8 | ConvertFrom-Json
$jobs = @($configuration.jobs)
if ($jobs.Count -ne 5) { throw 'image-to-video-jobs.json 必须包含 S01-S05 共五个镜头。' }

$missing = @()
foreach ($job in $jobs) {
  if ([string]::IsNullOrWhiteSpace([string]$job.first_frame)) {
    $missing += "$($job.shot)：未配置首帧路径"
    continue
  }
  $framePath = if ([System.IO.Path]::IsPathRooted([string]$job.first_frame)) { [string]$job.first_frame } else { Join-Path $ProjectDirectory ([string]$job.first_frame) }
  if (-not (Test-Path -LiteralPath $framePath)) { $missing += "$($job.shot)：缺少 $framePath" }
}

[pscustomobject]@{
  status = if ($missing.Count -eq 0) { 'ready_for_video' } else { 'waiting_for_images' }
  ready = ($missing.Count -eq 0)
  missing = $missing
} | ConvertTo-Json -Depth 4

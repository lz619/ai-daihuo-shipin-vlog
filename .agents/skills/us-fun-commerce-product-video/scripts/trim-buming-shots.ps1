param(
  [Parameter(Mandatory = $true)][string]$ProjectDirectory,
  [string]$FfmpegPath
)

$ErrorActionPreference = 'Stop'

function Resolve-Executable {
  param([string]$RequestedPath, [string]$Name)
  if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
    if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) { throw "指定的 $Name 不存在：$RequestedPath" }
    return (Resolve-Path -LiteralPath $RequestedPath).Path
  }
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($null -ne $command) { return $command.Source }
  $wingetPackages = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
  if (Test-Path -LiteralPath $wingetPackages) {
    $installed = Get-ChildItem -LiteralPath $wingetPackages -Directory -Filter 'Gyan.FFmpeg*' -ErrorAction SilentlyContinue |
      ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter "$Name.exe" -File -Recurse -ErrorAction SilentlyContinue } |
      Select-Object -First 1
    if ($null -ne $installed) { return $installed.FullName }
  }
  throw "未找到 $Name。请安装 FFmpeg，或指定可用程序路径。"
}

if (-not (Test-Path -LiteralPath $ProjectDirectory -PathType Container)) { throw "SKU 项目文件夹不存在：$ProjectDirectory" }
$null = & (Join-Path $PSScriptRoot 'assert-production-plan.ps1') -ProjectDirectory $ProjectDirectory -Stage jobs
$jobsPath = Join-Path $ProjectDirectory 'image-to-video-jobs.json'
$statePath = Join-Path $ProjectDirectory 'video-task-state.json'
if (-not (Test-Path -LiteralPath $jobsPath) -or -not (Test-Path -LiteralPath $statePath)) { throw '缺少视频任务配置或已完成任务状态。' }
$jobs = @( (Get-Content -LiteralPath $jobsPath -Raw -Encoding utf8 | ConvertFrom-Json).jobs )
$state = Get-Content -LiteralPath $statePath -Raw -Encoding utf8 | ConvertFrom-Json
if ($jobs.Count -ne 5) { throw '任务配置必须包含 S01-S05 五个镜头。' }
$totalEditSeconds = 0.0
foreach ($job in $jobs) {
  $shot = [string]$job.shot
  $editSeconds = [double]$job.edit_duration_seconds
  $startSeconds = [double]$job.trim_start_seconds
  if ($editSeconds -le 0) { throw "$shot 缺少正数 edit_duration_seconds。" }
  $task = @($state.tasks | Where-Object { $_.shot -eq $shot -and $_.fingerprint -eq $job.request_fingerprint -and $_.state -eq 'success' -and -not [string]::IsNullOrWhiteSpace([string]$_.local_video) } | Sort-Object submitted_at -Descending | Select-Object -First 1)
  if ($task.Count -eq 0 -or -not (Test-Path -LiteralPath $task[0].local_video -PathType Leaf)) { throw "$shot 没有成功下载的源视频。" }
  $source = Get-Item -LiteralPath $task[0].local_video
  $sourceDuration = [double]$job.duration_seconds
  if ($startSeconds -lt 0 -or ($startSeconds + $editSeconds) -gt $sourceDuration) { throw "$shot 的剪辑区间超出生成时长。" }
  $totalEditSeconds += $editSeconds
}
if ($totalEditSeconds -lt 15 -or $totalEditSeconds -gt 20) { throw "五镜头剪辑保留时长合计 $totalEditSeconds 秒，不在 15–20 秒范围。" }

$ffmpeg = Resolve-Executable -RequestedPath $FfmpegPath -Name 'ffmpeg'
$sourceDirectory = Join-Path $ProjectDirectory 'videos'
$preparedDirectory = Join-Path $sourceDirectory 'edit-ready'
New-Item -ItemType Directory -Path $preparedDirectory -Force | Out-Null
$outputs = @()
foreach ($shot in @('S01', 'S02', 'S03', 'S04', 'S05')) {
  $job = @($jobs | Where-Object { $_.shot -eq $shot })[0]
  $task = @($state.tasks | Where-Object { $_.shot -eq $shot -and $_.fingerprint -eq $job.request_fingerprint -and $_.state -eq 'success' -and -not [string]::IsNullOrWhiteSpace([string]$_.local_video) } | Sort-Object submitted_at -Descending | Select-Object -First 1)[0]
  $source = Get-Item -LiteralPath $task.local_video
  $outputPath = Join-Path $preparedDirectory "$shot.mp4"
  & $ffmpeg -hide_banner -loglevel error -y -i $source.FullName -ss ([string][double]$job.trim_start_seconds) -t ([string]$job.edit_duration_seconds) -map 0:v:0 -map '0:a?' -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart $outputPath
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputPath) -or (Get-Item -LiteralPath $outputPath).Length -eq 0) { throw "修剪 $shot 失败。" }
  $outputs += [pscustomobject]@{ shot = $shot; source = $source.FullName; output = $outputPath; edit_duration_seconds = [double]$job.edit_duration_seconds }
}
[pscustomobject]@{ status = 'trimmed'; total_edit_duration_seconds = $totalEditSeconds; prepared_directory = $preparedDirectory; shots = $outputs } | ConvertTo-Json -Depth 6

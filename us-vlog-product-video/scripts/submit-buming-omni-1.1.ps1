param(
  [Parameter(Mandatory = $true)][string]$ProjectDirectory,
  [ValidateSet('720P', '1080P', '4K')][string]$Resolution,
  [ValidateSet('S01', 'S02', 'S03', 'S04', 'S05')][string[]]$Shots = @('S01', 'S02', 'S03', 'S04', 'S05'),
  [switch]$DryRun,
  [switch]$ForceResubmit
)

$ErrorActionPreference = 'Stop'

function Get-BumingApiKey {
  $key = [Environment]::GetEnvironmentVariable('BUMING_API_KEY', 'Process')
  if ([string]::IsNullOrWhiteSpace($key)) { $key = [Environment]::GetEnvironmentVariable('BUMING_API_KEY', 'User') }
  if ([string]::IsNullOrWhiteSpace($key)) { $key = [Environment]::GetEnvironmentVariable('BUMING_API_KEY', 'Machine') }
  if ([string]::IsNullOrWhiteSpace($key)) {
    $secretFile = Join-Path (Split-Path -Parent $PSScriptRoot) '.secrets\buming-api-key.txt'
    if (Test-Path -LiteralPath $secretFile) { $key = (Get-Content -LiteralPath $secretFile -Raw).Trim() }
  }
  if ([string]::IsNullOrWhiteSpace($key)) { throw '未找到不鸣 AI API 密钥。请设置 BUMING_API_KEY，或创建 .secrets\buming-api-key.txt。' }
  $key
}

function Convert-FrameToDataUrl {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "找不到首帧：$Path" }
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -gt 10MB) { throw "首帧超过接口的 10MB 单图默认限制：$Path" }
  $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
  if ($extension -eq '.jpg' -or $extension -eq '.jpeg') { $mime = 'image/jpeg' }
  elseif ($extension -eq '.webp') { $mime = 'image/webp' }
  else { $mime = 'image/png' }
  "data:$mime;base64," + [Convert]::ToBase64String($bytes)
}

function Get-JobFingerprint {
  param([object]$Job, [string]$FramePath, [string]$FinalResolution)
  $source = "$($Job.shot)|$([System.IO.Path]::GetFullPath($FramePath))|$($Job.duration_seconds)|$FinalResolution|$($Job.prompt)"
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { (([System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($source))) -replace '-', '')).ToLowerInvariant() }
  finally { $sha.Dispose() }
}

function Read-TaskState {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]@{ schema_version = 1; updated_at = $null; tasks = @() } }
  try {
    $state = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
    if ($null -eq $state.tasks) { $state | Add-Member -NotePropertyName tasks -NotePropertyValue @() }
    $state
  } catch { throw "任务状态文件无法读取：$Path。$($_.Exception.Message)" }
}

function Save-TaskState {
  param([object]$State, [string]$Path)
  $State.updated_at = (Get-Date).ToString('o')
  $State | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding utf8
}

if (-not (Test-Path -LiteralPath $ProjectDirectory -PathType Container)) { throw "SKU 项目文件夹不存在：$ProjectDirectory" }
$jobsPath = Join-Path $ProjectDirectory 'image-to-video-jobs.json'
if (-not (Test-Path -LiteralPath $jobsPath)) { throw "尚未生成图生视频任务文件：$jobsPath" }
$jobConfig = Get-Content -LiteralPath $jobsPath -Raw -Encoding utf8 | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$jobConfig.model)) { throw '任务文件缺少 model。' }
if ($jobConfig.aspect_ratio -ne '9:16') { throw "当前自动化仅支持竖屏 9:16，任务文件写的是：$($jobConfig.aspect_ratio)" }
$finalResolution = if ([string]::IsNullOrWhiteSpace($Resolution)) { [string]$jobConfig.resolution } else { $Resolution }
if ($finalResolution -notin @('720P', '1080P', '4K')) { throw "任务文件中的分辨率无效：$finalResolution" }
$allJobs = @($jobConfig.jobs)
$shotNames = @($allJobs | ForEach-Object { [string]$_.shot })
$missingRequiredShots = @(@('S01','S02','S03','S04','S05') | Where-Object { $_ -notin $shotNames })
if ($allJobs.Count -ne 5 -or (@($shotNames | Sort-Object -Unique)).Count -ne 5 -or $missingRequiredShots.Count -gt 0) { throw '任务文件必须各包含一次 S01 至 S05。' }
$selectedJobs = @($allJobs | Where-Object { [string]$_.shot -in $Shots })
if ($selectedJobs.Count -ne $Shots.Count) { throw '至少有一个指定镜头不在任务文件中。' }

$prepared = foreach ($job in $selectedJobs) {
  if ([string]::IsNullOrWhiteSpace([string]$job.prompt) -or [string]::IsNullOrWhiteSpace([string]$job.first_frame)) { throw "镜头 $($job.shot) 缺少提示词或首帧。" }
  $duration = [int]$job.duration_seconds
  if ($duration -lt 3 -or $duration -gt 10) { throw "镜头 $($job.shot) 时长必须为 3 至 10 秒。" }
  $framePath = [string]$job.first_frame
  if (-not [System.IO.Path]::IsPathRooted($framePath)) { $framePath = Join-Path $ProjectDirectory $framePath }
  [pscustomobject]@{ job = $job; frame_path = [System.IO.Path]::GetFullPath($framePath); fingerprint = Get-JobFingerprint -Job $job -FramePath $framePath -FinalResolution $finalResolution }
}
if ($DryRun) {
  [pscustomobject]@{ status = 'dry_run'; project = [System.IO.Path]::GetFullPath($ProjectDirectory); model = $jobConfig.model; resolution = $finalResolution; jobs = @($prepared | ForEach-Object { [pscustomobject]@{ shot = $_.job.shot; duration_seconds = $_.job.duration_seconds; first_frame = $_.frame_path; prompt_is_chinese = ($_.job.prompt -match '[\u4e00-\u9fff]'); ready = (Test-Path -LiteralPath $_.frame_path) } }) } | ConvertTo-Json -Depth 6
  exit 0
}

$headers = @{ Authorization = "Bearer $(Get-BumingApiKey)" }
$taskStatePath = Join-Path $ProjectDirectory 'video-task-state.json'
$taskState = Read-TaskState -Path $taskStatePath
$taskList = [System.Collections.ArrayList]@($taskState.tasks)
$results = @()
foreach ($item in $prepared) {
  $job = $item.job
  $existing = @($taskList | Where-Object { $_.shot -eq $job.shot -and $_.fingerprint -eq $item.fingerprint -and $_.state -in @('submitted','running','success') } | Select-Object -First 1)
  if ($existing.Count -gt 0 -and -not $ForceResubmit) {
    $results += [pscustomobject]@{ shot = $job.shot; submitted = $true; existing = $true; task_id = $existing[0].task_id; state = $existing[0].state; local_video = $existing[0].local_video; fingerprint = $item.fingerprint }
    continue
  }
  try {
    $body = @{ model = $jobConfig.model; params = @{ aspect_ratio = $jobConfig.aspect_ratio; resolution = $finalResolution; duration = [string]$job.duration_seconds; images = @((Convert-FrameToDataUrl -Path $item.frame_path)) }; prompt = [string]$job.prompt } | ConvertTo-Json -Depth 8 -Compress
    $response = Invoke-RestMethod -Uri 'https://api.lk888.ai/v1/media/generate' -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $body
    $taskId = [string]$response.task_id
    if ([string]::IsNullOrWhiteSpace($taskId) -and $null -ne $response.data) { $taskId = [string]$response.data.task_id }
    if ([string]::IsNullOrWhiteSpace($taskId)) { throw '接口没有返回 task_id。' }
    $taskList.Add([pscustomobject]@{ shot = $job.shot; task_id = $taskId; fingerprint = $item.fingerprint; state = 'submitted'; first_frame = $item.frame_path; duration_seconds = $job.duration_seconds; resolution = $finalResolution; submitted_at = (Get-Date).ToString('o'); local_video = $null }) | Out-Null
    $results += [pscustomobject]@{ shot = $job.shot; submitted = $true; existing = $false; task_id = $taskId; fingerprint = $item.fingerprint }
  } catch { $results += [pscustomobject]@{ shot = $job.shot; submitted = $false; existing = $false; task_id = $null; error = $_.Exception.Message; fingerprint = $item.fingerprint } }
}
$taskState.tasks = @($taskList)
Save-TaskState -State $taskState -Path $taskStatePath
$results | ConvertTo-Json -Depth 6

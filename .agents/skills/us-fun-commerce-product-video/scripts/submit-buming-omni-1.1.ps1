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
  # The canonical compiler fingerprints generation inputs (not local edit times).
  # assert-production-plan verifies this value before any API call.
  [string]$Job.request_fingerprint
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
$null = & (Join-Path $PSScriptRoot 'assert-production-plan.ps1') -ProjectDirectory $ProjectDirectory -Stage jobs
$jobsPath = Join-Path $ProjectDirectory 'image-to-video-jobs.json'
if (-not (Test-Path -LiteralPath $jobsPath)) { throw "尚未生成图生视频任务文件：$jobsPath" }
$jobConfig = Get-Content -LiteralPath $jobsPath -Raw -Encoding utf8 | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$jobConfig.model)) { throw '任务文件缺少 model。' }
if ([string]$jobConfig.model -ne 'omni-1.1') { throw "当前提交脚本仅适配不鸣 AI Omni 1.1，不会调用其他模型：$($jobConfig.model)" }
if ($jobConfig.aspect_ratio -ne '9:16') { throw "当前自动化仅支持竖屏 9:16，任务文件写的是：$($jobConfig.aspect_ratio)" }
$finalResolution = if ([string]::IsNullOrWhiteSpace($Resolution)) { [string]$jobConfig.resolution } else { $Resolution }
if ($finalResolution -notin @('720P', '1080P', '4K')) { throw "任务文件中的分辨率无效：$finalResolution" }
if ($finalResolution -ne $jobConfig.resolution) { throw '请先把用户选择的分辨率写入任务文件及首帧确认记录，不允许临时覆盖。' }
$allJobs = @($jobConfig.jobs)
$shotNames = @($allJobs | ForEach-Object { [string]$_.shot })
$missingRequiredShots = @(@('S01','S02','S03','S04','S05') | Where-Object { $_ -notin $shotNames })
if ($allJobs.Count -ne 5 -or (@($shotNames | Sort-Object -Unique)).Count -ne 5 -or $missingRequiredShots.Count -gt 0) { throw '任务文件必须各包含一次 S01 至 S05。' }
$totalEditSeconds = 0.0
foreach ($job in $allJobs) {
  $editSeconds = [double]$job.edit_duration_seconds
  $startSeconds = [double]$job.trim_start_seconds
  if ($editSeconds -le 0 -or $startSeconds -lt 0 -or ($startSeconds + $editSeconds) -gt [double]$job.duration_seconds) { throw "$($job.shot)：剪辑起点/时长不合法，必须在生成时长内。" }
  if ([string]::IsNullOrWhiteSpace([string]$job.dialogue)) { throw "$($job.shot)：缺少英语口播。" }
  $totalEditSeconds += $editSeconds
}
if ($totalEditSeconds -lt 15 -or $totalEditSeconds -gt 20) { throw '最终剪辑时长必须合计 15–20 秒。' }
$selectedJobs = @($allJobs | Where-Object { [string]$_.shot -in $Shots })
if ($selectedJobs.Count -ne $Shots.Count) { throw '至少有一个指定镜头不在任务文件中。' }

$prepared = foreach ($job in $selectedJobs) {
  if ([string]::IsNullOrWhiteSpace([string]$job.prompt) -or [string]::IsNullOrWhiteSpace([string]$job.first_frame)) { throw "镜头 $($job.shot) 缺少提示词或首帧。" }
  $duration = [int]$job.duration_seconds
  if ($duration -lt 3 -or $duration -gt 10) { throw "镜头 $($job.shot) 时长必须为 3 至 10 秒。" }
  $framePath = [string]$job.first_frame
  if (-not [System.IO.Path]::IsPathRooted($framePath)) { $framePath = Join-Path $ProjectDirectory $framePath }
  if (-not (Test-Path -LiteralPath $framePath -PathType Leaf)) { throw "首帧不存在：$framePath" }
  if ((Get-Item -LiteralPath $framePath).Length -gt 10MB) { throw "首帧超过 10MB：$framePath" }
  [pscustomobject]@{ job = $job; frame_path = [System.IO.Path]::GetFullPath($framePath); fingerprint = Get-JobFingerprint -Job $job -FramePath $framePath -FinalResolution $finalResolution }
}
$readiness = & (Join-Path $PSScriptRoot 'check-first-frames.ps1') -ProjectDirectory $ProjectDirectory | ConvertFrom-Json
if ($DryRun) {
  [pscustomobject]@{ status = 'dry_run'; ready = $readiness.ready; blockers = $readiness.missing; project = [System.IO.Path]::GetFullPath($ProjectDirectory); model = $jobConfig.model; resolution = $finalResolution; jobs = @($prepared | ForEach-Object { [pscustomobject]@{ shot = $_.job.shot; duration_seconds = $_.job.duration_seconds; first_frame = $_.frame_path; prompt_is_chinese = ($_.job.prompt -match '[\u4e00-\u9fff]'); ready = (Test-Path -LiteralPath $_.frame_path) } }) } | ConvertTo-Json -Depth 6
  exit 0
}
if (-not $readiness.ready) { throw ($readiness.missing -join '；') }

$headers = @{ Authorization = "Bearer $(Get-BumingApiKey)" }
$taskStatePath = Join-Path $ProjectDirectory 'video-task-state.json'
$taskState = Read-TaskState -Path $taskStatePath
$taskList = [System.Collections.ArrayList]@($taskState.tasks)
$results = @()
foreach ($item in $prepared) {
  $job = $item.job
  $existing = @($taskList | Where-Object { $_.shot -eq $job.shot -and $_.fingerprint -eq $item.fingerprint } | Select-Object -Last 1)
  if ($existing.Count -gt 0 -and -not $ForceResubmit) {
    if ($existing[0].state -notin @('submitted','running','success')) {
      $results += [pscustomobject]@{shot=$job.shot; submitted=$false; task_id=$existing[0].task_id; error='该请求已失败或提交结果不明，保留记录，禁止自动重复扣费。'}
      continue
    }
    $results += [pscustomobject]@{ shot = $job.shot; submitted = $true; existing = $true; task_id = $existing[0].task_id; state = $existing[0].state; local_video = $existing[0].local_video; fingerprint = $item.fingerprint }
    continue
  }
  $body = @{ model = $jobConfig.model; params = @{ aspect_ratio = $jobConfig.aspect_ratio; resolution = $finalResolution; duration = [string]$job.duration_seconds; images = @((Convert-FrameToDataUrl -Path $item.frame_path)) }; prompt = [string]$job.prompt } | ConvertTo-Json -Depth 8 -Compress
  $entry = [pscustomobject]@{ shot=$job.shot; task_id=$null; fingerprint=$item.fingerprint; state='submitting'; first_frame=$item.frame_path; duration_seconds=$job.duration_seconds; resolution=$finalResolution; submitted_at=(Get-Date).ToString('o'); local_video=$null }
  $taskList.Add($entry) | Out-Null
  $taskState.tasks = @($taskList)
  Save-TaskState -State $taskState -Path $taskStatePath
  try {
    $response = Invoke-RestMethod -Uri 'https://api.lk888.ai/v1/media/generate' -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $body -TimeoutSec 60
    $taskId = [string]$response.task_id
    if ([string]::IsNullOrWhiteSpace($taskId) -and $null -ne $response.data) { $taskId = [string]$response.data.task_id }
    if ([string]::IsNullOrWhiteSpace($taskId)) { throw '接口没有返回 task_id。' }
    $entry.task_id = $taskId
    $entry.state = 'submitted'
    Save-TaskState -State $taskState -Path $taskStatePath
    $results += [pscustomobject]@{ shot = $job.shot; submitted = $true; existing = $false; task_id = $taskId; fingerprint = $item.fingerprint }
  } catch {
    $entry.state = 'submission_unknown'
    Save-TaskState -State $taskState -Path $taskStatePath
    $results += [pscustomobject]@{ shot = $job.shot; submitted = $false; existing = $false; task_id = $entry.task_id; error = '提交响应未能确认，已记录请求；先核对原任务，不能自动重复提交。'; fingerprint = $item.fingerprint }
  }
}
$taskState.tasks = @($taskList)
Save-TaskState -State $taskState -Path $taskStatePath
$results | ConvertTo-Json -Depth 6

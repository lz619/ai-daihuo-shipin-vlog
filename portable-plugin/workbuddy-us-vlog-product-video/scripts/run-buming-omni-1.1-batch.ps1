param(
  [Parameter(Mandatory = $true)][string]$ProjectDirectory,
  [ValidateSet('720P', '1080P', '4K')][string]$Resolution,
  [ValidateRange(5, 60)][int]$PollIntervalSeconds = 10,
  [ValidateRange(1, 120)][int]$TimeoutMinutes = 30,
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

function Get-NextVideoPath {
  param([string]$VideoDirectory, [string]$Shot)
  $basePath = Join-Path $VideoDirectory "$Shot.mp4"
  if (-not (Test-Path -LiteralPath $basePath)) { return $basePath }
  $escapedShot = [regex]::Escape($Shot)
  $versions = Get-ChildItem -LiteralPath $VideoDirectory -File -Filter "$Shot-v*.mp4" | Where-Object { $_.Name -match "^$escapedShot-v(?<version>\d+)\.mp4$" } | ForEach-Object { [int]([regex]::Match($_.Name, "^$escapedShot-v(?<version>\d+)\.mp4$").Groups['version'].Value) }
  $nextVersion = if ($versions) { (($versions | Measure-Object -Maximum).Maximum + 1) } else { 2 }
  Join-Path $VideoDirectory ("$Shot-v$nextVersion.mp4")
}

function Update-TaskState {
  param([string]$Path, [string]$TaskId, [string]$State, [string]$LocalVideo)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $data = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
  foreach ($task in @($data.tasks | Where-Object { $_.task_id -eq $TaskId })) {
    $task.state = $State
    if (-not [string]::IsNullOrWhiteSpace($LocalVideo)) { $task.local_video = $LocalVideo }
    $task.updated_at = (Get-Date).ToString('o')
  }
  $data.updated_at = (Get-Date).ToString('o')
  $data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding utf8
}

if (-not (Test-Path -LiteralPath $ProjectDirectory -PathType Container)) { throw "SKU 项目文件夹不存在：$ProjectDirectory" }
$submitScript = Join-Path $PSScriptRoot 'submit-buming-omni-1.1.ps1'
$assembleScript = Join-Path $PSScriptRoot 'assemble-final-video.ps1'
if (-not (Test-Path -LiteralPath $submitScript) -or -not (Test-Path -LiteralPath $assembleScript)) { throw '缺少提交或成片拼接脚本。' }
if ($DryRun) {
  $dryRunParams = @{ ProjectDirectory = $ProjectDirectory; DryRun = $true }
  if (-not [string]::IsNullOrWhiteSpace($Resolution)) { $dryRunParams.Resolution = $Resolution }
  & $submitScript @dryRunParams
  exit $LASTEXITCODE
}

$submitParams = @{ ProjectDirectory = $ProjectDirectory; ForceResubmit = $ForceResubmit }
if (-not [string]::IsNullOrWhiteSpace($Resolution)) { $submitParams.Resolution = $Resolution }
$rawSubmission = & $submitScript @submitParams
$jobs = @($rawSubmission | ConvertFrom-Json)
$rejected = @($jobs | Where-Object { -not $_.submitted -or [string]::IsNullOrWhiteSpace([string]$_.task_id) })
if ($rejected.Count -gt 0) { throw "以下镜头未能提交：$($rejected.shot -join '、')" }

$videoDirectory = Join-Path $ProjectDirectory 'videos'
if (-not (Test-Path -LiteralPath $videoDirectory)) { New-Item -ItemType Directory -Path $videoDirectory -Force | Out-Null }
$taskStatePath = Join-Path $ProjectDirectory 'video-task-state.json'
$headers = @{ Authorization = "Bearer $(Get-BumingApiKey)" }
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$pending = @{}; $completed = @(); $failed = @()
foreach ($job in $jobs) {
  if ($job.existing -eq $true -and $job.state -eq 'success' -and -not [string]::IsNullOrWhiteSpace([string]$job.local_video) -and (Test-Path -LiteralPath $job.local_video)) {
    $completed += [pscustomobject]@{ shot = $job.shot; task_id = $job.task_id; video = $job.local_video; reused = $true }
  } else { $pending[[string]$job.task_id] = $job }
}

while ($pending.Count -gt 0 -and (Get-Date) -lt $deadline) {
  foreach ($taskId in @($pending.Keys)) {
    $job = $pending[$taskId]
    try {
      $status = Invoke-RestMethod -Uri "https://api.lk888.ai/v1/media/status?task_id=$taskId" -Headers $headers -Method Get
      if ($status.is_final -ne $true) { Update-TaskState -Path $taskStatePath -TaskId $taskId -State 'running' -LocalVideo $null; continue }
      $pending.Remove($taskId)
      if ($status.state -eq 'success' -and -not [string]::IsNullOrWhiteSpace([string]$status.result_url)) {
        $outputPath = Get-NextVideoPath -VideoDirectory $videoDirectory -Shot $job.shot
        Invoke-WebRequest -Uri $status.result_url -OutFile $outputPath
        if (-not (Test-Path -LiteralPath $outputPath) -or (Get-Item -LiteralPath $outputPath).Length -eq 0) { throw "下载结果为空：$($job.shot)" }
        Update-TaskState -Path $taskStatePath -TaskId $taskId -State 'success' -LocalVideo $outputPath
        $completed += [pscustomobject]@{ shot = $job.shot; task_id = $taskId; video = $outputPath }
      } else {
        Update-TaskState -Path $taskStatePath -TaskId $taskId -State 'failed' -LocalVideo $null
        $failed += [pscustomobject]@{ shot = $job.shot; task_id = $taskId; error = [string]$status.error }
      }
    } catch {
      $pending.Remove($taskId)
      Update-TaskState -Path $taskStatePath -TaskId $taskId -State 'failed' -LocalVideo $null
      $failed += [pscustomobject]@{ shot = $job.shot; task_id = $taskId; error = $_.Exception.Message }
    }
  }
  if ($pending.Count -gt 0) { Start-Sleep -Seconds $PollIntervalSeconds }
}
foreach ($taskId in @($pending.Keys)) { $failed += [pscustomobject]@{ shot = $pending[$taskId].shot; task_id = $taskId; error = "等待超过 $TimeoutMinutes 分钟" } }
if ($failed.Count -gt 0) { [pscustomobject]@{ status = 'failed_or_pending'; completed = $completed; failed = $failed; final_video = $null } | ConvertTo-Json -Depth 6; exit 1 }
$assembly = & $assembleScript -ProjectDirectory $ProjectDirectory | ConvertFrom-Json
[pscustomobject]@{ status = 'generated'; completed = $completed; failed = @(); final_video = $assembly.output; sources = $assembly.sources } | ConvertTo-Json -Depth 6

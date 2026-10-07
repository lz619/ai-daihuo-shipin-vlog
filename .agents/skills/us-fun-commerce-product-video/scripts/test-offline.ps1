# Offline integration checks. All API requests are mocked; all outputs are temporary.
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('fun-video-test-' + [guid]::NewGuid().ToString('N'))
$previousKey = $env:BUMING_API_KEY
$global:FunVideoMockCalls = 0
$global:FunVideoMockFailure = $false
function global:Invoke-RestMethod {
  param($Uri,$Method,$Headers,$ContentType,$Body,$TimeoutSec)
  $global:FunVideoMockCalls++
  if ($global:FunVideoMockFailure) { throw 'Mock ambiguous timeout' }
  return @{task_id="offline-$global:FunVideoMockCalls"}
}
function Assert-Test($Condition, $Message) { if (-not $Condition) { throw $Message } }
try {
  New-Item -ItemType Directory -Path $testRoot | Out-Null
  $env:BUMING_API_KEY = 'offline-fixture'
  $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
  $nodePath = if ($nodeCommand) { $nodeCommand.Source } else { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe' }
  & $nodePath "$PSScriptRoot/test-production-plan.mjs" --fixture-dir $testRoot | Out-Null
  Assert-Test ($LASTEXITCODE -eq 0) 'Structured fixture creation failed.'
  $framePath = Join-Path $testRoot 'first-frames/S01.png'
  $png = [IO.File]::ReadAllBytes($framePath)
  $blocked = $false
  try { & "$PSScriptRoot/submit-buming-omni-1.1.ps1" -ProjectDirectory $testRoot | Out-Null } catch { $blocked=$true }
  Assert-Test ($blocked -and $global:FunVideoMockCalls -eq 0) 'Unapproved images reached submission.'
  & "$PSScriptRoot/record-first-frame-approval.ps1" -ProjectDirectory $testRoot -UserConfirmation 'Synthetic test approval, not a production approval.'
  & $nodePath "$PSScriptRoot/production-plan.mjs" compile --project $testRoot --stage video | Out-Null
  Assert-Test ($LASTEXITCODE -eq 0) 'Canonical task compilation failed.'
  $config = Get-Content -LiteralPath (Join-Path $testRoot 'image-to-video-jobs.json') -Raw -Encoding utf8 | ConvertFrom-Json
  & "$PSScriptRoot/submit-buming-omni-1.1.ps1" -ProjectDirectory $testRoot | Out-Null
  Assert-Test ($global:FunVideoMockCalls -eq 5) 'Expected five mocked submissions.'
  & "$PSScriptRoot/submit-buming-omni-1.1.ps1" -ProjectDirectory $testRoot | Out-Null
  Assert-Test ($global:FunVideoMockCalls -eq 5) 'Resume created duplicate requests.'
  $config.jobs[0].dialogue = 'Tampered task file.'
  $config | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $testRoot 'image-to-video-jobs.json') -Encoding utf8
  $blocked = $false
  try { & "$PSScriptRoot/submit-buming-omni-1.1.ps1" -ProjectDirectory $testRoot | Out-Null } catch { $blocked = $true }
  Assert-Test ($blocked -and $global:FunVideoMockCalls -eq 5) 'A hand-edited task reached the API.'
  & $nodePath "$PSScriptRoot/production-plan.mjs" compile --project $testRoot --stage video | Out-Null
  $config = Get-Content -LiteralPath (Join-Path $testRoot 'image-to-video-jobs.json') -Raw -Encoding utf8 | ConvertFrom-Json
  [IO.File]::WriteAllBytes($framePath, ($png + [byte]0))
  $ready = & "$PSScriptRoot/check-first-frames.ps1" -ProjectDirectory $testRoot | ConvertFrom-Json
  Assert-Test (-not $ready.ready) 'Replacing frame content did not invalidate approval.'
  [IO.File]::WriteAllBytes($framePath,$png)
  $global:FunVideoMockFailure = $true
  & "$PSScriptRoot/submit-buming-omni-1.1.ps1" -ProjectDirectory $testRoot -Shots S01 -ForceResubmit | Out-Null
  $afterFailure = $global:FunVideoMockCalls
  & "$PSScriptRoot/submit-buming-omni-1.1.ps1" -ProjectDirectory $testRoot -Shots S01 | Out-Null
  Assert-Test ($global:FunVideoMockCalls -eq $afterFailure) 'Ambiguous submission was charged again.'

  # Verify real trimming, assembly and media checks using a tiny generated video.
  $videoDirectory = Join-Path $testRoot 'videos'
  New-Item -ItemType Directory -Path $videoDirectory | Out-Null
  $source = Join-Path $videoDirectory 'source.mp4'
  & ffmpeg -hide_banner -loglevel error -f lavfi -i 'color=c=blue:s=90x160:r=10:d=4' -f lavfi -i 'sine=frequency=440:duration=4' -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest $source
  Assert-Test ($LASTEXITCODE -eq 0) 'Fixture video creation failed.'
  $tasks = foreach ($job in $config.jobs) { @{shot=$job.shot; fingerprint=$job.request_fingerprint; state='success'; local_video=$source; submitted_at='2026-01-01T00:00:00Z'} }
  # A newer successful task for a different generation must never be selected.
  $tasks += @{shot='S01'; fingerprint='unrelated-generation'; state='success'; local_video=(Join-Path $testRoot 'wrong-source.mp4'); submitted_at='2027-01-01T00:00:00Z'}
  @{tasks=@($tasks)} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $testRoot 'video-task-state.json') -Encoding utf8
  $trim = & "$PSScriptRoot/trim-buming-shots.ps1" -ProjectDirectory $testRoot | ConvertFrom-Json
  $assembly = & "$PSScriptRoot/assemble-final-video.ps1" -ProjectDirectory $testRoot -PreparedDirectory $trim.prepared_directory | ConvertFrom-Json
  $validation = & "$PSScriptRoot/validate-final-video.ps1" -VideoPath $assembly.output | ConvertFrom-Json
  Assert-Test ($validation.status -eq 'validated') 'Final media validation failed.'
  'PASS: review gate, changed-image detection, deduplication, ambiguous-submit recovery, trimming, assembly, audio/aspect/duration checks.'
} finally {
  $env:BUMING_API_KEY = $previousKey
  Remove-Item Function:\Invoke-RestMethod -ErrorAction SilentlyContinue
  $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
  $allowedPrefix = Join-Path ([IO.Path]::GetTempPath()) 'fun-video-test-'
  if ($resolvedTestRoot.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTestRoot)) { Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force }
}

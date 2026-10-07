param(
  [Parameter(Mandatory = $true)][string]$VideoPath,
  [string]$OutputPath,
  [string]$RuntimeRoot = (Join-Path $env:LOCALAPPDATA 'faster-whisper'),
  [string]$PythonPath,
  [string]$ModelDirectory
)

$ErrorActionPreference = 'Stop'
$video = (Resolve-Path -LiteralPath $VideoPath -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $video -PathType Leaf)) { throw "Video file does not exist: $VideoPath" }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path (Split-Path -Parent $video) 'asr-transcript.json' }

$python = if ([string]::IsNullOrWhiteSpace($PythonPath)) { Join-Path $RuntimeRoot '.venv\Scripts\python.exe' } else { $PythonPath }
$modelDirectory = if ([string]::IsNullOrWhiteSpace($ModelDirectory)) { Join-Path $RuntimeRoot 'models' } else { $ModelDirectory }
$transcriber = Join-Path $PSScriptRoot 'transcribe-faster-whisper.py'
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) { throw "Fixed ASR runtime is not installed at $python. Run scripts/setup-faster-whisper.ps1; do not silently skip ASR." }
if (-not (Test-Path -LiteralPath $modelDirectory -PathType Container)) { throw "ASR model cache is missing at $modelDirectory. Run scripts/setup-faster-whisper.ps1; do not silently skip ASR." }

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($null -eq $ffmpeg) { throw 'ffmpeg is required to extract the final-video audio for ASR.' }
$tempAudio = Join-Path ([IO.Path]::GetTempPath()) ('faster-whisper-' + [guid]::NewGuid().ToString('N') + '.wav')
try {
  & $ffmpeg.Source -hide_banner -loglevel error -y -i $video -map 0:a:0 -vn -ac 1 -ar 16000 -c:a pcm_s16le $tempAudio
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tempAudio -PathType Leaf)) { throw 'Could not extract an audio track from the final video.' }
  & $python $transcriber --model-dir $modelDirectory --audio $tempAudio --output $OutputPath
  if ($LASTEXITCODE -ne 0) { throw 'ASR failed; this video cannot be marked quality-checked.' }
  if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) { throw 'ASR returned success but did not create its transcript JSON.' }
  $result = Get-Content -LiteralPath $OutputPath -Raw -Encoding utf8 | ConvertFrom-Json
  if ($result.status -ne 'transcribed' -or $result.engine_version -ne '1.2.1' -or $result.model -ne 'base.en') { throw 'ASR result did not match the required engine/model configuration.' }
  [pscustomobject]@{ status = 'transcribed'; engine = $result.engine; engine_version = $result.engine_version; model = $result.model; transcript_path = (Resolve-Path -LiteralPath $OutputPath).Path; segment_count = @($result.segments).Count } | ConvertTo-Json -Compress
} finally {
  if (Test-Path -LiteralPath $tempAudio -PathType Leaf) { Remove-Item -LiteralPath $tempAudio -Force }
}

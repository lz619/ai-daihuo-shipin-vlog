param(
  [string]$RuntimeRoot = (Join-Path $env:LOCALAPPDATA 'faster-whisper'),
  [string]$PythonLauncher = 'py'
)

$ErrorActionPreference = 'Stop'
$transcriber = Join-Path $PSScriptRoot 'transcribe-faster-whisper.py'
$requirements = Join-Path $PSScriptRoot 'faster-whisper-requirements.txt'
$venvPython = Join-Path $RuntimeRoot '.venv\Scripts\python.exe'
$modelDirectory = Join-Path $RuntimeRoot 'models'

if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { throw 'LOCALAPPDATA is unavailable. Pass -RuntimeRoot to a persistent local directory.' }
if (-not (Test-Path -LiteralPath $transcriber -PathType Leaf)) { throw "ASR script is missing: $transcriber" }
if (-not (Test-Path -LiteralPath $requirements -PathType Leaf)) { throw "Pinned requirements are missing: $requirements" }

$launcher = Get-Command $PythonLauncher -ErrorAction SilentlyContinue
if ($null -eq $launcher) { throw 'Python launcher "py" was not found. Install Python 3.9+ from the official Python distribution, then rerun this setup script.' }
if ($null -eq (Get-Command ffmpeg -ErrorAction SilentlyContinue)) { throw 'FFmpeg was not found. Install FFmpeg before using this Skill; the ASR caller uses it to extract audio from MP4.' }

New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
New-Item -ItemType Directory -Path $modelDirectory -Force | Out-Null
if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
  & $launcher.Source -3 -m venv (Join-Path $RuntimeRoot '.venv')
  if ($LASTEXITCODE -ne 0) { throw 'Could not create the Faster-Whisper virtual environment. Confirm Python 3.9+ is installed.' }
}

& $venvPython -c "import sys; assert sys.version_info >= (3, 9), sys.version"
if ($LASTEXITCODE -ne 0) { throw 'The selected Python interpreter must be Python 3.9 or newer.' }
& $venvPython -m pip install --disable-pip-version-check --requirement $requirements
if ($LASTEXITCODE -ne 0) { throw 'Faster-Whisper installation failed. Check network access to PyPI and retry.' }
& $venvPython $transcriber --download-model --model-dir $modelDirectory
if ($LASTEXITCODE -ne 0) { throw 'The base.en model could not be downloaded or initialized. Check Hugging Face access and available disk space.' }

[pscustomobject]@{
  status = 'ready'
  python = $venvPython
  runtime_root = $RuntimeRoot
  model = 'base.en'
  model_cache = $modelDirectory
  faster_whisper_version = '1.2.1'
  device = 'cpu'
  compute_type = 'int8'
} | ConvertTo-Json -Compress

param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectDirectory,
  [string]$PreparedDirectory,
  [string]$OutputPath,
  [string]$FfmpegPath
)

$ErrorActionPreference = 'Stop'

function Resolve-Ffmpeg {
  param([string]$RequestedPath)

  if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
    if (-not (Test-Path -LiteralPath $RequestedPath)) {
      throw "指定的 FFmpeg 不存在：$RequestedPath"
    }
    return (Resolve-Path -LiteralPath $RequestedPath).Path
  }

  $command = Get-Command ffmpeg -ErrorAction SilentlyContinue
  if ($null -ne $command) {
    return $command.Source
  }

  $wingetPackages = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
  if (Test-Path -LiteralPath $wingetPackages) {
    $installed = Get-ChildItem -LiteralPath $wingetPackages -Directory -Filter 'Gyan.FFmpeg*' -ErrorAction SilentlyContinue |
      ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter 'ffmpeg.exe' -File -Recurse -ErrorAction SilentlyContinue } |
      Select-Object -First 1
    if ($null -ne $installed) {
      return $installed.FullName
    }
  }

  throw '未找到 FFmpeg。请安装 FFmpeg，或使用 -FfmpegPath 指定 ffmpeg.exe 的完整路径。'
}

function Get-LatestShotFile {
  param(
    [Parameter(Mandatory = $true)][string]$VideoDirectory,
    [Parameter(Mandatory = $true)][string]$Shot
  )

  $escapedShot = [regex]::Escape($Shot)
  $candidate = Get-ChildItem -LiteralPath $VideoDirectory -File -Filter "$Shot*.mp4" |
    Where-Object { $_.Name -match "^$escapedShot(?:-v(?<version>\d+))?\.mp4$" } |
    ForEach-Object {
      $match = [regex]::Match($_.Name, "^$escapedShot(?:-v(?<version>\d+))?\.mp4$")
      [pscustomobject]@{
        File = $_
        Version = if ($match.Groups['version'].Success) { [int]$match.Groups['version'].Value } else { 1 }
      }
    } |
    Sort-Object Version, @{ Expression = { $_.File.LastWriteTime }; Descending = $true } -Descending |
    Select-Object -First 1

  if ($null -eq $candidate) {
    throw "缺少 $Shot 的可用视频。请先生成该分镜，再执行拼接。"
  }
  return $candidate.File
}

if (-not (Test-Path -LiteralPath $ProjectDirectory -PathType Container)) {
  throw "SKU 项目文件夹不存在：$ProjectDirectory"
}

$videoDirectory = if ([string]::IsNullOrWhiteSpace($PreparedDirectory)) { Join-Path $ProjectDirectory 'videos' } else { $PreparedDirectory }
if (-not (Test-Path -LiteralPath $videoDirectory -PathType Container)) {
  throw "找不到分镜视频文件夹：$videoDirectory"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path (Join-Path $ProjectDirectory 'videos') 'final-video.mp4'
}

$ffmpeg = Resolve-Ffmpeg -RequestedPath $FfmpegPath
$shots = @('S01', 'S02', 'S03', 'S04', 'S05')
$sourceFiles = @($shots | ForEach-Object { Get-LatestShotFile -VideoDirectory $videoDirectory -Shot $_ })
$concatList = Join-Path $videoDirectory ('.concat-{0}.txt' -f [guid]::NewGuid().ToString('N'))

try {
  $listLines = $sourceFiles | ForEach-Object {
    $safePath = $_.FullName.Replace('\', '/').Replace("'", "'\\''")
    "file '$safePath'"
  }
  [System.IO.File]::WriteAllLines($concatList, [string[]]$listLines, [System.Text.UTF8Encoding]::new($false))

  & $ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i $concatList `
    -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart $OutputPath
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPath)) {
    throw 'FFmpeg 未能生成最终成片。'
  }

  [pscustomobject]@{
    output = (Resolve-Path -LiteralPath $OutputPath).Path
    sources = $sourceFiles.FullName
  } | ConvertTo-Json -Compress
} finally {
  if (Test-Path -LiteralPath $concatList) {
    Remove-Item -LiteralPath $concatList -Force
  }
}

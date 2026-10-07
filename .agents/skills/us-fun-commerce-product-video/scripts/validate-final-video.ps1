param(
  [Parameter(Mandatory = $true)][string]$VideoPath,
  [string]$FfprobePath
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $VideoPath -PathType Leaf)) { throw "最终视频不存在：$VideoPath" }
if ([string]::IsNullOrWhiteSpace($FfprobePath)) {
  $command = Get-Command ffprobe -ErrorAction SilentlyContinue
  if ($null -ne $command) { $FfprobePath = $command.Source }
  else {
    $wingetPackages = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path -LiteralPath $wingetPackages) {
      $installed = Get-ChildItem -LiteralPath $wingetPackages -Directory -Filter 'Gyan.FFmpeg*' -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter 'ffprobe.exe' -File -Recurse -ErrorAction SilentlyContinue } |
        Select-Object -First 1
      if ($null -ne $installed) { $FfprobePath = $installed.FullName }
    }
  }
}
if ([string]::IsNullOrWhiteSpace($FfprobePath) -or -not (Test-Path -LiteralPath $FfprobePath -PathType Leaf)) { throw '未找到 ffprobe，无法验证最终视频的时长、画幅和音轨。' }

$probeText = & $FfprobePath -v error -show_entries format=duration:stream=codec_type,width,height -of json $VideoPath
if ($LASTEXITCODE -ne 0) { throw 'ffprobe 无法读取最终视频。' }
$probe = $probeText | ConvertFrom-Json
$videoStream = @($probe.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1)
$audioStream = @($probe.streams | Where-Object { $_.codec_type -eq 'audio' } | Select-Object -First 1)
if ($videoStream.Count -eq 0) { throw '最终视频没有视频轨。' }
if ($audioStream.Count -eq 0) { throw '最终视频没有口播/音频轨。' }
$ratio = [double]$videoStream[0].width / [double]$videoStream[0].height
if ([math]::Abs($ratio - (9.0 / 16.0)) -gt 0.01) { throw "最终视频不是 9:16 竖屏：$($videoStream[0].width)x$($videoStream[0].height)" }
$duration = [double]$probe.format.duration
if ($duration -lt 15 -or $duration -gt 20) { throw "最终视频时长 $([math]::Round($duration, 3)) 秒不在 15–20 秒范围。" }
[pscustomobject]@{ status = 'validated'; path = (Resolve-Path -LiteralPath $VideoPath).Path; duration_seconds = [math]::Round($duration, 3); width = [int]$videoStream[0].width; height = [int]$videoStream[0].height; has_audio = $true } | ConvertTo-Json -Compress

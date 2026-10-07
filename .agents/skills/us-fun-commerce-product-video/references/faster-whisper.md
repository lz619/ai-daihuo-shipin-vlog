# Faster-Whisper 固定运行环境

本 Skill 的最终视频口播检查固定使用 faster-whisper。它不是跟着 SKU 或视频项目复制的文件，而是在每台电脑上安装一次的本地共享运行环境：

- Python package：`faster-whisper==1.2.1`
- ASR model：`base.en`（模型标识，不带 1.1 版本号）
- Device / precision：CPU / int8
- Runtime：`%LOCALAPPDATA%\faster-whisper\.venv\Scripts\python.exe`
- Model cache：`%LOCALAPPDATA%\faster-whisper\models`

## 首次安装

需要 Windows、Python 3.9+ launcher (`py`) 和可访问 PyPI/Hugging Face 的网络。不要将虚拟环境、模型缓存、商品素材或 API 密钥提交到公开仓库。

从仓库根目录运行：

```powershell
& ".agents/skills/us-fun-commerce-product-video/scripts/setup-faster-whisper.ps1"
```

脚本会在当前 Windows 用户的 `%LOCALAPPDATA%` 下建立一次性 venv、按 `scripts/faster-whisper-requirements.txt` 安装固定版本，并下载/初始化 `base.en`。其他 SKU 视频复用这一份环境和模型，不重复安装。

## 每条视频调用

首剪后及每次二次剪辑后都运行：

```powershell
& ".agents/skills/us-fun-commerce-product-video/scripts/run-faster-whisper-qa.ps1" `
  -VideoPath "<视频项目>/videos/final-video.mp4" `
  -OutputPath "<视频项目>/asr-transcript.json"
```

入口从成片抽取音轨，调用固定 venv 转写，并验证输出的引擎版本与模型标识。JSON 包含语段及词级时间戳。Codex 仍须对照统一计划中的英文台词、实际试听并做画面复核；ASR 只提供识别文本和时间证据，不会自行判断怎么剪。剪辑由 Skill 决策后调用 FFmpeg 执行。

运行环境缺失、版本不匹配、模型加载或转写失败时，质检入口以失败退出，Skill 必须停止交付，报告错误并让用户先修复运行环境；不允许把转写文件缺失当成检查通过。

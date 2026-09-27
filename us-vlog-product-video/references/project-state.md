# SKU Project State

Create one folder per SKU and keep:

```text
<SKU>/
  project-state.md
  direction-cards.md
  five-shot-scripts.md
  reference-plan.md
  static-storyboard-prompts.md
  image-to-video-prompts.md
  anchors/
  first-frames/
  videos/
```

`project-state.md` is the resumption index, not a substitute for the complete
deliverables. Store the full direction cards, shot specifications, P/R plan,
ChatGPT-web prompts, and image-to-video prompts in the corresponding files.
Follow [the deliverable-file contract](deliverable-files.md) for their required
contents and update this state whenever an artifact is created, reviewed, or
blocked. Write the state and every associated deliverable in Simplified Chinese,
except for exact American-English dialogue and source identifiers that must not
change.

The source Excel remains the authoritative first-step fact card. In `project-state.md`, record its absolute path, worksheet, row, SKU, and product-image paths. Do not copy facts into the state as if they were independently confirmed.

```md
# SKU 项目状态

## 来源
- Excel 路径：
- 工作表与行：
- SKU：
- 产品图片路径：

## 视频默认值
- 市场：TikTok US
- 画幅：9:16
- 成片时长：15-20 秒
- 视频模型最短生成时长：

## 视频 <编号>
### 方向
- 核心卖点：
- 有依据的用户痛点：
- 具体目标人群：
- 具体生活场景：
- 开场钩子：
- 核心视觉动作：

### 交付文件
- 方向卡：direction-cards.md | 状态 | 审核备注
- 五镜头脚本：five-shot-scripts.md | 状态 | 审核备注
- P/R 最小素材计划：reference-plan.md | 状态 | 审核备注
- ChatGPT 网页静态首帧提示词：static-storyboard-prompts.md | 状态 | 审核备注
- 图生视频提示词：image-to-video-prompts.md | 状态 | 审核备注

### 美国日常生活 Vlog 视觉设定
- 创作者身份与自然状态：
- 具体生活空间：
- 少量合理背景物：
- 光线与色彩：
- 手机机位与拍摄方式：
- 连续性锚点：
- 避免：

### 脚本
- S01：镜头职责 | 动作 | 起始状态 | 结束状态 | 必须可见的产品部分 | 镜头 | 英文台词 | 成片保留时长
- S02：镜头职责 | 动作 | 起始状态 | 结束状态 | 必须可见的产品部分 | 镜头 | 英文台词 | 成片保留时长
- S03：镜头职责 | 动作 | 起始状态 | 结束状态 | 必须可见的产品部分 | 镜头 | 英文台词 | 成片保留时长
- S04：镜头职责 | 动作 | 起始状态 | 结束状态 | 必须可见的产品部分 | 镜头 | 英文台词 | 成片保留时长
- S05：镜头职责 | 动作 | 起始状态 | 结束状态 | 必须可见的产品部分 | 镜头 | 英文台词 | 成片保留时长

### 最小素材
- P 产品图：
- R 连续性锚点：
- 缺失或阻塞素材：

### 静态首帧
- S01：路径 | 状态 | 审核备注
- S02：路径 | 状态 | 审核备注
- S03：路径 | 状态 | 审核备注
- S04：路径 | 状态 | 审核备注
- S05：路径 | 状态 | 审核备注

### 声音
- 说话人：
- 口音：
- 语气：
- 语速：
- 各镜头台词方式：

### 视频任务
- S01：提示词状态 | 供应商任务 ID | 本地视频路径 | 审核备注
- S02：提示词状态 | 供应商任务 ID | 本地视频路径 | 审核备注
- S03：提示词状态 | 供应商任务 ID | 本地视频路径 | 审核备注
- S04：提示词状态 | 供应商任务 ID | 本地视频路径 | 审核备注
- S05：提示词状态 | 供应商任务 ID | 本地视频路径 | 审核备注

### 最终成片
- 状态：pending / generated / approved / blocked / failed
- 文件：`videos/final-video.mp4`
- 拼接顺序：
- 使用的镜头版本：
- 技术校验：画幅、音视频流、总时长
- 审核备注：
```

Use `pending`, `prompt_ready`, `generated`, `approved`, `blocked`, or `failed` for image and video status. Always preserve the specific reason for `blocked` or `failed`.

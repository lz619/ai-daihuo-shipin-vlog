# 趣味带货 SKU 项目状态

每个 SKU 在独立目录保存项目文件。源 Excel 仍是商品事实的唯一表格依据；项目文件应记录其来源，不将未经核验的总结写成新事实。

```text
<SKU>/
  project-state.md
  product-config.json
  production-config.json
  production-plan.json
  direction-cards.md
  five-shot-scripts.md
  reference-plan.md
  static-storyboard-prompts.md
  first-frame-jobs.json
  image-to-video-prompts.md
  image-to-video-jobs.json
  first-frame-review.json
  video-task-state.json
  anchors/
  first-frames/
  videos/
```

在 `project-state.md` 记录：

```md
# SKU 趣味带货视频项目状态

## 来源
- Excel 路径：
- 工作表与行：
- SKU：
- 商品图片路径：

## 默认制作规格
- 市场：TikTok US
- 画幅：9:16
- 剪辑成片时长：15–20 秒
- 选用图生视频模型及最短生成时长：

## 视频 <编号>
- 方向卡：文件 | 状态 | 审核备注
- 统一计划：production-plan.json | 校验/编译状态 | 版本和阻塞原因
- 五镜头脚本：文件 | 状态 | 审核备注
- P/R 计划：文件 | 状态 | 审核备注
- 静态首帧：文件 | 状态 | 审核备注
- 图生视频提示词：文件 | 状态 | 审核备注
- 趣味钩子类型：
- 钩子与产品的因果连接：
- 商品首次出现时间：
- 核心卖点及来源字段：
- 可见证据及来源字段/图片：
- 美区 Vlog 生活质感设定：
- S01–S05 剪辑秒数：
- P/R 素材与实际路径：
- 首帧/视频实际路径及审核状态：
- 当前阶段：规划 / 生成首帧 / awaiting_user_review / 视频生成 / 成片审核 / completed
- 首帧用户验收：待确认 / 确认原话、时间、对应文件与 SHA256
- 阻塞问题：

## 发布复盘
- 发布/投放窗口与数据来源：
- 2 秒 / 6 秒观看率：
- 商品点击率：
- 点击后转化率、订单：
- CPA / ROAS（如有）：
- 对照组：
- 结论及下一轮单一改动：
```

素材状态沿用 `pending`、`prompt_ready`、`generated`、`approved`、`blocked`、`failed`。用户看图后明确继续，才把首帧状态从 generated 改成 approved。任何 blocked/failed 都要记录具体原因。实际图片/视频不存在时不得虚构路径或审核结果。多条视频时每个 video-NN 目录独立保存任务与首帧确认记录。

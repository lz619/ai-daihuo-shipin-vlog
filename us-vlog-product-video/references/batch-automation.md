# Excel 批量自动化说明

## 你填写的 Excel

使用 `assets/product-input-template.xlsx` 的“产品输入”工作表。每一行是一个独立 SKU；A 至 F 列为产品事实，G 至 K 列为该商品自己的生产配置：

- `队列状态`：`待规划`、`等待图片`、`可生成视频`、`已完成` 或 `跳过`。
- `视频模型`：默认 `omni-1.1`。
- `分辨率`：默认 `720P`，也可填 `1080P` 或 `4K`。
- `BGM 文件路径（可选）`、`项目备注（可选）`：保留在 SKU 配置中，供后续剪辑策略使用。

一个单元格中的多张商品图使用换行分隔；填写真实本地绝对路径。SKU 只能使用字母、数字、下划线和连字符。

## 自动化边界

1. 你填写 Excel 和真实商品图片路径。
2. 智能体按每一行自己的事实生成中文策划、五分镜、静态首帧提示词，以及该 SKU 的 `image-to-video-jobs.json`。
3. 你在 GPT 网页生成并审核锚点图/五张首帧，保存到该 SKU 的 `first-frames` 文件夹。
4. 脚本检查五张首帧，批量提交、轮询、下载和拼片。

第 3 步是唯一保留的手动环节。脚本不会替你调用 GPT 网页，也不会在未授权时创建付费视频任务。

## 常用命令

在 skill 根目录运行：

```powershell
node scripts/read-product-input.mjs .\assets\product-input-template.xlsx
node scripts/initialize-batch-projects.mjs --excel .\assets\product-input-template.xlsx
.\scripts\run-ready-video-batch.ps1
```

第三条命令只检查，不消耗额度。确认后再由用户明确授权，并运行：

```powershell
.\scripts\run-ready-video-batch.ps1 -Submit
```

若仅处理一个 SKU：

```powershell
.\scripts\run-buming-omni-1.1-batch.ps1 -ProjectDirectory .\projects\你的SKU
```

脚本将任务记录在 `video-task-state.json`。首帧、提示词、时长和分辨率都未变化时，会复用已有任务 ID，避免重复提交；只有明确传入 `-ForceResubmit` 才会再次创建任务。

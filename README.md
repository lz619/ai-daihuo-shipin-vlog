# AI 带货视频 Vlog Skill

这是一个从 Excel 商品事实卡出发、生成美国 TikTok 日常 Vlog 带货视频的本地 Skill。

当前自动化范围：按 SKU 读取 Excel、生成策划与分镜任务配置、检查人工生成的五张首帧、提交 Omni 1.1 图生视频、轮询下载、版本管理及自动拼接成片。

GPT 网页生成并审核锚点图/首帧仍是人工环节；真实 API 密钥、本地商品素材、视频和任务状态均被 `.gitignore` 排除。

主要 Skill 位于 [`us-vlog-product-video`](us-vlog-product-video)。部署和批量使用说明见该目录的 `docs` 与 `references`。

# 统一制作计划：方向卡、五镜头与后续参数

每条视频维护一个 `production-plan.json`。模型负责其中的创意与语义，程序按 [production-plan.schema.json](production-plan.schema.json) 检查结构，再派生 Markdown、首帧任务和视频任务。所有下游文件均是可重新生成的阅读/执行材料，不独立修改参数。

## 生成和校验顺序

1. Excel 初始化得到 `product-config.json`；用户选定模型/分辨率后记录 `production-config.json`。这两个文件用于建立来源和初始制作配置。
2. 在单条视频目录运行 `node scripts/production-plan.mjs init --project <视频目录>`。多视频时在各 `video-NN` 目录运行，初始化程序向上查找商品与制作配置。已有计划不覆盖。
3. 先读 [高停留钩子与产品证明设计](hook-and-proof.md)，至少构思并比较三个不同视觉机制的开场，淘汰只有痛点口播、没有视觉停留点的方案。选定后，模型填写计划中的事实、方向卡、S01–S05、P/R 素材和静态提示词。S01 留下的期待须由 S02 的产品桥接及 S03–S04 的真实可视演示兑现。`motion_prompt` 此时留空。初始化的空字段只是草稿，不是已完成创意；按错误提示修改到 planning 校验通过。
4. 运行 `node scripts/production-plan.mjs compile --project <视频目录> --stage planning`。一次性检查全部数据后生成 `direction-cards.md`、`five-shot-scripts.md`、`reference-plan.md`、`static-storyboard-prompts.md`、`first-frame-jobs.json`，不会生成视频任务。
5. 按 `first-frame-jobs.json` 中的真实参考路径和完整提示词，用 ImageGen 逐镜头生成首帧。允许 S01 同时作为 R01，后续引用时必须先确认它已保存。参考图职责与 PoseMaster 优先级由编译器明确加入首帧提示词。模型仍需视觉检查商品、手部、空间和生活质感。
6. 在 Codex 展示五张图并等用户验收。用户要求替换（如 S020.png）时只修改该镜头 `first_frame` 及确需调整的视觉字段，重新 planning 编译并展示；不能伪造批准。
7. 得到用户明确继续后，运行 `record-first-frame-approval.ps1`。它直接读取统一计划，不需要预先存在视频任务，记录确认原话、模型/分辨率、五张图内容哈希和首帧计划哈希。
8. 模型填写同一计划各镜头的 `motion_prompt`。不要在这里复制/重写台词、生成秒数或剪辑秒数；这些已有专门字段。再运行 `compile --stage video`，程序从这些字段组装准确台词和口播方式、生成 `image-to-video-jobs.json` 与提示词 Markdown。
9. 提交及修剪脚本都先核对任务文件与当前计划是否完全一致。过期/手改任务会被阻止，须从 JSON 重新编译。修改生成相关参数会产生新请求指纹；仅调整起剪点/保留秒数，保持原生成指纹，可复用成功视频。需重新付费时沿用用户现有授权边界。

以上命令由 Codex 执行，用户仍只参与 Excel、模型/分辨率选择与五张首帧验收。优先使用可用 `node`，否则用 Codex 自带 Node.js 的绝对路径。

## 顶层字段

| 字段 | 内容与职责 |
| --- | --- |
| `schema_version` | 当前为 1；不能随意增减字段 |
| `sku` / `video_id` | 商品与本条视频身份 |
| `source` | `product_config` 路径、Excel 路径、工作表和行号；须与商品镜像一致 |
| `production` | provider/model/resolution/aspect_ratio/spoken_language；初始化后本条视频以此为唯一制作配置 |
| `facts` | 从该 SKU 资料核对的事实编号、内容、来源字段和真实图片路径 |
| `direction` | 方向卡；商品首次出现时间和总时长由镜头数据计算，不重复填写 |
| `references` | 真实商品图 P 和所需人物/环境锚点 R 的路径及职责 |
| `shots` | 按固定顺序 S01–S05 的五镜头脚本与提示词字段 |

不要另维护一份分镜秒数表，或在 production-config、Markdown、任务文件内覆盖参数。用户后续改变制作选择时修改 `production`，再记录必要的用户选择/首帧确认并重新编译。事实文本须由模型核对，程序检查编号和来源可追溯性，不宣称自动证明事实正确。

## 方向卡字段

- `core_selling_point`：一项核心卖点；`text` 写内容，`fact_ids` 关联本计划事实编号。其余卖点另用于其他视频，不拆成这里的多卖点数组。
- `confirmed_pain_point`、`target_audience`、`purchase_reason`：均有 `text` 和 `fact_ids`。
- `life_situation`：具体生活情境。
- `hook`：`behavior` 写清首秒发生的视觉事件及留下的问题，不要只写痛点；`humor_source` 写悬念、视觉冲击、新奇/反差的具体来源；`bridge_to_product` 说明 S02 怎样在钩子后几秒内回到商品；`muted_readable` 评审静音时是否仍能理解。候选生成与评分按 [高停留钩子与产品证明设计](hook-and-proof.md) 执行。
- `proof`：`method` 说明 S03–S04 如何通过正确操作、可观察变化/输出或其他真实演示增强信任；`fact_ids` 关联支持该演示的商品证据。不能演示的效果不得只用台词声称。
- `vlog`：`creator` 人物、`wardrobe` 服装、`setting` 环境、`lighting` 光线、`camera_style` 手机拍摄方式、`continuity` 连续性。
- 首次露品时间：程序累计之前镜头的 `edit_duration_seconds`，加上首个露品镜头的 `reveal_offset_seconds`。该偏移指最终保留片段内的时间；不露品时为 null。最迟 S02 露品，约 3 秒仍是创作建议，不强制当成所有商品的固定值。

## 五镜头字段

| 字段 | 约定 |
| --- | --- |
| `id` / `role` | S01/hook、S02/bridge、S03/use、S04/proof、S05/cta，固定顺序 |
| `visual` / `main_action` | 画面与唯一主要动作；动作的可实现性仍需模型评审 |
| `start_state` / `end_state` | 首帧起始状态和单段运动的结束状态 |
| `visible_product_parts` | 商品需可见部分；无商品镜头明确写“不出现” |
| `continuity` / `camera` / `vlog_detail` | 跨镜头连续性、可行机位、自然生活细节 |
| `fact_ids` | 此镜头所依赖的商品事实编号 |
| `dialogue` / `delivery` | 精确美式英语台词；on_camera 对镜或 voiceover 同一创作者画外音 |
| `product_visible` / `reveal_offset_seconds` | 是否露品、相对保留片段的首次露品偏移；不露品用 null |
| `duration_seconds` | Omni 1.1 生成整数秒数 3–10 |
| `edit_duration_seconds` / `trim_start_seconds` | 保留正数秒数与非负起剪点；相加不得超过生成秒数；五镜合计 15–20 秒 |
| `spatial_relation` | none/installation/insertion/clamping/magnetic/snap/sleeving/connection/support/rotation |
| `pose_master_ref` / `reference_ids` | 空间关系启用时指向已选 PoseMaster 并包含在上传清单；none 时 pose_master_ref 为 null |
| `first_frame` | 本镜头实际文件路径；可以相对视频目录，也支持明确的替换图路径 |
| `static_prompt` / `acceptance_checks` | 模型创作的静态提示词正文及非空验收清单；编译器加入参考图职责与固定约束 |
| `motion_prompt` | 获批后填写，只写首帧后的动作和镜头变化；台词/时长由其他字段组装 |

`references` 每项有 id、kind（product/anchor）、path、locks、pose_master、angle_degrees、body_and_connection_visible。商品图必须来自 `product-config.json` 所记录的 Excel 图片；PoseMaster 需声明真实 30°–60° 且能看见主体与连接结构。程序能检查路径、声明值与镜头引用，不能替代视觉确认。规划时 R 图允许尚未生成；确认/视频编译前所有引用素材须真实存在。

## 校验与既有项目

```powershell
node scripts/production-plan.mjs validate --project <视频目录> --stage planning
node scripts/production-plan.mjs compile --project <视频目录> --stage planning
# 展示五张图并获得用户明确确认以后：
.\scripts\record-first-frame-approval.ps1 -ProjectDirectory <视频目录> -UserConfirmation <用户确认原话>
# 在统一计划填写 motion_prompt 后：
node scripts/production-plan.mjs compile --project <视频目录> --stage video
node scripts/production-plan.mjs validate --project <视频目录> --stage jobs
.\scripts\run-buming-omni-1.1-batch.ps1 -ProjectDirectory <视频目录> -DryRun
```

视频编译和提交必须有用户批准记录；图片/路径、视觉计划或参考图内容改变会使批准失效。只改台词、运动提示词或剪辑秒数不会擅自把图片设成未批准，但任务必须重新编译，新的付费生成仍按原规则处理。

历史项目没有 production-plan 时不自动从自然语言猜测并补写成已批准状态。恢复历史制作应以真实 Excel 和已存文件逐项建立计划、校验并展示相应首帧取得本轮确认。仅查看历史成片无需迁移。已有 001 文件不因这次升级被覆盖。

运行 `node scripts/test-production-plan.mjs` 和 `scripts/test-offline.ps1` 可进行临时目录的离线验证；后者用模拟 API，并用 FFmpeg 生成小型测试素材，验证批准、复用和剪辑流程，不生成商品视频、不调用付费服务。

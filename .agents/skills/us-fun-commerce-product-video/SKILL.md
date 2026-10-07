---
name: us-fun-commerce-product-video
description: "Create attention-grabbing U.S. TikTok Shop product videos from a completed Excel fact card, with curiosity-led visual hooks, fast product bridges, demonstrable product proof, reviewable storyboards, and configured Buming AI production. Use when planning or producing fun, high-retention product videos from SKU facts."
metadata:
  short-description: 强钩子与可视化产品证明的美区带货视频
---

# 高停留钩子与视觉证明美区带货视频

为 TikTok US 规划有停留点、有产品证明、仍保留创作者真实感的商品短视频。开头不能默认采用普通的“我有一个问题”或只把痛点说出来；先设计能制造悬念、视觉冲击或新奇反差的具体画面，再在钩子后几秒内顺畅揭示产品和关联。全片遵循：**钩子拿停留，效果拿信任，结果和人群共鸣带来分享与购买。**

每条先构思至少三个机制不同的开场候选，至少让“悬念/神秘感、视觉冲击、新奇/反差”中的两项在画面里一眼可见。S01 先让人停下来，S02 尽快回到产品本身并解释关联，S03–S04 用真实、可演示且有资料依据的使用过程或结果建立信任，S05 回扣开场并给目标受众一个自然的分享/购买理由。趣味可以比普通生活片段更大胆，但商品功能、效果和使用方式不能靠编造来制造戏剧性。

已有用户对标时，先读 [用户对标的画面机制](references/hook-reference-library.md) 及能访问的原视频/抽帧。候选必须说清借鉴了哪个具体事件机制、第一秒哪里反常、前三秒发生什么变化，而不是只写“悬念/反差”标签。普通产品效果展示、藏住商品后缓慢揭示、反问式口播不能单凭命名就通过强钩子评审。表格与时长校验通过只证明计划格式正确，不证明开头能吸引停留。

开场可使用演员、独立道具、荒诞剧情和明确可辨的艺术夸张；商品事实约束的是商品身份、操作和效果，不要求剧情只能复刻商品图片。夸张道具或特效不能被表现为商品能力，回归商品时恢复真实比例和功能。生活质感约束光线、材质和表演，不把反常事件删成平淡 Vlog。

旧版 `us-vlog-product-video` 是独立的“真实小麻烦开场”方案。本 Skill 不覆盖旧版文件；用户可按 SKU 同时制作两种路线作为创意对照。

## 核心边界

- 商品事实只从用户指定 Excel 商品事实卡及其真实商品图片读取。TikTok 官方资料只用于创意结构和平台指标，不作为商品功能、效果或安全性的证据。
- 不补写 Excel 和图片未证实的功能、规格、配件、操作、效果、评价、价格、优惠或比较结论；不确定处标为“待确认”，并停止依赖该信息的镜头。
- 每条视频只讲一个主要卖点；五个镜头各一个主要动作。开场负责停留，产品使用与证据负责信任，结尾的结果回扣和受众共鸣负责分享与购买。
- 生产材料使用简体中文；仅保留精确、自然的美式英语口播，以及 SKU、品牌原文、文件路径等不可变标识。
- 默认 9:16、15–20 秒、五镜头。按产品实际使用场景和输入资料决定人物、场景、道具；不得为了营造“美区感”臆造地理标志或消费习惯。

## 工作流

### Excel 来源定位

- 用户明确指定工作簿时，只读取该工作簿。用户说“这个 skill 的 assets/资产里的 Excel”或未提供其他路径时，默认读取**本次实际调用的 `SKILL.md` 所在目录**下 `assets/product-input-template.xlsx`；不要按当前工作目录、文件修改时间或全盘同名搜索改选来源。
- 本仓库实际调用位置为 `.agents/skills/us-fun-commerce-product-video/`，因此常用填写文件为 `E:\我的ai带货视频skills\.agents\skills\us-fun-commerce-product-video\assets\product-input-template.xlsx` 的“产品输入”工作表。仓库根目录的同名 Skill、旧版 Skill、打包/验证目录内的 Excel 均不是默认输入。
- 开始制作先报告解析后的 Excel 绝对路径、工作表、SKU 与行号。指定 SKU 未找到时，核对该工作簿中的 SKU；不得偷偷换表。文件不存在或无法读取时报告该路径；若 Excel 尚未保存，请用户保存原文件，不复制其他模板来代替。
- 用户本轮明确要求“一条/一个视频”时，该数量优先于 Excel 的空白或旧数量；用初始化参数 `--sku <SKU> --video-count 1` 记录本轮覆盖及原始值，保留原始 Excel。

按 [自动执行流程与人工确认点](references/automation.md) 推进整条制作链，默认自动执行，只在三个节点停下：等用户填好/指定 Excel；等用户选择不鸣 AI 模型和分辨率；五张静态首帧生成后展示并等用户验收。尤其不得把“已生成图片”视为“用户已批准”，也不得在首帧验收前调用付费视频 API。

1. 用户提供填好的 Excel 路径和 SKU（如只存在一条有效 SKU 可自动选中）。读取工作簿、对应 SKU 行及真实商品图片；记录来源并验证文件可读。确认本轮 SKU/事实有效后，只询问一次本轮不鸣 AI 模型和分辨率（当前已实现 Omni 1.1 的 720P/1080P/4K）。缺少或冲突的商品事实不能猜测；能安全继续的部分先做，其余仅就确实阻塞的镜头提问。
2. 阅读 [工作流与真实性规范](references/workflow.md)、[高停留钩子与产品证明设计](references/hook-and-proof.md) 和 [统一制作计划](references/structured-plan.md)。先做开场候选与钩子质量筛选，再把胜出的创意写入每条 `production-plan.json`；该文件是方向卡、五镜头、P/R、提示词及制作参数的唯一来源。通过程序 planning 校验并编译成可读 Markdown 和 `first-frame-jobs.json`；禁止分别改写下游秒数、台词和素材路径。强钩子必须在数秒内回归产品，产品故事必须兑现开场留下的问题或预期。
3. 按统一计划编译的首帧任务，使用可用的 `$imagegen`/Codex ImageGen 工具生成五张图，保存到该视频的 `first-frames/`，回填计划的实际路径并做视觉检查。空间连接产品按 PoseMaster 规则执行。完成后在 Codex 中展示五张图并暂停，等待用户提出修改或明确说继续。
4. 仅在用户批准首帧并明确继续后，从统一计划记录批准及图像哈希，再填写其 `motion_prompt` 并 video 编译，自动沿用模型、分辨率、台词、首帧和生成/剪辑秒数；只使用用户指定的不鸣 AI API，不替换为其他视频生成服务。
5. 提交和修剪程序先检查派生任务与当前统一计划完全一致，再校验图片/API 凭据并执行。复用同生成指纹任务避免重复扣费；剪辑只使用与当前镜头生成指纹匹配的成功源视频，按同一份保留秒数修剪并拼接。发生明确失败时记录状态；遇到暂时网络错误不重提任务。
6. 成片必须经过“首剪 → faster-whisper ASR 质检 → 必要时二次优化 → 再次 ASR 与全片复检”的闭环。每次首剪和每次修正后都必须调用 `scripts/run-faster-whisper-qa.ps1`，使用固定的本机运行环境（faster-whisper 1.2.1、`base.en`、CPU int8），将词级时间戳写入该视频目录的 `asr-transcript.json`；不得静默改用其他 ASR 或跳过。ASR 调用失败时停止最终交付并报告具体错误，不能标记复检通过。Codex 对照 `production-plan.json` 的英文台词分析转写和词级时间，结合实际音频/画面预览判断漏词、切词、起口延迟、过长停顿、声线/音量/连续性及产品演示是否清楚。发现可修复问题时，必须自行使用现有素材和 FFmpeg 做本地二次剪辑，再拼接并重新调用 ASR 与技术校验；只有源素材本身无法修复时才阻塞并说明原因。ASR 时间戳是检查证据，不等于正确判决，仍需实际试听与视觉复核。工具安装和固定路径见 [Faster-Whisper 固定运行环境](references/faster-whisper.md)。按 [创意测试与数据复盘](references/metrics-and-testing.md) 处理后续投放数据。

处理批量 Excel 时，对所有填写完整且未标为“跳过”的行按相同流程执行；第三个确认点集中展示所有生成的首帧。缺少凭据、工具不可用、来源图不足以证明空间结构、或外部 API 返回不可恢复错误时，明确标注阻塞与已完成的安全步骤，不伪造完成状态。

## 每条视频的必需交付

- `production-plan.json`：结构化方向卡、五镜头、事实来源、P/R 与后续制作参数；通过 `production-plan.schema.json` 和跨字段程序校验。
- 方向卡：核心卖点、已证实痛点、具体受众、具体生活情境、经筛选的强视觉钩子、钩子至产品的因果连接、产品首次出现时间、核心可视化证明方式、开场预期如何兑现、购买/分享理由、Vlog 真实感设定。
- S01–S05 完整脚本：镜头职责、画面、单一动作、起止状态、商品必须可见部分、人物/场景连续性、可实现机位、生活细节、精确美式英语台词、剪辑时长。
- P/R 最小素材计划、五张静态首帧提示词与验收清单、审核通过后对应的图生视频提示词。
- SKU 项目状态：来源、交付文件状态、实际素材路径、审核备注和阻塞原因。

## 参考资料

- [高停留钩子与产品证明设计](references/hook-and-proof.md)
- [统一制作计划与字段约定](references/structured-plan.md)
- [自动执行流程与人工确认点](references/automation.md)
- [工作流与真实性规范](references/workflow.md)
- [输入表填写说明](references/input-template.md)
- [胎压监测仪创意示例](references/tire-pressure-examples.md)
- [创意测试与数据复盘](references/metrics-and-testing.md)

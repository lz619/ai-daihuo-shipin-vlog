# Workflow: Excel Fact Card to Video Prompt Bundle

## Scope and Starting Point

The user's Excel is the completed Step 1 product fact card. It supplies SKU, product name, product-image links or paths, what the product is, confirmed functions, supported pain points, audience, scenes, usage method, numbered selling points, and requested video count. Do not produce a second product-fact-card pass.

Inspect the selected row and referenced product images. Report missing or contradictory facts, unclear product structure, or unavailable image paths. Do not fill gaps from common knowledge.

Default delivery is 9:16, 15-20 seconds, five shots, and Simplified-Chinese production materials. Direction cards, shot descriptions, material plans, upload lists, prompts, checklists, statuses, and review notes must be in Simplified Chinese. The only normal English output is the exact natural American-English dialogue required for the spoken line. The video model's minimum generation duration is an input, not a reason to change the intended edit duration.

## Global Fact and Continuity Rules

- Do not invent functionality, performance, safety claims, accessories, product results, hidden structures, or use conditions.
- Do not alter the product's confirmed structure, color, scale, buttons, ports, front/back relationship, or required operating steps.
- A white-background or catalog product image locks product identity only. It must not become the final scene background or commercial product composition.
- Everyday background objects may be present only as background. If an object participates in operating the product, demonstrating a claim, creating a pain point, or implying an included accessory, it needs fact support.
- Do not invent dirt, food, pets, children, cosmetics, cleaning products, packaging, replacement parts, cables, or adapters unless the fact card supports them.
- A single video keeps its creator, wardrobe, location, product state, and relevant props consistent across shots. Use anchors only when necessary for cross-shot consistency.

## Everyday U.S. Vlog Visual Rules

The visual aim is a specific ordinary U.S. user sharing a small real-life inconvenience and a supported use experience.

- The creator behaves like they are talking to a friend, never like a professional presenter, studio model, or announcer.
- Use a well-kept, believable lived-in U.S. home or everyday space related to the product's use. Include only a few appropriate daily background objects and light signs of use.
- Use natural window light or soft practical interior light, natural skin tone and white balance, realistic texture, and an ordinary phone-camera medium or medium-close view.
- Use only slight handheld drift or a stable phone position. Do not use cinematic tracking, dramatic lighting, heavy filters, over-blur, aggressive zooms, staged luxury, damage, grime, or empty showroom interiors.
- Keep the creator and product together when practical. A key operation may move closer to the hands, but the creator's posture, gaze, and relationship to the product must remain understandable.
- If the operation needs two hands, use a fixed phone, tabletop, or third-party camera angle. Never describe an impossible self-filmed third-hand shot.
- Never use product-only beauty-shot sequences, a faceless desk montage, a shopping-channel presentation, or an exaggerated commercial before/after montage.

## Step 2: Video Direction Card

For each requested video, output a separate direction card in Simplified Chinese with exactly these sections:

1. Core selling point
2. Supported user pain point
3. Specific target user
4. Specific, generatable everyday life setting
5. Opening hook for the first 1-3 seconds
6. Core visual action
7. U.S. everyday Vlog visual setting
   - creator identity and natural state
   - concrete living space
   - limited appropriate background objects
   - lighting and color
   - phone angle and shooting method
   - cross-shot person and scene continuity
   - commercial-looking elements to avoid

Do not include a separate end-to-end sales-logic section. The five shot roles in Step 3 provide the narrative progression.

Choose one visualizable, stable-to-generate selling point. Different videos for the same SKU must differ substantively in at least two of: creator persona, room, hook type, supported demonstration, proof method, or closing reason. Changes limited to dialogue wording do not count.

## Step 3: Five-Shot Script

Input: completed Excel fact card, one direction card, and its Vlog visual setting.

Create S01-S05. Write every field in Simplified Chinese except the exact
American-English dialogue. Each shot must state:

1. Shot role
2. Picture content
3. One primary action
4. Start state
5. End state
6. Product portion that must be visible
7. Creator and setting requirements
8. Camera angle and physically possible shooting method
9. Natural Vlog detail
10. Exact American-English dialogue
11. Suggested final edit duration

Default roles are:

- S01: real everyday-problem hook
- S02: product appears naturally
- S03: key supported operation or key visible change
- S04: visible supported value during use
- S05: low-pressure reason to consider buying

S01 and S05 normally keep the creator naturally speaking to camera. S03 must make the correct hand placement, contact point, and product portion clear. S04 may only depict an observable or supported result. Dialogue must fit the retained time and avoid hype, unsupported superlatives, fabricated reviews, or fabricated long-term use.

Keep a complete script. A short shot summary alone is insufficient because subsequent stages need the start state, end state, scene, camera method, and Vlog details.

## Step 4: Minimum Reference-Material Plan

Input: complete script, Vlog visual setting, existing product images.

Output the P/R material plan in Simplified Chinese. Output P material only when a real product image will be uploaded later. For each P image, record identifier, Chinese name, used shots, and the structure it locks.

Create R anchors only when a person, setting, or non-product prop must stay consistent across two or more shots. For each R anchor, record identifier, used shots, what it locks, creation method, reference source, and its complete creation prompt when generation is needed. Do not create unused anchors.

End with a one-line minimum material list such as `P01 + P03 + R01 + R02`, and list any blocked operation or missing source image.

## Step 5: Final Static Storyboards in ChatGPT Web

Input: complete script, Vlog visual setting, minimum material plan, actual P images, and approved R images.

For each S01-S05, provide the following in Simplified Chinese:

1. Exact reference images to upload to ChatGPT web
2. One sentence on what each reference image locks
3. Complete Chinese first-frame image prompt
4. First-frame acceptance checklist

The prompt must specify the 9:16 frame, the shot's start state, correct person/product/hand relationship, necessary button/port/cable/accessory state, required product identity, and the everyday Vlog setting. Position the frame immediately before the primary action rather than after it completes.

Forbid subtitles, logos, watermarks, product-showroom styling, irrelevant objects, commercial lighting, and filters. Do not upload a product P image for S01 when the product should not appear.

The user generates R and S images in ChatGPT web and saves them locally. Record exact S01-S05 paths and inspection results before Step 6. An unapproved or unavailable first frame blocks only its dependent shot.

## Step 6: Image-to-Video Prompt Bundle

Input: approved S01-S05 images, complete script, Vlog visual setting, one voice setting, and the video model's minimum duration.

For every shot, provide the following in Simplified Chinese, except the exact English dialogue:

- shot identifier and the S image to upload
- generation duration, at or above the model minimum
- intended edit retention duration
- a copyable Chinese image-to-video prompt
- exact English dialogue
- dialogue mode: on-camera or voiceover

Each video prompt must describe only what changes after the approved first frame: one primary creator/product action, start-to-end movement, simple feasible camera motion, preserved product structure, Vlog phone-camera texture, continuity, dialogue, voice requirements, natural lip sync when visible, and excluded subtitles/music/second voice.

Do not restate static details already established in the first frame. Do not use complex camera movement. A video-generation duration is not the edit retention duration.

Until a provider API reference exists, do not send requests. Mark the video task as `prompt_ready` rather than `submitted`.

## Step 7: 自动拼接最终成片

当 S01-S05 都已成功生成后，使用 `scripts/assemble-final-video.ps1` 按 S01、S02、S03、S04、S05 的顺序拼接为 `videos/final-video.mp4`。保留每条原始分镜，绝不覆盖它们。

若某个镜头有重做版本，默认使用最高的 `-vN` 文件，例如 S04 同时有 `S04.mp4`、`S04-v2.mp4`、`S04-v3.mp4` 时，自动选用 `S04-v3.mp4`。脚本会验证五段齐全、自动定位 FFmpeg，并重新编码为兼容的竖版 MP4。任何一个镜头缺失或拼接失败都必须记录为阻塞，不得输出伪完整成片。

若用户明确授权一批新的付费 Omni 1.1 任务，可运行 `scripts/run-buming-omni-1.1-batch.ps1`。它会一次完成五个镜头的提交、轮询、下载和拼接，并始终保留旧版分镜。这个自动化仅覆盖已具备真实商品资料、已审核 S01-S05 首帧及已配置 API 密钥的 SKU 项目；它不替代产品事实审核或首帧素材确认。

## Review and Rework Routing

Review each generated image or video for factual product fidelity, correct operation, continuity, everyday Vlog realism, natural dialogue and audio, and visible AI defects such as malformed hands, face drift, floating objects, missing parts, or impossible movement.

- Product identity or missing reference problem: return to Step 4 or 5.
- Bad hand/product relationship or unsupported action: return to Step 3 or 5.
- Scene or creator lacks everyday Vlog realism: return to Step 2 or 5.
- Movement, lip sync, or audio problem: return to Step 6.

Do not mark a generated artifact approved merely because the prompt was approved.

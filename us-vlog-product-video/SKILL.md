---
name: us-vlog-product-video
description: Plan 15-20 second U.S. TikTok product videos in a natural everyday phone-Vlog style from a completed Excel product fact card. Use for video direction, five-shot scripts, reference planning, ChatGPT image prompts, or image-to-video prompt preparation.
metadata:
  short-description: Produce U.S. Vlog product-video plans from Excel facts
---

# U.S. Vlog Product Video

Use this skill to produce an evidence-based five-shot U.S. TikTok product-video plan. The input Excel is the completed first-step product fact card. Start at video direction; do not regenerate, embellish, or replace the product facts.

Read [the workflow reference](references/workflow.md) before performing any stage. Read [the state schema](references/project-state.md) when creating or resuming a SKU project.
For spreadsheet-driven batch work, also read [the batch automation reference](references/batch-automation.md).

## Workflow Routing

1. Read the selected SKU row, product images, and its requested video count from the completed Excel fact card. For a batch, first run `node scripts/read-product-input.mjs <Excel路径>` and `node scripts/initialize-batch-projects.mjs --excel <Excel路径>`; every SKU project must retain its own `product-config.json`.
2. For each requested video, create one direction card. It has six planning fields and one integrated U.S. everyday Vlog visual setting; then create the five-shot script and P/R minimum-material plan.
3. For static storyboards, prepare the ChatGPT web upload list and image prompts. The user creates and saves the actual R and S images in ChatGPT web. Record real local paths and approval status before progressing.
4. Prepare image-to-video prompts only after approved S01-S05 first frames exist. In addition to the human-readable prompt file, write `image-to-video-jobs.json` containing that SKU's exact five Chinese prompts, first-frame paths, model, resolution, and duration. Do not submit a video-generation API request until the provider's endpoint, authentication, upload, request, status, and download documentation is supplied and the user asks to execute it.
5. After S01-S05 have each generated successfully, assemble them in shot order into `videos/final-video.mp4`. Keep every source shot. When a shot has rework versions, use the highest `-vN` version by default. Use `scripts/assemble-final-video.ps1`; it validates all five source files and uses FFmpeg to normalize them into one 9:16 MP4.
6. For unattended execution after all approved first frames are present, first run `scripts/run-ready-video-batch.ps1` without `-Submit`; it reports which SKU projects are ready and which are missing images. Only after explicit authorization for a billable batch, rerun it with `-Submit`. It reads every SKU's own task file, de-duplicates unchanged submissions, polls terminal status, downloads each completed video without overwriting prior versions, then calls the assembly script.

## Required Boundaries

- The Excel product information, numbered selling points, and product images are the only source for product claims, operations, props that demonstrate claims, and structural details.
- Preserve the product's confirmed color, proportions, controls, ports, orientation, accessories, and operation. Record missing evidence as unresolved instead of guessing.
- A video has one core selling point, five shots, and one primary action per shot.
- Keep the same person, clothing, setting, and relevant non-product props continuous within a video.
- Create real U.S. everyday phone-Vlog scenes, not a studio commercial, a product-only montage, or an exaggerated before/after advertisement.

## Output Language

Unless the user explicitly asks for another language, write every user-facing
delivery and every SKU-project file in Simplified Chinese. This includes
direction cards, shot descriptions, P/R material plans, upload lists, image
prompts, acceptance checklists, state notes, review notes, and final status
messages. Preserve English only where the workflow explicitly requires exact
natural American-English dialogue, or where a source identifier must remain
unchanged (for example SKU, filename, file path, URL, product branding visible
in a source image, or provider task ID). Do not use English section headings
or English explanatory prose in generated SKU deliverables.

## ChatGPT Web Image Stage

ChatGPT web is a manual production step. Supply the exact reference-image list, prompt, and acceptance criteria for each R or S image. Do not state that an image exists, has been downloaded, or passed review until its actual file path and inspection result are recorded.

## Video API Stage

Until provider documentation is available, deliver a provider-neutral prompt bundle and leave video task fields pending. When documentation arrives, add a narrowly scoped provider reference and implementation. Never infer a relay API's payload, authentication, model capabilities, billing, polling, or download behavior.

The current verified provider reference for the user's selected Omni 1.1 model is [不鸣 AI Omni 1.1](references/providers/buming-omni-1.1.md). Use it only when the user selects that model. Preparing prompts does not authorize an API submission; submit only after the user explicitly asks to execute and supplies usable authentication.

For this local skill, provider authentication may come from `BUMING_API_KEY` or the untracked local file `.secrets/buming-api-key.txt`. Never print, copy into deliverables, or otherwise expose the credential.

## Deliverables

Maintain one SKU project state file using [the state schema](references/project-state.md). Store complete cards and scripts in that SKU folder, not only chat prose. Use the current state plus the specific images required by the current stage when resuming work.

Use [the deliverable-file contract](references/deliverable-files.md) for the required contents and stage gates of the files in each SKU folder. A completed Excel row and its product images are required before creating a real SKU project. The blank bundled Excel template is not product evidence and must not be treated as one.

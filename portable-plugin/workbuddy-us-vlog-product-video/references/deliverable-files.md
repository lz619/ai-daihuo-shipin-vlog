# SKU Deliverable-File Contract

Create a folder named with the SKU only after a completed Excel fact-card row
has been selected. Keep all production content inside that folder. The source
Excel remains authoritative for product facts; these files must identify the
source worksheet and row instead of restating unverified claims as facts.

## Output Language

All generated file content must be in Simplified Chinese, including headings,
field labels, descriptions, plans, prompts, checklists, status explanations,
and review notes. Keep only exact American-English dialogue in English. Do not
translate immutable source identifiers such as SKU, file path, URL, provider
task ID, or the fixed workflow status codes `pending`, `prompt_ready`,
`generated`, `approved`, `blocked`, and `failed`.

## Required Files

### `direction-cards.md`

Create one `## Video <number>` section for each requested video. Each section
contains exactly these six planning fields, followed by the visual-setting
section:

1. Core selling point
2. Supported user pain point
3. Specific target user
4. Specific, generatable everyday life setting
5. Opening hook for the first 1-3 seconds
6. Core visual action

Then add `### U.S. Everyday Vlog Visual Setting` with creator identity and
natural state, concrete living space, limited appropriate background objects,
lighting and color, phone angle and physically possible shooting method,
cross-shot continuity, and commercial-looking elements to avoid. Do not add a
separate end-to-end sales-logic section.

### `five-shot-scripts.md`

For every video, create complete `### S01` through `### S05` sections. Every
shot records: shot role, picture content, one primary action, start state, end
state, product portion that must be visible, creator and setting requirements,
camera angle and physically possible shooting method, natural Vlog detail,
exact American-English dialogue, and suggested final edit duration.

Use these fixed roles:

- `S01` — real everyday-problem hook
- `S02` — the product appears naturally
- `S03` — key operation or key visible change
- `S04` — visible value during use
- `S05` — a low-pressure reason to consider buying

### `reference-plan.md`

List only the minimum P and R materials needed for the script.

- Each P material names the real product image to upload, the shots that use
  it, and the product structure it locks.
- Each R anchor is included only when a person, setting, or non-product prop
  must remain consistent across two or more shots. Record its identifier, used
  shots, what it locks, source or creation method, and its complete creation
  prompt if it must be generated.
- End with a one-line minimum material list and all missing or blocked source
  materials. Do not invent a P or R file path.

### `static-storyboard-prompts.md`

For every S01-S05, record the exact upload list for ChatGPT web, what each
upload locks, a complete Chinese first-frame prompt, and a first-frame
acceptance checklist. The prompt describes the 9:16 start state immediately
before the one primary action. It must preserve approved product identity and
the ordinary U.S. phone-Vlog setting. It excludes subtitles, logos,
watermarks, commercial styling, filters, and irrelevant objects.

The user creates the R and S images manually in ChatGPT web. After each image
is saved, record its actual local path, inspection result, and status in
`project-state.md`. A prompt is not an image, and a generated file is not
approved until reviewed.

### `image-to-video-prompts.md`

Write this file only for shots whose S01-S05 first-frame image is approved.
For each eligible shot, provide the S-image path to upload, generation duration
at or above the selected model minimum, intended final edit duration, a
copyable Chinese image-to-video prompt, exact English dialogue, and whether
the dialogue is on-camera or voiceover. Describe only change after the first
frame: one action, feasible movement, simple camera motion, continuity,
natural lip sync when visible, and no subtitle, music, or second voice.

Until the user provides provider documentation covering authentication, upload,
submission, status/polling, and download, set every video task to
`prompt_ready`; do not infer or submit API requests.

### `product-config.json`

This is the SKU-local copy of the Excel row made by the batch initializer. It
records source workbook/row, product facts, selling points, requested video
count, selected model, resolution, optional BGM path, and the queue status.
It is configuration, not a substitute for real product evidence.

### `image-to-video-jobs.json`

Create this machine-readable companion only after the five first frames are
approved. It must contain exactly S01-S05 and, for each shot, the real
`first_frame` path, `duration_seconds`, Chinese `prompt`, and exact English
dialogue. At the top level it contains the SKU-selected model, 9:16 aspect
ratio, and resolution. The submission scripts read this file and never contain
another SKU's product prompt.

## State and Stage Gates

| Stage | Required status before advancing |
| --- | --- |
| Direction and script | Complete files plus recorded review status |
| P/R planning | Complete plan; actual P paths and any required R anchors recorded before frame generation |
| Static frames | Every dependent S image has a real local path and `approved` inspection status |
| Image-to-video prompts | Write only for approved S images; leave blocked shots explicitly blocked |
| API execution | Not eligible until the provider documentation is supplied and the user asks to execute |

Use only `pending`, `prompt_ready`, `generated`, `approved`, `blocked`, or
`failed` for frame and video status. A `blocked` or `failed` status must state
the exact missing material, review defect, or provider-documentation gap.

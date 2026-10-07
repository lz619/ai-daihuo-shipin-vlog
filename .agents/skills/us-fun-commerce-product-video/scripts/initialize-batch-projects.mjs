import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { readProductInput, defaultExcelPath } from "./read-product-input.mjs";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));

function parseArguments(args) {
  const result = {};
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === "--overwrite") result.overwrite = true;
    if (argument === "--excel") result.excel = args[index + 1];
    if (argument === "--projects") result.projects = args[index + 1];
    if (argument === "--sku") result.sku = args[index + 1];
    if (argument === "--video-count") result.videoCount = Number(args[index + 1]);
  }
  return result;
}

function safeSku(sku) {
  if (!/^[A-Za-z0-9_-]+$/.test(sku)) throw new Error(`SKU 只能使用字母、数字、下划线或连字符：${sku}`);
  return sku;
}

function createProjectState(product) {
  return `# SKU 项目状态\n\n## 来源\n\n- Excel 路径：${product.source_excel_path}\n- 工作表与行：${product.source_worksheet}，第 ${product.source_row} 行\n- SKU：${product.sku}\n- 产品图片路径：${product.product_images.map((item) => `\n  - ${item}`).join("")}\n\n## 自动化队列\n\n- 队列状态：待规划\n- 视频模型：${product.video_model}\n- 分辨率：${product.resolution}\n- 当前阻塞：记录用户制作配置，填写 production-plan.json 并通过 planning 编译，再制作五张首帧。\n`;
}

const args = parseArguments(process.argv.slice(2));
args.excel ||= defaultExcelPath;
if (args.videoCount !== undefined && (!args.sku || !Number.isInteger(args.videoCount) || args.videoCount < 1)) {
  throw new Error("--video-count 需要同时指定 --sku，且数量必须为正整数。");
}
const projectsDirectory = args.projects ? path.resolve(args.projects) : path.resolve(scriptDirectory, "..", "projects");
const input = await readProductInput(path.resolve(args.excel));
if (args.sku && input.products.filter(row => row.sku === args.sku).length !== 1) {
  throw new Error(`指定 Excel 中 SKU ${args.sku} 必须唯一存在：${input.excel_path}`);
}
const results = [];

for (const sourceRow of input.products) {
  const row = { ...sourceRow, issues: [...sourceRow.issues] };
  if (args.sku && row.sku !== args.sku) continue;
  if (args.videoCount !== undefined) {
    row.requested_video_count = args.videoCount;
    row.issues = row.issues.filter(issue => issue !== "视频数量必须是大于 0 的整数");
    row.valid = row.issues.length === 0;
  }
  if (row.queue_status === "跳过" || (!args.sku && row.queue_status === "已完成")) {
    results.push({ sku: row.sku, status: "skipped", reason: `Excel 队列状态为${row.queue_status}` });
    continue;
  }
  if (!row.valid) {
    results.push({ sku: row.sku || `第${row.source_row}行`, status: "blocked", issues: row.issues });
    continue;
  }

  const sku = safeSku(row.sku);
  const projectDirectory = path.join(projectsDirectory, sku);
  const configPath = path.join(projectDirectory, "product-config.json");
  await fs.mkdir(projectDirectory, { recursive: true });
  await Promise.all(["anchors", "first-frames", "videos"].map((folder) => fs.mkdir(path.join(projectDirectory, folder), { recursive: true })));

  const videoDirectories = [];
  if (row.requested_video_count > 1) {
    for (let videoIndex = 1; videoIndex <= row.requested_video_count; videoIndex += 1) {
      const videoDirectory = path.join(projectDirectory, `video-${String(videoIndex).padStart(2, "0")}`);
      await fs.mkdir(videoDirectory, { recursive: true });
      await Promise.all(["anchors", "first-frames", "videos"].map((folder) => fs.mkdir(path.join(videoDirectory, folder), { recursive: true })));
      videoDirectories.push(videoDirectory);
    }
  }

  const product = {
    schema_version: 1,
    source_excel_path: input.excel_path,
    source_worksheet: input.worksheet,
    source_row: row.source_row,
    sku,
    product_name: row.product_name,
    product_images: row.product_images,
    product_information: row.product_information,
    selling_points: row.selling_points,
    requested_video_count: row.requested_video_count,
    ...(args.videoCount !== undefined ? { requested_video_count_override: { source: "user_request", source_excel_value: sourceRow.source_video_count_text, effective_value: args.videoCount } } : {}),
    queue_status: row.queue_status,
    video_model: row.video_model,
    resolution: row.resolution,
    bgm_file: row.bgm_file,
    project_note: row.project_note,
  };

  const configExists = await fs.stat(configPath).then(() => true).catch(() => false);
  if (!configExists || args.overwrite) {
    await fs.writeFile(configPath, `${JSON.stringify(product, null, 2)}\n`, "utf8");
  }

  const statePath = path.join(projectDirectory, "project-state.md");
  const stateExists = await fs.stat(statePath).then(() => true).catch(() => false);
  if (!stateExists) await fs.writeFile(statePath, createProjectState(product), "utf8");
  results.push({ sku, status: configExists && !args.overwrite ? "existing" : "initialized", project_directory: projectDirectory, video_directories: videoDirectories });
}

console.log(JSON.stringify({ excel: input.excel_path, projects_directory: projectsDirectory, results }, null, 2));

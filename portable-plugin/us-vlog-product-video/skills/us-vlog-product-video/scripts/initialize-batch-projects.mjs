import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { readProductInput } from "./read-product-input.mjs";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));

function parseArguments(args) {
  const result = {};
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === "--overwrite") result.overwrite = true;
    if (argument === "--excel") result.excel = args[index + 1];
    if (argument === "--projects") result.projects = args[index + 1];
  }
  return result;
}

function safeSku(sku) {
  if (!/^[A-Za-z0-9_-]+$/.test(sku)) throw new Error(`SKU 只能使用字母、数字、下划线或连字符：${sku}`);
  return sku;
}

function createProjectState(product) {
  return `# SKU 项目状态\n\n## 来源\n\n- Excel 路径：${product.source_excel_path}\n- 工作表与行：${product.source_worksheet}，第 ${product.source_row} 行\n- SKU：${product.sku}\n- 产品图片路径：${product.product_images.map((item) => `\n  - ${item}`).join("")}\n\n## 自动化队列\n\n- 队列状态：待规划\n- 视频模型：${product.video_model}\n- 分辨率：${product.resolution}\n- 当前阻塞：需要根据 Excel 商品事实生成方向卡、五镜头脚本、GPT 网页静态首帧提示词。\n`;
}

const args = parseArguments(process.argv.slice(2));
if (!args.excel) throw new Error("需要 --excel <Excel路径>。");
const projectsDirectory = args.projects ? path.resolve(args.projects) : path.resolve(scriptDirectory, "..", "projects");
const input = await readProductInput(path.resolve(args.excel));
const results = [];

for (const row of input.products) {
  if (row.queue_status === "跳过") {
    results.push({ sku: row.sku, status: "skipped", reason: "Excel 队列状态为跳过" });
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
  results.push({ sku, status: configExists && !args.overwrite ? "existing" : "initialized", project_directory: projectDirectory });
}

console.log(JSON.stringify({ excel: input.excel_path, projects_directory: projectsDirectory, results }, null, 2));

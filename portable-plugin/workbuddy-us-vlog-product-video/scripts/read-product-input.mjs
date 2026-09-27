import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const runtimeCandidates = [
  process.env.UGC_ARTIFACT_RUNTIME_ROOT,
  path.resolve(scriptDirectory, "..", ".automation-runtime"),
  path.join(os.homedir(), ".cache", "codex-runtimes", "codex-primary-runtime", "dependencies", "node"),
].filter(Boolean);
const moduleRoot = runtimeCandidates.find((candidate) => fs.existsSync(path.join(candidate, "node_modules", "@oai", "artifact-tool")));
if (!moduleRoot) {
  throw new Error("未找到 Codex 表格运行库。请在已安装 Codex 的电脑中运行，或将 UGC_ARTIFACT_RUNTIME_ROOT 指向包含 node_modules 的运行库目录。");
}
const require = createRequire(path.join(moduleRoot, "artifact-loader.cjs"));
const { FileBlob, SpreadsheetFile } = require("@oai/artifact-tool");

const requiredHeaders = ["SKU", "产品名称", "产品图片", "产品信息", "卖点", "视频数量"];
const optionalHeaders = ["队列状态", "视频模型", "分辨率", "BGM 文件路径（可选）", "项目备注（可选）"];

function valueOf(value) {
  return value === null || value === undefined ? "" : String(value).trim();
}

function getHeaderIndex(headers, name) {
  const index = headers.findIndex((header) => valueOf(header) === name);
  return index >= 0 ? index : null;
}

function extractImagePaths(text) {
  return valueOf(text)
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => /\.(png|jpe?g|webp)$/i.test(line));
}

export async function readProductInput(excelPath) {
  const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(excelPath));
  const sheet = workbook.worksheets.getItem("产品输入");
  if (!sheet) throw new Error("Excel 中缺少“产品输入”工作表。");

  const usedRange = sheet.getUsedRange(true);
  const values = usedRange.values;
  if (!values || values.length < 2) return { excel_path: excelPath, products: [], errors: ["产品输入表没有可读取的数据行。"] };

  const headers = values[0];
  const headerIndexes = Object.fromEntries([...requiredHeaders, ...optionalHeaders].map((name) => [name, getHeaderIndex(headers, name)]));
  const missingHeaders = requiredHeaders.filter((name) => headerIndexes[name] === null);
  if (missingHeaders.length > 0) {
    throw new Error(`Excel 缺少必填列：${missingHeaders.join("、")}`);
  }

  const products = values.slice(1).map((row, index) => {
    const field = (name) => {
      const column = headerIndexes[name];
      return column === null ? "" : valueOf(row[column]);
    };
    const sku = field("SKU");
    const requestedVideos = Number(field("视频数量"));
    const images = extractImagePaths(field("产品图片"));
    const queueStatus = field("队列状态") || "待规划";
    const issues = [];
    if (!sku) issues.push("缺少 SKU");
    if (!field("产品名称")) issues.push("缺少产品名称");
    if (images.length === 0) issues.push("产品图片列未找到图片完整路径");
    if (!field("产品信息")) issues.push("缺少产品信息");
    if (!field("卖点")) issues.push("缺少卖点");
    if (!Number.isInteger(requestedVideos) || requestedVideos < 1) issues.push("视频数量必须是大于 0 的整数");

    return {
      source_row: index + 2,
      sku,
      product_name: field("产品名称"),
      product_image_text: field("产品图片"),
      product_images: images,
      product_information: field("产品信息"),
      selling_points: field("卖点"),
      requested_video_count: requestedVideos,
      queue_status: queueStatus,
      video_model: field("视频模型") || "omni-1.1",
      resolution: field("分辨率") || "720P",
      bgm_file: field("BGM 文件路径（可选）") || null,
      project_note: field("项目备注（可选）") || null,
      valid: issues.length === 0,
      issues,
    };
  }).filter((product) => {
    // 模板空行自带说明文字；只有用户真正开始填写 SKU 或产品名称时才纳入校验。
    return product.sku || product.product_name;
  });

  return { excel_path: excelPath, worksheet: "产品输入", products };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const excelPath = process.argv[2];
  if (!excelPath) throw new Error("用法：node read-product-input.mjs <Excel路径>");
  console.log(JSON.stringify(await readProductInput(excelPath), null, 2));
}

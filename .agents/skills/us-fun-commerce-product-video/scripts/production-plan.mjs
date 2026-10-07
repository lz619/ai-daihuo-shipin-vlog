import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { isDeepStrictEqual } from 'node:util';

const scriptPath = fileURLToPath(import.meta.url);
const schema = JSON.parse(fs.readFileSync(path.join(path.dirname(scriptPath), '../references/production-plan.schema.json'), 'utf8'));
const ids = ['S01', 'S02', 'S03', 'S04', 'S05'];
const roles = ['hook', 'bridge', 'use', 'proof', 'cta'];
const labels = ['强钩子', '钩子揭示与产品出现', '正确使用', '可见证据和价值', '兑现与购买行动'];
const readJson = p => JSON.parse(fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, ''));
const stable = value => Array.isArray(value) ? value.map(stable) : value !== null && typeof value === 'object' ? Object.fromEntries(Object.keys(value).sort().map(k => [k, stable(value[k])])) : value;
const hash = value => crypto.createHash('sha256').update(typeof value === 'string' ? value : JSON.stringify(stable(value))).digest('hex');
const fileHash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const resolved = (root, p) => path.resolve(root, p);
const samePath = (a, b) => (process.platform === 'win32' ? a.toLowerCase() === b.toLowerCase() : a === b);
const round = n => Math.round(n * 1e6) / 1e6;
function requireCondition(ok, message) { if (!ok) throw new Error(message); }
function fileExists(p) { return fs.existsSync(p) && fs.statSync(p).isFile(); }
function validateSchema(value, rule, where = '$') {
  if (rule.$ref) return validateSchema(value, rule.$ref.split('/').slice(1).reduce((s, key) => s[key], schema), where);
  const types = rule.type ? [].concat(rule.type) : [];
  const match = t => t === 'null' ? value === null : t === 'array' ? Array.isArray(value) : t === 'object' ? value !== null && typeof value === 'object' && !Array.isArray(value) : t === 'integer' ? Number.isInteger(value) : t === 'number' ? typeof value === 'number' && Number.isFinite(value) : typeof value === t;
  if (types.length) requireCondition(types.some(match), `${where}：类型必须为 ${types.join('/')}`);
  if ('const' in rule) requireCondition(isDeepStrictEqual(value, rule.const), `${where}：必须为 ${JSON.stringify(rule.const)}`);
  if (rule.enum) requireCondition(rule.enum.some(x => isDeepStrictEqual(value, x)), `${where}：不在允许值中`);
  if (typeof value === 'string' && rule.minLength) requireCondition(value.trim().length >= rule.minLength, `${where}：不能为空`);
  if (typeof value === 'number') {
    if ('minimum' in rule) requireCondition(value >= rule.minimum, `${where}：不能小于 ${rule.minimum}`);
    if ('maximum' in rule) requireCondition(value <= rule.maximum, `${where}：不能大于 ${rule.maximum}`);
    if ('exclusiveMinimum' in rule) requireCondition(value > rule.exclusiveMinimum, `${where}：必须大于 ${rule.exclusiveMinimum}`);
  }
  if (Array.isArray(value)) {
    if ('minItems' in rule) requireCondition(value.length >= rule.minItems, `${where}：至少 ${rule.minItems} 项`);
    if ('maxItems' in rule) requireCondition(value.length <= rule.maxItems, `${where}：最多 ${rule.maxItems} 项`);
    if (rule.uniqueItems) requireCondition(new Set(value.map(x => JSON.stringify(x))).size === value.length, `${where}：不能重复`);
    value.forEach((x, i) => validateSchema(x, rule.items, `${where}[${i}]`));
  } else if (value !== null && typeof value === 'object') {
    for (const key of rule.required || []) requireCondition(Object.hasOwn(value, key), `${where}.${key}：缺少必填字段`);
    for (const [key, x] of Object.entries(value)) {
      if (!rule.properties?.[key]) requireCondition(rule.additionalProperties !== false, `${where}.${key}：未知字段`);
      else validateSchema(x, rule.properties[key], `${where}.${key}`);
    }
  }
}

export function loadPlan(project) {
  const planPath = path.join(project, 'production-plan.json');
  requireCondition(fileExists(planPath), '缺少 production-plan.json；先初始化并填写统一制作计划。');
  const plan = readJson(planPath);
  validateSchema(plan, schema);
  return plan;
}

export function validatePlan(plan, project) {
  validateSchema(plan, schema);
  const productPath = resolved(project, plan.source.product_config);
  requireCondition(fileExists(productPath), 'source.product_config 不存在');
  const product = readJson(productPath);
  requireCondition(product.sku === plan.sku && product.source_row === plan.source.row && product.source_worksheet === plan.source.worksheet && samePath(resolved(project, product.source_excel_path), resolved(project, plan.source.excel_path)), '计划 SKU/Excel/行号与 product-config.json 来源不一致');
  requireCondition(fileExists(resolved(project, plan.source.excel_path)), '来源 Excel 不存在');
  const realImages = (product.product_images || []).map(p => resolved(project, p));
  const sourceImage = p => realImages.some(x => samePath(x, resolved(project, p))) && fileExists(resolved(project, p));
  const factIds = new Set();
  for (const fact of plan.facts) {
    requireCondition(!factIds.has(fact.id), `事实编号重复：${fact.id}`); factIds.add(fact.id);
    requireCondition(fact.source_fields.length || fact.source_images.length, `${fact.id}：必须记录来源字段或真实图片`);
    fact.source_images.forEach(p => requireCondition(sourceImage(p), `${fact.id}：图片不属于本 SKU 的真实来源或不存在：${p}`));
  }
  const checkFacts = (list, where) => list.forEach(id => requireCondition(factIds.has(id), `${where}：未知事实编号 ${id}`));
  for (const [key, value] of Object.entries(plan.direction)) if (value?.fact_ids) checkFacts(value.fact_ids, `direction.${key}`);
  const refs = new Map();
  for (const ref of plan.references) {
    requireCondition(!refs.has(ref.id), `参考图编号重复：${ref.id}`); refs.set(ref.id, ref);
    if (ref.kind === 'product') requireCondition(sourceImage(ref.path), `${ref.id}：商品图必须来自本 SKU Excel 的真实图片`);
    if (ref.pose_master) requireCondition(ref.kind === 'product' && ref.angle_degrees >= 30 && ref.angle_degrees <= 60 && ref.body_and_connection_visible, `${ref.id}：PoseMaster 必须是同时看见主体和连接结构的真实 30°–60° 商品图`);
  }
  let total = 0; let firstAppearance = null;
  const framePaths = [];
  plan.shots.forEach((shot, i) => {
    requireCondition(shot.id === ids[i] && shot.role === roles[i], `shots[${i}]：镜头顺序/职责必须为 ${ids[i]}/${roles[i]}`);
    requireCondition(round(shot.trim_start_seconds + shot.edit_duration_seconds) <= shot.duration_seconds, `${shot.id}：起剪点＋保留秒数超过生成秒数`);
    checkFacts(shot.fact_ids, shot.id);
    shot.reference_ids.forEach(id => requireCondition(refs.has(id), `${shot.id}：未知参考图 ${id}`));
    if (shot.product_visible) {
      requireCondition(shot.reference_ids.some(id => refs.get(id).kind === 'product'), `${shot.id}：商品可见但缺少真实商品参考图`);
      requireCondition(typeof shot.reveal_offset_seconds === 'number' && shot.reveal_offset_seconds < shot.edit_duration_seconds, `${shot.id}：露品偏移必须落在保留片段内`);
      if (firstAppearance === null) firstAppearance = round(total + shot.reveal_offset_seconds);
    } else requireCondition(shot.reveal_offset_seconds === null, `${shot.id}：不露品时 reveal_offset_seconds 必须为 null`);
    if (shot.spatial_relation !== 'none') {
      requireCondition(shot.product_visible && shot.reference_ids.includes(shot.pose_master_ref) && refs.get(shot.pose_master_ref)?.pose_master, `${shot.id}：空间连接镜头必须引用有效 PoseMaster`);
    } else requireCondition(shot.pose_master_ref === null, `${shot.id}：无空间连接时 pose_master_ref 应为 null`);
    const frame = resolved(project, shot.first_frame);
    requireCondition(!framePaths.some(p => samePath(p, frame)), `${shot.id}：五张首帧必须使用不同的文件路径`);
    framePaths.push(frame); total += shot.edit_duration_seconds;
  });
  total = round(total);
  requireCondition(total >= 15 && total <= 20, `五镜头保留时长 ${total} 秒，必须合计 15–20 秒`);
  requireCondition(firstAppearance !== null && (plan.shots[0].product_visible || plan.shots[1].product_visible), '商品必须最迟在 S02 露出');
  return { total_edit_duration_seconds: total, product_first_appearance_seconds: firstAppearance };
}

export function framePlanHash(plan, project) {
  return hash({ sku: plan.sku, video_id: plan.video_id, vlog: plan.direction.vlog, references: plan.references.map(r => ({...r, sha256: fileExists(resolved(project,r.path)) ? fileHash(resolved(project,r.path)) : null})), shots: plan.shots.map(s => {
    const {id, visual, main_action, start_state, end_state, visible_product_parts, continuity, camera, vlog_detail, product_visible, spatial_relation, pose_master_ref, reference_ids, first_frame, static_prompt, acceptance_checks} = s;
    return {id, visual, main_action, start_state, end_state, visible_product_parts, continuity, camera, vlog_detail, product_visible, spatial_relation, pose_master_ref, reference_ids, first_frame, static_prompt, acceptance_checks};
  }) });
}

export function validateApproval(plan, project) {
  const reviewPath = path.join(project, 'first-frame-review.json');
  requireCondition(fileExists(reviewPath), '等待用户验收五张首帧并明确继续');
  const review = readJson(reviewPath);
  requireCondition(review.status === 'approved' && typeof review.user_confirmation === 'string' && review.user_confirmation.trim(), '首帧尚未记录用户明确批准');
  requireCondition(review.model === plan.production.model && review.resolution === plan.production.resolution, '模型/分辨率与首帧确认记录不一致');
  for (const ref of plan.references) if (plan.shots.some(s => s.reference_ids.includes(ref.id))) requireCondition(fileExists(resolved(project,ref.path)), `${ref.id}：引用的参考素材尚未保存`);
  requireCondition(review.frame_plan_sha256 === framePlanHash(plan, project), '首帧计划或参考素材已变更，需重新展示并取得确认');
  requireCondition(Array.isArray(review.frames) && review.frames.length === 5, '批准记录必须包含五张首帧');
  for (const shot of plan.shots) {
    const p = resolved(project, shot.first_frame);
    requireCondition(fileExists(p) && fs.statSync(p).size <= 10 * 1024 * 1024, `${shot.id}：首帧不存在或超过 10MB`);
    const entries = review.frames.filter(x => x.shot === shot.id);
    requireCondition(entries.length === 1 && samePath(resolved(project, entries[0].path), p) && String(entries[0].sha256).toLowerCase() === fileHash(p), `${shot.id}：首帧内容/路径未批准或已经改变`);
  }
}

function makeJobs(plan, project) {
  validateApproval(plan, project);
  return {
    schema_version: 1, plan_sha256: hash(plan), model: plan.production.model, aspect_ratio: plan.production.aspect_ratio, resolution: plan.production.resolution,
    jobs: plan.shots.map(s => {
      requireCondition(s.motion_prompt.trim(), `${s.id}：批准后仍缺少 motion_prompt`);
      const firstFrame = resolved(project, s.first_frame);
      const prompt = `${s.motion_prompt}\n口播方式：${s.delivery === 'on_camera' ? '同一创作者对镜口播，口型自然同步' : '同一创作者画外口播'}。只说以下完整美式英语台词：${JSON.stringify(s.dialogue)}\n保持获批首帧的商品结构、人物、服装、环境和自然光；无字幕、水印、背景音乐、第二说话人或额外台词。`;
      const requestFingerprint = hash({model: plan.production.model, aspect_ratio: plan.production.aspect_ratio, resolution: plan.production.resolution, shot: s.id, frame_sha256: fileHash(firstFrame), duration_seconds: s.duration_seconds, prompt});
      return {shot: s.id, first_frame: firstFrame, duration_seconds: s.duration_seconds, edit_duration_seconds: s.edit_duration_seconds, trim_start_seconds: s.trim_start_seconds, dialogue: s.dialogue, prompt, request_fingerprint: requestFingerprint};
    })
  };
}

function renderPlanning(plan, derived) {
  const d = plan.direction; const evidence = c => `${c.text}（事实：${c.fact_ids.join('、')}）`;
  const header = '> 自动从 production-plan.json 生成；修改请回到 JSON 后重新 compile，勿单独改本文件。\n\n';
  const direction = `# 视频方向卡\n\n${header}- SKU：${plan.sku} / ${plan.video_id}\n- 核心卖点：${evidence(d.core_selling_point)}\n- 已证实痛点：${evidence(d.confirmed_pain_point)}\n- 具体受众：${evidence(d.target_audience)}\n- 生活情境：${d.life_situation}\n- 强钩子（S01视觉事件）：${d.hook.behavior}\n- 悬念/冲击/新奇反差机制：${d.hook.humor_source}\n- S02产品接桥：${d.hook.bridge_to_product}\n- 静音可理解：${d.hook.muted_readable ? '是' : '否，需人工评审'}\n- 商品首次出现：${derived.product_first_appearance_seconds} 秒（由镜头保留秒数及露品偏移计算）\n- 视觉证明方式：${d.proof.method}（事实：${d.proof.fact_ids.join('、')}）\n- 购买理由：${evidence(d.purchase_reason)}\n- 总剪辑时长：${derived.total_edit_duration_seconds} 秒\n\n## Vlog 设定\n${Object.entries(d.vlog).map(([k,v]) => `- ${k}：${v}`).join('\n')}\n\n## 商品事实来源\n${plan.facts.map(f => `- ${f.id}：${f.text}；来源字段：${f.source_fields.join('、')}；图片：${f.source_images.join('、')}`).join('\n')}\n`;
  const fields = {visual:'画面',main_action:'唯一主要动作',start_state:'起始状态',end_state:'结束状态',visible_product_parts:'商品可见部分',continuity:'连续性',camera:'机位',vlog_detail:'自然 Vlog 细节',dialogue:'美式英语口播',delivery:'口播方式',duration_seconds:'模型生成秒数',edit_duration_seconds:'剪辑保留秒数',trim_start_seconds:'起剪秒数'};
  const scripts = `# 五镜头脚本\n\n${header}总时长 ${derived.total_edit_duration_seconds} 秒；首次露品 ${derived.product_first_appearance_seconds} 秒。\n\n` + plan.shots.map((s,i) => `## ${s.id} ${labels[i]}\n${Object.entries(fields).map(([k,label]) => `- ${label}：${s[k]}`).join('\n')}\n- 事实：${s.fact_ids.join('、')}\n- 空间关系：${s.spatial_relation}；PoseMaster：${s.pose_master_ref || '不启用'}\n`).join('\n');
  const references = `# 最小参考素材计划\n\n${header}` + plan.references.map(r => `- ${r.id}（${r.kind}${r.pose_master ? ' / PoseMaster' : ''}）：${r.path}\n  锁定：${r.locks}\n`).join('\n') + '\n## 每镜头上传清单\n' + plan.shots.map(s => `- ${s.id}：${s.reference_ids.join('、') || '无'}；首帧：${s.first_frame}`).join('\n') + '\n';
  const imageJobs = plan.shots.map(s => {
    const refs = s.reference_ids.map(id => plan.references.find(r => r.id === id));
    const prompt = `${s.static_prompt}\n起始状态：${s.start_state}。机位：${s.camera}。连续性：${s.continuity}。\n上传参考图及职责：${refs.map(r => `${r.id}：${r.locks}`).join('；') || '无'}。` + (s.pose_master_ref ? `\n${s.pose_master_ref} 是商品三维姿态的最高优先级 PoseMaster：保留主体方向、连接轴线、插入深度、接触面和相对比例；正面图只补外观，不能改写空间姿态。` : '') + '\n9:16 写实美区日常手机 Vlog，自然生活光线。不得重设计商品、添加未知功能、字幕、水印或广告灯效。';
    return {shot:s.id,first_frame:resolved(derived.project,s.first_frame),prompt,references:refs.map(r => ({id:r.id,path:resolved(derived.project,r.path),locks:r.locks,pose_master:r.pose_master})),acceptance_checks:s.acceptance_checks};
  });
  const staticPrompts = `# 五张静态首帧提示词\n\n${header}` + imageJobs.map(s => `## ${s.shot}\n- 首帧路径：${s.first_frame}\n- 参考图：${s.references.map(r => r.id).join('、') || '无'}\n\n${s.prompt}\n\n验收：\n${s.acceptance_checks.map(x => `- ${x}`).join('\n')}\n`).join('\n');
  return {'direction-cards.md':direction,'five-shot-scripts.md':scripts,'reference-plan.md':references,'static-storyboard-prompts.md':staticPrompts,'first-frame-jobs.json':JSON.stringify({schema_version:1,frame_plan_sha256:framePlanHash(plan,derived.project),jobs:imageJobs},null,2)+'\n'};
}

export function compilePlan(project, stage) {
  const plan = loadPlan(project); const derived = validatePlan(plan, project);
  requireCondition(['planning','video'].includes(stage), 'compile stage 只能为 planning/video');
  // Validate all dependent data before writing any generated deliverable.
  const jobs = stage === 'video' ? makeJobs(plan, project) : null;
  const outputs = renderPlanning(plan, {...derived,project});
  if (jobs) {
    outputs['image-to-video-jobs.json'] = JSON.stringify(jobs, null, 2) + '\n';
    outputs['image-to-video-prompts.md'] = '# 图生视频提示词\n\n> 自动从 production-plan.json 生成；勿单独编辑。\n\n' + jobs.jobs.map(j => `## ${j.shot}\n首帧：${j.first_frame}\n生成 ${j.duration_seconds} 秒；保留 ${j.edit_duration_seconds} 秒；起剪 ${j.trim_start_seconds} 秒。\n\n${j.prompt}\n`).join('\n');
  }
  for (const [name, text] of Object.entries(outputs)) fs.writeFileSync(path.join(project,name),text,'utf8');
  return {status:'compiled',stage,...derived,files:Object.keys(outputs),frame_plan_sha256:framePlanHash(plan,project)};
}

export function validateJobs(project) {
  const plan = loadPlan(project); const derived = validatePlan(plan, project);
  const expected = makeJobs(plan, project);
  requireCondition(fileExists(path.join(project,'image-to-video-jobs.json')), '缺少派生任务文件，先 compile --stage video');
  requireCondition(isDeepStrictEqual(readJson(path.join(project,'image-to-video-jobs.json')), expected), '视频任务与 production-plan.json 不一致或已过期；从统一计划重新 compile --stage video');
  return {status:'validated',stage:'jobs',...derived,frame_plan_sha256:framePlanHash(plan,project)};
}

function findParentFile(project, name) {
  let folder = project;
  while (true) { const candidate = path.join(folder,name); if (fileExists(candidate)) return candidate; const parent=path.dirname(folder); if(parent===folder) return null; folder=parent; }
}
export function initializePlan(project) {
  const target = path.join(project,'production-plan.json');
  requireCondition(!fs.existsSync(target), 'production-plan.json 已存在；不会覆盖已有计划');
  const productPath = findParentFile(project,'product-config.json');
  const configPath = findParentFile(project,'production-config.json');
  requireCondition(productPath && configPath, '先初始化 Excel 商品项目并记录本轮 production-config.json，再 init 计划');
  const product=readJson(productPath); const production=readJson(configPath);
  const blankClaim=()=>({text:'',fact_ids:[]});
  const plan={schema_version:1,sku:product.sku,video_id:path.basename(project),source:{product_config:productPath,excel_path:product.source_excel_path,worksheet:product.source_worksheet,row:product.source_row},production:{provider:production.provider,model:production.model,resolution:production.resolution,aspect_ratio:production.aspect_ratio,spoken_language:production.spoken_language},facts:[],direction:{core_selling_point:blankClaim(),confirmed_pain_point:blankClaim(),target_audience:blankClaim(),life_situation:'',hook:{behavior:'',humor_source:'',bridge_to_product:'',muted_readable:false},proof:{method:'',fact_ids:[]},purchase_reason:blankClaim(),vlog:{creator:'',wardrobe:'',setting:'',lighting:'',camera_style:'',continuity:''}},references:(product.product_images||[]).map((p,i)=>({id:`P${String(i+1).padStart(2,'0')}`,kind:'product',path:p,locks:'',pose_master:false,angle_degrees:null,body_and_connection_visible:false})),shots:ids.map((id,i)=>({id,role:roles[i],visual:'',main_action:'',start_state:'',end_state:'',visible_product_parts:'',continuity:'',camera:'',vlog_detail:'',fact_ids:[],dialogue:'',delivery:'voiceover',product_visible:i>0,reveal_offset_seconds:i>0?0:null,duration_seconds:4,edit_duration_seconds:3.5,trim_start_seconds:0,spatial_relation:'none',pose_master_ref:null,reference_ids:[],first_frame:`first-frames/${id}.png`,static_prompt:'',acceptance_checks:[],motion_prompt:''}))};
  fs.writeFileSync(target,JSON.stringify(plan,null,2)+'\n','utf8');
  return {status:'draft_created',path:target,message:'空创意字段须由模型根据真实资料填写；草稿尚不通过校验。'};
}

if (process.argv[1] && path.resolve(process.argv[1]) === scriptPath) {
  try {
    const [command,...args]=process.argv.slice(2); const get=k=>{const i=args.indexOf(k);return i>=0?args[i+1]:undefined;};
    const project=path.resolve(get('--project')||'.'); const stage=get('--stage')||'planning';
    let result;
    if(command==='init') result=initializePlan(project);
    else if(command==='compile') result=compilePlan(project,stage);
    else if(command==='validate') {
      if(stage==='jobs') result=validateJobs(project);
      else { requireCondition(['planning','video','frames'].includes(stage),'validate stage 只能为 planning/frames/video/jobs'); const plan=loadPlan(project); const d=validatePlan(plan,project); if(stage==='frames') validateApproval(plan,project); if(stage==='video') makeJobs(plan,project); result={status:'validated',stage,...d,frame_plan_sha256:framePlanHash(plan,project)}; }
    } else throw new Error('用法：node production-plan.mjs init|validate|compile --project <视频目录> --stage planning|video|jobs');
    console.log(JSON.stringify(result));
  } catch(error) { console.error(JSON.stringify({status:'blocked',error:error.message})); process.exitCode=1; }
}

// Synthetic fixtures only. No Excel authoring, image generation or paid API calls.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {initializePlan,loadPlan,validatePlan,framePlanHash,compilePlan,validateJobs} from './production-plan.mjs';

const save=(p,v)=>fs.writeFileSync(p,JSON.stringify(v,null,2)+'\n');
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
export function createFixture(root) {
  fs.mkdirSync(path.join(root,'first-frames'),{recursive:true});
  const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jWZkAAAAASUVORK5CYII=','base64');
  fs.writeFileSync(path.join(root,'product.png'),png);
  fs.writeFileSync(path.join(root,'source.xlsx'),'Synthetic path fixture; not a real workbook.');
  save(path.join(root,'product-config.json'),{sku:'test',source_excel_path:path.join(root,'source.xlsx'),source_worksheet:'产品输入',source_row:2,product_images:[path.join(root,'product.png')]});
  save(path.join(root,'production-config.json'),{provider:'buming-ai',model:'omni-1.1',resolution:'720P',aspect_ratio:'9:16',spoken_language:'en-US'});
  initializePlan(root);
  const plan=JSON.parse(fs.readFileSync(path.join(root,'production-plan.json'),'utf8'));
  plan.facts=[{id:'F01',text:'Synthetic product use for testing.',source_fields:['产品信息'],source_images:[]}];
  for(const key of ['core_selling_point','confirmed_pain_point','target_audience','purchase_reason']) plan.direction[key]={text:'测试创意',fact_ids:['F01']};
  plan.direction.life_situation='测试生活场景';
  plan.direction.hook={behavior:'测试小动作',humor_source:'动作',bridge_to_product:'引出测试商品',muted_readable:true};
  plan.direction.proof={method:'测试正确使用步骤',fact_ids:['F01']};
  for(const k of Object.keys(plan.direction.vlog)) plan.direction.vlog[k]='测试自然 Vlog 设定';
  plan.references[0].locks='测试商品主体和连接结构';
  for(const s of plan.shots) {
    for(const k of ['visual','main_action','start_state','end_state','visible_product_parts','continuity','camera','vlog_detail','static_prompt']) s[k]='测试画面与自然小动作';
    s.fact_ids=['F01']; s.dialogue='This is an offline test.'; s.motion_prompt='从首帧延续一次小动作。'; s.acceptance_checks=['商品与手的接触合理'];
    s.reference_ids=s.product_visible?['P01']:[];
    fs.writeFileSync(path.join(root,s.first_frame),png);
  }
  save(path.join(root,'production-plan.json'),plan);
  return plan;
}
function approve(plan,root) {
  save(path.join(root,'first-frame-review.json'),{status:'approved',user_confirmation:'Synthetic approval for offline tests only.',model:plan.production.model,resolution:plan.production.resolution,frame_plan_sha256:framePlanHash(plan,root),frames:plan.shots.map(s=>({shot:s.id,path:path.join(root,s.first_frame),sha256:sha(path.join(root,s.first_frame))}))});
}
function test() {
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'fun-plan-test-'));
  let count=0;
  try {
    const plan=createFixture(root); const check=mutate=>{const p=structuredClone(plan); mutate(p); assert.throws(()=>validatePlan(p,root)); count++;};
    const d=validatePlan(plan,root); assert.equal(d.total_edit_duration_seconds,17.5); assert.equal(d.product_first_appearance_seconds,3.5); count++;
    check(p=>delete p.shots[2].main_action);
    check(p=>p.shots[0].duration_seconds=3.5);
    check(p=>p.shots[0].edit_duration_seconds='3.5');
    check(p=>p.shots[4].edit_duration_seconds=4.5);
    check(p=>p.shots[0].trim_start_seconds=-1);
    check(p=>p.shots[0].id='S02');
    check(p=>p.shots[2].fact_ids=['unknown']);
    check(p=>p.shots[2].reference_ids=['missing']);
    check(p=>p.shots[2].spatial_relation='insertion');
    check(p=>p.references[0].path=path.join(root,'unlisted.png'));
    check(p=>p.shots.forEach(s=>s.edit_duration_seconds=2));
    check(p=>p.direction.product_first_appearance_seconds=2.5);
    check(p=>p.shots[1].first_frame=p.shots[0].first_frame);
    const pose=structuredClone(plan); Object.assign(pose.references[0],{pose_master:true,angle_degrees:45,body_and_connection_visible:true}); Object.assign(pose.shots[1],{spatial_relation:'insertion',pose_master_ref:'P01'}); validatePlan(pose,root); count++;
    pose.references[0].angle_degrees=0; assert.throws(()=>validatePlan(pose,root)); count++;
    assert.throws(()=>initializePlan(root)); count++;
    compilePlan(root,'planning'); assert.equal(fs.existsSync(path.join(root,'image-to-video-jobs.json')),false); count++;
    assert.throws(()=>compilePlan(root,'video'),/验收/); count++;
    approve(plan,root); compilePlan(root,'video'); validateJobs(root); count++;
    const jobs=JSON.parse(fs.readFileSync(path.join(root,'image-to-video-jobs.json'),'utf8'));
    jobs.jobs[0].dialogue='Tampered speech'; save(path.join(root,'image-to-video-jobs.json'),jobs); assert.throws(()=>validateJobs(root),/不一致/); count++;
    compilePlan(root,'video'); const oldJobs=JSON.parse(fs.readFileSync(path.join(root,'image-to-video-jobs.json'),'utf8'));
    plan.shots[0].edit_duration_seconds=3; save(path.join(root,'production-plan.json'),plan);
    assert.throws(()=>validateJobs(root),/不一致/); compilePlan(root,'video');
    const newJobs=JSON.parse(fs.readFileSync(path.join(root,'image-to-video-jobs.json'),'utf8'));
    assert.equal(oldJobs.jobs[0].request_fingerprint,newJobs.jobs[0].request_fingerprint); validateJobs(root); count++;
    plan.shots[0].dialogue='A different offline line.'; save(path.join(root,'production-plan.json'),plan); assert.throws(()=>validateJobs(root),/不一致/); compilePlan(root,'video'); validateJobs(root); count++;
    const changed=structuredClone(plan); changed.shots[0].camera='不同机位'; save(path.join(root,'production-plan.json'),changed); assert.throws(()=>compilePlan(root,'video'),/重新展示/); count++;
    save(path.join(root,'production-plan.json'),plan);
    fs.appendFileSync(path.join(root,plan.shots[0].first_frame),Buffer.from([0])); assert.throws(()=>compilePlan(root,'video'),/首帧内容/); count++;
    console.log(`PASS: ${count} structured-plan checks (schema, timing, references, PoseMaster, approval, drift and generation reuse).`);
  } finally { fs.rmSync(root,{recursive:true,force:true}); }
}
if(process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const i=process.argv.indexOf('--fixture-dir');
  if(i>=0) { createFixture(path.resolve(process.argv[i+1])); console.log('Synthetic fixture created.'); }
  else test();
}

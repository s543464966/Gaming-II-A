// 将当前源码导出到唯一网页预览目录，先验证完整包再替换现有预览。
import { spawnSync } from 'node:child_process';
import { cp, mkdir, mkdtemp, readFile, writeFile, readdir, stat, rm } from 'node:fs/promises';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { selectEngine } from '../environment/engine.mjs';

const workspace = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const source = join(workspace, 'Coding/godot');
const destination = join(workspace, 'Archive/Builds/web');
const runtime = join(workspace, 'Testing/.runtime');
await mkdir(runtime, { recursive: true });
const run = await mkdtemp(join(runtime, 'web-export-'));
const project = join(run, 'project');
const output = join(run, 'web');
const excluded = new Set(['.godot', '.git', '.runtime', 'node_modules']);
try {
  const engine = await selectEngine(workspace);
  await cp(source, project, { recursive: true, filter: path => !relative(source, path).split(sep).some(part => excluded.has(part)) });
  await mkdir(output);
  const template = join(workspace, 'Tooling/.runtime/godot-platform/web-4.5.1');
  for (const mode of ['debug', 'release']) await stat(join(template, `web_nothreads_${mode}.zip`));
  const preset = join(project, 'export_presets.cfg');
  let config = await readFile(preset, 'utf8');
  config = config.replace('[preset.2.options]', `[preset.2.options]\ncustom_template/debug="${join(template,'web_nothreads_debug.zip').replaceAll('\\','/')}"\ncustom_template/release="${join(template,'web_nothreads_release.zip').replaceAll('\\','/')}"`);
  await writeFile(preset, config);
  function execute(label, args, marker) {
    const result = spawnSync(engine, ['--headless', '--path', project, ...args], { encoding: 'utf8', timeout: 240000, maxBuffer: 16*1024*1024 });
    const log = (result.stdout ?? '') + (result.stderr ?? '');
    if (result.status !== 0 || result.error || /SCRIPT ERROR:|(?:^|\n)ERROR:|Parse Error:/.test(log) || marker && !log.includes(marker)) {
      process.stderr.write(log); throw new Error(`${label} failed (${result.status}); ${result.error?.message ?? ''}`);
    }
    console.log(`PASS: ${label}`);
    return log;
  }
  // 与测试入口保持一致，Windows 不启用会导致字体导入崩溃的单线程场景模式。
  const importOptions = process.platform === 'win32' ? [] : ['--single-threaded-scene'];
  await writeFile(join(run,'import.log'), execute('web import',[...importOptions,'--editor','--import','--quit']));
  await writeFile(join(run,'export.log'), execute('web export',['--export-release','Web Preview',join(output,'game.html')]));
  await writeFile(join(run,'pack.log'), execute('100-level exported content',['--main-pack',join(output,'game.pck'),'--script',join(workspace,'Testing/integration/donut_sort/web_pack_test.gd')], 'PASS: hundred web pack'));
  const catalog = JSON.parse(await readFile(join(source, 'game_content/donuts/levels/catalog.json'), 'utf8'));
  const hashes = {};
  for (const level of catalog.levels) {
    const path = level.path.replace('res://','');
    hashes[path] = createHash('sha256').update(await readFile(join(source,path))).digest('hex');
  }
  await cp(join(workspace,'Tooling/preview/web.html'),join(output,'index.html'));
  await writeFile(join(output,'build_info.json'),JSON.stringify({levels:catalog.levels.length,builtAt:new Date().toISOString(),hashes},null,2)+'\n');
  await mkdir(destination,{recursive:true});
  // 输出文件只覆盖已验证的同一路径；服务继续读取固定目录，不创建另一个链接。
  for (const entry of await readdir(output)) await cp(join(output,entry),join(destination,entry));
  console.log('Updated http://127.0.0.1:4173/');
  const checked = resolve(run);
  if (!checked.startsWith(resolve(runtime)+sep)) throw new Error('Temporary path left runtime directory');
  await rm(checked,{recursive:true});
} catch(error) {
  console.error(error.message); console.error(`Diagnostics: ${run}`); process.exitCode=1;
}

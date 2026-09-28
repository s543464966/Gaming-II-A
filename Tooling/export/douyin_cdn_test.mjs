// Owns a reusable resource origin, optionally exposed through Cloudflare for phone tests.
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { mkdir, mkdtemp, readFile, rename, rm, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { updateProject, workspace } from './minigame.mjs';
import { startDouyinResourceServer, verifyDouyinResource } from './douyin_resource_server.mjs';
import { rebuildRunningCdn, startCdnControl } from './douyin_cdn_session.mjs';
import { prepareDevelopmentTunnel } from '../environment/development_tunnel.mjs';
import { startQuickTunnel, waitForOrigin } from './quick_tunnel.mjs';

const digest = bytes => createHash('sha256').update(bytes).digest('hex');

// A fresh child reads current build code on every reuse; the CDN keeps serving meanwhile.
function exportCandidate(baseUrl, destination) {
  const source = 'import {createDouyinExport} from ' + JSON.stringify(new URL('./douyin.mjs', import.meta.url).href)
    + '; process.on("SIGINT",()=>{}); process.on("SIGTERM",()=>{});'
    + ' await createDouyinExport({mode:"cdn",baseUrl:process.argv[1],destination:process.argv[2],testDomainBypass:true});';
  return new Promise((accept, reject) => {
    const child = spawn(process.execPath, ['--input-type=module', '-e', source, baseUrl, destination],
      { cwd: workspace, stdio: ['ignore', 'inherit', 'inherit'] });
    child.once('error', reject);
    child.once('close', (code, signal) => {
      if (code === 0) accept();
      else reject(new Error('CDN 导出进程失败：' + (signal ?? code)));
    });
  });
}

async function publishRemote(candidate, name, expected) {
  const directory = join(workspace, 'Archive/Builds/douyin.cdn');
  await mkdir(directory, { recursive: true });
  const destination = join(directory, name);
  const prior = await readFile(destination).catch(error => {
    if (error.code === 'ENOENT') return null;
    throw error;
  });
  if (prior) {
    if (digest(prior) !== expected) throw new Error('Existing CDN file has different bytes: ' + destination);
    return;
  }
  const temporary = join(directory, '.incoming-' + process.pid);
  try {
    await writeFile(temporary, await readFile(candidate), { flag: 'wx' });
    if (digest(await readFile(temporary)) !== expected) throw new Error('CDN candidate changed while copying.');
    await rename(temporary, destination);
  } finally { await rm(temporary, { force: true }); }
}

function readyMessage(result) {
  return 'CDN TEST READY\n小游戏项目：' + result.output
    + '\n小游戏包：' + result.packageBytes + ' 字节；远程贴图：' + result.remoteBytes
    + ' 字节（' + result.remoteFiles.length + ' 块）'
    + '\nCDN 测试地址：' + result.baseUrl
    + '\n全部资源已从包内地址回下载并校验；在原有抖音开发者工具项目点击“编译”。'
    + (result.transport === 'cloudflare'
      ? '\nCloudflare HTTPS 已就绪，可扫码测试；开发测试包保留不校验合法域名配置。'
      : '\n此包用于电脑模拟器；手机测试请选择 cloudflare-cdn 或配置正式 HTTPS CDN。')
    + '\n保持提供 CDN 服务的工具窗口运行；后续再双击 douyin.command 会复用服务并重新打包。';
}

export async function runDouyinCdnTest({ signal, onProgress = console.log, transport = 'local' } = {}) {
  if (!['local', 'cloudflare'].includes(transport)) throw new Error('Unknown CDN transport.');
  const runtime = join(workspace, 'Testing/.runtime');
  const lock = join(workspace, 'Tooling/.runtime/douyin/cdn-test.lock');
  await mkdir(runtime, { recursive: true });
  await mkdir(dirname(lock), { recursive: true });
  const reused = await rebuildRunningCdn(lock, workspace, transport);
  if (reused) { onProgress(readyMessage(reused)); return; }
  try { await mkdir(lock); }
  catch (error) {
    if (error.code === 'EEXIST') throw new Error('CDN 服务正在准备中，请稍后再双击 douyin.command。');
    throw error;
  }
  let run;
  let server;
  let control;
  let tunnel;
  let failed = false;
  let currentFiles = [];
  let previousFiles = [];
  let building;
  const controller = new AbortController();
  const cancel = () => controller.abort(signal?.reason ?? Error('测试已停止'));
  signal?.addEventListener('abort', cancel, { once: true });
  if (signal?.aborted) cancel();
  const state = { owner: 'donut-douyin-cdn-test', workspace, pid: process.pid, transport,
    startedAt: new Date().toISOString(), state: 'starting' };
  const save = () => writeFile(join(run, 'session.json'), JSON.stringify(state, null, 2) + '\n', { mode: 0o600 });

  async function build() {
    controller.signal.throwIfAborted();
    state.state = 'building';
    delete state.error;
    await save();
    const staging = await mkdtemp(join(run, 'build-'));
    const candidate = join(staging, 'douyin');
    try {
      onProgress('开始导出 CDN 模式抖音包；验证通过后更新原有模拟器项目。');
      await exportCandidate(state.baseUrl, candidate);
      const report = JSON.parse(await readFile(join(candidate, 'build_report.json'), 'utf8'));
      const packs = report.delivery?.packs;
      if (!Array.isArray(packs) || !packs.length) throw new Error('CDN build report has no resource chunks.');
      for (const pack of packs) {
        if (!/^[0-9a-f]{64}\.pck$/.test(pack.file) || pack.file !== pack.sha256 + '.pck') {
          throw new Error('CDN resource name is invalid.');
        }
        const path = join(staging, 'douyin.cdn', pack.file);
        const bytes = await readFile(path);
        if (bytes.length !== pack.bytes || digest(bytes) !== pack.sha256) throw new Error('CDN artifact and report differ.');
        server.install(pack.file, bytes);
        onProgress('校验 CDN 资源 ' + (packs.indexOf(pack) + 1) + '/' + packs.length + '…');
        await verifyDouyinResource(state.baseUrl, pack.file, bytes, { signal: controller.signal });
        await publishRemote(path, pack.file, pack.sha256);
      }
      controller.signal.throwIfAborted();
      const fixed = join(workspace, 'Archive/Builds/douyin');
      await updateProject(candidate, fixed, join(staging, 'previous_project'));
      previousFiles = currentFiles;
      currentFiles = packs.map(pack => pack.file);
      server.retain([...currentFiles, ...previousFiles]);
      Object.assign(state, { state: 'ready', output: fixed, remoteFiles: currentFiles,
        packageBytes: report.sizes.total, remoteBytes: report.delivery.remoteBytes,
        sourceSha256: report.sourceSha256, readyAt: new Date().toISOString() });
      await save();
      onProgress(readyMessage(state));
      await rm(staging, { recursive: true });
      return { ...state };
    } catch (error) {
      server.retain([...currentFiles, ...previousFiles]);
      state.state = 'failed';
      state.error = error.message;
      await save();
      throw new Error(error.message + '\nCDN 构建诊断：' + staging, { cause: error });
    }
  }

  const rebuild = () => building ??= build().finally(() => { building = undefined; });
  try {
    run = await mkdtemp(join(runtime, 'douyin-cdn-test-'));
    await writeFile(join(lock, 'owner.json'), JSON.stringify({ pid: process.pid, run }) + '\n', { flag: 'wx', mode: 0o600 });
    await save();
    onProgress('CDN 测试诊断：' + run);
    server = await startDouyinResourceServer({ onDownload: event => {
      if (state.state === 'ready') onProgress('RESOURCE GET ' + event.name + ' — ' + event.bytes + ' bytes');
    } });
    state.baseUrl = server.origin + server.prefix;
    await save();
    const health = await fetch(state.baseUrl + 'health', { signal: AbortSignal.timeout(5000) });
    if (!health.ok || await health.text() !== server.challenge) throw new Error('本机 CDN 服务健康检查失败。');
    if (transport === 'cloudflare') {
      const binary = await prepareDevelopmentTunnel(workspace, { signal: controller.signal, onProgress });
      onProgress('连接 Cloudflare 临时 HTTPS，仅提供本批资源块；本机控制接口不对外开放。');
      tunnel = await startQuickTunnel({ binary, origin: server.origin, run, signal: controller.signal,
        onExit: error => controller.abort(error) });
      state.baseUrl = tunnel.url + server.prefix;
      state.tunnelPid = tunnel.pid;
      await save();
      onProgress('校验 Cloudflare HTTPS 与本机资源服务的连接…');
      await waitForOrigin(state.baseUrl, server.challenge, { signal: controller.signal });
    }
    control = await startCdnControl({ workspace, rebuild, state: () => state.state, transport });
    await writeFile(join(lock, 'owner.json'), JSON.stringify({
      ...control.identity, run, controlUrl: control.url,
    }) + '\n', { mode: 0o600 });
    await rebuild();
    await new Promise(accept => {
      if (controller.signal.aborted) accept();
      else controller.signal.addEventListener('abort', accept, { once: true });
    });
    if (!signal?.aborted) throw controller.signal.reason;
  } catch (error) {
    failed = !signal?.aborted;
    state.error = error.message;
    if (failed) throw new Error(error.message + '\nCDN 测试诊断：' + (run ?? lock), { cause: error });
  } finally {
    signal?.removeEventListener('abort', cancel);
    if (building) await building.catch(() => {});
    await control?.close();
    await tunnel?.close();
    await server?.close();
    Object.assign(state, { state: failed ? 'failed' : 'stopped', stoppedAt: new Date().toISOString(), requests: server?.stats });
    if (run) await save();
    const owner = await readFile(join(lock, 'owner.json'), 'utf8').then(JSON.parse).catch(() => null);
    if (owner?.pid === process.pid) await rm(lock, { recursive: true });
    if (run && !failed) await rm(run, { recursive: true });
  }
}

export async function startDouyinCdnTest({ transport = 'local' } = {}) {
  const controller = new AbortController();
  const stop = () => controller.abort();
  for (const event of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.once(event, stop);
  try { await runDouyinCdnTest({ signal: controller.signal, transport }); }
  finally { for (const event of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.removeListener(event, stop); }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.length !== 2) {
    console.error('Usage: node Tooling/export/douyin_cdn_test.mjs');
    process.exitCode = 2;
  } else {
    startDouyinCdnTest().catch(error => { console.error(error.message); process.exitCode = 1; });
  }
}

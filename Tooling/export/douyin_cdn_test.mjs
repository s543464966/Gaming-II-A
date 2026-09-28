// A temporary local origin and HTTPS tunnel for the same fixed Douyin IDE project.
import { createHash } from 'node:crypto';
import { mkdir, mkdtemp, readFile, rename, rm, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createDouyinExport } from './douyin.mjs';
import { updateProject, workspace } from './minigame.mjs';
import { prepareDevelopmentTunnel } from '../environment/development_tunnel.mjs';
import { startQuickTunnel, waitForOrigin } from './quick_tunnel.mjs';
import { startDouyinResourceServer, verifyDouyinResource } from './douyin_resource_server.mjs';

const digest = bytes => createHash('sha256').update(bytes).digest('hex');

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
  const temporary = join(directory, `.incoming-${process.pid}`);
  try {
    await writeFile(temporary, await readFile(candidate), { flag: 'wx' });
    if (digest(await readFile(temporary)) !== expected) throw new Error('CDN candidate changed while copying.');
    await rename(temporary, destination);
  } finally { await rm(temporary, { force: true }); }
}

export async function runDouyinCdnTest({ signal, onProgress = console.log } = {}) {
  const runtime = join(workspace, 'Testing/.runtime');
  const lock = join(workspace, 'Tooling/.runtime/douyin/cdn-test.lock');
  await mkdir(runtime, { recursive: true });
  try { await mkdir(lock); }
  catch (error) {
    if (error.code === 'EEXIST') throw new Error(`已有 CDN 测试服务；先检查 ${join(lock, 'owner.json')}。`);
    throw error;
  }
  let run;
  let server;
  let tunnel;
  let failed = false;
  const controller = new AbortController();
  const cancel = () => controller.abort(signal?.reason ?? Error('测试已停止'));
  signal?.addEventListener('abort', cancel, { once: true });
  if (signal?.aborted) cancel();
  const state = { owner: 'donut-douyin-cdn-test', pid: process.pid, startedAt: new Date().toISOString(), state: 'starting' };
  const save = () => writeFile(join(run, 'session.json'), `${JSON.stringify(state, null, 2)}\n`, { mode: 0o600 });
  try {
    run = await mkdtemp(join(runtime, 'douyin-cdn-test-'));
    await writeFile(join(lock, 'owner.json'), `${JSON.stringify({ pid: process.pid, run })}\n`, { flag: 'wx', mode: 0o600 });
    await save();
    onProgress(`CDN 测试诊断：${run}`);
    const binary = await prepareDevelopmentTunnel(workspace, { signal: controller.signal, onProgress });
    server = await startDouyinResourceServer({ onDownload: event => {
      if (state.state === 'ready') onProgress(`RESOURCE GET ${event.name} — ${event.bytes} bytes`);
    } });
    tunnel = await startQuickTunnel({ binary, origin: server.origin, run, signal: controller.signal,
      onExit: error => controller.abort(error) });
    state.tunnelPid = tunnel.pid;
    state.baseUrl = tunnel.url + server.prefix;
    await save();
    onProgress('检查临时 HTTPS 地址确实连接本机资源服务…');
    await waitForOrigin(state.baseUrl, server.challenge, { signal: controller.signal });
    state.state = 'building';
    await save();
    const candidate = join(run, 'candidate/douyin');
    await mkdir(dirname(candidate), { recursive: true });
    onProgress('开始导出 CDN 模式抖音包，现有模拟器项目暂不替换。');
    await createDouyinExport({ mode: 'cdn', baseUrl: state.baseUrl,
      destination: candidate, testDomainBypass: true });
    const report = JSON.parse(await readFile(join(candidate, 'build_report.json'), 'utf8'));
    const name = report.delivery?.remoteFile;
    if (!/^[0-9a-f]{64}\.pck$/.test(name ?? '')) throw new Error('CDN build report has no valid remote file.');
    const remote = join(run, 'candidate/douyin.cdn', name);
    const bytes = await readFile(remote);
    if (bytes.length !== report.delivery.remoteBytes || digest(bytes) !== report.delivery.remoteSha256) {
      throw new Error('CDN artifact and build report differ.');
    }
    server.install(name, bytes);
    onProgress('从临时公网 HTTPS 地址回下载资源并校验 SHA-256…');
    await verifyDouyinResource(state.baseUrl, name, bytes, { signal: controller.signal });
    controller.signal.throwIfAborted();
    await publishRemote(remote, name, report.delivery.remoteSha256);
    const fixed = join(workspace, 'Archive/Builds/douyin');
    await updateProject(candidate, fixed, join(run, 'previous_project'));
    Object.assign(state, { state: 'ready', output: fixed, remoteFile: name,
      packageBytes: report.sizes.total, remoteBytes: bytes.length, readyAt: new Date().toISOString() });
    await save();
    onProgress(`CDN TEST READY\n小游戏项目：${fixed}\n小游戏包：${report.sizes.total} 字节；远程贴图：${bytes.length} 字节\n临时 HTTPS 地址：${state.baseUrl}\n公网资源和分包缓存已校验；抖音宿主 tt.request 仍需本地预览验收。在原有抖音开发者工具项目点击“编译”后可预览。保持此窗口运行；结束后如要恢复离线包，双击 douyin.command。`);
    await new Promise(accept => {
      if (controller.signal.aborted) accept();
      else controller.signal.addEventListener('abort', accept, { once: true });
    });
    if (!signal?.aborted) throw controller.signal.reason;
  } catch (error) {
    failed = !signal?.aborted;
    state.error = error.message;
    if (failed) throw new Error(`${error.message}\nCDN 测试诊断：${run ?? lock}`, { cause: error });
  } finally {
    signal?.removeEventListener('abort', cancel);
    await tunnel?.close();
    await server?.close();
    Object.assign(state, { state: failed ? 'failed' : 'stopped', stoppedAt: new Date().toISOString(), requests: server?.stats });
    if (run) await save();
    await rm(lock, { recursive: true });
    if (run && !failed) await rm(run, { recursive: true });
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.length !== 2) {
    console.error('Usage: node Tooling/export/douyin_cdn_test.mjs');
    process.exitCode = 2;
  } else {
    const controller = new AbortController();
    const stop = () => controller.abort();
    for (const event of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.once(event, stop);
    try { await runDouyinCdnTest({ signal: controller.signal }); }
    catch (error) { console.error(error.message); process.exitCode = 1; }
    finally { for (const event of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.removeListener(event, stop); }
  }
}

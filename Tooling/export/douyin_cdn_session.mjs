import { randomBytes } from 'node:crypto';
import { createServer } from 'node:http';
import { readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';

const OWNER = 'donut-douyin-cdn-test';
const protocol = 3;

function alive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try { process.kill(pid, 0); return true; }
  catch (error) { if (error.code === 'ESRCH') return false; throw error; }
}

// Separate loopback control is never served by the resource endpoint.
export async function startCdnControl({ workspace, rebuild, state, transport = 'local' }) {
  const route = '/' + randomBytes(24).toString('hex');
  const identity = { owner: OWNER, protocol, workspace, pid: process.pid, transport };
  let inFlight;
  const server = createServer(async (request, response) => {
    response.setHeader('Content-Type', 'application/json');
    response.setHeader('Cache-Control', 'no-store');
    const send = (status, value) => { response.writeHead(status); response.end(JSON.stringify(value)); };
    if (request.headers.origin) { send(403, { error: 'Browser control requests are not accepted.' }); return; }
    if (request.method === 'GET' && request.url === route + '/state') {
      send(200, { ...identity, state: state() }); return;
    }
    if (request.method !== 'POST' || request.url !== route + '/build') {
      send(404, { error: 'Unknown command.' }); return;
    }
    try {
      inFlight ??= Promise.resolve().then(rebuild).finally(() => { inFlight = undefined; });
      send(200, { ...identity, result: await inFlight });
    } catch (error) { send(500, { ...identity, error: error.message }); }
  });
  server.requestTimeout = 0;
  await new Promise((accept, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', accept);
  });
  return {
    identity, url: 'http://127.0.0.1:' + server.address().port + route,
    async close() {
      server.closeAllConnections();
      await new Promise(accept => server.close(accept));
    },
  };
}

// Only a verified process from this workspace may service a repeated double click.
export async function rebuildRunningCdn(lock, workspace, transport = 'local') {
  const path = join(lock, 'owner.json');
  const raw = await readFile(path, 'utf8').catch(error => {
    if (error.code === 'ENOENT') return null;
    throw error;
  });
  if (!raw) return null;
  const owner = JSON.parse(raw);
  if (!alive(owner.pid)) {
    if (await readFile(path, 'utf8') === raw) await rm(lock, { recursive: true });
    return null;
  }
  if (owner.owner !== OWNER || owner.protocol !== protocol || owner.workspace !== workspace
      || !/^http:\/\/127\.0\.0\.1:\d+\/[0-9a-f]{48}$/.test(owner.controlUrl ?? '')) {
    throw new Error('旧版本或无法确认归属的 CDN 服务仍在运行，请先关闭它的工具窗口，再双击 douyin.command。');
  }
  if (owner.transport !== transport) {
    throw new Error('正在运行的 CDN 服务模式不同，请先关闭原工具窗口，再启动本次模式。');
  }
  const check = value => {
    if (value.owner !== OWNER || value.protocol !== protocol || value.workspace !== workspace
        || value.pid !== owner.pid || value.transport !== transport) {
      throw new Error('本机 CDN 服务身份不匹配，未触发打包。');
    }
  };
  const status = await fetch(owner.controlUrl + '/state', { signal: AbortSignal.timeout(300000), redirect: 'error' });
  if (!status.ok) throw new Error('本机 CDN 服务暂不可用，请查看原工具窗口。');
  check(await status.json());
  console.log('复用已运行的本机 CDN 服务，正在重新打包…');
  const response = await fetch(owner.controlUrl + '/build', {
    method: 'POST', signal: AbortSignal.timeout(300000), redirect: 'error',
  });
  const body = await response.json();
  check(body);
  if (!response.ok) throw new Error(body.error ?? '本机 CDN 重新打包失败。');
  return body.result;
}

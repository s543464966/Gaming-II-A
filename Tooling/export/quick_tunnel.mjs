// Owns only the child launched here. A printed hostname is not a readiness signal.
import { spawn } from 'node:child_process';
import { appendFileSync } from 'node:fs';
import { writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';

export async function startQuickTunnel({ binary, origin, run, signal, onExit = () => {}, timeoutMs = 90000 }) {
  const config = join(run, 'tunnel.json');
  await writeFile(config, '{}\n', { flag: 'wx', mode: 0o600 });
  const args = ['tunnel', '--config', config, '--no-autoupdate', '--metrics', '127.0.0.1:0', '--url', origin, '--grace-period', '1s'];
  const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('TUNNEL_') && !['NO_AUTOUPDATE', 'NO_TLS_VERIFY'].includes(key)));
  const child = spawn(binary, args, { cwd: run, env, stdio: ['ignore', 'pipe', 'pipe'] });
  let output = '';
  let logBytes = 0;
  let exited = false;
  let stopping = false;
  let childError;
  const receive = chunk => {
    output = (output + chunk).slice(-65536);
    if (logBytes < 1024 * 1024) {
      appendFileSync(join(run, 'tunnel.log'), chunk, { mode: 0o600 });
      logBytes += chunk.length;
    }
  };
  child.stdout.on('data', receive);
  child.stderr.on('data', receive);
  child.on('error', error => { childError = error; });
  const closed = new Promise(accept => child.once('close', code => {
    exited = true;
    if (!stopping) onExit(Error(`临时隧道进程已停止（${code}）；查看 ${join(run, 'tunnel.log')}`));
    accept();
  }));
  let closing;
  const close = () => closing ??= (async () => {
    stopping = true;
    if (exited) return;
    child.kill('SIGTERM');
    const timer = setTimeout(() => child.kill('SIGKILL'), 4000);
    await closed;
    clearTimeout(timer);
  })();
  const abort = () => { void close(); };
  signal?.addEventListener('abort', abort, { once: true });
  try {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      signal?.throwIfAborted();
      if (exited) throw childError ?? Error('无法建立临时隧道，请查看 tunnel.log。');
      const match = output.match(/https:\/\/[a-z0-9]+(?:-[a-z0-9]+)*\.trycloudflare\.com\b/);
      if (match) return { url: match[0], pid: child.pid, args, close: async () => { signal?.removeEventListener('abort', abort); await close(); } };
      await delay(100, undefined, { signal });
    }
    throw Error('申请临时 HTTPS 地址超时；不会替换小游戏包。');
  } catch (error) {
    signal?.removeEventListener('abort', abort);
    await close();
    throw error;
  }
}

export async function waitForOrigin(baseUrl, challenge, { signal, timeoutMs = 90000 } = {}) {
  const deadline = Date.now() + timeoutMs;
  let diagnostic = '';
  while (Date.now() < deadline) {
    signal?.throwIfAborted();
    try {
      const timeout = AbortSignal.timeout(Math.min(10000, Math.max(1, deadline - Date.now())));
      const response = await fetch(baseUrl + 'health', { redirect: 'error', signal: signal ? AbortSignal.any([signal, timeout]) : timeout });
      if (response.status === 200 && (await response.text()) === challenge) return;
      diagnostic = `HTTP ${response.status} 或响应来源不匹配`;
      await response.body?.cancel().catch(() => {});
    } catch (error) { diagnostic = [error.name, error.cause?.code, error.cause?.message ?? error.message].filter(Boolean).join(': '); }
    if (Date.now() < deadline) await delay(1000, undefined, { signal });
  }
  throw Error(`临时 HTTPS 地址无法返回本次服务响应：${diagnostic}。旧包不动，请检查网络后重试。`);
}

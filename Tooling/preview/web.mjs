import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { copyFile, stat } from 'node:fs/promises';
import { dirname, extname, isAbsolute, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = dirname(fileURLToPath(import.meta.url));
const workspace = resolve(directory, '../..');
const build = join(workspace, 'Archive/Builds/web');
const origin = 'http://127.0.0.1:4173';
const identity = { service: 'donut-web-preview', workspace };
const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8', '.png': 'image/png',
  '.wasm': 'application/wasm', '.pck': 'application/octet-stream',
};

// 重复启动复用同一工程的固定端口，不创建另一份服务或另选端口。
const existing = await fetch(`${origin}/__preview/status`, { signal: AbortSignal.timeout(1500) })
  .then(response => response.ok ? response.json() : null).catch(() => null);
if (existing?.service === identity.service && existing.workspace === workspace) {
  console.log(`预览已在运行：${origin}/`);
} else {
  await stat(join(build, 'game.html')).catch(() => {
    throw new Error('缺少网页导出，请先将最新游戏导出到 Archive/Builds/web/game.html。');
  });
  await copyFile(join(directory, 'web.html'), join(build, 'index.html'));

  const server = createServer(async (request, response) => {
    // 预览每次读取当前导出，入口和游戏资源均不复用旧缓存。
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    if (!['GET', 'HEAD'].includes(request.method)) {
      response.writeHead(405, { Allow: 'GET, HEAD' }).end();
      return;
    }
    try {
      const url = new URL(request.url, origin);
      if (url.pathname === '/__preview/status') {
        response.writeHead(200, { 'Content-Type': types['.json'] });
        response.end(request.method === 'HEAD' ? undefined : JSON.stringify(identity));
        return;
      }
      // 历史版本参数和 index.html 均归一到同一个公开地址。
      if (url.pathname === '/index.html' || (url.pathname === '/' && (url.search || url.hash))) {
        response.writeHead(302, { Location: '/' }).end();
        return;
      }
      if (url.pathname === '/game.html' && url.search) {
        response.writeHead(302, { Location: '/game.html' }).end();
        return;
      }
      const pathname = decodeURIComponent(url.pathname);
      const file = resolve(build, pathname === '/' ? 'index.html' : `.${pathname}`);
      const local = relative(build, file);
      if (local.startsWith('..') || isAbsolute(local) || pathname.includes('\\')) {
        response.writeHead(403).end();
        return;
      }
      const details = await stat(file);
      if (!details.isFile()) {
        response.writeHead(404).end();
        return;
      }
      response.writeHead(200, {
        'Content-Type': types[extname(file)] ?? 'application/octet-stream',
        'Content-Length': details.size,
      });
      if (request.method === 'HEAD') response.end();
      else createReadStream(file).on('error', () => response.destroy()).pipe(response);
    } catch (error) {
      response.writeHead(error instanceof URIError ? 400 : 404).end();
    }
  });
  server.on('error', error => {
    console.error(error.code === 'EADDRINUSE'
      ? '4173 端口已被其他服务占用；请先检查该进程，不创建新的预览端口。' : error.message);
    process.exitCode = 1;
  });
  server.listen(4173, '127.0.0.1', () => console.log(`唯一网页预览：${origin}/`));
  for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => server.close());
}

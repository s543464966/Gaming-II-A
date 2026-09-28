import { createHash, randomBytes } from 'node:crypto';
import { createServer } from 'node:http';

const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');

// The local origin serves only one verified, immutable content-addressed pack.
export async function startDouyinResourceServer({ onDownload = () => {} } = {}) {
  const prefix = `/${randomBytes(24).toString('hex')}/`;
  const challenge = randomBytes(24).toString('hex');
  let asset = null;
  const stats = { requests: 0, bytes: 0 };
  const server = createServer({ requestTimeout: 15000, headersTimeout: 10000, maxHeaderSize: 8192 }, (request, response) => {
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Access-Control-Allow-Origin', '*');
    response.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    const name = request.url?.startsWith(prefix) ? request.url.slice(prefix.length) : '';
    const body = name === 'health' ? Buffer.from(challenge) : name === asset?.name ? asset.bytes : null;
    if (!body) { response.writeHead(404); response.end(); return; }
    if (request.method === 'OPTIONS') { response.writeHead(204); response.end(); return; }
    if (!['GET', 'HEAD'].includes(request.method)) { response.writeHead(405); response.end(); return; }
    response.setHeader('Content-Type', name === 'health' ? 'text/plain' : 'application/octet-stream');
    response.setHeader('Content-Length', body.length);
    response.writeHead(200);
    if (name !== 'health' && request.method === 'GET') {
      response.once('finish', () => {
        stats.requests++;
        stats.bytes += body.length;
        onDownload({ name, bytes: body.length, requests: stats.requests });
      });
    }
    response.end(request.method === 'HEAD' ? undefined : body);
  });
  server.maxConnections = 32;
  await new Promise((accept, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', accept);
  });
  return {
    origin: `http://127.0.0.1:${server.address().port}`, prefix, challenge, stats,
    install(name, bytes) {
      if (!/^[0-9a-f]{64}\.pck$/.test(name) || sha256(bytes) + '.pck' !== name
          || bytes.length < 1 || bytes.length > 8 * 1024 * 1024) {
        throw new Error('The local CDN pack name, size or digest is invalid.');
      }
      asset = { name, bytes: Buffer.from(bytes) };
    },
    async close() {
      server.closeAllConnections();
      await new Promise(accept => server.close(accept));
      asset = null;
    },
  };
}

// Verify the public TLS route by consuming and hashing the exact pack bytes.
export async function verifyDouyinResource(baseUrl, name, expected, { signal } = {}) {
  const timeout = AbortSignal.timeout(30000);
  const response = await fetch(baseUrl + name, {
    redirect: 'error', signal: signal ? AbortSignal.any([signal, timeout]) : timeout,
  });
  if (response.status !== 200 || !response.body) throw new Error(`CDN public resource returned HTTP ${response.status}.`);
  const digest = createHash('sha256');
  let size = 0;
  for await (const chunk of response.body) {
    size += chunk.length;
    if (size > expected.length) throw new Error('CDN public resource exceeded expected size.');
    digest.update(chunk);
  }
  if (size !== expected.length || digest.digest('hex') !== sha256(expected)) {
    throw new Error('CDN public resource bytes differ from the packaged resource.');
  }
  return size;
}

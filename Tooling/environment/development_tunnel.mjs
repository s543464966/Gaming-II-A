// Workspace-only, pinned development dependency; never installed as a system service.
import { execFile } from 'node:child_process';
import { createHash } from 'node:crypto';
import { chmod, mkdir, mkdtemp, readFile, rename, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { promisify } from 'node:util';

const exec = promisify(execFile);
const version = '2026.8.3';
// Archive digest is GitHub's release asset digest; the release body lists the binary digest.
const archiveSha = '40c9144d86df8937c5b43293a1f7d2d2107029aa74725023dd46b1b27154352f';
const binarySha = '50a04624531e7a98ddb65f1223905e32f84e7488ed3ee8dadcd3260aa8932603';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');

export async function prepareDevelopmentTunnel(workspace, { signal, onProgress = () => {} } = {}) {
  if (process.platform !== 'darwin' || process.arch !== 'arm64') throw Error('临时隧道工具目前仅锁定 macOS ARM64。');
  const cache = join(workspace, 'Tooling/.runtime/development-tunnel');
  const binary = join(cache, 'cloudflared');
  const archive = join(cache, `cloudflared-${version}.tgz`);
  const matches = async (path, digest) => {
    try { return hash(await readFile(path)) === digest; }
    catch (error) { if (error.code === 'ENOENT') return false; throw error; }
  };
  signal?.throwIfAborted();
  if (await matches(binary, binarySha)) return binary;
  await mkdir(cache, { recursive: true });
  const run = await mkdtemp(join(cache, '.prepare-'));
  try {
    if (!await matches(archive, archiveSha)) {
      onProgress(`下载官方 cloudflared ${version}（仅工作区缓存）`);
      const staged = join(run, 'client.tgz');
      await exec('curl', ['--fail', '--location', '--silent', '--show-error', '--connect-timeout', '15', '--max-time', '180',
        '--output', staged, `https://github.com/cloudflare/cloudflared/releases/download/${version}/cloudflared-darwin-arm64.tgz`], { signal, timeout: 185000 });
      if (!await matches(staged, archiveSha)) throw Error('开发隧道下载校验失败；不运行未验证的文件。');
      await rename(staged, archive);
    }
    const entries = await exec('tar', ['-tzf', archive], { signal, timeout: 10000 });
    if (entries.stdout.trim() !== 'cloudflared') throw Error('开发隧道压缩包包含非预期文件。');
    await exec('tar', ['-xzf', archive, '-C', run, 'cloudflared'], { signal, timeout: 10000 });
    const staged = join(run, 'cloudflared');
    if (!await matches(staged, binarySha)) throw Error('开发隧道客户端校验失败。');
    await chmod(staged, 0o755);
    await rename(staged, binary);
    return binary;
  } finally { await rm(run, { recursive: true }); }
}

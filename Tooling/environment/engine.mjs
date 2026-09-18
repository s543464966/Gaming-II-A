import { constants } from 'node:fs';
import { access, readFile } from 'node:fs/promises';
import { join } from 'node:path';

// Preview and checks use the same engine selection without installing dependencies.
export async function selectEngine(workspace) {
  if (process.env.GODOT_BIN) return process.env.GODOT_BIN;
  if (process.platform !== 'darwin') return 'godot';
  const { engine } = JSON.parse(await readFile(join(workspace, 'Coding/godot/tooling/engine.json'), 'utf8'));
  if (!/^\d+\.\d+\.\d+$/.test(engine)) throw new Error('Invalid Godot version in tooling/engine.json.');
  const prepared = join(workspace, `Tooling/.runtime/godot-platform/editor-${engine}/Godot.app/Contents/MacOS/Godot`);
  try {
    await access(prepared, constants.X_OK);
    return prepared;
  } catch {
    return '/Applications/Godot.app/Contents/MacOS/Godot';
  }
}

"""从已校验的 Noto 源字体生成随包 UI 字体，不依赖设备系统字体。"""
import hashlib
from pathlib import Path
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[2]
SOURCE_SHA256 = "faa6c9df652116dde789d351359f3d7e5d2285a2b2a1f04a2d7244df706d5ea9"

if len(sys.argv) != 2:
    raise SystemExit("Usage: python3 Tooling/data/subset_ui_font.py /path/to/NotoSansSC-Regular.otf")
source = Path(sys.argv[1])
if hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_SHA256:
    raise SystemExit("Source font SHA-256 mismatch.")

# 覆盖常用简体中文及工程现有文本；源字体无需进入游戏包。
characters = {chr(code) for code in range(32, 127)}
for first in range(0xA1, 0xF8):
    for second in range(0xA1, 0xFF):
        try:
            characters.update(bytes([first, second]).decode("gb2312"))
        except UnicodeDecodeError:
            pass
for path in (ROOT / "Coding/godot").rglob("*"):
    if path.suffix in {".gd", ".tscn", ".json"} and ".godot" not in path.parts:
        characters.update(path.read_text())

font = TTFont(source, recalcTimestamp=False)
options = subset.Options()
options.recalc_timestamp = False
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes={ord(char) for char in characters})
subsetter.subset(font)
output = ROOT / "Coding/godot/ui/design_system/fonts/donut_sans_sc.otf"
output.parent.mkdir(parents=True, exist_ok=True)
font.save(output)
print(f"Generated {output}: {output.stat().st_size} bytes")

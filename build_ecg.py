#!/usr/bin/env python3
"""Generate event-specific observer pages from the main app + a preset.

Single source of truth is index.html. Each event lives in its own folder with a
preset.json; this injects that preset and writes <folder>/index.html. Re-run after
editing index.html so event pages pick up the change.

    python3 build_ecg.py
"""
import json, pathlib, sys

root = pathlib.Path(__file__).parent
app = (root / "index.html").read_text(encoding="utf-8")
MARKER = "<!--EVENT_PRESET-->"
if MARKER not in app:
    sys.exit("index.html is missing the <!--EVENT_PRESET--> marker")

built = []
for preset_file in sorted(root.glob("*/preset.json")):
    folder = preset_file.parent
    preset = json.loads(preset_file.read_text(encoding="utf-8"))
    # Compact JSON, safe to embed inside a <script> (escape </ to avoid closing the tag).
    blob = json.dumps(preset, ensure_ascii=False).replace("</", "<\\/")
    inject = f'<script>window.EVENT_PRESET = {blob};</script>'
    out = app.replace(MARKER, inject, 1)
    (folder / "index.html").write_text(out, encoding="utf-8")
    built.append(f"{folder.name}/index.html  ({len(preset.get('games', []))} games, {len(preset.get('teams', []))} teams)")

print("Built:" if built else "No */preset.json found.")
for b in built:
    print("  " + b)

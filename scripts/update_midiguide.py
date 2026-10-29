#!/usr/bin/env python3
"""Refresh the bundled midi.guide CC catalog (CC LFO browser, phase 61).

    scripts/update_midiguide.py

Downloads the midi.guide database (github.com/pencilresearch/midi, one CSV
per device, CC BY-SA 4.0), keeps the rows that carry a CC number, and writes
Resources/MIDIGuide/midiguide.json plus NOTICE.md (attribution + licence).
Run it before a release; build.sh copies the folder into the app bundle.
"""
import csv
import io
import json
import tarfile
import urllib.request
from datetime import date
from pathlib import Path

REPO = "pencilresearch/midi"
HEAD_SHA = f"https://api.github.com/repos/{REPO}/commits/main"
TARBALL = f"https://codeload.github.com/{REPO}/tar.gz/{{sha}}"
OUT_DIR = Path(__file__).resolve().parents[1] / "Resources/MIDIGuide"


def cc_number(text: str) -> int | None:
    """0–119: CC 120–127 are channel-mode messages (All Notes Off, Local
    Control, Omni/Mono/Poly) — an LFO there would cut notes or switch modes."""
    try:
        value = int(text.strip())
    except ValueError:
        return None
    return value if 0 <= value <= 119 else None


def bound(text: str, default: int) -> int:
    try:
        return max(0, min(127, int(float(text.strip()))))
    except ValueError:
        return default


def parse(archive: bytes) -> list[dict]:
    """manufacturer → model → parameters, alphabetical; rows in file order."""
    catalog: dict[str, dict[str, list[dict]]] = {}
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as tar:
        for member in tar.getmembers():
            name = member.name
            if not member.isfile() or not name.endswith(".csv") or name.endswith(".triggers.csv"):
                continue
            text = tar.extractfile(member).read().decode("utf-8-sig")
            for row in csv.DictReader(io.StringIO(text)):
                cc = cc_number(row.get("cc_msb") or "")
                manufacturer = (row.get("manufacturer") or "").strip()
                device = (row.get("device") or "").strip()
                parameter = (row.get("parameter_name") or "").strip()
                if cc is None or not manufacturer or not device or not parameter:
                    continue
                low = bound(row.get("cc_min_value") or "", 0)
                high = bound(row.get("cc_max_value") or "", 127)
                if low == high:
                    continue                # a command (e.g. "Store"), nothing to sweep
                catalog.setdefault(manufacturer, {}).setdefault(device, []).append({
                    "section": (row.get("section") or "").strip() or "General",
                    "name": parameter,
                    "cc": cc,
                    "min": min(low, high),
                    "max": max(low, high),
                })
    manufacturers = [
        {"name": manufacturer,
         "models": [{"name": model, "parameters": catalog[manufacturer][model]}
                    for model in sorted(catalog[manufacturer], key=str.casefold)]}
        for manufacturer in sorted(catalog, key=str.casefold)
    ]
    return manufacturers


def main() -> None:
    request = urllib.request.Request(HEAD_SHA,
                                     headers={"Accept": "application/vnd.github.sha"})
    with urllib.request.urlopen(request) as response:
        commit = response.read().decode().strip()
    with urllib.request.urlopen(TARBALL.format(sha=commit)) as response:
        manufacturers = parse(response.read())
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "midiguide.json").write_text(
        json.dumps(manufacturers, ensure_ascii=False, separators=(",", ":")))
    models = sum(len(m["models"]) for m in manufacturers)
    parameters = sum(len(model["parameters"]) for m in manufacturers for model in m["models"])
    (OUT_DIR / "NOTICE.md").write_text(f"""# midi.guide data

`midiguide.json` is derived from the midi.guide MIDI CC & NRPN database
(https://midi.guide, https://github.com/pencilresearch/midi), © its
contributors, licensed under Creative Commons Attribution-ShareAlike 4.0
International (https://creativecommons.org/licenses/by-sa/4.0/).

Changes: only parameters with a CC number 0–119 and a value range are kept
(NRPN-only rows, channel-mode messages, fixed-value commands and trigger
files are left out), converted from CSV to JSON. This derived file
is distributed under the same licence, CC BY-SA 4.0.

Source commit: {commit} · retrieved {date.today().isoformat()} ·
{len(manufacturers)} manufacturers, {models} models, {parameters} CC parameters.
""")
    print(f"midiguide: {len(manufacturers)} manufacturers, {models} models, "
          f"{parameters} CC parameters (commit {commit})")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Write the Sparkle appcast for one release (auto-update, phase 56).

    scripts/make_appcast.py <dmg> <version> <download-url> <out.xml>

The DMG is signed with Sparkle's sign_update (EdDSA key from the login
Keychain); the release notes are the version's CHANGELOG.md section,
rendered as simple HTML. Called by `build.sh dist`; the end-to-end update
test uses it with a local URL.
"""
import html
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

SIGN_UPDATE = ".build/artifacts/sparkle/Sparkle/bin/sign_update"
MIN_SYSTEM = "14.0"


def changelog_section(version: str) -> str:
    text = Path("CHANGELOG.md").read_text()
    match = re.search(rf"^## {re.escape(version)}\b.*?$(.*?)(?=^## |\Z)", text, re.S | re.M)
    return match.group(1).strip() if match else ""


def inline(md: str) -> str:
    out = html.escape(md)
    out = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", out)
    return re.sub(r"`(.+?)`", r"<code>\1</code>", out)


def notes_html(md: str) -> str:
    """Top-level bullets become <li>; indented bullets a nested list."""
    items: list[list] = []          # [text, [subitems]]
    for line in md.splitlines():
        if re.match(r"^- ", line):
            items.append([line[2:].strip(), []])
        elif re.match(r"^\s+- ", line) and items:
            items[-1][1].append(line.strip()[2:])
        elif line.strip() and items:
            target = items[-1][1]
            if target:
                target[-1] += " " + line.strip()
            else:
                items[-1][0] += " " + line.strip()
    parts = []
    for text, subs in items:
        sub = "".join(f"<li>{inline(s)}</li>" for s in subs)
        parts.append(f"<li>{inline(text)}" + (f"<ul>{sub}</ul>" if sub else "") + "</li>")
    return "<ul>" + "".join(parts) + "</ul>" if parts else ""


def main() -> None:
    dmg, version, url, out = sys.argv[1:5]
    signature = subprocess.run([SIGN_UPDATE, dmg], check=True,
                               capture_output=True, text=True).stdout.strip()
    if "sparkle:edSignature" not in signature:
        sys.exit(f"sign_update gave no signature: {signature!r}")
    date = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")
    notes = notes_html(changelog_section(version))
    Path(out).write_text(f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Berlinan</title>
    <link>https://jiripisa.github.io/berlinan/</link>
    <description>Berlinan updates</description>
    <item>
      <title>Berlinan {version}</title>
      <sparkle:version>{version}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{MIN_SYSTEM}</sparkle:minimumSystemVersion>
      <pubDate>{date}</pubDate>
      <description><![CDATA[{notes}]]></description>
      <enclosure url="{html.escape(url)}" type="application/octet-stream" {signature}/>
    </item>
  </channel>
</rss>
""")
    print(f"appcast: {out} ({version})")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Apply the KeySuite V3.00 Coupling Layout Correction.

This patcher is intentionally limited to frontend files:
- index.html
- manifest.json
- sw.js

It never reads or writes config.js and makes timestamped backups before changes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
import zipfile
from datetime import datetime
from pathlib import Path

VERSION = "3.00"
CACHE_VERSION = "v300"
START_MARKER = "/* KEYSUITE V3.00 COUPLING LAYOUT START */"
END_MARKER = "/* KEYSUITE V3.00 COUPLING LAYOUT END */"

CSS_BLOCK = r'''/* KEYSUITE V3.00 COUPLING LAYOUT START */
/* Keep Coupling controls, resolution message and bush information in normal document flow. */
.assembly-item-coupling .assembly-component-detail-row{
  display:block;
  min-height:0;
  overflow:visible;
}
.assembly-component-detail-row .assembly-coupling-options{
  display:grid;
  grid-template-columns:repeat(3,minmax(0,1fr));
  gap:10px;
  align-items:start;
  position:static;
  z-index:auto;
  width:100%;
  max-width:none;
  margin:0 0 10px!important;
}
.assembly-component-detail-row .assembly-coupling-options .assembly-item-option{
  display:grid;
  grid-template-rows:18px 42px;
  gap:4px;
  min-width:0;
  margin:0;
}
.assembly-component-detail-row .assembly-coupling-options .assembly-item-option label{
  margin:0;
  line-height:18px;
  white-space:nowrap;
}
.assembly-component-detail-row .assembly-coupling-options select,
.assembly-component-detail-row .assembly-coupling-options input{
  position:static;
  z-index:auto;
  width:100%;
  min-width:0;
  height:42px!important;
  box-sizing:border-box;
}
.assembly-component-detail-row .assembly-coupling-resolved-note,
.assembly-component-detail-row .assembly-coupling-bush-summary,
.assembly-component-detail-row .assembly-coupling-warning{
  display:block;
  position:static;
  z-index:auto;
  clear:both;
  width:100%;
  max-width:none;
  box-sizing:border-box;
  overflow-wrap:anywhere;
}
.assembly-component-detail-row .assembly-coupling-resolved-note{
  margin:0;
  padding:7px 10px;
  line-height:1.45;
}
.assembly-component-detail-row .assembly-coupling-bush-summary{
  margin:10px 0 0;
  padding:0;
  line-height:1.55;
  pointer-events:auto;
}
.assembly-component-detail-row .assembly-coupling-warning{
  margin:10px 0 0;
}
@media(max-width:900px){
  .assembly-component-detail-row .assembly-coupling-options{
    grid-template-columns:repeat(2,minmax(0,1fr));
  }
}
@media(max-width:620px){
  .assembly-component-detail-row .assembly-coupling-options{
    grid-template-columns:1fr;
  }
}
/* KEYSUITE V3.00 COUPLING LAYOUT END */'''


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8", newline="\n")


def inject_or_replace_css(html: str) -> str:
    if START_MARKER in html or END_MARKER in html:
        pattern = re.compile(
            re.escape(START_MARKER) + r".*?" + re.escape(END_MARKER),
            flags=re.DOTALL,
        )
        if not pattern.search(html):
            raise RuntimeError("V3.00 CSS marker pair is incomplete. Restore the backup and retry.")
        return pattern.sub(CSS_BLOCK, html, count=1)

    if "</style>" not in html:
        raise RuntimeError("index.html has no closing </style> tag.")
    return html.replace("</style>", f"\n  {CSS_BLOCK}\n  </style>", 1)


def update_index(html: str) -> tuple[str, list[str]]:
    required_markers = (
        "assembly-coupling-options",
        "assembly-coupling-resolved-note",
        "assembly-coupling-bush-summary",
    )
    missing = [marker for marker in required_markers if marker not in html]
    if missing:
        raise RuntimeError(
            "The target index.html does not contain the expected Coupling layout markers: "
            + ", ".join(missing)
        )

    html = inject_or_replace_css(html)
    changes: list[str] = ["Inserted/refreshed V3.00 Coupling layout CSS"]

    replacements = [
        (
            r"<title>\s*KeySuite\s+V[^<]+</title>",
            "<title>KeySuite V3.00</title>",
            "Updated browser title",
        ),
        (
            r'(<div class="auth-brand">KeySuite<small>)[^<]*(</small></div>)',
            r"\1V3.00 Coupling Layout Correction\2",
            "Updated sign-in version",
        ),
        (
            r'(<div class="brand">KeySuite<small>)[^<]*(</small></div>)',
            r"\1Full Suite V3.00\2",
            "Updated sidebar version",
        ),
        (
            r'<div class="suite-version">[^<]*</div>',
            '<div class="suite-version">KeySuite V3.00 · Coupling Layout Correction</div>',
            "Updated footer version",
        ),
    ]
    for pattern, replacement, label in replacements:
        updated, count = re.subn(pattern, replacement, html, count=1, flags=re.IGNORECASE)
        if count:
            html = updated
            changes.append(label)

    # Refresh local application script URLs. Keep config.js untouched so the deployment
    # configuration remains exactly as supplied by the user.
    def script_repl(match: re.Match[str]) -> str:
        prefix, path, _old_query, suffix = match.groups()
        if Path(path).name.lower() == "config.js":
            return match.group(0)
        return f'{prefix}{path}?v=300{suffix}'

    html, script_count = re.subn(
        r'(<script\s+src=")((?!https?://)[^"?]+\.js)(\?v=[^"]+)?("></script>)',
        script_repl,
        html,
        flags=re.IGNORECASE,
    )
    if script_count:
        changes.append(f"Refreshed {script_count} local script cache keys")

    html = re.sub(
        r'(<link\s+rel="manifest"\s+href="manifest\.json)(?:\?v=[^"]+)?(")',
        r"\1?v=300\2",
        html,
        count=1,
        flags=re.IGNORECASE,
    )
    return html, changes


def update_manifest(text: str) -> tuple[str, list[str]]:
    data = json.loads(text)
    data["name"] = "KeySuite V3.00"
    output = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    return output, ["Updated manifest name to KeySuite V3.00"]


def update_sw(text: str) -> tuple[str, list[str]]:
    updated, count = re.subn(
        r"const\s+CACHE\s*=\s*['\"]keysuite-[^'\"]+['\"]\s*;",
        "const CACHE='keysuite-v300';",
        text,
        count=1,
    )
    if not count:
        raise RuntimeError("sw.js does not contain the expected KeySuite CACHE declaration.")
    return updated, ["Updated service-worker cache to keysuite-v300"]


def make_changed_files_zip(target: Path, output: Path) -> None:
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for filename in ("index.html", "manifest.json", "sw.js"):
            archive.write(target / filename, arcname=filename)
        result = target / "V300_PATCH_RESULT.txt"
        if result.exists():
            archive.write(result, arcname=result.name)


def apply(target: Path, create_backup: bool = True) -> Path:
    target = target.resolve()
    files = {name: target / name for name in ("index.html", "manifest.json", "sw.js")}
    missing = [name for name, path in files.items() if not path.is_file()]
    if missing:
        raise RuntimeError(
            f"Target folder is not a KeySuite source folder. Missing: {', '.join(missing)}"
        )

    before_hashes = {name: sha256(path) for name, path in files.items()}
    config_path = target / "config.js"
    config_before = sha256(config_path) if config_path.is_file() else None

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = target / f".keysuite_v300_backup_{timestamp}"
    if create_backup:
        suffix = 1
        while backup_dir.exists():
            backup_dir = target / f".keysuite_v300_backup_{timestamp}_{suffix}"
            suffix += 1
        backup_dir.mkdir(parents=True, exist_ok=False)
        for name, path in files.items():
            shutil.copy2(path, backup_dir / name)

    all_changes: list[str] = []
    try:
        index_text, changes = update_index(read_text(files["index.html"]))
        all_changes.extend(changes)
        manifest_text, changes = update_manifest(read_text(files["manifest.json"]))
        all_changes.extend(changes)
        sw_text, changes = update_sw(read_text(files["sw.js"]))
        all_changes.extend(changes)

        write_text(files["index.html"], index_text)
        write_text(files["manifest.json"], manifest_text)
        write_text(files["sw.js"], sw_text)
    except Exception:
        if create_backup and backup_dir.exists():
            for name in files:
                shutil.copy2(backup_dir / name, files[name])
        raise

    after_hashes = {name: sha256(path) for name, path in files.items()}
    config_after = sha256(config_path) if config_path.is_file() else None
    if config_before != config_after:
        raise RuntimeError("Safety stop: config.js changed unexpectedly.")

    # Idempotence/integrity checks on the actual patched files.
    final_index = read_text(files["index.html"])
    checks = {
        "V3.00 CSS marker occurs once": final_index.count(START_MARKER) == 1 and final_index.count(END_MARKER) == 1,
        "Three-column desktop Coupling layout exists": "grid-template-columns:repeat(3,minmax(0,1fr))" in final_index,
        "Resolution note is in normal flow": ".assembly-component-detail-row .assembly-coupling-resolved-note" in final_index and "position:static" in final_index,
        "Bush summary is separated": "margin:10px 0 0" in final_index,
        "Mobile single-column rule exists": "@media(max-width:620px)" in final_index,
        "Service-worker cache is V3.00": "keysuite-v300" in read_text(files["sw.js"]),
        "Manifest is V3.00": json.loads(read_text(files["manifest.json"])).get("name") == "KeySuite V3.00",
        "config.js preserved": config_before == config_after,
    }
    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        raise RuntimeError("Post-patch QA failed: " + "; ".join(failed))

    result_lines = [
        "KeySuite V3.00 Patch Result",
        "===========================",
        f"Applied: {datetime.now().isoformat(timespec='seconds')}",
        f"Target: {target}",
        "",
        "Changes",
        "-------",
        *[f"PASS - {item}" for item in all_changes],
        "",
        "Integrity Checks",
        "----------------",
        *[f"PASS - {name}" for name, passed in checks.items() if passed],
        "",
        "File SHA-256",
        "-------------",
    ]
    for name in files:
        result_lines.append(f"{name}: {before_hashes[name]} -> {after_hashes[name]}")
    result_lines.extend(
        [
            "",
            f"Backup: {backup_dir if create_backup else 'disabled'}",
            "Database migration: none",
            "config.js: not modified",
        ]
    )
    result_path = target / "V300_PATCH_RESULT.txt"
    write_text(result_path, "\n".join(result_lines) + "\n")

    output_zip = target / "KeySuite_V3.00_Changed_Files.zip"
    make_changed_files_zip(target, output_zip)
    return output_zip


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Apply KeySuite V3.00 Coupling layout correction")
    parser.add_argument(
        "--target",
        type=Path,
        default=Path.cwd(),
        help="KeySuite repository/source folder (default: current folder)",
    )
    parser.add_argument("--no-backup", action="store_true", help="Do not create timestamped backups")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        output = apply(args.target, create_backup=not args.no_backup)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    print("KeySuite V3.00 patch completed successfully.")
    print(f"Changed-files ZIP: {output}")
    print("No Supabase migration is required.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

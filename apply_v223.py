#!/usr/bin/env python3
"""Apply the KeySuite V2.23 runtime integration to an existing V2.22 source folder.

Usage:
    python apply_v223.py C:\\path\\to\\KeySuite_V2.22
"""
from __future__ import annotations
import argparse
import re
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent


def backup(path: Path) -> None:
    backup_path = path.with_suffix(path.suffix + '.v222.bak')
    if path.exists() and not backup_path.exists():
        shutil.copy2(path, backup_path)


def replace_required(text: str, pattern: str, replacement: str, label: str, count: int = 1, flags: int = 0) -> str:
    updated, hits = re.subn(pattern, replacement, text, count=count, flags=flags)
    if hits == 0:
        raise RuntimeError(f'Could not locate the V2.22 {label} pattern. No file was overwritten.')
    return updated


def patch_app(path: Path) -> None:
    backup(path)
    text = path.read_text(encoding='utf-8')
    if 'v223Reference=await window.KeySuiteV223.nextQuotationReference' not in text:
        text = replace_required(
            text,
            r'function\s+newQuote\s*\(\s*\)\s*\{',
            "async function newQuote(){\n let v223Reference='';try{v223Reference=await window.KeySuiteV223.nextQuotationReference()}catch(error){alert(error?.message||String(error));return}",
            'newQuote function'
        )
        text = replace_required(
            text,
            r"\$\('quoteNo'\)\.value\s*=\s*nextQuoteNo\(\)\s*;",
            "$('quoteNo').value=v223Reference;",
            'quotation number assignment'
        )
    path.write_text(text, encoding='utf-8')


def patch_index(path: Path) -> None:
    backup(path)
    text = path.read_text(encoding='utf-8')
    text = text.replace('V2.22','V2.23').replace('v2.22','v2.23')
    if 'v223-runtime.js' not in text:
        text = replace_required(
            text,
            r'</body>',
            '  <script src="v223-runtime.js?v=223"></script>\n</body>',
            'closing body tag',
            flags=re.I
        )
    path.write_text(text, encoding='utf-8')


def patch_auth(path: Path) -> None:
    backup(path)
    text = path.read_text(encoding='utf-8')
    text = text.replace("version:'2.22'", "version:'2.23'")
    text = text.replace("release_date:'2026-08-02'", "release_date:'2026-08-03'")
    path.write_text(text, encoding='utf-8')


def patch_sw(path: Path) -> None:
    backup(path)
    text = path.read_text(encoding='utf-8')
    text = re.sub(r"const\s+CACHE\s*=\s*'[^']+'", "const CACHE='keysuite-v223'", text, count=1)
    if 'v223-runtime.js' not in text:
        text = replace_required(
            text,
            r"(const\s+SHELL\s*=\s*\[)",
            r"\1'./v223-runtime.js',",
            'service-worker shell list'
        )
    path.write_text(text, encoding='utf-8')


def patch_version(path: Path) -> None:
    backup(path)
    path.write_text('2.23\n', encoding='utf-8')


def patch_readme(path: Path) -> None:
    if not path.exists():
        return
    backup(path)
    text = path.read_text(encoding='utf-8')
    text = re.sub(r'^#\s+KeySuite\s+V2\.22', '# KeySuite V2.23', text, count=1, flags=re.M)
    marker = '## V2.23 additions'
    if marker not in text:
        text += f'''\n\n{marker}\n\n- Unique per-user quotation prefixes with case-insensitive duplicate blocking.\n- Quotation references use `[Prefix]-[YYMM]-[Running Number]`; the sequence resets only when the calendar year changes.\n- Motor Product and Price List for IE1 through IE5.\n- Motor prefixes: BM, 2BM, 3BM, 4BM and 5BM.\n- Motor Assembly actions route to Pumpset > Motor.\n'''
    path.write_text(text, encoding='utf-8')


def main() -> int:
    parser = argparse.ArgumentParser(description='Apply KeySuite V2.23 to a V2.22 source directory.')
    parser.add_argument('target', type=Path, help='Existing KeySuite V2.22 source directory')
    args = parser.parse_args()
    target = args.target.resolve()
    required = ['app.js','index.html','auth.js','sw.js','VERSION.txt']
    missing = [name for name in required if not (target/name).exists()]
    if missing:
        raise SystemExit('Missing required V2.22 files: ' + ', '.join(missing))

    patch_app(target/'app.js')
    patch_index(target/'index.html')
    patch_auth(target/'auth.js')
    patch_sw(target/'sw.js')
    patch_version(target/'VERSION.txt')
    patch_readme(target/'README.md')

    shutil.copy2(HERE/'v223-runtime.js', target/'v223-runtime.js')
    shutil.copy2(HERE/'V223_SUPABASE_MIGRATION.sql', target/'V223_SUPABASE_MIGRATION.sql')
    (target/'setup').mkdir(exist_ok=True)
    shutil.copy2(HERE/'setup'/'V223_SUPABASE_MIGRATION.sql', target/'setup'/'V223_SUPABASE_MIGRATION.sql')
    for name in ['INSTALL_V223.txt','V223_CHANGES.txt','V223_QA_REPORT.txt']:
        if (HERE/name).exists(): shutil.copy2(HERE/name,target/name)

    print('KeySuite V2.23 patch applied successfully.')
    print('Backups use the suffix .v222.bak.')
    print('Next: run V223_SUPABASE_MIGRATION.sql, deploy, and hard-refresh.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

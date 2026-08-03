import subprocess,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as td:
    d=Path(td)
    (d/'app.js').write_text("function newQuote(){\n $('quoteNo').value=nextQuoteNo();\n}\n")
    (d/'index.html').write_text("<html><body><h1>KeySuite V2.22</h1></body></html>")
    (d/'auth.js').write_text("return {version:'2.22',release_date:'2026-08-02'};")
    (d/'sw.js').write_text("const CACHE='keysuite-v222';\nconst SHELL=['./','./app.js'];")
    (d/'VERSION.txt').write_text('2.22\n')
    (d/'README.md').write_text('# KeySuite V2.22\n')
    subprocess.run(['python',str(root/'apply_v223.py'),str(d)],check=True,capture_output=True,text=True)
    assert 'async function newQuote' in (d/'app.js').read_text()
    assert 'nextQuotationReference' in (d/'app.js').read_text()
    assert 'v223-runtime.js' in (d/'index.html').read_text()
    assert "keysuite-v223" in (d/'sw.js').read_text()
    assert (d/'VERSION.txt').read_text().strip()=='2.23'
    assert (d/'app.js.v222.bak').exists()
    assert (d/'setup'/'V223_SUPABASE_MIGRATION.sql').exists()
print('PASS - V2.23 patcher safely updates a V2.22 fixture and creates backups')

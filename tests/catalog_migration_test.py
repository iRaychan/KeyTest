import json,re
from collections import Counter
from pathlib import Path
root=Path(__file__).resolve().parents[1]
cat=json.loads((root/'motor-catalog.json').read_text())
assert len(cat)==680, len(cat)
counts=Counter(x['efficiency_class'] for x in cat)
assert counts=={'IE1':136,'IE2':136,'IE3':136,'IE4':136,'IE5':136},counts
assert len({x['id'] for x in cat})==680
assert len({x['model'] for x in cat})==680
assert all(x['pole'] in (2,4,6,8) for x in cat)
assert next(x for x in cat if x['model']=='BM20-2')['description']=='20HP 2Pole IE1 Motor'
assert next(x for x in cat if x['model']=='2BM20-2')['description']=='20HP 2Pole IE2 Motor'
assert next(x for x in cat if x['model']=='3BM50-4')['description']=='50HP 4Pole IE3 Motor'
assert next(x for x in cat if x['model']=='4BM20-8')['description']=='20HP 8Pole IE4 Motor'
assert next(x for x in cat if x['model']=='5BM600-6')['description']=='600HP 6Pole IE5 Motor'
sql=(root/'V223_SUPABASE_MIGRATION.sql').read_text()
assert sql.count("('motor-ie")==680, sql.count("('motor-ie")
for token in ["'IE1','IE2','IE3','IE4','IE5'","'BM','2BM','3BM','4BM','5BM'",'keysuite_next_quotation_reference_v223','keysuite_decode_motor_model_v223']:
    assert token in sql,token
assert (root/'setup'/'V223_SUPABASE_MIGRATION.sql').read_bytes()==(root/'V223_SUPABASE_MIGRATION.sql').read_bytes()
print('PASS - 680 catalogue rows, five efficiency classes, SQL seed and setup copy')

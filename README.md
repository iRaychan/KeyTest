# KeySuite V2.23 Upgrade Patch

This package upgrades an existing **KeySuite V2.22** source folder to V2.23.

## Included amendments

- Unique per-user quotation prefixes.
- Reference format `[Prefix]-[YYMM]-[Running Number]`.
- Annual sequence reset only.
- Motor Product and Price List for IE1 through IE5.
- Prefixes `BM`, `2BM`, `3BM`, `4BM`, and `5BM`.
- Motor Assembly route fixed to `Pumpset > Motor`.
- 680 seeded motor catalogue combinations.
- Custom model decoding, including `3BM50-5`.

## Apply

```text
python apply_v223.py C:\path\to\KeySuite_V2.22
```

Then run `V223_SUPABASE_MIGRATION.sql` in Supabase, deploy, and hard-refresh.

The patcher creates `.v222.bak` backups of amended files. Keep the existing deployment `config.js`.

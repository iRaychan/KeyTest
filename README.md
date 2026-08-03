# KeySuite V2.23

KeySuite V2.23 is a complete source build based on V2.22.

## V2.23 additions

### Motor IE1–IE5

- Product > Motor page.
- Key > Price List > Motor page.
- Category Pricing Rule support for `MOTOR`.
- Quotation and Assembly pricing integration.
- Model prefixes:
  - IE1 = `BM`
  - IE2 = `2BM`
  - IE3 = `3BM`
  - IE4 = `4BM`
  - IE5 = `5BM`
- Model decoding follows `[Efficiency Prefix][HP]-[Pole]`.
  - `BM20-2` = `20HP 2Pole IE1 Motor`
  - `3BM50-5` = `50HP 5Pole IE3 Motor`
- The supplied catalogue contains 680 standard entries: 34 HP ratings × 4 standard poles × 5 efficiency classes.
- Prices in the supplied Motor workbook are placeholders/zero values and remain editable in KeySuite.

### Motor Assembly routing

Motor **Assembly** actions route only to:

`Assembly → Pumpset → Motor`

They do not route to System.

### Per-user quotation references

- Format: `[Prefix]-[YYMM]-[Running Number]`.
- Each user saves a unique 1–8 character alphanumeric prefix in Settings.
- Duplicate prefixes are blocked case-insensitively.
- The running number continues across months and resets only when the calendar year changes.

## Upgrade from V2.22

1. Back up the current V2.22 deployment and Supabase database.
2. Run `V223_SUPABASE_MIGRATION.sql` in Supabase SQL Editor.
3. Upload this complete V2.23 source to GitHub.
4. Preserve the existing working `config.js`; do not replace it with `setup/config.example.js`.
5. Wait for deployment, then hard-refresh the browser with `Ctrl+F5`.
6. Each user opens Settings and saves a unique quotation prefix.
7. Enter Motor source prices and test Product, Price List, Category Pricing, Quote and Pumpset routing.

The migration is included in the root folder and `setup/`. It is not run automatically by the source package.

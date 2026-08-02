# KeySuite V2.18

KeySuite V2.18 isolates Assembly drafts by quotation, standardises coupled-description indentation, and adds reusable quotation templates for company and dealer use.

## Main changes

- New quotations start with an empty Assembly/System draft workspace; drafts are linked to their quotation session.
- Coupled component continuation rows use exactly one tab and no extra spaces in Assembly, Quotation and PDF output.
- KeyPLC wiring is combined into one line: `Wiring for pumps & pressure transmitter within pump skid @ 1 Lot`.
- Multiple quotation templates support company-wide and personal/dealer ownership, logos, company details, colours, fonts, price-column layout, quotation defaults, signature visibility, headers, footers and PDF filename patterns.
- Sealed quotations retain a template snapshot so later template edits do not change the original output.

## Upgrade from V2.17

1. Run `V218_SUPABASE_MIGRATION.sql` in Supabase SQL Editor.
2. Apply `KeySuite_V2.18_Changed_Files_Patch.zip` over V2.17.
3. Preserve the existing working `config.js`.
4. Deploy and hard refresh with `Ctrl + Shift + R`.

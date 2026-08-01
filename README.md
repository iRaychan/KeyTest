# KeySuite V2.17

KeySuite V2.17 keeps the visible System Description synchronized with BOM changes and improves System/Pumpset quotation PDF layout.

## Main changes

- System Description refreshes immediately after BOM quantity, price, panel type, component, or automatic-selection changes.
- Coupled component descriptions use `c/w ` on the first row and exactly four leading spaces on continuation rows.
- Existing tab-based descriptions are normalized when reopened or transferred to Quotation.
- System/Pumpset PDF descriptions span the Description and Qty columns, while Qty, Unit Price and Total remain on the item header row.
- Long Manifold descriptions such as `2.5" inlet & 2.5" outlet` receive the wider System/Pumpset print area.

## Upgrade from V2.16

1. Apply `KeySuite_V2.17_Changed_Files_Patch.zip` over V2.16.
2. Preserve the existing working `config.js`.
3. No new Supabase migration is required.
4. Hard refresh after deployment.

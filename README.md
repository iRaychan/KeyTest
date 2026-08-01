# KeySuite V2.16

KeySuite V2.16 improves System BOM controls, description editing and global action-button consistency.

## Main changes

- End Suction descriptions now show the clean pump model, suction/discharge DN sizes, expanded Mech Seal/Gland Packing wording, and bare-shaft wording.
- Product > End Suction includes Mech Seal Material and Elastomer selectors with pink non-default highlighting.
- The System New button is hidden; adding another Pumpset automatically saves the existing System draft and opens a new System.
- Existing System drafts can be reopened and updated with Pumpsets, panels, Manifolds and Tanks while preserving fixed description grouping.
- System Description shows one highlighted view and opens an Arial popup editor on double-click.
- Auto-selected Manifold and Tank Qty/Unit Price fields are locked but the items remain deletable. System BOM colours extend through component titles and rows.
- Coupled descriptions use tab-aligned `c/w` formatting.

## Upgrade from V2.15

1. Apply `KeySuite_V2.16_Changed_Files_Patch.zip` over V2.15.
2. Preserve the existing working `config.js`.
3. No new Supabase migration is required.
4. Hard refresh after deployment.

# KeySuite V2.15

KeySuite V2.15 improves End Suction product descriptions and configuration, and refines the System draft and BOM workflow.

## Main changes

- End Suction descriptions now show the clean pump model, suction/discharge DN sizes, expanded Mech Seal/Gland Packing wording, and bare-shaft wording.
- Product > End Suction includes Mech Seal Material and Elastomer selectors with pink non-default highlighting.
- The System New button is hidden; adding another Pumpset automatically saves the existing System draft and opens a new System.
- Existing System drafts can be reopened and updated with Pumpsets, panels, Manifolds, Tanks and MISC items while preserving fixed description grouping.
- System Description has a highlighted variable-value preview for internal checking only.
- System BOM rows use category background colours.
- Coupled descriptions use tab-aligned `c/w` formatting.

## Upgrade from V2.14

1. Apply `KeySuite_V2.15_Changed_Files_Patch.zip` over V2.14.
2. Preserve the existing working `config.js`.
3. No new Supabase migration is required.
4. Hard refresh after deployment.

# KeySuite V2.29 Update Patch

Upgrade path: **V2.28 → V2.29**

## Installation

1. Back up the current V2.28 deployment and database.
2. Run `V229_SUPABASE_MIGRATION.sql` in Supabase SQL Editor.
3. Replace the supplied application files in GitHub.
4. Keep the existing working `config.js`; it is not included in this patch.
5. Deploy, press `Ctrl+F5`, then sign in again.

## Included application files

- `index.html`
- `assembly.js`
- `coupling.js`
- `manifest.json`
- `sw.js`
- `VERSION.txt`

## Main changes

- FCL 224 maximum speed corrected to 3,000 rpm.
- Product Coupling clearly separates Auto Size and Manual Selection.
- Suitability table shows model-by-model reasons.
- Tyre coupling shows F/H bush arrangement, bush models, actual shafts, maximum shafts, and status.
- Tyre auto-sizing applies the pump shaft 24 mm rule and evaluates Motor-side F Bush to reduce coupling size.
- Pumpset BOM adds Flexible, Pin & Bush, and Tyre selection buttons; Flexible is the default.
- Flexible mode selects the higher-priced suitable Pin & Bush or Tyre option.
- Multiple Pumps/Motors size from the largest shafts, highest individual torque, and highest speed.
- Pump/Motor edits or deletion automatically recalculate or clear the coupling.
- Completed Pumpset description combines Pump, Motor, Baseplate, and Coupling information.

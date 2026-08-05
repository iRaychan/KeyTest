# KeySuite V2.31 Update-Only Patch

Upgrade path: **V2.30 → V2.31**

## Installation order

1. Back up the current V2.30 deployment and Supabase database.
2. Run `V231_SUPABASE_MIGRATION.sql` in Supabase SQL Editor.
3. Replace the application files supplied in this patch.
4. Keep the existing working `config.js`; this patch does not include or replace it.
5. Deploy, press `Ctrl+F5`, then sign out and log in again.

## Changed application files

- `app.js`
- `assembly.js`
- `coupling.js`
- `motor.js`
- `quotation-templates.js`
- `index.html`
- `manifest.json`
- `sw.js`
- `VERSION.txt`

## Main changes

- Customer-assigned default quotation templates, while saved quotations retain their own template.
- Coupling quotation shaft information with Pump shaft, Motor shaft, Motor Pole and derived nominal rpm.
- Motor speed mapping: 2 Pole 2,900 rpm; 4 Pole 1,450 rpm; 6 Pole 960 rpm; 8 Pole 720 rpm.
- B.G.Reich removed from quotation descriptions and model text.
- Coupling Product selection reordered and prepared with an ES Pump Series selector.
- Bush pricelist hides Torque and Maximum Speed columns.
- Unified Assembly/Pumpset BOM first-row alignment and component colours.
- Coupling type buttons replaced by a Selected Type dropdown in the BOM.
- IE3 remains the Motor default; other efficiencies use the existing non-default input colour.
- New Pumpset capacity defaults to m³/h.

This package has not been deployed to GitHub or run against the live Supabase project.

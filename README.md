# KeySuite V2.24

KeySuite V2.24 is a complete source build based on V2.23.

## V2.24 additions

### Product > Motor Model

- Replaces the large standard-model table with direct selection fields.
- Selection order: **HP / Pole / Efficiency**.
- Pole options: 2 Pole, 4 Pole, 6 Pole and 8 Pole.
- Efficiency options: IE1, IE2, IE3, IE4 and IE5.
- Efficiency defaults to **IE3**.
- The model and description are generated from the selection.
- Standard Motor Assembly actions continue to route only to `Assembly → Pumpset → Motor`.
- Custom Motor models remain available, including non-standard poles such as `3BM50-5`.

### Motor Price List

- Currency selection now follows the CHC/ES price-list method.
- The **Currency & Multipliers** panel is collapsible and starts collapsed.
- The panel contains only Currency Selection, USD → MYR and RMB → MYR.
- USD/RMB multipliers use the same 3-second hold-to-edit pattern as CHC/ES.
- Efficiency and Pole are outside the currency panel.
- Efficiency defaults to **IE3**.
- Pole options are 2 Pole, 4 Pole, 6 Pole and 8 Pole.
- No Search field is shown on the Motor Price List.
- The price table displays one row per HP for the selected Efficiency and Pole.
- The price input label and prefix change with USD, RMB or MYR selection.

## Existing V2.23 Motor rules retained

- IE1 = `BM`
- IE2 = `2BM`
- IE3 = `3BM`
- IE4 = `4BM`
- IE5 = `5BM`
- Motor Assembly routing: `Assembly → Pumpset → Motor`
- Per-user quotation references remain unchanged.

## Upgrade from V2.23

1. Back up the current V2.23 deployment.
2. No new V2.24 Supabase migration is required.
3. Upload this complete V2.24 source to GitHub.
4. Preserve the existing working `config.js`; do not replace it with `setup/config.example.js`.
5. Wait for deployment, then hard-refresh the browser with `Ctrl+F5`.
6. Test Product > Motor and Key > Price List > Motor.

A database with V223_SUPABASE_MIGRATION.sql already applied is required for the Motor module.

# KeySuite V2.13

KeySuite V2.13 adds the Manifold workbook as a complete database-backed Price List and Product module, exposes its Category and Company Pricing rules, restores the manual quoted-value calculator in the visible Category Pricing Rule panel, and includes the requested quotation and End Suction refinements.

## Highlights

- End Suction Product material dropdown no longer offers `CI BR SS MS` or `CI BR SS GP`.
- Quotation item action and dialog wording now use **Remarks**; internal-only storage, `#D5BD50` highlighting and print/PDF exclusion remain unchanged.
- KeyPLC System Description uses a shared tab stop so `Pump Controller`, motor kW/VFD and `Wiring` begin directly below `KeyPLC` on screen and in print/PDF output.
- The supplied Manifold workbook is seeded into `ks_products_manifold` with four editable tables: Branch, Manifold Sizing, Header and Tank Fitting.
- Manifold is available in Product, Price List, Category Management and Company & Pricing.
- Product > Manifold calculates the header size from the larger pump connection and pump quantity, adds branch/header/tank-fitting source prices, applies the Manifold category rule, and routes the result to Assembly or Quotation.
- The Manual Quoted Value Calculator is visible directly inside Company & Pricing > Category Pricing Rule and supports USD/RMB/MYR plus Many/Common/Rare.

## Installation

1. Run `V213_SUPABASE_MIGRATION.sql` in Supabase SQL Editor.
2. Deploy the V2.13 changed-files patch over V2.12, preserving the existing working `config.js`.
3. Hard-refresh the application with `Ctrl + Shift + R`.

The original supplied workbook is retained under `source_pricelists/` for reference.

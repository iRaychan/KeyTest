# KeySuite V2.14

KeySuite V2.14 improves System and Pumpset quotation transfer, isolates each new quotation from previous quotation/System work, and adds automatic KeyPLC control-panel, Manifold and GWS tank selection from the pump BOM.

## Highlights

- End Suction materials appear in the required sequence with the two obsolete BR options removed.
- Coupled KeyPLC descriptions use `c/w` on row 1 and exactly four leading spaces on continuation rows; direct Product > KeyPLC quotations omit `c/w`.
- KeyPLC wiring is separated into pump wiring and pressure-transmitter wiring lines.
- System/Pumpset quotation items use Set/Sets and no longer include the internal Pumpset/Control Panel BOM summary.
- New Quotation creates a separate quotation/System session so old customer pricing and working data are not reused.
- Automatically selected System BOM control-panel quantity and unit price are read-only and visibly filled.
- Manifold defaults are GI, Flange 16 Bar, 2 Pumps and Common; non-default fields are highlighted pink.
- Automatic Manifold pricing follows pump DN, total pump quantity and the selected pressure connection.
- Manifold pressure connection follows zero-flow shut-off head, with Flange 16 Bar as the no-curve fallback.
- Automatic GWS tank volume follows the CHC series and tank pressure rating is selected strictly above the zero-flow shut-off pressure.

## Installation

1. Deploy the V2.14 changed-files patch over V2.13, preserving the existing working `config.js`.
2. No new Supabase migration is required for V2.14. V2.13's Manifold migration must already be installed.
3. Hard-refresh the application with `Ctrl + Shift + R`.

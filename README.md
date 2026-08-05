# KeySuite V2.32

Complete KeySuite source updated from V2.31.

## Installation

1. Back up the current deployment.
2. Upload the V2.32 source files to GitHub.
3. Keep the existing working `config.js` because it is not included in this package.
4. No new Supabase migration is required for V2.32.
5. Deploy, press `Ctrl+F5`, then sign out and log in again if cached files remain.

## V2.32 changes

- Coupling and Baseplate BOM fill colours now apply to normal and auto-generated items.
- Coupling type in Pumpset BOM can change reliably between Flexible, Pin & Bush, and Tyre.
- Coupling quotation Model/Item includes the selected coupling type.
- Standalone Coupling type text is removed from the quotation description.
- Motor quotation descriptions begin with `B.G.Reich`.
- Motor quotation items no longer show Capacity and Head controls.
- Coupling shaft-information checkbox matches the standard Capacity checkbox size.
- Product > Coupling actions and selected model are combined into the top row.
- Quotation print Description font is 10 pt.
- Assembly BOM input heights and component header alignment are standardized.

See `V232_QA_REPORT.txt` for completed checks.

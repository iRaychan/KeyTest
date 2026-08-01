# KeySuite V2.12

KeySuite V2.12 adds consistent default-selection highlighting across Product and Selector, source-price completion indicators, a manual category-rule quoted-value calculator, internal quotation-item remarks, and corrected KeyPLC description alignment.

## Highlights

- CHC defaults are highlighted pink whenever Product or Selector uses a non-default material, mechanical seal, elastomer, connection, or supply option.
- ES Product rows provide a material dropdown with `CI SS SS MS` as the default; non-default materials are highlighted pink.
- GWS Product provides Series and Model dropdowns, including Pressure Wave models.
- KeyPLC Product defaults to 2 pumps and highlights non-default pump quantities pink.
- Every Price List family shows USD, RMB, and MYR filled counts against the total available price cells.
- Category Pricing Rule includes a manual USD/RMB/MYR cost calculator with Many, Common, and Rare formula selection and immediate MYR quoted value.
- Quotation items include an internal-only Remark button and collapsed-item indicator in `#D5BD50`; remarks are excluded from print and PDF output.
- KeyPLC System Description lines now share the same left alignment without spaces or non-breaking-space indentation.
- No Supabase migration is required for V2.12.

Preserve the deployment's working `config.js`, deploy the V2.12 changed-files patch, and hard-refresh the application.

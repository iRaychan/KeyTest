# KeySuite V2.08

KeySuite V2.08 corrects CHC PDF material/seal output, keeps Product default duty points out of Quotation and Assembly descriptions, improves Assembly-only tank wording, makes all Price List currency panels collapsible, and integrates the supplied KeyPLC control-panel price list.

## Database

Run `V208_SUPABASE_MIGRATION.sql` after the existing V2.05 database migration and before deploying the V2.08 website files. Preserve the deployment's working `config.js`.

## Main changes

- CHC Selector and Product PDF output uses the selected material, seal faces and elastomer.
- Product reference duty points remain on curves/PDFs but are excluded from descriptions.
- Assembly tank descriptions are concise, quantity-aware and placed without a blank row.
- CHC, ES, GWS and KeyPLC currency panels start collapsed.
- KeyPLC is available in Product, Price List, Assembly routing, Quotation, Category and Company Pricing.
- The KeyPLC workbook values are seeded as MYR for 0.75kW through 110kW models.

See `V208_CHANGES.txt` and `INSTALL_V208.txt` for details.

# KeySuite V2.19

KeySuite V2.19 adds quotation-template identification, consistent coupled-description tab alignment, and quotation safeguards for invalid pricing inputs.

## Main changes

- Shows the selected quotation-template logo beside the Quotation No.; sealed quotations use the saved template snapshot logo.
- Formats coupled descriptions with exactly one tab after `c/w` on the first row and exactly two tabs on continuation rows.
- Keeps all existing company Category Pricing Rule percentages: Margin, Normal, Rare, Transport, Commission, Set Discount, Final Discount and Fuel Charge.
- Blocks quotation actions when the applicable Margin is blank/0% or when no positive converted USD, RMB or MYR source cost is available.

## Upgrade from V2.18

1. Back up the existing deployment.
2. Apply `KeySuite_V2.19_Changed_Files_Patch.zip` over V2.18.
3. Preserve the existing working `config.js`.
4. No new Supabase migration is required.
5. Deploy and hard-refresh with `Ctrl + Shift + R`.

## Clean installation

Use `KeySuite_V2.19_GitHub.zip`, provide the deployment `config.js`, and run all previously required Supabase migrations through V2.18.

# KeySuite V2.20

KeySuite V2.20 introduces Owner-only company pricing settings and separates internal Assembly pricing from customer Quotation pricing.

## Main changes

- Adds **Key > Company** for the signed-in company and protected commercial pricing settings.
- Moves Commission, Set Discount, Final Discount and Fuel Charge control out of Category Pricing Rule.
- Splits company factors into **Assembly** and **Quotation** tabs.
- Keeps Set Discount only in Quotation; Assembly pricing excludes it.
- Keeps Category Pricing Rule focused on Margin, Normal, Rare and Transport.
- Uses Assembly factors for products and automatic components inside Assembly/System BOM.
- Recalculates System/Pumpset components with Quotation factors when transferred to Quotation.
- Prevents company-factor changes from recalculating sealed quotations.

## Upgrade from V2.19

1. Back up the deployment and Supabase database.
2. Run `V220_SUPABASE_MIGRATION.sql` in Supabase.
3. Apply `KeySuite_V2.20_Changed_Files_Patch.zip` over V2.19.
4. Preserve the existing working `config.js`.
5. Deploy and hard-refresh with `Ctrl + Shift + R`.

## Clean installation

Use `KeySuite_V2.20_GitHub.zip`, provide the deployment `config.js`, and run all required Supabase migrations in sequence through V2.20.

# KeySuite V2.21

KeySuite V2.21 corrects the company and category pricing-factor workflow.

## Main changes

- Key > Company now has one Owner-only set of Commission, Set Discount and Final Discount values.
- The Owner can choose a company, see the Not Set count and filter companies whose three values are all zero.
- Key > Category > Edit Category keeps Margin, Normal, Rare and Transport editable.
- Company Commission, Set Discount and Final Discount are read-only in Category, with category-level Use checkboxes.
- Fuel Charge remains automatic and has a category-level Use checkbox.
- Pricing > Category Pricing Rule has Assembly and Quote factor views. Unticked factors are hidden and excluded.
- Assembly pricing always excludes Set Discount.

## Upgrade from V2.20

1. Back up the current deployment and Supabase database.
2. Run `V221_SUPABASE_MIGRATION.sql` in Supabase SQL Editor.
3. Apply `KeySuite_V2.21_Changed_Files_Patch.zip` over V2.20.
4. Preserve the existing deployment `config.js`.
5. Deploy and hard-refresh the browser.

## Clean installation

Use `KeySuite_V2.21_GitHub.zip`, provide the deployment `config.js`, and run all required migrations through V2.21.

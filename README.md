# KeySuite V2.22

KeySuite V2.22 changes the Owner pricing setup from company-based records to customer-based records.

## Main changes

- **Key > Company** is renamed to **Key > Customer**.
- The Owner can select every active customer, including Keylargo and Apex.
- Commission, Set Discount and Final Discount are saved separately for each customer.
- The Not Set count and filter now use the customer list.
- Category factor Use controls remain unchanged.
- Assembly pricing excludes Set Discount; Quote pricing uses it when enabled.
- The V2.21 `company_id is ambiguous` save error is removed by the new customer RPC and named conflict constraint.

## Upgrade from V2.21

1. Back up the deployment and Supabase database.
2. Run `V222_SUPABASE_MIGRATION.sql` in Supabase SQL Editor.
3. Apply `KeySuite_V2.22_Changed_Files_Patch.zip` over V2.21.
4. Preserve the existing working `config.js`.
5. Deploy and hard-refresh the browser.

## Data migration

- Active customers receive a customer-pricing row.
- A customer whose name matches the existing company master inherits the old company percentages when its customer percentages are still zero.
- Other customers remain Not Set until the Owner enters their rates.
- Existing company pricing tables and sealed quotations are not deleted or recalculated.

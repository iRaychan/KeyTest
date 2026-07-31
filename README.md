# KeySuite V2.05

KeySuite V2.05 completes the End Suction Price List workflow, repairs ES saving, adds ES currency and category rules, fixes CHC Product actions, and aligns the Quotation No. field at the page top-right.

## Required Supabase update

Run `setup/V205_SUPABASE_MIGRATION.sql` before deploying the V2.05 application files. Preserve the existing working `config.js`.

See `V205_CHANGES.txt` and `INSTALL_V205.txt` for details.

---

# KeySuite V2.02

KeySuite V2.02

- Assembly customer is read-only and follows the active Quotation customer selection.
- Selector header now has Add to Quotation and Add to Assembly side by side.
- Selector/Product quotation description is transferred into System Description when routed to Assembly.
- Pumpset Pump section shows pump model with editable Qty, Unit Price and calculated Total Price.
- Product CHC curve is fixed to 50 Hz.
- CHC Add to Assembly routes to Assembly > System > Pumpset.


## Database
No Supabase schema change is required for V2.02. Continue using migrations through V2.01.

# KeySuite V1.24

## Required Supabase update

Run `setup/V124_SUPABASE_MIGRATION.sql` before testing the custom Role Permissions editor. The migration stores the permission matrix per company and keeps Owner safeguards for Key Dashboard, Role management and own profile access.

## V1.24 changes

- Removed the visible Printed Customer and Printed Contact Name inputs from Quotation. The internal customer/contact values remain available for the frozen PDF output.
- Quotation No. input is approximately twice the previous width.
- Price List Currency Selection, USD → MYR and RMB → MYR controls are aligned.
- Role Permission columns now run from Viewer to Owner.
- Owner can hold the Edit button for five seconds; a live countdown unlocks the complete permission matrix.
- Save Permissions stores the authority settings in Supabase.
- Owner Key Dashboard, Role management and own profile permissions remain fixed to avoid accidental lockout.
- The V1.08 quotation PDF layout remains fully frozen and unchanged.

## Upload

1. Run the V1.24 Supabase migration.
2. Upload all public files and folders to the GitHub repository root.
3. Keep the existing working `config.js`.
4. Refresh with `Ctrl + Shift + R`.

---

# KeySuite V1.22

## V1.20.5 quotation item deletion hotfix

- Allows deletion of the final remaining quotation item.
- An empty quotation can remain open; use **+ Add Item** to add a new item.
- Saving still requires at least one valid item.
- No Supabase SQL update is required.
- Keep the existing working `config.js`.
- Frozen V1.08 PDF output layout remains unchanged.

---

# KeySuite V1.20.4


## V1.20.4 required hotfix

Run `setup/V1204_SUPABASE_HOTFIX.sql` before uploading this GitHub package. It adds the missing audit column required by the CHC price/rarity save function and retires unsupported E-Wave models.

- CHC price and rarity saving no longer fails with `column updated_at does not exist`.
- The Category `Hold 3s to Edit` countdown is compact enough to stay beside the editor title.
- E-Wave contains only `PEB 24LX`.
- No quotation PDF/print layout code was changed.

## V1.20.3 category layout update

- Compact inline rows for CHC and GWS pricing rules.
- Margin, Normal, Rare and Transport inputs sit beside their labels.
- Commission, Set Discount, Final and Fuel Charge show input and Use checkbox in one row.
- The single Hold 3s to Edit control unlocks the complete Category editor.
- No new Supabase SQL is required when V1.20 migration is already installed.


Base: KeySuite V1.19. The approved V1.08 quotation PDF/print layout remains fully frozen and unchanged.

## Install in this order

1. In Supabase, open SQL Editor and run the complete file:
   `setup/V120_SUPABASE_MIGRATION.sql`
2. Deploy the included Supabase Edge Function using the function name:
   `keysuite-invite-user`
   Source folder: `supabase/functions/keysuite-invite-user/`
   This step is required only for sending new-user invitation emails.
3. Extract this GitHub package.
4. Upload all files and folders to the root of the existing KeySuite repository, replacing matching files.
5. Keep the existing working `config.js`. This package intentionally does not include it.
6. Wait for GitHub Pages to deploy, then refresh using `Ctrl + Shift + R`.

## V1.20 highlights

- Owner-managed invitation emails let new users create their own passwords.
- Category Names are visible, selectable, highlighted, and load the correct saved rules.
- Protected Category and multiplier values use a visible 3-second hold flow.
- Multiplier unlock reveals explicit Save and Cancel controls.
- CHC and GWS have independent USD and RMB multipliers.
- CHC Price List uses grouped Price and Rarity columns for CHC, CHCS and CHCN.
- Rarity defaults to Common and is saved per currency and variant.
- Many, Common and Rare now apply different formulas using the rarity of the winning highest converted price.
- GWS Tank pricing uses only actual sellable series/model/pressure SKUs.
- PEB 24LX and PWB 24LX are separate 10 Bar items.
- Unavailable 16 Bar or 25 Bar combinations are not shown.
- GWS quotation item titles show only litres and pressure; technical model details appear in Description.

## User invitations

The public browser must never receive a Supabase service-role key. The included Edge Function performs the privileged invitation safely on the server and verifies that the caller is an active KeySuite Owner.

The invited user opens the email link and sets a password in KeySuite. Role/access and Authentication remain linked but separate records.

## Security and data

- Only the Owner sees the gold Key button and protected Key modules.
- Customer ID and Category ID remain database-only and are not shown on dashboards.
- Source prices, rarity and multipliers are stored in Supabase, not embedded in public GitHub files.
- Never upload a secret or service-role key into `config.js` or GitHub.


## V1.21 quotation status

Saved quotations remain editable. Seal locks all quotation fields and enables PDF output. Hold the Sealed button for five seconds to return it to Saved. Revise creates a separate v01/v02 revision with the original customer and date locked.

Customer pricing is selected inside the quotation. The Customers page no longer carries a Quote/Quoted selection.


## V1.22 pricing interface update

- Price List USD→MYR and RMB→MYR multipliers are unlocked by holding directly on the input for 3 seconds.
- The countdown appears below the held input; the separate hold button was removed.
- Save and Cancel appear only after the multiplier is unlocked.
- Company & Pricing now has CHC and GWS tabs and displays only the selected product family's rule and formulas.
- Removed the Search Model toolbar and the full calculated-price table from Company & Pricing.
- No Supabase SQL migration is required.
- V1.08 PDF output remains frozen and unchanged.

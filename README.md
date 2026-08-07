# KeySuite V3.6

Combined KeySuite + KeyES + KeyAI build.

## V3.6
- Integrates **KeyES V1.7** into KeySuite under **Selection → ES**.
- Keeps KeyES V1.7 engineering selection logic unchanged: efficiency-first recommendation, fixed catalog alternative order, system/orifice operating intersection, direct impeller/frequency control and compact motor selectors.
- Routes a KeyES selection into KeySuite **Assembly → Pumpset → Pump** or directly to **Quotation**.
- Applies the existing KeySuite ES source price, Customer/Category Pricing Rule and quote-blocking checks when the selected ES pump is routed.
- Saves KeyES selection/export state with the quotation item so the item **PDF** button reopens the ES selector data sheet, not the CHC selector.
- Protects the integrated KeyES URL with the same signed-in KeySuite access check used by the CHC selector.
- Adds automatic iframe-height synchronization to reduce clipping/overlap inside KeySuite.
- No database migration and no Edge Function redeployment are required for V3.6.

## Required V3.6 setup
1. Upload/replace the complete V3.6 GitHub package.
2. Keep your existing `config.js`.
3. No new Supabase SQL migration is required.
4. No KeyAI Edge Function redeployment is required for this release.
5. Ctrl+F5 / restart the installed PWA after deployment.

See `INSTALL_V360.txt` for the test sequence.

## V3.5
- Fixes the KeyAI Telegram Inbox renderer so AI results display as friendly structured requirement cards instead of raw/truncated JSON.
- Older V3.3/V3.4 enquiries are also normalized for display where enough information exists in the original Telegram message.
- KeyAI OpenAI extraction now requests schema-constrained Structured Output for Telegram processing.
- Telegram clarification is enforced server-side for real blocking ambiguities, including multi-duty-pump flow basis (total system flow vs flow per duty pump).
- Customer follow-up replies continue in the same enquiry and resolved clarification items are removed.
- KeyAI normalizes System Type separately from Duty Configuration (for example Transfer System vs 2 Duty + 1 Standby).
- Dashboard Customer (company) and Customer Name (contact/employee) are aligned on the same row with equal-height inputs and remain linked to Quotation.
- Existing OpenAI ON/OFF, usage, cost estimate, monthly request limit, Telegram OFF manual-review path and V3.4 conversation database are retained.

## Required V3.5 setup
1. Upload/replace the V3.5 GitHub files.
2. No new Supabase SQL migration is required if V310, V330 and V340 were already run.
3. Redeploy BOTH Edge Functions from this package: `keyai-openai` and `telegram-webhook`.
4. Keep existing secrets: `OPENAI_API_KEY`, `KEYAI_INTERNAL_SECRET`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_WEBHOOK_SECRET`.
5. Keep platform JWT verification OFF for both functions. Each function performs its own handler-level authentication.
6. No Telegram webhook re-registration is required if its URL and secret have not changed.
7. Ctrl+F5 / restart the installed PWA after deployment.

See `INSTALL_V350.txt` for the test sequence.

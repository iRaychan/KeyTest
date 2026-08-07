# KeySuite V3.5

Combined KeySuite + KeyES + KeyAI build.

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

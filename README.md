# KeySuite V3.4

Combined KeySuite + KeyES + KeyAI build.

## V3.4
- KeyAI Telegram Inbox now shows a friendly structured draft instead of raw JSON.
- OpenAI ON can automatically ask the customer concise clarification questions when a real ambiguity blocks duty interpretation.
- Customer Telegram replies are attached to the same enquiry and merged into the prepared requirements.
- OpenAI connection/test status persists after refresh and can also show the last successful API-use time.
- Status & Usage adds Estimated OpenAI Cost this month and records cached input tokens.
- Existing 0 KeySuite monthly request limit is changed to a recommended 500-request starting guard; Owner can change it later.
- OpenAI OFF behaviour is unchanged: Telegram enquiries are saved for manual review with no OpenAI call.

## Required V3.4 setup
1. Confirm V310 and V330 migrations were already run.
2. Run `V340_SUPABASE_MIGRATION.sql`.
3. Upload/replace the V3.4 GitHub files.
4. Redeploy BOTH Edge Functions from this package: `keyai-openai` and `telegram-webhook`.
5. Keep existing secrets: `OPENAI_API_KEY`, `KEYAI_INTERNAL_SECRET`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_WEBHOOK_SECRET`.
6. Keep platform JWT verification OFF for both functions. Each function performs its own handler-level authentication.
7. No Telegram webhook re-registration is required if its URL and secret have not changed.

See `INSTALL_V340.txt` for the test sequence.

# KeySuite V3.3

Combined KeySuite + KeyES + KeyAI build.

## V3.3
- Dashboard: Customer is the company; Customer Name is the employee/contact for that company, synchronized with Quotation.
- Left panel: System/Pumpset use a #FFC000 outline only, with the same normal white text style as other navigation items.
- KeyAI: Telegram webhook integrated with Owner-controlled OpenAI ON/OFF.
- OpenAI OFF: enquiries are saved for manual review with zero OpenAI calls.
- OpenAI ON: enquiries are processed by the server-side keyai-openai function and saved as AI Draft Ready.
- Owner KeyAI page includes a Telegram Inbox for review/testing.

## Required V3.3 setup
1. If V310 has not been run, run `V310_SUPABASE_MIGRATION.sql` first.
2. Run `V330_SUPABASE_MIGRATION.sql`.
3. Configure Supabase Edge Function secrets: `OPENAI_API_KEY`, `KEYAI_INTERNAL_SECRET`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_WEBHOOK_SECRET`.
4. Deploy `keyai-openai` and `telegram-webhook`.
5. Keep JWT verification OFF for `telegram-webhook` and ON for `keyai-openai` (see `supabase/config.toml`).
6. Register the Telegram webhook to `/functions/v1/telegram-webhook` with the same Telegram webhook secret.

See `INSTALL_V330.txt` for the test sequence.

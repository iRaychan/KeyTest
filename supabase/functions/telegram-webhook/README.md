# telegram-webhook

KeySuite V3.3 Telegram receiver for KeyAI.

Required secrets:
- `TELEGRAM_BOT_TOKEN` (also supports the older `KeySuiteBot_Token` name)
- `TELEGRAM_WEBHOOK_SECRET` (also supports `KeySuiteBot_TELEGRAM_WEBHOOK_SECRET`)
- `KEYAI_INTERNAL_SECRET`

The webhook checks the Owner's `keyai_openai_enabled` setting before any AI call.
- OFF: saves the enquiry as `AI Disabled – Manual Review` and never calls OpenAI.
- ON: calls the server-side `keyai-openai` function and saves an AI draft summary.

This function must accept Telegram's unauthenticated webhook request. Keep Supabase JWT verification OFF for this function and rely on Telegram's secret header validation in the code.

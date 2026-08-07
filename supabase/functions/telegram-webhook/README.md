# telegram-webhook — KeySuite V3.4

Telegram receiver for KeyAI.

V3.4 keeps OpenAI OFF as a zero-AI-call manual-review path. When OpenAI is ON it can ask concise clarification questions, attach the customer's reply to the same enquiry and update the structured draft.

Secrets:
- `TELEGRAM_BOT_TOKEN` (older `KeySuiteBot_Token` also accepted)
- `TELEGRAM_WEBHOOK_SECRET` (older `KeySuiteBot_TELEGRAM_WEBHOOK_SECRET` also accepted)
- `KEYAI_INTERNAL_SECRET`

The handler validates Telegram's `X-Telegram-Bot-Api-Secret-Token` header. Platform JWT verification must remain OFF.

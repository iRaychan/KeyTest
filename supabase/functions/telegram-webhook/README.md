# telegram-webhook — KeySuite V3.5

Telegram receiver for KeyAI.

V3.5 retains the OpenAI OFF zero-AI-call manual-review path. When OpenAI is ON it normalizes the structured result and independently enforces critical clarification when required. For multi-duty-pump enquiries with an ambiguous stated flow, Telegram asks whether the flow is total system flow or flow per duty pump. Customer replies are linked to the same enquiry and resolved questions are cleared.

Secrets:
- `TELEGRAM_BOT_TOKEN` (older `KeySuiteBot_Token` also accepted)
- `TELEGRAM_WEBHOOK_SECRET` (older `KeySuiteBot_TELEGRAM_WEBHOOK_SECRET` also accepted)
- `KEYAI_INTERNAL_SECRET`

The handler validates Telegram's `X-Telegram-Bot-Api-Secret-Token` header. Platform JWT verification must remain OFF.

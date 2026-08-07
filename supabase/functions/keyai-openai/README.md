# keyai-openai

Supabase Edge Function for KeySuite V3.3 KeyAI OpenAI calls.

Required secret:
- `OPENAI_API_KEY`

Required for Telegram-to-OpenAI internal calls:
- `KEYAI_INTERNAL_SECRET`

Keep Supabase platform JWT verification OFF for this function. The function performs its own authentication inside the handler: browser calls must carry a valid signed-in KeySuite user bearer token, while Telegram-to-OpenAI calls must carry the matching `KEYAI_INTERNAL_SECRET`. This avoids blocking external/internal calls at the gateway while still enforcing KeySuite authorization in code.

The function checks the Owner ON/OFF setting in `ks_app_settings` before every OpenAI request and never exposes the OpenAI key to the browser or GitHub.

# keyai-openai

Supabase Edge Function for KeySuite V3.1 KeyAI OpenAI calls.

Required secret: `OPENAI_API_KEY`
Optional internal KeyAI caller secret: `KEYAI_INTERNAL_SECRET`

Deploy from Supabase CLI with: `supabase functions deploy keyai-openai --no-verify-jwt`

The function checks the Owner ON/OFF setting in `ks_app_settings` before every OpenAI request and never exposes the OpenAI key to the browser.

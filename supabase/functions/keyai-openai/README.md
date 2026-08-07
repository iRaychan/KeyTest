# keyai-openai — KeySuite V3.4

Server-side OpenAI gateway for KeyAI.

Secrets:
- `OPENAI_API_KEY`
- `KEYAI_INTERNAL_SECRET`

V3.4 records monthly token usage, cached input tokens and an estimated cost for known pricing (including `gpt-5-mini`). Test Connection results are persisted server-side.

`verify_jwt=false` is intentional in `supabase/config.toml`; this handler validates either a signed-in KeySuite bearer token or `KEYAI_INTERNAL_SECRET` itself.

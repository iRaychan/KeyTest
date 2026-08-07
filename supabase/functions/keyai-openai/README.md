# keyai-openai — KeySuite V3.5

Server-side OpenAI gateway for KeyAI.

Secrets:
- `OPENAI_API_KEY`
- `KEYAI_INTERNAL_SECRET`

V3.5 keeps the V3.4 usage/cost and persistent Test Connection features, and adds schema-constrained Structured Output for Telegram quotation-requirement extraction. This reduces malformed/truncated JSON reaching the Telegram workflow.

`verify_jwt=false` is intentional in `supabase/config.toml`; this handler validates either a signed-in KeySuite bearer token or `KEYAI_INTERNAL_SECRET` itself.

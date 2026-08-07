# KeySuite V3.2

Complete GitHub-ready KeySuite source. KeySuite, KeyES and the current KeyAI OpenAI module are carried under the same master KeySuite version line.

## V3.2 amendments

- **Left navigation System / Pumpset** — changes the previous solid `#FFFF00` buttons to clean yellow outline buttons while retaining the navy left panel.
- **Dashboard Customer Name** — the Start customer picker is labelled **Customer Name** and the linked customer is shown as **Quotation Customer**. The existing Dashboard-to-Quotation synchronization is retained.
- **KeyAI retained** — carries forward the V3.1 Owner-only OpenAI ON/OFF control, model selection, monthly request limit, connection test and usage counters, including the Supabase `keyai-openai` Edge Function.
- Retains all V3.1 and V3.00 KeySuite/KeyES functionality.

## Deployment

1. Upload all files/folders from this package to the root of the existing GitHub repository, replacing old files.
2. Preserve the existing production `config.js`; it is intentionally not included.
3. There is **no new V3.2 Supabase migration**.
4. If the KeyAI OpenAI setup from V3.1 has not yet been installed, run `V310_SUPABASE_MIGRATION.sql`, add the `OPENAI_API_KEY` Edge Function secret, and deploy `supabase/functions/keyai-openai`.
5. After GitHub Pages deploys, close/reopen KeySuite and press `Ctrl+F5` once.

See `V320_CHANGES.txt`, `INSTALL_V320.txt`, and `V320_QA_REPORT.txt`.

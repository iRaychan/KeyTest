# KeySuite V3.1

Complete GitHub-ready KeySuite source based on V3.00. KeySuite, KeyES and KeyAI amendments are now maintained under the same master KeySuite version line.

## V3.1 amendments

- **KeyAI OpenAI owner control** — Owner-only ON/OFF, model selection, monthly request limit, connection test and monthly token/request usage. OpenAI calls run through the Supabase `keyai-openai` Edge Function; the API key is never placed in browser code.
- **Dashboard Start redesign** — removes the four summary metrics and the four Start action buttons, promotes Start visually, and adds a scalable searchable/recent-customer picker linked directly to the Quotation customer.
- **Left navigation** — expanded Selection and Product groups use `#3072C2`; Assembly is replaced by direct **System** and **Pumpset** buttons using `#FFFF00`.
- Retains all **V3.00 coupling layout** and **Quote History year/month expand-collapse** improvements.

## Deployment

1. Run `V310_SUPABASE_MIGRATION.sql` in the existing KeySuite Supabase project.
2. Add the Supabase Edge Function secret `OPENAI_API_KEY`.
3. Deploy `supabase/functions/keyai-openai` (see `V310_OPENAI_SETUP.txt`).
4. Upload all files/folders from this package to the root of the existing GitHub repository, replacing old files.
5. Preserve the existing production `config.js`; it is intentionally not included.
6. After GitHub Pages deploys, close/reopen KeySuite and press `Ctrl+F5` once.

See `V310_CHANGES.txt`, `INSTALL_V310.txt`, `V310_OPENAI_SETUP.txt`, and `V310_QA_REPORT.txt`.

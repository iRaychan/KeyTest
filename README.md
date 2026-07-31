# KeySuite V2.10

KeySuite V2.10 refines KeyPLC descriptions inside Assembly and replaces the manual Assembly Save button with automatic saving.

## Highlights

- Assembly-only KeyPLC descriptions begin with `c/w KeyPLC Control Panel`.
- Continuation lines align under the panel name.
- No blank row appears above a KeyPLC panel description.
- Assembly edits save automatically to Supabase, with local browser storage retained as a fallback.
- Product-to-Quotation KeyPLC wording remains unchanged.
- No Supabase migration is required for this release.

Preserve the deployment's working `config.js`, deploy the V2.10 changed-files patch, and hard-refresh the application.

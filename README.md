# KeySuite V2.38

Full GitHub source built from V2.37. `config.js` is intentionally not included; preserve the existing deployment configuration.

## Upgrade

For V2.37 → V2.38:

1. Back up the current V2.37 deployment.
2. Replace the files from the V2.38 update patch.
3. Keep the existing `config.js`.
4. No new Supabase migration is required. Confirm `V236_SUPABASE_MIGRATION.sql` was previously installed.
5. Deploy and press `Ctrl+F5`.
6. If the previous service worker remains, clear KeySuite site data once and reopen the app.

See `V238_CHANGES.txt`, `INSTALL_V238.txt`, `V238_NO_DATABASE_MIGRATION.txt`, and `V238_QA_REPORT.txt`.

KeyAI integration remains paused and is not included in this Version 2 build.

KeySuite V2.25 Update-Only Patch

Use only when the installed application is KeySuite V2.24.

Update order:
1. Back up V2.24 and the Supabase database.
2. Run V225_SUPABASE_MIGRATION.sql in Supabase SQL Editor.
3. Copy all patch files over the V2.24 project, preserving the supplied folders.
4. Keep the existing working config.js; this patch does not include config.js.
5. Commit/push the changed files and wait for deployment.
6. Press Ctrl+F5 after deployment.
7. Owner: open Key > Role and assign a unique quotation prefix to each user.

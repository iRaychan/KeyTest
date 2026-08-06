# KeySuite user invitation function

Deploy this Edge Function to the same Supabase project used by KeySuite.

Function name: `keysuite-invite-user`

It verifies that the caller is an active KeySuite Owner, then uses Supabase Auth Admin to send an invitation email. The invitee sets their own password from the email link.

The hosted Supabase function environment supplies `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`. Never place the service-role key in GitHub `config.js`.

Before testing invitations, ensure the deployed KeySuite GitHub Pages URL is allowed as an Authentication redirect URL in the Supabase project. The browser sends the current KeySuite page as the invitation redirect destination.

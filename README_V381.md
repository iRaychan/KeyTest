# KeySuite V3.8.1 - KeyCore Dark Stage Hotfix

This incremental release fixes the white rounded background that could appear behind the KeyCore data globes in V3.8.

The KeyCore scene is now explicitly isolated from the normal KeySuite light/card theme. The viewport remains green-black, while the finite world surface is transparent so the Matrix data rain, space field, glows, particles and orbit effects form one continuous background.

## Upgrade
Upload all files in this package to the root of an existing KeySuite V3.8 repository and replace the matching files. Keep `config.js` unchanged.

No Supabase migration or KeyAI Edge Function redeployment is required.

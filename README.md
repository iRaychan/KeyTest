# KeySuite V2.07

KeySuite V2.07 improves CHC Product Curve PDF duty-point output and technical data, normalizes motor HP formatting, adds duty information to engineering descriptions, widens the Assembly description editor, and simplifies GWS tank descriptions in Assembly.

## Database

No new Supabase migration is required for V2.07. A database upgraded through V2.05 is sufficient. Preserve the existing working `config.js` during deployment.

## Main changes

- CHC Product Curve PDF includes its default duty point.
- Technical Data page 2 uses the same duty flow and intersected head.
- Motor HP formatting removes unnecessary trailing zeros.
- Pump descriptions include Capacity when valid flow/head data exist.
- Product-origin CHC BOM titles remain model-only.
- Assembly description pop-up is wider.
- GWS tanks use concise Assembly-only descriptions with quantity tracking.

See `V207_CHANGES.txt` and `INSTALL_V207.txt` for full details.

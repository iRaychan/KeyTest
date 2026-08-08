# KeySuite V3.7 — Universe View

V3.7 adds an optional live **Universe View** on top of KeySuite V3.6. The existing Dashboard remains the default working view.

## Highlights

- Data planets for Quotations, Customers, Price List, Pump Curves, KeyAI, Assembly, Products and Alerts.
- Planet **base size follows data volume**.
- Quiet planets use a restrained heartbeat pulse.
- Detected changes trigger a stronger **big → small → big → normal** heartbeat and a glowing relationship line back to the KeySuite core.
- Drag/pan, wheel zoom, plus/minus zoom, reset view, recent activity, Live Sync and Pause Motion.
- Clicking a planet opens the corresponding existing KeySuite module; business and engineering logic are not duplicated in Universe View.
- Respects `prefers-reduced-motion`.

## Deployment

Apply these files on top of **KeySuite V3.6** and keep your existing `config.js`. No new Supabase migration or KeyAI Edge Function redeployment is required.

See `INSTALL_V370.txt` for the deployment/test sequence.

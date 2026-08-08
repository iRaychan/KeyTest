# KeySuite V3.8 — KeyCore

V3.8 replaces the user-facing **Universe View** concept with **KeyCore**, a Matrix/AI-style live visualization of KeySuite data.

## Highlights

- KeyCore center globe / system core
- Matrix data-rain background
- data-volume-driven globe growth
- gravity-like orbiting particles around each globe
- particle absorption when new data arrives
- stronger heartbeat and connection flash on activity
- pan, zoom, reset and pause controls
- existing KeySuite dashboard and business logic preserved

## Upgrade

Replace `universe.js` and `sw.js` in the repository root. Keep `config.js` unchanged. No SQL migration is required.

The filename `universe.js` is intentionally preserved for a drop-in V3.7 upgrade even though the feature is now named **KeyCore** everywhere in the UI.

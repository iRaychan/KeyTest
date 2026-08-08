# KeySuite V3.8.2 — R2 Corrective Update

Base required: **KeySuite V3.8.1**
Build date: **2026-08-08**

## CHC — KeyCHC V3.4.7
- Required Duty opens with Flow and Head blank.
- `m³/min` is removed from the visible Flow-unit dropdown.
- Top actions are `PDF / Assembly / Quote`.
- Duplicate PDF beside Summary is removed.
- Alternative Model ordering is small-to-big, with same-base variants ordered `-2 < -1 < standard`.
- PDF curve Page 1 motor label includes actual pole count, e.g. `0.75kW 2P`.

## ES — KeyES V1.9
- Top actions are `PDF / Assembly / Quote`.
- Top option row is now: Material / Seal Type / Seal Material / Elastomer / Bare Shaft.
- Seal Type default is `Mechanical Seal`; alternate is `Gland Packing`.
- Mechanical Seal materials: Carbon Ceramic (default), Silicon Carbide, Tungsten.
- Gland Packing automatically changes Seal Material to `Graphite` and Graphite is the only available material while Gland Packing is selected.
- Non-default Material / Seal Type / Seal Material / Elastomer / Motor Voltage use the existing alert fill.
- Bare Shaft Pump uses the same alert fill when ticked.
- Motor Voltage remains available separately below Pump Speed Range.
- Pump Speed Range defaults to `All Speed`.
- Alternative Selection no longer forces nine models. A candidate is excluded when the required duty head is below that candidate's head at its maximum-flow curve endpoint. Only the nearest relevant catalog neighbours are shown; one suitable alternative is acceptable.
- Summary expand/collapse follows CHC and shows Efficiency / Power-BHP / NPSHr.
- Normal Assembly transfers Pump + Motor and retains Flexible Coupling / Baseplate pumpset intent. Bare Shaft transfers pump only.

## ES PDF
- Curve Page 1 retains the aligned Q-H / Efficiency / Power / NPSHr layout and motor label with actual pole count.
- Technical Page 2 retains Operating Data / Pump / Motor / Pumpset sections.
- Page 2 `Bearing Type` is `Ball`.
- Shaft seal output uses:
  - default Mechanical Seal + Carbon Ceramic -> `Mechanical Seal`
  - non-default Mechanical Seal material -> `Mech Seal (SiC SiC)` / actual abbreviation
  - Gland Packing -> `Gland Packing`
- Pumpset dimension format remains visible with blank placeholders until the dimension mapping is supplied.

## Dashboard — Quick Pump Selection
- Adds Flow + Head duty inputs to Dashboard.
- Checks CHC and ES selector families through their live selector logic.
- Only families with a suitable recommended model are displayed.
- Family button expands its recommended model.
- Model button expands key information including duty, efficiency, power, NPSHr, motor, speed/frequency and connection where available.

## KeyCore
- KeyCore hides the normal left navigation and expands to a full-width immersive view while KeyCore is active.
- `Product` opens a Product Hub instead of opening CHC directly.
- Product Hub exposes CHC, ES, Motor, Coupling, Control Panel, GWS Tank and Manifold using existing KeySuite routes.
- `Pump Curve` opens a Pump Curve Hub first, with CHC and ES families.
- Because the exact V3.8.1 main shell was not available, these parent-shell changes are loaded through the forward-compatible `v382-dashboard-keycore.js` extension injected by `sw.js`; older V3.6 app shell files are not copied over V3.8.1.

## Database
- No Supabase migration.
- No config.js change.
- No KeyAI Edge Function change.

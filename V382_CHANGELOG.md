# KeySuite V3.8.2

## Corrective rebuild — 2026-08-08
- Revalidated CHC and ES top action order as `PDF / Assembly / Quote`.
- Revalidated blank CHC Flow/Head startup and removal of `m³/min` from integrated flow dropdowns.
- Corrected ES PDF Page 2 Bearing Type from `Ball Bearing` to `Ball`.
- Revalidated Page 1 motor labels with actual pole count.
- Final amendment QA: 30/30 PASS.

Base required: **KeySuite V3.8.1**

## CHC — KeyCHC V3.4.7
- Updated the integrated CHC selector runtime to KeyCHC V3.4.7.
- Required Duty starts blank: Flow and Head are not pre-filled.
- Removed `m³/min` from all integrated selector flow-unit dropdowns. CHC and ES now expose only the remaining approved flow units.
- Removed the duplicate PDF control beside Summary; the main/top PDF control remains.
- Alternative Model catalog order is smallest to biggest with variant priority `-2 < -1 < standard` for the same base model.
- PDF Curve Page 1 motor label now includes pole count, e.g. `0.75kW 2P` or `15kW 4P`.
- Existing KeySuite Assembly / Quote / saved-PDF bridge behavior is retained.

## ES — KeyES V1.9
- Updated the integrated ES selector runtime to KeyES V1.9.
- Top action order is now `PDF / Assembly / Quote`, matching CHC.
- Moved Material, Mechanical Seal, Elastomer and Motor Voltage into the top option area.
- Any of those four controls uses the existing alert fill when its value differs from the standard/default selection.
- Added Bare Shaft Pump checkbox in the same top option area.
- Added CHC-style Summary expand/collapse. Core collapsed values are Efficiency, Power/BHP and NPSHr.
- Assembly payload now carries Pump, Motor, Flexible Coupling intent and Baseplate/pumpset context. When KeySuite's live Assembly/Motor APIs are available, Pump + selected Motor are inserted directly and the Pumpset Assembly auto-selects its default Flexible Coupling; the coupling description carries the baseplate. Bare Shaft Pump transfers only the pump.
- PDF Curve Page 1 motor label now includes pole count.

## ES PDF Page 2 — Technical Data
- Page 2 follows the KeyCHC technical-data table style.
- Sections: Operating Data, Pump, Motor and Pumpset.
- Pump data comes from the active KeyES pump/result dataset.
- `Shaft Seal` is renamed to `Mechanical Seal`.
- Standard Mechanical Seal displays as `Carbon Ceramic` without `(Ca Ce)`.
- Bearing Type is `Ball`.
- Motor data prefers the live KeySuite motor backend; KeyCHC motor technical data remains a fallback for fields not exposed by the backend.
- Pumpset dimension format is present now. Dimension values are intentionally blank (`-`) until the later dimension mapping is supplied.

## Dimension scope
- No new dimension mapping is invented in V3.8.2.
- Existing KeyES V1.9 dimensional page/data is otherwise preserved.

## KeyCore app-shell amendments
The requested KeyCore `Product Hub` and `Pump Curve Hub` routing belongs to the main KeySuite V3.8.1 app shell. The exact V3.8.1 full repository was not available in this build session, so those two parent-app files were **not replaced with older V3.6 files**. See `V382_APP_SHELL_PENDING.txt`.

## Database
No database migration required.

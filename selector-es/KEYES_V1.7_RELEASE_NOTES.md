# KeySelector ES V1.7 Release Notes

This is the standalone KeyES V1.7 release. It is not merged into KeySuite.

## V1.7 changes
1. Pump recommendation priority: highest calculated efficiency at D1; then selected impeller nearest max/full impeller; then BEP preference within ±10% and closest to BEP.
2. Alternative Selection list follows the fixed ES catalog/model sequence rather than score order.
3. System Curve display stops at the actual operating intersection for the D1 running-pump count.
4. When Orifice is active, the System Curve endpoint uses the After-Orifice × System Curve intersection.
5. Motor / Efficiency text labels are removed from the top-right compact selectors.
6. A manually selected motor below calculated pump BHP uses the alert fill.

## Retained behavior
- Duty Flow and Head start blank.
- Direct whole-mm Impeller Size with ±1 mm adjustment and auto round-up to the next 5 mm.
- Frequency defaults to 50.0 Hz, allows 0.1 Hz adjustment, and warns below 30 Hz.
- Static Head units: m, ft, bar, kPa, psi.
- Orifice Size and K-Factor 0.62 controls.
- After-Orifice stops at 0 m.
- 1P–6P curves on Q-H, Efficiency, Power and NPSHr; Power is summed across running pumps.
- Updated Max. Casing Pressure data from the V1.1 ES workbook.

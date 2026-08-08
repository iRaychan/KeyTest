# KeySuite V3.8.2

Base: KeySuite V3.8.1

## 1. CHC selector
- Updated selector runtime to KeyCHC V3.4.7.
- Added/retained KeySuite bridge actions for PDF, Assembly and Quote.
- Supports KeySuite product-frame model loading and saved-datasheet re-export messages.
- Standalone selector service-worker registration is disabled in the KeySuite-integrated copy to avoid stale selector caches or cross-app cache conflicts.

## 2. ES selector
- Updated selector runtime to KeyES V1.9.
- Retains KeySuite Assembly / Quote / PDF integration from V1.9.

## 3. KeyES PDF Page 2
- Rebuilt Page 2 to follow the KeyCHC V3.4.7 TECHNICAL DATA visual/table structure.
- Sections in V3.8.2: Operating Data, Pump, Motor.
- Pump values are read from the active KeyES V1.9 pump/result dataset and the selected ES construction options.
- Motor model/technical values first use the live KeySuite motor backend when matching data is exposed by the parent app.
- A KeyCHC V3.4.7 motor technical-data snapshot is supplied as fallback for matching 2-pole motor technical fields.
- Missing backend technical values display '-' / 'Data Not Available' rather than invented values.

## 4. Dimensions
- No dimensional redesign in V3.8.2.
- KeyES PDF Page 3 dimension expression is preserved from KeyES V1.9.
- Dimension mapping/layout remains pending a later amendment.

## Database
No database migration required.

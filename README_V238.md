# KeySuite V2.38

V2.38 continues directly from V2.37 and corrects Pumpset Coupling ownership, capacity presentation, and Quotation History date filtering.

## Main changes

- Automatic and manually added Pumpset Couplings are separate BOM records with separate IDs.
- Deleting the Auto Coupling suppresses only the Auto Coupling and shows **Restore Auto Coupling**.
- Product > Coupling > Assembly can add a Manual Coupling while the Auto Coupling is suppressed.
- Deleting either an Auto or Manual Coupling no longer removes the other coupling records.
- Capacity displays the selected units first and adds metric equivalents only when needed.
- Quotation History filters exact year/month combinations, such as October and December 2026.

No new Supabase migration is required. The V2.36 quotation-history migration must already be installed.

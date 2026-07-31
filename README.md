# KeySuite V2.11

KeySuite V2.11 adds a customer-led Dashboard start workflow and improves System / Pumpset assembly quoting.

## Highlights

- Dashboard **Start** customer stays synchronized with the Quotation customer.
- Changing the Dashboard customer saves the current valid draft quotation, then opens a new quotation for the selected customer.
- Start contains four actions in one row: **Selection**, **Product**, **System**, and **Pumpset**.
- Assembly KeyPLC continuation lines align under `KeyPLC`, with no blank row above the panel description.
- System and Pumpset builders include **Model / Item**, **Qty**, and **Unit Price** above the description.
- System model suggestions follow the pump arrangement in the BOM while still allowing custom text.
- System Control Panel sizing follows total pump quantity and the highest motor kW, selecting the equal or next larger KeyPLC rating.
- Automatically sized panels start as **Indoor Type** and remain switchable to Sheltered.
- Assembly quotation Qty and manual Unit Price are stored through the existing assembly item JSON, so no database migration is required.

Preserve the deployment's working `config.js`, deploy the V2.11 changed-files patch, and hard-refresh the application.

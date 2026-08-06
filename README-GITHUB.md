# KeySelector CHC v3.2.3g

Test build for the two-page Pump Selection and Technical Data report.

Changes in this build:
- Underlined Motor Efficiency, Power Factor, and Pumpset Dimension headings.
- Fixed the missing Technical Data logo by waiting for images and fonts before printing.
- Removed the duplicate print page break that could create a blank second page on PC.

Open `index.html` in Chrome or Edge, select a pump, and use Export PDF.


## v3.2.3g
- Replaced B.G.Reich logo with the supplied high-definition PNG.
- Lowered the Page 2 TECHNICAL DATA title by 3 px.
- Moved the modification notice one row below the approximate dimension note.

- Reduced the Page 2 header-to-table gap by about half.
- Increased and balanced Page 2 row heights and section spacing to use the printable page more evenly.
- Kept the approved table structure, borders, logo, and footer wording unchanged.


## v3.2.3g
- TECHNICAL DATA title: 13 px
- Technical table content: 10 px
- Approximate dimension note: 10 px
- B.G.Reich reservation notice: 11 px

## v3.2.3n motor data update
- Added motor efficiency selection: IE5, IE4, IE3 (default), IE2 and IE.
- Added motor phase selection: 3 Phase (default) and 1 Phase.
- Voltage range changes automatically: 380–415 V for 3 Phase; 220–240 V for 1 Phase.
- Page 2 motor specifications now match motor HP, phase and efficiency class using Motor - 260726.xlsx.
- IE4 and IE5 remain selectable and display Data Not Available until their specification tables are added.


## v3.2.3n
- Page 2 motor HP omits unnecessary trailing .0 (for example, 15 HP; 1.5 HP).
- PDF report tab closes after printing and returns focus to the selector, allowing a new Flow and Head duty point without refreshing.


## v3.2.3n changes
- Page 3 dimension table vertical separators adjusted to match the approved layout.
- PDF export now uses a temporary print frame, keeping Flow and Head editable after export without refreshing.


## v3.2.3n changes
- Page 3: removed the extra left line before Weight and moved the Weight block left to share the dimension table boundary.
- Selection page: renamed “Select CHC Pump” to “Select” and moved it beside Required Duty, above the Flow controls.

## v3.2.3o changes
- Updated Page 2 Pumpset dimensions from CHC - 260726 - V1.1.xlsx.
- Length = the larger of (D1 / 2 + D2) and the CHC Dimension sheet Pump L.
- Width = the larger of (D1 / 2 + D2) and the CHC Dimension sheet Pump W.
- Height and weight now come directly from the selected model row in the CHC sheet.
- Page 3 dimension table now shows B1, B2, B1+B2, D1 and D2 only; D has been removed.


## v3.2.3z
- Kept all current Page 2 font sizes unchanged.
- Standardized every Page 2 table font to the same Arial/Helvetica font face used on Page 3.

## v3.2.3z update
- Page 2 Country of Origin changed to Malaysia.

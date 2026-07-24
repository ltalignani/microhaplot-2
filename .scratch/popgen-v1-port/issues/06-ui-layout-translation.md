Type: grilling
Status: resolved

## Question

microhaplot2's Population Genetics tab uses bslib constructs with no
direct v1 equivalent: `bslib::layout_sidebar`/`bslib::sidebar` (data-source
toggle + reference-panel controls, out of scope here), `bslib::
navset_card_tab` (the 4 sub-tabs as cards-in-tabs), `bslib::card`/
`card_header` (section framing within each sub-tab), and Bootstrap 5
button classes (`btn-outline-primary btn-sm`).

v1's existing bottom navbar uses classic `navbarMenu(...)` with
`tabPanel(...)` children for multi-part sections (see `"Genotype Call"` and
`"Criteria Cutoff"` in `inst/shiny/microhaplot/ui.R`), and its "Table" tab
(~line 656) uses a `fixedPanel`-based control strip above a `DT` output as
its closest existing analog to a persistent per-tab control area.

Decide the concrete v1-idiomatic translation for the new tab:
- Top-level structure: confirm `navbarMenu("Population Genetics", tabPanel("F-statistics", ...), tabPanel("Allelic diversity", ...), tabPanel("PCA / Projection", ...), tabPanel("Outlier scan", ...))` (mirroring "Genotype Call") is the right shape, or propose an alternative if the 4 sub-tabs' content doesn't fit that pattern well.
- Data-source toggle placement: where does the raw/filtered toggle (from the data-source-mapping ticket) live given there's no sidebar equivalent — a shared control strip at the top of each sub-tab (like "Table"'s `fixedPanel`), or a per-tab `wellPanel`, or something else?
- Card-equivalent framing: how do `bslib::card`/`card_header` sections (e.g. "Per-locus Ho / He / Fis / Fst / Fit", "Pairwise Fst", "BetaS" within F-statistics) map to shinyBS/Bootstrap 3 — plain `wellPanel` + `h4`/`h5` headers, or something else already used elsewhere in v1's UI?
- Button/download styling: what convention should new download buttons follow to look consistent with v1's existing ones (e.g. the plain `downloadButton('downloadData', 'Download')` on the "Table" tab has no special class)?

Use `/prototype` if a visual mockup would help settle this faster than
description alone.

## Answer

Resolved by direct precedent from `inst/shiny/microhaplot/ui.R`'s existing
`"Criteria Cutoff"` and `"Genotype Call"` `navbarMenu`s — no prototype
needed, the conventions there are consistent and unambiguous:

- **Top-level structure**: `navbarMenu("Population Genetics",
  tabPanel(h5("F-statistics"), ...), tabPanel(h5("Allelic diversity"),
  ...), tabPanel(h5("PCA / Projection"), ...), tabPanel(h5("Outlier
  scan"), ...))` — sub-tab titles wrapped in `h5()`, matching every
  existing `navbarMenu` in the app (e.g. `tabPanel(h5("Global Scope"),
  ...)` in Criteria Cutoff).
- **Data-source toggle placement**: no shared/persistent control area —
  v1 has no sidebar equivalent. A `fluidRow`/`column` control strip
  (e.g. `radioButtons` for raw/filtered) repeated at the top of *each*
  of the 4 sub-tabs, matching the "Quality Profiling" sub-tab's existing
  pattern of inline controls at the top of a `tabPanel`.
- **Card-equivalent framing**: no visual wrapper (no `wellPanel`, which
  the codebase barely uses). Section headers are plain `h4()`/`h5()`
  calls directly inside a `column()`, exactly like `column(12,
  h4(textOutput("DP1")))` and `column(6, h4("Individual list:"))` in
  Criteria Cutoff.
- **Button/download styling**: plain `downloadButton(...)`/
  `actionButton(...)` with no custom class — matching the "Table" tab's
  `downloadButton('downloadData', 'Download')`, which has none.

# Spreadsheet twins

Workbooks that publish rules as Excel formulas, each opened as a Logical
English program by the spreadsheet translator (`migration/spreadsheet/`).
Such a program is a **twin**: each formula of the workbook is a
rule (its formula kept above it as a comment), each lookup range a decision
table, each cell a person fills in a fact a scenario states. Every expected
answer in the scenarios comes from the workbook: the values Excel saved in
the file (the scenario `as_saved`), and cases worked out from the workbook by
the spreadsheet engine (`services/sheet`: Formualizer, an open-source engine,
not Microsoft Excel). The ledger beside each twin lists every formula, table
and input, translated directly, approximated, or left as residue.

Only workbooks in the public domain are published here. The pilots made
from workbooks that state no licence for reuse are not published: the
translator writes their twins into a private place (`migration/README.md`).

## Start here
- [CMS Medical Loss Ratio calculator 2025](cms_mlr/cms_mlr.le) — the loss
  ratio of a health insurer, its credibility adjustment, and the rebates
  owed below the 80% and 85% thresholds (a United States federal work, from
  the Centers for Medicare & Medicaid Services). 2,015 elements translated,
  163 approximated, 17 left as residue; 854 of 854 of the workbook's own
  answers reproduced, 49 more waiting for the residue.

## Where the workbook comes from

`cms_mlr/sources/cms_mlr_2025.xlsm` is the "MLR 2025 Calculator and Formula
Tool" of the Centers for Medicare & Medicaid Services (CMS), copied unchanged
from <https://www.cms.gov/files/document/2025-mlr-calculator.xlsm> in October
2026. It is a work of the United States Government, which has no copyright
protection in the United States (17 U.S.C. § 105). `cms_mlr_2025.vba.txt`
beside it is the text of the workbook's own macros, written out by the
translator. The calculator is a tool that goes with the MLR Annual Reporting
Form; it is not the form that an insurer files. CMS did not take part in the
translation and does not endorse it: the twin is not an official statement of
the Medical Loss Ratio rules.

See also `../../regulatory/medicare/vitamin_d_bmi.le`, a rule that asks a
workbook instead of translating it (the `sheet:` services address), and
`docs/user/integrations/spreadsheets.md`.

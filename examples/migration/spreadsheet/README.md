# Spreadsheet twins

Workbooks that publish rules as Excel formulas, each opened as a Logical
English program by the spreadsheet translator of the Logical English
Translators. Such a program is a **twin**: each formula of the workbook is a
rule (its formula kept above it as a comment), each lookup range a decision
table, each cell a person fills in a fact a scenario states. Every expected
answer in the scenarios is a value the workbook itself computed: the values
Excel saved in the file, and cases worked out by the spreadsheet engine
(`services/sheet`). The ledger beside each twin lists every formula, table
and input, translated directly, approximated, or left as residue.

Only workbooks in the public domain are published here. The pilots made
from workbooks that state no licence for reuse are kept in the Logical
English Translators' own repository.

## Start here
- [CMS Medical Loss Ratio calculator 2025](cms_mlr/cms_mlr.le) — the loss
  ratio of a health insurer, its credibility adjustment, and the rebates
  owed below the 80% and 85% thresholds (a United States federal work, from
  the Centers for Medicare & Medicaid Services). 2,015 elements translated,
  854 of 854 of the workbook's own answers reproduced.

See also `../../regulatory/medicare/vitamin_d_bmi.le`, a rule that asks a
workbook instead of translating it (the `sheet:` services address), and
`docs/user/integrations/spreadsheets.md`.

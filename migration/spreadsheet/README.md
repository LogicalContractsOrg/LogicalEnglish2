# Spreadsheets into Logical English

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

*Kind: developer guide · Audience: developers · Status: Phases 0–3 of the design notes Excel.md §7.7 (12 October 2026)*

A workbook (Excel `.xlsx` or `.xlsm`) opened with File ▸ Open in the LE
editor becomes a Logical English (LE) program: the workbook's *twin*. The
plan, and the survey of public spreadsheets behind it, is
the design notes `Excel.md`.

| Element of the sheet | In the twin |
|---|---|
| a cell a person fills in (unlocked on a protected sheet, with a list of allowed values, or empty and read by a formula) | an input: a template `; undefined`, which each scenario states |
| another constant cell a formula reads | a fact of the knowledge base, citing its cell (`as stated in "file.xlsx" at Sheet B54`) |
| a range read by `LOOKUP`, `VLOOKUP`, `HLOOKUP` or `INDEX`/`MATCH` | a decision table (language.md §17.3); an approximate match is a band `>= k and < next`, with first match |
| a formula | a rule, its formula as a comment above it; an `IF` is an `otherwise` cascade |
| a formula no other formula reads, and that depends on an input | an output: a query, and an expectation in every scenario |
| a column of copies of one formula (the same in R1C1 terms, every reference on its own row), and the input columns it reads | one rule over each row: the template's first place is the row (`the withholding of *a row* is *an amount*`), and a scenario states the rows it fills (`row_7`); a `SUM` over such a column is an aggregate |
| a formula the translator cannot read | a residue block (le_writer), for the Contract Assistant's residue mode |

The words of a template come from the cell's label: the text to its left,
or above it, cleaned of numbering, brackets and instructions
(`xlsx_ir:label_words/2`). The program is written in the language of the
labels (English, Portuguese, Spanish, French, Italian), detected from them.

## The sheet is its own oracle

Every expected answer of the twin is a value the workbook itself computed
(`xlsx_tests.pl`):

- the scenario `as_saved`: the inputs as the file holds them, and the values
  Excel saved for the outputs;
- twelve generated cases: inputs drawn (from a fixed seed) around the
  thresholds the formulas and tables test and at random, each case evaluated
  by the sheet engine. A percentage is drawn between 0 and 100%, a count
  (an input whose thresholds are small whole numbers) among small numbers,
  a date within about a year of the date saved;
- with `examples([...])`, one scenario per filled example workbook.

A value the sheet shows as an error (`#N/A`, `#VALUE!`) is not correct, so
it is not expected; the scenario says so in a comment.

## The pieces

| File | What it does |
|---|---|
| LE2 `services/sheet/sheet_engine.mjs` | reads the workbook (cells, saved values, styles, names, validations, comments) and evaluates it with Formualizer, an Excel formula engine compiled to WebAssembly. The same module serves LE2's `sheet:` services and runs in a browser |
| `xlsx_front.mjs` | the workbook as JSON (`read`), cases evaluated (`eval`), the coverage survey (`survey`) |
| `xlsx_ir.pl` | structure recovery, labels, formulas as rules, tables, ledger entries |
| `xlsx_tests.pl` | the scenarios, from the saved values and the oracle |
| `xlsx_import.pl` | the adapter File ▸ Open calls (`le_importers.pl`), and `import_workbook/4` |
| `build.pl` | the twins (`build_all`): public-domain ones beside LE2's examples, the others in this repository's `examples/migration/spreadsheet/` |
| `fetch_sources.sh` | the workbooks of the survey and the pilots, into `.cache/files` |
| `survey.sh`, `survey_corpus.sh`, `harvest_corpus.py`, `survey_report.py` | phase 0: how much of each workbook the engine recomputes as Excel saved it; `survey.md`, `survey_corpus.md`, `corpus.json` |
| `crosscheck/snap_crosscheck.pl` | phase 2: the Massachusetts SNAP sheet against the RuleSpec twin of 7 USC 2017(a); `crosscheck/snap_crosscheck.md` |
| `test_spreadsheet.pl` | `swipl -g run_tests -t halt test_spreadsheet.pl` |

Options of `import_workbook(File, Dir, Options, Result)`: `inputs([Ref...])`
(the inputs, when the workbook does not say), `outputs([Ref...])` (the
answer cells: only what they need is translated — for a large model),
`examples([Workbook...])` (workbooks of the same layout filled in by the
publisher: each a scenario, its saved values the expected answers),
`cases(N)` (default 12),
`seed(S)`, `max_outputs(N)` (default 200), `language(L)`, `name(Base)`,
`known_departures([Scenario-Reason])` (expectations written pending, with the
reason), and for a diagnosis `outputs(all)` with `expect_errors(true)`: every
translated cell is expected, and where the sheet shows an error LE must
answer nothing — the first cell that differs is where to look.

## Asking the sheet instead: the `sheet:` address (Mode B)

Every import also drafts, at the end of the twin and in comments, the Logical
English that asks the workbook instead of the translation (LE2's `sheet:`
services address, language.md §17.6): the service line, a template for each
answer it found (when the inputs are few enough to be the places of one
sentence), and the section `the cells of service workbook are:` that says
which cells answer each template, followed by the list of the input and
answer cells with their labels. No file is written beside the workbook: the
binding is part of the program. `test_spreadsheet.pl` copies the draft out of
its comment and asks the workbook with it.
`examples/migration/spreadsheet/ok_child_support_service/` asks Oklahoma's own
calculator for each parent's base obligation, and LE2's
`examples/regulatory/medicare/vitamin_d_bmi.le` asks a BMI workbook for a
patient's ICD-10 code.

## How Excel's meaning is kept

- **Errors.** Where Excel shows an error, LE answers nothing. An IF reads the
  cells its condition needs before choosing a branch, so an error in the
  condition is an error of the IF, as in Excel.
- **Numbers and text.** Arithmetic on a value that may not be a number goes
  through the helper `*a value* counts in arithmetic as *a number*` (TRUE as
  1, FALSE as 0, a text of digits as its number, any other text: no value,
  Excel's `#VALUE!`). A comparison of a number with a text follows Excel's
  order (every number before every text).
- **Text that reads as a number.** Excel reads `"$35.00"` as 35 in
  arithmetic; Formualizer 0.11 does not. Such a literal is rewritten as its
  number, in the workbook the oracle evaluates and in the rules alike, and
  the ledger marks the formula approximated.
- **OR** is "it is not the case that none holds": one answer however many
  alternatives hold.
- **Equality in a cascade** is written with the constant first, or with
  Prolog's equality between two values, so LE's guard keeps it (language.md
  §17.2).
- **ROUND** rounds half away from zero on the decimal shown (`2.675` → `2.68`).
- **An empty input** is 0, as in Excel's arithmetic and references (`=C13`
  gives 0); Excel's test for an empty cell, `C13=""`, is read as `C13=0` (an
  entered 0 then counts as empty: approximated).
- **ISERROR** computes its argument: a division by zero has no value
  (LE2's `=` fails on it), so ISERROR holds.
- **MIN and MAX** are LE's conditions `the minimum of X and Y is Z`.
- **A lookup with a computed column** (`VLOOKUP(x, table, MIN(n+2, 8))`) is a
  table of two keys: the row's band and the column's number.
- **Every formula's template is memorable** (language.md §2.5): a cell read
  by many others is worked out once per query.
- **CHOOSE** is a cascade over its index; **SUMIF, COUNTIF, SUMIFS,
  COUNTIFS** over at most 400 cells are a sum of one term per cell (the
  cell's value, or 1, where every criterion holds; a comparison criterion
  holds only for a number, as in Excel).
- **Dates.** A cell formatted as a date is an LE date (`2026-03-15`), not
  Excel's day number; `EDATE` is LE's `months after`, a date plus or minus a
  number of days LE's `days after`, dates compare by time, and `YEAR`,
  `MONTH`, `DAY` read the parts.
- **A range with the sheet named at both ends** (`'Pt 2'!D14:'Pt 2'!D17`)
  is one range.

Known approximations, each in the ledger: text compared exactly (Excel
ignores case); an error inside the branch an IF takes moves the twin's
cascade to the next alternative; an approximate match on text keys is read
as an exact match.

## Requirements

Node 18 or later and `npm ci` in LE2's `services/sheet` (formualizer 0.11.1,
fflate 0.8.2). Nothing else: no Python, no LibreOffice. `.xls` and `.ods`
files are refused with the reason (save them as `.xlsx`).

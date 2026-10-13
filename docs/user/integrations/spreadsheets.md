# Spreadsheets and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-12)*

Many rules live in spreadsheets. A tax office publishes a calculator, a legal
aid group a benefit worksheet, a court a child support form. Each is an
Excel workbook: a file of cells, where some cells hold a number a person
types in and others hold a **formula**, a small calculation such as
`=IF(B27<=B31,"PASSED","FAILED")` that works out a value from other cells.

Logical English (LE) can use such a workbook in two ways.

- **Open it.** **File ▸ Open…** (or **File ▸ Import from Another System…**)
  takes an Excel workbook (a file ending in `.xlsx` or `.xlsm`) and writes it
  as an LE program: each formula becomes a rule, each table the formulas
  look values up in becomes a decision table, and each cell a person types
  into becomes a fact a scenario states. LE calls the result the workbook's
  *twin*. The twin comes with scenarios whose expected answers are the
  workbook's own: the values the workbook itself computes.
- **Ask it.** A program can leave the workbook as it is and ask it for an
  answer, as it would ask any outside service. The workbook stays the
  authority, and LE credits each answer to it.

The translator that opens workbooks is part of the Logical English
Translators, so only installations that have them, such as the hosted
service, offer it. Asking a workbook is part of LE itself.

## Contents

- [A small example](#a-small-example)
- [How to open a workbook](#how-to-open-a-workbook)
- [What the twin holds](#what-the-twin-holds)
- [Where the expected answers come from](#where-the-expected-answers-come-from)
- [Where Excel and Logical English differ](#where-excel-and-logical-english-differ)
- [Large workbooks](#large-workbooks)
- [Asking a workbook instead](#asking-a-workbook-instead)
- [What is not supported yet](#what-is-not-supported-yet)
- [See also](#see-also)

## A small example

A tax calculator has three cells that matter. B1 holds the income, which a
person types in. B2 looks up the rate in a table of income bands on another
sheet: `=VLOOKUP(B1,Brackets!A2:B4,2,TRUE)`. B3 works out the tax:
`=IF(B1<12000,0,ROUND(B1*B2,2))`. The labels "Income", "Rate" and "Tax" are
in column A, beside the cells.

Opened in LE, the workbook becomes:

```le
the templates are:
    the income is *a number*; scenario element.
    the rate is *a number*; memorable.
    the tax is *a number*; memorable.
    the rate for *a key* is *a value* under table rate.

the table rate is, with first match, with provenance "tax.xlsx" at Brackets A2 to B4:
    row | key                  | value
    r1  | >= 0 and < 12000     | 0
    r2  | >= 12000 and < 50000 | 0.2
    r3  | >= 50000             | 0.4

the knowledge base tax includes:

% Calc!B2: =VLOOKUP(B1,Brackets!A2:B4,2,TRUE)
the rate is a number if
    the income is a second number
    and the rate for the second number is the number under table rate.

% Calc!B3: =IF(B1<12000,0,ROUND(B1*B2,2))
the tax is a number N if
    the income is a number M
    and M < 12000
        and N is equal to 0
        otherwise the income is a number K
        and the rate is a number P
        and N = round(K * P * 100 * (1 + 0.000000000001)) / 100.
```

Two templates are about the rate, and they are not the same. `the rate is
*a number*` is cell B2: the rate of this case, which the rule for the tax
reads. `the rate for *a key* is *a value* under table rate` is the table of
bands, which gives the rate for any income; the rule for B2 asks it for the
rate of the case's income.

Each rule keeps its formula above it as a comment, so a reader can check
one against the other. The words of each template come from the label
beside the cell, and a table is named after the column it returns. The
addition `memorable` tells LE to work a value out once in each question,
however many rules read it.

## How to open a workbook

1. Choose **File ▸ Open…** and pick the workbook.
2. LE writes the twin and opens it. The notes say how many formulas were
   translated, and how many of the workbook's own answers the twin
   reproduces.
3. **File ▸ Show the Original…** lists the workbook, kept beside the twin in
   a folder called `sources`.

A workbook in the older Excel format (`.xls`) or in the OpenDocument format
(`.ods`) is refused, with the reason: save it as `.xlsx` first.

## What the twin holds

| In the workbook | In the twin |
|---|---|
| A cell a person types in: unlocked on a protected sheet, with a list of allowed values, or empty and used by a formula | A template marked as a scenario element: each scenario states its value |
| Another number or text a formula uses (a rate, a limit) | A fact of the program, which says which cell it came from |
| A range that `LOOKUP`, `VLOOKUP`, `HLOOKUP` or `INDEX` and `MATCH` look values up in | A decision table. A range of numbers searched for the nearest lower value becomes a table of bands, such as `>= 12000 and < 50000` |
| A formula | A rule. An `IF` becomes an `otherwise` cascade: the first branch, or else the next |
| A formula no other formula uses | An *output*: a query, and an expected answer in every scenario |
| A column of copies of one formula, one row per employee, say | One rule for every row. The row is the first place of the template, as in `the withholding of *a row* is *an amount*`, and a scenario names the rows it fills, such as `row_7` |
| A formula the translator cannot read | A block marked `RESIDUE`, which keeps the formula. The Contract Assistant can translate such blocks |

A cell formatted as a date becomes a date in the twin (`2026-03-15`), and
date arithmetic uses LE's own sentences: `EDATE(B4,2)`, two months after a
date, becomes `… is 2 months after …`.

The program is written in the language of the workbook's labels: a
Portuguese calculator becomes a program in Portuguese LE. Each import also
writes a **ledger**, a list of every formula, table, input and constant,
each marked as translated directly, translated with a small difference
(*approximated*), or left as residue.

## Where the expected answers come from

Every expected answer in the twin is a value that the workbook itself
computed.

- **The values saved in the file.** The scenario `as_saved` states the
  inputs as the file holds them, and expects the values Excel saved for the
  outputs.
- **Cases the workbook computed.** Twelve more scenarios each choose new
  inputs: values just below, on and just above the limits the formulas test,
  and values at random. The workbook is worked out for each case by a
  spreadsheet engine inside LE, and its outputs become the expected answers.
- **Examples the publisher filled in.** Some authorities publish their
  template with worked examples: the same workbook, filled in for a typical
  case. Each example can become a scenario of its own, its saved values the
  expected answers.

The generated cases stay realistic: a percentage is drawn between 0 and
100%, a count among small numbers, a date within about a year of the date
in the file.

Where the workbook shows an error instead of a value, such as `#N/A`, there
is no correct value, so nothing is expected; the scenario says so in a
comment.

## Where Excel and Logical English differ

The twin keeps Excel's meaning where the two languages differ, and the
ledger names every place where it could not do so exactly.

- Where Excel shows an error, the twin gives no answer.
- Excel reads TRUE as 1 and FALSE as 0 in arithmetic, and an empty cell as
  0. The twin does the same.
- Excel puts every number before every text when it compares them. The twin
  does the same.
- Excel compares texts without regard to capital letters. The twin compares
  them exactly: *approximated*.
- When the branch an `IF` chooses shows an error, Excel shows the error. The
  twin goes on to the next branch instead: *approximated*.

## Large workbooks

For a workbook of thousands of formulas the translator can be told which
cells hold the answers, and it translates only what those cells need. The
import also says when it took an implausible number of cells as inputs —
empty cells that formulas read, in a workbook that does not mark which cells
a person fills in — so that the inputs can be named instead. These two
choices are options of the translator, available to whoever runs it (see
the developer guide of the Logical English Translators).

## Asking a workbook instead

Sometimes the workbook should stay the authority: a court's own calculator,
say, or a workbook too large to review. A program then declares the
workbook as a **service** and asks it. The address of such a service starts
with `sheet:`:

```le
the knowledge base ok child support service includes these services:
    father at sheet:sources/ok_child_support.xlsm#father_base_obligation as a calculator.

the templates are:
    the father's base obligation for *a number* children with incomes *an amount* and *an amount* is *an amount*; via service father.
```

Beside the workbook, a small file says which cells the question fills and
which cell holds the answer. It has the workbook's name and ends in
`.sheetport.yaml`. Opening a workbook in LE writes a draft of this file in
the `sources` folder, listing every input and output the translator found.
Keep the ones the question needs, in the order the template gives its
values. The answer is the cell the address names after `#`.

The explanation credits the workbook: *according to service father, because
ok_child_support.xlsm computed father_base_obligation from children = 2,
father_income = 5000, mother_income = 3000*. The rules for services in
general, such as asking only once and keeping the answers, are in §17.6 of
the [language reference](../reference/language.md#176-services-and-semantic-predicates-over-text).

## What is not supported yet

- Workbooks in the `.xls` and `.ods` formats: save them as `.xlsx`.
- Macros, the programs some workbooks run when a button is pressed: they
  are not read. A workbook whose rules live in macros becomes a twin with
  little in it.
- Some functions: text functions such as `CONCATENATE` and `TEXT`,
  `TODAY`, `EOMONTH`, `INDIRECT`, `OFFSET` and array formulas become residue
  blocks. (`IF`, `AND`, `OR`, `CHOOSE`, the lookups, `SUM`, `SUMIF`,
  `COUNTIF` and their plural forms over up to 400 cells, `MIN`, `MAX`,
  `ROUND` and its kin, `EDATE`, `YEAR`, `MONTH`, `DAY` and date arithmetic
  are read.)
- A very large model, such as the European Union's template for the carbon
  border adjustment, with tens of thousands of formulas: name the cells
  that hold the answers (see below), and the twin holds only what they
  need.
- Rules written as sentences in cells, as some regulators publish them, are
  planned separately.
- Writing an LE program back as a workbook is not offered.
- Asking a workbook needs a server with the spreadsheet engine installed. In
  the editions of LE that run entirely in the browser, the question is
  answered as unknown.

## See also

- [Language reference](../reference/language.md), §17.3 (decision tables),
  §17.2 (`otherwise` cascades) and §17.6 (services).
- `examples/regulatory/medicare/vitamin_d_bmi.le`: a rule that asks a
  workbook for a patient's body mass index code.

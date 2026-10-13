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
say, or a workbook too large to review. A program can then leave the
workbook as it is and ask it for an answer whenever a rule needs one. LE
calls an outside source of answers a **service** (§17.6 of the
[language reference](../reference/language.md#176-services-and-semantic-predicates-over-text)).
A workbook becomes a service in four steps. The example is Oklahoma's child
support computation: given the number of children and each parent's gross
monthly income, the workbook works out each parent's base monthly
obligation.

### Step 1. Put the workbook beside the program

The workbook must be in the program's folder on the LE server, or in a
folder under it. Here the program is `ok_child_support_service.le` and the
workbook is `sources/ok_child_support.xlsm`. The workbook may not be
anywhere else: LE refuses a workbook outside the program's folder. A
program typed into the editor without a folder of its own cannot ask a
workbook.

### Step 2. Write the manifest beside the workbook

Yes, one more file is needed. A workbook does not say which of its cells are
questions and which are answers, so a small text file says it: the
**manifest**. It sits in the same folder as the workbook, with the
workbook's name and the ending `.sheetport.yaml` in place of `.xlsx` or
`.xlsm`; here, `sources/ok_child_support.sheetport.yaml`. Its format is
SheetPort, the format of the spreadsheet engine LE uses, written in YAML, a
common format for structured text:

```yaml
spec: fio
spec_version: "0.3.0"
manifest:
  id: ok-child-support
  name: "Oklahoma child support computation"
  workbook:
    uri: "file://ok_child_support.xlsm"
    locale: en-US
    date_system: 1900
ports:
  - id: children
    dir: in
    shape: scalar
    location: { a1: "'Child Support Comp Entry'!B4" }
    schema: { type: number }
  - id: father_income
    dir: in
    shape: scalar
    location: { a1: "'Child Support Comp Entry'!C5" }
    schema: { type: number }
  - id: mother_income
    dir: in
    shape: scalar
    location: { a1: "'Child Support Comp Entry'!D5" }
    schema: { type: number }
  - id: father_base_obligation
    dir: out
    shape: scalar
    location: { a1: "'Child Support Comp Entry'!C17" }
    schema: { type: number }
```

The first eight lines are the same for every workbook, except for three
values: `id`, a short name of 3 to 64 lowercase letters, digits and hyphens
(`ok-child-support`; no spaces and no underscores); `name`, any title; and
`uri`, which names the workbook file. Then comes the list of **ports**. A
port is one cell the service uses:

- `id` names the port;
- `dir: in` is a cell LE fills in before the workbook is worked out (a
  question), `dir: out` a cell LE reads afterwards (an answer);
- `location` is the cell, written as in Excel: the sheet's name in single
  quotes, an exclamation mark, the cell;
- `schema` says what the cell holds: `number`, or `string` for a text;
- `shape: scalar` says the port is one cell.

Every cell the manifest does not name keeps the value saved in the
workbook.

**The order of the input ports matters**: LE fills them, in the order they
are listed, with the values the template gives, in the order the template
gives them (step 4).

The manifest need not be written from nothing. Opening the workbook with
**File ▸ Open…** (with the Logical English Translators) writes a draft of it
beside the copy of the workbook, in the `sources` folder, listing every
input and output the translator found; **File ▸ Show the Original…** opens
it. Keep the ports the question needs, give them clear names, and put the
input ports in the right order.

### Step 3. Declare the service

```le
the knowledge base ok child support service includes these services:
    father at sheet:sources/ok_child_support.xlsm#father_base_obligation as a calculator.
```

The line reads: *the service called `father` is at the address
`sheet:sources/ok_child_support.xlsm#father_base_obligation`, and it is a
calculator.* Piece by piece:

| Piece | Meaning |
|---|---|
| `father` | the service's name, one word, which templates use to name it |
| `at` | the address follows |
| `sheet:` | the kind of address: a workbook (other services have addresses starting with `https://` or `llm:`) |
| `sources/ok_child_support.xlsm` | the workbook, given from the program's folder |
| `#father_base_obligation` | the output port (step 2) whose cell is the answer. When the manifest has only one output port, `#` and the name may be left out |
| `as a calculator` | the kind of service, a word or two of description. Only the kind `semantic matcher` means something to LE; any other is a description for the reader |

A workbook can be declared several times, once for each answer it gives.
The Oklahoma example declares a second service, `mother at
sheet:sources/ok_child_support.xlsm#mother_base_obligation`, for the other
parent's obligation. Several declarations are separated by commas, and the
last one ends with a full stop.

### Step 4. Write a template the service answers, and use it

```le
the templates are:
    the father's base obligation for *a number* children with incomes *an amount* and *an amount* is *an amount*; via service father.
```

`; via service father` says that the service `father` answers this
template. Its places are matched to the manifest's ports:

- every place but the last is an input: the first value fills the first
  input port (`children`), the second the second (`father_income`), the
  third the third (`mother_income`). So the template must have as many
  places before the last as the manifest has input ports;
- the last place is the answer, the value of the output port the address
  names.

A rule then uses the template like any other. It must know every input
value by the time it asks; a question with an input still unknown stops the
query with an error, because a workbook cannot be worked out backwards:

```le
the base monthly obligation of the father in a case is an amount
    if the number of children of the case is a number
    and the gross monthly income of the father in the case is a first amount
    and the gross monthly income of the mother in the case is a second amount
    and the father's base obligation for the number children with incomes the first amount and the second amount is the amount.
```

For two children and incomes of 5,000 and 3,000, the answer is 814.38,
worked out by the workbook. The explanation credits it: *according to
service father, because ok_child_support.xlsm computed
father_base_obligation from children = 2, father_income = 5000,
mother_income = 3000*.

### What else to know

- LE asks the workbook once for each different question in a session, and
  keeps the answer (§17.6). A changed workbook counts as a new one, so an
  answer kept from the old one is not reused.
- The workbook is worked out with its clock fixed, so a formula such as
  `TODAY()` gives the same answer each time.
- When the workbook cannot be asked — no workbook or no manifest where the
  address says, a value of the wrong type for a port (a text where the
  manifest says `number`), a template with the wrong number of places, an
  error in the answer cell — the question is answered as **unknown**, and
  the query still answers on that condition. The server's log says why.
- Asking a workbook needs a server with the spreadsheet engine installed
  (Node and the packages of `services/sheet`). In the editions of LE that
  run entirely in the browser, the question is answered as unknown.

Two complete examples: `examples/regulatory/medicare/vitamin_d_bmi.le`
asks a small workbook for a patient's body mass index code; the Oklahoma
example comes with the Logical English Translators.

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

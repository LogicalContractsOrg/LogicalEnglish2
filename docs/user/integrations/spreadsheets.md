# Spreadsheets and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-13)*

Many rules are in spreadsheets. For example, a tax office publishes a calculator, a
legal aid group publishes a benefit worksheet, and a court publishes a child support
form. Each of these spreadsheets is an Excel workbook. A workbook is a file of cells.
In some cells, a person types a number. Other cells contain a **formula**. A formula
is a small calculation that finds a value from other cells, for example
`=IF(B27<=B31,"PASSED","FAILED")`.

Logical English (LE) can use such a workbook in two ways:

- **Open the workbook.** **File ▸ Open…** (or **File ▸ Import from Another
  System…**) accepts an Excel workbook (a file that ends in `.xlsx` or `.xlsm`). LE
  then writes the workbook as an LE program. Each formula becomes a rule. Each table
  where the formulas look up values becomes a decision table. Each cell where a
  person types a value becomes a fact that a scenario states. (A scenario is a set
  of facts about one case.) LE calls the result the *twin* of the workbook. The twin
  has scenarios, and the expected answers of these scenarios come from the workbook.
  These answers are the values that the workbook itself calculates.
- **Ask the workbook.** A program can keep the workbook as it is and ask the workbook
  for an answer. The program asks the workbook as it asks any outside service. The
  workbook stays the authority, and LE gives the workbook the credit for each answer.

The translator that opens workbooks is a part of the Logical English Translators.
Thus only the installations that have the translators give this function. The hosted
service is one of these installations. The function that asks a workbook is a part of
LE itself.

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

A tax calculator has three important cells. B1 contains the income, which a person
types. B2 finds the rate in a table of income bands on a different sheet:
`=VLOOKUP(B1,Brackets!A2:B4,2,TRUE)`. B3 calculates the tax:
`=IF(B1<12000,0,ROUND(B1*B2,2))`. The labels "Income", "Rate" and "Tax" are in column
A, next to the cells.

When you open the workbook in LE, the workbook becomes this program:

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

A template is the pattern of a sentence, with slots for the values. Two templates are
about the rate, and they are not the same. `the rate is *a number*` is cell B2. Cell
B2 is the rate of this case, and the rule for the tax reads this rate.
`the rate for *a key* is *a value* under table rate` is the table of bands. The table
gives the rate for each income. The rule for B2 asks the table for the rate of the
income of the case.

Each rule keeps its formula above it as a comment. Thus a reader can compare the
rule with the formula. The words of each template come from the label next to the
cell. A table gets the name of the column that it returns. The addition `memorable`
tells LE to calculate a value only one time in each question. This is true for any
number of rules that read the value.

## How to open a workbook

Do these steps:

1. Select **File ▸ Open…**.
2. Select the workbook.
3. LE writes the twin and opens it. The notes tell you how many formulas LE
   translated. The notes also tell you how many of the answers of the workbook the
   twin gives again.
4. Select **File ▸ Show the Original…** to see the workbook. LE keeps the workbook
   next to the twin, in a folder with the name `sources`.

LE refuses a workbook in the older Excel format (`.xls`) or in the OpenDocument
format (`.ods`). LE gives the reason: save the workbook as `.xlsx` first.

## What the twin holds

| In the workbook | In the twin |
|---|---|
| A cell where a person types a value: an unlocked cell on a protected sheet, a cell with a list of permitted values, or an empty cell that a formula uses | A template with the mark scenario element: each scenario states the value |
| A different number or text that a formula uses (for example a rate or a limit) | A fact of the program. The fact tells the cell that it came from |
| A range where `LOOKUP`, `VLOOKUP`, `HLOOKUP` or `INDEX` and `MATCH` look up values | A decision table. Sometimes the formula searches a range of numbers for the nearest lower value. That range becomes a table of bands, for example `>= 12000 and < 50000` |
| A formula | A rule. An `IF` becomes an `otherwise` cascade: the first branch, or if not, the next branch |
| A formula that no other formula uses | An *output*: a query, and an expected answer in each scenario |
| A column of copies of one formula, for example one row for each employee | One rule for all the rows. The row is the first slot of the template, for example `the withholding of *a row* is *an amount*`. A scenario gives the names of the rows that it fills, for example `row_7` |
| A formula that the translator cannot read | A block with the mark `RESIDUE`. The block keeps the formula. The Contract Assistant can translate such blocks |

A cell with the format of a date becomes a date in the twin (`2026-03-15`). Date
calculations use the sentences of LE. For example, `EDATE(B4,2)` means two months
after a date. It becomes `… is 2 months after …`.

LE writes the program in the language of the labels of the workbook. For example, a
Portuguese calculator becomes a program in Portuguese LE. Each import also writes a
**ledger**. The ledger is a list of all the formulas, tables, inputs and constants.
The ledger gives each item one of three marks: translated directly, translated with a
small difference (*approximated*), or kept as residue.

## Where the expected answers come from

Each expected answer in the twin is a value that the workbook itself calculated.
There are three sources:

- **The values that the file contains.** The scenario `as_saved` states the inputs
  as the file contains them. The scenario expects the values that Excel saved for the
  outputs.
- **Cases that the workbook calculated.** Twelve more scenarios each select new
  inputs. Some values are just below a limit that the formulas test, some are on the
  limit, and some are just above the limit. Other values are random. A spreadsheet
  engine inside LE calculates the workbook for each case. The outputs become the
  expected answers.
- **Examples that the publisher filled in.** Some authorities publish their template
  with worked examples. A worked example is the same workbook, filled in for a
  typical case. Each example can become a separate scenario. The values that the
  example contains become the expected answers.

The cases that LE makes stay realistic. A percentage is between 0 and 100%. A count
is a small number. A date is within approximately one year of the date in the file.

Sometimes the workbook shows an error and not a value, for example `#N/A`. Then there
is no correct value, thus the scenario expects nothing. A comment in the scenario
tells you this.

## Where Excel and Logical English differ

The twin keeps the meaning of Excel where the two languages are different. The ledger
gives each place where the twin could not keep the meaning exactly.

- Where Excel shows an error, the twin gives no answer.
- In calculations, Excel reads TRUE as 1, FALSE as 0, and an empty cell as 0. The
  twin does the same.
- When Excel compares numbers and texts, it puts all numbers before all texts. The
  twin does the same.
- Excel compares texts and ignores capital letters. The twin compares texts exactly:
  *approximated*.
- Sometimes the branch that an `IF` selects shows an error. Then Excel shows the
  error. The twin continues to the next branch: *approximated*.

## Large workbooks

A workbook can have thousands of formulas. For such a workbook, you can tell the
translator which cells contain the answers. The translator then translates only the
parts that these cells need. Some workbooks do not mark the cells that a person
fills in. In such a workbook, the translator takes the empty cells that formulas read
as inputs. Sometimes the number of these inputs is not realistic. The import then
tells you, so that you can give the names of the inputs. These two choices are
options of the translator. Each person who runs the translator can use them. (Refer
to the developer guide of the Logical English Translators.)

## Asking a workbook instead

Sometimes the workbook must stay the authority. An example is the calculator of a
court, or a workbook that is too large to examine. Then a program can keep the
workbook as it is. The program asks the workbook for an answer each time a rule needs
one. LE calls an outside source of answers a **service** (§17.6 of the
[language reference](../reference/language.md#176-services-and-semantic-predicates-over-text)).
You write all the necessary data in the program itself, in Logical English. You need
no other file, only the workbook. There are five steps. The example is the child
support calculation of Oklahoma. The inputs are the number of children and the gross
monthly income of each parent. The workbook calculates the base monthly obligation of
each parent.

### Step 1. Put the workbook in the program's folder

The workbook must be in the folder of the program on the LE server, or in a folder
below it. Here, the program is `ok_child_support_service.le` and the workbook is
`sources/ok_child_support.xlsm`. The workbook cannot be in a different place. LE
refuses a workbook outside the folder of the program. Sometimes you type a program
into the editor, and the program has no folder. Such a program cannot ask a workbook.

### Step 2. Declare the service

```le
the knowledge base ok child support service includes these services:
    oklahoma at sheet:sources/ok_child_support.xlsm as a calculator.
```

The line means: *the service with the name `oklahoma` is at the address
`sheet:sources/ok_child_support.xlsm`, and it is a calculator.* These are the parts
of the line:

| Piece | Meaning |
|---|---|
| `oklahoma` | the name of the service. The name is one word. The other parts of the program use this name for the service |
| `at` | the address comes next |
| `sheet:` | the kind of address: a workbook (the addresses of other services start with `https://` or `llm:`) |
| `sources/ok_child_support.xlsm` | the workbook, relative to the folder of the program |
| `as a calculator` | the kind of service, in one or two words. Only the kind `semantic matcher` has a meaning for LE. Any other kind is a description for the reader |

When a program declares more than one service, commas separate the services. The
last service ends with a full stop.

### Step 3. Write a template for each answer

A **template** is the pattern of a sentence. It has a slot for each value. A slot
has a form such as `*a number*` or `*an amount*`. A template that the workbook
answers ends with `; via service` and the name of the service:

```le
the templates are:
    the father's base obligation for *a number* children with incomes *an amount* and *an amount* is *an amount*; via service oklahoma.
    the mother's base obligation for *a number* children with incomes *an amount* and *an amount* is *an amount*; via service oklahoma.
```

Each slot before the last slot is a question that the program gives to the workbook.
The last slot is the answer that the workbook gives back. One workbook can answer
more than one template, as in this example.

### Step 4. Say which cells answer each template

A workbook does not tell which of its cells are questions and which cells are
answers. The program tells this, in a separate section:

```le
the cells of service oklahoma are:
    the sheet is "Child Support Comp Entry".
    the father's base obligation for "B4" children with incomes "C5" and "D5" is "C17".
    the mother's base obligation for "B4" children with incomes "C5" and "D5" is "D17".
```

Each sentence after the first sentence is a template of step 3 again. But each slot
contains a **cell reference** and not a value. For example, `"B4"` is the cell in
column B, row 4. The sentence means: *to answer this template, write the number of
children into B4, the income of the father into C5 and the income of the mother into
D5. Then calculate the workbook, and read the answer in C17.*

- **`the sheet is "..."`** gives the name of the sheet (the tab of the workbook)
  where the cells are. If this sentence is not there, the cells are on the first
  sheet of the workbook. A cell on a different sheet gives the name of its sheet
  itself, as in Excel. Write the name of the sheet in single quotes, then an
  exclamation mark, then the cell. An example is `"'Rates 2026'!B4"`.
- **`the cell "..." is ...`** gives a cell the same value for each question. For
  example, `the cell "B30" is "monthly".` writes the text `monthly` into B30 each
  time. `the cell "B31" is 12.` writes the number 12.
- Each cell that the section does not name keeps the value that the workbook saved.
- Write the cell references in double quotes. Without the quotes, LE reads `B4` as a
  separate name.

The verifier examines the section immediately when you load the program. The
verifier gives a report at the applicable line for each of these problems:

- A sentence that is not an instance of a template that the service answers.
- A slot that contains something that is not a cell reference.
- A template that the service answers, but no sentence tells which cells answer it.
- A workbook that is not at the address.

You can open the workbook with **File ▸ Open…** (with the Logical English
Translators). LE then writes a draft of steps 2 to 4 at the end of the twin, as a
comment. The draft has the service line, a template for each answer that the
translator found, and the section of cells. After the draft, there is a list of all
the input cells and answer cells, each with its label. Copy the lines out of the
comment. Keep the answers that you need. Give each template clearer words.

### Step 5. Use the template in a rule

A rule uses the template as it uses any other template. The rule must know all the
values of a question when it asks the question. If a value of a question is not yet
known, the query stops with an error. The reason is that a workbook cannot calculate
backwards:

```le
the base monthly obligation of the father in a case is an amount
    if the number of children of the case is a number
    and the gross monthly income of the father in the case is a first amount
    and the gross monthly income of the mother in the case is a second amount
    and the father's base obligation for the number children with incomes the first amount and the second amount is the amount.
```

For two children and incomes of 5,000 and 3,000, the answer is 814.38. The workbook
calculated this answer. The explanation gives the workbook the credit: *according to
service oklahoma, because ok_child_support.xlsm computed C17 from B4 = 2,
C5 = 5000, D5 = 3000*.

### What else to know

- In a session, LE asks the workbook one time for each different question. LE keeps
  the answer (§17.6). A changed workbook is a new workbook for LE. Thus LE does not
  use again an answer that it kept from the old workbook. A change to the section of
  cells also makes a new question.
- When the program gives a date, LE writes the date into its cell as a date. Excel
  reads a date that a person types into a cell in the same way. A formula such as
  `TODAY()` reads the day when the workbook is calculated. A formula such as `RAND()`
  gives the same value each time.
- Sometimes LE cannot calculate the workbook. For example, there is no workbook at
  the address, the workbook does not have the sheet, or the answer cell shows an
  error such as `#VALUE!`. Then the answer to the question is **unknown**, and the
  query continues to answer on that condition. The log of the server gives the
  reason.
- To ask a workbook, you need a server that has the spreadsheet engine (Node and the
  packages of `services/sheet`). Some editions of LE run fully in the browser. In
  these editions, the answer to the question is unknown.

There are two full examples. `examples/regulatory/medicare/vitamin_d_bmi.le` asks a
small workbook for the body mass index code of a patient. The Oklahoma example comes
with the Logical English Translators.

## What is not supported yet

- Workbooks in the `.xls` and `.ods` formats: save them as `.xlsx`.
- Macros: LE does not read macros. Macros are the programs that some workbooks run
  when you click a button. A workbook with its rules in macros becomes a twin with
  little content.
- Some functions become residue blocks. These functions are text functions such as
  `CONCATENATE` and `TEXT`, and also `TODAY`, `EOMONTH`, `INDIRECT`, `OFFSET` and
  array formulas. (LE reads these functions: `IF`, `AND`, `OR`, `CHOOSE`, the
  lookups, `SUM`, `SUMIF`, `COUNTIF` and their plural forms over a maximum of 400
  cells, `MIN`, `MAX`, `ROUND` and the related functions, `EDATE`, `YEAR`, `MONTH`,
  `DAY` and date calculations.)
- A very large model, for example the template of the European Union for the carbon
  border adjustment, with tens of thousands of formulas: give the cells that contain
  the answers (refer to [Large workbooks](#large-workbooks)). The twin then contains
  only the parts that these cells need.
- Some regulators publish rules as sentences in cells. A separate plan is about such
  rules.
- LE cannot write an LE program back as a workbook.
- To ask a workbook, you need a server that has the spreadsheet engine. Some
  editions of LE run fully in the browser. In these editions, the answer to the
  question is unknown.

## See also

- [Language reference](../reference/language.md), §17.3 (decision tables),
  §17.2 (`otherwise` cascades) and §17.6 (services).
- `examples/regulatory/medicare/vitamin_d_bmi.le`: a rule that asks a workbook for
  the body mass index code of a patient.

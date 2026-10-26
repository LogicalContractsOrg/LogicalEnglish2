# DMN and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-26)*

DMN (Decision Model and Notation) is a standard of the Object Management
Group for decision models. A DMN model is an XML file. It holds the
**inputs** of a decision, the **decisions**, and the logic of each decision.
The logic is often a **decision table**: a grid of rules, one rule on each
row. It can also be an expression in **FEEL** (the Friendly Enough
Expression Language), the expression language of DMN. Engines such as
Drools, Camunda and Trisotech run DMN models.

Logical English (LE) reads DMN. **File ▸ Open…** (or **File ▸ Import from
Another System…**) accepts a `.dmn` file. It also accepts an `.xml` file in
the Dutch STTR profile of DMN, which the Dutch Environment and Planning Act
(the *Omgevingswet*) uses. The result is an ordinary Logical English
program. The translation of a model has the name *twin*. When a test file of
the DMN Technology Compatibility Kit (the TCK) is next to the model, its
test cases become scenarios. The translator is a part of the Logical
English Translators. Thus only the installations that have the Translators
give the translator, for example the hosted service. Every installation has
the twins of the TCK, of examples of Dutch government rules (RONL) and of
the Benefit Decision Toolkit of Philadelphia.

## Contents

- [DMN in brief: a small example](#dmn-in-brief-a-small-example)
- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
- [How DMN maps to Logical English](#how-dmn-maps-to-logical-english)
- [Two differences of meaning](#two-differences-of-meaning)
- [What is not supported yet](#what-is-not-supported-yet)
- [See also](#see-also)

## DMN in brief: a small example

A DMN decision table has a column for each input, a column for the output,
and a **hit policy**. The hit policy tells what to do when more than one row
applies. This table of the TCK decides the approval of a loan:

| Age | Risk category | Is affordable | Approval status |
|---|---|---|---|
| >= 18 | "Medium", "Low" | true | "Approved" |
| < 18 | "Medium", "Low" | true | "Declined" |
| - | "High" | true | "Declined" |
| - | - | false | "Declined" |

The hit policy is UNIQUE: only one row can apply. A `-` cell applies to all
values. The twin in Logical English is a decision table too:

```
the table approval_status is, with unique match:
    age   | risk category     | is_affordable | value
    >= 18 | "Medium" or "Low" | true          | "Approved"
    < 18  | "Medium" or "Low" | true          | "Declined"
    any   | "High"            | true          | "Declined"
    any   | any               | false         | "Declined"
```

Each input and each decision becomes a **function**: a template whose last
place is its value (language.md §2.3). An example is `the age is *a
number*`. A rule can then use the value directly, also in a formula:
`N = the monthly salary * 12`.

A test case of the TCK becomes a **scenario**: a set of facts about one
case, with the answers that the test expects:

```
scenario t001 is, as stated in "0004-simpletable-U-test-01.xml" at test case 001:
    the age is 18.
    the risk category is "Medium".
    the is_affordable is true.
    q_d_approval_status expects answers ["the approval status is Approved"].
```

## At a glance

| | |
|---|---|
| Reads | a DMN model of version 1.1 to 1.6 (`.dmn`, or `.xml` with a DMN namespace, as the Dutch STTR files), alone or in a zip file with the models that it imports |
| Writes | one Logical English program. The program keeps the model in its `sources/` folder |
| Tests | a TCK test file next to the model (`<model>-test-01.xml`): one scenario for each test case |
| Way back | not yet |
| Checked against | the expected results of the TCK (compliance level 2: 138 of 138 test cases) and of the Benefit Decision Toolkit (195 of 195); for the models without tests, the answers of Apache KIE Drools 10.2.0 to generated cases (RONL: 346 of 346; the 196 models of the Omgevingswet's rules: 6,364 of 6,364) |

## How to use it

Do these steps:

1. Select **File ▸ Import from Another System…**.
2. Select a DMN file, or a zip file of a model and the models that it
   imports.
3. Read the notes of the program that opens. The notes tell how many
   elements the translator encoded, and how many tests pass.
4. Select a scenario and a query.
5. Click **Query**.
6. Click an answer to see the reason for that answer. Each rule of the twin
   gives the name of its decision, and the row of the table when the rule is
   one row.
7. Click **View Original Text** to see the DMN file.

The twins are in the examples, in `migration/dmn/`. The folders are `tck/`
(the models of compliance level 2 of the TCK), `ronl/` (Dutch government
rules: social assistance, subsidies, permits) and `bdt/` (the Benefit
Decision Toolkit of Code for Philly: Philadelphia tax relief). Start with
`tck/0004_simpletable_u` and `bdt/homestead_exemption`.

> Note: a model that is a set of questions to a citizen (the Dutch STTR
> models) also gets a **view**. The view asks the questions one at a time,
> as the Omgevingsloket of the Dutch government asks them. Select
> **Misc ▸ Open Executive View** to use it.

## How DMN maps to Logical English

| DMN | Logical English |
|---|---|
| an input, a decision with one value | a function: `the risk category is *a text*` |
| a structure (an item definition with components) | a function for each component: `the rate of the approval is *a text*` |
| a list | one fact for each item: `the people of the situation include "p1" with 1950-01-01`, and `the people of the situation are listed`. Each place of an item has the name of its part: `*a delta r* with *an extra dikte mm*` |
| a decision table | an LE decision table, with its hit policy: UNIQUE `with unique match`, FIRST `with first match`, COLLECT `with all matches`. PRIORITY and OUTPUT ORDER put the rows in the sequence of the allowed values of the output |
| COLLECT with SUM, COUNT, MIN or MAX | an aggregate over the rows that apply: `N is the sum of each V such that …` |
| a table with complex cells | one rule for each row |
| a FEEL expression | a rule. The arithmetic stays arithmetic: `N = the principal of the loan * the rate of the loan / 12` |
| a business knowledge model (BKM) | a function with places: `the pmt of *a value* and … is *a value*` |
| a decision service | a function, `the <service> result is *a value*`, when the program's own inputs are its inputs; otherwise its logic, where a decision uses it |
| FEEL's built-in functions | the templates of the libraries `lib/text`, `lib/rounding`, `lib/temporal` and `lib/feel`: `decimal(x, 2)` is `the rounding of x to 2 decimals half even` |
| a date, a duration of years and months | an LE date; a duration is a number of months |

## Two differences of meaning

**No value (null).** In FEEL, a decision can have the value *null*. It has
null when an input is missing, or when no row of its table applies. The twin
gives no answer for null. A decision with true or false has two sets of
rules: one set for *true*, one set for *false*. FEEL has three values here:
`false and null` is false, `true and null` is null. The twin does the same.
Two cases are approximations, and the ledger of the twin tells you:

- **ANY.** The hit policy ANY says that all the rows that apply give the same
  value. The twin uses the first row that applies. DMN gives an error when
  the rows do not agree.
- **A null input in a column that compares numbers.** A table answers only
  when such an input has a value. In DMN, a row with `-` in that column also
  applies when the input is null.

**Numbers.** DMN calculates with exact decimals of 34 digits. Logical English
calculates with ordinary computer numbers, which are very slightly inexact.
A test compares an expected number with the result to 12 significant digits.
When a rule needs exact rounding, the library `lib/rounding` rounds a value
exactly, at a number of decimals.

## What is not supported yet

- **Times, dates with times, and durations of days and hours.** Logical
  English has no type for them.
- **Ranges and functions as values, `instance of`, the functions of regular
  expressions** (`matches`, `replace`, `split`) **and of contexts**
  (`get value`, `context put`). LE keeps them in the program as blocks that
  it did not translate. The blocks have a mark: a person or the Contract
  Assistant must translate them.
- **A business knowledge model in Java.**
- **The way back**, from Logical English to DMN.

On the TCK's compliance level 3, which tests FEEL function by function, the
twins give 1,745 of the 3,559 answers (49%). The answers that are not given are
mostly the parts above.

The names in an STTR model often end with letters such as `UR` and `CR`. The
modeller of the Omgevingswet uses them to identify the kind of rule: `UR`
(*uitvoeringsregel*) is a question, `CR` (*conclusieregel*) a conclusion.
The twin keeps them in the words of its templates.

## See also

- [Other systems: importing and exporting](index.md)
- DMN: https://www.omg.org/dmn/
- The DMN TCK: https://github.com/dmn-tck/tck (Apache-2.0)
- The Benefit Decision Toolkit: https://github.com/CodeForPhilly/benefit-decision-toolkit (MIT)
- RONL examples: https://github.com/sgort/linked-data-explorer (EUPL-1.2)

# Rune and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-18)*

**Rune** is a language to write financial rules as programs that a computer runs.
These rules tell what a trade is, what occurs to the trade during its life, and what
a bank must report about the trade to its regulators. Rune is free software. FINOS,
the Fintech Open Source Foundation, keeps Rune. Two large models are written in Rune:

- The **Common Domain Model** (the CDM). The CDM is a description of trades and of
  the events in their lives (a new trade, an amendment, a termination). Banks and
  other firms share the CDM, so that they all describe a trade in the same way.
- **Digital Regulatory Reporting** (DRR). ISDA, the International Swaps and
  Derivatives Association, publishes DRR. Nine regulators in eight jurisdictions ask
  for 28 reports. For each of these reports, DRR contains the rules that calculate
  each field of the report from a trade. The CDM describes the trade.

Logical English (LE) can read Rune, and LE can write it back. **File ▸ Open…** (or
**File ▸ Import from Another System…**) reads a `.rosetta` file. Rune keeps its
programs in `.rosetta` files. The menu item also reads a zip file of some `.rosetta`
files. A zip file is one compressed file that contains many files.

The result is a Logical English program. In this program, each rule is a sentence.
Each field of a report is a rule that cites the passage of the regulation that the
rule implements. **File ▸ Export to Another System… ▸ Rune** writes back the rules
that you changed. Then it runs the result on the engine of DRR. The translator is
part of the Logical English Translators. Thus only installations that have the
Logical English Translators show this menu item.

## Contents

- [The words used here](#the-words-used-here)
- [What happens when a Rune file is opened](#what-happens-when-a-rune-file-is-opened)
- [How Rune becomes Logical English](#how-rune-becomes-logical-english)
- [Running a report's tests](#running-a-reports-tests)
- [Writing a report back as Rune, and running it](#writing-a-report-back-as-rune-and-running-it)
- [How well it works](#how-well-it-works)
- [What is left](#what-is-left)
- [The examples](#the-examples)
- [See also](#see-also)

## The words used here

- A **namespace** is a chapter of a Rune model. It has a name, for example
  `drr.regulation.cftc.rewrite.trade` for the rules of the American trade report. It
  contains the definitions written in it.
- A **reporting rule** calculates one value of a report from a trade. For example, a
  reporting rule tells whether the trade was cleared.
- A **report** names the fields that a regulator asks for. For each field, the report
  names the reporting rule that gives the value of the field.
- An **instruction** is the data from which the system calculates a report. The
  instruction contains a trade with the event that occurred to it, the parties, who
  reports, and to whom.
- A **twin** is the Logical English program that a translation writes. A twin must
  give the same answers as the original.
- A **scenario** is a set of facts. You can ask the questions of a program about a
  scenario. Here, each scenario is one instruction.

## What happens when a Rune file is opened

A Rune file is never alone. It uses the types, the lists of values and the functions
of the namespaces that it imports. Thus the translator reads the file together with a
full model: DRR 7.14.0 and the CDM 6.29 that DRR uses. ISDA publishes these models
on its public software repository. The file that you open goes on top of the model.
A file with the same name as a file of DRR replaces that file. Each other file is
added to the model.

The result is a program in three files. Each file includes the next file. Thus the
editor shows you the file that you opened, and keeps the other files one step away:

| File | What it holds |
|---|---|
| `<report>.le` | the namespace that you opened: its reporting rules, and one rule for each field of the report |
| `<report>_drr.le` | the rules from the other namespaces of DRR that the namespace uses (the definitions that most regulators share) |
| `<report>_cdm.le` | the functions of the CDM that those rules use, and the sentences that describe a trade |

All three files are Logical English. When the editor explains an answer, the
explanation goes from the field of the report down to the facts of the trade. It
goes through each rule between them.

The program of a file of DRR without changes was translated before. Thus it opens
immediately. The first question to the program, or the first test run, waits while
the server reads the full program. For a trade report with one file of scenarios,
this takes about three minutes. After that, the server keeps the program, and the
answers come in seconds.

The translator translates a changed file, or a file of your own, when you open it.
For a full report, this takes some minutes. A file without a report (only functions,
as in the CDM) opens as the program of its functions.

Next to the program are the **scenarios of DRR's own tests**. There is one file for
each group of products (rates, credit, foreign exchange, ...). Each scenario is an
instruction of the test pack of DRR, with the values that the report of DRR gives
for it. The system checks these scenarios in the same way as each other Logical
English test.

## How Rune becomes Logical English

| In Rune | In Logical English |
|---|---|
| a reporting rule | a rule that concludes a sentence: `the FCA confirmed of *a transaction report instruction* is *a value*` |
| the field of a report and its rule | a rule `the FCA UKEMIR Trade field "2.29 Confirmed" of an instruction is a value if ...`. The rule cites the passage of the regulation (*as stated in*, with its words after *confer*) and the reading of the industry (*according to*) |
| `filter`, `extract` | a list of the elements that pass a test: `a list L is the list of each V such that ...` |
| a value that can be missing | *the value or nothing of* the list: the value, or nothing when there is no value |
| `if ... then ... else` | one rule for each branch. The second rule has *it is not the case that* the test of the first rule |
| an attribute of an object, `trade -> product` | a sentence: `the product of the trade is a product` |
| a function | a rule with a place for each of its inputs |
| a test that the CDM names, `Qualify_AssetClass_Credit` | a sentence: `*an economic terms* qualifies as asset class credit` |
| a list of named values (an enumeration) | the name of the value in quotation marks: `"NonFinancial"` |

The program keeps a definition that the translator cannot write yet as a **residue**
block. A residue block is a comment that contains the Rune and the reason. The block
is marked as work to do.

Core Logical English has no form for some conditions. An example is a choice between
alternatives that starts with a negation or a count. The translator writes such a
condition as a small separate rule:
`a value meets condition 2 of the clearing threshold`. Thus the program needs
nothing more than Logical English itself.

## Running a report's tests

Do these steps:

1. Open one of the scenario files next to the program (`rates.le`, ...).
2. Select **Misc ▸ Run the Program's Tests**.

For each field, each scenario expects the value that the report of DRR gives. You can
also ask one question about one scenario in the **Query** panel. The answer shows how
the system calculates the field, rule by rule. It also shows the passages of the
regulation that each rule cites.

## Writing a report back as Rune, and running it

Do these steps:

1. Change a rule in the file of the report.
2. Select **File ▸ Export to Another System… ▸ Rune**.

The export does these actions:

1. It finds the rules that you changed. (The program remembers each rule as it was
   at the time of the translation.)
2. It writes each changed rule as Rune again, with its name followed by `LE`.
3. It writes the type of the report again, as a new type. The new type is different
   from the type of DRR only in the fields that use a changed rule. (Rune attaches a
   rule to a field in the type of the report.) It also writes the report with that
   type. Each rule that you did not change stays the rule of DRR, as ISDA wrote it.
4. When the server has the engine of DRR, the export runs the result on that engine.
   The checker of Rune reads the file. The generator of Rune changes the file into a
   program. The program of DRR calculates the report of each instruction of the test
   pack of DRR. The notes tell how many reports are exactly the same as the reports
   of DRR. For the other reports, the notes tell which fields are different.

The first export of a session takes some minutes, while the engine of DRR starts.
Each export after the first takes about one minute.

The export refuses a change that it cannot write back, and gives the reason. Then
the export writes nothing. The export refuses these changes:

- a change to a rule of the lower files,
- a change to the rule of a field itself (change the rule that it reads instead),
- a condition that the translator cannot read back yet.

**A public place to run it.** The free web editor of Rune can also read the exported
file. This editor is the Community edition of Rosetta (REGnosys,
[ui.rosetta-technology.io](https://ui.rosetta-technology.io)). Do these steps:

1. Make an account.
2. Open a model.
3. Paste the file into the model.

The notes of the export contain the link.

## How well it works

The translator translated each of the 28 reports of DRR. Each translation received
each instruction of the test pack of DRR. The answers of each translation were
compared, field by field, with the reports that the program of DRR gives.

| Report | Instructions | Field values that agree |
|---|---|---|
| CFTC Part 45 (United States) | 197 | 11,910 of 11,960 (99.6%) |
| CFTC Part 43 (United States, public) | 197 | 8,127 of 8,163 (99.6%) |
| SEC trade (United States) | 178 | 8,858 of 8,888 (99.7%) |
| SEC PPD (United States) | 178 | 6,838 of 6,855 (99.8%) |
| CSA trade (Canada) | 219 | 12,084 of 12,163 (99.4%) |
| CSA PPD (Canada) | 219 | 8,538 of 8,600 (99.3%) |
| ESMA EMIR trade (European Union) | 189 | 9,601 of 9,675 (99.2%) |
| FCA UK EMIR trade (United Kingdom) | 156 | 8,027 of 8,093 (99.2%) |
| ASIC trade (Australia) | 178 | 6,148 of 6,193 (99.3%) |
| MAS trade (Singapore) | 178 | 6,654 of 6,707 (99.2%) |
| HKMA trade (Hong Kong) | 178 | 8,406 of 8,619 (97.5%) |
| JFSA trade (Japan) | 178 | 6,734 of 6,963 (96.7%) |
| The 16 margin and valuation reports of the eight regulators | 28 | 625 of 625 (100%) |

In total, 102,550 of 103,504 field values agree (99.1%). A value that does not agree
is of one of a small number of kinds:

- A value that the program of DRR calculates in Java, not in Rune (for example, a
  schedule of prices). Java is a programming language. The translation marks such a
  value as work to do.
- Some shapes of rule that the translation reads differently. An example: two objects
  of a trade can have the same contents. DRR counts them as one value. The
  translation compares their names, and thus counts two values. This difference is
  most of the difference in the Japanese report (its technical record identifier).

The CDM has a product qualification, which tells what a product is. The translation
of the product qualification gives the same answer as the program of the CDM for all
22,000 questions. (The questions are 100 tests of what a product is, on each of the
220 products of the test pack of DRR.)

The way back was also measured. Each rule of the file of each report was written back
as Rune. The result was run on the engine of DRR, over the test pack of DRR. The
files of the 28 reports contain 1,280 rules. Of these rules, 1,137 (89%) were written
back. The engine of DRR then calculated 2,249 reports. Of these reports, 2,197
(97.7%) are exactly the same as the reports of DRR. Twenty-two of the 28 reports are
exactly the same as the reports of DRR for each instruction. The other reports are
different in a small number of fields:

- the Canadian reports, in a quantity whose limit has more digits than Logical
  English keeps (Logical English rounds the limit),
- two reports of Hong Kong and Singapore, where the translation itself is different
  from DRR.

## What is left

- The way back reads the shapes of rule that the translator writes. It also reads the
  rules that you write in the same words. Some rules of each report use a shape that
  the way back cannot read yet. You can translate, run and explain such a rule in
  Logical English, but the export refuses a change to it. Of the 1,280 rules of the
  files of the 28 reports, 143 rules are in that case. Most of them are in that case
  because a condition uses a value that no earlier condition gives.
- Logical English rounds a number with more than fifteen digits (for example, the
  limit 99999999999999999999.99999 of DRR). The export writes the number back
  rounded.
- Some values change during the life of a trade. DRR reports each of these events
  separately. Thus these values did not need Logical English for LPS: each report
  reads one instruction at a time.
- DRR belongs to ISDA and has the ISDA DRR License. This licence lets you use DRR
  without changes. Thus Logical English does not publish the translations of the
  reports of DRR. The CDM is open, thus the translations of the CDM can be published.

## The examples

Logical Contracts keeps the translations of the 28 reports of DRR privately, because
of the licence of DRR. These translations open when you open a DRR file on a server
that has them.

The translation of the product qualification of the CDM is
`cdm_product_qualification`. It tells what a product is, for example an interest rate
swap of a fixed rate against a floating rate. This translation is checked against the
program of the CDM, on the products of the test pack of DRR.

## See also

- [Other systems: importing and exporting](index.md)
- [Catala and Logical English](catala.md), a different language for rules as
  programs
- [The Logical English reference](../reference/language.md), section 14 about
  included resources

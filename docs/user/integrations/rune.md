# Rune and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-07)*

**Rune** is a language for writing financial rules as programs that a
computer runs: what a trade is, what happens to it over its life, and what
a bank must report about it to its regulators. It is free software, kept by
FINOS, the Fintech Open Source Foundation. Two large models are written in
it:

- the **Common Domain Model** (the CDM), a description of trades and of the
  events in their lives (a new trade, an amendment, a termination), shared
  by banks and other firms so that they describe a trade the same way;
- **Digital Regulatory Reporting** (DRR), published by ISDA, the
  International Swaps and Derivatives Association: for 28 reports that
  nine regulators in eight jurisdictions ask for, the rules that compute each
  field of the report from a trade described in the CDM.

Logical English (LE) reads Rune, and writes it back. **File ▸ Open…** (or
**File ▸ Import from Another System…**) takes a `.rosetta` file, the files
Rune programs are kept in, or a zip file of several. The result is a
Logical English program: each rule a sentence, each field of a report a rule
that cites the passage of the regulation it implements. **File ▸ Export to
Another System… ▸ Rune** writes back the rules you changed, and runs the
result on DRR's own engine. The translator is part of the Logical English
Translators, so only installations that have them offer it.

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

- A **namespace** is a chapter of a Rune model: a name such as
  `drr.regulation.cftc.rewrite.trade` for the rules of the American trade
  report, with the definitions written in it.
- A **reporting rule** computes one value of a report from a trade, for
  example whether the trade was cleared.
- A **report** names the fields a regulator asks for, and for each field
  the reporting rule that fills it in.
- An **instruction** is what a report is computed from: a trade with the
  event that happened to it, the parties, who reports and to whom.
- A **twin** is the Logical English program that a translation writes: it
  should give the same answers as the original.
- A **scenario** is a set of facts that a program's questions can be asked
  about; here, each scenario is one instruction.

## What happens when a Rune file is opened

A Rune file is never alone: it uses the types, the lists of values and the
functions of the namespaces it imports. The translator therefore reads the
file together with a whole model: DRR 7.14.0 and the CDM 6.29 it is built
on, which ISDA publishes on its public software repository. The file you
open is laid over the model: a file with the same name as one of DRR's
takes its place, and any other file is added to it.

What opens is a program in three files, each including the next, so that
the editor shows you the file you opened and keeps the rest one step away:

| File | What it holds |
|---|---|
| `<report>.le` | the namespace you opened: its reporting rules, and one rule per field of the report |
| `<report>_drr.le` | the rules of DRR's other namespaces that it uses (the definitions most regulators share) |
| `<report>_cdm.le` | the functions of the CDM that those use, and the sentences that describe a trade |

All three are Logical English. When the editor explains an answer, the
explanation goes from the field of the report down to the facts of the
trade, through every rule in between.

When the file is one of DRR's own, unchanged, the program was translated
beforehand and opens at once. The first question asked of it, or the first
test run, waits for the server to read the whole program: about three
minutes for a trade report with one file of scenarios. After that the
server keeps the program, and answers come in seconds. A changed file, or a file of your own, is
translated when you open it, which takes a few minutes for a whole report.
A file without a report (only functions, as in the CDM) opens as the
program of its functions.

Beside the program are the **scenarios of DRR's own tests**, one file per
group of products (rates, credit, foreign exchange, ...): each instruction
of DRR's test pack, with the values that DRR's report gives for it. They are
checked as any Logical English test is.

## How Rune becomes Logical English

| In Rune | In Logical English |
|---|---|
| a reporting rule | a rule concluding a sentence: `the FCA confirmed of *a transaction report instruction* is *a value*` |
| the field of a report and its rule | a rule `the FCA UKEMIR Trade field "2.29 Confirmed" of an instruction is a value if ...`, citing the regulation's passage (*as stated in*, with its words after *confer*) and the industry's reading of it (*according to*) |
| `filter`, `extract` | a list of the elements that pass a test: `a list L is the list of each V such that ...` |
| a value that may be missing | *the value or nothing of* the list: the value, or nothing when there is none |
| `if ... then ... else` | one rule for each branch, the second under *it is not the case that* the first's test |
| an attribute of an object, `trade -> product` | a sentence: `the product of the trade is a product` |
| a function | a rule with a place for each of its inputs |
| a test the CDM names, `Qualify_AssetClass_Credit` | a sentence: `*an economic terms* qualifies as asset class credit` |
| a list of named values (an enumeration) | the value's name in quotation marks: `"NonFinancial"` |

A definition the translator cannot write yet is kept as a **residue** block:
a comment that carries the Rune and the reason, marked as work to do. A
condition that core Logical English has no form for (a choice between
alternatives that opens with a negation or a count) is written as a small
rule of its own, `a value meets condition 2 of the clearing threshold`, so
that the program needs nothing beyond Logical English itself.

## Running a report's tests

Open one of the scenario files beside the program (`rates.le`, ...) and use
**Misc ▸ Run the Program's Tests**. Each scenario expects, for each field,
the value DRR's report gives. Asking one question about one scenario (the
**Query** panel) shows how the field is computed, rule by rule, with the
passages of the regulation each rule cites.

## Writing a report back as Rune, and running it

Change a rule of the report's own file, then use **File ▸ Export to Another
System… ▸ Rune**. The export:

1. finds the rules you changed (the program remembers how each rule was
   when it was translated);
2. writes each of them as Rune again, under its name with `LE` after it;
3. writes the report's type again, as a new type that differs from DRR's
   only in the fields that use a changed rule (Rune attaches a rule to a
   field on the report's type), and the report with that type. Every rule
   you did not change stays DRR's own, as ISDA wrote it;
4. when the server has DRR's engine, runs the result there: Rune's own
   checker reads the file, Rune's own generator turns it into a program, and
   DRR's program computes the report of every instruction of DRR's test
   pack. The notes say how many reports came out exactly as DRR's, and which
   fields differ in the others.

The first export of a session takes a few minutes, while DRR's engine
starts; each export after takes about a minute.

A change the export cannot write back is refused with the reason, and
nothing is written: a change to a rule of the lower files, a change to a
field's own rule (change the rule it reads instead), or a condition the
translator does not read back yet.

**A public place to run it.** Rune's free web editor, the Community edition
of Rosetta (REGnosys, [ui.rosetta-technology.io](https://ui.rosetta-technology.io)),
reads the exported file too: create an account, open a model, and paste
the file in. The export's notes carry the link.

## How well it works

Each of DRR's 28 reports was translated, and each translation was given
every instruction of DRR's test pack. Its answers were compared with the
reports DRR's own program gives, field by field.

| Report | Instructions | Field values that agree |
|---|---|---|
| CFTC Part 45 (United States) | 195 | 11,783 of 11,833 (99.6%) |
| CFTC Part 43 (United States, public) | 195 | 8,040 of 8,076 (99.6%) |
| SEC trade (United States) | 176 | 8,747 of 8,777 (99.7%) |
| SEC PPD (United States) | 176 | 6,751 of 6,768 (99.7%) |
| CSA trade (Canada) | 217 | 11,962 of 12,039 (99.4%) |
| CSA PPD (Canada) | 217 | 8,451 of 8,511 (99.3%) |
| ESMA EMIR trade (European Union) | 187 | 9,466 of 9,567 (98.9%) |
| FCA UK EMIR trade (United Kingdom) | 154 | 7,895 of 7,985 (98.9%) |
| ASIC trade (Australia) | 176 | 6,050 of 6,118 (98.9%) |
| MAS trade (Singapore) | 176 | 6,556 of 6,631 (98.9%) |
| HKMA trade (Hong Kong) | 176 | 8,288 of 8,522 (97.3%) |
| JFSA trade (Japan) | 176 | 6,628 of 6,878 (96.4%) |
| The 16 margin and valuation reports of the eight regulators | 28 | 625 of 625 (100%) |

In all, 101,242 of 102,330 field values agree (98.9%). A value that does
not agree is one of a few kinds: a value DRR's program computes in Java
rather than in Rune (a schedule of prices, for example), which the
translation marks as work to do; and a few shapes of rule the translation
reads differently. One of them: when two objects of a trade hold the same
contents, DRR counts them as one value, and the translation, which compares
their names, counts two. It is most of the difference in the Japanese
report (its technical record identifier).

The translation of the CDM's product qualification gives the same answer
as the CDM's own program for all 22,000 questions asked (100 tests
of what a product is, on each of the 220 products of DRR's test pack).

The way back was measured too. Every rule of each report's own file was
written back as Rune, and the result run on DRR's engine over DRR's test
pack. Of the 1,280 rules of the 28 reports' files, 1,137 (89%) were written
back. Of the 2,249 reports DRR's engine then computed, 2,197 (97.7%) are
exactly DRR's own. Twenty-two of the 28 reports are exactly DRR's on every
instruction. The others differ in a few fields: the Canadian reports in a
quantity whose limit has more digits than Logical English keeps (it is
rounded), and two reports of Hong Kong and Singapore where the translation
itself differs from DRR.

## What is left

- The way back reads the shapes of rule the translator writes, and the
  ones you write in the same words. Some rules of each report use a shape
  it does not read back yet; such a rule can be translated, run and
  explained in Logical English, but a change to it is refused on export.
  Of the 1,280 rules of the 28 reports' own files, 143 are in that case,
  most of them because a condition uses a value that no earlier condition
  gives.
- A number with more than fifteen digits (DRR's limit
  99999999999999999999.99999, for example) is rounded by Logical English,
  and is written back rounded.
- Values that change over the life of a trade (the events DRR reports are
  each reported on their own) have not needed Logical English for LPS:
  every report reads one instruction at a time.
- DRR is ISDA's, under the ISDA DRR License, which allows its use without
  changes. The translations of DRR's reports are therefore not published
  with Logical English; the translations of the CDM, which is open, can be.

## The examples

The translations of DRR's 28 reports are kept privately by Logical
Contracts, because of DRR's licence; they open when a DRR file is opened
on a server that has them. The translation of the CDM's product
qualification (`cdm_product_qualification`: what a product is, for example
an interest rate swap of a fixed rate against a floating one) is checked
against the CDM's own program on the products of DRR's test pack.

## See also

- [Other systems: importing and exporting](index.md)
- [Catala and Logical English](catala.md), another language for rules as
  programs
- [The Logical English reference](../reference/language.md), section 14 on
  included resources

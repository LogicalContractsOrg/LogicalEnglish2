# Axiom RuleSpec and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-05)*

The Axiom Foundation publishes United States law as programs. Each program
covers one provision of a statute, a regulation or an agency's policy, such
as section 2017(a) of title 7 of the United States Code, which sets the
monthly amount of food assistance (SNAP, the Supplemental Nutrition
Assistance Program). The programs are written in a format called
**RuleSpec**: a text file in YAML, a common format for structured data, with
a second file beside it that holds the provision's tests. Axiom's
collection, `rulespec-us`, holds about 5,000 such programs, and Axiom's own
engine runs them.

Logical English (LE) reads RuleSpec, and writes it. **File ▸ Open…** (or
**File ▸ Import from Another System…**) takes a RuleSpec file, alone or in a
zip file with the files it uses. The result is an ordinary Logical English
program, with the provision's tests as scenarios. **File ▸ Export to Another
System…** writes a Logical English program as a RuleSpec file, with the
program's scenarios as its tests. The translator is part of the Logical
English Translators, so only installations that have them, such as the
hosted service, offer it. The translations of Axiom's programs for food
assistance, two tax credits and Supplemental Security Income, called
*twins*, come with every installation.

## Contents

- [RuleSpec in brief: a small example](#rulespec-in-brief-a-small-example)
- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
- [How RuleSpec maps to Logical English](#how-rulespec-maps-to-logical-english)
- [Writing a program back as RuleSpec](#writing-a-program-back-as-rulespec)
- [What is not supported yet](#what-is-not-supported-yet)
- [See also](#see-also)

## RuleSpec in brief: a small example

A RuleSpec file is a list of rules. A **parameter** is a number the law
states. A **derived** rule computes a value, or decides a yes-or-no
question (RuleSpec calls such a question a *judgment*), from a formula. A
name that no rule defines is an **input**: the facts of the case give it.

```yaml
format: rulespec/v1
rules:
  - name: snap_minimum_allotment_rate
    kind: parameter
    dtype: Rate
    source: 7 USC 2017(a), "8 percent"
    versions:
      - effective_from: '2008-10-01'
        formula: 0.08
  - name: snap_regular_month_allotment
    kind: derived
    entity: Household
    dtype: Money
    versions:
      - effective_from: '2008-10-01'
        formula: |-
          if snap_eligible:
              max(snap_allotment_before_minimum, snap_minimum_monthly_allotment)
          else:
              0
```

Its twin in Logical English says the same in sentences. Each name becomes a
**template**, the pattern of a sentence with places for its values; each
rule cites the provision it comes from:

```
the snap minimum allotment rate is 0.08, as stated in "7 USC 2017(a)", confer "8 percent".

rule snap_regular_month_allotment with provenance "7 USC 2017(a)":
the snap regular month allotment of a household is an amount N if
    the household is snap eligible
    and the snap allotment before minimum of the household is an amount M
    and the snap minimum monthly allotment of the household is an amount K
    and the maximum of M and K is N
    otherwise the household is a household
    and N = 0.
```

A test of the RuleSpec file becomes a **scenario**, a set of facts about one
case, with the answers the test expects:

```
scenario household_not_certified_eligible_receives_no_regular_month_allotment is,
        as stated in "sources/us/statutes/7/2017/a.test.yaml" at case 4:
    household_1 is a household.
    the household size of household_1 is 1.
    ...
    q_snap_regular_month_allotment expects answers ["the snap regular month allotment of household_1 is 0"].
```

## At a glance

| | |
|---|---|
| Reads | a RuleSpec file (`.yaml` starting `format: rulespec/v1`), alone or in a zip with the files it uses (`imports`) |
| Writes | one Logical English program: the file, and every file it uses, each provision under a comment naming it |
| Tests | the companion `.test.yaml`, when it is there: one scenario per test case |
| Way back | **File ▸ Export to Another System… ▸ Axiom RuleSpec**: one RuleSpec file, with the scenarios as its tests |
| Checked against | Axiom's own engine, `axiom-rules-engine`: on Axiom's 39 programs that come as twins, the twins give all 473 answers the tests expect, and 37 of the 39 twins, written back as RuleSpec, pass all their tests on Axiom's engine |

## How to use it

1. Choose **File ▸ Import from Another System…** and pick a RuleSpec file,
   or a zip file of a provision and the provisions it uses (as laid out in
   `rulespec-us`: `us/statutes/7/2017/a.yaml`, …).
2. The program opens. Its notes say how many provisions it holds, and how
   many of the tests pass. A provision the file uses but the upload does not
   hold is named in the notes: the values it would have computed become
   facts that the scenarios state.
3. Choose a scenario and a query, and click **Query**. Click an answer to
   see why: each step names the provision, and **View Original Text** shows
   the RuleSpec file, kept in the program's `sources/` folder.

The twins of Axiom's programs are among the examples, under
`migration/rulespec/`: `snap/` (food assistance), `ctc/` (the Child Tax
Credit), `eitc/` (the Earned Income Tax Credit) and `ssi/` (Supplemental
Security Income). Start with `snap/us_statutes_7_2017_a.le`, section 2017(a)
with the four provisions it uses.

## How RuleSpec maps to Logical English

| RuleSpec | Logical English |
|---|---|
| a parameter | a fact, citing the provision and the words it quotes (`confer "8 percent"`) |
| a table (`indexed_by`, `values`) | one fact per row: `the snap maximum allotment table for 3 is 785` |
| a derived value | a rule concluding `the <name> of *a household* is *an amount*`; the words come from the rule's name |
| a judgment | a rule concluding a sentence: `*a household* is snap eligible` |
| an input | a template whose facts the scenario states; a yes-or-no input is a sentence, stated when it is true |
| the names a formula reads | the rule's conditions, one for each name |
| `if … else …`, `match` | an `otherwise` cascade: the first branch whose conditions hold gives the value |
| `and`, `or`, `not` | the conditions; each alternative of an `or` is a rule of its own |
| `len`, `sum`, `count_where`, `sum_where` over a relation | `the count of each …`, `the sum of each …` |
| dated versions | each version a rule that holds from its start date, read against `the calculation date` the scenario states |

Two differences of meaning are worth knowing:

- **A missing fact.** RuleSpec calls a yes-or-no question *undetermined*
  when the case does not give a fact it needs. Logical English treats a
  sentence that is not stated as false. A twin's scenarios state every fact
  the tests give, so the answers agree; a case of your own must state its
  facts too.
- **Numbers.** Axiom's engine computes money with exact decimals. Logical
  English computes with ordinary computer numbers, which are very slightly
  inexact (386.5 × 0.3 is 115.94999999999999 for a computer). An answer
  shows such a number as 115.95, and a test compares numbers as numbers.
  The library `lib/rounding` rounds a value at a number of decimals, exactly,
  when a rule needs it.

## Writing a program back as RuleSpec

**File ▸ Export to Another System… ▸ Axiom RuleSpec** writes the program as
one RuleSpec file. The file's tests (the scenarios, with the answers they
expect) follow it as a block of comments; save them as the file's
`.test.yaml` to run them with Axiom's engine. The export refuses a program
that RuleSpec cannot express, and lists what it refused and why:

- a value concluded only when conditions hold, with no `otherwise` for the
  other cases (RuleSpec has no "no value");
- a rule that reads a value of something other than its subject, except
  through a count or a sum over a relation;
- several rules concluding one value that are not dated versions of it;
- a template with three places or more.

## What is not supported yet

- **Compositions.** Axiom's composed programs (`module.kind: composition`)
  are not read.
- **Relations computed by a rule** (`derived_relation`), the date functions
  (`days_between`, `date_add_days`, …) and the sums over periods are kept in
  the program as untranslated blocks, marked for translation by hand or by
  the Contract Assistant.
- **Rounding of a money value** (`rounding:`) is noted as an approximation
  in the ledger; it occurs in 6 rules of the whole collection, none among
  the twins.

## See also

- [Other systems: importing and exporting](index.md)
- Axiom Foundation: https://axiom.org, and its programs:
  https://github.com/TheAxiomFoundation/rulespec-us (CC-BY-4.0)
- The format: https://github.com/TheAxiomFoundation/axiom-rules-engine/blob/main/docs/rulespec-format.md

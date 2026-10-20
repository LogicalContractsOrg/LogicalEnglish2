# Axiom RuleSpec and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-05)*

The Axiom Foundation publishes United States law as programs. Each program
covers one provision of a statute, a regulation or the policy of an agency. An
example is section 2017(a) of title 7 of the United States Code. That section
sets the monthly amount of food assistance (SNAP, the Supplemental Nutrition
Assistance Program). The programs are in a format with the name **RuleSpec**.
A RuleSpec program is a text file in YAML. YAML is a common format for
structured data. A second file is adjacent to the program file, and that file
holds the tests of the provision. The collection of Axiom, `rulespec-us`, holds
approximately 5,000 of these programs. The engine of Axiom runs them.

Logical English (LE) reads RuleSpec, and LE also writes RuleSpec. **File ▸
Open…** (or **File ▸ Import from Another System…**) accepts a RuleSpec file.
The file can be alone, or in a zip file with the files that it uses. The
result is an ordinary Logical English program. The tests of the provision
become scenarios in that program. **File ▸ Export to Another System…** writes
a Logical English program as a RuleSpec file. The scenarios of the program
become the tests of the file. The translator is a part of the Logical English
Translators. Thus only the installations that have the Translators give the
translator, for example the hosted service. Every installation has the
translations of the Axiom programs for food assistance, two tax credits and
Supplemental Security Income. These translations have the name *twins*.

## Contents

- [RuleSpec in brief: a small example](#rulespec-in-brief-a-small-example)
- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
- [How RuleSpec maps to Logical English](#how-rulespec-maps-to-logical-english)
- [Writing a program back as RuleSpec](#writing-a-program-back-as-rulespec)
- [What is not supported yet](#what-is-not-supported-yet)
- [See also](#see-also)

## RuleSpec in brief: a small example

A RuleSpec file is a list of rules. A **parameter** is a number that the law
states. A **derived** rule calculates a value from a formula. A derived rule
can also decide a yes-or-no question from a formula. RuleSpec calls this type
of question a *judgment*. A name that no rule defines is an **input**. The
facts of the case give the value of an input.

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

The twin in Logical English says the same thing in sentences. Each name
becomes a **template**. A template is the pattern of a sentence, with places
for its values. Each rule cites the provision that it comes from:

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

A test of the RuleSpec file becomes a **scenario**. A scenario is a set of
facts about one case, with the answers that the test expects:

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
| Reads | a RuleSpec file (`.yaml` that starts with `format: rulespec/v1`), alone or in a zip file with the files that it uses (`imports`) |
| Writes | one Logical English program: the file and each file that it uses, each provision below a comment that gives its name |
| Tests | the companion `.test.yaml`, if it is there: one scenario for each test case |
| Way back | **File ▸ Export to Another System… ▸ Axiom RuleSpec**: one RuleSpec file, with the scenarios as its tests |
| Checked against | the engine of Axiom, `axiom-rules-engine`. Axiom has 39 programs that come as twins. The twins give all 473 answers that the tests expect. LE wrote the 39 twins back as RuleSpec, and 37 of them pass all their tests on the engine of Axiom |

## How to use it

Do these steps:

1. Select **File ▸ Import from Another System…**.
2. Select a RuleSpec file, or a zip file of a provision and the provisions that
   it uses. The zip file has the layout of `rulespec-us` (`us/statutes/7/2017/a.yaml`, …).
3. Read the notes of the program that opens. The notes tell how many provisions
   the program holds, and how many of the tests pass.
4. Select a scenario and a query.
5. Click **Query**.
6. Click an answer to see the reason for that answer.
7. Click **View Original Text** to see the RuleSpec file.

Each step of an explanation gives the name of its provision. The program keeps
the RuleSpec file in its `sources/` folder.

> Note: possibly the file uses a provision that the upload does not hold. The
> notes give the name of that provision. The values that the provision
> calculates become facts that the scenarios state.

The twins of the Axiom programs are in the examples, in `migration/rulespec/`.
The folders are `snap/` (food assistance), `ctc/` (the Child Tax Credit),
`eitc/` (the Earned Income Tax Credit) and `ssi/` (Supplemental Security
Income). Start with `snap/us_statutes_7_2017_a.le`. That program is section
2017(a), with the four provisions that it uses.

## How RuleSpec maps to Logical English

| RuleSpec | Logical English |
|---|---|
| a parameter | a fact that cites the provision and the words that the provision quotes (`confer "8 percent"`) |
| a table (`indexed_by`, `values`) | one fact for each row: `the snap maximum allotment table for 3 is 785` |
| a derived value | a rule with the conclusion `the <name> of *a household* is *an amount*`; the words come from the name of the rule |
| a judgment | a rule with a sentence as its conclusion: `*a household* is snap eligible` |
| an input | a template that has its facts in the scenario; a yes-or-no input is a sentence, which the scenario states when it is true |
| the names that a formula reads | the conditions of the rule, one condition for each name |
| `if … else …`, `match` | an `otherwise` cascade: the first branch with conditions that are true gives the value |
| `and`, `or`, `not` | the conditions; each alternative of an `or` is a separate rule |
| `len`, `sum`, `count_where`, `sum_where` over a relation | `the count of each …`, `the sum of each …` |
| dated versions | each version is a rule that is true from its start date; LE compares that date with `the calculation date` that the scenario states |

Two differences of meaning are important:

- **A missing fact.** RuleSpec calls a yes-or-no question *undetermined* when
  the case does not give a necessary fact. Logical English thinks that a
  sentence that is not stated is false. The scenarios of a twin state all the
  facts that the tests give, thus the answers agree. A case that you write must
  also state its facts.
- **Numbers.** The engine of Axiom calculates money with exact decimals.
  Logical English calculates with ordinary computer numbers. These numbers are
  very slightly inexact: for a computer, 386.5 × 0.3 is 115.94999999999999. An
  answer shows this number as 115.95. A test compares numbers as numbers. When
  a rule needs exact rounding, the library `lib/rounding` rounds a value
  exactly, at a number of decimals.

## Writing a program back as RuleSpec

**File ▸ Export to Another System… ▸ Axiom RuleSpec** writes the program as
one RuleSpec file. The tests of the file come after it, as a block of
comments. The tests are the scenarios, with the answers that they expect. To
run the tests with the engine of Axiom, save them as the `.test.yaml` of the
file. The export refuses a program that RuleSpec cannot express. The export
gives a list of the parts that it refused, and the reason for each part. It
refuses these parts:

- a value that a rule concludes only when conditions are true, with no
  `otherwise` for the other cases (RuleSpec has no "no value");
- a rule that reads a value of a thing that is not its subject, but a count or
  a sum over a relation is permitted;
- more than one rule with the same value as conclusion, when the rules are not
  dated versions of that value;
- a template with three places or more.

## What is not supported yet

- **Compositions.** LE does not read the composed programs of Axiom
  (`module.kind: composition`).
- **Relations that a rule calculates** (`derived_relation`), the date functions
  (`days_between`, `date_add_days`, …) and the sums over periods. LE keeps them
  in the program as blocks that it did not translate. The blocks have a mark:
  a person or the Contract Assistant must translate them.
- **Rounding of a money value** (`rounding:`). The ledger records this rounding
  as an approximation. It occurs in 6 rules of the full collection, and in none
  of the twins.

## See also

- [Other systems: importing and exporting](index.md)
- Axiom Foundation: https://axiom.org, and its programs:
  https://github.com/TheAxiomFoundation/rulespec-us (CC-BY-4.0)
- The format: https://github.com/TheAxiomFoundation/axiom-rules-engine/blob/main/docs/rulespec-format.md

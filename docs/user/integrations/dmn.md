# DMN and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-26, the way back and the adapter added)*

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
the twins of the TCK, of examples of Dutch government rules (RONL), of
the Benefit Decision Toolkit of Philadelphia, and of the models that the
client examples of Kogito and Camunda call.

The translation also goes the other way. **File ▸ Export to Another
System… ▸ DMN** writes a Logical English program as a DMN 1.6 model, with its
scenarios as TCK test cases. And the **DMN adapter** lets the applications
that called a DMN engine (Kogito, KIE Server, Camunda 7, Camunda 8) call the
twin instead, without a change to their code.

## Contents

- [DMN in brief: a small example](#dmn-in-brief-a-small-example)
- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
- [How DMN maps to Logical English](#how-dmn-maps-to-logical-english)
- [Two differences of meaning](#two-differences-of-meaning)
- [What is not supported yet](#what-is-not-supported-yet)
- [The way back: from Logical English to DMN](#the-way-back-from-logical-english-to-dmn)
- [The DMN adapter](#the-dmn-adapter)
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
| Way back | **File ▸ Export to Another System… ▸ DMN**: a DMN 1.6 model, the scenarios as a TCK test file. Checked on Drools with the runner of the TCK: the 84 twins and examples of the check, 424 of 424 test cases |
| Adapter | the DMN adapter answers the callers of Kogito, KIE Server, Camunda 7 and Camunda 8 from the twins. Checked: 521 of 521 expected results of the four public collections, through the adapter |
| Checked against | the expected results of the TCK (compliance level 2: 138 of 138 test cases) and of the Benefit Decision Toolkit (195 of 195); for the models without tests, the answers of Apache KIE Drools 10.2.0 to generated cases (RONL: 346 of 346; the 196 models of the Omgevingswet's rules: 6,364 of 6,364); for the client examples, the answers of Drools and of Camunda's own engine (33 of 33) |

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
rules: social assistance, subsidies, permits), `bdt/` (the Benefit
Decision Toolkit of Code for Philly: Philadelphia tax relief) and
`clients/` (Traffic Violation, the model of Kogito's example, and Dinner
Decisions, the model of Camunda's example). Start with
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
| a decision service or a BKM of an imported model | a copy in the program, between two comments: `BEGIN of inlined logic` and `END of inlined logic`. The comments name the model that the copy comes from. You can move the copy to a file of its own, and include that file in each program that uses it |
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

On the TCK's compliance level 3, which tests FEEL function by function, the
twins give 1,745 of the 3,559 answers (49%). The answers that are not given are
mostly the parts above.

The names in an STTR model often end with letters such as `UR` and `CR`. The
modeller of the Omgevingswet uses them to identify the kind of rule: `UR`
(*uitvoeringsregel*) is a question, `CR` (*conclusieregel*) a conclusion.
The twin keeps them in the words of its templates.

## The way back: from Logical English to DMN

**File ▸ Export to Another System… ▸ DMN** writes the program of the front
tab as one DMN 1.6 model. A DMN engine can then run the rules of the
program. Do these steps:

1. Open a Logical English program, for example
   `regulatory/dmn_export/childcare_support`.
2. Select **File ▸ Export to Another System…**, then **DMN**.
3. Read the notes. Click **Save…** to keep the model as a `.dmn` file.
4. At the end of the file, a comment holds the scenarios as a TCK test file.
   Save that part as `<name>-test-01.xml` next to the model, without the
   first and the last line of the comment. The runner of the TCK and the
   test tools of most DMN engines run it.

What becomes what:

| Logical English | DMN |
|---|---|
| a value that no rule gives (`the age is *a number*`) | an input (`inputData`), with the type of its noun |
| a sentence without a place that no rule gives | an input of the type boolean: false when a scenario does not state it |
| a value that rules give | a decision. Its rules, in order, are one FEEL expression: `if <conditions of rule 1> then <value> else if … else null` |
| a sentence that rules give | a decision of the type boolean: true when a rule applies, false when no rule applies |
| a list (`the children include *a name*`) | a list input, or a decision whose value is a list |
| a decision table | a DMN decision table, with its hit policy (`unique match` UNIQUE, `first match` FIRST, `all matches` COLLECT). A decision that only reads the table is the table; else the table is a business knowledge model that the decision calls |
| a template with places that rules give (`the pmt of *a value* and … is *a value*`) | a business knowledge model: a function with parameters |
| `it is not the case that`, `or`, `otherwise`, comparisons, arithmetic | `not(…)`, `or`, `if … then … else`, comparisons, arithmetic |
| `the count`, `sum`, `min` or `max of each …` | `count(…)`, `sum(…)`, `min(…)`, `max(…)` |
| the templates of `lib/temporal`, `lib/rounding`, `lib/maths`, `lib/text` that FEEL has | FEEL's own functions: `date(…)`, `decimal(…)`, `years and months duration(…)`, `string join(…)`, … |
| a scenario | a test case of the TCK. A query that expects no answer expects null (false for a sentence, `[]` for a list) |

**A program about one kind of thing.** Many programs are about persons,
claims or applicants: `the household income of *an applicant* is *an
amount*`. A DMN model decides one case at a time, and has no such things.
When all the templates of a program are about one kind of thing, and each
rule is about one of them, the export makes that thing the case. The
template becomes `the household income of the applicant is *an amount*`.
Each thing of a scenario becomes a test case of its own (`two_families_ana`,
`two_families_ben`).

**What the export refuses.** The export writes nothing, and it lists the
problems, when the program has:

- relations between two things (`*a person* is the parent of *a person*`);
- templates that may be assumed (abduction);
- a table that a scenario changes;
- a value that a scenario states and that rules also give (in DMN a value is
  an input or a decision, not both);
- conditions that FEEL has no form for here.

**How the export was checked.** The script `dmn_roundtrip.pl` of the
translators exports a set of programs. It runs the test cases of each model
with the runner of the TCK on Apache KIE Drools 10.2. On 26 October 2026:
the 83 public DMN twins and the example `childcare_support`, 84 programs,
424 of 424 test cases pass. Of 99 other example programs written in Logical
English, 20 export, 38 of 38 test cases pass, and 79 are refused with the
reason.

## The DMN adapter

An application that called a DMN engine can call the Logical English server
instead. The server answers in the format of that engine, from the twin of
the model. The application changes the address of the engine, and nothing
else.

| The application called | It calls this server at |
|---|---|
| a Kogito or Apache KIE service (`POST /<model>`) | `POST /kogito/<model>`, `/kogito/<model>/dmnresult`, `/kogito/<model>/<decision service>`; `GET /kogito/<model>` gives the DMN file, `GET /kogito/q/openapi` the OpenAPI description |
| KIE Server (Red Hat Decision Manager, IBM BAMOE) | `POST /kie-server/services/rest/server/containers/<any>/dmn` (JSON), and the lists of containers and models |
| Camunda 7 | `POST /engine-rest/decision-definition/key/<decision id>/evaluate`, and the list of decision definitions |
| Camunda 8 (for example with `@camunda8/sdk`) | `POST /v2/decision-definitions/evaluation`; the sign-in at `/dmn-adapter/oauth/token` |

`/dmn-adapter` shows the list of the models that the server can answer.
Each answer is the answer of the twin. Add `?explain=true` to a Kogito
`dmnresult` call to get the reasons for each decision, as a tree of
sentences. The adapter uses the mapping file that the translator writes
next to each twin. Refer to [Adapters](adapters.md) for the mapping file and
for the sign-in.

The folder `migration/dmn/clients/` has the twins of the models that the
client examples of Kogito and Camunda call. With those twins, these clients
ran without a change, except for the address:

- the request of Kogito's own example (`curl … /Traffic%20Violation`);
- the Java client of KIE Server (`kie-server-client`, `DMNServicesClient`);
- the Node.js client of Camunda 8 (`@camunda8/sdk`, `evaluateDecision`),
  with no sign-in and with OAuth;
- calls to the REST API of Camunda 7.

Their 26 answers are the same as the answers of Drools and of Camunda's own
engine on the original models.

**Not available:** the XML formats of KIE Server, the processes,
deployments and history of Camunda, the rules that matched in a decision
table (Camunda 8 gets an empty list of matched rules), and the tracing
services of Kogito.

## See also

- [Other systems: importing and exporting](index.md)
- [Adapters: keep the callers of another system](adapters.md)
- DMN: https://www.omg.org/dmn/
- The DMN TCK: https://github.com/dmn-tck/tck (Apache-2.0)
- The Benefit Decision Toolkit: https://github.com/CodeForPhilly/benefit-decision-toolkit (MIT)
- RONL examples: https://github.com/sgort/linked-data-explorer (EUPL-1.2)

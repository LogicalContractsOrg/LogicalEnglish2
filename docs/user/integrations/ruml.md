# RUML and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-11-24)*

RUML (the Rulemapping Logic Format) is a file format for the decision logic
of laws. The Law as Code Institut of Berlin published version 1.0.0 on 15
November 2026. A RUML file is a JSON file. JSON is a common text format for
structured data. The file holds a **rulemap**: a tree of questions that
each have the answer yes or no. Each question is a **node**. The top node is
the **root**. A node can have **children**, and an **operator** tells how
the answers of the children give the answer of the node. A node without
children is a **leaf**. A leaf gets its answer from the data of a case, with
an expression in JSONata. JSONata is a small language for questions about
JSON data.

Logical English (LE) reads RUML. **File ▸ Open…** accepts a `.ruml` file. The
result is an ordinary Logical English program. The translation of a rulemap
has the name *twin*. LE also writes RUML: **File ▸ Export to Another System…
▸ RUML** writes a Logical English program as a rulemap. And LE can be a RUML
**evaluator**: it reads a rulemap and the data of a case, and it writes the
result in the result format of RUML (`.ruml-result`).

The translator is a part of the Logical English Translators. Thus only the
installations that have the Translators give the translator, for example the
hosted service. Every installation has the twins of the examples of the RUML
specification and of the fixtures of its conformance tests.

## Contents

- [RUML in brief: a small example](#ruml-in-brief-a-small-example)
- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
- [How RUML maps to Logical English](#how-ruml-maps-to-logical-english)
- [The three answers of RUML](#the-three-answers-of-ruml)
- [Logical English as a RUML evaluator](#logical-english-as-a-ruml-evaluator)
- [The way back: from Logical English to RUML](#the-way-back-from-logical-english-to-ruml)
- [What is not supported yet](#what-is-not-supported-yet)
- [See also](#see-also)

## RUML in brief: a small example

This rulemap of the specification decides a hardship benefit. The root node
has the operator AND: all its children must be true. Its first child,
"Härtefall liegt vor" (there is a case of hardship), is true when at least
two of three criteria are true. This rule is an expression on the node:
`$count($children[status = "true"]) >= 2`. The criteria are leaves. Each
leaf compares a value of the case, for example `dp_pflegegrad >= 3` (the
care level is at least 3).

The twin in Logical English says the same:

```
Härtefallleistung holds for a case if
    Härtefall liegt vor holds for the case
    and Wohnsitz im Land holds for the case.

Pflegegrad mindestens 3 holds for a case if
    the Pflegegrad of the case is a number N
    and N >= 3.
```

Each node is a sentence about a case. The words of the sentence are the
label of the node. The values of the case are facts of a scenario:

```
scenario one is:
    the Pflegegrad of case 1 is 4.
    the Monatlicher Eigenanteil of case 1 is 640.
    the Alleinlebend of case 1 is true.
    the Wohnsitz im Land of case 1 is true.
```

[Open this twin](/editor/index.html?example=migration/ruml/spec/4_14_haertefall/4_14_haertefall).

## At a glance

| | |
|---|---|
| Reads | `.ruml` (a rulemap), `.ruml-ext` (a file of additions to a rulemap), `.rumlc` (a zip archive with a rulemap, its additions and its texts), and a zip archive of these |
| Writes | `.ruml` (File ▸ Export), `.ruml-result` (the operation `evaluateForeign`) |
| Checked against | the 90 validation tests and the 103 evaluation tests of RUML; an evaluator written from the specification; a second, independent evaluator |
| Results | The 90 validation tests: 90 pass. The twins: 2,468 of 2,468 expected answers, in 80 rulemaps. The evaluator: 103 of 103 evaluation tests, in both modes, and each result file is valid. The way back: 80 of 80 twins come back with the same results (1,045 of 1,045 node results) |
| Twins | `examples/migration/ruml/spec/` (the examples of the specification) and `examples/migration/ruml/tests/` (the fixtures of the tests). Licence: Apache-2.0, Rulemapping Group GmbH |

## How to use it

To open a rulemap:

1. Sign in. The translator is a part of the Logical English Translators.
2. Select **File ▸ Open…**.
3. Select the `.ruml` file (or the `.rumlc` file, or a zip file with the
   rulemap and its additions).
4. Read the note that the editor shows. It gives the counts of the ledger
   and the results of the scenarios.
5. Select **File ▸ Show the Ledger…** to see how each element of the
   rulemap was translated.
6. Select **File ▸ Show the Original…** to see the rulemap and its texts.

The scenarios of an opened twin are cases that the translator makes from the
values that the expressions compare. An evaluator that was written from the
RUML specification gives their expected answers. This evaluator needs
Node.js on the server. Without Node.js, the twin has no scenarios.

When the rulemap was written by Logical English (File ▸ Export), the twin
also keeps the program that it was written from, under `sources/`.

## How RUML maps to Logical English

| RUML | Logical English |
|---|---|
| A node | A sentence with one place, the case: `<label> holds for *a case*` |
| AND | One rule. The children are its conditions |
| OR, XOR | One rule for each child. XOR of RUML is not the exclusive or of logic: it is an OR whose children cannot be true together |
| NOT_AND, NOT_OR, NOT_XOR | `it is not the case that` before a second sentence, `the conditions of <label> are met for *a case*` |
| DELEGATED, with `ruml:expression` | The expression as conditions. A count of the children that are true is a count of the sentences `child *a number* of <label> counts for *a case*` |
| A leaf with `ruml:query` | A rule. Its conditions are the expression |
| A leaf with no question, or with `ruml:ai-query` | A judged sentence: a person decides it. The answer says *(judgment needed)* |
| A data point | A sentence that only scenarios state: `the <name> of *a case* is *a number*` |
| A set (a group of data points, for example a person) | A relation between the case and each member: `*a case* has guarantor *a person*`, and a sentence for each field of the member |
| A computed data point | A rule that calculates the value |
| A text of a law (`ruml:text-reference`) | A document of the twin, under `sources/`. A law in Akoma Ntoso is written as XML and as text. The node that represents the text gets the text as provenance of its rule |
| `ruml:actions` | Not translated. The ledger lists each action |
| `ruml:tree-include` (a node of a different rulemap) | Not evaluated: the leaf is undefined, as the specification says for a rulemap that is not available |

A label keeps its words. The translator removes only the signs that a
sentence of Logical English cannot hold, for example brackets. It writes
`>` as `more than` and a word in capitals in small letters.

## The three answers of RUML

A node of RUML has three possible answers: `true`, `false` and `undefined`.
`undefined` means that the evaluation did not get an answer, for example
because a value of the case is missing. Logical English gives the same three
answers with its *unknowns*. An unknown is a sentence that an answer must
assume.

| RUML | The twin |
|---|---|
| true | LE proves the sentence of the node. LE does not prove its negation |
| false | LE does not prove the sentence |
| undefined | LE proves the sentence and its negation, each only with unknowns. The unknowns tell which leaf waits for which value |

For example, when the age of the case is missing, the leaf "Antragsteller
volljährig" (the applicant is of legal age) is undefined. The twin gives the
answer with the unknown `Antragsteller volljährig would hold for case 1`.

RUML has two **modes** of evaluation. In the `complete` mode, the evaluator
examines all children of a node. In the `optimized` mode, an AND stops at the
first child that is not true, and an XOR stops at the first child that is
not false. The other children are `ignored`. The two modes can give
different answers: in the `optimized` mode, an undefined first child stops
an AND, also when a later child is false. The twin gives the answers of the
`complete` mode. The evaluator below gives both.

## Logical English as a RUML evaluator

The operation `evaluateForeign` of the LE server reads a rulemap and the
values of a case. It writes a result file of RUML (`.ruml-result`). The twin
decides each node. Each node result has a reason: the expression and the
values that it read, or the value that is missing. For a node that was not
examined in the `optimized` mode, the reason tells which node stopped its
parent.

A request:

```json
{ "operation": "evaluateForeign", "token": "...",
  "evaluator": "ruml", "name": "haertefall.ruml", "text": "<the rulemap>",
  "data": { "dp_pflegegrad": 4, "dp_eigenanteil": 640, "dp_alleinlebend": true, "dp_wohnsitz": true },
  "options": { "mode": "optimized" } }
```

The reply holds `result`, the result file, and `fileName`. The options are
`mode` (`complete`, the default, or `optimized`), `caseId` and `maxDepth`
(the limit of recursion, 500 by default). When the rulemap asks for an
evaluation protocol (`ruml:protocol`), the result holds it.

## The way back: from Logical English to RUML

**File ▸ Export to Another System… ▸ RUML** writes the program as one
rulemap. The root is the first query of the program that is about one
thing.

- A sentence that rules conclude is a node. One rule is an AND of its
  conditions. Two or more rules are an OR, with one child for each rule.
- `it is not the case that` is a NOT_AND.
- A sentence that only scenarios state is a data point with the answer yes
  or no.
- The conditions on values are one JSONata expression.
- A judged sentence is a leaf that a person decides.
- The scenarios are context materials of the category `example`, with the
  values of their case.

The Logical English text goes into the rulemap as comments. The description
of each node holds its rules. The comment of the metadata holds the whole
program. When you open the rulemap again in Logical English, the twin keeps
that program under `sources/`.

When the program came from a rulemap, the export keeps the identifiers, the
metadata and the data points of the original.

The export refuses a program that RUML cannot say. Nothing is written, and
each problem links to its line. RUML cannot say:

- a relation between two or more things, for example `*a person* is a parent
  of *a person*`;
- rules that use themselves;
- a sum, a count or a minimum over things that rules find;
- integrity constraints;
- a program in Logical English for LPS, which speaks about time.

## What is not supported yet

- `ruml:actions` (actions that start when a node has an answer) are listed
  in the ledger and not translated.
- A node of a different rulemap (`ruml:tree-include`) is not evaluated.
- The JSONata functions for texts and dates (`$substring`, `$toMillis` and
  others) are not translated yet. A leaf that uses them is residue: it is
  marked in the twin, and the ledger tells why.
- `decisionMode` `agreement` and `majority` are residue.
- Two examples of the specification require a capability of a different
  organisation (`com.example/...`). The specification says that a tool that
  does not know such a capability must refuse the file. The translator
  refuses it.

## See also

- [DMN and Logical English](dmn.md): the other standard of decision logic.
- [The Migration Gallery](gallery.md): all the systems that Logical English
  reads.
- [Adapters](adapters.md): the LE server answers the applications of a
  different system.
- The RUML specification: [ruml.org](https://ruml.org).

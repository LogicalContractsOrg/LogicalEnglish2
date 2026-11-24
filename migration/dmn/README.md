# DMN and FEEL → Logical English (Phase 4)

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

The translator of the design notes `roadmap.md` §5.2 and §8, Phase 4, for
**DMN**, the OMG's Decision Model and Notation (versions 1.1 to 1.6), and
**FEEL**, its expression language. A DMN model is an XML file: input data,
decisions (decision tables, literal expressions, boxed contexts,
invocations), business knowledge models (BKMs: functions), decision
services, and imports of other models. Each model becomes a Logical English
program, its **twin**: the inputs and decisions are functions
(language.md §2.4), the decision tables LE decision tables (§17.3) with
their hit policy, FEEL's built-in functions templates of the shared
libraries (`lib/text`, `lib/rounding`, `lib/temporal`, `lib/maths`, and
`lib/feel`, written for this phase), and the model's tests scenarios. It
uses the shared migration machinery of LE2 (`le_writer.pl`,
`le_migration.pl`; LE2's `docs/dev/migration.md`).

**Where it stands (26 October 2026): steps 0 to 3 are done, and, the same
evening, the way back (LE → DMN 1.6, `dmn_export.pl`) and the DMN adapter
(the APIs of Kogito, KIE Server, Camunda 7 and Camunda 8 answered by the
twins, `dmn_adapter.pl`, on LE2's adapter kit `le_adapter.pl`).** The
numbers of the last runs are in `runs/` and in the tables below.

| Collection | Models | Twins in | Tests | Result |
|---|---|---|---|---|
| DMN TCK, compliance level 2 (`dmn-tck/tck`, Apache-2.0) | 28 | LE2 `examples/migration/dmn/tck/` | the kit's test cases | 138 of 138 |
| RONL examples (`sgort/linked-data-explorer`, EUPL-1.2) | 16 distinct (32 files) | LE2 `examples/migration/dmn/ronl/` | generated; the 13 models of Camunda Modeler answered by Camunda 7.23's own engine (every input given, null where the case leaves it), the 3 others by Drools | 399 of 399, in 16 models |
| Benefit Decision Toolkit (Code for Philly, MIT) | 37 | LE2 `examples/migration/dmn/bdt/` | its Bruno requests | 195 of 195, in 25 models |
| The Omgevingswet's bruidsschat, STTR (KOOP) | 196 | this repository's `examples/migration/dmn/sttr/` (terms of reuse not confirmed) | generated, answered by Drools | 6,364 of 6,364, in 196 models |
| DMN TCK, compliance level 3 (FEEL) | 128 | this repository's `examples/migration/dmn/tck3/` (a measurement, not examples) | the kit's test cases | 1,745 of 3,559 (49%) |
| The client examples' models: Kogito's Traffic Violation, Camunda's Dinner Decisions (Apache-2.0) | 2 | LE2 `examples/migration/dmn/clients/` | `clients/*.cases.json`, answered by Drools and by Camunda 7.23's own engine | 33 of 33 |

**The way back** (`dmn_export.pl`, File ▸ Export ▸ DMN; checked by
`dmn_roundtrip.pl`, which runs each exported model's TCK test file with the
TCK's runner on Drools, `runs/roundtrip.txt`):

| Programs | Exported | Test cases |
|---|---|---|
| The public twins (TCK 28, RONL 16, BDT 37, clients 2) and LE2 `examples/regulatory/dmn_export/childcare_support.le` | 84 of 84 | 422 of 424 pass (27 October: the 2 others are cases of RONL's home-battery subsidy whose application date is the text "anders", not a date; the twin and Camunda answer 0, the exported model on Drools null; not yet examined) |
| Other hand-written LE programs (LE2 `examples/regulatory/*.le` and `examples/moreExamples/**`, 99) | 20; 79 refused, each with its reason | 38 of 38 pass |

**The adapter** (`dmn_adapter.pl`; checked by `dmn_adapter_check.pl`: every
expected result of the collections' own tests, sent through the adapter as a
caller sends it, `runs/adapter-check.txt`): TCK 126 of 126, BDT 195 of 195,
RONL 179 of 183, clients 26 of 26. The four RONL results that differ
(Heusdenpas Eindresultaat) are a rule of Camunda's that matches and gives
only nulls: Camunda answers a structure of nulls, the twin has no value and
the adapter answers null. Kogito's README request, Red Hat's
`kie-server-client` (Java), Camunda's `@camunda8/sdk` (Node, no sign-in and
OAuth) and Camunda 7's REST calls ran unchanged but for the address
(lpsPlus `examples/dmn_adapter_demo/`, whose `compare.mjs` gets 26 of 26
answers equal to Drools' and Camunda's on the original models).

The gate of step 1: every FEEL text of the four collections parses
(50,930 of 50,930, `runs/gate.txt`), and the decision requirements graph
the reader builds equals Drools' own reading for every model Drools
compiles: 28 of 28 (TCK level 2), 196 of 196 (bruidsschat), 38 of 38 (BDT),
4 of 4 (RONL), 121 of 125 (TCK level 3) — `runs/drg-gate.txt`.

| File | What it does |
|---|---|
| `fetch_sources.sh`, `corpus.pl` | the four collections at pinned commits into `.cache/` (gitignored); the bruidsschat's July 2023 STTR files unpacked into `.cache/sttr`; the client examples' two models (`client_file/3`) into `.cache/clients`; where each collection's twins go |
| `clients/` | the cases of the client examples' models (`<model>.cases.json`): the requests of the examples' own documentation, and a few more |
| `oracle-camunda/` | the second oracle: Camunda 7.23's DMN engine (camunda-engine-dmn with the Scala FEEL engine) as one jar, for Camunda Modeler's DMN 1.1 dialect (unqualified type names, process variables as inputs), which Drools does not run; reports each decision's result list and matched rules |
| `oracle/` | the oracle: Apache KIE Drools DMN 10.2.0 as one jar (`oracle/build.sh`, Java 21 and Maven): `eval` (cases in, results out, JSON), `drg` (Drools' reading of a model), `tck` (the kit's runner; 3,389 of the 3,391 published cases, one more than Drools' published result). `oracle/README.md` |
| `dmn_reader.pl` | DMN XML (1.1 to 1.6, STTR's extensions) → one model term |
| `feel_parser.pl` | FEEL → a syntax tree: expressions and unary tests, names with spaces resolved against the names in scope |
| `dmn_names.pl` | DMN names → template words (camelCase, STTR's escapes, numbers, articles, LE's reserved words and the copula) |
| `dmn_tests.pl` | the TCK's test files, and BDT's Bruno requests, as cases |
| `dmn_cases.pl` | generated cases for a model with no tests of its own (every bruidsschat and RONL model, a BDT model without Bruno requests): a case per table row, half of them with the questions the row does not read left unanswered; a name a column reads that the model does not declare (Camunda's process variables) is an input too |
| `dmn_oracle.pl` | the oracle on a model's cases (cached by a hash in `runs/oracle/`, gitignored) |
| `dmn_twin.pl` | a model and the models it imports → the migration term |
| `dmn_build.pl`, `build.pl` | builds the twins, with their ledgers and originals; `diagnose_model/3` builds one with an expectation for every decision |
| `dmn_import.pl` | File ▸ Open (LE2's `le_import.pl` registry, `../le_importers.pl`) |
| `dmn_adapter_map.pl` | the adapter's mapping beside each twin, `<twin>.adapter_map.json` (LE2 docs/user/integrations/adapters.md): an attribute per input and decision of the model (value, structure, list, records), aliases (a table's output name), and the DMN facts the engines' replies name (namespace, decision ids, hit policies, rule ids) |
| `dmn_adapter.pl` | the DMN adapter: Kogito (`/kogito/...`), KIE Server (`/kie-server/services/rest/server/...`), Camunda 7 (`/engine-rest/...`), Camunda 8 (`/v2/decision-definitions/evaluation`), an OAuth sign-in, `/dmn-adapter`; access by `../adapter_access.pl` |
| `dmn_adapter_check.pl` | the adapter on every collection's own tests |
| `dmn_export.pl` | the way back: a Logical English program as a DMN 1.6 model and its scenarios as a TCK test file (File ▸ Export; registered in `../le_importers.pl` with its export check) |
| `dmn_roundtrip.pl` | the way back checked: export, then the TCK's runner on Drools |
| `gate.pl` | the gate: the parse of every FEEL text, the DRG against Drools' |
| `test_dmn.pl` | plunit: the parser, the names, three small models (hit policies, FEEL's three values, STTR's idiom), File ▸ Open, a TCK model, the last gate runs |

## How to run

From the LE2 checkout (`/work`):

```sh
migration/dmn/fetch_sources.sh                 # the corpus
migration/dmn/oracle/build.sh                  # the oracle (Java 21, Maven)
swipl -q -g "use_module('migration/dmn/gate'), gate:parse_gate_all, gate:drg_gate_all" -t halt
swipl -q migration/dmn/build.pl                # every collection
swipl -q migration/dmn/build.pl -- tck 0004    # the models of a collection whose file name has 0004
swipl -q -g run_tests -t halt migration/dmn/test_dmn.pl
migration/dmn/oracle-camunda/build.sh          # the second oracle (Camunda 7.23)
swipl -q migration/dmn/build.pl -- clients     # the client examples' twins
swipl -q migration/dmn/dmn_adapter_check.pl    # the adapter on every collection's tests
swipl -q migration/dmn/dmn_roundtrip.pl        # the way back on Drools (or: -- tck | file.le ...)
```

## The way back: what becomes what

A value no rule concludes is an `inputData` (typed by its noun); a value
rules conclude is a decision whose rules, in order, are one FEEL literal
`if <conditions> then <value> else ... else null` (each value a condition
reads is guarded `x != null`, since a Logical English condition on a missing
value fails); a sentence is a boolean input (false unless stated) or a
boolean decision (`if (c1) or (c2) then true else false`); a list is a list
input or a decision of `for ... return` and `flatten`; an LE decision table
is a DMN decision table, as the decision when its one rule only reads the
table, otherwise as a business knowledge model (`<table>_table`) that the
rules invoke (several outputs: a context, `.column`); a template with places
that rules conclude is a BKM; `otherwise` and disjunctions that give the
value are split into the rules of the cascade; aggregates are `count`,
`sum`, `min`, `max`; the templates of lib/temporal, rounding, maths, text
and feel that FEEL has are its functions. A program about one kind of thing
(`the household income of *an applicant* ...`) is lowered to one case: the
subject's place leaves the templates (`the household income of the
applicant`) and each subject of a scenario is a test case of its own. Names
with a FEEL word (`or`, `for`, `null`, ...) are written with underscores.
Refused, with the reason: relations between things, abduction (`assumable`),
a scenario's own table, a value both stated and concluded, anything FEEL has
no form for here. Every input of a test case is given (null where the
scenario says nothing: DMN refuses a missing input), and a list's expected
elements are in the order the program gives them in the scenario (a COLLECT
table's order).

## The mapping

| DMN | The twin says |
|---|---|
| an input, a decision of one value | a function of no place: `the risk category is *a text*.` A value used in a formula is an operand: `N = the monthly salary * 12` |
| a structure (an item definition with components) | a function per component: `the rate of the approval is *a text*.` A structure passed to a service is the union of its parts in every model that reads it |
| a list of values, a list of structures | a relation, one fact per element, and `the … are listed` (FEEL tells an empty list from null); the places of a structure are named after its components (`the bereken isolatie opties include *a delta r* with *an extra dikte mm* with …`) |
| a decision table with simple cells | an LE decision table with its hit policy: UNIQUE `with unique match`, FIRST `with first match`, ANY `with first match` (approximated: DMN also reports rows that disagree), PRIORITY and OUTPUT ORDER rows reordered by the order of the output's allowed values, COLLECT and RULE ORDER `with all matches`; SUM, COUNT, MIN and MAX an aggregate over the matches |
| a table column with `-` or `not(…)` cells | read through `the … or null` (the value, or the word null), so a row with `-` matches where the input is null, as in DMN. A column that also compares numbers is read plainly (approximated: where its input is null the table has no answer) |
| any other table | a rule per row; FIRST, PRIORITY and ANY as an `otherwise` cascade; COLLECT with an aggregation over the rows' relation |
| a literal expression | a rule per alternative of its value; a boolean decision `… is true if …` and `… is false if …`, with no answer where FEEL gives null (FEEL's three values) |
| `x = null`, `x != null` | `it is not the case that the x is a value`, `the x is a value` |
| a context | its entries, each in scope for the next; evaluated on the program's own inputs, each entry is a function of the twin (`the checks as list of the is_eligible is …`), and a result that is the last entry is that entry's logic; a context without a result is a structure |
| a BKM | a function with places; a BKM of an imported model, or one with lists or structures for parameters, is inlined where it is invoked |
| a decision service (of the model, or of an imported one) | invoked on the program's own inputs with one output: a function of the twin, `the <service> result is *a value*`, written once however often it is invoked; otherwise inlined where it is invoked, its output decision computed in its own model, its inputs bound to what the caller passes |
| `for`, `some`, `every`, a filter `L[…]`, `L[1]` | over a relation: its elements; over a list written in place: its items |
| FEEL's built-in functions | LE's arithmetic (`floor`, `ceiling`, `abs`, `sqrt`), `lib/rounding` (`decimal`, `floor`/`ceiling` with a scale, `round half up`), `lib/text`, `lib/temporal` (dates, `years and months duration`), `lib/feel` (the rest); a null or a wrong argument gives null |
| dates, `@"2020-01-01"`, years-and-months durations | LE dates; a duration is a number of months, `.years` and `.months` its parts |
| STTR's questions (`vraagTekst`) | a view, `the facts are asked one at a time.`, with `the question for … is "…".` per question |
| a decision's description, a rule's annotations, STTR's `conclusieToelichting` | a comment on the rule (a native table: before the table, row by row) |
| each rule | labelled, and citing the model and its decision (`rule X with provenance the model at decision Y, rule 3:`) |

Models left without tests: twelve BDT
models: libraries of types and functions, and checks whose only input is a
structure (`situation`), for which the generator makes no values. Their
twins are built and loaded; their logic is tested where a tested model uses
it.

## What is not translated

- **Times, date-and-times, days-and-time durations.** LE has no type for
  them; the TCK's level 3 uses them in about 700 cases, the three real
  collections not at all.
- **Ranges and functions as values, `instance of`, regular expressions
  (`matches`, `replace`, `split`), the context functions (`get value`,
  `context put`, `context merge`).** Residue blocks, with the FEEL text.
- **Java BKMs** (BDT's `invoke decision service`).
- **Includes instead of inlining.** An imported model's BKMs and services
  are inlined, so a library model's logic is written in each twin that uses
  it (the DMN modeller's review, point 7). The copied rules are between a
  `BEGIN of inlined logic` and an `END of inlined logic` comment, which
  name what they copy (the service or BKM, its model and file) and suggest
  moving it to a separate, included file. A service function is one block;
  a decision whose conditions copy imported logic is one block, with the
  service functions it reads before it.

## Traps met

- `findall/3` copies variables, again: the variables of the rule that a
  table's outputs bind, and the alternatives of a split `otherwise`, must
  be built without it (`out_fields/5`, `and_product/3`).
- Dict access (`C.status`) inside `aggregate_all/3`, which is autoloaded,
  is evaluated before the goal runs: use `get_dict/3`.
- A Logical English expectation of several answers is a set, sorted; a DMN
  list is ordered. The exported test lists them in the order the program
  gives them (`in_program_order/4`, `queryScenario/6`).
- Camunda's SDK reads the access token as a JSON Web Token; the adapter's
  OAuth route wraps the signed token in one (`adapter_sign_in_jwt/3`).

- `findall/3` copies variables. An environment (a BKM's parameters, a
  context's entries, a loop's element) is therefore made of ground
  references (`'$ref'(Key)`), bound back to variables after the
  compilation: a variable in the environment would be copied apart from the
  goal that binds it (`groundify/4`, `bind_refs/4`).
- yall lambdas over outer variables behave differently once LE2's modules
  are loaded (goal expansion turns the lambda into a predicate and the outer
  variable into a fresh one): the code has none.
- `b_setval/2` copies its value too: a list of the rule's variables cannot
  travel through it.
- A DMN name holding `is` (`isAffordable`) breaks every sentence the name is
  in: LE reads the first `is` as the copula. The word is joined to the next.
- A column may read the name of another table's *output* rather than of a
  decision. It is that decision's value, not a free input: a generated case
  that gave it a value made Drools use the value and the twin compute the
  decision, two answers (RONL's SZW Bijstand, found and fixed 26 October).
- An input entry that is a boolean expression
  (`date(dagVanAanvraag) <= date("2024-12-31")`, RONL's home-battery
  subsidy) is the test itself for Camunda's engine, whatever the input's
  value; Drools and the DMN standard compare the input with the
  expression's value. A twin of a Camunda Modeler file reads it as Camunda
  does (`dmn_twin.pl`, `camunda_reading/1`), and Camunda's engine is the
  oracle of those files (27 October). Camunda refuses a case that leaves an
  input out: the cases give every input, null where unstated.
- Two tables may output the same name: a table whose entry for the name is
  the name itself only passes on a value computed elsewhere, and a reader
  of the name finds it in the other (RONL's SVB Leeftijds Informatie beside
  SVB Bereken Leeftijden, 27 October).
- Drools answers STTR's COLLECT decisions with `[]` only with its type check
  off (`--no-typecheck`), as Kogito runs.

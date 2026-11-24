# RUML ↔ Logical English

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

The translator of the design notes `ruml.md` (the author's working papers, not published)
for **RUML**, the Rulemapping Logic Format (version 1.0.0, 15 November 2026,
Law as Code Institut GmbH for the Rulemapping Group GmbH). A RUML file is a
tree of yes-or-no questions about one case, in JSON, with the data each
question reads (data points), JSONata expressions, and the texts of the law.
Each rulemap becomes a Logical English program, its **twin**; a Logical
English program can be written back as a rulemap; and Logical English can
act as a RUML **evaluator**: a rulemap and a case in, RUML's own result file
out.

It uses the shared migration machinery of LE2 (`le_writer.pl`,
`le_migration.pl`, `le_import.pl`; LE2's `docs/dev/migration.md`).

## Where it stands (24 November 2026)

Steps 1 to 6 and 8 of the plan are done; step 7 (the LPS companion for
`ruml:actions`) waits, as decided; step 0 (real rulemaps from the publisher)
and the messages to the publisher wait too (`TODO.md`).

| Step | Gate | Result |
|---|---|---|
| 1. The reader | RUML's 90 validation tests: accepted or rejected as each expects, by the published schema with the reader's own checks | **90 of 90** (`runs/validation-gate.txt`) |
| 2. The twins | Every public rulemap translates; RUML's evaluation tests pass as scenarios (the `complete` mode) | **80 of 83** rulemaps built; the 3 others require another vendor's capability and are refused, as the specification demands (CAP-01). **3,508 of 3,508** expectations pass: the tests' fixtures 1,442, the specification's examples 2,066 (`runs/build-*.txt`); a few more are pending, written as comments, where they wait for a residue block |
| 3. Generated cases, the oracle, the second opinion | Twin and oracle agree on every generated case; each disagreement with the second evaluator explained | The oracle passes **103 of 103** of RUML's evaluation tests (`runs/oracle-check.txt`). The twins agree with it on every generated case (in the counts above). The unofficial evaluator agrees on **527 of 562** evaluations of the cases with data points; every difference at the root comes from one open question of the specification (§ below). (The cases that answer leaves came later and were not put to it: it takes leaf statuses by path.) |
| 4. Texts, File ▸ Open | The specification's law examples open with their texts | Texts under `sources/`: plain text, and a law in RUML Text written as Akoma Ntoso XML and as text; anchors as rule provenance; File ▸ Open of `.ruml`, `.rumlc`, `.ruml-ext`, zip; a Playwright test |
| 5. The evaluator | RUML's 103 evaluation tests through Logical English; every result valid | **103 of 103**, both modes; **103 of 103** result files valid against `ruml-result.schema.json` (`runs/evaluation-gate.txt`). LE2's operation `evaluateForeign` |
| 6. The way back | Every twin exports and comes back with the same results; counts for other programs; every export valid | **80 of 80** twins export, all valid (and 218 of 625 other programs, all valid: § below); on the originals' generated cases (473, with data and with answers to leaves), **1,575 of 1,575** node results are the same as the original's, but for one node whose expression draws a random number (`runs/roundtrip.txt`); the counts for LE2's own programs and the other doors' twins are in the same file |

## The way back on programs that did not come from RUML

How many of LE2's own programs, and of the twins of the other doors, can be
written as RUML (`runs/roundtrip.txt`, the run of 24 November 2026). Every
exported file is valid against the published schema. RUML
speaks about one case with yes-or-no questions; a program about relations
between things, or one with no sentence about one thing, is refused with its
reason, one per line of the program.

| Programs | Exported | Refused | The commonest reasons |
|---|---|---|---|
| LE2's own (`examples/regulatory`, `examples/moreExamples`, core suite) | 113 of 288 | 175 | a sentence about two things (70); no sentence about one thing to be the root (60); a condition RUML's expressions cannot say (37) |
| DMN twins | 18 of 114 | 96 | no sentence about one thing (45); a sentence about two things (38) |
| RuleSpec twins | 26 of 39 | 13 | |
| L4 twins | 36 of 80 | 44 | |
| LegalRuleML twins | 10 of 24 | 14 | |
| s(CASP) twins | 5 of 17 | 12 | |
| Miniscript twins | 6 of 24 | 18 | |
| Blawx twins | 3 of 15 | 12 | |
| Catala twins | 1 of 12 | 11 | |
| OIPA twins | 0 of 12 | 12 | |

An exported program is a way from that system into RUML, through Logical
English: a DMN model, an L4 rule or a RuleSpec statute that fits RUML's form
becomes a rulemap.

## How it reads a rulemap

The mapping is in `ruml_twin.pl`'s header and the plan's §4. In short: every
node is a sentence about a case (`Antragsteller volljährig holds for *a
case*`), its words the node's label; AND is one rule, OR and XOR a rule per
child; NOT_AND, NOT_OR and NOT_XOR the negation of a second sentence;
DELEGATED the translation of its JSONata; a leaf with `ruml:query` a rule
whose conditions are its expression; a leaf with no deciding capability a person's answer, a fact of the case (`the answer to <label> for case 1 is true`), undefined until given; `ruml:ai-query` a judged sentence; data points sentences that scenarios
state; a set a relation between the case and its members.

RUML's three results are Logical English's answers:

| RUML | The twin |
|---|---|
| true | the sentence is proved, and its negation is not |
| false | the sentence is not proved |
| undefined | the sentence and its negation are both proved, each only with unknowns |

The twin reproduces RUML's `complete` mode exactly (decision 3): a leaf whose
expression has no result (a missing value under a comparison, a `$lookup` of
an unlisted key) has a second rule with the assumable sentence `... would
hold for *a case*`; a DELEGATED or recursive node asks that its children be
`decided`, a sentence defined from the data alone. The `optimized` mode is
the evaluator's (`ruml_result.pl`): a walk with RUML's stopping rules.

## The way back

`ruml_export.pl` (File ▸ Export ▸ RUML) writes the program's first query as
the root; one rule an AND, several an OR, a negation a NOT_AND; the
conditions on values one `ruml:query` expression; a computed value a
computed data point; the twin's own forms read back as what they were. The
Logical English travels **as comments** (decision 4, as taken: no name space
of our own): each node's `description` holds its rules, and
`metadata.comment` the whole program. File ▸ Open of such a file keeps that
program beside the twin, as `sources/<name>.original.le`. The scenarios are
`ruml:context` entries of the category `example`, with the values they state
(at most 12). Refused, each on its line: relations between things, a
sentence about two things, rules that use themselves, aggregates other than
a twin's count, integrity constraints, LPS.

## Findings for the publisher (not sent: `TODO.md`)

1. **A missing value under `=`.** JSONata gives `false` for `dp_x = true`
   when `dp_x` has no value; §4.8 says the result is the node's status, so
   the node is false. The unofficial evaluator says undefined (missing data,
   §5.0). No conformance test covers it. This translator follows the text of
   §4.8; every root-level difference with the second evaluator is this.
2. **Node identifiers.** Seven examples of the specification use the file's
   own `metadata.id` as a node's `id` (NODE-08 forbids it):
   `credit-check`, `root-declaration`, `income-check-with-text-and-actions`,
   `income-query`, `funding-application`, `hardship-case`, `inline-mode`.
3. **Examples that cannot be evaluated as printed** (plan §3, I): a modular
   node with two results "because different data points were available", and
   a recursion whose rounds see different data, while the format has one set
   of data per evaluation.
4. **The runner contract** describes tests that set leaf statuses and compare
   whole result files; the published tests give data points and check single
   statuses.

## Files

| File | What it does |
|---|---|
| `fetch_sources.sh`, `corpus.pl` | the format's repository, its two libraries and the unofficial tooling at pinned commits, into `.cache/` (gitignored); the two collections (`spec`, `tests`) and where their twins go |
| `package.json` | the Node half: `jsonata` 2.2.0 (the oracle), `ajv` (the schema check), `js-yaml` |
| `ruml_reader.pl` | `.ruml`, `.ruml-ext` (merged after the hash check), `.rumlc`; the checks of chapter 8 that change meaning or that no schema states |
| `schema_check.mjs` | the published JSON Schemas, on files (`ruml`, `ruml-result`, `ruml-ext`) |
| `jsonata_parser.pl` | JSONata → a syntax tree; the names an expression reads |
| `ruml_names.pl` | labels → template words |
| `ruml_twin.pl` | a rulemap → the migration term (twin, ledger, tests) |
| `ruml_tests.pl`, `ruml_paths.pl` | RUML's conformance tests, read; paths of a tree |
| `ruml_cases.pl` | generated cases, the oracle's answers (cached in `runs/oracle/`), the second opinion's input |
| `ruml_oracle.mjs`, `oracle_check.mjs` | the oracle, and its check on RUML's 103 evaluation tests |
| `second_opinion.mjs` | the oracle against `ruml-tooling`'s evaluator on every generated case |
| `ruml_build.pl`, `build.pl` | builds the twins with their ledgers, originals and texts |
| `ruml_import.pl` | File ▸ Open, and the evaluator of LE2's `evaluateForeign` |
| `ruml_result.pl` | Logical English as a RUML evaluator: a `.ruml-result` |
| `ruml_export.pl` | the way back (File ▸ Export, with its check) |
| `ruml_roundtrip.pl` | the way back checked |
| `gate.pl` | the validation gate (step 1) and the evaluation gate (step 5) |
| `test_ruml.pl` | plunit: JSONata, labels, the checks, the three results, both modes, a reason, export and refusal, File ▸ Open |
| `spike/` | the experiments behind the plan |

## How to run

From the LE2 checkout (`/work`):

```sh
migration/ruml/fetch_sources.sh
(cd migration/ruml/.cache/ruml-tooling && npx -y pnpm@9 install --filter @ruml/core... --ignore-scripts && node packages/core/esbuild.mjs)   # the second opinion only
swipl -q -g "use_module('migration/ruml/gate'), gate:validation_gate" -t halt
node migration/ruml/oracle_check.mjs
swipl -q migration/ruml/build.pl                  # both collections (or: -- tests | spec [filter])
swipl -q -g "use_module('migration/le2_paths'), use_module('migration/ruml/gate'), gate:evaluation_gate" -t halt
swipl -q -g "use_module('migration/le2_paths'), use_module('migration/ruml/ruml_build'), ruml_cases:second_opinion([tests, spec])" -t halt
swipl -q migration/ruml/ruml_roundtrip.pl         # (or: -- twins)
swipl -q -g run_tests -t halt migration/ruml/test_ruml.pl
```

## Traps

- `findall/3` copies its results: the case variable of a rule must be kept
  shared (`ruml_twin:shared_findall/4`). The twins answered for "a second
  case" until it was.
- A `yall` lambda that reads a variable of its clause without `{X}/` gets a
  copy: helper predicates, or `{X}/[...]>>`.
- The oracle's cache is keyed by the file's content and the request; keyed
  by the path alone, the round trip read stale answers.
- A value of one or two capital letters (`BY`) in a rule is a variable in LE:
  the twin writes constants in quotation marks.
- `pnpm install` run inside `.cache/ruml-tooling` puts its store at the root
  of the repository unless told otherwise: delete `/lpsPlus/.pnpm-store`.
- A comment that contains `/*` (a glob such as `examples/*.le`) ends a
  Prolog block comment early.

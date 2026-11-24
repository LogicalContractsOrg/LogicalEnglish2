# Axiom RuleSpec → Logical English (Phase 3a)

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

The translator of the design notes `roadmap.md` §5.10 and §8, Phase 3a, for
**RuleSpec**, the format in which the Axiom Foundation publishes United
States statutes, regulations and agency policies as executable modules
(`rulespec-us`, CC-BY-4.0; the engine `axiom-rules-engine`, MIT). A module
is one YAML file for one provision, with its tests in a companion
`.test.yaml`; it imports other modules by a durable identifier
(`us:statutes/7/2014/e/6/A`). Each module becomes a Logical English program
holding the module and every module it imports, each rule citing its
provision, the module's tests as scenarios; and a Logical English program
can be written back as a RuleSpec module whose tests Axiom's engine runs.
It uses the shared migration machinery of LE2 (`le_writer.pl`,
`le_migration.pl`; LE2's `docs/dev/migration.md`).

**Where it stands (5 October 2026): steps 0 to 3 are done.**

- **The gate (step 1).** Axiom's engine reproduces 172 of the 175 test
  cases of the 44 modules in scope (SNAP, the Child Tax Credit, the EITC,
  SSI); the 3 others give one input two values in their test file (7 U.S.C.
  2014(c)). The reader's parse of every formula equals the engine's own
  lowering of it: **351 of 351** (`gate.pl`, `runs/gate.txt`).
- **The twins (step 2).** 39 twins (89 modules counting imports) in LE2's
  `examples/migration/rulespec/{snap,ctc,eitc,ssi}/`: **1,248 ledger
  elements encoded, 10 approximated (a rule reading a value another entity
  declares, noted), no residue; 473 of 473
  expectations pass**; 13 more are pending, the cases of 2014(c) the engine
  does not reproduce.
- **File ▸ Open and the way back (step 3).** `rulespec_import.pl` opens a
  module, alone or zipped with its imports. `rulespec_export.pl` writes a
  Logical English program as a RuleSpec module with its scenarios as test
  cases: **37 of the 39 twins, exported, compile and pass every case on
  Axiom's engine**; 2 are refused with their reason (a `match` nested in
  an `if`), none disagrees (`roundtrip.pl`,
  `runs/roundtrip.txt`).

| File | What it does |
|---|---|
| `fetch_sources.sh`, `corpus.pl`, `prepare_root.py` | the corpus: `rulespec-us` at commit `f468c8d` (4 October 2026) into `.cache/rulespec-us`; the copy the engine loads, `.cache/root/rulespec-us`, with only the metadata the engine refuses normalised (below); the modules written as twins |
| `fetch_oracle.sh`, `rulespec_oracle.py` | the oracle: the engine built from source at commit `e9757b4` (5 October 2026), and a runner that turns each test case into an execution request as Axiom's own harness does (`axiom-encode`), runs it in explain mode and keeps the results in `runs/<module>.json` |
| `rulespec_reader.pl` | YAML (SWI-Prolog's `library(yaml)`), the import closure, and a parser of the formula language written after the format reference (`docs/rulespec-format.md` of the engine) |
| `gate.pl` | the reader's parse of every formula against the engine's lowering |
| `rulespec_twin.pl` | a module and its imports → the migration term: templates, rules, facts, tests as scenarios, the ledger |
| `rulespec_build.pl`, `build.pl` | builds the twins into LE2 (`le2_paths:twins_dir(rulespec, D)`), with the originals under each group's `sources/` |
| `rulespec_import.pl` | File ▸ Open (LE2's `le_import.pl` registry, `../le_importers.pl`) |
| `rulespec_export.pl`, `roundtrip.pl` | File ▸ Export to Another System… → RuleSpec, and the round trip through Axiom's engine |
| `test_rulespec.pl` | plunit: the grammar, the closure, the wording, two twins, an import with a missing module, the export and its refusals, the round trip's last run |
| `results.py` | the table below |

## How to run

From the LE2 checkout (`/work`):

```sh
migration/rulespec/fetch_sources.sh     # the corpus, normalised
migration/rulespec/fetch_oracle.sh      # the engine (Rust; see the script)
python3 migration/rulespec/rulespec_oracle.py --all-under us/statutes/7   # the engine on the tests
./myswipl.sh -q migration/rulespec/gate.pl < /dev/null
./myswipl.sh -q migration/rulespec/build.pl                    # all twins
./myswipl.sh -q migration/rulespec/build.pl -- us:statutes/7/2017/a
./myswipl.sh -q migration/rulespec/roundtrip.pl < /dev/null    # LE -> RuleSpec -> engine
./myswipl.sh -q -g run_tests -t halt migration/rulespec/test_rulespec.pl
```

**The engine and the corpus are a moving pair.** The released binaries
(v0.2.2, 20 August 2026) refuse fields the corpus has used since September,
and the corpus itself lists 643 modules its own pinned engine does not load
(`tools/known-engine-load-failures.txt`). Every class of those failures but
one is metadata the engine does not execute, so `prepare_root.py` copies the
jurisdiction folders and changes only that: a list of citation paths keeps
its first, an unknown `source_verification` field (a copy of the parameter
values for the corpus checker) is dropped, 22 files and folders whose names
the engine refuses (`47:294.yaml`, `He-W 704`, an en dash) are left out.
Rules, formulas and tests are untouched; the list is
`.cache/root/normalised.txt`. Composition modules (`module.kind:
composition`) are compiled by another command and are not translated.

## The mapping

| RuleSpec | The twin says |
|---|---|
| a module and its `imports` | one program: each imported module's rules under a comment naming its provision, imports first; the engine merges them into one namespace too, and so does the twin (a name defined twice keeps the first module's, an approximated ledger row) |
| `kind: parameter`, one version | a fact, cited: `the snap minimum allotment rate is 0.08, as stated in "7 USC 2017(a)", confer "8 percent"`; the provision a document whose text is the module's original in `sources/` |
| an indexed parameter (`indexed_by`, `values`) | one fact per row: `the snap maximum allotment table for 3 is 785` |
| a parameter whose formula is an expression (`1 / 2`) | a rule (the engine, too, lowers it as a derived value) |
| `kind: derived`, a value | a rule concluding `the <name> of *a household* is *an amount*` (the noun from `entity`, the value's from `dtype`: Money an amount, Rate a rate, a count a number) |
| `kind: derived`, `dtype: Judgment` | a rule concluding a sentence: `*a household* is snap eligible`, `*a household* fails gross income standard`, `the snap net income of *a household* exceeds poverty line` (the name's verb, when it has one, starts the predicate) |
| a name no rule defines | an input: a template the scenario states (`; undefined`); read as a condition, a sentence stated when true (LE reads a sentence not stated as not holding, which is the engine's `not_holds`, not its `undetermined`) |
| a formula's names | conditions, each read once: `the snap net income of the household is an amount N` |
| `+ - * /`, `max`, `min`, `floor`, `ceil` | LE arithmetic, `the maximum of A and B is C`, `floor()`, `ceiling()` |
| `table[expr]` | a condition on the table's fact at the index |
| `if … : … elif … : … else: …` | an `otherwise` cascade; inside arithmetic, a cascade of its own binding the value |
| `match x:` with `_` | the same, comparing `x` with each pattern; without `_`, the cascade has no last branch: no value, as the engine has none |
| `and`, `or`, `not` in a judgment | the conditions in disjunctive normal form: each alternative a rule of its own (`rule …_1`, `…_2`), negations pushed inward, a comparison one unit; past 12 alternatives, nested |
| `exactly_one(a, b, c)` | the alternatives written out: a and not b and not c, … |
| `data_relation` (`arguments: [Person, Household]`) | a two-place sentence, `*a person* is a member of *a household*` |
| `len`, `sum`, `count_where`, `sum_where` over a relation | `the count of each person such that …`, `the sum of each amount such that …` |
| `period_start` | `the calculation date`, which the scenario states |
| dated `versions` | each version a rule guarded by the calculation date (on or after its start, before the next or on or before its end; convention N9 of roadmap §7.5); a rule with one version open at its end that starts before 2000 carries no guard (it is in force for every test) |
| an `else: 0` branch, a rule naming its subject only under a negation | the condition `the household is a household`, each scenario stating `household_1 is a household`, so the answer names the household |
| `rounding:` on a money output | approximated in the ledger (6 rules of the whole corpus, none in scope); `lib/rounding` (N8) has the modes |
| a test case | a scenario citing the test file and the case; its inputs facts, a relation's items related things with their own facts, each output an expectation of the query named after the rule (`q_snap_regular_month_allotment`); `not_holds` an expectation with no answer |
| `derived_relation`, `days_between`, `date_add_*`, `*_over_periods` | residue blocks with the rule's YAML (none in the twins of scope) |

## The way back

`rulespec_export.pl` reads a loaded program (`le_writer:kb_to_ir/2`), not its
text. A template concluded by rules becomes a derived rule; a fact without a
subject a parameter; facts with a key an indexed parameter; a two-place
sentence no rule concludes a data relation; anything else an input. A rule's
conditions become its formula: the values its conditions read become names,
its arithmetic the formula, its comparisons and sentences the conditions;
several rules for one sentence `or`; an `otherwise` cascade `if … else`, or
a `match` when it has no last branch and compares one value with constants;
the calculation-date guards dated versions. The scenarios become the test
cases, a sentence not stated `false`. It refuses, with the reason, a value
concluded only under conditions (RuleSpec has no "no value"), a value read
of something other than the rule's subject outside an aggregate, several
rules concluding one value that are not dated versions, and a template of
three places or more. The editor's export puts the test cases after the
module as a commented block (one file); `export_files/4` writes the two.

## Results

| Group | Twin | Modules | Encoded | Approx. | Residue | Expectations pass | fail | error | Pending | Engine on the test file |
|---|---|---|---|---|---|---|---|---|---|---|
| ctc | `us_statutes_26_24` | 2 | 70 | 0 | 0 | 28 | 0 | 0 | 0 | 4 of 4 |
| ctc | `us_statutes_26_24_d` | 11 | 226 | 2 | 0 | 32 | 0 | 0 | 0 | 4 of 4 |
| ctc | `us_statutes_26_24_h` | 1 | 24 | 0 | 0 | 20 | 0 | 0 | 0 | 4 of 4 |
| eitc | `us_statutes_26_32` | 10 | 202 | 2 | 0 | 28 | 0 | 0 | 0 | 5 of 5 |
| eitc | `us_statutes_26_32_c_2` | 2 | 25 | 0 | 0 | 4 | 0 | 0 | 0 | 4 of 4 |
| snap | `us_policies_usda_snap_fy_2024_cola_deductions` | 2 | 20 | 0 | 0 | 18 | 0 | 0 | 0 | 6 of 6 |
| snap | `us_policies_usda_snap_fy_2024_cola_income_eligibility_standards` | 1 | 32 | 0 | 0 | 45 | 0 | 0 | 0 | 5 of 5 |
| snap | `us_policies_usda_snap_fy_2024_cola_maximum_allotments` | 1 | 17 | 0 | 0 | 4 | 0 | 0 | 0 | 4 of 4 |
| snap | `us_policies_usda_snap_fy_2026_cola_deductions` | 2 | 20 | 0 | 0 | 18 | 0 | 0 | 0 | 6 of 6 |
| snap | `us_policies_usda_snap_fy_2026_cola_income_eligibility_standards` | 1 | 10 | 0 | 0 | 9 | 0 | 0 | 0 | 3 of 3 |
| snap | `us_policies_usda_snap_fy_2026_cola_maximum_allotments` | 1 | 17 | 0 | 0 | 11 | 0 | 0 | 0 | 3 of 3 |
| snap | `us_statutes_7_2012_j` | 1 | 3 | 0 | 0 | 2 | 0 | 0 | 0 | 2 of 2 |
| snap | `us_statutes_7_2012_m_4` | 1 | 5 | 0 | 0 | 4 | 0 | 0 | 0 | 4 of 4 |
| snap | `us_statutes_7_2014_a` | 1 | 10 | 0 | 0 | 12 | 0 | 0 | 0 | 4 of 4 |
| snap | `us_statutes_7_2014_c` | 4 | 23 | 0 | 0 | 4 | 0 | 0 | 13 | 1 of 4 |
| snap | `us_statutes_7_2014_d` | 1 | 10 | 0 | 0 | 8 | 0 | 0 | 0 | 6 of 6 |
| snap | `us_statutes_7_2014_e_2` | 2 | 5 | 0 | 0 | 4 | 0 | 0 | 0 | 2 of 2 |
| snap | `us_statutes_7_2014_e_2_b` | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 0 | 1 of 1 |
| snap | `us_statutes_7_2014_e_6_a` | 3 | 13 | 0 | 0 | 4 | 0 | 0 | 0 | 2 of 2 |
| snap | `us_statutes_7_2014_g` | 1 | 19 | 0 | 0 | 12 | 0 | 0 | 0 | 4 of 4 |
| snap | `us_statutes_7_2015_b_1` | 1 | 27 | 0 | 0 | 22 | 0 | 0 | 0 | 6 of 6 |
| snap | `us_statutes_7_2015_d_2` | 8 | 76 | 0 | 0 | 9 | 0 | 0 | 0 | 3 of 3 |
| snap | `us_statutes_7_2015_d_2_a` | 1 | 8 | 0 | 0 | 8 | 0 | 0 | 0 | 4 of 4 |
| snap | `us_statutes_7_2015_d_2_b` | 1 | 6 | 0 | 0 | 4 | 0 | 0 | 0 | 4 of 4 |
| snap | `us_statutes_7_2015_d_2_c` | 2 | 43 | 0 | 0 | 8 | 0 | 0 | 0 | 4 of 4 |
| snap | `us_statutes_7_2015_d_2_d` | 1 | 3 | 0 | 0 | 3 | 0 | 0 | 0 | 3 of 3 |
| snap | `us_statutes_7_2015_d_2_e` | 1 | 6 | 0 | 0 | 4 | 0 | 0 | 0 | 4 of 4 |
| snap | `us_statutes_7_2015_d_2_f` | 1 | 8 | 0 | 0 | 4 | 0 | 0 | 0 | 4 of 4 |
| snap | `us_statutes_7_2015_e` | 1 | 38 | 0 | 0 | 20 | 0 | 0 | 0 | 4 of 4 |
| snap | `us_statutes_7_2015_f` | 1 | 16 | 0 | 0 | 35 | 0 | 0 | 0 | 14 of 14 |
| snap | `us_statutes_7_2017_a` | 5 | 39 | 0 | 0 | 17 | 0 | 0 | 0 | 4 of 4 |
| ssi | `us_statutes_42_1382_a_1` | 4 | 41 | 1 | 0 | 5 | 0 | 0 | 0 | 4 of 4 |
| ssi | `us_statutes_42_1382_a_2` | 4 | 40 | 1 | 0 | 5 | 0 | 0 | 0 | 4 of 4 |
| ssi | `us_statutes_42_1382_a_3` | 1 | 4 | 0 | 0 | 6 | 0 | 0 | 0 | 3 of 3 |
| ssi | `us_statutes_42_1382_b` | 2 | 24 | 2 | 0 | 6 | 0 | 0 | 0 | 3 of 3 |
| ssi | `us_statutes_42_1382_e_1` | 3 | 70 | 2 | 0 | 20 | 0 | 0 | 0 | 12 of 12 |
| ssi | `us_statutes_42_1382a_b_2` | 1 | 15 | 0 | 0 | 5 | 0 | 0 | 0 | 5 of 5 |
| ssi | `us_statutes_42_1382a_b_4` | 1 | 16 | 0 | 0 | 20 | 0 | 0 | 0 | 5 of 5 |
| ssi | `us_statutes_42_1382b_a` | 1 | 16 | 0 | 0 | 4 | 0 | 0 | 0 | 4 of 4 |
| **all** | 39 twins | 89 | 1248 | 10 | 0 | **473** | 0 | 0 | 13 | 168 of 171 |

"Engine on the test file" is the run of `rulespec_oracle.py` on the twin's
own module; a twin's expectations are the test file's, and the cases the
engine does not reproduce are pending in the twin.

## Licence

`rulespec-us` is CC-BY-4.0 (Axiom Foundation): the twins are published in
LE2 with the attribution in each program's opening comment and the
originals under `sources/`. The translator is part of the Logical English
Translators (the `converters` capability).

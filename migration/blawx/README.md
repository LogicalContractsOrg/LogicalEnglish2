# Blawx → Logical English (Phase 2c)

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

The Blawx half of the design notes `roadmap.md` §5.7 and §8, Phase 2c.
A [Blawx](https://github.com/Lexpedite/blawx) project — legislation in
Blawx's "Clean" markdown, the blocks of each section compiled by Blawx into
s(CASP), and the project's tests — becomes a Logical English program in the
**Act's own words**, each rule citing its section, with the project's tests
as scenarios whose expected answers are **Blawx's own** (its reasoner, run),
plus cases written from each rule and answered by Blawx the same way. It uses
the shared migration machinery of LE2 (`le_writer.pl`, `le_migration.pl`;
LE2's `docs/dev/migration.md`); nothing Blawx-specific lives in LE2.

| File | What it does |
|---|---|
| `fetch_sources.sh` | Blawx v1.6.22-alpha (MIT, commit `3de892f6`, 18 October 2023 — its last release) into `.cache/` (gitignored) |
| `blawx_reader.pl` | a project (YAML of Django fixtures: `blawx.ruledoc`, `blawx.workspace`, `blawx.blawxtest`) → the Act's text, each section's s(CASP) clauses with their comments, the tests; section ids → locators (`section 34(1)(b)(i)`) and constants (`section_34_1_b_i`) |
| `blawx_twin.pl` | project → migration: templates, rules, defeats, facts, constraints, residue, the tests as scenarios, a View, the ledger; `build_twin/4` writes a twin directory |
| `blawx_cases.pl` | cases written from the rules: each rule met, each near miss, each defeat (the satisfaction-analysis method of the Miniscript twins) |
| `oracle.py` | Blawx's reasoner, run: `reasoner.py`'s `run_test` assembly (its preamble — `passthrough.py`, `ldap.py`, `dates.py`, `aggregates.py`, `events.py` — every section's encoding with the `% BLAWX CHECK DUPLICATES` lines de-duplicated, the test) under `library(scasp)`; the clock fixed |
| `runs/` | the oracle's answers (tests, generated cases), kept so a build needs Python only when a project changes |
| `build.pl` | builds the 15 twins into `LogicalEnglish2/examples/migration/blawx/<project>/` |
| `blawx_import.pl` | the File ▸ Open adapter (LE2's `le_import.pl` registry, `migration/le_importers.pl`): a `.blawx` export or example YAML (alone or zipped) → its twin |
| `test_blawx.pl` | plunit: the reader, the wording, the defeats, every twin passing, the import adapter |
| `results.py` | the results table below, from the built twins and their ledgers |

## How to run

From the LE2 checkout (`/work`), with `library(scasp)` installed
(`pack_install(scasp)`) and Python 3 with PyYAML:

```sh
migration/blawx/fetch_sources.sh
./myswipl.sh -q migration/blawx/build.pl              # all 15 twins
./myswipl.sh -q migration/blawx/build.pl -- bird      # one
./myswipl.sh -q -g run_tests -t halt migration/blawx/test_blawx.pl
python3 migration/blawx/oracle.py <project.yaml> --all   # Blawx's answers to its tests
```

Each twin directory holds `<id>.le`, `<id>.ledger.md` / `.ledger.json` and
`sources/` (the project file and the Act's text as `sources/<id>.md`, which
the program cites). The twins run in LE2's `testing/run_tests.sh le
--with-extensions` through the `insureLE2` link.

## The mapping

| Blawx generates | The twin says |
|---|---|
| `blawx_category(C)`, `#pred C(X) :: '@(X) is a C'` | `*a thing* is a C` (the category itself as the place's type when it types an attribute: `*a test* is a test`) |
| `blawx_attribute(Cat, A, Type)`, `blawx_relationship(R, T1, ...)` with their `#pred` | a template in the `#pred`'s words, places typed by `Cat`/`Type`, in the order of the sentence (not of Blawx's arguments); Blawx's possessive `@(X) 's facial hair is …` → `the facial hair of *a person* is …`; a type word before its own place dropped (`business @(X)` → `*a business*`) |
| `according_to(S, P, Xs) :- Body` | a rule concluding P, labelled after the section and cited: `rule section_4 with provenance the Rock Paper Scissors Act at section 4:` |
| `holds(S, P, Xs) :- according_to(S, P, Xs)` and `P(Xs) :- holds(S, P, Xs)` (and their `% BLAWX CHECK DUPLICATES` copies) | nothing: Blawx's plumbing, collapsed into the rules |
| `holds(S, P, Xs) :- according_to(...), not blawx_defeated(S, P, Xs)` with `blawx_defeated(S, P, Xs) :- holds(S2, P2, Ys)` | the rule's guard: `and it is not the case that <P2> under section_S2` |
| `holds(S, P, Xs)` or `according_to(S, P, Xs)` read by a rule, a defeat, a fact or a test | a template of its own: `*a thing* can fly under *a provision*`, concluded by S's rule, with a rule linking it to the plain conclusion (`% What section 4 concludes holds.`) |
| `-P(Xs)` (classical negation) | P's opposite form (`; opposite: *a thing* cannot fly`; `is` → `is not`, `can` → `cannot`, `applies` → `does not apply`) |
| facts in a section | facts citing it (`rock beats scissors, as stated in the … Act at section 3(a)`) |
| `#abducible p(...)` in a section | `; assumable` |
| `false :- Body` | an integrity constraint, `it must not be true that …` (LE2 le_summary.md §3.3): as in s(CASP), a case whose facts meet it is inconsistent and answers nothing (until 15 September 2026, a query `denial_1` every scenario expected to have no answer — convention N1) |
| `blawx_diseq`, `blawx_comparison`, `date_compare`, `duration_compare`, `#>=` … | comparisons |
| `date_add(A, D, B)` | an assignment in the direction the bound variables allow (`M = T - N`) |
| `date(T)`, `datetime(T)`, `duration(T)` | the number T: seconds since 1970, as Blawx stores them |
| `blawx_today`, `blawx_now` | a fact of the day the twin was built (the oracle uses the same clock) — approximated |
| `blawx_as_of`, `blawx_during`, `blawx_not_interrupted` per predicate | left out (the temporal boilerplate; nothing in a project reads it — the ledger counts it) |
| `blawx_becomes`, `blawx_initially`, `blawx_ultimately` and their rules | one residue block per section: a value events change is an LPS fluent, or lib/temporal's periods |
| `findall` with Blawx's list predicates | residue |
| a call to a predicate Blawx's reasoner does not define (`datetime_add`, `not_after` in the OAS Act) | residue, saying that the rule never applies in Blawx |
| a rule needing its own conclusion (`business(X) :- business(X), …`) | left out: it adds nothing in the least model or the stable models, and a Prolog reading would loop |
| a test's facts, `?- query.` | a scenario and a query; the expectation is Blawx's answer (`?- not G.` → `G` expects no answer when Blawx proves `not G`) |
| a template the verifier would report undefined, unused or unread, because the source is so or because the clauses that use it are residue | the ledger's Note column says which (`template_notes/7`: read or defined only by residue blocks, facts nothing reads, a declaration never used; a reading found by hand is a `hand_template_note/3`, the Bird Act's "except for pingu") |
| an input (a template no rule concludes) | `; undefined`, and a line of the view's "facts about the case" — unless it is `#abducible`, which the view leaves to the result's unknowns (23 September 2026: the view listed it, and the verifier reported it) |
| a test's `#abducible`s, a symbolic answer | the expectation kept as a pending comment (Blawx's answers are hypotheses) |

### Defeasibility: the E2 question, answered on this corpus

Three projects use Blawx's defeasibility layer: the New Bird Act (section 3
defeats 2; 4 and 5 defeat 3), the OAS Act (section 4(1) defeats 3(1)) and
Rule 34 of the Legal Profession Rules (17 defeats between paragraphs (1)–(6)).
In every case the overriding sections conclude **different** things —
`flies` against `-flies`, `may_accept` against `must_not_accept`,
`may_be_paid` against its negation — never alternative values of one
conclusion. So `otherwise` (alternatives of one conclusion) does not apply,
and no priority construct is needed: Blawx's own layer is written as plain LE
rules. A defeasible rule carries its defeaters' failure as its guard, and a
defeater's conclusion is held per section:

```le
rule section_2 with provenance the New Bird Act at section 2:
a thing can fly if
    the thing is a bird
    and it is not the case that the thing cannot fly under section_3.

rule section_3 with provenance the New Bird Act at section 3:
a thing cannot fly under section_3 if
    the thing is a penguin
    and it is not the case that the thing can fly under section_4
    and it is not the case that the thing can fly under section_5.
```

This is the "s(CASP) with the layer written as LE rules" option of §7.4,
and on this corpus it needs no s(CASP): the defeat graphs are acyclic, so
the negation as failure is stratified and the Prolog target answers as
Blawx does. A cycle of defeats would need the s(CASP) target; none occurs.

## Fidelity

Two sources of expectations, both answered by Blawx's reasoner:

- **the projects' own tests** (41). Most of them state no facts — they are
  the scenario editor's starting points — so they check little beyond
  "nothing without facts";
- **cases written from the rules** (`blawx_cases.pl`): for each rule, a case
  meeting every positive condition (individuals named after their types,
  `person_a`; numbers at the boundary of their comparisons), each near miss
  (one fact left out; one comparison missed by one), and for a defeasible
  rule the case with each defeater's own case added. Capped at 10 per rule
  and 90 per project.

*Results (14 September 2026):* the 41 tests of the fifteen projects (Blawx
answers 14 with something, 16 with nothing, 10 end in an error in Blawx — the
OAS Act's queries of `according_to/2` — and one asks nothing) and 167
generated cases give **163 expectations, all of which the twins meet**; 21
more are kept as pending comments, each with its reason (abductive tests,
symbolic answers, answers that hold only if Blawx assumes an `#abducible`
fact, the list aggregate). (Revised 15 September 2026: the Logical
Constraints inconsistency is no longer pending — LE has integrity constraints
now, and its test is met.)

| Project | Rules | Blawx tests | Generated cases | Expectations | Pending | Pass / fail | Ledger (enc/approx/residue) |
|---|---|---|---|---|---|---|---|
| `beard_tax` | 5 | 1 | 12 | 13 | 0 | 13 / 0 | 17/0/0 |
| `bird` | 6 | 4 | 13 | 17 | 0 | 17 / 0 | 25/0/0 |
| `covid_test` | 1 | 3 | 0 | 3 | 0 | 3 / 0 | 18/0/0 |
| `life_act` | 0 | 2 | 0 | 0 | 0 | 0 / 0 | 5/0/5 |
| `list_demo` | 0 | 1 | 0 | 0 | 1 | 0 / 0 | 6/0/1 |
| `logical_constraints` | 0 | 1 | 0 | 1 | 0 | 1 / 0 | 9/0/0 |
| `mortality` | 1 | 1 | 1 | 2 | 0 | 2 / 0 | 7/0/0 |
| `net30` | 1 | 1 | 0 | 1 | 0 | 1 / 0 | 7/0/0 |
| `numerical_constraints` | 3 | 1 | 11 | 11 | 1 | 11 / 0 | 11/1/0 |
| `oasa` | 13 | 16 | 15 | 20 | 1 | 20 / 0 | 58/11/5 |
| `r34` | 42 | 1 | 90 | 64 | 16 | 64 / 0 | 142/1/2 |
| `rps` | 1 | 3 | 9 | 11 | 1 | 11 / 0 | 19/1/0 |
| `siblings` | 2 | 4 | 7 | 10 | 1 | 10 / 0 | 13/1/0 |
| `wills` | 2 | 1 | 9 | 10 | 0 | 10 / 0 | 10/0/0 |
| `wills_tutorial` | 0 | 1 | 0 | 0 | 0 | 0 / 0 | 3/0/0 |
| **total** | 77 | 41 | 167 | 163 | 21 | 163 / 0 | |

"Rules" counts the Act's rules as written (not the rules linking a section's
conclusion to the plain one). The Covid Test and Net 30 rules compute with
dates (`date_add`), which the case generator does not solve, so their only
expectations are the projects' own tests; the Life Act and the Lists
Demonstration have none that can be active (events and list aggregates are
residue), and the Logical Constraints' one test is the inconsistency itself
(no answer, in Blawx and in the twin).
Every twin loads without errors and runs in the `--with-extensions` suite in
about three seconds altogether.

## Findings

- **Blawx's own exception does not take effect.** The New Bird Act's section
  5 reads "…, except for pingu" (a span of the text); Blawx encodes the span
  as `holds(sec_5__span_pingu_section, -blawx_applies, sec_5_section, pingu)`
  and section 5's applicability as `blawx_applies(sec_5_section, A) :- not
  -blawx_applies(sec_5_section, A)`, but nothing derives `-blawx_applies`
  from the span's `holds`, so section 5 applies to pingu and pingu with a
  jetpack flies. The test `pingu_with_jetpack_cant_fly` says in its comment
  that it expects the opposite; Blawx's reasoner (and so the twin, which
  follows the code) answers that pingu can fly. The twin makes the gap
  visible: its fact `section_5 does not apply to pingu under section_5_pingu`
  is one no rule reads (the verifier says so), and `section_5 does not apply
  to …` is an opposite form nothing concludes.
- **A circular rule empties a predicate in s(CASP).** Rule 34's section
  9(a) has `according_to(sec_34__subsec_9__para_a_section, business, B) :-
  business(B), B \= practicing_as_a_lawyer` (its author's comment: "This is
  hopelessly circular, but it is what the law says"). With it in the
  program, `library(scasp)` 1.1.4 proves nothing to be a business — not
  `widget_sales`, stated as a fact in the Act's root — so every rule reading
  `business` fails in Blawx; without it, the stated businesses are
  businesses. The rule adds nothing in the least model or the stable models,
  so the twin leaves it out (the ledger says so), and the generated cases are
  answered by Blawx's program without it (the ledger says that too). A
  small program with the same loop (`b(x). b(X) :- b(X), X \= y.`) answers
  `x`; the loop through Blawx's `holds`/`according_to` layer does not.
- **s(CASP) merges constants ending in `_<digits>`.** In `library(scasp)`
  (the 2026 pack), an atom such as `x_1` comes back as `x`: `p(x_1)`
  answers `p(x)`, and `x_1 \= x_2` fails. The generated cases name their
  individuals `person_a`, `person_b` for that reason; a Blawx user naming
  objects `bob_1`, `bob_2` would meet the same merge.
- **OAS Act, v1.6.22:** the rules of section 3(1)(b)(i), (b)(ii) and
  (c)(ii) call `datetime_add/3` and `not_after/2` and compare with
  `date(1977,7,1)`, none of which the release's reasoner defines (its date
  predicates take seconds): those rules never apply in Blawx. Ten of the
  project's sixteen tests query `according_to/2`, which is not defined
  either, and end in an error in Blawx; they carry no expectation.
- **The Logical Constraints example** is inconsistent by design (sections
  2 and 4 give Bob two ages, section 3 forbids it): s(CASP) has no model, so
  Blawx answers nothing to any query. The twin states section 3 as an LE
  integrity constraint (`it must not be true that a person is a person and
  the person is a number years of age and …`), so it answers nothing too, and
  the explanation of the empty answer is the constraint and the proof of its
  conditions. (Before LE had integrity constraints, the twin answered 40 and
  50, and a query `denial_1` named the violation; both expectations were
  pending. This example is what showed that the convention lost meaning.)
- **Blawx's generator writes clauses that do not parse.** Two are in the
  temporal boilerplate (Rock Paper Scissors: `-throwA,B,C),…`) and are left
  out with it; two are the rules of Rule 34's paragraphs (4) and (5), whose
  "no law-related service" condition came out as `not
  service(S)provides(BE,S)law_related(S)`. s(CASP) skips a clause that does
  not parse, so in Blawx those paragraphs never let a practitioner accept an
  appointment; the twin keeps them verbatim as residue blocks that say so,
  and its answers, like Blawx's, are those of the Act without them.
- **A date written `datetime(2000,1,5,0,0,0)`** (the Covid Test's `old_test`)
  is not a number to Blawx's date predicates, so the rule fails on it; the
  twin keeps it as text, and fails the same way.

## Decisions and gaps

- **Wording.** The templates are Blawx's `#pred` sentences, which Blawx
  writes from the author's words in the blocks; they are kept, with LE's
  possessive, sentence-ordered places, and citations written with
  underscores (`s3_1_a`) because LE splits a word at a parenthesis or a
  hyphen and writes the pieces spaced. The section-scoped templates read
  `... under section_3`; a section's LE constant is its id without Blawx's
  decoration.
- **Dates** stay numbers of seconds (Blawx's representation). A reader wants
  ISO dates; converting would change nothing in the logic but every value
  in the scenarios, and Blawx's dates are instants (7:00 UTC for a Mountain
  midnight), not days.
- **Not translated** (residue, with the source kept verbatim): the event
  calculus of the Life Act (its two tests query `blawx_during`, which the
  twin does not have: no expectation), Blawx's list aggregates (Lists
  Demonstration), the OAS Act's date rules and Rule 34's two broken clauses
  (these never apply in Blawx, so the expectations reading them stand).
- **Not covered:** Blawx's scenario-editor data (`fact_scenario` JSON, empty
  in all fifteen examples), its interview ("bot") and its Akoma Ntoso output
  (the Act's text is cited as markdown, sections as locators).

# s(CASP) and Prolog → Logical English (Phase 2c, first half)

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

The translator of the design notes `roadmap.md` §5.7 for s(CASP) and
plain Prolog programs, and in particular for **LE1's own s(CASP)
translations** — the nearest thing to an LE1 → LE2 migration corpus. The
reading itself is LE2 core (`le_writer:prolog_file_to_ir/3`, LE's s(CASP)
target read backwards: see LE2's `docs/dev/migration.md` §2 and
`docs/user/reference/scasp.md` §13); this directory adds what a *source file* says
around its program, the fidelity oracle and the twins. Blawx, which
generates s(CASP), has its own translator in `../blawx/`.

| File | What it does |
|---|---|
| `scasp_source.pl` | reads a source: its terms (and the statements s(CASP) does not read or only clingo means, kept with their text) with their lines and variable names (s(CASP)'s operators), LE1's scenarios (`/* Scenario x … % */`, commented out, or live between `/* Scenario x */` and `/* % */`), its `?-` queries, and LE1's metadata (`source_lang/1`) left out |
| `scasp_twin.pl` | the migration: the core reader's IR, the scenarios with their rules, the expected answers from **s(CASP) on the source**, LE1's dates and `is_days_after/3`, the ledger |
| `corpus.pl`, `build.pl` | the corpus (the sCASP pack's `test/le_programs` and four classics of `test/all_programs`; the pack is https://github.com/SWI-Prolog/sCASP, Apache License 2.0, copyright 2019 Joaquin Arias) and the build into `LogicalEnglish2/examples/migration/scasp/` |
| `scasp_import.pl` | the File ▸ Open adapter for `.pl`, `.scasp`, `.lp` (LE2's `le_import.pl` registry, `migration/le_importers.pl`) |
| `test_scasp.pl` | plunit: the source reader, the oracle, every twin, the adapter |

## How to run

The s(CASP) pack must be installed (`pack_install(scasp)`); from the root of LE2:

```sh
./myswipl.sh -q migration/scasp/build.pl                    # the corpus
./myswipl.sh -q migration/scasp/build.pl -- some.pl other.pl
./myswipl.sh -q -g run_tests -t halt migration/scasp/test_scasp.pl
```

## The mapping

Core (the reader): `#pred` wording → templates (`@(X:type)` names the place;
an unannotated predicate's place takes the type of an annotated place its
variable fills in the same clause); `-p` → p's opposite form; `#abducible` →
`; unknown`; a denial → an integrity constraint, `it must not be true that …`
(LE2 le_summary.md §3.3; it was a query `denial_<n>` every scenario expected
to have no answer, convention N1, until 15 September 2026); `#>`… → comparisons; `?-` → queries; `is_a/2` →
LE's own form; `[H|T]` patterns → residue. This translator:

| Source | Twin |
|---|---|
| an LE1 scenario (either form) | a scenario; its rules are rules of the scenario |
| each `?-` query | a query, asked in every scenario |
| the expected answers | **s(CASP)'s own answers on the source** plus the scenario (library(scasp), in a process of its own); a constraint answer, or an adjudicated one, is pending with its reason |
| LE1's Unix-time dates (`1633737600.0` in a `date` place) | dates (`2021-10-09`) |
| LE1's `is_days_after/3` (called, never defined) | LE2's `*a date* is *a number* days after *a date*`; the oracle gives the source LE1's meaning (86400 s a day) — unless the program defines it itself (`obligation`) |
| a program's own `forall/2` (by double negation through `wrong/2` and `once/1`) | LE's universal; the oracle runs the source's universals as a counterexample search (Lloyd–Topor), since s(CASP) has neither Prolog's `forall/2` nor `call/1` |
| a predicate the source declares `dynamic` and gives no clause, that its rules or queries read | a **scenario element** (`; undefined`): the data a scenario supplies, as LE1 meant by declaring it dynamic (23 September 2026; before, the verifier reported each one undefined) |
| what the source leaves (a predicate read and defined nowhere, an LE1 built-in s(CASP) lacks such as `has_as_head_before/3`, a declaration never used, facts nothing reads, a fact with a variable, rules not stratified, a predicate defined only by a scenario's rule) | as in the source, and **said in the ledger's Note column** (`source_diagnostics/6`), so that every verifier warning left on a twin is explained there; a reading found by hand is a `hand_note/3` (the nested `that` sentences of `obligation`, which LE2's parser reads the wrong way round) |
| a clingo-only statement (choice rule `{a;b}.`, disjunctive head `a ; b.`) or one that does not read (`1 { … } 1`, `#count`, `1..n`, `:~ … [w@p]`, `#const`) | a residue block `not_scasp_<n>` with its text and line (`scasp_source.pl` keeps them as `'$not_scasp'(Kind, Text, Line)`); expectations reaching what its head names are pending, and all of them when it names nothing |

## Results (14 September 2026)

LE2's documents of that month name version 1.1.4 of the s(CASP) pack
(`docs/user/reference/scasp.md` §8).

| Twin | Source | Scenarios | Expectations passing | Pending | Ledger (enc/approx/residue) |
|---|---|---|---|---|---|
| `citizenshiptrust` | LE1 | 4 | 4/4 | 0 | 20/0/0 |
| `criminaljustice` | LE1 | 2 | 2/2 | 0 | 26/0/0 |
| `family_le` | LE1 | 1 | 1/1 | 0 | 5/0/0 |
| `impossibleancestor` | LE1 (a rule in a scenario) | 2 | 2/2 | 0 | 9/0/0 |
| `isdapermissioncorrected` | LE1 (sentences as values) | 1 | 1/1 | 0 | 13/0/0 |
| `itispermittedthat` | LE1 | 1 | 1/1 | 0 | 13/0/0 |
| `list` | LE1 (own forall, list patterns) | 1 | 1/1 | 0 | 11/0/1 |
| `loanwithcure` | LE1 (dates) | 1 | 0/0 | 1 (adjudicated) | 16/0/0 |
| `minicontract` | LE1 | 1 | 1/1 | 0 | 11/0/0 |
| `obligation` | LE1 (its own date arithmetic) | 1 | 0/0 | 1 (a constraint answer) | 19/0/0 |
| `simplerps` | LE1 | 1 | 1/1 | 0 | 8/0/0 |
| `subset` | LE1 (own forall) | 2 | 2/2 | 0 | 8/0/0 |
| `turingcomplete` | LE1 | 1 | 1/1 | 0 | 14/0/0 |
| `birds` | sCASP classic (classical negation) | 1 | 1/1 | 0 | 16/0/0 |
| `family` | sCASP classic | 1 | 1/1 | 0 | 27/0/0 |
| `classic_negation_inconstistent` | sCASP classic | 1 | 1/1 | 0 | 2/0/0 |
| `abdbirds` | sCASP classic (abducibles) | 1 | 1/1 | 0 | 8/0/0 |

21 of 21 expectations reproduce s(CASP)'s answers on the sources; two more
are pending with their reasons. `escrow-scasp.jump` and `bec_theory.incl` of
`le_programs` are not Prolog files and are not in the corpus.

**The adjudication (`loanwithcure`).** The source calls `is_days_after/3` and
does not define it, so s(CASP) ran the source with the oracle's definition
(the table above). With it, s(CASP) answers that the borrower
defaults on 2016-06-06, yet the program's own cure rule holds on that date
(payment on 2016-06-05, notice on 2016-06-06: `cures_the_failure_of_on_or_before(the_borrower, obligation2, …06-06)`
succeeds when asked alone), so by the program's rules the default's
not-cured condition fails. The likely cause is the pack's constructive
negation over the anonymous variable in `is_that/2`: a reading made here by
hand, and this repository records no report of it to the s(CASP) authors.
The twin gives no default. The expectation is kept, pending, with that reason; the
twin is never the oracle.

## What building this found in LE2 core (fixed there)

- The s(CASP) **target** wrote universals as Prolog's `forall/2`, which
  s(CASP) rejects; opposite forms as separate predicates with vacuous
  constraints instead of classical negation; scenario elements as
  abducibles; and LE's own records (the ontology record, flip expectations,
  services) into the unit as facts. All four now follow
  `docs/user/reference/scasp.md` §4, and the round trip LE → s(CASP) → LE → s(CASP)
  gives the same program for 87 of the 93 core programs the target can emit
  (`testing/scasp_roundtrip.pl`, 15 September 2026: a non-numeric `is
  different from` is now s(CASP)'s `\=`, and a program with a construct
  s(CASP) cannot lower is refused rather than emitted with `true` in its
  place).
- Query answers showed a sentence-valued argument as a Prolog term
  (`designates_that('Alice', occurs_at(…))`); they show its words now.
- Expected answers wrote quoted text in quotes (`”article_7_(_3_)”`), which
  never matched LE's answers; text is written bare in answers now.
- A scenario's rule could not be passed to `le_migration` as a source test
  line (`rule(H, B)` now is).
- The naive wording: propositional predicates (`rain`) failed; a
  third-person verb (`flies`) is `*a thing* flies`, not `is a flies`; a
  one-letter variable name says nothing (`*a thing*`, not `*a x*`); the
  reader writes in the program's language whatever the process's is.

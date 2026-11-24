# Catala → Logical English, and back (Phase 3c)

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

The translator of the design notes `roadmap.md` §5.4 and §8, Phase 3c, for
**Catala** (Inria's language for laws, in English and in French). A Catala
program is literate: law text and code side by side, the code made of
*scopes* (one calculation each: its inputs, its outputs, their definitions,
exceptions between definitions) and *test scopes* that assert what the law
should produce. Decision 3 of the October plan: Catala is read directly (its
surface language, not its Python output), and the French programs come out
in Français Logique, which this phase polished first (below).

The examples are Apache-2.0: the twins are published in LE2's
`examples/migration/catala/`, with attribution.

**Where it stands (9 October 2026)** — see [Results](#results) and the work left, done on [7 October](#the-work-left-7-october-2026), [8 October](#the-work-left-8-october-2026) and [9 October](#the-work-left-9-october-2026). **Six whole twins**, no residue, every answer agreeing with Catala's interpreter: section 132 (8), the SMIC (29), the BMAF (6), section 121 for one and two persons (6), family-benefit eligibility (4), and the rental calculation of the CNAF's housing allowance (`aides_logement`, scope `CalculAidePersonnaliséeLogementLocatif`, 49 of 49 answers of its 9 tests). **Two more programmes that do not answer yet**: the housing allowance's two eligibility scopes (`eligibilite_apl`, `eligibilite_al`), read and lowered but waiting on a list's cardinality, a list mapped or filtered, and a rule body core LE cannot open a group with. The gate: 46 of 46.

| File | What it does |
|---|---|
| `fetch_sources.sh`, `corpus.pl` | `catala-examples` at the commit pinned, the Catala team's own build of 22 August 2026 (the newest published package), OCaml 5.3 from Debian's packages unpacked as a user (no root), zig as the C compiler; the programmes written as twins |
| `catala_reader.pl` | the reader: Catala's literate files after the compiler's own lexer and grammar (`lexer_en`, `lexer_fr`, `parser.mly`), both dialects into one tree |
| `catala_lower.pl` | the lowering: a scope's variables as rules in the shape of RuleSpec (the twin builder of Phase 3a writes the program, as for Phase 3b), the exception trees as ordered cascades, sub-scopes copied under their instance's name, test scopes as test cases |
| `catala_gate.pl` | the gate: the reader's exception tree of every variable against the compiler's (`catala exceptions --output-format=json`) |
| `catala_build.pl` | the twins: lowering, the oracle (each test scope run by `catala interpret`; generated cases for a programme without tests), the twin builder, the originals under `sources/` |
| `catala_import.pl` | File ▸ Open of `.catala_en`, `.catala_fr`, or a zip of a program with its tests |
| `catala_export.pl`, `catala_roundtrip.pl` | File ▸ Export to Another System ▸ Catala, and its check: every twin exported and its test scopes run by Catala's interpreter |
| `test_catala.pl` | plunit: the reader in both dialects, the lowering, the twins, the import, the export |

## How to run

```sh
migration/catala/fetch_sources.sh
./myswipl.sh -q migration/catala/catala_gate.pl
./myswipl.sh -q migration/catala/catala_build.pl            # every programme
./myswipl.sh -q migration/catala/catala_build.pl -- smic    # one
./myswipl.sh -q migration/catala/catala_roundtrip.pl
./myswipl.sh -q -g run_tests -t halt migration/catala/test_catala.pl
```

## The mapping

| Catala | Lowered as (RuleSpec shape) | In Logical English |
|---|---|---|
| `declaration scope S`, `input x content money` | a rule of kind `input`, typed | `the x is *an amount*`, a fact the scenario states |
| `output y content money`, its definitions | a derived rule, its formula the cascade of the definitions | `the y is *an amount*` |
| `condition c`, `rule c under condition … consequence fulfilled` | a judgment | `the case <c>` (English), `la condition … est remplie` (French) |
| `context` variable | a derived rule a test may state (`overridable`) | a rule, and a fact a scenario may state |
| `label L definition …` / `exception L definition …` | exceptions first, then the definitions they are exceptions to: `if exc: … elif base: …` | one rule, its parts joined by `otherwise` |
| a definition with no value in the other cases | an `if` with no `else` | a cascade without a last branch |
| `match x with pattern -- A : …` (no content) | `match x: 'A' => …` | `otherwise` |
| `x = A or x = B or …` | an `or` of equalities | `le code est dans ["A", "B", …]` |
| a sub-scope (`p scope S2`, `definition p.input …`, `p.output`) | S2's rules copied, named `p_…`; the caller's definitions of its inputs replace them | rules named after the instance |
| an input structure's fields | one input per field, `x_f` | facts |
| money, decimal, percentage, integer, date | numbers, `date("2019-01-01")` | numbers, dates |
| test scope (`#[test]`): `definition s.x equals …`, `assertion s.y = …` | a test case | a scenario |
| `definition x of child` (a parameter of a structure's type) | a rule whose subject is the parameter, an individual of the structure's type; the fields it reads are that type's inputs | `un enfant … remplit la condition droit ouvert si …` |
| a list input of structures (`input periods content list of Period`) | each element an individual of the structure's type, its being in the list an input judgment (`is_in_periods`) | `*a period* is in property ownage`, facts the scenario states |
| `f of l`, f a function of a list whose definition is the sum of a map over it | inlined: a sum over the elements of l (`sum_over`) | `the sum of each N such that the period is in … and …` |
| `résultat de S avec {…}.x`, S's x one definition without conditions | inlined: that definition, its inputs replaced by the arguments | the definition's conditions |
| durations: `20 an` in a date's addition, `730 day`, a date less a date | months added to a date; days | `*a date* is *a number* months after *a date*`, `… days after …` |
| a test asserting a definition of a parameter (`f.droit_ouvert de données.enfant1`) | one case per assertion, its subject the structure given | a scenario per child |
| a variable in states (`état formule`, `état taux_arrondi`) | one rule per state, the later reading the earlier; the last state the variable's own name; an input in states: its first state the input | `le taux loyer éligible formule`, `le taux loyer éligible` |
| a structure, an enumeration whose cases carry a value (`ReturnType`), as an input or a value | one fact per leaf, named by the fields and cases that lead to it; a list leaf a fact of each element (`is_in_…`); a structure-valued variable one rule per leaf, its definitions projected (through `match`, `if`, a structure built) | `the section121 two persons return type JointReturn person1 property ownage` |
| `x with pattern C content y and …` | the case, then y the value it carries | `the … other section 121 a sale is "MostRecent…" and …` |
| a date less a date compared with years or months | the later date compared with the earlier one moved by them | `a date N is 24 months after the second date and D <= N` |
| a `context` variable of a root scope | its rule's first part the value a test gives (`…_given`), otherwise its definition | `the gain cap given is …, otherwise …` |
| a function of a value (`dépend de aide_finale contenu argent`), in states | one rule per argument it is called with, per state, `; memorable` | `le traitement aide finale diminué de aide finale formule initiale` |
| a function declared outside the scopes (`déclaration f … égal à`), a sub-scope's function | inlined; the sub-scope's rule for that argument | |
| `décimal de`, `argent de`, `Date.accès_année de` | the value; rounded to the cent; the whole years from 1900, and 1900 | |
| a `selon … sous forme` whose cases answer yes or no | one condition, `x is in [...]` | `la résidence est dans [...]` |
| folds over a list, lists built inside a definition | residue, with the Catala text | a residue block |

The twin builder writes French templates for a French programme (`le brut
horaire est *un montant*`), with Français Logique's keywords; the article's
gender is the writer's guess (writer_words.csv), and the head of a French
noun phrase is its first word.

## Français Logique, polished first (decision 3)

Before the French twins: LE2's French was a machine-made draft. This phase
made it a working language (LE2, `i18n/`, status `pilot`):

- **Elision and contraction** (languages.csv, `elisions`, `contractions`):
  the tokenizer reads "l'autre personne" as "le autre personne", "d'une" as
  "de une", "au", "du", "aux" as "à le", "de le", "à les", "s'il" as "si
  il"; a dictionary cell may be written with the short forms; the writer
  writes them (never before an *h*, which may be aspirated); a test's
  expected answer may use either form.
- **An apostrophe after a letter never opens a string**, in every language
  (the Prolog tokenizer and the editor's): "the employers' fund is 'x'" was
  mis-read before too.
- **A template beginning with "le"** no longer gets a name the system
  reserves for its own predicates (`le_…`).
- **The dictionary reviewed** by a role-played French legal drafter: 71
  changes (keywords such as "sauf si", "il n'est pas vrai que", "attend les
  réponses", "au motif que"; 27 messages; the feminine endings), the French
  example rewritten in idiomatic French.

## Results

The gate: the reader's exception tree equals the compiler's for **46 of 46**
variables of the programmes' scopes (`runs/gate.txt`; 35 on 7 October). The
housing allowance's files are left out of the gate unless
`CATALA_GATE_ALL=1`: Catala's `exceptions` command takes some 4 GB and
minutes for each of its variables; that twin is checked by its 49
answers. All 83 English and
French files of `catala-examples` read (the 9 Polish ones are out of scope).

| Twin | Dialect | Ledger: encoded / approx. / residue | Expectations | Written back, on Catala's interpreter |
|---|---|---|---|---|
| `section_132` (26 U.S.C. 132(c)) | English | 7 / 2 / 0 | 8 of 8 (3 test scopes) | 3 of 3 tests |
| `smic` (salaire minimum, 2019–2024) | French | 2 / 1 / 0 | 29 of 29 (generated cases; 1 left out, a conflict in Catala) | 29 of 29 |
| `bmaf` (base mensuelle des allocations familiales) | French | 1 / 1 / 0 | 6 of 6 (generated cases) | 6 of 6 |
| `section_121` (26 U.S.C. 121) | English | 85 / 0 / 0 | 6 of 6 (one person and two persons) | refused, with its reason: a sum over a list of periods has no Catala form in the exporter |
| `prestations_familiales` (eligibility) | French | 11 / 2 / 0 | 4 of 4 (one case per child the test asserts about) | 4 of 4 tests (a definition that depends on a child) |
| `apl_locatif` (the CNAF's housing allowance, rental calculation) | French | 37 / 13 / 0 | 49 of 49 (its 9 test scopes) | refused, with its reasons: two cascades inside cascades the exporter does not read |

The *approximated* rows are the conflict notes. The ledgers count each
element once, so the encoded counts are lower than a first build's.

*Generated cases*: `smic` and `bmaf` have no test scopes of their own; their
cases are made from a grid (`corpus.pl`, `generated/4`: the middle of each
period their texts define, three regions for the SMIC), written as Catala
test scopes and run by the interpreter, whose answers are the expectations.
One of the 30 SMIC cases has no answer: for Mayotte in mid-2024 Catala stops
with a **conflict** between two decrees' amounts, because the example dates
the November 2024 decree's amount for Mayotte from 1 January 2024 (the
decree says 1 November). The case is kept, left out of the twin with
Catala's reason. A twin takes the first part of its cascade that applies
where Catala stops with a conflict: each variable where that can happen
carries a note in the ledger (found by the review, below).

What this says. The reader is exact (the gate), and the scopes made of
conditions, amounts, dates and enumerations translate whole, in both
dialects, both ways. Since 7 October the family benefits' eligibility is
whole too (definitions of a child, durations, a call of another scope), and
section 121's single-person scope (lists of periods, a sum over them). What
stays residue is in [the work left](#the-work-left-7-october-2026);
`allocations_familiales` and `aides_logement` are not written as twins yet.

## The work left, 7 October 2026

Of the roadmap's list (the design notes `roadmap.md` §8, *Phase 3c — work left*):

- **Item 1, definitions with a parameter: done** for a parameter of a
  structure's type. `prestations_familiales` is whole: its 3 residue blocks
  are rules about a child, and its test, which asserts `droit_ouvert` of four
  children, became four cases, all passing on Catala's interpreter.
- **Item 2(a), lists as facts and an aggregate: done** for a list input of
  structures and a function of a list defined as the sum of a map over it.
  Section 121's single-person scope translates, and its 4 tests pass.
- **Item 3, durations: done** in two units: months, added to a date (LE's
  *months after*), and days, a date less a date (LE's *days after*). Catala
  rounds a month added to the 31st up, LE to the month's last day: only a
  date at the end of a month can differ, noted here rather than in each
  ledger.
- **A call of another scope**, `résultat de S avec {…}.x`, is inlined when
  S's output is one definition without conditions (the age check of
  `France.VérificationÂgeSupérieurÀ`).
- **A defect found on the way**: the exception tree's labelled groups were
  collected with a `yall` lambda whose free variable is copied when the
  lambda is called rather than compiled, so a labelled definition could be
  lost depending on how the modules were loaded; the lambdas are now plain
  predicates (`labelled/2`, `subst_all/4`). The twins built before were
  checked again: none had changed.
- **Left**: section 121's two-person and two-pass scopes (15 blocks: a
  structure's list fields, the return type's enumeration with content, the
  merge of periods, which is a fold over a list), states (item 5), a
  `context` variable a caller replaces (item 6), and `aides_logement`,
  which uses all of these; the way back for a definition with a parameter.

## The work left, 8 October 2026

The *Left* item of 7 October, with what the last Catala video lists as
still to do (values over time, enumerations carrying a value, lists inside a
structure, the housing allowance, the way back of the rules about a child):

- **States (item 5): done.** One rule per state; an input in states is its
  first state (`loyer_principal_base`), the test setting it.
- **A `context` a caller replaces (item 6): done** for the programme's own
  scopes (a test gives the value: *… given*); in a sub-scope instance the
  caller's definition replaces it, as before. A sub-scope's input the
  caller defines is no longer marked as one a test may give.
- **Section 121's two-person scope: done.** Structures and enumerations with
  content as leaves (item 4), lists inside a structure's field, a value
  that is a structure projected leaf by leaf, the binding of `with pattern
  … content`, a date difference compared with years. The `PeriodMerge`
  scope the example leaves as a placeholder (`[]`, its own TODO) is an empty
  list: no rule. Section 121 is whole, 6 of 6.
- **The way back for a definition with a parameter: done.** The child is a
  structure, the rule a definition `of` it, each scenario an assertion
  about the child it describes; a number of months a Catala duration; a
  `context` written back as `context output`, a test's given value as the
  test's definition. `prestations_familiales` 4 of 4 on Catala's
  interpreter.
- **`aides_logement`, scope by scope: the first scope done.** The rental
  calculation (`CalculAidePersonnaliséeLogementLocatif`, with its
  contributions sub-scope and the archives of its scales since 2020) is
  whole, 49 of 49 answers of `tests_calcul_apl_locatif`. It needed: states,
  functions of an amount in states, top-level functions, casts, the year of
  a date, a match of yes-or-no cases as one condition (the other way made
  the twin builder run out of memory), `; memorable` on the states.
- **Found on the way, fixed:** the reader parsed a function's argument as a
  whole sum or product (`arrondi de x / y` as `arrondi de (x / y)`; Catala
  applies first); a label named `base` was taken for the unlabelled
  definitions; a `soit` that rebinds a name was ignored by the
  substitution; the oracle took a scope with outputs for a failure (it
  prints them instead of "successful") and enumerated every prefix of a
  failure's text (thousands of copies of each case); numbers were written
  with an exponent (`1.0e+04`), which the formula language does not read;
  the gate stopped on a nested unlabelled exception; a yall lambda's free
  variables again (the substitution of a function's argument).
- **Left:** the other scopes of `aides_logement` (eligibility, the
  allowance for owners and for residences, the global calculator: lists of
  dependants, the household's composition); folds; lists built in a
  definition; the way back for sums over lists and for nested cascades;
  the law's own assertions as integrity constraints (item 7); conflicts as
  constraints (item 8).

## The work left, 9 October 2026

The *Left* of 8 October, with items 7 and 8 of the roadmap's list.

- **Item 7, the law's own assertions as integrity constraints: written, and
  off by default.** A scope's `assertion` statements are not definitions, so
  they become constraints of the twin: a case that contradicts what the law
  asserts is refused, not answered. Five on `apl_locatif` (the dégressivité
  ceiling against the rent ceiling, the L832-3 fraction between 0.9 and 0.98,
  a room that is not also a shared tenancy, a count of dependants that is not
  negative, a calculation date within the archive's reach). The twin builder's
  `must_items/3` writes each one negated, since a constraint's body holding is
  the violation.

  They are written only when a build asks (`constraints(true)`), because
  Logical English checks every constraint when it answers a question: a
  constraint costs what its body costs, on every answer. The final aid of the
  housing allowance is a chain of six states, each reading the one before it
  two or three times, and it is already near the time limit. With those five
  constraints in the program — each reading nothing but parameters — four of
  the nine test scopes stopped answering: **49 of 49 answers with no
  constraints, 45 of 49 with five**, the same four scopes each time (three
  timeouts and one stack overflow). A twin's answers are the evidence it
  exists for, so the default keeps them and the ledger keeps its note. What
  this waits on is constraint checking that does not pay the program's cost
  again for each answer.
- **Item 8, Catala's conflicts as constraints: not done, and measured.** Two
  definitions of one variable at one level of the exception tree both
  applying is a conflict, where Catala stops rather than answering. Written
  as a constraint per pair, that grows with the square of a variable's
  definitions: a variable whose law was reissued every year has dozens, and
  one rule of `aides_logement` carried **814 constraints**. Bounding a level
  to four definitions left two — and both were pairs of *dated* versions of
  one definition (`date_courante` in 2020-10…2021-10 against
  2021-10…2022-10), which can never hold together, so they were never
  conflicts. And they would cost on every answer what item 7's five cost
  (above), on top of being mostly spurious. What item 8 needs is a form that
  states the conflict without being paid for on every answer, and that leaves
  out the pairs two dated versions of one definition make. Until then the ledger's note stands: where Catala would stop
  with a conflict, the twin takes the first definition that applies, and says
  so. The bounded enumeration is kept as `conflict_pairs/4`.
- **The oracle's cache: fixed.** It was keyed on the Catala files' text
  alone, so a change in the *translator* reused a cached verdict and the
  interpreter was never asked again — a case the lowering had just learned to
  read stayed `untranslated` for ever. The key now covers the translator's
  reading of the test scopes as well.
- **A test scope that asserts through its own variable: read.**
  `définition éligible égal à éligibilité.éligibilité` and then `assertion
  éligible` asserts the sub-scope's output through a local name;
  `output_of/4` follows that alias. Without it the housing allowance's
  eligibility tests carried no expectations at all.
- **A `match` arm that binds the value its case carries: read.**
  `-- C contenu v : body(v)` substitutes `contentof(E, C)` for `v`, as a
  projection of a structured value already did (`proj_arm/6`), so the
  payload's own leaves are the facts named after the case and the field. A
  yes-or-no match now also tolerates an arm whose payload its body ignores,
  and a payload used whole reads as its own leaf.
- **The other scopes of `aides_logement`: two more are programmes.**
  `eligibilite_apl` (`ÉligibilitéAidePersonnaliséeLogement`) and
  `eligibilite_al` (`ÉligibilitéAllocationLogement`, the other two test
  scopes of the same file). Residue 11 → 6 and 13 → 5. **Neither answers
  yet**, and for three reasons: `nombre de` (a list's cardinality) over a
  list input of structures, a list mapped or filtered (the dependants), and —
  the writer's limit, not the reader's — a rule body whose every leading
  condition is a negation. Core LE opens a nested group with one of its own
  plain conditions; when there is none, the writer falls back to an `all of`
  block of the extensions and the program no longer parses. Naming such a
  group as a judgment rule of its own is the way out, and is not written yet.
  The three remaining scopes (`apl_foyer`, `apl_accession`, `al_locatif`) and
  the global calculator are declared in `corpus.pl` but not built.
- **A twin whose program no longer parses still reports "0 writer
  error(s)".** The writer falls back to an `all of` / `either` block of the
  InsurLE extensions when it cannot open a nested group with a plain
  condition of its own, and records a remark
  (`issue(warning, needs_extensions, …)`) — but that remark does not reach
  the list `write_migration/4` returns, so the build cannot count it. The
  eligibility twins were caught by LE's own parse error on the generated
  program (`missing_template` for `all of`) and by their answers: a twin in
  that state answers nothing, or answers wrongly. The same fallback cost
  `universal_credit` 39 of its 146 answers
  (`../openfisca/README.md`).
- **Checked after these changes.** The gate: 46 of 46. The twins that were
  whole stay whole and keep their figures — `section_132` 8 of 8, `smic` 29
  of 29, `bmaf` 6 of 6, `section_121` 6 of 6, `prestations_familiales` 4 of
  4, `apl_locatif` 49 of 49 — and `test_catala.pl` passes all 8 of its
  tests.
- **Left.** The three reasons above; folds; lists built in a definition; the
  way back for sums over lists and for nested cascades; item 8's form.

## The work left, 10 October 2026

The *Left* of 9 October, and the one thing that was holding three scopes of
the housing allowance back at once.

- **A group core Logical English cannot open is now a rule of its own, and
  that was the blocker: done.** The writer's own limit — a nested group whose
  leading condition needs lines of its own (a negation, a universal, an
  aggregate) and that has no plain condition to open it — was met with an
  `all of` block of the InsurLE extensions, which core LE does not read, so
  the program stopped parsing and the twin answered nothing while reporting
  no error. The writer now **names such a group as a judgment rule of its
  own** (`le_writer.pl`, `hoist_blocks/4`): the group becomes a rule whose
  head is a judgment about the variables it shares with the rest of the rule,
  and its place in the rule becomes that one condition. A rule's body is a
  list of sibling conditions, where a leading negation is no trouble, so the
  group is written in core LE there, and nothing is lost: the judgment holds
  exactly when the group does. Its sentence names the rule it came from —
  *la condition 1 de l'aide finale est remplie pour un montant*. The pass
  reads the rules of a program, not its integrity constraints: a constraint
  whose body needed the same treatment would still be written with the
  block, which none of the constraints written so far does (each is a
  comparison of parameters, item 7 of 9 October).
- **Three more scopes of `aides_logement` are twins, and they answer.**
  `apl_foyer` (the allowance for a residence) **14 of 14**, `al_locatif`
  (the other allowance for a tenancy) **5 of 5**, `apl_accession` (the
  allowance for a purchase) 4 of 8. All three were "declared in `corpus.pl`
  but not built" on 9 October; what stopped them was the group above.
- **Which article an answer uses is no longer a difference.** `apl_foyer`
  reported 11 of 14 with three failures of the form *expected «la
  équivalence loyer éligible est 350», got «le équivalence loyer éligible est
  350»*. The gender was not wrong in either place: the twin writes the
  feminine article, the document elides it (*l'équivalence*), and a language
  has one expansion for `l'`, so the program is read back with the
  masculine. LE2's own answer comparison already read elisions and numbers
  the same way on both sides (`le_kbs.pl`, `unelide_words/2`,
  `same_number_word/2`); it now reads **every article of a language as one
  word** (`same_article_word/2`), which is what the parser already does with
  them ("the parser accepts every article of the class"). Three answers.
- **A build says what the writer remarked, not only what it could not
  write.** `catala_build.pl` counted issues of severity `error` alone, so a
  twin whose program no longer parsed still reported "0 writer error(s)".
  It now reports the warnings beside them, and prints each.
- **`nombre de` a list, and a list filtered: read, for lists of
  structures.** A list of structures is already a fact of each element
  (`is_in_…`): its cardinality is now a count over those elements
  (`count_over`, beside `sum_over`), and a variable defined as `liste de x
  parmi l tel que c` becomes **a judgment of each element** — it is in the
  list the filter reads, and the condition holds of it — so the filtered list
  needs no list at all. A function of a structure called on the element
  (`prise_en_compte_personne_à_charge de personne_à_charge`) reads as that
  same individual's own judgment.
- **What the housing allowance's own lists need, measured.** The two
  eligibility scopes still answer nothing, and the reason is not the writer
  any more: `ménage.personnes_à_charge` is a list of an **enumeration whose
  cases carry structures** (`PersonneÀCharge`: *EnfantÀCharge* or
  *AutrePersonneÀCharge*), not a list of structures, so the element has no
  structure type to be an individual of and the readings above do not apply.
  Its single pending expectation waits on two other blocks as well
  (`caractéristiques_prêt_l831_1_1 de propriété.prêt`: a function of a
  structure called on a *field path* rather than on the element). Both twins
  do now build with no writer error and no remark (residue 6 and 5).
- **Checked after these changes.** `section_132` 8 of 8, `smic` 29 of 29,
  `bmaf` 6 of 6, `section_121` 6 of 6, `prestations_familiales` 4 of 4,
  `apl_locatif` 49 of 49 — every twin that was whole stays whole — and
  `apl_foyer` 14 of 14, `al_locatif` 5 of 5, `apl_accession` 6 of 8 are new.
  The gate: 46 of 46. The example suite of LE2 runs these twins, so
  `apl_accession`'s two remaining disagreements are two red tests there
  (`testSuiteCoreStatus.txt`): either the rule above is split and the
  disagreements go, or the programme comes out of `corpus.pl` until it is.
- **A rule of 912 variables was not written at all, and the twin went
  quietly wrong: fixed.** `apl_accession` reported *4 of 8 answers, 2 writer
  errors*, and the two errors were the cause of all four disagreements (*la
  mensualité éligible*: 533,91 expected, 650 given — the uncapped amount).
  The rules that could not be written are the ceiling on a monthly payment,
  `calcul_plafond_mensualité_d832_10_3` read at two dates: each is one rule
  of **912 variables** (the whole table of ceilings by zone, by household and
  by number of dependants, inlined), and the writer names the variables of
  one type with one or two letters — 24 and 576 — so it ran out and
  `clause_naming/5` failed. The writer now reaches for a third letter
  (`pick_id/4`), and `apl_accession` answers **6 of 8**. A rule that large is
  still unreadable: what it wants is the OpenFisca reader's device, a value
  that grows past a size becoming a step of its own, which the Catala
  lowering does not have.
- **Left.** `apl_accession`'s last two disagreements; a rule too large to
  read (the ceiling above) wants a step of its own; lists of an enumeration,
  for the two eligibility scopes; folds; lists built in a definition; the way
  back for sums over lists and for nested cascades; item 8's form.

The review is a review that is not published.
Its follow-up made amounts round to the cent and `round of` to the unit as
Catala does, kept two scopes of one programme apart, read assertions on
conditions and left out (with the reason) a test whose assertions it cannot
read, noted every possible conflict in the ledger, gave residue blocks the
whole Catala text, made citations open the Catala file, and stopped the way
back from exporting a twin with residue. Open: a `context` variable a caller
replaces (the twin gives both values), the law's own assertions (Logical
English's integrity constraints are built, not wired), a twin that refuses
to answer where Catala finds a conflict.

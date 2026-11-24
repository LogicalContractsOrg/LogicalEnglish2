# OpenFisca and PolicyEngine → Logical English (Phase 3b)

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

The translator of the design notes `roadmap.md` §5.5 and §8, Phase 3b, for
**OpenFisca** (the tax-and-benefit microsimulation framework; the country
template, France, New Zealand…) and **PolicyEngine** (its 2022 fork, with
the models of the United States and the United Kingdom). A country package
is Python: a `Variable` class per quantity, with dated `formula` methods
written over NumPy arrays, parameters in YAML, and tests in YAML. A
*programme* — the variables one root variable reads, within its folder of
the package — becomes a Logical English program, each variable a rule
citing its label and reference, each parameter dated facts citing its
reference, the package's tests as scenarios. And a Logical English
program can be written back as an OpenFisca package (one module) that
openfisca-core runs.

All the packages are AGPL-3.0, so the twins stay in this repository
(`examples/migration/{openfisca,policyengine}/`; decision 2 of the October
plan).

**Where it stands (13 October 2026; first written 5 October)** — five
rounds of 12–13 October took the list of 11 October and the two programmes
of the October plan that were never built: **six twins of
`openfisca-france`** now (the income tax, **2,286 of the 2,302 expectations
it checks, with no residue left**; the housing allowance, 50 of 50, and its cross-check with the
Catala twin of the CNAF's programme, 216 of 216; the RSA and prime
d'activité, 28 of 28; the family benefits and the payslip contributions,
both new and both still behind their residue), their sentences French
throughout, and no writer error in any of them. The English-language
twins were rebuilt with the same reader and none moved against its engine
(the country template 32 of 32, Child Benefit 4 of 4, Universal Credit 219
of 222 — 26 expectations more than before, with one newly reached case that
differs in the fifteenth decimal; SNAP 361 of 409 of this
checkout's cases, the CTC 56 of 57, the EITC 46 of 50). See [the fourth round](#the-fourth-round-1213-october-2026).

The rest of this document is the record of each round, newest last; the work left of the roadmap, done on 7 October: see [below](#the-work-left-7-october-2026); and on 8 October: [below](#the-work-left-8-october-2026). Six English-language twins, 694 of 748 checked expectations against the packages' own engines (598 of 598 on 8 October, 366 on 7 October: the cases a twin can state went up, [below](#the-income-tax-twin-answers-its-cases-11-october-2026)); residue 9 blocks (19); the way back on openfisca-core: five twins, every case (191 of 191). Since 9 October, **`openfisca-france` as well** (Phase 3b′: [below](#openfisca-france-phase-3b-steps-1-to-4-9-october-2026)) — 682 of 988 of its computed variables translate, and its income tax is a twin in Français Logique, with values of other years and roles in a tax household, which agrees with 1,585 of the 1,944 expectations of the package's own tests (11 October). Its housing allowance is a twin too (39 of 39, with the 36,682-row table of zones by commune as a CSV file), cross-checked with the Catala twin of the CNAF's programme: the two encodings differ only in where they round to the cent ([below](#steps-5-to-7-of-phase-3b-the-housing-allowance-its-cross-check-with-catala-the-rsa-11-october-2026), 11 October, afternoon).

> The figures for the six English-language twins were measured where their
> engines were installed. This repository's `.cache/venv` holds one
> environment per engine now (see *How to run*), and a machine that has not
> installed them cannot reproduce those figures — it reports
> `ModuleNotFoundError`, not a translation failure.

As first written (5 October) — six twins (the country template;
SNAP, EITC and CTC from `policyengine-us`; Universal Credit and Child
Benefit from `policyengine-uk`): every expectation the twins can check
passes (99 of 99), against the answers of the packages' own engines; most
test cases still wait for residue, and no programme's root variable (the
benefit itself) is checked yet. Written back, the country template's and
the EITC's modules pass every case on openfisca-core, CTC's all but one.
See [Results](#results).

| File | What it does |
|---|---|
| `fetch_sources.sh`, `corpus.pl` | the packages at the commits pinned (country template `9877d0f`, policyengine-us `b44d435c`, policyengine-uk `b5b0923`), cloned into `.cache/` and installed with their engines into `.cache/venv`; the programmes written as twins |
| `of_classify.py` | step 0: the shapes of a package's formulas, mechanical or residue |
| `of_extract.py` | the reader: loads the package (so every parameter has the engine's own values, PolicyEngine's uprating included), follows the variables a programme reads, and writes each formula in the expression language of the RuleSpec translator's reader, plus the tests in RuleSpec's test shape |
| `of_static.py` | the same reader on files alone, for an upload (File ▸ Open): the variables' Python read with `ast`, the parameters as OpenFisca reads its YAML |
| `of_oracle.py` | the oracle: each test run on the package's own engine (openfisca-core, or PolicyEngine's policyengine-core); the values the engine computes for the variables just outside the programme are stated in the twin's scenarios |
| `of_run.py` | one load of a package for several programmes: extract, then run the oracle |
| `of_build.pl` | the twins: the RuleSpec translator's twin builder (`../rulespec/rulespec_twin.pl`) on the reader's output, the originals under each twin's `sources/` |
| `of_import.pl` | File ▸ Open of OpenFisca or PolicyEngine code (a `.py` of variables, or a zip of a package) |
| `of_export.pl`, `of_roundtrip.pl`, `of_roundtrip_run.py` | File ▸ Export to Another System… → OpenFisca, and its check on openfisca-core |
| `test_openfisca.pl` | plunit: the reader's shapes, the static reader, the import, the export |
| `results.py` | the table below |

## How to run

```sh
migration/openfisca/fetch_sources.sh              # packages, engines, venv (pip)
./myswipl.sh -q migration/openfisca/of_build.pl            # every programme
./myswipl.sh -q migration/openfisca/of_build.pl -- snap    # one
./myswipl.sh -q migration/openfisca/of_roundtrip.pl -- <twin.le>...
./myswipl.sh -q -g run_tests -t halt migration/openfisca/test_openfisca.pl
```

PolicyEngine US takes about seven minutes to load on the build machine and
its oracle about an hour for SNAP (722 tests): `of_build.pl` loads each
package once for all its programmes; `OF_SKIP_EXTRACT=1` rebuilds the twins
from the last extraction.

**One environment per engine (9 October 2026).** The line above that installs
the three packages into one `.cache/venv` no longer resolves: pip refuses
`openfisca-core[web-api]==45.0.5` together with
`openfisca-country-template==8.1.0`, which pins a different core. That is the
same split that already sent `openfisca-france` to an environment of its own
(it needs core 44), so each engine now wants its own: `.cache/venv` for the
PolicyEngine packages, `.cache/venv-fr` for France, and the country template
beside them. `of_roundtrip_run.py` also needs PyYAML in whichever
environment runs it. Until an environment has them, `test_openfisca.pl`
fails its two export tests with `ModuleNotFoundError` rather than a
translation error — the figures below were measured where the engines were
installed, and a fresh machine has to install them before it can reproduce
them.

## The mapping

The reader writes each variable in the shape of a RuleSpec rule, so the
twin builder of Phase 3a writes the program (`../rulespec/README.md` has
the LE side of the mapping). What the reader does with the Python:

| OpenFisca / PolicyEngine | Written as |
|---|---|
| `entity = SPMUnit`, `definition_period = MONTH`, `value_type = float/bool/str/Enum` | a rule of entity SpmUnit; a value, a yes-or-no judgment, or a code |
| `person("salary", period)`, `unit.household("x", period)` | the variable; a projection to the group reads the case's own value (noted) |
| `unit.sum(unit.members("x", period))`, `.any(…)`, `.all(…)`, `nb_persons()` | a sum, a count, a comparison of counts over `*a person* is a member of *a unit*` |
| arithmetic on the members' values (`sum(unearned * share)`, `any(ages < 8)`) | a helper rule per person (`member_part_of_<variable>`, `counts_for_<variable>`), summed or counted |
| `parameters(period).gov.x.y`, `…[key]`, `…[region][size]` | a dated parameter; a table; a `match` on the first key over a table per key |
| `scale.calc(x)` (marginal rates), a single-amount scale | the brackets written out: rate × the part of x in each bracket; the amount of the highest threshold reached |
| `where`, `select`, `max_`, `min_`, `clip`, `np.round(x, n)`, `np.ceil`, `np.floor`, `abs`, `&`, `|`, `~`, `is_in` | `if`, `max`, `min`, `round`, `ceil`, `floor`, `abs`, `and`, `or`, `not`, `or` of equalities |
| `if <condition>: return …` and `if/else` assignments | `if … else` |
| `adds = [...]`, `subtracts = [...]`, `add(unit, period, [...])` (a person's variables added up for a group) | a sum, over the members where the variable is a person's |
| `defined_for = "v"` | `if v: <formula> else: 0` |
| dated `formula_YYYY_MM_DD`, a variable's `end` | dated versions; after the end, the default value |
| a variable read for `period.first_month` or `period.this_year` when its value is the case's one value | the case's value (approximated, noted) |
| parameters: the values in force during the years the tests ask about | dated facts, a dated table one fact per row with its dates |
| a variable outside the programme's folder | a fact the case states: the test's value, or the value the engine computed for that case |
| a yearly test of monthly variables whose twelve months are equal (the oracle checks it) | one month, at a twelfth of the yearly figures |
| loops, comprehensions over computed lists, helpers of the package, other periods, roles | residue: the Python kept in the program, its reason, the cases that need it left out |

## The way back

`of_export.pl` reads a program as the RuleSpec exporter does
(`../rulespec/rulespec_export.pl`: the same templates, rules, refusals) and
writes one Python module for openfisca-core: the entities (Person and each
group, with a `member` role), a `Variable` per template, the parameters as
a `ParameterNode` built from a dict, `system()`, and the scenarios as
OpenFisca YAML tests in `TESTS`. Formulas are written in OpenFisca's
vector style (`where`, `select`, `max_`, `min_`, `np.floor`, `&`, `|`, `~`,
`unit.sum(unit.members(…))`). It refuses, besides the RuleSpec refusals, a
rule reading a value of another entity (OpenFisca reads one only through
members or roles).

## Results

Step 0, the share of formulas the reader writes without a person
(`of_classify.py`, first residue reason in brackets): the country template
14 of 14 (100%); `policyengine-us` 3,728 of 4,402 (85%; `if` statements, the
package's own helper functions, `decode_to_str`, loops); `policyengine-uk`
487 of 696 (70%; `if` statements, reads of the benefit unit from a person,
loops); `openfisca-aotearoa` 23 of 217 (11%: it reads people through its own
`persons` and `people` helpers, so it is not in this phase).
`openfisca-france` was not measured: decision 1 kept it out.

The engines on the package's own tests (the gate), as the reader converts
them on 7 October (a test is one case per period it asks about): the
country template 28 of 28 in the twin's reach, SNAP 769 of 788 (19 where
PolicyEngine disagrees with its own test file), EITC 42 of 42, CTC 47 of 48,
Universal Credit 179 of 180, Child Benefit 4 of 4. (On 5 October: 27 of 27,
842 of 884, 46 of 46, 52 of 53, 190 of 190, 4 of 4.)

| Twin | Package | Variables (translated / residue / facts of the case) | Parameters | Tests: engine reproduces, in the twin's reach | Ledger: encoded / approx. / residue | Expectations pass / fail | Cases left out |
|---|---|---|---|---|---|---|---|
| `country_template` | openfisca_country_template | 12 / 1 / 6 | 24 | 28 of 32 | 40 / 4 / 1 | 21 / 0 | 11 |
| `child_benefit` | policyengine_uk | 10 / 0 / 6 | 5 | 4 of 4 | 22 / 3 / 0 | 2 / 0 | 2 |
| `ctc` | policyengine_us | 20 / 0 / 7 | 18 | 47 of 48 | 47 / 2 / 0 | 42 / 0 | 16 |
| `eitc` | policyengine_us | 13 / 2 / 19 | 40 | 42 of 46 | 75 / 1 / 2 | 16 / 0 | 33 |
| `snap` | policyengine_us | 69 / 9 / 101 | 76 | 769 of 862 | 237 / 38 / 10 | 237 / 0 | 643 |
| `universal_credit` | policyengine_uk | 45 / 6 / 40 | 75 | 179 of 189 | 169 / 6 / 6 | 48 / 0 | 153 |

*Variables*: those the programme reads, as the reader found them (a formula
it translated, one kept as residue, a fact the case states). *Tests*: the
package's test cases that its engine reproduces and the twin can take (a
case is out of reach when it states a value the program computes, or when
it expects a figure within a margin that is not a whole number of cents;
the run file says which). *Ledger*: each element counted once.
*Expectations*: the answers the twin checks, all passing. *Cases left out*:
test cases each of whose expectations waits for a residue block, or is out
of reach.

What this says. The translation is faithful where it applies: no
expectation fails, and the parameters are the engine's own values. Since
the work of 7 October, every programme's own amount is among the checked
answers: SNAP's allotment in 3 cases, the EITC in 1, the CTC in 14,
Universal Credit in 6, Child Benefit in 1, and the country template's
income tax. 366 expectations are checked, all passing (99 on 5 October).
Residue is down from 40 blocks to 19: SNAP 10, Universal Credit 6, the
EITC 2, the country template 1, the CTC and Child Benefit none. Each
residue block keeps its Python, its reason and the sentence a translation
must conclude, for a person or the Contract Assistant. The cases still left
out are mostly out of reach: a test that states a value the program
computes, or one whose expected figure has a margin that is not a whole
number of cents.

Two differences of meaning to know. A yes-or-no fact a scenario does not
state is "no" in Logical English; a package's input whose default is "yes"
(take-up, filing) is therefore stated as "yes" in every scenario, and a new
scenario must state it. And Logical English rounds a half away from zero,
where NumPy's `round` rounds a half to the even neighbour; the twins differ
only on an amount ending in exactly half a cent.

The way back, on openfisca-core (`of_roundtrip.pl`, `runs/roundtrip.txt`):
the country template 21 of 21 cases, the EITC 13 of 13, the CTC 32 of 32
(the 2021 phase-out disagreement of 5 October was the exporter's `~` on a
plain Python yes-or-no value, now `np.logical_not`), SNAP 219 of 219;
Universal Credit and Child Benefit refused, each for one reason: a count
over the members of the person's own group (a child's rank among the
children, whether a person is an assessed claimant), which the exporter has
no form for yet.

Fixes the work caused, all generic: a count or sum over members whose test
is proved by several rules counts each member once (all the members, less
those that fail the test); a test case that states a value the program
computes, even in a member's record, is left out with its reason; two
cases of one name get a number; a test without groups is about one person,
the one member of each group, and `members: person` is one member;
PolicyEngine's division of a yearly income among the months, and its
adding up of the months of a year, are written as `/ 12` and `* 12` (for a
flow, never for a stock such as a household's size), and so are the
`[DIVIDE]` and `[ADD]` options; an inner test already decided by the branch
it is in is dropped; an `if`, a yes-or-no table and a yes-or-no value used
as a number are read as conditions or as 1 and 0; `MONTHS_IN_YEAR` and a
file's number constants, a scale's `thresholds[-1]`, `np.isin` and `&=` are
read; a person's read of a value the program computes for the person's
group is residue (it would be asked of the person); a run of the engine is
reused only for the same cases (`OF_REUSE_ORACLE=1`); the exporters give a
member only the inputs of its own entity, and write `round`, `abs` and
tables keyed by a code. Making the video found two more, fixed: an upload's
`formula_1980` (a year without a month) starts in 1980, not at the
beginning of time; and a rule whose aggregate comes before any condition
naming its subject names it first. The review is
a review that is not published.

## The work left, 7 October 2026

The roadmap's list (the design notes `roadmap.md` §8, *Phase 3b — work left*),
item by item:

- **1. Questions about a group's members** (`any`, `all`, `sum`, `max`, `min`,
  `nb_persons`, from the group or from a person of it): done. Asked from a
  person (`person.benunit.any(child & ~claimant)`), the question is a value
  of the group, named after what it says (*a benunit has members who count
  for …*), read through *the person is a member of a benunit*. A person's
  place among the members (`get_rank`) is a count of the members before it;
  members with the same key share a place (the engine orders them by
  position: noted in the ledger). `nb_persons` of a role is left (one block).
- **2. A value read from the person's group**: done (*the person is a member
  of a household and the household's state code is …*).
- **3(a). Loops over a list written in the program**: done, unrolled: a
  `sum(f(x) for x in [...])` into a sum, a `for` statement over a module's
  dictionary or list into one copy of its body per entry.
- **4. The package's own helper functions**: done, inlined from their
  source, a helper returning a tuple included (`_, increment = …`).
  PolicyEngine UK's `add_for_members` is read as a sum over the members a
  mask selects.
- **5. An `if` on a parameter**: done when the parameter has one value over
  the twin's years (the branch it takes is decided when the twin is
  written); `if m.any():`, NumPy's shortcut, is read as its body when the
  body only assigns `where` values on m.
- **6. Parameters that are not numbers**: lists done (`np.isin`, `is_in`:
  *x is in [...]*); a list that changed over time (SNAP's eligible
  immigration statuses before and after the 2025 law; the programmes that
  make a household categorically eligible) is one list per period, chosen
  by the calculation date; texts by state left.
- **8. Dates**: an age from a birth date, as the whole months from the birth
  date to the period's start divided by 12 (LE's *months after*); written
  back too (`_months_between`).
- **9. Values of another period**: SNAP's poverty guideline read at the start
  of its fiscal year (1 October) is a parameter whose versions run from each
  1 October to the next. Values of a variable at another period are left.
- **10. Expression forms**: a yes-or-no expression used as a number is 1 or
  0; a number used as a condition holds when it is not 0; a constant `True`
  times a value is the value.
- **The cases**: a test whose outputs name other periods than its own is split
  into one case per period (the country template's age at birth); a test that
  leaves out a group makes the person its one member, as OpenFisca does; a
  case keeps the outputs of one entity; the engine's single-precision values
  are written as the shortest decimals that read back as them.
- **Found on the way, fixed**: a value of the household stated at the top of
  a person's test is stated of the household when a rule reads it there
  (it was stated of the person); a yes-or-no variable added up with
  amounts (`add(unit, period, [...])`) counts as 1 or 0, never as the word
  *false*; a variable read only from a person's group is declared as an
  input of the group (SNAP's `is_tanf_enrolled` had no template); a name
  the twin builder cannot place is residue, never a sentence without a
  template; the way back writes a person's own facts when the person's case
  also names the person's household.
- **The way back, fixed on 7 October**: a value read from the person's group
  is written as `member_of_tax_unit.x` (RuleSpec) and `person.tax_unit('x',
  period)` (OpenFisca), and a group's read of another group's value through
  its first member; the largest and smallest value over the members; a date
  in a rule; a version of a formula that ends is written with its last day
  as a condition (OpenFisca ends a variable, not a formula); two yes-or-no
  rules from the same date are one formula joined by `|` (two methods of one
  name overwrote each other); a text value given by `the text is equal to
  "SUA"`; a parameter whose first value starts in year 0 starts in year 1;
  and *not* is `np.logical_not`, since Python's `~` of a plain `True` is -2.

**Results of the work left, 7 October 2026.** Six twins rebuilt from the
packages (`runs/build.log`): 366 of 366 checked expectations pass, against
the packages' own engines; every programme's root variable is among them.
Residue: 19 blocks (40 before). The way back: 285 of 285 cases on
openfisca-core for four twins; two refused with a reason. Left: a value of
a variable at another period (item 9, waits for `openfisca-france`), texts
kept as parameters (a state's name, item 6), lookups through Python's data
structures (item 7), roles in a group, the `nb_persons` of a role, and on
the way back a count over the members of the person's own group. The
integrity constraints of the review (years outside the twin, inputs whose
default is "yes") are not written yet.

## The work left, 8 October 2026

The roadmap's *Phase 3b — work left* of 7 October, in its order:

- **Small expression forms: done.** A chained assignment; `list()` of a
  parameter, a list comprehension filtered by `in`/`not in`, `.append` on a
  written list; `sum()` over a parameter's list (item 3(b), unrolled for the
  list in force in the twin's years); a scale's `calc()` used as a yes or no
  (`!= 0`); a name for a group (`spm_unit = person.spm_unit`), and the
  members read through it; a member's amount times a member's yes or no, a
  member's yes or no in arithmetic (1 or 0); `not_` of the members' values;
  Python's own `max`, `min`; `inf`; a member value compared with a value of
  the unit. SNAP's general work requirements and the ABAWD chain (its
  parameters read at a date the formula writes, `parameters("2025-06-01")`),
  SNAP's parent exception, the EITC's earned income and demographic test.
- **Dictionaries: done.** `pd.Series(...).map({...})` (the dictionary worked
  out from the module's names: SNAP's region) and a loop over a module's
  dictionary assigning `where(mask & (key == k), v, x)` (SNAP's utility
  region) as a lookup, a `match`, kept as a step of its own; the `any()`
  guard extended to masks built from the first.
- **The inner function: done.** A function defined inside a formula is
  inlined where it is called (Universal Credit's deduction rate).
- **The way back: done** for a person's place among its group's members
  (`get_rank`): the count of the members meeting the condition with a
  smaller key, written as `_rank(...)` in the module. Child Benefit 2 of 2,
  Universal Credit 103 of 103 on openfisca-core.
- **Roles: done.** A role in a group is a fact of each member, *person 1 is
  adult in household*, stated from the tests' role lists; `nb_persons` of a
  role a count of the members with it. A group's `project()` of its value to
  its members. The country template's parenting allowance translates; the
  country template has no residue.
- **An `if` that sets a value on one branch only: done.** A name set inside
  the `if` for its own use is dropped after it; `if c: x = where(d, v, x)`
  is read as `where(c and d, v, x)` (SNAP's minimum allotment, written once
  rather than once per `if`); an `if` on a parameter compared with a number,
  or on an `and` of parameters, decided when the twin is written
  (Universal Credit's child element). A value that grows past 2,000
  characters while a formula assigns it again is a step of its own.
- **The two integrity constraints: done.** (a) Each twin refuses a scenario
  dated before the first or after the last day of the years its tests ask
  about (`it must not be true that the calculation date is a date D and D <
  …`; the module's `covers`). (b) An input whose default is "yes" is turned
  around (`takes_up_snap_if_eligible` → *declines snap if eligible*,
  `would_claim_uc` → *would not claim uc*), its formulas reading `not` the
  turned input, so that a scenario that does not state it means the
  package's default; the input's source says so.
- **A group reading another group's value: done for a value the program
  computes** (Universal Credit's household capital): read through the
  members, the largest of their groups' values. A group's *input* read as
  its own is still approximated (noted in the ledger).
- **Found on the way, fixed.** The oracle now runs the engine in double
  precision (`double_precision`): in single precision 20,386.028 and
  20,386.03 are one number, and a test's margin hid the difference; a case
  is kept with the engine's figure only when it is a whole number of cents.
  A test with `people:` and no group puts them all in one group, as
  OpenFisca does; a test with no groups at all makes its one person a member
  of each group; a test's expected values written under their group
  (`output: household: …`) are read; the twin states a person case's
  household's computed values (the oracle), and a group's unstated inputs
  their defaults; a date's default (the template's birth, 1970-01-01) is
  stated; a person's role from an upload without the package; an input
  named after a pension is an amount, not a code (*state pension*); a
  derived value in words is a `str` variable on the way back. In LE2 itself:
  two numbers are equal by value (`1.0 = 1`), which SNAP's student and work
  requirement cases needed.
- **Left.** Values of another period (SNAP's prorated income) and tables of
  texts by texts (SNAP's individual utility allowance) wait for
  `openfisca-france`, as the roadmap says; SNAP's two other blocks are dates
  worked out from ages on the package's own month grid (Universal Credit's
  child index and the birth before the child limit, two blocks there too),
  and a family's order within its household (`np.arange`) and the
  simulation's random draws of deductions in Universal Credit (estimation,
  not law: three blocks). On the way back, SNAP is refused for one reason:
  `is_homeless`, a household's input, is read as their own by a person and
  by a SPM unit, so its template has two kinds of subject; a group's link to
  the household it belongs to (*the household of a spm unit*) would settle
  it.

**Results of the work left, 8 October 2026.** Six twins rebuilt from the
packages, the engine run again in double precision: 598 of 598 checked
expectations (the country template 26, Child Benefit 2, Universal Credit
146, SNAP 349, the EITC 33, the CTC 42). Residue 9 blocks: SNAP 4, Universal
Credit 5, the others none. The engines reproduce their own tests: the
country template 32 of 35, Universal Credit 179 of 196, Child Benefit 4 of
4, SNAP 962 of 1,103, the EITC 42 of 46, the CTC 47 of 48. The way back on
openfisca-core: the country template 26 of 26, the EITC 28 of 28, the CTC 32
of 32, Child Benefit 2 of 2, Universal Credit 103 of 103 (`runs/roundtrip.txt`);
SNAP refused, with its reason (219 of 219 on 7 October, before the ABAWD
exemption read the household's `is_homeless` as a person's own).
Also fixed for the way back: a test with no groups names its one person in
each group's list without stating its facts twice (the second, a default 0,
won in the exported YAML).

## openfisca-france: Phase 3b′, steps 1 to 4 (9 October 2026)

The plan is the roadmap's
Phase 3b′ (a working paper of the author, not published). Its decisions
were taken as the plan recommends, with two settled by the user: a period is
**named by its text**, with the relations a case needs stated as facts
(decision (a)); the first programmes are the **income tax**, then the housing
allowance (decision (b)); a build **never calls France's public API** — the
oracle is always the package's own engine, run here, so that a twin's
evidence does not depend on someone else's service and no case, however
synthetic, leaves the machine (decision (c)); and the twins stay **private**,
the package being AGPL-3.0 (decision (d)).

**Step 1 (the reader's smaller forms) and step 2 (roles): done.** The survey
run again (`runs/france_survey.json`): **682 of 988 computed variables
translate (69%)**, against 524 (53%) at step 0 and the 65% the plan expected.

**Step 3 (the income-tax twin) and step 4 (periods): the twin is built and
its answers are being checked.** `programme(impot_revenu, …)` in `corpus.pl`
reads the variables of `prelevements_obligatoires/impot_revenu` that the
income tax's eight root variables reach, with the tax administration's own
calculator tests and the package's income-tax tests: **1,986 variables (181
formulas translated, 0 residue in the reader, 1,805 facts the case states),
411 parameters, 434 test cases**, of which the package's own engine
reproduces **431**.

A period is a word in the sentence. Only a variable read at another period
gets a place for one (*le revenu fiscal de référence du foyer fiscal pour
une période est un montant*), and a case states both the values of each
period it needs and the relations between those periods
(*une période est un nombre années avant une période*). The oracle computes
the value of each such variable at every period a case names, from the
engine — the local equivalent of the trace France's API would return.

**Defects this step found, all generic and all in the shared machinery:**

- The reader wrote `Person` for the roles, the membership relations and the
  member helpers, while a variable's entity came from the package itself
  (`camel(var.entity.key)`). France's person is `individu`, so a rule of an
  `Individu` reading a value of its foyer fiscal found no relation whose
  first argument was its own entity, and the read became residue — four
  blocks. `person_key/1` now reads the package's own key, and the twin
  builder takes the person entity from a `member_of_…` relation
  (`person_entity/1`) rather than assuming `Person`, so a French twin says
  *un individu* and not *un person*.
- **A template may not contain a reserved word of the language it is written
  in.** LE cuts the template off there, and the rule that uses the whole
  sentence is left with no template at all. `safe_word/2` had handled English
  `if`; `reserved_safe/2` now asks LE2's own keyword table for the twin's
  language and joins such a word to its neighbour, so
  `surplus_si_invalide` — whose `si` is French for *if* — reads as *surplus
  si_invalide*. One template of 2,349 was lost to this.
- A value stated for each period, **read without naming a period**, was
  refused; it is now read at the period the rule is about (its own, or the
  calculation period). `openfisca-france` reads `age` that way throughout —
  two blocks.
- `?bool:` is the reader's own mark for a role read as a yes or no; a role
  read straight into an `if` carried the mark into the formula, which the
  formula language cannot parse — three blocks.
- `at_period` looked up a period key as text only, but YAML reads a year as
  an integer (`2025`) and a month as a string (`2025-03`). With more
  variables read by period, a case named a year whose given value was keyed
  by the integer, and the extraction stopped with `KeyError: '2025'`.
- **A sum of yes-or-no values used as a condition** was not read:
  `(not majeur) + handicap`, which is how the package asks whether a child is
  a minor or disabled. The twin builder could read a bare judgment *name* as
  1 or 0 but not a judgment *expression*, and had no reading for arithmetic
  used as a condition at all (nor for the literal `0`, which the package also
  writes). Both rules this cost — `enfant_a_charge` and
  `enfant_majeur_celibataire_sans_enfant` — feed `nbptr`, the number of parts
  of a tax household, which feeds every answer the tests ask for; so **all
  434 cases waited on two residue blocks**, and the twin checked nothing.
- **A rule core Logical English cannot write was written anyway, and the
  twin went quietly wrong.** When the writer cannot open a nested group with
  a plain condition of its own — a group that leads with an aggregate, a
  negation or a universal — it falls back to an `all of` block of the InsurLE
  extensions and records a *remark*. Core LE does not read that block, so LE
  reports a missing template for `all of` and the rule using the whole
  sentence is left without one. **Universal Credit's assessable capital went
  that way**: the twin reported 107 of 146 answers passing and 39 failing,
  with "0 writer error(s)" beside them, where the figure recorded on 8
  October is 146 of 146. (Checked by building it with the readings added
  above both on and off: the result is identical, so this is not their
  doing — it came in with the 8 October work that reads a group's value
  through the members.) **This is not fixed.** Writing the rule properly
  means naming the group as a judgment rule of its own — which is what the
  housing allowance's two eligibility scopes wait on too. Refusing it
  instead, so the rule becomes residue with its reason, needs a test of what
  the writer can express, and the obvious test (could a plain condition be
  moved to the front?) does not match the writer, which declines to rotate
  inside an `otherwise` at all (`le_writer:rotate_front/3`: "a guard is a set
  of conditions in an order; leave it"). What a build does show is the
  failures themselves — Universal Credit's line reads `tests 107 pass 39
  fail`. The writer records a remark for the fallback
  (`issue(warning, needs_extensions, …)`), but it does not reach the list
  `write_migration/4` returns, so a build cannot yet name the cause beside
  the count.
- **A test that gives a value the package itself computes was treated as a
  case the twin cannot state** — and this, not residue, is why the income-tax
  twin checked nothing through three builds while its residue fell from 9
  blocks to 1. OpenFisca lets any variable be given as an input, and then its
  own formula is not used; the tax administration's tests rely on it, and
  every one of the 434 cases gives `age`, `nbF`, `nbG`,
  `assurance_vie_pfu_ir` and three more that the package could work out.
  Logical English already has the construct for it — the one a Catala
  `context` variable is written with: read the value a scenario gives first,
  the rule otherwise. The reader now marks exactly the variables a test
  actually gives as `overridable` (`mark_overridable/3`), which meant reading
  the tests before writing the module.
- **A twin that read test cases but wrote no scenario said nothing about it.**
  `tests/3` dropped a case it could not write and returned the rest, so 434
  cases becoming no scenarios was indistinguishable from a source with no
  tests at all. It now reports how many cases it could not write, and says so
  as an error when it could write none.

**Steps 5 to 7: not started.** Step 5 (the tables by commune) is measured but
not written: `zone_apl` preloads a 36,682-row CSV into a module-level
dictionary (`preload_zone_apl()`) and looks it up by INSEE code with
`fromiter`, so the reader has to recognise that shape and keep the table as an
included resource. LE2 gained the builtin a lookup by code needs (*starts
with*, in six languages) on the way. Steps 6 (RSA, prime d'activité, then
contributions and payslips) and 7 (File ▸ Open of a France programme, the
review, the French integration document) are untouched; the other four French
programmes are declared in `corpus.pl` but not built.

```sh
cd .cache && python3 -m venv venv-fr && venv-fr/bin/pip install -e ./openfisca-france
cd .cache && venv-fr/bin/python ../of_survey.py france --json ../runs/france_survey.json
cd /work && OF_SKIP_EXTRACT=1 ./myswipl.sh -q migration/openfisca/of_build.pl -- impot_revenu
```

## openfisca-france, and the answers a twin can be asked: 10 October 2026

Steps 5 to 7 of Phase 3b′ (a working paper of the author, not published)
were "not started" on 9 October, and the income-tax twin of steps 3 and 4 was
recorded as "built". Reading what a build actually says turned out to matter
more than either: **the twin was built and checked nothing.**

**A twin that cannot be asked a question has not been migrated.** Each of the
income tax's 434 cases stated **1,800 values, of which 1,757 were the same
`0`** — the default of every input the programme reads. That made a program of
**30 MB and 736,847 lines**, which Logical English could not parse at all
(`Stack limit (1.0Gb) exceeded` while reading the text), so the build reported
`tests 0 pass 0 fail` beside 96 writer errors. The figure recorded on 9
October, 431 of 434, was the *package's own engine* reproducing its own tests,
not the twin reproducing anything.

Four changes, each of them general, and each found by reading a build's own
line rather than the code:

- **A default is written once, as the variable's own rule.** An input the
  programme reads whose value the package gives a default becomes a rule
  concluding that default, which a case overrides by stating a value
  (`overridable` — the construct a Catala `context` variable is written
  with). A case now states only the values it actually gives.
- **A value stated for each period is no longer also stated without one.**
  `rs_f2dc(foyer_fiscal_1, 0)` asked for a template of two places beside the
  three-place sentence the rules read (*le f2dc d'un foyer fiscal pour une
  période est un montant*). All 96 writer errors were that.
- **A monthly input a test states for a year is divided by twelve**, as
  OpenFisca's own `set_input_divide_by_period` divides it. Child Benefit's
  four children with a respective amount of 1 stated for 2021 are 4 a year,
  not 48.
- **Before the first version of its formula, a variable has its default**, as
  it already did after its end: OpenFisca answers 0 for a basic income asked
  about a year before the one its formula starts in. The country template's
  own test says so, and the twin had no answer for it.

**What the twins check now.** Every twin was rebuilt. The cases a twin can
state went up, and with them the answers it is checked on — and three
disagreements with the packages' own engines came out of cases that had never
been checked before.

| Twin | Checked expectations, 8 October | 10 October |
|---|---|---|
| country template | 26 of 26 | **32 of 32** |
| Child Benefit | 2 of 2 | **4 of 4** |
| Universal Credit | 146 of 146 | **194 of 196** |

**The two Universal Credit cases that now disagree**, both of them cases the
twin could not state before:

- *Exempt pension*: the test states `pension_credit` at the top of the case,
  and `pension_credit` is a value of the **benefit unit**; the twin states it
  of the person (*the pension credit given of person_1 is 1*), so the rule
  that reads the benefit unit's pension credit finds the default 0 and the
  person is not exempt. A value stated at the top of a case belongs to the
  individual of **its own variable's entity**, not to the case's subject.
- *A situation with no claimant roles*: the count of claimants in benefit
  units without reported capital is 1 where the engine says 0.

**Step 7, File ▸ Open of a France programme: done.** The static reader already
had France's entity names; it now also **says which package it read**
(`dialect: static_fr`, from a `foyer_fiscal` among the entities), and the door
writes the twin in **Français Logique** when it did — decision 3 of the
October plan, which until now applied only to a build. A slice of
`openfisca-france` (the wealth tax, its `parameters/` and `entities.py`
beside it) opens as 139 variables, 27 of them translated, 0 residue, 215
ledger elements, in French, with the package's engine never run. In a French
twin the reader's own names are French too: *un individu est membre d'un
foyer fiscal*, *un individu est declarant dans le foyer fiscal* — where
before a French twin mixed the two languages in one sentence.

**The survey again, and the helpers' depth.** `of_survey.py france`:
**778 of 988 computed variables translate (79%)**, against 682 at step 2 and
524 at step 0 — the periods, the roles and the overridable inputs of steps 3
and 4 are what lifted it. The reader also inlines a helper that calls a
helper up to six deep instead of three (33 of the survey's blocks stopped at
the depth, and `apply_bareme` reaches through three helpers); the count did
not move, because each of those formulas stops at something else a step
later, but the reason a build now gives is the construct rather than the
limit.

**The environment split, finished.** `fetch_sources.sh` was changed on 9
October to give the country template an environment of its own (`venv-ct`:
pip will not resolve its core beside PolicyEngine's 45), but the environment
was never made, so every country-template build failed. It is made, and the
template builds again (openfisca-core 45.0.5).

**Left of Phase 3b′.** Step 5 (the tables by commune, and the
housing-allowance twin, with the cross-check against the Catala twin of the
same law); step 6 (RSA and prime d'activité, then the contributions and the
payslips); step 7's review and the French integration document. The two
Universal Credit cases above, and SNAP's way back.

## The income-tax twin answers its cases: 11 October 2026

The pick-up list below was followed in its order. Its first item, "the
figure that matters — how many of the 434 cases the twin itself answers",
is now known: **1,585 of the 1,944 expectations the twin checks agree with
`openfisca-france`'s own tests** (82%), none of them an error. The engine
still reproduces 431 of its 434 cases. The program is 4.7 MB and 82,352
lines (it was 30 MB and 736,847 lines), and a build takes 50 minutes.

| Value the case asks for | Agree | Disagree |
|---|---|---|
| `nbptr`, the number of tax shares | 363 | 0 |
| `rfr`, the reference taxable income | 349 | 3 |
| `rbg`, the gross total income | 321 | 0 |
| `rni`, the net taxable income | 249 | 2 |
| `iai`, the tax before credits | 77 | 219 |
| `reductions`, the tax reductions | 30 | 112 |
| the 40 others (credits, reductions one by one) | 196 | 23 |

**Why the twin had answered nothing.** The build had stopped three times. It
had not run out of memory, as the note assumed: it had never finished. Each
cause was general, and each fix serves every program, not this one:

- **The build could not start.** On 9 October the corpus modules were
  renamed (`corpus` became `openfisca_corpus` and `catala_corpus`, so that a
  server could load two translators at once). `of_build.pl`,
  `catala_build.pl` and `catala_gate.pl` still looked for `corpus`, and
  failed without a word.
- **Finding which expectations wait for residue went round and round.** For
  each pair of a query and a residue block, LE2's `migration_pending`
  walked the rules with lists. On 2,600 rules it never finished. It now
  walks once per query, with balanced trees.
- **Logical English could not read a long French program.** Three faults,
  each of them in LE2's core:
  - The tokenizer left a choice point after every French word, which kept
    the whole text alive.
  - The parser copied the 4.7 MB text each time it read a sentence back
    verbatim.
  - Two notes the parser keeps were thrown away each time a condition
    failed, so they were worked out again for every condition. One is
    whether any template is prepositional (in the extensions); the other
    lists the templates that define global names.

  Reading the program took 242 seconds and now takes 87.
- **The verifier took more than ten minutes**, mostly reading one large
  index again and again. It now takes under a minute. One check also raised
  9,398 false warnings. It warns when a memorable call sits under a
  negation, but every "otherwise" in a rule makes such a call outside the
  negation as well.

**Why it then answered wrongly.** The first real figure was 36 of 1,944. The
causes, in the order the twin's own answers showed them:

- **The marital status was added up.** A household reads the main
  declarant's status (`foyer_fiscal.declarant_principal('statut_marital')`),
  and the reader added the status up over the members, as it does for an
  amount. A code is now compared rather than summed: "a member holds the
  role and has that code". This alone stopped 1,443 expectations.
- **A variable the French elision did not spare.** The writer elides "de
  une" to "d'une". It also elided a variable named `NE`: "et NE est un
  nombre" became "et N'est un nombre". 67 lines of the program read a
  variable that nothing set. A word in capitals is now never elided.
- **Yes-or-no values read as amounts.** Some boxes of the tax form are
  declared yes-or-no and then used as numbers: `caseT` is multiplied by a
  rate, and `f7xe_2025` (a Scellier investment) is added to amounts. The
  reader now counts a yes-or-no as 1 or 0 wherever it enters a sum, as NumPy
  does. Before, a case that did not state the value left the whole sum
  without one. The reader had also missed `caseT` and `nbH` because of the
  capital letter in their names.
- **`rfr` was handed to the twin instead of worked out.** For a variable
  read at another period (`rfr` two years back), the oracle stated the
  engine's value at every period the case names, *including the case's
  own*. For `rfr`, a root of the tax, that was the answer the case checks.
  The engine's value is now stated only for the other periods. The reader
  did the same with the package's default, which hid the rule's own value
  behind a 0. A value the case does give for each period is now stated as
  the value given (`le rfr donné`), which the rule reads first.
- **The query of `rfr`** now asks for the period the case is about. Before,
  it answered for every period the case names.
- **`500,0` is 500.** LE2's test runner compares answers as text, and in
  French the decimal comma made 98 equal values look different.
- **Each value worked out once per question.** OpenFisca's engine keeps each
  variable once it has worked it out for a period. The twin's computed
  templates are now `; mémorisable`, and LE2 does the same. Without it, one
  case's tax ran an 8 GB machine out of memory. The test runner asks the
  memo not to keep explanations, which it never reads (each replay copied
  the whole proof below). The editor's explanations are unchanged.

**What is left.** The tax itself (`iai`) and the reductions answer nothing in
286 cases. The worked-out value is 0 instead of the expected one in 10
Duflot-Pinel-Denormandie cases and in 6 cases of the high-income
contribution. All of them are cases never checked before: findings, not
regressions. Tracing them needs runs that take most of an 8 GB machine's
memory. Twice the machine stopped such a run, so they are left for a
larger one.

### Where to pick this up (written 10 October 2026, 07:40 UTC; done 11 October, see above)

The machine this ran on stopped three times in the middle of a build, so
**three twins were not rebuilt after the reader changed** and their recorded
figures are the ones of 8 October, not of the reader as it now stands. Every
change is in the files; what is missing is the evidence a build produces.
To finish, in this order:

1. **The income-tax twin** — `./myswipl.sh -q
   migration/openfisca/of_build.pl -- impot_revenu`, from the LE2
   repository, with `.cache/venv-fr` in place. Its oracle ran twice and said
   the same thing both times (431 of 434 cases reproduced by the package's
   own engine, 1 disagreeing, 2 outside the twin's reach), and the reader
   wrote its module; the build was killed while the twin builder was writing
   the program, so **the figure that matters — how many of the 434 cases the
   twin itself answers — is still unknown**. The program it wrote on 9
   October (30 MB, 736,847 lines, no answers) is still the one in
   `examples/migration/openfisca/impot_revenu/`: expect the next build to
   replace it with one about a hundred times smaller, and read the
   `tests … pass … fail` of the build's own line.
2. **SNAP, the EITC and the CTC** — `… of_build.pl -- snap eitc ctc`. SNAP's
   extraction takes about twenty-five minutes before the twin is written.
   Their 8 October figures (349, 33 and 42 checked expectations, 598 in all
   with the three above) are the ones every document still quotes; the three
   twins rebuilt so far each check more than they did, so the total will
   move up, and any case that now disagrees is a case that was never checked
   before — read it as a finding, not as a regression.
3. **Then the figures in two places**: the "Where it stands" line at the
   top of this README, and the `598 of 598` of the design notes `roadmap.md`
   (§8, Phase 3b work left).

What is **not** waiting on a build: every reader and writer change of 10
October, the three twins rebuilt (country template 32 of 32, Child Benefit 4
of 4, Universal Credit 194 of 196), the Catala side (`apl_foyer` 14 of 14,
`al_locatif` 5 of 5, `apl_accession` 6 of 8, every earlier twin unchanged),
File ▸ Open of a French package, and the documents. LE2's own suites were run
once in the middle of the work: 4,304 of 4,313 example expectations and all
but 14 of 801 unit tests, and each of those failures was checked to be older
than this work — except `apl_accession`'s two, which are the ones named in
`../catala/README.md`.

## Steps 5 to 7 of Phase 3b′: the housing allowance, its cross-check with Catala, the RSA (11 October 2026)

The roadmap's Phase 3b′ (a working paper of the author, not published)
left steps 5 and 6 and part of step 7 to do. A five-hour session took them
in that order. What it reached is below. Every figure comes from a build or
a test run of that day.

**Step 5 — the tables by commune, and the housing-allowance twin.**

| Twin | Variables read | Residue blocks | Checked expectations |
|---|---|---|---|
| `aides_logement` (at the start of the day) | 14 | 2 | 8 of 36 cases run by the engine; 1 checked by the twin |
| `aides_logement` | 106 | 2 | **39 of 39** |
| `aides_logement_croise` (the cross-check's 36 situations) | 99 | 1 | **216 of 216** |

- **A table by commune is a CSV file the twin loads.** `zone_apl` looks the
  commune's INSEE code up in a dictionary the module fills from
  `assets/apl/20110914_zonage.csv` (`fromiter(d.get(code, default) for
  code in depcom)`). The reader recognises that shape, takes the table from
  the loaded module (OpenFisca loads a file of variables as a module of its
  own, so the reader calls the module's own loader there,
  `preload_zone_apl()`), and writes it to `.cache/out/of/<programme>.tables/`.
  `of_build.pl` copies it beside the program. The twin builder writes `la
  table zone_apl_by_depcom est chargée depuis zone_apl_by_depcom.csv, avec
  première correspondance`, with the package's default as the last row
  (`-`, any code). 36,682 communes and their sub-communes; LE reads the
  table without a delay worth measuring.
- **The reader's new readings, each general:** a parameter chosen by a code
  and then one of its children (`coefficients[zone_apl].degressivite`); a
  code read through a role holder used to choose a parameter (one test per
  code, never a sum of codes); parameters read at a date the calculation
  date decides (`parameters(period.n_2.stop)`,
  `parameters(period.start.offset(-2, 'year'))`, `parameters(period.n_2)`,
  the last 1 July as an `Instant`), each written with its versions moved by
  as much; `famille.demandeur.has_role(FoyerFiscal.DECLARANT_PRINCIPAL)`;
  `x is not None` of a value read (always true); `date.max`; `assert
  period.unit == 'month'` (a helper checking its own argument); a
  member's own yes-or-no counted as 1 or 0 in a sum; ADD and DIVIDE reads
  of another period through the members; a test's expected value written
  as arithmetic (`round(0.0045 * (0.6888 - 0.45), 5)`); `enum.index`.
- **Defects found, all in the shared machinery:**
  - The oracle read only absolute error margins. The housing allowance's
    tests give a *relative* one (1%), so the engine "failed" 21 of its own
    tests that `openfisca test` passes. It now reads both, as OpenFisca's
    own runner does: 39 of 39 engine runs pass (23 before).
  - **Every parent was the demandeur and the conjoint.** A sub-role
    (`demandeur`, `conjoint`; `declarant_principal`) is the person at its
    place in its role's list. The scenario writer tested membership of the
    list, so a couple's rent was counted twice, and in the income tax both
    declarants of a married couple were the main declarant.
  - **A group that lists its people in another order gave each person the
    other's values** (a household listing its children before the reference
    person). Every group's list now follows the case's order, and each item
    carries the person's place (`id`), which the twin builder reads
    (`item_place/3`).
  - The oracle stated a value read for each period also without a period,
    for a group (4 writer errors) and for a person (the RSA's 3): it is now
    stated at the case's own period, among the others.
  - **LE2's writer** treated a variable named in one `otherwise`
    alternative as bound in the next, and moved `P - R > 0` in front of the
    counts that bind P and R; that alternative then answered 0 for a
    family's rent ceiling. Each alternative now starts from the variables
    known before the cascade (`le_writer.pl`, `alternatives_seq/6`). The
    cross-check twin went from 98 to 141 of 144 with this alone.
  - **LE2's `migration_pending`** held back every expectation that reached
    residue, even through a value the case itself gives (an overridable
    rule). The walk now stops at such a rule for that case: the personal
    participation and the allowance itself, which read the resources every
    case gives, are checked (`le_migration.pl`, `overrides/2`). Only the
    pairs already waiting are walked again, once per set of given values,
    and only where cases × waiting pairs is at most 20,000: on the income
    tax (hundreds of cases, each giving its own set of boxes) the walks
    took hours, so there the expectations wait as before.
  - The writer fix above first appended both alternatives' lists of
    mentioned variables, which doubled the list at every nested cascade;
    only the variables new in an alternative are added now. (Three builds
    of the income tax were stopped while this and the walks were found.)
- **Left**: 12 of the 53 cases need the 2021 reform's rolling year
  (`Period(('year', period.start, 1)).offset(-1).offset(-1, 'month')`, the
  twelve months before the previous month: a period the twin cannot name
  yet) and a read person → family → applicant → tax household; 11 cases
  have two tax households or two households, which the scenario writer does
  not state; 3 cases are left out because the engine's figure is not a
  whole number of cents.

**Step 5 — the cross-check with the Catala twin** (`of_crosscheck.py`,
`runs/croise/`). 36 rental situations (single or couple, 0, 1 or 3
children, zone 1, 2 or 3, four months from 2022 to 2024, two rents, two
incomes) written as openfisca-france tests whose expected values the
package's engine gives (the programme `aides_logement_croise` of
`corpus.pl`), and as scenarios of a copy of the Catala twin `apl_locatif`
(`apl_locatif_croise.le`). `of_crosscheck.py report` runs both twins and
writes `runs/croise/report.md`:

| Quantity | Twins agree | Disagree | One has no answer |
|---|---|---|---|
| rent ceiling | 35 | 0 | 1 |
| charges | 36 | 0 | 0 |
| family rate | 36 | 0 | 0 |
| minimal participation (P0) | 18 | 18 | 0 |
| personal participation | 0 | 36 | 0 |

All 54 disagreements have one cause, **in the sources**: the CNAF's Catala
programme rounds P0, and each of the two terms of the personal
participation, to the cent before adding them; openfisca-france keeps them
unrounded (48.654 against 48.65; 52.4969 against 48.65 + 3.84 = 52.49).
Each twin gives its own source's value. The one unanswered value is the
Catala twin's rent ceiling for a single person in zone 3 in March 2024; it
is still to be put to Catala's own interpreter.

**Step 6 — RSA and the prime d'activité: built, not yet answering.** The
programme `rsa` of `corpus.pl` (roots `rsa`, `rsa_socle`, `ppa`, within
`prestations/minima_sociaux`, 207 test cases from the package's `rsa` and
`ppa` tests). At the start of the session it read 48 variables, with 6
residue blocks and 1 expectation checked. After the session's reader changes
(below), the engine reproduces 136 of the 207 cases, and the twin reads
262 elements, with 15 residue blocks and 1 writer error (a variable read
and never declared, `assiette_csg_plus_values`). It checks 40
expectations, of which **16 agree**; the 24 that do not are the prime
d'activité's activity income (`ppa_revenu_activite`, 20) and its
fictitious amount (`ppa_fictive`, 4), which answer 0 although each case now
states the person's salary for each month in the person's own record. That
is where to pick the RSA up. What the RSA needed, all general:

- **`period.last_3_months` is a period of its own**, the three months
  before (`2015-07_3m`), whose months the case states (*2015-07 est un mois
  de 2015-07_3m*). The reader wrote it as *the month three months before*,
  so a sum over the last three months read one month. Chains of period
  words (`period.last_month.last_3_months`) and periods built with
  `Period(('month', period.start, 1)).offset(-1)` (the month before) or
  `Period(('month', period.first_month.start, 3)).offset(-3)` (the last
  three months) are read; a period of twelve or twenty-four months from the
  period's start is residue.
- **A constant `Instant`** (`parameters(Period(('month', Instant((2016, 1,
  1)), 1)))`, the prime d'activité's parameters before 2016) and **a
  parameter node chosen by an `if`**, its children read afterwards: the
  five residue blocks of the prime d'activité.
- **A period bound to a name** (`m_3 = period.offset(-3, 'month')`).
- **A person's value read for each period is stated with its periods**, in
  every place the scenario writer states a person's value (a group's
  members, a case about one person, a case with no groups) and in the
  oracle's values merged into a case: 25 writer errors became 1.
- **The oracle stated a person's value at the other periods for the first
  person only, at the top of the case**, where the twin read it as the
  family's (*l'aah donné de famille_1*): the prime d'activité averages the
  activity income of the three previous months, and found none. Each
  member's value is now stated in the member's record; and the scenario
  writer's own per-period values of a person (`period_inputs`) go to the
  one person of a case without groups rather than to the top of the case.
- Left: 71 of the 207 cases are outside the twin's reach, 33 of them for
  having two or three tax households; `rsa_socle` reads a parameter the
  package no longer has (`rmi.rmi_m.rmi`) in a version inside the tests'
  years; the social contributions and payslips (`cotisations_sociales`)
  were not built in this session.

**Step 7 — the review and the French document.**
a review that is not published
(a DGFiP engineer and a CNAF engineer, role-played); LE2
`docs/user/integrations/openfisca-france.md`, in French, in the Help menu.

**The income-tax twin's open items.** Reading the reader's output for the
Duflot-Pinel-Denormandie reduction (0 instead of the amount in 10 cases)
found a defect: a long formula is broken into steps, and each dated version
numbered its own from 1, so the 2024 version's steps replaced the 2023
one's (both end on `step_24`). A step is now named once per variable,
across its versions (`stage()`). With this and the sub-role fix above
(both declarants of a married couple had been the main declarant), the
package's engine reproduces **432 of the 434 cases** (431 before; reader and
oracle of 11 October, 17:53). **The twin itself was not rebuilt within the
session**: its twin-writing phase ran 20 to 46 CPU-minutes without
finishing, and five runs were stopped (the last at the session's end) while two slow spots of this session's own changes
were found and removed (see the defects above). The program in
`examples/migration/openfisca/impot_revenu/` is still the one of 11 October,
11:22, with the figures of the section below. Rebuild it alone:
`cd /work && OF_SKIP_EXTRACT=1 ./myswipl.sh -q
migration/openfisca/of_build.pl -- impot_revenu` (the extraction
and the engine's run of 17:53 are in `.cache/out/of/`), then read the
Duflot-Pinel-Denormandie and high-income contribution cases.


### Where to pick this up (written 11 October 2026, 19:40 UTC; followed 11–12 October, see below)

0. **The income-tax twin**: rebuild it alone (command above), and check
   that the 10 Duflot-Pinel-Denormandie cases now answer; then the 6
   high-income contribution cases and the 286 cases where the tax answers
   nothing (a machine with more than 8 GB).
1. **The RSA's activity income** (`ppa_revenu_activite` answers 0 in 20
   cases): ask the twin `rsa` for `ppa_revenu_activite_individu` of the
   person for each month of `2015-07_3m` in
   `PPA_Eligibilité_sur_certains_mois_seulement_2015_10`, and follow the
   rule down to the salary each month states.
2. **Several groups of one kind in a case** (two tax households, two
   households): 33 RSA cases and 11 housing-allowance cases wait for it in
   the scenario writer (`convert_tests`, `len(gv) != 1`).
3. **A rolling year** (`Period(('year', period.start, 1)).offset(-1)`, the
   2021 reform of the housing allowance's resources): a period name and the
   months it holds, as `_3m` does for three months.
4. **The Catala twin's missing rent ceiling** (single person, zone 3, March
   2024): run Catala's interpreter on that case (`../catala/`).
5. **The French of the twins**: articles and accents from the variables'
   labels; the translator's own words in French (review point 6).
6. **The contributions and payslips** (`cotisations_sociales`): declared in
   `corpus.pl`, not built.
7. **The way back of the country template**: 15 of its 32 cases stop on a
   date (`float()` of a `datetime.date`, the birthday cases added on 10
   October); `test_openfisca.pl`'s `runs_on_openfisca_core` fails on it.
8. **Build time**: a build of `rsa` takes 35 minutes when the engine runs
   (`OF_REUSE_ORACLE=1`: 4 minutes); building two twins in one run of
   `of_build.pl` once crashed SWI-Prolog (a segmentation fault; each alone
   builds).

## The pick-up list of 11 October, 19:40, followed (11–12 October 2026)

The list above was taken in its order, with LE2's test suite first (two
failures). Every figure below comes from a build or a run of that night.

| Item | Result |
|---|---|
| LE2 suite | the 2 failures of `apl_accession` gone: **8 of 8** |
| 0. income-tax twin | rebuilt: **1,755 of 1,948** expectations agree (1,585 of 1,944 before), no writer error |
| 1. RSA activity income | **36 of 40** expectations agree (16 before) |
| 2. several groups of one kind | done: RSA cases within reach 206 of 207 (162 before); housing allowance **50 of 50** (39 of 39 before) |
| 3. rolling year | done: `aide_logement_base_ressources_individu` is no longer residue |
| 4. Catala rent ceiling | answered, and the cross-check's rent ceiling is **36 of 36** |
| 5. French of the twins | not done |
| 6. contributions and payslips | not done |
| 7. country template's way back | **32 of 32** on openfisca-core (17 pass and 15 errors before) |
| 8. build time | not done; a build of `rsa` without the engine took 5 minutes |

**One defect behind the LE2 failures and item 4.** The writer elides a word
before a vowel (*de une* → *d'une*). On 10 October it learned to spare a
variable in capitals (*NE est* had become *N'est*), but the Catala twins
were written before that: `apl_accession`, `apl_locatif`, `al_locatif` and
`apl_foyer` still read *M'est égal à "D331_32"* and *N'est égal à
"PersonneSeule"*, conditions on a variable nothing set. In `apl_accession`
a loan signed in 2019 then took the ceiling of a loan of 1994 in francs
(300.48 € instead of 399.20 €). The four twins were rebuilt
(`catala_build.pl -- <programme>`): 8 of 8, 49 of 49, 5 of 5, 14 of 14. The
cross-check's copy of `apl_locatif` was rewritten from the new twin and
`of_crosscheck.py report` run again (`OF_CROSS_REUSE=1`, the OpenFisca
twin's run kept): the missing rent ceiling of March 2024 was the same
defect, and one of the 18 disagreements on the minimal participation (P0)
with it. Catala's interpreter was not needed.

| Quantity | Twins agree | Disagree | One has no answer |
|---|---|---|---|
| rent ceiling | 36 | 0 | 0 |
| charges | 36 | 0 | 0 |
| family rate | 36 | 0 | 0 |
| minimal participation (P0) | 19 | 17 | 0 |
| personal participation | 0 | 36 | 0 |

The 17 and 36 disagreements left are the rounding of the sources (above).

**Item 1, the RSA's activity income.** Three general causes, in the order
the twin's answers showed them:

- **The oracle stated nothing of a residue variable for the case's own
  month.** It leaves out a computed variable's value at the case's own
  period, because that value is the twin's to work out. A variable left as
  residue (`rsa_indemnites_journalieres_activite`, `aah`) cannot be worked
  out, so the activity income read no daily allowance for the month asked
  about. `of_oracle.py` now states it, unless the case asks for that
  variable.
- **A residue variable's given value reached nothing.** For a variable a
  case may give, the twin's rule reads the given value first; when the rule
  was residue, no rule was written at all. `rulespec_twin.pl`
  (`residue_items/4`) now writes, beside the block, the rule that reads the
  given value; LE2's `migration_pending` treats that rule as an override
  (`le_migration.pl`, `overrides/2`, `only_reads/2`): a case that gives the
  value does not wait for the block.
- **A bound on the refinement left 205 of the 207 cases out.** On 11 October
  the refinement of `migration_pending` (a case that gives a value does not
  wait for the residue behind it) was switched off where cases × waiting
  pairs exceeded 20,000, after the RSA twin of 19:33 had been built. The
  bound now counts the work itself: distinct sets of given values × waiting
  pairs × rules in the graph, at most 50 million. The RSA's cases share few
  sets; the income tax stays above it. (`testing/test_le_writer.pl`:
  `given_value_stops_the_walk`, `given_value_of_a_residue`.)

The 4 expectations left are `ppa_fictive`: it reads `ppa_forfait_logement`,
still residue (r6). The case gives `ppa_fictive` for its other months, and
the refinement takes that for giving it: the walk does not know periods.
173 of the 207 cases are still left out, almost all because the RSA's own
amount (`rsa_socle`) reads a parameter the package no longer has.

**Item 2, several groups of one kind.** A case may now have several groups
of a kind other than the one it asks about (a family's two tax households).
The reader (`convert_tests`) gives each person's item the number of its
group (`group: 2`) and states each group's own values in a list
(`groups.member_of_foyer_fiscal`); the oracle states the engine's values of
each group there (`boundary`, `merge_computed`); the twin builder names the
groups `foyer_fiscal_1`, `foyer_fiscal_2` and states each one's values
(`item_group/3`, `group_facts/3`). Several groups of the kind the case asks
about are still out of reach. Found on the way: an input read for each
period that the oracle states without a period (`rsa` of a family) was
written as a sentence missing its period place; it is now the value of the
case's own period (`input_facts/5`).

**Item 3, the rolling year.** `Period(('year', period.start, 1)).offset(-1)`
is read as `twelve_months_from(months_before(period, 12))`, a period of its
own named `2021-03_12m` (as `_3m` names three months), and a further
`.offset(-1, 'month')` moves its first month. A case states *2021-03_12m
est les douze mois à partir de 2021-03* and its twelve months. (The first
day of a period of months, `2015-07_3m`, had been written as
`2015-07_3m` itself; it is now `2015-07-01`.)

**Item 7, the way back of the country template.** Two general defects:
`of_export.pl` declared a variable whose values in the scenarios are dates
(`birth`) as a `float`, and openfisca-core cannot read a date into a float;
it is now a `datetime.date`. And `rulespec_export.pl` put each person's
given value (`the birth given of person_3`) at the top of the case, where
every person of the household received every value; it now goes in the
person's own record. 32 of 32; `test_openfisca.pl` passes 5 of 5.

**Item 0, the income-tax twin**, rebuilt alone with the extraction and
engine run of 11 October 17:53 (`OF_SKIP_EXTRACT=1`). The twin-writing
phase took more than 90 CPU-minutes, using about 160 MB each time it was sampled; the earlier
stopped runs had not been given that long. 2 of the 434 cases are left out.

| Value the case asks for | Agree | Disagree (of which no answer) |
|---|---|---|
| `nbptr` | 363 | 0 |
| `rfr` | 351 | 1 |
| `rbg` | 321 | 0 |
| `rni` | 251 | 0 |
| `iai` | 172 | 124 |
| `reductions` | 90 | 53 |
| the others | 207 | 15 |
| **all** | **1,755** | **193 (170)** |

- **Duflot-Pinel-Denormandie**: 105 of the 119 expectations of its cases
  agree (the reduction was 0 in 10 cases before the fix of `stage()`). The
  14 left are 7 cases (`reduc_duflot_3`, `_4`, `reduc_pinel_dom_3`, `_4`,
  `_test_plafond_300_000`, `reduc_pinel_metro_3`, `_4`) whose tax and
  reductions answer nothing.
- **The high-income contribution**: still 6 disagreements. In 5 cases of
  incomes taxed at the flat rate (`…_au_PFU`) the engine gives 0 and the
  twin 1,500 to 27,500; in the 2026 case with smoothing the engine gives
  4,500 and the twin 0.
- 170 of the 193 disagreements are no answer at all, mostly `iai` and
  `reductions`: the next thing to trace, case by case.

### Where to pick this up (written 12 October 2026)

1. **The income tax**: the 170 expectations without an answer (start with
   `reduc_pinel_metro_3`), then the flat-rate cases of the high-income
   contribution.
2. **`ppa_fictive`**: translate `ppa_forfait_logement` (r6), or teach the
   walk of `migration_pending` that a value given for other periods does
   not give the case's own.
3. **The RSA's own amount** (`rsa_socle`): the parameter `rmi.rmi_m.rmi` in
   the tests' years.
4. Items 5, 6 and 8 of the list above.

## The second round, 12 October 2026

Three CPU-hours, taken in the order of the pick-up list just above.

**The income tax: steps of a formula read once per year were lost.** The
2016 version of the Duflot-Pinel-Denormandie reduction reads its own step 3,
and the twin declared step 3 as a value the case states: no rule wrote it.
A formula whose shape depends on the calculation's year is read once per
year of the twin's window (`period.start.year`, Phase 3b′ item 4). Each
reading registered its steps, but only the last year's reader was kept:
the steps, reads and periods of every other year were dropped. All are
kept now (`of_extract.py`, the loop over `read_one(y)`). 494 steps are
referred to and all 494 now have a rule (before, steps 3 and 5 of the Duflot-Pinel-Denormandie
reduction had none). The cases dated 2016 and 2017 were nearly all among
the 170 expectations without an answer: the reductions feed `iai`.
Rebuilt with that fix alone (`OF_REUSE_ORACLE=1`, about 95 CPU-minutes):
**1,925 of 1,948** expectations agree (1,755 before), and every expectation
now has an answer (170 had none).

| Value the case asks for | Agree | Disagree |
|---|---|---|
| `nbptr` | 363 | 0 |
| `rfr` | 351 | 1 |
| `rbg` | 321 | 0 |
| `rni` | 251 | 0 |
| `iai` | 293 | 3 |
| `reductions` | 139 | 4 |
| the others | 207 | 15 |

Duflot-Pinel-Denormandie: **119 of 119**. The 23 left:
- 6 differ by one euro (`iai` 1,359 for 1,358, `reductions` 6,663 for
  6,662, the décote 83 for 84): a rounding to the euro, to trace.
- 9 are the high-income contribution's flat-rate cases and its 2026 case
  with smoothing: this build's reader still carried the 2025 gain into
  2026 (see the next paragraph, done after the build started).
- 8 are the trade-union dues (`Cotisations_syndicales_…`): the reduction is
  a twelfth of the expected one (27.5 for 330, 7.15 for 85.8, 7.315 for
  87.78). Their ceiling is 1% of the year's salaries, read through the
  tax household's members (`foyer_fiscal.members('salaire_imposable',
  period, options=[ADD])`); the twin states a month's salary, and a direct
  read with `[ADD]` is multiplied by twelve (`scaled`), but a read through
  the members was not. It is now (`member_read`), after this build: the
  housing allowance and the RSA are unchanged by it, the income tax is to
  be rebuilt.

(This build also predates the French helper names below: the income-tax
twin still says *member part of* and *step*.)

**A value given for one year is not given for the next.** The test
"Célibataire à 500 000 € de revenus, au PFU" gives the capital gain `f3ua`
for 2025 and expects the high-income contribution for 2025 and for 2026.
The reader carried the 2025 gain into the 2026 case (`at_period` takes the
latest earlier value), so the twin owed 7,500 € where the engine, which
does not carry an input to another period, owes nothing. An input given
only for other periods now has its default in the case (`given_at`), except
a variable defined once for all time; a computed value given for other
periods only is left to the oracle. 8 of the 434 income-tax cases are
concerned, among them the 6 cases of the high-income contribution. The
housing allowance and the RSA are unchanged by it (50 of 50, 28 of 28).
**The income-tax twin has not been rebuilt with this change** (its build
takes about two hours; the engine must run its cases again).

**The RSA's `ppa_fictive`**: a value a case gives counts as giving an
expected value only when it is for the same thing (the same family, the
same month): `le_migration.pl`, `expected_not_given/4`, and the test
`given_for_another_period_still_waits`. The 4 failures are now pending, as
are 4 expectations that had agreed only by answering 0, the value of the
`otherwise` branch: **28 of 28** checked expectations agree, 12 pending.

**The French of the twins (item 5, in part).** The names of the rules the
translator adds are French in openfisca-france's twins: *compte pour*,
*contribution du membre à*, *étape* (`etape`), *a des membres qui comptent
pour*, … (`HELPER_WORDS`), and so are the notes it writes as their source
(*la valeur de … à cette étape de la formule*, *la valeur par défaut du
modèle, quand le cas n'en donne pas*). LE2's writer now elides the first
word of a line too (*l'aide logement … d'un ménage est un montant M si*,
was *la aide logement*): `le_writer.pl`, `elide_words/4`, test
`writer_elides_at_line_start`. The articles of the variables' names (*le
zone*, *le pensions*) are not done.

### Where to pick this up (written 12 October 2026, second round)

1. **Rebuild the income tax** with the reader of this round (no
   `OF_SKIP_EXTRACT`, no `OF_REUSE_ORACLE`: the cases changed): the 8 cases
   of `given_at`.
   That build also checks the trade-union dues (`member_read`).
2. The six one-euro roundings: traced (third round, below); a decision,
   not a defect of the twin.
3. The articles of the French twins (item 5); the contributions (item 6).

## The third round, 12 October 2026

**The six one-euro differences are the engine's floating point.** The
calculator's tests give a yearly salary (50,000 €); the engine divides it
among the twelve months and adds them up again, and the sum falls just
short: the net taxable income of `maj_nbp_2` is 89,999.99999999999, of
`charges_deduc_non_plafonnees_reparations_2` 19,999.999999999993, of
`reduc_dfppce_7` 44,999.99999999999. The tax before the family-quotient cap
is then 4,791.4999999999 (exactly 4,791.50 in the twin), which rounds to
4,791 in the engine and to 4,792 in the twin; the décote of the second case
(84 against 83) and the reductions of the third (7,105 against 7,106)
follow the same way. The tests' expected values agree with the engine.
The twin computes with the twelfths the scenario states, so its sums are
whole; matching the engine would mean copying its rounding error, which is
not the law. Left as it is, and recorded here
(`.cache/venv-fr/bin/python`, a SimulationBuilder run of the source test).

**Articles of the French twins.** A first word that reads as a plural now
takes *les* (*les pensions alimentaires percues*, was *le pensions*; the verb is still *est*), with a
list of singular words that end in -s or -x (*le taux*, *le mois*); *zone*
and *prime* are feminine (LE2 `i18n/writer_words.csv`). (`rulespec_twin.pl`,
`fr_plural/1`.) Accents are still missing (*percues*): the variables' names
have none, and their labels are not used for the sentences.

**The income tax rebuilt in full** (extraction and engine run again,
`given_at` and `member_read` in): **1,934 of 1,948**, no writer
error. The 5 flat-rate cases of the high-income contribution now agree; the
2026 case with smoothing still differs (3 expectations). The trade-union
dues went from 8 to 5 differences (4 of the reduction cases, 1 of the
credit): to trace. The other 6 are the one-euro differences above, the
engine's floating point.

**A value read "for the year" that has a period place.** The RSA's one
writer error: `rsa_base_ressources_patrimoine_individu` reads
`assiette_csg_plus_values` for `period.this_year`, which the reader takes as
the case's one value, but other formulas read that variable at other
periods, so its sentence has a place for the period, and the read was one
place short. Such a read is now made at the year (or first month) by name
(`of_extract.py`, the `other` branch of `read`). RSA rebuilt with its engine: no writer error any more, 28 of 28.

## The fourth round, 12–13 October 2026

Eight machine-hours, taken in the order of the third round's list, with two
programmes of the October plan that had never been built.

**The accents of a French twin come from the source's own labels.** A package
of variables names them without accents (`credit_impot_logement`), while the
label of each variable — the words the twin's rule cites as its source — is
written for a reader (*Crédit d'impôt pour le logement*). Every word of a
name is now spelled as the module's own labels spell it, when the accented
spelling is the commonest one there: *le crédit impôt*, *la réduction*, *les
intérêts*, *l'année*, *l'indemnité résidence*, *la rémunération principale*,
*les congés payés*. A word the labels write oftener plain (*controle*), or
one shorter than four letters (*a* and *à*, *ou* and *où*), keeps the name's
own spelling. The income tax gains 49 accented words, the payslips 31.
(`rulespec_twin.pl`, `accents/2` and `words_of/2`; LE2's writer and parser
read accented words already, as the Catala twins show. Test:
`a_french_twin_takes_the_accents_of_the_labels`.)

**A turned-around input reads in French too.** An input of the package whose
default is "yes" is turned around, so that a scenario which does not state it
means what the package's default means; the turned name was always English
(`is_not_rempli_obligation_scolaire`), which put *is not* in a French
sentence. A name with no English verb to turn now takes the negative word of
the twin's language: *l'individu remplit la condition non rempli obligation
scolaire*. (`of_extract.py`, `turned_name/1` and `HELPER_WORDS`.)

**The person of a case stated flat holds the roles OpenFisca gives it.** The
trade-union dues' tests state a salary and box 7AC and nothing else — no
`individus:` list, no `declarants:`. OpenFisca builds such a case with its
one person in the first role of each group (`add_default_group_entity`), so
that person is the tax household's declarant; the reader left every role
unstated, so the twin read no declarant, `celibataire_ou_divorce` was false,
the number of adults and the number of parts (`nbptr`) were 0, and the tax
before reductions divided by a number of parts of 0 and answered nothing.
That is what the third round's five trade-union differences were: not the
dues, which agree (330 €, 85.8 €, 87.78 €), but the tax they are taken from.
The case now states *individu_1 est declarant principal dans le foyer
fiscal*, and false for the roles it does not hold. (`of_extract.py`,
`default_roles/2`.)

**A computed value the case gives for other periods only is not stated at
all.** (The third round left the 2026 case of the high-income contribution
with three differences.) The test gives the tax household's revenu fiscal de
référence (`rfr`) for 2024 and 2025 and expects the twin to work out the one
of 2026, 500,000 €. The reader wrote the case two keys for that one
variable: its value at each period the test gives it for, and — for the
case's own period, which the test does not give — the model's default,
nothing. Of two keys naming one input the twin keeps the input's own, so the
case said *le rfr donné de foyer_fiscal_1 pour 2026 est 0*, which the rule
reads before its own conclusion: the twin answered nothing for the revenu
fiscal de référence, for the contribution with smoothing and for the one
without. A value the package computes is now not stated at all where the
test gives it only for other periods: the case's own period is the twin's to
work out, and the test's own values of 2024 and 2025 — which the smoothing
reads — stay. (`of_extract.py`, `stated/5` and `NOT_STATED`.)

**File ▸ Open of a package read its reforms as the package's own.** Found by
the translator's own test suite in this round, and wrong in the worst way:
silently, under the law's name. The static reader — the one File ▸ Open uses,
which reads an upload's Python without installing the package — walks every
`.py` of the folder, and a *reform* replaces a variable of the package with
its own. The country template ships one that makes the social security
contribution 3% of the salary flat, where the law has a marginal scale of
three brackets with dated rates; the upload's twin then answered 60 € where
the package's own test expects 40 €, in five of its 35 cases. A reform is
another program, and is left out now (`of_static.py`, `read_variables/1`), as
a test naming one already was. The twin of an upload of the country template
is back to every case passing.

### Two programmes of the October plan built for the first time

Both are twins of `openfisca-france` that the plan names and no round had
built: the payslip contributions and the family benefits.

**`cotisations_sociales` — the payslip contributions.** The programme of the
plan's step 8: `cotisations_salariales`, `cotisations_employeur`,
`salaire_net` and `salaire_super_brut`, with the package's own payslip tests
(`tests/fiches_de_paie`: a template and eight real payslips of 2011 to
2015). The twin reads 125 variables (49 translated, 40 residue, 36 facts the case
states) and 430 parameters; 517 ledger elements encoded, 1 approximated, 40
residue; no writer error. Of the nine payslips, one is in the twin's reach,
and its four checked expectations agree; 46 more are pending behind the
residue. The other eight are out of reach before any residue: seven expect a
figure within half a cent (`absolute_error_margin: 0.005`), which is not a
whole number of cents, and Logical English compares numbers exactly; the
ninth gives the start of an apprenticeship contract as more than one value.

The forty residue blocks are one shape of formula, the one every
contribution of a payslip uses. Such a formula has two steps. It calls
`apply_bareme` with the kind of contribution (the employee's), the name of a
scale and the name of the variable. Then it multiplies the result by a test
of the employee's category. (The formula of `agirc_salarie`, in
openfisca-france, is an example. The package's code is AGPL-3.0, so it is
described here and not copied.)

`apply_bareme` is the package's own helper (`cotisations_sociales/base.py`).
It applies a named scale — a barème of marginal rates whose thresholds are
multiples of the ceiling of the social security (`plafond_securite_sociale`)
— to the base of the contributions (`assiette_cotisations_sociales`), taking
the scale of the employee's own category out of the parameter tree
(`cotsoc.cotisations_salarie[<catégorie>][<barème>]`), and it does so in one
of three ways, by the recovery mode the case states
(`cotisation_sociale_mode_recouvrement`): *mensuel strict*, the month's own;
*annuel*, nothing until December and the whole year in December; *mensuel*
(anticipated), the month's own until December and, in December, the year's
less the eleven months already taken. The reader has every piece of that
except the helper itself: scales as brackets, a parameter chosen by a code,
a sum over the months of a period, a value read at another period. Writing
it is the next round's first item, and the one that would let the payslip
tests be checked: none of the nine is dated December, so the three modes
would all be exercised by the month's own branch.

**`prestations_familiales` — the family benefits.** The programme of the
plan's step 9: the allocations familiales (`af`, with its base and its
majoration), the complément familial (`cf`), the PAJE (`paje_base`) and the
allocation de soutien familial (`asf`), with the package's own tests of the
family benefits. The twin reads 78 variables (41 translated, 4 residue, 33 facts the case
states) and 66 parameters; 176 ledger elements encoded, 9 approximated, 6
residue; no writer error. The engine reproduces 71 of the package's 113
cases, and the 42 others are out of reach for the margin above (a figure
within half a cent). Every case the twin can state still waits for residue,
so it checks nothing yet.

Six residue blocks, of four shapes:

- **A formula the reader writes and its own grammar cannot read back.** The
  means test of the family benefits reads, for each member of the family,
  the collective income of that member's *tax household* two years earlier:
  the reader writes the member's contribution as `(if is_demandeur_in_famille:
  member_of_foyer_fiscal.at_period(rev_coll, years_before(period, 2)) else:
  0)`, and its expression grammar accepts a value read through a relation
  (`member_of_foyer_fiscal.rev_coll`) but not one read through a relation
  *at a period*. The grammar needs a `field` whose field is a read at a
  period; that is the one defect of the six, and it blocks the means test,
  which every case of the family benefits waits for.
- **A period of six months.** Whether a child is financially independent
  reads the net salary of the six months before the month asked about
  (`Period(('month', period.start, 6)).offset(-6)`). The reader names a
  period of three months (*les trois mois avant*) and a rolling year (*les
  douze mois à partir de*), each a period of its own whose months the case
  states; it should name a period of any number of months
  (`last_n_months_of(period, n)`), which is the same machinery with the
  count as a place.
- **A parameter read at a date the formula works out, and an instant used as
  a value** (the PAJE's `apje_avant_cumul`, and the age limit of a child
  under the old APJE).
- **A parameter the package no longer has**
  (`prestations_sociales.prestations_familiales.petite_enfance.apje.age_limite_enfants_ouvrant_droit_apje`),
  which is the shape the RSA's `rsa_socle` already showed: a formula of a
  year whose parameter was removed from the model.

**A period of any number of months, and the family benefits' first
answers.** The reader named a period of three months (*les trois mois
avant*, the RSA's salaries of the last three months) and a rolling year
(*les douze mois à partir de*), and refused any other count; whether a child
is financially independent reads the net salary of the six months before the
month asked about, and that was residue. Such a period is now named with its
count as a place — *une période est les 6 mois avant une période*, a period
of its own (`2019-07_6m`) whose months the case states, as `_3m` and `_12m`
already were; three months keep their own sentence, so the RSA's twin does
not change. The family-benefits twin, rebuilt with it, **answers its first
cases: 3 of 3 expectations agree**, 42 of its variables translate (41
before) and three residue blocks are left (four). Its 42 cases out of reach
are out of reach for the margin, not for the residue.

**PolicyEngine carries an input forward and openfisca-core does not.** The
one difference the round cost, found in the first SNAP build since the third
round. "Case 7, weeks worked reported for 2024 carry forward to 2026" gives
`weeks_worked` for 2024 only and asks about 2026, and PolicyEngine carries
that input forward — 26 weeks of 2024 are 26 weeks of 2026, so the work
requirement is 40 usual hours × 26 / 52 = 20. openfisca-core does not carry
an input to another period, which is what the third round measured on the
2026 case of France's high-income contribution, and the reader now gives
such an input its default whichever package it is reading: SNAP's twin reads
no weeks worked and keeps the usual 40 hours. **The reader has to know which
engine it is reading**, as it already knows which language to write; that is
one line in `given_at` and a rebuild of SNAP (an hour and a quarter), which
did not fit in this round.

**Every twin of this round, measured.** *Tests*: the cases the package's own
engine reproduces, of those the twin can state. *Ledger*: source elements
encoded / approximated / residue. *Expectations*: the answers the twin
checks, against the package's own tests.

| Twin | Package | Variables (translated / residue / facts of the case) | Parameters | Tests: engine reproduces, in the twin's reach | Ledger: encoded / approx. / residue | Expectations pass / fail | Cases left out |
|---|---|---|---|---|---|---|---|
| `aides_logement` | openfisca_france | 52 / 1 / 74 | 208 | 50 of 53 | 435 / 29 / 11 | 50 / 0 | 12 |
| `aides_logement_croise` | openfisca_france | 48 / 0 / 69 | 182 | 36 of 36 | 386 / 25 / 8 | 216 / 0 | 0 |
| `cotisations_sociales` | openfisca_france | 49 / 40 / 36 | 430 | 1 of 9 | 517 / 1 / 40 | 4 / 0 | 8 |
| `country_template` | openfisca_country_template | 13 / 0 / 6 | 25 | 32 of 35 | 45 / 4 / 0 | 32 / 0 | 3 |
| `impot_revenu` | openfisca_france | 181 / 0 / 1805 | 411 | 432 of 434 | 2891 / 18 / 1 | 1942 / 6 | 2 |
| `prestations_familiales` | openfisca_france | 42 / 3 / 34 | 68 | 71 of 113 | 180 / 9 / 5 | 3 / 0 | 110 |
| `rsa` | openfisca_france | 54 / 8 / 75 | 88 | 157 of 207 | 280 / 10 / 14 | 28 / 0 | 179 |
| `child_benefit` | policyengine_uk | 10 / 0 / 6 | 5 | 4 of 4 | 22 / 2 / 0 | 4 / 0 | 0 |
| `ctc` | policyengine_us | 20 / 0 / 7 | 18 | 47 of 48 | 47 / 2 / 0 | 56 / 1 | 1 |
| `eitc` | policyengine_us | 15 / 0 / 27 | 41 | 42 of 46 | 94 / 1 / 0 | 46 / 4 | 4 |
| `snap` | policyengine_us | 79 / 4 / 113 | 105 | 962 of 1103 | 332 / 30 / 4 | 361 / 48 | 713 |
| `universal_credit` | policyengine_uk | 58 / 5 / 70 | 85 | 182 of 196 | 243 / 9 / 5 | 219 / 3 | 29 |

### Where to pick this up (written 13 October 2026, fourth round)

1. **`apply_bareme`** (the design above): the forty residue blocks of the
   payslips, and with them the nine payslip tests, wait on that one helper.
   It needs no new Logical English: a scale by category of employee, the
   ceiling of the social security as the scale's factor, and the recovery
   mode as three dated branches.
2. **A value read through a relation at a period** (`field` of a read at a
   period, in the reader's expression grammar): the family benefits' means
   test, and whatever else reads a group's value of another year through its
   members. The reader writes that expression already and cannot read it
   back, so it is a defect, not a missing feature.
3. **The reader has to know which engine it is reading**: PolicyEngine
   carries an input to a later period and openfisca-core does not (the
   paragraph above). One line in `given_at`, and a rebuild of SNAP to see
   its one expectation come back.
4. The PAJE's parameter read at a date the formula works out; the parameters
   the package no longer has (as `rsa_socle`); the instant used as a value.
5. Build time (item 8 of the first list, still open). What a build costs,
   measured in this round (wall clock, one machine of eight cores):

   | Build | Time | Where it goes |
   |---|---|---|
   | the income tax alone | 2 h 06 | the reader 1 min, the engine's 434 cases 11 min, and 1 h 54 to write the program (5.7 MB), parse it and run its 1,948 expectations |
   | the RSA alone | 45 min | the engine's 207 cases 41 min |
   | the four other French twins, one batch | 19 min | one load of openfisca-france for the four; 211 cases on the engine |
   | the country template | 1 min | |
   | Child Benefit and Universal Credit | 4 min | |

   So the lever is the twin phase of the income tax, not the reader: a
   program of that size is written, parsed and run once per build. A build
   now says how long each of its phases took (`of_build.pl`, `timed/3`:
   *impot_revenu: the twin took 114 min 0 s*), which is where the next round
   should start; the candidates within that phase are the writer's work over
   2,891 ledger elements and the 1,948 expectations, each of which runs
   against the program's rules.

## The fifth round, 13 October 2026

Two hours, taken in the order of the fourth round's list: items 2 and 3.

**The reader knows which engine it is reading.** PolicyEngine's core carries
an input forward to a later period and openfisca-core does not — SNAP's test
"weeks worked reported for 2024 carry forward to 2026" is a test of 26 weeks
in 2026, where a capital gain of 2025 is no gain in 2026 for
openfisca-france. The third round taught the reader openfisca-core's rule,
and the fourth round's SNAP build showed what it cost: one expectation of
409. The reader now takes the earlier value where the package is one of
PolicyEngine's, and only for an input — a value a package *computes* is
worked out afresh for each period by both engines. (`of_extract.py`,
`DIALECT`, `CARRIES_FORWARD`, `given_at/3`; the dialect was already known for
the twin's language.) SNAP rebuilt with it: **362 of 409**, the expectation
back and the figure of 11 October with it.

**A value read through a relation at a period** (item 2), a defect rather
than a missing feature: the reader wrote an expression its own grammar could
not read back. For each member of a family, the means test of the family
benefits reads the collective income of that member's *tax household* two
years earlier, and the reader writes it as

```
(if is_demandeur_in_famille:
    member_of_foyer_fiscal.at_period(rev_coll, years_before(period, 2))
 else: 0)
```

The expression grammar accepted a value read through a relation
(`member_of_foyer_fiscal.rev_coll`) but not one read through a relation *at a
period*, so the whole means test was residue and every case of the family
benefits waited for it. A name after the dot may now be a call
(`rulespec_reader.pl`), and the twin builder writes it as the group the
person is a member of and that group's value at the period the read names
(`rulespec_twin.pl`, `scalar/5` and `note/3`). **The family-benefits twin
answers 54 of its 55 expectations** (3 of 3 in the fourth round, where the
means test was residue), with three of its six residue blocks left.

**The one that failed, and the three defects behind it.** The complément
familial's property income: `cf_base_ressources` expected 20,000 €,
answered 0. The test gives the tax household's property income for 2016 and
asks about January 2018, and the means test reads the household's
`rev_coll` of the year before last, which the twin read as 0. Following
that one case found four things, each general:

- **A value the package computes has no default at any period.** The fourth
  round stopped stating the model's default for such a value at the case's
  own period; at the other periods it was still stated, and a given value is
  what the rule reads first. (`of_extract.py`, `period_inputs/10`.)
- **The oracle states a value of a group of another kind than the case asks
  about.** It stated the engine's values for the case's own entity and for
  each person, and skipped a group of another kind — the tax household of a
  case about a family — so nothing stood where the default had been.
  (`of_oracle.py`, `boundary/7`.)
- **And the twin states it of that group.** Of two groups related through
  the person rather than to each other, the reader fell back to the case's
  own subject: *le rev coll donné de famille_1*, a sentence no rule matched,
  where the rules read that value of the tax household.
  (`rulespec_twin.pl`, `input_target/4`.)
- **The roles a lone person holds in each group are kept.** A case stated
  flat puts its one person in every group, and the reader emptied each
  group's list but the subject's own, to avoid stating the person's values
  twice — taking the roles with them. The means test needs the declarant of
  the tax household, and there was none. (`of_extract.py`.)

With the four, the family-benefits twin **answers every expectation it
checks: 55 of 55**, no writer error — from 3 of 3 at the start of the round,
by way of 54 of 55. Its three residue blocks are the PAJE's parameter read
at a date the formula works out, the instant used as a value, and a
parameter the package no longer has.

**What the four cost, and what it took to see it.** The four fixes above
were measured on the family benefits, where they were found. Rebuilding the
other French twins with them showed two regressions, each of a kind worth
recording:

- **The housing allowance lost all 50 of its checked expectations.** A case
  that states a value the program computes is a case the twin builder
  refuses, unless the variable is marked *overridable* — the twin then reads
  the value the case gives first and its own rule otherwise. The reader
  marks that for the values the *tests* give, before the engine has run; the
  engine's own values are added to the cases afterwards, and the oracle had
  just learnt to state the values of a group of another kind, which the
  housing allowance computes itself. A value the oracle states is now marked
  overridable too (`of_oracle.py`, `overridable_as_stated/3`), and the
  housing allowance is back at **50 of 50** — with eight ledger elements
  more encoded and three residue blocks instead of eleven — its cross-check
  with the Catala twin at **216 of 216**.
- **The RSA's build stopped with a type error.** The grammar of this round
  reads a call after a relation, and the RSA reads its members' rente
  viagère over the months of the year before last
  (`member_of_foyer_fiscal.sum_over_months(…)`), which the twin builder took
  for a name. Such a read is now written as the group's value summed over
  the months of that period, and any other call after a relation is residue
  with its reason rather than an error (`rulespec_twin.pl`). Its twin then
  grew to 12 MB — twice the income tax's — and the thread that reads a
  written program for its tests ran out of stack; that thread now has two
  gigabytes (LE2 `le_migration.pl`, `tests_of_file/2`) — and then the parse
  passed the load limit of five minutes and the twin counted no tests at
  all. So the growth is the defect, not the stack: a case now states a value
  of **every group at every period it names**, and the RSA's 207 cases carry
  enough of those sentences to make a program twice the size of the income
  tax's. The twin in this repository is still the measured one (28 of 28,
  built on 13 October before these four changes); the reader that would
  write it again is this round's, so that pair is the next round's first
  measurement. What the oracle states has to be narrowed to the values a
  rule actually reads at those periods.

Two lessons for the next round, both about measuring: a change to what a
case states has to be tried on every twin that states such values, not only
on the one that showed the defect; and the twins' builds are cheap to repeat
without the engine (`OF_SKIP_EXTRACT=1` keeps the cases and rewrites the
twins — three of them in three minutes) as long as the change is in the
twin builder rather than in the reader.

**The income tax, rebuilt with the six changes: 2,286 of 2,302, and nothing
left as residue.** (1,942 of 1,948 before; the build ran on past the end of
the round and its figures are here.) The one residue block left — the tax a
household still has to pay, `impot_revenu_restant_a_payer` — is translated
now that a value read through a relation at a period can be written, so the
354 expectations that waited for it are checked: **the income-tax twin has
no residue at all**. It is still 5.7 MB and still parses in minutes, so the
growth that made the RSA's twin 12 MB does not reach it; its cases name few
periods of few groups.

Of the 16 that differ, 10 are the one-euro roundings the third round traced
to the engine's floating point — the six of before, and four more that are
the same difference showing through the tax to pay, checked for the first
time. The other **6 answer nothing**: the tax to pay in four cases, a credit
in one, and the tax to pay of a case expecting 63 €. That is the first new
work this round leaves.

### Where to pick this up (written 13 October 2026, fifth round)

1. **`apply_bareme`**: the forty residue blocks of the payslips, and with
   them the nine payslip tests, wait on that one helper of the package. The
   design is in the fourth round's section.
2. The PAJE's parameter read at a date the formula works out; the parameters
   the package no longer has (as `rsa_socle`); the instant used as a value.
3. Build time: the measurements are in the fourth round's section, and a
   build now prints the time of each phase.
4. **The RSA's twin of 12 MB.** A case now states a value of every group at
   every period it names, and the RSA's 207 cases carry enough of those
   sentences to pass both the test thread's stack and its five-minute load
   limit: the twin counted no tests, and the one in this repository is still
   the measured one (28 of 28, built before this round's changes).
   **Narrow what the oracle states to the values a rule reads at those
   periods** (`of_oracle.py`, `boundary/7`: it states every by_period
   variable of every group of the case, where the reader knows which
   variables are read at which periods), then rebuild the RSA. The income
   tax does not have the problem (below), so this is the RSA's own shape:
   three months, twelve months and six months of several groups at once.
5. **The six expectations of the income tax that answer nothing** (below):
   the tax a household has to pay, in four cases, a credit in one, and a
   case expecting 63 €.

## openfisca-france: the survey of 9 October 2026

`openfisca-france` runs in an environment of its own (`.cache/venv-fr`:
it needs openfisca-core 44, the other packages 45). `of_survey.py france`
reads every computed variable as the twins are read: 524 of 988 translate
(53%); the residue by need, the reads of another period and the areas of
the model are in `runs/france_survey.json`. The plan built on it is the
roadmap's Phase 3b′ (a working paper of the author, not published).

```sh
cd .cache && python3 -m venv venv-fr && venv-fr/bin/pip install -e ./openfisca-france
cd .cache && venv-fr/bin/python ../of_survey.py france --json ../runs/france_survey.json
```

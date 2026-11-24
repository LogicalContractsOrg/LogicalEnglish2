# OIPA → Logical English (Phase 2b)

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

Phase 2b of the design notes `roadmap.md` (§5.9, §8): a reader over
the configuration of **Oracle Insurance Policy Administration** — the Rules
Palette's XML for a transaction and its attached rules — and one Logical
English twin per transaction, in the timeless reading (an activity's values
from its fields, the policy it finds and the plan). There is no public OIPA
and no public configuration, so the phase is built, as the plan says, on a
**synthetic corpus** written from the forms of the public *OIPA XML
Configuration Guide* (release 9.7, docs.oracle.com), with the expected
values computed **independently** of the translator.

| File | What it does |
|---|---|
| `corpus/annuity/`, `corpus/termlife/` | two synthetic plans: a deferred annuity (Deposit, Withdrawal with a free amount, a surrender charge by policy year and a MathIF, FullSurrender spawned by a withdrawal that leaves too little) and a level term life policy (Issue with ANB issue age, a premium rate by age, gender and tobacco, modal premiums; PremiumPayment advancing the paid-to date; GraceCheck spawning a lapse); per transaction `Transaction.xml` and its attached rules `ValidateExpressions.xml`, `SpawnActivities.xml`, `CopyToPolicyFields.xml`; per plan `Rates.csv` (AsRate), `PlanFields.csv` (AsPlanField) and `cases.json` (policy lives: activities in order) |
| `oipa_reader.pl` | a plan directory → transactions: fields, MathVariables in order (FIELD, POLICYFIELD, PLANFIELD, VALUE, EXPRESSION, FUNCTION, IIF, RATE) and MathIFs, validations, spawns, copies; the guide's expression operators (`And Or Not = <> != < > <= >= + - * / ^ %`, functions) |
| `oipa_twin.pl` | a transaction → a migration (`le_migration.pl`): templates, rules, a loaded decision table per rate description, plan facts, checks, spawns, the policy after the activity, a View, queries, the policy lives' activities as scenarios, the ledger |
| `oipa_eval.py` | **the oracle**: an interpreter of OIPA transaction math in Python, sharing no code with the translator (Decimal arithmetic, ROUND half up, the guide's definitions of DurationOf, ANBAgeOf, DaysDiffOf, MonthsAdd, TruncateNumber, MinOf, MaxOf; RATE by exact criteria with DEFAULT; attached rules; a refused activity changes nothing; a spawned transaction runs at once) — it plays each policy life and reports every activity's values |
| `build.pl` | the twins into LE2's `examples/migration/oipa/<plan>_<transaction>/` (`le2_paths:twins_dir/2`) |
| `oipa_import.pl` | File ▸ Open of a transaction's `.xml` (root `<Transaction>` with a Math or Fields section), or of a `.zip` of a plan folder or of one transaction's folder: the attached rules and the plan's `Rates.csv` / `PlanFields.csv` are read when they sit beside the transaction; the twin laid out as `build.pl`'s (`sources/<Transaction>/Transaction.xml`, where the citations point); the note says what was read and what was not |
| `test_oipa.pl` | plunit: the operators, the reader, every twin passing, File ▸ Open |

## How to run

From the LE2 checkout (`/work`), with Python 3:

    ./myswipl.sh -q migration/oipa/build.pl
    ./myswipl.sh -q -g run_tests -t halt migration/oipa/test_oipa.pl

## The mapping

- An **activity field** (`FIELD Activity:GrossAmount`) is `the gross amount of
  *an activity* is *an amount*`, a fact of the case; the effective date is
  `the effective date of *an activity* is *a date*`, and a twin, which is one
  transaction, says what its activities are: `an activity is a withdrawal if
  the effective date of the activity is a date` — the condition of a line
  that reads nothing of the activity (a fallback, a copy). A **policy field**
  (`POLICYFIELD AccountValue`) is `the account value of the policy before *an
  activity* is ...` — the policy as the activity finds it. A **plan field**
  (`PLANFIELD`) is `the minimum balance of the plan is ...`, its value a fact
  of the program cited to `PlanFields.csv` (or to the MathVariable's DEFAULT).
- A **MathVariable** is `the net amount of *an activity* is *an amount*` with
  one rule citing it (`rule net_amount with provenance "Withdrawal/Transaction.xml"
  at MathVariable NetAmountMV`): the variables it reads are conditions, the
  EXPRESSION its arithmetic, `ROUND="2"` written `round(E * 100) / 100`, an
  INTEGER from a division truncated. A **VALUE** set once is written in place.
- **IIF**, and a **MathIF** that sets a variable set before it, are
  `otherwise` cascades, the latest assignment first — OIPA evaluates top to
  bottom and the last assignment wins. A MathVariable that reads a variable
  **between two of its assignments** reads the value it had then: that value
  is a rule of its own, the cascade of the assignments made so far (`the
  first value of the charge of *an activity*`), and the ledger row of the
  reassigned variable says so. A MathIF's condition reads the values set
  before the MathIF. A variable read before any assignment is residue.
- **RATE** is a decision table loaded from a CSV beside the twin (the plan's
  rates of that description: criteria columns and the rate), `with unique
  match`; its DEFAULT the cascade's last line. OIPA's criteria are exact
  codes (`02`, `N`), and stay codes.
- **FUNCTION**: DurationOf is lib/temporal's `the age on *a date* of someone
  born on *a date*` (full years between two dates); DaysDiffOf `*a date* is
  *a number* days after *a date*`; MonthsAdd `... months after ...` (the
  calendar months OIPA means); TruncateNumber `truncate`; MinOf / MaxOf LE's
  minimum and maximum. **ANBAgeOf** (the age at the nearest birthday) is the
  age six calendar months later — approximated, and flagged: the two can
  differ by a day at the half-year.
- **ValidateExpressions** → `*an activity* fails the check *a code*` (the
  message as the rule's comment, its `$$$GrossAmountMV$$$` placeholders
  as `[the gross amount]`); **SpawnActivities** → `*an activity*
  spawns *a transaction*`; **CopyToPolicyFields** → `the account value of the
  policy after *an activity* is ...` — the last two only for an activity that
  fails no check, since OIPA refuses it.
- A **View** per transaction prices an activity (le_summary.md §17.10): the
  activity's fields, the policy it finds, the first logged value as the
  result, the checks.

Not translated: SQL, OBJECT/COLLECTION/ARRAY and the other MathVariable
types above, a FIELD set inside a MathIF, the functions the corpus does not
use, and a reference to a variable the transaction does not set — each a
`% RESIDUE` block with the MathVariable's XML (every assignment of it),
concluding its template, and a ledger row *residue*; a `MathLoop` (or any
other element of the Math section the reader does not know) is one residue
block with its XML, concluding the MathVariables set inside it, with a
ledger row for the loop and one per variable. A check, spawn or copy that
reads what cannot be translated is left out with a ledger note. Assignments
to funds (Assignment elements) and Valuation are not read.

## Results (14 September 2026)

| Twin | Transaction | Scenarios (activities) | Expectations (the interpreter's values) | Ledger enc/approx/residue |
|---|---|---|---|---|
| `annuity_deposit` | Deposit: premium tax, a bonus by size (IIF), the new account value; 2 checks | 4 | 12/12 | 13/0/0 |
| `annuity_withdrawal` | Withdrawal: policy year, free amount, surrender charge rate (RATE), a MathIF, net amount; 2 checks; spawns FullSurrender; copies the account value | 7 | 30/30 | 20/0/0 |
| `annuity_full_surrender` | FullSurrender (spawned): the surrender value; copies value and status | 1 | 3/3 | 12/0/0 |
| `termlife_issue` | Issue: ANB issue age, the premium rate (RATE by 3 criteria, 192 rows), annual and modal premiums (3 MathIFs); 2 checks; 6 copies | 4 | 40/40 | 20/1/0 |
| `termlife_premium_payment` | PremiumPayment: whole modes paid, the new paid-to date; 1 check | 3 | 12/12 | 12/0/0 |
| `termlife_grace_check` | GraceCheck: days past due, in grace (IIF); spawns Lapse | 2 | 6/6 | 9/0/0 |

**103 of 103** expectations reproduce the interpreter's values, across two
policy lives per plan and more (a deposit refused for being zero, a
withdrawal refused for exceeding the account value, a withdrawal after the
surrender charge period, a withdrawal that spawns the full surrender, a
payment below one modal premium, a lapse spawned 44 days past due, an issue
refused for age and face amount, an insured just 18 at the nearest birthday).

## The E5 verdict

The plan asked whether relational arithmetic is readable on a real
transaction or LE needs functional expressions (E5). On these transactions:
**not needed.** A MathVariable is already a named intermediate value, so one
rule per variable, reading the variables it names, is a one-to-one reading of
the configuration and cites it line by line; expressions stay short because
OIPA's own style breaks them into variables. Two frictions remain, both
small: **rounding** (`ROUND="2"` reads `round(E * 100) / 100`, where a
`rounded to 2 decimals` form would read better — a candidate for a built-in,
not a construct), and **reassignment** by MathIF, which the `otherwise`
cascade states exactly, with a rule for each earlier value a MathVariable
reads between two assignments.

## Not done

The LPS twin of a plan (the policy's life: activities as events, policy
fields as fluents, CopyToPolicyFields as causal laws) — the interpreter
already plays the lives, which gives it its oracle; it waits for a pilot
whose Assignments say which transactions change the policy. A real
configuration export: the phase's risk, stated in the plan, is unchanged —
the first customer is the first corpus.

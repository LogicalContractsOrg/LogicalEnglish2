# Oracle Insurance Policy Administration and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

Oracle Insurance Policy Administration (OIPA) is the system of Oracle for the
administration of life, annuity and health policies. You configure an OIPA product.
You do not program it. The configuration tool of OIPA is the Rules Palette. In the
Rules Palette, a *transaction* (a deposit, a withdrawal, an issue) is an XML document.
XML (eXtensible Markup Language) is a plain-text format for structured documents.
The Math section of the document calculates values from the fields of the activity,
from the policy and from the plan. The business rules attached to the document check
the activity. They also spawn (start) other transactions, and copy values back to the
policy.

The editor translates the XML of one transaction into Logical English (LE). The
translation has one rule for each MathVariable, and each rule cites its MathVariable.
Rate lookups become decision tables. The translation also has a view that calculates
the price of an activity. A view is a screen that shows the program to its users. The
translation goes in one direction only, from OIPA into Logical English. There is no
exporter back to OIPA. To use the translator, select **File ▸ Open…** or **File ▸
Import from Another System…**. The translator needs the Logical English Translators.
Some installations have them, for example the hosted service.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [What to upload](#what-to-upload)
  - [Importing](#importing)
  - [The note and the ledger](#the-note-and-the-ledger)
  - [Running the translation](#running-the-translation)
  - [Show the Original](#show-the-original)
  - [Examples to try](#examples-to-try)
- [How OIPA maps to Logical English](#how-oipa-maps-to-logical-english)
  - [The activity, the policy it finds and the plan](#the-activity-the-policy-it-finds-and-the-plan)
  - [Reassignment and MathIF](#reassignment-and-mathif)
  - [What is not translated](#what-is-not-translated)
  - [Rates](#rates)
  - [Checks, spawns and copies](#checks-spawns-and-copies)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| OIPA → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | The Rules Palette XML of one transaction (`.xml`, root element `<Transaction>` with a `Math` or `Fields` section). Or a `.zip` of a plan folder or of the folder of a transaction | A program with a template for each field and MathVariable, and a rule for each MathVariable that cites it. Decision tables for rates. Checks, spawns and copies from the attached rules. Queries for the logged values, and a view. A migration ledger. The XML and the CSV files of the plan in `sources/` | For the example twins, an independent interpreter of OIPA transaction math, which runs the policy lives of each plan. An uploaded transaction has no tests |

## How to use it

### What to upload

Upload one of these items:

- **A zip of a plan folder**, with the same layout as the configuration of the Rules
  Palette. There is one folder for each transaction. Each folder contains its
  `Transaction.xml` and its attached rules (`ValidateExpressions.xml`,
  `SpawnActivities.xml`, `CopyToPolicyFields.xml`). The `Rates.csv` (AsRate) and
  `PlanFields.csv` (AsPlanField) of the plan are next to those folders. The
  translator reads all of these files. It translates the first transaction in
  alphabetical sequence. The note gives the names of the other transactions. The
  name of the program comes from the plan and the transaction
  (`annuity_withdrawal.le`). To translate a different transaction, make a zip of the
  folder of that transaction together with the two CSV files of the plan.
- **A zip of the folder of one transaction** (with or without the CSV files of the
  plan next to it). The name of the folder is the name of the transaction.
- **The XML of one transaction**, as the Rules Palette shows it: a `<Transaction>`
  element with its `<Fields>` and its `<Math>`/`<MathVariables>`. The name of the
  file becomes the name of the transaction. Thus `Withdrawal.xml` gives the
  transaction `Withdrawal`. A file with the name `Transaction.xml` gets its name from
  the `NAME` attribute of its root element, if there is one. If there is no such
  attribute, its name is `Transaction`. When you upload one file, no other files come
  with it. Thus the translator does not read the attached rules of the transaction
  and the CSV files of the plan. The note tells you this (refer to
  [the note](#the-note-and-the-ledger)).

An attached rule file alone (`ValidateExpressions.xml`, and the others) has a root
element that is not `<Transaction>`. Thus the translator does not identify the file
as OIPA material.

Three translators read `.xml` files: Oracle Intelligent Advisor, LegalRuleML and
OIPA. Each of the three examines the file. The OIPA translator accepts the file when
its root element is `<Transaction>`.

### Importing

Do these steps:

1. Select **File ▸ Import from Another System…** (or **File ▸ Open…**).
2. Select the zip or the `.xml` file of the transaction.

The server translates the file and opens the program in a new tab. For a zipped plan
folder, the name of the program is `<plan>_<transaction>.le` (`annuity_withdrawal.le`).
For other uploads, the name is `oipa_<transaction>.le` (`oipa_withdrawal.le`).

A note below the menu bar gives the name of the translator (*Oracle Insurance Policy
Administration transaction (Rules Palette XML)*) and the counts.

The server keeps the upload and its translation for one day. To keep the program,
select **File ▸ Save As…**.

### The note and the ledger

This is the note for one `Withdrawal.xml`:

```
oipa_withdrawal: 16 MathVariables and rules encoded, 0 approximated, no residue; 0 writer errors.
Read: Transaction.xml. Not found beside the uploaded XML file (an upload of one file has nothing beside it), so not read: ValidateExpressions.xml, SpawnActivities.xml, CopyToPolicyFields.xml, Rates.csv, PlanFields.csv — hence no checks; no spawns; no copies to policy fields; each rate table is empty, so a RATE gives its DEFAULT or no value; each plan field is its MathVariable's DEFAULT or has no value. To have them read, zip the plan's folder (Withdrawal/ with its attached rules, and Rates.csv and PlanFields.csv) and open the zip.
The XML is kept in sources/Withdrawal/ (the plan's CSV files in sources/), where the rules' citations point; File > Show the Original lists it.
```

For a zipped plan folder, the second line of the note gives a list of the files that
the translator read:
`Read: Transaction.xml, ValidateExpressions.xml, SpawnActivities.xml, CopyToPolicyFields.xml, PlanFields.csv, Rates.csv.`
It also tells which kinds of attached rules the transaction does not have. A last line
gives the names of the other transactions of the plan.

The translator writes a ledger, `<name>.ledger.md`, next to the program. The ledger
has one row for each MathVariable, for each validation, spawn and copy, and for each
`MathLoop`. Each row gives the mapping that the translator used, for example:

- `FIELD -> the activity field GrossAmount, a fact of the case`;
- `RATE -> a decision table loaded from the plan's rates, DEFAULT as the last line`.

A row with the mark *approximated* tells how the meaning changed. A row with the mark
*residue* is an item that the translator could not read. That item stays in the
program as a `% RESIDUE` block (refer to
[what is not translated](#what-is-not-translated)).

### Running the translation

An uploaded transaction has no scenarios. A scenario is the set of facts of one case.
Until you add a scenario, the verifier gives warnings. The warnings tell you that the
fields of the activity and of the policy (for example `the_gross_amount_of_is/2`) are
not defined. These warnings are expected, because such fields are the facts of a
case. Write a scenario that gives the fields of the activity, its effective date and
the policy that it finds, as the example twins do:

```le
scenario steady_saver_w1 is:
    the gross amount of w1 is 10000.
    the effective date of w1 is 2022-06-01.
    the account value of the policy before w1 is 168836.850000000005821.
    the issue date of the policy before w1 is 2020-03-15.
```

Then run a query. The translator writes one query for each MathVariable with the mark
`LOG="Yes"`, for example:
`query net_amount is: the net amount of which activity is which amount.`
If the transaction has attached rules, the translator also writes the queries `checks`
and `spawns`. It also writes one `policy_after_…` query for each copied field. The
explanation of an answer follows the math. The net amount comes from the gross amount
and the surrender charge. The surrender charge comes from the policy year. The
explanation continues in this way down to the fields.

The view (`the view withdrawal is: …`) is a test activity. The inputs are the fields
of the activity and the policy that the activity finds. The result is the first logged
value. The view shows a list of the checks. Each MathVariable gives one citation. Open
the view from the editor or from the executive view (refer to
[views](../guide/executive-view.md#views)).

In the example twins, each scenario has `expects answers` lines. **Misc ▸ Run the
Program's Tests…** shows that the program gives the same values.

### Show the Original

**File ▸ Show the Original…** shows a list of the files in `sources/` next to the
program, as the example twins keep them. The XML of the transaction and the attached
rules that the translator read are in `sources/<Transaction>/`. The `Rates.csv` and
`PlanFields.csv` of the plan are in `sources/`. The provenance of each rule
(`with provenance "Withdrawal/Transaction.xml" at MathVariable NetAmountMV`) cites the
MathVariable that the rule states. The program tells where that file is:
`the text of "Withdrawal/Transaction.xml" is at "sources/Withdrawal/Transaction.xml"`.
Thus **View Original Text** on a citation opens the file at that MathVariable.

### Examples to try

The examples include six translated transactions, open to all users. To open them,
select **File ▸ Open example from server…**. The six come from two plans: a deferred
annuity and a level term life policy:

- `migration/oipa/annuity_deposit`: premium tax, a bonus that depends on the size (an
  IIF), the new account value; two checks;
- `migration/oipa/annuity_withdrawal`: policy year, free amount, a surrender charge
  rate for each policy year (a RATE), a MathIF, the net amount; two checks; spawns
  FullSurrender; copies the account value;
- `migration/oipa/annuity_full_surrender`: the surrender value of the spawned
  transaction; copies the value and the status;
- `migration/oipa/termlife_issue`: issue age at the nearest birthday, a premium rate
  for each age, gender and tobacco value (192 rows), annual and modal premiums; two
  checks; six copies;
- `migration/oipa/termlife_premium_payment`: whole modes paid and the new paid-to
  date; one check;
- `migration/oipa/termlife_grace_check`: days past due, in grace; spawns Lapse.

There is no public OIPA configuration. Thus we wrote the two plans for this purpose.
We followed the forms in the public OIPA XML Configuration Guide of Oracle. The two
plans are not plans of Oracle. Each of the six, as each translated program, is given
"as is", without warranty of any kind. It is not insurance or financial advice. Its
first comment tells this in full. Their scenarios are the activities of some policy
lives, for example:

- a deposit that the program refuses because it is zero;
- a withdrawal that spawns the full surrender;
- a lapse that the program spawns 44 days past due;
- an issue that the program refuses because of the age and the face amount;
- and more.

A separate program calculated the expected values. That program calculates the math
of OIPA, and it shares no code with the translator. The six twins give all 103 of
those expected values.

## How OIPA maps to Logical English

| OIPA | Logical English |
|---|---|
| Activity field, `FIELD` `Activity:GrossAmount` | A fact of the case: `the gross amount of *an activity* is *an amount*.` |
| The transaction | `an activity is a withdrawal if the effective date of the activity is a date.` |
| Policy field, `POLICYFIELD` `AccountValue` | A fact of the case, the policy as the activity finds it: `the account value of the policy before *an activity* is *an amount*.` |
| Plan field, `PLANFIELD` | A fact of the program, with a citation: `the minimum balance of the plan is 2000, as stated in "PlanFields.csv" at MinimumBalance.` |
| `EXPRESSION` MathVariable | A rule. The MathVariables that it reads are its conditions: `rule policy_year with provenance "Withdrawal/Transaction.xml" at MathVariable PolicyYearMV:` / `the policy year of an activity is a number N if the duration of the activity is a number M and N = M + 1.` |
| `ROUND="2"` | `N = round((M - K) * 100) / 100` |
| `INTEGER` result of a division | `truncate(…)` |
| `VALUE` set one time | The constant, written in its position |
| `IIF`, and a `MathIF` that assigns a variable again | An `otherwise` cascade, with the latest assignment first |
| A variable that a MathVariable reads between two of its assignments | The value that it had at that point, as a separate rule: `the first value of the charge of *an activity*` |
| `SQL` and other MathVariable types that the translator does not read, `MathLoop` | A `% RESIDUE` block with the XML, and a ledger row *residue* |
| `RATE` | A decision table that the program loads from a CSV next to the program, `with unique match`. Its `DEFAULT` is the last line of the cascade |
| `DurationOf` | `the age on *a date* of someone born on *a date*` (lib/temporal) |
| `ANBAgeOf` (age at the nearest birthday) | The age six calendar months later (approximated) |
| `DaysDiffOf`, `MonthsAdd` | `*a date* is *a number* days after *a date*`, `… months after …` (lib/temporal) |
| `TruncateNumber`, `MinOf`, `MaxOf`, `AbsOf` | `truncate`, `the minimum/maximum of`, `abs` |
| `ValidateExpressions` `Expression` | `*an activity* fails the check *a code*`, with the message as the comment of the rule |
| `SpawnActivities` `Spawn` | `*an activity* spawns *a transaction*`, only for an activity that fails no check |
| `CopyToPolicyFields` `Field` | `the account value of the policy after *an activity* is *a value*`, only for an activity that fails no check |
| `LOG="Yes"` | A query for that value. The first one is the result of the view |

### The activity, the policy it finds and the plan

The program is the *timeless* reading of one transaction. You give an activity, and
the policy as the activity finds it. The program then tells what the math calculates.
The fields of the activity and the fields of the policy are the facts of a scenario.
The fields of the plan are facts of the program. Each plan field gets the value of
the plan from `PlanFields.csv`, if the plan folder has that file. If not, it gets the
`DEFAULT` of the MathVariable, with a citation of that `DEFAULT`:

```le
the free withdrawal percent of the plan is 10, as stated in "Withdrawal/Transaction.xml" at MathVariable FreePercentMV DEFAULT.
```

A program contains one transaction. Thus the program tells one time what its
activities are. Some rules read nothing from the activity (the fallback of a
cascade, a copy of a constant). These rules test that one sentence:

```le
% An activity of this program is a withdrawal: the Withdrawal transaction it processes.
an activity is a withdrawal if
    the effective date of the activity is a date.
```

### Reassignment and MathIF

OIPA calculates the Math section from top to bottom. The last assignment to a
variable is the value that stays. When a `MathIF` assigns a variable again, the
translator writes that variable as one `otherwise` cascade, with the latest
assignment first. In the Withdrawal transaction, the surrender charge is
`ChargeableAmountMV * SurrenderChargeRateMV`. Then it is 0 under
`<MathIF IF="PolicyYearMV > 7">`:

```le
rule surrender_charge with provenance "Withdrawal/Transaction.xml" at MathVariable SurrenderChargeMV:
the surrender charge of an activity is an amount N if
    the policy year of the activity is a number M
    and M > 7
    and N = 0
    otherwise the chargeable amount of the activity is an amount K
    and the surrender charge rate of the activity is a number P
    and N = round(K * P * 100) / 100.
```

An `IIF` is the same. It gives its first value under its condition. If not, it gives
its second value.

Sometimes a MathVariable reads a variable *between* two assignments of that variable.
The MathVariable then gets the value that the variable had at that point, as OIPA
calculates it. The translator writes the earlier value as a separate rule. That rule
contains the cascade of the assignments until that point:

```le
rule charge_first_value with provenance "Payout/Transaction.xml" at MathVariable ChargeMV:
the first value of the charge of an activity is an amount N if
    the activity is a payout
    and N = 100.

rule first_net with provenance "Payout/Transaction.xml" at MathVariable FirstNetMV:
the first net of an activity is an amount N if
    the gross amount of the activity is an amount M
    and the first value of the charge of the activity is an amount K
    and N = M - K.
```

The ledger row of the variable that has more than one assignment tells which of its
earlier values are rules. The condition of a `MathIF` reads the values that the Math
section set before the `MathIF`.

### What is not translated

If the translator cannot read a MathVariable, the MathVariable becomes a residue
block. The block contains these items:

- the XML of the variable (all the assignments of the variable);
- the reason why the translator did not translate the variable;
- the template that the missing rule must conclude.

The translator translates the rules that read such a variable. But these rules have no
answer until somebody translates the block. The ledger row for the variable says
*residue*:

```le
% RESIDUE r1 BEGIN: Payout/Transaction.xml MathVariable BalanceMV
% TODO: translate the fragment below by hand, or with the Contract Assistant (residue mode); it was not translated automatically
%   source: Payout/Transaction.xml
% Not translated: a MathVariable of TYPE SQL, which the translator does not read.
% Conclude: the balance of *an activity* is *an amount*.
%   OIPA XML:
%   | <MathVariable VARIABLENAME="BalanceMV" TYPE="SQL" DATATYPE="DECIMAL">SELECT Balance FROM AsPolicy</MathVariable>
% RESIDUE r1 END
```

These items become residue in this way:

- the MathVariable types other than FIELD, POLICYFIELD, PLANFIELD, VALUE,
  EXPRESSION, FUNCTION, IIF and RATE (`SQL`, `MULTIFIELD`, `OBJECT`, `COLLECTION`,
  and others);
- a `FIELD` MathVariable that is set inside a `MathIF`;
- each function other than DurationOf, ANBAgeOf, DaysDiffOf, MonthsAdd,
  TruncateNumber, MinOf, MaxOf and AbsOf;
- a reference to a variable that the transaction does not set, or did not set yet.

A `MathLoop` becomes one residue block that contains the XML of the loop. That block
must conclude the MathVariables that the loop sets. The ledger then has a row for the
loop and one row for each of those variables. If a check, a spawn or a copy reads an
item that the translator cannot translate, the translator does not include it. The
ledger tells this.

### Rates

A `RATE` MathVariable looks up a value in the rate table of the plan (AsRate in
OIPA). The criteria must agree exactly. The translator writes the rates of that
description into a CSV file next to the program. It also writes a decision table that
reads the file. The criteria stay as codes (`02`, `N`):

```le
the table term_premium is loaded from term_premium.csv, with unique match:
    issue age | gender | tobacco | rate
```

The last alternative of the rule that reads the table is the `DEFAULT`
(`otherwise the activity is an issue and N = 0`).

### Checks, spawns and copies

A validation becomes a rule that concludes `fails the check`. The message of the
validation is a comment above the rule. In the message, the translator replaces each
`$$$…MV$$$` placeholder with the name of its value. The translator changes an
`ErrorOnFalse` expression into its negation:

```le
% A withdrawal of [the gross amount] exceeds the account value of [the account value].
rule w002 with provenance "Withdrawal/ValidateExpressions.xml" at Expression W002:
an activity fails the check "W002" if
    the gross amount of the activity is an amount N
    and the account value of the policy before the activity is an amount M
    and N > M.
```

OIPA refuses an activity that fails a check. Thus the spawns and the copies have the
condition
`it is not the case that the activity fails the check a code`.
For a refused activity, the program still answers the values that the math
calculates.

## Traps

- **An `.xml` upload has no attached rules, rates or plan fields.** The editor
  receives only one file. Thus the translator does not read
  `ValidateExpressions.xml`, `SpawnActivities.xml`, `CopyToPolicyFields.xml`,
  `Rates.csv` and `PlanFields.csv`. The note gives a list of them. This has three
  results:
  - The program has no checks, no spawns and no copies.
  - Each rate table is an empty CSV file, with its heading row and nothing more.
    Thus a `RATE` always gives its `DEFAULT`. If it has no `DEFAULT`, it gives no
    answer.
  - Each plan field uses the `DEFAULT` of its MathVariable, or it has no value.

  Upload a zip of the plan folder instead.
- **One transaction for each upload.** For a zipped plan folder, the translator
  translates its first transaction. The note gives the names of the other
  transactions.
- **No scenarios, no tests.** An upload does not contain policy lives. Thus nothing
  checks the program against OIPA. Test the program with activities whose values you
  know from a test environment. Write them as scenarios with `expects answers` lines.
- **The effective date is part of each case.** The fallbacks of the cascades and the
  copies test `the activity is a withdrawal`. This sentence is true when the activity
  has an effective date. A scenario that does not state an effective date gets no
  default values.
- **Residue has no answers.** `SQL`, the other MathVariable types that the translator
  does not read, and `MathLoop`s become residue blocks (refer to
  [what is not translated](#what-is-not-translated)). All the items that read them,
  down to the logged values, have no answer. They get answers when somebody
  translates the blocks manually, or with the residue mode of the Contract
  Assistant.
- **Not in the translation:** assignments to funds, valuation, suspense, reversals
  and the lifecycle of the activity. A copy tells what the policy field becomes after
  the activity. The copy does not change the policy for the next activity. A spawn
  does not run the transaction that it spawns. Each scenario states the policy that
  the activity finds.
- **ANBAgeOf is approximated.** The program writes the age at the nearest birthday
  as the age six calendar months later. The two values can be different by one day
  at the half-year. The ledger marks the MathVariable *approximated*.
- **Numbers are not decimal.** OIPA calculates in decimal. The program calculates in
  floating point, the approximate fractions that a computer uses. It rounds where
  OIPA rounds (`ROUND`). Between two rounding points, those approximate fractions can
  show in a value, for example `168836.850000000005821` in the Withdrawal scenarios.
  Compare amounts after rounding.
- **Rounding looks like arithmetic.** `ROUND="2"` is `round(E * 100) / 100`. This is
  correct, but it is easy to read incorrectly.
- **Codes are values.** Text fields and criteria (gender `02`, tobacco `N`, billing
  mode `12`) are of type *a value*. They must agree exactly with the rate CSV. Write
  them in scenarios as the example twins do
  (`the insured gender of the policy before i1 is "02".`).
- **The words come from the names of OIPA.** Templates come from the names of the
  MathVariables (`NetAmountMV` → `the net amount of *an activity*`). Thus a name such
  as `SqlMV` becomes `the sql of *an activity*`. If the words are important to the
  readers of the program, change the names of the templates in the program.

## See also

- In this documentation:
  - [Other systems: importing and exporting](index.md), including
    [opening another system's file](index.md#opening-another-systems-file),
    [what could not be translated](index.md#what-could-not-be-translated),
    [Show the Original](index.md#show-the-original) and
    [the migration twins](index.md#the-migration-twins-among-the-examples)
  - [Decision tables](../reference/language.md#173-decision-tables),
    [`otherwise` cascades](../reference/language.md#172-otherwise-cascades),
    [rule labels and provenance](../reference/language.md#155-rule-labels-and-provenance),
    [provenance trailers](../reference/language.md#171-provenance-trailers-and-judged-templates),
    [the `temporal` library](../reference/language.md#142-shipped-libraries-lib),
    [arithmetic](../reference/language.md#7-arithmetic-and-comparisons),
    [testing and expectations](../reference/language.md#12-testing-and-expectations)
  - [LE Views](../tutorials/views.md) and
    [views in the executive view](../guide/executive-view.md#views)
- The documentation of Oracle about OIPA configuration:
  - [OIPA XML Configuration Guide](https://docs.oracle.com/cd/F25688_01/xml_guide/Content/introduction/index.htm)
  - [MathVariable Element](https://docs.oracle.com/cd/E59346_01/xml_guide/content/math_elements/mathvariable_element.htm)
    (XML Configuration Guide, release 10.1.2.0)
  - [Math Pane](https://docs.oracle.com/cd/E40981_01/rules_palette/Content/Transactions/Math_Pane.htm)
    (Rules Palette 10.0)

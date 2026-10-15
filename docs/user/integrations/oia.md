# Oracle Intelligent Advisor and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-15)*

Oracle Intelligent Advisor (OIA, and before that Oracle Policy Automation) is
Oracle's product for rules about who is eligible for something and what they
are entitled to. An author writes those rules in Word and Excel documents.
Oracle's Policy Modeling tool then turns the documents into a rulebase, the
machine-readable form of the rules, and a server uses the rulebase to interview
people and decide their cases.

The editor translates an OIA project into Logical English. The rules become
rules, in the words of the Word documents. The rule tables become decision
tables. The project's Excel test cases become scenarios. An interview becomes a
view, a screen that shows the program to someone who is not reading its
sentences. The translation goes one way only, from OIA into Logical English:
nothing writes an OIA project back out. Start the translation with **File ▸
Open…** or **File ▸ Import from Another System…**. The translator is part of
the *Logical English Translators*, which installations such as the hosted
service have, for the accounts that hold that licence.

The same licence brings the **OIA adapter**: the server answers the calls that
applications make to Oracle Intelligent Advisor — its decision services, Batch
Assess and SOAP Assess — in Oracle's own formats, from the translated program.
An application written for OIA then needs a new address and new credentials,
not new code (see [The OIA adapter](#the-oia-adapter)).

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [What to upload](#what-to-upload)
  - [Importing](#importing)
  - [The note and the ledger](#the-note-and-the-ledger)
  - [Running the translation](#running-the-translation)
  - [Show the Original](#show-the-original)
  - [Examples to try](#examples-to-try)
- [How OIA maps to Logical English](#how-oia-maps-to-logical-english)
  - [Roles of the global entity](#roles-of-the-global-entity)
  - [Rule tables](#rule-tables)
  - [Entities](#entities)
  - [Tests, or the analysis of the rules](#tests-or-the-analysis-of-the-rules)
- [The OIA adapter](#the-oia-adapter)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| OIA → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | a Word rule document (`.docx`); a `.ruletxt` file; a project exported from the Hub as JSON (a decision service or a flow); a compiled rule document (`<doc>.docx.xgen`); a deployed `rulebase.xml`, with its `rulebase.stxt`; a `.zip` of a Policy Modeling project folder or of a deployed rulebase | a program with templates, rules citing the Word document and paragraph, decision tables, scenarios, queries and an interview view; a migration ledger; the documents' paragraphs in `sources/` | the project's Excel test cases (whose results Policy Modeling records in `testResults.xml`); for a project with no test files, an evaluator of the OIA rules with OIA's own semantics |

## How to use it

### What to upload

The translator reads the rules as their authors wrote them, and the forms
Policy Modeling compiles them into. Upload one of these:

- **A Word rule document** (`.docx`), as it sits in the project's `Rules`
  folder. The translator reads its paragraphs and their styles (`OPM -
  conclusion`, `OPM - level 1`, …) and its rule tables, as Policy Modeling
  does; lines in the `Comment` styles are left out, as Policy Modeling leaves
  them out. Zip the project folder instead to bring the data model
  (`projectDataModel.xml`, which says what type each attribute has and which
  entity it belongs to) and the test files with it.
- **Rule text** (`.ruletxt`): the text form of Word rule documents that some
  teams keep under version control, one file per document (zip several).
- **A Hub project** exported as JSON: a *decision service* or a *flow* written
  in Intelligent Advisor Hub. Its contract gives each field's name and type.
- **One compiled rule document.** Policy Modeling turns each Word or Excel rule
  document into a file `bin/<Document>.docx.xgen`. Upload that file. The
  `.xgen` file carries the sentences as their author wrote them, Oracle's
  reading of each sentence (which words are the subject, and so on), the rules
  with their levels, and the paragraphs of the document.
- **A deployed rulebase.** Upload `rulebase.xml`, the rulebase as published to
  the server that answers cases. If you also have
  `rulebase.stxt`, put the two in one zip: the `.stxt` file holds the sentence
  forms the author wrote for each attribute, namely the negative form and the
  question the interview asks. The editor takes an `.xml` file for a rulebase
  when the file's outermost element is `rulebase`, whatever the file is called.
- **A whole project.** Zip the Policy Modeling project folder. The folder holds
  the `.xprj` file, the `Rules` folder with the Word documents, the `bin`
  folder with its `.xgen` files when the project was built,
  `projectDataModel.xml`, the Excel test files and `testResults.xml`. The zip
  may hold the folder itself or the folder's contents. A built project is read
  from its `.xgen` files, which Policy Modeling checked; a project that was
  never built is read from its Word documents.

The two ways of reading agree: for the four public projects that ship both
their Word documents and Policy Modeling's `.xgen` files, the rules read from
Word are the rules read from Oracle's compilation, 120 of 120.

The server reads the Excel test files only when it has `python3` with the
`openpyxl` package installed. Without that package the server skips the test
files, and the note says how many it skipped.

### Importing

1. Choose **File ▸ Import from Another System…** (or **File ▸ Open…**) and
   pick the file.
2. The server recognises the material as OIA's, translates it, and opens the
   new program in a new tab. The program's name comes from the project — from
   its `.xprj` file, its folder, or the file you uploaded — so that
   `Synthetic Rules.docx.xgen` opens as `synthetic_rules.le`.
3. A note under the menu bar says that the Oracle Intelligent Advisor
   translator was used, and gives the translator's counts, which the next
   section explains. Close the note with its `×`.

The server keeps what you uploaded, and the translation of it, for one day.
Save the program with **File ▸ Save As…** if you want to keep it. What
happens when you open any other system's file is described in
[Opening another system's file](index.md#opening-another-systems-file).

### The note and the ledger

The note reads, for instance:

```
ledger: 8 encoded, 1 approximated, 0 residue (TODO in the program)
10 scenario(s) generated from the rules' own analysis (no test files)
the scenarios run: 20 pass, 0 fail, 0 error
approximated: OIA's unknown and uncertain states are read with LE's closed world (see the ledger)
```

- The **ledger**, the record of how each piece of the project was translated,
  is written beside the program as `<name>.ledger.md` (and as `<name>.ledger.json`).
  The ledger has one row for each piece of the project: each attribute, role,
  entity, rule and test file. Each row says whether that piece was *encoded*
  (translated with its meaning unchanged), *approximated* (translated, with a
  note on how the meaning changed) or left as *residue* (not translated). The
  ledger also lists every answer the project expected, with what actually
  happened, so a failure shows both what was expected and what came instead.
- The note may say three further things: that `rulebase.stxt` was not uploaded,
  in which case the sentences come from the rulebase's own text and have no
  author-written negative forms or questions; that the Excel test files were
  not read; or that a rule document could not be read.

### Running the translation

The translation is an ordinary Logical English program. Pick a scenario and a
query and run the query, as you would for any program. Each step of an
explanation names the Word document and the paragraph the rule came from, and
the § badge beside the step opens that paragraph.

- **Misc ▸ Run the Program's Tests…** runs every answer the scenarios expect
  and lists them all, the failures first.
- The **interview** view (`the view interview is: …`) asks for the facts of
  the case one at a time, and asks only for those the answer still depends on.
  The view then gives the main conclusion, the reasons for it, and what would
  have to change for the conclusion to change. Open the view from the editor or
  from the executive view; see [Views](../tutorials/views.md).

### Show the Original

**File ▸ Show the Original…** lists the files in the program's `sources/`
folder. When you uploaded an `.xgen` file or a whole project, that folder holds
the text of each rule document, one paragraph to a line, and each rule's
`confer "…"` citation quotes from that text. When you uploaded a rulebase,
which carries no Word text, the folder holds the files you uploaded.

### Examples to try

Fifteen translated OIA projects sit among the lpsPlus examples. Those
examples are visible only on installations that have them, and only to users
with access to them. Open one with **File ▸ Open example from server…**:

- `lpsPlus/migration/oia/warranty_claims`: three rules, the smallest;
- `lpsPlus/migration/oia/mom_paternity_leave`: Singapore's Government Paid
  Paternity Leave, with mixed `and`/`or` levels and date arithmetic;
- `lpsPlus/migration/oia/gst_at_settlement`: five Word documents of
  Australian GST withholding, with 55 Excel test cases;
- `lpsPlus/migration/oia/vibect`: a deployed rulebase with a 383-row rule
  table and 97 Excel test cases;
- `lpsPlus/migration/oia/dctad`: a deployed rulebase with entities and five
  rule tables;
- `lpsPlus/migration/oia/loan_advisor`: Oracle's *Loan Advisor* demonstration,
  with assets, liabilities, income sources and a schedule of 361 monthly
  payments the rules infer one from another;
- `lpsPlus/migration/oia/do_i_need_to_file`, `taxpayer_information` and
  `student_benefits`: Oracle's own Hub samples (two decision services and a
  flow);
- `lpsPlus/migration/oia/laa_feedback_form` and `check_answers`: two
  Ministry of Justice rulebases that build email and web page text;
- `lpsPlus/migration/oia/simple_benefits`, `insurance_fraud_score`,
  `aged_care_approval` and `social_services_screening`: four of Oracle's
  documented example projects, rebuilt from their documentation, with
  entities, `ForAll`, `Exists`, sums and dates (Simple Benefits also answers
  the two cases Oracle's documentation publishes, as Oracle published them).

Each comes with its ledger and its `sources/` folder; together they
reproduce 953 of the 953 answers their tests expect. Several of the public
projects state no licence, so their translations are not published anywhere
else.

## How OIA maps to Logical English

| OIA | Logical English |
|---|---|
| a boolean attribute of the global entity | a template; `; opposite:` when a rule concludes it false; `; scenario element` when no rule concludes it: `*a customer* is a gold member; scenario element.` |
| a value attribute | a template with a place for the value: `the fee is *a fee*.`; `the value of … is …` when the text begins with a word Logical English reserves (`the value of the contract price is a price P`) |
| a role of the global entity ("the claim", "the Father") | a typed place of the templates that speak about it, and a named constant standing for the case's one individual: `the constants are:` with `the Father is "the Father".` |
| a rule `… if` with conditions | a rule, labelled and cited: `rule warranty_claims_intro_rules_r0 with provenance "Warranty Claims (Intro) Rules.docx", confer "The claim is covered by warranty if":` |
| Word levels mixing `and` and `or` | a numbered outline, as the Word document shows it: `5. either:` / `5.1. …; or` / `5.2. …` |
| the automatic *otherwise false* | negation as failure: what no rule concludes is false |
| `not` | `it is not the case that …` (approximated) |
| a value conclusion `the fee = the price * 0.07` | relational arithmetic, decimals as fractions: `the price is a price P and F = P * 7 / 100` |
| `otherwise <value>` | an `otherwise` alternative: `otherwise F is equal to 0.` |
| a rule table whose cells are all attribute = constant | a decision table `with first match`; the `Else` row becomes an `any` row |
| a rule table of other shapes (expressions in cells) | an `otherwise` cascade, rows in order |
| a citation written before a line (`[s 6]`) | a comment on the rule: `% cites: s 6; s 9; …` |
| `add-months`, `add-years`, `add-days` | the shipped `temporal` library, copied beside the program: `a later date L is -3 calendar months after the second date` |
| `current-date` | case data: `the current date is *a date*; scenario element.` |
| `known(x)`, `unknown(x)` | for a value, `x is a value` and its negation; for a boolean, `x` or its opposite form, and the negation of that (approximated) |
| `uncertain(x)` | `it is uncertain whether x`, a fact a test states (approximated) |
| an `Error("…")` or `Warning` event | `the rulebase raises the error "The purchaser cannot be under 18 years of age" if …` |
| an entity the case lists | an instance template after its relationship: `*a child* is one of the claimant's children`; an instance is named by its identifying value, else by its identifier in the case |
| an entity attribute | a template with a place for the instance: `the known value of *an asset* is *a value*`, `*a child* is a teenager` |
| `InstanceCount`, `InstanceSum`, `InstanceCountIf`, `InstanceMinimum`, `InstanceMaximum` | an aggregate: `N is the count of each P such that P is one of the payments and …` |
| `Exists`, `ForAll` | a condition on some instance; `for all cases in which … it is the case that …` |
| text built with `+`, `Text()`, `Contains`, `EndsWith`, `StartsWith` | the shipped `text` library (`the joining of [...] is ...`) and Logical English's own `starts with` |
| `xy` (a power), `Minimum`, `Maximum`, `Round(x, n)`, `DayDifference`, `YearDifference` | the shipped `maths`, `rounding` and `temporal` libraries, Logical English's `the minimum of … and … is …` |
| an entity with an identifying attribute, whose instances a table infers | an instance is its identifying value: `*a code* identifies the error.` |
| a table that infers entity instances | a rule whose rows are alternatives (each matching row adds an instance), and a query listing them |
| instances inferred one from another (a schedule of payments) | a walk along the chain from the first instance, each step remembered: `the payments from *a payment* are *a list*` |
| a test case from Excel, a logged Assess request and its response, or a JSON case | a scenario with the inputs as facts and the expected values as `expects answers` |
| an Excel test case | a scenario `as stated in "Witholding_Amount.xlsx" at test case 1:` with the inputs as facts and the expected values as `expects answers` |
| the interview | a view: the attributes no rule concludes, asked one at a time; the top conclusion as the result |
| a rule the translator cannot map | a `% RESIDUE` block holding the rule's XML |

### Roles of the global entity

OIA's rules about a single case speak of the people and things in that case by
name: "the Father", "the Child", "the claim". Where Oracle's reading of the
sentences makes one phrase the subject of two or more attributes, the
translator turns that phrase into a **role**. Every template that speaks about
the role gets a place for it, with the role as the place's type. A named
constant (the language reference §2.2) then says which individual of the case
the role stands for, so that the rules go on reading as they were written:

```le
the constants are:
    the Father is "the Father".
```

Two kinds of sentence keep their own words instead: a sentence that some rule
concludes in its negative form, and a sentence that would read like another
role's sentence once the role became a place. The translator finds roles only
in `.xgen` documents, because the `.stxt` file of a rulebase does not say how
Oracle read each sentence.

### Rule tables

Each decision table is named after what the table concludes, and its columns
after the attributes the table tests and the attribute it concludes:

```le
the table notification_type_table is, with first match, with provenance "rulebase.xml":
    row  | branch id | country match flag | business event type    | notification type
    r1   | 20        | "Y"                | "CHARGE_CLFEE"         | "Alert"
```

A rule that reads the table says `table notification_type_table for … gives
…`. A table whose cells hold conditions or sums, rather than plain values,
becomes an `otherwise` cascade instead, keeping the order of the table's rows.
See
[Decision tables](../reference/language.md#173-decision-tables) and
[`otherwise` cascades](../reference/language.md#172-otherwise-cascades).

### Entities

An entity is a kind of thing the rules speak about, such as a child, an asset
or a payment, and each individual of that kind is an *instance*. Each
attribute of an entity becomes a template with a place for the instance, and
each rule about an entity's attribute holds for each instance:
`a child is a teenager if the child is one of the claimant's children and the
age of the child is a number N and N >= 13 and N <= 19`. OIA's functions over
the instances become Logical English's aggregates (`the count of each`, `the
sum of each`) and its universal condition (`for all cases in which`). A table
that works out which instances there are, which OIA calls a relationship, adds
one instance for each row that matches. Instances OIA infers one from the
previous one — the payments of a loan — are found by walking from the first,
each step remembered, so that a schedule of 361 payments takes seconds.

### Tests, or the analysis of the rules

A project that has Excel test files gets one scenario for each test case. The
inputs of the test case become facts of the scenario; an input that is `false`
becomes a fact only when the sentence has an opposite form. The values the test
expects become `expects answers` lines. Where a test expects false, `(unknown)`
or `(uncertain)`, the scenario expects no answer at all.

A project with no test files gets its scenarios from **the analysis of its
rules** instead. For each goal, the translator writes a scenario for each way
the rules can reach that goal, and a scenario for each near miss, in which one
input is changed so that a condition fails. What each of those scenarios should
answer is worked out by a second program, which applies the OIA rules the way
OIA itself would, rather than by the translated Logical English program. The
two are therefore checked against each other. That second program computes in
decimals, as OIA does, and writes each expected number the way Logical English
prints numbers, so a whole number carries no decimal point (`the fee is 70`).
A scenario written this way says `as stated in the analysis of the rules`.

## The OIA adapter

The server that runs the editor can also answer **Oracle Intelligent
Advisor's own interfaces**, from the translated programs, when the
installation has the Logical English Translators:

| An application that called OIA through | Calls this server at |
|---|---|
| OIA's sign-in (an API client's identifier and secret) | `POST /opa-hub/api/12.2.23/auth` |
| a decision service (one case, several, its OpenAPI description) | `POST /determinations-server/v2/<name>`, `.../batch`, `GET .../swagger.json` |
| Batch Assess | `POST /determinations-server/batch/12.2.26/policy-models/<name>/assessor` |
| SOAP Assess | `POST /determinations-server/assess/soap/generic/12.2/<name>` |

`/oia-adapter` lists the translated programs that can answer, and their
names. Each case's values become facts of the program, each outcome a
question of it, and an outcome asked with a *decision report* gets the
program's explanation. A boolean outcome the case leaves undecided is answered
*false*, where OIA could say *unknown* (see the first trap below). The API
clients belong to accounts that hold the licence; your administrator makes
them.

## Traps

- **Unknown is false.** OIA works with three values, not two: an input nobody
  answered is *unknown*, and anything that depends on it is unknown in turn.
  Logical English reads a case as a closed world, where an unanswered input is
  simply false, and a conclusion that OIA would call unknown is not drawn at
  all. The ledger marks every rule whose meaning that difference can change
  (`not`, not-equals, `known`/`unknown`, `uncertain`, the current date) as
  *approximated*. On the published GST project the difference costs one expected
  answer in 207. That one test leaves the "between associates" question
  unanswered; OIA's rule table stops there, while the translation carries on to
  the `Else` row. In the example the expected answer is kept as a comment in
  its scenario, waiting rather than running. In an import of your own, such a
  test simply fails.
- **Uncertain is a fact.** `uncertain(x)` becomes a template, `it is uncertain
  whether x`, which a scenario has to state as a fact. No rule ever concludes
  it.
- **Little reasoning about time.** The current date is one of the facts of the
  case. Change points, `ValueAt`, `WhenLast` and sums over intervals are not
  translated at all, and a rule that uses any of them is left as residue.
- **Not read:** `.tsc` test scripts, Excel sheets listing the instances of an
  entity, interview screens (`.xint` files: the view is built from the rules
  instead), `If()` used as a value, `Substring` and the other functions that
  turn text into values, inputs whose value is a relationship between two
  entities, and entities nested more than one level under the case: a rule
  that uses any of them is left as residue.
- **The words change a little.** The translator keeps each sentence as written,
  but makes it safe for Logical English to read: punctuation is dropped, `%`
  becomes `percent`, `/` becomes `or`, and any word Logical English keeps for
  itself is replaced, so `if` becomes `in case`, and `unless`, `either`,
  `otherwise`, `only if`, `any of` and `all of` are all replaced in the same
  way. Look out for sentences that now begin `the value of …`: the translator
  adds those words where a sentence began with a word that opens a section,
  such as `the contract`.
- **Typos and oddities come through faithfully.** The translator corrects
  nothing in the rulebase. "the product is faculty", "have been engaged", Word
  headings that Policy Modeling turned into conclusions with no conditions
  (which stay as facts), and a condition that repeats what the levels beneath
  it already define all arrive exactly as OIA had them.
- **A document that cannot be read** does not stop the rest of the import. Such
  a document becomes a TODO comment holding the first part of its XML, the
  marked-up text Policy Modeling wrote, and the document's rules are missing
  from the program. The note says how many documents could not be read.
- **Without `rulebase.stxt`** a rulebase carries no negative forms and no
  interview questions as the author wrote them.
- **Only one project per upload.** The editor reads a zip as a single project.
  The project's `out` folder and any `__MACOSX` entries are ignored.

## See also

- In this documentation:
  - [Other systems: importing and exporting](index.md), including
    [what could not be translated](index.md#what-could-not-be-translated) and
    [Show the Original](index.md#show-the-original)
  - [Decision tables](../reference/language.md#173-decision-tables),
    [`otherwise` cascades](../reference/language.md#172-otherwise-cascades),
    [provenance trailers](../reference/language.md#171-provenance-trailers-and-judged-templates),
    [rule labels and provenance](../reference/language.md#155-rule-labels-and-provenance),
    [the `temporal`, `text`, `maths` and `lists` libraries](../reference/language.md#142-shipped-libraries-lib),
    [testing and expectations](../reference/language.md#12-testing-and-expectations)
  - [LE Views](../tutorials/views.md), for the interview
  - [The assistants](../guide/assistants.md#the-contract-assistant): the Contract
    Assistant's *Migration residue* mode translates residue blocks
- Oracle Intelligent Advisor's own documentation:
  [Oracle Intelligent Advisor](https://docs.oracle.com/en/cloud/saas/intelligent-advisor/index.html)

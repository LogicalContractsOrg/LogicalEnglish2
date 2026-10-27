# Oracle Intelligent Advisor and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-15)*

Oracle Intelligent Advisor (OIA) is the product of Oracle for rules about who is
eligible for something and what they have a right to. The earlier name of OIA was
Oracle Policy Automation. An author writes those rules in Word and Excel documents.
Then the Policy Modeling tool of Oracle changes the documents into a rulebase. A
rulebase is the form of the rules that a computer can read. A server uses the
rulebase to interview people and decide their cases.

The editor translates an OIA project into Logical English. The rules become rules,
in the words of the Word documents. The rule tables become decision tables. The
Excel test cases of the project become scenarios. A scenario is the set of facts of
one case. An interview becomes a view. A view is a screen that shows the program to a
person who does not read its sentences. The translation goes in one direction only,
from OIA into Logical English. Nothing writes an OIA project back. To start the
translation, select **File ▸ Open…** or **File ▸ Import from Another System…**. The
translator is part of the *Logical English Translators*. Some installations, for
example the hosted service, have the translators for the accounts that have that
licence.

The same licence gives the **OIA adapter**. With the adapter, the server answers the
calls that applications make to Oracle Intelligent Advisor: its decision services,
Batch Assess and SOAP Assess. The server answers in the formats of Oracle, from the
translated program. Thus an application that was written for OIA needs a new address
and new credentials, but no new code. Refer to [The OIA adapter](#the-oia-adapter).

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
| OIA → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | A Word rule document (`.docx`). A `.ruletxt` file. A project that you exported from the Hub as JSON (a decision service or a flow). A compiled rule document (`<doc>.docx.xgen`). A deployed `rulebase.xml`, with its `rulebase.stxt`. A `.zip` of a Policy Modeling project folder or of a deployed rulebase | A program with templates, rules that cite the Word document and paragraph, decision tables, scenarios, queries and an interview view. A migration ledger. The paragraphs of the documents in `sources/` | The Excel test cases of the project (Policy Modeling records their results in `testResults.xml`). For a project without test files, an evaluator of the OIA rules that uses the semantics (the meaning rules) of OIA |

## How to use it

### What to upload

The translator reads the rules in the form that their authors wrote. It also reads
the forms into which Policy Modeling compiles them. Upload one of these items:

- **A Word rule document** (`.docx`), as it is in the `Rules` folder of the project.
  The translator reads the paragraphs and their styles (`OPM - conclusion`,
  `OPM - level 1`, …) and the rule tables of the document, as Policy Modeling does.
  The translator does not read the lines in the `Comment` styles, as Policy Modeling
  does not read them. Make a zip of the project folder instead to include the data
  model and the test files. The data model is `projectDataModel.xml`. It gives the
  type of each attribute and the entity of each attribute.
- **Rule text** (`.ruletxt`): the text form of Word rule documents. Some teams keep
  this form under version control. There is one file for each document. Make a zip
  of more than one file.
- **A Hub project** that you exported as JSON: a *decision service* or a *flow* that
  somebody wrote in Intelligent Advisor Hub. Its contract gives the name and the type
  of each field.
- **One compiled rule document.** Policy Modeling changes each Word or Excel rule
  document into a file `bin/<Document>.docx.xgen`. Upload that file. The `.xgen` file
  contains these items:
  - the sentences, as their author wrote them;
  - the reading of Oracle of each sentence (which words are the subject, and other
    parts);
  - the rules, with their levels;
  - the paragraphs of the document.
- **A deployed rulebase.** Upload `rulebase.xml`. This is the rulebase that somebody
  published to the server that answers cases. If you also have `rulebase.stxt`, put
  the two files in one zip. The `.stxt` file contains the sentence forms that the
  author wrote for each attribute: the negative form, and the question that the
  interview asks. The editor accepts an `.xml` file as a rulebase when the outermost
  element of the file is `rulebase`. The name of the file is not important.
- **A full project.** Make a zip of the Policy Modeling project folder. The folder
  contains these items:
  - the `.xprj` file;
  - the `Rules` folder with the Word documents;
  - the `bin` folder with its `.xgen` files, if somebody built the project;
  - `projectDataModel.xml`;
  - the Excel test files and `testResults.xml`.

  The zip can contain the folder, or the contents of the folder. The translator reads
  a built project from its `.xgen` files, which Policy Modeling checked. It reads a
  project that nobody built from its Word documents.

The two methods of reading give the same result. Four public projects have both their
Word documents and the `.xgen` files of Policy Modeling. For these projects, the rules
from Word are the same as the rules from the compilation of Oracle: 120 of 120.

The server reads the Excel test files only when it has `python3` with the `openpyxl`
package installed. Without that package, the server does not read the test files. The
note then tells how many test files the server did not read.

### Importing

Do these steps:

1. Select **File ▸ Import from Another System…** (or **File ▸ Open…**).
2. Select the file.

The server identifies the material as OIA material and translates it. Then it opens
the new program in a new tab. The name of the program comes from the project: from
its `.xprj` file, its folder, or the file that you uploaded. For example,
`Synthetic Rules.docx.xgen` opens as `synthetic_rules.le`.

A note below the menu bar tells you that the editor used the Oracle Intelligent
Advisor translator. The note also gives the counts of the translator. The next
section explains these counts. To close the note, click its `×`.

The server keeps your upload, and its translation, for one day. To keep the program,
select **File ▸ Save As…**. For what occurs when you open a file of a different
system, refer to
[Opening another system's file](index.md#opening-another-systems-file).

### The note and the ledger

This is an example of the note:

```
ledger: 8 encoded, 1 approximated, 0 residue (TODO in the program)
10 scenario(s) generated from the rules' own analysis (no test files)
the scenarios run: 20 pass, 0 fail, 0 error
approximated: OIA's unknown and uncertain states are read with LE's closed world (see the ledger)
```

- The **ledger** is the record of how the translator translated each part of the
  project. The editor writes the ledger next to the program as `<name>.ledger.md`
  (and as `<name>.ledger.json`). The ledger has one row for each part of the project:
  each attribute, role, entity, rule and test file. Each row tells the result for
  that part:
  - *encoded*: translated, with no change to its meaning;
  - *approximated*: translated, with a note about how the meaning changed;
  - *residue*: not translated.

  The ledger also gives a list of all the answers that the project expected, with
  the actual results. Thus a failure shows the expected answer and the actual answer.
- The note can also tell you three more things:
  - You did not upload `rulebase.stxt`. In that case, the sentences come from the
    text of the rulebase. They do not have the negative forms or the questions that
    the author wrote.
  - The translator did not read the Excel test files.
  - The translator could not read a rule document.

### Running the translation

The translation is a usual Logical English program. Select a scenario and a query,
and run the query, as for all programs. Each step of an explanation gives the name of
the Word document and the paragraph that the rule came from. The § badge next to the
step opens that paragraph.

- **Misc ▸ Run the Program's Tests…** runs all the answers that the scenarios expect.
  It shows all of them in a list, with the failures first.
- The **interview** view (`the view interview is: …`) asks for the facts of the case
  one at a time. It asks only for the facts that the answer still depends on. Then
  the view gives the main conclusion and the reasons for it. It also tells what must
  change to change the conclusion. Open the view from the editor or from the
  executive view. Refer to [Views](../tutorials/views.md).

### Show the Original

**File ▸ Show the Original…** shows a list of the files in the `sources/` folder of
the program. If you uploaded an `.xgen` file or a full project, that folder contains
the text of each rule document, with one paragraph on each line. The `confer "…"`
citation of each rule quotes from that text. A rulebase does not contain the Word
text. Thus, if you uploaded a rulebase, the folder contains the files that you
uploaded.

### Examples to try

The lpsPlus examples include fifteen translated OIA projects. You can see those
examples only on installations that have them, and only if you have access to them.
To open an example, select **File ▸ Open example from server…**:

- `lpsPlus/migration/oia/warranty_claims`: three rules. This is the smallest example;
- `lpsPlus/migration/oia/mom_paternity_leave`: the Government Paid Paternity Leave
  of Singapore, with mixed `and`/`or` levels and date arithmetic;
- `lpsPlus/migration/oia/gst_at_settlement`: five Word documents about the
  withholding of Australian GST (Goods and Services Tax), with 55 Excel test cases;
- `lpsPlus/migration/oia/vibect`: a deployed rulebase with a rule table of 383 rows
  and 97 Excel test cases;
- `lpsPlus/migration/oia/dctad`: a deployed rulebase with entities and five rule
  tables;
- `lpsPlus/migration/oia/loan_advisor`: the *Loan Advisor* demonstration of Oracle,
  with assets, liabilities and sources of income. It also has a schedule of 361
  monthly payments. The rules infer each payment from the payment before it;
- `lpsPlus/migration/oia/do_i_need_to_file`, `taxpayer_information` and
  `student_benefits`: Hub samples from Oracle (two decision services and a flow);
- `lpsPlus/migration/oia/laa_feedback_form` and `check_answers`: two rulebases of
  the Ministry of Justice that make the text of emails and web pages;
- `lpsPlus/migration/oia/simple_benefits`, `insurance_fraud_score`,
  `aged_care_approval` and `social_services_screening`: four example projects from
  the documentation of Oracle. We made them again from their documentation, with
  entities, `ForAll`, `Exists`, sums and dates. Simple Benefits also answers the two
  cases that the documentation of Oracle publishes, with the same results that Oracle
  published.

Each example has its ledger and its `sources/` folder. Together, the examples give 953
of the 953 answers that their tests expect. Some of the public projects do not state a
licence. Thus we do not publish their translations in other locations.

## How OIA maps to Logical English

| OIA | Logical English |
|---|---|
| A boolean (true or false) attribute of the global entity | A template. Add `; opposite:` when a rule concludes that the attribute is false. Add `; scenario element` when no rule concludes the attribute: `*a customer* is a gold member; scenario element.` |
| A value attribute | A template with a place for the value: `the fee is *a fee*.` Use `the value of … is …` when the text starts with a word that Logical English reserves (`the value of the contract price is a price P`) |
| A role of the global entity ("the claim", "the Father") | A typed place of the templates that refer to the role. Also a named constant for the one individual of the case: `the constants are:` with `the Father is "the Father".` |
| A rule `… if` with conditions | A rule with a label and a citation: `rule warranty_claims_intro_rules_r0 with provenance "Warranty Claims (Intro) Rules.docx", confer "The claim is covered by warranty if":` |
| Word levels that mix `and` and `or` | A numbered outline, as the Word document shows it: `5. either:` / `5.1. …; or` / `5.2. …` |
| The automatic *otherwise false* | Negation as failure: a sentence that no rule concludes is false |
| `not` | `it is not the case that …` (approximated) |
| A value conclusion `the fee = the price * 0.07` | Relational arithmetic, with decimals as fractions: `the price is a price P and F = P * 7 / 100` |
| `otherwise <value>` | An `otherwise` alternative: `otherwise F is equal to 0.` |
| A rule table in which all the cells are attribute = constant | A decision table `with first match`. The `Else` row becomes an `any` row |
| A rule table of other shapes (expressions in cells) | An `otherwise` cascade, with the rows in sequence |
| A citation before a line (`[s 6]`) | A comment on the rule: `% cites: s 6; s 9; …` |
| `add-months`, `add-years`, `add-days` | The `temporal` library that the system supplies. The translator copies it next to the program: `a later date L is -3 calendar months after the second date` |
| `current-date` | Data of the case: `the current date is *a date*; scenario element.` |
| `known(x)`, `unknown(x)` | For a value, `x is a value` and its negation. For a boolean, `x` or its opposite form, and the negation of that (approximated) |
| `uncertain(x)` | `it is uncertain whether x`, a fact that a test states (approximated) |
| An `Error("…")` or `Warning` event | `the rulebase raises the error "The purchaser cannot be under 18 years of age" if …` |
| An entity that the case lists | An instance template after its relationship: `*a child* is one of the claimant's children`. The name of an instance is its identifying value. If there is no identifying value, the name is its identifier in the case |
| An entity attribute | A template with a place for the instance: `the known value of *an asset* is *a value*`, `*a child* is a teenager` |
| `InstanceCount`, `InstanceSum`, `InstanceCountIf`, `InstanceMinimum`, `InstanceMaximum` | An aggregate: `N is the count of each P such that P is one of the payments and …` |
| `Exists`, `ForAll` | A condition on one instance; `for all cases in which … it is the case that …` |
| Text made with `+`, `Text()`, `Contains`, `EndsWith`, `StartsWith` | The `text` library that the system supplies (`the joining of [...] is ...`), and the `starts with` of Logical English |
| `xy` (a power), `Minimum`, `Maximum`, `Round(x, n)`, `DayDifference`, `YearDifference` | The `maths`, `rounding` and `temporal` libraries that the system supplies. Also `the minimum of … and … is …` of Logical English |
| An entity with an identifying attribute, whose instances a table infers | An instance is its identifying value: `*a code* identifies the error.` |
| A table that infers entity instances | A rule whose rows are alternatives (each row that agrees adds an instance), and a query that lists the instances |
| Instances that OIA infers one from another (a schedule of payments) | A walk along the chain from the first instance. The system remembers each step: `the payments from *a payment* are *a list*` |
| A test case from Excel, a logged Assess request and its response, or a JSON case | A scenario with the inputs as facts and the expected values as `expects answers` |
| An Excel test case | A scenario `as stated in "Witholding_Amount.xlsx" at test case 1:` with the inputs as facts and the expected values as `expects answers` |
| The interview | A view: it asks for the attributes that no rule concludes, one at a time. The result is the top conclusion |
| A rule that the translator cannot map | A `% RESIDUE` block that contains the XML of the rule |

### Roles of the global entity

The OIA rules about one case refer by name to the people and things in that case:
"the Father", "the Child", "the claim". Oracle reads each sentence and finds its
subject. Sometimes one phrase is the subject of two or more attributes. Then the
translator changes that phrase into a **role**. Each template that refers to the role
gets a place for it, and the type of the place is the role. A named constant (the
language reference §2.3) then tells which individual of the case the role refers to.
Thus the rules continue to read as their author wrote them:

```le
the constants are:
    the Father is "the Father".
```

Two kinds of sentence keep their own words:

- a sentence that a rule concludes in its negative form;
- a sentence that becomes similar to a sentence of a different role when the role
  becomes a place.

The translator finds roles only in `.xgen` documents. The reason is that the `.stxt`
file of a rulebase does not tell how Oracle read each sentence.

### Rule tables

The name of each decision table comes from the thing that the table concludes. The
names of its columns come from the attributes that the table tests and the attribute
that it concludes:

```le
the table notification_type_table is, with first match, with provenance "rulebase.xml":
    row  | branch id | country match flag | business event type    | notification type
    r1   | 20        | "Y"                | "CHARGE_CLFEE"         | "Alert"
```

A rule that reads the table says `table notification_type_table for … gives …`. Some
tables have conditions or sums in their cells, not only values. Such a table becomes
an `otherwise` cascade, with the rows in the same sequence as in the table. Refer to
[Decision tables](../reference/language.md#173-decision-tables) and
[`otherwise` cascades](../reference/language.md#172-otherwise-cascades).

### Entities

An entity is a kind of thing that the rules refer to, for example a child, an asset
or a payment. Each individual of that kind is an *instance*. Each attribute of an
entity becomes a template with a place for the instance. Each rule about an attribute
of an entity applies to each instance:
`a child is a teenager if the child is one of the claimant's children and the age of the child is a number N and N >= 13 and N <= 19`.

The functions of OIA over the instances become the aggregates of Logical English
(`the count of each`, `the sum of each`). They can also become its universal
condition (`for all cases in which`). In OIA, a relationship is a table that
calculates which instances there are. Such a table adds one instance for each row
that agrees with the case. Sometimes OIA infers each instance from the instance
before it, for example the payments of a loan. The translation finds such instances
with a walk from the first instance, and it remembers each step. Thus a schedule of
361 payments takes some seconds.

### Tests, or the analysis of the rules

A project with Excel test files gets one scenario for each test case. The inputs of
the test case become facts of the scenario. An input that is `false` becomes a fact
only when the sentence has an opposite form. The values that the test expects become
`expects answers` lines. Where a test expects false, `(unknown)` or `(uncertain)`,
the scenario expects no answer.

A project without test files gets its scenarios from **the analysis of its rules**.
For each goal, the translator writes these scenarios:

- one scenario for each path by which the rules can reach that goal;
- one scenario for each near miss. In a near miss, one input changes, and thus one
  condition fails.

A second program calculates the answer that each of those scenarios must give. The
translated Logical English program does not calculate it. The second program applies
the OIA rules in the same way as OIA. Thus the two programs check each other. The
second program calculates in decimals, as OIA does. It writes each expected number in
the same way as Logical English shows numbers. Thus a whole number has no decimal
point (`the fee is 70`). A scenario of this kind says
`as stated in the analysis of the rules`.

## The OIA adapter

The server that runs the editor can also answer **the interfaces of Oracle Intelligent
Advisor**, from the translated programs. For this, the installation must have the
Logical English Translators:

| An application that called OIA through | Calls this server at |
|---|---|
| The sign-in of OIA (the identifier and the secret of an API client) | `POST /opa-hub/api/12.2.23/auth` |
| A decision service (one case, more than one case, its OpenAPI description) | `POST /determinations-server/v2/<name>`, `.../batch`, `GET .../swagger.json` |
| Batch Assess | `POST /determinations-server/batch/12.2.26/policy-models/<name>/assessor` |
| SOAP Assess | `POST /determinations-server/assess/soap/generic/12.2/<name>` |

An API (application programming interface) client is a program that calls these
addresses. `/oia-adapter` shows a list of the translated programs that can answer,
with their names. The values of each case become facts of the program. Each outcome
becomes a question to the program. An outcome that asks for a *decision report* gets
the explanation of the program. If the case does not decide a boolean outcome, the
answer is *false*. In the same case, OIA can say *unknown* (refer to the first trap
below). The API clients belong to accounts that have the licence. Your administrator
makes them.

The OIA adapter and the DMN adapter share one part, the adapter kit. The kit reads
the mapping file next to each twin, writes the case as sentences of the twin, and asks
the outcomes. Refer to [Adapters](adapters.md).

## Traps

- **Unknown is false.** OIA works with three values, not two. An input that nobody
  answered is *unknown*. Each result that depends on that input is also unknown.
  Logical English reads a case as a closed world. In a closed world, an input that
  nobody answered is false. Also, Logical English does not give a conclusion that OIA
  calls unknown. The ledger marks as *approximated* each rule whose meaning that
  difference can change (`not`, not-equals, `known`/`unknown`, `uncertain`, the
  current date). On the published GST project, the difference changes one expected
  answer in 207. That one test does not answer the "between associates" question. The
  rule table of OIA stops there, but the translation continues to the `Else` row. In
  the example, the expected answer stays as a comment in its scenario. It waits, and
  it does not run. In your own import, such a test fails.
- **Uncertain is a fact.** `uncertain(x)` becomes a template,
  `it is uncertain whether x`. A scenario must state it as a fact. No rule concludes
  it.
- **Little reasoning about time.** The current date is one of the facts of the case.
  The translator does not translate change points, `ValueAt`, `WhenLast` and sums
  over intervals. A rule that uses one of them stays as residue.
- **Not read:** the translator does not read these items:
  - `.tsc` test scripts;
  - Excel sheets that give a list of the instances of an entity;
  - interview screens (`.xint` files). The translator makes the view from the rules
    instead;
  - `If()` used as a value;
  - `Substring` and the other functions that change text into values;
  - inputs whose value is a relationship between two entities;
  - entities more than one level below the case.

  A rule that uses one of these items stays as residue.
- **The words change a little.** The translator keeps each sentence as its author
  wrote it. But it makes the sentence safe for Logical English to read:
  - it removes the punctuation;
  - `%` becomes `percent`, and `/` becomes `or`;
  - it replaces each word that Logical English keeps for its own use. Thus `if`
    becomes `in case`. It replaces `unless`, `either`, `otherwise`, `only if`,
    `any of` and `all of` in the same way.

  Look for sentences that now start with `the value of …`. The translator adds those
  words where a sentence started with a word that starts a section, for example
  `the contract`.
- **Typing errors and unusual items stay as they are.** The translator corrects
  nothing in the rulebase. These items all arrive exactly as OIA had them:
  - "the product is faculty" and "have been engaged";
  - Word headings that Policy Modeling changed into conclusions without conditions
    (these stay as facts);
  - a condition that repeats what the levels below it already define.
- **A document that the translator cannot read** does not stop the remaining import.
  Such a document becomes a TODO comment that contains the first part of its XML. The
  XML is the marked-up text that Policy Modeling wrote. The rules of the document are
  not in the program. The note tells how many documents the translator could not
  read.
- **Without `rulebase.stxt`**, a rulebase does not contain the negative forms and the
  interview questions that the author wrote.
- **Only one project for each upload.** The editor reads a zip as one project. It
  ignores the `out` folder of the project and all `__MACOSX` entries.

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
  - [The assistants](../guide/assistants.md#the-contract-assistant): the *Migration
    residue* mode of the Contract Assistant translates residue blocks
- The documentation of Oracle Intelligent Advisor:
  [Oracle Intelligent Advisor](https://docs.oracle.com/en/cloud/saas/intelligent-advisor/index.html)

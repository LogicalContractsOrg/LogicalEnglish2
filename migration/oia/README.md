# Oracle Intelligent Advisor → LE (Phase 1c)

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

A deterministic translator from Oracle Intelligent Advisor (OIA, formerly
Oracle Policy Automation) projects to Logical English twins, following the
mapping of the design notes `roadmap.md` §5.1 on the shared LE2
infrastructure of Phase 0 (`le_writer.pl`, `le_migration.pl`,
`lib/temporal`). The twins are not published: the translator writes them
under `examples/migration/oia/` of the private place
(`le2_paths:private_root/1`, [`../README.md`](../README.md)).

Oracle is a registered trademark of Oracle and/or its affiliates. This
translator and its adapter are not Oracle products, and Oracle does not
endorse them. No Oracle code, WSDL or schema is copied here. The READMEs
of `sources/extra/` quote a few sentences of Oracle's documentation, each
marked and attributed, and Simple Benefits restates the rules of an example
that Oracle's documentation gives (its README says which pages).

| File | What it is |
|---|---|
| `oia_reader.pl` | `.xgen` (compiled Word rule documents) and `rulebase.xml` + `rulebase.stxt` → a neutral model `oia(Name, Attrs, Rules, Docs)`; `projectDataModel.xml` for the types |
| `oia_ir.pl` | the model + the Excel test files → a `le_migration` migration term: Migration IR, ledger, source tests |
| `oia_analysis.pl` | a project with no test files: its cases from its rules' own analysis (paths to each goal, near misses), expected outcomes by an evaluator of the OIA model |
| `oia_import.pl` | the adapter LE2's File ▸ Open calls (`le_import.pl` registry, row in `../le_importers.pl`): an `.xgen`, a `rulebase.xml`, or a zipped project → a program with its ledger and sources |
| `oia_tests.py` | Excel test file (`.xlsx`) → JSON (openpyxl); used by `oia_ir.pl` |
| `oia_migrate.pl` | the projects, and the driver that writes each twin |
| `test_oia.pl` | plunit tests (synthetic projects in `tests/`, VIBECT and MOM end to end) |
| `oia_text.pl` | the rules **as authors write them** → the same model: Word rule documents (`.docx`, through `oia_docx.py`), `.ruletxt` (the Ministry of Justice's text form of Word rules) and Intelligent Advisor Hub projects exported as JSON (decision services, flows); `projectDataModel.xml` or the Hub contracts for entities, relationships, types and public names |
| `oia_docx.py` | Word `.docx` → JSON lines (paragraph styles, levels, rule tables), standard library only |
| `oia_assess.pl` | Oracle's Assess messages: a SOAP Assess request/response pair → a test case (a customer's logged traffic replays as regression tests); Assess responses written back (`oia_adapter.pl`) |
| `sources/fetch.sh` | clones the public projects into `sources/.cache/` (gitignored) |
| `sources/extra/` | what this repository adds: synthetic test cases for the projects that publish none (each with the `make_tests.py` that computes its expected values, independently of the twin), and four projects written for this repository (their README says from what); `make_docx.py` writes their Word rule documents. Oracle's two published Assess exchanges of Simple Benefits are not copied here: they are read from the private place when they are there |

## Sources

None of the three repositories of the first corpus states a licence, so
nothing of them is copied here: `sources/fetch.sh` clones them into
`sources/.cache/`, which git ignores, and their twins — **derived works** —
are written to the private place and are not published. Every twin and
ledger says so in its header (`licence` in the ledger metadata).

Oracle's own samples, `oracle-samples/ia-tools-samples`, are different:
they are under the Universal Permissive License 1.0 (copyright Oracle and/or
its affiliates). The samples themselves are not copied here either. The test
cases that this repository wrote for three of them
(`sources/extra/do_i_need_to_file/`, `student_benefits/`,
`taxpayer_information/`) name the samples' attributes and values, so the
samples' copyright notice and licence are beside them, unchanged:
`sources/extra/LICENSE-UPL-1.0.txt`.

| Repository | Projects used | Format |
|---|---|---|
| `github.com/NixonS24/Oracle-Policy-Modeling` (2019) | *Warranty Claims (Intro)*; *GST at Settlement* (5 Word documents, 5 Excel test files, `testResults.xml`) | Policy Modeling 12.2 project: `bin/*.xgen`, `projectDataModel.xml` |
| `github.com/yihsiang/opa_demo` (2017) | *MOM Paternity Leave* (Singapore Ministry of Manpower) | same |
| `github.com/Intelligent-Advisor/oia-dmn-tree` (2026) | *VIBECT* (4 Excel test files), *DCTAD* | compiled `rulebase.xml` + `rulebase.stxt` + `projectDataModel.xml` (an OIA → DMN tool's example inputs) |
| `github.com/ministryofjustice/opa_tools` (MIT) | none — a `.docx` → Python converter, read for the Word conventions only | — |

No public project ships `.tsc` test scripts; the Excel test files are the
form all of them use, so that is what is read (`.tsc` is a gap, below).

### The second corpus (15 October 2026)

Ten more projects, chosen for the features that experienced OIA authors
use: Oracle's own samples, a government's production rulebases,
entities, inferred instances, string building, the Hub's newer formats. The
public web holds few OIA projects (Policy Modeling projects are their owners'
property, and the example projects that Oracle's documentation describes
come with the product, under its licence); this is all that could be found.
Four more projects were written for this repository: Simple Benefits, from
the rules that Oracle's documentation gives for its example of that name,
and three that take the name and the theme of an example that Oracle's
documentation describes in a sentence or two. The rules of those three are
this repository's, not Oracle's.

| Project | Source | Format | Tests |
|---|---|---|---|
| `loan_advisor` | Oracle's *Loan Advisor* demonstration rulebase, as deployed in `github.com/NealOKelly/govuk-opa-maf-template` | compiled `rulebase.xml` + `.stxt`: 4 entities, 360 inferred payment instances (a chain), instance sums and counts, power, modulo, text | 7 synthetic cases (`make_tests.py`, a Python model of the rulebase) |
| `do_i_need_to_file` | Oracle sample `oracle-samples/ia-tools-samples` (UPL), `llm/llm_ds_chat` | Hub **decision service** JSON (contract + rule text, a table whose cells are conditions) | 12 cases from the IRS's 2022 filing thresholds |
| `taxpayer_information` | same | Hub decision service (a lookup table, dates) | 3 cases |
| `student_benefits` | Oracle sample, `samples/flows/student-benefits` | Hub **flow** project's rule documents (any/all groups 4 deep, a table with a formula row, `= null`) | 11 cases from US Federal Student Aid criteria |
| `laa_feedback_form` | Ministry of Justice, `laa-ccms-opa-feedback-form-v23-ruletxt` (the Legal Aid Agency's production feedback form) | `.ruletxt` (Word rules as text): HTML built with `+`, `is currently known`, `it is certain whether`, switched-off rows and lines, `currentdatetime()`, `trunc` | 7 synthetic cases |
| `check_answers` | Ministry of Justice, `govuk-elements-for-oracle-policy-automation`, `CheckAnswers.zip` | **Word `.docx`** + data model (an entity; HTML with exact spaces; `Contains`, `StartsWith`, `EndsWith`) | 3 synthetic cases |
| `simple_benefits` | Oracle's *SimpleBenefits*, reconstructed from the Determinations Server documentation (one rule, the allowance amount, is an assumption: its README) | Word `.docx` written by `make_docx.py`; `Exists`, `InstanceCount` | **Oracle's two published Assess exchanges** (SOAP; kept in the private place, not here) + 5 cases |
| `insurance_fraud_score` | written for this repository after Oracle's description of its *Insurance Fraud Score* example; the rules are ours | Word; `InstanceSum`, `InstanceCountIf`, `Exists`, `AddMonths`, `DayDifference`, `Minimum`, Word rule tables | 6 synthetic cases |
| `aged_care_approval` | written for this repository after Oracle's description of its *Aged Care Approval* example; the rules are ours | Word; `YearDifference`, `DayDifference`, `AddMonths`, current date, an entity summed | 8 synthetic cases |
| `social_services_screening` | written for this repository after Oracle's description of its *Social Services Screening* example; the rules are ours | Word; `ForAll`, `Exists`, `InstanceCountIf`, `InstanceSum`, a table with a formula row | 6 synthetic cases |

Licences of the second corpus: `oracle-samples/ia-tools-samples` is under the
Universal Permissive License 1.0; `govuk-elements-for-oracle-policy-automation`
is under the MIT licence (Ministry of Justice); the other two repositories
state none. No file of any of them is copied here.

Every expected value of a synthetic case is computed by the `make_tests.py`
beside it — a Python model of the rules, written from the source, never the
twin — or taken from Oracle's published results.

**Word documents read directly, checked against Oracle's compilation.**
For the four public projects that ship both their Word documents and
Policy Modeling's compiled `.xgen` (Warranty Claims, MOM Paternity Leave,
GST at Settlement, Check Answers), `oia_text.pl` reads the Word documents
and the result is compared, rule by rule, with what `oia_reader.pl` reads
from Oracle's compilation: **120 of 120 rules identical** (the test
`word_equals_oracle_compilation` repeats the comparison for MOM Paternity
Leave). Getting there settled four of Policy
Modeling's conventions: a line without a connector takes the connective of
its group (`and` under a conclusion, `or` under `either`); a line with no
connector before an `either` block is a conjunct, not an inline conclusion;
a line break inside a paragraph adds nothing to a string literal; the
negative form of an attribute ("does not contain", "has not submitted") is
recognised against the data model.

## How to run

```sh
migration/oia/sources/fetch.sh                          # once, from the root of LE2
./myswipl.sh -q -g "consult('migration/oia/oia_migrate.pl')" -g "oia_migrate:main" -t halt
./myswipl.sh -q -g run_tests -t halt migration/oia/test_oia.pl
```

`main` rewrites every twin (about 10 s) and prints, per project, the writer's
issues, the ledger counts and the fidelity (source expectations reproduced).
`migrate(Name)` does one project; `migrate(Name, OutRoot, Report)` writes
elsewhere. Needs python3 with openpyxl for the Excel files. The tests take
about 10 s, 8 of them VIBECT's end-to-end translation.

## The formats, as found in the real files

**`.xgen`** (`bin/<Document>.docx.xgen`, one per Word/Excel rule document;
UTF-8 with a byte-order mark):

```
root(product-version)
  entities/entity(ref=global|<entity>)/attribute(name=b1|p1|..., type=boolean|currency|text|date|number|...)
      text(lang)/base            the sentence as authored ("the claim is covered by warranty")
      text(lang)/parse           Oracle's parse: s(ver(V), v(Verb, t(Aspect, Tense, Mood)), Subject, Object)
  relationships
  rules/rule(id, name, folder, source-offset=<paragraph>)/rule-xml/
      conclude(attr-id, entity-id, scope-id, source-offset, line-offset, tags)
          value/<expr>           true-value | an expression (a value attribute)
          condition/<expr>
          otherwise/<expr>       false-value (booleans: the automatic "otherwise false") | a value
      table-conclude(entity-id)  condition-col(header?, rows/<cell>*) ... conclusion-col(attr-id | relationship-id)/value|empty*
      event(action='Error("...")')/condition
  source(kind=MSWord)/p(para, s=<Word style>, t=<paragraph text>)/ref(k, v, r)
```

Attribute ids (`b1`, `p1`) are local to the document; the same sentence in
two documents is the same attribute, so the reader keys attributes by their
normalised text (lower case, no punctuation, no leading article, no
trailing "is true"), which is also how Excel test columns name them.
Expressions: `and`, `or`, `not`, `attribute(attr-id, tags)`,
`for(scope-ref, <expr>)` (a global attribute read from an entity's scope),
an inline `conclude` (a Word level that is itself a conclusion), `equals`
... `less-than-equals`, `multiply`/`divide`/`add`/`subtract`,
`add-months`/`add-days`/`add-years`, `min`/`max`, `known`/`unknown`/
`uncertain`, `negate`/`round`, `temporal-*`, and the constants
`string-value`, `number-value`, `date-value`, `true-value`, `false-value`,
`uncertain-value`, `current-date`. A condition's `tags` (`[s 6:x=1-4],y=12`)
carries the bracketed citation the author wrote before the line.

**`rulebase.xml`** (the compiled rulebase; no Word text):

```
rulebase(region, timezone)
  entity(text, name=global|<uuid>, singleton, identifying-attribute-name)/attribute(name, type)
  relationship(relationship-id, relationship-text, reverse-relationship-id, source, target)
  rules(module)/(conclude | table-conclude | event)*       same elements as rule-xml above
```

**`rulebase.stxt`** — the sentence forms per `attribute(attr-id, entity)`:
`basic` and `third-person/{text, positive, negative, question, uncertain,
unknown}`. The authored `negative` is used as the opposite form, the
`question` as the View's question.

**`projectDataModel.xml`** — `attribute(@type)/text/base`: the type of every
attribute, by its text (auto-typed attributes are typed by use).

**Excel test files** — a sheet `Test Cases` (other sheets: entity instances);
one row per case, one column per attribute, the role of each column given by
the cell's *named style* (`OPM - Input Heading`/`OPM - Input`,
`OPM - Expected ...`, `OPM - Actual ...`, `OPM - Test Result ...`); group
titles may sit above the heading row; values `(uncertain)`, `(unknown)`.

**`testResults.xml`** — Policy Modeling's record of its own last run:
`policy-model/testing-document(name, total, pass, fail, started)/test-case`.
Cited in the ledger (GST: 55 of 55 passed on 2018-11-10), so the Excel
expectations are known to be OIA's own behaviour.

## The mapping, as implemented

| OIA | LE twin | Ledger |
|---|---|---|
| a **role** of the global entity: a phrase `the <noun>` Oracle's parse gives as the subject of an attribute, spoken about by two or more (`the Father`, `the Child`, `the claim`, `the purchaser`) | a typed place of the templates that speak about it (`*a father* is an employee`, `the employment status of *a father* is *a status*` for "the Father's employment status") and a global the rules keep using as written: `the Father in the case is *a father*; defines global the Father.`, with the knowledge base naming the case's one individual, `the Father in the case is "the Father".` A sentence a rule concludes in its negative form, or one that would read like another role's once the role is a place, keeps its words | encoded |
| global boolean attribute (with the `.stxt` negative, or one derived from Oracle's parse) | template, `; opposite:` when a rule concludes it false or tests it known; `; scenario element` (undefined) when nothing concludes it | encoded |
| global value attribute | `<text> is *a <noun>*` (the head noun when apt: `the contract price is *a price*`); `the value of <text> is ...` when the text starts with an LE section word (`the contract ...`) or is a prefix of a boolean sentence | encoded |
| Word text | kept as the author wrote it, made LE-safe: `%` → `percent`, `/` → `or`, no punctuation, reserved words (`if` → `in case`, `unless`, `either`, `otherwise`, `only if`, `any of`, `all of`) replaced | encoded |
| conclusion `if` conditions, `otherwise false` | rule; the automatic *otherwise false* is negation as failure | encoded |
| negative conclusion (`false-value`) | rule concluding the opposite form | encoded |
| Word levels (`and`/`or` groups) | nested body (core LE, the twins as published); the reader asks the writer for a numbered outline `1. ... 2. either: 2.1 ...` when levels mix `and` and `or` (as the Word document shows them), which the writer honours only for a document with `extensions(true)` in its header, since the outline needs `le_extensions.pl` | encoded |
| inline conclusion (a level that concludes) | a rule of its own, labelled `<parent>_<functor>`, and its conclusion as the condition | encoded |
| `not` | `it is not the case that` | approximated (closed world) |
| value conclusion `the fee = the price * 0.07` | relational arithmetic: `the price is a price P and F = P * 7 / 100`; decimal constants as fractions (OIA's arithmetic is decimal) | encoded |
| `otherwise <value>` | `otherwise` alternative | encoded |
| rule table, all columns attribute = constant | LE decision table `with first match`, `Else` row → `any` row | encoded |
| rule table, other shapes (conditions in cells, expressions) | `otherwise` cascade, rows in order; an uncertain-valued row stops the cascade (`prolog fail`) | encoded |
| citation tags `[s 6]` | `% cites: s 6; ...` comment on the rule | encoded |
| document and paragraph of a conclusion | provenance `as stated in "Doc.docx"`, `confer "<paragraph>"` checked against `sources/<doc>.txt` (the document's paragraphs, beside the twin) | — |
| `known(x)` / `unknown(x)` | a value: `x is a value`; a boolean: `x or <opposite of x>` / its negation | approximated |
| `uncertain(x)` | a template `it is uncertain whether x`, stated by a test's `(uncertain)` input | approximated |
| `current-date`, `temporal-on-or-after` / `-before` / `-after`, `temporal-years-since` | `the current date is *a date*` (case data) and lib/temporal (`number of whole years from ... to ...`) | approximated (no change points) |
| `add-months`, `add-years` | lib/temporal `*a later date* is *a number* calendar months after *a date*`, included and copied beside the twin | encoded |
| `Error("...")` / `Warning` events | `the rulebase raises the error *a message*` rules | encoded |
| entity (not global) with identifying attribute | `*a code* identifies the error`: an instance is its identifying value | encoded |
| entity attribute | `the error description of *a code* is *a description*` | encoded |
| table concluding a relationship (inferred instances) | a rule whose rows are **alternatives** (each matching row adds an instance) — plus a query listing them | encoded |
| table of an entity | per instance: `the code identifies the error and table ... for the code gives the description` (decision table or cascade) | encoded |
| Excel test case | scenario `as stated in "File.xlsx" at test case N`; inputs as facts (`false` inputs only for sentences with an opposite form), expected values as `expects` answers (false, `(unknown)`, `(uncertain)` → no answer) | encoded |
| no test files | scenarios from the **rules' own analysis** (`oia_analysis.pl`): for each goal (a conclusion no boolean rule reads), each way the rules reach it (a set of inputs: the first matching row of a table, one `or` alternative, every `and` condition, the opposite of a negated one) and its near misses (one input changed to fail its condition); expected outcomes from an evaluator of the OIA model with OIA's semantics (exact decimal arithmetic, each number written as LE prints it: `70`, not `70.0`), never from the twin; cited `as stated in the analysis of the rules` | encoded |
| the interview | a View: the undefined attributes asked one at a time, the top conclusion as result (a project whose decisions are entity instances: the query listing them), the `.stxt` questions | — |
| anything else | `% RESIDUE` block with the rule's XML | residue |

**Three-valued logic.** OIA's *unknown* propagates; the twins read it with
LE's closed world: an unknown input is false, and a conclusion that would
be unknown is not derived. For every rule whose meaning this can change
(`not`, `not-equals`, `known`/`unknown`, `uncertain`, the current date) the
ledger says *approximated* and why. On the real tests this costs one
expectation out of 476 (below). The §5.1 alternative — `; assumable`
inputs reported as unknowns — was not used: it would make every unanswered
input an assumption in every case, where OIA's tests state their inputs
completely.

### The mapping of entities, functions and chains (October 2026)

| OIA | LE twin |
|---|---|
| an entity the case lists (a containment relationship from the case) | `*an asset* is one of the assets` (after the relationship's text: `*a child* is one of the claimant's children`); an instance is named by its identifying value, else by its `@id` |
| an entity attribute | `the known value of *an asset* is *a value*` ("the asset's known value"), `*a child* is a teenager`, `the customer's monthly income from *an income source* is *an amount*` |
| a rule concluding an entity attribute | a rule for each instance: `the known value of an asset is a value if the asset is one of the assets and ...` |
| `InstanceCount`, `InstanceSum`, `InstanceMinimum`/`Maximum`, `InstanceCountIf` | LE aggregates: `N is the count of each P such that a payment P is one of the payments and ...` |
| `Exists(rel, c)`, `ForAll(rel, c)` | a condition on some instance; `for all cases in which a household member is one of the household members it is the case that ...` |
| `For(rel, attr)`, `scope-for` | the related instance through the relationship's template (`the previous payment of the payment is a second payment`) |
| `conclude-instance` (inferred instances) | the relationship's rule and an instance rule; for a **chain** (a first instance from the case, each next from the previous, identity "index + k" — OIA's way of laying out a schedule) a forward walk instead: `the payments from *a payment* are *a list*` (memorable), its end the condition's opposite, and the reverse relationship by the inverse step |
| text `+`, `Text()`, `Contains`, `StartsWith`, `EndsWith`, `Length` | LE2's `lib/text`: `the joining of [..] is ..`, `the text of ..`, `.. contains ..`, LE's own `starts with` |
| `xy` (power), `Minimum`/`Maximum`, `Round(x, n)`, `Trunc`, `modulo` | `lib/maths` (`the power of .. to .. is ..`), LE's `the minimum of .. and .. is ..`, `round()`, `lib/rounding`, `truncate()`, `mod` |
| `DayDifference`, `MonthDifference`, `YearDifference`, `AddDays` | `lib/temporal` (`the number of days from .. to ..`), LE's `.. is .. days after ..` |
| a Hub table whose conclusion cells are conditions (`the person's gross income > $12,950`) | a cascade row concluding whether the condition holds |
| `X = null`, `is currently known`, `it is certain whether` | known / unknown tests (a conclusion with OIA's automatic "otherwise false" is always known) |
| consecutive value conclusions of one attribute | one `otherwise` cascade; each alternative reads the value and gives it to the result with `is equal to`, so that a question that fixes the result ("is the parent form Not known?") cannot pass an earlier alternative's guard |

## Results

| Project | Source | Attributes | Rules (tables) | Tests | Fidelity | Ledger E / A / R | Twin |
|---|---|---|---|---|---|---|---|
| warranty_claims | 1 Word doc (.xgen) | 8, 3 roles | 3 | 10 cases of the rules' analysis | **20 / 20** | 14 / 0 / 0 | 123 lines, View |
| mom_paternity_leave | 1 Word doc (.xgen) | 27, 2 roles | 12 (1), 2 inline | 28 cases of the rules' analysis (+ 2 hand cases in `test_oia.pl`) | **56 / 56** | 39 / 2 / 0 | 568 lines, View, lib/temporal |
| gst_at_settlement | 5 Word docs (.xgen) | 217, 7 roles | 105 (1) | 5 Excel files, 55 cases | **206 / 207** | 288 / 46 / 0 | 2463 lines, View, lib/temporal |
| vibect | rulebase.xml | 90, 1 entity | 59 (4) | 4 Excel files, 97 cases | **269 / 269** | 126 / 28 / 0 | 2905 lines, 2 decision tables, View |
| dctad | rulebase.xml | 12, 2 entities | 7 (5) | 14 cases of the rules' analysis | **112 / 112** | 19 / 2 / 0 | 614 lines, 5 decision tables, View |
| loan_advisor | rulebase.xml | 64, 4 entities | 38, a chain of 361 inferred payments | 7 synthetic cases | **56 / 56** | 99 / 8 / 0 | 683 lines, lib/text, maths, lists |
| do_i_need_to_file | Hub decision service | 14 | 5 (1) | 12 cases (IRS 2022) | **12 / 12** | 20 / 0 / 0 | 157 lines |
| taxpayer_information | Hub decision service | 3 | 1 (1) | 3 cases | **6 / 6** | 4 / 1 / 0 | 79 lines, 2 decision tables |
| student_benefits | Hub flow | 39 | 17 (1) | 11 cases (Federal Student Aid) | **22 / 22** | 54 / 3 / 0 | 382 lines |
| laa_feedback_form | 5 `.ruletxt` | 51 | 28 (6) | 7 synthetic cases | **66 / 66** | 67 / 13 / 0 | 495 lines, lib/text |
| check_answers | 1 Word doc (`.docx`) | 7, 1 entity | 3 (1) | 3 synthetic cases | **9 / 9** | 12 / 0 / 0 | 118 lines, lib/text |
| simple_benefits | 1 Word doc, reconstructed | 8, 1 entity | 4 | Oracle's 2 published Assess exchanges + 5 cases | **18 / 18** | 15 / 1 / 0 | 141 lines |
| insurance_fraud_score | 1 Word doc, reconstructed | 24, 1 entity | 16 (5) | 6 synthetic cases | **28 / 28** | 41 / 1 / 0 | 304 lines, lib/temporal |
| aged_care_approval | 1 Word doc, reconstructed | 22, 1 entity | 12 | 8 synthetic cases | **25 / 25** | 33 / 3 / 0 | 268 lines, lib/temporal |
| social_services_screening | 1 Word doc, reconstructed | 17, 1 entity | 11 (2) | 6 synthetic cases | **48 / 48** | 30 / 0 / 0 | 283 lines |

**All fifteen projects: 953 of 953 expectations** (the GST case 5 pending
expectation below is not counted). `main` rewrites all fifteen in about 40
seconds, Loan Advisor's tests taking most of it.

E / A / R = encoded / approximated / residue source elements (attributes,
entities, rules, test files). No residue is left in any project. Every
twin loads with 0 errors and runs in the `--with-extensions` example suite
(the two tested twins in 6–7 s each).

The one failing expectation is GST `Witholding_Amount.xlsx` case 5, whose
own note says it: *"will not fall through rule table to hit general case
because of uncertain state"*. The associates questions are unanswered, so in
OIA "the supply is between associates" is unknown and the withholding
table stops there (no value); in the closed world it is false, the table
falls through to its `Else` row and the twin answers 91000. It is the
measured cost of the approximation, and is kept as a *pending* expectation
(`known_divergence/2` in `oia_ir.pl`): written as a comment in its scenario
with the reason, and counted in the ledger, so the twin runs green while the
difference stays on record.

## The E5 verdict (§7.3)

**The relational arithmetic is readable; E5 is not needed for OIA.** The
largest arithmetic rule of the corpus, GST's withholding table (Amount_To_Pay,
rule 0: five rows, the Act's sections cited), reads:

```le
% cites: s 6; s 9; Law Companion Ruling LCR 2018/04 para 44; s 11
rule amount_to_pay_r0 with provenance "Amount_To_Pay.docx":
the total withholding amount is an amount N if
    the margin scheme applies
    and the value of the contract price is a price P
        and N = P * 7 / 100
    otherwise the supply is between associates
    and the value of the contract price is a price M
        and N = M / 10
    otherwise the supply is only partly a supply of new residential premises or potential residential land
    and the value of the contract price is a price K
        and the percentage of ownership of the purchaser is a number Q
        and N = K * 91 / 1000 / Q
    ...
```

against OIA's `the total withholding amount = the contract price * 0.091 /
the purchaser's percentage of ownership`. The relational form costs one
line per attribute reference, and the reference line is itself a sentence
of the program a reviewer already knows (it is the template). Across the
five projects there are 7 arithmetic lines, none with more than two
attribute references (so at most two binding lines before it). MOM's `days of GPPL the Father is
entitled to = number of weeks of GPPL * number of working days a week`
becomes `number of weeks of GPPL is a number N and number of working days a
week is a number M and V = N * M`. What hurt readability was not arithmetic
but the OIA sentences themselves (Word headings compiled as attributes,
authors' typos, `the value of` prefixes forced by LE's section words) — no
functional sugar would change those. Caveat: the public OIA corpus is light
on arithmetic; Guidewire's Gosu (Phase 2) remains the second test the
roadmap sets.

## What the second corpus changed in Logical English itself (LE2)

The translator works round nothing it can fix at the source. The second
corpus led to these changes in LE2 (each documented in
`docs/user/reference/language.md`):

- **Long chains of remembered answers** (`reasoner.pl`, §2.5). Loan
  Advisor's 360 payments, each read from the one before three times, overflowed
  the stack: a replayed answer copied its whole explanation (exponential in
  the chain), the nesting limit of 100 conditions stopped the chain, and
  storing every link's full explanation was quadratic. A replayed answer now
  cites its reasons once; a remembered question counts its depth afresh
  (capped at 5,000 nested remembered questions); a remembered explanation is
  kept whole up to 150 steps and otherwise to the depth that fits; the
  grouping of repeated explanations hashes their first 12 levels; long lists
  are abbreviated in explanations. The loan's 361 payments: from a stack
  overflow to 5–8 s.
- **Libraries** `lib/text` (joining, text of a number, contains, ends with,
  length), `lib/maths` (power) and `lib/lists` (an item followed by a list).
- **Expected numbers with decimals** (§12): matched by an answer that rounds
  to them at that many decimals — amounts to the cent, as OIA's own test
  cases compare currencies.
- Apostrophes in strings: the translator no longer replaces them (LE reads
  `"<dd class='x'>"` and `"Bob's"` as written), so generated HTML is the
  source's to the byte.

## Gaps

- **Rule table headings.** A decision table's columns are named after the
  attributes they test and conclude, and the table after what it concludes
  (`notification_type_table`: `branch id | country match flag | business
  event type | notification type`), as the OIA user review asked
  (a review that is not published). The variables of the rules that read a table are
  still named by the writer from their types (`for the id with the flag …`).
- **`.tsc` test scripts** are not read (none in the public corpus); nor are
  Excel entity-instance sheets (none of the tested projects uses one).
- **Entities**: since October 2026 entity-level conclusions, `ForAll`,
  `Exists`, `InstanceCount`/`Sum`/`CountIf`/`Minimum`/`Maximum`, `For`
  through one-to-one relationships, inferred instances and chains are mapped
  (above). Not mapped: many-to-many relationships given as input
  (`IsMemberOf`), entities nested more than one level under the case, and
  inferred instances whose identity cannot be inverted (a chain's identity
  must be "index + k") — residue if met.
- **`If(c, a, b)`** as an expression, `Number(text)`, `Substring`,
  `ExtractDate` and the other text-to-value functions are not read yet.
- **Temporal**: the current date is case data; change points, `ValueAt`,
  `WhenLast` and interval sums are not modelled (residue if met).
- **Three-valued logic**: closed world, above. s(CASP) was not tried.
  TODO: read OIA's unknown with Logical English's own unknowns (abducibles),
  scenario by scenario — the plan is roadmap §8 Phase 1c TODO (a working paper of the author, not published).
- **Interview screens** (`.xint`) are not read; the View is generated from
  the rules (one question per undefined attribute).
- **Roles** are found from Oracle's parse, which only `.xgen` attributes carry
  (a rulebase's `.stxt` has none): VIBECT and DCTAD have no role-like
  subjects anyway. A mention of a role in the middle of a sentence becomes a
  place only before a verb or as a possessor ("the Child's Mother"); an
  object such as "the applicant is the purchaser" keeps its words.
- Two LE core behaviours shaped the output (worth fixing in LE, the
  translator works round them): an `otherwise` alternative drops `V is equal
  to C` from the next alternative's guard when nothing else in the
  alternative mentions `V`, even when `V` is bound by the rule already (the
  translator writes the instance test of an entity table constant first,
  `"1-DCTA-EVENT-MISSING" is equal to the code`); and an opposite-form head
  holding a global compiles to a predicate of its own, which the positive
  sentence's conditions do not reach (such sentences keep their words).
- Word headings that Policy Modeling compiled as unconditional conclusions
  (GST `Property Details`) are kept as facts, faithfully.

## File ▸ Open (the IDE's importer)

`oia_import.pl` is what LE2's editor calls when an OIA file is opened
(registry `le_import.pl` in LE2; the row is in `../le_importers.pl`). It
accepts one compiled rule document (`<doc>.docx.xgen`), a deployed
`rulebase.xml` (with `rulebase.stxt` when both are zipped), or a zip of a
Policy Modeling project folder — the `.xprj`, `bin/`, `projectDataModel.xml`,
the Excel test files and `testResults.xml` — and writes the same twin as
`oia_migrate.pl` would: the program, its ledger, the rule documents'
paragraphs and lib/temporal. A rule the translator cannot map is a residue
block (a `TODO` comment with the rule's XML); a rule document that cannot be
read at all is a `TODO` comment of its own; a project without test files
gets its rules' analysis as scenarios. Excel test files need python3 with
openpyxl (without it they are skipped, with a note).

```prolog
?- use_module('migration/oia/oia_import').
?- detect_oia('/tmp/up/Warranty Claims (Intro)').
?- import_oia('/tmp/up/Warranty Claims (Intro)', '/tmp/out', imported(LE, Notes)).
```

## Implementation status (§8 Phase 1c)

*13 September 2026: done, in `migration/oia` (reader, mapping,
tests) and `examples/migration/oia` of the private place (five twins with
ledgers and Views).*
The reader takes both compiled forms — the `.xgen` of Policy Modeling
projects (Word rule documents with their paragraphs, levels, citations and
Oracle's own sentence parse) and the `rulebase.xml`/`.stxt` of deployed
rulebases (entities, relationships, sentence forms) — and the Excel test
files (with `testResults.xml` cited). *Revised the same day:* the roles of the global entity ("the Father",
"the Child") are typed places and named constants rather than words of
propositions, the three projects without test files get their rules'
analysis as scenarios (warranty 20/20, MOM 56/56, DCTAD 112/112, outcomes
by an evaluator of the OIA model), DCTAD has a View, and File ▸ Open reads
OIA material through `oia_import.pl`. Everything in the public corpus maps:
no residue in five projects (8–217 attributes, 3–105 rules, 11 rule
tables, 3 entities); rule tables become LE decision tables or `otherwise`
cascades, inferred entity instances rules whose instances are their
identifying values, and the date arithmetic uses lib/temporal (E3). The two
projects with tests reproduce 475 of 476 source expectations (VIBECT 269/269,
GST 206/207); the one miss is OIA's unknown state, the documented cost of
the closed-world reading, which the ledgers mark as *approximated* rule by
rule (78 of 552 elements; test files with expected unknowns included). E5 verdict: not needed — the relational
arithmetic of the real rulebases reads well.

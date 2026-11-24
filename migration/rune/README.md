# Rune → Logical English, for trade reporting

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

The translator of the design notes `rune.md` (the author's working papers, not published):
ISDA's Digital Regulatory Reporting (DRR), written in **Rune** over the
Common Domain Model (CDM), read into Logical English (LE) as a readable,
cited view of what DRR computes. DRR is ISDA's, under the ISDA DRR License
(September 2023), which allows its use "without modifications": the twins
are private, in `lpsPlus/examples/migration/rune/`, and never published
(rune.md §6).

**Where it stands (7 October 2026)** — steps 0 to 6 of rune.md §8; the
review of step 5 is a review that is not published.
Then rune.md §13–14, the same day: the Rune door as a migration like the
others: all 28 of DRR's reports, in three layers; File ▸ Open and Export in
the LE editor; the way back for whole reports, run on DRR's engine; the CDM
on its own; no dependency on cdmLOG (see *§14* below).

| File | What it does |
|---|---|
| `fetch_sources.sh` | DRR 7.14.0 from ISDA's public Maven repository into `.cache/` (the Rune files, the compiled Java, the test packs, the Java sources), DRR's Java libraries through Maven (`java/pom.xml`), Rune's runtime sources (finos/rune-dsl 9.95.0) and the Rune files read by `parser/rosetta2json.py` into `.cache/json` |
| `java/`, `oracle.sh` | the oracle: DRR's own Java (`DrrOracle.java`) run on the instructions of a test pack, as DRR's test harness runs it (references resolved, DRR's testing clock) |
| `flat.py` | a report as field-to-value pairs, and the comparison of two directories of reports |
| `parser/` | the Rune parser, three files that work together ([parser/README.md](parser/README.md)): `rosetta2json.py` (the structure, a copy of cdmLOG's converter maintained beside it), `rune_expr.pl` (Rune's expression language: the lexer, the parser, a DCG after Rune's own grammar, and the printer) and `rune_reader.pl` (the model in Prolog: the JSON loaded as facts, names resolved, every expression parsed) |
| `data/csa1/` | CSA 1 and cdmLOG's gold-standard reading of it (copies; step 4) |
| `gate.pl` | the gate: every expression of DRR, printed back, gives the tokens of its source |
| `rune_types.pl` | the typing: every name of an expression resolved (an input, an attribute of the implicit item, a function or rule, an enumeration value), every node given a type and a cardinality |
| `rune_closure.pl` | a report's fields (which rule computes which field, from the report type's annotations), and the closure of the rules, functions, attributes and enumerations they need |
| `measure.pl`, `java_fields.py` | step 1's measure: the fields checked against DRR's generated Java, the closure counted (`runs/closure_<report>.txt`) |
| `rune_data.pl` | a CDM object (a DRR input) as facts, with DRR's references resolved |
| `rune_paths.pl` | where things are, and a report's test pack as pairs of an instruction and its expected report, read from the test-pack configuration in Rune's own format (`pipeline-*.json`, `test-pack-*.json`: the `PipelineModel` and `TestPackModel` of `rosetta-common`): DRR's, or an upload's own, which File ▸ Open then prefers (a model of one's own with its test pack opens with its scenarios) |
| `hand_build.pl` | step 0: the scenarios of the hand-made twin of five fields |
| `rune_twin.pl` | step 2: a report's closure written as Logical English (the templates, the rules, the report's fields, the ledger) |
| `build.pl` | step 2: the twin of a report, its library, its ledger, and one file of scenarios per group of DRR's test pack |
| `ledger_json.pl` | each twin's `<twin>.ledger.json`, from its ledger and its templates, for View Original Text (run by `build.pl` and `cdm_build.pl`; `ledger_json:run([])` for all) |
| `twin_sources.py` | each twin's `sources/`: the Rune files of the namespaces its ledger names (run by `build.pl` and `cdm_build.pl`; `python3 twin_sources.py [twin…]` on its own) |
| `check.pl`, `summary.py` | step 2's measure: each scenario's whole report in one query, compared with DRR's, field by field (`<group>.le.check.txt`, `runs/<report>.txt`) |
| `ask.pl` | asking a twin a question in one scenario, condition by condition, to find out why a field differs |
| `mic_data.py` | step 3: the ISO 10383 records of the venues the test packs name |
| `compare.pl` | step 3: two reports field by field (`runs/compare_*.md`) |
| `csa_map.pl`, `csa_chain.pl` | step 4: cdmLOG's reading of a credit support annex in CDM 6.29, its margin call in LE, the collateral instructions and the link of the margin twin's scenarios to the margin call |
| `flip.py` | step 4: one fact of a trade flipped, DRR's Java on each |
| `le_to_rune.pl` (+ `le_to_rune_cli.pl`), `java_back/RuneBack.java`, `back.sh` | step 6: an LE rule as Rune, compiled by Rune's own generator, run by DRR's Java |
| `rune_fingerprint.pl` | §14: the fingerprints of a twin's own predicates when it was written (`<twin>.fingerprints.pl`), so that the way back knows which rules a user changed |
| `rune_writeback.pl`, `rune_export.pl` | §14: the way back for a whole report: the changed rules as Rune, the report's type as a subtype overriding the fields that use them, the report with that type (`rune_export.pl` is its command line; `all` writes every rule, the measure of the way back's reach) |
| `java_back/RuneRunner.java`, `rune_runner.pl`, `run_back.sh` | §14: Rune written back, run on DRR's engine: one warm Java process (Rune's validator and generator, the Java compiled in memory, DRR's Java on the test pack), every report compared with DRR's; `run_back.sh` does the same from a shell, cold |
| `rune_import.pl`, `rune_import_run.pl` | §14: File ▸ Open of a `.rosetta` file or a zip of them in the LE editor (the prebuilt twin of an unchanged DRR file; otherwise the twin built over DRR 7.14.0 with the upload laid over it) |
| `rune_le_export.pl` | §14: File ▸ Export to Another System ▸ Rune in the LE editor, with the run on DRR's engine in its notes |
| `measure_twin.sh`, `measure_back.pl` | §14: the measure of a twin against DRR's test pack (`runs/<twin>.txt`); the reach of the way back for every twin (`runs/back.txt`) |
| `cdm_build.pl`, `java/.../CdmQualifyOracle.java` | §14: the CDM on its own: the twin of `cdm.product.qualification` checked against the CDM's Java on the products of DRR's test pack (`runs/cdm_product_qualification.txt`) |

## How to run

```sh
migration/rune/fetch_sources.sh
migration/rune/oracle.sh cftc-part45 drr.regulation.cftc.rewrite.trade.reports.CFTCPart45ReportFunction
./myswipl.sh -q migration/rune/gate.pl
./myswipl.sh -q migration/rune/measure.pl -- 'CFTC Part45'
./myswipl.sh -q migration/rune/hand_build.pl
./myswipl.sh -g "use_module(le_kbs), runTestsFor('/lpsPlus/examples/migration/rune/hand/cftc_part45_hand.le', R), print_test_result(R), halt."
./myswipl.sh -q migration/rune/build.pl -- 'CFTC Part45'
./myswipl.sh -q migration/rune/check.pl -- /lpsPlus/examples/migration/rune/cftc_part45/rates.le
python3 migration/rune/summary.py cftc_part45 > migration/rune/runs/cftc_part45.txt
```

The twins need `le_extensions.pl` (a few nested conditions open with a
negation, which core LE cannot write).

## Step 0: the spike

**DRR from Maven.** ISDA's repository serves DRR 7.14.0 as a jar
(`com.regnosys.drr:rosetta-source:7.14.0`, 44 MB), not as a zip: the Rune
files (506), the compiled Java, and the test packs. DRR's Java libraries
come through Maven: CDM 6.29.0 (`cdm-java`), Rune 9.95.0, 119 jars.

**The oracle is exact.** DRR's `CFTCPart45ReportFunction`, run on the 195
instructions of the test pack whose expected CFTC Part 45 report is in the
archive, gives the archive's report for **195 of 195** instructions, **11,652
of 11,652** field values. Two things are needed for it, both what DRR's own
test harness does: the references of the input resolved first (a
`partyReference` points at a party by its key; without the resolver, the
counterparties come out empty) and DRR's testing clock
(`DrrRuntimeModuleTesting`: the reporting timestamp of the test packs,
29 April 2024). It takes about 3.5 seconds an instruction.

**The hand twin of five fields** (`examples/migration/rune/hand/`): Counterparty 1
(data element 13), Submitter identifier (22), Counterparty 2 identifier
source (15), and DTCC's Submitting Party - ID Type and Submitted For Party,
translated by hand with the functions they call (PartyLei,
PartyLeiAndPersonByRoles, NaturalPersonBuyerOrSeller,
ExtractReportSubmittingParty, and the CPMI-IOSCO critical data element
Counterparty 1 through its versions 3, 2 and 1). The 195 instructions are
its scenarios, made from DRR's JSON by `rune_data.pl`; their expectations
are the expected reports' values. **975 of 975 expectations pass**, in
about five seconds.

What the hand twin fixed for the generator (step 2):

- **Data.** One template per attribute the rules read, `the reporting side
  of *an instruction* is *a reporting side*`; an object is a name made from
  its type (`party_7`), the instruction is `instruction`. An attribute name
  shared by several types (`identifier`) has one template, with a general
  word for its owner. A value is a string, a number, `true` or `false`; an
  enumeration's value is its text in DRR's JSON (`"LEI"`).
- **Keys.** DRR copies a party wherever it is used, with the same key; the
  copies are one object in the scenario, so that "the reporting party is
  this party" compares what Rune compares. A key belongs to a type: DRR
  gives a person and its identifier the same key.
- **Lists.** A function's input with more than one value is an LE list
  (`the party LEI of a list is a value`); `only-element`, `distinct` and
  `first` are a `prolog` goal on the list an aggregate builds (`the list of
  each identifier such that ...`).
- **Citations.** The field's passage of the regulation is the rule's
  provenance (`with provenance "CFTC Part 45" at "appendix 1, data element
  13", confer "..."`); the industry's interpretation is a separate
  `according to "ISDA Peer Review Group, 9 March 2022"`.
- **Fields.** A query per field; an expectation per field and instruction.

## Step 1: the reader

**The structure** is `parser/rosetta2json.py`, a copy of cdmLOG's converter, extended (its version 0.2.0,
committed in cdmLOG) with the three declarations DRR needs and the CDM
does not use: `report`, `reporting rule`, `eligibility rule`, with the
`import ... as` aliases DRR's names go through, the `for` paths of
`[label]`, `[ruleReference]` and `[docReference]`, and a rule's trailing
`as "label"`. Reading DRR found five defects of the converter, which lost
or cut constructs (a comment at column 0, a provision over several lines,
`//` inside a string, a list literal at the start of a rule); fixing them
changed nothing in the CDM's own output but two added fields. DRR reads
whole: 327 namespaces, 1,971 reporting rules, 51 eligibility rules, 28
reports, 2,762 functions, 4,191 types, in about 6 seconds.

**The expressions** are parsed in Prolog (decision 3 of rune.md §10), by a
grammar written after Rune's own (`Rosetta.xtext` of finos/rune-dsl
9.95.0): `then` lowest, then `or`, `and`, equality, comparison,
arithmetic, `contains`/`default`/`join`, the postfix operations (`->`,
`exists`, `only-element`, `filter`, `extract`, ...), the primaries. **The
gate: 10,479 of 10,479 expressions of DRR (and of the CDM it carries)
print back to their own tokens** (`runs/gate.txt`).

**Names.** Rune resolves names per file, and a qualified name may be an
alias's (`cdeV3.execution.Cleared`), a full name, or a name relative to the
file's namespace (`party.ReportSubmittingEntity` in
`drr.regulation.common.trade`) or to an imported one (`payment.PeriodicPayment`
with `import drr.base.trade.*`). A bare name is, in this order, a variable,
an attribute of the implicit item, a function or rule (called on the item),
an enumeration value the context expects (the other side of a comparison,
the other branch of an `if`), or the value of the one enumeration in scope
that has it. In the closure of CFTC Part 45, every rule and function step
types, and 10 nodes stay unresolved (`buyer`, `seller` and `key`, inside
`switch` and constructor expressions).

**The fields of a report**, from its type's annotations, follow Rune's own
`RuleReferenceService`: an outer `[ruleReference for x -> y R]` wins over
the inner attribute's own, an override inherits, an attribute with many
values is not searched for nested fields. Checked against DRR's generated
Java (the report function's `assignOutput`):

| Report | Fields | Same rule as DRR's Java |
|---|---|---|
| CFTC Part 45 | 185 | 182, and the 3 others are rules whose body is `empty` (the Java writes `null`) |
| ESMA EMIR Refit, trade | 156 | 156 |
| FCA UK EMIR, trade | 158 | 158 |
| CFTC margin | 33 | 32 |

**The closure** (`runs/closure_*.txt`), what decides the template question
of rune.md §4.2:

| Report | Rules | Functions (in Java) | Attributes (names, types) | Enumerations |
|---|---|---|---|---|
| CFTC Part 45 | 377 | 341 (11) | 453 (309, 160) | 66 |
| ESMA EMIR Refit, trade | 372 | 400 (15) | 545 (359, 183) | 92 |
| FCA UK EMIR, trade | 368 | 396 (15) | 545 (359, 183) | 92 |
| CFTC margin | 38 | 49 (4) | 71 (60, 38) | 12 |

About a thousand templates for a trade report: LE2 handles that, so **the
twins use named templates only** (one per attribute name the closure
reads, one per rule and function), and no generic `the *an attribute* of
*an object* is *a value*`. The functions implemented in Java
(`[codeImplementation]`: `Now`, `DateDifference`, `RoundToPrecision`,
`StringContains`, ...) need a library of their own in the twin (step 2).

## Step 2: the twin of CFTC Part 45

**What is written.** `build.pl` writes the 377 rules and 341 functions of
the report's closure as one Logical English program
(`examples/migration/rune/cftc_part45/cftc_part45.le`, about 35,000
lines), with the report's 185 fields on top, and one file of scenarios
for each of the seven groups of DRR's test pack (195 instructions, each a
scenario whose expectations are DRR's expected report).

- **Templates.** One per attribute name the closure reads (`the reporting
  party of *a reporting side* is *a party*`), one per rule and function
  (`the CFTC counterparty 1 of *a transaction report instruction* is *a
  value*`), one per alias (`the product in strike price of ...`). Every
  rule's and function's template is `memorable`: the answer is worked out
  once per query. A function whose output is a yes or no is a sentence
  (`*a product* is IR swaption`).
- **Fields.** One template for the report, `the CFTC Part45 field *a
  field* of *an instruction* is *a value*`, with a rule and a query per
  field. A field of one value takes the rule's value only when the rule
  has exactly one, as DRR's Java does. A field whose value is an object
  (a strike price, a barrier) is reported by the object's own attributes.
- **Citations.** The regulation's passage is the rule's provenance, as in
  the hand twin; the industry's reading is a comment above the rule.
- **Rune's empty value.** An input of one value or none is `nothing` when
  it has none: the function is still called, as in Rune. `=` and `<>`
  follow Rune's runtime when a side is empty; an `if` whose test is empty
  takes its `then`.
- **Objects that Rune builds** (`PriceFormat { decimal: ..., ... }`) are
  values made of the place in the source and the inputs, with a rule for
  each attribute.
- **The library** (`examples/migration/rune/lib/rune.le` and `rune.pl`,
  copied beside each twin): lists, rounding, dates (`AddDays`,
  `DateDifference`, `LeapYearDateDifference`), DRR's clock, and the
  regular expressions of `StringContains`. Two of DRR's Java functions
  only read the data (`GetQuantityKeys`, `GetQuantityReference`); they are
  written as rules.
- **The ledger** (`cftc_part45.ledger.md`): 1,033 definitions encoded, 5
  approximated, 4 residue — the Java functions that compute rather than
  read (`VectorOperation`, `ToTime`, `ToDateTime`), and a `switch` on
  types; the approximated ones lose one branch each (a `switch`, a name
  the typer cannot resolve).

**The measure** (`runs/cftc_part45.txt`):

**11783 of 11833 expected field values agree (99.6%), 50 missing, 38 extra, in 195 instructions**. The count is of the scenarios' expectations: DRR's 11,652 field values (a list's repeated values counted once) and, for each of the 195 instructions, that the report's eligibility rule holds.

| Group | Instructions | Agree | Missing | Extra |
|---|---|---|---|---|
| cftc_event_scenarios | 41 | 2312 | 18 | 17 |
| credit | 14 | 848 | 1 | 1 |
| custom_scenarios | 25 | 1565 | 4 | 4 |
| equity | 24 | 1361 | 0 | 0 |
| events | 20 | 1111 | 16 | 13 |
| fx | 25 | 1559 | 9 | 0 |
| rates | 46 | 3027 | 2 | 3 |

The differences that remain are each a few instructions: a change in
notional after a partial termination, a fixing date, the action type of
three event chains.

**What the twin fixed in the reader, the data and LE.** Five things
mattered most:

- **Data.** A party written inside a reference (`"partyReference":
  {"value": {...}}`, in novations) is known by its key; a type that
  extends a choice (CDM's `BasketConstituent extends Observable`) has the
  choice's options; the locations an address points at are data.
- **Templates.** LE matches a sentence by its words, and a place can
  swallow words: a template made of the same words as another (an alias
  and an attribute) needs words of its own, and a field's name with "of"
  in it is written in quotes.
- **The writer** (LE2's `le_writer.pl`): an `otherwise` chain on the left of
  a connective is written nested; a double negation is never written on
  one line; a list built by an aggregate is a list.
- **Speed** (LE2): loading the twin went from 284 to about 40 seconds (an
  index of the templates by their first word, in the parser and the
  verifier), and a whole report from 168 to under 2 seconds an
  instruction (`memorable` templates, and no explanation of failures when
  the checker asks).
- **Typing.** A name in a report type's annotation is resolved in that type
  and relative to its namespace and imports.

## Step 3: EMIR Refit and UK EMIR

The same generator, two more reports: `build.pl -- 'ESMA EMIR Trade'` and
`build.pl -- 'FCA UKEMIR Trade'`. Two things the EU and UK reports needed that
CFTC Part 45 did not:

- **Reference data.** The venue of execution is worked out from the venue's
  record in ISO 10383, the international list of market identifier codes
  (MICs). DRR's Java fetches that list from iso20022.org while it runs
  (`API_GetMicDataImpl`). The twin has the records of the venues the test packs name
  (`mic_data.py`: 22 of the 2,883 records), as facts, and DRR's Java
  function is a rule that reads them.
- **The data of an object with an attribute called `value`** (a product's
  taxonomy: a source and a value) is not a wrapper of metadata; reading it
  as one lost the product's classification (ISO 10962) in every commodity
  trade.

**The measure:**

| Report | Instructions | Agree | Missing | Extra | Ledger (encoded, approximated, residue) |
|---|---|---|---|---|---|
| ESMA EMIR Refit, trade | 187 | 9,465 of 9,567 (98.9%) | 102 | 65 | 1,172, 5, 12 |
| FCA UK EMIR, trade | 154 | 7,894 of 7,985 (98.9%) | 91 | 45 | 1,164, 5, 12 |

(`runs/esma_emir_trade.txt`, `runs/fca_ukemir_trade.txt`; the EU count includes
the three flipped trades of step 4.)

The residue is mostly DRR's Java that builds schedules (`Create_ContinuousPriceSchedule`
and `Create_ContinuousQuantitySchedule`: the notional and price schedules of a
trade whose amounts change over time) and holiday calendars
(`BusinessCenterHolidays`); a field computed from them is missing.

**The comparison** (`compare.pl`, `runs/compare_ESMA_EMIR_Trade_FCA_UKEMIR_Trade.md`;
rune.md §7 question 4). For each field of the UK report: whether the UK
computes it with the EU's own rule (*shared*), with a rule of its own that
computes the same thing (*the same*), or differently (*changed*). For a
changed field it shows both rules and every rule or function between them
where the two part. Two rules are the same when their expressions are the
same, up to rules and functions that are themselves the same:

- **129 fields shared**, 0 the same in a rule of their own, **27 changed**,
  and 2 fields only in the UK report (1.21, the execution agent of each
  counterparty).
- The changes are of three kinds. The UK names its own regime (`UKEMIR`
  where the EU says `EMIR`: Confirmed, Clearing obligation, Venue of
  execution, the counterparties' nature and clearing threshold). The UK
  reads its own party information (`fcaPartyInformation`). And the EU
  adjusts the payment frequency of a leg (`AdjustFrequencyPeriod`) where the
  UK reports it as it is (fields 2.81, 2.82, 2.97, 2.98).
- The passages cited differ for every field: the EU's cite ESMA's technical
  standard (RTS), the UK's the FCA's.

## Step 4: the credit support annex, all the way to the margin report

rune.md §7 question 5, "where did the collateral numbers come from?". The
chain runs from an ISDA credit support annex (CSA) read by cdmLOG to DRR's
CFTC margin report, in Logical English, and is checked against DRR's Java at
the end.

1. **The margin twin.** `build.pl -- 'CFTC Margin'`: 95 definitions, all
   encoded; on DRR's own two collateral instructions it gives 46 of 46
   expected values, and the oracle gives 44 of 44 (DRR's Java, on the
   margin report function, `CFTCMarginReportFunction`).
2. **From CDM 8 to CDM 6.29** (decision 5 of rune.md §10: cdmLOG keeps its
   CDM, 8.0.0-dev.4). `csa_map.pl` walks the path of each value cdmLOG read
   from the annex (66 labelled values of CSA 1's gold standard, checked by
   hand) in DRR's CDM, 6.29, with a short table of the names the two
   versions give the same thing (`rewrite/3`). **38 of the 66 map.** The 28
   that do not are the eligible collateral (24 values: CDM 6.29 describes
   eligible collateral another way, `EligibleCollateralCriteria`) and the
   independent amounts (4: CDM 6.29's credit support obligations have no
   place for them). The values become CSA 1 as a `LegalAgreement` in DRR's
   JSON.
3. **The margin call, in Logical English** (`csa_chain.pl` writes
   `examples/migration/rune/cftc_margin/csa1_margin_call.le`): the annex's
   terms as facts, each with its paragraph (11(b)(iii)(A) to (D)), and
   paragraphs 2 and 10 of the 1995 annex as rules: the Credit Support
   Amount, the Delivery and Return Amounts, the Minimum Transfer Amount, the
   rounding. The independent amounts, which CDM 6.29 cannot hold, come from
   cdmLOG's CDM 8 reading, and the program says so. Four valuation dates:
   Party A delivers 1,250,000; returns of 850,000; a return of 20,000 that
   is under the Minimum Transfer Amount and is not made; everything
   returned when the exposure falls below Party B's independent amount.
4. **The collateral report.** For each date, DRR's own collateral
   instruction (Collateral-ex01's shape) with CSA 1 as its portfolio's legal
   agreement and the balance the margin call gives; DRR's Java computes the
   CFTC margin report of each (`.cache/chain/`).
5. **The margin twin on the same instructions** (`cftc_margin/csa1.le`):
   the scenarios are the instructions, but the balance's amount is not a
   number there: it is the margin call's answer (`csa_chain.pl -- link`).
   **64 of 64 expectations pass**: the twin, computing the balance from the
   annex's paragraphs, reports what DRR's Java reports.

The margin type is a reading for the former ISDA lawyer to confirm: the
1995 annex is taken as a variation margin agreement. The collateralisation
category stays what DRR reads from the instruction (rune.md §7, the caution
of question 5).

**Question 3, "what changes if…?"** (`flip.py`): DRR's Credit-Index-CDX-ex02
with one fact flipped for EMIR: the counterparties also mandatorily
clearable (the clearing obligation goes from FLSE to TRUE), the
counterparties below the clearing threshold (fields 1.7 and 1.13 go to
false). DRR's Java runs on each; the twin's scenarios of them are the group
`flips` of the EMIR twin.

## Step 6: the way back

An LE reporting rule, written in the words of a twin, becomes Rune, Java made
by DRR's own tools, and runs with DRR's Java (`back.sh`):

1. `le_to_rune.pl` reads the rule's clauses, as LE2 compiles them, with the
   twin's templates (`<twin>.templates.pl`, written by `build.pl`: which Rune
   attribute, function or rule each template stands for) and the Rune model
   (the types, to write a constant as the enumeration value its place asks
   for). It reads the shapes the generator writes and the ones an author
   writes with the same words: attributes as paths, functions and rules as
   calls, a list taken as one value or none, negations, comparisons, and
   several rules as `if ... else if ...`. Anything else stops it with the
   condition it cannot read.
2. `java_back/RuneBack.java` loads the Rune of DRR 7.14.0, the CDM 6.29 and
   their dependencies (784 files), then the new file; Rune's own validator
   checks it and Rune's own generator (Rune 9.95) writes its Java, as DRR's
   build would. About a minute.
3. The Java is compiled against DRR's jars and run by the oracle's harness
   on every instruction of the test pack.

**The demonstration rule** (`fca_ukemir_trade/back_confirmed.le`): the EU's
Confirmed (field 2.29) written by hand in LE with the UK's regime, as an
analyst would write it from the comparison of step 3. Its Rune:

```
reporting rule ConfirmedFromLE from drr.regulation.common.TransactionReportInstruction:
    if drr.base.qualification.event.IsAllowableAction(item)
       and (drr.base.qualification.event.IsCleared(item -> originatingWorkflowStep)) = False
       and (drr.regulation.common.IsRegulatedMarketOrThirdCountryEquivalentMarket(item -> reportableInformation,
                drr.regulation.common.RegimeNameEnum -> UKEMIR)) = False
    then drr.standards.iosco.cde.version3.execution.Confirmed
```

Rune's validator accepts it, and **on the 154 instructions of the UK test
pack it gives DRR's own UK Confirmed for 154 of 154**.

## §14: Rune as a migration like the others

rune.md §14 says what was done and decided; here, how it works.

**Twins in three layers.** `rune_twin:report_twin_layers/3` puts each
definition of a report's closure in the layer of its namespace: the
report's own namespace (`<twin>.le`, what the editor shows when a DRR file
is opened), DRR's other namespaces (`<twin>_drr.le`), the CDM and the
models DRR builds on (`<twin>_cdm.le`); an object a rule builds goes with
the rule. Included files are one knowledge base, so a rule may call a
predicate of any layer; a template is declared in the lowest layer that
defines or uses it, and each file's writer is told the templates of the
layers below (`template(F, T, [included])`).

**Core LE only.** An alternative of an `or` that opens with a negation, a
list or an aggregate, which core LE cannot write (only le_extensions.pl's
`either`/`all of` blocks), becomes a rule of its own, "*a value* meets
condition N of <the definition>", on the variables it shares with the rest
of its rule (`rune_twin:lift_clauses/3`); the way back reads such a rule in
place. An alternative sharing more than twenty variables is left as it is.
The places of such a rule are separated by *beside*, not *with*: the
words of a place can hold *with* ("the payout leg with auxiliary"), and the
parser then split the sentence at the wrong one, so that the condition
never held (FCA UKEMIR Trade lost Settlement Currency 1).

**Lists of names.** A list of twenty constants or more, or any list of
enumeration values turned into text (DRR's lists of floating rate names,
`[FloatingRateIndexEnum -> X to-string, ...] any = floatingRate`), is one
membership, "the value is in [...]", not an `or` of one sentence per name:
LE's parser holds each level of a nested `or` until the sentence ends, and
the 250 names of `GetIndexIndicatorFromFloatingRateOTHR` took more than its
1 GB stack (five trade twins had 7,270 such lines).

**The 28 reports.** `rune_paths:report_pack/3`: twelve transaction reports
(DRR's FpML record-keeping test pack) and the margin and valuation reports
of eight regulators (one or two instructions each in DRR's test pack).

| Report | Twin | Instructions | Field values agree | Missing | Extra |
|---|---|---|---|---|---|
| CFTC Part45 | `cftc_part45` | 195 | 11,783 of 11,833 (99.6%) | 50 | 38 |
| CFTC Part43 | `cftc_part43` | 195 | 8,040 of 8,076 (99.6%) | 36 | 33 |
| SEC Trade | `sec_trade` | 176 | 8,747 of 8,777 (99.7%) | 30 | 36 |
| SEC PPD | `sec_ppd` | 176 | 6,751 of 6,768 (99.7%) | 17 | 28 |
| CSA Trade | `csa_trade` | 217 | 11,962 of 12,039 (99.4%) | 77 | 83 |
| CSA PPD | `csa_ppd` | 217 | 8,451 of 8,511 (99.3%) | 60 | 69 |
| ESMA EMIR Trade | `esma_emir_trade` | 187 | 9,466 of 9,567 (98.9%) | 101 | 64 |
| FCA UKEMIR Trade | `fca_ukemir_trade` | 154 | 7,895 of 7,985 (98.9%) | 90 | 44 |
| ASIC Trade | `asic_trade` | 176 | 6,050 of 6,118 (98.9%) | 68 | 66 |
| MAS Trade | `mas_trade` | 176 | 6,556 of 6,631 (98.9%) | 75 | 68 |
| HKMA Trade | `hkma_trade` | 176 | 8,288 of 8,522 (97.3%) | 234 | 150 |
| JFSA Trade | `jfsa_trade` | 176 | 6,628 of 6,878 (96.4%) | 250 | 65 |
| the 16 margin and valuation reports | `<regulator>_margin`, `<regulator>_valuation` | 28 | 625 of 625 (100%) | 0 | 0 |

In all 101,242 of 102,330 field values (98.9%) on 8 October; **on 18 October, 102,550 of 103,504 (99.1%)**, after DRR's two `pre-enrich` samples of each trade report were added and a rounding defect fixed (the design notes `rune.md` §15; `runs/<twin>.txt` are the current figures). Measured with `measure_twin.sh` (each scenario file by `check.pl`, summed by `summary.py` into `runs/<twin>.txt`). The values that differ: fields DRR computes in Java (schedules of prices and quantities, residue blocks), `distinct` of objects (the twin compares their names, DRR their contents: JFSA's technical record identifier, 170 values), and a few shapes read differently.

**File ▸ Open.** `rune_import.pl` is the adapter; the work runs in a child
Prolog process (`rune_import_run.pl`), so that the server never holds two
models. An upload of DRR's own files, unchanged, opens the twin of
`examples/migration/rune/` (copied; seconds). Otherwise DRR's Rune files are
copied into a temporary folder, the upload laid over them (a file of the
same name replaces DRR's), `rosetta2json.py` reads the whole, and the twin
is built: of the first report the upload declares (with DRR's test pack as
scenarios when DRR has one), or, for a file without a report, of its
namespaces' rules and functions (`rune_twin:namespace_twin/3`).

**A server for the twins.** A trade twin with its largest scenario file
(FCA UKEMIR Trade's `rates.le`) takes about nine minutes to load and more
than LE's default 1 GB Prolog stack, near which the load slows to a crawl.
The server that opens them is started with a larger one,
`./myswipl.sh --stack-limit=4g -g "use_module(classic_web_api), start_api_server(3050)"`;
LE2 allows a load or an export 900 seconds (`le_api:operation_time_limit/2`).

**File ▸ Export ▸ Rune.** `rune_le_export.pl`, in the server's own
process: DRR's model is loaded once (about ten seconds, about 90 MB), the
program's predicates fingerprinted and compared with those of the twin as
written; each changed reporting rule of the report's namespace is written
back by `le_to_rune.pl`; the report's type becomes `<Type>LE extends
<Type>`, overriding each attribute that holds a field whose rule changed,
with every rule reference under it (`for` paths for nested fields); the
report is declared again with that type. A rule source cannot do this:
Rune 9.95 resolves a `for` path only on a type's own attribute, and with a
rule source a field loses a rule it inherits through an `override` (seven
`packageIdentifier` values of FCA UKEMIR Trade, in a test).

**Run on DRR's engine.** `rune_runner.pl` starts `RuneRunner` once per
server (the export menu starts it, and warms it with a first request): it
loads DRR's 784 Rune files, and for each request replaces the file written
back, validates it, generates its Java, compiles it in memory against DRR's
runtime and calls `DrrOracle.runPairs` in a class loader of DRR's runtime
kept between requests. The reports are compared with DRR's expected ones in
Prolog. About 40 seconds a report once warm; four minutes the first time.

**The way back's reach.** `le_to_rune.pl` reads the shapes `rune_twin.pl`
writes: lists collected (filter, extract, a named element `x1` so that the
instruction is not hidden), a value given by any condition (a condition
that names a variable not yet given is put after the others), disjunctions,
existence, membership, constants compared with rules, functions and
attributes, `any` for a comparison of a list with one value, and the
"meets condition N" rules in place; a library operation (only element,
first, distinct values, ...) whose value is known already, as a
comparison; "every element of the list is X" as `all =`; a list of an
attribute's values that pass tests as `filter`, with `then` before what
follows a closure; a list of constants (`each T such that T is "A" or T is
"B"`) as a list literal. A constant takes the type of where it goes: the
rule's own type for the value a rule gives, the input's for a function's
argument, the other side's for a comparison, so that an enumeration's
value is written `PartyIdentifierTypeEnum -> LEI` (an enumeration that
extends another has the other's values too), and the twin's text "[FCA]"
or list ["FCA"] is `[SupervisoryBodyEnum -> FCA]`. Every issue Rune's
validator raises, and every field that differs on DRR's engine, is
written to `runs/back.txt` under its twin. `measure_back.pl` writes every rule of
each twin's main file back and runs the result (`runs/back.txt`, with
every issue of Rune's validator and every field that differs): 1,137 of
1,280 rules written back; 2,197 of 2,249 reports exactly DRR's own, 22 of
the 28 twins on every instruction. CSA Trade and CSA PPD differ in 25
reports each (the limit 99999999999999999999.99999 comes back as 1.0e+20,
and one leg 2 quantity), HKMA and MAS Trade in 2 each (cleared, where the
twins differ from DRR too). `RUNE_BACK_OUT` writes the lines elsewhere;
`check.pl` reads `RUNE_STACK_LIMIT` (bytes) for the Prolog stack.

**The CDM on its own.** `cdm_build.pl`: the twin of `cdm.product.qualification` (172 definitions, 1 approximated), its scenarios the economic terms of the products of DRR's test pack, checked against the CDM's own Java (`CdmQualifyOracle.java`): 22,000 of 22,000 answers agree (100 functions on each of 220 products; `runs/cdm_product_qualification.txt`). Each scenario names its economic terms (`the economic terms of the instruction is economic_terms_27`) and each query starts from them: a qualification that counts the payouts of its economic terms names them nowhere else, so that the query answered for none in particular, and held when a swaption's underlying swap qualified.

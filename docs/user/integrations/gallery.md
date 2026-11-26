# The Migration Gallery: twenty-one systems, and how each twin was checked

*Kind: gallery · Audience: anyone deciding whether Logical English can read their rules · Status: current (2026-11-24)*

Logical English (LE) is a way to write rules in English that a computer can run. A
*translator* is a program that reads the files of a different system and writes the
same rules in Logical English. The result is called a *twin*. Each twin keeps the
tests of the other system, written as *scenarios*. A scenario is a set of facts,
together with the answers that the other system gives. When you run the scenarios,
you check the twin against the other system.

This page lists the twenty-one systems that the translators read. For each system, the
page tells what the twin was checked against, and the result. When we can run the
engine of the other system, the twin is checked against that engine. For some
systems, there is no engine that we can run. Then the page tells what the twin was
checked against instead.

When the twin can be published, the **Open** link runs the twin in your browser.
You do not need an account, and you do not have to install software. When the
licence of the other system does not let us publish the twin, the page tells you.
Then the video shows the twin when it runs.

The organisations that make these systems did not write, examine or approve the
translators or the twins. The names of the systems are the trademarks of their
owners.

## Contents

- [The Migration Gallery: twenty-one systems, and how each twin was checked](#the-migration-gallery-twenty-one-systems-and-how-each-twin-was-checked)
  - [Contents](#contents)
  - [The twenty-one systems](#the-twenty-one-systems)
  - [How to read the results](#how-to-read-the-results)
  - [Try one in two minutes](#try-one-in-two-minutes)
  - [A free twin of your own program](#a-free-twin-of-your-own-program)
  - [See also](#see-also)

## The twenty-one systems

"Both ways" means that the editor can also write a Logical English program back in
the format of the other system. *LE for LPS* is Logical English for programs that act
over time, for example contracts. LE for LPS runs in the sister editor, LPS2 (Logic
Production Systems 2).

| System | Direction | Checked against | Result | Twin | Video | Guide |
|---|---|---|---|---|---|---|
| **Axiom RuleSpec** (United States benefit and tax rules) | both ways | the engine of Axiom | 473 of 473 answers that were checked. 13 more answers, in 3 test cases, were not checked. Written back: 37 of 39 programs pass each case on the engine of Axiom. The export refuses the other 2, and gives the reasons | [Open](/editor/index.html?example=migration/rulespec/snap/us_policies_usda_snap_fy_2024_cola_maximum_allotments) | [watch](https://www.youtube.com/watch?v=ZF593VoCCK8) | [guide](/docs/user/integrations/rulespec) |
| **Bitcoin Miniscript** (spending policies) | both ways | an evaluator that the translator has, written from the Miniscript specification (BIP 379); and a node of a public Bitcoin test chain | 361 of 361. Of these, 271 are checked against the evaluator. The other 90 are attempts to spend that were sent to the node of the test chain. The node accepted 16 and refused 74, as the twins say | [Open](/editor/index.html?example=migration/miniscript/liana_inheritance/liana_inheritance) | [watch](https://www.youtube.com/watch?v=04Vbk13G7K4) | [guide](/docs/user/integrations/miniscript) |
| **Blawx**, version 1 (rules as code, Canada; not the hosted Blawx 2 and 3) | into LE | the answers of the reasoner of Blawx version 1: its s(CASP) program, run with the s(CASP) library of SWI-Prolog | 163 of 163, in 15 projects | [Open](/editor/index.html?example=migration/blawx/rps/rps) | [watch](https://www.youtube.com/watch?v=_CdWVsLthhk) | [guide](/docs/user/integrations/blawx) |
| **Catala** (laws as programs, in English and French) | both ways, *preliminary* | the interpreter of Catala (a nightly build of August 2026) | 129 of 129 in 9 programs, 15 more waiting. 3 more programs do not give answers yet. Written back: 4 programs, 42 of 42 tests pass on the interpreter of Catala. The export refuses 2 more programs, and gives the reasons | [Open](/editor/index.html?example=migration/catala/smic/smic) (the French minimum wage, in Français Logique) | [watch](https://www.youtube.com/watch?v=GEm6ybIKyWM) | [guide](/docs/user/integrations/catala) |
| **Daml** (contracts on Canton, the ledger software of the Canton Network) | both ways, as LE for LPS | a Canton sandbox. For the 4 scripts that set the time: the IDE Ledger of Daml Script | 18 of 22 scripts end with exactly the active contracts of Daml. The guide explains the other 4 | [Open in LPS2](https://lps2.logicalcontracts.com/ide?example=migration/daml/simple_iou/simple_iou.le) | [watch](https://www.youtube.com/watch?v=9Svirhcghb4) | [guide](https://lps2.logicalcontracts.com/docs/user/integrations/daml) |
| **DMN** (decision models and their FEEL expressions: the OMG standard, and the Dutch STTR profile) | into LE | the expected results of the DMN Technology Compatibility Kit (TCK), compliance level 2, and of the Benefit Decision Toolkit; on generated cases, the DMN engines of Camunda 7.23 and of Drools 10.2 (Apache KIE, incubating) | 138 of 138 (TCK compliance level 2, 28 models). On compliance level 3, the translator is not complete: 1,745 of 3,559. 195 of 195 (Benefit Decision Toolkit of Code for Philly). 399 of 399 (example models of Dutch government rules, RONL) | [Open](/editor/index.html?example=migration/dmn/bdt/homestead_exemption/homestead_exemption) | [watch](https://www.youtube.com/watch?v=CiCwgb599Tk) | [guide](/docs/user/integrations/dmn) |
| **Drools** (business rule files; a project of Apache KIE, incubating) | into LE and LE for LPS | a session of Drools 10.2.0 | 5 of 5 small rule bases end with the same working memory as Drools: 2 examples of Drools, and 3 rule bases that were written for the check. The Java code in the rules is not translated | [Open in LPS2](https://lps2.logicalcontracts.com/ide?example=migration/drools/insurance/insurance.le) | [watch](https://www.youtube.com/watch?v=sdb3BJdb5jE) | [guide](https://lps2.logicalcontracts.com/docs/user/integrations/drools) |
| **Epilog** (a logic programming language from Stanford University) | into LE and LE for LPS | EpilogJS, the engine of Epilog | 6 rulesets: 21 of 21 queries give the answers of EpilogJS. 71 of 75 games, and 2 programs with operations, end in the same state as in EpilogJS | [Open](/editor/index.html?example=migration/epilog/kinship/kinship) (rulesets); [games in LPS2](https://lps2.logicalcontracts.com/ide?example=migration/epilog/tictactoe/tictactoe.le) | [watch](https://www.youtube.com/watch?v=hqGWqiyA4So) | [guide](/docs/user/integrations/epilog) |
| **Excel workbooks** (calculators kept in spreadsheets) | into LE | the values that Excel saved in the workbook; and new cases that an open-source spreadsheet engine (Formualizer, not Excel) calculates from the workbook | each checked value agrees: 2,588 values in 7 workbooks, 484 more waiting. One of the 7 workbooks is published (854 of 854, 49 more waiting). The other 6 state no licence, so their twins are not published | [Open](/editor/index.html?example=migration/spreadsheet/cms_mlr/cms_mlr) (the 2025 Medical Loss Ratio calculator of the United States Centers for Medicare & Medicaid Services) | [watch](https://www.youtube.com/watch?v=cVKjigqVvlo) | [guide](/docs/user/integrations/spreadsheets) |
| **L4** (legal rules and contracts; Legalese, from Singapore Management University) | into LE and LE for LPS | the evaluator of L4 (the release of April 2026) | 621 of 621 rule answers. 87 of 95 contract runs end at the same point as in L4. The translator did not translate the other 8 | [Open](/editor/index.html?example=migration/l4/british_citizen_act/british_citizen_act) | [watch](https://www.youtube.com/watch?v=Rb0rHYy1Ys8) | [guide](/docs/user/integrations/l4) |
| **LegalRuleML** (an OASIS Standard for legal rules) | both ways | SPINdle, the defeasible logic reasoner that was used to test the standard, on a theory that the translator writes from each example | 68 of 68 answers, in the 7 examples of the standard that have scenarios. 5 more examples are translated with no scenarios. The scenarios were written for the twins; they are not part of the standard | [Open](/editor/index.html?example=migration/legalruleml/ex5_section29new/ex5_section29new) | [watch](https://www.youtube.com/watch?v=oPdimQmfE4M) | [guide](/docs/user/integrations/legalruleml) |
| **LOMO** (descriptions of the rules of EU law: the Legal Obligation Metadata Ontology of the European institutions) | both ways | LOMO's seven search queries, run by rdflib on the RDF data; LOMO's validity rules, run by pySHACL. A description has no cases: the cases of the guide were written with answers worked out from the text | The seven search queries of LOMO: the same 1,977 rows on the data and on the registers, 131 of 131 files. The validity rules: the same 166 results as pySHACL, 134 of 134 files. Written back: 131 of 131 registers give the same graph again; 93 of LE2's 99 programs that cite provisions become valid descriptions, and the export refuses the other 6, with the reasons | [Open](/editor/index.html?example=migration/lomo/other/financial_reporting_dir_2013_34_lomo_manual&query=obligations) | (not yet on the channel) | [guide](/docs/user/integrations/lomo) |
| **Oracle Insurance Policy Administration (OIPA)** (life and annuity transactions) | into LE | a calculator of the transaction formulas that we wrote from the public configuration guide of Oracle. It is not the engine of Oracle. The twins were not run on OIPA | 103 of 103 values, in 6 example transactions that we wrote. They are not configurations of Oracle | [Open](/editor/index.html?example=migration/oipa/termlife_grace_check/termlife_grace_check) | [watch](https://www.youtube.com/watch?v=IFxy2gi_BjU) | [guide](/docs/user/integrations/oipa) |
| **Oracle Intelligent Advisor** (rules for public services and insurance) | into LE | the test results of the projects | 475 of 476 test results, in the 2 public projects that have test files (5 projects are translated). The one difference is the *unknown* value of Oracle Intelligent Advisor. When a test gives no answer to a question that a rule table needs, Oracle Intelligent Advisor gives no result. Logical English reads the missing answer as false | not published: the five projects state no licence. Instead, [Open](/editor/index.html?example=regulatory/dfe_funding/dfe_16_19_funding&scenario=full_time&query=OnProgPayment) the full 16 to 19 funding rulebase of England. The Department for Education publishes this rulebase as rule documents. A coding assistant (Claude Code, with the model Claude Opus 5.5) wrote it by hand from these documents. It is not a translation. It was checked against an independent second reading, not against the engine of Oracle | [watch](https://www.youtube.com/watch?v=i4qEYqAnvUs) | [guide](/docs/user/integrations/oia) |
| **PolicyEngine and OpenFisca** (tax and benefit models) | both ways, *preliminary* | the engines of the models | 719 of the 774 test answers that the twins can check, in 6 programmes of 3 models (the country template of OpenFisca, PolicyEngine US, PolicyEngine UK). The ledger of each twin lists the 55 answers that are different. On the model of France: 2,286 of 2,302 income tax answers, in 432 test cases | not published: the licence of the models (AGPL-3.0) would apply to the twins | [watch](https://www.youtube.com/watch?v=WgYGTqR1GJE) | [guide](/docs/user/integrations/openfisca) |
| **Ponens** (policies that examine the record of the session of an AI agent. Its packs follow texts of ESMA, NIST, IOSCO, MISRA, DO-178C and others) | both ways, as LE for LPS | `ponens trace check`, the evaluator of Ponens | 11,236 of 11,236 verdicts: 212 of the 213 policies of Ponens (13 packs, and the policies in no pack), each on 53 traces. Ponens gives no verdict on the other policy. Written back: the same 11,236 | [Open in LPS2](https://lps2.logicalcontracts.com/ide?example=migration/ponens/esma_mifid_ai_investment_services/esma_mifid_ai_investment_services.le) | (not yet on the channel) | [guide](https://lps2.logicalcontracts.com/docs/user/integrations/ponens) |
| **RUML** (rulemaps of laws: the Rulemapping Logic Format, published by Law as Code Institut GmbH, Berlin) | both ways. Logical English also evaluates a rulemap; it does not claim conformance to RUML | the 103 evaluation tests of RUML; on generated cases, an evaluator that the authors of the translator wrote from the specification (the publisher of RUML has published none) | 3,508 of 3,508, in 80 rulemaps: 384 from the tests of RUML, and 3,124 from generated cases. The evaluation: 103 of 103 tests of RUML, in both modes. Written back: 80 of 80 rulemaps give the same results (1,575 of 1,575 node results) | [Open](/editor/index.html?example=migration/ruml/spec/4_14_haertefall/4_14_haertefall) | (not yet on the channel) | [guide](/docs/user/integrations/ruml) |
| **Rune** (the language of the Common Domain Model, a FINOS project, and of the Digital Regulatory Reporting rules of ISDA) | both ways | the expected reports of the test pack of Digital Regulatory Reporting (DRR) | 99.1% of 103,504 report fields, in the 28 reports of DRR. Written back: 2,197 of 2,249 reports are exactly the same as the reports of the engine of DRR | not published: the licence of DRR lets you share its rules only without changes | (not yet on the channel) | [guide](/docs/user/integrations/rune) |
| **s(CASP) and Prolog** (logic programs) | both ways | s(CASP) itself | 21 of 21, 2 more waiting. The way back: of 93 Logical English examples written as s(CASP) and read again, 87 give the same s(CASP) program | [Open](/editor/index.html?example=migration/scasp/loanwithcure/loanwithcure) | [watch](https://www.youtube.com/watch?v=BI6TJf6TVHk) | [guide](/docs/user/integrations/scasp) |
| **Socotra** (insurance products) | into LE | the Liquid scripts of the products, run by a separate Liquid interpreter on generated quotes. The twins were not run on the platform of Socotra | 992 of 992 expected values that can run, 100 more waiting, in the 17 products of the public product library | not published: the product library states no licence | [watch](https://www.youtube.com/watch?v=bNIW68EFP2c) | [guide](/docs/user/integrations/socotra) |
| **Solidity** (Ethereum smart contracts) | both ways, as LE for LPS | the record of the Ethereum main network: 822 logged USDC transfers, mints and burns, replayed as calls. For the way back: the Solidity compiler and an Ethereum virtual machine | 849 of 849 values agree with the main network | [Open in LPS2](https://lps2.logicalcontracts.com/ide?example=migration/solidity/replay/usdc_window.le) (a shorter replay: 201 logs, 215 of 215 values) | [watch](https://www.youtube.com/watch?v=xksKg0QvW6Y) | [guide](https://lps2.logicalcontracts.com/docs/user/integrations/solidity) |

## How to read the results

- **"475 of 476"** means that the tests of the other system gave 476 answers. The
  twin gave the same answer in 475 of these cases. Each guide tells what the
  differences are.
- **"15 more waiting"** means that 15 more answers of the other system cannot be
  checked yet. The parts of the program that these answers need are not translated.
  The scenarios keep these answers as comments, with the reason for each answer. The
  results do not count these answers as agreements or as differences.
- **"Preliminary"** means that a large part of a large real program is still left
  for a person to translate. The translator gives a good start, but not yet a
  finished program.
- **"Written back"** means that the twin, or a program written in Logical English,
  was translated back into the format of the other system. Then it was run on the
  engine of that system.
- **A refusal is also a result.** A program can say something that the other system
  cannot express. Then the export refuses and names the lines. The export does not
  write something with a different meaning.
- **The twin keeps what was not translated.** Each twin has a *ledger*. The ledger is
  a table with one row for each part of the source. Each row tells whether that part
  was translated, approximated, or left for a person to translate. For an
  approximation, a note tells how its meaning changed. To see the source next to the
  twin, select **File ▸ Show the Original…** in the editor.

## Try one in two minutes

LegalRuleML is the standard of OASIS (a standards body) to write legal rules in XML.
XML is a text format for structured data. LegalRuleML tells who is obliged,
permitted or forbidden to do what. Its specification has an example from section 29
of the National Consumer Credit Protection Act of Australia, with the penalties
that the Act had in 2009. Section 29 says that no one can engage in a credit
activity without a licence. It also gives the penalties for this.

Do these steps:

1. Open the [twin of section 29](/editor/index.html?example=migration/legalruleml/ex5_section29new/ex5_section29new&scenario=unlicensed_trader&query=obligations).
   The link selects the scenario `unlicensed_trader` and the query `obligations` for
   you.
2. Click **Query**. Two answers appear: alice is obliged to pay 200 penalty units,
   and alice is obliged to pay 2000 civil penalty units.
3. Click an answer. The explanation shows the reason: alice engages in a credit
   activity without a credit licence. Thus she breaks the prohibition. The penalty is
   the penalty that the example gives. In the Act, each penalty is the largest
   penalty that a court can order. The Act of today has different penalties.
4. Select the scenario `licensed_trader` and the query `permissions`. The answer is
   that bob, who holds a licence, is permitted to engage in a credit activity.
5. Select **File ▸ Show the Original…**. The editor shows the LegalRuleML document
   that the twin was translated from.

## A free twin of your own program

Send us one program, rulebase or spreadsheet of yours, from one of the systems above.
In five working days, you receive its Logical English twin, its ledger, and a link
that runs the twin in the browser. This service is free, and you can keep the
result. We publish nothing without your written permission. Write to
<licensing@logicalcontracts.com>, or use the form at
<https://logicalcontracts.com/home/contact-us/>.

The translators themselves are open source. The translators are in the folder
`migration/` of Logical English 2, with the same licence, the Apache License 2.0. On
the hosted service, the translators are free for each visitor who signed in. The
translators and each twin are given "as is", without warranty. Check a twin against
its source before you rely on it.

## See also

- [Other systems: importing and exporting](/docs/user/integrations/index): how the
  translators work, and the guide to each system.
- [Signing in, and what a licence adds](/docs/user/guide/accounts).
- The videos, all on one channel:
  <https://www.youtube.com/@logicalcontracts>.

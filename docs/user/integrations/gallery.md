# The Migration Gallery: nineteen systems, each checked against its own engine

*Kind: gallery · Audience: anyone deciding whether Logical English can read their rules · Status: current (2026-10-26)*

Logical English (LE) is a way to write rules in English that a computer can run. A
*translator* is a program that reads the files of a different system and writes the
same rules in Logical English. The result is called a *twin*. Each twin keeps the
tests of the other system, written as *scenarios*. A scenario is a set of facts,
together with the answers that the other system gives. When you run the scenarios,
you check the twin against the other system.

This page lists the nineteen systems that the translators read. For each system, the
page tells what the twin was checked against, and the result. When the twin can be
published, the **Open** link runs the twin in your browser. You do not need an
account, and you do not have to install software. When the licence of the other
system does not let us publish the twin, the page tells you. Then the video shows the
twin when it runs.

## Contents

- [The Migration Gallery: nineteen systems, each checked against its own engine](#the-migration-gallery-nineteen-systems-each-checked-against-its-own-engine)
  - [Contents](#contents)
  - [The nineteen systems](#the-nineteen-systems)
  - [How to read the results](#how-to-read-the-results)
  - [Try one in two minutes](#try-one-in-two-minutes)
  - [A free twin of your own program](#a-free-twin-of-your-own-program)
  - [See also](#see-also)

## The nineteen systems

"Both ways" means that the editor can also write a Logical English program back in
the format of the other system. *LE for LPS* is Logical English for programs that act
over time, for example contracts. LE for LPS runs in the sister editor, LPS2 (Logic
Production Systems 2).

| System | Direction | Checked against | Result | Twin | Video | Guide |
|---|---|---|---|---|---|---|
| **Axiom RuleSpec** (United States benefit and tax rules) | both ways | the engine of Axiom | 473 of 473. Written back: 37 of 39 programs pass each case on the engine of Axiom. The export refuses the other 2, and gives the reasons | [Open](/editor/index.html?example=migration/rulespec/snap/us_policies_usda_snap_fy_2024_cola_maximum_allotments) | [watch](https://www.youtube.com/watch?v=ZF593VoCCK8) | [guide](/docs/user/integrations/rulespec) |
| **Bitcoin Miniscript** (spending policies) | both ways | a test Bitcoin network | 361 of 361. This number includes payments that the network confirmed | [Open](/editor/index.html?example=migration/miniscript/liana_inheritance/liana_inheritance) | [watch](https://www.youtube.com/watch?v=04Vbk13G7K4) | [guide](/docs/user/integrations/miniscript) |
| **Blawx**, version 1 (rules as code, Canada; not the hosted Blawx 2 and 3) | into LE | the answers of Blawx | 163 of 163, in 15 projects | [Open](/editor/index.html?example=migration/blawx/rps/rps) | [watch](https://www.youtube.com/watch?v=_CdWVsLthhk) | [guide](/docs/user/integrations/blawx) |
| **Catala** (laws as programs, in English and French) | both ways, *preliminary* | the interpreter of Catala | 129 of 129 in 9 programs, 15 more waiting. Written back: 42 of 42 tests pass on Catala | [Open](/editor/index.html?example=migration/catala/smic/smic) (the French minimum wage, in Français Logique) | [watch](https://www.youtube.com/watch?v=GEm6ybIKyWM) | [guide](/docs/user/integrations/catala) |
| **Daml** (contracts on the Canton network) | both ways, as LE for LPS | a Canton sandbox | 18 of 22 scripts end with exactly the active contracts of Daml. The guide explains the other 4 | [Open in LPS2](https://lps2.logicalcontracts.com/ide?example=migration/daml/simple_iou/simple_iou.le) | [watch](https://www.youtube.com/watch?v=9Svirhcghb4) | [guide](https://lps2.logicalcontracts.com/docs/user/integrations/daml) |
| **DMN** (decision models and their FEEL expressions: the OMG standard, and the Dutch STTR profile) | into LE | the expected results of the DMN test kit (TCK) and of the Benefit Decision Toolkit; Apache KIE Drools on generated cases | 138 of 138 (TCK, 28 models). 195 of 195 (Benefit Decision Toolkit of Philadelphia). 346 of 346 (Dutch government examples, RONL) | [Open](/editor/index.html?example=migration/dmn/bdt/homestead_exemption/homestead_exemption) | [watch](https://www.youtube.com/watch?v=CiCwgb599Tk) | [guide](/docs/user/integrations/dmn) |
| **Drools** (business rule files) | into LE and LE for LPS | a real Drools session | 5 of 5 rule bases end with the same working memory as Drools | [Open in LPS2](https://lps2.logicalcontracts.com/ide?example=migration/drools/insurance/insurance.le) | [watch](https://www.youtube.com/watch?v=sdb3BJdb5jE) | [guide](https://lps2.logicalcontracts.com/docs/user/integrations/drools) |
| **Epilog** (the rule language of Stanford) | into LE and LE for LPS | EpilogJS, the engine of Epilog | 17 of 17 rulesets. 70 of 74 games end in the same state as in Epilog | not published: no licence | [watch](https://www.youtube.com/watch?v=hqGWqiyA4So) | [guide](/docs/user/integrations/epilog) |
| **Excel workbooks** (calculators kept in spreadsheets) | into LE | the workbook itself, calculated again | each checked value agrees: 2,588 values in 7 workbooks, 484 more waiting | [Open](/editor/index.html?example=migration/spreadsheet/cms_mlr/cms_mlr) (the United States medical loss ratio form) | [watch](https://www.youtube.com/watch?v=cVKjigqVvlo) | [guide](/docs/user/integrations/spreadsheets) |
| **L4** (legal rules and contracts, Singapore) | into LE and LE for LPS | the evaluator of L4 | 621 of 621 rule answers. 87 of 95 contract runs end at the same point as in L4. The translator did not translate the other 8 | [Open](/editor/index.html?example=migration/l4/british_citizen_act/british_citizen_act) | [watch](https://www.youtube.com/watch?v=Rb0rHYy1Ys8) | [guide](/docs/user/integrations/l4) |
| **LegalRuleML** (the OASIS standard for legal norms) | both ways | SPINdle, a reasoner for the standard | 68 of 68, in the 12 examples of the standard | [Open](/editor/index.html?example=migration/legalruleml/ex5_section29new/ex5_section29new) | [watch](https://www.youtube.com/watch?v=oPdimQmfE4M) | [guide](/docs/user/integrations/legalruleml) |
| **Oracle Insurance Policy Administration (OIPA)** (life and annuity transactions) | into LE | an independent calculator of the formulas of OIPA | 103 of 103 values, in 6 transactions | [Open](/editor/index.html?example=migration/oipa/termlife_grace_check/termlife_grace_check) | [watch](https://www.youtube.com/watch?v=IFxy2gi_BjU) | [guide](/docs/user/integrations/oipa) |
| **Oracle Intelligent Advisor** (rules for public services and insurance) | into LE | the test results of the projects | 475 of 476 test results, in 5 public projects. The one difference is the *unknown* answer of Oracle. When a test gives no answer to a question, Oracle concludes *unknown*. Logical English reads the missing answer as false | not published: the five projects have no licence. Instead, [Open](/editor/index.html?example=regulatory/dfe_funding/dfe_16_19_funding&scenario=full_time&query=OnProgPayment) the full 16 to 19 funding rulebase of England. The Department for Education publishes this rulebase as rule documents. A person wrote it by hand from these documents. It is not a translation. It was checked against an independent second reading, not against the engine of Oracle | [watch](https://www.youtube.com/watch?v=i4qEYqAnvUs) | [guide](/docs/user/integrations/oia) |
| **PolicyEngine and OpenFisca** (tax and benefit models) | both ways, *preliminary* | the engines of the models | 719 of 774 test answers of the models, in 6 models. The ledger of each twin lists the 55 answers that are different. On the model of France: 2,286 of 2,302 income tax cases | not published: the licence of the models would apply to the twins | [watch](https://www.youtube.com/watch?v=WgYGTqR1GJE) | [guide](/docs/user/integrations/openfisca) |
| **Ponens** (policies for the record of the session of an AI agent: ESMA, NIST, IOSCO, MISRA, DO-178C and others) | both ways, as LE for LPS | the evaluator of Ponens | 11,236 of 11,236 verdicts, in all 213 policies of 14 packs and 53 traces. Written back: the same 11,236 | [Open in LPS2](https://lps2.logicalcontracts.com/ide?example=migration/ponens/esma_mifid_ai_investment_services/esma_mifid_ai_investment_services.le) | (not yet on the channel) | [guide](https://lps2.logicalcontracts.com/docs/user/integrations/ponens) |
| **Rune** (the reporting rules of the derivatives industry, from FINOS and ISDA) | both ways | the expected reports of the reporting engine | 99.1% of 102,879 report fields. Written back: 2,197 of 2,249 reports are exactly the same as the reports of the engine | not published: you can share the rules only without changes | (not yet on the channel) | [guide](/docs/user/integrations/rune) |
| **s(CASP) and Prolog** (logic programs) | both ways | s(CASP) itself | 21 of 21, 2 more waiting. Written back: 87 of 93 programs come back without changes | [Open](/editor/index.html?example=migration/scasp/loanwithcure/loanwithcure) | [watch](https://www.youtube.com/watch?v=BI6TJf6TVHk) | [guide](/docs/user/integrations/scasp) |
| **Socotra** (insurance products) | into LE | a reference run of the scripts of Socotra | 992 of 992 expected values that can run, in 17 public products | not published: no licence | [watch](https://www.youtube.com/watch?v=bNIW68EFP2c) | [guide](/docs/user/integrations/socotra) |
| **Solidity** (Ethereum smart contracts) | both ways, as LE for LPS | the Solidity compiler, and a virtual machine that replays 822 real USDC payments | 849 of 849 values agree | [Open in LPS2](https://lps2.logicalcontracts.com/ide?example=migration/solidity/replay/usdc_window.le) | [watch](https://www.youtube.com/watch?v=xksKg0QvW6Y) | [guide](https://lps2.logicalcontracts.com/docs/user/integrations/solidity) |

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
of the National Consumer Credit Protection Act of Australia. Section 29 says that no
one can engage in a credit activity without a licence. It also gives the penalties
for this.

Do these steps:

1. Open the [twin of section 29](/editor/index.html?example=migration/legalruleml/ex5_section29new/ex5_section29new&scenario=unlicensed_trader&query=obligations).
   The link selects the scenario `unlicensed_trader` and the query `obligations` for
   you.
2. Click **Query**. Two answers appear: alice is obliged to pay 200 penalty units,
   and alice is obliged to pay 2000 civil penalty units.
3. Click an answer. The explanation shows the reason: alice engages in a credit
   activity without a credit licence. Thus she breaks the prohibition. The penalty is
   what the Act requires when a person breaks the prohibition.
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

The translators themselves have a licence: refer to
<https://logicalcontracts.com/logical-english-extensions/>. Each twin is given "as
is", without warranty. Check a twin against its source before you rely on it.

## See also

- [Other systems: importing and exporting](/docs/user/integrations/index): how the
  translators work, and the guide to each system.
- [Signing in, and what a licence adds](/docs/user/guide/accounts).
- The videos, all on one channel:
  <https://www.youtube.com/@logicalcontracts>.

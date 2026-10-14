# The Migration Gallery: seventeen systems, each checked against its own engine

*Kind: gallery · Audience: anyone deciding whether Logical English can read their rules · Status: current (2026-10-13)*

Logical English (LE) is a way of writing rules in English that a computer can
run. A *translator* is a program that reads another system's files and writes
the same rules in Logical English. The result is called a *twin*. Each twin
keeps the other system's own tests, written as *scenarios*: sets of facts
with the answers the other system gives. Running the scenarios checks the
twin against the other system.

This page lists the seventeen systems the translators read, what each twin
was checked against, and the result. Where the twin may be published, the
**Open** link runs it in your browser, with no account and nothing to
install. Where it may not, because the other system's licence does not allow
it, the page says so, and the video shows the twin running.

## Contents

- [The seventeen systems](#the-seventeen-systems)
- [How to read the results](#how-to-read-the-results)
- [Try one in two minutes](#try-one-in-two-minutes)
- [A free twin of your own program](#a-free-twin-of-your-own-program)
- [See also](#see-also)

## The seventeen systems

"Both ways" means the editor can also write a Logical English program back
in the other system's own format. *LE for LPS* is Logical English for
programs that act over time, such as contracts; it runs in the sister editor,
LPS2 (Logic Production Systems 2).

| System | Direction | Checked against | Result | Twin | Video | Guide |
|---|---|---|---|---|---|---|
| **Oracle Intelligent Advisor** (rules for public services and insurance) | into LE | the projects' own test results | 475 of 476 test outcomes, over 5 public projects (the one miss is Oracle's *uncertain* answer) | the five twins are not published: the projects carry no licence. Instead, [Open](/editor/index.html?example=regulatory/dfe_funding/dfe_16_19_funding&scenario=full_time&query=OnProgPayment) the whole of England's 16 to 19 funding rulebase, which the Department for Education publishes as rule documents: written by hand from them, not translated, and checked against an independent second reading rather than Oracle's engine | [watch](https://www.youtube.com/watch?v=i4qEYqAnvUs) | [guide](/docs/user/integrations/oia) |
| **Socotra** (insurance products) | into LE | a reference run of Socotra's own scripts | 992 of 992 runnable expectations, over 17 public products | not published: no licence | [watch](https://www.youtube.com/watch?v=bNIW68EFP2c) | [guide](/docs/user/integrations/socotra) |
| **Oracle Insurance Policy Administration (OIPA)** (life and annuity transactions) | into LE | an independent calculator of OIPA's formulas | 103 of 103 values, over 6 transactions | [Open](/editor/index.html?example=migration/oipa/termlife_grace_check/termlife_grace_check) | [watch](https://www.youtube.com/watch?v=IFxy2gi_BjU) | [guide](/docs/user/integrations/oipa) |
| **Excel workbooks** (calculators kept in spreadsheets) | into LE | the workbook itself, recomputed | every value checked agrees: 2,553 values over 7 workbooks | [Open](/editor/index.html?example=migration/spreadsheet/cms_mlr/cms_mlr) (the United States medical loss ratio form) | [watch](https://www.youtube.com/watch?v=cVKjigqVvlo) | [guide](/docs/user/integrations/spreadsheets) |
| **Blawx**, version 1 (rules as code, Canada; not the hosted Blawx 2 and 3) | into LE | Blawx's own answers | 163 of 163, over 15 projects | [Open](/editor/index.html?example=migration/blawx/rps/rps) | [watch](https://www.youtube.com/watch?v=_CdWVsLthhk) | [guide](/docs/user/integrations/blawx) |
| **Axiom RuleSpec** (United States benefit and tax rules) | both ways | Axiom's own engine | 473 of 473; written back, 37 of 39 programs pass every case on Axiom's engine, and the other 2 are refused with reasons | [Open](/editor/index.html?example=migration/rulespec/snap/us_policies_usda_snap_fy_2024_cola_maximum_allotments) | [watch](https://www.youtube.com/watch?v=ZF593VoCCK8) | [guide](/docs/user/integrations/rulespec) |
| **PolicyEngine and OpenFisca** (tax and benefit models) | both ways, *preliminary* | the models' own engines | 99 of 99 checked answers over 6 models; on France's own model, 1,934 of 1,948 income tax cases | not published: the models' licence would extend to the twins | [watch](https://www.youtube.com/watch?v=WgYGTqR1GJE) | [guide](/docs/user/integrations/openfisca) |
| **Catala** (laws as programs, in English and French) | both ways, *preliminary* | Catala's own interpreter | 43 of 43; written back, 38 of 38 tests pass on Catala | [Open](/editor/index.html?example=migration/catala/smic/smic) (the French minimum wage, in Français Logique) | [watch](https://www.youtube.com/watch?v=GEm6ybIKyWM) | [guide](/docs/user/integrations/catala) |
| **L4** (legal rules and contracts, Singapore) | into LE and LE for LPS | L4's own evaluator | 621 of 621 rule answers; 87 of 95 contract runs end where L4's do, the other 8 not translated | [Open](/editor/index.html?example=migration/l4/british_citizen_act/british_citizen_act) | [watch](https://www.youtube.com/watch?v=Rb0rHYy1Ys8) | [guide](/docs/user/integrations/l4) |
| **LegalRuleML** (the OASIS standard for legal norms) | both ways | SPINdle, a reasoner for the standard | 68 of 68, over the standard's 12 examples | [Open](/editor/index.html?example=migration/legalruleml/ex5_section29new/ex5_section29new) | [watch](https://www.youtube.com/watch?v=oPdimQmfE4M) | [guide](/docs/user/integrations/legalruleml) |
| **s(CASP) and Prolog** (logic programs) | both ways | s(CASP) itself | 23 of 23; written back, 87 of 93 programs come back unchanged | [Open](/editor/index.html?example=migration/scasp/loanwithcure/loanwithcure) | [watch](https://www.youtube.com/watch?v=BI6TJf6TVHk) | [guide](/docs/user/integrations/scasp) |
| **Epilog** (Stanford's rule language) | into LE and LE for LPS | EpilogJS, Epilog's own engine | 17 of 17 rulesets; 70 of 74 games end in Epilog's own state | not published: no licence | [watch](https://www.youtube.com/watch?v=hqGWqiyA4So) | [guide](/docs/user/integrations/epilog) |
| **Rune** (the derivatives industry's reporting rules, from FINOS and ISDA) | both ways | the reporting engine's own expected reports | 98.9% of 101,705 report fields; written back, 2,197 of 2,249 reports exactly as the engine gives them | not published: the rules may be shared only unchanged | (not yet on the channel) | [guide](/docs/user/integrations/rune) |
| **Drools** (business rule files) | into LE and LE for LPS | a real Drools session | 5 of 5 rule bases end in Drools' own working memory | [Open in LPS2](https://lps2.logicalcontracts.com/ide?example=migration/drools/insurance/insurance.le) | [watch](https://www.youtube.com/watch?v=sdb3BJdb5jE) | [guide](https://lps2.logicalcontracts.com/docs/user/integrations/drools) |
| **Solidity** (Ethereum smart contracts) | both ways, as LE for LPS | the Solidity compiler and a virtual machine replaying 822 real USDC payments | 849 of 849 values agree | [Open in LPS2](https://lps2.logicalcontracts.com/ide?example=migration/solidity/replay/usdc_window.le) | [watch](https://www.youtube.com/watch?v=xksKg0QvW6Y) | [guide](https://lps2.logicalcontracts.com/docs/user/integrations/solidity) |
| **Daml** (contracts on the Canton network) | both ways, as LE for LPS | a Canton sandbox | 18 of 22 scripts end in exactly Daml's active contracts, the other 4 explained | [Open in LPS2](https://lps2.logicalcontracts.com/ide?example=migration/daml/simple_iou/simple_iou.le) | [watch](https://www.youtube.com/watch?v=9Svirhcghb4) | [guide](https://lps2.logicalcontracts.com/docs/user/integrations/daml) |
| **Bitcoin Miniscript** (spending policies) | both ways | a test Bitcoin network | 361 of 361, including payments confirmed on the network | [Open](/editor/index.html?example=migration/miniscript/liana_inheritance/liana_inheritance) | [watch](https://www.youtube.com/watch?v=04Vbk13G7K4) | [guide](/docs/user/integrations/miniscript) |

## How to read the results

- **"475 of 476"** means: the other system's own tests gave 476 answers, and
  the twin gave the same answer to 475 of them. Each guide says what the
  misses are.
- **"Preliminary"** means: every answer that was checked agrees, but a good
  part of a large real program is still left for a person to translate. The
  translator gives a head start, not yet a finished program.
- **"Written back"** means: the twin, or a program written in Logical English,
  was translated back into the other system's format and run on that
  system's own engine.
- **A refusal is a result too.** When a program says something the other
  system cannot express, the export refuses and names the lines, rather than
  writing something that means something else.
- **What was not translated is kept.** Each twin has a *ledger*: a table with
  one row for each part of the source, saying whether that part was
  translated, approximated (with a note on how its meaning changed), or left
  for a person to translate. Choose **File ▸ Show the Original…** in the
  editor to see the source beside the twin.

## Try one in two minutes

LegalRuleML is the standard of OASIS (a standards body) for writing legal
rules in XML: who is obliged, permitted or forbidden to do what. Its
specification has an example from section 29 of Australia's National
Consumer Credit Protection Act: no one may engage in a credit activity
without a licence, and the penalties for doing so.

1. Open the [twin of section 29](/editor/index.html?example=migration/legalruleml/ex5_section29new/ex5_section29new&scenario=unlicensed_trader&query=obligations).
   The link chooses the scenario `unlicensed_trader` and the query
   `obligations` for you.
2. Click **Query**. There are two answers: alice is obliged to pay 200 penalty
   units, and to pay 2000 civil penalty units.
3. Click an answer. The explanation shows why: alice engages in a credit
   activity without a credit licence, so she breaks the prohibition, and the
   penalty is what the Act requires when the prohibition is broken.
4. Choose the scenario `licensed_trader` and the query `permissions`: bob, who
   holds a licence, is permitted to engage in a credit activity.
5. Choose **File ▸ Show the Original…**: the LegalRuleML document the twin was
   translated from.

## A free twin of your own program

Send us one program, rulebase or spreadsheet of yours, from any of the
systems above. Within five working days you get back its Logical English
twin, its ledger, and a link that runs it in the browser. It is free, and
yours to keep. We publish nothing without your written permission. Write to
<licensing@logicalcontracts.com>, or use the form at
<https://logicalcontracts.com/home/contact-us/>.

The translators themselves are licensed: see
<https://logicalcontracts.com/logical-english-extensions/>. Every twin is
provided "as is", without warranty: check a twin against its source before
relying on it.

## See also

- [Other systems: importing and exporting](/docs/user/integrations/index): how
  the translators work, and the guide to each system.
- [Signing in, and what a licence adds](/docs/user/guide/accounts).
- The videos, all on one channel:
  <https://www.youtube.com/@logicalcontracts>.

# Twins of other systems' programs

A **twin** is a program of another rule system rewritten in Logical English
by a translator, a program that reads the other system's files. Each twin
keeps the original beside it, in its `sources/` folder, and a **migration
ledger**: the record of what each part of the twin was translated from. Its
scenarios (named sets of facts) expect the answers the other system itself
gives, so running them checks the translation.

## Start here
- [Blawx](blawx/) — Acts encoded in Blawx, a visual tool for legal rules.
- [Catala](catala/) — tax and benefit law written in Catala, in English and in French (Français Logique), the rental calculation of the French housing allowance among them.
- [DMN](dmn/) — decision models of the OMG standard: the DMN Technology Compatibility Kit, example models of Dutch government rules (RONL) and Code for Philly's benefit checks for Philadelphia.
- [Epilog](epilog/README.md) — programs of the Epilog site (Stanford University), each twin checked against EpilogJS: the rulesets here, the games among LPS2's examples.
- [L4](l4/) — rules written in L4, a language for legal rules and contracts: the rules here, the contracts among LPS2's examples.
- [LegalRuleML](legalruleml/) — the examples of the OASIS LegalRuleML standard: duties, permissions, prohibitions.
- [Miniscript](miniscript/) — Bitcoin spending policies: who can spend a coin, and when.
- [OIPA](oipa/) — insurance transactions of Oracle Insurance Policy Administration, on two plans we wrote.
- [RuleSpec](rulespec/) — United States food assistance, tax credit and Supplemental Security Income rules from the Axiom Foundation's RuleSpec programs.
- [RUML](ruml/) — the examples of the RUML specification and the fixtures of its tests (the Rulemapping Logic Format, published by Law as Code Institut GmbH); some cite German statutes.
- [s(CASP)](scasp/) — logic programs of the s(CASP) reasoner, including Logical English 1's own.
- [Spreadsheets](spreadsheet/) — calculators kept in Excel workbooks: formulas as rules, the workbook's own values as tests.

## Try this
1. Open [the Rock Paper Scissors Act](blawx/rps/rps.le?scenario=bobjane&query=bobjane) and click **Query**: the answer is "the winner of testgame is jane".
2. Click the answer: the explanation cites section 4 of the Act.
3. Choose **File > Show the Original…**: the Blawx project the twin was translated from.
4. Open [its ledger](blawx/rps/rps.ledger.md) to see what was translated from what.
5. Open any folder above for its own short tour.

## More
- How translation works, for each system: [the integrations guide](/docs/user/integrations/index).
- The twins are written by the translators in the folder `migration/` of this repository (its `README.md` lists them); do not edit them by hand. One correction was made in place, on 24 November 2026, when the translators became open source: the lines of each twin and ledger that name the translator now give its present place, `migration/<system>`.
- The twins in Logical English for LPS (Daml, Drools, Ponens, Solidity, the contracts of L4, the Epilog games) are among LPS2's examples, in its `examples/migration/`.

## Disclaimer
A twin is written by a translator, and it is provided **"as is", without
warranty of any kind**, express or implied, including any warranty that it
is accurate, complete or fit for a particular purpose. A translation may be
wrong: check a twin against its source before relying on it. A twin is not
legal, tax, insurance, financial or other professional advice. Its authors
accept no liability for any loss or damage arising from its use. Every twin
repeats this notice in its opening comment; the translators write it there
themselves (`twin_disclaimer` in `i18n/writer_words.csv`).

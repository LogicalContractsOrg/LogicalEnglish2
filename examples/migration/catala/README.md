# Catala twins

Twelve programs written in Catala, Inria's programming language for laws,
each rewritten in Logical English by a translator. Such a rewrite is a
**twin**. A Catala program keeps the text of the law and its code side by
side; each rule of a twin cites the article it comes from. The French
programs are written in Français Logique (Logical English in French). The
scenarios (named sets of facts) expect the answers that Catala's own
interpreter gives.

## Start here
- [The French minimum wage (SMIC)](smic/smic.le?scenario=Gen1&query=q_brut_horaire) — the hourly wage by date and region, 2019 to 2024, in Français Logique.
- [26 U.S.C. 132, qualified employee discounts](section_132/section_132.le?scenario=TestSection132_1&query=q_qualified_employee_discount) — a section of the United States tax code, in English.
- [The French housing allowance, rental calculation](apl_locatif/apl_locatif.le) — the largest of Catala's examples (`aides_logement`), one calculation of it.

## Try this
1. Open [the minimum wage](smic/smic.le?scenario=Gen1&query=q_brut_horaire) and click **Query**: "le brut horaire est 10,03".
2. Choose **File > Show the Original…**: the Catala file, with the text of the decrees.
3. Open [section 132](section_132/section_132.le?scenario=TestSection132_1&query=q_qualified_employee_discount) and click **Query**: "the qualified employee discount is 500".
4. Open [its ledger](section_132/section_132.ledger.md) to see what was translated from what.

## More
- `section_132/`, `section_121/`: United States tax code. `smic/`: the minimum wage. `bmaf/`: the monthly base of family allowances. `prestations_familiales/`: eligibility for family benefits. `apl_locatif/`, `apl_foyer/`, `apl_accession/`, `al_locatif/`: four calculations of the housing allowance.
- `eligibilite_apl/`, `eligibilite_al/` and `calculette_globale/` (the eligibility for the housing allowance and its whole calculator) do not answer yet: parts of them are still **residue**, Catala text kept in the program for a person to translate. Each ledger says which parts.
- Each twin's migration ledger (`<name>.ledger.md`) says what was translated from what, and which rules are approximations.
- [Catala and Logical English](/docs/user/integrations/catala): how the translation works, and the way back to Catala.
- Catala: https://catala-lang.org and https://github.com/CatalaLang/catala
- The twins are written by the translator in `migration/catala/` of this repository; do not edit them by hand.

## Sources and licences
- The Catala programs come from `catala-examples` (https://github.com/CatalaLang/catala-examples), commit `e67e42414c8bcd2dca450a6a21c94db593fc909b` of 30 June 2026, by the Catala team and its contributors, under the **Apache License 2.0** (the same licence as this repository: `LICENSE` at its root).
- Each `sources/` folder holds the Catala files its twin was read from, **copied without changes**. It is a selection, not the whole example: the files the twin was read from (for the housing allowance, one test file of several, and not the file that joins the others, `Aides_logement.catala_fr`). The files in `sources/cat/` are not Catala's: the translator wrote them (the rules as it read them, and the test cases).
- The texts of law inside the Catala files are public texts of French law (each article's heading carries its Légifrance identifier) and of the United States Code.
- Each twin is a translation, so a changed form of its source: its opening comment names the Catala scopes it was translated from.
- The expected answers were computed in October 2026 with a nightly build of Catala (`1.2.0+git20260822r08832f46b`), not a release.
- Catala is developed by Inria. The twins and their translator are not part of the Catala project.

## Disclaimer
A twin is written by a translator (a program that rewrites another
system's program in Logical English), and it is provided **"as is", without
warranty of any kind**, express or implied, including any warranty that it
is accurate, complete or fit for a particular purpose. A translation may be
wrong: check a twin against its source before relying on it. A twin is not
legal, tax, insurance, financial or other professional advice. Its authors
accept no liability for any loss or damage arising from its use. Every twin
repeats this notice in its opening comment.

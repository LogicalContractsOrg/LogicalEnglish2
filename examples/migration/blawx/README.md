# Blawx twins

Fifteen Acts encoded in Blawx, a visual tool for writing legal rules (the
example projects of Blawx v1.6.22-alpha, by Lexpedite Legal Technologies, MIT
licence: `sources/BLAWX_LICENSE` in each folder), each
rewritten in Logical English by a translator. Such a rewrite is a **twin**:
each rule is a section of the Act in the words of Blawx's own sentence
forms, citing its section. The project's tests, and cases written from its
rules, are the scenarios, and they expect the answers Blawx itself gives.

## Start here
- [Rock Paper Scissors Act](rps/rps.le?scenario=bobjane&query=bobjane) — who wins a game.
- [Beard Tax Act](beard_tax/beard_tax.le?scenario=case_1&query=which_is_bearded) — when a person counts as bearded.
- [Old Age Security Act](oasa/oasa.le) — a Canadian Act, the largest of the set but one.

## Try this
1. Open [the Rock Paper Scissors Act](rps/rps.le?scenario=bobjane&query=bobjane) and click **Query**: "the winner of testgame is jane".
2. Click the answer: the explanation shows the rule of section 4 and the throws that decide it.
3. Put the cursor in a rule and choose **File > View Original Text**: the section of the Act it encodes.
4. Open [the Beard Tax Act on case 1](beard_tax/beard_tax.le?scenario=case_1&query=which_is_bearded): "person_a is bearded".
5. Now open it [on the same case without the fact that person_a is a person](beard_tax/beard_tax.le?scenario=case_1_without_fact_1&query=which_is_bearded): no answer, and the explanation says which condition failed.
6. Open [the Act as a screen](beard_tax/beard_tax.le?view=the%20act&scenario=case_1): the view "the act" in the executive view.

## More
- Each twin's migration ledger (`<id>.ledger.md`, for example [the Rock Paper Scissors one](rps/rps.ledger.md)) says what was translated from what; `sources/` holds the Blawx project and the Act's text.
- [Blawx in Logical English](/docs/user/integrations/blawx): how the translation works.
- Blawx: https://github.com/Lexpedite/blawx (version 1, the open-source release that these examples come from) and https://app.blawx.dev (the hosted service, a later version)
- The twins are written by `migration/blawx/build.pl` of this repository; do not edit them by hand.

## Disclaimer
A twin is written by a translator (a program that rewrites another
system's program in Logical English), and it is provided **"as is", without
warranty of any kind**, express or implied, including any warranty that it
is accurate, complete or fit for a particular purpose. A translation may be
wrong: check a twin against its source before relying on it. A twin is not
legal, tax, insurance, financial or other professional advice. Its authors
accept no liability for any loss or damage arising from its use. Every twin
repeats this notice in its opening comment.

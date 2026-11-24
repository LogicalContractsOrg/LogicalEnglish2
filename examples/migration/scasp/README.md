# s(CASP) twins

Seventeen programs of s(CASP), a reasoner for logic programs with negation
and constraints, rewritten in Logical English by a translator. Such a
rewrite is a **twin**. Thirteen are Logical English 1's own s(CASP)
translations (the sCASP package's `test/le_programs`), four are classics of
its `test/all_programs`. Each scenario expects s(CASP)'s own answer on the
original.

## Start here
- [British citizenship, with trust](citizenshiptrust/citizenshiptrust.le?scenario=alice&query=query_1) — who acquires citizenship, and whose word counts.
- [Birds](birds/birds.le?scenario=the_program&query=query_1) — the classic: birds fly unless they are penguins.
- [A small contract](minicontract/minicontract.le?scenario=one&query=query_1) — when a contract is valid.
- [Turing complete](turingcomplete/turingcomplete.le) — an interpreter written in logic.

## Try this
1. Open [citizenship on the scenario alice](citizenshiptrust/citizenshiptrust.le?scenario=alice&query=query_1) and click **Query**: "John acquires British citizenship on 2021-10-09", through his mother.
2. Open [the scenario harry](citizenshiptrust/citizenshiptrust.le?scenario=harry&query=query_1): the same answer, through his father's settlement.
3. Open [the scenario alice_harry](citizenshiptrust/citizenshiptrust.le?scenario=alice_harry&query=query_1): the father is known because a qualified person says so; click the answer to follow the reasons.
4. Choose **File > Show the Original…**: the s(CASP) program it was translated from.
5. Open [birds](birds/birds.le?scenario=the_program&query=query_1): "tweety can fly".

## More
- [s(CASP) and Prolog in Logical English](/docs/user/integrations/scasp): how the translation works, and the way back.
- s(CASP), by Joaquín Arias and others: https://github.com/SWI-Prolog/sCASP (the version for SWI-Prolog, by Jan Wielemaker, which these twins were checked against) and https://gitlab.software.imdea.org/ciao-lang/sCASP (the original, for Ciao Prolog).
- The originals in each `sources/` folder are copied unchanged from the tests of the s(CASP) package for SWI-Prolog, which is under the Apache License 2.0 (copyright 2019 Joaquin Arias). [MAKING_OF.md](MAKING_OF.md) says where each one came from.
- Each twin's ledger (`<name>.ledger.md`) and `sources/` sit beside it.
- The twins are written by `migration/scasp/build.pl` of this repository; do not edit them by hand.

## Disclaimer
A twin is written by a translator (a program that rewrites another
system's program in Logical English), and it is provided **"as is", without
warranty of any kind**, express or implied, including any warranty that it
is accurate, complete or fit for a particular purpose. A translation may be
wrong: check a twin against its source before relying on it. A twin is not
legal, tax, insurance, financial or other professional advice. Its authors
accept no liability for any loss or damage arising from its use. Every twin
repeats this notice in its opening comment.

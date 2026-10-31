# Epilog twins — every program of the Epilog site, translated and checked

Epilog is the logic programming language of Stanford's Epilog site
(http://epilog.stanford.edu). The Epilog translator of the Logical English
Translators rewrote the programs of that site in Logical English. The
translator is a program: nothing in a twin was written by hand. Such a rewrite
is a **twin**. Each twin keeps its Epilog original in `sources/`, and a
**ledger** that tells what each part of the program became. Every twin was
checked against EpilogJS, the Epilog interpreter of Stanford. A twin is here
only when it gives the same results as EpilogJS.

The Epilog programs, and their twins, are public. EpilogJS is not part of this
repository: its licence allows academic, non-commercial use only. The section
"Checking a new Epilog program", at the end, tells how to use it.

## Two kinds of twin

- **A ruleset** is a set of rules and facts with no actions. A ruleset becomes
  usual Logical English, and its twin is in this folder. The data sheet becomes
  the scenario `dataset`. Each relation that the rules define has a query. Each
  query expects the answers that EpilogJS gives on the same rules and data.
  Click **Query** to run a query.
- **A game, or another program with operations,** changes its data when an
  action occurs. Such a program becomes Logical English for LPS (Logic
  Production System). **These twins need LPS to run.** They are among the
  examples of LPS2, in its `examples/migration/epilog/` folder. Open them in
  the LPS2 IDE (the links below), or in this editor with **Misc ▸ Run in
  LPS**. The scenario `play` is a play that EpilogJS made. The last comment of
  the twin gives the state at the end of that play in EpilogJS. LPS ends the
  play in the same state.

## Start here
- [Kinship](kinship/kinship.le?scenario=dataset&query=gp) — grandparents, ancestors and childless persons. Click **Query**.
- [Tic-tac-toe, in LPS2](https://lps2.logicalcontracts.com/ide?example=migration/epilog/tictactoe/tictactoe.le) — press **Run**. On the timeline, the board fills in move by move.
- [Triples, in LPS2](https://lps2.logicalcontracts.com/ide?example=migration/epilog/triples/triples.le) — one table of students becomes three relations, and then one table again.

## The Examples page

The Examples page (http://epilog.stanford.edu/homepage/examples.php) has 23
items.

### Rulesets with a twin (in this folder; Logical English)

| Program | Queries that give EpilogJS's answers | Notes |
|---|---|---|
| [base](base/base.le) | 1 of 1 | A data sheet with no rules. The query asks for the facts. |
| [blocks](blocks/blocks.le) | 6 of 6 | |
| [graphs](graphs/graphs.le) | 6 of 6 | |
| [kinship](kinship/kinship.le) | 5 of 5 | |
| [mapcoloring](mapcoloring/mapcoloring.le) | 2 of 2 | The site gives no colours: its Sierraplus page lets a visitor choose them. The data sheet of this twin adds a colouring of our own. One sentence (`base(color(R,H))`) is a residue block: it only declares the relation. |
| [metalevel](metalevel/metalevel.le) | 1 of 1 | The site gives no data. The data sheet of this twin is ours. |

### Programs with operations that have a twin (in LPS2; Logical English for LPS)

| Program | The play | Notes |
|---|---|---|
| [triples](https://lps2.logicalcontracts.com/ide?example=migration/epilog/triples/triples.le) | `convert_to_triples`, then `convert_to_tables`, from the site's data sheet | |
| [grapheditor](https://lps2.logicalcontracts.com/ide?example=migration/epilog/grapheditor/grapheditor.le) | `copy(a,e)`, `invert(c)`, `insert(x,b)` | The site gives no data sheet: the graph is ours. `insert` calls itself. The calls deeper than five levels are a residue block, and the ledger marks `insert` *approximated*. |
| buttonsandlights, tictactoe | — | The same programs as the games with the same names. Refer to the Games page below. |

The site has no game rules for these two programs, so EpilogJS cannot choose
their moves. The operations of each play are ours. EpilogJS applies the same
operations to the same data, and the final states agree.

### Programs with no twin

| Program | Why there is no twin |
|---|---|
| boolean, satisfiability, zebra | Their facts and rules hold values made of other values (`and(p,q)`, `h(english,dog,…)`). A Logical English place holds a constant, not such a value. The translator keeps these sentences as residue blocks, so nothing remains to compare with EpilogJS. |
| lists, sets, nlp | They take lists apart (`X!L`), which the translator keeps as residue blocks. Their open queries have no finite answer, in EpilogJS also. |
| cryptarithmetic (the ruleset) | EpilogJS does not answer its open query in the time allowed, so there is nothing to compare. (The game cryptarithmetic of the Games page has a twin.) |
| portico (worksheet) | Partly translated. The four queries that can be checked give EpilogJS's answers. But 24 sentences, among them the zoning rules (`illegal(height)`, `explain(…)`), hold values made of other values, and are residue blocks. |
| schedule (rule sheet and worksheet), gameoflife (worksheet) | Their state holds values made of other values (`select(room(E),R)`, `value(cell(5,3),on)`). The final state of the twin is different from the final state of EpilogJS. |
| solar (worksheet) | It uses the arithmetic relations of Epilog (`plus(X,Y,Z)`, `dcos`), which the translator does not translate, and LPS cannot read one of its conditions. |
| programsheets, pelicanhunters | These pages have no Epilog program to read. Scripts build the program sheets. The Pelican Hunters page was on a different site, and is not there now. |

## The Games page

The Games page (http://epilog.stanford.edu/homepage/games.php) lists 81 games.
The Gamemaster site (http://gamemaster.stanford.edu) lists the same 81 games,
with the same libraries. All the games use the game description language of
the two sites: Epilog with the words `role`, `base`, `action`, `init`,
`legal`, `goal` and `terminal`, and operations for the moves. Every game twin
needs LPS to run.

- **71 games have a twin** (the table below). EpilogJS plays up to 12 legal
  moves by a fixed rule. LPS ends the same play in the same state.
- **7 games are different from EpilogJS, or cannot be checked:**
  - badqueens, badsendmoremoney, badtictactoe: EpilogJS does not finish its
    play in 120 seconds. These are the slow versions of other games, slow by
    design.
  - skirmish, skirmish1: their state holds values made of other values
    (`location(cell(a,1), piece(white,rook,1))`). The final state of the twin
    is different from the final state of EpilogJS.
  - reversum (some colours are the other way round) and ttcc4 (some pieces are
    missing): the final states are different. The reason is not known yet.
- **3 games have no program**: twoplustwo, badtwoplustwo and sendmoremoney.
  Their libraries on the page are empty.

Some twins keep sentences as residue blocks and still agree. Albuquerque,
alquerque and battleofnumbers have views over move terms
(`goodmove(move(U,V,X,Y))`). Sophia and badsophia use `rem` and `quo`, which
they define with `:=`. *Approximated* means that a view uses `symless` or
`symleq`, which the translator removes.

| Game | Moves in the play | Fluents at the end | Notes |
|---|---|---|---|
| [albuquerque](https://lps2.logicalcontracts.com/ide?example=migration/epilog/albuquerque/albuquerque.le) | 12 | 28 | 3 residue blocks |
| [alquerque](https://lps2.logicalcontracts.com/ide?example=migration/epilog/alquerque/alquerque.le) | 12 | 29 | 3 residue blocks |
| [badconnectfour](https://lps2.logicalcontracts.com/ide?example=migration/epilog/badconnectfour/badconnectfour.le) | 12 | 13 |  |
| [badconnectfour2](https://lps2.logicalcontracts.com/ide?example=migration/epilog/badconnectfour2/badconnectfour2.le) | 12 | 13 |  |
| [badqueens6x6](https://lps2.logicalcontracts.com/ide?example=migration/epilog/badqueens6x6/badqueens6x6.le) | 6 | 8 | the game ends after 6 moves |
| [badsophia](https://lps2.logicalcontracts.com/ide?example=migration/epilog/badsophia/badsophia.le) | 1 | 2 | 3 residue blocks; the game ends after 1 move |
| [battleofnumbers](https://lps2.logicalcontracts.com/ide?example=migration/epilog/battleofnumbers/battleofnumbers.le) | 12 | 14 | 5 residue blocks |
| [bestbuttonsandlights](https://lps2.logicalcontracts.com/ide?example=migration/epilog/bestbuttonsandlights/bestbuttonsandlights.le) | 12 | 15 |  |
| [besttictactoe](https://lps2.logicalcontracts.com/ide?example=migration/epilog/besttictactoe/besttictactoe.le) | 12 | 19 |  |
| [breakthrough](https://lps2.logicalcontracts.com/ide?example=migration/epilog/breakthrough/breakthrough.le) | 12 | 33 |  |
| [bridgecrossing](https://lps2.logicalcontracts.com/ide?example=migration/epilog/bridgecrossing/bridgecrossing.le) | 5 | 8 | 2 approximated; the game ends after 5 moves |
| [buttonsandlights](https://lps2.logicalcontracts.com/ide?example=migration/epilog/buttonsandlights/buttonsandlights.le) | 6 | 4 | the game ends after 6 moves |
| [canonicalbuttonsandlights](https://lps2.logicalcontracts.com/ide?example=migration/epilog/canonicalbuttonsandlights/canonicalbuttonsandlights.le) | 6 | 4 | the game ends after 6 moves |
| [cbnk](https://lps2.logicalcontracts.com/ide?example=migration/epilog/cbnk/cbnk.le) | 12 | 27 |  |
| [chinesecheckers1](https://lps2.logicalcontracts.com/ide?example=migration/epilog/chinesecheckers1/chinesecheckers1.le) | 12 | 39 |  |
| [chinesecheckers3](https://lps2.logicalcontracts.com/ide?example=migration/epilog/chinesecheckers3/chinesecheckers3.le) | 12 | 39 |  |
| [chinook](https://lps2.logicalcontracts.com/ide?example=migration/epilog/chinook/chinook.le) | 12 | 36 |  |
| [chinook1](https://lps2.logicalcontracts.com/ide?example=migration/epilog/chinook1/chinook1.le) | 12 | 19 |  |
| [connectfour](https://lps2.logicalcontracts.com/ide?example=migration/epilog/connectfour/connectfour.le) | 12 | 13 |  |
| [cram](https://lps2.logicalcontracts.com/ide?example=migration/epilog/cram/cram.le) | 8 | 17 | the game ends after 8 moves |
| [crusade](https://lps2.logicalcontracts.com/ide?example=migration/epilog/crusade/crusade.le) | 12 | 35 |  |
| [cryptarithmetic](https://lps2.logicalcontracts.com/ide?example=migration/epilog/cryptarithmetic/cryptarithmetic.le) | 8 | 10 | the game ends after 8 moves |
| [donttouch](https://lps2.logicalcontracts.com/ide?example=migration/epilog/donttouch/donttouch.le) | 3 | 17 | the game ends after 3 moves |
| [family](https://lps2.logicalcontracts.com/ide?example=migration/epilog/family/family.le) | 7 | 9 | 2 approximated; the game ends after 7 moves |
| [hamilton](https://lps2.logicalcontracts.com/ide?example=migration/epilog/hamilton/hamilton.le) | 12 | 12 |  |
| [hex](https://lps2.logicalcontracts.com/ide?example=migration/epilog/hex/hex.le) | 12 | 38 |  |
| [hex7x7](https://lps2.logicalcontracts.com/ide?example=migration/epilog/hex7x7/hex7x7.le) | 12 | 38 |  |
| [hexie](https://lps2.logicalcontracts.com/ide?example=migration/epilog/hexie/hexie.le) | 12 | 38 |  |
| [hexlite](https://lps2.logicalcontracts.com/ide?example=migration/epilog/hexlite/hexlite.le) | 12 | 38 |  |
| [hunter](https://lps2.logicalcontracts.com/ide?example=migration/epilog/hunter/hunter.le) | 12 | 18 |  |
| [jealousy](https://lps2.logicalcontracts.com/ide?example=migration/epilog/jealousy/jealousy.le) | 1 | 9 | 2 approximated; the game ends after 1 move |
| [knights](https://lps2.logicalcontracts.com/ide?example=migration/epilog/knights/knights.le) | 12 | 21 |  |
| [knightstour](https://lps2.logicalcontracts.com/ide?example=migration/epilog/knightstour/knightstour.le) | 3 | 6 | the game ends after 3 moves |
| [knightthrough](https://lps2.logicalcontracts.com/ide?example=migration/epilog/knightthrough/knightthrough.le) | 12 | 33 |  |
| [knightthroughsmall](https://lps2.logicalcontracts.com/ide?example=migration/epilog/knightthroughsmall/knightthroughsmall.le) | 10 | 22 | the game ends after 10 moves |
| [kono](https://lps2.logicalcontracts.com/ide?example=migration/epilog/kono/kono.le) | 12 | 20 |  |
| [leafymcfairface](https://lps2.logicalcontracts.com/ide?example=migration/epilog/leafymcfairface/leafymcfairface.le) | 12 | 91 |  |
| [leafymcfallface](https://lps2.logicalcontracts.com/ide?example=migration/epilog/leafymcfallface/leafymcfallface.le) | 12 | 38 |  |
| [lightboard](https://lps2.logicalcontracts.com/ide?example=migration/epilog/lightboard/lightboard.le) | 12 | 13 |  |
| [lines](https://lps2.logicalcontracts.com/ide?example=migration/epilog/lines/lines.le) | 12 | 73 |  |
| [majorities](https://lps2.logicalcontracts.com/ide?example=migration/epilog/majorities/majorities.le) | 12 | 73 |  |
| [minorities](https://lps2.logicalcontracts.com/ide?example=migration/epilog/minorities/minorities.le) | 12 | 73 |  |
| [missionaries](https://lps2.logicalcontracts.com/ide?example=migration/epilog/missionaries/missionaries.le) | 4 | 9 | 2 approximated; the game ends after 4 moves |
| [multiplebuttonsandlights](https://lps2.logicalcontracts.com/ide?example=migration/epilog/multiplebuttonsandlights/multiplebuttonsandlights.le) | 12 | 15 |  |
| [multiplehunter](https://lps2.logicalcontracts.com/ide?example=migration/epilog/multiplehunter/multiplehunter.le) | 12 | 50 |  |
| [multipleknightthrough](https://lps2.logicalcontracts.com/ide?example=migration/epilog/multipleknightthrough/multipleknightthrough.le) | 12 | 48 |  |
| [multipletictactoe](https://lps2.logicalcontracts.com/ide?example=migration/epilog/multipletictactoe/multipletictactoe.le) | 12 | 87 |  |
| [nineboardtictactoe](https://lps2.logicalcontracts.com/ide?example=migration/epilog/nineboardtictactoe/nineboardtictactoe.le) | 12 | 83 |  |
| [ornatebuttonsandlights](https://lps2.logicalcontracts.com/ide?example=migration/epilog/ornatebuttonsandlights/ornatebuttonsandlights.le) | 6 | 4 | the game ends after 6 moves |
| [ornatechinook1](https://lps2.logicalcontracts.com/ide?example=migration/epilog/ornatechinook1/ornatechinook1.le) | 12 | 39 |  |
| [parallelbuttonsandlights](https://lps2.logicalcontracts.com/ide?example=migration/epilog/parallelbuttonsandlights/parallelbuttonsandlights.le) | 12 | 3 |  |
| [parallelhunter](https://lps2.logicalcontracts.com/ide?example=migration/epilog/parallelhunter/parallelhunter.le) | 12 | 34 |  |
| [parallelknightthrough](https://lps2.logicalcontracts.com/ide?example=migration/epilog/parallelknightthrough/parallelknightthrough.le) | 12 | 38 |  |
| [pentago](https://lps2.logicalcontracts.com/ide?example=migration/epilog/pentago/pentago.le) | 12 | 8 |  |
| [pentagosuicide](https://lps2.logicalcontracts.com/ide?example=migration/epilog/pentagosuicide/pentagosuicide.le) | 12 | 8 |  |
| [queens](https://lps2.logicalcontracts.com/ide?example=migration/epilog/queens/queens.le) | 8 | 10 | the game ends after 8 moves |
| [queens6x6](https://lps2.logicalcontracts.com/ide?example=migration/epilog/queens6x6/queens6x6.le) | 6 | 8 | the game ends after 6 moves |
| [rainbow](https://lps2.logicalcontracts.com/ide?example=migration/epilog/rainbow/rainbow.le) | 6 | 7 | the game ends after 6 moves |
| [redundantbuttonsandlights](https://lps2.logicalcontracts.com/ide?example=migration/epilog/redundantbuttonsandlights/redundantbuttonsandlights.le) | 6 | 4 | the game ends after 6 moves |
| [soldiers](https://lps2.logicalcontracts.com/ide?example=migration/epilog/soldiers/soldiers.le) | 12 | 8 |  |
| [sophia](https://lps2.logicalcontracts.com/ide?example=migration/epilog/sophia/sophia.le) | 1 | 2 | 3 residue blocks; the game ends after 1 move |
| [sukoshi](https://lps2.logicalcontracts.com/ide?example=migration/epilog/sukoshi/sukoshi.le) | 5 | 10 | the game ends after 5 moves |
| [switches](https://lps2.logicalcontracts.com/ide?example=migration/epilog/switches/switches.le) | 12 | 13 |  |
| [tictactoe](https://lps2.logicalcontracts.com/ide?example=migration/epilog/tictactoe/tictactoe.le) | 7 | 10 | the game ends after 7 moves |
| [tictactoe3](https://lps2.logicalcontracts.com/ide?example=migration/epilog/tictactoe3/tictactoe3.le) | 2 | 10 | the game ends after 2 moves |
| [tictactoe4x4](https://lps2.logicalcontracts.com/ide?example=migration/epilog/tictactoe4x4/tictactoe4x4.le) | 12 | 17 |  |
| [tictactoe5](https://lps2.logicalcontracts.com/ide?example=migration/epilog/tictactoe5/tictactoe5.le) | 5 | 10 | the game ends after 5 moves |
| [tictactoe7](https://lps2.logicalcontracts.com/ide?example=migration/epilog/tictactoe7/tictactoe7.le) | 4 | 10 | the game ends after 4 moves |
| [trifecta](https://lps2.logicalcontracts.com/ide?example=migration/epilog/trifecta/trifecta.le) | 7 | 10 | the game ends after 7 moves |
| [ttt1p](https://lps2.logicalcontracts.com/ide?example=migration/epilog/ttt1p/ttt1p.le) | 9 | 11 | the game ends after 9 moves |
| [ttt3tp](https://lps2.logicalcontracts.com/ide?example=migration/epilog/ttt3tp/ttt3tp.le) | 2 | 10 | the game ends after 2 moves |

## Checking a new Epilog program

The translator is part of the Logical English Translators licence. A holder of
that licence can translate any Epilog program with **File ▸ Open…**. A program
opened in this way is not checked. To check a new program against EpilogJS, do
these steps.

**First, the licence of EpilogJS.** EpilogJS belongs to Stanford University.
Its licence allows non-profit institutions to use it for non-commercial
purposes only. It does not allow you to give copies to other persons. Use
EpilogJS only as its licence allows. For a commercial use, get a commercial
licence from Stanford first.

1. Get the lpsPlus repository, which holds the translator in
   `migration/epilog/`. Also get a checkout of LE2 (this repository) and a
   checkout of LPS2. Put the three folders side by side, or set `LE2_DIR` and
   `LPS2_DIR` to the LE2 and LPS2 folders.
2. Install SWI-Prolog and Node.js.
3. Get EpilogJS. Either run `migration/epilog/fetch_sources.sh` (it also gets
   the texts of the Epilog site), or download
   http://epilog.stanford.edu/javascript/epilog.js into
   `migration/epilog/.cache/epilog.js`. You can also set `EPILOG_JS` to the
   file.
4. Run the check:

   ```sh
   # a ruleset: its rule sheet, and its data sheet if it has one
   swipl lpsPlus/migration/epilog/validate.pl -- ruleset myrules.epilog mydata.epilog
   # a data sheet with no rules
   swipl lpsPlus/migration/epilog/validate.pl -- ruleset none mydata.epilog
   # a game library: EpilogJS plays 12 moves (change the number with --moves N)
   swipl lpsPlus/migration/epilog/validate.pl -- game mygame.hrf
   # operations with no game rules: the data, then the operations in turn
   swipl lpsPlus/migration/epilog/validate.pl -- program myprogram.epilog mydata.epilog "invert(c)" "copy(a,e)"
   ```

5. Read the last line. `AGREES with EpilogJS` means that the twin gives the
   same answers as EpilogJS, or ends in the same state. `DIFFERS from
   EpilogJS` lists what is different. `NOT CHECKED` means that nothing was left
   to compare, for example when every query is in a residue block.
6. The twin is in `epilog-twins/<name>/` (change the folder with `--out DIR`).
   Open its ledger, `<name>.ledger.md`, to see what was translated, what was
   approximated and what is residue.

A twin that agrees on one play is not proved correct for every play. For a
game that you depend on, check more than one play (`--moves N`, or `program`
with operations of your own).

## More
- How Epilog maps to Logical English: [the Epilog guide](/docs/user/integrations/epilog).
- The Epilog translator of `lpsPlus/migration/epilog` (not public) writes these twins: its `build.pl` writes this folder and the folder of LPS2. Do not edit them by hand.
- **Disclaimer.** A twin is written by a translator, and it is provided "as is", without warranty of any kind, express or implied, including any warranty that it is accurate, complete or fit for a particular purpose. A translation may be wrong: check a twin against its source before relying on it. A twin is not legal, tax, insurance, financial or other professional advice. Its authors accept no liability for any loss or damage arising from its use.

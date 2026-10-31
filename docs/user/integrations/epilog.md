# Epilog and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-31)*

Epilog is the logic programming language of the Stanford course on Dynamic Logic
Programming. The course teaches Epilog with the Epilog web site and with EpilogJS.
EpilogJS runs Epilog programs inside a web browser. An Epilog program keeps three
things separate:

- The *data* are the facts.
- The *view definitions* are rules, for example
  `gp(X,Z) :- parent(X,Y) & parent(Y,Z)`.
- The *operation definitions* tell what an action changes, for example
  `mark(M,N) :: control(R) ==> cell(M,N,R) & ~cell(M,N,b)`. The meaning is: when
  the action occurs, change the data in this way.

The translation goes in one direction only, into Logical English. A ruleset is a file
of rules with no actions. A ruleset becomes a usual Logical English program. Some
programs have operations, for example the games on the Epilog Games page. Such a
program becomes a program in Logical English for LPS (Logic Production System). LPS
runs a program forward through time. To open the Epilog file, select **File ▸
Open…** or **File ▸ Import from Another System…**. Nothing writes an Epilog file back
out. The translator is a part of the Logical English Translators. Thus only the
installations that have the translators give this function. The hosted service is
one of these installations. To run a translated game, you also need an LPS2 server
next to the editor.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [Opening a ruleset](#opening-a-ruleset)
  - [Opening a game](#opening-a-game)
  - [The example twins](#the-example-twins)
- [How Epilog maps to Logical English](#how-epilog-maps-to-logical-english)
  - [Rulesets](#rulesets)
  - [Games and other programs with operations](#games-and-other-programs-with-operations)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| Epilog ruleset → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | `.epilog`, `.epi`, `.txt` (rules, and facts if you want) | the views as rules, a query for each view, a ledger | the answers of EpilogJS to the query of each view (example twins) |
| Epilog game or program with operations → Logical English for LPS | the same | `.hrf` (a game library of the Games page), `.epilog`, `.epi`, `.txt` | actions, causal laws, intensional fluents, the initial state, legality as constraints, a ledger | the final state of EpilogJS after a recorded play (example twins) |
| Logical English → Epilog | none | — | — | — |

## How to use it

### Opening a ruleset

Do these steps:

1. Save the rules as a text file with a name that ends in `.epilog` (or `.epi`, or
   `.txt`). A rule sheet that you copy directly from the Epilog site is correct as
   it is.
2. If you also want the data, put the facts from the data sheet in the same file.
   The editor reads only one file.
3. Select **File ▸ Open…** (or **File ▸ Import from Another System…**).
4. Select the file. The program opens in a new tab.
5. Read the note below the menu bar. The note gives the name of the translator and
   the counts from the ledger.
6. Close the note with its `×`.

The ledger is the record of how the translator translated each part of the file. An
example of the note is *kinship: an Epilog ruleset, as Logical English (6 elements
encoded, 0 approximated, 0 residue), with a query per view.*

The program has one query for each view
(`query gp is: which thing is the gp of which second thing.`). Select a query and run
it. The facts in the file are facts of the program.

**File ▸ Show the Original…** shows the Epilog file. The editor keeps the Epilog file
in the `sources/` folder of the program. The editor writes the ledger,
`<name>.ledger.md`, next to the program.

A file that you open in this way has no expected answers. The reason is that nothing
in the editor runs EpilogJS. If you know the correct answers, write them into a
scenario with `expects answers`. (A scenario is a set of facts about one case.) Then
select **Misc ▸ Run the Program's Tests…**.

### Opening a game

Do these steps:

1. Save the library of the game as a `.hrf` file. The library is the text of a game
   on the Epilog Games page.
2. Select **File ▸ Open…**, and open that file.

The new program declares `the target language is: lps.`. The editor does not show
the query buttons now. It shows **Run in LPS** and **Legal View**.

The note tells how many parts of the game the translator encoded, approximated and
kept as residue. The note also tells that the program has no scenario at this time.
Add a scenario: a sequence of moves, with one move for each step of time:

```le
   scenario play is:
       the move mark with 1 and 1 is made from 1 to 2.
       the move mark with 3 and 3 is made from 2 to 3.
```

The words of a move are the words of its action declaration
(`the move mark with *an index* and *a second index* is made`).

**Run in LPS** runs the program with the LPS2 engine, in a new window. The timeline
in that window shows the moves. It also shows each fluent as time passes. A fluent is
a fact that changes over time. LPS refuses a move that is not legal. The timeline
marks that move *refused by a constraint*.

A program that opens without a play says `the maximum time is 20.` For a longer play,
make that number larger.

The LPS2 IDE is the integrated development environment, or editor, for LPS. Its
**Open…** item reads the same `.epilog`, `.epi` and `.hrf` files. This is true only
when the Logical English installation next to that editor has the translators.

### The example twins

The translator translated every program of the Epilog site. The translations are
the *twins*. Each twin was checked against EpilogJS. A twin is published only when
it gives the same results as EpilogJS. The Epilog programs and their twins are
public. To open a twin, select **File ▸ Open example from server…**.

- The rulesets are in `migration/epilog/` (6 twins: `base`, `blocks`, `graphs`,
  `kinship`, `mapcoloring`, `metalevel`). In each of these twins, the data sheet
  became the scenario `dataset`. The query of each view expects the answers that
  EpilogJS gives on the same rules and the same data. **Misc ▸ Run the Program's
  Tests…** shows that all the answers pass.
- The games, and two programs with operations (`triples`, `grapheditor`), need
  LPS. Their twins are among the examples of LPS2, in its `migration/epilog/`
  folder: 71 games of the Games page, for example
  [tic-tac-toe](https://lps2.logicalcontracts.com/ide?example=migration/epilog/tictactoe/tictactoe.le).
  The scenario `play` contains a play that EpilogJS made. The comment immediately
  before the scenario gives the final state of EpilogJS. When you run the twin in
  LPS, it finishes in the same state.

[The README of the Epilog examples](/?dir=migration/epilog) lists
every program of the Epilog site: which programs have a twin, which programs need
LPS, which programs are different from EpilogJS, and why. It also tells how to
check a new Epilog program against EpilogJS.

On a twin, **File ▸ Show the Original…** shows a list with the rule sheet and the
data sheet (`.rules`, `.data`). For a game, the list has the game library (`.hrf`)
and the record of the play by EpilogJS (`<name>.epilog.json`). The record contains
the state and the legal moves after each move.

## How Epilog maps to Logical English

### Rulesets

| Epilog | Logical English |
|---|---|
| a fact `parent(art,bob)` | a fact, `art is the parent of bob.` (in a twin, in the scenario `dataset`) |
| a view definition `h :- b1 & b2` | a rule, `… if … and …` |
| `~p(X)` | `it is not the case that …` |
| `b1 \| b2` | `either … or …` |
| a relation name | a template with words from the name: `*a thing* is the gp of *a second thing*` |
| a relation with one argument that gives the type of a slot (`node(X)`) | the name of the slot: `*a node* is the p of *a second node*` |
| `same`, `distinct`, `leq`, `less` | `=`, `\=`, `=<`, `<` |
| `evaluate(plus(X,times(Y,2)),Z)` | `Z = X + Y * 2` (`plus`, `times`, `minus`, `quotient`) |
| `mutex(X1,…,Xn)` | each pair of values is different |
| `countofall(X, p(X) & q(X), N)` | an aggregate: the number of each X such that … |
| `max(A,B)`, `min(A,B)` in an evaluation | two rules, one for `A >= B` and one for `A < B` |
| `symless`, `symleq` | removed; the ledger marks the view *approximated* |
| a sentence with a functional term, a function definition `f(X) := …`, or a list pattern | a residue block (refer to [Traps](#traps)) |
| each view | a query `which thing is …` |

(A template is the pattern of a sentence, with slots for the values.) This is part of
the kinship twin:

```le
a thing is childless if
    the thing is a person
    and it is not the case that the thing is isparent.

query childless is:
    which thing is childless.
```

The `~` of Epilog and the `it is not the case that` of Logical English have the same
meaning. The condition is true when the rules and the data cannot prove the fact.
Both languages need rules in layers, where each layer only negates a lower layer.
Thus a view and the rule that it becomes give the same answers on the same data.

### Games and other programs with operations

The editor reads a file as a game when the file contains one or more operation
definitions (`… :: … ==> …`). The editor reads a file with no operation definition as
a ruleset.

The games of the Epilog site and of the Gamemaster site
(http://gamemaster.stanford.edu, the same 81 games) use one game description
language: Epilog with the words `role`, `base`, `action`, `init`, `legal`, `goal`
and `terminal`, and operations for the moves. The translator reads this language.
The older Game Description Language of general game playing describes the next
state with `next`, `true` and `does` instead of operations. The translator does not
read that form as a game (see [Traps](#traps)).

| Epilog | Logical English for LPS |
|---|---|
| a relation that `init` sets or an operation changes (`cell`, `control`) | a fluent |
| a move: an operation that no other operation calls, or that `action(…)` declares | an action, in the words of a move: `the move mark with *an index* and *a second index* is made; known as mark.` |
| `init(…)` | `initially …`, after calculation: `initially 1 cell 1 with b and … and x is a control.` |
| `a :: cond ==> e & ~f` | a causal law, one for each operation rule: `when … is made and cond then e and it is not the case that f.` |
| an operation that a move calls (`tick(X)`) | put inside the move: its conditions and effects become part of the law of the move |
| a view over the state (`line`, `open`, `goal`, `terminal`) | an intensional fluent, `… at a time if … at the time` |
| a view over relations that do not change (`index`, `succ`) | a template with no time, with its facts and rules |
| `legal(mark(M,N)) :- …` | an intensional fluent for each move, `the move mark with *an index* and *a second index* is legal`, and a constraint that refuses a move that is not legal |
| `goal(R, N)` | `the goal of *a role* is *a number*` |
| `terminal` | `the game is terminal` |
| `max(A,B)`, `min(A,B)` in the arithmetic of an operation or a view | two cases, one for `A >= B` and one for `A < B` |
| `role(R)`, `base(…)`, `action(…)` | no separate sentence: they give the types of the slots of the fluents and moves |

An intensional fluent is a fluent that rules calculate from other fluents. A causal
law tells how an event changes the fluents. This part of the tic-tac-toe twin shows
the three operation rules of `mark` and the constraint that keeps a move legal:

```le
when the move mark with an index and a second index is made
    and x is a control
then o is a control
    and it is not the case that x is a control.

it must not be true that
    the move mark with an index and a second index is made
    and it is not the case that the move mark with the index and the second index is legal.
```

A causal law reads its conditions in the state before the move. Epilog reads them in
the same way. Epilog deletes before it adds. Thus, when one operation deletes and
adds the same fluent, the fluent is still true after the move. LPS gives the same
result.

A game manager refuses a move that is not legal. The translated program also does
this: the constraint stops the move fully. Legality is not a goal of the program.
Also, the program does not select the moves. Each move comes from the scenario.

The Games page has 81 games, and 78 of them have a library. EpilogJS plays 75 of
these games within 120 seconds. Of these 75 games, 71 finish under LPS2 in the same
state as in EpilogJS after the same play.

## Traps

- **The words are simple.** The translator makes each template from the name of the
  relation, not from English. Thus `isparent(X)` becomes `*a thing* is isparent`,
  and `cell(M,N,Z)` becomes `*an index* cell *a second index* with *a thing*`. The
  words follow the order of the arguments. Thus a sentence can come out backwards:
  `value(p,true)` becomes `p is the value of true`. Change the names of the
  templates before you show the program to other persons. You can do this yourself
  or with help from the assistants.
- **A file that you open has no expected answers.** Only the example twins were
  compared with EpilogJS. After you open your own ruleset, compare some of its
  answers with the answers of Epilog. Do this before you trust the program.
- **One file only.** You cannot open rules in one file and data in a different file
  together. Put the facts in the file that contains the rules. Sometimes a file
  contains only facts, with no `:-` and no `::`. The editor does not recognise such a
  file as Epilog. The file opens as a program, and its text is inside a `TODO`
  comment.
- **A line that ends with a full stop** makes the file look like Prolog. The Epilog
  translator then does not translate the file. Epilog itself writes no full stops.
- **A game opens without a play.** You must write the scenario yourself.
  `the maximum time is 20.` sets the maximum length of the play.
- **The final state is not a checked expectation.** In a game twin, the final state
  is a comment. Compare that comment with the last state of the run yourself.
  **Misc ▸ Run the Program's Tests…** does not compare them for you.
- **A value made of parts stays as residue.** A slot in a Logical English sentence
  contains a plain constant. It cannot contain a value made of other values, for
  example `and(p,q)`, `not(X)` or `location(cell(a,1), piece(white,rook,1))`. The
  translator writes each sentence that contains such a value as a
  `% RESIDUE functional_term_… BEGIN … END` block. The block keeps the Epilog
  sentence inside it. The ledger and the note count the sentence as *residue*.
  Sometimes only such sentences state a relation. That relation keeps its template
  and its query, but the query finds nothing until a person translates the block.
  The rulesets with the names boolean, satisfiability, schedule and zebra become
  mostly residue. Games that keep such values in their state, for example skirmish,
  also become mostly residue.
- **Functions.** A function definition (`f(X) := …`) becomes a residue block. Each
  sentence where `evaluate(…)` calls that function also becomes a residue block. This
  is also true when `evaluate(…)` calls an Epilog function that is not `plus`,
  `times`, `minus`, `quotient`, `max` or `min`.
- **Lists.** A clause that takes a list apart (`mem(X,X!Y)`) becomes a residue block
  that contains the Epilog clause. The ledger counts it. Some relations have no end,
  for example the lists or the sets. An open query over such a relation has no finite
  answer.
- **`symless` and `symleq` are removed**, in rulesets and also in games. Epilog uses
  them to give a pair only one time. The translated program gives the pair in the
  two orders. The ledger marks each view that used them *approximated*.
- **Symbols that are also Logical English words.** In a game, a constant such as `a`
  becomes the text `"a"`. Examples of such a constant are a column of a board, or one
  of the persons in Bridge crossing. Thus Logical English does not read the constant
  as the article *a*. Write such a constant in the same way in your own scenario:
  `the move right with "a" is made from 1 to 2.`
- **One name with two numbers of arguments.** Sometimes a relation has one argument
  in one place and two arguments in a different place. Such a relation becomes two
  separate templates. LPS knows them as `left_1` and `left_2`.
- **An operation that calls a different operation** gets the conditions and effects
  of the called operation inside it. This occurs to a maximum depth of five.
  Sometimes the chain of operations in a move is deeper than five, or an operation
  calls itself. Then the effects below that depth get no law. The program then
  contains a residue block with the names of the applicable operations. The ledger
  marks the move *approximated*.
- **The older Game Description Language.** A game that uses `next(…)`,
  `true(…)` and `does(…)` and has no operations opens as a ruleset: `next`, `true`
  and `does` become usual relations, with no time. Write the moves as operations
  (`a :: cond ==> e & ~f`), as the games of the Epilog site do.
- **Rules with no variables**
  (`reflexive if it is not the case that nonreflexive.`) are correct for Epilog. But
  the verifier gives a warning about each of them.
- **Differences found on the Games page.** Two games, reversum and ttcc4, finish in
  a state that is different from the final state of EpilogJS. At this time, nobody
  knows the reason. Games with a state that contains values made of other values,
  for example skirmish, are fully out of range.

## See also

- In this documentation:
  - [Other systems: importing and exporting](index.md): [opening the file of a different system](index.md#opening-another-systems-file), [what could not be translated](index.md#what-could-not-be-translated), [Show the Original](index.md#show-the-original), [the migration twins](index.md#the-migration-twins-among-the-examples)
  - [Logical English for LPS](../reference/lps-target.md)
  - [The editor: advanced features](../guide/editor.md#advanced-features) (Run in LPS, Legal View)
  - [The Contract Assistant](../guide/assistants.md#the-contract-assistant). Its migration residue mode translates residue blocks
  - [Logical operators](../reference/language.md#4-logical-operators) and [aggregates](../reference/language.md#5-aggregates) in the language reference
- In LPS2:
  - [Logical English for LPS, the surface language](https://lps2.logicalcontracts.com/docs/user/reference/le-for-lps): [intensional fluents](https://lps2.logicalcontracts.com/docs/user/reference/le-for-lps#36-intensional-fluents-and-composite-events), [`initially`](https://lps2.logicalcontracts.com/docs/user/reference/le-for-lps#32-initially)
  - [The LPS2 IDE](https://lps2.logicalcontracts.com/docs/user/guide/ide): the timeline, and how to run a program
  - [LPS glossary](https://lps2.logicalcontracts.com/docs/user/reference/glossary)
- The documentation of Epilog itself:
  - [Epilog](http://epilog.stanford.edu/homepage/index.php), the site of the language
  - [Examples](http://epilog.stanford.edu/homepage/examples.php) and [Games](http://epilog.stanford.edu/homepage/games.php)
  - [Vocabulary](http://epilog.stanford.edu/homepage/vocabulary.php): the predefined relations and functions
  - [Sierra](http://epilog.stanford.edu/homepage/sierra.php), the Epilog IDE, and [EpilogJS](http://epilog.stanford.edu/homepage/epilogjs.php)

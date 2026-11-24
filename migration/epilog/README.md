# Epilog → Logical English (Phase 2d)

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

The translator of the design notes roadmap.md §5.7 / §8 Phase 2d: Epilog
programs (Stanford's Dynamic Logic Programming language, Genesereth; the
language of the Epilog site, http://epilog.stanford.edu, and of its
interpreter EpilogJS) as Logical English. It is deterministic: the same
Epilog text always gives the same twin, and no twin is edited by hand.

Epilog separates **data** (facts), **view definitions** (`h :- b1 & ~b2`,
stratified, negation as failure) and **operation definitions**
(`a :: cond ==> e1 & ~e2`: when the action happens and the condition holds
in the current state, delete `e2` and add `e1`). Views are LE's timeless
rules; operations are what LE for LPS has causal laws for. So a program is
translated two ways:

| Epilog program | Twin | Test |
|---|---|---|
| a ruleset + a dataset (Examples page) | timeless LE: the views as rules, the dataset as a scenario, a query per view (per data relation, for a dataset with no rules) | the twin passes **EpilogJS's** answers to every view's open query (`runTestsFor`) |
| a game (Games page) | LE for LPS: moves as actions, operations as causal laws, views over the state as intensional fluents, `init` as the initial state | a play EpilogJS made (legal moves, reproducibly chosen) is the scenario; **LPS2's final state** (`lps state`) must be EpilogJS's |
| a program with operations and no game rules (Examples page: triples, grapheditor) | LE for LPS, as a game; the initial state is the data sheet | operations we choose, applied by EpilogJS to the data sheet, are the scenario; LPS2's final state must be EpilogJS's |

The expected answers and final states are always EpilogJS's — the source's
own interpreter — never the LE program's.

**The twins are public** (the Epilog site's texts were cleared for
publication in October 2026; see Licence findings): the rulesets' twins are
in LE2's `examples/migration/epilog/`, the games' and programs' in LPS2's
(`le2_paths.pl`, `epilog_twin:twin_dir/4`). The README of LE2's
`examples/migration/epilog/` is the catalogue: every program of the site,
its outcome, and how to check a new Epilog program.

## How the reader was built

No grammar of Epilog was used: the site publishes none. Its Vocabulary page
lists the predefined relations and functions, and a few operators (`:-` as
`rule(…)`, `==>` as `transition(…)`, `:=` as `definition(…)`), and refers to
the course book (*Logic Programming*, Genesereth and Chaudhri) for the
syntax. The reader was written from three things:

1. **The Epilog texts themselves**: the rule sheets, data sheets, worksheet
   programs and game libraries of the site (113 texts in October 2026).
2. **EpilogJS's own parser, as the reference.** The first version of the
   translator did not parse Epilog at all: `epilog_reader.pl` runs
   EpilogJS's `readdata` (through `tools/epilog_tool.cjs parse`) and turns
   its JSON into Prolog terms. `epilog_syntax.pl` was then written so that
   File ▸ Open needs no EpilogJS (whose licence forbids shipping it), and
   it is held to EpilogJS's reading: the test `reads_as_epilogjs`
   (test_epilog.pl) parses every text fetched from the site with both, and
   requires the same sentences with the same variables: 113 of 113 agree. Two of its choices copy what
   EpilogJS was observed to do: a sentence ends where two terms meet with
   no operator between them (Epilog writes no full stop), and `a | b` is
   `or(a, b)`. In October 2026 the Solar System worksheet showed two gaps,
   now fixed: a decimal such as `1.5` never tokenized (a string where a code
   list was meant), and EpilogJS reads `.6` as a number.
3. **Prolog's own reader** does the rest: the tokens of one sentence are
   joined and read by `term_string/3` with Epilog's operators declared
   (`:-`, `::`, `==>`, `&`, `~`, `!`, `|`, `:=`).

So the reader is inductive — written from the texts and checked against
EpilogJS's parse, not derived from EpilogJS's source code or a grammar. A
construct that no text of the site uses could be read differently; the
agreement test is what to extend when a new text is added.

## GDL: the game vocabulary

The games of the Epilog Games page and of the Gamemaster site
(http://gamemaster.stanford.edu: the same 81 games, with byte-identical
libraries — checked on three) are written in one game description language:
Epilog plus the words `role`, `base`, `action`, `init`, `legal`, `goal`,
`terminal`, with the moves as Epilog operations (`mark(M,N) :: control(R)
==> cell(M,N,R) & ~cell(M,N,b)`). The translator understands that
vocabulary (decisions below, "GDL relations"): all 78 non-empty libraries
of the Games page are read and translated, and 71 of the 75 that EpilogJS
plays in 120 seconds end in EpilogJS's state. Of the vocabulary, `input`
and `sees` are used by no game of the site and have no mapping.

The older Game Description Language of general game playing (the
Stanford GGP of 2005–2008) describes the next state with `next(F) :-
true(G) & does(R, A)` instead of operations. **That form is not read as a
game**: with no operation in the file, it is read as a ruleset, and
`next`, `true`, `does` become plain timeless relations. No program of the
Epilog or Gamemaster sites uses it. Supporting it would mean a frame
axiom (every fluent not re-derived by `next` ends), which LE for LPS can
state, but which the translator does not write today.

## Files

| File | What |
|---|---|
| `epilog_syntax.pl` | Epilog's surface syntax read in Prolog (no EpilogJS needed): tokens, sentences cut where two terms meet with no operator (Epilog writes no full stop), Prolog's reader with Epilog's operators (`:-`, `::`, `==>`, `&`, `~`, `!`, `|`, `:=`) |
| `epilog_reader.pl` | EpilogJS as a subprocess (`tools/epilog_tool.cjs`): its parse (JSON → terms), its query answers, its game runs |
| `tools/epilog_tool.cjs` | EpilogJS on the command line: `parse`, `query <data> <rules> <goal>...`, `game <library> [move...]` (with `EPILOG_DATA`, the state starts as a data sheet's facts) |
| `epilog_twin.pl` | the translator: `theory_migration/3`, `game_migration/3`, `build_theory/3`, `build_game/3` |
| `epilog_import.pl` | File ▸ Open (registered in `../le_importers.pl`: `.epilog`, `.epi`, `.hrf`, `.txt` + detection) |
| `validate.pl` | translate one Epilog program and check it against EpilogJS: `ruleset`, `game` or `program`; prints AGREES / DIFFERS / NOT CHECKED (instructions in LE2's `examples/migration/epilog/README.md`) |
| `corpus.pl`, `corpus_games.pl` | the programs that have twins: 6 rulesets, 2 programs with operations, 71 games |
| `data/` | the data sheets that are ours, where the site gives none (grapheditor, metalevel) or leaves the values to its page (mapcoloring's colours) |
| `build.pl` | the build of every twin into LE2 and LPS2 |
| `test_epilog.pl` | the tests (below) |
| `fetch_sources.sh` | fetches EpilogJS and every rule sheet, data sheet, worksheet program and game library the site's pages link to, into `.cache/` (gitignored) |

Run, from an LE2 checkout, with LPS2 beside LE2 or named by `LPS2_DIR`:

    migration/epilog/fetch_sources.sh
    swipl migration/epilog/build.pl
    swipl -g run_tests -t halt migration/epilog/test_epilog.pl

`build.pl` needs node (EpilogJS is the oracle); the tests need LPS2 (`lps
state`) and, for the reader's agreement with EpilogJS, `.cache/epilog.js`
(skipped without it). File ▸ Open needs neither node nor EpilogJS.

## Mapping

| Epilog | Logical English | Notes |
|---|---|---|
| fact `p(a,b)` | a fact (ruleset: the program or the scenario `dataset`; game: timeless fact, or `initially` when `p` is a base relation) | |
| view `h :- b1 & ~b2` | a rule (`if ... and it is not the case that ...`), through LE2's core Prolog reader (`le_writer:prolog_to_ir/3`) | naive wording, places named after unary relations that type them |
| disjunction `b1 \| b2` | the reader's `either` (ruleset); one rule per disjunct (game views) | |
| `same`, `distinct`, `leq`, `less` | `=`, `\=`, `=<`, `<` (LE's comparisons) | |
| `evaluate(plus(X,times(Y,2)),Z)` | `Z = X + Y * 2` (`plus`, `times`, `minus`, `quotient`, n-ary folded) | |
| `max(A,B)`, `min(A,B)` in an expression | two cases (two rules in a ruleset, two laws or fluent rules in a game): `A >= B` with `A`, `A < B` with `B` | LE has no max in expressions |
| `mutex(X1,...,Xn)` | pairwise `is different from` | |
| `countofall(X, p(X) & q(X), N)` | `N is the number of each X such that ...` (aggregate) | |
| `symless(X,Y)`, `symleq(X,Y)` | — (dropped, in rulesets and games alike; **approximated** in the ledger, one entry per view) | a symbol order LE does not have: a `legal` view lists a pair in both orders |
| lists `X!L`, `nil`, `[a,b]` | LE lists; a clause that takes a list apart (`X!L` in a head) is a **residue** block `list_pattern_K` (the core reader's rule), with the Epilog sentence, one ledger entry per block | |
| a functional term as an argument (`negation(not(X))`, `goodmove(move(U,V,X,Y))`, `init(location(cell(a,1), ...))`) | **residue** block `functional_term_K` with the Epilog sentence, one ledger entry each; a relation stated only by such sentences keeps its template and query | an LE place holds a constant, not a term; the GDL wrappers (`init`, `base`, `action`, `legal`, `next`, `true`, `does`, `input`) hold a literal, not a term |
| `f(X) := expr` (function definition) | **residue** block `function_definition_K` | LE has no user functions in expressions |
| a sentence whose `evaluate` calls a function other than `plus`, `times`, `minus`, `quotient`, `max`, `min` (one defined with `:=`, or `remainder`, `floor`, ...) | **residue** block `function_call_K` | |
| **game / dynamic program** | | |
| relations `init` sets or operations change (`cell`, `control`, `step`) | fluents | a name used with two arities is two templates, known in LPS as `step_1`, `step_2` |
| the moves (operations no other operation calls) | actions, worded as moves: `the move mark with *an index* and *a second index* is made` | the same words as the move's legality |
| `a(X) :: c ==> e & ~f` | `when the move a with … is made and c then e and it is not the case that f.` (one sentence per operation rule, additions first, read back as one law per effect; conditions read in the state before the move, as Epilog does) | Epilog deletes then adds, so a fluent both deleted and added stays; LPS2 does the same (checked) |
| a negated static condition `~home(W,U,V)` in an operation | `it is not the case that ...` with no time (written as holds(not(G), lps_now), read back as not(G)) | |
| a relation named like a Prolog built-in (`succ`, `plus`) | a template like any other (typing clauses put it in a head, where the core reader words it) | an undefined one (battleofnumbers' `succ`) is empty, as in Epilog |
| a symbol that is an LE word (a board's column `a`) | the text `"a"` (LPS2 reports `"a"`; the test reads it back as `a`) | `a cell 1 with red` would introduce a variable |
| a move that is also a sub-operation (kono's `kerchunk`) | an action with its own laws, and inlined in the moves that call it | moves = operations nobody calls, or declared by `action`/`legal`, or played |
| a sub-operation (`kerchunk`, `tick(X)`, `ticket(X,Y)` in bridgecrossing) | inlined: its conditions join the calling move's law | depth ≤ 5; a move whose calls go deeper (or recurse) gets a **residue** block `deep_operations_K` with its operations, and its ledger entry is approximated |
| views over the state (`line`, `open`, `goal`, `terminal`, `legal`) | intensional fluents (`... at a time if ... at the time`) | |
| views over static relations only (`index`, `succ`, `pace`) | timeless templates, facts and rules | |
| static facts only the game's declarations read (`person(a)` read by `action(left(X)) :- person(X)`, `row(1)` by `init(cell(R,C,b)) :- row(R) & col(C)`, a `legal(a)` that always holds) | not written: LPS states those declarations as templates, the initial state and (for a move always legal) no constraint, so the facts would be data nothing reads; the ledger names them (`facts`, `unread_static/3`) | a relation mentioned by any rule, law, view or residue block keeps its facts |
| `init(...)` | `initially ...` — EpilogJS's evaluation (build) or Prolog's (File ▸ Open; the program's relations are evaluated under prefixed names, so one named like a Prolog built-in, skirmish's `number/1`, is the program's own) | a state fact holding a functional term is left out, in a residue block `init_terms_1` |

### GDL relations (decisions)

- `role(R)`: no sentence of its own — roles are the values of the `goal` and
  `control` places (a template `*a thing* is a role` would only restate the
  facts).
- `base(...)`, `action(...)`: not translated as sentences; they **type the
  places** of the fluents and moves (`action(mark(M,N)) :- index(M) &
  index(N)` makes mark's places `*an index*`).
- `legal(mark(M,N))`: a move is a term, which an LE place cannot hold, so
  each move has its own intensional fluent `the move mark with *an index*
  and *a second index* is legal` (`legal_mark`), and a constraint: `it must
  not be true that the move mark with an index and a second index is made
  and it is not the case that the move mark with the index and the second
  index is legal.` As a game manager refuses an illegal move, LPS2 refuses
  it (the timeline marks it *refused by a constraint*).
- `goal(R, N)`: the intensional fluent `the goal of *a role* is *a number*`.
- `terminal`: the intensional fluent `the game is terminal`.
- EpilogJS's plays: the k-th move is the ((7k + seed) mod n)-th of the legal
  moves sorted by their text — reproducible, not a strategy; they stop at a
  terminal state or after 12 moves.

## Licence findings

- **The site's texts** (rule sheets, data sheets, worksheet programs, game
  libraries): public. Stanford confirmed in October 2026 that everything on
  the Epilog site is public except EpilogJS. The twins keep them under
  `sources/`, in the public LE2 and LPS2 repositories.
- **EpilogJS** (`javascript/epilog.js`): for academic use. Its header:
  "Copyright (c) 2020 The Board of Trustees of the Leland Stanford Junior
  University. All nonprofit research institutions may use this Software for
  any non-profit purpose ... This Software may not be redistributed. It may
  not be used for commercial purposes." So it lives only in the gitignored
  `.cache/`, is fetched by `fetch_sources.sh`, and nothing in the
  repositories or in File ▸ Open depends on it: the Prolog reader
  (`epilog_syntax.pl`) reads Epilog, and EpilogJS is used only as the oracle
  when building, testing and validating. A commercial product must not ship
  or run it; a licence holder who validates new programs (`validate.pl`)
  fetches it and complies with its licence, or obtains a commercial licence
  from Stanford.
- EpilogJS's recorded runs (`<name>.epilog.json`) are our outputs.

## Results

Every program of the site was translated and checked (October 2026); the
catalogue, with each outcome and why, is the README of LE2's
`examples/migration/epilog/`. In short:

- **Examples page** (23 items): 6 rulesets have twins (base, blocks,
  graphs, kinship, mapcoloring, metalevel: 21 of 21 queries give EpilogJS's
  answers) and 2 programs with operations (triples, grapheditor); the
  Examples page's buttonsandlights and tictactoe are the games of the same
  names. No twin: boolean, satisfiability, zebra, schedule, gameoflife
  (functional terms), lists, sets, nlp (list patterns, infinite queries),
  cryptarithmetic (EpilogJS gives no answer in time), portico (partly
  translated: 24 sentences residue), solar (arithmetic relations not
  translated), programsheets and pelicanhunters (no Epilog text on the
  page).
- **Games page** (81 games): 71 twins. No twin: badqueens,
  badsendmoremoney, badtictactoe (EpilogJS does not finish in 120 s),
  skirmish, skirmish1 (functional terms in the state), reversum, ttcc4
  (final states differ, not yet explained); twoplustwo, badtwoplustwo,
  sendmoremoney have empty libraries.

Compared with September (3 rulesets, 10 games; 70 of 74 games agreeing on
the whole page): badconnectfour now plays within the time limit and agrees;
a dotted relation name (triples' `student.major`) is renamed in games
(`student_major`), because LE worded the dot apart in laws but not in the
template.

## Residue and limits

- Functional terms (`and(p,q)`, `h(english,dog,...)`): no LE form; the
  sentences are residue blocks, counted in the ledger and the File ▸ Open note.
- List patterns and recursive list definitions: core residue blocks, counted.
- `:=` function definitions, and the sentences whose expressions call them
  (or an Epilog function LE's arithmetic lacks): residue blocks.
- Operations called more than five levels deep: a residue block per move.
- `symless`, `symleq`: dropped (approximated), in rulesets and games.
- The wording is naive (from relation names: `*a thing* is the gp of *a
  second thing*`); the assistant's wording pass (§5.7) is the next step.

## Core findings (LE2)

1. `le_writer:typed_by_annotation/5` takes `arg/3` of every literal of a
   clause: a clause with a proposition (`open :- cell(M,N,b)`, `terminal`)
   beside a literal with a variable throws a type error, so
   `prolog_to_ir/3` fails on it. Worked around here (propositions wrapped
   for the reader, `ir_of/3`); the fix is one `compound(L2)` guard.
2. `le_verifier:slot_value/5` does the same with a rule's head
   (`arg(K, Head, HArg)`): loading any LE program with a proposition
   concluded from a condition with a variable (graphs: `nonreflexive if a
   thing is a node and ...`) prints an `arg/3` type error from the
   unread-value check. Needs the same guard in the core.
3. `le_writer`'s naive wording names the seventh and later places of a
   predicate `*a thing 7*`, which LE reads back with a different arity (the
   ten-place `goal` of cryptarithmetic).
4. A place named like a constant of the program (the place `count` of
   `movecount(Count)` beside the constant `count`) makes LE read the constant
   as the place's variable; worked around here (such a place is renamed
   `count value`), a writer-level check would help every reader.
5. `le_lps_write` has no form for a negated timeless condition (`not(G)` in
   a causal law, which LE's own reader produces from `it is not the case
   that ...` with no time): it writes `% not(...)`. Worked around with
   holds(not(G), lps_now).
6. `le_lps_write:arg_text/3` writes an atom bare, and `le_writer:
   bare_atom_ok/1` accepts a one-word article: the constant `a` is written
   `a`, which LE reads as an article. Worked around (such symbols are
   texts).
7. `le_writer:prolog_to_ir/3` gives no template to a predicate used only in
   bodies whose name is a SWI built-in (`succ/2`, `plus/3`): it becomes a
   Prolog goal. Worked around (typing clauses in head position).

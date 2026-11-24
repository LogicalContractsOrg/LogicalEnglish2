# L4 → Logical English

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

The translator of the design notes `l4.md` (the author's working papers, not published) for
L4, the language for laws and contracts of Singapore Management University's
Centre for Computational Law, now developed by Legalese
(`smucclaw/l4-ide`, copyright Singapore Management University, Apache
License 2.0; the last commit of that repository is of 21 April 2026, and
Legalese continues L4 in `legalese/l4-ide`, under the same licence). L4's
rules become Logical English (LE), and
its contracts become LE for LPS (Logic Production Systems, LE's companion
language for rules about time and change), run by LPS2.

**Where it stands (29 September 2026): steps 0 to 4 of the plan are
done.** Step 0 wrote L4's promissory note both ways by hand and decided
that contracts go into LE for LPS by default
([`step0/README.md`](step0/README.md)). Step 1 is the reader and the oracle
below. Step 2, the rules half (`l4_twin.pl`, `build.pl`), is described in
[The rules half](#the-rules-half) below; step 3, the contracts half, in
`l4_contracts.pl`, `l4_history.pl` and `l4_contracts_build.pl`. Step 4 is
File ▸ Open (`l4_import.pl`, below), the users' documentation (LE2's and
LPS2's `docs/user/integrations/l4.md`) and a role-play review, written
from the point of view of an L4 developer (it is not published, and it is
not a review by the makers of L4).

**Files that come from L4.** Five files here are copied or adapted from
`smucclaw/l4-ide` at commit `5e082cf` (Copyright 2025 Singapore Management
University, Apache License 2.0, the licence of this repository's
`LICENSE`): `step0/promissory_note_traces.l4` (after its three-line
heading, its lines 4 to 328 are L4's `jl4/examples/legal/promissory-note.l4`,
unchanged; the rest was written here), `spike/rules.l4`, `spike/sale.l4`
and `spike/l4run.mjs` ([`spike/NOTICE.txt`](spike/NOTICE.txt) says where
each comes from and what was changed), and the function `load` of
`l4_oracle.mjs` (its heading says so). `l4_lex.pl` and `l4_reader.pl` are
new Prolog code that follows the order of L4's `Lexer.hs` and `Parser.hs`.
The L4 files under `sources/` in the published twins are unchanged copies,
each with L4's `LICENSE`.

| File | What it does |
|---|---|
| `l4_lex.pl` | the lexer: L4 text → tokens with their lines and columns, following L4's own lexer (`jl4-core/src/L4/Lexer.hs`) token for token; comments dropped, annotations kept, the ditto mark `^` replaced by the token above it |
| `l4_reader.pl` | the reader: tokens → the model below, following L4's own parser (`jl4-core/src/L4/Parser.hs`) construct by construct, including its use of columns; what it cannot read is kept as an `unparsed` item, never dropped |
| `l4_print.pl` | the model written back as L4, for the gate's round trip |
| `l4_oracle.mjs`, `fetch_oracle.sh` | the oracle: L4's own evaluator, compiled to WebAssembly by its authors (release `vscode-wasm-build-117`, fetched into `oracle/`), run by Node.js: every directive's result, the type at a position (`hover`), and the cache of runs |
| `corpus.pl`, `fetch_sources.sh` | the corpus: 87 files of `smucclaw/l4-ide` at commit `5e082cf` (21 April 2026, the commit that release `vscode-wasm-build-117` was built from), fetched into `.cache/l4-ide` |
| `runs/` | the evaluator's results for each corpus file (`<Id>.json`) and the gate's last results (`gate.txt`) |
| `gate.pl` | the gate of step 1 (below) |
| `test_l4.pl` | plunit: the lexer, the reader, the corpus, the gate's last run, the two step 0 twins |
| `l4_twin.pl` | step 2, the rules half: the model → a migration (`le_migration.pl`) in timeless LE — templates, rules, records as individuals, the tests as scenarios, the ledger; the variants of a program whose facts are ASSUMEd |
| `build.pl` | the rules twins into LE2 `examples/migration/l4/<name>/` (`le2_paths:twins_dir/2`), with the source under `sources/` and its licence; runs the variants through the evaluator into `runs/variants/` when their cache is stale |
| `l4_import.pl` | File ▸ Open of an `.l4` file (through `../le_importers.pl`): the rules twin in the LE editor, the contracts twin in the LPS2 IDE (which passes `target(lps)`), the other written beside it; the file under `sources/`; L4's evaluator's results as the expectations when it is installed |
| `test_l4_import.pl` | plunit: File ▸ Open through LE2's upload door, as each editor asks |
| `step0/` | step 0: the promissory note by hand in both readings, and the decision |
| `lib_draft/` | a first cut of `lib/deontic_history.le` (not moved to LE2; see its README) |
| `spike/` | the experiments the plan was written from |

## How to run

From the LE2 checkout (`/work`); Node.js 20 or later for the oracle:

```sh
migration/l4/fetch_sources.sh          # the corpus, into .cache/
migration/l4/fetch_oracle.sh           # L4's evaluator, into oracle/
./myswipl.sh -q -g run_tests -t halt migration/l4/test_l4.pl
./myswipl.sh -q -g run_tests -t halt migration/l4/test_l4_import.pl   # File ▸ Open

# the gate (about 3 minutes: every file is run by L4's evaluator again)
./myswipl.sh -q -g "consult('migration/l4/gate.pl'), gate:main" -t halt

# the oracle by hand
node migration/l4/l4_oracle.mjs eval FILE.l4
node migration/l4/l4_oracle.mjs hover FILE.l4 12:15 32:7
node migration/l4/l4_oracle.mjs cache --force ID=FILE.l4   # into runs/ID.json

# reading a file
./myswipl.sh -q -g "use_module('migration/l4/l4_reader'), l4_read_file('FILE.l4', M), print(M)" -t halt
```

## The gate of step 1

L4's evaluator accepts 82 of the 87 corpus files. The other five are
experiments in syntax the language has left behind (four Jersey charities
files, the Personal Data Protection Act), or a file that imports another
file of the corpus, which the WebAssembly evaluator cannot be given. For the
82 (`runs/gate.txt`):

| Check | Result |
|---|---|
| read with nothing left unread, and every directive the evaluator ran (`#EVAL`, `#TRACE`, `#ASSERT`, …) found on the same line | **82 of 82 files** |
| the type recorded for each declared name (the parameters after `GIVEN`, the fields after `HAS`) is the type L4's hover reports there, on five files | **155 of 155 names** |
| the file written back from the model (`l4_print.pl`: every name in backquotes, brackets wherever the model has structure) gives the same results under L4's evaluator | **82 of 82 files**, 654 results |

The round trip is the strong check: an operator grouped differently, an
argument given to the wrong function, a branch attached to the wrong
`CONSIDER` or an obligation's `LEST` given to the wrong obligation changes
a result. The five refused files are read too; three have parts the reader
keeps as `unparsed`, where L4 also stops.

Two things found on the way, both in L4's own tools as they were in that
release (April 2026; a later L4 may differ):

- **L4's parser takes time exponential in the depth of brackets.** It tries
  a bracketed expression as the start of a field access (`x's f`), and reads
  it again from the start when that fails. A file written with a bracket
  around every subexpression did not finish in a minute. The printer
  therefore writes brackets only where they are needed.
- **The WebAssembly build of the evaluator runs one file only.** It has an
  empty store of project files, so an `IMPORT` of another file of the
  program fails there (L4's other tools do read a program in several
  files). Only the libraries it ships (`prelude`, `daydate`, `math`, …) can
  be imported.

## The model

`l4_read_file(+File, -Model)` and `l4_read_text(+Text, -Model)` give

    l4_module(Items, Issues)

`Items` are the program's top-level items in order; `Issues` are the
`unparsed` ones among them. A name is an atom: the text of a plain name or of
a name in backquotes, without the backquotes. A position is `pos(Line1,
Line2)`, the lines an item spans, or `pos(Line, Column)` for a name.

### Items

| Item | L4 |
|---|---|
| `section(Level, Name, Aka, pos(L1, L2))` | `§`, `§§`, … `Name` (or `none`), `AKA` names |
| `import(Name, pos(L1, L2))` | `IMPORT Name` |
| `timezone(Expr, pos(L1, L2))` | `TIMEZONE IS Expr` |
| `declare(Sig, AppForm, TypeDecl, Anns, pos(L1, L2))` | `DECLARE` |
| `decide(Kind, Sig, AppForm, Expr, Anns, pos(L1, L2))` | `DECIDE … IF/IS …` (`Kind = decide`) or `… MEANS …` (`Kind = means`) |
| `assume(Sig, AppForm, Type, Anns, pos(L1, L2))` | `ASSUME … IS Type` (`Type = none` when not given) |
| `directive(Directive, Anns, pos(L1, L2))` | `#EVAL` and the others, below |
| `unparsed(Text, Reason, pos(L1, L2))` | what the reader could not read: the tokens' text, and `parse` or `lexer(Line, Column)` |

- `Sig = sig(Givens, Giveth)`: `Givens` is a list of
  `param(Name, Type, pos(Line, Column))` (`Type = none` when not given);
  `Giveth` is a type or `none`.
- `AppForm = appform(Name, Args, Aka, pos(Line, Column))`: the words of the
  defined name as written, `Name` first, then the parameter names and, for a
  mixfix name, its other words (`` a `plus` b MEANS … `` is
  `appform(a, [plus, b], [], _)`). `l4_mixfix_signature(Sig, AppForm, Parts)`
  gives a mixfix definition's words as `param(P)` and `kw(Word)`.
- `TypeDecl` is `record(Fields)`, `enum(Constructors)` or `synonym(Type)`;
  a field is `field(Name, Type, Computed, pos(Line, Column))`, `Computed` the
  expression after `MEANS` or `none`; a constructor is `con(Name, Fields)`.
- `Anns` is a list of `a(Kind, Text, Line)`, `Kind` one of `desc`, `nlg`,
  `ref`, `export`, `ref_src`, `ref_map`. An annotation on a line of its own
  belongs to the next item; one at the end of a line belongs to the item on
  that line. (Which parameter an annotation on a `GIVEN` line describes is
  its line: compare it with the parameter's position.)

### Types

`type` (`TYPE`), `tyapp(Name, Args)` (`NUMBER` is `tyapp('NUMBER', [])`,
`LIST OF NUMBER` is `tyapp('LIST', [tyapp('NUMBER', [])])`,
`DEONTIC Actor Action` is `tyapp('DEONTIC', [tyapp('Actor', []), tyapp('Action', [])])`),
`fun(ArgTypes, ResultType)` (`FUNCTION FROM A AND B TO C`),
`forall(Names, Type)`. Articles (`A`, `AN`, `THE`) are dropped.

### Directives

`eval(E)`, `evaltrace(E)`, `check(E)`, `assert(E)`, and
`trace(Contract, StartTime, Events)` for
`#TRACE Contract AT StartTime WITH Events`, each event an
`event(Party, Action, Time)` (`PARTY p DOES a AT t`) or an ordinary
expression (`` (`WAIT UNTIL` 20) `` is `app('WAIT UNTIL', [num(20)])`).

### Expressions

| Model | L4 |
|---|---|
| `num(N)`, `str(S)` | a number, a string |
| `app(Name, Args)` | a name (`Args = []`), `f a b`, `f OF a, b` |
| `app_named(Name, [Field=Expr, …])` | `Name WITH Field IS Expr, …` |
| `mixfix([arg(E1), kw(W1), arg(E2), …])` | `` e1 `w1` e2 … `` — a use of a mixfix name, left for the translator to match against the definitions' signatures |
| `proj(E, Field)` | `E's Field` |
| `and(A, B)`, `or`, `implies`, `ror`, `rand`, `eq`, `leq`, `geq`, `lt`, `gt`, `cons`, `plus`, `minus`, `times`, `div`, `mod` | the binary operators, grouped as L4 groups them (`A UNLESS B` is `and(A, not(B))`) |
| `not(E)`, `percent(E)`, `as(E, Type)` | `NOT E`, `E%`, `E AS STRING` |
| `if(C, T, E)` | `IF C THEN T ELSE E` |
| `branch([C1-E1, …], Otherwise)` | `BRANCH IF C1 THEN E1 … OTHERWISE E` |
| `consider(E, Branches)` | `CONSIDER E WHEN P THEN X …`; a branch is `when(Pattern, Expr)` or `otherwise(Expr)` |
| `lam(Params, E)` | `GIVEN x YIELD E` |
| `list(Es)` | `LIST e1, e2` |
| `where(E, LocalDecls)`, `let(LocalDecls, E)` | `E WHERE …`, `LET … IN E`; a local declaration is a `decide/6` or `assume/5` item |
| `deontic(Party, Modal, Action, Provided, Within, Hence, Lest)` | `PARTY p MUST/MAY/SHANT/DO action PROVIDED c WITHIN d HENCE h LEST l`; `Modal` is `must`, `may`, `shant` or `do`; each optional part is `none` when absent |
| `breach(By, Because)` | `BREACH BY p BECAUSE r` (`none` when absent) |
| `event(Party, Action, Time)` | `PARTY p DOES a AT t` |
| `fetch(E)`, `env(E)`, `post(A, B, C)`, `concat(Es)` | `FETCH`, `ENV`, `POST`, `CONCAT` |

A pattern (after `WHEN`, and the action after `MUST`) is `plit(Literal)`,
`pexact(Expr)` (`EXACTLY e`), `papp(Name, Patterns)` or `pcons(P1, P2)`
(`FOLLOWED BY`).

`FULFILLED`, `TRUE`, `FALSE`, `NOTHING`, `JUST` and the constructors of a
choice are names (`app('FULFILLED', [])`): the model does not interpret them.

## The rules half

`./myswipl.sh -q migration/l4/build.pl` (from `/work`) writes the
twins of every rules file of the corpus (`l4_rules_file/1` in
`l4_twin.pl`), `build.pl -- ID ...` those of the ids given. Each twin is
`examples/migration/l4/<name>/<name>.le` in LE2, with its ledger
(`.ledger.md`, `.ledger.json`), the source and its licence under
`sources/`, and `l4_daydate.le` beside it when it uses dates. Results of
29 September 2026, after step 4's review: **62 twins, 621 of 621
expectations pass**; 1,236 source elements encoded, 383 approximated, 159
residue (the ledgers say which and why). The six twins added by the review
are the rules of the files that also have contracts; their contracts are
residue here, and twins of their own in LPS2 (step 3).

**The mapping** (the design notes l4.md §3, as built):

- A record type is a type of individuals; each field is a function
  template, `the age of *an applicant* is *a number*` (the part after a
  possessive: `the applicant's age` → `age`), or, for a yes-or-no field,
  `*an applicant* has valid ID` (the type's name put where the field's
  phrase names it, else `has`). A computed field (`age … MEANS current year
  - date of birth`) is a rule over the record's other fields. A constructor
  of a choice with fields is a record type too, with `*a t* is a c`.
- A record written in the program (`alice MEANS Person "Alice" 30`) is an
  individual (`alice`) with one fact per field; a field the program
  computes (`IS Trillion 3`) is a rule; a list of records is a list of
  individuals. A record written in a test is an individual of that test's
  scenario.
- `DECIDE`/`MEANS` giving yes or no is a rule; giving a value, a rule of a
  template ending `is *a value*`. The words: the `@nlg` sentence; the mixfix
  name; the phrase name with each input put where the phrase names it
  (`the applicant is eligible` with input `applicant` → `*an applicant* is
  eligible`); else the name with the inputs after it (a verb phrase takes
  its first input before it), flagged `approximated` in the ledger. LE's
  own words in a name are replaced (`if` → `whether`, `or` → `else`,
  `either` → `one of`, …). Two templates that could read each other's
  sentences are told apart (the enclosing definition's name, `given`
  instead of `for`, `variant two`).
- `ASSUME` is `; undefined` (the scenario states it). `WHERE`/`LET`
  definitions are templates of their own, with the enclosing inputs they
  use. `IF`, `BRANCH` and `CONSIDER` are `otherwise` cascades; a pattern on
  a list (`x FOLLOWED BY rest`) is a `prolog` goal taking the list apart;
  `JUST`/`NOTHING` a value present or absent. `all`/`any`/`elem` are `for
  all cases in which` / `is in`; `sum`, `length`, `maximum`, `minimum` over
  `map`/`filter` are LE's aggregates, and `map`/`filter` kept as a list is
  `the list of each … such that`.
- Dates are LE dates; `Date d m y`, `Day`, `DATE_YEAR` and the other
  daydate functions are `lib/l4_daydate.le`'s templates (LE2), whose
  Prolog half counts days as L4 does (1 January 2025 is day 739616).
- What has no LE form — a function passed as a value, a record built
  inside a rule, text functions (`CONCAT`, `TOSTRING`), `TRUNC` with a
  precision, a list built with `FOLLOWED BY`, JSON and web builtins — is a
  residue block with the source lines, never dropped; the tests that need
  it are pending.

**The tests.** Every `#EVAL`/`#ASSERT` is a scenario citing its line. A
yes-or-no definition with constant inputs is queried by its own sentence
(`alice_the_adult is eligible`); any other answer by a check of its own,
`L4's answer at line 40 is reproduced`, whose rule computes the value and
compares it with L4's (a number within one part in a billion, written with
whole numbers). A program whose facts are `ASSUME`d has **variants**: each
assumed type gets one individual, each assumed yes-or-no fact or function
TRUE or FALSE, each assumed function to a type that individual, and each
decision over those is `#EVAL`ed, for every combination of the facts it
rests on (up to eight; else all true, all false and each one flipped).
`build.pl` runs them through the evaluator into `runs/variants/<Id>.json`,
keyed by a hash of the variants' text. A decision that calls itself has no
variants: with one individual per type it would not end.

**The hook for step 3.** `twin_migration/3` calls
`l4_contracts:contract_items(ctx(Model, Options, Symbols), Items, Tests,
Ledger)` when it exists, `Symbols` the rules' templates; step 3 took
another route (its own documents, `l4_contracts.pl`), so the rules twins
record each `DEONTIC` definition as residue for step 3.

**Found on the way, in LE2:** `le_writer.pl` wrote a variable first met
inside a `prolog` goal as `the <name>`, which LE reads as one already met,
so a goal taking a list apart bound nothing; such a variable is now written
as an id (`prolog (the list=[T|L])`).

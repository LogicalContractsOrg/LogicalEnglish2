# Daml / Canton ↔ Logical English (Phase 2g)

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

The translator of the design notes `roadmap.md` §6.6 for Daml 3 (the
smart-contract language of Canton). It reads Daml **source**, not Daml-LF:
the templates and choices of a Daml project, and its Daml Script tests,
become a twin in LE for LPS (run by LPS2). Its oracle is Daml itself, on a
local Canton sandbox. The way back writes an LE for LPS program as a Daml
module, with its scenario as a Daml Script, and runs that on Canton too.

| File | What it does |
|---|---|
| `daml_syntax.pl` | the reader: a tokenizer, Haskell's layout rule (implicit blocks after `where`/`with`/`do`/`let`/`of`, `let … in`, `if/then/else` in `do`), and a DCG for Daml's declarative subset — modules, imports, `data` records, `template` (fields, `signatory`, `observer`, `ensure`, `choice` with `nonconsuming`/`preconsuming`/`postconsuming`, `with` arguments, `controller`, `do`), functions, and expressions (precedence climbing, records and record update, sections, backquoted infixes, `do`, `if`, lists, tuples). A declaration it does not cover is kept whole as `other(Kind, Text)`: nothing is dropped silently |
| `daml_model.pl` | a project's model: records, templates with their flattened fields, choices, script functions, type aliases; two templates of one name are an error, not a merge |
| `daml_twin.pl` | the twin: templates as fluents, creates and choices as actions, who may do what as integrity constraints, choice bodies run symbolically as causal laws, Daml Scripts as scenarios, the ledger of what was encoded/approximated/residue |
| `daml_oracle.pl` | the oracle: each script run by Daml (Canton sandbox, else Daml Script's in-memory ledger), the active contracts it ends with read back; runs cached in `runs/` |
| `daml_export.pl` | the way back, LE for LPS → Daml: File ▸ Export to Another System (`le_import:exporter(daml, …)`) |
| `daml_gate.pl` | the gate of the way back: exported Daml built and run on Canton, its final state compared with LPS2's, and a mutant's |
| `daml_import.pl` | the File ▸ Open adapter for `.daml` files and zipped Daml projects (`le_import:importer(daml, …)`) |
| `corpus.pl`, `build.pl`, `fetch_sources.sh` | the corpus (the SDK's own templates, Apache-2.0), the build into `lps2/examples/migration/daml/` |
| `test_daml.pl` | plunit: the reader, every twin against Daml's final state, File ▸ Open, the exporter, the gate's last run |
| `runs/` | the oracle's runs (`<project>__<script>.json`: the contracts, the ledger that answered) and the gate's last results (`gate.txt`) |

Both adapters are registered in `../le_importers.pl`.

## How to run

The Daml SDK (`dpm` 3.5.x, `~/.dpm/bin/dpm`; it brings Java and Canton) is
needed to fetch the corpus, to make the oracle's runs and to run the gate;
the twins and the tests need neither Daml nor the sandbox (the runs are
cached). From `/work`:

```sh
migration/daml/fetch_sources.sh                                  # the SDK templates, into .cache/
./myswipl.sh -q migration/daml/build.pl                          # every twin
./myswipl.sh -q migration/daml/build.pl -- skeleton quickstart   # some
./myswipl.sh -q -g run_tests -t halt migration/daml/test_daml.pl

# the oracle and the gate (a sandbox first: ~/.dpm/bin/dpm sandbox, ~90 s to start)
./myswipl.sh -q -g "use_module('migration/daml/daml_oracle'), oracle_run(quickstart, [force(true)])" -t halt
./myswipl.sh -q -g "use_module('migration/daml/daml_gate'), gate_main" -t halt
```

## The mapping

| Daml | LE for LPS |
|---|---|
| `template Asset with issuer, owner, name` | a fluent keyed by the contract id, the fields (flattened: `iou : Iou` gives `iou issuer`, `iou owner`, …) its other places: `*an asset* is an asset with issuer *an issuer*, owner *an owner* and name *a name*` |
| `create` | an action of the submitting party, `*a party* creates the asset *an asset* with …` (the contract named as its archive and choices name it), initiating the fluent |
| `choice Give with newOwner controller owner do …` | an action of the exerciser on a contract id, `*a party* exercises give on the asset *an asset* with new owner *a new owner* creating *a second asset*` |
| the ids of the contracts a command creates | **places of its action, supplied by the caller**: the ledger assigns them, the scenario names them (`creating bob_tv`) |
| a consuming choice; `archive`; the implicit `Archive` choice | a law terminating the contract's fluent |
| `fetch` | a condition that the contract is active |
| a nested `exercise` | inlined; a contract created and consumed in the same transaction never reaches the state (Daml's transient contracts) |
| `signatory` of a created contract | a constraint: the submitter (of a create), or the choice's authorizers (its controllers and its contract's signatories), must include them; a list of signatories (`signatory alreadySigned`), each member of it (`an element is in the already signed list and the element is different from the party`) |
| `controller` | a constraint: the exerciser must be it |
| an archived contract exercised again | a constraint: the contract must be active |
| `ensure`, `assert`, `assertMsg`, `===` | constraints, conjunct by conjunct (a conjunct the twin cannot state is noted, never dropped silently) |
| a Daml Script (`submit`, `submitMustFail`, `createCmd`, `exerciseCmd`, `createAndExerciseCmd`, `archiveCmd`, `allocateParty`, `let`, helper scripts) | a scenario: one command per cycle, parties as constants (their hints), contract ids the names the script binds; a `submitMustFail` is a command LPS2 refuses |
| further scripts of the project | programs of their own that extend the first (`<project>_<script>.le`) |

Each twin's comment carries Daml's own final state (the oracle's run) and
its `sources/` the originals with Digital Asset's notice. Residue — `key`,
interfaces, `case`, time (`getTime`, `passTime`, `addRelTime`), text
functions, helper functions inside choices — is listed in the ledger
(`<twin>.ledger.md`) with its reason.

### The oracle

Each script is built as a package of its own (a DAR named after the run),
its party hints suffixed with the run's tag (the only change to the
sources), and run by `dpm script` on the Canton sandbox. A generated
wrapper runs the script, then asks every party it allocated for the
contracts of every template, and returns them (`--output-file`). Scripts
that set the time (`setTime`, `passTime`) are refused by the sandbox's wall
clock; they run on Daml Script's in-memory ledger instead, and the run says
so. The twin's final state (`lps state` in LPS2) is compared with the
payloads, contract ids left out (the ledger's are hashes).

### The way back (File ▸ Export to Another System ▸ Daml)

Daml 3 has no contract keys, so a fluent cannot be looked up by its values:
the exporter writes the whole LPS state as **one** contract, `State`, its
fluents lists of records (a fluent with no places a `Bool`). An operator
party is its signatory and every party of the program an observer; each
action is a choice of `State`, its controller the acting party (the
action's first place); an integrity constraint on an action is an
`assertMsg` before the update, one on states an `assertMsg` on the new
state; the causal laws are the update (terminations and updates' old values
computed on the state before, initiations added, `dedup` since a fluent is
a set); `initially` is the created `State`; the scenario is a Daml Script
that submits each observed action with `trySubmit` (a refused one leaves
the state as it was, as LPS2 refuses it) and returns the final `State`.

A record's fields and a choice's arguments are named by the places of the
LE templates (`issuer : Party`, `observersPartyList : [Party]`; a choice argument
that a `State` field already names gets `Arg`), `a1`, `a2`, … only for a
relation with no template.

Types come from the program: a place that holds an acting party, or shares
a variable with one, is a `Party` (not when the program states facts about
it, nor when it holds a number or a date); a number, or a place a law compares or
computes with, a `Decimal`; lists are lists of those (`[Party]` when a
member is a party, a law takes a member of it to a party's place, or the
place is called a list of parties, as a twin calls a Daml `[Party]` field:
`*an observers party list*`); else
`Text`. A party a law names (`the treasury`) is a field of `State` the
script allocates (Daml has no party literals). A fluent's default
(`0 by default`) is its value when no record has it; the program's facts
are alternatives; `findall`, `length` and `is in` are Daml's list
functions.

**Rules are functions.** Daml has no rules, but a rule asked with some of
its places known is a function from those to the list of the others: `the
preceding business day for a trade of a date is a second date`, asked with
the trade and the date, becomes
`thePrecedingBusinessDayForOfIs_bbf : State -> Text -> Date -> [Date]` (`b` a
known place, `f` one asked for; a `Bool` when every place is known). There
is one function for each pattern a law, a constraint or another rule asks
the rule in, each clause a list of answers, so recursive rules (a date
shifted by business days) are recursive functions. Intensional fluents and
the predicates the program states as facts are functions too (the facts
written as alternatives would copy the conditions after them once per fact).
A predicate the program leaves to Prolog, in its `.lps` companion, has no
Logical English to translate: a **Daml companion**, `<knowledge base>.daml`
beside the program, gives each function under the same name, and the
refusal lists the functions missing with their types. Dates are Daml's
`Date` (a place no statement gives a value, which its template calls a
date, too).

**A reactive rule is a cycle.** A reactive rule whose conditions read the
state and the rules (no event), and which takes actions, is the operator's
nonconsuming choice `ReactiveCycle`: on the state as it is, the actions the
rules call for that the constraints allow (`<action>Allowed`), each taken in
turn. The script exercises it once for each of LPS's cycles, up to the
program's maximum time, the events observed in between. LPS takes one
cycle's actions together; the module takes them one after another, which
differs only for actions of one cycle that bear on each other.

Refused, with the reason: a reactive rule that reacts to an event (a Daml
trigger would be one), or that takes an action of a party (only that party
can take it in Daml, not the operator's cycle); composite events;
constraints relating two actions; a goal to plan; a place that holds a party
in one statement and a list in another (Daml's types differ); a predicate
left to Prolog with no Daml companion; and any error of the program's LPS
reading. The check runs before anything is written (`check_daml/3`, le_import's
`export_check`): a refused program gets no module, only the list, each item
with its line.

The gate (`daml_gate.pl`): the generated module is built with `dpm build`,
its script run on Canton, and the final `State` compared with LPS2's final
state of the program; a mutant (no law terminates anything) must end
elsewhere.

## Results (15 September 2026)

### Twins against Daml

Daml's final active contracts against the twin's final state under LPS2,
per Daml Script (22 scripts, 11 projects; Canton 3.5 sandbox unless noted).

| Project | Source (SDK template) | Script | Daml ran on | Twin = Daml | Ledger (enc/approx/residue) |
|---|---|---|---|---|---|
| `skeleton` | skeleton | `setup` | Canton | yes | 5/5/0 |
| `token` | daml-intro-daml-scripts | `token_test`, `_1`, `_2`, `_3` | Canton | yes (4/4) | 3/0/0 |
| `simple_iou` | daml-intro-choices | `test_iou` | Canton | yes | 4/1/0 |
| `contact` | daml-intro-choices | `choice_test` | Canton | yes | 5/5/0 |
| `restrictions` | daml-intro-constraints | `test_restrictions` | in-memory (`setTime`) | **no** (expected) | 5/11/6 |
| `parties` | daml-intro-parties | `iou_test`, `simple_iou_test` | Canton; in-memory (`passTime`) | yes (2/2) | 24/7/0 |
| `quickstart` | quickstart-java | `iou_test`, `trade_test` | Canton | yes (2/2) | 18/11/2 |
| `compose` | daml-intro-compose | `setupRoles`, `test_asset`, `test_issuance`, `test_merge`, `test_split`, `tradeSetup`, `test_trade` | Canton | yes (6/7), `test_trade` **no** (expected) | 33/6/0 |
| `coin_issuance` | daml-patterns | `coinIssuance` | in-memory (`passTime`) | **no** (expected) | 27/10/2 |
| `locking` | daml-patterns | `locking` | in-memory (`passTime`) | yes | 17/3/0 |
| `multiparty` | daml-patterns | `multiplePartyAgreementTest` | Canton | **no** (expected) | 7/7/2 |

18 of 22 scripts end, in the twin, with exactly Daml's contracts —
including the quickstart's delivery-versus-payment trade (nested
exercises, transient contracts), every `submitMustFail` a refused call. The
four that do not, and why (`expected_difference/3` in `test_daml.pl`):

- `restrictions`: `Redeem` reads the ledger's time and branches on a
  `case`; the `ensure`'s `T.length`/`T.isUpper` conjuncts are text
  functions — residue, so the twin keeps IOUs Daml redeems;
- `compose test_trade`: the script passes a value it queried from the
  ledger (`queryContractId`) into `Trade`'s create; the symbolic run of the
  script does not know ledger values;
- `coin_issuance`: `Lock` takes a maturity (`addRelTime now (days 2)`) and
  `Clawback`/`Unlock` compare it with `getTime`; time is not stated, so the
  lock and what follows are skipped;
- `multiparty`: `Sign` asserts `elem` of the function `toSign` (a record
  pattern, `filter`, `notElem`) and `Finalize` compares sorted lists — both
  residue, so the twin ends with the `Pending` contract (its list of
  signatories, and the create Daml refuses, are the twin's too) that Daml
  signs and finalizes into an `Agreement`.

### The way back, on Canton

Every program the exporter accepts, written as Daml, built with `dpm
build` and its script run on the Canton sandbox, ends in LPS2's final state
of the program (`runs/gate.txt`, 15 September 2026):

| Programs | Exported | On Canton = LPS2 | Mutant ends elsewhere |
|---|---|---|---|
| the 22 Daml twins (`lps2/examples/migration/daml/`) | 22 | 22 | 19 (the other three terminate nothing their scenario can see: `token_test_1`, `token_test_2`, `multiparty`) |
| LPS2's Logical English examples (`lps2/examples/le/`, 17) | 2 (`token`, `fee_token`: defaults, a constant, a list airdrop, a party a law names) | 2 | 2 |
| | 15 refused, with the reason | | 7 reactive rules, 4 composite events, 3 intensional fluents, 1 constraint relating two actions |

**18 October 2026: rules as functions** (`runs/gate.txt`). The exporter now
writes rules, intensional fluents and fact tables as functions, and reactive
rules that read the state as the operator's `ReactiveCycle`; the gate's
corpus gained LPS2's finance examples:

| Programs | Exported | On Canton = LPS2 | Mutant ends elsewhere |
|---|---|---|---|
| the 22 Daml twins | 22 | 22 | 19 (the same three) |
| LPS2's finance examples (`examples/finance/`, 2) | 2 (the CDM's interest-rate reset, with its Daml companion; the trade lifecycle record) | 2 | 1 (the record's demo scenario ends nothing) |
| LPS2's Logical English examples (`examples/le/`, 19) | 2 (`token`, `fee_token`) | 2 | 2 |
| | 17 refused, with the reason | | 8 reactive rules that wait for events, 6 composite events, 2 constraints relating two actions, 1 reactive rule taking a party's action |

Each of the interest-rate reset's eight scenarios, made the program's first
in a copy, ends on Canton in LPS2's final state too; seven mutants end
elsewhere (in *overnight without method* the step is refused and nothing
ends). The gate also found an old fault of the `multiparty` twin's reading
in LE2: a variable of a qualifier and five words of type (`a second final
contract signatories party list`) was read as words, a constant, which made
its constraint weaker and its export not build; the qualifier no longer
counts towards LE2's limit of five words (`le_grammar.pl`,
`extract_var_name/2`).

So the full cycle Daml → LE → Daml holds on the corpus: for the 18
scripts whose twin ends as Daml does, the exported Daml ends, on Canton, in
the state the original Daml ends in.

### Daml Finance

Not in the corpus, and not feasible for a source reader as it stands. The
Daml Finance templates (`dpm new --template finance-settlement` and the
other `finance-*` templates) are written against Daml Finance's
**interfaces**, which come as pre-built DARs (`data-dependencies:
.lib/daml-finance-*.dar`), not as source: a holding is created through an
interface factory, `implements` blocks give the choices, and the scripts
exercise interface choices on interface contract ids. A source reader sees
the calls but not what they do. Two ways forward: read Daml-LF (the DAR's
compiled package, which has every interface and instance) instead of
source — a reader of its own, of about this one's size; or read Daml
Finance's own source repository (Apache-2.0) as a project, with interfaces
as `the knowledge base … extends …` and `implements` as `this law replaces
…`, as §6.6 sketches. Both are larger than this phase.

## Decisions

- **Source, not Daml-LF.** The twin reads what a lawyer and a developer
  read, with its comments and names; the price is Daml Finance (above).
- **Contract ids are places of the actions**, supplied by the scenario
  (the script's binder names: `alice_tv`), never invented by the twin:
  the ledger assigns them in Daml, and LPS has no fresh-id generator a
  law could use. A constraint refuses a create whose id is already active.
- **Authorization as constraints.** A command Daml rejects is a call LPS2
  refuses (with the constraint that refused it); `submitMustFail` is a
  refused call in the scenario, commented as such.
- **One twin per project, a program per further script** that extends the
  first, so each script has its own scenario and final state.
- **Daml itself is the oracle**, on a real Canton sandbox, with its runs
  cached so builds and tests need neither.
- **The way back as one `State` contract**: Daml 3 has no contract keys, so
  a fluent cannot be a contract looked up by its values; one contract with
  lists keeps LPS's reading (a set of fluents, laws computed on the state
  before) exact, at the price of every choice consuming the one contract.

## Findings

- LE2 core (fixed there): `le_lps_write`'s expression writer dropped the
  quotes of a string in a condition (`name /= ""` came out as `name \= `),
  so the twins left such conditions out; they keep them now (`the name is
  equal to ""`, the skeleton's `ensure`). The writer also put a space before
  commas (`issuer the issuer , owner …`) and loaded with a
  discontiguous-clauses warning; both gone.
- Daml: Canton's sandbox runs on wall-clock time, so the SDK's own tests
  that `setTime`/`passTime` cannot run on it; the in-memory ledger runs them.
- Daml: party hints are global to a sandbox, so every run of a script needs
  hints of its own; and a package name may not have a segment starting
  with a digit.
- Daml: the SDK's `daml-patterns` has four templates called
  `TransferProposal` in four modules; a project must take one.

## Licences

The corpus is the Daml SDK's own templates (`dpm new`), © Digital Asset
(Switzerland) GmbH and/or its affiliates, Apache License 2.0; each twin's
`sources/` holds the files it was made from, unchanged, with a
`NOTICE.txt` and the licence's text (`LICENSE`, the copy the SDK's
`dpm new` ships, kept here as `LICENSE-Apache-2.0.txt`). `.cache/` (the fetched templates) and `oracle/work/` (the
oracle's and the gate's packages) are not kept.

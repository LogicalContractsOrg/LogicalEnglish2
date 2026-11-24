# Solidity / EVM → Logical English for LPS (Phase 1e)

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

The flagship translator of the design notes `roadmap.md` (§6.0–6.1,
§8 Phase 1e): a deployed Solidity contract as an **executable twin** in
Logical English for LPS, a **legal-readable view** derived from it (who may
do what, when, with which effect), and **validation by replay** of the
chain's own transactions. It stands on the shared Phase 0 machinery of LE2
(`le_writer.pl`, `le_migration.pl`, `docs/dev/migration.md`).

**The way back is LPS2's**: `src/syntax/lps_solidity.pl` in the LPS2
repository, its *Deploy as Solidity*, with its gate (`tools/solidity_test.pl`).
This folder is the way in.

```
contract.sol ──solcjs (solc_ast.js)──▶ typed AST ──sol_front.pl──▶ LPS terms + templates (Migration IR)
                                                                 ──le_writer──▶ twin.le  (LE for LPS)
twin's LPS terms ──LE2's le_lps_legal.pl──▶ legal view (timeless LE: may-rules, effects, flip queries)
chain logs + balances (replay_fetch.js) ──sol_replay.pl──▶ scenario ──LPS2──▶ state vs chain
```

| File | What it is |
|---|---|
| `solc_ast.js` | compiles with solcjs, prints the compact typed AST, storage layouts and source texts |
| `sol_front.pl` | the front end: symbolic execution of each public function into paths, paths into LPS laws and constraints |
| `sol_names.pl` | the wording: the reviewed templates of the reference models (E11), a fallback from identifiers |
| `sol_migrate.pl` | the catalogue of twins, the writer of `<twin>.le` + ledger, the LPS2 runner |
| `sol_import.pl` | File ▸ Open of a `.sol` (or a `.zip` of sources) in the editors: the adapter LE2's `le_import.pl` calls — the most derived concrete contract, constructor parameters as named constants, residue as `% TODO` blocks, a source that does not compile as a `% TODO` comment |
| `replay_fetch.js`, `sol_replay.pl` | the replay validation (§6.1) |
| `contracts/` | the reference contracts (OpenZeppelin compositions, the FiatToken subset, the E12 vault) |
| `e13/` | the atomicity experiments (E13) |
| LPS2's `src/syntax/lps_solidity.pl` | **LPS2's Deploy as Solidity** (its M12g): the way back, an LPS program (or an LE-for-LPS document) as one contract, or a refusal naming every feature that has no straight translation |
| LPS2's `src/syntax/lps_solidity_cost.pl` | what the written contract will cost, **measured**: the deployed and creation sizes against EIP-170/3860 (a refusal above either), the gas of each call of the program's own scenario, the intrinsic and calldata a transaction also pays, solc's own estimates reported and not relied on, and the budgets the program states checked against all of it (the design notes `ExtendingLanguagesCoverage.md` §2.1.5–2.1.6) |
| `sol_prune.pl` | whether a path can happen at all: its conditions as linear inequalities over `clpq`, so that a Panic path the function has already ruled out is not written. Rationals rather than finite domains on purpose — the reasoning is over `0 .. 2^256 - 1`, where `clpfd` would have to label |
| LPS2's `tools/solidity_test.pl`, `src/syntax/solidity_evm.cjs` | that writer's own gate: the refusals, and each twin written back, compiled with solc and replayed on an in-process EVM until its state is LPS2's — and, since 20 Sep 2026, the cost report, the stated budgets and the overflow notes |
| `test_solidity.pl` | 48 plunit tests: front end, twins (final state and call by call), round trip, the five Phase 1e changes, replay (its negative control, its laws the twin's), E13, legal views (drawn from each twin and its run) against their twins, E12, the importer |

Twins, ledgers and replay data: `lps2/examples/migration/solidity/`
(in the LPS2 repository).

## How to run

```sh
cd migration/solidity
npm install                          # solc 0.8.26 (solcjs) and @openzeppelin/contracts 5.0.2
# the twins, their ledgers and their contracts (in sources/); legal views are computed by the editors:
/work/myswipl.sh -q -g "consult('sol_migrate.pl')" -g "sol_migrate:migrate_all" -t halt
# a twin, run:
LPS_LE2_DIR=/work /lps2/lps run /lps2/examples/migration/solidity/erc20/erc20.le
# a replay on a fresh window of USDC (public RPC, no key):
node replay_fetch.js --blocks 12 > /lps2/examples/migration/solidity/replay/usdc_window_12.json
/work/myswipl.sh -q -g "consult('sol_replay.pl')" -g "sol_replay:replay('/lps2/examples/migration/solidity/replay/usdc_window_12.json')" -t halt
# the tests (about 40 s; LPS2 runs as a subprocess):
/work/myswipl.sh -q -g "consult('test_solidity.pl')" -g run_tests -t halt
```

Deploy as Solidity's own gate, from this repository's root (it needs LE2 and an
LPS2 checkout; it points LPS2's `LPS_PLUS_DIR` back at itself, so it tests
these files). solc comes from the `node_modules` above; the EVM from the LPS2
checkout's `build/evm/node_modules`
(`npm i --prefix <lps2>/build/evm @ethereumjs/vm@10 @ethereumjs/common@10 @ethereumjs/util@10`),
and what is missing is skipped rather than passed:

```sh
(cd ../lps2 && LPS_LE2_LIB=<this LE2> ./myswipl.sh -q -g "consult('tools/solidity_test.pl')" -g "solt:main" -t halt)
```

Needs node (22 used), SWI-Prolog, LE2 and LPS2. `../le2_paths.pl` finds
them: the LE2 (and LPS2) the process already runs in, then `$LE2_DIR` (or
LPS2's `$LPS_LE2_LIB` / `$LPS_LE2_DIR`) and `$LPS2_DIR`, then checkouts beside
this repository (`../LogicalEnglish2`, `../lps2`), then `/work` and `/lps2`.

## The mapping, as implemented

One **path** per branch decision through a public/external state-changing
function, with modifiers inlined around the body, internal calls inlined,
`super` and virtual overrides resolved on the C3 linearisation, and base
constructors run from a constructor's modifier list. Along a path the
executor keeps the conditions (over the parameters, the caller and the state
before the call) and the storage writes in order; infeasible paths (a
condition and its negation, `msg.sender == address(0)`) are pruned.

| Solidity | LE for LPS |
|---|---|
| `uint x` | fluent `the x of the token is *an amount*; 0 by default` (reviewed: `the total supply is *an amount*`) |
| `mapping(address k => uint)` | fluent `the balance of *an account* is *an amount*; 0 by default` — one argument per key, nested mappings included |
| `bool b`, `mapping(address => bool)` | a proposition: `the token is paused`, `*an account* is on the blacklist` (initiated / terminated) |
| `address a`, `string s`, a contract-typed variable | a fluent holding one value; a new value terminates the old; an address is `the zero address by default`, which is also what its absence reads as |
| public / external function `f(p…)` | action `*a caller* … *p* …` — the caller (`msg.sender`) first; reviewed wording for the ERC-20 / Ownable / Pausable / FiatToken functions, `*a caller* calls f with p *a …*` otherwise |
| a revert path (`revert E()`, `require(c, "msg")`, a modifier's check) | `it must not be true that <call> and <the path's own conditions>`, headed by `% reverts: E` — LPS refuses the whole call, which is the EVM's revert |
| the guards before it (`require`s that passed) | left out: each guard's failure is a constraint of its own, and the union of the constraints is the same |
| a success path's storage writes | one `when <call> [and <branch conditions>] then …` law per write; `x[k] += d`, `x[k] = x[k] - d` become `… that is N becomes N + d` (relative), anything else `… becomes <expression>` |
| Solidity's zero default of mappings | the fluent's `; 0 by default` (Phase 1e (a)): an absent entry reads as 0 and an update reads 0 as its old value — no law materialises it, no read has an absent variant (before: 86 of the ERC-20 twin's 181 law lines) |
| `if … else …` with both sides succeeding | the branch condition on the laws of each side |
| `x // y`, `x % y` | LE's `//` and `mod` (E4) |
| a checked `+ - *` that can overflow on its path | one more constraint, `reverts: Panic 0x11`, with the ceiling as the named constant *the largest amount*; one the path already forbids is not written (`sol_prune.pl`) |
| a checked `/ %` whose divisor can be zero | one more constraint, `reverts: Panic 0x12` |
| `unchecked { … }` | no constraint: the plain arithmetic where the path or the block's own comment forbids the wrap, `mod 2^256` where neither does — one ledger row per block either way |
| `emit Event(…)` | the call itself records it (ledger: approximated; the logs are what the replay reads) |
| `view` / `pure` functions | the fluent answers them (ledger) |
| constructor | `initially …` from the instance's arguments (`constructor_args`), state variables' initialisers included |
| external calls, assembly, `delegatecall`, anything else not read | a **residue** block with the function's source, for the Contract Assistant (residue mode) or a person; the function's other paths are still translated |
| `type(uint256).max`, a `constant` state variable | a named constant (`the constants are:` / `the unlimited allowance is 1157…`), read by its name (sol_names:constant_name/3) |
| `for (uint i = 0; i < xs.length; i++)` over an array parameter | summarised by pattern (Phase 1e (d)): a `+=`/`-=` keyed by the element → one law per key in the list, by the count of its occurrences; a sum into a local → `a total is the sum of each an element such that …`; a `require` in the loop → a constraint that some element fails it; `xs.length` → a count. An order-dependent loop (a branch or `break` in it), two arrays indexed by `i`, or a storage array: residue |
| a contract that inherits a reference model | written as what it adds (Phase 1e (b)): `the knowledge base my token extends erc20, pausable.`, the bases' twins copied beside it; if the contract takes away a base's law, written whole, and the ledger says why |

Every translated element is a row of the twin's ledger
(`<twin>.ledger.md` / `.json`, from `le_migration.pl`): state variables,
functions (paths → laws / constraints), events, views, the constructor —
encoded, approximated (events), or residue, with wording generated from
identifiers flagged "to review".

**The written twin reads back to the same LPS terms.** For every twin the
terms the front end generated and those LE parses from the English it wrote
are variant-equal term by term (39 for the ERC-20, 99 for the FiatToken
subset; `test_solidity.pl`, `round_trip_*`).

## The reference models (E11) and their scenarios

| Twin | Source | LPS laws + constraints | Scenario run by LPS2 (expected final state) |
|---|---|---|---|
| `erc20` | OpenZeppelin 5.0.2 `ERC20` + an initial mint (`contracts/RefERC20.sol`) | 18 | 6 calls: a transfer beyond the balance and a `transferFrom` beyond the allowance refused, a transfer to oneself unchanged — 5 expected values |
| `ownable` | OpenZeppelin `Ownable` | 6 | 4 calls: a stranger and the old owner refused, hand-over, renouncement — no owner at the end |
| `pausable` | OpenZeppelin `Pausable` + `Ownable` — extends `ownable` | 12 | 5 calls: a stranger refused, pausing twice refused (`EnforcedPause`) — owner, paused |
| `mytoken` | a token after those of the OpenZeppelin Contracts Wizard: ERC20 + Ownable + Pausable, owner mints (`contracts/MyToken.sol`, written for this folder; the Wizard's own output inherits `ERC20Pausable`) — extends `erc20` and `pausable` | 38 (flattened) | 8 calls: an overdraft, a mint by a non-owner and a transfer while paused refused, a transfer to oneself unchanged — 4 expected values |
| `fiat_token` | Circle's FiatTokenV1 logic (Ownable, Pausable, Blacklistable, minters with allowances), `contracts/FiatTokenSubset.sol` | 71 | 14 calls: a mint beyond the minter's allowance, transfers from and to a blacklisted account, a `transferFrom` beyond the allowance, a burn beyond the balance and a transfer while paused refused — 8 expected values |
| `airdrop` | batch calls, `contracts/Airdrop.sol`: an airdrop to a list, a burn of a list of amounts, and an order-dependent search (residue) | 7 | 4 calls: a recipient listed twice credited twice, a burn beyond the balance and an airdrop to the zero address refused — 4 expected values |

The expected values of these scenarios were worked out by hand from the
Solidity sources (the catalogue in `sol_migrate.pl`): the reference contracts
themselves were not run on an EVM for them. The checks made by a machine are
the replay below, against the chain, and LPS2's gate, which writes five of
the twins back as contracts (`airdrop` and `vault` are not in its list) and
runs each on an EVM against LPS2's own run.

An instance is bound to a reference model by `initially` facts — its
constructor's arguments, or the state read from the chain — and the twin's
header comment cites the match (for USDC: the implementation behind the proxy
at the replayed block, `0x43506849…02dd`, which Sourcify lists as a verified
match of FiatTokenV2_2 — `match`, not `exact_match`, when read again on 24
November 2026; the comment's words "full match" are a fixed text of
`sol_replay.pl`, not a lookup). `initially` takes no provenance trailer, hence
the comment.

## Validation by replay (§6.1)

`replay_fetch.js` reads, from a public node (publicnode, no key), a window of
USDC's Transfer, Mint and Burn logs, the balance of every account they touch
and the total supply before and after the window, and the minters'
allowances; `sol_replay.pl` binds the FiatToken twin to the state before the
window, renders each log in chain order as one observed call (a Transfer as
`transfer`, a mint as `mint` by the minter its Mint log names, a burn as
`burn`), runs it with LPS2 and compares.

| Window (Ethereum mainnet, 13 Sept 2026) | Calls replayed | Values compared | Agree with the chain | LPS2 |
|---|---|---|---|---|
| blocks 25968821–25968823 (`replay/usdc_window.json`) | 201 (197 transfers, 3 mints, 1 burn) | 215 | **215** | 1.6 s |
| blocks 25968820–25968831 (`replay/usdc_window_12.json`) | 822 (810 transfers, 10 mints, 2 burns) | 849 | **849** | 11.4 s |

Every one of the 822 calls was accepted (none refused by a constraint), and
every balance and the total supply the twin reaches are the chain's.
**Negative control:** the same window against a twin whose fluents declare
no default (`sol_mutation(no_default)`) agrees on only 165 of 215 values —
the replay does discriminate.

Approximated, and said so in the results: a Transfer made by `transferFrom`
is replayed as a `transfer` by the owner of the funds (the same balances; the
allowance spent is not in the logs); Approval logs are not replayed. USDT
(`TetherToken`, Solidity 0.4.17) is not one of the reference models and was
not replayed.

## E13 — LPS transaction atomicity, established by experiment

`e13/*.le`, each run with LPS2 (`test_solidity.pl`, `solidity_e13`):

1. **A call refused by an integrity constraint has no effect at all**
   (`refused_call.le`): LPS2 checks the constraints against the whole event
   before any law fires. That is the EVM's revert, for free.
2. **Laws are independent** (`vanishing_tokens.le`): a law whose conditions
   fail does not fire while the others do. With an `updated` law alone, a
   transfer to an account holding no balance fluent debits the payer and
   credits no one — ten tokens vanish. This is the one real atomicity gap, and
   it is a *translation* gap: Solidity's mappings are total (zero by default),
   LPS fluents are not.
3. **One action's effects apply in serial micro-states** (LPS2's
   `apply_serial_action/2`): initiations first, then each update to the state
   produced so far. So an unguarded initiation of the default and an update
   of the same entry compound (`compounding_default.le`: 20 received for 10),
   and — the useful side — two updates of one entry in one call compose in
   order, as the EVM's successive storage writes do (`self_transfer.le`: a
   transfer to oneself leaves the balance unchanged).

**Conclusion (first round): no change to the engine was needed**: the
translator closed gap 2 by materialising each written entry's default in an
`initiated` law guarded by its absence. **Since Phase 1e (a)** (14 September
2026) gap 2 is closed where it belongs — the fluent is declared `0 by default`
(LPS2's `defaults/1`), an absent entry reads as 0 and an update of it reads 0
as its old value — and the materialisation laws are gone. The translator
still relies on 3 for the ordering, and gives every law of a path the path's
conditions, so a successful call fires all of them and a refused one none.
The replay's negative control is the empirical check (its mutant now declares
no default). `e13/*.le` keep the undeclared form: they are the experiments
that motivated it.

Two LE-side fixes found on the way (in `le_lps.pl`, see the report): `… is
equal to 5` was read as the prospective form `… to 5` (an integer time), and
an update `… becomes amount` with a bare name dropped the whole law without
a word.

## E10 — the legal-readable view

The view is now LE2 core's (`le_lps_legal.pl`), because nothing in it is
about Solidity: it is a fixed transformation of **any** LE-for-LPS program,
and both editors offer it as a command (LE editor: **Misc ▸ Legal View of
This LPS Program**; LPS2 IDE: **View ▸ Legal view**). It is computed whenever
it is asked for, never stored: with the program's run (the LPS2 server's), it
also has a scenario with the state before each call of the twin's scenario and
the questions whether each call may be made and what it changes, as
expectations — `test_solidity.pl` draws each twin's view that way
(`sol_migrate:legal_view_text/2`) and checks it agrees with the twin. For
example:

```le
% who may blacklist: none of the action's integrity constraints applies
a blacklister may blacklist an account if
    the blacklister of the token is the blacklister.

% who may transfer: none of the action's integrity constraints applies
a sender may transfer an amount N to a recipient if
    it is not the case that
        the balance of the sender is an amount M
        and N > M
    and it is not the case that
        it is not the case that the balance of the sender is a third amount
        and N > 0
    and it is not the case that the recipient is equal to the zero address
    and it is not the case that the recipient is on the blacklist
    and it is not the case that the sender is on the blacklist
    and it is not the case that the token is paused.

a blacklister blacklisting an account results in the account being on the blacklist.
```

One `may` rule per action (none of its constraints applies; a role check —
"the owner is someone and is the caller" — is written as the positive
condition it is, so "which blacklister may blacklist carol" has an answer),
one effect rule per law (`… results in … being …`, `… no longer being …`; the
zero-default materialisations are left out). The wording is the program's own
templates, by English morphology (`transfers` → `may transfer`,
`transferring`), with fixed words for a template that does not start with its
actor and a verb, or in another language. A constraint on two actions at once
and an action nothing governs (a residue) are said in comments, not turned
into permissions. The state is the scenario; questions are queries; the
counterfactual is a flip query: with carol blacklisted, `which minimal change
to the scenario makes it the case that carol may transfer 10 to bob` answers
`remove: carol is on the blacklist`.

What `sol_migrate:legal_view/1` adds for a twin is its questions, **checked
against the twin**: for each call of the twin's scenario, the state just
before it as LPS2 computed it (`before_call_N`), `may_call_N` expected to hold
exactly when the twin accepted the call, and the effect queries of an accepted
call expected to name the entries it changed. Across the six twins, 72
expectations, all passing; the one kind of divergence, a transfer to oneself
(two laws touching one entry: the view states each law's effect, the twin
composes them), is written as a comment in its scenario, not as an
expectation.

## E12 — external oracles, as a convention

`contracts/Vault.sol` borrows against collateral valued by a price feed. The
front end translates `deposit` and leaves `borrow`, which calls the feed, as
residue (`vault/vault.le`). Filled by the convention (no syntax):

- **in the twin** (`vault/vault_oracle.le`), the feed's value is a *fluent*
  set by an *event* of the environment (`the price feed reports *an amount*`,
  its own update transaction or a reading at the call); the call's check is
  then an ordinary constraint over that fluent. Run by LPS2: at price 2, a
  borrow of 90 against 100 is accepted and a further 150 refused; after the
  feed reports 1 and 200 more collateral arrive, a borrow of 60 is accepted
  (debt 150);
- **in a legal view** (`vault/vault_view.le`), it is an `; assumable`
  template phrased as the question a borrower asks — `the price of the
  collateral is at least *a number*` — so without a stated price the answer is
  conditional (`alice may borrow 90`, unknown: `the price of the collateral is
  at least 1.8`), and with one `according to the price feed` it is outright. A
  live feed is the same template with `; via service feed` and a declared
  service (`le_summary.md` §17.6): attributed, cached, materialisable.

## Licences

- OpenZeppelin Contracts 5.0.2 — MIT, copyright zOS Global Limited and
  contributors (installed by npm, not vendored). The twins `erc20`,
  `ownable`, `pausable` and `mytoken` are translations of its contracts: its
  licence text is beside them, `LICENSE-OpenZeppelin.txt` in LPS2's
  `examples/migration/solidity/`.
- Circle `stablecoin-evm` — since its release 2.2.0 `contracts/v1/FiatTokenV1.sol`
  and `Blacklistable.sol` are Apache-2.0, copyright Circle Internet Group,
  Inc. (releases 2.0.0 and 2.1.0 were MIT, copyright CENTRE SECZ);
  `contracts/v1/Ownable.sol` and `Pausable.sol` are still MIT: Circle's forks
  of OpenZeppelin's, copyright zOS Global Limited, Smart Contract Solutions,
  Inc. and CENTRE SECZ. `contracts/FiatTokenSubset.sol` is a changed copy of
  parts of those four files in Solidity 0.8; its header carries their notices
  and lists the changes.
- The other contracts in `contracts/` (`RefERC20.sol`, `RefOwnable.sol`,
  `RefPausable.sol`, `MyToken.sol`, `Airdrop.sol`, `Vault.sol`) were written
  for this folder. Their first line offers them under the MIT licence.
- The Solidity compiler — GPL-3.0. It comes inside the npm package `solc`
  (solc-js, whose own JavaScript is MIT), which `npm install` downloads: a
  tool that is run, never copied into this repository. No compiled bytecode
  is kept here either.
- Chain data — public (Ethereum mainnet, read through the public endpoint
  of publicnode.com, without a key); Sourcify match metadata — public.
- Solidity, OpenZeppelin, Circle and USDC are named to say what was read and
  replayed. Their makers took no part in this work and did not review it.

## Gaps

- Solidity subset: loops only over one array parameter and by the patterns
  above; no structs, storage arrays, `delegatecall`/proxies (the proxy is
  bound, not translated), assembly, try/catch, external calls (all residue);
  the gas bound of a loop is not modelled (the overflow of checked arithmetic
  is: the `Panic 0x11` constraints of the table above).
- Solidity 0.4–0.7 sources (USDT, the real FiatTokenV2_2) are not compiled by
  solc 0.8; the FiatToken model is a transcription, bound to USDC by the
  Sourcify match of the logic it keeps.
- Events are not LPS events; `transferFrom` and approvals are not replayed.
- Wording beyond the reviewed table is mechanical (flagged in the ledger).
- The reference-model library is five models (ERC-20, Ownable, Pausable, the
  Wizard composition, FiatToken); Safe, Uniswap V2/V3, Aave, Compound, stETH
  and USDT are not yet curated.
- The legal view's `may` rules are faithful but literal (a double negation
  where the source reads "if the sender has no balance, the amount must be
  0"); polishing their wording is assistant work over a fixed meaning.

## Implementation status (for §8, Phase 1e)

> **Implemented 13 September 2026** (`LE2 migration/solidity/`, twins in
> `lps2/examples/migration/solidity/`). A solcjs front end (typed AST) with a
> symbolic executor — modifiers, internal calls, `super` and overrides
> inlined, one LPS law per success path and one integrity constraint per
> revert path, Solidity's zero default materialised — writes LE-for-LPS
> twins through `le_writer.pl`; the written English reads back to the same
> LPS terms. Reference models (E11): OpenZeppelin ERC-20, Ownable, Pausable,
> their Wizard composition, and Circle's FiatToken logic, each with an LPS2
> scenario reproducing the EVM's outcome. **Replay** of 822 consecutive USDC
> calls from mainnet (12 blocks) against the FiatToken twin bound to the
> chain's state: 849 of 849 balances and the total supply agree; a mutant twin
> fails. E10: a legal-readable view (may-rules, effects) derived from the
> twin, with flip queries. E12: external oracles as a convention (fluent + event
> in the twin, `; assumable` or a service in a view), worked on a vault. E13:
> LPS2 refuses a constraint-violating call whole and applies an action's
> effects in serial micro-states; the only gap (independent laws over partial
> fluents) is closed by the translator, no engine change. Not done: USDT and the
> other DeFi reference models, Vyper, proxies beyond binding, replay of
> allowances.

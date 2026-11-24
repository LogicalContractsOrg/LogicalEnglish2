# Bitcoin Miniscript → Logical English (Phase 1d)

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

The translator of the design notes `roadmap.md` §6.4: a Bitcoin
spending policy — written in the Miniscript policy language, in Miniscript
itself, or as an output descriptor around either — becomes a Logical English
program that says **who can spend the coin, when, and why**, with its own
tests, a key-loss analysis, a ledger and a custody-explainer view. It uses the
shared migration machinery of LE2 (`le_writer.pl`, `le_migration.pl`,
`lib/temporal`; see LE2's `docs/dev/migration.md`) and nothing source-specific
lives in LE2.

| File | What it does |
|---|---|
| `miniscript.pl` | parser (policy language, Miniscript fragments and wrappers, `wsh`/`sh`/`tr` descriptors, key origins, checksums), lifting to the abstract policy by BIP 379's semantics column, the evaluator (`ms_eval/2`, the fidelity oracle) and the satisfaction analysis (`ms_satisfactions/2`) |
| `ms_twin.pl` | policy → Migration IR, source tests, flip tests, view and ledger; `build_twin/3` writes a twin directory |
| `policies.pl`, `core_wallet_policies.pl` | the twelve real policies, their key legends and citations |
| `sources/` | the cited text excerpts (copied beside each twin, so quotations are checked) |
| `build.pl` | builds the twins into this repository's `examples/migration/miniscript/<id>/` |
| `ms_import.pl` | the File ▸ Open adapter (LE2's `le_import.pl` registry, `migration/le_importers.pl`): a file of policies → twins |
| `ms_export.pl` | the way back, File ▸ Export (LE2's `exporter/6` registry): an LE program in the twins' vocabulary → the policy, sipa's Miniscript, the descriptor (when the program states the keys) and a Minsc link |
| `ms_chain.pl`, `chain/ms_chain.cjs` | the twin on a real chain — RewindBitcoin's **Tape** test chain, or a private regtest `bitcoind` — and in **Minsc**; sipa's policy compiler (`@bitcoinerlab/miniscript-policies`) |
| `chain.pl` | runs every twin's spending attempts on a chain and records them (`chain/runs/<id>.tape.json`) |
| `chain/check_minsc.cjs` | opens every twin's Minsc link in a headless browser and reports what Minsc compiles |
| `sources/originals/` | the files the cited excerpts come from, whole: Bitcoin Core's and Liana's files with their licences. The Miniscript page states no licence, so the page is not copied — see [Sources and licences](#sources-and-licences) |
| `fetch_bitcoind.sh` | Bitcoin Core for the private regtest backend, into `.cache/` |
| `test_miniscript.pl` | plunit: parser, lifting, semantics, an end-to-end twin, LE–policy agreement on every attempt, the File ▸ Open adapter, the export round trip, the re-import of every twin's `.policy` original, the chain scenarios |

## How to run

From the LE2 checkout (`/work`), which provides `le_kbs`, `le_writer` and
`le_migration`:

```sh
./myswipl.sh -q migration/miniscript/build.pl              # all twins
./myswipl.sh -q migration/miniscript/build.pl liana_recovery
./myswipl.sh -q -g run_tests -t halt migration/miniscript/test_miniscript.pl
```

Each twin directory holds `<id>.le` (the program, its scenarios, flips and
view), `<id>.ledger.md` / `.ledger.json`, `temporal.le` + `temporal.pl`
(the library, copied) and `sources/`: the cited excerpt, `<id>.policy` (the
policy as File ▸ Open takes it back: title, key legend, the source's text,
sipa's compilation, the Minsc link), `originals/` (the page or files the
excerpt comes from, whole) and `<id>.chain.json` (the recorded chain run).

The chain tools need Node and `npm install` in `chain/` (the twins still
build without them: no Minsc link and no compiled Miniscript, then); the
chain runs need the network:

```sh
(cd migration/miniscript/chain && npm install)
./myswipl.sh -q migration/miniscript/chain.pl                  # every twin, on Tape
NETWORK=regtest ./myswipl.sh -q migration/miniscript/chain.pl -- cosigning_service
(cd migration/miniscript/chain && npm run check-minsc)         # every Minsc link
```

The twins also run in LE2's core example suite (`testing/run_tests.sh le`);
the twelve load and run in about five seconds.

## Reading the source in a twin

Each twin's header shows what the source said four ways, so a reader need
not decode a descriptor:

```
% The source, as written:
%     or(pk(key_revocation),and(pk(key_remote),or(pk(key_local),hash160(H))))
%
% The source, laid out (keys and hashes by their role, <like this>):
%     or(
%       pk(<the revocation key>),
%       and(
%         pk(<the remote node>),
%         or(pk(<the local node>),hash160(<the payment hash>))))
%
% The legend (role <- key or hash as written in the source):
%     the revocation key <- key_revocation
%     ...
%
% What it says (the spending policy, by BIP 379's semantics):
%     any one of these:
%       a signature by the revocation key
%       all of these:
%         a signature by the remote node
%         any one of these:
%           a signature by the local node
%           the preimage of the payment hash (hash160)
```

— verbatim (a descriptor longer than 100 characters cut into lines of 100),
laid out in its own notation (`miniscript:ms_layout/3`: a node that fits in
64 columns stays on one line, `thresh(k,` / `multi(k,` open their block),
the legend, and the lifted policy in words with the delays in blocks and
approximate time. The cited excerpts under `sources/` are plain text, one
paragraph per line, which the source viewer shows wrapped.

## Opening a policy file in the editor (File ▸ Open)

`ms_import.pl` is the adapter LE2's `le_import.pl` calls for a file of
policies (`.miniscript`, `.ms`, `.policy`, `.desc`, `.txt`): one policy,
Miniscript expression or descriptor per line; `#` lines are comments (the one
above a policy is its title); `name = role` lines name keys and hashes. The
first policy is the program opened, each further one a program of its own
beside it (`<stem>_2.le`, ...), each the same translation as the catalogue's
(cited rules quoting their line of the file, which is copied under
`sources/`; the satisfaction analysis as scenarios; flips; a view). A line
that is not a policy (a bare word is not one) is kept in the first program as
a residue block — a `% TODO` comment with the line and the parser's
complaint. A file with no policy at all is not claimed.

```prolog
ms_import:import_miniscript(+File, +OutDir, -imported(LEFile, Notes)).
ms_import:detect_miniscript(+File).
```

## The originals, and the way back (File ▸ Export)

Every twin keeps what it was translated from beside it (LE2's `sources/`
convention, File ▸ Show the Original): the cited excerpt, the files it
comes from whole (`sources/originals/`:
Bitcoin Core's `descriptors.md`, `miniscript_tests.cpp`,
`wallet_miniscript.py` with `COPYING` (MIT), Liana's `README.md` and
`RECOVER.md` with `LICENCE` (BSD-3)), and **`<id>.policy`**, the policy in
the format File ▸ Open reads. For the Miniscript page, which states no
licence, only the quoted example policies are kept, not the page.

The twin states what a descriptor needs, so the program is complete
without its sources: `the public key of the primary key is "[a5c6b76e/…]tpub…"`
for every real key and `the hash function of the payment hash is hash160`
(with `the hash value of … is "…"` for a real hash) — facts, read by the
queries `keys`, `hash_functions` and `hashes`.

**File ▸ Export to Another System…** (LE2's exporter registry; in the LPS2
IDE, Misc ▸ Export to another system…) writes such a program back
(`ms_export.pl`): it reads the rules concluding `the coin can be spent` by
their templates — signatures, preimages, the coin's age, lock times,
counts over keys or named conditions, `or` of the rules — into the policy
language, compiles it with sipa's compiler (`@bitcoinerlab/miniscript-policies`,
the reference C++ compiler in WebAssembly), writes the descriptor when the
program states the keys, and links the result to Minsc. A condition in
another vocabulary (or an integrity constraint, which a policy cannot state)
refuses the export, each with its line, rather than being dropped: the check
runs before anything is written (`check_miniscript/3`, le_import's
`export_check`).
The program need not be a twin: any program in this vocabulary exports, so
a spending policy can be *written* in Logical English and exported as a
policy, to be checked like any other policy before a coin is sent to it.

Two tests close the loop on all twelve twins: exporting the twin gives back
the source's policy (the same spending paths, keys and hashes by role,
locks, hash functions), and `sources/<id>.policy` opened again through
File ▸ Open gives a program whose policy is the same.

## Try it in Minsc, and on a chain

**Minsc** (`min.sc`, rust-miniscript in WebAssembly) takes the code itself
in its link (`https://min.sc/#c=<the code, URI-encoded>`, verified in its
page's source). Each twin cites `the policy in Minsc` with such a link: one
variable per key or hash, named after its role, holding the source's key
(a descriptor key's `/<0;1>/*` as its receive branch `/0/*`) or, where the
source only names it, the chain run's test key. `check_minsc.cjs` opens all
twelve: eleven compile to a descriptor and a testnet address; for
`hash_threshold` Minsc answers *"Top Level script is not safe on some
spendpath"* — two preimages spend it with no signature, which is a verdict
on the policy (Bitcoin Core's test vector is deliberately so), not on the
link.

**The Tape network** (RewindBitcoin's test chain,
<https://tape.rewindbitcoin.com>, which its operator runs on one node and
opens to the public: regtest addresses, a faucet, an Esplora API and an
explorer; a block about every ten minutes during the run) is where the twins
are *run*. The public signet and testnet faucets tried in September 2026
wanted a login or a captcha; Tape's did not. Tape's page does not name its
node software: the refusals in the record are Bitcoin Core's
(`sendrawtransaction RPC error -26: non-BIP68-final`). `chain.pl` takes each twin's satisfaction
analysis — for each spending path, all it needs, then each signature or
preimage left out, and nothing at all — as the material a spender has, and
`chain/ms_chain.cjs` does what a wallet does: it asks the Miniscript
satisfier for a witness made of that material (lock-free first), sets
`nSequence` / `nLockTime` for the locks, signs with **test keys** derived
from the role names (nobody holds the source's keys; the policy's structure
is the source's), broadcasts, and records what the node says. When the
material makes no witness, it offers the path's witness with the missing
part left out (an empty signature, a wrong preimage), so the chain still
judges a transaction. One faucet coin per twin; each accepted spend pays
back to the policy, and the next attempt spends that.

`build.pl` writes each run into its twin as **chain scenarios** (the code
and older notes call them *chain-confirmed*: the chain's verdict, accepted or
refused, confirms the twin's answer — not a transaction confirmed in a block)
(`chain_revocation`, `chain_family_2_without_1`, …, named after the rule
the path satisfies, as the satisfaction scenarios are — a run recorded
before 16 September 2026 numbered its attempts `path_<i>` in the analysis's
order, and `ms_chain:attempt_name/4` renames them; the citation keeps the
run's own id): the witness's signatures and preimages, the block of
the coin and of the spending transaction (the chain's next block), the lock
time — and the chain's verdict as the expectation, cited as
`as stated in the Tape run of 2026-09-14 at transaction <txid>` (or `at the
refusal of attempt …`, with the node's reason as a comment); the run's
record is the document (`sources/<id>.chain.json`), its explorer page the
address.

*Results (14 September 2026):* 90 attempts on eleven twins, 16 accepted and
74 refused. *Accepted* is the node taking the transaction into its mempool:
the run does not wait for a block, and every coin was still unconfirmed when
it was spent, so a scenario's block of the coin and of the spend is the
chain's next block. The 16 accepted spends are all of paths without a lock
(`nLockTime` 0, an `nSequence` that sets no relative lock): on Tape every path with `older` or
`after` is checked by its refusal only (the private regtest below accepts
the `older` paths). The refusals are by script failure (a missing
signature: *Script failed an OP_CHECKSIGVERIFY operation*, *Signature must be zero for failed CHECK*; a
wrong preimage: *OP_EQUALVERIFY*), by BIP 68 (*non-BIP68-final*: the coin
too young for `older`) or by BIP 65/113 (*non-final*: a lock time not yet
past). **Every verdict agrees with its twin** (all 361 expectations of the
twelve twins pass, 90 of them the chain's). `hash_threshold` has no run: its
Miniscript is not *sane* (a path without a signature), and the wallet
libraries refuse to build it.

*What the chain found.* The first run disagreed with the twins on 15
attempts (14 in `halving_decay`, 1 in `revault_unvault`): spends whose
material meets an `after()` path, refused as *non-final*. BIP 379 reads
`after(t)` as "the lock time is at least t", and so did the twins and the
translator's evaluator; but consensus also wants the lock time *past* — a
transaction whose lock time is not below its block's height (or median
time) cannot be mined. The twins now say so: an `after()` path reads

```le
    and the spending transaction has the lock time a number N
    and the lock time N is a block height
    and N >= 424242
    and the spending transaction is in block a height M
    and N < M.
```

and the evaluator treats a lock time that is not past as none. The
satisfaction analysis puts its spends after their lock times, so its
expectations did not change.

**A private regtest** (`NETWORK=regtest`, Bitcoin Core from
`fetch_bitcoind.sh`) runs the same attempts with one coin each, buried under
enough blocks for every relative lock (up to 20000): there the `older` paths
are *accepted*. It is slower (mining 12960 blocks takes about five minutes)
and private, so it is a check rather than the published run.

## The mapping

| Miniscript / policy | Logical English |
|---|---|
| `pk(K)`, `pkh(K)`, `pk_k`, `pk_h`, `c:` | `the witness contains a signature by <role>` (a scenario element) — the key named by its role from the legend, else `key A`, `key B`, … |
| `sha256/hash256/ripemd160/hash160(H)` | `the witness reveals the preimage of <name>` |
| `older(n)` (blocks) | `the coin has been confirmed for a number N blocks and N >= n`, the age from `the coin was confirmed in block H` and `the spending transaction is in block M` |
| `older(n)` with BIP 68's time flag | the same in seconds (`512 × (n & 0xffff)`), from `... at the time T` |
| `after(t)` | `the spending transaction has the lock time a number L and the lock time L is a block height` (or `is a time`, lib/temporal) `and L >= t`, and the lock time past: `the spending transaction is in block a height M and L < M` (at the time, for a time lock) — a lock time of the other kind never meets it |
| `and`, `and_v`, `and_b`, `and_n` | `and` |
| `or`, `or_b`, `or_c`, `or_d`, `or_i` | `or`; a top-level `or` is **one rule per spending path**, labelled (`rule recovery with provenance ...`) |
| `andor(X, Y, Z)` | `(X and Y) or Z` |
| `thresh(k, keys)`, `multi(k, ...)`, `multi_a`, `sortedmulti` | `a number N is the count of each K such that a key K is in [the keys] and the witness contains a signature by K`, `and N >= k` (k = n: the signatures, one per line) |
| `thresh(k, conditions)` | the same count over **named conditions** (`the signature of key 1`, `the delay of 12960 blocks`, ...), each with a rule of its own |
| `tr(K, {leaves})` | `K`'s signature, or any leaf |
| wrappers `a s c d v j n t l u`, probabilities `9@`, `wsh`, `sh` | no effect on who can spend (BIP 379): ledger entries, nothing in the rules |
| witness sizes, fees, malleability, fragment choice | not in the twin — one **approximated** ledger entry: the twin is the policy, not the Script |

**Tests are the policy's own analysis.** Each minimal satisfying set (spending
path) is a scenario that meets exactly its requirements, named after the rule
(the top-level `or` branch) it satisfies — `revocation`, or `family_1`,
`family_2` when a rule can be met in several ways (`ms_twin:named_sets/3`) —
and each path yields
**near misses**: one requirement removed — a signature or preimage missing, a
delay one block (one second) short, a lock time one below — plus an empty
witness. Every expected answer is computed by `miniscript:ms_eval/2` on the
policy tree, never by the LE program; `test_miniscript.pl` further checks that
the LE program and the evaluator agree on **every** combination of signatures
and preimages, before and after the delays.

**Flips are the key-loss analysis (§17.7).** Every twin asks `which minimal
change to the scenario makes it the case that the coin can be spent` with
nothing signed, now and after every delay (the minimal sets of signatures and
preimages that suffice), and, for each key (up to six keys), with that key
lost and everything else given: if the coin can still be spent, `... makes it
the case that it is not the case that the coin can be spent` lists the
smallest sets of facts whose removal would then block it — the keys (and
timelock facts) that become indispensable once that key is gone. Every
expected change set is computed from the policy.

**The view** `custody explainer` shows the witness facts and the timelock
facts as the case, whether the coin can be spent, its reasons and citations,
and the flip (keeping the timelock facts, so a flip never proposes to change
the block heights).

## Results (13 September 2026)

| Twin | Source | Keys | Paths | Scenarios | Flips | Expectations passing | Ledger (enc/approx/residue) |
|---|---|---|---|---|---|---|---|
| `core_2of3_multisig` | Bitcoin Core `doc/descriptors.md` | 3 | 3 | 15 | 5 | 18/18 | 7/1/0 |
| `liana_recovery` | Liana `doc/RECOVER.md` (a real descriptor) | 2 | 2 | 10 | 4 | 12/12 | 10/1/0 |
| `liana_inheritance` | Liana README (prose → policy) | 5 | 5 | 25 | 7 | 30/30 | 9/5/0 |
| `cosigning_service` | sipa's Miniscript page (2FA service) | 2 | 2 | 11 | 3 | 12/12 | 5/1/0 |
| `decaying_multisig` | sipa: 3-of-3 → 2-of-3 after 90 days | 3 | 4 | 22 | 5 | 25/25 | 6/1/0 |
| `halving_decay` | Bitcoin Core: 4-of-4 decaying at each halving | 4 | 35 (13 sampled) | 72 | 6 | 76/76 | 13/1/0 |
| `bolt3_to_local` | sipa: BOLT #3 to_local | 2 | 2 | 10 | 4 | 12/12 | 5/1/0 |
| `bolt3_offered_htlc` | sipa: BOLT #3 offered HTLC | 3 | 3 | 14 | 5 | 17/17 | 6/1/0 |
| `bolt3_received_htlc` | sipa: BOLT #3 received HTLC | 3 | 3 | 15 | 5 | 18/18 | 7/1/0 |
| `hash_threshold` | Bitcoin Core Miniscript test vector (thresh + sha256 + hash160) | 1 | 3 | 13 | 3 | 14/14 | 9/1/0 |
| `liquid_federation` | Bitcoin Core wallet test (time-based `older`) | 8 | 4 | 21 | 2 | 21/21 | 20/1/0 |
| `revault_unvault` | Bitcoin Core wallet test (`andor`, `multi`, `after`) | 10 | 2 | 16 | 2 | 16/16 | 20/1/0 |

On 14 September 2026 the twins gained the chain scenarios of the
Tape run (above): 361 of 361 expectations pass — the 271 of the analysis
(unchanged by the finality condition) and 90 chain verdicts (core_2of3 7,
liana_recovery 3, liana_inheritance 9, cosigning_service 4, decaying 8,
halving_decay 16, bolt3_to_local 3, offered 7, received 7, liquid 13,
revault 13; hash_threshold none).

Fidelity is 100% (271 of 271 expectations); every program loads with 0 errors
and its quotations are found in the cited texts. The only warnings are the
verifier's `rule_without_variables` on single-signature paths, which are
propositional by nature.

Key-loss findings the flips make explicit: in `cosigning_service` the user's
key is indispensable (no path without it); losing the service, the primary
key (Liana), the wallet manager, the revocation key, any key of the two
decaying multisigs, any functionary or any stakeholder leaves the coin
spendable only after the delays; in the 2-of-3 and the HTLCs losing one key
changes nothing.

## Sources and licences

- Pieter Wuille, Andrew Poelstra, Sanket Kanjalkar, *Miniscript*,
  <https://bitcoin.sipa.be/miniscript/> — the policy examples. The page and
  its repository (<https://github.com/sipa/miniscript>) state no licence for
  the page's text (checked 24 November 2026). So the page is not copied
  here. `sources/sipa_miniscript.txt` quotes, with attribution, only the
  page's example policies: the title of each example link, followed by the
  policy that the link loads. The authors of the page keep all rights.
  `sources/extract_sipa.py` writes that file from a copy of the page that
  you save yourself (into `.cache/`, which git ignores).
- BIP 379, *Miniscript* <https://github.com/bitcoin/bips/blob/master/bip-0379.md>
  — the semantics the lifting follows.
- Bitcoin Core (MIT): `doc/descriptors.md`, `src/test/miniscript_tests.cpp`,
  `test/functional/wallet_miniscript.py` (the f-strings with their keys
  substituted, in `core_wallet_policies.pl`).
- Liana (BSD-3-Clause): `README.md` (About) and `doc/RECOVER.md`.

## Decisions and gaps

- **Liana inheritance is our reading of prose.** The README gives the
  configuration in words ("any 2 keys from the owner's spouse and two kids
  (after 1 year)"); the policy, and the conversion of 1 year and 15 months at
  144 blocks a day, are ours — the four elements concerned are `approximated`
  in its ledger, each path citing its own line of the README. The fifteen
  months were first written `older(65664)`, which a role-play review caught
  (an AI agent reading as a Miniscript expert; the review is not published,
  and no Miniscript developer took part): BIP 68 reads only the low
  16 bits of a relative lock, so consensus reads 65664 as 128 blocks, and the
  longest relative lock is 65535 blocks (about 455 days — one day short of the
  README's 1 year and 3 months). The policy is now `older(65535)`, run again on
  Tape; and the translator says so whenever a policy writes what consensus
  reads otherwise (`ms_lock_warnings/2`: bits BIP 68 ignores, a path mixing
  lock kinds), in the program's header, its ledger and File ▸ Open's notes.
- **The coin's age is a rule of the twin, not lib/temporal's `block … is at
  least … blocks after …`.** That library rule compares an arithmetic
  expression (`H - F >= N`), which LE's comparison built-ins do not evaluate
  (see "Core findings" below): it holds for every pair of heights. The twins
  compute the age with an assignment (`N = M - H`) and compare the number.
  lib/temporal is used for the lock-time kinds.
- **The test locator is a comment, not the scenario header.** Headers read
  `as stated in the satisfaction analysis of the policy`; the path each
  scenario comes from opens it as a comment (a writer bug drops the lines of
  a scenario whose header has an `at` locator — see below).
- **Bounds.** A policy with more than 12 paths is sampled (first, last and
  evenly between); key-loss flips for policies of at most six keys; LE's flips
  look at most three changes deep, and the expected sets say `[]` beyond that
  (as LE does).
- **Not covered:** Simplicity, Script that is not Miniscript (a raw
  `OP_IF … OP_CHECKSIGADD` script must first be decompiled to Miniscript),
  the witness itself (sizes, fees, malleability — out of the twin by
  design), and relative locks mixing blocks and seconds in one path (Miniscript
  forbids the mixing; the parser does not re-check BIP 379's type system).

## Core findings (reported to the coordinator, not patched here)

1. **`le_writer`: scenario lines vanish with an `at` locator.** In
   `write_scenario/4`, `option(at(L), Opts)` binds `L`, and the following
   `forall(member(L, Lines), ...)` then matches nothing, so the scenario is
   written empty. Patch: rename the locator variable (`option(at(Loc), Opts),
   locator_text(Loc, LT)`).
2. **Comparisons with an arithmetic operand are not evaluated.**
   `reasoner:le_compare/3` compares numbers arithmetically but anything else
   by the standard order of terms, so `H - F >= 1008` (a compound against a
   number) is always true. It bites `lib/temporal.le`'s `block *a height* is
   at least *a number* blocks after block *a first height*` (always true).
   Patch, either: in `le_compare/3`, evaluate operands that are arithmetic
   expressions (`catch(X1 is X, _, fail)`) before comparing; or rewrite the
   library rule as `D = H - F and D >= N`.

## Implementation status (for §8, Phase 1d)

*Done, 13 September 2026.* `LE2 migration/miniscript/` parses the policy
language, Miniscript (all BIP 379 fragments and wrappers) and `wsh`/`sh`/`tr`
descriptors, lifts them to the spending policy, and writes LE twins through
the shared writer and ledger: one labelled, cited rule per spending path,
thresholds as count aggregates, timelocks via the coin's age and lib/temporal's
lock-time kinds. The tests are the policy's own satisfaction analysis —
every path and every near miss, expected outcomes from an independent
evaluator — plus flip queries for the key-loss analysis and a custody-explainer
view per twin. Twelve real policies (sipa's Miniscript page including the
three BOLT #3 outputs, Liana's recovery descriptor and inheritance
configuration, Bitcoin Core's 2-of-3, halving-decay, hash-threshold, Liquid-like
federation and Revault test policies): 271 of 271 expectations pass, 0 load
errors; the LE programs agree with the evaluator on every attempt tested.

# Bitcoin Miniscript and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

Miniscript is a structured way to write Bitcoin Script. BIP 379 specifies
Miniscript. BIP 379 is one of the Bitcoin Improvement Proposals. Wallets such
as Bitcoin Core and Liana use Miniscript. A *spending policy* tells who can
spend a coin, and when. You can write a policy in three forms:

- in the policy language (`and(pk(key_user),or(pk(key_service),older(12960)))`);
- in Miniscript (`and_v(v:pk(…),or_d(…))`);
- in an output descriptor (`wsh(…)`).

The translation operates in the two directions. **File ▸ Open…** (or **File ▸
Import from Another System…**) changes a file of policies into a Logical
English (LE) program. The program has these parts:

- one rule for each spending path, with a citation;
- the analysis of the policy, as scenarios;
- flip queries for lost keys;
- a *custody explainer* view.

**File ▸ Export to Another System…** writes a program that uses the same
vocabulary back as a policy. You get the Miniscript that the compiler of sipa
makes from the policy. You also get the descriptor, when the program states the
keys. You also get a link that opens the policy in the Minsc playground. The
translators are a part of the Logical English Translators. Thus they are
available only on the installations that have the Translators, for example the
hosted service. Every installation has the example twins.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [Opening a policy file](#opening-a-policy-file)
  - [Reading the program](#reading-the-program)
  - [The custody explainer and the flips](#the-custody-explainer-and-the-flips)
  - [The example twins and their chain runs](#the-example-twins-and-their-chain-runs)
  - [Exporting a program as a policy](#exporting-a-program-as-a-policy)
  - [Writing a policy in Logical English](#writing-a-policy-in-logical-english)
- [How Miniscript maps to Logical English](#how-miniscript-maps-to-logical-english)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| Miniscript → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | `.miniscript`, `.ms`, `.policy`, `.desc`, `.txt`: policies, Miniscript expressions or descriptors, one on each line | one rule for each spending path, each with a citation of its line; the satisfaction analysis as scenarios; key-loss flips; a custody explainer view; a ledger | an independent evaluator of the policy (the semantics of BIP 379), and for the twins, a recorded run of each spending attempt on the Tape test network |
| Logical English → Miniscript | **File ▸ Export to Another System…** | writes `<program>.policy` | the policy, the Miniscript of sipa, the descriptor when the program states the keys, a **Try it in Minsc** button | the round trip: each twin exports to the policy of its source, and the exported file opens back into the same policy |

**File ▸ Open…** and **Misc ▸ Export to another system…** in the LPS2 IDE use
the same translators, when the adjacent Logical English installation has them.

## How to use it

### Opening a policy file

Do these steps:

1. Write the policies in a text file, one policy on each line.
2. Select **File ▸ Open…**.
3. Select the file.
4. Read the note below the menu bar.
5. Select **Misc ▸ Run the Program's Tests…** to run the scenarios.
6. Select **File ▸ Show the Original…** to see the file that you uploaded.

In the text file of step 1, a line that starts with `#` is a comment. The
comment immediately above a policy becomes the title of that policy. A line of
the form `name = role` gives a role to a key or a hash. That line applies to
all the policies in the file. This is a file that File ▸ Open reads:

```
key_user = the user
key_service = the cosigning service

# A user and a co-signing service, the user alone after 90 days
and(pk(key_user),or(99@pk(key_service),older(12960)))
```

A policy can be a descriptor with real keys and a checksum
(`wsh(…)#checksum`, `tr(…)`, key origins such as `[a5c6b76e/48'/1'/0'/2']tpub…/<0;1>/*`).

After step 3, the program opens in a new tab. The note of step 4 gives, for
each policy, the ledger counts and the result of the tests of the policy. An
example is *wallet: 5 ledger elements encoded, 1 approximated, 0 residue;
0 writer errors; the policy's own analysis: 12 tests pass, 0 fail, 0 errors.*
The note starts with a **WARNING** when the consensus rules of the Bitcoin
network read the policy differently from how it is written (refer to
[Traps](#traps)).

The program that opens holds the first policy of the file. Each other policy
becomes a separate program, adjacent to the first (`<name>_2`, `<name>_3`, …).
The note gives the names of these other programs. A comment at the top of the
first program also gives their names.

The editor does not discard a line that is not a policy (for example, a word
alone). That line becomes a `% TODO` residue block in the first program. The
block also holds the complaint from the part of the editor that reads
policies. The editor does not use a file as Miniscript if the file has no
policy.

The editor keeps the uploaded file in the `sources/` folder of the program. The
editor writes the ledger, `<name>.ledger.md`, adjacent to the program.

### Reading the program

The comment at the top of the program shows the source in four ways. Thus you
do not have to decode a descriptor yourself. The four ways are:

- as it is written;
- as an indented tree, with keys and hashes by role (`pk(<the user>)`);
- the legend, which tells which key or hash has each role;
- what the policy says, in words, with delays in blocks and in approximate
  time (`the coin at least 12960 blocks old (about 90 days; older(12960))`).

After the comment come the rules, one rule for each spending path. Each rule
has a label and cites its source:

```le
rule user_and_service with provenance the Miniscript page,
        confer "A user and a 2FA service need to sign off, but after 90 days the user alone is enough":
the coin can be spent if
    the witness contains a signature by the user
    and the witness contains a signature by the cosigning service
        or the coin has been confirmed for a number N blocks
            and N >= 12960.
```

The scenarios are the *satisfaction analysis* of the policy. Each spending path
gets a scenario that meets exactly the requirements of that path. The name of
the scenario comes from the rule that it satisfies. For example, the scenario
for the rule `revocation` is `revocation`. When an `or` or a `thresh` in the
rule `family` lets you meet that rule in more than one way, the scenarios are
`family_1`, `family_2`.

Each path also gets its *near misses*. A near miss has one requirement less
(`revocation_without_1`). For example, a signature or a preimage is missing,
a delay is one block too short, or a lock time is one too low. One more scenario
has an empty witness (`no_witness`). Each expected answer comes from the policy.
A separate program that follows BIP 379 calculates these answers. They never
come from the Logical English program. The queries are `spendable`
(`the coin can be spent`), `flip_spend` and `flip_block`.

### The custody explainer and the flips

Each program ends with a view, `custody explainer`. Do these steps:

1. Select **Misc ▸ Open Executive View**.
2. Select the view in the **Views:** strip.

The view shows the facts of the case. These facts are the witness (the
signatures and the preimages) and the timelocks (the block of the coin, and
the block of the spending transaction). Then the view tells if a person can
spend the coin, with the reasons and the citations. The view has a flip
button, **What would let this coin be spent?**. This button keeps the block
heights as they are. Thus the answer comes back in keys and preimages.

The flip scenarios hold the key-loss analysis
([flip queries](../reference/language.md#177-flip-queries-which-minimal-change-flips-the-outcome)):

- `flip_now` and `flip_after_delays` start with no signatures. They ask which
  smallest sets of signatures and preimages let a person spend the coin, now
  and after all the delays;
- `lost_the_<role>` gives all items except the signature of that key, after
  the delays. The answer tells if a person can still spend the coin. If a
  person can spend it, the answer also tells which smallest removals then stop
  the spending. These removals give the keys and the timelock facts that become
  necessary after the loss of the key.

For example, in `cosigning_service` the key of the user is necessary. If the
cosigning service is lost, the user alone can spend the coin, after the delay.

### The example twins and their chain runs

LE translated twelve published policies. The results have the name *twins*.
They are in the examples, in `migration/miniscript/`. To open them, select
**File ▸ Open example from server…**:

| Twin | Source |
|---|---|
| `core_2of3_multisig` | the descriptor documentation of Bitcoin Core: a 2-of-3 multisig |
| `liana_recovery`, `liana_inheritance` | the recovery descriptor of Liana, and the inheritance wallet that its README describes |
| `cosigning_service`, `decaying_multisig` | the Miniscript page of sipa: a 2FA service; a 3-of-3 that becomes 2-of-3 after 90 days |
| `bolt3_to_local`, `bolt3_offered_htlc`, `bolt3_received_htlc` | the page of sipa: the Lightning outputs of BOLT #3, with hash locks |
| `halving_decay`, `hash_threshold`, `liquid_federation`, `revault_unvault` | the test policies of Bitcoin Core: a decaying 4-of-4, a threshold of hashes, a federation with a time-based lock, the unvault output of Revault with `after` |

On a twin, **File ▸ Show the Original…** gives a list of the sources of the
translation:

- the cited excerpt as plain text;
- the full page or files that the excerpt comes from (`originals/`);
- `<id>.policy`, which is the policy in the form that File ▸ Open reads, with
  the compilation of sipa and the Minsc link;
- `<id>.chain.json`.

LE also *ran* all the twins except `hash_threshold`. LE made each spending
attempt of the satisfaction analysis of a twin into a real transaction. This
includes each path, each near miss, and the empty witness. LE sent each
transaction to a network. The network was **Tape**, the public regtest network
of Rewind Bitcoin. Tape is a test network with no real money. It runs the
consensus and mempool rules of Bitcoin Core. The decisions of the node of the
network are in the twins, as the scenarios with names that start with `chain_…`:

```le
scenario chain_user_and_service_1 is, as stated in the Tape run of 2026-09-14 at the refusal of attempt path_1:
    % the chain refused the spend: non-BIP68-final
    the witness contains a signature by the user.
    the coin was confirmed in block 122322.
    the spending transaction is in block 122322.
    spendable expects answers [].
```

An accepted spend cites its transaction. The document `the Tape run of …` has a
link to the address on the explorer of Tape. In the run of 14 September 2026,
LE did 90 attempts on eleven twins. The result was 16 accepted spends and 74
refusals. These were the causes of the refusals:

- missing signatures;
- incorrect preimages;
- coins that were too young for `older` (BIP 68);
- lock times that were not past yet (BIP 65 and BIP 113).

Each decision of the network agrees with its twin. LE also ran the same
attempts on a private test node. On that node, the coins are below sufficient
blocks to satisfy the long relative locks. Thus that node also accepts the
`older` paths. That second run is only a check. The twins do not record it.

The signatures in these runs use *test keys*. LE calculates the test keys from
the role names. No person has the private keys of the sources. The structure of
the policy comes from the source. The editor sends nothing to a network. The
chain runs are recorded material. The editor does not do them for you.

### Exporting a program as a policy

Do these steps:

1. Open a twin, or a different program in the same vocabulary (refer to the
   section below).
2. Select **File ▸ Export to Another System…**.
3. Select *Bitcoin Miniscript policy (with its Miniscript and a Minsc link)*.
4. Click **Copy** or **Save…** to keep the `.policy` text.
5. Click **Try it in Minsc** to open the policy in the Minsc playground.

The menu of step 2 also gives LegalRuleML. LegalRuleML refuses a program that
has a threshold (refer to [LegalRuleML](legalruleml.md#traps)).

After step 3, the window shows the `.policy` text, with **Copy**, **Save…**
and **Try it in Minsc**. The text has:

- the Miniscript that the compiler of sipa makes from the policy (P2WSH);
- the descriptor, `wsh(…)`, when the program states all the keys;
- the Minsc link;
- the legend lines and the policy.

The notes count the keys, the hashes and the spending paths. The Minsc
playground compiles the policy to Miniscript, Script and a testnet address in
the browser.

The exported file opens again with **File ▸ Open…**. Each twin comes back with
the same policy. That is, the same paths, the same keys and hashes by role, the
same locks and the same hash functions.

Possibly a rule that concludes `the coin can be spent` has a condition outside
that vocabulary. Then the exporter refuses and writes nothing
([refusals](index.md#when-an-export-is-refused)). The window gives each of
these conditions with its line:
*a condition Miniscript has no form for (a policy says only: signatures, hash
preimages, relative and absolute time locks, and thresholds of them)*. The
exporter also refuses an integrity constraint (`it must not be true that …`).
Rules that the policy does not read cause no problem. An example is the rule for
the age of the coin.

### Writing a policy in Logical English

The program does not have to come from a policy. You can export each program
that uses the templates of the twins. Thus you can write a spending policy in
Logical English first. You can test it and explain it in Logical English. Then
you can change it into a policy. This is the smallest such program:

```le
the target language is: prolog.

the templates are:
    the coin can be spent.
    the witness contains a signature by *a key*.
    the witness reveals the preimage of *a hash*.

the knowledge base mine includes:

the coin can be spent if
    the witness contains a signature by alice
    and the witness reveals the preimage of the secret.

the coin can be spent if
    the witness contains a signature by bob.
```

The program exports as `or(and(pk(alice),sha256(secret)),pk(bob))`. The
compiler of sipa changes this into `andor(pk(alice),sha256(secret),pk(bob))`.
The templates must have exactly the wording of the table below. To use real
keys and to get a descriptor, state the keys:
`the public key of the primary key is "[a5c6b76e/…]tpub…/<0;1>/*".`
For a hash that is not SHA-256, state its function:
`the hash function of the payment hash is hash160.`

## How Miniscript maps to Logical English

| Miniscript or policy | Logical English |
|---|---|
| `pk(K)`, `pkh(K)`, `pk_k`, `pk_h`, `c:` | `the witness contains a signature by <role>`: the role from the legend; if there is no role, `key A`, `key B`, … |
| `sha256(H)`, `hash256`, `ripemd160`, `hash160` | `the witness reveals the preimage of <role>`, with `the hash function of <role> is hash160` (and so on) as a fact |
| `older(n)`, in blocks | `the coin has been confirmed for a number N blocks and N >= n`; LE calculates the age from `the coin was confirmed in block …` and `the spending transaction is in block …` |
| `older(n)` with the time flag of BIP 68 | the same, in seconds (512 × the low 16 bits) |
| `after(t)` | `the spending transaction has the lock time a number N and the lock time N is a block height` (or `is a time`) `and N >= t`, and the lock time is past: `the spending transaction is in block a height H and N < H` |
| `and`, `and_v`, `and_b`, `and_n` | `and` |
| `or`, `or_b`, `or_c`, `or_d`, `or_i` | `or`; a top-level `or` is one rule for each spending path, with a label |
| `andor(X, Y, Z)` | (X and Y) or Z |
| `thresh(k, keys)`, `multi`, `multi_a`, `sortedmulti` | a count: `a number N is the count of each K such that a key K is in [cosigner A, cosigner B, cosigner C] and the witness contains a signature by K` and `N >= 2` |
| `thresh(k, conditions)` | the same count over named conditions (`the condition … is met`), each with a separate rule |
| `tr(K, {leaves})` | the signature of K, or any leaf |
| a real key in a descriptor | `the public key of <role> is "…"` |
| wrappers (`a s c d v j n t l u`), `wsh`, `sh`, weights such as `99@` | nothing in the rules: they do not change who can spend (BIP 379); the ledger records them |
| witness sizes, fees, malleability, the selection of fragments | not in the program: one *approximated* ledger entry, *the Script encoding* |

These templates are `scenario element`s:

- `the witness contains a signature by *a key*`;
- `the coin was confirmed in block *a height*`;
- `the spending transaction is in block *a height*`;
- `the spending transaction has the lock time *a number*`.

A scenario element is a fact that a case states. A flip can add or remove
these facts.

## Traps

- **The program is the policy, not the Script.** Witness sizes, fees,
  malleability and the selection between equivalent fragments are not a part
  of the program. Two Miniscripts with the same policy give the same program.
- **Weights disappear.** `99@` and `9@` guide the compiler of sipa to the more
  probable path. The weights do not change who can spend. The comment at the
  top of the program tells that the program does not include them.
- **`older(n)` reads only 16 bits.** BIP 68 ignores the higher bits of the
  number. Thus, for the network, `older(65664)` means 128 blocks. File ▸ Open
  tells you this in a WARNING. The WARNING is in the note, in the comment at
  the top of the program, and in the ledger. The program states what the
  network reads (`N >= 128`). The export gives the policy back as it is
  written. The longest relative lock is 65535 blocks, approximately 455 days.
  Thus you cannot write "one year and three months" in blocks.
- **Mixed lock types.** Some spending paths need a lock by block height and a
  lock by time. No transaction can meet such a path. File ▸ Open gives a
  warning about such a path (BIP 379 calls it timelock mixing). Apart from
  that warning, the editor does not examine the type system of Miniscript. The
  type system is the rules that tell which fragments can go together.
- **`after(t)` needs a lock time that is past.** BIP 379 reads `after(t)` as
  "the lock time is at least t". The network also refuses a transaction if its
  lock time is not below the height or median time of its block. The programs
  state the two requirements. LE found the second requirement when the Tape run
  refused spends that the first programs permitted.
- **The block heights in the analysis are only examples.** The scenarios put
  the coin at block 850000, and the spend immediately after the delays. The
  chain scenarios use the heights of the Tape run.
- **Chain runs recorded before 16 September 2026 give numbers to their
  attempts.** The scenario names follow the rules (`chain_revocation`). But the
  citation keeps the attempt id of the run (`at the refusal of attempt path_1`).
  That id gives numbers to the paths of the analysis, in the sequence in which
  the analysis found them.
- **The flip queries of the program can propose to remove block facts.** The
  answers to `flip_block` include
  `remove: the coin was confirmed in block 850000`. This is true, but a key
  holder cannot cause it. The flip of the view keeps the timelock facts. Use the
  view for questions about keys.
- **Limits.** When a policy has more than 12 spending paths, LE uses only some
  of them: the first, the last, and some between them. LE writes key-loss
  scenarios for policies with a maximum of six keys. A flip examines a maximum
  of three changes.
- **Minsc links use test keys when the source gives no key.** A link or a
  descriptor that LE makes from role names holds keys that LE calculates from
  these names. The comment in the link says
  *a test key: the source names no key*. Never send funds to an address that
  comes from such keys. The export writes a descriptor only when the program
  states all the keys with `the public key of …`.
- **A hash function that the program does not state is SHA-256.** An exported
  program with `the witness reveals the preimage of …` and no
  `the hash function of … is …` fact writes `sha256`.
- **Possibly the compiler of sipa refuses.** Sometimes the compiler cannot
  change the policy into safe Miniscript. Then the export writes only the
  policy, without Miniscript and without a descriptor. A note tells the reason.
  `hash_threshold` is such a policy: two preimages spend the coin with no
  signature. Minsc answers *"Top Level script is not safe on some spendpath"*.
  Wallet software does not make transactions for that policy. Thus
  `hash_threshold` has no chain run.
- **The wording must match.** The exporter reads rules by their templates.
  Possibly a program says `the transaction is signed by alice`, and not
  `the witness contains a signature by alice`. Then the editor does not give the
  Miniscript export for that program, or the export refuses at that condition.
- **More than one translator uses `.txt`.** More than one translator reads
  `.txt` files. The editor uses a `.txt` file as Miniscript only when a minimum
  of one line reads as a policy. To be sure, give the file the extension
  `.policy`.
- **Expected warnings.** A path that needs one signature has no variables. On
  such rules, the `rule_without_variables` warning of the verifier is expected.
- **Not covered:** Simplicity, and Script that is not Miniscript. Change such
  Script back into Miniscript first.

## See also

- In this documentation:
  - [Other systems: importing and exporting](index.md): open files, [what LE could not translate](index.md#what-could-not-be-translated), [Show the Original](index.md#show-the-original), [refused exports](index.md#when-an-export-is-refused), [the twins](index.md#the-migration-twins-among-the-examples);
  - [LegalRuleML](legalruleml.md), the other exporter that the editor gives for these programs;
  - [flip queries](../reference/language.md#177-flip-queries-which-minimal-change-flips-the-outcome), [views](../reference/language.md#1710-views-how-a-screen-shows-a-program), [aggregates](../reference/language.md#5-aggregates), [integrity constraints](../reference/language.md#33-integrity-constraints-it-must-not-be-true-that-), [rule labels and provenance](../reference/language.md#155-rule-labels-and-provenance);
  - [the executive view](../guide/executive-view.md#views), [LE Views](../tutorials/views.md), [Querying a program](../tutorials/querying-a-program.md#5-flip-what-would-change-the-answer);
  - [the Contract Assistant](../guide/assistants.md#the-contract-assistant). Its residue mode translates TODO blocks.
- In the LPS2 IDE: [the IDE guide](https://lps2.logicalcontracts.com/docs/user/guide/ide), [integrations](https://lps2.logicalcontracts.com/docs/user/integrations/index).
- The documentation of Miniscript:
  - [Miniscript](https://bitcoin.sipa.be/miniscript/), by Pieter Wuille, Andrew Poelstra and Sanket Kanjalkar, with the policy compiler;
  - [BIP 379: Miniscript](https://github.com/bitcoin/bips/blob/master/bip-0379.md);
  - [the descriptors of Bitcoin Core](https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md);
  - [Minsc](https://min.sc/), the playground;
  - [the Tape network](https://tape.rewindbitcoin.com/).

# How the examples in this folder were made

Every program here is a *twin*: a Bitcoin spending policy, written in
Miniscript, rewritten in Logical English by a translator, a Prolog program
that reads the policy and writes the twin. Eleven of the twelve policies are
published by their authors (Bitcoin Core, Liana, Pieter Wuille's Miniscript
page). The twelfth, `liana_inheritance`, was written for this folder from the
wallet configuration that Liana's README describes in words: Liana did not
publish it as a policy, and its ledger marks what was read into those words.
An AI agent (Claude, in Claude Code) chose the policies, recorded where each
is published, and named the roles of their keys: the role names are the
agent's, not the sources'. The translator itself, and this folder's README,
were written by the AI agent at Miguel Calejo's request. Bitcoin Core, Liana
and the authors of Miniscript took no part in this work and have not reviewed
it.

| File | Made by | How |
|---|---|---|
| `*/<id>.le` | Translator program `migration/miniscript/build.pl` of this repository (`main/1`, which calls `ms_twin:build_twin/3`) | Parses and evaluates the policy with `miniscript.pl` and writes the program through LE2's `le_writer.pl` and `le_migration.pl`. The scenarios are computed from the policy: its satisfaction analysis, the loss of each key, and the recorded spending attempts on a test network. The expected answers come from the translator's own evaluator of the policy (`ms_eval/2`), following BIP 379. The opening disclaimer comes from `le_migration:with_disclaimer/2`. |
| `*/<id>.ledger.md`, `*/<id>.ledger.json` | The same translator (`le_migration.pl`) | What each part of the twin was translated from. |
| The key legends and titles inside each twin | AI agent (Claude, in Claude Code), 13 September 2026 | Written in `migration/miniscript/policies.pl` and `core_wallet_policies.pl`: which key belongs to whom ("cosigner A", "the manager"), and which published text each policy is quoted from. |
| `*/temporal.le`, `*/temporal.pl` | A copy of LE2's `lib/temporal.le` and `lib/temporal.pl`, put there by the translator | The library of dates and lock times. It was written by the AI agent (commit `63c3591`, 13 September 2026). |
| `*/sources/*.txt` | People: the authors of each cited document | The excerpt each twin quotes, copied from Pieter Wuille's Miniscript page (https://bitcoin.sipa.be/miniscript/), Bitcoin Core's documentation and tests (https://github.com/bitcoin/bitcoin), or Liana's documentation (https://github.com/wizardsardine/liana). |
| `*/sources/originals/*` | The same authors | The whole file the excerpt comes from, unchanged, with its licence (`COPYING` for Bitcoin Core, `LICENCE` for Liana). The Miniscript page and its repository (https://github.com/sipa/miniscript) state no licence for the page's text. So the page is not copied here: `sipa_miniscript.txt` quotes only the page's example policies, with attribution, and the authors of the page keep all rights. |
| `*/sources/<id>.policy` | The translator | The policy as File ▸ Open reads it back: title, key legend, the source's text, the compiled Miniscript, a link to the Minsc playground. |
| `*/sources/<id>.chain.json` | Program `migration/miniscript/chain.pl` | The recorded run of the twin's spending attempts on a test chain (Tape, which RewindBitcoin operates and opens to the public): what its node accepted and what it refused. |
| `README.md` | AI agent (Claude, in Claude Code), at Miguel Calejo's request (it came from InsurLE2 with the twins on 16 September 2026 and was rewritten on 23 September) | Written by the agent itself, not by the translator. |
| `MAKING_OF.md` | AI agent (Claude, in Claude Code), 24 September 2026, at Miguel Calejo's request | This file. |

## The record

- Commit `0ca7270` (13 September 2026) "Migration Phase 1c/1d/1e: … Bitcoin
  Miniscript translator (12 cited policies, 271/271) …", in the InsurLE2
  repository, by Miguel Calejo with Claude Opus 5 (the commit's
  `Co-Authored-By` line): the translator, the policies and the first build.
- The translator moved to the lpsPlus repository, which is not public, on
  18 September 2026 (commit `44d3f65` there), and into this repository
  (`migration/miniscript/`, Apache License 2.0) in November 2026; the twins
  moved into this repository on 16 September (commit `9d42150`, "move
  examples"). Later changes here came from rebuilds,
  and from refreshed copies of the `temporal` library (commits `dfeddca`,
  16 September, and `6e903fd`, 22 September); the record shows no hand edit (before the corrections of 24 November 2026: the translator's name in each ledger, the heading of the policy in `liana_inheritance.le`, and the excerpt of the Miniscript page, cut to the quoted lines) of
  a twin.
- To build the twins again, from the LE2 checkout:

  ```sh
  ./myswipl.sh -q migration/miniscript/build.pl                   # all
  ./myswipl.sh -q migration/miniscript/build.pl liana_recovery    # one
  ./myswipl.sh -q migration/miniscript/chain.pl                   # the chain runs
  ```

  `migration/miniscript/README.md` says what the chain runs need.

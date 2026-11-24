# The translators of other rule systems

*Kind: developer guide · Audience: developers, and anyone who wants to read or repair a translator · Status: current (24 November 2026)*

This folder holds the **translators** of Logical English (LE): the programs
that read a file of another rule system and write it as Logical English, and
the programs that write a Logical English program in another system's format.
The editor offers them in **File ▸ Open** (Import from Another System…) and
in **File ▸ Export**. Each translator is checked against the other system's
own engine, where that engine can be run.

A program that a translator writes from another system's program is called a
**twin**: it says the same thing in Logical English, and it carries the other
program's tests as its own scenarios.

## Copyright, licence, support

- **Copyright Miguel Calejo.** Every file in this folder that the list in
  [Files of other authors](#files-of-other-authors) does not name is his. The
  rest of the repository has other copyright holders (`../NOTICE`).
- **Apache License 2.0**, as the rest of the repository (`../LICENSE`).
- **"As is".** The tests of each translator pass on the versions of the other
  system that its README names. There is no promise that a translator follows
  a later version of that system. Reports and corrections are welcome.

The translators were a closed product until November 2026. Comments and
READMEs still cite the author's design notes by name (`roadmap.md`, `l4.md`,
`rune.md`, `ruml.md`, `Excel.md`) and by section. Those notes are working
papers, and they are not published. The text here does not need them.

## The translators

| Folder | System | Reads | Writes | The twins are in |
|---|---|---|---|---|
| [blawx](blawx/README.md) | Blawx version 1 | yes | | `examples/migration/blawx/` |
| [catala](catala/README.md) | Catala | yes | yes | `examples/migration/catala/` |
| [daml](daml/README.md) | Daml 3 (Canton) | yes | yes | LPS2, `examples/migration/daml/` |
| [dmn](dmn/README.md) | DMN 1.1 to 1.6 and FEEL; the adapter for Kogito, KIE Server and Camunda | yes | yes | `examples/migration/dmn/` |
| [drools](drools/README.md) | Drools DRL | yes | | LPS2, `examples/migration/drools/` |
| [epilog](epilog/README.md) | Epilog (Stanford) | yes | | `examples/migration/epilog/`; the games in LPS2 |
| [l4](l4/README.md) | L4 (Legalese, Singapore Management University) | yes | | `examples/migration/l4/`; the contracts in LPS2 |
| [legalruleml](legalruleml/README.md) | LegalRuleML (OASIS) | yes | yes | `examples/migration/legalruleml/` |
| [miniscript](miniscript/README.md) | Bitcoin Miniscript | yes | yes | `examples/migration/miniscript/` |
| [oia](oia/README.md) | Oracle Intelligent Advisor; its adapter | yes | | private (see below) |
| [oipa](oipa/README.md) | Oracle Insurance Policy Administration | yes | | `examples/migration/oipa/` |
| [openfisca](openfisca/README.md) | OpenFisca and PolicyEngine | yes | yes | private (see below) |
| [ponens](ponens/README.md) | Ponens policies | yes | yes | LPS2, `examples/migration/ponens/` |
| [rulespec](rulespec/README.md) | Axiom RuleSpec | yes | yes | `examples/migration/rulespec/` |
| [ruml](ruml/README.md) | RUML (the Rulemapping Logic Format) | yes | yes | `examples/migration/ruml/` |
| [rune](rune/README.md) | Rune (ISDA's Digital Regulatory Reporting, the Common Domain Model) | yes | yes | private (see below) |
| [scasp](scasp/README.md) | s(CASP) and Prolog | yes | | `examples/migration/scasp/` |
| [socotra](socotra/README.md) | Socotra product configurations | yes | | private (see below) |
| [solidity](solidity/README.md) | Solidity (the way back, *Deploy as Solidity*, is LPS2's `src/syntax/lps_solidity.pl`) | yes | | LPS2, `examples/migration/solidity/` |
| [spreadsheet](spreadsheet/README.md) | Spreadsheets (Excel) | yes | | `examples/migration/spreadsheet/` (workbooks in the public domain); the others private (see below) |

Three files serve all of them:

| File | What it does |
|---|---|
| `le_importers.pl` | The table that File ▸ Open and File ▸ Export read: one row for each translator. `../le_kbs.pl` loads the table. A translator is loaded only when a file of its kind is opened or a program is exported |
| `le2_paths.pl` | Where LE2, LPS2 and the twins are, so that no translator holds a fixed path |
| `adapter_access.pl` | Who may call the two adapters (Oracle Intelligent Advisor, DMN) on a server |

The shared machinery is in the root of LE2 and is described in
[`docs/dev/migration.md`](../docs/dev/migration.md): `le_writer.pl` writes
Logical English text, `le_migration.pl` writes the ledger of a translation and
turns the source's tests into scenarios, `le_import.pl` is the registry, and
`le_adapter.pl` is the adapter kit.

## Twins that are not published

A twin is a translation of its source. So a twin can be published only where
the licence of the source allows a changed copy to be published. The twins of
these sources are never written into this repository or into LPS2:

- Oracle Intelligent Advisor sample projects and Socotra's product library
  (no licence that allows it);
- OpenFisca and PolicyEngine (AGPL-3.0, which is not compatible with the
  licence of this repository);
- ISDA's Digital Regulatory Reporting (a licence that does not allow changed
  copies);
- the spreadsheets of publishers that state no licence, and the Dutch
  *bruidsschat* decision tables (terms of reuse not confirmed).

The translators of those systems write their twins into a **private place**:
the folder that `$LE_PRIVATE_TWINS_DIR` names, or `build/private/` in this
repository, which git ignores (`le2_paths:private_root/1`). The tests that
need such a twin are skipped when the twin is not there.

## What a translator needs

Each README says what its translator needs. In general:

- **To open a file in the editor:** SWI-Prolog, and for some translators one
  more program (Node.js for Solidity and spreadsheets, Python 3 for Rune and
  OpenFisca).
- **To rebuild the published twins and to check them against the other
  system:** that system's own engine (Java and Maven for DMN, Drools and
  Rune; a Canton sandbox for Daml; and so on), and its sources. A script in
  each folder (`fetch_sources.sh` or similar) downloads the sources into a
  `.cache/` folder that git ignores. Nothing of another system's engine is
  copied into this repository.
- **LPS2**, in a checkout beside this one or named by `$LPS2_DIR`, for the
  translators that write Logical English for LPS (Solidity, Drools, Daml, the
  contracts of L4, the games of Epilog, Ponens): LPS2 runs their twins.

## Tests

From the root of LE2:

```sh
testing/run_tests.sh migration        # the tests of every translator
./myswipl.sh -q -g run_tests -t halt migration/dmn/test_dmn.pl   # one translator
```

A test that needs a download, an engine or LPS2 that is not there is skipped,
and the run says so.

## Files of other authors

Some files here were written by others. Each keeps its authors' copyright and
licence.

- `drools/corpus/drl/Fire.drl`, `drools/corpus/drl/HonestPolitician.drl` and
  `drools/corpus/java/org/drools/examples/`: examples of Apache KIE Drools,
  copyright the Apache Software Foundation; Apache License 2.0 (stated at the
  top of each file).
- `legalruleml/corpus/oasis/`: the examples of the LegalRuleML Core
  Specification Version 1.0, copyright OASIS Open, unchanged, under the OASIS
  intellectual property rights policy (`NOTICE.txt` in that folder).
- `miniscript/sources/`: texts from Bitcoin Core (MIT licence, `COPYING`),
  from Liana (copyright the Liana developers, 3-clause BSD licence,
  `LICENCE`), and from Pieter Wuille's Miniscript page. The first line of
  each excerpt names its origin.
- `l4/step0/promissory_note_traces.l4` (its first 325 lines), `l4/spike/rules.l4`,
  `l4/spike/sale.l4`, `l4/spike/l4run.mjs` and the loader in `l4/l4_oracle.mjs`:
  copied or adapted from L4 (`smucclaw/l4-ide`), copyright Singapore
  Management University; Apache License 2.0. `l4/l4_lex.pl` and
  `l4/l4_reader.pl` follow L4's lexer and parser, construct by construct.
- `solidity/contracts/FiatTokenSubset.sol`: a transcription of a part of
  Circle's `stablecoin-evm` (`contracts/v1/`), which is Circle's; Apache
  License 2.0. `solidity/contracts/MyToken.sol` is the output of the
  OpenZeppelin Wizard (MIT licence), and the `Ref*.sol` files import
  OpenZeppelin Contracts (MIT licence).
- `blawx/oracle.py`: two functions (`get_variables`, `simplify_rule`) follow
  `blawx/reasoner.py` of Blawx, by Lexpedite Legal Technologies; MIT
  licence.
- `daml/LICENSE-Apache-2.0.txt`: the licence text that the Daml twins carry
  with the templates of the Daml SDK (Digital Asset; Apache License 2.0).
- `oia/sources/extra/do_i_need_to_file/`, `student_benefits/` and
  `taxpayer_information/`: test cases for sample projects of
  `oracle-samples/ia-tools-samples`, which name the samples' attributes;
  copyright Oracle and/or its affiliates, Universal Permissive License 1.0.
- `rulespec/runs/`: results that hold the formulas of `rulespec-us` as Axiom's
  engine lowers them; the Axiom Foundation, CC BY 4.0.
- `epilog/data/mapcoloring.data`: its facts are the data sheet of the Epilog
  site (Stanford University), which Stanford cleared for publication in
  October 2026.

The compilers and engines that the checks call are downloaded, not copied
here: among them `solc` (GPL-3.0) and SPINdle (LGPL).

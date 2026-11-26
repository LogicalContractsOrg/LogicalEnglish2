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
- **Not the work of the other systems' makers.** The organisations that make
  the other systems did not write, review or endorse these translators. The
  names of the systems are used only to say what each translator reads and
  writes; they are trademarks of their owners.
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
| [lomo](lomo/README.md) | LOMO (the Legal Obligation Metadata Ontology of the European institutions) | yes | yes | `examples/migration/lomo/` |
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

A twin is a translation of its source. So a twin can be published here only
where the licence of the source allows a changed copy to be published under
the licence of this repository, or beside it with its own licence stated (as
the RONL twins are, under the EUPL-1.2). The twins of these sources are never
written into this repository or into LPS2:

- the public Oracle Intelligent Advisor projects that state no licence
  (projects of third parties; Oracle's own samples have the Universal
  Permissive License), and Socotra's product library, which states no
  licence;
- OpenFisca and PolicyEngine (AGPL-3.0: a twin can be published only under
  the AGPL-3.0, which this Apache-2.0 repository cannot carry);
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

- `blawx/oracle.py`: two functions (`get_variables`, `simplify_rule`) are
  copied from `blawx/reasoner.py` of Blawx, and the loop of `assemble`
  follows its `run_test`; copyright (c) 2022 Lexpedite Legal Technologies
  Ltd.; MIT licence (`blawx/BLAWX_LICENSE`).
- `catala/catala_reader.pl` follows the lexers and the grammar of the Catala
  compiler (`CatalaLang/catala`, `compiler/surface/`), copyright Inria and
  contributors; Apache License 2.0. No file of the compiler is copied.
- `daml/LICENSE-Apache-2.0.txt`: the licence text that the Daml twins carry
  with the templates of the Daml SDK (Digital Asset; Apache License 2.0).
- `dmn/oracle/src/main/java/org/lpsplus/dmnoracle/Tck.java`: its reading of a
  test file is a port of `DroolsTCKTest.parseType` of the DMN TCK
  (`dmn-tck/tck`, `runners/dmn-tck-runner-drools`); Apache License 2.0.
- `drools/corpus/drl/Fire.drl`, `drools/corpus/drl/HonestPolitician.drl` and
  `drools/corpus/java/org/drools/examples/`: examples of Drools, of Apache KIE
  (incubating), unchanged; Apache License 2.0 (stated at the top of each
  file). `drools/corpus/NOTICE.txt` repeats Apache KIE's attribution notices
  (the Apache Software Foundation; Red Hat).
- `epilog/data/mapcoloring.data`: the regions, the hues and the neighbours
  are the data sheet of the Epilog site (Stanford University); the colouring
  is ours.
- `l4/step0/promissory_note_traces.l4` (its lines 4 to 328),
  `l4/spike/rules.l4`, `l4/spike/sale.l4`, `l4/spike/l4run.mjs` and the
  function `load` of `l4/l4_oracle.mjs`: copied or adapted from L4
  (`smucclaw/l4-ide`), copyright 2025 Singapore Management University; Apache
  License 2.0 (`l4/spike/NOTICE.txt` says what was changed). `l4/l4_lex.pl`
  and `l4/l4_reader.pl` follow L4's lexer and parser, construct by construct.
- `legalruleml/corpus/oasis/`: the examples of the LegalRuleML Core
  Specification Version 1.0, copyright OASIS Open 2021, unchanged, under the
  notice of the specification (in full in `NOTICE.txt` in that folder).
- `lomo/corpus/lomo-1.1.0/`: the data, the ontology, its word lists, its
  shapes and its search queries of LOMO 1.1.0 (`code.europa.eu/drpm/lomo`),
  (c) European Union, Creative Commons Attribution 4.0, unchanged
  (`lomo/corpus/NOTICE.txt`); `lomo/corpus/spec-examples/`: the Turtle
  examples of the LOMO specification page, with the prefixes they use added.
- `miniscript/sources/`: texts from Bitcoin Core (MIT licence, `COPYING`)
  and from Liana (copyright the Liana developers, 3-clause BSD licence,
  `LICENCE`), and short quotations from Pieter Wuille's Miniscript page. The
  page states no licence, so the page itself is not copied. The first lines
  of each excerpt name its origin.
- `oia/sources/extra/do_i_need_to_file/`, `student_benefits/` and
  `taxpayer_information/`: test cases for sample projects of
  `oracle-samples/ia-tools-samples`, which name the samples' attributes;
  copyright Oracle and/or its affiliates, Universal Permissive License 1.0
  (the notice and the licence text: `oia/sources/extra/LICENSE-UPL-1.0.txt`).
- `ponens/ponens_formula.pl`: a port of the tokenizer and parser of Ponens
  (`cli/ponens/policy_compiler.py`), with that file's word lists. The eight
  laws of `structural_laws/3` in `ponens/ponens_twin.pl` follow
  `evaluate_structural` in its `cli/ponens/trace.py`. MIT licence; the
  copyright notice is in `ponens/PONENS_LICENSE`.
- `rulespec/runs/`: results that hold the test names, the expected values and
  the formulas of `rulespec-us`
  (https://github.com/TheAxiomFoundation/rulespec-us) as Axiom's engine
  lowers them; the Axiom Foundation, CC BY 4.0
  (https://creativecommons.org/licenses/by/4.0/), in a changed form
  (`rulespec/runs/NOTICE.txt`).
- `rune/parser/rune_expr.pl` follows the expression grammar of the Rune DSL
  (`Rosetta.xtext` of finos/rune-dsl 9.95.0), copyright 2019 - 2024 REGnosys;
  Apache License 2.0.
- `solidity/contracts/FiatTokenSubset.sol`: a changed copy of parts of
  Circle's `stablecoin-evm` (`contracts/v1/`): FiatTokenV1 and Blacklistable,
  copyright Circle Internet Group, Inc., Apache License 2.0; Ownable and
  Pausable, Circle's forks of OpenZeppelin's, copyright zOS Global Limited,
  Smart Contract Solutions, Inc. and CENTRE SECZ, MIT licence. Its header
  carries the notices and lists the changes. The other contracts in
  `solidity/contracts/` were written for this folder; their first line
  offers them under the MIT licence as well. The `Ref*.sol` files and
  `MyToken.sol` import OpenZeppelin Contracts (MIT), which npm downloads.

The compilers and engines that the checks call are downloaded, not copied
here: among them `solc` (GPL-3.0) and SPINdle (LGPL).

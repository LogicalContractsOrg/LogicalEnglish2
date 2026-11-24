# The Rune parser

Three files that work together, kept in this folder so that they can be
offered on their own later (a Rune parser for Prolog):

| File | What it does |
|---|---|
| `rosetta2json.py` | the structure of a Rune model: namespaces, imports, types, enumerations, choices, functions, reporting and eligibility rules, reports, rule sources, as one JSON file per namespace. Python 3, standard library only |
| `rune_expr.pl` | Rune's expression language in Prolog: the lexer, the parser (a DCG written after Rune's own grammar, `Rosetta.xtext` of finos/rune-dsl 9.95.0; the Rune DSL is a FINOS project, copyright 2019 - 2024 REGnosys, Apache License 2.0) and the printer |
| `rune_reader.pl` | the model in Prolog: the JSON of `rosetta2json.py` loaded as facts of the module `rune_model`, names resolved through the imports, every expression parsed by `rune_expr.pl` |

```sh
python3 parser/rosetta2json.py <folder of .rosetta files> <json folder>
swipl -g "use_module(parser/rune_reader), load_rune_model('<json folder>')"
```

**The gate** (`../gate.pl`): every expression of DRR 7.14.0 and of the CDM
it carries, 10,479 of them, printed back by `rune_expr.pl`, gives the
tokens of its source.

**Where `rosetta2json.py` comes from.** It is a copy of cdmLOG's converter
(`tools/rosetta2json/` in cdmLOG, version 0.2.0, commit e34b3ac of 6 October
2026), which this work extended to read DRR (reports, reporting and
eligibility rules, import aliases, five fixes). cdmLOG is a private
repository, so the copy lives here and the two are maintained in parallel
for now: a change made in one should be made in the other.
`rosetta2json.README.md` is cdmLOG's description of the tool.

**Its tests**: `python3 parser/test_rosetta2json.py`. The demo model in
`testdata/demo/` is a copy of cdmLOG's, and it is not in this repository
(the `DemoGolden` tests need it); the corpus tests read the CDM and
DRR files that `../fetch_sources.sh` downloads (or `$CDM_ROSETTA`).
Three tests check figures of cdmLOG's CDM 8 copy and run only with
`CDM_VERSION=8`.

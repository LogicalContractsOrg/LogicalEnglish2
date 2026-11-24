# rosetta2json

Deterministic Rune DSL (`.rosetta`) → JSON converter, replacing the LLM-based
conversion described in `examples/CLAUDE.md` (Phase 1 of
`docs/ReimplementationPlan.md`).

```bash
# regenerate all namespaces (and namespaces.json):
python3 tools/rosetta2json/rosetta2json.py examples/cdm examples/cdm/json-generated --namespaces-json

# semantic diff against another schema-json directory:
python3 tools/rosetta2json/diff_schemas.py examples/cdm/json examples/cdm/json-generated
python3 tools/rosetta2json/diff_schemas.py -v OLD NEW | python3 tools/rosetta2json/classify_diffs.py

# tests:
python3 tools/rosetta2json/test_rosetta2json.py
```

Stdlib-only, no dependencies. Converts all 145 `.rosetta` files (90 namespaces)
in ~0.7 s. A CDM release bump is: drop in the new `.rosetta` files, re-run,
review the diff.

## Output contract

One `<namespace>.json` per namespace, merging all its files, with the fields
`cdm.pl` (`loadSchema` / `updateComponents`) consumes. Same shape as the
LLM-made files in `examples/cdm/json/`, canonicalised:

| Field | Shape |
|---|---|
| `types.<N>` | `{description?, extends?, metadata?, annotations?, attributes, conditions?, conditionDescriptions?}` |
| `types.<N>.attributes.<a>` | `{type, cardinality, description?, override?, metadata?, annotations?}` — `[metadata scheme]` → `metadata: {scheme: true}` (the form `typeAttributeMetadata` reads) |
| `choices.<N>` | `{description?, options: [name \| {value, description}]}` (always an array — never the dict form found in one legacy file) |
| `enums.<N>` | `{description?, values: [name \| {value, displayName?, description?, annotations?}]}` |
| `functions.<N>` | `{description?, annotations?, inputs?, output?, conditions?, conditionDescriptions?, postconditions?, implementation?}` |
| `functions` implementation | array of `{set\|add\|alias: {target: expression}, description?}` in source order |
| `typeAliases.<N>` | `{description?, parameters?, definition}` — definition kept verbatim |
| `reports.<Body Corpus>` | `{regulatoryBody, corpus, timing, input, eligibility: [rule], reportType, source?}` — `report CFTC Part45 in T+1 from X when R with type T` (DRR) |
| `reportingRules.<R>`, `eligibilityRules.<R>` | `{input?, description?, label?, annotations?, expression}` — `reporting rule R from T: <"doc"> [docReference ...] expression [as "label"]`; the expression verbatim, as for functions |
| `conditionAnnotations.<C>` (types, functions) | the `[docReference ...]` a condition starts with, taken out of its expression |
| attribute `annotations.label`, `annotations.ruleReference` | lists of `{for?, value}`: `[label for leg1 -> notionalAmount "..."]`, `[ruleReference for x R]`, `[ruleReference empty]`; `docReference` entries carry `for` too |
| `importAliases` | `{alias: namespace}` — `import drr.standards.iosco.cde.version2.* as cde` |
| `fileScopes.<file>` | `{imports, importAliases, members}`, written when a namespace has aliases: Rune resolves names per file, and two files of one namespace may give an alias different namespaces |
| top level | `namespace, namespaceDescription?, version?, provenance, originalFiles, imports, bodies, corpora, segments, metaTypes?, annotations?, synonyms?, rootDeclarations?` + component sections |

Contract clarifications vs `examples/CLAUDE.md` (all invisible to the loader,
which ignores unknown fields):

- **Conditions are always `{name: expression-string}`** (some legacy files used
  `{description, expression}` objects, which the loader cannot read). Condition
  docstrings go to a parallel `conditionDescriptions` object.
- **Anonymous conditions** get keys `condition`, `condition2`, … (matching the
  dominant legacy convention).
- **Dispatch functions** `func F(param: Enum -> V):` get key `F(V)` and inherit
  `inputs`/`output` from the base `F` (the loader's `function/4` needs `output`).
- **Expressions are verbatim** (indentation and newlines preserved), except
  `//` comments are stripped — several legacy files glued a comment between two
  expression lines, which comments out the rest of the expression if executed.
- `provenance` is `"rosetta2json <version>"` — reproducible, no LLM.

## Parser design

Not a full Rune grammar: expressions are captured as text (they are consumed as
text by prompt generation, and executed only by the finos-cdm validator — see
plan §2.3), so the parser only needs the *structural* grammar:

1. **Lexer** (`logical_lines`): folds multi-line `<"...">` docstrings into one
   logical line; strips `/* ... */` block comments; tab-aware indentation.
2. **Block grouping** (`blocks_of`): top-level constructs at column 0 (with
   tolerance for mis-indented headers like ` func Create_Bicycle:` in the demo
   corpus); `{ ... }` synonym-source bodies attach to the preceding construct.
3. **Per-construct parsers**: attributes (`[override] name Type (m..n) <"doc">
   [annotations]`), conditions, enum values (with `displayName`), choices,
   typeAliases, functions (inputs/output/conditions/post-conditions/set/add/
   alias), annotation definitions, body/corpus/segment/metaType declarations,
   `isEvent`/`isProduct` roots, synonym sources.
4. **Annotations** `[ ... ]` may span lines (docReference provisions); bracket
   balance is tracked outside quoted strings. `[metadata x]` → `metadata`,
   `[docReference ...]`/`[synonym ...]` → structured `annotations` entries,
   anything else → `annotations: {name: [args]}`.

## DRR (since 0.2.0)

ISDA's Digital Regulatory Reporting is written in the same language and
reads with the same converter: 506 files of DRR 7.14.0 (with the copies of
the CDM 6.29 it builds on) give 327 namespaces, with all 1,971 reporting
rules, 51 eligibility rules, 28 reports, 2,762 functions and 4,191 types,
in about 6 seconds. The Rune door of Logical English (`migration/rune/`)
parses every expression of them in Prolog (10,479 of 10,479 print back to
their own tokens). The fixes this needed, all invisible to `cdm.pl` (the
CDM's own output only gains `importAliases` and `fileScopes`):

- a comment at column 0 inside a construct no longer ends it;
- a multi-line `provision "..."` keeps its lines (also one starting at
  column 0, and one with `//` inside), and the rest of the construct after it;
- `//` inside a `'...'` string is not a comment;
- a rule whose expression starts with a list literal (`[a, b] then ...`)
  is not read as an annotation.

## Known limitations

- `synonym source X { ... }` bodies (mapping namespaces) are captured verbatim
  in a `body` string, not parsed — CDMlog does not consume them.
- `[metadata address "pointsTo"=...]`-style parameterised metadata is kept
  raw under `metadata._raw`.
- Enum names are source-faithful (`_1`, `_30` in `RollConventionEnum`, with
  `displayName "1"` etc.); some legacy files stripped the underscore.

See `ComparisonReport.md` for the audit of the legacy LLM-made files against
this converter's output.

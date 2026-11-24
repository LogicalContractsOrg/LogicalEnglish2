# Socotra → Logical English

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

Phase 1a of the design notes `roadmap.md` §8 ("Socotra — build and
prove"): a reader that turns a Socotra product configuration (the classic
JSON + Liquid configuration of `socotra/product-library`) into a Logical
English twin, with a migration ledger and the product's own quotes as
scenarios. The twins are in
`examples/migration/socotra/`.

| File | What it is |
|---|---|
| `socotra_reader.pl` | the reader: product model → Migration IR (LE2's `le_writer.pl`), ledger and scenarios (`le_migration.pl`) |
| `liquid.pl` | a parser for the Liquid the product library uses (assign, if/elsif/else/unless, case/when, for, comment, filters) |
| `oracle.py` | the reference run: executes the product's own Liquid with python-liquid and Socotra's filters as shims, over generated quotes |
| `socotra_sources.pl` | where each rule comes from: every cited file a document of the twin (GitHub page at the pinned commit; text in the twin's `sources/`), each rule at its passage (a quotation, or a line locator) |
| `socotra_import.pl` | the File ▸ Open adapter (LE2's `le_import.pl` registry, `migration/le_importers.pl`): a zip or folder of a product configuration → a twin, with the product's files copied into its `sources/<Product>/`; a lone `policy.json` / `exposure.json` → its fields |
| `fetch_sources.sh` | clones the sources into `sources/.cache/` (git-ignored) at pinned commits |
| `test_socotra.pl` | plunit tests: the parser, snippet translations, values, one product end to end, documents and passages, an import |

## Licence status

`socotra/product-library` has **no licence file**. Its files are never
vendored here: `fetch_sources.sh` clones it into `sources/.cache/`
(git-ignored) and the twins are generated from that cache. The twins are
derived works; they are kept in this private repository and **publication
awaits confirmation of the product-library licence** — every ledger header
says so (`licence` in its meta). `socotra/public` is MIT (its README); it is
fetched for reference only (its `premium_test` harness is what the oracle's
shims follow) and nothing from it is copied.

## How to run

```sh
cd LE2 migration/socotra
./fetch_sources.sh                                   # sources/.cache/{product-library,public}
# one product (LE2: $LE2_DIR, or a checkout beside this repository — ../le2_paths.pl)
swipl -g "use_module(socotra_reader), build_product('sources/.cache/product-library/Pet', '../../examples/migration/socotra', R), print(R), halt."
# all 17 (about 25 s)
swipl -g "use_module(socotra_reader), build_all('sources/.cache/product-library', '../../examples/migration/socotra'), halt."
# tests
swipl -q -g run_tests -t halt test_socotra.pl
```

The oracle needs Python 3 with `python-liquid` 2.x (run as `python3` from
the PATH). On a machine without it, `build_product/4` and `build_all/3` with
the option `reuse_quotes(true)` keep each twin's `quotes.json` of an earlier
run instead (the reference run is deterministic), e.g.
`build_all('sources/.cache/product-library', '../../examples/migration/socotra', [reuse_quotes(true)])`.
`build_product/3` runs it (10 quotes per product), translates,
writes `<product>/<product>.le`, the CSV tables, `quotes.json`, the ledger
(`.ledger.md`, `.ledger.json`) and runs the twin's scenarios; its report is
`report(LEFile, Errors, counts(Encoded, Approximated, Residue),
fidelity(Passed, Failed, Errors, Rows))`.

## Navigating to the source (documents and passages)

Every rule cites the file it was translated from, and that file is a
**document of the twin**, so the editor's source viewer (§ in the executive
view, *Show definition* on a provenance trailer) opens it:

```le
"Contract Surety/policy/exposures/bid/perils/license.premium.liquid" is published at "https://github.com/socotra/product-library/blob/df4a7f8.../Contract%20Surety/policy/exposures/bid/perils/license.premium.liquid".
the text of "Contract Surety/policy/exposures/bid/perils/license.premium.liquid" is at "sources/Contract Surety/policy/exposures/bid/perils/license.premium.liquid".
```

— the public GitHub page at the pinned commit, and the text of the copy in the
twin's `sources/` folder (`build_product/4` copies the product's Liquid, JSON
and CSV files there; they are kept, like the twin, in this private repository —
see `fetch_sources.sh`), so the viewer needs no network and **File ▸ Show the
Original** lists them. Each rule also points at **its
passage** of the file (`socotra_sources.pl`): a short passage without double
quotes is quoted (`confer "{{ premium | set_year_premium }}"`, which the
viewer highlights), a longer one is a line locator (`at lines 3 to 9`,
`at line 18`). The passage is found from what the rule is: the k-th quantity
of a variable is the k-th if/case/for block assigning it counted from the end
(the reader numbers a variable's quantities from its last value back), with
the plain assignment just before it; an output rule is the line of its `set_*`
filter; the i-th `add_*` output the i-th `add_*` filter. All 284 rules the
Liquid produces across the 17 twins are located; the lookup rules cite their
CSV table as a whole. The quotes are a document too (`the text of Pet rating
quotes is at "quotes.json"`).

## Opening a configuration in the editor (File ▸ Open)

`socotra_import.pl` is the adapter LE2's `le_import.pl` calls when the editor
opens a **zip** (or a folder) holding a classic product configuration — the
product-library layout (`<Product>/policy/policy.json`, exposures, perils,
`.premium.liquid`, taxes, fees, tables) or Socotra's
`products/<name>/policy/...`, found up to three levels down. The translation is
the reader's; a script it cannot follow is a residue block (a `% TODO` comment
with the Liquid verbatim), the rest is translated. The product's Liquid, JSON
and CSV files are copied into `sources/<Product>/` beside the program and are
the rules' documents (`the text of "Homeowners/policy/..." is at
"sources/Homeowners/policy/..."`; quotations checked against them), and the
note says where they are. Quotes come from the reference run when python3
with python-liquid is installed; otherwise (or when the run fails) the
program has no scenarios, and the note and the program's header say that the
quote scenarios were skipped and why (no python3, no python-liquid, or the
run's last error line). An upload with several products translates the first
and names the others. A lone `.json` that is a classic configuration's
`policy.json` or `exposure.json` (a `fields` list of named, typed fields) is
translated too, as the product folder it belongs in: its fields as scenario
elements (`product_migration/4` with `declare_fields(true)`), no rules,
queries or view, and a note that the scripts and tables need the zipped
folder.

```prolog
socotra_import:import_socotra(+InputDir, +OutDir, -imported(LEFile, Notes)).
socotra_import:detect_socotra(+InputDir).
```

## The mapping

| Socotra | Logical English |
|---|---|
| policy / exposure / peril fields (`policy.json`, `exposure.json`, `perils/*.json`) | scenario-element templates: `the <field> of *a policy* is *a value*`, `the <field> of *a vehicle* is *a number*`, `the <field> for *a peril* on *an exposure* is ...` (dates as LE dates; select values as strings, or numbers when they read as one) |
| exposure kinds | a type per kind (`a vehicle`, `a work cover`); each quote states both `vehicle 1 is a vehicle` and `vehicle 1 is an exposure` |
| peril characteristics (limits, deductible, lump sum) | `the deductible for *a peril* on *an exposure* is *an amount*` |
| `<peril>.premium.liquid` | rules, by symbolic execution: an `assign` is a value; branches that give a variable different values are an `otherwise` cascade (a quantity `the <peril> <variable> for *a vehicle* is *a number*`, one per step when reassigned; *a value* when a branch gives it a text); `round: d` is `round(x * 10^d) / 10^d.0`, half away from zero and a double, as the reference Liquid; `set_year_premium`, `set_month_premium`, `set_year_technical_premium`, `add_year_commission` ... are the conclusions `the yearly premium for *a peril* on *an exposure* is *an amount*` ... guarded by `the exposure is covered for <peril>` |
| `taxes/<tax>.premium.liquid` | `the <tax> tax for *a peril* on *an exposure* is *an amount*` (the peril's premium read as its yearly premium) |
| `underwriting.guidelines.liquid` | `the underwriting decision for *a policy* is *a decision*`, `the underwriting notes for *a policy* include *a note*`; a decision set later overrides one set earlier (last write wins: cascades) |
| `policy.calculations.liquid` (`add_fee`) | `the <fee> fee for *a policy* is *an amount*` and its description |
| `data.policy.characteristics[0].gross_premium` / `gross_taxes` | derived: the sum of the perils' yearly premiums / taxes |
| loops over the exposures / perils | an existential condition (`for some exposure of the policy ...`), a sum aggregate for an accumulator, a decision "written when some item satisfies its condition" |
| `"table" \| lookup: key` | a CSV-loaded decision table (unique match) citing the carrier's file, read through `the <table> lookup of *a key* is *a value*`, which gives 0 for a missing key (Liquid's nil) |
| `timestamp_millis_print: "YYYY"` of a date | `the year of *a date* is *a number*` (`lib/temporal`, copied beside the twin) |
| everything else | a residue block (`% RESIDUE rN BEGIN ... END`) with the Liquid source, why it was not translated, what it must conclude and which fields the quotes state for it |

Conventions (the ledgers record each use):

- **Arithmetic (E4).** The reference Liquid: whole numbers stay whole and
  whole ÷ whole is integer division (`//` in the twin); otherwise IEEE
  doubles; `round` rounds half away from zero; nil is 0 in arithmetic and
  false in a comparison. The twins do no rounding of their own: an amount is
  the double the source computes, so expectations compare exactly.
- **Values.** A value is read as LE's CSV loader reads a cell (`0005` is 5;
  `.9` becomes `0.9` in the copied table); a value opening with a comparison
  sign, which a CSV cell would read as a condition, is spelled out (`<50%`
  → `under 50%`) in the scenarios, the rules and the copied table alike.
- **Source defects** (a variable never assigned, a table the product lacks,
  a misspelt variable) are translated as Liquid reads them (nil) and listed.

## Scenarios: the product's own quotes

There are no rating tests in the product library, and `socotra/public`'s
`premium_test` prices a single peril against a live Socotra tenant (its
`test_peril.json` is a request, with no expected result), so `oracle.py` makes
the tests without the platform: it builds a base quote (the first value of each select, representative
numbers by field name, a table's first key for a lookup field) and variants
(each other select value, each threshold a script compares a number with),
spread over 10 quotes, and executes the product's Liquid on each with
python-liquid, Socotra's filters as shims and the reference-Liquid arithmetic
above. Every output (premiums, technical premiums, commissions, taxes, fees,
underwriting decision and notes) becomes an expectation of that quote's
scenario (`as stated in "<Product> rating quotes" at quote <id>`). A peril
whose script the reference run itself cannot execute is left uncovered in
the quote.

## Results

17 twins, 519 rules, 25 tables, 140 quote scenarios; **all 992 tests that
can run pass, and 14 of 17 products reproduce every quote**; the 100 other
expectations depend on the four residue blocks and are *pending* — written
as comments in their scenarios and counted in the ledgers (Travel Multi
Trip's perils are residue); the ledgers count 1265 elements
encoded, 63 approximated, 4 residue. All load with 0 errors; the
largest (Workers Compensation) runs its 130 tests in 2.6 s. Per product: the
index.

## Residue, and why

| Product | Script | Why |
|---|---|---|
| Homeowners | `underwriting.guidelines.liquid` | a variable assigned inside the loop over the exposures and read after it (Liquid keeps the last item's value) |
| Product Liability | `Explosion_Mobile.premium.liquid` | a loop over a repeatable field group read through `field_groups_by_locator`, and a looked-up text split into an array |
| Travel Multi Trip | `benefit.premium.liquid`, `medical.premium.liquid` | the coverage timestamps, and `get_30_360_day_count`, a filter that is not Liquid (the reference run cannot execute these scripts either) |

The expectations that depend on these blocks (Homeowners' underwriting;
Product Liability's mobile explosion premium and the taxes, gross premium and
fees built on it; Travel's peril premiums) are pending: `le_migration` finds
them from the IR — a query whose rules reach what a residue block must
conclude (`concludes([...])` on the residue item) — and writes them as
comments, restored when the block is translated.

**Residue mode, live.** The Homeowners block was given to the Contract
Assistant's residue mode (`le_contract_assistant.pl`, `mode: "residue"`, the
twin as skeleton) with `gpt-5.5`: one draft and one repair call, 61 s, and the
block came back translated with 0 errors and **80/80** tests passing (from
60/80). The rules and the run: `examples/migration/socotra/homeowners/residue_r1_live_run.md`.
The twin itself keeps the block as residue until a person adopts them.

## Implementation status (for §8, Phase 1a)

*Implementation status (13 September 2026): done, in `migration/socotra/`
(reader, Liquid parser, reference-run oracle, fetch script, tests; README) and
`examples/migration/socotra/` (17 twins with ledgers, quote scenarios and a
quote-desk View each).* The reader translates the product model into
templates and the Liquid rating, tax, fee and underwriting scripts into rules
by symbolic execution (branches as `otherwise` cascades, loops as existential
conditions and sum aggregates), with the carrier's CSV rate tables loaded as
decision tables. The rating test tool of `socotra/public` prices a peril
against a live Socotra tenant and carries no expected results, so the
scenarios come from a reference run of each product's own Liquid (python-liquid with Socotra's filters as shims, reference-Liquid
arithmetic — the E4 convention is stated in every ledger). Every test that
can run passes (992), 14 of the 17 products reproduce every quote, and the
100 expectations that depend on the four residue blocks (one underwriting
script, three peril scripts) are pending, as comments counted in the ledgers;
and the Contract Assistant's residue mode, run live on the Homeowners block,
brought that product to 80/80. The twins stay private until the
product-library licence (no licence file) is confirmed.

# Socotra and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

Socotra is a core platform for insurance, in the cloud. A carrier (an insurance
company) describes a product in a *product configuration*. A product configuration
contains three kinds of file:

- JSON files declare the policy, its exposures (a vehicle, a dwelling, a pet) and
  their perils. JSON (JavaScript Object Notation) is a plain-text format for
  structured data.
- CSV files contain the rate tables. CSV (comma-separated values) is a plain-text
  format for a table.
- Scripts in the Liquid template language calculate the premiums, the commissions,
  the taxes, the fees and the underwriting decision.

The editor translates a classic Socotra product configuration, JSON and Liquid
together, into Logical English (LE). The fields become templates. A template is a
sentence pattern that the program declares. The Liquid scripts become rules, and the
rate tables become decision tables. The program also gets a *quote desk* view. A view
is a screen that shows the program to its users. The translation goes in one
direction only, from Socotra into Logical English. There is no exporter back to
Socotra. To use the translator, select **File ▸ Open…** or **File ▸ Import from
Another System…**. The translator needs the Logical English Translators. Some
installations have them, for example the hosted service.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [What to upload](#what-to-upload)
  - [Importing](#importing)
  - [The note and the ledger](#the-note-and-the-ledger)
  - [Running the translation](#running-the-translation)
  - [Show the Original and the rules' citations](#show-the-original-and-the-rules-citations)
  - [Examples to try](#examples-to-try)
- [How Socotra maps to Logical English](#how-socotra-maps-to-logical-english)
  - [Liquid scripts become rules](#liquid-scripts-become-rules)
  - [Rate tables](#rate-tables)
  - [Loops over exposures and perils](#loops-over-exposures-and-perils)
  - [Quotes as scenarios](#quotes-as-scenarios)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| Socotra → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | A `.zip` of a product configuration (a folder with `policy/policy.json`). Or one `policy.json` or `exposure.json`, for its fields only | A program with the rating, tax, fee and underwriting rules of the product, its rate tables, generated quotes as scenarios, a quote desk view, a ledger, and the files of the product in `sources/` | The Liquid scripts of the product. A reference Liquid interpreter runs them on the generated quotes, and copies the filters of Socotra |
| Logical English → Socotra | none | | | |

## How to use it

### What to upload

Upload a **zip archive** of the configuration. The translator looks in the archive,
to a maximum of three folders deep, for a product folder. A product folder is a
folder that contains `policy/policy.json`. The translator finds these two layouts:

- the layout of the public product library of Socotra, `<Product>/policy/...`;
- the layout of a Socotra configuration, `products/<name>/policy/...`.

The translator reads these files in the product folder:

- `policy/policy.json`, `policy/exposures/<exposure>/exposure.json` and the JSON of
  the perils: the fields;
- `<peril>.premium.liquid`: the rating scripts;
- `policy/taxes/`: the tax scripts;
- `policy/underwriting.guidelines.liquid`: the underwriting decision and notes;
- `policy/policy.calculations.liquid` and `fees.json`: the fees;
- `policy/tables/<table>.csv`: the rate tables.

The document templates (`schedule.template.liquid`, `invoice.template.liquid` and
similar files) make the layout of documents. They do not make decisions. Thus the
translator does not read them. The ledger gives a list of those files and tells this.

If the archive contains more than one product, the translator translates the first
product in alphabetical sequence. The note gives the names of the other products. To
translate a different product, put it in a separate archive and open that archive.

The translator also translates one `.json` file, if the file is the `policy.json` of
a product configuration or an `exposure.json`. An `exposure.json` is a list of named
`fields`, each with its type. Such a file does not contain rating. The program then
declares the fields of the file as the facts of a quote
(`the channel of *a policy* is *a value*; scenario element.`). The program has no
rules, no queries and no view. The note tells you that the rating, taxes, fees and
underwriting are in the scripts and tables of the product folder. To translate them,
make a zip of the product folder. A different `.json` file opens as a program that
contains the text of the file in a `% TODO` comment, with the reason.

### Importing

Do these steps:

1. Select **File ▸ Import from Another System…** (or **File ▸ Open…**).
2. Select the zip.

The server unpacks the archive, finds the product folder, and translates the product.
The program opens in a new tab. The name of the program comes from the product
(`pet.le` for a product with the name Pet).

A note below the menu bar tells you that the *Socotra product configuration*
translator did the work. The note also gives the remarks of the translator. The next
section describes them. To close the note, click its `×`.

The server keeps the upload and its translation for one day. To keep the program,
select **File ▸ Save As…**.

### The note and the ledger

This is an example of the note:

> Pet: 52 ledger elements encoded, 7 approximated, no residue; 0 writer errors.

Then the note tells where the quote scenarios came from, or why the translator did
not make them. When there are quotes, the note gives the results of their
expectations. It also tells where the translator put the files of the product:

> The product's Liquid, JSON and CSV files are copied into sources/Pet/ beside
> the program (File > Show the Original lists them); every rule cites its file
> and passage there.

The translator also writes a *ledger* next to the program (`<product>.ledger.md`).
Each row is one element of the configuration: a script, a branch of a script, an
output, a field, a table, a fee, or a value of the platform. Each row gives its
result:

- **encoded**: translated, with no change to its meaning;
- **approximated**: translated, with a recorded change of meaning (the note on the
  row tells the change);
- **residue**: not translated. The program keeps the element as a residue block.

The ledger also records the convention for arithmetic. When the program has quotes,
the ledger also tells how many of their expected values the program gives.

**Quotes need the reference run.** To make the scenarios, the translator makes ten
quotes. Then it runs the Liquid scripts of the product on them. That run needs
Python 3 on the server, with the `python-liquid` package installed. If the run is not
possible, the note tells you that the translator did not make the quote scenarios.
It also tells the reason: no `python3`, no `python-liquid`, or an error in the run.
The comment at the top of the program tells the same:

> Quote scenarios skipped: the reference run of the product's Liquid needs the
> python-liquid package (pip install python-liquid), which this server's
> python3 lacks. The program has no scenarios, so nothing checks its rules
> against the product's Liquid; state a quote in the Scenario Editor to run it.

The rules, tables, queries and view are the same in the two conditions.

### Running the translation

The program has one query for each kind of output: `yearly_premiums`,
`yearly_technical_premiums`, `yearly_commissions`, `underwriting_decision`,
`underwriting_notes`, one query for each tax (`taxes_sales`), one query for each fee
(`fees_transaction`), and `declined`.

- Select a scenario (a quote) and a query, and run the query as usual. The
  explanation of each answer goes down through the rules to the fields of the quote.
- **Misc ▸ Run the Program's Tests…** runs all the expectations of the quote
  scenarios. It shows each expectation in a list with its result.
- If the program has no quotes, write a quote yourself in the Scenario Editor. Give a
  policy, its exposures, the perils that cover each exposure, and the fields that the
  rules read. The quote desk view shows a list of exactly those fields.
- The **quote desk** view shows the case in groups: policy, exposure and coverage.
  The result is the yearly premiums. Next to them are the total premium, the
  technical premiums, the commissions, the taxes, the fees, and the underwriting
  decision with its notes. The view shows amounts with 2 decimals. When the decision
  is `reject`, a red banner shows "Declined by underwriting: this policy cannot be
  bound". At the end of the view is a draft of the quote, as text.

### Show the Original and the rules' citations

**File ▸ Show the Original…** shows a list of the files of the product: the Liquid,
JSON and CSV files. The translator copies these files into the `sources/` folder of
the program, below the name of the product. Select one of the files, and it opens in
the source viewer.

Each rule cites the file that the translator translated it from. Where the
translator can find it, the rule also cites the passage in that file. The rule quotes
a short passage after `confer`. It gives a longer passage by its line numbers.

```le
rule accident_limit_factor_key_1 with provenance "Pet/policy/exposures/Pet/perils/accident.premium.liquid",
        confer "{% if peril_c.indemnity_per_item <= 500.00 %} {% assign limit_factor_key = 'A' %} {% else %} {% assign limit_factor_key = 'B' %} {% endif %}":
```

```le
rule accident_premium_2 with provenance "Pet/policy/exposures/Pet/perils/accident.premium.liquid" at lines 7 to 41:
```

A provenance trailer is the part of a rule that tells its source. Put the cursor on a
provenance trailer, and use **Show definition** (F12, or the right-click menu). The
cited file opens in the source viewer, with the passage highlighted. When the program
loads, the editor checks the quotations against the copied files.

### Examples to try

The lpsPlus examples include the twins of the seventeen products of the public
product library of Socotra. A twin is the translation of a product. The products
include Pet, Personal Auto, Homeowners, Workers Compensation, Term Life, Cyber, Drone
and others. You can see those examples only on installations that have them, and
only if you have access. To open a twin, select **File ▸ Open example from
server…**:

- `lpsPlus/migration/socotra/pet/pet`: small (27 rules, three tables), with an
  underwriting rejection in the Lion and Elephant quotes;
- `lpsPlus/migration/socotra/personal_auto/personal_auto`: seven perils and the
  loadings for the history of claims;
- `lpsPlus/migration/socotra/term_life/term_life`: ages from dates of birth, with
  lib/temporal;
- `lpsPlus/migration/socotra/homeowners/homeowners`: a residue block, and
  expectations that wait for it.

Each twin has its ledger, its quotes (`quotes.json`), and the files of the product in
`sources/`. For all seventeen products, each expectation that can run passes: 992
expectations. Another 100 expectations wait until somebody translates the four
residue blocks. The twins are different from a usual import in one item: each file
that a twin cites also has a link to its page in the public product library on
GitHub.

## How Socotra maps to Logical English

| Socotra | Logical English |
|---|---|
| A policy field (`policy.json`) | A scenario-element template: `the channel of *a policy* is *a value*; scenario element.` |
| A kind of exposure and its fields (`exposure.json`) | A type with the name of the kind, and templates: `the pet type of *a pet* is *a value*; scenario element.` A quote states both `pet 1 is a pet.` and `pet 1 is an exposure.` |
| A peril and its characteristics | `*an exposure* is covered for *a peril*; scenario element.` and `the indemnity per item for *a peril* on *an exposure* is *an amount*; scenario element.` |
| A field that no script reads | Not declared (the ledger tells this) |
| `assign` in `<peril>.premium.liquid` | A quantity: `the accident premium for *a pet* is *a number*.` There is one template for each step when the script assigns the variable again (`the accident premium at step two for *a pet* is *a number*.`). Use *a value* when a branch gives it a text (`the accident limit factor key for *a pet* is *a value*.`) |
| `round`, `round: 2` | `N = round(M)`; `N = round(M * 100) / 100.0` (half away from zero, as the reference Liquid does) |
| `if` / `elsif` / `else` / `unless`, `case` / `when` | An `otherwise` cascade: the first branch that agrees |
| `set_year_premium`, `set_year_technical_premium`, `set_month_premium`, `add_year_commission`, ... | The conclusions `the yearly premium for *a peril* on *an exposure* is *an amount*.` and similar conclusions, with the condition `the exposure is covered for accident` |
| `taxes/<tax>.premium.liquid` | `the sales tax for *a peril* on *an exposure* is *an amount*.` |
| `underwriting.guidelines.liquid` | `the underwriting decision for *a policy* is *a decision*.`, `the underwriting notes for *a policy* include *a note*.` |
| `add_fee` in `policy.calculations.liquid`, `fees.json` | `the transaction fee for *a policy* is *an amount*.` and its description |
| `gross_premium`, `gross_taxes` (the platform calculates them) | Derived rules: the sum of the yearly premiums, or taxes, of the perils |
| `"table" \| lookup: key` | A decision table that the program loads from the CSV of the carrier. Rules read it through `the <table> lookup of *a key* is *a value*`. A missing key gives 0 |
| `for` over the exposures or perils | An existential condition (a condition about one item), or a `sum` aggregate for an accumulator |
| `timestamp_millis_print: "YYYY"` of a date | `the year of *a date* is *a number*` (lib/temporal, copied next to the program) |
| All other items | A residue block with the Liquid text, unchanged |

### Liquid scripts become rules

The translator reads each script, but it does not run it on actual numbers. The
translator follows each branch and records the value of each variable. It writes a
rule for each value that an output filter receives. If different branches set a
variable differently, the variable becomes a cascade. The rule below comes from the
accident script of the Pet product:

```le
rule accident_premium_1 with provenance "Pet/policy/exposures/Pet/perils/accident.premium.liquid" at lines 7 to 41:
the accident premium for a pet is a number N if
    the accident premium at step two for the pet is a number M
    and all of
        the pet type of the pet is "Cat"
        and N = round(M + 10.0)
        otherwise N is equal to M.
```

The output filter is the conclusion:

```le
rule death_yearly_premium_final with provenance "Pet/policy/exposures/Pet/perils/death.premium.liquid",
        confer "{{ premium | round | set_year_premium }}":
the yearly premium for death on an exposure is an amount N if
    the exposure is covered for death
    and the death premium for the exposure is a number M
    and N = round(M).
```

The underwriting script sets a decision. A later setting in the script replaces an
earlier setting. Thus the translation tries the last setting first. The result is a
cascade of *provisional* decisions. The cascade ends in
`the underwriting decision for a policy is a decision`. Notes are different. A script
adds a note, and does not replace the notes before it. Thus each note becomes a
separate rule:

```le
rule underwriting_note_two_final with provenance "Pet/policy/underwriting.guidelines.liquid" at line 14:
the underwriting notes for a policy include "Policy does not meet guidelines for automatic acceptance as the pet is a Lion" if
    the policy is a policy
    and an exposure is insured under the policy
    and the pet type of the exposure is "Lion".
```

### Rate tables

The scripts look up values in some tables. Such a table becomes a decision table with
unique match. The program loads the table from the CSV file of the carrier. The
translator copies that file next to the program:

```le
the table pet_base_rates_table is loaded from pet_base_rates_table.csv, with unique match:
    key | value
```

A rule reads the table. It gives 0 for a key that has no row in the table. Liquid
does the same, because in the arithmetic of Liquid, a missing value (`nil`) counts as
0:

```le
rule lookup_pet_base_rates_table with provenance "Pet/policy/tables/pet_base_rates_table.csv":
the pet base rates table lookup of a key is a value if
    the pet base rates table entry for the key is the value under table pet_base_rates_table
    otherwise the value is equal to 0.
```

### Loops over exposures and perils

Some loops decide something when an item satisfies a condition. Such a loop becomes a
condition about *some* exposure or peril. This example is from Workers Compensation:

```le
    and an exposure is insured under the policy
    and the exposure is covered for a peril
    and the class code for the peril on the exposure is 3315
        or the class code for the peril on the exposure is 3316
```

A loop that adds values becomes an aggregate. An aggregate is a calculation over many
items, for example a sum. The platform of Socotra calculates the gross premium, not a
script. The program calculates the gross premium in the same way:

```le
rule gross_premium:
the gross premium of a policy is an amount N if
    the policy is a policy
    and N is the sum of each M such that
        an exposure is insured under the policy
        and the exposure is covered for a peril
        and the yearly premium for the peril on the exposure is an amount M.
```

### Quotes as scenarios

A product configuration does not contain rating tests. Thus the translator makes its
own quotes. First, it makes a base quote with these values:

- the first value of each list field;
- typical numbers;
- for a field that the scripts look up in a table, the first key of the table.

Then the translator makes variants. Each variant changes one list value, or goes
across a threshold that a script compares a number with. The translator keeps ten
quotes in total. Then it runs the Liquid scripts of the product on each quote. Each
output becomes an expectation in the scenario of that quote:

```le
scenario quote_exposure_Pet_pet_type_Lion is, as stated in Pet rating quotes at quote exposure_Pet_pet_type_Lion:
    policy 1 is a policy.
    the channel of policy 1 is "Direct".
    pet 1 is a pet.
    pet 1 is an exposure.
    pet 1 is insured under policy 1.
    the pet type of pet 1 is "Lion".
    ...
    underwriting_decision expects answers ["the underwriting decision for policy 1 is reject"].
```

The expected values are the results of the scripts of the product, not the results of
the translation. The values do not come from Socotra. The reference run copies the
filters and the arithmetic of Socotra, without the platform.

## Traps

- **A JSON file gives only its fields.** One `policy.json` or `exposure.json` gives
  the fields and nothing more (refer to [What to upload](#what-to-upload)). For the
  rules, upload a zip of the product folder.
- **Classic configurations only.** The translator reads the JSON and Liquid
  configuration. It does not translate other items in your upload (plugins, claims
  forms, permissions, document templates).
- **No quotes without python-liquid.** If the server does not have the
  `python-liquid` package, the program has no scenarios. Thus nothing checks the
  translation against the Liquid scripts of the product. The note tells you that the
  translator did not make the quote scenarios, and why. Test the program on quotes
  for which you know the answers of the platform.
- **Residue.** If the translator cannot follow a script, it keeps the full script as a
  residue block. Each item that depends on that script then has no rule. The block
  tells why the translator did not translate the script. It also tells what the
  missing rules must conclude, and which fields the script reads:

  ```le
  % RESIDUE r1 BEGIN: Homeowners/policy/underwriting.guidelines.liquid
  % TODO: translate the fragment below by hand, or with the Contract Assistant (residue mode); it was not translated automatically
  %   source: Homeowners/policy/underwriting.guidelines.liquid
  % Not translated: the variable dwelling_c is assigned inside a loop and read after it (Liquid keeps the last item's value).
  % Conclude: the underwriting decision for *a policy* is *a decision*; the underwriting notes for *a policy* include *a note*.
  ```

  These items become residue:
  - a filter that is not Liquid arithmetic and not an output filter of Socotra (for
    example `get_30_360_day_count`);
  - arithmetic on dates or times;
  - a variable that a script sets inside a loop and reads after the loop;
  - a loop over a repeatable group of fields;
  - a Liquid tag that the translator does not know.

  In a twin, the expectations that depend on a residue block stay as comments,
  `% pending — waits for residue r1:`. Thus all the tests pass, and you can still see
  the gap. Translate the block manually, or with the *Migration residue* mode of the
  Contract Assistant. Then put those lines back.
- **Missing values are 0.** Liquid reads a missing table row as `nil`. It also reads
  as `nil` a variable that no script assigns. `nil` is 0 in arithmetic, and false in
  a comparison. The program also reads 0 in arithmetic. But a field that a quote does
  not state is different. The rules that read the field find nothing. Thus the output
  of those rules can have no answer, where Liquid calculates with `nil`. Thus a script
  that depends on a false *comparison* with a missing row can give a different result
  in the program. The ledger marks each lookup *approximated*. It also gives a list of
  each variable that a script reads but no script assigns. Such a variable is a fault
  in the source, and the program copies the fault.
- **Numbers are the floating point of the source.** The program calculates amounts as
  the Liquid scripts calculate them. Computers use approximate fractions for decimal
  numbers (floating point). The program does not round numbers itself. Thus an
  expectation can show `0.8500000000000001` or `686.0`. The quote desk shows 2
  decimals. Queries and tests show the exact value. The `round` and `round: 2` of
  Liquid round half away from zero, and the program does the same. `round: 2` gives a
  floating-point number (`70.0`), as the reference Liquid does.
- **Integer division.** The `divided_by` of Liquid divides one whole number by a
  different whole number, and removes the remainder. Where the two numbers are
  certainly whole, the program writes `//` (`N = M // 100`). This is correct only for
  whole-number inputs. Sometimes the kinds of number are not known until the program
  runs. There, the translator writes `/`. The ledger marks the two conditions
  *approximated*.
- **Text and numbers.** A list value that looks like a number becomes a number. The
  program reads a table key such as `0005` as 5. A value that starts with a
  comparison sign becomes words: `<50%` becomes `under 50%`. This change occurs in the
  rules, in the scenarios and in the copied table. The reason is that Logical English
  reads a table cell that starts with `<` as a condition. When you write a quote
  manually, write numbers without quotation marks:
  `the atfault claims past five years of policy 1 is "2"` does not agree with a rule
  that compares with the number 2. The verifier gives a warning about a value that no
  rule can read in its position.
- **Names come from the words of the source.** The names of the templates come from
  the names of the fields and variables of Socotra ("the pet breed dog of a pet",
  "the accident premium at step two"). The type of a variable comes from the values
  that its branches give it. The type is *a number*, or *a value* when one of those
  values is a text. You possibly must change the words.
- **The first exposure is any exposure.** The program reads
  `data.policy.exposures[0]` as "an exposure of the policy". That reading is correct
  when the policy has one exposure of that kind. It is not correct when the policy has
  more than one.
- **Loops ignore sequence.** The program reads a decision inside a loop as "written
  when some item satisfies the condition". The program does not record which item
  Liquid examined last.
- **Gross premium and taxes are sums.** The platform of Socotra also counts
  endorsements and term changes. One quote has none of them. Thus the sum is exact
  for a quote, but not in other conditions.
- **Rating, not claims.** A product configuration contains rating and underwriting.
  It contains no claims logic to translate (coverage for a loss, applied deductibles,
  limits, reserves).

## See also

- In this documentation:
  - [Other systems: importing and exporting](index.md#opening-another-systems-file):
    what all importers do, [what could not be translated](index.md#what-could-not-be-translated),
    [Show the Original](index.md#show-the-original) and
    [the migration twins](index.md#the-migration-twins-among-the-examples);
  - [the `otherwise` cascades](../reference/language.md#172-otherwise-cascades),
    [decision tables](../reference/language.md#173-decision-tables),
    [aggregates](../reference/language.md#5-aggregates),
    [rule labels and provenance](../reference/language.md#155-rule-labels-and-provenance),
    [expectations](../reference/language.md#12-testing-and-expectations) and
    [lib/temporal](../reference/language.md#142-shipped-libraries-lib) in the
    language reference;
  - [views](../reference/language.md#1710-views-how-a-screen-shows-a-program)
    and the [views tutorial](../tutorials/views.md), for the quote desk;
  - [the Scenario Editor](../guide/editor.md#the-scenario-editor), to write a quote;
  - [the Contract Assistant](../guide/assistants.md#the-contract-assistant). Its
    residue mode translates residue blocks.
- The documentation of Socotra:
  - [Socotra](https://www.socotra.com)
  - [Socotra documentation](https://docs.socotra.com)
  - [socotra/product-library](https://github.com/socotra/product-library): the
    public product configurations that we made the twins from
  - [socotra/public](https://github.com/socotra/public): code samples, example
    configurations and test utilities
  - [Liquid](https://shopify.github.io/liquid/): the template language of the
    scripts

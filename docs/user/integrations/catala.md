# Catala and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-06)*

**Catala** is a programming language for laws, made at Inria, the French
national research institute for computer science. A Catala program is
*literate*: the text of the law and the code that says what it means sit
side by side in one file, each piece of code under the article it
translates. Catala has two dialects with the same meaning, English
(`.catala_en`) and French (`.catala_fr`). The French social security
agency for family benefits, the CNAF (Caisse nationale des allocations
familiales), decided in June 2026 to compute its housing allowance in
Catala.

Logical English (LE) reads a Catala program, and writes one.
**File ▸ Open…** (or **File ▸ Import from Another System…**) takes a
`.catala_en` or `.catala_fr` file, or a zip file of a program's files with
its tests. The result is a Logical English program, written in French
(*Français Logique*) when the Catala is French. **File ▸ Export to Another
System… ▸ Catala** writes a Logical English program as Catala. The
translator is part of the Logical English Translators, so only installations
that have them offer it.

## Contents

- [How Catala is organised](#how-catala-is-organised)
- [What happens when a program is opened](#what-happens-when-a-program-is-opened)
- [How Catala becomes Logical English](#how-catala-becomes-logical-english)
- [Exceptions](#exceptions)
- [What is left for a person to translate](#what-is-left-for-a-person-to-translate)
- [Writing a program as Catala](#writing-a-program-as-catala)
- [The examples](#the-examples)
- [See also](#see-also)

## How Catala is organised

A Catala program is made of *scopes*. A scope is one calculation the law
describes, such as the monthly minimum wage. It declares its *inputs* (the
facts it is given, such as the date and the region), and the *outputs* it
computes (the wage). Its *definitions* say how each output is computed, each
under the article of the law it comes from. A scope may use another scope:
the family benefits scope uses the minimum wage scope, for example. A *test
scope* gives a scope its inputs and states, in *assertions*, the outputs
the law should produce.

## What happens when a program is opened

The translator reads the Catala files as text, after Catala's own grammar;
it does not run Catala. Each output of a scope becomes a Logical English
rule; each input a fact that each *scenario* (the facts of one case, with
the answers its test expects) states; each test scope a scenario. A scope
that the program uses is copied into the program, its names led by the
name the program gives it. The originals are kept in the program's
`sources/` folder: **File ▸ Show the Original** shows them. Each rule cites
the headings of the articles it translates, and the citation opens the
Catala file under `sources/`.

## How Catala becomes Logical English

| In Catala | In Logical English |
|---|---|
| a scope's output: `output qualified_employee_discount content money` | a template: `the qualified employee discount is *an amount*` |
| an input: `input customer_price content money` | a fact the scenario states: `the customer price is 1500.` |
| a condition: `rule is_property under condition … consequence fulfilled` | a sentence that holds: `the case is property` |
| `definition x under condition c consequence equals e` | a rule whose conditions are c |
| several definitions of one output, each with its condition | one rule, its parts joined by `otherwise` |
| `if … then … else …`, `match … with pattern` | `otherwise` |
| an enumeration, such as the regions of France | a code: `the résidence is "Mayotte"` |
| `résidence = Métropole ou résidence = Guadeloupe ou …` | `le code est dans ["Métropole", "Guadeloupe", …]` |
| money, decimals, percentages, dates | numbers and dates; an amount times a rate rounded to the cent, as Catala does |
| a scope another scope uses | its rules, copied under the user's name for it |

A program in French is written in Français Logique: `le brut horaire est
*un montant*`, `la condition … est remplie`. Français Logique writes
French's short forms (*l'*, *d'*, *au*, *du*), and reads them either way.

## Exceptions

Catala lets a definition be an *exception* to another: when the exception's
condition holds, its value replaces the other's. The translator keeps the
order Catala gives them: in the Logical English rule, the exception comes
first, and the definition it is an exception to comes after `otherwise`. So
the first part that applies gives the answer, as in Catala.

There is one difference. When two definitions at the same level both apply,
Catala stops with an error (a *conflict*): the law, as written, gives two
answers. Logical English takes the first. So each rule where a conflict can
happen is marked in the program's ledger, the record of what was translated
from what, as an approximation. The translator checks its reading of every
exception against Catala's own. One conflict was found in Catala's own
minimum wage example: for Mayotte, the November 2024 decree's amount is
dated from 1 January 2024, so from January to October 2024 two amounts
apply. Catala stops there, and that case is left out of the twin, with
Catala's reason.

A *context* variable is a value the scope works out unless its caller or
a test gives one. In the program it becomes a rule with two parts: first
the value the scenario gives (*the gain cap given is …*), otherwise the
scope's own definition. One difference remains: the assertions a Catala
program states about its own values are not yet checked by the program.

## What is left for a person to translate

Most of Catala translates. A definition that takes a child (or any other
structure) as its parameter becomes a rule about a child: each child is an
individual of the program, and the child's details are facts about it. A
list of structures, such as the periods a person owned a house, becomes one
individual for each element, with a fact that says which list it is in; a
sum over the list becomes a sum over those individuals. A duration becomes a
number of months added to a date, or a number of days between two dates.

A value defined in steps (Catala's *states*) becomes one rule per step,
each step reading the one before it; the last step has the value's own
name. A structure, such as a person's details, and an enumeration whose
cases carry a value, such as the kind of tax return with the people it
names, become one fact for each detail: *the return type is "JointReturn"*,
and the details of that case under its name. A value that is a structure
(*person 1* chosen from the kind of return) becomes one rule for each of its
details. A function of an amount, such as the treatment of the final
housing allowance, becomes one rule for each amount it is applied to,
named after it: *le traitement aide finale de aide finale formule
initiale*.

Some of Catala has no translation yet: combining a list step by step (a
*fold*), and lists built inside a definition. Such a definition is kept in the program as a *residue* block:
its Catala text, the reason it was not translated, and the sentence a
translation must conclude. The scenarios that depend on it are left out of
the program and counted in the program's ledger, the record of what was
translated from what.

## Writing a program as Catala

**File ▸ Export to Another System… ▸ Catala** writes the program as one
Catala file in the English dialect: one scope, `Program`, with the
program's inputs and the values and conditions its rules conclude. A value
given only under conditions, with no last `otherwise`, has no value in the
other cases, written with Catala's `impossible`. A code (a value in words)
becomes an enumeration of the words the program uses. Each scenario
becomes a test scope that Catala's `clerk test` runs. Numbers are written as
decimals: Catala distinguishes money, decimals and whole numbers, and Logical
English does not. A program that Catala cannot express is refused, with the
reasons: sums or counts over the things related to a case, values with
dates, rounding up or down. A rule about a child is written as a Catala
definition that depends on a child: the child's details become a
structure, and each scenario asks the definition about the child it
describes. A number of months added to a date becomes a Catala duration.

## The examples

The examples in `examples/migration/catala` come from Catala's own examples
(`catala-examples`, Apache-2.0 licence):

| Program | Dialect | Checked |
|---|---|---|
| United States tax code, section 132 (qualified employee discounts) | English | its 3 tests: 8 of 8 answers |
| The French minimum wage (SMIC), 2019 to 2024 | French | 29 cases made from its dates and regions, checked against Catala's interpreter |
| The monthly base of French family allowances, 2019 to 2024 | French | 6 cases, the same way |
| United States tax code, section 121 (sale of a principal residence) | English | whole: its 6 tests, for one person and for two, pass |
| French family benefits, eligibility | French | whole: its test, about four children, becomes four scenarios, and all pass |
| French housing allowance (*aides au logement*, the CNAF's programme): the rental calculation (`apl_locatif`) | French | whole: its 9 tests, 49 answers, all pass |

Written back to Catala, section 132, the minimum wage, the monthly base and
the family benefits pass every test on Catala's interpreter. Section 121 is
not written back yet: its sums over lists of periods have no Catala form in
the exporter. The housing allowance is not written back either: two of its
rules are cascades inside cascades that the exporter does not read yet. A
program that still holds residue blocks is not written back.

## See also

- [Other systems: importing and exporting](index.md)
- [Français Logique](../reference/language.md): Logical English in French
- Catala: https://catala-lang.org

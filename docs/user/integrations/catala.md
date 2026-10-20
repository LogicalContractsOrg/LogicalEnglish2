# Catala and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-06)*

**Catala** is a programming language for laws. Inria made Catala. Inria is the French
national research institute for computer science. A Catala program is *literate*.
This means that the text of the law and the code that tells its meaning are side by
side in one file. Each piece of code is below the article that it translates.

Catala has two dialects with the same meaning: English (`.catala_en`) and French
(`.catala_fr`). The CNAF (Caisse nationale des allocations familiales) is the French
social security agency for family benefits. In June 2026, the CNAF decided to
calculate its housing allowance in Catala.

Logical English (LE) can read a Catala program, and LE can also write one. **File ▸
Open…** (or **File ▸ Import from Another System…**) reads a `.catala_en` or
`.catala_fr` file. It also reads a zip file of the files of a program with its tests.
A zip file is one compressed file that contains many files. The result is a Logical
English program. When the Catala is French, the program is written in French
(*Français Logique*).

**File ▸ Export to Another System… ▸ Catala** writes a Logical English program as
Catala. The translator is part of the Logical English Translators. Thus only
installations that have the Logical English Translators show this menu item.

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

A Catala program contains *scopes*. A scope is one calculation that the law
describes, for example the monthly minimum wage. A scope declares its *inputs* and
its *outputs*. The inputs are the facts that the scope receives, for example the
date and the region. The outputs are the values that the scope calculates, for
example the wage. The *definitions* of the scope tell how the scope calculates each
output. Each definition is below the article of the law that it comes from.

A scope can use a different scope. For example, the family benefits scope uses the
minimum wage scope. A *test scope* gives the inputs to a scope. The test scope also
states, in *assertions*, the outputs that the law must give.

## What happens when a program is opened

The translator reads the Catala files as text, with the grammar of Catala. The
translator does not run Catala.

- Each output of a scope becomes a Logical English rule.
- Each input becomes a fact that each *scenario* states. A scenario is the facts of
  one case, together with the answers that its test expects.
- Each test scope becomes a scenario.

The translator copies into the program each scope that the program uses. The names
of a copied scope start with the name that the program gives to the scope.

The program keeps the originals in its `sources/` folder. **File ▸ Show the
Original** shows the originals. Each rule cites the headings of the articles that it
translates. The citation opens the Catala file in `sources/`.

## How Catala becomes Logical English

| In Catala | In Logical English |
|---|---|
| an output of a scope: `output qualified_employee_discount content money` | a template: `the qualified employee discount is *an amount*` |
| an input: `input customer_price content money` | a fact that the scenario states: `the customer price is 1500.` |
| a condition: `rule is_property under condition … consequence fulfilled` | a sentence that is true: `the case is property` |
| `definition x under condition c consequence equals e` | a rule with the conditions c |
| some definitions of one output, each with its condition | one rule, with its parts joined by `otherwise` |
| `if … then … else …`, `match … with pattern` | `otherwise` |
| an enumeration, for example the regions of France | a code: `the résidence is "Mayotte"` |
| `résidence = Métropole ou résidence = Guadeloupe ou …` | `le code est dans ["Métropole", "Guadeloupe", …]` |
| money, decimals, percentages, dates | numbers and dates. An amount multiplied by a rate is rounded to the cent, as in Catala |
| a scope that a different scope uses | the rules of the scope, copied below the name that the user gives to it |

The translator writes a program in French in Français Logique: `le brut horaire est
*un montant*`, `la condition … est remplie`. Français Logique writes the short forms
of French (*l'*, *d'*, *au*, *du*). Français Logique reads both the short forms and
the long forms.

## Exceptions

In Catala, a definition can be an *exception* to a different definition. When the
condition of the exception is true, the value of the exception replaces the other
value. The translator keeps the order that Catala gives. In the Logical English rule,
the exception comes first. The definition that has the exception comes after
`otherwise`. Thus the first part that applies gives the answer, as in Catala.

There is one difference. Two definitions at the same level can both apply. Then
Catala stops with an error, called a *conflict*: the law, as written, gives two
answers. Logical English uses the first answer. Thus the ledger of the program marks
as an approximation each rule where a conflict can occur. The ledger is the record of
what was translated from what.

The translator compares its reading of each exception with the reading of Catala. The
comparison found one conflict in the minimum wage example of Catala itself. For
Mayotte, the amount of the decree of November 2024 starts on 1 January 2024. Thus
from January to October 2024, two amounts apply. Catala stops in that case. The twin
does not contain that case, and it gives the reason of Catala. (A twin is the
translation of a program from a different system.)

A *context* variable is a value that the scope calculates when its caller or a test
does not give one. In the program, a context variable becomes a rule with two parts.
The first part is the value that the scenario gives (*the gain cap given is …*). The
second part, after `otherwise`, is the definition of the scope. One difference stays:
the program does not yet check the assertions that a Catala program states about its
own values.

## What is left for a person to translate

The translator can translate most of Catala:

- A definition can take a child (or any other structure) as its parameter. Such a
  definition becomes a rule about a child. Each child is an individual of the
  program, and the details of the child are facts about the child.
- A list of structures becomes one individual for each element. An example is the
  periods when a person owned a house. A fact tells the list that contains each
  individual. A sum over the list becomes a sum over those individuals.
- A duration becomes a number of months added to a date, or a number of days between
  two dates.
- A value that Catala defines in steps (the *states* of Catala) becomes one rule for
  each step. Each step reads the step before it. The last step has the name of the
  value.
- A structure becomes one fact for each detail. An example is the details of a
  person. An enumeration whose cases carry a value also becomes one fact for each
  detail. An example is the kind of tax return with the persons that it names: *the
  return type is "JointReturn"*, and the details of that case below its name.
- A value that is a structure (*person 1* selected from the kind of return) becomes
  one rule for each of its details.
- A function of an amount becomes one rule for each amount that the function applies
  to. An example is the treatment of the final housing allowance. Each rule has the
  name of its amount: *le traitement aide finale de aide finale formule initiale*.

Some parts of Catala have no translation yet: the combination of a list step by step
(a *fold*), and lists that a definition makes inside itself. The program keeps such
a definition as a *residue* block. The residue block contains the Catala text, the
reason that the translator did not translate it, and the sentence that a translation
must conclude. The program does not contain the scenarios that depend on a residue
block. The ledger of the program counts these scenarios. The ledger is the record of
what was translated from what.

## Writing a program as Catala

**File ▸ Export to Another System… ▸ Catala** writes the program as one Catala file in
the English dialect. The file has one scope, `Program`. The scope contains the inputs
of the program, and the values and conditions that its rules conclude.

- A value can be given only under conditions, with no last `otherwise`. Such a value
  has no value in the other cases. The export writes these cases with `impossible` of
  Catala.
- A code (a value in words) becomes an enumeration of the words that the program
  uses.
- Each scenario becomes a test scope that `clerk test` of Catala runs.
- Numbers are written as decimals. Catala makes a difference between money, decimals
  and whole numbers, but Logical English does not.
- A rule about a child becomes a Catala definition that depends on a child. The
  details of the child become a structure. Each scenario asks the definition about the
  child that the scenario describes.
- A number of months added to a date becomes a Catala duration.

The export refuses a program that Catala cannot express, and it gives the reasons.
Examples are sums or counts over the things related to a case, values with dates, and
rounding up or down.

## The examples

The examples in `examples/migration/catala` come from the examples of Catala
(`catala-examples`, Apache-2.0 licence):

| Program | Dialect | Checked |
|---|---|---|
| United States tax code, section 132 (qualified employee discounts) | English | its 3 tests: 8 of 8 answers |
| The French minimum wage (SMIC), 2019 to 2024 | French | 29 cases made from its dates and regions, checked against the interpreter of Catala |
| The monthly base of French family allowances, 2019 to 2024 | French | 6 cases, checked in the same way |
| United States tax code, section 121 (sale of a principal residence) | English | in full: its 6 tests, for one person and for two persons, pass |
| French family benefits, eligibility | French | in full: its test, about four children, becomes four scenarios, and all pass |
| French housing allowance (*aides au logement*, the programme of the CNAF): the rental calculation (`apl_locatif`) | French | in full: its 9 tests, 49 answers, all pass |

The export writes back to Catala section 132, the minimum wage, the monthly base and
the family benefits. These programs pass each test on the interpreter of Catala.
The export does not write back section 121 yet. Its sums over lists of periods have
no Catala form in the exporter. The export does not write back the housing allowance
either. Two of its rules are cascades inside cascades, and the exporter cannot read
these cascades yet. The export does not write back a program that contains residue
blocks.

## See also

- [Other systems: importing and exporting](index.md)
- [Français Logique](../reference/language.md): Logical English in French
- Catala: https://catala-lang.org

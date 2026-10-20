# OpenFisca, PolicyEngine and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-05)*

**OpenFisca** is free software. Governments and researchers use OpenFisca to write
the taxes and benefits of a country as programs. They also use OpenFisca to
calculate the taxes and benefits for many households at the same time. The tax and
benefit system of France is written in OpenFisca. Smaller models are also written in
OpenFisca, for example the *country template* of OpenFisca, which is a teaching
example.

**PolicyEngine** is a version of OpenFisca. PolicyEngine has its own models of the
taxes and benefits of the United States and the United Kingdom.

A model is a package of Python files. Python is a programming language. Each
*variable* in a model is an amount, a yes-or-no question or a code, and each variable
has a formula. *Parameters* are rates, thresholds and tables. The model keeps the
parameters in separate files, together with the dates on which their values change.
Test files tell what the formulas must give for sample households.

Logical English (LE) can read such a model, and LE can also write one. **File ▸
Open…** (or **File ▸ Import from Another System…**) reads a Python file of
variables, or a zip file of the files of a model. A zip file is one compressed file
that contains many files. The result is a Logical English program:

- Each variable becomes a rule.
- Each parameter becomes a value for each period.
- Each test that the program can use becomes a *scenario*. A scenario is a set of
  facts about one household, together with the answers that the test expects.

**File ▸ Export to Another System… ▸ OpenFisca** writes a Logical English program as
one Python file that OpenFisca can run. The translator is part of the Logical English
Translators. Thus only installations that have the Logical English Translators show
this menu item.

The models have the AGPL licence. Thus the hosted service keeps the translations of
the models of PolicyEngine and OpenFisca. These translations are called *twins*. The
examples of each installation do not contain the twins.

## Contents

- [What happens when a model is opened](#what-happens-when-a-model-is-opened)
- [How the Python becomes Logical English](#how-the-python-becomes-logical-english)
- [What is left for a person to translate](#what-is-left-for-a-person-to-translate)
- [Writing a program as an OpenFisca model](#writing-a-program-as-an-openfisca-model)
- [See also](#see-also)

## What happens when a model is opened

When you open a model, the translator reads the files of the model as text. The
translator does not run the Python.

(The twins of the PolicyEngine models were made in a different way. They were made
from the model that was installed with its engine. Thus each parameter has the values
of the engine. Also, each test was run on the engine to check the test.)

The translator starts from the variables that nothing else in the upload reads.
These variables are the results of the model. Then the translator follows each
variable that the formulas of these variables read. Some variables are read by the
upload but are not defined in it. Each such variable becomes a fact that each
scenario must state.

The test files become scenarios. The expected values of the tests become the answers
that the scenarios expect. The notes tell how many variables the translator
translated, and how many tests pass.

The program keeps the originals in its `sources/` folder. **File ▸ Show the
Original…** shows the originals. Each rule cites the label of the variable and its
reference. The reference is usually a link to the statute.

## How the Python becomes Logical English

| In the model | In Logical English |
|---|---|
| a variable of a household, with a formula | a rule that concludes `the snap net income of *an spm unit* is *an amount*` |
| a yes-or-no variable | a rule that concludes a sentence: `*an spm unit* is snap eligible` |
| a parameter, with the dates on which its value changes | one rule for each period of its value. Each scenario states `the calculation date`, and this date selects the rule |
| a table of parameters (by state, by household size) | one fact for each row, with the dates on which the fact is true |
| `where`, `select`, `max_`, `min_`, rounding | `otherwise`, the maximum and the minimum of two values, the rounding of LE |
| the sum of a group over its members | `the sum of each … such that the person is a member of the spm unit` |
| a tax scale with brackets | the brackets written in full. Each rate is multiplied by the part of the income in its bracket |
| the formulas of a variable from different dates | one rule for each range of dates |
| a question that a person asks of the group of the person (`person.benunit.any(...)`) | a sentence about the group, `*a benunit* has members who count for …`, read through `the person is a member of a benunit` |
| the age of a person from a birth date | the number of whole months from the birth date to the calculation date, divided by 12 |
| a list that the model keeps as a parameter (`np.isin(status, p.eligible_statuses)`) | `the code is in [...]`, with one list for each period that the parameter defines |
| a loop over a list that the model writes, or a helper function of the model | written in full: one copy of the body of the loop for each item, and the body of the helper function in the place of its call |

**Months and years.** A model defines each variable for a month or for a year. When a
test asks for a year of a monthly variable, PolicyEngine adds the values of the twelve
months. The translator uses the engine of the model to check that the twelve months
are equal. When the months are equal, the scenario is one month, at one twelfth of
the yearly values. Also, a monthly formula can read an income that is defined for a
year. Then PolicyEngine divides the income by twelve, and the rule says `/ 12`. A
size or an age keeps its value.

**The years that a twin covers.** A twin keeps the parameter values of the years that
its tests ask about. An *integrity constraint* tells this. An integrity constraint is
a sentence `it must not be true that …`, and a scenario must not break it. The twin
refuses a scenario with a date before the first of those years or after the last of
those years. The twin gives the reason. It does not give an answer from values that
it does not have.

**Inputs whose default is "yes".** In a model, some facts are true when a case does
not tell otherwise. For example, a household takes up the benefit, and a person files
a tax return. In Logical English, a sentence that a scenario does not state is false.
Thus the twin uses the opposite sentence. For example, *a spm unit declines snap if
eligible* is the sentence of the twin for `takes_up_snap_if_eligible` of the model. A
scenario that does not state this sentence has the same meaning as the default of the
model.

**Roles in a group.** The adults and the children of a household are the roles that
the tests of the model give. Each role becomes a fact of the scenario, for example
*person 1 is adult in household*. The count of the adults in the model becomes a
count of the members for whom that fact is true.

## What is left for a person to translate

Python can say some things that have no fixed translation:

- the values that a variable had in a different period (for example, the income of
  the last year),
- tables of texts that the model keeps as parameters (for example, a utility
  allowance by state and by expense),
- a value that the simulation of the model selects at random,
- an order that depends on the position of a family in its household.

The translator translates these items (refer to the table above):

- loops over a list that the model writes or keeps as a parameter,
- dictionaries that the model writes,
- the helper functions of the model,
- functions that a formula defines inside itself.

The program keeps a formula that has no translation as a *residue* block. The residue
block contains the Python, the reason that the translator did not translate it, and
the sentence that a translation must conclude. The program does not contain the
scenarios that depend on a residue block. The ledger of the program counts these
scenarios. The ledger is the record of what was translated from what. The LE Contract
Assistant can translate a residue block when you ask it.

## Writing a program as an OpenFisca model

**File ▸ Export to Another System… ▸ OpenFisca** writes the program as one Python
file. The file contains these items:

- the kinds of things that the program is about (each person, and each group, for
  example a household),
- a variable for each template,
- the parameters,
- a function `system()` that puts these items together.

The scenarios follow, as tests of OpenFisca.

The export refuses a program that OpenFisca cannot express, and it gives the reasons.
An example is a value that the program concludes only under conditions, with no
`otherwise`.

A rule about a person can read a value of the group of the person (*the person is a
member of a tax unit and the tax unit …*). A rule about a group can add, count, or
find the largest or the smallest value over its members. The place of a person among
the members of its group (for example, the rank of a child among the children)
becomes the number of members that meet the same condition and come before that
person.

## See also

- [Other systems: importing and exporting](index.md)
- [OpenFisca-France et Français Logique](openfisca-france.md): the model of France as
  twins in Français Logique, and its housing allowance compared with the Catala
  programme of the CNAF (in French)
- [Axiom RuleSpec and Logical English](rulespec.md): the same benefit rules, written
  by the Axiom Foundation
- OpenFisca: https://openfisca.org · PolicyEngine: https://policyengine.org

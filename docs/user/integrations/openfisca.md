# OpenFisca, PolicyEngine and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-05)*

**OpenFisca** is free software that governments and researchers use to
write a country's taxes and benefits as programs, and to compute them for
many households at once. France's tax and benefit system is written in it,
and so are smaller models such as OpenFisca's own *country template*, a
teaching example. **PolicyEngine** is a version of OpenFisca with its own
models of the taxes and benefits of the United States and the United
Kingdom. A model is a package of Python files. Each *variable* (an amount, a
yes-or-no question, a code) has a formula; *parameters* (rates, thresholds,
tables) are kept in files of their own with the dates they change; and test
files say what the formulas should give for sample households.

Logical English (LE) reads such a model, and writes one. **File ▸ Open…**
(or **File ▸ Import from Another System…**) takes a Python file of
variables, or a zip file of a model's files. The result is a Logical
English program: each variable a rule, each parameter a value for each period,
and each test the program can take a *scenario* (a set of facts about one
household, with the answers the test expects). **File ▸ Export to Another System… ▸ OpenFisca**
writes a Logical English program as one Python file that OpenFisca runs.
The translator is part of the Logical English Translators, so only
installations that have them offer it. The models are published under the
AGPL licence, so the translations of PolicyEngine's and OpenFisca's own
models, called *twins*, are kept on the hosted service, not in the
examples of every installation.

## Contents

- [What happens when a model is opened](#what-happens-when-a-model-is-opened)
- [How the Python becomes Logical English](#how-the-python-becomes-logical-english)
- [What is left for a person to translate](#what-is-left-for-a-person-to-translate)
- [Writing a program as an OpenFisca model](#writing-a-program-as-an-openfisca-model)
- [See also](#see-also)

## What happens when a model is opened

When a model is opened, the translator reads its files as text; it does
not run the Python. (The twins of PolicyEngine's models were made
differently: from the model installed with its engine, so that every
parameter has the engine's own values, and each test was run on the
engine to check it.) The translator starts from the variables nothing else in the upload reads (the results
of the model) and follows every variable their formulas read. A variable
the upload reads but does not define becomes a fact that each scenario
states. The test files become scenarios, and their expected values the
answers the scenarios expect. The notes say how many variables were
translated, and how many tests pass.

The originals are kept in the program's `sources/` folder: **File ▸ Show
the Original…** shows them. Each rule cites the variable's label and its
reference, usually a link to the statute.

## How the Python becomes Logical English

| In the model | In Logical English |
|---|---|
| a variable of a household, with a formula | a rule concluding `the snap net income of *an spm unit* is *an amount*` |
| a yes-or-no variable | a rule concluding a sentence: `*an spm unit* is snap eligible` |
| a parameter, with the dates its value changes | one rule for each period of its value; `the calculation date`, which each scenario states, picks the rule |
| a table of parameters (by state, by household size) | one fact per row, with the dates it holds |
| `where`, `select`, `max_`, `min_`, rounding | `otherwise`, the maximum and minimum of two values, LE's rounding |
| a group's sum over its members | `the sum of each … such that the person is a member of the spm unit` |
| a tax scale with brackets | the brackets written out, each rate times the part of the income in its bracket |
| a variable's formulas from different dates | one rule per date range |
| a question a person asks of the group the person belongs to (`person.benunit.any(...)`) | a sentence about the group, `*a benunit* has members who count for …`, read through `the person is a member of a benunit` |
| a person's age from a birth date | the whole months from the birth date to the calculation date, divided by 12 |
| a list kept as a parameter (`np.isin(status, p.eligible_statuses)`) | `the code is in [...]`, one list for each period the parameter defines |
| a loop over a list written in the model, or a helper function of the model | written out: one copy of the loop's body per item; the helper's body in place of its call |

**Months and years.** A model defines each variable for a month or for a
year. When a test asks for a year of a monthly variable, PolicyEngine adds
up the twelve months. The translator checks with the model's own engine
that the twelve months are equal; when they are, the scenario is one month
at a twelfth of the yearly figures. In the same way, when a monthly formula
reads an income defined for a year, PolicyEngine divides it by twelve, and
the rule says `/ 12`; a size or an age keeps its value.

**The years a twin covers.** A twin keeps the parameter values of the years
its tests ask about. For an earlier or a later year, a rule that needs a
parameter finds no value, and its answer is not to be trusted.

## What is left for a person to translate

Python can say things that have no fixed translation: lists built by
computation, values a variable had in another period (last year's income),
the roles people have in a household, texts kept as parameters (a state's
name). Loops over a list written in the model and the model's own helper
functions are translated (see the table above); a loop over a list the
program computes is not.
Such a formula is kept in the program as a *residue* block: its Python,
the reason it was not translated, and the sentence a translation must
conclude. The scenarios that depend on it are left out of the program and
counted in the program's ledger, the record of what was translated from
what. The LE Contract Assistant can translate a residue block on request.

## Writing a program as an OpenFisca model

**File ▸ Export to Another System… ▸ OpenFisca** writes the program as one
Python file: the kinds of things it speaks of (each person, and each group
such as a household), a variable for each template, the parameters, and a
function `system()` that assembles them; the scenarios follow as
OpenFisca's tests. A program that OpenFisca cannot express is refused,
with the reasons: a value concluded only under conditions, with no
`otherwise`; a count over the members of a person's own group (a child's
rank among the children). A rule about a person may read a value of the
person's group (*the person is a member of a tax unit and the tax unit …*),
and a rule about a group may add up, count, or take the largest or smallest
value over its members.

## See also

- [Other systems: importing and exporting](index.md)
- [Axiom RuleSpec and Logical English](rulespec.md): the same benefit rules
  written by the Axiom Foundation
- OpenFisca: https://openfisca.org · PolicyEngine: https://policyengine.org

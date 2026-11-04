# Logical English Load-Time Warnings

*Kind: guide · Audience: users · Status: current (2026-10-04)*

The system shows these warnings when it loads a program. The warnings apply only to
programs that the system can already read. In such programs, all sentences are
written correctly.

## Missing template for '...'

A phrase of more than one word is in the conditions of a rule. But the program
declares no template for that phrase. A template is a sentence pattern that tells LE
the words of a sentence.  
**Fix:** Add a template for the phrase to the `the templates are:` section.

## Undefined predicate '...'

A rule uses a predicate in its conditions. A predicate is a kind of statement. But no
part of the program tells when that statement is true. No rule concludes the
statement, and no scenario gives the statement as a fact.  
**Fix:** Add a rule that defines the predicate. Or, add fact sentences for the
predicate in the applicable scenarios.

## This predicate is not tested by any query: '...'

No `query` in the program can reach this predicate. The rules define this predicate;
the scenarios do not give it. The warning identifies the predicate by its template
(`*a claim* is covered under *a section*`). The warning also points to the first rule
that concludes the predicate.  
**Fix:** Add a query that tests the predicate. Then add expected answers with
`expects answers` in a scenario.

## This template is never used: '...'

The program declares a template, but the template is not in any other part of the
program. It is not in the conclusion of a rule or in the conditions of a rule. It is
not in a fact, in a scenario or in a query. Words that nothing uses take the
attention of the reader. Also, no use of the words ever tests them. Programs that a
computer writes frequently make such classifications (`*a cost* is a cost; undefined.`).
No rule uses these classifications.  
**Fix:** Delete the template, or use it.

## Test failed for query '...' in scenario '...'

The query gives answers that are different from the expected answers. The scenario
gives the expected answers (`<query> expects answers [...] and unknowns [...]`).
Some older examples have an old `.le.tests` file adjacent to the program. In that
case, the expected answers can also come from that file.  
**Fix:** Examine the logic of your rules, or the facts in the scenario.

## Template '...' has no word of its own besides "is" (an error)

All the words of the template are between asterisks, but not the word *is*. An
example is `*the amount of other insurance* is *an amount*`. In the system, such a
template replaces the template that the system uses for arithmetic. Thus the system
reads each "... is ..." sentence of the program as a use of this template. This
includes a comparison of dates, for example `D is after or equal to S`. Each answer
that needs such a sentence stops with an error.  
**Fix:** Write the fixed words outside the asterisks:
`the amount of other insurance under *a policy* is *an amount*`.

## An aggregate speaks of something no condition before it names

An aggregate is a calculation on a set of values, for example a maximum. A conclusion
of a rule names a thing (`the capped amount for a claim component is ...`). An
aggregate in the rule also refers to that thing
(`the max of each V such that the payable benefit for the claim component is V`).
But no condition before the aggregate tells which thing it is. Thus the aggregate
uses all of these things together. The rule then gives one answer, but not for one
specific thing.  
**Fix:** Name the thing in a condition before the aggregate, for example
`a claim has the claim component`.

## The condition '...' shares nothing with the rest of its rule

A rule has two or more conditions. One condition contains only variables, or
variables and a name, and these variables are in no other part of the rule. A
variable is a part of a rule that different values can fill. An example is the
last condition of this rule:

```
a proposal has an established regulatory basis for a provider
    if the proposal involves the provider
    and the provider has a licence covering a financial service
    and an Australian financial services licence is current on a date.
```

This condition does not ask about the licence of the provider. It asks whether a
licence is current on a date, for any licence and any date. Thus the rule is true
when some other licence is current. Also, the system must examine each such fact for
each answer of the rule, and the answers become slow. A condition with a name and a
new variable, `and a case supplies agreement D`, is the same: it is true when any
case supplies the agreement. A condition whose first part is a name, `the start
date is a date`, asks about that named thing, and is not reported.  
**Fix:** Connect the condition to the rule. Use *the* for a thing that the rule
already names: `and the licence of the provider is current on the date of the
proposal`. If the rule really needs only that some such fact exists, declare a
template without variables for it (`there is a current licence.`). Then write a rule
that concludes it from the condition.

## The template '...' has no words outside its argument places (an error)

All the words of the template are between asterisks. An example is
`*an exemption expressly covers a trustee service*; undefined.` A template of this
kind agrees with each sentence of the program. Thus the system read conditions such
as `the date is before 2027-03-31` and `the text of the policy is at "..."` as facts
of this template. The system now ignores the template.  
**Fix:** Write the fixed words outside the asterisks:
`*an exemption* expressly covers a trustee service; undefined.`

## The template '...' puts an apostrophe after an argument place

The template has a possessive after an argument place, for example
`*a provider*'s licence covers *a proposal*`. A sentence of the program writes the
possessive as one word: `the provider's licence covers the proposal`. Thus no sentence
agrees with this template, and the system reports each sentence as a sentence without
a template.  
**Fix:** Write the possessive with *of*, in the template and in the sentences:
`the licence of *a provider* covers *a proposal*`.

## Rule without variables: ...

The conclusion of the rule and the conditions of the rule do not contain a variable.
A variable is a part of a rule that different values can fill. Each part of this rule
names one specific value.  
**Fix:** Move the specific values into a scenario. A rule must use variables.

## Missing rules / Too many facts

- **Missing rules:** The program contains only facts and no rules.  
- **Too many facts:** The facts are more than 5 times the number of rules.  
**Fix:** Add rules that find conclusions from the facts.

---

**Note:** For a "Missing template" warning, the editor gives a **Quick Fix**. A
lightbulb shows the Quick Fix. The Quick Fix proposes a template and writes the
template into the program for you.

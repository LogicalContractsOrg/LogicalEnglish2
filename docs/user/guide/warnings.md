# Logical English Load-Time Warnings

*Kind: guide · Audience: users · Status: current (2026-10-04)*

These warnings apply only to programs the system can already read: programs
whose sentences are correctly written

## Missing template for '...'

A phrase of several words appears among the conditions of a rule, but no template has been declared for that phrase.  
**Fix:** add a template for the phrase to the `the templates are:` section.

## Undefined predicate '...'

A rule uses a predicate — a kind of statement — among its conditions, but nothing ever says when that statement holds: no rule concludes it, and no scenario states it as a fact.  
**Fix:** add a rule defining the predicate, or add fact sentences for it in the relevant scenarios.

## This predicate is not tested by any query: '...'

No `query` in the program can reach this predicate, which is one the rules define rather than one the scenarios state. The warning names the predicate by its template (`*a claim* is covered under *a section*`), and points at the first rule that concludes it.  
**Fix:** add a query that exercises the predicate, and add expected answers using `expects answers` in a scenario.

## This template is never used: '...'

A template is declared, but appears nowhere else: in no rule's conclusion, in no rule's conditions, in no fact, in no scenario, in no query. Wording that nothing uses costs the reader attention, and nothing ever tests it against a use. Programs written automatically often invent classifications of this kind (`*a cost* is a cost; undefined.`) that no rule ever consults.  
**Fix:** delete the template, or use it.

## Test failed for query '...' in scenario '...'

The answers the query actually gives differ from the answers the scenario says to expect (`<query> expects answers [...] and unknowns [...]`), or from those in an old `.le.tests` file beside the program, where an example still has one.  
**Fix:** check the logic of your rules or the facts in the scenario.

## Template '...' has no word of its own besides "is" (an error)

Every word of the template's sentence is inside asterisks except *is*, as in
`*the amount of other insurance* is *an amount*`. Inside the system, such a
template would take the place of the one the system uses for arithmetic, so
that every sentence of the program written "... is ...", including a
comparison of dates such as `D is after or equal to S`, would be read as an
instance of the template, and each answer that needs it stops with an error.
**Fix:** write the fixed words outside the asterisks:
`the amount of other insurance under *a policy* is *an amount*`.

## An aggregate speaks of something no condition before it names

A rule's conclusion names something (`the capped amount for a claim
component is ...`), and an aggregate in the rule (`the max of each V such that
the payable benefit for the claim component is V`) speaks of it, but no
condition before the aggregate says which one. The aggregate then takes all of
them together, and the rule answers once, for none in particular.
**Fix:** name it in a condition before the aggregate, such as `a claim has the
claim component`.

## Rule without variables: ...

Neither the conclusion of the rule nor its conditions contain a single variable: every part of the rule names one particular value.  
**Fix:** move the particular values into a scenario; a rule should use variables.

## Missing rules / Too many facts

- **Missing rules:** the program contains only facts and no rules.  
- **Too many facts:** facts outnumber rules by more than 5:1.  
**Fix:** add rules that derive conclusions from the facts.

---

**Note:** for a "Missing template" warning, the editor offers a **Quick Fix**, marked by a lightbulb. The Quick Fix proposes a template and writes it into the program for you.

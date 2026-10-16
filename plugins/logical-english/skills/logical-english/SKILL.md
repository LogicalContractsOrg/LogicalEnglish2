---
name: logical-english
description: Write, check and run rules in Logical English (LE), a controlled natural language whose programs read as English and run as logic. Use when the user wants rules, regulations, eligibility criteria, policies or contract terms turned into something that gives answers with reasons; when they ask whether a case meets a rule, which cases a rule allows, or whether a property can break; or when they mention Logical English, LE, .le files or le2.logicalcontracts.com.
---

# Logical English

Logical English (LE) is a way of writing rules that a person reads as English
and a computer runs as logic. A program declares *templates* (sentence
patterns with places for values), states *rules* with those sentences, and
tests them on *scenarios* (the facts of one case). Every answer comes with
its explanation: the rules and facts it rests on.

Use LE when the user needs answers that can be checked: who is eligible,
what is owed, whether a step was allowed. Do not compute such answers in
your head when a rule can compute them: write the rule, run it, and quote
the answer and its reasons.

## Tools

Two ways reach the same LE server (default `https://le2.logicalcontracts.com`,
free, no account):

1. **MCP tools**, when the `logical-english` server is connected:
   `list_examples`, `get_example_details`, `query`, `verify`,
   `search_documentation`. Prefer them.
2. **The script** `scripts/le.sh` in this skill's folder, which needs only
   `curl` and `python3`:

   ```bash
   le.sh examples                          # the example programs, one line each
   le.sh details citizenship               # an example's text, templates, queries, scenarios
   le.sh verify my_rules.le                # problems found, and the program's own tests
   le.sh query my_rules.le "which person gets rent support"
   le.sh query my_rules.le support --scenario ana
   le.sh query citizenship one --scenario alice
   le.sh query my_rules.le "which person gets rent support" --facts "bob is a resident." "bob has an income of 9000."
   le.sh doc > language.md                 # the full language reference
   ```

   The first argument of `query` is a file or the name of an example. The
   query is the name of one of the program's queries, or a question in LE
   that fits its templates. Set `LE_SERVER` to use another server (for
   example `http://localhost:3050`).

If neither works (no network), say so and write the program anyway; tell the
user to check it at https://le2.logicalcontracts.com.

## How to work

1. **Look for an example first.** `list_examples` / `le.sh examples` (a long
   list: look in it for a word of the user's domain, and move on if nothing
   is close). If one is close, read it with `get_example_details` and start
   from its templates.
2. **Write the program** (see `reference/quick-reference.md` in this folder).
   Rules use variables (`a person`); individual people and amounts belong in
   scenarios. Add a scenario for each example the user gave, and an
   expectation for each query in each scenario.
3. **Verify** with `verify`. Fix every error and warning: the reply says what
   is wrong and suggests a fix. Do not stop while a test fails.
4. **Answer** with `query`, and give the user the answer *and* the
   explanation in plain words. Quote the rule an answer rests on.
5. **Look for the cases nobody tried.** Before you finish, and whenever the
   user asks what is untested, what could go wrong, or whether something can
   happen, run a case search (next section) on each main conclusion. Do not
   work the cases out in your head: report each case marked *no scenario
   covers it*, and the case that breaks a property. Each such answer comes
   with a scenario that meets it; add it to the program, with the expectation
   the user confirms.
6. **Save** the program as a `.le` file in the user's project when they work
   in one, so it can be opened in the editor at
   https://le2.logicalcontracts.com (File ▸ Open).

## Questions over every case

Two kinds of query look at every case the rules allow, with no scenario:

```
query support cases is:
    which cases make it the case that
        a person gets rent support.

query both eligible and excluded is:
    is there a case in which
        a person is eligible for rent support
        and the person is excluded from rent support.
```

The query can also be passed to `query` directly, as text, without adding
it to the program. The first lists each case in which the goal holds, in
general terms, and which of the program's scenarios cover it. The second looks for a case that
breaks a property, and returns it with a scenario that shows it. A scenario
can expect `["there is no such case: the search covered every case"]`, which
makes the property one of the program's tests. Use these to find the cases
the user's examples never tried, and the gaps between two rules.

## Things that often go wrong

- A sentence must match a template word for word, apart from `a`, `an`,
  `the`, `is`, `are`, `has`, `have` and the like.
- `a person` introduces a variable; `the person` refers back to it in the
  same rule. A `the …` with nothing before it names one fixed individual.
- Arithmetic uses short capitalised names: `and TOTAL = PRICE * 1.2`, not
  descriptive words, inside a formula.
- There is no `min`/`max` function: write `the minimum of A and B is C`.
- A negated condition goes on its own indented line after
  `it is not the case that`.
- Dates are written `2026-10-16`; compare them with `is before`, `is after`,
  `is N days after`, `is N months after`.
- An expectation names the query without the word `query`:
  `support expects answers ["ana gets rent support"].`

For anything else, search the reference: `search_documentation` with a few
keywords, or `le.sh doc` and look for the section.

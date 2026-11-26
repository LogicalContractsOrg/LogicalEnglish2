# From a LOMO description to a full Logical English program: a guide for agents

*Kind: guide for agents (coding assistants) · Audience: an agent asked to "write the conditions" of a LOMO description · Status: current (2026-11-26), from the work on GDPR Articles 6 and 33 and Directive 2013/34/EU*

A LOMO description says *who must do what, by when, under which provision*.
It does not say *when a rule applies*: LOMO has no conditions. A **register**
(the description translated by `migration/lomo/`) therefore answers every
question about a case as if the conditions of each rule held, and says so
in each explanation (`it is not the case that R has written conditions`).

This guide is how to add the conditions: read the legislation that the
description cites, and write its conditions in Logical English, beside the
register, so that the program decides cases as the law does. The three
programs of `agent_written/` were made this way; read them first:

| Program | What it shows |
|---|---|
| `agent_written/cases/gdpr_article_6_conditions.le` | a rule that holds `only if` one of six alternatives holds, with an exception inside one alternative |
| `agent_written/cases/gdpr_article_33_conditions.le` | an `unless` exception, and a second duty that the text adds (reasons for a late notification) |
| `agent_written/other/directive_2013_34_conditions.le` | definitions with thresholds (sizes of undertakings, "two of three criteria"), an exemption that the description lacks, added in LOMO's own words, and its limits in other articles |

The Contract Assistant is not needed for this, and it is not set up for it.

## 1. Start from the register, not from the text

1. Translate the description: File ▸ Open of the `.ttl`, or
   `./myswipl.sh -q migration/lomo/build.pl -- file.ttl`. Keep the register
   as the translator wrote it: never edit it.
2. Read the register's questions: `obligations`, `places`, `deadlines`,
   `rules_without_conditions`. Each rule in `rules_without_conditions` is a
   rule whose conditions you may have to write.
3. Note for each rule: its name in the register (`norm publication
   obligation`), its provision (`is established in "<ELI>"`), its action, its
   bearer (`the bearer role is addresser`), its deadline.

## 2. Get the text of each provision

1. Use `lomo_eli:provision_text(ELI, Text)` (migration/lomo/lomo_eli.pl). It
   fetches the act from the Publications Office's repository (Cellar) by its
   CELEX number and cuts out the article, paragraph or point. EUR-Lex itself
   refuses automated clients; Cellar does not.
2. Read the **whole article**, not only the cited paragraph: exceptions are
   often in another paragraph (Article 36(7)) or another article (Article 40).
3. Check that the provision **exists**. The specification of LOMO cites an
   "Article 1a" of Directive 2013/34/EU that the directive does not have.
4. Check **which version** the description cites. An ELI ending in `/oj` is
   the act as published; the consolidated text may have other values (the
   thresholds of Article 3 changed in 2023). Say in the program which version
   you followed.
5. Write the text of each provision you quote into `sources/eli/` beside
   the program (`lomo_eli:write_provision_texts/3` does it; `build.pl` does
   it for the programs of `agent_written/`), and declare it:
   `the text of "<ELI>" is at "sources/eli/<file>.txt".` The editor then
   checks every quotation.

## 3. Write the program beside the register

```le
the target language is: prolog.

the templates are:
    *an undertaking* is in the scope of the directive; undefined.
    ...

the knowledge base my_conditions includes these resources:
    financial_reporting_dir_2013_34_lomo_manual.

the knowledge base my_conditions includes:

norm publication obligation has written conditions.

rule art_30_1 with provenance "http://data.europa.eu/eli/dir/2013/34/art_30/par_1/oj",
        confer "Member States shall ensure that undertakings publish ...":
the conditions of norm publication obligation hold for an undertaking if
    the undertaking is in the scope of the directive.
```

- **One fact switches a rule from the description to your conditions:**
  `<rule> has written conditions.` Without it, the library's default (the
  conditions hold) stays.
- **The conditions sentence is `the conditions of <rule> hold for <party>
  if ...`.** The party is whoever the rule reaches. Include `and the party
  counts as <agent type>` when the conditions must not hold for others.
- **Label each rule and cite its provision** with `with provenance "<ELI>"`
  and `confer "<the exact words>"`. Quote the words exactly as the text has
  them (the quotation marks of the Official Journal are `‧…‧`).
- **Definitions.** When the description has a definition that `defines` an
  agent type, write `a party meets the definition <definition> if ...`; the
  library then makes the party of that type. For an agent type with no
  definition in the description, write `a party is of the type <agent type>
  if ...` directly.
- **"Only if"** (`Processing shall be lawful only if ...`): write the `only
  if` rule and also each sufficient case as an `if` rule. Ask the negative
  conclusion of a named party (`the processing of broker is not lawful`):
  the party appears only under `it is not the case that`.
- **Exceptions** ("unless", "except where"): `and it is not the case that ...`
  in the conditions.
- **Something the description lacks** (an exemption, a second duty): add it
  in LOMO's words as facts of your program (`norm micro exemption is a
  prescriptive rule.`, `... derogates from norm publication obligation.`,
  its action and agent role), and give each new thing an address (`... is
  identified by "urn:...".`), or the export breaks LOMO's validity rules. A
  derogating rule sets the other rule aside for the parties it reaches: you
  only write its conditions.
- **A further duty in the text** that is not a LOMO rule (reasons for a late
  notification): write it with the deontic sentences (`a controller is
  obliged that the controller gives the reasons for the delay if ...`).
- **Case facts** are templates marked `; undefined`. Declare every template
  in the one `the templates are:` section at the top: a second section among
  the rules is not read, and a negation of its sentence is then always true.

## 4. Write the cases first, with their answers

1. Before you run anything, write a scenario for each condition and each
   exception: a party that meets it, a party that fails it, a party at each
   threshold.
2. Work out the expected answers from the text, and write them as `expects`
   lines. Do not copy them from a run: they are the test.
3. Give the dates of events (`"balance sheet date" happens to acme on
   2025-12-31.`) or their moments (`... at "2026-03-01T14:30".`) when the
   duty has a deadline in hours.

## 5. Check

1. Verify the program: no errors; the warnings explained or removed.
2. Run its tests: `runTestsFor/2`. A test that fails is either your rule or
   your reading of the text: read the article again before you change the
   expected answer.
3. Export it: File ▸ Export ▸ LOMO. The result must have no notes about
   LOMO's validity rules.
4. Put the program under `agent_written/<set>/` and rebuild, so that
   `build.pl` copies it beside its register with the texts it cites.
5. Record what the text taught you about the description (a missing
   article, an outdated value, a wrong role) in the README of the door and in
   the plan's progress section (`lpsPlus docs/strategy/LOMO.md`).

## What is still worth deciding

Writing the conditions of a description is the work of a lawyer, aided. An
agent can draft it well when the text is short and the description is good
(each of the three programs took one session). Whether to extend the
Contract Assistant to start from a LOMO description is open: it would save
the cutting and naming that the description already gives, but most of the
work is reading the right articles and writing exact cases, which this guide
asks for in any case.

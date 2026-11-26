# LOMO and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-11-26)*

> **About the language of this document.** This document obeys the rules of
> ASD-STE100 Simplified Technical English: short sentences, numbered steps for
> procedures, the active voice, and one word for one meaning. The names of the
> user interface, of Logical English ideas and of LOMO terms are not STE words.

LOMO, the Legal Obligation Metadata Ontology, is a vocabulary of the European
institutions. It *describes* the rules of a legal text. A LOMO **description**
tells, for each rule:

- the kind of rule (an obligation or a permission, a definition, a scope rule),
- the provision that makes the rule, by its ELI (the European Legislation
  Identifier: the web address of an act, an article, a paragraph or a point),
- the exact words of the provision,
- the **modality** of the rule: obligation, permission, prohibition or right,
- the **action** that the rule asks for, the **agents** of the action and
  their **roles** (the **addresser** does the action, the **addressee**
  receives it, the **beneficiary** gets the benefit),
- the result of the action (a report, a data set), and its times (a
  **deadline**, a period of validity, a **trigger**).

A description is written in RDF, the data format of the web, usually as a
Turtle file (`.ttl`). Version 1.1.0 of LOMO is of 21 October 2026. The
licence of LOMO and of its data is Creative Commons Attribution 4.0.

A LOMO description has no conditions, no values and no cases. It does not
say *when* a rule applies. The makers of LOMO say so in their open requests
166 and 173: conditions and the resolution of conflicts between rules belong
in "an external reasoning layer". Logical English (LE) can be that layer.

LOMO is a work of the European institutions. The makers of LOMO did not
make the LOMO translator of Logical English, and they did not examine it.

## Contents

- [What Logical English does with a description](#what-logical-english-does-with-a-description)
- [How to open a description](#how-to-open-a-description)
- [The register](#the-register)
- [Questions about a description](#questions-about-a-description)
- [A case: who must do what, by when](#a-case-who-must-do-what-by-when)
- [The conditions of a rule](#the-conditions-of-a-rule)
- [Derogations](#derogations)
- [Dates and lengths of time](#dates-and-lengths-of-time)
- [Duties through time, in LPS](#duties-through-time-in-lps)
- [The text of a provision](#the-text-of-a-provision)
- [The way back: from Logical English to LOMO](#the-way-back-from-logical-english-to-lomo)
- [How the translator was checked](#how-the-translator-was-checked)
- [What is not supported yet](#what-is-not-supported-yet)
- [See also](#see-also)

## What Logical English does with a description

Logical English does four things with a LOMO description:

1. It **holds** the description, without loss: each statement becomes one fact.
2. It **answers the questions** of LOMO's requirements document, for example
   "Which obligations does this act impose, and on which addressees?".
3. It **runs the part that has values**: who must do which action, by which
   date, and who is late, when you give the events of a case.
4. It **is the place for the conditions**. You write the conditions of a rule
   in Logical English, beside the description, with the same rule and the same
   provision.

Logical English also writes a program back as a LOMO description.

## How to open a description

Do these steps:

1. Select **File ▸ Open…**.
2. Select a `.ttl` file that uses the words of LOMO.
3. Click **Open**.

The editor shows the **register** of the description (refer to the next
section). The file is kept in the folder `sources/` beside the register. To
see it, select **File ▸ Show the Original…**.

The editor also has the registers of the public data of LOMO:

1. Select **File ▸ Open example from server…**.
2. Open the folder `migration/lomo/`.
3. Select a register, for example `other/financial_reporting_dir_2013_34_lomo_manual`.

## The register

A **register** is a Logical English program that has one fact for each
statement of a description. The library `lomo.le` gives the words of the
facts. This is a part of the register of Directive 2013/34/EU (financial
statements):

```le
norm publication obligation is identified by "http://example.org/accounting-graph#Norm_PublicationObligation".
norm publication obligation is a substantive rule.
norm publication obligation has the modality obligation.
norm publication obligation is established in "http://data.europa.eu/eli/dir/2013/34/art_30/par_1/oj".
norm publication obligation produces step publish full report.
step publish full report has the agent role agent role micro undertaking publisher.
agent role micro undertaking publisher is for the agent actor micro undertaking.
agent role micro undertaking publisher has the role addresser.
step publish full report has the time specification step publish full report time.
step publish full report time has the function deadline.
step publish full report time has the duration "P12M".
step publish full report time is timed after step publish full report time after.
step publish full report time after has the temporal label "balance sheet date".
```

- Each thing of the description has a **name**: words from the end of its web
  address. The fact `... is identified by "..."` keeps the full address.
- A term of LOMO's word lists is a word: `obligation`, `deadline`,
  `addresser`, `data`.
- A property that the library does not know has the general form
  `... has for "eli-lo:unit" the value "EUR"`. Thus no statement is lost.
- The fact `the bearer role is addresser.` tells which role bears a duty. Some
  descriptions write the bearer as the addressee. Then select that option when
  you translate (refer to [What is not supported yet](#what-is-not-supported-yet)).

The register also has a **ledger**: a list of each thing of the description,
the words of older versions of LOMO that it uses, and the statements that
break the validity rules of LOMO. To see the ledger, select **File ▸ Show the
Ledger…**.

## Questions about a description

Each register has the questions of LOMO's requirements document as queries.
Do these steps:

1. Open a register.
2. Select a query in the list next to **Query**, for example `obligations`.
3. Click **Query**.

| Query | The question |
|---|---|
| `rules_of_act`, `places` | Which rules does an act establish? In which article and paragraph? |
| `kinds` | Which things does the description name, and of which kind? |
| `obligations`, `permissions`, `prohibitions`, `rights` | Which rule obliges (permits, forbids) which agent, in which role? |
| `addressers`, `addressees`, `beneficiaries` | Who does, receives, gets the benefit of an action? |
| `deadlines`, `triggers`, `frequencies` | What are the times of an action? |
| `sequence` | Which action comes before which action? |
| `derogations`, `specifications` | Which rule derogates from, or specifies, which rule? |
| `digital_dimensions`, `datasets`, `standards` | The digital parts of the rules |
| `texts` | Every text of the description, for a search |
| `rules_without_conditions` | Which rules have no conditions written for them? |

The answers come from the facts and from the library. For example, a
substantive rule is also a prescriptive rule and a legal rule. A link that
the description gives in one direction (`derogates from`) is also true in the
other direction (`is derogated by`).

## A case: who must do what, by when

A **scenario** of a register gives the facts of a case: the parties, their
types, and the dates of events. This scenario is from the register of the
door's own example `cases/probe`:

```le
scenario case_one is:
    acme is of the type controllers.
    acme is of the type undertakings.
    tiny is of the type undertakings.
    tiny is of the type micro undertakings.
    "awareness of a personal data breach" happens to acme on 2026-03-01.
    acme performs notify the breach on 2026-03-05.
    "balance sheet date" happens to acme on 2025-12-31.
    "balance sheet date" happens to tiny on 2025-12-31.
```

With this scenario, the queries give these answers:

- `must_perform`: acme must perform notify the breach by 2026-03-04 under
  norm gdpr 33. (The description gives 72 hours after the event: 3 days.)
- `must_perform`: acme must perform publish the statements by 2026-12-31
  under norm accounts 30.
- `late_on_1_april_2026`: acme is late with notify the breach.
- `set_aside`: norm accounts 30 is set aside for tiny by norm micro 36.

A rule **applies to** a party when the party is of the type of the agent that
bears the action of the rule, when the conditions of the rule hold for the
party, and when no derogation sets the rule aside. The explanation of each
answer shows these steps.

## The conditions of a rule

LOMO has no place for the conditions of a rule. Thus, in a register, the
conditions of each rule count as holding until somebody writes them. Each
answer that depends on a rule shows the condition
`it is not the case that norm gdpr 33 has written conditions`. Thus an answer
never hides that only the description was used.

To write the conditions of a rule, write a program that includes the
register. Do these steps:

1. Make a new program in the folder of the register.
2. Include the register: `the knowledge base x includes these resources: probe.`
3. Write the fact `norm gdpr 33 has written conditions.`
4. Write the rule `the conditions of norm gdpr 33 hold for a controller if ...`.

The folder `migration/lomo/cases/` has three such programs:

| Program | What it writes |
|---|---|
| `gdpr_article_6_conditions` | Article 6(1) of the data protection regulation (GDPR): "Processing shall be lawful only if ... at least one of the following applies", with its six points. This is the example of LOMO's request 166 |
| `gdpr_article_33_conditions` | Article 33(1): the exception "unless the personal data breach is unlikely to result in a risk", and the second duty, to give the reasons for a late notification |
| `other/directive_2013_34_conditions` | Directive 2013/34/EU: the sizes of undertakings (Article 3), the publication (Article 30), the exemption of micro-undertakings (Article 36(1)(d)) and its limits (Articles 36(7) and 40) |

Each rule of these programs cites its provision: `rule art_3_1 with
provenance "http://data.europa.eu/eli/dir/2013/34/art_3/par_1/oj", confer
"..."`. The editor compares the quotation with the text of the provision
(refer to [The text of a provision](#the-text-of-a-provision)).

## Derogations

A rule **derogates from** a second rule when it gives a different answer for
some cases, and wins. In a register, a derogating rule sets the second rule
aside for each party that the derogating rule **reaches**. A rule reaches a
party when the party bears the action of the rule and the conditions of the
rule hold.

> **Note:** a derogation from a derogating rule is not examined. No
> description of LOMO has such a chain.

The specification of LOMO has three examples of derogation. Their register
is `spec/derogatesfrom`. Its scenarios add the actions and the cases that the
examples leave out, and the answers show who is bound in each case.

## Dates and lengths of time

LOMO writes a length of time in the ISO 8601 form: `P12M` is 12 months,
`P20D` is 20 days, `P1W` is one week, `PT72H` is 72 hours. The library
`temporal.le` calculates with these lengths:

```le
the due date is the period "P12M" after the balance sheet date
```

- A date in Logical English is a day. Thus hours count as whole days, and the
  system rounds up: `PT72H` is 3 days. The query `hours_as_days` shows each
  length of time that was rounded.
- A **rhythm** (a frequency, `P1Y`) gives a date for each period. The query
  `due_in_2027` shows the dates in 2027.
- A date without a year ("30 September") has its own template:
  `the day "30 September" in the year 2027 is 2027-09-30`.

The library also has the relations between times: *later than*, *during*,
*overlaps with*. The query `broken_links` shows a link that the dates of the
description contradict. For example, an appeal period that the description
puts after a notification, but with a date before it.

## Duties through time, in LPS

LPS2 (Logic Production Systems 2) runs programs that act over time. The
library `lomo_calendar.le` of LPS2 runs the duties of a case day by day: a
duty starts when its trigger happens, ends when the party does the action in
time, and is breached when the date passes.

The LOMO translator writes the program of a case from a register and its
scenario. LE for LPS counts days, not dates. Thus each date of the case
becomes a day number. The first lines of the program tell what the run must
show at the end. Refer to the examples in the folder `migration/lomo/` of
LPS2.

## The text of a provision

The translator gets the text of a provision from its ELI. It asks the
repository of the Publications Office of the European Union (Cellar) for the
act. Then it takes the article, the paragraph or the point that the ELI names.
The text goes in `sources/eli/` beside the register, and the program gets a
line such as:

```le
the text of "http://data.europa.eu/eli/dir/2013/34/art_36/par_1/pnt_d/oj" is at "sources/eli/dir_2013_34_art_36_par_1_pnt_d_oj.txt".
```

Thus **File ▸ Show the Original…** shows the provision, and the editor
compares each `confer "..."` quotation with the text.

> **Note:** this works for regulations, directives and decisions. A
> proposal of the Commission has a different kind of ELI, and the translator
> does not get its text.

## The way back: from Logical English to LOMO

**File ▸ Export to Another System… ▸ LOMO** writes a Turtle file. Do these
steps:

1. Open a program.
2. Select **File ▸ Export to Another System…**.
3. Select **LOMO**.
4. Click **Export**.

The export reads the program in one of two ways:

- **A register, or a program that includes one.** Each fact in the words of
  `lomo.le` becomes its statement again. The facts that a program adds (for
  example, the exemption of Article 36 in `directive_2013_34_conditions`)
  become statements too.
- **Any other program.** Each rule with a label and the address of its
  provision (`rule r with provenance "<address>"`) becomes a legal rule of the
  description. A rule that concludes an obligation, a permission or a
  prohibition becomes a prescriptive rule, with its action and its addresser.
  The conditions are not written in LOMO: the description refers to the
  program.

The export checks the file against the validity rules of LOMO before it gives
the file to you. The check runs on your computer. Nothing goes to a service of
the Commission. A rule that has no address of its provision cannot go into a
description: the export refuses the program, and it tells you which rules to
change.

## How the translator was checked

| Check | Result (26 November 2026) |
|---|---|
| The seven search queries of the LOMO repository, on the RDF data (with rdflib) and on the register | the same rows: 131 of 131 files (the 63 data files, the 65 examples of the specification, 3 cases of ours): the same 1,977 rows |
| The validity rules of LOMO: our check and pySHACL (the reference engine for SHACL in Python) | the same results, file by file and result by result: 134 of 134 files (the same 131 and 3 files broken on purpose): the same 166 results |
| Each register's own scenario: answers of rdflib for three questions | 131 of 131 registers pass their scenarios |
| The calendar of the 11 data files with a deadline that has a value, against a calendar written in Python with no Logical English | the same due dates |
| The time examples of the specification, with dates worked out by hand | all pass |
| The three derogation examples of the specification, GDPR Articles 6 and 33, Directive 2013/34/EU | all pass; each quotation agrees with the text of the provision |
| The cases in LPS2, against the timeless reading for the last day | 3 of 3 |
| The way back: each register to Turtle and again | 131 of 131 give the same graph again (30,105 statements; rdflib compares the graphs, blank nodes included) |
| The way back: LE2's examples that cite provisions, and the LegalRuleML twins | 99 programs cite their provisions: 93 become valid descriptions (10,894 statements); the other 6 are refused, and the export tells why (a rule cites a document that has no web address) |

The checks found these points in the material of LOMO:

- Directive 2013/34/EU has no Article 1a. The example of `derogatesFrom` in
  the specification cites it. The exemption of micro-undertakings is
  Article 36.
- The example of `TemporalSpecification` writes 24 hours as `P24H`. ISO 8601
  writes `PT24H`.
- The description of Directive 2013/34/EU in the LOMO repository gives the
  limits of 2013 for micro-undertakings (EUR 350 000 and 700 000). Delegated
  Directive (EU) 2023/2775 changed them to EUR 450 000 and 900 000.
- One data file (settlement) gives the frequency of an action as the text
  `"Ad-hoc"` (two times, and one longer text). LOMO asks for a length of time
  (`xsd:duration`), and a program cannot calculate with such a text. The
  ledger of the register lists them.

## What is not supported yet

- **Hours.** A date is a day. A deadline in hours counts in whole days.
- **The bearer of a duty.** The translator reads the addresser as the party
  that bears a duty, as the ontology defines the roles. The data made from the
  digital statements often writes the bearer as the addressee. The option
  `bearer(addressee)` of the translator reads them so (it is not in the menu
  yet).
- **Rhythms in LPS.** The LPS library does not repeat a duty yet. The timeless
  calendar of LE has rhythms.
- **A chain of derogations.** It is not examined (refer to [Derogations](#derogations)).
- **Definitions** are text in LOMO. A definition that gives the meaning of an
  agent type (`defines`) makes the sentence `a party meets the definition ...`.
  A person decides it, or a program writes it as a rule, as
  `directive_2013_34_conditions` does for micro-undertakings.

## See also

- [The Migration Gallery](gallery.md): the other systems that Logical English reads.
- [LegalRuleML and Logical English](legalruleml.md): the deontic library that
  the register uses.
- The specification of LOMO: <https://drpm.pages.code.europa.eu/lomo/latest/>.
- The LOMO repository: <https://code.europa.eu/drpm/lomo>.
- For developers: `migration/lomo/README.md` of Logical English 2.

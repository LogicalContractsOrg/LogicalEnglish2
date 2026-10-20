# s(CASP), Prolog and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

s(CASP) is a reasoner. You give it a question, and it goes backwards from the
question, through the rules, to the facts. s(CASP) reasons in Answer Set
Programming with constraints. Answer Set Programming is a form of logic
programming. In this form, a program can have more than one consistent set of
conclusions. People run s(CASP) from SWI-Prolog, and Blawx also runs it. An
s(CASP) program is similar to Prolog, with more items in it:

- classical negation (`-flies(X)`);
- abducibles, which are facts that the reasoner can assume;
- global constraints (`false :- …`);
- comparisons that are written as constraints (`#>`);
- `#pred` lines, which tell how each predicate reads in English.

LE1, the first Logical English, changed its documents into programs of that
type.

Logical English 2 connects to s(CASP) and Prolog in two directions. The two
directions operate very differently. In the incoming direction, **File ▸
Open…** (or **File ▸ Import from Another System…**) translates a `.pl`,
`.scasp` or `.lp` file into a Logical English program. A file that LE1 wrote in
s(CASP) is one of these files. That translator is a part of the Logical English
Translators. Thus only the installations that have the Translators give the
translator, for example the hosted service. In the outgoing direction there is
no export menu. The reason is that every installation can show you the other
forms of the program directly:

- **See s(CASP)** shows the full program in s(CASP). To find it, right-click in
  the editor.
- The **Engine** picker answers a query with s(CASP) instead of with Prolog.
- **See PROLOG** shows the Prolog clause that Logical English makes from a
  rule.

To answer with s(CASP), the server must have the s(CASP) pack of SWI-Prolog.
The hosted service has that pack.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [Opening an s(CASP) or Prolog file](#opening-an-scasp-or-prolog-file)
  - [LE1's s(CASP) translations](#le1s-scasp-translations)
  - [The example twins](#the-example-twins)
  - [See s(CASP): the program in s(CASP)](#see-scasp-the-program-in-scasp)
  - [The s(CASP) engine](#the-scasp-engine)
  - [See PROLOG: the PROLOG Equivalent panel](#see-prolog-the-prolog-equivalent-panel)
- [How s(CASP) and Prolog map to Logical English](#how-scasp-and-prolog-map-to-logical-english)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| s(CASP) or Prolog → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | `.pl`, `.scasp`, `.lp` | templates from `#pred` (if there is no `#pred`, a wording from the names), opposite forms, `unknown` templates, integrity constraints, the scenarios of LE1 and the `?-` queries as scenarios and queries, a ledger | the answers of s(CASP) on the source, as the expectations of the scenarios (when the server has s(CASP)) |
| Logical English → s(CASP) | right-click in the editor ▸ **See s(CASP)**; the **Engine** picker | shown in the **PROLOG Equivalent** panel, with **Copy** | the full program in s(CASP), or the list of the parts that s(CASP) cannot state | the round trip LE → s(CASP) → LE → s(CASP) on the examples of LE2 |
| Logical English → Prolog | right-click in the editor ▸ **See PROLOG** | shown in the **PROLOG Equivalent** panel, with **Copy** | the Prolog clause of the rule or fact at the cursor | the Prolog engine: the Prolog engine runs that clause |

## How to use it

### Opening an s(CASP) or Prolog file

> Note: the file must hold Prolog clauses, and these can include the operators
> of s(CASP). A minimum of one clause must be a rule or a fact, not a
> directive.

Do these steps:

1. Select **File ▸ Open…**.
2. Select a `.pl`, `.scasp` or `.lp` file.
3. Read the note in the new tab that opens.
4. Select **File ▸ Show the Original…** to see the original file.
5. Examine the templates before you do other work.
6. Change the templates that do not tell what the predicates mean.

The note in step 3 gives the counts from the ledger. The ledger is the record of
how LE translated each part of the file. The note also gives the comparison with
s(CASP). An example of a note is *birds: 16 source elements encoded,
0 approximated, 0 residue; 0 writer errors; the source's own answers
(s(CASP)): 1 expectations pass, 0 fail, 0 errors.*

Each `?-` query in the file becomes a query with the name `query_1`, `query_2`,
and so on. Each scenario asks all these queries. A file with no scenarios gets
one scenario, `the_program`. That scenario asks the queries about the facts of
the program. The expected answer of each query is the answer that s(CASP) gave
on the original file.

A clause that Logical English cannot state becomes a `% RESIDUE … BEGIN` block.
The block holds the clause word for word, and the reason why LE did not
translate it. Two types of clause go into a block. The first type is a clause
that takes a list apart. The second type is a statement in the form of clingo.
clingo is a different Answer Set Programming system (refer to Traps, below):

```le
% RESIDUE list_pattern_1 BEGIN: a clause that takes a list apart
% TODO: translate the fragment below by hand, or with the Contract Assistant (residue mode); it was not translated automatically
% Logical English has no list patterns (a list's first element and the rest, [H|T]); a recursive definition over a list is written with an included Prolog resource, or restated with aggregates
```

The editor keeps the original file in the `sources/` folder of the program. The
program cites the original file: `the text of the source program is at "sources/…"`.
The ledger is `<name>.ledger.md`.

In step 5, the templates are the first thing to examine. Where the file has
`#pred` lines, the translator uses their words. In all other places, the
translator makes a wording from the name of the predicate. For example,
`parent(X, Y)` becomes `*a thing* is the parent of *a second thing*`. Change the
names of these templates, so that they tell what the predicates really mean.

After these steps, **Misc ▸ Run the Program's Tests…** examines the expected
answers.

You can also go out and come back again. Do these steps:

1. Copy the text that **See s(CASP)** shows (refer to the section below).
2. Paste the text into a `.scasp` file.
3. Open that file with **File ▸ Open…**.

The rules come back as Logical English. A rule that contains `or` comes back as
more than one rule. The reason is that the s(CASP) text writes each alternative
separately. The scenarios and the queries are not in that text. Thus they do not
come back with the rules.

### LE1's s(CASP) translations

LE1 wrote each of its documents as an s(CASP) program. The sentences became
rules with `#pred` lines. The scenarios became blocks of comments. The queries
came after the program:

```
/* Scenario alice
is_born_in_on('John', the_UK, 1633737600.0).
...
% */
```

The translator reads all of these items. Each scenario of LE1 becomes a
scenario. This is true if LE1 wrote the scenario in a comment, and also if LE1
wrote it as live clauses between `/* Scenario x */` and `/* % */`. A rule in a
scenario becomes a rule of that scenario. Some lines of LE1 are about the
program and not about the law: `source_lang/1`, the module line, and the
directives of the loader. The translator does not keep these lines.

LE1 wrote a date as a Unix time, which is the count of seconds since 1970. An
example is `1633737600.0` in a place with the type `date`. The translator
changes this number into a date, `2021-10-09`. LE1 programs call
`is_days_after/3`, but they do not define it. The translator changes each call
into the LE2 template `*a date* is *a number* days after *a date*`. Thus an LE1
program comes into LE2 through its s(CASP) translation. The program brings its
scenarios, and it uses the answers of s(CASP) as its tests:

```le
a person acquires British citizenship on a date if
    the person is born in the_UK on the date
    and the date isafter commencement
    and a second person is a parent of the person
    and the second person is citizen or settled the date.
```

### The example twins

Seventeen programs have translations already. The translated programs have the
name *twins*. They are in the examples, in `migration/scasp/`. To open a twin,
select **File ▸ Open copy from server…**. The twins are:

- the translations of LE1 (from the tests of the s(CASP) pack): `citizenshiptrust`,
  `criminaljustice`, `family_le`, `impossibleancestor` (a rule in a scenario),
  `isdapermissioncorrected` (sentences as values), `itispermittedthat`,
  `list` (its own universal, and a list pattern as residue), `loanwithcure`
  and `obligation` (dates), `minicontract`, `simplerps`, `subset`,
  `turingcomplete` (embedded `prolog` goals for the list built-ins of s(CASP));
- classic examples of s(CASP): `birds` (classical negation), `family`,
  `classic_negation_inconstistent`, `abdbirds` (abducibles).

Each answer that a twin expects is the answer that s(CASP) gave on the original
file. Two of these expected answers are comments, not live tests. Each of them
has its reason adjacent to it. In `obligation`, s(CASP) answers with a
constraint, not a value. In `loanwithcure`, s(CASP) says that the borrower
defaults. But the cure rule of the program is true on that date. The twin
follows the rules.

### See s(CASP): the program in s(CASP)

Do these steps:

1. Right-click in the editor.
2. Select **See s(CASP)**.

The **PROLOG Equivalent** panel opens. The panel holds the full program in the
form that s(CASP) writes. The program has these parts:

- a `#pred` line for each template;
- the rules;
- classical negation for the opposite forms;
- `false :- …` for the constraints;
- at the end, a comment for each problem that LE found when it wrote the
  program.

**Copy** copies the full text. This is the program `birds`:

```
#pred can_fly(A) :: '@(A:thing) can fly'.
...
can_fly(A) :-
    is_a_bird(A),not(is_an_ab(A)).
-can_fly(A) :-
    is_an_ab(A).
```

Possibly the program uses an item that s(CASP) cannot say correctly. Examples are
an aggregate, a `prolog` goal, a decision table, `is in`, date arithmetic and
`according to`. In that case the editor does not show a program. The editor
shows the *Not translated* window, which a refused export also uses. The window
gives each problem, adjacent to its line. The full list of the items that s(CASP)
cannot say is in
[the s(CASP) reference, §8](../reference/scasp.md#8-unsupported-constructs--issues-errors).
There is no **File ▸ Export** to s(CASP). **See s(CASP)** is the way out.

### The s(CASP) engine

The **Engine** picker is adjacent to **Query**. It selects the reasoner that
answers the query, Prolog or s(CASP). **Misc ▸ ENGINE PICKER** decides when the
editor shows the picker: for every program, or only for programs with a target
language that is not Prolog. A program that declares `the target language is: scasp.`
selects s(CASP) when the program loads. The translator writes that
declaration when the original file has abducibles, classical negation or
constraints. The editor keeps your selection in the web address of the page, as
`engine=scasp`.

s(CASP) gives you three things that Prolog does not give:

- answers that are constraints, not values;
- more than one possible world for one question;
- abduction, which is the assumption of facts that make the answer true.

Each world of an abductive query gives a list of what that world assumes
(*assuming tweety is a penguin*). **Trace** operates with Prolog only. The
engine refuses a program that s(CASP) cannot state, as **See s(CASP)** also
refuses it. The [s(CASP) reference](../reference/scasp.md) describes the
reasoner fully. This guide does not repeat what the reference says.

### See PROLOG: the PROLOG Equivalent panel

Logical English changes into Prolog, and the Prolog engine runs the Prolog. Do
these steps:

1. Put the cursor in a rule, a fact or a scenario fact.
2. Right-click.
3. Select **See PROLOG**.

The **PROLOG Equivalent** panel shows that one clause, with a **Copy** button:

```
is_a_parent_of(A, B) :-
    le_at(is_the_mother_of(A, B), 1225, 1270).
```

The clause holds the positions of the words in the Logical English document
(`le_at(Goal, Start, End)`). These positions connect each step of an
explanation to the sentence that it came from. The reasoner of Logical English
runs the clause. The clause is not a Prolog program that can run alone. There
is no export to Prolog. The reason is that Prolog is what Logical English
changes into, not a different system to translate to. To use Prolog code
*inside* a program, include a `.pl` resource
([Prolog resources](../reference/language.md#141-prolog-resources-pl)).

## How s(CASP) and Prolog map to Logical English

| s(CASP) or Prolog | Logical English |
|---|---|
| `#pred p(X,Y) :: '@(X:person) is born in @(Y:place)'` | the template `*a person* is born in *a place*`; more than one wording of one predicate are synonyms |
| a predicate with no annotation | a wording from its name and the variables of its clauses: `parent(X, Y)` → `*a thing* is the parent of *a second thing*`; `flies(X)` → `*a thing* flies` |
| a fact, a rule | a fact, a rule |
| `not p(X)` (negation as failure) | `it is not the case that` |
| `-p(X)` (classical negation), with `#pred -p(X) :: …` | the opposite form of p: `*a thing* can fly; opposite: *a thing* can not fly` |
| `#abducible p(X)` | `; unknown` on the template |
| `:- Body.` or `false :- Body.` | an integrity constraint: `it must not be true that …` |
| `X #> Y`, `#>=`, `#<`, `#=<`, `#<>` | comparisons; `#=` is an assignment |
| `?- Goal.` | a query `query_<n>` |
| `is_a/2` | the LE `is a` |
| a `forall/2` of the program | a universal, `for all cases in which … it is the case that …` |
| the s(CASP) helpers of LE, `le_forall_K` | the universal again |
| a Prolog built-in goal | a `prolog` goal |
| `[H|T]` patterns | a residue block |
| LE1: `/* Scenario x … % */`, Unix-time dates, `is_days_after/3` | a scenario, ISO dates, `… is … days after …` |

This is the twin `birds`, from the examples of s(CASP):

```le
the target language is: scasp.

the templates are:
    *a thing* is a penguin; opposite: *a thing* is not a penguin.
    *a thing* can fly; opposite: *a thing* can not fly.

a thing can fly if
    the thing is a bird
    and it is not the case that the thing is an ab.

a thing can not fly if
    the thing is an ab.
```

This is a denial with abducibles, from a small file:

```le
    *a person* votes; unknown; opposite: it is false that *a person* votes.

% Constraint 1 of the source: no case, and nothing assumed, may meet these conditions.
it must not be true that
    a person is an adult
    and the person is a minor.
```

To write s(CASP) and to read s(CASP) are two directions of one correspondence.
LE examined this on the examples of LE2. LE went from Logical English to
s(CASP), then to Logical English, then to s(CASP) again. The result was the
same s(CASP) program for 83 of the 88 programs that s(CASP) can state
(14 September 2026;
[§14 of the reference](../reference/scasp.md#14-reading-scasp-back-september-2026)).

## Traps

- **The expected answers need s(CASP) on the server.** The translator finds
  each expected answer. To do this, it runs the original file with the s(CASP)
  library of SWI-Prolog. If the server does not have that library, the
  translator keeps each expected answer as a comment, `% pending — s(CASP) did not answer on the source (…)`.
  A note tells that s(CASP) is not installed, and how many answers wait.
  Write your own `expects answers` lines, or open the file on an installation
  that has s(CASP).
- **Only s(CASP) and Prolog syntax.** Answer Set Programming has more than one
  dialect. A `.lp` file in a different dialect is not s(CASP). Each statement
  that only clingo understands becomes a `% RESIDUE not_scasp_<n>` block. The
  block holds the text of the statement and its line, and the ledger counts it
  as residue. These statements are: a choice rule `{a;b}.`, a head with
  alternatives `a ; b.`, cardinality bounds `1 { … } 1`, `#count` aggregates,
  ranges `1..n`, weak constraints `:~`, and `#const`. A line that the
  translator cannot read also goes into a block. An expected answer waits if
  its query depends on the conclusions of such a block. Some blocks conclude
  nothing that has a name, for example a weak constraint or a `#const`. Then
  all the expected answers wait, because s(CASP) ran without that block.
  Write the choices again in s(CASP) or in Logical English.
- **Wordings from names read strangely.** `old(X)` becomes `*a thing* is an
  old`, and `s(C)` becomes `*a thing* is a s`. The translator keeps a `#pred`
  wording exactly as it is written, also with its typing errors
  (`isafter commencement`). A quoted constant keeps its underscores
  (`the_UK`). Edit the templates. The ledger gives a list of all of them.
- **Lists.** A clause that takes a list apart stays as residue. Write the
  clause again with an aggregate or with `is in`, or keep the clause in an
  included Prolog resource.
- **Constraint answers are not values.** Sometimes s(CASP) answers with a
  constraint such as `A #> 3`, and not with a value. Then the expected answer
  waits. A Logical English scenario compares answers as text.
- **The two reasoners use negation differently.** Negation as failure and
  classical negation are two different things. Logical English writes negation
  as failure as `it is not the case that`. Classical negation is the opposite
  form. Think of a program in which a rule negates a conclusion that depends on
  the same rule. If Prolog runs this program, possibly it goes round in circles
  or gives an unsound answer. s(CASP) calculates the stable models instead. The
  verifier gives a warning about this type of program. Run it with
  `the target language is: scasp.`
- **An opposite form in a condition is not a negation.** `the thing can not
  fly` asks for a proof of the opposite form, and a rule must conclude it. The
  opposite form does not have the same meaning as
  `it is not the case that the thing can fly`.
- **Constraints were queries before 15 September 2026.** A twin from before
  that date had a query `denial_<n>`. Each scenario expected no answer to that
  query. Now a denial is an integrity constraint. A case with facts that meet
  the constraint gives no answers. Also, nothing that the reasoner assumes can
  meet the constraint.
- **s(CASP) and Logical English can disagree.** The twin `loanwithcure` is an
  example of a disagreement. The cause is how s(CASP) negates a condition that
  holds an anonymous variable. The twin follows the rules, and keeps the answer
  of s(CASP) as a waiting comment. The twin is never the final decision about
  the meaning of the rules.
- **Constants that end in `_<digits>`.** The s(CASP) library reads `x_1` back
  as `x`. Thus, for s(CASP), `x_1` and `x_2` are the same individual. Give your
  individuals names such as `person_a` and `person_b`.
- **Abducibles with an `is different from` constraint, when the values are not
  fixed yet.** The s(CASP) library (version 1.1.4) can answer these unsoundly.
  It answers soundly a constraint between values that are already fixed.
- **See s(CASP) refuses, and does not approximate.** A program that uses an
  aggregate or a `prolog` goal has no form in s(CASP). Answer such a program
  with the Prolog engine. The two reasoners complete each other.
- **See PROLOG shows one clause, and is not an export.** **See PROLOG** shows
  the clause at the cursor, with the positions of the words that it came from.
  No menu item writes the full program as a Prolog file.

## See also

- In this documentation:
  - [s(CASP) on Logical English](../reference/scasp.md): [select the engine](../reference/scasp.md#1-choosing-the-engine), [the mapping](../reference/scasp.md#4-le-construct--scasp-mapping), [constraints, worlds and abduction](../reference/scasp.md#5-answers-constraints-multiple-models-abduction), [what LE refuses](../reference/scasp.md#8-unsupported-constructs--issues-errors), [read s(CASP) back](../reference/scasp.md#14-reading-scasp-back-september-2026);
  - [Other systems: importing and exporting](index.md): [open a file](index.md#opening-another-systems-file), [what LE could not translate](index.md#what-could-not-be-translated), [Show the Original](index.md#show-the-original), [refusals](index.md#when-an-export-is-refused), [the twins](index.md#the-migration-twins-among-the-examples);
  - [Blawx](blawx.md), which makes s(CASP) and has its own translator;
  - the language reference: [integrity constraints](../reference/language.md#33-integrity-constraints-it-must-not-be-true-that-), [aggregates](../reference/language.md#5-aggregates), [Prolog resources](../reference/language.md#141-prolog-resources-pl), [tests and expectations](../reference/language.md#12-testing-and-expectations);
  - [the editor guide](../guide/editor.md#advanced-features) (the engine picker, See s(CASP), See PROLOG, the debugger);
  - [the Contract Assistant](../guide/assistants.md#the-contract-assistant). Its residue mode translates residue blocks.
- In the LPS2 IDE: [integrations](https://lps2.logicalcontracts.com/docs/user/integrations/index).
- The documentation of s(CASP) and of LE1:
  - [s(CASP) for SWI-Prolog](https://github.com/SWI-Prolog/sCASP);
  - [LE1, the first Logical English](https://github.com/LogicalContractsOrg/LogicalEnglish).

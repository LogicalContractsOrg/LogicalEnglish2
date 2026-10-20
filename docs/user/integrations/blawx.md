# Blawx and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-10-14)*

Blawx is a tool that runs in a web browser. You use Blawx to write law as rules that
a computer can follow. Jason Morris of Lexpedite wrote Blawx. An author pastes the
legislation into Blawx, in a simple marked-up text that gives numbers to the
sections. Then the author encodes each section: the author moves blocks together on
the screen. The blocks are categories, attributes, relationships, rules, exceptions
("section 4 overrides section 3"), and tests. Blawx changes these blocks into
s(CASP), and uses s(CASP) to answer the tests. (s(CASP) is a reasoning language that
is related to Prolog.)

**Which versions.** The translator reads projects of **Blawx version 1**. Blawx
version 1 is the open-source release that its user installs and runs. Its last
version is 1.6.22-alpha, of October 2023. Blawx 2 and 3 are the hosted versions at
app.blawx.dev. These versions keep each project inside the service, and do not give
a file to export. Thus at this time there is nothing that **File ▸ Open…** can read.
Projects of these versions are not supported.

The translation goes in one direction only, into Logical English. **File ▸ Open…**
(or **File ▸ Import from Another System…**) reads a Blawx project. The project can be
a `.blawx` file that you exported from Blawx. It can also be the YAML file of one of
the example projects of Blawx. YAML is a plain-text format for structured data. You
can upload each of these files alone or inside a zip file. The result is a Logical
English program in the words of the Act itself. Each rule cites the section that it
came from. The text of the Act stays next to the program. The tests of the project
become scenarios. (A scenario is a set of facts about one case.) The scenarios expect
the answers that Blawx itself gives. Nothing writes a Blawx project back out. The
translator is a part of the Logical English Translators. Thus only the installations
that have the translators give this function. The hosted service is one of these
installations. The translations of the example projects of Blawx, the *twins*, come
with each installation.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [Opening a Blawx project](#opening-a-blawx-project)
  - [The sections, cited](#the-sections-cited)
  - [The tests, as scenarios](#the-tests-as-scenarios)
  - [The Act's view](#the-acts-view)
  - [The example twins](#the-example-twins)
- [How Blawx maps to Logical English](#how-blawx-maps-to-logical-english)
  - [Exceptions: Blawx's defeasibility](#exceptions-blawxs-defeasibility)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| Blawx version 1 → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | `.blawx`, `.yaml`, `.yml`, or a `.zip` that contains one of them | the rules of the Act in the words of the sentence forms of Blawx, each with a citation of its section; facts with a citation of their section; constraints; the tests of the project and the cases that the translator writes from each rule, as scenarios; a view; a ledger; the text of the Act in `sources/` | the answers of Blawx itself: the reasoner of Blawx runs on the project and answers each test and each generated case |
| Logical English → Blawx | none | — | — | — |

## How to use it

### Opening a Blawx project

Do these steps:

1. In Blawx, export the project as a `.blawx` file. The YAML files of the example
   projects of Blawx are also correct as they are. A `.zip` that contains one of
   these two kinds of file is also correct.
2. Select **File ▸ Open…**.
3. Select the file. The editor reads a file as Blawx when the file contains a
   `blawx.ruledoc`. A `blawx.ruledoc` is the rule document of Blawx.

The program opens in a new tab. A note gives the counts from the ledger. The ledger
is the record of how the translator translated each part of the project. The note
also gives the comparison with Blawx, for example *rps: 17 ledger elements encoded,
3 approximated, 0 residue; 0 writer errors; Blawx's tests and the generated cases:
11 pass, 0 fail, 0 errors.*

The header of the program gives the name of the project and the number of sections
in the project. **Misc ▸ Run the Program's Tests…** runs the scenarios.

**File ▸ Show the Original…** shows a list with the project file and the text of the
Act, `sources/<name>.md`. The ledger, `<name>.ledger.md`, has one row for each part
of the encoding. The parts are each category, rule and test, the clock, and the
lines that Blawx adds to each project. Each row gives one of three results for its
part:

- *encoded*: translated, and the meaning did not change.
- *approximated*: translated, with a note about the change.
- *residue*: not translated.

The answers that the scenarios expect come from the reasoner of Blawx. The server
runs that reasoner on the project. To run the reasoner, the server needs three
things:

- The preamble of Blawx. The preamble is the block of rules that Blawx puts before
  each project. The server downloads the preamble.
- Python with the PyYAML package.
- The s(CASP) library of SWI-Prolog.

If the reasoner cannot run, the scenarios have no expected answers. A second note
tells which of the three things is missing.

### The sections, cited

The program cites two documents, the Act and the project:

```le
the text of the Rock Paper Scissors Act is at "sources/rps.md".

the text of the Blawx project is at "sources/rps.yaml".
```

Each rule has the name of its section and cites that section. Each fact that a
section encodes also cites the section:

```le
rock beats scissors, as stated in the Rock Paper Scissors Act at section 3 a.

rule section_4 with provenance the Rock Paper Scissors Act at section 4:
the winner of a game is a player if
    the game is a game
    and the player is a player
    ...
    and the sign beats the second sign.
```

Right-click a citation in the editor. The menu shows **View Original Text**. This
item opens the text of the Act. In an explanation, and in the executive view, a step
that cites a section shows a § badge. The badge opens the passage. Thus, when you
read a rule in Logical English, the words of the Act that the rule encodes are always
one click away.

### The tests, as scenarios

Each Blawx test becomes a scenario with the same name. The scenario contains the
facts and the comments of the test. The query of the scenario expects the answer
that Blawx gave:

```le
scenario pingu_on_plane_can_fly is, as stated in the Blawx project at test pingu_on_plane_can_fly:
    % Pingu can fly, because section 2 applies, because
    % section 3 would defeat it, but section 4 defeats
    % section 3. Also, section 4 applies on its own.
    pingu is on a plane.
    pingu_on_plane_can_fly expects answers ["pingu can fly"].
```

Most of the example tests state no facts. The reason is that these tests are only
starting points for a person who works in the scenario editor of Blawx. Thus the
translator writes its own cases from the rules. Blawx answers these cases in the same
way (`case_1`, `case_4_without_fact_1`, and other cases). For each rule, there is
one case that satisfies all the conditions of the rule. In that case, the
individuals have the names of their types (`penguin_a`). The numbers are exactly at
the limit of the comparisons that the rule makes.

Next to that case are the near misses. Each near miss does not include one fact, or
misses one comparison by one. A rule that has exceptions also gets one case for each
exception, with that exception added. There are a maximum of 10 cases for a rule and
90 cases for a project. Each of these scenarios cites
`the case analysis of the encoding at section …`.

Sometimes the translator can see that a test does not do what its name or its
comment says. Then the scenario tells this in a `NOTE`. The scenario still expects
the answer that Blawx gives (refer to [Traps](#traps)).

### The Act's view

Each program ends with a view with the name `the act`. A view is a screen that shows
the program in a form for its users. Do these steps:

1. Select **Misc ▸ Open Executive View**.
2. Select the view in the **Views:** strip.

The view shows the facts of the case and the answer to the question that most of the
sections conclude. For the Bird Act, this question is *which thing can fly*. The view
also shows the reasons for the answer, the sections that it cites, and a flip. A flip
shows what must change for the answer to change. When the answer is no, *Why not*
gives the list of the conditions that the case did not satisfy. Each condition has
the section that it comes from.

### The example twins

The translator translated all fifteen example projects of Blawx (Blawx
v1.6.22-alpha, MIT licence). The translations, the twins, are among the examples
under `migration/blawx/`. To open a twin, select **File ▸ Open example from
server…**:

| Twin | Project |
|---|---|
| `bird` | the New Bird Act: sections that defeat each other |
| `rps` | the Rock Paper Scissors Act |
| `r34` | Rule 34 of the Legal Profession Professional Conduct Rules: 42 rules, 17 defeats |
| `oasa` | the Old Age Security Act |
| `beard_tax`, `covid_test`, `mortality`, `net30`, `siblings`, `wills`, `wills_tutorial` | smaller examples: categories, dates, relationships |
| `logical_constraints`, `numerical_constraints` | the constraints of Blawx |
| `life_act`, `list_demo` | events and lists, kept as residue |

Each expected answer that runs passes: 163 expected answers on 15 September 2026.
Twenty-one more expected answers are comments and do not run. Each of these comments
gives its reason.

## How Blawx maps to Logical English

| Blawx generates | Logical English |
|---|---|
| a category, `#pred C(X) :: '@(X) is a C'` | `*a thing* is a C` |
| an attribute or relationship with its `#pred` sentence | a template in the words of the sentence, with typed slots in the order of the sentence; the possessive form of Blawx, `@(X) 's facial hair is …`, becomes `the facial hair of *a person* is …` |
| `according_to(Section, P, …) :- Body` | a rule that concludes P, with a label and a citation: `rule section_4 with provenance the … Act at section 4:` |
| `holds`, the connections of `according_to`, and their `% BLAWX CHECK DUPLICATES` copies | nothing: they become part of the rules |
| a rule that other sections defeat | the rule with a guard: `and it is not the case that the thing cannot fly under section_3` |
| a conclusion that a different rule reads for each section | a separate template, `*a thing* can fly under *a provision*`, and a rule that connects it to the plain conclusion |
| `-P(…)`, classical negation | the opposite form of P: `; opposite: *a thing* cannot fly` |
| facts in a section | facts that cite the section |
| `#abducible` in a section | `; assumable` |
| `false :- Body` | an integrity constraint, `it must not be true that …` |
| comparisons of numbers, dates, durations | comparisons |
| `date_add` | an assignment (`M = T - N`) |
| `date(T)`, `datetime(T)`, `duration(T)` | the number T: seconds since 1970, as Blawx keeps them |
| `blawx_today`, `blawx_now` | a fact about the day when the translator made the twin (*approximated*) |
| `blawx_as_of`, `blawx_during`, `blawx_not_interrupted` standard text | not included, but counted in the ledger |
| events: `blawx_becomes`, `blawx_initially`, `blawx_ultimately` | a residue block for each section |
| `findall` over the lists of Blawx | residue |
| the facts of a test and `?- query.` | a scenario and a query, which expect the answer of Blawx |

### Exceptions: Blawx's defeasibility

In Blawx, one section can override a different section. (This property is
defeasibility.) The translator writes an override as plain Logical English rules.
The rule that can be defeated gets one more condition. The condition says that the
rules that can defeat it are not true. Each defeating rule concludes under its own
section. Thus the program can tell which section a conclusion comes from. This is the
New Bird Act:

```le
rule section_2 with provenance the New Bird Act at section 2:
a thing can fly if
    the thing is a bird
    and it is not the case that the thing cannot fly under section_3.

rule section_3 with provenance the New Bird Act at section 3:
a thing cannot fly under section_3 if
    the thing is a penguin
    and it is not the case that the thing can fly under section_4
    and it is not the case that the thing can fly under section_5.

% What section 3 concludes holds.
rule section_3_conclusion with provenance the New Bird Act at section 3:
a thing cannot fly if
    the thing cannot fly under section_3.
```

In the examples of Blawx, the overriding sections always conclude different things,
`can fly` against `cannot fly`. They never give two different values for one
conclusion. No defeat ever comes back in a circle. Thus you can put the rules in
layers, where each layer only negates a lower layer. Thus the twins give the same
answers as Blawx under the usual Prolog engine of Logical English. They do not need
s(CASP). A project where the defeats come back in a circle needs
`the target language is: scasp.` ([s(CASP)](scasp.md)).

## Traps

- **The expected answers are the answers of Blawx, with its mistakes.** A twin
  follows the encoding, not the meaning of the Act. In the New Bird Act, section 5
  says "…, except for pingu". But Blawx never connects that exception to the rule.
  Thus Blawx answers that pingu with a jetpack can fly. But the name of the test is
  `pingu_with_jetpack_cant_fly`. The twin expects the answer of Blawx, and tells this
  in a `NOTE`. The twin has the fact
  `section_5 does not apply to pingu under section_5_pingu`, but no rule reads this
  fact. The verifier gives a warning about it.
- **Without the reasoner of Blawx, there are no expected answers.** Sometimes you
  open a project on a server that cannot run the reasoner. Then the scenarios have
  their facts, but no `expects answers` lines. The generated cases also expect
  nothing. All the counts are then zero. The second note gives the reason: the server
  did not download the preamble, or PyYAML is missing, or s(CASP) is missing.
- **Abductive tests and answers that are not values wait, and do not run.** A test
  can let s(CASP) assume its own facts (`#abducible`). Such a test gets these
  assumptions back from Blawx. But a Logical English scenario states a fact or does
  not state it. Some answers come back as a variable or a constraint, and not as a
  value. LE keeps these expected answers, and the expected answers of abductive
  tests, as `% pending —` comments. Each comment gives its reason.
- **Dates are counts of seconds.** Blawx keeps a date as the number of seconds since
  1970. The twins keep the dates in that form (`bob was born on 946710000`). Such a
  date is an instant in time, not a day. For the date rules of Blawx, a date in a
  different form (`datetime(2000,1,5,0,0,0)`) is not a number. Such a date fails in
  Blawx and also in the twin.
- **Today does not change.** `blawx_today` becomes a fact that states the day when
  the translator made the twin. But Blawx answers with the day when you run it.
  Change that fact before you run a test that depends on the date.
- **Events and lists stay as residue.** The event calculus of Blawx (the Life Act)
  and its aggregates over lists (the Lists Demonstration) stay word for word inside
  `% RESIDUE` blocks. A value that events change belongs in a program in Logical
  English for LPS, or in the periods of the temporal library.
- **Rules that the reasoner of Blawx never applies.** Two kinds of rule stay as
  residue. The first kind calls predicates that Blawx v1.6.22 never defines (the
  `datetime_add` and `not_after` of the OAS Act). The second kind is clauses that
  Blawx wrote in a form that its own reasoner cannot read (paragraphs 4 and 5 of Rule
  34). Each block tells that the rule never applies in Blawx either. The answers
  stay the answers that the Act gives without these rules, exactly as in Blawx.
- **LE does not include a rule that defines a thing from itself.** Section 9(a) of
  Rule 34 defines `business` with `business`. The definition adds nothing. In
  s(CASP), it makes the predicate fully empty. The twin does not include that
  definition, and the ledger tells this.
- **Constants that end in `_<digits>`.** s(CASP) reads `bob_1` back as `bob`. Thus
  `bob_1` and `bob_2` are the same individual. For this reason, the generated cases
  use `person_a` and `person_b`. Use names of that form in your own scenarios when
  you want to compare answers with Blawx.
- **Constraints can make a case that has no answer.** The Logical Constraints example
  gives Bob two ages at the same time, and a constraint prohibits exactly that. As in
  Blawx, the case gives no answer. The explanation of the empty answer is the
  constraint itself.
- **The words follow the sentence forms of Blawx.** These forms are the words that
  the author wrote in the blocks. Sometimes these words are not elegant. For example,
  the category guards of Rule 34 are on separate lines, and the words *the EA* from
  its template come into the sentences. Constants that are names of sections keep
  their underscores (`section_3`, `s3_1_a`). If not, Logical English breaks the name
  at the bracket.
- **Not read:** the data of the scenario editor of Blawx, its interview, and the
  Akoma Ntoso documents that it writes. The program cites the Act as marked-up text,
  and the citations point to the sections.
- **No way back.** Nothing writes Blawx blocks. **See s(CASP)** writes the program
  as s(CASP), the language that Blawx itself generates. But an s(CASP) program is
  not a Blawx project.

## See also

- In this documentation:
  - [Other systems: importing and exporting](index.md): [opening a file](index.md#opening-another-systems-file), [what could not be translated](index.md#what-could-not-be-translated), [Show the Original](index.md#show-the-original), [the twins](index.md#the-migration-twins-among-the-examples);
  - [s(CASP), Prolog and Logical English](scasp.md), the language that Blawx generates; [LegalRuleML](legalruleml.md), where the translator writes defeasibility in the same way;
  - the language reference: [rule labels and provenance](../reference/language.md#155-rule-labels-and-provenance), [provenance trailers](../reference/language.md#171-provenance-trailers-and-judged-templates), [integrity constraints](../reference/language.md#33-integrity-constraints-it-must-not-be-true-that-), [views](../reference/language.md#1710-views-how-a-screen-shows-a-program), [testing and expectations](../reference/language.md#12-testing-and-expectations);
  - [the executive view](../guide/executive-view.md#views) and [why not](../guide/executive-view.md#when-there-is-no-answer-why-not); [LE Views](../tutorials/views.md);
  - [the Contract Assistant](../guide/assistants.md#the-contract-assistant). Its residue mode translates residue blocks;
  - [s(CASP) on Logical English](../reference/scasp.md).
- In the LPS2 IDE: [integrations](https://lps2.logicalcontracts.com/docs/user/integrations/index).
- The documentation of Blawx itself: [Blawx on GitHub](https://github.com/Lexpedite/blawx) (source, README and the example projects).

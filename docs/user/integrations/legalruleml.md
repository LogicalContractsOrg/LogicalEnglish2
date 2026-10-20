# LegalRuleML and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

LegalRuleML is a published standard to write legal rules (LegalRuleML Core
Specification 1.0, 2021, from the OASIS standards body). A LegalRuleML document
is in XML. XML is a way to mark text, so that a program can read it. LegalRuleML
adds to an older rule language, RuleML, the items that legal rules need. These
are the items of LegalRuleML:

- *constitutive* statements, which define concepts;
- *prescriptive* statements, which state the obligations, permissions and
  prohibitions of a bearer. The bearer is the party who must do a thing, who
  can do it, or who must not do it;
- defeasible rules, which a different rule can override;
- defeaters and overrides;
- reparations and penalties for violations;
- links to legal sources;
- alternative interpretations of one provision.

LegalRuleML is only a way to write rules. No program runs a LegalRuleML
document, and a document has no tests.

Logical English reads LegalRuleML, and also writes it. **File ▸ Open…** (or
**File ▸ Import from Another System…**) reads a `.lrml` document. It also reads
an `.xml` document if the outermost element is `lrml:LegalRuleML`. It changes
the document into a Logical English program. The program uses the deontic
library. The deontic library is the set of sentences that comes with Logical
English, for obligations, permissions and prohibitions. **File ▸ Export to
Another System…** writes a Logical English program back as a LegalRuleML
document. It uses the shorter of the two layouts of the standard. Possibly the
program says a thing that LegalRuleML cannot say. Then the editor refuses to
write the document. It tells you each problem, with its line. The two
translators are a part of the Logical English Translators. Thus only the
installations that have the Translators give them, for example the hosted
service. Every installation has the translations of the examples of the
specification. These translations have the name *twins*.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [Opening a LegalRuleML document](#opening-a-legalruleml-document)
  - [The specification's examples](#the-specifications-examples)
  - [Exporting a program to LegalRuleML](#exporting-a-program-to-legalruleml)
  - [When the export is refused](#when-the-export-is-refused)
  - [Programs in Logical English for LPS: norms](#programs-in-logical-english-for-lps-norms)
- [How LegalRuleML maps to Logical English](#how-legalruleml-maps-to-logical-english)
  - [Defeasibility](#defeasibility)
  - [The way back](#the-way-back)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| LegalRuleML → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | `.lrml`, or `.xml` with a `lrml:LegalRuleML` root; compact or normalized serialisation | rules, facts, obligations, permissions and prohibitions (the deontic library, `deontic.le`, adjacent to the program), exceptions as conditions, legal sources as documents, a ledger | for the examples of the specification: the answers of SPINdle (a reasoner for defeasible deontic logic) on scenarios that a person wrote from the examples |
| Logical English → LegalRuleML | **File ▸ Export to Another System…** | writes `<program>.lrml` | a Statements block of rules (constitutive or prescriptive, each with its Logical English as the paraphrase), the facts, legal sources, the facts of each scenario | the round trip on the English examples of LE2: a program that LE exports and opens again gives the same rules, facts and scenario facts |

The LPS2 IDE is the integrated development environment, or editor, for LPS
(Logic Production System). The LPS2 IDE has the same two menu items, **File ▸
Open…** and **Misc ▸ Export to another system…**. These items use the same two
translators, when the adjacent Logical English installation has them.

## How to use it

### Opening a LegalRuleML document

Do these steps:

1. Select **File ▸ Open…**.
2. Select the `.lrml` file.
3. Read the note in the new tab.
4. Select **File ▸ Show the Original…** to see the LegalRuleML document.
5. Write a scenario with the facts of a case.
6. Ask the program a question.

In step 2, the editor reads an `.xml` file as LegalRuleML when the outermost
element of the file is `lrml:LegalRuleML`. The standard permits two layouts for
a document. The translator reads the two layouts in the same way.

After step 2, the program opens in a new tab, with the deontic library
`deontic.le` adjacent to it. The note of step 3 gives the counts from the
ledger. The ledger is the record of how LE translated each part of the
document. An example is *ex5_section29new: 13 source elements encoded,
0 approximated, 4 residue; 0 writer errors; …*.

The editor keeps the LegalRuleML document in the `sources/` folder of the
program. The ledger, `<name>.ledger.md`, gives a list of all the elements of the
document. Each element is *encoded* (translated, with the same meaning),
*approximated* (translated, with a note about the change) or *residue* (not
translated).

A LegalRuleML document holds no tests. Thus the new program has no scenarios.
That is the reason for steps 5 and 6. The templates of the deontic library
answer the usual questions:

```le
query prohibitions is:
    which party is forbidden that which sentence.

query violated_prohibitions is:
    the prohibition of which party that which sentence is violated.

query breaches is:
    which party is in breach.
```

A document that you wrote gets its English wording from its relations. If a
`ruleml:Rel` element has text, the translator uses that text. If it has no
text, the translator makes a wording from the name of the relation. For
example, `engageCreditActivity` becomes `*a thing* engages credit activity`.
The ledger marks such a wording as *approximated*. Edit these templates, so
that they tell what the relation really means.

### The specification's examples

LE translated all the examples of the LegalRuleML Core Specification. The
translated programs, the twins, are in the examples, in
`migration/legalruleml/`. To open a twin, select **File ▸ Open example from
server…**:

| Twin | What it shows |
|---|---|
| `ex5_section29new` | section 29 of the National Consumer Credit Protection Act 2009 of Australia: a prohibition, a permission that overrides it, penalties, a chain of reparations |
| `ex12_usc_17_504_context` | 17 USC 504 in three historical versions: a prohibition, statutory, increased and reduced damages, overrides |
| `ex3_deontic` | obligations, permissions, reparations, compliance, overrides between statements |
| `ex8_defeasible`, `ex8b_defeasible`, `ex8c_defeasible` | defeaters, strict and defeasible strength |
| `ex9b_alternatives` | alternative interpretations of one provision |
| `ex1_curies`, `ex2_references`, `ex9_alternatives`, `ex10_mix`, `ex11_maternity_alternatives` | structure only: CURIEs, references, metadata, the alternatives of the Italian maternity benefit |

The specification has no tests. Thus a person wrote the scenarios in the twins.
The person used the plain-English paraphrases in the examples, and the law that
the examples encode. The answer that each scenario expects is the answer of
SPINdle on the original document. SPINdle is a reasoner for defeasible deontic
logic. That is, it reasons about duties that other rules can override.
**Misc ▸ Run the Program's Tests…** shows that the twins give the same answers.
If you open one of the documents of the specification with **File ▸ Open…**,
you get the same wording and the same scenarios as its twin.

### Exporting a program to LegalRuleML

Do these steps:

1. Open the program, for example `citizenship` or one of the LegalRuleML twins.
2. Select **File ▸ Export to Another System…**.
3. Read the notes in the window that opens.
4. Click **Copy** or **Save…** to keep the document.
5. Open the exported document again with **File ▸ Open…**.

The menu of step 2 gives LegalRuleML for each program that has a rule or a
fact. The window of step 3 shows the document. The notes in the window tell
which parts change their meaning in the export. The first note says: *the
scenarios' facts are exported (Statements blocks `scenario-<name>`); the queries (flip queries included) and expected answers are not: LegalRuleML has no queries*.

The other notes are about three more items:

- A `; judged` or assumable template. In Logical English, such a template keeps
  open an instance that the case does not state. A program that reads the
  LegalRuleML document thinks that the same instance is false.
- The provenance trailers, which tell the origin of a fact.
- The sections of the decision skeleton.

None of these three items changes what the rules conclude from the facts that
the case states. The exporter also writes the same notes into the document, as
`lrml:Comment` elements.

In step 5, the original wording comes back. The reason is that the exporter
writes the text of each relation as the Logical English template that it came
from.

No public web site runs LegalRuleML documents. Thus this window has no button
to try the document in a different place.

### When the export is refused

When the program says a thing that LegalRuleML cannot say, the editor writes no
document. A window with the title *Not translated to LegalRuleML …* gives a
list of the problems. Each problem is adjacent to its line
([refusals](index.md#when-an-export-is-refused)). The editor refuses these
items:

| In the program | Message (abridged) |
|---|---|
| an aggregate (`the count of each …`, `the sum of each …`) | *a rule for "…" uses count/3, which LegalRuleML cannot state* |
| a universal (`for all cases in which …`) | *… uses a universal (for all cases in which)* |
| a decision table | *the decision table …: LegalRuleML has no tables (write its rows as rules to export them)*, at the line of the table |
| an integrity constraint (`it must not be true that …`) | a problem at the constraint |
| a template that a service answers (`; via service …`), or a built-in semantic template | *the template "…" is answered by the service … at run time: LegalRuleML has no services*, at the line of the template; *… uses a semantic template answered by a service*, at the condition |
| a value that has parts (a structured term) | *a structured value (…): LegalRuleML could only name it* |
| `according to` in a condition (a source-scoped proof), also inside `it is not the case that` | *… uses `according to` (who holds a condition true), which LegalRuleML cannot state*, at the `according to` |
| a different condition with no LegalRuleML form: `prolog` goals, the date built-ins of LE | *… uses <name>/<arity>, which LegalRuleML cannot state*, at that condition |
| a fact that it cannot state | *a fact LegalRuleML cannot state: …*, at the fact |
| in a program for LPS, the default of a fluent (`; 0 by default`) | *a fluent's default value: LegalRuleML has no defaults*, at the template |

You can make two refusals occur yourself:

- `migration/miniscript/core_2of3_multisig`: its spending rule counts
  signatures. The Miniscript exporter writes the same program.
- `regulatory/eu261_integration`: its decision table `article_7`. Also, a rule
  with the condition
  `it is not the case that the cancellation of the flight is due to extraordinary circumstances according to the carrier`.
  That condition uses a source-scoped proof. A source-scoped proof is a proof
  that is true only for the named party. The message gives the
  `according to`, and points to the line of the `according to`. The message
  about the table points to the line of the table. LE exports plain negation,
  as `Naf`. The reported problem is always the innermost part that LegalRuleML
  cannot state.

### Programs in Logical English for LPS: norms

The translator can also read a program in Logical English for LPS as a set of
norms. Such a program starts with `the target language is: lps.`. These are
the changes:

- A reactive rule becomes an obligation of the party who acts.
- A constraint on an action becomes a prohibition of that action.
- A causal law becomes a constitutive rule from the event to its effect.
- The initial state becomes facts.

LegalRuleML says nothing about time. Thus a note tells that the export does not
keep the times when each norm is true. The translator refuses the items that
have no corresponding norm. These items are a composite event, a goal, the
default value of a fluent, a constraint between two actions or with no action,
and a consequence that is not an action.

The two editors give LegalRuleML for such a program, if the program has items
other than declarations to read as norms. In the LPS2 editor, the menu item is
**Misc ▸ Export to another system…**, adjacent to Daml. The **Legal View** is a
second way to read an LPS program. The Legal View shows the permissions and
effects of the program in Logical English
([the editor guide](../guide/editor.md#advanced-features)).

## How LegalRuleML maps to Logical English

| LegalRuleML | Logical English |
|---|---|
| `ConstitutiveStatement` | a rule, with the key of the statement as its label: `rule ps1:` |
| `FactualStatement` | a fact |
| `PrescriptiveStatement` with `Obligation`, `Permission`, `Prohibition` (a `Right` is a permission) | a rule that concludes the library template `*a party* is obliged / permitted / forbidden that *a sentence*`; the party is the `Bearer`; if there is no bearer, the party is the subject of the sentence |
| `Naf` | `it is not the case that` |
| `Neg` of a relation that a rule concludes | a separate relation, with a negative wording (`*a thing* is not a rel3`) |
| `Neg` of a fact of the case | `it is not the case that` |
| `SuborderList` | a chain: LE concludes each element when the element before it is violated |
| `Violation`, `Compliance` of a statement | the library templates `the obligation (prohibition) of … that … is violated`, `… complies with the obligation that …` |
| `Reparation` with its `PenaltyStatement` | rules that conclude the obligations of the penalty from the violation that it repairs |
| `Override`, defeasible strength, `Defeater` | conditions on the defeated rule (below) |
| `LegalSources`, `References` | documents: `ls1 is published at "http://www.comlaw.gov.au/…"` |
| `Association`, `Context` | the rules of its targets cite the source: `rule ps1 with provenance ls1:` |
| `Paraphrase` | a comment above the rule |
| `Authority`, `Jurisdiction` | a comment in the header |
| `TemporalCharacteristics` (start and end of a status) | `the relevant date is a date D and D is on or after the start and before the end` |
| `Alternatives` | the rules of each alternative are true when `the interpretation adopted is` that alternative |

This is section 29, from the twin `ex5_section29new`. The chain of reparations
becomes one rule for each step:

```le
rule ps1:
a party is forbidden that the party engages in a credit activity if
    the party is a person
    and it is not the case that the party holds a credit licence.

rule reparation_1_2:
a party is obliged that the party is imprisoned for 2 years if
    the prohibition of the party that the party engages in a credit activity is violated
    and the obligation of the party that the party pays 200 penalty units is violated.
```

Each translated program includes the deontic library, `deontic.le`. The library
tells when a statement is violated:

- An obligation is violated when its sentence is not the case.
- A prohibition is violated when its sentence is the case.
- A party is in breach when one of the obligations or prohibitions of that
  party is violated.

The same library is in the `lib/` folder of LE2
([shipped libraries](../reference/language.md#142-shipped-libraries-lib)). Any
program can include the library.

### Defeasibility

Logical English has no defeasible rules. Thus the translator writes defeat as
ordinary conditions. Think of a defeasible rule that a different statement
overrides. Or think of a defeasible rule that a different statement attacks,
because it concludes the opposite, and no order between the two is set. Such a
rule is true only when the attacking statement does not apply. Sometimes the
attacking statement is about specified individuals. Then the translator gives
the statement a name, and states its conditions one time. This is the twin
`ex3_deontic`:

```le
rule ps1:
y is forbidden that x is not a rel3 if
    ...
    and it is not the case that the statement ps2_1 applies
    and it is not the case that the statement ps2_2 applies.

% when ps2_1 applies, the rules it overrides or attacks do not
the statement ps2_1 applies if
    ...
```

A defeater concludes nothing of its own. LE writes a defeater in that same
shape, `the statement cs2 applies if …`. Each rule that the defeater attacks
has the negation of that sentence. Nothing attacks strict rules. Possibly the
document does not tell the strength of a rule. Then the translator makes the
rule defeasible if an Override gives its name, and strict if not. Some
attackers are about variables, not named individuals. An example is the tiers
of damages in 17 USC 504. Such an attacker keeps its conditions inside the
exception.

### The way back

In the other direction, the exporter writes each rule as a
`ConstitutiveStatement`. But a rule that concludes an obligation, a permission
or a prohibition of the deontic library becomes a `PrescriptiveStatement`. Each
relation becomes `<ruleml:Rel iri="le:<name>">`, and its text is the Logical
English template. Conditions become `And`, `Or` and `Naf`.

Possibly a negation brings in its own variable, which no earlier part of the
rule fixes. Such a negation becomes `Naf` of an `Exists` that declares the
variable. The reason is that, if not, the variables of a rule apply to the full
rule. A `Naf(p(X1, X2))` alone reads "for some X2, not p". But
`it is not the case that` means "for no X2".

An `otherwise` cascade (`A otherwise B`) goes out in the form that Logical
English makes from the cascade, `Or(A, And(Naf(A), B))`. Each guard gets the
same treatment as the negation above. The paraphrase still shows the
`otherwise`, and the document opens again as the same rule. These are the other
changes:

- Comparisons and arithmetic become the built-in operations of RIF, the Rule
  Interchange Format (`pred:numeric-less-than`, `func:numeric-add`).
- `is a` becomes `rdf:type`.
- A list becomes a `Plex`.
- A sentence that is a value becomes a `Reify`.
- The label of a rule becomes the key of the statement.
- The source that the rule cites becomes a `LegalSource` with an
  `Association`.
- Each scenario becomes a `Statements` block with the name `scenario-<name>`.

Exported rules are strict, with one exception: the named form above,
`the statement … applies`. The named form goes back out as an `Override`
between defeasible rules. A defeater goes back as a `Defeater` statement. That
statement concludes the opposite of what the defeater attacks. Two statements
that defeat each other go back as a conflict with no Override. Thus a twin that
LE exports and opens again gives the same program.

## Traps

- **A document is not a test suite.** LegalRuleML has no queries and no
  expected answers. Thus a document that you open has no scenarios. The twins
  of the specification have scenarios that a person wrote. The expected
  answers of these scenarios come from SPINdle.
- **The closed world of a case.** A fact that the scenario does not state is
  false. Thus `Neg` of a fact that nobody stated is true. LE ran SPINdle with
  that same interpretation. But a different program that reads LegalRuleML can
  think that `Neg` is strong negation. Strong negation must have a proof. It is
  not sufficient that nobody stated the fact.
- **Defeasibility becomes explicit negation.** The exceptions become
  `it is not the case that` conditions. With this form, the exceptions give the
  same answers as SPINdle on all the examples. A cycle of defeats is a rule that
  defeats a rule that defeats it back. Such a cycle makes the negation
  non-stratified. That is, you cannot put the rules in layers where each layer
  negates only a layer below. Then the Prolog engine can go round in circles.
  The verifier gives a warning about such a program
  ([s(CASP)](../reference/scasp.md#1-choosing-the-engine)).
- **Exported rules are strict.** An exception that is a plain
  `it is not the case that` condition goes out as a `Naf` in a strict rule,
  not as an Override. Only the named form (`the statement … applies`) goes back
  as defeasibility.
- **LE does not export queries and expected answers.** LE exports the facts of
  the scenarios, as `Statements` blocks. A scenario fact of the form `X is Y`
  is test data, not a fact of the case. Thus the exporter does not include that
  fact, and a note tells you this.
- **LE exports negation, but not `according to`.** Possibly the
  `it is not the case that` block of a rule holds an `according to`. Then the
  editor refuses the export at the `according to`.
- **An `otherwise` cascade that sets an output** (`… and the rate is 20`).
  The editor refuses it. But the refusal is about the assignment (`le_is/2`),
  not about the cascade. LE exports an alternative that only tests conditions.
- **The editor refuses a full decision table.** To export the rows, write them
  as rules.
- **The wording of your own documents is simple.** If a relation has no text,
  the translator makes its wording from the name of the relation. Thus `rel1`
  gives `*a thing* is a rel1`. LE writes an individual with a name like a
  variable, `X`, in lower case. If not, Logical English reads `X` as a variable.
  Thus a one-letter constant such as `C` comes back as `c` when LE exports the
  document and opens it again.
- **Numbers inside words.** In `ex12_usc_17_504_context`, the damages read
  `between $250 and "$10,000"`. LE writes a figure with a thousands separator
  as quoted text.
- **The examples of the specification do not always agree with each other.**
  `ex12` gives rule keys that `ex12` never defines. Thus its temporal
  characteristics and its strengths apply to nothing (*residue* in the ledger).
  `ex3` violates a statement `ps0` that does not exist (*approximated*).
  `ex12` spells a relation incorrectly in two of its three versions. The
  `rule0` of `ex12` is an Infringer with no conditions. It becomes
  `a person is an infringer.` Thus each person is an infringer, in a correct
  translation.
- **Associations inside a rule**, on an atom or on a deontic formula. LE does
  not keep them. Logical English cites a source one time for each rule. Thus the
  ledger marks such a rule *approximated*.
- **Documents that hold only metadata.** Examples are ex4, ex6 and ex7 of the
  specification, which describe the document and do not state rules. LE reads
  these documents, but they give no rules.
- **Constants of more than one word that contain `and`.** They come back as
  pieces of text when LE exports the document and opens it again. The reason
  is that Logical English reads a quoted constant as text.

## See also

- In this documentation:
  - [Other systems: importing and exporting](index.md): [open a file](index.md#opening-another-systems-file), [Show the Original](index.md#show-the-original), [export](index.md#exporting-to-another-system), [refusals](index.md#when-an-export-is-refused), [the twins](index.md#the-migration-twins-among-the-examples);
  - [Bitcoin Miniscript](miniscript.md), the other exporter for programs without time; [Blawx](blawx.md), which also writes its defeasibility as conditions;
  - the language reference: [shipped libraries (deontic.le)](../reference/language.md#142-shipped-libraries-lib), [rule labels and provenance](../reference/language.md#155-rule-labels-and-provenance), [provenance trailers](../reference/language.md#171-provenance-trailers-and-judged-templates), [decision tables](../reference/language.md#173-decision-tables), [`according to`](../reference/language.md#175-source-scoped-proof-according-to-in-a-rule), [integrity constraints](../reference/language.md#33-integrity-constraints-it-must-not-be-true-that-);
  - [Logical English for LPS](../reference/lps-target.md).
- In the LPS2 IDE: [the IDE guide](https://lps2.logicalcontracts.com/docs/user/guide/ide), [LE for LPS](https://lps2.logicalcontracts.com/docs/user/reference/le-for-lps), [Daml](https://lps2.logicalcontracts.com/docs/user/integrations/daml).
- The documentation of LegalRuleML:
  - [LegalRuleML Core Specification Version 1.0](https://docs.oasis-open.org/legalruleml/legalruleml-core-spec/v1.0/legalruleml-core-spec-v1.0.html) (OASIS Standard, 30 August 2021), with its examples;
  - [the OASIS LegalRuleML Technical Committee](https://www.oasis-open.org/committees/legalruleml/).

# LegalRuleML ⇄ Logical English (Phase 2f)

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on the versions named below, and there is no promise to follow later versions of the other system. The translators' overview is [`../README.md`](../README.md).*

Phase 2f of the design notes `roadmap.md` (§5.8, §8): an XML reader
over the OASIS LegalRuleML Core 1.0 standard, its twins in Logical English
with the **deontic pattern library** (`lib/deontic.le` in LE2 core, N4), an
oracle (SPINdle, the reasoner that the specification acknowledges as the
engine used for testing LegalRuleML), and the way
back: **LE → LegalRuleML**, from the LE editor and from the LPS2 IDE.

| File | What it does |
|---|---|
| `lrml_reader.pl` | a document, compact or normalized (the normalized form's wrapper edges dropped first), → `model(Items)`: statements, rules (strength, if/then, paraphrase), atoms, And/Or/Naf/Neg, Obligation/Permission/Prohibition/Right with Bearer, SuborderList, Violation/Compliance/Reparation, penalties, reparations, overrides, sources, associations and contexts, temporal characteristics, alternatives; keyrefs resolved (a rule or atom takes what it does not restate from the one it names); what a statement's associations give it (`statement_props/3`, `statement_strength/3`, `statement_period/4`) |
| `lrml_twin.pl` | model → migration (`le_migration.pl`): templates, rules, the deontic library, exceptions, provenance, guards, the drafted scenarios' tests (answers from SPINdle), the ledger |
| `lrml_spindle.pl` | the oracle: the document grounded over a scenario's facts, written in SPINdle's DFL, run, and read back |
| `oracle/fetch_spindle.sh` | downloads SPINdle 2.2.4 (copyright 2009-2014 NICTA Ltd.; GNU Lesser General Public License, version 3) from its SourceForge project into `oracle/spindle/` (gitignored: nothing of SPINdle is kept in this repository); needs Java |
| `corpus.pl`, `corpus/oasis/` | the specification's fifteen examples, both serialisations, unmodified (copyright OASIS Open; the specification's Notices section in full in `corpus/oasis/NOTICE.txt`); the reviewer's wording and the drafted scenarios |
| `build.pl` | the twins into `LogicalEnglish2/examples/migration/legalruleml/<example>/` |
| `lrml_export.pl` | LE → LegalRuleML (File ▸ Export to Another System…; Misc ▸ Export in the LPS2 IDE) |
| `roundtrip.pl` | LE → LegalRuleML → LE over LE2's English example corpus |
| `lrml_import.pl` | File ▸ Open of a `.lrml` (or an `.xml` whose root is `lrml:LegalRuleML`), in both IDEs |
| `test_lrml.pl` | plunit: both serialisations read alike, SPINdle's s. 29 answers, every twin passing, the round trip, the LPS export, File ▸ Open |

## How to run

From the LE2 checkout (`/work`), with Java for the oracle:

    migration/legalruleml/oracle/fetch_spindle.sh
    ./myswipl.sh -q migration/legalruleml/build.pl
    ./myswipl.sh -q -g run_tests -t halt migration/legalruleml/test_lrml.pl
    ./myswipl.sh -q -g "consult('migration/legalruleml/roundtrip.pl')" -g "roundtrip:main" -t halt

## The mapping

- **ConstitutiveStatement** → an LE rule; **FactualStatement** → a fact.
  `Naf` → `it is not the case that`; `Neg` of a relation some rule
  concludes → a relation of its own worded negatively (`it is false that …`,
  `*a thing* is not a rel3`); `Neg` of a fact of the case → `it is not the
  case that` (a case states its facts; what it does not state is false —
  SPINdle's reading below).
- **PrescriptiveStatement** → rules concluding the library's `*a party* is
  obliged / permitted / forbidden that *a sentence*` (Right is a permission);
  the Bearer slot is the party, else the one the sentence is about (its first
  argument). A **SuborderList** is a chain: each element is concluded once the
  one before is violated (`the obligation of the party that … is violated`).
  A **Reparation** gives its **PenaltyStatement**'s chain on the violation of
  the statement it repairs (and on the conditions of a rule that concludes
  the reparation, 17 USC 504's pattern). `Violation`/`Compliance` of a
  statement in a condition are the library's violation and compliance.
- **Defeasibility** is written out as conditions (E2's convention, decided on
  Blawx and confirmed here): a defeasible rule that another **Override**s,
  or that a non-strict rule with a conflicting conclusion (forbidden vs
  permitted, obliged vs forbidden, p vs not p) attacks with no order between
  them, holds only when the attacker's conditions do not; the attacker's
  conclusion is lined up with the attacked one where they conflict, else
  their variables are shared by name. A **defeater** concludes nothing: it is
  only such a condition. Strict rules are never attacked (a priority is
  between defeasible rules). A rule whose strength the document does not give
  is defeasible when an Override names it, strict otherwise. An attacker
  about particular individuals (no variables, as in the specification's
  examples) is *named* in the exception — `it is not the case that the
  statement ps2_1 applies` — and its conditions said once, `the statement
  ps2_1 applies if …`, which its own rule then uses; a defeater is such a
  sentence too. Export writes that form back as Overrides between
  defeasible rules, a defeater as a `Defeater` statement concluding the
  complement of what it attacks, and two statements that defeat each other
  as a conflict with no Override.
- **LegalSources / Sources / References** → documents of the program
  (`ls1 is published at "…"`); an **Association** or **Context** gives the
  rules of its targets `rule ps1 with provenance ls1:`. A **Paraphrase** is the
  rule's comment. Authorities and jurisdictions go in a header comment.
- **TemporalCharacteristics** (Starts / Ends of a status) → `the relevant date
  is a date D and D is on or after the start and before the end`.
  **Alternatives** → each alternative's rules hold when `the interpretation
  adopted is` it.
- Names: the reviewer's wording (`corpus.pl`, recorded as such), else the
  wording the `Rel` element gives (its text), else a naive wording of its
  IRI (`engageCreditActivity` → `*a thing* engages credit activity`, flagged
  approximated). An Ind named like a variable (`X`) is lower-cased: LE would
  read `X` as one. The specification's schematic examples write their
  individuals so (`<ruleml:Ind>X</ruleml:Ind>` in a rule closed
  universally): their rules are about the individual x, as SPINdle grounds
  them, and the verifier's "rule without variables" on them is the
  document's, not the translation's. A `Var` is an LE variable.
- **Facts of the case.** A relation the rules read and nothing concludes —
  no rule, no fact, no rule of the deontic library (a permission no
  statement grants, the violation of a statement the document lacks, a
  function it names without defining it, the interpretation adopted) — is
  what a scenario states: its template is marked `; undefined` (a scenario
  element, language.md §2), the library's too, declared again by the twin.
- **Templates** are declared only for what the twin writes (a rule, a fact,
  a query or a scenario uses them): a relation that occurs only as a
  defeater's conclusion, which concludes nothing, or only in a statement
  the translator could not read gets none, and its ledger entry says which.
- **Reviewer's notes** (`corpus.pl`, `ledger_notes`) explain in the ledger
  a verifier warning that is the document's: ex3's loop through negation
  (ps2 overrides ps1, whose reparations oblige what ps2 forbids), ex12's
  rule that makes everyone an infringer.

## The oracle: SPINdle

LegalRuleML ships no tests, and its specification includes no engine: it is
an interchange language. The specification acknowledges SPINdle (Ho-Pun Lam
and Guido Governatori, NICTA), a defeasible (and modal defeasible) logic
prover, as the engine used for testing LegalRuleML. SPINdle does not read
LegalRuleML, so the theory it runs on is this translator's:
`lrml_spindle.pl` reads the document with the same reader as the twin
(`lrml_reader.pl`), grounds it
over a scenario's constants (a base atom of a rule instance must be a fact, so
the theory stays small), writes it in DFL and reads back what is defeasibly
proved (+∂). The reading follows the specification's prose and its worked
example of section 29 (`ps2 > ps1`, penalties as obligations); where the
specification leaves a choice open, the choice is ours, and the twin and the
theory make the same one: strict / defeasible / defeater
rules; Obligation(p) = [OBL] p, Prohibition(p) = [OBL] ¬p, Permission(p) =
[PER] p (OBL and PER declared in conflict), the bearer an argument of the
deontic literal; violation rules; an Override is superiority between the
instances that agree on shared variables, and — where the two conclusions do
not conflict — a defeater of the under rule's applicability; the closed world
of the case (a fact not stated is false; an atom a rule concludes is false by
default below its rules). Two things we observed in SPINdle 2.2.4 shape the
theory: it did not accept a theory of facts alone (a dummy rule is added),
and with literals that carry arguments a defeater of `p(a)` also defeated
`p(b)`, so the theory is written fully ground and propositional
(`p__c1_c2`).

## Results (14 September 2026)

| Twin | Source | Scenarios | Expectations (SPINdle's answers) | Ledger enc/approx/residue |
|---|---|---|---|---|
| `ex5_section29new` | s. 29 of the National Consumer Credit Protection Act 2009 (Cth): prohibition, permission overriding it, two penalties, a three-step suborder list | 4 | 24/24 | 13/0/4 |
| `ex12_usc_17_504_context` | 17 USC 504 in three historical versions: prohibition, reparations with statutory, increased and reduced damages, overrides | 4 | 20/20 | 46/0/14 |
| `ex3_deontic` | deontic elements, reparations, compliance | 1 | 8/8 | 14/11/1 |
| `ex8_defeasible`, `ex8b`, `ex8c` | defeaters, strict and defeasible strengths, keyref templates | 2, 1, 1 | 4/4, 2/2, 2/2 | 6/4/0 each |
| `ex9b_alternatives` | Alternatives: prescriptive vs constitutive reading | 2 | 8/8 | 3/2/6 |
| `ex1_curies`, `ex2_references`, `ex9_alternatives`, `ex10_mix`, `ex11_maternity_alternatives` | CURIEs, references, alternatives, mixed metadata, the Italian maternity-benefit alternatives | — | (structure only: schematic relations, or a function the document does not define) | |

68 of 68 expectations, in the seven twins that have scenarios, reproduce
SPINdle's answers. The section 29 example has the penalties of the Act as
made in 2009 (civil penalty 2,000 penalty units; criminal penalty 200 penalty
units, or 2 years imprisonment, or both), which the Act no longer has. ex4, ex6 and ex7 hold
metadata only and are read, not translated; both serialisations of all
fifteen read to the same model.

**The round trip** (`roundtrip.pl`), LE → LegalRuleML → LE over LE2's 90
English example programs (`examples/moreExamples` and `examples/regulatory`,
16 September): **55 the same** (rules, facts and scenario facts, up to
variable names), 33 skipped — 31 because the exporter refuses them, for what
LegalRuleML cannot state (aggregates, universals, decision tables, Prolog
calls, LE's date and list built-ins, `X is Y` assignments, `according to`,
services, integrity constraints), and 2 that are not Prolog-target programs —
and 2 differ: a multi-word constant with `and` in it comes back a text (the
LE writer quotes it, and LE reads a quoted constant as a text — a writer
limitation shared by every translator), and one program whose `is a` facts
name labels with parentheses.

**The check before the text.** The exporter refuses a program with anything
LegalRuleML cannot state faithfully, listing each with its line
(`check_lrml/3`, registered as le_import's `export_check`): nothing is written
rather than a document without the rule. A rule's problem names the innermost
construct with no LegalRuleML form, at that construct's own position (an
`according to` inside `it is not the case that` is reported as the `according
to`, since the negation alone is a Naf); a decision table's problem has the
table's line; a template answered by a service (`; via service`), which
the document would hold false, has the template's line; an LPS fluent's
default too. What carries no meaning for what the rules conclude (queries,
flip queries and expected answers, a scenario's unstatable test data, the
absence of time in an LPS program's reading, a `; judged` or assumable
template — open in LE, false for a LegalRuleML reader when a case does not
state it —, the facts' provenance trailers, the decision skeleton's sections)
stays a note.

## What the specification's examples taught

The examples illustrate the elements of the standard; they are not complete
models of the laws they cite, and some of their references resolve to
nothing: ex12's Contexts name rule keys (`rule2`, `rule1-tblock1`) the
document does not define, so its temporal characteristics and strengths apply
to nothing, and its third block's override names `rule2-tblock3` while the
rule is keyed `rule2-tblock23`; ex12 also misspells `claimStatutoryDamanges`
in two of its three blocks (the reviewer keeps it a relation of its own, and
the scenarios state both); ex3 violates `ps0`, which does not exist; ex5
names the same reparation twice. The ledger records each (context → residue,
missing statement → approximated). Semantically: whether a Neg of an
unstated fact holds needs a decision (the closed world of the case, taken by
both twin and oracle), and whether an Override between rules whose
conclusions do not conflict means anything (it does, in ex12: the rules are
alternative penalties; both sides read it as the under rule not applying).

## LE → LegalRuleML

`lrml_export.pl` writes the compact serialisation. Each relation is a
`<ruleml:Rel iri="le:F">` whose **text is the LE template**, so the words
travel with the rules and come back; rules are strict Constitutive or (for a
deontic conclusion) Prescriptive statements with the rule's own Logical
English as the Paraphrase; comparisons and arithmetic are RIF's built-ins
(`pred:numeric-less-than`, `func:numeric-add`), types `rdf:type`, lists
`Plex`, a sentence as a value `Reify`; a negation's own variables (bound by
nothing before it: the rule's variables are universal over the whole rule, so
a bare Naf would read "for some") are declared by an `Exists` inside the
`Naf`, which the reader takes back to the same condition — so an `otherwise`
cascade, which LE compiles to `A or (not A and B)`, is exported faithfully as
`Or`/`Naf` with its guards so scoped; provenance becomes LegalSources and
Associations; each scenario a `scenario-<name>` Statements block of facts.
Queries and expected answers are not LegalRuleML's: a note says so. The
exported documents are checked by reading them back (`roundtrip.pl`); they
are not validated against the standard's RelaxNG or XSD schemas, which this
repository does not hold. From the
LPS2 IDE, an LE for LPS program is written as norms — a reactive rule an
obligation of the one who acts, a constraint on an action a prohibition, a
causal law a constitutive rule from the event to its effect — with a note
that the time of events does not carry over (LegalRuleML's temporal
characteristics say when a norm is in force, not when something happens). An LE for LPS program's IR holds only its
templates, so `applies_lrml/1` asks its LPS reading instead: both IDEs' export
menus (`le_import:export_formats/2`, which the LPS2 IDE reaches through its
`export_formats` operation) offer LegalRuleML when that reading has anything
besides declarations.

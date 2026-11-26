# LOMO ⇄ Logical English

*Copyright Miguel Calejo · Apache License 2.0 · published "as is": the tests pass on LOMO 1.1.0 (21 October 2026), and there is no promise to follow later versions of LOMO. The translators' overview is [`../README.md`](../README.md).*

LOMO, the Legal Obligation Metadata Ontology of the European institutions
(`http://data.europa.eu/leg/lomo`, `https://code.europa.eu/drpm/lomo`), is a
vocabulary for *describing* the rules of a legal text: the kind of rule, its
provision (by ELI), its words, its modality, its actions, agents and roles,
its results and its times. It has no conditions, no values and no cases.
This door reads a LOMO description (Turtle) into a Logical English
**register** (one fact per statement, in the words of `lib/lomo.le`), runs
what the description holds, and writes a Logical English program back as a
LOMO description. The plan it follows is the company's research note
`LOMO.md` (§6; not published).

| File | What it does |
|---|---|
| `lomo_words.pl` | the one table of LOMO's words: classes, properties, the word lists, and the templates of `lib/lomo.le` that hold them |
| `lomo_reader.pl` | a Turtle file → statements, each value classified; a name for every thing (the shortest unique ending of its address, in words) |
| `lomo_twin.pl` | statements → the register (Migration IR for `le_migration.pl`): facts, the questions as queries, the ledger |
| `lomo_shacl.pl` | LOMO's validity rules (`shapes/lomo-shapes.ttl`) checked here: an interpreter of the SHACL constraints the shapes use |
| `lomo_gate.pl` | the gates: LOMO's seven search queries on the RDF (rdflib) and on the register; our validity check against pySHACL; the scenario of each register |
| `corpus.pl`, `corpus/lomo-1.1.0/` | the data, ontology, word lists, shapes and queries of the LOMO repository, unmodified (CC BY 4.0, `corpus/NOTICE.txt`) |
| `corpus/spec-examples/` | the 65 Turtle examples of the specification page, with the prefixes they use |
| `corpus/broken/` | three descriptions broken on purpose, for the test of the validity check |
| `oracle/` | the judges: `sparql_judge.py` (rdflib), `shacl_judge.py` (pySHACL); `setup.sh` installs them in `oracle/.venv` |
| `spec_cases.pl` | the agent-written scenarios for the specification's examples and the door's own cases, the answers worked out before the run |
| `corpus/cases/` | descriptions of our own: the probe of the plan (GDPR Article 33, Directive 2013/34/EU Articles 30 and 36), GDPR Article 6, time links that their dates contradict |
| `agent_written/<set>/` | agent-written programs beside the registers of `<set>`: the conditions of GDPR Articles 6(1) and 33(1) and of Directive 2013/34/EU Articles 3, 30, 36(1)(d), 36(7) and 40 |
| `lomo_eli.pl` | the text of a provision from its ELI: the act from the Publications Office's repository (Cellar, by CELEX number), the article, paragraph or point cut out by the ids of its XHTML |
| `lomo_lps.pl` | step 5: a case of a register through time, written as LE for LPS over LPS2's `examples/migration/lomo/lomo_calendar.le`, run by LPS2, compared with the timeless reading |
| `lomo_export.pl` | step 7: Logical English → LOMO (a register written back; other programs' cited rules described), checked by `lomo_shacl.pl` before it is given |
| `lomo_roundtrip.pl` | step 7's gates: every register back to Turtle, compared by rdflib's isomorphism; LE2's examples that cite provisions exported or refused with reasons |
| `lomo_import.pl` | File ▸ Open of a `.ttl` (registered in `../le_importers.pl`, with the exporter) |
| `build.pl` | the registers into `examples/migration/lomo/{examples,other,lfds,spec,cases}/` |
| `CONDITIONS_GUIDE.md` | for agents: how to write the conditions of a description from the legislation it cites, as a full Logical English program |
| `test_lomo.pl` | plunit: the words, the names, every register's scenario, the gates of steps 1, 2, 5 and 7 |

## How to run

From the LE2 checkout:

    migration/lomo/oracle/setup.sh                     # rdflib and pySHACL, once
    ./myswipl.sh -q migration/lomo/build.pl
    ./myswipl.sh -q -g "use_module(migration/lomo/lomo_gate), gate_main" -t halt
    ./myswipl.sh -q -g "use_module(migration/lomo/lomo_gate), shacl_gate_main" -t halt
    ./myswipl.sh -q -g run_tests -t halt migration/lomo/test_lomo.pl

## The register

- **One fact per statement.** `rdf:type` → `<thing> is a substantive rule`;
  a property of the table → its sentence (`… has the modality obligation`,
  `… is established in "<ELI>"`); any other property → the generic form
  `… has for "eli-lo:unit" the value "EUR"` (or `the resource …`), so nothing
  is dropped. A thing with an address has `… is identified by "<IRI>"`.
- **Names.** The shortest ending of the address that no other thing of the
  file has, in words (`…#Norm_PublicationObligation` → `norm publication
  obligation`; `…/analysis/description/1` → `description 1`); an ELI address
  is named whole (`eli dir 2013 34 oj`); a blank node after its owner and the
  property (`step publish full report time`). A name never starts with a
  word LE reserves (`rule`, `the`, `a`, …), never holds a word that joins
  conditions (`and`, `either`, …), and is never one of the words of LOMO's
  word lists.
- **Words of the word lists** (deontic modality, temporal function, result
  category, digital dimensions, and the three roles of the Publications
  Office's authority table) are words: `obligation`, `deadline`,
  `addresser`, `data`. `lib/lomo.le` gives their labels.
- **Literals.** A text keeps its words exactly (a quotation mark is written
  `\"`); the language tag `en` is the default; a property whose texts have no
  tag, or whose values carry another datatype, says so once (`the values of
  "eli-lo:upper_value_limit" have the datatype "xsd:decimal"`).
- **Older words.** The data uses 23 properties and 4 classes that 1.1.0 no
  longer declares; they are read (in their own sentence when the table has
  one, else the generic form) and the ledger names them.
- **Who bears a duty**: `the bearer role is addresser.` (the ontology's
  reading); option `bearer(addressee)` for data made the other way.

## Results (26 November 2026)

**Step 1** — 63 of 63 files read; 63 registers, 0 writer errors, each
passing its scenario (3 questions whose expected answers are rdflib's).
LOMO's seven search queries give the same tables on the RDF and on the
registers: **1,898 rows, 63 of 63 files, 7 of 7 queries**
(requirements 733, data flows 367, data 302, assessment 201, assessment
table 131, public services 87, digital solutions 77). With the specification's
65 examples and our 3 cases: 1,977 rows, 131 of 131 files. The comparison found
two defects of LE2's shared writer, both fixed for every translator: a
quotation mark inside a text came back as `”`, and a space before a comma
inside a text was removed.

**Step 2** — our check of LOMO's validity rules agrees with pySHACL on **131
of 131 files, result by result (166 results)**: the 63 data files (all
valid), the 65 examples of the specification (34 not valid: abbreviated
examples without a label, a provision, an action or an agent role) and the
three broken ones. The specification's example of `lomo:TemporalSpecification`
writes 24 hours as `P24H`, which is not an ISO 8601 length of time
(`PT24H`).

**Step 3 (time)** — `lib/temporal.le` reads ISO 8601 lengths of time
(`P12M`, `P4Y1D`, `PT72H`: hours count as whole days, rounded up, and
`*a duration* counts hours as whole days` says so), rhythms, and dates
without a year; `lib/lomo.le` gives the first and last date of a time
specification, the twelve relations between them, the links that their
dates contradict (`broken_links`), and the timeless calendar. The
specification's time examples run as scenarios with dates worked out by
hand (all pass). On the 11 data files whose deadlines have a value, the
calendar of 2027 agrees with a calendar written in Python with no Logical
English (`oracle/sparql_judge.py`, `calendar`), and each such register
carries it as its scenario `calendar`.

**Step 4 (who is bound)** — parties and their types, definitions that give
the meaning of an agent type, the condition slot of every rule (`the
conditions of R hold for P` holds until a program writes it, and the
explanation says `it is not the case that R has written conditions`),
derogation (a derogating rule sets a rule aside for the parties it
*reaches*: stratified, so no warning, and no chain of derogations), the
deontic sentences of `lib/deontic.le` (with a right and its correlative
duty, added there), and a party's calendar (`must perform … by`, `met`,
`is late with`). The specification's three derogation examples (10 of 10),
GDPR Article 6(1) with its six points and `only if` (6 of 6), and the probe
of the plan from a register the reader wrote (12 of 12) pass.

**Step 5 (LPS)** — `lomo_calendar.le` in LPS2: one-off duties, and
repeating duties (the next occurrence starts when the clock passes the due
time of the current one). Five cases (the probe to two last days, the probe
to the minute, Directive 2013/34/EU, an annual report three times) end in
LPS2 with exactly the open, met and breached duties that the timeless
reading gives for the last day. A date of the case is a number of days, a
moment a number of minutes.

**Hours** — a case that gives the moment of an event (`"2026-03-01T14:30"`)
gets deadlines exact to the minute (`lib/temporal.le`: `the period … after
the moment …`; `lib/lomo.le`: `must perform … by the moment …`, `met … in
time`, `is late with … at …`); with a date only, hours count in whole days,
rounded up, and the answer says so.

**Step 6 (provisions)** — agent-written (Opus 5.5), as asked (no Contract Assistant, no
profile of it): `lomo_eli.pl` gets the text of a provision from its ELI;
the registers of `examples/`, `other/` and `cases/` carry the texts of the
provisions they cite (`sources/eli/`) as documents, so quotations are checked
and File ▸ Show the Original shows them. The conditions programs of `agent_written/`
cite and quote each provision; their cases, with answers worked out from
the text first, pass (GDPR Article 33: 3 of 3; Directive 2013/34/EU: 5 of 5).
Reading the text found that the directive has **no Article 1a**: the
specification's example of `derogatesFrom` and the plan's probe cite one;
the exemption of micro-undertakings is Article 36(1)(d). The description of
the directive in the LOMO repository has the limits of 2013, which
Delegated Directive (EU) 2023/2775 changed.

**Step 7 (the way back)** — every register goes back to Turtle, and rdflib
finds the same graph, blank nodes included (`lomo_roundtrip:main`; the first
run found 28 registers whose values did not fit their property's kind, or
kept a datatype of their own: fixed in the reader and the writer). LE2's
examples that cite provisions, and the LegalRuleML twins, are exported or
refused with their reasons (`lomo_roundtrip:examples`; 99 programs cite their provisions: 93 become valid descriptions (10,894 statements); the other 6 are refused, and the export tells why (a rule cites a document that has no web address)).

**Step 8** — the guide (`docs/user/integrations/lomo.md`, in `nav.json`),
the row of the Migration Gallery, File ▸ Open of a `.ttl` and File ▸
Export ▸ LOMO (`editor/tests/lomo.spec.ts`), the review in the role of a
LOMO annotator (lpsPlus `docs/reviews/LOMO_annotatorReport.md`, with a
message to the LOMO project prepared and not sent), the video script
(lpsPlus `docs/sales/videos/lomo_in_le.cjs`). The browser build packs the
door (`wasm/pack.pl`): the reader, the register, the validity check and the
export use only the Turtle reader of SWI-Prolog, which the WebAssembly image
has; the judges and the download of provisions need Python and curl and are
loaded only when called. Checked on the WebAssembly build of 26 November
2026 (`./wasm/build.sh --skip-editor`, served by `wasm/runtime/serve.mjs`):
`importFormats` offers LOMO alone, File ▸ Open of `corpus/cases/probe.ttl`
opens its register, and File ▸ Export ▸ LOMO writes its 61 statements back.

## Traps

- pySHACL 0.40 never finished when given the ontology as `ont_graph`; the
  judge joins the ontology to the data graph instead (the same union).
- rdflib normalises the lexical form of a duration (`P1W` → `P7D`) unless
  `NORMALIZE_LITERALS` is off.
- A rule of `lib/lomo.pl` must not rely on a cut: LE's reasoner runs those
  clauses itself.
- A query of an included library is not a query of the program: the
  questions are written into each register.
- LE's reasoner runs the clauses of a library's `.pl` itself: no cut, no
  lambda (`yall`) and no other meta-call inside them.
- A template declared in a second `the templates are:` placed among the
  rules is not read, and a negation of its sentence is then always true.
- EUR-Lex answers automated clients with a challenge page; the Publications
  Office's Cellar serves the same act by CELEX number.
- The WebAssembly image of SWI-Prolog has `semweb/turtle` but neither
  `semweb/rdf_db` nor `library(process)`: the door does not load them at
  load time.
- A full build beside another large job was stopped by the memory limit
  (oom_kill); run the build alone.
- A name made of a long label (a sentence) is full of the templates' own
  small words (*of*, *for*, *to*, *the*), and LE's reading of each fact about
  it then explodes: one register needed more than 6 GB to load. Names come
  from addresses, and from a blank node's temporal label only when it has at
  most five words without those words.

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
| `build.pl` | the registers into `examples/migration/lomo/{examples,other,lfds}/` |
| `test_lomo.pl` | plunit: the words, the names, every register's scenario, the two gates |

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
table 131, public services 87, digital solutions 77). The comparison found
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

## Traps

- pySHACL 0.40 never finished when given the ontology as `ont_graph`; the
  judge joins the ontology to the data graph instead (the same union).
- rdflib normalises the lexical form of a duration (`P1W` → `P7D`) unless
  `NORMALIZE_LITERALS` is off.
- A rule of `lib/lomo.pl` must not rely on a cut: LE's reasoner runs those
  clauses itself.
- A query of an included library is not a query of the program: the
  questions are written into each register.

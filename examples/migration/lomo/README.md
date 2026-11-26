# LOMO registers

LOMO, the Legal Obligation Metadata Ontology of the European institutions,
describes the rules of a legal text. A LOMO description says, for each rule:
the kind of rule, the article that makes it, its exact words, whether it
obliges, permits or forbids, which action, done by whom, for whom, with what
result, and when. A description is written in RDF, the data format of the
web. A LOMO description has no conditions and no cases.

Each program here is a **register**: one LOMO description written in Logical
English, one fact for each statement. The library `lomo.le` says what the
statements mean together. The questions of LOMO's requirements document are
the queries of each register.

| Folder | What it holds |
|---|---|
| `examples/` | Imported from the 10 Turtle files of `data/examples/batch_1/` of the LOMO repository: https://code.europa.eu/drpm/lomo/-/tree/cfe522d164a6b6a345269bb1e25624f9ccbc6967/data/examples/batch_1. The LOMO project gives them as example descriptions, one provision each |
| `other/` | Imported from all 7 Turtle files of `data/other/` of the LOMO repository: https://code.europa.eu/drpm/lomo/-/tree/cfe522d164a6b6a345269bb1e25624f9ccbc6967/data/other. The LOMO project calls them pilot descriptions of whole acts (financial reporting, settlement finality, vehicle registration, anti-dumping duties, the Cybersecurity Act 2 proposal, environmental assessments). The folder has these 7 files and no other; none was left out |
| `lfds/` | Imported from all 46 Turtle files of `data/lfds/ttl/` of the LOMO repository: https://code.europa.eu/drpm/lomo/-/tree/cfe522d164a6b6a345269bb1e25624f9ccbc6967/data/lfds/ttl. A program of the LOMO project generated these files from the tables of the Legislative Financial and Digital Statements (LFDS) of Commission proposals of 2025 and 2026 |
| `spec/` | Imported from the 65 Turtle examples of the LOMO specification page, https://drpm.pages.code.europa.eu/lomo/1.1.0/ (each example with the prefixes it uses added) |
| `cases/` | Agent-written: descriptions written by the agent for the tests of the translator (the probe of the plan, GDPR Article 6, time links), and programs that write the conditions of GDPR Articles 6(1) and 33(1) |

## Start here
- [Directive 2013/34/EU, financial reporting](other/financial_reporting_dir_2013_34_lomo_manual.le?query=obligations) — who must publish what.
- [The questions of the description](other/financial_reporting_dir_2013_34_lomo_manual.le?query=deadlines) — the deadlines.

## Try this
1. Open [the financial reporting register](other/financial_reporting_dir_2013_34_lomo_manual.le?query=obligations) and click **Query**. The answers name the rule, the agent and the role of the agent.
2. Change the query to `places`. Each rule shows the article and paragraph that make it.
3. Change the query to `kinds`. Each thing of the description shows its kind.
4. Choose **File > Show the Original…**. The editor shows the LOMO description that the register comes from.

## More
- Written by `migration/lomo/build.pl` of this repository. Do not edit the registers by hand.
- Each imported register (`examples/`, `other/`, `lfds/`) is a translation of its Turtle file, statement by statement, by the translator `migration/lomo/`. Nothing in it is invented; the original is in `sources/` beside it.
- Each register has a scenario, `description`. Its expected answers come from a search over the RDF data with rdflib, not from Logical English.
- `other/directive_2013_34_conditions.le` and the programs `cases/*_conditions.le` are agent-written: the conditions of the rules, from the text of the provisions.
- The verifier says "too many facts" on the larger registers. A register is data: this is expected.
- `NOTICE.txt` in this folder gives the source and the licence of the data.

## Disclaimer
A register is written by a translator (a program that rewrites another
system's data in Logical English), and it is provided **"as is", without
warranty of any kind**, express or implied, including any warranty that it
is accurate, complete or fit for a particular purpose. A translation may be
wrong: check a register against its source before relying on it. A register
is not legal or other professional advice. Its authors accept no liability
for any loss or damage arising from its use. Every register repeats this
notice in its opening comment.

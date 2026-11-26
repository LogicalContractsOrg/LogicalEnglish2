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
| `examples/` | The 10 hand-made examples of the LOMO repository (`data/examples/`) |
| `other/` | 7 hand-made descriptions (`data/other/`): financial reporting, settlement, vehicle registration and others |
| `lfds/` | 46 descriptions made from the digital statements of Commission proposals of 2025 and 2026 (`data/lfds/`) |

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
- Each register has a scenario, `description`. Its expected answers come from a search over the RDF data with rdflib, not from Logical English.
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

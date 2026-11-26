"""The judge of step 1: LOMO's own search queries over the RDF data.

    sparql_judge.py OUT.json CORPUS_DIR FILE.ttl ...

For each data file: a graph of the file, the ontology and its four word
lists (rdflib), and the seven queries of the LOMO repository
(scripts/rdf-to-table/queries/, copied to CORPUS_DIR/queries/). The rows go
to OUT.json: {file: {query: [{column: text}]}}. A value that a query does not
bind is "". Written for the LOMO door of Logical English (migration/lomo);
Apache License 2.0.
"""
import json, os, sys
import rdflib
# The lexical form as written: rdflib would write a duration "P1W" as "P7D".
rdflib.NORMALIZE_LITERALS = False

# The questions whose answers each register's own scenario expects
# (build.pl): who must do what, in LOMO's words.
PREFIXES = """PREFIX lomo: <http://data.europa.eu/leg/lomo#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
"""
EXTRA = {
    'x-modalities': PREFIXES + "SELECT DISTINCT ?rule ?modality WHERE { ?rule lomo:hasDeonticModality ?modality }",
    'x-actions-of-rules': PREFIXES + "SELECT DISTINCT ?rule ?action WHERE { ?rule lomo:produces ?action }",
    'x-agents-in-roles': PREFIXES + "SELECT DISTINCT ?agent ?role ?action WHERE { ?action lomo:hasAgentRole ?r . ?r lomo:forAgent ?agent ; lomo:withRole ?role }",
}

def main():
    out, corpus, files = sys.argv[1], sys.argv[2], sys.argv[3:]
    onto = [os.path.join(corpus, 'ontologies', f) for f in sorted(os.listdir(os.path.join(corpus, 'ontologies'))) if f.endswith('.ttl')]
    qdir = os.path.join(corpus, 'queries')
    queries = {f[:-3]: open(os.path.join(qdir, f), encoding='utf-8').read() for f in sorted(os.listdir(qdir)) if f.endswith('.rq')}
    queries.update(EXTRA)
    base = rdflib.Graph()
    for o in onto:
        base.parse(o, format='turtle')
    result = {}
    for f in files:
        g = rdflib.Graph()
        for t in base:
            g.add(t)
        g.parse(f, format='turtle')
        per = {}
        for name, q in queries.items():
            rows = []
            for r in g.query(q):
                rows.append({str(k): ('' if r[k] is None else str(r[k])) for k in r.labels})
            per[name] = rows
        result[os.path.abspath(f)] = per
    with open(out, 'w', encoding='utf-8') as fh:
        json.dump(result, fh, ensure_ascii=False, indent=1)

if __name__ == '__main__':
    main()

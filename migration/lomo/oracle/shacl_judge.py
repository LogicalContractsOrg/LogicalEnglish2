"""The judge of step 2: LOMO's validity rules (SHACL), run by pySHACL.

    shacl_judge.py OUT.json CORPUS_DIR FILE.ttl ...

For each data file: pySHACL validates the file against shapes/lomo-shapes.ttl,
with the ontology and its four word lists joined to the data (so that a
target class has its subclasses, and a word has its scheme). OUT.json gets,
for each file, whether it conforms and its results: focus node, path,
constraint component, value. Written for the LOMO door of Logical English
(migration/lomo); Apache License 2.0.
"""
import json, os, sys
import rdflib
# The lexical form as written: rdflib would write a duration "P1W" as "P7D".
rdflib.NORMALIZE_LITERALS = False
from pyshacl import validate

SH = rdflib.Namespace('http://www.w3.org/ns/shacl#')

def main():
    out, corpus, files = sys.argv[1], sys.argv[2], sys.argv[3:]
    ont = rdflib.Graph()
    od = os.path.join(corpus, 'ontologies')
    for f in sorted(os.listdir(od)):
        if f.endswith('.ttl'):
            ont.parse(os.path.join(od, f), format='turtle')
    shapes = rdflib.Graph().parse(os.path.join(corpus, 'shapes', 'lomo-shapes.ttl'), format='turtle')
    result = {}
    for f in files:
        # The ontology is joined to the data, as pySHACL's ont_graph would
        # (which never finished on these files with pySHACL 0.40).
        data = rdflib.Graph()
        for t in ont:
            data.add(t)
        data.parse(f, format='turtle')
        conforms, rg, _ = validate(data, shacl_graph=shapes, inference='none',
                                   advanced=False, meta_shacl=False)
        rows = []
        # the results of the report itself (sh:result), not their details
        for r in rg.objects(None, SH.result):
            def v(p):
                x = rg.value(r, p)
                if x is None:
                    return ''
                if isinstance(x, rdflib.BNode):
                    return '_:'
                return str(x)
            rows.append({'focus': v(SH.focusNode), 'path': v(SH.resultPath),
                         'component': v(SH.sourceConstraintComponent).rsplit('#', 1)[-1],
                         'value': v(SH.value), 'severity': v(SH.resultSeverity).rsplit('#', 1)[-1]})
        result[os.path.abspath(f)] = {'conforms': bool(conforms), 'results': rows}
    with open(out, 'w', encoding='utf-8') as fh:
        json.dump(result, fh, ensure_ascii=False, indent=1)

if __name__ == '__main__':
    main()

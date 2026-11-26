"""The judge of step 7: are two Turtle files the same graph?

    iso_judge.py A.ttl B.ttl

Prints `same N` (rdflib's graph isomorphism, blank nodes included), or
`different N M`, then the statements only in A (`- `) and only in B (`+ `).
Written for the LOMO door of Logical English; Apache License 2.0.
"""
import sys
import rdflib
rdflib.NORMALIZE_LITERALS = False
from rdflib.compare import to_isomorphic, graph_diff

a = rdflib.Graph().parse(sys.argv[1], format='turtle')
b = rdflib.Graph().parse(sys.argv[2], format='turtle')
ia, ib = to_isomorphic(a), to_isomorphic(b)
if ia == ib:
    print('same', len(a))
else:
    print('different', len(a), len(b))
    both, only_a, only_b = graph_diff(ia, ib)
    for t in sorted(only_a)[:15]:
        print('-', t[0].n3(), t[1].n3(), t[2].n3()[:120])
    for t in sorted(only_b)[:15]:
        print('+', t[0].n3(), t[1].n3(), t[2].n3()[:120])

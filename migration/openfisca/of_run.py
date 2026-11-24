#!/usr/bin/env python3
"""One load of a package for its programmes: extract each, then run its tests on the engine.

    of_run.py <dialect> <out dir> --programme NAME --roots a,b [--within dir,...] [--tests PATH]... [--programme ...]

The arguments are those of of_extract.py; of_build.pl calls this. With
OF_REUSE_ORACLE=1 the engine is not run again: the last run's results are
kept (for a change of the reader alone).
"""
import gc, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import of_extract, of_oracle  # noqa: E402

dialect, out, progs = of_extract.parse_programmes(sys.argv[1:])
of_oracle.core(dialect)
system = of_extract.load_system(dialect)
for p in progs:
    of_extract.write_programme(system, dialect, out, p)
    gc.collect()
    if not (os.environ.get('OF_REUSE_ORACLE') and of_oracle.reuse(out, p['name'])):
        of_oracle.oracle(system, out, p['name'])
    gc.collect()

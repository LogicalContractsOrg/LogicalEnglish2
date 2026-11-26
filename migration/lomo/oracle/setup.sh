#!/bin/sh
# The judges of the LOMO door: rdflib (LOMO's search queries) and pySHACL
# (LOMO's validity rules), in a Python environment of their own here
# (.venv, not kept in the repository).
cd "$(dirname "$0")" && python3 -m venv .venv && .venv/bin/pip install -q rdflib pyshacl

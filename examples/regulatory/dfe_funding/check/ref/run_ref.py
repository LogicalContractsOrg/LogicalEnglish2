#!/usr/bin/env python3
"""python3 run_ref.py case1.json case2.json ...  -> one JSON line per case:
{"case": filename, "out": {...}}   (add --no-intermediate to drop "_intermediate")"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dfe_ref import calculate  # noqa: E402


def main(argv):
    keep = "--no-intermediate" not in argv
    files = [a for a in argv if not a.startswith("--")]
    rc = 0
    for f in files:
        try:
            with open(f) as fh:
                case = json.load(fh)
            out = calculate(case)
            if not keep:
                out.pop("_intermediate", None)
            print(json.dumps({"case": os.path.basename(f), "out": out}, sort_keys=True))
        except Exception as e:  # report, keep going
            rc = 1
            print(json.dumps({"case": os.path.basename(f), "error": repr(e)}))
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

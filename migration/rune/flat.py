"""Flat field-to-value views of DRR's report JSON, and their comparison.

    python3 flat.py compare <expected dir> <actual dir>

A report is flattened into "path = value" pairs: `leg1.notionalAmount = 300000`,
`otherPayment[0].paymentType = "UFRO"`.  `nonReportable` (DRR's working data,
not part of the report) is left out.
"""
import json, os, sys

SKIP = {"nonReportable"}

def flatten(obj, prefix="", out=None):
    out = {} if out is None else out
    if isinstance(obj, dict):
        for k, v in obj.items():
            if not prefix and k in SKIP:
                continue
            flatten(v, f"{prefix}.{k}" if prefix else k, out)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            flatten(v, f"{prefix}[{i}]", out)
    else:
        out[prefix] = obj
    return out

def load_flat(path):
    with open(path) as f:
        return flatten(json.load(f))

def same(a, b):
    if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool):
        return abs(a - b) < 1e-9 * max(1, abs(a))
    return a == b

def compare(exp_dir, act_dir):
    files = agree = differ = 0
    missing = []
    worst = {}
    for root, _, names in os.walk(exp_dir):
        for n in sorted(names):
            if not n.endswith(".json"):
                continue
            e = os.path.join(root, n)
            a = os.path.join(act_dir, os.path.relpath(e, exp_dir))
            if not os.path.exists(a):
                missing.append(a); continue
            files += 1
            fe, fa = load_flat(e), load_flat(a)
            for k in set(fe) | set(fa):
                if k in fe and k in fa and same(fe[k], fa[k]):
                    agree += 1
                else:
                    differ += 1
                    worst.setdefault(k, []).append(os.path.relpath(e, exp_dir))
    print(f"{files} reports compared, {len(missing)} missing; {agree} field values agree, {differ} differ")
    for k, v in sorted(worst.items(), key=lambda kv: -len(kv[1]))[:30]:
        print(f"  {len(v):4d}  {k}   e.g. {v[0]}")

if __name__ == "__main__":
    if sys.argv[1] == "compare":
        compare(sys.argv[2], sys.argv[3])

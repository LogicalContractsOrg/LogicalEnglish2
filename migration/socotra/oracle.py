#!/usr/bin/env python3
"""The reference run for Socotra products: runs a product's ORIGINAL Liquid
scripts on generated quotes, so that the LE twin can be checked against them.

This is not Socotra's software, and no Socotra software runs here: the Liquid
interpreter is python-liquid, and the filters that Socotra adds to Liquid are
written again below (the shims). The results were not compared with those of
Socotra's platform.

    python3 oracle.py <product-dir> <out.json> [--max-cases N]

For each generated quote (a policy with one exposure of each type the product
declares, every peril of it covered, and field values varied one at a time)
it runs these scripts of a Socotra Liquid configuration, in this order:

  1. each peril's  exposures/<exposure>/perils/<peril>.premium.liquid,
  2. each tax's    taxes/<tax>.premium.liquid on every peril's yearly premium,
  3. underwriting.guidelines.liquid on the whole policy,
  4. policy.calculations.liquid (fees) with the gross premium,

and records every output the scripts set (premiums, technical premiums,
commissions, taxes, underwriting decision and notes, fees).

Liquid semantics. python-liquid 2 runs the templates, with Socotra's custom
filters as shims (lookup, set_year_premium, add_year_commission, ...). Numbers
follow the reference Liquid (Ruby): integers stay integers (integer division
when both operands are integers), other numbers are IEEE doubles, and round
goes half away from zero. python-liquid's own arithmetic (decimal, and
round-half-to-even) is replaced, and the choice is recorded in the output.

Source defects the reference Liquid rejects are normalised first, the same way
the Prolog reader reads them (liquid.pl): a number written `.05`, `{% case x}`
missing its `%`, parentheses around a condition, a field named `limit`.
"""

import csv
import glob
import json
import math
import os
import re
import sys

from liquid import Environment
from liquid.undefined import Undefined

ROUNDING = "half away from zero (reference Liquid)"
ARITHMETIC = "integers as integers, other numbers as IEEE doubles (reference Liquid)"


# --------------------------------------------------------------------- numbers

def to_num(v):
    if isinstance(v, bool):
        return 0
    if isinstance(v, (int, float)):
        return v
    if v is None or isinstance(v, Undefined):
        return 0
    if isinstance(v, str):
        s = v.strip()
        try:
            return int(s)
        except ValueError:
            try:
                return float(s)
            except ValueError:
                return 0
    return 0


def f_times(a, b):
    a, b = to_num(a), to_num(b)
    if isinstance(a, int) and isinstance(b, int):
        return a * b
    return float(a) * float(b)


def f_plus(a, b):
    a, b = to_num(a), to_num(b)
    if isinstance(a, int) and isinstance(b, int):
        return a + b
    return float(a) + float(b)


def f_minus(a, b):
    a, b = to_num(a), to_num(b)
    if isinstance(a, int) and isinstance(b, int):
        return a - b
    return float(a) - float(b)


def f_divided_by(a, b):
    a, b = to_num(a), to_num(b)
    if isinstance(a, int) and isinstance(b, int):
        return a // b
    return float(a) / float(b)


def f_round(a, digits=None):
    a = to_num(a)
    if digits is None:
        return int(math.floor(abs(a) + 0.5)) * (1 if a >= 0 else -1)
    d = int(to_num(digits))
    m = 10 ** d
    return math.floor(abs(a) * m + 0.5) / m * (1 if a >= 0 else -1)


# ------------------------------------------------------------------- the shims

class Recorder:
    def __init__(self, tables):
        self.tables = tables
        self.out = {}

    def set(self, key, v):
        self.out[key] = v
        return ""

    def add(self, key, v):
        self.out.setdefault(key, []).append(v)
        return ""


def make_env(rec):
    env = Environment()
    f = env.filters
    f["times"] = f_times
    f["plus"] = f_plus
    f["minus"] = f_minus
    f["divided_by"] = f_divided_by
    f["round"] = f_round

    def lookup(table, key):
        rows = rec.tables.get(str(table))
        if rows is None:
            return None
        return rows.get(str(key).strip() if key is not None else "")
    f["lookup"] = lookup

    for name in ["set_year_premium", "set_year_technical_premium",
                 "set_month_premium", "set_month_technical_premium",
                 "set_underwriting_decision", "set_peril_tax"]:
        f[name] = (lambda n: (lambda v, *a: rec.set(n, v)))(name)
    f["add_year_commission"] = lambda v, who="": rec.add("year_commission", [str(who), v])
    f["add_month_commission"] = lambda v, who="": rec.add("month_commission", [str(who), v])
    f["add_underwriting_note"] = lambda v, *a: rec.add("notes", str(v))
    f["add_fee"] = lambda v, name="", desc="": rec.add("fees", [str(name), v, str(desc)])

    def timestamp_millis_print(v, fmt=""):
        import datetime
        if isinstance(v, str) and re.match(r"^\d{4}-\d{2}-\d{2}", v):
            d = datetime.date.fromisoformat(v[:10])
        else:
            d = datetime.datetime.fromtimestamp(to_num(v) / 1000, datetime.timezone.utc).date()
        return str(fmt).replace("YYYY", "%04d" % d.year).replace("MM", "%02d" % d.month) \
                       .replace("DD", "%02d" % d.day)
    f["timestamp_millis_print"] = timestamp_millis_print
    return env


# The reference Liquid compares nil with a number as false (Ruby: nil does not
# respond to <); python-liquid raises. A policy whose loop reads a field one
# of its exposures lacks would otherwise stop its underwriting script.
import liquid.builtin.expressions.logical as _logical
_orig_lt = _logical._lt


def _lt_nil_false(token, left, right):
    if left is None or right is None or isinstance(left, Undefined) or isinstance(right, Undefined):
        return False
    return _orig_lt(token, left, right)


_logical._lt = _lt_nil_false
NIL_COMPARISON = "a comparison with nil is false (reference Liquid)"


def normalize(src):
    src = re.sub(r"\{%(\s*case[^%\n}]*)\}", r"{%\1 %}", src)        # {% case x}
    src = re.sub(r"(=\s*)\.(\d)", r"\g<1>0.\2", src)                  # .05
    src = re.sub(r"(\{%\s*(?:if|elsif)\s)([^%]*)%\}",
                 lambda m: m.group(1) + m.group(2).replace("(", "").replace(")", "") + "%}", src)
    src = re.sub(r"\.limit\b", '["limit"]', src)                       # a field named limit
    src = re.sub(r"\|\s*\|", "|", src)                                   # an empty filter: | |
    return src


def read_tables(policy_dir):
    tables = {}
    for p in glob.glob(os.path.join(policy_dir, "tables", "*.csv")):
        name = os.path.splitext(os.path.basename(p))[0]
        with open(p, newline="", encoding="utf-8-sig") as fh:
            rows = list(csv.reader(fh))
        d = {}
        for r in rows[1:]:
            if len(r) >= 2:
                d[r[0].strip()] = r[1].strip()
        tables[name] = d
    return tables


def run_script(path, data, tables):
    """(outputs, error) of one script on one data object."""
    rec = Recorder(tables)
    env = make_env(rec)
    try:
        with open(path, encoding="utf-8") as fh:
            tmpl = env.from_string(normalize(fh.read()))
        tmpl.render(data=data)
    except Exception as e:  # a script the reference Liquid cannot run
        return rec.out, "%s: %s" % (type(e).__name__, str(e).splitlines()[0][:200])
    return rec.out, None


# ------------------------------------------------------------ the product model

def load_json(p):
    with open(p, encoding="utf-8") as fh:
        return json.load(fh)


def exposures_of(policy_dir):
    out = []
    for ej in sorted(glob.glob(os.path.join(policy_dir, "exposures", "*", "exposure.json"))):
        e = load_json(ej)
        edir = os.path.dirname(ej)
        perils = []
        for pj in sorted(glob.glob(os.path.join(edir, "perils", "*.json"))):
            p = load_json(pj)
            base = os.path.splitext(os.path.basename(pj))[0]
            script = os.path.join(edir, "perils", base + ".premium.liquid")
            perils.append({"name": p.get("name", base), "json": p, "file": base,
                           "script": script if os.path.exists(script) else None})
        out.append({"name": e["name"], "dir": os.path.basename(edir), "json": e, "perils": perils})
    return out


NUM_DEFAULTS = [("value", 25000), ("revenue", 1000000), ("sales", 500000), ("area", 2000),
                ("wage", 100000), ("payroll", 200000), ("mod", 1), ("credit", 1),
                ("age", 40), ("year", 2015), ("cc", 600), ("employee", 10), ("limit", 50000),
                ("amount", 10000), ("length", 20), ("price", 1000)]


def default_number(name):
    n = name.lower()
    for k, v in NUM_DEFAULTS:
        if k in n:
            return v
    return 100


TABLES = {}          # the product's tables, for lookup fields


def default_value(field):
    t = field.get("type")
    if t == "lookup":
        # a key of the field's table (a field matched to another one is
        # filled once that one is: match_lookups)
        keys = list(TABLES.get(field.get("table"), {}))
        return None if field.get("match") or not keys else keys[0]
    if t == "select":
        vals = field.get("values") or []
        return vals[0] if vals else None
    if t == "number":
        return default_number(field["name"])
    if t == "date":
        return "1980-05-15" if "dob" in field["name"].lower() or "birth" in field["name"].lower() else "2026-01-01"
    if t == "string":
        return "text"
    if t == "email":
        return "someone@example.com"
    return None


def scalar_fields(fields):
    return [f for f in fields or [] if f.get("type") in ("select", "number", "date", "string", "email", "lookup")]


def match_lookups(fields, values):
    """A lookup field matched to another field: the table's value for that field's key."""
    for f in scalar_fields(fields):
        if f.get("type") == "lookup" and f.get("match"):
            key = values.get(f["match"][0])
            v = TABLES.get(f.get("table"), {}).get(key) if key is not None else None
            if v is not None:
                values[f["name"]] = v
    return values


def peril_chars(pj):
    chars = {}
    for k_json, k in [("indemnityPerItem", "indemnity_per_item"), ("indemnityPerEvent", "indemnity_per_event"),
                      ("indemnityInAggregate", "indemnity_in_aggregate"), ("deductible", "deductible"),
                      ("lumpSumPayment", "lump_sum_payment")]:
        v = pj.get(k_json)
        if v is None:
            chars[k] = 0            # the platform's default for a characteristic not set
            continue
        try:
            chars[k] = int(str(v))
        except ValueError:
            try:
                chars[k] = float(str(v))
            except ValueError:
                chars[k] = UNLIMITED    # "unlimited": a representative large limit
    return chars


UNLIMITED = 1000000

START_MS = 1767225600000          # the policy's start: 2026-01-01
END_MS = START_MS + 365 * 86400000


def iso_date(ms):
    import datetime
    return datetime.datetime.fromtimestamp(ms / 1000, datetime.timezone.utc).date().isoformat()


# ---------------------------------------------------------------- the quotes

def thresholds(script_texts, field):
    """Numbers a script compares this field (or a variable read from it) with."""
    ths = set()
    for t in script_texts:
        for m in re.finditer(r"\b%s\s*(>=|>|<=|<)\s*(\d+(?:\.\d+)?)" % re.escape(field), t):
            ths.add(float(m.group(2)) if "." in m.group(2) else int(m.group(2)))
        # {% assign x = ...field... %} ... x >= N
        for m in re.finditer(r"assign\s+(\w+)\s*=\s*[^%%]*\b%s\b" % re.escape(field), t):
            var = m.group(1)
            for m2 in re.finditer(r"\b%s\s*(>=|>|<=|<)\s*(\d+(?:\.\d+)?)" % re.escape(var), t):
                ths.add(float(m2.group(2)) if "." in m2.group(2) else int(m2.group(2)))
    return sorted(ths)


def referenced(script_texts, name):
    pat = re.compile(r"[.\[\"']%s\b" % re.escape(name))
    return any(pat.search(t) for t in script_texts)


def build_cases(policy_dir, max_cases):
    policy = load_json(os.path.join(policy_dir, "policy.json"))
    exps = exposures_of(policy_dir)
    texts = []
    for p in glob.glob(os.path.join(policy_dir, "**", "*.liquid"), recursive=True):
        if not p.endswith(".template.liquid"):
            with open(p, encoding="utf-8") as fh:
                texts.append(fh.read())

    base_pol = {f["name"]: default_value(f) for f in scalar_fields(policy.get("fields"))}
    base_pol = match_lookups(policy.get("fields"), {k: v for k, v in base_pol.items() if v is not None})
    base_exps = []
    for i, e in enumerate(exps):
        fv = {f["name"]: default_value(f) for f in scalar_fields(e["json"].get("fields"))}
        perils = []
        for p in e["perils"]:
            pf = {f["name"]: default_value(f) for f in scalar_fields(p["json"].get("fields"))}
            perils.append({"name": p["name"], "file": p["file"],
                           "chars": peril_chars(p["json"]),
                           "fields": match_lookups(p["json"].get("fields"),
                                                   {k: v for k, v in pf.items() if v is not None})})
        base_exps.append({"type": e["name"], "dir": e["dir"],
                          "fields": match_lookups(e["json"].get("fields"),
                                                  {k: v for k, v in fv.items() if v is not None}),
                          "perils": perils})

    cases = [("base", base_pol, base_exps)]
    variants = []

    def vary(scope, fields, setter):
        for f in scalar_fields(fields):
            if not referenced(texts, f["name"]):
                continue
            if f["type"] == "lookup":
                if not f.get("match"):
                    for v in list(TABLES.get(f.get("table"), {}))[1:3]:
                        variants.append(("%s_%s_%s" % (scope, f["name"], v), setter(f["name"], v, fields)))
            elif f["type"] == "select":
                vals = f.get("values") or []
                for v in vals[1:6]:
                    variants.append(("%s_%s_%s" % (scope, f["name"], v), setter(f["name"], v, fields)))
            elif f["type"] == "number":
                for th in thresholds(texts, f["name"])[:2]:
                    v = th * 2 if th > 0 else 5
                    if isinstance(v, float):
                        v = round(v, 2)
                    variants.append(("%s_%s_%s" % (scope, f["name"], v), setter(f["name"], v, fields)))

    def pol_setter(name, v, fields):
        def mk():
            p = dict(base_pol); p[name] = v; match_lookups(fields, p)
            return p, json.loads(json.dumps(base_exps))
        return mk
    vary("policy", policy.get("fields"), pol_setter)

    for i, e in enumerate(exps):
        def exp_setter(name, v, fields, i=i):
            def mk():
                es = json.loads(json.dumps(base_exps)); es[i]["fields"][name] = v
                match_lookups(fields, es[i]["fields"])
                return dict(base_pol), es
            return mk
        vary("exposure_" + e["dir"].strip(), e["json"].get("fields"), exp_setter)
        for j, p in enumerate(e["perils"]):
            def peril_setter(name, v, fields, i=i, j=j):
                def mk():
                    es = json.loads(json.dumps(base_exps)); es[i]["perils"][j]["fields"][name] = v
                    match_lookups(fields, es[i]["perils"][j]["fields"])
                    return dict(base_pol), es
                return mk
            vary("peril_" + p["file"], p["json"].get("fields"), peril_setter)

    # spread the variants over the budget
    if len(variants) > max_cases - 1:
        step = len(variants) / (max_cases - 1)
        variants = [variants[int(k * step)] for k in range(max_cases - 1)]
    for cid, mk in variants:
        pol, es = mk()
        cases.append((cid, pol, es))
    return cases, exps


def run_case(policy_dir, exps, pol_fields, exp_list, tables):
    outputs = {"perils": [], "policy": {}}
    errors = []
    policy_obj = {"characteristics": [{"field_values": pol_fields}], "exposures": []}
    for e in exp_list:
        policy_obj["exposures"].append({
            "name": e["type"],
            "characteristics": [{"field_values": e["fields"], "field_groups_by_locator": {}}],
            "perils": [{"name": p["name"],
                        "characteristics": [dict(p["chars"], field_values=p["fields"])]}
                       for p in e["perils"]]})
    pol_chars = {"field_values": pol_fields, "policy_start_timestamp": START_MS,
                 "policy_end_timestamp": END_MS}
    gross = 0
    # 1. perils
    for ei, e in enumerate(exp_list):
        exp_model = exps[ei]
        for pi, p in enumerate(e["perils"]):
            script = exp_model["perils"][pi]["script"]
            rec = {"exposure": ei, "peril": p["name"], "file": p["file"], "out": {}}
            if script:
                data = {"policy_characteristics": pol_chars,
                        "exposure_characteristics": {"field_values": e["fields"], "field_groups_by_locator": {}},
                        "peril_characteristics": dict(p["chars"], field_values=p["fields"]),
                        "policy": policy_obj}
                out, err = run_script(script, data, tables)
                rec["out"] = out
                if err:
                    rec["error"] = err
                    errors.append("%s: %s" % (os.path.relpath(script, policy_dir), err))
            outputs["perils"].append(rec)
    # 2. taxes
    for tax_script in sorted(glob.glob(os.path.join(policy_dir, "taxes", "*.premium.liquid"))):
        tax = os.path.basename(tax_script).split(".")[0]
        for rec in outputs["perils"]:
            prem = rec["out"].get("set_year_premium")
            if prem is None or "error" in rec:
                continue
            e = exp_list[rec["exposure"]]
            p = [x for x in e["perils"] if x["name"] == rec["peril"]][0]
            data = {"policy_characteristics": pol_chars,
                    "exposure_characteristics": {"field_values": e["fields"]},
                    "peril_characteristics": dict(p["chars"], field_values=p["fields"], premium=prem),
                    "policy": policy_obj}
            out, err = run_script(tax_script, data, tables)
            if err:
                errors.append("%s: %s" % (os.path.relpath(tax_script, policy_dir), err))
            elif "set_peril_tax" in out:
                rec.setdefault("taxes", {})[tax] = out["set_peril_tax"]
    # the gross premium: the perils' yearly premiums, in quote order
    for rec in outputs["perils"]:
        prem = rec["out"].get("set_year_premium")
        if prem is not None and "error" not in rec:
            gross = f_plus(gross, prem)
    outputs["policy"]["gross_premium"] = gross
    policy_obj["characteristics"][0]["gross_premium"] = gross
    # the gross taxes: every peril's taxes, in quote order
    gross_taxes = 0
    for rec in outputs["perils"]:
        for t in sorted(rec.get("taxes", {})):
            gross_taxes = f_plus(gross_taxes, rec["taxes"][t])
    outputs["policy"]["gross_taxes"] = gross_taxes
    policy_obj["characteristics"][0]["gross_taxes"] = gross_taxes
    # 3. underwriting, 4. fees
    for name, key in [("underwriting.guidelines.liquid", "underwriting"), ("policy.calculations.liquid", "fees")]:
        path = os.path.join(policy_dir, name)
        if os.path.exists(path):
            out, err = run_script(path, {"policy": policy_obj, "policy_characteristics": pol_chars}, tables)
            outputs["policy"][key] = out
            if err:
                outputs["policy"][key + "_error"] = err
                errors.append("%s: %s" % (name, err))
    return outputs, errors


def main():
    product_dir = sys.argv[1]
    out_path = sys.argv[2]
    max_cases = 12
    if "--max-cases" in sys.argv:
        max_cases = int(sys.argv[sys.argv.index("--max-cases") + 1])
    policy_dir = os.path.join(product_dir, "policy")
    tables = read_tables(policy_dir)
    TABLES.update(tables)
    cases, exps = build_cases(policy_dir, max_cases)
    result = {"product": os.path.basename(product_dir.rstrip("/")),
              "semantics": {"rounding": ROUNDING, "arithmetic": ARITHMETIC, "nil": NIL_COMPARISON,
                            "engine": "python-liquid %s" % __import__("liquid").__version__},
              "cases": []}
    for cid, pol, es in cases:
        outputs, errors = run_case(policy_dir, exps, pol, es, tables)
        result["cases"].append({"id": cid, "policy": pol, "exposures": es,
                                "policy_dates": {"start": iso_date(START_MS), "end": iso_date(END_MS)},
                                "outputs": outputs, "errors": errors})
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(result, fh, indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()

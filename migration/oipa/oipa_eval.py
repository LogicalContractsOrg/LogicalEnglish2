#!/usr/bin/env python3
"""The reference calculator of the OIPA twins (their test oracle): an
interpreter of OIPA transaction math. It is not Oracle's engine: it was
written for this repository from Oracle's public XML Configuration Guide.

Phase 2b (the design notes roadmap.md): there is no public
OIPA, so the expected policy values are computed independently of the
translator, as the plan asks ("a spreadsheet"): this interpreter reads the
same XML the translator reads and evaluates it with the semantics of the OIPA
XML Configuration Guide 9.7 -- MathVariables top to bottom (a later one of the
same name replaces the earlier), MathIF, IIF, VALUE, FIELD (Activity:),
POLICYFIELD, PLANFIELD, EXPRESSION (the guide's operators), FUNCTION (the
functions the corpus uses, as the guide defines them), RATE (exact match on
the criteria the table has, DEFAULT when none), ROUND (half up), then the
attached rules ValidateExpressions (ErrorOnTrue/ErrorOnFalse, $$$MV$$$
substitution), SpawnActivities and CopyToPolicyFields. It shares no code
with the Prolog translator.

    oipa_eval.py PLAN_DIR CASES.json     -> the policy lives, activity by
                                            activity, as JSON on stdout
"""

import csv, json, os, re, sys, datetime
import xml.etree.ElementTree as ET
from decimal import Decimal, ROUND_HALF_UP, ROUND_DOWN

# ---------------------------------------------------------------- values

def to_date(v):
    if isinstance(v, datetime.date):
        return v
    return datetime.date.fromisoformat(str(v))

def num(v):
    if isinstance(v, Decimal):
        return v
    if isinstance(v, bool):
        return Decimal(int(v))
    return Decimal(str(v))

def typed(value, datatype):
    dt = (datatype or "").strip().upper()
    if value is None:
        return None
    if dt in ("DECIMAL", "INTEGER", "CURRENCY"):
        d = num(value)
        return d.to_integral_value(ROUND_DOWN) if dt == "INTEGER" else d
    if dt == "DATE":
        return to_date(value)
    if dt == "BOOLEAN":
        return value if isinstance(value, bool) else str(value).lower() == "true"
    return value if isinstance(value, (Decimal, datetime.date, bool)) else str(value)

# ---------------------------------------------------------------- dates (the guide's definitions)

def add_months(d, n):
    m = d.month - 1 + n
    y, m = d.year + m // 12, m % 12 + 1
    last = [31, 29 if (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)) else 28,
            31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]
    return datetime.date(y, m, min(d.day, last))

def full_years(d1, d2):
    """DurationOf: full years, unchanged until an anniversary of d1 is reached."""
    y = d2.year - d1.year
    if (d2.month, d2.day) < (d1.month, d1.day):
        y -= 1
    return y

def anb_age(birth, d):
    """ANBAgeOf: d moved to the nearest anniversary of birth."""
    age = full_years(birth, d)
    last = add_months(birth, 12 * age)
    nxt = add_months(birth, 12 * (age + 1))
    return age + 1 if (nxt - d) < (d - last) else age

FUNCTIONS = {
    "DurationOf": lambda a, b: Decimal(full_years(to_date(a), to_date(b))),
    "ANBAgeOf": lambda a, b: Decimal(anb_age(to_date(a), to_date(b))),
    "DaysDiffOf": lambda a, b: Decimal((to_date(b) - to_date(a)).days),
    "MonthsAdd": lambda d, n: add_months(to_date(d), int(num(n))),
    "TruncateNumber": lambda x, p: num(x).quantize(Decimal(1).scaleb(-int(num(p))), rounding=ROUND_DOWN),
    "MinOf": lambda a, b: min(num(a), num(b)),
    "MaxOf": lambda a, b: max(num(a), num(b)),
    "AbsOf": lambda a: abs(num(a)),
}

# ---------------------------------------------------------------- expressions

TOKEN = re.compile(r"\s*(?:(\d+\.\d*|\d*\.\d+|\d+)|('[^']*')|(<>|!=|<=|>=|[-+*/^%=<>(),])|([A-Za-z_][A-Za-z0-9_:]*))")

def tokenize(s):
    s = s.strip()
    pos, out = 0, []
    while pos < len(s):
        m = TOKEN.match(s, pos)
        if not m or m.end() == pos:
            raise ValueError("cannot read %r at %d" % (s, pos))
        n, q, op, name = m.groups()
        if n is not None: out.append(("num", Decimal(n)))
        elif q is not None: out.append(("str", q[1:-1]))
        elif op is not None: out.append(("op", op))
        else:
            low = name.lower()
            if low in ("and", "or", "not"): out.append(("op", low))
            elif low in ("true", "false"): out.append(("bool", low == "true"))
            else: out.append(("name", name))
        pos = m.end()
    return out

class Expr:
    def __init__(self, text, env):
        self.toks = tokenize(text)
        self.i = 0
        self.env = env
    def peek(self):
        return self.toks[self.i] if self.i < len(self.toks) else (None, None)
    def take(self, kind=None, val=None):
        k, v = self.peek()
        if (kind and k != kind) or (val is not None and v != val):
            raise ValueError("expected %s %s, got %s %s" % (kind, val, k, v))
        self.i += 1
        return v
    def parse(self):
        v = self.or_()
        if self.i != len(self.toks):
            raise ValueError("trailing tokens")
        return v
    def or_(self):
        v = self.and_()
        while self.peek() == ("op", "or"):
            self.take(); r = self.and_(); v = bool(v) or bool(r)
        return v
    def and_(self):
        v = self.not_()
        while self.peek() == ("op", "and"):
            self.take(); r = self.not_(); v = bool(v) and bool(r)
        return v
    def not_(self):
        if self.peek() == ("op", "not"):
            self.take(); return not bool(self.not_())
        return self.cmp()
    def cmp(self):
        v = self.add()
        k, op = self.peek()
        if k == "op" and op in ("=", "<>", "!=", "<", ">", "<=", ">="):
            self.take(); r = self.add()
            a, b = comparable(v, r)
            return {"=": a == b, "<>": a != b, "!=": a != b, "<": a < b, ">": a > b,
                    "<=": a <= b, ">=": a >= b}[op]
        return v
    def add(self):
        v = self.mul()
        while self.peek()[0] == "op" and self.peek()[1] in ("+", "-"):
            op = self.take(); r = self.mul()
            v = num(v) + num(r) if op == "+" else num(v) - num(r)
        return v
    def mul(self):
        v = self.pow()
        while self.peek()[0] == "op" and self.peek()[1] in ("*", "/", "%"):
            op = self.take(); r = self.pow()
            v = num(v) * num(r) if op == "*" else (num(v) / num(r) if op == "/" else num(v) % num(r))
        return v
    def pow(self):
        v = self.unary()
        if self.peek() == ("op", "^"):
            self.take(); r = self.pow(); v = num(v) ** int(num(r))
        return v
    def unary(self):
        if self.peek() == ("op", "-"):
            self.take(); return -num(self.unary())
        return self.atom()
    def atom(self):
        k, v = self.peek()
        if k == "num": self.take(); return v
        if k == "str": self.take(); return v
        if k == "bool": self.take(); return v
        if k == "op" and v == "(":
            self.take(); x = self.or_(); self.take("op", ")"); return x
        if k == "name":
            self.take()
            if self.peek() == ("op", "("):
                self.take(); args = []
                if self.peek() != ("op", ")"):
                    args.append(self.or_())
                    while self.peek() == ("op", ","):
                        self.take(); args.append(self.or_())
                self.take("op", ")")
                return FUNCTIONS[v](*args)
            return self.env.lookup(v)
        raise ValueError("unexpected %s %s" % (k, v))

def comparable(a, b):
    if isinstance(a, datetime.date) or isinstance(b, datetime.date):
        return to_date(a), to_date(b)
    try:
        return num(a), num(b)
    except Exception:
        return str(a), str(b)

# ---------------------------------------------------------------- a transaction

class Env:
    def __init__(self, activity, policy, plan):
        self.mv, self.activity, self.policy, self.plan = {}, activity, policy, plan
    def lookup(self, name):
        if name in self.mv: return self.mv[name]
        if ":" in name:
            scope, field = name.split(":", 1)
            src = {"Activity": self.activity, "Policy": self.policy, "Plan": self.plan}[scope]
            return src.get(field)
        raise KeyError("no MathVariable " + name)

def load_xml(path):
    return ET.parse(path).getroot() if os.path.exists(path) else None

def rate(rows, params, env, default):
    desc = params.findtext("RateDescription").strip()
    crit = {c.get("NAME"): env.lookup(c.text.strip()) for c in params.findall("RateCriteria")}
    for r in rows:
        if r["RateDescription"] != desc: continue
        if all(str(num(v)) == str(num(r[k])) if _isnum(r[k]) else str(v) == r[k]
               for k, v in crit.items() if k in r):
            return Decimal(r["Rate"])
    return default

def _isnum(s):
    try: Decimal(s); return True
    except Exception: return False

def run_math(node, env, rates):
    for el in node:
        if el.tag == "MathVariable":
            name, typ = el.get("VARIABLENAME"), el.get("TYPE").upper()
            dt, text = el.get("DATATYPE"), (el.text or "").strip()
            default = el.get("DEFAULT")
            if typ == "VALUE": v = text if text != "" else None
            elif typ == "FIELD": v = env.lookup(text)
            elif typ == "POLICYFIELD": v = env.policy.get(text)
            elif typ == "PLANFIELD": v = env.plan.get(text)
            elif typ in ("EXPRESSION", "FUNCTION"): v = Expr(text, env).parse()
            elif typ == "IIF":
                first, second = [x.strip() for x in text.split(",")]
                v = env.lookup(first) if Expr(el.get("EXPRESSION"), env).parse() else env.lookup(second)
            elif typ == "RATE":
                v = rate(rates, el.find("Parameters"), env, None)
            else:
                raise ValueError("unsupported MathVariable TYPE " + typ)
            if v is None and default is not None: v = default
            v = typed(v, dt)
            if el.get("ROUND") and isinstance(v, Decimal):
                v = v.quantize(Decimal(1).scaleb(-int(el.get("ROUND"))), rounding=ROUND_HALF_UP)
            env.mv[name] = v
        elif el.tag == "MathIF":
            if Expr(el.get("IF"), env).parse():
                run_math(el, env, rates)

def substitute(msg, env):
    return re.sub(r"\$\$\$(\w+)\$\$\$", lambda m: show(env.lookup(m.group(1))), msg)

def show(v):
    if isinstance(v, Decimal):
        s = format(v.normalize(), "f")
        return s
    if isinstance(v, datetime.date): return v.isoformat()
    return str(v)

def run_activity(plan_dir, name, activity, policy, plan, rates):
    tdir = os.path.join(plan_dir, name)
    env = Env(activity, policy, plan)
    run_math(load_xml(os.path.join(tdir, "Transaction.xml")).find("Math/MathVariables"), env, rates)
    errors = []
    ve = load_xml(os.path.join(tdir, "ValidateExpressions.xml"))
    for e in (ve.findall("Expression") if ve is not None else []):
        r = bool(Expr(e.text, env).parse())
        if (e.get("TYPE") == "ErrorOnTrue") == r:
            errors.append({"number": e.get("ERRORNUMBER"), "message": substitute(e.get("MESSAGE"), env)})
    spawns = []
    sa = load_xml(os.path.join(tdir, "SpawnActivities.xml"))
    for s in (sa.findall("Spawn") if sa is not None else []):
        if all(Expr(t.text, env).parse() for t in s.findall("Tests/Test")):
            spawns.append(s.findtext("Transaction").strip())
    updates = {}
    cp = load_xml(os.path.join(tdir, "CopyToPolicyFields.xml"))
    for f in (cp.findall("Fields/Field") if cp is not None else []):
        updates[f.findtext("To").strip()] = env.lookup(f.findtext("From").strip())
    return env, errors, spawns, updates

def plain(d):
    return {k: show(v) for k, v in d.items() if v is not None}

def main(plan_dir, cases_file):
    rates = list(csv.DictReader(open(os.path.join(plan_dir, "Rates.csv"))))
    plan = {r["Name"]: r["Value"] for r in csv.DictReader(open(os.path.join(plan_dir, "PlanFields.csv")))}
    cases = json.load(open(cases_file))
    out = []
    for life in cases["lives"]:
        policy = {k: (to_date(v) if re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(v)) else v)
                  for k, v in life.get("policy", {}).items()}
        queue = [dict(a) for a in life["activities"]]
        steps = []
        while queue:
            a = queue.pop(0)
            fields = dict(a.get("fields", {}))
            fields["EffectiveDate"] = to_date(a["date"])
            before = dict(policy)
            env, errors, spawns, updates = run_activity(plan_dir, a["transaction"], fields, before, plan, rates)
            if not errors:
                policy.update(updates)
                for s in spawns:
                    if os.path.isdir(os.path.join(plan_dir, s)):
                        queue.insert(0, {"id": a["id"] + "_" + s.lower(), "transaction": s, "date": a["date"],
                                         "fields": {}, "spawned_by": a["id"]})
            steps.append({"id": a["id"], "transaction": a["transaction"], "date": a["date"],
                          "fields": plain({k: v for k, v in fields.items() if k != "EffectiveDate"}),
                          "policy": plain(before), "values": plain(env.mv),
                          "errors": errors, "spawns": spawns if not errors else [],
                          "updates": plain(updates) if not errors else {},
                          "spawned_by": a.get("spawned_by")})
        out.append({"life": life["name"], "steps": steps, "final_policy": plain(policy)})
    json.dump({"plan": os.path.basename(plan_dir.rstrip("/")), "plan_fields": plan, "lives": out},
              sys.stdout, indent=1)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

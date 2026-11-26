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

# ---- the calendar of step 3, computed here with no Logical English --------
# For each action with a deadline: the agent who bears it (the addresser),
# the rule that produces it, and its due dates. Events that a deadline
# counts from happen on the calendar's start, 2027-01-01, which is also
# the start of a rhythm that counts from nothing else.
import calendar as _cal, datetime as _dt, math as _math, re as _re

LOMO = rdflib.Namespace('http://data.europa.eu/leg/lomo#')
TFN = rdflib.Namespace('http://data.europa.eu/leg/temporal-function/')
ROLE = rdflib.Namespace('http://publications.europa.eu/resource/authority/role/')
XDATE = rdflib.URIRef('http://www.w3.org/2006/time#inXSDDate')
START = _dt.date(2027, 1, 1)
WINDOW = (_dt.date(2027, 1, 1), _dt.date(2027, 12, 31))
ISO = _re.compile(r'^P(?!$)(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?(?:T(?=\d)(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$')

def iso(text):
    m = ISO.match(str(text))
    if not m:
        return None
    y, mo, w, d, h, mi, se = [int(x) if x else 0 for x in m.groups()]
    return (y * 12 + mo, w * 7 + d, h * 3600 + mi * 60 + se)

def add_months(day, n):
    t = day.year * 12 + day.month - 1 + n
    y, m = divmod(t, 12)
    return _dt.date(y, m + 1, min(day.day, _cal.monthrange(y, m + 1)[1]))

def add_period(day, text, k):
    p = iso(text)
    months, days, secs = p
    d1 = add_months(day, k * months)
    return d1 + _dt.timedelta(days=k * (days + _math.ceil(secs / 86400)))

def instant_days(lit):
    t = str(lit)
    t = t.split('T')[0]
    parts = t.split('-')
    try:
        nums = [int(x) for x in parts]
    except ValueError:
        return None
    if len(nums) == 3:
        d = _dt.date(*nums); return (d, d)
    if len(nums) == 2:
        y, m = nums; return (_dt.date(y, m, 1), _dt.date(y, m, _cal.monthrange(y, m)[1]))
    if len(nums) == 1 and nums[0] > 999:
        return (_dt.date(nums[0], 1, 1), _dt.date(nums[0], 12, 31))
    return None

def later_than(g, s):
    out = set(g.objects(s, LOMO.after)) | set(g.objects(s, LOMO.immediatelyAfter))
    out |= set(g.subjects(LOMO.before, s)) | set(g.subjects(LOMO.immediatelyBefore, s))
    return out

def earlier_than(g, s):
    out = set(g.objects(s, LOMO.before)) | set(g.objects(s, LOMO.immediatelyBefore))
    out |= set(g.subjects(LOMO.after, s)) | set(g.subjects(LOMO.immediatelyAfter, s))
    return out

def first_dates(g, s, happened, depth=0):
    if depth > 10:
        return set()
    out = set()
    for i in g.objects(s, LOMO.instant):
        r = instant_days(i)
        if r: out.add(r[0])
    for i in g.objects(s, XDATE):
        r = instant_days(i)
        if r: out.add(r[0])
    for l in g.objects(s, LOMO.temporalLabel):
        if str(l) in happened: out.add(happened[str(l)])
    for du in g.objects(s, LOMO.duration):
        if iso(du) is None: continue
        for s2 in later_than(g, s):
            for d2 in last_dates(g, s2, happened, depth + 1): out.add(add_period(d2, du, 1))
        for s2 in earlier_than(g, s):
            for d2 in first_dates(g, s2, happened, depth + 1): out.add(add_period(d2, du, -1))
    return out

def last_dates(g, s, happened, depth=0):
    insts = list(g.objects(s, LOMO.instant))
    if insts:
        durs = list(g.objects(s, LOMO.duration))
        out = set()
        for i in insts:
            r = instant_days(i)
            if not r: continue
            if durs:
                for du in durs:
                    if iso(du) is not None: out.add(add_period(r[0], du, 1))
            else:
                out.add(r[1])
        return out
    return first_dates(g, s, happened, depth)

def calendar(g):
    happened = {}
    deadlines = [s for s in g.subjects(LOMO.hasFunction, TFN.deadline)]
    for s in deadlines:
        for s2 in later_than(g, s) | earlier_than(g, s):
            if any(True for _ in g.objects(s2, LOMO.instant)) or any(True for _ in g.objects(s2, XDATE)):
                continue          # a specification with a date of its own
            for l in g.objects(s2, LOMO.temporalLabel):
                happened[str(l)] = START
    due, due_in = set(), set()
    for a, s in g.subject_objects(LOMO.atTime):
        if (s, LOMO.hasFunction, TFN.deadline) not in g:
            continue
        agents = set()
        for r in g.objects(a, LOMO.hasAgentRole):
            if (r, LOMO.withRole, ROLE.ADDRESSER) in g:
                agents |= set(g.objects(r, LOMO.forAgent))
        freqs = list(g.objects(s, LOMO.frequency))
        dates_one, dates_in = set(), set()
        if not freqs:
            dates_one = first_dates(g, s, happened)
            dates_in = {d for d in dates_one if WINDOW[0] <= d <= WINDOW[1]}
        else:
            starts = first_dates(g, s, happened)
            if not starts:
                for s2 in later_than(g, s):
                    starts |= last_dates(g, s2, happened)
            if not starts:
                starts = {START}
            reps = [int(x) for x in g.objects(s, LOMO.repetitions)]
            ends = set()
            for s2 in g.objects(s, LOMO.finishedBy):
                ends |= last_dates(g, s2, happened)
            for fq in freqs:
                if iso(fq) is None: continue
                for st in starts:
                    k = 1
                    while True:
                        d = add_period(st, fq, k)
                        if d > WINDOW[1]: break
                        if reps and k > min(reps): break
                        if ends and any(d > e for e in ends): break
                        if d >= WINDOW[0]: dates_in.add(d)
                        k += 1
        for ag in agents:
            for d in dates_one: due.add((str(ag), str(a), d.isoformat()))
            for d in dates_in: due_in.add((str(ag), str(a), d.isoformat()))
    keys = ['agent', 'action', 'date']
    return ([dict(zip(keys, t)) for t in sorted(due)], [dict(zip(keys, t)) for t in sorted(due_in)],
            [{'event': l, 'date': d.isoformat()} for l, d in sorted(happened.items())])

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
        due, due_in, happened = calendar(g)
        per['x-due'] = due
        per['x-due-2027'] = due_in
        per['x-happened'] = happened
        per['x-deadline-values'] = [{'spec': str(sp)} for sp in set(g.subjects(LOMO.hasFunction, TFN.deadline))
                                    if any(True for p in (LOMO.instant, LOMO.duration, LOMO.frequency, XDATE) for _ in g.objects(sp, p))]
        result[os.path.abspath(f)] = per
    with open(out, 'w', encoding='utf-8') as fh:
        json.dump(result, fh, ensure_ascii=False, indent=1)

if __name__ == '__main__':
    main()

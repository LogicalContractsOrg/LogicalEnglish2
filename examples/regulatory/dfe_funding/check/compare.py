"""Compare the Python reading with the Logical English program, output by output.

    python3 check/compare.py REF_OUT.jsonl LE_OUT.jsonl [N]

REF_OUT is the output of ref/run_ref.py --no-intermediate, LE_OUT that of
run_le.pl, on the same cases; N is how many differing cases to show per
output (4 by default)."""
import json, re, sys, os, collections
def const(s): return re.sub(r'[^a-z0-9]+','_',str(s).lower()).strip('_')
ref={}
for l in open(sys.argv[1]):
    d=json.loads(l); ref['case_'+const(os.path.splitext(os.path.basename(d['case']))[0])]=d['out']
le={}
for l in open(sys.argv[2]):
    d=json.loads(l); le[d['case']]=d['out']
def same(a,b):
    if isinstance(a,(int,float)) and isinstance(b,(int,float)) and not isinstance(a,bool) and not isinstance(b,bool):
        return abs(a-b)<=1e-6*max(1,abs(a),abs(b))
    return a==b
diff=collections.defaultdict(list); total=agree=0
for c in sorted(ref):
    if c not in le: print('missing in LE',c); continue
    for k,v in ref[c].items():
        if k.startswith('_') or k=='LearnRefNumber': continue
        total+=1
        w=le[c].get(k,'<absent>')
        if same(v,w): agree+=1
        else: diff[k].append((c,v,w))
print(f'{agree}/{total} agree; {len(ref)} cases')
for k in sorted(diff, key=lambda k:-len(diff[k])):
    print(f'== {k}: {len(diff[k])}')
    for c,v,w in diff[k][:int(sys.argv[3]) if len(sys.argv)>3 else 4]: print(f'   {c}: ref={v!r} le={w!r}')

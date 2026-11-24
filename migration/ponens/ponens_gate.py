#!/usr/bin/env python3
"""The gate of the Ponens translator: every twin, on every trace, against Ponens.

For each policy pack of a Ponens checkout's gallery: the pack's policies are
written as one policy file; Ponens's own evaluator checks each trace against
them (`ponens trace check --policy-file … --json`, the oracle); the twin of
the pack is written with the traces as its scenarios (ponens_build.pl); each
scenario is run by LPS2; and the breaches the twin records are compared with
Ponens's verdicts, policy by policy:

  - a policy Ponens fails is broken in the twin, and a policy it passes is not;
  - for a policy `G(φ)`, the steps the twin breaks it at are the actions
    Ponens names as violating it.

    python3 ponens_gate.py --ponens REPO [--traces own|all] [--packs P …] [--out runs/gate]

Needs: the `ponens` package (its CLI on PATH or --ponens-cli), SWI-Prolog
with LE2 (LE2_DIR, default /work), LPS2 (LPS2_DIR, default /lps2).
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
LE2 = os.environ.get('LE2_DIR', os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')))
LPS2 = os.environ.get('LPS2_DIR', os.path.join(os.path.dirname(LE2), 'lps2'))

#  The traces of each pack in Ponens's examples/ (own); the packs without
#  examples of their own use the top-level samples.
OWN = {
    'esma-mifid-ai-investment-services': ['esma_mifid_ai/*.json'],
    'iosco-supervisory-recordkeeping': ['iosco_recordkeeping/*.json'],
    'cms-ai-guidance': ['cms/*.json'],
    'nist-ai-rmf': ['nist_ai_rmf/*.json'],
    'nist-ssdf': ['ssdf/*.json'],
    'cert-secure-coding': ['cert/*.json'],
    'do-178c-software-assurance': ['do178c/*.json'],
    'jsf-av-cpp': ['jsf/*.json'],
    'misra-c': ['misra/misra_c_*.json'],
    'misra-cpp': ['misra/misra_cpp_*.json'],
    'agentic-ai-runtime-governance': ['agentic_governance/*.json', 'fix_ai_wg/*.json'],
    'ipl-fix-certification': ['*.json'],
    'apply-formal-methods': ['*.json'],
    'ponens-defaults': ['*.json'],
}


def all_traces(repo):
    out = []
    for f in sorted(glob.glob(os.path.join(repo, 'examples', '*.json')) +
                    glob.glob(os.path.join(repo, 'examples', '*', '*.json'))):
        if f.endswith('manifest.json') or f.endswith('.walk.json'):
            continue
        try:
            d = json.load(open(f))
        except Exception:
            continue
        if isinstance(d, dict) and d.get('actions'):
            out.append(f)
    return out


def scenario_name(repo, f):
    rel = os.path.relpath(f, os.path.join(repo, 'examples'))
    n = re.sub(r'\.json$', '', rel)
    n = re.sub(r'[^A-Za-z0-9]+', '_', n).strip('_').lower()
    if not n[0].isalpha():
        n = 't_' + n
    return n


def swipl(goal):
    r = subprocess.run([os.path.join(LE2, 'myswipl.sh'), '-q', '-g', goal, '-t', 'halt'],
                       cwd=LE2, capture_output=True, text=True, timeout=1800)
    if r.returncode != 0:
        sys.stderr.write(r.stderr[-3000:])
        raise SystemExit(f'swipl failed: {goal[:200]}')
    return r.stdout


def packs_of(gallery):
    packs = set()
    for f in glob.glob(os.path.join(gallery, 'policies', '*.json')):
        if os.path.basename(f).startswith('_'):
            continue
        p = json.load(open(f))
        packs.add(p.get('pack') or 'ponens-defaults')
    return sorted(packs)


def oracle(cli, trace, policy_file):
    r = subprocess.run([cli, 'trace', 'check', trace, '--policy-file', policy_file, '--json'],
                       capture_output=True, text=True, timeout=600)
    try:
        return json.loads(r.stdout)
    except Exception:
        return None


def lps_breaches(twin, scenario):
    env = dict(os.environ, LPS_LE2_LIB=LE2)
    r = subprocess.run([os.path.join(LPS2, 'lps'), 'run', twin, '--scenario', scenario],
                       capture_output=True, text=True, timeout=900, env=env, cwd=os.path.dirname(twin))
    lines = [l for l in r.stdout.splitlines() if l.startswith('fluents/')]
    if not lines:
        return None, (r.stdout + r.stderr)[-2000:]
    last = lines[-1]
    at = {}
    for p, s in re.findall(r"broken_at\(([^,()]+),(\d+)\)", last):
        at.setdefault(p.strip("'"), set()).add(int(s))
    whole = {p.strip("'") for p in re.findall(r"broken\(([^,()]+)\)", last)}
    return (at, whole), None


def run_all(twin, names, work):
    """Every scenario of the twin, in one LPS2 process (ponens_run.pl)."""
    nf = os.path.join(work, 'names.json')
    of = os.path.join(work, 'runs.json')
    json.dump(names, open(nf, 'w'))
    env = dict(os.environ, LPS_LE2_LIB=LE2, LPS2_DIR=LPS2)
    with open(os.path.join(work, 'runs.log'), 'w') as log:
        subprocess.run(['swipl', '-q', '-g', f"consult('{HERE}/ponens_run'), run_scenarios('{twin}', '{nf}', '{of}')",
                        '-t', 'halt'], stdout=log, stderr=log, text=True, timeout=7200, env=env, cwd=LE2)
    try:
        return json.load(open(of))
    except Exception:
        return {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ponens', required=True, help='a checkout of github.com/imandra-ai/ponens')
    ap.add_argument('--ponens-cli', default='ponens')
    ap.add_argument('--traces', default='all', choices=['own', 'all'])
    ap.add_argument('--packs', nargs='*')
    ap.add_argument('--out', default=os.path.join(HERE, 'runs', 'gate'))
    a = ap.parse_args()

    gallery = os.path.join(a.ponens, 'gallery')
    os.makedirs(a.out, exist_ok=True)
    traces_all = all_traces(a.ponens)
    packs = a.packs or packs_of(gallery)
    summary = []
    total = agree = 0
    global global_back
    global_back = [0, 0]
    for pack in packs:
        work = os.path.join(a.out, pack)
        os.makedirs(work, exist_ok=True)
        pf = os.path.join(work, 'policies.json')
        swipl(f"use_module('{HERE}/ponens_build'), write_policy_file('{gallery}', '{pack}', '{pf}')")
        if a.traces == 'own':
            files = sorted({f for g in OWN.get(pack, ['*.json'])
                            for f in glob.glob(os.path.join(a.ponens, 'examples', g))
                            if f in traces_all})
        else:
            files = traces_all
        specs = []
        verdicts = {}
        for f in files:
            name = scenario_name(a.ponens, f)
            v = oracle(a.ponens_cli, f, pf)
            vf = os.path.join(work, name + '.verdicts.json')
            json.dump(v if v is not None else [], open(vf, 'w'), indent=1)
            verdicts[name] = v
            specs.append({'name': name, 'file': f, 'verdicts': vf})
        tj = os.path.join(work, 'traces.json')
        json.dump(specs, open(tj, 'w'), indent=1)
        twin = os.path.join(work, pack.replace('-', '_') + '.le')
        ledger = os.path.join(work, pack.replace('-', '_') + '.ledger.json')
        swipl(f"use_module('{HERE}/ponens_build'), build_twin('{gallery}', '{pack}', '{tj}', '{twin}', '{ledger}')")
        rows = []
        runs = run_all(twin, [s['name'] for s in specs], work)
        for s in specs:
            v = verdicts[s['name']]
            got = runs.get(s['name'])
            if v is None or got is None or 'error' in got:
                rows.append((s['name'], None, None, (got or {}).get('error', 'no oracle')))
                continue
            at, whole = {}, set(got['whole'])
            for p_, s_ in got['at']:
                at.setdefault(p_, set()).add(s_)
            for pv in v:
                pid = pv['policy_id']
                status = pv['status']
                if status not in ('passed', 'failed'):
                    rows.append((s['name'], pid, 'skipped', status))
                    continue
                ponens_fail = status == 'failed'
                ours_fail = pid in at or pid in whole
                ids = set(pv.get('violating_action_ids') or [])
                ok = ponens_fail == ours_fail and (not ids or pid in whole or at.get(pid, set()) == ids)
                total += 1
                agree += ok
                rows.append((s['name'], pid, 'ok' if ok else 'DIFF',
                             '' if ok else f'ponens {status} {sorted(ids)}; twin {sorted(at.get(pid, []))}{" whole" if pid in whole else ""}'))
        # The way back: the twin's laws written back as Ponens policies, checked by Ponens
        back = os.path.join(work, 'policies_back.json')
        swipl(f"use_module('{LE2}/le_kbs'), use_module('{LE2}/le_lps'), use_module('{HERE}/ponens_writer'), write_policies('{twin}', '{back}')")
        back_pol = {p['policy_id']: p for p in json.load(open(back))}
        orig_pol = {p['policy_id']: p for p in json.load(open(pf))}
        wb_total = wb_ok = 0
        for s in specs:
            v1 = verdicts[s['name']] or []
            v2 = oracle(a.ponens_cli, s['file'], back) or []
            m2 = {x['policy_id']: x for x in v2}
            for x in v1:
                pid = x['policy_id']
                if x['status'] not in ('passed', 'failed'):
                    continue
                y = m2.get(pid)
                wb_total += 1
                if y and y['status'] == x['status'] and sorted(y.get('violating_action_ids') or []) == sorted(x.get('violating_action_ids') or []):
                    wb_ok += 1
                else:
                    rows.append((s['name'], pid, 'BACKDIFF', f"original {x['status']} {x.get('violating_action_ids')}; written back {y and y['status']} {y and y.get('violating_action_ids')}; formula {back_pol.get(pid, {}).get('formula')}"))
        missing = sorted(set(orig_pol) - set(back_pol))
        global_back[0] += wb_ok
        global_back[1] += wb_total
        with open(os.path.join(work, 'gate.txt'), 'w') as g:
            for r in rows:
                g.write('\t'.join(str(x) for x in r) + '\n')
        n_ok = sum(1 for r in rows if r[2] == 'ok')
        n = sum(1 for r in rows if r[2] in ('ok', 'DIFF'))
        diffs = [r for r in rows if r[2] in ('DIFF', 'BACKDIFF') or r[1] is None]
        summary.append((pack, len(files), n_ok, n, wb_ok, wb_total, ','.join(missing)))
        print(f'{pack}: {len(files)} traces, {n_ok}/{n} verdicts agree; written back {wb_ok}/{wb_total}'
              + (f'; not written back: {missing}' if missing else '') + (f', {len(diffs)} to look at' if diffs else ''))
        for r in diffs[:8]:
            print('   ', r)
    print(f'ALL: {agree}/{total} verdicts agree; written back {global_back[0]}/{global_back[1]}')
    with open(os.path.join(a.out, 'summary.txt'), 'w') as g:
        for p in summary:
            g.write('\t'.join(str(x) for x in p) + '\n')
        g.write(f'ALL\t{agree}/{total}\twritten back\t{global_back[0]}/{global_back[1]}\n')


if __name__ == '__main__':
    main()

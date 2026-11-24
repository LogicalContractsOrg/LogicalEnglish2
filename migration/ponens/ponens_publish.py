#!/usr/bin/env python3
"""The Ponens twins, published: one folder per policy pack in LPS2's examples.

    python3 ponens_publish.py --ponens REPO [--to /lps2/examples/migration/ponens]

For each pack of the gallery (and Ponens's own default policies, the pack
`ponens-defaults`): the twin, with the pack's own example traces as its
scenarios (ponens_gate.OWN), Ponens's verdicts on them in the comment above
each scenario, the ledger, a README, and under sources/ what it was written
from: the policies, the pack's description and specification, the
organization's page, the traces and Ponens's verdicts, and Ponens's licence
(MIT, which allows the twins to be published).
"""
import argparse
import glob
import json
import os
import re
import shutil
import subprocess

import ponens_gate as G

HERE = os.path.dirname(os.path.abspath(__file__))


def folder_name(pack):
    return pack.replace('-', '_')


def short_name(path):
    n = re.sub(r'\.json$', '', os.path.basename(path))
    n = re.sub(r'[^A-Za-z0-9]+', '_', n).strip('_').lower()
    return n if n[0].isalpha() else 't_' + n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ponens', required=True)
    ap.add_argument('--ponens-cli', default='ponens')
    ap.add_argument('--to', default=os.path.join(G.LPS2, 'examples', 'migration', 'ponens'))
    ap.add_argument('--packs', nargs='*')
    a = ap.parse_args()
    gallery = os.path.join(a.ponens, 'gallery')
    traces_all = G.all_traces(a.ponens)
    commit = subprocess.run(['git', '-C', a.ponens, 'log', '-1', '--format=%h %cs'],
                            capture_output=True, text=True).stdout.strip()
    packs = a.packs or G.packs_of(gallery)
    index = []
    for pack in packs:
        out = os.path.join(a.to, folder_name(pack))
        src = os.path.join(out, 'sources')
        if os.path.isdir(out):
            shutil.rmtree(out)
        os.makedirs(os.path.join(src, 'policies'))
        os.makedirs(os.path.join(src, 'traces'))
        pf = os.path.join(src, 'policies.json')
        G.swipl(f"use_module('{HERE}/ponens_build'), write_policy_file('{gallery}', '{pack}', '{pf}')")
        pol_ids = [p['policy_id'] for p in json.load(open(pf))]
        for pid in pol_ids:
            shutil.copy(os.path.join(gallery, 'policies', pid + '.json'), os.path.join(src, 'policies'))
        meta = {}
        pj = os.path.join(gallery, 'packs', pack + '.json')
        if os.path.exists(pj):
            shutil.copy(pj, os.path.join(src, 'pack.json'))
            meta = json.load(open(pj))
            spec = meta.get('spec')
            if spec:
                sp = os.path.join(a.ponens, spec.lstrip('/') + '.md')
                if os.path.exists(sp):
                    shutil.copy(sp, os.path.join(src, os.path.basename(sp)))
            org = meta.get('org')
            if org:
                oj = os.path.join(gallery, 'organizations', org + '.json')
                if os.path.exists(oj):
                    shutil.copy(oj, os.path.join(src, 'organization.json'))
        shutil.copy(os.path.join(a.ponens, 'LICENSE'), os.path.join(src, 'LICENSE'))
        files = sorted({f for g in G.OWN.get(pack, ['*.json'])
                        for f in glob.glob(os.path.join(a.ponens, 'examples', g)) if f in traces_all})
        specs = []
        failing = 0
        for f in files:
            name = short_name(f)
            if any(s['name'] == name for s in specs):
                name = short_name(os.path.dirname(f) + '_' + os.path.basename(f))
            dst = os.path.join(src, 'traces', name + '.json')
            shutil.copy(f, dst)
            v = G.oracle(a.ponens_cli, f, pf) or []
            failing += sum(1 for x in v if x.get('status') == 'failed')
            vf = os.path.join(src, 'traces', name + '.verdicts.json')
            json.dump(v, open(vf, 'w'), indent=1)
            specs.append({'name': name, 'file': dst, 'verdicts': vf})
        tj = os.path.join(out, '.traces.json')
        json.dump(specs, open(tj, 'w'), indent=1)
        twin = os.path.join(out, folder_name(pack) + '.le')
        ledger = os.path.join(out, folder_name(pack) + '.ledger.json')
        G.swipl(f"use_module('{HERE}/ponens_build'), build_twin('{gallery}', '{pack}', '{tj}', '{twin}', '{ledger}')")
        os.remove(tj)
        title = meta.get('name') or "Ponens's own policies"
        summary = meta.get('summary') or ('The policies of Ponens that belong to no pack: '
                                          'how an AI coding agent should work (read before editing, '
                                          'test before committing, prove before a high-stakes change).')
        counts = json.load(open(ledger))['counts']
        with open(os.path.join(out, 'README.md'), 'w') as r:
            r.write(f"# {title}\n\n")
            r.write(f"{summary}\n\n")
            r.write(f"The {len(pol_ids)} policies of the Ponens pack `{pack}`, as a program of Logical "
                    f"English for LPS: each policy is a law that records a breach, and each of the "
                    f"{len(specs)} traces under `sources/traces/` is a scenario. Choose a scenario and "
                    f"press **Run**: the breaches are on the timeline, at the step where each policy "
                    f"failed, and the comment above each scenario says what Ponens's own evaluator "
                    f"found on the same trace.\n\n")
            r.write(f"Ledger: {counts.get('encoded', 0)} policies encoded, {counts.get('residue', 0)} kept as residue "
                    f"(formulas Ponens's own parser cannot read).\n\n")
            if meta.get('source'):
                r.write(f"The pack restates: {meta['source']}\n\n")
            r.write(f"Written by Logical English's Ponens translator from github.com/imandra-ai/ponens "
                    f"(commit {commit}, MIT licence; `sources/LICENSE`).\n")
        index.append((folder_name(pack), title, len(pol_ids), len(specs), counts))
        print(f'{pack}: {len(pol_ids)} policies, {len(specs)} traces, {counts}')
    with open(os.path.join(a.to, 'README.md'), 'w') as r:
        r.write("# Ponens policies in Logical English for LPS\n\n")
        r.write("Ponens (github.com/imandra-ai/ponens, MIT licence) checks the record of an AI "
                "agent's session, a *trace*, against *policies* written in a temporal logic. Each folder "
                "here is one of its policy packs as a program of Logical English for LPS. Each policy is "
                "a causal law that records a breach at the step where the policy fails, and each trace "
                "is a scenario. The comment above each scenario says what Ponens's own evaluator found "
                "on the same trace.\n\n")
        r.write("| Pack | Policies | Traces | Encoded | Residue |\n|---|---|---|---|---|\n")
        for f, t, n, nt, c in index:
            r.write(f"| [{t}]({f}/) | {n} | {nt} | {c.get('encoded', 0)} | {c.get('residue', 0)} |\n")
        r.write("\nHow the translation works, and how it was checked: the integration guide, "
                "[Ponens policies](/docs/user/integrations/ponens).\n")


if __name__ == '__main__':
    main()

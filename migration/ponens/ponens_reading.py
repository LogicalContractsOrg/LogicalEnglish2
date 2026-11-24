#!/usr/bin/env python3
"""A Ponens trace as Ponens reads it: the facts the twin's scenarios state.

The twin of a policy pack (ponens_twin.pl) translates the POLICIES: their
temporal and logical structure becomes causal laws and conditions of a Logical
English program for LPS. What each atom of a policy means at an action of a
trace — an action type, a keyword in the action's text, a verification
result, the oracle that produced an artifact — and which earlier actions are
in an action's dependency chain or on its target, is Ponens's own reading of
its own trace format. This helper asks Ponens's code for that reading, so the
scenarios state exactly the facts Ponens's evaluator sees:

    python3 ponens_reading.py TRACE.json ATOMS.json > READING.json

ATOMS.json is a list of formula texts, each an atomic node of the pack's
policies (`VerificationResult(proved ∨ sat)`, `suitability_assessed`,
`rationale ≠ ∅`, …). The output:

    {"actions":   [{"id": 3, "true": [<atom text>, …], "inputs": [...], "outputs": [...]}, …],
     "trace_true": [<atom text>, …],             # atoms that hold of the trace (start_event, end_event)
     "chain":     [[b, a], …],                   # b < a, b in a's dependency chain (P_chain)
     "target":    [[b, a], …],                   # b < a, b on a's target lineage (P_target)
     "collections": {"residuals": [...], "telemetry": [...], "criteria": [...]},
     "structural": {...}}                        # the facts Ponens's structural policies read

It needs the `ponens` package (pip install ponens, or the repository's cli/).
"""
import json
import sys

from ponens import trace as T
from ponens import lineage
from ponens.policy_compiler import Parser, tokenize


def parse(text):
    return Parser(tokenize(text), text, '').parse()


def holds(node, trace, action):
    try:
        v = T.evaluate_formula(node, trace, {'action': action} if action is not None else None)
    except Exception:
        return False
    return v is True


def main(trace_file, atoms_file):
    trace = T.load_trace(trace_file, warn_invalid=False)
    T.normalize_trace(trace)
    atoms = json.load(open(atoms_file, encoding='utf-8'))
    nodes = [(a, parse(a)) for a in atoms]
    actions = sorted(trace.get('actions', []), key=lambda a: a['id'])

    out_actions = []
    for a in actions:
        out_actions.append({
            'id': a['id'],
            'type': a.get('type'),
            'true': [text for text, node in nodes if holds(node, trace, a)],
            'inputs': list(a.get('_original_inputs', a.get('inputs', []))),
            'outputs': list(a.get('_original_outputs', a.get('outputs', []))),
        })

    trace_true = [text for text, node in nodes if holds(node, trace, None)]

    chain, target = [], []
    for a in actions:
        cur_targets = T.get_target_lineage(a, trace)
        for b in actions:
            if b['id'] >= a['id']:
                continue
            if T.in_dependency_chain(b, a, trace):
                chain.append([b['id'], a['id']])
            if cur_targets and (T.get_action_target(b, trace) in cur_targets
                                or bool(T.get_target_lineage(b, trace) & cur_targets)):
                target.append([b['id'], a['id']])

    def flat(items, key, lower=True):
        res = []
        for i, it in enumerate(items):
            if not isinstance(it, dict):
                continue
            fields = {}
            for k, v in it.items():
                if isinstance(v, bool):
                    fields[k] = 'yes' if v else 'no'
                elif isinstance(v, str) and v.strip():
                    # Ponens compares field values case-insensitively (_eval_compare); its residual
                    # policies compare them as they are (evaluate_structural)
                    fields[k] = v.lower() if lower else v
                elif isinstance(v, (int, float)):
                    fields[k] = v
                elif isinstance(v, list) and v:
                    fields[k] = ','.join(str(x) for x in v)
            res.append({'id': str(it.get(key) or f'{key}_{i + 1}'), 'fields': fields})
        return res

    #  the fields Ponens's residual policies read (trace.py evaluate_structural)
    residuals = []
    for r in lineage.residual_surface(trace):
        r = dict(r)
        r['status'] = r.get('status', 'open')
        sc = r.get('suggested_check')
        r.pop('suggested_check', None)
        if isinstance(sc, str) and sc.strip():
            r['suggested_check'] = 'given'
        if r.get('target') or r.get('related_artifact_ids'):
            r['located'] = 'yes'
        residuals.append(r)
    collections = {
        'residuals': flat(residuals, 'residual_id', lower=False),
        'telemetry': flat(trace.get('telemetry', []) or [], 'span_id'),
        'criteria': flat(T._criteria(trace), 'id'),
    }

    # What the structural policies read (trace.py, evaluate_structural)
    output_map = {}
    for a in actions:
        for o in a.get('_original_outputs', a.get('outputs', [])):
            output_map[o] = a['id']
    for art in trace.get('artifacts', []):
        if art.get('producer_action_id') is not None:
            output_map[art['artifact_id']] = art['producer_action_id']
    edited = sorted({ev['ref'] for a in trace.get('actions', [])
                     if a.get('type') in ('EditFile', 'CreateFile', 'DeleteFile')
                     for ev in a.get('evidence', []) if ev.get('type') == 'FileRef'})
    artifacts = []
    for art in trace.get('artifacts', []):
        payload = art.get('payload') or {}
        artifacts.append({
            'id': art.get('artifact_id'),
            'type': T._canon_type(art.get('artifact_type')),
            'raw_type': art.get('artifact_type'),
            'derived_from': list(art.get('derived_from', []) or []),
            'target_artifact_id': payload.get('target_artifact_id') if isinstance(payload, dict) else None,
        })
    structural = {
        'made_by': [[k, v] for k, v in sorted(output_map.items(), key=lambda kv: str(kv[0]))],
        'edited_files': edited,
        'declared_files': sorted(set(trace.get('files_modified', []) or [])),
        'artifacts': artifacts,
        'has_commit': any(a.get('type') == 'GitCommit' for a in trace.get('actions', [])),
    }

    json.dump({'trace_id': trace.get('trace_id'), 'actions': out_actions, 'trace_true': trace_true,
               'chain': chain, 'target': target, 'collections': collections,
               'structural': structural}, sys.stdout, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])

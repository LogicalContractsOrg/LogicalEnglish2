#!/usr/bin/env python3
"""The corpus as the engine loads it: .cache/root/rulespec-us.

The engine reads a checkout named rulespec-<country> holding only its
jurisdiction folders, and refuses the whole root when one file breaks its
rules. rulespec-us at the pinned commit lists 643 modules its own pinned engine
does not load (tools/known-engine-load-failures.txt); every class of those
failures but one is metadata the engine does not execute. This copies the
jurisdiction folders and normalises only that metadata:

  - module.source_verification keeps the fields the engine knows
    (corpus_citation_path, source_sha256, upstream_source_check); a list of
    citation paths keeps its first ("plural-corpus-citation-paths"); the
    `values` block, a copy of the parameter values for the corpus checker,
    is dropped ("source-verification-unknown-field");
  - files and folders whose names the engine refuses (`47:294.yaml`,
    `He-W 704`, an en dash) are left out ("invalid-filesystem-path").

Rules, formulas, versions, imports and tests are copied byte for byte; a
normalised file is written back with its rules untouched (PyYAML, keys in
their order). The list of what was changed is written to
.cache/root/normalised.txt.
"""
import os, re, shutil, sys, yaml

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '.cache', 'rulespec-us')
DST = os.path.join(HERE, '.cache', 'root', 'rulespec-us')
OK_NAME = re.compile(r'^[A-Za-z0-9_.\-]+$')
KNOWN = ('corpus_citation_path', 'source_sha256', 'upstream_source_check')


class Keep(yaml.SafeDumper):
    pass


def _str(d, s):
    style = '|' if '\n' in s else None
    return d.represent_scalar('tag:yaml.org,2002:str', s, style=style)


Keep.add_representer(str, _str)


def normalise(path):
    with open(path) as f:
        text = f.read()
    if 'source_verification' not in text:
        return None
    d = yaml.safe_load(text)
    sv = (d.get('module') or {}).get('source_verification') if isinstance(d, dict) else None
    if not isinstance(sv, dict):
        return None
    why = []
    cp = sv.get('corpus_citation_path')
    if isinstance(cp, list):
        sv['corpus_citation_path'] = cp[0] if cp else ''
        why.append('plural-corpus-citation-paths')
    for k in list(sv):
        if k not in KNOWN:
            del sv[k]
            why.append('source-verification-unknown-field:' + k)
    if not why:
        return None
    if not sv.get('corpus_citation_path'):
        del d['module']['source_verification']
        why.append('source-verification-emptied')
    with open(path, 'w') as f:
        yaml.dump(d, f, Dumper=Keep, sort_keys=False, allow_unicode=True, width=1000)
    return why


def main():
    if os.path.isdir(DST):
        shutil.rmtree(DST)
    os.makedirs(DST)
    changed, skipped = [], []
    for j in sorted(os.listdir(SRC)):
        if not re.match(r'^us(-[a-z]{2})?$', j):
            continue
        for root, dirs, files in os.walk(os.path.join(SRC, j)):
            rel = os.path.relpath(root, SRC)
            for dname in list(dirs):
                if not OK_NAME.match(dname):
                    skipped.append(os.path.join(rel, dname) + '/')
                    dirs.remove(dname)
            os.makedirs(os.path.join(DST, rel), exist_ok=True)
            for fn in files:
                if not OK_NAME.match(fn) or fn.count('.yaml') > 1 and not fn.endswith('.test.yaml'):
                    skipped.append(os.path.join(rel, fn))
                    continue
                out = os.path.join(DST, rel, fn)
                shutil.copyfile(os.path.join(root, fn), out)
                if fn.endswith('.yaml') and not fn.endswith('.test.yaml'):
                    why = normalise(out)
                    if why:
                        changed.append(os.path.join(rel, fn) + '\t' + ','.join(why))
    with open(os.path.join(HERE, '.cache', 'root', 'normalised.txt'), 'w') as f:
        f.write('# normalised (metadata only)\n' + '\n'.join(changed) +
                '\n# left out (names the engine refuses)\n' + '\n'.join(skipped) + '\n')
    print(f'{len(changed)} files normalised, {len(skipped)} paths left out -> {DST}')


if __name__ == '__main__':
    sys.exit(main())

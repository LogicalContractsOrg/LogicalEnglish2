"""The measure of a twin (the design notes rune.md §5), from the files that
check.pl writes (<group>.le.check.txt): per group and in total, how many of
DRR's expected field values the twin gives, and the fields where it differs.

    python3 summary.py <report>          # e.g. cftc_part45
    > runs/<report>.txt

A field value agrees when the twin's report has it; it is missing when DRR's
report has it and the twin's does not; it is extra the other way round.
"""
import collections, glob, os, re, sys

def main(base):
    here = os.path.dirname(os.path.abspath(__file__))
    private = os.environ.get('LE_PRIVATE_TWINS_DIR', os.path.join(here, '../../../lpsPlus'))
    d = os.path.join(private, 'examples/migration/rune', base)
    per_field = collections.defaultdict(lambda: [0, 0])
    rows, tot = [], [0, 0, 0, 0]
    for f in sorted(glob.glob(os.path.join(d, '*.le.check.txt'))):
        g = os.path.basename(f)[:-len('.le.check.txt')]
        if g.startswith('zz_'):
            continue
        a = m = x = n = 0
        for line in open(f, errors='replace'):
            h = re.match(r'\S+: (\d+) agree, (\d+) missing, (\d+) extra', line)
            if h:
                a += int(h.group(1)); m += int(h.group(2)); x += int(h.group(3)); n += 1
                continue
            k = re.match(r'\s+(missing|extra):\s+.* field (.*) of instruction is ', line)
            if k:
                per_field[k.group(2)][0 if k.group(1) == 'missing' else 1] += 1
        rows.append((g, n, a, m, x))
        for i, v in enumerate((n, a, m, x)):
            tot[i] += v
    n, a, m, x = tot
    print(f"{a} of {a + m} expected field values agree ({100.0 * a / max(a + m, 1):.1f}%), "
          f"{m} missing, {x} extra, in {n} instructions")
    print()
    print("| Group | Instructions | Agree | Missing | Extra |")
    print("|---|---|---|---|---|")
    for g, n, a, m, x in rows:
        print(f"| {g} | {n} | {a} | {m} | {x} |")
    print()
    print("| Field | Missing | Extra |")
    print("|---|---|---|")
    for k, (m, x) in sorted(per_field.items(), key=lambda kv: (-sum(kv[1]), kv[0])):
        print(f"| {k} | {m} | {x} |")

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'cftc_part45')

"""The fields of a DRR report as its generated Java computes them: the
mapping from a field's path to its rule, read from the report function's
assignOutput (DRR's own compiled mapping). Used to check the mapping the
reader derives from the Rune annotations (rune_closure.pl report_fields/2).

    python3 java_fields.py <ReportFunction.java>   ->  "path<TAB>rule" lines
"""
import re, sys

def fields(path):
    src = open(path).read()
    imports = dict((m.group(2), m.group(1)) for m in re.finditer(r'import ([\w.]+)\.(\w+);', src))
    own = re.search(r'^package ([\w.]+);', src, re.M).group(1)
    body = src[src.index('assignOutput('):]
    body = body[body.index('{') + 1:]
    temps = {}
    out = []
    for stmt in body.split(';'):
        s = ' '.join(stmt.split())
        m = re.match(r'final [\w<>.]+ (\w+) = (\w+)\.evaluate\(input\)', s)
        if m:
            temps[m.group(1)] = m.group(2)
            continue
        if not s.startswith('output'):
            continue
        chain = re.findall(r'\.getOrCreate(\w+)\(\)', s)
        m = re.search(r'\.(set|add)(\w+?)(?:OverriddenAs\w+)?\(\(?(?:MapperC\.of\()?(\w+)(?:\.evaluate\(input\))?(?: == null \? null : \w+\.\w+\(\)\))?\)', s)
        if not m:
            continue
        field, arg = m.group(2), m.group(3)
        if arg == 'null':
            continue    # a field DRR does not report here
        rule_var = temps.get(arg, arg)
        cls = rule_var[0].upper() + rule_var[1:]
        pkg = imports.get(cls, own)
        ns = pkg[:-len('.reports')] if pkg.endswith('.reports') else pkg
        rule = ns + '.' + (cls[:-4] if cls.endswith('Rule') else cls)
        p = [c[0].lower() + c[1:] for c in chain] + [field[0].lower() + field[1:]]
        out.append(('.'.join(p), rule))
    return out

if __name__ == '__main__':
    for p, r in fields(sys.argv[1]):
        print(f'{p}\t{r}')

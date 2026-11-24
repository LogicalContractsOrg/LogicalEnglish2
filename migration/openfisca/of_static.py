#!/usr/bin/env python3
"""An OpenFisca or PolicyEngine package read from its files, without its engine.

    of_static.py <dir> <out dir> [<programme>]

For File > Open of an upload (a zip of a country package, or a folder of
variable files with parameter YAML and tests beside them), where the
package cannot be installed: the variables are read from their Python with
`ast` (class attributes and formula methods, never executed), the parameters
from their YAML as OpenFisca reads them (`values` with dates, `brackets`,
nested folders and files), and the result stands in for a loaded
TaxBenefitSystem, so of_extract.py translates it exactly as it translates an
installed package. A variable a formula reads that the upload does not
define is an input the scenarios state. Without the engine there is no
oracle: the expected answers are the test files' own.

Writes <out>/of/<programme>.yaml, .test.yaml and .json, as of_extract.py does.
"""
import ast, os, re, sys, textwrap, types, yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import of_extract  # noqa: E402

ENTITY_KEYS = {'Person': 'person', 'Household': 'household', 'SPMUnit': 'spm_unit', 'SpmUnit': 'spm_unit',
               'TaxUnit': 'tax_unit', 'Family': 'family', 'MaritalUnit': 'marital_unit', 'BenUnit': 'benunit',
               'Individu': 'individu', 'Famille': 'famille', 'Menage': 'menage', 'FoyerFiscal': 'foyer_fiscal'}


class Entity:
    def __init__(self, key):
        self.key = key


class Formula:
    def __init__(self, src, file):
        self.__of_source__ = src
        self.__of_file__ = file


class Named:
    def __init__(self, name):
        self.__name__ = name


class Var:
    pass


class EnumType:
    __name__ = 'Enum'


class Value:
    def __init__(self, instant, value):
        self.instant_str, self.value = instant, value


class Node:
    def __init__(self, children=None, metadata=None, file_path=None, description=None):
        self.children = children or {}
        self.metadata = metadata or {}
        self.file_path = file_path
        self.description = description


class Leaf:
    def __init__(self, values, metadata=None, file_path=None, description=None):
        self.values_list = values
        self.metadata = metadata or {}
        self.file_path = file_path
        self.description = description


class Bracket:
    def __init__(self, children):
        self.children = children


class Scale(Node):
    def __init__(self, brackets, metadata=None, file_path=None, description=None):
        super().__init__({}, metadata, file_path, description)
        self.brackets = brackets


def leaf_values(d):
    out = []
    for k, v in (d or {}).items():
        if isinstance(v, dict):
            v = v.get('value')
        if isinstance(v, str) and v == 'expected':
            continue                       # a placeholder: no value yet (OpenFisca ignores it)
        out.append(Value(str(k), v))
    return out


def param_from(d, path):
    """A parameter, as OpenFisca reads a YAML document."""
    if isinstance(d, dict) and 'brackets' in d:
        brackets = []
        for b in d['brackets'] or []:
            brackets.append(Bracket({k: Leaf(leaf_values(v), file_path=path) for k, v in b.items()
                                     if k in ('threshold', 'rate', 'amount', 'average_rate')}))
        return Scale(brackets, d.get('metadata'), path, d.get('description'))
    if isinstance(d, dict) and 'values' in d:
        return Leaf(leaf_values(d['values']), d.get('metadata'), path, d.get('description'))
    if isinstance(d, dict):
        kids = {k: param_from(v, path) for k, v in d.items() if k not in ('metadata', 'description', 'documentation')}
        return Node(kids, d.get('metadata'), path, d.get('description'))
    return Leaf([Value('0001-01-01', d)], file_path=path)


def param_tree(folder):
    node = Node(file_path=folder)
    for name in sorted(os.listdir(folder)):
        p = os.path.join(folder, name)
        if os.path.isdir(p):
            node.children[name] = param_tree(p)
        elif name.endswith('.yaml') or name.endswith('.yml'):
            key = re.sub(r'\.ya?ml$', '', name)
            try:
                d = yaml.safe_load(open(p))
            except Exception:
                continue
            if key == 'index':
                if isinstance(d, dict):
                    node.metadata = d.get('metadata') or {}
                    node.description = d.get('description')
                continue
            node.children[key] = param_from(d, p)
    return node


def value_of(n):
    if isinstance(n, ast.Constant):
        return n.value
    if isinstance(n, (ast.List, ast.Tuple)):
        return [value_of(e) for e in n.elts]
    if isinstance(n, ast.Name):
        return ('name', n.id)
    if isinstance(n, ast.Attribute):
        return ('attr', value_of(n.value), n.attr)
    return None


def read_variables(folder):
    variables, enums = {}, {}
    for root, dirs, files in os.walk(folder):
        #  A reform is another program: it replaces a variable of the package
        #  with its own, and reading its file as the package's own put the
        #  reform's rule in the twin under the law's name. (The country
        #  template's reform makes the social security contribution 3% of the
        #  salary flat, where the law has a marginal scale with three
        #  brackets and dated rates: the upload then answered 60 € where the
        #  package's own test expects 40 €, in five of its 35 cases.) The
        #  package path leaves reforms out too: a test naming one is not
        #  converted.
        dirs[:] = [d for d in dirs if d not in ('__pycache__', 'reforms')]
        for fn in sorted(files):
            if not fn.endswith('.py'):
                continue
            path = os.path.join(root, fn)
            src = open(path).read()
            try:
                tree = ast.parse(src)
            except SyntaxError:
                continue
            lines = src.split('\n')
            for cls in [n for n in tree.body if isinstance(n, ast.ClassDef)]:
                bases = [getattr(b, 'id', getattr(b, 'attr', '')) for b in cls.bases]
                if 'Enum' in bases:
                    enums[cls.name] = [t.id for n in cls.body if isinstance(n, ast.Assign) for t in n.targets if isinstance(t, ast.Name)]
                    continue
                if 'Variable' not in bases:
                    continue
                v = Var()
                v.name = cls.name
                v.__of_file__ = path
                attrs = {t.id: n.value for n in cls.body if isinstance(n, ast.Assign) for t in n.targets if isinstance(t, ast.Name)}
                ent = value_of(attrs.get('entity'))
                v.entity = Entity(ENTITY_KEYS.get(ent[1], ent[1].lower()) if isinstance(ent, tuple) else 'person')
                dp = value_of(attrs.get('definition_period'))
                v.definition_period = (dp[1] if isinstance(dp, tuple) and dp[0] == 'name' else dp[2] if isinstance(dp, tuple) else str(dp or 'month')).lower()
                vt = value_of(attrs.get('value_type'))
                vtn = vt[1] if isinstance(vt, tuple) and vt[0] == 'name' else 'float'
                v.value_type = {'float': float, 'int': int, 'bool': bool, 'str': str}.get(vtn, EnumType)
                lab = attrs.get('label')
                v.label = value_of(lab) if isinstance(value_of(lab), str) else None
                ref = value_of(attrs.get('reference'))
                v.reference = ref if isinstance(ref, (str, list)) else None
                for k in ('adds', 'subtracts', 'defined_for', 'end'):
                    x = value_of(attrs.get(k)) if k in attrs else None
                    setattr(v, k, x if isinstance(x, (str, list)) else None)
                dv = value_of(attrs.get('default_value')) if 'default_value' in attrs else None
                if isinstance(dv, tuple) and dv[0] == 'attr':
                    dv = types.SimpleNamespace(name=dv[2])
                v.default_value = dv if dv is not None else (False if v.value_type is bool else 0 if v.value_type in (int, float) else None)
                si = value_of(attrs.get('set_input')) if 'set_input' in attrs else None
                v.set_input = Named(si[1]) if isinstance(si, tuple) and si[0] == 'name' else None
                v.formulas = {}
                for m in cls.body:
                    if isinstance(m, ast.FunctionDef) and m.name.startswith('formula'):
                        date = '0001-01-01'
                        #  formula_2016_12_01, or formula_1980 (from 1 January), as OpenFisca reads them
                        mm = re.fullmatch(r'formula_(\d{4})(?:_(\d{2}))?(?:_(\d{2}))?', m.name)
                        if mm:
                            date = f'{mm.group(1)}-{mm.group(2) or "01"}-{mm.group(3) or "01"}'
                        body = '\n'.join(lines[m.lineno - 1:m.end_lineno])
                        v.formulas[date] = Formula(textwrap.dedent(body), path)
                variables[cls.name] = v
    return variables


class Role:
    def __init__(self, key, plural=None, subroles=()):
        self.key, self.plural, self.subroles = key, plural or key + 's', list(subroles)


class RoleEntity:
    def __init__(self, key, plural=None, roles=()):
        self.key, self.plural, self.roles = key, plural or key + 's', list(roles)


def read_entities(folder):
    """The package's entities and their roles, from the `build_entity(...)`
    calls of its `entities.py`, read with `ast` and never run. An upload of
    openfisca-france needs them: its formulas read a value through the
    holder of a role (the demandeur of a family, the principal declarant of
    a tax household; roadmap Phase 3b′, item 2)."""
    out = []
    for root, dirs, files in os.walk(folder):
        dirs[:] = [d for d in dirs if d != '__pycache__']
        if 'entities.py' not in files:
            continue
        try:
            tree = ast.parse(open(os.path.join(root, 'entities.py')).read())
        except Exception:
            continue
        for node in ast.walk(tree):
            if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                    and node.func.id == 'build_entity'):
                continue
            kw = {k.arg: k.value for k in node.keywords}
            key = kw['key'].value if isinstance(kw.get('key'), ast.Constant) else None
            if not key:
                continue
            plural = kw['plural'].value if isinstance(kw.get('plural'), ast.Constant) else None
            roles = []
            rl = kw.get('roles')
            if isinstance(rl, (ast.List, ast.Tuple)):
                for item in rl.elts:
                    if not isinstance(item, ast.Dict):
                        continue
                    d = {k.value: v for k, v in zip(item.keys, item.values)
                         if isinstance(k, ast.Constant)}
                    rk = d['key'].value if isinstance(d.get('key'), ast.Constant) else None
                    if not rk:
                        continue
                    rp = d['plural'].value if isinstance(d.get('plural'), ast.Constant) else None
                    subs = []
                    sl = d.get('subroles')
                    if isinstance(sl, (ast.List, ast.Tuple)):
                        subs = [Role(x.value) for x in sl.elts if isinstance(x, ast.Constant)]
                    roles.append(Role(rk, rp, subs))
            out.append(RoleEntity(key, plural, roles))
    return out


class StaticSystem:
    """The parts of a TaxBenefitSystem of_extract.py reads."""
    static = True

    def __init__(self, folder):
        self.variables = read_variables(folder)
        self.entities = read_entities(folder)
        pdir = None
        for root, dirs, _ in os.walk(folder):
            if os.path.basename(root) == 'parameters':
                pdir = root
                break
        self.parameters = param_tree(pdir) if pdir else Node()

    def unknown(self, name, like):
        """A variable an upload reads but does not define: an input."""
        v = Var()
        v.name, v.__of_file__ = name, None
        v.entity, v.definition_period = like.entity, like.definition_period
        v.value_type, v.label, v.reference = float, None, None
        v.adds = v.subtracts = v.defined_for = v.end = None
        v.default_value, v.set_input, v.formulas = None, None, {}
        self.variables[name] = v
        return v


def main(folder, out, programme=None):
    system = StaticSystem(folder)
    computed = [n for n, v in system.variables.items() if v.formulas or v.adds]
    if not computed:
        sys.exit('no variable with a formula in ' + folder)
    read = set()
    for v in system.variables.values():
        for f in v.formulas.values():
            read |= set(re.findall(r'["\']([a-z_][a-z0-9_]*)["\']', f.__of_source__))
    roots = [n for n in computed if n not in read] or computed
    tests = [os.path.join(r, f) for r, _, fs in os.walk(folder) for f in sorted(fs)
             if f.endswith('.yaml') and ('test' in r or 'test' in f) and '/parameters' not in r]
    programme = programme or re.sub(r'\W+', '_', os.path.basename(os.path.normpath(folder))).strip('_').lower() or 'upload'
    #  An upload of openfisca-france: its own entities name it (a foyer
    #  fiscal is France's alone), and decision 3 of the October plan gives a
    #  French source a French twin, so the door is told which it is
    #  (of_import.pl reads the line below). Phase 3b′, step 7.
    keys = {getattr(e, 'key', None) for e in system.entities}
    dialect = 'static_fr' if 'foyer_fiscal' in keys else 'static'
    of_extract.write_programme(system, dialect, out, {'name': programme, 'roots': roots, 'tests': tests, 'within': []})
    print('roots:', ', '.join(roots))
    print('dialect:', dialect)


if __name__ == '__main__':
    main(*sys.argv[1:])

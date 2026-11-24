#!/usr/bin/env python3
"""OpenFisca and PolicyEngine country packages, read for the twin builder.

    of_extract.py <dialect> <out dir> --programme NAME --roots v1,v2 [--tests <yaml file or dir>]... [--programme ...]

The package is loaded (its TaxBenefitSystem), so every parameter has the
values the engine itself uses, PolicyEngine's uprating included. From the
root variables the extractor follows every variable a formula reads; each
variable becomes a rule in the RuleSpec shape that migration/rulespec reads
(`rulespec_reader.pl`, `rulespec_twin.pl`), its formula written in RuleSpec's
expression language:

    person("salary", period)                    salary
    spm_unit.household("x", period)             x            (same unit: noted)
    unit.sum(unit.members("x", period))         sum(member_of_<unit>.x)
    unit.any(unit.members("x", period))         count_where(member_of_<unit>, x) > 0
    unit.nb_persons()                           len(member_of_<unit>)
    add(unit, period, ["a", "b"])               a + b
    parameters(period).gov.x.y                  x_y              (a parameter, dated values)
    parameters(period).gov.x.y[k]               x_y[k]           (an indexed parameter)
    p.main[region][size]                        match region: 'A' => ..._main_a[size] ...
    scale.calc(x)                               the brackets written out (rates, thresholds)
    where(c, a, b), select([c..], [v..], d)     if … else …
    max_, min_, np.maximum, np.minimum          max, min
    np.round(x, n), round_(x, n), np.ceil, np.floor, abs
    &, |, ~, comparisons, enum members          and, or, not, comparisons, 'NAME'
    adds / subtracts                            a + b - c
    defined_for = "v"                           if v: <formula> else: 0

Anything else — another period (`period.last_year`, `options=[ADD]`), loops,
`if` statements, comprehensions, calls to helpers — makes the formula
residue: its Python is kept beside the rule, and the twin marks it.

Writes <out>/of/<programme>.yaml (a RuleSpec module, identifier
of:<programme>), <out>/of/<programme>.test.yaml (the package's YAML tests
that read the programme's variables, in RuleSpec's test shape) and
<out>/of/<programme>.json (what was read: variables, their kinds, the
Python of each formula, the parameters and their references).
"""
import ast, copy, csv, datetime, importlib, inspect, json, math, os, re, shutil, sys, textwrap, yaml

DIALECTS = {
    'template': ('openfisca_country_template', 'CountryTaxBenefitSystem'),
    'us': ('policyengine_us', 'CountryTaxBenefitSystem'),
    'uk': ('policyengine_uk', 'CountryTaxBenefitSystem'),
    'france': ('openfisca_france', 'CountryTaxBenefitSystem'),
    'static': ('an upload', None),
    'static_fr': ('an upload of openfisca-france', None),
}
ENTITY_ARGS = {'person', 'household', 'spm_unit', 'tax_unit', 'family', 'marital_unit', 'benunit',
               'individu', 'famille', 'foyer_fiscal', 'menage'}       # (openfisca-france's entities)

#  OpenFisca's names for a period near the one a formula is worked out for,
#  written in the formula language over `period` (Phase 3b′, item 1)
PERIOD_WORDS = {'last_year': 'years_before({0}, 1)', 'n_2': 'years_before({0}, 2)',
                'last_month': 'months_before({0}, 1)', 'this_year': 'year_of({0})',
                'first_month': 'first_month_of({0})', 'last_3_months': 'last_3_months_of({0})'}
#  (`last_3_months` is the three months before the period, one period of its
#  own, `2023-10_3m`, whose months a case states: read as the month three
#  months before, a sum over the last three months read one month)


#  the packages whose helper functions may be inlined
PACKAGE_ROOTS = {'policyengine_us', 'policyengine_uk', 'openfisca_country_template', 'policyengine_core', 'openfisca_core', 'openfisca_france'}

#  the engine's own period arithmetic: not a helper of the law, so never
#  inlined — a period a formula builds is read as a period (Phase 3b′, item 1)
ENGINE_PERIODS = {'openfisca_core.periods.helpers', 'policyengine_core.periods.helpers',
                  'openfisca_core.periods', 'policyengine_core.periods'}


def of_package(h):
    """Whether h is a function of one of the packages, so its body may be
    inlined. openfisca-france's own model files are loaded by path, under
    made-up module names, so the file decides, not the module's name."""
    if not inspect.isfunction(h):
        return False
    mod = getattr(h, '__module__', '') or ''
    if mod in ENGINE_PERIODS:
        return False
    if mod.split('.')[0] in PACKAGE_ROOTS:
        return True
    try:
        file = inspect.getsourcefile(h) or ''
    except TypeError:
        return False
    return any(f'/{r}/' in file for r in PACKAGE_ROOTS)


class Subst(ast.NodeTransformer):
    def __init__(self, names):
        self.names = names

    def visit_Name(self, node):
        if isinstance(node.ctx, ast.Load) and node.id in self.names:
            return ast.copy_location(copy.deepcopy(self.names[node.id]), node)
        return node


def subst(node, names):
    """A copy of the tree with the names given replaced by their trees."""
    return Subst(names).visit(copy.deepcopy(node)) if names else node


def const_node(v):
    """A Python value as an AST node: a tuple or a list as a node of nodes,
    so that a loop's `a, b = item` unpacks it."""
    if isinstance(v, tuple):
        return ast.Tuple(elts=[const_node(x) for x in v], ctx=ast.Load())
    if isinstance(v, list):
        return ast.List(elts=[const_node(x) for x in v], ctx=ast.Load())
    return ast.Constant(v)


def bytetext(v):
    """A text constant, from a `str` or from the bytes a NumPy text array
    holds (openfisca-france compares a nationality with b'FR')."""
    return "'" + (v.decode('utf-8') if isinstance(v, bytes) else str(v)) + "'"


def numtext(v):
    """A number written out in full, without an exponent."""
    t = format(v, '.20f').rstrip('0')
    return t + '0' if t.endswith('.') else t


def split_if(t):
    """(C, V, E) of formula text `(if C: V else: E)`, else None."""
    if not (t.startswith('(if ') and t.endswith(')')):
        return None
    depth, q, parts, start, i = 0, None, [], 4, 4
    body = t[:-1]
    while i < len(body):
        c = body[i]
        if q:
            q = None if c == q else q
        elif c in "'\"":
            q = c
        elif c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
        elif depth == 0 and not parts and body.startswith(': ', i):
            parts.append(body[start:i]); start = i + 2; i += 1
        elif depth == 0 and len(parts) == 1 and body.startswith(' else: ', i):
            parts.append(body[start:i]); start = i + 7; i += 6
        i += 1
    if len(parts) != 2:
        return None
    return parts[0], parts[1], body[start:]


def merge_if(cond, a, b):
    """`if cond: x = where(c, v, x)` read as `where(cond and c, v, x)`: the
    value before the if is the other branch, once."""
    s = split_if(a)
    if s and s[2] == b:
        return f'(if ({cond} and {s[0]}): {s[1]} else: {b})'
    return f'(if {cond}: {a} else: {b})'


class Residue(Exception):
    pass


class Skip(Exception):
    """A `continue` in a loop the reader unrolls: the rest of this copy of
    the body is not read."""
    pass


HELPERS = {}

#  The translator's own words in the names of the rules it adds (a person's
#  part of a group's value, a step of a long formula): in the twin's own
#  language, which the twin's sentences are made of. openfisca-france's twins
#  read "*un individu* remplit la condition compte pour ..." rather than
#  "counts for" (review of 11 October, point 6).
HELPER_WORDS = {
    'en': {'counts_for': 'counts_for', 'member_part_of': 'member_part_of', 'step': 'step',
           'any': 'has_members_who_count_for', 'all': 'has_only_members_who_count_for',
           'sum': 'number_of_members_who_count_for', 'total': 'total_over_the_members_for',
           'max': 'highest_among_the_members_for', 'min': 'lowest_among_the_members_for',
           'nb_persons': 'number_of_members_for',
           'step_src': '{v}: the value of {name} at this step of the formula',
           'each_member': 'each member: {t}', 'members_of': 'the members of the {g}: {t}',
           'default': " — the package's default, where the case states no value",
           'role': "a person given the role {k} in the {g} (the tests' {pl}: lists)",
           'table': '{g}: the table of the package by code, read by {v} ({n} rows, preloaded from its assets)',
           'turned': "{l}: the package's input {n} (default yes) turned around, so that a scenario that "
                     "does not state it means what the package's default means",
           'not': 'is_not'},
    'fr': {'counts_for': 'compte_pour', 'member_part_of': 'contribution_du_membre_a', 'step': 'etape',
           'any': 'a_des_membres_qui_comptent_pour', 'all': 'a_seulement_des_membres_qui_comptent_pour',
           'sum': 'nombre_de_membres_qui_comptent_pour', 'total': 'total_des_membres_pour',
           'max': 'maximum_des_membres_pour', 'min': 'minimum_des_membres_pour',
           'nb_persons': 'nombre_de_membres_pour',
           'step_src': '{v} : la valeur de {name} à cette étape de la formule',
           'each_member': 'chaque membre : {t}', 'members_of': 'les membres du groupe {g} : {t}',
           'default': " — la valeur par défaut du modèle, quand le cas n'en donne pas",
           'role': "une personne qui a le rôle {k} dans le groupe {g} (les listes {pl}: des tests)",
           'table': '{g} : la table du modèle par code, lue par {v} ({n} lignes, chargées depuis ses fichiers)',
           'turned': "{l} : l'entrée {n} du modèle (oui par défaut) retournée, pour qu'un scénario qui ne la "
                     "donne pas veuille dire ce que veut dire la valeur par défaut du modèle",
           'not': 'non'}}
WORDS = HELPER_WORDS['en']


#  Which engine the reader is reading. PolicyEngine's core carries an input
#  forward to a later period and openfisca-core does not, so the twins of the
#  two differ in what a case states for a value a test gives for another
#  period (given_at/3).
DIALECT = 'static'
CARRIES_FORWARD = ('us', 'uk')     # the PolicyEngine packages


def helper_words(dialect):
    """The helper names' words for a package's twin: French for openfisca-france;
    and which engine this is, for the engines' own differences."""
    global WORDS, DIALECT
    WORDS = HELPER_WORDS['fr' if dialect == 'france' else 'en']
    DIALECT = dialect
ROLES = {}        # the inputs that say a person has a role in a group: name -> (group, role, plural)


def source_of(fn):
    """A formula's Python: from the loaded package, or as of_static.py read it."""
    return getattr(fn, '__of_source__', None) or textwrap.dedent(inspect.getsource(fn))


def file_of(var):
    if hasattr(var, '__of_file__'):
        return var.__of_file__
    try:
        return inspect.getsourcefile(type(var))
    except TypeError:
        return None


def load_system(dialect):
    mod, cls = DIALECTS[dialect]
    m = importlib.import_module(mod)
    return getattr(m, cls)()


def camel(key):
    return ''.join(p.capitalize() for p in key.split('_'))


# ------------------------------------------------------------------ parameters

LOOKUPS = {}     # a table by code the package preloads: name -> (rows, default), written as CSV
SUBROLE_PLACE = {}   # (group, subrole) -> its place in its role's list (demandeur 0, conjoint 1)

class Params:
    """The parameters a programme reads, named after their paths."""
    def __init__(self, system, window=None):
        self.system = system
        self.window = window     # (first, last) date of the tests: values outside are left out
        self.rules = {}          # name -> RuleSpec rule dict
        self.refs = {}           # name -> reference text
        self.files = set()       # the parameter files read
        self.bools = set()       # parameters that are yes or no

    def node(self, path):
        n = self.system.parameters
        for p in path:
            if p.startswith('@') or p.startswith('=') or p.startswith('>'):
                continue            # the date it is read at (a fiscal year's start, a fixed date): not a node
            try:
                n = n.children[p] if hasattr(n, 'children') and p in n.children else getattr(n, p)
            except (AttributeError, KeyError):
                raise Residue(f'the parameter attribute {".".join(path)}')
        return n

    @staticmethod
    def name(path):
        #  (PolicyEngine's parameters all start with `gov`: it adds nothing to a sentence)
        anchor = [p for p in path if p.startswith('@')]
        fixed = [p for p in path if p.startswith('=')]
        rel = [p for p in path if p.startswith('>')]
        path = [p for p in path if not p.startswith('@') and not p.startswith('=') and not p.startswith('>')]
        path = list(path[1:]) if len(path) > 1 and path[0] == 'gov' else list(path)
        n = re.sub(r'[^a-z0-9_]', '_', '_'.join(path).lower())
        if anchor:
            #  read at the start of a year that begins on another day (SNAP's
            #  fiscal year, from 1 October): named after that day
            n += '_from_' + re.sub(r'[^0-9]', '_', anchor[0][1:])
        if fixed:
            #  read at a date the formula writes (`parameters("2025-06-01")`)
            n += '_on_' + re.sub(r'[^0-9]', '_', fixed[0][1:])
        if rel:
            #  read at a date the calculation date decides (`parameters(period.n_2.stop)`)
            kind, k = rel[0][1:].split(':')
            k = int(k)
            n += {'shift': f'_{abs(k)}_months_before' if k < 0 else f'_{k}_months_after',
                  'yearend': f'_end_of_year_n{k:+d}', 'yearstart': f'_start_of_year_n{k:+d}'}[kind].replace('+', 'p').replace('-', 'm')
        return n

    @staticmethod
    def rel(path):
        a = [p for p in path if p.startswith('>')]
        if not a:
            return None
        kind, k = a[0][1:].split(':')
        return kind, int(k)

    def rel_vals(self, path, node_vals):
        """The versions of a parameter read at a date the calculation date
        decides: so many months before it (each version's start moved by as
        much), or the end or the start of the year so many years before
        (one version per year of the twin's window)."""
        kind, k = self.rel(path)
        if kind == 'shift':
            out = []
            for d, v in node_vals:
                dd = datetime.date.fromisoformat(d)
                m = dd.year * 12 + dd.month - 1 - k
                out.append((f'{m // 12:04d}-{m % 12 + 1:02d}-{dd.day:02d}' if dd.day <= 28 else
                            f'{m // 12:04d}-{m % 12 + 1:02d}-28', v))
            return out
        lo, hi = self.window if self.window else ('2015-01-01', '2030-12-31')
        day = '12-31' if kind == 'yearend' else '01-01'
        out = []
        for y in range(int(lo[:4]), int(hi[:4]) + 1):
            vs = [v for dd, v in sorted(node_vals) if dd <= f'{y + k}-{day}']
            out.append((f'{y}-01-01', vs[-1] if vs else None))
        return out

    @staticmethod
    def fixed(path):
        a = [p for p in path if p.startswith('=')]
        return a[0][1:] if a else None

    @staticmethod
    def anchor(path):
        a = [p for p in path if p.startswith('@')]
        return a[0][1:] if a else None

    def anchored_dates(self, mmdd):
        """The starts of the years beginning on mmdd that the twin's window
        meets, and the day before each next start."""
        lo, hi = self.window if self.window else ('2015-01-01', '2030-12-31')
        out = []
        for y in range(int(lo[:4]) - 1, int(hi[:4]) + 1):
            start, nxt = f'{y}-{mmdd}', f'{y + 1}-{mmdd}'
            if nxt > lo and start <= hi:
                end = (datetime.date.fromisoformat(nxt) - datetime.timedelta(days=1)).isoformat()
                out.append((start, end))
        return out

    @staticmethod
    def value_at(node, date):
        vs = [v for v in sorted(node.values_list, key=lambda v: v.instant_str) if v.instant_str <= date]
        return vs[-1].value if vs else None

    def reference(self, node):
        md = getattr(node, 'metadata', {}) or {}
        ref = md.get('reference')
        if isinstance(ref, list) and ref:
            r = ref[0]
            return r.get('title') or r.get('href') if isinstance(r, dict) else str(r)
        if isinstance(ref, dict):
            return ref.get('title') or ref.get('href')
        if isinstance(ref, str):
            return ref
        return getattr(node, 'description', None)

    def scalar(self, path):
        """A leaf parameter: a RuleSpec parameter with dated versions."""
        name = self.name(path)
        if name in self.rules:
            return name
        node = self.node(path)
        if not hasattr(node, 'values_list'):
            raise Residue(f'parameter {".".join(path)} is not a value')
        vals = sorted((v.instant_str, v.value) for v in node.values_list)
        if self.anchor(path):
            vals = [(st, self.value_at(node, st)) for st, _ in self.anchored_dates(self.anchor(path))]
        if self.fixed(path):
            vals = [('1900-01-01', self.value_at(node, self.fixed(path)))]
        if self.rel(path):
            vals = self.rel_vals(path, vals)
        versions = []
        texts = False
        for i, (d, v) in enumerate(vals):
            if v is None:
                continue
            if isinstance(v, bool):
                v = 1 if v else 0                 # a yes or no: 1 or 0, tested as such
                self.bools.add(name)
            if isinstance(v, str):
                #  a parameter in words (a state's name, the kind of a utility
                #  allowance): a text, cited like any other value
                texts = True
            elif not isinstance(v, (int, float)):
                raise Residue(f'parameter {".".join(path)} is not a number')
            if isinstance(v, float) and math.isinf(v):
                v = 1e15 if v > 0 else -1e15      # (no limit: a number no age or amount reaches, as np.inf)
            ver = {'effective_from': d,
                   'formula': bytetext(v) if isinstance(v, str)
                   else numtext(v) if isinstance(v, float) and 'e' in repr(v)
                   else repr(v) if isinstance(v, float) else str(v)}
            if i + 1 < len(vals):
                nxt = datetime.date.fromisoformat(vals[i + 1][0]) - datetime.timedelta(days=1)
                ver['effective_to'] = nxt.isoformat()
            versions.append(ver)
        if not versions:
            raise Residue(f'parameter {".".join(path)} has no value')
        versions[-1].pop('effective_to', None)
        versions = self.clip(versions)
        ref = self.reference(node)
        plain = [p for p in path if not p[:1] in ('@', '=', '>')]
        self.rules[name] = {'name': name, 'kind': 'parameter', 'dtype': 'Text' if texts else 'Decimal',
                            'source': ref or '.'.join(plain), 'versions': versions}
        self.files.add(getattr(node, 'file_path', None))
        return name

    def table(self, path):
        """A node whose children are values keyed by a code or a number: an
        indexed parameter (one version per date any child changes)."""
        name = self.name(path)
        if name in self.rules:
            return name
        node = self.node(path)
        kids = getattr(node, 'children', None)
        if not kids or not all(hasattr(k, 'values_list') for k in kids.values()):
            raise Residue(f'parameter {".".join(path)} is not a table of values')
        dates = sorted({v.instant_str for k in kids.values() for v in k.values_list})
        if self.anchor(path):
            dates = [st for st, _ in self.anchored_dates(self.anchor(path))]
        if self.fixed(path):
            dates = [self.fixed(path)]
        versions = []
        for i, d in enumerate(dates):
            row = {}
            for key, k in kids.items():
                vs = [v for v in sorted(k.values_list, key=lambda v: v.instant_str) if v.instant_str <= d]
                if vs and vs[-1].value is not None:
                    val = vs[-1].value
                    if isinstance(val, bool):
                        val = 1 if val else 0
                    row[int(key) if str(key).isdigit() else str(key)] = val
            ver = {'effective_from': '1900-01-01' if self.fixed(path) else d, 'values': row}
            if i + 1 < len(dates):
                ver['effective_to'] = (datetime.date.fromisoformat(dates[i + 1]) - datetime.timedelta(days=1)).isoformat()
            versions.append(ver)
        self.files.add(getattr(node, 'file_path', None))
        versions = self.clip(versions)
        texts = any(isinstance(x, str) for v in versions for x in v['values'].values())
        self.rules[name] = {'name': name, 'kind': 'parameter', 'dtype': 'Text' if texts else 'Decimal',
                            'indexed_by': name + '_key',
                            'source': self.reference(node) or '.'.join(path), 'versions': versions}
        return name

    def lookup(self, gname, table, default, var):
        """A table by code that the package preloads into a dictionary of its
        module (`zone_apl_by_depcom`, 36,682 communes read from a CSV of its
        assets): a table loaded from a CSV file beside the twin, with the
        dictionary's default as its last row (roadmap Phase 3b′, item 3)."""
        name = re.sub(r'[^a-z0-9_]', '_', gname.lower()).strip('_')
        if name not in self.rules:
            rows = sorted((str(k), v) for k, v in table.items())
            if not all(isinstance(v, (int, float, str)) and not isinstance(v, bool) for _, v in rows):
                raise Residue(f'the table {gname} holds values that are not numbers or texts')
            LOOKUPS[name] = (rows, default)
            texts = any(isinstance(v, str) for _, v in rows)
            self.rules[name] = {'name': name, 'kind': 'parameter', 'dtype': 'Text' if texts else 'Decimal',
                                'indexed_by': name + '_key', 'table_file': name + '.csv', 'table_default': default,
                                'source': WORDS['table'].format(g=gname, v=var, n=len(rows)),
                                'versions': [{'effective_from': '1900-01-01', 'values': {}}]}
        return name

    def calendar(self, part):
        """The calculation date's own year or month, as a dated parameter: one
        version per year (or per month) of the twin's window. A French formula
        reads `period.start.year` or `period.start.month` as a value (the year
        a benefit is paid in, the month a yearly contribution is settled in);
        the twin knows the years it covers when it is written, so the value is
        a parameter of the calculation date like any other (roadmap Phase 3b′,
        item 4)."""
        #  (named in the twin's language: a French twin read `la calculation
        #  year`)
        french = person_key(self.system) == 'individu'
        name = ({'year': 'annee_de_calcul', 'month': 'mois_de_calcul'}[part] if french else 'calculation_' + part)
        if name in self.rules:
            return name
        lo, hi = self.window if self.window else ('2015-01-01', '2030-12-31')
        versions = []
        if part == 'year':
            for y in range(int(lo[:4]), int(hi[:4]) + 1):
                versions.append({'effective_from': f'{y}-01-01', 'effective_to': f'{y}-12-31', 'formula': str(y)})
        else:
            for y in range(int(lo[:4]), int(hi[:4]) + 1):
                for m in range(1, 13):
                    last = (datetime.date(y + m // 12, m % 12 + 1, 1) - datetime.timedelta(days=1)).isoformat()
                    versions.append({'effective_from': f'{y}-{m:02d}-01', 'effective_to': last, 'formula': str(m)})
        versions = [v for v in versions if v['effective_from'] <= hi and v['effective_to'] >= lo]
        if not versions:
            raise Residue(f'the period\'s {part} outside the twin\'s window')
        versions[-1].pop('effective_to', None)
        self.rules[name] = {'name': name, 'kind': 'parameter', 'dtype': 'Decimal',
                            'source': f"the {part} the calculation date falls in (openfisca's period.start.{part})",
                            'versions': versions}
        return name

    def clip(self, versions):
        """The versions in force at some date of the window."""
        if not self.window or not versions:
            return versions
        lo, hi = self.window
        kept = [v for v in versions if v['effective_from'] <= hi and (not v.get('effective_to') or v['effective_to'] >= lo)]
        return kept or versions[-1:]

    def keys(self, path):
        return list(self.node(path).children.keys())

    def scale(self, path):
        """A marginal scale: the rate and threshold of each bracket, as
        parameters; its calc() written out by the caller."""
        node = self.node(path)
        brackets = getattr(node, 'brackets', None)
        if not brackets:
            raise Residue(f'{".".join(path)} is not a scale')
        out = []
        for i, b in enumerate(brackets):
            kids = b.children
            if 'rate' not in kids or 'threshold' not in kids:
                raise Residue(f'{".".join(path)}: a bracket without a rate and a threshold')
            out.append((self._bracket(path, i, 'rate', kids['rate']),
                        self._bracket(path, i, 'threshold', kids['threshold'])))
        return out

    def amount_scale(self, path):
        """A single-amount scale (each bracket an amount from a threshold):
        [(amount, threshold)], or None when the scale has rates."""
        node = self.node(path)
        brackets = getattr(node, 'brackets', None) or []
        if not brackets or not all('amount' in b.children and 'threshold' in b.children for b in brackets):
            return None
        return [(self._bracket(path, i, 'amount', b.children['amount']),
                 self._bracket(path, i, 'threshold', b.children['threshold'])) for i, b in enumerate(brackets)]

    def _bracket(self, path, i, what, leaf):
        name = self.name(path + [f'bracket_{i + 1}', what])
        if name in self.rules:
            return name
        vals = sorted((v.instant_str, v.value) for v in leaf.values_list)
        if self.fixed(path):
            vals = [('1900-01-01', self.value_at(leaf, self.fixed(path)))]
        #  a bracket that does not exist (yet, or any more) adds nothing: a
        #  rate of 0 and a threshold no income reaches, as calc() reads it
        none = 0.0 if what in ('rate', 'amount') else 1e15
        if vals and vals[0][0] > '1900-01-01':
            vals.insert(0, ('1900-01-01', None))
        versions = []
        for j, (d, v) in enumerate(vals):
            ver = {'effective_from': d, 'formula': repr(float(none if v is None else v))}
            if j + 1 < len(vals):
                ver['effective_to'] = (datetime.date.fromisoformat(vals[j + 1][0]) - datetime.timedelta(days=1)).isoformat()
            versions.append(ver)
        versions[-1].pop('effective_to', None)
        versions = self.clip(versions)
        self.rules[name] = {'name': name, 'kind': 'parameter', 'dtype': 'Decimal',
                            'source': self.reference(self.node(path)) or '.'.join(path), 'versions': versions}
        return name


# ------------------------------------------------------------------ formulas

class Translator:
    def __init__(self, system, params, var):
        self.system, self.params, self.var = system, params, var
        self.env = {}
        self.reads = set()
        self.notes = []
        self.helpers = {}
        self.boolnames = set()
        self.calcnames = set()
        self.aliases = {}
        self.approx = []
        self.musts = []          # the formula's own assertions, as integrity constraints
        self.yields = []         # the terms a generator the formula sums yields
        self.by_period = set()   # the variables this formula reads for another period
        self.derived_periods = set()   # among them, those the programme works out itself
        self.given_periods = set()     # among them, those the case gives for another period
        self.known_periods = set()   # the variables the programme already reads for another period
        self.periods = set()     # the period expressions it names
        self.within = ()         # the programme's folders, when it has them
        self.out_vars = None
        self.epoch = 0           # one statement of the formula: inside it, a node's value is fixed
        self.memo = {}           # (epoch, node) -> the value, or the Residue it raises

    # an expression as RuleSpec formula text, or ('param', path) / ('members', unit, var) markers
    def expr(self, n):
        t = self.e(n)
        if isinstance(t, tuple):
            if t[0] == 'param':
                name = self.params.scalar(t[1])
                return f'({name} == 1)' if name in self.params.bools else name
            if t[0] == 'period_part':
                #  the calculation date's own year or month: a dated parameter
                #  (roadmap Phase 3b′, item 4)
                self.approx.append(f'period.start.{t[1]} written as the {t[1]} of the calculation date')
                return self.params.calendar(t[1])
            if t[0] == 'period' and t[1] == 'start':
                return 'period_start'                  # the calculation date
            if t[0] == 'roleval':
                return self.through_role(t[1], t[2], t[3], False)
            if t[0] == 'pmatch':
                return self.pmatch_text(t)
            raise Residue(f'{t[0]} used as a value')
        return t

    def e(self, n):
        """The value of an expression. Memoised within one statement of the
        formula: `boolmul` reads the same subtree again to see whether it
        answers yes or no, and a formula of nested `where`s over a scale
        would otherwise be read a number of times that doubles with its
        depth (the reader's speed: roadmap Phase 3b′, item 6)."""
        key = (self.epoch, id(n))
        hit = self.memo.get(key)
        if hit is not None:
            if isinstance(hit[0], Residue):
                raise hit[0]
            return hit[0]
        try:
            v = self.e_(n)
        except Residue as r:
            self.memo[key] = (r, n)
            raise
        self.memo[key] = (v, n)
        return v

    def e_(self, n):
        if isinstance(n, ast.Constant):
            if isinstance(n.value, bool):
                return 'true' if n.value else 'false'
            if isinstance(n.value, float) and 'e' in repr(n.value):
                return numtext(n.value)              # (1e-09: the formula language has no exponent)
            if isinstance(n.value, (int, float)):
                return repr(n.value)
            if isinstance(n.value, str):
                return "'" + n.value + "'"
            if isinstance(n.value, bytes):
                return bytetext(n.value)       # (a NumPy text array holds bytes: b'FR')
            raise Residue(f'constant {n.value!r}')
        if isinstance(n, (ast.List, ast.Tuple)) and n.elts and all(isinstance(x, ast.Constant) for x in n.elts):
            return ('list', [x.value for x in n.elts])     # a list written out, for a loop or add()
        if isinstance(n, (ast.List, ast.Tuple)) and n.elts:
            #  a list of expressions the formula names (the conditions and the
            #  amounts of a select): each read where it stands
            return ('exprs', list(n.elts))
        if isinstance(n, ast.Name):
            if n.id in self.env:
                return self.env[n.id]
            if n.id in ('True', 'False'):
                return n.id.lower()
            if n.id == 'inf' and n.id not in getattr(self, 'fn_globals', {}).get('__builtins__', {}) \
                    and getattr(self, 'fn_globals', {}).get('inf') == math.inf:
                self.approx.append('inf written as 10^15, a number no amount reaches')
                return '1000000000000000'
            c = number_constant(n.id, file_of(self.var))
            if c is None and n.id[:1].isupper():
                #  a number the module the formula (or the helper it reads)
                #  belongs to writes: DEFAULT_ROUND_BASE_DECIMALS
                g = getattr(self, 'fn_globals', {}).get(n.id)
                if isinstance(g, (int, float)) and not isinstance(g, bool):
                    c = g
            if c is not None:
                return repr(c)                 # MONTHS_IN_YEAR, a number of the file or of the engine
            if n.id[:1].isupper():
                return ('enum', n.id)          # an Enum class: its members are codes
            raise Residue(f'the name {n.id}')
        if isinstance(n, ast.BinOp):
            if isinstance(n.op, ast.FloorDiv):
                return f'floor({self.expr(n.left)} / {self.expr(n.right)})'
            if isinstance(n.op, (ast.BitAnd, ast.BitOr)):
                #  two sets the formula writes, met or joined (the years a
                #  reduction covers and the years the calculation reaches)
                a, b = self.e_safe(n.left), self.e_safe(n.right)
                if isinstance(a, tuple) and a[0] == 'list' and isinstance(b, tuple) and b[0] == 'list':
                    if isinstance(n.op, ast.BitAnd):
                        return ('list', [x for x in a[1] if x in b[1]])
                    return ('list', list(a[1]) + [x for x in b[1] if x not in a[1]])
            op = {ast.Add: '+', ast.Sub: '-', ast.Mult: '*', ast.Div: '/', ast.BitAnd: 'and', ast.BitOr: 'or'}.get(type(n.op))
            if op is None:
                raise Residue(f'the operator {type(n.op).__name__}')
            l, r = self.e(n.left), self.e(n.right)
            if any(isinstance(x, tuple) and x[0] in ('members', 'mexpr', 'mbool', 'mpred') for x in (l, r)):
                yes_no = lambda x: isinstance(x, tuple) and (x[0] in ('mbool', 'mpred') or x[0] == 'members' and x[1] in self.system.variables
                                                              and self.system.variables[x[1]].value_type is bool)
                if op == '*' and yes_no(l) and yes_no(r):
                    return ('mbool', f'({self.mtext(l)} and {self.mtext(r)})')     # two yes-or-no values: both
                if op == '*':
                    #  a member's value times a yes or no of the member: the
                    #  value where it holds, else 0
                    for x, y in ((l, r), (r, l)):
                        if yes_no(x) and not yes_no(y):
                            return ('mexpr', f'(if {self.mtext(x)}: {self.mtext(y)} else: 0)')
                kind = 'mbool' if op in ('and', 'or') else 'mexpr'
                if kind == 'mexpr':
                    #  a member's yes or no in arithmetic: 1 or 0
                    #  (a member's own yes-or-no variable too: `inapte_travail`
                    #  added to a count, which no case states, had no value)
                    num = lambda x: f'(if {self.mtext(x)}: 1 else: 0)' if yes_no(x) else self.mtext(x)
                    return (kind, f'({num(l)} {op} {num(r)})')
                return (kind, f'({self.mtext(l)} {op} {self.mtext(r)})')
            if op in ('and', 'or'):
                #  a scale's calc() used as a yes or no: it holds when not 0
                l, r = (f'({x} != 0)' if self.is_calc(y) else x for x, y in ((l, n.left), (r, n.right)))
                if isinstance(l, str) and isinstance(r, str):
                    return f'({l} {op} {r})'
            if op == '+':
                a, b = self.boolmul(n.left), self.boolmul(n.right)
                if a[0] == 'bool' and b[0] == 'bool':
                    return f'({a[1]} or {b[1]})'           # NumPy's sum of two yes-or-no arrays
            if op == '*':
                a, b = self.boolmul(n.left), self.boolmul(n.right)
                for x, y, other in ((a, b, n.right), (b, a, n.left)):
                    if x == ('bool', 'true') and y[0] != 'bool':
                        return self.expr(other)              # True * x: x
                    if x == ('bool', 'false') and y[0] != 'bool':
                        return '0'
                if a[0] == 'bool' and b[0] == 'bool':
                    return f'({a[1]} and {b[1]})'          # NumPy's product of two yes-or-no arrays
                if a[0] == 'bool' and b[0] != 'bool':
                    return f'(if {a[1]}: {self.expr(n.right)} else: 0)'
                if b[0] == 'bool' and a[0] != 'bool':
                    return f'(if {b[1]}: {self.expr(n.left)} else: 0)'
            if op in ('+', '-', '/'):
                #  a yes or no added to (or taken from) a number: 1 or 0, as
                #  NumPy reads it. openfisca-france declares some amounts of
                #  the tax form yes-or-no (`f7xe_2025`, a Scellier
                #  investment): read as a number, an input no case states
                #  had no value, and the whole sum none.
                a, b = self.boolmul(n.left), self.boolmul(n.right)
                if (a[0] == 'bool') != (b[0] == 'bool'):
                    l = f'(if {a[1]}: 1 else: 0)' if a[0] == 'bool' else self.expr(n.left)
                    r = f'(if {b[1]}: 1 else: 0)' if b[0] == 'bool' else self.expr(n.right)
                    return f'({l} {op} {r})'
            return f'({self.expr(n.left)} {op} {self.expr(n.right)})'
        if isinstance(n, ast.UnaryOp):
            if isinstance(n.op, ast.UAdd):
                return self.expr(n.operand)
            if isinstance(n.op, ast.USub):
                return f'(-{self.expr(n.operand)})'
            if isinstance(n.op, (ast.Invert, ast.Not)):
                o = self.e(n.operand)
                if isinstance(o, tuple) and o[0] in ('members', 'mexpr', 'mbool', 'mpred'):
                    return ('mbool', f'(not {self.mtext(o)})')
                return f'(not {self.expr(n.operand)})'
            raise Residue('unary operator')
        if isinstance(n, ast.BoolOp):
            op = 'and' if isinstance(n.op, ast.And) else 'or'
            return '(' + f' {op} '.join(self.expr(v) for v in n.values) + ')'
        if isinstance(n, ast.Compare) and len(n.ops) == 1 and isinstance(n.ops[0], (ast.Is, ast.IsNot)) \
                and isinstance(n.comparators[0], ast.Constant) and n.comparators[0].value is None \
                and not (isinstance(n.left, ast.Constant) and n.left.value is None) \
                and self.python_value(n.left) is None:
            #  `x is not None` of a value the formula read: the engine gives
            #  it an array, never None
            self.notes.append('a test that a value the formula read is not nothing, which it never is: '
                              + ast.unparse(n))
            return 'true' if isinstance(n.ops[0], ast.IsNot) else 'false'
        if isinstance(n, ast.Compare) and len(n.ops) == 1 and isinstance(n.ops[0], (ast.Eq, ast.NotEq)):
            #  a code of the member who holds a role compared with a code
            #  (`statut_marital == TypesStatutMarital.marie`, statut_marital
            #  the main declarant's): whether a member holds the role and has
            #  that code. Summed over the members as a number is, the code
            #  stopped every income-tax case (openfisca-france, Phase 3b′).
            sides = [n.left, n.comparators[0]]
            vals = [self.e(x) for x in sides]
            for i in (0, 1):
                v = vals[i]
                if isinstance(v, tuple) and v[0] == 'roleval':
                    _, grp, rolename, text = v
                    code = self.expr(sides[1 - i])
                    h = self.helper(f'({rolename} and ({text} == {code}))', 'Judgment')
                    own = f'member_of_{grp}'
                    self.relations.add(own)
                    test = f'(count_where({own}, {h}) > 0)'
                    return test if isinstance(n.ops[0], ast.Eq) else f'(not {test})'
        if isinstance(n, ast.Compare) and len(n.ops) == 1:
            left = self.e(n.left)
            right = self.e(n.comparators[0]) if not (isinstance(left, tuple) and left[0] in ('members', 'mexpr')) else None
            if isinstance(right, tuple) and right[0] in ('members', 'mexpr'):
                #  a value compared with a member's value: a yes or no of each member
                op = {ast.Lt: '<', ast.LtE: '<=', ast.Gt: '>', ast.GtE: '>=', ast.Eq: '==', ast.NotEq: '!='}.get(type(n.ops[0]))
                if op is None:
                    raise Residue('comparison ' + type(n.ops[0]).__name__)
                return ('mbool', f'({self.mtext(left)} {op} {self.mtext(right)})')
            if isinstance(left, tuple) and left[0] == 'mexpr':
                left = ('members', self.helper(left[1], 'Money'))
            if isinstance(left, tuple) and left[0] == 'members':
                op = {ast.Lt: '<', ast.LtE: '<=', ast.Gt: '>', ast.GtE: '>=', ast.Eq: '==', ast.NotEq: '!='}.get(type(n.ops[0]))
                right = self.e(n.comparators[0])
                if isinstance(right, tuple) and right[0] in ('members', 'mexpr', 'mbool', 'mpred'):
                    return ('mbool', f'({left[1]} {op} {self.mtext(right)})')
                right = self.expr(n.comparators[0])
                word = {'<': 'below', '<=': 'at_most', '>': 'above', '>=': 'at_least', '==': 'equal_to', '!=': 'not_equal_to'}[op]
                hname = re.sub(r'[^a-z0-9_]', '_', f'{left[1]}_{word}_{right}'.lower()).strip('_')
                self.helpers[hname] = {'name': hname, 'kind': 'derived', 'entity': camel(person_key(self.system)), 'dtype': 'Judgment',
                                       'source': WORDS['each_member'].format(t=f'{left[1]} {op} {right}'),
                                       'versions': [{'effective_from': '1900-01-01', 'formula': f'{left[1]} {op} {right}'}]}
                return ('mpred', hname)
        if isinstance(n, ast.Compare):
            if len(n.ops) != 1:
                return '(' + ' and '.join(self.expr(ast.Compare(left=a, ops=[o], comparators=[b]))
                                          for a, o, b in zip([n.left] + n.comparators[:-1], n.ops, n.comparators)) + ')'
            op = {ast.Lt: '<', ast.LtE: '<=', ast.Gt: '>', ast.GtE: '>=', ast.Eq: '==', ast.NotEq: '!='}.get(type(n.ops[0]))
            if op is None:
                raise Residue('comparison ' + type(n.ops[0]).__name__)
            return f'({self.expr(n.left)} {op} {self.expr(n.comparators[0])})'
        if isinstance(n, ast.IfExp):
            return f'(if {self.expr(n.test)}: {self.expr(n.body)} else: {self.expr(n.orelse)})'
        if isinstance(n, ast.Attribute):
            # parameters(period).a.b, an enum member, a parameter node's child
            if isinstance(n.value, ast.Name) and n.value.id == 'period':
                return ('period', n.attr)
            if isinstance(n.value, ast.Name) and n.value.id == getattr(self, 'entity_arg', None) and n.attr == 'members':
                return ('memberfn',)
            if n.attr == 'possible_values':
                return ('enum', 'possible_values')
            if n.attr == 'values' and isinstance(n.value, ast.Call) and isinstance(n.value.func, ast.Attribute) \
                    and n.value.func.attr == 'map':
                return self.e(n.value)                  # pd.Series(...).map(...).values
            if n.attr == 'start' and isinstance(n.value, ast.Call) and isinstance(n.value.func, ast.Attribute) \
                    and n.value.func.attr == 'offset' and isinstance(n.value.func.value, ast.Name) \
                    and n.value.func.value.id == 'period' and n.value.args \
                    and isinstance(n.value.args[0], (ast.Constant, ast.UnaryOp)):
                #  period.offset(-24, 'month').start: the first day of the
                #  period so many months before the one asked about
                k = n.value.args[0]
                months = k.value if isinstance(k, ast.Constant) else \
                    -k.operand.value if isinstance(k, ast.UnaryOp) and isinstance(k.op, ast.USub) \
                    and isinstance(k.operand, ast.Constant) else None
                unit = n.value.args[1].value if len(n.value.args) > 1 and isinstance(n.value.args[1], ast.Constant) else 'month'
                if not isinstance(months, int) or unit not in ('month', 'year'):
                    raise Residue('a date so many periods before the one asked about')
                return f'add_months(period_start, {months * (12 if unit == "year" else 1)})'
            if n.attr == 'date' and isinstance(n.value, ast.Attribute) and n.value.attr == 'start' \
                    and isinstance(n.value.value, ast.Name) and n.value.value.id == 'period':
                return 'period_start'               # the first day of the period asked about
            if n.attr in ('year', 'month') and isinstance(n.value, ast.Attribute) and n.value.attr == 'start' \
                    and isinstance(n.value.value, ast.Name) and n.value.value.id == 'period':
                return ('period_part', n.attr)      # for the start of a year read at another day (below)
            if isinstance(n.value, ast.Name) and n.value.id == 'date' and n.attr in ('max', 'min'):
                #  datetime.date.max: a date after every date a case gives
                return 'date("9999-12-31")' if n.attr == 'max' else 'date("0001-01-01")'
            if isinstance(n.value, ast.Name) and n.value.id in ('np', 'numpy') and n.attr == 'inf':
                self.approx.append('np.inf written as 10^15, a number no amount reaches')
                return '1000000000000000'
            base = self.e(n.value)
            if isinstance(base, tuple) and base[0] == 'param':
                return ('param', base[1] + [n.attr])
            if isinstance(base, tuple) and base[0] in ('period', 'periodexpr') and n.attr in PERIOD_WORDS:
                #  a period near a period near the one asked about
                #  (`period.last_month.last_3_months`)
                inner = PERIOD_WORDS[base[1]].format('period') if base[0] == 'period' else base[1]
                return ('periodexpr', PERIOD_WORDS[n.attr].format(inner))
            if isinstance(base, tuple) and base[0] == 'period' and base[1] in ('n_2', 'last_year', 'this_year') \
                    and n.attr in ('start', 'stop'):
                #  the first or last day of a year near the one asked about,
                #  to read the parameters at (`parameters(period.n_2.stop)`)
                return ('date_rel', 'yearend' if n.attr == 'stop' else 'yearstart',
                        {'n_2': -2, 'last_year': -1, 'this_year': 0}[base[1]])
            if isinstance(base, tuple) and base[0] == 'pindex':
                #  a node chosen by a code, then one of its children
                #  (`coefficients[zone_apl].degressivite`): a match on the
                #  code, each arm that child of the code's node
                _, path, first = base
                return ('pmatch', first, {k: ('param', path + [k, n.attr]) for k in self.params.keys(path)})
            if isinstance(base, tuple) and base[0] == 'pmatch':
                return ('pmatch', base[1], {k: self.pattr(a, n.attr) for k, a in base[2].items()})
            if isinstance(base, tuple) and base[0] == 'enum':
                return "'" + n.attr + "'"
            if n.attr in ('name', 'value', 'index') and isinstance(base, str) and base.startswith("'"):
                return base                 # a member of an enumeration, by its name
            raise Residue(f'the attribute .{n.attr}')
        if isinstance(n, ast.Subscript):
            base = self.e(n.value)
            idx = n.slice
            if isinstance(base, tuple) and base[0] == 'param' and base[1] and base[1][-1] in ('thresholds', 'rates', 'amounts'):
                #  scale.thresholds[-1]: one bracket's threshold, a parameter like any other
                k = idx.value if isinstance(idx, ast.Constant) else -idx.operand.value \
                    if isinstance(idx, ast.UnaryOp) and isinstance(idx.op, ast.USub) and isinstance(idx.operand, ast.Constant) else None
                brackets = getattr(self.params.node(base[1][:-1]), 'brackets', None)
                if not isinstance(k, int) or not brackets or not -len(brackets) <= k < len(brackets):
                    raise Residue(f'the bracket {".".join(base[1])}[…]')
                what = base[1][-1][:-1]
                i = k % len(brackets)
                return self.params._bracket(base[1][:-1], i, what, brackets[i].children[what])
            if isinstance(base, tuple) and base[0] == 'param':
                #  a child of the parameter node, by a key the formula writes
                #  (`cotisations_employeur['prive_cadre']`): the child itself
                key = self.python_value(idx)
                if isinstance(key, str):
                    node = self.params.node(base[1])
                    kids = getattr(node, 'children', None) or {}
                    if key in kids and not hasattr(kids[key], 'values_list'):
                        return ('param', base[1] + [key])
                return self.param_index(base[1], idx)
            if isinstance(base, tuple) and base[0] == 'pindex':
                return self.param_index2(base, idx)
            if isinstance(base, tuple) and base[0] == 'pmatch':
                return ('pmatch', base[1], {k: self.psub(a, idx) for k, a in base[2].items()})
            #  a slice of a list the formula writes out, whose end the
            #  calculation's own year decides (the reports of past years a
            #  deduction may still carry): every element, each counted only
            #  where the slice reaches it
            if isinstance(idx, ast.Slice) and isinstance(base, tuple) and base[0] in ('list', 'exprs') \
                    and idx.step is None:
                lo = 0 if idx.lower is None else self.python_value(idx.lower)
                if lo != 0 or idx.upper is None:
                    raise Residue('a slice of a list this translator does not read')
                hi = self.python_value(idx.upper)
                if isinstance(hi, int):
                    return (base[0], list(base[1])[:hi])
                return ('slice', list(base[1]), self.expr(idx.upper))
            if isinstance(base, tuple) and base[0] == 'globals':
                key = self.python_value(idx)
                if isinstance(key, str):
                    return ('global', key)
                #  a name the formula puts together from a text it reads
                raise Residue('a helper of the module read by a name the case decides')
            #  an index into a dictionary or a list of the module
            v = self.python_value(n)
            if isinstance(v, bool):
                raise Residue('a subscript')
            if isinstance(v, (str, int, float)):
                return bytetext(v) if isinstance(v, str) else repr(v)
            if isinstance(v, (list, tuple)):
                return ('list', list(v))
            raise Residue('a subscript')
        if isinstance(n, ast.Call):
            return self.call(n)
        if isinstance(n, ast.ListComp) and len(n.generators) == 1 and isinstance(n.generators[0].target, ast.Name) \
                and isinstance(n.elt, ast.Name) and n.elt.id == n.generators[0].target.id \
                and all(isinstance(c, ast.Compare) and len(c.ops) == 1 and isinstance(c.ops[0], (ast.In, ast.NotIn))
                        and isinstance(c.left, ast.Name) and c.left.id == n.elt.id for c in n.generators[0].ifs):
            #  [v for v in names if v in other], of lists the program writes
            #  or a parameter holds: a list worked out when the twin is written
            g = n.generators[0]
            items = self.names_of(g.iter)
            for c in g.ifs:
                other = set(self.names_of(c.comparators[0]))
                items = [i for i in items if (i in other) == isinstance(c.ops[0], ast.In)]
            return ('list', items)
        if isinstance(n, ast.ListComp) and len(n.generators) == 1 and not n.generators[0].ifs \
                and isinstance(n.generators[0].target, ast.Name) \
                and not (isinstance(n.elt, ast.Name) and n.elt.id == n.generators[0].target.id):
            #  [f(x) for x in names], names written in the program: the values
            #  one by one, for an or, an and, a sum
            g = n.generators[0]
            try:
                names = self.names_of(g.iter)
            except Residue:
                names = None
            if names is not None:
                vals = [self.expr(subst(n.elt, {g.target.id: ast.Constant(v)})) for v in names]
                return ('exprs', vals)
        if isinstance(n, ast.ListComp) and len(n.generators) == 1:
            g = n.generators[0]
            src = self.e(g.iter)
            if isinstance(src, tuple) and src[0] == 'param' and isinstance(g.target, ast.Name) \
                    and isinstance(n.elt, ast.Name) and n.elt.id == g.target.id:
                node = self.params.node(src[1])
                vals = sorted(node.values_list, key=lambda p: p.instant_str)
                items = list(vals[-1].value or [])
                for cond in g.ifs:
                    if isinstance(cond, ast.Compare) and len(cond.ops) == 1 and isinstance(cond.comparators[0], ast.Constant):
                        c = cond.comparators[0].value
                        if isinstance(cond.ops[0], ast.NotEq):
                            items = [i for i in items if i != c]
                        elif isinstance(cond.ops[0], ast.Eq):
                            items = [i for i in items if i == c]
                        else:
                            raise Residue('a list comprehension with another test')
                    else:
                        raise Residue('a list comprehension with another test')
                return ('list', items)
            raise Residue('ListComp')
        raise Residue(type(n).__name__)

    def is_calc(self, n):
        """A scale's calc(), or a name bound to one (or to a where between two)."""
        if isinstance(n, ast.Name):
            return n.id in getattr(self, 'calcnames', set())
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr == 'calc':
            return True
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id == 'where' and len(n.args) == 3:
            return self.is_calc(n.args[1]) and self.is_calc(n.args[2])
        return False

    def mtext(self, x):
        """A member-level value as formula text: a member's variable, an
        expression over them, or a value of the unit (the same for each)."""
        if isinstance(x, tuple):
            if x[0] in ('members', 'mexpr', 'mbool', 'mpred'):
                return x[1]
            if x[0] == 'param':
                return self.params.scalar(x[1])
            raise Residue(f'{x[0]} in a member expression')
        return x

    def helper(self, text, dtype):
        #  named neutrally: a name made of the formula would carry its `or`
        #  and `not` into the sentence
        #  (a person `counts for` the variable, or has a `member part of` it)
        k = len([h for h in HELPERS if h[0] == self.var.name and not (len(h) == 3 and h[1] == 'step')]) + 1
        base = self.var.name[3:] if self.var.name.startswith('is_') else self.var.name   # (counts for uc eligible)
        stem = f"{WORDS['counts_for']}_{base}" if dtype == 'Judgment' else f"{WORDS['member_part_of']}_{base}"
        n = HELPERS.setdefault((self.var.name, text), stem if k == 1 else f'{stem}_{k}')
        hname = n
        self.helpers[hname] = {'name': hname, 'kind': 'derived', 'entity': camel(person_key(self.system)), 'dtype': dtype,
                               'source': WORDS['each_member'].format(t=text),
                               'versions': [{'effective_from': '1900-01-01', 'formula': text}]}
        return hname

    def group_helper(self, grp, text, dtype, kind='any'):
        #  a value of the group the person belongs to, defined over the
        #  group's members: the group answers it, the person reads it. Named
        #  by what it says of the members ("*a benunit* has members who
        #  count for ...")
        base = self.var.name[3:] if self.var.name.startswith('is_') else self.var.name
        stem = f'{WORDS[kind]}_{base}'
        if (self.var.name, grp, text) in HELPERS:
            n = HELPERS[(self.var.name, grp, text)]
        else:
            used = set(HELPERS.values())
            n = stem
            k = 2
            while n in used:
                n, k = f'{stem}_{k}', k + 1
            HELPERS[(self.var.name, grp, text)] = n
        self.helpers[n] = {'name': n, 'kind': 'derived', 'entity': camel(grp), 'dtype': dtype,
                           'source': WORDS['members_of'].format(g=grp, t=text),
                           'versions': [{'effective_from': '1900-01-01', 'formula': text}]}
        return n

    def boolmul(self, n):
        if isinstance(n, ast.Constant) and isinstance(n.value, bool):
            return ('bool', 'true' if n.value else 'false')
        if isinstance(n, ast.Name) and self.env.get(n.id) in ('true', 'false'):
            return ('bool', self.env[n.id])            # eligible = True
        if isinstance(n, ast.Compare) or (isinstance(n, ast.UnaryOp) and isinstance(n.op, ast.Invert)) \
                or (isinstance(n, ast.BinOp) and isinstance(n.op, (ast.BitAnd, ast.BitOr))):
            return ('bool', self.expr(n))
        if isinstance(n, ast.BinOp) and isinstance(n.op, (ast.Mult, ast.Add)):
            a, b = self.boolmul(n.left), self.boolmul(n.right)
            if a[0] == 'bool' and b[0] == 'bool':
                return ('bool', f'({a[1]} and {b[1]})' if isinstance(n.op, ast.Mult) else f'({a[1]} or {b[1]})')
        if isinstance(n, ast.Name) and n.id in self.boolnames:
            return ('bool', self.env[n.id])
        try:
            t = self.e(n)
        except Residue:
            return ('other', None)
        if isinstance(t, str) and t.startswith('?bool:'):
            return ('bool', t[6:])
        if isinstance(t, str) and re.fullmatch(r'\(count_where\(member_of_[a-z_]+, [a-z_0-9]+\) (> 0|== len\(member_of_[a-z_]+\))\)', t):
            return ('bool', t)          # whether some (or all) members count
        #  (a name may have capitals: openfisca-france's caseT, a box of the
        #  tax form, multiplied by a rate, was read as a number and stated
        #  nowhere)
        m = re.fullmatch(r'member_of_[a-z_]+\.([A-Za-z_][A-Za-z0-9_]*)', t) if isinstance(t, str) else None
        if m and ((m.group(1) in self.system.variables and self.system.variables[m.group(1)].value_type is bool)
                  or self.helpers.get(m.group(1), {}).get('dtype') == 'Judgment'):
            return ('bool', t)          # a yes-or-no value of the person's group
        if isinstance(t, str) and re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', t) and t in self.system.variables \
                and self.system.variables[t].value_type is bool:
            return ('bool', t)
        return ('other', None)

    def scale_text(self, br, x, factor=None, decimals=None):
        """A marginal scale written out: for each bracket, its rate times the
        part of x that falls in it. `factor` multiplies every threshold (the
        social-security ceiling, in whose units French scales are written);
        `decimals` rounds each bracket's part and its product, as
        openfisca-core's `round_base_decimals` does."""
        def thr(t):
            return f'({t} * {factor})' if factor else t
        terms = []
        for i, (rate, t) in enumerate(br):
            upper = f'min({x}, {thr(br[i + 1][1])})' if i + 1 < len(br) else x
            part = f'max(0, {upper} - {thr(t)})'
            if decimals is not None:
                part = f'round({part}, {decimals})'
                terms.append(f'round({rate} * {part}, {decimals})')
            else:
                terms.append(f'({rate} * {part})')
        return '(' + ' + '.join(terms) + ')' if terms else '0'

    def elements(self, node):
        """The expressions of a list the formula writes out, or of one it
        bound to a name (the conditions and the amounts of a select)."""
        if isinstance(node, (ast.List, ast.Tuple)):
            return list(node.elts)
        t = self.e_safe(node)
        if isinstance(t, tuple) and t[0] == 'exprs':
            return list(t[1])
        if isinstance(t, tuple) and t[0] == 'list':
            return [ast.Constant(v) for v in t[1]]
        return None

    def cond(self, node):
        """An expression as a condition: a yes-or-no value as it is, a number
        as `it is not 0` (Python reads a non-zero number as true)."""
        k, t = self.boolmul(node)
        if k == 'bool':
            return t
        o = self.e(node)
        if isinstance(o, tuple) and o[0] in ('members', 'mexpr', 'mbool', 'mpred'):
            return self.mtext(o)
        return f'({self.expr(node)} != 0)'

    def numterm(self, t):
        """A term of a sum the formula builds from a list of names: a name
        of a yes-or-no variable counts as 1 or 0 (openfisca-france's
        `f7xe_2025`, an amount of the tax form declared yes-or-no, in the
        Scellier sums `sum([foyer_fiscal(inv, period) for inv in inv_5])`)."""
        if isinstance(t, str) and re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', t) and t in self.system.variables \
                and self.system.variables[t].value_type is bool:
            return f'(if {t}: 1 else: 0)'
        return t

    def sumterm(self, node):
        """One term of a sum: a number, or a yes or no counted as 1 or 0."""
        k, t = self.boolmul(node)
        if k == 'bool':
            return f'(if {t}: 1 else: 0)'
        o = self.e(node)
        if isinstance(o, tuple) and o[0] in ('members', 'mexpr', 'mbool', 'mpred'):
            return self.mtext(o)
        return self.expr(node)

    def code_test(self, rv, code):
        """Whether the member who holds a role has a code (a roleval): the
        test the comparison `x == code` is read as."""
        _, grp, rolename, text = rv
        h = self.helper(f"({rolename} and ({text} == '{code}'))", 'Judgment')
        own = f'member_of_{grp}'
        self.relations.add(own)
        return f'(count_where({own}, {h}) > 0)'

    def code_chain(self, rv, arms):
        """A choice by a code the member who holds a role has: one test per
        code, in turn (a sum of codes means nothing)."""
        text = '0'
        for k, v in reversed(list(arms)):
            text = f'(if {self.code_test(rv, k)}: {v} else: {text})'
        return text

    def param_index(self, path, idx):
        node = self.params.node(path)
        kids = getattr(node, 'children', None)
        sub = self.e(idx)
        if isinstance(sub, tuple) and sub[0] == 'roleval' and kids:
            if all(hasattr(k, 'values_list') for k in kids.values()):
                return self.code_chain(sub, [(k, self.params.scalar(path + [k])) for k in kids])
            return ('pmatch', sub, {k: ('param', path + [k]) for k in kids})
        if kids and all(hasattr(k, 'values_list') for k in kids.values()):
            return f'{self.params.table(path)}[{self.expr(idx)}]'
        if kids:
            return ('pindex', path, self.expr(idx))
        raise Residue('an index into a parameter that is not a table')

    def pmatch_arm(self, a):
        if isinstance(a, tuple) and a[0] == 'pmatch':
            return self.pmatch_text(a)
        return self.expr_of(a) if isinstance(a, tuple) else a

    def pattr(self, arm, attr):
        if isinstance(arm, tuple) and arm[0] == 'param':
            return ('param', arm[1] + [attr])
        if isinstance(arm, tuple) and arm[0] == 'pmatch':
            return ('pmatch', arm[1], {k: self.pattr(a, attr) for k, a in arm[2].items()})
        raise Residue(f'the attribute .{attr} of a parameter chosen by a code')

    def psub(self, arm, idx):
        """One arm of a match on a code, subscripted: as a parameter node is."""
        if not (isinstance(arm, tuple) and arm[0] == 'param'):
            raise Residue('a subscript of a parameter chosen by a code')
        key = self.python_value(idx)
        if isinstance(key, str):
            kids = getattr(self.params.node(arm[1]), 'children', None) or {}
            if key in kids and not hasattr(kids[key], 'values_list'):
                return ('param', arm[1] + [key])
        r = self.param_index(arm[1], idx)
        if isinstance(r, tuple):
            raise Residue('a parameter chosen by two codes and a third')
        return r

    def pmatch_text(self, t):
        first, arms = t[1], t[2]
        if isinstance(first, tuple) and first[0] == 'cond':
            a, b = (self.pmatch_arm(arms[k]) for k in ('then', 'else'))
            return f'(if {first[1]}: {a} else: {b})'
        if isinstance(first, tuple) and first[0] == 'roleval':
            return self.code_chain(first, [(k, self.expr_of(a) if isinstance(a, tuple) else a) for k, a in arms.items()])
        texts = []
        for k, a in arms.items():
            v = self.expr_of(a) if isinstance(a, tuple) else a
            texts.append(f"    '{k}' => {v}")
        return '(match ' + first + ':\n' + '\n'.join(texts) + '\n    _ => 0)'

    def param_index2(self, base, idx):
        _, path, first = base
        if isinstance(self.e(idx), tuple) and self.e(idx)[0] == 'roleval':
            raise Residue('a parameter chosen by a code and by a code a role holder has')
        arms = []
        for k in self.params.keys(path):
            arms.append(f"    '{k}' => {self.params.table(path + [k])}[{self.expr(idx)}]")
        return '(match ' + first + ':\n' + '\n'.join(arms) + '\n    _ => 0)'

    def call(self, n):
        f = n.func
        fname = f.attr if isinstance(f, ast.Attribute) else f.id if isinstance(f, ast.Name) else None
        # parameters(period)
        if isinstance(f, ast.Name) and f.id == 'parameters':
            if n.args and not (isinstance(n.args[0], ast.Name) and n.args[0].id == 'period'):
                a = self.e_safe(n.args[0])
                if isinstance(a, tuple) and a[0] == 'year_start':
                    return ('param', [f'@{a[1]}'])     # the parameters at the start of the year
                if isinstance(a, tuple) and a[0] == 'date_rel':
                    return ('param', [f'>{a[1]}:{a[2]}'])   # at a date the calculation date decides
                if isinstance(a, tuple) and a[0] == 'instant':
                    return ('param', [f'={a[1]}'])          # at a day the formula writes
                #  parameters(Period(('month', Instant((2016, 1, 1)), 1))): at
                #  the start of a period the formula writes
                q = n.args[0]
                if isinstance(q, ast.Call) and isinstance(q.func, ast.Name) and q.func.id == 'Period' and q.args \
                        and isinstance(q.args[0], ast.Tuple) and len(q.args[0].elts) >= 2:
                    st = self.e_safe(q.args[0].elts[1])
                    if isinstance(st, tuple) and st[0] == 'instant':
                        return ('param', [f'={st[1]}'])
                if isinstance(a, tuple) and a[0] == 'period' and a[1] in ('n_2', 'last_year', 'this_year'):
                    #  parameters(period.n_2): at the start of that year
                    return ('param', [f'>yearstart:{ {"n_2": -2, "last_year": -1, "this_year": 0}[a[1]]}'])
                if isinstance(n.args[0], ast.Constant) and isinstance(n.args[0].value, str) \
                        and re.fullmatch(r'\d{4}(-\d{2}(-\d{2})?)?', n.args[0].value):
                    #  the parameters at a date, a month or a year the formula
                    #  writes (`parameters('2010')`)
                    d = n.args[0].value
                    d = d if len(d) == 10 else d + '-01' if len(d) == 7 else d + '-01-01'
                    return ('param', [f'={d}'])
                raise Residue('parameters read at a date the formula computes')
            return ('param', [])
        # parameters.gov.x.y(period)
        chain, q = [], f
        while isinstance(q, ast.Attribute):
            chain.insert(0, q.attr); q = q.value
        if isinstance(q, ast.Name) and q.id == 'parameters' and chain:
            return ('param', chain)
        # person.benunit("x", period), person the members of a household: each
        # member's value of the other group it belongs to
        if isinstance(f, ast.Attribute) and f.attr in ENTITY_ARGS and self.is_members(f.value) and n.args:
            name, text = self.read_period(n)
            rel = f'member_of_{f.attr}'
            self.relations.add(rel)
            var = self.system.variables.get(name)
            if text != name:
                h = self.helper(f'{rel}.{text}', 'Judgment' if var is not None and var.value_type is bool else 'Money')
                return ('mbool' if var is not None and var.value_type is bool else 'mexpr', h)
            return ('mbool' if var is not None and var.value_type is bool else 'mexpr', f'{rel}.{name}')
        #  m_3 = period.offset(-3, 'month'): a period near the one asked
        #  about, bound to a name the formula reads variables at
        if fname == 'offset' and isinstance(f, ast.Attribute) and not (
                isinstance(f.value, ast.Attribute) and f.value.attr == 'start'):
            try:
                pe = self.period_expr(n)
            except Residue:
                pe = False
            if pe:
                return ('periodexpr', pe)
        #  period.start.offset(-2, 'year'): the day so many months or years
        #  before the start of the period, to read the parameters at
        if fname == 'offset' and isinstance(f, ast.Attribute) and isinstance(f.value, ast.Attribute) \
                and f.value.attr == 'start' and isinstance(f.value.value, ast.Name) and f.value.value.id == 'period' \
                and n.args:
            k = n.args[0]
            k = k.value if isinstance(k, ast.Constant) else -k.operand.value \
                if isinstance(k, ast.UnaryOp) and isinstance(k.op, ast.USub) and isinstance(k.operand, ast.Constant) else None
            unit = n.args[1].value if len(n.args) > 1 and isinstance(n.args[1], ast.Constant) else 'day'
            if isinstance(k, int) and unit in ('month', 'year'):
                return ('date_rel', 'shift', k * (12 if unit == 'year' else 1))
        #  Instant((period.start.year if period.start.month >= 7 else
        #  period.start.year - 1, 7, 1)): the last 1 July on or before the
        #  calculation date, the start of a year that begins on that day
        if fname == 'Instant' and len(n.args) == 1 and isinstance(n.args[0], ast.Tuple) and len(n.args[0].elts) == 3:
            y, m, d = n.args[0].elts
            mm, dd = self.python_value(m), self.python_value(d)
            src = ast.unparse(y).replace(' ', '')
            if isinstance(mm, int) and dd == 1 and src == \
                    f'period.start.yearifperiod.start.month>={mm}elseperiod.start.year-1':
                return ('year_start', f'{mm:02d}-01')
            vals = [self.python_value(x) for x in (y, m, d)]
            if all(isinstance(x, int) and not isinstance(x, bool) for x in vals):
                return ('instant', f'{vals[0]:04d}-{vals[1]:02d}-{vals[2]:02d}')    # a day the formula writes
            raise Residue('an Instant this translator does not read')
        #  fromiter((table.get(code, default) for code in codes), dtype): each
        #  code looked up in a table of the module, the default where it is
        #  not there (zone_apl by depcom, roadmap Phase 3b′, item 3)
        if fname == 'fromiter' and n.args and isinstance(n.args[0], ast.GeneratorExp) \
                and len(n.args[0].generators) == 1 and not n.args[0].generators[0].ifs:
            g = n.args[0]
            el = g.elt
            if isinstance(el, ast.Call) and isinstance(el.func, ast.Attribute) and el.func.attr == 'get' \
                    and isinstance(el.func.value, ast.Name) and len(el.args) == 2:
                table = self.python_value(el.func.value)
                default = self.python_value(el.args[1])
                if isinstance(table, dict) and table and isinstance(default, (int, float, str)):
                    key = self.expr(g.generators[0].iter)
                    name = self.params.lookup(el.func.value.id, table, default, self.var.name)
                    self.approx.append(f'the code looked up in {el.func.value.id} as the text the case gives')
                    return f'{name}[{key}]'
            raise Residue('fromiter of a generator this translator does not read')
        #  entity.empty_array(): a column of zeros, where a formula starts a
        #  running total
        if fname == 'empty_array' and isinstance(f, ast.Attribute) and not n.args:
            return '0'
        #  individu.has_role(Famille.DEMANDEUR): the person's own role
        #  (roadmap Phase 3b′, item 2)
        if fname == 'has_role' and len(n.args) == 1 and isinstance(f, ast.Attribute):
            if self.var.entity.key in PERSON_ENTITIES:
                return '?bool:' + self.role(n.args[0])
            #  asked of a group's members, inside a question about them
            #  (`menage.members.has_role(Famille.ENFANT)`: each member of the
            #  household, in its own family)
            if self.is_members(f.value):
                return ('mpred', self.role(n.args[0]))
            #  famille.demandeur.has_role(FoyerFiscal.DECLARANT_PRINCIPAL):
            #  whether the member who holds one role of the group holds
            #  another, in a group of its own
            if isinstance(f.value, ast.Attribute) and isinstance(f.value.value, ast.Name) \
                    and f.value.value.id == self.entity_arg and self.var.entity.key not in PERSON_ENTITIES \
                    and f.value.attr in self.roles_of(self.var.entity.key):
                grp = self.var.entity.key
                holder = self.role(f.value.attr, grp)
                other = self.role(n.args[0])
                return self.through_role(grp, holder, other, True)
            raise Residue('has_role asked of something that is not a person')
        #  famille.demandeur('x', period), foyer_fiscal.declarant_principal(…),
        #  menage.personne_de_reference(…): the group reads a value of the
        #  member who holds the role
        if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) and f.value.id == self.entity_arg \
                and self.var.entity.key not in PERSON_ENTITIES and f.attr in self.roles_of(self.var.entity.key) and n.args:
            grp = self.var.entity.key
            rolename = self.role(f.attr, grp)
            name, text = self.read_period(n)
            target = self.system.variables.get(name)
            if target is not None and target.entity.key not in PERSON_ENTITIES:
                raise Residue(f'{f.attr}, a role, reading {name}, which is not a person\'s value')
            self.approx.append(f'{name} read through the {f.attr} of the {grp}: the value of the one member who holds the role')
            if target is not None and getattr(target, 'possible_values', None) is not None:
                #  a code (`statut_marital`): not a sum, which LE cannot add
                #  up, but kept for the comparison that reads it (`== marie`)
                return ('roleval', grp, rolename, text)
            return self.through_role(grp, rolename, text, target is not None and target.value_type is bool)
        #  famille.demandeur.menage('residence_dom', period): the group reads,
        #  through the member who holds the role, a value of that member's
        #  own other group
        if isinstance(f, ast.Attribute) and f.attr in ENTITY_ARGS and isinstance(f.value, ast.Attribute) \
                and isinstance(f.value.value, ast.Name) and f.value.value.id == self.entity_arg \
                and self.var.entity.key not in PERSON_ENTITIES and f.value.attr in self.roles_of(self.var.entity.key) and n.args:
            grp, other = self.var.entity.key, f.attr
            rolename = self.role(f.value.attr, grp)
            name, text = self.read_period(n)
            target = self.system.variables.get(name)
            self.approx.append(f'{name} read through the {f.value.attr} of the {grp}: the value of the {other} '
                               f'of the one member who holds the role')
            if target is not None and getattr(target, 'possible_values', None) is not None:
                #  a code (`statut_occupation_logement`): compared, not
                #  summed, as for a code of the role holder's own
                rel = f'member_of_{other}'
                self.relations.add(rel)
                return ('roleval', grp, rolename, f'{rel}.{text}')
            return self.through_role(grp, rolename, text, target is not None and target.value_type is bool, other=other)
        # np.logical_or.reduce([...]), np.logical_and.reduce([...]): an or, an and
        if fname == 'reduce' and isinstance(f, ast.Attribute) and isinstance(f.value, ast.Attribute) \
                and f.value.attr in ('logical_or', 'logical_and') and len(n.args) == 1:
            items = self.e(n.args[0])
            if not (isinstance(items, tuple) and items[0] == 'exprs'):
                raise Residue('reduce() over a list that is not written in the program')
            op = ' or ' if f.value.attr == 'logical_or' else ' and '
            return '(' + op.join(items[1]) + ')' if items[1] else ('false' if op == ' or ' else 'true')
        # unit.project(x): the unit's value x, the same for each member
        if fname == 'project' and isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) \
                and f.value.id == self.entity_arg and len(n.args) == 1 and self.var.entity.key not in PERSON_ENTITIES:
            t = self.expr(n.args[0])
            grp = self.var.entity.key
            rel = f'member_of_{grp}'
            self.relations.add(rel)
            dtype = 'Judgment' if self.boolmul(n.args[0])[0] == 'bool' else 'Money'
            kind = 'sum' if t.startswith('count_where(') else 'total'
            return ('mexpr' if dtype == 'Money' else 'mbool', f'{rel}.{self.group_helper(grp, t, dtype, kind)}')
        # person.household.sum(x), person the unit's members: for each member,
        # a value of the other group it belongs to (a benefit unit reading its
        # household's total)
        if isinstance(f, ast.Attribute) and f.attr in ('sum', 'any', 'max', 'min') and n.args \
                and isinstance(f.value, ast.Attribute) and f.value.attr in ENTITY_ARGS \
                and self.is_members(f.value.value):
            grp = f.value.attr
            rel = f'member_of_{grp}'
            self.relations.add(rel)
            m = self.member_level(n.args[0])
            if m is None:
                raise Residue(f'{grp}.{f.attr}() of something that is not its members\' values')
            h, isbool = m
            if isbool:
                gtext = f'(count_where({rel}, {h}) > 0)' if f.attr == 'any' else f'count_where({rel}, {h})'
                gtype = 'Judgment' if f.attr == 'any' else 'Money'
            else:
                gtext = f'sum({rel}.{h})' if f.attr == 'sum' else f'{f.attr}({rel}.{h})'
                gtype = 'Money'
            kind = {'sum': 'total' if not isbool else 'sum', 'any': 'any', 'max': 'max', 'min': 'min'}[f.attr]
            g = self.group_helper(grp, gtext, gtype, kind)
            return ('mbool' if gtype == 'Judgment' else 'mexpr', f'{rel}.{g}')
        #  individu.get_holder('x'): the store of a variable's own values
        if fname == 'get_holder' and len(n.args) == 1 and isinstance(n.args[0], ast.Constant):
            return ('holder', n.args[0].value)
        # a function defined inside the formula
        if isinstance(f, ast.Name) and isinstance(self.env.get(f.id), tuple) and self.env[f.id][0] == 'localfn':
            return self.inline_tree(self.env[f.id][1], n, getattr(self, 'fn_globals', {}), f.id, outer=True)
        # person.spm_unit.members("x", period): each member's x, inside a
        # question about the members of the person's group
        if isinstance(f, ast.Attribute) and f.attr == 'members' and self.group_of(f.value) and n.args:
            name, text = self.read_period(n)
            if text != name:
                var = self.system.variables.get(name)
                return ('mbool' if var is not None and var.value_type is bool else 'mexpr', text)
            return self.member_read(name, n)
        # entity("var", period)
        if isinstance(f, ast.Name) and f.id == self.entity_arg:
            return self.scaled(self.read(n), n)
        if isinstance(f, ast.Name) and self.env.get(f.id) == ('memberfn',):
            name, text = self.read_period(n)
            if text != name:
                var = self.system.variables.get(name)
                return ('mbool' if var is not None and var.value_type is bool else 'mexpr', text)
            return self.member_read(name, n)
        # unit.household("var", period): a projection to the group
        if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) and f.value.id == self.entity_arg \
                and f.attr in ENTITY_ARGS:
            name = n.args[0].value if n.args and isinstance(n.args[0], ast.Constant) else None
            target = self.system.variables.get(name)
            if self.var.entity.key in PERSON_ENTITIES and target is not None and (target.formulas or getattr(target, 'adds', None)):
                #  a value the program computes for the person's group: read
                #  from the group the person is a member of (roadmap §8,
                #  Phase 3b work left, item 2)
                _, text = self.read_period(n)
                rel = f'member_of_{f.attr}'
                self.relations.add(rel)
                return f'{rel}.{text}'
            if self.var.entity.key not in PERSON_ENTITIES and target is not None and (target.formulas or getattr(target, 'adds', None)):
                #  a value the program computes for another group: read
                #  through the members, whose group it is (all the members of
                #  a benefit unit are in one household): the largest of their
                #  groups' values (roadmap §8, Phase 3b work left, a group
                #  reading another group's value)
                _, v = self.read_period(n)
                rel, own = f'member_of_{f.attr}', f'member_of_{self.var.entity.key}'
                self.relations.add(rel); self.relations.add(own)
                if target.value_type is bool:
                    h = self.helper(f'{rel}.{v}', 'Judgment')
                    return f'(count_where({own}, {h}) > 0)'
                h = self.helper(f'{rel}.{v}', 'Money')
                return f'max({own}.{h})'
            #  an input of another entity: read through the link between
            #  them, never as the subject's own (which would give one
            #  template two kinds of subject: the OpenFisca review's finding
            #  on SNAP's `is_homeless`, roadmap §8 Phase 3b work left)
            if target is not None and f.attr != self.var.entity.key:
                _, text = self.read_period(n)
                if self.var.entity.key in PERSON_ENTITIES:
                    rel = f'member_of_{f.attr}'
                    self.relations.add(rel)
                    return f'{rel}.{text}'
                rel, own = f'member_of_{f.attr}', f'member_of_{self.var.entity.key}'
                self.relations.add(rel); self.relations.add(own)
                self.approx.append(f'{name}, a value of the {f.attr}, read through the members of the '
                                   f'{self.var.entity.key}, who are all in one {f.attr}')
                if target.value_type is bool:
                    h = self.helper(f'{rel}.{text}', 'Judgment')
                    return f'(count_where({own}, {h}) > 0)'
                h = self.helper(f'{rel}.{text}', 'Money')
                return f'max({own}.{h})'
            return self.scaled(self.read(n), n)
        # person.get_rank(person.<group>, key, condition=c): the person's place
        # (from 0) among the members of its group for whom c holds, by key
        # ascending: the members with a smaller key (roadmap §8, Phase 3b work
        # left, item 1; ties share a place, where the engine orders them by
        # their position in the group)
        if fname == 'get_rank' and isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) \
                and f.value.id == self.entity_arg and self.var.entity.key in PERSON_ENTITIES and len(n.args) >= 2 \
                and isinstance(n.args[0], ast.Attribute) and n.args[0].attr in ENTITY_ARGS:
            grp = n.args[0].attr
            rel = f'member_of_{grp}'
            self.relations.add(rel)
            key = self.helper(self.expr(n.args[1]), 'Money')
            c = next((k.value for k in n.keywords if k.arg == 'condition'), n.args[2] if len(n.args) > 2 else None)
            if c is None:
                cond = 'none'
            else:
                b = self.boolmul(c)
                if b[0] != 'bool':
                    raise Residue('get_rank() with a condition that is not yes or no')
                cond = self.helper(b[1], 'Judgment')
            self.approx.append(f'{self.var.name}: members with the same key share a place (the engine orders them by position)')
            return f'rank_in_group({rel}, {key}, {cond})'
        if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) and f.value.id == self.entity_arg:
            #  a group's aggregate over the members holding a role
            #  (`famille.min(age_en_mois_i, role = Famille.ENFANT)`):
            #  the aggregate over those members only (Phase 3b′, item 2)
            rolearg = next((k.value for k in n.keywords if k.arg == 'role'), None)
            if rolearg is not None and f.attr in ('sum', 'any', 'all', 'max', 'min') and n.args:
                grp = self.var.entity.key
                rel = f'member_of_{grp}'
                self.relations.add(rel)
                #  the role may be one of another group the members belong
                #  to (`menage.sum(…, role = FoyerFiscal.DECLARANT_PRINCIPAL)`:
                #  the members of the household who declare for their own tax
                #  household)
                rolename = self.role(rolearg)
                m = self.member_level(n.args[0])
                if m is None:
                    raise Residue(f'{self.entity_arg}.{f.attr}(role=…) of something that is not its members\' values')
                v, isbool = m
                if f.attr in ('max', 'min'):
                    if isbool:
                        raise Residue(f'the {f.attr} of a yes-or-no value over the members holding a role')
                    return f'{f.attr}_where({rel}, {v}, {rolename})'
                if f.attr == 'sum':
                    if isbool:
                        h = self.helper(f'({rolename} and {v})', 'Judgment')
                        return f'count_where({rel}, {h})'
                    h = self.helper(f'(if {rolename}: {v} else: 0)', 'Money')
                    return f'sum({rel}.{h})'
                h = self.helper(f'({rolename} and {v})' if isbool else f'({rolename} and {v} != 0)', 'Judgment')
                hr = self.helper(rolename, 'Judgment') if False else rolename
                if f.attr == 'any':
                    return f'(count_where({rel}, {h}) > 0)'
                return f'(count_where({rel}, {h}) == count_where({rel}, {hr}))'
            if f.attr == 'members' and n.args:
                name, text = self.read_period(n)
                if text != name:
                    var = self.system.variables.get(name)
                    return ('mbool' if var is not None and var.value_type is bool else 'mexpr', text)
                return self.member_read(name, n)
            if f.attr in ('sum', 'any', 'all') and n.args:
                m = self.e(n.args[0])
                if isinstance(m, tuple) and m[0] == 'mexpr':
                    m = ('members', self.helper(m[1], 'Money'))
                if isinstance(m, tuple) and m[0] == 'mbool':
                    m = ('mpred', self.helper(m[1], 'Judgment'))
                if isinstance(m, tuple) and m[0] in ('members', 'mpred'):
                    rel = f'member_of_{self.var.entity.key}'
                    self.relations.add(rel)
                    v = m[1]
                    if f.attr == 'sum' and m[0] == 'members':
                        k = period_factor(self.system, self.var, v)
                        return f'(sum({rel}.{v}){k})' if k else f'sum({rel}.{v})'
                    if f.attr == 'sum' and m[0] == 'mpred':
                        return f'count_where({rel}, {v})'      # adding up yes-or-no values counts them
                    if f.attr == 'any':
                        return f'(count_where({rel}, {v}) > 0)'
                    if f.attr == 'all':
                        return f'(count_where({rel}, {v}) == len({rel}))'
                raise Residue(f'{self.entity_arg}.{f.attr}() of something that is not its members\' values')
            if f.attr == 'nb_persons' and not n.args:
                rel = f'member_of_{self.var.entity.key}'
                self.relations.add(rel)
                return f'len({rel})'
            if f.attr in ('max', 'min') and n.args:
                m = self.e(n.args[0])
                if isinstance(m, tuple) and m[0] == 'mexpr':
                    m = ('members', self.helper(m[1], 'Money'))
                if isinstance(m, tuple) and m[0] == 'members':
                    rel = f'member_of_{self.var.entity.key}'
                    self.relations.add(rel)
                    return f'{f.attr}({rel}.{m[1]})'
            if f.attr == 'nb_persons' and n.args:
                #  the members with a role (household.nb_persons(Household.ADULT)):
                #  a count of the members the case gives that role
                rel = f'member_of_{self.var.entity.key}'
                self.relations.add(rel)
                return f'count_where({rel}, {self.role(n.args[0])})'
            raise Residue(f'{self.entity_arg}.{f.attr}()')
        # person.<group>.any(...), .sum, .all, .max, .min, .nb_persons():
        # a question about the members of the person's group, answered by
        # the group and read from it (roadmap §8, Phase 3b work left, items 1, 2)
        if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Attribute) \
                and isinstance(f.value.value, ast.Name) and f.value.value.id == self.entity_arg \
                and self.var.entity.key in PERSON_ENTITIES and f.value.attr in ENTITY_ARGS \
                and f.attr in ('any', 'all', 'sum', 'max', 'min', 'nb_persons'):
            grp = f.value.attr
            rel = f'member_of_{grp}'
            self.relations.add(rel)
            if f.attr == 'nb_persons':
                if n.args:
                    raise Residue(f'{self.entity_arg}.{grp}.nb_persons() of a role')
                gtext, gtype = f'len({rel})', 'Money'
            else:
                if not n.args:
                    raise Residue(f'{self.entity_arg}.{grp}.{f.attr}() of nothing')
                m = self.member_level(n.args[0])
                if m is not None:
                    #  the members' own values (spm_unit.members("age", period) < 6)
                    h, isbool = m
                    b = ('bool', None) if isbool else ('other', None)
                else:
                    b = self.boolmul(n.args[0])
                if m is not None and not isbool and f.attr in ('any', 'all'):
                    raise Residue(f'{self.entity_arg}.{grp}.{f.attr}() of a value that is not yes or no')
                if m is not None:
                    if isbool:
                        gtext = {'any': f'(count_where({rel}, {h}) > 0)',
                                 'all': f'(count_where({rel}, {h}) == len({rel}))',
                                 'sum': f'count_where({rel}, {h})'}.get(f.attr)
                        if gtext is None:
                            raise Residue(f'{self.entity_arg}.{grp}.{f.attr}() of a yes or no')
                        gtype = 'Money' if f.attr == 'sum' else 'Judgment'
                    else:
                        gtext = f'sum({rel}.{h})' if f.attr == 'sum' else f'{f.attr}({rel}.{h})'
                        gtype = 'Money'
                elif f.attr in ('any', 'all') or (f.attr == 'sum' and b[0] == 'bool'):
                    if b[0] != 'bool':
                        raise Residue(f'{self.entity_arg}.{grp}.{f.attr}() of a value that is not yes or no')
                    h = self.helper(b[1], 'Judgment')
                    gtext = {'any': f'(count_where({rel}, {h}) > 0)',
                             'all': f'(count_where({rel}, {h}) == len({rel}))',
                             'sum': f'count_where({rel}, {h})'}[f.attr]
                    gtype = 'Money' if f.attr == 'sum' else 'Judgment'
                else:
                    t = self.e(n.args[0])
                    if not isinstance(t, str):
                        raise Residue(f'{self.entity_arg}.{grp}.{f.attr}() of {t[0]}')
                    h = self.helper(t, 'Money')
                    gtext = f'sum({rel}.{h})' if f.attr == 'sum' else f'{f.attr}({rel}.{h})'
                    gtype = 'Money'
            kind = f.attr if f.attr != 'sum' or gtype == 'Money' and gtext.startswith('count_where') else 'total'
            g = self.group_helper(grp, gtext, gtype, kind)
            return f'{rel}.{g}'
        if fname == 'add' and len(n.args) == 3 and not isinstance(n.args[2], (ast.List, ast.Tuple)):
            lst = self.e(n.args[2])
            if isinstance(lst, tuple) and lst[0] == 'list':
                n = ast.Call(func=n.func, args=[n.args[0], n.args[1], ast.List(elts=[ast.Constant(x) for x in lst[1]])], keywords=[])
                lst = None
            if lst is not None and isinstance(lst, tuple) and lst[0] == 'param':
                node = self.params.node(lst[1])
                vals = sorted(node.values_list, key=lambda p: p.instant_str)
                self.params.files.add(getattr(node, 'file_path', None))
                #  a list that changed over time: the sum of each period's
                #  list, chosen by the calculation date
                eras = []
                for v in vals:
                    if not eras or eras[-1][1] != list(v.value or []):
                        eras.append((v.instant_str, list(v.value or [])))
                call = lambda names: ast.Call(func=n.func, args=[n.args[0], n.args[1], ast.List(elts=[ast.Constant(x) for x in names])], keywords=[])
                text = self.call(call(eras[-1][1]))
                for (_, names), (since, _) in zip(reversed(eras[:-1]), reversed(eras[1:])):
                    text = f'(if (period_start < date("{since}")): {self.call(call(names))} else: {text})'
                return text
        if fname == 'add' and len(n.args) == 3 and isinstance(n.args[2], (ast.List, ast.Tuple)):
            if not (isinstance(n.args[1], ast.Name) and n.args[1].id == 'period'):
                raise Residue('add() over another period')
            names = [a.value for a in n.args[2].elts if isinstance(a, ast.Constant)]
            terms = []
            for v in names:
                if v not in self.system.variables:
                    if not getattr(self.system, 'static', False):
                        raise Residue(f'unknown variable {v}')
                    self.system.unknown(v, self.var)
                self.reads.add(v)
                yes_no = self.system.variables[v].value_type is bool        # (a yes-or-no value adds as 1 or 0)
                if self.system.variables[v].entity.key in PERSON_ENTITIES and self.var.entity.key not in PERSON_ENTITIES:
                    rel = f'member_of_{self.var.entity.key}'      # added up over the members
                    self.relations.add(rel)
                    t = f'count_where({rel}, {v})' if yes_no else f'sum({rel}.{v})'
                else:
                    t = f'(if {v}: 1 else: 0)' if yes_no else v
                k = period_factor(self.system, self.var, v)
                terms.append(f'({t}{k})' if k else t)
            return '(' + ' + '.join(terms) + ')' if terms else '0'
        # PolicyEngine UK's add_for_members(unit, period, names, members):
        # each person-level variable added up over the members the mask
        # selects, each unit-level variable added as it is (its own
        # utils/benefit_unit.py; roadmap §8, Phase 3b work left, item 4)
        if fname == 'add_for_members' and len(n.args) == 4:
            lst = self.e(n.args[2])
            if isinstance(lst, tuple) and lst[0] == 'param':
                node = self.params.node(lst[1])
                vals = sorted((v for v in node.values_list if v.value is not None), key=lambda v: v.instant_str)
                if not vals or not isinstance(vals[-1].value, list):
                    raise Residue(f'parameter {".".join(lst[1])} is not a list')
                if len({tuple(v.value) for v in vals}) > 1:
                    self.approx.append(f'the list {".".join(lst[1])} changed over time: the latest is read')
                self.params.files.add(getattr(node, 'file_path', None))
                names = list(vals[-1].value)
            elif isinstance(lst, tuple) and lst[0] == 'list':
                names = list(lst[1])
            elif isinstance(n.args[2], (ast.List, ast.Tuple)):
                names = [a.value for a in n.args[2].elts if isinstance(a, ast.Constant)]
            else:
                raise Residue('add_for_members() over a list that is not a parameter')
            mask = self.e(n.args[3])
            if isinstance(mask, tuple) and mask[0] == 'members' and mask[1] in self.system.variables \
                    and self.system.variables[mask[1]].value_type is bool:
                pred = mask[1]
            elif isinstance(mask, tuple) and mask[0] in ('mbool', 'mpred'):
                pred = mask[1] if mask[0] == 'mpred' else self.helper(mask[1], 'Judgment')
            else:
                raise Residue('add_for_members() with a mask that is not a yes-or-no value of the members')
            rel = f'member_of_{self.var.entity.key}'
            self.relations.add(rel)
            terms = []
            for v in names:
                if v not in self.system.variables:
                    raise Residue(f'unknown variable {v}')
                self.reads.add(v)
                k = period_factor(self.system, self.var, v)
                t = f'sum_where({rel}, {v}, {pred})' if self.system.variables[v].entity.key in PERSON_ENTITIES else v
                terms.append(f'({t}{k})' if k else t)
            return '(' + ' + '.join(terms) + ')' if terms else '0'
        # np.isin(x, p.list), is_in(x, p.list): x is one of the list's
        # values, the list a parameter read when the twin is written (roadmap
        # §8, Phase 3b work left, item 6); the twin writes `x is in [...]`
        if fname in ('isin', 'is_in') and len(n.args) == 2:
            lst = self.e(n.args[1])
            if isinstance(lst, tuple) and lst[0] == 'param':
                node = self.params.node(lst[1])
                if not hasattr(node, 'values_list'):
                    raise Residue(f'parameter {".".join(lst[1])} is not a list')
                vals = sorted((v for v in node.values_list if v.value is not None), key=lambda v: v.instant_str)
                if not vals or not all(isinstance(v.value, list) for v in vals):
                    raise Residue(f'parameter {".".join(lst[1])} is not a list')
                self.params.files.add(getattr(node, 'file_path', None))
                #  a list that changed over time: the list of each period,
                #  chosen by the calculation date
                eras = []
                for v in vals:
                    if not eras or eras[-1][1] != v.value:
                        eras.append((v.instant_str, v.value))
            elif isinstance(lst, tuple) and lst[0] == 'list':
                eras = [(None, lst[1])]
            else:
                raise Residue('isin() over a list that is not a parameter')
            x = self.expr(n.args[0])
            lit = lambda v: repr(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else "'" + str(v) + "'"
            one = lambda items: '(' + ' or '.join(f'({x} == {lit(v)})' for v in items) + ')' if items else 'false'
            text = one(eras[-1][1])
            for (_, items), (since, _) in zip(reversed(eras[:-1]), reversed(eras[1:])):
                text = f'(if (period_start < date("{since}")): {one(items)} else: {text})'
            return text
        if fname in ('where',) and len(n.args) == 3:
            parts = [self.e(a) for a in n.args]
            if any(isinstance(x, tuple) and x[0] in ('members', 'mexpr', 'mbool') for x in parts):
                #  a value of each member (a where over the members' values),
                #  for a max, min or sum over them
                c, a, b = (self.mtext(x) for x in parts)
                return ('mexpr', f'(if {c}: {a} else: {b})')
            return f'(if {self.expr(n.args[0])}: {self.expr(n.args[1])} else: {self.expr(n.args[2])})'
        if fname == 'select':
            conds, vals = n.args[0], n.args[1]
            dflt = n.args[2] if len(n.args) > 2 else next((k.value for k in n.keywords if k.arg == 'default'), ast.Constant(0))
            celts, velts = self.elements(conds), self.elements(vals)
            if celts is None or velts is None:
                raise Residue('select over a computed list')
            out = self.expr(dflt)
            for c, v in reversed(list(zip(celts, velts))):
                out = f'(if {self.cond(c)}: {self.expr(v)} else: {out})'
            return out
        if fname in ('max_', 'maximum', 'min_', 'minimum') and len(n.args) == 2:
            g = 'max' if fname in ('max_', 'maximum') else 'min'
            parts = [self.e(a) for a in n.args]
            if any(isinstance(x, tuple) and x[0] in ('members', 'mexpr', 'mbool') for x in parts):
                a, b = (self.mtext(x) for x in parts)
                return ('mexpr', f'{g}({a}, {b})')
            return f'{g}({self.expr(n.args[0])}, {self.expr(n.args[1])})'
        if fname in ('ceil', 'floor') and len(n.args) == 1:
            return f'{fname}({self.expr(n.args[0])})'
        if fname in ('round_', 'round', 'around') and n.args:
            nd = n.args[1] if len(n.args) > 1 else next((k.value for k in n.keywords if k.arg == 'decimals'), ast.Constant(0))
            if not isinstance(nd, ast.Constant):
                raise Residue('rounding to a computed number of decimals')
            o = self.e(n.args[0])
            if isinstance(o, tuple) and o[0] in ('members', 'mexpr', 'mbool'):
                return ('mexpr', f'round({self.mtext(o)}, {nd.value})')
            return f'round({self.expr(n.args[0])}, {nd.value})'
        if fname == 'clip' and len(n.args) == 3:
            return f'min(max({self.expr(n.args[0])}, {self.expr(n.args[1])}), {self.expr(n.args[2])})'
        if fname == 'clip' and isinstance(f, ast.Attribute) and len(n.args) == 2:
            return f'min(max({self.expr(f.value)}, {self.expr(n.args[0])}), {self.expr(n.args[1])})'
        if fname == 'decode_to_str' and isinstance(f, ast.Attribute):
            return self.expr(f.value)              # an enumeration's member is read as its name already
        if fname == 'astype' and isinstance(f, ast.Attribute) and n.args:
            to = n.args[0]
            tname = str(to.value if isinstance(to, ast.Constant) else getattr(to, 'id', getattr(to, 'attr', '')))
            #  a difference of two dates read as a number of months or of days
            #  (roadmap Phase 3b′, item 5): the whole months (or days) from
            #  the earlier date to the later one
            m = re.fullmatch(r'(?:timedelta64|m8)\[([YMD])\]', tname, re.I)
            inner_node = f.value
            #  `(d1 - d2 + epsilon)`: openfisca-france adds a day so that a
            #  birthday counts on the day itself
            if m and isinstance(inner_node, ast.BinOp) and isinstance(inner_node.op, ast.Add) \
                    and isinstance(inner_node.left, ast.BinOp) and isinstance(inner_node.left.op, ast.Sub):
                self.notes.append('a day added to a difference of dates, so that the day itself counts')
                inner_node = inner_node.left
            if m and isinstance(inner_node, ast.BinOp) and isinstance(inner_node.op, ast.Sub):
                later, earlier = self.expr(inner_node.left), self.expr(inner_node.right)
                unit = m.group(1).upper()
                if unit == 'D':
                    return f'days_between({earlier}, {later})'
                if unit == 'M':
                    return f'months_between({earlier}, {later})'
                return f'whole_years({earlier}, {later})'
            inner = self.e(f.value)
            text = self.mtext(inner) if isinstance(inner, tuple) and inner[0] != 'param' else self.expr(f.value)
            if tname == 'bool':
                return f'({text} == 1)' if not self.boolmul(f.value)[0] == 'bool' else text
            if tname in ('int', 'float', 'int64', 'float64', 'float32', 'int32'):
                return f'(if {text}: 1 else: 0)' if self.boolmul(f.value)[0] == 'bool' else text
            if tname == 'str':
                #  the code of a commune, of a region: already a text here
                return text
            raise Residue(f'astype({tname})')
        if fname in ('is_in', 'isin'):
            if fname == 'is_in' and isinstance(f, ast.Name) or \
                    isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) and f.value.id in ('np', 'numpy'):
                x, opts = n.args[0], n.args[1:]      # is_in(x, ...), np.isin(x, [...])
            else:
                x, opts = f.value, n.args
            if len(opts) == 1 and isinstance(opts[0], (ast.List, ast.Tuple)):
                opts = opts[0].elts
            xs = self.expr(x)
            return '(' + ' or '.join(f'({xs} == {self.expr(o)})' for o in opts) + ')'
        #  date(2003, 7, 1): a date written out (openfisca-france compares the
        #  calculation date with the dates a decree took effect)
        if fname == 'date' and len(n.args) == 3 and all(isinstance(a, ast.Constant) for a in n.args):
            y, m, d = (a.value for a in n.args)
            return f'date("{y:04d}-{m:02d}-{d:02d}")'
        #  invert(x): openfisca-france's name for `not x`
        if fname == 'invert' and len(n.args) == 1:
            return f'(not {self.cond(n.args[0])})'
        #  individu.get_holder('x').default_array(): the value of x in a case
        #  that does not state it
        if fname == 'default_array' and isinstance(f, ast.Attribute) and not n.args:
            h = self.e(f.value)
            if isinstance(h, tuple) and h[0] == 'holder':
                var = self.system.variables.get(h[1])
                if var is None:
                    raise Residue(f'the default value of {h[1]}')
                dv = default_value(var)
                return f'date("{dv}")' if isinstance(dv, str) and re.fullmatch(r'\d{4}-\d{2}-\d{2}', str(dv)) \
                    else ('true' if dv else 'false') if var.value_type is bool \
                    else bytetext(dv) if isinstance(dv, str) else repr(dv)
            raise Residue('default_array() of something that is not a holder')
        if fname == 'get_holder' and len(n.args) == 1 and isinstance(n.args[0], ast.Constant):
            return ('holder', n.args[0].value)
        #  the periods at which the engine already holds a value of a
        #  variable: the engine's own cache, not a rule of the law. A twin
        #  holds one case, so nothing is held: the formula falls through to
        #  the rule that works the value out (openfisca-france's `age`, from
        #  the date of birth).
        if fname == 'get_known_periods' and isinstance(f, ast.Attribute) and not n.args:
            h = self.e(f.value)
            if isinstance(h, tuple) and h[0] == 'holder':
                self.notes.append(f'the periods at which the engine holds a value of {h[1]}: '
                                  'none, so the formula works the value out')
                return ('list', [])
            raise Residue('get_known_periods() of something that is not a holder')
        if fname == 'bool' and isinstance(f, ast.Name) and len(n.args) == 1:
            o = self.e(n.args[0])
            if isinstance(o, tuple) and o[0] == 'list':
                return 'true' if o[1] else 'false'
            return f'({self.cond(n.args[0])})'
        if fname == 'sorted' and isinstance(f, ast.Name) and n.args:
            o = self.e(n.args[0])
            if isinstance(o, tuple) and o[0] in ('list', 'exprs'):
                return o
            raise Residue('sorted() of something that is not a list written in the program')
        #  globals()['compute_' + name]: a helper of the module, by a name the
        #  formula puts together
        if fname == 'globals' and isinstance(f, ast.Name) and not n.args:
            return ('globals',)
        #  NumPy's date and duration types (roadmap Phase 3b′, item 5)
        if fname == 'datetime64' and len(n.args) >= 1:
            a = n.args[0]
            if isinstance(a, ast.Constant) and isinstance(a.value, str):
                d = a.value if len(a.value) == 10 else (a.value + '-01-01')[:10] if len(a.value) == 4 \
                    else (a.value + '-01')[:10] if len(a.value) == 7 else None
                if d is None:
                    raise Residue(f'the date {a.value!r}')
                return f'date("{d}")'
            return self.expr(a)                     # a date already
        if fname == 'timedelta64' and len(n.args) >= 1:
            if not isinstance(n.args[0], ast.Constant):
                raise Residue('a duration that is not a number')
            return repr(n.args[0].value)            # the number, in the unit its comparison reads
        #  char.startswith(code, "971"): the first characters of a text
        #  (a commune's code names its department: roadmap Phase 3b′, item 5)
        if fname == 'startswith' and len(n.args) == 2:
            pre = self.e(n.args[1])
            if isinstance(pre, tuple) and pre[0] == 'list':
                return '(' + ' or '.join(f'starts_with({self.expr(n.args[0])}, {bytetext(p)})' for p in pre[1]) + ')'
            return f'starts_with({self.expr(n.args[0])}, {pre})'
        if fname == 'str' and isinstance(f, ast.Name) and len(n.args) == 1:
            t = self.e(n.args[0])
            if isinstance(t, tuple) and t[0] == 'param':
                node = self.params.node(t[1])
                vals = sorted(node.values_list, key=lambda p: p.instant_str)
                if len({v.value for v in vals}) > 1:
                    self.approx.append(f'str() of {".".join(t[1])}, which changes over time: the latest value')
                return "'" + str(vals[-1].value) + "'"
            raise Residue('str() of a computed value')
        if fname == 'formula' and isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) \
                and f.value.id == self.var.name:
            first = self.var.formulas[sorted(self.var.formulas)[0]]
            tr = Translator(self.system, self.params, self.var)
            text, _ = tr.formula(first)
            self.reads |= tr.reads; self.relations |= tr.relations; self.helpers.update(tr.helpers); self.approx += tr.approx; self.musts += tr.musts
            return f'({text})'
        if fname == 'abs' and len(n.args) == 1:
            return f'abs({self.expr(n.args[0])})'
        #  int(x), float(x) of a number: the number (openfisca-france writes
        #  `int(period.start.year)`)
        if fname in ('int', 'float') and isinstance(f, ast.Name) and len(n.args) == 1:
            t = self.expr(n.args[0])
            return t if fname == 'float' else f'floor({t})' if not re.fullmatch(r'[a-z_][a-z0-9_]*', t) else t
        if fname == 'not_' and len(n.args) == 1:
            o = self.e(n.args[0])
            if isinstance(o, tuple) and o[0] in ('members', 'mexpr', 'mbool', 'mpred'):
                return ('mbool', f'(not {self.mtext(o)})')
            return f'(not {self.expr(n.args[0])})'
        #  openfisca-france's own names for NumPy's logical operations
        #  (roadmap Phase 3b′, item 5): or_(a, b), and_(a, b), xor_(a, b)
        if fname in ('or_', 'and_', 'xor_') and len(n.args) >= 2 and not n.keywords:
            member = False
            ts = []
            for a in n.args:
                k, t = self.boolmul(a)
                if k != 'bool':
                    o = self.e(a)
                    if isinstance(o, tuple) and o[0] in ('members', 'mexpr', 'mbool', 'mpred'):
                        t, member = self.mtext(o), True
                    else:
                        t = f'({self.expr(a)} != 0)'    # a number used as a yes or no
                ts.append(t)
            if fname == 'xor_':
                if len(ts) != 2:
                    raise Residue('xor_ of more than two values')
                a, b = ts
                t = f'(({a} or {b}) and not ({a} and {b}))'
            else:
                t = '(' + (' or ' if fname == 'or_' else ' and ').join(ts) + ')'
            return ('mbool', t) if member else t
        #  openfisca-france's own mini(a, b, ...) and maxi(a, b, ...): the
        #  smallest or largest of any number of values
        if fname in ('mini', 'maxi') and len(n.args) >= 2 and not n.keywords:
            g = 'min' if fname == 'mini' else 'max'
            out = self.expr(n.args[0])
            for a in n.args[1:]:
                out = f'{g}({out}, {self.expr(a)})'
            return out
        # Python's own max(a, b), min(a, b) of two values
        if fname in ('max', 'min') and isinstance(f, ast.Name) and len(n.args) == 2 and not n.keywords:
            return f'{fname}({self.expr(n.args[0])}, {self.expr(n.args[1])})'
        #  MarginalRateTaxScale(name = ...): a scale the formula builds,
        #  bracket by bracket (roadmap Phase 3b′, item 5)
        if fname in ('MarginalRateTaxScale', 'SingleAmountTaxScale', 'MarginalAmountTaxScale') \
                and isinstance(f, ast.Name):
            return ('scale', [], None, fname != 'MarginalRateTaxScale')
        #  the keys or the values of a dictionary the formula writes
        if fname in ('keys', 'values', 'items') and isinstance(f, ast.Attribute) and not n.args:
            d = self.python_value(f.value)
            if isinstance(d, dict):
                if fname == 'keys':
                    return ('list', list(d))
                if fname == 'values':
                    return ('list', list(d.values()))
                return ('list', list(d.items()))
            raise Residue(f'{fname}() of something that is not a dictionary written in the program')
        #  set(...) of names the formula writes: the names, without repetition
        if fname == 'set' and isinstance(f, ast.Name) and len(n.args) <= 1:
            if not n.args:
                return ('list', [])
            o = self.e(n.args[0])
            if isinstance(o, tuple) and o[0] == 'list':
                return ('list', list(dict.fromkeys(o[1])))
            v = self.python_value(n.args[0])
            if isinstance(v, (list, tuple)):
                return ('list', list(dict.fromkeys(v)))
            raise Residue('set() of something that is not a list written in the program')
        if fname in ('add', 'update') and isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) \
                and isinstance(self.env.get(f.value.id), tuple) and self.env[f.value.id][0] == 'list':
            #  names.add("x") on a set the formula writes
            lst = list(self.env[f.value.id][1])
            for a in n.args:
                v = self.python_value(a)
                if isinstance(v, (list, tuple)):
                    lst += [x for x in v if x not in lst]
                elif v is not None and v not in lst:
                    lst.append(v)
                elif v is None:
                    raise Residue('a value added to a set that is not written in the program')
            self.env[f.value.id] = ('list', lst)
            return 'true'
        # range(a, b, step): the numbers it names, for a loop the reader unrolls
        if fname == 'range' and isinstance(f, ast.Name) and n.args:
            vs = [self.python_value(a) for a in n.args]
            if all(isinstance(x, int) and not isinstance(x, bool) for x in vs):
                return ('list', list(range(*vs)))
            raise Residue('a range whose bounds the case decides')
        # list(p.names): a parameter's list, read when the twin is written
        if fname == 'list' and isinstance(f, ast.Name) and len(n.args) == 1:
            lst = self.e(n.args[0])
            if isinstance(lst, tuple) and lst[0] == 'list':
                return lst
            if isinstance(lst, tuple) and lst[0] == 'param':
                return ('list', self.param_list(lst[1]))
            raise Residue('list() of something that is not a list of names')
        # pd.Series(x).map({...}).values, Enum.encode(x): a dictionary of
        # constants applied to a code (roadmap §8, Phase 3b work left, item 7)
        if fname == 'Series' and len(n.args) == 1:
            return self.e(n.args[0])
        if fname == 'encode' and len(n.args) == 1:
            return self.e(n.args[0])
        if fname == 'map' and isinstance(f, ast.Attribute) and len(n.args) == 1 and isinstance(n.args[0], ast.Dict):
            table = self.constant_dict(n.args[0])
            if table is None:
                raise Residue('map() through a dictionary that is not written in the program')
            x = self.expr(f.value)
            arms = [(k, v) for k, v in table.items() if k != v]
            if not arms:
                return x
            self.approx.append(f'{self.var.name}: a code the dictionary does not name is kept as it is')
            return '(match ' + x + ':\n' + '\n'.join(f"    '{k}' => '{v}'" for k, v in arms) + f'\n    _ => {x})'
        if fname == 'calc' and isinstance(f, ast.Attribute):
            base = self.e(f.value)
            kw = {k.arg: k.value for k in n.keywords}
            if len(n.args) > 1:
                kw.setdefault('factor', n.args[1])
            if len(n.args) > 2:
                kw.setdefault('round_base_decimals', n.args[2])
            factor = self.expr(kw['factor']) if 'factor' in kw else None
            nd = kw.get('round_base_decimals')
            decimals = nd.value if isinstance(nd, ast.Constant) and isinstance(nd.value, int) else None
            if nd is not None and decimals is None:
                dv = self.python_value(nd)
                decimals = dv if isinstance(dv, int) else None
                if decimals is None:
                    raise Residue('calc() rounded to a number of decimals the formula computes')
            x = self.expr(n.args[0])
            if isinstance(base, tuple) and base[0] == 'scale':
                #  a scale the formula built: its own brackets
                br = [(rate, thr) for thr, rate in base[1]]
                if base[2]:
                    br = [(rate, f'({thr} * {base[2]})') for rate, thr in br]
                if base[3]:
                    out = '0'
                    for rate, thr in br:
                        out = f'(if {x} >= {thr}: {rate} else: {out})'
                    return out
                return self.scale_text(br, x, factor, decimals)
            if not (isinstance(base, tuple) and base[0] == 'param'):
                raise Residue('calc() of something that is not a scale')
            amounts = self.params.amount_scale(base[1])
            if amounts:
                out = '0'
                for amt, thr in amounts:
                    t = f'({thr} * {factor})' if factor else thr
                    out = f'(if {x} >= {t}: {amt} else: {out})'
                return out
            return self.scale_text(self.params.scale(base[1]), x, factor, decimals)
        # sum(f(x) for x in names): a loop over a list written in the
        # program, unrolled into a sum of its terms (roadmap §8, Phase 3b
        # work left, item 3(a))
        #  sum(f()), f a generator of the formula or of the package: the
        #  terms it yields, added up (roadmap Phase 3b′, item 4)
        if fname == 'sum' and len(n.args) == 1 and isinstance(n.args[0], ast.Call):
            t = self.e(n.args[0])
            if isinstance(t, tuple) and t[0] == 'yields':
                terms = [self.mtext(x) if isinstance(x, tuple) else x for x in t[1]]
                if not all(isinstance(x, str) for x in terms):
                    raise Residue('a sum of values that are not numbers')
                return '(' + ' + '.join(self.numterm(x) for x in terms) + ')' if terms else '0'
            if isinstance(t, str):
                return t
            raise Residue('sum() of something that is not a generator')
        #  sum([a, b, c]): the terms added up (roadmap Phase 3b′, item 5)
        if fname == 'sum' and len(n.args) == 1 and isinstance(n.args[0], (ast.List, ast.Tuple)) \
                and not all(isinstance(x, ast.Constant) for x in n.args[0].elts):
            terms = [self.sumterm(x) for x in n.args[0].elts]
            return '(' + ' + '.join(terms) + ')' if terms else '0'
        #  sum(montants), a name the formula bound to a list of values
        if fname == 'sum' and len(n.args) == 1 and isinstance(n.args[0], ast.Name):
            t = self.e(n.args[0])
            if isinstance(t, tuple) and t[0] == 'exprs' and all(isinstance(x, str) for x in t[1]):
                return '(' + ' + '.join(self.numterm(x) for x in t[1]) + ')' if t[1] else '0'
            if isinstance(t, tuple) and t[0] == 'exprs':
                return '(' + ' + '.join(self.sumterm(x) for x in t[1]) + ')' if t[1] else '0'
            if isinstance(t, str):
                return t
            raise Residue('sum() of a name that is not a list of values')
        #  sum([f(x, y) for x in L for y in M(x)]): a loop inside a loop,
        #  both over lists the formula writes (the reports of each year, case
        #  by case)
        if fname == 'sum' and len(n.args) == 1 and isinstance(n.args[0], (ast.GeneratorExp, ast.ListComp)) \
                and len(n.args[0].generators) == 2 and not any(g.ifs for g in n.args[0].generators) \
                and all(isinstance(g.target, ast.Name) for g in n.args[0].generators):
            g1, g2 = n.args[0].generators
            outer = self.constant_items(g1.iter)
            if outer is None:
                raise Residue('a loop over a list that is not written in the program')
            terms = []
            for v1 in outer:
                it2 = subst(g2.iter, {g1.target.id: const_node(v1)})
                inner = self.constant_items(it2)
                if inner is None:
                    raise Residue('an inner loop over a list that is not written in the program')
                for v2 in inner:
                    t = self.e(subst(n.args[0].elt, {g1.target.id: const_node(v1), g2.target.id: const_node(v2)}))
                    t = self.expr_of(t) if isinstance(t, tuple) and t[0] == 'param' else t
                    if not isinstance(t, str):
                        raise Residue('a sum of values that are not numbers')
                    terms.append(t)
            return '(' + ' + '.join(self.numterm(x) for x in terms) + ')' if terms else '0'
        if fname == 'sum' and len(n.args) == 1 and isinstance(n.args[0], (ast.GeneratorExp, ast.ListComp)) \
                and len(n.args[0].generators) == 1 and not n.args[0].generators[0].ifs \
                and isinstance(n.args[0].generators[0].target, ast.Name):
            g = n.args[0].generators[0]
            items = self.e(g.iter)
            if isinstance(items, tuple) and items[0] == 'slice':
                #  the elements the slice reaches, each counted only there
                terms = []
                for k, val in enumerate(items[1]):
                    t = self.e(subst(n.args[0].elt, {g.target.id: ast.Constant(val)}))
                    t = self.expr_of(t) if isinstance(t, tuple) else t
                    if not isinstance(t, str):
                        raise Residue('a sum over a slice of values that are not numbers')
                    terms.append(f'(if {k} < {items[2]}: {t} else: 0)')
                return '(' + ' + '.join(self.numterm(x) for x in terms) + ')' if terms else '0'
            if isinstance(items, tuple) and items[0] == 'param':
                items = ('list', self.param_list(items[1]))      # a parameter's list (item 3(b), unrolled)
            if isinstance(items, tuple) and items[0] == 'range':
                items = ('list', items[1])
            if not (isinstance(items, tuple) and items[0] == 'list'):
                raise Residue('a loop over a list that is not written in the program')
            terms = [self.e(subst(n.args[0].elt, {g.target.id: const_node(v)})) for v in items[1]]
            if any(isinstance(t, tuple) and t[0] in ('members', 'mexpr') for t in terms):
                return ('mexpr', '(' + ' + '.join(self.mtext(t) for t in terms) + ')')
            terms = [self.expr_of(t) if isinstance(t, tuple) and t[0] == 'param' else t for t in terms]
            if not all(isinstance(t, str) for t in terms):
                raise Residue('a sum of values that are not numbers')
            return '(' + ' + '.join(self.numterm(x) for x in terms) + ')' if terms else '0'
        # a helper function of the package, called from the formula: read from
        # its own source and inlined (roadmap §8, Phase 3b work left, item 4).
        # `m.f(...)` is the function of module m, never the global of that name
        # (openfisca-core exports `period`, which `periods.period(...)` is not).
        globs = getattr(self, 'fn_globals', {})
        gf = self.e_safe(f)
        if isinstance(gf, tuple) and gf[0] == 'global':
            h = globs.get(gf[1])
            if inspect.isfunction(h):
                return self.inline(h, n)
            raise Residue(f'the helper {gf[1]}, which the module does not write')
        if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name):
            base = globs.get(f.value.id)
            h = getattr(base, fname, None) if inspect.ismodule(base) else None
        elif isinstance(f, ast.Name):
            h = globs.get(fname)
        else:
            h = None
        if of_package(h):
            return self.inline(h, n)
        if (getattr(h, '__module__', '') or '') in ENGINE_PERIODS:
            raise Residue(f'a period built in the formula ({fname}())')
        raise Residue(f'the call {fname}()')

    def period_expr(self, per):
        """The period a read asks about, written in the formula language over
        the period the rule is being worked out for: `period` itself, or a
        period a case names by its relation to it — two years before, the
        month before, the year it falls in (roadmap Phase 3b′, item 1,
        decision (a): a period is named by its text, and the relations
        between the periods a case needs are facts the scenario states).

        None when the read is for the formula's own period; False when the
        period is not one of the forms the twin writes."""
        if per is None or (isinstance(per, ast.Name) and per.id == 'period'):
            return None
        if isinstance(per, ast.Name) and isinstance(self.env.get(per.id), tuple):
            e = self.env[per.id]
            if e[0] == 'period':
                per = ast.Attribute(value=ast.Name(id='period'), attr=e[1])
            elif e[0] == 'periodexpr':
                return e[1]
        #  a chain of them, read from the inside out (period.last_year.last_year)
        if isinstance(per, ast.Attribute) and per.attr in PERIOD_WORDS:
            inner = self.period_expr(per.value) if not (isinstance(per.value, ast.Name) and per.value.id == 'period') else None
            if inner is False:
                return False
            base = inner or 'period'
            return PERIOD_WORDS[per.attr].format(base)
        if isinstance(per, ast.Call) and isinstance(per.func, ast.Attribute) and per.func.attr == 'offset' \
                and per.args and isinstance(per.func.value, ast.Call) and isinstance(per.func.value.func, ast.Name) \
                and per.func.value.func.id == 'Period':
            #  Period(('month', period.start, 1)).offset(-1): the month
            #  before; Period(('month', period.first_month.start, 3))
            #  .offset(-3): the last three months. (A year from the
            #  period's start is a year that need not begin in January,
            #  which the twin cannot name: residue.)
            pa = per.func.value.args
            tup = pa[0] if pa and isinstance(pa[0], ast.Tuple) and len(pa[0].elts) == 3 else None
            k = per.args[0]
            k = k.value if isinstance(k, ast.Constant) else -k.operand.value \
                if isinstance(k, ast.UnaryOp) and isinstance(k.op, ast.USub) and isinstance(k.operand, ast.Constant) else None
            if tup is not None and isinstance(k, int) and len(per.args) == 1:
                unit, start, size = (self.python_value(tup.elts[0]), ast.unparse(tup.elts[1]).replace(' ', ''),
                                     self.python_value(tup.elts[2]))
                if unit == 'month' and start in ('period.start', 'period.first_month.start'):
                    if size == 1 and k != 0:
                        return f'months_before(period, {-k})' if k < 0 else f'months_after(period, {k})'
                    if isinstance(size, int) and size > 1 and k == -size:
                        #  the `size` months before the period: a period of its
                        #  own, whose months a case states. Three of them have
                        #  a name of their own (*les trois mois avant*, the
                        #  RSA's salaries); any other count is written with
                        #  the count as a place (the family benefits read the
                        #  six months before, to see whether a child earns
                        #  enough to be independent).
                        return 'last_3_months_of(period)' if size == 3 else f'last_n_months_of(period, {size})'
                if unit == 'year' and start in ('period.start', 'period.first_month.start') and size == 1 and k < 0:
                    #  a rolling year: the twelve months from the month k years
                    #  before (`Period(('year', period.start, 1)).offset(-1)`),
                    #  a period of its own, `2021-03_12m`, as `_3m` is
                    return f'twelve_months_from(months_before(period, {-12 * k}))'
            return False
        if isinstance(per, ast.Call) and isinstance(per.func, ast.Attribute) and per.func.attr == 'offset' \
                and per.args:
            inner = self.period_expr(per.func.value) if not (isinstance(per.func.value, ast.Name)
                                                             and per.func.value.id == 'period') else None
            if inner is False:
                return False
            base = inner or 'period'
            k = per.args[0]
            if isinstance(k, ast.Constant) and k.value == 'first-of':
                #  the period that begins the one asked about: for a month or a
                #  year, the period itself
                self.approx.append('a period read "first-of": the period asked about')
                return inner
            months = k.value if isinstance(k, ast.Constant) and isinstance(k.value, int) else \
                -k.operand.value if isinstance(k, ast.UnaryOp) and isinstance(k.op, ast.USub) \
                and isinstance(k.operand, ast.Constant) else None
            unit = per.args[1].value if len(per.args) > 1 and isinstance(per.args[1], ast.Constant) else 'month'
            if months is None or unit not in ('month', 'year'):
                return False
            if months == 0:
                return inner
            m12 = re.fullmatch(r'twelve_months_from\((.*)\)', base)
            if m12:
                #  a rolling year moved by months or years: the twelve months
                #  from a month moved as much
                n = abs(months) * (12 if unit == 'year' else 1)
                return f"twelve_months_from({'months_before' if months < 0 else 'months_after'}({m12.group(1)}, {n}))"
            word = ('years_before' if months < 0 else 'years_after') if unit == 'year' else \
                ('months_before' if months < 0 else 'months_after')
            return f'{word}({base}, {abs(months)})'
        return False

    def period_value(self, node):
        """The period expression a node names, when it names one: `period`
        itself, or one near it."""
        looks = (isinstance(node, ast.Attribute) and node.attr in PERIOD_WORDS) or \
            (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == 'offset')
        if not looks:
            return None
        try:
            pe = self.period_expr(node)
        except Residue:
            return None
        return None if pe is False else (pe or 'period')

    def read(self, n):
        #  the name of the variable: written out, or a name the formula bound
        #  to one (a loop over the cases of a form, each with its own box)
        if n.args and isinstance(n.args[0], ast.Constant) and isinstance(n.args[0].value, str):
            v = n.args[0].value
        else:
            nm = self.python_value(n.args[0]) if n.args else None
            if not isinstance(nm, str):
                raise Residue('a variable read by a computed name')
            v = nm
        per = n.args[1] if len(n.args) > 1 else None
        if isinstance(per, ast.Name) and isinstance(self.env.get(per.id), tuple):
            e = self.env[per.id]
            if e[0] == 'period':
                per = ast.Attribute(value=ast.Name(id='period'), attr=e[1])
            elif e[0] == 'periodexpr' and e[1] == 'period':
                per = ast.Name(id='period')
            elif e[0] == 'periodexpr' and e[1] in ('first_month_of(period)', 'year_of(period)'):
                #  `january = period.first_month` then a read at `january`:
                #  the same thing as reading at `period.first_month`, which
                #  the twin takes as the case's one value (below). Without
                #  this the two spellings of one period part company, and a
                #  formula that names the period first asks the case for a
                #  value per period that no scenario of an upload can give —
                #  the country template's housing tax answered 0 that way.
                per = ast.Attribute(value=ast.Name(id='period'),
                                    attr='first_month' if e[1].startswith('first_month') else 'this_year')
        opts = read_options(n)
        if opts not in ([], ['DIVIDE'], ['ADD']):
            raise Residue(f'{v} read with options')
        if v not in self.system.variables:
            if not getattr(self.system, 'static', False):
                raise Residue(f'unknown variable {v}')
            self.system.unknown(v, self.var)        # read from a file not in the upload: an input
        if per is None or (isinstance(per, ast.Name) and per.id == 'period'):
            self.reads.add(v)
            if v in self.known_periods:
                #  another formula of the programme asks for this value at
                #  another period, so its template has a place for the
                #  period: every read names one
                self.by_period.add(v)
                self.periods.add('period')
                return ('atperiod', f'at_period({v}, period)')
            return v
        other = isinstance(per, ast.Attribute) and isinstance(per.value, ast.Name) and per.value.id == 'period' \
            and per.attr in ('first_month', 'this_year')
        if other and v in self.known_periods:
            #  a value whose template has a place for the period (another
            #  formula reads it at another period): read at the year, or the
            #  first month, by name. Read as the case's one value, it was a
            #  sentence one place short (the RSA's assiette_csg_plus_values,
            #  the twin's one writer error)
            pe = PERIOD_WORDS[per.attr].format('period')
            self.reads.add(v)
            self.by_period.add(v)
            self.periods.add(pe)
            return ('atperiod', f'at_period({v}, {pe})')
        if other:
            #  the twin holds one value per case: the value of the period's
            #  first month, or of its year, is the case's value (the oracle
            #  checks every answer, so an approximation that does not hold
            #  shows as a failing expectation, never as a silent difference)
            self.approx.append(f'{v} read for period.{per.attr}: the case\'s one value')
            self.reads.add(v)
            return v
        #  a value of another period: the variable gets a place for the period
        #  in its template, and the case states it for each period the
        #  calculation reads (roadmap Phase 3b′, item 1)
        pe = self.period_expr(per)
        if pe is False:
            raise Residue(f'{v} read for a period the twin cannot name')
        if pe is None or pe == 'period':
            #  the period asked about, written another way
            self.reads.add(v)
            if v in self.known_periods:
                self.by_period.add(v)
                self.periods.add('period')
                return ('atperiod', f'at_period({v}, period)')
            return v
        if not self.states(v):
            #  the programme works the value out for its own period, and its
            #  rule cannot be worked out for another one (its parameters are
            #  those of a date): for another period the case gives the value,
            #  and the oracle — the package's engine, or France's trace —
            #  says what it is (roadmap Phase 3b′, item 1)
            self.approx.append(f'{v} of another period: the value the case states, which the engine gives, '
                               f'rather than the twin working it out again for that period')
            self.given_periods.add(v)
        if self.system.variables.get(v) is not None and (self.system.variables[v].formulas
                                                         or getattr(self.system.variables[v], 'adds', None)) \
                and not (self.within and not inside(self.system.variables[v], self.within)):
            self.derived_periods.add(v)
        self.reads.add(v)
        self.by_period.add(v)
        self.periods.add(pe)
        if opts == ['ADD']:
            #  a year as the sum of its months (OpenFisca's [ADD])
            self.periods.add(f'months_of({pe})')
            return ('atperiod', f'sum_over_months({v}, {pe})')
        if opts == ['DIVIDE']:
            self.approx.append(f'{v} of {pe} divided among the months of that period')
            return ('atperiod', f'(at_period({v}, {pe}) / 12)')
        return ('atperiod', f'at_period({v}, {pe})')

    def read_name(self, n):
        """The name of the variable a read asks for, where only the rule's own
        period makes sense: a read for another period there is residue."""
        v = self.read(n)
        if isinstance(v, tuple):
            name = n.args[0].value if n.args and isinstance(n.args[0], ast.Constant) else '?'
            raise Residue(f'{name} of another period, read through a group or its members')
        return v

    def read_period(self, n):
        """(name, the text that reads it) for a read through a group, a role
        or the members: the name alone, or the name with the period it asks
        about (Phase 3b′, item 1)."""
        v = self.read(n)
        if isinstance(v, tuple):
            name = n.args[0].value if n.args and isinstance(n.args[0], ast.Constant) else '?'
            #  (or a year as the sum of its months, or a year's value divided
            #  among its months: OpenFisca's ADD and DIVIDE)
            m = re.fullmatch(r'(?:at_period|sum_over_months)\(([a-z_0-9]+), (.*)\)', v[1]) or \
                re.fullmatch(r'\(at_period\(([a-z_0-9]+), (.*)\) / 12\)', v[1])
            if not m:
                raise Residue(f'{name} of another period, read through a group or its members')
            return name, v[1]
        return v, v

    def states(self, v):
        """Whether the twin can give the value of v for a period other than
        the one it is working out: a value the case states (an input, or a
        variable outside the programme, whose value at each period the
        scenario states and the oracle gives), or one the programme works out
        from such values alone (`age`, from the date of birth: its rule gets
        a place for the period too)."""
        var = self.system.variables.get(v)
        if var is None:
            return True
        if self.within and not inside(var, self.within):
            return True            # outside the programme: a fact the case states
        if not (var.formulas or getattr(var, 'adds', None) or getattr(var, 'subtracts', None)):
            return True
        return self.period_safe(v, 2)

    def period_safe(self, v, depth):
        """Whether the rule of v can be worked out for a period other than
        the calculation's own: one formula, no parameter (whose value would
        be that of another date), no read of yet another period, and every
        variable it reads a value the case states or itself period-safe
        (roadmap Phase 3b′, item 1)."""
        var = self.system.variables.get(v)
        if var is None or depth <= 0:
            return False
        if getattr(var, 'adds', None) or getattr(var, 'subtracts', None) or getattr(var, 'end', None):
            return False
        fs = var.formulas or {}
        if len(fs) != 1:
            return False
        try:
            src = source_of(list(fs.values())[0])
        except Exception:
            return False
        if 'parameters(' in src or re.search(r'period\.(offset|last_year|n_2|last_month|last_3_months)', src):
            return False
        #  the names its rule actually reads, not the ones its Python mentions
        #  (openfisca-france's `age` falls back to the date of birth, and the
        #  branch that reads the engine's cache is not read at all)
        guard = getattr(self, '_safe_seen', None)
        if guard is None:
            guard = self._safe_seen = set()
        if v in guard:
            return False
        guard.add(v)
        try:
            tr = Translator(self.system, self.params, var)
            tr.within, tr.out_vars = self.within, {}
            try:
                text, _ = tr.formula(list(fs.values())[0])
            except Residue:
                return False
            if 'at_period(' in text or 'sum_over_months(' in text:
                return False
            for n in set(re.findall(r'[A-Za-z_][A-Za-z0-9_]*', text)) & set(self.system.variables):
                w = self.system.variables[n]
                if self.within and not inside(w, self.within):
                    continue
                if not (w.formulas or getattr(w, 'adds', None)):
                    continue
                if not self.period_safe(n, depth - 1):
                    return False
            return True
        finally:
            guard.discard(v)

    def member_read(self, name, n):
        """Each member's value of a variable read for the formula's own
        period: scaled as a direct read is (a year's sum of a monthly salary,
        `options=[ADD]`, is twelve of the months the twin states; the trade-
        union dues' ceiling read one month's salary)."""
        t = self.scaled(name, n) if read_options(n) else name    # (PolicyEngine's flows: sum() scales them)
        if t != name:
            return ('mexpr', t)
        return ('members', name)

    def scaled(self, v, n):
        """A number read for the formula's own period from a variable of
        another (period_factor)."""
        if isinstance(v, tuple) and v[0] == 'atperiod':
            return v[1]                 # the read carries the period it asks about
        per = n.args[1] if len(n.args) > 1 else None
        if not (isinstance(per, ast.Name) and per.id == 'period'):
            return v
        opts = read_options(n)
        if opts:                               # [DIVIDE] a year among its months, [ADD] a year's months
            target = self.system.variables.get(v)
            mine, theirs = str(self.var.definition_period).lower(), str(getattr(target, 'definition_period', '')).lower()
            f = ' / 12' if opts == ['DIVIDE'] and mine.endswith('month') and theirs.endswith('year') else \
                ' * 12' if opts == ['ADD'] and mine.endswith('year') and theirs.endswith('month') else ''
            return f'({v}{f})' if f else v
        f = period_factor(self.system, self.var, v)
        return f'({v}{f})' if f else v

    def block(self, stmts):
        """The value a block of statements returns: an AST node, or formula
        text when an `if` decided between returns."""
        for k, st in enumerate(stmts):
            self.epoch += 1
            if isinstance(st, ast.AnnAssign) and st.value is not None:
                #  `regions_list: list[str] = ...`: the type note adds nothing
                st = ast.Assign(targets=[st.target], value=st.value, lineno=st.lineno)
                stmts[k] = st
            if isinstance(st, ast.Assign) and len(st.targets) == 1 and isinstance(st.targets[0], ast.Tuple) \
                    and all(isinstance(x, ast.Name) for x in st.targets[0].elts):
                #  a, b = helper(...): each name the helper's value at its
                #  place; a, b = <a pair the formula writes out>: each element
                if isinstance(st.value, (ast.Tuple, ast.List)) and len(st.value.elts) == len(st.targets[0].elts):
                    for x, node in zip(st.targets[0].elts, st.value.elts):
                        if x.id != '_':
                            self.block([ast.Assign(targets=[ast.Name(id=x.id, ctx=ast.Store())],
                                                   value=node, lineno=st.lineno)])
                    continue
                t = self.e(st.value)
                if not (isinstance(t, tuple) and t[0] == 'tuple' and len(t[1]) == len(st.targets[0].elts)):
                    raise Residue('an assignment of several names from something that is not a helper\'s tuple')
                for x, v in zip(st.targets[0].elts, t[1]):
                    if x.id != '_':
                        self.env[x.id] = v
                continue
            if isinstance(st, ast.Assign) and len(st.targets) > 1 and all(isinstance(x, ast.Name) for x in st.targets):
                #  p = p = parameters(...): each name the one value
                for x in st.targets:
                    self.block([ast.Assign(targets=[x], value=st.value, lineno=st.lineno)])
                continue
            if isinstance(st, ast.Assign) and len(st.targets) == 1 and isinstance(st.targets[0], ast.Name) \
                    and self.group_of(st.value):
                #  spm_unit = person.spm_unit, household = benunit.household:
                #  a name for the group, read in what follows as written out
                self.aliases[st.targets[0].id] = st.value
                stmts[k + 1:] = [subst(x, {st.targets[0].id: st.value}) for x in stmts[k + 1:]]
                continue
            if isinstance(st, ast.Assign) and len(st.targets) == 1 and isinstance(st.targets[0], ast.Name) \
                    and isinstance(st.value, ast.Attribute) and st.value.attr == 'members' \
                    and isinstance(st.value.value, ast.Name) and st.value.value.id == self.entity_arg:
                #  person = benunit.members: person("x", period) is each member's x
                self.env[st.targets[0].id] = ('memberfn',)
                continue
            if isinstance(st, ast.Assign) and len(st.targets) == 1 and isinstance(st.targets[0], ast.Name) \
                    and self.period_value(st.value) is not None:
                #  a name for a period near the one the formula is about
                #  (`janvier = period.first_month`, `decembre =
                #  janvier.offset(11, 'month')`): the period it names
                self.env[st.targets[0].id] = ('periodexpr', self.period_value(st.value))
                continue
            if isinstance(st, ast.Assign) and len(st.targets) == 1 and isinstance(st.targets[0], ast.Name) \
                    and isinstance(st.value, ast.Attribute) and st.value.attr == 'possible_values' \
                    and isinstance(st.value.value, ast.Name):
                #  TypesX = x.possible_values: the name of the enumeration of
                #  the variable x, so a loop over its members can be unrolled
                inner = self.env.get(st.value.value.id)
                self.enum_of = dict(getattr(self, 'enum_of', {}))
                self.enum_of[st.targets[0].id] = inner if isinstance(inner, str) else st.value.value.id
                self.env[st.targets[0].id] = ('enum', 'possible_values')
                continue
            if isinstance(st, ast.FunctionDef):
                #  a function defined inside the formula: inlined where it is
                #  called, as the package's helpers are (roadmap §8, Phase 3b
                #  work left, item 4)
                self.env[st.name] = ('localfn', st)
                continue
            if isinstance(st, ast.Expr) and isinstance(st.value, ast.Call) and isinstance(st.value.func, ast.Attribute) \
                    and st.value.func.attr == 'append' and isinstance(st.value.func.value, ast.Name) \
                    and isinstance(self.env.get(st.value.func.value.id), tuple) and self.env[st.value.func.value.id][0] == 'list' \
                    and len(st.value.args) == 1 and isinstance(st.value.args[0], ast.Constant):
                #  names.append("x") on a list written in the program
                lst = self.env[st.value.func.value.id]
                self.env[st.value.func.value.id] = ('list', list(lst[1]) + [st.value.args[0].value])
                continue
            if isinstance(st, ast.For) and not st.orelse and self.dict_loop(st):
                continue
            if isinstance(st, ast.For) and not st.orelse and self.expr_loop(st):
                continue
            if isinstance(st, ast.For) and not st.orelse:
                #  a loop over a dictionary or a list written in the module
                #  (AK_COUNTY_TO_REGION.items()): one copy of its body per entry
                #  (roadmap §8, Phase 3b work left, item 3(a))
                items = self.constant_items(st.iter)
                if items is None:
                    raise Residue('a loop over something that is not written in the program')
                for it in items:
                    names = self.bind_target(st.target, it)
                    if names is None:
                        raise Residue('a loop whose variables do not match its items')
                    body = [subst(x, names) for x in st.body]
                    try:
                        r = self.block(body)
                    except Skip:
                        continue           # the body's own `continue`
                    if r is not None:
                        raise Residue('a return inside a loop')
                continue
            if isinstance(st, ast.If) and not st.orelse and self.logging_only(st.body):
                #  `if (...).any(): log.error(...)`: the package warning about
                #  a declaration it finds inconsistent, not a rule of the law
                self.notes.append('a message the package logs, dropped: ' + ast.unparse(st.test)[:120])
                continue
            if isinstance(st, ast.If) and not st.orelse and self.any_guard(st):
                #  if mask.any(): ... — NumPy's shortcut when no row matches;
                #  every assignment of the body is a where on the mask, so the
                #  body gives the same values when run unconditionally
                r = self.block(list(st.body))
                if r is not None:
                    raise Residue('a return inside an if on .any()')
                continue
            ys = self.year_start_if(st) if isinstance(st, ast.If) else None
            if ys:
                #  if month >= 10: d = f"{year}-10-01" else: d = f"{year - 1}-10-01":
                #  the start of the year (from 1 October) the period falls in
                self.env[ys[0]] = ('year_start', ys[1])
                continue
            truth = self.static_truth(st.test) if isinstance(st, ast.If) else None
            if truth is not None:
                #  an if on a parameter whose value does not change within the
                #  twin's years: the branch it takes (roadmap §8, Phase 3b work
                #  left, item 5)
                taken = st.body if truth else st.orelse
                r = self.block(list(taken) + list(stmts[k + 1:]))
                return r
            if isinstance(st, ast.Assign) and len(st.targets) == 1 and isinstance(st.targets[0], ast.Name):
                try:
                    t = self.e(st.value)
                except Residue:
                    #  a name for a dictionary or a list the module writes
                    #  (openfisca-france's lists of contributions by category
                    #  of employee): kept as the Python value it is, for the
                    #  `in` tests and lookups that read it
                    pv = self.python_value(st.value)
                    if pv is None or not isinstance(pv, (dict, list, tuple)):
                        raise
                    self.env[st.targets[0].id] = ('pyvalue', pv)
                    continue
                if isinstance(t, tuple) and t[0] == 'exprs':
                    self.env[st.targets[0].id] = t
                    continue
                if isinstance(t, str) and self.boolmul(st.value)[0] == 'bool':
                    self.boolnames.add(st.targets[0].id)
                if self.is_calc(st.value):
                    self.calcnames.add(st.targets[0].id)
                elif st.targets[0].id in self.calcnames:
                    self.calcnames.discard(st.targets[0].id)
                self.env[st.targets[0].id] = self.stage(st.targets[0].id, t)
            elif isinstance(st, ast.Return):
                return st.value
            elif isinstance(st, ast.If) and st.body and isinstance(st.body[-1], ast.Return):
                cond = self.expr(st.test)
                saved = dict(self.env)
                then = self.guarded(st.body)
                then = self.expr(then) if isinstance(then, ast.AST) else then
                self.env = dict(saved)
                rest = self.block(st.orelse + stmts[k + 1:]) if (st.orelse or stmts[k + 1:]) else None
                if rest is None:
                    #  the last statement of a helper the package only ever
                    #  calls where the condition holds (compute_cotisation_
                    #  annuelle, called in December): the other branch cannot
                    #  be reached, and is written as nothing owed
                    self.notes.append('a formula branch the package cannot reach, written as 0: '
                                      + ast.unparse(st.test))
                    rest = '0'
                rest = self.expr(rest) if isinstance(rest, ast.AST) else rest
                return f'(if {cond}: {then} else: {rest})'
            elif isinstance(st, ast.If):
                cond = self.expr(st.test)
                saved = dict(self.env)
                for x in st.body:
                    self.guarded([x])
                then_env = dict(self.env)
                self.env = dict(saved)
                for x in st.orelse:
                    self.guarded([x])
                else_env = dict(self.env)
                self.env = dict(saved)
                for name in set(then_env) | set(else_env):
                    a, b = then_env.get(name), else_env.get(name)
                    if a == b:
                        if a is not None:
                            self.env[name] = a
                        continue
                    if (a is None or b is None) and name not in saved:
                        #  a name the if sets on one branch only. Used after
                        #  the if, it is that branch's value where the branch
                        #  is taken, and nothing where it is not: the dates
                        #  an if/elif chain over the calculation date does
                        #  not cover (openfisca-france's allegement général
                        #  before 2003 and after 2025). The twin writes 0
                        #  there, which the formula's own `if seuil <= 1:
                        #  return 0` asks for, and says so.
                        one = a if a is not None else b
                        t1 = self.expr_of(one)
                        if not isinstance(t1, str):
                            continue
                        zero = 'false' if name in self.boolnames else '0'
                        self.notes.append(f'{name} is set only where ' + ast.unparse(st.test)
                                          + (' holds' if a is not None else ' does not hold')
                                          + ': 0 elsewhere')
                        c = cond if a is not None else f'(not {cond})'
                        self.env[name] = self.stage(name, f'(if {c}: {t1} else: {zero})')
                        continue
                    if all(isinstance(x, tuple) and x[0] in ('param', 'pmatch') for x in (a, b)) \
                            and not all(x[0] == 'param' and hasattr(self.params.node(x[1]), 'values_list') for x in (a, b)):
                        #  a parameter node chosen by the if (`ppa =
                        #  parameters(<2016>).…ppa` before 2016, else at the
                        #  calculation date), its children read after it
                        self.env[name] = ('pmatch', ('cond', cond), {'then': a, 'else': b})
                        continue
                    a, b = (self.expr_of(x) for x in (a, b))
                    if not isinstance(a, str) or not isinstance(b, str):
                        raise Residue('an if that sets a value on one branch only')
                    self.env[name] = self.stage(name, merge_if(cond, a, b))
            elif isinstance(st, ast.Expr) and isinstance(st.value, ast.Call) \
                    and isinstance(st.value.func, ast.Attribute) \
                    and st.value.func.attr in ('add_bracket', 'multiply_thresholds', 'multiply_rates') \
                    and isinstance(st.value.func.value, ast.Name) \
                    and isinstance(self.env.get(st.value.func.value.id), tuple) \
                    and self.env[st.value.func.value.id][0] == 'scale':
                #  a bracket added to a scale the formula builds, and the
                #  thresholds multiplied by the social-security ceiling
                nm = st.value.func.value.id
                _, brackets, factor, amounts = self.env[nm]
                c = st.value
                if c.func.attr == 'add_bracket':
                    if len(c.args) != 2:
                        raise Residue('add_bracket with something other than a threshold and a rate')
                    brackets = brackets + [(self.expr(c.args[0]), self.expr(c.args[1]))]
                elif c.func.attr == 'multiply_thresholds':
                    if factor is not None:
                        raise Residue('a scale whose thresholds are multiplied twice')
                    factor = self.expr(c.args[0])
                else:
                    brackets = [(t, f'({r} * {self.expr(c.args[0])})') for t, r in brackets]
                self.env[nm] = ('scale', brackets, factor, amounts)
            elif isinstance(st, ast.Continue):
                raise Skip()
            elif isinstance(st, ast.Pass):
                continue
            elif isinstance(st, ast.Try):
                #  the try's own statements; where reading one of them fails
                #  because the package looked for a parameter that is not
                #  there, the handler's statements instead (openfisca-france's
                #  own fix for a category that has no scale: Phase 3b' item 4)
                saved = dict(self.env)
                try:
                    r = self.block(list(st.body))
                except Skip:
                    raise
                except Residue:
                    self.env = saved
                    handlers = [h for h in st.handlers]
                    if not handlers:
                        raise
                    self.notes.append('a parameter the package looks for and does not find: '
                                      'the formula\'s own handler read instead')
                    r = self.block([x for x in handlers[0].body if not isinstance(x, ast.Raise)])
                if st.finalbody:
                    r2 = self.block(list(st.finalbody))
                    r = r if r is not None else r2
                if r is not None:
                    return r
            elif isinstance(st, ast.Expr) and isinstance(st.value, ast.Yield):
                #  a generator the formula adds up (sum(iter_cotisations())):
                #  each yield one term
                self.yields.append(self.e(st.value.value))
            elif isinstance(st, ast.Expr) and isinstance(st.value, ast.Call) \
                    and isinstance(st.value.func, ast.Name) and st.value.func.id in ('KeyError', 'NameError', 'ValueError'):
                #  `KeyError(...)` written without `raise`: a statement with no
                #  effect in the package (it means the entry is missing)
                continue
            elif isinstance(st, ast.Assert):
                #  `assert x is not None`, `assert x`: the package checking
                #  that its own helper was called properly — not law, and
                #  dropped with a note. An assertion about the values a
                #  formula reads becomes an integrity constraint of the twin
                #  (roadmap Phase 3b′, item 4).
                t = st.test
                arg_check = isinstance(t, ast.Compare) and len(t.ops) == 1 and isinstance(t.ops[0], ast.IsNot) \
                    and isinstance(t.comparators[0], ast.Constant) and t.comparators[0].value is None
                #  `assert period.unit == 'month'`: the helper checking the
                #  period it was called with — the twin's rules are read at
                #  the period they are about, so there is nothing to check
                period_check = isinstance(t, ast.Compare) and isinstance(t.left, ast.Attribute) \
                    and isinstance(t.left.value, ast.Name) and t.left.value.id == 'period' \
                    and all(isinstance(c, ast.Constant) for c in t.comparators)
                if arg_check or period_check or isinstance(t, ast.Name) or isinstance(t, ast.Attribute):
                    self.notes.append('an assert on the package\'s own argument, dropped: '
                                      + ast.unparse(t))
                    continue
                try:
                    self.musts.append(self.expr(t))
                except Residue as r:
                    raise Residue(f'an assert this translator does not read ({r})')
                self.notes.append('the formula\'s assert kept as an integrity constraint: ' + ast.unparse(t))
            elif isinstance(st, ast.Expr) and isinstance(st.value, ast.Call) and isinstance(st.value.func, ast.Name) \
                    and not st.value.args and not st.value.keywords \
                    and inspect.isfunction(getattr(self, 'fn_globals', {}).get(st.value.func.id)):
                #  `preload_zone_apl()`: a function of the module called for
                #  its effect, loading a table into the module once; the
                #  reader reads the module after the package has loaded it
                #  OpenFisca loads a file of variables as a module of its own,
                #  so the package's own call of the loader filled another
                #  copy of the table: the reader calls it in this one
                try:
                    self.fn_globals[st.value.func.id]()
                except Exception as x:
                    raise Residue(f'{st.value.func.id}() failed when the reader called it ({type(x).__name__})')
                self.notes.append(f'{st.value.func.id}() dropped: the table it loads is read from the module')
                continue
            elif isinstance(st, ast.AugAssign) and isinstance(st.target, ast.Name) and st.target.id in self.env:
                #  x &= y, x += y: x = x & y, x = x + y
                self.block([ast.Assign(targets=[ast.Name(id=st.target.id, ctx=ast.Store())],
                                       value=ast.BinOp(left=ast.Name(id=st.target.id, ctx=ast.Load()), op=st.op, right=st.value),
                                       lineno=st.lineno)])
            else:
                raise Residue(type(st).__name__ + ' statement')
        return None

    def logging_only(self, body):
        """A block that only writes a message (`log.error(...)`, `print(...)`):
        nothing of the law happens in it."""
        if not body:
            return False
        for st in body:
            if not (isinstance(st, ast.Expr) and isinstance(st.value, ast.Call)):
                return False
            f = st.value.func
            name = f.attr if isinstance(f, ast.Attribute) else getattr(f, 'id', None)
            base = getattr(f, 'value', None)
            if name not in ('error', 'warning', 'info', 'debug', 'print', 'warn') \
                    and not (isinstance(base, ast.Name) and base.id in ('log', 'logging', 'logger')):
                return False
        return True

    def guarded(self, stmts):
        """A block under a condition the twin cannot decide: a `continue`
        there would end the whole copy of a loop's body, which is not what
        the Python means, so it is residue with its reason."""
        try:
            return self.block(stmts)
        except Skip:
            raise Residue('a continue under a condition the twin cannot decide')

    def constant_items(self, it):
        """The entries of `D.items()`, `D`, `L` for a dictionary or list of
        constants the module defines, as Python values; else None."""
        call_items = isinstance(it, ast.Call) and isinstance(it.func, ast.Attribute) and it.func.attr == 'items' and not it.args
        node = it.func.value if call_items else it
        #  the members of an enumeration, by their names (a loop over the
        #  categories of employee: roadmap Phase 3b′, item 4)
        if not call_items:
            e = self.e_safe(node)
            if isinstance(e, tuple) and e[0] == 'enum':
                members = self.enum_members(node)
                if members:
                    return members
        if not isinstance(node, ast.Name):
            e = self.e_safe(node)
            if isinstance(e, tuple) and e[0] == 'list':
                return list(e[1])
            pv = self.python_value(node)
            if isinstance(pv, (list, tuple)):
                return list(pv)
            v = self.python_value(node)
            return list(v) if isinstance(v, (list, tuple)) and all(isinstance(x, (str, int, float)) for x in v) else None
        if isinstance(node, ast.Name) and not call_items:
            e = self.e_safe(node)
            if isinstance(e, tuple) and e[0] == 'list':
                return list(e[1])
        v = getattr(self, 'fn_globals', {}).get(node.id)
        if isinstance(v, dict) and call_items and all(isinstance(k, (str, int, float)) for k in v) \
                and all(isinstance(x, (str, int, float)) for x in v.values()):
            return list(v.items())
        if isinstance(v, (list, tuple)) and not call_items and all(isinstance(x, (str, int, float)) for x in v):
            return list(v)
        return None

    def enum_members(self, node):
        """The names of the members of the enumeration `x.possible_values`
        names, where x is a variable the formula read."""
        if not (isinstance(node, ast.Name) and isinstance(self.env.get(node.id), tuple)):
            #  the name was bound to ('enum', …) by `T = x.possible_values`
            pass
        src = getattr(self, 'enum_of', {}).get(node.id if isinstance(node, ast.Name) else None)
        if src is None:
            return None
        var = self.system.variables.get(src)
        pv = getattr(var, 'possible_values', None) if var is not None else None
        try:
            return [m.name for m in pv]
        except TypeError:
            return None

    def member_level(self, node):
        """(name, yes-or-no) of a per-member value read through the person's
        group (a member's variable, or a helper of each member), else None."""
        try:
            t = self.e(node)
        except Residue:
            return None
        if not (isinstance(t, tuple) and t[0] in ('members', 'mexpr', 'mbool', 'mpred')):
            return None
        if t[0] == 'mpred':
            return t[1], True
        if t[0] == 'mbool':
            return self.helper(t[1], 'Judgment'), True
        if t[0] == 'members':
            var = self.system.variables.get(t[1])
            return t[1], bool(var is not None and var.value_type is bool)
        return self.helper(t[1], 'Money'), False

    def entity_key(self, cls):
        """The key of the entity a formula names by its class (`FoyerFiscal`
        is `foyer_fiscal`), when the package has one of that name."""
        key = re.sub(r'(?<!^)(?=[A-Z])', '_', cls).lower()
        if key in ENTITY_ARGS:
            return key
        for e in getattr(self.system, 'entities', []) or []:
            if e.key == key:
                return key
        return None

    def roles_of(self, grp):
        """The roles of an entity, and the subroles of each (a famille has
        parents and children, and the parents are the demandeur and the
        conjoint): name -> the plural a case's role list is written under."""
        out = {}
        for e in getattr(self.system, 'entities', []) or []:
            if e.key != grp:
                continue
            for r in getattr(e, 'roles', []) or []:
                out[r.key] = getattr(r, 'plural', None) or r.key + 's'
                for i, sub in enumerate(getattr(r, 'subroles', None) or []):
                    #  a subrole is written in the case under its parent's
                    #  plural, at the place the subrole has: the first of a
                    #  famille's parents is its demandeur, the second its
                    #  conjoint
                    out[getattr(sub, 'key', str(sub))] = getattr(r, 'plural', None) or r.key + 's'
                    SUBROLE_PLACE[(grp, getattr(sub, 'key', str(sub)))] = i
        return out

    def role(self, node, grp=None):
        """The yes-or-no input of a person that says it has the role node
        names in a group (`Household.ADULT`: *a person is adult in
        household*; `Famille.DEMANDEUR`: *a person is demandeur in famille*),
        stated by each case from its role lists."""
        if isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name) and node.value.id[:1].isupper():
            key = node.attr.lower()
            grp = grp or self.entity_key(node.value.id) or self.var.entity.key
        elif isinstance(node, str):
            key, grp = node, grp or self.var.entity.key
        else:
            raise Residue('a role the formula works out')
        if hasattr(self.system, 'entities'):
            roles = self.roles_of(grp)
        else:
            #  an upload read without the package: OpenFisca's way of naming roles
            roles = {key: 'children' if key == 'child' else key + 's'}
        if key not in roles:
            raise Residue(f'the role {key} of {grp}')
        name = f'is_{key}_in_{grp}'
        ROLES[name] = (grp, key, roles[key])
        return name

    def through_role(self, grp, rolename, value, isbool, other=None):
        """A group's reading of a value through the member who holds a role
        (`famille.demandeur.menage('residence_dom', period)`): the value of
        the one member of the group who holds the role — nothing for the
        others, so the group's own value is the sum over its members
        (roadmap Phase 3b′, item 2)."""
        own = f'member_of_{grp}'
        self.relations.add(own)
        read = value
        if other:
            rel = f'member_of_{other}'
            self.relations.add(rel)
            read = f'{rel}.{value}'
        if isbool:
            h = self.helper(f'({rolename} and {read})', 'Judgment')
            return f'(count_where({own}, {h}) > 0)'
        h = self.helper(f'(if {rolename}: {read} else: 0)', 'Money')
        return f'sum({own}.{h})'

    def is_members(self, node):
        """`person`, after `person = benunit.members`, or `menage.members`
        written out: the members of the formula's own group."""
        if isinstance(node, ast.Name) and self.env.get(node.id) == ('memberfn',):
            return True
        return isinstance(node, ast.Attribute) and node.attr == 'members' \
            and isinstance(node.value, ast.Name) and node.value.id == self.entity_arg

    def group_of(self, node):
        """`person.spm_unit`, `benunit.household`: the group of the formula's
        entity that the node names."""
        return isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name) \
            and node.value.id == self.entity_arg and node.attr in ENTITY_ARGS

    def expr_of(self, x):
        """A value of the environment as formula text, when it is one."""
        if isinstance(x, tuple) and x[0] == 'param':
            name = self.params.scalar(x[1])
            return f'({name} == 1)' if name in self.params.bools else name
        return x

    def stage(self, name, t, force=False):
        """A long value bound to a name the formula assigns again (a lookup
        through a dictionary, a value built in steps) is a step of its own:
        a rule of the variable's entity, which the next steps read by name
        rather than copying it (roadmap §8, Phase 3b work left: one name per
        assignment)."""
        if not isinstance(t, str) or not (force or len(t) > 1200):
            return t
        #  numbered across the variable's dated versions, and the same step
        #  the same name: each version counted its own from 1, so a later
        #  version's steps replaced an earlier one's (the 2023 and 2024
        #  Duflot-Pinel-Denormandie formulas both ended on step 24, and the
        #  2024 reduction read the 2023 one's investments)
        key = (self.var.name, 'step', t)
        if key not in HELPERS:
            HELPERS[key] = f'{self.var.name}_{WORDS["step"]}_{len([h for h in HELPERS if h[:2] == (self.var.name, "step")]) + 1}'
        hname = HELPERS[key]
        dtype = 'Judgment' if name in self.boolnames else 'Text' if re.search(r"(=>|:) '", t) else 'Money'
        self.helpers[hname] = {'name': hname, 'kind': 'derived', 'entity': camel(self.var.entity.key), 'dtype': dtype,
                               'source': WORDS['step_src'].format(v=self.var.name, name=name),
                               'versions': [{'effective_from': '1900-01-01', 'formula': t}]}
        return hname

    def dict_loop(self, st):
        """`for k, v in D.items(): x = where(m & (e == k), v, x)`, D a
        dictionary of codes the module writes: x looked up in D where m
        holds, as a step of its own (roadmap §8, Phase 3b work left, item 7).
        True when the loop was read so."""
        items = self.constant_items(st.iter)
        if not items or not isinstance(st.target, ast.Tuple) or len(st.target.elts) != 2 \
                or not all(isinstance(x, ast.Name) for x in st.target.elts) or len(st.body) != 1:
            return False
        kname, vname = (x.id for x in st.target.elts)
        a = st.body[0]
        if not (isinstance(a, ast.Assign) and len(a.targets) == 1 and isinstance(a.targets[0], ast.Name)
                and isinstance(a.value, ast.Call) and isinstance(a.value.func, ast.Name) and a.value.func.id == 'where'
                and len(a.value.args) == 3 and isinstance(a.value.args[1], ast.Name) and a.value.args[1].id == vname
                and isinstance(a.value.args[2], ast.Name) and a.value.args[2].id == a.targets[0].id):
            return False
        x = a.targets[0].id
        c = a.value.args[0]
        is_key = lambda q: isinstance(q, ast.Compare) and len(q.ops) == 1 and isinstance(q.ops[0], ast.Eq) \
            and isinstance(q.comparators[0], ast.Name) and q.comparators[0].id == kname
        if is_key(c):
            mask, key = None, c.left
        elif isinstance(c, ast.BinOp) and isinstance(c.op, ast.BitAnd) and is_key(c.right):
            mask, key = c.left, c.right.left
        elif isinstance(c, ast.BinOp) and isinstance(c.op, ast.BitAnd) and is_key(c.left):
            mask, key = c.right, c.left.left
        else:
            return False
        if x not in self.env or not all(isinstance(k, str) and isinstance(v, str) for k, v in items):
            return False
        before = self.expr_of(self.env[x])
        e = self.expr(key)
        look = '(match ' + e + ':\n' + '\n'.join(f"    '{k}' => '{v}'" for k, v in items) + f'\n    _ => {before})'
        if mask is not None:
            look = f'(if {self.expr(mask)}: {look} else: {before})'
        self.env[x] = self.stage(x, look, force=len(items) > 3)
        return True

    def names_of(self, node):
        """A list of names the program writes, or a parameter that is one."""
        t = self.e(node)
        if isinstance(t, tuple) and t[0] == 'list':
            return list(t[1])
        if isinstance(t, tuple) and t[0] == 'param':
            return self.param_list(t[1])
        raise Residue('a list that is not written in the program')

    def param_list(self, path):
        """A parameter that is a list of names: its value in the twin's years
        (the latest of them, noted, when it changed within them)."""
        node = self.params.node(path)
        if not hasattr(node, 'values_list'):
            raise Residue(f'parameter {".".join(path)} is not a list')
        vals = sorted((v for v in node.values_list if v.value is not None), key=lambda v: v.instant_str)
        if self.params.window:
            lo, hi = self.params.window
            vals = [v for i, v in enumerate(vals)
                    if v.instant_str <= hi and (i + 1 == len(vals) or vals[i + 1].instant_str > lo)] or vals[-1:]
        if not vals or not all(isinstance(v.value, list) for v in vals):
            raise Residue(f'parameter {".".join(path)} is not a list')
        if len({tuple(v.value) for v in vals}) > 1:
            self.approx.append(f'the list {".".join(path)} changed within the twin\'s years: the latest is read')
        self.params.files.add(getattr(node, 'file_path', None))
        return list(vals[-1].value)

    def constant_dict(self, node):
        """A dictionary written in the program, from codes to codes (an
        enumeration's member read as its name), worked out from the module's
        own names; None when it is anything else."""
        try:
            d = eval(compile(ast.Expression(body=node), '<dictionary>', 'eval'), dict(getattr(self, 'fn_globals', {})))
        except Exception:
            return None
        out = {}
        for k, v in d.items():
            k = getattr(k, 'name', k)
            v = getattr(v, 'name', v)
            if not isinstance(k, str) or not isinstance(v, str):
                return None
            out[k] = v
        return out

    def expr_loop(self, st):
        """A loop over a list of values the formula writes out (a list of
        pairs of expenses, one pair per year): one copy of the body per
        element, the loop's names bound to the element's own expressions.
        True when the loop was read so (roadmap Phase 3b′, item 5)."""
        elts = None
        if isinstance(st.iter, (ast.List, ast.Tuple)):
            elts = list(st.iter.elts)
        else:
            t = self.e_safe(st.iter)
            if isinstance(t, tuple) and t[0] == 'exprs':
                elts = list(t[1])
        if elts is None or not elts:
            return False
        for it in elts:
            if isinstance(st.target, ast.Name):
                names = {st.target.id: it}
            elif isinstance(st.target, ast.Tuple) and isinstance(it, (ast.Tuple, ast.List)) \
                    and len(st.target.elts) == len(it.elts) and all(isinstance(x, ast.Name) for x in st.target.elts):
                names = {x.id: v for x, v in zip(st.target.elts, it.elts)}
            else:
                return False
            body = [subst(x, names) for x in st.body]
            try:
                r = self.block(body)
            except Skip:
                continue
            if r is not None:
                raise Residue('a return inside a loop')
        return True

    def bind_target(self, target, item):
        if isinstance(target, ast.Name):
            return {target.id: const_node(item)}
        if isinstance(target, ast.Tuple) and isinstance(item, tuple) and len(target.elts) == len(item) \
                and all(isinstance(x, ast.Name) for x in target.elts):
            return {x.id: ast.Constant(v) for x, v in zip(target.elts, item)}
        return None

    def any_guard(self, st):
        """`if m.any():` whose body only assigns `where(...)` values that test
        the same m (or an `and` with it)."""
        t = st.test
        if not (isinstance(t, ast.Call) and isinstance(t.func, ast.Attribute) and t.func.attr == 'any'
                and not t.args and isinstance(t.func.value, ast.Name)):
            return False
        m = t.func.value.id
        ms = {m}
        def masked(node):
            if isinstance(node, ast.Name):
                return node.id in ms
            if isinstance(node, ast.BinOp) and isinstance(node.op, ast.BitAnd):
                return masked(node.left) or masked(node.right)
            return False
        def ok(x):
            if isinstance(x, ast.For):
                return all(ok(y) for y in x.body) and not x.orelse
            if isinstance(x, ast.Assign) and len(x.targets) == 1 and isinstance(x.targets[0], ast.Name):
                v = x.value
                if isinstance(v, ast.Call) and isinstance(v.func, ast.Name) and v.func.id == 'where' and len(v.args) == 3:
                    return masked(v.args[0])
                if isinstance(v, ast.BinOp) and masked(v):
                    ms.add(x.targets[0].id)          # a mask within m (still_ak = is_ak & ...)
                return isinstance(v, (ast.BinOp, ast.Compare, ast.Name))   # a mask of its own
            return False
        return all(ok(x) for x in st.body)

    def year_start_if(self, st):
        """(name, 'MM-DD') for `if month >= M: x = f"{year}-MM-DD" else:
        x = f"{year - 1}-MM-DD"`, month and year the period start's."""
        t = st.test
        if not (isinstance(t, ast.Compare) and len(t.ops) == 1 and isinstance(t.ops[0], ast.GtE)
                and isinstance(t.left, ast.Name) and self.env.get(t.left.id) == ('period_part', 'month')
                and isinstance(t.comparators[0], ast.Constant) and isinstance(t.comparators[0].value, int)):
            return None
        m = t.comparators[0].value
        def one(body, lag):
            if len(body) != 1 or not isinstance(body[0], ast.Assign) or len(body[0].targets) != 1 \
                    or not isinstance(body[0].targets[0], ast.Name) or not isinstance(body[0].value, ast.JoinedStr):
                return None
            vs = body[0].value.values
            if len(vs) != 2 or not isinstance(vs[0], ast.FormattedValue) or not isinstance(vs[1], ast.Constant):
                return None
            y = vs[0].value
            ok = (isinstance(y, ast.Name) and self.env.get(y.id) == ('period_part', 'year')) if lag == 0 else \
                 (isinstance(y, ast.BinOp) and isinstance(y.op, ast.Sub) and isinstance(y.left, ast.Name)
                  and self.env.get(y.left.id) == ('period_part', 'year') and isinstance(y.right, ast.Constant) and y.right.value == 1)
            return (body[0].targets[0].id, vs[1].value) if ok else None
        a, b = one(st.body, 0), one(st.orelse, 1)
        if not a or not b or a != b or not re.fullmatch(r'-\d{2}-\d{2}', a[1]) or int(a[1][1:3]) != m:
            return None
        return a[0], a[1][1:]

    def python_value(self, node):
        """The Python value of an expression that does not depend on a case:
        a constant, a name the formula bound to one, a module's dictionary or
        list, an index into one, a parameter node's own name. None when the
        expression is not one of those. (openfisca-france decides which
        contributions a category of employee owes from dictionaries of its
        own: roadmap Phase 3b′, item 4.)"""
        if isinstance(node, ast.Constant):
            return node.value
        if isinstance(node, ast.Name):
            v = getattr(self, 'fn_globals', {}).get(node.id, Ellipsis)
            if isinstance(v, (dict, list, tuple, str, int, float)) and not isinstance(v, bool):
                return v
            if node.id in self.env and isinstance(self.env[node.id], tuple) and self.env[node.id][0] == 'pyvalue':
                return self.env[node.id][1]
            e = self.env.get(node.id)
            if isinstance(e, tuple) and e[0] == 'period_part' and e[1] == 'year' \
                    and getattr(self, 'year_const', None) is not None:
                return self.year_const        # the year the formula is read for
            if isinstance(e, str):
                #  a name the formula bound to a number or a text written out
                if re.fullmatch(r'-?\d+', e):
                    return int(e)
                if re.fullmatch(r"'[^']*'", e):
                    return e[1:-1]
            return None
        if isinstance(node, (ast.List, ast.Tuple)):
            vs = [self.python_value(x) for x in node.elts]
            if all(v is not None or (isinstance(x, ast.Constant) and x.value is None)
                   for v, x in zip(vs, node.elts)):
                return [tuple(v) if isinstance(v, list) and isinstance(x, ast.Tuple) else v
                        for v, x in zip(vs, node.elts)]
            return None
        if isinstance(node, ast.Dict) and all(k is not None for k in node.keys):
            ks = [self.python_value(k) for k in node.keys]
            vs = [self.python_value(v) for v in node.values]
            if all(k is not None for k in ks) and all(v is not None for v in vs):
                return dict(zip(ks, vs))
            return None
        if isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Sub)):
            a, b = self.python_value(node.left), self.python_value(node.right)
            if isinstance(a, str) and isinstance(b, str) and isinstance(node.op, ast.Add):
                return a + b           # 'compute_' + the name of the variable
            if isinstance(a, int) and isinstance(b, int) and not isinstance(a, bool) and not isinstance(b, bool):
                return a + b if isinstance(node.op, ast.Add) else a - b
            return None
        if isinstance(node, ast.Subscript):
            base, key = self.python_value(node.value), self.python_value(node.slice)
            if isinstance(base, (dict, list, tuple)) and key is not None:
                try:
                    return base[key]
                except (KeyError, IndexError, TypeError):
                    return None
            return None
        if isinstance(node, ast.Attribute):
            b = self.e_safe(node.value)
            if isinstance(b, tuple) and b[0] == 'enum':
                return node.attr               # a member of an enumeration, by its name
            if node.attr in ('name', 'value') and isinstance(self.e_safe(node.value), str):
                t = self.e_safe(node.value)
                return t.strip("'") if t else None
            if node.attr == '_name':
                t = self.e_safe(node.value)
                if isinstance(t, tuple) and t[0] == 'param' and t[1]:
                    #  the parameter node's own last name, as the engine's
                    #  `_name` gives it (with the preprocessing suffix the
                    #  package's dictionaries are keyed by)
                    return t[1][-1] + '_after_preprocessing'
            return None
        return None

    def date_text(self, node):
        """'period_start', or a date written YYYY-MM-DD, for an expression
        that is the calculation date or a date the formula writes."""
        t = self.e_safe(node)
        if t == 'period_start':
            return 'period_start'
        if isinstance(t, str):
            m = re.fullmatch(r'date\("(\d{4}-\d{2}-\d{2})"\)', t)
            if m:
                return m.group(1)
        return None

    def e_safe(self, node):
        try:
            return self.e(node)
        except Residue:
            return None

    def static_truth(self, test):
        """True or False when the test is a parameter (or its negation) whose
        value is the same at every date of the twin's window, else None."""
        #  a chain (`date(a) <= period.start.date <= date(b)`): each link
        if isinstance(test, ast.Compare) and len(test.ops) > 1:
            parts = [self.static_truth(ast.Compare(left=a, ops=[o], comparators=[b]))
                     for a, o, b in zip([test.left] + test.comparators[:-1], test.ops, test.comparators)]
            if any(x is None for x in parts):
                return None
            return all(parts)
        #  the calculation date compared with a date the formula writes: the
        #  twin keeps the years its tests ask about, so a branch of an
        #  if/elif chain over the dates a decree ran can be decided when the
        #  twin is written (openfisca-france's allegement général)
        if isinstance(test, ast.Compare) and len(test.ops) == 1 and self.params.window:
            a, b = (self.date_text(test.left), self.date_text(test.comparators[0]))
            if (a == 'period_start') != (b == 'period_start') and a and b:
                op = {ast.Lt: '<', ast.LtE: '<=', ast.Gt: '>', ast.GtE: '>=', ast.Eq: '==', ast.NotEq: '!='}.get(type(test.ops[0]))
                if op:
                    lo, hi = self.params.window
                    cmps = {'<': lambda x, y: x < y, '<=': lambda x, y: x <= y, '>': lambda x, y: x > y,
                            '>=': lambda x, y: x >= y, '==': lambda x, y: x == y, '!=': lambda x, y: x != y}[op]
                    truths = {cmps(d if a == 'period_start' else a, b if b != 'period_start' else d)
                              for d in (lo, hi)}
                    if len(truths) == 1:
                        value = truths.pop()
                        note = (f'the calculation date {op} {b if a == "period_start" else a} is {value} '
                                'at every date of the tests: the if decided when the twin was written')
                        if note not in self.approx:
                            self.approx.append(note)
                        return value
        #  the day so many months before the calculation date (`n_2.date >=
        #  date(2009, 6, 1)`), compared with a date the formula writes
        if isinstance(test, ast.Compare) and len(test.ops) == 1 and self.params.window \
                and isinstance(test.left, ast.Attribute) and test.left.attr == 'date':
            sh = self.e_safe(test.left.value)
            b = self.date_text(test.comparators[0])
            op = {ast.Lt: '<', ast.LtE: '<=', ast.Gt: '>', ast.GtE: '>=', ast.Eq: '==', ast.NotEq: '!='}.get(type(test.ops[0]))
            if isinstance(sh, tuple) and sh[0] == 'date_rel' and sh[1] == 'shift' and b and b != 'period_start' and op:
                def moved(d):
                    dd = datetime.date.fromisoformat(d)
                    m = dd.year * 12 + dd.month - 1 + sh[2]
                    return f'{m // 12:04d}-{m % 12 + 1:02d}-01'
                cmps = {'<': lambda x, y: x < y, '<=': lambda x, y: x <= y, '>': lambda x, y: x > y,
                        '>=': lambda x, y: x >= y, '==': lambda x, y: x == y, '!=': lambda x, y: x != y}[op]
                truths = {cmps(moved(d), b) for d in self.params.window}
                if len(truths) == 1:
                    value = truths.pop()
                    self.approx.append(f'{ast.unparse(test)} is {value} at every date of the tests: '
                                       'the if decided when the twin was written')
                    return value
        #  `x is None`, `x is not None`: an argument the call left out, or
        #  one it gave (openfisca-france's helpers read their own defaults)
        if isinstance(test, ast.Compare) and len(test.ops) == 1 and isinstance(test.ops[0], (ast.Is, ast.IsNot)):
            left, right = test.left, test.comparators[0]
            if isinstance(right, ast.Constant) and right.value is None:
                #  a value the formula read is never None (the engine gives it
                #  an array), so only the literal None is None
                isnone = isinstance(left, ast.Constant) and left.value is None
                if not isnone:
                    self.notes.append('a test that a value the formula read is not nothing, '
                                      'which it never is: ' + ast.unparse(test))
                return isnone if isinstance(test.ops[0], ast.Is) else not isnone
        #  `name in <a dictionary of the module>`, `a == 'text'` of values the
        #  formula does not read from the case: decided when the twin is written
        if isinstance(test, ast.Compare) and len(test.ops) == 1 \
                and isinstance(test.ops[0], (ast.In, ast.NotIn, ast.Eq, ast.NotEq)):
            a, b = self.python_value(test.left), self.python_value(test.comparators[0])
            if a is not None and b is not None and not isinstance(b, (int, float)):
                op = type(test.ops[0])
                if op is ast.In:
                    return a in b
                if op is ast.NotIn:
                    return a not in b
                if op is ast.Eq:
                    return a == b
                return a != b
        neg = False
        while isinstance(test, ast.UnaryOp) and isinstance(test.op, ast.Not):
            neg, test = not neg, test.operand
        #  a list written in the program, used as a condition: it holds when
        #  the list has something in it (Python's truth of a list)
        t0 = self.e_safe(test)
        if isinstance(t0, tuple) and t0[0] in ('list', 'exprs'):
            return bool(t0[1]) != neg
        if isinstance(t0, str) and t0 in ('true', 'false'):
            return (t0 == 'true') != neg
        if isinstance(test, ast.BoolOp):
            #  `a and b` of parameters: decided when each part is
            parts = [self.static_truth(v) for v in test.values]
            if any(p is None for p in parts):
                return None
            value = all(parts) if isinstance(test.op, ast.And) else any(parts)
            return value != neg
        if isinstance(test, ast.Compare) and len(test.ops) == 1 and isinstance(test.comparators[0], ast.Constant) \
                and isinstance(test.comparators[0].value, (int, float)):
            #  a parameter compared with a number (`if age_exemption > 0:`)
            try:
                t = self.e(test.left)
                node = self.params.node(t[1]) if isinstance(t, tuple) and t[0] == 'param' else None
            except Residue:
                return None
            if node is None or not hasattr(node, 'values_list'):
                return None
            op = {ast.Lt: lambda a, b: a < b, ast.LtE: lambda a, b: a <= b, ast.Gt: lambda a, b: a > b,
                  ast.GtE: lambda a, b: a >= b, ast.Eq: lambda a, b: a == b, ast.NotEq: lambda a, b: a != b}.get(type(test.ops[0]))
            vals = self.window_values(node)
            if op is None or not vals or not all(isinstance(v, (int, float)) for v in vals):
                return None
            truths = {op(v, test.comparators[0].value) for v in vals}
            if len(truths) != 1:
                return None
            value = truths.pop()
            note = f'{".".join(t[1])} { {ast.Lt: '<', ast.LtE: '<=', ast.Gt: '>', ast.GtE: '>=', ast.Eq: '==', ast.NotEq: '!='}[type(test.ops[0])]} {test.comparators[0].value} is {value} at every date of the tests: the if decided when the twin was written'
            if note not in self.approx:
                self.approx.append(note)
            return value != neg
        try:
            t = self.e(test)
        except Residue:
            return None
        if not (isinstance(t, tuple) and t[0] == 'param'):
            return None
        try:
            node = self.params.node(t[1])
        except Residue:
            return None
        if not hasattr(node, 'values_list'):
            return None
        vals = sorted((v for v in node.values_list if v.value is not None), key=lambda v: v.instant_str)
        win = self.params.window
        if win:
            lo, hi = win
            kept = [v for i, v in enumerate(vals)
                    if v.instant_str <= hi and (i + 1 == len(vals) or vals[i + 1].instant_str > lo)]
            vals = kept or vals[-1:]
        truths = {bool(v.value) for v in vals}
        if len(truths) != 1:
            return None
        value = truths.pop()
        note = f'{".".join(t[1])} is {value} at every date of the tests: the if decided when the twin was written'
        if note not in self.approx:
            self.approx.append(note)
        return value != neg

    def window_values(self, node):
        """The values a parameter takes at the dates of the twin's window."""
        vals = sorted((v for v in node.values_list if v.value is not None), key=lambda v: v.instant_str)
        if self.params.window:
            lo, hi = self.params.window
            vals = [v for i, v in enumerate(vals)
                    if v.instant_str <= hi and (i + 1 == len(vals) or vals[i + 1].instant_str > lo)] or vals[-1:]
        return [v.value for v in vals]

    def inline(self, h, n):
        """The value of a call of the package's helper h: its body read with
        its parameters bound to the call's arguments. A constant, `period`,
        `parameters` or the entity is put in the helper's source in place of
        its parameter; any other argument is read first, where the call is."""
        tree = ast.parse(textwrap.dedent(inspect.getsource(h))).body[0]
        return self.inline_tree(tree, n, h.__globals__, h.__name__)

    def inline_tree(self, tree, n, globs, fname, outer=False):
        depth = getattr(self, 'inline_depth', 0)
        #  openfisca-france's helpers call helpers: `apply_bareme` through
        #  `apply_bareme_for_relevant_type_sal` through `montant_cotisation`.
        #  A value that grows past a size becomes a step of its own, so the
        #  depth a formula may reach is the chain's, not the expression's
        #  (Phase 3b′, step 1: 33 of the survey's blocks were this limit).
        if depth > 6:
            raise Residue(f'{fname}(), helpers calling helpers too deep')
        params = [a.arg for a in tree.args.args]
        args = list(n.args) + [None] * (len(params) - len(n.args))
        for k in n.keywords:
            if k.arg in params:
                args[params.index(k.arg)] = k.value
        #  an argument the call leaves out takes the helper's own default
        #  (DEFAULT_ROUND_BASE_DECIMALS: roadmap Phase 3b′, item 4)
        defaults = list(tree.args.defaults)
        if defaults:
            for i, d in enumerate(defaults, start=len(params) - len(defaults)):
                if i < len(args) and args[i] is None and d is not None:
                    if isinstance(d, ast.Name):
                        #  a default written as a name of the helper's own
                        #  module (DEFAULT_ROUND_BASE_DECIMALS): its value
                        g = globs.get(d.id)
                        if isinstance(g, (int, float, str)) and not isinstance(g, bool):
                            d = ast.Constant(g)
                    args[i] = d
        names, bound = {}, {}
        for p, a in zip(params, args):
            if a is None:
                raise Residue(f'{fname}() called without its argument {p}')
            if isinstance(a, ast.Constant) or (isinstance(a, ast.Name) and a.id in ('period', 'parameters', self.entity_arg)):
                names[p] = a
            else:
                bound[p] = self.e(a)
        body = [subst(st, names) for st in tree.body
                if not (isinstance(st, ast.Expr) and isinstance(st.value, ast.Constant))]
        saved = (self.env, set(self.boolnames), getattr(self, 'fn_globals', {}), self.yields)
        self.env = dict(self.env, **bound) if outer else dict(bound)
        self.fn_globals = globs
        self.inline_depth = depth + 1
        self.yields = []
        try:
            ret = self.block(body)
            if ret is None and self.yields:
                #  a generator: the terms it yields, for the sum that reads it
                return ('yields', list(self.yields))
            if ret is None:
                raise Residue(f'{fname}() returns nothing the translator reads')
            if isinstance(ret, ast.Tuple):
                out = ('tuple', [self.e(x) for x in ret.elts])     # `a, b = helper(...)`
            else:
                out = self.e(ret) if isinstance(ret, ast.AST) else ret
        finally:
            self.env, self.boolnames, self.fn_globals, self.yields = saved
            self.inline_depth = depth
        return out

    def age_formula(self, src):
        #  an age in whole years worked out from a birth date with NumPy's
        #  date types (the country template's `age`): the whole months from
        #  the birth date to the period's start, divided by 12 (roadmap §8,
        #  Phase 3b work left, item 8). The shape is recognised, not read.
        if 'datetime64[Y]' not in src or self.var.value_type not in (int, float):
            return None
        dates = re.findall(r'''{0}\(\s*["']([a-z_0-9]+)["']\s*,\s*period\s*\)'''.format(self.entity_arg), src)
        dates = [d for d in dict.fromkeys(dates)
                 if d in self.system.variables and self.system.variables[d].value_type is datetime.date]
        if len(dates) != 1 or 'period.start' not in src:
            return None
        self.reads.add(dates[0])
        self.approx.append(f'{self.var.name}: the age in whole years on the first day of the period, from {dates[0]}')
        return f'whole_years({dates[0]}, period_start)'

    def formula(self, fn):
        src = source_of(fn)
        tree = ast.parse(src).body[0]
        self.entity_arg = tree.args.args[0].arg
        self.fn_globals = getattr(fn, '__globals__', {})
        self.relations = set()
        body = [s for s in tree.body if not (isinstance(s, ast.Expr) and isinstance(s.value, ast.Constant))]
        age = self.age_formula(src)
        if age:
            return age, src
        ret = self.block(body)
        if ret is None:
            raise Residue('no return')
        text = self.expr(ret) if isinstance(ret, ast.AST) else ret
        if isinstance(ret, ast.AST) and self.var.value_type is not bool and self.boolmul(ret)[0] == 'bool':
            text = f'if {text}: 1 else: 0'          # a yes or no counted as 1 or 0
        return text, src


def variable_rule(system, params, name, out_vars, within=(), known_periods=()):
    v = system.variables[name]
    rule = {'name': name, 'kind': 'derived', 'entity': camel(v.entity.key),
            'dtype': 'Judgment' if v.value_type is bool else 'Text' if v.value_type is str or v.value_type.__name__ in ('Enum', 'EnumType') else 'Money',
            'period': {'month': 'Month', 'year': 'Year'}.get(str(v.definition_period), str(v.definition_period))}
    ref = v.reference
    if isinstance(ref, (list, tuple)):
        ref = ref[0] if ref else None
    rule['source'] = (v.label or name) + (f' ({ref})' if ref else '')
    vfile = file_of(v)
    info = {'name': name, 'file': vfile, 'entity': v.entity.key, 'period': str(v.definition_period),
            'value_type': v.value_type.__name__, 'label': v.label, 'reference': ref, 'formulas': []}
    reads, relations, notes = set(), set(), []
    musts = []
    by_period, periods = set(), set()
    derived_periods, given_periods = set(), set()
    helpers = {}
    approx = []
    versions = []
    adds = getattr(v, 'adds', None)
    subtracts = getattr(v, 'subtracts', None)
    defined_for = getattr(v, 'defined_for', None)
    df = defined_for if isinstance(defined_for, str) else getattr(defined_for, 'name', None)
    try:
        if v.formulas:
            starts = sorted(v.formulas.keys())
            #  the twin keeps the years its tests ask about (`covers`, and the
            #  constraint that refuses a case dated outside them), so only the
            #  versions of the formula in force in those years are read: an
            #  older version the package keeps for history is not translated
            if params.window:
                lo, hi = params.window
                kept = [st for i, st in enumerate(starts)
                        if st <= hi and (i + 1 == len(starts) or starts[i + 1] > lo)]
                if kept and kept != starts:
                    info['versions_outside_the_window'] = [st for st in starts if st not in kept]
                    starts = kept
            for i, start in enumerate(starts):
                nxt = starts[i + 1] if i + 1 < len(starts) else None
                end = (datetime.date.fromisoformat(nxt) - datetime.timedelta(days=1)).isoformat() if nxt else None

                def read_one(year=None, start=start):
                    tr = Translator(system, params, v)
                    tr.within, tr.out_vars = within, out_vars
                    tr.known_periods = set(known_periods)
                    tr.year_const = year
                    text, src = tr.formula(v.formulas[start])
                    return tr, text, src

                try:
                    tr, text, src = read_one()
                    pieces = [(start, end, text)]
                    trs = [tr]
                except Residue as r:
                    src0 = source_of(v.formulas[start])
                    #  a formula whose shape the calculation's own year decides
                    #  (the years of investment a reduction still carries): one
                    #  version per year of the twin's window, with that year in
                    #  place of `period.start.year` (roadmap Phase 3b′, item 4)
                    yrs = year_window(params.window, start, end) if 'period.start.year' in src0 else []
                    pieces, trs = [], []
                    for y, ystart, yend in yrs:
                        try:
                            tr, text, src = read_one(y)
                        except Residue:
                            pieces = []
                            break
                        pieces.append((ystart, yend, text))
                        trs.append(tr)
                    if not pieces:
                        info['formulas'].append({'from': start, 'python': src0, 'residue': str(r)})
                        raise
                    notes.append(f'{name}: one version per year, where the calculation\'s own '
                                 'year decides which years the formula reads')
                #  what each year's reading found: the steps of the 2016
                #  Duflot-Pinel-Denormandie reduction were the 2016 reading's,
                #  and only the last year's were kept (its step 3 had no rule)
                for tr in trs:
                    reads |= tr.reads; relations |= tr.relations
                    notes += [x for x in tr.notes if x not in notes]
                    musts += [x for x in tr.musts if x not in musts]
                    by_period |= tr.by_period; periods |= tr.periods
                    derived_periods |= tr.derived_periods
                    given_periods |= tr.given_periods
                    helpers.update(tr.helpers)
                    approx += [a for a in tr.approx if a not in approx]
                info['formulas'].append({'from': start, 'python': src, 'formula': pieces[0][2]})
                for pstart, pend, ptext in pieces:
                    ver = {'effective_from': '1900-01-01' if pstart == '0001-01-01' else pstart, 'formula': ptext}
                    if pend:
                        ver['effective_to'] = pend
                    versions.append(ver)
        elif adds or subtracts:
            def names(x):
                if isinstance(x, str):
                    node = params.node(x.split('.'))
                    vals = sorted(node.values_list, key=lambda p: p.instant_str)
                    return list(vals[-1].value)
                return list(x or [])
            a, s = names(adds), names(subtracts)
            reads |= set(a) | set(s)

            def term(x):
                # a person's variable added up for a group: the sum over its members
                k = period_factor(system, v, x)
                if x in system.variables and system.variables[x].entity.key in PERSON_ENTITIES and v.entity.key not in PERSON_ENTITIES:
                    rel = f'member_of_{v.entity.key}'
                    relations.add(rel)
                    return f'(sum({rel}.{x}){k})' if k else f'sum({rel}.{x})'
                return f'({x}{k})' if k else x
            text = ' + '.join(map(term, a)) if a else '0'
            if s:
                text = f'({text}) - ' + ' - '.join(map(term, s))
            versions = [{'effective_from': '1900-01-01', 'formula': text}]
            info['formulas'].append({'adds': a, 'subtracts': s, 'formula': text})
        else:
            return None, info, set(), set(), [], set(), set(), set(), set()          # an input
        if df:
            zero = 'false' if v.value_type is bool else '0'
            for ver in versions:
                ver['formula'] = f'if {df}:\n    {ver["formula"]}\nelse:\n    {zero}'
            reads.add(df)
            info['defined_for'] = df
    except Residue as r:
        rule['versions'] = [{'effective_from': '1900-01-01', 'formula': f'__residue__ {r}'}]
        rule['residue_reason'] = str(r)
        rule['python_source'] = '\n'.join(f.get('python', '') for f in info['formulas'])
        info['residue'] = str(r)
        return rule, info, set(), set(), [], set(), set(), set(), set()
    end = getattr(v, 'end', None)
    if end:                                    # after its end, a variable has its default value
        end = str(end)
        versions = [ver for ver in versions if ver['effective_from'] <= end]
        if versions:
            if not versions[-1].get('effective_to') or versions[-1]['effective_to'] > end:
                versions[-1]['effective_to'] = end
            nxt = (datetime.date.fromisoformat(end) + datetime.timedelta(days=1)).isoformat()
            versions.append({'effective_from': nxt, 'formula': 'false' if v.value_type is bool else '0'})
        info['end'] = end
    #  Before the first version of its formula, a variable has its default
    #  value as well: OpenFisca answers 0 for a basic income asked about a
    #  year before the one its formula starts in, which is what the country
    #  template's own test "the basic income should be 0 before it was
    #  introduced" asks for. The versions kept are those in force at some
    #  date of the twin's window (Params.clip/2), so a first version that
    #  starts after 1900 is a formula with nothing before it.
    if versions and versions[0].get('effective_from', '1900-01-01') > '1900-01-01':
        first = versions[0]['effective_from']
        prev = (datetime.date.fromisoformat(first) - datetime.timedelta(days=1)).isoformat()
        before = 'false' if v.value_type is bool else (default_literal(v) or '0')
        versions.insert(0, {'effective_from': '1900-01-01', 'effective_to': prev, 'formula': before})
        info['default_before'] = first
    rule['versions'] = versions
    if musts:
        #  the formula's own assertions, as integrity constraints of the twin
        #  (roadmap Phase 3b′, item 4)
        rule['must'] = sorted(set(musts))
    if approx:
        rule['approximated'] = '; '.join(sorted(set(approx)))
        info['approximated'] = rule['approximated']
    info['helpers'] = list(helpers.values())
    return rule, info, reads, relations, notes, by_period, periods, derived_periods | given_periods, given_periods


def year_window(window, start, end):
    """The years of the twin's window a version of a formula is in force in,
    each with the first and last day of that year within the version."""
    if not window:
        return []
    lo, hi = window
    first = max(start, lo)[:4]
    last = min(end or hi, hi)[:4]
    out = []
    for y in range(int(first), int(last) + 1):
        ys, ye = max(f'{y}-01-01', start, lo), min(f'{y}-12-31', end or hi, hi)
        if ys <= ye:
            out.append((y, ys, ye))
    return out


def inside(var, within):
    f = file_of(var) or ''
    for w in within:
        w = w.strip('/')
        #  `variables/` in PolicyEngine and the country template, `model/` in
        #  openfisca-france
        for root in ('/variables/', '/model/'):
            if (root + w + '/') in f or f.endswith(root + w + '.py'):
                return True
    return False


def extract_with(system, dialect, programme, roots, within=(), window=None):
    helper_words(dialect)
    #  A variable the programme reads for another period has a place for the
    #  period in its template, so every read of it names one: the pass is run
    #  again until the set of such variables stops growing (Phase 3b′, item 1).
    known, periods, out = set(), set(), None
    for _ in range(4):
        out = extract_pass(system, dialect, programme, roots, within, window, known)
        if out[3] <= known:
            periods = out[4]
            break
        known |= out[3]
        periods = out[4]
    module, infos, files = out[0], out[1], out[2]
    return module, infos, files, sorted(known), sorted(periods)


def extract_pass(system, dialect, programme, roots, within, window, known_periods):
    params = Params(system, window)
    rules, infos, relations = {}, {}, set()
    by_period, periods, derived_periods, given_periods = set(), set(), set(), set()
    todo, seen = list(roots), set()
    while todo:
        n = todo.pop()
        if n in seen:
            continue
        seen.add(n)
        if n not in system.variables:
            continue
        if within and not inside(system.variables[n], within):
            infos[n] = {'name': n, 'entity': system.variables[n].entity.key, 'input': True,
                        'period': str(system.variables[n].definition_period),
                        'outside': bool(system.variables[n].formulas or getattr(system.variables[n], 'adds', None)),
                        'note': 'outside the programme: a fact the case states'}
            continue
        rule, info, reads, rels, notes, bp, pds, dp, gp = variable_rule(system, params, n, rules, within, known_periods)
        derived_periods |= dp
        given_periods |= gp
        infos[n] = info
        by_period |= bp
        periods |= pds
        if rule:
            rules[n] = rule
            for h in info.get('helpers', []):
                rules[h['name']] = h
                reads |= set(re.findall(r'[A-Za-z_][A-Za-z0-9_]*', h['versions'][0]['formula'].split()[0]))
            relations |= rels
            if notes:
                info['notes'] = sorted(set(notes))
            todo.extend(sorted(reads - seen))
        else:
            info['input'] = True
    #  The package's own name for the person: `person` in the country template
    #  and PolicyEngine, `individu` in openfisca-france. A variable's entity is
    #  written from the package (camel(var.entity.key)), so the roles and the
    #  membership relations must use the same name, or a rule of an Individu
    #  reading a value of its foyer fiscal finds no relation whose first
    #  argument is its own entity (Phase 3b′, step 3).
    person = camel(person_key(system))
    role_rules = [{'name': n, 'kind': 'input', 'entity': person, 'dtype': 'Judgment',
                   'source': WORDS['role'].format(k=k, g=g, pl=pl)}
                  for n, (g, k, pl) in sorted(ROLES.items()) if any(n in str(r.get('versions')) for r in rules.values())]
    rel_rules = [{'name': r, 'kind': 'data_relation',
                  'data_relation': {'arity': 2, 'arguments': [person, camel(r[len('member_of_'):])]}}
                 for r in sorted(relations)]
    #  a value the case states for each period the calculation reads: an input
    #  whose template has a place for the period
    period_rules = []
    for n in sorted(by_period):
        var = system.variables.get(n)
        if n in rules:
            rules[n]['by_period'] = True
            if n in given_periods:
                rules[n]['overridable'] = True
            continue
        if n in derived_periods:
            #  the programme works it out, and its rule can be worked out for
            #  another period: it is read with the period among its places
            continue
        ref = getattr(var, 'reference', None) if var is not None else None
        if isinstance(ref, (list, tuple)):
            ref = ref[0] if ref else None
        period_rules.append({
            'name': n, 'kind': 'input', 'by_period': True,
            'entity': camel(var.entity.key) if var is not None else person,
            'dtype': ('Judgment' if var.value_type is bool else
                      'Text' if var.value_type is str or var.value_type.__name__ in ('Enum', 'EnumType')
                      else 'Money') if var is not None else 'Money',
            'source': ((var.label or n) + (f' ({ref})' if ref else '')) if var is not None else n})
    #  An input the programme reads whose value the package gives a default:
    #  the default is written once, as the variable's own rule, and a case
    #  states only the values it actually gives — the rule reads the case's
    #  value first (`overridable`). Stating every default in every case made
    #  openfisca-france's income tax a program of 736,847 lines, of which
    #  1,757 values per case were the same 0, and Logical English could not
    #  parse it at all (Phase 3b′, step 3).
    default_rules = []
    for n in sorted(infos):
        info = infos[n]
        var = system.variables.get(n)
        if not info.get('input') or n in by_period or var is None:
            continue
        lit = default_literal(var)
        if lit is None:
            continue
        info['default_rule'] = True
        dref = getattr(var, 'reference', None)
        if isinstance(dref, (list, tuple)):
            dref = dref[0] if dref else None
        default_rules.append({
            'name': n, 'kind': 'derived', 'overridable': True,
            'entity': camel(var.entity.key),
            'dtype': 'Text' if (var.value_type is str or var.value_type.__name__ in ('Enum', 'EnumType')) else 'Money',
            'period': {'month': 'Month', 'year': 'Year'}.get(str(var.definition_period), str(var.definition_period)),
            'source': (var.label or n) + (f' ({dref})' if dref else '')
                      + WORDS['default'],
            'versions': [{'effective_from': '1900-01-01', 'formula': lit}]})
    #  an input of text the case states (a commune's INSEE code, `depcom`):
    #  declared as a text, or the twin reads it as a number and 01001, a
    #  commune of the Ain, becomes 1001, which no table knows
    named = {r['name'] for r in rel_rules + role_rules + period_rules + default_rules} | set(rules)
    text_rules = [{'name': n, 'kind': 'input', 'entity': camel(system.variables[n].entity.key), 'dtype': 'Text',
                   'source': system.variables[n].label or n}
                  for n in sorted(infos) if infos[n].get('input') and n not in named and n in system.variables
                  and system.variables[n].value_type is str]
    all_rules = rel_rules + role_rules + period_rules + default_rules + text_rules + list(params.rules.values()) + [rules[k] for k in sorted(rules)]
    strip_markers(all_rules)
    #  Each value worked out once per question, as OpenFisca's engine works
    #  out each variable once per period and keeps it (`; memorable`). The
    #  income tax reads the same values along many paths: without it, one
    #  case's tax ran out of an 8 GB machine's memory; with it, 14 seconds.
    for r in all_rules:
        if r.get('kind') == 'derived':
            r['memorable'] = True
    module = {'format': 'rulespec/v1',
              'module': {'title': f'{programme} ({DIALECTS[dialect][0]})',
                         'summary': f'Variables of {DIALECTS[dialect][0]} read by {", ".join(roots)}, written for the twin builder.'},
              'rules': all_rules}
    return module, infos, sorted(f for f in params.files if f), by_period, periods


# ------------------------------------------------------------------ tests

def num(v):
    """A test's expected value: a number, or the arithmetic the test writes
    out (`round(0.0045 * (0.6888 - 0.45), 5)`), worked out. Only numbers,
    the four operations, powers and round/min/max/abs are read."""
    if isinstance(v, str):
        try:
            tree = ast.parse(v.strip(), mode='eval')
        except SyntaxError:
            return v
        fns = {'round': round, 'min': min, 'max': max, 'abs': abs}
        ops = {ast.Add: lambda a, b: a + b, ast.Sub: lambda a, b: a - b, ast.Mult: lambda a, b: a * b,
               ast.Div: lambda a, b: a / b, ast.Pow: lambda a, b: a ** b}

        def ev(n):
            if isinstance(n, ast.Constant) and isinstance(n.value, (int, float)) and not isinstance(n.value, bool):
                return n.value
            if isinstance(n, ast.BinOp) and type(n.op) in ops:
                return ops[type(n.op)](ev(n.left), ev(n.right))
            if isinstance(n, ast.UnaryOp) and isinstance(n.op, (ast.USub, ast.UAdd)):
                x = ev(n.operand)
                return -x if isinstance(n.op, ast.USub) else x
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id in fns and not n.keywords:
                return fns[n.func.id](*[ev(a) for a in n.args])
            raise ValueError('not arithmetic')
        try:
            return ev(tree.body)
        except (ValueError, ZeroDivisionError, TypeError, OverflowError):
            return v
    return v


def at_key(v, k):
    """The value a dict of periods holds under the key k. A year is read from
    YAML as an integer (`2025`) and a month as a string (`2025-03`), so a key
    taken as text has to be tried both ways; None when it is not there."""
    if k in v:
        return v[k]
    try:
        return v[int(k)]
    except (KeyError, ValueError, TypeError):
        return None


def at_period(v, period):
    if isinstance(v, dict) and v and all(re.fullmatch(r'\d{4}(-\d{2})?', str(k)) for k in v):
        ks = sorted((str(k) for k in v), reverse=True)
        p = str(period)
        for k in ks:
            if k <= p or p.startswith(k):
                return at_key(v, k)
        return at_key(v, ks[-1])
    return v


def given_at(v, period, var=None):
    """The value a test gives an input for the case's period: its value at
    that period, or for the year that holds it, or the year's months; None
    when the test gives it only for other periods. OpenFisca does not carry
    a value to another period (a capital gain of 2025 is no gain in 2026,
    and the 2026 case of the high-income contribution then owed 7,500 €
    rather than nothing), except for a variable defined once for all time.

    PolicyEngine's core does carry an input forward: a test that reports 26
    weeks worked in 2024 and asks about 2026 is a test of 26 weeks in 2026
    ("weeks worked reported for 2024 carry forward to 2026", SNAP's work
    requirement). So the earlier value is taken where the package is one of
    PolicyEngine's, and only for an input — a value the package computes is
    worked out afresh for each period by both engines."""
    if not (isinstance(v, dict) and v and all(re.fullmatch(r'\d{4}(-\d{2})?', str(k)) for k in v)):
        return v
    if var is not None and str(var.definition_period) == 'eternity':
        return at_period(v, period)
    if DIALECT in CARRIES_FORWARD and (var is None or not computed_variable(var)):
        return at_period(v, period)
    p = str(period)
    if any(str(k) == p or p.startswith(str(k)) or str(k).startswith(p) for k in v):
        return at_period(v, period)
    return None


def computed_variable(var):
    """True when the package works the variable out rather than taking it as
    an input: it has a formula, or adds other variables up. (The static
    reader of an upload builds its own variables, without openfisca-core's
    `is_input_variable`, so the question is asked of the formulas.)"""
    f = getattr(var, 'is_input_variable', None)
    if callable(f):
        return not f()
    return bool(getattr(var, 'formulas', None) or getattr(var, 'adds', None) or getattr(var, 'subtracts', None))


def default_value(var):
    """A variable's default as a test value: a number, an enumeration's
    member name, a date, or true for a Boolean whose default is true
    (take-up, filing: not stated would be false in the twin); None for a
    Boolean whose default is false, or a text."""
    dv = var.default_value
    if var.value_type is bool:
        return True if dv is True else None
    if dv is None:
        return None
    if hasattr(dv, 'name') and var.value_type.__name__ in ('Enum', 'EnumType'):
        return dv.name
    if isinstance(dv, (int, float)):
        return dv
    if isinstance(dv, datetime.date):
        return dv                  # a date (the template's birth: 1970-01-01)
    return None


def default_literal(var):
    """A variable's default as the formula language writes it: a number as it
    is, an enumeration's member or a text in quotes, a date as `date("…")`.
    None where there is none to write, or where not stating the value already
    means the default (a Boolean: a judgment no case states does not hold)."""
    dv = default_value(var)
    if dv is None or isinstance(dv, bool):
        return None
    if isinstance(dv, (int, float)):
        return repr(dv)
    if isinstance(dv, datetime.date):
        return f'date("{dv.isoformat()}")'
    if isinstance(dv, str):
        return f'date("{dv}")' if re.fullmatch(r'\d{4}-\d{2}-\d{2}', dv) else "'" + dv + "'"
    return None


#  A value the case does not state at all, which is not the same as a value
#  stated as nothing: the key is left out of the case, so that another key of
#  the same variable (its value at each period the calculation reads) is the
#  one the twin keeps (one_value_per_input/3 in the twin builder).
NOT_STATED = object()


def stated(system, name, raw, period, case):
    """The value of input `name` for the case: its value at the case's
    period, a twelfth of a year's amount stated for a monthly variable, as
    the engine divides it. A text stays a text (`depcom: "01001"`, not 1001)."""
    var0 = system.variables.get(name)
    if var0 is not None and given_at(raw, period, var0) is None:
        #  Given for other periods only. A value the package computes (`rfr`)
        #  is then not stated at all: the case's own period is the twin's to
        #  work out, and a default stated here would be a given value, which
        #  the rule reads first — the 2026 case of the high-income
        #  contribution had `le rfr donné … pour 2026 est 0`, and that key
        #  displaced the test's own rfr of 2024 and 2025, which the smoothing
        #  reads. An input of the package keeps its default.
        if computed_variable(var0):
            return NOT_STATED
        return default_value(var0)
    if name in system.variables and system.variables[name].value_type is str:
        v = at_period(raw, period)
        return str(v) if isinstance(v, (str, int)) and not isinstance(v, bool) else v
    v = num(at_period(raw, period))
    if isinstance(raw, dict) and re.fullmatch(r'\d{4}-\d{2}', str(period)) and name in system.variables:
        keys = [str(k) for k in raw]
        if str(period) not in keys and str(period)[:4] in keys:
            var = system.variables[name]
            si = getattr(getattr(var, 'set_input', None), '__name__', '')
            if str(var.definition_period) == 'month' and 'divide' in si and isinstance(v, (int, float)) and not isinstance(v, bool):
                return v / 12
    return per_month(system, name, v, case, period)


def per_month(system, name, v, case, period=None):
    """An input the test states for a year, defined by the month: a twelfth
    of it, as the engine divides a year's value among the months
    (`set_input_divide_by_period`). The twin reads such a value at a twelfth
    and multiplies by twelve wherever a year's rule sums the months
    (period_factor/3), so the two agree — Child Benefit's four children with
    a respective amount of 1 stated for 2021 are 4 a year, not 48."""
    if name not in system.variables:
        return v
    if not (case.get('twelfths') or re.fullmatch(r'\d{4}', str(period or ''))):
        return v
    var = system.variables[name]
    if str(var.definition_period) != 'month' or not isinstance(v, (int, float)) or isinstance(v, bool):
        return v
    si = getattr(getattr(var, 'set_input', None), '__name__', '')
    return v / 12 if 'divide' in si else v


def read_options(n):
    """The options of a variable read, `x("v", period, [DIVIDE])` or
    `options=[ADD]`: their names."""
    lst = n.args[2] if len(n.args) > 2 else next((k.value for k in n.keywords if k.arg == 'options'), None)
    if lst is None:
        return []
    if isinstance(lst, (ast.List, ast.Tuple)):
        return [getattr(e, 'id', getattr(e, 'attr', '?')) for e in lst.elts]
    return ['?']


_CONSTANTS = {}


def number_constant(name, file):
    """A capitalised name for a number: assigned at the top of the variable's
    file, or one of the engine's constants (MONTHS_IN_YEAR); None otherwise."""
    if not name[:1].isupper():
        return None
    if '' not in _CONSTANTS:
        core = {'MONTHS_IN_YEAR': 12, 'WEEKS_IN_YEAR': 52, 'DAYS_IN_YEAR': 365}
        for mod in ('policyengine_core.commons.formulas', 'openfisca_core.commons.formulas'):
            try:
                m = __import__(mod, fromlist=['x'])
                core.update({k: v for k, v in vars(m).items() if k.isupper() and isinstance(v, (int, float)) and not isinstance(v, bool)})
            except Exception:
                pass
        _CONSTANTS[''] = core
    if file and file not in _CONSTANTS:
        found = {}
        try:
            for st in ast.parse(open(file).read()).body:
                if isinstance(st, ast.Assign) and len(st.targets) == 1 and isinstance(st.targets[0], ast.Name) \
                        and isinstance(st.value, ast.Constant) and isinstance(st.value.value, (int, float)) \
                        and not isinstance(st.value.value, bool):
                    found[st.targets[0].id] = st.value.value
        except Exception:
            pass
        _CONSTANTS[file] = found
    return (_CONSTANTS.get(file) or {}).get(name, _CONSTANTS[''].get(name))


def period_factor(system, var, name):
    """What PolicyEngine does to a number of variable `name` read for the
    period of `var`: a year's value divided among its twelve months
    (' / 12'), a year's twelve months added up (' * 12': the twin's months
    are equal), or nothing. It does so for a flow, an income; a stock, a
    size or an age, keeps its value; openfisca-core does neither."""
    target = system.variables.get(name)
    if target is None or not str(getattr(target, 'quantity_type', '')).lower().endswith('flow'):
        return ''
    mine, theirs = str(var.definition_period).lower(), str(target.definition_period).lower()
    if mine.endswith('month') and theirs.endswith('year'):
        return ' / 12'
    if mine.endswith('year') and theirs.endswith('month'):
        return ' * 12'
    return ''


GROUP_KEYS = {'household': 'households', 'spm_unit': 'spm_units', 'tax_unit': 'tax_units', 'family': 'families',
              'marital_unit': 'marital_units', 'benunit': 'benunits',
              'famille': 'familles', 'foyer_fiscal': 'foyers_fiscaux', 'menage': 'menages'}

#  the words a test writes a group's members under, by role (OpenFisca builds
#  a group from `members`, or from one list per role)
def default_roles(system, grp):
    """The roles a person holds in a group the test does not describe: the
    first of the group's roles and, where that role has subroles, the first of
    those — as OpenFisca builds a case whose test gives no role lists
    (`add_default_group_entity`). The one person of a tax household is its
    declarant, and its declarant principal; of a famille, its demandeur; of a
    menage, its personne de reference.

    Without them the twin read no declarant, so `celibataire_ou_divorce` was
    false, `nb_adult` and `nbptr` were 0, and the income tax of a case stated
    flat (the trade-union dues: a salary and box 7AC, no `individus:` list)
    divided by a number of parts of 0 and answered nothing."""
    for e in getattr(system, 'entities', []) or []:
        if e.key != grp:
            continue
        for r in getattr(e, 'roles', []) or []:
            out = {r.key}
            subs = getattr(r, 'subroles', None) or []
            if subs:
                out.add(getattr(subs[0], 'key', str(subs[0])))
            return out
    return set()


ROLE_KEYS = ['members', 'adults', 'children', 'parents', 'head', 'spouse',
             'enfants', 'declarants', 'personnes_a_charge', 'personne_de_reference', 'conjoint',
             'demandeur', 'enfant', 'declarant_principal']
PERSON_KEYS = ['people', 'persons', 'individus']

#  the person entity, by the name each package gives it
PERSON_ENTITIES = {'person', 'individu'}


def stated_names(value, prefixes, out):
    """The variables a case gives a value for, at the top of the case or in
    the record of one of a group's members. A value given for each period the
    calculation reads is stated under `at_period.`, not `input.`, so both
    prefixes count: `age` is given that way by every income-tax test."""
    if isinstance(value, dict):
        for k, v in value.items():
            ks = str(k)
            for pre in prefixes:
                if ks.startswith(pre):
                    out.add(ks[len(pre):])
                    break
            stated_names(v, prefixes, out)
    elif isinstance(value, (list, tuple)):
        for v in value:
            stated_names(v, prefixes, out)


def mark_overridable(module, cases, mid):
    """A test that gives a value the package itself computes. OpenFisca lets
    any variable be set as an input, and then its own formula is not used; a
    twin says the same thing by reading the value a scenario gives first and
    its rule otherwise, which is what `overridable` asks the twin builder for
    (a Catala `context` variable is written the same way).

    Without this, every one of the 434 cases of `openfisca-france`'s income
    tax was refused, because the tax administration's own tests give `age`,
    `nbF`, `nbG`, `assurance_vie_pfu_ir` and three others that the package can
    work out for itself: the twin builder marks such a case as one it cannot
    state, so none of its answers was checked (Phase 3b', step 3)."""
    stated = set()
    pres = (f'{mid}#input.', f'{mid}#at_period.')
    for c in cases:
        stated_names(c.get('input') or {}, pres, stated)
    for r in module['rules']:
        if r.get('kind') == 'derived' and r.get('name') in stated:
            r['overridable'] = True


def strip_markers(rules):
    """`?bool:x` is the reader's own mark for a role read as a yes or no
    (`individu.has_role(...)`): the reader strips it where it reads a
    condition, but a role read straight into an `if` carried the mark into
    the formula, which the formula language cannot parse — three of
    impot_revenu's residue blocks. A bare name is read as a judgment there,
    so the mark is simply dropped (Phase 3b', step 3)."""
    for r in rules:
        for v in r.get('versions') or ():
            f = v.get('formula')
            if isinstance(f, str) and '?bool:' in f:
                v['formula'] = f.replace('?bool:', '')


def person_key(system):
    """The package's key for the person entity ('person', or 'individu' in
    openfisca-france): the entity that is not a group. A static upload reads
    its entities from entities.py (of_static.read_entities)."""
    for e in getattr(system, 'entities', ()) or ():
        if getattr(e, 'key', None) in PERSON_ENTITIES:
            return e.key
    for v in getattr(system, 'variables', {}).values():
        k = getattr(getattr(v, 'entity', None), 'key', None)
        if k in PERSON_ENTITIES:
            return k
    return 'person'


def flat_output(t):
    """A test whose expected values are written under their group
    (`output: household: parenting_allowance: …`, or under the one group of
    a plural) with them at the top, as the other tests write them."""
    out = t.get('output') if isinstance(t, dict) else None
    if not isinstance(out, dict):
        return t
    flat, changed = {}, False
    for k, v in out.items():
        if k in GROUP_KEYS and isinstance(v, dict):
            flat.update(v); changed = True
        elif k in GROUP_KEYS.values() and isinstance(v, dict) and len(v) == 1 and isinstance(list(v.values())[0], dict):
            flat.update(list(v.values())[0]); changed = True
        else:
            flat[k] = v
    return dict(t, output=flat) if changed else t


def expand_periods(docs):
    """(number, test) for each test, a test whose outputs name other periods
    than its own split into one test per period named: the expected age of a
    person born in 1980 `1981-03: 1` is a case of March 1981, not of the
    test's own January 2016 (the inputs, given without a period, hold at
    every period, as OpenFisca reads them)."""
    out = []
    for i, t in enumerate(docs, 1):
        t = flat_output(t)
        if not isinstance(t, dict) or not isinstance(t.get('output'), dict):
            out.append((i, t))
            continue
        own = str(t.get('period'))
        keyed = {k: v for k, v in t['output'].items()
                 if isinstance(v, dict) and v and all(re.fullmatch(r'\d{4}(-\d{2})?', str(p)) for p in v)}
        others = sorted({str(p) for v in keyed.values() for p in v if str(p) != own})
        if not others:
            out.append((i, t))
            continue
        base = {k: v for k, v in t['output'].items() if k not in keyed}
        mine = {k: v[own] if own in v else v[int(own)] if own.isdigit() and int(own) in v else None for k, v in keyed.items()}
        mine = {k: v for k, v in mine.items() if v is not None}
        if base or mine:
            out.append((i, dict(t, output={**base, **mine})))
        for p in others:
            outs = {k: v[p] if p in v else v.get(int(p)) if p.isdigit() else v.get(p) for k, v in keyed.items()}
            outs = {k: v for k, v in outs.items() if v is not None}
            if outs:
                out.append((i, dict(t, period=p, output=outs, name=f"{t.get('name', f'case_{i}')} ({p})")))
    return out


def period_of(expr, base):
    """The period an expression names, from the period a case is about, and
    the relations a case must state for it: ('2022', [('years_before', ['2022',
    2, '2024'])]). A period is named by its text (roadmap Phase 3b′, decision
    (a)); `months_of` gives every month of a period."""
    expr = expr.strip()
    if expr == 'period':
        return base, []
    m = re.fullmatch(r'(years|months)_(before|after)\((.*),\s*(\d+)\)', expr)
    if m:
        inner, rows = period_of(m.group(3), base)
        n = int(m.group(4)) * (-1 if m.group(2) == 'after' else 1)
        if m.group(1) == 'years':
            if re.fullmatch(r'\d{4}', inner):
                out = str(int(inner) - n)
            else:
                y, mo = inner.split('-')
                out = f'{int(y) - n}-{mo}'
        else:
            if re.fullmatch(r'\d{4}', inner):
                if n % 12:
                    raise ValueError(f'{n} months from the year {inner}')
                out = str(int(inner) - n // 12)
            else:
                y, mo = (int(x) for x in inner.split('-'))
                k = y * 12 + (mo - 1) - n
                out = f'{k // 12}-{k % 12 + 1:02d}'
        kind = f'{m.group(1)}_before'
        row = [out, abs(n), inner] if m.group(2) == 'before' else [inner, abs(n), out]
        return out, rows + [(kind, row)]
    m = re.fullmatch(r'year_of\((.*)\)', expr)
    if m:
        inner, rows = period_of(m.group(1), base)
        out = inner[:4]
        return out, rows + [('year_of', [out, inner])]
    m = re.fullmatch(r'last_3_months_of\((.*)\)', expr)
    if m:
        inner, rows = period_of(m.group(1), base)
        if not re.fullmatch(r'\d{4}-\d{2}', inner):
            raise ValueError(f'the last three months of {inner}')
        y, mo = (int(x) for x in inner.split('-'))
        k = y * 12 + (mo - 1) - 3
        out = f'{k // 12}-{k % 12 + 1:02d}_3m'
        return out, rows + [('last_3_months_of', [out, inner])]
    m = re.fullmatch(r'last_n_months_of\((.*), (\d+)\)', expr)
    if m:
        inner, rows = period_of(m.group(1), base)
        n = int(m.group(2))
        if not re.fullmatch(r'\d{4}-\d{2}', inner):
            raise ValueError(f'the {n} months before {inner}')
        y, mo = (int(x) for x in inner.split('-'))
        k = y * 12 + (mo - 1) - n
        out = f'{k // 12}-{k % 12 + 1:02d}_{n}m'
        return out, rows + [('last_n_months_of', [out, n, inner])]
    m = re.fullmatch(r'twelve_months_from\((.*)\)', expr)
    if m:
        inner, rows = period_of(m.group(1), base)
        if not re.fullmatch(r'\d{4}-\d{2}', inner):
            raise ValueError(f'the twelve months from {inner}')
        out = f'{inner}_12m'
        return out, rows + [('twelve_months_from', [out, inner])]
    m = re.fullmatch(r'first_month_of\((.*)\)', expr)
    if m:
        inner, rows = period_of(m.group(1), base)
        out = inner if '-' in inner else f'{inner}-01'
        return out, rows + [('first_month_of', [out, inner])]
    m = re.fullmatch(r'months_of\((.*)\)', expr)
    if m:
        inner, rows = period_of(m.group(1), base)
        mm = re.fullmatch(r'(\d{4}-\d{2})_(\d+)m', inner)
        if mm:
            y, mo = (int(x) for x in mm.group(1).split('-'))
            n = int(mm.group(2))
            months = [f'{(y * 12 + mo - 1 + j) // 12}-{(y * 12 + mo - 1 + j) % 12 + 1:02d}' for j in range(n)]
        else:
            months = [f'{inner}-{k:02d}' for k in range(1, 13)] if re.fullmatch(r'\d{4}', inner) else [inner]
        return months, rows + [('month_of', [x, inner]) for x in months]
    raise ValueError(f'the period {expr}')


def period_inputs(system, mid, infos, by_period, periods, base, raw_at, inp, case, alone=None):
    """The sentences a case states about periods: the period it is about, the
    relations between the periods its formulas read, and the value of each
    such variable at each of them (roadmap Phase 3b′, item 1)."""
    if not by_period:
        return True
    inp[f'{mid}#input.calculation_period'] = base
    wanted, rows = set(), []
    for pe in sorted(periods):
        try:
            p, rs = period_of(pe, base)
        except ValueError as e:
            case['notes'].append(f'the case cannot name {e}')
            return False
        wanted |= set(p if isinstance(p, list) else [p])
        rows += rs
    #  the first day of each period a case names: a rule the twin works out
    #  for another period reads it (openfisca's `period.start`)
    for p in sorted(wanted):
        #  (a period of months, `2015-07_3m`: the first day of its first month)
        day = p[:7] + '-01' if '_' in p else p if len(p) == 10 else p + '-01' if len(p) == 7 else p + '-01-01'
        rows.append(('first_day', [day, p]))
    by_kind = {}
    for kind, row in rows:
        by_kind.setdefault(kind, [])
        if row not in by_kind[kind]:
            by_kind[kind].append(row)
    for kind, rs in by_kind.items():
        inp[f'{mid}#period_rel.{kind}'] = rs
    case['periods'] = sorted(wanted)
    for name in sorted(by_period):
        var = system.variables.get(name)
        vals = {}
        given = raw_at.get(name)
        for p in sorted(wanted):
            if isinstance(given, dict):
                #  (only the periods the test gives it for: given_at)
                v = given_at(given, p, var)
            elif given is not None and p == base:
                v = given
            else:
                v = None
            if v is None and var is not None:
                if computed_variable(var):
                    #  a value the package computes (`rfr`), which a test
                    #  may give: given nothing, no period of it is the
                    #  model's default. A default stated there was taken for
                    #  a given value, which the rule reads first: at the
                    #  case's own period `rfr` was never computed, and at
                    #  another period the twin read 0 where the engine works
                    #  the value out (the collective income of a tax
                    #  household two years before, which the means test of
                    #  the family benefits reads). The oracle states the
                    #  engine's value at every period the case names.
                    continue
                v = default_value(var)
            if v is None:
                continue
            vals[p] = num(v)
        if vals:
            if var is not None and var.entity.key in ('person', 'individu'):
                #  a person's value: the one person's, in its own group's
                #  list (a case with no groups); in a case with groups, each
                #  member's record states its own. At the top of the case
                #  it was the family's (`le salaire net de famille_1`).
                items = inp.get(f'{mid}#relation.{alone}') if alone else None
                if isinstance(items, list) and len(items) == 1:
                    have = items[0].setdefault(f'{mid}#at_period.{name}', {})
                    for p, x in vals.items():
                        have.setdefault(p, x)
                continue
            inp[f'{mid}#at_period.{name}'] = vals
    return True


def convert_tests(system, mid, infos, files, relations=(), rels_used=(), by_period=(), periods=()):
    """The package's tests whose outputs are variables of the programme, as
    RuleSpec test cases. A case whose period is not the one its outputs are
    defined for (a year asked of a monthly variable) is kept with a note,
    and the twin marks its expectations pending."""
    cases = []
    for f in files:
        try:
            docs = yaml.safe_load(open(f))
        except Exception:
            continue
        if isinstance(docs, dict):
            docs = [docs]
        for i, t in expand_periods(docs or []):
            if not isinstance(t, dict) or 'output' not in t or t.get('reforms') or t.get('parameters') or t.get('extensions'):
                continue                       # a reform is another program
            outs = {k: v for k, v in (t.get('output') or {}).items() if k in infos and not infos[k].get('input')}
            if not outs:
                continue
            #  one subject per case: the outputs of the first output's entity
            first_ent = system.variables[list(outs)[0]].entity.key
            others = [k for k in outs if system.variables[k].entity.key != first_ent]
            outs = {k: v for k, v in outs.items() if k not in others}
            period = str(t.get('period'))
            case = {'name': re.sub(r'\W+', '_', str(t.get('name', f'case_{i}'))).strip('_')[:90],
                    'source_file': os.path.relpath(f), 'source_case': i,
                    'notes': [f'output {k} is of another entity than {list(outs)[0]}: not checked' for k in others]}
            if re.fullmatch(r'\d{4}-\d{2}', period):
                case['period'] = period
                kind = 'month'
            elif re.fullmatch(r'\d{4}', period):
                case['period'] = {'period_kind': 'tax_year', 'start': f'{period}-01-01', 'end': f'{period}-12-31'}
                kind = 'year'
                month_outs = [k for k in outs if str(system.variables[k].definition_period) == 'month']
                if month_outs and len(month_outs) == len(outs):
                    #  a year of monthly values: one month at a twelfth, when
                    #  the twelve months are equal (the oracle checks it)
                    case['period'] = f'{period}-01'
                    case['twelfths'] = True
                    kind = 'month'
            else:
                continue
            inp = {}
            raw = t.get('input') or {}
            plurals = set(GROUP_KEYS.values())
            groups = {k: v for k, v in raw.items() if isinstance(v, dict) and (k in PERSON_KEYS or k in plurals)}
            for k, pl in GROUP_KEYS.items():
                if isinstance(raw.get(k), dict):          # one group, written without its plural
                    groups[pl] = {k: raw[k]}
            people0 = next((groups[k] for k in PERSON_KEYS if groups.get(k)), {})
            out_ent0 = system.variables[list(outs)[0]].entity.key
            if people0 and out_ent0 not in ('person', 'individu'):
                #  a group the test leaves out holds all its people, as
                #  OpenFisca builds it (add_default_group_entity)
                for rel in sorted(r for r in relations if r.startswith('member_of_')):
                    pl = GROUP_KEYS.get(rel[len('member_of_'):])
                    if pl and pl not in groups:
                        groups[pl] = {'default': {'members': list(people0)}}
            #  (a group's own name may also be a variable: openfisca-france
            #  has `famille`, the family a person belongs to)
            taken = set(groups) | set(GROUP_KEYS) | set(PERSON_KEYS)
            flat = {k: v for k, v in raw.items() if k not in taken and (not isinstance(v, dict) or k in system.variables)}
            flat = {k: v for k, v in flat.items() if k in system.variables}
            ok = True
            out_ent = system.variables[list(outs)[0]].entity.key
            #  a test without groups is about one person, the one member of
            #  each group: a person's value stated at the top is that member's
            alone = f'member_of_{out_ent}' if not groups and out_ent not in ('person', 'individu') else None
            for k, v0 in flat.items():
                v = stated(system, k, v0, period, case)
                if v is NOT_STATED:
                    continue
                if isinstance(v, (list, dict)):
                    ok = False
                    case['notes'].append(f'input {k} is not one value')
                    continue
                if alone and system.variables[k].entity.key in ('person', 'individu'):
                    if alone in relations:
                        item = inp.setdefault(f'{mid}#relation.{alone}', [{}])[0]
                        if k in by_period:
                            item[f'{mid}#at_period.{k}'] = {str(pk): num(x) for pk, x in v0.items()} \
                                if isinstance(v0, dict) else {str(period): num(v)}
                        else:
                            item[f'{mid}#input.{k}'] = v
                        case.setdefault('members', {})[alone] = ['person']
                    continue
                if k in by_period:
                    inp[f'{mid}#at_period.{k}'] = {str(period): v}     # read for each period: with its period
                    continue
                inp[f'{mid}#input.{k}'] = v
            if alone and alone in relations and f'{mid}#relation.{alone}' not in inp:
                inp[f'{mid}#relation.{alone}'] = [{}]
                case.setdefault('members', {})[alone] = ['person']
            if alone:
                #  the one person is a member of each of the other groups too
                for rel in sorted(r for r in relations if r.startswith('member_of_') and r != alone):
                    inp.setdefault(f'{mid}#relation.{rel}', [{}])
                    case.setdefault('members', {})[rel] = ['person']
            if out_ent in ('person', 'individu'):
                #  a group a person's test leaves out: the person is its one
                #  member (as OpenFisca builds the case)
                for rel in sorted(r for r in relations if r.startswith('member_of_')):
                    g = rel[len('member_of_'):]
                    if GROUP_KEYS.get(g) not in groups:
                        inp.setdefault(f'{mid}#relation.{rel}', [{}])
                        case.setdefault('members', {})[rel] = ['person']
            #  a person the case puts in a group without saying in which role
            #  (a test stated flat): the role OpenFisca itself gives it
            for rk0 in [k for k in inp if f'{mid}#relation.member_of_' in k]:
                items0 = inp[rk0]
                grp0 = rk0.split('#relation.member_of_')[1]
                if not (isinstance(items0, list) and len(items0) == 1) or GROUP_KEYS.get(grp0) in groups:
                    continue
                held = default_roles(system, grp0)
                for rn, (rg, rk, _pl) in ROLES.items():
                    if rg == grp0 and rn in rels_used and f'{mid}#input.{rn}' not in items0[0]:
                        items0[0][f'{mid}#input.{rn}'] = rk in held
            people = next((groups[k] for k in PERSON_KEYS if groups.get(k)), {})
            if out_ent in ('person', 'individu') and len(people) == 1:
                #  a case about one person: that person's facts are the case's own
                for k, v0 in (list(people.values())[0] or {}).items():
                    if k in system.variables:
                        if k in by_period:
                            #  (read for each period: with its periods)
                            inp[f'{mid}#at_period.{k}'] = {str(pk): num(x) for pk, x in v0.items()} \
                                if isinstance(v0, dict) else {str(period): num(v0)}
                            continue
                        v = stated(system, k, v0, period, case)
                        if v is not NOT_STATED and not isinstance(v, (list, dict)):
                            inp[f'{mid}#input.{k}'] = v
            for gk, gv in groups.items():
                if gk in PERSON_KEYS:
                    continue
                ent = {v: k for k, v in GROUP_KEYS.items()}[gk]
                #  several groups of one kind (two tax households in a family's
                #  case): each person's item says which group it is in, and
                #  each group's own values are stated of it (`groups.`), the
                #  twin naming them foyer_fiscal_1, foyer_fiscal_2. Several
                #  groups of the kind the case asks about are still outside
                #  the twin's reach: its question names one.
                if len(gv) != 1 and (len(gv) == 0 or ent == out_ent):
                    ok = False
                    case['notes'].append(f'{len(gv)} {gk}')
                    continue
                several = len(gv) > 1
                rel = f'member_of_{ent}'
                all_members, item_of, group_inputs = [], {}, []
                for gj, g in enumerate(gv.values(), 1):
                    ms = g.get('members') or []
                    members = [ms] if isinstance(ms, str) else list(ms)      # `members: person`, one name
                    for role in ROLE_KEYS:
                        if role == 'members':
                            continue
                        r = g.get(role) or []
                        members += [m for m in (r if isinstance(r, list) else [r]) if m not in members]
                    ginp = {}
                    for k, v0 in g.items():
                        if k in ROLE_KEYS:
                            continue
                        v = stated(system, k, v0, period, case)
                        if v is NOT_STATED:
                            continue
                        if isinstance(v, (list, dict)):
                            ok = False
                            case['notes'].append(f'input {k} is not one value')
                            continue
                        if several:
                            ginp[f'{mid}#input.{k}'] = v
                        else:
                            inp[f'{mid}#input.{k}'] = v
                    group_inputs.append(ginp)
                    if not (members and people and rel in relations):
                        continue
                    #  every group lists the case's people in one order, the
                    #  order the case names them, and each item says which
                    #  person it is: a household that lists its children
                    #  before the reference person otherwise gave each
                    #  person the other's age (openfisca-france's housing
                    #  allowance)
                    order = list(people)
                    for m in members:
                        if m in item_of:
                            continue
                        pv = people.get(m, {}) or {}
                        item = {'id': order.index(m) + 1} if m in order else {}
                        if several:
                            item['group'] = gj
                        for rn, (rg, rk, rpl) in ROLES.items():
                            if rg == ent and rn in rels_used:
                                rl = g.get(rpl) or []
                                rl = rl if isinstance(rl, list) else [rl]
                                place = SUBROLE_PLACE.get((rg, rk))
                                if g.get(rk) is not None:
                                    #  the subrole named in the case itself
                                    rk_l = g[rk] if isinstance(g[rk], list) else [g[rk]]
                                    item[f'{mid}#input.{rn}'] = m in rk_l
                                elif place is not None:
                                    item[f'{mid}#input.{rn}'] = len(rl) > place and rl[place] == m
                                else:
                                    item[f'{mid}#input.{rn}'] = m in rl
                        for k, v0 in pv.items():
                            if k in by_period:
                                #  a person's value the twin reads for each
                                #  period: stated with its periods (the
                                #  RSA's salaries of the last three months),
                                #  never without one
                                item[f'{mid}#at_period.{k}'] = \
                                    {str(pk): num(x) for pk, x in v0.items()} if isinstance(v0, dict) \
                                    else {str(period): num(v0)}
                                continue
                            v = stated(system, k, v0, period, case)
                            if v is not NOT_STATED and not isinstance(v, (list, dict)):
                                item[f'{mid}#input.{k}'] = v
                        item_of[m] = item
                        all_members.append(m)
                if several and any(group_inputs):
                    inp[f'{mid}#groups.{rel}'] = group_inputs
                if all_members:
                    order = list(people)
                    all_members.sort(key=lambda m: order.index(m) if m in order else len(order))
                    inp[f'{mid}#relation.{rel}'] = [item_of[m] for m in all_members]
                    case.setdefault('members', {})[rel] = list(all_members)
                    if several:
                        case.setdefault('groups', {})[rel] = len(gv)
            outp = {}
            for k, v in outs.items():
                v = num(at_period(v, period))
                if isinstance(v, (list, dict)):
                    case['notes'].append(f'output {k} is one value per member')
                    continue
                if case.get('twelfths') and isinstance(v, (int, float)) and not isinstance(v, bool):
                    v = v / 12
                vp = system.variables[k].definition_period
                if str(vp) != kind:
                    case['notes'].append(f'{k} is defined for a {vp}, the test asks for a {kind}')
                    ok = False
                outp[f'{mid}#{k}'] = v
            if not outp:
                continue
            #  an input the test leaves out has the variable's default value
            qent = system.variables[list(outs)[0]].entity.key
            for name, inf in infos.items():
                if not inf.get('input') or inf.get('outside') or inf.get('default_rule') or name in by_period:
                    continue                  # (a computed variable outside the programme: the oracle states it;
                                              #  a default written as a rule: the case states only what it gives;
                                              #  a value stated for each period: period_inputs/9 states it, with
                                              #  the period among its places — stating it without one asked for a
                                              #  template of two places that the twin does not declare, which was
                                              #  96 of the income tax's writer errors)
                dv = default_value(system.variables[name])
                if dv is None:
                    continue
                key = f'{mid}#input.{name}'
                if inf['entity'] == qent and key not in inp:
                    inp[key] = dv
                elif inf['entity'] != 'person' and key not in inp:
                    inp[key] = dv          # (another group's: stated where the rules read it)
                elif inf['entity'] == 'person':
                    for rk, items in list(inp.items()):
                        if isinstance(items, list):
                            for it in items:
                                it.setdefault(key, dv)
            if alone:
                #  (the one person's facts are in its own group's list: the
                #  other groups name it, without stating them again — except
                #  the roles it holds in each of them, which no other list
                #  carries. Wiping those left the means test of the family
                #  benefits with no declarant of the tax household, and it
                #  answered 0 of a property income of 20,000 €.)
                for rel in sorted(r for r in relations if r.startswith('member_of_') and r != alone):
                    if f'{mid}#relation.{rel}' in inp:
                        items0 = inp[f'{mid}#relation.{rel}']
                        kept = {}
                        if isinstance(items0, list) and len(items0) == 1 and isinstance(items0[0], dict):
                            kept = {k: v for k, v in items0[0].items()
                                    if str(k).split('#input.')[-1] in ROLES}
                        inp[f'{mid}#relation.{rel}'] = [kept]
            #  the periods the case names, and the values of each of them
            raw_at = {}
            for k, v0 in list(raw.items()):
                if k in by_period:
                    raw_at[k] = v0
            for gv in groups.values():
                for g in (gv or {}).values():
                    for k, v0 in (g or {}).items():
                        if k in by_period:
                            raw_at.setdefault(k, v0)
            if not period_inputs(system, mid, infos, by_period, periods, period, raw_at, inp, case, alone):
                ok = False
            case['input'] = inp
            case['output'] = outp
            case['translatable'] = ok
            if t.get('absolute_error_margin') is not None:
                case['absolute_error_margin'] = t['absolute_error_margin']
            if t.get('relative_error_margin') is not None:
                case['relative_error_margin'] = t['relative_error_margin']
            cases.append(case)
    return cases


def test_window(files):
    """The years the tests ask about, from the first day of the first to the
    last day of the last: the parameter values a twin keeps."""
    years = set()
    for f in files:
        try:
            docs = yaml.safe_load(open(f)) or []
            for _, t in expand_periods(docs if isinstance(docs, list) else [docs]):     # (a test's other periods too)
                m = re.match(r'(\d{4})', str(t.get('period', '')))
                if m:
                    years.add(int(m.group(1)))
        except Exception:
            pass
    if not years:
        return None
    return (f'{min(years)}-01-01', f'{max(years)}-12-31')


def parse_programmes(argv):
    """<dialect> <out> then, for each programme, --programme NAME --roots a,b [--tests PATH]..."""
    dialect, out = argv[0], argv[1]
    progs, cur = [], None
    i = 2
    while i < len(argv):
        a = argv[i]
        if a == '--programme':
            cur = {'name': argv[i + 1], 'roots': [], 'tests': [], 'within': []}
            progs.append(cur)
        elif a == '--within':
            cur['within'] = argv[i + 1].split(',')
        elif a == '--roots':
            cur['roots'] = argv[i + 1].split(',')
        elif a == '--tests':
            p = argv[i + 1]
            if os.path.isdir(p):
                for r, _, fs in os.walk(p):
                    cur['tests'] += [os.path.join(r, f) for f in sorted(fs) if f.endswith('.yaml')]
            else:
                cur['tests'].append(p)
        i += 2
    return dialect, out, progs


def turn_inputs(inp, mid, turned):
    """A case's facts with each turned input stated the other way round
    (`declines_snap: true` where the test says `takes_up_snap: false`); a
    "yes", the default, is left unstated."""
    for k in list(inp):
        if isinstance(inp[k], list):
            for it in inp[k]:
                if isinstance(it, dict):
                    turn_inputs(it, mid, turned)
            continue
        n = k.split('#input.', 1)[1] if '#input.' in k else None
        if n in turned:
            v = inp.pop(k)
            if v is False or v == 'false' or v == 0:
                inp[f'{mid}#input.{turned[n]}'] = True


def turned_name(v):
    """The name of an input turned around (takes_up_snap → declines_snap).
    A name with no English verb to turn is prefixed with the negative word of
    the twin's own language: `rempli_obligation_scolaire` becomes
    `non_rempli_obligation_scolaire` in a French twin, which reads *l'individu
    remplit la condition non rempli obligation scolaire*, where `is_not_…`
    had left English in a French sentence."""
    for a, b in (('takes_up_', 'declines_'), ('would_claim_', 'would_not_claim_'), ('would_file_', 'would_not_file_'),
                 ('would_', 'would_not_'), ('has_', 'has_no_'), ('is_', 'is_not_'), ('meets_', 'does_not_meet_')):
        if v.startswith(a):
            return b + v[len(a):]
    return WORDS.get('not', 'is_not') + '_' + v


def turn_defaults(system, module, infos):
    """The inputs whose default is "yes" (take-up, filing), turned around so
    that their default is the one a scenario leaves unstated: in Logical
    English what is not stated is false, so a scenario that forgot
    `takes_up_snap_if_eligible` would silently answer 0; *a spm unit declines
    snap if eligible* is false when not stated, as the package's default is
    (review finding 1; roadmap §8, Phase 3b work left, the constraints (b)).
    {name: turned name}; the module's formulas read `not` the turned input."""
    turned = {}
    texts = [v['formula'] for r in module['rules'] for v in r.get('versions', []) if isinstance(v.get('formula'), str)]
    for n, i in infos.items():
        if not i.get('input') or i.get('outside') or n not in system.variables:
            continue
        var = system.variables[n]
        if var.value_type is not bool or var.default_value is not True:
            continue
        pat = re.compile(r'(?<![A-Za-z0-9_.])(member_of_[a-z_]+\.)?' + re.escape(n) + r'(?![A-Za-z0-9_])')
        if any(re.search(r'(count_where|sum_where|rank_in_group)\([^()]*\b' + re.escape(n) + r'\b', t) for t in texts):
            continue                  # (read as the name of a test over members: kept as it is)
        turned[n] = turned_name(n)
        for r in module['rules']:
            for v in r.get('versions', []):
                if isinstance(v.get('formula'), str):
                    v['formula'] = pat.sub(lambda m: f'(not {m.group(1) or ""}{turned[n]})', v['formula'])
        module['rules'].insert(0, {'name': turned[n], 'kind': 'input', 'entity': camel(var.entity.key), 'dtype': 'Judgment',
                                   'source': WORDS['turned'].format(l=var.label or n, n=n)})
    return turned


def write_programme(system, dialect, out, prog):
    programme, roots, tests = prog['name'], prog['roots'], prog['tests']
    module, infos, pfiles, by_period, periods = extract_with(system, dialect, programme, roots,
                                                             prog.get('within', []), test_window(tests))
    turned = turn_defaults(system, module, infos)
    window = test_window(tests)
    if window:
        module['module']['covers'] = list(window)       # the dates the parameters kept cover
    mid = f'of:{programme}'
    d = os.path.join(out, 'of')
    os.makedirs(d, exist_ok=True)

    class Dumper(yaml.SafeDumper):
        def ignore_aliases(self, data):       # each case written whole: the YAML readers want no anchors
            return True

    def str_rep(dumper, s):
        return dumper.represent_scalar('tag:yaml.org,2002:str', s, style='|' if '\n' in s else None)
    Dumper.add_representer(str, str_rep)
    rels = {r['name'] for r in module['rules'] if r['kind'] == 'data_relation'}
    roles = {r['name'] for r in module['rules'] if r['kind'] == 'input'}
    cases = convert_tests(system, mid, infos, tests, rels, roles, by_period, periods)
    for c in cases:
        turn_inputs(c.get('input') or {}, mid, turned)
    #  the tests are read before the module is written: they say which of the
    #  variables the programme computes a case may also give
    mark_overridable(module, cases, mid)
    with open(os.path.join(d, f'{programme}.yaml'), 'w') as f:
        yaml.dump(module, f, Dumper=Dumper, sort_keys=False, allow_unicode=True, width=1000)
    #  the tables by code a programme reads, as CSV files the twin loads
    td = os.path.join(d, f'{programme}.tables')
    if os.path.isdir(td):
        shutil.rmtree(td)
    for r in module['rules']:
        if r.get('table_file') and r['name'] in LOOKUPS:
            os.makedirs(td, exist_ok=True)
            rows, default = LOOKUPS[r['name']]
            with open(os.path.join(td, r['table_file']), 'w', newline='') as f:
                w = csv.writer(f, lineterminator="\n")      # (LF, as the committed tables are)
                w.writerow(['code', 'valeur' if dialect == 'france' else 'value'])   # the twin's own column names
                w.writerows(rows)
                w.writerow(['-', default])      # any other code: the default, last (first match)
    with open(os.path.join(d, f'{programme}.test.yaml'), 'w') as f:
        yaml.dump([{k: c[k] for k in ('name', 'period', 'input', 'output') if k in c} for c in cases], f,
                  Dumper=Dumper, sort_keys=False, allow_unicode=True, width=1000)
    with open(os.path.join(d, f'{programme}.json'), 'w') as f:
        json.dump({'dialect': dialect, 'package': DIALECTS[dialect][0], 'roots': roots, 'variables': infos,
                   'by_period': by_period, 'periods': periods, 'parameter_files': pfiles, 'test_files': sorted({os.path.abspath(c['source_file']) for c in cases}),
                   'cases': [{k: c[k] for k in c if k not in ('input', 'output')} for c in cases]},
                  f, indent=1, default=str)
    nres = sum(1 for i in infos.values() if i.get('residue'))
    ninp = sum(1 for i in infos.values() if i.get('input'))
    print(f'{programme}: {len(infos)} variables ({len(infos) - nres - ninp} translated, {nres} residue, {ninp} inputs), '
          f'{len([r for r in module["rules"] if r["kind"] == "parameter"])} parameters, {len(cases)} test cases '
          f'({sum(1 for c in cases if c["translatable"])} in the variable\'s own period)', flush=True)


def main(argv):
    dialect, out, progs = parse_programmes(argv)
    system = load_system(dialect)
    for prog in progs:
        write_programme(system, dialect, out, prog)


if __name__ == '__main__':
    main(sys.argv[1:])

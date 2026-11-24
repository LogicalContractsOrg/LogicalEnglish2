#!/usr/bin/env python3
"""rosetta2json — deterministic Rune DSL (.rosetta) -> JSON converter for CDMlog.

Replaces the LLM-based conversion described in examples/CLAUDE.md with a
reproducible parser. It emits, per namespace, a single <namespace>.json file
with the same JSON contract the Prolog side (cdm.pl loadSchema/updateComponents)
consumes:

  namespace, provenance, originalFiles, imports, bodies, corpora, segments,
  metaTypes, annotations (annotation definitions), synonyms (synonym sources),
  rootDeclarations (isEvent/isProduct), typeAliases, types, choices, enums,
  functions.

Design notes:
  - Expressions (condition bodies, set/add/alias right-hand sides, typeAlias
    definitions) are captured verbatim, preserving the original indentation and
    newlines, as required by examples/CLAUDE.md. Because expressions stay text,
    no expression grammar is needed and the parser is stdlib-only.
  - Docstrings <"..."> may span lines; the lexer folds them into one logical
    line, keeping interior newlines in the description text.
  - Annotations [ ... ] may span lines (e.g. docReference provisions); the
    parser completes unbalanced brackets across lines.

Usage:
  python3 rosetta2json.py SRC_DIR OUT_DIR [--only NAMESPACE] [--namespaces-json]
"""

import argparse
import json
import re
import sys
from pathlib import Path

VERSION = "0.2.0"
PROVENANCE = f"rosetta2json {VERSION}"

# ---------------------------------------------------------------- lexer

def logical_lines(text):
    """Split text into logical lines: newlines inside <"..."> docstrings are
    kept within a single logical line (as literal newlines in the line text)."""
    lines = []
    cur = []
    i, n = 0, len(text)
    in_doc = False
    in_str = False
    while i < n:
        c = text[i]
        if in_doc:
            if c == '"' and i + 1 < n and text[i + 1] == '>':
                cur.append('">')
                i += 2
                in_doc = False
                continue
            cur.append(c)
            i += 1
            continue
        if in_str:
            if c == '\\' and i + 1 < n:
                cur.append(text[i:i + 2])
                i += 2
                continue
            if c == '"':
                in_str = False
            if c == '\n':  # unterminated string: recover at end of line
                in_str = False
                lines.append(''.join(cur))
                cur = []
                i += 1
                continue
            cur.append(c)
            i += 1
            continue
        if c == '<' and text[i:i + 2] == '<"':
            in_doc = True
            cur.append('<"')
            i += 2
            continue
        if c == '"':
            in_str = True
            cur.append(c)
            i += 1
            continue
        if c == '/' and text[i:i + 2] == '/*':  # block comment
            end = text.find('*/', i + 2)
            i = (end + 2) if end != -1 else n
            continue
        if c == '\n':
            lines.append(''.join(cur))
            cur = []
            i += 1
            continue
        cur.append(c)
        i += 1
    if cur:
        lines.append(''.join(cur))
    return lines


def indent_of(line):
    line = line.expandtabs(4)
    return len(line) - len(line.lstrip(' '))


def bracket_balance(s):
    """Bracket balance of s, ignoring brackets inside "..." strings and <"..."> docstrings."""
    bal = 0
    i, n = 0, len(s)
    in_doc = in_str = False
    while i < n:
        c = s[i]
        if in_doc:
            if c == '"' and i + 1 < n and s[i + 1] == '>':
                in_doc = False
                i += 2
                continue
        elif in_str:
            if c == '\\':
                i += 2
                continue
            if c == '"':
                in_str = False
        elif c == '<' and s[i:i + 2] == '<"':
            in_doc = True
            i += 2
            continue
        elif c == '"':
            in_str = True
        elif c == '[':
            bal += 1
        elif c == ']':
            bal -= 1
        i += 1
    return bal


DOC_START_RE = re.compile(r'^<"(.*?)">\s*', re.S)


def doc_at_start(s):
    """If s (lstripped) starts with a docstring, return (doc, rest); else (None, s)."""
    t = s.lstrip()
    m = DOC_START_RE.match(t)
    if m:
        return m.group(1), t[m.end():]
    return None, s


def extract_doc(s):
    """Extract the first docstring anywhere in s. Returns (s_without_doc, doc|None)."""
    m = re.search(r'<"(.*?)">', s, re.S)
    if not m:
        return s, None
    return (s[:m.start()] + ' ' + s[m.end():]).strip(), m.group(1)


def tokenize(s):
    """Tokens of an annotation/header payload: bare words and quoted strings."""
    tokens = []
    for m in re.finditer(r'"((?:[^"\\]|\\.)*)"|(\S+)', s):
        if m.group(2) is not None:
            tokens.append(('word', m.group(2)))
        else:
            tokens.append(('str', m.group(1)))
    return tokens


# ---------------------------------------------------------------- annotations

def parse_annotation(text):
    """Parse one [ ... ] annotation body (without the outer brackets).
    Returns (kind, payload)."""
    text = text.strip()
    tokens = tokenize(text)
    if not tokens:
        return None, None
    kind = tokens[0][1]
    rest = tokens[1:]
    target = None
    if kind in ('docReference', 'label', 'ruleReference') and rest and rest[0] == ('word', 'for'):
        # [label for leg1 -> notionalAmount "..."]: the annotation is about a
        # path below the attribute it is written on
        path = [rest[1][1]] if len(rest) > 1 else []
        i = 2
        while i + 1 < len(rest) and rest[i] == ('word', '->'):
            path.append(rest[i + 1][1])
            i += 2
        target = ' -> '.join(path)
        rest = rest[i:]
    if kind in ('label', 'ruleReference'):
        payload = {'value': rest[0][1] if rest else None}
        if target is not None:
            payload = {'for': target, **payload}
        return kind, payload
    if kind == 'metadata':
        payload = {}
        for tt, tv in rest:
            if tt == 'word':
                payload[tv] = True
            else:  # e.g. [metadata address "pointsTo"=...]
                payload.setdefault('_raw', []).append(tv)
        return kind, payload
    if kind in ('docReference', 'synonym'):
        # leading bare words (not key of a key-"value" pair) -> source;
        # then (word "string") pairs -> fields
        payload = {}
        source_words = []
        i = 0
        while i < len(rest):
            tt, tv = rest[i]
            if tt == 'word' and i + 1 < len(rest) and rest[i + 1][0] == 'str':
                payload[tv] = rest[i + 1][1]
                i += 2
            elif tt == 'word':
                source_words.append(tv)
                i += 1
            else:  # stray string
                payload.setdefault('_extra', []).append(tv)
                i += 1
        if source_words:
            payload = {'source': ' '.join(source_words), **payload}
        if target is not None:
            payload = {'for': target, **payload}
        return kind, payload
    # generic annotation: [codeImplementation], [creation WorkflowStep], [rootType]...
    return kind, [tv for _, tv in rest]


def split_bracket_groups(s):
    """Split '[a][b "x"] tail' into (['a', 'b "x"'], tail). Respects strings."""
    groups = []
    i, n = 0, len(s)
    tail = []
    while i < n:
        c = s[i]
        if c == '[':
            depth = 1
            j = i + 1
            in_str = False
            while j < n and depth:
                cj = s[j]
                if in_str:
                    if cj == '\\':
                        j += 1
                    elif cj == '"':
                        in_str = False
                elif cj == '"':
                    in_str = True
                elif cj == '[':
                    depth += 1
                elif cj == ']':
                    depth -= 1
                j += 1
            groups.append(s[i + 1:j - 1])
            i = j
        else:
            tail.append(c)
            i += 1
    return groups, ''.join(tail).strip()


class AnnotationSet:
    """Accumulates annotations for one target (type, attribute, enum value, func)."""

    def __init__(self):
        self.metadata = {}
        self.annotations = {}

    def add(self, kind, payload):
        if kind is None:
            return
        if kind == 'metadata':
            self.metadata.update(payload)
        elif kind in ('docReference', 'synonym', 'label', 'ruleReference'):
            self.annotations.setdefault(kind, []).append(payload)
        else:
            self.annotations[kind] = payload

    def apply(self, obj):
        if self.metadata:
            obj['metadata'] = self.metadata
        if self.annotations:
            obj['annotations'] = self.annotations


# ---------------------------------------------------------------- constructs

ATTR_RE = re.compile(
    r'^(override\s+)?(\w+)\s+([\w.]+(?:\([^)]*\))?)\s*\((\d+)\.\.(\d+|\*)\)\s*(.*)$', re.S)


def parse_attribute_line(line):
    """Parse '[override] name Type (m..n) <"doc"> [ann]...'; returns
    (name, attr_dict, annset) or None if the line is not an attribute."""
    m = ATTR_RE.match(line.strip())
    if not m:
        return None
    override, name, typ, lo, hi, rest = m.groups()
    attr = {'type': typ, 'cardinality': f'{lo}..{hi}'}
    if override:
        attr['override'] = True
    doc, rest = doc_at_start(rest)
    if doc is not None:
        attr['description'] = doc
    annset = AnnotationSet()
    groups, tail = split_bracket_groups(rest)
    for g in groups:
        annset.add(*parse_annotation(g))
    return name, attr, annset


def leading_annotations(expr):
    """Split the annotations a condition may start with ([docReference ...],
    Rune's `References`) from its expression. Returns (AnnotationSet or None,
    expression). Only leading groups: a list literal later on is expression."""
    anns = None
    rest = expr.lstrip()
    while rest.startswith('['):
        depth, j, in_str = 0, 0, False
        while j < len(rest):
            c = rest[j]
            if in_str:
                if c == '\\':
                    j += 1
                elif c == '"':
                    in_str = False
            elif c == '"':
                in_str = True
            elif c == '[':
                depth += 1
            elif c == ']':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        group = rest[1:j]
        kind = group.split(None, 1)[0] if group.split() else ''
        if kind not in ('docReference', 'regulatoryReference', 'label', 'ruleReference',
                        'deprecated', 'codeImplementation', 'suppressWarnings'):
            break  # a list literal: [A, B] contains x
        anns = anns or AnnotationSet()
        anns.add(*parse_annotation(group))
        rest = rest[j + 1:].lstrip()
    return anns, (rest if anns else expr)


class Block:
    """One top-level construct: header logical line + body logical lines."""

    def __init__(self, header, body):
        self.header = header
        self.body = body  # list of logical lines (indent > 0), blanks included


TOP_KEYWORDS = {'namespace', 'version', 'import', 'metaType', 'body', 'corpus',
                'segment', 'annotation', 'synonym', 'isEvent', 'isProduct',
                'type', 'choice', 'enum', 'typeAlias', 'func',
                'report', 'reporting', 'eligibility', 'rule'}


def is_top_level(line):
    """Top-level construct header: column 0, or slightly mis-indented (the
    corpus contains e.g. ' func Create_Bicycle:') but starting with a keyword."""
    ind = indent_of(line)
    first = line.strip().split(None, 1)[0].rstrip(':') if line.strip() else ''
    if ind == 0:
        # a line of a multi-line provision "..." may start at column 0 (DRR's
        # UK EMIR file): only a keyword or a brace opens a construct; a
        # comment at column 0 inside a rule's body does not end it
        return first in TOP_KEYWORDS or first.startswith(('{', '}')) \
            or first == 'schema'
    if ind < 4:
        return first in TOP_KEYWORDS
    return False


def blocks_of(lines):
    """Group logical lines into top-level blocks."""
    blocks = []
    cur_header = None
    cur_body = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            if cur_header is not None:
                cur_body.append(line)
            i += 1
            continue
        if is_top_level(line):
            stripped = line.strip()
            if stripped.startswith('{') and cur_header is not None:
                # brace block belongs to previous construct (synonym source)
                cur_body.append(line)
                depth = bracket_depth_braces(line)
                while depth > 0 and i + 1 < len(lines):
                    i += 1
                    cur_body.append(lines[i])
                    depth += bracket_depth_braces(lines[i])
                i += 1
                continue
            if cur_header is not None:
                blocks.append(Block(cur_header, cur_body))
            cur_header = line
            cur_body = []
        else:
            if cur_header is not None:
                cur_body.append(line)
        i += 1
    if cur_header is not None:
        blocks.append(Block(cur_header, cur_body))
    return blocks


def bracket_depth_braces(s):
    bal = 0
    in_str = False
    i = 0
    while i < len(s):
        c = s[i]
        if in_str:
            if c == '\\':
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == '{':
            bal += 1
        elif c == '}':
            bal -= 1
        i += 1
    return bal


def complete_brackets(body, i):
    """Starting at body[i] (a line beginning with '['), consume lines until
    bracket balance closes. Returns (full_text, next_index)."""
    text = body[i]
    i += 1
    # the balance of the whole text so far: a provision "..." may span lines,
    # and a bracket inside it does not count
    while bracket_balance(text) > 0 and i < len(body):
        text += '\n' + body[i]
        i += 1
    return text, i


def strip_line_comment(line):
    """Remove a // comment (outside quoted strings, "..." or '...') from a line."""
    in_str = False
    i = 0
    while i < len(line):
        c = line[i]
        if in_str:
            if c == '\\':
                i += 1
            elif c == in_str:
                in_str = False
        elif c in '"\'':
            in_str = c
        elif c == '/' and line[i:i + 2] == '//':
            return line[:i].rstrip()
        i += 1
    return line


def open_string(text):
    """Whether text ends inside a "..." string (docstrings <"..."> aside)."""
    in_str = False
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if in_str:
            if c == '\\':
                i += 1
            elif c == '"':
                in_str = False
        elif c == '<' and text[i:i + 2] == '<"':
            end = text.find('">', i + 2)
            i = n if end == -1 else end + 2
            continue
        elif c == '"':
            in_str = True
        i += 1
    return in_str


def capture_expression(header_rest, body, i, clause_indent):
    """Capture a verbatim expression: the remainder of the clause header line
    plus all following lines indented deeper than clause_indent. // comments
    are removed (the JSON keeps expression text, not commentary).
    Returns (expression, next_index)."""
    parts = []
    first = strip_line_comment(header_rest).strip()
    if first:
        parts.append(first)
    while i < len(body):
        line = body[i]
        if not line.strip():
            parts.append('')
            i += 1
            continue
        if open_string('\n'.join(parts)):
            # a line of a provision "..." that spans lines: "//" is text here
            parts.append(line)
            i += 1
            continue
        if not strip_line_comment(line).strip():
            i += 1  # a comment line, even at column 0
            continue
        if indent_of(line) <= clause_indent and bracket_balance('\n'.join(parts)) <= 0:
            break  # (inside an open [docReference ... "provision"], keep going)
        line = strip_line_comment(line)
        if line.strip():
            parts.append(line)
        i += 1
    # trim trailing blanks
    while parts and parts[-1] == '':
        parts.pop()
    if not parts:
        return '', i
    if not parts[0]:
        parts = parts[1:]
    # first line carries no indentation; continuation lines keep the original
    expr = parts[0].strip() if parts else ''
    if len(parts) > 1:
        expr = '\n'.join([parts[0].strip()] + parts[1:])
    return expr.rstrip(), i


HEADER_RE = re.compile(r'^(\w[\w-]*)\s+([\w.]+(?:\([^)]*\))?)?\s*(extends\s+([\w.]+))?\s*(:)?\s*(.*)$', re.S)


def parse_construct_header(header):
    """Parse 'type Name extends Super: <"doc">' style headers.
    Returns (keyword, name, extends, doc)."""
    stripped = header.strip()
    doc = None
    m = re.match(r'^(\w[\w-]*)\s+([\w.]+(?:\([^)]*\))?)\s*(?:extends\s+([\w.]+))?\s*:?\s*(.*)$',
                 stripped, re.S)
    if not m:
        return None, None, None, None
    kw, name, ext, rest = m.groups()
    d, rest = doc_at_start(rest)
    if d is not None:
        doc = d
    return kw, name, ext, doc


# ------------------------------------------------------- component parsers

def parse_type(block, out):
    _, name, ext, doc = parse_construct_header(block.header)
    obj = {}
    if doc is not None:
        obj['description'] = doc
    if ext:
        obj['extends'] = ext
    type_anns = AnnotationSet()
    attributes = {}
    conditions = {}
    condition_docs = {}
    condition_anns = {}
    last_attr_annset = None
    body = block.body
    i = 0
    seen_attr = False
    while i < len(body):
        line = body[i]
        s = line.strip()
        if not s:
            i += 1
            continue
        if s.startswith('//'):
            i += 1
            continue
        if s.startswith('['):
            text, i = complete_brackets(body, i)
            groups, _ = split_bracket_groups(text.strip())
            target = last_attr_annset if seen_attr else type_anns
            for g in groups:
                target.add(*parse_annotation(g))
            continue
        parsed = parse_attribute_line(line)
        if parsed:  # try attribute first: 'condition' can be an attribute name
            aname, attr, annset = parsed
            attributes[aname] = attr
            last_attr_annset = _DeferredApply(attr, annset)
            seen_attr = True
            i += 1
            continue
        m = re.match(r'^condition\s*([\w-]*)\s*:\s*(.*)$', s, re.S)
        if m:
            cname, rest = m.group(1), m.group(2)
            if not cname:  # anonymous condition, as in the LLM-made files
                cname = 'condition' if 'condition' not in conditions \
                    else f'condition{len(conditions) + 1}'
            cdoc, rest = doc_at_start(rest)
            expr, i2 = capture_expression(rest, body, i + 1, indent_of(line))
            canns, expr = leading_annotations(expr)
            conditions[cname] = expr
            if canns:
                cobj = {}
                canns.apply(cobj)
                condition_anns[cname] = cobj['annotations']
            if cdoc is not None:
                condition_docs[cname] = cdoc
            i = i2
            continue
        # unrecognized line inside type: keep parsing (defensive)
        i += 1
    type_anns.apply(obj)
    if attributes:
        obj['attributes'] = attributes
    if conditions:
        obj['conditions'] = conditions
    if condition_docs:
        obj['conditionDescriptions'] = condition_docs
    if condition_anns:
        obj['conditionAnnotations'] = condition_anns
    out.setdefault('types', {})[name] = obj


class _DeferredApply(AnnotationSet):
    """AnnotationSet bound to an attribute dict: applies on every add."""

    def __init__(self, attr, initial):
        super().__init__()
        self.attr = attr
        self.metadata = initial.metadata
        self.annotations = initial.annotations
        self.apply(attr)

    def add(self, kind, payload):
        super().add(kind, payload)
        self.apply(self.attr)


def parse_choice(block, out):
    _, name, _, doc = parse_construct_header(block.header)
    obj = {}
    if doc is not None:
        obj['description'] = doc
    options = []
    option_annotations = {}
    body = block.body
    i = 0
    while i < len(body):
        line = body[i]
        s = line.strip()
        if not s or s.startswith('//'):
            i += 1
            continue
        if s.startswith('['):
            # option-level annotation, e.g. [metadata location]; kept out of
            # options so the Prolog loader's option shapes stay untouched
            text, i = complete_brackets(body, i)
            if options:
                last = options[-1]
                oname = last if isinstance(last, str) else last['value']
                annset = AnnotationSet()
                groups, _ = split_bracket_groups(text.strip())
                for g in groups:
                    annset.add(*parse_annotation(g))
                entry = {}
                annset.apply(entry)
                option_annotations[oname] = entry
            continue
        rest, odoc = extract_doc(s)
        oname = rest.strip()
        if oname:
            options.append({'value': oname, 'description': odoc}
                           if odoc is not None else oname)
        i += 1
    obj['options'] = options
    if option_annotations:
        obj['optionAnnotations'] = option_annotations
    out.setdefault('choices', {})[name] = obj


ENUM_VALUE_RE = re.compile(r'^([\w]+)\s*(?:displayName\s+"((?:[^"\\]|\\.)*)")?\s*(.*)$', re.S)


def parse_enum(block, out):
    _, name, ext, doc = parse_construct_header(block.header)
    obj = {}
    if doc is not None:
        obj['description'] = doc
    if ext:
        obj['extends'] = ext
    values = []
    last = None  # last value as dict, for annotations
    body = block.body
    i = 0
    while i < len(body):
        line = body[i]
        s = line.strip()
        if not s or s.startswith('//'):
            i += 1
            continue
        if s.startswith('['):
            text, i = complete_brackets(body, i)
            groups, _ = split_bracket_groups(text.strip())
            if last is None:
                i += 0
                continue
            if isinstance(values[-1], str):
                values[-1] = {'value': values[-1]}
            annset = AnnotationSet()
            for g in groups:
                annset.add(*parse_annotation(g))
            annset.apply(values[-1])
            continue
        m = ENUM_VALUE_RE.match(s)
        if not m:
            i += 1
            continue
        vname, display, rest = m.groups()
        vdoc, rest = doc_at_start(rest)
        if display is None and vdoc is None:
            values.append(vname)
        else:
            v = {'value': vname}
            if display is not None:
                v['displayName'] = display
            if vdoc is not None:
                v['description'] = vdoc
            values.append(v)
        last = values[-1]
        i += 1
    obj['values'] = values
    out.setdefault('enums', {})[name] = obj


def parse_type_alias(block, out):
    stripped = block.header.strip()
    m = re.match(r'^typeAlias\s+(\w+(?:\([^)]*\))?)\s*:\s*(.*)$', stripped, re.S)
    name_full, rest = m.group(1), m.group(2)
    name = name_full.split('(')[0]
    obj = {}
    doc, rest = doc_at_start(rest)
    if doc is not None:
        obj['description'] = doc
    if '(' in name_full:
        obj['parameters'] = name_full[name_full.index('('):]
    parts = [rest.strip()] if rest.strip() else []
    for line in block.body:
        if line.strip():
            parts.append(line)
        elif parts:
            parts.append('')
    while parts and parts[-1] == '':
        parts.pop()
    if parts:
        obj['definition'] = '\n'.join([parts[0].strip()] + parts[1:]).rstrip() \
            if len(parts) > 1 else parts[0].strip()
    out.setdefault('typeAliases', {})[name] = obj


FUNC_CLAUSE_RE = re.compile(r'^(condition|post-condition|set|add|alias)\s*([^:]*?)\s*:\s*(.*)$', re.S)


def parse_function(block, out, section='functions'):
    _, name, _, doc = parse_construct_header(block.header)
    # dispatch functions: func F(param: Enum -> Value): ...  ->  key "F(Value)"
    m = re.match(r'^(\w+)\((.+)\)$', name or '')
    if m:
        base, disp = m.groups()
        val = disp.split('->')[-1].strip() if '->' in disp else disp.strip()
        name = f'{base}({val})'
    obj = {}
    if doc is not None:
        obj['description'] = doc
    annset = AnnotationSet()
    inputs = {}
    output = {}
    conditions = {}
    postconditions = {}
    condition_docs = {}
    condition_anns = {}
    implementation = []
    body = block.body
    i = 0
    mode = None  # None | 'inputs' | 'output'
    last_attr_annset = None
    while i < len(body):
        line = body[i]
        s = line.strip()
        if not s or s.startswith('//'):
            i += 1
            continue
        ind = indent_of(line)
        if s.startswith('['):
            text, i = complete_brackets(body, i)
            groups, _ = split_bracket_groups(text.strip())
            target = last_attr_annset if (mode in ('inputs', 'output') and last_attr_annset) else annset
            for g in groups:
                target.add(*parse_annotation(g))
            continue
        if s == 'inputs:':
            mode = 'inputs'
            last_attr_annset = None
            i += 1
            continue
        if s == 'output:':
            mode = 'output'
            last_attr_annset = None
            i += 1
            continue
        m = FUNC_CLAUSE_RE.match(s)
        if m:
            kw, target, rest = m.groups()
            mode = None
            cdoc, rest = doc_at_start(rest)
            expr, i2 = capture_expression(rest, body, i + 1, ind)
            canns, expr = leading_annotations(expr)
            if canns and kw in ('condition', 'post-condition'):
                cobj = {}
                canns.apply(cobj)
                condition_anns[target or 'condition'] = cobj['annotations']
            if kw == 'condition':
                if not target:
                    target = 'condition' if 'condition' not in conditions \
                        else f'condition{len(conditions) + 1}'
                conditions[target] = expr
                if cdoc is not None:
                    condition_docs[target] = cdoc
            elif kw == 'post-condition':
                postconditions[target] = expr
            else:
                entry = {kw: {target: expr}}
                if cdoc is not None:
                    entry['description'] = cdoc
                implementation.append(entry)
            i = i2
            continue
        parsed = parse_attribute_line(line)
        if parsed and mode in ('inputs', 'output'):
            aname, attr, aanns = parsed
            (inputs if mode == 'inputs' else output)[aname] = attr
            last_attr_annset = _DeferredApply(attr, aanns)
            i += 1
            continue
        i += 1
    annset.apply(obj)
    if inputs:
        obj['inputs'] = inputs
    if output:
        obj['output'] = output
    if conditions:
        obj['conditions'] = conditions
    if condition_docs:
        obj['conditionDescriptions'] = condition_docs
    if postconditions:
        obj['postconditions'] = postconditions
    if condition_anns:
        obj['conditionAnnotations'] = condition_anns
    if implementation:
        obj['implementation'] = implementation
    out.setdefault(section, {})[name] = obj


RULE_HEADER_RE = re.compile(
    r'^(reporting|eligibility)\s+rule\s+(\w+)(?:\s+from\s+([\w.]+))?\s*:?\s*(.*)$', re.S)


def parse_rule(block, out):
    """reporting rule R from T: <"doc"> [annotations] expression
       eligibility rule R from T: <"doc"> [annotations] expression
    -> reportingRules.R / eligibilityRules.R = {input, description?,
    annotations?, expression}; the expression is verbatim, as for functions."""
    m = RULE_HEADER_RE.match(block.header.strip())
    if not m:
        return
    kind, name, input_type, rest = m.groups()
    doc, rest = doc_at_start(rest)
    obj = {}
    if input_type:
        obj['input'] = input_type
    if doc is not None:
        obj['description'] = doc
    expr, _ = capture_expression(rest, block.body, 0, -1)
    annset, expr = leading_annotations(expr)
    if annset:
        annset.apply(obj)
    m = re.search(r'\s+as\s+"((?:[^"\\]|\\.)*)"\s*$', expr)
    if m:
        # reporting rule R ... <expression> as "1.1 Reporting Timestamp"
        obj['label'] = m.group(1)
        expr = expr[:m.start()].rstrip()
    obj['expression'] = expr
    section = 'reportingRules' if kind == 'reporting' else 'eligibilityRules'
    out.setdefault(section, {})[name] = obj


REPORT_RE = re.compile(
    r'^report\s+(.*?)\s+in\s+(.*?)\s+from\s+([\w.]+)\s+when\s+([\w.]+(?:\s+and\s+[\w.]+)*)'
    r'\s+with\s+type\s+([\w.]+)(?:\s+with\s+source\s+([\w.]+))?\s*$', re.S)


def parse_report(block, out):
    """report CFTC Part45 in T+1 from TransactionReportInstruction
         when IsReportableEvent with type CFTCPart45TransactionReport
    -> reports."CFTC Part45" = {regulatoryBody, corpus, timing, input,
    eligibility: [rule...], reportType, source?}."""
    text = ' '.join([block.header.strip()] +
                    [strip_line_comment(l).strip() for l in block.body if l.strip()])
    m = REPORT_RE.match(text)
    if not m:
        print(f'WARNING: unrecognized report: {text[:80]!r}', file=sys.stderr)
        return
    names, timing, input_type, when, rtype, source = m.groups()
    words = names.split()
    obj = {'regulatoryBody': words[0], 'corpus': words[1:], 'timing': timing,
           'input': input_type,
           'eligibility': [w.strip() for w in re.split(r'\s+and\s+', when)],
           'reportType': rtype}
    if source:
        obj['source'] = source
    out.setdefault('reports', {})[' '.join(words)] = obj


def parse_annotation_def(block, out):
    """annotation creation: <"..."> with [prefix X] and attribute-like members."""
    _, name, _, doc = parse_construct_header(block.header)
    obj = {}
    if doc is not None:
        obj['description'] = doc
    attributes = {}
    for i, line in enumerate(block.body):
        s = line.strip()
        if not s or s.startswith('//'):
            continue
        if s.startswith('['):
            groups, _ = split_bracket_groups(s)
            for g in groups:
                kind, payload = parse_annotation(g)
                if kind:
                    obj[kind] = payload if not isinstance(payload, list) else \
                        (payload[0] if len(payload) == 1 else payload)
            continue
        parsed = parse_attribute_line(line)
        if parsed:
            aname, attr, aanns = parsed
            aanns.apply(attr)
            attributes[aname] = attr
    if attributes:
        obj['attributes'] = attributes
    out.setdefault('annotations', {})[name] = obj


def parse_corpus(block, out):
    text, doc = extract_doc(block.header.strip())
    tokens = tokenize(re.sub(r'^corpus\s+', '', text))
    corpus_type = tokens[0][1] if tokens else None
    rest = tokens[1:]
    corpus_name = None
    words = []
    for tt, tv in rest:
        if tt == 'str':
            corpus_name = tv
        else:
            words.append(tv)
    body_name = None
    alias = None
    if len(words) == 1:
        alias = words[0]
    elif len(words) >= 2:
        body_name = words[0]
        alias = words[-1]
    out.setdefault('corpora', []).append({
        'CorpusType': corpus_type,
        'Body': body_name,
        'Alias': alias,
        'CorpusName': corpus_name,
        'description': doc,
    })


def parse_body_decl(block, out):
    text, doc = extract_doc(block.header.strip())
    parts = text.split()
    out.setdefault('bodies', []).append({
        'BodyType': parts[1] if len(parts) > 1 else None,
        'BodyName': parts[2] if len(parts) > 2 else None,
        'description': doc,
    })


def parse_synonym_source(block, out):
    text = block.header.strip()
    m = re.match(r'^synonym\s+source\s+(\w+)(?:\s+extends\s+(\w+))?\s*$', text)
    if not m:
        return
    name, ext = m.groups()
    obj = {'type': 'source'}
    if ext:
        obj['extends'] = ext
    body = [l for l in block.body]
    while body and not body[0].strip():
        body.pop(0)
    while body and not body[-1].strip():
        body.pop()
    if body:
        obj['body'] = '\n'.join(body)
    out.setdefault('synonyms', {})[name] = obj


# ---------------------------------------------------------------- file/namespace

def parse_file(path):
    """Parse one .rosetta file into a partial namespace dict."""
    text = path.read_text(encoding='utf-8')
    out = {}
    lines = logical_lines(text)
    for block in blocks_of(lines):
        header = block.header.strip()
        kw = header.split(None, 1)[0].rstrip(':') if header else ''
        if kw == 'namespace':
            rest = header[len('namespace'):].strip()
            rest, doc = extract_doc(rest)
            out['namespace'] = rest.split(':')[0].strip().rstrip(':').strip()
            if doc:
                out['namespaceDescription'] = doc
        elif kw == 'version':
            m = re.search(r'"((?:[^"\\]|\\.)*)"', header)
            if m:
                out['version'] = m.group(1)
        elif kw == 'import':
            parts = header.split()
            ns = re.sub(r'\.\*$', '', parts[1])
            out.setdefault('imports', []).append(ns)
            if len(parts) >= 4 and parts[2] == 'as':
                # import drr.standards.iosco.cde.version2.* as cde
                out.setdefault('importAliases', {})[parts[3]] = ns
        elif kw == 'metaType':
            parts = header.split()
            if len(parts) >= 3:
                out.setdefault('metaTypes', {})[parts[1]] = {'type': parts[2]}
        elif kw == 'body':
            parse_body_decl(block, out)
        elif kw == 'corpus':
            parse_corpus(block, out)
        elif kw == 'segment':
            parts = header.split()
            if len(parts) >= 2:
                out.setdefault('segments', []).append(parts[1])
        elif kw == 'annotation':
            parse_annotation_def(block, out)
        elif kw == 'synonym':
            parse_synonym_source(block, out)
        elif kw in ('isEvent', 'isProduct'):
            m = re.match(r'^(isEvent|isProduct)\s+root\s+([\w.]+)\s*;?', header)
            if m:
                out.setdefault('rootDeclarations', {})[m.group(1)] = m.group(2)
        elif kw == 'type':
            parse_type(block, out)
        elif kw == 'choice':
            parse_choice(block, out)
        elif kw == 'enum':
            parse_enum(block, out)
        elif kw == 'typeAlias':
            parse_type_alias(block, out)
        elif kw == 'func':
            parse_function(block, out)
        elif kw in ('reporting', 'eligibility'):
            parse_rule(block, out)
        elif kw == 'report':
            parse_report(block, out)
        elif header.startswith('//') or not header:
            continue
        else:
            print(f'WARNING: {path.name}: unrecognized top-level construct: '
                  f'{header[:80]!r}', file=sys.stderr)
    return out


TOP_ORDER = ['namespace', 'namespaceDescription', 'version', 'provenance',
             'originalFiles', 'imports', 'bodies', 'corpora', 'segments',
             'metaTypes', 'annotations', 'synonyms', 'rootDeclarations',
             'importAliases', 'typeAliases', 'types', 'choices', 'enums',
             'functions', 'reports', 'reportingRules', 'eligibilityRules',
             'fileScopes']


def merge_namespace(parts, filenames):
    """Merge per-file dicts (same namespace) into the final JSON object."""
    merged = {
        'namespace': None,
        'provenance': PROVENANCE,
        'originalFiles': sorted(filenames),
        'imports': [],
        'bodies': [],
        'corpora': [],
        'segments': [],
    }
    imports = set()
    scopes = {}
    for fn, part in zip(filenames, parts):
        members = sorted(k for key in ('types', 'choices', 'enums', 'typeAliases',
                                       'functions', 'reportingRules', 'eligibilityRules')
                         for k in part.get(key, {}))
        scopes[fn] = {'imports': sorted(set(part.get('imports', []))),
                      'importAliases': part.get('importAliases', {}),
                      'members': members}
    for part in parts:
        merged['namespace'] = merged['namespace'] or part.get('namespace')
        if 'namespaceDescription' in part and 'namespaceDescription' not in merged:
            merged['namespaceDescription'] = part['namespaceDescription']
        if 'version' in part and 'version' not in merged:
            merged['version'] = part['version']
        imports.update(part.get('imports', []))
        merged['bodies'].extend(part.get('bodies', []))
        merged['corpora'].extend(part.get('corpora', []))
        for seg in part.get('segments', []):
            if seg not in merged['segments']:
                merged['segments'].append(seg)
        for key in ('metaTypes', 'annotations', 'synonyms', 'rootDeclarations',
                    'importAliases', 'typeAliases', 'types', 'choices', 'enums',
                    'functions', 'reports', 'reportingRules', 'eligibilityRules'):
            if key in part:
                dst = merged.setdefault(key, {})
                for k, v in part[key].items():
                    if key == 'importAliases' and k in dst:
                        # the same alias, imported by several files; when two
                        # files give it different namespaces, fileScopes says
                        # which is meant where
                        continue
                    if k in dst:
                        print(f'WARNING: duplicate {key} component {k} in '
                              f'{merged["namespace"]}', file=sys.stderr)
                    dst[k] = v
    imports.discard(merged['namespace'])
    merged['imports'] = sorted(imports)
    if any(sc['importAliases'] for sc in scopes.values()):
        # Rune resolves names per file: a file's own imports and aliases
        merged['fileScopes'] = scopes
    # dispatch functions F(Value) inherit the signature of the base function F
    funcs = merged.get('functions', {})
    for fname, fobj in funcs.items():
        m = re.match(r'^(\w+)\(', fname)
        if m and m.group(1) in funcs:
            base = funcs[m.group(1)]
            for key in ('inputs', 'output'):
                if key not in fobj and key in base:
                    fobj[key] = base[key]
    return {k: merged[k] for k in TOP_ORDER if k in merged}


def convert(src_dir, out_dir, only=None, write_namespaces=False):
    src = Path(src_dir)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    by_namespace = {}
    for path in sorted(src.glob('*.rosetta')):
        part = parse_file(path)
        ns = part.get('namespace')
        if not ns:
            print(f'WARNING: {path.name}: no namespace found, skipped', file=sys.stderr)
            continue
        by_namespace.setdefault(ns, []).append((path.name, part))
    written = []
    for ns in sorted(by_namespace):
        if only and ns != only:
            continue
        files = [fn for fn, _ in by_namespace[ns]]
        parts = [p for _, p in by_namespace[ns]]
        merged = merge_namespace(parts, files)
        target = out / f'{ns}.json'
        with open(target, 'w', encoding='utf-8') as f:
            json.dump(merged, f, indent=2, ensure_ascii=False)
            f.write('\n')
        written.append(target)
    if write_namespaces:
        nsmap = {ns: sorted(fn for fn, _ in by_namespace[ns]) for ns in sorted(by_namespace)}
        with open(out / 'namespaces.json', 'w', encoding='utf-8') as f:
            json.dump(nsmap, f, indent=2, ensure_ascii=False)
            f.write('\n')
    return written, by_namespace


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('src', help='directory with .rosetta files')
    ap.add_argument('out', help='output directory for <namespace>.json files')
    ap.add_argument('--only', help='convert a single namespace')
    ap.add_argument('--namespaces-json', action='store_true',
                    help='also write namespaces.json (namespace -> file list)')
    args = ap.parse_args()
    written, by_ns = convert(args.src, args.out, args.only, args.namespaces_json)
    print(f'{len(written)} namespace files written to {args.out} '
          f'({len(by_ns)} namespaces discovered)')


if __name__ == '__main__':
    main()

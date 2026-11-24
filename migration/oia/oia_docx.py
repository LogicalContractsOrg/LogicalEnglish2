#!/usr/bin/env python3
"""Oracle Intelligent Advisor Word rule document (.docx) -> JSON lines.

    python3 oia_docx.py "Rules/My Rules.docx"   > lines.json

The rule documents of an OIA (Oracle Policy Automation) project are Word files
whose paragraphs carry Policy Modeling's own styles: "OPM - conclusion",
"OPM - level 1" ... "OPM - level 6", "OPM - Alternative conclusion",
"OPM - rule type", "OPM - Heading", the "Comment - ..." styles of lines the
author switched off, and ordinary headings and body text. A rule table is a
Word table whose cells hold paragraphs in those same styles. Policy Modeling
compiles them to `.xgen`; this script reads the Word file itself, so a project
can be translated without Policy Modeling and without its compiled output.

Only the standard library is used (zipfile, xml.etree): no python-docx.

Output, one JSON object:

    {"document": "<file name>",
     "blocks": [ {"kind": "p", "style": "OPM - conclusion", "text": "...", "para": 7},
                 {"kind": "table", "para": 12,
                  "rows": [[ [ {"style": ..., "text": ...}, ... ],   # cell 1
                             [ ... ] ],                              # cell 2
                           ... ]} ]}

`para` numbers the document's paragraphs in order, as Policy Modeling's
source offsets do (a table counts as one). Line breaks inside a paragraph
(`<w:br/>`) add nothing, as Policy Modeling compiles them; a tab is a
space.
"""

import json
import sys
import zipfile
import xml.etree.ElementTree as ET

W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'


def style_names(z):
    """styleId -> the style's display name ("OPM-level1" -> "OPM - level 1")."""
    names = {}
    try:
        root = ET.fromstring(z.read('word/styles.xml'))
    except KeyError:
        return names
    for st in root.iter(W + 'style'):
        sid = st.get(W + 'styleId')
        n = st.find(W + 'name')
        if sid and n is not None:
            names[sid] = n.get(W + 'val')
    return names


def para_text(p):
    out = []
    for el in p.iter():
        if el.tag == W + 't':
            out.append(el.text or '')
        elif el.tag == W + 'tab':
            out.append(' ')
        # a line break inside a paragraph (a long string literal laid out
        # on several lines) adds nothing: Policy Modeling compiles the
        # line '"  <div>', a break, and '    <dt' as '"  <div>    <dt'
    return ''.join(out)


def para_style(p, names):
    ppr = p.find(W + 'pPr')
    if ppr is not None:
        ps = ppr.find(W + 'pStyle')
        if ps is not None:
            sid = ps.get(W + 'val')
            return names.get(sid, sid)
    return 'Normal'


def cell_paras(tc, names):
    return [{'style': para_style(p, names), 'text': para_text(p)}
            for p in tc.findall(W + 'p')]


def read(path):
    z = zipfile.ZipFile(path)
    names = style_names(z)
    body = ET.fromstring(z.read('word/document.xml')).find(W + 'body')
    blocks = []
    n = 0
    for el in body:
        if el.tag == W + 'p':
            n += 1
            blocks.append({'kind': 'p', 'para': n,
                           'style': para_style(el, names), 'text': para_text(el)})
        elif el.tag == W + 'tbl':
            n += 1
            rows = []
            for tr in el.findall(W + 'tr'):
                rows.append([cell_paras(tc, names) for tc in tr.findall(W + 'tc')])
            blocks.append({'kind': 'table', 'para': n, 'rows': rows})
    return {'document': path.split('/')[-1], 'blocks': blocks}


if __name__ == '__main__':
    json.dump(read(sys.argv[1]), sys.stdout, ensure_ascii=False)

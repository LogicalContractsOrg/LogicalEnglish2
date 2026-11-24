#!/usr/bin/env python3
"""Write an Oracle Policy Modeling Word rule document (.docx) from .ruletxt.

    python3 make_docx.py "Rules/Simple Benefits Rules.ruletxt" "Rules/Simple Benefits Rules.docx"

The projects reconstructed from Oracle's documentation (sources/extra/) are
authored in the plain-text form the Ministry of Justice's opa_tools uses for
Word rule documents under version control (`[OPM-level1]<tab>text`; a rule
table as `[table-OPM-conclusion]` header, `value | [n] condition` rows,
`[table-cell-continued]` lines). This script writes them as the Word
documents a Policy Modeling project holds, with the paragraph styles Policy
Modeling uses ("OPM - conclusion", "OPM - level 1", ...), so that the
translator reads them as it reads any customer's Word rules (oia_docx.py).
Only the standard library is used.
"""
import sys
import zipfile
from xml.sax.saxutils import escape

STYLES = {  # style id -> display name
    "OPM-conclusion": "OPM - conclusion",
    "OPM-Alternativeconclusion": "OPM - Alternative conclusion",
    "OPM-ruletype": "OPM - rule type",
    "OPM-blankline": "OPM - blank line",
    "OPM-Heading": "OPM - Heading",
    "Heading1": "heading 1",
    "Heading2": "heading 2",
    "Normal": "Normal",
    "Comment-conclusion": "Comment - conclusion",
    "Comment-Level1": "Comment - Level 1",
}
for n in range(1, 7):
    STYLES["OPM-level%d" % n] = "OPM - level %d" % n

W = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'


def para(style, text):
    sid = style if style in STYLES else "Normal"
    return ('<w:p><w:pPr><w:pStyle w:val="%s"/></w:pPr><w:r><w:t xml:space="preserve">%s</w:t></w:r></w:p>'
            % (sid, escape(text)))


def cell(paras):
    return '<w:tc>%s</w:tc>' % (''.join(para(s, t) for s, t in paras) or para("Normal", ""))


def parse(lines):
    """Blocks: ('p', style, text) or ('table', header_text, rows) with rows
    [(value_style, value, [(level, condition), ...]), ...]."""
    blocks, i = [], 0
    while i < len(lines):
        line = lines[i].rstrip("\n")
        if not line.strip():
            i += 1
            continue
        style, text = line[1:line.index("]")], line[line.index("]") + 1:].strip()
        if style.startswith("table-") and "conclusion" in style and "Alternative" not in style:
            header, rows = text, []
            i += 1
            while i < len(lines) and lines[i].startswith("[table-"):
                s2 = lines[i][1:lines[i].index("]")]
                t2 = lines[i][lines[i].index("]") + 1:].strip()
                if "conclusion" in s2 and "Alternative" not in s2:
                    break                      # the next table's header
                if s2 == "table-cell-continued":
                    cond = t2.lstrip("|").strip()
                    rows[-1][2].append(level_of(cond))
                else:
                    value, cond = [x.strip() for x in t2.rsplit("|", 1)]
                    vstyle = "OPM-Alternativeconclusion" if "Alternative" in s2 else "OPM-conclusion"
                    rows.append((vstyle, value, [level_of(cond)]))
                i += 1
            blocks.append(("table", header, rows))
            continue
        blocks.append(("p", style.rstrip("()"), text))
        i += 1
    return blocks


def level_of(cond):
    if cond.startswith("["):
        n = int(cond[1:cond.index("]")])
        return (max(n, 1), cond[cond.index("]") + 1:].strip())
    return (1, cond)


def document(blocks):
    body = []
    for b in blocks:
        if b[0] == "p":
            body.append(para(b[1], b[2]))
        else:
            _, header, rows = b
            trs = ['<w:tr>%s%s</w:tr>' % (cell([("OPM-conclusion", header)]), cell([]))]
            for vstyle, value, conds in rows:
                cstyle = lambda lv, t: ("OPM-Alternativeconclusion", t) if t.lower() == "otherwise" else ("OPM-level%d" % lv, t)
                trs.append('<w:tr>%s%s</w:tr>' % (cell([(vstyle if vstyle != "OPM-Alternativeconclusion" else "OPM-conclusion", value)]),
                                                  cell([cstyle(lv, t) for lv, t in conds])))
            body.append('<w:tbl>%s</w:tbl>' % ''.join(trs))
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<w:document %s><w:body>%s</w:body></w:document>' % (W, ''.join(body)))


def styles():
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:styles %s>%s</w:styles>'
            % (W, ''.join('<w:style w:type="paragraph" w:styleId="%s"><w:name w:val="%s"/></w:style>' % (k, v)
                          for k, v in STYLES.items())))


CONTENT_TYPES = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
    '</Types>')
RELS = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
    '</Relationships>')
DOC_RELS = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>')


def main(src, dst):
    with open(src, encoding="utf-8") as f:
        blocks = parse(f.readlines())
    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", CONTENT_TYPES)
        z.writestr("_rels/.rels", RELS)
        z.writestr("word/_rels/document.xml.rels", DOC_RELS)
        z.writestr("word/document.xml", document(blocks))
        z.writestr("word/styles.xml", styles())


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

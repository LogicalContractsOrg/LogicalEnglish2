#!/usr/bin/env python3
"""Oracle Intelligent Advisor Excel test files (.xlsx) -> JSON.

An OIA test script in Excel is a workbook whose sheet "Test Cases" has one
row per case and one column per attribute. Each cell carries a NAMED STYLE
that says what the column is: "OPM - Input Heading" / "OPM - Input",
"OPM - Expected Heading" / "OPM - Expected", "OPM - Actual ..." and
"OPM - Test Result ...". Other sheets hold entity instances (their first
column names the test case, or "all").

Output (stdout, JSON):
  {"file": ..., "sheets": [{"name": ..., "columns": [{"name":..., "role":...}],
   "cases": [{"id":..., "row":..., "inputs": {...}, "expected": {...},
              "actual": {...}, "note": ...}]}]}

Values: booleans stay booleans, numbers numbers, dates ISO strings
("2018-06-23"), "(uncertain)" / "(unknown)" as written. Empty cells are left
out. Used by oia_tests.pl; the reader proper is Prolog.

Usage: oia_tests.py FILE.xlsx
"""
import datetime
import json
import sys

import openpyxl

ROLES = {"input heading": "input", "input": "input",
         "expected heading": "expected", "expected": "expected",
         "actual heading": "actual", "actual": "actual",
         "test result heading": "result", "test result": "result"}


def role_of(style):
    s = (style or "").strip().lower()
    if s.startswith("opm - "):
        s = s[6:]
    elif s.startswith("opm "):
        s = s[4:]
    return ROLES.get(s.strip(), "")


def value(v):
    if isinstance(v, datetime.datetime):
        if v.hour == v.minute == v.second == 0:
            return v.date().isoformat()
        return v.isoformat()
    if isinstance(v, datetime.date):
        return v.isoformat()
    if isinstance(v, float) and v.is_integer():
        return int(v)
    return v


def empty(v):
    return v is None or (isinstance(v, str) and v.strip() == "")


def header_row(ws):
    """The row of the column headings: group titles may sit above it."""
    for r in range(1, min(ws.max_row, 6) + 1):
        if any(role_of(ws.cell(row=r, column=c).style).endswith(("input", "expected"))
               and str(ws.cell(row=r, column=c).style).lower().endswith("heading")
               for c in range(1, ws.max_column + 1)):
            return r
    return 1


def sheet(ws):
    hr = header_row(ws)
    columns = []
    for c in range(1, ws.max_column + 1):
        head = ws.cell(row=hr, column=c)
        role = role_of(head.style)
        if not role:                      # the heading may be unstyled: look below
            for r in range(hr + 1, min(ws.max_row, hr + 5) + 1):
                role = role_of(ws.cell(row=r, column=c).style)
                if role:
                    break
        name = "" if head.value is None else str(head.value).strip()
        columns.append({"col": c, "name": name, "role": role})
    id_col = next((c for c in columns if c["name"].lower() in ("test case", "test cases")), None)
    note_col = next((c for c in columns if not c["role"] and c["name"] == ""), None)
    cases = []
    for r in range(hr + 1, ws.max_row + 1):
        case = {"row": r, "inputs": {}, "expected": {}, "actual": {}}
        filled = False
        for c in columns:
            if c is id_col or not c["name"] or c["role"] not in ("input", "expected", "actual"):
                continue
            v = ws.cell(row=r, column=c["col"]).value
            if empty(v):
                continue
            filled = True
            key = {"input": "inputs", "expected": "expected", "actual": "actual"}[c["role"]]
            case[key][c["name"]] = value(v)
        if not filled:
            continue
        idv = ws.cell(row=r, column=id_col["col"]).value if id_col else r - hr
        if isinstance(idv, str) and idv.startswith("Use '"):
            continue
        case["id"] = value(idv)
        # a free note in an unstyled column to the right of the results
        for c in columns:
            if not c["role"]:
                v = ws.cell(row=r, column=c["col"]).value
                if not empty(v):
                    case["note"] = str(v)
        cases.append(case)
    return {"name": ws.title,
            "columns": [{"name": c["name"], "role": c["role"]} for c in columns if c["name"]],
            "cases": cases}


def main(path):
    wb = openpyxl.load_workbook(path, data_only=True)
    out = {"file": path, "sheets": []}
    for ws in wb.worksheets:
        if not any(role_of(ws.cell(row=r, column=c).style)
                   for r in range(1, min(ws.max_row, 6) + 1) for c in range(1, ws.max_column + 1)):
            continue                      # an "About" sheet
        out["sheets"].append(sheet(ws))
    json.dump(out, sys.stdout, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main(sys.argv[1])

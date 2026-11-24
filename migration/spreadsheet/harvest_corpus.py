"""A corpus of government workbooks for the phase-0 survey (Excel.md §8, decision 4).

Searches data.gov.uk's catalogue (CKAN) for Excel files published under the
Open Government Licence, with words that suggest a calculation, downloads up
to N of them (each under 15 MB) into .cache/corpus/, and keeps those that hold
at least one formula. The list it kept is corpus.json (committed): name,
publisher's dataset, URL, licence, formula count.

    python3 harvest_corpus.py [N]
"""
import json, os, sys, urllib.request, urllib.parse, zipfile, io, re, hashlib

N = int(sys.argv[1]) if len(sys.argv) > 1 else 60
API = "https://ckan.publishing.service.gov.uk/api/action/package_search"
WORDS = ["calculator", "calculation", "formula", "eligibility", "allowance", "model", "tool", "tariff", "rates"]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".cache", "corpus")
os.makedirs(OUT, exist_ok=True)
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) Logical English spreadsheet survey"}

def get(url, limit=15_000_000):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read(limit + 1)
    if len(data) > limit:
        raise ValueError("too large")
    return data

def formulas(data):
    z = zipfile.ZipFile(io.BytesIO(data))
    return sum(len(re.findall(rb"<f[ >]", z.read(n))) for n in z.namelist() if n.startswith("xl/worksheets/") and n.endswith(".xml"))

seen, kept = set(), []
for w in WORDS:
    for start in range(0, 400, 100):
        q = urllib.parse.urlencode({"q": w, "fq": "res_format:XLSX AND license_id:uk-ogl", "rows": 100, "start": start})
        try:
            res = json.loads(get(f"{API}?{q}"))["result"]["results"]
        except Exception as e:
            print("search failed", w, e); break
        if not res: break
        for p in res:
            for r in p["resources"]:
                if r.get("format", "").upper() != "XLSX" or r["url"] in seen: continue
                seen.add(r["url"])
                if len(kept) >= N: break
                try:
                    data = get(r["url"])
                    n = formulas(data)
                except Exception as e:
                    continue
                if n == 0: continue
                name = re.sub(r"[^a-z0-9]+", "_", p["name"].lower())[:50] + "_" + hashlib.sha1(r["url"].encode()).hexdigest()[:6] + ".xlsx"
                open(os.path.join(OUT, name), "wb").write(data)
                kept.append({"file": name, "dataset": p["title"], "publisher": (p.get("organization") or {}).get("title"),
                             "url": r["url"], "licence": p.get("license_id"), "formulas": n})
                print(len(kept), n, name, flush=True)
        if len(kept) >= N: break
    if len(kept) >= N: break
json.dump(kept, open(os.path.join(os.path.dirname(OUT), "..", "corpus.json"), "w"), indent=1)
print("kept", len(kept))

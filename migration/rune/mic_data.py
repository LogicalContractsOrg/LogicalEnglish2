"""The ISO 10383 records of the market identifier codes (MICs) that DRR's test
packs name, for the twins: DRR's Java (API_GetMicDataImpl) fetches the whole
table from iso20022.org when a trade names a venue without enrichment data;
the twins read the same records as facts.

    python3 mic_data.py        # .cache/ISO10383_MIC.xml -> .cache/mic_records.json

The records kept are those of every MIC that appears as a text in a test
pack's input, and of their operating MICs. The fields are named as in DRR's
MicData type, with the values DRR's Java gives them (dates as yyyy-mm-dd).
"""
import glob, json, os, re, urllib.request
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, '.cache')
URL = 'https://www.iso20022.org/sites/default/files/ISO10383_MIC/ISO10383_MIC.xml'

FIELDS = {   # XML element -> MicData attribute
    'MIC': 'mic', 'OPERATING_x0020_MIC': 'operatingMic', 'OPRT_x002F_SGMT': 'micType',
    'MARKET_x0020_NAME-INSTITUTION_x0020_DESCRIPTION': 'nameInstitutionDescription',
    'LEGAL_x0020_ENTITY_x0020_NAME': 'legalEntityName', 'MARKET_x0020_CATEGORY_x0020_CODE': 'marketCategory',
    'ACRONYM': 'acronym', 'ISO_x0020_COUNTRY_x0020_CODE_x0020__x0028_ISO_x0020_3166_x0029_': 'countryCode',
    'CITY': 'city', 'WEBSITE': 'website', 'STATUS': 'status', 'CREATION_x0020_DATE': 'creationDate',
    'LAST_x0020_UPDATE_x0020_DATE': 'lastUpdateDate', 'LAST_x0020_VALIDATION_x0020_DATE': 'lastValidationDate',
    'EXPIRY_x0020_DATE': 'expiryDate',
}

def table():
    path = os.path.join(CACHE, 'ISO10383_MIC.xml')
    if not os.path.exists(path):
        urllib.request.urlretrieve(URL, path)
    recs = {}
    root = ET.parse(path).getroot()
    table.generated = root.get('generated', '')
    for e in root:
        r = {}
        for c in e:
            k = FIELDS.get(c.tag)
            v = (c.text or '').strip()
            if k and v:
                if k.endswith('Date') and re.fullmatch(r'\d{8}', v):
                    v = f'{v[:4]}-{v[4:6]}-{v[6:]}'
                r[k] = v
        if 'mic' in r:
            recs[r['mic']] = r
    return recs

def texts(x, out):
    if isinstance(x, dict):
        for v in x.values():
            texts(v, out)
    elif isinstance(x, list):
        for v in x:
            texts(v, out)
    elif isinstance(x, str) and re.fullmatch(r'[A-Z0-9]{4}', x):
        out.add(x)

def main():
    recs = table()
    used = set()
    for f in glob.glob(os.path.join(CACHE, 'drr/enrich/output/**/*.json'), recursive=True):
        try:
            texts(json.load(open(f)), used)
        except ValueError:
            pass
    keep = {m for m in used if m in recs}
    keep |= {recs[m]['operatingMic'] for m in keep if recs[m].get('operatingMic') in recs}
    out = {m: recs[m] for m in sorted(keep)}
    json.dump({'generated': table.generated, 'records': out},
              open(os.path.join(CACHE, 'mic_records.json'), 'w'), indent=1)
    print(f'{len(out)} MIC records of {len(recs)} kept')

if __name__ == '__main__':
    main()

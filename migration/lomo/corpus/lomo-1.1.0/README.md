# LOMO — Legal Obligation Metadata Ontology

LOMO is an OWL ontology for describing the rules found in legal texts: prescriptive rules (obligations, permissions, prohibitions, rights) and constitutive rules (definitions, scope, institutional rules), with the actions they require, the agents involved, their results, and their temporal conditions. It comes with four SKOS controlled vocabularies and SHACL shapes to validate data against the model.

- **Published documentation:** <https://drpm.pages.code.europa.eu/lomo/> (`/latest/` is the newest release, `/draft/` is the development branch, `/X.Y.Z/` is each release from 1.0.0 on)
- **Ontology IRI:** `http://data.europa.eu/leg/lomo`
- **Changes:** [CHANGELOG](CHANGELOG)
- **Licence:** [CC BY 4.0](LICENSE)

## Repository layout

| Path | Contents |
|---|---|
| `ontologies/lomo-ontology.ttl` | The ontology |
| `ontologies/*.ttl` (others) | The controlled vocabularies: digital dimensions, deontic modality, result category, temporal function |
| `shapes/` | SHACL shapes for instance data (`lomo-shapes.ttl`), for the vocabularies (`lomo-vocabularies-shapes.ttl`) and for interoperability assessments (`iopa-shapes.ttl`) |
| `data/` | Example and pilot instance data |
| `iopa/` | Interoperability assessment alignment and codes |
| `sparql/`, `templates/`, `diagram-layout.json` | Queries, page templates and the class diagram layout used to generate the documentation |
| `scripts/` | Validation, documentation and conversion tooling — see [scripts/README.md](scripts/README.md) |
| `tests/` | pytest checks on the ontology, vocabularies and tooling |

## Working locally

Python 3.11 or later.

```bash
pip install -r requirements.txt pytest     # or: poetry install

python scripts/validate_ttl.py -r          # every .ttl file parses
python -m pytest                           # model and tooling checks
python scripts/validate_shacl.py           # instance data against the shapes (calls the EU ITB validator)
python scripts/generate_docs.py            # renders index.html from the ontology
```

## Contributing

Changes start as an issue, using the *change_request* template (`.gitlab/issue_templates/`). Work happens on a branch named `<issue>-<short-description>` from `development`, with a merge request back into `development`. Each merge request adds its entry to the unreleased section of the [CHANGELOG](CHANGELOG), which follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

A release merges `development` into `main` and tags it `vX.Y.Z`; the tag pipeline validates the data and publishes that version's documentation.

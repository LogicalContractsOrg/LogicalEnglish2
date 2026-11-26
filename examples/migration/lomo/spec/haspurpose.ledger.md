# Migration ledger: haspurpose

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — hasPurpose.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 3 |
| approximated | 0 |
| residue | 0 |
| **total** | 3 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/Service_StatisticalDissemination | *a thing* is a public service | encoded | 5 statements(5), one fact each | service statistical dissemination | kept in the generic form (no word in lomo.le): cpsv:hasCompetentAuthority |
| http://example.org/Service_DataQualityAssurance | *a thing* is a public service | encoded | 5 statements(5), one fact each | service data quality assurance | kept in the generic form (no word in lomo.le): cpsv:hasCompetentAuthority |
| http://example.org/Service_MemberStateDataCollection | *a thing* is a public service | encoded | 5 statements(5), one fact each | service member state data collection | kept in the generic form (no word in lomo.le): cpsv:hasCompetentAuthority |


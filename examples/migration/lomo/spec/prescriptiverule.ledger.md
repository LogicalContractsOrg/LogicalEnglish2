# Migration ledger: prescriptiverule

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — PrescriptiveRule.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 10 |
| approximated | 0 |
| residue | 0 |
| **total** | 10 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/Requirement_Art4_Par1 | *a thing* is a prescriptive rule | encoded | 7 statements(7), one fact each | requirement art 4 par 1 |  |
| http://example.org/Requirement_Art30_Par1_PublicationObligation | *a thing* is a prescriptive rule | encoded | 6 statements(6), one fact each | requirement art 30 par 1 publication obligation |  |
| http://example.org/Requirement_Art10_Par2 | *a thing* is a prescriptive rule | encoded | 5 statements(5), one fact each | requirement art 10 par 2 |  |
| http://example.org/Requirement_Art10_Par2 | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Requirement_Art10_Par2 has no produces (LOMO asks for one) |
| http://example.org/Requirement_Art10_Par2 | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Requirement_Art10_Par2 has no label (LOMO asks for one) |
| http://example.org/Requirement_Art10_Par2 | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Requirement_Art10_Par2 has no label (LOMO asks for one) |
| http://example.org/Requirement_Art30_Par1_PublicationObligation | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Requirement_Art30_Par1_PublicationObligation has no label (LOMO asks for one) |
| http://example.org/Requirement_Art30_Par1_PublicationObligation | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Requirement_Art30_Par1_PublicationObligation has no label (LOMO asks for one) |
| http://example.org/Requirement_Art4_Par1 | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Requirement_Art4_Par1 has no label (LOMO asks for one) |
| http://example.org/Requirement_Art4_Par1 | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Requirement_Art4_Par1 has no label (LOMO asks for one) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| description | modalities | pass |  |
| description | actions_of_rules | pass |  |


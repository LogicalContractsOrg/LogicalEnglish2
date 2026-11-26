# Migration ledger: gdpr_article_6

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — gdpr_article_6.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 6 |
| approximated | 0 |
| residue | 0 |
| **total** | 6 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/cases/gdpr6#Norm_GDPR_6_1 | *a thing* is a substantive rule | encoded | 6 statements(6), one fact each | norm gdpr 6 1 |  |
| http://example.org/cases/gdpr6#ProcessPersonalData | action | encoded | 4 statements(4), one fact each | process personal data |  |
| http://example.org/cases/gdpr6#Role_Controller | agent role | encoded | 3 statements(3), one fact each | role controller |  |
| http://example.org/cases/gdpr6#Role_DataSubject | agent role | encoded | 3 statements(3), one fact each | role data subject |  |
| http://example.org/cases/gdpr6#Controllers | agent type | encoded | 2 statements(2), one fact each | controllers |  |
| http://example.org/cases/gdpr6#DataSubjects | agent type | encoded | 2 statements(2), one fact each | data subjects |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| description | modalities | pass |  |
| description | actions_of_rules | pass |  |
| description | actions_of_agents | pass |  |


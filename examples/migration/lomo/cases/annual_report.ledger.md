# Migration ledger: annual_report

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — annual_report.ttl
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

Fidelity: **9 of 9** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/cases/annual#Norm_Annual_Report | *a thing* is a substantive rule | encoded | 5 statements(5), one fact each | norm annual report |  |
| http://example.org/cases/annual#SubmitTheReport | action | encoded | 4 statements(4), one fact each | submit the report |  |
| http://example.org/cases/annual#Role_Operator | agent role | encoded | 3 statements(3), one fact each | role operator |  |
| http://example.org/cases/annual#Operators | agent type | encoded | 2 statements(2), one fact each | operators |  |
| http://example.org/cases/annual#Every_Year | *a thing* is a temporal specification | encoded | 5 statements(5), one fact each | year |  |
| http://example.org/cases/annual#StartOfOperation | *a thing* is a temporal specification | encoded | 2 statements(2), one fact each | start of operation |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| calendar | due_dates | pass |  |
| calendar | due_in_2027 | pass |  |
| description | modalities | pass |  |
| description | actions_of_rules | pass |  |
| description | actions_of_agents | pass |  |
| three_reports | occurrences_on_30_june_2027 | pass |  |
| three_reports | met_on_30_june_2027 | pass |  |
| three_reports | breached_on_30_june_2027 | pass |  |
| three_reports | owed_on_30_june_2027 | pass |  |


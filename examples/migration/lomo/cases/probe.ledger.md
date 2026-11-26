# Migration ledger: probe

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — probe.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 18 |
| approximated | 0 |
| residue | 0 |
| **total** | 18 |

Fidelity: **15 of 15** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/cases/probe#Norm_GDPR_33 | *a thing* is a substantive rule | encoded | 6 statements(6), one fact each | norm gdpr 33 |  |
| http://example.org/cases/probe#NotifyTheBreach | action | encoded | 5 statements(5), one fact each | notify the breach |  |
| http://example.org/cases/probe#Role_Controller | agent role | encoded | 3 statements(3), one fact each | role controller |  |
| http://example.org/cases/probe#Role_Authority | agent role | encoded | 3 statements(3), one fact each | role authority |  |
| http://example.org/cases/probe#Deadline_72_Hours | *a thing* is a temporal specification | encoded | 4 statements(4), one fact each | deadline 72 hours |  |
| http://example.org/cases/probe#Awareness | *a thing* is a temporal specification | encoded | 2 statements(2), one fact each | awareness |  |
| http://example.org/cases/probe#Controllers | agent type | encoded | 2 statements(2), one fact each | controllers |  |
| http://example.org/cases/probe#SupervisoryAuthorities | agent type | encoded | 2 statements(2), one fact each | supervisory authorities |  |
| http://example.org/cases/probe#Norm_Accounts_30 | *a thing* is a substantive rule | encoded | 5 statements(5), one fact each | norm accounts 30 |  |
| http://example.org/cases/probe#PublishTheStatements | action | encoded | 4 statements(4), one fact each | publish the statements |  |
| http://example.org/cases/probe#Role_Publisher | agent role | encoded | 3 statements(3), one fact each | role publisher |  |
| http://example.org/cases/probe#Deadline_12_Months | *a thing* is a temporal specification | encoded | 4 statements(4), one fact each | deadline 12 months |  |
| http://example.org/cases/probe#BalanceSheetDate | *a thing* is a temporal specification | encoded | 2 statements(2), one fact each | balance sheet date |  |
| http://example.org/cases/probe#Undertakings | agent type | encoded | 2 statements(2), one fact each | undertakings |  |
| http://example.org/cases/probe#Norm_Micro_36 | *a thing* is a prescriptive rule | encoded | 6 statements(6), one fact each | norm micro 36 |  |
| http://example.org/cases/probe#SkipThePublication | action | encoded | 3 statements(3), one fact each | skip the publication |  |
| http://example.org/cases/probe#Role_Micro | agent role | encoded | 3 statements(3), one fact each | role micro |  |
| http://example.org/cases/probe#MicroUndertakings | agent type | encoded | 2 statements(2), one fact each | micro undertakings |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| calendar | due_dates | pass |  |
| calendar | due_in_2027 | pass |  |
| description | modalities | pass |  |
| description | actions_of_rules | pass |  |
| description | actions_of_agents | pass |  |
| case_one | applies | pass |  |
| case_one | set_aside | pass |  |
| case_one | must_perform | pass |  |
| case_one | late_on_1_april_2026 | pass |  |
| case_one | permitted | pass |  |
| case_one | violations | pass |  |
| case_one | rules_without_conditions | pass |  |
| to_the_minute | must_perform_by_the_moment | pass |  |
| to_the_minute | met_in_time | pass |  |
| to_the_minute | late_at_midnight_4_march | pass |  |


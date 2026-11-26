# Migration ledger: hasfunction

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — hasFunction.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 16 |
| approximated | 0 |
| residue | 0 |
| **total** | 16 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/Action_SubmitReport | action | encoded | 5 statements(5), one fact each | action submit report |  |
| http://example.org/Rule_TemporaryMeasure | *a thing* is a prescriptive rule | encoded | 5 statements(5), one fact each | norm temporary measure |  |
| http://example.org/Rule_DataBreachNotification | *a thing* is a prescriptive rule | encoded | 5 statements(5), one fact each | norm data breach notification |  |
| http://example.org/Action_SubmitReport | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Action_SubmitReport has no hasAgentRole (LOMO asks for one) |
| http://example.org/Rule_DataBreachNotification | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_DataBreachNotification has no establishedIn (LOMO asks for one) |
| http://example.org/Rule_DataBreachNotification | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_DataBreachNotification has no establishedIn (LOMO asks for one) |
| http://example.org/Rule_DataBreachNotification | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_DataBreachNotification has no hasDeonticModality (LOMO asks for one) |
| http://example.org/Rule_DataBreachNotification | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_DataBreachNotification has no produces (LOMO asks for one) |
| http://example.org/Rule_DataBreachNotification | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_DataBreachNotification has no label (LOMO asks for one) |
| http://example.org/Rule_DataBreachNotification | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_DataBreachNotification has no label (LOMO asks for one) |
| http://example.org/Rule_TemporaryMeasure | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_TemporaryMeasure has no establishedIn (LOMO asks for one) |
| http://example.org/Rule_TemporaryMeasure | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_TemporaryMeasure has no establishedIn (LOMO asks for one) |
| http://example.org/Rule_TemporaryMeasure | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_TemporaryMeasure has no hasDeonticModality (LOMO asks for one) |
| http://example.org/Rule_TemporaryMeasure | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_TemporaryMeasure has no produces (LOMO asks for one) |
| http://example.org/Rule_TemporaryMeasure | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_TemporaryMeasure has no label (LOMO asks for one) |
| http://example.org/Rule_TemporaryMeasure | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_TemporaryMeasure has no label (LOMO asks for one) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| calendar | due_dates | pass |  |
| calendar | due_in_2027 | pass |  |
| the_functions | deadlines | pass |  |
| the_functions | first_dates | pass |  |


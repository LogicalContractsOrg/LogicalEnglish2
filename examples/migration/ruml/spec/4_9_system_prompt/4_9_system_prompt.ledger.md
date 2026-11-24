# Migration ledger: 4_9_system_prompt

Source: RUML — system-prompt.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 1 |
| residue | 0 |
| **total** | 2 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| node(1) | leaf | encoded | ruml:ai-query: a judged sentence (the prompt: Prüfe anhand der bereitgestellten Unterlagen, ob eine Härtefallbegründung plausibel ist. Antworte ausschließlich mit true, false oder undefined.) | Begründung plausibel holds for *a case* | label: Begründung plausibel |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |


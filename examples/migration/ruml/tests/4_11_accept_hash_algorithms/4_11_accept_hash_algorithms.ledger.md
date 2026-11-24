# Migration ledger: 4_11_accept_hash_algorithms

Source: RUML — accept-hash-algorithms.ruml
Translator: ruml_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 4 |
| residue | 0 |
| **total** | 5 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| context(ctx_estg_sha3) | context | approximated | context material (administrativeGuidance) | estg sha3 | context material is listed, not reasoned with |
| context(ctx_estg_sha256) | context | approximated | context material (administrativeGuidance) | estg sha256 | context material is listed, not reasoned with |
| context(ctx_estg_blake3) | context | approximated | context material (administrativeGuidance) | estg blake3 | context material is listed, not reasoned with |
| node(1) | leaf | encoded | a leaf with no deciding capability: a judged sentence, which a person decides | Antrag holds for *a case* | RUML: undefined until decided |
| metadata | metadata | approximated | a comment at the top; the original file under sources/ |  | status, version, validity, authors: data about the file, not rules (decision 6 of the plan) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generated_1 | node_1 | pass |  |
| generated_1 | not_node_1 | pass |  |


# Migration ledger: traffic_violation

Source: DMN — Traffic Violation.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 2 |
| approximated | 0 |
| residue | 0 |
| **total** | 2 |

Fidelity: **21 of 21** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Fine | decision table | encoded | decision table | Fine | a rule per row |
| Should the driver be suspended? | context | encoded | context | Should the driver be suspended? |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| readme | q_d_amount_of_the_fine | pass |  |
| readme | q_d_points_of_the_fine | pass |  |
| readme | q_d_should_the_driver_be_suspended | pass |  |
| fast | q_d_amount_of_the_fine | pass |  |
| fast | q_d_points_of_the_fine | pass |  |
| fast | q_d_should_the_driver_be_suspended | pass |  |
| slightly_fast | q_d_amount_of_the_fine | pass |  |
| slightly_fast | q_d_points_of_the_fine | pass |  |
| slightly_fast | q_d_should_the_driver_be_suspended | pass |  |
| parking | q_d_amount_of_the_fine | pass |  |
| parking | q_d_points_of_the_fine | pass |  |
| parking | q_d_should_the_driver_be_suspended | pass |  |
| dui | q_d_amount_of_the_fine | pass |  |
| dui | q_d_points_of_the_fine | pass |  |
| dui | q_d_should_the_driver_be_suspended | pass |  |
| boundary_10 | q_d_amount_of_the_fine | pass |  |
| boundary_10 | q_d_points_of_the_fine | pass |  |
| boundary_10 | q_d_should_the_driver_be_suspended | pass |  |
| boundary_30 | q_d_amount_of_the_fine | pass |  |
| boundary_30 | q_d_points_of_the_fine | pass |  |
| boundary_30 | q_d_should_the_driver_be_suspended | pass |  |


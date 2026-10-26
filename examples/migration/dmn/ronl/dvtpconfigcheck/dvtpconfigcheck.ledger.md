# Migration ledger: dvtpconfigcheck

Source: DMN — DvtpConfigCheck.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 0 |
| **total** | 1 |

Fidelity: **12 of 12** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| DvTP Service Configuration Check (FR-30/32) | decision table | encoded | decision table | DvTP Service Configuration Check (FR-30/32) |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| g001 | q_d_config_ttl_days_of_the_dv_tp_service_configuration_check_fr_30_32 | pass |  |
| g001 | q_d_config_ttl_label_of_the_dv_tp_service_configuration_check_fr_30_32 | pass |  |
| g001 | q_d_initiator_allowed_of_the_dv_tp_service_configuration_check_fr_30_32 | pass |  |
| g002 | q_d_config_ttl_days_of_the_dv_tp_service_configuration_check_fr_30_32 | pass |  |
| g002 | q_d_config_ttl_label_of_the_dv_tp_service_configuration_check_fr_30_32 | pass |  |
| g002 | q_d_initiator_allowed_of_the_dv_tp_service_configuration_check_fr_30_32 | pass |  |
| g003 | q_d_config_ttl_days_of_the_dv_tp_service_configuration_check_fr_30_32 | pass |  |
| g003 | q_d_config_ttl_label_of_the_dv_tp_service_configuration_check_fr_30_32 | pass |  |
| g003 | q_d_initiator_allowed_of_the_dv_tp_service_configuration_check_fr_30_32 | pass |  |
| g004 | q_d_config_ttl_days_of_the_dv_tp_service_configuration_check_fr_30_32 | pass |  |
| g004 | q_d_config_ttl_label_of_the_dv_tp_service_configuration_check_fr_30_32 | pass |  |
| g004 | q_d_initiator_allowed_of_the_dv_tp_service_configuration_check_fr_30_32 | pass |  |


# Migration ledger: ronl_szw_bijstand

Source: DMN — RONL_SZW_Bijstand.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 4 |
| approximated | 0 |
| residue | 0 |
| **total** | 4 |

Fidelity: **35 of 35** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| SZW Bijstandsnorm Informatie | decision table | encoded | decision table | SZW Bijstandsnorm Informatie | a rule per row |
| SZW Bijstandsnorm Bedragen | decision table | encoded | decision table | SZW Bijstandsnorm Bedragen |  |
| SZW Bijstandsnormtype | decision table | encoded | decision table | SZW Bijstandsnormtype |  |
| SZW Bijstandsnormtermijn | decision table | encoded | decision table | SZW Bijstandsnormtermijn | a rule per row |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| g001 | q_d_szw_bijstandsnormtermijn | pass |  |
| g001 | q_d_szw_bijstandsnormtype | pass |  |
| g002 | q_d_szw_bijstandsnormtype | pass |  |
| g003 | q_d_szw_bijstandsnormtermijn | pass |  |
| g003 | q_d_szw_bijstandsnormtype | pass |  |
| g004 | q_d_szw_bijstandsnormtype | pass |  |
| g005 | q_d_szw_bijstandsnormtermijn | pass |  |
| g005 | q_d_szw_bijstandsnormtype | pass |  |
| g006 | q_d_szw_bijstandsnormtype | pass |  |
| g007 | q_d_szw_bijstandsnormtermijn | pass |  |
| g007 | q_d_szw_bijstandsnormtype | pass |  |
| g008 | q_d_szw_bijstandsnormtype | pass |  |
| g009 | q_d_szw_bijstandsnormtermijn | pass |  |
| g009 | q_d_szw_bijstandsnormtype | pass |  |
| g010 | q_d_szw_bijstandsnormtype | pass |  |
| g011 | q_d_szw_bijstandsnormtermijn | pass |  |
| g011 | q_d_szw_bijstandsnormtype | pass |  |
| g012 | q_d_szw_bijstandsnormtype | pass |  |
| g013 | q_d_szw_bijstandsnormtermijn | pass |  |
| g013 | q_d_szw_bijstandsnormtype | pass |  |
| g014 | q_d_szw_bijstandsnormtype | pass |  |
| g015 | q_d_szw_bijstandsnormtermijn | pass |  |
| g015 | q_d_szw_bijstandsnormtype | pass |  |
| g016 | q_d_szw_bijstandsnormtype | pass |  |
| g017 | q_d_szw_bijstandsnormtermijn | pass |  |
| g017 | q_d_szw_bijstandsnormtype | pass |  |
| g018 | q_d_szw_bijstandsnormtype | pass |  |
| g019 | q_d_szw_bijstandsnormtermijn | pass |  |
| g019 | q_d_szw_bijstandsnormtype | pass |  |
| g020 | q_d_szw_bijstandsnormtermijn | pass |  |
| g021 | q_d_szw_bijstandsnormtermijn | pass |  |
| g021 | q_d_szw_bijstandsnormtype | pass |  |
| g022 | q_d_szw_bijstandsnormtermijn | pass |  |
| g023 | q_d_szw_bijstandsnormtermijn | pass |  |
| g023 | q_d_szw_bijstandsnormtype | pass |  |


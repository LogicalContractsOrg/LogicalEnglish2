# Migration ledger: ronl_svb_leeftijden

Source: DMN — RONL_SVB_Leeftijden.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 4 |
| approximated | 0 |
| residue | 0 |
| **total** | 4 |

Fidelity: **48 of 48** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| SVB Leeftijds Informatie | decision table | encoded | decision table | SVB Leeftijds Informatie | a rule per row |
| SVB Leeftijdsgrenzen | decision table | encoded | decision table | SVB Leeftijdsgrenzen | a rule per row |
| SVB Bereken Leeftijden | decision table | encoded | decision table | SVB Bereken Leeftijden | a rule per row |
| SVB AOW leeftijd | decision table | encoded | decision table | SVB AOW leeftijd | a rule per row |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| g001 | q_d_aow_datum_aanvrager_of_the_svb_leeftijds_informatie | pass |  |
| g001 | q_d_aow_datum_partner_of_the_svb_leeftijds_informatie | pass |  |
| g001 | q_d_aanvrager_heeft_aow_leeftijd_of_the_svb_leeftijds_informatie | pass |  |
| g001 | q_d_aanvrager_is181920_of_the_svb_leeftijds_informatie | pass |  |
| g001 | q_d_aanvrager_is_jonger_dan18_of_the_svb_leeftijds_informatie | pass |  |
| g001 | q_d_aanvrager_is_tenminste21_of_the_svb_leeftijds_informatie | pass |  |
| g001 | q_d_leeftijd_aanvrager_of_the_svb_leeftijds_informatie | pass |  |
| g001 | q_d_leeftijd_partner_of_the_svb_leeftijds_informatie | pass |  |
| g001 | q_d_partner_heeft_aow_leeftijd_of_the_svb_leeftijds_informatie | pass |  |
| g001 | q_d_partner_is181920_of_the_svb_leeftijds_informatie | pass |  |
| g001 | q_d_partner_is_jonger_dan18_of_the_svb_leeftijds_informatie | pass |  |
| g001 | q_d_partner_is_tenminste21_of_the_svb_leeftijds_informatie | pass |  |
| g002 | q_d_aow_datum_aanvrager_of_the_svb_leeftijds_informatie | pass |  |
| g002 | q_d_aow_datum_partner_of_the_svb_leeftijds_informatie | pass |  |
| g002 | q_d_aanvrager_heeft_aow_leeftijd_of_the_svb_leeftijds_informatie | pass |  |
| g002 | q_d_aanvrager_is181920_of_the_svb_leeftijds_informatie | pass |  |
| g002 | q_d_aanvrager_is_jonger_dan18_of_the_svb_leeftijds_informatie | pass |  |
| g002 | q_d_aanvrager_is_tenminste21_of_the_svb_leeftijds_informatie | pass |  |
| g002 | q_d_leeftijd_aanvrager_of_the_svb_leeftijds_informatie | pass |  |
| g002 | q_d_leeftijd_partner_of_the_svb_leeftijds_informatie | pass |  |
| g002 | q_d_partner_heeft_aow_leeftijd_of_the_svb_leeftijds_informatie | pass |  |
| g002 | q_d_partner_is181920_of_the_svb_leeftijds_informatie | pass |  |
| g002 | q_d_partner_is_jonger_dan18_of_the_svb_leeftijds_informatie | pass |  |
| g002 | q_d_partner_is_tenminste21_of_the_svb_leeftijds_informatie | pass |  |
| g003 | q_d_aow_datum_aanvrager_of_the_svb_leeftijds_informatie | pass |  |
| g003 | q_d_aow_datum_partner_of_the_svb_leeftijds_informatie | pass |  |
| g003 | q_d_aanvrager_heeft_aow_leeftijd_of_the_svb_leeftijds_informatie | pass |  |
| g003 | q_d_aanvrager_is181920_of_the_svb_leeftijds_informatie | pass |  |
| g003 | q_d_aanvrager_is_jonger_dan18_of_the_svb_leeftijds_informatie | pass |  |
| g003 | q_d_aanvrager_is_tenminste21_of_the_svb_leeftijds_informatie | pass |  |
| g003 | q_d_leeftijd_aanvrager_of_the_svb_leeftijds_informatie | pass |  |
| g003 | q_d_leeftijd_partner_of_the_svb_leeftijds_informatie | pass |  |
| g003 | q_d_partner_heeft_aow_leeftijd_of_the_svb_leeftijds_informatie | pass |  |
| g003 | q_d_partner_is181920_of_the_svb_leeftijds_informatie | pass |  |
| g003 | q_d_partner_is_jonger_dan18_of_the_svb_leeftijds_informatie | pass |  |
| g003 | q_d_partner_is_tenminste21_of_the_svb_leeftijds_informatie | pass |  |
| g004 | q_d_aow_datum_aanvrager_of_the_svb_leeftijds_informatie | pass |  |
| g004 | q_d_aow_datum_partner_of_the_svb_leeftijds_informatie | pass |  |
| g004 | q_d_aanvrager_heeft_aow_leeftijd_of_the_svb_leeftijds_informatie | pass |  |
| g004 | q_d_aanvrager_is181920_of_the_svb_leeftijds_informatie | pass |  |
| g004 | q_d_aanvrager_is_jonger_dan18_of_the_svb_leeftijds_informatie | pass |  |
| g004 | q_d_aanvrager_is_tenminste21_of_the_svb_leeftijds_informatie | pass |  |
| g004 | q_d_leeftijd_aanvrager_of_the_svb_leeftijds_informatie | pass |  |
| g004 | q_d_leeftijd_partner_of_the_svb_leeftijds_informatie | pass |  |
| g004 | q_d_partner_heeft_aow_leeftijd_of_the_svb_leeftijds_informatie | pass |  |
| g004 | q_d_partner_is181920_of_the_svb_leeftijds_informatie | pass |  |
| g004 | q_d_partner_is_jonger_dan18_of_the_svb_leeftijds_informatie | pass |  |
| g004 | q_d_partner_is_tenminste21_of_the_svb_leeftijds_informatie | pass |  |


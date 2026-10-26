# Migration ledger: decision_105946

Source: DMN — decision-105946.dmn
Translator: dmn_twin

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 7 |
| approximated | 0 |
| residue | 0 |
| **total** | 7 |

Fidelity: **48 of 48** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Boom kappen of houtopstand vellen | decision table | encoded | decision table | Boom kappen of houtopstand vellen | a rule per row |
| Boom kappen of houtopstand vellen_Niet van toepassing_cross | decision table | encoded | decision table | Boom kappen of houtopstand vellen_Niet van toepassing_cross |  |
| Boom kappen of houtopstand vellen_Vergunningplicht_cross | decision table | encoded | decision table | Boom kappen of houtopstand vellen_Vergunningplicht_cross |  |
| _6d45be8c-8010-4d11-8775-487a28b88087_Niet van toepassing | decision table | encoded | decision table | _6d45be8c-8010-4d11-8775-487a28b88087_Niet van toepassing |  |
| _2bc68e71-981f-4476-aaaf-f10980dab348_Vergunningplicht | decision table | encoded | decision table | _2bc68e71-981f-4476-aaaf-f10980dab348_Vergunningplicht |  |
| _45d6b9e0-518b-4bcc-b39a-b50cc3251539_Vergunningplicht | decision table | encoded | decision table | _45d6b9e0-518b-4bcc-b39a-b50cc3251539_Vergunningplicht |  |
| _8f6e3ddc-bba0-4b6c-bb24-6614f061332c_Vergunningplicht | decision table | encoded | decision table | _8f6e3ddc-bba0-4b6c-bb24-6614f061332c_Vergunningplicht |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| g001 | q_d_n2bc68e71_981f_4476_aaaf_f10980dab348_vergunningplicht | pass |  |
| g001 | q_d_n45d6b9e0_518b_4bcc_b39a_b50cc3251539_vergunningplicht | pass |  |
| g001 | q_d_n6d45be8c_8010_4d11_8775_487a28b88087_niet_van_toepassing | pass |  |
| g001 | q_d_n8f6e3ddc_bba0_4b6c_bb24_6614f061332c_vergunningplicht | pass |  |
| g003 | q_d_n2bc68e71_981f_4476_aaaf_f10980dab348_vergunningplicht | pass |  |
| g003 | q_d_n45d6b9e0_518b_4bcc_b39a_b50cc3251539_vergunningplicht | pass |  |
| g003 | q_d_n6d45be8c_8010_4d11_8775_487a28b88087_niet_van_toepassing | pass |  |
| g003 | q_d_n8f6e3ddc_bba0_4b6c_bb24_6614f061332c_vergunningplicht | pass |  |
| g005 | q_d_n2bc68e71_981f_4476_aaaf_f10980dab348_vergunningplicht | pass |  |
| g005 | q_d_n45d6b9e0_518b_4bcc_b39a_b50cc3251539_vergunningplicht | pass |  |
| g005 | q_d_n6d45be8c_8010_4d11_8775_487a28b88087_niet_van_toepassing | pass |  |
| g005 | q_d_n8f6e3ddc_bba0_4b6c_bb24_6614f061332c_vergunningplicht | pass |  |
| g007 | q_d_n2bc68e71_981f_4476_aaaf_f10980dab348_vergunningplicht | pass |  |
| g007 | q_d_n45d6b9e0_518b_4bcc_b39a_b50cc3251539_vergunningplicht | pass |  |
| g007 | q_d_n6d45be8c_8010_4d11_8775_487a28b88087_niet_van_toepassing | pass |  |
| g007 | q_d_n8f6e3ddc_bba0_4b6c_bb24_6614f061332c_vergunningplicht | pass |  |
| g009 | q_d_n2bc68e71_981f_4476_aaaf_f10980dab348_vergunningplicht | pass |  |
| g009 | q_d_n45d6b9e0_518b_4bcc_b39a_b50cc3251539_vergunningplicht | pass |  |
| g009 | q_d_n6d45be8c_8010_4d11_8775_487a28b88087_niet_van_toepassing | pass |  |
| g009 | q_d_n8f6e3ddc_bba0_4b6c_bb24_6614f061332c_vergunningplicht | pass |  |
| g011 | q_d_n2bc68e71_981f_4476_aaaf_f10980dab348_vergunningplicht | pass |  |
| g011 | q_d_n45d6b9e0_518b_4bcc_b39a_b50cc3251539_vergunningplicht | pass |  |
| g011 | q_d_n6d45be8c_8010_4d11_8775_487a28b88087_niet_van_toepassing | pass |  |
| g011 | q_d_n8f6e3ddc_bba0_4b6c_bb24_6614f061332c_vergunningplicht | pass |  |
| g013 | q_d_n2bc68e71_981f_4476_aaaf_f10980dab348_vergunningplicht | pass |  |
| g013 | q_d_n45d6b9e0_518b_4bcc_b39a_b50cc3251539_vergunningplicht | pass |  |
| g013 | q_d_n6d45be8c_8010_4d11_8775_487a28b88087_niet_van_toepassing | pass |  |
| g013 | q_d_n8f6e3ddc_bba0_4b6c_bb24_6614f061332c_vergunningplicht | pass |  |
| g015 | q_d_n2bc68e71_981f_4476_aaaf_f10980dab348_vergunningplicht | pass |  |
| g015 | q_d_n45d6b9e0_518b_4bcc_b39a_b50cc3251539_vergunningplicht | pass |  |
| g015 | q_d_n6d45be8c_8010_4d11_8775_487a28b88087_niet_van_toepassing | pass |  |
| g015 | q_d_n8f6e3ddc_bba0_4b6c_bb24_6614f061332c_vergunningplicht | pass |  |
| g017 | q_d_n2bc68e71_981f_4476_aaaf_f10980dab348_vergunningplicht | pass |  |
| g017 | q_d_n45d6b9e0_518b_4bcc_b39a_b50cc3251539_vergunningplicht | pass |  |
| g017 | q_d_n6d45be8c_8010_4d11_8775_487a28b88087_niet_van_toepassing | pass |  |
| g017 | q_d_n8f6e3ddc_bba0_4b6c_bb24_6614f061332c_vergunningplicht | pass |  |
| g019 | q_d_n2bc68e71_981f_4476_aaaf_f10980dab348_vergunningplicht | pass |  |
| g019 | q_d_n45d6b9e0_518b_4bcc_b39a_b50cc3251539_vergunningplicht | pass |  |
| g019 | q_d_n6d45be8c_8010_4d11_8775_487a28b88087_niet_van_toepassing | pass |  |
| g019 | q_d_n8f6e3ddc_bba0_4b6c_bb24_6614f061332c_vergunningplicht | pass |  |
| g021 | q_d_n2bc68e71_981f_4476_aaaf_f10980dab348_vergunningplicht | pass |  |
| g021 | q_d_n45d6b9e0_518b_4bcc_b39a_b50cc3251539_vergunningplicht | pass |  |
| g021 | q_d_n6d45be8c_8010_4d11_8775_487a28b88087_niet_van_toepassing | pass |  |
| g021 | q_d_n8f6e3ddc_bba0_4b6c_bb24_6614f061332c_vergunningplicht | pass |  |
| g023 | q_d_n2bc68e71_981f_4476_aaaf_f10980dab348_vergunningplicht | pass |  |
| g023 | q_d_n45d6b9e0_518b_4bcc_b39a_b50cc3251539_vergunningplicht | pass |  |
| g023 | q_d_n6d45be8c_8010_4d11_8775_487a28b88087_niet_van_toepassing | pass |  |
| g023 | q_d_n8f6e3ddc_bba0_4b6c_bb24_6614f061332c_vergunningplicht | pass |  |


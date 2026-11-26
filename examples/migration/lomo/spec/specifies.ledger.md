# Migration ledger: specifies

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — specifies.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 12 |
| approximated | 0 |
| residue | 0 |
| **total** | 12 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/Rule_GDPR_Art4_7_Controller | *a thing* is a definition | encoded | 6 statements(6), one fact each | norm gdpr art 4 7 controller |  |
| http://example.org/Rule_GDPR_Art5_Principles | *a thing* is a constitutive rule | encoded | 3 statements(3), one fact each | norm gdpr art 5 principles |  |
| http://example.org/Rule_Dir2013_34_Art2_3_SmallUndertakings | *a thing* is a definition | encoded | 6 statements(6), one fact each | norm dir 2013 34 art 2 3 small undertakings |  |
| http://example.org/Rule_Dir2013_34_Art4_ReportingObligations | *a thing* is a prescriptive rule | encoded | 3 statements(3), one fact each | norm dir 2013 34 art 4 reporting obligations |  |
| http://example.org/Rule_OrgFarm_Art3_GeneralObligation | *a thing* is a prescriptive rule | encoded | 5 statements(5), one fact each | norm org farm art 3 general obligation |  |
| http://example.org/Rule_OrgFarm_Art10_CropProduction | *a thing* is a substantive rule | encoded | 7 statements(7), one fact each | norm org farm art 10 crop production |  |
| http://example.org/Rule_eIDAS_Art4_27_eID | *a thing* is a definition | encoded | 6 statements(6), one fact each | norm e idas art 4 27 e id |  |
| http://example.org/Rule_eIDAS_Art6_IdentityRequirements | *a thing* is a constitutive rule | encoded | 3 statements(3), one fact each | norm e idas art 6 identity requirements |  |
| http://example.org/Rule_Dir2013_34_Art4_ReportingObligations | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_Dir2013_34_Art4_ReportingObligations has no hasDeonticModality (LOMO asks for one) |
| http://example.org/Rule_Dir2013_34_Art4_ReportingObligations | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_Dir2013_34_Art4_ReportingObligations has no produces (LOMO asks for one) |
| http://example.org/Rule_OrgFarm_Art10_CropProduction | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_OrgFarm_Art10_CropProduction has no produces (LOMO asks for one) |
| http://example.org/Rule_OrgFarm_Art3_GeneralObligation | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_OrgFarm_Art3_GeneralObligation has no produces (LOMO asks for one) |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| description | modalities | pass |  |


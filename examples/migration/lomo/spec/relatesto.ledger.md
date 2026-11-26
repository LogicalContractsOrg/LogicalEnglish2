# Migration ledger: relatesto

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — relatesTo.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 14 |
| approximated | 0 |
| residue | 0 |
| **total** | 14 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/Rule_GDPR_Art5_Principles | *a thing* is a constitutive rule | encoded | 5 statements(5), one fact each | norm gdpr art 5 principles | kept in the generic form (no word in lomo.le): skos:note |
| http://example.org/Rule_GDPR_Art6_LawfulBasis | *a thing* is a constitutive rule | encoded | 3 statements(3), one fact each | norm gdpr art 6 lawful basis |  |
| http://example.org/Rule_FinRep_Art4_DataRequirements | *a thing* is a prescriptive rule | encoded | 5 statements(5), one fact each | norm fin rep art 4 data requirements | kept in the generic form (no word in lomo.le): skos:note |
| http://example.org/Rule_FinRep_Art5_DataVerification | *a thing* is a prescriptive rule | encoded | 3 statements(3), one fact each | norm fin rep art 5 data verification |  |
| http://example.org/Rule_EIA_Art5_PublicConsultation | *a thing* is a prescriptive rule | encoded | 5 statements(5), one fact each | norm eia art 5 public consultation | kept in the generic form (no word in lomo.le): skos:note |
| http://example.org/Rule_EIA_Art6_ScreeningRequirements | *a thing* is a prescriptive rule | encoded | 3 statements(3), one fact each | norm eia art 6 screening requirements |  |
| http://example.org/Rule_EIA_Art5_PublicConsultation | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_EIA_Art5_PublicConsultation has no hasDeonticModality (LOMO asks for one) |
| http://example.org/Rule_EIA_Art5_PublicConsultation | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_EIA_Art5_PublicConsultation has no produces (LOMO asks for one) |
| http://example.org/Rule_EIA_Art6_ScreeningRequirements | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_EIA_Art6_ScreeningRequirements has no hasDeonticModality (LOMO asks for one) |
| http://example.org/Rule_EIA_Art6_ScreeningRequirements | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_EIA_Art6_ScreeningRequirements has no produces (LOMO asks for one) |
| http://example.org/Rule_FinRep_Art4_DataRequirements | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_FinRep_Art4_DataRequirements has no hasDeonticModality (LOMO asks for one) |
| http://example.org/Rule_FinRep_Art4_DataRequirements | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_FinRep_Art4_DataRequirements has no produces (LOMO asks for one) |
| http://example.org/Rule_FinRep_Art5_DataVerification | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_FinRep_Art5_DataVerification has no hasDeonticModality (LOMO asks for one) |
| http://example.org/Rule_FinRep_Art5_DataVerification | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Rule_FinRep_Art5_DataVerification has no produces (LOMO asks for one) |


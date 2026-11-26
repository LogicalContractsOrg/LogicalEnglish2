# Migration ledger: antidumping_microdisks_lomo_instances

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — antidumping-microdisks-lomo-instances.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 48 |
| approximated | 0 |
| residue | 0 |
| **total** | 48 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://data.europa.eu/leg/lomo/antidumping-microdisks | owl:Ontology | encoded | 7 statements(7), one fact each | antidumping microdisks | kept in the generic form (no word in lomo.le): dcterms:created, dcterms:modified, dcterms:source, owl:imports |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#AgentType_CustomsAuthorities | agent type | encoded | 5 statements(5), one fact each | agent type customs authorities |  |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#AgentType_Importers | agent type | encoded | 5 statements(5), one fact each | agent type importers |  |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#AgentType_MemberStates | agent type | encoded | 5 statements(5), one fact each | agent type member states |  |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Agent_MemorexTelexJapan | agent | encoded | 5 statements(5), one fact each | agent memorex telex japan | kept in the generic form (no word in lomo.le): http://data.europa.eu/leg/lomo/antidumping-microdisks#taricAdditionalCode |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Agent_HitachiMaxell | agent | encoded | 5 statements(5), one fact each | agent hitachi maxell | kept in the generic form (no word in lomo.le): http://data.europa.eu/leg/lomo/antidumping-microdisks#taricAdditionalCode |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Agent_TDK | agent | encoded | 5 statements(5), one fact each | agent tdk | kept in the generic form (no word in lomo.le): http://data.europa.eu/leg/lomo/antidumping-microdisks#taricAdditionalCode |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Agent_CISTechnology | agent | encoded | 5 statements(5), one fact each | agent cis technology | kept in the generic form (no word in lomo.le): http://data.europa.eu/leg/lomo/antidumping-microdisks#taricAdditionalCode |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Agent_HannyMagnetics | agent | encoded | 5 statements(5), one fact each | agent hanny magnetics | kept in the generic form (no word in lomo.le): http://data.europa.eu/leg/lomo/antidumping-microdisks#taricAdditionalCode |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Def_Microdisks | *a thing* is a definition | encoded | 8 statements(8), one fact each | def microdisks | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Def_ExcludedMicrodisks | *a thing* is a definition | encoded | 8 statements(8), one fact each | def excluded microdisks | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Def_NetFreeAtCommunityFrontierPrice | *a thing* is a definition | encoded | 7 statements(7), one fact each | def net free at community frontier price | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#DutyRate_Japan_General | action result | encoded | 7 statements(7), one fact each | duty rate japan general | kept in the generic form (no word in lomo.le): http://data.europa.eu/leg/lomo/antidumping-microdisks#countryOfOrigin, http://data.europa.eu/leg/lomo/antidumping-microdisks#dutyPercentage, skos:notation |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#DutyRate_MemorexTelexJapan | action result | encoded | 7 statements(7), one fact each | duty rate memorex telex japan | kept in the generic form (no word in lomo.le): http://data.europa.eu/leg/lomo/antidumping-microdisks#companyExporter, http://data.europa.eu/leg/lomo/antidumping-microdisks#dutyPercentage, skos:notation |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#DutyRate_HitachiMaxell | action result | encoded | 7 statements(7), one fact each | duty rate hitachi maxell | kept in the generic form (no word in lomo.le): http://data.europa.eu/leg/lomo/antidumping-microdisks#companyExporter, http://data.europa.eu/leg/lomo/antidumping-microdisks#dutyPercentage, skos:notation |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#DutyRate_TDK | action result | encoded | 7 statements(7), one fact each | duty rate tdk | kept in the generic form (no word in lomo.le): http://data.europa.eu/leg/lomo/antidumping-microdisks#companyExporter, http://data.europa.eu/leg/lomo/antidumping-microdisks#dutyPercentage, skos:notation |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#DutyRate_Taiwan_General | action result | encoded | 7 statements(7), one fact each | duty rate taiwan general | kept in the generic form (no word in lomo.le): http://data.europa.eu/leg/lomo/antidumping-microdisks#countryOfOrigin, http://data.europa.eu/leg/lomo/antidumping-microdisks#dutyPercentage, skos:notation |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#DutyRate_CISTechnology | action result | encoded | 7 statements(7), one fact each | duty rate cis technology | kept in the generic form (no word in lomo.le): http://data.europa.eu/leg/lomo/antidumping-microdisks#companyExporter, http://data.europa.eu/leg/lomo/antidumping-microdisks#dutyPercentage, skos:notation |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#DutyRate_China_General | action result | encoded | 7 statements(7), one fact each | duty rate china general | kept in the generic form (no word in lomo.le): http://data.europa.eu/leg/lomo/antidumping-microdisks#countryOfOrigin, http://data.europa.eu/leg/lomo/antidumping-microdisks#dutyPercentage, skos:notation |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#DutyRate_HannyMagnetics | action result | encoded | 7 statements(7), one fact each | duty rate hanny magnetics | kept in the generic form (no word in lomo.le): http://data.europa.eu/leg/lomo/antidumping-microdisks#companyExporter, http://data.europa.eu/leg/lomo/antidumping-microdisks#dutyPercentage, skos:notation |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#TriggerInstant_PublicationOJ | *a thing* is a temporal specification | encoded | 7 statements(7), one fact each | trigger instant publication oj | words of LOMO before 1.1.0: lomo:triggerDescription |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#TriggerInstant_ProvisionalDuty | *a thing* is a temporal specification | encoded | 6 statements(6), one fact each | trigger instant provisional duty | words of LOMO before 1.1.0: lomo:triggerDescription |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Condition_ProductsFromJapan | owl:NamedIndividual | encoded | 4 statements(4), one fact each | condition products from japan | words of LOMO before 1.1.0: lomo:LegalCondition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Condition_ProductsFromTaiwan | owl:NamedIndividual | encoded | 4 statements(4), one fact each | condition products from taiwan | words of LOMO before 1.1.0: lomo:LegalCondition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Condition_ProductsFromChina | owl:NamedIndividual | encoded | 4 statements(4), one fact each | condition products from china | words of LOMO before 1.1.0: lomo:LegalCondition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Condition_ManufacturedBySoldBy | owl:NamedIndividual | encoded | 5 statements(5), one fact each | condition manufactured by sold by | words of LOMO before 1.1.0: lomo:LegalCondition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Condition_ProvisionalDutyExceedsDefinitive | owl:NamedIndividual | encoded | 4 statements(4), one fact each | condition provisional duty exceeds definitive | words of LOMO before 1.1.0: lomo:LegalCondition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Condition_AmountsSecuredInExcess | owl:NamedIndividual | encoded | 4 statements(4), one fact each | condition amounts secured in excess | words of LOMO before 1.1.0: lomo:LegalCondition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Requirement_Art1_Par1_ImposeDuty | *a thing* is a constitutive rule | encoded | 8 statements(8), one fact each | requirement art 1 par 1 impose duty | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Requirement_Art1_Par2_DutyRates | *a thing* is a prescriptive rule | encoded | 11 statements(11), one fact each | requirement art 1 par 2 duty rates | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Requirement_Art1_Par2_a_Japan | *a thing* is a prescriptive rule | encoded | 15 statements(15), one fact each | requirement art 1 par 2 a japan | words of LOMO before 1.1.0: lomo:hasCondition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Requirement_Art1_Par2_b_Taiwan | *a thing* is a prescriptive rule | encoded | 13 statements(13), one fact each | requirement art 1 par 2 b taiwan | words of LOMO before 1.1.0: lomo:hasCondition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Requirement_Art1_Par2_c_China | *a thing* is a prescriptive rule | encoded | 13 statements(13), one fact each | requirement art 1 par 2 c china | words of LOMO before 1.1.0: lomo:hasCondition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Requirement_Art1_Par3_CustomsProvisions | *a thing* is a prescriptive rule | encoded | 9 statements(9), one fact each | requirement art 1 par 3 customs provisions |  |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Action_ApplyDutyRate | action | encoded | 5 statements(5), one fact each | action apply duty rate |  |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#AgentRole_CustomsAuthorities_Applier | agent role | encoded | 5 statements(5), one fact each | agent role customs authorities applier |  |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Requirement_Art2_Par1_DefinitiveCollection | *a thing* is a prescriptive rule | encoded | 10 statements(10), one fact each | requirement art 2 par 1 definitive collection | words of LOMO before 1.1.0: lomo:hasCondition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Requirement_Art2_Par2_ReleaseExcess | *a thing* is a prescriptive rule | encoded | 10 statements(10), one fact each | requirement art 2 par 2 release excess | words of LOMO before 1.1.0: lomo:hasCondition |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Action_CollectProvisionalDuty | action | encoded | 5 statements(5), one fact each | action collect provisional duty |  |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Action_ReleaseExcessAmounts | action | encoded | 5 statements(5), one fact each | action release excess amounts |  |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#AgentRole_CustomsAuthorities_Collector | agent role | encoded | 5 statements(5), one fact each | agent role customs authorities collector |  |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#AgentRole_CustomsAuthorities_Releaser | agent role | encoded | 5 statements(5), one fact each | agent role customs authorities releaser |  |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Requirement_Art3_EntryIntoForce | *a thing* is a constitutive rule | encoded | 7 statements(7), one fact each | requirement art 3 entry into force |  |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#Requirement_Art3_DirectApplicability | *a thing* is a constitutive rule | encoded | 6 statements(6), one fact each | requirement art 3 direct applicability |  |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#taricAdditionalCode | owl:DatatypeProperty | encoded | 5 statements(5), one fact each | taric additional code | kept in the generic form (no word in lomo.le): rdfs:domain, rdfs:range |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#dutyPercentage | owl:DatatypeProperty | encoded | 5 statements(5), one fact each | duty percentage | kept in the generic form (no word in lomo.le): rdfs:domain, rdfs:range |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#countryOfOrigin | owl:DatatypeProperty | encoded | 5 statements(5), one fact each | country of origin | kept in the generic form (no word in lomo.le): rdfs:domain, rdfs:range |
| http://data.europa.eu/leg/lomo/antidumping-microdisks#companyExporter | owl:ObjectProperty | encoded | 5 statements(5), one fact each | company exporter | kept in the generic form (no word in lomo.le): rdfs:domain, rdfs:range |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| description | modalities | pass |  |
| description | actions_of_rules | pass |  |
| description | actions_of_agents | pass |  |


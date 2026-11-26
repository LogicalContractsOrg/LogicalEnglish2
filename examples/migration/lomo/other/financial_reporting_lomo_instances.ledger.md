# Migration ledger: financial_reporting_lomo_instances

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — financial-reporting-lomo-instances.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 108 |
| approximated | 0 |
| residue | 0 |
| **total** | 108 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://data.europa.eu/leg/lomo/financial-reporting | owl:Ontology | encoded | 7 statements(7), one fact each | financial reporting | kept in the generic form (no word in lomo.le): dcterms:created, dcterms:source, owl:imports |
| http://data.europa.eu/leg/lomo/financial-reporting#Agent_Commission | agent | encoded | 4 statements(4), one fact each | agent commission |  |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentType_MemberStates | agent type | encoded | 4 statements(4), one fact each | agent type member states |  |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentType_StatutoryAuditor | agent type | encoded | 4 statements(4), one fact each | agent type statutory auditor |  |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentType_MicroUndertaking | agent type | encoded | 5 statements(5), one fact each | agent type micro undertaking | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentType_SmallUndertaking | agent type | encoded | 5 statements(5), one fact each | agent type small undertaking | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentType_MediumSizedUndertaking | agent type | encoded | 5 statements(5), one fact each | agent type medium sized undertaking | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentType_LargeUndertaking | agent type | encoded | 5 statements(5), one fact each | agent type large undertaking | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentType_PublicInterestEntity | agent type | encoded | 5 statements(5), one fact each | agent type public interest entity | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentType_Undertaking | agent type | encoded | 4 statements(4), one fact each | agent type undertaking |  |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentType_ParentUndertaking | agent type | encoded | 5 statements(5), one fact each | agent type parent undertaking | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentType_SmallGroup | agent type | encoded | 5 statements(5), one fact each | agent type small group | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentType_MediumGroup | agent type | encoded | 5 statements(5), one fact each | agent type medium group | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentType_LargeGroup | agent type | encoded | 5 statements(5), one fact each | agent type large group | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentRole_MS_OptionHolder | agent role | encoded | 5 statements(5), one fact each | agent role ms option holder |  |
| http://data.europa.eu/leg/lomo/financial-reporting#ResultType_FinancialStatements | action result type | encoded | 4 statements(4), one fact each | result type financial statements |  |
| http://data.europa.eu/leg/lomo/financial-reporting#ResultType_ManagementReport | action result type | encoded | 4 statements(4), one fact each | result type management report |  |
| http://data.europa.eu/leg/lomo/financial-reporting#ResultType_AuditorOpinion | action result type | encoded | 4 statements(4), one fact each | result type auditor opinion |  |
| http://data.europa.eu/leg/lomo/financial-reporting#ResultType_ConsolidatedStatements | action result type | encoded | 4 statements(4), one fact each | result type consolidated statements |  |
| http://data.europa.eu/leg/lomo/financial-reporting#ResultType_ConsolidatedFinancialStatements | action result type | encoded | 4 statements(4), one fact each | result type consolidated financial statements |  |
| http://data.europa.eu/leg/lomo/financial-reporting#ResultType_ConsolidatedManagementReport | action result type | encoded | 4 statements(4), one fact each | result type consolidated management report |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Frequency_Annual | owl:NamedIndividual | encoded | 6 statements(6), one fact each | frequency annual | words of LOMO before 1.1.0: lomo:frequencyUnit, lomo:frequencyValue |
| http://data.europa.eu/leg/lomo/financial-reporting#Frequency_FiveYears | owl:NamedIndividual | encoded | 6 statements(6), one fact each | frequency five years | words of LOMO before 1.1.0: lomo:frequencyUnit, lomo:frequencyValue |
| http://data.europa.eu/leg/lomo/financial-reporting#TriggerInstant_BalanceSheetDate | *a thing* is a temporal specification | encoded | 6 statements(6), one fact each | trigger instant balance sheet date | words of LOMO before 1.1.0: lomo:triggerDescription |
| http://data.europa.eu/leg/lomo/financial-reporting#TemporalSpec_12MonthsAfterBalanceSheet | owl:NamedIndividual | encoded | 7 statements(7), one fact each | temporal spec 12 months after balance sheet | words of LOMO before 1.1.0: lomo:hasDuration, lomo:hasStart |
| http://data.europa.eu/leg/lomo/financial-reporting#TemporalSpec_TranspositionDeadline | *a thing* is a temporal specification | encoded | 7 statements(7), one fact each | temporal spec transposition deadline | words of LOMO before 1.1.0: lomo:triggerDescription |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_PublicInterestEntity | *a thing* is a definition | encoded | 6 statements(6), one fact each | def public interest entity |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_ParticipatingInterest | *a thing* is a definition | encoded | 7 statements(7), one fact each | def participating interest | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_RelatedParty | *a thing* is a definition | encoded | 7 statements(7), one fact each | def related party | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_FixedAssets | *a thing* is a definition | encoded | 7 statements(7), one fact each | def fixed assets | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_NetTurnover | *a thing* is a definition | encoded | 14 statements(14), one fact each | def net turnover | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_PurchasePrice | *a thing* is a definition | encoded | 7 statements(7), one fact each | def purchase price | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_ProductionCost | *a thing* is a definition | encoded | 7 statements(7), one fact each | def production cost | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_ValueAdjustment | *a thing* is a definition | encoded | 7 statements(7), one fact each | def value adjustment | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_ParentUndertaking | *a thing* is a definition | encoded | 7 statements(7), one fact each | def parent undertaking | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_SubsidiaryUndertaking | *a thing* is a definition | encoded | 7 statements(7), one fact each | def subsidiary undertaking | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_Group | *a thing* is a definition | encoded | 7 statements(7), one fact each | def group | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_AffiliatedUndertakings | *a thing* is a definition | encoded | 7 statements(7), one fact each | def affiliated undertakings | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_AssociatedUndertaking | *a thing* is a definition | encoded | 7 statements(7), one fact each | def associated undertaking | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_InvestmentUndertakings | *a thing* is a definition | encoded | 7 statements(7), one fact each | def investment undertakings | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_FinancialHoldingUndertakings | *a thing* is a definition | encoded | 7 statements(7), one fact each | def financial holding undertakings | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_Material | *a thing* is a definition | encoded | 7 statements(7), one fact each | def material | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_MicroUndertaking | *a thing* is a definition | encoded | 7 statements(7), one fact each | def micro undertaking | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_SmallUndertaking | *a thing* is a definition | encoded | 7 statements(7), one fact each | def small undertaking | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_MediumSizedUndertaking | *a thing* is a definition | encoded | 7 statements(7), one fact each | def medium sized undertaking | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_LargeUndertaking | *a thing* is a definition | encoded | 7 statements(7), one fact each | def large undertaking | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_SmallGroup | *a thing* is a definition | encoded | 7 statements(7), one fact each | def small group | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_MediumSizedGroup | *a thing* is a definition | encoded | 7 statements(7), one fact each | def medium sized group | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_LargeGroup | *a thing* is a definition | encoded | 7 statements(7), one fact each | def large group | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_BalanceSheetTotal | *a thing* is a definition | encoded | 7 statements(7), one fact each | def balance sheet total | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art3_MicroUndertakingDefinition | *a thing* is a constitutive rule | encoded | 8 statements(8), one fact each | requirement art 3 micro undertaking definition |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art3_SmallUndertakingDefinition | *a thing* is a constitutive rule | encoded | 8 statements(8), one fact each | requirement art 3 small undertaking definition |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art3_MediumSizedUndertakingDefinition | *a thing* is a constitutive rule | encoded | 8 statements(8), one fact each | requirement art 3 medium sized undertaking definition |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art3_LargeUndertakingDefinition | *a thing* is a constitutive rule | encoded | 8 statements(8), one fact each | requirement art 3 large undertaking definition |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art3_Par5_SmallGroupDefinition | *a thing* is a constitutive rule | encoded | 8 statements(8), one fact each | requirement art 3 par 5 small group definition |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art3_Par6_MediumGroupDefinition | *a thing* is a constitutive rule | encoded | 8 statements(8), one fact each | requirement art 3 par 6 medium group definition |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art3_Par7_LargeGroupDefinition | *a thing* is a constitutive rule | encoded | 8 statements(8), one fact each | requirement art 3 par 7 large group definition |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art3_Par8_SetOffProvision | *a thing* is a constitutive rule | encoded | 6 statements(6), one fact each | requirement art 3 par 8 set off provision |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art3_Par9_CurrencyConversion | *a thing* is a constitutive rule | encoded | 6 statements(6), one fact each | requirement art 3 par 9 currency conversion |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art3_Par10_ConsecutiveYearsRule | *a thing* is a constitutive rule | encoded | 6 statements(6), one fact each | requirement art 3 par 10 consecutive years rule |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art3_Par11_BalanceSheetTotalDefinition | *a thing* is a constitutive rule | encoded | 7 statements(7), one fact each | requirement art 3 par 11 balance sheet total definition |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art3_Par12_AnnualThresholdCalculation | *a thing* is a constitutive rule | encoded | 7 statements(7), one fact each | requirement art 3 par 12 annual threshold calculation |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art3_Par13_CommissionReviewThresholds | *a thing* is a prescriptive rule | encoded | 9 statements(9), one fact each | requirement art 3 par 13 commission review thresholds |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art3_ReviewThresholds | action | encoded | 5 statements(5), one fact each | action art 3 review thresholds |  |
| http://data.europa.eu/leg/lomo/financial-reporting#TemporalSpec_Art3_FiveYearReview | owl:NamedIndividual | encoded | 5 statements(5), one fact each | temporal spec art 3 five year review | words of LOMO before 1.1.0: lomo:hasFrequency |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentRole_Art3_Commission_Reviewer | agent role | encoded | 4 statements(4), one fact each | agent role art 3 commission reviewer |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_ManagementReport | *a thing* is a definition | encoded | 7 statements(7), one fact each | def management report | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_KeyPerformanceIndicators | *a thing* is a definition | encoded | 7 statements(7), one fact each | def key performance indicators | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art19_Par1_ManagementReportContent | *a thing* is a prescriptive rule | encoded | 12 statements(12), one fact each | requirement art 19 par 1 management report content |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art19_Par2_AdditionalInfo | *a thing* is a prescriptive rule | encoded | 10 statements(10), one fact each | requirement art 19 par 2 additional info |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art19_Par3_ExemptSmallUndertakings | *a thing* is a prescriptive rule | encoded | 9 statements(9), one fact each | requirement art 19 par 3 exempt small undertakings | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art19_Par4_ExemptSmallMediumNonFinancial | *a thing* is a prescriptive rule | encoded | 10 statements(10), one fact each | requirement art 19 par 4 exempt small medium non | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art19_PrepareManagementReport | action | encoded | 6 statements(6), one fact each | action art 19 prepare management report |  |
| http://data.europa.eu/leg/lomo/financial-reporting#TemporalSpec_Art19_AnnualReporting | owl:NamedIndividual | encoded | 5 statements(5), one fact each | temporal spec art 19 annual reporting | words of LOMO before 1.1.0: lomo:hasFrequency |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art19_IncludeAdditionalInfo | action | encoded | 5 statements(5), one fact each | action art 19 include additional info |  |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentRole_Art19_Undertaking_Preparer | agent role | encoded | 5 statements(5), one fact each | agent role art 19 undertaking preparer |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Result_ManagementReport | action result | encoded | 4 statements(4), one fact each | result management report | words of LOMO before 1.1.0: lomo:hasResultType |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art19_ExemptSmallFromManagementReport | action | encoded | 5 statements(5), one fact each | action art 19 exempt small from management report |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art19_ExemptSmallMediumFromNonFinancialInfo | action | encoded | 5 statements(5), one fact each | action art 19 exempt small medium from non financial |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art30_Par1_PublicationObligation | *a thing* is a prescriptive rule | encoded | 10 statements(10), one fact each | requirement art 30 par 1 publication obligation |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art30_Par2_ExemptAnnexII | *a thing* is a prescriptive rule | encoded | 8 statements(8), one fact each | requirement art 30 par 2 exempt annex ii |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art30_Par3_ConsolidatedStatements | *a thing* is a prescriptive rule | encoded | 10 statements(10), one fact each | requirement art 30 par 3 consolidated statements |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art30_Publish | action | encoded | 6 statements(6), one fact each | action art 30 publish |  |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentRole_Art30_Undertaking_Publisher | agent role | encoded | 5 statements(5), one fact each | agent role art 30 undertaking publisher |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Result_PublishedStatements | action result | encoded | 6 statements(6), one fact each | result published statements | words of LOMO before 1.1.0: lomo:hasResultType |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art30_PublishConsolidated | action | encoded | 6 statements(6), one fact each | action art 30 publish consolidated |  |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentRole_Art30_ParentUndertaking_Publisher | agent role | encoded | 5 statements(5), one fact each | agent role art 30 parent undertaking publisher |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Result_PublishedConsolidatedStatements | action result | encoded | 5 statements(5), one fact each | result published consolidated statements | words of LOMO before 1.1.0: lomo:hasResultType |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art30_ExemptAnnexIIFromPublication | action | encoded | 5 statements(5), one fact each | action art 30 exempt annex ii from publication |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art31_Par1_ExemptSmallFromPublication | *a thing* is a prescriptive rule | encoded | 9 statements(9), one fact each | requirement art 31 par 1 exempt small from publication | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art31_Par2_PermitMediumSizedAbridged | *a thing* is a prescriptive rule | encoded | 9 statements(9), one fact each | requirement art 31 par 2 permit medium sized abridged | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art31_ExemptSmallFromPublication | action | encoded | 5 statements(5), one fact each | action art 31 exempt small from publication |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art31_PermitMediumSizedAbridgedPublication | action | encoded | 5 statements(5), one fact each | action art 31 permit medium sized abridged publication |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Def_Transposition | *a thing* is a definition | encoded | 7 statements(7), one fact each | def transposition | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art53_Par1_TranspositionObligation | *a thing* is a prescriptive rule | encoded | 11 statements(11), one fact each | requirement art 53 par 1 transposition obligation |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art53_Par1_Sub2_DelayedApplication | *a thing* is a prescriptive rule | encoded | 9 statements(9), one fact each | requirement art 53 par 1 sub 2 delayed application |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art53_Par1_Sub3_ReferenceObligation | *a thing* is a prescriptive rule | encoded | 9 statements(9), one fact each | requirement art 53 par 1 sub 3 reference obligation |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Requirement_Art53_Par2_CommunicateText | *a thing* is a prescriptive rule | encoded | 9 statements(9), one fact each | requirement art 53 par 2 communicate text |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art53_BringIntoForce | action | encoded | 5 statements(5), one fact each | action art 53 bring into force |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art53_InformCommission | action | encoded | 6 statements(6), one fact each | action art 53 inform commission |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art53_CommunicateText | action | encoded | 5 statements(5), one fact each | action art 53 communicate text |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art53_DeferApplicationTo2016 | action | encoded | 5 statements(5), one fact each | action art 53 defer application to 2016 |  |
| http://data.europa.eu/leg/lomo/financial-reporting#Action_Art53_IncludeReferenceToDirective | action | encoded | 5 statements(5), one fact each | action art 53 include reference to directive |  |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentRole_Art53_MS_Transposer | agent role | encoded | 4 statements(4), one fact each | agent role art 53 ms transposer |  |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentRole_Art53_MS_Informer | agent role | encoded | 4 statements(4), one fact each | agent role art 53 ms informer |  |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentRole_Art53_Commission_Informed | agent role | encoded | 4 statements(4), one fact each | agent role art 53 commission informed |  |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentRole_Art53_MS_Communicator | agent role | encoded | 4 statements(4), one fact each | agent role art 53 ms communicator |  |
| http://data.europa.eu/leg/lomo/financial-reporting#AgentRole_Art53_Commission_Recipient | agent role | encoded | 4 statements(4), one fact each | agent role art 53 commission recipient |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| description | modalities | pass |  |
| description | actions_of_rules | pass |  |
| description | actions_of_agents | pass |  |


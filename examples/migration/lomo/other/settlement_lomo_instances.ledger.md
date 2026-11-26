# Migration ledger: settlement_lomo_instances

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — settlement-lomo-instances.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 116 |
| approximated | 0 |
| residue | 0 |
| **total** | 116 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://data.europa.eu/leg/lomo/test | owl:Ontology | encoded | 6 statements(6), one fact each | test | kept in the generic form (no word in lomo.le): dcterms:created, dcterms:modified, owl:imports |
| http://data.europa.eu/leg/lomo/test#Agent_ESMA | agent | encoded | 3 statements(3), one fact each | agent esma |  |
| http://data.europa.eu/leg/lomo/test#Agent_EBA | agent | encoded | 3 statements(3), one fact each | agent eba |  |
| http://data.europa.eu/leg/lomo/test#Agent_ESCB | agent | encoded | 3 statements(3), one fact each | agent escb |  |
| http://data.europa.eu/leg/lomo/test#Agent_CompetentAuthority | agent type | encoded | 3 statements(3), one fact each | agent competent authority |  |
| http://data.europa.eu/leg/lomo/test#Agent_SystemOperator | agent type | encoded | 3 statements(3), one fact each | agent system operator |  |
| http://data.europa.eu/leg/lomo/test#Agent_ThirdCountrySystemOperator | agent type | encoded | 3 statements(3), one fact each | agent third country system operator |  |
| http://data.europa.eu/leg/lomo/test#Agent_RegisteringAuthority | agent type | encoded | 3 statements(3), one fact each | agent registering authority |  |
| http://data.europa.eu/leg/lomo/test#Agent_NationalCompetentAuthority | agent type | encoded | 3 statements(3), one fact each | agent national competent authority |  |
| http://data.europa.eu/leg/lomo/test#Agent_DesignatingAuthority | agent type | encoded | 3 statements(3), one fact each | agent designating authority |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article26_CentralDatabase | *a thing* is a prescriptive rule | encoded | 16 statements(16), one fact each | norm article 26 central database |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article4_ElectronicApplication | *a thing* is a prescriptive rule | encoded | 20 statements(20), one fact each | norm article 4 electronic application |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article6_Notification | *a thing* is a prescriptive rule | encoded | 18 statements(18), one fact each | norm article 6 notification |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article8_ChangesNotification | *a thing* is a prescriptive rule | encoded | 18 statements(18), one fact each | norm article 8 changes notification |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article9_WithdrawalNotification | *a thing* is a prescriptive rule | encoded | 23 statements(23), one fact each | norm article 9 withdrawal notification |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article10_CompetentAuthorityNotification | *a thing* is a prescriptive rule | encoded | 17 statements(17), one fact each | norm article 10 competent authority notification |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article11_InformationExchange | *a thing* is a prescriptive rule | encoded | 30 statements(30), one fact each | norm article 11 information exchange |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article13_RegistrationApplication | *a thing* is a prescriptive rule | encoded | 21 statements(21), one fact each | norm article 13 registration application |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article15_RegistrationNotification | *a thing* is a prescriptive rule | encoded | 22 statements(22), one fact each | norm article 15 registration notification |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article16_RegistrationWithdrawalNotification | *a thing* is a prescriptive rule | encoded | 23 statements(23), one fact each | norm article 16 registration withdrawal notification |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article22_InsolvencyNotification | *a thing* is a prescriptive rule | encoded | 22 statements(22), one fact each | norm article 22 insolvency notification |  |
| http://data.europa.eu/leg/lomo/test#Action_ESMA_EstablishDatabase | action | encoded | 6 statements(6), one fact each | action esma establish database |  |
| http://data.europa.eu/leg/lomo/test#Action_SystemOperator_SubmitApplication | action | encoded | 8 statements(8), one fact each | action system operator submit application |  |
| http://data.europa.eu/leg/lomo/test#Result_ApplicationSubmission | action result | encoded | 6 statements(6), one fact each | result application submission |  |
| http://data.europa.eu/leg/lomo/test#Action_CompetentAuthority_NotifyDesignation | action | encoded | 8 statements(8), one fact each | action competent authority notify designation |  |
| http://data.europa.eu/leg/lomo/test#Result_DesignationNotification | action result | encoded | 6 statements(6), one fact each | result designation notification |  |
| http://data.europa.eu/leg/lomo/test#Action_SystemOperator_NotifyChanges | action | encoded | 8 statements(8), one fact each | action system operator notify changes |  |
| http://data.europa.eu/leg/lomo/test#Action_CompetentAuthority_NotifyWithdrawal | action | encoded | 12 statements(12), one fact each | action competent authority notify withdrawal |  |
| http://data.europa.eu/leg/lomo/test#Action_MemberState_NotifyAuthorities | action | encoded | 7 statements(7), one fact each | action member state notify authorities |  |
| http://data.europa.eu/leg/lomo/test#Action_Authorities_ExchangeInformation | action | encoded | 19 statements(19), one fact each | action authorities exchange information |  |
| http://data.europa.eu/leg/lomo/test#Action_ThirdCountryOperator_SubmitRegistration | action | encoded | 9 statements(9), one fact each | action third country operator submit registration |  |
| http://data.europa.eu/leg/lomo/test#Action_RegisteringAuthority_NotifyRegistration | action | encoded | 12 statements(12), one fact each | action registering authority notify registration |  |
| http://data.europa.eu/leg/lomo/test#Action_RegisteringAuthority_NotifyWithdrawal | action | encoded | 12 statements(12), one fact each | action registering authority notify withdrawal |  |
| http://data.europa.eu/leg/lomo/test#Action_CompetentAuthority_NotifyInsolvency | action | encoded | 11 statements(11), one fact each | action competent authority notify insolvency |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_ESMA_DatabaseOperator | agent role | encoded | 4 statements(4), one fact each | agent role esma database operator |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_SystemOperator_Applicant | agent role | encoded | 4 statements(4), one fact each | agent role system operator applicant |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_CompetentAuthority_Recipient | agent role | encoded | 4 statements(4), one fact each | agent role competent authority recipient |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_CompetentAuthority_Notifier | agent role | encoded | 4 statements(4), one fact each | agent role competent authority notifier |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_ESMA_Recipient | agent role | encoded | 4 statements(4), one fact each | agent role esma recipient |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_SystemOperator_Notifier | agent role | encoded | 4 statements(4), one fact each | agent role system operator notifier |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_SystemOperator_Recipient | agent role | encoded | 4 statements(4), one fact each | agent role system operator recipient |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_ThirdCountryOperator_Recipient | agent role | encoded | 4 statements(4), one fact each | agent role third country operator recipient |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_NationalCompetentAuthority_Recipient | agent role | encoded | 4 statements(4), one fact each | agent role national competent authority recipient |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_DesignatingAuthority_Recipient | agent role | encoded | 4 statements(4), one fact each | agent role designating authority recipient |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_RegisteringAuthority_Recipient | agent role | encoded | 4 statements(4), one fact each | agent role registering authority recipient |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_EBA_Recipient | agent role | encoded | 4 statements(4), one fact each | agent role eba recipient |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_ESCB_Recipient | agent role | encoded | 4 statements(4), one fact each | agent role escb recipient |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_MemberState_Notifier | agent role | encoded | 4 statements(4), one fact each | agent role member state notifier |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_DesignatingAuthority_Sharer | agent role | encoded | 4 statements(4), one fact each | agent role designating authority sharer |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_RegisteringAuthority_Sharer | agent role | encoded | 4 statements(4), one fact each | agent role registering authority sharer |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_NationalCompetentAuthority_Sharer | agent role | encoded | 4 statements(4), one fact each | agent role national competent authority sharer |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_CompetentAuthority_Sharer | agent role | encoded | 4 statements(4), one fact each | agent role competent authority sharer |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_ESMA_Sharer | agent role | encoded | 4 statements(4), one fact each | agent role esma sharer |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_EBA_Sharer | agent role | encoded | 4 statements(4), one fact each | agent role eba sharer |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_ESCB_Sharer | agent role | encoded | 4 statements(4), one fact each | agent role escb sharer |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_ThirdCountryOperator_Applicant | agent role | encoded | 4 statements(4), one fact each | agent role third country operator applicant |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_RegisteringAuthority_Notifier | agent role | encoded | 4 statements(4), one fact each | agent role registering authority notifier |  |
| http://data.europa.eu/leg/lomo/test#TemporalSpec_Immediate | *a thing* is a temporal specification | encoded | 7 statements(7), one fact each | temporal spec immediate |  |
| http://data.europa.eu/leg/lomo/test#TemporalSpec_ApplicationPeriod | *a thing* is a temporal specification | encoded | 7 statements(7), one fact each | temporal spec application period |  |
| http://data.europa.eu/leg/lomo/test#TemporalSpec_Ongoing | *a thing* is a temporal specification | encoded | 6 statements(6), one fact each | temporal spec ongoing |  |
| http://data.europa.eu/leg/lomo/test#Result_CentralDatabase | action result | encoded | 5 statements(5), one fact each | result central database |  |
| http://data.europa.eu/leg/lomo/test#Result_ChangeNotification | action result | encoded | 6 statements(6), one fact each | result change notification |  |
| http://data.europa.eu/leg/lomo/test#Result_WithdrawalNotification | action result | encoded | 6 statements(6), one fact each | result withdrawal notification |  |
| http://data.europa.eu/leg/lomo/test#Result_AuthorityNotification | action result | encoded | 5 statements(5), one fact each | result authority notification |  |
| http://data.europa.eu/leg/lomo/test#Result_InformationExchange | action result | encoded | 5 statements(5), one fact each | result information exchange |  |
| http://data.europa.eu/leg/lomo/test#Result_RegistrationApplication | action result | encoded | 7 statements(7), one fact each | result registration application |  |
| http://data.europa.eu/leg/lomo/test#Result_RegistrationNotification | action result | encoded | 5 statements(5), one fact each | result registration notification |  |
| http://data.europa.eu/leg/lomo/test#Result_RegistrationWithdrawalNotification | action result | encoded | 6 statements(6), one fact each | result registration withdrawal notification |  |
| http://data.europa.eu/leg/lomo/test#Result_InsolvencyNotification | action result | encoded | 6 statements(6), one fact each | result insolvency notification |  |
| http://data.europa.eu/leg/lomo/test#Dataset_CentralDatabase | *a thing* is a dataset | encoded | 3 statements(3), one fact each | dataset central database |  |
| http://data.europa.eu/leg/lomo/test#Dataset_ApplicationRecords | *a thing* is a dataset | encoded | 3 statements(3), one fact each | dataset application records |  |
| http://data.europa.eu/leg/lomo/test#Dataset_NotificationRecords | *a thing* is a dataset | encoded | 3 statements(3), one fact each | dataset notification records |  |
| http://data.europa.eu/leg/lomo/test#Dataset_ChangeRecords | *a thing* is a dataset | encoded | 3 statements(3), one fact each | dataset change records |  |
| http://data.europa.eu/leg/lomo/test#Dataset_WithdrawalRecords | *a thing* is a dataset | encoded | 3 statements(3), one fact each | dataset withdrawal records |  |
| http://data.europa.eu/leg/lomo/test#Dataset_AuthorityRecords | *a thing* is a dataset | encoded | 3 statements(3), one fact each | dataset authority records |  |
| http://data.europa.eu/leg/lomo/test#Dataset_InformationExchange | *a thing* is a dataset | encoded | 3 statements(3), one fact each | dataset information exchange |  |
| http://data.europa.eu/leg/lomo/test#Dataset_RegistrationApplications | *a thing* is a dataset | encoded | 3 statements(3), one fact each | dataset registration applications |  |
| http://data.europa.eu/leg/lomo/test#Dataset_RegistrationNotifications | *a thing* is a dataset | encoded | 3 statements(3), one fact each | dataset registration notifications |  |
| http://data.europa.eu/leg/lomo/test#Dataset_WithdrawalNotifications | *a thing* is a dataset | encoded | 3 statements(3), one fact each | dataset withdrawal notifications |  |
| http://data.europa.eu/leg/lomo/test#Dataset_InsolvencyRecords | *a thing* is a dataset | encoded | 3 statements(3), one fact each | dataset insolvency records |  |
| http://data.europa.eu/leg/lomo/test#Dataset_DesignationApplicationData | *a thing* is a dataset | encoded | 4 statements(4), one fact each | dataset designation application data |  |
| http://data.europa.eu/leg/lomo/test#Dataset_RegistrationDesignationSSCS | *a thing* is a dataset | encoded | 4 statements(4), one fact each | dataset registration designation sscs |  |
| http://data.europa.eu/leg/lomo/test#Dataset_DesignationWithdrawal | *a thing* is a dataset | encoded | 3 statements(3), one fact each | dataset designation withdrawal |  |
| http://data.europa.eu/leg/lomo/test#Dataset_RegistrationDesignationPaymentSystems | *a thing* is a dataset | encoded | 4 statements(4), one fact each | dataset registration designation payment systems |  |
| http://data.europa.eu/leg/lomo/test#Dataset_RegistrationWithdrawal | *a thing* is a dataset | encoded | 3 statements(3), one fact each | dataset registration withdrawal |  |
| http://data.europa.eu/leg/lomo/test#Dataset_InsolvencyProceedings | *a thing* is a dataset | encoded | 3 statements(3), one fact each | dataset insolvency proceedings |  |
| http://data.europa.eu/leg/lomo/test#Standard_Article5_1 | *a thing* is a standard | encoded | 3 statements(3), one fact each | standard article 5 1 |  |
| http://data.europa.eu/leg/lomo/test#Standard_Article13_13 | *a thing* is a standard | encoded | 3 statements(3), one fact each | standard article 13 13 |  |
| http://data.europa.eu/leg/lomo/test#Standard_Article13_15 | *a thing* is a standard | encoded | 3 statements(3), one fact each | standard article 13 15 |  |
| http://data.europa.eu/leg/lomo/test#HighLevelProcessScheme | *a thing* is a concept scheme | encoded | 3 statements(3), one fact each | high level process scheme |  |
| http://data.europa.eu/leg/lomo/test#Process_DataSharing | *a thing* is a concept | encoded | 4 statements(4), one fact each | process data sharing |  |
| http://data.europa.eu/leg/lomo/test#Process_SystemRegistration | *a thing* is a concept | encoded | 4 statements(4), one fact each | process system registration |  |
| http://data.europa.eu/leg/lomo/test#Process_ApplicationSubmission | *a thing* is a concept | encoded | 4 statements(4), one fact each | process application submission |  |
| http://data.europa.eu/leg/lomo/test#Process_Notification | *a thing* is a concept | encoded | 4 statements(4), one fact each | process notification |  |
| http://data.europa.eu/leg/lomo/test#Process_ChangeManagement | *a thing* is a concept | encoded | 4 statements(4), one fact each | process change management |  |
| http://data.europa.eu/leg/lomo/test#Process_Withdrawal | *a thing* is a concept | encoded | 4 statements(4), one fact each | process withdrawal |  |
| http://data.europa.eu/leg/lomo/test#Process_AuthorityRegistration | *a thing* is a concept | encoded | 4 statements(4), one fact each | process authority registration |  |
| http://data.europa.eu/leg/lomo/test#Process_InformationExchange | *a thing* is a concept | encoded | 4 statements(4), one fact each | process information exchange |  |
| http://data.europa.eu/leg/lomo/test#Process_Registration | *a thing* is a concept | encoded | 4 statements(4), one fact each | process registration |  |
| http://data.europa.eu/leg/lomo/test#Process_InsolvencyHandling | *a thing* is a concept | encoded | 4 statements(4), one fact each | process insolvency handling |  |
| http://data.europa.eu/leg/lomo/test#DigitalSolution_CentralDatabase | owl:NamedIndividual | encoded | 16 statements(16), one fact each | digital solution central database | words of LOMO before 1.1.0: lomo:hasAccessibilityMeasure, lomo:hasFunctionality, lomo:hasPolicyCompliance, lomo:hasReference, lomo:hasResponsibleBody, lomo:hasReusabilityMeasure |
| http://data.europa.eu/leg/lomo/test#DigitalPublicService_DesignationRegistrationPlatform | *a thing* is a public service | encoded | 4 statements(4), one fact each | digital public service designation registration platform |  |
| http://data.europa.eu/leg/lomo/test#ImplementationMeasure_CentralDatabase | *a thing* is a concept | encoded | 8 statements(8), one fact each | implementation measure central database | words of LOMO before 1.1.0: lomo:hasReference, lomo:hasResponsibleBody, lomo:hasTimeline |
| http://data.europa.eu/leg/lomo/test#ImplementationMeasure_TechnicalStandards | *a thing* is a concept | encoded | 10 statements(10), one fact each | implementation measure technical standards | words of LOMO before 1.1.0: lomo:hasCommissionRole, lomo:hasReference, lomo:hasResponsibleBody, lomo:hasTimeline |
| http://data.europa.eu/leg/lomo/test#AssessmentTypeAlignmentPolicies | owl:NamedIndividual | encoded | 3 statements(3), one fact each | assessment type alignment policies |  |
| http://data.europa.eu/leg/lomo/test#AssessmentTypeOrganisationalMeasures | owl:NamedIndividual | encoded | 3 statements(3), one fact each | assessment type organisational measures |  |
| http://data.europa.eu/leg/lomo/test#AssessmentTypeSharedDataUnderstanding | owl:NamedIndividual | encoded | 3 statements(3), one fact each | assessment type shared data understanding |  |
| http://data.europa.eu/leg/lomo/test#AssessmentTypeStandardsSpecifications | owl:NamedIndividual | encoded | 3 statements(3), one fact each | assessment type standards specifications |  |
| http://data.europa.eu/leg/lomo/test#Statement_AlignmentPolicies | assessment statement | encoded | 6 statements(6), one fact each | statement alignment policies | kept in the generic form (no word in lomo.le): dcterms:type |
| http://data.europa.eu/leg/lomo/test#Statement_OrganisationalMeasures | assessment statement | encoded | 6 statements(6), one fact each | statement organisational measures | kept in the generic form (no word in lomo.le): dcterms:type |
| http://data.europa.eu/leg/lomo/test#Statement_DataUnderstanding | assessment statement | encoded | 6 statements(6), one fact each | statement data understanding | kept in the generic form (no word in lomo.le): dcterms:type |
| http://data.europa.eu/leg/lomo/test#Statement_StandardsUsage | assessment statement | encoded | 6 statements(6), one fact each | statement standards usage | kept in the generic form (no word in lomo.le): dcterms:type |
| http://data.europa.eu/leg/lomo/test#Assessment_AlignmentPolicies | assessment | encoded | 5 statements(5), one fact each | assessment alignment policies | kept in the generic form (no word in lomo.le): dcterms:type |
| http://data.europa.eu/leg/lomo/test#Assessment_OrganisationalMeasures | assessment | encoded | 5 statements(5), one fact each | assessment organisational measures | kept in the generic form (no word in lomo.le): dcterms:type |
| http://data.europa.eu/leg/lomo/test#Assessment_DataUnderstanding | assessment | encoded | 5 statements(5), one fact each | assessment data understanding | kept in the generic form (no word in lomo.le): dcterms:type |
| http://data.europa.eu/leg/lomo/test#Assessment_StandardsUsage | assessment | encoded | 5 statements(5), one fact each | assessment standards usage | kept in the generic form (no word in lomo.le): dcterms:type |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| description | modalities | pass |  |
| description | actions_of_rules | pass |  |
| description | actions_of_agents | pass |  |


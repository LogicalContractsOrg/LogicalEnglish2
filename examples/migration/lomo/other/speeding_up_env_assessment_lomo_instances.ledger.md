# Migration ledger: speeding_up_env_assessment_lomo_instances

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — speeding-up-env-assessment-lomo-instances.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 79 |
| approximated | 0 |
| residue | 0 |
| **total** | 79 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://data.europa.eu/leg/lomo/test | owl:Ontology | encoded | 6 statements(6), one fact each | test | kept in the generic form (no word in lomo.le): dcterms:created, dcterms:modified, owl:imports |
| http://data.europa.eu/leg/lomo/test#Agent_MemberState | agent | encoded | 3 statements(3), one fact each | agent member state |  |
| http://data.europa.eu/leg/lomo/test#Agent_Developers | agent | encoded | 3 statements(3), one fact each | agent developers |  |
| http://data.europa.eu/leg/lomo/test#Agent_CompetentAuthority | agent | encoded | 3 statements(3), one fact each | agent competent authority |  |
| http://data.europa.eu/leg/lomo/test#Agent_Public | agent | encoded | 3 statements(3), one fact each | agent public |  |
| http://data.europa.eu/leg/lomo/test#Agent_Commission | agent | encoded | 3 statements(3), one fact each | agent commission |  |
| http://data.europa.eu/leg/lomo/test#AgentType_MemberState | agent type | encoded | 3 statements(3), one fact each | agent type member state |  |
| http://data.europa.eu/leg/lomo/test#AgentType_Developers | agent type | encoded | 3 statements(3), one fact each | agent type developers |  |
| http://data.europa.eu/leg/lomo/test#AgentType_CompetentAuthority | agent type | encoded | 3 statements(3), one fact each | agent type competent authority |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_MemberState_Provider | agent role | encoded | 5 statements(5), one fact each | agent role member state provider |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_Developers_Submitter | agent role | encoded | 5 statements(5), one fact each | agent role developers submitter |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_CompetentAuthority_Processor | agent role | encoded | 5 statements(5), one fact each | agent role competent authority processor |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_Public_Recipient | agent role | encoded | 5 statements(5), one fact each | agent role public recipient |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_MemberState_Publisher | agent role | encoded | 5 statements(5), one fact each | agent role member state publisher |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_MemberState_CrossBorderEnabler | agent role | encoded | 5 statements(5), one fact each | agent role member state cross border enabler |  |
| http://data.europa.eu/leg/lomo/test#AgentRole_CompetentAuthority_DigitalManager | agent role | encoded | 5 statements(5), one fact each | agent role competent authority digital manager |  |
| http://data.europa.eu/leg/lomo/test#TemporalSpec_SixMonthsAfterEntry | *a thing* is a temporal specification | encoded | 5 statements(5), one fact each | temporal spec six months after entry | words of LOMO before 1.1.0: lomo:hasDescription, lomo:hasStartDate |
| http://data.europa.eu/leg/lomo/test#TemporalSpec_TwelveMonthsAfterEntry | *a thing* is a temporal specification | encoded | 5 statements(5), one fact each | temporal spec twelve months after entry | words of LOMO before 1.1.0: lomo:hasDescription, lomo:hasStartDate |
| http://data.europa.eu/leg/lomo/test#TemporalSpec_TwentyFourMonthsAfterEntry | *a thing* is a temporal specification | encoded | 5 statements(5), one fact each | temporal spec twenty four months after entry | words of LOMO before 1.1.0: lomo:hasDescription, lomo:hasStartDate |
| http://data.europa.eu/leg/lomo/test#TemporalSpec_Ongoing | *a thing* is a temporal specification | encoded | 4 statements(4), one fact each | temporal spec ongoing | words of LOMO before 1.1.0: lomo:hasDescription |
| http://data.europa.eu/leg/lomo/test#TemporalSpec_PerCase | *a thing* is a temporal specification | encoded | 4 statements(4), one fact each | temporal spec per case | words of LOMO before 1.1.0: lomo:hasDescription |
| http://data.europa.eu/leg/lomo/test#Action_MemberState_ProvideOnlineInfo | action | encoded | 8 statements(8), one fact each | action member state provide online info |  |
| http://data.europa.eu/leg/lomo/test#Action_Developers_SubmitElectronicInfo | action | encoded | 8 statements(8), one fact each | action developers submit electronic info |  |
| http://data.europa.eu/leg/lomo/test#Action_MemberState_PublishAssessmentData | action | encoded | 8 statements(8), one fact each | action member state publish assessment data |  |
| http://data.europa.eu/leg/lomo/test#Action_MemberState_EnableCrossBorderExchange | action | encoded | 8 statements(8), one fact each | action member state enable cross border exchange |  |
| http://data.europa.eu/leg/lomo/test#Action_CompetentAuthority_ProcessSubmissions | action | encoded | 8 statements(8), one fact each | action competent authority process submissions |  |
| http://data.europa.eu/leg/lomo/test#Action_CompetentAuthority_ManageDigitalProcedures | action | encoded | 8 statements(8), one fact each | action competent authority manage digital procedures |  |
| http://data.europa.eu/leg/lomo/test#Action_Public_AccessInformation | action | encoded | 8 statements(8), one fact each | action public access information |  |
| http://data.europa.eu/leg/lomo/test#Result_OnlineInformationAccess | action result | encoded | 6 statements(6), one fact each | result online information access |  |
| http://data.europa.eu/leg/lomo/test#Result_ElectronicSubmission | action result | encoded | 5 statements(5), one fact each | result electronic submission |  |
| http://data.europa.eu/leg/lomo/test#Result_DigitalPublication | action result | encoded | 5 statements(5), one fact each | result digital publication |  |
| http://data.europa.eu/leg/lomo/test#Result_CrossBorderExchange | action result | encoded | 5 statements(5), one fact each | result cross border exchange |  |
| http://data.europa.eu/leg/lomo/test#Result_SubmissionProcessing | action result | encoded | 5 statements(5), one fact each | result submission processing |  |
| http://data.europa.eu/leg/lomo/test#Result_DigitalProcedureManagement | action result | encoded | 5 statements(5), one fact each | result digital procedure management |  |
| http://data.europa.eu/leg/lomo/test#Result_PublicInformationAccess | action result | encoded | 5 statements(5), one fact each | result public information access |  |
| http://data.europa.eu/leg/lomo/test#Dataset_SinglePointOfContactInfo | *a thing* is a dataset | encoded | 6 statements(6), one fact each | dataset single point of contact info | words of LOMO before 1.1.0: lomo:hasStandard |
| http://data.europa.eu/leg/lomo/test#Dataset_ProcedureInfo | *a thing* is a dataset | encoded | 6 statements(6), one fact each | dataset procedure info | words of LOMO before 1.1.0: lomo:hasStandard |
| http://data.europa.eu/leg/lomo/test#Dataset_DeveloperSubmissions | *a thing* is a dataset | encoded | 6 statements(6), one fact each | dataset developer submissions | words of LOMO before 1.1.0: lomo:hasStandard |
| http://data.europa.eu/leg/lomo/test#Dataset_PublishedAssessmentData | *a thing* is a dataset | encoded | 6 statements(6), one fact each | dataset published assessment data | words of LOMO before 1.1.0: lomo:hasStandard |
| http://data.europa.eu/leg/lomo/test#Dataset_CrossBorderData | *a thing* is a dataset | encoded | 6 statements(6), one fact each | dataset cross border data | words of LOMO before 1.1.0: lomo:hasStandard |
| http://data.europa.eu/leg/lomo/test#Dataset_ProcessedSubmissions | *a thing* is a dataset | encoded | 6 statements(6), one fact each | dataset processed submissions | words of LOMO before 1.1.0: lomo:hasStandard |
| http://data.europa.eu/leg/lomo/test#Dataset_DigitalProcedureData | *a thing* is a dataset | encoded | 5 statements(5), one fact each | dataset digital procedure data | words of LOMO before 1.1.0: lomo:hasStandard |
| http://data.europa.eu/leg/lomo/test#Dataset_PublicAccessData | *a thing* is a dataset | encoded | 5 statements(5), one fact each | dataset public access data | words of LOMO before 1.1.0: lomo:hasStandard |
| http://data.europa.eu/leg/lomo/test#Process_InformationProvision | owl:NamedIndividual | encoded | 6 statements(6), one fact each | process information provision | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_OnlineInformationProvision | owl:NamedIndividual | encoded | 6 statements(6), one fact each | process online information provision | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_ElectronicSubmission | owl:NamedIndividual | encoded | 12 statements(12), one fact each | process electronic submission | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_Intake | owl:NamedIndividual | encoded | 12 statements(12), one fact each | process intake | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_Transparency | owl:NamedIndividual | encoded | 12 statements(12), one fact each | process transparency | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_DataProtectionCompliance | owl:NamedIndividual | encoded | 12 statements(12), one fact each | process data protection compliance | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_DigitalProcedureManagement | owl:NamedIndividual | encoded | 12 statements(12), one fact each | process digital procedure management | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_CrossBorderExchange | owl:NamedIndividual | encoded | 12 statements(12), one fact each | process cross border exchange | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_AutomationGovernance | owl:NamedIndividual | encoded | 12 statements(12), one fact each | process automation governance | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_CapacityBuilding | owl:NamedIndividual | encoded | 12 statements(12), one fact each | process capacity building | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_TechnologyReadiness | owl:NamedIndividual | encoded | 12 statements(12), one fact each | process technology readiness | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_AccessToInformation | owl:NamedIndividual | encoded | 12 statements(12), one fact each | process access to information | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_RedressPathways | owl:NamedIndividual | encoded | 12 statements(12), one fact each | process redress pathways | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_DataPublication | owl:NamedIndividual | encoded | 6 statements(6), one fact each | process data publication | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_SubmissionProcessing | owl:NamedIndividual | encoded | 6 statements(6), one fact each | process submission processing | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#Process_InformationAccess | owl:NamedIndividual | encoded | 6 statements(6), one fact each | process information access | words of LOMO before 1.1.0: lomo:Process |
| http://data.europa.eu/leg/lomo/test#DataScheme | *a thing* is a concept scheme | encoded | 2 statements(2), one fact each | data scheme |  |
| http://data.europa.eu/leg/lomo/test#ProcessScheme | *a thing* is a concept scheme | encoded | 2 statements(2), one fact each | process scheme |  |
| http://data.europa.eu/leg/lomo/test#DigitalDimensionScheme | *a thing* is a concept scheme | encoded | 2 statements(2), one fact each | digital dimension scheme |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article3_SinglePointOfContact | *a thing* is a prescriptive rule | encoded | 16 statements(16), one fact each | item rule article 3 single point of contact |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article10_ElectronicSubmission | *a thing* is a prescriptive rule | encoded | 18 statements(18), one fact each | item rule article 10 electronic submission |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article10_OnlineInformationAccess | *a thing* is a prescriptive rule | encoded | 20 statements(20), one fact each | item rule article 10 online information access |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article10_DigitalPublication | *a thing* is a prescriptive rule | encoded | 16 statements(16), one fact each | item rule article 10 digital publication |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article10_FullDigitalization | *a thing* is a prescriptive rule | encoded | 21 statements(21), one fact each | item rule article 10 full digitalization |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article10_DisputeSettlementInfo | *a thing* is a prescriptive rule | encoded | 15 statements(15), one fact each | item rule article 10 dispute settlement info |  |
| http://data.europa.eu/leg/lomo/test#Rule_Article12_ResourcesAndTraining | *a thing* is a prescriptive rule | encoded | 12 statements(12), one fact each | item rule article 12 resources training |  |
| http://data.europa.eu/leg/lomo/test#DigitalSolution_OnlinePortal | owl:NamedIndividual | encoded | 9 statements(9), one fact each | digital solution online portal |  |
| http://data.europa.eu/leg/lomo/test#DigitalSolution_ElectronicSubmission | owl:NamedIndividual | encoded | 8 statements(8), one fact each | digital solution electronic submission |  |
| http://data.europa.eu/leg/lomo/test#DigitalSolution_DigitalProcedures | owl:NamedIndividual | encoded | 9 statements(9), one fact each | digital solution digital procedures |  |
| http://data.europa.eu/leg/lomo/test#DigitalPublicService_EnvironmentalPortal | *a thing* is a public service | encoded | 10 statements(10), one fact each | digital public service environmental portal | kept in the generic form (no word in lomo.le): cpsv:hasCompetentAuthority; words of LOMO before 1.1.0: lomo:hasReference |
| http://data.europa.eu/leg/lomo/test#DigitalPublicService_CrossBorderExchange | *a thing* is a public service | encoded | 10 statements(10), one fact each | digital public service cross border exchange | kept in the generic form (no word in lomo.le): cpsv:hasCompetentAuthority; words of LOMO before 1.1.0: lomo:hasReference |
| http://data.europa.eu/leg/lomo/test#InteroperabilityAssessment_AlignmentWithPolicies | owl:NamedIndividual | encoded | 8 statements(8), one fact each | interoperability assessment alignment with policies | kept in the generic form (no word in lomo.le): cav:assesses, cav:hasAssessmentStatement, cav:hasAssessmentType |
| http://data.europa.eu/leg/lomo/test#InteroperabilityAssessment_OrganizationalMeasures | owl:NamedIndividual | encoded | 7 statements(7), one fact each | interoperability assessment organizational measures | kept in the generic form (no word in lomo.le): cav:assesses, cav:hasAssessmentStatement, cav:hasAssessmentType |
| http://data.europa.eu/leg/lomo/test#InteroperabilityAssessment_DataUnderstanding | owl:NamedIndividual | encoded | 7 statements(7), one fact each | interoperability assessment data understanding | kept in the generic form (no word in lomo.le): cav:assesses, cav:hasAssessmentStatement, cav:hasAssessmentType |
| http://data.europa.eu/leg/lomo/test#InteroperabilityAssessment_TechnicalStandards | owl:NamedIndividual | encoded | 8 statements(8), one fact each | interoperability assessment technical standards | kept in the generic form (no word in lomo.le): cav:assesses, cav:hasAssessmentStatement, cav:hasAssessmentType |
| http://data.europa.eu/leg/lomo/test#CompleteInteroperabilityAssessment_EnvironmentalServices | owl:NamedIndividual | encoded | 8 statements(8), one fact each | complete interoperability assessment environmental services | kept in the generic form (no word in lomo.le): cav:hasSubAssessment |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| description | modalities | pass |  |
| description | actions_of_rules | pass |  |
| description | actions_of_agents | pass |  |


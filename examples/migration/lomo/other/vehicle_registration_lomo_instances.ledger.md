# Migration ledger: vehicle_registration_lomo_instances

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — vehicle-registration-lomo-instances.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 68 |
| approximated | 0 |
| residue | 0 |
| **total** | 68 |

Fidelity: **5 of 5** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://data.europa.eu/leg/lomo/vehicle-registration | owl:Ontology | encoded | 7 statements(7), one fact each | vehicle registration | kept in the generic form (no word in lomo.le): dcterms:created, dcterms:modified, dcterms:source, owl:imports |
| http://data.europa.eu/leg/lomo/vehicle-registration#Agent_EuropeanCommission | agent | encoded | 4 statements(4), one fact each | agent european commission |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#Agent_EuropeanParliament | agent | encoded | 4 statements(4), one fact each | agent european parliament |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#Agent_EuropeanCouncil | agent | encoded | 4 statements(4), one fact each | agent european council |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentType_MemberStates | agent type | encoded | 4 statements(4), one fact each | agent type member states |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentType_CompetentAuthorities | agent type | encoded | 4 statements(4), one fact each | agent type competent authorities |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentType_VehicleOwner | agent type | encoded | 5 statements(5), one fact each | agent type vehicle owner | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentType_ReregisteringMemberState | agent type | encoded | 5 statements(5), one fact each | agent type reregistering member state | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentType_MemberStateOfRegistration | agent type | encoded | 5 statements(5), one fact each | agent type member state of registration | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#Def_PhysicalRegistrationCertificate | *a thing* is a definition | encoded | 7 statements(7), one fact each | def physical registration certificate | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#Def_MobileRegistrationCertificate | *a thing* is a definition | encoded | 7 statements(7), one fact each | def mobile registration certificate | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#Def_Vehicle | *a thing* is a definition | encoded | 7 statements(7), one fact each | def vehicle | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#Def_Registration | *a thing* is a definition | encoded | 7 statements(7), one fact each | def registration | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#Def_RegistrationCertificate | *a thing* is a definition | encoded | 7 statements(7), one fact each | def registration certificate | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#Def_HolderOfRegistrationCertificate | *a thing* is a definition | encoded | 7 statements(7), one fact each | def holder of registration certificate | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#Def_Suspension | *a thing* is a definition | encoded | 7 statements(7), one fact each | def suspension | words of LOMO before 1.1.0: lomo:isSemanticDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#ResultType_PhysicalCertificatePartI | action result type | encoded | 4 statements(4), one fact each | result type physical certificate part i |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#ResultType_MobileCertificatePresentation | action result type | encoded | 4 statements(4), one fact each | result type mobile certificate presentation |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#ResultType_AcceptanceDecision | action result type | encoded | 4 statements(4), one fact each | result type acceptance decision |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#ResultType_VerificationReport | action result type | encoded | 4 statements(4), one fact each | result type verification report |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#ResultType_VehicleRegistrationReport | action result type | encoded | 4 statements(4), one fact each | result type vehicle registration report |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#ResultType_DataTransmission | action result type | encoded | 4 statements(4), one fact each | result type data transmission |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#TemporalSpec_DateOfEntryIntoForce | *a thing* is a temporal specification | encoded | 5 statements(5), one fact each | temporal spec date of entry into force |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#TemporalSpec_FourYearsAfterEntry | *a thing* is a temporal specification | encoded | 6 statements(6), one fact each | temporal spec four years after entry |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#TemporalSpec_FourYearsOneDayAfterEntry | *a thing* is a temporal specification | encoded | 6 statements(6), one fact each | temporal spec four years one day after entry |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#TemporalSpec_March31_2030 | *a thing* is a temporal specification | encoded | 6 statements(6), one fact each | temporal spec march 31 2030 |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#TemporalSpec_TriennialDeadline | *a thing* is a temporal specification | encoded | 6 statements(6), one fact each | temporal spec triennial deadline |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#Requirement_Art10_Par2 | *a thing* is a prescriptive rule | encoded | 13 statements(13), one fact each | requirement art 10 par 2 | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#Action_RequirePhysicalCert | action | encoded | 8 statements(8), one fact each | action require physical cert |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_CompAuth_RequirePhysical | agent role | encoded | 4 statements(4), one fact each | agent role comp auth require physical |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_Owner_SubmitPhysical | agent role | encoded | 4 statements(4), one fact each | agent role owner submit physical |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#Result_PhysicalCertSubmission | action result | encoded | 5 statements(5), one fact each | result physical cert submission | words of LOMO before 1.1.0: lomo:hasAnnotation, lomo:hasResultType |
| http://data.europa.eu/leg/lomo/vehicle-registration#Action_AcceptMobileCert | action | encoded | 8 statements(8), one fact each | action accept mobile cert |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_CompAuth_AcceptMobile | agent role | encoded | 4 statements(4), one fact each | agent role comp auth accept mobile |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_Owner_PresentMobile | agent role | encoded | 4 statements(4), one fact each | agent role owner present mobile |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#Result_MobileCertPresentation | action result | encoded | 5 statements(5), one fact each | result mobile cert presentation | words of LOMO before 1.1.0: lomo:hasAnnotation, lomo:hasResultType |
| http://data.europa.eu/leg/lomo/vehicle-registration#Requirement_Art10_Par3 | *a thing* is a prescriptive rule | encoded | 13 statements(13), one fact each | requirement art 10 par 3 | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#Action_AcceptBothCerts | action | encoded | 8 statements(8), one fact each | action accept both certs |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_MS_AcceptBoth | agent role | encoded | 5 statements(5), one fact each | agent role ms accept both |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#Result_AcceptanceBothFormats | action result | encoded | 5 statements(5), one fact each | result acceptance both formats | words of LOMO before 1.1.0: lomo:hasAnnotation, lomo:hasResultType |
| http://data.europa.eu/leg/lomo/vehicle-registration#Action_VerifyFormats | action | encoded | 9 statements(9), one fact each | action verify formats | words of LOMO before 1.1.0: lomo:precedes |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_ReregMS_Verify | agent role | encoded | 4 statements(4), one fact each | agent role rereg ms verify |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_OrigMS_Respond | agent role | encoded | 4 statements(4), one fact each | agent role orig ms respond |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#Result_VerificationInfo | action result | encoded | 5 statements(5), one fact each | result verification info | words of LOMO before 1.1.0: lomo:hasAnnotation, lomo:hasResultType |
| http://data.europa.eu/leg/lomo/vehicle-registration#Requirement_Art16_Par1 | *a thing* is a prescriptive rule | encoded | 14 statements(14), one fact each | requirement art 16 par 1 | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#Action_CommunicateDataToCommission | action | encoded | 10 statements(10), one fact each | action communicate data to commission |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_MS_Communicate | agent role | encoded | 4 statements(4), one fact each | agent role ms communicate |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_Commission_Receive | agent role | encoded | 4 statements(4), one fact each | agent role commission receive |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#Result_TriennialReport | action result | encoded | 9 statements(9), one fact each | result triennial report | words of LOMO before 1.1.0: lomo:hasAnnotation, lomo:hasResultType |
| http://data.europa.eu/leg/lomo/vehicle-registration#Result_PhysicalCertData | action result | encoded | 5 statements(5), one fact each | result physical cert data | words of LOMO before 1.1.0: lomo:hasAnnotation |
| http://data.europa.eu/leg/lomo/vehicle-registration#Result_MobileCertData | action result | encoded | 5 statements(5), one fact each | result mobile cert data | words of LOMO before 1.1.0: lomo:hasAnnotation |
| http://data.europa.eu/leg/lomo/vehicle-registration#Result_ReregistrationData | action result | encoded | 5 statements(5), one fact each | result reregistration data | words of LOMO before 1.1.0: lomo:hasAnnotation |
| http://data.europa.eu/leg/lomo/vehicle-registration#Result_SuspensionData | action result | encoded | 5 statements(5), one fact each | result suspension data | words of LOMO before 1.1.0: lomo:hasAnnotation |
| http://data.europa.eu/leg/lomo/vehicle-registration#Action_TransmitDataToParliamentCouncil | action | encoded | 8 statements(8), one fact each | action transmit data to parliament council |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_Commission_Transmit | agent role | encoded | 4 statements(4), one fact each | agent role commission transmit |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_Parliament_Receive | agent role | encoded | 4 statements(4), one fact each | agent role parliament receive |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_Council_Receive | agent role | encoded | 4 statements(4), one fact each | agent role council receive |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#Result_DataTransmissionToInstitutions | action result | encoded | 5 statements(5), one fact each | result data transmission to institutions | words of LOMO before 1.1.0: lomo:hasAnnotation, lomo:hasResultType |
| http://data.europa.eu/leg/lomo/vehicle-registration#Requirement_Art10_Par1_Obligation | *a thing* is a prescriptive rule | encoded | 13 statements(13), one fact each | requirement art 10 par 1 obligation | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#Action_MS_AcceptBothFormsForID | action | encoded | 8 statements(8), one fact each | action ms accept both forms for id |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_MS_AcceptBothID_Bearer | agent role | encoded | 5 statements(5), one fact each | agent role ms accept both id bearer |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_Driver_BenefitsFromAcceptance | agent role | encoded | 5 statements(5), one fact each | agent role driver benefits from acceptance |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#Result_AcceptanceBothForID | action result | encoded | 5 statements(5), one fact each | result acceptance both for id | words of LOMO before 1.1.0: lomo:hasAnnotation, lomo:hasResultType |
| http://data.europa.eu/leg/lomo/vehicle-registration#Requirement_Art10_Par1_Right | *a thing* is a prescriptive rule | encoded | 13 statements(13), one fact each | requirement art 10 par 1 right | words of LOMO before 1.1.0: lomo:usesDefinition |
| http://data.europa.eu/leg/lomo/vehicle-registration#Action_Driver_UseEitherFormat | action | encoded | 8 statements(8), one fact each | action driver use format |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_Driver_RightHolder | agent role | encoded | 5 statements(5), one fact each | agent role driver right holder |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#AgentRole_MS_DutyBearer | agent role | encoded | 5 statements(5), one fact each | agent role ms duty bearer |  |
| http://data.europa.eu/leg/lomo/vehicle-registration#Result_CertificatePresentation | action result | encoded | 6 statements(6), one fact each | result certificate presentation | words of LOMO before 1.1.0: lomo:hasAnnotation, lomo:hasResultType |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| calendar | due_dates | pass |  |
| calendar | due_in_2027 | pass |  |
| description | modalities | pass |  |
| description | actions_of_rules | pass |  |
| description | actions_of_agents | pass |  |


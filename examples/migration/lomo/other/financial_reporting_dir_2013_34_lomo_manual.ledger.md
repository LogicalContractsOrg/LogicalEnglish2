# Migration ledger: financial_reporting_dir_2013_34_lomo_manual

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — financial-reporting-dir_2013_34-lomo-manual.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 24 |
| approximated | 0 |
| residue | 0 |
| **total** | 24 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://data.europa.eu/eli/dir/2013/34/oj | eli:LegalResource | encoded | 1 statements(1), one fact each | eli dir 2013 34 oj |  |
| http://example.org/accounting-graph#Def_PublicInterestEntity | *a thing* is a definition | encoded | 5 statements(5), one fact each | def public interest entity |  |
| http://example.org/accounting-graph#Def_MicroUndertaking | *a thing* is a definition | encoded | 6 statements(6), one fact each | def micro undertaking |  |
| http://example.org/accounting-graph#Actor_MicroUndertaking | agent type | encoded | 21 statements(21), one fact each | actor micro undertaking | kept in the generic form (no word in lomo.le): eli-lo:average_employees, eli-lo:balance_sheet, eli-lo:has_source, eli-lo:net_turn_over, eli-lo:size_category, eli-lo:source_text, eli-lo:unit, eli-lo:upper_value_limit |
| http://example.org/accounting-graph#Actor_SmallUndertaking | agent type | encoded | 3 statements(3), one fact each | actor small undertaking | kept in the generic form (no word in lomo.le): eli-lo:size_category |
| http://example.org/accounting-graph#Actor_MediumSizedUndertaking | agent type | encoded | 3 statements(3), one fact each | actor medium sized undertaking | kept in the generic form (no word in lomo.le): eli-lo:size_category |
| http://example.org/accounting-graph#Actor_LargeUndertaking | agent type | encoded | 3 statements(3), one fact each | actor large undertaking | kept in the generic form (no word in lomo.le): eli-lo:size_category |
| http://example.org/accounting-graph#Agent_MemberState | agent type | encoded | 2 statements(2), one fact each | agent member state |  |
| http://example.org/accounting-graph#Agent_Commission | agent | encoded | 2 statements(2), one fact each | agent commission |  |
| http://example.org/accounting-graph#Norm_ManagementReportContent | *a thing* is a constitutive rule | encoded | 4 statements(4), one fact each | norm management report content |  |
| http://example.org/accounting-graph#Norm_PublicationObligation | *a thing* is a substantive rule | encoded | 10 statements(10), one fact each | norm publication obligation | kept in the generic form (no word in lomo.le): eli-lo:applies_to |
| http://example.org/accounting-graph#Step_PublishFullReport | action | encoded | 21 statements(21), one fact each | step publish full report |  |
| http://example.org/accounting-graph#AgentRole_MicroUndertaking_Publisher | agent role | encoded | 3 statements(3), one fact each | agent role micro undertaking publisher |  |
| http://example.org/accounting-graph#AgentRole_SmallUndertaking_Publisher | agent role | encoded | 3 statements(3), one fact each | agent role small undertaking publisher |  |
| http://example.org/accounting-graph#AgentRole_MediumSizedUndertaking_Publisher | agent role | encoded | 3 statements(3), one fact each | agent role medium sized undertaking publisher |  |
| http://example.org/accounting-graph#AgentRole_LargeUndertaking_Publisher | agent role | encoded | 3 statements(3), one fact each | agent role large undertaking publisher |  |
| http://example.org/accounting-graph#Doc_ManagementReport | action result type | encoded | 3 statements(3), one fact each | doc management report |  |
| http://example.org/accounting-graph#Doc_AnnualFinancialStatements | action result type | encoded | 3 statements(3), one fact each | doc annual financial statements |  |
| http://example.org/accounting-graph#Doc_AuditorOpinion | action result type | encoded | 3 statements(3), one fact each | doc auditor opinion |  |
| http://example.org/accounting-graph#Norm_TranspositionObligation | implementation and oversight rule | encoded | 8 statements(8), one fact each | norm transposition obligation | kept in the generic form (no word in lomo.le): eli-lo:applies_to |
| http://example.org/accounting-graph#Step_BringInForce | action | encoded | 12 statements(12), one fact each | step bring in force |  |
| http://example.org/accounting-graph#AgentRole_MemberState_Transposer | agent role | encoded | 3 statements(3), one fact each | agent role member state transposer |  |
| http://example.org/accounting-graph#Step_CommunicateText | agent role | encoded | 14 statements(14), one fact each | step communicate text |  |
| http://example.org/accounting-graph#Doc_Legislation | action result type | encoded | 3 statements(3), one fact each | doc legislation |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| description | modalities | pass |  |
| description | actions_of_rules | pass |  |
| description | actions_of_agents | pass |  |


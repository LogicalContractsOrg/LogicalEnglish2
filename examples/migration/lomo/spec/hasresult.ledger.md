# Migration ledger: hasresult

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — hasResult.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 10 |
| approximated | 0 |
| residue | 0 |
| **total** | 10 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/Action_PrepareFinancialStatements | action | encoded | 2 statements(2), one fact each | action prepare financial statements |  |
| http://example.org/Result_FinancialStatements_2024 | action result | encoded | 2 statements(2), one fact each | result financial statements 2024 |  |
| http://example.org/Action_Audit | action | encoded | 2 statements(2), one fact each | action audit |  |
| http://example.org/AuditReportType | action result type | encoded | 2 statements(2), one fact each | audit report type |  |
| http://example.org/Action_AnnualReview | action | encoded | 3 statements(3), one fact each | action annual review |  |
| http://example.org/Result_AnnualReport_2024 | action result | encoded | 2 statements(2), one fact each | result annual report 2024 |  |
| http://example.org/Result_FinancialSummary_2024 | action result | encoded | 2 statements(2), one fact each | result financial summary 2024 |  |
| http://example.org/Action_AnnualReview | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Action_AnnualReview has no hasAgentRole (LOMO asks for one) |
| http://example.org/Action_Audit | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Action_Audit has no hasAgentRole (LOMO asks for one) |
| http://example.org/Action_PrepareFinancialStatements | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Action_PrepareFinancialStatements has no hasAgentRole (LOMO asks for one) |


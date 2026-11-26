# Migration ledger: equivalentdefinition

Source: a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle) — equivalentDefinition.ttl
Translator: LE2 migration/lomo (lomo_twin.pl)
Date: 2026-11-26
Source licence: Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 9 |
| approximated | 0 |
| residue | 0 |
| **total** | 9 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| http://example.org/Def_RelatedParty | *a thing* is a definition | encoded | 5 statements(5), one fact each | def related party | kept in the generic form (no word in lomo.le): rdfs:seeAlso |
| _: | a validity rule of LOMO | encoded | kept as the description has it | - | _: has no establishedIn (LOMO asks for one) |
| _: | a validity rule of LOMO | encoded | kept as the description has it | - | _: has no establishedIn (LOMO asks for one) |
| _: | a validity rule of LOMO | encoded | kept as the description has it | - | _: has no label (LOMO asks for one) |
| _: | a validity rule of LOMO | encoded | kept as the description has it | - | _: has no label (LOMO asks for one) |
| http://example.org/Def_RelatedParty | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Def_RelatedParty has no establishedIn (LOMO asks for one) |
| http://example.org/Def_RelatedParty | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Def_RelatedParty has no establishedIn (LOMO asks for one) |
| http://example.org/Def_RelatedParty | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Def_RelatedParty has no label (LOMO asks for one) |
| http://example.org/Def_RelatedParty | a validity rule of LOMO | encoded | kept as the description has it | - | http://example.org/Def_RelatedParty has no label (LOMO asks for one) |


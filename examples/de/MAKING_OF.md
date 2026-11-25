# Wie die Beispiele dieses Ordners entstanden sind / How the examples in this folder were made

The three programs of this folder were translated from English by an AI agent,
when German Logical English (Logisches Deutsch) was built.

| File | Made by | How |
|---|---|---|
| `staatsbuergerschaft.le` | AI agent (Claude Fable 5.2, in Claude Code), 2026-11-25, at Miguel Calejo's request | Translated from `../moreExamples/citizenship.le` (British citizenship). The sentences are written as German is written: the verb at the end of a clause after `wenn` or `dass`, commas between clauses, `am` and `im`. |
| `gluecklicher_drache.le` | Same | Translated from `../moreExamples/happy_dragon.le`. |
| `verguetung.le` | Same | Translated from `../moreExamples/numbers.le`. The variables `salary` and `bonus` of the English rule are `Grundbetrag` and `Bonusbetrag`, and Bob's bonus has a decimal part, to show the German number format. |
| `README.md` | Same | |

## The record
- Written on 25 November 2026 with the changes to the engine that German needs: the columns `inflection_endings`, `noun_endings`, `word_order`, `clause_commas` and `value_contractions` of `i18n/languages.csv`.

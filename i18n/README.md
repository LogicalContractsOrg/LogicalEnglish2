# Multilingual Logical English — the `i18n/` dictionaries

This directory is the **single source of truth** for every natural-language
surface of Logical English. The Prolog backend (`le_i18n.pl`) loads these CSVs
at start-up; the editor build generates its keyword tables and UI catalog from
the same files (`editor/scripts/gen-i18n.cjs` → `editor/src/generated/i18nData.ts`).

A Logical English program declares its language with its **first statement**
(the `opener` column of `languages.csv`):

| Language | Opener |
|---|---|
| English | `the target language is: prolog.` |
| Português Lógico | `a linguagem alvo é: prolog.` |
| Español Lógico | `el lenguaje objetivo es: prolog.` |
| Français Logique | `la langue cible est: prolog.` |
| Italiano Logico | `il linguaggio obiettivo è: prolog.` |
| Logisches Deutsch | `die Zielsprache ist: prolog.` |

When no opener matches, the program is parsed as English (decision O-1).

## Files

- **`languages.csv`** — language registry: code, autonym, opener phrase, and
  number locale (`decimal_sep`, `thousands_sep`, `list_sep`). `status` is
  informational (`core`, `pilot`, `draft`). Two optional columns serve
  languages that shorten words: `elisions` lists the words written short
  before a vowel, as `short=full` pairs separated by `|` (French
  `l'=le|d'=de|qu'=que|…`), and `contractions` the words that stand for two
  (`au=à le|du=de le|s'il=si il`). The parser reads a short form as its full
  form ("l'autre personne" as "le autre personne", "au marché" as "à le
  marché"), so a template and a sentence match whichever way each is
  written; the LE writer writes the short forms; a test's expected answer
  may use either. An apostrophe directly after a letter is always part of
  the word, in every language: it never opens a quoted string.
  Five more optional columns serve a language whose words change their
  ending and whose verb changes its place (German):
  - `inflection_endings` (`e|er|es|en|em`): the endings an adjective takes.
    A word of the class `qualifier` (first, second, other …) names the same
    variable with any of them: "ein erster Zeitpunkt", "der erste
    Zeitpunkt", "dem ersten Zeitpunkt". List every form of each qualifier
    in the `qualifier` cell of `keywords.csv`.
  - `noun_endings` (`en|es|n|s|e`): the endings a noun may add in another
    case. A phrase names a variable already introduced whose noun differs
    from it only by one of them: "der Kunde", "dem Kunden".
  - `word_order` (`verb_moves`): a sentence that matches no template as it
    is written is tried with its last word put back at an earlier place
    (the verb at the end of a subordinate clause: "wenn die Person in dem
    Ort geboren wurde") and with its first word put at a later place (the
    verb first, after a word that took the first place: "dann wird das
    Feuer bekämpft"). The verb is never put inside a noun phrase. In
    Logical English for LPS, a time may then stand before the last words
    of the sentence ("wird von einem ersten Zeitpunkt bis zu einem zweiten
    Zeitpunkt bekämpft").
  - `clause_commas`: the words (or short phrases, "in denen") before which
    the language writes a comma that only separates clauses. That comma is
    dropped when a program is read; a comma before any other word stays.
  - `value_contractions` (`yes`): before a number or a date a contraction
    is only its first word ("am 2021-10-09" is "an 2021-10-09"), and that
    word is written as the contraction in an answer.
- **`keywords.csv`** — grammar keywords and word classes. One row per keyword
  `key` (grouped by `category`), one column per language. A cell holds one or
  more **synonyms separated by `|`**; each synonym is a space-separated word
  phrase. The first/longest synonym is the *principal* form, used when LE text
  is generated (answers, explanations); all synonyms are accepted when parsing.
  Category `view` holds the sentence phrases of views (docs/user/reference/language.md
  §17.10): each view sentence is a sequence of these phrases and its
  arguments.
  Category `service_cells` holds the phrases of the section that says which
  cells of a workbook answer a template (`the cells of service <name> are:`,
  `the sheet is`, `the cell`; docs/user/reference/language.md §17.6).
- **`system_templates.csv`** — surface phrases of the built-in predicates
  (`is equal to` / `é igual a`, …). `{1}`, `{2}`, … mark the argument slots;
  synonyms with `|` as above. Symbolic operators (`>=`, `=` …) are
  language-neutral and are not listed here.
- **`messages.csv`** — diagnostics and other generated messages, with
  **named placeholders** `{name}` that translations may reorder ( `{newline}`
  is predefined). An empty cell falls back to English.
- **`writer_words.csv`** — the few words the LE writer (`le_writer.pl`, the
  translators' last step) inserts when it *generates* a program: indefinite
  and definite articles, ordinals and `which`, each in a masculine (`_m`) and
  a feminine (`_f`) form, and the noun endings taken as feminine when a
  generated variable needs an article (`feminine_endings`, a heuristic for
  readability only — the parser accepts either form).
- **`ui.csv`** — editor/UI chrome strings, keyed by the canonical English
  string. An empty cell falls back to English.

## Adding or revising a language

1. Add/adjust the row in `languages.csv` (opener + number separators).
2. Fill the language's column in `keywords.csv`, `system_templates.csv` and
   `messages.csv`. Machine-translated first drafts are fine — mark work in
   progress via the `status` column of `languages.csv` and review keyword rows
   especially (they define the grammar!).
3. Run the tests: `testing/run_tests.sh --no-e2e`. Example programs for the
   language live under `examples/<code>/` (decision O-7) and are picked up by
   the runner automatically.
4. Rebuild the editor (`cd editor && npm run build`) to regenerate its tables.

### Notes and caveats for translators

- **Number locale (decision O-3, option B).** In comma-decimal languages a
  comma **directly between digits** is read as the decimal separator
  (`o custo é 1,5`). Write list/argument commas with a following space:
  `[1, 5]`. The thousands separator groups exactly three digits
  (`1.234.567`); dates stay ISO (`2026-07-15`).
- **Meta markers (decision O-14).** The words of the `meta_marker` class
  (`that`/`says`; `que`/`diz`, …) give templates containing
  `<marker> *a variable*` priority as meta-templates. In Romance languages
  `que` is ubiquitous — built-in templates are exempt from this priority, and
  comparison phrasings in `system_templates.csv` should avoid a bare
  `que` before a slot (Portuguese uses `é superior a`, not `é maior que`).
- **Determiners.** The `article` class introduces variables ("uma pessoa");
  the `definite_article` class marks constants in scenarios ("o pão");
  `determiner_definite` ("this"/"este|esta") anchors prepositional chains.
  Capitalised variants ('The', 'Uma') are accepted automatically.
- **Capital letters.** A keyword is matched as it is written. Only the
  words of the determiner classes are also accepted with a capital first
  letter. A language that writes nouns with a capital (German) writes them so
  in its keyword cells (`die Vorlagen sind`), and lists a second form where a
  keyword may open a sentence (`wenn|Wenn`, `Szenario|szenario`).
- **Verb-final keywords.** In a language whose verb moves, a keyword that
  holds a verb has another order inside a subordinate clause. List each
  order as a synonym: `es ist nicht der Fall dass|es nicht der Fall ist
  dass|ist es nicht der Fall dass`.
- **Gender/number agreement (decision O-8).** Generation is minimal: programs
  are echoed with their own words; only connective words are inserted. Where a
  class needs both genders (qualifiers, additions), list both forms as
  synonyms (`desconhecido|desconhecida`).
- Keys are **stable identifiers** — never rename them; only edit language
  cells. New grammar features must add rows here rather than hardcoding words.

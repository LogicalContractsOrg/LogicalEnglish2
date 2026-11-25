# Logical English in other languages

You can write Logical English in six natural languages. Each language has its
own version of Logical English:

| Language | Name of its Logical English | First sentence of a program | How complete |
|---|---|---|---|
| English | Logical English | `the target language is: prolog.` | complete |
| Portuguese | Português Lógico | `a linguagem alvo é: prolog.` | pilot |
| Spanish | Español Lógico | `el lenguaje objetivo es: prolog.` | draft |
| French | Français Logique | `la langue cible est: prolog.` | draft |
| Italian | Italiano Logico | `il linguaggio obiettivo è: prolog.` | draft |
| German | Logisches Deutsch | `die Zielsprache ist: prolog.` | draft |

A program has the same meaning in each language. Only the words change. These
words are the keywords (*if*, *and*, *it is not the case that* …), the headings of
the sections, and the built-in sentences, for example *is greater than*. The
author of the program writes the other words of the program.

*Complete* means that the full system operates in the language. *Pilot* means
these three things about Portuguese: it has tests with its own example programs, it
has its own language reference, and it has its own instructions for the
assistants. *Draft* means that a machine translated the keywords first, and that
people continue to examine the keywords. A draft language has a small number of
example programs. For the draft languages, the assistants use their English
instructions.

## Choosing the language of a program

The first sentence of a program tells the language of the program. The editor
reads that sentence. Then the editor reads the remaining part of the program in
that language. The editor also shows the keywords of that language in colours. If
a program does not have this first sentence, the editor reads the program as
English.

Below is the start of the classic example about British citizenship, in Español
Lógico. A *template* is the pattern of a sentence. A template has a slot for each
thing that changes, for example *\*una persona\**:

```
el lenguaje objetivo es: prolog.

las plantillas son:
*una persona* adquiere ciudadanía británica en *una fecha*.
*una persona* nació en *un lugar* en *una fecha*,
*una persona* es la madre de *una persona*,
*una persona* es ciudadana británica en *una fecha*.

la base de conocimiento ciudadania incluye:

una persona adquiere ciudadanía británica en una fecha
si la persona nació en el Reino Unido en la fecha
	y una otra persona es la madre de la persona
	y la otra persona es ciudadana británica en la fecha.
```

In English, the same rule is *a person acquires British citizenship on a date if
the person is born in the UK on the date and …*. A *scenario* is a set of facts,
with a name, that describes one case. A *query* is a question to the program. The
words for "scenario" and "query" change with the language, as all keywords do:

| English | Português | Español | Français | Italiano | Deutsch |
|---|---|---|---|---|---|
| the templates are | os modelos são | las plantillas son | les modèles sont | i modelli sono | die Vorlagen sind |
| the knowledge base … includes | a base de conhecimento … inclui | la base de conocimiento … incluye | la base de connaissances … comprend | la base di conoscenza … include | die Wissensbasis … enthält |
| if | se | si | si | se | wenn, falls |
| and | e | y | et | e | und |
| or | ou | o | ou | o | oder |
| it is not the case that | não é o caso que | no es el caso que | il est faux que | non è il caso che | es ist nicht der Fall, dass |
| scenario … is | cenário … é | escenario … es | scénario … est | scenario … è | Szenario … ist |
| query … is | consulta … é | consulta … es | requête … est | interrogazione … è | Abfrage … ist |
| expects | espera | espera | attend | attende | erwartet |

The [language reference](../reference/language.md) describes each construct in
English. There is also a Portuguese translation of the reference:
[Resumo da sintaxe do Português Lógico](../reference/language.pt.md).

## German: the sentences of Logisches Deutsch

German changes the order and the endings of words more than the other five
languages. Logisches Deutsch reads the sentences as German writes them. You do
not have to write unnatural German.

Below is the rule about British citizenship in Logisches Deutsch:

```
die Zielsprache ist: prolog.

die Vorlagen sind:
*eine Person* erwirbt an *einem Datum* die britische Staatsbürgerschaft,
*eine Person* wurde an *einem Datum* in *einem Ort* geboren,
*ein Datum* liegt nach dem Inkrafttreten,
*eine Person* ist die Mutter von *einer Person*,
*eine Person* besitzt an *einem Datum* die britische Staatsbürgerschaft.

die Wissensbasis Staatsbuergerschaft enthält:

eine Person erwirbt an einem Datum die britische Staatsbürgerschaft,
wenn die Person an dem Datum im Vereinigten Königreich geboren wurde
    und das Datum nach dem Inkrafttreten liegt
    und eine andere Person die Mutter von der Person ist
    und die andere Person an dem Datum die britische Staatsbürgerschaft besitzt.

Szenario alice ist:
    John wurde am 2021-10-09 im Vereinigten Königreich geboren.
    2021-10-09 liegt nach dem Inkrafttreten.
    Alice ist die Mutter von John.
    Alice besitzt am 2021-10-09 die britische Staatsbürgerschaft.
```

The rules of Logisches Deutsch are these:

- **A template is a main clause.** Write each template with its verb in the
  second position, as in a statement: `*eine Person* wurde an *einem Datum* in
  *einem Ort* geboren`. A fact in a scenario has the same order.
- **After `wenn`, `falls` and `dass`, the verb is at the end.** German puts the
  verb at the end of a clause that starts with one of these words: `wenn die
  Person an dem Datum im Vereinigten Königreich geboren wurde`. Logisches Deutsch
  finds the template of such a clause. The order of the template is also
  accepted there (`wenn die Person wurde … geboren`), but it is not correct
  German.
- **After a word that takes the first position, the verb comes before the
  subject.** This order occurs in Logical English for LPS, after `dann` and
  `anfangs`: `dann wird das Feuer bekämpft`, `anfangs gibt es ein Feuer`.
- **A comma between clauses is permitted.** You can write a comma before
  `wenn`, `falls`, `dass`, `und`, `oder`, `dann` and the other words that start
  a clause. The comma is not a part of the sentence.
- **The article and the ending of an adjective change with the case.** `eine
  andere Person`, `die andere Person` and `der anderen Person` are the same
  variable. `ein erster Zeitpunkt`, `der erste Zeitpunkt` and `dem ersten
  Zeitpunkt` are the same variable. The adjectives with this property are the
  ordinal numbers (`erste`, `zweite`, …) and `andere`, `weitere`, `neue`,
  `vorherige`, `nächste`, `aktuelle`, `letzte`, `gleiche`, `ursprüngliche`,
  `einzige` and `gegebene`.
- **A noun can have an ending in a different case.** `der Kunde` and `dem
  Kunden` are the same variable. `ein Betrag` and `des Betrags` are the same
  variable. The endings that Logisches Deutsch accepts are `-n`, `-en`, `-s`,
  `-es` and `-e`.
- **Short forms.** `am`, `im`, `zum`, `zur`, `vom`, `beim`, `ins` and `ans` are
  the same as `an dem`, `in dem`, `zu dem`, `zu der`, `von dem`, `bei dem`, `in
  das` and `an das`. Before a date or a number, the short form is only the
  preposition: `am 2021-10-09` gives the date to the template `an *einem Datum*`.
- **Nouns have a capital letter.** Write the keywords as the table above shows
  them: `die Vorlagen sind`, `die Wissensbasis`, `Szenario`, `Abfrage`.

**Notes.**

- A verb in two parts has its parts together at the end of a clause
  (`teilnimmt` for `nimmt … teil`). Logisches Deutsch does not find the template
  of such a clause. Use a verb in one part, or write the clause in the order of
  the template.
- The name of a person or a thing must have the same form each time. `das
  Vereinigte Königreich` and `dem Vereinigten Königreich` are two different
  names. The example above always writes `im Vereinigten Königreich`.
- The words of a negation are `es ist nicht der Fall, dass`. In a clause after
  `wenn`, the order is `es nicht der Fall ist, dass`. A sentence with the word
  `nicht` or `kein` in it (`die Person raucht nicht`) is not a negation for
  Logisches Deutsch.

The three example programs of Logisches Deutsch are in the folder
`examples/de/`: `staatsbuergerschaft`, `gluecklicher_drache` and `verguetung`.

## Numbers and dates

In Portuguese, Spanish, French, Italian and German, a comma between two digits is
the decimal comma. Thus `o custo é 1,5` means one and a half. A point divides the
thousands, in groups of exactly three digits: `1.234.567`. In a list, write a
space after each comma between the items, as in `[1, 5]`. Then the editor does not
read the comma as a decimal comma. Dates have the same form in each language, with
the year first: `2026-07-15`.

## Where to find the programs of each language

The landing page of the editor has a line *Other languages*, with one link for
each language. Each link opens a landing page for that language. That landing page
shows only the example programs of that language, and its words are in that
language. You can also open these pages from the address `/multilingual`. That
address shows a list of the languages.

Click an example to open the example in the editor, as on the English landing
page.

## The language of the menus

The language of the menus, the buttons and the messages of the editor is
different from the language of the program. You select the two languages
separately. If the browser of a reader uses English, the reader can edit a program
in Español Lógico with the menus in English. A reader in Lisbon can edit an English
program with the menus in Portuguese.

When the editor opens in a browser for the first time, the editor uses the
preferred language of the browser. If Logical English does not have that language,
the editor uses English.

To change the language of the menus, do these steps:

1. Open the **Misc** menu.
2. Put the mouse pointer on **Language**.
3. In the list that opens next to **Language**, select a language.

The editor loads the page again in the language that you selected. The browser
keeps your selection for the next visit. When you open a program in another
language, the language of the menus does not change. The landing pages of the
other languages also do not change the language of the menus.

The language of the menus also controls three other things:

- The login page and the executive view show their words in that language. The
  executive view is the page that runs a program and does not show the text of the
  program. Refer to [the executive view](executive-view.md).
- **File ▸ New** starts a new program with the first sentence of that language.
  Thus a reader with Portuguese menus starts a program in Português Lógico.
- When the open program is empty, the LE Assistant answers in that language.

## The assistants

The assistants use the language of the program, not the language of the menus.
The LE Assistant is the chat panel of the editor. The LE Assistant writes the
program in the language of the program. The Scenario Editor and the Query Editor
have a command that changes ordinary sentences into facts or into a query. The
name of the command is **Write it in English…** in the English menus, and
**Escreva em Português…** in the Portuguese menus. This command also writes in the
language of the program. The guide [the assistants](assistants.md) describes the
LE Assistant and the command.

## Improving a language

The words of each language are in a set of tables, with one column for each
language. The tables are in the `i18n` folder of the source code of Logical
English 2. The file `i18n/README.md` in that folder tells how to correct a
translation or how to add a language. A correction to a keyword changes the text
that the editor accepts. Thus, after each change, the test programs of each
language must run again.

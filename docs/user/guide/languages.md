# Logical English in other languages

You can write Logical English in five natural languages. Each language has its
own version of Logical English:

| Language | Name of its Logical English | First sentence of a program | How complete |
|---|---|---|---|
| English | Logical English | `the target language is: prolog.` | complete |
| Portuguese | Português Lógico | `a linguagem alvo é: prolog.` | pilot |
| Spanish | Español Lógico | `el lenguaje objetivo es: prolog.` | draft |
| French | Français Logique | `la langue cible est: prolog.` | draft |
| Italian | Italiano Logico | `il linguaggio obiettivo è: prolog.` | draft |

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

| English | Português | Español | Français | Italiano |
|---|---|---|---|---|
| the templates are | os modelos são | las plantillas son | les modèles sont | i modelli sono |
| the knowledge base … includes | a base de conhecimento … inclui | la base de conocimiento … incluye | la base de connaissances … comprend | la base di conoscenza … include |
| if | se | si | si | se |
| and | e | y | et | e |
| or | ou | o | ou | o |
| it is not the case that | não é o caso que | no es el caso que | il est faux que | non è il caso che |
| scenario … is | cenário … é | escenario … es | scénario … est | scenario … è |
| query … is | consulta … é | consulta … es | requête … est | interrogazione … è |
| expects | espera | espera | attend | attende |

The [language reference](../reference/language.md) describes each construct in
English. There is also a Portuguese translation of the reference:
[Resumo da sintaxe do Português Lógico](../reference/language.pt.md).

## Numbers and dates

In Portuguese, Spanish, French and Italian, a comma between two digits is the
decimal comma. Thus `o custo é 1,5` means one and a half. A point divides the
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

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
languages. Logisches Deutsch reads many sentences as German writes them. It does
not read all of German. This section tells what it reads, and what it does not.

Below is the rule about British nationality in Logisches Deutsch:

```
Die Zielsprache ist: prolog.

Die Vorlagen sind:
*eine Person* erwirbt an *einem Datum* die britische Staatsangehörigkeit,
*eine Person* wurde an *einem Datum* in *einem Ort* geboren,
*ein Datum* liegt nach dem Inkrafttreten,
*eine Person* ist die Mutter *einer Person*,
*eine Person* besitzt an *einem Datum* die britische Staatsangehörigkeit.

Die Wissensbasis Staatsangehoerigkeit enthält:

Eine Person erwirbt an einem Datum die britische Staatsangehörigkeit,
wenn die Person an dem Datum im Vereinigten Königreich geboren wurde
    und das Datum nach dem Inkrafttreten liegt
    und eine andere Person die Mutter der Person ist
    und die andere Person an dem Datum die britische Staatsangehörigkeit besitzt.

Szenario alice ist:
    John wurde am 09.10.2021 im Vereinigten Königreich geboren.
    2021-10-09 liegt nach dem Inkrafttreten.
    Alice ist die Mutter von John.
    Alice besitzt am 09.10.2021 die britische Staatsangehörigkeit.
```

### What Logisches Deutsch reads

- **A template is a main clause.** Write each template with its verb in the
  second position, as in a statement: `*eine Person* wurde an *einem Datum* in
  *einem Ort* geboren`. A fact in a scenario has the same order.
- **Each condition of a rule starts on a new line.** This rule applies to each
  language of Logical English. Write `wenn`, `und` or `oder` at the start of the
  line.
- **After `wenn`, `falls` and `dass`, the verb is at the end**: `wenn die Person
  an dem Datum im Vereinigten Königreich geboren wurde`. Logisches Deutsch finds
  the template of such a clause. A verb in two parts is one word there, and
  Logisches Deutsch finds its template also: `wenn die Erklärung dem Empfänger
  zugeht` for the template `*eine Erklärung* geht *einem Empfänger* zu`.
- **After a word that takes the first position, the verb comes before the
  subject.** This order occurs in Logical English for LPS, after `dann` and
  `anfangs`: `dann wird das Feuer bekämpft`, `anfangs gibt es ein Feuer`.
- **A comma between clauses is permitted**: before `wenn`, `falls`, `dass`,
  `und`, `oder`, `dann`, `es sei denn`, `sofern nicht`, `in denen`, and after
  `es sei denn`.
- **The first word of a sentence can have a capital letter**: `Die Vorlagen
  sind:`, `Eine Person erwirbt …`, `Wenn …`. Write the nouns of the keywords with
  a capital letter, as the table above shows them.
- **Negation with `nicht`.** A clause with `nicht` (or `nicht mehr`) is the
  negation of the same clause without the word, when the clause without the word
  is a sentence of one of your templates: `und die Person nicht das siebente
  Lebensjahr vollendet hat`. You can also write `es ist nicht der Fall, dass …`.
  In a clause after `wenn`, the order of these words is `es nicht der Fall ist,
  dass …`.
- **Exceptions**: `es sei denn, …` (with a main clause, or with `dass` and the
  verb at the end), `sofern nicht …`, `soweit nicht …`, `wenn nicht …` and
  `außer wenn …`.
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
  `-es`, `-e`, `-ses` and `-ns`.
- **The genitive.** Write a template with a genitive: `*eine Person* ist die
  Mutter *einer Person*`. A rule then says `die Mutter der Person`. Before a
  name, write `von`: `Alice ist die Mutter von John`. `der Kontostand des
  Zahlers` and `der Kontostand von Bob` fill the same template.
- **Short forms.** `am`, `im`, `zum`, `zur`, `vom`, `beim`, `ins` and `ans` are
  the same as `an dem`, `in dem`, `zu dem`, `zu der`, `von dem`, `bei dem`, `in
  das` and `an das`. Before a date or a number, the short form is only the
  preposition: `am 2021-10-09` gives the date to the template `an *einem Datum*`.
  An answer shows the short form again.
- **Thresholds.** `ist mindestens`, `ist höchstens`, `beträgt mindestens`,
  `beträgt höchstens`, `übersteigt` and `unterschreitet` compare two numbers.
- **Names.** A name is one word or more, with or without a capital letter:
  `Bob`, `Frau Adler`. A variable that you name with a letter has capital
  letters only: `eine Person X`, `ein Betrag B`, `ein Zeitpunkt T1`.

### What Logisches Deutsch does not read

When Logisches Deutsch does not read a sentence, the editor shows an error or a
warning in most cases. Always give your scenarios expected answers. Then a
sentence that is read incorrectly shows as a test that fails.

- **`kein` is not a negation.** `kein Vermieter hat die Untervermietung
  untersagt` is not read as a negation, and the editor shows a warning. Write
  `es ist nicht der Fall, dass ein Vermieter …`.
- **An adjective used as a noun changes its ending with the article**: `ein
  Beamter`, `der Beamte`; `ein Dritter`, `der Dritte`. Logisches Deutsch does
  not read these two forms as one variable. The editor shows a warning. Name
  the variable with a letter: `Ein Beamter B ist vereidigt, wenn B einen Eid
  leistet.`
- **The name of a thing must have the same form each time.** `das Vereinigte
  Königreich` and `dem Vereinigten Königreich` are two different names. The
  example above always writes `im Vereinigten Königreich`.
- **Two values need a word between them.** The template `*ein Verkäufer*
  verkauft *einem Käufer* *eine Sache*` is not possible. Write `*ein
  Verkäufer* verkauft *eine Sache* an *einen Käufer*`.
- **`sofern` and `soweit` are not conditions.** Write `wenn` or `falls`. (`sofern
  nicht` and `soweit nicht` are exceptions, and they are read.)
- **A sentence has the order of its template, with only the verb moved.** A
  sentence that starts with a different part (`durch die Geburt erwirbt ein
  Kind …`) does not match the template `*ein Kind* erwirbt durch die Geburt …`.
- **Relative clauses, pronouns and plurals are not read**: `eine Person, die …`,
  `wenn sie volljährig ist`, `Anna und Bert sind Menschen`. Write one sentence
  for each fact, and repeat the noun.
- **A point ends the sentence.** Do not write `das 18. Lebensjahr`. Write `das
  achtzehnte Lebensjahr`.

## Numbers and dates in German

- Write a number as German writes it: `1.250.000`, `10.000,50`, `1,5`. A number
  with a point as the decimal sign (`1.5`), with a space (`1 000`) or with a
  currency sign (`1.250,50 €`) is not a number for Logisches Deutsch. It is read
  as a name, and the editor shows a warning. Put the unit in the template: `…
  beträgt *einen Betrag* Euro`.
- Write a date as `2026-03-02` or as `02.03.2026`. A date with the name of the
  month (`2. März 2026`) is not read, and the editor shows a warning. An answer
  shows a date with the year first.

The three example programs of Logisches Deutsch are in the folder
`examples/de/`: `staatsangehoerigkeit`, `gluecklicher_drache` and `verguetung`.

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

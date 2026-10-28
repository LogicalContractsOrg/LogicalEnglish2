# Readable documents: a program for people who do not use the editor

*Kind: guide · Audience: users · Status: current (2026-10-28)*

A **readable document** is a Logical English program, set out for a person who reads
it without the editor. This person is usually a domain expert: a lawyer, an
underwriter, a policy officer. The domain expert must make sure that the rules say
what the regulation, the contract or the policy says.

The document is the program, word for word. The document does not add words, and it
does not change words. It only shows the program in a form that is easy to read:

- Each statement of the program has a number.
- A section of the program (the templates, the knowledge base, each scenario, each
  query) is a heading. The document starts with a list of the headings.
- The words have a style for what they are. A **keyword** is a word of Logical
  English itself, such as *if* or *and*. A **template** is a sentence pattern of the
  program. A **variable**, such as *a person*, stands for any thing of its kind. A
  **value**, such as *Alice*, is one fixed thing.
- Each sentence in a rule, a scenario or a query is a link. The link goes to the
  place where the program defines the sentence: the first rule or fact that
  concludes it. When no rule concludes it, the link goes to its template.
- Each rule tells the numbers of the statements that use it. Each template tells
  the numbers of the statements that define it and use it.
- An index of the templates is at the end.
- A decision table is a table.

The idea comes from *literate programming*: a program is a text for people first
(refer to <https://en.wikipedia.org/wiki/Literate_programming>).

## Contents

- [Making a readable document](#making-a-readable-document)
- [The formats](#the-formats)
- [The styles](#the-styles)
- [Comments and notices](#comments-and-notices)
- [Included resources](#included-resources)
- [The address of a readable document](#the-address-of-a-readable-document)
- [Programs for LPS](#programs-for-lps)

## Making a readable document

Do these steps:

1. Open the program in the editor.
2. Select **File > Save as a Readable Document…**.
3. In **Format**, select the format of the document.
4. In **Style**, select how the web page looks when it opens.
5. To include the comments of the program, select **Include the comments of the
   program**.
6. Click **Open** to show the document in a new tab, or click **Save…** to save it
   as a file. To send the address of the document to somebody, click **Copy link**
   (refer to [The address of a readable document](#the-address-of-a-readable-document)).

The document shows the text in the editor, also when you did not save it.

## The formats

| Format | What you get |
|---|---|
| **Web page (HTML)** | One file. The styles are in the file, thus you can send the file by email and read it with no connection to the internet. The page has a **Style** menu and a **Print or save as PDF** button. |
| **PDF (printed from the browser)** | The web page opens in a new tab with the print dialog of the browser. Select **Save as PDF** in that dialog. |
| **Word (.docx)** | A Word document with the same statements, links and index. Each kind of word has a character style of its own (*LE Keyword*, *LE Template*, *LE Variable*, *LE Value*, *LE Place*). Thus you can change how the words look in Word. |
| **Markdown** | Text for a site or a repository that shows Markdown (for example GitHub). |

## The styles

The web page has five styles. Use the **Style** menu at the top right of the page to
change the style. The browser keeps the style that you selected, when the browser
permits this.

| Style | For |
|---|---|
| **Plain** | Reading. A quiet look with a serif font. This is the default. |
| **Compact** | A long program. Small text and less space between the statements. |
| **Legal** | A reader who knows statutes. The headings are centred, the statement numbers are bold, and the text is justified. |
| **Colourful** | Young readers, and teaching. More colour, a card for each statement, and an icon for each kind of statement. |
| **Editor colours** | A reader who also uses the editor. The colours and the font of the editor. |

When you print the page, the page uses the style on the screen. The menu and the
legend are not printed.

## Comments and notices

A comment of a program is a note of the author. A comment can be private: for
example, a question for a colleague. A readable document goes to more people than
the program does. Thus the document does not show the comments, unless you select
**Include the comments of the program**.

A **notice** is a comment that starts with one of these words: `Copyright`, `©`,
`(c)`, `Licence`, `License`, `Licensed under`, `Disclaimer`, `Legal notice` or
`SPDX-License-Identifier:`. The document always shows the notices, at the start and
at the end. A notice continues to the next empty comment line. Example:

```le
% Copyright 2026 Example Ltd. All rights reserved.
% Licensed under the Apache License, Version 2.0.
%
% This line is a usual comment: the document does not show it.
the target language is: prolog.
```

Refer to §10 of the [language reference](../reference/language.md#10-comments).

## Included resources

A program can include other Logical English files (§14 of the
[language reference](../reference/language.md#14-included-resources)). A sentence whose
template an included file defines is a link to the readable document of that file.
The link goes to the server, thus the reader must be connected to the internet and
signed in.

## The address of a readable document

Each example program of the server has a readable document at this address:

```
/readable/<example>?format=html&style=plain
```

- `format` is `html`, `pdf`, `docx` or `md`.
- `style` is `plain`, `compact`, `legal`, `cute` (the **Colourful** style) or
  `editor`.
- `comments=true` includes the comments.

An example is `/readable/citizenship?format=html&style=legal`.

To give the address to a colleague, do these steps:

1. Open the program from the examples of the server (**File > Open example from
   server…**).
2. Select **File > Save as a Readable Document…**.
3. Select the format, the style and the comments.
4. Click **Copy link**.
5. Paste the address into your message.

The address shows the program as the server keeps it. It does not show the changes
that you did not save. **Copy link** is not available for a program that the server
does not keep, for example a file from your computer.

To make a document, the server loads the program. Thus the address is only for
people who are signed in. When you are not signed in, the server opens the sign-in
page first, and then the document. The document of a program of a licensed
collection opens only for people whose licence includes that collection. Refer to
[Signing in, and what a licence adds](accounts.md).

The editor that runs completely in the browser (the WebAssembly version) also makes
readable documents. That version has no server, thus its documents have no links to
the documents of included resources.

## Programs for LPS

A program for LPS (Logic Production System; `the target language is: lps.`) has a
readable document of the same kind. Its causal laws (`when … then …`), reactive
rules (`if … then …`), constraints and `initially` sentences are statements of
their own kinds. The fluents, the events and the actions are headings. A sentence
links to the law that makes it true.

The LPS2 editor has the same command: **File > Save as a readable document…**, with
the same **Copy link** button. For a program in the older syntax of LPS (an `.lps`
file), the document shows the program after the conversion to Logical English
(**Misc > Convert to Logical English…**).

The LPS2 server gives the documents of its own examples at the same kind of address,
for example `/readable/le/goat?format=html&style=legal`. The same rule applies: the
address is only for people who are signed in. A sentence of a base that a program
extends is a link to the readable document of that base on the LPS2 server.

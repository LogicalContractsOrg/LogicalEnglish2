# The executive view

*Kind: guide · Audience: users · Status: current (2026-09-16)*

The executive view runs an existing Logical English program for the people who use
the program, not for the people who write the program. These users ask the program
questions, try cases on the program, and read the reasons for each answer. The
executive view does not show the text of the program, and it does not change the
program. The page operates on a phone and on a desktop computer. On a phone, tap
where this guide tells you to click. The page is at **`/executive`** on the server
(for example `http://localhost:3050/executive`). The landing page has a link to the
page.

## Contents

- [Choosing a program](#choosing-a-program)
- [Asking a question](#asking-a-question)
- [Reading an answer](#reading-an-answer)
  - [Citations first](#citations-first)
  - [The source viewer](#the-source-viewer)
  - [When there is no answer: why not](#when-there-is-no-answer-why-not)
- [Scenario Variations](#scenario-variations)
- [Views](#views)
- [Links: the address of a result](#links-the-address-of-a-result)
- [From the editor](#from-the-editor)
- [Logging in](#logging-in)
- [Language](#language)

## Choosing a program

When you open `/executive` with nothing added to its address, the page shows a list
of the example programs on the server.

To open a program, do these steps:

1. Type in **Filter…** to make the list shorter.
2. Click the name of a program.

The program opens. To go back to the list, click the **←** at the top left of the
program.

## Asking a question

The screen of a program has two lists. The **Scenario** list contains the scenarios
of the program and *(no scenario)*. A scenario is a set of facts, with a name, that
describes one case. The **Query** list contains the queries of the program. A query
is a question to the program. The list shows each query by its text.

There is no Run button. The program opens on its first scenario and immediately
runs the selected query. When you select a different item in one of the two lists,
the query runs again. The answers appear below the lists.

If problems occurred while the program loaded, the screen shows the first problems
at the top. If a program has no queries, the screen tells you.

## Reading an answer

Each answer is a card. Click the card to open its explanation. Some answers are
true only because of an assumption. An assumption is a fact that the scenario marks
as *unknown*. Such a card shows those assumptions after the answer, as
*(assuming: …)*.

The explanation is a tree of steps. Each step is indented below the step that it
helps to prove:

- Green shows what the reasoner proved. Red shows what failed. Amber shows what the
  reasoner assumed. The reasoner is the part of the system that finds the answers.
- A step can be true because a different thing failed (*it is not the case that …*,
  *for all …*). Such a step keeps those failures closed, behind a small triangle.
  The failures record the search, not the reasons.
- A part of the explanation that occurs more than one time appears only one time.
  It shows the number of times that it occurred (*×3*), or the words
  *(shown above)*.

### Citations first

A program can cite its sources. When a program cites its sources, an open answer
starts with its **Citations**. The citations are the steps of the proof that cite a
document, in the sequence of the proof. A rule or a table cites its source with
`with provenance`. A fact cites its source with `as stated in …`, `according to …`
or `confer "…"`. Refer to [the language reference](../reference/language.md) §17.1.
Each step shows the sentence that the reasoner proved. It also shows one line that
tells the source of the sentence. That line gives the rule and the document. It
also gives the quoted text, or the place in the document, for example *page 1* or
*paragraph 25*.

- **Copy** puts the numbered list of cited steps on the clipboard, each step with
  its citation.
- **Full explanation ↓** goes to the full tree. The tree is closed, below the list.

If the proof of an answer cites nothing, the answer shows the tree immediately.

### The source viewer

A cited step has a **§** button in two cases:

- The server can get the text of the document, because the program tells where the
  text is, with `the text of <document> is at "…"`.
- The document has a published address.

The **§** button opens the document in the source viewer. The source viewer marks
the cited text. If the program gives only a web address, the document opens in a
new tab.

### When there is no answer: why not

When a query has no answer, the card says *No — no answers for this query.* Under
**Why not**, the card shows the conditions that the case did not satisfy. A program
can have more than one way to get to the answer. The card shows only the ways that
came nearest to the answer. These ways are the ways in which the most conditions
were true before one condition failed. Each condition has one of two marks:

- **not stated**: a fact that the case could state, but does not state. The record
  says nothing about that fact.
- **not met**: a test that is false for the values of the case, a fact that the
  case states differently, or a denial whose subject is true.

Next to each condition are the rule that needs the condition and the citation of
that rule. After the word *given:*, the card shows the facts that the rule
compared. A **§** opens the cited text, as described above. The full explanation of
the failure is closed, below.

## Scenario Variations

The **Scenario Variations** button is between the two lists. The button opens the
Scenario Variations window of the editor on the same program, in a new tab. The
window starts from the scenario and the query that you selected. In that window,
you can change, delete, add or assume facts. You can also run queries on the
changed case. The program itself does not change. Refer to
[Scenario Variations](editor.md#scenario-variations) in the editor guide.

## Views

A program can tell how its screen must look, in a *view* section at the end of the
program. Refer to [the language reference](../reference/language.md) §17.10, and to
the tutorial [LE Views](../tutorials/views.md). If a program has views, it shows
them in a **Views:** strip at the top. Click a view to open it. Then the view
replaces the two lists. It shows the title and the screen that its author
described. The content of that screen changes with the view:

- the facts of the case in groups, which you can edit;
- the result in large letters;
- the citations or the reasons of the result (*Why not* when the result fails);
- the stage that the result gets to;
- the missing facts;
- the smallest changes that change the result;
- the answers to other questions, as tables;
- a comparison with a different scenario;
- the documents next to the facts;
- each case with its result;
- a draft text;
- or an interview, with one question at a time.

**Without a view** shows the lists again.

If a program does not declare a view, the program gives an **Automatic view**. The
server makes the automatic view from the program when you open the view. The
automatic view is the same draft that the *Generate LE view* button of the editor
makes. A note on the screen tells you this.

To open a view takes some seconds. The program must load, and then the server must
calculate the first result. During this time, the page says *Opening the view…* and
shows a waiting cursor.

## Links: the address of a result

The address contains all the things that the screen shows. Thus you can bookmark a
result or share it. You can add these parts to the address:

| Parameter | Meaning |
|---|---|
| `program=<name>` | the example program, with its name in the list (for example `citizenship`, `regulatory/eu261_integration`) |
| `scenario=<name>` | the scenario to select |
| `query=<name>` | the query to select |
| `view=<name>` | a view of the program to open; `view=*` opens the automatic view |

When you change the lists, the lists also change the address. The case list of a
view also changes the address: it sets `scenario=`. If a link names a program, a
scenario and a query, the link runs that query immediately when it opens. For
example:

```
/executive?program=citizenship&scenario=alice&query=one
/executive?program=regulatory/eu261_integration&view=claim%20desk
```

If the address names a scenario or a query that the program does not have, the page
ignores the name. Then the page selects the first scenario.

## From the editor

In the editor, **Misc ▸ Open Executive View** opens the program in the executive
view, in a new tab. The executive view uses the scenario and the query that you
selected in the editor. The new tab shows the program *as it is in the editor*,
with the changes that you did not save. The views in the list also come from that
text. The **Open the view** link of *Generate LE view* operates in the same way.

The editor gives the text to the executive view through the storage of the browser.
The address contains a `text=` key that names the location of the text. If you open
such a link in a different browser, the page tells you that the copy of the editor
is not in that browser. Then the page shows the program as you last saved it.

## Logging in

The top right of the page shows **Login**. After you log in, it shows your email
address and **Logout**, as the landing page does. **Login** and **Logout** both send
you back to the page that you were on. Some example programs are available only to
users with a specific role. If you log in with such a role, the list shows those
programs. You can open those programs and the documents that they cite.

## Language

The words of the page (buttons, labels and messages) use the language that you
selected on the multilingual landing page (`/multilingual`). The sentences of the
program stay in the language of the program.

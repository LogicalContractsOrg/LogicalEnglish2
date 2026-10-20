# The assistants: language models in the editor

*Kind: guide · Audience: users · Status: current (2026-09-16)*

Three functions of Logical English 2 (LE2) use a large language model (LLM) to write
Logical English for you. An LLM is a program that learned from very large quantities
of text. Thus it can read and write usual language. These are the three functions:

- the **LE Assistant**: a chat panel in the editor. It reads, writes and examines the
  program that you have open.
- **Write it in English**: a function in the Scenario Editor and the Query Editor. It
  changes sentences into facts or a query that use the templates of your program. (A
  template is the pattern of a sentence, with slots for the values.)
- the **Contract Assistant**: a separate web page. It changes a contract (wording,
  schedule, cases) into a tested program. It can also write one scenario or one query
  for a program that you already have. It does this work as a background job.

In all three functions, the Logical English verifier examines the text of the model
before you receive the text. The verifier tells you about each problem that it
finds. The model never decides the answers. Your program decides them, when you run
it.

Two functions in the editor do not need a model:

- **Generate LE view** in the header of the LE Assistant. This function makes a draft
  of a view from the program itself (refer to
  [the editor guide](editor.md#generate-le-view-le-assistant)).
- The translators of the files of other systems
  ([importing and exporting](../integrations/index.md)).

## Contents

- [Setting up: models and API keys](#setting-up-models-and-api-keys)
- [The LE Assistant](#the-le-assistant)
  - [Light and Deep modes](#light-and-deep-modes)
- [Write it in English](#write-it-in-english)
- [The Contract Assistant](#the-contract-assistant)
  - [What to generate](#what-to-generate)
  - [A whole program](#a-whole-program)
  - [Running, leaving, coming back](#running-leaving-coming-back)
  - [The result](#the-result)

## Setting up: models and API keys

In the editor, select **Misc ▸ API Keys & Assistant Settings…**. The dialog has these
settings:

- **Assistant Model** gives the list of the models that this server knows. Each model
  has its provider (OpenAI, Anthropic, Google, Groq, Together).
- There is one **API key** field for each provider. (API means Application
  Programming Interface.) An API key is the pass phrase that lets the editor use the
  models of that provider. Sometimes the server already has a key for a provider.
  Then the field shows *Provided by server*, and you cannot change it. You need your
  own key only for a provider that has no key on the server.
- **Assistant Max Steps (1–50)**: the maximum number of turns that the Light mode of
  the LE Assistant can use for one request. If you do not change the number, the
  maximum is 10.

Your browser keeps the keys and the settings in its own store. The editor sends them
with each request that needs them. The LE Assistant and Write it in English use the
same model and the same keys. The Contract Assistant page reads the same stored keys.
Thus a key that you set in one place operates in the two places.

Sometimes you did not select a model, or the provider of the selected model has no
key. Then the LE Assistant answers with a warning that refers you to this dialog.
Write it in English then makes its **Generate** button unavailable.

## The LE Assistant

The **LE Assistant** tab is in the bottom panel of the editor. It is a chat about the
program in the tab that you have open. Type a request and click **Send** (or push
Enter). Some examples of requests are:

- *Fix the errors in this program.*
- *Why does scenario alice give no answer to query one?*
- *Add a rule: a person is a citizen if a parent is a citizen.*
- *Draft a program for the following regulation: …*

While the assistant works, a line below the input box tells what it does at that
time. **Interrupt** stops the assistant. When the assistant is done, the panel shows
its explanation, with headings and lists. Sometimes the assistant changed the
program. Then the new version replaces the text in the editor, and the panel says
*I have updated the editor content with the changes.* The full replacement is one
edit. Thus **Undo** in the editor immediately gives back the previous text. A reply
can also have a folded *System Logs (stderr)* section. This section contains the
technical record of the run.

Each open tab has its own conversation. A reply comes back to the program that asked
for it. This is true also if you went to a different tab during the work.

You can also ask the assistant about Logical English or about the editor. Examples
are *How do I write a decision table?* and *What does "otherwise" do?* The assistant
searches this documentation for your question and gives a short answer. At the end,
it gives a maximum of three links to the sections that tell you more. A link opens in
a new browser tab. A request to change the program gets no links.

### Light and Deep modes

The **Light Mode** box in the header of the panel selects how the assistant works.
Your browser keeps your selection.

- **Light** is the default mode, and it runs on the server itself. The server gives
  the model the Logical English reference and a set of example programs. The model
  can do two things to the program that it edits:
  - **verify** the program: load the program and examine it.
  - **query** the program: run one query on one scenario.

  The model then does the work again. It repairs the problems that the verifier
  found, and examines the tests. It continues until it is done or until it has used
  all its permitted steps. Each request starts again from the program as it is in
  the editor. The editor does not send the earlier messages in the panel again.
- **Deep** runs a full coding assistant on the server, the program `opencode`. Deep
  mode works on a file, with the same two Logical English tools. It can also search
  through files, download web pages and run commands. Deep mode is slower to start.
  It is good for larger tasks, for example a draft of a program from a regulation
  that needs research first. Deep mode also keeps the full conversation of a tab from
  one request to the next. For Deep mode, the server must have `opencode` installed.

## Write it in English

In the **Scenario Editor** (Edit ▸ Edit Scenarios…), the last item of the **Add fact**
menu is **Write it in English**. In the **Query Editor** (Edit ▸ Edit Queries…), the
same item is the last item of **Add condition**. When you select the item, a dialog
opens. Do these steps:

1. Type one or more sentences. For facts, an example is *Alice is the mother of John,
   and John was born in the UK on 2021-10-09.* For a query, type a question.
2. Click **Generate** (or push Ctrl/Cmd+Enter). The dialog shows the model that it
   uses.

The model writes facts, or query conditions. It uses **only the templates that your
program already has**. The model selects the words and the tense. Sometimes your
sentence gives no value for a blank. Then the model keeps the words of the blank, for
example `a date`. The editor then compares the result with your program. The editor
counts only the problems that your program did not already have. If there are such
problems, the editor asks the model to correct them, for some rounds.

If there is no new problem, the editor immediately adds the result as usual rows. You
can edit these rows. If problems stay, the dialog shows the text and the list of
problems, with the errors first. Then you can click **Insert anyway**. Or you can
write your sentence in different words and click **Regenerate**. An *[error]* means
that the text does not do what it says. Thus it is usually better to write the
sentence in different words.

Sometimes your sentence needs a kind of statement that the program does not have.
Then add the template for that statement first, in the editor or with the LE
Assistant.

**From a document.** In the Scenario Editor, the dialog has a folded **From a
document** section. Give the name of the document there. You can also give the
address of its text: a web address, or a file next to the program. Then click
**Fetch text** to put the text into the box. Each fact that the model then writes
cites the passage that states it, as `confer "…"`. The scenario gives the name of the
document.

## The Contract Assistant

The Contract Assistant is a separate web page, at
**`/web_extras/contract_assistant/index.html`** on the server. It is a part of the
**Logical English Translators** licence. You must sign in with an account that has
that licence ([signing in](accounts.md)). The Contract Assistant runs longer tasks on
the server. Each task stays within a budget that you set. One run can call the model
many times. A run can take some minutes or some hours. The cost depends on the models
and on the effort that you select.

The Contract Assistant needs a model and a key for the model (**3. Model**). A key
field appears only for the provider of the model that you selected. It appears only
when the server has no key for that provider. The **Judge model** does only two
things: it merges the vocabulary samples, and it writes the coverage ledger. Thus a
less expensive model is usually sufficient. **Branches also drafted by** gives the
name of a second model. Sometimes a run writes two or more competing drafts. Then the
main model and the second model write them in turn, and the same tests select the
best draft. For example, you can use a model from one company together with an
"open-weight" model. An open-weight model is a model with published weights. Then you
let the tests select. **Additional instructions** and the **Effort budget** (refer to
[A whole program](#a-whole-program)) apply in each mode.

### What to generate

- **A whole program**: a contract wording, with its schedule and its specific cases,
  becomes a full program (templates, rules, scenarios, queries). The program has a
  coverage ledger, clause by clause. Refer to [A whole program](#a-whole-program).
- **One scenario**: paste a Logical English program that you think is correct.
  Describe a situation in English. You receive one `scenario … is:` block for the
  situation. **Expected answers** selects if the scenario gets `expects answers`
  lines. There are three choices:
  - *auto*: only when your text states the result.
  - *always*: where a query is applicable.
  - *never*.
- **One query**: the same, for a question. You receive one `query … is:` block.
- **Migration residue**: paste a program that a translator wrote from a different
  system, when the program still has `RESIDUE` blocks
  ([importing and exporting](../integrations/index.md#what-could-not-be-translated)).
  The assistant translates only these blocks. Then it runs the tests of the program.
  Sometimes a test passed before, and gives different answers after the translation.
  That is damage, and the assistant must repair it. Sometimes the answers of a test
  stay correct, but now they depend on different unknowns. That is not damage. The
  reason is that the translation of a block changes what an answer depends on. You
  can add background text, for example the documentation of the other system. But
  this is not necessary.

  More about the migration residue mode:
  - In a program with many blocks, the assistant translates approximately twenty
    blocks at a time. Thus each request stays small.
  - Sometimes a block stays as it was. Sometimes the assistant translates a block
    into rules that only examine again what the rule that uses the block already
    examines. In these two conditions, the block counts as not done.
  - Sometimes a block gives its source (a `% provenance:` line). Then each rule that
    the assistant writes for the block cites that source. The other rules of the
    program cite their sources in the same way.
  - Sometimes the assistant translates a block into one rule. The assistant then
    moves the conditions of that rule into the rules that use the block, and removes
    the block. This is folding. The text of the block stays as a comment above each
    of these rules. The assistant also keeps the program from before the folding.
  - The assistant does not fold a block when a scenario gives the name of the block.

In the scenario, query and residue modes, the assistant only reads the program that
you paste. It never changes that program. The assistant does not make new templates.
Sometimes your text needs words that the program does not declare. Then the assistant
writes what it can. In a `%` comment on the block, it tells what it could not
express. You can give the block a **Name**, but this is not necessary.

These three modes do the same work as *Write it in English*, but with a budget.
*Write it in English* is one call to the model, and you wait some seconds. Use the
Contract Assistant when the block is sufficiently important to pay for more checks.

### A whole program

Do these steps:

1. **Documents.** Give the documents:
   - The **contract wording** is necessary: a file, or the web address where it is
     published.
   - **Schedule** and **cases / claims** are optional. Each one can be more than one
     file.

   Markdown or plain text is best. The server can also convert some other formats,
   if the necessary tools are installed. These formats are a Word file (`.docx`, with
   the pandoc tool), a web page, and a PDF. For a PDF, the server uses pdftotext or
   PyMuPDF4LLM. These tools read a page with two columns one column at a time.
   Schedules and cases can also be in JSON or CSV. JSON and CSV are two usual formats
   for structured data as text. A JSON list of claims gives one case, and thus one
   scenario, for each item in the list.
2. **Target section** (optional, but strongly recommended). Give a section title or a
   span:
   - A section title selects that section, with its subsections and the general
     terms.
   - A span is for example
     `from Employers' liability until Property definitions`. Add `(inclusive)` to
     keep the last section.

   For the full wording, keep the field empty.
3. **Existing LE code** (optional). Give templates, scenarios with the answers that you
   expect, and rules that you already wrote. The program that the assistant writes
   must contain your code and must agree with it. The result tells how much of your
   code stayed word for word.
4. **Additional instructions** (optional). Write any text that you want. The assistant
   adds it to each request for a draft and to each request for a repair. Sometimes
   your instructions are different from the usual conventions of the assistant. Then
   your instructions have priority. The assistant writes scenarios only for the cases
   that you give, unless your instructions ask for more.
5. **Effort budget**. **Draft** takes approximately 15 minutes, **Standard**
   approximately 45 minutes and **Thorough** approximately 2 hours. The three budgets
   are different in three numbers: the number of vocabulary samples, the number of
   competing drafts, and the number of difficult test cases for the best draft.
   **Advanced** shows each of these numbers and settings, and you can select them
   yourself. After you select a wording file, the page shows an **estimate of the
   cost** before you start.

The program contains these items in addition to its rules:

- **Citations.** The program gives the wording as a document: where it is published,
  and the file that contains its text. Each rule that encodes a clause cites the
  clause, with the number of the clause and a quotation of its words
  (`rule … with provenance the policy at article III.B.8, confer "…"`). An
  explanation then shows the clause next to each step. The editor opens the quoted
  passage in the wording
  ([provenance](../reference/language.md#171-provenance-trailers-and-judged-templates)).
  The assistant compares the quotations with the text. If the wording does not
  contain a quotation, the assistant sends the quotation back for repair, with the
  passage that is most similar to it.
- **Sections.** The rules are in groups, in sections. If the wording has that shape,
  there are three sections. The *applicability* section tells if the contract
  applies. The *question* section tells if the claim is covered. The *remedy* section
  tells what is paid. When a claim fails, the report gives the section where it
  stopped.
- **A view.** A view is a screen for the person who decides cases. The executive view
  shows it ([views](../reference/language.md#1710-views-how-a-screen-shows-a-program)).
  The assistant selects the shape of the view from the kind of contract:
  - a claims desk for an insurance policy,
  - a default desk for a loan or a derivative,
  - an interview for an eligibility rule,
  - an obligations desk for a service contract.

  A claims desk shows the facts of a claim in groups, the judgments of the adjuster,
  and the amount payable. It also shows the clauses that the amount depends on, the
  changes that can change the amount, and the other claims with their results.

Click **Generate Logical English**. The assistant then writes more than one draft. It
examines each draft and repairs it with the cases. It keeps the best of all the
drafts. To compare the drafts, the assistant uses these preferences:

1. A program that has tests.
2. Of these programs, a program with fewer errors.
3. Of these programs, a program that passes more of its tests.

If you gave two or more cases, the assistant does not use some of them during the
drafts. It then gives a score to the result on these cases, which the drafts did not
see.

### Running, leaving, coming back

The run screen shows these items:

- the stage of the work,
- one card for each draft, with its errors, warnings and tests,
- a record of the events, which continues during the run,
- the time since the start,
- a **Cancel** button.

The work continues inside the server, not inside the page. Thus you can close the tab.
The address of the page contains the identifying name of the run, after the `#`. You
can open that address again to join the run again. You can also give the address to a
different person. If you do not have such an address, the setup screen shows **Your
recent runs** from this browser. When the server starts again, it does not keep its
runs. But you can recover a finished result from the files that the run left on the
server.

### The result

- the Logical English that the assistant wrote, with **Copy**, **Download .le** and
  **Open in editor**. For a scenario or a query, **Open in editor** opens the new
  block at the end of the program that it is for, exactly as the assistant examined
  it. Some programs are too large to go in a web address. You must download such a
  program, and open it from the file;
- the score of the delivered program, and of each draft;
- for a full program, the **coverage ledger**: the parts that the assistant encoded,
  the parts that it did not encode intentionally, and the parts that are missing;
- reports, where they are applicable:
  - the test cases that agree with the program, and the test cases that do not agree
    with it. A disagreement means that the program is wrong, or that the reading of
    the contract is wrong;
  - how much of your existing code the assistant kept;
  - what a new scenario or query answers when it runs against the program;
  - the score for how stable the program is when the same question has different
    words.

Read the result as you read the draft of a colleague. The tests show that the program
decides the cases that you gave as you expected. The ledger shows what the program
does not cover.

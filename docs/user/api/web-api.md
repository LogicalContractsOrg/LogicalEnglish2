# Logical English Web API

*Kind: reference · Audience: developers · Status: current (2026-09-16)*

The LE (Logical English) server gives an API. An API is a method that lets one
program ask a different program to do a task. The API is at the web address
`POST /leapi`. The port is 3050, unless the server started on a different port. A
request and its reply are both in JSON (JavaScript Object Notation). JSON is a
plain-text method to write data. Requests and replies go over HTTP, the protocol of
the web. The Prolog file `classic_web_api.pl` contains the server side of this
exchange. This document describes all the operations of `/leapi`, in groups by their
purpose. At the end, it gives the other web addresses of the server. The address
that uses MCP (the Model Context Protocol), and the plain web addresses that do the
same work, are in [mcp.md](mcp.md).

## Table of Contents
- [Conventions](#conventions)
  - [Request and reply](#request-and-reply)
  - [The token](#the-token)
  - [Errors](#errors)
  - [Sessions](#sessions)
  - [Programs sent as text: `le`, `source`, `base`](#programs-sent-as-text-le-source-base)
  - [Example names and access](#example-names-and-access)
- [Operations at a glance](#operations-at-a-glance)
- [Programs and examples](#programs-and-examples)
  - [`list_examples`](#list_examples--list-the-example-programs)
  - [`examples`](#examples--read-an-example-program)
  - [`load`](#load--load-a-program-into-a-new-session)
  - [`documentText`](#documenttext--the-text-of-a-cited-document)
  - [`originals`](#originals--the-original-files-a-program-was-converted-from)
- [Answering queries](#answering-queries)
  - [`answeringQuery`](#answeringquery--answer-a-query-in-a-session)
  - [`interruptQuery`](#interruptquery--interrupt-a-running-query)
  - [`openQuestions`](#openquestions--what-a-case-does-not-state)
  - [`answer`](#answer--load-a-document-and-explain-its-first-answer)
  - [`explain`](#explain--load-a-document-and-explain-every-answer)
  - [`query`](#query--run-a-prolog-goal)
  - [`loadFactsAndQuery`](#loadfactsandquery--add-prolog-facts-to-a-session-and-run-a-goal)
  - [`scaspQuery`](#scaspquery--answer-a-query-with-scasp)
- [Explanations and the Proof Game](#explanations-and-the-proof-game)
  - [`explanationDrill`](#explanationdrill--the-explanation-drill)
  - [`getGameData`](#getgamedata--cards-for-the-proof-game)
  - [`unifyGameNodes`](#unifygamenodes--check-a-proof-game-board)
- [Inspecting a loaded program](#inspecting-a-loaded-program)
  - [`getProlog`](#getprolog--the-prolog-clause-at-a-position)
  - [`predicateAt`](#predicateat--the-predicate-at-a-position)
  - [`predicateOccurrences`](#predicateoccurrences--every-mention-of-the-predicate-at-a-position)
  - [`provenanceAt`](#provenanceat--the-document-cited-at-a-position)
  - [`is_a_hierarchy`](#is_a_hierarchy--the-type-hierarchy)
  - [`graph`](#graph--the-program-as-a-graph)
  - [`testReport`](#testreport--run-the-programs-tests)
- [Views](#views)
  - [`automaticView`](#automaticview--the-automatic-view)
  - [`draftView`](#draftview--draft-a-view-section)
  - [`legalView`](#legalview--the-legal-view-of-an-lps-program)
- [Other targets, import and export](#other-targets-import-and-export)
  - [`getScasp`](#getscasp--the-program-as-scasp)
  - [`getLps`](#getlps--the-program-as-lps)
  - [`importFormats`](#importformats--the-importers)
  - [`importForeign`](#importforeign--translate-another-systems-file)
  - [`exportFormats`](#exportformats--the-exporters-that-apply)
  - [`exportForeign`](#exportforeign--write-the-program-for-another-system)
- [LLM features](#llm-features)
  - [`list_models`](#list_models--the-llm-models)
  - [`nl_to_le`](#nl_to_le--write-it-in-english)
  - [`assistant_command`](#assistant_command--start-an-le-assistant-job)
  - [`assistant_status`](#assistant_status--poll-an-le-assistant-job)
  - [`assistant_interrupt`](#assistant_interrupt--interrupt-an-le-assistant-job)
  - [`contract_start`](#contract_start--start-a-contract-assistant-job)
  - [`contract_status`](#contract_status--poll-a-contract-assistant-job)
  - [`contract_result`](#contract_result--the-result-of-a-contract-assistant-job)
  - [`contract_interrupt`](#contract_interrupt--stop-a-contract-assistant-job)
  - [`contract_cost_estimate`](#contract_cost_estimate--price-a-contract-assistant-job)
- [Explanation tree nodes](#explanation-tree-nodes)
- [Other HTTP endpoints](#other-http-endpoints)
- [Starting the server](#starting-the-server)

---

## Conventions

### Request and reply

Send each request as an HTTP `POST /leapi` with the header
`Content-Type: application/json`. The body of the request is one JSON object. This
object contains `token`, `operation` and the fields that the operation needs. The
server always replies with one JSON object.

```bash
curl -s -X POST http://localhost:3050/leapi \
  -H 'Content-Type: application/json' \
  -d '{"token":"myToken123","operation":"load","file":"citizenship"}'
```

You can add `?lang=<code>` to the address, as in `/leapi?lang=pt`. Then the server
writes its messages in that language for that one request. The language must be one
of the languages that the folder `i18n/` registers. The selected language does not
change how the server reads a program. Each program declares its own language in its
first statement.

### The token

The body must contain `"token": "myToken123"`. The predicate `validate_token/1` sets
this value in the code. The token only keeps out accidental requests. The token gives
no rights and hides nothing. All the clients in this repository send the same token.
If a request does not contain the token, the reply has the status `403` and
`{"error": "Invalid token"}`.

### Errors

- Sometimes an operation cannot do what the request asks. Usually the reply then has
  the status `200` and an `error` field with a message. The section about each
  operation gives the messages of that operation.
- If an operation fails unexpectedly, the reply has the status `500` with
  `{"error": "Operation failed or internal error"}`. The server writes the cause in
  its log. The server also sends the cause to Sentry, if the server is configured to
  report errors. Sentry is a service that collects errors
  ([docs/dev/telemetry.md](../../dev/telemetry.md)).
- If a request names an `operation` that the server does not know, the reply is
  `{"error": "Unknown operation"}`.

### Sessions

The `load` operation puts a program into a *session module*. A session module is a
separate workspace. The reply gives the name of that workspace in the field
`sessionModule`. Each operation that works on a loaded program takes that name in a
field with the same name. A session holds the program, and the facts of the scenario
that the session set last. The server deletes a session after 30 minutes without
use. After that, the operations `answeringQuery`, `getGameData` and
`explanationDrill` reply `{"error": "Session expired", "session_expired": true}`.
Then the editor loads the program again and sends the request a second time. The
other session operations reply `{"error": "No KB loaded"}` when the named session
does not exist. KB is short for knowledge base. The knowledge base is the program
itself.

### Programs sent as text: `le`, `source`, `base`

Some operations take the text of the program, in a field with the name `le`. For
`answer` and `explain`, this field is `document`. These operations accept two more
fields. The two fields are optional. They tell the server where the program is.
Thus the server can find a file that the program `include`s with a relative path:

| Field | Description |
|-------|-------------|
| `source` | the example name with which you opened the text (for example `"regulatory/eu261_integration"`); the server looks for included files in the folder of that example |
| `base` | for a program from a URL (an address on the web): the address below which its included files are (`http://…` or `https://…`) |

If the request gives neither field, the server looks for included files in the
folder where the server started.

A reply frequently refers to a location in the program with a `start` offset. The
offset counts characters from the start of the text. Sometimes such a location is in
an included file. Then the same object also contains `resource`, `resourcePath`,
`resourceExample` (which can be null), `resourceLine`, `resourceStart` and
`resourceEnd`. With these fields, a client can open the included file at that
location.

### Example names and access

An example name is the path of the file of the program below
`examples/moreExamples/`, without the `.le` at the end. Examples are
`"citizenship"` and `"collections/kowalski-book/above_transitivity"`. Alternatively,
a name can start with the code of a language that has its own folder,
`examples/<lang>/`. An example is `"pt/cidadania"`. A name can also start with the
root name of one of the extra folders that `le_extra_examples_dir/2` in `le_kbs.pl`
gives. An example is `"regulatory/…"`. The server then looks for the program in that
folder. A name that starts with `"imported/<id>/…"` is for a program that
`importForeign` wrote.

Some folders of examples are open only to callers with a specific licence.
`restricted_paths.pl` records these folders ([Signing in, and what a licence
adds](../guide/accounts.md)). The server identifies the caller from a cookie. A
cookie is a small note that a browser keeps and sends back with each request. The
sign-in at `/login` makes this cookie. The server then finds the licences for that
email address. A request without such a cookie has no licence. The same rule applies
to the translators of other systems (`importFormats`, `importForeign`,
`exportFormats`, `exportForeign`). A caller without the licence *with extensions*
gets none of these translators.

---

## Operations at a glance

| Operation | Takes | Purpose |
|---|---|---|
| `list_examples` | – | the example names |
| `examples` | `file` | the text of an example |
| `load` | `le` or `file` | load a program, make a session |
| `documentText` | `address` | the text of a cited document |
| `originals` | `source` | the files from which the system converted a program |
| `answeringQuery` | `sessionModule` | answer a query, with explanations |
| `interruptQuery` | `sessionModule` | interrupt an `answeringQuery` that runs |
| `openQuestions` | `sessionModule` | the facts that a case does not have for a query |
| `answer` | `document` | the first answer of a named query in a named scenario |
| `explain` | `document` | all the answers of a named query in a named scenario |
| `query` | `module` | a Prolog goal against a module |
| `loadFactsAndQuery` | `sessionModule` | Prolog facts into a session, then a goal |
| `scaspQuery` | `sessionModule` | answer a query with s(CASP) |
| `explanationDrill` | `sessionModule` | the Explanation Drill |
| `getGameData` | `sessionModule` | the cards of the Proof Game |
| `unifyGameNodes` | `sessionModule` | check a Proof Game board |
| `getProlog` | `sessionModule` | the Prolog clause at an offset |
| `predicateAt` | `sessionModule` | the predicate at an offset, its template and its rules |
| `predicateOccurrences` | `sessionModule` | all the mentions of that predicate |
| `provenanceAt` | `sessionModule` | the document cited at an offset |
| `is_a_hierarchy` | `sessionModule` | the `is a` type hierarchy |
| `graph` | `sessionModule` | templates, rules, facts, scenarios, queries as a graph |
| `testReport` | `le` | run the `expects answers` tests of the program |
| `automaticView` | `sessionModule` | the automatic LE view |
| `draftView` | `sessionModule` | a first view section, as LE text |
| `legalView` | `le` | the legal view of a program in LE for LPS (Logic Production System) |
| `getScasp` | `sessionModule` | the program as s(CASP) |
| `getLps` | `le` or `sessionModule` | the program as LPS |
| `importFormats` | – | the importers |
| `importForeign` | `name`, `text`/`base64` | translate a file of a different system into LE |
| `exportFormats` | `le` | the exporters that can write the program |
| `exportForeign` | `le`, `exporter` | write the program for a different system |
| `list_models` | – | the models of LLMs (large language models), and the providers for which the server has a key |
| `nl_to_le` | `sentence` | English into LE facts or a query, with one call to an LLM |
| `assistant_command` | `command`, `content` | start an LE Assistant job |
| `assistant_status` | `job_id` | ask for the status of the job |
| `assistant_interrupt` | `job_id` | interrupt the job |
| `contract_start` | materials | start a Contract Assistant job |
| `contract_status` | `job` | ask for the status of the job |
| `contract_result` | `job` | the result of the job |
| `contract_interrupt` | `job` | stop the job |
| `contract_cost_estimate` | configuration | the price of the job, before it runs |

---

## Programs and examples

### `list_examples` — List the example programs

**Request**: no fields.

**Reply**

```json
{ "examples": [ "alice", "citizenship", "collections/kowalski-book/above_transitivity", ... ] }
```

The reply gives the names of the `.le` programs that the caller can open. The server
looks through `examples/moreExamples/` and through the extra folders, into all the
folders in them. The server puts the root name of each extra folder in front of the
programs in that folder. A request can use `?lang=` to ask for a language that has
its own folder. Then the programs of that folder come first, as `<lang>/<name>`. The
server does not include copies of the libraries in `lib/`, or the files in `sources/`
folders.

### `examples` — Read an example program

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `file` | string | an example name, for example `"citizenship"` |

**Reply**: `{ "document": "<LE source text>" }`.

- If the name agrees with no file, the reply is
  `{ "answer": "File not found", "details": "<path>", "document": "" }`.
- For a restricted example, the reply is
  `{ "error": "<message>", "loginRequired": true }` when the caller did not sign in.
  The reason is that a sign-in can possibly give access. If the caller signed in but
  has no licence for that example, the reply is `{ "error": "<message>" }`.

### `load` — Load a program into a new session

**Request**: the text, or an example. For the text:

| Field | Type | Description |
|-------|------|-------------|
| `le` | string | the text of the program |
| `source`, `base` | string | optional, [refer to the section above](#programs-sent-as-text-le-source-base) |

For an example:

| Field | Type | Description |
|-------|------|-------------|
| `file` | string | an example name ([refer to the section above](#example-names-and-access)). The server adds `.le` when the name has no extension and a file `<name>.le` exists. The server reads a file whose name ends in `.le` as Logical English. It reads all other files as plain Prolog |

**Reply**

```json
{
  "sessionModule": "s536aee7e-…",
  "kb": "citizenship",
  "language": "le",
  "target": "prolog",
  "templates": [ "a person acquires British citizenship on a date", ... ],
  "template_defs": [ { "label": "*a person* acquires British citizenship on *a date*",
                       "scenario_element": false, "judged": false, "values": [[], []] }, ... ],
  "queries": [ { "name": "one", "template": "acquires_British_citizenship_on(_A,_B)",
                 "le": "which person acquires British citizenship on which date" } ],
  "examples": [ { "name": "alice" }, { "name": "harry" } ],
  "included_resources": [ { "resource": "...", "start": 0, "end": 0, "rules": 3, "templates": 2 } ],
  "fact_images": [ { "start": 0, "end": 0, "url": "..." } ],
  "template_images": [ { "literal": "...", "url": "..." } ],
  "views": [ ... ],
  "citations": [ ... ],
  "issues": [ { "severity": "error|warning|…", "type": "...", "message": "...", "fix": "...", "start": 0, "end": 0 } ]
}
```

- `kb` is the name of the program, or null when the program has no name. `language`
  is `le` or `prolog`. `target` is the target language that the program declares,
  for example `prolog` or `lps`.
- `examples` are the scenarios of the program.
- `template_defs` gives the templates with their placeholders. Each template tells
  if it is a scenario element and if it is judged. Each placeholder contains the
  values that the rules read in that position. The Scenario Editor gives these values
  as choices.
- `views` contains the LE views of the program, already compiled
  ([language.md §17.10](../reference/language.md)). `citations` contains the
  locations where the program cites a document that `provenanceAt` can show.
- `issues` contains the problems and the possible problems that the verifier found in
  the program ([warnings](../guide/warnings.md)). The verifier is the part of the
  system that checks a program for mistakes.

If a program does not load, the reply is the `500` reply that the section "Errors"
describes. The reply is the same for an example that the caller cannot open.

### `documentText` — The text of a cited document

**Request**: `address`, which is a web address or a path relative to the folder of
the program. Also `source` or `base`, as for `load`.

**Reply**: `{ "text": "...", "address": "..." }`, or `{ "error": "<reason>" }`. The
reason is `"no such document file"` when the file does not exist. Alternatively, the
reason is a message about a document that the licences of the caller do not include.

### `originals` — The original files a program was converted from

**Request**: `source`, the example name with which you opened the program, or
`base`.

**Reply**: `{ "files": [ "sources/…", ... ] }` gives the text files in the `sources/`
folder next to the program, with a maximum of 500 files. The reply does not include
files that are not text. Read each file with `documentText`. If a program has no such
files, the reply is `{ "files": [] }`.

---

## Answering queries

### `answeringQuery` — Answer a query in a session

The query panel of the editor uses this operation. The request must contain a
`sessionModule` from `load`.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | from `load` |
| `query` | string | the name of a query of the program (for example `"one"`) |
| `customQuery` | string or null | instead of `query`: a question in LE, the part after `query … is:`. The server reads the question against the templates of the program |
| `scenario` | string | a scenario name; `""` for no scenario. The server reads a string that contains `(` as a Prolog fact or a list of Prolog facts |
| `customScenario` | string or null | instead of `scenario`: facts in LE. The server reads the facts against the templates of the program |
| `detailedFailures` | boolean | optional: when the query fails, the explanation contains one node for each rule that the server tried |
| `whyNot` | boolean | optional: for a query with no answer, the reply also contains `unmet` ([language.md §17.10](../reference/language.md), "Why not"); sets `detailedFailures` to true |
| `keep` | list of strings | optional: the template labels whose facts a flip query does not change ([language.md §17.7](../reference/language.md)) |
| `hideRepeated` | boolean | optional, true by default: hide a sub-explanation that the reply already showed (`false` shows each one in full) |
| `largerImportantReasons` | boolean | optional, true by default: when the query fails, the important reason names the three deepest failures, not one |
| `timeLimit` | number | optional: the number of seconds that the query can use, instead of 240 (from 10 to 1800). The **Keep going** button of the editor sends this field |
| `debug` | boolean | optional: run the query under the debugger that is connected to the session through `/dap` |

Each call replaces the facts in the session with the facts of the scenario, or with
the facts that the request gives.

**Reply — the query has answers**

```json
{
  "result": "ok",
  "results": [
    { "answer": "John acquires British citizenship on 2021-10-09",
      "goal": "John acquires British citizenship on 2021-10-09",
      "unknowns": [ "<LE sentence>", ... ],
      "why": [ <explanation node>, ... ],
      "strongestReason": "2021-10-09 is after commencement",
      "strongestReasonPath": "1.2" }
  ],
  "checklist": []
}
```

- The reply contains one result for each different answer. If two answers have the
  same sentence and the same unknowns, the reply gives them one time.
- `goal` is the answer as a sentence that the server can read back as the same
  answer.
- `unknowns` gives, as LE sentences, the goals that the answer assumes. Abduction is
  the name for the assumption of a goal to get an answer. The list is empty when the
  answer assumes nothing.
- `strongestReason` gives a summary of the explanation in one line.
  `strongestReasonPath` tells where its node is in `why`. The count starts at 1:
  `"1.2"` is the second child of the first root.
- `checklist` has a value for a program that uses the reserved sections:
  applicability, question and remedy ([language.md §17](../reference/language.md)).
  The value is then `[{section, status}]` in the sequence of the checklist. All other
  programs get `[]`.

**Reply — no answer**

```json
{
  "result": "ok",
  "results": [],
  "why": [ <failure explanation node>, ... ],
  "strongestReason": "it is not the case that 2021-10-09 is after commencement",
  "strongestReasonPath": "1.1.2",
  "checklist": [],
  "unmet": [ ... ]
}
```

The field `unmet` occurs only when the request asked for `whyNot`. `unmet` is a list
of `{literal, kind, facts, ruleStart, ruleEnd, rule?, provenance?, label?, goal?, values?}`.
`kind` is `not_stated` or `not_met`. `not_stated` is for a fact that the case can
state but does not state. `facts` contains the conditions of the rule that asked, and
that were true. `rule` is the name of that rule. It occurs only when the author of the
rule gave it a name. `provenance` is the provenance of that rule. An item whose `kind`
is `not_stated` also contains the `label` of the template and the `goal` that must be
stated. For each placeholder, it also contains the `values` that the rules read
there.

**Other replies**

- `{ "error": "<parse message>" }` — the server could not read the scenario or the
  query that the request gave.
- `{ "result": "interrupted", "interrupted": true }` — `interruptQuery` stopped the
  query before the query found an answer. If the query found some answers, the reply
  is `{ "result": "ok", "interrupted": true, "incomplete": true, "results": [...] }`.
  This reply gives the answers that the query found before the stop, each as in a
  full reply.
- `{ "result": "timeout", "timedOut": true, "timeLimit": <seconds>, "error": "<message>" }` —
  the query used all its time before it found an answer, and the server stopped it.
  A query has 240 seconds, or the `timeLimit` that the request gives. With
  `debug: true`, a query has 3600 seconds, because that time includes the time while
  the debugger is paused. If the query found answers, the reply is
  `{ "result": "ok", "timedOut": true, "incomplete": true, "timeLimit": <seconds>, "results": [...] }`.
  This reply gives the answers that the query found before the stop. A new request
  with a larger `timeLimit` can possibly find more answers.
- `"explanations": "short"` in a reply with answers tells you this: the explanations
  of the answers do not tell why each condition of the form "it is not the case that
  ..." is true. On a large program, the explanations of these conditions are most of
  the work. Thus the query first runs with full explanations for a quarter of its
  time, with a maximum of 20 seconds. If that time is not sufficient, the query runs
  again without these explanations. The answers from the first run keep their full
  explanations. Later runs of the same query on the same program start without these
  explanations immediately. All other operations can run for 300 seconds. After that
  time, the request fails with the status 500.
- `{ "results": [], "error": "Explanation failed", "result": "ok" }` — the query has
  no answer, and the server could not explain why.
- A reply can also contain `valueWarnings`. This field gives the values in the
  supplied facts that no rule can read in their position. Each item is
  `{fact, value, kind, message, fix}`.
- `{ "error": "Session expired", "session_expired": true }`.

### `interruptQuery` — Interrupt a running query

**Request**: `sessionModule`.

**Reply**: `{ "result": "ok", "interrupted": true }` when an `answeringQuery` ran in
that session. The stopped `answeringQuery` then replies `interrupted` to its own
caller. If no query ran, the reply is
`{ "result": "ok", "interrupted": false, "message": "No running query" }`.

### `openQuestions` — What a case does not state

This operation gives the facts that a case must have before the server can answer a
query. A screen that asks the user for these facts uses this operation. In the views,
the sentence for this operation is "the result asks what is missing".

**Request**: `sessionModule`, `query` or `customQuery`, and `scenario` or
`customScenario`, all as for `answeringQuery`.

**Reply**

```json
{ "holds": false,
  "missing": [ { "literal": "...", "label": "*a date* is after commencement",
                 "goal": "2021-10-09 is after commencement", "values": [[]] } ],
  "touched": [ ... ] }
```

`holds` tells if the query has an answer. `missing` gives the case facts that caused
the failure of the nearest attempts, because they were not there. If you state one of
these facts, you can possibly get a result. `touched` gives all the case facts that
the attempt looked for and did not find. A case fact is a fact of a template with the
mark "scenario element" or the mark "judged". Some programs do not mark any template
in these two ways. In such a program, a case fact is a fact of a template that no
rule concludes. The errors are `{ "error": "No KB loaded" }`, a message that tells
what the server could not read, and `{ "error": "Could not set up the query" }`.

### `answer` — Load a document and explain its first answer

This operation keeps nothing between calls. The server loads the document into a
separate session, and sets the named scenario. Then it runs the query, and deletes
the session.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `document` | string | the text of the program |
| `theQuery` | string | a query name, for example `"one"` |
| `scenario` | string | a scenario name, for example `"alice"` |
| `source`, `base` | string | optional, [refer to the section above](#programs-sent-as-text-le-source-base) |
| `hideRepeated` | boolean | optional, as for `answeringQuery` |

**Reply**: `{ "answer": [ <explanation node>, ... ] }`, or
`{ "answer": "No answer found" }`. If the program does not know the scenario name,
the reply is `{ "error": "Scenario not found" }`.

### `explain` — Load a document and explain every answer

This operation is the same as `answer`, but it explains each different answer, not
only the first answer.

**Request**: the fields of `answer`.

**Reply**: `{ "results": [ [ <explanation node>, ... ], ... ] }`, with one
explanation for each different answer. If the program does not know the scenario
name, the reply is `{ "error": "Scenario not found" }`.

### `query` — Run a Prolog goal

This operation is near to the internal mechanism. The server runs a goal in Prolog
against one module. A module is one named set of loaded rules.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `theQuery` | string | a Prolog goal, for example `"acquires_British_citizenship_on(P, D)"` |
| `module` | string | a session module, or the module of a loaded knowledge base. For a knowledge base, the server makes a separate session |
| `facts` | list of strings | optional: facts in Prolog, which the server adds before the goal runs |
| `hideRepeated` | boolean | optional |

**Reply**

```json
{ "results": [ { "result": "true",
                 "bindings": { "P": "John", "D": "2021-10-09" },
                 "unknowns": [ ... ],
                 "why": [ <explanation node>, ... ] } ] }
```

If a goal has no solution, the reply is `{ "results": [ { "result": "false" } ] }`.
Facts that you add to a session module stay in that session after the call.

### `loadFactsAndQuery` — Add Prolog facts to a session and run a goal

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | from `load` |
| `facts` | list of strings | facts in Prolog, for example `"is_born_in_on(bob, 'the UK', '2021-10-09')"`. The server adds them to the session |
| `goal` | string | optional: a goal in Prolog, to run after the server adds the facts |
| `hideRepeated` | boolean | optional |

**Reply**

- A request without `goal` gets `{ "facts": [ ... ], "result": "ok" }`.
- A request with a `goal` that has solutions gets `{ "facts": [ ... ], "goal": "...", "answers": [ { "bindings": { "X": ... }, "explanation": ... } ], "result": "true" }`.
- A request with a `goal` that has no solution gets `{ "result": "false" }`.

### `scaspQuery` — Answer a query with s(CASP)

The server answers the query with the s(CASP) engine, not with its own reasoner
([s(CASP) reference](../reference/scasp.md)). The reasoner is the part of the system
that finds the answers.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | from `load` |
| `query` or `customQuery` | string | a query name, or a question in LE |
| `scenario` | string | optional: a scenario name |
| `timeLimit` | number | optional: the number of seconds that the query can run, 10 by default |
| `le` | string | optional: the text of the program. With this text, a refusal can name the lines that cause it |

**Reply**

```json
{ "result": "ok", "engine": "scasp", "modelCount": 2, "issues": [ ... ],
  "results": [ { "answer": "...", "why": <node>, "bindings": { "X": "..." },
                 "unknowns": [ ... ], "assumptions": [ ... ],
                 "symbolic": false, "constraints": [],
                 "modelIndex": 1, "modelCount": 2 } ] }
```

The reply contains one result for each different possible world. A possible world is
one answer together with one set of assumptions. Some answers are about any thing
that agrees with conditions, not about one specific thing. Such an answer has the
mark `symbolic`. Its `constraints` tell in LE words the conditions that the thing
must agree with. Each item of `issues` is `{kind, ruleId, message}`. Some programs
contain a construct that s(CASP) cannot state correctly. The server refuses such a
program, exactly as `getScasp` refuses it. The other errors are
`{ "error": "No KB loaded" }`, a message that the engine is not installed, and
`{ "error": "Unknown query for the s(CASP) engine" }`.

---

## Explanations and the Proof Game

### `explanationDrill` — The Explanation Drill

This operation controls the "suspects tree" drill on an explanation. The drill
selects the node that best divides the part of the tree that is still in question.
Then it asks the reader if the reader understands that node.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | a session. The drill records its progress in the session |
| `why` | explanation | the explanation tree, on the first call; later calls can omit it |
| `answers` | list | the replies of the reader until now, in sequence: `"yes"` when the reader understands the node, `"not_yet"` to go down into the node |

**Reply**

```json
{ "ok": true, "initialCount": 17, "progress": 5, "topPath": "1.2",
  "questions": [ { "path": "1.2", "text": "...", "start": 0, "end": 0, "answer": "not_yet" } ],
  "pending": { "path": "1.2.1", "text": "...", "start": 0, "end": 0 } }
```

`pending` is the next question. It is null when the drill is complete.
`initialCount` is the number of nodes in the full tree. `progress` is the number of
nodes in the part that the reader understands. The errors are
`{ "error": "No explanation to drill" }` and the reply for an expired session.

### `getGameData` — Cards for the Proof Game

**Request**: `sessionModule`, `query` or `customQuery`, and `scenario` or
`customScenario`, all as for `answeringQuery`. The request can also contain
`hideRepeated` and `answerIndex`. `answerIndex` selects the answer that the game
proves. The count of the answers starts at 0.

**Reply**

```json
{ "result": "ok",
  "gameData": { "rules": [ ... ], "facts": [ ... ], "query": "<LE text>",
                "queryTokens": [ ... ], "sessionModule": "...",
                "queryConditions": [ ... ], "queryConditionTokens": [ ... ],
                "queryRanges": [ ... ], "queryNaf": [ ... ], "queryForall": [ ... ],
                "queryTypeCheck": [ ... ],
                "explanation": <explanation of the chosen answer, or of the failure>,
                "answers": [ "<answer label>", ... ], "answerIndex": 0,
                "failed": false } }
```

`le_proof_game.pl` makes the rule cards and the fact cards for the Proof Game window
([the Proof Game](../guide/proof-game.md)). It gives the cards the shape that this
window needs. `answers` contains a maximum of 25 answers. If an answer is true only
because of assumptions, its label gives these assumptions. The game plays a query
with no answer as a failure. Then `answers` is empty, and `failed` is `true`.
`explanation` contains the failure explanation of the query. This explanation is the
spine of the failure that the board makes. If the server cannot make the game, the
reply is `{ "error": "...", "gameDataError": true }`.

### `unifyGameNodes` — Check a Proof Game board

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | the session of the game, as `getGameData` left it |
| `nodes` | list | one `{instanceId, templateId}` for each card on the board; a FAIL card has the `templateId` `"fail"` |
| `edges` | list | `{child, parent, bodyIndex, subIndex?}`: the child card satisfies the condition number `bodyIndex` of the parent. The count starts at 0. `subIndex` selects one part of a "for all cases" condition |

**Reply**: `{ "result": "ok", "status": "ok", "nodes": [ {instanceId, head, headTokens, body, bodyTokens, bodyForall, bodyNafInner, bodyHolds}, ... ] }`
— the cards, each with the values that the connections make necessary. `status` is
`"clash"` when the connections cannot agree. `status` is `"error"`, with a message
in `error`, when a card is unknown.

---

## Inspecting a loaded program

All the operations in this section work at one location in the program. Each one
takes `position`. `position` counts characters from the start of the text of the
program. Each one also takes two optional fields: `line` and `lineStart`. `line` is
the text of the line where the cursor is. `lineStart` is the position where that
line starts. With these two fields, the server can find the difference between the
head of a rule (its conclusion) and the conditions of the rule.

### `getProlog` — The Prolog clause at a position

**Request**: `sessionModule`, `position`.

**Reply**: `{ "prolog": "<clause, as portray_clause/1 writes it>" }`. The errors are
`{ "error": "No term found at this position" }` and `{ "error": "No KB loaded" }`.

### `predicateAt` — The predicate at a position

The "Show definition" and "Fold/Unfold all rules" functions of the editor use this
operation.

**Request**: `sessionModule`, `position`, `line`, `lineStart`.

**Reply**

```json
{ "le": "*person* acquires British citizenship on *date*",
  "functor": "acquires_British_citizenship_on", "arity": 2,
  "template": { "start": 180, "end": 231 },
  "rules": [ { "start": 611, "end": 954 } ] }
```

`template` is not in the reply when the program declares no template for the
predicate. The errors are `{ "error": "No predicate at this position" }` and
`{ "error": "No KB loaded" }`.

### `predicateOccurrences` — Every mention of the predicate at a position

The "Show occurrences" function uses this operation.

**Request**: the fields of `predicateAt`.

**Reply**: `{ le, functor, arity, occurrences: [ {start, end, kind, context, text}, ... ] }`,
in the sequence of the mentions in the text. `kind` tells the type of the mention:
`template`, `fact`, `head`, `condition`, `scenario` or `query`. `context` is the name
of the scenario or query that contains the mention, or `""`. `text` is the sentence
at that location, in LE. The `start` and `end` of a rule include the full rule. Thus
`text` tells the reader which line to look at. The errors are the same as for
`predicateAt`.

### `provenanceAt` — The document cited at a position

This operation gives the citation at one location in the program. The View Original
Text function of the editor now uses `originalTextAt` instead. `originalTextAt` does
the same work and more.

**Request**: `sessionModule`, `position`, `line`, `lineStart`.

**Reply**

```json
{ "provenance": { "source": "...", "document": "...", "locator": "...", "quote": "...",
                  "rationale": "...", "url": "...", "text": "..." },
  "rule": "<rule label>" }
```

`rule` is null, unless the citation is part of a rule with a name from its author.
Each field that the program does not give is null. The errors are
`{ "error": "No cited document at this position" }` and
`{ "error": "No KB loaded" }`.

### `originalTextAt` — Where the original of a position is

The "View Original Text" function uses this operation.

**Request**: `sessionModule`, `position`, `line`, `lineStart`, and `source` or
`base`. `source` or `base` tells where the folder of the program is, when the
session does not know.

**Reply**: the `kind` field gives the type of reply. The server tries these types in
this sequence:

- `"citation"`: `{ kind, provenance, rule }`, the same fields as `provenanceAt`
  gives. The server gives this reply when it can show the citation at that location.
  Sometimes the citation refers to a text file, and its locator names an identifier,
  as `at MathVariable PremiumTaxMV` does. Then the reply also contains the passage
  that defines that identifier, in `quote` and `at`.
- `"passage"`: `{ kind, construct: {kind, name}, rule, via, provenance }`. The server
  found the construct at the cursor in the files from which the program was written.
  The construct is a `rule`, `fact`, `table`, `template`, `scenario` or `query`.
  `provenance.text` names the file (`"sources/…"`), and `document` gives its name.
  `locator` is the identifier that the server found. `quote` is the passage itself.
  `at` is the `[start, end]` of that passage in the readable text of the file, which
  `documentText` gives. `quote` and `at` are null when the original of the construct
  is the full file, not one passage. `via` tells which link found the passage:
  `label`, `ledger` or `citation`.
- `"originals"`: `{ kind, construct, files: [{document, text}], hinted }`. The server
  found no passage. `hinted` gives the files that the ledger names for the construct.
- `"none"`: `{ kind, construct }`. The program keeps no original text.

The error is `{ "error": "No KB loaded" }`.

### `is_a_hierarchy` — The type hierarchy

**Request**: `sessionModule`.

**Reply**: `{ "hierarchy": [ { "type": "...", "range": { "start": 0, "end": 0 } | null, "children": [ ... ] }, ... ] }`
— the types that the `is a` facts and rules of the program name, as one or more
trees. Each type contains the `start` and `end` of the statement that makes it a
subtype of a different type. If a program states no such fact or rule, the reply is
`{ "hierarchy": [] }`. If the session does not exist, the reply is
`{ "error": "No KB loaded" }`.

### `graph` — The program as a graph

**Request**: `sessionModule`.

**Reply**: `{ "nodes": [ { "data": {...} } ], "edges": [ { "data": {...} } ] }` — the
nodes and the edges between them, in the format of the elements of the drawing
library Cytoscape. The `data` of a node contains `id`, `type` (`template`, `rule`,
`fact`, `scenario` or `query`), `label` and `source: {start, end}`. A template also
contains `functor` and `arity`. A fact in a scenario also contains `parent`. The
`data` of an edge contains `id`, `source`, `target` and `type` (`uses`, `scopes`, …).
Refer to [docs/dev/graph.md](../../dev/graph.md). If the session does not exist, the
reply is `{ "error": "No KB loaded" }`.

### `testReport` — Run the program's tests

The server runs all the `<query> expects answers [...]` tests in the scenarios of the
program.

**Request**: `le`, with `source` or `base`.

**Reply**

```json
{ "passed": 4, "failed": 0, "errors": 0,
  "tests": [ { "scenario": "alice", "query": "one", "status": "pass|fail|error",
               "expected": [], "actual": [], "unknowns": [], "expectedUnknowns": [],
               "message": "" } ] }
```

A test that fails fills in `expected`, `actual` and the unknowns. A test that cannot
complete fills in `message`. If a program does not load, the reply is
`{ "error": "The program could not be loaded" }`.

---

## Views

Refer to [LE Views](../tutorials/views.md) and
[language.md §17.10](../reference/language.md). A view is the description of a screen
for one kind of decision.

### `automaticView` — The automatic view

This operation gives the view that the server makes from the program itself, for a
program that does not declare a view. The executive page uses this operation.

**Request**: `sessionModule`, and optionally `name`, the file name of the program.
This name becomes the name of the view when the program itself has no name.

**Reply**: `{ "view": { ... } }` — the compiled view, in the same shape as the
`views` field of the reply of `load`. If the server cannot make a view from the
program, the reply is `{ "error": "No view could be drawn from this program" }`.

### `draftView` — Draft a view section

The "Generate LE view" function of the LE Assistant uses this operation. The server
writes a first view section for the program, as LE text. The author can add this
text at the end of the program.

**Request**: `sessionModule`, and optionally `name`, the name of the program.

**Reply**: `{ "view": "the view … is:\n    …" }`, or `{ "error": "No KB loaded" }`.

### `legalView` — The legal view of an LPS program

This operation gives a view of a program in LE for LPS that a lawyer can read. The
view tells who can do what, when, and with what effect. The server writes this view
as a usual LE program.

**Request**: `le`, with `source` or `base`.

**Reply**: `{ "document": "<LE text>", "name": "<program name>", "issues": [ {severity, code, message} ] }`.
In these three conditions, the reply is `{ "error": "<message>" }`: the program does
not declare `the target language is: lps`, the program does not load, or the server
cannot make a view from it.

---

## Other targets, import and export

### `getScasp` — The program as s(CASP)

**Request**: `sessionModule`, and optionally `le`, the text of the program. With
this text, a refusal can name the lines that cause it.

**Reply**: `{ "scasp": "<s(CASP) program>", "issues": [ {kind, ruleId, message} ] }`.

Some programs use a construct that s(CASP) cannot state correctly. The server
refuses such a program with
`{ "error": "<one sentence>", "exporter": "s(CASP)", "problems": [ {line, message, text} ], "issues": [...] }`.
The other errors are `{ "error": "No KB loaded" }`, and a message that tells that the
s(CASP) engine is not installed on the server.

### `getLps` — The program as LPS

This operation translates Logical English into LPS (in LPS2:
`docs/dev/le-lps-interface.md` §3.1).

**Request**: `le`, with `source` or `base`, or alternatively `sessionModule`. A
request with `le` gets provenance with line numbers and column numbers. A request
with only `sessionModule` gets empty provenance.

**Reply**: `{ "lps": "<LPS text>", "provenance": [ {index, line, col, kind} ], "issues": [ {severity, type, message, line, col} ] }`,
or `{ "error": "getLps needs either the document text (le) or a loaded sessionModule" }`.

### `importFormats` — The importers

**Request**: no fields.

**Reply**: `{ "formats": [ { "id": "miniscript", "title": "...", "extensions": [ "ms", ... ] }, ... ] }`
— the translators that File ▸ Open gives (`le_import.pl`).

### `importForeign` — Translate another system's file

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | the name of the file; the extension of the name selects the translator |
| `text` | string | the content of the file, when the file is text |
| `base64` | string | instead of `text`: the content in base64. Base64 is a method to write any file as plain letters and digits. Use it for an archive, or for any file that is not text |
| `importer` | string | optional: the `id` of a translator. The server then uses that translator, whatever the name of the file is |

**Reply**: `{ "document": "<LE text>", "fileName": "<stem>.le", "source": "imported/<id>/<stem>", "importer": "<title>|null", "notes": [ ... ], "files": [ ... ] }`
— open the new program with the name in `source`. Then the server can find the files
that the program includes. The reply is `{ "error": "..." }` when the file is too
large, or when the server could read nothing from it.

### `exportFormats` — The exporters that apply

**Request**: `le`, with `source` or `base`.

**Reply**: `{ "formats": [ { "id": "legalruleml", "title": "...", "extension": "lrml" }, ... ] }`
— the exporters that can write this program. The list is empty when the program does
not load.

### `exportForeign` — Write the program for another system

**Request**: `le`, with `source` or `base`, and `exporter`. `exporter` is one of the
`id` values from `exportFormats`.

**Reply**: `{ "document": "...", "fileName": "...", "exporter": "<title>", "notes": [ ... ], "links": [ {title, url} ] }`.
The exporter refuses a program that it cannot translate correctly, with
`{ "error": "...", "exporter": "...", "problems": [ {line, message, text} ] }`.
In this reply, `line` is null when the exporter cannot tell which line causes the
problem. If a program does not load, the reply is
`{ "error": "The program could not be loaded" }`.

---

## LLM features

The operations in this section use an LLM (a large language model). Each operation
takes the short name of the model, which `list_models` gives. Each operation can also
take an `api_keys` object. In that object, each provider has the key to use with it.
The providers are `openai`, `anthropic`, `groq`, `together`, and `google` for
Gemini. If the request gives no key for a provider, the server uses its own start-up
key, if it has one.

### `list_models` — The LLM models

**Request**: no fields.

**Reply**: `{ "models": [ { "short": "gpt-4o", "provider": "openai", "api_model": "gpt-4o" }, ... ], "server_keys": [ "openai", ... ] }`
— `server_keys` gives the providers for which the server itself has a key.

### `nl_to_le` — Write it in English

The server asks the LLM one time. The server replies only after the LLM replies. The
LLM changes English into LE facts, or into the body of a query, with the templates of
the program. The server then checks the result against the program (`nl_to_le.pl`).

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sentence` | string | the English text |
| `kind` | string | `"facts"` (default) or `"query"` |
| `templates` | list of strings | the template labels, with their `*…*` placeholders, that the new text can use |
| `content` | string | the program. The server checks the new text against it |
| `model` | string | optional, `"openai/gpt-oss-120b"` by default |
| `api_keys` | object | optional |
| `document` | string | optional: the name of the document that the facts come from. Each new fact then cites that document |
| `address` | string | optional, together with `document`: the location of the text of the document |
| `source`, `base` | string | optional: the location of the program. With it, the server can find the templates that the program includes |

**Reply**: `{ "result": "ok", "le": "<LE text>", "warnings": [ "[warning] line 2: …", ... ], "document_facts": [ ... ] }`.
`warnings` gives the issues that the new text adds to the program, the most important
first. It gives a maximum of six issues, followed by "… and N more".
`document_facts` contains the statements that tell the program where `document` is.
It is empty when the request gives no `address`. If the conversion fails, the reply
is `{ "result": "error", "error": "<message>" }`.

### `assistant_command` — Start an LE Assistant job

The server starts the LE Assistant on the program
([docs/dev/assistant.md](../../dev/assistant.md)). The job then runs independently.
The client sends `assistant_status` at intervals to get the progress of the job.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `command` | string | the request of the user |
| `content` | string | the current text of the program |
| `mode` | string | `"light"` or `"deep"`. `"light"` is an agent that runs in the server itself (`le_assistant_light.pl`). `"deep"` (the default when the request gives no mode) is an `opencode` agent that works in a separate folder |
| `model` | string | the short name of a model |
| `api_keys` | object | optional |
| `max_steps` | number | light mode: the number of steps that the agent can do, 10 by default |
| `session_id` | string | deep mode: the conversation to continue, as a previous `assistant_status` gave it |

**Reply**: `{ "result": "ok", "job_id": "job_7" }`.

### `assistant_status` — Poll an LE Assistant job

**Request**: `job_id`.

**Reply while running**: `{ "result": "ok", "status": "running", "stdout": "...", "stderr": "..." }`
— the text that the job wrote until now, while it continues.

**Reply when finished**

```json
{ "result": "ok", "status": "finished", "exit_status": "exit(0)",
  "stdout": "<the assistant's answer>", "stderr": "...",
  "new_content": "<the program after the job>", "session_id": "<conversation id>" }
```

If the server does not know the job, the reply is
`{ "result": "error", "error": "Job not found" }`.

### `assistant_interrupt` — Interrupt an LE Assistant job

**Request**: `job_id`.

**Reply**: `{ "result": "ok", "message": "Job interrupted" }`, or the same reply with
the message `"Job already finished"`. If the server does not know the job, the reply
is `{ "result": "error", "error": "Job not found" }`.

### `contract_start` — Start a Contract Assistant job

The Contract Assistant changes the materials that it receives into a tested LE
program. The work occurs in a job that runs independently. The module
`le_contract_assistant.pl` of the licensed Logical English Translators does this
work. The pages for the user are at `/web_extras/contract_assistant/`. A server
without this module replies to each `contract_…` operation with
`{ "error": "<it is not installed here>", "not_installed": true }`. The server keeps
the files of a job in `contract_jobs/<job>/`, or in the folder that
`$LE_CONTRACT_JOBS_DIR` names. These files stay on the disk. Thus, after a restart,
the server can still report the state of a job and give its result.

The five `contract_…` operations are part of the Logical English Translators licence
(the capability `contract_assistant`; [signing in](../guide/accounts.md)). If the
sign-in of a request does not have this licence, the reply is
`{ "error": "<why, and how to obtain it>", "unlicensed": true }`. A server that
started with `NO_RESTRICTIONS=true` replies to all callers.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `mode` | string | `"contract"`, `"scenario"`, `"query"` or `"residue"`. `"contract"` is the default when the request gives no mode: materials in, a full program out. `"scenario"` and `"query"` make one new block for a program that already exists |
| `wording` | upload | the wording of the contract; a request in `contract` mode must contain it, or `wording_url` |
| `wording_url` | string | instead of `wording`: the web address of the wording (a PDF, a web page, a Word file or a text file). The server gets the wording and converts it. The program cites it as the location where the wording is published |
| `schedule`, `cases` | upload or list of uploads | optional, in `contract` mode |
| `existing_code` | string | optional: LE that the program must include |
| `program` | string | in `scenario` and `query` modes: the program for the new block. If the request gives no program, the server uses `existing_code` |
| `text` | string or upload | in `scenario` and `query` modes: the English to convert. In `residue` mode: optional background |
| `name` | string | optional: the name of the new block |
| `instructions` | string | optional: more instructions for the assistant, in free text |
| `model`, `judge_model` | string | `"claude-sonnet"` by default. The judge uses the same model as the work, unless the request gives a model for the judge |
| `branch_models` | list of strings | optional, in `contract` mode: the models that write and repair the competing drafts ("branches"), in turn. For example, with `["gpt-5.6-sol", "Qwen/Qwen3.8-2.4T-A95B"]`, the first model does branches 1 and 3, and the second model does branch 2. The tests give a rank to all the branches together |
| `api_keys` | object | optional |
| `target` | string | optional |
| `budget` | object | `{preset, k?, w?, repairs?, minutes?}`, where `preset` is `"draft"`, `"standard"` or `"thorough"`; `draft` by default |
| `features` | object | optional: settings to change one at a time — `probes`, `interrogation_repair`, `holdout`, `paraphrase`, `clausewise`, `diff_repairs`, `max_rewrite_errors`, `polish` |
| `max_tokens` | number | optional; the server calculates a value when the request gives none |
| `reasoning` | string | `"default"` or `"minimal"` |

An upload is `{ "name": "wording.md", "text": "..." }` for a text file, or
`{ "name": "wording.pdf", "data": "<base64>" }` for all other files.

**Reply**: `{ "job": "caj_<uuid>" }`, or `{ "error": "<message>" }`.

### `contract_status` — Poll a Contract Assistant job

**Request**: `job`, and optionally `since`. `since` is the number of the first log
line that you want. It is the `next_seq` of the previous reply.

**Reply**

```json
{ "status": "running|interrupted|finished|error", "stage": 3, "stage_label": "...",
  "branches": [ { "branch": 1, "model": "<when branch_models is set>", ... } ], "log": [ "...", ... ], "next_seq": 42,
  "config": { "mode": "contract", "model": "...", ... }, "elapsed": 120.5,
  "error": "<when status is error>" }
```

If a job does not run and is not on the disk, the reply is
`{ "error": "Unknown job" }`.

### `contract_result` — The result of a Contract Assistant job

**Request**: `job`.

**Reply**: `{ "le": "<program>", "filename": "contract.le", "mode": "...", "winner": 1, "scores": [ ... ], "final_score": ..., "ledger": "<markdown>", "interrogation": {...}, "paraphrase": {...}, "existing_code": {...} }`
The reply also contains `recovered: true` when the server read the result from the
disk after a restart. The errors are `{ "error": "Job has no result (yet)" }` and
`{ "error": "Unknown job" }`.

### `contract_interrupt` — Stop a Contract Assistant job

**Request**: `job`.

**Reply**: `{ "ok": true }`. The job stops the next time that it checks if it must
stop. If the job does not run, the reply is
`{ "ok": false, "error": "Job is not running" }`.

### `contract_cost_estimate` — Price a Contract Assistant job

**Request**: the settings of `contract_start` (`mode`, `model`, `judge_model`,
`budget` and `features`), and `input_chars`. `input_chars` is the size of the
selected materials.

**Reply**

```json
{ "calls": 13, "input_tokens_per_call": 32117, "output_tokens_per_call": 5000,
  "priced": true, "cost_usd": 4.12, "currency": "USD", "note": "" }
```

`priced` is false and `cost_usd` is null when the model has no price in the table.
They are also false and null when the table of prices did not load. `note` tells
which of the two occurred.

---

## Explanation tree nodes

The fields `why`, `answer` and `explanation` each contain a list of nodes. A node has
this shape:

```json
{
  "type": "success | failure | unknown",
  "literal": "<LE sentence>",
  "start": 611,
  "end": 954,
  "children": [ <node>, ... ]
}
```

`start` and `end` count characters in the text of the program. They are not in the
node when the node comes from no location in the program. A node can also contain
these fields:

| Field | On | Meaning |
|---|---|---|
| `naf` | success | the literal is a negation (`it is not the case that …`) |
| `ruleAttempt`, `met`, `conditions` | failure | with `detailedFailures`: one rule that the server tried. Of the `conditions` of that rule, the first `met` conditions were true |
| `typeCheck` | failure | a check of the kind of the named thing, not a condition that the program states |
| `repeated`, `repeatedCount` | any | this one node replaces `repeatedCount` sub-explanations that are the same and are next to each other |
| `repeated`, `repeatedOf` | any | the node repeats the sub-explanation at the tree path `repeatedOf`. The full sub-explanation is at that path |
| `provenance`, `rule`, `plain` | any | the fact or rule that proved the node cites a document: its provenance (the fields that `provenanceAt` gives), the name of the rule, and the sentence without the citation |
| `resource`, … | any | the location of the node is in an included file ([refer to the section above](#programs-sent-as-text-le-source-base)) |

A tree path (`strongestReasonPath`, `repeatedOf`, and the `path` of the drill) gives
numbers to the nodes from 1. Thus `"2.1"` is the first child of the second root.

---

## Other HTTP endpoints

| Endpoint | Description |
|---|---|
| `GET /` | the landing page, with the examples, the links, and the test runner (`?run_tests=true`) |
| `GET /editor/` | the Logical English editor |
| `GET /executive` | the executive page: select a program, a scenario and a query, and run it |
| `GET /multilingual` | the language selector; with `?lang=<code>`, a landing page for the examples of that language |
| `GET /docs/user/…` | the user documentation: a path that ends in `.md` gives the file itself, and the same path without `.md` gives the viewer |
| `GET /source/<path>` | the `.le` text of an example. The server gives a path only if two conditions are true. The path must be below one of the folders in the setting `ALLOWED_LE_EXPORTS`. The server gets this setting when it starts. The setting is a list of folders with commas between them, for example `examples/moreExamples`. Also, the roles of the caller must permit access |
| `GET /build_info` | `{ "build_info": "<first line of build_info.txt>" }`, or `"unknown build"` |
| `GET,POST /login`, `GET /logout` | sign in and sign out. You can sign in with Google or GitHub (the buttons go to `/auth/google` and `/auth/github`), or with the form fields `email`, `password` and `return`. The cookie `lc_session` records who signed in. The LPS server of the same domain uses the same cookie |
| `GET /whoami` | `{ "loggedIn": true, "email": "…", "provider": "google", "licenses": [{ "id", "title", "expires" }], "capabilities": [ … ] }` or `{ "loggedIn": false, "email": null, "licenses": [], "capabilities": [] }` |
| `WS /dap` | the permanent connection on which the debugger uses the Debug Adapter Protocol ([docs/dev/debugger.md](../../dev/debugger.md)) |
| `POST /mcp` | the address that uses the Model Context Protocol ([mcp.md](mcp.md)) |
| `GET /list_examples`, `POST /query`, `POST /verify`, `POST /example_details` | the same four MCP tools as plain web addresses ([mcp.md](mcp.md#rest-endpoints)) |
| `GET /telemetry.js`, `GET /telemetry_test` | the script that reports how people use the pages, and a page that checks that the script operates ([docs/dev/telemetry.md](../../dev/telemetry.md)) |
| `POST /test_services/<name>` | replacements for external services. They always give the same answer, so that tests can use them (`le_services.pl`) |
| `/web_extras/…` | the other web applications: the Contract Assistant, the executive page and the documentation viewer |

---

## Starting the server

Run this command from the root of the repository:

```bash
swipl -g "use_module(classic_web_api), start_api_server(3050)" -t "repeat, sleep(1000), fail"
```

If you call `start_api_server/0` without a number, the server uses port 3050. The
server does its work in separate threads. Thus the goal after `-t` only prevents the
program from stopping. The `Dockerfile` does the same. In an interactive `swipl`
session, `?- start_api_server(3050).` is sufficient. The server does not start if a
different program already uses the port.

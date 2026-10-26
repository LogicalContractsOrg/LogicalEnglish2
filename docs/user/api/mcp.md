# Logical English over MCP

*Kind: reference · Audience: developers · Status: current (2026-10-21: limits and keys)*

The LE (Logical English) server speaks MCP, the
[Model Context Protocol](https://modelcontextprotocol.io). MCP is a common language
in which one program asks a different program for information for an LLM (large
language model). The Prolog file `llm/mcp.pl` contains the part of that conversation
that the LE server does. A program that drives a large language model can use MCP.
Examples are Claude Desktop, Claude Code and opencode. Such a program can do these
jobs:

- list the example programs,
- read the templates and queries of one program,
- run queries,
- check programs for mistakes.

The server also gives the same four jobs without the Model Context Protocol, each at
its own web address. These addresses are for clients that do not speak the protocol.
A ChatGPT action is one such client. The deep mode of the LE Assistant talks to this
server itself. For all the other things that the server can do, refer to
[web-api.md](web-api.md).

## Table of Contents
- [Transports](#transports)
- [Client setup](#client-setup)
  - [Claude Desktop](#claude-desktop)
  - [Claude Code](#claude-code)
  - [opencode (the LE Assistant)](#opencode-the-le-assistant)
  - [ChatGPT actions](#chatgpt-actions)
- [Tools](#tools)
  - [The tools of the Contract Assistant](#the-tools-of-the-contract-assistant)
- [Resources](#resources)
- [Prompts](#prompts)
- [REST endpoints](#rest-endpoints)
- [Limits and keys](#limits-and-keys)
  - [The limits](#the-limits)
  - [When the server refuses a call](#when-the-server-refuses-a-call)
  - [Keys](#keys)
  - [The settings of a server](#the-settings-of-a-server)
- [Protocol details](#protocol-details)

## Transports

- **HTTP**: HTTP is the protocol of the web. Send each message over HTTP to
  `POST /mcp` on the LE server. The server listens on port 3050, if it was not
  started on a different port. One request contains one message, written in
  JSON-RPC 2.0. JSON-RPC 2.0 is a simple way to name what you want and to give the
  arguments for it in JSON. JSON (JavaScript Object Notation) is a text format for
  data. The server answers each request with one JSON reply. The server never opens
  its own channel to send messages to the client. Thus the server refuses a
  `GET /mcp` with status `405`. Start the server as
  [web-api.md](web-api.md#starting-the-server) describes.
- **STDIO**: run the server as a program that reads JSON-RPC messages, one message
  on each line, from its standard input. The program writes each reply to its
  standard output:

  ```bash
  swipl -g "use_module(llm/mcp), mcp:handle_mcp_stdio." -t halt llm/mcp.pl
  ```

  Start that program in the top folder of this repository. The top folder is the
  folder that contains the full project. The server reads the examples and the
  documentation through paths that start from that folder. From a different folder,
  the server cannot find the examples or the documentation.

## Client setup

For most clients, one line is sufficient. The guide
[Logical English in your coding assistant](../guide/coding-assistants.md) gives
that line for Claude Code, Codex, Gemini CLI, Visual Studio Code, Cursor and Claude
Desktop. The guide also installs the Logical English skill with the line. The skill
is the set of instructions that tells an assistant how to use these tools. The
folder `llm/settings/` contains an example settings file for each client below.

### Claude Desktop

Add one of two entries to `claude_desktop_config.json`. The first entry starts your
own server on the same computer. This server talks through its standard input and
output. Do these steps:

1. Correct the path to `swipl` for your computer.
2. Make sure that the program starts in the top folder of the repository. For
   example, start the program through a shell that changes to that folder first
   (with `cd`).

```json
{
  "mcpServers": {
    "logical-english": {
      "command": "swipl",
      "args": ["-g", "use_module(llm/mcp), mcp:handle_mcp_stdio.", "-t", "halt", "llm/mcp.pl"]
    }
  }
}
```

The second entry talks to a server that already runs. It uses `mcp-remote`, a small
relay program that sends the messages over the web
(`llm/settings/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "logical-english": {
      "command": "npx",
      "args": ["mcp-remote", "http://localhost:3050/mcp"]
    }
  }
}
```

A third settings file, `llm/settings/claude_desktop_config_remote.json`, connects
the relay to the hosted server, `https://le2.logicalcontracts.com/mcp`.

### Claude Code

Run one of these two lines in the top folder of the repository. The first line
starts a server that talks through standard input and output. The second line
connects to a server that already runs:

```bash
claude mcp add logical-english -- swipl -g "use_module(llm/mcp), mcp:handle_mcp_stdio." -t halt llm/mcp.pl
claude mcp add --transport http logical-english http://localhost:3050/mcp
```

Claude Code can speak to a server over HTTP itself. Thus Claude Code needs no relay.
You add the hosted server in the same way, at `https://le2.logicalcontracts.com/mcp`.

### opencode (the LE Assistant)

The deep mode of the LE Assistant runs `opencode` with settings that it writes from
`llm/settings/opencode_config.json.template`. These settings name one server on the
same computer. The settings reach that server through
`npx mcp-remote http://127.0.0.1:3050/mcp?job=<job id>`. The `job` part of that
address tells the server the job of each checked program. A line `X-LE-Job` in the
request does the same. Thus the assistant can give back the last program that
passed the check. It can do this also when the edits of the agent to the files did
not arrive ([docs/dev/assistant.md](../../dev/assistant.md)).

### ChatGPT actions

Do these steps:

1. Make a Custom GPT.
2. Under Configure, make a new action.
3. Paste `llm/settings/chatgpt_openapi.yaml` into the Schema field. That file
   describes [the four web addresses listed below](#rest-endpoints).
4. Set the server URL to an address of the LE server that the outside world can
   reach. The server URL is the address of the server on the web.

Note: A server that runs on your own computer has no such address until you open a
tunnel to it. Use a tool such as `ngrok` to open a tunnel.

## Tools

A call to `tools/list` gives five tools. A call to `tools/call` runs one of the
five tools. The server sends the result of a tool as one item of content of type
`text`. The text of this item is the JSON reply of the tool, written out. When that
reply contains an `error` field, the server sends the error message instead. Then
the server marks the result `isError: true`.

| Tool | Arguments | Reply |
|---|---|---|
| `list_examples` | `filter` | `{examples: [{name, summary}]}` |
| `get_example_details` | `example_name` (required), `include_program_text` | the program's metadata, and its text when the text is short |
| `query` | `query` (required), `example_name`, `program_text`, `scenario_name`, `facts` | `{results: [{answer, explanation, case?}], notes?}` |
| `verify` | `program_text` (required) | `{issues, test_results}` |
| `search_documentation` | `query` (required): a few keywords | `{sections}`: the sections found, each with its link |

**`list_examples`** lists the programs of `examples/moreExamples/`, of the extra
folders (`regulatory/…`, `migration/…`, …) and of the folders of the other languages
(`pt/…`). Each program has a summary of one line. The list does not contain the
folders that only readers with a licence can open, unless the client sends the key
of a licence holder ([Keys](#keys)). To write a summary, the server loads the program one time. Then the
server keeps the summary for the next list.

The full list is long (more than 150,000 characters). An assistant can refuse a
reply of that size. Give `filter` to get a shorter list: `filter` is one or more
words, and the list then contains only the examples whose name or summary
contains every word. For example, `filter: "nationality"`.

The server gives 20 seconds to the full list. When that time ends, the comment at the
top of each program without a summary describes that program instead.

**`get_example_details`** loads the example that the call names. The names are
written as [web-api.md](web-api.md#example-names-and-access) explains. Then the tool
replies with what the server knows about that program: `kb`, `templates`,
`template_defs`, `queries` (`{name, template, le}`), `scenarios` and `examples`
(`{name}`), `included_resources`, `views`, and the lists of images.

These fields are the same as the fields that
[the `load` operation](web-api.md#load--load-a-program-into-a-new-session) of the web
API sends back, without the session, and with `program_text`. The web API is the
other way for a program to ask this server for something. `program_text` is the text
of the program itself. An example in a folder for licence holders only gives the
answer `{error: "Example '…' requires login"}`, unless the client sends the key of a
licence holder ([Keys](#keys)).

The reply contains `program_text` only when the text has 30,000 characters or
fewer. A longer text is left out, because many assistants refuse a reply of that
size, and then they do not get the templates either. In its place, the reply
contains `program_text_omitted` (the number of characters) and a `note`. The
templates and the queries are sufficient to query the program. To get the text
of a long program, give `include_program_text: true`.

A name without its folder, such as `bna`, gives an error that names the full
name: *Example 'bna' not found; did you mean 'regulatory/bna'?*

**`query`** works in four steps:

1. The tool loads a program into a session that lasts for this one call. The program
   is the example that `example_name` names, or the text in `program_text`.
2. The tool sets the scenario `scenario_name`, if the call gives one.
3. The tool adds the sentences of `facts`. Each sentence is an LE sentence that ends
   with a full stop. The sentences can be on one line or on separate lines. The
   tool ignores a heading line, such as `the knowledge base includes:`. The tool
   reads each sentence against the templates of the program.
4. The tool runs `query`. `query` is the name of a query in the program, or a
   question written in LE that agrees with the templates of the program. A
   question can be two sentences joined by *and*, for example
   `the question is asked on 1990-01-01 and which person is a british citizen on 1990-01-01`.

An example for licence holders only gives the answer `error`, as above. A name that
is not the name of an example gives the answer
`{error: "Example '…' not found; …"}`. When the name is the folder of an example,
the message gives the full name of the example. The name of an example in its own
folder contains the folder and the program, for example
`migration/blawx/rps/rps`.

Each answer comes back as `{answer, explanation}`. The explanation contains the
nodes that [web-api.md](web-api.md#explanation-tree-nodes) describes. When the query
has no answer, the reply is `{results: [], explanation}`, with the explanation of the
failure. If there is no such explanation, the reply is
`{results: [], error: "No answer and no explanation found"}`. When the server cannot
read the facts or the query against the templates, the tool replies `error`.

A fact in `facts` can contain a variable. A variable is a phrase that starts with
*a* or *an*, as in `claim 1 is for a quad cane`. Then the reply also contains
`notes`, with one sentence for each such fact. Such a fact is about all things of its
kind. A caller seldom means this. The answer that follows does not tell why it is
wrong.

A date in `facts` or in `query` that is written in words, such as `3 March 1986`
or `the 1st of January 1990`, also gives a sentence in `notes`. Logical English
reads a date only in the form year-month-day, as in `1986-03-03`. A date in words
is a name, and no rule can compare it with a date.

A case search is a query `which cases make it the case that …` or
`is there a case in which …` ([the language reference](../reference/language.md)
§17.11). **`query`** of a case search, as the name of a query or as text, gives one
result for each case. Each result also contains `case`:
`{index, count, conditions, coveredBy, scenario, notes}`. `coveredBy` lists the
scenarios of the program that meet the case. `scenario` is the text of a scenario
that meets the case, ready to add to the program. An answer that tells that no case exists contains
`case: {none: true, complete}`. `complete` tells whether the search covered all the
cases.

**`search_documentation`** looks for the keywords in this documentation. It replies
with the sections that contain the keywords, each with its link on the server.

**`verify`** loads `program_text` and replies with two lists:

- `issues` contains the problems and the possible problems that the verifier found
  in the program. Each issue is `{severity, type, message, fix, start, end}`.
  [The warnings guide](../guide/warnings.md) explains the issues.
- `test_results` contains the results of the tests written inside the program itself
  (`expects answers` and `expects changes`). Each result is
  `{status: "pass"|"fail"|"error", query, scenario}`. A test that fails also contains
  `expected`, `actual` and the unknowns. A test that stops with an error contains
  `message`.

A server that starts with the flag `mcp:mcp_only_query_verify` lists only two of the
four tools: `query` and `verify`.

### The tools of the Contract Assistant

A server with the Contract Assistant installed gives nine more tools. The tools are
in the list only when the sign-in of the client has the licence of the Logical
English Translators (the capability `contract_assistant`;
[signing in](../guide/accounts.md)). Each tool is one stage of the
[Contract Assistant](../guide/assistants.md#the-contract-assistant). Each tool takes
what it needs (the document, the vocabulary, the program) and gives back its
result. The client keeps the results and gives them to the next tool. Thus an
assistant such as Claude Code can do the stages one at a time, read each result,
and decide the next step.

| Tool | Arguments | Reply |
|---|---|---|
| `ca_ingest` | `document`, `profile`, `hops` | the kind of document, the profile, the questions, the clauses that the assistant found, the index of the limits, the referenced documents |
| `ca_vocabulary` | `document`, `k`, `jury_models` | the vocabulary: the templates of the program |
| `ca_architecture` | `document`, `vocabulary`, `sketch_number` | a plan of the program |
| `ca_draft` | `document`, `vocabulary`, `sketch`, `cases` | a program, verified |
| `ca_check` | `program` | the errors, the warnings, the tests, and the feedback that a repair receives (no model call) |
| `ca_repair` | `document`, `vocabulary`, `program`, `feedback` | the program after one repair, verified |
| `ca_probe_cases` | `document`, `count`, `jury_models` | test cases that two or three models wrote from the document and checked |
| `ca_ledger` | `document`, `program`, `profile` | the ledger of the program, clause by clause, and its coverage figure (no model call) |
| `ca_populate` | `document`, `schema`, `k` | the elements of the schema, with their values as facts that cite the document |

A tool that calls a model can run for some minutes. This is more than the limit of
60 seconds for a call ([The limits](#the-limits)). Use these tools on a server on
your own computer, or on a server with a higher limit.

## Resources

| URI | Content |
|---|---|
| `le://docs/syntax` | `text/markdown`: the Logical English language reference, [docs/user/reference/language.md](../reference/language.md) |

## Prompts

| Prompt | Arguments | What it sets up |
|---|---|---|
| `use_logical_english` | `example_name` | work with one program: read its details, write the facts and question of the user again to agree with its templates, call `query`, explain the result |
| `massage_query` | `user_question`, `templates` | write a question again as one LE query that agrees with the templates |
| `massage_facts` | `user_facts`, `templates` | write facts again as LE facts that agree with the templates, one fact on each line |

## REST endpoints

You can also use the same four tools on the LE server without JSON-RPC. Each tool
has its own web address. Send the arguments of the tool as a JSON object in the body
of the request. The server answers with the JSON reply of the tool. When the tool
itself fails, that reply contains an `error` field, and the status is still `200`.

| Endpoint | Tool |
|---|---|
| `GET /list_examples` | `list_examples` |
| `POST /example_details` | `get_example_details` |
| `POST /query` | `query` |
| `POST /verify` | `verify` |

```bash
curl -s -X POST http://localhost:3050/query -H 'Content-Type: application/json' \
  -d '{"example_name":"citizenship","scenario_name":"alice","query":"one"}'
```

These four addresses do not ask for a token. They have the same limits as the MCP
tools ([Limits and keys](#limits-and-keys)).

## Limits and keys

The public server, `le2.logicalcontracts.com`, answers every client. It is a small
server, and the editor uses it too. Thus the server limits the calls of each
client, so that each client gets a fair share. A server that you start on your own
computer does not limit the calls that come from the same computer.

### The limits

| Client | Calls in a minute | Calls in a day | Longest text in a call |
|---|---|---|---|
| A client without a key | 10 | 200 | 20,000 characters |
| A client with the key of a person | 30 | 2,000 | 200,000 characters |
| A client with the key of an event (for example, a lecture) | 60, for each session | the total of the event | 200,000 characters |
| A client with the key of a licence holder | 300 | 50,000 | 1,000,000 characters |

- `query` and `verify` count as three calls. The other tools count as one call.
- A *session* starts when a client sends `initialize`. The reply gives the session
  identifier in the header `Mcp-Session-Id`, and the client sends it back with each
  call. Without a key, the limit applies to each session. All the sessions from one
  internet address have, together, ten times that limit. Many students in a
  classroom share one address, and each student has a session.
- A text in a call is the value of `program_text`, `facts` or `query`.
- A tool call can run for a maximum of 60 seconds.
- A maximum of four tool calls run at the same time. A call waits for its turn for
  a maximum of five seconds.
- `query` gives a client on a different computer a maximum of 50 answers. A note
  tells how many answers there are.
- The assistants of the editors use the same budget when they use a key of the
  server: a request to an assistant counts as 10 calls, a sentence in Write it in
  English as 3, a contract read by the Contract Assistant as 50. A request with the
  user's own key for the model does not count
  ([the assistants guide](../guide/assistants.md#the-limit-of-the-servers-keys)).

### When the server refuses a call

- **Over MCP**, the reply to the tool call is a normal result, marked
  `isError: true`. Its text tells which limit the call reached, how many seconds
  to wait, and how to get a key. An assistant can read this text and tell you.
- **At the four web addresses**, the status of the reply is `429` (too many calls)
  or `413` (a text that is too long). The header `Retry-After` gives the number of
  seconds to wait, when waiting helps. The status `503` means that the server is
  busy; `504` means that the call ran for too long.

### Keys

A key gives a larger number of calls. To get a key, write to Logical Contracts.
There are three types of key:

- **The key of a person** is valid for one year. If the person has a licence, the
  key gives the licence holder's limits.
- **The key of an event** is for a lecture or a workshop. It is valid only on the
  days of the event, and it gives all the participants together a total number of
  calls.
- **The key of a licence holder** also opens what the licence pays for, for
  example the private example programs. Without a key, an MCP client never has a
  licence.

To use a key, send it in the header `Authorization`:

```bash
claude mcp add --transport http logical-english https://le2.logicalcontracts.com/mcp \
    --header "Authorization: Bearer lc_..."
```

A client that cannot send a header can put the key in the address:
`https://le2.logicalcontracts.com/mcp?key=...`. Do this only with the key of an
event: an address stays in logs and in the history of a browser.

Keep your key secret. A key starts with `lc_`, so you can find one in a file. If a
key becomes public by mistake, tell us, and we withdraw it.

### The settings of a server

These environment variables change the limits of a server that you run yourself:

| Variable | What it changes | Default |
|---|---|---|
| `LE_MCP_THROTTLE` | `off` turns off all the limits | on |
| `LE_MCP_THROTTLE_LOCAL` | `true` also limits the calls from the same computer | false |
| `LE_MCP_RATE`, `LE_MCP_BURST`, `LE_MCP_DAILY` | the calls in a minute, the largest burst, and the calls in a day, for a client without a key | 10, 10, 200 |
| `LE_MCP_CONCURRENT` | the tool calls that can run at the same time | 4 |
| `LE_MCP_TIME_LIMIT` | the seconds that a tool call can run | 60 |
| `LE_MCP_EVENT_KEYS` | simple event keys, without the accounts of the hosted sites: `name:budget:from:until`, separated by commas; the client sends the name as its key | none |
| `LE_MCP_STATE_DIR` | a folder where the server keeps the totals of the event keys when it starts again | none |
| `LE_MCP_CONTACT` | an email address that a refused client can write to for a key | none |

The keys of the hosted sites are made by the accounts of Logical Contracts. A
server without those accounts knows each client only by its address and by
`LE_MCP_EVENT_KEYS`.

## Protocol details

- The server answers an `initialize` message with these items: the protocol
  version `2024-11-05`, the three things that it can give (`tools`, `prompts` and
  `resources`), and its name, `Logical English MCP Server`.
- The server accepts notifications. A notification is a message without an `id`,
  because it expects no answer. Over HTTP, the server still replies
  `{"result": "ok"}` to a notification.
- The server answers a message that names an unknown method with the JSON-RPC error
  `-32601`. Over HTTP, the status is `404`. The server answers a message with no
  `method` with `-32600`, and with the status `400`. The server answers with
  `-32603` when a tool stops with an error.
- A large language model sometimes adds incorrect characters to the end of the name
  of a tool, as in `query<|channel|>…`. The server cuts such a name at the first
  `<`.

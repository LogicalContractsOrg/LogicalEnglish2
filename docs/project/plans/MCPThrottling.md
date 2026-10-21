# Limiting how much one client can ask of the public server

*Kind: plan · Audience: developers · Status: suggestions for later work, 21 October 2026*

## The problem

The public server, `le2.logicalcontracts.com`, answers the tools of the
Model Context Protocol (MCP) at `/mcp`, and the same tools at four plain web
addresses (`/list_examples`, `/example_details`, `/query`, `/verify`), for
anyone, without signing in. That is what makes it useful in a lecture: a
student adds one line to a coding assistant and asks the British Nationality
Act a question. It also means that one client can take the server for itself:

- **One small machine.** The server is one virtual machine on fly.io: one
  processor, 1 GB of memory (`fly.toml`), with 24 worker threads
  (`start_api_server/1` in `classic_web_api.pl`). The editor's users share
  the same machine.
- **No time limit of its own on a tool call.** `query` collects every
  answer (`le_tools:run_query/4`), and `query` and `verify` accept the text
  of any program (`program_text`). Only the web server's default limit for a
  request (SWI-Prolog's `http:time_limit`, 300 seconds) stops a call that
  runs too long. The editor's own queries have their limit
  (`le_api:query_time_limit/2`); the tools do not use it.
- **No count of requests.** Nothing remembers who asked what, or how often.
  A language model in a loop, or a script, can call `query` many times a
  second.
- **Large replies.** Until 21 October 2026 `get_example_details` sent the
  whole text of a program (100,000 characters for `regulatory/bna`), and
  `list_examples` sends 156,000 characters. Large replies cost the server
  time and memory, and a client refuses them (Claude Code takes about 25,000
  tokens from one tool call).

A class makes the problem harder, not easier: the 60 students of a lecture
usually reach the internet through **one address** of their university. A
limit for each address that stops one script also stops the class.

## What a limit must do

1. Keep the editor responsive for its users, whatever the tools receive.
2. Be generous to one person, and to one class, asking questions by hand
   or through an assistant.
3. Refuse with a message that a language model can read and repeat: what
   the limit is, and how many seconds to wait.
4. Need no sign-in for light use.
5. Be cheap: a few hundred lines of Prolog, no new service.

## Suggestions, cheapest first

### 1. A time limit and size limits on every tool call

Run `query` and `verify` under `call_with_time_limit/2` (30 seconds is
generous for the examples; the editor keeps its own 240), and reply
`{error: "The query took more than 30 seconds and was stopped…"}`. Refuse a
`program_text` or `facts` longer than, say, 200,000 characters, and send at
most the first 50 answers of a query, with a note that says how many there
were. These limits alone stop the worst case: one call that holds a worker
for five minutes.

### 2. A limit on the tool calls that run at the same time

Let at most a few tool calls run at once (4 of the 24 workers, say), so
that the editor always has workers left. A message queue holding 4 tokens
does it: a call takes a token (`thread_get_message/3` with `timeout(5)`),
runs, and puts the token back in `setup_call_cleanup/3`. A call that finds
no token within 5 seconds replies that the server is busy and to try again
in 10 seconds.

### 3. A budget for each client: a token bucket

A *token bucket* is a counter for each client that refills at a fixed rate
up to a maximum. Each call spends from it; an empty bucket refuses the call
until it refills. It allows short bursts and stops long floods.

- **Who is the client.** Behind fly.io's proxy, the address of the
  connection is the proxy's. fly.io sends the client's own address in the
  `Fly-Client-IP` header; use that, else the first address of
  `X-Forwarded-For`, else the connection's `peer/1`.
- **The numbers to start from.** A bucket of 30 calls, refilled at one
  call every 2 seconds (30 a minute), and a cap of 2,000 calls a day. Let
  calls cost what they cost: `list_examples`, `get_example_details` and
  `search_documentation` 1, `query` and `verify` 3. `initialize` and
  `tools/list` cost nothing.
- **The refusal.** For MCP, answer the `tools/call` with a result marked
  `isError: true` whose text the model reads: *"Too many requests from your
  address: wait 12 seconds. The public server allows 30 calls a minute."*
  (Some clients treat an HTTP error as a broken connection, so the reply
  stays a normal one.) For the plain web addresses, reply HTTP status `429`
  with a `Retry-After` header.
- **The class behind one address.** Three ways, which combine:
  1. **A bucket for each MCP session.** The protocol lets the server give a
     session identifier in the `Mcp-Session-Id` header of its reply to
     `initialize`; a client such as Claude Code sends it back with every
     later request. Then each student has a bucket of their own, and the
     address has a larger one (ten times the session's) that only a flood
     empties.
  2. **A key for an event.** A key in the address
     (`https://le2.logicalcontracts.com/mcp?key=ulster-2026-10-22`), valid
     for one day and set in an environment variable of the server, gives a
     larger bucket to everyone who uses it. The lecturer writes the key on
     the slide.
  3. **Signed-in users.** A licence holder (`le_entitlements.pl`) sends a
     token in the `Authorization` header and gets a bucket of their own,
     with the larger limits of their licence.

### 4. The same question, the same answer: a cache

Logical English is deterministic: the same program, scenario, facts and
query always give the same answers. So the server can keep the last few
hundred answers, under a key made of the example's file and its date of
change, the scenario, the facts and the query, and send a repeat without
running it. A class that asks the same question 60 times costs one query. A
query whose answer depends on the time of day (a built-in such as *today*)
must not be cached.

### 5. Smaller replies

Done on 21 October 2026: `get_example_details` leaves out a program text
longer than 30,000 characters unless the call asks for it
(`include_program_text`), and `list_examples` takes a `filter`. Next:
`list_examples` without a filter could send only the names past a certain
length, with a note that says how to filter.

### 6. Settings of the host

In `fly.toml`, `[http_service.concurrency]` with `type = "requests"`,
`soft_limit = 20` and `hard_limit = 25` makes fly.io's proxy hold back the
requests over the limit instead of passing them on. A stronger separation:
serve the tools from a second machine (a second fly.io app, or a second
process group), so that heavy use of the tools never slows the editor.

### 7. Measure before choosing the numbers

Count the calls for each address and each tool, and their time, for a few
weeks (the log line `MCP Result: …` in `llm/mcp.pl` is a start; see also
`docs/dev/telemetry.md`). Choose the limits from what normal use looks like.

## Where it goes in the code

- **One new module**, `le_throttle.pl`: the buckets as dynamic facts
  `bucket(Key, Tokens, LastTime)`, changed only inside
  `with_mutex(le_throttle, …)`; a check `throttle(+Request, +Tool,
  -Verdict)` that answers `allow` or `refuse(Seconds, Message)`; and a
  periodic clean-up of old buckets, like the session reaper of `le_kbs.pl`.
  The time is passed in, so that a plunit test can check the arithmetic
  without waiting.
- **The hook** is `handle_mcp/1` in `llm/mcp.pl`, before
  `handle_mcp_post/1`, for `tools/call` only, and the four `handle_rest_…/1`
  handlers beside it. This is the HTTP half of the server
  (`classic_web_api.pl`); the WebAssembly deployment runs in the user's own
  browser and needs no limit.
- **The settings** as environment variables, so that a lecture can raise
  them without a new build: `LE_MCP_RATE` (calls a minute), `LE_MCP_BURST`,
  `LE_MCP_DAILY`, `LE_MCP_CONCURRENT`, `LE_MCP_TIME_LIMIT`, and
  `LE_MCP_EVENT_KEYS`.

The heart of the bucket, for illustration:

```prolog
%   take(+Key, +Cost, +Now, -Verdict): spend Cost from Key's bucket.
take(Key, Cost, Now, Verdict) :-
    with_mutex(le_throttle, take_(Key, Cost, Now, Verdict)).

take_(Key, Cost, Now, Verdict) :-
    rate(PerSecond), burst(Max),
    (   retract(bucket(Key, T0, Last)) -> true ; T0 = Max, Last = Now ),
    T1 is min(Max, T0 + (Now - Last) * PerSecond),
    (   T1 >= Cost
    ->  T is T1 - Cost, Verdict = allow
    ;   T = T1, Wait is ceiling((Cost - T1) / PerSecond), Verdict = refuse(Wait)
    ),
    assertz(bucket(Key, T, Now)).
```

## A first step

Suggestions 1, 2 and 3 (with the bucket for each address and the key for an
event) are about a day's work with their tests, and remove the risks that
matter. The cache (4) and the second machine (6) can follow when the
measurements (7) show the need.

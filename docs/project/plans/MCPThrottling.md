# Limiting how much one client can ask of the public server

*Kind: plan · Audience: developers · Status: steps 1 and 2 of [the order of the work](#the-order-of-the-work) built on 21 October 2026, in LE2, LPS2 and lpsPlus, for the tools of `/mcp` and for the assistants; not yet deployed; steps 3 and 4 are for later*

## Status (21 October 2026)

### Done

| What | Where | Section |
|---|---|---|
| Time limit (60 s), size limits, at most 4 tool calls at once | `le_throttle.pl` (LE2; LPS2 loads it from its LE2 or `vendor/le2`) | [What was built](#what-was-built-21-october-2026) |
| A budget for each client: token bucket, day total, event total; sessions (`Mcp-Session-Id`) behind a shared address | `le_throttle.pl` | idem |
| Refusals a model can read (MCP), 429/413 with `Retry-After` (LE2's four plain addresses) | `llm/mcp.pl`; LPS2 `src/edges/lps_mcp.pl`, `lps_throttle.pl` | idem |
| Smaller replies: long program text left out, `list_examples` filter, at most 50 answers to a remote client | `llm/mcp.pl` | idem |
| Signed keys (person, event, licence holder), withdrawal, the admin's commands, the identity hook | lpsPlus `accounts/lc_accounts.pl`, `lc_accounts_admin.pl` | idem |
| The licensed parts through MCP, with a licence holder's key | `llm/mcp.pl` (`mcp_roles/1`); LPS2 `lps_plus_set_visitor/2` | idem |
| The assistants: requests paid with the server's key spend the same budget; with the user's own key, no limit | `le_api:llm_payer/3` + `classic_web_api.pl`; LPS2 `lps_assistant:llm_payer/3` + `lps_http.pl` | [The assistants](#the-assistants-21-october-2026-later-the-same-day) |
| The user can always bring a key: the LE2 editor's dialog and the Contract Assistant's page accept one even when the server has a key; LPS2 prefers the user's key | `editor/src/client.ts`; lpsPlus `contract_assistant/web/app.js`; LPS2 `lps_assistant.pl`, `ui/src/assistant.js` | idem |
| Documents: the MCP guides of LE2 and LPS2 ("Limits and keys"), the assistants guide, the LPS2 IDE guide, both privacy notices, the accounts README, the Contract Assistant README | `docs/user/…`, lpsPlus | — |

Tests: `testing/test_throttle.pl` (13), `testing/test_llm_payer.pl` (7), the
`lc_mcp_keys` unit of lpsPlus `accounts/test_lc_accounts.pl` (9), and by hand over
HTTP on both servers (a refusal after the budget, a second session at the same
address, a licence holder's key opening a private example, a user's own key never
refused). The full LE2 suite on the final code: unit and examples pass; the browser
suite fails 16, of which the 10 known on this machine (`executive.spec.ts` ×6,
WebKit; `scasp-engine.spec.ts` ×4, no `library(scasp)` here) and 6 that pass when
run alone (`explanation-drill.spec.ts` ×4, `flip-button.spec.ts` ×2: timing under
the full suite's load). LPS2: the MCP, surface, sandbox, sector-page, telemetry,
assistant-documentation and assistant-prompt gates pass; core lint is clean.

### To deploy

1. Rebuild and redeploy both servers (`./buildPush.sh` in LE2 and in LPS2): the
   code, `revoked_keys.csv` and the vendored `le_throttle.pl` go in the images.
2. Make keys with `LC_AUTH_SECRET` set to the servers' secret
   (`lc_accounts_admin.pl mcp-key …`, lpsPlus `accounts/README.md`).
3. Optional settings (`fly secrets` or `fly.toml`): `LE_MCP_CONTACT` (where a
   refused client may ask for a key), `LE_MCP_STATE_DIR` on a fly.io volume (event
   totals across restarts), and the costs and rates if the defaults prove wrong.
4. After the deploy, check: a call without a key is refused after its budget; a key
   made with the servers' secret is accepted (`mcp-key show`).
5. Commit: nothing is committed yet, in any of the three repositories.

### Left to do

- **Step 3** of the order of the work: the page `/keys`, where a signed-in person
  makes, sees and withdraws keys (random keys in a store that the page can write,
  shared by the two servers); and the cache of answers ([suggestion 4](#4-the-same-question-the-same-answer-a-cache)).
- **Step 4**: OAuth sign-in from the assistant itself
  ([Sign-in from the assistant itself](#sign-in-from-the-assistant-itself-oauth)),
  and a second machine for the tools ([suggestion 6](#6-settings-of-the-host)).
- **Measure** ([suggestion 7](#7-measure-before-choosing-the-numbers)): a few weeks
  of counts for each level and tool, then fix the numbers of the levels and the
  costs of the assistants.
- **`fly.toml` concurrency settings** (suggestion 6, first half): not set.
- **Not limited yet**: the `llm:` semantic services of a program
  (`le_services.pl`), which use the server's key inside a query; and the
  WebAssembly deployments' proxy (`wasm/api/proxy.js`), whose own rule is that the
  server's key wins and `LE_PROXY_KEYS_ONLY=1` refuses the caller's.
- **More than one machine**: each counts for itself; give each its share, or add a
  shared store, if the service grows.
- **LPS2's vendored copy**: `le_throttle.pl` and `i18n/messages.csv` were copied by
  hand into `vendor/le2`; the next run of `tools/vendor_le2.sh` vendors them by
  itself.

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

Run `query` and `verify` under `call_with_time_limit/2` (60 seconds is
generous for the examples; the editor keeps its own 240), and reply
`{error: "The query took more than 60 seconds and was stopped…"}`. Refuse a
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
  3. **A key of one's own.** A person, an event or a licence holder sends a
     key, and the key has its own budget. The section
     [Knowing who asks](#knowing-who-asks-keys-with-a-budget) below says how.

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

## Knowing who asks: keys with a budget

An address is a weak name for a client. A class shares one address; a
laptop changes its address from home to university; and a person who wants
to flood the server can use many addresses. A **key** names the person, the
event or the program that asks. Then the budget belongs to them, a limit can
be raised for those who need more (a course, a licence holder), and one
client can be stopped without stopping the others.

Keys must stay optional. The demonstration "one command, nothing to sign"
(Demo F of the Ulster lecture) is the best introduction the server has, so
a client without a key keeps a small budget of its own.

### What exists already

The lpsPlus repository (the folder `accounts/`, described in its
`README.md`) already has most of the parts:

- **Sign-in** with Google, GitHub, or an email and password that we create,
  on the page `/login` of both servers; one sign-in is valid on LE2 and LPS2.
- **The licences table**, `licenses.csv`: an email address, a licence, and
  the last day the licence may be used.
- **Signed tokens**: `sign/2` and `verify/2` in `lc_accounts.pl` write and
  check a small JSON record signed with the server's secret
  (`LC_AUTH_SECRET`, HMAC-SHA256). `lc_api_token/3` makes a token for one
  hour from them; the server checks it without a table.
- **Program clients**, `api_clients.csv`: a client name and the hash of its
  secret, for a program that signs in (the Oracle Intelligent Advisor
  adapter, with OAuth's "client credentials"). `lc_accounts_admin.pl
  api-client` makes one and prints the secret once.

What is missing: a key for the tools of `/mcp`, a budget attached to it,
and the hook that reads it.

### The levels

| Who asks | How the server knows | Budget to start from | Also |
|---|---|---|---|
| Anybody | nothing: the address only | 10 calls a minute and 200 a day, for each address | a `program_text` of at most 20,000 characters |
| A person | a free key, made on a page `/keys` after signing in | 30 calls a minute, 2,000 a day | a `program_text` of at most 200,000 characters |
| An event (a lecture, a workshop) | an event key that we make | 5,000 calls for the event in all, and 60 a minute for each MCP session | valid only on the days of the event |
| A licence holder | the person's key; the licence is looked up from its email | 300 calls a minute, 50,000 a day | the licensed parts through MCP too (below) |
| A program | the client's secret, exchanged for a token (exists) | as agreed with its owner | |

The numbers are a start; the measurements of suggestion 7 decide them.

### What a key is: two ways

1. **A signed key.** The key is a record signed like the existing tokens:
   `lc_` followed by `sign(_{kind: "mcp_key", sub: Owner, level: Level,
   kid: Id, exp: Expiry})`. The server checks the signature and reads the
   owner, the level and the expiry date from the key itself: no table, no
   storage, and the same key works on both servers.
   - *For:* nothing to store; nothing to keep in step between machines.
   - *Against:* one key cannot be withdrawn unless the server keeps a short
     list of withdrawn key identifiers (a file `revoked_keys.csv` beside
     the licences table); a new `LC_AUTH_SECRET` withdraws every key at
     once; the key is long (about 200 characters).
2. **A random key in a table.** The key is `lc_` and 32 random
   characters; the server keeps only its SHA-256 hash in a table, with the
   owner, the level, the dates and a note.
   - *For:* a short key; each key can be listed, counted and withdrawn.
   - *Against:* a page that makes keys must write the table. Today the
     tables are files in the image, written by hand and deployed; a page
     needs a store that it can write (a fly.io volume, or a small database
     on one), shared by the two servers.
   - A random key of 32 characters needs no slow hash: SHA-256 is enough,
     and fast enough to check on every call. (The slow PBKDF2 hash of the
     passwords and client secrets, 131,072 rounds, is made to be slow: right
     for a sign-in, too slow for every tool call.)

**Recommendation:** signed keys first. They need no store, so event keys
and keys for licence holders can be made with `lc_accounts_admin.pl` the day
the feature is ready. Random keys in a table come with the self-service
page, when there are enough users to need one.

### How the key travels

- **In the `Authorization` header**, as a bearer token. Claude Code:
  `claude mcp add --transport http logical-english
  https://le2.logicalcontracts.com/mcp --header "Authorization: Bearer
  lc_…"`. `mcp-remote` takes `--header` too, and the settings files of the
  other clients have a field for headers.
- **In the address**, `…/mcp?key=lc_…`, for a client that cannot set a
  header. An address is kept in logs and in browser histories, so this way
  is for event keys only: they are short-lived and worth little.
- **The editor and the web API need no key**: a request that carries a
  valid sign-in cookie (`lc_session`) counts as that person.
- The server never writes a key in its log: it writes the key's identifier
  (`kid`).

### Sign-in from the assistant itself: OAuth

The MCP standard describes how a client signs in to a remote server with
OAuth 2.1, the usual protocol for "sign in with …" on the web. The server
answers a call without a token with status `401` and the address of a
description of itself (`/.well-known/oauth-protected-resource`). The client
(in Claude Code: `/mcp`, then *Authenticate*) opens the browser at the
server's sign-in page; the person signs in with Google or GitHub, as on
`/login`; and the client receives a token, which it renews by itself. No
key is copied or pasted.

This is the most convenient way for a person, and the largest piece of
work: the server must become an OAuth authorisation server (the pages
`authorize` and `token`, codes protected with PKCE, the registration of
clients, the description documents), and every part must be secure. It is
for later, when there are many individual users. It must stay optional:
the server goes on answering calls without a token, within the anonymous
budget.

### Counting the budgets

- **What is counted.** For each key, the token bucket of suggestion 3 (the
  rate), a total for the day, and for an event key a total for the event.
  A call can cost by tool (as in suggestion 3) or by time: a budget in
  seconds of work, each call costing its time rounded up to a second, is
  fairer to a client that asks many small questions. Measure before
  choosing.
- **Where the counts live.** The rate and the day's total can live in
  memory: a restart forgets them, which errs on the generous side. The
  machine stops when it is idle (`auto_stop_machines` in `fly.toml`), but
  an idle machine has no load to protect. The total of an event is worth
  keeping: write it to a file on a fly.io volume every minute. With more
  than one machine, each counts for itself; give each machine its share of
  the budget, or add a shared store when the service grows to need one.
- **Telling the client.** Each tool result can say what is left (a header
  `X-LE-Budget-Remaining`, and a sentence in `notes` when less than a tenth
  is left). A refusal says which limit was reached, when the budget
  refills, and where to get a larger one: *"This address has used its 200
  calls for today. A free key gives 2,000: https://le2.logicalcontracts.com/keys"*.
- **The page `/keys`** (with the random keys): a signed-in person makes a
  key (shown once), sees each key's use today, and withdraws a key.
- **The administrator's commands** (with the signed keys), beside the
  existing ones in `lc_accounts_admin.pl`:
  - `mcp-key event ulster-2026-10-22 --budget 5000 --from 2026-10-22 --until 2026-10-22`
    prints an event key;
  - `mcp-key person someone@example.com` prints a person's key, at the
    level of their licences;
  - `mcp-key revoke KID` adds the key to the withdrawn list.

### The licensed parts through MCP

Today a client of `/mcp` never signs in, so it never has a licence: the
private examples and the translators are refused to it. A key tells the
server whose request it is. The hook that reads the key can also set the
request's entitlements (`le_entitlements:set_request_entitlements/1`, from
the licences of the key's email), as the sign-in cookie does for the
editor. Then a licence holder's assistant can read the private examples and
use the translators over MCP. This must be tested with care: a request
without a key must keep the entitlements `none`.

### Privacy and safety

- **What is kept.** A key links calls to an email address. The privacy
  notice must say what is counted (the tool, the time, the size of the
  call), for how long (for example 30 days), and that the facts and the
  queries are not kept: they may contain personal details of a real case.
- **A key pasted by mistake.** Keys begin with `lc_`, so that a person, or
  a code host's search for secrets, recognises one in a public file. A key
  reported in this way is withdrawn.
- **A key on a slide is public.** An event key gets a small budget and the
  days of the event only.
- **No key in logs or in error messages.** Only the identifier.

### Where keys go in the code

- **LE2 must work without lpsPlus**, as it does for licences: LE2 is open
  source and lpsPlus is not. So `le_throttle.pl` asks a hook,
  `le_throttle:client_identity(+Request, -Identity)`, declared `multifile`.
  The accounts code of lpsPlus answers it (it checks the key and looks up
  the licences), as `le_entitlements:host_entitlements/1` is answered for
  LPS2. Without lpsPlus the identity is the address, and the simple event
  keys of `LE_MCP_EVENT_KEYS` still work.
- **The same hook** sets the request's entitlements for a call to `/mcp`.
- **Signed keys** reuse `sign/2` and `verify/2` of `lc_accounts.pl`, with a
  new `kind: "mcp_key"`, so that a key can never be used as a sign-in
  cookie or an API token, nor the other way round.

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

## The order of the work

1. **First, about a day with the tests:** suggestions 1, 2 and 3, with the
   bucket for each address and the simple event keys of
   `LE_MCP_EVENT_KEYS`. These remove the risks that matter.
2. **Then, two or three days:** signed keys for people, events and licence
   holders, made with `lc_accounts_admin.pl`; the hook
   `client_identity/2` in lpsPlus; the levels; the licensed parts through
   MCP; the privacy notice brought up to date.
3. **When there are enough users:** the page `/keys` with random keys in a
   store, and the cache (4).
4. **Later:** OAuth sign-in from the assistant, and a second machine for
   the tools (6), when the measurements (7) show the need.

## What was built (21 October 2026)

Steps 1 and 2 of the order above, for both servers.

- **`le_throttle.pl`** (LE2; LPS2 loads the same file from the LE2 it uses, or
  from its copy in `vendor/le2`): who asks (`throttle_identity/2`: the hook of
  lpsPlus, then `LE_MCP_EVENT_KEYS`, then the address from `Fly-Client-IP`,
  `X-Forwarded-For` or the connection), the levels (`level_limits/2`), the token
  buckets and the totals of the day and of an event (`throttle_admit/4`, and
  `admit_at/5` with the time given, for the tests), the size limit, the calls
  running at once and their time limit (`throttle_run/3`), and the session
  identifiers (`throttle_new_session/1`). The messages are rows `throttle_…` of
  `i18n/messages.csv`, in the five languages.
- **LE2**: `llm/mcp.pl` identifies the client of each POST to `/mcp` and of the
  four plain addresses, gives a key's licences to the request, answers
  `initialize` with `Mcp-Session-Id`, refuses a call over budget (a tool result
  marked `isError` over MCP; 429 or 413 with `Retry-After` at the plain
  addresses), runs the rest within the limits, opens the example trees with the
  request's capabilities, and gives a remote client the first 50 answers of a
  query. Tests: `testing/test_throttle.pl`.
- **LPS2**: `src/edges/lps_throttle.pl` loads `le_throttle.pl` and gives
  `lps_mcp.pl` the same four steps; `lps_plus_set_visitor/2` gives a key's
  licences to the request; `tools/vendor_le2.sh` now vendors `le_throttle.pl`.
- **lpsPlus** (`accounts/`): signed keys (`lc_mcp_key/2`, `lc_verify_mcp_key/2`),
  `revoked_keys.csv` (`lc_revoke_mcp_key/2`), the hook (`lc_client_identity/2`:
  a key, an API client's token, the sign-in cookie), and the commands
  `mcp-key person|event|show|revoke` of `lc_accounts_admin.pl`. Tests: the
  `lc_mcp_keys` unit of `accounts/test_lc_accounts.pl`.
- **Documents**: LE2's and LPS2's `docs/user/api/mcp.md` ("Limits and keys"),
  both privacy notices ("Keys for the tools of the assistants"), and the
  accounts' `README.md`.

Where the building differed from the plan above:

- **The time limit is 60 seconds**, not 30: the first load of a large example
  (the British Nationality Act) takes several seconds before its query runs.
- **Keys start with `lc_`**, not `le2_`: one key is valid on both servers.
- **A request from the same computer is not limited** (unless
  `LE_MCP_THROTTLE_LOCAL=true`): the deep mode of the LE Assistant calls its own
  server's `/mcp`, and a developer's server is not public.
- **A key is looked for in the header, then in the address**: on an LPS2 server
  started with `LPS_TOKEN`, the header carries that token.
- **Every MCP call takes a turn** among the calls that run at once, not only
  `tools/call`; the others are short.

## The assistants (21 October 2026, later the same day)

The same budget, levels and keys now apply to the requests of the assistants that
the server pays for: a request that reaches a language model with the server's key,
and only the server's key. A request that brings the user's own key for the
provider of every model it uses is not counted.

- **Who pays**: `le_api:llm_payer/3` (LE2) and `lps_assistant:llm_payer/3` (LPS2)
  read the operation's model or models and its `api_keys`, with the rule the
  assistants use to choose a key. The operations: LE2's `assistant_command` (10),
  `nl_to_le` (3) and the Contract Assistant's `contract_start` (50); LPS2's
  `assistant_command` and `play_start` (10), `le_nl` and `live_translate` (3).
  `LE_ASSISTANT_COST`, `LE_NL_COST` and `LE_CONTRACT_COST` change the costs.
- **Where**: in the HTTP half of each server, before the operation runs
  (`classic_web_api.pl`, `llm_budget/3` in `handle_leapi/1`; `lps_http.pl`,
  `llm_budget/3` in `lpsapi/1`), so that `le_api.pl` stays free of transport and
  the WebAssembly deployment, which uses the user's keys through its proxy, is not
  touched. The editor's assistant session stands for the MCP session. A refusal is
  an ordinary reply with `error` (and `throttled`, `retry_after`), which every
  assistant already shows, ending with the sentence `throttle_own_llm_key`: with
  the user's own key there is no limit.
- **The user's key must be usable**: the LE2 editor's key dialog no longer locks a
  provider for which the server has a key, and the Contract Assistant shows the key
  field for such a provider as optional. LPS2's assistant chose the server's key
  before the user's (`have_key/3`); it now chooses the user's first, as LE2 does,
  and its key dialog says so.
- **Not counted**: the `llm:` semantic services of a program (`le_services.pl`),
  which run inside a query with the server's key only. A query that uses one is
  limited by the query's own time limit, not by this budget.
- Tests: `testing/test_llm_payer.pl`.

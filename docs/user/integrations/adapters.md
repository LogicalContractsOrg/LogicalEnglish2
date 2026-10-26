# Adapters: keep the callers of another system

*Kind: integration guide · Audience: users and developers · Status: current (2026-10-26)*

An organisation that moves its rules from another system to Logical English
(LE) also has **callers**. A caller is an application that sends cases to the
other system and reads the answers: a claims system, a benefits portal, a
quoting screen. An **adapter** is a part of the LE server that answers those
callers in the format of the other system, at the addresses of the other
system. After the move, a caller changes one setting, the address of the
server. The caller does not change its code.

The rules that answer are the **twin**: the LE program that a translator
wrote from the rules of the other system. The adapter writes each value of a
case as a sentence of the twin, asks the twin the questions of the case, and
sends back the answers in the format of the other system. When a caller asks
for it, the adapter also sends the reasons for each answer.

## Contents

- [The adapters](#the-adapters)
- [The mapping file](#the-mapping-file)
- [How the adapter answers a case](#how-the-adapter-answers-a-case)
- [Ask a twin from your own program](#ask-a-twin-from-your-own-program)
- [Sign-in](#sign-in)
- [Limits](#limits)
- [See also](#see-also)

## The adapters

| The callers of | Use | The adapter answers |
|---|---|---|
| Oracle Intelligent Advisor (OIA) | the twins of OIA projects | decision services, Batch Assess, SOAP Assess, the sign-in of OIA. Refer to [OIA](oia.md#the-oia-adapter) |
| Kogito and Apache KIE (DMN decision services) | the twins of DMN models | `POST /kogito/<model>` and `/dmnresult`. Refer to [DMN](dmn.md#the-dmn-adapter) |
| KIE Server (Red Hat Decision Manager, IBM BAMOE) | the twins of DMN models | the DMN evaluation of KIE Server, in JSON |
| Camunda 7 | the twins of DMN models | `POST /engine-rest/decision-definition/key/<key>/evaluate` |
| Camunda 8 | the twins of DMN models | `POST /v2/decision-definitions/evaluation`, the call of Camunda's own client libraries |

The two adapters come with the Logical English Translators. The common part
of all adapters, the **adapter kit** (`le_adapter.pl`), is a part of the open
engine. The kit reads the mapping files, loads the twins and answers the
cases. Each adapter adds the addresses and the formats of one system.

## The mapping file

A twin uses its own sentences: `the points of the driver is 2`. A caller uses
the names of the other system: `{"Driver": {"Points": 2}}`. The **mapping
file** connects the two. The translator writes it next to the twin, with the
name `<twin>.adapter_map.json` (the OIA translator writes
`<twin>.oia_map.json`, in the same format).

The file is JSON (JavaScript Object Notation, a text format for data). It
holds the names of the deployment and one **attribute** for each name that a
caller uses. This is a part of the mapping file of the Traffic Violation
model (`examples/migration/dmn/clients/traffic_violation/`):

```json
{"title": "Traffic Violation", "project": "Traffic Violation",
 "deployments": ["Traffic Violation", "traffic_violation"],
 "attributes": [
   {"name": "Driver", "kind": "structure", "role": "input",
    "components": [
      {"name": "Points", "kind": "value", "type": "number",
       "template": "the points of the driver is *a number*"}]},
   {"name": "Should the driver be suspended?", "kind": "value", "type": "string",
    "role": "decision", "derived": true,
    "template": "the should the driver be suspended is *a text*"}]}
```

Each attribute has a **kind**. The kind tells how a value becomes sentences:

| Kind | A value of the caller | The sentences of the twin |
|---|---|---|
| `value` | one value: `120` | the template with the value in its place: `the actual speed of the violation is 120` |
| `boolean` | `true` or `false` | the sentence when true; its opposite form (`opposite`) when false |
| `structure` | an object: `{"Points": 2}` | the sentences of its components |
| `list` | a list: `["Golf", "Hockey"]` | one sentence for each item, and the sentence `listed`: `the interests are listed` |
| `records` | a list of objects | one sentence for each object, with a place for each component |
| `evalue`, `ebool` | (OIA) a value of an instance of an entity | the template, with the instance in its first place |

Other fields: `type` (number, string, boolean, date, any), `derived` (true for
a value that the rules of the twin give), `aliases` (other names that callers
use for the same value), and, for an outcome of the kind `structure`,
`null_when_empty` (false when the answer is an object also when no part has a
value).

## How the adapter answers a case

The adapter does these steps for each case:

1. It finds the deployment from the name in the address, for example
   `Traffic Violation`. Case is not important, and a space, a `-` and a `_`
   are the same.
2. It loads the twin. It loads a twin one time, and again when the file of
   the twin changes.
3. It writes each value of the case as a sentence of the twin. LE's own
   parser reads the sentences.
4. It asks each outcome that the caller wants as a question of the twin.
   The outcomes of one case share one memory of answers. Thus the twin
   calculates a long series, for example a schedule of payments, only one
   time.
5. It writes the answers in the format of the caller. An outcome without an
   answer is `null`.
6. When the caller asks for the reasons of an outcome, it adds the
   explanation of the twin: a tree of sentences, each with the sentences that
   it rests on.

## Ask a twin from your own program

The kit is also an operation of the LE application programming interface
(API), the interface that programs use to call the LE server: `adapterDecide`.
The server and the version of LE that runs in the browser both have it. Send
it to `/leapi`:

```json
{"token": "<token>", "operation": "adapterDecide",
 "file": "migration/dmn/clients/traffic_violation/traffic_violation",
 "case": {"Driver": {"Points": 2},
          "Violation": {"Type": "speed", "Actual Speed": 120, "Speed Limit": 100}},
 "outcomes": ["Fine", "Should the driver be suspended?"],
 "reports": ["Fine"]}
```

- `file` is the name of the twin, as the editor opens an example.
- `map` is the mapping. Without it, the operation uses the mapping file next to
  the twin.
- `outcomes` is a list of names, or `"all"` (the default), `"contract"` or
  `"goals"`.
- `reports` is the list of the outcomes that get their reasons.

The answer is `{"outputs": {...}, "reports": {...}}`.

## Sign-in

On a server without restrictions (a developer's computer, a demonstration),
the adapters do not ask for a sign-in. On a hosted server, each call must
have one of these:

- `Authorization: Bearer <token>`, with a token from the sign-in address of
  the adapter (`/opa-hub/api/12.2.23/auth` for OIA,
  `/dmn-adapter/oauth/token` for DMN). The caller sends the identifier and the
  secret of an API client, as it did to the other system.
- `Authorization: Basic`, with the identifier and the secret of an API client.
  The clients of KIE Server and of Camunda 7 send this form.

An API client belongs to an account that has the licence of the Logical
English Translators. Your administrator makes API clients.

## Limits

- **Unknown is no answer.** A twin reads a case as a closed world. An OIA
  boolean that the case does not decide is false, not *unknown*. A DMN
  decision that the twin cannot conclude is `null`, as in DMN.
- **One case at a time.** The adapters do not keep records between calls.
  They answer the calls that calculate. They do not answer the calls that
  change stored data (processes, policies, deployments).
- **One server.** The adapters run in the server of the editor. A lean
  server for production, with versions of each twin, is not available yet.

## See also

- [OIA and Logical English](oia.md#the-oia-adapter)
- [DMN and Logical English](dmn.md#the-dmn-adapter)
- [Other systems: importing and exporting](index.md)

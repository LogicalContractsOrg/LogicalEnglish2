# Logical English in your coding assistant

*Kind: guide · Audience: users, developers · Status: current (2026-10-16)*

A coding assistant is a program such as Claude Code, Cursor, Codex or Gemini
CLI. In such a program, a large language model (an LLM, a program trained on
great quantities of text) reads and writes the files of a project for you.
Logical English (LE) can be added to such an assistant in one line. The
assistant can then write rules in Logical English, check them, and answer
questions with them, instead of working the answers out itself.

Every answer then comes from the rules, with its explanation: the rules and
facts that the answer rests on. The model writes the rules and reads the
answers out to you. The model does not decide the answers.

## Contents

- [What is installed](#what-is-installed)
- [Installing](#installing)
  - [Claude Code: the plugin](#claude-code-the-plugin)
  - [Any assistant: the skill](#any-assistant-the-skill)
  - [Any assistant: the server alone](#any-assistant-the-server-alone)
- [What to ask](#what-to-ask)
- [Your own server](#your-own-server)

## What is installed

Two pieces can be installed, separately or together.

- **The skill** is a set of instructions for the assistant: what Logical
  English is, when to use it, how a program is written and checked, and the
  mistakes to avoid. A skill is a folder with a file named `SKILL.md`. The
  assistant reads that file when a request needs it. The skill also has a
  short script, `le.sh`, which asks the Logical English server over the web
  with the programs `curl` and `python3`. So the skill works even when the
  assistant has no other way to reach the server.
- **The server** is the public Logical English server,
  `https://le2.logicalcontracts.com`. The assistant reaches it through the
  Model Context Protocol (MCP), a common way for an assistant to use the
  tools of another program. The server offers five tools: list the example
  programs, read one, check a program (`verify`), ask a program a question
  (`query`), and search this documentation. The tools are described in
  [Logical English over MCP](../api/mcp.md).

The public server is free and needs no account. It does not save the
programs sent to it, but each program does travel over the internet to it.
Do not send it rules or facts that must stay private: run
[your own server](#your-own-server) for those.

## Installing

### Claude Code: the plugin

A plugin is a package for Claude Code that holds a skill and the settings of
a server together. In Claude Code, type:

```
/plugin marketplace add LogicalContractsOrg/LogicalEnglish2
/plugin install logical-english@logical-english
```

The first line tells Claude Code where the plugin is: in this repository on
GitHub. The second line installs it. The skill and the server are then both
in place.

### Any assistant: the skill

In a terminal, in the folder of your project, type:

```
npx skills add LogicalContractsOrg/LogicalEnglish2
```

The `skills` installer asks which assistants to install the skill for, and
copies it into the folder each one reads skills from. It knows Claude Code,
Cursor, Codex, Gemini CLI, GitHub Copilot, opencode and many others. Add
`-g` to install the skill for every project of your user account.

### Any assistant: the server alone

Without the skill, the assistant still sees the server's five tools and their
descriptions. One line adds the server:

| Assistant | Type in a terminal |
|---|---|
| Claude Code | `claude mcp add --transport http logical-english https://le2.logicalcontracts.com/mcp` |
| Codex | `codex mcp add logical-english --url https://le2.logicalcontracts.com/mcp` |
| Gemini CLI | `gemini mcp add --transport http logical-english https://le2.logicalcontracts.com/mcp` |
| Visual Studio Code | `code --add-mcp '{"name":"logical-english","type":"http","url":"https://le2.logicalcontracts.com/mcp"}'` |

In Cursor, open Settings ▸ MCP ▸ Add new MCP server, and give the address
`https://le2.logicalcontracts.com/mcp`. In Claude Desktop, open Settings ▸
Connectors ▸ Add custom connector, with the same address.

## What to ask

Ask in your own words. The skill tells the assistant to write the rules in
Logical English, check them, and run them. Three examples:

- *"A household gets the heating grant if it lives in the town and its income
  is under 18000. Households with a member over 75 get it whatever their
  income. Write this as rules, save them to heating.le, and tell me whether
  the Smith household gets it."*
- *"Which cases of these rules do my examples not test?"* The assistant runs
  a case search (`which cases make it the case that …`, the
  [language reference](../reference/language.md#1711-case-searches-every-case-and-properties)
  §17.11). It reports each case no scenario tests, with a scenario that
  tests it.
- *"Can anyone be both eligible and excluded?"* The assistant asks
  `is there a case in which …`. The answer is either such a case, with a
  scenario that shows it, or the statement that there is none.

A program the assistant saves as a `.le` file opens in the editor at
https://le2.logicalcontracts.com (File ▸ Open), where you can run it, read
its explanations and change it yourself.

## Your own server

The skill and the plugin use the public server unless told otherwise. To use
a server of your own (see [the web API](../api/web-api.md#starting-the-server)
for how to start one):

- for the skill's script, set the variable `LE_SERVER`, as in
  `export LE_SERVER=http://localhost:3050`;
- for the server's tools, add the server under your own address, as in
  `claude mcp add --transport http logical-english http://localhost:3050/mcp`.

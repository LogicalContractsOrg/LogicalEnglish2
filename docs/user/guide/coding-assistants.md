# Logical English in your coding assistant

*Kind: guide · Audience: users, developers · Status: current (2026-10-16)*

A coding assistant is a program such as Claude Code, Cursor, Codex or Gemini CLI.
In such a program, a large language model reads and writes the files of a project
for you. A large language model (an LLM) is a program that learned from very large
quantities of text. You can add Logical English (LE) to such an assistant with one
line. Then the assistant can write rules in Logical English and check the rules.
The assistant can also answer questions with the rules, and does not calculate the
answers itself.

Then each answer comes from the rules, with its explanation. The explanation gives
the rules and facts that the answer uses. The model writes the rules and tells you
the answers. The model does not decide the answers.

## Contents

- [What is installed](#what-is-installed)
- [Installing](#installing)
  - [Claude Code: the plugin](#claude-code-the-plugin)
  - [Any assistant: the skill](#any-assistant-the-skill)
  - [Any assistant: the server alone](#any-assistant-the-server-alone)
- [What to ask](#what-to-ask)
- [Your own server](#your-own-server)

## What is installed

You can install two parts, separately or together.

- **The skill** is a set of instructions for the assistant. The instructions tell
  what Logical English is, when to use it, how to write and check a program, and
  which mistakes to avoid. A skill is a folder with a file named `SKILL.md`. The
  assistant reads that file when a request needs it. The skill also has a short
  script, `le.sh`. This script sends questions to the Logical English server
  through the web, with the programs `curl` and `python3`. Thus the skill operates
  also when the assistant has no other way to connect to the server.
- **The server** is the public Logical English server,
  `https://le2.logicalcontracts.com`. The assistant connects to the server through
  the Model Context Protocol (MCP). MCP is a standard way for an assistant to use
  the tools of another program. The server gives five tools. The tools list the
  example programs, read one example program, check a program (`verify`), ask a
  program a question (`query`), and search this documentation. Refer to
  [Logical English over MCP](../api/mcp.md) for a description of the tools.

The public server is free, and you do not need an account. The server does not
keep the programs that you send to it. But each program goes through the internet
to the server. Do not send rules or facts that must stay private to the public
server. For those rules and facts, run [your own server](#your-own-server).

## Installing

### Claude Code: the plugin

A plugin is a package for Claude Code that contains a skill and the settings of a
server together. In Claude Code, type:

```
/plugin marketplace add LogicalContractsOrg/LogicalEnglish2
/plugin install logical-english@logical-english
```

The first line tells Claude Code the location of the plugin: this repository on
GitHub. The second line installs the plugin. Then the skill and the server are
both installed.

### Any assistant: the skill

In a terminal, in the folder of your project, type:

```
npx skills add LogicalContractsOrg/LogicalEnglish2
```

The `skills` installer asks for which assistants to install the skill. Then it
copies the skill into the folder where each assistant reads skills. The installer
knows Claude Code, Cursor, Codex, Gemini CLI, GitHub Copilot, opencode and many
other assistants. Add `-g` to install the skill for all projects of your user
account.

### Any assistant: the server alone

Without the skill, the assistant still sees the five tools of the server and their
descriptions. One line adds the server:

| Assistant | Type in a terminal |
|---|---|
| Claude Code | `claude mcp add --transport http logical-english https://le2.logicalcontracts.com/mcp` |
| Codex | `codex mcp add logical-english --url https://le2.logicalcontracts.com/mcp` |
| Gemini CLI | `gemini mcp add --transport http logical-english https://le2.logicalcontracts.com/mcp` |
| Visual Studio Code | `code --add-mcp '{"name":"logical-english","type":"http","url":"https://le2.logicalcontracts.com/mcp"}'` |

To add the server in Cursor, do these steps:

1. Open **Settings ▸ MCP ▸ Add new MCP server**.
2. Type the address `https://le2.logicalcontracts.com/mcp`.

To add the server in Claude Desktop, do these steps:

1. Open **Settings ▸ Connectors ▸ Add custom connector**.
2. Type the same address.

## What to ask

Ask in your own words. The skill tells the assistant to write the rules in Logical
English, to check the rules, and to run the rules. Three examples:

- *"A household gets the heating grant if it lives in the town and its income
  is under 18000. Households with a member over 75 get it whatever their
  income. Write this as rules, save them to heating.le, and tell me whether
  the Smith household gets it."*
- *"Which cases of these rules do my examples not test?"* The assistant runs a case
  search (`which cases make it the case that …`, refer to the
  [language reference](../reference/language.md#1711-case-searches-every-case-and-properties)
  §17.11). The assistant tells you each case that no scenario tests. For each case,
  it also gives a scenario that tests the case.
- *"Can anyone be both eligible and excluded?"* The assistant asks
  `is there a case in which …`. The answer is such a case, with a scenario that
  shows the case. Or the answer says that there is no such case.

When the assistant saves a program as a `.le` file, you can open the file in the
editor at https://le2.logicalcontracts.com (File ▸ Open). In the editor, you can
run the program, read its explanations and change the program yourself.

## Your own server

The skill and the plugin use the public server, unless you tell them to use a
different server. You can use your own server. Refer to
[the web API](../api/web-api.md#starting-the-server) for how to start a server. To
use your own server, do these steps:

1. For the script of the skill, set the variable `LE_SERVER`, as in
   `export LE_SERVER=http://localhost:3050`.
2. For the tools of the server, add the server with your own address, as in
   `claude mcp add --transport http logical-english http://localhost:3050/mcp`.

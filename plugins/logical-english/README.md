# The Logical English skill and plugin

Logical English for coding assistants: a skill (`skills/logical-english/`)
that tells an assistant how to write, check and run rules in Logical English,
and, for Claude Code, a plugin that adds the public Logical English server
(`https://le2.logicalcontracts.com/mcp`) as an MCP server beside it.

Install, in Claude Code:

```
/plugin marketplace add LogicalContractsOrg/LogicalEnglish2
/plugin install logical-english@logical-english
```

Install the skill for any assistant (Claude Code, Cursor, Codex, Gemini CLI,
GitHub Copilot, opencode, …):

```
npx skills add LogicalContractsOrg/LogicalEnglish2
```

The guide, with the one-line commands that add the server alone to each
assistant: `docs/user/guide/coding-assistants.md`.

| File | What it is |
|---|---|
| `.claude-plugin/plugin.json` | the plugin's name, version and description |
| `.mcp.json` | the server the plugin adds |
| `skills/logical-english/SKILL.md` | the instructions the assistant reads |
| `skills/logical-english/reference/quick-reference.md` | the part of the language needed for a first program |
| `skills/logical-english/scripts/le.sh` | the server's tools, from a shell, with `curl` and `python3` |

The marketplace that lists the plugin is `.claude-plugin/marketplace.json` at
the top of this repository. Check both with `claude plugin validate .` and
`claude plugin validate plugins/logical-english`.

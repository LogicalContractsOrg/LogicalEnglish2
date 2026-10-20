# LogicalEnglish2 documentation

| Folder | What | Published |
|---|---|---|
| [`user/`](user/) | the user documentation: tutorials, guides, references, the API. [`user/nav.json`](user/nav.json) is its table of contents, from which the editor's Help menu, the landing page and the documentation viewer are built | yes, at `/docs/user/…` |
| [`dev/`](dev/) | how the system is built: architecture, the assistants, migration, the debugger, the graph, telemetry | no |
| [`project/`](project/) | plans, papers, research material, and an archive of superseded documents | no |

The viewer's shared script, `web_extras/docsview/docs-extras.js` (identical in LE2 and LPS2:
keep the copies equal), gives every document three things. **Search**:
`/docs/search?q=…` searches the documents of `nav.json`, section by section,
deterministically; a document not in `nav.json` is not searched. **Links to
the other IDE**: write them as `https://lps2.logicalcontracts.com/docs/user/…`
(from LE2) or `https://le2.logicalcontracts.com/docs/user/…` (from LPS2); the
viewer rewrites them to wherever the other IDE is (le2.DOMAIN ↔ lps2.DOMAIN; on
localhost ports 3000 ↔ 3060; `?peer=<origin>` overrides). **Diagrams**:
`mermaid` code blocks are drawn with the local `mermaid.min.js`, and their
`click` links are rewritten the same way.

Every document says under its title what kind of document it is, for whom,
and whether it is current. A plan that has been implemented says where its
result is documented.

## How documents are written

The readers are lawyers, underwriters, policy officers and other domain
experts as much as programmers, so every document — and every piece of text
the software puts in front of a reader, such as a menu tip, an explanation of
an answer, or an assistant's reply — is written to be understood by someone
with no technical training.

- **Name the thing instead of pointing at it.** Use a pronoun only when the
  noun it stands for is the one just before it and no other noun could be
  meant. Never open a sentence with *it*, *this*, *that*, *these* or *they*
  standing for the whole sentence before: repeat the noun.
- **No computing jargon without plain words in the same sentence.** Words such
  as *parse*, *instantiate*, *serialise*, *hook*, *callback*, *back end*,
  *repository*, *endpoint* and *payload* are replaced by ordinary English, or
  explained where they first appear. Name a file, a predicate or a setting
  only where the reader has to go and look at it.
- **One idea per sentence, in the order things happen.** Prefer a subject that
  acts: *the editor checks the document*, rather than *the document is
  checked*.
- **Spell out an abbreviation the first time each document uses it.**
- **Documents should be self-contained.** Notations and concepts should be clearly explained, or references given to documents explaining them.
- The names of the ideas these systems teach — a fluent, an event, a template,
  a scenario, a reactive rule — are part of the language being taught. Use
  them freely, and define each one at first use or in the glossary.

### Simplified Technical English

Write each user document in ASD-STE100 Simplified Technical English (STE).
STE is a controlled form of English for technical documents (refer to
<https://en.wikipedia.org/wiki/Simplified_Technical_English>). The model is
LE2's tutorial `docs/user/tutorials/intro-to-le/intro-to-le.md`. Obey these
rules, together with the rules above:

- **Short sentences.** Write a maximum of 20 words in a procedure, and a
  maximum of 25 words in a description. Split a long sentence; do not remove
  its content.
- **Short paragraphs.** Write a maximum of six sentences in a paragraph. Give
  each paragraph one topic.
- **Procedures as numbered steps.** Write "Do these steps:" and then a
  numbered list. Write one instruction in each step, with the command form of
  the verb ("Select…", "Click…", "Run…"). Write the result of the steps in a
  separate sentence after the list.
- **Active voice and simple tenses.** Use the present, the simple past and the
  simple future. Do not use an "-ing" form where a simple form is possible.
- **One word for one meaning.** Use the same word each time. Write "Refer to"
  for a cross-reference, "Put the mouse pointer on" for a hover, "Select" for a
  menu item or a list, and "Click" for a button.
- **Approved words.** When possible, use the words of the STE dictionary: *use*
  (not *utilise*), *make sure* (not *ensure*), *can* (not *is able to*),
  *show* (not *display*), *start* (not *launch*), *give* (not *provide*), *do*
  (not *perform*), *tell* (not *inform*), *thus* (not *therefore*), *about*
  (not *regarding*), *before* (not *prior to*).
- **No contractions, idioms, jokes or phrasal verbs** (*find out* → *find*).
  Keep the articles (*the*, *a*) that English needs.
- **Notes and warnings** come before the step that they apply to.
- **Words outside the STE dictionary** are permitted in three groups: the names
  in the user interface (menus, buttons, windows, settings), always in
  **bold** and spelled as the software spells them; the names of the ideas of
  the languages (template, scenario, query, fluent, event, reactive rule);
  and other technical names (Prolog, s(CASP), JSON). Define each one at first
  use.
- **Keep what other files depend on.** Do not change program text (code
  blocks and inline code), screenshots, link targets, quoted text from other
  sources, or a heading that other documents link to.

## The documents

**User documentation** (`user/`)

- Tutorials: [Introduction to Logical English](user/tutorials/intro-to-le/intro-to-le.md), [querying a program](user/tutorials/querying-a-program.md), [LE Views](user/tutorials/views.md)
- Guides: [the editor](user/guide/editor.md), [the executive view](user/guide/executive-view.md), [the assistants](user/guide/assistants.md), [the Proof Game](user/guide/proof-game.md), [the verifier's warnings](user/guide/warnings.md)
- Reference: [the language](user/reference/language.md) (and [em português](user/reference/language.pt.md)), [the extensions](user/reference/extensions.md) (the hosted service), [s(CASP)](user/reference/scasp.md), Logical English for LPS (in LPS2: `docs/user/reference/le-for-lps.md`)
- Other systems: [the map, importing and exporting](user/integrations/index.md), and a document per system: [Bitcoin Miniscript](user/integrations/miniscript.md), [LegalRuleML](user/integrations/legalruleml.md), [s(CASP), Prolog and LE1](user/integrations/scasp.md), [Blawx](user/integrations/blawx.md), [Oracle Intelligent Advisor](user/integrations/oia.md), [Socotra](user/integrations/socotra.md), [OIPA](user/integrations/oipa.md), [Epilog](user/integrations/epilog.md); Drools, Solidity, Daml, PDDL, Inform 7 and the original LPS are in LPS2's `docs/user/integrations/`
- API: [the web API](user/api/web-api.md), [MCP](user/api/mcp.md)

**Developer documentation** (`dev/`): [architecture](dev/architecture.md), [the LE Assistant](dev/assistant.md), [the Contract Assistant](dev/contract-assistant.md), [LE Views](dev/views.md), [migration](dev/migration.md), [debugger](dev/debugger.md), [graph](dev/graph.md), [telemetry](dev/telemetry.md), [deploying as a static site](dev/deploy-vercel.md) (the WebAssembly build: LE2 in the browser, on Vercel), [i18n](../i18n/README.md), the LE2↔LPS2 interface (in LPS2: `docs/dev/le-lps-interface.md`).

**Project documents** (`project/`): [plans](project/plans/), [papers](project/papers/), [research](project/research/), [archive](project/archive/).

The LLM features read documents by path — the language reference in
particular (`le_assistant_light.pl`, lpsPlus's `contract_assistant/le_contract_assistant.pl`,
`AGENTS_LE_template*.md`, `llm/mcp.pl`): move one only together with them.
`vibeCodingNotes.md` is private notes, not served and not in the image.

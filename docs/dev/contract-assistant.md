# The LE Contract Assistant

*Kind: design pointer · Audience: developers · Status: current (2026-10-04)*

The Contract Assistant turns a contract, its schedules and its cases into a
tested Logical English program. It is part of the **Logical English
Translators**, a licensed product, and its code lives in the private lpsPlus
repository, in `contract_assistant/`: the module `le_contract_assistant.pl`,
residue mode's folding (`le_residue_fold.pl`), the prompts, the web page and
the tests. Its design document is that folder's `README.md`. Until 4 October
2026 all of it was in this repository.

## What is here

This repository keeps what LE2 needs to run the assistant when it is
installed, and what other open features use:

| Here | What it does |
|---|---|
| `le_api.pl` | loads the module where an lpsPlus checkout has it (`le_plus.pl`), and routes the five `contract_…` operations to it. Without it they answer `{"error": …, "not_installed": true}`; without the licence, `{"error": …, "unlicensed": true}` (`contract_assistant_refusal/1`, `contract_assistant_installed/0`) |
| `classic_web_api.pl` | serves the page, from lpsPlus `contract_assistant/web/`, at `/web_extras/contract_assistant/`, to visitors whose licence includes it (`handle_contract_assistant_page/1`) |
| `le_entitlements.pl` | the capability `contract_assistant`, which the lpsPlus licence "Logical English Translators" grants |
| `llm/llm_client.pl`, `llm/llm_prices.pl` | the model client and the price table, which the LE Assistant and "Write it in English" use too |
| `le_issue_feedback.pl` | how verifier issues are ranked and shown to a model, shared with "Write it in English" (`nl_to_le.pl`) |
| `le_verifier.pl` | the checks the assistant's repair rounds rely on (`quote_not_found` with the closest passage, `builtin_template`, `unbound_aggregate_variable`) |
| `vendor_lpsplus.sh` | copies `contract_assistant/` into the server image with the rest of lpsPlus |
| `editor/tests/contract-assistant.spec.ts` | the page's tests, skipped where the assistant is not installed |

`testing/run_tests.sh unit` also runs lpsPlus's `contract_assistant/testing/`
when it finds an lpsPlus checkout, each file in a process of its own.

The user documentation stays here: [the assistants](../user/guide/assistants.md#the-contract-assistant)
and [the web API](../user/api/web-api.md#contract_start--start-a-contract-assistant-job).

% Who pays for an assistant's language model (le_api:llm_payer/3): the user,
% when the browser brings a key for the provider of every model the request
% uses, and then nothing is limited; the server otherwise, and then the
% request spends from the client's budget (classic_web_api.pl, le_throttle.pl).

:- use_module(library(plunit)).
:- use_module('../le_api').

:- begin_tests(llm_payer).

test(assistant_with_users_key) :-
    llm_payer(_{operation: "assistant_command", model: "gpt-4o",
                api_keys: _{openai: "sk-user", anthropic: null}}, 10, user).

test(assistant_with_servers_key) :-
    llm_payer(_{operation: "assistant_command", model: "gpt-4o",
                api_keys: _{openai: "", groq: "gsk-user"}}, 10, server).

test(nl_to_le_default_model_is_groq) :-
    llm_payer(_{operation: "nl_to_le", api_keys: _{groq: "gsk-user"}}, 3, user),
    llm_payer(_{operation: "nl_to_le", api_keys: _{openai: "sk-user"}}, 3, server).

test(contract_needs_a_key_for_every_model) :-
    llm_payer(_{operation: "contract_start", model: "gpt-4o", judge_model: "openai/gpt-oss-120b",
                api_keys: _{openai: "sk-user"}}, 50, server),
    llm_payer(_{operation: "contract_start", model: "gpt-4o", judge_model: "openai/gpt-oss-120b",
                api_keys: _{openai: "sk-user", groq: "gsk-user"}}, 50, user).

test(no_keys_at_all) :-
    llm_payer(_{operation: "assistant_command", model: "gpt-4o"}, _, server).

test(other_operations_call_no_model, [fail]) :-
    llm_payer(_{operation: "answeringQuery"}, _, _).

test(cost_from_environment, [cleanup(unsetenv('LE_ASSISTANT_COST'))]) :-
    setenv('LE_ASSISTANT_COST', 25),
    llm_payer(_{operation: "assistant_command", model: "gpt-4o"}, 25, server).

:- end_tests(llm_payer).

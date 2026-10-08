% Tests for the LLM price table (llm/llm_prices.pl). The Contract Assistant's
% cost estimate built on it is tested where the assistant is, in the lpsPlus
% repository (contract_assistant/testing/test_cost_estimate.pl). A tiny local price file (pointed at by
% LE_MODEL_PRICES_FILE, exactly as an offline deployment would) stands in for
% LiteLLM's model_prices_and_context_window.json, so nothing here touches the
% network.

:- use_module('../llm/llm_prices').
:- use_module('../llm/llm_client').

% A handful of rows in LiteLLM's schema: bare keys for OpenAI/Anthropic,
% provider-prefixed keys for the rest, plus a costless entry that must be
% ignored and a dearer twin of one model to prove the conservative choice.
price_fixture('{
  "sample_spec": {"input_cost_per_token": "docs, not a model"},
  "gpt-4o": {"input_cost_per_token": 2.5e-06, "output_cost_per_token": 1e-05,
             "litellm_provider": "openai", "mode": "chat"},
  "claude-haiku-4-5-20251001": {"input_cost_per_token": 1e-06,
             "output_cost_per_token": 5e-06, "litellm_provider": "anthropic", "mode": "chat"},
  "groq/openai/gpt-oss-120b": {"input_cost_per_token": 1.5e-07,
             "output_cost_per_token": 6e-07, "litellm_provider": "groq", "mode": "chat"},
  "cheapcloud/zai-org/glm-5.2": {"input_cost_per_token": 1e-06,
             "output_cost_per_token": 2e-06, "litellm_provider": "cheapcloud", "mode": "chat"},
  "dearcloud/zai-org/glm-5.2": {"input_cost_per_token": 3e-06,
             "output_cost_per_token": 9e-06, "litellm_provider": "dearcloud", "mode": "chat"},
  "text-embedding-3-small": {"input_cost_per_token": 2e-08, "litellm_provider": "openai",
             "mode": "embedding"}
}').

prices_setup :-
    tmp_file(le_prices, File),
    price_fixture(JSON),
    setup_call_cleanup(open(File, write, S, [encoding(utf8)]),
                       write(S, JSON), close(S)),
    setenv('LE_MODEL_PRICES_FILE', File),
    retractall(llm_prices:price_row(_, _, _)),
    retractall(llm_prices:prices_meta(_)),
    retractall(llm_prices:prices_tried),
    nb_setval(le_price_fixture, File).

prices_cleanup :-
    unsetenv('LE_MODEL_PRICES_FILE'),
    retractall(llm_prices:price_row(_, _, _)),
    retractall(llm_prices:prices_meta(_)),
    retractall(llm_prices:prices_tried),
    ( nb_current(le_price_fixture, F) -> catch(delete_file(F), _, true) ; true ).

:- begin_tests(llm_prices, [setup(prices_setup), cleanup(prices_cleanup)]).

test(loads_from_local_file) :-
    llm_prices_status(S),
    assertion(S.loaded == true),
    assertion(S.models =:= 5).      % the embedding row and sample_spec are skipped

% Bare key (OpenAI), and Anthropic likewise.
test(bare_key_lookup) :-
    llm_price('gpt-4o', In, Out),
    assertion(In =:= 2.5e-06),
    assertion(Out =:= 1e-05),
    llm_price('claude-haiku-4-5-20251001', In2, _),
    assertion(In2 =:= 1e-06).

% The registry's short name is resolved to the provider-qualified LiteLLM key.
test(provider_prefixed_lookup) :-
    llm_price('openai/gpt-oss-120b', In, Out),
    assertion(In =:= 1.5e-07),
    assertion(Out =:= 6e-07).

% Served by several providers under a suffix match: the DEAREST wins, so an
% estimate is never flattering.
test(ambiguous_model_takes_the_dearest) :-
    llm_price('zai-org/GLM-5.2', In, Out),
    assertion(In =:= 3e-06),
    assertion(Out =:= 9e-06).

test(unknown_model_has_no_price) :-
    assertion(\+ llm_price('no-such-model-anywhere', _, _)).

:- end_tests(llm_prices).


/* test_llm_model_list.pl — the models the pickers offer (llm_list_models/1):
   a model that its provider's own list no longer has is hidden; a provider
   whose list could not be read keeps all its models. No network: the
   providers' lists are put in the cache by hand. */

:- use_module(library(plunit)).
:- use_module('../llm/llm_client').

with_cache(Provider, Ids, Goal) :-
    get_time(Now),
    setup_call_cleanup(
        ( retractall(llm_client:provider_models_cache(_, _, _)),
          forall(member(P, [openai, groq, anthropic, together, gemini]),
                 assertz(llm_client:provider_models_cache(P, Now, failed))),
          retractall(llm_client:provider_models_cache(Provider, _, _)),
          assertz(llm_client:provider_models_cache(Provider, Now, Ids)) ),
        Goal,
        retractall(llm_client:provider_models_cache(_, _, _))).

:- begin_tests(llm_model_list).

test(withdrawn_model_hidden) :-
    with_cache(openai, ['gpt-6.1-sol', 'gpt-6-sol'], llm_list_models(Rows)),
    assertion(memberchk(row('gpt-6.1-sol', openai, _), Rows)),
    assertion(\+ memberchk(row('gpt-6-luna', openai, _), Rows)).

test(unreadable_list_keeps_all) :-
    findall(S, llm_client:llm_model_entry(S, together, _, _), All),
    with_cache(openai, [], llm_list_models(Rows)),
    findall(S, member(row(S, together, _), Rows), Kept),
    assertion(Kept == All).

test(no_retired_model_offered) :-
    findall(S, llm_client:llm_model_entry(S, _, _, _), All),
    forall(member(Old, ['gpt-4', 'gpt-4-turbo', 'gpt-4o', 'gpt-4o-mini', 'llama-3.3-70b',
                        'gemini-2.0-flash', 'deepseek-ai/DeepSeek-V4-Pro']),
           assertion(\+ memberchk(Old, All))).

:- end_tests(llm_model_list).

/* test_contract_assistant_citations.pl — the Contract Assistant's citations,
   its models per branch, its wording from a web page, and its licence.

   - The draft is told the name of the wording's text file, and the program is
     verified beside that file, so a quotation the wording does not hold is a
     `quote_not_found` warning whose fix names the closest real passage.
   - `branch_models` gives the branches their models in turn, each with its
     own auto-tunings.
   - A web page given as the wording becomes text without a converter.
   - The `/leapi` operations of the Contract Assistant answer only a request
     whose licence includes `contract_assistant`.
   No test needs a network or an API key: the LLM is stubbed (ca_llm_hook/1).
*/

:- use_module(library(plunit)).
:- use_module('../le_contract_assistant').
:- use_module('../le_api').
:- use_module('../le_entitlements').

:- dynamic seen_message/2.     % Purpose, the user message of the call

ci_wording("# Flood policy\n\n## I. Agreement\n\nWe will pay you for direct physical loss by or from flood to your insured property.\n").

cited_program(Quote, P) :-
    format(string(P),
"the target language is: prolog.

the templates are:
    *a claim* is covered.
    *a claim* is for a flood loss; undefined.

the knowledge base flood includes:
the policy is published at \"https://example.org/policy.pdf\".
the text of the policy is at \"wording-policy.md\".

section question is:
rule insuring_agreement with provenance the policy at article I,
        confer \"~w\":
a claim is covered
    if the claim is for a flood loss.

scenario one is:
    claim one is for a flood loss.
    q expects answers [\"claim one is covered\"].

query q is:
    which claim is covered.
", [Quote]).

hook_cites(Purpose, Messages, Reply) :-
    last(Messages, M),
    assertz(seen_message(Purpose, M.content)),
    (   Purpose = draft(_)
    ->  cited_program("We will pay you for direct loss by flood to your insured property", P),
        format(string(Reply), "```le\n~w```\n", [P])
    ;   ( Purpose = repair(_, _) ; Purpose = polish(_, _) )
    ->  cited_program("We will pay you for direct physical loss by or from flood to your insured property", P),
        format(string(Reply), "```le\n~w```\n", [P])
    ;   Purpose == ledger
    ->  Reply = "LEDGER"
    ;   Reply = "*a claim* is covered."
    ).

ci_hook_setup :-
    retractall(seen_message(_, _)),
    tmp_file(cajobs, Tmp),
    setenv('LE_CONTRACT_JOBS_DIR', Tmp),
    retractall(le_contract_assistant:ca_llm_hook(_)),
    assertz(le_contract_assistant:ca_llm_hook(user:hook_cites)).

ci_hook_cleanup :-
    retractall(le_contract_assistant:ca_llm_hook(_)),
    unsetenv('LE_CONTRACT_JOBS_DIR').

ci_start(Extra, JobID) :-
    ci_wording(W),
    Config0 = _{wording: _{name: "policy.md", text: W},
                model: "stub-model",
                budget: _{preset: "draft", minutes: 5}},
    Config = Config0.put(Extra),
    start_contract_job(Config, [sync(true)], JobID).

:- begin_tests(contract_assistant_citations,
               [setup(ci_hook_setup), cleanup(ci_hook_cleanup)]).

test(draft_is_told_the_document) :-
    ci_start(_{}, JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    once(seen_message(draft(1), Msg)),
    assertion(sub_string(Msg, _, _, _, "## DOCUMENT")),
    assertion(sub_string(Msg, _, _, _, "wording-policy.md")),
    assertion(sub_string(Msg, _, _, _, "no web address")).

test(misquotation_is_repaired_against_the_wording) :-
    ci_start(_{}, JobID),
    le_contract_assistant:ca_result(JobID, Result),
    % the draft's quotation was not in the wording: the round that cleans up
    % warnings was told so, with the passage it should have quoted ...
    once(seen_message(polish(1, _), Feedback)),
    assertion(sub_string(Feedback, _, _, _, "quote_not_found")),
    assertion(sub_string(Feedback, _, _, _, "direct physical loss by or from flood")),
    % ... and the delivered program quotes it exactly
    assertion(sub_string(Result.le, _, _, _, "direct physical loss by or from flood")),
    assertion(Result.final_score.warnings =:= 0).

test(branch_models_take_turns) :-
    ci_start(_{branch_models: ["model-a", "model-b"],
            budget: _{preset: "draft", w: 3, minutes: 5}}, JobID),
    findall(I-M, le_contract_assistant:ca_branch_model(JobID, I, M), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [1-"model-a", 2-"model-b", 3-"model-a"]),
    le_contract_assistant:ca_result(JobID, Result),
    assertion(sub_string(Result.ledger, _, _, _, "branches: model-a, model-b")).

test(branch_models_from_a_string) :-
    le_contract_assistant:branch_models(_{branch_models: " gpt-5.5 , Qwen/Qwen3.8-2.4T-A95B "}, Ms),
    assertion(Ms == ["gpt-5.5", "Qwen/Qwen3.8-2.4T-A95B"]).

test(tunings_are_per_model) :-
    le_contract_assistant:tune_key(j1, _{model: "m"}, K1),
    le_contract_assistant:tune_key(j1, _{model: "q", branch_model: "q"}, K2),
    assertion(K1 == j1),
    assertion(K2 == j1/q).

test(document_block_names_the_address) :-
    le_contract_assistant:document_block(
        _{wording: '/x/sources/wording-policy.md', wording_url: 'https://example.org/policy.pdf'}, B),
    assertion(sub_string(B, _, _, _, "`wording-policy.md`")),
    assertion(sub_string(B, _, _, _, "https://example.org/policy.pdf")).

test(wording_url_must_be_web_address, [fail]) :-
    le_contract_assistant:wording_url(_{wording_url: "file:///etc/passwd"}, _).

:- end_tests(contract_assistant_citations).

:- begin_tests(contract_assistant_html_wording).

test(html_page_to_text) :-
    tmp_file(page, Base),
    atom_concat(Base, '.html', Html),
    atom_concat(Base, '.md', Md),
    setup_call_cleanup(open(Html, write, S),
        format(S, "<html><head><style>p{}</style></head><body><h1>Policy</h1><p>We will\npay you.</p><ul><li>One</li></ul><script>x()</script></body></html>", []),
        close(S)),
    le_contract_assistant:html_to_text_file(Html, Md),
    read_file_to_string(Md, T, []),
    assertion(T == "Policy\n\nWe will pay you.\n\nOne").

:- end_tests(contract_assistant_html_wording).

:- begin_tests(contract_assistant_licence, [setup(unsetenv('NO_RESTRICTIONS'))]).

test(refused_without_the_licence) :-
    with_entitlements([converters],
        handle_operation(_{operation: "contract_status", job: "caj_none"}, R)),
    assertion(R.unlicensed == true),
    assertion(sub_string(R.error, _, _, _, "Logical English Translators")).

test(served_with_the_licence) :-
    with_entitlements([contract_assistant],
        handle_operation(_{operation: "contract_status", job: "caj_none"}, R)),
    assertion(\+ get_dict(unlicensed, R, _)).

:- end_tests(contract_assistant_licence).

:- begin_tests(contract_assistant_supplied_cases).

test(identifiers_of_json_cases) :-
    tmp_file(cases, B), atom_concat(B, '.json', F),
    setup_call_cleanup(open(F, write, S),
        format(S, "{\"claims\": [{\"claimRef\": \"C-01\", \"policyRef\": \"P1\"}, {\"claimRef\": \"C-02\", \"policyRef\": \"P1\"}]}", []),
        close(S)),
    le_contract_assistant:case_identifiers([F], Ids),
    assertion(Ids == ["C-01", "C-02"]).

test(missing_case_is_an_error,
     [setup(( assertz(le_contract_assistant:ca_config(jtest, _{mode: contract, dev_case_ids: ["C-01", "C-02"]})),
              le_contract_assistant:ca_bind_job(jtest) )),
      cleanup(( retractall(le_contract_assistant:ca_config(jtest, _)),
                retractall(le_contract_assistant:ca_thread_job(_)) ))]) :-
    le_contract_assistant:supplied_case_issues("scenario C-01 is:\n    x.\n\nscenario mine is:\n    y.\n", Is),
    Is = [I],
    get_dict(type, I, Type), get_dict(message, I, Msg),
    assertion(Type == "supplied_case_missing"),
    assertion(sub_string(Msg, _, _, _, "C-02")).

:- end_tests(contract_assistant_supplied_cases).

:- dynamic refused_once/0.

%   The first repair request is refused (as a provider's content filter
%   refused one); the second, with a shorter feedback, is answered.
hook_refuse_once(Purpose, Messages, Reply) :-
    (   Purpose = repair(_, _), \+ refused_once
    ->  assertz(refused_once),
        throw(error(contract_assistant_error(llm_failed(repair, "invalid_prompt")), _))
    ;   Purpose = draft(_)
    ->  cited_program("We will pay you for direct physical loss by or from flood to your insured property", P0),
        % a wrong expectation, so that a repair round is needed
        sub_string(P0, B, _, A, "claim one is covered\"]"), sub_string(P0, 0, B, _, Pre),
        sub_string(P0, _, A, 0, Post),
        atomics_to_string([Pre, "claim two is covered\"]", Post], P),
        format(string(Reply), "```le\n~w```\n", [P])
    ;   hook_cites(Purpose, Messages, Reply)
    ).

:- begin_tests(contract_assistant_refused_repair,
               [setup(( ci_hook_setup, retractall(refused_once),
                        retractall(le_contract_assistant:ca_llm_hook(_)),
                        assertz(le_contract_assistant:ca_llm_hook(user:hook_refuse_once)) )),
                cleanup(ci_hook_cleanup)]).

test(a_refused_repair_is_tried_again) :-
    ci_start(_{}, JobID),
    assertion(user:refused_once),
    findall(L, le_contract_assistant:ca_log(JobID, _, L), Ls),
    assertion(( member(L1, Ls), sub_string(L1, _, _, _, "trying once more") )),
    le_contract_assistant:ca_result(JobID, Result),
    assertion(Result.final_score.tests_failed =:= 0).

:- end_tests(contract_assistant_refused_repair).

:- begin_tests(contract_assistant_why_no_answer).

test(failed_test_says_why) :-
    P = "the target language is: prolog.

the templates are:
    *a claim* is covered.
    *a claim* is for a flood loss.
    *a claim* is reported in time.

the knowledge base k includes:

a claim is covered
    if the claim is for a flood loss
    and the claim is reported in time.

scenario one is:
    claim one is for a flood loss.
    q expects answers [\"claim one is covered\"].

query q is:
    which claim is covered.
",
    verify_le_text(P, V),
    V.test_details = [D],
    assertion(sub_string(D.why_not, _, _, _, "not stated by the scenario: claim one is reported in time")),
    assertion(sub_string(D.why_not, _, _, _, "line 10")),
    le_contract_assistant:format_verify_feedback(V, F),
    assertion(sub_string(F, _, _, _, "why the expected answer is not reached")).

:- end_tests(contract_assistant_why_no_answer).

:- begin_tests(quote_closest_passage).

test(closest_passage_offered) :-
    le_provenance:normalized_text("Intro. We will pay you for direct physical loss by or from flood to your insured property if you: pay.", N),
    le_verifier:closest_passage("We will pay for direct loss by flood to the insured property", N, P),
    assertion(sub_string(P, _, _, _, "direct physical loss")).

test(nothing_close, [fail]) :-
    le_provenance:normalized_text("Intro. We will pay you for direct physical loss by or from flood.", N),
    le_verifier:closest_passage("this text is not in the policy", N, _).

:- end_tests(quote_closest_passage).

/* test_entitlements.pl — what a request may use of the licensed parts.

   le_entitlements.pl carries, per thread, the capabilities of the visitor a
   server is serving (the licences themselves are lpsPlus's). These tests
   check the carrier, that a program parsed for one visitor is never handed
   to another with a different licence (le_kbs:grammar_key/2), and that a
   numbered rule body read without the InsurLE licence is an error that says
   so, rather than a rule with no conditions.
*/

:- use_module(library(plunit)).
:- use_module('../le_entitlements').
:- use_module('../le_kbs').

numbered_program("the target language is: prolog.

the templates are:
    *a person* is eligible.
    *a person* is a citizen.
    *a person* is a resident.

the knowledge base numbered includes:
    a person is eligible if:
    1. the person is a citizen; or
    2. the person is a resident.

scenario s is:
    ann is a resident.

query q is:
    which person is eligible.
").

extensions_installed :- current_predicate(le_extensions:parse_numbered_body/7).

issue_kinds(M, Kinds) :-
    findall(K, M:le_issue(error, K, _, _, _, _), Kinds).

:- use_module('../le_import', []).

:- begin_tests(entitlements, [setup(unsetenv('NO_RESTRICTIONS'))]).

test(default_is_everything) :-
    le_entitlements:clear_request_entitlements,
    entitled(converters), entitled(le_extensions).
test(request_limits) :-
    with_entitlements([converters], ( entitled(converters), \+ entitled(le_extensions) )).
test(request_restored_after) :-
    with_entitlements([], true),
    entitled(le_extensions).
test(server_default_is_nothing) :-
    setup_call_cleanup(set_default_entitlements(none),
                       \+ entitled(converters),
                       set_default_entitlements(all)).
test(no_restrictions_lifts_all) :-
    setup_call_cleanup(setenv('NO_RESTRICTIONS', true),
                       with_entitlements([], entitled(le_extensions)),
                       unsetenv('NO_RESTRICTIONS')).

test(same_program_other_licence_other_module) :-
    numbered_program(T),
    with_entitlements(all, load_text(T, M1)),
    with_entitlements([], load_text(T, M2)),
    (   extensions_installed
    ->  M1 \== M2
    ;   M1 == M2         % no extensions here: nothing to tell apart
    ).

test(numbered_body_without_licence_is_an_error) :-
    numbered_program(T),
    with_entitlements([converters], load_text(T, M)),
    issue_kinds(M, Kinds),
    memberchk(numbered_body_unlicensed, Kinds).

test(numbered_body_with_licence, [condition(extensions_installed)]) :-
    numbered_program(T),
    with_entitlements([le_extensions], load_text(T, M)),
    issue_kinds(M, Kinds),
    \+ memberchk(numbered_body_unlicensed, Kinds).

%   The translators of other systems are free, and a server with a sign-in
%   gives them to signed-in visitors: a visitor who has not signed in is
%   told to sign in, and not that no translator reads the file.
test(translators_ask_an_unsigned_visitor_to_sign_in) :-
    with_entitlements([], le_import:no_translator_message('model.dmn', M1)),
    once(sub_string(M1, _, _, _, "Sign in")),
    with_entitlements([converters], le_import:no_translator_message('model.zzz', M2)),
    \+ sub_string(M2, _, _, _, "Sign in").

%   The registry offers a translator to a request that may use them, and to
%   no other (migration/le_importers.pl).
test(registry_follows_the_capability) :-
    with_entitlements([converters], registry_importers(N1)),
    with_entitlements([], registry_importers(N0)),
    N1 > 10, N0 =:= 0.

%   The importers of the registry: those whose translator is a file of
%   migration/. Another test file may register importers of its own
%   (test_le_import.pl does), which no capability gates; when the suites are
%   loaded together those are in the table too, and they are not counted.
registry_importers(N) :-
    aggregate_all(count,
                  ( le_import:importer(_, _, _, File, _, _),
                    atomic(File), sub_atom(File, _, _, _, '/migration/') ),
                  N).

:- end_tests(entitlements).

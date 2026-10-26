/** <module> Unit tests for functions given a formula (language.md §2.3)

    A function applied to a formula, `the double of (the fee + 1)`, receives
    the formula and calculates it. Its step in an explanation must still read
    as the function's template, not as the Prolog goal.

    Uses testing/fixtures/le/function_operands.le. Run with:
        swipl -g run_tests -t halt testing/test_function_operands.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_function_operands, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../reasoner').

% Every node text of the explanations of a query's answers.
why_texts(KB, SM, QueryName, Texts) :-
    KB:query_info(QueryName, Goal, _),
    findall(S,
        ( reasoner:i(Goal, SM, _U, Why0),
          le_kbs:postprocess_why(Why0, SM, Why),
          node_text(Why, T), to_str(T, S) ),
        Texts).

node_text(T, Txt) :-
    ( is_list(T) -> member(X, T), node_text(X, Txt)
    ; T = success(_, _, LE, Ch) -> ( Txt = LE ; node_text(Ch, Txt) )
    ; T = failure(_, _, LE, Ch) -> ( Txt = LE ; node_text(Ch, Txt) )
    ; fail
    ).

to_str(X, S) :- ( string(X) -> S = X ; atom(X) -> atom_string(X, S) ; term_string(X, S) ).

:- begin_tests(function_operands).

test(formula_argument_reads_as_template) :-
    le_kbs:load('testing/fixtures/le/function_operands.le', KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, cups),
    why_texts(KB, SM, h, Texts),
    assertion(Texts \== []),
    assertion(( member(T, Texts), sub_string(T, 0, _, _, "the double of") )),
    assertion(\+ ( member(T, Texts), sub_string(T, _, _, _, "the_double_of") )).

:- end_tests(function_operands).

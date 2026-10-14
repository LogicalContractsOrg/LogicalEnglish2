/*  "the minimum (maximum) of A and B is C" with a calculation for A or B:
    the argument reaches the built-in as an expression (N-1) and is worked
    out. Until 14 October 2026 the goal failed, silently, and a rule using it
    gave no answer (found writing the UK legal-aid means test and Portugal's
    Prestação Social Única).
*/
:- use_module('../le_kbs').

:- begin_tests(min_max_calculation).

answers(Text, QName, Answers) :-
    load_text(Text, KB),
    createSession(KB, SM), setScenarion(SM, s),
    KB:query_info(QName, G, _),
    findall(G, reasoner:i(G, SM, _, _), Answers),
    destroySession(SM).

test(minimum_of_a_calculation) :-
    answers("the target language is: prolog.
the templates are:
    the capped value of *a number* is *a value*.
the knowledge base m includes:
the capped value of a number N is a value V if the minimum of N - 1 and 10 is V.
scenario s is:
    the capped value of 0 is 0.
query q is:
    the capped value of 5 is which value.
", q, As),
    assertion(As = [the_capped_value_of_is(5, 4)]).

test(maximum_of_two_calculations) :-
    answers("the target language is: prolog.
the templates are:
    the floor value of *a number* is *a value*.
the knowledge base m includes:
the floor value of a number N is a value V if the maximum of N * 2 and N + 10 is V.
scenario s is:
    the floor value of 0 is 0.
query q is:
    the floor value of 3 is which value.
", q, As),
    assertion(As = [the_floor_value_of_is(3, 13)]).

test(plain_numbers_unchanged) :-
    reasoner:le_minimum(3, 7, Z), assertion(Z == 3),
    assertion(\+ reasoner:le_minimum(3, 7, 4)),
    assertion(reasoner:le_maximum(3, 7, 7)).

:- end_tests(min_max_calculation).

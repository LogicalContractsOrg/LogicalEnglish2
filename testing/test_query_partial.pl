/** <module> A query stopped by its time limit keeps the answers it found

    le_api.pl, run_interruptible_query/5: each answer is kept as it is found,
    and a query its time limit stops replies with them, marked `incomplete`,
    so that the editor shows them with a "Keep going" button (a longer
    `timeLimit`, query_time_limit/2).

    Run with:  swipl -q -g run_tests -t halt testing/test_query_partial.pl
*/

:- module(test_query_partial, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_api').

%   64,000 answers, each found at once and none deep: the query cannot
%   finish within its second, whatever the machine.
endless("the target language is: prolog.

the templates are:
    *a number*, *a second number* and *a third number* make a triple.

the knowledge base endless includes:

a number N, a second number M and a third number K make a triple if
    N is in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39]
    and M is in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39]
    and K is in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39].

query naturals is:
    which number, which second number and which third number make a triple.
").

:- begin_tests(query_partial).

test(stopped_query_keeps_its_answers) :-
    endless(T), le_kbs:load_text(T, KB), le_kbs:createSession(KB, SM),
    le_api:run_interruptible_query(SM, naturals, KB, 1, R),
    assertion(get_dict(incomplete, R, true)),
    assertion(get_dict(timedOut, R, true)),
    get_dict(results, R, Rs),
    assertion(Rs = [_, _|_]),
    Rs = [First|_],
    assertion(get_dict(answer, First, _)).

test(time_limit_from_the_request) :-
    le_api:query_time_limit(_{}, D), assertion(D == 240),
    le_api:query_time_limit(_{timeLimit: 480}, L), assertion(L == 480),
    le_api:query_time_limit(_{timeLimit: 999999}, M), assertion(M == 1800),
    le_api:query_time_limit(_{timeLimit: 480, debug: true}, X), assertion(X == 3600).

:- end_tests(query_partial).

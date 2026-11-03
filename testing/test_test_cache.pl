/* test_test_cache.pl — a test's result is kept in the program's module, so
   that the tests the load ran for the verifier are not run again, and a
   test runs without the proof's per-call records. */

:- use_module(library(plunit)).
:- use_module('../le_kbs').

cache_program("the target language is: prolog.

the templates are:
    *a person* is rich; undefined.
    *a person* is happy.

the knowledge base k includes:

a person is happy
    if the person is rich.

scenario s is:
    ann is rich.
    q expects answers [\"ann is happy\"].

query q is:
    which person is happy.
").

:- begin_tests(test_cache).

test(kept_and_reused) :-
    cache_program(T),
    le_kbs:load_text(T, KB),
    findall(test(Q, S, A, U), KB:le_expected(Q, S, A, U), [Test]),
    le_kbs:run_one_test(KB, Test, R1),
    assertion(R1 = pass(_, _)),
    assertion(KB:le_test_result(Test, pass(_, _), _)),
    le_kbs:run_one_test(KB, Test, R2, Got),
    assertion(R2 == R1),
    assertion(Got \== none),
    current_prolog_flag(le_failure_explanations, FE),
    assertion(FE == true).

:- end_tests(test_cache).

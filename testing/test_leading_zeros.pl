/* test_leading_zeros.pl — a number written with leading zeros inside a name
   keeps them: claim SYN-01-C1 stays SYN-01-C1, in a scenario's name, in a
   fact's argument and in an answer, so that an expectation naming it can be
   met. A number with thousands separators is still a number. */

:- use_module(library(plunit)).
:- use_module('../le_kbs').

lz_program("the target language is: prolog.

the templates are:
    *a claim* is open.
    *a claim* is for *an amount*.

the knowledge base k includes:

scenario SYN-01-C1 is:
    claim SYN-01-C1 is open.
    claim SYN-01-C1 is for 1000.
    q expects answers [\"claim SYN-01-C1 is open\"].
    r expects answers [\"claim SYN-01-C1 is for 1000\"].

query q is:
    which claim is open.

query r is:
    which claim is for which amount.
").

:- begin_tests(leading_zeros).

test(names_keep_their_zeros) :-
    lz_program(P),
    load_text(P, KB),
    findall(Q-S-A, KB:le_expected(Q, S, A, _), Ts),
    Ts \== [],
    forall(member(Q-S-A, Ts),
           ( le_kbs:run_one_test(KB, test(Q, S, A, []), R),
             assertion(R = pass(_, _)) )).

test(width) :-
    tokenizer:leading_zeros_width(1, 10, 12, W), assertion(W == 2),
    \+ tokenizer:leading_zeros_width(1000, 0, 5, _),     % 1,000
    \+ tokenizer:leading_zeros_width(12, 0, 2, _).

:- end_tests(leading_zeros).

/* A variable named A at the start of an expression (`P = A - 2000`) is the
   variable, not the article "A". */
var_a_program("the target language is: prolog.

the templates are:
    the loss of *a claim* is *an amount*.
    the net of *a claim* is *an amount*.

the knowledge base k includes:

the net of a claim is an amount P
    if the loss of the claim is an amount A
    and P = A - 2000.

scenario s is:
    the loss of claim one is 12500.
    q expects answers [\"the net of claim one is 10500\"].

query q is:
    the net of which claim is which amount.
").

:- begin_tests(variable_a).

test(a_starts_an_expression) :-
    var_a_program(P),
    load_text(P, KB),
    KB:le_expected(Q, S, A, U),
    le_kbs:run_one_test(KB, test(Q, S, A, U), R),
    assertion(R = pass(_, _)).

:- end_tests(variable_a).

/** <module> An assumable `; one value` template is not assumed beside a proved value

    When the facts or rules prove a value for the question of a template
    that is both assumable and `; one value` (the colour of the car), a call
    with the value still open does not also assume another value. Without
    this, each such call opened one branch per value that the rules could
    use, and each negation over those branches multiplied them: a customs
    product with two such templates ran out of memory.

    Run with:  swipl -q -g run_tests -t halt testing/test_one_value_assumable.pl
*/

:- module(test_one_value_assumable, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

program(Additions, P) :-
    format(string(P), "the target language is: prolog.

the templates are:
    the colour of *a car* is *a colour*~w.
    the paint of *a car* is *a colour*.
    *a car* is cheap in *a colour*.

the knowledge base k includes:

the colour of a car is a colour if
    the paint of the car is the colour.

a car is cheap in a colour if
    the colour of the car is the colour
    and the colour is in [red, blue].

scenario stated is:
    the colour of car1 is red.

scenario derived is:
    the paint of car1 is red.

scenario none is:
    the paint of car2 is red.

query q is:
    car1 is cheap in which colour.
", [Additions]).

% the answers: each colour with the number of unknowns it needs
answers(Additions, Scenario, Answers) :-
    program(Additions, P),
    le_kbs:load_text(P, test_one_value_assumable, KB),
    createSession(KB, SM), setScenarion(SM, Scenario),
    findall(C-N, ( query(SM, q, Inst, Us, _), last(Inst, C0),
                   ( var(C0) -> C = '_' ; C = C0 ), length(Us, N) ), Answers0),
    sort(Answers0, Answers),
    destroySession(SM).

:- begin_tests(one_value_assumable).

test(stated_value_closes_the_question) :-
    answers("; one value; assumable", stated, As),
    assertion(As == [red-0]).

test(derived_value_closes_the_question) :-
    answers("; one value; assumable", derived, As),
    assertion(As == [red-0]).

test(open_question_is_still_assumed) :-
    answers("; one value; assumable", none, As),
    assertion(As == [blue-1, red-1]).

test(without_one_value_other_values_stay_open) :-
    answers("; assumable", stated, As),
    assertion(memberchk(red-0, As)),
    assertion(memberchk(blue-1, As)).

:- end_tests(one_value_assumable).

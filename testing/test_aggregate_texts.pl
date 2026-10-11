/** <module> The maximum and the minimum of texts

    `the maximum of each X such that ...` over values that are not all
    numbers (a household's state code, the same for every member) is the
    greatest in the standard order of terms. It used max_list/2, which read
    a text of one letter as its character code and stopped at a text of two
    ("CA", PolicyEngine's SNAP twin).

    Run with:  swipl -q -g run_tests -t halt testing/test_aggregate_texts.pl
*/

:- module(test_aggregate_texts, []).

:- use_module(library(plunit)).
:- use_module('../reasoner').

:- begin_tests(aggregate_texts).

test(numbers_as_before) :-
    reasoner:apply_aggregate(max, [3, 7.5, 2], Max), Max =:= 7.5,
    reasoner:apply_aggregate(min, [3, 7.5, 2], Min), Min =:= 2.

test(texts_in_standard_order) :-
    reasoner:apply_aggregate(max, ["CA", "CA"], Max), Max == "CA",
    reasoner:apply_aggregate(min, ["NY", "CA"], Min), Min == "CA".

test(nothing_has_no_maximum, [fail]) :-
    reasoner:apply_aggregate(max, [], _).

:- end_tests(aggregate_texts).

/** <module> lib/feel.le — FEEL's built-in functions the other libraries lack (E7)

    lpsPlus/docs/migration/roadmap.md, Phase 4: the DMN translator writes
    FEEL's built-in functions as templates of the shared libraries; this one
    has what lib/text, lib/rounding, lib/temporal and lib/maths do not. Also
    the comparison of an expected number given to more digits than a float
    keeps (le_kbs:answers_match/2).

    Run with:  swipl -q -g run_tests -t halt testing/test_feel_lib.pl
*/

:- module(test_feel_lib, []).

:- use_module(library(plunit)).
:- use_module(library(filesex)).
:- use_module('../le_kbs').
:- use_module('../le_migration').

:- consult('../lib/feel.pl').

:- begin_tests(feel_lib_prolog).

test(lists, [nondet]) :-
    the_item_at_position_of_the_list_is(-1, [a, b, c], A), assertion(A == c),
    \+ the_item_at_position_of_the_list_is(4, [a, b, c], _),
    the_median_of_the_list_is([3, 1, 2], M), assertion(M == 2),
    the_list_of_the_distinct_values_of_is([1, 2, 1, 3], D), assertion(D == [1, 2, 3]),
    the_flattening_of_the_list_is([1, [2, [3]]], F), assertion(F == [1, 2, 3]),
    the_list_with_inserted_at_position_is([1, 3], 2, 2, I), assertion(I == [1, 2, 3]),
    the_list_of_the_positions_of_in_is(x, [x, y, x], P), assertion(P == [1, 3]).

%   FEEL's all() and any() have three values: null where an item is not a
%   truth, and a single value counts as a list of one.
test(three_valued_all_any, [nondet]) :-
    the_conjunction_of_the_list_is([true, false], A), assertion(A == false),
    the_conjunction_of_the_list_is([], B), assertion(B == true),
    \+ the_conjunction_of_the_list_is([true, 123], _),
    the_disjunction_of_the_list_is(true, C), assertion(C == true).

test(rounding_modes, [nondet]) :-
    the_rounding_of_away_from_zero_to_decimals_is(-1.121, 2, A), assertion(A =:= -1.13),
    the_rounding_of_toward_zero_to_decimals_is(-1.129, 2, B), assertion(B =:= -1.12),
    the_rounding_of_to_decimals_half_toward_zero_is(1.125, 2, C), assertion(C =:= 1.12).

test(texts_and_dates, [nondet]) :-
    the_part_of_after_is("foobar", "o", A), assertion(A == "obar"),
    the_part_of_before_is("foobar", "z", B), assertion(B == ""),
    the_date_written_as_is("2020-01-31", D), assertion(D == date(2020, 1, 31)),
    the_date_written_as_is(date(2020, 1, 31), E), assertion(E == date(2020, 1, 31)).

:- end_tests(feel_lib_prolog).

:- begin_tests(feel_lib_le).

test(included_library_answers, [setup(tmp_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    copy_library(feel, Dir),
    atomic_list_concat([Dir, '/uses_feel.le'], File),
    copy_file('testing/fixtures/feel/uses_feel.le', File),
    le_kbs:runTestsFor(File, test_file(_, Results)),
    assertion(Results = [_, _, _]),
    assertion(forall(member(R, Results), R = pass(_, _))).

tmp_dir(Dir) :- tmp_file(feel, Dir), make_directory(Dir).

:- end_tests(feel_lib_le).

:- begin_tests(decimal_answers).

%   The DMN TCK's 2778.69354943277 (34-digit decimals) against the float LE
%   computes, 2778.693549432746: equal within a relative 1e-12; a real
%   difference still is one.
test(float_noise_beyond_fifteen_digits) :-
    assertion(le_kbs:answers_match(["the payment is 2778.69354943277"], ["the payment is 2778.693549432746"])),
    assertion(\+ le_kbs:answers_match(["the payment is 2778.69354943277"], ["the payment is 2778.69354"])).

:- end_tests(decimal_answers).

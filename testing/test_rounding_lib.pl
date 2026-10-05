/** <module> lib/rounding.le — rounding at a number of decimals (N8)

    lpsPlus/docs/migration/roadmap.md §7.5: rounding half up, half even
    (banker's), down, up and to the nearest step, at a number of decimals,
    exactly; a library the migrations share (RuleSpec, Catala, RegelSpraak),
    not syntax. Also the way an answer shows a number: the noise of binary
    floating point is not shown (le_kbs:number_locale_atom/2), and an
    expectation compares numbers as numbers (30 is 30.0).

    Run with:  swipl -q -g run_tests -t halt testing/test_rounding_lib.pl
*/

:- module(test_rounding_lib, []).

:- use_module(library(plunit)).
:- use_module(library(filesex)).
:- use_module(library(pcre)).
:- use_module('../le_kbs').
:- use_module('../le_migration').

:- consult('../lib/rounding.pl').

:- begin_tests(rounding_lib_prolog).

test(half_up_is_exact, [nondet]) :-
    le_rounding_half_up(2.675, 2, A), assertion(A =:= 2.68),
    le_rounding_half_up(-2.675, 2, B), assertion(B =:= -2.68),
    le_rounding_half_up(1234.5, 0, C), assertion(C == 1235),
    le_rounding_half_up(1234.5, -1, D), assertion(D == 1230).

test(half_even, [nondet]) :-
    le_rounding_half_even(2.5, 0, A), assertion(A == 2),
    le_rounding_half_even(3.5, 0, B), assertion(B == 4),
    le_rounding_half_even(0.125, 2, C), assertion(C =:= 0.12),
    le_rounding_half_even(0.135, 2, D), assertion(D =:= 0.14).

test(down_up_nearest, [nondet]) :-
    le_rounding_down(-2.675, 2, A), assertion(A =:= -2.68),
    le_rounding_up(1.001, 2, B), assertion(B =:= 1.01),
    le_rounding_nearest(7.3, 0.25, C), assertion(C =:= 7.25),
    le_rounding_nearest(14, 10, D), assertion(D == 10).

:- end_tests(rounding_lib_prolog).

:- begin_tests(rounding_lib_le).

test(included_library_answers, [setup(tmp_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    copy_library(rounding, Dir),
    atomic_list_concat([Dir, '/uses_rounding.le'], File),
    copy_file('testing/fixtures/rounding/uses_rounding.le', File),
    le_kbs:runTestsFor(File, test_file(_, Results)),
    assertion(Results = [_, _, _, _, _]),
    assertion(forall(member(R, Results), R = pass(_, _))).

%   The resource written with its extension, `rounding.le.`, as
%   language.md §14 allows (it used to be looked for as rounding.le.le).
test(include_written_with_extension, [setup(tmp_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    copy_library(rounding, Dir),
    read_file_to_string('testing/fixtures/rounding/uses_rounding.le', T0, []),
    re_replace("    rounding\\."/m, "    rounding.le.", T0, T),
    atomic_list_concat([Dir, '/with_extension.le'], File),
    setup_call_cleanup(open(File, write, O), write(O, T), close(O)),
    le_kbs:runTestsFor(File, test_file(_, Results)),
    assertion(Results = [_, _, _, _, _]),
    assertion(forall(member(R, Results), R = pass(_, _))).

tmp_dir(Dir) :- tmp_file(rounding, Dir), make_directory(Dir).

:- end_tests(rounding_lib_le).

:- begin_tests(number_display).

test(float_noise_is_not_shown) :-
    X is 386.5 * 0.3, le_kbs:number_locale_atom(X, A), assertion(A == '115.95'),
    Y is 3400.0000000000005, le_kbs:number_locale_atom(Y, B), assertion(B == '3400.0'),
    Z is 1 / 3, le_kbs:number_locale_atom(Z, C), assertion(C == '0.3333333333333333'),
    le_kbs:number_locale_atom(3.0, D), assertion(D == '3.0'),
    le_kbs:number_locale_atom(2256.46, E), assertion(E == '2256.46').

%   floor of a whole number blurred by binary floating point (1920 * 1.025
%   / 12 is 163.99999999999997) is that whole number, as in decimal.
test(floor_of_float_noise) :-
    reasoner:call_reasoner_built_in(le_assign(A, floor(1920 * 1.025 / 12) * 12), _), assertion(A =:= 1968),
    reasoner:call_reasoner_built_in(le_assign(B, ceiling(0.1 * 3 * 10)), _), assertion(B =:= 3),
    reasoner:call_reasoner_built_in(le_assign(C, floor(2.7)), _), assertion(C =:= 2).

test(expected_numbers_compare_as_numbers) :-
    le_kbs:normalize_string("the pay of ann is 30.0", A),
    le_kbs:normalize_string("the pay of ann is 30", B),
    assertion(A == B),
    le_kbs:normalize_string("the rate is 1.50", C),
    le_kbs:normalize_string("the rate is 1.5", D),
    assertion(C == D).

:- end_tests(number_display).

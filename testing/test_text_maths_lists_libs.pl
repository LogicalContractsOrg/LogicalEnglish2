/*  Tests of lib/text, lib/maths and lib/lists (docs/user/reference/language.md
    §14.2), and of the comparison of an expected number written with decimals
    (§12): what the translators of other rule systems lean on (Oracle
    Intelligent Advisor's joined texts, `Contains`, powers, chains of
    instances, amounts to the cent).

    ./myswipl.sh -q -g run_tests -t halt testing/test_text_maths_lists_libs.pl
*/

:- use_module(library(plunit)).
:- use_module(library(filesex)).
:- use_module('../le_kbs').
:- use_module('../le_migration').

:- begin_tests(text_maths_lists_libs).

%   A program including the libraries, copied beside it as the translators do.
test(included_libraries_answer, [setup(tmp_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    forall(member(L, [text, maths, lists]), copy_library(L, Dir)),
    atomic_list_concat([Dir, '/uses_text_maths_lists.le'], File),
    copy_file('testing/fixtures/libraries/uses_text_maths_lists.le', File),
    le_kbs:runTestsFor(File, test_file(_, Results)),
    assertion(Results = [_, _, _, _]),
    assertion(forall(member(R, Results), R = pass(_, _))).

test(text_of_number_without_point_zero) :-
    consult_lib(text),
    text:the_text_of_is(70.0, S1), assertion(S1 == "70"),
    text:the_joining_of_is(["a", 1, 2.5, date(2026, 10, 5)], S2), assertion(S2 == "a12.52026-10-05").

test(expected_decimals_match_rounded_answer) :-
    assertion(le_kbs:answers_match(["x is 2398.2"], ["x is 2398.2021006110276"])),
    assertion(\+ le_kbs:answers_match(["x is 2398.3"], ["x is 2398.2021006110276"])),
    assertion(\+ le_kbs:answers_match(["x is 2398"], ["x is 2398.2021006110276"])).

tmp_dir(Dir) :- tmp_file(libs, Dir), make_directory(Dir).

consult_lib(L) :-
    atomic_list_concat(['lib/', L, '.pl'], F),
    load_files(L:F, [if(not_loaded)]).

:- end_tests(text_maths_lists_libs).

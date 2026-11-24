/** <module> Tests of the Blawx -> LE translator (Phase 2c)

    Run from the LE2 checkout (/work), after fetch_sources.sh:

        ./myswipl.sh -q -g run_tests -t halt migration/blawx/test_blawx.pl

    The oracle's answers are read from runs/ (build.pl writes them), so the
    tests need neither Python nor the network once the twins are built.
*/

:- module(test_blawx, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(blawx_reader).
:- use_module(blawx_twin).
:- use_module(blawx_import).
:- use_module(le2(le_kbs)).
:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).

:- use_module('../le2_paths', [twins_dir/2]).
:- prolog_load_context(directory, D), retractall(dir(_)), assertz(dir(D)).
:- dynamic dir/1.

example(Id, F) :- dir(D), format(atom(F), '~w/.cache/blawx/blawx/static/blawx/examples/~w.yaml', [D, Id]).
%   The fetched sources of Blawx (fetch_sources.sh): the tests that read one
%   of its example projects are skipped without it.
fetched(Id) :- example(Id, F), exists_file(F).
twin_file(Id, F) :-
    twins_dir(blawx, Root),
    format(atom(F), '~w/~w/~w.le', [Root, Id, Id]).

:- begin_tests(blawx_reader).

test(sections_and_locators) :-
    assertion(section_locator(sec_34__subsec_1__para_b__subpara_i_section, 'section 34(1)(b)(i)')),
    assertion(section_constant(sec_34__subsec_1__para_b_section, section_34_1_b)),
    assertion(section_locator(sec_5__span_pingu_section, 'section 5, the words "pingu"')),
    assertion(section_constant(sec_5__span_pingu_section, section_5_pingu)).

test(reads_a_project, [condition(fetched(bird))]) :-
    example(bird, F),
    blawx_project(F, project(Title, _, Text, Sections, Tests)),
    assertion(Title == "New Bird Act"),
    assertion(sub_string(Text, _, _, _, "Penguins are birds.")),
    length(Sections, NS), assertion(NS =:= 8),
    length(Tests, NT), assertion(NT =:= 4),
    memberchk(section(sec_3_section, Cs), Sections),
    assertion(( member(c((H :- _), _, _), Cs), H =.. [according_to, sec_3_section, -(flies)|_] )).

test(generator_typos_are_marked, [condition(fetched(rps))]) :-   % Blawx wrote `-throwA,B,C)` in rps
    example(rps, F), blawx_project(F, project(_, _, _, Sections, _)),
    assertion(( member(section(_, Cs), Sections), member(c(syntax_error(_), _, _), Cs) )).

:- end_tests(blawx_reader).

:- begin_tests(blawx_twins).

%   The Bird Act: the defeats written as rules under their sections.
test(bird_defeasibility) :-
    twin_file(bird, F), read_file_to_string(F, S, []),
    assertion(sub_string(S, _, _, _, "it is not the case that the thing cannot fly under section_3")),
    assertion(sub_string(S, _, _, _, "a thing cannot fly under section_3 if")),
    assertion(sub_string(S, _, _, _, "*a thing* can fly; opposite: *a thing* cannot fly.")).

%   Blawx's possessive "X 's facial hair" is LE's "the facial hair of X";
%   a relationship's places follow its sentence, not Blawx's argument order.
test(wording) :-
    twin_file(beard_tax, F1), read_file_to_string(F1, S1, []),
    assertion(sub_string(S1, _, _, _, "the facial hair of *a person* is *a number* mm in length")),
    twin_file(covid_test, F2), read_file_to_string(F2, S2, []),
    assertion(sub_string(S2, _, _, _, "the person took a covid test the test")).

%   Every twin loads, and its Blawx tests and generated cases pass.
test(twins_pass) :-
    forall(member(Id, [beard_tax, bird, covid_test, life_act, list_demo, logical_constraints, mortality,
                       net30, numerical_constraints, oasa, r34, rps, siblings, wills, wills_tutorial]),
           ( twin_file(Id, F),
             le_kbs:runTestsFor(F, test_file(_, Rs)),
             assertion(( forall(member(R, Rs), functor(R, pass, _)) -> true ; print(Id-Rs), nl, fail )) )).

:- end_tests(blawx_twins).

:- begin_tests(blawx_import).

test(detects_projects, [condition(fetched(wills))]) :-
    example(wills, F), assertion(detect_blawx(F)),
    dir(D), format(atom(Not), '~w/README.md', [D]), assertion(\+ detect_blawx(Not)).

%   (its expected answers are s(CASP)'s, asked when the project is opened:
%   skipped where the `scasp` pack is not installed)
test(import_a_project, [condition(( fetched(wills), exists_source(library(scasp)) )), setup(tmp(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    example(wills, F),
    import_blawx(F, Dir, imported(LE, Notes)),
    assertion(file_base_name(LE, 'wills.le')),
    assertion(Notes \== []),
    le_kbs:runTestsFor(LE, test_file(_, Rs)),
    assertion(Rs \== []),
    assertion(forall(member(R, Rs), functor(R, pass, _))).

%   A server whose SWI-Prolog has no s(CASP) cannot run Blawx's reasoner:
%   the note says so (not only "0 pass, 0 fail"), and no failed run is kept
%   as Blawx's answers.
test(no_scasp_warns, [condition(fetched(wills)),
                      setup(( tmp(Dir), no_scasp_swipl(Dir, Old) )),
                      cleanup(( restore_swipl(Old), delete_directory_and_contents(Dir) ))]) :-
    example(wills, F),
    format(atom(Out), '~w/out', [Dir]), make_directory(Out),
    import_blawx(F, Out, imported(_, Notes)),
    assertion(( member(N, Notes), sub_string(N, _, _, _, "no s(CASP) library") )),
    format(atom(Runs), '~w/sources/blawx_answers/wills.json', [Out]),
    assertion(\+ exists_file(Runs)).

no_scasp_swipl(Dir, Old) :-
    ( getenv('SWIPL', O) -> Old = O ; Old = none ),
    format(atom(Fake), '~w/swipl_without_scasp', [Dir]),
    setup_call_cleanup(open(Fake, write, S), format(S, "#!/bin/sh~nexit 1~n", []), close(S)),
    chmod(Fake, +x),
    setenv('SWIPL', Fake).

restore_swipl(none) :- !, unsetenv('SWIPL').
restore_swipl(Old) :- setenv('SWIPL', Old).

tmp(Dir) :- tmp_file(bxi, Dir), make_directory(Dir).

:- end_tests(blawx_import).

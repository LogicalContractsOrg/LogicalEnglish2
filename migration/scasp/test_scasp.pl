/** <module> Tests of the s(CASP) -> LE translator (Phase 2c)

    Run from the LE2 checkout (/work):

        ./myswipl.sh -q -g run_tests -t halt migration/scasp/test_scasp.pl
*/

:- module(test_scasp, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(scasp_source).
:- use_module(scasp_twin).
:- use_module('../le2_paths', []).
:- use_module(scasp_import).
:- use_module(corpus).
:- use_module(le2(le_kbs)).

:- begin_tests(scasp_source).

%   s(CASP) itself (SWI-Prolog's `scasp` pack) reads the source and is the
%   oracle: the tests that need it are skipped where it is not installed.
scasp_installed :- exists_source(library(scasp)).

le1_file(Name, F) :- scasp_test_dir(T), atomic_list_concat([T, '/le_programs/', Name], F).

test(le1_scenarios_in_comments_and_live, [condition(scasp_installed)]) :-
    le1_file('citizenshiptrust-scasp.pl', F), read_source(F, source(_, Sc, Q)),
    assertion(length(Sc, 4)), assertion(Q = [_]),
    le1_file('loanwithcure-scasp.pl', F2), read_source(F2, source(P2, [scenario(payment, Fs)], _)),
    assertion(Fs = [_, _, _]),
    assertion(\+ ( member(T-_, P2), T = pays_to_on(_, _, _, _) )).      % the live scenario's facts are the scenario's

%   clingo-only statements are kept, with their text and line, as what
%   s(CASP) does not have — never read as sentences, never dropped.
test(clingo_statements_are_not_scasp, [setup(tmp_file_stream(text, F, S)), cleanup(delete_file(F))]) :-
    format(S, "p(1).~n{a;b}.~n% a comment~nc :- a.~n1 { q(X) : p(X) } 1.~n:~~ p. [1@1]~n#const n = 3.~nx(1..n).~na ; b :- c.~n#show a/0.~nd :- not c.~n", []),
    close(S),
    read_source(F, source(P, _, _)),
    findall(K-L-T, member('$not_scasp'(K, T, L)-_, P), Ns),
    assertion(Ns == [clingo-2-"{a;b}.", unreadable-5-"1 { q(X) : p(X) } 1.", unreadable-6-":~ p. [1@1]",
                     unreadable-7-"#const n = 3.", unreadable-8-"x(1..n).", clingo-9-"a ; b :- c."]),
    assertion(memberchk((c :- a)-_, P)),
    assertion(memberchk((d :- not(c))-_, P)).

test(le1_metadata_is_not_program, [condition(scasp_installed)]) :-
    le1_file('family-le-scasp.pl', F), read_source(F, source(P, _, _)),
    assertion(\+ member(source_lang(_)-_, P)).

:- end_tests(scasp_source).

:- begin_tests(scasp_oracle).

scasp_installed :- exists_source(library(scasp)).

test(scasp_answers_on_the_source, [condition(scasp_installed)]) :-
    oracle_answers([p(a)-[], p(b)-[], (q(X) :- p(X), not(r(X)))-[], r(b)-[]], [], [q(_)], [A]),
    assertion(A == answers([q(a)])).

:- end_tests(scasp_oracle).

:- begin_tests(scasp_twins).

twins_dir(D) :- le2_paths:twins_dir(scasp, D).
scasp_installed :- exists_source(library(scasp)).

%   Every twin of the corpus reproduces s(CASP)'s answers on its source.
test(twins_pass, [forall(( twins_dir(D), directory_files(D, Es), member(E, Es),
                           \+ sub_atom(E, 0, _, _, '.'),
                           atomic_list_concat([D, '/', E, '/', E, '.le'], F), exists_file(F) ))]) :-
    le_kbs:runTestsFor(F, test_file(_, Rs)),
    assertion(forall(member(R, Rs), functor(R, pass, _))).

test(file_open_adapter, [condition(scasp_installed), setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    atomic_list_concat([D, '/in.pl'], F),
    setup_call_cleanup(open(F, write, S),
        format(S, "#pred bird(X) :: '@(X:animal) is a bird'.~nbird(tweety).~nflies(X) :- bird(X), not penguin(X).~npenguin(sam).~nbird(sam).~n?- flies(X).~n", []),
        close(S)),
    assertion(detect_scasp(F)),
    atomic_list_concat([D, '/out'], O), make_directory(O),
    import_scasp(F, O, imported(LE, _)),
    le_kbs:runTestsFor(LE, test_file(_, Rs)),
    assertion(Rs = [pass(_, _)]).

%   A denial is an LE integrity constraint, and LE answers as s(CASP) does:
%   nothing from a case whose facts meet it (bob has two ages), and no answer
%   that would assume what meets it (ann's age may be assumed, but not a
%   second one).
test(denials_are_constraints, [condition(scasp_installed), setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    atomic_list_concat([D, '/in.pl'], F),
    setup_call_cleanup(open(F, write, S),
        format(S, "#pred age(X, N) :: '@(X:person) is @(N:number) years of age'.~n#pred adult(X) :: '@(X:person) is an adult'.~nage(bob, 40).~nage(bob, 50).~nadult(X) :- age(X, N), N #>= 18.~n:- age(X, A), age(X, B), A #<> B.~n?- adult(X).~n", []),
        close(S)),
    atomic_list_concat([D, '/out'], O), make_directory(O),
    import_scasp(F, O, imported(LE, _)),
    read_file_to_string(LE, Text, []),
    assertion(sub_string(Text, _, _, _, "it must not be true that")),
    assertion(\+ sub_string(Text, _, _, _, "denial_")),
    le_kbs:runTestsFor(LE, test_file(_, Rs)),
    assertion(Rs = [pass(_, _)]),
    assertion(sub_string(Text, _, _, _, "expects answers []")).

%   A clingo program (`.lp`): its choice rules and other clingo-only
%   statements are residue blocks, counted, and the twin loads — not a
%   sentence `a;b is a { }` LE cannot read.
test(clingo_syntax_is_residue, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    atomic_list_concat([D, '/in.lp'], F),
    setup_call_cleanup(open(F, write, S),
        format(S, "p(1).~n{a;b}.~nc :- a.~n1 { q(X) : p(X) } 1.~nd :- not c.~n?- d.~n", []),
        close(S)),
    assertion(detect_scasp(F)),
    atomic_list_concat([D, '/out'], O), make_directory(O),
    import_scasp(F, O, imported(LE, [Note|_])),
    read_file_to_string(LE, Text, []),
    assertion(\+ sub_string(Text, _, _, _, "is a {")),
    assertion(sub_string(Text, _, _, _, "% RESIDUE not_scasp_1 BEGIN")),
    assertion(sub_string(Text, _, _, _, "%   | {a;b}.")),
    assertion(sub_string(Text, _, _, _, "% RESIDUE not_scasp_2 BEGIN")),
    assertion(sub_string(Note, _, _, _, " 2 residue; 0 writer errors")).

%   Without s(CASP) on the server nothing is checked, and the notes say so.
test(no_scasp_warns, [setup(( tmp_dir(D), no_scasp_swipl(D, Old) )),
                      cleanup(( restore_swipl(Old), delete_directory_and_contents(D) ))]) :-
    atomic_list_concat([D, '/in.pl'], F),
    setup_call_cleanup(open(F, write, S), format(S, "p(a).~nq(X) :- p(X).~n?- q(X).~n", []), close(S)),
    atomic_list_concat([D, '/out'], O), make_directory(O),
    import_scasp(F, O, imported(_, Notes)),
    assertion(( member(N, Notes), sub_string(N, _, _, _, "1 expectation(s) are pending") )),
    assertion(( member(N2, Notes), sub_string(N2, _, _, _, "s(CASP) is not installed") )).

no_scasp_swipl(Dir, Old) :-
    ( getenv('SWIPL', O) -> Old = O ; Old = none ),
    atomic_list_concat([Dir, '/swipl_without_scasp'], Fake),
    setup_call_cleanup(open(Fake, write, S), format(S, "#!/bin/sh~nexit 1~n", []), close(S)),
    chmod(Fake, +x),
    setenv('SWIPL', Fake).

restore_swipl(none) :- !, unsetenv('SWIPL').
restore_swipl(Old) :- setenv('SWIPL', Old).

tmp_dir(D) :- tmp_file(scasp, D), make_directory(D).

:- end_tests(scasp_twins).

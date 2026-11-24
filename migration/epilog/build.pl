/*  Build the Epilog twins: the rulesets into LE2's examples/migration/epilog/,
    the programs with operations and the games into LPS2's (le2_paths.pl,
    epilog_twin:twin_dir/4).

    From an LE2 checkout, after ./fetch_sources.sh (EpilogJS and the Epilog
    site's texts, into .cache/), with LPS2 beside LE2 or named by
    LPS2_DIR:

        swipl migration/epilog/build.pl              # every twin (corpus.pl)
        swipl migration/epilog/build.pl -- tictactoe

    Needs node (EpilogJS is the oracle: the rulesets' expected answers, the
    plays and final states).
*/

:- initialization(main, main).

:- use_module(library(main)).
:- use_module(library(apply)).
:- use_module(epilog_twin).
:- use_module(corpus).

main(Argv) :-
    (   Argv == []
    ->  findall(theory-Id, theory(Id, _), Ts), findall(program-Id, program(Id, _, _), Ps),
        findall(game-Id, game(Id, _, _), Gs), append([Ts, Ps, Gs], Jobs)
    ;   findall(K-Id, ( member(A, Argv), atom_string(Id, A), kind(Id, K) ), Jobs)
    ),
    forall(member(K-Id, Jobs),
           ( format("~w ... ", [Id]), flush_output,
             catch(( build(K, Id, report(F, Issues, Counts, Fid)),
                     include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
                     ( Fid = fidelity(P, Fa, U, _) -> true ; P = '-', Fa = '-', U = '-' ),
                     format("~w  ~w  pass ~w fail ~w error ~w  ~w writer error(s)~n", [F, Counts, P, Fa, U, NE]) ),
                   E, print_message(error, E)) )).

kind(Id, theory) :- theory(Id, _), !.
kind(Id, program) :- program(Id, _, _), !.
kind(_, game).

build(theory, Id, Report) :-
    theory(Id, Title), theory_files(Id, R, D), source_url(theory, Id, U),
    build_theory(Id, [rules(R), data(D), title(Title), source("the Epilog Examples page", U)], Report).
build(program, Id, Report) :-
    program(Id, Title, Ops), program_files(Id, L, D), source_url(program, Id, U),
    build_game(Id, [library(L), data(D), operations(Ops), title(Title), source("the Epilog Examples page", U)], Report).
build(game, Id, Report) :-
    game(Id, Title, N), game_file(Id, F), source_url(game, Id, U),
    build_game(Id, [library(F), moves(N), title(Title), source("the Epilog Games page", U)], Report).

/*  Build the Drools twins into lps2/examples/migration/drools (le2_paths:twins_dir/2).

    From /work (the LE2 checkout):

        ./myswipl.sh -q migration/drools/build.pl             # every case
        ./myswipl.sh -q migration/drools/build.pl -- fire_alarm

    Needs the oracle built (oracle/: mvn -q package), the fact model compiled
    (./compile_model.sh) and LPS2 (its lps_drools.pl reads the DRL).
*/

:- initialization(main, main).

:- use_module('../le2_paths', [twins_dir/2]).

:- prolog_load_context(directory, D),
   twins_dir(drools, Out),
   asserta(user:drools_out_dir(Out)).

:- use_module(library(main)).
:- use_module(drl_twin).
:- use_module(corpus).

main(Argv) :-
    user:drools_out_dir(Out),
    make_directory_path(Out),
    (   Argv == [] -> findall(Id, case(Id, _), Ids) ; maplist([A, I]>>atom_string(I, A), Argv, Ids) ),
    forall(member(Id, Ids),
           ( case(Id, Opts),
             format("~w ... ", [Id]), flush_output,
             catch(( build_case(case(Id, Opts), Out, report(Files, Reports)),
                     forall(( nth1(I, Files, F), nth1(I, Reports, report(_, Issues, Counts, Fid)) ),
                            ( include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
                              ( Fid = fidelity(P, Fa, U, _) -> true ; P = '-', Fa = '-', U = '-' ),
                              format("~n    ~w  ~w  pass ~w fail ~w error ~w  ~w writer error(s)", [F, Counts, P, Fa, U, NE]) )),
                     nl ),
                   E, ( print_message(error, E) )) )).

/*  Build the Blawx twins into LogicalEnglish2/examples/migration/blawx (le2_paths:twins_dir/2).

    From /work (the LE2 checkout, which provides le_writer and le_migration):

        ./myswipl.sh -q migration/blawx/build.pl            # all 15
        ./myswipl.sh -q migration/blawx/build.pl -- rps     # one

    The projects are Blawx v1.6.22-alpha's examples, fetched into .cache/ by
    fetch_sources.sh; their answers come from oracle.py (Blawx's reasoner),
    kept in runs/<id>.json.
*/

:- initialization(main, main).

:- use_module('../le2_paths', [twins_dir/2]).

:- prolog_load_context(directory, D),
   twins_dir(blawx, Out),
   atomic_list_concat([D, '/.cache/blawx/blawx/static/blawx/examples'], Src),
   asserta(user:bx_out_dir(Out)), asserta(user:bx_src_dir(Src)).

:- use_module(library(main)).
:- use_module(blawx_twin).

projects([beard_tax, bird, covid_test, life_act, list_demo, logical_constraints, mortality, net30,
          numerical_constraints, oasa, r34, rps, siblings, wills, wills_tutorial]).

main(Argv) :-
    user:bx_out_dir(Out), user:bx_src_dir(Src),
    make_directory_path(Out),
    (   Argv == [] -> projects(Ids) ; maplist([A, I]>>atom_string(I, A), Argv, Ids) ),
    forall(member(Id, Ids),
           ( format(atom(F), '~w/~w.yaml', [Src, Id]),
             format("~w ... ", [Id]), flush_output,
             catch(( build_twin(F, Id, Out, report(File, Issues, Counts, Fid)),
                     include([issue(S, _, _)]>>(S == error), Issues, Errs),
                     length(Errs, NE),
                     ( Fid = fidelity(P, Fa, U, _) -> true ; P = '-', Fa = '-', U = '-' ),
                     format("~w  ~w  tests ~w pass ~w fail ~w error  ~w writer error(s)~n", [File, Counts, P, Fa, U, NE]),
                     forall(member(E, Errs), ( print(E), nl )) ),
                   E, ( print_message(error, E) )) )).

/*  Build the Miniscript twins into LogicalEnglish2/examples/migration/miniscript (le2_paths:twins_dir/2).

    From /work (the LE2 checkout, which provides le_writer and le_migration):

        ./myswipl.sh -q migration/miniscript/build.pl

    or build one twin:  ... build.pl -- decaying_multisig
*/

:- initialization(main, main).

:- use_module('../le2_paths', [twins_dir/2]).

:- prolog_load_context(directory, D),
   twins_dir(miniscript, Out),
   asserta(user:ms_out_dir(Out)).

:- use_module(library(main)).
:- use_module(ms_twin).
:- use_module(policies).

main(Argv) :-
    user:ms_out_dir(Out),
    make_directory_path(Out),
    (   Argv == [] -> findall(Id, twin(Id, _), Ids) ; maplist([A, I]>>atom_string(I, A), Argv, Ids) ),
    forall(member(Id, Ids),
           ( twin(Id, Opts),
             format("~w ... ", [Id]), flush_output,
             catch(( build_twin(twin(Id, Opts), Out, report(File, Issues, Counts, Fid)),
                     include([issue(S, _, _)]>>(S == error), Issues, Errs),
                     format("~w  ~w  ~w  ~w writer error(s)~n", [File, Counts, Fid, Errs]) ),
                   E, ( print_message(error, E) )) )).

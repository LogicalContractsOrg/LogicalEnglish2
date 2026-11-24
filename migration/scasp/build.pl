/*  Build the s(CASP) twins into LogicalEnglish2/examples/migration/scasp (le2_paths:twins_dir/2).

    From /work (the LE2 checkout, which provides le_writer and le_migration):

        ./myswipl.sh -q migration/scasp/build.pl                  # the corpus
        ./myswipl.sh -q migration/scasp/build.pl -- file.pl ...   # given files

    The corpus is the sCASP pack's test/le_programs (LE1's own s(CASP)
    translations) and a few of its test/all_programs (see corpus/1); the pack
    is found through library(scasp) (SCASP_TEST_DIR overrides).
*/

:- initialization(main, main).

:- use_module('../le2_paths', [twins_dir/2]).

:- prolog_load_context(directory, D),
   twins_dir(scasp, Out),
   asserta(user:scasp_out_dir(Out)).

:- use_module(library(main)).
:- use_module(scasp_twin).
:- use_module(corpus).

main(Argv) :-
    user:scasp_out_dir(Out),
    make_directory_path(Out),
    (   Argv == [] -> findall(F, corpus_file(F), Files) ; maplist([A, F]>>atom_string(F, A), Argv, Files) ),
    forall(member(F, Files),
           ( file_base_name(F, B), format("~w ... ", [B]), flush_output,
             catch(( build_twin(F, Out, report(File, Issues, Counts, Fid)),
                     include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
                     ( Fid = fidelity(P, Fa, U, _) -> true ; P = '-', Fa = '-', U = '-' ),
                     format("~w  ~w  pass ~w fail ~w error ~w  ~w writer error(s)~n", [File, Counts, P, Fa, U, NE]) ),
                   E, ( print_message(error, E) )) )).

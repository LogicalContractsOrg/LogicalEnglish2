/*  Build the LegalRuleML twins into LogicalEnglish2/examples/migration/legalruleml (le2_paths:twins_dir/2).

    From /work (the LE2 checkout, which provides le_writer and le_migration):

        ./myswipl.sh -q migration/legalruleml/build.pl                  # the corpus
        ./myswipl.sh -q migration/legalruleml/build.pl -- file.lrml ... # given files

    The corpus is the specification's examples with the reviewer's wording and
    the drafted scenarios of corpus.pl; the expected answers need SPINdle
    (oracle/fetch_spindle.sh) and Java.
*/

:- initialization(main, main).

:- use_module('../le2_paths', [twins_dir/2]).

:- prolog_load_context(directory, D),
   twins_dir(legalruleml, Out),
   asserta(user:lrml_out_dir(Out)).

:- use_module(library(main)).
:- use_module(library(filesex)).
:- use_module(lrml_twin).
:- use_module(lrml_reader).
:- use_module(corpus).
:- use_module('../le2_paths', []).
:- use_module(le2(le_migration)).

main(Argv) :-
    user:lrml_out_dir(Out),
    make_directory_path(Out),
    (   Argv == []
    ->  findall(F-O, ( lrml_example(_, F, O), read_lrml(F, model(Is)), memberchk(statement(_, _, _, _), Is) ), Jobs)
    ;   findall(F-O, ( member(A, Argv), atom_string(F, A), file_base_name(F, B),
                       ( lrml_example(_, CF, O), file_base_name(CF, B) -> true ; O = [] ) ), Jobs)
    ),
    forall(member(F-O, Jobs),
           ( file_base_name(F, B), format("~w ... ", [B]), flush_output,
             (   catch(build(F, O, Out), E, ( print_message(error, E), fail )) -> true
             ;   format("FAILED~n")
             ) )).

build(File, Options, Root) :-
    twin_name(File, Name),
    atomic_list_concat([Root, '/', Name], Dir),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
    file_base_name(File, B), atomic_list_concat([SD, '/', B], Copy),
    copy_file(File, Copy),
    copy_library(deontic, Dir),
    twin_migration(File, [name(Name), source_copy(B)|Options], Migration),
    write_migration(Migration, Dir, Name, report(LE, Issues, Counts, Fid)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    ( Fid = fidelity(P, Fa, U, _) -> true ; P = '-', Fa = '-', U = '-' ),
    format("~w  ~w  pass ~w fail ~w error ~w  ~w writer error(s)~n", [LE, Counts, P, Fa, U, NE]).

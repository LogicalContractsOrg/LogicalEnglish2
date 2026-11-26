/*  Build the LOMO registers (the twins of LOMO's public data) into
    examples/migration/lomo/<set>/ (le2_paths:twins_dir/2).

    From the LE2 checkout:

        ./myswipl.sh -q migration/lomo/build.pl                  # the corpus
        ./myswipl.sh -q migration/lomo/build.pl -- file.ttl ...  # given files

    The corpus is the data of the LOMO repository (corpus.pl). The expected
    answers of each register's scenario are those of a search over the RDF
    data (oracle/sparql_judge.py, rdflib): oracle/setup.sh installs it.
*/

:- initialization(main, main).

:- use_module(library(main)).
:- use_module(library(filesex)).
:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(lomo_twin).
:- use_module(lomo_gate).
:- use_module(corpus).
:- use_module(le2(le_migration)).

main(Argv) :-
    twins_dir(lomo, Root),
    (   Argv == []
    ->  findall(F-Set, lomo_file(Set, F), Jobs)
    ;   findall(F-files, ( member(A, Argv), atom_string(F0, A), absolute_file_name(F0, F) ), Jobs)
    ),
    forall(member(F-Set, Jobs),
           ( file_base_name(F, B), format("~w ... ", [B]), flush_output,
             (   catch(build(F, Set, Root), E, ( print_message(error, E), fail )) -> true
             ;   format("FAILED~n")
             ) )).

build(File, Set, Root) :-
    atomic_list_concat([Root, '/', Set], Dir),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
    file_base_name(File, B), atomic_list_concat([SD, '/', B], Copy),
    copy_file(File, Copy),
    copy_library(lomo, Dir),
    twin_name(File, Name),
    gate_tests(File, Tests),
    twin_migration(File, [name(Name), source_copy(B), tests(Tests)], Migration),
    write_migration(Migration, Dir, Name, report(LE, Issues, Counts, Fid)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    ( Fid = fidelity(P, Fa, U, _) -> true ; P = '-', Fa = '-', U = '-' ),
    format("~w  ~w  pass ~w fail ~w error ~w  ~w writer error(s)~n", [LE, Counts, P, Fa, U, NE]).

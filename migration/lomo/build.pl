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
:- use_module(spec_cases).
:- use_module(lomo_eli).
:- use_module(library(readutil)).
:- use_module(le2(le_migration)).

main(Argv) :-
    twins_dir(lomo, Root),
    (   Argv == []
    ->  findall(F-Set, lomo_file(Set, F), Jobs)
    ;   findall(F-Set, ( member(A, Argv), atom_string(F0, A), absolute_file_name(F0, F),
                         ( lomo_file(Set, F) -> true ; Set = files ) ), Jobs)
    ),
    copy_hand_programs(Root),
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
    copy_library(temporal, Dir),
    copy_library(deontic, Dir),
    twin_name(File, Name),
    gate_tests(File, Tests0),
    file_name_extension(Stem, _, B),
    (   case(Stem, Scenarios, Queries, Templates)
    ->  findall(test(N, 'the source description', none, Facts, Es), member(scenario(N, Facts, Es), Scenarios), Hand),
        append(Tests0, Hand, Tests)
    ;   Tests = Tests0, Queries = [], Templates = []
    ),
    (   memberchk(Set, [examples, other, cases]) -> Eli = [eli_texts(Dir)] ; Eli = [] ),
    twin_migration(File, [name(Name), source_copy(B), tests(Tests), queries(Queries), templates(Templates)|Eli], Migration),
    write_migration(Migration, Dir, Name, report(LE, Issues, Counts, Fid)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    ( Fid = fidelity(P, Fa, U, _) -> true ; P = '-', Fa = '-', U = '-' ),
    format("~w  ~w  pass ~w fail ~w error ~w  ~w writer error(s)~n", [LE, Counts, P, Fa, U, NE]).

%   The programs written by hand beside the registers of the door's own
%   cases (hand/): the conditions of a rule, in Logical English.
%   hand/<set>/<name>.le goes beside the registers of <set>, with the text of
%   every provision it names (sources/eli/).
copy_hand_programs(Root) :-
    module_property(lomo_twin, file(TF)), file_directory_name(TF, Here),
    atomic_list_concat([Here, '/hand'], HD),
    forall(( directory_files(HD, Sets), member(Set, Sets), \+ sub_atom(Set, 0, _, _, '.'),
             atomic_list_concat([HD, '/', Set], SD), exists_directory(SD),
             directory_files(SD, Fs), member(F, Fs), file_name_extension(_, le, F) ),
           ( atomic_list_concat([SD, '/', F], Src),
             atomic_list_concat([Root, '/', Set], CD), make_directory_path(CD),
             atomic_list_concat([CD, '/', F], Dst), copy_file(Src, Dst),
             read_file_to_string(Src, Text, []),
             findall(E, ( sub_string(Text, B, _, _, "\"http://data.europa.eu/eli/"), B1 is B + 1,
                          sub_string(Text, B1, _, 0, R), once(sub_string(R, P, 1, _, "\"")), sub_string(R, 0, P, _, E) ), Es0),
             sort(Es0, Es),
             lomo_eli:write_provision_texts(Es, CD, _) )).

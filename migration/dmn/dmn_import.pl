/** <module> File ▸ Open of a DMN model: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    a DMN model: a `.dmn` file, or an `.xml` file whose root element is
    `definitions` in a DMN namespace (the Dutch STTR files are such `.xml`
    files), alone or zipped with the models it imports. The program opened
    is the twin dmn_twin.pl writes. A DMN TCK test file beside the model
    (`<model>-test-01.xml`) gives its scenarios; without one the program has
    none, since the oracle (Drools) is not run on an upload.
*/

:- module(dmn_import, [import_dmn/3, detect_dmn/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module(dmn_reader).
:- use_module(dmn_tests).
:- use_module(dmn_twin).
:- use_module(dmn_build, [model_dir_name/2]).
:- use_module(le2(le_migration)).

%!  detect_dmn(+Input) is semidet.
detect_dmn(Input) :- dmn_files(Input, [_|_]).

dmn_files(Input, Files) :-
    (   exists_directory(Input)
    ->  findall(F, ( directory_member(Input, F, [recursive(true), extensions([dmn, xml])]),
                     \+ sub_atom(F, _, _, _, '-test-'), is_dmn(F) ), Fs0),
        msort(Fs0, Files)
    ;   exists_file(Input), is_dmn(Input) -> Files = [Input]
    ;   Files = []
    ).

%   The root element is `definitions` in a DMN namespace: read from the
%   first lines, so a large file is not parsed to be recognised.
is_dmn(F) :-
    catch(setup_call_cleanup(open(F, read, In, [encoding(utf8)]), read_string(In, 4000, Head), close(In)), _, fail),
    sub_string(Head, _, _, _, "definitions"),
    (   sub_string(Head, _, _, _, "omg.org/spec/DMN/")
    ;   sub_string(Head, _, _, _, "www.omg.org/spec/DMN")
    ), !.

%!  import_dmn(+Input, +OutDir, -Result) is det.
import_dmn(Input, OutDir0, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    dmn_files(Input, Files),
    (   Files == [] -> throw(error(format("~w is not a DMN model (no DMN `definitions`)", [Input]), _)) ; true ),
    main_model(Files, Main),
    tck_test_files(Main, TFs),
    findall(C, ( member(TF, TFs), tck_cases(TF, _, Cs), member(C, Cs) ), Cases),
    ( TFs = [TF1|_] -> file_base_name(TF1, Doc) ; file_base_name(Main, Doc) ),
    model_dir_name(Main, Name),
    model_migration(Main, [tests(Cases), document(Doc), program(Name)], Migration0),
    with_original(Migration0, Main, OutDir, Migration),
    Migration = migration(_, program(Header, _), _, _),
    (   memberchk(includes(Libs), Header) -> forall(member(L, Libs), copy_library(L, OutDir)) ; true ),
    write_migration(Migration, OutDir, Name, report(LEFile, Issues, counts(E, A, R), Fid)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    file_base_name(Main, MB),
    (   Fid = fidelity(P, F, U, _)
    ->  format(string(N1), "~w: ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors; the test file's cases: ~w pass, ~w fail, ~w errors.", [MB, E, A, R, NE, P, F, U])
    ;   format(string(N1), "~w: ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors; no test file beside it, so no expectations.", [MB, E, A, R, NE])
    ),
    length(Files, NF),
    (   NF > 1 -> format(string(N2), "~w models in the upload; the one no other imports was translated.", [NF]), Notes = [N1, N2]
    ;   Notes = [N1]
    ).

%   The model no other model of the upload imports (the last such, by name).
main_model([F], F) :- !.
main_model(Files, Main) :-
    findall(NS, ( member(F, Files), catch(dmn_read_file(F, model(_, Items)), _, fail),
                  member(import(_, NS, _, _), Items) ), Imported),
    findall(F, ( member(F, Files), catch(dmn_read_file(F, M), _, fail),
                 dmn_info(M, namespace, NS), \+ memberchk(NS, Imported) ), Roots),
    ( last(Roots, Main) -> true ; last(Files, Main) ).

with_original(migration(Meta, program(H, Items), L, T), File, Dir, migration(Meta, program(H, [document(the_model, [text(Rel)])|Items]), L, T)) :-
    atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
    file_base_name(File, B), atomic_list_concat([SD, '/', B], Dst),
    ( same_file(File, Dst) -> true ; copy_file(File, Dst) ),
    atomic_list_concat(['sources/', B], Rel).

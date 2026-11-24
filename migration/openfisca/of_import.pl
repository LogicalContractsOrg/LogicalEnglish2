/** <module> File ▸ Open of OpenFisca or PolicyEngine code: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    a country package's code: a `.py` file of `Variable` classes, or a zip
    of a package (or part of one: variable files, a `parameters/` folder of
    YAML, test YAML files). The upload is not installed and its code is not
    run: of_static.py reads the variables' Python with `ast` and the
    parameters as OpenFisca reads them, and of_extract.py translates them as
    it translates an installed package; the twin builder of migration/rulespec
    writes the program. A variable the upload reads but does not define is a
    fact the scenarios state. The expected answers are the test files' own:
    the engine is not run on an upload.
*/

:- module(of_import, [import_openfisca/3, detect_openfisca/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module('../rulespec/rulespec_reader').
:- use_module('../rulespec/rulespec_twin').
:- use_module(le2(le_migration)).

here(D) :- module_property(of_import, file(F)), file_directory_name(F, D).

%!  detect_openfisca(+Input) is semidet.
detect_openfisca(Input) :-
    (   exists_directory(Input)
    ->  directory_member(Input, F, [recursive(true), extensions([py])]), variable_file(F), !
    ;   exists_file(Input), file_name_extension(_, py, Input), variable_file(Input)
    ).

variable_file(F) :-
    catch(read_file_to_string(F, S, []), _, fail),
    sub_string(S, _, _, _, "(Variable):"), !.

%!  import_openfisca(+Input, +OutDir, -Result) is det.
import_openfisca(Input, OutDir0, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    (   exists_directory(Input) -> Dir = Input
    ;   file_directory_name(Input, Dir0),
        atomic_list_concat([OutDir, '/upload'], Dir), make_directory_path(Dir),
        file_base_name(Input, B), atomic_list_concat([Dir, '/', B], To), copy_file(Input, To),
        _ = Dir0
    ),
    file_base_name(Input, IB), file_name_extension(Stem0, _, IB), name_of(Stem0, Name),
    atomic_list_concat([OutDir, '/.of'], Tmp), make_directory_path(Tmp),
    here(H), atomic_list_concat([H, '/of_static.py'], Py),
    process_create(path(python3), [Py, Dir, Tmp, Name], [stdout(pipe(O)), stderr(pipe(E)), process(P)]),
    read_string(O, _, Said), read_string(E, _, Err), close(O), close(E), process_wait(P, St),
    (   St == exit(0) -> true ; throw(error(format("the OpenFisca reader failed: ~s", [Err]), _)) ),
    atomic_list_concat([Tmp, '/of/', Name, '.yaml'], ModFile),
    atom_concat('of:', Name, Id),
    %  An upload of openfisca-france is written in Français Logique
    %  (decision 3 of the October plan: a French source gives a French
    %  twin). The reader says which it read (of_static.py, Phase 3b′ step 7).
    (   sub_string(Said, _, _, _, "dialect: static_fr")
    ->  Lang = fr,
        format(string(Header), "~w — du code openfisca-france ouvert en Logical English.~nTraduit par LE2 migration/openfisca, depuis les fichiers seuls : le moteur du paquet n'a pas été exécuté.", [Name])
    ;   Lang = en,
        format(string(Header), "~w — OpenFisca / PolicyEngine code opened in Logical English.~nTranslated by LE2 migration/openfisca, from the files alone: the package's engine was not run.", [Name])
    ),
    with_upload([Id-ModFile], [], module_migration(Id, [header(Header), language(Lang)], Migration)),
    copy_originals(Dir, ModFile, OutDir),
    write_migration(Migration, OutDir, Name, report(LEFile, Issues, counts(En, A, R), Fid)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    split_string(Said, "\n", "", [First|_]),
    (   Fid = fidelity(Pa, Fa, U, _)
    ->  format(string(N1), "~s. ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors; the test files' cases: ~w pass, ~w fail, ~w errors.", [First, En, A, R, NE, Pa, Fa, U])
    ;   format(string(N1), "~s. ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors; no test file, so no expectations.", [First, En, A, R, NE])
    ),
    (   Lang == fr
    ->  N2 = "Le moteur du paquet n'a pas été exécuté sur ce téléversement : les réponses attendues sont celles de ses propres fichiers de tests, et une variable que le téléversement ne définit pas est un fait énoncé par les scénarios."
    ;   N2 = "The package's engine was not run on this upload: the expected answers are its test files' own, and a variable the upload does not define is a fact the scenarios state."
    ),
    Notes = [N1, N2].

name_of(S0, S) :-
    downcase_atom(S0, L), atom_codes(L, Cs0),
    maplist([C0, C]>>( code_type(C0, alnum) -> C = C0 ; C = 0'_ ), Cs0, Cs),
    atom_codes(S1, Cs), ( S1 == '' -> S = upload ; S = S1 ).

copy_originals(Dir, ModFile, OutDir) :-
    atomic_list_concat([OutDir, '/sources/of'], SO), make_directory_path(SO),
    file_base_name(ModFile, MB), atomic_list_concat([SO, '/', MB], MT), copy_file(ModFile, MT),
    file_name_extension(Stem, yaml, ModFile), atom_concat(Stem, '.test.yaml', TF),
    (   exists_file(TF) -> file_base_name(TF, TB), atomic_list_concat([SO, '/', TB], TT), copy_file(TF, TT) ; true ),
    forall(( directory_member(Dir, F, [recursive(true)]), \+ sub_atom(F, _, _, _, '/.of/'),
             file_name_extension(_, Ext, F), memberchk(Ext, [py, yaml, yml]) ),
           ( atom_concat(Dir, Rel, F), atomic_list_concat([OutDir, '/sources', Rel], To),
             file_directory_name(To, TD), make_directory_path(TD), ( exists_file(To) -> true ; copy_file(F, To) ) )).

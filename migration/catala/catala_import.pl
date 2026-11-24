/** <module> File ▸ Open of Catala: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    Catala: a `.catala_en` or `.catala_fr` file, or a zip of a module's
    files with its tests. The upload is read by catala_reader.pl (Catala's
    own grammar, both dialects) and lowered by catala_lower.pl; the twin
    builder of migration/rulespec writes the program in the files' language
    (English, or Français Logique for `.catala_fr`). The program's scopes
    are those no other scope calls (test scopes aside); the scenarios are
    the test scopes (#[test]) that call them, their expected answers the
    tests' assertions: Catala is not run on an upload.
*/

:- module(catala_import, [import_catala/3, detect_catala/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module(library(yaml)).
:- use_module(catala_reader).
:- use_module(catala_lower).
:- use_module('../rulespec/rulespec_reader').
:- use_module('../rulespec/rulespec_twin').
:- use_module(le2(le_migration)).

%!  detect_catala(+Input) is semidet.
detect_catala(Input) :-
    (   exists_directory(Input)
    ->  catala_files(Input, [_|_])
    ;   exists_file(Input), catala_lang(Input, _)
    ).

catala_files(Dir, Fs) :-
    findall(F, ( directory_member(Dir, F, [recursive(true)]), catala_lang(F, _) ), Fs0), sort(Fs0, Fs).

%!  import_catala(+Input, +OutDir, -Result) is det.
import_catala(Input, OutDir0, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    (   exists_directory(Input) -> catala_files(Input, Files), Dir = Input
    ;   Files = [Input], file_directory_name(Input, Dir)
    ),
    Files = [F1|_], catala_lang(F1, Lang),
    file_base_name(Input, IB), file_name_extension(Stem0, _, IB), name_of(Stem0, Name),
    maplist(read_catala_file, Files, Trees),
    roots(Trees, Roots),
    (   Roots == [] -> throw(error(format("no scope with definitions in ~w", [IB]), _)) ; true ),
    lower_programme(Name, Files, Roots, module(Rules, Tests, _)),
    atomic_list_concat([OutDir, '/.cat'], Tmp), make_directory_path(Tmp),
    atomic_list_concat([Tmp, '/', Name, '.yaml'], ModFile),
    atomic_list_concat([Tmp, '/', Name, '.test.yaml'], TestFile),
    write_yaml(ModFile, _{format: "rulespec/v1", module: _{title: Name}, rules: Rules}),
    write_yaml(TestFile, Tests),
    atom_concat('cat:', Name, Id),
    atomic_list_concat(Roots, ', ', RA),
    (   Lang == fr
    ->  format(string(Header), "~w — Catala ouvert en Logical English (champs d'application ~w).~nTraduit par LE2 migration/catala, à partir des fichiers seuls : Catala n'a pas été exécuté.", [Name, RA]),
        Subj = 'le cas'
    ;   format(string(Header), "~w — Catala opened in Logical English (scopes ~w).~nTranslated by LE2 migration/catala, from the files alone: Catala was not run.", [Name, RA]),
        Subj = 'the case'
    ),
    with_upload([Id-ModFile], [], module_migration(Id, [header(Header), language(Lang), subject(none), judgment_subject(Subj)], Migration)),
    copy_originals(Dir, Files, ModFile, OutDir),
    write_migration(Migration, OutDir, Name, report(LEFile, Issues, counts(En, A, R), Fid)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    length(Files, NF), length(Rules, NR),
    (   Fid = fidelity(Pa, Fa, U, _)
    ->  format(string(N1), "~w Catala file(s), scope(s) ~w: ~w variables; ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors; the test scopes' assertions: ~w pass, ~w fail, ~w errors.", [NF, RA, NR, En, A, R, NE, Pa, Fa, U])
    ;   format(string(N1), "~w Catala file(s), scope(s) ~w: ~w variables; ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors; no test scope, so no expectations.", [NF, RA, NR, En, A, R, NE])
    ),
    Notes = [N1, "Catala was not run on this upload: the expected answers are the test scopes' own assertions."].

%   The scopes with definitions that no other scope calls, test scopes aside.
roots(Trees, Roots) :-
    findall(S, ( member(catala(_, Is), Trees), member(code(_, CIs, _), Is),
                 member(scope_decl(S, _, As, _), CIs), \+ memberchk(test, As) ), Ss0), sort(Ss0, Ss),
    findall(S2, ( member(catala(_, Is), Trees), member(code(_, CIs, _), Is),
                  member(scope_decl(_, Ds, As2, _), CIs), \+ memberchk(test, As2),
                  member(sub(_, scoped(_, S2), _, _), Ds) ), Called0), sort(Called0, Called),
    findall(S, ( member(S, Ss), \+ memberchk(S, Called),
                 once(( member(catala(_, Is), Trees), member(code(_, CIs, _), Is), member(scope_use(S, _, [_|_], _, _), CIs) )) ), Roots).

name_of(S0, S) :-
    downcase_atom(S0, L), atom_codes(L, Cs0),
    maplist([C0, C]>>( code_type(C0, alnum) -> C = C0 ; C = 0'_ ), Cs0, Cs),
    atom_codes(S1, Cs), ( S1 == '' -> S = upload ; S = S1 ).

write_yaml(File, Term) :-
    setup_call_cleanup(open(File, write, S, [encoding(utf8)]), yaml_write(S, Term), close(S)).

copy_originals(Dir, Files, ModFile, OutDir) :-
    atomic_list_concat([OutDir, '/sources/cat'], SC), make_directory_path(SC),
    file_base_name(ModFile, MB), atomic_list_concat([SC, '/', MB], MT), copy_file(ModFile, MT),
    file_name_extension(Stem, yaml, ModFile), atom_concat(Stem, '.test.yaml', TF),
    ( exists_file(TF) -> file_base_name(TF, TB), atomic_list_concat([SC, '/', TB], TT), copy_file(TF, TT) ; true ),
    forall(member(F, Files),
           ( (   atom_concat(Dir, Rel0, F), atom_concat('/', Rel, Rel0) -> true ; file_base_name(F, Rel) ),
             atomic_list_concat([OutDir, '/sources/', Rel], To), file_directory_name(To, TD),
             make_directory_path(TD), copy_file(F, To) )).

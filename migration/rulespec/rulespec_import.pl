/** <module> File ▸ Open of a RuleSpec module: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    an Axiom RuleSpec module: a `.yaml` file whose first key is `format:
    rulespec/v1`, alone, or in a zip with the modules it imports (laid out as
    in rulespec-us, `us/statutes/...`, or side by side). The program opened
    is the twin rulespec_twin.pl writes: the module and its imports, each
    rule cited, the companion `.test.yaml` (when it is there) as scenarios.

    An import the upload does not hold is looked for in the corpus this
    translator was built on (fetch_sources.sh), when it is installed; a
    module found in neither is noted, and the names it would have defined
    become inputs the scenarios state. The expected answers are the test
    file's own; Axiom's engine is not run on an upload.
*/

:- module(rulespec_import, [import_rulespec/3, detect_rulespec/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module(rulespec_reader).
:- use_module(rulespec_twin).
:- use_module(le2(le_migration)).

%!  detect_rulespec(+Input) is semidet.
detect_rulespec(Input) :- rulespec_files(Input, [_|_]).

rulespec_files(Input, Files) :-
    (   exists_directory(Input)
    ->  findall(F, ( directory_member(Input, F, [recursive(true), extensions([yaml, yml])]),
                     \+ test_file(F), is_rulespec(F) ), Files0),
        msort(Files0, Files)
    ;   exists_file(Input), \+ test_file(Input), is_rulespec(Input) -> Files = [Input]
    ;   Files = []
    ).

test_file(F) :- ( sub_atom(F, _, _, 0, '.test.yaml') ; sub_atom(F, _, _, 0, '.test.yml') ).

is_rulespec(F) :-
    catch(setup_call_cleanup(open(F, read, In), read_head(In, 40, Lines), close(In)), _, fail),
    member(L, Lines), split_string(L, "", " \t", [T]),
    sub_string(T, 0, _, _, "format:"), sub_string(T, _, _, 0, "rulespec/v1"), !.

read_head(_, 0, []) :- !.
read_head(In, N, Ls) :-
    read_line_to_string(In, L),
    (   L == end_of_file -> Ls = [] ; N1 is N - 1, Ls = [L|Ls1], read_head(In, N1, Ls1) ).

%!  import_rulespec(+Input, +OutDir, -Result) is det.
import_rulespec(Input, OutDir0, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    rulespec_files(Input, Files),
    (   Files == [] -> throw(error(format("~w is not a RuleSpec module (no `format: rulespec/v1`)", [Input]), _)) ; true ),
    maplist(file_id, Files, Pairs),
    roots(Files, Roots),
    root_module(Pairs, RootId),
    with_upload(Pairs, Roots,
                ( module_migration(RootId, [], Migration),
                  module_closure(RootId, Ms),
                  copy_sources(Ms, OutDir),
                  findall(M, missing_import(M), Missing) )),
    module_twin_name(RootId, Name),
    write_migration(Migration, OutDir, Name, report(LEFile, Issues, counts(E, A, R), Fid)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    length(Ms, NM),
    (   Fid = fidelity(P, F, U, _)
    ->  format(string(N1), "~w (~w module(s)): ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors; the test file's cases: ~w pass, ~w fail, ~w errors.", [RootId, NM, E, A, R, NE, P, F, U])
    ;   format(string(N1), "~w (~w module(s)): ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors; no test file beside it, so no expectations.", [RootId, NM, E, A, R, NE])
    ),
    (   Missing == [] -> Notes = [N1]
    ;   atomic_list_concat(Missing, ', ', MT),
        format(string(N2), "Imported but not found here: ~w. The names those modules define are inputs the scenarios state.", [MT]),
        Notes = [N1, N2]
    ).

%   A file's identifier: its path's, when it is laid out as in rulespec-us,
%   upload:<name> otherwise.
file_id(F, Id-F) :-
    (   path_module_id(F, Id0) -> Id = Id0
    ;   file_base_name(F, B), file_name_extension(S, _, B), atom_concat('upload:', S, Id)
    ).

%   The folders above a jurisdiction folder: where imports are looked for.
roots(Files, Roots) :-
    findall(R, ( member(F, Files), path_module_id(F, Id), atomic_list_concat([J, Rest], ':', Id),
                 atomic_list_concat(['/', J, '/', Rest, '.yaml'], Tail), atom_concat(R, Tail, F) ), Rs0),
    sort(Rs0, Roots).

%   The module no other module of the upload imports (the first, when there
%   are several), preferring one with a test file beside it.
root_module(Pairs, Root) :-
    findall(I, ( member(_-F, Pairs), catch(yaml_imports(F, Is), _, fail), member(I0, Is),
                 atom_string(I1, I0), ( sub_atom(I1, B, 1, _, '#') -> sub_atom(I1, 0, B, _, I) ; I = I1 ) ), Imported),
    findall(I, ( member(I-_, Pairs), \+ memberchk(I, Imported) ), Tops0),
    ( Tops0 == [] -> findall(I, member(I-_, Pairs), Tops) ; Tops = Tops0 ),
    (   member(Root, Tops), memberchk(Root-F, Pairs), file_name_extension(B, _, F), atom_concat(B, '.test.yaml', T), exists_file(T)
    ->  true
    ;   Tops = [Root|_]
    ).

yaml_imports(F, Is) :-
    yaml_read(F, D), ( get_dict(imports, D, Is0), is_list(Is0) -> Is = Is0 ; Is = [] ).

copy_sources(Ms, OutDir) :-
    forall(member(module(MId, _), Ms),
           ( module_file(MId, F),
             atomic_list_concat([J, R], ':', MId),
             atomic_list_concat([OutDir, '/sources/', J, '/', R, '.yaml'], To),
             file_directory_name(To, TD), make_directory_path(TD),
             ( same_file(F, To) -> true ; copy_file(F, To) ),
             file_name_extension(B, _, F), atom_concat(B, '.test.yaml', TF),
             (   exists_file(TF)
             ->  atomic_list_concat([OutDir, '/sources/', J, '/', R, '.test.yaml'], TTo),
                 ( same_file(TF, TTo) -> true ; copy_file(TF, TTo) )
             ;   true ) )).

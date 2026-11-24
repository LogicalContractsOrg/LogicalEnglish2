/** <module> File ▸ Open of a Blawx project: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    a Blawx project: a `.blawx` export or the YAML of an example (Django
    fixtures holding one `blawx.ruledoc`, its sections' workspaces and its
    tests), alone or in a zip. The program opened is the twin blawx_twin.pl
    writes for the project catalogue: the Act in its own words, section by
    section and cited, the tests as scenarios. When Blawx's reasoner
    preamble has been fetched (fetch_sources.sh) and the reasoner can run
    (Python with PyYAML, SWI-Prolog with library(scasp)) the expected answers
    are Blawx's own, computed on the upload (oracle.py) and kept beside it in
    sources/; otherwise the scenarios carry no expectations, and a note says
    why.
*/

:- module(blawx_import, [import_blawx/3, detect_blawx/1]).

:- use_module(library(lists)).
:- use_module(library(filesex)).
:- use_module(blawx_reader).
:- use_module(blawx_twin).
:- use_module(le2(le_migration)).

%!  detect_blawx(+Input) is semidet.
detect_blawx(Input) :- blawx_file(Input, _).

blawx_file(Input, File) :-
    (   exists_directory(Input)
    ->  directory_member(Input, File, [recursive(true), extensions([blawx, yaml, yml])]),
        is_blawx_project(File), !
    ;   exists_file(Input), is_blawx_project(Input), File = Input
    ).

%!  import_blawx(+Input, +OutDir, -Result) is det.
import_blawx(Input, OutDir0, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    (   blawx_file(Input, File) -> true
    ;   throw(error(format("~w is not a Blawx project (no blawx.ruledoc in it)", [Input]), _))
    ),
    file_base_name(File, B), file_name_extension(Stem0, _, B), stem(Stem0, Id),
    atomic_list_concat([OutDir, '/sources'], SD), make_directory_path(SD),
    atomic_list_concat([SD, '/', B], Copy), ( exists_file(Copy) -> true ; copy_file(File, Copy) ),
    atomic_list_concat([SD, '/blawx_answers'], Runs),
    project_migration(Copy, Id, [dir(OutDir), runs(Runs)], Migration),
    write_migration(Migration, OutDir, Id, report(LEFile, Issues, counts(E, A, R), Fid)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    (   Fid = fidelity(P, F, U, _)
    ->  format(string(N1), "~w: ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors; Blawx's tests and the generated cases: ~w pass, ~w fail, ~w errors.", [Id, E, A, R, NE, P, F, U])
    ;   format(string(N1), "~w: ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors.", [Id, E, A, R, NE])
    ),
    (   oracle_unavailable(Why) -> Notes = [N1, Why]
    ;   Notes = [N1]
    ).

stem(S0, S) :-
    downcase_atom(S0, L), atom_codes(L, Cs0),
    maplist([C0, C]>>( code_type(C0, alnum), C0 < 128 -> C = C0 ; C = 0'_ ), Cs0, Cs),
    atom_codes(A, Cs), atomic_list_concat(Ps0, '_', A), exclude(==(''), Ps0, Ps),
    ( Ps == [] -> S = blawx_project ; atomic_list_concat(Ps, '_', S1),
      ( sub_atom(S1, 0, 1, _, F), char_type(F, digit) -> atom_concat(p_, S1, S) ; S = S1 ) ).

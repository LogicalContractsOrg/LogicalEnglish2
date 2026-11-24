/*  The way back of Phase 3b, checked by OpenFisca's engine

        ./myswipl.sh -q migration/openfisca/of_roundtrip.pl -- <twin.le>...

    Each program is exported with of_export.pl to one Python module (into
    .cache/rt/), and of_roundtrip_run.py runs its scenarios, as OpenFisca
    tests, on openfisca-core.
*/

:- initialization(main, main).

:- use_module(library(main)).
:- use_module(library(filesex)).
:- use_module(library(process)).
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- use_module(of_export).

main(Files) :-
    module_property(of_export, file(F)), file_directory_name(F, H),
    atomic_list_concat([H, '/.cache/rt'], RT), make_directory_path(RT),
    findall(Py, ( member(File, Files), export_one(File, RT, Py) ), Pys),
    atomic_list_concat([H, '/.cache/venv/bin/python'], Python),
    atomic_list_concat([H, '/of_roundtrip_run.py'], Runner),
    (   Pys == [] -> true
    ;   process_create(Python, [Runner|Pys], [stdout(pipe(O))]), read_string(O, _, S), close(O), format("~s", [S])
    ).

export_one(File, RT, Py) :-
    file_base_name(File, B), file_name_extension(Name0, _, B),
    atomic_list_concat(Ps, '-', Name0), atomic_list_concat(Ps, '_', Name),
    read_file_to_string(File, Text, []), file_directory_name(File, D),
    (   catch(( le_kbs:load_text(Text, D, KB), openfisca_module(KB, M, T) ), E, true)
    ->  (   var(E)
        ->  atomic_list_concat([RT, '/', Name, '.py'], Py),
            setup_call_cleanup(open(Py, write, O), format(O, "~s~nTESTS = r'''~n~s'''~n", [M, T]), close(O))
        ;   ( E = error(of_export_refused(P), _) -> length(P, NP), format("~w: refused (~w problem(s)): ~q~n", [Name, NP, P]) ; format("~w: ~q~n", [Name, E]) ),
            fail
        )
    ;   format("~w: export failed~n", [Name]), fail
    ).

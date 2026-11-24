/*  Build the RUML twins (the design notes ruml.md §10, steps 2 to 4).

        swipl -q migration/ruml/build.pl                      both collections
        swipl -q migration/ruml/build.pl -- tests             one collection
        swipl -q migration/ruml/build.pl -- spec haertefall   the rulemaps whose file name has haertefall

    Run from the LE2 checkout, after fetch_sources.sh. Each rulemap becomes
    <twins>/<collection>/<name>/<name>.le with its ledger and its original
    under sources/.
*/

:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(le2(le_migration)).
:- use_module(ruml_build).

:- initialization(main, main).

main :-
    current_prolog_flag(argv, Argv),
    (   Argv = [C|Rest] -> atom_string(Ca, C), ( Rest = [F0|_] -> atom_string(F, F0), build_collection(Ca, F) ; build_collection(Ca, '') )
    ;   forall(member(C, [tests, spec]), build_collection(C, ''))
    ).

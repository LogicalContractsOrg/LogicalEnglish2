/*  Build the DMN twins (the design notes roadmap.md, Phase 4, step 2).

        swipl -q migration/dmn/build.pl                 all collections
        swipl -q migration/dmn/build.pl -- tck          one collection
        swipl -q migration/dmn/build.pl -- tck 0004     the models whose file name has 0004

    Run from the LE2 checkout (it loads LE2's le_migration through
    ../le2_paths). Each model becomes <twins>/<collection>/<model>/<model>.le
    with its ledger, the original under sources/, and the libraries it
    includes copied beside it.
*/

:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(le2(le_migration)).
:- use_module(dmn_build).

:- initialization(main, main).

main :-
    current_prolog_flag(argv, Argv),
    (   Argv = [C|Rest] -> atom_string(Ca, C), ( Rest = [F0|_] -> atom_string(F, F0), build_collection(Ca, F) ; build_collection(Ca, '') )
    ;   forall(member(C, [tck, ronl, bdt, tck3, sttr]), build_collection(C, ''))
    ).

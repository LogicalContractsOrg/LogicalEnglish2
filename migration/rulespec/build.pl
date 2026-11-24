/*  Build the RuleSpec twins (le2_paths:twins_dir/2: LE2 examples/migration/rulespec).

    From /work (the LE2 checkout, which provides le_writer and le_migration):

        ./myswipl.sh -q migration/rulespec/build.pl                    # all of corpus.pl
        ./myswipl.sh -q migration/rulespec/build.pl -- us:statutes/7/2017/a

    The modules are rulespec-us at the commit corpus.pl pins, normalised by
    prepare_root.py into .cache/root/; the engine's answers to their tests come
    from rulespec_oracle.py, kept in runs/<id>.json.
*/

:- initialization(main, main).

:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(library(main)).
:- use_module(rulespec_twin).
:- use_module(rulespec_build).

main(Argv) :-
    (   Argv == [] -> findall(I, rulespec_corpus:twin_module(I, _), Ids) ; maplist([A, I]>>atom_string(I, A), Argv, Ids) ),
    forall(member(Id, Ids), build_and_report(Id)).

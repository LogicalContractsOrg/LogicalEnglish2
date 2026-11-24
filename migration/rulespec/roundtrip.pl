/*  The way back, checked by Axiom's engine (roadmap.md §8, Phase 3a, step 3)

        ./myswipl.sh -q migration/rulespec/roundtrip.pl [-- twin.le ...]

    Each twin (all of examples/migration/rulespec/ by default) is exported
    with rulespec_export.pl to one module, us:policies/logical-english/<name>,
    and its scenarios to the module's test cases; the module is written into
    a scratch checkout (.cache/rt/rulespec-us), compiled and run on those
    cases by the engine (rulespec_oracle.py, runs under .cache/rt/runs).
    Prints, per twin, whether the engine compiled the module and how many
    cases it reproduced; writes runs/roundtrip.txt.
*/

:- initialization(main, main).

:- use_module(library(main)).
:- use_module(library(filesex)).
:- use_module(library(process)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(le2(le_kbs)).
:- use_module(rulespec_export).

main(Argv) :-
    module_property(rulespec_export, file(F)), file_directory_name(F, Here),
    atomic_list_concat([Here, '/.cache/rt'], RT),
    atomic_list_concat([RT, '/rulespec-us/us/policies/logical-english'], Dir),
    ( exists_directory(RT) -> delete_directory_and_contents(RT) ; true ),
    make_directory_path(Dir),
    (   Argv == []
    ->  twins_dir(rulespec, TD), findall(T, directory_member(TD, T, [extensions([le]), recursive(true)]), Ts0),
        exclude([T]>>sub_atom(T, _, _, _, '/sources/'), Ts0, Ts1), msort(Ts1, Twins)
    ;   Twins = Argv
    ),
    atomic_list_concat([Here, '/runs/roundtrip.txt'], Out),
    setup_call_cleanup(open(Out, write, S),
        ( forall(member(T, Twins), roundtrip(S, Here, RT, Dir, T)),
          summary(S) ),
        close(S)).

:- dynamic outcome/2.

roundtrip(S, Here, RT, Dir, File) :-
    file_base_name(File, B), file_name_extension(Name, _, B),
    format(atom(MId), 'us:policies/logical-english/~w', [Name]),
    read_file_to_string(File, Text, []), file_directory_name(File, D),
    (   catch(( le_kbs:load_text(Text, D, KB), export_files(KB, MId, Module, Tests) ), E, true)
    ->  true ; E = failed ),
    (   nonvar(E)
    ->  ( E = error(rulespec_export_refused(Ps), _) -> length(Ps, NP), format(string(Why), "refused (~w problem(s)): ~w", [NP, Ps]) ; term_string(E, Why) ),
        assertz(outcome(Name, refused)), report(S, "~w: ~s~n", [Name, Why])
    ;   atomic_list_concat([Dir, '/', Name, '.yaml'], MF), write_file(MF, Module),
        atomic_list_concat([Dir, '/', Name, '.test.yaml'], TF), write_file(TF, Tests),
        atomic_list_concat([Here, '/rulespec_oracle.py'], Py),
        atomic_list_concat([RT, '/rulespec-us'], Root), atomic_list_concat([RT, '/runs'], Runs),
        format(atom(RootA), 'RULESPEC_ROOT=~w', [Root]), format(atom(RunsA), 'RULESPEC_RUNS=~w', [Runs]),
        process_create(path(env), [RootA, RunsA, python3, Py, '--force', MId],
                       [stdout(pipe(P)), stderr(null)]),
        read_string(P, _, Said), close(P),
        split_string(Said, "\n", "", [Line|_]),
        ( sub_string(Line, _, _, _, "compile ok"), sub_string(Line, _, _, _, " 0 fail, 0 error") -> O = agrees ; O = differs ),
        assertz(outcome(Name, O)),
        report(S, "~s~n", [Line])
    ).

write_file(F, T) :- setup_call_cleanup(open(F, write, O, [encoding(utf8)]), write(O, T), close(O)).

report(S, Fmt, Args) :- format(S, Fmt, Args), format(Fmt, Args).

summary(S) :-
    aggregate_all(count, outcome(_, agrees), A), aggregate_all(count, outcome(_, differs), D),
    aggregate_all(count, outcome(_, refused), R),
    report(S, "~nexported and reproduced by the engine: ~w; exported, the engine disagrees or fails: ~w; refused: ~w~n", [A, D, R]).

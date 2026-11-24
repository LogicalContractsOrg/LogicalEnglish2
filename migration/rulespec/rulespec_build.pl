/** <module> Building one RuleSpec twin: originals, oracle runs, the program, its ledger

    build_and_report(+Id) writes the twin of module Id into
    <twins_dir(rulespec)>/<group>/<name>.le with its ledger, copies the
    YAML of every module it reads (and their test files) into the group's
    sources/, and prints the counts and the fidelity of the twin's
    scenarios.
*/

:- module(rulespec_build, [build_and_report/1, build_twin/2]).

:- use_module(library(filesex)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(le2(le_migration)).
:- use_module(corpus).
:- use_module(rulespec_reader).
:- use_module(rulespec_twin).

:- dynamic here_/1.
:- prolog_load_context(directory, D), retractall(here_(_)), assertz(here_(D)).

build_and_report(Id) :-
    format("~w ... ", [Id]), flush_output,
    catch(( build_twin(Id, report(File, Issues, Counts, Fid)),
            include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
            ( Fid = fidelity(P, Fa, U, _) -> true ; P = '-', Fa = '-', U = '-' ),
            format("~w  ~w  tests ~w pass ~w fail ~w error  ~w writer error(s)~n", [File, Counts, P, Fa, U, NE]),
            forall(member(E, Errs), ( print(E), nl )) ),
          E, ( print_message(error, E) )).

build_twin(Id, Report) :-
    twin_module(Id, Group),
    twins_dir(rulespec, Out0), atomic_list_concat([Out0, '/', Group], Dir),
    make_directory_path(Dir),
    copy_sources(Id, Dir),
    oracle_run(Id, Run),
    module_migration(Id, [oracle_runs(Run)], Migration),
    module_twin_name(Id, Name),
    write_migration(Migration, Dir, Name, Report).

copy_sources(Id, Dir) :-
    module_closure(Id, Ms),
    forall(member(module(MId, _), Ms),
           ( module_file(MId, F), file_name_extension(B, yaml, F), atom_concat(B, '.test.yaml', TF),
             atomic_list_concat([J, R], ':', MId),
             atomic_list_concat([Dir, '/sources/', J, '/', R, '.yaml'], To),
             file_directory_name(To, TD), make_directory_path(TD),
             original(F, F0), copy_file(F0, To),
             (   original(TF, TF0), exists_file(TF0)
             ->  atomic_list_concat([Dir, '/sources/', J, '/', R, '.test.yaml'], TTo), copy_file(TF0, TTo)
             ;   true ) )).

%   The file as the corpus has it (not the normalised copy).
original(F, F0) :-
    here_(H), atomic_list_concat([H, '/.cache/root/rulespec-us/'], P),
    (   atom_concat(P, Rel, F)
    ->  atomic_list_concat([H, '/.cache/rulespec-us/', Rel], F0)
    ;   F0 = F
    ).

oracle_run(Id, Run) :-
    here_(H), atom_codes(Id, Cs0),
    maplist([C0, C]>>( memberchk(C0, `/:`) -> C = 0'_ ; C = C0 ), Cs0, Cs), atom_codes(B, Cs),
    atomic_list_concat([H, '/runs/', B, '.json'], F),
    (   exists_file(F) -> setup_call_cleanup(open(F, read, In), json_read_dict(In, Run), close(In)) ; Run = none ).

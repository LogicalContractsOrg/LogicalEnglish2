/*  Build the Daml twins into lps2/examples/migration/daml (le2_paths:twins_dir/2).

    From /work (the LE2 checkout):

        ./myswipl.sh -q migration/daml/build.pl                 # every project
        ./myswipl.sh -q migration/daml/build.pl -- skeleton token

    Needs the corpus (fetch_sources.sh). The expected final states come from
    the oracle's runs (runs/, made by daml_oracle.pl on a Canton sandbox): with
    them each twin says what Daml ends with, and test_daml.pl compares.
*/

:- initialization(main, main).

:- use_module('../le2_paths', [twins_dir/2]).

:- prolog_load_context(directory, D),
   twins_dir(daml, Out),
   asserta(user:daml_out_dir(Out)), asserta(user:daml_build_dir(D)).

:- use_module(library(main)).
:- use_module(library(filesex)).
:- use_module(corpus).
:- use_module(daml_twin).
:- use_module(daml_oracle).
:- use_module('../le2_paths', []).
:- use_module(le2(le_migration)).

main(Argv) :-
    user:daml_out_dir(Out),
    make_directory_path(Out),
    (   Argv == [] -> findall(Id, project(Id, _, _, _), Ids) ; maplist([A, I]>>atom_string(I, A), Argv, Ids) ),
    forall(member(Id, Ids),
           ( format("~w ... ", [Id]), flush_output,
             (   catch(build(Id, Out), E, ( print_message(error, E), fail )) -> true
             ;   format("FAILED~n")
             ) )).

build(Id, Root) :-
    project(Id, Title, Tpl, Rels),
    cache_dir(C),
    atomic_list_concat([Root, '/', Id], Dir),
    make_directory_path(Dir),
    findall(F, ( member(R, Rels), atomic_list_concat([C, '/', Tpl, '/', R], F) ), Files),
    forall(( member(R, Rels), atomic_list_concat([C, '/', Tpl, '/', R], Src),
             atomic_list_concat([Dir, '/sources/', R], Dst), file_directory_name(Dst, DD) ),
           ( make_directory_path(DD), copy_file(Src, Dst) )),
    notice(Dir, Tpl),
    oracle_final_states(Id, States),
    project_migrations(project(Id, Title, Files), [id(Id), sources(Rels), final_states(States)], Migs),
    forall(member(mig(Name, Mig), Migs),
           ( write_migration(Mig, Dir, Name, report(LE, Issues, Counts, _)),
             include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
             format("~n    ~w  ~w  ~w writer error(s)", [LE, Counts, NE]) )),
    nl.

notice(Dir, Tpl) :-
    atomic_list_concat([Dir, '/sources/NOTICE.txt'], N),
    setup_call_cleanup(open(N, write, S),
        format(S, "The Daml sources here are the Daml SDK's template `~w` (dpm new ~w --template ~w,~nSDK 3.5.10), Copyright (c) 2025 Digital Asset (Switzerland) GmbH and/or its affiliates,~nlicensed under the Apache License, Version 2.0: https://www.apache.org/licenses/LICENSE-2.0~nThey are unmodified. The licence is LICENSE (the one the SDK's `dpm new` ships).~n", [Tpl, Tpl, Tpl]),
        close(S)),
    user:daml_build_dir(H), atomic_list_concat([H, '/LICENSE-Apache-2.0.txt'], L),
    atomic_list_concat([Dir, '/sources/LICENSE'], L1), copy_file(L, L1).

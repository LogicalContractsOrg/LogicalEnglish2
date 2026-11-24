/*  Build the OpenFisca and PolicyEngine twins. The packages are AGPL-3.0 and
    a twin is a translation of its package, so the twins are never written
    into this repository (Apache-2.0): le2_paths:twins_dir/2 names the
    private place, examples/migration/{openfisca,policyengine} under
    le2_paths:private_root/1.

        ./myswipl.sh -q migration/openfisca/of_build.pl [-- programme ...]

    For each programme of corpus.pl: of_run.py reads the package (its
    variables, parameters and tests) into .cache/out/of/<programme>.* and
    runs its tests on the package's engine (of_extract.py, of_oracle.py), and the twin
    builder of migration/rulespec writes the program, its ledger and its
    originals.
*/

:- initialization(main, main).

:- use_module(library(main)).
:- use_module(library(filesex)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(le2(le_migration)).
:- use_module(corpus).
:- use_module('../rulespec/rulespec_reader').
:- use_module('../rulespec/rulespec_twin').

here(D) :- module_property(openfisca_corpus, file(F)), file_directory_name(F, D).

main(Argv) :-
    (   Argv == [] -> findall(P, programme(P, _, _, _, _), Ps) ; maplist([A, P]>>atom_string(P, A), Argv, Ps) ),
    findall(D, ( member(P, Ps), programme(P, D, _, _, _) ), Ds0), sort(Ds0, Ds),
    forall(member(D, Ds),
           ( include({D}/[P]>>programme(P, D, _, _, _), Ps, DPs),
             catch(( ( getenv('OF_SKIP_EXTRACT', _) -> true ; timed(extract(D, DPs), D, 'the reader and the engine') ),
                     forall(member(P, DPs), catch(timed(build(P), P, 'the twin'), E, print_message(error, E))) ),
                   E2, print_message(error, E2)) )).

%   What each phase of a build costs, so that the next round knows where the
%   time goes (the income tax takes about two hours, and almost all of it is
%   the twin: writing a program of 5.7 MB, parsing it and running its 1,948
%   expectations). README.md, "where to pick this up", build time.
timed(Goal, Name, What) :-
    get_time(T0),
    setup_call_cleanup(true, Goal,
                       ( get_time(T1), DT is T1 - T0,
                         Mins is floor(DT / 60), Secs is round(DT) mod 60,
                         format("~w: ~w took ~w min ~w s~n", [Name, What, Mins, Secs]) )).

%   One load of the package for all its programmes: of_extract.py, then
%   of_oracle.py.
extract(Dialect, Ps) :-
    here(H), atomic_list_concat([H, '/.cache'], C), atomic_list_concat([C, '/out'], Out),
    venv(Dialect, V), atomic_list_concat([C, '/', V, '/bin/python'], Py),
    atomic_list_concat([H, '/of_run.py'], Run),
    findall(A, ( member(P, Ps), programme(P, Dialect, _, Roots, Tests), atomic_list_concat(Roots, ',', RA),
                 ( member(A, ['--programme', P, '--roots', RA])
                 ; programme_within(P, W), atomic_list_concat(W, ',', WA), member(A, ['--within', WA])
                 ; member(T0, Tests), member(A, ['--tests', T0]) ) ), Args),
    run(C, Py, [Run, Dialect, Out|Args]).

%   One environment per engine: openfisca-france needs an openfisca-core
%   below 45 (Phase 3b′), and the country template has an environment of its
%   own (fetch_sources.sh). PolicyEngine's two packages run on
%   policyengine-core, not on openfisca-core, and share `venv`.
venv(france, 'venv-fr') :- !.
venv(template, 'venv-ct') :- !.
venv(_, venv).

%   Decision 3 of the October plan: a French source gives a French twin
%   (Français Logique).
twin_language(france, fr) :- !.
twin_language(_, en).

build(P) :-
    programme(P, _Dialect, Group, Roots, _Tests),
    here(H), atomic_list_concat([H, '/.cache'], C), atomic_list_concat([C, '/out'], Out),
    atomic_list_concat([Out, '/of/', P, '.yaml'], ModFile),
    atomic_list_concat([Out, '/of/', P, '.run.json'], RunFile),
    atomic_list_concat([Out, '/of/', P, '.json'], InfoFile),
    read_json(RunFile, Run), read_json(InfoFile, Info),
    atom_concat('of:', P, Id),
    twins_dir(Group, TD0), atomic_list_concat([TD0, '/', P], Dir),
    make_directory_path(Dir),
    copy_sources(Info, ModFile, C, Dir),
    copy_tables(Out, P, Dir),
    get_dict(package, Info, Pkg),
    programme(P, Dialect, _, _, _), twin_language(Dialect, Lang),
    (   Lang == fr
    ->  format(string(Header), "~w — un jumeau des variables de ~w que ~w lisent, avec les paramètres qu'elles utilisent et les tests du paquet lui-même.~nTraduit par LE2 migration/openfisca. Source : licence AGPL-3.0, qui s'applique aussi à cette traduction (un jumeau non publié).",
               [P, Pkg, Roots])
    ;   format(string(Header), "~w — a twin of the variables of ~w that ~w read, with the parameters they use and the package's own tests.~nTranslated by LE2 migration/openfisca. Source: AGPL-3.0, which applies to this translation too (a twin that is not published).",
               [P, Pkg, Roots])
    ),
    with_upload([Id-ModFile], [],
                module_migration(Id, [oracle_runs(Run), header(Header), language(Lang)], Migration0)),
    relabel(Migration0, Pkg, Migration1),
    live_cases(Migration1, Migration),
    write_migration(Migration, Dir, P, report(LE, Issues, Counts, Fid)),
    include(issue_of(error), Issues, Errs), length(Errs, NE),
    include(issue_of(warning), Issues, Warns), length(Warns, NW),
    ( Fid = fidelity(Pa, Fa, U, _) -> true ; Pa = '-', Fa = '-', U = '-' ),
    format("~w  ~w  tests ~w pass ~w fail ~w error  ~w writer error(s), ~w warning(s)~n",
           [LE, Counts, Pa, Fa, U, NE, NW]),
    forall(member(E, Errs), ( print(E), nl )),
    forall(member(W, Warns), ( print(W), nl )).

%   A build says what the writer remarked as well as what it could not write:
%   a remark of its own (a group it had to write with the extensions, say) is
%   a reason a twin may answer nothing, and counting only the errors hid it.
issue_of(Severity, issue(Severity, _, _)).

relabel(migration(Meta0, IR, L, T), Pkg, migration(Meta, IR, L, T)) :-
    selectchk(source(_), Meta0, Meta1), selectchk(translator(_), Meta1, Meta2),
    selectchk(licence(_), Meta2, Meta3),
    Meta = [source(Pkg), translator('LE2 migration/openfisca'), licence('AGPL-3.0 (the package)')|Meta3].

%   The cases with at least one expectation the twin can check: a case whose
%   every expectation waits for residue, or lies outside the twin's reach,
%   is left out of the program and counted in the ledger.
live_cases(M0, migration(Meta, IR, Ledger, Live)) :-
    le_migration:migration_pending(M0, migration(Meta, IR, Ledger0, Tests)),
    partition(live_test, Tests, Live, Dead),
    length(Dead, ND), length(Tests, NT),
    (   ND =:= 0 -> Ledger = Ledger0
    ;   format(string(Note), "~w of the ~w test cases left out of the program: each of their expectations waits for a residue block, or is a case the twin cannot state (the run file says which)", [ND, NT]),
        append(Ledger0, [entry("test cases", tests, approximated, Note, none, none)], Ledger)
    ).

live_test(test(_, _, _, _, Es)) :- member(E, Es), E = expects(_, _), !.
live_test(test(_, _, _, _, Es)) :- member(E, Es), E = expects(_, _, _), !.

run(Cwd, Py, Args) :-
    process_create(Py, Args, [cwd(Cwd), stdout(pipe(O)), stderr(pipe(E)), process(Pid)]),
    read_string(O, _, Out), read_string(E, _, Err), close(O), close(E),
    process_wait(Pid, Status),
    format("~s", [Out]),
    (   Status == exit(0) -> true ; format(user_error, "~s", [Err]), throw(error(subprocess_failed(Args), _)) ).

read_json(F, D) :- setup_call_cleanup(open(F, read, In), json_read_dict(In, D), close(In)).

%   The originals: the Python of each variable, the parameter files, the
%   test files, under sources/ as they are in the repository; and what the
%   reader made of them, sources/of/<programme>.yaml, the text the rules cite.
copy_sources(Info, ModFile, Cache, Dir) :-
    atomic_list_concat([Dir, '/sources/of'], SO), make_directory_path(SO),
    file_base_name(ModFile, B), atomic_list_concat([SO, '/', B], To), copy_file(ModFile, To),
    file_name_extension(Stem, yaml, ModFile), atom_concat(Stem, '.test.yaml', TF),
    ( exists_file(TF) -> atomic_list_concat([SO, '/', Stem, '.test.yaml'], _), file_base_name(TF, TB), atomic_list_concat([SO, '/', TB], TTo), copy_file(TF, TTo) ; true ),
    get_dict(variables, Info, Vs), dict_pairs(Vs, _, Pairs),
    findall(F, ( member(_-V, Pairs), get_dict(file, V, F0), F0 \== null, atom_string(F, F0) ), Fs1),
    get_dict(parameter_files, Info, PFs0), maplist([X, Y]>>atom_string(Y, X), PFs0, PFs),
    get_dict(test_files, Info, TFs0), maplist([X, Y]>>atom_string(Y, X), TFs0, TFs),
    append([Fs1, PFs, TFs], All0), sort(All0, All),
    forall(member(F, All), copy_original(Cache, F, Dir)).

%   The tables by code the reader wrote as CSV files (a commune's zone):
%   beside the program, which loads them.
copy_tables(Out, P, Dir) :-
    atomic_list_concat([Out, '/of/', P, '.tables'], TD),
    (   exists_directory(TD)
    ->  directory_files(TD, Fs),
        forall(( member(F, Fs), file_name_extension(_, csv, F) ),
               ( atomic_list_concat([TD, '/', F], From), atomic_list_concat([Dir, '/', F], To), copy_file(From, To) ))
    ;   true
    ).

copy_original(Cache, F, Dir) :-
    (   atom_concat(Cache, Rel0, F), atom_concat('/', Rel, Rel0) -> true ; file_base_name(F, Rel) ),
    atomic_list_concat([Dir, '/sources/', Rel], To),
    file_directory_name(To, TD), make_directory_path(TD),
    ( exists_file(F) -> copy_file(F, To) ; true ).

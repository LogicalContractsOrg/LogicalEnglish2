/** <module> Writing the DMN twins

    build_collection(+Collection, +Filter): every model of the collection
    (dmn_corpus:collection/3) whose file name contains Filter, written as a
    twin with its tests, its ledger and its original under sources/. The
    public collections go to LE2's examples/migration/dmn/<collection>/, the
    bruidsschat to this repository's examples/migration/dmn/bruidsschat/
    (dmn_corpus:twin_place/2). A summary line per model and a total are
    printed, and appended to runs/build-<collection>.txt.
*/

:- module(dmn_build, [build_collection/2, build_model/4, twin_root/2, model_dir_name/2, diagnose_model/3]).

:- use_module(dmn_home).
:- use_module(library(filesex)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(http/json)).
:- use_module('../le2_paths', [twins_dir/2, private_root/1]).
:- use_module(le2(le_migration)).
:- use_module(corpus).
:- use_module(gate, [collection_files/2]).
:- use_module(dmn_tests).
:- use_module(dmn_twin).
:- use_module(dmn_reader).
:- use_module(dmn_cases).
:- use_module(dmn_oracle).
:- use_module(dmn_adapter_map).

twin_root(C, Root) :-
    (   dmn_corpus:twin_place(C, private)
    ->  private_root(R), atomic_list_concat([R, '/examples/migration/dmn/', C], Root)
    ;   twins_dir(dmn, D), atomic_list_concat([D, '/', C], Root)
    ).

build_collection(C, Filter) :-
    distinct_files(C, Files0),
    include(file_matches(Filter), Files0, Files),
    twin_root(C, Root),
    dmn_path('runs/build-', LogStem), atomic_list_concat([LogStem, C, '.txt'], Log),
    setup_call_cleanup(open(Log, write, Out),
        ( foldl(build_one(C, Root, Out), Files, t(0, 0, 0, 0)-t(0,0,0), Total-Ledger),
          Total = t(NM, P, Fl, E), Ledger = t(Enc, App, Res),
          format(Out, "TOTAL ~w: ~d models, ~d pass, ~d fail, ~d error; ledger ~d encoded, ~d approximated, ~d residue~n",
                 [C, NM, P, Fl, E, Enc, App, Res]),
          format("TOTAL ~w: ~d models, ~d pass, ~d fail, ~d error; ledger ~d encoded, ~d approximated, ~d residue~n",
                 [C, NM, P, Fl, E, Enc, App, Res]) ),
        close(Out)).

%   One file per model: a collection that copies a model to several places
%   (RONL keeps each in its examples, its fixtures and its frontend) is
%   built once, from its examples/organizations copy when there is one.
distinct_files(C, Files) :-
    collection_files(C, Fs),
    findall(Key-F, ( member(F, Fs), catch(dmn_read_file(F, M), _, fail),
                     dmn_info(M, name, N), dmn_info(M, namespace, NS), Key = NS-N ), Keyed),
    msort(Keyed, Sorted), group_pairs_by_key(Sorted, Groups),
    findall(F, ( member(_-G, Groups), preferred_copy(G, F) ), Files0),
    msort(Files0, Files).

preferred_copy(G, F) :- member(F, G), sub_atom(F, _, _, _, '/examples/organizations/'), !.
preferred_copy([F|_], F).

file_matches('', _) :- !.
file_matches(Filter, F) :- file_base_name(F, B), sub_atom(B, _, _, _, Filter).

build_one(C, Root, Out, File, T0-L0, T-L) :-
    (   catch(build_model(C, Root, File, report(_, Issues, counts(En, Ap, Re), Fid)), Err,
              ( print_message(error, Err), fail ))
    ->  fid_counts(Fid, P, F, E),
        length(Issues, NI),
        file_base_name(File, B),
        format(Out, "~w  ledger(~d,~d,~d)  pass ~d fail ~d error ~d  ~d writer issue(s)~n", [B, En, Ap, Re, P, F, E, NI]),
        format("~w  ledger(~d,~d,~d)  pass ~d fail ~d error ~d~n", [B, En, Ap, Re, P, F, E]),
        T0 = t(M0, P0, F0, E0), M1 is M0 + 1, P1 is P0 + P, F1 is F0 + F, E1 is E0 + E, T = t(M1, P1, F1, E1),
        L0 = t(A0, B0, C0), A1 is A0 + En, B1 is B0 + Ap, C1 is C0 + Re, L = t(A1, B1, C1)
    ;   file_base_name(File, B), format(Out, "~w  NOT BUILT~n", [B]), format("~w  NOT BUILT~n", [B]),
        T = T0, L = L0
    ).

fid_counts(none, 0, 0, 0) :- !.
fid_counts(fidelity(P, F, E, _), P, F, E) :- !.
fid_counts(fidelity(P, F, E), P, F, E) :- !.
fid_counts(_, 0, 0, 0).

%!  build_model(+Collection, +Root, +File, -Report) is semidet.
build_model(C, Root, File, Report) :-
    model_dir_name(File, Name),
    atomic_list_concat([Root, '/', Name], Dir),
    make_directory_path(Dir),
    tests_of(C, File, Cases, TestDoc),
    file_base_name(File, Base),
    format(atom(Doc), '~w', [Base]),
    ( TestDoc == none -> D2 = Doc ; D2 = TestDoc ),
    model_migration(File, [tests(Cases), document(D2), program(Name), collection(C)], Migration0),
    with_sources(Migration0, File, Dir, Migration),
    Migration = migration(_, program(Header, _), _, _),
    (   memberchk(includes(Libs), Header) -> forall(member(L, Libs), copy_library(L, Dir)) ; true ),
    write_adapter_map(File, Dir, Name),
    write_migration(Migration, Dir, Name, Report).

%   The original beside the twin, under sources/, and cited.
with_sources(migration(Meta, program(H, Items), L, T), File, Dir, migration(Meta, program(H, [document(the_model, [text(Rel)])|Items]), L, T)) :-
    atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
    file_base_name(File, B), atomic_list_concat([SD, '/', B], Dst),
    copy_file(File, Dst),
    atomic_list_concat(['sources/', B], Rel).

tests_of(C, File, Cases, Doc) :-
    memberchk(C, [tck, tck3]), !,
    tck_test_files(File, TFs),
    findall(Case, ( member(TF, TFs), tck_cases(TF, _, Cs), member(Case, Cs) ), Cases),
    ( TFs = [TF1|_] -> file_base_name(TF1, Doc) ; Doc = none ).
tests_of(bdt, File, Cases, Doc) :-
    dmn_read_file(File, M), dmn_info(M, name, Name),
    dmn_path('.cache/bdt/library-api/test', BrunoDir), bruno_cases(BrunoDir, Name, Cases),
    Cases \== [], !,
    format(atom(Doc), 'the Bruno requests of ~w', [Name]).
%   The client examples' models: the cases written for them in clients/
%   (the requests of the examples' own documentation, and a few more),
%   answered by the oracle; every decision the oracle evaluates is expected.
tests_of(clients, File, Cases, Doc) :-
    file_base_name(File, B), file_name_extension(Stem, _, B),
    dmn_path('clients/', ClientsDir), atomic_list_concat([ClientsDir, Stem, '.cases.json'], CF),
    exists_file(CF), !,
    (   camunda_file(File) -> Doc = 'the oracle, Camunda 7.23\'s DMN engine, on the cases of clients/'
    ;   Doc = 'the oracle, Drools 10.2.0, on the cases of clients/'
    ),
    setup_call_cleanup(open(CF, read, In, [encoding(utf8)]), json_read_dict(In, Js, [value_string_as(string)]), close(In)),
    findall(case(Id, Desc, Inputs, all),
            ( member(J, Js), atom_string(Id, J.id), atom_string(Desc, J.description),
              dict_pairs(J.inputs, _, Ps),
              findall(N-V, ( member(K-JV, Ps), atom_string(K, NS), atom_string(N, NS), dmn_tests:json_v(JV, V) ), Inputs) ),
            Cases0),
    (   camunda_file(File)
    ->  camunda_answers(File, Cases0, Cases1)
    ;   oracle_answers([File], Cases0, [normalise], Cases1)
    ),
    include([case(_, _, _, R)]>>(R \== []), Cases1, Cases).
%   A model with no tests of its own: generated cases, answered by the
%   oracle; a BDT model with the collection's other models beside it, for
%   its imports.
%   A RONL model of Camunda Modeler: Camunda 7's dialect, run by the
%   explorer on Operaton (Camunda 7's fork). Its oracle is Camunda 7.23's
%   own engine, which reads a boolean expression in an input entry as the
%   test (dmn_twin: camunda_reading/1) where Drools compares the input with
%   it. Camunda refuses a case that leaves an input out: every input is
%   given, null where the case does not answer it.
tests_of(ronl, File, Cases, 'the oracle, Camunda 7.23\'s DMN engine, on generated cases') :-
    camunda_file(File), !,
    dmn_read_file(File, Model),
    generated_cases(Model, Generated0),
    findall(N, ( member(case(_, _, In, _), Generated0), member(N-_, In) ), Ns0), sort(Ns0, Ns),
    maplist({Ns}/[case(I, D, In0, _), case(I, D, In, all)]>>
              findall(N-V, ( member(N, Ns), ( memberchk(N-V0, In0) -> V = V0 ; V = null ) ), In),
            Generated0, Generated),
    camunda_answers(File, Generated, Answered),
    maplist(frontier(Model), Answered, Cases0),
    include([case(_, _, _, R)]>>(R \== []), Cases0, Cases).
tests_of(C, File, Cases, 'the oracle, Drools 10.2.0, on generated cases') :-
    dmn_read_file(File, Model),
    generated_cases(Model, Generated0),
    maplist([case(I, D, In, _), case(I, D, In, all)]>>true, Generated0, Generated),
    ( memberchk(C, [ronl, clients]) -> Opts = [normalise] ; Opts = [] ),
    (   C == bdt
    ->  collection_files(bdt, All), exclude(==(File), All, Others), Models = [File|Others]
    ;   Models = [File]
    ),
    oracle_answers(Models, Generated, Opts, Answered),
    maplist(frontier(Model), Answered, Cases0),
    include([case(_, _, _, R)]>>(R \== []), Cases0, Cases), !.

tests_of(_, _, [], none).

%   The expected results of a generated case: the decisions the oracle
%   evaluated that no other evaluated decision requires — the last ones,
%   where the oracle reached them, and else the furthest it got (a model
%   that requires a node it does not hold, as some of the bruidsschat do,
%   still tests what it can compute).
frontier(model(_, Items), case(Id, D, In, Rs), case(Id, D, In, Front)) :-
    findall(N, member(result(N, _, _), Rs), Evaluated),
    findall(R, ( member(R, Rs), R = result(N, _, _),
                 member(decision(DId, N, _, _, _, _), Items),
                 \+ ( member(decision(_, N2, _, reqs(Ds, _, _), _, _), Items), memberchk(N2, Evaluated),
                      member(H, Ds), dmn_href_id(H, DId) ) ),
            Front).

%   The folder of a twin: the model file's name, or the model's own name
%   when the file's name is an identifier (BDT's `P-4fc360de-…-1.0.0.dmn`).
model_dir_name(File, Name) :-
    file_base_name(File, B), file_name_extension(Stem0, _, B),
    (   identifier_name(Stem0), catch(dmn_read_file(File, M), _, fail), dmn_info(M, name, MN)
    ->  Stem = MN
    ;   Stem = Stem0
    ),
    atom_codes(Stem, Cs),
    maplist([C0, C]>>( code_type(C0, alnum) -> code_type(C, to_lower(C0)) ; C = 0'_ ), Cs, Ds0),
    collapse(Ds0, Ds), atom_codes(Name, Ds).

identifier_name(Stem) :-
    split_string(Stem, "-_.", "", Parts),
    member(P, Parts), string_length(P, 12), string_codes(P, Cs),
    forall(member(C, Cs), code_type(C, xdigit(_))), !.

collapse([], []).
collapse([0'_, 0'_|Cs], Ds) :- !, collapse([0'_|Cs], Ds).
collapse([C|Cs], [C|Ds]) :- collapse(Cs, Ds).

%!  diagnose_model(+Collection, +Filter, +Dir) is det.
%
%   One model built into Dir with an expectation for EVERY decision (the
%   oracle answers them all), and a case or two: a failing twin's first
%   wrong decision is then the one whose inputs are all right.
diagnose_model(C, Filter, Dir) :-
    distinct_files(C, Fs), include(file_matches(Filter), Fs, [File|_]),
    dmn_read_file(File, Model),
    generated_cases(Model, Generated0),
    ( Generated0 = [G1, G2|_] -> Gen1 = [G1, G2] ; Gen1 = Generated0 ),
    maplist([case(I, D, In, _), case(I, D, In, all)]>>true, Gen1, Generated),
    ( memberchk(C, [ronl, clients]) -> Opts = [normalise] ; Opts = [] ),
    oracle_answers([File], Generated, Opts, Cases),
    model_dir_name(File, Name),
    make_directory_path(Dir),
    model_migration(File, [tests(Cases), document(diagnosis), program(Name), collection(C)], Migration),
    Migration = migration(_, program(Header, _), _, _),
    (   memberchk(includes(Libs), Header) -> forall(member(L, Libs), copy_library(L, Dir)) ; true ),
    write_migration(Migration, Dir, Name, report(LE, _, _, Fid)),
    format("~w~n~q~n", [LE, Fid]).


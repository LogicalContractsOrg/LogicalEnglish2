/** <module> The oracle of the Daml twins: Daml itself, on a Canton sandbox

    Each Daml Script of a project is run by Daml — on a local Canton sandbox
    (`dpm sandbox`, Canton 3.5) when one listens on localhost:6865, else on
    Daml Script's in-memory ledger (`--ide-ledger`) — and the active
    contracts it ends with are read back: a generated module
    (OracleWrapper.daml) runs the script, then asks every party the script
    allocated for the contracts of every template (`query`), and returns
    them; `dpm script --output-file` writes them as JSON. The run is kept
    in runs/<project>__<script>.json, so a build needs neither Daml nor the
    sandbox, and says which ledger answered.

    Several scripts share one sandbox: each is built as a package of its
    own (a DAR named after the run) and its party hints and user ids get the
    run's suffix (`"Alice"` -> `"Alice_r3"`), the only change made to the
    sources — the parties read back are the hints again (`alice`).

    The twin's final state (`lps state` in LPS2) is compared with these
    contracts' payloads, the contract ids left out (the ledger's are hashes,
    the twin's the names the script binds).
*/

:- module(daml_oracle, [
    oracle_final_states/2,     % +Project, -[Script-Fluents]
    oracle_run/2,              % +Project, +Options
    twin_final_state/2,        % +LEFile, -Fluents (ids dropped)
    sandbox_up/0,
    dpm/1
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module(library(process)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(socket)).
:- use_module(library(md5), []).
:- use_module(corpus).
:- use_module(daml_model).
:- use_module(daml_twin).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).

dpm(P) :- ( getenv('DPM', P0) -> P = P0 ; expand_file_name('~/.dpm/bin/dpm', [P]) ).

runs_dir(D) :- here(H), atomic_list_concat([H, '/runs'], D).
work_dir(D) :- here(H), atomic_list_concat([H, '/oracle/work'], D).

%   A Canton sandbox listens on localhost:6865.
sandbox_up :-
    catch(( tcp_connect(localhost:6865, S, []), close(S) ), _, fail).

		 /*******************************
		 *          RUNNING DAML        *
		 *******************************/

%!  oracle_run(+Project, +Options) is det.
%
%   Runs every script of Project on Daml, writing runs/. Options:
%   scripts(Names) (default all), force(true) (run again).
oracle_run(Id, Options) :-
    project(Id, _, Tpl, Rels),
    cache_dir(C),
    findall(F, ( member(R, Rels), atomic_list_concat([C, '/', Tpl, '/', R], F) ), Files),
    project_model(Files, Model),
    findall(N, ( script_fun(Model, fun(_, N, [], _)) ), Scripts0),
    option(scripts(Scripts), Options, Scripts0),
    forall(member(S, Scripts), run_script(Id, Model, Tpl, Rels, S, Options)).

run_script(Id, Model, Tpl, Rels, Script, Options) :-
    runs_dir(RD), make_directory_path(RD),
    format(atom(Out), '~w/~w__~w.json', [RD, Id, Script]),
    (   exists_file(Out), \+ option(force(true), Options) -> true
    ;   ( sandbox_up -> Ledger = canton ; Ledger = ide ),
        run_tag(Tag),
        package_dir(Id, Script, Tag, PD),
        write_package(Model, Tpl, Rels, Script, Tag, PD, Map),
        dpm(Dpm),
        run_dpm(Dpm, [build], PD, BuildOut, BS),
        (   BS \== exit(0)
        ->  format(user_error, "daml build failed for ~w ~w:~n~w~n", [Id, Script, BuildOut]),
            Result = _{error: "build failed", log: BuildOut}
        ;   project_package_name(PD, PName),
            format(atom(Dar), '~w/.daml/dist/~w-0.0.1.dar', [PD, PName]),
            format(atom(JOut), '~w/acs.json', [PD]),
            run_on(Ledger, Dpm, Dar, PD, JOut, Result0),
            (   Ledger == canton, get_dict(error, Result0, _)
            ->  %  a script Canton refuses (setTime needs static time): the
                %  in-memory ledger, and the reason kept
                run_on(ide, Dpm, Dar, PD, JOut, Result1),
                Result = Result1.put(canton_refused, Result0.log), Ledger1 = ide
            ;   Result = Result0, Ledger1 = Ledger
            )
        ),
        ( var(Ledger1) -> Ledger1 = Ledger ; true ),
        ledger_name(Ledger1, LN),
        pairs_to_json(Map, JMap),
        R1 = Result.put(_{project: Id, script: Script, ledger: LN, tag: Tag, templates: JMap}),
        setup_call_cleanup(open(Out, write, S), json_write_dict(S, R1, [width(100)]), close(S))
    ).

run_on(Ledger, Dpm, Dar, PD, JOut, Result) :-
    (   Ledger == canton
    ->  Args = [script, '--dar', Dar, '--script-name', 'OracleWrapper:main', '--ledger-host', localhost,
                '--ledger-port', '6865', '--upload-dar', true, '--output-file', JOut]
    ;   Args = [script, '--dar', Dar, '--script-name', 'OracleWrapper:main', '--ide-ledger', '--static-time', '--output-file', JOut]
    ),
    catch(delete_file(JOut), _, true),
    run_dpm(Dpm, Args, PD, RunOut, RS),
    (   RS == exit(0), exists_file(JOut)
    ->  setup_call_cleanup(open(JOut, read, JS), json_read_dict(JS, ACS), close(JS)),
        Result = _{acs: ACS}
    ;   last_lines(RunOut, 12, Tail), Result = _{error: "the script failed", log: Tail}
    ).

last_lines(S, N, T) :- split_string(S, "\n", "", Ls), length(Ls, L), K is max(0, L - N), length(Pre, K), append(Pre, Last, Ls), atomic_list_concat(Last, '\n', T).

ledger_name(canton, "a Canton 3.5 sandbox (dpm sandbox), over the Ledger API") :- !.
ledger_name(ide, "Daml Script's in-memory ledger (dpm script --ide-ledger)").

pairs_to_json(Map, J) :- findall(_{field: K, template: T, module: M}, member(K-(M:T), Map), J).

%   (the process too: runs in parallel share the sandbox's party hints)
run_tag(Tag) :-
    get_time(T), I is floor(T * 1000) mod 100000000, current_prolog_flag(pid, P),
    format(atom(Tag), 'r~wp~w', [I, P]).

package_dir(Id, Script, Tag, PD) :-
    work_dir(W), format(atom(PD), '~w/~w__~w__~w', [W, Id, Script, Tag]).

snake_dash(A, B) :- atom_codes(A, Cs), maplist([C, D]>>( C == 0'_ -> D = 0'- ; D = C ), Cs, Ds), atom_codes(B, Ds).

%   (stderr to a file, read after: the compiler's errors are there)
run_dpm(Dpm, Args, Dir, Out, Status) :-
    tmp_file(dpm_err, EF),
    setup_call_cleanup(
        ( open(EF, write, ES), process_create(Dpm, Args, [cwd(Dir), stdout(pipe(O)), stderr(stream(ES)), process(P)]) ),
        ( read_string(O, _, Out1), process_wait(P, Status, [timeout(900)]) ),
        ( close(O), close(ES) )),
    read_file_to_string(EF, Err, []), delete_file(EF),
    string_concat(Out1, Err, Out).

%   The package: daml.yaml, the sources (party hints suffixed), and the
%   wrapper. Map: [Field-(Module:Template)].
write_package(Model, Tpl, Rels, Script, Tag, PD, Map) :-
    make_directory_path(PD),
    project_package_name(PD, PName),
    format(atom(Y), '~w/daml.yaml', [PD]),
    setup_call_cleanup(open(Y, write, S),
        format(S, "sdk-version: 3.5.10~nname: ~w~nsource: daml~nversion: 0.0.1~ndependencies:~n  - daml-prim~n  - daml-stdlib~n  - daml-script~nbuild-options:~n  - -Wno-template-interface-depends-on-daml-script~n", [PName]),
        close(S)),
    cache_dir(C),
    forall(member(R, Rels),
           ( atomic_list_concat([C, '/', Tpl, '/', R], Src), module_path(R, MP),
             atomic_list_concat([PD, '/daml/', MP], Dst), file_directory_name(Dst, DD), make_directory_path(DD),
             read_file_to_string(Src, Text0, [encoding(utf8)]), suffix_hints(Text0, Tag, Text),
             setup_call_cleanup(open(Dst, write, O, [encoding(utf8)]), write(O, Text), close(O)) )),
    wrapper(Model, Script, Map, WText),
    atomic_list_concat([PD, '/daml/OracleWrapper.daml'], WF),
    setup_call_cleanup(open(WF, write, O2), write(O2, WText), close(O2)).

%   The package's name: oracle-<project>-<script>-<tag>, as dpm writes the
%   DAR's (the build names it).
project_package_name(PD, Name) :-
    file_base_name(PD, B), atomic_list_concat(Ps, '__', B),
    atomic_list_concat([oracle|Ps], '-', N0), snake_dash(N0, N1),
    %  (every part of a package name starts with a letter: token-test-1 -> token-test-n1)
    atomic_list_concat(Segs0, '-', N1),
    maplist([S0, S]>>( sub_atom(S0, 0, 1, _, C), char_type(C, digit) -> atom_concat(n, S0, S) ; S = S0 ), Segs0, Segs),
    atomic_list_concat(Segs, '-', Name).

%   daml/Tests/Iou.daml -> Tests/Iou.daml; main/daml/Main.daml -> Main.daml
module_path(R, MP) :-
    atomic_list_concat(Parts, '/', R),
    (   append(_, [daml|Rest], Parts), Rest \== [] -> atomic_list_concat(Rest, '/', MP) ; MP = R ).

%   `"Alice"` in a party hint or user id -> `"Alice_r3"`.
suffix_hints(Text0, Tag, Text) :-
    foldl(suffix_after(Tag), ["allocateParty \"", "PartyIdHint \"", "allocatePartyWithHint \"", "validateUserId \""], Text0, Text).

suffix_after(Tag, Prefix, T0, T) :-
    atomic_list_concat(Parts, Prefix, T0),
    (   Parts = [First|Rest]
    ->  maplist(suffix_part(Tag), Rest, Rest1), atomic_list_concat([First|Rest1], Prefix, T1), atom_string(T1, T)
    ;   T = T0
    ).

suffix_part(Tag, P0, P) :-
    (   sub_atom(P0, B, 1, _, '"') -> sub_atom(P0, 0, B, _, H), sub_atom(P0, B, _, 0, R),
        format(atom(P), '~w_~w~w', [H, Tag, R])
    ;   P = P0
    ).

%   The wrapper: run the script, then the active contracts of every
%   template, as every allocated party sees them.
wrapper(Model, Script, Map, Text) :-
    Model = model(_, Ts, Funs, _, _),
    memberchk(fun(SM, Script, [], _), Funs),
    findall(M, member(tpl(_, M, _, _, _, _, _, _), Ts), Ms0), sort([SM|Ms0], Ms),
    findall(K-(M:T), ( nth1(I, Ts, tpl(T, M, _, _, _, _, _, _)), format(atom(K), 'c~w', [I]) ), Map),
    with_output_to(string(Text), (
        format("module OracleWrapper where~n~nimport Daml.Script~nimport DA.List (dedupOn)~n"),
        forall(member(M, Ms), format("import qualified ~w~n", [M])),
        format("~ndata OracleAcs = OracleAcs with~n"),
        forall(member(K-(M:T), Map), format("    ~w : [(ContractId ~w.~w, ~w.~w)]~n", [K, M, T, M, T])),
        format("  deriving (Eq, Show)~n~nmain : Script OracleAcs~nmain = do~n  _ <- ~w.~w~n", [SM, Script]),
        format("  ps <- listKnownParties~n  let parties = map (\\d -> d.party) ps~n"),
        forall(member(K-(M:T), Map),
               format("  ~w <- fmap (dedupOn fst . concat) (mapA (\\p -> query @~w.~w p) parties)~n", [K, M, T])),
        findall(K, member(K-_, Map), Ks), atomic_list_concat(Ks, '; ', KL),
        format("  pure OracleAcs with ~w~n", [KL]) )).

		 /*******************************
		 *        READING THE RUNS      *
		 *******************************/

%!  oracle_final_states(+Project, -States) is det.
%
%   [Script-Fluents] from runs/: each active contract as the twin's fluent
%   without its id (`asset(alice, alice, "TV")`), sorted.
oracle_final_states(Id, States) :-
    runs_dir(RD),
    (   project(Id, _, Tpl, Rels)
    ->  cache_dir(C),
        findall(F, ( member(R, Rels), atomic_list_concat([C, '/', Tpl, '/', R], F) ), Files),
        catch(project_model(Files, Model), _, fail),
        compile_project(Model, Twin, _), twin_vocabulary(Twin, Voc),
        format(atom(Pat), '~w/~w__*.json', [RD, Id]), expand_file_name(Pat, Runs),
        findall(S-Fs, ( member(Run, Runs), run_fluents(Run, Voc, S, Fs) ), States)
    ;   States = []
    ).
oracle_final_states(_, []).

run_fluents(Run, Voc, Script, Fluents) :-
    setup_call_cleanup(open(Run, read, S), json_read_dict(S, D), close(S)),
    atom_string(Script, D.script),
    get_dict(acs, D, ACS),
    findall(F, ( member(M, D.templates), atom_string(K, M.field), atom_string(T, M.template),
                 memberchk(voc(T, Fn, Paths), Voc), get_dict(K, ACS, Rows), member(Row, Rows),
                 row_fluent(Fn, Paths, Row, F) ), Fs0),
    msort(Fs0, Fluents).

row_fluent(Fn, Leaves, Row, F) :-
    get_dict('_2', Row, Payload),
    maplist(path_value(Payload), Leaves, Vs),
    F =.. [Fn|Vs].

path_value(D, [K]-Ty, V) :- !, atom_string(KA, K), get_dict(KA, D, V0), norm(Ty, V0, V).
path_value(D, [K|Ks]-Ty, V) :- atom_string(KA, K), get_dict(KA, D, Sub), path_value(Sub, Ks-Ty, V).

%   A Daml value (JSON) as the twin holds it: a party its hint (`alice`),
%   a number a number, a text a text, a list a list.
norm(con('Party', []), V, P) :- !, party_hint(V, P).
norm(con(T, []), V, N) :- memberchk(T, ['Decimal', 'Int', 'Numeric']), !, ( number(V) -> N0 = V ; number_string(N0, V) ), N is float(N0).
norm(list(T), L, L1) :- is_list(L), !, maplist(norm(T), L, L1).
norm(con('ContractId', _), _, '$cid') :- !.
norm(_, true, true) :- !.
norm(_, false, false) :- !.
norm(_, null, none) :- !.
norm(_, V, V).

%   `Alice_r3-d4d9::1220...` (the run's party) -> alice.
party_hint(V, P) :-
    ( sub_string(V, B, _, _, "::") -> sub_string(V, 0, B, _, H0) ; H0 = V ),
    ( sub_string(H0, B2, _, _, "_r"), B3 is B2 + 2, sub_string(H0, B3, 1, _, D), char_type(D, digit) -> sub_string(H0, 0, B2, _, H1) ; H1 = H0 ),
    %  (allocateParty "Bank" gets `Bank-d4d95138` from Canton)
    ( sub_string(H1, B4, 9, 0, Sfx), sub_string(Sfx, 0, 1, _, "-"), sub_string(Sfx, 1, 8, 0, Hex), string_codes(Hex, HC),
      forall(member(C, HC), code_type(C, xdigit(_))) -> sub_string(H1, 0, B4, _, H) ; H = H1 ),
    string_lower(H, L), atom_string(P, L).

		 /*******************************
		 *        THE TWIN'S STATE      *
		 *******************************/

%!  twin_final_state(+LEFile, -Fluents) is det.
%   `lps state` (LPS2) on the twin: its final fluents, ids dropped,
%   numbers as floats, sorted.
twin_final_state(LEFile, Fluents) :-
    lps_bin(Lps), le2_paths:le2_dir(LE2),
    setup_call_cleanup(
        process_create(Lps, [state, LEFile], [stdout(pipe(O)), stderr(null), process(P),
                                              environment(['LPS_LE2_LIB'=LE2])]),
        ( read_string(O, _, S), process_wait(P, _) ),
        close(O)),
    split_string(S, "\n", " ", Lines),
    findall(F, ( member(L, Lines), L \== "", catch(term_string(T, L), _, fail), compound(T),
                 T =.. [Fn, _|Vs], maplist(norm_twin, Vs, Ws), F =.. [Fn|Ws] ), Fs),
    msort(Fs, Fluents).

norm_twin(V, N) :- number(V), !, N is float(V).
norm_twin(L, L1) :- is_list(L), !, maplist(norm_twin, L, L1).
norm_twin(V, V).

lps_bin(Lps) :- le2_paths:lps2_dir(LPS2), atom_concat(LPS2, '/lps', Lps).

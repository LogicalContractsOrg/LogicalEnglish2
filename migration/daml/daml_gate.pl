/** <module> The gate of the way back: LE for LPS -> Daml, run on Canton

    For an LE for LPS program the exporter accepts (daml_export.pl): the
    generated module is built with `dpm build`, its script (the program's
    scenario) run on the local Canton sandbox (else Daml Script's in-memory
    ledger), and the final State it returns compared with LPS2's final
    state of the program (`lps state`). A mutant — the same module with its
    laws' terminations disabled — must end elsewhere whenever the program
    terminates anything, which is what makes the agreement mean something.

        daml_gate(+LEFile, -Result)
        Result = gate(Verdict, MutantVerdict, Details)
                 Verdict: same | differs(Daml, LPS) | refused(Notes) | error(Why)
*/

:- module(daml_gate, [daml_gate/2, gate_main/0]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- use_module(daml_export).
:- use_module(daml_oracle).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).

daml_gate(LEFile, gate(Verdict, Mutant, Notes)) :-
    read_file_to_string(LEFile, Text, [encoding(utf8)]),
    file_directory_name(LEFile, Dir),
    le_kbs:load_text(Text, Dir, KB),
    export_daml(KB, [text(Text), base(Dir)], Result),
    (   Result = refused(Problems)
    ->  findall(M, member(problem(_, M), Problems), Notes),
        Verdict = refused(Notes), Mutant = none
    ;   Result = exported(_, Daml, Notes, _),
        daml_types_of(KB, Text, Types),
        twin_final_state_typed(LEFile, Types, LPS),
        run_generated(LEFile, Daml, Types, R1),
        (   R1 = ok(FS)
        ->  ( FS == LPS -> Verdict = same ; Verdict = differs(FS, LPS) )
        ;   Verdict = R1
        ),
        mutate(Daml, MDaml),
        (   MDaml == Daml -> Mutant = no_termination_to_disable
        ;   run_generated(LEFile, MDaml, Types, R2),
            ( R2 = ok(MFS) -> ( MFS == LPS -> Mutant = same ; Mutant = differs ) ; Mutant = R2 )
        )
    ).

%   The exporter's types, to read the State back (a party is its hint).
daml_types_of(KB, Text, Types) :-
    le_lps:le_lps_module(KB, Text, Internal, _, _),
    daml_export:term_string_terms(Internal, Terms),
    ( memberchk(fluents(Fls), Terms) -> true ; Fls = [] ),
    ( memberchk(actions(Acts0), Terms) -> true ; Acts0 = [] ),
    findall(A, ( member(observe(Es, _), Terms), member(E, Es), functor(E, F, N), functor(A, F, N) ), ObsA),
    append(Acts0, ObsA, Acts1), daml_export:sort_by_functor(Acts1, Acts),
    daml_export:types(Terms, Fls, Acts, Types0),
    findall(F/N, ( member(Fl, Fls), functor(Fl, F, N) ), FNs),
    Types = types(Types0, FNs).

%   The mutant: no law ends anything.
mutate(D0, D) :-
    atomic_list_concat(Parts, "filter (\\r -> not (", D0),
    atomic_list_concat(Parts, "filter (\\r -> True || not (", D1), atom_string(D1, D).

run_generated(LEFile, Daml, Types, Result) :-
    here(H), file_base_name(LEFile, B), file_name_extension(Base, _, B),
    daml_oracle:run_tag(Tag),
    format(atom(PD), '~w/oracle/work/export__~w__~w', [H, Base, Tag]),
    make_directory_path(PD), atomic_list_concat([PD, '/daml'], DD), make_directory_path(DD),
    daml_oracle:project_package_name(PD, PName),
    format(atom(Y), '~w/daml.yaml', [PD]),
    setup_call_cleanup(open(Y, write, S),
        format(S, "sdk-version: 3.5.10~nname: ~w~nsource: daml~nversion: 0.0.1~ndependencies:~n  - daml-prim~n  - daml-stdlib~n  - daml-script~nbuild-options:~n  - -Wno-template-interface-depends-on-daml-script~n", [PName]),
        close(S)),
    daml_oracle:suffix_hints(Daml, Tag, Daml1),
    atomic_list_concat([DD, '/Main.daml'], MF),
    setup_call_cleanup(open(MF, write, O), write(O, Daml1), close(O)),
    dpm(Dpm),
    daml_oracle:run_dpm(Dpm, [build], PD, BOut, BS),
    (   BS \== exit(0)
    ->  daml_oracle:last_lines(BOut, 15, T), Result = error(build(T))
    ;   format(atom(Dar), '~w/.daml/dist/~w-0.0.1.dar', [PD, PName]),
        format(atom(JOut), '~w/final.json', [PD]),
        ( sandbox_up -> L = canton ; L = ide ),
        (   L == canton
        ->  Args = [script, '--dar', Dar, '--script-name', 'Main:scenario', '--ledger-host', localhost, '--ledger-port', '6865', '--upload-dar', true, '--output-file', JOut]
        ;   Args = [script, '--dar', Dar, '--script-name', 'Main:scenario', '--ide-ledger', '--output-file', JOut]
        ),
        daml_oracle:run_dpm(Dpm, Args, PD, ROut, RS),
        (   RS == exit(0), exists_file(JOut)
        ->  setup_call_cleanup(open(JOut, read, JS), json_read_dict(JS, State), close(JS)),
            state_fluents(State, Types, FS), Result = ok(FS)
        ;   daml_oracle:last_lines(ROut, 15, T), Result = error(run(T))
        )
    ).

%   The final State (JSON) as fluents: parties their hints, numbers floats.
state_fluents(null, _, []) :- !.
state_fluents(State, types(Types, FNs), Fluents) :-
    findall(Fl, ( member(F/N, FNs), N > 0, daml_export:field_name(F, Fd), get_dict(Fd, State, Rows), member(Row, Rows),
                  numlist(1, N, Is), maplist(row_value(Row, F, N, Types), Is, Vs), Fl =.. [F|Vs] ), Fs1),
    findall(F, ( member(F/0, FNs), daml_export:field_name(F, Fd), get_dict(Fd, State, true) ), Fs0),
    append(Fs0, Fs1, Fs), msort(Fs, Fluents).

row_value(Row, F, N, Types, I, V) :-
    daml_export:slot_field(F, N, I, K), get_dict(K, Row, V0),       % (the names export_daml gave)
    ( memberchk(slot(F, N, I)-Ty, Types) -> true ; Ty = 'Text' ),
    typed(Ty, V0, V).

typed('Party', V0, V) :- !, daml_oracle:party_hint(V0, V1), party_key(V1, V).
typed('Date', V0, date(Y, M, D)) :- !, split_string(V0, "-", "", [YS, MS, DS]), number_string(Y, YS), number_string(M, MS), number_string(D, DS).
typed('Decimal', V0, V) :- !, ( number(V0) -> N = V0 ; number_string(N, V0) ), V is float(N).
typed(Ty, V0, V) :- is_list(V0), atom_concat('[', T1, Ty), atom_concat(E, ']', T1), !, maplist(typed(E), V0, V).
typed(_, V0, V) :- atom_string(V, V0).


%   LPS2's final state, read with the same types (texts atoms, parties keys).
twin_final_state_typed(LEFile, types(Types, _), Fluents) :-
    setup_call_cleanup(
        le2_paths:lps2_dir(LPS2), atom_concat(LPS2, '/lps', LpsBin), le2_paths:le2_dir(LE2),
        process_create(LpsBin, [state, LEFile], [stdout(pipe(O)), stderr(null), process(P), environment(['LPS_LE2_LIB'=LE2])]),
        ( read_string(O, _, S), process_wait(P, _) ), close(O)),
    split_string(S, "\n", " ", Lines),
    findall(F, ( member(L, Lines), L \== "", catch(term_string(T, L), _, fail), callable(T),
                 T =.. [Fn|Vs], length(Vs, N), numlist_(1, N, Is), maplist(twin_value(Fn, N, Types), Is, Vs, Ws), F =.. [Fn|Ws] ), Fs),
    msort(Fs, Fluents).

numlist_(L, H, []) :- L > H, !.
numlist_(L, H, [L|T]) :- L1 is L + 1, numlist_(L1, H, T).

twin_value(F, N, Types, I, V0, V) :-
    ( memberchk(slot(F, N, I)-Ty, Types) -> true ; Ty = 'Text' ),
    twin_typed(Ty, V0, V).

twin_typed(Ty, V0, V) :-
    (   Ty == 'Party' -> party_key(V0, V)
    ;   is_list(V0), atom_concat('[', T1, Ty), atom_concat(E, ']', T1) -> maplist(twin_typed(E), V0, V)
    ;   number(V0) -> V is float(V0)
    ;   string(V0) -> atom_string(V, V0)
    ;   V = V0
    ).

%   The gate over LPS2's Logical English examples, its finance examples and
%   the Daml twins.
gate_main :-
    le2_paths:lps2_dir(LPS2), atomic_list_concat([LPS2, '/examples/le'], LpsEx),
    atomic_list_concat([LPS2, '/examples/finance'], Finance),
    le2_paths:twins_dir(daml, Twins),
    findall(F, ( member(D, [LpsEx, Finance, Twins]),
                 directory_member(D, F, [extensions([le]), recursive(true)]) ), Fs0),
    sort(Fs0, Fs),
    forall(member(F, Fs),
           ( catch(daml_gate(F, G), E, ( message_to_string(E, M), G = gate(error(M), none, []) )),
             report(F, G) )).

report(F, gate(same, M, _)) :- !, format("  SAME     ~w  (mutant: ~w)~n", [F, M]).
report(F, gate(refused(Ns), _, _)) :- !, ( Ns = [N|_] -> true ; N = "" ), format("  refused  ~w  (~w)~n", [F, N]).
report(F, gate(differs(A, B), M, _)) :- !, format("  DIFFERS  ~w  (mutant: ~w)~n      Daml: ~w~n      LPS:  ~w~n", [F, M, A, B]).
report(F, gate(V, _, _)) :- format("  ERROR    ~w: ~q~n", [F, V]).

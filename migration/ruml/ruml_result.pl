/** <module> Logical English as a RUML evaluator (the design notes ruml.md §7)

    A rulemap and the values of a case in; a RUML result file
    (`.ruml-result`, chapter 5 of the specification) out. The rulemap's
    twin decides the nodes: each node's sentence and its negation are asked
    of the twin, with the values of the case as the facts of a scenario.

        RUML true       the negation has no answer
        RUML false      the sentence has no answer
        RUML undefined  both have an answer, with unknowns

    That is RUML's `complete` mode. The `optimized` mode is a walk of the
    tree in the order of the children, with the stopping rules of §3.6: an
    AND stops at the first child that is not true, an XOR at the first that
    is not false, and the children after it are `ignored`. A leaf's result
    does not depend on the mode; a parent's result in the `optimized` mode
    is its `complete` result or `undefined`, so a DELEGATED node is
    undefined when a child is, and otherwise the twin's answer.

    Each node result has its reason: for a leaf with ruml:query, the
    expression and the values it read; for an undefined node, the unknowns
    of the twin's answer, which say which leaf waits for what; for a
    skipped node, the node that stopped its parent.

        ruml_evaluate(+RulemapFile, +Data, +Options, -Result)
            Data: the values of the case, a JSON object (classic term
            json([...]) or a dict); Options: mode(complete|optimized),
            evaluation_id(Id), clock(TimeStamp), max_depth(N), case_id(C)
        ruml_evaluate_doc(+Doc, +DocName, +Data, +Options, -Result)
        result_json_text(+Result, -Text)
*/

:- module(ruml_result, [ruml_evaluate/4, ruml_evaluate_doc/5, result_json_text/2, twin_statuses/4]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(uuid)).
:- use_module(library(crypto)).
:- use_module(library(http/json)).
:- use_module(ruml_reader).
:- use_module(ruml_twin).
:- use_module(ruml_paths).
:- use_module(jsonata_parser).
:- use_module(le2(le_migration)).
:- use_module(le2(le_kbs)).

tool_id("logical-english-ruml").
tool_version("1.0.0").

%!  ruml_evaluate(+File, +Data, +Options, -Result) is det.
ruml_evaluate(File, Data, Options, Result) :-
    ruml_read_file(File, Doc, Issues),
    (   Doc == none -> throw(error(format("~w is not a RUML rulemap", [File]), _)) ; true ),
    (   member(issue(error, R, _, M), Issues), memberchk(R, ['CAP-01', 'FMT-03', 'FMT-04', 'FMT-08', 'FMT-09', 'NODE-10', 'NODE-12'])
    ->  throw(error(format("RUML ~w: ~w", [R, M]), _))
    ;   true
    ),
    file_base_name(File, B),
    ruml_evaluate_doc(Doc, B, Data, Options, Result).

ruml_evaluate_doc(Doc, DocName, Data0, Options, Result) :-
    data_pairs(Data0, Data),
    option(mode(Mode), Options, complete),
    option(max_depth(Max), Options, 500),
    get_time(Start),
    twin_statuses(Doc, DocName, Data, Statuses),
    j(Doc, metadata, Md), j(Md, id, Id),
    canonical_json(Doc, Canon), crypto_data_hash(Canon, H, [algorithm(sha3_256), encoding(utf8)]),
    format(string(Hash), "sha3-256:~w", [H]),
    b_setval(ruml_ctx, ctx(Doc, Data, Statuses, Mode, Max)),
    nb_setval(ruml_results, []),
    walk('1', '1', [], _),
    nb_getval(ruml_results, Rs0), reverse(Rs0, Rs),
    (   option(evaluation_id(EId), Options) -> true ; uuid(EId0, [version(4)]), atom_string(EId0, EId) ),
    (   option(clock(Clock), Options) -> Ts = Clock, StartTs = Clock
    ;   get_time(End), stamp(End, Ts), stamp(Start, StartTs)
    ),
    maplist(stamped(Ts), Rs, Results),
    tool_id(Tool), tool_version(TV),
    used_capabilities(Doc, Caps0),
    protocol(Doc, Rs, Ts, Mode, Caps0, Caps),
    Ev0 = [id=EId, timestamp=Ts, startTimestamp=StartTs, mode=Mode, toolId=Tool, toolVersion=TV],
    ( option(case_id(C), Options) -> Ev1 = [caseId=C|Ev0] ; Ev1 = Ev0 ),
    ( Caps == [] -> Ev2 = Ev1 ; append(Ev1, [capabilities=Caps], Ev2) ),
    append(Ev2, [results=json(Results)], Ev),
    j(Doc, '$specVersion', V),
    Result = json(['$format'="RUML-Result", '$specVersion'=V, rumlReference=json([id=Id, hash=Hash]), evaluation=json(Ev)]).

stamp(T, S) :- format_time(string(S), "%FT%T%:z", T).
stamped(Ts, P=json(Fs), P=json([lexId=L, status=S, evaluatedAt=Ts|Rest])) :- selectchk(lexId=L, Fs, F1), selectchk(status=S, F1, Rest).

data_pairs(json(Ps), Data) :- !, findall(K-V, member(K=V, Ps), Data).
data_pairs(D, Data) :- is_dict(D), !, dict_pairs(D, _, Ps), maplist(dict_value, Ps, Data).
data_pairs(L, L) :- is_list(L).
dict_value(K-V0, K-V) :- dict_json(V0, V).
dict_json(D, json(Ps)) :- is_dict(D), !, dict_pairs(D, _, KVs), maplist([K-V0, K=V]>>dict_json(V0, V), KVs, Ps).
dict_json(L, L2) :- is_list(L), !, maplist(dict_json, L, L2).
dict_json(true, @(true)) :- !.
dict_json(false, @(false)) :- !.
dict_json(V, V).

		 /*******************************
		 *       THE TWIN DECIDES       *
		 *******************************/

%!  twin_statuses(+Doc, +DocName, +Data, -Statuses) is det.
%   LexId-status(Status, Unknowns), in RUML's `complete` mode.
twin_statuses(Doc, DocName, Data, Statuses) :-
    model_migration(Doc, [document(DocName), program(evaluation), queries(all),
                          tests([case(evaluation, '', Data, [])])], Migration),
    migration_text(Migration, Text, _),
    setup_call_cleanup(le_kbs:set_le_issue_reporting(false),
                       le_kbs:load_text(Text, KB),
                       le_kbs:set_le_issue_reporting(true)),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, evaluation),
    nodes(Doc, Ns),
    findall(L-St, ( member(L-_, Ns), node_status(SM, L, St) ), Statuses),
    le_kbs:destroySession(SM).

node_status(SM, L, status(S, Us)) :-
    node_query(L, Q), node_negation_query(L, QN),
    answers(SM, Q, Pos), answers(SM, QN, Neg),
    (   Neg == [] -> ( Pos == [] -> S = undefined, Us = [] ; S = true, Us = [] )
    ;   Pos == [] -> S = false, Us = []
    ;   S = undefined, findall(U, ( member(_-U0, Pos), member(U, U0) ), Us1), sort(Us1, Us)
    ).

answers(SM, Q, As) :-
    ( SM:le_kb_module_fact(KB) -> true ; KB = none ),
    findall(A-Us, ( catch(le_kbs:query(SM, Q, I, U0, _), _, fail),
                    le_kbs:canonical_string(I, A),
                    maplist(unknown_text(KB), U0, Us) ), As0),
    sort(As0, As).

%   An unknown as the twin's own sentence.
unknown_text(KB, not(U), T) :- !, unknown_text(KB, U, T0), format(string(T), "it is not the case that ~w", [T0]).
unknown_text(KB, U, T) :-
    catch(( le_kbs:item_to_instance(KB, U, I0), flatten(I0, I), le_kbs:canonical_string(I, T0) ), _, fail), !,
    atom_string(T0, T).
unknown_text(_, U, T) :- format(string(T), "~w", [U]).

		 /*******************************
		 *          THE WALK            *
		 *******************************/

%   walk(+LexId, +Path, +Stack, -Status): the node's result at Path, in the
%   mode of the evaluation; each result is recorded as it is decided.
walk(L, P, Stack, S) :-
    b_getval(ruml_ctx, ctx(Doc, _, Statuses, Mode, Max)),
    include(==(L), Stack, Seen), length(Seen, Depth),
    node(Doc, L, N),
    (   Depth > Max
    ->  S = undefined,
        format(string(M), "Recursion depth ~d exceeds the maximum recursion depth of ~d", [Depth, Max]),
        record(P, L, undefined, json([type="error", message=M]), [])
    ;   \+ j(N, children, [_|_])
    ->  memberchk(L-status(S, Us), Statuses),
        leaf_reason(Doc, N, S, Us, Reason, Caps),
        record(P, L, S, Reason, Caps)
    ;   j(N, operator, Op0), atom_string(Op, Op0),
        j(N, children, Cs0), maplist([X, Y]>>atom_string(Y, X), Cs0, Cs),
        parent(Op, Mode, L, P, [L|Stack], Cs, Results, Stop),
        combine(Op, L, Results, Statuses, S),
        parent_reason(Doc, N, Op, L, Results, Stop, S, Statuses, Reason, Caps),
        record(P, L, S, Reason, Caps)
    ).

%   The children, in order: in the `optimized` mode an AND (NOT_AND) stops at
%   the first child that is not true, an XOR (NOT_XOR) at the first that is
%   not false; the others are recorded `ignored`.
parent(Op, Mode, _, P, Stack, Cs, Results, Stop) :-
    base(Op, B),
    (   Mode == optimized, memberchk(B, ['AND', 'XOR']) -> Seq = B ; Seq = none ),
    children_walk(Cs, 1, P, Stack, Seq, Op, Mode, none, Results, Stop).

children_walk([], _, _, _, _, _, _, Stop, [], Stop).
children_walk([C|Cs], I, P, Stack, Seq, Op, Mode, Stop0, [R|Rs], Stop) :-
    format(atom(CP), '~w.~d', [P, I]),
    (   Stop0 \== none
    ->  R = (CP-C)-ignored,
        record(CP, C, ignored, json([type="shortCircuit", trigger=Stop0, operator=Op, mode=Mode]), []),
        Stop1 = Stop0
    ;   walk(C, CP, Stack, S), R = (CP-C)-S,
        (   Seq == 'AND', S \== true -> Stop1 = CP
        ;   Seq == 'XOR', S \== false -> Stop1 = CP
        ;   Stop1 = none
        )
    ),
    I1 is I + 1,
    children_walk(Cs, I1, P, Stack, Seq, Op, Mode, Stop1, Rs, Stop2),
    ( Stop0 \== none -> Stop = Stop0 ; Stop1 \== none -> Stop = Stop1 ; Stop = Stop2 ).

base('NOT_AND', 'AND') :- !.
base('NOT_OR', 'OR') :- !.
base('NOT_XOR', 'XOR') :- !.
base(Op, Op).

combine('DELEGATED', L, Results, Statuses, S) :- !,
    (   member(_-undefined, Results) -> S = undefined
    ;   memberchk(L-status(S, _), Statuses)
    ).
combine(Op, _, Results, _, S) :-
    base(Op, B),
    exclude([_-X]>>(X == ignored), Results, Rs), pairs_values(Rs, Ss),
    (   B == 'AND' -> ( memberchk(false, Ss) -> S0 = false ; memberchk(undefined, Ss) -> S0 = undefined ; S0 = true )
    ;   ( memberchk(true, Ss) -> S0 = true ; memberchk(undefined, Ss) -> S0 = undefined ; S0 = false )
    ),
    (   B \== Op -> flip(S0, S) ; S = S0 ).

flip(true, false).
flip(false, true).
flip(undefined, undefined).

record(P, L, S, Reason, Caps) :-
    nb_getval(ruml_results, Rs0),
    Fs0 = [lexId=L, status=S, reason=Reason],
    ( Caps == [] -> Fs = Fs0 ; append(Fs0, [capabilities=Caps], Fs) ),
    nb_setval(ruml_results, [P=json(Fs)|Rs0]).

		 /*******************************
		 *           REASONS            *
		 *******************************/

leaf_reason(Doc, N, S, Us, Reason, Caps) :-
    b_getval(ruml_ctx, ctx(_, Data, _, _, _)),
    node_caps(N, Es),
    findall(json([id="ruml:query", payload=json([expression=E, inputs=json(In), result=RS])]),
            ( member(cap('ruml:query', P), Es), j(P, expression, E), read_inputs(E, Data, In), atom_string(S, RS) ),
            Caps),
    j(N, label, Label, ""),
    (   S == undefined
    ->  undefined_message(Label, Us, Data, N, M), Reason = json([type="default", message=M])
    ;   Caps = [json([_, payload=json([expression=E1, inputs=json(In1)|_])])|_]
    ->  inputs_text(E1, In1, IT), format(string(Reason), "~w: ~w (~w)", [S, E1, IT])
    ;   S == true -> format(string(Reason), "true: ~w, answered yes", [Label])
    ;   format(string(Reason), "false: ~w, answered no", [Label])
    ),
    ignore(Doc = _).

%   The unknowns that the twin's answer rests on: which leaf waits for a
%   value, or for a person's judgment.
undefined_message(Label, Us, Data, N, M) :-
    (   node_caps(N, Es), member(cap('ruml:query', P), Es), j(P, expression, E),
        jsonata_parse(E, T), jsonata_names(T, Names), Names \== [],
        missing_names(Names, Data, Missing), Missing \== []
    ->  b_getval(ruml_ctx, ctx(Doc, _, _, _, _)), maplist(dp_name(Doc), Missing, MNs), atomic_list_concat(MNs, ', ', MS),
        format(string(M), "~w has no result: no value for ~w", [Label, MS])
    ;   Us \== []
    ->  atomic_list_concat(Us, '; ', UT),
        format(string(M), "~w is open: it rests on ~w", [Label, UT])
    ;   format(string(M), "~w has no answer yet: a person, a model or another rulemap decides it", [Label])
    ).

missing_names([], _, []).
missing_names([N|Ns], Data, Ms) :-
    ( memberchk(N-_, Data) -> Ms = Ms1 ; atom_string(N, S), memberchk(S-_, Data) -> Ms = Ms1 ; Ms = [N|Ms1] ),
    missing_names(Ns, Data, Ms1).

parent_reason(Doc, N, Op, L, Results, Stop, S, Statuses, Reason, Caps) :-
    b_getval(ruml_ctx, ctx(_, Data, _, _, _)),
    (   Op == 'DELEGATED', node_caps(N, Es), member(cap('ruml:expression', P), Es), j(P, expression, E),
        \+ member(_-undefined, Results)
    ->  read_inputs(E, Data, In),
        findall(json([lexId=C, status=CS]), member((_-C)-CS, Results), Ch),
        Caps = [json([id="ruml:expression", payload=json([expression=E, inputs=json(In), children=Ch, result=S])])]
    ;   Caps = []
    ),
    (   S == undefined
    ->  memberchk(L-status(_, Us), Statuses),
        findall(T, ( member((CP-C)-undefined, Results), child_text(Doc, CP, C, T) ), Und),
        (   Und \== [] -> atomic_list_concat(Und, '; ', UC), format(string(M), "~w: undefined, because ~w is undefined", [Op, UC])
        ;   Us \== [] -> atomic_list_concat(Us, '; ', UT), format(string(M), "~w: undefined; it rests on ~w", [Op, UT])
        ;   format(string(M), "~w: undefined", [Op])
        ),
        Reason = json([type="default", message=M])
    ;   Stop \== none -> memberchk((Stop-SC)-SS, Results), child_text(Doc, Stop, SC, ST), format(string(Reason), "~w: ~w, decided by ~w (~w)", [Op, S, ST, SS])
    ;   findall(T, ( member((CP-C)-CS, Results), child_text(Doc, CP, C, T0), format(string(T), "~w ~w", [T0, CS]) ), Ts), atomic_list_concat(Ts, '; ', TT),
        format(string(Reason), "~w: ~w (~w)", [Op, S, TT])
    ),
    ignore(Doc = _).

%   A child as a case worker reads it: its path and its label.
child_text(Doc, CP, C, T) :- ( node(Doc, C, N), j(N, label, L) -> format(string(T), "~w ~w", [CP, L]) ; format(string(T), "~w", [CP]) ).

%   A data point's name beside its id.
dp_name(Doc, Id, T) :-
    (   capabilities(Doc, Cs), member(C, Cs), j(C, id, "ruml:datapoints"), j(C, payload, P), j(P, data, D), j(D, Id, DP), j(DP, name, Nm)
    ->  format(string(T), "~w (~w)", [Nm, Id])
    ;   format(string(T), "~w", [Id])
    ).

read_inputs(E, Data, In) :-
    (   jsonata_parse(E, T) -> jsonata_names(T, Ns) ; Ns = [] ),
    findall(K=V, ( member(K, Ns), memberchk(K-V, Data) ), In).

%   The values an expression read, and those it found missing.
inputs_text(E, In, T) :-
    findall(S, ( member(K=V, In), json_short(V, VS), format(string(S), "~w = ~w", [K, VS]) ), Ss),
    (   jsonata_parse(E, Tr) -> jsonata_names(Tr, Ns) ; Ns = [] ),
    b_getval(ruml_ctx, ctx(Doc, _, _, _, _)),
    findall(S, ( member(K, Ns), \+ memberchk(K=_, In), dp_name(Doc, K, KN), format(string(S), "no value for ~w", [KN]) ), Ms),
    append(Ss, Ms, All), ( All == [] -> T = "no data" ; atomic_list_concat(All, ', ', T) ).
json_short(V, S) :- with_output_to(string(S), json_write(current_output, V, [width(0)])).

used_capabilities(Doc, Caps) :-
    capabilities(Doc, Cs),
    findall(json([id=Id]), ( member(C, Cs), j(C, id, Id), Id \== "ruml:protocol" ), Caps).

		 /*******************************
		 *           PROTOCOL           *
		 *******************************/

%   ruml:protocol (§4.13): the run as CloudEvents, when the file asks for it.
protocol(Doc, Rs, Ts, Mode, Caps0, Caps) :-
    capabilities(Doc, Cs),
    (   member(C, Cs), j(C, id, "ruml:protocol")
    ->  ( j(C, payload, P), j(P, config, Cf), j(Cf, level, Lv) -> true ; Lv = "standard" ),
        tool_id(Tool), format(string(Src), "urn:~w", [Tool]),
        findall(E, protocol_event(Rs, Ts, Mode, Src, Lv, E), Es0),
        foldl([json(Fs0), json([specversion="1.0", id=I|Fs0]), N0, N]>>( N is N0 + 1, format(string(I), "~d", [N]) ), Es0, Es, 0, _),
        append(Caps0, [json([id="ruml:protocol", payload=json([level=Lv, events=Es])])], Caps)
    ;   Caps = Caps0
    ).

protocol_event(_, Ts, Mode, Src, _, json([source=Src, type="ruml.evaluation.started", time=Ts, data=json([mode=Mode])])).
protocol_event(Rs, Ts, _, Src, Lv, json([source=Src, type=T, time=Ts, subject=P, data=json(D)])) :-
    member(P=json(Fs), Rs), memberchk(lexId=L, Fs), memberchk(status=S, Fs),
    (   S == ignored -> Lv == "verbose", T = "ruml.node.skipped", D = [lexId=L, cause="shortCircuit"]
    ;   T = "ruml.node.evaluated", D = [lexId=L, status=S]
    ).
protocol_event(_, Ts, _, Src, _, json([source=Src, type="ruml.evaluation.completed", time=Ts])).

%!  result_json_text(+Result, -Text) is det.
result_json_text(R, T) :- with_output_to(string(T), json_write(current_output, R, [width(100)])).

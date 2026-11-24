/*  The gate of step 1 (the design notes roadmap.md, Phase 4): every FEEL
    text of the four collections parsed.

        swipl -q -g "use_module('migration/dmn/gate'), gate:parse_gate_all" -t halt
        swipl -q -g "use_module('migration/dmn/gate'), gate:parse_gate(tck)" -t halt

    Writes runs/gate.txt: per collection, the number of models read, the
    number of texts of each kind (literal expression, input expression,
    input entry, output entry, allowed values) and how many parsed, then
    every text that did not, with its model.
*/

:- module(gate, [parse_gate/1, parse_gate_all/0, model_texts/2, model_texts/3, collection_files/2, drg_gate/1, drg_gate_all/0]).

:- use_module(dmn_home).
:- use_module(dmn_reader).
:- use_module(feel_parser).
:- use_module(corpus).

parse_gate_all :-
    findall(C, dmn_corpus:collection(C, _, _), Cs),
    dmn_path('runs/gate.txt', GateFile),
    setup_call_cleanup(open(GateFile, write, Out),
        forall(member(C, Cs), parse_gate(C, Out)),
        close(Out)).

parse_gate(C) :- parse_gate(C, user_output).

parse_gate(C, Out) :-
    collection_files(C, Files),
    length(Files, NF),
    namespace_index(Files, Index),
    findall(F-K-T-R, ( member(F, Files), file_texts(F, Index, Ts), member(K-T-Names, Ts),
                        ( parse_text(K, T, Names) -> R = ok ; R = fail ) ), Rows),
    length(Rows, NT),
    include([_-_-_-ok]>>true, Rows, Ok), length(Ok, NOk),
    format(Out, "~w: ~d models, ~d of ~d texts parse~n", [C, NF, NOk, NT]),
    forall(member(K0, [literal, input_expression, input_entry, output_entry, allowed]),
           ( include(row_kind(K0), Rows, KR), length(KR, NK),
             include(row_kind_ok(K0), KR, KO), length(KO, NKO),
             ( NK > 0 -> format(Out, "    ~w: ~d of ~d~n", [K0, NKO, NK]) ; true ) )),
    forall(( member(F-K-T-fail, Rows) ),
           ( file_base_name(F, B), format(Out, "  FAIL ~w ~w: ~q~n", [B, K, T]) )),
    flush_output(Out).

row_kind(K, _-K-_-_).
row_kind_ok(K, _-K-_-ok).

parse_text(input_entry, T, Ns) :- !, feel_unary(T, Ns, _).
parse_text(allowed, T, Ns) :- !, feel_unary(T, Ns, _).
parse_text(_, '', _) :- !.
parse_text(_, T, Ns) :- feel_parse(T, Ns, _).

file_texts(F, Index, Ts) :-
    catch(dmn_read_file(F, M), _, fail), !,
    imported_names(M, Index, INs),
    model_texts(M, INs, Ts).
file_texts(_, _, []).

%   Namespace-Names of every model of the collection, so an import's names
%   are in scope where the importing model uses them (`Age.as of date`).
namespace_index(Files, Index) :-
    findall(NS-Ns, ( member(F, Files), catch(dmn_read_file(F, M), _, fail),
                     dmn_info(M, namespace, NS), model_names(M, [], Ns) ), Index).

imported_names(model(_, Items), Index, Names) :-
    findall(N, ( member(import(_, NS, _, _), Items), member(NS-Ns, Index), member(N, Ns) ), Names).

%!  model_texts(+Model, -Texts) is det.
%
%   Every FEEL text of a model, as Kind-Text-NamesInScope.
model_texts(M, Ts) :- model_texts(M, [], Ts).

model_texts(M, Extra, Ts) :-
    model_names(M, Extra, Names),
    findall(T, model_text(M, Names, T), Ts).

model_names(model(_, Items), Extra, Names) :-
    findall(N, ( member(I, Items),
                 ( I = input(_, N, _, _) ; I = decision(_, N, _, _, _, _) ; I = bkm(_, N, _, _, _)
                 ; I = service(_, N, _, _, _, _) ; I = import(N, _, _, _), N \== '' ) ), Names0),
    findall(N, ( member(itemdef(_, D), Items), sub_term(component(N, _), D) ), Comps),
    append([Names0, Comps, Extra], Names1),
    sort(Names1, Names).

model_text(model(_, Items), Names, T) :-
    member(I, Items),
    (   I = decision(_, _, _, _, L, _), logic_text(L, Names, T)
    ;   I = bkm(_, _, _, L, _), logic_text(L, Names, T)
    ;   I = itemdef(_, D), sub_term(type(_, AV, _), D), AV \== '', T = allowed-AV-Names
    ).

logic_text(table(_, _, Ins, Outs, Rules), Ns, T) :-
    (   member(in(X, _, AV), Ins), ( T = input_expression-X-Ns ; AV \== '', T = allowed-AV-Ns )
    ;   member(out(_, _, AV, D), Outs), ( AV \== '', T = allowed-AV-Ns ; D \== '', T = output_entry-D-Ns )
    ;   member(rule(_, IT, OT, _), Rules),
        ( member(X, IT), T = input_entry-X-Ns ; member(X, OT), T = output_entry-X-Ns )
    ).
logic_text(literal(X), Ns, literal-X-Ns).
logic_text(context(Es), Ns, T) :-
    findall(N, ( member(entry(N, _), Es), N \== '$result' ), ENs),
    append(ENs, Ns, Ns1),
    member(entry(_, L), Es), logic_text(L, Ns1, T).
logic_text(invocation(_, Bs), Ns, T) :- member(binding(_, L), Bs), logic_text(L, Ns, T).
logic_text(list(Ls), Ns, T) :- member(L, Ls), logic_text(L, Ns, T).
logic_text(relation(_, Rows), Ns, T) :- member(R, Rows), member(L, R), logic_text(L, Ns, T).
logic_text(function(Ps, _, L), Ns, T) :-
    findall(P, member(param(P, _), Ps), PNs), append(PNs, Ns, Ns1), logic_text(L, Ns1, T).
logic_text(conditional(A, B, C), Ns, T) :- member(L, [A, B, C]), logic_text(L, Ns, T).
logic_text(filter(A, B), Ns, T) :- ( logic_text(A, Ns, T) ; logic_text(B, [item|Ns], T) ).
logic_text(iterator(_, V, A, B), Ns, T) :- ( logic_text(A, Ns, T) ; logic_text(B, [V|Ns], T) ).

collection_files(C, Files) :-
    dmn_corpus:collection(C, Dir, Pattern),
    dmn_path('.cache', Cache), directory_file_path(Cache, Dir, Root),
    findall(F, ( directory_member(Root, F, [recursive(true), matches(Pattern)]),
                 \+ sub_atom(F, _, _, _, '/node_modules/'),
                 \+ sub_atom(F, _, _, _, '/target/') ), Fs),
    msort(Fs, Files).

		 /*******************************
		 *   THE DRG AGAINST DROOLS'    *
		 *******************************/

%!  drg_gate(+Collection) is det.
%
%   The second half of step 1's gate: for every model, the reader's
%   decision requirements graph against Drools' own reading of the model
%   (oracle/results/<collection>-drg.json, `dmn-oracle drg`): the same
%   inputs, the same decisions, and for each decision the same required
%   decisions, inputs and knowledge, the same kind of logic and, for a
%   table, the same hit policy and number of rules. Prints a line per
%   collection and each model that differs.
drg_gate(C) :- drg_gate(C, user_output).

drg_gate_all :-
    dmn_path('runs/drg-gate.txt', DrgFile),
    setup_call_cleanup(open(DrgFile, write, Out),
        forall(member(C-J, [tck-tck2, tck3-tck3, sttr-sttr, ronl-ronl, bdt-bdt]), drg_gate(C, J, Out)),
        close(Out)).

drg_gate(C, Out) :- drg_json_name(C, J), drg_gate(C, J, Out).
drg_json_name(tck, tck2). drg_json_name(tck3, tck3). drg_json_name(sttr, sttr).
drg_json_name(ronl, ronl). drg_json_name(bdt, bdt).

drg_gate(C, J0, Out) :-
    ( sub_atom(J0, _, _, 0, '-normalised') -> J = J0 ; atom_concat(J0, '-drg', J) ),
    dmn_path('oracle/results/', Results), atomic_list_concat([Results, J, '.json'], JF),
    setup_call_cleanup(open(JF, read, In), json:json_read_dict(In, Models, [value_string_as(atom)]), close(In)),
    include([D]>>(get_dict(compiled, D, true)), Models, Compiled),
    length(Models, NM), length(Compiled, NC),
    collection_files(C, CFs),
    findall(Id-N, ( member(CF, CFs), catch(dmn_read_file(CF, model(_, CIs)), _, fail), member(It, CIs),
                    arg(1, It, Id), atom(Id), Id \== '', item_named(It, N) ), Index0),
    sort(Index0, Index), nb_setval(drg_index, Index),
    findall(F-Diffs, ( member(D, Compiled), get_dict(file, D, F), exists_file(F),
                       catch(dmn_read_file(F, Mo), _, fail), drg_diffs(Mo, D, Diffs) ), Rs),
    include([_-[]]>>true, Rs, Same), length(Same, NS), length(Rs, NR),
    format(Out, "~w: ~d models, ~d compiled by Drools, ~d of ~d with the same DRG~n", [C, NM, NC, NS, NR]),
    forall(( member(F-Ds, Rs), Ds \== [] ), ( file_base_name(F, B), format(Out, "  DIFFERS ~w: ~q~n", [B, Ds]) )),
    flush_output(Out).

:- use_module(library(http/json)).

item_named(decision(_, N, _, _, _, _), N).
item_named(input(_, N, _, _), N).
item_named(bkm(_, N, _, _, _), N).
item_named(service(_, N, _, _, _, _), N).

drg_diffs(model(_, Items), D, Diffs) :-
    findall(P, member(import(P, _, _, _), Items), Ps), nb_setval(drg_prefixes, Ps),
    findall(N, member(input(_, N, _, _), Items), Ins0), msort(Ins0, Ins),
    get_dict(inputData, D, DIns), findall(N, ( member(X, DIns), get_dict(name, X, N) ), DIns1), msort(DIns1, DInsS),
    get_dict(decisions, D, DDs),
    findall(diff(N, What), ( member(DD, DDs), get_dict(name, DD, N), decision_diff(Items, N, DD, What) ), DecDiffs),
    findall(N, member(decision(_, N, _, _, _, _), Items), Ds0), msort(Ds0, DsS),
    findall(N, ( member(X, DDs), get_dict(name, X, N) ), DDs1), msort(DDs1, DDsS),
    (   Ins == DInsS -> I1 = [] ; I1 = [inputs(Ins, DInsS)] ),
    (   DsS == DDsS -> I2 = [] ; I2 = [decisions(DsS, DDsS)] ),
    append([I1, I2, DecDiffs], Diffs).

decision_diff(Items, N, DD, What) :-
    member(decision(_, N, _, reqs(RD, RI, RK), L, _), Items), !,
    names_of(Items, decision, RD, RDN), names_of(Items, input, RI, RIN), names_of(Items, bkm, RK, RKN),
    get_dict(requiredDecisions, DD, DRD0), get_dict(requiredInputs, DD, DRI0), get_dict(requiredKnowledge, DD, DRK0),
    maplist(last_name, DRD0, DRD), maplist(last_name, DRI0, DRI), maplist(last_name, DRK0, DRK),
    msort(DRD, DRDs), msort(DRI, DRIs), msort(DRK, DRKs),
    get_dict(logic, DD, DL),
    (   RDN \== DRDs -> What = required_decisions(RDN, DRDs)
    ;   RIN \== DRIs -> What = required_inputs(RIN, DRIs)
    ;   RKN \== DRKs -> What = required_knowledge(RKN, DRKs)
    ;   logic_diff(L, DL, What)
    ).

%   Drools names an imported element `Prefix.Name`: the prefix of one of the
%   model's imports is dropped, a dot in a name itself (`Artikel 22.28 a`)
%   is not.
last_name(N0, N) :-
    nb_getval(drg_prefixes, Ps),
    (   member(P, Ps), P \== '', atom_concat(P, '.', PD), atom_concat(PD, N1, N0) -> N = N1 ; N = N0 ).

names_of(Items, Kind, Hrefs, Names) :-
    findall(N, ( member(H, Hrefs), dmn_href_id(H, Id), item_name(Items, Kind, Id, N) ), Ns0), msort(Ns0, Names).

item_name(Items, decision, Id, N) :- member(decision(Id, N, _, _, _, _), Items), !.
item_name(Items, input, Id, N) :- member(input(Id, N, _, _), Items), !.
item_name(Items, bkm, Id, N) :- ( member(bkm(Id, N, _, _, _), Items) ; member(service(Id, N, _, _, _, _), Items) ), !.
item_name(_, _, Id, N) :- nb_getval(drg_index, Index), memberchk(Id-N, Index), !.      % in an imported model
item_name(_, _, Id, Id).

logic_diff(table(Hit, _, _, _, Rules), DL, What) :- !,
    get_dict(kind, DL, K), get_dict(hitPolicy, DL, HP0), get_dict(rules, DL, NR),
    downcase_atom(HP0, HP1), atomic_list_concat(Ps, ' ', HP1), atomic_list_concat(Ps, '_', HP),
    length(Rules, N),
    (   K \== decisionTable -> What = kind(table, K)
    ;   HP \== Hit -> What = hit(Hit, HP)
    ;   N =\= NR -> What = rules(N, NR)
    ;   fail
    ).
logic_diff(iterator(I, _, _, _), DL, kind(I, K)) :- !, get_dict(kind, DL, K), K \== I.
logic_diff(L, DL, kind(K1, K)) :-
    get_dict(kind, DL, K), functor(L, F, _), logic_kind_name(F, K1), K1 \== K.

logic_kind_name(literal, literalExpression).
logic_kind_name(context, context).
logic_kind_name(invocation, invocation).
logic_kind_name(list, list).
logic_kind_name(relation, relation).
logic_kind_name(function, functionDefinition).
logic_kind_name(conditional, conditional).
logic_kind_name(filter, filter).
logic_kind_name(iterator, iterator).
logic_kind_name(none, none).

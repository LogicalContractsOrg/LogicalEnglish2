/** <module> DMN XML → a model term

    Reads a DMN model (the OMG's Decision Model and Notation, versions 1.1 to
    1.6) into one Prolog term that the twin writer (dmn_twin.pl) and the gate
    (gate.pl) work from. Nothing here interprets FEEL: every expression stays
    the text the model holds, and feel_parser.pl reads it.

        model(Info, Items)

    Info: name(N), namespace(NS), version(V) (dmn11 … dmn16), file(F),
    exporter(E), profile(sttr | none).

    Items, each with the element's id first so a reference (`href="#id"`, or
    `href="ns#id"` into an imported model) can be resolved:

      import(Name, Namespace, Location, Type)
      itemdef(Name, Def)            Def = type(TypeRef, Allowed, Collection)
                                        | struct(Components, Collection)
                                    Components = [component(Name, Def)]
      input(Id, Name, TypeRef, Meta)
      decision(Id, Name, TypeRef, Reqs, Logic, Meta)
      bkm(Id, Name, Params, Logic, Reqs)
      service(Id, Name, Outputs, Encapsulated, InputDecisions, InputData)

    Reqs = reqs(Decisions, Inputs, Knowledge), each a list of hrefs.
    Params = [param(Name, TypeRef)].

    Logic, the boxed expressions of the specification (chapter 7):

      table(Hit, Aggregation, Inputs, Outputs, Rules)
            Hit: unique, first, priority, any, collect, rule_order,
                 output_order; Aggregation: none, sum, count, min, max
            Inputs = [in(Text, TypeRef, Allowed)]
            Outputs = [out(Name, TypeRef, Allowed, Default)]
            Rules = [rule(Id, InTexts, OutTexts, Annotations)]
      literal(Text)
      context(Entries)              Entries = [entry(Name, Logic)], the
                                    final result entry named '$result'
      invocation(Callee, Bindings)  Bindings = [binding(Param, Logic)]
      list(Logics)
      relation(Columns, Rows)       Rows = [[Logic]]
      function(Params, Kind, Logic) Kind: feel, java, pmml
      conditional(If, Then, Else)   (DMN 1.4+)
      filter(In, Match)
      iterator(Kind, Var, In, Body) Kind: for, some, every
      none                          (a decision with no logic)

    Meta keeps what the model says ABOUT an element without it being logic:
    description(Text), question(Text) and explanation(Text) (STTR's
    vraagTekst and toelichting), fixed(Value) (STTR's vasteWaarde: an input
    whose value the model gives itself), datatype(T) (STTR's gegevensType),
    sttr_ref(Href) (functioneleStructuurRef, uitvoeringsregelRef),
    allowed(Text) (the allowed values of the variable's type).
*/

:- module(dmn_reader, [
    dmn_read_file/2,            % +File, -Model
    dmn_model_items/3,          % +Model, +Kind, -Items
    dmn_info/3,                 % +Model, +Key, -Value
    dmn_href_id/2,              % +Href, -Id
    dmn_item_by_id/3            % +Model, +Id, -Item
]).

:- use_module(library(sgml)).
:- use_module(library(lists)).
:- use_module(library(apply)).

%!  dmn_read_file(+File, -Model) is det.
dmn_read_file(File, model(Info, Items)) :-
    load_structure(File, DOM, [dialect(xmlns), space(sgml), keep_prefix(false)]),
    member(element(RootName, Attrs, Children), DOM),
    local_name(RootName, definitions), !,
    root_ns(RootName, NS0),
    version_of(NS0, Version),
    attr(name, Attrs, Name, ''),
    attr(namespace, Attrs, Namespace, ''),
    attr(exporter, Attrs, Exporter, ''),
    (   sub_atom(Exporter, _, _, _, 'STTR') -> Profile = sttr
    ;   sub_atom(Namespace, 0, _, _, 'http://toepasbare-regels.omgevingswet') -> Profile = sttr
    ;   Profile = none
    ),
    sttr_rules(Children, SttrRules),
    phrase(items(Children, SttrRules), Items),
    Info = [name(Name), namespace(Namespace), version(Version), file(File),
            exporter(Exporter), profile(Profile)].

dmn_info(model(Info, _), Key, Value) :- T =.. [Key, Value], memberchk(T, Info).

dmn_model_items(model(_, Items), Kind, Out) :-
    findall(I, ( member(I, Items), functor(I, Kind, _) ), Out).

dmn_href_id(Href, Id) :-
    (   sub_atom(Href, B, 1, _, '#') -> B1 is B + 1, sub_atom(Href, B1, _, 0, Id)
    ;   Id = Href
    ).

dmn_item_by_id(model(_, Items), Id, Item) :-
    member(Item, Items), arg(1, Item, Id0), Id0 == Id, !.

		 /*******************************
		 *            ITEMS             *
		 *******************************/

items([], _) --> [].
items([E|Es], S) --> item(E, S), items(Es, S).

item(element(N, A, C), S) --> { local_name(N, L) }, !, item_(L, A, C, S).
item(_, _) --> [].

item_(import, A, _, _) --> !,
    { attr(name, A, Name, ''), attr(namespace, A, NS, ''),
      attr(locationURI, A, Loc, ''), attr(importType, A, T, '') },
    [import(Name, NS, Loc, T)].
item_(itemDefinition, A, C, _) --> !,
    { attr(name, A, Name, ''), itemdef(A, C, Def) },
    [itemdef(Name, Def)].
item_(inputData, A, C, S) --> !,
    { attr(id, A, Id, ''), attr(name, A, Name, ''),
      variable_type(C, T), meta(C, S, Meta) },
    [input(Id, Name, T, Meta)].
item_(decision, A, C, S) --> !,
    { attr(id, A, Id, ''), attr(name, A, Name, ''),
      variable_type(C, T0), reqs(C, Reqs), logic_of(C, Logic),
      ( T0 == '', logic_type(Logic, T1) -> T = T1 ; T = T0 ),
      meta(C, S, Meta) },
    [decision(Id, Name, T, Reqs, Logic, Meta)].
item_(businessKnowledgeModel, A, C, _) --> !,
    { attr(id, A, Id, ''), attr(name, A, Name, ''), reqs(C, Reqs),
      (   child(C, encapsulatedLogic, element(_, EA, EC))
      ->  params(EC, Params), attr(kind, EA, K0, 'FEEL'), kind(K0, K),
          logic_of(EC, Body), Logic = function(Params, K, Body)
      ;   Params = [], Logic = none
      ) },
    [bkm(Id, Name, Params, Logic, Reqs)].
item_(decisionService, A, C, _) --> !,
    { attr(id, A, Id, ''), attr(name, A, Name, ''),
      hrefs(C, outputDecision, O), hrefs(C, encapsulatedDecision, E),
      hrefs(C, inputDecision, ID), hrefs(C, inputData, IN) },
    [service(Id, Name, O, E, ID, IN)].
item_(_, _, _, _) --> [].

itemdef(A, C, Def) :-
    attr(isCollection, A, Coll0, false), truth(Coll0, Coll),
    findall(component(N, D),
            ( member(element(CN, CA, CC), C), local_name(CN, itemComponent),
              attr(name, CA, N, ''), itemdef(CA, CC, D) ),
            Comps),
    (   Comps \== [] -> Def = struct(Comps, Coll)
    ;   ( child_text(C, typeRef, T) -> true ; attr(typeRef, A, T, '') ),
        ( child(C, allowedValues, element(_, _, AC)), child_text(AC, text, AV) -> true ; AV = '' ),
        Def = type(T, AV, Coll)
    ).

variable_type(C, T) :-
    (   child(C, variable, element(_, VA, _)) -> attr(typeRef, VA, T, '')
    ;   T = ''
    ).

reqs(C, reqs(Ds, Is, Ks)) :-
    findall(H, ( child(C, informationRequirement, element(_, _, RC)),
                 child(RC, requiredDecision, element(_, RA, _)), attr(href, RA, H, '') ), Ds),
    findall(H, ( child(C, informationRequirement, element(_, _, RC)),
                 child(RC, requiredInput, element(_, RA, _)), attr(href, RA, H, '') ), Is),
    findall(H, ( child(C, knowledgeRequirement, element(_, _, RC)),
                 child(RC, requiredKnowledge, element(_, RA, _)), attr(href, RA, H, '') ), Ks).

hrefs(C, Local, Hs) :-
    findall(H, ( child(C, Local, element(_, A, _)), attr(href, A, H, '') ), Hs).

params(C, Ps) :-
    findall(param(N, T), ( child(C, formalParameter, element(_, A, _)),
                           attr(name, A, N, ''), attr(typeRef, A, T, '') ), Ps).

kind(K0, K) :- downcase_atom(K0, K1), ( memberchk(K1, [feel, java, pmml]) -> K = K1 ; K = feel ).

		 /*******************************
		 *        BOXED EXPRESSIONS     *
		 *******************************/

%   The logic of a decision (or of a BKM's encapsulated logic, of a context
%   entry, ...): its one boxed-expression child.
logic_of(C, Logic) :-
    (   member(element(N, A, EC), C), local_name(N, L), boxed(L), !,
        boxed_logic(L, A, EC, Logic)
    ->  true
    ;   Logic = none
    ).

boxed(decisionTable). boxed(literalExpression). boxed(context).
boxed(invocation). boxed(list). boxed(relation). boxed(functionDefinition).
boxed(conditional). boxed(filter). boxed(for). boxed(some). boxed(every).

boxed_logic(literalExpression, _, C, literal(T)) :- !,
    ( child_text(C, text, T) -> true ; T = '' ).
boxed_logic(decisionTable, A, C, table(Hit, Agg, Ins, Outs, Rules)) :- !,
    attr(hitPolicy, A, H0, 'UNIQUE'), hit(H0, Hit),
    attr(aggregation, A, G0, ''), ( G0 == '' -> Agg = none ; downcase_atom(G0, Agg) ),
    findall(in(T, TR, AV),
            ( child(C, input, element(_, _, IC)),
              child(IC, inputExpression, element(_, IEA, IEC)),
              ( child_text(IEC, text, T) -> true ; T = '' ),
              attr(typeRef, IEA, TR, ''),
              ( child(IC, inputValues, element(_, _, VC)), child_text(VC, text, AV) -> true ; AV = '' ) ),
            Ins),
    findall(out(N, TR, AV, D),
            ( child(C, output, element(_, OA, OC)),
              attr(name, OA, N, ''), attr(typeRef, OA, TR, ''),
              ( child(OC, outputValues, element(_, _, VC)), child_text(VC, text, AV) -> true ; AV = '' ),
              ( child(OC, defaultOutputEntry, element(_, _, DC)), child_text(DC, text, D) -> true ; D = '' ) ),
            Outs),
    findall(rule(Id, IT, OT, An),
            ( child(C, rule, element(_, RA, RC)), attr(id, RA, Id, ''),
              findall(X, ( child(RC, inputEntry, element(_, _, XC)), entry_text(XC, X) ), IT),
              findall(X, ( child(RC, outputEntry, element(_, _, XC)), entry_text(XC, X) ), OT),
              findall(X, ( child(RC, annotationEntry, element(_, _, XC)), entry_text(XC, X) ), An0),
              %  STTR: the explanation shown with a conclusion
              findall(X, ( child(RC, outputEntry, element(_, _, OC)), child(OC, extensionElements, element(_, _, XE)),
                           child(XE, conclusieToelichting, element(_, _, TC)), child_text(TC, toelichting, X0), clean(X0, X) ), An1),
              append(An0, An1, An) ),
            Rules).
boxed_logic(context, _, C, context(Es)) :- !,
    findall(entry(N, L),
            ( child(C, contextEntry, element(_, _, EC)),
              (   child(EC, variable, element(_, VA, _)) -> attr(name, VA, N, '')
              ;   N = '$result'
              ),
              logic_of(EC, L) ),
            Es).
boxed_logic(invocation, _, C, invocation(Callee, Bs)) :- !,
    (   member(element(N, _, EC), C), local_name(N, literalExpression),
        child_text(EC, text, Callee0) -> normalize_space(atom(Callee), Callee0)
    ;   Callee = ''
    ),
    findall(binding(P, L),
            ( child(C, binding, element(_, _, BC)),
              child(BC, parameter, element(_, PA, _)), attr(name, PA, P, ''),
              logic_of(BC, L) ),
            Bs).
boxed_logic(list, _, C, list(Ls)) :- !,
    findall(L, ( member(element(N, A, EC), C), local_name(N, LN), boxed(LN),
                 boxed_logic(LN, A, EC, L) ), Ls).
boxed_logic(relation, _, C, relation(Cols, Rows)) :- !,
    findall(N, ( child(C, column, element(_, A, _)), attr(name, A, N, '') ), Cols),
    findall(R, ( child(C, row, element(_, _, RC)),
                 findall(L, ( member(element(N, A, EC), RC), local_name(N, LN), boxed(LN),
                              boxed_logic(LN, A, EC, L) ), R) ),
            Rows).
boxed_logic(functionDefinition, A, C, function(Ps, K, L)) :- !,
    params(C, Ps), attr(kind, A, K0, 'FEEL'), kind(K0, K), logic_of(C, L).
boxed_logic(conditional, _, C, conditional(I, T, E)) :- !,
    part_logic(C, if, I), part_logic(C, then, T), part_logic(C, else, E).
boxed_logic(filter, _, C, filter(I, M)) :- !,
    part_logic(C, in, I), part_logic(C, match, M).
boxed_logic(L, A, C, iterator(L, V, I, B)) :-
    memberchk(L, [for, some, every]), !,
    attr(iteratorVariable, A, V, ''),
    part_logic(C, in, I),
    ( L == for -> part_logic(C, return, B) ; part_logic(C, satisfies, B) ).

part_logic(C, Part, L) :-
    (   child(C, Part, element(_, _, PC)) -> logic_of(PC, L) ; L = none ).

entry_text(C, T) :-
    ( child_text(C, text, T0) -> true ; T0 = '' ),
    normalize_space(atom(T), T0).

hit('UNIQUE', unique).          hit('FIRST', first).
hit('PRIORITY', priority).      hit('ANY', any).
hit('COLLECT', collect).        hit('RULE ORDER', rule_order).
hit('OUTPUT ORDER', output_order).
hit(H, unique) :- \+ memberchk(H, ['UNIQUE','FIRST','PRIORITY','ANY','COLLECT','RULE ORDER','OUTPUT ORDER']).

logic_type(table(_, _, _, [out(_, T, _, _)], _), T) :- T \== ''.

		 /*******************************
		 *        STTR METADATA         *
		 *******************************/

%   The uitvoeringsregels (execution rules) of an STTR model: the question
%   an input asks, its explanation, and the value a "vaste waarde" input
%   has. Keyed by id, as uitvoeringsregelRef refers to them.
sttr_rules(Children, Rules) :-
    findall(Id-Meta,
            ( member(element(N, _, C), Children), local_name(N, extensionElements),
              child(C, uitvoeringsregels, element(_, _, RC)),
              child(RC, uitvoeringsregel, element(_, RA, UC)),
              attr(id, RA, Id, ''),
              sttr_rule_meta(UC, Meta) ),
            Rules).

sttr_rule_meta(C, Meta) :-
    findall(M, sttr_meta(C, M), Meta).

sttr_meta(C, question(Q)) :-
    child(C, vraag, element(_, _, VC)), child_text(VC, vraagTekst, Q0), clean(Q0, Q).
sttr_meta(C, datatype(T)) :-
    (   child(C, vraag, element(_, _, VC)) ; child(C, vasteWaarde, element(_, _, VC)) ),
    child_text(VC, gegevensType, T).
sttr_meta(C, fixed(V)) :-
    child(C, vasteWaarde, element(_, _, VC)), child_text(VC, waarde, V).
sttr_meta(C, explanation(T)) :-
    child(C, uitvoeringsregelToelichting, element(_, _, TC)),
    child_text(TC, toelichting, T0), clean(T0, T).

%   An element's own metadata: its description, and for STTR the
%   uitvoeringsregel it refers to.
meta(C, SttrRules, Meta) :-
    findall(M, element_meta(C, SttrRules, M), Meta0),
    append(Meta0, Meta1), Meta = Meta1.

element_meta(C, _, [description(D)]) :-
    child_text(C, description, D0), clean(D0, D), D \== ''.
element_meta(C, S, [sttr_ref(H)|M]) :-
    child(C, extensionElements, element(_, _, XC)),
    member(element(N, A, _), XC),
    local_name(N, L), memberchk(L, [uitvoeringsregelRef, functioneleStructuurRef]),
    attr(href, A, H, ''),
    dmn_href_id(H, Id),
    ( memberchk(Id-M, S) -> true ; M = [] ).

%   STTR escapes Markdown-ish punctuation with backslashes (`\(bouw\)`).
clean(T0, T) :-
    atomic_list_concat(Parts, '\\', T0), atomic_list_concat(Parts, T1),
    normalize_space(atom(T), T1).

		 /*******************************
		 *          XML HELPERS         *
		 *******************************/

local_name(_:L, L) :- !.
local_name(L, L).

root_ns(NS:_, NS) :- !.
root_ns(_, '').

version_of(NS, V) :-
    (   sub_atom(NS, _, _, _, '20151101') -> V = dmn11
    ;   sub_atom(NS, _, _, _, '20180521') -> V = dmn12
    ;   sub_atom(NS, _, _, _, '20191111') -> V = dmn13
    ;   sub_atom(NS, _, _, _, '20211108') -> V = dmn14
    ;   sub_atom(NS, _, _, _, '20230324') -> V = dmn15
    ;   sub_atom(NS, _, _, _, '20240513') -> V = dmn16
    ;   sub_atom(NS, _, _, _, 'DMN/1.6') -> V = dmn16
    ;   V = unknown
    ).

attr(Name, Attrs, V, Default) :-
    (   member(K=V0, Attrs), local_name(K, Name) -> V = V0 ; V = Default ).

truth(true, true) :- !.
truth(V, true) :- atom(V), downcase_atom(V, true), !.
truth(_, false).

child(C, Local, element(N, A, CC)) :-
    member(element(N, A, CC), C), local_name(N, Local).

child_text(C, Local, Text) :-
    child(C, Local, element(_, _, TC)), !,
    texts(TC, Ts), atomic_list_concat(Ts, Text0),
    atom_string(Text0, S), split_string(S, "", " \t\n\r", [S1]), atom_string(Text, S1).

texts([], []).
texts([T|Ts], [T|Rs]) :- atomic(T), !, texts(Ts, Rs).
texts([_|Ts], Rs) :- texts(Ts, Rs).

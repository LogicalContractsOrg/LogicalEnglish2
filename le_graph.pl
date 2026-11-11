/** <module> Logical English Graph Generator
    
    This module generates a graph representation of a Logical English knowledge base,
    suitable for rendering with Cytoscape.js.
*/

:- module(le_graph, [kb_graph/2, radial_tree/4, query_at_offset/3]).

:- use_module(le_kbs).
:- use_module(le_verifier).
:- use_module(le_system_templates).
:- use_module(reasoner).
:- use_module(library(time)).

:- discontiguous node/2.
:- discontiguous edge/3.

%!  kb_graph(+KBModule:atom, -Graph:dict) is det.
%
%   Generates a graph representation of the given KB module.
kb_graph(KB, _{nodes: Nodes, edges: Edges}) :-
    collect_nodes(KB, Nodes),
    collect_edges(KB, Nodes, Edges).

%!  collect_nodes(+KBModule:atom, -Nodes:list) is det.
%
%   Every node id is unique: Cytoscape refuses a second element with the
%   id of one it already has, so a duplicate would be lost.
collect_nodes(KB, Nodes) :-
    findall(Node, node(KB, Node), Nodes0),
    unique_by_id(Nodes0, Nodes).

%!  unique_by_id(+Elements:list, -Unique:list) is det.
%
%   The elements whose `data.id` has not been seen before, in order.
unique_by_id(Elements, Unique) :-
    unique_by_id(Elements, [], Unique).

unique_by_id([], _, []).
unique_by_id([E|Es], Seen, Unique) :-
    (   get_dict(data, E, Data), get_dict(id, Data, Id), \+ memberchk(Id, Seen)
    ->  Unique = [E|Rest], unique_by_id(Es, [Id|Seen], Rest)
    ;   unique_by_id(Es, Seen, Unique)
    ).

%!  bookkeeping_clause(+Head) is semidet.
%
%   A clause the compiler asserts for its own use, never knowledge the user
%   wrote: `le_kb/1`, the expected-answer test records (`le_expected` of ANY
%   arity, which used to leak into the graph as bogus fact nodes), and every
%   other system predicate of le_kbs (`le_unknown/1` for a `; undefined`
%   template, `le_provenance_required/0`, `le_expected_changes/3`, ...).
%   Scenarios and queries are system predicates too, but they are the graph's
%   own nodes, handled before this check.
bookkeeping_clause(Head) :-
    callable(Head),
    functor(Head, F, A),
    (   F == le_kb
    ;   F == le_expected
    ;   le_kbs:is_system_predicate(F/A)
    ).

% Template Nodes
node(KB, _{data: _{id: TID, type: "template", label: Label, functor: F, arity: Arity,
                   source: _{start: Start, end: End}}}) :-
    current_predicate(KB:le_dict/1),
    KB:le_dict(Dict),
    (Dict = dict(FA, NTs, WV, _, _, _, _) ; Dict = dict(FA, NTs, WV, _, _, _) ; Dict = dict(FA, NTs, WV, _, _) ; Dict = dict(FA, NTs, WV, _) ; Dict = dict(FA, NTs, WV)),
    \+ le_system_templates:le_system_template(dict(FA, NTs, WV)),
    FA = [F|Args],
    length(Args, Arity),
    format(atom(TID), 'template_~w_~w', [F, Arity]),
    copy_term(NTs-WV, NTsC-WVC),
    maplist(fill_type_with_stars, NTsC),
    le_kbs:canonical_string(WVC, Label),
    ( KB:le_source_info(Ref, Start, End, template), catch(clause(KB:le_dict(Dict), true, Ref), _, fail), (Dict = dict(FA, NTs, WV, _) ; Dict = dict(FA, NTs, WV)) -> true ; Start = 0, End = 0).

% Rule, Fact, Scenario, and Query Nodes
node(KB, _{data: Data}) :-
    KB:le_source_info(Ref, Start, End, RID),
    \+ member(RID, [template, ontology, session_fact, none]),
    ( catch(clause(KB:Head, Body, Ref), _, fail) -> true ; Head = unknown, Body = true ),
    % Exclude the compiler's bookkeeping clauses (bookkeeping_clause/1): for
    % instance each `; undefined` template asserts an le_unknown/1 fact under
    % the same source id, `template_unknown`, and two of them made two nodes
    % with one id, which Cytoscape rejects.
    \+ ( Head \= scenario(_, _), Head \= query_info(_, _, _), bookkeeping_clause(Head) ),
    ( Head = scenario(SName, _) -> 
        format(atom(SID), 'scenario_~w', [SName]),
        Data = _{id: SID, type: "scenario", label: SName, source: _{start: Start, end: End}}
    ; Head = query_info(QName, _, _) ->
        format(atom(QID), 'query_~w', [QName]),
        Data = _{id: QID, type: "query", label: QName, source: _{start: Start, end: End}}
    ; Body == true -> 
        rule_label(KB, Head, Body, Label),
        Data = _{id: RID, type: "fact", label: Label, source: _{start: Start, end: End}}
    ; 
        rule_label(KB, Head, Body, Label),
        Data = _{id: RID, type: "rule", label: Label, source: _{start: Start, end: End}}
    ).

% Scenario Fact Nodes
node(KB, _{data: _{id: FID, type: "fact", label: Label, parent: SID,
                   source: _{start: Start, end: End}}}) :-
    current_predicate(KB:scenario/2),
    KB:scenario(SName, Terms),
    format(atom(SID), 'scenario_~w', [SName]),
    member(FactItem, Terms),
    ( FactItem = fact_with_source(Term, Start, End) -> true ; Term = FactItem, Start = 0, End = 0 ),
    rule_label(KB, Term, true, Label),
    format(atom(FID), 'fact_~w', [Start]).

% Scenario containment edges (to ensure Cytoscape sees the relationship)
edge(_KB, Nodes, _{data: _{id: EID, source: SID, target: FID, type: "scopes"}}) :-
    member(SNode, Nodes),
    get_dict(data, SNode, SData),
    get_dict(type, SData, "scenario"),
    get_dict(id, SData, SID),
    
    member(FNode, Nodes),
    get_dict(data, FNode, FData),
    get_dict(type, FData, "fact"),
    get_dict(parent, FData, SID),
    get_dict(id, FData, FID),
    
    atomic_list_concat([SID, '-contains-', FID], EID).

% Type Nodes
node(KB, _{data: _{id: TID, type: "type", label: Type,
                   source: _{start: Start, end: End}}}) :-
    catch(le_kbs:is_a_hierarchy(KB, Hierarchy), _, fail),
    flatten_hierarchy(Hierarchy, Flat),
    member(Node, Flat),
    Type = Node.type,
    (   Node.range \== null
    ->  Start = Node.range.start, End = Node.range.end
    ;   Start = 0, End = 0
    ),
    format(atom(TID), 'type_~w', [Type]).

flatten_hierarchy([], []).
flatten_hierarchy([Node|Rest], [Node|Flat]) :-
    flatten_hierarchy(Node.children, ChildrenFlat),
    flatten_hierarchy(Rest, RestFlat),
    append(ChildrenFlat, RestFlat, Flat).

% Edges. A rule whose body has two literals of one template (`a situation has
% factor a factor` twice, say) yields the same "uses" edge twice; one is kept.
collect_edges(KB, Nodes, Edges) :-
    findall(Edge, edge(KB, Nodes, Edge), Edges0),
    unique_by_id(Edges0, Edges).

edge(KB, Nodes, _{data: _{id: EID, source: RID, target: TID, type: Type}}) :-
    member(Node, Nodes),
    get_dict(data, Node, Data),
    get_dict(id, Data, RID),
    get_dict(type, Data, RType),
    (RType == "rule" ; RType == "fact" ; RType == "query"),
    ( RID = RID_Atom, atom(RID_Atom) -> true ; RID = RID_Atom ),

    ( atom_concat('query_', QName, RID_Atom) ->
        KB:le_source_info(Ref, _, _, QName),
        ( catch(clause(KB:Head, Body, Ref), _, fail) -> true ; Head = unknown, Body = true )
    ; atom_concat('scenario_', SName, RID_Atom) ->
        KB:le_source_info(Ref, _, _, SName),
        ( catch(clause(KB:Head, Body, Ref), _, fail) -> true ; Head = unknown, Body = true )
    ; atom_concat('fact_', OffsetAtom, RID_Atom) -> 
        atom_number(OffsetAtom, Offset),
        ( (current_predicate(KB:scenario/2), catch(KB:scenario(_SName, Terms), _, fail), member(FactItem, Terms), (FactItem = fact_with_source(Head, Start, _End) -> Start == Offset ; Head = FactItem, Offset == 0)) -> true ; Head = unknown ),
        Body = true
    ; KB:le_source_info(Ref, _, _, RID_Atom),
      ( catch(clause(KB:Head, Body, Ref), _, fail) -> true ; Head = unknown, Body = true )
    ),
    ( Head = query_info(_, Goal, _) -> Body1 = Goal, Head1 = true ; Body1 = Body, Head1 = Head ),
    ( literal_uses_template(KB, Head1, TID, Nodes), Type = "uses"
    ; le_verifier:find_in_body(Body1, Literal),
      ( Literal = not(G) -> Type = "negates", G1 = G ; Type = "uses", G1 = Literal ),
      literal_uses_template(KB, G1, TID, Nodes)
    ),
    atomic_list_concat([RID, '-', TID, '-', Type], EID).

% ISA Edges (Hierarchy-based)
edge(KB, Nodes, _{data: _{id: EID, source: SubID, target: SuperID, type: "is-a"}}) :-
    catch(le_kbs:is_a_hierarchy(KB, Hierarchy), _, fail),
    flatten_hierarchy(Hierarchy, Flat),
    member(ParentNode, Flat),
    member(ChildNode, ParentNode.children),
    SubType = ChildNode.type,
    SuperType = ParentNode.type,
    
    member(SubNode, Nodes),
    get_dict(data, SubNode, SubData),
    get_dict(id, SubData, SubID),
    get_dict(label, SubData, SubType),
    
    member(SuperNode, Nodes),
    get_dict(data, SuperNode, SuperData),
    get_dict(id, SuperData, SuperID),
    get_dict(label, SuperData, SuperType),
    
    atomic_list_concat([SubID, '-isa-', SuperID], EID).

% Template defines Type Edges
edge(KB, Nodes, _{data: _{id: EID, source: TID, target: TypeID, type: "defines"}}) :-
    member(TNode, Nodes),
    get_dict(data, TNode, TData),
    get_dict(type, TData, "template"),
    get_dict(id, TData, TID),
    
    current_predicate(KB:le_dict/1),
    KB:le_dict(Dict),
    (Dict = dict(FA, NTs, _) ; Dict = dict(FA, NTs, _, _)),
    FA = [F|Args],
    length(Args, Arity),
    get_dict(functor, TData, F),
    get_dict(arity, TData, Arity),
    
    member(V-Type, NTs),
    atom(Type),
    
    member(TypeNode, Nodes),
    get_dict(data, TypeNode, TypeData),
    get_dict(type, TypeData, "type"),
    get_dict(label, TypeData, Type),
    get_dict(id, TypeData, TypeID),
    
    ( var(V) -> VName = 'var' ; VName = V ),
    atomic_list_concat([TID, '-defines-', TypeID, '-', VName], EID).





literal_uses_template(_KB, Literal, TID, Nodes) :-
    ( Literal = not(G) -> (compound(G) -> G =.. [F|Args] ; F = G, Args = [])
    ; compound(Literal) -> Literal =.. [F|Args]
    ; F = Literal, Args = []
    ),
    length(Args, Arity),
    member(Node, Nodes),
    get_dict(data, Node, Data),
    get_dict(type, Data, "template"),
    get_dict(functor, Data, F),
    get_dict(arity, Data, Arity),
    get_dict(id, Data, TID).
% --- Helpers ---

fill_type_with_stars(V-Type) :-
    (   atom(Type) -> format(atom(V), "*~w*", [Type])
    ;   V = '*variable*'
    ).

rule_label(KB, Head, Body, Label) :-
    ( le_kbs:item_to_instance(KB, Head, HeadTokens) ->
        le_kbs:canonical_string(HeadTokens, HeadStr)
    ; term_string(Head, HeadStr)
    ),
    ( Body == true -> Label = HeadStr
    ; body_to_compact_le(KB, Body, BodyStr),
      format(string(Label), "~w\nif\n~w", [HeadStr, BodyStr])
    ).

body_to_compact_le(KB, Body, Str) :-
    findall(L, le_verifier:find_in_body(Body, L), Literals),
    ( Literals = [] -> Str = "..."
    ; maplist(literal_to_le(KB), Literals, LEs),
      atomic_list_concat(LEs, ',\n', FullBody),
      ( string_length(FullBody, Len), Len > 60 -> 
        sub_string(FullBody, 0, 60, _, Sub),
        string_concat(Sub, "...", Str)
      ; Str = FullBody
      )
    ).

literal_to_le(KB, L, Str) :-
    ( L = not(G) -> literal_to_le(KB, G, GStr), string_concat("not ", GStr, Str)
    ; le_kbs:item_to_instance(KB, L, Tokens) -> le_kbs:canonical_string(Tokens, Str)
    ; term_string(L, Str)
    ).


/* ---------------------------------------------------------------------------
   Radial tree of a query (editor/radial-tree.html)

   The tree that the reasoner explores for a query, as the program states it:
   the query at the root; under a condition, the rules that can conclude it
   (alternatives, "OR"), plus the facts of the program and the facts that the
   scenarios give; under a rule, the conditions of its body ("AND", "OR",
   "NOT"). It uses the labels and source ranges of the Source Graph above.

   Each node can carry how often it holds in the program's scenarios, and the
   tree carries each scenario's test result for the query (its `expects
   answers` line), when the program has one.
--------------------------------------------------------------------------- */

%!  query_at_offset(+KB, +Offset:integer, -QueryName) is semidet.
%
%   The query whose statement contains Offset (a character position in the
%   program's text). Fails when Offset is not inside a query.
query_at_offset(KB, Offset, QName) :-
    current_predicate(KB:query_info/3),
    findall(Len-Q,
            ( clause(KB:query_info(Q, _, _), true, Ref),
              KB:le_source_info(Ref, Start, End, _),
              Start =< Offset, Offset =< End,
              Len is End - Start ),
            Found),
    keysort(Found, [_-QName|_]).

%!  radial_tree(+KB, +QueryName, +Options:list, -Tree:dict) is det.
%
%   Options: depth(D), how many levels of conditions to unfold (default 4);
%   held(Bool), whether to evaluate every node in every scenario (default
%   true). Tree is a dict ready for JSON:
%   `{query, text, source, tree, scenarios, truncated, held_complete}`, or
%   `{error, error_code}` when the query does not exist.
radial_tree(KB, QName0, Options, Tree) :-
    (   rt_query(KB, QName0, QName, Goal, Items, Start, End)
    ->  option(depth(Depth), Options, 4),
        option(held(Held), Options, true),
        nb_setval(le_rt_count, 0),
        nb_setval(le_rt_truncated, false),
        query_text(KB, Items, Text),
        rt_root(KB, QName, Goal, Text, Start-End, Depth, Root0),
        rt_scenarios(KB, Scenarios),
        (   Held == true, Scenarios \== []
        ->  rt_held(KB, Scenarios, Root0, Root1, Complete)
        ;   Root1 = Root0, Complete = true
        ),
        rt_strip_goals(Root1, Root),
        get_time(T0), TestsDeadline is T0 + 20,
        nb_setval(le_rt_tests_deadline, TestsDeadline),
        maplist(rt_test_result(KB, QName), Scenarios, ScenarioDicts),
        nb_getval(le_rt_truncated, Truncated),
        term_string(QName, QS),
        Tree = _{query: QS, text: Text, source: _{start: Start, end: End},
                 tree: Root, scenarios: ScenarioDicts,
                 truncated: Truncated, held_complete: Complete}
    ;   Tree = _{error: "No such query", error_code: "no_query"}
    ).

rt_query(KB, QName0, QName, Goal, Items, Start, End) :-
    current_predicate(KB:query_info/3),
    (   atom(QName0) -> Q = QName0
    ;   string(QName0) -> atom_string(Q, QName0)
    ;   Q = QName0
    ),
    (   clause(KB:query_info(Q, Goal, Items), true, Ref) -> QName = Q
    ;   atom(Q), atom_number(Q, N), clause(KB:query_info(N, Goal, Items), true, Ref) -> QName = N
    ),
    !,
    ( KB:le_source_info(Ref, Start, End, _) -> true ; Start = 0, End = 0 ).

query_text(KB, Items, Text) :-
    findall(S, ( member(I, Items), catch(le_kbs:item_to_le_string(I, S), _, fail) ), Ss),
    (   Ss == []
    ->  findall(S, ( member(I, Items), catch(literal_to_le(KB, I, S), _, fail) ), Ss2),
        atomic_list_concat(Ss2, ' and ', A)
    ;   atomic_list_concat(Ss, ' and ', A)
    ),
    atom_string(A, Text).

%   The most nodes a tree has: beyond, a condition is not unfolded.
rt_max_nodes(600).

rt_new_id(Id) :-
    nb_getval(le_rt_count, N0), N is N0 + 1, nb_setval(le_rt_count, N),
    format(atom(Id), 'n~w', [N]).

rt_room :-
    nb_getval(le_rt_count, N), rt_max_nodes(Max),
    (   N < Max -> true ; nb_setval(le_rt_truncated, true), fail ).

%   The root: the query. A query of one condition shows the rules of that
%   condition right under it (the query's alternatives, "OR"); a query of
%   several shows its conditions ("AND").
rt_root(KB, QName, Goal, Text, Start-End, Depth, Root) :-
    rt_new_id(Id),
    term_string(QName, Label),
    rt_body(KB, Goal, ctx(0, Depth, []), Children0, Connector0),
    (   Children0 = [Only], get_dict(kind, Only, "condition"), \+ get_dict(negated, Only, true)
    ->  get_dict(children, Only, Children),
        get_dict(connector, Only, Connector)
    ;   Children = Children0, Connector = Connector0
    ),
    Root = _{id: Id, kind: "query", label: Label, text: Text, connector: Connector,
             source: _{start: Start, end: End}, children: Children, goal: Goal}.

%!  rt_body(+KB, +Goal, +Ctx, -Children:list, -Connector) is det.
%
%   The nodes of a body (or a query): its conditions, and how they combine
%   ("AND", "OR", or null for one condition).
rt_body(KB, Goal, Ctx, Children, Connector) :-
    rt_strip(Goal, G, _),
    (   rt_conj(G)
    ->  rt_flatten(G, and, Parts), Connector = "AND"
    ;   rt_disj(G)
    ->  rt_flatten(G, or, Parts), Connector = "OR"
    ;   Parts = [Goal], Connector = null
    ),
    rt_nodes(KB, Parts, Ctx, Children).

rt_nodes(_, [], _, []).
rt_nodes(KB, [P|Ps], Ctx, Nodes) :-
    (   rt_node(KB, P, Ctx, N) -> Nodes = [N|Rest] ; Nodes = Rest ),
    rt_nodes(KB, Ps, Ctx, Rest).

rt_strip(le_at(G0, S0, E0), G, Src) :- !,
    (   G0 = le_at(_, _, _) -> rt_strip(G0, G, Src) ; G = G0, Src = S0-E0 ).
rt_strip(G, G, none).

rt_conj((_, _)).
rt_conj(and(_, _)).
rt_disj((_ ; _)).
rt_disj(or(_, _)).

rt_flatten(G0, Op, Parts) :-
    rt_strip(G0, G, _),
    (   Op == and, ( G = (A, B) ; G = and(A, B) )
    ->  rt_flatten(A, Op, PA), rt_flatten(B, Op, PB), append(PA, PB, Parts)
    ;   Op == or, ( G = (A ; B) ; G = or(A, B) )
    ->  rt_flatten(A, Op, PA), rt_flatten(B, Op, PB), append(PA, PB, Parts)
    ;   Parts = [G0]
    ).

rt_source(none, null) :- !.
rt_source(S-E, _{start: S, end: E}).

%!  rt_node(+KB, +Goal, +Ctx, -Node) is semidet.
%
%   The node of one part of a body. Fails for `true`, which shows nothing.
rt_node(KB, Goal0, Ctx, Node) :-
    rt_strip(Goal0, G, Src),
    rt_node(G, Goal0, Src, KB, Ctx, Node).

rt_node(true, _, _, _, _, _) :- !, fail.
rt_node(G, Goal0, Src, KB, Ctx, Node) :-
    ( rt_conj(G) ; rt_disj(G) ), !,
    rt_junction(KB, Goal0, Src, Ctx, Node).
rt_node(not(G0), Goal0, Src0, KB, Ctx, Node) :- !,
    rt_strip(G0, G, Src1),
    ( Src1 == none -> Src = Src0 ; Src = Src1 ),
    (   ( rt_conj(G) ; rt_disj(G) )
    ->  rt_junction(KB, G0, Src, Ctx, Node0)
    ;   rt_node(G, G0, Src, KB, Ctx, Node0)
    ),
    Node = Node0.put(_{negated: true, goal: Goal0}).
% `according to` someone, and a flip query: the goal inside, still wrapped
% in its own source range (le_at/3)
rt_node(le_scoped(G, _), _, _, KB, Ctx, Node) :- !,
    rt_node(KB, G, Ctx, Node).
rt_node(le_flip(G, _), _, _, KB, Ctx, Node) :- !,
    rt_node(KB, G, Ctx, Node).
rt_node(forall(A, B), Goal0, Src, KB, Ctx, Node) :- !,
    rt_aggregate(KB, "FOR ALL", [A, B], Goal0, Src, Ctx, Node).
rt_node(G, Goal0, Src, KB, Ctx, Node) :-
    rt_aggregate_goal(G, Name, Inner), !,
    rt_aggregate(KB, Name, [Inner], Goal0, Src, Ctx, Node).
rt_node(G, Goal0, Src, KB, Ctx, Node) :-
    rt_condition(KB, G, Goal0, Src, Ctx, Node).

rt_aggregate_goal(sum(_, G, _), "SUM", G).
rt_aggregate_goal(count(_, G, _), "COUNT", G).
rt_aggregate_goal(min(_, G, _), "MIN", G).
rt_aggregate_goal(max(_, G, _), "MAX", G).
rt_aggregate_goal(average(_, G, _), "AVERAGE", G).
rt_aggregate_goal(list([each|_], G, _), "LIST", G).

%   A group of conditions inside a body ("AND" or "OR" nested in the other).
rt_junction(KB, Goal, Src, Ctx, Node) :-
    rt_new_id(Id),
    rt_body(KB, Goal, Ctx, Children, Connector),
    ( Connector == "OR" -> Label = "or" ; Label = "and" ),
    rt_source(Src, Source),
    Node = _{id: Id, kind: "group", label: Label, connector: Connector,
             source: Source, children: Children, goal: Goal}.

rt_aggregate(KB, Name, Parts, Goal, Src, Ctx, Node) :-
    rt_new_id(Id),
    rt_nodes(KB, Parts, Ctx, Children),
    ( catch(literal_to_le(KB, Goal, Label0), _, fail) -> Label = Label0 ; Label = Name ),
    rt_source(Src, Source),
    Node = _{id: Id, kind: "group", label: Label, connector: Name,
             source: Source, children: Children, goal: Goal}.

%   One condition: a literal of a template. Unfolded into the rules that
%   conclude it, the facts of the program, and the facts of the scenarios.
rt_condition(KB, L, Goal0, Src, ctx(D, Max, Path), Node) :-
    rt_new_id(Id),
    ( catch(literal_to_le(KB, L, Label0), _, fail) -> Label = Label0 ; term_string(L, Label) ),
    rt_source(Src, Source),
    Base = _{id: Id, label: Label, source: Source, goal: Goal0, connector: null, children: []},
    (   \+ callable(L)
    ->  Node = Base.put(_{kind: "builtin", goal: none})
    ;   L = le_table(Table, _)
    ->  % a decision table: its name; looked up with its row unknown, it
        % says nothing, so it is not evaluated
        ( atom(Table) -> atomic_list_concat(Ws, '_', Table), atomic_list_concat(Ws, ' ', TL) ; term_string(Table, TL) ),
        Node = Base.put(_{kind: "table", label: TL, goal: none})
    ;   functor(L, F, A),
        (   \+ rt_user_predicate(KB, F, A)
        ->  % a calculation or a comparison: its numbers come from the
            % conditions before it, so alone it says nothing
            Node = Base.put(_{kind: "builtin", goal: none})
        ;   memberchk(F/A, Path)
        ->  Node = Base.put(_{kind: "condition", recursive: true})
        ;   D >= Max
        ->  Node = Base.put(_{kind: "condition", more: true})
        ;   \+ rt_room
        ->  Node = Base.put(_{kind: "condition", more: true})
        ;   D1 is D + 1,
            Ctx1 = ctx(D1, Max, [F/A|Path]),
            findall(R, rt_rule(KB, L, Ctx1, R), Rules),
            rt_fact_count(KB, L, NFacts),
            ( rt_scenario_predicate(KB, F, A) -> InScenarios = true ; InScenarios = false ),
            (   Rules == []
            ->  Node = Base.put(_{kind: "condition", facts: NFacts, given: InScenarios})
            ;   rt_data_leaves(KB, L, NFacts, InScenarios, Leaves),
                Rules = [Rule], Leaves == []
            ->  % one rule only: the condition and the rule are one node,
                % which leads to the source of the rule
                Node = Base.put(_{kind: "condition", connector: Rule.connector,
                                  children: Rule.children, rule: Rule.rule,
                                  tip: Rule.tip, source: Rule.source})
            ;   rt_data_leaves(KB, L, NFacts, InScenarios, Leaves),
                append(Rules, Leaves, Children),
                ( Children = [_, _|_] -> Connector = "OR" ; Connector = null ),
                Node = Base.put(_{kind: "condition", connector: Connector, children: Children})
            )
        )
    ).

rt_user_predicate(KB, F, A) :-
    functor(H, F, A),
    (   current_predicate(KB:F/A), \+ predicate_property(KB:H, imported_from(_)), clause(KB:H, _)
    ;   rt_scenario_predicate(KB, F, A)
    ;   current_predicate(KB:le_dict/1), KB:le_dict(Dict), arg(1, Dict, [F|Args]), length(Args, A),
        \+ le_system_templates:le_system_template(Dict)
    ), !.

rt_scenario_predicate(KB, F, A) :-
    current_predicate(KB:scenario/2),
    KB:scenario(_, Terms),
    member(T0, Terms),
    ( T0 = fact_with_source(T, _, _) -> true ; T = T0 ),
    ( T = (H :- _) -> true ; H = T ),
    callable(H), functor(H, F, A), !.

%   A rule that concludes L (its head unified with a copy of L), with the
%   conditions of its body under it.
rt_rule(KB, L, Ctx, Node) :-
    copy_term(L, H),
    functor(H, F, A), current_predicate(KB:F/A),
    clause(KB:H, Body, Ref),
    Body \== true,
    KB:le_source_info(Ref, Start, End, RID),
    \+ bookkeeping_clause(H),
    rt_new_id(Id),
    ( catch(literal_to_le(KB, H, Label0), _, fail) -> Label = Label0 ; term_string(H, Label) ),
    ( catch(rule_label(KB, H, Body, Tip0), _, fail) -> Tip = Tip0 ; Tip = Label ),
    rt_body(KB, Body, Ctx, Children, Connector),
    term_string(RID, RIDS),
    Node = _{id: Id, kind: "rule", label: Label, tip: Tip, rule: RIDS, connector: Connector,
             source: _{start: Start, end: End}, children: Children, goal: Body}.

rt_fact_count(KB, L, N) :-
    copy_term(L, H),
    functor(H, F, A),
    (   current_predicate(KB:F/A)
    ->  aggregate_all(count, ( clause(KB:H, true, Ref), KB:le_source_info(Ref, _, _, _) ), N)
    ;   N = 0
    ).

%   Under a condition that has rules, the facts that also give it: one leaf
%   for the program's facts, one for the scenarios'.
rt_data_leaves(KB, L, NFacts, InScenarios, Leaves) :-
    (   NFacts > 0
    ->  rt_new_id(Id1),
        copy_term(L, H),
        (   clause(KB:H, true, Ref), KB:le_source_info(Ref, S, E, _)
        ->  Source = _{start: S, end: E} ; Source = null ),
        ( catch(literal_to_le(KB, L, Label), _, fail) -> true ; term_string(L, Label) ),
        F1 = [_{id: Id1, kind: "facts", label: Label, facts: NFacts, source: Source,
                connector: null, children: [], goal: L}]
    ;   F1 = []
    ),
    (   InScenarios == true
    ->  rt_new_id(Id2),
        ( catch(literal_to_le(KB, L, Label2), _, fail) -> true ; term_string(L, Label2) ),
        F2 = [_{id: Id2, kind: "given", label: Label2, source: null,
                connector: null, children: [], goal: none}]
    ;   F2 = []
    ),
    append(F1, F2, Leaves).

%   The program's scenarios, in order.
rt_scenarios(KB, Scenarios) :-
    (   current_predicate(KB:scenario/2)
    ->  findall(S, clause(KB:scenario(S, _), true), Ss0),
        list_to_set(Ss0, Scenarios)
    ;   Scenarios = []
    ).

%!  rt_held(+KB, +Scenarios, +Root0, -Root, -Complete) is det.
%
%   Every node gets `held`, one status per scenario ("yes", "no",
%   "unknown", or "skipped" when the time allowed ran out): whether some
%   instance of the node holds when that scenario is loaded. The allowance
%   is 2 seconds a goal and 20 seconds in total; Complete is false when
%   that ran out.
rt_held(KB, Scenarios, Root0, Root, Complete) :-
    rt_goals(Root0, Goals, []),
    get_time(T0), Deadline is T0 + 20,
    nb_setval(le_rt_complete, true),
    current_prolog_flag(le_failure_explanations, FE),
    setup_call_cleanup(
        set_prolog_flag(le_failure_explanations, false),
        maplist(rt_held_in(KB, Goals, Deadline), Scenarios, PerScenario),
        set_prolog_flag(le_failure_explanations, FE)),
    nb_getval(le_rt_complete, Complete),
    % PerScenario: one list of Id-Status per scenario
    rt_put_held(Root0, PerScenario, Root).

rt_goals(Node, [Id-Goal|Gs], Tail) :-
    get_dict(id, Node, Id), get_dict(goal, Node, Goal),
    get_dict(children, Node, Children),
    foldl(rt_goals_acc, Children, Gs, Tail).
rt_goals_acc(Child, Gs, Tail) :- rt_goals(Child, Gs, Tail).

rt_held_in(KB, Goals, Deadline, Scenario, Statuses) :-
    createSession(KB, SM),
    setup_call_cleanup(
        true,
        (   catch(le_kbs:setScenarion(SM, Scenario), _, fail)
        ->  maplist(rt_status(SM, Deadline), Goals, Statuses)
        ;   findall(Id-"skipped", member(Id-_, Goals), Statuses)
        ),
        destroySession(SM)).

rt_status(_, _, Id-none, Id-null) :- !.
rt_status(SM, Deadline, Id-Goal0, Id-Status) :-
    get_time(Now),
    (   Now >= Deadline
    ->  nb_setval(le_rt_complete, false), Status = "skipped"
    ;   Limit is min(2, Deadline - Now),
        copy_term(Goal0, Goal),
        catch(call_with_time_limit(Limit, rt_holds(Goal, SM, Status)), E,
              rt_status_error(E, Status))
    ).

%   Out of time: not checked, and the counts are incomplete. Another error
%   (a goal that cannot run alone): no status.
rt_status_error(time_limit_exceeded, "skipped") :- !,
    nb_setval(le_rt_complete, false).
rt_status_error(E, _) :-
    nonvar(E), ( E = unwind(_) ; E == '$aborted' ), !,
    throw(E).
rt_status_error(_, null).

rt_holds(Goal, SM, Status) :-
    (   once(( reasoner:without_explanations(reasoner:i(Goal, SM, U, _)), U == [] ))
    ->  Status = "yes"
    ;   once(reasoner:without_explanations(reasoner:i(Goal, SM, _, _)))
    ->  Status = "unknown"
    ;   Status = "no"
    ).

rt_put_held(Node0, PerScenario, Node) :-
    get_dict(id, Node0, Id),
    findall(S, ( member(Pairs, PerScenario), memberchk(Id-S, Pairs) ), Held),
    get_dict(children, Node0, Cs0),
    maplist(rt_put_held_child(PerScenario), Cs0, Cs),
    Node = Node0.put(_{held: Held, children: Cs}).

rt_put_held_child(PerScenario, C0, C) :-
    rt_put_held(C0, PerScenario, C).

rt_strip_goals(Node0, Node) :-
    del_dict(goal, Node0, _, Node1),
    get_dict(children, Node1, Cs0),
    maplist(rt_strip_goals, Cs0, Cs),
    Node = Node1.put(children, Cs).

%   A scenario's test result for the query: what its `expects answers` line
%   expects, the answers the query gets, and whether they agree.
rt_test_result(KB, QName, Scenario, Dict) :-
    term_string(Scenario, SName),
    (   clause(KB:scenario(Scenario, _), true, Ref), KB:le_source_info(Ref, S, E, _)
    ->  Source = _{start: S, end: E} ; Source = null ),
    (   current_predicate(KB:le_expected/4),
        KB:le_expected(QName, Scenario, Expected, Unknowns)
    ->  catch(le_kbs:run_one_test(KB, test(QName, Scenario, Expected, Unknowns), R, Got), _,
              ( R = error(QName, Scenario, 'error'), Got = none )),
        maplist(rt_answer_string, Expected, ExpectedStrings),
        ExpectedOut = ExpectedStrings
    ;   % no expectation: the answers only, while the 20 seconds last
        get_time(Now), nb_getval(le_rt_tests_deadline, Deadline),
        (   Now < Deadline
        ->  catch(le_kbs:run_one_test(KB, test(QName, Scenario, [], any), R0, Got), _,
                  ( R0 = error(QName, Scenario, 'error'), Got = none )),
            ( R0 = error(_, _, _) -> R = R0 ; R = none )
        ;   R = not_run(QName, Scenario), Got = none
        ),
        ExpectedOut = null
    ),
    (   Got = got(Answers0, _) -> maplist(rt_answer_string, Answers0, Answers) ; Answers = [] ),
    (   R = pass(_, _) -> Result = "pass"
    ;   R = none -> Result = "none"
    ;   R = error(_, _, Msg) -> Result = "error", term_string(Msg, Message)
    ;   R = not_run(_, _) -> Result = "none", Message = "not run (time limit)"
    ;   Result = "fail"
    ),
    ( var(Message) -> Message = "" ; true ),
    Dict = _{name: SName, source: Source, expected: ExpectedOut, answers: Answers,
             result: Result, message: Message}.

rt_answer_string(string(S, _), Str) :- !, rt_answer_string(S, Str).
rt_answer_string(S, Str) :- ( string(S) -> Str = S ; term_string(S, Str) ).

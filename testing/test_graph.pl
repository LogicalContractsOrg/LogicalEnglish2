/** <module> Tests for the Source Graph generator (le_graph.pl).

    Pins down that bookkeeping clauses stay out of the graph — notably the
    expected-answer test records ("expects answers" scenario items compile to
    le_expected/4, which used to leak into the graph as bogus fact nodes
    because the exclusion guard only matched le_expected/3) — while all the
    substantive layers (templates, rules, facts, scenarios, queries) remain.

    Run with:  swipl -q -g run_tests -t halt testing/test_graph.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_graph, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_graph').

citizenship_graph(Nodes) :-
    le_kbs:load('examples/moreExamples/citizenship.le', KB),
    le_graph:kb_graph(KB, G),
    get_dict(nodes, G, Nodes).

node_label(N, L) :-
    get_dict(data, N, D),
    get_dict(label, D, L0),
    term_to_atom(L0, L).

:- begin_tests(source_graph).

% le_expected/N records are bookkeeping, not knowledge: no node shows them.
test(no_le_expected_nodes) :-
    citizenship_graph(Nodes),
    forall(( member(N, Nodes), node_label(N, L) ),
           \+ sub_atom(L, _, _, _, le_expected)).

% The substantive layers are all present.
test(graph_has_all_layers) :-
    citizenship_graph(Nodes),
    findall(T, ( member(N, Nodes), get_dict(data, N, D), get_dict(type, D, T) ), Ts0),
    sort(Ts0, Ts),
    forall(member(Expected, ["template", "rule", "fact", "scenario", "query"]),
           assertion(memberchk(Expected, Ts))).

% eu261_integration.le has two `; undefined` templates (each asserts an
% le_unknown/1 fact under the source id `template_unknown`), a
% `scenario facts require provenance.` statement and an `expects changes`
% item, and rules whose body uses one template twice. All of that used to
% produce two nodes with one id (which Cytoscape rejects, leaving the graph
% blank), bookkeeping fact nodes, and duplicate edge ids.
eu261_graph(Nodes, Edges) :-
    le_kbs:load('examples/regulatory/eu261_integration.le', KB),
    le_graph:kb_graph(KB, G),
    get_dict(nodes, G, Nodes),
    get_dict(edges, G, Edges).

ids(Elements, Ids) :-
    findall(Id, ( member(E, Elements), get_dict(data, E, D), get_dict(id, D, Id) ), Ids).

test(node_ids_unique) :-
    eu261_graph(Nodes, _),
    ids(Nodes, Ids),
    length(Ids, N), sort(Ids, Unique), length(Unique, N).

test(edge_ids_unique) :-
    eu261_graph(_, Edges),
    ids(Edges, Ids),
    length(Ids, N), sort(Ids, Unique), length(Unique, N).

% No compiler bookkeeping shows as a fact: not le_unknown/1, not
% le_provenance_required/0, not le_expected_changes/3.
test(no_bookkeeping_nodes) :-
    eu261_graph(Nodes, _),
    forall(( member(N, Nodes), node_label(N, L) ),
           \+ sub_atom(L, 0, _, _, le_)).

% The user's knowledge is all there: the judged template, the rule that
% decides it, the precedent facts, the four scenarios and queries.
test(eu261_layers) :-
    eu261_graph(Nodes, _),
    findall(T-L, ( member(N, Nodes), get_dict(data, N, D), get_dict(type, D, T), get_dict(label, D, L) ), TLs),
    assertion(memberchk("template"-"*event* is beyond the actual control of *carrier*", TLs)),
    assertion(memberchk("fact"-"wallentin hermann decided for inherent", TLs)),
    assertion(memberchk("scenario"-bird_strike, TLs)),
    assertion(memberchk("query"-flip, TLs)),
    aggregate_all(count, member("scenario"-_, TLs), 4),
    aggregate_all(count, member("query"-_, TLs), 4).

:- end_tests(source_graph).

/* The Radial Tree of a query (le_graph:radial_tree/4, editor/radial-tree.html):
   the rules under the query, the conditions under each rule, NOT on a
   negated condition, how often each node holds in the scenarios, and the
   scenarios' test results. */

claims_kb(KB) :-
    le_kbs:load('testing/fixtures/le/radial_tree_claims.le', KB, [skip_tests]).

tree_nodes(Node, [Node|Ns]) :-
    get_dict(children, Node, Cs),
    foldl([C, A0, A]>>( tree_nodes(C, CNs), append(A0, CNs, A) ), Cs, [], Ns).

node_by_label(Tree, Label, Node) :-
    tree_nodes(Tree, Ns),
    member(Node, Ns),
    get_dict(label, Node, L0), atom_string(L0, Label), !.

:- begin_tests(radial_tree).

test(query_at_offset) :-
    claims_kb(KB),
    clause(KB:query_info(covered, _, _), true, Ref),
    KB:le_source_info(Ref, Start, _, _),
    Inside is Start + 5,
    assertion(le_graph:query_at_offset(KB, Inside, covered)),
    assertion(\+ le_graph:query_at_offset(KB, 400, _)).

test(no_such_query) :-
    claims_kb(KB),
    le_graph:radial_tree(KB, "nothing", [], R),
    assertion(R.error_code == "no_query").

% One rule concludes "a claim is covered": the query and that rule are one
% node, and its two alternatives are under it, "OR".
test(tree_structure) :-
    claims_kb(KB),
    le_graph:radial_tree(KB, "covered", [], R),
    T = R.tree,
    assertion(T.kind == "query"),
    assertion(T.connector == "OR"),
    length(T.children, 2),
    node_by_label(T, "a claim is under the buildings section", B),
    assertion(B.connector == "AND"),
    node_by_label(T, "a claim concerns gradual wear", W),
    assertion(W.negated == true),
    assertion(W.given == true),
    node_by_label(T, "an item is a household item", H),
    assertion(H.facts == 1).

% Held in the scenarios, in order pipe, wear, tv.
test(held_and_test_results) :-
    claims_kb(KB),
    le_graph:radial_tree(KB, "covered", [], R),
    assertion(R.held_complete == true),
    assertion(R.tree.held == ["yes", "no", "yes"]),
    node_by_label(R.tree, "a claim concerns gradual wear", W),
    assertion(W.held == ["yes", "no", "yes"]),
    findall(N-Res, ( member(S, R.scenarios), N = S.name, Res = S.result ), Results),
    assertion(Results == ["pipe"-"pass", "wear"-"pass", "tv"-"pass"]).

% Depth 1 shows the query's conditions without unfolding them.
test(depth_limit) :-
    claims_kb(KB),
    le_graph:radial_tree(KB, "covered", [depth(1), held(false)], R),
    node_by_label(R.tree, "a claim is under the buildings section", B),
    assertion(B.more == true),
    assertion(B.children == []).

% eu261_integration.le: "it is not the case that" over an "and" group, and
% over a condition "according to the carrier" (le_scoped/2), used to fail
% (an instantiation error, and a condition shown as a calculation); a
% comparison and a decision table are not evaluated alone, so the counts
% are complete.
test(negated_group_and_scoped_condition) :-
    le_kbs:load('examples/regulatory/eu261_integration.le', KB, [skip_tests]),
    le_graph:radial_tree(KB, claim, [], R),
    assertion(\+ get_dict(error, R, _)),
    assertion(R.held_complete == true),
    node_by_label(R.tree, "the cancellation of a flight is due to extraordinary circumstances", C),
    assertion(C.kind == "condition"),
    assertion(C.negated == true),
    node_by_label(R.tree, "a number is greater than or equal to 14", B),
    assertion(B.kind == "builtin"),
    assertion(B.held == [null, null, null, null]).

:- end_tests(radial_tree).

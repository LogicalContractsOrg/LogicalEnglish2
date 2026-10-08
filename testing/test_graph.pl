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

<<<<<<< HEAD
=======
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

>>>>>>> 92331814ad247a300fe820fd74fe6908f2b1611f
:- end_tests(source_graph).

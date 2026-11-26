/** <module> LOMO's validity rules on our side: a check of a description against shapes/lomo-shapes.ttl

    check_file(+TTL, -Results)
    check_triples(+Triples, -Results)
        Results = [result(Focus, Path, Component, Value, Message), ...]
        Focus and Value are IRIs, literal texts, '_:' for a blank node, or
        '' when the result has no value (a count). Component is the SHACL
        constraint component's local name (`MinCountConstraintComponent`).
        Message says it in words, for the ledger and for File > Export.

    The project runs its checks with an online validator of the Commission.
    This is the same check, here, with nothing sent anywhere: an interpreter
    of the part of SHACL (the W3C language for checks on data) that LOMO's
    shapes use, reading the shapes file itself — targets by class (with the
    subclasses of the ontology) and by subject of a property; on a property:
    minCount, maxCount, nodeKind, datatype, uniqueLang, in, node (whose
    shape asks for hasValue). A shape that uses anything else is reported,
    not skipped (unsupported/2). The judge of this check is pySHACL
    (oracle/shacl_judge.py); test_lomo.pl compares the two on every file of
    the corpus, result by result.

    Copyright Miguel Calejo; Apache License 2.0, as the rest of this
    repository (../../NOTICE). Published "as is".
*/

:- module(lomo_shacl, [check_file/2, check_triples/2, result_message/2, unsupported/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(semweb/turtle)).
:- use_module(library(semweb/rdf_db), [rdf_is_bnode/1]).
:- use_module(corpus).

sh(L, I) :- atom_concat('http://www.w3.org/ns/shacl#', L, I).
rdf(L, I) :- atom_concat('http://www.w3.org/1999/02/22-rdf-syntax-ns#', L, I).
rdfs(L, I) :- atom_concat('http://www.w3.org/2000/01/rdf-schema#', L, I).
xsd(L, I) :- atom_concat('http://www.w3.org/2001/XMLSchema#', L, I).

:- dynamic shapes_/1, onto_/1.

shapes(Ts) :- shapes_(Ts), !.
shapes(Ts) :- shapes_file(F), rdf_read_turtle(F, Ts, [anon_prefix('_:s')]), assertz(shapes_(Ts)).

%   The ontology and its four word lists: the subclasses of a target class,
%   the scheme of a word.
onto(Ts) :- onto_(Ts), !.
onto(Ts) :-
    corpus_dir(C), atomic_list_concat([C, '/ontologies'], D),
    directory_files(D, Fs0), msort(Fs0, Fs),
    findall(T, ( member(F, Fs), file_name_extension(_, ttl, F),
                 atomic_list_concat([D, '/', F], P),
                 rdf_read_turtle(P, Ts0, [anon_prefix('_:o')]), member(T, Ts0) ), Ts),
    assertz(onto_(Ts)).

check_file(TTL, Results) :-
    rdf_read_turtle(TTL, Ts, [anon_prefix('_:d')]),
    check_triples(Ts, Results).

check_triples(Data, Results) :-
    shapes(S), onto(O),
    append(Data, O, G),
    findall(R, ( node_shape(S, Shape), shape_result(S, G, Shape, R) ), Results0),
    msort(Results0, Results).

t(Ts, S, P, O) :- member(rdf(S, P, O), Ts).

node_shape(S, Shape) :- rdf(type, T), sh('NodeShape', NS), t(S, Shape, T, NS), \+ rdf_is_bnode(Shape).

shape_result(S, G, Shape, result(F, Path, Comp, Value, Msg)) :-
    target(S, G, Shape, Focus),
    sh(property, PP), t(S, Shape, PP, PS),
    sh(path, PathP), t(S, PS, PathP, Path),
    findall(V, t(G, Focus, Path, V), Vs0), list_to_set(Vs0, Vs),
    constraint(S, G, PS, Vs, Comp, Value0),
    shown(Focus, F), shown(Value0, Value),
    result_message(result(F, Path, Comp, Value, _), Msg).

%   The focus nodes of a shape.
target(S, G, Shape, Focus) :-
    findall(F, ( sh(targetClass, TC), t(S, Shape, TC, C), instance_of(G, F, C) ), Fs1),
    findall(F, ( sh(targetSubjectsOf, TS), t(S, Shape, TS, P), t(G, F, P, _) ), Fs2),
    append(Fs1, Fs2, Fs0), list_to_set(Fs0, Fs),
    member(Focus, Fs).

instance_of(G, F, C) :-
    subclasses(G, C, Cs),
    rdf(type, T),
    findall(X, ( member(C1, Cs), t(G, X, T, C1) ), Xs0), list_to_set(Xs0, Xs),
    member(F, Xs).

subclasses(G, C, Cs) :- subclasses(G, [C], [C], Cs).
subclasses(_, [], Seen, Seen).
subclasses(G, [C|Q], Seen, Cs) :-
    rdfs(subClassOf, SC),
    findall(S, ( t(G, S, SC, C), \+ memberchk(S, Seen) ), New0), list_to_set(New0, New),
    append(Seen, New, Seen1), append(Q, New, Q1),
    subclasses(G, Q1, Seen1, Cs).

constraint(S, _, PS, Vs, 'MinCountConstraintComponent', '') :-
    sh(minCount, P), t(S, PS, P, literal(type(_, N0))), atom_number(N0, N),
    length(Vs, L), L < N.
constraint(S, _, PS, Vs, 'MaxCountConstraintComponent', '') :-
    sh(maxCount, P), t(S, PS, P, literal(type(_, N0))), atom_number(N0, N),
    length(Vs, L), L > N.
constraint(S, _, PS, Vs, 'NodeKindConstraintComponent', V) :-
    sh(nodeKind, P), t(S, PS, P, K), sh('IRI', K),
    member(V, Vs), ( V = literal(_) ; rdf_is_bnode(V) ).
constraint(S, _, PS, Vs, 'DatatypeConstraintComponent', V) :-
    sh(datatype, P), t(S, PS, P, D),
    member(V, Vs), \+ has_datatype(V, D).
constraint(S, _, PS, Vs, 'UniqueLangConstraintComponent', '') :-
    sh(uniqueLang, P), t(S, PS, P, literal(type(_, true))),
    findall(L, member(literal(lang(L, _)), Vs), Ls), msort(Ls, Sorted),
    append(_, [X, X|_], Sorted), !.
constraint(S, _, PS, Vs, 'InConstraintComponent', V) :-
    sh(in, P), t(S, PS, P, List), rdf_list(S, List, Allowed),
    member(V, Vs), \+ memberchk(V, Allowed).
constraint(S, G, PS, Vs, 'NodeConstraintComponent', V) :-
    sh(node, P), t(S, PS, P, Node),
    member(V, Vs), \+ conforms(S, G, Node, V).

has_datatype(literal(lang(_, _)), D) :- !, rdf(langString, D).
has_datatype(literal(type(T, _)), D) :- !, T == D.
has_datatype(literal(_), D) :- !, xsd(string, D).

%   A value conforms to a shape of hasValue constraints on its properties.
conforms(S, G, Node, V) :-
    forall(( sh(property, PP), t(S, Node, PP, PS) ),
           ( sh(path, PathP), t(S, PS, PathP, Path),
             forall(( sh(hasValue, HV), t(S, PS, HV, X) ), t(G, V, Path, X)) )).

rdf_list(S, L, Items) :-
    rdf(nil, Nil),
    (   L == Nil -> Items = []
    ;   rdf(first, F), rdf(rest, R),
        t(S, L, F, I), t(S, L, R, L1),
        rdf_list(S, L1, Is), Items = [I|Is]
    ).

shown('', '') :- !.
shown(X, '_:') :- atom(X), rdf_is_bnode(X), !.
shown(literal(lang(_, T)), T) :- !.
shown(literal(type(_, T)), T) :- !.
shown(literal(T), T) :- !.
shown(X, X).

%!  result_message(+Result, -Message) is det.
result_message(result(F, Path, Comp, Value, _), Msg) :-
    local(Path, P),
    (   comp_words(Comp, Value, P, W) -> true ; format(string(W), "breaks ~w on ~w", [Comp, P]) ),
    format(string(Msg), "~w ~w", [F, W]).

comp_words('MinCountConstraintComponent', _, P, W) :- format(string(W), "has no ~w (LOMO asks for one)", [P]).
comp_words('MaxCountConstraintComponent', _, P, W) :- format(string(W), "has more values of ~w than LOMO allows", [P]).
comp_words('NodeKindConstraintComponent', V, P, W) :- format(string(W), "has ~w ~q, which is not a web address", [P, V]).
comp_words('DatatypeConstraintComponent', V, P, W) :- format(string(W), "has ~w ~q without the kind of value LOMO asks for (a text with its language, for a label)", [P, V]).
comp_words('UniqueLangConstraintComponent', _, P, W) :- format(string(W), "has two values of ~w in one language", [P]).
comp_words('InConstraintComponent', V, P, W) :- format(string(W), "has ~w ~w, which is not one of the words LOMO allows", [P, V]).
comp_words('NodeConstraintComponent', V, P, W) :- format(string(W), "has ~w ~w, which is not a term of LOMO's word list for it", [P, V]).

local(I, L) :- ( sub_atom(I, B, 1, A, '#'), \+ ( sub_atom(I, B2, 1, _, '#'), B2 > B ) -> sub_atom(I, _, A, 0, L) ; L = I ), B = B.

%!  unsupported(-Shape, -Constraint) is nondet.
%   A constraint of the shapes file that this check does not interpret.
unsupported(Shape, C) :-
    shapes(S), node_shape(S, Shape),
    ( t(S, Shape, C0, _) ; sh(property, PP), t(S, Shape, PP, PS), t(S, PS, C0, _) ),
    sh(L, C0), \+ memberchk(L, [targetClass, targetSubjectsOf, property, path, minCount, maxCount, nodeKind,
                                datatype, uniqueLang, in, node, name, description, message, severity]),
    C = L.

/** <module> The LOMO reader: a Turtle file -> statements with names and kinds of value

    read_lomo(+File, -Model)
        Model = lomo(Statements, Nodes, Prefixes)
        Statements = [st(Subject, Property, Value), ...] in the order of the file
            Subject  = a node id (an IRI, or a blank node's id)
            Property = the property's IRI
            Value    = node(Id) | word(Word, IRI) | address(Text)
                     | lit(Kind, LEValue, Form)
                       Kind: text, date, number, duration, boolean, value
                       Form: lang(L) | plain | type(DatatypeIRI)
        Nodes = [node(Id, Name, IRI), ...]: every thing the register names.
            IRI is '-' for a blank node.
        Prefixes = [Prefix-IRI, ...] of the file, then of lomo_words:ns/2

    A thing is named from its web address: the shortest ending of the
    address (its last part, then its last two parts, ...) that no other thing
    of the file has, in words (`Norm_PublicationObligation` -> `norm
    publication obligation`; `.../analysis/description/1` -> `description
    1`). A blank node is named after the thing it belongs to and the
    property that links them (`step publish full report time 1`). A name
    never starts with a word that Logical English reserves.

    SWI-Prolog's own Turtle reader (library(semweb/turtle)) does the reading.

    Copyright Miguel Calejo; Apache License 2.0, as the rest of this
    repository (../../NOTICE). Published "as is".
*/

:- module(lomo_reader, [read_lomo/2, read_lomo/3, words_of/2, compact_iri/3, iri_kind/3]).

:- use_module(library(semweb/turtle)).
:- use_module(library(semweb/rdf_db), [rdf_is_bnode/1]).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(lomo_words).

read_lomo(File, Model) :- read_lomo(File, Model, []).

read_lomo(File, lomo(Statements, Nodes, Prefixes), _Options) :-
    rdf_read_turtle(File, Triples, [prefixes(FilePrefixes), anon_prefix('_:b')]),
    findall(P-NS, ( member(P-NS, FilePrefixes), P \== '' ), Ps0),
    findall(P-NS, ns(P, NS), Ps1),
    append(Ps0, Ps1, Ps2),
    dedup_prefixes(Ps2, Prefixes),
    subjects(Triples, Subjects),
    thing_objects(Triples, Subjects, ObjectNodes),
    append(Subjects, ObjectNodes, NodeIds0),
    list_to_set(NodeIds0, NodeIds),
    name_nodes(NodeIds, Triples, Nodes),
    maplist(statement(Subjects, NodeIds), Triples, Statements).

dedup_prefixes(Ps0, Ps) :-
    foldl([P-N, A0, A]>>( memberchk(P-_, A0) -> A = A0 ; memberchk(_-N, A0) -> A = A0 ; append(A0, [P-N], A) ),
          Ps0, [], Ps).

subjects(Triples, Subjects) :-
    findall(S, member(rdf(S, _, _), Triples), Ss),
    list_to_set(Ss, Subjects).

%   An object that the register names although it is not a subject of the
%   file: a blank node, or the value of a property whose values are things.
thing_objects(Triples, Subjects, Os) :-
    findall(O, ( member(rdf(_, P, O), Triples), atom(O),
                 \+ memberchk(O, Subjects),
                 \+ vocabulary_term(O, _),
                 ( rdf_is_bnode(O) -> true ; property_word(P, _, _, thing) )
               ), Os0),
    list_to_set(Os0, Os).

statement(Subjects, NodeIds, rdf(S, P, O0), st(S, P, V)) :-
    value(P, O0, Subjects, NodeIds, V).

value(P, O, _, _, V) :-
    rdf_type(P), atom(O), !,
    (   class_word(O, _, _) -> V = node(O)          % a class: the twin writes its sentence
    ;   V = address(O)
    ).
value(P, literal(L), _, _, lit(Kind, Value, Form)) :- !,
    literal_value(P, L, Kind, Value, Form).
value(_, O, _, NodeIds, V) :-
    (   vocabulary_term(O, W) -> V = word(W, O)
    ;   memberchk(O, NodeIds) -> V = node(O)
    ;   atom_string(O, S), V = address(S)
    ).

rdf_type('http://www.w3.org/1999/02/22-rdf-syntax-ns#type').

literal_value(_, lang(L, T), text, S, lang(L)) :- !, atom_string(T, S).
literal_value(P, type(Type, Lex), Kind, V, type(Type)) :- !,
    typed_value(Type, Lex, P, Kind, V).
literal_value(P, Lex, Kind, V, plain) :-
    ( property_word(P, _, _, K), memberchk(K, [date, number, duration, boolean]) -> Kind0 = K ; Kind0 = text ),
    plain_value(Kind0, Lex, Kind, V).

typed_value(Type, Lex, _, Kind, V) :-
    xsd(Local, Type), xsd_kind(Local, Kind0), !,
    atom_string(Lex, S),
    (   kind_value(Kind0, S, V0) -> Kind = Kind0, V = V0
    ;   Kind = value, V = S                       % an ill-formed lexical form: kept as text
    ).
typed_value(_, Lex, _, value, S) :- atom_string(Lex, S).

plain_value(K, Lex, K, V) :- atom_string(Lex, S), kind_value(K, S, V), !.
plain_value(_, Lex, text, S) :- atom_string(Lex, S).

xsd(L, T) :- atom(T), atom_concat('http://www.w3.org/2001/XMLSchema#', L, T).
xsd_kind(date, date).
xsd_kind(decimal, number).
xsd_kind(integer, number).
xsd_kind(int, number).
xsd_kind(nonNegativeInteger, number).
xsd_kind(positiveInteger, number).
xsd_kind(double, number).
xsd_kind(float, number).
xsd_kind(duration, duration).
xsd_kind(boolean, boolean).
xsd_kind(string, text).

kind_value(text, S, S).
kind_value(duration, S, S).
kind_value(date, S, date(Y, M, D)) :-
    split_string(S, "-", "", [YS, MS, DS]),
    number_string(Y, YS), number_string(M, MS), number_string(D, DS),
    integer(Y), integer(M), integer(D).
kind_value(number, S, N) :- catch(number_string(N, S), _, fail), number(N).
kind_value(boolean, S, B) :- ( S == "true" -> B = true ; S == "false" -> B = false ; S == "1" -> B = true ; S == "0" -> B = false ).

%!  iri_kind(+Value, -Kind, -Text): how a value is shown in the ledger.
iri_kind(node(I), node, I).
iri_kind(word(W, _), word, W).
iri_kind(address(A), address, A).
iri_kind(lit(K, V, _), K, V).

%   ---- names -----------------------------------------------------------

name_nodes(Ids, Triples, Nodes) :-
    partition([I]>>rdf_is_bnode(I), Ids, BNodes, IRIs),
    maplist(iri_segments, IRIs, Segs),
    pairs_keys_values(Pairs0, IRIs, Segs),
    unique_names(Pairs0, IRINames),                 % IRI-Name
    bnode_names(BNodes, Triples, IRINames, BNames),
    append(IRINames, BNames, All0),
    disambiguate(All0, All),
    findall(node(I, N, IRI), ( member(I-N, All), ( rdf_is_bnode(I) -> IRI = '-' ; IRI = I ) ), Nodes0),
    order_like(Ids, Nodes0, Nodes).

order_like(Ids, Nodes0, Nodes) :-
    findall(node(I, N, R), ( member(I, Ids), memberchk(node(I, N, R), Nodes0) ), Nodes).

%   The parts of an address, from the last: the fragment, then the path
%   from its end. The host is left out.
iri_segments(IRI, Segs) :-
    (   sub_atom(IRI, B, _, A, '#'), \+ ( sub_atom(IRI, B2, _, _, '#'), B2 > B )
    ->  sub_atom(IRI, 0, B, _, Base), sub_atom(IRI, _, A, 0, Frag),
        path_segments(Base, PSs), Segs0 = [Frag|PSs]
    ;   path_segments(IRI, Segs0)
    ),
    exclude(==(''), Segs0, Segs).

path_segments(IRI, Rev) :-
    (   sub_atom(IRI, B, 3, _, '://') -> B3 is B + 3, sub_atom(IRI, B3, _, 0, Rest) ; Rest = IRI ),
    atomic_list_concat([_Host|Path], '/', Rest),
    reverse(Path, Rev).

%   Each IRI starts with its last part; a group sharing a name takes one
%   part more, until no group does or no part is left.
unique_names(Pairs, Names) :-
    maplist([I-Segs, I-Segs-K]>>( eli_iri(I, Segs, K) -> true ; K = 1 ), Pairs, States0),
    grow(States0, States),
    maplist([I-Segs-K, I-N]>>candidate(Segs, K, N), States, Names).

grow(States0, States) :-
    maplist([I-S-K, (N-(I-S-K))]>>candidate(S, K, N), States0, Keyed),
    msort(Keyed, Sorted),
    group_pairs_by_key(Sorted, Groups),
    (   member(_-[_, _|_], Groups),
        findall(I-S-K1, ( member(_-G, Groups), member(I-S-K, G),
                          ( G = [_, _|_], length(S, L), K < L -> K1 is K + 1 ; K1 = K ) ), States1),
        States1 \== States0
    ->  grow(States1, States)
    ;   States = States0
    ).

%   An act or a provision named by its ELI is named by the whole of its
%   ELI: `http://data.europa.eu/eli/dir/2013/34/oj` -> `eli dir 2013 34 oj`.
eli_iri(IRI, Segs, K) :-
    sub_atom(IRI, _, _, _, '/eli/'),
    nth1(K, Segs, eli), !.

candidate(Segs, K0, Name) :-
    length(Segs, L),
    (   Segs = [S1|_], words_of(S1, W1), W1 \== [], forall(member(W, W1), atom_number(W, _)), K0 < 2, L >= 2
    ->  K = 2                                       % `.../description/1`: `description 1`
    ;   K is min(K0, L)
    ),
    length(Take, K), append(Take, _, Segs),
    reverse(Take, InOrder),
    maplist(words_of, InOrder, Ws), append(Ws, Words0),
    exclude([W]>>inner_stop_word(W), Words0, Words1),
    cap(Words1, Words2),
    safe_start(Words2, Words),
    atomic_list_concat(Words, ' ', Name).

cap(Ws, Ws) :- length(Ws, L), L =< 9, !.
cap(Ws, Cap) :- length(Cap, 9), append(Cap, _, Ws).

safe_start([], [thing]) :- !.
safe_start([rule|Ws], [norm|Ws]) :- Ws \== [], !.      % `Rule_GDPR_Art6` -> `norm gdpr art 6`
safe_start([W|Ws], Out) :-
    (   ( reserved_start(W) ; atom_number(W, _) )
    ->  Out = [item, W|Ws]
    ;   Out = [W|Ws]
    ).

reserved_start(W) :- memberchk(W, [a, an, the, which, rule, it, not, scenario, query, if, and, or, every, each,
                                    there, no, all, any, some, either, otherwise, only, when, then, that, true, false,
                                    is, are, has, have, of, for, in, on, at, by, to, with, from]).

inner_stop_word(W) :- memberchk(W, [and, or, if, then, not, it, is, are, has, have, that, which, unless, otherwise, except, either, neither, nor, only, every, each]).  % words that open or join conditions

%   Words of a part of an address: split at every character that is not a
%   letter or a digit, at a change from lower to upper case, and between
%   letters and digits; lower case, accents dropped.
words_of(Seg, Words) :-
    atom_codes(Seg, Cs0),
    maplist(fold_code, Cs0, Cs1),
    split_codes(Cs1, Groups),
    exclude(==([]), Groups, Gs),
    maplist([G, W]>>( atom_codes(A, G), downcase_atom(A, W) ), Gs, Words).

fold_code(C, F) :-
    (   C < 128 -> F = C
    ;   char_code(Ch, C), fold_char(Ch, FCh) -> char_code(FCh, F)
    ;   F = 0'
    ).
fold_char(Ch, F) :-
    atom_codes(Ch, _),
    member(F-Set, [a-"àáâãäåā", e-"èéêëē", i-"ìíîïī", o-"òóôõöøō", u-"ùúûüū", c-"ç", n-"ñ", s-"š", z-"ž",
                   'A'-"ÀÁÂÃÄÅ", 'E'-"ÈÉÊË", 'I'-"ÌÍÎÏ", 'O'-"ÒÓÔÕÖØ", 'U'-"ÙÚÛÜ", 'C'-"Ç", 'N'-"Ñ"]),
    string_chars(Set, Chars), memberchk(Ch, Chars), !.

split_codes(Cs, Groups) :- split_codes(Cs, [], Groups).
split_codes([], Cur, [G]) :- reverse(Cur, G).
split_codes([C|Cs], Cur, Groups) :-
    (   \+ alnum(C)
    ->  reverse(Cur, G), Groups = [G|Rest], split_codes(Cs, [], Rest)
    ;   Cur = [Prev|_], boundary(Prev, C, Cs)
    ->  reverse(Cur, G), Groups = [G|Rest], split_codes(Cs, [C], Rest)
    ;   split_codes(Cs, [C|Cur], Groups)
    ).

alnum(C) :- code_type(C, alnum), C < 128.
boundary(P, C, _) :- code_type(P, lower), code_type(C, upper).
boundary(P, C, _) :- code_type(P, alpha), code_type(C, digit).
boundary(P, C, _) :- code_type(P, digit), code_type(C, alpha).
boundary(P, C, [N|_]) :- code_type(P, upper), code_type(C, upper), code_type(N, lower).   % `PDFFile` -> `pdf file`

%   A blank node: the name of the thing it belongs to, the word of the
%   property, and a number when the thing has several of them.
bnode_names(BNodes, Triples, IRINames, Names) :-
    bnode_parents(BNodes, Triples, Parents),
    foldl(name_bnode(Parents, BNodes), BNodes, IRINames, All),
    findall(B-N, ( member(B, BNodes), memberchk(B-N, All) ), Names).

bnode_parents(BNodes, Triples, Parents) :-
    findall(B-(S-P), ( member(B, BNodes), once(member(rdf(S, P, B), Triples)) ), Parents).

name_bnode(Parents, BNodes, B, Known0, Known) :-
    bnode_name(B, Parents, BNodes, Known0, Known1, Name),
    (   memberchk(B-_, Known1) -> Known = Known1 ; Known = [B-Name|Known1] ).

bnode_name(B, _, _, Known, Known, N) :- memberchk(B-N, Known), !.
bnode_name(B, Parents, BNodes, Known0, Known, Name) :-
    (   memberchk(B-(S-P), Parents)
    ->  (   memberchk(S-SN, Known0) -> Known1 = Known0
        ;   rdf_is_bnode(S), S \== B
        ->  bnode_name(S, Parents, BNodes, Known0, Known10, SN), Known1 = [S-SN|Known10]
        ;   SN = thing, Known1 = Known0
        ),
        property_short(P, PW),
        findall(B2, ( member(B2-(S-P), Parents) ), Siblings),
        (   Siblings = [_]
        ->  atomic_list_concat([SN, PW], ' ', Name)
        ;   nth1(Ix, Siblings, B), !,
            atomic_list_concat([SN, PW, Ix], ' ', Name)
        ),
        Known = Known1
    ;   nth1(Ix, BNodes, B), !,
        atomic_list_concat([anonymous, Ix], ' ', Name), Known = Known0
    ).

property_short(P, W) :- short(P, W), !.
property_short(P, W) :-
    iri_segments(P, [L|_]), words_of(L, Ws0),
    exclude([X]>>memberchk(X, [has, is, of, the]), Ws0, Ws),
    ( Ws == [] -> W = part ; atomic_list_concat(Ws, ' ', W) ).

short(P, W) :-
    lomo_ns(N), atom_concat(N, L, P),
    member(L-W, [atTime-time, hasResult-result, hasAgentRole-role, hasCondition-condition,
                 manifests-result, isManifestedIn-dataset, produces-action, after-'earlier time',
                 before-'later time', immediatelyAfter-'earlier time', immediatelyBefore-'later time',
                 starts-'whole time', finishes-'whole time', startedBy-'start time', finishedBy-'end time',
                 overlaps-'other time', in-'whole time', isComposedOf-part, defines-'defined thing',
                 references-resource, hasNext-'next action', hasPrevious-'previous action']), !.

%   Two things with one name (an address cut to nine words, a blank node
%   named like an address): the second gets ` 2`, the third ` 3`, ...
%   A name is never one of the words of LOMO's word lists (`data`).
disambiguate(All0, All) :-
    findall(W-1, vocabulary_term(_, W), Taken),
    foldl([I-N, S0-A0, S-A]>>(
              (   memberchk(N-C, S0)
              ->  C1 is C + 1, selectchk(N-C, S0, N-C1, S), atomic_list_concat([N, C1], ' ', N1),
                  A = [I-N1|A0]
              ;   S = [N-1|S0], A = [I-N|A0]
              )), All0, Taken-[], _-Rev),
    reverse(Rev, All).

%!  compact_iri(+IRI, +Prefixes, -Text) is det.
compact_iri(IRI, Prefixes, Text) :-
    (   member(P-NS, Prefixes), atom_concat(NS, Local, IRI), Local \== '',
        \+ sub_atom(Local, _, _, _, '/'), \+ sub_atom(Local, _, _, _, '#')
    ->  format(string(Text), "~w:~w", [P, Local])
    ;   atom_string(IRI, Text)
    ).

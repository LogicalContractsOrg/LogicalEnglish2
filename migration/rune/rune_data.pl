:- module(rune_data, [
    instance_facts/4,       % +JsonFile, +RootType, +Root, -Facts
    value_type/2,           % +TypeRef, -Kind: object(Q) | enum(Q) | basic(B)
    type_feature/3          % +Type, ?Name, -feature(TypeRef, Card, Meta)
]).
/** <module> CDM objects as facts: what a scenario of a twin states

A DRR input (a TransactionReportInstruction, several hundred lines of JSON)
becomes one fact per attribute value, walking the JSON against the model
(rune_reader.pl):

    f(Object, Attribute, Value)        Value: o(Id) | a string, number, true, false
    m(Object, Attribute, Meta, Value)  the metadata of a value: scheme

in the order of the JSON, so that a list keeps its order. The root is
`Root`; every other object gets an id from its type and a counter
(`party_identifier_3`).

**References.** An object with a key (`"meta": {"globalKey": "bea4b578"}`)
is one object wherever it is copied: its id is made once, and every
`globalReference` (or `externalReference`) to the key is that id — what
DRR's reference resolver does before a report is computed
(java/src/main/java/DrrOracle.java). Two copies of a party are then the
same party, as Rune's equality, which compares objects by their content,
says they are.

**Metadata.** A value with a scheme (`{"value": "X", "meta": {"scheme": S}}`)
is stated as its value, and its scheme as m/4.
*/

:- use_module(library(json)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(parser/rune_reader).

:- dynamic unknown_attribute/2.

%!  instance_facts(+File, +RootType, +Root, -Facts) is det.
instance_facts(File, RootType, Root, Facts) :-
    setup_call_cleanup(open(File, read, S, [encoding(utf8)]),
                       json_read_dict(S, D, [value_string_as(string), default_tag(json)]),
                       close(S)),
    nb_setval(rune_data_counter, 0),
    empty_assoc(K0),
    keyed_objects(D, RootType, K0, Keys),
    nb_setval(rune_data_keys, Keys),
    empty_assoc(Done0),
    phrase(object(D, RootType, [], Root, [], Done0, _), Facts0),
    Facts = Facts0.

% ---------------------------------------------------------------- keys

%   object_keys(+Json, +Type, -Keys): the keys an object is known by: its
%   global key (DRR's "0" is a placeholder, not a key), its external key,
%   and the locations an address may point at (`[metadata location]`, on
%   the wrapper of the value: {"meta": {"location": [...]}, "value": {...}}).
%   A key is a key of its type: DRR gives a person and its identifier the
%   same global key.
%   The keys of a wrapper are those of its meta and those of the value it
%   holds (a reference may carry its object: `"partyReference": {"value":
%   {"meta": {"globalKey": ...}, ...}}`).
object_keys(D, T, Keys) :-
    own_keys(D, T, K1),
    (   wrapper(D, Inner) -> own_keys(Inner, T, K2) ; K2 = [] ),
    append(K1, K2, Keys).

own_keys(D, T, Keys) :-
    (   get_dict(meta, D, M), is_dict(M)
    ->  findall(K, meta_key(M, T, K), Keys)
    ;   Keys = []
    ).

meta_key(M, T, globalKey-G-T) :- get_dict(globalKey, M, G), G \== "0".
meta_key(M, T, externalKey-E-T) :- get_dict(externalKey, M, E).
meta_key(M, T, location-V-T) :- get_dict(location, M, Ls), is_list(Ls), member(L, Ls), is_dict(L), get_dict(value, L, V).

%   The object a JSON value holds: the value inside a wrapper, or itself.
object_json(V, Inner) :- ( wrapper(V, Inner0) -> Inner = Inner0 ; Inner = V ).

%   A wrapper of a value (Rune's FieldWithMeta, ReferenceWithMeta): a
%   "value" with nothing beside it but metadata and references. An object
%   with an attribute of its own called value (a Taxonomy: source and
%   value) is not one.
wrapper(V, Inner) :-
    get_dict(value, V, Inner), is_dict(Inner),
    dict_pairs(V, _, Ps),
    forall(member(K-_, Ps), memberchk(K, [value, meta, globalReference, externalReference, address])).

%   keyed_objects(+Json, +Type, +Keys0, -Keys): every object with a key,
%   the first occurrence: Key - Json.
keyed_objects(D, T, K0, K) :-
    is_dict(D), !,
    object_keys(D, T, Ks), object_json(D, Obj),
    foldl(add_key(Obj), Ks, K0, K1),
    dict_pairs(Obj, _, Ps),
    foldl(keyed_pair(T), Ps, K1, K).
keyed_objects(L, T, K0, K) :- is_list(L), !, foldl(keyed_item(T), L, K0, K).
keyed_objects(_, _, K, K).

keyed_item(T, D, K0, K) :- keyed_objects(D, T, K0, K).

keyed_pair(T, A-V, K0, K) :-
    (   A \== meta, type_feature(T, A, feature(TR, _, _)), value_type(TR, object(Q))
    ->  keyed_objects(V, Q, K0, K)
    ;   K = K0
    ).

add_key(D, Key, K0, K) :-
    (   get_assoc(Key, K0, _) -> K = K0 ; put_assoc(Key, K0, D, K) ).

% ---------------------------------------------------------------- walk

%   object(+Json, +Type, +Keys, ?Id, +Link, +Done0, -Done)//: the facts of
%   one object, after the fact that links it to its owner (Link, with Id in
%   it), so that a scenario reads from the root down. Done: the objects
%   already stated, by their keys (each is stated once, wherever DRR copies
%   it).
object(D, T, Keys, Id, Link, Done0, Done) -->
    (   { member(Key, Keys), get_assoc(Key, Done0, Id0) }
    ->  { Id = Id0, Done = Done0 }, Link
    ;   { ( var(Id) -> new_id(T, Id) ; true ),
          foldl(done_key(Id), Keys, Done0, Done1),
          dict_pairs(D, _, Ps) },
        Link,
        %  the locations an address may point at are data too: DRR's Java
        %  reads them (GetQuantityKeys, GetQuantityReference)
        { findall(f(Id, location, L), member(location-L-_, Keys), LFs) }, LFs,
        attributes(Ps, T, Id, Done1, Done)
    ).

done_key(Id, Key, D0, D) :- put_assoc(Key, D0, Id, D).

attributes([], _, _, Done, Done) --> [].
attributes([A-V|Ps], T, Id, Done0, Done) -->
    (   { A \== meta, type_feature(T, A, feature(TR, _, Meta)) }
    ->  values(V, A, TR, Meta, Id, Done0, Done1)
    ;   { Done1 = Done0,
          ( A == meta -> true ; flag(rune_data_unknown, U, U+1), assertz(unknown_attribute(T, A)) ) }
    ),
    attributes(Ps, T, Id, Done1, Done).

values(L, A, TR, Meta, Id, Done0, Done) --> { is_list(L) }, !, items(L, A, TR, Meta, Id, Done0, Done).
values(V, A, TR, Meta, Id, Done0, Done) --> item(V, A, TR, Meta, Id, Done0, Done).

items([], _, _, _, _, Done, Done) --> [].
items([V|Vs], A, TR, Meta, Id, Done0, Done) -->
    item(V, A, TR, Meta, Id, Done0, Done1),
    items(Vs, A, TR, Meta, Id, Done1, Done).

item(null, _, _, _, _, Done, Done) --> !.
item(V, A, TR, _Meta, Id, Done0, Done) -->
    { value_type(TR, object(Q)) }, !,
    (   { is_dict(V), reference_target(V, Target) }
    ->  % a reference: the keyed object it points to (stated where it is)
        reference(Target, Q, A, Id, Done0, Done)
    ;   { is_dict(V) }
    ->  { object_keys(V, Q, Keys), object_json(V, Obj) },
        object(Obj, Q, Keys, Sub, [f(Id, A, o(Sub))], Done0, Done)
    ;   { Done = Done0 }
    ).
item(V, A, TR, _, Id, Done, Done) -->
    { value_type(TR, Kind) },
    (   { is_dict(V) }
    ->  (   { get_dict(value, V, X) } -> { primitive(Kind, X, P) }, [f(Id, A, P)] ; [] ),
        (   { get_dict(meta, V, M), is_dict(M), get_dict(scheme, M, S) }
        ->  [m(Id, A, scheme, S)] ; []
        )
    ;   { primitive(Kind, V, P) }, [f(Id, A, P)]
    ).

%   A reference to a key, from an attribute of type Q: the object with that
%   key whose type is Q or a type that extends Q.
reference(Which-Key, Q, A, Id, Done0, Done) -->
    (   { keyed_type(Which-Key, Q, T), get_assoc(Which-Key-T, Done0, Sub) }
    ->  [f(Id, A, o(Sub))], { Done = Done0 }
    ;   { keyed_type(Which-Key, Q, T), nb_getval(rune_data_keys, Keys),
          get_assoc(Which-Key-T, Keys, KD) }
    ->  { object_keys_of(KD, Which-Key-T, Ks) },
        object(KD, T, Ks, Sub, [f(Id, A, o(Sub))], Done0, Done)
    ;   { Done = Done0 }      % a reference to nothing in the document
    ).

object_keys_of(_, K, [K]).

keyed_type(Which-Key, Q, T) :-
    nb_getval(rune_data_keys, Keys),
    (   get_assoc(Which-Key-Q, Keys, _) -> T = Q
    ;   assoc_to_keys(Keys, Ks), member(Which-Key-T, Ks), type_ancestor(T, Q) -> true
    ;   assoc_to_keys(Keys, Ks), member(Which-Key-T, Ks), type_ancestor(Q, T) -> true
    ).

reference_target(V, Target) :-
    \+ wrapper(V, _),
    (   get_dict(globalReference, V, G), G \== "0" -> Target = globalKey-G
    ;   get_dict(externalReference, V, E) -> Target = externalKey-E
    ;   get_dict(address, V, Ad), is_dict(Ad), get_dict(value, Ad, L) -> Target = location-L
    ).

primitive(_, true, "true") :- !.          % a boolean is a text in the twins
primitive(_, false, "false") :- !.
primitive(basic(boolean), V, V) :- !.
primitive(basic(B), V, N) :- memberchk(B, [int, number]), string(V), number_string(N, V), !.
primitive(_, V, V).

new_id(T, Id) :-
    nb_getval(rune_data_counter, N0), N is N0 + 1, nb_setval(rune_data_counter, N),
    ( atomic_list_concat(Parts, '.', T), last(Parts, Short) -> true ; Short = T ),
    snake(Short, S),
    format(atom(Id), '~w_~w', [S, N]).

snake(A, S) :-
    atom_codes(A, Cs), snake_codes(Cs, true, Ds), atom_codes(S, Ds).
snake_codes([], _, []).
snake_codes([C|Cs], First, Ds) :-
    (   code_type(C, upper(L))
    ->  ( First == true -> Ds = [L|R] ; Ds = [0'_, L|R] )
    ;   Ds = [C|R]
    ),
    snake_codes(Cs, false, R).

% ---------------------------------------------------------------- the model

%!  type_feature(+Type, ?Name, -feature(TypeRef, Card, Meta)) is nondet.
%
%   An attribute of a type (its own or inherited), or an option of a
%   choice (named after the option's type).
type_feature(T, A, feature(TR, Card, Meta)) :-
    rune_model:rune_type(T, _, _), !,
    type_attribute(T, A, attr(TR, Card, Meta, _)).
type_feature(T, A, feature(O, card(0, 1), _{})) :-
    rune_model:rune_choice(T, Os), !,
    member(O, Os), atomic_list_concat(Parts, '.', O), last(Parts, A).

%!  value_type(+TypeRef, -Kind) is det.
value_type(T, Kind) :-
    (   rune_model:rune_type(T, _, _) -> Kind = object(T)
    ;   rune_model:rune_choice(T, _) -> Kind = object(T)
    ;   rune_model:rune_enum(T, _, _) -> Kind = enum(T)
    ;   rune_model:rune_type_alias(T, Def) -> alias_base(Def, Kind)
    ;   Kind = basic(T)
    ).

alias_base(Def, Kind) :-
    (   sub_atom(Def, B, _, _, '(') -> sub_atom(Def, 0, B, _, N0) ; N0 = Def ),
    normalize_space(atom(N), N0),
    (   rune_reader:basic_type(N) -> Kind = basic(N)
    ;   rune_model:rune_type_alias(Q, _), atomic_list_concat(Ps, '.', Q), last(Ps, N)
    ->  rune_model:rune_type_alias(Q, Def2), alias_base(Def2, Kind)
    ;   Kind = basic(string)
    ).

:- module(rune_reader, [
    load_rune_model/1,      % +JsonDir: the rosetta2json output of a corpus
    rune_expression/3,      % ?Where, ?Text, ?AST (AST = error(...) when unparsed)
    resolve_name/4,         % +Scope, +Name, ?Kind, -QName
    type_attribute/3,       % +Type, ?Attr, -attr(Type, Card, Meta, Anns): own and inherited
    type_ancestor/2,        % +Type, ?Ancestor (the type itself included)
    enum_value_json/3       % +Enum, ?Value, -Json: the text the JSON of a value holds
]).
/** <module> A Rune model in Prolog: the structure read by rosetta2json, the
expressions parsed here (rune_expr.pl)

    python3 parser/rosetta2json.py <rosetta dir> <json dir>

writes one JSON file per namespace (cdmLOG's converter; it reads `report`,
`reporting rule` and `eligibility rule` since its version 0.2.0). This
module loads those files as facts of `rune_model`:

    rune_ns(NS)
    rune_file(NS, File, Imports, Aliases)            Aliases: [Alias-Namespace]
    rune_member(NS, Name, Kind, File)                Kind: type enum choice func
                                                     rule eligibility typeAlias
    rune_type(Q, Super, Doc)                         Super: a QName or none
    rune_attr(Q, Name, TypeQ, Card, Meta, Anns)      Card: card(Min, Max|inf)
    rune_enum(Q, Super, Values)                      Values: [ev(Name, Display, Doc)]
    rune_choice(Q, Options)                          Options: [TypeQ]
    rune_type_alias(Q, Definition)
    rune_func(Q, Inputs, Output, Steps, Conditions, Anns, Doc)
        Inputs: [in(Name, TypeQ, Card)], Output: out(Name, TypeQ, Card)
        Steps: [alias(Name, Where) | set(Path, Where) | add(Path, Where)]
    rune_rule(Kind, Q, InputQ, Where, Anns, Doc)     Kind: reporting | eligibility
    rune_report(Name, Body, Corpus, InputQ, Eligibility, TypeQ)
    rune_condition(TypeQ, Name, Where)

Where identifies an expression: `rune_expression(Where, Text, AST)` holds its
text and its tree. Names in a type are resolved here, with the namespace's
imports (Rune resolves names per file: `fileScopes` says which file declared
what, with its own imports and aliases). Names in an expression are resolved
later, by the typing (rune_types.pl), with `resolve_name/4`.
*/

:- use_module(library(json)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(rune_expr).

:- dynamic rune_model:rune_ns/1, rune_model:rune_file/4, rune_model:rune_member/4,
    rune_model:rune_type/3, rune_model:rune_attr/6, rune_model:rune_enum/3,
    rune_model:rune_choice/2, rune_model:rune_type_alias/2, rune_model:rune_func/7,
    rune_model:rune_rule/6, rune_model:rune_report/6, rune_model:rune_condition/3,
    rune_model:rune_expr_text/2, rune_model:rune_expr_ast/2, rune_model:pending_type/3.

model_predicates([rune_ns/1, rune_file/4, rune_member/4, rune_type/3, rune_attr/6,
    rune_enum/3, rune_choice/2, rune_type_alias/2, rune_func/7, rune_rule/6,
    rune_report/6, rune_condition/3, rune_expr_text/2, rune_expr_ast/2, pending_type/3]).

%!  load_rune_model(+JsonDir) is det.
load_rune_model(Dir) :-
    model_predicates(Ps),
    forall(member(P/N, Ps), (functor(H, P, N), retractall(rune_model:H))),
    directory_files(Dir, Fs0), msort(Fs0, Fs),
    forall(( member(F, Fs), file_name_extension(_, json, F), F \== 'namespaces.json' ),
           ( directory_file_path(Dir, F, Path),
             setup_call_cleanup(open(Path, read, S, [encoding(utf8)]),
                                json_read(S, T, [value_string_as(atom)]),
                                close(S)),
             json_ordered_dict(T, D),
             load_members(D) )),
    forall(rune_model:rune_ns(NS), load_namespace_body(NS)),
    resolve_pending_types.

:- dynamic loaded_dict/2.

% Pass 1: the namespaces and their members, so that pass 2 can resolve names.
load_members(D) :-
    NS = D.namespace,
    assertz(rune_model:rune_ns(NS)),
    retractall(loaded_dict(NS, _)), assertz(loaded_dict(NS, D)),
    Imports = D.get(imports, []),
    pairs_of(D.get(importAliases, _{}), Aliases),
    ( get_dict(fileScopes, D, Scopes) ->
        pairs_of(Scopes, SPs),
        forall(member(File-Sc, SPs),
               ( pairs_of(Sc.importAliases, FA),
                 assertz(rune_model:rune_file(NS, File, Sc.imports, FA)),
                 forall(member(M, Sc.members), member_kind_file(NS, D, M, File)) ))
    ;   File = '*',
        assertz(rune_model:rune_file(NS, File, Imports, Aliases)),
        forall(( member(Sec, [types, choices, enums, typeAliases, functions,
                              reportingRules, eligibilityRules]),
                 get_dict(Sec, D, Sd), get_dict(M, Sd, _), M \== '$order' ),
               member_kind_file(NS, D, M, File))
    ).

member_kind_file(NS, D, M, File) :-
    forall(( member(Sec-Kind, [types-type, choices-choice, enums-enum,
                               typeAliases-typeAlias, functions-func,
                               reportingRules-rule, eligibilityRules-eligibility]),
             get_dict(Sec, D, Sd), get_dict(M, Sd, _) ),
           assertz(rune_model:rune_member(NS, M, Kind, File))).

% Pass 2: the members themselves.
load_namespace_body(NS) :-
    loaded_dict(NS, D),
    forall(member_of(D, types, N, T), load_type(NS, N, T)),
    forall(member_of(D, enums, N, E), load_enum(NS, N, E)),
    forall(member_of(D, choices, N, C), load_choice(NS, N, C)),
    forall(member_of(D, typeAliases, N, A),
           ( q(NS, N, Q), assertz(rune_model:rune_type_alias(Q, A.definition)) )),
    forall(member_of(D, functions, N, F), load_func(NS, N, F)),
    forall(member_of(D, reportingRules, N, R), load_rule(reporting, NS, N, R)),
    forall(member_of(D, eligibilityRules, N, R), load_rule(eligibility, NS, N, R)),
    forall(member_of(D, reports, N, R), load_report(NS, N, R)).

member_of(D, Sec, N, V) :- pairs_of(D.get(Sec, _{}), Ps), member(N-V, Ps).

q(NS, N, Q) :- atomic_list_concat([NS, N], '.', Q).

scope_of(NS, Name, scope(NS, File)) :-
    ( rune_model:rune_member(NS, Name, _, File) -> true ; File = '*' ).

load_type(NS, N, T) :-
    q(NS, N, Q), scope_of(NS, N, Sc),
    ( get_dict(extends, T, Ext) -> pending_or_resolved(Sc, Ext, Super) ; Super = none ),
    assertz(rune_model:rune_type(Q, Super, T.get(description, ''))),
    pairs_of(T.get(attributes, _{}), APs),
    forall(member(A-AD, APs), load_attr(Sc, Q, A, AD)),
    pairs_of(T.get(conditions, _{}), CPs),
    forall(member(C-Text, CPs),
           ( W = cond(Q, C), store_expression(W, Text),
             assertz(rune_model:rune_condition(Q, C, W)) )).

load_attr(Sc, Q, A, AD) :-
    card(AD.cardinality, Card),
    pending_or_resolved(Sc, AD.type, TQ),
    Meta = AD.get(metadata, _{}),
    Anns = AD.get(annotations, _{}),
    assertz(rune_model:rune_attr(Q, A, TQ, Card, Meta, Anns)).

% A type reference resolved after every namespace is loaded (its members
% are known after pass 1, but a type alias's name may be needed first).
pending_or_resolved(Sc, Name, TQ) :- resolve_type_ref(Sc, Name, TQ), !.
pending_or_resolved(_, Name, Name).

resolve_pending_types.

card(Text, card(Min, Max)) :-
    atomic_list_concat([L, H], '..', Text),
    atom_number(L, Min),
    ( H == '*' -> Max = inf ; atom_number(H, Max) ).

load_enum(NS, N, E) :-
    q(NS, N, Q), scope_of(NS, N, Sc),
    ( get_dict(extends, E, Ext) -> pending_or_resolved(Sc, Ext, Super) ; Super = none ),
    maplist(enum_value, E.get(values, []), Vs),
    assertz(rune_model:rune_enum(Q, Super, Vs)).

enum_value(V, ev(V, none, '')) :- atom(V), !.
enum_value(V, ev(V.value, V.get(displayName, none), V.get(description, ''))).

load_choice(NS, N, C) :-
    q(NS, N, Q), scope_of(NS, N, Sc),
    maplist(choice_option(Sc), C.get(options, []), Os),
    assertz(rune_model:rune_choice(Q, Os)).

load_func(NS, N0, F) :-
    % a dispatch function F(Value) is kept under F(Value)
    q(NS, N0, Q), base_name(N0, N), scope_of(NS, N, Sc),
    pairs_of(F.get(inputs, _{}), IPs),
    maplist(func_input(Sc), IPs, Ins0),
    ( Ins0 == [] -> Ins = [] ; input_order(F, Ins0, Ins) ),
    ( pairs_of(F.get(output, _{}), [O-OD]) ->
        pending_or_resolved(Sc, OD.type, OT), card(OD.cardinality, OC),
        Out = out(O, OT, OC)
    ;   Out = none
    ),
    foldl(load_step(Q), F.get(implementation, []), Steps, 0, _),
    pairs_of(F.get(conditions, _{}), CPs),
    findall(C-W, ( member(C-Text, CPs), W = fcond(Q, C), store_expression(W, Text) ), Conds),
    assertz(rune_model:rune_func(Q, Ins, Out, Steps, Conds, F.get(annotations, _{}),
                                 F.get(description, ''))).

base_name(N0, N) :- sub_atom(N0, B, _, _, '('), !, sub_atom(N0, 0, B, _, N).
base_name(N, N).

% A dict's keys are sorted; the inputs' order is their order in the source,
% kept by json_ordered_dict/2 under '$order'.
input_order(F, Ins0, Ins) :-
    get_dict(inputs, F, FI), get_dict('$order', FI, Order),
    maplist(input_named(Ins0), Order, Ins).

input_named(Ins, N, I) :- member(I, Ins), I = in(N, _, _), !.
choice_option(Sc, O, TQ) :- ( atom(O) -> T = O ; T = O.value ), pending_or_resolved(Sc, T, TQ).
func_input(Sc, I-ID, in(I, TQ, Card)) :-
    pending_or_resolved(Sc, ID.type, TQ), card(ID.cardinality, Card).

%   json_ordered_dict(+JsonTerm, -Dict): json([K=V, ...]) as a dict whose
%   key '$order' lists the keys in the order of the file.
json_ordered_dict(json(Ps), D) :- !,
    maplist(json_pair, Ps, DPs, Order),
    dict_pairs(D, _, ['$order'-Order|DPs]).
json_ordered_dict(L, DL) :- is_list(L), !, maplist(json_ordered_dict, L, DL).
json_ordered_dict(@(V), V) :- !.
json_ordered_dict(V, V).

json_pair(K=V, K-DV, K) :- json_ordered_dict(V, DV).
dict_key_pair(D, K, K-V) :- get_dict(K, D, V).
eligibility_name(Sc, E, EQ) :- ( resolve_name(Sc, E, eligibility, EQ) -> true ; EQ = E ).
trimmed(A0, A) :- normalize_space(atom(A), A0).

pairs_of(D, Ps) :-
    ( is_dict(D), get_dict('$order', D, O) -> maplist(dict_key_pair(D), O, Ps)
    ; Ps = [] ).

load_step(Q, Step, S, I0, I) :-
    I is I0 + 1,
    pairs_of(Step, Ps),
    member(Kind-Body, Ps), memberchk(Kind, [set, add, alias]), !,
    pairs_of(Body, [Target-Text]),
    W = step(Q, I),
    store_expression(W, Text),
    ( Kind == alias -> S = alias(Target, W)
    ; atomic_list_concat(Path0, '->', Target), maplist(trimmed, Path0, Path),
      S =.. [Kind, Path, W]
    ).

load_rule(Kind, NS, N, R) :-
    q(NS, N, Q), scope_of(NS, N, Sc),
    ( get_dict(input, R, In) -> pending_or_resolved(Sc, In, InQ) ; InQ = none ),
    W = rule(Q), store_expression(W, R.expression),
    assertz(rune_model:rune_rule(Kind, Q, InQ, W, R.get(annotations, _{}),
                                 R.get(description, ''))).

load_report(NS, Name, R) :-
    Sc = scope(NS, '*'),
    pending_or_resolved(Sc, R.input, InQ),
    pending_or_resolved(Sc, R.reportType, TQ),
    maplist(eligibility_name(Sc), R.eligibility, Elig),
    assertz(rune_model:rune_report(Name, R.regulatoryBody, R.corpus, InQ, Elig, TQ)).

store_expression(W, Text) :-
    assertz(rune_model:rune_expr_text(W, Text)),
    ( catch(rune_parse(Text, AST), E, (AST = error(E))) -> true ; AST = error(unparsed) ),
    assertz(rune_model:rune_expr_ast(W, AST)).

%!  rune_expression(?Where, ?Text, ?AST) is nondet.
rune_expression(W, Text, AST) :-
    rune_model:rune_expr_text(W, Text),
    rune_model:rune_expr_ast(W, AST).

% ---------------------------------------------------------------- names

%!  resolve_name(+Scope, +Name, ?Kind, -QName) is semidet.
%
%   Scope is scope(Namespace, File). A name with dots is an alias's (first
%   part) or a namespace's; a plain name is the namespace's own member, else
%   a member of one of the file's imports (the first that has it).
resolve_name(scope(NS, File), Name, Kind, Q) :-
    atomic_list_concat(Parts, '.', Name),
    ( Parts = [N] ->
        ( rune_model:rune_member(NS, N, Kind, _) -> q(NS, N, Q)
        ; file_imports(NS, File, Imports),
          member(I, Imports),
          (   rune_model:rune_member(I, N, Kind, _) -> q(I, N, Q)
          ;   % import cdm.product.asset.FloatingRateBase: one name
              atomic_list_concat(IParts, '.', I), append(INs, [N], IParts),
              atomic_list_concat(INs, '.', NS1),
              rune_model:rune_member(NS1, N, Kind, _) -> Q = I
          )
        )
    ; append(Pre, [N], Parts), Pre = [First|Rest],
      (   file_alias(NS, File, First, Target),
          atomic_list_concat([Target|Rest], '.', NS2)
      ;   atomic_list_concat(Pre, '.', NS2)            % a full name
      ;   % a name relative to the namespace, or to one that contains it:
          % `party.ReportSubmittingEntity` in drr.regulation.common.trade
          atomic_list_concat(NSParts, '.', NS), append(Outer, _, NSParts), Outer \== [],
          append(Outer, Pre, Parts2), atomic_list_concat(Parts2, '.', NS2)
      ;   % or relative to an imported namespace: `payment.PeriodicPayment`
          % with `import drr.base.trade.*`
          file_imports(NS, File, Imports), member(I, Imports),
          atomic_list_concat([I|Pre], '.', NS2)
      ),
      rune_model:rune_member(NS2, N, Kind, _), q(NS2, N, Q)
    ), !.

file_imports(NS, File, Imports) :-
    ( rune_model:rune_file(NS, File, Imports, _) -> true
    ; findall(I, (rune_model:rune_file(NS, _, Is, _), member(I, Is)), Imports0),
      list_to_set(Imports0, Imports)
    ).

file_alias(NS, File, A, T) :-
    ( rune_model:rune_file(NS, File, _, As), memberchk(A-T, As) -> true
    ; rune_model:rune_file(NS, _, _, As), memberchk(A-T, As) -> true
    ).

resolve_type_ref(_, Name, Name) :- basic_type(Name), !.
resolve_type_ref(Sc, Name0, Q) :-
    % a type with parameters: string(maxLength: 72)
    ( sub_atom(Name0, B, _, _, '(') -> sub_atom(Name0, 0, B, _, Name) ; Name = Name0 ),
    ( basic_type(Name) -> Q = Name
    ; member(K, [type, enum, choice, typeAlias]), resolve_name(Sc, Name, K, Q) -> true
    ).

basic_type(T) :- memberchk(T, [string, int, number, boolean, date, time,
    dateTime, zonedDateTime, productType, eventType, calculation]).

% ---------------------------------------------------------------- types

%!  type_ancestor(+Type, ?Ancestor) is nondet.
type_ancestor(T, T).
type_ancestor(T, A) :- rune_model:rune_type(T, S, _), S \== none, type_ancestor(S, A).

%!  type_attribute(+Type, ?Attr, -Info) is nondet.
%
%   An attribute of the type or of an ancestor; an `override` in a subtype
%   hides the ancestor's.
type_attribute(T, A, attr(TQ, Card, Meta, Anns)) :-
    type_attribute_(T, A, TQ, Card, Meta, Anns).

type_attribute_(T, A, TQ, Card, Meta, Anns) :-
    rune_model:rune_type(T, S, _),
    (   rune_model:rune_attr(T, A, TQ, Card, Meta, Anns)
    ;   S \== none,
        type_attribute_(S, A, TQ, Card, Meta, Anns),
        \+ rune_model:rune_attr(T, A, _, _, _, _)
    ).
%   A type that extends a choice has the choice's options (CDM's
%   BasketConstituent extends Observable: Asset, Basket or Index), each
%   named after its type, of one value or none.
type_attribute_(T, A, TQ, card(0, 1), _{}, []) :-
    rune_model:rune_type(T, S, _), S \== none,
    rune_model:rune_choice(S, Os),
    member(TQ, Os), atomic_list_concat(Parts, '.', TQ), last(Parts, A),
    \+ rune_model:rune_attr(T, A, _, _, _, _).

%!  enum_value_json(+Enum, ?Value, -Json) is nondet.
%
%   The text of an enumeration value in the JSON of an object: its display
%   name when it has one, else its name. An enum that extends another has
%   the other's values too.
enum_value_json(E, V, J) :-
    rune_model:rune_enum(E, Super, Vs),
    (   member(ev(V, D, _), Vs), ( D == none -> J = V ; J = D )
    ;   Super \== none, enum_value_json(Super, V, J),
        \+ memberchk(ev(V, _, _), Vs)
    ).

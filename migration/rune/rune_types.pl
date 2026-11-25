:- module(rune_types, [
    typed_expression/4,     % +Where, +Env, -Typed, -Type
    type_expr/4,            % +Env, +AST, -Typed, -Type
    rule_env/2,             % +RuleQ, -Env
    func_env/2,             % +FuncQ, -Env
    expression_scope/2,     % +Where, -Scope
    typed_refs/2            % +Typed, -Refs: [func(Q) | rule(Q) | attr(T, A) | enum(E)]
]).
/** <module> The typing of Rune's expressions: every name resolved, every
node given a type and a cardinality

    Type = ty(Kind, Card)
    Kind = object(Q) | enum(Q) | basic(B) | boolean | unknown
    Card = single | multi

The typed tree has the shape of the parsed one (rune_expr.pl), with the
names resolved:

    attr(R, Owner, A, Meta)       R -> A, Owner the type A is an attribute of,
                                  Meta its metadata dict
    meta(R, Owner, A, Key)        R -> A -> scheme: the metadata of a value
    var(Name)                     an input, an alias's name, a parameter
    alias(Name, Typed)            an alias of a function, inlined where used
    item                          the implicit variable
    call(func, Q, Args)           a function, its arguments typed
    call(rule, Q, [Arg])          a reporting or eligibility rule
    enum(E, V)                    an enumeration value
    unresolved(Name)              a name nothing resolves: residue

and the operations of rune_expr.pl, their children typed. The rules of
the semantics followed are the Rune runtime's (finos/rune-dsl 9.95.0,
rune-runtime: ExpressionOperatorsNullSafe, ExpressionEqualityUtilNullSafe):
a path over a list gives the list of its values, flattened.

Env = env(Scope, Item, Vars):
    Scope   scope(Namespace, File), for names (rune_reader:resolve_name/4)
    Item    none | ty(...) of the implicit variable
    Vars    [Name-Binding], Binding = ty(...) | alias(Typed, ty(...))
*/

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(parser/rune_reader).
:- use_module(rune_data, [type_feature/3, value_type/2]).

%!  expression_scope(+Where, -Scope) is det.
expression_scope(rule(Q), Sc) :- !, q_scope(Q, Sc).
expression_scope(step(Q, _), Sc) :- !, q_scope(Q, Sc).
expression_scope(fcond(Q, _), Sc) :- !, q_scope(Q, Sc).
expression_scope(cond(Q, _), Sc) :- q_scope(Q, Sc).

q_scope(Q0, scope(NS, File)) :-
    ( sub_atom(Q0, B, _, _, '(') -> sub_atom(Q0, 0, B, _, Q) ; Q = Q0 ),
    atomic_list_concat(Ps, '.', Q), append(NSPs, [N], Ps),
    atomic_list_concat(NSPs, '.', NS),
    ( rune_model:rune_member(NS, N, _, File) -> true ; File = '*' ).

%!  rule_env(+RuleQ, -Env) is det.
rule_env(Q, env(Sc, Item, [])) :-
    rune_model:rune_rule(_, Q, In, _, _, _),
    q_scope(Q, Sc),
    ( In == none -> Item = none ; kind_of(In, K), Item = ty(K, single) ).

%!  func_env(+FuncQ, -Env) is det.
%
%   The inputs, then each alias in order (an alias sees the inputs and the
%   aliases before it).
func_env(Q, env(Sc, none, Vars)) :-
    rune_model:rune_func(Q, Ins, _, Steps, _, _, _),
    q_scope(Q, Sc),
    maplist(input_binding, Ins, Vars0),
    foldl(alias_binding(Sc), Steps, Vars0, Vars).

input_binding(in(N, T, card(_, Max)), N-ty(K, C)) :-
    kind_of(T, K), ( Max == 1 -> C = single ; C = multi ).

alias_binding(Sc, alias(N, W), Vs0, Vs) :- !,
    rune_expression(W, _, AST),
    (   AST \= error(_), catch(type_expr(env(Sc, none, Vs0), AST, T, Ty), _, fail)
    ->  append(Vs0, [N-alias(T, Ty)], Vs)
    ;   append(Vs0, [N-alias(unresolved(N), ty(unknown, multi))], Vs)
    ).
alias_binding(_, _, Vs, Vs).

kind_of(T, K) :-
    (   T == boolean -> K = boolean
    ;   value_type(T, VK) -> ( VK = basic(boolean) -> K = boolean ; K = VK )
    ;   K = unknown
    ).

%!  typed_expression(+Where, +Env, -Typed, -Type) is semidet.
typed_expression(W, Env, T, Ty) :-
    rune_expression(W, _, AST), AST \= error(_),
    type_expr(Env, AST, T, Ty).

% ---------------------------------------------------------------- typing

%!  type_expr(+Env, +AST, -Typed, -Type) is det.
type_expr(Env, AST, T, Ty) :- tx(AST, Env, none, T, Ty), !.
type_expr(_, AST, unresolved(AST), ty(unknown, multi)).

%   tx(+AST, +Env, +Expected, -Typed, -Type): Expected is the kind the
%   context wants (none, or the kind of the other side of a comparison),
%   which decides a bare enumeration value (`then I else N`).
tx(paren(E), Env, X, paren(T), Ty) :- !, tx(E, Env, X, T, Ty).
tx(implicit, env(_, Item, _), _, item, Ty) :- !,
    ( Item == none -> Ty = ty(unknown, multi) ; Ty = Item ).
tx(item, env(_, Item, _), _, item, Ty) :- !,
    ( Item == none -> Ty = ty(unknown, multi) ; Ty = Item ).
tx(bool(B), _, _, bool(B), ty(boolean, single)) :- !.
tx(str(S), _, _, str(S), ty(basic(string), single)) :- !.
tx(sq(S), _, _, str(S), ty(basic(string), single)) :- !.
tx(num(N), _, _, num(N), ty(basic(number), single)) :- !.
tx(empty, _, _, empty, ty(unknown, multi)) :- !.
tx(list(Es), Env, X, list(Ts), ty(K, multi)) :- !,
    maplist(tx_elem(Env, X), Es, Ts, Tys),
    ( member(ty(K0, _), Tys), K0 \== unknown -> K = K0 ; K = unknown ).
tx(feature(R, F), Env, X, T, Ty) :- !, tx_feature(R, F, Env, X, T, Ty).
tx(deep(R, F), Env, _, deep(RT, F, Paths), ty(K, multi)) :- !,
    tx(R, Env, none, RT, ty(RK, _)),
    (   RK = object(C), findall(path(P)-AT, deep_path(C, F, P, AT, 3), PAs), PAs \== []
    ->  pairs_keys_values(PAs, Paths, [AT1|_]), kind_of(AT1, K)
    ;   Paths = [], K = unknown
    ).
tx(sym(Q), Env, X, T, Ty) :- !, tx_sym(Q, Env, X, T, Ty).
tx(call(Q, As), Env, _, T, Ty) :- !, tx_call(Q, As, Env, T, Ty).
tx(if(C, A), Env, X, if(CT, AT), Ty) :- !,
    tx(C, Env, none, CT, _), tx(A, Env, X, AT, Ty0), card_multi_ok(Ty0, Ty).
tx(if(C, A, B), Env, X, if(CT, AT, BT), ty(K, Card)) :- !,
    tx(C, Env, none, CT, _),
    tx(A, Env, X, AT0, ty(KA, CA)),
    ( KA == unknown, X \== none -> X1 = X ; KA \== unknown -> X1 = KA ; X1 = X ),
    tx(B, Env, X1, BT, ty(KB, CB)),
    ( KA == unknown, KB \== unknown -> tx(A, Env, KB, AT, _) ; AT = AT0 ),
    ( KA \== unknown -> K = KA ; K = KB ),
    ( CA == single, CB == single -> Card = single ; Card = multi ).
tx(or(L, R), Env, _, or(LT, RT), ty(boolean, single)) :- !,
    tx(L, Env, none, LT, _), tx(R, Env, none, RT, _).
tx(and(L, R), Env, _, and(LT, RT), ty(boolean, single)) :- !,
    tx(L, Env, none, LT, _), tx(R, Env, none, RT, _).
tx(eq(Op, M, L, R), Env, _, eq(Op, M, LT, RT, LTy, RTy), ty(boolean, single)) :- !,
    tx_pair(L, R, Env, LT, RT, LTy, RTy).
tx(cmp(Op, M, L, R), Env, _, cmp(Op, M, LT, RT, LTy, RTy), ty(boolean, single)) :- !,
    tx_pair(L, R, Env, LT, RT, LTy, RTy).
tx(arith(Op, L, R), Env, _, arith(Op, LT, RT, K), ty(K, single)) :- !,
    tx(L, Env, none, LT, ty(KL, _)), tx(R, Env, none, RT, ty(KR, _)),
    ( (KL = basic(string) ; KR = basic(string)) -> K = basic(string)
    ; (KL = basic(date) ; KR = basic(date)) -> K = basic(date)
    ; K = basic(number) ).
tx(contains(L, R), Env, _, contains(LT, RT), ty(boolean, single)) :- !,
    tx(L, Env, none, LT, ty(K, _)), tx(R, Env, K, RT, _).
tx(disjoint(L, R), Env, _, disjoint(LT, RT), ty(boolean, single)) :- !,
    tx(L, Env, none, LT, ty(K, _)), tx(R, Env, K, RT, _).
tx(default(L, R), Env, X, default(LT, RT), ty(K, C)) :- !,
    tx(L, Env, X, LT, ty(K, C)), tx(R, Env, K, RT, _).
tx(join(L, R), Env, _, join(LT, RT), ty(basic(string), single)) :- !,
    tx(L, Env, none, LT, _), ( R == none -> RT = none ; tx(R, Env, none, RT, _) ).
tx(exists(M, A), Env, _, exists(M, AT), ty(boolean, single)) :- !, tx(A, Env, none, AT, _).
tx(absent(A), Env, _, absent(AT), ty(boolean, single)) :- !, tx(A, Env, none, AT, _).
tx(op(N, A), Env, X, op(N, AT), Ty) :- !, tx(A, Env, X, AT, ATy), op_type(N, ATy, Ty).
tx(to_enum(A, E0), Env, _, to_enum(AT, E), ty(enum(E), single)) :- !,
    tx(A, Env, none, AT, _),
    env_scope(Env, Sc), ( resolve_name(Sc, E0, enum, E) -> true ; E = E0 ).
tx(as(A, T0), Env, _, as(AT, T), ty(K, single)) :- !,
    tx(A, Env, none, AT, _), env_scope(Env, Sc),
    ( member(Kd, [type, choice, enum]), resolve_name(Sc, T0, Kd, T) -> kind_of(T, K)
    ; T = T0, K = unknown ).
tx(filter(A, F), Env, _, filter(AT, FT), ty(K, multi)) :- !,
    tx(A, Env, none, AT, ty(K, _)),
    tx_fn(F, Env, ty(K, single), FT, _).
tx(extract(A, F), Env, _, extract(AT, FT), ty(K, C)) :- !,
    tx(A, Env, none, AT, ty(KA, CA)),
    tx_fn(F, Env, ty(KA, single), FT, ty(K, CF)),
    ( CA == single, CF == single -> C = single ; C = multi ).
tx(then(A, F), Env, X, then(AT, FT), Ty) :- !,
    tx(A, Env, none, AT, ATy),
    ( F == none -> FT = none, Ty = ATy ; tx_fn(F, Env, ATy, FT, Ty0, X), Ty = Ty0 ).
tx(sort(A, F), Env, _, sort(AT, FT), ty(K, multi)) :- !,
    tx(A, Env, none, AT, ty(K, _)), ( F == none -> FT = none ; tx_fn(F, Env, ty(K, single), FT, _) ).
tx(min(A, F), Env, _, min(AT, FT), ty(K, single)) :- !,
    tx(A, Env, none, AT, ty(K, _)), ( F == none -> FT = none ; tx_fn(F, Env, ty(K, single), FT, _) ).
tx(max(A, F), Env, _, max(AT, FT), ty(K, single)) :- !,
    tx(A, Env, none, AT, ty(K, _)), ( F == none -> FT = none ; tx_fn(F, Env, ty(K, single), FT, _) ).
tx(reduce(A, F), Env, _, reduce(AT, F), ty(K, single)) :- !, tx(A, Env, none, AT, ty(K, _)).
tx(switch(A, Cs), Env, X, switch(AT, CTs), ty(K, multi)) :- !,
    tx(A, Env, none, AT, ty(AK, _)),
    maplist(tx_case(Env, AK, X), Cs, CTs, Ks),
    ( member(K, Ks), K \== unknown -> true ; K = unknown ).
tx(choice(A, N, As), Env, _, choice(AT, N, As), ty(boolean, single)) :- !, tx(A, Env, none, AT, _).
tx(only_exists(Ps, P), Env, _, only_exists(PTs, P), ty(boolean, single)) :- !,
    maplist(tx_plain(Env), Ps, PTs).
tx(with_meta(A, Es), Env, X, with_meta(AT, Es), Ty) :- !, tx(A, Env, X, AT, Ty).
tx(as_key(A), Env, X, AT, Ty) :- !, tx(A, Env, X, AT, Ty).
tx(cons(T0, Ps, Rest), Env, _, cons(T, PTs, Rest), ty(K, single)) :- !,
    env_scope(Env, Sc),
    ( member(Kd, [type, choice]), resolve_name(Sc, T0, Kd, T) -> kind_of(T, K) ; T = T0, K = unknown ),
    maplist(tx_pair_value(Env, T), Ps, PTs).
tx(super, _, _, unresolved(super), ty(unknown, multi)) :- !.
tx(super(_), _, _, unresolved(super), ty(unknown, multi)) :- !.

tx_plain(Env, E, T) :- tx(E, Env, none, T, _).

%   A case of a switch: its guard (a literal, a value of the switch's
%   enumeration, or a type for a switch on a choice) and its value.
tx_case(Env, _AK, X, default(E), default(ET), K) :- !, tx(E, Env, X, ET, ty(K, _)).
tx_case(Env, AK, X, case(G, E), case(GT, ET), K) :-
    (   G = sym(N), AK = enum(En), enum_has(En, N) -> GT = enum(En, N)
    ;   G = sym(N), env_scope(Env, Sc), member(Kd, [type, choice]), resolve_name(Sc, N, Kd, TQ) -> GT = type(TQ)
    ;   G = sym(N) -> GT = unresolved(N)
    ;   GT = G
    ),
    tx(E, Env, X, ET, ty(K, _)).

%   The paths ->> follows: through the options of a choice (and the
%   options of an option), to the attribute.
deep_path(C, F, [C-F], AT, _) :- type_feature(C, F, feature(AT, _, _)), \+ rune_model:rune_choice(C, _), !.
deep_path(C, F, [C-O|P], AT, D) :-
    D > 0, rune_model:rune_choice(C, _), D1 is D - 1,
    type_feature(C, O, feature(OT, _, _)),
    ( value_type(OT, object(OQ)) -> deep_path(OQ, F, P, AT, D1) ).
tx_elem(Env, X, E, T, Ty) :- tx(E, Env, X, T, Ty).
%   A value of a constructor, the kind its attribute wants expected.
tx_pair_value(Env, T, K-V, K-VT) :-
    ( type_feature(T, K, feature(AT, _, _)) -> kind_of(AT, X) ; X = none ),
    tx(V, Env, X, VT, _).

card_multi_ok(ty(K, _), ty(K, multi)).

env_scope(env(Sc, _, _), Sc).

%   The two sides of a comparison: the side with a type tells the other
%   which enumeration a bare value belongs to.
tx_pair(L, R, Env, LT, RT, LTy, RTy) :-
    tx(L, Env, none, LT0, LTy0),
    LTy0 = ty(KL, _),
    tx(R, Env, KL, RT, RTy),
    RTy = ty(KR, _),
    (   KL == unknown, KR \== unknown -> tx(L, Env, KR, LT, LTy)
    ;   LT = LT0, LTy = LTy0
    ).

op_type(N, ty(K, _), ty(K, single)) :- memberchk(N, ['only-element', first, last, sum]), !.
op_type(count, _, ty(basic(int), single)) :- !.
op_type(N, ty(K, _), ty(K, multi)) :- memberchk(N, [flatten, distinct, reverse]), !.
op_type('one-of', _, ty(boolean, single)) :- !.
op_type('to-string', ty(_, C), ty(basic(string), C)) :- !.
op_type('to-number', ty(_, C), ty(basic(number), C)) :- !.
op_type('to-int', ty(_, C), ty(basic(int), C)) :- !.
op_type('to-time', ty(_, C), ty(basic(time), C)) :- !.
op_type('to-date', ty(_, C), ty(basic(date), C)) :- !.
op_type('to-date-time', ty(_, C), ty(basic(dateTime), C)) :- !.
op_type('to-zoned-date-time', ty(_, C), ty(basic(zonedDateTime), C)) :- !.

%   The body of an inline function, its parameter (or the implicit item)
%   bound to ItemTy.
tx_fn(F, Env, ItemTy, FT, Ty) :- tx_fn(F, Env, ItemTy, FT, Ty, none).
tx_fn(implicit(B), env(Sc, _, Vs), ItemTy, implicit(BT), Ty, X) :- !,
    tx(B, env(Sc, ItemTy, Vs), X, BT, Ty).
tx_fn(fn([], B), env(Sc, _, Vs), ItemTy, fn([], BT), Ty, X) :- !,
    tx(B, env(Sc, ItemTy, Vs), X, BT, Ty).
tx_fn(fn([P|_], B), env(Sc, Item, Vs), ItemTy, fn([P], BT), Ty, X) :- !,
    tx(B, env(Sc, Item, [P-ItemTy|Vs]), X, BT, Ty).

%   R -> F: an attribute of R's type, an enumeration value (Enum -> V), or
%   a metadata of a value (`-> scheme`).
tx_feature(sym(E0), V, Env, _, enum(E, V), ty(enum(E), single)) :-
    env_scope(Env, Sc), \+ sym_is_bound(E0, Env),
    resolve_name(Sc, E0, enum, E), enum_has(E, V), !.
tx_feature(R, F, Env, _, T, Ty) :-
    tx(R, Env, none, RT, ty(RK, RC)),
    (   RK = object(Owner), type_feature(Owner, F, feature(FT, card(_, Max), Meta))
    ->  kind_of(FT, K),
        ( RC == single, Max == 1 -> C = single ; C = multi ),
        T = attr(RT, Owner, F, Meta), Ty = ty(K, C)
    ;   memberchk(F, [scheme]), RT = attr(_, Owner, A, Meta), is_dict(Meta), get_dict(scheme, Meta, _)
    ->  RT = attr(R2, _, _, _), T = meta(R2, Owner, A, F), Ty = ty(basic(string), RC)
    ;   RK = basic(B), basic_feature(B, F, FT)
    ->  T = basic_feature(RT, F), Ty = ty(basic(FT), RC)        % a timestamp's date, a date's year
    ;   T = attr(RT, unknown, F, _{}), Ty = ty(unknown, multi)
    ).

%   The features Rune's basic types have (Rune's built-in types: a
%   zonedDateTime has a date, a time and a timezone; a date a year, a month
%   and a day).
basic_feature(zonedDateTime, date, date).
basic_feature(zonedDateTime, time, time).
basic_feature(zonedDateTime, timezone, string).
basic_feature(dateTime, date, date).
basic_feature(dateTime, time, time).
basic_feature(date, year, int).
basic_feature(date, month, int).
basic_feature(date, day, int).

sym_is_bound(N, env(_, Item, Vs)) :-
    ( memberchk(N-_, Vs) -> true
    ; Item = ty(object(T), _), type_feature(T, N, _) ).

enum_has(E, V) :- enum_value_json(E, V, _), !.

%   A bare name: a variable, an attribute of the item, a function or rule
%   called on the item (or with no inputs), an enumeration value the
%   context expects, or a value of the one enumeration in scope that has it.
tx_sym(N, env(_, _, Vs), _, T, Ty) :- memberchk(N-B, Vs), !,
    ( B = alias(AT, Ty) -> T = alias(N, AT) ; T = var(N), Ty = B ).
tx_sym(N, env(_, Item, _), _, attr(item, Owner, N, Meta), ty(K, C)) :-
    Item = ty(object(Owner), IC), type_feature(Owner, N, feature(FT, card(_, Max), Meta)), !,
    kind_of(FT, K), ( IC == single, Max == 1 -> C = single ; C = multi ).
tx_sym(N, Env, _, T, Ty) :-
    env_scope(Env, Sc), resolve_name(Sc, N, func, Q), !,
    rune_model:rune_func(Q, Ins, _, _, _, _, _),
    ( Ins == [] -> As = [] ; As = [implicit] ),
    tx_call_q(func, Q, As, Env, T, Ty).
tx_sym(N, Env, _, T, Ty) :-
    env_scope(Env, Sc), member(K, [rule, eligibility]), resolve_name(Sc, N, K, Q), !,
    tx_call_q(rule, Q, [implicit], Env, T, Ty).
tx_sym(N, _, enum(E), enum(E, N), ty(enum(E), single)) :- enum_has(E, N), !.
tx_sym(N, Env, _, enum(E, N), ty(enum(E), single)) :-
    env_scope(Env, Sc), scope_enum_with(Sc, N, E), !.
tx_sym(N, _, _, unresolved(N), ty(unknown, multi)).

scope_enum_with(scope(NS, File), V, E) :-
    rune_reader:file_imports(NS, File, Is0), Is = [NS|Is0],
    findall(E0, ( member(I, Is), rune_model:rune_member(I, N, enum, _),
                  atomic_list_concat([I, N], '.', E0), enum_has(E0, V) ), Es0),
    sort(Es0, Es),
    Es = [E|_].

tx_call(Q0, As, Env, T, Ty) :-
    env_scope(Env, Sc),
    (   resolve_name(Sc, Q0, func, Q) -> tx_call_q(func, Q, As, Env, T, Ty)
    ;   member(K, [rule, eligibility]), resolve_name(Sc, Q0, K, Q) -> tx_call_q(rule, Q, As, Env, T, Ty)
    ;   T = unresolved(Q0), Ty = ty(unknown, multi)
    ).

tx_call_q(func, Q, As, Env, call(func, Q, ATs), Ty) :- !,
    rune_model:rune_func(Q, Ins, Out, _, _, _, _),
    length(As, N), length(Ins0, N), ( append(Ins0, _, Ins) -> true ; Ins0 = [] ),
    maplist(tx_arg(Env), As, Ins0, ATs),
    (   Out = out(_, OT, card(_, Max)) -> kind_of(OT, K), ( Max == 1 -> C = single ; C = multi )
    ;   K = unknown, C = multi
    ),
    Ty = ty(K, C).
tx_call_q(rule, Q, As, Env, call(rule, Q, ATs), ty(K, C)) :-
    maplist(tx_plain(Env), As, ATs),
    ( rule_output(Q, K, C) -> true ; K = unknown, C = multi ).

tx_arg(Env, A, in(_, T, _), AT) :- kind_of(T, K), tx(A, Env, K, AT, _).

%   The type of a rule's value, from its own expression (memoised).
:- dynamic rule_output_memo/3.
rule_output(Q, K, C) :- rule_output_memo(Q, K, C), !.
rule_output(Q, K, C) :-
    assertz(rule_output_memo(Q, unknown, multi)),        % a rule that calls itself
    (   rule_env(Q, Env), rune_model:rune_rule(_, Q, _, W, _, _),
        typed_expression(W, Env, _, ty(K0, C0))
    ->  K = K0, C = C0
    ;   K = unknown, C = multi
    ),
    retractall(rule_output_memo(Q, _, _)),
    assertz(rule_output_memo(Q, K, C)).

% ---------------------------------------------------------------- references

%!  typed_refs(+Typed, -Refs) is det.
%
%   What a typed expression reads: the functions and rules it calls, the
%   attributes it reads (with the type they belong to), the enumerations
%   it names.
typed_refs(T, Refs) :- phrase(refs(T), Rs0), sort(Rs0, Refs).

refs(V) --> { var(V) }, !.
refs(attr(R, Owner, A, _)) --> !, [attr(Owner, A)], refs(R).
refs(basic_feature(R, _)) --> !, refs(R).
refs(meta(R, Owner, A, K)) --> !, [attr(Owner, A), meta(Owner, A, K)], refs(R).
refs(call(K, Q, As)) --> !, [call(K, Q)], refs_list(As).
refs(enum(E, _)) --> !, [enum(E)].
refs(alias(_, T)) --> !, refs(T).
refs(unresolved(N)) --> !, [unresolved(N)].
refs(to_enum(A, E)) --> !, [enum(E)], refs(A).
refs(only_exists(Ps, _)) --> !,
    { findall(attr(O, B), ( member(attr(_, O, _, _), Ps), type_feature(O, B, _) ), As) },
    As, refs_list(Ps).
refs(deep(R, _, Paths)) --> !, refs(R), deep_refs(Paths).
refs(switch(A, Cs)) --> !, refs(A), refs_list(Cs).
refs(as(A, T)) --> !, { atomic_list_concat(Ps, '.', T), last(Ps, S), findall(attr(C, S), ( rune_model:rune_choice(C, Os), memberchk(T, Os) ), As) }, As, refs(A).
refs(cons(T, Ps, _)) --> !, { findall(attr(T, K), member(K-_, Ps), As) }, As, cons_refs(Ps).
refs(T) --> { compound(T), !, T =.. [_|As] }, refs_list(As).
refs(_) --> [].

cons_refs([]) --> [].
cons_refs([_-V|Ps]) --> refs(V), cons_refs(Ps).

deep_refs([]) --> [].
deep_refs([path(P)|Ps]) --> { deep_owner_attrs(P, As) }, As, deep_refs(Ps).

deep_owner_attrs(P, As) :- findall(attr(O, A), member(O-A, P), As).

refs_list([]) --> [].
refs_list([A|As]) --> refs(A), refs_list(As).

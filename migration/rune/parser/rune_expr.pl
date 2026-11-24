:- module(rune_expr, [
    rune_tokens/2,          % +Text, -Tokens
    rune_parse/2,           % +Text, -AST
    rune_parse_tokens/2,    % +Tokens, -AST
    rune_print/2,           % +AST, -Text
    rune_print_tokens/2     % +AST, -Tokens
]).
/** <module> Rune's expression language: lexer, parser and printer

The expressions of conditions, functions and reporting rules, after Rune's
own grammar (finos/rune-dsl 9.95.0, `rune-lang/.../Rosetta.xtext`, the rules
`Expression` down to `PrimaryExpression`). Precedence, lowest first:

    then  <  or  <  and  <  = <>  <  < <= > >=  <  + -  <  * /
          <  contains disjoint default join  <  postfix operations  <  primary

The body of `filter`, `extract` and `reduce` without brackets is an `or`
expression (Rune's ImplicitInlineFunction), so `xs filter a = b and c`
filters on `a = b and c`; `then` passes the whole value on its left to the
function on its right.

The tree:

    then(A, F)                    F is a function body (fn/2 or implicit/1)
    or(L, R)  and(L, R)           a missing left side is `implicit`
    eq(Op, Mod, L, R)             Op = (=) | (<>), Mod = none | any | all
    cmp(Op, Mod, L, R)            Op = (<) | (=<) | (>) | (>=)
    arith(Op, L, R)               Op = (+) | (-) | (*) | (/)
    contains(L, R)  disjoint(L, R)  default(L, R)  join(L, R|none)
    feature(R, F)  deep(R, F)     R -> F, R ->> F
    exists(Mod, A)                Mod = none | single | multiple
    absent(A)
    op(Name, A)                   only-element count flatten distinct reverse
                                  first last sum one-of to-string to-number
                                  to-int to-time to-date to-date-time
                                  to-zoned-date-time
    to_enum(A, Enum)  as(A, Type)  choice(A, Necessity, Attributes)
    switch(A, Cases)              Cases: case(Guard, E) | default(E)
    with_meta(A, Entries)         Entries: Key-E
    sort(A, F)  min(A, F)  max(A, F)        F = none | fn(Params, Body)
    filter(A, F)  extract(A, F)  reduce(A, F)
                                  F = fn(Params, Body) | implicit(Body)
    if(C, T)  if(C, T, E)
    sym(QName)  call(QName, Args)  item  super  super(Args)
    bool(true|false)  str(S)  num(Text)  empty  list(Elements)
    sq(S)                         a string in single quotes
    cons(Type, Pairs, Rest)       Rest = none | ellipsis | comma
    only_exists(Paths, Parens)    Parens = true | false
    as_key(E)                     inside a constructor
    paren(E)                      kept, so that printing gives the source back

`rune_print/2` writes a tree back as Rune; the gate (gate.pl) checks that
the printed tokens of every expression are the tokens of its source.
*/

:- use_module(library(lists)).
:- use_module(library(apply)).

%!  rune_tokens(+Text, -Tokens) is det.
%
%   Tokens: id(Name), str(String), num(Text), kw(Keyword), p(Punct).
%   Keywords with a hyphen (only-element, to-string) are one token.
rune_tokens(Text, Tokens) :-
    ( string(Text) -> S = Text ; atom_string(Text, S) ),
    string_codes(S, Cs),
    phrase(tokens(Tokens), Cs), !.

tokens(Ts) --> ws, ( eos_ -> { Ts = [] } ; token(T), { Ts = [T|R] }, tokens(R) ).

eos_([], []).

ws --> [C], { code_type(C, space) }, !, ws.
ws --> "//", !, skip_line, ws.
ws --> "/*", !, skip_block, ws.
ws --> [].

skip_line --> [C], { C \== 0'\n }, !, skip_line.
skip_line --> [].
skip_block --> "*/", !.
skip_block --> [_], skip_block.

token(str(S)) --> "\"", !, str_codes(0'", Cs), { string_codes(S, Cs) }.
token(sq(S)) --> "'", !, str_codes(0'', Cs), { string_codes(S, Cs) }.
token(T) --> hyphen_keyword(K), !, { T = kw(K) }.
token(num(N)) --> digits1(D), ( ".", digits1(F) -> { append(D, [0'.|F], Ds) } ; { Ds = D } ),
    !, { atom_codes(N, Ds) }.
token(T) --> "^", ident_codes(Cs), !, { atom_codes(A, Cs), T = id(A) }.   % escaped keyword
token(T) --> ident_codes(Cs), !, { atom_codes(A, Cs), ( keyword(A) -> T = kw(A) ; T = id(A) ) }.
token(p(P)) --> punct(P), !.

str_codes(Q, []) --> [Q], !.
str_codes(Q, [C|Cs]) --> "\\", [C], !, str_codes(Q, Cs).
str_codes(Q, [C|Cs]) --> [C], str_codes(Q, Cs).

digits1([D|Ds]) --> [D], { code_type(D, digit) }, digits0(Ds).
digits0([D|Ds]) --> [D], { code_type(D, digit) }, !, digits0(Ds).
digits0([]) --> [].

ident_codes([C|Cs]) --> [C], { code_type(C, csymf) }, ident_rest(Cs).
ident_rest([C|Cs]) --> [C], { code_type(C, csym) }, !, ident_rest(Cs).
ident_rest([]) --> [].

hyphen_keyword(K) --> { hyphen_keyword(K), atom_codes(K, Cs) }, Cs, \+ ident_more.
ident_more --> [C], { code_type(C, csym) }.

hyphen_keyword('only-element').
hyphen_keyword('to-zoned-date-time').
hyphen_keyword('to-date-time').
hyphen_keyword('to-string').
hyphen_keyword('to-number').
hyphen_keyword('to-int').
hyphen_keyword('to-time').
hyphen_keyword('to-enum').
hyphen_keyword('to-date').
hyphen_keyword('one-of').
hyphen_keyword('with-meta').
hyphen_keyword('as-key').

punct('...') --> "...".
punct('->>') --> "->>".
punct('->') --> "->".
punct('<>') --> "<>".
punct('>=') --> ">=".
punct('<=') --> "<=".
punct(P) --> [C], { memberchk(C, `=<>+-*/()[]{},:.`), atom_codes(P, [C]) }.

keyword(K) :- memberchk(K, [if, then, else, and, or, extract, filter, reduce,
    exists, is, absent, count, flatten, distinct, reverse, first, last, sum,
    sort, min, max, contains, disjoint, default, join, all, any, single,
    multiple, 'True', 'False', empty, item, super, switch, as, only, choice,
    optional, required]).

%!  rune_parse(+Text, -AST) is semidet.
rune_parse(Text, AST) :-
    rune_tokens(Text, Ts),
    rune_parse_tokens(Ts, AST).

rune_parse_tokens(Ts, AST) :-
    phrase(expression(AST), Ts), !.

% ---------------------------------------------------------------- grammar

expression(E) --> then_op(E0), ( [kw('as-key')] -> { E = as_key(E0) } ; { E = E0 } ).

then_op(E) --> or_op(A), then_rest(A, E).
then_rest(A, E) --> [kw(then)], !,
    ( fn_body_implicit(F) -> { T = then(A, F) } ; { T = then(A, none) } ),
    then_rest(T, E).
then_rest(A, A) --> [].

fn_body_implicit(implicit(B)) --> or_op(B).

or_op(E) --> and_op(L), or_rest(L, E).
or_op(E) --> [kw(or)], and_op(R), or_rest(or(implicit, R), E).
or_rest(L, E) --> [kw(or)], !, and_op(R), or_rest(or(L, R), E).
or_rest(E, E) --> [].

and_op(E) --> eq_op(L), and_rest(L, E).
and_op(E) --> [kw(and)], eq_op(R), and_rest(and(implicit, R), E).
and_rest(L, E) --> [kw(and)], !, eq_op(R), and_rest(and(L, R), E).
and_rest(E, E) --> [].

eq_op(E) --> cmp_op(L), eq_rest(L, E).
eq_op(E) --> card_mod(M), eq_sym(Op), cmp_op(R), eq_rest(eq(Op, M, implicit, R), E).
eq_rest(L, E) --> card_mod(M), eq_sym(Op), !, cmp_op(R), eq_rest(eq(Op, M, L, R), E).
eq_rest(E, E) --> [].
eq_sym(=) --> [p(=)].
eq_sym(<>) --> [p(<>)].

card_mod(any) --> [kw(any)], !.
card_mod(all) --> [kw(all)], !.
card_mod(none) --> [].

cmp_op(E) --> add_op(L), cmp_rest(L, E).
cmp_op(E) --> card_mod(M), cmp_sym(Op), add_op(R), cmp_rest(cmp(Op, M, implicit, R), E).
cmp_rest(L, E) --> card_mod(M), cmp_sym(Op), !, add_op(R), cmp_rest(cmp(Op, M, L, R), E).
cmp_rest(E, E) --> [].
cmp_sym(>=) --> [p('>=')].
cmp_sym(=<) --> [p('<=')].
cmp_sym(>) --> [p(>)].
cmp_sym(<) --> [p(<)].

add_op(E) --> mul_op(L), add_rest(L, E).
add_rest(L, E) --> add_sym(Op), !, mul_op(R), add_rest(arith(Op, L, R), E).
add_rest(E, E) --> [].
add_sym(+) --> [p(+)].
add_sym(-) --> [p(-)].

mul_op(E) --> bin_op(L), mul_rest(L, E).
mul_op(E) --> mul_sym(Op), bin_op(R), mul_rest(arith(Op, implicit, R), E).
mul_rest(L, E) --> mul_sym(Op), !, bin_op(R), mul_rest(arith(Op, L, R), E).
mul_rest(E, E) --> [].
mul_sym(*) --> [p(*)].
mul_sym(/) --> [p(/)].

% Rune allows one binary operation here, and one more after a missing left side.
bin_op(E) --> unary(L), ( bin_tail(L, E0) -> { E = E0 } ; { E = L } ).
bin_op(E) --> bin_tail(implicit, E1), ( bin_tail(E1, E) -> [] ; { E = E1 } ).
bin_tail(L, contains(L, R)) --> [kw(contains)], unary(R).
bin_tail(L, disjoint(L, R)) --> [kw(disjoint)], unary(R).
bin_tail(L, default(L, R)) --> [kw(default)], unary(R).
bin_tail(L, join(L, R)) --> [kw(join)], ( unary(R0) -> { R = R0 } ; { R = none } ).

unary(E) --> primary(P), postfix(P, E).
unary(E) --> postfix_op(implicit, E1), postfix(E1, E).

postfix(A, E) --> postfix_op(A, B), !, postfix(B, E).
postfix(E, E) --> [].

postfix_op(R, feature(R, F)) --> [p('->')], feature_name(F).
postfix_op(R, deep(R, F)) --> [p('->>')], feature_name(F).
postfix_op(A, exists(M, A)) --> exists_mod(M), [kw(exists)].
postfix_op(A, absent(A)) --> [kw(is), kw(absent)].
postfix_op(A, op(N, A)) --> [kw(N)], { simple_postfix(N) }.
postfix_op(A, to_enum(A, Enum)) --> [kw('to-enum')], qname(Enum).
postfix_op(A, choice(A, N, Attrs)) --> [kw(N)], { memberchk(N, [optional, required]) },
    [kw(choice)], id_list(Attrs).
postfix_op(A, switch(A, Cases)) --> [kw(switch)], switch_cases(Cases).
postfix_op(A, with_meta(A, Es)) --> [kw('with-meta')], [p('{')], meta_entries(Es), [p('}')].
postfix_op(A, as(A, T)) --> [kw(as)], qname(T).
postfix_op(A, T) --> [kw(Op)], { memberchk(Op, [sort, min, max]) },
    ( inline_fn(F) -> [] ; { F = none } ), { T =.. [Op, A, F] }.
postfix_op(A, T) --> [kw(Op)], { memberchk(Op, [filter, extract, reduce]) },
    ( inline_fn(F) -> [] ; fn_body_implicit(F) ), { T =.. [Op, A, F] }.

feature_name(F) --> [id(F)].
feature_name(F) --> [kw(F)], { memberchk(F, [condition, source, value, version, pattern, scope]) }.

simple_postfix(N) :- memberchk(N, ['only-element', count, flatten, distinct, reverse,
    first, last, sum, 'one-of', 'to-string', 'to-number', 'to-int', 'to-time',
    'to-date', 'to-date-time', 'to-zoned-date-time']).

exists_mod(single) --> [kw(single)].
exists_mod(multiple) --> [kw(multiple)].
exists_mod(none) --> [].

inline_fn(fn(Ps, B)) --> params(Ps), [p('[')], expression(B), [p(']')].
params([P|Ps]) --> [id(P)], params_rest(Ps).
params([]) --> [].
params_rest([P|Ps]) --> [p(',')], [id(P)], params_rest(Ps).
params_rest([]) --> [].

id_list([A|As]) --> [id(A)], ( [p(',')], id_list(As) -> [] ; { As = [] } ).

switch_cases([C|Cs]) --> switch_case(C), ( [p(',')], switch_cases(Cs) -> [] ; { Cs = [] } ).
switch_case(default(E)) --> [kw(default)], expression(E).
switch_case(case(G, E)) --> switch_guard(G), [kw(then)], expression(E).
switch_guard(L) --> literal(L), !.
switch_guard(sym(Q)) --> qname(Q).

meta_entries([K-E|Es]) --> [id(K), p(:)], expression(E), ( [p(',')], meta_entries(Es) -> [] ; { Es = [] } ).
meta_entries([]) --> [].

primary(E) --> constructor(E), !.
primary(E) --> [kw(if)], !, or_op(C), [kw(then)], or_op(T),
    ( [kw(else)] -> or_op(F), { E = if(C, T, F) } ; { E = if(C, T) } ).
primary(E) --> only_exists(E), !.
primary(E) --> [kw(super)], !, ( args(As) -> { E = super(As) } ; { E = super } ).
primary(item) --> [kw(item)], !.
primary(E) --> qname(Q), !, ( args(As) -> { E = call(Q, As) } ; { E = sym(Q) } ).
primary(E) --> literal(E), !.
primary(empty) --> [kw(empty)], !.
primary(list(Es)) --> [p('[')], !, ( [p(']')] -> { Es = [] } ; elements(Es), [p(']')] ).
primary(paren(E)) --> [p('(')], expression(E), [p(')')].

literal(bool(true)) --> [kw('True')].
literal(bool(false)) --> [kw('False')].
literal(str(S)) --> [str(S)].
literal(sq(S)) --> [sq(S)].
literal(num(N)) --> [num(N)].
literal(num(N)) --> [p(-), num(N0)], { atom_concat('-', N0, N) }.

elements([E|Es]) --> expression(E), ( [p(',')] -> elements(Es) ; { Es = [] } ).

args(As) --> [p('(')], ( [p(')')] -> { As = [] } ; elements(As), [p(')')] ).

qname(Q) --> valid_id(A), qname_rest(As), { atomic_list_concat([A|As], '.', Q) }.
qname_rest([A|As]) --> [p('.')], valid_id(A), !, qname_rest(As).
qname_rest([]) --> [].
valid_id(A) --> [id(A)].
valid_id(A) --> [kw(A)], { memberchk(A, [condition, source, value, version, pattern, scope]) }.

constructor(cons(T, Ps, Rest)) --> qname(T), [p('{')], cons_body(Ps, Rest), [p('}')].
cons_body([], ellipsis) --> [p('...')], !.
cons_body([], none) --> [].
cons_body([P|Ps], Rest) --> cons_pair(P), cons_more(Ps, Rest).
cons_more([], ellipsis) --> [p(','), p('...')], !.
cons_more([P|Ps], Rest) --> [p(',')], cons_pair(P), !, cons_more(Ps, Rest).
cons_more([], comma) --> [p(',')], !.
cons_more([], none) --> [].
cons_pair(K-V) --> valid_id(K), [p(:)], expression(V0),
    ( [kw('as-key')] -> { V = as_key(V0) } ; { V = V0 } ).

only_exists(only_exists(Ps, true)) --> [p('(')], oe_elements(Ps), [p(')'), kw(only), kw(exists)].
only_exists(only_exists([P], false)) --> oe_element(P), [kw(only), kw(exists)].
oe_elements([P|Ps]) --> oe_element(P), ( [p(',')] -> oe_elements(Ps) ; { Ps = [] } ).
oe_element(E) --> oe_root(R), oe_path(R, E).
oe_root(item) --> [kw(item)].
oe_root(sym(Q)) --> qname(Q).
oe_path(R, E) --> [p('->')], feature_name(F), !, oe_path(feature(R, F), E).
oe_path(E, E) --> [].

% ---------------------------------------------------------------- printer

%!  rune_print(+AST, -Text) is det.
rune_print(AST, Text) :-
    rune_print_tokens(AST, Ts),
    maplist(token_text, Ts, Ws),
    atomic_list_concat(Ws, ' ', Text).

token_text(id(A), A).
token_text(kw(A), A).
token_text(p(A), A).
token_text(num(A), A).
token_text(str(S), T) :- format(atom(T), '"~s"', [S]).
token_text(sq(S), T) :- format(atom(T), "'~s'", [S]).

rune_print_tokens(AST, Ts) :- phrase(pr(AST), Ts), !.

pr(implicit) --> [].
pr(then(A, F)) --> pr(A), [kw(then)], pr_fn(F).
pr(or(L, R)) --> pr(L), [kw(or)], pr(R).
pr(and(L, R)) --> pr(L), [kw(and)], pr(R).
pr(eq(Op, M, L, R)) --> pr(L), pr_mod(M), { eq_tok(Op, T) }, [p(T)], pr(R).
pr(cmp(Op, M, L, R)) --> pr(L), pr_mod(M), { cmp_tok(Op, T) }, [p(T)], pr(R).
pr(arith(Op, L, R)) --> pr(L), [p(Op)], pr(R).
pr(contains(L, R)) --> pr(L), [kw(contains)], pr(R).
pr(disjoint(L, R)) --> pr(L), [kw(disjoint)], pr(R).
pr(default(L, R)) --> pr(L), [kw(default)], pr(R).
pr(join(L, none)) --> !, pr(L), [kw(join)].
pr(join(L, R)) --> pr(L), [kw(join)], pr(R).
pr(feature(R, F)) --> pr(R), [p('->')], pr_id(F).
pr(deep(R, F)) --> pr(R), [p('->>')], pr_id(F).
pr(exists(M, A)) --> pr(A), ( { M == none } -> [] ; [kw(M)] ), [kw(exists)].
pr(absent(A)) --> pr(A), [kw(is), kw(absent)].
pr(op(N, A)) --> pr(A), [kw(N)].
pr(to_enum(A, E)) --> pr(A), [kw('to-enum')], pr_q(E).
pr(choice(A, N, As)) --> pr(A), [kw(N), kw(choice)], pr_ids(As).
pr(switch(A, Cs)) --> pr(A), [kw(switch)], pr_cases(Cs).
pr(with_meta(A, Es)) --> pr(A), [kw('with-meta'), p('{')], pr_meta(Es), [p('}')].
pr(as(A, T)) --> pr(A), [kw(as)], pr_q(T).
pr(sort(A, F)) --> pr(A), [kw(sort)], pr_fn(F).
pr(min(A, F)) --> pr(A), [kw(min)], pr_fn(F).
pr(max(A, F)) --> pr(A), [kw(max)], pr_fn(F).
pr(filter(A, F)) --> pr(A), [kw(filter)], pr_fn(F).
pr(extract(A, F)) --> pr(A), [kw(extract)], pr_fn(F).
pr(reduce(A, F)) --> pr(A), [kw(reduce)], pr_fn(F).
pr(if(C, T)) --> [kw(if)], pr(C), [kw(then)], pr(T).
pr(if(C, T, E)) --> [kw(if)], pr(C), [kw(then)], pr(T), [kw(else)], pr(E).
pr(sym(Q)) --> pr_q(Q).
pr(call(Q, As)) --> pr_q(Q), [p('(')], pr_list(As), [p(')')].
pr(item) --> [kw(item)].
pr(super) --> [kw(super)].
pr(super(As)) --> [kw(super), p('(')], pr_list(As), [p(')')].
pr(bool(true)) --> [kw('True')].
pr(bool(false)) --> [kw('False')].
pr(str(S)) --> [str(S)].
pr(sq(S)) --> [sq(S)].
pr(num(N)) --> { atom_concat('-', N0, N) }, !, [p(-), num(N0)].
pr(num(N)) --> [num(N)].
pr(empty) --> [kw(empty)].
pr(list(Es)) --> [p('[')], pr_list(Es), [p(']')].
pr(paren(E)) --> [p('(')], pr(E), [p(')')].
pr(cons(T, Ps, Rest)) --> pr_q(T), [p('{')], pr_pairs(Ps), pr_rest(Ps, Rest), [p('}')].
pr(as_key(E)) --> pr(E), [kw('as-key')].
pr(only_exists(Ps, true)) --> [p('(')], pr_list(Ps), [p(')'), kw(only), kw(exists)].
pr(only_exists([P], false)) --> pr(P), [kw(only), kw(exists)].

pr_fn(none) --> [].
pr_fn(implicit(B)) --> pr(B).
pr_fn(fn(Ps, B)) --> pr_ids(Ps), [p('[')], pr(B), [p(']')].

pr_mod(none) --> [].
pr_mod(M) --> { M \== none }, [kw(M)].

eq_tok(=, =).
eq_tok(<>, <>).
cmp_tok(<, <).
cmp_tok(=<, '<=').
cmp_tok(>, >).
cmp_tok(>=, '>=').

pr_list([]) --> [].
pr_list([E]) --> !, pr(E).
pr_list([E|Es]) --> pr(E), [p(',')], pr_list(Es).

pr_ids([]) --> [].
pr_ids([A]) --> !, pr_id(A).
pr_ids([A|As]) --> pr_id(A), [p(',')], pr_ids(As).

pr_id(A) --> [id(A)].

pr_q(Q) --> { atomic_list_concat(Parts, '.', Q) }, pr_qparts(Parts).
pr_qparts([A]) --> !, pr_id(A).
pr_qparts([A|As]) --> pr_id(A), [p('.')], pr_qparts(As).

pr_cases([C]) --> !, pr_case(C).
pr_cases([C|Cs]) --> pr_case(C), [p(',')], pr_cases(Cs).
pr_case(default(E)) --> [kw(default)], pr(E).
pr_case(case(G, E)) --> pr(G), [kw(then)], pr(E).

pr_meta([]) --> [].
pr_meta([K-E]) --> !, pr_id(K), [p(:)], pr(E).
pr_meta([K-E|Es]) --> pr_id(K), [p(:)], pr(E), [p(',')], pr_meta(Es).

pr_pairs([]) --> [].
pr_pairs([K-V]) --> !, pr_id(K), [p(:)], pr(V).
pr_pairs([K-V|Ps]) --> pr_id(K), [p(:)], pr(V), [p(',')], pr_pairs(Ps).
pr_rest(_, none) --> [].
pr_rest([], ellipsis) --> !, [p('...')].
pr_rest(_, ellipsis) --> [p(','), p('...')].
pr_rest(_, comma) --> [p(',')].

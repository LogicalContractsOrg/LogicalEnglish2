/** <module> Daml source: tokens, layout, and the subset the translator reads

    Phase 2g (the design notes roadmap.md §6.6). Daml is layout-sensitive
    Haskell; this reader implements the layout rule of the Haskell report
    (an implicit block opens after `where`, `with`, `do`, `let` and `of` at
    the column of the next token; a line starting at that column is a new
    item, a line to its left closes it; a closing bracket, a comma or `in`
    closes the blocks opened inside the bracket) and parses the subset of
    Daml a contract model is written in:

        module M where { decl ; ... }
        decl  import ... | type T = Ty | data T = C with { f : Ty ; ... } deriving ...
            | template T with { f : Ty ; ... } where { tdecl ; ... }
            | name : Ty | name args = expr
        tdecl signatory e, ... | observer e, ... | ensure e
            | [nonconsuming|preconsuming|postconsuming] choice C : Ty
                  [with { f : Ty ; ... }] controller e, ... do { stmt ; ... }
        stmt  pat <- e | let { x = e ; ... } | e
        expr  $, ||, &&, comparisons, <> ++, + -, * /, application, e.f,
              literals, (e), (e, e), [e, ...], C with { f = e ; ... },
              this with { ... }, do { ... }, if e then e else e, @T

    Everything else (interfaces, keys, case, lambdas, where-bound helpers,
    guards) is kept as `other(Kind, Text)` with its source text: the
    translator reports it as residue, never drops it.

        daml_module(+File, -module(Name, Decls))
*/

:- module(daml_syntax, [daml_module/2, daml_text_module/2, daml_tokens/2, expr_text/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).
:- use_module(library(dcg/basics)).

daml_module(File, Module) :-
    read_file_to_string(File, Text, [encoding(utf8)]),
    daml_text_module(Text, Module).

daml_text_module(Text, Module) :-
    daml_tokens(Text, Toks0),
    layout(Toks0, Toks),
    b_setval(daml_source_text, Text), b_setval(daml_nodo, false),
    (   phrase(module(Module), Toks) -> true
    ;   throw(error(syntax_error(daml_module), _))
    ).

		 /*******************************
		 *            TOKENS            *
		 *******************************/

%   t(Token, Line, Col, Offset): Token is id(A) | con(A) (a capitalised or
%   qualified name) | num(N) | str(S) | op(A) | p(C) (punctuation) | kw(K).
daml_tokens(Text, Toks) :-
    string_codes(Text, Cs),
    phrase(tokens(Toks, 1, 1, 0), Cs).

tokens(Ts, L, _, O) --> [0'\n], !, { L1 is L + 1, O1 is O + 1 }, tokens(Ts, L1, 1, O1).
tokens(Ts, L, C, O) --> [X], { code_type(X, space) }, !, { C1 is C + 1, O1 is O + 1 }, tokens(Ts, L, C1, O1).
tokens(Ts, L, C, O) --> "--", \+ op_code_peek, !, skip_line(N), { C1 is C + 2 + N, O1 is O + 2 + N }, tokens(Ts, L, C1, O1).
tokens(Ts, L, C, O) --> "{-", !, block_comment(Cs, 2), { advance(Cs, L, C, O, L1, C1, O1) }, tokens(Ts, L1, C1, O1).
tokens([t(T, L, C, O)|Ts], L, C, O) --> token(T, Len), !, { C1 is C + Len, O1 is O + Len }, tokens(Ts, L, C1, O1).
tokens([], _, _, _) --> [].

op_code_peek, [X] --> [X], { memberchk(X, `!#$%&*+./<=>?@\\^|~:`), X \== 0'- }.

skip_line(N) --> string_without(`\n`, Cs), { length(Cs, N) }.

block_comment(Cs, _) --> "-}", !, { Cs = `-}` }.
block_comment([X|Cs], D) --> [X], block_comment(Cs, D).

advance([], L, C, O, L, C1, O1) :- !, C1 is C + 2, O1 is O + 2.
advance([0'\n|Cs], L, _, O, L2, C2, O2) :- !, L1 is L + 1, O1 is O + 1, advance(Cs, L1, 1, O1, L2, C2, O2).
advance([_|Cs], L, C, O, L2, C2, O2) :- C1 is C + 1, O1 is O + 1, advance(Cs, L, C1, O1, L2, C2, O2).

token(str(S), Len) --> "\"", str_chars(Cs), "\"", !, { unescape(Cs, Us), string_codes(S, Us), length(Cs, N), Len is N + 2 }.
token(num(N), Len) --> digits1(Ds), ( ".", digits1(Fs) -> { append(Ds, [0'.|Fs], All) } ; { All = Ds } ), !,
    { number_codes(N, All), length(All, Len) }.
token(T, Len) --> name_codes(Cs), !, { classify(Cs, T), length(Cs, Len) }.
token(p(C), 1) --> [X], { memberchk(X, `()[],;{}\``), char_code(C, X) }, !.
token(op(A), Len) --> op_codes(Cs), { Cs \== [] }, !, { atom_codes(A, Cs), length(Cs, Len) }.

unescape([0'\\, 0'n|Cs], [0'\n|Us]) :- !, unescape(Cs, Us).
unescape([0'\\, X|Cs], [X|Us]) :- !, unescape(Cs, Us).
unescape([X|Cs], [X|Us]) :- !, unescape(Cs, Us).
unescape([], []).

str_chars([0'\\, X|Cs]) --> "\\", [X], !, str_chars(Cs).
str_chars([X|Cs]) --> [X], { X \== 0'" }, !, str_chars(Cs).
str_chars([]) --> [].

digits1([D|Ds]) --> [D], { code_type(D, digit) }, digits0(Ds).
digits0([D|Ds]) --> [D], { code_type(D, digit) }, !, digits0(Ds).
digits0([]) --> [].

%   A name: `owner`, `Asset`, `Main.Asset`, `DA.List`; `iou.owner` is
%   three tokens (a field access), which the parser puts together.
name_codes(Cs) --> ident(C1), qual_rest(C1, Cs).
ident([C|Cs]) --> [C], { code_type(C, alpha) ; C == 0'_ }, idrest(Cs).
idrest([C|Cs]) --> [C], { code_type(C, alnum) ; C == 0'_ ; C == 0'' }, !, idrest(Cs).
idrest([]) --> [].
qual_rest([U|Us], Cs) --> { code_type(U, upper) }, ".", ident(C2), !, { append([U|Us], [0'.|C2], C3) }, qual_rest(C2, Cs0), { qual_join(C3, C2, Cs0, Cs) }.
qual_rest(C1, C1) --> [].

qual_join(C3, C2, Cs0, Cs) :- ( Cs0 == C2 -> Cs = C3 ; append(Prefix, C2, C3), append(Prefix, Cs0, Cs) ).

op_codes([C|Cs]) --> [C], { memberchk(C, `!#$%&*+./<=>?@\\^|~:-`) }, !, op_codes(Cs).
op_codes([]) --> [].

keyword(K) :- memberchk(K, [module, where, import, qualified, as, hiding, type, data, template, with, do, let, in,
                            if, then, else, case, of, deriving, signatory, observer, ensure, choice,
                            controller, nonconsuming, preconsuming, postconsuming, key, maintainer,
                            interface, instance, this, class, newtype, viewtype, implements]).

classify(Cs, T) :-
    atom_codes(A, Cs),
    (   keyword(A) -> T = kw(A)
    ;   Cs = [C|_], code_type(C, upper) -> T = con(A)
    ;   T = id(A)
    ).

		 /*******************************
		 *            LAYOUT            *
		 *******************************/

%   The implicit blocks as explicit `{` `;` `}` (vo/vc/sep), after the
%   Haskell report's layout algorithm.
layout(Toks, Out) :- lay(Toks, [0], none, Out).

%   The stack: implicit block columns (integers > 0), `b` for an open
%   bracket, 0 at the bottom (the file).

layout_kw(kw(K)) :- memberchk(K, [where, with, do, let, of]).

%   lay(+Toks, +Stack, +Prev, -Out): Stack of block columns (0: explicit /
%   bracket context); Prev the previous token.
lay([], Stack, _, Out) :- close_all(Stack, Out).
lay([t(T, L, C, O)|Ts], Stack, Prev, Out) :-
    (   Prev = t(PT, _, _, _), layout_kw(PT), T \== p('{')
    ->  %  a new implicit block at this token's column
        ( member(M0, Stack), col(M0, M) -> true ; M = 0 ),
        ( PT == kw(let) -> Blk = let(C) ; Blk = C ),        % (a let block is what `in` closes)
        (   C > M
        ->  Out = [t(vo, L, C, O), t(T, L, C, O)|Out1], lay_after(T, Ts, [Blk|Stack], t(T, L, C, O), Out1)
        ;   Out = [t(vo, L, C, O), t(vc, L, C, O)|Out1], lay([t(T, L, C, O)|Ts], Stack, t(none, L, C, O), Out1)
        )
    ;   Prev = t(_, PL, _, _), L > PL
    ->  new_line(t(T, L, C, O), Ts, Stack, Out)
    ;   Prev == none
    ->  new_line(t(T, L, C, O), Ts, Stack, Out)
    ;   closer(T) -> close_for(T, Stack, Stack2, Closes), append(Closes, [t(T, L, C, O)|Out1], Out), lay(Ts, Stack2, t(T, L, C, O), Out1)
    ;   Out = [t(T, L, C, O)|Out1], lay_after(T, Ts, Stack, t(T, L, C, O), Out1)
    ).

%   The first token of a line: close the blocks it is left of, separate
%   the items of the block it starts in.
new_line(t(T, L, C, O), Ts, Stack, Out) :-
    close_left(C, Stack, Stack1, Closes),
    (   Stack1 = [C0|_], col(C0, C), C > 0, \+ closer(T), \+ memberchk(T, [kw(then), kw(else)])   % (DoAndIfThenElse)
    ->  Sep = [t(sep, L, C, O)]
    ;   Sep = []
    ),
    append(Closes, Sep, Pre),
    (   closer(T)
    ->  close_for(T, Stack1, Stack3, Closes2), append(Pre, Closes2, Pre2),
        append(Pre2, [t(T, L, C, O)|Out1], Out), lay(Ts, Stack3, t(T, L, C, O), Out1)
    ;   append(Pre, [t(T, L, C, O)|Out1], Out), lay_after(T, Ts, Stack1, t(T, L, C, O), Out1)
    ).

lay_after(T, Ts, Stack, Tok, Out) :-
    ( opener(T) -> Stack1 = [b|Stack] ; Stack1 = Stack ),
    lay(Ts, Stack1, Tok, Out).

opener(p('(')). opener(p('[')). opener(p('{')).
closer(p(')')). closer(p(']')). closer(p('}')). closer(p(',')). closer(kw(in)).

close_left(C, [M0|Ms], Stack, [t(vc, 0, 0, 0)|Cs]) :- col(M0, M), M > 0, C < M, !, close_left(C, Ms, Stack, Cs).
close_left(_, Stack, Stack, []).

%   A block's column (a let block is let(C)).
col(M, M) :- integer(M), !.
col(let(M), M).

%   A closing bracket or a comma inside brackets ends the implicit blocks
%   opened since the innermost bracket; `in` ends its `let`.
close_implicit(Stack, Stack, []) :- \+ memberchk(b, Stack), !.
close_implicit([M0|Ms], Stack, [t(vc, 0, 0, 0)|Cs]) :- col(M0, M), M > 0, !, close_implicit(Ms, Stack, Cs).
close_implicit(Stack, Stack, []).

pop_bracket(T, [b|Ms], Ms) :- memberchk(T, [p(')'), p(']'), p('}')]), !.
pop_bracket(_, Stack, Stack).

%   `in` closes its `let` block; a bracket or a comma the blocks inside it.
close_for(kw(in), [let(_)|Ms], Ms, [t(vc, 0, 0, 0)]) :- !.
close_for(kw(in), Stack, Stack, []) :- !.               % (its let block is closed already)
close_for(T, Stack, Stack2, Closes) :- close_implicit(Stack, Stack1, Closes), pop_bracket(T, Stack1, Stack2).

close_all([M|Ms], Cs) :- M == b, !, close_all(Ms, Cs).
close_all([M0|Ms], [t(vc, 0, 0, 0)|Cs]) :- col(M0, M), M > 0, !, close_all(Ms, Cs).
close_all(_, []).

		 /*******************************
		 *           THE PARSER         *
		 *******************************/

tok(T) --> [t(T, _, _, _)].
tok(T, O) --> [t(T, _, _, O)].

block(G) --> tok(vo), items(G, Is0), tok(vc), { exclude(==(skip), Is0, Is), b_setval(daml_block_items, Is) }.

%   items(:G, -Items): G's items separated by `;`, each item as G gives it.
items(G, [I|Is]) --> call(G, I), item_end, !, items_rest(G, Is).
items(G, Is) --> [t(S, _, _, _)], { separator(S) }, !, items(G, Is).
items(_, []) --> [].
items_rest(G, Is) --> [t(S, _, _, _)], { separator(S) }, !, items(G, Is).
items_rest(_, []) --> [].

%   An item ends at the next `;` or `}` of its block: an item a construct
%   parses only in part is parsed again by the next alternative (in the end
%   as `other`, its text).
item_end, [T] --> [T], { T = t(K, _, _, _), ( separator(K) ; K == vc ) }, !.
item_end --> \+ [_].

separator(sep).
separator(p(';')).                % an explicit `;` (`with coin = this; newOwner`)

module(module(Name, Decls)) --> pragmas, tok(kw(module)), mod_name(Name), tok(kw(where)),
    tok(vo), items(decl, Decls0), tok(vc), { exclude(==(skip), Decls0, Decls) }.
module(module('Main', Decls)) --> tok(vo), items(decl, Decls0), tok(vc), { exclude(==(skip), Decls0, Decls) }.

pragmas --> [].

mod_name(N) --> tok(con(N)).

%   A declaration; what the subset does not cover is kept as its text.
decl(D) --> decl_(D).
decl(other(Kind, Text)) --> [t(T0, L, _, O0)], rest_of_item(Ts), { item_text(O0, Ts, Text), kind_of(T0, Kind), ignore(L = _) }.

kind_of(kw(K), K) :- !.
kind_of(id(_), definition) :- !.
kind_of(_, declaration).

decl_(import(M)) --> tok(kw(import)), ( tok(kw(qualified)) -> [] ; [] ), tok(con(M)), rest_of_item(_).
decl_(type_alias(N, Ty)) --> tok(kw(type)), tok(con(N)), tok(op(=)), type(Ty).
decl_(data(N, C, Fs)) --> tok(kw(data)), tok(con(N)), tok(op(=)), tok(con(C)), tok(kw(with)), block_fields(Fs), deriving.
decl_(template(N, Fs, Body)) --> tok(kw(template)), tok(con(N)), tok(kw(with)), block_fields(Fs), tok(kw(where)), tbody(Body).
decl_(sig(N, Ty)) --> tok(id(N)), tok(op(:)), type(Ty).
decl_(fun(N, Args, E)) --> tok(id(N)), fun_args(Args), tok(op(=)), expr(E).

deriving --> ( [t(sep, _, _, _)], tok(kw(deriving)) -> rest_of_item(_) ; tok(kw(deriving)) -> rest_of_item(_) ; [] ).

fun_args([A|As]) --> tok(id(A)), !, fun_args(As).
fun_args([]) --> [].

%   The rest of an item: its tokens up to the next `;` at this level.
rest_of_item([T|Ts]) --> [T], { T = t(K, _, _, _), \+ separator(K), K \== vc }, !,
    ( { K == vo } -> nested_rest(Ns), { append(Ns, Ts0, Ts) }, rest_of_item(Ts0) ; rest_of_item(Ts) ).
rest_of_item([]) --> [].

nested_rest([T|Ts]) --> [T], { T = t(vc, _, _, _) }, !, { Ts = [] }.
nested_rest([T|Ts]) --> [T], { T = t(vo, _, _, _) }, !, nested_rest(Ns), { append(Ns, Ts1, Ts) }, nested_rest(Ts1).
nested_rest([T|Ts]) --> [T], nested_rest(Ts).

item_text(O0, Ts, Text) :-
    b_getval(daml_source_text, Src),
    (   last(Ts, t(_, _, _, O1)), O1 > 0 -> true ; O1 = O0 ),
    ( sub_string(Src, O1, _, 0, After), sub_string(After, B, _, _, "\n") -> E is O1 + B ; string_length(Src, E) ),
    Len is E - O0, sub_string(Src, O0, Len, _, Text).

block_fields(Fs) --> tok(vo), items(field_decl, Fs0), tok(vc), { append(Fs0, Fs) }.
field_decl(Fs) --> names(Ns), tok(op(:)), type(Ty), ( tok(kw(deriving)) -> rest_of_item(_) ; [] ),
    { findall(N-Ty, member(N, Ns), Fs) }.
names([N|Ns]) --> tok(id(N)), ( tok(p(',')) -> names(Ns) ; { Ns = [] } ).

%   Types, as terms: con(Name, Args) | list(Ty) | tuple(Tys) | unit.
type(Ty) --> type_app(Ty0), ( tok(op('->')) -> type(R), { Ty = fun(Ty0, R) } ; { Ty = Ty0 } ).
type_app(Ty) --> type_atom(A), type_args(As), { A = con(N, []), As \== [] -> Ty = con(N, As) ; Ty = A }.
type_args([A|As]) --> type_atom(A), !, type_args(As).
type_args([]) --> [].
type_atom(con(N, [])) --> tok(con(N)).
type_atom(var(N)) --> tok(id(N)).
type_atom(unit) --> tok(p('(')), tok(p(')')), !.
type_atom(T) --> tok(p('(')), type(T1), ( tok(p(',')) -> types(Ts), { T = tuple([T1|Ts]) } ; { T = T1 } ), tok(p(')')).
type_atom(list(T)) --> tok(p('[')), type(T), tok(p(']')).
types([T|Ts]) --> type(T), ( tok(p(',')) -> types(Ts) ; { Ts = [] } ).

%   A template's body.
tbody(Items) --> tok(vo), items(tdecl, Items0), tok(vc), { exclude(==(skip), Items0, Items) }.

tdecl(D) --> tdecl_(D).
tdecl(other(Kind, Text)) --> [t(T0, _, _, O0)], rest_of_item(Ts), { item_text(O0, Ts, Text), kind_of(T0, Kind) }.

tdecl_(signatory(Es)) --> tok(kw(signatory)), exprs(Es).
tdecl_(observer(Es)) --> tok(kw(observer)), exprs(Es).
tdecl_(ensure(E)) --> tok(kw(ensure)), expr(E).
tdecl_(choice(Kind, N, Ty, Args, Ctrl, Body)) -->
    consuming(Kind), tok(kw(choice)), tok(con(N)), tok(op(:)), type(Ty),
    ( tok(kw(with)) -> block_fields(Args) ; { Args = [] } ),
    tok(kw(controller)), { b_setval(daml_nodo, true) }, exprs(Ctrl), { b_setval(daml_nodo, false) },
    tok(kw(do)), stmts(Body).

consuming(K) --> tok(kw(K)), { memberchk(K, [nonconsuming, preconsuming, postconsuming]) }, !.
consuming(consuming) --> [].

exprs([E|Es]) --> expr(E), ( tok(p(',')) -> exprs(Es) ; { Es = [] } ).

%   A do block: statements.
stmts(Ss) --> tok(vo), !, items(stmt, Ss0), tok(vc), { exclude(==(skip), Ss0, Ss) }.
stmts([S]) --> stmt(S).

stmt(let(Bs)) --> tok(kw(let)), tok(vo), items(binding, Bs), tok(vc), !.
stmt(bind(P, E)) --> pattern(P), tok(op('<-')), !, expr(E).
stmt(expr(E)) --> expr(E).

binding(N-E) --> tok(id(N)), fun_args(As), tok(op(=)), expr(E0), { As == [] -> E = E0 ; E = lambda(As, E0) }.

pattern(as(N, P)) --> tok(id(N)), tok(op('@')), !, pattern(P).        % setupResult@(alice, ...)
pattern(var(N)) --> tok(id(N)).
pattern(wild) --> tok(id('_')).
pattern(tuple(Ps)) --> tok(p('(')), patterns(Ps), tok(p(')')).
pattern(list(Ps)) --> tok(p('[')), patterns(Ps), tok(p(']')).
pattern(con(C, Ps)) --> tok(con(C)), pattern_args(Ps).
patterns([P|Ps]) --> pattern(P), ( tok(p(',')) -> patterns(Ps) ; { Ps = [] } ).
pattern_args([P|Ps]) --> pattern(P), !, pattern_args(Ps).
pattern_args([]) --> [].

		 /*******************************
		 *          EXPRESSIONS         *
		 *******************************/

expr(E) --> op_expr(0, E).

%   Precedence climbing: level(Op, Prec, Assoc).
level('$', 0, right).
level('||', 2, right).
level('&&', 3, right).
level(Op, 4, none) :- memberchk(Op, ['==', '/=', '<', '<=', '>', '>=', '===', '=/=']).   % (=== : DA.Assert)
level(Op, 5, right) :- memberchk(Op, ['<>', '++', '::']).
level(Op, 6, left) :- memberchk(Op, ['+', '-']).
level(Op, 7, left) :- memberchk(Op, ['*', '/']).

op_expr(Min, E) --> unary(L), op_rest(Min, L, E).

op_rest(Min, L, E) -->                       % a function in backquotes: infixl 9
    { Min =< 9 }, [t(p('`'), _, _, _), t(id(F), _, _, _), t(p('`'), _, _, _)], !,
    op_expr(10, R), op_rest(Min, app(var(F), [L, R]), E).
op_rest(Min, L, E) -->
    peek_op(Op, P, A), { P >= Min }, !, tok(_),
    { ( A == left ; A == none ) -> P1 is P + 1 ; P1 = P },
    op_expr(P1, R), { L1 = op(Op, L, R) }, op_rest(Min, L1, E).
op_rest(_, E, E) --> [].

peek_op(Op, P, A), [t(T, L, C, O)] --> [t(T, L, C, O)], { T = op(Op), level(Op, P, A) }.

unary(neg(E)) --> tok(op('-')), !, application(E).
unary(E) --> application(E).

application(E) --> aexpr(F), args(As), { As == [] -> E0 = F ; E0 = app(F, As) }, record_update(E0, E).

record_update(E0, rec(E0, Fs)) --> tok(kw(with)), !, rec_fields(Fs).
record_update(E, E) --> [].

args([A|As]) --> app_arg(A), !, args(As).
args([]) --> [].

%   `with` binds tighter than application: `create this with owner = o` is
%   `create (this with owner = o)`.
app_arg(E) --> aexpr(E0), record_update_arg(E0, E).
record_update_arg(E0, rec(E0, Fs)) --> tok(kw(with)), !, rec_fields(Fs).
record_update_arg(E, E) --> [].

%   `C with f = e` and `this with f = e` (a block of field bindings, or one
%   on the line); a field alone is a pun (`with issuer` = issuer = issuer).
rec_fields(Fs) --> tok(vo), items(rec_field, Fs), tok(vc).
rec_field(F-E) --> tok(id(F)), ( tok(op(=)) -> expr(E) ; { E = var(F) } ).

aexpr(E) --> atom_expr(E0), fields(E0, E).

fields(E0, E) --> dot_field(F), !, fields(field(E0, F), E).
fields(E, E) --> [].

%   `iou.owner`: a dot with no space on either side.
dot_field(F), [] --> [t(op('.'), L, C, _), t(id(F), L, C1, _)], { C1 =:= C + 1 }.

atom_expr(var(N)) --> tok(id(N)).
atom_expr(var(K)) --> tok(kw(K)), { memberchk(K, [signatory, observer]) }.   % `signatory iou`: a function too
atom_expr(this) --> tok(kw(this)).
atom_expr(con(N)) --> tok(con(N)).
atom_expr(num(N)) --> tok(num(N)).
atom_expr(str(S)) --> tok(str(S)).
atom_expr(tyapp(T)) --> tok(op('@')), type_atom(T).
atom_expr(unit) --> tok(p('(')), tok(p(')')), !.
atom_expr(section(F)) --> tok(p('(')), tok(op('.')), tok(id(F)), tok(p(')')), !.
atom_expr(E) --> tok(p('(')), expr(E1), ( tok(p(',')) -> exprs(Es), { E = tuple([E1|Es]) } ; { E = E1 } ), tok(p(')')).
atom_expr(list(Es)) --> tok(p('[')), ( tok(p(']')) -> { Es = [] } ; exprs(Es), tok(p(']')) ).
atom_expr(do(Ss)) --> { \+ nb_current(daml_nodo, true) }, tok(kw(do)), stmts(Ss).   % (not after `controller p`)
atom_expr(if(C, T, E)) --> tok(kw(if)), expr(C), tok(kw(then)), expr(T), ( [t(sep, _, _, _)] -> [] ; [] ), tok(kw(else)), expr(E).

		 /*******************************
		 *            PRINTING          *
		 *******************************/

%   An expression as Daml text, for notes and residue.
expr_text(E, T) :- with_output_to(string(T), pe(E)).

pe(var(N)) :- write(N).
pe(con(N)) :- write(N).
pe(this) :- write(this).
pe(num(N)) :- write(N).
pe(str(S)) :- format("~q", [S]).
pe(unit) :- write('()').
pe(neg(E)) :- write('-'), pe(E).
pe(field(E, F)) :- pe(E), write('.'), write(F).
pe(op(Op, L, R)) :- write('('), pe(L), format(" ~w ", [Op]), pe(R), write(')').
pe(app(F, As)) :- pe(F), forall(member(A, As), ( write(' '), pe(A) )).
pe(rec(E, Fs)) :- pe(E), write(' with '), foldl([F-V, S0, S]>>( ( S0 == first -> true ; write('; ') ), format("~w = ", [F]), pe(V), S = next ), Fs, first, _).
pe(tuple(Es)) :- write('('), foldl([E, S0, S]>>( ( S0 == first -> true ; write(', ') ), pe(E), S = next ), Es, first, _), write(')').
pe(list(Es)) :- write('['), foldl([E, S0, S]>>( ( S0 == first -> true ; write(', ') ), pe(E), S = next ), Es, first, _), write(']').
pe(tyapp(T)) :- format("@~q", [T]).
pe(do(_)) :- write('do ...').
pe(if(C, T, E)) :- write('if '), pe(C), write(' then '), pe(T), write(' else '), pe(E).
pe(section(F)) :- format("(.~w)", [F]).
pe(lambda(As, E)) :- format("\\~w -> ", [As]), pe(E).
pe(X) :- \+ memberchk(X, []), format("~q", [X]).

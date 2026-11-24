/** <module> The L4 reader: L4 text → a Prolog model

    Step 1 of the design notes l4.md (§6): a reader of L4's text written in
    Prolog, so that it runs wherever LE2 runs. It follows the parser of L4's
    own implementation (jl4-core/src/L4/Parser.hs of smucclaw/l4-ide at
    commit 5e082cf, Copyright 2025 Singapore Management University,
    Apache-2.0) construct by
    construct, including its use of indentation: a construct's parts must
    start to the right of the column where the construct started, lists of
    things (parameters, fields, branches, events) are one per line at the
    same column or separated by commas, and the operators of an expression
    that is spread over several lines group by their columns — an operator
    further to the right binds more tightly (Parser.hs `combine`).

    The model is documented in README.md ("The model"), which is the
    interface for the steps that write the twins. In short:

        l4_module(Items, Issues)

    where each item is one of

        section(Level, Name, Aka, pos(L1, L2))
        import(Name, pos(L1, L2))
        timezone(Expr, pos(L1, L2))
        declare(Sig, AppForm, TypeDecl, Anns, pos(L1, L2))
        decide(Kind, Sig, AppForm, Expr, Anns, pos(L1, L2))     Kind = decide | means
        assume(Sig, AppForm, Type, Anns, pos(L1, L2))           Type = none if not given
        directive(Directive, Anns, pos(L1, L2))
        unparsed(Text, Reason, pos(L1, L2))

    and Issues lists what the reader could not read (also as `unparsed`
    items, in place), so that nothing is dropped silently.

    Mixfix names (a function whose name is split around its inputs,
    `` p `is eligible for` q ``) are recognised in expressions with a
    registry of the program's own mixfix definitions, made by a first
    reading of the program, as L4's parser does with its "mixfix hints".
*/

:- module(l4_reader, [l4_read_file/2, l4_read_text/2, l4_read_text/3,
                      l4_mixfix_signature/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).
:- use_module(l4_lex).

:- thread_local mixfix_kw/1, mixfix_postfix/1.

%!  l4_read_file(+File, -Model) is det.
l4_read_file(File, Model) :-
    read_file_to_string(File, Text, [encoding(utf8)]),
    l4_read_text(Text, Model).

%!  l4_read_text(+Text, -Model) is det.
l4_read_text(Text, Model) :-
    l4_read_text(Text, Model, []).

%!  l4_read_text(+Text, -Model, +Options) is det.
%
%   Options: registry(Items) — mixfix definitions to know besides the
%   program's own (the items of an imported module, say).
l4_read_text(Text, Model, Options) :-
    once(read_text_(Text, Model, Options)).

read_text_(Text, l4_module(Items, Issues), Options) :-
    catch(l4_tokens(Text, Toks0), error(l4_lex(L, C, Near), _),
          ( Items = [unparsed(Near, lexer(L, C), pos(L, L))], Issues = Items, Toks0 = none )),
    (   Toks0 == none
    ->  true
    ;   split_annotations(Toks0, Toks, Anns),
        option_items(Options, Extra),
        % First reading: find the mixfix definitions.
        retractall(mixfix_kw(_)), retractall(mixfix_postfix(_)),
        program(Toks, Items0),
        append(Extra, Items0, ForRegistry),
        register_mixfix(ForRegistry),
        % Second reading, with the registry.
        program(Toks, Items1),
        attach_annotations(Items1, Anns, Items),
        include([I]>>(I = unparsed(_, _, _)), Items, Issues),
        retractall(mixfix_kw(_)), retractall(mixfix_postfix(_))
    ).

option_items(Options, Items) :-
    (   memberchk(registry(Items), Options) -> true ; Items = [] ).

split_annotations([], [], []).
split_annotations([tok(ann(K), V, L, C, _, _)|Ts], Toks, [ann(K, V, L, C)|As]) :- !,
    split_annotations(Ts, Toks, As).
split_annotations([T|Ts], [T|Toks], As) :-
    split_annotations(Ts, Toks, As).

% ---------------------------------------------------------------------------
% Token access

tl(tok(_, _, L, _, _, _), L).
tc(tok(_, _, _, C, _, _), C).

peek(T, [T|Ts], [T|Ts]).

%   The column of the next token is greater than (equal to) P.
col_gt(P, S, S) :- S = [T|_], tc(T, C), C > P.
col_eq(P, S, S) :- S = [T|_], tc(T, C), C =:= P.
indent(C, S, S) :- S = [T|_], tc(T, C).
line(L, S, S) :- S = [T|_], tl(T, L).
last_line(L, S, S) :- ( S = [T|_] -> tl(T, L) ; L = 1000000000 ).

kw(K) --> [tok(kw(K), _, _, _, _, _)].
sym(S) --> [tok(sym, S, _, _, _, _)].
opr(O) --> [tok(op, O, _, _, _, _)].

name(N) --> [tok(K, N, _, _, _, _)], { K == id ; K == q }.
name_pos(N, L, C) --> [tok(K, N, L, C, _, _)], { K == id ; K == q }.

next_is_kw(K, S, S) :- S = [tok(kw(K), _, _, _, _, _)|_].

% ---------------------------------------------------------------------------
% Layout-driven lists (Parser.hs lmany / lsepBy / lsepBy1)

%   lsep(:PP, +Sep, -Xs): groups, each starting at the column of the first,
%   each a Sep-separated list of PP(Column).
lsep(PP, Sep, Xs) --> indent(C), !, lsep_groups(C, PP, Sep, Xss), { append(Xss, Xs) }.
lsep(_, _, []) --> [].

lsep_groups(C, PP, Sep, [G|Gs]) --> col_eq(C), sep_by1(PP, C, Sep, G), !, lsep_groups(C, PP, Sep, Gs).
lsep_groups(_, _, _, []) --> [].

lsep1(PP, Sep, Xs) --> lsep(PP, Sep, Xs), { Xs \== [] }.

sep_by1(PP, C, Sep, [X|Xs]) --> call(PP, C, X), sep_rest(PP, C, Sep, Xs).
sep_rest(PP, C, Sep, [X|Xs]) --> sym(Sep), call(PP, C, X), !, sep_rest(PP, C, Sep, Xs).
sep_rest(_, _, _, []) --> [].

lmany(PP, Xs) --> indent(C), !, lmany_groups(C, PP, Xss), { append(Xss, Xs) }.
lmany(_, []) --> [].

lmany_groups(C, PP, [G|Gs]) --> col_eq(C), some(PP, C, G), !, lmany_groups(C, PP, Gs).
lmany_groups(_, _, []) --> [].

some(PP, C, [X|Xs]) --> call(PP, C, X), many(PP, C, Xs).
many(PP, C, [X|Xs]) --> call(PP, C, X), !, many(PP, C, Xs).
many(_, _, []) --> [].

% ---------------------------------------------------------------------------
% The program

program(Toks, Items) :-
    items(Toks, 0, Items).

%   items(+Toks, +SectionLevel, -Items)
items([], _, []) :- !.
items(Toks, Lvl, [Item|Items]) :-
    Toks = [T0|_], tl(T0, L1),
    (   section_header(Level, Name, Aka, Toks, Rest)
    ->  Item = section(Level, Name, Aka, pos(L1, L2))
    ;   topdecl(Item0, Toks, Rest)
    ->  Item0 =.. Args0, append(ArgsA, [_], Args0), append(ArgsA, [pos(L1, L2)], ArgsB), Item =.. ArgsB
    ;   recover(Toks, Skipped, Rest),
        tokens_text(Skipped, Text),
        Item = unparsed(Text, parse, pos(L1, L2))
    ),
    before_line(Toks, Rest, L2),
    ( Rest = [tok(sym, ';', _, _, _, _)|Rest1] -> true ; Rest1 = Rest ),
    items(Rest1, Lvl, Items).

%   The line of the last token of Toks before Rest.
before_line(Toks, Rest, L) :-
    last_before(Toks, Rest, none, T),
    (   T == none -> Toks = [T1|_], tl(T1, L)
    ;   T = tok(_, _, _, _, L0, C0), ( C0 =:= 1, L0 > 1 -> L is L0 - 1 ; L = L0 )
    ).

last_before(Ts, Rest, Last, Last) :- same_term(Ts, Rest), !.
last_before([], _, Last, Last) :- !.
last_before([T|Ts], Rest, _, Last) :- last_before(Ts, Rest, T, Last).

%   Parser.hs topdeclWithRecovery: skip the first token, then every token
%   not at column 1.
recover([T|Ts], [T|Skipped], Rest) :-
    skip_indented(Ts, Skipped, Rest).
skip_indented([T|Ts], [T|Sk], Rest) :- tc(T, C), C > 1, !, skip_indented(Ts, Sk, Rest).
skip_indented(Ts, [], Ts).

tokens_text(Toks, Text) :-
    maplist([tok(_, V, _, _, _, _), S]>>format(string(S), "~w", [V]), Toks, Ss),
    atomic_list_concat(Ss, ' ', A),
    atom_string(A, Text).

section_header(Level, Name, Aka) -->
    section_symbols(0, Level), { Level > 0 },
    ( name(Name) -> [] ; { Name = none } ),
    ( aka(Aka) -> [] ; { Aka = [] } ).

section_symbols(N0, N) --> sym('§'), !, { N1 is N0 + 1 }, section_symbols(N1, N).
section_symbols(N, N) --> [].

topdecl(timezone(E, _)) -->
    [tok(id, 'TIMEZONE', _, _, _, _)], kw('IS'), !, expr(E).
topdecl(Item) -->
    type_sig(Sig),
    (   declare(Sig, Item) -> []
    ;   decide(Sig, Item) -> []
    ;   assume(Sig, Item) -> []
    ;   { Sig == sig([], none) }, directive(Item) -> []
    ;   { Sig == sig([], none) }, import(Item)
    ).

import(import(N, _)) --> kw('IMPORT'), name(N).

% ---------------------------------------------------------------------------
% Signatures, declarations

type_sig(sig(Givens, Giveth)) -->
    ( givens(Givens) -> [] ; { Givens = [] } ),
    ( giveth(Giveth) -> [] ; { Giveth = none } ).

givens(Ps) --> kw('GIVEN'), lsep(param, ',', Ps).

param(_, param(N, Type, pos(L, C))) -->
    name_pos(N, L, C),
    ( separator, type(Type) -> [] ; { Type = none } ).

separator --> kw('IS'), !.
separator --> sym(':').

giveth(T) --> ( kw('GIVETH') ; kw('GIVES') ), type(T).

declare(Sig, declare(Sig, AF, TD, [], _)) -->
    kw('DECLARE'), appform(AF), type_decl(TD).

type_decl(record(Fs)) --> kw('HAS'), !, lsep(req_param, ',', Fs).
type_decl(TD) --> kw('IS'),
    (   kw('ONE'), kw('OF') -> lsep(con_decl, ',', Cs), { TD = enum(Cs) }
    ;   type(T), { TD = synonym(T) }
    ).
type_decl(record([])) --> [].

con_decl(_, con(N, Fs)) --> name(N), ( kw('HAS') -> lsep(req_param, ',', Fs) ; { Fs = [] } ).

req_param(_, field(N, T, Computed, pos(L, C))) -->
    name_pos(N, L, C), separator, type(T),
    ( kw('MEANS') -> indented_expr(C, E), { Computed = E } ; { Computed = none } ).

decide(Sig, decide(decide, Sig, AF, E, [], _)) -->
    indent(C), kw('DECIDE'), !, appform(AF), ( kw('IS') ; kw('IF') ), indented_expr(C, E).
decide(Sig, decide(means, Sig, AF, E, [], _)) -->
    indent(C), appform(AF), kw('MEANS'), indented_expr(C, E).

assume(Sig, assume(Sig, AF, T, [], _)) -->
    indent(C), kw('ASSUME'), appform(AF),
    ( kw('IS') -> col_gt(C), type(T) ; { T = none } ).

appform(appform(N, Args, Aka, pos(L, C))) -->
    name_pos(N, L, C),
    (   kw('OF') -> sep_by1_simple(name, ',', Args)
    ;   lmany(af_name(C), Args)
    ),
    ( aka(Aka) -> [] ; { Aka = [] } ).

aka(Ns) --> kw('AKA'), lsep(any_name, ',', Ns).

af_name(C, _, X) --> col_gt(C), name(X).
any_name(_, N) --> name(N).
ie(C, _, X) --> indented_expr(C, X).
ty_gt(C, _, X) --> col_gt(C), type(X).
ty_gt(C, X) --> col_gt(C), type(X).
aty_gt(C, _, X) --> col_gt(C), atomic_type(X).
any_expr(_, E) --> expr(E).
any_branch(_, B) --> branch(B).
pat_b(C, _, X) --> col_gt(C), base_pattern(X).
pat_a(C, _, X) --> col_gt(C), atomic_pattern(X).

sep_by1_simple(P, Sep, [X|Xs]) --> call(P, X), ( sym(Sep) -> sep_by1_simple(P, Sep, Xs) ; { Xs = [] } ).

% ---------------------------------------------------------------------------
% Types (Parser.hs type')

type(T) --> kw('FOR'), kw('ALL'), !, sep_by1_kw(name, 'AND', Ns), type(T0), { T = forall(Ns, T0) }.
type(T) --> sym('('), !, type(T), sym(')').
type(T) --> opt_article, type_(T).

type_(type) --> kw('TYPE'), !.
type_(fun(As, R)) --> kw('FUNCTION'), !, indent(C), kw('FROM'),
    sep_by1_kw(ty_gt(C), 'AND', As), kw('TO'), col_gt(C), type(R).
type_(T) --> indent(C), ty_head(N),
    (   kw('OF') -> lsep1(ty_gt(C), ',', Args)
    ;   lmany(aty_gt(C), Args)
    ),
    { T = tyapp(N, Args) }.

ty_head('LIST') --> kw('LIST'), !.
ty_head(N) --> name(N).

atomic_type(T) --> sym('('), !, type(T), sym(')').
atomic_type(T) --> opt_article, ( kw('TYPE') -> { T = type } ; name(N), { T = tyapp(N, []) } ).

opt_article --> ( kw('A') ; kw('AN') ; kw('THE') ), !.
opt_article --> [].

sep_by1_kw(P, K, [X|Xs]) --> call(P, X), ( kw(K) -> sep_by1_kw(P, K, Xs) ; { Xs = [] } ).

% ---------------------------------------------------------------------------
% Directives

directive(directive(D, [], _)) -->
    [tok(dir, K, L, _, _, _)], { K \== cont },
    directive_(K, L, D).

directive_(eval, L, eval(E)) --> single_line_expr(L, E).
directive_(evaltrace, L, evaltrace(E)) --> single_line_expr(L, E).
directive_(check, L, check(E)) --> single_line_expr(L, E).
directive_(assert, L, assert(E)) --> single_line_expr(L, E).
directive_(trace, L, trace(C, At, Events)) -->
    single_line_expr(L, C),
    ( kw('STARTING') -> [] ; [] ),
    kw('AT'), line(L2), single_line_expr(L2, At),
    kw('WITH'),
    lmany(any_expr, Events).

%   Parser.hs singleLineExpr: operators continue only on the start line, or
%   after a `# ` continuation.
single_line_expr(L, E) -->
    mixfix_chain(E0), sl_conts(L, Cs), { combine(end, L, E0, Cs, E) }.

sl_conts(L, [C|Cs]) --> sl_cont(L, C), !, sl_conts(L, Cs).
sl_conts(_, []) --> [].

sl_cont(L, c(Op, Pr, As, L2, P, Arg)) -->
    (   [tok(dir, cont, _, _, _, _)] -> []
    ;   line(L0), { L0 =:= L }
    ),
    indent(P), operator(Pr, As, Op), line(L2), base_expr(Arg).

% ---------------------------------------------------------------------------
% Expressions

expr(E) --> indented_expr(1, E).

%   Parser.hs indentedExpr: the first token to the right of P; operators
%   (continuations) too; an optional WHERE.
indented_expr(P, E) -->
    col_gt(P), line(L),
    mixfix_chain(E0),
    conts(P, Cs),
    { combine(end, L, E0, Cs, E1) },
    (   where_expr(P, E1, E2) -> { E = E2 } ; { E = E1 } ).

where_expr(P, E, where(E, Ds)) -->
    col_gt(P), kw('WHERE'),
    many_local(P, Ds).

many_local(P, [D|Ds]) --> col_gt(P), local_decl(D), !, many_local(P, Ds).
many_local(_, []) --> [].

local_decl(D) -->
    line(L1), type_sig(Sig),
    (   decide(Sig, D0) -> [] ; assume(Sig, D0) ),
    { D0 =.. Args0, append(ArgsA, [_], Args0), append(ArgsA, [pos(L1, L1)], ArgsB), D =.. ArgsB }.

conts(P, [C|Cs]) --> cont(P, C), !, conts(P, Cs).
conts(_, []) --> [].

cont(P, c(Op, Pr, As, L2, Pos, Arg)) -->
    col_gt(P), indent(Pos), operator(Pr, As, Op), line(L2), base_expr(Arg).

%   Parser.hs operator: priority, associativity, the model's functor.
operator(1, r, implies) --> ( kw('IMPLIES') ; opr('=>') ), !.
operator(1, r, unless) --> kw('UNLESS'), !.
operator(2, r, or) --> ( kw('OR') ; opr('||') ; sym('..') ), !.
operator(3, r, and) --> ( kw('AND') ; opr('&&') ; sym('...') ), !.
operator(2, r, ror) --> kw('ROR'), !.
operator(3, r, rand) --> kw('RAND'), !.
operator(4, r, eq) --> ( kw('EQUALS') ; opr('=') ), !.
operator(4, r, leq) --> ( kw('AT'), kw('MOST') ; opr('<=') ), !.
operator(4, r, geq) --> ( kw('AT'), kw('LEAST') ; opr('>=') ), !.
operator(4, r, lt) --> ( kw('LESS'), kw('THAN') ; kw('BELOW') ; opr('<') ), !.
operator(4, r, gt) --> ( kw('GREATER'), kw('THAN') ; kw('ABOVE') ; opr('>') ), !.
operator(5, r, cons) --> kw('FOLLOWED'), kw('BY'), !.
operator(6, l, plus) --> ( kw('PLUS') ; opr('+') ), !.
operator(6, l, minus) --> ( kw('MINUS') ; opr('-') ), !.
operator(7, l, times) --> ( kw('TIMES') ; opr('*') ), !.
operator(7, l, div) --> ( kw('DIVIDED'), kw('BY') ; opr('/') ), !.
operator(7, l, mod) --> kw('MODULO'), !.

%   Parser.hs combine: operators on one line (or all at one column) follow
%   their priorities; otherwise an operator further right binds tighter.
combine(end, _, E, [], E) :- !.
combine(frame(S, E1, Op, _, _, L1, _), _, E2, [], E) :- !,
    mk_op(Op, E1, E2, E3), combine(S, L1, E3, [], E).
combine(end, L1, E1, [c(Op, Pr, As, L2, P2, E2)|Cs], E) :- !,
    combine(frame(end, E1, Op, Pr, As, L1, P2), L2, E2, Cs, E).
combine(S1, L, E2, [C|Cs], E) :-
    S1 = frame(S, E1, Op1, Pr1, As1, L1, P1),
    C = c(Op2, Pr2, As2, L2, P2, E3),
    (   stronger(L2, P2, Pr2, As2, L1, P1, Pr1, As1)
    ->  combine(frame(S1, E2, Op2, Pr2, As2, L, P2), L2, E3, Cs, E)
    ;   mk_op(Op1, E1, E2, E12), combine(S, L1, E12, [C|Cs], E)
    ).

stronger(Ly, Py, Pry, Asy, Lx, Px, Prx, Asx) :-
    (   Lx =:= Ly -> prio_stronger(Pry, Asy, Prx, Asx)
    ;   Py > Px -> true
    ;   Py =:= Px, prio_stronger(Pry, Asy, Prx, Asx)
    ).

prio_stronger(Pry, Asy, Prx, Asx) :-
    (   Pry > Prx -> true
    ;   Pry =:= Prx -> \+ ( Asx == l, Asy == l )
    ;   fail
    ).

mk_op(unless, A, B, and(A, not(B))) :- !.
mk_op(Op, A, B, E) :- E =.. [Op, A, B].

%   Parser.hs mixfixChainExpr: a base expression followed by keywords of a
%   mixfix name and their arguments.
mixfix_chain(E) -->
    indent(C0), line(L0), base_expr(E0),
    (   mixfix_pairs(C0, L0, Pairs), { Pairs \== [] }
    ->  { E = mixfix([arg(E0)|Pairs]) }
    ;   { E = E0 }
    ).

mixfix_pairs(C0, L0, [kw(K), arg(A)|More]) -->
    mixfix_keyword(C0, L0, K), base_expr(A), !,
    ( mixfix_pairs(C0, L0, More) -> [] ; { More = [] } ).

mixfix_keyword(C0, L0, K, S0, S) :-
    S0 = [T|S], T = tok(Kind, K, L, C, _, _), ( Kind == id ; Kind == q ),
    (   mixfix_kw(K)
    ->  ( L =:= L0 ; C =:= C0 ; true )
    ;   \+ mixfix_kw(_), Kind == q, L =:= L0
    ).

base_expr(E) -->
    line(L), base_expr_(E0), postfixes(L, E0, E).

%   Postfix operators: `%`, `AS STRING`, and a mixfix postfix name on the
%   same line that is not followed by an expression on that line.
postfixes(L, E0, E) --> sym('%'), !, postfixes(L, percent(E0), E).
postfixes(L, E0, E) --> kw('AS'), !, opt_article, name(T), postfixes(L, as(E0, T), E).
postfixes(L, E0, E) -->
    [tok(K, N, L2, _, _, _)],
    { ( K == id ; K == q ), ( mixfix_postfix(N) ; K == q, \+ mixfix_kw(N) ), L2 =:= L },
    \+ same_line_expr(L), !,
    postfixes(L, app(N, [E0]), E).
postfixes(_, E, E) --> [].

same_line_expr(L) --> [T], { tl(T, L2), L2 =:= L, starts_expr(T) }.

starts_expr(tok(K, _, _, _, _, _)) :- memberchk(K, [id, q, num, str]).
starts_expr(tok(sym, '(', _, _, _, _)).

base_expr_(E) --> projection(E), !.
base_expr_(not(E)) --> indent(C), kw('NOT'), !, ( kw('OF') -> [] ; [] ), indented_expr(C, E).
base_expr_(fetch(E)) --> indent(C), kw('FETCH'), !, indented_expr(C, E).
base_expr_(env(E)) --> indent(C), kw('ENV'), !, indented_expr(C, E).
base_expr_(post(A, B, D)) --> indent(C), kw('POST'), !, indented_expr(C, A), indented_expr(C, B), indented_expr(C, D).
base_expr_(concat(Es)) --> indent(C), kw('CONCAT'), !, lsep(ie(C), ',', Es).
base_expr_(if(Cond, Then, Else)) --> indent(C), kw('IF'), !,
    indented_expr(C, Cond), kw('THEN'), indented_expr(C, Then), kw('ELSE'), indented_expr(C, Else).
base_expr_(branch(Gs, Other)) --> indent(C), kw('BRANCH'), !,
    many_guarded(C, Gs), col_gt(C), kw('OTHERWISE'), indented_expr(C, Other).
base_expr_(E) --> event(E), !.
base_expr_(E) --> regulative(E), !.
base_expr_(breach(By, Because)) --> indent(C), kw('BREACH'), !,
    ( kw('BY') -> indented_expr(C, By) ; { By = none } ),
    ( kw('BECAUSE') -> indented_expr(C, Because) ; { Because = none } ).
base_expr_(lam(Ps, E)) --> indent(C), givens(Ps), !, kw('YIELD'), indented_expr(C, E).
base_expr_(consider(E, Bs)) --> indent(C), kw('CONSIDER'), !, indented_expr(C, E), lsep(any_branch, ',', Bs).
base_expr_(E) --> named_app(E), !.
base_expr_(E) --> app(E), !.
base_expr_(E) --> lit(E), !.
base_expr_(list(Es)) --> indent(C), kw('LIST'), !, lsep(ie(C), ',', Es).
base_expr_(E) --> let_in(E), !.
base_expr_(E) --> sym('('), expr(E), sym(')').

many_guarded(C, [G|Gs]) --> col_gt(C), guarded(C, G), !, many_guarded(C, Gs).
many_guarded(_, []) --> [].
guarded(C, Cond-E) --> kw('IF'), indented_expr(C, Cond), col_gt(C), kw('THEN'), indented_expr(C, E).

branch(when(P, E)) --> indent(C), kw('WHEN'), !, indented_pattern(C, P), kw('THEN'), indented_expr(C, E).
branch(otherwise(E)) --> indent(C), kw('OTHERWISE'), indented_expr(C, E).

lit(num(N)) --> [tok(num, N, _, _, _, _)], !.
lit(str(S)) --> [tok(str, S, _, _, _, _)].

projection(E) -->
    atomic_expr(A), [tok(gen, _, _, _, _, _)], name(F),
    more_proj(proj(A, F), E).
more_proj(E0, E) --> [tok(gen, _, _, _, _, _)], !, name(F), more_proj(proj(E0, F), E).
more_proj(E, E) --> [].

atomic_expr(E) --> lit(E), !.
atomic_expr(app(N, [])) --> name(N), !.
atomic_expr(E) --> sym('('), expr(E), sym(')').

%   Parser.hs app: a name, then OF and comma-separated arguments, or
%   arguments by juxtaposition, each to the right of the name's column.
app(app(N, Args)) -->
    indent(C), [T], { T = tok(K, N, L, _, _, _), ( K == id ; K == q ) },
    (   kw('OF') -> lsep1(ie(C), ',', Args)
    ;   app_args(C, L, true, Args)
    ).

app_args(C, L, First, [A|As]) -->
    ( { First == true } -> \+ mixfix_keyword_on(L) ; [] ),
    col_gt(C), atomic_expr(A), !,
    app_args(C, L, false, As).
app_args(_, _, _, []) --> [].

mixfix_keyword_on(L, S, S) :-
    S = [tok(K, N, L2, _, _, _)|_], ( K == id ; K == q ), L2 =:= L, mixfix_kw(N).

named_app(app_named(N, Fs)) -->
    name(N), kw('WITH'), lsep1(named_expr, ',', Fs).

named_expr(C, N=E) --> name(N), separator, opt_article, indented_expr(C, E).

let_in(let(Ds, E)) -->
    indent(C), kw('LET'), !,
    many_let(C, Ds), kw('IN'), indented_expr(C, E).

many_let(C, [D|Ds]) --> let_decl(C, D), !, many_let(C, Ds).
many_let(_, []) --> [].

let_decl(C, decide(means, sig([], none), appform(N, Args, [], pos(L, C1)), E, [], pos(L, L))) -->
    col_gt(C), indent(BC), name_pos(N, L, C1),
    lmany(af_name(BC), Args),
    ( kw('IS') ; kw('BE') ; kw('MEAN') ; kw('MEANS') ; opr('=') ),
    ( indented_expr(BC, E) -> [] ; indented_expr(C, E) ).

% ---------------------------------------------------------------------------
% Contracts (Parser.hs event, obligation, must, deadline, hence, lest)

event(event(Party, Action, At)) -->
    kw('PARTY'), expr(Party), kw('DOES'), expr(Action), kw('AT'), expr(At), !.
event(event(Party, Action, At)) -->
    kw('AT'), expr(At), kw('PARTY'), expr(Party), kw('DOES'), expr(Action).

regulative(deontic(Party, Modal, Action, Provided, Within, Hence, Lest)) -->
    indent(C), kw('PARTY'), indented_expr(C, Party),
    modal(Modal), indented_pattern(C, Action),
    ( kw('PROVIDED') -> indented_expr(C, Provided) ; { Provided = none } ),
    ( kw('WITHIN') -> indented_expr(C, Within) ; { Within = none } ),
    ( kw('HENCE') -> indented_expr(C, Hence) ; { Hence = none } ),
    ( kw('LEST') -> indented_expr(C, Lest) ; { Lest = none } ).

modal(M) --> kw('MUST'), !, ( kw('NOT') -> { M = shant } ; { M = must } ), opt_do.
modal(may) --> kw('MAY'), !, opt_do.
modal(shant) --> kw('SHANT'), !, opt_do.
modal(do) --> kw('DO').

opt_do --> kw('DO'), !.
opt_do --> [].

indented_pattern(P, Pat) -->
    col_gt(P), line(L), base_pattern(Pat0), pat_conts(P, Cs),
    { combine(end, L, Pat0, Cs, Pat) }.

pat_conts(P, [c(pcons, 5, r, L, Pos, A)|Cs]) -->
    col_gt(P), indent(Pos), kw('FOLLOWED'), kw('BY'), line(L), base_pattern(A), !,
    pat_conts(P, Cs).
pat_conts(_, []) --> [].

base_pattern(plit(E)) --> lit(E), !.
base_pattern(pexact(E)) --> kw('EXACTLY'), !, expr(E).
base_pattern(papp(N, Ps)) --> indent(C), name(N), !,
    (   kw('OF') -> lsep(pat_b(C), ',', Ps)
    ;   lmany(pat_a(C), Ps)
    ).
base_pattern(P) --> sym('('), indented_pattern(1, P), sym(')').

atomic_pattern(plit(E)) --> lit(E), !.
atomic_pattern(pexact(E)) --> kw('EXACTLY'), !, expr(E).
atomic_pattern(papp(N, [])) --> name(N), !.
atomic_pattern(P) --> sym('('), indented_pattern(1, P), sym(')').

% ---------------------------------------------------------------------------
% The mixfix registry

%   A definition is mixfix when its name is one of its own parameters
%   (`a `plus` b`), or when a parameter comes before a later word of its
%   name. Its keywords are the words of the name that are not parameters.
register_mixfix(Items) :-
    forall(( member(I, Items), item_sig_appform(I, Sig, AF),
             l4_mixfix_signature(Sig, AF, Parts) ),
           register_parts(Parts)).

register_parts(Parts) :-
    forall(member(kw(K), Parts), ( mixfix_kw(K) -> true ; assertz(mixfix_kw(K)) )),
    (   Parts = [param(_), kw(K)] -> ( mixfix_postfix(K) -> true ; assertz(mixfix_postfix(K)) )
    ;   true
    ).

item_sig_appform(decide(_, Sig, AF, _, _, _), Sig, AF).
item_sig_appform(assume(Sig, AF, _, _, _), Sig, AF).

%!  l4_mixfix_signature(+Sig, +AppForm, -Parts) is semidet.
%
%   Parts: the name's words in order, each param(Name) or kw(Word), when
%   the definition is mixfix.
l4_mixfix_signature(sig(Givens, _), appform(N, Args, _, _), Parts) :-
    findall(P, member(param(P, _, _), Givens), Ps),
    Ps \== [],
    Words = [N|Args],
    maplist(mixfix_part(Ps), Words, Parts),
    Parts = [First|_],
    (   First = param(_) -> true
    ;   append(_, [param(_), kw(_)|_], Parts)
    ),
    memberchk(kw(_), Parts).

mixfix_part(Ps, W, X) :- ( memberchk(W, Ps) -> X = param(W) ; X = kw(W) ).

% ---------------------------------------------------------------------------
% Annotations

%   attach_annotations(+Items, +Anns, -Items1): an annotation on a line of
%   its own belongs to the next item; one on a line with an item's tokens
%   belongs to that item (to a parameter or field, when one is on that line).
attach_annotations(Items, Anns, Out) :-
    foldl(attach_one, Anns, Items, Out).

attach_one(ann(K, V, L, _), Items0, Items) :-
    (   nth0(I, Items0, It), item_pos(It, pos(L1, L2)), L >= L1, L =< L2
    ->  true
    ;   nth0(I, Items0, It), item_pos(It, pos(L1, _)), L1 > L
    ->  true
    ;   I = none
    ),
    (   I == none -> Items = Items0
    ;   nth0(I, Items0, It0, Rest), add_ann(It0, a(K, V, L), It1), nth0(I, Items, It1, Rest)
    ).

item_pos(It, P) :- It =.. L, last(L, P), P = pos(_, _).

add_ann(It0, A, It) :-
    It0 =.. [F|Args0],
    (   append(Pre, [Anns0, P], Args0), is_list(Anns0), F \== unparsed, F \== section, F \== import
    ->  append(Anns0, [A], Anns), append(Pre, [Anns, P], Args), It =.. [F|Args]
    ;   It = It0
    ).

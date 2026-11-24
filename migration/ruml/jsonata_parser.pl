/** <module> JSONata → a syntax tree

    RUML writes every expression in JSONata 2.2.0 (`ruml:query`,
    `ruml:expression`, a computed data point). This module reads the part of
    JSONata that a rulemap uses (the design notes ruml.md §4.5) into a term:

        num(N)  str(S)  bool(true|false)  null
        name(N)                       a field of the input: `dp_age`
        var(N)                        a variable: `$children`, `$x`
        path(A, B)                    `A.B`
        filter(A, P)                  `A[P]` (an index when P is a number)
        call(F, Args)                 `$count(x)`; F without the dollar sign
        bin(Op, A, B)                 + - * / % & = != < <= > >= and or in
        neg(A)                        unary minus
        cond(C, T, E)                 `C ? T : E` (E = none when absent)
        array(Items)  object(Key-Value pairs)  block(Exprs)
        unsupported(What)             a construct parsed but not translated
                                      (a function definition, `~>`, `:=`,
                                      a regular expression, `**`, `..`)

    jsonata_parse(+Text, -Tree) fails with an error term when the text is
    not JSONata; jsonata_names(+Tree, -Names) gives the input fields an
    expression reads at its top level (the data point ids, DP-18).
*/

:- module(jsonata_parser, [jsonata_parse/2, jsonata_names/2, jsonata_text/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).

%!  jsonata_parse(+Text, -Tree) is semidet.
jsonata_parse(Text, Tree) :-
    ( string(Text) -> string_codes(Text, Cs) ; atom_codes(Text, Cs) ),
    catch(( phrase(tokens(Ts), Cs), Ts \== [] ), _, fail),
    catch(expr(0, Ts, Tree, []), error(jsonata(_), _), fail), !.

%!  jsonata_text(+Tree, -Text) is det.
%   The tree written back as JSONata (for comments, residue and the way back).
jsonata_text(T, S) :- with_output_to(string(S), wr(T)).

		 /*******************************
		 *           TOKENS             *
		 *******************************/

tokens(Ts) --> ws, ( token(T) -> { Ts = [T|Ts1] }, tokens(Ts1) ; { Ts = [] } ).

ws --> [C], { code_type(C, space) }, !, ws.
ws --> "/*", !, comment_end, ws.
ws --> [].
comment_end --> "*/", !.
comment_end --> [_], comment_end.

token(num(N)) --> digits(D), { D \== [] }, frac(F), exp(E), !,
    { append([D, F, E], Cs), number_codes(N0, Cs), N is N0 }.
token(str(S)) --> "\"", !, str_chars(0'", Cs), { string_codes(S, Cs) }.
token(str(S)) --> "'", !, str_chars(0'', Cs), { string_codes(S, Cs) }.
token(name(N)) --> "`", !, bq_chars(Cs), { atom_codes(N, Cs) }.
token(var(N)) --> "$", name_chars(Cs), !, { atom_codes(N, Cs) }.
token(T) --> name_chars(Cs), { Cs \== [] }, !, { atom_codes(A, Cs), keyword_token(A, T) }.
token(op(Op)) --> op3(Op), !.
token(op(Op)) --> op2(Op), !.
token(op(Op)) --> [C], { memberchk(C, `.[](){},:?;+-*/%&=<>@#^~|!`), atom_codes(Op, [C]) }.

keyword_token(and, op(and)) :- !.
keyword_token(or, op(or)) :- !.
keyword_token(in, op(in)) :- !.
keyword_token(true, bool(true)) :- !.
keyword_token(false, bool(false)) :- !.
keyword_token(null, null) :- !.
keyword_token(function, op(function)) :- !.
keyword_token(A, name(A)).

op3('...') --> "...".
op2('!=') --> "!=".
op2('<=') --> "<=".
op2('>=') --> ">=".
op2(':=') --> ":=".
op2('~>') --> "~>".
op2('**') --> "**".
op2('..') --> "..".
op2('?:') --> "?:".
op2('??') --> "??".

digits([C|Cs]) --> [C], { code_type(C, digit) }, !, digits(Cs).
digits([]) --> [].
frac([0'.|D]) --> ".", digits(D), { D \== [] }, !.
frac([]) --> [].
exp([0'e|Cs]) --> ( "e" ; "E" ), sign(S), digits(D), { D \== [], append(S, D, Cs) }, !.
exp([]) --> [].
sign("-") --> "-", !.
sign([]) --> "+", !.
sign([]) --> [].

str_chars(Q, []) --> [Q], !.
str_chars(Q, [C|Cs]) --> "\\", [E], !, { esc(E, C) }, str_chars(Q, Cs).
str_chars(Q, [C|Cs]) --> [C], str_chars(Q, Cs).
esc(0'n, 0'\n) :- !.
esc(0't, 0'\t) :- !.
esc(0'r, 0'\r) :- !.
esc(C, C).

bq_chars([]) --> "`", !.
bq_chars([C|Cs]) --> [C], bq_chars(Cs).

name_chars([C|Cs]) --> [C], { name_char(C) }, !, name_chars(Cs).
name_chars([]) --> [].
name_char(C) :- code_type(C, csym).
name_char(C) :- C > 127, \+ code_type(C, space).

		 /*******************************
		 *    THE PARSER (Pratt style)   *
		 *******************************/

expr(RBP, Ts0, E, Ts) :-
    prefix(Ts0, L, Ts1),
    infix_loop(RBP, L, Ts1, E, Ts).

infix_loop(RBP, L, [T|Ts0], E, Ts) :-
    lbp(T, LBP), LBP > RBP, !,
    infix(T, L, Ts0, L1, Ts1),
    infix_loop(RBP, L1, Ts1, E, Ts).
infix_loop(_, E, Ts, E, Ts).

lbp(op('.'), 75).
lbp(op('['), 80).
lbp(op('('), 80).
lbp(op('{'), 70).
lbp(op('*'), 60).  lbp(op('/'), 60).  lbp(op('%'), 60).
lbp(op('+'), 50).  lbp(op('-'), 50).  lbp(op('&'), 50).
lbp(op('='), 40).  lbp(op('!='), 40). lbp(op('<'), 40). lbp(op('<='), 40).
lbp(op('>'), 40).  lbp(op('>='), 40). lbp(op(in), 40).  lbp(op('~>'), 40).
lbp(op('**'), 60). lbp(op('..'), 20).
lbp(op(and), 30).  lbp(op(or), 25).
lbp(op('?'), 20).  lbp(op('?:'), 40). lbp(op('??'), 40).
lbp(op(':='), 10).
lbp(op('^'), 80).  lbp(op('@'), 80).  lbp(op('#'), 80).

prefix([num(N)|Ts], num(N), Ts) :- !.
prefix([str(S)|Ts], str(S), Ts) :- !.
prefix([bool(B)|Ts], bool(B), Ts) :- !.
prefix([null|Ts], null, Ts) :- !.
prefix([name(N)|Ts], name(N), Ts) :- !.
prefix([var(N)|Ts], var(N), Ts) :- !.
prefix([op('-')|Ts0], E, Ts) :- !,
    expr(70, Ts0, A, Ts),
    ( A = num(N) -> N1 is -N, E = num(N1) ; E = neg(A) ).
prefix([op('(')|Ts0], E, Ts) :- !,
    block_items(Ts0, Es, Ts),
    ( Es = [E0] -> E = E0 ; E = block(Es) ).
prefix([op('[')|Ts0], array(Es), Ts) :- !,
    list_items(op(']'), Ts0, Es, Ts).
prefix([op('{')|Ts0], object(Ps), Ts) :- !,
    pairs(Ts0, Ps, Ts).
prefix([op(function)|Ts0], unsupported(function), Ts) :- !,
    skip_balanced(Ts0, Ts1),            % the parameters
    ( Ts1 = [op('{')|_] -> skip_balanced(Ts1, Ts) ; Ts = Ts1 ).
prefix([op('*')|Ts], name('*'), Ts) :- !.
prefix([op('/')|Ts0], unsupported(regex), Ts) :- !,
    skip_until(op('/'), Ts0, Ts).
prefix(Ts, _, _) :- throw(error(jsonata(unexpected(Ts)), _)).

infix(op('.'), L, Ts0, path(L, R), Ts) :- !, expr(75, Ts0, R, Ts).
infix(op('['), L, Ts0, E, Ts) :- !,
    (   Ts0 = [op(']')|Ts] -> E = L        % `x[]`: keep the array
    ;   expr(0, Ts0, P, [op(']')|Ts]), E = filter(L, P)
    ).
infix(op('('), L, Ts0, call(F, Args), Ts) :- !,
    list_items(op(')'), Ts0, Args, Ts),
    ( L = var(F) -> true ; L = name(F) -> true ; F = L ).
infix(op('{'), L, Ts0, unsupported(group(L)), Ts) :- !, pairs(Ts0, _, Ts).
infix(op('?'), C, Ts0, cond(C, T, E), Ts) :- !,
    expr(20, Ts0, T, Ts1),
    (   Ts1 = [op(':')|Ts2] -> expr(20, Ts2, E, Ts)
    ;   E = none, Ts = Ts1
    ).
infix(op(Op), L, Ts0, E, Ts) :-
    memberchk(Op, ['~>', ':=', '**', '..', '?:', '??', '^', '@', '#']), !,
    lbp(op(Op), P), expr(P, Ts0, _, Ts),
    E = unsupported(Op), ignore(L = _).
infix(op(Op), L, Ts0, bin(Op, L, R), Ts) :-
    lbp(op(Op), P), expr(P, Ts0, R, Ts).

list_items(Close, [Close|Ts], [], Ts) :- !.
list_items(Close, Ts0, [E|Es], Ts) :-
    expr(0, Ts0, E, Ts1),
    (   Ts1 = [op(',')|Ts2] -> list_items(Close, Ts2, Es, Ts)
    ;   Ts1 = [Close|Ts] -> Es = []
    ;   throw(error(jsonata(expected(Close)), _))
    ).

block_items(Ts0, [E|Es], Ts) :-
    expr(0, Ts0, E, Ts1),
    (   Ts1 = [op(';')|Ts2] -> ( Ts2 = [op(')')|Ts] -> Es = [] ; block_items(Ts2, Es, Ts) )
    ;   Ts1 = [op(')')|Ts] -> Es = []
    ;   throw(error(jsonata(expected(')')), _))
    ).

pairs([op('}')|Ts], [], Ts) :- !.
pairs(Ts0, [K-V|Ps], Ts) :-
    expr(0, Ts0, K, [op(':')|Ts1]),
    expr(0, Ts1, V, Ts2),
    (   Ts2 = [op(',')|Ts3] -> pairs(Ts3, Ps, Ts)
    ;   Ts2 = [op('}')|Ts] -> Ps = []
    ;   throw(error(jsonata(expected('}')), _))
    ).

skip_balanced([op(O)|Ts0], Ts) :- memberchk(O-C, ['('-')', '{'-'}', '['-']']), !,
    skip_to_close(C, Ts0, Ts).
skip_balanced(Ts, Ts).
skip_to_close(C, [op(C)|Ts], Ts) :- !.
skip_to_close(C, [op(O)|Ts0], Ts) :- memberchk(O, ['(', '{', '[']), !,
    skip_balanced([op(O)|Ts0], Ts1), skip_to_close(C, Ts1, Ts).
skip_to_close(C, [_|Ts0], Ts) :- skip_to_close(C, Ts0, Ts).
skip_until(T, [T|Ts], Ts) :- !.
skip_until(T, [_|Ts0], Ts) :- skip_until(T, Ts0, Ts).

		 /*******************************
		 *        NAMES THAT ARE READ   *
		 *******************************/

%!  jsonata_names(+Tree, -Names) is det.
%
%   The input fields an expression reads from the root of its input: the
%   first step of every path, not the fields inside a filter or after a
%   dot (those are fields of the value found there).
jsonata_names(T, Names) :-
    findall(N, root_name(T, N), Ns0), sort(Ns0, Names).

root_name(name(N), N) :- N \== '*'.
root_name(path(A, _), N) :- root_name(A, N).
root_name(filter(A, _), N) :- root_name(A, N).          % the predicate reads each element
root_name(call(_, Args), N) :- member(A, Args), root_name(A, N).
root_name(bin(_, A, B), N) :- ( root_name(A, N) ; root_name(B, N) ).
root_name(neg(A), N) :- root_name(A, N).
root_name(cond(C, T, E), N) :- member(X, [C, T, E]), X \== none, root_name(X, N).
root_name(array(Es), N) :- member(E, Es), root_name(E, N).
root_name(object(Ps), N) :- member(_-V, Ps), root_name(V, N).
root_name(block(Es), N) :- member(E, Es), root_name(E, N).

		 /*******************************
		 *           WRITING            *
		 *******************************/

wr(num(N)) :- !, ( integer(N) -> write(N) ; format("~w", [N]) ).
wr(str(S)) :- !, format("'~w'", [S]).
wr(bool(B)) :- !, write(B).
wr(null) :- !, write(null).
wr(name(N)) :- !, ( sub_atom(N, _, _, _, ' ') -> format("`~w`", [N]) ; write(N) ).
wr(var(N)) :- !, format("$~w", [N]).
wr(path(A, B)) :- !, wr(A), write('.'), wr(B).
wr(filter(A, P)) :- !, wr(A), write('['), wr(P), write(']').
wr(call(F, Args)) :- !, ( atom(F) -> format("$~w(", [F]) ; wr(F), write('(') ), wr_list(Args), write(')').
wr(bin(Op, A, B)) :- !, wr_arg(A), format(" ~w ", [Op]), wr_arg(B).
wr(neg(A)) :- !, write('-'), wr_arg(A).
wr(cond(C, T, none)) :- !, wr_arg(C), write(' ? '), wr_arg(T).
wr(cond(C, T, E)) :- !, wr_arg(C), write(' ? '), wr_arg(T), write(' : '), wr_arg(E).
wr(array(Es)) :- !, write('['), wr_list(Es), write(']').
wr(object(Ps)) :- !, write('{'), wr_pairs(Ps), write('}').
wr(block(Es)) :- !, write('('), wr_seq(Es), write(')').
wr(unsupported(W)) :- !, format("/* ~w */", [W]).
wr(X) :- write(X).

wr_arg(E) :- ( E = bin(_, _, _) ; E = cond(_, _, _) ), !, write('('), wr(E), write(')').
wr_arg(E) :- wr(E).
wr_list([]).
wr_list([E]) :- !, wr(E).
wr_list([E|Es]) :- wr(E), write(', '), wr_list(Es).
wr_seq([E]) :- !, wr(E).
wr_seq([E|Es]) :- wr(E), write('; '), wr_seq(Es).
wr_pairs([]).
wr_pairs([K-V]) :- !, wr(K), write(': '), wr(V).
wr_pairs([K-V|Ps]) :- wr(K), write(': '), wr(V), write(', '), wr_pairs(Ps).

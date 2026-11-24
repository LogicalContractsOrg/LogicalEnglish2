/** <module> The L4 lexer: text → tokens with their lines and columns

    Part of the L4 reader (the design notes l4.md §6, step 1). It follows the
    lexer of L4's own implementation (jl4-core/src/L4/Lexer.hs of
    smucclaw/l4-ide at commit 5e082cf, Copyright 2025 Singapore Management
    University, Apache-2.0)
    token for token, because L4's layout depends on the exact column of each
    token:

      - literals first: a number (an integer, or digits.digits, each possibly
        preceded by `-` with no space), a string in double quotes;
      - `'s` (the genitive) and a name in backquotes;
      - a directive: `#EVAL`, `#EVALTRACE`, `#CHECK`, `#TRACE`, `#ASSERT`, and
        `# ` (a directive continued on the next line);
      - annotations: `@ref-src`, `@ref-map`, `@desc`, `@export`, `@nlg`,
        `@ref` (each to the end of the line), `[ … ]` (an inline `@nlg`) and
        `<< … >>` (an inline `@ref`);
      - white space and comments (`--` and `//` to the end of the line,
        nested `{- … -}`, `/* … */`), which are dropped;
      - symbols (longest first): `...`, `<<`, `>>`, `..`, `^`, `(`, `)`, `{`,
        `}`, `[`, `]`, `§`, `,`, `;`, `.`, `%`, `:`;
      - operators (`*`, `+`, `-`, `>=`, `<=`, `>`, `<`, `=`, `==`, `!=`, `&&`,
        `||`, `=>`, `/`), else any other run of operator characters;
      - a keyword (the upper-case words of Lexer.hs's table) or a name.

    Columns count from 1, and a tab moves to the next multiple of 8 plus 1,
    as Megaparsec's do. `^` (the ditto mark) is replaced by a copy of the
    token that starts at the same column on the line above — the nearest
    line above that has anything but white space and comments on it.

    A token is tok(Kind, Value, Line, Column, EndLine, EndColumn):
        kw(K)        Value = K, an upper-case atom ('GIVEN')
        id           a name                    Value = atom
        q            a name in backquotes      Value = atom
        gen          's
        num          a number                  Value = integer or float
        str          a string                  Value = string
        op           an operator               Value = atom
        sym          a symbol                  Value = atom
        other        other operator characters Value = atom
        dir          a directive               Value = eval | evaltrace | check | trace | assert | cont
        ann(K)       an annotation, K = nlg | ref | desc | export | ref_src | ref_map;
                     Value = its text (string)
        ditto        a `^` with nothing above it
*/

:- module(l4_lex, [l4_tokens/2, l4_keyword/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).

%!  l4_tokens(+Text, -Tokens) is det.
%
%   Text is a string, an atom or a list of codes. Throws
%   error(l4_lex(Line, Column, Rest), _) on a character no rule reads.
l4_tokens(Text, Tokens) :-
    (   is_list(Text) -> Codes = Text
    ;   string_codes(Text, Codes)
    ),
    raw_tokens(Codes, 1, 1, Raw),
    resolve_dittos(Raw, Tokens).

% ---------------------------------------------------------------------------
% Raw tokens, with positions

raw_tokens([], _, _, []) :- !.
raw_tokens(Cs, L, C, Ts) :-
    (   token(Cs, Rest, Kind, Value)
    ->  true
    ;   length(Cs, N), M is min(N, 30), length(Pre, M), append(Pre, _, Cs),
        atom_codes(A, Pre),
        throw(error(l4_lex(L, C, A), _))
    ),
    advance_to(Cs, Rest, L, C, L1, C1),
    (   Kind == space
    ->  Ts = Ts1
    ;   Ts = [tok(Kind, Value, L, C, L1, C1)|Ts1]
    ),
    raw_tokens(Rest, L1, C1, Ts1).

%   advance_to(+Cs, +Rest, +L, +C, -L1, -C1): the position after the codes
%   of Cs that come before its suffix Rest (the same term, not a copy).
advance_to(Cs, Rest, L, C, L, C) :- same_term(Cs, Rest), !.
advance_to([0'\n|Cs], Rest, L, _, L2, C2) :- !, L1 is L + 1, advance_to(Cs, Rest, L1, 1, L2, C2).
advance_to([0'\t|Cs], Rest, L, C, L2, C2) :- !, C1 is ((C - 1) // 8 + 1) * 8 + 1, advance_to(Cs, Rest, L, C1, L2, C2).
advance_to([_|Cs], Rest, L, C, L2, C2) :- C1 is C + 1, advance_to(Cs, Rest, L, C1, L2, C2).

%   token(+Codes, -Rest, -Kind, -Value): the first token of Codes, in the
%   order of Lexer.hs's tokenPayload.
token(Cs, Rest, Kind, Value) :- literal(Cs, Rest, Kind, Value), !.
token([0'', 0's|Rest], Rest, gen, '\'s') :- !.
token([0'`|Cs], Rest, q, Name) :- !,
    append(NameCs, [0'`|Rest], Cs), !,
    NameCs \== [], \+ member(0'\n, NameCs),
    atom_codes(Name, NameCs).
token([0'#|Cs], Rest, dir, D) :- directive(Cs, Rest, D), !.
token(Cs, Rest, ann(K), Text) :- annotation(Cs, Rest, K, Text), !.
token(Cs, Rest, space, '') :- space(Cs, Rest), !.
token(Cs, Rest, sym, S) :- symbol(Cs, Rest, S), !.
token(Cs, Rest, Kind, Value) :-
    op_string(Cs, OpCs, Rest), OpCs \== [], !,
    atom_codes(A, OpCs),
    (   operator(A) -> Kind = op, Value = A
    ;   Kind = other, Value = A
    ).
token([C|Cs], Rest, Kind, Value) :-
    alpha(C), !,
    ident_rest(Cs, More, Rest),
    atom_codes(A, [C|More]),
    (   l4_keyword(A) -> Kind = kw(A), Value = A
    ;   Kind = id, Value = A
    ).

% Literals: a rational (digits . digits), an integer, a string.
literal(Cs, Rest, num, N) :-
    opt_minus(Cs, Sign, Cs1),
    digits(Cs1, D1, [0'.|Cs2]), D1 \== [],
    digits(Cs2, D2, Rest), D2 \== [], !,
    append(D1, [0'.|D2], Ds),
    number_codes(N0, Ds), N is Sign * N0.
literal(Cs, Rest, num, N) :-
    opt_minus(Cs, Sign, Cs1),
    digits(Cs1, D1, Rest), D1 \== [], !,
    number_codes(N0, D1), N is Sign * N0.
literal([0'"|Cs], Rest, str, S) :-
    string_body(Cs, Body, Rest), !,
    string_codes(S, Body).

opt_minus([0'-|Cs], -1, Cs) :- Cs = [D|_], digit(D), !.
opt_minus(Cs, 1, Cs).

digits([D|Cs], [D|Ds], Rest) :- digit(D), !, digits(Cs, Ds, Rest).
digits(Cs, [], Cs).

digit(D) :- between(0'0, 0'9, D).

%   A Haskell character literal body: \" \\ \n \t and the like.
string_body([0'"|Rest], [], Rest) :- !.
string_body([0'\\, E|Cs], [C|Bs], Rest) :- !, escape(E, C), string_body(Cs, Bs, Rest).
string_body([C|Cs], [C|Bs], Rest) :- string_body(Cs, Bs, Rest).

escape(0'n, 0'\n) :- !.
escape(0't, 0'\t) :- !.
escape(0'r, 0'\r) :- !.
escape(C, C).

directive(Cs, Rest, D) :-
    member(Word-D, ["EVALTRACE"-evaltrace, "EVAL"-eval, "CHECK"-check, "TRACE"-trace, "ASSERT"-assert]),
    string_codes(Word, WCs), append(WCs, Rest, Cs), !.
directive(Cs, Cs, cont) :- Cs = [0' |_].

annotation(Cs, Rest, K, Text) :-
    member(Herald-K, ["@ref-src"-ref_src, "@ref-map"-ref_map, "@desc"-desc, "@export"-export,
                      "@nlg"-nlg, "@ref"-ref]),
    string_codes(Herald, HCs), append(HCs, After, Cs), !,
    to_eol(After, TCs, Rest),
    string_codes(T0, TCs), normalize_space(string(Text), T0).
annotation([0'[|Cs], Rest, nlg, Text) :-
    append(TCs, [0']|Rest], Cs), !,
    string_codes(Text, TCs).
annotation([0'<, 0'<|Cs], Rest, ref, Text) :-
    append(TCs, [0'>, 0'>|Rest], Cs), !,
    string_codes(Text, TCs).

to_eol([], [], []).
to_eol(Cs, [], Cs) :- Cs = [0'\n|_], !.
to_eol([C|Cs], [C|Ts], Rest) :- to_eol(Cs, Ts, Rest).

space([C|Cs], Rest) :- white(C), !, whites(Cs, Rest).
space([0'-, 0'-|Cs], Rest) :- !, to_eol(Cs, _, Rest).
space([0'/, 0'/|Cs], Rest) :- !, to_eol(Cs, _, Rest).
space([0'{, 0'-|Cs], Rest) :- !, block(Cs, 0'-, 0'}, 0'{, Rest).
space([0'/, 0'*|Cs], Rest) :- !, block(Cs, 0'*, 0'/, 0'/, Rest).

whites([C|Cs], Rest) :- white(C), !, whites(Cs, Rest).
whites(Cs, Cs).

white(C) :- code_type(C, space).

%   A block comment, nested: `{- … {- … -} … -}`.
block([A, B|Cs], A, B, _, Cs) :- !.
block([O, A|Cs], A, B, O, Rest) :- !,
    block(Cs, A, B, O, Cs1),
    block(Cs1, A, B, O, Rest).
block([_|Cs], A, B, O, Rest) :- block(Cs, A, B, O, Rest).

symbol(Cs, Rest, S) :-
    member(S, ['...', '<<', '>>', '..', '^', '(', ')', '{', '}', '[', ']', '§', ',', ';', '.', '%', ':']),
    atom_codes(S, SCs), append(SCs, Rest, Cs), !.

op_string([C|Cs], [C|Os], Rest) :- op_char(C), !, op_string(Cs, Os, Rest).
op_string(Cs, [], Cs).

op_char(C) :- memberchk(C, `=<>+-*/:~&|%§`).

operator(A) :- memberchk(A, ['*', '+', '-', '>=', '<=', '>', '<', '=', '==', '!=', '&&', '||', '=>', '/']).

alpha(C) :- code_type(C, alpha), \+ code_type(C, digit(_)), C \== 0'_.

ident_char(C) :- code_type(C, alnum) ; C == 0'_.

ident_rest([C|Cs], [C|Is], Rest) :- ident_char(C), !, ident_rest(Cs, Is, Rest).
ident_rest(Cs, [], Cs).

%!  l4_keyword(?Word) is nondet.
l4_keyword(W) :-
    memberchk(W, ['GIVEN', 'GIVETH', 'GIVES', 'DECIDE', 'EXACTLY', 'MEANS', 'DECLARE', 'IF',
                  'BRANCH', 'THEN', 'ELSE', 'OTHERWISE', 'AND', 'OR', 'RAND', 'ROR', 'NOT', 'IS',
                  'ONE', 'OF', 'WITH', 'A', 'AN', 'HAS', 'THE', 'YIELD', 'CONSIDER', 'WHERE',
                  'LIST', 'ASSUME', 'WHEN', 'TYPE', 'PARTY', 'DO', 'DOES', 'MUST', 'MAY', 'SHANT',
                  'BREACH', 'BECAUSE', 'PROVIDED', 'WITHIN', 'HENCE', 'LEST', 'FUNCTION', 'FROM',
                  'TO', 'EQUALS', 'IMPLIES', 'PLUS', 'MINUS', 'TIMES', 'DIVIDED', 'MODULO', 'BY',
                  'GREATER', 'LESS', 'THAN', 'ABOVE', 'BELOW', 'AT', 'STARTING', 'LEAST', 'MOST',
                  'FOLLOWED', 'FOR', 'ALL', 'AKA', 'IMPORT', 'FETCH', 'POST', 'ENV', 'CONCAT',
                  'AS', 'LET', 'IN', 'BE', 'MEAN', 'UNLESS']).

% ---------------------------------------------------------------------------
% The ditto mark

%   resolve_dittos(+Raw, -Tokens): each sym('^') becomes a copy of the token
%   starting at its column on the previous line that has a token (an
%   annotation counts; white space and comments do not, and were dropped).
resolve_dittos(Raw, Tokens) :-
    resolve(Raw, 0, [], [], Tokens).

%   resolve(+Raw, +CurLine, +CurLineToks, +PrevLineToks, -Out)
resolve([], _, _, _, []).
resolve([T0|Ts], Cur, CurToks, Prev, [T|Out]) :-
    T0 = tok(_, _, L, C, EL, EC),
    (   L =:= Cur -> Prev1 = Prev, CurToks1 = CurToks
    ;   ( CurToks == [] -> Prev1 = Prev ; Prev1 = CurToks ), CurToks1 = []
    ),
    (   T0 = tok(sym, '^', _, _, _, _)
    ->  (   member(tok(K, V, _, C, _, _), Prev1)
        ->  T = tok(K, V, L, C, EL, EC)
        ;   T = tok(ditto, '^', L, C, EL, EC)
        )
    ;   T = T0
    ),
    resolve(Ts, L, [T|CurToks1], Prev1, Out).

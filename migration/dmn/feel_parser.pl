/** <module> FEEL text → an abstract syntax tree

    The Friendly Enough Expression Language of DMN, chapter 10 of the
    specification: the expressions of literal expressions, the cells of
    decision tables (unary tests), and the bodies of boxed expressions.

        feel_parse(+Text, +Names, -AST)       an expression
        feel_unary(+Text, +Names, -Tests)     the cell of an input column

    Names are the names in scope (the inputs, decisions and BKMs of the
    model, a context's entries, a function's parameters). FEEL allows a name
    to hold spaces and some operators (`Applicant data`, `Monthly Income -
    Gross`), so the parser tries, at each name, the longest name in scope
    that the text begins with; only then does it take the plain run of words
    up to the next keyword or operator. The built-in functions whose names
    hold spaces (`date and time`, `string length`) are always in scope.

    The tree:

      num(R)              an exact rational (FEEL numbers are decimals)
      str(S)              a string
      bool(true|false), null
      name(N)             a name, with the spaces as written (normalised)
      at(S)               a temporal literal `@"2020-01-01"`
      path(E, Name)       `E.Name`
      filter(E, Cond)     `E[Cond]`
      call(F, Args)       Args = [pos(E)] or [named(Name, E)]
      arith(Op, A, B)     Op one of + - * / **
      neg(E)
      cmp(Op, A, B)       Op one of = != < <= > >=
      and(A, B), or(A, B)
      between(E, Lo, Hi)
      in(E, Tests)        Tests as feel_unary/3 gives them
      instance_of(E, Type)
      if(C, Then, Else)
      for(Iterators, Return)          Iterators = [iter(Name, Domain)]
      some(Iterators, Cond), every(Iterators, Cond)
      list(Es), context([Key-E]), range(LoIncl, Lo, Hi, HiIncl)
      function(Params, Body), external(Params, Body)
      q                   `?`, the value tested in a unary test (DMN 1.2+)
      unary_cmp(Op, E)    `< 10` written as an expression (a range, 1.4+)

    Unary tests (feel_unary/3): any (`-`), not(Tests), or a list of
    test(T): T is cmp(Op, E) (`< 10`), range(...), eq(E) (a value), or
    expr(E) (a boolean expression over `?`).
*/

:- module(feel_parser, [
    feel_parse/3,               % +Text, +Names, -AST
    feel_unary/3,               % +Text, +Names, -Tests
    feel_builtin_name/1         % ?Name
]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(dcg/basics), [digits//1]).

%!  feel_parse(+Text, +Names, -AST) is semidet.
feel_parse(Text, Names, AST) :-
    text_codes(Text, Cs),
    scope(Names, Scope),
    phrase((ws, expr(Scope, AST), ws), Cs), !.

%!  feel_unary(+Text, +Names, -Tests) is semidet.
feel_unary(Text, Names, Tests) :-
    text_codes(Text, Cs),
    scope(Names, Scope),
    phrase((ws, unary_tests(Scope, Tests), ws), Cs), !.

text_codes(T, Cs) :- ( string(T) -> string_codes(T, Cs) ; atom(T) -> atom_codes(T, Cs) ; Cs = T ).

%   The names in scope, as code lists with single spaces, longest first,
%   together with the built-ins whose names have spaces.
scope(Names, scope(Sorted)) :-
    findall(N, ( member(N, Names) ; feel_builtin_name(N) ), All0),
    findall(L-Cs, ( member(N, All0), name_codes(N, Cs), Cs \== [], length(Cs, L) ), Keyed),
    sort(0, @>=, Keyed, Desc),
    pairs_values(Desc, Sorted0),
    list_to_set(Sorted0, Sorted).

name_codes(N, Cs) :-
    ( atom(N) -> atom_codes(N, Cs0) ; string(N) -> string_codes(N, Cs0) ; Cs0 = N ),
    normalise_ws(Cs0, Cs).

normalise_ws(Cs0, Cs) :-
    atom_codes(A, Cs0), normalize_space(codes(Cs), A).

		 /*******************************
		 *          EXPRESSIONS         *
		 *******************************/

expr(S, E) --> kw("if"), !, ws, expr(S, C), ws, kw("then"), ws, expr(S, T), ws, kw("else"), ws, expr(S, F),
    { E = if(C, T, F) }.
expr(S, for(Its, R)) --> kw("for"), !, ws, iterators(S, Its, S1), ws, kw("return"), ws, expr(S1, R).
expr(S, E) --> quantifier(Q), !, ws, iterators(S, Its, S1), ws, kw("satisfies"), ws, expr(S1, C),
    { E =.. [Q, Its, C] }.
expr(S, E) --> disj(S, E).

quantifier(some) --> kw("some").
quantifier(every) --> kw("every").

iterators(S, [iter(N, D)|Is], S2) -->
    plain_name(N), ws, kw("in"), ws, iter_domain(S, D),
    { add_name(S, N, S1) },
    (   ws, ",", ws -> iterators(S1, Is, S2) ; { Is = [], S2 = S1 } ).

iter_domain(S, range_to(A, B)) --> disj(S, A), ws, "..", !, ws, disj(S, B).
iter_domain(S, D) --> disj(S, D).

add_name(scope(Ns), N, scope([Cs|Ns])) :- name_codes(N, Cs).

disj(S, E) --> conj(S, A), disj_tail(S, A, E).
disj_tail(S, A, E) --> ws, kw("or"), !, ws, conj(S, B), disj_tail(S, or(A, B), E).
disj_tail(_, E, E) --> [].

conj(S, E) --> comparison(S, A), conj_tail(S, A, E).
conj_tail(S, A, E) --> ws, kw("and"), !, ws, comparison(S, B), conj_tail(S, and(A, B), E).
conj_tail(_, E, E) --> [].

comparison(S, E) --> arith(S, A), comparison_tail(S, A, E).
comparison_tail(S, A, cmp(Op, A, B)) --> ws, cmp_op(Op), !, ws, arith(S, B).
comparison_tail(S, A, between(A, L, H)) --> ws, kw("between"), !, ws, arith(S, L), ws, kw("and"), ws, arith(S, H).
comparison_tail(S, A, in(A, Ts)) --> ws, kw("in"), !, ws, in_tests(S, Ts).
comparison_tail(_, A, instance_of(A, T)) --> ws, kw("instance"), ws, kw("of"), !, ws, type_name(T).
comparison_tail(_, E, E) --> [].

in_tests(S, Ts) --> "(", ws, positive_tests(S, Ts), ws, ")", !.
in_tests(S, [test(T)]) --> positive_test(S, T).

cmp_op('<=') --> "<=".
cmp_op('>=') --> ">=".
cmp_op('!=') --> "!=".
cmp_op('<') --> "<".
cmp_op('>') --> ">".
cmp_op('=') --> "=".

arith(S, E) --> term(S, A), arith_tail(S, A, E).
arith_tail(S, A, E) --> ws, add_op(Op), !, ws, term(S, B), arith_tail(S, arith(Op, A, B), E).
arith_tail(_, E, E) --> [].

add_op(+) --> "+".
add_op(-) --> "-".

term(S, E) --> expo(S, A), term_tail(S, A, E).
term_tail(S, A, E) --> ws, mul_op(Op), !, ws, expo(S, B), term_tail(S, arith(Op, A, B), E).
term_tail(_, E, E) --> [].

mul_op(*) --> "*", \+ "*".
mul_op(/) --> "/".

expo(S, E) --> unary(S, A), expo_tail(S, A, E).
expo_tail(S, A, E) --> ws, "**", !, ws, unary(S, B), expo_tail(S, arith(**, A, B), E).
expo_tail(_, E, E) --> [].

unary(S, neg(E)) --> "-", ws, unary(S, E), !.
unary(S, E) --> postfix(S, E).

postfix(S, E) --> primary(S, P), postfix_tail(S, P, E).
postfix_tail(S, P, E) --> ws, ".", \+ ".", ws, feel_name(S, N), !, postfix_tail(S, path(P, N), E).
postfix_tail(S, P, E) --> ws, "[", ws, expr(S, C), ws, "]", !, postfix_tail(S, filter(P, C), E).
postfix_tail(S, P, E) --> ws, "(", ws, args(S, As), ws, ")", !, postfix_tail(S, call(P, As), E).
postfix_tail(_, E, E) --> [].

args(_, []) --> [].
args(S, [A|As]) --> arg(S, A), ws, ( ",", ws -> args1(S, As) ; { As = [] } ).
args1(S, [A|As]) --> arg(S, A), ws, ( ",", ws -> args1(S, As) ; { As = [] } ).

arg(S, named(N, E)) --> plain_name(N), ws, ":", \+ "=", !, ws, expr(S, E).
arg(S, pos(E)) --> expr(S, E).

		 /*******************************
		 *           PRIMARIES          *
		 *******************************/

primary(_, num(N)) --> number(N), !.
primary(_, str(T)) --> string_lit(T), !.
primary(_, at(T)) --> "@", ws, string_lit(T), !.
primary(_, bool(true)) --> kw("true"), !.
primary(_, bool(false)) --> kw("false"), !.
primary(_, null) --> kw("null"), !.
primary(S, E) --> kw("function"), !, ws, "(", ws, params(Ps), ws, ")", ws,
    { foldl([N, S0, S1]>>add_name(S0, N, S1), Ps, S, S2) },
    (   kw("external") -> ws, expr(S2, B), { E = external(Ps, B) }
    ;   expr(S2, B), { E = function(Ps, B) }
    ).
primary(S, E) --> "(", ws, expr(S, A), ws, range_or_paren(S, '(', A, E), !.
primary(S, E) --> "]", ws, expr(S, A), ws, "..", ws, expr(S, B), ws, range_close(H), !,
    { E = range(false, A, B, H) }.
primary(S, E) --> "[", ws, list_or_range(S, E), !.
primary(S, context(Es)) --> "{", ws, context_entries(S, Es), ws, "}", !.
primary(S, unary_cmp(Op, E)) --> cmp_op(Op), ws, arith(S, E), !.
primary(_, q) --> "?", \+ name_part, !.
primary(S, name(N)) --> feel_name(S, N).

range_or_paren(S, '(', A, range(false, A, B, H)) --> "..", !, ws, expr(S, B), ws, range_close(H).
range_or_paren(_, '(', A, A) --> ")".

range_close(true) --> "]".
range_close(false) --> ")".
range_close(false) --> "[".

list_or_range(_, list([])) --> "]", !.
list_or_range(S, E) --> expr(S, A), ws,
    (   ".." -> ws, expr(S, B), ws, range_close(H), { E = range(true, A, B, H) }
    ;   list_rest(S, As), { E = list([A|As]) }
    ).

list_rest(_, []) --> "]".
list_rest(S, [A|As]) --> ",", ws, expr(S, A), ws, list_rest(S, As).

context_entries(_, []) --> [].
context_entries(S, [K-E|Es]) --> context_key(S, K), ws, ":", ws, expr(S, E), ws,
    { add_name(S, K, S1) },
    ( ",", ws -> context_entries1(S1, Es) ; { Es = [] } ).
context_entries1(S, [K-E|Es]) --> context_key(S, K), ws, ":", ws, expr(S, E), ws,
    { add_name(S, K, S1) },
    ( ",", ws -> context_entries1(S1, Es) ; { Es = [] } ).

context_key(_, K) --> string_lit(K0), !, { atom_string(K, K0) }.
context_key(_, K) --> plain_name(K), ws, \+ \+ ":", !.
context_key(_, K) --> key_codes(Cs), { Cs \== [], atom_codes(K0, Cs), normalize_space(atom(K), K0) }.

%   A key with FEEL's additional name symbols (`foo+bar`), up to its colon.
key_codes([C|Cs]) --> [C], { C =\= 0':, C =\= 0'}, C =\= 0', }, !, key_codes(Cs).
key_codes([]) --> [].

params([P|Ps]) --> param(P), ws, ( ",", ws -> params(Ps) ; { Ps = [] } ).
params([]) --> [].
param(N) --> plain_name(N), ws, ( ":", ws, type_name(_) -> [] ; [] ).

type_name(T) --> type_codes(Cs), { Cs \== [], atom_codes(T0, Cs), normalize_space(atom(T), T0) }.
type_codes([C|Cs]) --> [C], { code_type(C, csym) ; memberchk(C, `. <>,:->`) }, !, type_codes(Cs).
type_codes([]) --> [].

		 /*******************************
		 *            NAMES             *
		 *******************************/

%   A name: the longest name in scope the text begins with, else the plain
%   run of words.
feel_name(scope(Ns), N) -->
    { member(Cs, Ns) }, name_match(Cs), \+ name_part, !,
    { atom_codes(N, Cs) }.
feel_name(_, N) --> plain_name(N).

%   The text matches a name in scope, a single space in the name matching
%   any run of white space in the text.
name_match([]) --> [].
name_match([0' |Cs]) --> !, blank1, blanks0, name_match(Cs).
name_match([C|Cs]) --> [C], name_match(Cs).

blank1 --> [C], { code_type(C, space) }.
blanks0 --> blank1, !, blanks0.
blanks0 --> [].

%   A plain name: words of name characters, separated by single spaces, up
%   to a keyword or anything that is not a word.
plain_name(N) --> name_word(W), \+ { keyword(W) }, more_words(Ws),
    { atomic_list_concat([W|Ws], ' ', N) }.

more_words([W|Ws]) --> blank1, blanks0, name_word(W), { \+ keyword(W) }, !, more_words(Ws).
more_words([]) --> [].

name_word(W) --> [C], { name_start(C) }, name_rest(Cs), { atom_codes(W, [C|Cs]) }.
name_rest([C|Cs]) --> [C], { name_char(C) }, !, name_rest(Cs).
name_rest([]) --> [].

name_part, [C] --> [C], { name_char(C) }.

name_start(C) :- code_type(C, alpha) ; C =:= 0'_ ; C =:= 0'? ; C > 127.
name_char(C) :- code_type(C, alnum) ; C =:= 0'_ ; C =:= 0'' ; C > 127 ; C =:= 0'? .

keyword(W) :- downcase_atom(W, L), memberchk(L, [and, or, if, then, else, for, in, return, some, every,
    satisfies, between, instance, of, function, external, true, false, null]).

kw(K) --> { string_codes(K, Cs) }, Cs, \+ name_part.

%!  feel_builtin_name(?Name) is nondet.
%
%   The built-in functions (§10.3.4) whose names contain spaces; they are
%   in every scope so the longest-name rule can find them.
feel_builtin_name(N) :- member(N, [
    'date and time', 'years and months duration', 'days and time duration',
    'string length', 'upper case', 'lower case', 'substring before',
    'substring after', 'starts with', 'ends with', 'list contains',
    'insert before', 'index of', 'distinct values', 'get value',
    'get entries', 'is defined', 'list replace', 'string join',
    'day of week', 'day of year', 'week of year', 'month of year',
    'context put', 'context merge', 'round up', 'round down',
    'round half up', 'round half down', 'number', 'string']).

		 /*******************************
		 *           LITERALS           *
		 *******************************/

number(N) --> digits(I), { I \== [] }, ".", digits(F), { F \== [] }, exponent(X), !, { decimal(I, F, N0), N is N0 * 10^X }.
number(N) --> digits(I), { I \== [] }, ".", digits(F), { F \== [] }, !, { decimal(I, F, N) }.
number(N) --> digits(I), { I \== [] }, exponent(X), !, { number_codes(N0, I), N is N0 * 10^X }.
number(N) --> ".", digits(F), { F \== [] }, !, { decimal(`0`, F, N) }.
number(N) --> digits(I), { I \== [] }, \+ name_part0, { number_codes(N, I) }.

name_part0, [C] --> [C], { code_type(C, alpha) }.

exponent(X) --> ( "e" ; "E" ), ( "+" -> { Sg = 1 } ; "-" -> { Sg = -1 } ; { Sg = 1 } ), digits(D), { D \== [] },
    { number_codes(X0, D), X is Sg * X0 }.

decimal(I, F, N) :-
    number_codes(IV, I), number_codes(FV, F), length(F, K),
    N is IV + FV rdiv (10^K).

string_lit(S) --> "\"", str_chars(Cs), "\"", { string_codes(S, Cs) }.

str_chars([]) --> [].
str_chars([C|Cs]) --> "\\", [E], !, { escape(E, C) }, str_chars(Cs).
str_chars([C|Cs]) --> [C], { C =\= 0'" }, str_chars(Cs).

escape(0'n, 10) :- !.
escape(0't, 9) :- !.
escape(0'r, 13) :- !.
escape(C, C).

		 /*******************************
		 *          UNARY TESTS         *
		 *******************************/

unary_tests(_, any) --> "-", !.
unary_tests(_, any) --> \+ [_], !.
unary_tests(S, not(Ts)) --> kw("not"), ws, "(", ws, positive_tests(S, Ts), ws, ")", !.
unary_tests(S, Ts) --> positive_tests(S, Ts).

positive_tests(S, [test(T)|Ts]) --> positive_test(S, T), ws, ( ",", ws -> positive_tests(S, Ts) ; { Ts = [] } ).

positive_test(S, cmp(Op, E)) --> cmp_op(Op), ws, endpoint(S, E), \+ (ws, kw("or")), \+ (ws, kw("and")), !.
positive_test(S, R) --> interval(S, R), !.
positive_test(S, T) --> expr(S, E), { ( contains_q(E) -> T = expr(E) ; T = eq(E) ) }.

endpoint(S, E) --> arith(S, E).

interval(S, range(LI, A, B, HI)) --> range_open(LI), ws, endpoint(S, A), ws, "..", ws, endpoint(S, B), ws, range_close(HI).
range_open(true) --> "[".
range_open(false) --> "(".
range_open(false) --> "]".

contains_q(q) :- !.
contains_q(E) :- compound(E), E \= num(_), E \= str(_), arg(_, E, A), ( is_list(A) -> member(X, A), contains_q_(X) ; contains_q(A) ), !.
contains_q_(X) :- ( X = pos(E) ; X = named(_, E) ; X = iter(_, E) ; X = _-E ; X = test(E) ; X = E ), contains_q(E), !.

		 /*******************************
		 *         WHITE SPACE          *
		 *******************************/

ws --> [C], { code_type(C, space) }, !, ws.
ws --> "//", !, skip_line, ws.
ws --> "/*", !, skip_block, ws.
ws --> [].

skip_line --> [C], { C =\= 10 }, !, skip_line.
skip_line --> [].
skip_block --> "*/", !.
skip_block --> [_], skip_block.

/** <module> Epilog's surface syntax, read in Prolog

    The reader of Epilog text that needs no EpilogJS (whose licence does not
    allow it to be redistributed, so a clean checkout does not have it):
    File ▸ Open and the build read Epilog with this module, and the test
    suite checks that it reads every file of the corpus the way EpilogJS
    does (test_epilog.pl, `parser agreement`).

    Epilog writes no full stop after a sentence: one sentence ends where
    two terms meet with no operator between them (`p(a)` then `p(b)` on the
    next line), which is how EpilogJS reads it too. So the text is split
    into tokens, cut into sentences at those places, and each sentence read
    by Prolog's own reader with Epilog's operators:

        H :- B1 & ~B2          a rule (view definition)
        A :: C ==> E1 & ~E2    an operation definition (handler)
        A :: E                 a handler with no condition
        B1 | B2                a disjunction (or(...), as EpilogJS reads it)
        F := E                 a function definition (definition(F, E))
        [X, Y]                 a list, as X!Y!nil
        X!L, nil               a list
        student.major          a symbol (dots inside a name)
        "text"                 a string

    Sentences come out as epilog_reader's do: rule(H, [B, ...]),
    handler(A, C, E) (C and E a literal or and([...]); `true` for none),
    fact(T), with not(P) for `~P` and cons(X, L) for `X!L`, each paired with
    the variables' names.
*/

:- module(epilog_syntax, [
    epilog_text_sentences/2,   % +Text, -Sentences (each Sentence-Bindings)
    epilog_file_sentences/2    % +File, -Sentences
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).
:- use_module(library(dcg/basics)).

%!  epilog_file_sentences(+File, -Sentences) is det.
epilog_file_sentences(File, Sentences) :-
    read_file_to_string(File, Text, [encoding(utf8)]),
    epilog_text_sentences(Text, Sentences).

%!  epilog_text_sentences(+Text, -Sentences) is det.
%
%   Throws error(syntax_error(epilog(Message)), _) on text that is not
%   Epilog.
epilog_text_sentences(Text, Sentences) :-
    string_codes(Text, Cs),
    (   phrase(tokens(Ts), Cs) -> true
    ;   throw(error(syntax_error(epilog('a character Epilog does not use')), _))
    ),
    split_sentences(Ts, Groups),
    maplist(read_sentence, Groups, Sentences).

		 /*******************************
		 *            TOKENS            *
		 *******************************/

tokens(Ts) --> blanks_or_comments, ( token(T) -> { Ts = [T|R] }, tokens(R) ; { Ts = [] } ).

blanks_or_comments --> [C], { code_type(C, space) }, !, blanks_or_comments.
blanks_or_comments --> "%", !, string_without("\n", _), blanks_or_comments.
blanks_or_comments --> [].

token(op(":-")) --> ":-", !.
token(op(":=")) --> ":=", !.
token(op("|")) --> "|", !.
token(lbracket) --> "[", !.
token(rbracket) --> "]", !.
token(op("::")) --> "::", !.
token(op("==>")) --> "==>", !.
token(op("&")) --> "&", !.
token(op("~")) --> "~", !.
token(op("!")) --> "!", !.
token(open) --> "(", !.
token(close) --> ")", !.
token(comma) --> ",", !.
token(string(S)) --> "\"", !, string_without("\"", Cs), "\"", { string_codes(S, Cs) }.
token(quoted(A)) --> "'", !, string_without("'", Cs), "'", { atom_codes(A, Cs) }.
token(number(N)) --> digit(D), !, digits(Ds), ( ".", digit(E), digits(Es) -> { append([[D|Ds], [0'.], [E|Es]], NCs) } ; { NCs = [D|Ds] } ),
    { number_codes(N, NCs) }.
%   A decimal with no digit before its point (`incr(b,.6)`, the Solar System
%   worksheet), which EpilogJS reads as the numeral `.6`.
token(number(N)) --> ".", digit(E), !, digits(Es), { number_codes(N, [0'0, 0'., E|Es]) }.
token(T) --> [C], { name_start(C) }, !, name_rest(Cs), { atom_codes(A, [C|Cs]), name_token(C, A, T) }.

name_start(C) :- code_type(C, alpha) ; C == 0'_.
name_char(C) :- code_type(C, alnum) ; C == 0'_.

%   A name's dots are part of it when a name character follows
%   (`student.major`).
name_rest([C|Cs]) --> [C], { name_char(C) }, !, name_rest(Cs).
name_rest([0'., C|Cs]) --> ".", [C], { name_char(C) }, !, name_rest(Cs).
name_rest([]) --> [].

name_token(C, A, var(A)) :- ( C == 0'_ ; code_type(C, upper) ), !.
name_token(_, A, atom(A)).

		 /*******************************
		 *           SENTENCES          *
		 *******************************/

%   A sentence ends where a term ends (a name, a number, a string, a closing
%   parenthesis) and another begins (a name, a number, a string, `~`), at
%   the outermost level.
split_sentences([], []) :- !.
split_sentences(Ts, [G|Gs]) :- take_sentence(Ts, 0, G, Rest), split_sentences(Rest, Gs).

take_sentence([T], _, [T], []) :- !.
take_sentence([T, N|Ts], D, [T|G], Rest) :-
    depth(T, D, D1),
    (   D1 =:= 0, term_end(T), term_start(N)
    ->  G = [], Rest = [N|Ts]
    ;   take_sentence([N|Ts], D1, G, Rest)
    ).

depth(open, D, D1) :- !, D1 is D + 1.
depth(close, D, D1) :- !, D1 is D - 1.
depth(lbracket, D, D1) :- !, D1 is D + 1.
depth(rbracket, D, D1) :- !, D1 is D - 1.
depth(_, D, D).

term_end(atom(_)).  term_end(var(_)).  term_end(number(_)).  term_end(string(_)).
term_end(quoted(_)).  term_end(close).  term_end(rbracket).
term_start(atom(_)).  term_start(var(_)).  term_start(number(_)).  term_start(string(_)).
term_start(quoted(_)).  term_start(op("~")).  term_start(lbracket).

read_sentence(Ts, S-Bs) :-
    tokens_text(Ts, Texts),
    atomic_list_concat(Texts, Body),
    atom_concat(Body, ' .', Src),
    ops(M),
    catch(term_string(T, Src, [module(M), variable_names(Bs), double_quotes(string)]), _,
          throw(error(syntax_error(epilog(Body)), _))),
    sentence(T, S).

%   A name and its opening parenthesis are written together (`p(a)`, not
%   `p (a)`, which Prolog reads differently); other tokens with a space.
tokens_text(Ts, Xs) :- tokens_text(Ts, 0, Xs).

tokens_text([], _, []).
tokens_text([T|Ts], B, [X|Xs]) :-
    %  `|` is Epilog's disjunction outside a list, a list's tail inside one
    (   T == op("|") -> ( B > 0 -> X0 = '|' ; X0 = ';' )
    ;   token_text(T, X0)
    ),
    ( T == lbracket -> B1 is B + 1 ; T == rbracket -> B1 is B - 1 ; B1 = B ),
    (   Ts = [open|_], memberchk(T, [atom(_), quoted(_)]) -> X = X0
    ;   Ts == [] -> X = X0
    ;   atom_concat(X0, ' ', X)
    ),
    tokens_text(Ts, B1, Xs).

%   The tokens as Prolog text: a name with dots, or any symbol Prolog would
%   read otherwise (a capitalised quoted name stays a symbol), quoted.
token_text(op(O), O).
token_text(open, '(').
token_text(close, ')').
token_text(comma, ',').
token_text(lbracket, '[').
token_text(rbracket, ']').
token_text(string(S), T) :- format(atom(T), '~q', [S]).
token_text(quoted(A), T) :- format(atom(T), '~q', [A]).
token_text(number(N), T) :- format(atom(T), '~w', [N]).
token_text(var(V), V).
token_text(atom(A), T) :- format(atom(T), '~q', [A]).

ops(epilog_syntax_ops) :-
    M = epilog_syntax_ops,
    op(200, xfy, M:(!)),
    op(1150, xfx, M:(::)),
    op(1100, xfx, M:(==>)),
    op(1000, xfy, M:(&)),
    op(1200, xfx, M:(:=)),
    op(900, fy, M:(~)).

		 /*******************************
		 *      AS EPILOG_READER'S      *
		 *******************************/

sentence((H :- B), rule(H1, Bs)) :- !, lit(H, H1), conj(B, Bs0), maplist(lit, Bs0, Bs).
sentence(':='(H, E), definition(H1, E1)) :- !, term(H, H1), term(E, E1).
sentence('::'(A, '==>'(C, E)), handler(A1, C1, E1)) :- !, lit(A, A1), part(C, C1), part(E, E1).
sentence('::'(A, E), handler(A1, true, E1)) :- !, lit(A, A1), part(E, E1).
sentence(T, fact(T1)) :- lit(T, T1).

part(P, P1) :- conj(P, Ps), maplist(lit, Ps, Ls), ( Ls = [L] -> P1 = L ; P1 = and(Ls) ).

disj(V, [V]) :- var(V), !.
disj((A ; B), L) :- !, disj(A, LA), disj(B, LB), append(LA, LB, L).
disj(P, [P]).

conj(V, [V]) :- var(V), !.
conj('&'(A, B), L) :- !, conj(A, LA), conj(B, LB), append(LA, LB, L).
conj(P, [P]).

lit(V, V) :- var(V), !.
lit('~'(P), not(P1)) :- !, lit(P, P1).
lit((A ; B), Or) :- !, term((A ; B), Or).
lit(T, T1) :- term(T, T1).

term(V, V) :- var(V), !.
term('!'(X, L), cons(X1, L1)) :- !, term(X, X1), term(L, L1).
term('&'(A, B), and(Ls)) :- !, conj('&'(A, B), Ps), maplist(lit, Ps, Ls).
term('~'(P), not(P1)) :- !, term(P, P1).
term((A ; B), Or) :- !, disj((A ; B), Ds), maplist(part, Ds, Ls), Or =.. [or|Ls].
term([], nil) :- !.
term([X|L], cons(X1, L1)) :- !, term(X, X1), term(L, L1).
term(T, T1) :- compound(T), !, T =.. [F|As], maplist(term, As, Bs), T1 =.. [F|Bs].
term(T, T).

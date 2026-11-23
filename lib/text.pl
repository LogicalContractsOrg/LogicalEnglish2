/*  lib/text.pl — the predicates behind lib/text.le

    Text as the rule systems the translators read build it: joined from
    pieces, numbers printed without a trailing ".0", dates in ISO form.

    The predicates at the end are the templates of text.le, under the names
    LE gives them (a template's words, its slots left out), with their
    arguments in the order of the slots: LE calls them directly.

    Loaded assert-only as a Prolog resource (docs/user/reference/language.md
    §14.1). No cuts in this file: LE's reasoner runs a resource's clauses
    itself, and a cut there does not prune — so each clause carries the test
    that tells it from the others. Nor does it call library predicates such
    as member/2: a list is walked by a clause of this file (le_text_part/2).
*/

le_text_piece(X, X) :- string(X).
le_text_piece(X, S) :- atom(X), atom_string(X, S).
le_text_piece(X, S) :- integer(X), number_string(X, S).
le_text_piece(X, S) :- float(X), X =:= float_integer_part(X), abs(X) < 1.0e15, I is truncate(X), number_string(I, S).
le_text_piece(X, S) :- float(X), X =\= float_integer_part(X), format(string(S), "~15g", [X]).
le_text_piece(X, S) :- float(X), abs(X) >= 1.0e15, format(string(S), "~15g", [X]).
le_text_piece(date(Y, M, D), S) :- format(string(S), "~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, D]).

%   (No maplist/3: the reasoner runs this file's clauses itself and cannot
%   call a closure of it.)
le_text_join(L, S) :- is_list(L), le_text_pieces(L, Ps), atomic_list_concat(Ps, A), atom_string(A, S).

le_text_pieces([], []).
le_text_pieces([X|Xs], [P|Ps]) :- le_text_piece(X, P), le_text_pieces(Xs, Ps).

le_text_string(X, S) :- le_text_piece(X, S).

the_joining_of_is(L, S) :- le_text_join(L, S).
the_text_of_is(X, S) :- le_text_piece(X, S).
the_length_of_is(T, N) :- le_text_string(T, S), string_length(S, N).
contains(T, P) :- le_text_string(T, S), le_text_string(P, Q), sub_string(S, _, _, _, Q).
ends_with(T, P) :- le_text_string(T, S), le_text_string(P, Q), string_concat(_, Q, S).
%   Each piece of the text between two separators, without the spaces at its
%   ends ("toys & hobbies" and "remote control toys" of "toys & hobbies >
%   remote control toys" split at ">"); an empty piece is not a part.
split_at_has_the_part(T, Sep, P) :- le_text_string(T, S), le_text_string(Sep, D), split_string(S, D, " ", Ps), le_text_part(Ps, P).

le_text_part([P|_], P) :- P \== "".
le_text_part([_|Ps], P) :- le_text_part(Ps, P).

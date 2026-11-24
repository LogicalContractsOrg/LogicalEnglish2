/** <module> RUML labels → the words of Logical English templates

    A node's label is free text in any language: `Antragsteller
    volljährig`, `§ 2 (1) GmbHG`, `Income > 30,000 EUR?`. The twin keeps
    the label as the words of the node's template (the design notes ruml.md
    §4.2), changed only where Logical English would read it otherwise:

    - signs that a template cannot hold go: brackets, quotation marks,
      punctuation; `>`, `<`, `=` and `%` become words (`more than`, ...);
    - a word in capitals (`BGB`, `AND`, `A`) is written in small letters:
      LE reads a word in capitals as a variable;
    - the articles `a` and `an` go: LE reads `a member` in a condition as a
      new variable;
    - a word that LE reserves (`if`, `unless`, `otherwise`, `expects`) and
      the copula `is` are joined to the next word with an underscore.

    Capitalised words (German nouns) and numbers stay: experiment G of the
    plan read `§ 2 Abs 1 GmbHG gilt für *a case*` back.

        label_words(+Label, -Words)       a list of atoms
        unique_label(+Key, +Label, -Text) words no other node has
        names_reset
*/

:- module(ruml_names, [label_words/2, label_text/2, unique_label/3, names_reset/0,
                       datapoint_words/3, case_constant/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).

:- dynamic taken/2.          % Text, Key

names_reset :- retractall(taken(_, _)).

%!  case_constant(-C) is det.   The case that a test or an evaluation is about.
case_constant('case 1').

%!  unique_label(+Key, +Label, -Text) is det.
unique_label(Key, Label, Text) :-
    (   taken(T, Key) -> Text = T
    ;   label_text(Label, T0),
        (   taken(T0, _) -> format(atom(T), "~w node ~w", [T0, Key]) ; T = T0 ),
        assertz(taken(T, Key)), Text = T
    ).

label_text(Label, Text) :- label_words(Label, Ws), atomic_list_concat(Ws, ' ', Text).

%!  datapoint_words(+Id, +Name, -Words) is det.
%   The words of a data point: its name, or its identifier without `dp_`.
datapoint_words(Id, Name, Ws) :-
    (   Name \== '', label_words(Name, Ws0), Ws0 \== [value] -> Ws = Ws0
    ;   atom_string(Id, S), ( string_concat("dp_", R, S) -> true ; R = S ),
        split_string(R, "_", "", Ps), exclude(==(""), Ps, Ps1),
        maplist([P, A]>>atom_string(A, P), Ps1, Ws0), label_words_list(Ws0, Ws)
    ).

%!  label_words(+Label, -Words) is det.
label_words(Label, Words) :-
    ( atom(Label) -> atom_codes(Label, Cs) ; string(Label) -> string_codes(Label, Cs) ; format(codes(Cs), "~w", [Label]) ),
    phrase(signs(Cs1), Cs),
    raw_words(Cs1, Raw),
    label_words_list(Raw, Words).

label_words_list(Raw, Words) :-
    exclude([W]>>memberchk(W, [a, an, '']), Raw, Raw1),       % `A` in capitals is a name, not an article
    maplist(small_caps, Raw1, Ws0),
    join_letters(Ws0, Ws1),                                    % `Antrag A`: `Antrag_a`, not the article
    reserved_safe(Ws1, Ws2),
    ( Ws2 == [] -> Words = [value] ; Words = Ws2 ).

%   Signs that are words.
signs(Out) --> ">=", !, signs(R), { append(` at least `, R, Out) }.
signs(Out) --> "<=", !, signs(R), { append(` at most `, R, Out) }.
signs(Out) --> ">", !, signs(R), { append(` more than `, R, Out) }.
signs(Out) --> "<", !, signs(R), { append(` less than `, R, Out) }.
signs(Out) --> "=", !, signs(R), { append(` equal to `, R, Out) }.
signs(Out) --> "%", !, signs(R), { append(` percent `, R, Out) }.
signs(Out) --> "&", !, signs(R), { append(` and `, R, Out) }.
signs([C|R]) --> [C], !, signs(R).
signs([]) --> [].

%   Runs of letters, digits and `§`; a dot or comma between two digits
%   stays in the run (22.28, 30,000); every other character separates.
raw_words(Cs, Ws) :- raw_words(Cs, [], Ws).
raw_words([], Acc, Ws) :- flush(Acc, [], Ws).
raw_words([C|Cs], Acc, Ws) :-
    (   word_char(C) -> raw_words(Cs, [C|Acc], Ws)
    ;   memberchk(C, `'’`), Acc \== [], Cs = [N|_], code_type(N, alpha) -> raw_words(Cs, Acc, Ws)
    ;   ( C =:= 0'. ; C =:= 0', ), Acc = [P|_], code_type(P, digit), Cs = [N|_], code_type(N, digit)
    ->  raw_words(Cs, Acc, Ws)                     % 30,000 -> 30000; 22.28 -> 2228
    ;   flush(Acc, Ws0, Ws), raw_words(Cs, [], Ws0)
    ).
flush([], Rest, Rest) :- !.
flush(Acc, Rest, [W|Rest]) :- reverse(Acc, Cs), atom_codes(W, Cs).

word_char(C) :- code_type(C, alnum), C =\= 0'_ .
word_char(0'§).
word_char(C) :- C > 127, \+ code_type(C, space), \+ memberchk(C, `‘’“”„–—…«»·•`).

%   A word with no small letter and at least one capital: small letters.
small_caps(W0, W) :-
    atom_codes(W0, Cs),
    (   \+ ( member(C, Cs), code_type(C, lower) ), member(C, Cs), code_type(C, upper)
    ->  downcase_atom(W0, W)
    ;   W = W0
    ).

reserved_safe(Ws0, Ws) :- reserved_safe_(Ws0, [], Ws).
reserved_safe_([], Acc, Ws) :- reverse(Acc, Ws).
reserved_safe_([W|Ws], Acc, Out) :-
    (   \+ reserved_word(W) -> reserved_safe_(Ws, [W|Acc], Out)
    ;   Ws = [N|Rest] -> atomic_list_concat([W, N], '_', WN), reserved_safe_([WN|Rest], Acc, Out)
    ;   Acc = [P|As] -> atomic_list_concat([P, W], '_', PW), reserved_safe_([], [PW|As], Out)
    ;   atom_concat(W, '_', W2), reserved_safe_([], [W2|Acc], Out)
    ).

reserved_word(W0) :- downcase_atom(W0, W), memberchk(W, [if, unless, expects, otherwise, then, when, which, who, what, is, are,
                                  either, holds, would, decided]).

%   A word of one letter joins the word before it: LE reads a lone `a` as
%   an article, and a lone capital as a variable.
join_letters([], []).
join_letters([W, L|Ws], Out) :- atom_length(L, 1), atom_codes(L, [C]), code_type(C, alpha), !,
    downcase_atom(L, LL), atomic_list_concat([W, LL], '_', WL), join_letters([WL|Ws], Out).
join_letters([W|Ws], [W|Out]) :- join_letters(Ws, Out).

/** <module> DMN names → the words of Logical English templates

    A DMN name is whatever the modeller typed: `Applicant data`,
    `isAffordable`, `nieuw bouwwerk _of _ uitbreiding daarvan Op Artikel
    22.28 a`, `Conclusie - BijbehorendBouwwerk`, `Monthly Income - Gross`.
    A template needs words LE reads back as those words and nothing else:

    - camelCase is split (`isAffordable` → is affordable), and words are
      lower case: a word in capitals (`UR`, `TRUE`) is a variable's id in
      LE, and a capitalised word may be read as a proper name;
    - punctuation goes; STTR's escapes of FEEL's keywords (`_of`, `_in`, a
      lone `_`) lose their underscore;
    - a number is joined to the word before it (`artikel_22_28`): a
      template's place cannot be a number, and a number among its words
      would be read as a value;
    - the articles `a` and `an` go (LE reads `a member` in a condition as a
      new variable), except a lone letter after a number (`22_28_a`);
      a leading `the` goes, since the template adds its own;
    - a word LE reserves (`if`, `unless`, `expects`, ...; asked of LE2's
      keyword table), and the copula `is` (a sentence goes on with `is`
      after the name, and would stop at the name's own), is joined to its
      neighbour with an underscore: `is_affordable`.

    names_reset/0 starts a model; unique_words/3 gives each name words no
    other name of the model has (a clash gets a number word).
*/

:- module(dmn_names, [
    name_words/2,           % +Name, -Words
    name_phrase/2,          % +Name, -Atom   (the words, spaced)
    name_functor/3,         % +Prefix, +Name, -Functor
    names_reset/0,
    unique_words/3,         % +Key, +Name, -Words
    type_noun/2             % +TypeRef, -Noun
]).

:- use_module(library(lists)).
:- use_module(library(apply)).

:- dynamic taken/2.          % Words, Key

names_reset :- retractall(taken(_, _)).

%!  unique_words(+Key, +Name, -Words) is det.
unique_words(Key, Name, Words) :-
    (   taken(Ws, Key) -> Words = Ws
    ;   name_words(Name, Ws0),
        unique_(Ws0, 1, Ws),
        assertz(taken(Ws, Key)),
        Words = Ws
    ).

unique_(Ws0, N, Ws) :-
    (   N =:= 1 -> W1 = Ws0 ; number_word(N, NW), append(Ws0, [NW], W1) ),
    (   taken(W1, _) -> N1 is N + 1, unique_(Ws0, N1, Ws) ; Ws = W1 ).

number_word(N, W) :- nth1(N, [one, two, three, four, five, six, seven, eight, nine, ten], W), !.
number_word(N, W) :- format(atom(W), 'number_~d', [N]).

name_phrase(Name, Phrase) :- name_words(Name, Ws), atomic_list_concat(Ws, ' ', Phrase).

name_functor(Prefix, Name, F) :-
    name_words(Name, Ws), atomic_list_concat([Prefix|Ws], '_', F0),
    atom_codes(F0, Cs), include([C]>>(code_type(C, csym)), Cs, Ds), atom_codes(F, Ds).

%!  name_words(+Name, -Words) is det.
name_words(Name, Words) :-
    ( atom(Name) -> atom_codes(Name, Cs) ; string(Name) -> string_codes(Name, Cs) ; format(codes(Cs), "~w", [Name]) ),
    raw_words(Cs, Raw0),
    maplist(split_camel, Raw0, Raw1), append(Raw1, Raw),
    maplist(downcase_atom, Raw, Low),
    exclude(==(''), Low, Ws1),
    join_numbers(Ws1, Ws2),
    drop_articles(Ws2, Ws3),
    ( Ws3 = [the|Ws4], Ws4 \== [] -> true ; Ws4 = Ws3 ),
    reserved_safe(Ws4, Ws5),
    ( Ws5 == [] -> Words = [value] ; Words = Ws5 ).

%   Runs of letters and digits; a dot or comma between two digits stays in
%   the run (22.28), every other character separates.
raw_words(Cs, Ws) :- raw_words(Cs, [], Ws).

raw_words([], Acc, Ws) :- flush(Acc, [], Ws).
raw_words([C|Cs], Acc, Ws) :-
    (   word_char(C) -> raw_words(Cs, [C|Acc], Ws)
    ;   memberchk(C, `'’`), Acc \== [] -> raw_words(Cs, Acc, Ws)     % pony's -> ponys
    ;   ( C =:= 0'. ; C =:= 0', ), Acc = [P|_], code_type(P, digit), Cs = [N|_], code_type(N, digit)
    ->  raw_words(Cs, [0'_|Acc], Ws)
    ;   flush(Acc, Ws0, Ws), raw_words(Cs, [], Ws0)
    ).

flush([], Rest, Rest) :- !.
flush(Acc, Rest, [W|Rest]) :- reverse(Acc, Cs), atom_codes(W, Cs).

word_char(C) :- code_type(C, alnum), C =\= 0'_ .
word_char(C) :- C > 127, \+ code_type(C, space), \+ memberchk(C, `‘’“”–—`).

%   isAffordable → [is, Affordable]; RiskCategory → [Risk, Category];
%   HTTPServer → [HTTP, Server]; words in capitals stay whole.
split_camel(W, Ws) :-
    atom_codes(W, Cs),
    (   forall(member(C, Cs), \+ code_type(C, lower)) -> Ws = [W]
    ;   camel(Cs, Parts), maplist([P, A]>>atom_codes(A, P), Parts, Ws)
    ).

camel([], []).
camel([C|Cs], [W|Ws]) :-
    (   code_type(C, upper), Cs = [D|_], code_type(D, upper)
    ->  take_caps([C|Cs], W, Rest)          % an acronym: HTTP of HTTPServer
    ;   take_lower(Cs, W0, Rest), W = [C|W0]
    ),
    camel(Rest, Ws).

take_lower([C|Cs], [C|W], R) :- \+ code_type(C, upper), !, take_lower(Cs, W, R).
take_lower(R, [], R).

%   Capitals up to the one that starts the next word (the capital before a
%   lower-case letter).
take_caps([C, D|Cs], [C|W], R) :- code_type(C, upper), code_type(D, upper), !, take_caps([D|Cs], W, R).
take_caps([C], [C], []) :- code_type(C, upper), !.
take_caps([C, D|Cs], [C], [D|Cs]) :- code_type(C, upper), \+ code_type(D, lower), !.
take_caps(R, [], R).

%   A number joins the word before it: [artikel, '22_28', a] → [artikel_22_28_a].
join_numbers([W, N|Ws], Out) :-
    digitish(N), \+ digitish(W), !,
    atomic_list_concat([W, N], '_', WN0),
    (   Ws = [L|Ws1], atom_length(L, 1), L @>= a, L @=< z
    ->  atomic_list_concat([WN0, L], '_', WN), join_numbers([WN|Ws1], Out)
    ;   join_numbers([WN0|Ws], Out)
    ).
join_numbers([N|Ws], Out) :-
    digitish(N), !, atom_concat(n, N, NW), join_numbers([NW|Ws], Out).
join_numbers([W|Ws], [W|Out]) :- join_numbers(Ws, Out).
join_numbers([], []).

digitish(W) :- atom_codes(W, [C|_]), code_type(C, digit).

drop_articles(Ws0, Ws) :- exclude([W]>>memberchk(W, [a, an]), Ws0, Ws).

reserved_safe(Ws0, Ws) :- reserved_safe_(Ws0, [], Ws).

reserved_safe_([], Acc, Ws) :- reverse(Acc, Ws).
reserved_safe_([W|Ws], Acc, Out) :-
    (   \+ reserved_word(W)
    ->  reserved_safe_(Ws, [W|Acc], Out)
    ;   Ws = [N|Rest]
    ->  atomic_list_concat([W, N], '_', WN), reserved_safe_([WN|Rest], Acc, Out)
    ;   Acc = [P|As]
    ->  atomic_list_concat([P, W], '_', PW), reserved_safe_([], [PW|As], Out)
    ;   atom_concat(W, '_', W2), reserved_safe_([], [W2|Acc], Out)
    ).

%   The words that end a template instance in English LE
%   (le_grammar:reserved_template_truncator/4), asked of LE2's keyword table.
reserved_word(W) :-
    current_predicate(le_i18n:kw_synonym_words/3),
    member(Key, [if, only_if, unless, and_unless, either, any_of, all_of, expects, otherwise]),
    catch(le_i18n:kw_synonym_words(en, Key, [W]), _, fail), !.
reserved_word(W) :- memberchk(W, [if, unless, expects, otherwise, then, when, which, who, what]).
%   The copula: a sentence that holds the name goes on with `is`, and an
%   `is` among the name's own words would be taken for it.
reserved_word(is).
reserved_word(are).

%!  type_noun(+TypeRef, -Noun) is det.
%
%   The noun of a template's place for a value of a FEEL type.
type_noun(T0, Noun) :-
    ( atom(T0) -> T1 = T0 ; atom_string(T1, T0) ),
    ( sub_atom(T1, B, _, 0, ':') -> true ; true ),
    ( sub_atom(T1, B2, 1, _, ':') -> B3 is B2 + 1, sub_atom(T1, B3, _, 0, T) ; T = T1 ), ignore(B = 0),
    downcase_atom(T, L),
    (   memberchk(L, [number, integer, decimal, double, long, int]) -> Noun = number
    ;   memberchk(L, [string]) -> Noun = text
    ;   memberchk(L, [boolean]) -> Noun = 'truth value'
    ;   L == date -> Noun = date
    ;   memberchk(L, ['date and time', datetime]) -> Noun = 'date and time'
    ;   L == time -> Noun = time
    ;   sub_atom(L, _, _, _, duration) -> Noun = duration
    ;   Noun = value
    ).

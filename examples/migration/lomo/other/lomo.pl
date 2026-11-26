/*  lib/lomo.pl — what lib/lomo.le cannot say in sentences: ELI addresses and
    ISO 8601 lengths of time.

    A library, not syntax. The predicates at the end are templates of
    lomo.le, under the names LE gives them (a template's words, its slots
    left out), with their arguments in the order of the slots.

    Loaded assert-only as a Prolog resource (docs/user/reference/language.md §14.1).
    Copyright Miguel Calejo; Apache License 2.0.
*/

%   LE's reasoner runs these clauses itself, and it does not honour a cut:
%   so every choice below is an if-then-else, and no clause needs a cut.

%   ---- ELI: the European Legislation Identifier ------------------------
%
%   http://data.europa.eu/eli/dir/2013/34/art_30/par_1/oj
%       act:   http://data.europa.eu/eli/dir/2013/34/oj
%       place: Article 30(1)
%   The act is the address without its subdivisions (art_, par_, pnt_, ...);
%   the parts after the last subdivision (oj, a version, a language) stay.

le_lomo_text(X, A) :- ( string(X) -> atom_string(A, X) ; atom(X) -> A = X ).

le_lomo_subdivision(Seg, Kind, Id) :-
    atom(Seg),
    ( sub_atom(Seg, B0, 1, _, '_') -> B = B0 ; fail ),
    sub_atom(Seg, 0, B, _, Kind),
    le_lomo_subdivision_kind(Kind, _),
    B1 is B + 1, sub_atom(Seg, B1, _, 0, Id).

le_lomo_subdivision_kind(art, article).
le_lomo_subdivision_kind(par, paragraph).
le_lomo_subdivision_kind(pnt, point).
le_lomo_subdivision_kind(sub, subparagraph).
le_lomo_subdivision_kind(anx, annex).
le_lomo_subdivision_kind(rct, recital).
le_lomo_subdivision_kind(cpt, chapter).
le_lomo_subdivision_kind(tit, title).
le_lomo_subdivision_kind(sct, section).
le_lomo_subdivision_kind(prt, part).
le_lomo_subdivision_kind(cit, citation).
le_lomo_subdivision_kind(enc, enacting).
le_lomo_subdivision_kind(lst, list).

le_lomo_eli_parts(Address, Before, Subs, After) :-
    le_lomo_text(Address, A),
    sub_atom(A, _, _, _, '/eli/'),
    atomic_list_concat(Segs, '/', A),
    le_lomo_before(Segs, Before, Rest),
    le_lomo_last_sub(Rest, Subs, After).

%   The segments before the first subdivision, and the rest.
le_lomo_before([S|Ss], Before, Rest) :-
    (   le_lomo_subdivision(S, _, _)
    ->  Before = [], Rest = [S|Ss]
    ;   Before = [S|Bs], le_lomo_before(Ss, Bs, Rest)
    ).

%   The subdivisions, up to the last one, and the segments after it.
le_lomo_last_sub(Segs, Subs, After) :-
    le_lomo_last_sub_index(Segs, 1, 0, Last),
    Last > 0,
    length(Subs, Last),
    append(Subs, After, Segs).

le_lomo_last_sub_index([], _, L, L).
le_lomo_last_sub_index([S|Ss], I, L0, L) :-
    ( le_lomo_subdivision(S, _, _) -> L1 = I ; L1 = L0 ),
    I1 is I + 1,
    le_lomo_last_sub_index(Ss, I1, L1, L).

le_lomo_act(Provision, Act) :-
    (   le_lomo_eli_parts(Provision, Before, _, After0)
    ->  le_lomo_drop_empty(After0, After),
        append(Before, After, Segs),
        atomic_list_concat(Segs, '/', ActA),
        atom_string(ActA, Act)
    ;   le_lomo_text(Provision, A),
        sub_atom(A, _, _, _, '/eli/'),
        atom_string(A, Act)
    ).

le_lomo_drop_empty([], []).
le_lomo_drop_empty([H|T], R) :-
    ( H == '' -> R = R1 ; R = [H|R1] ),
    le_lomo_drop_empty(T, R1).

le_lomo_place(Provision, Text) :-
    le_lomo_eli_parts(Provision, _, Subs, _),
    le_lomo_place_parts(Subs, "", Text),
    Text \== "".

le_lomo_place_parts([], T, T).
le_lomo_place_parts([Seg|Segs], Acc, T) :-
    (   le_lomo_subdivision(Seg, Kind, Id)
    ->  (   le_lomo_heading(Kind, Word)
        ->  ( Acc == "" -> Sep = "" ; Sep = ", " ),
            format(string(Acc1), "~w~w~w ~w", [Acc, Sep, Word, Id])
        ;   format(string(Acc1), "~w(~w)", [Acc, Id])
        )
    ;   Acc1 = Acc
    ),
    le_lomo_place_parts(Segs, Acc1, T).

le_lomo_heading(art, 'Article').
le_lomo_heading(anx, 'Annex').
le_lomo_heading(rct, 'Recital').
le_lomo_heading(cpt, 'Chapter').
le_lomo_heading(tit, 'Title').
le_lomo_heading(sct, 'Section').
le_lomo_heading(prt, 'Part').
le_lomo_heading(cit, 'Citation').
le_lomo_heading(enc, 'Enacting terms').

%   ---- instants ---------------------------------------------------------
%   An instant is a date, or a text the description typed otherwise: a date
%   and time ("2026-04-12T14:00:00": its day), a year ("2035": its first
%   or last day), a year and a month ("2035-06").

le_lomo_instant_days(date(Y, M, D), date(Y, M, D), date(Y, M, D)).
le_lomo_instant_days(T, First, Last) :-
    ( string(T) ; atom(T) ),
    le_lomo_digits_dashes(T, Parts),
    le_lomo_instant_parts(Parts, First, Last).

%   Built-ins only (split_string/4, not append/3): the reasoner may interpret
%   a library predicate clause by clause, which is slow on a long list.
le_lomo_digits_dashes(T, Parts) :-
    split_string(T, "T", "", [Day|_]),
    atom_string(A, Day),
    atomic_list_concat(Ps, '-', A),
    le_lomo_numbers(Ps, Parts).

le_lomo_numbers([], []).
le_lomo_numbers([P|Ps], [N|Ns]) :- atom_number(P, N), integer(N), le_lomo_numbers(Ps, Ns).

le_lomo_instant_parts([Y, M, D], date(Y, M, D), date(Y, M, D)).
le_lomo_instant_parts([Y, M], date(Y, M, 1), date(Y, M, L)) :- le_temporal_days_in_month(Y, M, L).
le_lomo_instant_parts([Y], date(Y, 1, 1), date(Y, 12, 31)) :- Y > 999.

%   ---- The templates of lomo.le ----------------------------------------

the_act_of_is(Provision, Act) :- le_lomo_act(Provision, Act).
the_place_of_in_its_act_is(Provision, Text) :- le_lomo_place(Provision, Text).
the_first_day_of_the_instant_is(I, D) :- le_lomo_instant_days(I, D, _).
the_last_day_of_the_instant_is(I, D) :- le_lomo_instant_days(I, _, D).

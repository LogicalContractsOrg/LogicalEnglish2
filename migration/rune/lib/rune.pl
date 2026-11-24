% The operations of Rune that are Prolog here (lib/rune.le is their layer):
% lists, texts, and the functions DRR implements in Java. Pure predicates,
% read by LE2 as a Prolog resource (language.md, section 14.1).

rune_only_element(L, V) :- L = [V].
rune_first([V|_], V).
rune_last(L, V) :- last(L, V).
% An input of one value or none: the value, or nothing.
rune_or_nothing([V], V) :- !.
rune_or_nothing(_, nothing).
% Rune's min [key], max [key], sort [key]: the elements and their keys in the
% same order; an element without a key is left out.
rune_min_by(L, Ks, V) :- rune_keyed(L, Ks, Ps), Ps \== [], pairs_keys(Ps, Keys),
    min_member(Km, Keys), member(K-V, Ps), K == Km, !.       % the first of the least
rune_max_by(L, Ks, V) :- rune_keyed(L, Ks, Ps), Ps \== [], pairs_keys(Ps, Keys),
    max_member(Km, Keys), member(K-V, Ps), K == Km, !.       % the first of the greatest
rune_sorted_by(L, Ks, S) :- rune_keyed(L, Ks, Ps), keysort(Ps, S0), pairs_values(S0, S).
rune_keyed([], _, []).
rune_keyed([E|Es], [K|Ks], Ps) :- ( K == nothing -> Ps = Ps1 ; Ps = [K-E|Ps1] ), rune_keyed(Es, Ks, Ps1).
% Rune's min and max, of numbers, dates or texts (standard order).
rune_min(L, V) :- L \== [], min_member(V, L).
rune_max(L, V) :- L \== [], max_member(V, L).
rune_distinct(L, D) :- list_to_set(L, D).
rune_reverse(L, R) :- reverse(L, R).
rune_sorted(L, S) :- msort(L, S).
rune_concat(A, B, C) :- rune_text(A, SA), rune_text(B, SB), string_concat(SA, SB, C).
% Rune's to-string: Java's text of the value; a time with zero seconds is
% written without them (2024-04-29T00:00Z), as java.time writes it.
rune_to_string(V, S) :-
    rune_text(V, S0),
    (   string_length(S0, N), N >= 20,
        sub_string(S0, 10, 1, _, "T"), sub_string(S0, 16, 3, _, ":00"),
        sub_string(S0, 19, _, 0, Zone), ( Zone == "Z" ; sub_string(Zone, 0, 1, _, "+") ; sub_string(Zone, 0, 1, _, "-") )
    ->  sub_string(S0, 0, 16, _, Pre), string_concat(Pre, Zone, S)
    ;   S = S0
    ).
rune_to_number(V, N) :- ( number(V) -> N = V ; rune_text(V, S), number_string(N, S) ).
rune_contains_all(L1, L2) :- L1 \== [], L2 \== [], forall(member(X, L2), memberchk(X, L1)).
rune_disjoint(L1, L2) :- \+ ( member(X, L1), memberchk(X, L2) ).
rune_earlier(A, B) :- rune_text(A, SA), rune_text(B, SB), SA @< SB.
rune_join(L, Sep, S) :- maplist(rune_text, L, Ts), rune_text(Sep, TS), atomic_list_concat(Ts, TS, A), atom_string(A, S).
% CDM's RoundToPrecision and RoundToSignificantFigures (implemented in Java):
% Up, Down, or Nearest (half up), in exact decimals; an integral result is an
% integer, as the reports write it.
rune_round_to_precision(V, P, Dir, R) :-
    number(V), integer(P),
    rune_pow10(P, F), X is rationalize(V) * F, rune_round_rat(X, Dir, N),
    R0 is N / F, rune_number(R0, R).
rune_round_to_significant(V, S, Dir, R) :-
    number(V), integer(S),
    (   V =:= 0 -> R = 0
    ;   A is abs(rationalize(V)), rune_digits(A, E), P is S - E,
        rune_pow10(P, F), X is rationalize(V) * F, rune_round_rat(X, Dir, N),
        R0 is N / F, rune_number(R0, R)
    ).
% 10 to the power P, exact for a negative P too (10^ -1 would be the float 0.1).
rune_pow10(P, F) :- ( P >= 0 -> F is 10^P ; F is 1 rdiv 10^(-P) ).
% The digits of A's integer part (its exponent plus one): 10^(E-1) =< A < 10^E,
% exact (log10 of 9999999999999999999999999 is the float 25.0, one too many).
rune_digits(A, E) :-
    E0 is floor(log10(float(A))) + 1, rune_digits_fix(A, E0, E).
rune_digits_fix(A, E0, E) :- rune_pow10(E0, F), A >= F, !, E1 is E0 + 1, rune_digits_fix(A, E1, E).
rune_digits_fix(A, E0, E) :- E1 is E0 - 1, rune_pow10(E1, F), A < F, !, rune_digits_fix(A, E1, E).
rune_digits_fix(_, E, E).
rune_round_rat(X, "Up", N) :- !, ( X >= 0 -> N is ceiling(X) ; N is floor(X) ).
rune_round_rat(X, "Down", N) :- !, N is truncate(X).
rune_round_rat(X, _, N) :- ( X >= 0 -> N is floor(X + 1r2) ; N is -floor(-X + 1r2) ).
rune_number(R0, R) :- ( R0 =:= truncate(R0) -> R is truncate(R0) ; R is float(R0) ).

% CDM's AddDays, DateDifference, LeapYearDateDifference (Java), on ISO
% dates written as texts (2023-05-11).
rune_add_days(D, N, R) :- rune_day(D, J), J1 is J + N, rune_day(R, J1).
% CDM's DayOfWeek: MON .. SUN (day 0 of the stamps, 1 January 1970, was a Thursday)
rune_day_of_week(D, W) :- rune_day(D, J), I is (J + 3) mod 7, nth0(I, ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"], W).
rune_date_difference(D1, D2, N) :- rune_day(D1, J1), rune_day(D2, J2), N is J2 - J1.
% the 29 Februaries from the first date (exclusive) to the second (inclusive)
rune_leap_days(D1, D2, N) :-
    rune_day(D1, J1), rune_day(D2, J2),
    ( J1 =< J2 -> A = J1, B = J2, S = 1 ; A = J2, B = J1, S = -1 ),
    aggregate_all(count, ( between(A, B, J), J > A, rune_day(T, J), sub_string(T, 5, 5, _, "02-29") ), C),
    N is S * C.
rune_day(D, J) :-
    nonvar(D), !, rune_text(D, T), sub_string(T, 0, 10, _, Ds),
    split_string(Ds, "-", "", [Y, M, Dd]), number_string(YN, Y), number_string(MN, M), number_string(DN, Dd),
    date_time_stamp(date(YN, MN, DN, 0, 0, 0, 0, -, -), St), J is round(St / 86400).
rune_day(D, J) :-
    St is J * 86400, stamp_date_time(St, date(Y, M, Dd, _, _, _, _, _, _), 'UTC'),
    format(string(D), "~d-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, Dd]).

% DRR's testing clock (DrrRuntimeModuleTesting): the reporting time of its test packs.
rune_now("2024-04-29T00:00:00Z").


rune_text(V, S) :- string(V), !, S = V.
rune_text(V, S) :- number(V), !, number_string(V, S).
rune_text(V, S) :- atom(V), !, atom_string(V, S).
rune_text(V, S) :- term_string(V, S).

% An object a Rune constructor builds: the place it is built at and the
% values it is built from (Rune compares objects by their content). Known
% objects only: asked about an object nobody has built, the answer is no,
% rather than every object the rules could build.
rune_object_0(Site, O) :- rune_object(Site, [], O).
rune_object_1(Site, I1, O) :- rune_object(Site, [I1], O).
rune_object_2(Site, I1, I2, O) :- rune_object(Site, [I1, I2], O).
rune_object_3(Site, I1, I2, I3, O) :- rune_object(Site, [I1, I2, I3], O).
rune_object_4(Site, I1, I2, I3, I4, O) :- rune_object(Site, [I1, I2, I3, I4], O).
rune_object_5(Site, I1, I2, I3, I4, I5, O) :- rune_object(Site, [I1, I2, I3, I4, I5], O).
rune_object_6(Site, I1, I2, I3, I4, I5, I6, O) :- rune_object(Site, [I1, I2, I3, I4, I5, I6], O).
rune_object_7(Site, I1, I2, I3, I4, I5, I6, I7, O) :- rune_object(Site, [I1, I2, I3, I4, I5, I6, I7], O).
rune_object_8(Site, I1, I2, I3, I4, I5, I6, I7, I8, O) :- rune_object(Site, [I1, I2, I3, I4, I5, I6, I7, I8], O).

rune_object(Site, Inputs, O) :-
    (   nonvar(O) -> O = o(Site, Inputs)
    ;   ground(Inputs) -> O = o(Site, Inputs)
    ).

% DRR's StringContains (drr.regulation.common.util.functions.StringContainsImpl):
% Java's String.matches, the whole text against a regular expression. A small
% matcher of the expressions DRR writes: literals, ., classes [a-z0-9\\:._-]
% and their negation, \\d \\w \\s, groups (...) and (?:...), alternatives |,
% * + ? {m} {m,} {m,n}, and ^ $ at the ends.
rune_string_contains(T, R) :-
    rune_text(T, ST), rune_text(R, SR),
    string_codes(SR, RC), rx_alt(Re, RC, []), !,
    string_codes(ST, TC),
    rx_match(Re, TC, []), !.

% (the grammar of the expressions, as plain clauses: a Prolog resource is
% read as it is written)
:- non_terminal(user:rx_alt/3).
rx_alt(A, B, C) :-
    rx_seq(D, B, E),
    (   E=[124|F]
    ->  rx_alt(G, F, H),
        A=alt(D, G),
        C=H
    ;   A=D,
        C=E
    ).
:- non_terminal(user:rx_seq/3).
rx_seq([A|B], C, D) :-
    rx_piece(A, C, E),
    !,
    F=E,
    rx_seq(B, F, D).
:- non_terminal(user:rx_seq/3).
rx_seq([], A, B) :-
    A=B.
:- non_terminal(user:rx_piece/3).
rx_piece(A, B, C) :-
    rx_atom(D, B, E),
    rx_quant(D, A, E, C).
:- non_terminal(user:rx_atom/3).
rx_atom(any, A, B) :-
    A=[46|C],
    !,
    B=C.
:- non_terminal(user:rx_atom/3).
rx_atom(bol, A, B) :-
    A=[94|C],
    !,
    B=C.
:- non_terminal(user:rx_atom/3).
rx_atom(eol, A, B) :-
    A=[36|C],
    !,
    B=C.
:- non_terminal(user:rx_atom/3).
rx_atom(A, B, C) :-
    B=[40, 63, 58|D],
    !,
    E=D,
    rx_alt(A, E, F),
    F=[41|C].
:- non_terminal(user:rx_atom/3).
rx_atom(A, B, C) :-
    B=[40|D],
    !,
    E=D,
    rx_alt(A, E, F),
    F=[41|C].
:- non_terminal(user:rx_atom/3).
rx_atom(class(A, B), C, D) :-
    C=[91|E],
    !,
    F=E,
    (   F=[94|G]
    ->  A=true,
        H=G
    ;   A=false,
        H=F
    ),
    rx_class(B, H, I),
    I=[93|D].
:- non_terminal(user:rx_atom/3).
rx_atom(set(A), B, C) :-
    B=[92|D],
    D=[E|F],
    rx_escape(E, A),
    G=F,
    !,
    C=G.
:- non_terminal(user:rx_atom/3).
rx_atom(chr(A), B, C) :-
    B=[A|D],
    \+ memberchk(A, [124, 41, 42, 43, 63, 123]),
    C=D.
:- non_terminal(user:rx_quant/4).
rx_quant(A, rep(A, 0, inf), B, C) :-
    B=[42|D],
    !,
    C=D.
:- non_terminal(user:rx_quant/4).
rx_quant(A, rep(A, 1, inf), B, C) :-
    B=[43|D],
    !,
    C=D.
:- non_terminal(user:rx_quant/4).
rx_quant(A, rep(A, 0, 1), B, C) :-
    B=[63|D],
    !,
    C=D.
:- non_terminal(user:rx_quant/4).
rx_quant(A, rep(A, B, C), D, E) :-
    D=[123|F],
    rx_int(B, F, G),
    (   G=[44|H]
    ->  (   rx_int(C, H, I)
        ->  I=J
        ;   C=inf,
            J=H
        )
    ;   C=B,
        J=G
    ),
    J=[125|K],
    !,
    E=K.
:- non_terminal(user:rx_quant/4).
rx_quant(A, A, B, C) :-
    B=C.
:- non_terminal(user:rx_int/3).
rx_int(A, B, C) :-
    rx_digits(D, B, E),
    D\==[],
    number_codes(A, D),
    C=E.
:- non_terminal(user:rx_digits/3).
rx_digits([A|B], C, D) :-
    C=[A|E],
    code_type(A, digit),
    F=E,
    !,
    G=F,
    rx_digits(B, G, D).
:- non_terminal(user:rx_digits/3).
rx_digits([], A, B) :-
    A=B.
:- non_terminal(user:rx_class/3).
rx_class([A|B], C, D) :-
    rx_class_item(A, C, E),
    !,
    F=E,
    rx_class(B, F, D).
:- non_terminal(user:rx_class/3).
rx_class([], A, B) :-
    A=B.
:- non_terminal(user:rx_class_item/3).
rx_class_item(range(A, B), C, D) :-
    rx_class_char(A, C, E),
    E=[45|F],
    rx_class_char(B, F, G),
    !,
    D=G.
:- non_terminal(user:rx_class_item/3).
rx_class_item(set(A), B, C) :-
    B=[92|D],
    D=[E|F],
    rx_escape(E, A),
    G=F,
    !,
    C=G.
:- non_terminal(user:rx_class_item/3).
rx_class_item(chr(A), B, C) :-
    rx_class_char(A, B, C).
:- non_terminal(user:rx_class_char/3).
rx_class_char(A, B, C) :-
    B=[92|D],
    D=[A|E],
    \+ rx_escape(A, _),
    F=E,
    !,
    C=F.
:- non_terminal(user:rx_class_char/3).
rx_class_char(A, B, C) :-
    B=[A|D],
    A\==93,
    C=D.
rx_escape(100, digit).
rx_escape(119, word).
rx_escape(115, space).
rx_match([], T, T).
rx_match([X|Xs], T0, T) :- rx_one(X, T0, T1), rx_match(Xs, T1, T).
rx_match(alt(A, B), T0, T) :- ( rx_match(A, T0, T) ; rx_match(B, T0, T) ).

rx_one(bol, T, T).
rx_one(eol, [], []).
rx_one(rep(A, M, N), T0, T) :- rx_rep(A, M, N, T0, T).
rx_one(alt(A, B), T0, T) :- rx_match(alt(A, B), T0, T).
rx_one(L, T0, T) :- is_list(L), rx_match(L, T0, T).
rx_one(any, [_|T], T).
rx_one(chr(C), [C|T], T).
rx_one(set(S), [C|T], T) :- rx_in_set(S, C).
rx_one(class(Neg, Items), [C|T], T) :-
    ( member(I, Items), rx_in_item(I, C) -> In = true ; In = false ),
    In \== Neg.

rx_in_item(range(A, B), C) :- C >= A, C =< B.
rx_in_item(chr(C), C).
rx_in_item(set(S), C) :- rx_in_set(S, C).
rx_in_set(digit, C) :- code_type(C, digit).
rx_in_set(word, C) :- code_type(C, csym).
rx_in_set(space, C) :- code_type(C, space).

% greedy, then fewer
rx_rep(A, M, N, T0, T) :-
    ( N \== 0, rx_one(A, T0, T1), T1 \== T0,
      M1 is max(0, M - 1), ( N == inf -> N1 = inf ; N1 is N - 1 ),
      rx_rep(A, M1, N1, T1, T)
    ; M =:= 0, T = T0 ).
% Rune's built-in features of a time and a date (2021-03-13T06:32:49Z):
% its date (2021-03-13), its time (06:32:49), its time zone (Z); a date's
% year, month and day as numbers.
rune_date_part(T, D) :- rune_text(T, S), string_length(S, L), L >= 10, sub_string(S, 0, 10, _, D).
rune_time_part(T, H) :- rune_text(T, S), sub_string(S, B, 1, _, "T"), !, B1 is B + 1, sub_string(S, B1, 8, _, H).
rune_timezone_part(T, Z) :- rune_text(T, S), string_length(S, L), L > 19, sub_string(S, 19, _, 0, Z0), ( sub_string(Z0, 0, 1, _, ".") -> sub_string(Z0, P, _, 0, Z), sub_string(Z0, P, 1, _, C), memberchk(C, ["Z", "+", "-"]), ! ; Z = Z0 ).
rune_year_part(D, Y) :- rune_text(D, S), sub_string(S, 0, 4, _, YS), number_string(Y, YS).
rune_month_part(D, M) :- rune_text(D, S), sub_string(S, 5, 2, _, MS), number_string(M, MS).
rune_day_part(D, N) :- rune_text(D, S), sub_string(S, 8, 2, _, DS), number_string(N, DS).

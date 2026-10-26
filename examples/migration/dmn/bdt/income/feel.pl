/*  lib/feel.pl — the predicates behind lib/feel.le

    FEEL's built-in functions (DMN §10.3.4) that lib/text, lib/rounding,
    lib/temporal and lib/maths do not have. Positions in a text count from
    1, as FEEL counts them; a negative start counts from the end. The mean
    of an empty list, like FEEL's, has no value. `today` is the date of the
    machine that runs the query.

    The predicates at the end are the templates of feel.le, under the names
    LE gives them (a template's words, its slots left out), with their
    arguments in the order of the slots: LE calls them directly.

    Loaded assert-only as a Prolog resource (docs/user/reference/language.md
    §14.1). No cuts and no closures in this file: LE's reasoner runs a
    resource's clauses itself — each clause carries the test that tells it
    from the others.
*/

le_feel_string(X, S) :- string(X), S = X.
le_feel_string(X, S) :- atom(X), atom_string(X, S).

le_feel_date(T, date(Y, M, D)) :-
    le_feel_string(T, S), split_string(S, "-", "", [Ys, Ms, Ds]),
    number_string(Y, Ys), number_string(M, Ms), number_string(D, Ds).

le_feel_substring(T, Start, Len, P) :-
    le_feel_string(T, S), string_length(S, L), Start > 0,
    B is Start - 1, B =< L, Len >= 0, Take is min(Len, L - B),
    sub_string(S, B, Take, _, P).
le_feel_substring(T, Start, Len, P) :-
    le_feel_string(T, S), string_length(S, L), Start < 0,
    B is max(L + Start, 0), Len >= 0, Take is min(Len, L - B),
    sub_string(S, B, Take, _, P).

le_feel_rest(T, Start, P) :-
    le_feel_string(T, S), string_length(S, L), Len is L, le_feel_substring(S, Start, Len, P).

le_feel_number(T, N) :- le_feel_string(T, S), number_string(N, S).

%   FEEL's modulo: the result has the sign of the divisor.
le_feel_remainder(A, B, R) :- B =\= 0, R0 is A - B * floor(A / B), le_feel_whole(R0, R).

le_feel_whole(X, X) :- integer(X).
le_feel_whole(X, Y) :- float(X), X =:= truncate(X), abs(X) < 1.0e15, Y is truncate(X).
le_feel_whole(X, X) :- float(X), X =\= truncate(X).
le_feel_whole(X, X) :- float(X), abs(X) >= 1.0e15.

le_feel_sum([], 0).
le_feel_sum([X|Xs], S) :- number(X), le_feel_sum(Xs, S0), S is S0 + X.

le_feel_min([X], X) :- number(X).
le_feel_min([X, Y|Zs], M) :- le_feel_min([Y|Zs], M0), M is min(X, M0).

le_feel_max([X], X) :- number(X).
le_feel_max([X, Y|Zs], M) :- le_feel_max([Y|Zs], M0), M is max(X, M0).

le_feel_all([]).
le_feel_all([true|Xs]) :- le_feel_all(Xs).

le_feel_any([true|_]).
le_feel_any([X|Xs]) :- X \== true, le_feel_any(Xs).

%   FEEL's round up / round down / round half down: away from zero, toward
%   zero, and half toward zero, at a number of decimals, exactly.
le_feel_scaled(X, D, S) :- R is rationalize(X), S is R * 10^D.
le_feel_unscale(I, D, V) :- D =< 0, V is I * 10^(-D).
le_feel_unscale(I, D, V) :- D > 0, V0 is I / 10^D, le_feel_number_value(V0, V).
le_feel_number_value(V0, V) :- integer(V0), V = V0.
le_feel_number_value(V0, V) :- \+ integer(V0), V is float(V0).

le_feel_away(X, D, V) :- le_feel_scaled(X, D, S), S >= 0, I is ceiling(S), le_feel_unscale(I, D, V).
le_feel_away(X, D, V) :- le_feel_scaled(X, D, S), S < 0, I is floor(S), le_feel_unscale(I, D, V).
le_feel_toward(X, D, V) :- le_feel_scaled(X, D, S), I is truncate(S), le_feel_unscale(I, D, V).
le_feel_half_down(X, D, V) :- le_feel_scaled(X, D, S), S >= 0, I is ceiling(S - 1r2), le_feel_unscale(I, D, V).
le_feel_half_down(X, D, V) :- le_feel_scaled(X, D, S), S < 0, I is -ceiling(-S - 1r2), le_feel_unscale(I, D, V).

le_feel_before(T, P, B) :- le_feel_string(T, S), le_feel_string(P, Q), sub_string(S, I, _, _, Q), sub_string(S, 0, I, _, B).
le_feel_before(T, P, "") :- le_feel_string(T, S), le_feel_string(P, Q), \+ sub_string(S, _, _, _, Q).
le_feel_after(T, P, A) :- le_feel_string(T, S), le_feel_string(P, Q), sub_string(S, I, L, _, Q), J is I + L, sub_string(S, J, _, 0, A).
le_feel_after(T, P, "") :- le_feel_string(T, S), le_feel_string(P, Q), \+ sub_string(S, _, _, _, Q).

le_feel_strings([], []).
le_feel_strings([X|Xs], [S|Ss]) :- le_feel_string(X, S), le_feel_strings(Xs, Ss).
le_feel_join(L, D, S) :- le_feel_strings(L, Ss), le_feel_string(D, DS), atomic_list_concat(Ss, DS, A), atom_string(A, S).

le_feel_product([], 1).
le_feel_product([X|Xs], P) :- number(X), le_feel_product(Xs, P0), P is P0 * X.

le_feel_median(L, M) :- L \== [], msort(L, S), length(S, N), N mod 2 =:= 1, I is N // 2 + 1, le_feel_nth(I, S, M).
le_feel_median(L, M) :- L \== [], msort(L, S), length(S, N), N mod 2 =:= 0, I is N // 2, J is I + 1,
    le_feel_nth(I, S, A), le_feel_nth(J, S, B), M0 is (A + B) / 2, le_feel_whole(M0, M).

le_feel_reverse(L, R) :- le_feel_reverse(L, [], R).
le_feel_reverse([], A, A).
le_feel_reverse([X|Xs], A, R) :- le_feel_reverse(Xs, [X|A], R).

le_feel_distinct([], _, []).
le_feel_distinct([X|Xs], Seen, Out) :- memberchk(X, Seen), le_feel_distinct(Xs, Seen, Out).
le_feel_distinct([X|Xs], Seen, [X|Out]) :- \+ memberchk(X, Seen), le_feel_distinct(Xs, [X|Seen], Out).

le_feel_flatten([], []).
le_feel_flatten([X|Xs], F) :- is_list(X), le_feel_flatten(X, FX), le_feel_flatten(Xs, FXs), le_feel_append(FX, FXs, F).
le_feel_flatten([X|Xs], [X|F]) :- \+ is_list(X), le_feel_flatten(Xs, F).

le_feel_append([], L, L).
le_feel_append([X|Xs], L, [X|R]) :- le_feel_append(Xs, L, R).

le_feel_concat([], []).
le_feel_concat([L|Ls], R) :- is_list(L), le_feel_concat(Ls, R0), le_feel_append(L, R0, R).

le_feel_drop(0, L, L).
le_feel_drop(N, [_|Xs], R) :- N > 0, N1 is N - 1, le_feel_drop(N1, Xs, R).
le_feel_take(0, _, []).
le_feel_take(N, [X|Xs], [X|R]) :- N > 0, N1 is N - 1, le_feel_take(N1, Xs, R).
le_feel_take(N, [], []) :- N > 0.

le_feel_start(S, L, B) :- integer(S), S > 0, B is S - 1, length(L, N), B < N.
le_feel_start(S, L, B) :- integer(S), S < 0, length(L, N), B is N + S, B >= 0.

le_feel_sublist(L, S, R) :- le_feel_start(S, L, B), le_feel_drop(B, L, R).
le_feel_sublist(L, S, Len, R) :- le_feel_start(S, L, B), le_feel_drop(B, L, R0), le_feel_take(Len, R0, R).
le_feel_remove(L, P, R) :- le_feel_start(P, L, B), le_feel_take(B, L, A), B1 is B + 1, le_feel_drop(B1, L, Z), le_feel_append(A, Z, R).
le_feel_insert(L, P, X, R) :- le_feel_start(P, L, B), le_feel_take(B, L, A), le_feel_drop(B, L, Z), le_feel_append(A, [X|Z], R).

le_feel_positions([], _, _, []).
le_feel_positions([X|Xs], V, I, [I|Ps]) :- X == V, I1 is I + 1, le_feel_positions(Xs, V, I1, Ps).
le_feel_positions([X|Xs], V, I, Ps) :- X \== V, I1 is I + 1, le_feel_positions(Xs, V, I1, Ps).

le_feel_union(Ls, U) :- le_feel_concat(Ls, C), le_feel_distinct(C, [], U).

%   FEEL's all() and any(): three values, and a single value counts as a
%   list of one.
le_feel_items(L, L) :- is_list(L).
le_feel_items(X, [X]) :- \+ is_list(X).
le_feel_all(L, true) :- le_feel_items(L, Xs), le_feel_booleans(Xs), \+ memberchk(false, Xs).
le_feel_all(L, false) :- le_feel_items(L, Xs), le_feel_booleans(Xs), memberchk(false, Xs).
le_feel_any(L, true) :- le_feel_items(L, Xs), le_feel_booleans(Xs), memberchk(true, Xs).
le_feel_any(L, false) :- le_feel_items(L, Xs), le_feel_booleans(Xs), \+ memberchk(true, Xs).
le_feel_booleans([]).
le_feel_booleans([X|Xs]) :- ( X == true ; X == false ), le_feel_booleans(Xs).

%   FEEL's list[i]: from 1, and from the end when negative.
le_feel_item(I, L, X) :- integer(I), I > 0, le_feel_nth(I, L, X).
le_feel_item(I, L, X) :- integer(I), I < 0, length(L, N), J is N + I + 1, J > 0, le_feel_nth(J, L, X).

le_feel_item(I, L, X) :- float(I), I =:= truncate(I), J is truncate(I), le_feel_item(J, L, X).

%   (Not nth1/3: the reasoner runs this file's clauses itself, and a
%   library predicate is not one of them.)
le_feel_nth(1, [X|_], X).
le_feel_nth(I, [_|Xs], X) :- I > 1, J is I - 1, le_feel_nth(J, Xs, X).

le_feel_today(date(Y, M, D)) :- get_time(T), stamp_date_time(T, date(Y, M, D, _, _, _, _, _, _), local).

the_date_written_as_is(T, D) :- le_feel_date(T, D).
the_date_written_as_is(date(Y, M, D), date(Y, M, D)).
the_day_of_the_month_of_is(date(_, _, D), D).
the_date_of_year_month_day_is(Y, M, D, date(Y, M, D)) :- integer(Y), integer(M), integer(D).
the_substring_of_from_position_with_length_is(T, S, L, P) :- le_feel_substring(T, S, L, P).
the_substring_of_from_position_is(T, S, P) :- le_feel_rest(T, S, P).
the_upper_case_of_is(T, U) :- le_feel_string(T, S), string_upper(S, U).
the_lower_case_of_is(T, U) :- le_feel_string(T, S), string_lower(S, U).
the_number_written_as_is(T, N) :- le_feel_number(T, N).
the_remainder_of_divided_by_is(A, B, R) :- le_feel_remainder(A, B, R).
the_count_of_the_list_is(L, N) :- is_list(L), length(L, N).
the_sum_of_the_list_is(L, S) :- is_list(L), le_feel_sum(L, S).
the_minimum_of_the_list_is(L, M) :- is_list(L), le_feel_min(L, M).
the_maximum_of_the_list_is(L, M) :- is_list(L), le_feel_max(L, M).
the_mean_of_the_list_is(L, M) :- is_list(L), L \== [], le_feel_sum(L, S), length(L, N), M0 is S / N, le_feel_whole(M0, M).
today_is(D) :- le_feel_today(D).
the_item_at_position_of_the_list_is(I, L, X) :- is_list(L), le_feel_item(I, L, X).
the_rounding_of_away_from_zero_to_decimals_is(X, D, V) :- le_feel_away(X, D, V).
the_rounding_of_toward_zero_to_decimals_is(X, D, V) :- le_feel_toward(X, D, V).
the_rounding_of_to_decimals_half_toward_zero_is(X, D, V) :- le_feel_half_down(X, D, V).
the_part_of_before_is(T, P, B) :- le_feel_before(T, P, B).
the_part_of_after_is(T, P, A) :- le_feel_after(T, P, A).
the_joining_of_the_list_with_is(L, D, S) :- is_list(L), le_feel_join(L, D, S).
the_product_of_the_list_is(L, P) :- is_list(L), L \== [], le_feel_product(L, P).
the_median_of_the_list_is(L, M) :- is_list(L), le_feel_median(L, M).
the_reverse_of_the_list_is(L, R) :- is_list(L), le_feel_reverse(L, R).
the_list_of_the_distinct_values_of_is(L, R) :- is_list(L), le_feel_distinct(L, [], R).
the_flattening_of_the_list_is(L, R) :- is_list(L), le_feel_flatten(L, R).
the_concatenation_of_the_lists_is(Ls, R) :- is_list(Ls), le_feel_concat(Ls, R).
the_sublist_of_from_position_is(L, S, R) :- is_list(L), le_feel_sublist(L, S, R).
the_sublist_of_from_position_with_length_is(L, S, N, R) :- is_list(L), le_feel_sublist(L, S, N, R).
the_list_without_the_item_at_position_is(L, P, R) :- is_list(L), le_feel_remove(L, P, R).
the_list_with_inserted_at_position_is(L, X, P, R) :- is_list(L), le_feel_insert(L, P, X, R).
the_list_of_the_positions_of_in_is(V, L, Ps) :- is_list(L), le_feel_positions(L, V, 1, Ps).
the_union_of_the_lists_is(Ls, U) :- is_list(Ls), le_feel_union(Ls, U).
the_conjunction_of_the_list_is(L, B) :- le_feel_all(L, B).
the_disjunction_of_the_list_is(L, B) :- le_feel_any(L, B).
is_odd(N) :- integer(N), N mod 2 =\= 0.
is_even(N) :- integer(N), N mod 2 =:= 0.
includes(L, X) :- is_list(L), memberchk(X, L).
every_item_of_is_true(L) :- is_list(L), le_feel_all(L).
some_item_of_is_true(L) :- is_list(L), le_feel_any(L).

/*  lib/rounding.pl — the arithmetic behind lib/rounding.le

    Need N8 of lpsPlus/docs/migration/roadmap.md (§7.5): rounding at a
    number of decimals, half up (half away from zero), half even (banker's
    rounding), down (towards minus infinity), up (towards plus infinity),
    and to the nearest multiple of a step (0.05, 10). Exact: the number is
    made a fraction first (rationalize/1 gives the shortest fraction that
    reads back as the float), so 2.675 is 107/40, not 2.67499999....

    The predicates at the end are the templates of rounding.le, under the
    names LE gives them (a template's words, its slots left out), with their
    arguments in the order of the slots: LE calls them directly.

    Loaded assert-only as a Prolog resource (docs/user/reference/language.md
    §14.1). No cuts in this file: LE's reasoner runs a resource's clauses
    itself, and a cut there does not prune.
*/

le_rounding_scaled(X, D, S) :- R is rationalize(X), S is R * 10^D.

le_rounding_result(I, D, V) :- D =< 0, V is I * 10^(-D).
le_rounding_result(I, D, V) :- D > 0, V is I / 10^D * 1.0.

%   half away from zero
le_rounding_half_up(X, D, V) :-
    le_rounding_scaled(X, D, S), S >= 0, I is floor(S + 1r2), le_rounding_result(I, D, V).
le_rounding_half_up(X, D, V) :-
    le_rounding_scaled(X, D, S), S < 0, I is -floor(-S + 1r2), le_rounding_result(I, D, V).

%   half to even
le_rounding_half_even(X, D, V) :-
    le_rounding_scaled(X, D, S), F is floor(S), Fr is S - F,
    le_rounding_even_pick(F, Fr, I), le_rounding_result(I, D, V).

le_rounding_even_pick(F, Fr, F) :- Fr < 1r2.
le_rounding_even_pick(F, Fr, I) :- Fr > 1r2, I is F + 1.
le_rounding_even_pick(F, Fr, F) :- Fr =:= 1r2, F mod 2 =:= 0.
le_rounding_even_pick(F, Fr, I) :- Fr =:= 1r2, F mod 2 =\= 0, I is F + 1.

le_rounding_down(X, D, V) :- le_rounding_scaled(X, D, S), I is floor(S), le_rounding_result(I, D, V).
le_rounding_up(X, D, V) :- le_rounding_scaled(X, D, S), I is ceiling(S), le_rounding_result(I, D, V).

le_rounding_nearest(X, Step, V) :-
    R is rationalize(X), St is rationalize(Step), Q is R / St,
    Q >= 0, I is floor(Q + 1r2), V0 is I * St, le_rounding_float(V0, V).
le_rounding_nearest(X, Step, V) :-
    R is rationalize(X), St is rationalize(Step), Q is R / St,
    Q < 0, I is -floor(-Q + 1r2), V0 is I * St, le_rounding_float(V0, V).

le_rounding_float(V0, V) :- integer(V0), V = V0.
le_rounding_float(V0, V) :- \+ integer(V0), V is float(V0).

the_rounding_of_to_decimals_half_up_is(X, D, V) :- le_rounding_half_up(X, D, V).
the_rounding_of_to_decimals_half_even_is(X, D, V) :- le_rounding_half_even(X, D, V).
the_rounding_of_down_to_decimals_is(X, D, V) :- le_rounding_down(X, D, V).
the_rounding_of_up_to_decimals_is(X, D, V) :- le_rounding_up(X, D, V).
the_rounding_of_to_the_nearest_is(X, S, V) :- le_rounding_nearest(X, S, V).

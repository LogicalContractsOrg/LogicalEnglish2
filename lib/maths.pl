/*  lib/maths.pl — the predicates behind lib/maths.le

    Loaded assert-only as a Prolog resource (docs/user/reference/language.md
    §14.1). No cuts in this file: LE's reasoner runs a resource's clauses
    itself.
*/

%   A whole power of a whole number stays whole (2 to the 10 is 1024);
%   anything else is a float.
the_power_of_to_is(X, N, R) :- integer(X), integer(N), N >= 0, R is X ^ N.
the_power_of_to_is(X, N, R) :- \+ ( integer(X), integer(N), N >= 0 ), R is float(X) ** float(N).

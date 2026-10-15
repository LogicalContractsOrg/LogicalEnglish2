/*  lib/lists.pl — the predicate behind lib/lists.le

    Loaded assert-only as a Prolog resource (docs/user/reference/language.md
    §14.1). No cuts in this file: LE's reasoner runs a resource's clauses
    itself.
*/

%   L is X followed by T: the list whose first item is X and whose other
%   items are T. Either way round: L from X and T, or X and T from L.
is_followed_by(L, X, T) :- L = [X|T].

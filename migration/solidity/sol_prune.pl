/** <module> Which of a path's conditions can happen at all

    E3.3 of the design notes ExtendingLanguagesCoverage.md §2.1.5, and
    the part of it that decides whether the result is readable.

    `sol_front.pl` executes a Solidity function symbolically and keeps one
    path per sequence of branches. Making every checked `+ - *` a branch — it
    overflows, or it does not — doubles the paths, and most of the new ones
    cannot happen: a function that has already refused the call when
    `fromBalance < value` cannot then underflow at `fromBalance - value`.
    Emitting a constraint for each of those would turn a readable twin into a
    list of impossibilities, which is §2.1.2's whole objection to "emit them
    all".

    So this: the path's conditions are modelled as linear inequalities over
    the rationals (`library(clpq)`) and a path whose conditions cannot all
    hold is dropped. Anything too rich to model — a call, a hash, a
    disjunction, a product of two unknowns — is left out, or stands as an
    unknown of its own, which can only make the answer *satisfiable*. That is
    the safe direction: this decides what to **drop**, so it must never say
    "cannot happen" about something that can.

    **Rationals, not integers, and not finite domains.** The relaxation is
    the reason this is instant: over the rationals a contradiction falls out
    of posting the constraints, with no search. It is also the reason it is
    safe — a rational solution may have no integer one, so "satisfiable" here
    means "not shown impossible", which is exactly the reading a rule that
    only drops things needs. Finite-domain reasoning is the wrong tool at
    this width: `clpfd` needs to label to see that `x < y` and `x >= y`
    disagree, and over `0 .. 2^256 - 1` that never returns.

    The arithmetic is the EVM's: every value is a word, `0 .. 2^256 - 1`, and
    those two bounds are posted for each unknown — they are what makes an
    overflow test decidable at all. A twin over `int` would need the signed
    range, and there is none in the corpus.
*/

:- module(sol_prune, [
    conds_satisfiable/1,     % +[cond(Value, Kind)] or +[Value]
    value_satisfiable/2      % +Value, +Conds
  ]).

:- use_module(library(clpq)).
:- use_module(library(lists)).
:- use_module(library(assoc)).

word_max(M) :- M is 2^256 - 1.

%!  conds_satisfiable(+Conds) is semidet.
%
%   True when the conditions could all hold at once, as far as integer
%   reasoning can tell. `cond(V, _)` wrappers are accepted so that a path's
%   own condition list can be passed straight in.
conds_satisfiable(Conds) :-
    catch(\+ \+ post_all(Conds), _, true).

%!  value_satisfiable(+Value, +Conds) is semidet.
%
%   The same question for one more condition added to a path: *can this
%   overflow, given everything the path already decided?*
value_satisfiable(V, Conds) :-
    conds_satisfiable([V|Conds]).

post_all(Conds) :-
    empty_assoc(M0),
    foldl(post_cond, Conds, M0, _).

post_cond(cond(V, _), M0, M) :- !, post_value(V, M0, M).
post_cond(V, M0, M) :- post_value(V, M0, M).

%   A condition this cannot model constrains nothing: `true` here means "not
%   known to be impossible", and leaving a condition out only widens that.
post_value(V, M0, M) :-
    (   constraint(V, C, M0, M1)
    ->  M = M1, {C}
    ;   M = M0
    ).

		 /*******************************
		 *        THE TRANSLATION       *
		 *******************************/

constraint(not(V), C, M0, M) :- !,
    (   negatable(V, NV)
    ->  constraint(NV, C, M0, M)
    ;   fail
    ).
constraint(and(A, B), (CA, CB), M0, M) :- !,
    constraint(A, CA, M0, M1), constraint(B, CB, M1, M).
constraint(cmp(Op, A, B), C, M0, M) :-
    clp_op(Op, F), !,
    expr(A, EA, M0, M1), expr(B, EB, M1, M),
    C =.. [F, EA, EB].
%   A disjunction, a call, a hash: not modelled, and deliberately — see the
%   module comment. `or` could be reified, but a branch of it that this cannot
%   model would then have to be read as *false* rather than as *unknown*,
%   which is the unsafe direction.

negatable(cmp(Op, A, B), cmp(NOp, A, B)) :- neg_op(Op, NOp).
negatable(not(V), V).

neg_op('<', '>=').  neg_op('>=', '<').
neg_op('>', '<=').  neg_op('<=', '>').
neg_op('==', '!='). neg_op('!=', '==').

%   `!=` is left out on purpose: over the rationals it removes a single
%   point and never shows a path impossible, and clpq would carry it as a
%   disequation for no gain.
clp_op('<', <).    clp_op('<=', =<).
clp_op('>', >).    clp_op('>=', >=).
clp_op('==', =:=).

%!  expr(+Value, -ClpExpr, +Map0, -Map) is semidet.
expr(c(N), N, M, M) :- integer(N), !.
expr(c(const(_, V)), V, M, M) :- integer(V), !.
expr(N, N, M, M) :- integer(N), !.
expr(max(Bits), Max, M, M) :- integer(Bits), !, Max is 2^Bits - 1.
expr(bin(Op, A, B), E, M0, M) :-
    clp_arith(Op, F),
    expr(A, EA, M0, M1), expr(B, EB, M1, M2),
    linear(F, EA, EB), !,
    M = M2, E =.. [F, EA, EB].
expr(V, X, M0, M) :-
    %  anything else — a storage read, a parameter, the caller, a product of
    %  two unknowns, a division — is an unknown word. The same term is the
    %  same unknown, which is what lets a guard about it contradict a later
    %  overflow test on it.
    key(V, K),
    (   get_assoc(K, M0, X)
    ->  M = M0
    ;   word_max(Max), {X >= 0, X =< Max},
        put_assoc(K, M0, X, M)
    ).

clp_arith('+', +). clp_arith('-', -). clp_arith('*', *).

%   clpq is linear: a product is modelled only when one side is a number.
%   `/` and `%` are not modelled at all — each is an unknown of its own,
%   which is what the fall-through clause above makes it.
linear(*, A, B) :- !, ( number(A) ; number(B) ).
linear(_, _, _).

%   Two occurrences of the same read are the same unknown; variables inside
%   (there should be none) would make that wrong, so a term with any is given
%   a key of its own.
key(V, K) :- copy_term(V, K0), numbervars(K0, 0, _), term_to_atom(K0, K).

/** <module> Cases generated from a Blawx encoding, for Blawx itself to answer

    Most of the example projects' tests state no facts (they are the
    scenario editor's starting points), so the tests alone say little about
    whether the twin decides as Blawx does. This module writes cases the
    way the Miniscript translator writes a policy's satisfaction analysis:
    for each rule of the encoding, a case that meets its conditions (every
    positive condition a fact, each variable an individual named after its
    type — `person_a` — or a number at the boundary of its comparisons),
    each *near miss* (one fact left out, one comparison missed by one), and,
    for a defeasible rule, the case together with each defeater's own case.
    The expected answers are not computed here: Blawx's reasoner computes
    them (oracle.py, --batch), and the twin must agree.

        rule_cases(+Clauses, +Decls, -Cases)

    Cases = [case(Id, Section, Facts, Query)]: Facts ground Blawx terms,
    Query a Blawx goal (the rule's conclusion with its places as variables).
    A rule whose conditions the generator cannot meet (dates, lists,
    arithmetic other than a comparison with a number) gets no case.
*/

:- module(blawx_cases, [rule_cases/4, case_text/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).

max_depth(3).
max_cases_per_rule(10).
max_cases(90).

%!  rule_cases(+Clauses, +Decls, +TypesOf, -Cases) is det.
%
%   TypesOf is a closure call(TypesOf, F/N, Types): the place types of a
%   predicate, in Blawx's argument order.
rule_cases(Clauses, Decls, TypesOf, Cases) :-
    findall(R, source_rule(Clauses, R), Rules0),
    length(Rules0, NR), numlist1(NR, Is),
    pairs_keys_values(Rules, Is, Rules0),
    findall(Cs, ( member(I-R, Rules), rule_case_set(Clauses, Decls, TypesOf, I, R, Cs) ), Css),
    append(Css, Cases0),
    dedupe_cases(Cases0, Cases1),
    cap(Cases1, Cases).

numlist1(0, []) :- !.
numlist1(N, L) :- numlist(1, N, L).

source_rule(Clauses, r(S, C, Args, Body)) :-
    member(cl(_, (H :- Body), _), Clauses), nonvar(H),
    H =.. [according_to, S, P0|Args], atom(S), \+ P0 == blawx_becomes,
    ( P0 = -(P) -> C = neg(P) ; P = P0, atom(P), C = P ),
    \+ ( conj(Body, Gs), member(G, Gs), G0 =.. [P|Args], G == G0 ).   % not the circular kind

rule_case_set(Clauses, Decls, TypesOf, I, r(S, C, Args, Body), Cases) :-
    copy_term(Args-Body, A1-B1),
    (   catch(meet(Clauses, TypesOf, B1, 0, Facts0, Cons), _, fail)
    ->  value_vars(Decls, TypesOf, Facts0, Cons, A1, Vals),
        ground_facts(Facts0, Cons, Vals, Facts),
        query_goal(C, Args, Q),
        format(atom(Id0), 'case_~w', [I]),
        W = case(Id0, S, Facts, Q),
        findall(case(Id, S, Fs, Q),
                ( nth1(K, Facts, _), nth1(K, Facts, _, Fs), Fs \== [],
                  format(atom(Id), 'case_~w_without_fact_~w', [I, K]) ),
                Misses),
        findall(case(Id, S, Fs, Q),
                ( nth1(K, Cons, c(V, Op, N)), miss_value(Op, N, M),
                  ground_facts(Facts0, Cons, [V-M|Vals], Fs), Fs \== Facts,
                  format(atom(Id), 'case_~w_missing_comparison_~w', [I, K]) ),
                NumMisses),
        findall(case(Id, S, Fs, Q),
                ( defeater_case(Clauses, Decls, TypesOf, S-C, A1, Vals, Facts, S2, Fs),
                  format(atom(Id), 'case_~w_with_~w', [I, S2]) ),
                Defeated),
        append([[W], Misses, NumMisses, Defeated], All),
        max_cases_per_rule(Max), take(Max, All, Cases)
    ;   Cases = []
    ).

take(N, L, T) :- length(L, Len), ( Len =< N -> T = L ; length(T, N), append(T, _, L) ).

%   The query of a case: the conclusion, its places open.
query_goal(C, Args, Q) :-
    length(Args, N), length(Vs, N),
    ( C = neg(P) -> G =.. [P|Vs], Q = -(G) ; Q =.. [C|Vs] ).

%!  meet(+Clauses, +TypesOf, +Body, +Depth, -Facts, -Constraints)
%
%   The facts that meet the body's positive conditions (a condition read
%   from another section's conclusion is met through that section's rule),
%   and its comparisons with numbers: c(Var, Op, Number).
meet(Clauses, TypesOf, Body, D, Facts, Cons) :-
    conj(Body, Gs),
    foldl(meet_goal(Clauses, TypesOf, D), Gs, []-[], FR-CR),
    reverse(FR, Facts), reverse(CR, Cons).

conj(V, [V]) :- var(V), !.
conj((A, B), L) :- !, conj(A, LA), conj(B, LB), append(LA, LB, L).
conj(G, [G]).

meet_goal(_, _, _, G, _, _) :- var(G), !, fail.
meet_goal(_, _, _, not(_), Acc, Acc) :- !.
meet_goal(_, _, _, \+(_), Acc, Acc) :- !.
meet_goal(_, _, _, (_ ; _), _, _) :- !, fail.
meet_goal(_, _, _, X \= Y, Acc, Acc) :- !, ( var(X) ; var(Y) ; X \== Y ), !.
meet_goal(_, _, _, blawx_diseq(_, _), Acc, Acc) :- !.
meet_goal(_, _, _, G, F-C, F-[c(V, Op, N)|C]) :-
    compound(G), G =.. [Op0, A, B], comparison(Op0, Op1),
    (   var(A), number(B) -> V = A, N = B, Op = Op1
    ;   var(B), number(A) -> V = B, N = A, flip(Op1, Op)
    ), !.
meet_goal(_, _, _, G, F-C, F-[c(V, Op, N)|C]) :-
    compound(G), G =.. [K, A, Op0, B], memberchk(K, [blawx_comparison, date_compare, duration_compare]),
    word_op(Op0, Op1), unwrap_num(A, A1), unwrap_num(B, B1),
    (   var(A1), number(B1) -> V = A1, N = B1, Op = Op1
    ;   var(B1), number(A1) -> V = B1, N = A1, flip(Op1, Op)
    ), !.
meet_goal(Clauses, TypesOf, D, G, F0-C0, F-C) :-
    compound(G), G =.. [K, S, P0|Args], memberchk(K, [holds, according_to]), atom(S), S \== user, !,
    max_depth(Max), D < Max, D1 is D + 1,
    ( P0 = -(P) -> C1 = neg(P) ; P = P0, C1 = P ),
    source_rule(Clauses, r(S, C1, HArgs, Body)),
    copy_term(HArgs-Body, Args-B1),
    meet(Clauses, TypesOf, B1, D1, Fs, Cs),
    append(Fs, F0, F), append(Cs, C0, C).
meet_goal(_, _, _, G, F-C, [F1|F]-C) :-
    compound(G), G =.. [holds, user, P0|Args], !,
    ( P0 = -(P) -> G1 =.. [P|Args], F1 = -(G1) ; F1 =.. [P0|Args] ).
meet_goal(_, TypesOf, _, -(G), F-C, [-(G)|F]-C) :- !, callable(G), functor(G, Fn, N), call(TypesOf, Fn/N, _).
meet_goal(_, TypesOf, _, G, F-C, [G|F]-C) :-
    callable(G), functor(G, Fn, N), \+ generated_predicate(Fn), call(TypesOf, Fn/N, _).

%   What Blawx's preamble defines: a case cannot meet it by a fact.
generated_predicate(F) :- memberchk(F, [holds, according_to, blawx_defeated, date_add, date_compare,
                                        duration_compare, findall, datetime_add, not_after, blawx_today,
                                        blawx_now, is, count_blawx_list, sum_blawx_list, average_blawx_list,
                                        max_blawx_list, min_blawx_list, blawx_becomes, blawx_during,
                                        blawx_as_of, blawx_initially, blawx_ultimately]).

comparison(#>=, >=). comparison(#>, >). comparison(#<, <). comparison(#=<, =<). comparison(#=, =).
comparison(>=, >=). comparison(>, >). comparison(<, <). comparison(=<, =<).
word_op(gte, >=). word_op(gt, >). word_op(lt, <). word_op(lte, =<). word_op(eq, =).
flip(>=, =<). flip(=<, >=). flip(>, <). flip(<, >). flip(=, =).

unwrap_num(T, V) :- compound(T), T =.. [W, V0], memberchk(W, [date, datetime, duration, time]), !, V = V0.
unwrap_num(T, T).

%   The value meeting a comparison exactly at its boundary, and the one
%   missing it by one.
meet_value(>=, N, N). meet_value(=<, N, N). meet_value(>, N, M) :- M is N + 1.
meet_value(<, N, M) :- M is N - 1. meet_value(=, N, N).
miss_value(>=, N, M) :- M is N - 1. miss_value(=<, N, M) :- M is N + 1.
miss_value(>, N, N). miss_value(<, N, N). miss_value(=, N, M) :- M is N + 1.

%   Values: each constrained variable at its boundary, every other one an
%   individual named after its type (person_a, person_b, ...).
value_vars(_Decls, TypesOf, Facts, Cons, Args, Vals) :-
    cons_values(Cons, NVals0),              % not findall: it would copy the variables
    first_per_var(NVals0, NVals),
    term_variables(Facts-Args, Vs),
    foldl(name_var(TypesOf, Facts, NVals), Vs, []-[], _-Named),
    append(NVals, Named, Vals).

cons_values([], []).
cons_values([c(V, Op, N)|Cs], Out) :-
    ( meet_value(Op, N, M) -> Out = [V-M|Out1] ; Out = Out1 ),
    cons_values(Cs, Out1).

first_per_var([], []).
first_per_var([V-M|Rest], [V-M|Out]) :- drop_var(Rest, V, Rest1), first_per_var(Rest1, Out).

drop_var([], _, []).
drop_var([W-X|Ps], V, Out) :- ( W == V -> Out = Out1 ; Out = [W-X|Out1] ), drop_var(Ps, V, Out1).

name_var(_, _, NVals, V, Counts-Acc, Counts-Acc) :- member(W-_, NVals), W == V, !.
name_var(TypesOf, Facts, _, V, Counts0-Acc, Counts-[V-C|Acc]) :-
    (   var_type(TypesOf, Facts, V, T) -> true ; T = thing ),
    (   memberchk(T, [number, time, duration])
    ->  ( select(T-K0, Counts0, Counts1) -> K is K0 + 1 ; K = 1, Counts1 = Counts0 ),
        C is 1000 * K, Counts = [T-K|Counts1]
    ;   atomic_list_concat(Ws, ' ', T), atomic_list_concat(Ws, '_', TU),
        ( select(T-K0, Counts0, Counts1) -> K is K0 + 1 ; K = 1, Counts1 = Counts0 ),
        %  a letter, not a number: s(CASP) reads an atom ending in _<digits>
        %  as its stem (x_1 and x_2 are both x), which would merge individuals
        nth1(K, [a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z], Letter),
        format(atom(C), '~w_~w', [TU, Letter]), Counts = [T-K|Counts1]
    ).

var_type(TypesOf, Facts, V, T) :-
    member(F0, Facts), ( F0 = -(F) -> true ; F = F0 ),
    F =.. [Fn|As], nth1(I, As, A), A == V,
    length(As, N), call(TypesOf, Fn/N, Ts), nth1(I, Ts, T), !.

ground_facts(Facts0, _Cons, Vals, Facts) :-
    copy_term(Facts0-Vals, Facts1-Vals1),
    maplist([V-X]>>( var(V) -> V = X ; true ), Vals1),
    term_variables(Facts1, Rest), maplist(=(anything), Rest),
    list_to_set(Facts1, Facts).

%   A defeasible rule's case together with the case of each rule that
%   defeats it (the defeater's places given by the defeat, the rest its own).
defeater_case(Clauses, Decls, TypesOf, S-C, Args, Vals, Facts, S2, All) :-
    blawx_defeated_clause(Clauses, S-C, HArgs, S2-C2, BArgs),
    copy_term(HArgs-BArgs, HA-BA), HA = Args,
    source_rule(Clauses, r(S2, C2, DArgs, DBody)),
    copy_term(DArgs-DBody, BA-DB),
    catch(meet(Clauses, TypesOf, DB, 1, DFacts0, DCons), _, fail),
    value_vars(Decls, TypesOf, DFacts0, DCons, BA, DVals),
    append(Vals, DVals, AllVals),
    ground_facts(DFacts0, DCons, AllVals, DFacts),
    append(Facts, DFacts, All0), list_to_set(All0, All).

blawx_defeated_clause(Clauses, S-C, HArgs, S2-C2, BArgs) :-
    member(cl(_, (H :- B), _), Clauses), nonvar(H),
    H =.. [blawx_defeated, S, P1|HArgs], conc(P1, C),
    B =.. [holds, S2, P2|BArgs], conc(P2, C2).

conc(-(P), neg(P)) :- atom(P), !.
conc(P, P) :- atom(P).

dedupe_cases([], []).
dedupe_cases([case(Id, S, Fs, Q)|Cs], [case(Id, S, Fs, Q)|Out]) :-
    msort(Fs, SF),
    drop_same(Cs, SF, Q, Cs1),
    dedupe_cases(Cs1, Out).

drop_same([], _, _, []).
drop_same([C|Cs], SF, Q, Out) :-
    C = case(_, _, Fs2, Q2), msort(Fs2, SF2),
    ( SF2 == SF, Q2 =@= Q -> Out = Out1 ; Out = [C|Out1] ),
    drop_same(Cs, SF, Q, Out1).

cap(Cases, Capped) :-
    max_cases(Max), length(Cases, N),
    (   N =< Max -> Capped = Cases
    ;   Step is N / Max,
        findall(C, ( between(0, Max, J), J < Max, I is floor(J * Step) + 1, nth1(I, Cases, C) ), Capped)
    ).

%!  case_text(+Case, -FactsText, -QueryText) is det.
%
%   The case in Blawx's s(CASP): one fact per line, and the query.
case_text(case(_, _, Facts, Q), FT, QT) :-
    with_output_to(string(FT), forall(member(F, Facts), ( writeq(F), write('.'), nl ))),
    copy_term(Q, Q1), numbervars(Q1, 0, _),
    with_output_to(string(QT), print(Q1)).

/** <module> The rules' own analysis: generated test cases for an OIA project

    A project with no test files still carries the material for its tests:
    its rules. This module derives them, the way the Miniscript translator
    derives a policy's tests from its satisfaction analysis:

      - for each GOAL (a conclusion no boolean rule reads — the decisions
        the project exists for), the ways its rules can reach it: one
        PATH per way, a set of input values that makes the goal hold (the
        first-matching row of a rule table, one alternative of an `or`,
        every condition of an `and`, the opposite of a negated condition);
      - for each path, its NEAR MISSES: one of those inputs changed to the
        value that fails its condition (a boolean flipped, a date one day
        on the wrong side of its limit, another listed value);
      - every expected outcome computed by an EVALUATOR of the OIA model
        (OIA's semantics: three-valued, first match in rule tables, an
        entity instance per matching row of a relationship table) — never
        by the LE program the cases are then run against.

    Inputs a case leaves unstated are unknown to the evaluator; a case is
    completed (unstated inputs the outcome needs get a default value) until
    every goal is known, so the closed-world twin and OIA's three-valued
    reading give the same answer — the cases test the rules, not the
    documented approximation.

    Output: case(Id, Locator, Inputs, Outcomes), Inputs a list Key-Value,
    Outcomes a list Key-Value (global goals) and inst(Entity)-Instances /
    ek(Entity, Key)-[Id-Value] (entity goals). Values: true, false,
    unknown, str(S), num(N), date(Y, M, D). oia_ir.pl turns them into
    scenarios.
*/

:- module(oia_analysis, [
    analysis_cases/4,          % +Model, +Types, +Options, -Cases
    oia_eval_goal/4            % +Model, +Inputs, +Goal, -Value
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).

:- dynamic model_rules/1, model_types/1, model_ents/1.

		 /*******************************
		 *            DRIVER            *
		 *******************************/

%!  analysis_cases(+Model, +Types, +Options, -Cases) is det.
%
%   Options: max_paths(N) per goal (default 8; larger sets are sampled
%   evenly), goals(Goals) (default: the model's own).
analysis_cases(Model, Types, Opts, Cases) :-
    setup(Model, Types),
    option(max_paths(Max), Opts, 8),
    ( option(goals(Goals), Opts) -> true ; model_goals(Goals) ),
    findall(G-Paths, ( member(G, Goals), goal_paths(G, Paths0), sample(Paths0, Max, Paths) ), GPs),
    findall(c(Why, A), ( member(G-Paths, GPs), nth1(I, Paths, P),
                         path_cases(G, I, P, Why, A) ), Cs00),
    once_per_input(Cs00, Cs0),
    dedupe(Cs0, Cs1),
    findall(case(Id, Loc, In, Out),
            ( nth1(N, Cs1, c(Why, A)),
              complete(Goals, A, In),
              outcomes(Goals, In, Out),
              case_id(Why, N, Id, Loc) ),
            Cases).

setup(oia(_, Attrs, Rules, Docs), Types) :-
    retractall(model_rules(_)), retractall(model_types(_)), retractall(model_ents(_)),
    assertz(model_rules(Rules)),
    findall(K-T, ( member(attr(K, _, T0, _, _), Attrs), ( memberchk(K-T, Types) -> true ; T = T0 ) ), KTs),
    assertz(model_types(KTs)),
    findall(ent(E, IdK, Ks), ( member(entity(E, _, IdK), Docs),
                               findall(K, member(attr(K, _, _, E, _), Attrs), Ks) ), Es),
    findall(rel(R, Tgt), member(relationship(R, _, Tgt, _), Docs), Rs),
    findall(etext(E, T), member(entity(E, T, _), Docs), ETs),
    append([Es, Rs, ETs], ER),
    assertz(model_ents(ER)).

%   The goals: every conclusion no boolean rule reads (read by a value rule
%   or a table only, or by nothing), and, for a project with entities, the
%   instances its relationship tables infer and their concluded attributes.
model_goals(Goals) :-
    model_rules(Rules),
    findall(K, ( member(rule(_, _, _, _, T), Rules), concludes(T, K), atom(K), global_key(K) ), Ks0),
    list_to_set(Ks0, Ks),
    include(goal_key(Rules), Ks, G1),
    findall(inst(E), ( member(rule(_, _, _, _, table(_, _, Cs)), Rules), member(concl(rel(R), _), Cs),
                       model_ents(ER), memberchk(rel(R, E), ER) ), G2a),
    list_to_set(G2a, G2),
    findall(ek(E, K), ( member(inst(E), G2), member(rule(_, _, _, _, table(E, _, Cs)), Rules),
                        member(concl(K, _), Cs), atom(K) ), G3a),
    list_to_set(G3a, G3),
    append([G1, G2, G3], Goals).

global_key(K) :- \+ ( model_ents(ER), member(ent(_, _, Ks), ER), memberchk(K, Ks) ).

concludes(conclude(K, _, _, _, _), K).
concludes(table(_, _, Cs), K) :- member(concl(K, _), Cs).

%   A goal: a conclusion nothing reads, or a boolean one only value rules
%   and tables read whose own condition combines several attributes (the
%   eligibility a benefit's amount depends on, not a date test on the way).
goal_key(Rules, K) :-
    \+ ( member(rule(_, _, _, _, T), Rules), \+ concludes(T, K), sub_term(att(K), T) ),
    \+ ( member(rule(_, _, _, _, conclude(_, _, _, C, _)), Rules),
         sub_term(inline(conclude(K, _, _, _, _)), C) ), !.
goal_key(Rules, K) :-
    bool_key(K),
    not_read_by_boolean(Rules, K),
    member(rule(_, _, _, _, T), Rules), concludes(T, K),
    findall(A, sub_term(att(A), T), As0), list_to_set(As0, As), length(As, N), N >= 2, !.

not_read_by_boolean(Rules, K) :-
    \+ ( member(rule(_, _, _, _, conclude(_, _, V, C, _)), Rules),
         ( V == true ; V == false ), sub_term(att(K), C) ),
    \+ ( member(rule(_, _, _, _, conclude(_, _, _, C, _)), Rules),
         sub_term(inline(conclude(_, _, _, C2, _)), C), sub_term(att(K), C2) ).

sample(Ps, Max, Ps) :- length(Ps, N), N =< Max, !.
sample(Ps, Max, S) :-
    length(Ps, N),
    findall(P, ( between(0, Max, I0), I0 < Max, I is (I0 * N) // Max + 1, nth1(I, Ps, P) ), S0),
    list_to_set(S0, S).

%   The ways to reach a goal, as assignments (distinct, in order found).
goal_paths(G, Paths) :-
    findall(A, ( goal_sat(G, A0), sort(A0, A) ), As0),
    list_to_set(As0, Paths).

goal_sat(G, A) :-
    atom(G), !,
    (   bool_key(G) -> sat(att(G), top, [], A)
    ;   valsat(G, top, [], A, _)
    ).
goal_sat(inst(E), A) :-
    model_rules(Rules), model_ents(ER),
    member(rule(_, _, _, _, table(_, CCols, Cs)), Rules), member(concl(rel(R), Vals), Cs),
    memberchk(rel(R, E), ER),
    nth1(I, Vals, V), V \== uncertain_value,
    row_expr(CCols, I, RE),
    sat(RE, top, [], A).
goal_sat(ek(_, _), _) :- fail.        % reached through its instances

%   A path and its near misses: c(Why, Assignment).
path_cases(G, I, A, path(G, I, A), Clean) :- clean(A, Clean).
path_cases(G, I, A, near(G, I, K, A), A2) :-
    member(K-b(_, Opp), A), Opp \== none,
    select(K-_, A, Rest), clean(Rest, R1),
    ( Opp == known -> default_value(K, V2) ; Opp == unknown -> V2 = unknown ; V2 = Opp ),
    A2 = [K-V2|R1].

%   A near miss per goal and changed input: the first path that has the
%   input gives it (every requirement is missed once, not once per path).
once_per_input(Cs0, Cs) :-
    foldl(once1, Cs0, []-[], _-Rev), reverse(Rev, Cs).
once1(c(near(G, I, K, P), A), Seen-Acc, Seen1-Acc1) :- !,
    (   memberchk(G-K, Seen) -> Seen1 = Seen, Acc1 = Acc
    ;   Seen1 = [G-K|Seen], Acc1 = [c(near(G, I, K, P), A)|Acc]
    ).
once1(C, Seen-Acc, Seen-[C|Acc]).

clean(A, C) :- maplist(clean1, A, C).
clean1(K-b(V, _), K-V) :- !.
clean1(KV, KV).

dedupe(Cs0, Cs) :-
    foldl(dedupe1, Cs0, []-[], _-Rev), reverse(Rev, Cs).
dedupe1(c(W, A0), Seen-Acc, Seen1-Acc1) :-
    msort(A0, A),
    (   memberchk(A, Seen) -> Seen1 = Seen, Acc1 = Acc
    ;   Seen1 = [A|Seen], Acc1 = [c(W, A)|Acc]
    ).

case_id(path(G, I, _), _, Id, Loc) :-
    goal_slug(G, S), format(atom(Id), '~w_path_~w', [S, I]),
    goal_words(G, GW), format(atom(Loc), 'path ~w to ~w', [I, GW]).
case_id(near(G, I, K, _), N, Id, Loc) :-
    goal_slug(G, S), format(atom(Id), '~w_path_~w_miss_~w', [S, I, N]),
    goal_words(G, GW), format(atom(Loc), 'path ~w to ~w, with ~w changed', [I, GW, K]).

goal_words(inst(E), W) :- !, entity_text(E, T), format(atom(W), 'an instance of ~w', [T]).
goal_words(G, G).

entity_text(E, T) :- ( model_ents(ER), memberchk(etext(E, T), ER) -> true ; T = E ).

goal_slug(inst(E), S) :- !, entity_text(E, T), goal_slug(T, S).
goal_slug(G, S) :-
    atomic_list_concat(Ws0, ' ', G),
    exclude(slug_stop, Ws0, Ws1),
    ( length(Ws1, L), L > 4 -> length(Ws2, 4), append(Ws2, _, Ws1) ; Ws2 = Ws1 ),
    atomic_list_concat(Ws2, '_', S0),
    atom_codes(S0, Cs0), include(slug_code, Cs0, Cs),
    atom_codes(S, Cs).

slug_stop(W) :- memberchk(W, [the, a, an, is, of, to, for, all]).
slug_code(C) :- ( code_type(C, alnum) ; C == 0'_ ).

%   (No yall lambdas over outer variables in this module: loaded after
%   le_kbs, they were copied with those variables fresh — named helpers.)

		 /*******************************
		 *   COMPLETION AND OUTCOMES    *
		 *******************************/

%   Unstated inputs the evaluator reads while a goal is still unknown get a
%   default value, until every goal is known (a few rounds at most).
complete(Goals, A, In) :- complete(Goals, A, 0, In).
complete(Goals, A, N, In) :-
    nb_setval(oia_touched, []),
    outcomes(Goals, A, Out),
    tget(Ks0),
    (   N < 6, member(_-unknown, Out), list_to_set(Ks0, Ks), Ks \== []
    ->  foldl(default_bind, Ks, A, A1), N1 is N + 1,
        complete(Goals, A1, N1, In)
    ;   In = A
    ).

default_bind(K, A0, A) :-
    (   memberchk(K-_, A0) -> A = A0
    ;   default_value(K, V), A = [K-V|A0]
    ).

outcomes(Goals, A, Out) :-
    findall(O, ( member(G, Goals), catch(outcome(G, A, O), oia_analysis_unsupported(_), fail) ), Out0),
    append(Out0, Out).

outcome(G, A, [G-V]) :- atom(G), !, oia_eval_goal(_, A, G, V).
outcome(inst(E), A, [inst(E)-Ids]) :- !, instances(E, A, Ids).
outcome(ek(E, K), A, [ek(E, K)-Vs]) :-
    instances(E, A, Ids),
    findall(Id-V, ( member(Id, Ids), eval(att(K), ctx(A, inst(E, Id)), V) ), Vs).

%!  oia_eval_goal(+Model, +Inputs, +Goal, -Value) is det.
%
%   A global attribute's value under OIA's semantics: true, false, unknown
%   or a value. Model may be unbound once analysis_cases/4 set it up.
oia_eval_goal(Model, A, G, V) :-
    ( nonvar(Model) -> setup(Model, []) ; true ),
    eval(att(G), ctx(A, top), V).

		 /*******************************
		 *          EVALUATOR           *
		 *******************************/

%   eval(+Expr, +Ctx, -V): V is true, false, unknown or a value (str/num/
%   date). Ctx = ctx(Assignment, top | inst(Entity, Id)).
eval(cite(_, E), C, V) :- !, eval(E, C, V).
eval(true, _, true) :- !.
eval(false, _, false) :- !.
eval(str(S), _, str(S)) :- !.
eval(num(N), _, num(N)) :- !.
eval(date(Y, M, D), _, date(Y, M, D)) :- !.
eval(and(L), C, V) :- !, eval_decided(L, C, false, V0), ( V0 == none -> V = true ; V = V0 ).
eval(or(L), C, V) :- !, eval_decided(L, C, true, V0), ( V0 == none -> V = false ; V = V0 ).
eval(not(E), C, V) :- !, eval(E, C, V0),
    ( V0 == true -> V = false ; V0 == false -> V = true ; V = unknown ).
eval(inline(T), C, V) :- !, T = conclude(K, _, _, _, _), eval(att(K), C, V).
eval(known(E), C, V) :- !, eval(E, C, V0), ( V0 == unknown -> V = false ; V = true ).
eval(unknown(E), C, V) :- !, eval(E, C, V0), ( V0 == unknown -> V = true ; V = false ).
eval(E, C, V) :- E =.. [Op, L, R], memberchk(Op, [eq, ne, gt, ge, lt, le]), !,
    eval(L, C, VL), eval(R, C, VR),
    (   ( VL == unknown ; VR == unknown ) -> V = unknown
    ;   compare_values(Op, VL, VR) -> V = true
    ;   V = false
    ).
eval(E, C, V) :- E =.. [Op, L, R], memberchk(Op, [mul, div, add, sub]), !,
    eval(L, C, VL), eval(R, C, VR),
    (   VL = num(X), VR = num(Y)
    ->  arith(Op, X, Y, Z), V = num(Z)
    ;   V = unknown
    ).
eval(neg(E), C, V) :- !, eval(E, C, V0), ( V0 = num(X) -> Y0 is -X, le_number(Y0, Y), V = num(Y) ; V = unknown ).
eval(round(E), C, V) :- !, eval(E, C, V0), ( V0 = num(X) -> Y is round(X), V = num(Y) ; V = unknown ).
eval(add_months(D, N), C, V) :- !, eval(D, C, VD), eval(N, C, VN),
    ( VD = date(Y, M, Dd), VN = num(K) -> add_months(date(Y, M, Dd), K, V) ; V = unknown ).
eval(add_years(D, N), C, V) :- !, eval(D, C, VD), eval(N, C, VN),
    ( VD = date(Y, M, Dd), VN = num(K) -> K12 is 12 * K, add_months(date(Y, M, Dd), K12, V) ; V = unknown ).
eval(add_days(D, N), C, V) :- !, eval(D, C, VD), eval(N, C, VN),
    ( VD = date(_, _, _), VN = num(K) -> add_days(VD, K, V) ; V = unknown ).
eval(att(K), C, V) :- !, att_value(K, C, V).
%   Texts: OIA's `+` of texts, Text(), and the tests on texts.
eval(concat(A, B), C, V) :- !, eval(A, C, VA), eval(B, C, VB),
    (   text_of(VA, TA), text_of(VB, TB) -> string_concat(TA, TB, T), V = str(T) ; V = unknown ).
eval(text(A), C, V) :- !, eval(A, C, VA), ( text_of(VA, T) -> V = str(T) ; V = unknown ).
eval(E, C, V) :- E =.. [Op, A, B], memberchk(Op, [contains, starts_with, ends_with]), !,
    eval(A, C, VA), eval(B, C, VB),
    (   text_of(VA, TA), text_of(VB, TB)
    ->  (   Op == contains, sub_string(TA, _, _, _, TB) -> V = true
        ;   Op == starts_with, string_concat(TB, _, TA) -> V = true
        ;   Op == ends_with, string_concat(_, TB, TA) -> V = true
        ;   V = false
        )
    ;   V = unknown
    ).
eval(E, C, V) :- E =.. [Op, A, num(D)], memberchk(Op, [round, trunc]), integer(D), !,
    eval(A, C, VA),
    (   VA = num(X)
    ->  F is 10^D, ( Op == round -> Y0 is round(X * F) / F ; Y0 is truncate(X * F) / F ),
        le_number(Y0, Y), V = num(Y)
    ;   V = unknown
    ).
eval(E, C, V) :- E =.. [Op, A, B], memberchk(Op, [min, max, mod]), !,
    eval(A, C, VA), eval(B, C, VB),
    (   VA = num(X), VB = num(Y)
    ->  ( Op == min -> Z0 is min(X, Y) ; Op == max -> Z0 is max(X, Y) ; Z0 is X mod Y ), le_number(Z0, Z), V = num(Z)
    ;   V = unknown
    ).
%   Anything else (entity functions, current dates, ...) the evaluator does
%   not compute: the outcome that rests on it is not predicted at all
%   (outcome/3), rather than predicted wrong.
eval(E, _, _) :- throw(oia_analysis_unsupported(E)).

text_of(str(S), S).
text_of(num(N), S) :- ( integer(N) -> number_string(N, S) ; N =:= truncate(N) -> I is truncate(N), number_string(I, S) ; format(string(S), "~15g", [N]) ).
text_of(date(Y, M, D), S) :- format(string(S), "~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, D]).

compare_values(eq, A, B) :- same_value(A, B).
compare_values(ne, A, B) :- \+ same_value(A, B).
compare_values(Op, A, B) :- memberchk(Op, [gt, ge, lt, le]), order_key(A, KA), order_key(B, KB),
    ( Op == gt -> KA > KB ; Op == ge -> KA >= KB ; Op == lt -> KA < KB ; KA =< KB ).

same_value(str(A), str(B)) :- !, string_lower(A, L), string_lower(B, L).   % OIA text comparison ignores case
same_value(num(A), num(B)) :- !, A =:= B.
same_value(num(A), str(B)) :- !, number_string(N, B), A =:= N.
same_value(str(A), num(B)) :- !, number_string(N, A), N =:= B.
same_value(A, B) :- A == B.

order_key(num(N), N).
order_key(date(Y, M, D), K) :- K is Y * 10000 + M * 100 + D.
order_key(str(S), N) :- number_string(N, S).

%   OIA's arithmetic is decimal and the twin writes decimal constants as
%   fractions (0.07 as 7 / 100), so the evaluator computes exactly and gives
%   the result the way LE computes and prints it: a whole number as an
%   integer (70, not 70.0), anything else as a float.
arith(Op, X0, Y0, Z) :-
    exact(X0, X), exact(Y0, Y),
    arith_exact(Op, X, Y, Z0),
    le_number(Z0, Z).

arith_exact(mul, X, Y, Z) :- Z is X * Y.
arith_exact(add, X, Y, Z) :- Z is X + Y.
arith_exact(sub, X, Y, Z) :- Z is X - Y.
arith_exact(div, X, Y, Z) :- Y =\= 0, Z is X rdiv Y.

exact(X, R) :- float(X), !, R is rationalize(X).
exact(X, X).

le_number(Z, N) :- rational(Z), \+ integer(Z), !, N is float(Z).
le_number(Z, N) :- float(Z), Z =:= float_integer_part(Z), abs(Z) < 1.0e15, !, N is integer(Z).
le_number(Z, Z).

%   An attribute: an instance's identifying value, an entity attribute (its
%   entity's tables), a derived global (its rule), or an input.
att_value(K, ctx(_, inst(E, Id)), Id) :- model_ents(ER), memberchk(ent(E, K, _), ER), !.
att_value(K, ctx(A, inst(E, Id)), V) :-
    model_ents(ER), memberchk(ent(E, _, Ks), ER), memberchk(K, Ks), !,
    model_rules(Rules),
    (   member(rule(_, _, _, _, table(E, CCols, Cs)), Rules), member(concl(K, Vals), Cs)
    ->  table_value(CCols, Vals, ctx(A, inst(E, Id)), V)
    ;   input_value(K, A, V)
    ).
att_value(K, C, V) :-
    model_rules(Rules),
    (   member(rule(_, _, _, _, T), Rules), rule_for(T, K)
    ->  derived_value(T, K, C, V)
    ;   member(rule(_, _, _, _, conclude(_, _, _, Cond, _)), Rules),
        sub_term(inline(T), Cond), T = conclude(K, _, _, _, _)
    ->  derived_value(T, K, C, V)
    ;   C = ctx(A, _), input_value(K, A, V)
    ).

rule_for(conclude(K, _, _, _, _), K).
rule_for(table(global, _, Cs), K) :- memberchk(concl(K, _), Cs).

input_value(K, A, V) :-
    (   memberchk(K-V0, A)
    ->  ( V0 == unknown -> V = unknown ; V = V0 )
    ;   touch(K), V = unknown
    ).

derived_value(conclude(_, _, true, Cond, _), _, C, V) :- !,
    eval(Cond, C, V0), ( V0 == true -> V = true ; V0 == false -> V = false ; V = unknown ).
derived_value(conclude(_, _, false, Cond, _), _, C, V) :- !,
    eval(Cond, C, V0), ( V0 == true -> V = false ; V0 == false -> V = true ; V = unknown ).
derived_value(conclude(_, _, Expr, Cond, Else), _, C, V) :- !,
    eval(Cond, C, V0),
    (   V0 == true -> eval(Expr, C, V)
    ;   V0 == false, Else \== none, Else \== false, Else \== uncertain_value -> eval(Else, C, V)
    ;   V = unknown
    ).
derived_value(table(_, CCols, Cs), K, C, V) :-
    memberchk(concl(K, Vals), Cs),
    table_value(CCols, Vals, C, V).

%   First match: a row whose condition is unknown stops the table.
table_value(CCols, Vals, C, V) :-
    length(Vals, N), numlist(1, N, Is),
    first_row(Is, CCols, Vals, C, V).

first_row([], _, _, _, unknown).
first_row([I|Is], CCols, Vals, C, V) :-
    row_expr(CCols, I, RE),
    eval(RE, C, R),
    (   R == true -> nth1(I, Vals, VE), ( VE == uncertain_value -> V = unknown ; eval(VE, C, V) )
    ;   R == false -> first_row(Is, CCols, Vals, C, V)
    ;   V = unknown
    ).

row_expr(CCols, I, and(Cs)) :-
    findall(E, ( member(col(H, Cells), CCols), nth1(I, Cells, Cell), cell_expr(H, Cell, E) ), Cs).

cell_expr(_, empty, true).
cell_expr(_, cond(E), E).
cell_expr(H, op(Tag, [E]), X) :- tag_op(Tag, Op), X =.. [Op, H, E].

tag_op(equals, eq). tag_op('not-equals', ne). tag_op('greater-than', gt).
tag_op('greater-than-equals', ge). tag_op('less-than', lt). tag_op('less-than-equals', le).

%   An entity's instances: one per matching row of a table concluding a
%   relationship to it (every row, not the first).
instances(E, A, Ids) :-
    model_rules(Rules), model_ents(ER),
    findall(Id, ( member(rule(_, _, _, _, table(_, CCols, Cs)), Rules),
                  member(concl(rel(R), Vals), Cs), memberchk(rel(R, E), ER),
                  nth1(I, Vals, VE), VE \== uncertain_value,
                  row_expr(CCols, I, RE), eval(RE, ctx(A, top), true),
                  eval(VE, ctx(A, top), Id) ), Ids0),
    list_to_set(Ids0, Ids).

		 /*******************************
		 *   THE PATHS (SATISFACTION)   *
		 *******************************/

%   sat(+E, +Ctx, +A0, -A): A extends A0 so that E is TRUE; fals/4 FALSE.
%   Assignments hold K-b(Value, Opposite): the input's value and the one
%   that fails the condition that chose it (for the near misses), or none.
bool_key(K) :- model_types(KTs), memberchk(K-boolean, KTs), !.
bool_key(K) :- model_rules(Rules), member(rule(_, _, _, _, conclude(K, _, V, _, _)), Rules), ( V == true ; V == false ), !.

sat(cite(_, E), C, A0, A) :- !, sat(E, C, A0, A).
sat(true, _, A, A) :- !.
sat(and(L), C, A0, A) :- !, sat_all(L, C, A0, A).
sat(or(L), C, A0, A) :- !, member(E, L), sat(E, C, A0, A).
sat(not(E), C, A0, A) :- !, fals(E, C, A0, A).
sat(inline(conclude(_, _, true, Cond, _)), C, A0, A) :- !, sat(Cond, C, A0, A).
sat(known(E), _, A0, A) :- !, strip(E, att(K)), input_key(K), bind_known(K, unknown, A0, A).
sat(unknown(E), _, A0, A) :- !, strip(E, att(K)), input_key(K), bind(K, unknown, known, A0, A).
sat(att(K), C, A0, A) :- !,
    (   derived_rule(K, T) -> sat_rule(T, K, true, C, A0, A)
    ;   bind(K, true, false, A0, A)
    ).
sat(E, C, A0, A) :- comparison(E, Op, L, R), !, solve(Op, L, R, C, A0, A).

fals(cite(_, E), C, A0, A) :- !, fals(E, C, A0, A).
fals(false, _, A, A) :- !.
fals(and(L), C, A0, A) :- !, member(E, L), fals(E, C, A0, A).
fals(or(L), C, A0, A) :- !, fals_all(L, C, A0, A).
fals(not(E), C, A0, A) :- !, sat(E, C, A0, A).
fals(inline(conclude(_, _, true, Cond, _)), C, A0, A) :- !, fals(Cond, C, A0, A).
fals(known(E), _, A0, A) :- !, strip(E, att(K)), input_key(K), bind(K, unknown, known, A0, A).
fals(unknown(E), _, A0, A) :- !, strip(E, att(K)), input_key(K), bind_known(K, unknown, A0, A).
fals(att(K), C, A0, A) :- !,
    (   derived_rule(K, T) -> sat_rule(T, K, false, C, A0, A)
    ;   bind(K, false, true, A0, A)
    ).
fals(E, C, A0, A) :- comparison(E, Op, L, R), !, negate(Op, NOp), solve(NOp, L, R, C, A0, A).

strip(cite(_, E), X) :- !, strip(E, X).
strip(E, E).

comparison(E, Op, L, R) :- compound(E), E =.. [Op, L, R], memberchk(Op, [eq, ne, gt, ge, lt, le]).

negate(eq, ne). negate(ne, eq). negate(gt, le). negate(ge, lt). negate(lt, ge). negate(le, gt).

derived_rule(K, T) :-
    model_rules(Rules),
    (   member(rule(_, _, _, _, T), Rules), rule_for(T, K) -> true
    ;   member(rule(_, _, _, _, conclude(_, _, _, Cond, _)), Rules),
        sub_term(inline(T), Cond), T = conclude(K, _, _, _, _) -> true
    ).

input_key(K) :- \+ derived_rule(K, _).

%   A boolean conclusion reaches Truth.
sat_rule(conclude(_, _, true, Cond, _), _, true, C, A0, A) :- !, sat(Cond, C, A0, A).
sat_rule(conclude(_, _, true, Cond, _), _, false, C, A0, A) :- !, fals(Cond, C, A0, A).
sat_rule(conclude(_, _, false, Cond, _), _, true, C, A0, A) :- !, fals(Cond, C, A0, A).
sat_rule(conclude(_, _, false, Cond, _), _, false, C, A0, A) :- !, sat(Cond, C, A0, A).
sat_rule(table(_, CCols, Cs), K, Truth, C, A0, A) :-
    memberchk(concl(K, Vals), Cs),
    nth1(I, Vals, VE), VE == Truth,
    rows_before_fail(I, CCols, C, A0, A1),
    row_expr(CCols, I, RE), sat(RE, C, A1, A).

rows_before_fail(I, CCols, C, A0, A) :-
    I1 is I - 1, numlist(1, I1, Js0), ( I1 < 1 -> Js = [] ; Js = Js0 ),
    fals_rows(Js, CCols, C, A0, A).

fals_rows([], _, _, A, A).
fals_rows([J|Js], CCols, C, A0, A) :- row_expr(CCols, J, RE), fals(RE, C, A0, A1), fals_rows(Js, CCols, C, A1, A).

sat_all([], _, A, A).
sat_all([E|Es], C, A0, A) :- sat(E, C, A0, A1), sat_all(Es, C, A1, A).
fals_all([], _, A, A).
fals_all([E|Es], C, A0, A) :- fals(E, C, A0, A1), fals_all(Es, C, A1, A).
%   An and/or: Decider (false for and, true for or) among the values
%   decides it, whatever the unknown ones — and the inputs only those
%   unknown ones read are then not needed (not touched). V: Decider,
%   unknown, or none (every value the other one).
eval_decided(L, C, Decider, V) :-
    tget(T0),
    eval_each(L, C, Rs),
    (   memberchk(Decider-_, Rs) -> V = Decider, nb_setval(oia_touched, T0)
    ;   memberchk(unknown-_, Rs) -> V = unknown,
        findall(K, ( member(_-Ts, Rs), member(K, Ts) ), New), append(T0, New, T), nb_setval(oia_touched, T)
    ;   V = none, nb_setval(oia_touched, T0)
    ).

eval_each([], _, []).
eval_each([E|Es], C, [R-Ts|Rs]) :-
    tget(T0),
    nb_setval(oia_touched, []),
    eval(E, C, R),
    tget(Ts),
    nb_setval(oia_touched, T0),
    eval_each(Es, C, Rs).

tget(T) :- ( nb_current(oia_touched, T0) -> T = T0 ; T = [] ).

touch(K) :-
    ( nb_current(oia_touched, T) -> true ; T = [] ),
    nb_setval(oia_touched, [K|T]).

%   A value goal: the ways its rule computes it.
valsat(K, C, A0, A, K) :-
    derived_rule(K, T), !,
    (   T = conclude(_, _, Expr, Cond, _)
    ->  sat(Cond, C, A0, A1), expr_inputs(Expr, C, A1, A)
    ;   T = table(_, CCols, Cs), memberchk(concl(K, Vals), Cs),
        nth1(I, Vals, VE), VE \== uncertain_value,
        rows_before_fail(I, CCols, C, A0, A1),
        row_expr(CCols, I, RE), sat(RE, C, A1, A2),
        expr_inputs(VE, C, A2, A)
    ).
valsat(K, _, A0, A, K) :- bind_known(K, A0, A).

%   The attributes a value expression reads: derived ones reached, inputs
%   given a value.
expr_inputs(E, C, A0, A) :-
    findall(K, sub_term(att(K), E), Ks0), list_to_set(Ks0, Ks),
    reach_all(Ks, C, A0, A).

reach_all([], _, A, A).
reach_all([K|Ks], C, A0, A) :- reach(K, C, A0, A1), reach_all(Ks, C, A1, A).

reach(K, C, A0, A) :-
    (   memberchk(K-_, A0) -> A = A0
    ;   derived_rule(K, _) -> valsat(K, C, A0, A, _)
    ;   bind_known(K, A0, A)
    ).

bind(K, V, Opp, A0, A) :-
    (   memberchk(K-b(V0, _), A0) -> V0 == V, A = A0
    ;   A = [K-b(V, Opp)|A0]
    ).

bind_known(K, A0, A) :- bind_known(K, none, A0, A).

bind_known(K, Opp, A0, A) :-
    (   memberchk(K-b(V0, _), A0) -> V0 \== unknown, A = A0
    ;   default_value(K, V), A = [K-b(V, Opp)|A0]
    ).

%   A comparison made to hold: the attribute side gets the value at the
%   limit, its opposite the value just past it.
solve(Op, L0, R0, C, A0, A) :-
    strip(L0, L), strip(R0, R),
    (   L = att(K), input_key(K), \+ memberchk(K-_, A0), rhs_value(R, C, A0, A1, VR)
    ->  witness(Op, K, VR, V, Opp), bind(K, V, Opp, A1, A)
    ;   R = att(K), input_key(K), \+ memberchk(K-_, A0), rhs_value(L, C, A0, A1, VL)
    ->  flip(Op, FOp), witness(FOp, K, VL, V, Opp), bind(K, V, Opp, A1, A)
    ;   L = att(K), derived_rule(K, _), rhs_value(R, C, A0, A1, VR),
        valsat(K, C, A1, A, _),
        clean(A, CA), eval(att(K), ctx(CA, top), VK), VK \== unknown,
        compare_values(Op, VK, VR)
    ;   clean(A0, CA), E =.. [Op, L, R], eval(E, ctx(CA, top), true), A = A0
    ).

flip(eq, eq). flip(ne, ne). flip(gt, lt). flip(ge, le). flip(lt, gt). flip(le, ge).

%   The other side's value: a constant, or an expression over inputs (each
%   given its value, a default when it has none).
rhs_value(E, C, A0, A, V) :-
    findall(K, sub_term(att(K), E), Ks0), list_to_set(Ks0, Ks),
    reach_all(Ks, C, A0, A),
    clean(A, CA), eval(E, ctx(CA, top), V), V \== unknown.

witness(eq, K, V, V, Opp) :- !, other_value(K, V, Opp).
witness(ne, K, V, W, V) :- !, other_value(K, V, W).
witness(ge, _, V, V, P) :- !, pred_value(V, P).
witness(gt, _, V, S, V) :- !, succ_value(V, S).
witness(lt, _, V, P, V) :- !, pred_value(V, P).
witness(le, _, V, V, S) :- !, succ_value(V, S).

pred_value(num(N), num(P)) :- P is N - 1.
pred_value(date(Y, M, D), P) :- add_days(date(Y, M, D), -1, P).
pred_value(str(S), str(P)) :- number_string(N, S), P0 is N - 1, number_string(P0, P).
succ_value(num(N), num(P)) :- P is N + 1.
succ_value(date(Y, M, D), P) :- add_days(date(Y, M, D), 1, P).
succ_value(str(S), str(P)) :- number_string(N, S), P0 is N + 1, number_string(P0, P).

%   Another value of the same attribute: one the rules compare it with,
%   else a made-up one.
other_value(K, str(S), str(O)) :- !,
    model_rules(Rules),
    (   member(rule(_, _, _, _, T), Rules), sub_term(X, T), compound(X), X =.. [_, A, str(O)],
        strip(A, att(K)), string_lower(O, LO), string_lower(S, LS), LO \== LS
    ->  true
    ;   string_concat("NOT ", S, O)
    ).
other_value(_, num(N), num(M)) :- !, M is N + 1.
other_value(_, date(Y, M, D), O) :- !, add_days(date(Y, M, D), 1, O).
other_value(_, true, false) :- !.
other_value(_, false, true) :- !.
other_value(_, V, V).

default_value(K, V) :-
    ( model_types(KTs), memberchk(K-T, KTs) -> true ; T = text ),
    type_default(T, K, V).

type_default(boolean, _, false) :- !.
type_default(number, _, num(5)) :- !.
type_default(currency, _, num(1000)) :- !.
type_default(date, _, date(2024, 1, 15)) :- !.
type_default(datetime, _, date(2024, 1, 15)) :- !.
type_default(_, K, V) :-                      % text, auto: a value the rules compare it with
    model_rules(Rules),
    (   member(rule(_, _, _, _, T), Rules), sub_term(X, T), compound(X), X =.. [_, A, B],
        strip(A, att(K)), ( B = str(_) ; B = num(_) ; B = date(_, _, _) )
    ->  V = B
    ;   member(rule(_, _, _, _, table(_, CCols, _)), Rules), member(col(att(K), Cells), CCols),
        member(op(_, [B]), Cells), ( B = str(_) ; B = num(_) ; B = date(_, _, _) )
    ->  V = B
    ;   V = str("OTHER")
    ).

		 /*******************************
		 *            DATES             *
		 *******************************/

add_days(date(Y, M, D), N, date(Y1, M1, D1)) :-
    date_time_stamp(date(Y, M, D, 12, 0, 0, 0, -, -), S),
    S1 is S + N * 86400,
    stamp_date_time(S1, date(Y1, M1, D1, _, _, _, _, _, _), 'UTC').

%   Calendar months, the day kept or clamped to the month's end (OIA's
%   AddMonths).
add_months(date(Y, M, D), N, date(Y1, M1, D1)) :-
    T is Y * 12 + (M - 1) + N,
    Y1 is T // 12, M1 is T mod 12 + 1,
    month_days(Y1, M1, ML), D1 is min(D, ML).

month_days(Y, 2, D) :- !, ( ( Y mod 4 =:= 0, Y mod 100 =\= 0 ; Y mod 400 =:= 0 ) -> D = 29 ; D = 28 ).
month_days(_, M, 30) :- memberchk(M, [4, 6, 9, 11]), !.
month_days(_, _, 31).

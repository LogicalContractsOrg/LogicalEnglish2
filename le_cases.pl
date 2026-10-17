/** <module> Case search: every case in which a goal holds

        query paths is:
            which cases make it the case that
                a person acquires British citizenship on a date.

        query double benefit is:
            is there a case in which
                a person gets benefit a
                and the person gets benefit b.

    docs/user/reference/language.md §17.11. lpsPlus docs/strategy/AboutImandra.md
    §5.1 and §5.2.

    A *case* is what a scenario would have to say for the goal to hold: the
    facts of the scenario-element templates (le_flip:changeable/2: the
    templates marked `; undefined` or `; judged`, or, in a program that marks
    none, the templates no rule concludes and the program states no fact of),
    the facts that must be absent, and the comparisons the values must meet.
    The search is the reasoner itself, in a mode (reasoner:exploring_cases/1)
    in which, on an empty scenario,

    - a goal of a scenario-element template is assumed (explorable/4);
    - `it is not the case that G` holds by assuming that each way G could hold
      fails: for each set of assumptions that would prove G, one of them is
      denied (explore_negation/7);
    - a comparison on a value no fact has given yet becomes a constraint,
      kept by library(clpq) for numbers, and solved at the end for dates
      (explore_built_in/2).

    Each distinct case is then checked: its facts must not contradict what it
    denies, and the program's integrity constraints (`it must not be true
    that …`) must allow it. A case that a smaller one already gives is
    dropped. Each case is rendered twice: in general terms ("a person is born
    in the UK on a date"), and as a ready-made scenario with individuals and
    values chosen to meet it (the witness). Each case also says which of the
    program's own scenarios meet it, so that the cases no scenario covers —
    the cases the program's tests never tried — stand out.

    What the search cannot treat exactly is said on each answer (note/1): an
    aggregate or a "for all cases" over assumed facts, a condition kept as
    stated because it could not be solved, or a limit reached.
*/

:- module(le_cases, [
    cases/5,                   % +Goal, +Mode, +SM, +KM, -Cases
    explorable/4,              % +G, +SM, +KM, +Anc
    assume/3,
    rejoin/2,                  % +G, +KM, -Us
    explore_built_in/2,        % +G, -Us
    explore_negation/7,        % +Goal, +SM, +KM, +Anc, +D, +ID, -Us
    explore_aggregate/3,       % +Type, +Values, -Result
    note/1,                    % +Note
    case_words/3,              % +KM, +Case, -Words
    case_json/3                % +KM, +Case, -JSON
]).

:- use_module(library(clpq)).
:- use_module(library(apply)).
:- use_module(library(lists)).
:- use_module(library(pairs)).
:- use_module(le_i18n).

:- thread_local note_seen/1.
:- thread_local search_kb/1.

%   Limits of one search. The flags let a test or a server change them.
max_cases(Max) :-
    ( current_prolog_flag(le_cases_max, M), integer(M) -> Max = M ; Max = 200 ).
max_negation_proofs(Max) :-
    ( current_prolog_flag(le_cases_max_negation_proofs, M), integer(M) -> Max = M ; Max = 40 ).
max_denials(Max) :-
    ( current_prolog_flag(le_cases_max_denials, M), integer(M) -> Max = M ; Max = 64 ).
search_seconds(S) :-
    ( current_prolog_flag(le_cases_seconds, S0), number(S0) -> S = S0 ; S = 60 ).

%!  note(+Note) is det.
%   Something the current search could not treat exactly.
note(N) :- ( note_seen(N) -> true ; assertz(note_seen(N)) ).

		 /*******************************
		 *	     the search		*
		 *******************************/

%!  cases(+Goal, +Mode, +SM, +KM, -Cases) is det.
%
%   Mode is `all` (which cases make it the case that …) or `any` (is there a
%   case in which …). Cases is a list of Case-Proof: Case is
%   case(Index, Count, Literals, Witness, CoveredBy, Notes), or, when `any`
%   finds none, no_case(Complete, Notes). Proof is the explanation of the
%   goal under the case's assumptions, ready for display.
cases(Goal, _Mode, _SM, KM, Cases) :-
    retractall(note_seen(_)),
    retractall(search_kb(_)), assertz(search_kb(KM)),
    max_cases(Max),
    search_seconds(Secs),
    le_kbs:createSession(KM, T),
    b_setval(le_case_assumed, []),
    get_time(T0), Deadline is T0 + Secs,
    nb_setval(le_cases_deadline, Deadline-Secs),
    setup_call_cleanup(
        assertz(reasoner:exploring_cases(KM)),
        catch(call_with_time_limit(Secs, collect(Goal, T, KM, Max, Raw)),
              time_limit_exceeded, ( note(time_limit(Secs)), Raw = [] )),
        ( retractall(reasoner:exploring_cases(_)), le_kbs:destroySession(T),
          nb_setval(le_cases_deadline, none) )),
    length(Raw, NRaw),
    ( NRaw >= Max -> note(case_limit(Max)) ; true ),
    minimal_cases(Raw, Minimal),
    findall(N, note_seen(N), Notes),
    length(Minimal, Count),
    (   Minimal == []
    ->  ( Notes == [] -> Complete = true ; Complete = false ),
        Cases = [no_case(Complete, Notes)-[]]
    ;   findall(case(I, Count, Lits, Witness, Covered, CaseNotes)-Proof,
                ( nth1(I, Minimal, raw(Lits, Witness, Proof)),
                  covered_by(KM, Lits, Covered),
                  ( memberchk(cond(_), Lits) -> append(Notes, [kept_as_stated], CaseNotes) ; CaseNotes = Notes ) ),
                Cases)
    ).

%   The search's own clock. call_with_time_limit/2 raises its exception
%   once, wherever the search happens to be, and a catch-all on the way (the
%   reasoner has several, around goals that may raise errors) can swallow it,
%   leaving the search to run on. So the search's hooks (assume/3,
%   explore_negation/7, explore_built_in/2) also look at the deadline, and
%   past it they fail: a failure goes through every catch, and prunes the
%   rest of the search at once.
in_time :-
    (   nb_current(le_cases_deadline, Deadline-Secs)
    ->  get_time(Now),
        (   Now =< Deadline
        ->  true
        ;   note(time_limit(Secs)), fail
        )
    ;   true
    ).

%   One raw(Literals, Witness, Proof) per distinct proof of Goal on the empty
%   scenario T, the literals in general terms (variables numbered), the
%   witness with every place filled.
collect(Goal, T, KM, Max, Raw) :-
    reasoner:with_saved_reasoner_state(le_cases:collect_(Goal, T, KM, Max, Pairs00)),
    %  no constraint leaves the search: findall/3 copied them with the cases
    maplist(plain_copy, Pairs00, Pairs0),
    keep_first_per_key(Pairs0, Pairs),
    pairs_values(Pairs, Raw).

collect_(Goal, T, KM, Max, Pairs) :-
    findall(Key-raw(Lits, Witness, Proof),
            limit(Max,
                  ( copy_term(Goal, G0),
                    %  the objects the query is about, named while the search
                    %  runs (an aggregate copies the free variables of its
                    %  condition, which would make the query's object another
                    %  one inside it), and variables again in the case found
                    name_owners(G0),
                    reasoner:solve(G0, T, KM, [], 0, none, Us, Whys00),
                    resolve_denials(Us, KM, Lits10, 200),
                    tighten_bounds(Lits10, Lits00),
                    consistent_case(Lits00, T, KM),
                    unname_owners(c(Lits00, G0, Whys00), c(Lits0, G, Whys0)),
                    case_key(Lits0, Key),
                    general_literals(Lits0, Lits),
                    witness(KM, Lits0, G, Witness),
                    proof_for_display(Whys0, T, Proof) )),
            Pairs).

%   name_owners(+Goal): each variable in the first place of a literal of
%   Goal, and in no last place of one, becomes '$le_owner'(N).
name_owners(Goal) :-
    conj_literals(Goal, Ls),
    findall(V, ( member(L, Ls), compound(L), arg(1, L, V), var(V) ), Owners0),
    findall(V, ( member(L, Ls), compound(L), functor(L, _, A), A >= 2, arg(A, L, V), var(V) ), Values),
    exclude(var_in(Values), Owners0, Owners1),
    term_variables(Owners1, Owners),
    foldl(owner_name, Owners, 1, _).

var_in(Vs, V) :- member(W, Vs), W == V, !.
owner_name(V, N0, N) :- V = '$le_owner'(N0), N is N0 + 1.

conj_literals(G, []) :- var(G), !.
conj_literals((A, B), Ls) :- !, conj_literals(A, LA), conj_literals(B, LB), append(LA, LB, Ls).
conj_literals(le_cases(G, _, _), Ls) :- !, conj_literals(G, Ls).
conj_literals(G, [G]).

%   unname_owners(+Term0, -Term): Term0 with each '$le_owner'(N) a variable,
%   the same one for the same N.
unname_owners(T0, T) :-
    unname(T0, T, [], _).

unname(X, X, M, M) :- var(X), !.
unname('$le_owner'(N), V, M0, M) :- !,
    ( memberchk(N-V0, M0) -> V = V0, M = M0 ; M = [N-V|M0] ).
unname(X, Y, M0, M) :- compound(X), !,
    X =.. [F|As], unname_args(As, Bs, M0, M), Y =.. [F|Bs].
unname(X, X, M, M).

unname_args([], [], M, M).
unname_args([A|As], [B|Bs], M0, M) :- unname(A, B, M0, M1), unname_args(As, Bs, M1, M).

%!  tighten_bounds(+Lits0, -Lits) is det.
%
%   The comparisons of a case on a single value, replaced by the bounds clpq
%   gives that value: "the amount is less than or equal to 15000" for
%   "… ≤ 15000 and … < 20000".
tighten_bounds(Lits0, Lits) :-
    partition(single_value_cmp, Lits0, Cmps, Rest),
    term_variables(Cmps, Vs),
    include(constrained, Vs, Numeric),
    (   Numeric == []
    ->  Lits = Lits0
    ;   foldl(bound_literals, Numeric, [], Bounds0),
        reverse(Bounds0, Bounds),
        exclude(bounded_cmp(Numeric), Cmps, Kept),
        append([Rest, Kept, Bounds], Lits1),
        reading_order(Lits1, Lits)
    ).

%   Facts first, then the comparisons on their values, then what must be
%   absent.
reading_order(Lits0, Lits) :-
    partition(is_pos, Lits0, Pos, Rest0),
    partition(is_den, Rest0, Dens, Others),
    append([Pos, Others, Dens], Lits).

is_pos(pos(_)).

single_value_cmp(cmp(G)) :-
    G =.. [F, _, _], comparison(F, _),
    term_variables(G, [_]).

bounded_cmp(Numeric, cmp(G)) :-
    term_variables(G, [V]), member(W, Numeric), W == V, !.

bound_literals(V, Acc0, Acc) :-
    (   catch(inf(V, I1), _, fail)
    ->  plain_number(I1, I), I0 = I1,
        ( catch(entailed(V > I0), _, fail) -> L1 = [cmp(le_gt(V, I))] ; L1 = [cmp(le_ge(V, I))] )
    ;   L1 = []
    ),
    (   catch(sup(V, S1), _, fail)
    ->  plain_number(S1, S), S0 = S1,
        ( catch(entailed(V < S0), _, fail) -> L2 = [cmp(le_lt(V, S))] ; L2 = [cmp(le_le(V, S))] )
    ;   L2 = []
    ),
    (   L1 = [cmp(le_ge(_, B))], L2 = [cmp(le_le(_, B))]
    ->  Ls = [cmp(le_equal_to(V, B))]
    ;   append(L1, L2, Ls)
    ),
    reverse(Ls, RLs),
    append(RLs, Acc0, Acc).

%   A rational of clpq (7r20) as the number a reader writes (0.35).
plain_number(R, N) :-
    (   integer(R) -> N = R
    ;   rational(R) -> N is float(R)
    ;   N = R
    ).

keep_first_per_key(Pairs0, Pairs) :- keep_first_per_key(Pairs0, [], Pairs).
keep_first_per_key([], _, []).
keep_first_per_key([K-V|Ps], Seen, Out) :-
    (   memberchk(K, Seen)
    ->  Out = Out1, Seen1 = Seen
    ;   Out = [K-V|Out1], Seen1 = [K|Seen]
    ),
    keep_first_per_key(Ps, Seen1, Out1).

remove_variants([], []).
remove_variants([X|Xs], [X|Ys]) :-
    exclude(==(X), Xs, Xs1),
    remove_variants(Xs1, Ys).

%   A case denies none of what it assumes, and the program's integrity
%   constraints allow what it assumes.
consistent_case(Lits, T, KM) :-
    findall(P, member(pos(P), Lits), Ps),
    (   Ps == []
    ->  true
    ;   catch(reasoner:consistent_assumptions(Ps, T, KM), _, true)
    ).

%   The same case reached by two proofs has the same key: its literals with
%   the variables numbered, in a standard order, and the constraints clpq
%   holds on them.
case_key(Lits, Key) :-
    term_variables(Lits, Vs),
    copy_term(Vs-Lits, Vs1-Lits1, Gs),
    numbervars(Vs1-Lits1-Gs, 0, _),
    msort(Lits1, L), msort(Gs, G),
    Key = L-G.

general_literals(Lits0, Lits) :-
    term_variables(Lits0, Vs),
    copy_term(Vs-Lits0, _-Lits, _).

%   Drop a case whose literals include all those of another, smaller case.
minimal_cases(Raw, Minimal) :-
    exclude(subsumed_by_other(Raw), Raw, Minimal).

subsumed_by_other(Raw, raw(L1, _, _)) :-
    member(raw(L2, _, _), Raw),
    L2 \== L1,
    length(L2, N2), length(L1, N1), N2 < N1,
    \+ \+ subsumes_literals(L2, L1), !.

subsumes_literals(Small, Big) :-
    copy_term(Big, BigC), numbervars(BigC, 0, _),
    copy_term(Small, SmallC),
    all_in(SmallC, BigC).

all_in([], _).
all_in([L|Ls], Big) :- member(L, Big), all_in(Ls, Big).

		 /*******************************
		 *	the reasoner's hooks	*
		 *******************************/

%!  explorable(+G, +SM, +KM, +Anc) is semidet.
%
%   G may be assumed in a case: its template is a scenario element, the
%   program states no fact of it (a template with facts in the program, such
%   as a table of rates, is read from those facts, never assumed), and no
%   assumption of the same goal is under way above it.
explorable(G, _SM, KM, _Anc) :-
    callable(G), G \= le_unknown(_),
    functor(G, F, A),
    \+ sub_atom(F, 0, 3, _, le_),
    F \== is_a,
    (   catch(le_flip:marked_template(KM, F, A), _, fail)
    ->  true
    ;   current_predicate(KM:le_unknown/1),
        catch(clause(KM:le_unknown(G), _), _, fail)
    ->  true
    ;   catch(le_kbs:template_of(KM, F, A, _, _), _, fail),
        \+ rule_concludes(KM, F, A)
    ),
    \+ program_has_facts(KM, F, A).

%!  assume(+G, +KM, -Us) is semidet.
%
%   G is assumed, on this branch of the search (and nothing is, past the
%   search's deadline: in_time/0). The assumptions of the
%   branch are kept in a backtrackable global variable, so that a fact the
%   branch already assumed is not assumed twice (Us = []), and a fact of a
%   template that gives one value (one_value_each/2) takes the value already
%   assumed for the same places — or fails, when the values cannot be the
%   same (an item with two HCPCS codes), which prunes the branch at once.
assume(G, KM, Us) :-
    in_time,
    ( nb_current(le_case_assumed, A0) -> true ; A0 = [] ),
    (   member(E, A0), E == G
    ->  Us = []
    ;   functional_twin(G, A0, KM, E)
    ->  G = E, Us = []
    ;   b_setval(le_case_assumed, [G|A0]),
        Us = [G]
    ).

%!  rejoin(+G, +KM) is det.
%
%   A fact an aggregate's solution assumed, joining the case after the
%   aggregate (whose solutions are copies): the same object as one the case
%   already assumed for the same owner, when there is one and nothing tells
%   them apart; otherwise a fact of the case like any other.
rejoin(G, KM) :-
    ( nb_current(le_case_assumed, A0) -> true ; A0 = [] ),
    (   member(E, A0), E == G
    ->  true
    ;   compound(G), G =.. [F|Args], append(Keys, [V], Args), Keys \== [], var(V),
        member(E, A0), compound(E), E =.. [F|EArgs], append(EKeys, [EV], EArgs),
        EKeys == Keys, var(EV)
    ->  V = EV
    ;   assume(G, KM, _)
    ).

functional_twin(G, Assumed, KM, E) :-
    compound(G), G =.. [F|Args], append(Keys, [_], Args), Keys \== [],
    member(E, Assumed), compound(E), E =.. [F|EArgs],
    append(EKeys, [_], EArgs), EKeys == Keys,
    ( value_place(KM, F, Args) ; value_place(KM, F, EArgs) ), !.

%   A rule of the program concludes F/A.
rule_concludes(KM, F, A) :-
    functor(H, F, A),
    current_predicate(KM:F/A),
    le_kbs:kb_own_predicate(KM, H),
    catch(clause(KM:H, B), _, fail), B \== true, !.

program_has_facts(KM, F, A) :-
    functor(H, F, A),
    current_predicate(KM:F/A),
    le_kbs:kb_own_predicate(KM, H),
    catch(clause(KM:H, true), _, fail), !.

%!  explore_built_in(+G, -Us) is semidet.
%
%   A built-in condition on a value no fact has given yet: a comparison
%   becomes a constraint on that value (Us = ['$le_cmp'(G)]); a formula
%   (`a total = a price * 2`) a definition of it (Us = ['$le_def'(G)]).
%   Fails when every value is known, so that the condition is evaluated as
%   usual.
explore_built_in(G, Us) :-
    in_time,
    open_condition(G),
    catch(explore_open(G, Us), error(type_error(_, _), _), Us = ['$le_cond'(G)]).

open_condition(le_is_days_after(L, N, B)) :- !,
    include(ground, [L, N, B], Known), length(Known, K), K < 2.
open_condition(G) :-
    G =.. [F|Args],
    memberchk(F, [le_ge, le_le, le_gt, le_lt, le_assign, le_is, le_equal_to,
                  le_not_equal_to, le_is_days_after, le_is_months_after,
                  le_minimum, le_maximum]),
    \+ ground(Args).

explore_open(G, ['$le_cmp'(G)]) :-
    G =.. [F, X, Y],
    comparison(F, Op), !,
    (   numeric_side(X), numeric_side(Y), \+ ( var(X), var(Y) )
    ->  post(Op, X, Y)
    ;   var(X), var(Y)
    ->  true                                   % typed and posted with the witness
    ;   date_side(X), date_side(Y)
    ->  true                                   % solved with the witness
    ;   true
    ).
explore_open(G, Us) :-
    G =.. [F, X, Y], memberchk(F, [le_assign, le_is]), !,
    (   var(X), numeric_side(Y), \+ ground(Y)
    ->  { X =:= Y }, Us = ['$le_def'(G)]
    ;   var(X), ground(Y)
    ->  fail                                   % plain evaluation binds X
    ;   numeric_side(X), numeric_side(Y)
    ->  { X =:= Y }, Us = ['$le_def'(G)]
    ;   Us = ['$le_cond'(G)]
    ).
explore_open(le_equal_to(X, Y), Us) :- !,
    (   numeric_side(X), numeric_side(Y), \+ ( var(X), var(Y) )
    ->  { X =:= Y }, Us = ['$le_cmp'(le_equal_to(X, Y))]
    ;   X = Y, Us = []
    ).
explore_open(le_not_equal_to(X, Y), ['$le_cmp'(le_not_equal_to(X, Y))]) :- !,
    (   numeric_side(X), numeric_side(Y), \+ ( var(X), var(Y) )
    ->  { X =\= Y }
    ;   dif(X, Y)
    ).
explore_open(le_is_days_after(L, N, B), ['$le_cmp'(le_is_days_after(L, N, B))]) :- !,
    % worked out by the witness, on day numbers: fewer than two of the three
    % are known (open_condition/1 and days_known/3)
    ( var(N) -> true ; number(N) ).
explore_open(G, ['$le_cond'(G)]).

%!  explore_aggregate(+Type, +Values, -Result) is semidet.
%
%   A total, count, minimum or maximum over values some of which a case
%   search has not fixed yet: a count is the number of values; a total is
%   kept by clpq as the sum of the values. The others keep their result
%   open. The search notes that an aggregate over assumed facts is
%   approximate (it counts the facts the case assumed, no more).
explore_aggregate(count, Values, N) :- !, length(Values, N).
%   a count of things the case assumed: a case may assume as many of them as
%   the rule needs, so the count is at least the number assumed so far (a
%   rule that needs exactly two payouts is met by a case with two)
explore_aggregate(count_assumed, Values, N) :- !,
    length(Values, L),
    note(count_assumed),
    { N >= L }.
explore_aggregate(sum, Values, Sum) :-
    maplist(numeric_side, Values), !,
    foldl([V, A0, A0 + V]>>true, Values, 0, Expr),
    catch({ Sum =:= Expr }, error(type_error(_, _), _), true).
%   a list is the values themselves, those still open included
explore_aggregate(list, Values, Values) :- !.
explore_aggregate(_, _, _).

comparison(le_ge, >=).
comparison(le_le, =<).
comparison(le_gt, >).
comparison(le_lt, <).

numeric_side(X) :- var(X), !, \+ date_attributed(X).
numeric_side(X) :- number(X), !.
numeric_side(X) :- compound(X), X \= date(_, _, _), \+ is_list(X),
    X =.. [F|As], memberchk(F, [+, -, *, /, min, max, abs]),
    maplist(numeric_side, As).

date_side(X) :- var(X), !.
date_side(date(_, _, _)) :- !.
date_side(X) :- atom(X), le_date_atom(X, _).

date_attributed(_) :- fail.

post(>=, X, Y) :- { X >= Y }.
post(=<, X, Y) :- { X =< Y }.
post(>, X, Y)  :- { X > Y }.
post(<, X, Y)  :- { X < Y }.

le_date_atom(A, date(Y, M, D)) :-
    atom(A),
    catch(( parse_time(A, iso_8601, Stamp), stamp_date_time(Stamp, DT, 'UTC'),
            date_time_value(year, DT, Y), date_time_value(month, DT, M),
            date_time_value(day, DT, D) ), _, fail).

%!  explore_negation(+Goal, +SM, +KM, +Anc, +D, +ID, -Us) is semidet.
%
%   `it is not the case that Goal` in a case search. Every proof of Goal is
%   found, with what each proof assumed. A proof that assumed nothing means
%   Goal holds outright, and the negation fails. Otherwise the negation holds
%   in a case in which none of those proofs goes through: Us is
%   ['$le_denied'(Goal, Proofs)], each proof the list of its assumptions, and
%   resolve_denials/3 makes sure, once the whole case is known, that each
%   one fails in it.
explore_negation(Goal, SM, KM, Anc, D, ID, Us) :-
    in_time,
    max_negation_proofs(MaxP),
    %  the variables a proof of Goal may bind: Goal's, and those of what the
    %  branch has assumed so far (assume/3 may unify a value with one of them)
    ( nb_current(le_case_assumed, Assumed) -> true ; Assumed = [] ),
    term_variables(Goal-Assumed, Outer),
    findall(Outer-Us0,
            limit(MaxP, reasoner:solve(Goal, SM, KM, Anc, D, ID, Us0, _)),
            Proofs0),
    length(Proofs0, NP),
    ( NP >= MaxP -> note(negation_limit(MaxP)) ; true ),
    (   member(O1-[], Proofs0), renaming(O1)
    ->  fail                               % Goal holds outright
    ;   Proofs0 == []
    ->  Us = []
    ;   %  a copy without constraints: those the proof posted on its own
        %  copy of the case's numbers must not flow back into them (the
        %  proof's comparisons are in its assumptions, '$le_cmp'(…))
        maplist(plain_copy, Proofs0, Proofs00),
        maplist(rebind(Outer), Proofs00, Proofs1),
        minimal_sets(Proofs1, Proofs),
        Us = ['$le_denied'(Goal, Proofs)]
    ).

%   findall/3 copied each proof. A proof that left the goal's variables open
%   is unified back with them, so that a variable bound above stays the same
%   variable. A proof that bound them (`hospital is excluded from being a
%   home`, for the place of the case) holds only for that binding: the
%   binding becomes a condition of the proof, '$le_eq'(Outer, Binding).
rebind(Outer, Outer1-Us, S) :-
    (   renaming(Outer1)
    ->  Outer1 = Outer, S = Us
    ;   S = ['$le_eq'(Outer, Outer1)|Us]
    ).

plain_copy(P0, P) :- copy_term(P0, P, _).

%   The copy of the variables is still a list of distinct variables: the
%   proof bound none of them.
renaming(Vs) :-
    maplist(var, Vs),
    sort(Vs, S), length(S, N), length(Vs, N).

minimal_sets(Sets0, Sets) :-
    exclude(has_smaller(Sets0), Sets0, Sets).

has_smaller(Sets, S) :-
    member(S2, Sets), S2 \== S,
    length(S2, N2), length(S, N), N2 < N,
    forall(member(X, S2), ( member(Y, S), X == Y )), !.

opposite(le_ge(X, Y), le_lt(X, Y)).
opposite(le_le(X, Y), le_gt(X, Y)).
opposite(le_gt(X, Y), le_le(X, Y)).
opposite(le_lt(X, Y), le_ge(X, Y)).
opposite(le_equal_to(X, Y), le_not_equal_to(X, Y)).
opposite(le_not_equal_to(X, Y), le_equal_to(X, Y)).

		 /*******************************
		 *	  resolving denials	*
		 *******************************/

%!  resolve_denials(+Us0, +KM, -Lits, +Rounds) is nondet.
%
%   The assumptions Us0 of a whole proof, as the literals of a case in which
%   each denied proof fails. A denied proof fails in the case when one of its
%   assumed facts is not among the case's facts (nothing to do: a case says
%   only what it says), or, for each way its facts match the case's, when
%
%   - one of its comparisons is false: the opposite comparison is added to
%     the case (`the amount is less than or equal to 15000`);
%   - a fact it needs absent is present: the fact is added;
%   - a proof it denies goes through: that proof's facts and comparisons are
%     added, and its own denials resolved in turn.
%
%   Each way of making the denied proofs fail is one solution. Adding facts
%   can make another denied proof match, so the check is repeated (up to
%   Rounds times).
resolve_denials(Us0, KM, Lits, Rounds) :-
    split_assumptions(Us0, Pos0, Others0, Dens0),
    one_value_each(KM, Pos0),
    resolve_loop(KM, Pos0, Others0, Dens0, Rounds, Pos, Others, _Dens),
    wrap_pos(Pos, PL),
    maplist(other_literal, Others, OL),
    append([PL, OL], Lits0),
    remove_variants(Lits0, Lits).

wrap_pos([], []).
wrap_pos([P|Ps], [pos(P)|Ls]) :- wrap_pos(Ps, Ls).



split_assumptions([], [], [], []).
split_assumptions([U|Us], Pos, Others, Dens) :-
    split_assumptions(Us, Pos1, Others1, Dens1),
    (   U = '$le_denied'(G, Ps)
    ->  Pos = Pos1, Others = ['$le_denied_goal'(G)|Others1], append(Ps, Dens1, Dens)
    ;   U = '$le_cmp'(_) -> Pos = Pos1, Others = [U|Others1], Dens = Dens1
    ;   U = '$le_def'(_) -> Pos = Pos1, Others = [U|Others1], Dens = Dens1
    ;   U = '$le_cond'(_) -> Pos = Pos1, Others = [U|Others1], Dens = Dens1
    ;   U = '$le_eq'(A, B)                     % a binding a nested proof made
    ->  ( A = B -> true ; true ), Pos = Pos1, Others = Others1, Dens = Dens1
    ;   Pos = [U|Pos1], Others = Others1, Dens = Dens1
    ).

other_literal('$le_denied_goal'(G), den(G)).
other_literal('$le_cmp'(G), cmp(G)).
other_literal('$le_def'(G), def(G)).
other_literal('$le_cond'(G), cond(G)).

resolve_loop(_, Pos, Others, Dens, 0, Pos, Others, Dens) :- !,
    ( violated(Dens, Pos, _, _) -> note(denial_rounds), fail ; true ).
resolve_loop(KM, Pos0, Others0, Dens0, N, Pos, Others, Dens) :-
    (   violated(Dens0, Pos0, S, Match)
    ->  falsify(S, Match, Pos0, Others0, Dens0, Pos1, Others1, Dens1),
        one_value_each(KM, Pos1),
        N1 is N - 1,
        resolve_loop(KM, Pos1, Others1, Dens1, N1, Pos, Others, Dens)
    ;   Pos = Pos0, Others = Others0, Dens = Dens0
    ).

%!  one_value_each(+KM, +Pos) is semidet.
%
%   A template whose last place holds a value (a number or a date) is read
%   as giving one value for the rest of its places: two facts of a case that
%   differ only in that value are the same fact (`a person has an income of
%   an amount` gives a person one income). Their values are unified, which
%   fails when the case's constraints keep them apart.
one_value_each(KM, Pos) :-
    (   select(P1, Pos, Rest), member(P2, Rest),
        compound(P1), P1 \== P2,
        P1 =.. [F|A1], P2 =.. [F|A2],
        append(K1, [V1], A1), append(K2, [V2], A2),
        K1 == K2, V1 \== V2,
        ( value_place(KM, F, A1) ; value_place(KM, F, A2) )
    ->  V1 = V2,
        one_value_each(KM, Pos)
    ;   true
    ).

value_place(KM, F, Args) :-
    last(Args, V),
    (   one_value(KM, F, Args) -> true
    ;   number(V) -> true
    ;   date_like(V) -> true
    ;   var(V), constrained(V) -> true
    ;   catch(le_flip:template_types(KM, F, Args, Pairs), _, fail),
        last(Pairs, _-T), memberchk(T, [number, date])
    ).

%   A template declared `; one value` (an included file's templates are the
%   program's own).
one_value(KM, F, Args) :-
    length(Args, A),
    catch(KM:le_one_value(F, A), _, fail), !.

%   A denied proof S that the case does not yet make fail: its facts match
%   the case's (Match: S with its own variables bound accordingly), its
%   comparisons can hold, no fact it needs absent is present, and each proof
%   it denies is already made to fail.
violated(Dens, Pos, S, Match) :-
    member(S, Dens),
    instance_of(S, Pos, Match),
    \+ already_false(Match, Pos), !.

%   A copy of S whose assumed facts are facts of the case, sharing the
%   case's variables.
instance_of(S, Pos, Match) :-
    term_variables(Pos, PVs),
    copy_term(PVs-S, PVs1-Match0, _),
    PVs1 = PVs,
    match_facts(Match0, Pos),
    Match = Match0.

match_facts([], _).
match_facts([U|Us], Pos) :-
    (   fact_assumption(U)
    ->  member(P, Pos), U = P
    ;   true
    ),
    match_facts(Us, Pos).

fact_assumption(U) :- \+ U = '$le_cmp'(_), \+ U = '$le_def'(_), \+ U = '$le_cond'(_),
    \+ U = '$le_denied'(_, _), \+ U = '$le_eq'(_, _), \+ U = '$le_denied_goal'(_).

%   Under the match, S already fails: a comparison cannot hold together with
%   the case's constraints, or a proof it denies goes through.
already_false(Match, Pos) :-
    (   member('$le_eq'(A, B), Match), \+ A = B
    ->  true
    ;   member('$le_cmp'(C), Match), \+ \+ \+ post_cmp(C)
    ->  true
    ;   member('$le_denied'(_, Ps), Match), member(P, Ps), matches_case(P, Pos),
        \+ \+ forall(member('$le_cmp'(C1), P), post_cmp(C1))
    ->  true
    ).

matches_case(S, Pos) :-
    \+ \+ instance_of(S, Pos, _).

%   Make the matched denied proof fail: one of its comparisons is made false,
%   or one of the proofs it denies is made to go through.
falsify(_S, Match, Pos, Others, Dens, Pos, Others, Dens) :-
    member('$le_eq'(A, B), Match),
    dif(A, B).
falsify(_S, Match, Pos, Others, Dens, Pos, [ '$le_cmp'(N) | Others ], Dens) :-
    member('$le_cmp'(C), Match),
    opposite(C, N),
    post_cmp(N).
falsify(_S, Match, Pos0, Others0, Dens0, Pos, Others, Dens) :-
    member('$le_denied'(_, Ps), Match),
    member(P, Ps),
    split_assumptions(P, PPos, POthers, PDens),
    maplist(post_other, POthers),
    append(Pos0, PPos, Pos),
    append(Others0, POthers, Others),
    append(Dens0, PDens, Dens).
falsify(_S, Match, Pos, Others, Dens, Pos, [ '$le_cond'(not(C)) | Others ], Dens) :-
    member('$le_cond'(C), Match).

post_other('$le_cmp'(C)) :- !, post_cmp(C).
post_other(_).

%   A comparison as a constraint: on numbers through clpq; on dates, or when
%   both sides are still unknown, it is kept and solved with the witness.
post_cmp(G) :-
    catch(post_cmp_(G), error(type_error(_, _), _), true).

post_cmp_(G) :-
    (   G =.. [F, X, Y], comparison(F, Op), numeric_side(X), numeric_side(Y),
        \+ ( var(X), var(Y) )
    ->  post(Op, X, Y)
    ;   G = le_not_equal_to(X, Y), numeric_side(X), numeric_side(Y), \+ ( var(X), var(Y) )
    ->  { X =\= Y }
    ;   G = le_not_equal_to(X, Y)
    ->  dif(X, Y)
    ;   G = le_equal_to(X, Y)
    ->  ( numeric_side(X), numeric_side(Y), \+ ( var(X), var(Y) ) -> { X =:= Y } ; X = Y )
    ;   true
    ).

		 /*******************************
		 *	      witnesses		*
		 *******************************/

%!  witness(+KM, +Lits, +Goal, -Witness) is det.
%
%   Witness is w(Lits1, Goal1): Lits and Goal with every open place filled —
%   numbers chosen to meet the constraints clpq holds, dates to meet the
%   date comparisons, and each individual named after its type
%   (`person_1`). The choice is made inside findall/3, so the variables of
%   Lits stay open for the rest of the search.
witness(KM, Lits, Goal, Witness) :-
    (   findall(w(Lits, Goal), fill_witness(KM, Lits, Goal), [W|_])
    ->  Witness = W
    ;   copy_term(Lits-Goal, L1-G1, _), Witness = w(L1, G1)
    ).

fill_witness(KM, Lits, Goal) :-
    term_variables(Lits-Goal, Vs0),
    partition(date_var(KM, Lits), Vs0, DateVs, _),
    choose_dates(Lits, DateVs),
    post_open_comparisons(Lits),
    term_variables(Lits-Goal, Vs1),
    include(constrained, Vs1, Numeric),
    maplist(choose_number, Numeric),
    term_variables(Lits-Goal, Rest),
    name_individuals(KM, Lits-Goal, Rest), !.

date_var(KM, Lits, V) :- var_type(KM, Lits, V, date).

%   A comparison between two values that were both unknown when it was met
%   is posted now, when the dates among them have been chosen.
post_open_comparisons(Lits) :-
    forall(( member(cmp(G), Lits), G =.. [F, X, Y], comparison(F, Op),
             \+ ground(G), numeric_side(X), numeric_side(Y) ),
           ( catch(post(Op, X, Y), _, true) -> true ; true )).

constrained(V) :- var(V), get_attr(V, clpqr_itf, _), !.
constrained(V) :- var(V), attvar(V), clpq_var(V).

clpq_var(V) :- catch(( inf(V, _) ; sup(V, _) ), _, fail), !.

%   A value within the constraints: the bound itself when it is attained,
%   one past it when it is strict, a middle value when both bounds are known.
choose_number(V) :-
    (   nonvar(V) -> true
    ;   ( catch(inf(V, I), _, fail) -> true ; I = none ),
        ( catch(sup(V, S), _, fail) -> true ; S = none ),
        candidate_values(I, S, Cands),
        member(C0, Cands),
        plain_number(C0, C1),
        ( float(C1) -> C = C0 ; C = C1 ),
        catch({ V =:= C }, _, fail)
    ->  ( rational(V), \+ integer(V) -> true ; true )
    ;   true
    ).

candidate_values(none, none, [0, 1, 100, 1000]) :- !.
candidate_values(I, none, Cs) :- !,
    R is ceiling(I),
    Cs0 = [I, R, R + 1, I + 1, R + 10, R + 100],
    maplist([E, V]>>(V is E), Cs0, Cs).
candidate_values(none, S, Cs) :- !,
    R is floor(S),
    Cs0 = [S, R, R - 1, S - 1, R - 10, R - 100],
    maplist([E, V]>>(V is E), Cs0, Cs).
candidate_values(I, S, Cs) :-
    M is (I + S) / 2,
    R1 is ceiling(I), R2 is floor(S),
    (   R1 =< R2
    ->  Mi is (R1 + R2) // 2, Cs = [Mi, M, R1, R2, I, S]
    ;   Cs = [M, I, S]
    ).

%   The date comparisons of a case, solved on day numbers: each open date is
%   given the earliest day that meets its comparisons with the known dates,
%   or a default when it has none.
choose_dates(_, []) :- !.
choose_dates(Lits, Vs) :-
    date_comparisons(Lits, Gs),
    length(Vs, N), length(Days, N),
    pairs_keys_values(Map, Vs, Days),
    maplist(date_constraint(Map), Gs),
    maplist(choose_day, Days),
    maplist(bind_date, Map).

%   The comparisons of a case between dates, and its date arithmetic (the
%   variables kept: findall/3 would copy them).
date_comparisons([], []).
date_comparisons([L|Ls], Gs) :-
    (   L = cmp(G),
        (   G = le_is_days_after(_, _, _)
        ->  true
        ;   G =.. [F, X, Y], comparison(F, _), date_side(X), date_side(Y)
        )
    ->  Gs = [G|Gs1]
    ;   Gs = Gs1
    ),
    date_comparisons(Ls, Gs1).

%   A day within its constraints; the first one free of them is the anchor,
%   1 January 2026, and the others follow from it.
choose_day(D) :-
    (   nonvar(D) -> true
    ;   ( catch(inf(D, _), _, fail) ; catch(sup(D, _), _, fail) )
    ->  choose_number(D)
    ;   catch({ D =:= 20454 }, _, true)
    ).

date_constraint(Map, le_is_days_after(L, N, B)) :- !,
    day_term(Map, L, DL), day_term(Map, B, DB),
    ( catch({ DL =:= DB + N }, _, fail) -> true ; true ).
date_constraint(Map, G) :-
    G =.. [F, X, Y], comparison(F, Op),
    day_term(Map, X, DX), day_term(Map, Y, DY),
    ( catch(post(Op, DX, DY), _, fail) -> true ; true ).

day_term(Map, X, D) :- var(X), !, ( member(V-D0, Map), V == X -> D = D0 ; D = _ ).
day_term(_, date(Y, M, Dd), D) :- !, date_day(date(Y, M, Dd), D).
day_term(_, A, D) :- le_date_atom(A, Dt), date_day(Dt, D).

date_day(date(Y, M, D), N) :-
    date_time_stamp(date(Y, M, D, 0, 0, 0, 0, -, -), S),
    N is round(S / 86400).

bind_date(V-Day) :-
    (   nonvar(V) -> true
    ;   ( var(Day) -> Day1 = 20454 ; Day1 is round(Day) ),   % 2026-01-01
        S is Day1 * 86400,
        stamp_date_time(S, date(Y, M, D, _, _, _, _, _, _), 'UTC'),
        format(atom(A), '~d-~|~`0t~d~2+-~|~`0t~d~2+', [Y, M, D]),
        V = A
    ).

%   Each individual still open is named after the type its place declares:
%   `person 1`, `person 2`, and so on.
name_individuals(KM, Term, Vs) :-
    retractall(individual_count(_, _)),
    maplist(name_individual(KM, Term), Vs).

:- thread_local individual_count/2.

name_individual(_, _, V) :- nonvar(V), !.
name_individual(KM, Term, V) :- name_individual_(KM, Term, V), !.
name_individual(_, _, _).

name_individual_(KM, Term, V) :-
    ( var_type(KM, Term, V, Type) -> true ; Type = thing ),
    ( Type == number -> V = 0
    ; Type == date -> bind_date(V-_)
    ; ( retract(individual_count(Type, N0)) -> true ; N0 = 0 ),
      N is N0 + 1, assertz(individual_count(Type, N)),
      atomic_list_concat(Parts, ' ', Type), atomic_list_concat(Parts, '_', T1),
      format(atom(V), '~w_~d', [T1, N])
    ).

%   The type a template declares for the place where V stands, in the first
%   literal of Term that has V at a typed place.
var_type(KM, Term, V, Type) :-
    sub_term(L, Term), compound(L), L \= pos(_), L \= den(_), L \= cmp(_),
    L =.. [Fn|Args], Fn \== '-', Fn \== '.',
    nth1(I, Args, A), A == V,
    catch(le_flip:template_types(KM, Fn, Args, Pairs), _, fail),
    nth1(I, Pairs, _-Type0), Type0 \== any, !,
    Type = Type0.

		 /*******************************
		 *	      coverage		*
		 *******************************/

%!  covered_by(+KM, +Lits, -Names) is det.
%
%   The program's scenarios that meet the case: each states the case's facts
%   (for some individuals and values), none of the facts it denies, and its
%   values meet the case's comparisons.
covered_by(KM, Lits, Names) :-
    findall(N, ( catch(KM:scenario(N, _), _, fail),
                 scenario_meets(KM, N, Lits) ),
            Names0),
    sort(Names0, Names).

scenario_meets(KM, Name, Lits0) :-
    copy_term(Lits0, Lits, _),
    case_goal(Lits, Goal),
    le_kbs:createSession(KM, T),
    setup_call_cleanup(
        le_kbs:setScenarion(T, Name),
        catch(( reasoner:with_saved_reasoner_state(le_cases:
                    once(( reasoner:solve(Goal, T, KM, [], 0, none, Us, _), Us == [] ))) ),
              _, fail),
        le_kbs:destroySession(T)).

case_goal(Lits, Goal) :-
    partition(is_den, Lits, Negs, Others),
    maplist(lit_goal, Others, Gs0),
    maplist(lit_goal, Negs, Gs1),
    append(Gs0, Gs1, Gs),
    list_to_conj(Gs, Goal).

is_den(den(_)).

lit_goal(pos(G), G).
lit_goal(den(G), not(G)).
lit_goal(cmp(G), G).
lit_goal(def(G), G).
lit_goal(cond(G), G).

%   A denied proof as the goal it stands for.
assumptions_goal(S, G) :-
    maplist(assumption_goal, S, Gs),
    list_to_conj(Gs, G).

assumption_goal('$le_cmp'(C), C) :- !.
assumption_goal('$le_def'(C), C) :- !.
assumption_goal('$le_cond'(C), C) :- !.
assumption_goal('$le_denied'(G, _), not(G)) :- !.
assumption_goal('$le_denied_goal'(G), not(G)) :- !.
assumption_goal('$le_eq'(A, B), A = B) :- !.
assumption_goal(G, G).

list_to_disj([G], G) :- !.
list_to_disj([G|Gs], (G ; D)) :- list_to_disj(Gs, D).

list_to_conj([], true).
list_to_conj([G], G) :- !.
list_to_conj([G|Gs], (G, C)) :- list_to_conj(Gs, C).

		 /*******************************
		 *	     explanations		*
		 *******************************/

proof_for_display(Whys0, T, Proof) :-
    (   catch(le_kbs:postprocess_why(Whys0, T, Proof0), _, fail)
    ->  mark_assumed(Proof0, Proof)
    ;   Proof = []
    ).

mark_assumed(L, Out) :- is_list(L), !, maplist(mark_assumed, L, Out).
mark_assumed(success(G, R, LE, Cs), success(G, R1, LE, Cs1)) :- !,
    ( blob(R, clause) -> R1 = scenario_change ; R1 = R ),
    mark_assumed(Cs, Cs1).
mark_assumed(failure(G, R, LE, Cs), failure(G, R, LE, Cs1)) :- !,
    mark_assumed(Cs, Cs1).
mark_assumed(repeated_group(N, W), repeated_group(N, W1)) :- !, mark_assumed(W, W1).
mark_assumed(X, X).

		 /*******************************
		 *	      rendering		*
		 *******************************/

%!  case_words(+KM, +Case, -Words) is det.
%
%   The answer as it reads: "case 2 of 4: a person is born in the UK on a date
%   and …; covered by scenario alice" — or "…; no scenario covers it", or, for
%   `is there a case in which …` with no case, that there is none and whether
%   the search was complete.
case_words(KM, case(I, Count, Lits, _W, Covered, Notes), Words) :- !,
    general_text(KM, Lits, Text0),
    ( Text0 == '' -> le_msg(cases_no_condition, [], Text) ; Text = Text0 ),
    (   Covered == []
    ->  le_msg(cases_not_covered, [], CovText)
    ;   atomic_list_concat(Covered, ', ', Names),
        le_msg(cases_covered_by, [scenarios-Names], CovText)
    ),
    notes_text(Notes, NotesText),
    le_msg(cases_case, [index-I, count-Count, conditions-Text, coverage-CovText], A0),
    ( NotesText == '' -> A = A0 ; atomic_list_concat([A0, ' ', NotesText], A) ),
    atom_words_list(A, Words).
case_words(_KM, no_case(Complete, Notes), Words) :- !,
    (   Complete == true
    ->  le_msg(cases_none_complete, [], A0)
    ;   le_msg(cases_none_searched, [], A0)
    ),
    notes_text(Notes, NotesText),
    ( NotesText == '' -> A = A0 ; atomic_list_concat([A0, ' ', NotesText], A) ),
    atom_words_list(A, Words).

atom_words_list(A, Words) :-
    atomic_list_concat(Ws0, ' ', A),
    exclude(==(''), Ws0, Words).

notes_text([], '') :- !.
notes_text(Notes, Text) :-
    maplist(note_text, Notes, Ts),
    atomic_list_concat(Ts, '; ', Joined),
    le_msg(cases_notes, [notes-Joined], Text).

note_text(aggregate, T) :- !, le_msg(cases_note_aggregate, [], T).
note_text(count_assumed, T) :- !, le_msg(cases_note_count_assumed, [], T).
note_text(for_all_cases, T) :- !, le_msg(cases_note_forall, [], T).
note_text(kept_as_stated, T) :- !, le_msg(cases_note_kept, [], T).
note_text(case_limit(N), T) :- !, le_msg(cases_note_case_limit, [max-N], T).
note_text(negation_limit(N), T) :- !, le_msg(cases_note_negation_limit, [max-N], T).
note_text(time_limit(N), T) :- !, le_msg(cases_note_time_limit, [seconds-N], T).
note_text(N, T) :- term_string(N, T).

%   The case in general terms: each literal as its template reads, an open
%   place as "a person" the first time and "the person" after, a second
%   open place of the same type as "an other person", a third as "a third
%   person".
general_text(KM, Lits0, Text) :-
    retractall(place_seen(_)),
    copy_term(Lits0, Lits, _),
    term_variables(Lits, Vs),
    name_places(KM, Lits, Vs, Names),
    maplist(literal_text(KM, Names), Lits, Texts0),
    exclude(==(''), Texts0, Texts),
    le_i18n:kw_main_words(and, AndW), atomic_list_concat(AndW, ' ', And),
    atomic_list_concat([' ', And, ' '], Sep),
    atomic_list_concat(Texts, Sep, Text),
    retractall(place_seen(_)).

:- thread_local place_seen/1.

%   Each open place: its type, and its ordinal among the places of that type.
name_places(KM, Lits, Vs, Names) :-
    retractall(individual_count(_, _)),
    maplist(name_place(KM, Lits), Vs, Names).

name_place(KM, Lits, V, V-place(Type, N)) :-
    ( var_type(KM, Lits, V, Type) -> true ; Type = thing ),
    ( retract(individual_count(Type, N0)) -> true ; N0 = 0 ),
    N is N0 + 1, assertz(individual_count(Type, N)).

literal_text(KM, Names, L, Text) :-
    (   L = def(_) -> Text = ''                 % a definition reads in its comparison
    ;   lit_goal(L, '$le_eq'(_, _)) -> Text = ''  % a binding, not a sentence
    ;   lit_goal(L, G0),
        bind_places(Names, G0, G),
        goal_text(KM, G, S),
        replace_place_marks(S, Names, Text)
    ).

%!  goal_text(+KM, +Goal, -Text) is det.
%
%   Goal as its template reads, each place filled with its value, a sentence
%   at a place of type sentence read in turn ("an other person says that a
%   third person is the father of the person").
goal_text(KM, le_at(G, _, _), Text) :- !,
    goal_text(KM, G, Text).
goal_text(KM, (A, B), Text) :- !,
    goal_text(KM, A, TA), goal_text(KM, B, TB),
    le_i18n:kw_main_words(and, AW), atomic_list_concat(AW, ' ', And),
    atomic_list_concat([TA, And, TB], ' ', Text).
goal_text(KM, (A ; B), Text) :- !,
    goal_text(KM, A, TA), goal_text(KM, B, TB),
    le_i18n:kw_main_words(or, OW), atomic_list_concat(OW, ' ', Or),
    atomic_list_concat([TA, Or, TB], ' ', Text).
goal_text(KM, not(G), Text) :- !,
    goal_text(KM, G, T0),
    le_i18n:kw_main_words(not_the_case, NW), atomic_list_concat(NW, ' ', Not),
    atomic_list_concat([Not, T0], ' ', Text).
goal_text(KM, G, Text) :-
    compound(G), G =.. [Fn|Args],
    template_words(KM, Fn, Args, Words), !,
    maplist(word_text(KM), Words, Ts),
    atomic_list_concat(Ts, ' ', Text).
goal_text(KM, G, Text) :-
    (   catch(le_kbs:item_to_instance(KM, G, Toks), _, fail)
    ->  le_kbs:canonical_string(Toks, S), atom_string(Text, S)
    ;   term_to_atom(G, Text)
    ).

word_text(KM, W, T) :-
    (   var(W) -> T = '_'
    ;   rational(W), \+ integer(W)
    ->  F is float(W), format(atom(T), '~w', [F])
    ;   string(W)
    ->  format(atom(T), '"~w"', [W])
    ;   compound(W), W \= date(_, _, _), \+ is_list(W), functor(W, F, _), \+ arith(F)
    ->  goal_text(KM, W, T)
    ;   W = date(Y, M, D)
    ->  format(atom(T), '~d-~|~`0t~d~2+-~|~`0t~d~2+', [Y, M, D])
    ;   is_list(W) -> term_to_atom(W, T)
    ;   compound(W) -> term_to_atom(W, T)
    ;   atomic(W) -> T = W
    ).

arith(F) :- memberchk(F, [+, -, *, /, //, mod, min, max, abs, round, floor, ceiling, truncate]).

%   The words of the template of Fn/N with its places bound to Args: the
%   program's own template, or a built-in one whose place types fit Args
%   (`is after` for dates, `is greater than` for numbers).
template_words(KM, Fn, Args, Words) :-
    length(Args, N), length(Vs, N),
    findall(Vs-Ts-Ws,
            ( ( KM:le_dict(dict([Fn|Vs], Ts, Ws, _, _, _, _))
              ; KM:le_dict(dict([Fn|Vs], Ts, Ws, _))
              ; KM:le_dict(dict([Fn|Vs], Ts, Ws)) ) ),
            Cands),
    Cands \== [],
    (   member(Vs1-Ts1-Ws1, Cands), types_fit(Ts1, Args)
    ->  true
    ;   Cands = [Vs1-_-Ws1|_]
    ),
    copy_term(Vs1-Ws1, Args-Words).

types_fit(Ts, Args) :-
    maplist(type_fits, Ts, Args).

type_fits(_-date, A) :- !, date_like(A).
type_fits(_-number, A) :- !, \+ date_like(A).
type_fits(_, _).

date_like(V) :- var(V), !, fail.
date_like(date(_, _, _)) :- !.
date_like(A) :- atom(A), ( le_date_atom(A, _) ; sub_atom(A, 0, _, _, '§date§') ), !.

%   Each open place is bound to a mark that survives rendering; the marks are
%   then replaced by "a person" / "the person" in reading order.
bind_places(Names, G0, G) :-
    copy_term(G0, G),
    term_variables(G0, V0s), term_variables(G, Vs),
    maplist(bind_place(Names), V0s, Vs).

bind_place(Names, V0, V) :-
    (   member(W-place(T, N), Names), W == V0
    ->  format(atom(V), '§~w§~d§', [T, N])
    ;   V = '§thing§1§'
    ).

replace_place_marks(S, _Names, Text) :-
    atom_string(A, S),
    replace_marks(A, Text).

replace_marks(A, Text) :-
    (   sub_atom(A, B, _, _, '§'),
        sub_atom(A, B, _, 0, Rest), sub_atom(Rest, 1, _, 0, R1),
        sub_atom(R1, B1, _, _, '§'), sub_atom(R1, 0, B1, _, Type),
        B2 is B1 + 1, sub_atom(R1, B2, _, 0, R2),
        sub_atom(R2, B3, _, _, '§'), sub_atom(R2, 0, B3, _, NA),
        B4 is B3 + 1, sub_atom(R2, B4, _, 0, After)
    ->  sub_atom(A, 0, B, _, Before),
        atom_number(NA, N),
        place_phrase(Type, N, Phrase),
        replace_marks(After, AfterText),
        atomic_list_concat([Before, Phrase, AfterText], Text)
    ;   Text = A
    ).

place_phrase(Type, N, Phrase) :-
    (   place_seen(Type-N)
    ->  definite_phrase(Type, N, Phrase)
    ;   assertz(place_seen(Type-N)),
        indefinite_phrase(Type, N, Phrase)
    ).

indefinite_phrase(Type, 1, P) :- !, le_i18n:indefinite_isa_words(Type, [_|Art]), atomic_list_concat(Art, ' ', A), atomic_list_concat([A, Type], ' ', P0), strip_is(P0, P).
indefinite_phrase(Type, 2, P) :- !, le_msg(cases_place_other, [type-Type], P).
indefinite_phrase(Type, N, P) :- ordinal(N, O), le_msg(cases_place_nth, [type-Type, n-O], P).

definite_phrase(Type, 1, P) :- !, le_msg(cases_place_the, [type-Type], P).
definite_phrase(Type, 2, P) :- !, le_msg(cases_place_the_other, [type-Type], P).
definite_phrase(Type, N, P) :- ordinal(N, O), le_msg(cases_place_the_nth, [type-Type, n-O], P).

ordinal(N, O) :-
    (   N =< 9, atom_concat(cases_ordinal_, N, Id), le_msg(Id, [], O0), \+ sub_atom(O0, 0, _, _, 'missing message')
    ->  O = O0
    ;   format(atom(O), '~d.', [N])
    ).

strip_is(P0, P) :- atom_string(P0, S), normalize_space(atom(P), S).

		 /*******************************
		 *	   the ready scenario	*
		 *******************************/

%!  case_json(+KM, +Case, -JSON) is det.
%
%   What the editor needs beside the answer's words: the case's conditions
%   one by one, the scenarios that cover it, and a ready-made scenario that
%   meets it (`scenario`, the text to add to the document).
case_json(KM, case(I, Count, Lits, w(WLits, _), Covered, Notes), JSON) :- !,
    maplist(note_string, Notes, NoteStrings),
    scenario_text(KM, I, WLits, Text),
    general_text(KM, Lits, General),
    JSON = _{index: I, count: Count, conditions: General, coveredBy: Covered,
             scenario: Text, notes: NoteStrings}.
case_json(_KM, no_case(Complete, Notes), _{none: true, complete: Complete, notes: NoteStrings}) :- !,
    maplist(note_string, Notes, NoteStrings).

note_string(N, S) :- note_text(N, T), atom_string(T, S).

%   A scenario named `case_<i>`: each fact of the witness as its template
%   reads, and each ground denial of an assumable template as "it is not the
%   case that …" (an unstated fact of an ordinary template is already false).
scenario_text(KM, I, WLits, Text) :-
    le_msg(cases_scenario_name, [index-I], Name),
    findall(Line,
            ( member(L, WLits),
              (   L = pos(G), ground(G), G \= is_a(_, _)
              ->  fact_line(KM, G, Line)
              ;   L = pos(is_a(X, T)), ground(X), atom(T)
              ->  fact_line(KM, is_a(X, T), Line)
              ;   L = den(G0), strip_at(G0, G), ground(G), fact_assumption(G), assumable(KM, G)
              ->  fact_line(KM, G, F),
                  le_i18n:kw_main_words(not_the_case, NW), atomic_list_concat(NW, ' ', Not),
                  format(string(Line), "~w ~w", [Not, F])
              ) ),
            Lines),
    le_i18n:kw_main_words(scenario, SW), atomic_list_concat(SW, ' ', Scen),
    le_i18n:kw_main_words(marker_is, IW), atomic_list_concat(IW, ' ', Is),
    format(string(Head), "~w ~w ~w:", [Scen, Name, Is]),
    maplist([L0, L1]>>format(string(L1), "    ~w.", [L0]), Lines, Body),
    atomic_list_concat([Head|Body], '\n', Text0),
    atom_string(Text0, Text).

strip_at(le_at(G0, _, _), G) :- !, strip_at(G0, G).
strip_at(G, G).

fact_line(KM, G, S) :-
    goal_text(KM, G, A), atom_string(A, S).

assumable(KM, G) :-
    current_predicate(KM:le_unknown/1),
    catch(clause(KM:le_unknown(G), _), _, fail), !.

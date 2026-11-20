/** <module> Why not: the unmet conditions of a failed query

    A failed query's explanation (reasoner.pl, build_failure_tree/2, with
    detailed failures: one node per rule attempted) says everything that was
    tried. What a reader wants of it is shorter: the conditions the case did not
    meet, each with the rule that asked for it and the facts that rule compared
    — "not met: 223 is less than or equal to 183 (rule pmd_pa_delivery, LCD
    L33789: "the delivery must be within 6 months following the
    determination"), given that prior authorization was affirmed on 2026-03-01
    and the item was delivered on 2026-10-10".

    unmet_conditions/4 walks the (post-processed) failure tree:

    - where a goal was attempted by several rules, only the attempts that came
      CLOSEST are followed — those in which the most conditions held before the
      one that failed (le_kbs:rule_progress/4 counts them). An alternative that
      failed at its first test (another policy's code list, another group's
      criteria) is not a reason; the alternatives that got equally far are all
      reasons, since meeting any of them would do;
    - a failed condition proved by rules is followed into them; one that is not
      is a LEAF, and each leaf is one unmet condition:
        * `not_stated` — a fact the case could state (a scenario-element or
          judged template, le_flip:changeable/2) that it does not state: the
          record is silent;
        * `not_met` — a comparison or other test that is false on the case's
          values, a negation whose subject holds, a fact the case states
          otherwise (same template, same subject, another value), a judgment
          recorded with another outcome, or a goal no rule concludes.

    Each unmet condition carries the rule whose body holds it (the innermost
    rule of the program at its source position), that rule's provenance, and
    the conditions of that rule that held on the way (the facts compared).
    Nothing here knows any domain.
*/

:- module(le_why_not, [
    unmet_conditions/4,     % +SM, +KB, +Why, -Items:list(dict)
    unmet_json/4            % +SM, +KB, +Why, -JSON:list(dict)
]).

:- use_module(library(apply)).
:- use_module(library(lists)).
:- use_module(le_verifier, [find_in_body/2]).

%!  unmet_conditions(+SM, +KB, +Why, -Items) is det.
%
%   Items: unmet(Kind, Goal, LE, Range, Facts) in the order of the
%   explanation, without duplicates. Facts are the LE strings of the
%   conditions that held beside it.
unmet_conditions(SM, KB, Why, Items) :-
    ( is_list(Why) -> Roots = Why ; Roots = [Why] ),
    b_setval(le_why_not_held, []),
    findall(I, ( member(R, Roots), unmet_node(SM, KB, R, [], I) ), Items0),
    dedup_items(Items0, Items).

unmet_node(SM, KB, repeated_group(_, W), Ctx, I) :- !,
    unmet_node(SM, KB, W, Ctx, I).
unmet_node(_, _, failure(le_section_checklist(_), _, _, _), _, _) :- !, fail.
unmet_node(_, _, failure(le_type_check(_, _), _, _, _), _, _) :- !, fail.
unmet_node(SM, KB, failure(rule_attempt(Ref, _, _), _, _, Cs), _, I) :- !,
    held(Cs, Facts),
    ( nb_current(le_why_not_expected, Exp) -> true ; Exp = none ),
    b_setval(le_why_not_expected, none),
    % the conditions that held here and in the rules above (backtrackable)
    ( nb_current(le_why_not_held, Above), is_list(Above) -> true ; Above = [] ),
    findall(HG, ( member(C0, Cs), unwrap(C0, success(HG0, _, _, _)), strip_at(HG0, HG) ), Here),
    append(Here, Above, Held),
    b_setval(le_why_not_held, Held),
    failed_children(Cs, Fs),
    member(F, Fs),
    (   follow_expected(SM, KB, F, Held, Items)
    ->  member(I, Items)
    ;   follow_held(SM, KB, F, Held, Items)
    ->  member(I, Items)
    ;   Exp = value(Out),
        follow_rule_table(SM, KB, Ref, Out, F, Items)
    ->  member(I, Items)
    ;   absent_aggregate(KB, F, Cs, Facts, Items)
    ->  member(I, Items)
    ;   unmet_node(SM, KB, F, Facts, I)
    ).
unmet_node(SM, KB, failure(G, R, LE, Cs), Ctx, I) :-
    rule_attempts(Cs, Attempts0),
    (   Attempts0 \== []
    ->  % the value asked for, when the question names one: only the rules
        % that can give it are routes to it (FactsBackground.md §5.3)
        strip_at(G, G1),
        (   compound(G1), G1 =.. [_|GArgs], last(GArgs, Out), ground(Out)
        ->  b_setval(le_why_not_expected, value(Out)),
            include(can_give(KB, Out), Attempts0, Attempts1),
            ( Attempts1 == [] -> Attempts = Attempts0 ; Attempts = Attempts1 )
        ;   b_setval(le_why_not_expected, none),
            Attempts = Attempts0
        ),
        closest(Attempts, Kept),
        member(A, Kept),
        unmet_node(SM, KB, A, Ctx, I)
    ;   failed_children(Cs, Fs),
        (   Fs \== []
        ->  held(Cs, Facts),                % the facts of the rule that asks
            ( nb_current(le_why_not_held, Above), is_list(Above) -> true ; Above = [] ),
            findall(HG, ( member(C0, Cs), unwrap(C0, success(HG0, _, _, _)), strip_at(HG0, HG) ), Here),
            append(Here, Above, Held),
            b_setval(le_why_not_held, Held),
            member(F, Fs),
            (   follow_expected(SM, KB, F, Held, Items)
            ->  member(I, Items)
            ;   follow_held(SM, KB, F, Held, Items)
            ->  member(I, Items)
            ;   strip_at(G, G2), compound(G2), G2 =.. [_|G2Args],
                last(G2Args, Out), ground(Out),
                rule_ref_at(KB, R, Ref),
                follow_rule_table(SM, KB, Ref, Out, F, Items)
            ->  member(I, Items)
            ;   absent_aggregate(KB, F, Cs, Facts, Items)
            ->  member(I, Items)
            ;   unmet_node(SM, KB, F, Facts, I)
            )
        ;   leaf_kind(SM, KB, G, Cs, Kind, Extra),
            append(Ctx, Extra, Facts),
            table_words(KB, G, LE, LE1),
            I = unmet(Kind, G, LE1, R, Facts)
        )
    ).

% ---------------------------------------------------------------------------
% Following the expected value (FactsBackground.md §5.3)
% ---------------------------------------------------------------------------
% "Why is the subheading not 6109.10?" The closest route is the one the case
% took (heading 6110), and it fails at the row of the subheading table: a
% reason that says nothing. The expected value names the rows of the table
% that give it; a value that such a row needs and the case does not have
% (heading 6109 where the case has 6110) was given by a condition that held
% on the way ("the heading of item 110 is 6110"). The question is then asked
% of that condition, with the row's value: why is the heading not 6109? Its
% unmet conditions are the reasons. Two levels at most.

follow_expected(SM, KB, failure(G0, _, _, _), Held, Items) :-
    strip_at(G0, G),
    G = le_table(Name, Args),
    ( nb_current(le_why_not_follow, D0), integer(D0) -> D = D0 ; D = 0 ),
    D < 2,
    last(Args, Out), ground(Out),
    current_predicate(KB:le_table_row/6),
    findall(Q, ( KB:le_table_row(Name, _, _, Cells, _, _),
                 last(Cells, OutCell), cell_gives(OutCell, Out),
                 row_questions(Cells, Args, Held, Qs), Qs \== [],
                 member(Q, Qs) ), Qs0),
    list_to_set(Qs0, Questions),
    Questions \== [],
    D1 is D + 1,
    setup_call_cleanup(
        ( nb_setval(le_why_not_follow, D1), b_setval(le_why_not_held, []) ),
        findall(I, ( member(Q, Questions),
                     \+ catch(once(le_kbs:query(SM, Q, _, [], _)), _, fail),
                     catch(le_kbs:query_explain(SM, Q, _, _, Why), _, fail),
                     unmet_conditions(SM, KB, Why, Is),
                     member(I, Is) ),
                Items0),
        nb_setval(le_why_not_follow, D)),
    dedup_items(Items0, Items),
    Items \== [].

% A rule can give the value asked for: its conclusion is that value, or is
% looked up in a table with a row that gives it, or is computed otherwise.
can_give(KB, Out, failure(rule_attempt(Ref, _, _), _, _, _)) :-
    (   catch(clause(H0, B, Ref), _, fail)
    ->  strip_module(H0, _, H), H =.. [_|HArgs], last(HArgs, HO),
        (   var(HO)
        ->  (   rule_table(KB, B, HO, Name, _)
            ->  current_predicate(KB:le_table_row/6),
                KB:le_table_row(Name, _, _, Cells, _, _),
                last(Cells, OC), cell_gives(OC, Out), !
            ;   true
            )
        ;   same_value(HO, Out)
        )
    ;   true
    ).

% the table of a rule's conditions whose last column is the rule's conclusion
rule_table(KB, B, HO, Name, TArgs) :-
    current_predicate(KB:le_table/6),
    le_verifier:find_in_body(B, Lit0), strip_at(Lit0, Lit),
    compound(Lit), functor(Lit, TF, TA),
    KB:le_table(Name, _, TF/TA, _, _, _),
    Lit =.. [_|TArgs], last(TArgs, TO), TO == HO, !.

% The rule's table gives the value asked for in some rows; a condition before
% the table failed, whose value is a column of those rows (the heading of a
% garment, for its subheading). The question is asked of that condition with
% the row's value: why is the heading not 6204?
follow_rule_table(SM, KB, Ref, Out, failure(GF0, _, _, _), Items) :-
    ( nb_current(le_why_not_follow, D0), integer(D0) -> D = D0 ; D = 0 ),
    D < 2,
    catch(clause(H0, B, Ref), _, fail),
    strip_module(H0, _, H),
    H =.. [_|HArgs], last(HArgs, HO), var(HO),
    strip_at(GF0, GF), compound(GF), functor(GF, FF, FA),
    le_verifier:find_in_body(B, Lit0), strip_at(Lit0, Lit),
    compound(Lit), functor(Lit, FF, FA),
    Lit =.. [_|LArgs], last(LArgs, LV), var(LV), LV \== HO, !,
    findall(V, needed_value(KB, B, HO, LV, Out, V), Vs0),
    sort(Vs0, Vs), Vs \== [],
    GF =.. [_|GArgs], append(Front, [_], GArgs), ground(Front),
    findall(Q, ( member(V, Vs), append(Front, [V], QArgs), Q =.. [FF|QArgs] ), Qs),
    D1 is D + 1,
    setup_call_cleanup(
        ( nb_setval(le_why_not_follow, D1), b_setval(le_why_not_held, []) ),
        findall(I, ( member(Q, Qs),
                     \+ catch(once(le_kbs:query(SM, Q, _, [], _)), _, fail),
                     catch(le_kbs:query_explain(SM, Q, _, _, Why), _, fail),
                     unmet_conditions(SM, KB, Why, Is),
                     member(I, Is) ),
                Items0),
        nb_setval(le_why_not_follow, D)),
    dedup_items(Items0, Items),
    Items \== [].

%   needed_value(+KB, +Body, +HO, +LV, +Out, -V): a value of the variable LV
%   with which the rule's conclusion HO can be Out: LV is a column of the
%   rule's table, in a row that gives Out; or LV is passed to the condition
%   that concludes HO, and a rule of that condition gives Out with LV = V (in
%   its own table, or in its conclusion).
needed_value(KB, B, HO, LV, Out, V) :-
    rule_table(KB, B, HO, Name, TArgs),
    nth1(K, TArgs, TV), TV == LV,
    KB:le_table_row(Name, _, _, Cells, _, _),
    last(Cells, OC), cell_gives(OC, Out),
    nth1(K, Cells, Cell), cell_value(Cell, V).
needed_value(KB, B, HO, LV, Out, V) :-
    le_verifier:find_in_body(B, L0), strip_at(L0, L2),
    compound(L2), L2 =.. [F2|A2], last(A2, O2), O2 == HO,
    nth1(P, A2, X), X == LV,
    length(A2, N2), functor(H2, F2, N2),
    current_predicate(KB:F2/N2),
    catch(clause(KB:H2, B2), _, fail),
    H2 =.. [_|HA2], last(HA2, HO2), nth1(P, HA2, VP),
    (   var(HO2), var(VP)
    ->  rule_table(KB, B2, HO2, Name, TArgs),
        nth1(K, TArgs, TV), TV == VP,
        KB:le_table_row(Name, _, _, Cells, _, _),
        last(Cells, OC), cell_gives(OC, Out),
        nth1(K, Cells, Cell), cell_value(Cell, V)
    ;   nonvar(HO2), same_value(HO2, Out), nonvar(VP)
    ->  V = VP
    ).

% the clause of the rule at a range of the program
rule_ref_at(KB, range(S, E), Ref) :-
    integer(S),
    catch(KB:le_source_info(Ref, S, E, _), _, fail),
    catch(clause(_, B, Ref), _, fail), B \== true, !.

% A condition that failed with its value asked for (the subheading of the
% good in heading 6110 is 6211.32) where an argument that a condition above
% gave (heading 6110) is not one with which a rule of that condition gives
% the value: the question goes to that condition, with the value the rule
% needs (why is the heading not 6211?).
follow_held(SM, KB, failure(GF0, _, _, _), Held, Items) :-
    ( nb_current(le_why_not_follow, D0), integer(D0) -> D = D0 ; D = 0 ),
    D < 2,
    strip_at(GF0, GF), compound(GF), GF \= le_table(_, _),
    GF =.. [F|GArgs], last(GArgs, Out), ground(GArgs),
    length(GArgs, N), functor(H2, F, N),
    current_predicate(KB:F/N),
    findall(P-V, ( catch(clause(KB:H2, B2), _, fail),
                   H2 =.. [_|HA2], last(HA2, HO2),
                   nth1(P, HA2, VP), P < N,
                   (   var(HO2), var(VP)
                   ->  rule_table(KB, B2, HO2, Name, TArgs),
                       nth1(K, TArgs, TV), TV == VP,
                       KB:le_table_row(Name, _, _, Cells, _, _),
                       last(Cells, OC), cell_gives(OC, Out),
                       nth1(K, Cells, Cell), cell_value(Cell, V)
                   ;   nonvar(HO2), same_value(HO2, Out), nonvar(VP)
                   ->  V = VP
                   ),
                   nth1(P, GArgs, Cur), \+ same_value(Cur, V) ), PVs0),
    sort(PVs0, PVs), PVs \== [],
    findall(Q, ( member(P-V, PVs), nth1(P, GArgs, Cur),
                 member(HG, Held), compound(HG), HG \= le_table(_, _),
                 HG =.. [HF|HArgs], last(HArgs, Last), same_value(Last, Cur),
                 append(Front, [_], HArgs), ground(Front),
                 append(Front, [V], QArgs), Q =.. [HF|QArgs] ), Qs0),
    list_to_set(Qs0, Qs), Qs \== [],
    D1 is D + 1,
    setup_call_cleanup(
        ( nb_setval(le_why_not_follow, D1), b_setval(le_why_not_held, []) ),
        findall(I, ( member(Q, Qs),
                     \+ catch(once(le_kbs:query(SM, Q, _, [], _)), _, fail),
                     catch(le_kbs:query_explain(SM, Q, _, _, Why), _, fail),
                     unmet_conditions(SM, KB, Why, Is),
                     member(I, Is) ),
                Items0),
        nb_setval(le_why_not_follow, D)),
    dedup_items(Items0, Items),
    Items \== [].

strip_at(le_at(G0, _, _), G) :- !, strip_at(G0, G).
strip_at(G, G).

cell_gives(val(V), Out) :- same_value(V, Out).
cell_gives(oneof(Vs), Out) :- member(V, Vs), same_value(V, Out), !.

same_value(A, B) :- A == B, !.
same_value(A, B) :- atomic(A), atomic(B), atom_string(A, SA), atom_string(B, SB), SA == SB.

% the conditions that held, with the row's value in place of the case's: a
% value of the row that the case does not have, and that a held condition
% gave as its last argument
row_questions(Cells, Args, Held, Qs) :-
    append(InCells, [_], Cells), append(InArgs, [_], Args),
    findall(Cur-V, ( nth1(K, InCells, Cell), nth1(K, InArgs, Cur),
                     \+ cell_accepts(Cell, Cur),
                     cell_value(Cell, V) ), Bads),
    Bads \== [],
    findall(Q, ( member(Cur-V, Bads),
                 member(HG, Held), compound(HG),
                 HG =.. [F|HArgs], last(HArgs, Last), same_value(Last, Cur),
                 append(Front, [_], HArgs), append(Front, [V], QArgs),
                 Q =.. [F|QArgs] ), Qs0),
    % every value that differs must come from a condition, or the row is out of reach
    length(Bads, NB), length(Qs0, NQ), NQ >= NB,
    Qs = Qs0.
row_questions(_, _, _, []).

cell_accepts(any, _) :- !.
cell_accepts(val(V), X) :- !, same_value(V, X).
cell_accepts(oneof(Vs), X) :- !, member(V, Vs), same_value(V, X), !.
cell_accepts(test(_), _).           % a test on a value: not followed

cell_value(val(V), V).
cell_value(oneof([V|_]), V).

% ---------------------------------------------------------------------------
% A comparison after an aggregate over absent facts
% ---------------------------------------------------------------------------
% "0 is greater than 0": the share of a fibre is a sum over the facts that
% state each fibre's percentage, and the case states none. The leaf is the
% fact that is not stated, not the comparison that failed on its absence.

absent_aggregate(KB, failure(G0, R, _, _), Cs, Facts, Items) :-
    strip_at(G0, G),
    compound(G), functor(G, Cmp, 2),
    memberchk(Cmp, [le_gt, le_ge, le_lt, le_le, le_equal_to, le_not_equal_to, >, >=, <, =<]),
    findall(unmet(not_stated, Inner, LE, R, Facts),
            ( member(C0, Cs), unwrap(C0, S), sub_aggregate(S, Agg),
              Agg = success(_, _, _, ACs),
              member(AC0, ACs), unwrap(AC0, failure(Inner0, _, LE0, _)),
              strip_at(Inner0, Inner), callable(Inner),
              catch(le_flip:changeable(KB, Inner), _, fail),
              text(LE0, LE) ),
            Items0),
    dedup_items(Items0, Items),
    Items \== [].

sub_aggregate(success(G0, R, LE, Cs), success(G, R, LE, Cs)) :-
    strip_at(G0, G), compound(G), G =.. [Op, [each|_]|_],
    memberchk(Op, [sum, count, average, min, max, list]).
sub_aggregate(success(_, _, _, Cs), A) :-
    member(C0, Cs), unwrap(C0, S), S = success(_, _, _, _),
    sub_aggregate(S, A).

% ---------------------------------------------------------------------------
% A table row in the words of its table
% ---------------------------------------------------------------------------

table_words(KB, G0, LE0, LE) :-
    strip_at(G0, G),
    G = le_table(Name, Args),
    current_predicate(KB:le_table/6),
    KB:le_table(Name, _, HF/HA, _, _, _),
    length(Args, HA),
    Head =.. [HF|Args],
    catch(le_kbs:item_to_instance(KB, Head, Toks), _, fail),
    le_kbs:canonical_string(Toks, LE), !,
    ignore(LE0 = LE).
table_words(_, _, LE, LE).

rule_attempts(Cs, As) :-
    findall(A, ( member(C0, Cs), unwrap(C0, A), A = failure(rule_attempt(_, _, _), _, _, _) ), As).

% the attempts in which the most conditions held — and of those, the ones in
% which they were the largest part of the rule (a route that only begins to
% apply later, "the rental month is at least 4", ties by count with the route
% that applies now and failed on a criterion, but met less of itself)
closest(Attempts, Kept) :-
    findall(M-T, member(failure(rule_attempt(_, M, T), _, _, _), Attempts), MTs),
    pairs_keys(MTs, Ms), max_list(Ms, Max),
    findall(R, ( member(M-T, MTs), M =:= Max, share(M, T, R) ), Rs),
    max_list(Rs, MaxR),
    findall(A, ( member(A, Attempts), A = failure(rule_attempt(_, M, T), _, _, _),
                 M =:= Max, share(M, T, R), R =:= MaxR ), Kept).

share(_, 0, 0) :- !.
share(M, T, R) :- R is M / T.

failed_children(Cs, Fs) :-
    findall(F, ( member(C0, Cs), unwrap(C0, F), F = failure(_, _, _, _),
                 F \= failure(le_type_check(_, _), _, _, _) ), Fs).

% the conditions shown as having held (a choice point, with its binding)
held(Cs, Facts) :-
    findall(LE, ( member(C0, Cs), unwrap(C0, success(_, _, LE0, _)), text(LE0, LE) ), Facts).

unwrap(repeated_group(_, W), X) :- !, unwrap(W, X).
unwrap(X, X).

text(S, S) :- string(S), !.
text(A, S) :- atom(A), !, atom_string(A, S).
text(T, S) :- term_string(T, S).

%!  leaf_kind(+SM, +KB, +Goal, +Children, -Kind, -Extra) is det.
leaf_kind(SM, KB, G, Cs, Kind, Extra) :-
    (   % "it is not the case that X": X holds
        member(C0, Cs), unwrap(C0, success(_, _, LE0, _))
    ->  Kind = not_met, text(LE0, LE), Extra = [LE]
    ;   callable(G), catch(le_flip:changeable(KB, G), _, fail)
    ->  (   stated_otherwise(SM, KB, G, Other)
        ->  Kind = not_met, Extra = [Other]
        ;   Kind = not_stated, Extra = []
        )
    ;   Kind = not_met, Extra = []
    ).

% The case states the same template for the same question with another value
% (the last argument): "the type of the sleep test of Ben is home sleep test"
% where "... is facility polysomnogram" was asked for. For a judged template
% that is a recorded outcome ("unsupported" where "established" was needed).
stated_otherwise(SM, KB, G, LE) :-
    G =.. [F|Args],
    append(Question, [Last], Args), Question \== [],
    ground(Question), nonvar(Last),
    append(Question, [Other], Args1),
    G1 =.. [F|Args1],
    ( catch(clause(SM:G1, true), _, fail) ; catch(clause(KB:G1, true), _, fail) ),
    Other \== Last, !,
    (   catch(le_kbs:item_to_instance(KB, G1, Toks), _, fail)
    ->  le_kbs:canonical_string(Toks, LE)
    ;   term_string(G1, LE)
    ).

% one item per condition, as it reads (the first rule that asks for it)
dedup_items([], []).
dedup_items([I|Is], [I|Out]) :-
    I = unmet(_, _, LE, _, _),
    exclude(same_literal(LE), Is, Is1),
    dedup_items(Is1, Out).

same_literal(LE, unmet(_, _, LE2, _, _)) :- LE2 == LE.

% ---------------------------------------------------------------------------
% As the client reads them
% ---------------------------------------------------------------------------

%!  unmet_json(+SM, +KB, +Why, -JSON) is det.
%
%   Each unmet condition as {literal, kind, facts, rule?, provenance?, plain?,
%   label?, goal?, values?}: the rule of the program that asks for it (its
%   name when the author named it) and its provenance; for a fact the case
%   could state, the template's label, the goal as a fact to state, and the
%   values the rules read at each placeholder (as openQuestions gives them).
unmet_json(SM, KB, Why, JSON) :-
    unmet_conditions(SM, KB, Why, Items),
    maplist(item_json(KB), Items, JSON).

item_json(KB, unmet(Kind, G, LE0, R, Facts), J) :-
    text(LE0, LE1),
    rejoin_hyphens(LE1, LE),
    maplist(rejoin_hyphens, Facts, Facts1),
    J0 = _{literal: LE, kind: Kind, facts: Facts1},
    (   rule_at(KB, R, ID, S, E)
    ->  % the rule's name only when its author named it (not "rule_944")
        (   le_kbs:user_rule_name(ID)
        ->  J1 = J0.put(_{rule: ID, ruleStart: S, ruleEnd: E})
        ;   J1 = J0.put(_{ruleStart: S, ruleEnd: E})
        ),
        (   catch(le_provenance:rule_provenance(KB, ID, Prov), _, fail)
        ->  le_provenance:provenance_dict(none, KB, Prov, P),
            J2 = J1.put(provenance, P)
        ;   J2 = J1
        )
    ;   J2 = J0
    ),
    (   Kind == not_stated, callable(G),
        functor(G, F, A),
        catch(le_kbs:template_def(KB, F, A, Label, _, Values), _, fail)
    ->  (   catch(le_kbs:item_to_instance(KB, G, Tokens), _, fail)
        ->  copy_term(Tokens, T1), numbervars(T1, 0, _), le_kbs:goal_string(T1, GoalStr0),
            rejoin_hyphens(GoalStr0, GoalStr)
        ;   GoalStr = LE
        ),
        J = J2.put(_{label: Label, goal: GoalStr, values: Values})
    ;   J = J2
    ).

% The innermost rule of the program whose text holds the condition at range R
% (a named rule's name, or the rule's generated id).
rule_at(KB, range(P, _), ID, S, E) :-
    integer(P),
    findall(Len-(ID0-S0-E0),
            ( catch(KB:le_source_info(Ref, S0, E0, ID0), _, fail),
              integer(S0), integer(E0), S0 =< P, P =< E0,
              \+ catch(clause(_, true, Ref), _, fail),     % a rule, not a fact
              Len is E0 - S0 ),
            Hits),
    Hits \== [],
    keysort(Hits, [_-(ID-S-E)|_]).

% a hyphenated word renders tokenised ("full - time"): as written ("full-time")
rejoin_hyphens(S0, S) :-
    atomic_list_concat(Parts, ' - ', S0), atomic_list_concat(Parts, '-', A), atom_string(A, S).

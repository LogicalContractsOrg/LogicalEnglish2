/** <module> The oracle of the LegalRuleML twins: SPINdle on the source

    A LegalRuleML document has no engine of its own and ships no tests
    (the design notes roadmap.md §5.8). What its authors reason with is
    defeasible deontic logic, and SPINdle (Lam & Governatori, NICTA/Data61,
    LGPL; oracle/fetch_spindle.sh) is their reasoner: this module grounds a
    document's statements over a scenario's facts, writes the theory in
    SPINdle's DFL, runs SPINdle, and reads back what is defeasibly proved
    (+d). The twin's expected answers are these conclusions — never the LE
    program's own.

    The reading of the document is the standard's, stated in DFL:

      - a Constitutive rule is a strict (->), defeasible (=>) or defeater
        (~>) rule, per its strength (a Context's appliesStrength wins);
      - Obligation(p) is [OBL] p, Prohibition(p) [OBL] ~p, Permission(p) and
        Right(p) [PER] p, the deontic literal carrying its bearer as its
        first argument (OBL and PER declared in conflict, so a permission
        attacks a prohibition of the same act);
      - a SuborderList (and a Penalty's) is a contrary-to-duty chain: each
        element is in force once the one before it is violated; an
        obligation is violated when its act is not the case, a prohibition
        when it is; a Reparation applies its penalty to the violation of its
        statement (and to the conditions of the rule that concludes the
        reparation, if one does);
      - Override over > under is superiority between the ground instances
        that agree on their shared variables; where the two conclusions do
        not conflict (17 USC 504's alternative penalties), the override is a
        defeater of the under rule's applicability instead, which is what
        the document means by it;
      - facts are the scenario's, and an atom of a relation no rule
        concludes that is not a fact is false (>> ~p): the closed world of
        the case; an atom a rule concludes is false by default (=> ~p,
        below the rules for it) where a condition needs it false;
      - a statement with temporal characteristics applies when the
        scenario's date is in its period; one of a set of Alternatives when
        the scenario adopts it.

    spindle_conclusions(+Model, +Scenario, -Conclusions)
        Scenario  = scenario(Name, Facts, Options): Facts lit(Iri, Values),
                    Options date(date(Y,M,D)), alternative(Key)
        Conclusions = [lit(Iri, Values) | neg(lit(Iri, Values))
                      | deontic(Kind, Bearer, Sentence)
                      | violated(Kind, Bearer, Sentence)]   (Kind obligation,
                      prohibition or permission; Sentence a lit/neg)
        or unavailable(Why).
*/

:- module(lrml_spindle, [
    spindle_conclusions/3,       % +Model, +Scenario, -Conclusions
    spindle_theory/3,            % +Model, +Scenario, -DFLText
    spindle_available/0
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(dcg/basics)).
:- use_module(lrml_reader).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).

spindle_jar(Jar) :-
    (   getenv('SPINDLE_JAR', Jar) -> true
    ;   here(D), atomic_list_concat([D, '/oracle/spindle/SPINdle_2.2.4/dist/spindle_2.2.4.jar'], Jar)
    ),
    exists_file(Jar).

spindle_available :- spindle_jar(_).

%!  spindle_conclusions(+Model, +Scenario, -Conclusions) is det.
spindle_conclusions(Model, Scenario, Conclusions) :-
    (   \+ spindle_jar(_)
    ->  Conclusions = unavailable("SPINdle is not installed (run oracle/fetch_spindle.sh)")
    ;   catch(( theory(Model, Scenario, Text, Names), run_spindle(Text, Lines),
                decode_lines(Lines, Names, Conclusions) ),
              E, ( message_to_string(E, S), Conclusions = unavailable(S) ))
    ).

%!  spindle_theory(+Model, +Scenario, -Text) is det.
spindle_theory(Model, Scenario, Text) :- theory(Model, Scenario, Text, _).

		 /*******************************
		 *           GROUNDING          *
		 *******************************/

theory(Model, scenario(_, Facts, Opts), Text, names(Rels, Consts)) :-
    Model = model(Is),
    nb_setval(lrml_const, []),
    nb_setval(lrml_rel_tokens, []),
    %  the relations rules conclude; the others are the case's facts
    findall(Iri, ( member(statement(_, _, _, rule(_, _, Then, _)), Is), head_rel(Then, Iri) ), Hs1),
    findall(Iri, ( member(penalty(_, Ds), Is), member(D, Ds), head_rel(D, Iri) ), Hs2),
    append(Hs1, Hs2, Hs0), sort(Hs0, Derived),
    findall(V, ( member(lit(_, Vs), Facts), member(V, Vs) ), FVs),
    findall(V, ( member(statement(_, _, _, R), Is), sub_term(A, R), ground_arg(A), arg_value(A, V) ), RVs),
    append(FVs, RVs, Dom0), sort(Dom0, Domain),
    %  the statements in force in the case, each as its ground instances
    findall(S-Rule, ( member(statement(S, _, _, Rule), Is), \+ scenario_statement(Model, S, _),
                      applies(Model, S, Opts) ), Stmts),
    foldl(statement_instances(Model, Facts, Derived, Domain), Stmts, []-1, Insts0-_),
    reverse(Insts0, Insts1),
    reparation_instances(Model, Opts, Facts, Derived, Domain, Insts1, Insts2),
    overrides(Model, Insts2, Insts, Sups),
    violation_rules(Insts, VRules),
    closed_world_defaults(Insts, VRules, Derived, Defaults, DSups),
    %  facts, and the closed world of the base relations
    findall(L, ( member(lit(Iri, Vs), Facts), L = l(none, pos, p(Iri), Vs) ), FactLits),
    findall(l(none, neg, p(Iri), Vs),
            ( ( member(inst(_, _, _, _, B, H), Insts), ( member(L0, B) ; L0 = H ) ; member(vr(_, B, _), VRules), member(L0, B) ),
              L0 = l(_, _, p(Iri), Vs), Iri \= ok(_), \+ memberchk(Iri, Derived), \+ memberchk(lit(Iri, Vs), Facts) ), CWA0),
    sort(CWA0, CWA),
    with_output_to(string(Text),
        ( format("OBL != PER~nPER != OBL~n~n"),
          forall(member(L, FactLits), ( write('>> '), write_lit(L), nl )),
          forall(member(L, CWA), ( write('>> '), write_lit(L), nl )),
          nl,
          %  (SPINdle refuses a theory of facts alone)
          format("r0: le_nothing => le_nothing_follows~n"),
          forall(member(inst(Lab, _, Type, _, B, H), Insts), write_rule(Lab, Type, B, H)),
          forall(member(vr(Lab, B, H), VRules), write_rule(Lab, strict, B, H)),
          forall(member(dflt(Lab, H), Defaults), write_rule(Lab, defeasible, [], H)),
          forall(member(O > U, Sups), format("~w > ~w~n", [O, U])),
          forall(member(O > U, DSups), format("~w > ~w~n", [O, U])) )),
    findall(Iri, ( member(statement(_, _, _, R), Is), sub_term(atom(rel(Iri, _), _), R) ), RIs0),
    findall(Iri, ( member(penalty(_, R), Is), sub_term(atom(rel(Iri, _), _), R) ), RIs1),
    findall(Iri, member(lit(Iri, _), Facts), RIs2),
    append([RIs0, RIs1, RIs2], RIs), sort(RIs, Rels),
    nb_getval(lrml_const, Consts).

ground_arg(A) :- nonvar(A), ( A = ind(_) ; A = data(_, _) ).

head_rel(atom(rel(Iri, _), _), Iri).
head_rel(neg(F), Iri) :- head_rel(F, Iri).
head_rel(and(Fs), Iri) :- member(F, Fs), head_rel(F, Iri).
head_rel(suborder(Fs), Iri) :- member(F, Fs), head_rel(F, Iri).

%   In force in the case: its period holds the scenario's date, and it is
%   the adopted one of its alternatives.
applies(Model, S, Opts) :-
    (   statement_period(Model, S, Start, End), memberchk(date(D), Opts)
    ->  ( Start == none -> true ; D @>= Start ), ( End == none -> true ; D @< End )
    ;   true
    ),
    (   statement_alternatives(Model, S, _, _) -> memberchk(alternative(S), Opts) ; true ).

%   inst(Label, Statement, Type, Binding, Body, Head): a ground rule.
statement_instances(Model, Facts, Derived, Domain, S-Rule, Acc0-N0, Acc-N) :-
    (   catch(statement_instances_(Model, Facts, Derived, Domain, S-Rule, Acc0-N0, Acc1-N1), error(format(_, _), _), fail)
    ->  Acc = Acc1, N = N1
    ;   Acc = Acc0, N = N0                % a statement with nothing SPINdle can state
    ).

statement_instances_(Model, Facts, Derived, Domain, S-rule(_, If, Then, _), Acc0-N0, Acc-N) :-
    statement_strength(Model, S, Type),
    heads(Model, Then, Heads),
    body_dnf(Model, If, Conjs),
    findall(B-(H-Extra), ( member(B, Conjs), member(H-Extra, Heads) ), Pairs0),
    sort(Pairs0, Pairs),
    foldl(ground_pair(S, Type, Facts, Derived, Domain), Pairs, Acc0-N0, Acc-N).

ground_pair(S, Type, Facts, Derived, Domain, Body0-(Head-Extra), Acc0-N0, Acc-N) :-
    append(Body0, Extra, Body),
    findall(inst(S, Type, Bind, GB, GH),
            ground_instance(Body, Head, Facts, Derived, Domain, Bind, GB, GH), Gs0),
    sort(Gs0, Gs),
    foldl(label_inst, Gs, Acc0-N0, Acc-N).

label_inst(inst(S, T, Bind, B, H), Acc-N0, [inst(Lab, S, T, Bind, B, H)|Acc]-N) :-
    camel_snake(S, SS), format(atom(Lab), 'r~w_~w', [N0, SS]), N is N0 + 1.

%   Heads of a rule's `then`: [Head-ExtraConditions]; a SuborderList is a
%   chain, each element once the one before is violated; a Reparation the
%   penalty's chain once its statement is violated.
heads(Model, Then, Heads) :-
    (   Then = suborder(Ds) -> chain(Ds, [], Heads)
    ;   Then = and(Fs) -> findall(H, ( member(F, Fs), heads(Model, F, Hs), member(H, Hs) ), Heads)
    ;   Then = reparation(RK) -> reparation_heads(Model, RK, Heads)
    ;   Then = deontic(_, _, true) -> Heads = []
    ;   head_lit(Then, H) -> Heads = [H-[]]
    ;   Heads = []
    ).

chain([], _, []).
chain([D0|Ds], Extra, Heads) :-
    (   D0 = and(Parts), select(D, Parts, Conds0), D = deontic(_, _, _) -> body_conj_simple(Conds0, Conds) ; D = D0, Conds = [] ),
    append(Extra, Conds, Extra1),
    (   head_lit(D, H) -> Heads = [H-Extra1|Hs] ; Heads = Hs ),
    (   D = deontic(K, _, _), K \== permission, K \== right, head_lit(D, H1)
    ->  violation_of(H1, V), chain(Ds, [V|Extra], Hs)
    ;   Hs = []
    ).

body_conj_simple(Fs, Ls) :- findall(L, ( member(F, Fs), body_lit(F, L) ), Ls).

reparation_heads(model(Is), RK, Heads) :-
    (   memberchk(reparation(RK, Pen, PS), Is), memberchk(penalty(Pen, Ds), Is),
        memberchk(statement(PS, _, _, rule(_, _, PThen, _)), Is),
        once(( sub_term(D0, PThen), nonvar(D0), D0 = deontic(K, _, _), K \== permission, head_lit(D0, H0) ))
    ->  violation_of(H0, V), chain(Ds, [V], Heads)
    ;   Heads = []
    ).

%   Reparations no rule concludes apply on the violation alone.
reparation_instances(Model, Opts, Facts, Derived, Domain, Insts0, Insts) :-
    Model = model(Is),
    findall(RK, ( member(reparation(RK, _, PS), Is), \+ ( member(statement(_, _, _, rule(_, _, T, _)), Is), sub_term(reparation(RK), T) ),
                  applies(Model, PS, Opts) ), RKs),
    length(Insts0, N0), N1 is N0 + 1,
    foldl({Model, Facts, Derived, Domain}/[RK, A0-M0, A-M]>>( reparation_heads(Model, RK, Hs),
                              findall([]-H, member(H, Hs), Pairs),
                              foldl(ground_pair(RK, defeasible, Facts, Derived, Domain), Pairs, A0-M0, A-M) ),
          RKs, []-N1, Rev-_),
    reverse(Rev, New), append(Insts0, New, Insts).

%   Abstract literals: l(Mode, Sign, Name, Args), Name p(Iri) (an atom),
%   o(SentenceName) (a deontic sentence, bearer first), v(Kind, SName) (a
%   violation, bearer first), c(SName) (a compliance).
head_lit(atom(rel(Iri, _), As), l(none, pos, p(Iri), As)) :- Iri \== none.
head_lit(neg(atom(rel(Iri, _), As)), l(none, neg, p(Iri), As)).
head_lit(deontic(K, B0, S), l(Mode, Sign, o(SN), [B|As])) :-
    S \== true,
    deontic_bearer(B0, S, B),
    sentence(S, SN, As),
    kind_mode(K, Mode, Sign).

kind_mode(obligation, 'OBL', pos).
kind_mode(prohibition, 'OBL', neg).
kind_mode(permission, 'PER', pos).
kind_mode(right, 'PER', pos).

sentence(atom(rel(Iri, _), As), s(pos, Iri), As).
sentence(neg(atom(rel(Iri, _), As)), s(neg, Iri), As).

%   The violation of a deontic literal, and the literal itself as a
%   condition: [OBL] p violated when p is not the case, [OBL] ~p when it is.
violation_of(l('OBL', Sign, o(SN), Args), l(none, pos, v(Kind, SN), Args)) :-
    ( Sign == pos -> Kind = obligation ; Kind = prohibition ).

violation_rules(Insts, VRules) :-
    findall(H, ( member(inst(_, _, _, _, _, H), Insts), H = l('OBL', _, _, _) ), Hs0),
    sort(Hs0, Hs),
    findall(vr(Lab, [H, Truth], V),
            ( nth1(I, Hs, H), violation_of(H, V), H = l(_, Sign, o(s(SS, Iri)), [_|As]),
              truth(Sign, SS, Iri, As, Truth), format(atom(Lab), 'v~w', [I]) ), VRules).

%   The closed world of the case for what rules conclude, too: an atom a
%   condition needs to be false is false by default (=> ~p), below every
%   rule that concludes it — so `not the case` means not established, as
%   it does for the facts.
closed_world_defaults(Insts, VRules, Derived, Defaults, Sups) :-
    findall(L, ( ( member(inst(_, _, _, _, B, _), Insts) ; member(vr(_, B, _), VRules) ),
                 member(L, B), L = l(none, neg, p(Iri), _), memberchk(Iri, Derived) ), Ls0),
    sort(Ls0, Ls),
    findall(dflt(Lab, L), ( nth1(I, Ls, L), format(atom(Lab), 'd~w', [I]) ), Defaults),
    findall(R > D, ( member(dflt(D, l(none, neg, N, Vs)), Defaults),
                     member(inst(R, _, _, _, _, l(none, pos, N, Vs)), Insts) ), Sups).

%   What makes it violated: the act (for a prohibition), its absence (for
%   an obligation).
truth(neg, SS, Iri, As, l(none, SS, p(Iri), As)).
truth(pos, SS, Iri, As, l(none, S1, p(Iri), As)) :- ( SS == pos -> S1 = neg ; S1 = pos ).

%   A condition in disjunctive normal form: [[Literal]].
body_dnf(_, true, [[]]) :- !.
body_dnf(M, and(Fs), Conjs) :- !,
    foldl({M}/[F, C0, C]>>( body_dnf(M, F, CF), findall(X, ( member(A, C0), member(B, CF), append(A, B, X) ), C) ), Fs, [[]], Conjs).
body_dnf(M, or(Fs), Conjs) :- !,
    findall(C, ( member(F, Fs), body_dnf(M, F, CF), member(C, CF) ), Conjs).
body_dnf(M, violation(S), Conjs) :- !,
    M = model(Is),
    findall([V], ( memberchk(statement(S, _, _, rule(_, _, T, _)), Is), heads(M, T, Hs),
                   member(H-_, Hs), H = l('OBL', _, _, _), violation_of(H, V) ), Conjs0),
    ( Conjs0 == [] -> Conjs = [[l(none, pos, p(violation(S)), [])]] ; Conjs = Conjs0 ).
body_dnf(M, compliance(S), Conjs) :- !,
    M = model(Is),
    findall([l(none, neg, v(K, SN), As)],
            ( memberchk(statement(S, _, _, rule(_, _, T, _)), Is), heads(M, T, Hs),
              member(H-_, Hs), H = l('OBL', _, _, _), violation_of(H, l(_, _, v(K, SN), As)) ), Conjs0),
    ( Conjs0 == [] -> Conjs = [[l(none, pos, p(compliance(S)), [])]] ; Conjs = Conjs0 ).
body_dnf(_, F, [[L]]) :- body_lit(F, L), !.
body_dnf(_, F, _) :- throw(error(format("a condition SPINdle cannot state: ~q", [F]), _)).

body_lit(F, L) :- head_lit(F, L).

%   The ground instances: the base atoms of the body are matched against
%   the facts first (an instance whose base atom is false never fires);
%   the remaining variables range over the case's constants.
ground_instance(Body, Head, Facts, Derived, Domain, Bind, GB, GH) :-
    term_variables_named(Body-Head, Names),
    pairs_keys_values(Bind0, Names, _),
    match_base(Body, Facts, Derived, Bind0),
    maplist(bind_rest(Domain), Bind0),
    Bind = Bind0,
    maplist(ground_lit(Bind), Body, GB0),
    ground_lit(Bind, Head, GH),
    exclude(==(true), GB0, GB).

term_variables_named(T, Names) :-
    findall(N, sub_term(var(N, _), T), Ns0), sort(Ns0, Names).

match_base([], _, _, _).
match_base([L|Ls], Facts, Derived, Bind) :-
    (   L = l(none, pos, p(Iri), As), \+ memberchk(Iri, Derived), \+ ( member(A, As), \+ simple_arg(A) )
    ->  member(lit(Iri, Vs), Facts),
        maplist(match_arg(Bind), As, Vs)
    ;   true
    ),
    match_base(Ls, Facts, Derived, Bind).

simple_arg(var(_, _)).
simple_arg(A) :- ground_arg(A).

match_arg(Bind, var(N, _), V) :- !, memberchk(N-V, Bind).
match_arg(_, A, V) :- arg_value(A, V).

bind_rest(Domain, _-V) :- ( var(V) -> member(V, Domain) ; true ).

ground_lit(Bind, l(M, S, N, As), l(M, S, N, Vs)) :- maplist(ground_arg_value(Bind), As, Vs).

ground_arg_value(Bind, var(N, _), V) :- !, memberchk(N-V, Bind).
ground_arg_value(Bind, expr(F, As), V) :- !,
    maplist(ground_arg_value(Bind), As, Vs),
    (   memberchk(F-Op, [subtract-(-), add-(+), multiply-(*), divide-(/)]), Vs = [X, Y], number(X), number(Y)
    ->  E =.. [Op, X, Y], V is E
    ;   V =.. [F|Vs]
    ).
ground_arg_value(Bind, slot(_, A), V) :- !, ground_arg_value(Bind, A, V).
ground_arg_value(_, A, V) :- arg_value(A, V).

		 /*******************************
		 *          OVERRIDES           *
		 *******************************/

%   Override over > under between instances agreeing on shared names. A
%   pair whose conclusions do not conflict gets a defeater of the under
%   instance's applicability (its conclusion is then reached through an
%   `ok` literal).
overrides(Model, Insts0, Insts, Sups) :-
    Model = model(Is),
    findall(O-U, ( member(override(O0, U0), Is),
                   model_statement(Model, O0, O), model_statement(Model, U0, U) ), Pairs0),
    sort(Pairs0, Pairs),
    findall(pair(LO, LU, Conflict, BO),
            ( member(O-U, Pairs),
              member(inst(LO, O, _, BindO, BO, HO), Insts0),
              member(inst(LU, U, TU, BindU, _, HU), Insts0),
              TU \== strict,                    % a priority is between defeasible rules
              agree(BindO, BindU),
              ( conflicting(HO, HU) -> Conflict = true ; Conflict = false ) ), Ps),
    findall(LO > LU, member(pair(LO, LU, true, _), Ps), Sups0),
    findall(LU, member(pair(_, LU, false, _), Ps), Guarded0), sort(Guarded0, Guarded),
    foldl(guard_inst(Guarded), Insts0, [], Rev), reverse(Rev, Insts1),
    sort(Sups0, Sups1),
    findall(inst(LB, blocker, defeater, [], BO, l(none, neg, p(ok(LU)), [])),
            ( nth1(I, Ps, pair(_, LU, false, BO)), format(atom(LB), 'b~w_~w', [I, LU]) ), Blockers),
    findall(LB > LU, member(inst(LB, blocker, _, _, _, l(_, _, p(ok(LU)), _)), Blockers), Sups2),
    append(Insts1, Blockers, Insts),
    append(Sups1, Sups2, Sups).

agree(B1, B2) :- forall(( member(N-V1, B1), memberchk(N-V2, B2) ), V1 == V2).

conflicting(l(M, S1, N, As), l(M, S2, N, As)) :- S1 \== S2, !.
conflicting(l('OBL', neg, N, As), l('PER', pos, N, As)) :- !.
conflicting(l('PER', pos, N, As), l('OBL', neg, N, As)).

guard_inst(Guarded, inst(L, S, T, B, Body, H), Acc, Out) :-
    (   memberchk(L, Guarded)
    ->  atom_concat(L, '_h', LH),
        Out = [inst(LH, S, defeasible, B, [l(none, pos, p(ok(L)), [])], H),
               inst(L, S, T, B, Body, l(none, pos, p(ok(L)), []))|Acc]
    ;   Out = [inst(L, S, T, B, Body, H)|Acc]
    ).

		 /*******************************
		 *             DFL              *
		 *******************************/

write_rule(Lab, Type, Body, Head) :-
    arrow(Type, Arrow),
    format("~w: ", [Lab]),
    (   Body == [] -> true
    ;   foldl([L, F0, F]>>( ( F0 == first -> true ; write(', ') ), write_lit(L), F = next ), Body, first, _)
    ),
    format(" ~w ", [Arrow]), write_lit(Head), nl.

arrow(strict, '->').
arrow(defeasible, '=>').
arrow(defeater, '~>').

write_lit(l(Mode, Sign, N, Vs)) :-
    ( Mode == none -> true ; format("[~w] ", [Mode]) ),
    ( Sign == neg -> write('-') ; true ),
    dfl_name(N, DN), write(DN),
    %  the arguments are part of the name: SPINdle 2.2.4's defeater removal
    %  conflates literals of one predicate with different arguments (a
    %  defeater of p(a) defeated p(b)), so the theory is written ground and
    %  propositional: p__c1_c2
    (   Vs == [] -> true
    ;   maplist(dfl_const, Vs, Ts), atomic_list_concat(Ts, '_', A), format("__~w", [A])
    ).

dfl_name(p(Iri), N) :- !, name_part(Iri, P), atom_concat('p_', P, N).
dfl_name(o(s(S, Iri)), N) :- !, name_part(Iri, P), ( S == pos -> atom_concat('o_', P, N) ; atom_concat('on_', P, N) ).
dfl_name(v(K, s(S, Iri)), N) :- !, name_part(Iri, P), format(atom(N), 'v_~w_~w_~w', [K, S, P]).

name_part(ok(L), P) :- !, atom_concat(ok_, L, P).
name_part(violation(S), P) :- !, camel_snake(S, S1), atom_concat(violation_, S1, P).
name_part(compliance(S), P) :- !, camel_snake(S, S1), atom_concat(compliance_, S1, P).
name_part(Iri, P) :- rel_token(Iri, P).

%   A relation's DFL name: its IRI's local name made an identifier, kept
%   one-to-one by a table.
rel_token(Iri, T) :-
    (   nb_current(lrml_rel_tokens, Ts), memberchk(Iri-T, Ts) -> true
    ;   camel_snake(Iri, T0), atom_codes(T0, Cs), include([C]>>code_type(C, csym), Cs, Cs1),
        atom_codes(T2, Cs1), atomic_list_concat(Ws0, '_', T2), exclude(==(''), Ws0, Ws),
        atomic_list_concat(Ws, '_', T1),                % no `__`: it separates the arguments
        ( nb_current(lrml_rel_tokens, Ts0) -> true ; Ts0 = [] ),
        length(Ts0, K), format(atom(T), '~w_~w', [T1, K]),
        nb_setval(lrml_rel_tokens, [Iri-T|Ts0])
    ).

%   A constant's DFL token (c<N>), kept in a table for the way back.
dfl_const(V, T) :-
    nb_getval(lrml_const, Cs),
    (   member(T0-V0, Cs), V0 == V -> T = T0
    ;   length(Cs, N), format(atom(T), 'c~w', [N]),
        nb_setval(lrml_const, [T-V|Cs])
    ).

		 /*******************************
		 *        RUN AND DECODE        *
		 *******************************/

run_spindle(Text, Lines) :-
    spindle_jar(Jar),
    tmp_file_stream(text, File0, S0), close(S0),
    file_name_extension(File0, dfl, File),
    setup_call_cleanup(open(File, write, S), write(S, Text), close(S)),
    setup_call_cleanup(
        process_create(path(java), ['-jar', Jar, File], [stdout(pipe(Out)), stderr(null), process(Pid)]),
        ( read_string(Out, _, Str), process_wait(Pid, _) ),
        ( close(Out), delete_file(File), catch(delete_file(File0), _, true) )),
    (   sub_string(Str, _, _, _, "Exception")
    ->  sub_string(Str, B, _, _, "Exception"), sub_string(Str, B, 300, _, Why0),
        throw(error(format("SPINdle: ~w", [Why0]), _))
    ;   true
    ),
    split_string(Str, "\n", " \t", Lines).

decode_lines(Lines, names(_, Consts), Conclusions) :-
    nb_current(lrml_rel_tokens, RelTs),
    findall(C, ( member(Line, Lines), string_concat("+d ", Lit, Line),
                 string_codes(Lit, Cs), phrase(dfl_lit(Mode, Sign, Name, Args), Cs),
                 decode(Mode, Sign, Name, Args, RelTs, Consts, C) ), Cs0),
    sort(Cs0, Conclusions).

dfl_lit(Mode, Sign, Name, Args) -->
    ( "[", string_without(`]`, MC), "]" -> { atom_codes(Mode, MC) } ; { Mode = none } ),
    ( "-" -> { Sign = neg } ; { Sign = pos } ),
    string_without(`(`, NC), { atom_codes(Name0, NC) },
    { (   sub_atom(Name0, B, 2, _, '__')
      ->  sub_atom(Name0, 0, B, _, Name), B2 is B + 2, sub_atom(Name0, B2, _, 0, AA),
          atomic_list_concat(Args, '_', AA)
      ;   Name = Name0, Args = []
      ) },
    remainder(_).

decode(Mode, Sign, Name, Args, RelTs, Consts, C) :-
    maplist({Consts}/[T, V]>>memberchk(T-V, Consts), Args, Vs),
    (   Mode == none, atom_concat('p_', P, Name), memberchk(Iri-P, RelTs)
    ->  ( Sign == pos -> C = lit(Iri, Vs) ; C = neg(lit(Iri, Vs)) )
    ;   Mode \== none, ( atom_concat('o_', P, Name) -> SS = pos ; atom_concat('on_', P, Name), SS = neg ),
        memberchk(Iri-P, RelTs)
    ->  Vs = [B|As], sentence_term(SS, Iri, As, S),
        mode_kind(Mode, Sign, K), C = deontic(K, B, S)
    ;   Mode == none, Sign == pos, atomic_list_concat([v, K, SS | Ps], '_', Name),
        atomic_list_concat(Ps, '_', P), memberchk(Iri-P, RelTs)
    ->  Vs = [B|As], sentence_term(SS, Iri, As, S), C = violated(K, B, S)
    ).

sentence_term(pos, Iri, As, lit(Iri, As)).
sentence_term(neg, Iri, As, neg(lit(Iri, As))).

mode_kind('OBL', pos, obligation).
mode_kind('OBL', neg, prohibition).
mode_kind('PER', pos, permission).

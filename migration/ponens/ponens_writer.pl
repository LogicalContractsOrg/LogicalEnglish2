/** <module> Logical English for LPS → Ponens policies (the way back)

    the design notes ponens.md. A program in the vocabulary of the
    Ponens twins (ponens_twin.pl: `step S was a K`, `step S has shown "…"`,
    `step S meets "…"`, `the policy P is broken at step S`, …) is read in its
    LPS form (LE2's le_lps_file/4) and each law that records a breach is
    written back as a Ponens policy: the law is the policy's violation, its
    named conditions the sub-formulas.

      - `when step a step ends and <conditions> then the policy P is broken at
        step the step`, and the same law on `the session ends` with `step a
        step has ended`, is `G(φ)` with φ the condition the law's
        conditions break: `G(T → C)` when the last condition is a negation
        (`it is not the case that C`) and others come before it, `G(C)` when
        it stands alone, `G(¬(…))` when none is negated.
      - `when the session ends and <conditions> then the policy P is broken`
        is a formula about the whole trace.
      - A named condition is the formula of its rules: two rules an `∨`;
        `step a second step has ended and the second step < the step and …`
        a `P(…)`; `>=` an `F(…)`; `is in the chain of` a `P_chain(…)`;
        `shares a target with` a `P_target(…)`; the gap of `S_last` its
        right side.
      - The eight policies Ponens decides by name (ponens_twin:structural_
        policy/1) are written back with their own formula: the law follows
        Ponens's code, not a formula, and the formula is what names them.

    The severity and the rationale of each policy are read from the comment
    above its law (`% id (severity): formula` and the line after it), as the
    twin writes it; a law without that comment is an `error` with no
    rationale.
*/

:- module(ponens_writer, [
    twin_policies/2,          % +LEFile, -Policies (dicts, Ponens's trace-policy shape)
    terms_policies/3,         % +Terms, +Text, -Policies
    write_policies/2          % +LEFile, +JSONFile
]).

:- if(exists_source(library(json))).
:- use_module('../le2_paths', []).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(readutil)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(ponens_formula).
:- use_module(ponens_twin, [structural_policy/1]).

%!  write_policies(+LEFile, +JSONFile) is det.
write_policies(LEFile, JSONFile) :-
    twin_policies(LEFile, Policies),
    setup_call_cleanup(open(JSONFile, write, Out, [encoding(utf8)]),
                       json_write_dict(Out, Policies, [width(0)]),
                       close(Out)).

%!  twin_policies(+LEFile, -Policies) is det.
twin_policies(LEFile, Policies) :-
    lps_terms(LEFile, Terms),
    read_file_to_string(LEFile, Text, [encoding(utf8)]),
    terms_policies(Terms, Text, Policies).

%!  terms_policies(+Terms, +Text, -Policies) is det.
%
%   The policies of a program given in LPS's internal form (Terms) and as
%   its text (for the comments that carry each policy's severity and
%   rationale).
terms_policies(Terms, Text, Policies) :-
    comments(Text, Meta),
    findall(Id-Law, law(Terms, Id, Law), Laws0),
    group_laws(Laws0, Groups),
    findall(P, ( member(Id-Ls, Groups), policy(Terms, Meta, Id, Ls, P) ), Policies).

%   The program in LPS's internal form, as terms.
lps_terms(File, Terms) :-
    le2_loaded,
    le_lps:le_lps_file(File, Internal, _Prov, _Issues),
    term_string_list(Internal, Terms).

le2_loaded :-
    (   current_predicate(le_lps:le_lps_file/4) -> true
    ;   ( getenv('LE2_DIR', D) -> true ; le2_paths:le2_dir(D) ),
        atomic_list_concat([D, '/le_kbs'], K), use_module(K),
        atomic_list_concat([D, '/le_lps'], L), use_module(L)
    ).

term_string_list(Text, Terms) :-
    setup_call_cleanup(open_string(Text, In),
                       read_terms(In, Terms),
                       close(In)).

read_terms(In, Ts) :-
    catch(read_term(In, T, []), _, T = end_of_file),
    (   T == end_of_file -> Ts = []
    ;   Ts = [T|Ts1], read_terms(In, Ts1)
    ).

		 /*******************************
		 *		the laws		*
		 *******************************/

%   law(+Terms, -Policy, -Law): Law is step(S, Conds) (G, checked when a step
%   ends or at the end), or trace(Conds).
law(Terms, Id, step(S, Conds)) :-
    member(initiated(happens(step_ends(S), _, _), broken_at(Id, S), Conds), Terms).
law(Terms, Id, Law) :-
    member(initiated(happens(session_ends, _, _), F, Conds0), Terms),
    (   F = broken_at(Id, S)
    ->  exclude(ended(S), Conds0, Conds), Law = step(S, Conds)
    ;   F = broken(Id), Law = trace(Conds0)
    ).

ended(S, holds(has_ended(S1), _)) :- S1 == S.

group_laws(Laws, Groups) :-
    findall(Id, member(Id-_, Laws), Ids0), list_to_set(Ids0, Ids),
    findall(Id-Ls, ( member(Id, Ids), findall(L, member(Id-L, Laws), Ls) ), Groups).

policy(Terms, Meta, Id, Laws, Policy) :-
    (   structural_policy(Id), structural_formula(Id, F)
    ->  true
    ;   Laws = [step(S, Conds)]
    ->  violation_formula(Terms, S, Conds, Phi), formula_text(g(Phi), F)
    ;   Laws = [trace(Conds)]
    ->  trace_formula(Terms, Conds, Phi), formula_text(Phi, F)
    ;   F = ''
    ),
    (   memberchk(meta(Id, Sev, _F0, Rat), Meta) -> true ; Sev = error, Rat = '' ),
    Policy = _{policy_id: Id, name: Id, severity: Sev, scope: "trace", kind: "trace_invariant",
               formula: F, description: Rat}.

%   The formula a law's conditions break.
violation_formula(Terms, S, Conds0, Phi) :-
    maplist(literal_formula(Terms, S), Conds0, Lits),
    (   append(Trig, [neg(C)], Lits), Trig \== []
    ->  maplist(pos_of, Trig, Ts), conj(Ts, T), Phi = implies(T, C)
    ;   Lits = [neg(C)]
    ->  Phi = C
    ;   maplist(pos_of, Lits, Ts), conj(Ts, T), Phi = not(T)
    ).

trace_formula(Terms, Conds, Phi) :-
    maplist(trace_literal(Terms), Conds, Lits),
    (   append(Trig, [neg(C)], Lits), Trig \== []
    ->  maplist(pos_of, Trig, Ts), conj(Ts, T), Phi = implies(T, C)
    ;   Lits = [neg(C)]
    ->  Phi = C
    ;   maplist(pos_of, Lits, Ts), conj(Ts, T), Phi = not(T)
    ).

pos_of(pos(F), F).
pos_of(neg(F), not(F)).

%   Left to right, as Ponens's parser groups `a ∧ b ∧ c`.
conj([F|Fs], C) :- foldl([X, A, and(A, X)]>>true, Fs, F, C).

		 /*******************************
		 *	      literals		*
		 *******************************/

%   literal_formula(+Terms, +S, +Cond, -Lit): Lit is pos(F) or neg(F), F a
%   formula at step S.
literal_formula(Terms, S, holds(not(Fl), _), neg(F)) :- !, fluent_formula(Terms, S, Fl, F).
literal_formula(Terms, S, holds(Fl, _), pos(F)) :- !, fluent_formula(Terms, S, Fl, F).
literal_formula(_, _, G, pos(raw(T))) :- term_string(G, T).

fluent_formula(_, S, was_a(S1, K), atom(K)) :- S1 == S, !.
fluent_formula(_, S, has_shown(S1, Sign), F) :- S1 == S, !, sign_formula(Sign, F).
fluent_formula(_, _, trace_has_shown(Sign), F) :- !, trace_sign(Sign, F).
fluent_formula(Terms, S, meets(S1, Name), F) :- S1 == S, !, condition(Terms, Name, F).
fluent_formula(Terms, _, trace_meets(Name), F) :- !, trace_condition(Terms, Name, F).
fluent_formula(_, _, Fl, raw(T)) :- term_string(Fl, T).

trace_literal(Terms, holds(not(Fl), _), neg(F)) :- !, fluent_formula(Terms, none, Fl, F).
trace_literal(Terms, holds(Fl, _), pos(F)) :- !, fluent_formula(Terms, none, Fl, F).
trace_literal(_, G, pos(raw(T))) :- term_string(G, T).

%   A sign back to its atom: words → `snake_case`; a sign with brackets or
%   ≠ is Ponens text, read again.
sign_formula(Sign0, F) :-
    atom_string(Sign, Sign0),
    (   ( sub_atom(Sign, _, _, _, '(') ; sub_atom(Sign, _, _, _, '≠') )
    ->  parse_formula(Sign, F)
    ;   atomic_list_concat(Ws, ' ', Sign), atomic_list_concat(Ws, '_', A), F = atom(A)
    ).

trace_sign(Sign0, F) :-
    atom_string(Sign, Sign0),
    (   Sign == 'start event' -> F = start_event
    ;   Sign == 'end event' -> F = end_event
    ;   sign_formula(Sign, F)
    ).

		 /*******************************
		 *	 the named conditions	*
		 *******************************/

%   condition(+Terms, +Name, -F): the formula of `step S meets Name`.
condition(Terms, Name, F) :-
    findall(V-Body, ( member(l_int(holds(meets(V, N), _), Body), Terms), N == Name ), Rules),
    (   Rules == [] -> term_string(Name, T), F = raw(T)
    ;   maplist(rule_formula(Terms), Rules, Fs), disj(Fs, F)
    ).

disj([F|Fs], D) :- foldl([X, A, or(A, X)]>>true, Fs, F, D).

rule_formula(Terms, S-Body, F) :-
    (   select(holds(has_ended(S2), _), Body, B1), S2 \== S,
        select(Cmp, B1, B2), compare_of(Cmp, S2, S, Op)
    ->  partition(about(S2), B2, AtS2, Rest),
        temporal(Op, Terms, S2, S, AtS2, Rest, F)
    ;   select(holds(in_chain(S2, S1), _), Body, B1), S1 == S
    ->  lits_formula(Terms, S2, B1, X), F = p_chain(X)
    ;   select(holds(shares_target(S2, S1), _), Body, B1), S1 == S
    ->  lits_formula(Terms, S2, B1, X), F = p_target(X)
    ;   lits_formula(Terms, S, Body, F)
    ).

compare_of(A < B, S2, S, lt) :- A == S2, B == S, !.
compare_of(A >= B, S2, S, ge) :- A == S2, B == S, !.
compare_of(A > B, S2, S, gt) :- A == S2, B == S, !.
compare_of(A =< B, S2, S, le) :- A == S2, B == S, !.

about(S2, holds(not(Fl), _)) :- !, about_fluent(S2, Fl).
about(S2, holds(Fl, _)) :- about_fluent(S2, Fl).
about_fluent(S2, Fl) :- arg(1, Fl, A), A == S2, \+ Fl = meets_with(_, _, _).

temporal(lt, Terms, S2, _S, AtS2, [], p(X)) :- !, lits_formula(Terms, S2, AtS2, X).
temporal(ge, Terms, S2, _S, AtS2, [], f(X)) :- !, lits_formula(Terms, S2, AtS2, X).
temporal(lt, Terms, S2, S, AtS2, [holds(not(meets_with(A, Nb, B)), _)], s_last(L, R)) :- A == S2, B == S, !,
    lits_formula(Terms, S2, AtS2, L), between_formula(Terms, Nb, R).
temporal(gt, Terms, S2, S, AtS2, [holds(not(meets_with(A, _, B)), _)], x(X)) :- A == S, B == S2, !,
    lits_formula(Terms, S2, AtS2, X).
temporal(ge, Terms, S2, S, AtS2, [holds(not(meets_with(A, Nb, B)), _)], u(A1, B1)) :- A == S, B == S2, !,
    lits_formula(Terms, S2, AtS2, B1), between_formula(Terms, Nb, NotA), negate(NotA, A1).
temporal(le, Terms, S2, S, AtS2, [holds(not(meets_with(A, Nb, B)), _)], s(A1, B1)) :- A == S2, B == S, !,
    lits_formula(Terms, S2, AtS2, B1), between_formula(Terms, Nb, NotA), negate(NotA, A1).
temporal(_, _, _, _, _, Rest, raw(T)) :- term_string(Rest, T).

negate(not(X), X) :- !.
negate(X, not(X)).

%   The formula a step between two others meets (`step a step meets N with
%   step an other step`, a third step between them).
between_formula(Terms, Name, F) :-
    (   member(l_int(holds(meets_with(_, N, _), _), Body), Terms), N == Name
    ->  include([C]>>( C = holds(has_ended(_), _) -> fail ; \+ compound_cmp(C) ), Body, B1),
        (   member(holds(has_ended(S3), _), Body) -> true ; S3 = _ ),
        lits_formula(Terms, S3, B1, F)
    ;   term_string(Name, T), F = raw(T)
    ).

compound_cmp(_ < _).
compound_cmp(_ > _).
compound_cmp(_ >= _).
compound_cmp(_ =< _).

lits_formula(Terms, S, Body, F) :-
    maplist(literal_formula(Terms, S), Body, Lits),
    maplist(pos_of, Lits, Fs),
    conj(Fs, F).

trace_condition(Terms, Name, F) :-
    findall(Body, ( member(l_int(holds(trace_meets(N), _), Body), Terms), N == Name ), Rules),
    (   Rules == [] -> term_string(Name, T), F = raw(T)
    ;   maplist(trace_rule_formula(Terms), Rules, Fs), disj(Fs, F)
    ).

trace_rule_formula(Terms, Body, F) :-
    (   Body = [holds(findall(S, Inner, L), _), length(L1, D), Cmp], L1 == L,
        Cmp =.. [Op0, D1, N], D1 == D, cmp_op(Op0, Op)
    ->  exclude(ended(S), Inner, Inner1),
        lits_formula(Terms, S, Inner1, X), F = count(X, Op, N)
    ;   Body = [holds(not(trace_meets(Nf)), _)], item_rule(Terms, Nf, Q)
    ->  F = Q
    ;   select(holds(has_ended(S), _), Body, B1)
    ->  lits_formula(Terms, S, B1, X), F = f(X)
    ;   maplist(trace_literal(Terms), Body, Lits), maplist(pos_of, Lits, Fs), conj(Fs, F)
    ).

cmp_op(=<, '<=').
cmp_op(>=, '>=').
cmp_op(<, '<').
cmp_op(>, '>').
cmp_op(=, '=').

%   `∀ s ∈ C . φ`, written as "no item of C fails φ": the rule of the item
%   that fails, back to φ.
item_rule(Terms, Name, forall(s, Set, Phi)) :-
    member(l_int(holds(trace_meets(N), _), Body), Terms), N == Name,
    select(holds(item_had(I, Set, V, Fd), _), Body, B1), var(V), var(Fd), !,
    partition(neg_item, B1, Negs, Poss),
    maplist(item_compare(I, neg), Negs, Cs), maplist(item_compare(I, pos), Poss, Ts),
    conj(Cs, Cons),
    (   Ts == [] -> Phi = Cons ; conj(Ts, Trig), Phi = implies(Trig, Cons) ).

neg_item(holds(not(_), _)).

item_compare(_, neg, holds(not(item_had(_, _, V, Fd)), _), C) :- !, value_compare(V, Fd, C).
item_compare(_, pos, holds(item_had(_, _, V, Fd), _), C) :- value_compare(V, Fd, C).

value_compare(V, Fd, compare(field(s, Fd), '!=', atom('EMPTY'))) :- var(V), !.
value_compare(V, Fd, compare(field(s, Fd), '=', atom(A))) :- atom_string(A, V).

		 /*******************************
		 *	   what the twin says	*
		 *******************************/

%   meta(Id, Severity, Formula, Rationale): the comment above each policy.
comments(Text, Metas) :-
    split_string(Text, "\n", "", Lines),
    findall(meta(Id, Sev, F, Rat),
            ( nth1(I, Lines, L),
              sub_string(L, 0, 2, _, "% "),
              sub_string(L, B, _, _, " ("), sub_string(L, 2, Len, _, IdS), Len is B - 2,
              \+ sub_string(IdS, _, _, _, " "),
              sub_string(L, B2, _, A2, "): "), B2 > B, Bs is B + 2, Ls is B2 - Bs,
              sub_string(L, Bs, Ls, _, SevS), sub_string(L, _, A2, 0, FS),
              atom_string(Id, IdS), atom_string(Sev, SevS), atom_string(F, FS),
              I1 is I + 1, ( nth1(I1, Lines, R0), sub_string(R0, 0, 2, _, "% ") -> sub_string(R0, 2, _, 0, Rat) ; Rat = "" ) ),
            Metas).

%   The formulas Ponens's structural policies are known by (its gallery).
structural_formula(data_flow_integrity, 'G(∀input ∈ inputs(a) → ∃!b . b < a ∧ input ∈ outputs(b))').
structural_formula(goals_reference_valid_artifacts, 'G(VerificationGoal → target_artifact_id ∈ {a.id | a.type = IMLModel})').
structural_formula(files_modified_consistent, 'files_modified = {target(a) | G(a ∧ (EditFile ∨ CreateFile ∨ DeleteFile))}').
structural_formula(generated_tests_require_decomposition, 'G(GeneratedTests → Decomposition ∈ ancestors(derived_from))').
structural_formula(no_open_critical_residuals, '¬∃ r ∈ residuals . r.severity = Critical ∧ r.status = Open').
structural_formula(high_severity_residuals_acknowledged_before_commit, 'G(GitCommit → ∀ r ∈ residuals . r.severity ≥ High → r.status ≠ Open)').
structural_formula(unverified_residuals_have_suggested_check, '∀ r ∈ residuals . r.kind = Unverified → r.suggested_check ≠ ∅').
structural_formula(assumptions_are_located, '∀ r ∈ residuals . r.kind = Assumption → (r.target ≠ ∅ ∨ r.related_artifact_ids ≠ ∅)').

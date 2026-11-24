/** <module> Tests of the Ponens translator

    swipl -q -g run_tests -t halt migration/ponens/test_ponens.pl

    (from the LE2 checkout: LE2 is needed for the way back, which reads a
    program's LPS form). The gate, which runs the twins on LPS2 against
    Ponens's own evaluator, is ponens_gate.py.
*/

:- module(test_ponens, []).

:- use_module(library(plunit)).
:- use_module('../le2_paths', []).      % declares LE2 as the `le2` search path
:- use_module(library(lists)).
:- use_module(ponens_formula).
:- use_module(ponens_twin).
:- use_module(ponens_writer).

:- begin_tests(ponens_formula).

test(parse_comes_before) :-
    parse_formula("G(Deploy → P(tested ∧ validated))", F),
    F == g(implies(atom('Deploy'), p(and(atom(tested), atom(validated))))).

test(parse_precedence) :-
    parse_formula("G((Decision ∨ Output) → logged ∧ data_sources_recorded ∧ algorithm_recorded)", F),
    F == g(implies(or(atom('Decision'), atom('Output')),
                   and(and(atom(logged), atom(data_sources_recorded)), atom(algorithm_recorded)))).

test(parse_atom_args_and_unary_without_brackets) :-
    parse_formula("G(EditFile ∧ high_stakes_path → P_chain(VerificationResult(proved ∨ sat) ∨ Decomposition))", F),
    F = g(implies(_, p_chain(or(atom_args('VerificationResult', [or(atom(proved), atom(sat))]), atom('Decomposition'))))),
    parse_formula("G(Deploy → P UserApproval)", F2),
    F2 == g(implies(atom('Deploy'), p(atom('UserApproval')))).

test(parse_what_ponens_cannot) :-
    parse_formula("G(EditFile ∧ infra_scope → P(UserApproval ∧ approver_2 ≠ approver_1))", F),
    F = raw(_).

test(round_trip) :-
    forall(member(S, ["G(GitCommit → (RunTests ∧ completed) S_last GitCommit)",
                      "count(ToolCall) ≤ 20",
                      "(F SourceCode) → G(Verify → F(ConformanceResult(passed)))",
                      "∀ s ∈ telemetry . s.status = recorded",
                      "start_event ∧ F end_event",
                      "G(GitCommit → ¬P(CreateFile ∧ secret_pattern))"]),
           ( parse_formula(S, F), formula_text(F, T), parse_formula(T, F2), F2 == F )).

:- end_tests(ponens_formula).

:- begin_tests(ponens_twin).

policy(Id, Formula, P) :-
    P = _{id: Id, name: Id, formula: Formula, severity: "error", rationale: "a test"}.

test(law_of_a_comes_before_policy, [nondet]) :-
    policy("tested_first", "G(Deploy → P(tested ∧ validated))", P),
    twin_text(t, [P], [], twin(Text, [E])),
    sub_atom(Text, _, _, _, 'step a step meets "an earlier step shows tested and shows validated" at a time if'),
    sub_atom(Text, _, _, _, 'when step a step ends\n    and step the step was a Deploy\n    and it is not the case that step the step meets "an earlier step shows tested and shows validated"\nthen the policy tested_first is broken at step the step.'),
    E.verdict == encoded.

test(forward_looking_policy_waits_for_the_end, [nondet]) :-
    policy("verify_after", "G(Formalize → F(Verify))", P),
    twin_text(t, [P], [], twin(Text, _)),
    sub_atom(Text, _, _, _, 'when the session ends\n    and step a step has ended').

test(unreadable_formula_is_residue) :-
    policy("two_person", "G(EditFile → P(UserApproval ∧ approver_2 ≠ approver_1))", P),
    twin_text(t, [P], [], twin(_, [E])),
    E.verdict == residue.

test(oracle_field_is_part_of_the_formula) :-
    P = _{id: "fa", name: "fa", formula: "G(Formalize → F(Verify))", severity: "error", reasoner: "codelogician"},
    effective_formula(P, F),
    F == '(G(Formalize → F(Verify))) ∧ G(Verify → (produced_by(codelogician) ∨ oracle_type(codelogician)))'.

:- end_tests(ponens_twin).

:- begin_tests(ponens_way_back).

%   A twin written to a file, read back: the same formulas.
test(round_trip_through_lps, [setup(le2)]) :-
    Fs = ["G(Deploy → P(tested ∧ validated))",
          "G(Recommendation → suitability_assessed)",
          "G(Formalize → F(Verify ∨ StateSpaceAnalysis))",
          "G(EditFile → P_target(ReadFile ∨ ReadDocumentation))",
          "G(¬mandatory_violation)",
          "F(ComplianceSummary)",
          "G(GitCommit → (RunTests ∧ completed) S_last GitCommit)",
          "G(Deploy → X(Notify))",
          "G(Deploy → (Review U Approve))",
          "G(Deploy → (Review S Approve))"],
    findall(P, ( nth1(I, Fs, F), format(string(Id), "p~w", [I]), policy(Id, F, P) ), Ps),
    twin_text(t, Ps, [], twin(Text, _)),
    tmp_file_stream(text, File, S), close(S),
    atom_concat(File, '.le', LE),
    setup_call_cleanup(open(LE, write, O, [encoding(utf8)]), write(O, Text), close(O)),
    twin_policies(LE, Back),
    delete_file(LE),
    forall(( nth1(I, Fs, F), format(atom(Id), "p~w", [I]) ),
           ( member(B, Back), B.policy_id == Id, parse_formula(F, A1), parse_formula(B.formula, A2),
             ( A1 == A2 -> true ; format(user_error, "~w: ~w ≠ ~w~n", [Id, F, B.formula]), fail ) )).

policy(Id, Formula, P) :-
    P = _{id: Id, name: Id, formula: Formula, severity: "error", rationale: "a test"}.

le2 :-
    (   current_predicate(le_lps:le_lps_file/4) -> true
    ;   use_module(le2(le_kbs)), use_module(le2(le_lps))
    ).

:- end_tests(ponens_way_back).

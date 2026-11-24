/** <module> Ponens policy packs → Logical English for LPS

    the design notes ponens.md. A pack of Ponens policies (github.com/
    imandra-ai/ponens, the `.json` files of `gallery/policies`) becomes one document in
    Logical English for LPS (LE for LPS), run by LPS2; each Ponens trace given
    becomes one of its scenarios.

    The reading:

      - A trace's actions are steps. Step k of the trace (its actions in the
        order of their ids) happens in cycle 2k: what Ponens's evaluator
        reads off the action becomes events of that cycle — `step 3 is a
        Deploy`, `step 3 shows "tested"`, `step 3 comes after step 1 in its
        chain` — and `step 3 ends` follows in cycle 2k+1. Which atom holds at
        which action, and which earlier actions are in an action's chain or
        on its target, is Ponens's own reading, asked of its code
        (ponens_reading.py): the twin translates the policies, not the
        evaluator's reading of its own trace format.
      - Each event becomes a fluent (`step 3 was a Deploy`), kept to the end.
      - A policy `G(φ)` is a causal law that records a breach — `the policy P
        is broken at step S` — for each step at which φ is false: when that
        step ends, if φ looks only backwards (P, H, P_chain, P_target,
        S_last); when the session ends, if φ looks forward (F, G, X, U). Any
        other policy is a law on `the session ends`: `the policy P is
        broken`.
      - Each sub-formula that is not a plain atom is a condition with a name
        of its own, an intensional fluent `step S meets "<name>"` defined by
        rules: an `∨` by two rules, `P(ψ)` by "an earlier step that has
        ended meets ψ", `F(ψ)` by "this or a later step", `H(ψ)` and a nested
        `G(ψ)` as "no earlier (or later) step fails ψ" (LPS has no reading
        for a universal, so the universal is written as a double negation).
      - Ponens decides eight policies by name, in code of its own rather than
        from their formulas (`STRUCTURAL_POLICIES`: data flow, goal targets,
        declared files, decompositions behind generated tests, and four on
        the residual surface). Their laws are written from that code, over
        the facts it reads (`artifact a1 is made by step 2`, `residual r1
        has severity "critical"`, …).
      - A policy's `oracle` (or `reasoner`) field is part of its formula, as
        Ponens's `effective_formula` makes it: the evidence its atoms name
        must be produced by that oracle.
      - What Ponens's parser cannot read (a `RawStructural` formula, which
        Ponens reports as "too complex for runtime evaluation") is kept as
        residue: the formula in a comment, no law, and a ledger row saying so.

    The way back is ponens_writer.pl.
*/

:- module(ponens_twin, [
    load_policies/2,          % +GalleryDir, -Policies (dicts)
    pack_policies/3,          % +Policies, ?PackId, -PackPolicies
    effective_formula/2,      % +Policy, -Text
    twin_text/4,              % +Pack, +Policies, +Traces, -twin(Text, Ledger)
    trace_reading/3,          % +TraceFile, +AtomTexts, -Reading
    pack_atoms/2,             % +Policies, -AtomTexts
    structural_policy/1       % ?Name
]).

:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pcre)).
:- use_module(library(pairs)).
:- use_module(ponens_formula).

:- dynamic reader_python/1.

		 /*******************************
		 *	      the policies		*
		 *******************************/

%!  load_policies(+GalleryDir, -Policies) is det.
%
%   The policies of a Ponens checkout's gallery (`gallery/policies/*.json`,
%   the files whose name does not start with `_`), as dicts, sorted by id.
load_policies(Dir, Policies) :-
    atomic_list_concat([Dir, '/policies/*.json'], Pattern),
    expand_file_name(Pattern, Files),
    findall(Id-P,
            ( member(F, Files), file_base_name(F, B), \+ sub_atom(B, 0, 1, _, '_'),
              read_json(F, P), atom_string(Id, P.id) ),
            Pairs),
    keysort(Pairs, Sorted), pairs_values(Sorted, Policies).

read_json(File, Dict) :-
    setup_call_cleanup(open(File, read, In, [encoding(utf8)]),
                       json_read_dict(In, Dict, [default_tag(json)]),
                       close(In)).

%!  pack_policies(+Policies, ?Pack, -PackPolicies) is nondet.
%
%   The policies of a pack; the policies of no pack, Ponens's own defaults,
%   are the pack `ponens-defaults`.
pack_policies(Policies, Pack, PackPolicies) :-
    findall(K, ( member(P, Policies), policy_pack(P, K) ), Ks0), sort(Ks0, Ks),
    member(Pack, Ks),
    include(in_pack(Pack), Policies, PackPolicies).

in_pack(Pack, P) :- policy_pack(P, Pack).

policy_pack(P, K) :-
    (   get_dict(pack, P, K0), K0 \== null, K0 \== ''
    ->  atom_string(K, K0)
    ;   K = 'ponens-defaults'
    ).

%!  structural_policy(?Name) is semidet.
%   policy_compiler.py STRUCTURAL_POLICIES: decided by Ponens's code, by name.
structural_policy(N) :- memberchk(N, [
    data_flow_integrity, goals_reference_valid_artifacts, files_modified_consistent,
    generated_tests_require_decomposition, no_open_critical_residuals,
    high_severity_residuals_acknowledged_before_commit,
    unverified_residuals_have_suggested_check, assumptions_are_located]).

policy_name(P, N) :- atom_string(N, P.get(name, P.id)).

%   A policy Ponens decides by its name: the name of a policy file, which
%   ponens_build.pl makes the id, or the gallery's own.
structural(P) :- ( policy_name(P, N), structural_policy(N) -> true ; policy_id(P, I), structural_policy(I) ).
policy_id(P, I) :- atom_string(I, P.id).

%!  effective_formula(+Policy, -Text) is det.
%
%   policy_compiler.py effective_formula/oracle_conjunct: the authored
%   formula, conjoined with what its `oracle` (or `reasoner`) field means —
%   `G(a → (produced_by(x) ∨ oracle_type(x)))` for each evidence atom the
%   formula names (the four result types when it names none). Structural
%   policies keep their formula.
effective_formula(P, Text) :-
    atom_string(F, P.get(formula, "")),
    (   oracle_of(P, X), F \== '', \+ structural(P)
    ->  parse_formula(F, Ast), evidence_atoms(F, Ast, Atoms),
        maplist(oracle_conjunct(X), Atoms, Cs),
        atomic_list_concat(Cs, ' ∧ ', Extra),
        format(atom(Text), '(~w) ∧ ~w', [F, Extra])
    ;   Text = F
    ).

oracle_conjunct(X, A, C) :-
    format(atom(C), 'G(~w → (produced_by(~w) ∨ oracle_type(~w)))', [A, X, X]).

oracle_of(P, X) :-
    (   get_dict(oracle, P, X0), string(X0), X0 \== "" -> true
    ;   get_dict(reasoner, P, X0), string(X0), X0 \== ""
    ),
    normalize_space(atom(X), X0).

evidence_atoms(Text, _Ast, Atoms) :-
    split_string(Text, " ()∧∨→¬,.", " ()∧∨→¬,.", Parts0),
    exclude(==(""), Parts0, Parts),
    findall(A, ( member(S, Parts), atom_string(A, S), evidence_atom(A) ), As0),
    list_to_set(As0, As),
    (   As == [] -> Atoms = ['VerificationResult', 'StateSpaceAnalysisResult', 'ConformanceResult', 'CoSimulationResult']
    ;   Atoms = As ).

evidence_atom(A) :- memberchk(A, ['Verify', 'Decompose', 'StateSpaceAnalysis', 'ConformanceCheck',
    'CoSimulate', 'Test', 'Analyze', 'Observe', 'Judge', 'Attest',
    'VerificationResult', 'Decomposition', 'StateSpaceAnalysisResult', 'ConformanceResult',
    'CoSimulationResult', 'Observation', 'CommandResult', 'TestResult']).

%!  pack_atoms(+Policies, -Texts) is det.
%   The atomic nodes of the policies' formulas, as Ponens formula texts: what
%   the trace reading has to decide at each action.
pack_atoms(Policies, Texts) :-
    findall(T, ( member(P, Policies), \+ structural(P),
                 effective_formula(P, F), parse_formula(F, Ast), Ast \= raw(_),
                 formula_atoms(Ast, Ns), member(Nd, Ns), formula_text(Nd, T) ),
            Ts0),
    list_to_set(Ts0, Texts).

		 /*******************************
		 *	   the trace reading	*
		 *******************************/

%!  trace_reading(+TraceFile, +AtomTexts, -Reading) is det.
%
%   What Ponens's code reads off the trace (ponens_reading.py), as a dict.
trace_reading(TraceFile, Atoms, Reading) :-
    tmp_file_stream(text, AtomsFile, S), set_stream(S, encoding(utf8)),
    json_write(S, Atoms), close(S),
    reader_script(Script), python(Py),
    setup_call_cleanup(
        process_create(Py, [Script, TraceFile, AtomsFile], [stdout(pipe(Out)), stderr(null), process(Pid)]),
        ( set_stream(Out, encoding(utf8)), json_read_dict(Out, Reading, [default_tag(json)]) ),
        ( close(Out), process_wait(Pid, _), delete_file(AtomsFile) )).

reader_script(F) :-
    module_property(ponens_twin, file(Me)), file_directory_name(Me, D),
    atomic_list_concat([D, '/ponens_reading.py'], F).

%   The Python with the `ponens` package: $PONENS_PYTHON, else python3.
python(Py) :- reader_python(Py), !.
python(Py) :-
    (   getenv('PONENS_PYTHON', P), P \== '' -> Py = P
    ;   absolute_file_name(path(python3), Py, [access(execute)])
    ).

		 /*******************************
		 *	   the twin's text		*
		 *******************************/

%!  twin_text(+Pack, +Policies, +Traces, -Twin) is det.
%
%   Twin = twin(Text, Ledger). Traces is a list of trace(Name, File, Reading,
%   Verdicts): Verdicts the list Ponens's `trace check --json` gives for the
%   pack's policies on that trace (for the comment above the scenario).
twin_text(Pack, Policies, Traces, twin(Text, Ledger)) :-
    nb_setval(ponens_names, []),
    maplist(policy_section, Policies, Sections0, Ledger),
    exclude(==(''), Sections0, Sections),
    atomic_list_concat(Sections, '\n', PolicyText),
    length(Traces, NT),
    maplist(scenario_text, Traces, Scens),
    atomic_list_concat(Scens, '\n', ScenText),
    max_time(Traces, MaxT),
    header(Pack, Policies, NT, Header),
    recording_laws(Laws0),
    atomic_list_concat([PolicyText, ScenText], '\n', Used),
    used_laws(Laws0, Used, Laws),
    atomic_list_concat([Laws, Used], '\n', Used2),
    declarations(Used2, Decls),
    pack_kb_name(Pack, KB),
    format(atom(Text), '~w~n~nthe target language is: lps.~n~nthe maximum time is ~w.~n~n~w~nthe knowledge base ~w includes:~n~n~w~n~w~n~w',
           [Header, MaxT, Decls, KB, Laws, PolicyText, ScenText]).

pack_kb_name(Pack, KB) :-
    atomic_list_concat(Ws, '-', Pack), atomic_list_concat(Ws, ' ', KB).

max_time(Traces, T) :-
    findall(N, ( member(trace(_, _, R, _), Traces), length(R.actions, N) ), Ns),
    ( Ns == [] -> M = 0 ; max_list(Ns, M) ),
    T is 2 * M + 4.

header(Pack, Policies, NT, Header) :-
    length(Policies, NP),
    format(atom(Header),
'% The Ponens policies ~w, as a program of Logical English for LPS.
%
% Written by LE2\'s migration/ponens/ponens_twin.pl (the design notes ponens.md) from ~w
% Ponens policies, whose files are in sources/ (Ponens: github.com/imandra-ai/
% ponens, MIT licence), with ~w Ponens traces as its scenarios.
%
% Each step of a trace is an action of the session Ponens recorded. Each
% policy is a causal law that records a breach: at the step where the policy
% fails, when the step ends, or at the end of the session when the policy
% looks forward. Where a scenario has a comment above it, the comment is what
% Ponens\'s own evaluator (`ponens trace check --json`) says of the same
% policies on that trace.
%
% DISCLAIMER. This program was written by a translator from the policies of
% another system. It is provided "as is", without warranty of any kind,
% express or implied, including any warranty that it is accurate, complete or
% fit for a particular purpose. The translation may be wrong: check it against
% its source before relying on it. It is not legal, regulatory or other
% professional advice. Its authors accept no liability for any loss or damage
% arising from its use.', [Pack, NP, NT]).

%   The declarations of the templates the twin uses: an event when a
%   scenario states it, a fluent when a law or a rule reads it.
declarations(Used, Text) :-
    all_declarations(All),
    split_string(All, "\n", "", Lines),
    include(declaration_used(Used), Lines, Kept),
    atomic_list_concat(Kept, '\n', Text).

declaration_used(_, L) :- \+ sub_string(L, _, _, _, "; known as"), !.
declaration_used(Used, L) :-
    template_pattern(L, Pattern),
    re_match(Pattern/m, Used).

%   A template as a pattern of one line of the program: its words as they
%   are, each place some words, and after its last word something that ends
%   the sentence or the condition (so that `the policy P is broken` is not
%   taken for a use of `the policy P is broken at step S`).
template_pattern(L, Pattern) :-
    sub_string(L, Semi, _, _, ";"), sub_string(L, 0, Semi, _, T0),
    normalize_space(string(T), T0),
    split_string(T, "*", "", Parts),
    pattern_parts(Parts, 0, Ps),
    atomic_list_concat(Ps, P0),
    (   sub_string(T, _, 1, 0, "*")
    ->  Pattern = P0
    ;   string_concat(P0, "(?=[.,]|$| at (?:a|the) time| from \\d)", Pattern)
    ).

pattern_parts([], _, []).
pattern_parts([P|Ps], I, [Q|Qs]) :-
    (   I mod 2 =:= 0
    ->  re_replace("([.()\\[\\]?+*^$|\\\\])"/g, "\\\\\\1", P, Q)
    ;   Q = "[^\\n]+?"
    ),
    I1 is I + 1,
    pattern_parts(Ps, I1, Qs).

all_declarations(
'the events are:
    step *a step* is a *a kind*; known as step_is_a.
    step *a step* shows *a sign*; known as step_shows.
    step *a step* comes after step *an other step* in its chain; known as chain_link.
    step *a step* comes after step *an other step* on its target; known as target_link.
    step *a step* ends; known as step_ends.
    the trace shows *a sign*; known as trace_shows.
    item *an item* of *a collection* has *a value* as *a field*; known as item_field.
    artifact *an artifact* is made by step *a step*; known as made_by_event.
    step *a step* uses artifact *an artifact*; known as uses_event.
    artifact *an artifact* is a *a kind* artifact; known as artifact_kind_event.
    artifact *an artifact* derives from artifact *an other artifact*; known as derives_event.
    artifact *an artifact* is a verification goal for artifact *an other artifact*; known as goal_target_event.
    file *a file* is edited; known as edited_event.
    file *a file* is declared as modified; known as declared_event.
    the session ends; known as session_ends.

the fluents are:
    step *a step* was a *a kind*; known as was_a.
    step *a step* has shown *a sign*; known as has_shown.
    step *a step* is in the chain of step *an other step*; known as in_chain.
    step *a step* shares a target with step *an other step*; known as shares_target.
    step *a step* has ended; known as has_ended.
    the trace has shown *a sign*; known as trace_has_shown.
    item *an item* of *a collection* had *a value* as *a field*; known as item_had.
    artifact *an artifact* was made by step *a step*; known as made_by.
    step *a step* used artifact *an artifact*; known as used.
    artifact *an artifact* was a *a kind* artifact; known as artifact_kind.
    artifact *an artifact* derived from artifact *an other artifact*; known as derived.
    artifact *an artifact* was a verification goal for artifact *an other artifact*; known as goal_target.
    file *a file* was edited; known as edited.
    file *a file* was declared as modified; known as declared.
    step *a step* meets *a condition*; known as meets.
    step *a step* meets *a condition* with step *an other step*; known as meets_with.
    the trace meets *a condition*; known as trace_meets.
    artifact *an artifact* meets *a condition*; known as artifact_meets.
    artifact *an artifact* meets *a condition* with artifact *an other artifact*; known as artifact_meets_with.
    artifact *an artifact* meets *a condition* with step *a step*; known as artifact_meets_step.
    the policy *a policy* is broken at step *a step*; known as broken_at.
    the policy *a policy* is broken; known as broken.
').

recording_laws(
'% What a trace records, kept to the end of the session.
when step a step is a a kind
then step the step was a the kind.

when step a step shows a sign
then step the step has shown the sign.

when step a step comes after step an other step in its chain
then step the other step is in the chain of step the step.

when step a step comes after step an other step on its target
then step the other step shares a target with step the step.

when step a step ends
then step the step has ended.

when the trace shows a sign
then the trace has shown the sign.

when item an item of a collection has a value as a field
then item the item of the collection had the value as the field.

when artifact an artifact is made by step a step
then artifact the artifact was made by step the step.

when step a step uses artifact an artifact
then step the step used artifact the artifact.

when artifact an artifact is a a kind artifact
then artifact the artifact was a the kind artifact.

when artifact an artifact derives from artifact an other artifact
then artifact the artifact derived from artifact the other artifact.

when artifact an artifact is a verification goal for artifact an other artifact
then artifact the artifact was a verification goal for artifact the other artifact.

when file a file is edited
then file the file was edited.

when file a file is declared as modified
then file the file was declared as modified.
').

%   The recording laws whose event the scenarios state.
used_laws(All, Used, Laws) :-
    atomic_list_concat(Blocks, '\n\n', All),
    include(law_used(Used), Blocks, Kept),
    atomic_list_concat(Kept, '\n\n', Laws0),
    atom_concat(Laws0, '\n', Laws).

law_used(_, B) :- sub_atom(B, 0, _, _, '%'), !.
law_used(Used, B) :-
    law_probe(B, P), sub_atom(Used, _, _, _, P).

law_probe(B, P) :-
    member(P0-P, [ 'artifact an artifact is a a kind'-' artifact from ', 'is a a kind'-' is a ', 'shows a sign'-' shows "', 'in its chain'-' in its chain',
                   'on its target'-' on its target', 'step a step ends'-' ends from ',
                   'the trace shows'-'the trace shows', 'item an item'-'item ',
                   'is made by step'-' is made by step', 'uses artifact'-' uses artifact ',
                   'derives from'-' derives from ',
                   'verification goal for'-'verification goal for', 'is edited'-' is edited ',
                   'declared as modified'-' is declared as modified' ]),
    sub_atom(B, _, _, _, P0), !.

		 /*******************************
		 *	     one policy		*
		 *******************************/

%   The text of one policy (its comment, its conditions, its law) and its
%   ledger row.
policy_section(P, Text, Entry) :-
    policy_name(P, N), policy_id(P, Id),
    effective_formula(P, F),
    atom_string(Sev, P.get(severity, "error")),
    comment_lines(P, F, Comment),
    %   Ponens decides these by the policy's name; a policy file names a
    %   policy by its id (ponens_build.pl), where the gallery's own name is
    %   a title ("Generated Tests Require Decomposition").
    (   ( structural_policy(N) -> S = N ; structural_policy(Id) -> S = Id )
    ->  structural_laws(S, Id, LawText),
        Rules = [],
        Verdict = encoded, Mapping = 'decided by Ponens\'s code by name: the law follows that code',
        Note = ''
    ;   parse_formula(F, Ast),
        (   Ast = raw(_)
        ->  Rules = [], LawText = '% Ponens cannot evaluate this formula ("too complex for runtime evaluation"): no law.\n',
            Verdict = residue, Mapping = 'not read by Ponens\'s parser', Note = 'kept as a comment'
        ;   catch(compile_policy(Id, Ast, Rules, LawText), E, ( print_message(warning, E), fail ))
        ->  Verdict = encoded, mapping_of(Ast, Mapping), Note = ''
        ;   Rules = [], LawText = '% Not translated: the translator cannot write this formula yet.\n',
            Verdict = residue, Mapping = 'a construct the translator does not cover', Note = 'kept as a comment'
        )
    ),
    atomic_list_concat(Rules, '\n', RulesText0),
    ( RulesText0 == '' -> RulesText = '' ; atom_concat(RulesText0, '\n', RulesText) ),
    format(atom(Text), '~w~w~w', [Comment, RulesText, LawText]),
    Entry = _{element: Id, in_program: Id, kind: Sev, mapping: Mapping, note: Note, verdict: Verdict}.

comment_lines(P, F, Text) :-
    policy_id(P, Id), atom_string(Sev, P.get(severity, "")),
    atom_string(R, P.get(rationale, P.get(description, ""))),
    format(atom(Text), '% ~w (~w): ~w~n% ~w~n', [Id, Sev, F, R]).

mapping_of(g(B), M) :- !, ( looks_forward(B) -> M = 'G(φ): a breach at each step where φ fails, found when the session ends'
                         ; M = 'G(φ): a breach at each step where φ fails, found when the step ends' ).
mapping_of(_, 'a breach of the whole trace, found when the session ends').

looks_forward(F) :- sub_term(S, F), compound(S), functor(S, Op, _), memberchk(Op, [f, g, x, u]), !.

		 /*******************************
		 *	   compiling a formula	*
		 *******************************/

%   The rules of the named conditions and the law, as LE text.
%   Conditions are named after what they say ("an earlier step shows tested
%   and shows validated"), made unique within the program.
compile_policy(Id, Ast, Rules, Law) :-
    nb_setval(ponens_rules, []),
    (   Ast = g(B)
    ->  violation(B, the_step, Lits),
        and_lines(Lits, Body),
        (   looks_forward(B)
        ->  format(atom(Law), 'when the session ends~n    and step a step has ended~n~w~nthen the policy ~w is broken at step the step.~n', [Body, Id])
        ;   format(atom(Law), 'when step a step ends~n~w~nthen the policy ~w is broken at step the step.~n', [Body, Id])
        )
    ;   trace_violation(Ast, Lits),
        and_lines(Lits, Body),
        format(atom(Law), 'when the session ends~n~w~nthen the policy ~w is broken.~n', [Body, Id])
    ),
    nb_getval(ponens_rules, Rules0), reverse(Rules0, Rules).

%   The step variables of one rule: the subject, a second step, a third.
var_phrase(the_step, indef, 'a step').
var_phrase(the_step, def, 'the step').
var_phrase(the_second, indef, 'a second step').
var_phrase(the_second, def, 'the second step').
var_phrase(the_third, indef, 'a third step').
var_phrase(the_third, def, 'the third step').
var_phrase(the_other, def, 'the other step').
var_phrase(agg, def, 'S').

def(V, P) :- var_phrase(V, def, P).

%   violation(+F, +V, -Lits): F is false at step V (in the law, V is `the
%   step` of the law's `step a step ends`).
violation(implies(T, C), V, Lits) :- !, cond(T, V, L1), neg(C, V, L2), append(L1, L2, Lits).
violation(not(X), V, Lits) :- !, cond(X, V, Lits).
violation(X, V, Lits) :- neg(X, V, Lits).

%   cond(+F, +V, -Lits): the literals whose conjunction is F at step V.
cond(and(A, B), V, Lits) :- !, cond(A, V, L1), cond(B, V, L2), append(L1, L2, Lits).
cond(F, V, [L]) :- atomic_literal(F, V, L), !.
cond(not(X), V, Lits) :- !, neg(X, V, Lits).
cond(h(X), V, [L]) :- !, name_of(p(not(X)), N), def(V, P), format(atom(L), 'it is not the case that step ~w meets "~w"', [P, N]).
cond(g(X), V, [L]) :- !, name_of(f(not(X)), N), def(V, P), format(atom(L), 'it is not the case that step ~w meets "~w"', [P, N]).
cond(F, V, [L]) :- name_of(F, N), def(V, P), format(atom(L), 'step ~w meets "~w"', [P, N]).

%   neg(+F, +V, -Lits): F is false at step V.
neg(not(X), V, Lits) :- !, cond(X, V, Lits).
neg(h(X), V, [L]) :- !, name_of(p(not(X)), N), def(V, P), format(atom(L), 'step ~w meets "~w"', [P, N]).
neg(g(X), V, [L]) :- !, name_of(f(not(X)), N), def(V, P), format(atom(L), 'step ~w meets "~w"', [P, N]).
neg(F, V, [L]) :- atomic_literal(F, V, A), !, format(atom(L), 'it is not the case that ~w', [A]).
neg(F, V, [L]) :- name_of(F, N), def(V, P), format(atom(L), 'it is not the case that step ~w meets "~w"', [P, N]).

%   An atom at step V.
atomic_literal(atom(K), V, L) :- kind_atom(K), !, def(V, P), kind_word(K, W), format(atom(L), 'step ~w was a ~w', [P, W]).
atomic_literal(start_event, _, 'the trace has shown "start event"') :- !.
atomic_literal(end_event, _, 'the trace has shown "end event"') :- !.
atomic_literal(F, V, L) :- ponens_atomic(F), sign(F, S), def(V, P), format(atom(L), 'step ~w has shown "~w"', [P, S]).

ponens_atomic(atom(_)).
ponens_atomic(atom_args(_, _)).
ponens_atomic(field_ne_empty(_)).
ponens_atomic(func(_, _)).

%   A kind as a word of a sentence. A word all in capitals (`HLR`, `LLR`,
%   DO-178C's requirement levels) is a variable in Logical English, which
%   would give the artifact every kind: such a kind is quoted.
kind_word(K, W) :-
    (   sub_atom(K, _, 1, _, C), char_type(C, lower) -> W = K
    ;   format(atom(W), '"~w"', [K])
    ).

%   A capitalised atom names a kind of action or artifact.
kind_atom(K) :- sub_atom(K, 0, 1, _, C), char_type(C, upper).

%   The sign a step shows for an atom: a lower-case atom's words
%   (`suitability_assessed` → "suitability assessed"); any other node its
%   Ponens text (`VerificationResult(proved ∨ sat)`).
sign(atom(N), S) :- !, atomic_list_concat(Ws, '_', N), atomic_list_concat(Ws, ' ', S).
sign(start_event, 'start event') :- !.
sign(end_event, 'end event') :- !.
sign(F, S) :- formula_text(F, S).

%   The name of a condition, its rules written the first time.
name_of(F, N) :-
    nb_getval(ponens_names, Names),
    (   memberchk(F0-N0, Names), F0 =@= F
    ->  N = N0
    ;   describe(F, D0), unique_name(D0, Names, N),
        nb_setval(ponens_names, [F-N|Names]),
        define(F, N)
    ).

unique_name(D0, Names, N) :-
    (   \+ memberchk(_-D0, Names) -> N = D0
    ;   between(2, inf, K), format(atom(N), '~w (~w)', [D0, K]), \+ memberchk(_-N, Names) -> true
    ).

add_rule(R) :- nb_getval(ponens_rules, Rs), nb_setval(ponens_rules, [R|Rs]).

%   The rules of a named condition. `at the time` on every fluent of a rule.
define(or(A, B), N) :- !, rule_for(N, A), rule_for(N, B).
define(implies(A, B), N) :- !, rule_for(N, not(A)), rule_for(N, B).
define(and(A, B), N) :- !, cond(and(A, B), the_step, Ls), add_step_rule(N, Ls).
define(not(X), N) :- !, neg(X, the_step, Ls), add_step_rule(N, Ls).
define(p(X), N) :- !,
    cond(X, the_second, Ls),
    add_step_rule(N, ['step a second step has ended', 'the second step < the step'|Ls]).
define(f(X), N) :- !,
    cond(X, the_second, Ls),
    add_step_rule(N, ['step a second step has ended', 'the second step >= the step'|Ls]).
define(p_chain(X), N) :- !,
    cond(X, the_second, Ls),
    add_step_rule(N, ['step a second step is in the chain of step the step'|Ls]).
define(p_target(X), N) :- !,
    cond(X, the_second, Ls),
    add_step_rule(N, ['step a second step shares a target with step the step'|Ls]).
define(s_last(L, R), N) :- !,
    %  ∃ b < S: L(b), and no c with b ≤ c < S where R(c)
    cond(L, the_second, Ls),
    between_name(R, ge, Nb),
    format(atom(Gap), 'it is not the case that step the second step meets "~w" with step the step', [Nb]),
    append(['step a second step has ended', 'the second step < the step'|Ls], [Gap], Body),
    add_step_rule(N, Body).
define(x(X), N) :- !,
    %  the next step: the first later step, and no step between
    cond(X, the_second, Ls),
    between_name(atom(action), gt, Nb),
    format(atom(Gap), 'it is not the case that step the step meets "~w" with step the second step', [Nb]),
    append(['step a second step has ended', 'the second step > the step'|Ls], [Gap], Body),
    add_step_rule(N, Body).
define(u(A, B), N) :- !,
    %  ∃ k ≥ S: B(k), and no j with S ≤ j < k where A fails
    cond(B, the_second, Ls),
    between_name(not(A), ge_from, Nb),
    format(atom(Gap), 'it is not the case that step the step meets "~w" with step the second step', [Nb]),
    append(['step a second step has ended', 'the second step >= the step'|Ls], [Gap], Body),
    add_step_rule(N, Body).
define(s(A, B), N) :- !,
    %  ∃ k ≤ S: B(k), and no j with k < j ≤ S where A fails
    cond(B, the_second, Ls),
    between_name(not(A), gt_to, Nb),
    format(atom(Gap), 'it is not the case that step the second step meets "~w" with step the step', [Nb]),
    append(['step a second step has ended', 'the second step =< the step'|Ls], [Gap], Body),
    add_step_rule(N, Body).
define(F, N) :-
    cond(F, the_step, Ls),
    %   a condition the translator has no words for would be named after
    %   itself, and its rule would call itself for ever
    format(atom(Self), '"~w"', [N]),
    (   member(L, Ls), sub_atom(L, _, _, _, Self)
    ->  throw(error(domain_error(ponens_condition, F), _))
    ;   add_step_rule(N, Ls)
    ).

rule_for(N, F) :- cond(F, the_step, Ls), add_step_rule(N, Ls).

add_step_rule(N, Ls) :-
    maplist(at_the_time, Ls, Ls1),
    conj_text(Ls1, '    ', Body),
    format(atom(R), 'step a step meets "~w" at a time if~n~w.~n', [N, Body]),
    add_rule(R).

%   A condition between two steps (`step a step meets "N" with step an
%   other step`): a third step lies between them and meets F. Kind ge: the
%   step ≤ third < the other step; gt: the step < third < the other step;
%   ge_from: the step ≤ third < the other; gt_to: the step < third ≤ the
%   other step.
between_name(F, Kind, N) :-
    nb_getval(ponens_names, Names),
    Key = between(Kind, F),
    (   memberchk(K0-N0, Names), K0 =@= Key
    ->  N = N0
    ;   describe(F, D), between_words(Kind, W), format(atom(D1), 'a step ~w ~w', [W, D]),
        unique_name(D1, Names, N),
        nb_setval(ponens_names, [Key-N|Names]),
        cond(F, the_third, Ls),
        bounds(Kind, B1, B2),
        maplist(at_the_time, ['step a third step has ended', B1, B2|Ls], Ls1),
        conj_text(Ls1, '    ', Body),
        format(atom(R), 'step a step meets "~w" with step an other step at a time if~n~w.~n', [N, Body]),
        add_rule(R)
    ).

between_words(ge, 'from it to the other step').
between_words(gt, 'strictly between it and the other step').
between_words(ge_from, 'from it to the other step').
between_words(gt_to, 'after it, up to the other step').

bounds(ge, 'the third step >= the step', 'the third step < the other step').
bounds(gt, 'the third step > the step', 'the third step < the other step').
bounds(ge_from, 'the third step >= the step', 'the third step < the other step').
bounds(gt_to, 'the third step > the step', 'the third step =< the other step').

%   `at the time` after every fluent of a rule's body (not after a comparison).
at_the_time(L0, L) :-
    (   ( sub_atom(L0, _, _, _, ' < ') ; sub_atom(L0, _, _, _, ' > ') ; sub_atom(L0, _, _, _, ' >= ')
        ; sub_atom(L0, _, _, _, ' =< ') )
    ->  L = L0
    ;   atom_concat(L0, ' at the time', L)
    ).

%   A rule's body: its conditions joined by `and`.
conj_text([L|Ls], Ind, T) :-
    format(atom(First), '~w~w', [Ind, L]),
    maplist(and_line(Ind), Ls, Rest),
    atomic_list_concat([First|Rest], '\n', T).

and_line(Ind, X, Y) :- format(atom(Y), '~wand ~w', [Ind, X]).

%   A law's body: every condition after the law's first line (`when step a
%   step ends`, `when the session ends`) starts with `and`.
and_lines(Ls, T) :-
    maplist([L, X]>>format(atom(X), '    and ~w', [L]), Ls, Xs),
    atomic_list_concat(Xs, '\n', T).

		 /*******************************
		 *	   trace-level policies	*
		 *******************************/

%   A policy that is not G(φ): false of the trace.
trace_violation(implies(A, B), Lits) :- !, tcond(A, L1), tneg(B, L2), append(L1, L2, Lits).
trace_violation(not(X), Lits) :- !, tcond(X, Lits).
trace_violation(X, Lits) :- tneg(X, Lits).

tcond(and(A, B), Lits) :- !, tcond(A, L1), tcond(B, L2), append(L1, L2, Lits).
tcond(start_event, ['the trace has shown "start event"']) :- !.
tcond(end_event, ['the trace has shown "end event"']) :- !.
tcond(not(X), Lits) :- !, tneg(X, Lits).
tcond(F, [L]) :- tname_of(F, N), format(atom(L), 'the trace meets "~w"', [N]).

tneg(not(X), Lits) :- !, tcond(X, Lits).
tneg(start_event, ['it is not the case that the trace has shown "start event"']) :- !.
tneg(end_event, ['it is not the case that the trace has shown "end event"']) :- !.
tneg(F, [L]) :- tname_of(F, N), format(atom(L), 'it is not the case that the trace meets "~w"', [N]).

tname_of(F, N) :-
    nb_getval(ponens_names, Names),
    Key = trace(F),
    (   memberchk(K0-N0, Names), K0 =@= Key
    ->  N = N0
    ;   tdescribe(F, D), unique_name(D, Names, N),
        nb_setval(ponens_names, [Key-N|Names]),
        tdefine(F, N)
    ).

add_trace_rule(N, Ls) :-
    maplist(at_the_time, Ls, Ls1),
    conj_text(Ls1, '    ', Body),
    format(atom(R), 'the trace meets "~w" at a time if~n~w.~n', [N, Body]),
    add_rule(R).

%   With no current step, Ponens reads F and G over every action, P as
%   false and H as true, an atom as false (but start_event and end_event).
tdefine(f(X), N) :- !, cond(X, the_step, Ls), add_trace_rule(N, ['step a step has ended'|Ls]).
tdefine(g(X), N) :- !,
    name_of(not(X), Nn),
    tname_of_exists(Nn, Ne),
    format(atom(L2), 'it is not the case that the trace meets "~w"', [Ne]),
    add_trace_rule(N, [L2]).
tdefine(or(A, B), N) :- !, tcond(A, L1), add_trace_rule(N, L1), tcond(B, L2), add_trace_rule(N, L2).
tdefine(implies(A, B), N) :- !, tneg(A, L1), add_trace_rule(N, L1), tcond(B, L2), add_trace_rule(N, L2).
tdefine(and(A, B), N) :- !, tcond(and(A, B), Ls), add_trace_rule(N, Ls).
tdefine(count(B, Op, K), N) :- !,
    cond(B, agg, Ls0), maplist(at_the_time, ['step S has ended'|Ls0], Ls),
    conj_text(Ls, '        ', Inner),
    cmp_word(Op, W),
    format(atom(R), 'the trace meets "~w" at a time if~n    a number is the count of each S such that~n~w~n    and the number ~w ~w.~n', [N, Inner, W, K]),
    add_rule(R).
tdefine(forall(V, Set, Body), N) :- !,
    %  ∀ x ∈ C . φ: no item of C fails φ
    format(atom(Nf), 'some item of ~w fails ~w', [Set, N]),
    item_neg(Body, V, Set, Ls),
    format(atom(Exists), 'item an item of ~w had a value as a field', [Set]),
    maplist(at_the_time, [Exists|Ls], Ls1), conj_text(Ls1, '    ', B1),
    format(atom(R1), 'the trace meets "~w" at a time if~n~w.~n', [Nf, B1]),
    add_rule(R1),
    format(atom(L), 'it is not the case that the trace meets "~w"', [Nf]),
    add_trace_rule(N, [L]).
tdefine(p(_), N) :- !, add_trace_rule(N, ['the trace has shown "nothing"']).
tdefine(h(_), N) :- !, add_trace_rule(N, ['it is not the case that the trace has shown "nothing"']).
tdefine(F, N) :- ponens_atomic(F), !, sign(F, S), format(atom(L), 'the trace has shown "~w"', [S]), add_trace_rule(N, [L]).

%   "Some step meets the condition named Nn": its name is made of Nn (a
%   name in a name would bring its quotes), and `the step` that has ended is
%   the one that meets it.
tname_of_exists(Nn, N) :-
    nb_getval(ponens_names, Names),
    Key = exists(Nn),
    (   memberchk(K0-N0, Names), K0 == Key
    ->  N = N0
    ;   atom_concat('some step: ', Nn, D), unique_name(D, Names, N),
        nb_setval(ponens_names, [Key-N|Names]),
        format(atom(L), 'step the step meets "~w"', [Nn]),
        add_trace_rule(N, ['step a step has ended', L])
    ).

add_rule_raw(N, Body) :-
    format(atom(R), 'the trace meets "~w" at a time if~n    ~w.~n', [N, Body]),
    add_rule(R).

cmp_word('<=', '=<').
cmp_word('>=', '>=').
cmp_word('<', '<').
cmp_word('>', '>').
cmp_word('=', '=').
cmp_word('!=', 'is different from').

%   An item of a collection fails φ (the item is `the item`).
item_neg(compare(field(_, F), '=', atom(X)), _, Set, [L]) :- !,
    downcase_atom(X, Xl),
    format(atom(L), 'it is not the case that item the item of ~w had "~w" as ~w', [Set, Xl, F]).
item_neg(compare(field(_, F), '!=', atom('EMPTY')), _, Set, [L]) :- !,
    format(atom(L), 'it is not the case that item the item of ~w had a value as ~w', [Set, F]).
item_neg(implies(A, B), V, Set, Ls) :- !,
    item_cond(A, V, Set, L1), item_neg(B, V, Set, L2), append(L1, L2, Ls).

item_cond(compare(field(_, F), '=', atom(X)), _, Set, [L]) :- !,
    downcase_atom(X, Xl),
    format(atom(L), 'item the item of ~w had "~w" as ~w', [Set, Xl, F]).

		 /*******************************
		 *	    what a name says	*
		 *******************************/

describe(atom(K), D) :- kind_atom(K), !, format(atom(D), 'is a ~w', [K]).
describe(F, D) :- ponens_atomic(F), !, sign(F, S), format(atom(D), 'shows ~w', [S]).
describe(start_event, 'the trace has started') :- !.
describe(end_event, 'the trace has ended') :- !.
describe(and(A, B), D) :- !, describe(A, DA), describe(B, DB), format(atom(D), '~w and ~w', [DA, DB]).
describe(or(A, B), D) :- !, describe(A, DA), describe(B, DB), format(atom(D), '~w or ~w', [DA, DB]).
describe(implies(A, B), D) :- !, describe(A, DA), describe(B, DB), format(atom(D), 'if it ~w then it ~w', [DA, DB]).
describe(not(A), D) :- !, describe(A, DA), format(atom(D), 'not (~w)', [DA]).
describe(p(A), D) :- !, describe(A, DA), format(atom(D), 'an earlier step ~w', [DA]).
describe(h(A), D) :- !, describe(A, DA), format(atom(D), 'every earlier step ~w', [DA]).
describe(f(A), D) :- !, describe(A, DA), format(atom(D), 'it or a later step ~w', [DA]).
describe(g(A), D) :- !, describe(A, DA), format(atom(D), 'it and every later step ~w', [DA]).
describe(x(A), D) :- !, describe(A, DA), format(atom(D), 'the next step ~w', [DA]).
describe(p_chain(A), D) :- !, describe(A, DA), format(atom(D), 'an earlier step in its chain ~w', [DA]).
describe(p_target(A), D) :- !, describe(A, DA), format(atom(D), 'an earlier step on its target ~w', [DA]).
describe(s_last(A, B), D) :- !, describe(A, DA), describe(B, DB), format(atom(D), 'an earlier step ~w since the last step that ~w', [DA, DB]).
describe(u(A, B), D) :- !, describe(A, DA), describe(B, DB), format(atom(D), 'it ~w until a step that ~w', [DA, DB]).
describe(s(A, B), D) :- !, describe(A, DA), describe(B, DB), format(atom(D), 'it ~w since a step that ~w', [DA, DB]).
describe(F, D) :- formula_text(F, D).

tdescribe(f(A), D) :- !, describe(A, DA), format(atom(D), 'some step ~w', [DA]).
tdescribe(g(A), D) :- !, describe(A, DA), format(atom(D), 'every step ~w', [DA]).
tdescribe(count(B, Op, K), D) :- !, describe(B, DB), cmp_text_word(Op, W), format(atom(D), 'the number of steps that ~w is ~w ~w', [DB, W, K]).
tdescribe(F, D) :- describe(F, D0), format(atom(D), 'the trace: ~w', [D0]).

cmp_text_word('<=', 'at most').
cmp_text_word('>=', 'at least').
cmp_text_word('<', 'less than').
cmp_text_word('>', 'more than').
cmp_text_word('=', 'exactly').
cmp_text_word('!=', 'other than').

		 /*******************************
		 *	 the structural policies	*
		 *******************************/

%   trace.py evaluate_structural, policy by policy.
structural_laws(data_flow_integrity, Id, T) :- !,
    format(atom(T),
'artifact an artifact meets "made before" with step a step at a time if
    artifact the artifact was made by step an other step at the time
    and the other step < the step.

step a step meets "uses an artifact made at or after it, or by no step" at a time if
    step the step used artifact an artifact at the time
    and it is not the case that artifact the artifact meets "made before" with step the step at the time.

when the session ends
    and step a step meets "uses an artifact made at or after it, or by no step"
then the policy ~w is broken.
', [Id]).
structural_laws(goals_reference_valid_artifacts, Id, T) :- !,
    format(atom(T),
'when the session ends
    and artifact an artifact was a verification goal for artifact an other artifact
    and it is not the case that artifact the other artifact was a IMLModel artifact
then the policy ~w is broken.
', [Id]).
structural_laws(files_modified_consistent, Id, T) :- !,
    format(atom(T),
'when the session ends
    and file a file was edited
    and it is not the case that file the file was declared as modified
then the policy ~w is broken.

when the session ends
    and file a file was declared as modified
    and it is not the case that file the file was edited
then the policy ~w is broken.
', [Id, Id]).
structural_laws(generated_tests_require_decomposition, Id, T) :- !,
    format(atom(T),
'artifact an artifact meets "descends from" with artifact an other artifact at a time if
    artifact the artifact derived from artifact the other artifact at the time.

artifact an artifact meets "descends from" with artifact an other artifact at a time if
    artifact the artifact derived from artifact a third artifact at the time
    and artifact the third artifact meets "descends from" with artifact the other artifact at the time.

artifact an artifact meets "has a decomposition among its ancestors" at a time if
    artifact the artifact meets "descends from" with artifact an other artifact at the time
    and artifact the other artifact was a Decomposition artifact at the time.

artifact an artifact meets "has a decomposition among its ancestors" at a time if
    artifact the artifact meets "descends from" with artifact an other artifact at the time
    and artifact the other artifact was a Decomposition_Art artifact at the time.

when the session ends
    and artifact an artifact was a GeneratedTests artifact
    and it is not the case that artifact the artifact meets "has a decomposition among its ancestors"
then the policy ~w is broken.
', [Id]).
structural_laws(no_open_critical_residuals, Id, T) :- !,
    format(atom(T),
'when the session ends
    and item a residual of residuals had "critical" as severity
    and item the residual of residuals had "open" as status
then the policy ~w is broken.
', [Id]).
structural_laws(high_severity_residuals_acknowledged_before_commit, Id, T) :- !,
    format(atom(T),
'when the session ends
    and the trace has shown "a commit"
    and item a residual of residuals had "critical" as severity
    and item the residual of residuals had "open" as status
then the policy ~w is broken.

when the session ends
    and the trace has shown "a commit"
    and item a residual of residuals had "high" as severity
    and item the residual of residuals had "open" as status
then the policy ~w is broken.
', [Id, Id]).
structural_laws(unverified_residuals_have_suggested_check, Id, T) :- !,
    format(atom(T),
'when the session ends
    and item a residual of residuals had "unverified" as kind
    and it is not the case that item the residual of residuals had "given" as suggested_check
then the policy ~w is broken.
', [Id]).
structural_laws(assumptions_are_located, Id, T) :- !,
    format(atom(T),
'when the session ends
    and item a residual of residuals had "assumption" as kind
    and it is not the case that item the residual of residuals had "yes" as located
then the policy ~w is broken.
', [Id]).

		 /*******************************
		 *	      scenarios		*
		 *******************************/

%   One scenario per trace: the setup facts in cycle 1, the k-th action's
%   facts in cycle 2k, its end in cycle 2k+1, the end of the session after.
scenario_text(trace(Name, _File, R, Verdicts), Text) :-
    verdict_comment(Verdicts, VC),
    setup_lines(R, Setup),
    maplist(with_links(R), R.actions, Actions0),
    msort_actions(Actions0, Actions),
    numlist_actions(Actions, 1, ALines),
    length(Actions, N), TEnd is 2 * N + 2, TEnd1 is TEnd + 1,
    format(atom(EndLine), '    the session ends from ~w to ~w.', [TEnd, TEnd1]),
    append([Setup, ALines, [EndLine]], Lines),
    atomic_list_concat(Lines, '\n', Body),
    format(atom(Text), 'scenario ~w is:~n~w~n~w~n', [Name, VC, Body]).

%   The earlier steps in an action's chain and on its target, on the action.
with_links(R, A0, A) :-
    Id = A0.id,
    findall(B, member([B, Id], R.get(chain, [])), Cs),
    findall(B, member([B, Id], R.get(target, [])), Ts),
    A = A0.put(_{chain_from: Cs, target_from: Ts}).

msort_actions(As, Sorted) :-
    map_list_to_pairs(action_id, As, Ps), keysort(Ps, S), pairs_values(S, Sorted).

action_id(A, K) :- get_dict(id, A, K).

numlist_actions([], _, []).
numlist_actions([A|As], K, Lines) :-
    T is 2 * K, T1 is T + 1, T2 is T + 2,
    Id = A.id,
    findall(L, ( member(S0, A.true), atom_string(S, S0), action_line(Id, S, T, T1, L) ), L1),
    findall(L, ( member(Link, A.get(chain_from, [])), format(atom(L), '    step ~w comes after step ~w in its chain from ~w to ~w.', [Id, Link, T, T1]) ), L2),
    findall(L, ( member(Link, A.get(target_from, [])), format(atom(L), '    step ~w comes after step ~w on its target from ~w to ~w.', [Id, Link, T, T1]) ), L3),
    findall(L, ( member(I0, A.get(inputs, [])), le_constant(I0, I), format(atom(L), '    step ~w uses artifact ~w from ~w to ~w.', [Id, I, T, T1]) ), L4),
    format(atom(End), '    step ~w ends from ~w to ~w.', [Id, T1, T2]),
    append([L1, L2, L3, L4, [End]], Ls),
    K1 is K + 1,
    numlist_actions(As, K1, Rest),
    append(Ls, Rest, Lines).

%   An atom that holds at the action: a kind (`step 3 is a Deploy`) or a sign.
action_line(Id, S, T, T1, L) :-
    (   kind_text(S)
    ->  kind_word(S, W), format(atom(L), '    step ~w is a ~w from ~w to ~w.', [Id, W, T, T1])
    ;   S == start_event -> fail
    ;   S == end_event -> fail
    ;   parse_formula(S, F), sign(F, Sg),
        format(atom(L), '    step ~w shows "~w" from ~w to ~w.', [Id, Sg, T, T1])
    ).

kind_text(S) :- sub_atom(S, 0, 1, _, C), char_type(C, upper), \+ sub_atom(S, _, _, _, '('), \+ sub_atom(S, _, _, _, ' ').

%   An id as a constant of the program: as it is when it is one lower-case
%   word, quoted otherwise (`"art-1"`, `"src/pay.py"`).
le_constant(X0, X) :- ( string(X0) -> atom_string(X1, X0) ; X1 = X0 ),
    (   number(X1) -> X = X1
    ;   atom(X1), atom_codes(X1, [C|Cs]), code_type(C, lower),
        forall(member(D, Cs), ( code_type(D, alnum) ; D == 0'_ ))
    ->  X = X1
    ;   format(atom(X), '"~w"', [X1])
    ).

setup_lines(R, Lines) :-
    findall(L, ( member(S0, R.trace_true), atom_string(S, S0), parse_formula(S, F), sign(F, Sg),
                 format(atom(L), '    the trace shows "~w" from 1 to 2.', [Sg]) ), L1),
    St = R.structural,
    ( St.get(has_commit, false) == true -> L1b = ['    the trace shows "a commit" from 1 to 2.'] ; L1b = [] ),
    findall(L, ( member([A0, P], St.get(made_by, [])), le_constant(A0, A), format(atom(L), '    artifact ~w is made by step ~w from 1 to 2.', [A, P]) ), L2),
    findall(L, ( member(Art, St.get(artifacts, [])), Art.get(id) \== null, le_constant(Art.id, A),
                 member(K0, [Art.get(type), Art.get(raw_type)]), K0 \== null, atom_string(K, K0), kind_word(K, W),
                 format(atom(L), '    artifact ~w is a ~w artifact from 1 to 2.', [A, W]) ), L3a),
    list_to_set(L3a, L3),
    findall(L, ( member(Art, St.get(artifacts, [])), Art.get(id) \== null, le_constant(Art.id, A),
                 member(B0, Art.get(derived_from, [])), le_constant(B0, B),
                 format(atom(L), '    artifact ~w derives from artifact ~w from 1 to 2.', [A, B]) ), L4),
    findall(L, ( member(Art, St.get(artifacts, [])), Art.get(id) \== null, le_constant(Art.id, A),
                 Art.get(raw_type) == "VerificationGoal", G0 = Art.get(target_artifact_id), G0 \== null, G0 \== "",
                 le_constant(G0, G),
                 format(atom(L), '    artifact ~w is a verification goal for artifact ~w from 1 to 2.', [A, G]) ), L5),
    findall(L, ( member(F0, St.get(edited_files, [])), format(atom(L), '    file "~w" is edited from 1 to 2.', [F0]) ), L6),
    findall(L, ( member(F0, St.get(declared_files, [])), format(atom(L), '    file "~w" is declared as modified from 1 to 2.', [F0]) ), L7),
    findall(L, ( get_dict(C, R.collections, Items), member(It, Items), le_constant(It.id, I),
                 dict_pairs(It.fields, _, FPs), member(Fld-V, FPs), item_value(V, VT),
                 format(atom(L), '    item ~w of ~w has ~w as ~w from 1 to 2.', [I, C, VT, Fld]) ), L8),
    append([L1, L1b, L2, L3, L4, L5, L6, L7, L8], Lines).

item_value(V, T) :- string(V), !, format(atom(T), '"~w"', [V]).
item_value(V, T) :- atom(V), V \== null, !, format(atom(T), '"~w"', [V]).
item_value(V, V) :- number(V), !.

verdict_comment(Verdicts, Text) :-
    findall(L, ( member(V, Verdicts), atom_string(P, V.policy_id), atom_string(S, V.status),
                 S \== passed,
                 (   Ids = V.get(violating_action_ids), is_list(Ids), Ids \== []
                 ->  atomic_list_concat(Ids, ', ', IdT), format(atom(L), '    %     ~w: ~w at step ~w', [P, S, IdT])
                 ;   format(atom(L), '    %     ~w: ~w', [P, S])
                 ) ), Ls),
    (   Ls == []
    ->  Text = '    % Ponens: every policy of the pack passes on this trace.'
    ;   atomic_list_concat(['    % Ponens (`ponens trace check --json`):'|Ls], '\n', Text)
    ).

/** <module> The Ponens policy language: text → formula, and back

    A port of Ponens's own reader (`cli/ponens/policy_compiler.py` of
    github.com/imandra-ai/ponens, commit 2f91978: `tokenize/1` and the
    recursive-descent `Parser`), construct by construct, so that a formula
    means here what it means to Ponens's evaluator. Where Ponens's parser
    gives up (a `ParseError`, which makes the policy `RawStructural`, "too
    complex for runtime evaluation"), this one answers raw(Text) the same
    way. The word lists below are that file's own lists.

    Ponens is under the MIT licence. Its copyright notice and the licence
    text, which that licence asks to be kept with a copy or a port of its
    code, are in the file PONENS_LICENSE of this folder.

    The formula, as a term:

        g(F) f(F) x(F) p(F) h(F) p_target(F) p_chain(F)      unary temporal
        u(A,B) s(A,B) s_last(A,B)                            binary temporal
        implies(A,B) and(A,B) or(A,B) not(A)
        atom(Name)                                           Name an atom
        atom_args(Name, [Arg])                               VerificationResult(proved ∨ sat)
        field_ne_empty(Field)                                rationale ≠ ∅
        func(Name, Arg)                                      ref_model(x), produced_by(x), …
        start_event  end_event
        count(F, Op, N)                                      count(ToolCall) ≤ 20
        forall(Var, Set, F)  exists(Var, Set, F)  exists_unique(Var, Set, F)
        compare(field(Var, Field), Op, Value)                r.severity = Critical
        field(Var, Field)
        member(atom(Name), Set)  equals(atom(Name), Set)  set(Text)  ancestors(Field)
        raw(Text)                                            what Ponens cannot evaluate

    formula_text/2 writes a formula back in Ponens's unicode surface, with
    the brackets the parser needs and no more (the way back).
*/

:- module(ponens_formula, [
    parse_formula/2,          % +Text, -Formula
    formula_text/2,           % +Formula, -Text
    formula_atoms/2,          % +Formula, -AtomicNodes  (the nodes the trace reader decides)
    action_type/1,            % ?Name
    artifact_type/1,          % ?Name
    predicate_name/1          % ?Name
]).

:- use_module(library(lists)).
:- use_module(library(apply)).

		 /*******************************
		 *	   Ponens's word lists	*
		 *******************************/

%   policy_compiler.py, ACTION_TYPES, ARTIFACT_TYPES, PREDICATES, FIELDS,
%   EVIDENCE_PREDICATES, LABEL_PREDICATES, SYMBOL_PREDICATES.
action_type(T) :- memberchk(T, [
    'EditFile', 'ReadFile', 'ReadDocumentation', 'SearchCode', 'AnalyzeCode',
    'CreateFile', 'DeleteFile', 'RenameFile',
    'RunTests', 'TypeCheck', 'Lint', 'ManualVerification',
    'RunCommand', 'ExploreDirectory',
    'GitCommit', 'GitStatus', 'GitDiff', 'GitPush',
    'Deploy',
    'ToolCall', 'Retrieve', 'Compute', 'Draft', 'Release',
    'Decision', 'Output', 'Incident',
    'Recommendation', 'Distribution',
    'Plan', 'SystemRequirement', 'HLR', 'LLR', 'SourceCode', 'Test',
    'Change', 'ProblemReport', 'DerivedRequirement', 'CoverageAnalysis',
    'AccomplishmentSummary',
    'StaticAnalysis', 'Deviation', 'ComplianceSummary', 'Directive',
    'Finding',
    'AskUser', 'ReportProgress', 'Explain',
    'FormulatePlan', 'DecomposeTask', 'EstimateImpact',
    'Formalize', 'DefineVG', 'DefineVerificationGoal', 'Verify',
    'Decompose', 'StateSpaceAnalysis', 'ConformanceCheck', 'CoSimulate',
    'GenerateTests',
    'Observe', 'Analyze', 'Judge', 'Attest']).

artifact_type(T) :- memberchk(T, [
    'SourceCode', 'Documentation', 'SearchResults', 'AnalysisNote', 'Plan',
    'Formalization', 'IMLModel', 'VerificationGoal', 'VerificationResult',
    'Decomposition', 'GeneratedTests',
    'FormalModel', 'StateSpaceAnalysisResult', 'ConformanceResult',
    'CoSimulationResult', 'ReproductionBundle',
    'CommandResult', 'Diff', 'Commit', 'UserApproval', 'UserInstruction',
    'Residual', 'ResidualResolution', 'GoalAmendment', 'Observation']).

predicate_name(P) :- memberchk(P, [
    completed, failed, proved, refuted, sat, unknown,
    action, gateway, reasoning, activity,
    start_event, end_event, high_stakes_path,
    passed, partial, matched, mismatched,
    goal_declared, named_by_goal, signature_change, search_confirmed,
    current, ci_confirmed,
    established, evidence_current, evidence_ci_confirmed]).

field_name(F) :- memberchk(F, [rationale, target_artifact_id, files_modified,
    inputs, outputs, target, ancestors, derived_from, ref_model]).

evidence_predicate(P) :- memberchk(P, [strength_at_least, oracle_type, produced_by, conforms_to]).
label_predicate(labeled).
symbol_predicate(established_as).

		 /*******************************
		 *	      tokenizer		*
		 *******************************/

%   tok(Kind, Value): ident, op, lparen, rparen, lbrace, rbrace, dot, comma,
%   pipe, number, eof. Ops are Ponens's ASCII names: '->', '&&', '||', '!',
%   'FORALL', 'EXISTS', 'EXISTS_UNIQUE', 'IN', '!=', 'EMPTY', '>=', '<=',
%   '=', '<', '>'.
tokenize(Text, Tokens) :-
    string_codes(Text, Cs),
    tokens(Cs, Tokens0),
    append(Tokens0, [tok(eof, '')], Tokens).

tokens([], []) :- !.
tokens([C|Cs], Ts) :- code_type(C, space), !, tokens(Cs, Ts).
%  conforms_to(<id>): the id up to the closing bracket, one token
tokens(Cs, [tok(ident, conforms_to), tok(lparen, '('), tok(ident, Id), tok(rparen, ')')|Ts]) :-
    atom_codes(conforms_to, P), append(P, [0'(|Rest], Cs),
    append(IdCs, [0')|After], Rest), \+ memberchk(0'), IdCs), !,
    atom_codes(Id0, IdCs), normalize_space(atom(Id), Id0),
    tokens(After, Ts).
tokens([0x2203, 0'!|Cs], [tok(op, 'EXISTS_UNIQUE')|Ts]) :- !, tokens(Cs, Ts).
tokens([C|Cs], [tok(op, V)|Ts]) :- unicode_op(C, V), !, tokens(Cs, Ts).
tokens([0'(|Cs], [tok(lparen, '(')|Ts]) :- !, tokens(Cs, Ts).
tokens([0')|Cs], [tok(rparen, ')')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'{|Cs], [tok(lbrace, '{')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'}|Cs], [tok(rbrace, '}')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'.|Cs], [tok(dot, '.')|Ts]) :- !, tokens(Cs, Ts).
tokens([0',|Cs], [tok(comma, ',')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'-, 0'>|Cs], [tok(op, '->')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'&, 0'&|Cs], [tok(op, '&&')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'/, 0'\\|Cs], [tok(op, '&&')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'\\, 0'/|Cs], [tok(op, '||')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'|, 0'||Cs], [tok(op, '||')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'||Cs], [tok(pipe, '|')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'=|Cs], [tok(op, '=')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'<, 0'=|Cs], [tok(op, '<=')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'<|Cs], [tok(op, '<')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'>, 0'=|Cs], [tok(op, '>=')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'>|Cs], [tok(op, '>')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'!, 0'=|Cs], [tok(op, '!=')|Ts]) :- !, tokens(Cs, Ts).
tokens([0'!|Cs], [tok(op, '!')|Ts]) :- !, tokens(Cs, Ts).
tokens([C|Cs], [tok(number, N)|Ts]) :- code_type(C, digit), !,
    digits(Cs, Ds, Rest), number_codes(N, [C|Ds]), tokens(Rest, Ts).
tokens([C|Cs], [tok(ident, W)|Ts]) :- ident_start(C), !,
    ident_rest(Cs, Ws, Rest), atom_codes(W, [C|Ws]), tokens(Rest, Ts).
tokens([_|Cs], Ts) :- tokens(Cs, Ts).                 % Ponens skips the unknown

unicode_op(0x2192, '->').
unicode_op(0x2227, '&&').
unicode_op(0x2228, '||').
unicode_op(0x00AC, '!').
unicode_op(0x2200, 'FORALL').
unicode_op(0x2203, 'EXISTS').
unicode_op(0x2208, 'IN').
unicode_op(0x2260, '!=').
unicode_op(0x2205, 'EMPTY').
unicode_op(0x2265, '>=').
unicode_op(0x2264, '<=').

digits([C|Cs], [C|Ds], R) :- code_type(C, digit), !, digits(Cs, Ds, R).
digits(R, [], R).

ident_start(C) :- code_type(C, alpha) ; C == 0'_.
%  a '-' followed by a word character continues the word (`calendar-db`)
ident_rest([C|Cs], [C|Ws], R) :- ( code_type(C, alnum) ; C == 0'_ ), !, ident_rest(Cs, Ws, R).
ident_rest([0'-, D|Cs], [0'-|Ws], R) :- ( code_type(D, alnum) ; D == 0'_ ), !, ident_rest([D|Cs], Ws, R).
ident_rest(R, [], R).

		 /*******************************
		 *		parser		*
		 *******************************/

%!  parse_formula(+Text, -Formula) is det.
%
%   Formula as Ponens reads Text; raw(Text) where Ponens's parser fails.
parse_formula(Text0, Formula) :-
    ( string(Text0) -> Text = Text0 ; atom_string(Text0, Text) ),
    tokenize(Text, Tokens),
    (   catch(phrase(implies(F), Tokens, _Rest), parse_error(_), fail)
    ->  Formula = F
    ;   Formula = raw(Text)
    ).

%   Ponens's parse() reads one formula and ignores what follows it.
implies(F) --> or_(L), implies_tail(L, F).
implies_tail(L, F) --> [tok(op, '->')], !, or_(R), implies_tail(implies(L, R), F).
implies_tail(F, F) --> [].

or_(F) --> and_(L), or_tail(L, F).
or_tail(L, F) --> [tok(op, '||')], !, and_(R), or_tail(or(L, R), F).
or_tail(F, F) --> [].

and_(F) --> binary_temporal(L), and_tail(L, F).
and_tail(L, F) --> [tok(op, '&&')], !, binary_temporal(R), and_tail(and(L, R), F).
and_tail(F, F) --> [].

binary_temporal(F) --> unary(L), bt_tail(L, F).
bt_tail(L, F) --> [tok(ident, 'U')], !, unary(R), bt_tail(u(L, R), F).
bt_tail(L, F) --> [tok(ident, 'S_last')], !, unary(R), bt_tail(s_last(L, R), F).
bt_tail(L, F) --> s_op, !, unary(R), bt_tail(s(L, R), F).
bt_tail(F, F) --> [].

%   `S` is Since unless the next token is an identifier starting with `_`.
s_op, [Next] --> [tok(ident, 'S'), Next], { \+ ( Next = tok(ident, W), sub_atom(W, 0, 1, _, '_') ) }.

unary(not(B)) --> [tok(op, '!')], !, unary(B).
unary(F) --> [tok(ident, Op)], { unary_op(Op, F, B) }, !, primary(B).
unary(F) --> [tok(op, 'FORALL')], !, forall_(F).
unary(F) --> [tok(op, Q)], { memberchk(Q, ['EXISTS', 'EXISTS_UNIQUE']) }, !, exists_(Q, F).
unary(F) --> primary(F).

unary_op('G', g(B), B).
unary_op('F', f(B), B).
unary_op('X', x(B), B).
unary_op('P_target', p_target(B), B).
unary_op('P_chain', p_chain(B), B).
unary_op('H_target', h(B), B).            % Ponens: Historically (its TODO: scoped)
unary_op('H_chain', h(B), B).
unary_op('P', p(B), B).
unary_op('H', h(B), B).

primary(F) --> [tok(lparen, _)], !, implies(F), expect(rparen).
primary(F) --> [tok(lbrace, _)], !, set_literal(F).
primary(F) --> [tok(ident, Name)], !, ident_expr(Name, F).
primary(_) --> [T], { throw(parse_error(unexpected(T))) }.

expect(Kind) --> [tok(Kind, _)], !.
expect(Kind) --> [T], { throw(parse_error(expected(Kind, T))) }.

ident_expr(start_event, start_event) --> !.
ident_expr(end_event, end_event) --> !.
ident_expr(count, count(B, Op, N)) --> [tok(lparen, _)], !, implies(B), expect(rparen),
    (   [tok(op, Op)], { memberchk(Op, ['>=', '<=', '!=', '>', '<', '=']) }
    ->  ( [tok(number, N)] -> [] ; [T], { throw(parse_error(count_number(T))) } )
    ;   { throw(parse_error(count_comparison)) }
    ).
ident_expr(Name, F) --> [tok(dot, _), tok(_, Field)], !,
    (   [tok(op, Op)], { memberchk(Op, ['!=', '>=', '<=', '=', '>', '<']) }
    ->  value(V), { F = compare(field(Name, Field), Op, V) }
    ;   { F = field(Name, Field) }
    ).
ident_expr(Name, field_ne_empty(Name)) --> [tok(op, '!=')], !,
    (   ( [tok(op, 'EMPTY')] ; [tok(ident, 'EMPTY')] ) -> [] ; { throw(parse_error(empty_expected)) } ).
ident_expr(Name, equals(atom(Name), S)) --> { field_name(Name) }, [tok(op, '=')], !,
    (   [tok(lbrace, _)] -> set_literal(S) ; primary(S) ).
ident_expr(Name, member(atom(Name), S)) --> [tok(op, 'IN')], !, primary(S).
ident_expr(Name, func(Name, Arg)) --> { field_name(Name) }, [tok(lparen, _), tok(_, Arg)], !, expect(rparen).
ident_expr(Name, func(Name, Arg)) -->
    { evidence_predicate(Name) ; label_predicate(Name) ; symbol_predicate(Name) },
    [tok(lparen, _)], !, until_rparen(Parts), { atomic_list_concat(Parts, Arg) }.
ident_expr(Name, atom_args(Name, [A|As])) -->
    { artifact_type(Name) ; action_type(Name) }, [tok(lparen, _)], !,
    implies(A), more_args(As), expect(rparen).
ident_expr(ancestors, ancestors(Field)) --> [tok(lparen, _), tok(_, Field)], !, expect(rparen).
ident_expr(Name, atom(Name)) --> [].

more_args([A|As]) --> ( [tok(op, '||')] ; [tok(comma, _)] ), !, implies(A), more_args(As).
more_args([]) --> [].

until_rparen([]) --> [tok(rparen, _)], !.
until_rparen(_) --> [tok(eof, _)], !, { throw(parse_error(unclosed)) }.
until_rparen([V|Vs]) --> [tok(_, V)], until_rparen(Vs).

value(atom('EMPTY')) --> ( [tok(op, 'EMPTY')] ; [tok(ident, 'EMPTY')] ), !.
value(atom(V)) --> [tok(_, V)].

%   { … } read as its text, as Ponens keeps it (SetLiteral).
set_literal(set(Text)) --> set_parts(1, Parts), { atomic_list_concat(Parts, ' ', Text) }.
set_parts(D, Ps) --> [tok(K, V)],
    (   { K == rbrace, D == 1 } -> { Ps = [] }
    ;   { K == rbrace -> D1 is D - 1 ; K == lbrace -> D1 is D + 1 ; D1 = D },
        { Ps = [V|Ps1] }, set_parts(D1, Ps1)
    ).

forall_(forall(Var, Set, Body)) --> [tok(_, Var)], expect_op('IN'), set_name(Set), quant_sep, implies(Body).
exists_(Q, F) --> [tok(_, Var)],
    ( [tok(op, 'IN')] -> set_name(Set) ; { Set = '' } ),
    quant_sep, implies(Body),
    { Q == 'EXISTS_UNIQUE' -> F = exists_unique(Var, Set, Body) ; F = exists(Var, Set, Body) }.

expect_op(Op) --> [tok(op, Op)], !.
expect_op(Op) --> { throw(parse_error(expected(Op))) }.

quant_sep --> [tok(dot, _)], !.
quant_sep --> [tok(op, '->')], !.
quant_sep --> { throw(parse_error(quantifier_separator)) }.

set_name(S) --> [tok(_, Name)],
    (   [tok(lparen, _), tok(_, Arg)] -> expect(rparen), { format(atom(S), '~w(~w)', [Name, Arg]) }
    ;   { S = Name }
    ).

		 /*******************************
		 *	    the way back		*
		 *******************************/

%!  formula_text(+Formula, -Text) is det.
%
%   Formula in Ponens's unicode surface. Brackets go where the parser's
%   precedence (implies < or < and < binary temporal < unary) needs them,
%   and around the operand of a unary temporal operator, which Ponens reads
%   as a primary.
formula_text(raw(T), T) :- !.
formula_text(F, T) :- text(F, 0, T).

prec(implies(_, _), 1).
prec(or(_, _), 2).
prec(and(_, _), 3).
prec(u(_, _), 4).
prec(s(_, _), 4).
prec(s_last(_, _), 4).

text(F, Ctx, T) :-
    prec(F, P), !,
    F =.. [Op, A, B],
    op_text(Op, OT),
    (   Op == implies -> PA is P + 1, PB = P ; PA = P, PB is P + 1 ),
    text(A, PA, TA), text(B, PB, TB),
    format(atom(T0), '~w ~w ~w', [TA, OT, TB]),
    ( P < Ctx -> format(atom(T), '(~w)', [T0]) ; T = T0 ).
text(not(A), _, T) :- !, text(A, 5, TA), format(atom(T), '¬~w', [TA]).
text(F, _, T) :- F =.. [Op, A], unary_text(Op, OT), !,
    primary_text(A, TA), format(atom(T), '~w(~w)', [OT, TA]).
text(atom(N), _, N) :- !.
text(atom_args(N, Args), _, T) :- !,
    maplist([A, X]>>text(A, 0, X), Args, Ts), atomic_list_concat(Ts, ' ∨ ', In),
    format(atom(T), '~w(~w)', [N, In]).
text(field_ne_empty(N), _, T) :- !, format(atom(T), '~w ≠ ∅', [N]).
text(func(N, A), _, T) :- !, format(atom(T), '~w(~w)', [N, A]).
text(start_event, _, start_event) :- !.
text(end_event, _, end_event) :- !.
text(count(B, Op, N), _, T) :- !, text(B, 0, TB), cmp_text(Op, OT), format(atom(T), 'count(~w) ~w ~w', [TB, OT, N]).
text(compare(field(V, F), Op, atom(X)), _, T) :- !,
    cmp_text(Op, OT), ( X == 'EMPTY' -> XT = '∅' ; XT = X ),
    format(atom(T), '~w.~w ~w ~w', [V, F, OT, XT]).
text(field(V, F), _, T) :- !, format(atom(T), '~w.~w', [V, F]).
text(forall(V, S, B), Ctx, T) :- !, quant_text('∀', V, S, B, Ctx, T).
text(exists(V, S, B), Ctx, T) :- !, quant_text('∃', V, S, B, Ctx, T).
text(exists_unique(V, S, B), Ctx, T) :- !, quant_text('∃!', V, S, B, Ctx, T).
text(member(atom(N), S), _, T) :- !, text(S, 5, TS), format(atom(T), '~w ∈ ~w', [N, TS]).
text(equals(atom(N), S), _, T) :- !, text(S, 5, TS), format(atom(T), '~w = ~w', [N, TS]).
text(set(X), _, T) :- !, format(atom(T), '{~w}', [X]).
text(ancestors(F), _, T) :- !, format(atom(T), 'ancestors(~w)', [F]).

quant_text(Q, V, S, B, Ctx, T) :-
    text(B, 0, TB),
    ( S == '' -> format(atom(T0), '~w~w . ~w', [Q, V, TB]) ; format(atom(T0), '~w ~w ∈ ~w . ~w', [Q, V, S, TB]) ),
    ( Ctx > 0 -> format(atom(T), '(~w)', [T0]) ; T = T0 ).

primary_text(A, T) :- text(A, 0, T).

unary_text(g, 'G').
unary_text(f, 'F').
unary_text(x, 'X').
unary_text(p, 'P').
unary_text(h, 'H').
unary_text(p_target, 'P_target').
unary_text(p_chain, 'P_chain').

op_text(implies, '→').
op_text(or, '∨').
op_text(and, '∧').
op_text(u, 'U').
op_text(s, 'S').
op_text(s_last, 'S_last').

cmp_text('!=', '≠') :- !.
cmp_text('>=', '≥') :- !.
cmp_text('<=', '≤') :- !.
cmp_text(Op, Op).

		 /*******************************
		 *	   the atomic nodes		*
		 *******************************/

%!  formula_atoms(+Formula, -Nodes) is det.
%
%   The nodes of Formula whose truth at an action the trace decides — an
%   atom, an atom with arguments, a field that must not be empty, a
%   function of the action, the start and the end of the trace — each once.
formula_atoms(F, Nodes) :-
    findall(N, atomic_node(F, N), Ns0),
    list_to_set(Ns0, Nodes).

atomic_node(F, F) :- atomic_formula(F), !.
atomic_node(F, N) :- compound(F), \+ atomic_formula(F),
    F =.. [_|Args], member(A, Args),
    ( compound(A) ; A == start_event ; A == end_event ), atomic_node(A, N).

atomic_formula(atom(_)).
atomic_formula(atom_args(_, _)).
atomic_formula(field_ne_empty(_)).
atomic_formula(func(_, _)).
atomic_formula(start_event).
atomic_formula(end_event).

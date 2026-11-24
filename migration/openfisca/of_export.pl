/** <module> File ▸ Export to Another System… → OpenFisca

    The way back of Phase 3b (decision 7 of the October plan: one export per
    phase): a timeless Logical English program as one self-contained Python
    module for OpenFisca's engine (openfisca-core): its entities, a Variable
    class per template, its parameters as a ParameterNode built from a dict,
    and a `system()` that assembles them; the scenarios follow as OpenFisca's
    YAML tests in a string, TESTS.

    The program is read as the RuleSpec exporter reads it
    (migration/rulespec/rulespec_export.pl): the same templates become
    derived values, judgments, parameters, tables and inputs, and the same
    refusals apply (a value concluded only under conditions, a value read of
    something other than the rule's subject outside an aggregate, …). The
    formulas are written in OpenFisca's vector style: `where`, `select`,
    `max_`, `min_`, `np.floor`, `np.ceil`, `&`, `|`, `~`, a group's
    `sum(members(…))` for an aggregate over its members.

    export_openfisca(+KB, +Options, -Result); openfisca_module(+KB, -Text,
    -Tests) for the round trip (roundtrip.pl). Each variable and parameter
    has a comment above it naming the lines of the program it came from
    (`# Logical English line 74`), when the exporter is given the program's
    text.
*/

:- module(of_export, [export_openfisca/3, applies_openfisca/1, check_openfisca/3, openfisca_module/3, openfisca_module/4]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer), []).
:- use_module('../rulespec/rulespec_export').

:- discontiguous py/3.

applies_openfisca(KB) :- applies_rulespec(KB).

check_openfisca(KB, Options, Problems) :- check_rulespec(KB, Options, Problems).

export_openfisca(KB, Options, Result) :-
    le_writer:kb_to_ir(KB, program(H, _)),
    ( memberchk(kb(Name), H) -> true ; Name = program ),
    catch(openfisca_module(KB, Options, Text0, Tests), error(of_export_refused(Ps), _), true),
    (   nonvar(Ps)
    ->  Result = refused(Ps)
    ;   format(string(Text), "~s~nTESTS = r'''~n~s'''~n", [Text0, Tests]),
        format(atom(File), '~w.py', [Name]),
        Result = exported(File, Text,
                          ["One Python module: the entities, the variables, the parameters and system(), which builds the tax and benefit system; TESTS holds the scenarios as OpenFisca's YAML tests.",
                           "Run it: pip install openfisca-core; then build the system with system() and run TESTS with OpenFisca's test runner, or save TESTS as a .yaml file and run openfisca test with --country-package pointing at this module."],
                          [])
    ).

%!  openfisca_module(+KB, -Text, -Tests) is det.
%!  openfisca_module(+KB, +Options, -Text, -Tests) is det.
%
%   With text(Doc) in Options (the exporter's), each variable and parameter
%   has a comment above it naming the lines of the program it came from.
openfisca_module(KB, Text, Tests) :-
    openfisca_module(KB, [], Text, Tests).

openfisca_module(KB, Options, Text, Tests) :-
    rulespec_export:analyse(KB, 'of:program', Rules, Cases, Options),
    findall(problem(W, M), rulespec_export:problem_(W, M), Problems),
    (   Problems \== [] -> throw(error(of_export_refused(Problems), _)) ; true ),
    entities(Rules, Groups),
    retractall(text_input(_)), retractall(date_input(_)),
    forall(( member(case(_, _, In, _), Cases), member(K0-V0, In), text_value(K0, V0, K, V) ),
           ( date_text(V) -> assert_once(date_input(K)) ; assert_once(text_input(K)) )),
    b_setval(of_rules, Rules),
    with_output_to(string(Text), module_text(Rules, Groups)),
    with_output_to(string(Tests), tests_text(Cases, Groups)).

%   The group entities the program names (besides Person).
entities(Rules, Groups) :-
    findall(E, ( member(rs(_, _, Attrs, _), Rules), memberchk(entity-E, Attrs), E \== 'Person' ), Es1),
    findall(E, ( rulespec_export:t_(_, _, Shape, _), shape_entity(Shape, E), E \== none, E \== 'Person' ), Es2),
    append(Es1, Es2, Es0), sort(Es0, Groups).

shape_entity(input(_, E), E).
shape_entity(derived(_, E), E).
shape_entity(relation(_, B), E) :- rulespec_export:noun_entity(B, E).

key_of(E, K) :-
    atom_codes(E, Cs), snake(Cs, Ds), atom_codes(K, Ds).
snake([], []).
snake([C|Cs], Out) :-
    (   code_type(C, upper(L))
    ->  ( Out = [0'_, L|R] ) ; Out = [C|R] ),
    snake(Cs, R).

ekey(E, K) :- key_of(E, K0), ( atom_concat('_', K, K0) -> true ; K = K0 ).


		 /*******************************
		 *          THE MODULE          *
		 *******************************/

module_text(Rules, Groups) :-
    format("\"\"\"Written from a Logical English program by Logical English's translator\n(LE2 migration/openfisca). A tax and benefit system for openfisca-core.\"\"\"\n"),
    format("import datetime\nimport numpy as np\nfrom openfisca_core.entities import build_entity\nfrom openfisca_core.parameters import ParameterNode\nfrom openfisca_core.periods import MONTH\nfrom openfisca_core.taxbenefitsystems import TaxBenefitSystem\nfrom openfisca_core.variables import Variable\nfrom numpy import maximum as max_, minimum as min_, where, select\n\n"),
    format("def _key(x):\n    \"\"\"A table's key: a number written as OpenFisca names it, or a code.\"\"\"\n    x = np.asarray(x)\n    return x.astype(int).astype(str) if x.dtype.kind in 'iuf' else x.astype(str)\n\n"),
    format("def _ymd(d):\n    \"\"\"A date's year, month and day, as numbers (one date, or one per person).\"\"\"\n    d = np.asarray(d, dtype='datetime64[D]')\n    return (d.astype('datetime64[Y]').astype(int) + 1970, d.astype('datetime64[M]').astype(int) % 12 + 1,\n            (d - d.astype('datetime64[M]')).astype(int) + 1)\n\n"),
    format("def _months_between(b, l):\n    \"\"\"The whole months from date b to date l.\"\"\"\n    (by, bm, bd), (ly, lm, ld) = _ymd(b), _ymd(l)\n    return (ly - by) * 12 + (lm - bm) - (ld < bd)\n\n"),
    format("def _rank(person, group, key, condition):\n    \"\"\"How many members of each person's group meet the condition and have a\n    smaller key: the person's place among them.\"\"\"\n    ids = person.simulation.populations[group].members_entity_id\n    k = np.asarray(key, dtype=float)\n    c = np.broadcast_to(np.asarray(condition, dtype=bool), k.shape)\n    return ((ids[:, None] == ids[None, :]) & c[None, :] & (k[None, :] < k[:, None])).sum(axis=1)\n\n"),
    format("Person = build_entity(key='person', plural='persons', label='a person', is_person=True)\n"),
    forall(member(G, Groups),
           ( ekey(G, K), format("~w = build_entity(key='~w', plural='~ws', label='~w', roles=[{'key': 'member', 'plural': 'members', 'label': 'a member'}])~n", [G, K, K, K]) )),
    findall(G, member(G, Groups), GL), atomic_list_concat([''|GL], ', ', Gs0), ( GL == [] -> Gs = '' ; Gs = Gs0 ),
    format("ENTITIES = [Person~w]~n~n", [Gs]),
    parameters_text(Rules),
    forall(( rulespec_export:t_(F, _, input(Kind, E), _), rulespec_export:name_(F, N), N \== calculation_date ),
           input_text(N, Kind, E)),
    forall(( member(rs(N, derived, Attrs, Vs), Rules) ), derived_text(N, Attrs, Vs)),
    format("~ndef system():~n    s = TaxBenefitSystem(ENTITIES)~n    s.parameters = PARAMETERS~n    for v in [c for c in globals().values() if isinstance(c, type) and issubclass(c, Variable) and c is not Variable]:~n        s.add_variable(v)~n    return s~n").

parameters_text(Rules) :-
    format("PARAMETERS = ParameterNode('', data={~n"),
    forall(member(rs(N, parameter, Attrs, Vs), Rules), parameter_text(N, Attrs, Vs)),
    format("})~n~n").

parameter_text(N, _Attrs, Vs) :-
    ( provenance_text(N, PT) -> format("    # ~s~n", [PT]) ; true ),
    (   Vs = [version(_, _, table(_))|_]
    ->  findall(K, ( member(version(_, _, table(Rows)), Vs), member(K-_, Rows) ), Ks0), sort(Ks0, Ks),
        format("    '~w': {~n", [N]),
        forall(member(K, Ks),
               ( findall(From-V, ( member(version(From0, _, table(Rows)), Vs), memberchk(K-V, Rows), from_date(From0, From) ), FVs),
                 format("        '~w': {'values': {", [K]),
                 forall(member(From-V, FVs), format("'~w': ~w, ", [From, V])),
                 format("}},~n") )),
        format("    },~n")
    ;   format("    '~w': {'values': {", [N]),
        forall(( member(version(From0, _, literal(V)), Vs), from_date(From0, From) ), format("'~w': ~w, ", [From, V])),
        format("}},~n")
    ).

from_date(F0, F) :- ( memberchk(F0, ['1900-01-01', '0000-01-01']) -> F = '0001-01-01' ; F = F0 ).    % (OpenFisca has no year 0)

%   An input whose values in the scenarios are words: a text variable;
%   whose values are dates (1980-02-15): a date variable, which OpenFisca
%   reads from a test's date (a float variable cannot: `float()` of a
%   `datetime.date`).
:- dynamic text_input/1, date_input/1.
text_value(K0, V0, K, V) :-
    (   is_list(V0) -> member(It, V0), member(K1-V1, It), text_value(K1, V1, K, V)
    ;   ( atom(V0), \+ memberchk(V0, [true, false]) ; string(V0) ), local_key(K0, K), V = V0
    ).

date_text(V) :-
    ( atom(V) ; string(V) ),
    split_string(V, "-", "", [Y, M, D]),
    string_length(Y, 4), string_length(M, 2), string_length(D, 2),
    forall(member(X, [Y, M, D]), number_string(_, X)).
assert_once(F) :- ( call(F) -> true ; assertz(F) ).

input_text(N, Kind, E) :-
    ( E == none -> Ent = 'Person' ; Ent = E ),
    ( Kind == judgment -> T = bool ; date_input(N) -> T = 'datetime.date' ; text_input(N) -> T = str ; T = float ),
    format("~nclass ~w(Variable):~n    value_type = ~w~n    entity = ~w~n    definition_period = MONTH~n    label = '~w'~n", [N, T, Ent, N]).

%   A refusal found while writing a variable is placed on its rule (or its
%   template's rules), so that a partial export can leave them out. The
%   comment above the class names the lines it came from: a Variable's own
%   `reference` is the law it cites (a provenance trailer), not the program.
derived_text(N, Attrs, Vs) :-
    catch(derived_text_(N, Attrs, Vs), error(of_export_refused(Ps0), C),
          ( place_problems(N, Ps0, Ps), throw(error(of_export_refused(Ps), C)) )).

derived_text_(N, Attrs, Vs) :-
    ( memberchk(entity-E, Attrs) -> true ; E = 'Person' ),
    (   memberchk(dtype-'Judgment', Attrs) -> T = bool
    ;   date_input(N) -> T = 'datetime.date'                               % (a case gives it as a date)
    ;   memberchk(dtype-dtype(V), Attrs), memberchk(V, [text, code, "text", "code"]) -> T = str      % (a value in words)
    ;   T = float
    ),
    ( provenance_text(N, PT) -> format("~n# ~s", [PT]) ; true ),
    format("~nclass ~w(Variable):~n    value_type = ~w~n    entity = ~w~n    definition_period = MONTH~n    label = '~w'~n", [N, T, E, N]),
    (   T == str -> format("    default_value = ''~n") ; true ),
    (   memberchk(source-S, Attrs), S \== none -> format("    reference = ~q~n", [S]) ; true ),
    findall(From, member(version(From, _, _), Vs), Fs0), sort(Fs0, Fs),
    forall(member(From, Fs),
           ( findall(F, ( member(version(From, To, F0), Vs), until(To, T, F0, F) ), [F1|More]),
             (   More == [] -> F = F1
             ;   T == bool -> foldl([G, A0, or(A0, G)]>>true, More, F1, F)      % (rules from one date: alternatives)
             ;   format(string(M), "~w has two formulas from ~w", [N, From]),
                 throw(error(of_export_refused([problem(none, M)]), _))
             ),
             formula_text(E, From, F) )).

%   A version that ends: its formula holds until its last day (OpenFisca
%   ends a variable, not one of its formulas).
until(none, _, F, F) :- !.
until(To, bool, F, and(cmp(=<, ref(calculation_date), date(To)), F)) :- !.
until(To, _, F, if(cmp(=<, ref(calculation_date), date(To)), F, num(0))).

formula_text(E, From, F) :-
    ekey(E, Arg),
    ( From == '1900-01-01' -> MName = formula ; atomic_list_concat(Ps, '-', From), atomic_list_concat([formula|Ps], '_', MName) ),
    py(F, Arg, P),
    format("~n    def ~w(~w, period, parameters):~n        P = parameters(period)~n        return ~s~n", [MName, Arg, P]).

%   A formula of the RuleSpec exporter, in OpenFisca's vector style.
py(num(N), _, S) :- !, format(string(S), "~w", [N]).
py(str(X), _, S) :- !, format(string(S), "'~w'", [X]).
py(bool(true), _, "True") :- !.
py(bool(false), _, "False") :- !.
py(ref(calculation_date), _, "str(period.start)") :- !.
%   the whole months from date B to date L (the module's _months_between)
py(call(months_between, [B, L]), A, S) :- !, py(B, A, BS), py(L, A, LS),
    format(string(S), "_months_between(~s, ~s)", [BS, LS]).
%   a value of the group the subject belongs to: a person reads it through
%   OpenFisca's projector; a group reads it through its members, who are all
%   in one household (`the household of a spm unit`, the review's finding on
%   SNAP's `is_homeless`)
py(field(E, N), A, S) :- !, ekey(E, K), ekey('Person', P),
    (   A == P
    ->  format(string(S), "~w.~w('~w', period)", [A, K, N])
    ;   format(string(S), "~w.value_from_first_person(~w.members.~w('~w', period))", [A, A, K, N])
    ).
py(ref(N), A, S) :- !,
    (   rulespec_export:name_(F, N), rulespec_export:t_(F, _, Sh, _), memberchk(Sh, [parameter, table(_)])
    ->  format(string(S), "P.~w", [N])
    ;   name_entity(N, E2), ekey(E2, K2), K2 \== A, A == person
    ->  format(string(S), "~w.~w('~w', period)", [A, K2, N])      % the person's group's value
    ;   name_entity(N, E2), ekey(E2, K2), K2 \== A, ekey('Person', P), K2 \== P
    ->  %  another group's value, through the group's first member (the
        %  members of a group are in one household, one tax unit)
        format(string(S), "~w.value_from_first_person(~w.members.~w('~w', period))", [A, A, K2, N])
    ;   name_entity(N, E2), ekey(E2, K2), K2 \== A
    ->  format(string(M), "it reads ~w, a value of ~w, in a rule of ~w: OpenFisca reads another entity's value only through its members or roles", [N, E2, A]),
        throw(error(of_export_refused([problem(none, M)]), _))
    ;   format(string(S), "~w('~w', period)", [A, N])
    ).

name_entity(N, E) :-
    (   b_getval(of_rules, Rules), member(rs(N, derived, Attrs, _), Rules), memberchk(entity-E0, Attrs) -> E = E0
    ;   rulespec_export:name_(F, N), rulespec_export:t_(F, _, Sh, _), Sh =.. [_, _, E0], E0 \== none -> E = E0
    ;   fail
    ).
py(index(T, num(K)), _, S) :- !, format(string(S), "P.~w['~w']", [T, K]).
py(index(T, K), A, S) :- !, py(K, A, KS), format(string(S), "P.~w[_key(~s)]", [T, KS]).
py(bin(Op, X, Y), A, S) :- !, py(X, A, XS), py(Y, A, YS), format(string(S), "(~s ~w ~s)", [XS, Op, YS]).
py(neg(X), A, S) :- !, py(X, A, XS), format(string(S), "(-~s)", [XS]).
py(not(X), A, S) :- !, py(X, A, XS), format(string(S), "np.logical_not(~s)", [XS]).      % (~ of a Python bool is -1 or -2)
py(and(X, Y), A, S) :- !, py(X, A, XS), py(Y, A, YS), format(string(S), "(~s & ~s)", [XS, YS]).
py(or(X, Y), A, S) :- !, py(X, A, XS), py(Y, A, YS), format(string(S), "(~s | ~s)", [XS, YS]).
py(cmp(Op, X, Y), A, S) :- !, py(X, A, XS), py(Y, A, YS), op_py(Op, O), format(string(S), "(~s ~w ~s)", [XS, O, YS]).
py(if(C, X, nomatch), A, S) :- !, py(if(C, X, num(0)), A, S).
py(if(C, X, Y), A, S) :- !, py(C, A, CS), py(X, A, XS), py(Y, A, YS), format(string(S), "where(~s, ~s, ~s)", [CS, XS, YS]).
py(match(Subj, Arms), A, S) :- !,
    py(Subj, A, SS),
    findall(C, ( member(P-_, Arms), py(P, A, PS), format(string(C), "~s == ~s", [SS, PS]) ), Cs),
    findall(V, ( member(_-X, Arms), py(X, A, V) ), Vs),
    atomic_list_concat(Cs, ', ', CT), atomic_list_concat(Vs, ', ', VT),
    format(string(S), "select([~w], [~w], default=0)", [CT, VT]).
py(call(max, [X, Y]), A, S) :- !, py(X, A, XS), py(Y, A, YS), format(string(S), "max_(~s, ~s)", [XS, YS]).
py(call(min, [X, Y]), A, S) :- !, py(X, A, XS), py(Y, A, YS), format(string(S), "min_(~s, ~s)", [XS, YS]).
py(call(floor, [X]), A, S) :- !, py(X, A, XS), format(string(S), "np.floor(~s)", [XS]).
py(call(ceil, [X]), A, S) :- !, py(X, A, XS), format(string(S), "np.ceil(~s)", [XS]).
%   (Logical English rounds half away from zero; NumPy's round to the even.)
py(call(round, [X]), A, S) :- !, py(X, A, XS), format(string(S), "(np.sign(~s) * np.floor(np.abs(~s) + 0.5))", [XS, XS]).
py(call(abs, [X]), A, S) :- !, py(X, A, XS), format(string(S), "np.abs(~s)", [XS]).
py(len(_), A, S) :- !, format(string(S), "~w.nb_persons()", [A]).
%   a member's place among the members of its group who meet a condition,
%   by a key (the members with a smaller key: the module's _rank)
py(rank(R, K, P), A, S) :- !,
    atom_concat(member_of_, G, R),
    ( P == none -> PS = "True" ; format(string(PS), "~w('~w', period)", [A, P]) ),
    format(string(S), "_rank(~w, '~w', ~w('~w', period), ~s)", [A, G, A, K, PS]).
py(count_where(_, P), A, S) :- !, format(string(S), "~w.sum(~w.members('~w', period))", [A, A, P]).
py(sum(_, F), A, S) :- !, format(string(S), "~w.sum(~w.members('~w', period))", [A, A, F]).
py(extreme(Op, _, F), A, S) :- !, format(string(S), "~w.~w(~w.members('~w', period))", [A, Op, A, F]).
py(date(D), _, S) :- !, format(string(S), "'~w'", [D]).          % (compared with str(period.start))
py(sum_where(_, F, P), A, S) :- !, format(string(S), "~w.sum(~w.members('~w', period) * ~w.members('~w', period))", [A, A, F, A, P]).
py(X, _, _) :- term_string(X, T), throw(error(of_export_refused([problem(none, T)]), _)).

op_py(==, '==').
op_py(\=, '!=').
op_py(=<, '<=').
op_py(Op, Op).


		 /*******************************
		 *            TESTS             *
		 *******************************/

tests_text(Cases, Groups) :- forall(member(C, Cases), case_text(C, Groups)).

case_text(case(N, Period0, In, Out), Groups) :-
    ( Period0 = day(D) -> sub_atom(D, 0, 7, _, Period) ; Period = Period0 ),
    format("- name: ~w~n  period: ~w~n  input:~n", [N, Period]),
    findall(K-V, ( member(K0-V, In), \+ is_list(V), local_key(K0, K) ), Own0),
    out_entity(Out, QE0),
    %  in a group's case, a person's input belongs to its persons
    (   QE0 \== 'Person'
    ->  partition([K-_]>>( name_entity(K, 'Person') ), Own0, PersonOwn, Own)
    ;   PersonOwn = [], Own = Own0
    ),
    findall(R-Items, ( member(K0-Items, In), is_list(Items), local_key(K0, R) ), Rels),
    out_entity(Out, QE),
    (   QE == 'Person'
    ->  %  (a person's facts read as a group's first member: the person's own)
        findall(K-V, ( member(_-[It|_], Rels), member(K0-V, It), local_key(K0, K), \+ memberchk(K-_, Own) ), First0),
        sort(First0, First), append(Own, First, Mine),
        forall(member(K-V, Mine), format("    ~w: ~w~n", [K, V]))
    ;   ekey(QE, QK),
        (   Rels = [_-Items|_] -> length(Items, NM) ; Items = [], NM = 1 ),
        format("    persons:~n"),
        forall(between(1, NM, I), ( format("      p~w:~n", [I]),
                                     ( nth1(I, Items, It) -> true ; It = [] ),
                                     findall(K-V, ( member(K0-V, It), local_key(K0, K) ), PIt0),
                                     findall(K-V, ( member(K-V, PersonOwn), \+ memberchk(K-_, PIt0) ), Extra),
                                     append(PIt0, Extra, PIt),
                                     ( PIt == [] -> format("        {}~n") ; true ),
                                     forall(member(K-V, PIt), format("        ~w: ~w~n", [K, V])) )),
        format("    ~ws:~n      g1:~n        members: [", [QK]),
        forall(between(1, NM, I), ( I > 1 -> format(", p~w", [I]) ; format("p~w", [I]) )),
        format("]~n"),
        forall(member(K-V, Own), format("        ~w: ~w~n", [K, V]))
    ),
    _ = Groups,
    format("  output:~n"),
    forall(( member(K0-V0, Out), local_key(K0, K), \+ parameter_name(K) ), ( out_value(V0, V), format("    ~w: ~w~n", [K, V]) )).

%   A parameter is not a variable of OpenFisca: no test asks for it.
parameter_name(K) :- rulespec_export:name_(F, K), rulespec_export:t_(F, _, Sh, _), memberchk(Sh, [parameter, table(_)]), !.

local_key(K0, K) :-
    format(atom(A), '~w', [K0]),
    ( sub_atom(A, B, 1, _, '#') -> B1 is B + 1, sub_atom(A, B1, _, 0, F) ; F = A ),
    ( atom_concat('input.', K, F) -> true ; atom_concat('relation.', K, F) -> true ; K = F ).

out_value(holds, true) :- !.
out_value(not_holds, false) :- !.
out_value(V, V).

out_entity(Out, E) :-
    (   member(K0-_, Out), local_key(K0, K), rulespec_export:name_(F, K), rulespec_export:t_(F, _, Shape, _),
        Shape =.. [_, _, E], E \== none -> true
    ;   E = 'Person'
    ).

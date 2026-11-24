:- module(catala_lower,
          [ lower_programme/4,          % +Name, +Files, +Roots, -module(Rules, Tests, Notes)
            catala_value/2              % +Expr, -Value (a test's constant)
          ]).
/** <module> Catala scopes in the shape of RuleSpec rules

Phase 3c (roadmap.md §5.4, §8). The tree of catala_reader.pl, lowered to
the rules the twin builder of Phase 3a reads (rulespec_twin.pl), as the
OpenFisca reader of Phase 3b does: a scope's variables become the case's
own values (a test is one instance of the scope it tests); an input is a
fact the scenario states; a variable with definitions is a derived rule
whose formula, in RuleSpec's expression language, is the cascade of its
definitions; a condition (`rule … fulfilled`) is a judgment.

Exceptions. A variable's definitions form Catala's exception tree: the
definitions under a label, and the exceptions to that label, which win
when they apply. The cascade lists the exceptions first, then the
definitions they are exceptions to (`if exception: … elif base: …`), so
the first that applies gives the value, as in Catala; where two apply at
one level Catala stops with a conflict and the twin takes the first (noted
in the ledger). A variable no definition gives a value to has none, as in
Catala (a cascade without a last branch).

What is not lowered is residue, with its reason and the Catala source:
lists and their operations, structures other than an input's fields,
functions (`definition f of x`), scope calls and sub-scopes, durations.
*/

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(catala_reader).

%!  lower_programme(+Name, +Files, +Roots, -Result) is det.
%
%   Files: the Catala files of the programme (with its tests); Roots: the
%   scopes it is about. Result: module(Rules, Tests, Notes), Rules and
%   Tests as dicts in the shape of a RuleSpec module and its test file.
lower_programme(Name, Files, Roots, module(Rules, Tests, Notes)) :-
    maplist(read_catala_file, Files, Trees),
    ( Trees = [catala(Lang0, _)|_] -> b_setval(catala_lang, Lang0) ; b_setval(catala_lang, en) ),
    retractall(file_text(_, _)),
    forall(nth1(I, Files, F), ( read_file_to_string(F, T, []), split_string(T, "\n", "\r", Ls), assertz(file_text(I, Ls)) )),
    findall(F-Lang-I, ( nth1(F, Trees, catala(Lang, Is)), member(I, Is) ), LIs),
    collect(LIs),
    retractall(note(_)),
    atom_concat('cat:', Name, Mid),
    retractall(subject_field(_, _, _)),
    retractall(spec(_, _, _, _, _)), retractall(spec_done(_, _, _, _)),
    b_setval(catala_element, none), b_setval(catala_subject, none), b_setval(catala_state, none),
    b_setval(catala_in_sub, false),
    findall(R, ( member(S, Roots), root_prefix(Roots, S, P), scope_rules(Mid, S, P, [], R) ), Rules0a),
    spec_fixpoint(Mid, Rules0a, Rules0b),
    findall(_{name: N, kind: input, dtype: DT, entity: St}, subject_field(St, N, DT), SubjIns),
    append(Rules0b, SubjIns, Rules0),
    sort_rules(Rules0, Rules1),
    scope_asserts(Roots, Rules1, Rules),
    findall(T, ( test_scope(TS), test_case(Mid, Roots, TS, T) ), Tests),
    findall(N, note(N), Notes).

%!  scope_asserts(+Roots, +Rules0, -Rules) is det.
%
%   A scope's own `assertion` statements say what the law asserts about the
%   values it reads (`assertion montant_forfaitaire >= 0`). They are not
%   definitions, so they become integrity constraints of the twin: a case
%   that contradicts one is refused, not answered (roadmap §8, Phase 3c work
%   left, item 7). They are carried on the first rule of the scope they
%   belong to, which is where the twin writes them.
scope_asserts(Roots, Rules0, Rules) :-
    findall(S-M,
            ( member(S, Roots), scope_decl(S, Lang, _),
              scope_def(S, none, assertion(X, _), _),
              catch(expr_text(Lang, ctx(S, ''), X, T), _, fail),
              format(string(M), "~w", [T]) ),
            Pairs0),
    list_to_set(Pairs0, Pairs),
    (   Pairs == [] -> Rules = Rules0
    ;   foldl(attach_assert, Pairs, Rules0, Rules)
    ).

attach_assert(S-M, Rules0, Rules) :-
    (   nth0(I, Rules0, R), is_dict(R), get_dict(kind, R, derived),
        get_dict(catala_scope, R, S), \+ get_dict(residue_reason, R, _)
    ->  ( get_dict(must, R, Ms0) -> true ; Ms0 = [] ),
        ( memberchk(M, Ms0) -> Rules = Rules0
        ; R1 = R.put(must, [M|Ms0]), nth0(I, Rules0, _, Rest), nth0(I, Rules, R1, Rest) )
    ;   Rules = Rules0
    ).

:- dynamic scope_decl/3, scope_def/4, enum/2, struct/2, test_scope/1, heading_at/4, note/1, file_text/2,
           subject_field/3, spec/5, spec_done/4, topdef/3.

%   A function of a value (`traitement_aide_finale dépend de aide_finale`):
%   for each argument it is called with, its rules with the argument in
%   place of the parameter, named after both (*le traitement aide finale de
%   aide finale formule initiale*); the calls are found while the rules are
%   written, so this runs until no call asks for a new one.
spec_fixpoint(Mid, Rules0, Rules) :-
    findall(S-P-F-K-A, ( spec(S, P, F, K, A), \+ spec_done(S, P, F, K) ), New0), sort(New0, New),
    (   New == []
    ->  Rules = Rules0
    ;   forall(member(S-P-F-K-_, New), assertz(spec_done(S, P, F, K))),
        findall(R, ( member(S-P-F-K-A, New), spec_rules(Mid, S, P, F, K, A, R) ), Rs),
        append(Rules0, Rs, Rules1),
        spec_fixpoint(Mid, Rules1, Rules)
    ).

spec_rules(Mid, S, P, F, K, ArgText, Rule) :-
    scope_decl(S, Lang, Ds), memberchk(var(F, IO, _, Type, [Pm-_], States, _), Ds),
    ( var_defs(S, [F], Defs0) -> true ; Defs0 = [] ),
    memberchk(var(F, _, _, _, [Pm-PT], _, _), Ds),
    subst_each(Defs0, Pm, argref(ArgText, PT), Defs1),     % (no yall lambda: its free variables are not the clause's)
    (   States == []
    ->  spec_name(P, F, none, [], K, Name),
        var_rule(Mid, Lang, ctx(S, P), Name, IO, Type, [], [], Defs1, Rule)
    ;   nth1(I, States, St),
        spec_name(P, F, St, States, K, Name),
        include(def_in_state(St), Defs1, Defs),
        (   I > 1 -> I0 is I - 1, nth1(I0, States, St0), spec_name(P, F, St0, States, K, Prev) ; Prev = none ),
        b_setval(catala_state, F-Prev),
        var_rule(Mid, Lang, ctx(S, P), Name, IO, Type, [], [], Defs, Rule0),
        Rule = Rule0.put(memorable, true),
        b_setval(catala_state, none)
    ).

%   The rule of function F, in state St, for the argument K: F's name (and
%   the state's, but the last), `de` (`of` in English) and the argument's.
spec_name(P, F, St, States, K, Name) :-
    (   ( St == none ; last(States, St) ) -> atom_concat(P, F, B) ; format(atom(B), '~w~w_~w', [P, F, St]) ),
    ( scope_lang(fr) -> W = de ; W = of ),
    format(atom(Name), '~w_~w_~w', [B, W, K]).

scope_lang(L) :- nb_current(catala_lang, L0), !, L = L0.

%   A call of a function of a value: the rule for its argument (asked for).
spec_call(ctx(S, P), F, ArgText, ArgKey, T) :-
    (   spec(S, P, F, ArgKey, ArgText) -> true ; assertz(spec(S, P, F, ArgKey, ArgText)) ),
    scope_decl(S, _, Ds), memberchk(var(F, _, _, _, _, States, _), Ds),
    ( States == [] -> St = none ; last(States, St) ),
    spec_name(P, F, St, States, ArgKey, T0), atom_string(T0, T).

%   A value function of the scope (or of a sub-scope instance), with one
%   parameter of a plain type.
value_function(S, F) :-
    scope_decl(S, _, Ds), memberchk(var(F, _, _, _, [_-PT], _, _), Ds),
    \+ PT = list(_), \+ ( PT = named(_, St), struct(St, _) ).

%   A function of a structure: its rule is about an individual of that
%   structure (subject_param/2), so a call of it on that same individual is
%   its name alone.
struct_function(S, F, St) :-
    scope_decl(S, _, Ds), memberchk(var(F, _, _, _, [_-named(_, St)], _, _), Ds),
    struct(St, _).

%   The declarations and definitions of every file, by scope.
collect(LIs) :-
    retractall(scope_decl(_, _, _)), retractall(scope_def(_, _, _, _)),
    retractall(enum(_, _)), retractall(struct(_, _)), retractall(test_scope(_)), retractall(topdef(_, _, _)),
    retractall(heading_at(_, _, _, _)),
    forall(member(F-Lang-I, LIs), collect_item(F, Lang, I)).

collect_item(F, _, heading(L, T, N)) :- !, assertz(heading_at(F, N, L, T)).
collect_item(F, Lang, code(_, CIs, _)) :- !, forall(member(CI, CIs), collect_code(F, Lang, CI)).
collect_item(_, _, _).

collect_code(_, Lang, scope_decl(S, Ds, As, _)) :- !,
    assertz(scope_decl(S, Lang, Ds)),
    ( memberchk(test, As) -> assertz(test_scope(S)) ; true ).
collect_code(F, _, scope_use(S, SC, Items, _, _)) :- !,
    forall(member(I, Items), assertz(scope_def(S, SC, I, F))).
collect_code(_, _, enum_decl(E, Cs, _)) :- !, assertz(enum(E, Cs)).
collect_code(_, _, struct_decl(S, Fs, _)) :- !, assertz(struct(S, Fs)).
collect_code(_, _, topdef(N, _, Ps, X, _)) :- X \== none, !, assertz(topdef(N, Ps, X)).
collect_code(_, _, _).

%   A programme of several scopes: each scope's names led by the scope's,
%   so that two scopes' variables of one name stay two (section 121: one
%   person, two persons).
root_prefix([_], _, '') :- !.
root_prefix(_, S, P) :- scope_snake(S, N), atom_concat(N, '_', P).

scope_snake(S, N) :-
    atom_codes(S, Cs), snake(Cs, Ds), atom_codes(N0, Ds), downcase_atom(N0, N).
snake([], []).
snake([C|Cs], Out) :- ( code_type(C, upper), Cs \== [] -> true ; true ), snake_(Cs, C, Out).
snake_([], C, [C]).
snake_([D|Ds], C, [C, 0'_|Out]) :- code_type(D, upper), \+ code_type(C, upper), !, snake_(Ds, D, Out).
snake_([D|Ds], C, [C|Out]) :- snake_(Ds, D, Out).

sort_rules(Rs0, Rs) :- predsort([O, A, B]>>( get_dict(name, A, NA), get_dict(name, B, NB), compare(O, NA-A, NB-B) ), Rs0, Rs).


		 /*******************************
		 *            SCOPES            *
		 *******************************/

%   The rules of a scope, its names prefixed by P (the sub-scope instances
%   that lead to it): an input is declared with its type, a variable with
%   definitions is a rule. Feed: the variables the calling scope defines for
%   this instance (Var-Defs-CallerCtx), whose definitions replace the
%   scope's own. A sub-scope instance (`x scope S2`) brings S2's rules,
%   prefixed with `x_`.
scope_rules(Mid, S, P, Feed, Rule) :-
    scope_decl(S, Lang, Ds),
    (   member(var(V, IO, _Out, Type, Ps, States, _), Ds),
        atom_concat(P, V, Name),
        (   memberchk(V-CDefs-CCtx, Feed), structured(Type)
        ->  leaf_var_rule(Mid, Lang, CCtx, Name, internal, Type, CDefs, Rule, S)
        ;   memberchk(V-CDefs-CCtx, Feed)
        ->  %  (a sub-scope's input the calling scope defines: a value of the
            %  caller's, which no test replaces)
            var_rule(Mid, Lang, CCtx, Name, internal, Type, [], [], CDefs, Rule)
        ;   IO == input, structured(Type), \+ Type = list(_), \+ var_defs(S, [V], _)
        ->  %  a structure, or an enumeration whose cases carry values: an
            %  input per leaf (roadmap §8, Phase 3c work left, item 4)
            leaf(Type, Segs, LT), leaf_name(Name, Segs, LT, LN, Ent), leaf_dtype(LT, DT),
            (   Ent == none -> Rule = _{name: LN, kind: input, dtype: DT, catala_scope: S}
            ;   Rule = _{name: LN, kind: input, dtype: DT, entity: Ent, catala_scope: S}
            )
        ;   structured(Type), Ps == [], var_defs(S, [V], Defs)
        ->  %  a variable whose value is a structure: a rule per leaf, its
            %  definitions projected on the leaf
            leaf_var_rule(Mid, Lang, ctx(S, P), Name, IO, Type, Defs, Rule, S)
        ;   IO == input, Type = list(named(_, St)), struct(St, _), \+ var_defs(S, [V], _)
        ->  %  a list of structures: each element an individual of the
            %  structure's type, and its being in the list a fact about it
            %  (roadmap §8, Phase 3c work left, item 2(a))
            atom_concat(is_in_, Name, JN),
            Rule = _{name: JN, kind: input, dtype: 'Judgment', entity: St, catala_scope: S}
        ;   Type = list(named(_, St)), struct(St, _), var_defs(S, [V], Defs),
            filter_of_defs(Defs, Src, El, Cond)
        ->  %  a list filtered from another (`liste de x parmi l tel que c`):
            %  a judgment of each element — it is in the list the filter
            %  reads, and the condition holds of it. The list itself is
            %  never a value here, so nothing else needs its elements in an
            %  order (Phase 3c work left, 9 October).
            atom_concat(is_in_, Name, FN),
            filter_rule(Lang, ctx(S, P), FN, St, Src, El, Cond, Defs, Rule, S)
        ;   Ps = [_-list(_)]
        ->  fail                % a function of a list: inlined where it is called
        ;   Ps = [_-PT], \+ ( PT = named(_, St0), struct(St0, _) )
        ->  fail                % a function of a value: one rule per argument it is called with (spec_rules)
        ;   IO == input, \+ var_defs(S, [V], _)
        ->  input_rules(S, Name, Type, Rule)
        ;   States = [St1|_], IO == input
        ->  %  an input defined in states: the first state is the input,
            %  each later one a rule reading the state before it
            state_name(P, V, St1, States, N1),
            (   Rule = _{name: N1, kind: input, dtype: DT1, catala_scope: S}, dtype(Type, DT1)
            ;   ( var_defs(S, [V], Defs0) -> true ; Defs0 = [] ),
                nth1(K, States, St), K > 1,
                state_name(P, V, St, States, SName),
                include(def_in_state(St), Defs0, Defs),
                K0 is K - 1, nth1(K0, States, St0), state_name(P, V, St0, States, Prev),
                b_setval(catala_state, V-Prev),
                var_rule(Mid, Lang, ctx(S, P), SName, internal, Type, Ps, [], Defs, Rule),
                b_setval(catala_state, none)
            )
        ;   States \== []
        ->  %  a variable defined in states: one rule per state, each
            %  reading the state before it; the last state has the
            %  variable's own name (roadmap §8, Phase 3c work left, item 5)
            ( var_defs(S, [V], Defs0) -> true ; Defs0 = [] ),
            nth1(K, States, St),
            state_name(P, V, St, States, SName),
            include(def_in_state(St), Defs0, Defs),
            (   K > 1 -> K0 is K - 1, nth1(K0, States, St0), state_name(P, V, St0, States, Prev) ; Prev = none ),
            b_setval(catala_state, V-Prev),
            var_rule(Mid, Lang, ctx(S, P), SName, IO, Type, Ps, [], Defs, Rule),
            b_setval(catala_state, none)
        ;   ( var_defs(S, [V], Defs) -> true ; Defs = [] ),
            ( IO == context, nb_current(catala_in_sub, true) -> IO1 = internal ; IO1 = IO ),
            var_rule(Mid, Lang, ctx(S, P), Name, IO1, Type, Ps, States, Defs, Rule)
        )
    ;   member(sub(Sub, scoped(_, S2), _, _), Ds),
        findall(Var-SDefs-ctx(S, P), ( scope_decl(S2, _, D2s), member(var(Var, _, _, _, _, _, _), D2s),
                                       var_defs(S, [Sub, Var], SDefs) ), Feed2),
        format(atom(P2), '~w~w_', [P, Sub]),
        b_setval(catala_in_sub, true),          % (its context variables are the caller's to replace)
        scope_rules(Mid, S2, P2, Feed2, Rule)
    ).

eqs(TE, Cs, T) :-
    findall(Q, ( member(C, Cs), format(string(Q), "(~w == '~w')", [TE, C]) ), Qs),
    atomic_list_concat(Qs, ' or ', T0), format(string(T), "(~w)", [T0]).

%   The name of a function's argument in its rule's name: the variable it
%   is, without the scope's prefix; any other expression, a number of its own.
arg_key(id([], A, none), _, A) :- !.
arg_key(_, TX, K) :- term_hash(TX, H), K0 is H mod 10000, format(atom(K), 'valeur_~w', [K0]).

%   A type whose values are more than one fact: a structure, an
%   enumeration with a case that carries a value, a list of structures.
structured(named(_, St)) :- struct(St, _), !.
structured(named(_, E)) :- enum(E, Cs), member(case(_, CT), Cs), CT \== none, !.
structured(list(named(_, St))) :- struct(St, _).

%   leaf(+Type, -Segments, -LeafType): the facts a value of Type is made of,
%   each named by the fields (and cases) that lead to it: the case of an
%   enumeration is a leaf ([]), the value its case carries is under the
%   case's name; a list of structures is a leaf, a fact of each element.
leaf(named(_, E), Segs, T) :- enum(E, Cs), !,
    (   Segs = [], T = named([], E)
    ;   member(case(C, CT), Cs), CT \== none, leaf(CT, Rest, T), Segs = [C|Rest]
    ).
leaf(named(_, St), [F|Rest], T) :- struct(St, Fs), !,
    member(field(F, FT, []), Fs), leaf(FT, Rest, T).
leaf(T, [], T).

%   A leaf's name: the variable's, then its segments; a list's leaf is a
%   fact of each element (`is_in_…`, of the element's type).
leaf_name(Name, Segs, LT, LN, Ent) :-
    atomic_list_concat([Name|Segs], '_', N0),
    (   LT = list(named(_, St)) -> atom_concat(is_in_, N0, LN), Ent = St ; LN = N0, Ent = none ).

leaf_dtype(list(_), 'Judgment') :- !.
leaf_dtype(T, DT) :- dtype(T, DT).

%   The rules of a variable whose value is structured: for each leaf, the
%   variable's definitions with their values projected on the leaf.
leaf_var_rule(Mid, Lang, Ctx, Name, IO, Type, Defs, Rule, S) :-
    leaf(Type, Segs, LT), leaf_name(Name, Segs, LT, LN, Ent),
    maplist(project_def(Segs), Defs, PDefs),
    (   LT = list(_) -> VT = prim(boolean) ; VT = LT ),
    var_rule(Mid, Lang, Ctx, LN, IO, VT, [], [], PDefs, Rule0),
    (   Ent == none -> Rule1 = Rule0 ; Rule1 = Rule0.put(entity, Ent) ),
    Rule = Rule1.put(catala_scope, S).

project_def(Segs, def(SC, def(L, E, Pa, Ps, St, C, X, N), F), def(SC, def(L, E, Pa, Ps, St, C, proj(X, Segs), N), F)).

%!  proj_text(+Lang, +Ctx, +Expr, +Segments, -Text) is semidet.
%
%   The leaf Segments of a structured value: pushed through a match (each
%   arm's value projected, the value its case carries bound), an if, a
%   structure built, a case built; at a name, the name of its leaf. Fails
%   for a leaf the value does not have (a case not chosen).
proj_text(L, C, match(E, Arms), Segs, T) :- !,
    expr_text(L, C, E, TE),
    findall(AT, ( member(A, Arms), proj_arm(L, C, E, A, Segs, AT) ), ATs), ATs \== [],
    atomic_list_concat(ATs, ' ', AT), format(string(T), "(match ~w: ~w)", [TE, AT]).
proj_text(L, C, if(Co, A, B), Segs, T) :- !,
    expr_text(L, C, Co, TC),
    (   proj_text(L, C, A, Segs, TA)
    ->  ( proj_text(L, C, B, Segs, TB) -> format(string(T), "(if ~w: ~w else: ~w)", [TC, TA, TB]) ; format(string(T), "(if ~w: ~w)", [TC, TA]) )
    ;   proj_text(L, C, B, Segs, TB), format(string(T), "(if (not ~w): ~w)", [TC, TB])
    ).
proj_text(L, C, struct(_, _, Fs), [F|Rest], T) :- !, memberchk(F-X, Fs), proj_text(L, C, X, Rest, T).
proj_text(_, _, inject(_, K, _), [], T) :- !, format(string(T), "'~w'", [K]).
proj_text(L, C, inject(_, K, X), [K|Rest], T) :- !, X \== none, proj_text(L, C, X, Rest, T).
proj_text(_, _, inject(_, _, _), _, _) :- !, fail.
proj_text(_, _, id(P, K, _), [], T) :- P \== [], enum_constr(K), !, format(string(T), "'~w'", [K]).
proj_text(_, _, list([]), [], "false") :- !.
proj_text(L, C, dot(E, [], F), Segs, T) :- !, proj_text(L, C, E, [F|Segs], T).
proj_text(L, C, contentof(E, K), Segs, T) :- !, proj_text(L, C, E, [K|Segs], T).
proj_text(L, C, let([X], E1, E2), Segs, T) :- !, subst(E2, X, E1, E3), proj_text(L, C, E3, Segs, T).
proj_text(_, ctx(S, P), id([], V, none), Segs, T) :-
    scope_decl(S, _, Ds), memberchk(var(V, _, _, VT, _, _, _), Ds), !,
    atom_concat(P, V, Base), leaf_of(VT, Segs, LT),
    leaf_name(Base, Segs, LT, LN, _), atom_string(LN, T).
proj_text(L, C, X, [], T) :- expr_text(L, C, X, T).

%!  filter_of_defs(+Defs, -Src, -Element, -Condition) is semidet.
%
%   Every definition of the variable is the same filter of one list, with
%   no condition of its own. `aides_logement` writes it twice, as two
%   exceptions of one label; where the definitions differ the variable is
%   left as it was, residue with its reason.
filter_of_defs(Defs, Src, El, Cond) :-
    Defs = [D|Ds],
    filter_def(D, Src, El, Cond),
    forall(member(D2, Ds), ( filter_def(D2, Src2, El2, Cond2), Src2 == Src, El2 == El, Cond2 =@= Cond )).

filter_def(def(_, def(_, _, _, [], _, none, filter([El], Src, Cond), _), _), Src, El, Cond).

%!  filter_rule(+Lang, +Ctx, +Name, +Entity, +Src, +El, +Cond, +Defs, -Rule, +Scope) is semidet.
%
%   The judgment a filtered list becomes: an individual of Entity is in it
%   when it is in the list the filter reads and the filter's condition holds
%   of it. The condition is read with the element as the subject of the
%   sentence, as the body of a sum over a list is.
filter_rule(Lang, Ctx, Name, St, Src, El, Cond, Defs, Rule, S) :-
    list_leaf(Lang, Ctx, Src, St, SrcPred),
    b_getval(catala_element, Saved),
    b_setval(catala_element, El-St),
    catch(( expr_text(Lang, Ctx, Cond, TC) -> true ; TC = none ), lower_residue(_), TC = none),
    b_setval(catala_element, Saved),
    TC \== none,
    format(string(Formula), "(~w and ~w)", [SrcPred, TC]),
    findall(T, ( member(def(_, I1, F1), Defs), arg(8, I1, L1), source_text(F1, L1, T), T \== "" ), Ts0),
    list_to_set(Ts0, Ts), atomic_list_concat(Ts, '; ', SrcA), atom_string(SrcA, Source),
    Base = _{name: Name, kind: derived, dtype: 'Judgment', entity: St, source: Source,
             catala_scope: S, versions: [_{effective_from: '1900-01-01', formula: Formula}]},
    (   Defs = [def(_, _, FI)|_] -> Rule = Base.put(catala_file, FI) ; Rule = Base ).

%!  list_leaf(+Lang, +Ctx, +Expr, -Entity, -Pred) is semidet.
%
%   Expr is a list of structures — an input of the scope, or a field of a
%   structured one: Entity is the structure its elements are, Pred the
%   judgment that says an individual is in the list.
list_leaf(L, S, E, St, Pred) :-
    path_type(S, E, list(named(_, St))),
    struct(St, _),
    proj_text(L, S, E, [], Pred0),
    atom_string(Pred, Pred0).

%   A sub-scope's output: dot(id(Sub), F), F's leaf in the sub-scope.
proj_arm(L, C, E, arm(_, K, Ids, B), Segs, T) :-
    (   Ids = [Id] -> subst(B, Id, contentof(E, K), B1) ; B1 = B ),
    proj_text(L, C, B1, Segs, TB), format(string(T), "'~w' => ~w", [K, TB]).
proj_arm(L, C, _, wildcard(B), Segs, T) :-
    proj_text(L, C, B, Segs, TB), format(string(T), "_ => ~w", [TB]).

%   The leaf type at the end of Segments of Type.
leaf_of(T, [], T) :- !.
leaf_of(named(_, St), [F|Rest], LT) :- struct(St, Fs), memberchk(field(F, FT, _), Fs), !, leaf_of(FT, Rest, LT).
leaf_of(named(_, E), [K|Rest], LT) :- enum(E, Cs), memberchk(case(K, CT), Cs), CT \== none, leaf_of(CT, Rest, LT).

%   The type of a path into a structured value (a field, the value a case
%   carries).
path_type(ctx(S, _), id([], V, none), T) :- scope_decl(S, _, Ds), memberchk(var(V, _, _, T, _, _, _), Ds), !.
path_type(C, dot(E, [], F), T) :- path_type(C, E, ET), leaf_of(ET, [F], T).
path_type(C, contentof(E, K), T) :- path_type(C, E, ET), leaf_of(ET, [K], T).

%   A path into a structured value, as an expression: its leaf's name.
struct_path(dot(E, [], _)) :- ( E = contentof(_, _) ; struct_path(E) ; E = id([], _, none) ), !.

%   The name of a state of variable V: the last state is V itself (the
%   value the variable has outside its scope's definitions), each earlier
%   one V followed by the state's name.
state_name(P, V, St, States, Name) :-
    (   last(States, St) -> atom_concat(P, V, Name)
    ;   format(atom(Name), '~w~w_~w', [P, V, St])
    ).

def_in_state(St, def(_, I, _)) :- arg(5, I, St0), St0 == St.

var_defs(S, Path, Defs) :-
    findall(def(SC, I, F), ( scope_def(S, SC, I, F), item_var(I, Path) ), Defs), Defs \== [].

item_var(def(_, _, P, _, _, _, _, _), P).
item_var(rule(_, _, P, _, _, _, _, _), P).

%   An input, with its type (a structure: one input per field).
input_rules(S, N0, named(_, St), Rule) :-
    struct(St, Fs), !,
    member(field(F, T, []), Fs), dtype(T, DT), format(atom(N), '~w_~w', [N0, F]),
    Rule = _{name: N, kind: input, dtype: DT, catala_scope: S}.
input_rules(S, N, Type, _{name: N, kind: input, dtype: DT, catala_scope: S}) :-
    dtype(Type, DT).

var_rule(Mid, Lang, Ctx, V, IO, Type, Ps, States, Defs, Rule) :-
    dtype(Type, DT),
    findall(T, ( member(def(_, I1, F1), Defs), arg(8, I1, L1), source_text(F1, L1, T), T \== "" ), Ts0),
    list_to_set(Ts0, Ts), atomic_list_concat(Ts, '; ', SrcA), atom_string(SrcA, Src),
    subject_param(Ps, Subj),
    b_setval(catala_subject, Subj),
    (   catch(var_formula(Lang, Ctx, V, Type, Ps, States, Defs, F, Musts0),
              lower_residue(Why), ( F = none, R = Why ))
    ->  true
    ;   F = none, R = "a definition this translator does not read"
    ),
    ( var(Musts0) -> Musts = [] ; Musts = Musts0 ),
    b_setval(catala_subject, none),
    Ctx = ctx(S, _),
    (   Subj = _-St -> Base00 = _{name: V, kind: derived, dtype: DT, source: Src, catala_scope: S, entity: St}
    ;   Base00 = _{name: V, kind: derived, dtype: DT, source: Src, catala_scope: S}
    ),
    (   Type == prim(duration) -> Base0 = Base00.put(unit, "months") ; Base0 = Base00 ),
    (   Defs = [def(_, _, FI)|_] -> Base = Base0.put(catala_file, FI) ; Base = Base0 ),
    (   IO == context -> B10 = Base.put(overridable, true) ; B10 = Base ),
    (   F \== none, same_level(Defs)
    ->  (   Musts \== []
        ->  B1 = B10.put(must, Musts).put(approximated,
                "where two of its definitions at one level both apply, Catala stops with a conflict; the twin refuses the case, with that reason")
        ;   B1 = B10.put(approximated,
                "where two of its definitions at one level both apply, Catala stops with a conflict; the twin takes the first")
        )
    ;   B1 = B10
    ),
    (   F == none
    ->  ( var(R) -> R0 = "no definition" ; R0 = R ),
        ( R0 = format(Fm, As) -> format(string(RS), Fm, As) ; format(string(RS), "~w", [R0]) ),
        defs_source(Defs, Code),
        Rule = B1.put(_{versions: [_{effective_from: '1900-01-01', formula: '0'}], residue_reason: RS,
                        catala_source: Code})
    ;   Rule = B1.put(versions, [_{effective_from: '1900-01-01', formula: F}])
    ),
    _ = Mid.

dtype(prim(money), 'Money') :- !.
dtype(prim(decimal), 'Decimal') :- !.
dtype(prim(integer), 'Integer') :- !.
dtype(prim(boolean), 'Judgment') :- !.
dtype(prim(condition), 'Judgment') :- !.
dtype(prim(date), 'Date') :- !.
dtype(prim(duration), 'Integer') :- !.            % a duration in months (item 3)
dtype(named(_, E), 'Text') :- enum(E, _), !.
dtype(named(P, _), 'Text') :- P \== [], !.     % (an enumeration of another module: France.Collectivité)
dtype(_, 'Decimal').

%   Two or more definitions at one level of the exception tree (both
%   unlabelled and no exception, or under one label), each with a condition:
%   where both apply, Catala stops with a conflict.
same_level(Defs) :-
    findall(L-E, ( member(def(_, I, _), Defs), arg(1, I, L), arg(2, I, E) ), LEs),
    msort(LEs, Sorted), append(_, [X, X|_], Sorted), !.

%   The Catala text of a variable's definitions: from each one's first line
%   to the next line indented as little (the next item), or the block's end.
defs_source(Defs, Code) :-
    findall(T, ( member(def(_, I, F), Defs), arg(8, I, L), item_lines(F, L, T) ), Ts),
    atomic_list_concat(Ts, '\n', Code0), atom_string(Code0, Code).

item_lines(F, L, Text) :-
    file_text(F, Ls), nth1(L, Ls, First), indent(First, In),
    L1 is L + 1, findall(X, ( between(L1, 100000, J), ( nth1(J, Ls, X) -> true ; !, fail ) ), Rest),
    take_item(Rest, In, More),
    atomic_list_concat([First|More], '\n', Text).

take_item([], _, []).
take_item([X|Xs], In, Out) :-
    (   ( sub_string(X, _, _, _, "```") ; X \== "", indent(X, I), I =< In, item_start(X) ) -> Out = []
    ;   Out = [X|Out1], take_item(Xs, In, Out1)
    ).

%   A line that begins a new item of the scope (its continuation lines,
%   `consequence fulfilled`, `under condition`, keep the item going).
item_start(X) :-
    split_string(X, " ", " ", Ws0), exclude(==(""), Ws0, [W|_]),
    memberchk(W, ["definition", "rule", "label", "exception", "assertion", "date", "scope",
                  "définition", "règle", "étiquette", "champ", "déclaration", "declaration"]).

indent(S, N) :- string_codes(S, Cs), ( append(Sp, [C|_], Cs), C \== 0'  -> length(Sp, N) ; N = 1000 ).

%   The heading the definition sits under, as the rule's source.
source_text(File, Line, Src) :-
    findall(N-T, ( heading_at(File, N, _, T), N =< Line ), Hs),
    (   last(Hs, _-T) -> format(string(Src), "~w", [T]) ; Src = "" ).


		 /*******************************
		 *          EXCEPTIONS          *
		 *******************************/

%   A variable's formula: its definitions as a cascade, the exceptions to a
%   label before the definitions under it.
%   A definition of one parameter of a structure's type (`définition x de
%   enfant`, `rule f of child`): a rule whose subject is the parameter, an
%   individual of the structure's type with its fields as its inputs
%   (roadmap §8, Phase 3c work left, item 1).
subject_param([P-named(_, St)], P-St) :- struct(St, _), !.
subject_param(_, none).

var_formula(Lang, S, V, Type, Ps, States, Defs, F) :-
    var_formula(Lang, S, V, Type, Ps, States, Defs, F, _).

var_formula(Lang, S, V, Type, Ps, States, Defs, F, Musts) :-
    (   Ps \== [], \+ subject_param(Ps, _-_) -> throw(lower_residue("a function of its parameters")) ; true ),
    (   States \== [] -> throw(lower_residue("a variable defined in states")) ; true ),
    maplist(def_parts, Defs, Parts),
    tree_order(Parts, Ordered),
    (   Type == prim(condition)
    ->  maplist(rule_branch(Lang, S), Ordered, Branches0),
        append(Branches0, [true-"false"], Branches)
    ;   maplist(def_branch(Lang, S), Ordered, Branches)
    ),
    cascade(Branches, F),
    conflict_musts(Lang, S, Parts, Musts),
    _ = V.

%!  conflict_musts(+Lang, +Ctx, +Parts, -Musts) is det.
%
%   Two definitions of one variable at the same level of the exception tree
%   both applying is a conflict: Catala stops there rather than answering,
%   and so must the twin. Each such pair becomes an assertion that their
%   conditions do not hold together — an integrity constraint of the
%   program, which refuses the case instead of taking the first definition
%   (roadmap §8, Phase 3c work left, item 8).
%   Not written yet (item 8 stays open). Two measurements decided it. The
%   pairs are enumerated for every two definitions at one level, and a
%   variable whose law was reissued every year has dozens of them: one rule
%   of `aides_logement` carried 814 constraints. Bounding the level to four
%   definitions left 2, and both were pairs of *dated* versions of one
%   definition — `date_courante` in 2020-10..2021-10 against 2021-10..2022-10
%   — which can never hold together, so they are not conflicts at all. And
%   with them in the program the twin's deepest query (the final aid through
%   its six states) timed out: LE checks every constraint when it answers,
%   and a constraint that re-derives that chain costs what the chain costs.
%   49 of 49 answers with them out, 45 with them in.
%
%   What item 8 needs is a form that states the conflict without paying for
%   it on every answer, and that leaves out the pairs two dated versions of
%   one definition make. Until then the ledger's note stands: where Catala
%   would stop with a conflict, the twin takes the first definition that
%   applies, and says so.
conflict_musts(_, _, _, []).

%   Kept for that work: the pairs of one level, bounded so the enumeration
%   cannot grow with the square of a variable's definitions.
conflict_pairs(Lang, S, Parts, Musts) :-
    findall(L-E, member(p(L, E, _, _, _), Parts), Levels0), sort(Levels0, Levels),
    findall(M, ( member(L-E, Levels), level_conflicts(Lang, S, Parts, L, E, M) ), Ms0),
    list_to_set(Ms0, Musts).

%   The definitions of one variable at one level of the tree. A variable whose
%   law was reissued every year has dozens of them, and they are *dated*: two
%   can never apply at once, so the pairs are not conflicts, and enumerating
%   them all gave one rule of `aides_logement` 814 constraints — a twin whose
%   deepest answers then timed out. Only a level small enough for its pairs to
%   be worth stating is written; a larger one keeps the ledger's note that the
%   twin takes the first definition where Catala would stop.
%   (roadmap §8, Phase 3c work left, item 8: a form that does not grow with
%   the square of a variable's definitions is still to find.)
level_conflicts(Lang, S, Parts, L, E, M) :-
    findall(c(SC, C), ( member(p(L2, E2, cond(SC, C), _, _), Parts), L2 == L, E2 == E ), Cs),
    length(Cs, NC), NC =< 4,
    member(c(SC1, C1), Cs), member(c(SC2, C2), Cs),
    ( SC1-C1 ) @< ( SC2-C2 ),
    catch(branch_cond(Lang, S, SC1, C1, T1), _, fail),
    catch(branch_cond(Lang, S, SC2, C2, T2), _, fail),
    T1 \== "true", T2 \== "true", T1 \== T2,
    format(string(M), "not (~w and ~w)", [T1, T2]).

def_parts(def(SC, def(L, E, _, _, _, C, X, N), _), p(L, E, cond(SC, C), value(X), N)).
def_parts(def(SC, rule(L, E, _, _, _, C, B, N), _), p(L, E, cond(SC, C), fulfilled(B), N)).

%   The exception tree in evaluation order: for each label (the unlabelled
%   base first), the exceptions to it (recursively) and then its own
%   definitions.
tree_order(Parts, Ordered) :-
    include([p(none, none, _, _, _)]>>true, Parts, Base0),
    findall(L, member(p(L, _, _, _, _), Parts), Ls0), sort(Ls0, Ls),
    (   Base0 \== []
    ->  group_order('$base', Parts, Ordered0)
    ;   Ordered0 = []
    ),
    findall(O, ( member(L, Ls), L \== none, \+ ( member(p(L, E, _, _, _), Parts), E \== none ),
                 group_order(L, Parts, O) ), Os),
    append([Ordered0|Os], Ordered1),
    list_to_set(Ordered1, Ordered).

%   A group: the definitions labelled L (base: unlabelled, not exceptions)
%   with the groups that are exceptions to it before them.
group_order(G, Parts, Ordered) :-
    (   G == '$base'                  % (the unlabelled definitions; a label may be called `base`)
    ->  include([p(none, none, _, _, _)]>>true, Parts, Own),
        findall(P, ( member(P, Parts), P = p(_, unlabeled, _, _, _) ), Excs0)
    ;   include(labelled(G), Parts, Own),
        findall(P, ( member(P, Parts), P = p(_, to(G), _, _, _) ), Excs0)
    ),
    findall(O, ( member(p(L1, _, _, _, _), Excs0), L1 \== none, group_order(L1, Parts, O) ), Labelled),
    include([p(none, _, _, _, _)]>>true, Excs0, Unlabelled),
    append(Labelled, LO), append([LO, Unlabelled, Own], Ordered).

labelled(G, p(L, _, _, _, _)) :- L == G.

def_branch(Lang, S, p(_, _, cond(SC, C), value(X), _), Cond-Val) :-
    branch_cond(Lang, S, SC, C, Cond),
    expr_text(Lang, S, X, Val).

rule_branch(Lang, S, p(_, _, cond(SC, C), fulfilled(B), _), Cond-Val) :- !,
    branch_cond(Lang, S, SC, C, Cond),
    ( B == true -> Val = "true" ; Val = "false" ).
rule_branch(Lang, S, p(_, _, cond(SC, C), value(X), _), Cond-Val) :-      % a condition defined `equals` another
    branch_cond(Lang, S, SC, C, Cond),
    expr_text(Lang, S, X, Val).

branch_cond(Lang, S, SC, C, Cond) :-
    findall(X, ( member(X, [SC, C]), X \== none ), Cs),
    (   Cs == [] -> Cond = true
    ;   maplist(expr_text(Lang, S), Cs, Ts), atomic_list_concat(Ts, ' and ', Cond0),
        format(string(Cond), "(~w)", [Cond0])
    ).

%   if c1: v1 elif c2: v2 … [else: v] — an unconditional branch ends it.
cascade([true-V|_], V) :- !.
cascade([C-V], F) :- !, format(string(F), "(if ~w: ~w)", [C, V]).
cascade([C-V|Bs], F) :- cascade_rest(Bs, Rest), format(string(F), "(if ~w: ~w~w)", [C, V, Rest]).

cascade_rest([], "").
cascade_rest([true-V|_], R) :- !, format(string(R), " else: ~w", [V]).
cascade_rest([C-V|Bs], R) :- cascade_rest(Bs, R1), format(string(R), " elif ~w: ~w~w", [C, V, R1]).


		 /*******************************
		 *          EXPRESSIONS         *
		 *******************************/

%   An expression as RuleSpec formula text (rulespec_reader:parse_formula).
expr_text(_, _, lit(L), T) :- !, lit_text(L, T).
expr_text(_, ctx(_, P), id([], V, none), T) :-        % inside a state's definition: the state before
    nb_current(catala_state, V0-Prev), V0 == V, Prev \== none, !, T = Prev, _ = P.
expr_text(_, ctx(S, P), id([], V, St), T) :- St \== none,       % a state named
    scope_decl(S, _, Ds), memberchk(var(V, _, _, _, _, States, _), Ds), memberchk(St, States), !,
    state_name(P, V, St, States, T).
expr_text(_, ctx(_, P), id([], V, none), T) :- !, atom_concat(P, V, T).
expr_text(_, _, id(P, C, _), T) :- P \== [], enum_constr(C), !, format(string(T), "'~w'", [C]).
expr_text(_, _, inject(_, C, none), T) :- !, format(string(T), "'~w'", [C]).
expr_text(_, ctx(_, P), dot(id([], V, none), [], F), T) :-       % a field of the subject
    b_getval(catala_subject, V0-St), V == V0, struct(St, Fs), memberchk(field(F, FT, _), Fs), !,
    T0 = F, atom_string(T0, T), _ = P,          % (a structure's field is the structure's, in every scope)
    ( subject_field(St, T0, _) -> true ; dtype(FT, DT), assertz(subject_field(St, T0, DT)) ).
%   the output of a scope called with its inputs, whose output is one
%   definition without conditions: that definition, its inputs replaced by
%   the arguments (France.VérificationÂgeSupérieurÀ)
expr_text(L, S, dot(scope_call(_, Sc, Args), [], Out), T) :-
    scope_decl(Sc, _, _),
    findall(X, scope_def(Sc, none, def(none, none, [Out], [], none, none, X, _), _), [X0]), !,
    foldl(subst_arg, Args, X0, X),
    (   scope_def(Sc, none, date_rounding(_, _), _) -> assertz(note(rounding(Sc))) ; true ),
    expr_text(L, S, X, T).
%   f of l, f a function of a list whose definition is the sum of a map over
%   its list, l a list input: the sum over the elements of l
expr_text(L, ctx(S, P), call(id([], F, none), [id([], LV, none)]), T) :-
    scope_decl(S, _, Ds), memberchk(var(F, _, _, _, [Pm-list(named(_, St))], _, _), Ds),
    memberchk(var(LV, input, _, list(named(_, St)), _, _, _), Ds),
    findall(X, scope_def(S, none, def(none, none, [F], [Pm], none, none, X, _), _), [Def]),
    (   Def = sum(_, map([El], id([], Pm, none), Body))
    ;   Def = call(id(_, sum, none), [map([El], id([], Pm, none), Body)])     % Duration.sum, Money.sum
    ), !,
    atom_concat(P, LV, LN), atom_concat(is_in_, LN, Pred),
    b_getval(catala_element, Saved),
    b_setval(catala_element, El-St),
    expr_text(L, ctx(S, P), Body, TB),
    b_setval(catala_element, Saved),
    format(string(T), "sum_over(~w, ~w, ~w)", [St, Pred, TB]).
%   `nombre de l`, l a list of structures: the count of the individuals the
%   list's membership judgment holds of. A list of structures is a fact of
%   each of its elements (`is_in_…`, leaf_name/5), so its cardinality is a
%   count over them, as the sum of a map over it is a sum over them.
expr_text(L, S, call(builtin(cardinal), [E]), T) :-
    list_leaf(L, S, E, St, Pred), !,
    format(string(T), "count_over(~w, ~w)", [St, Pred]).
expr_text(_, ctx(_, P), dot(id([], V, none), [], F), T) :-       % a field of a list's element
    b_getval(catala_element, V0-St), V == V0, struct(St, Fs), memberchk(field(F, FT, _), Fs), !,
    T0 = F, atom_string(T0, T), _ = P,
    ( subject_field(St, T0, _) -> true ; dtype(FT, DT), assertz(subject_field(St, T0, DT)) ).
%   a function of a structure, called with the individual the rule is about
%   (the element of a list a filter or a sum walks, or the subject of the
%   sentence): its own name, since its rule is about that individual too
expr_text(_, ctx(S, P), call(id([], F, none), [id([], X, none)]), T) :-
    struct_function(S, F, St),
    (   b_getval(catala_element, X0-St0) -> true ; b_getval(catala_subject, X0-St0) ),
    X0 \== none, X == X0, St0 == St, !,
    atom_concat(P, F, T0), atom_string(T0, T).
expr_text(_, _, argref(T, _), T) :- !.
%   a function the program declares outside its scopes, called: its
%   expression, the arguments in place of its parameters
expr_text(L, S, call(id(_, F, none), Args), T) :-
    topdef(F, Ps, X), length(Ps, N), length(Args, N), !,
    subst_params(Ps, Args, X, X1),
    expr_text(L, S, X1, T).
%   the year of a date: the whole years from 1900 to it, and 1900
expr_text(L, S, call(id(['Date'], Y, none), [D]), T) :- memberchk(Y, [accès_année, get_year]), !,
    expr_text(L, S, D, TD), format(string(T), "(whole_years(date(\"1900-01-01\"), ~w) + 1900)", [TD]).
%   conversions (décimal de, argent de): the value; money to the cent
expr_text(L, S, call(id([], C, none), [X]), T) :- memberchk(C, [décimal, decimal, entier, integer]), !, expr_text(L, S, X, T).
expr_text(L, S, call(id([], C, none), [X]), T) :- memberchk(C, [argent, money]), !,
    expr_text(L, S, X, TX), format(string(T), "round(~w, 2)", [TX]).
%   inside a state of function F: F of the argument is its state before
expr_text(_, _, call(id([], F, none), [_]), T) :-
    nb_current(catala_state, F0-Prev), F0 == F, Prev \== none, !, atom_string(Prev, T).
%   a function of a value called: its rule for that argument
expr_text(L, ctx(S, P), call(id([], F, none), [X]), T) :- value_function(S, F), !,
    expr_text(L, ctx(S, P), X, TX), arg_key(X, TX, K), spec_call(ctx(S, P), F, TX, K, T).
expr_text(L, ctx(S, P), call(dot(id([], Sub, none), [], F), [X]), T) :-
    scope_decl(S, _, Ds), memberchk(sub(Sub, scoped(_, S2), _, _), Ds), value_function(S2, F), !,
    expr_text(L, ctx(S, P), X, TX), arg_key(X, TX, K), format(atom(P2), '~w~w_', [P, Sub]),
    spec_call(ctx(S2, P2), F, TX, K, T).
expr_text(L, S, proj(X, Segs), T) :- !,
    (   proj_text(L, S, X, Segs, T) -> true ; throw(lower_residue("a value with no such field")) ).
%   a field of a structured value (a value a case carries, a structure in
%   a structure): its leaf
expr_text(L, S, dot(E, [], F), T) :-
    ( E = contentof(_, _) ; E = dot(_, _, _) ; E = id([], V, none), S = ctx(Sc, _), scope_decl(Sc, _, Ds),
      memberchk(var(V, _, _, VT, _, _, _), Ds), structured(VT) ),
    path_type(S, dot(E, [], F), _), !,
    proj_text(L, S, dot(E, [], F), [], T).
%   `x with pattern C content y and …`: the case, and y the value it carries
%   in what follows
expr_text(L, S, binop(and, test_case(E, _, C, [Id]), R), T) :- !,
    expr_text(L, S, E, TE), subst(R, Id, contentof(E, C), R1), expr_text(L, S, R1, TR),
    format(string(T), "((~w == '~w') and ~w)", [TE, C, TR]).
%   a date less a date compared with years or months: the later date
%   compared with the earlier one moved by them
expr_text(L, S, binop(Op, binop(sub, A, B), lit(dur(N, U))), T) :-
    memberchk(Op, [lte, lt, gte, gt]), memberchk(U, [year, month]),
    expr_type(S, A, date), expr_type(S, B, date), !,
    ( U == year -> M is N * 12 ; M = N ), binop_text(Op, O),
    expr_text(L, S, A, TA), expr_text(L, S, B, TB),
    format(string(T), "(~w ~w add_months(~w, ~w))", [TA, O, TB, M]).
%   a date less a date: the days from the one to the other
expr_text(L, S, binop(sub, A, B), T) :- expr_type(S, A, date), expr_type(S, B, date), !,
    expr_text(L, S, A, TA), expr_text(L, S, B, TB), format(string(T), "days_between(~w, ~w)", [TB, TA]).
%   a date and a duration: the date the duration's months after it
expr_text(L, S, binop(add, A, B), T) :- expr_type(S, B, duration), !,
    expr_text(L, S, A, TA), expr_text(L, S, B, TB), format(string(T), "add_months(~w, ~w)", [TA, TB]).
expr_text(L, S, binop(sub, A, B), T) :- expr_type(S, B, duration), expr_type(S, A, date), !,
    expr_text(L, S, A, TA), expr_text(L, S, B, TB), format(string(T), "add_months(~w, (0 - ~w))", [TA, TB]).
expr_text(L, ctx(S, P), dot(id([], V, none), [], F), T) :- !,
    (   ( sub_instance(S, V) ; input_struct_field(S, V, F) ) -> format(string(T), "~w~w_~w", [P, V, F])
    ;   throw(lower_residue(format("the field ~w of ~w, a structure", [F, V])))
    ), _ = L.
expr_text(L, S, binop(Op, A, B), T) :- binop_text(Op, O), !,
    expr_text(L, S, A, TA), expr_text(L, S, B, TB),
    (   memberchk(Op, [mult, div]), expr_type(S, binop(Op, A, B), money)
    ->  format(string(T), "round((~w ~w ~w), 2)", [TA, O, TB])      % (Catala rounds an amount to the cent)
    ;   format(string(T), "(~w ~w ~w)", [TA, O, TB])
    ).
expr_text(L, S, binop(xor, A, B), T) :- !,
    expr_text(L, S, A, TA), expr_text(L, S, B, TB),
    format(string(T), "((~w and (not ~w)) or ((not ~w) and ~w))", [TA, TB, TA, TB]).
expr_text(L, S, unop(not, A), T) :- !, expr_text(L, S, A, TA), format(string(T), "(not ~w)", [TA]).
expr_text(L, S, unop(minus, A), T) :- !, expr_text(L, S, A, TA), format(string(T), "(0 - ~w)", [TA]).
expr_text(L, S, if(C, A, B), T) :- !,
    expr_text(L, S, C, TC), expr_text(L, S, A, TA), expr_text(L, S, B, TB),
    format(string(T), "(if ~w: ~w else: ~w)", [TC, TA, TB]).
%   a match whose cases each answer yes or no: whether the value is one of
%   the cases that answer yes (`le code est dans [...]`), one condition
expr_text(L, S, match(E, Arms), T) :-
    forall(member(A, Arms), ( A = arm(_, _, _, lit(bool(_))) ; A = wildcard(lit(bool(_))) )), !,
    expr_text(L, S, E, TE),
    findall(C, member(arm(_, C, _, lit(bool(true))), Arms), Yes),
    findall(C, member(arm(_, C, _, lit(bool(false))), Arms), No),
    (   memberchk(wildcard(lit(bool(true))), Arms)
    ->  ( No == [] -> T = "true" ; eqs(TE, No, NT), format(string(T), "(not ~w)", [NT]) )
    ;   ( Yes == [] -> T = "false" ; eqs(TE, Yes, T) )
    ).
expr_text(L, S, match(E, Arms), T) :- !,
    expr_text(L, S, E, TE),
    maplist(arm_text(L, S, E), Arms, ATs), atomic_list_concat(ATs, ' ', AT),
    format(string(T), "(match ~w: ~w)", [TE, AT]).
expr_text(L, S, test_case(E, _, C, []), T) :- !,
    expr_text(L, S, E, TE), format(string(T), "(~w == '~w')", [TE, C]).
expr_text(L, S, let([X], E1, E2), T) :- !,
    subst(E2, X, E1, E3), expr_text(L, S, E3, T).
expr_text(L, S, call(builtin(round), [A]), T) :- !, expr_text(L, S, A, TA), format(string(T), "round(~w)", [TA]).   % (to the unit: the euro, the dollar)
%   the value a case carries, used whole rather than through one of its
%   fields: the leaf named after the case (`… propriétaire Demandeur…`)
expr_text(L, S, contentof(E, K), T) :- !,
    (   proj_text(L, S, contentof(E, K), [], T) -> true
    ;   throw(lower_residue("the value a case carries, used whole"))
    ).
expr_text(_, _, E, _) :- functor(E, F, _), residue_reason(F, R), throw(lower_residue(R)).
expr_text(_, _, E, _) :- throw(lower_residue(format("an expression this translator does not read: ~q", [E]))).

%!  expr_type(+Ctx, +Expr, -Type) is semidet.
%
%   The type of an expression, as Catala's typing gives it, where the
%   lowering needs it: an amount times or divided by a number is an amount,
%   which Catala rounds to the cent; an amount divided by an amount is a
%   number.
expr_type(_, lit(money(_)), money) :- !.
expr_type(_, lit(dec(_, _)), decimal) :- !.
expr_type(_, lit(percent(_)), decimal) :- !.
expr_type(_, lit(int(_)), integer) :- !.
expr_type(_, lit(dur(_, _)), duration) :- !.
expr_type(_, lit(date(_, _, _)), date) :- !.
expr_type(_, dot(id([], V, none), [], F), T) :-
    ( b_getval(catala_subject, V0-St) ; b_getval(catala_element, V0-St) ), V == V0,
    struct(St, Fs), memberchk(field(F, prim(T), _), Fs), !.
expr_type(C, binop(add, A, B), date) :- expr_type(C, B, duration), expr_type(C, A, date), !.
expr_type(_, call(builtin(cardinal), _), integer) :- !.          % `nombre de`: a count
expr_type(_, argref(_, prim(T)), T) :- !.                        % a function's parameter
expr_type(ctx(S, _), call(id([], F, none), [_]), T) :- var_type(S, F, T), !.     % a function's value
expr_type(ctx(S, _), call(dot(id([], Sub, none), [], F), [_]), T) :-
    scope_decl(S, _, Ds), memberchk(sub(Sub, scoped(_, S2), _, _), Ds), var_type(S2, F, T), !.
expr_type(C, let([X], E1, E2), T) :- !, subst(E2, X, E1, E3), expr_type(C, E3, T).
expr_type(C, X, T) :- ( X = dot(contentof(_, _), _, _) ; X = dot(dot(_, _, _), _, _) ), path_type(C, X, prim(T)), !.
expr_type(ctx(S, _), id([], V, _), date) :- var_type(S, V, date), !.
expr_type(ctx(S, _), id([], V, _), T) :- !, var_type(S, V, T).
expr_type(ctx(S, _), dot(id([], X, none), [], F), T) :- !,
    scope_decl(S, _, Ds), memberchk(sub(X, scoped(_, S2), _, _), Ds), var_type(S2, F, T).
expr_type(C, binop(Op, A, B), T) :- memberchk(Op, [add, sub]), !,
    ( ( expr_type(C, A, money) ; expr_type(C, B, money) ) -> T = money ; expr_type(C, A, T) ).
expr_type(C, binop(mult, A, B), T) :- !,
    ( expr_type(C, A, money) ; expr_type(C, B, money) ) -> T = money ; ( expr_type(C, A, T) -> true ; expr_type(C, B, T) ).
expr_type(C, binop(div, A, B), T) :- !,
    (   expr_type(C, A, money) -> ( expr_type(C, B, money) -> T = decimal ; T = money )
    ;   T = decimal
    ).
expr_type(C, if(_, A, B), T) :- !, ( expr_type(C, A, T) -> true ; expr_type(C, B, T) ).
expr_type(C, unop(minus, A), T) :- !, expr_type(C, A, T).
expr_type(C, call(builtin(round), [A]), T) :- !, expr_type(C, A, T).

var_type(S, V, T) :-
    scope_decl(S, _, Ds), memberchk(var(V, _, _, prim(T0), _, _, _), Ds), T = T0.

residue_reason(list, "a list").
residue_reason(sum, "a sum over a list").
residue_reason(maxmin, "the maximum or minimum of a list").
residue_reason(exists, "a test over the elements of a list").
residue_reason(forall, "a test over the elements of a list").
residue_reason(filter, "a list filtered").
residue_reason(map, "a list transformed").
residue_reason(map_filter, "a list transformed").
residue_reason(find, "an element found in a list").
residue_reason(argext, "the element of a list with the largest or smallest value").
residue_reason(fold, "a list combined").
residue_reason(sort, "a list sorted").
residue_reason(contains, "a list's membership").
residue_reason(scope_call, "the output of another scope").
residue_reason(struct, "a structure built").
residue_reason(replace, "a structure changed").
residue_reason(call, "a function call").
residue_reason(tuple, "a tuple").
residue_reason(tuple_get, "a tuple's element").
residue_reason(dot, "the field of a structure").

binop_text(add, '+').  binop_text(sub, '-').  binop_text(mult, '*').  binop_text(div, '/').
binop_text(and, and).  binop_text(or, or).
binop_text(gte, '>=').  binop_text(lte, '<=').  binop_text(gt, '>').  binop_text(lt, '<').
binop_text(eq, '==').  binop_text(neq, '!=').

lit_text(int(I), T) :- format(string(T), "~w", [I]).
lit_text(dec(N, _), T) :- num_text(N, T).

%   A number written out in full (10000.0, not 1.0e4: the formula language
%   has no exponent).
num_text(N, T) :-
    format(string(T0), "~w", [N]),
    (   sub_string(T0, _, _, _, "e")
    ->  format(string(T1), "~15f", [N]), split_string(T1, "", "0", [T2]),
        ( sub_string(T2, _, 1, 0, ".") -> string_concat(T2, "0", T) ; T = T2 )
    ;   T = T0
    ).
lit_text(percent(P), T) :- X is P / 100, num_text(X, T).
lit_text(money(C), T) :- X is C / 100, num_text(X, T).
lit_text(bool(B), T) :- format(string(T), "~w", [B]).
lit_text(date(Y, M, D), T) :- format(string(T), "date(\"~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+\")", [Y, M, D]).
lit_text(dur(N, year), T) :- !, M is N * 12, format(string(T), "~w", [M]).     % in months (item 3)
lit_text(dur(N, month), T) :- !, format(string(T), "~w", [N]).
lit_text(dur(N, day), T) :- !, format(string(T), "~w", [N]).          % in days, as a date less a date

arm_text(L, S, _, arm(_, C, [], E), T) :- !, expr_text(L, S, E, TE), format(string(T), "'~w' => ~w", [C, TE]).
arm_text(L, S, _, wildcard(E), T) :- !, expr_text(L, S, E, TE), format(string(T), "_ => ~w", [TE]).
%   `-- C contenu v : body(v)`: the arm binds the value its case carries. That
%   value is the payload of that case of the matched value, whose own leaves
%   are facts named after the case and the field it leads to (the housing
%   allowance's `… mode occupation Locataire bailleur`), so the binder is
%   replaced by `contentof(E, C)` and the body read with it — the same way a
%   projection reads an arm (proj_arm/6).
arm_text(L, S, Subj, arm(_, C, [Id], B), T) :- !,
    subst(B, Id, contentof(Subj, C), B1),
    expr_text(L, S, B1, TB), format(string(T), "'~w' => ~w", [C, TB]).
arm_text(_, _, _, arm(_, C, _, _), _) :- throw(lower_residue(format("a case with content (~w)", [C]))).

enum_constr(C) :- enum(_, Cs), memberchk(case(C, _), Cs), !.

sub_instance(S, X) :- scope_decl(S, _, Ds), memberchk(sub(X, _, _, _), Ds).

input_struct_field(S, V, F) :-
    scope_decl(S, _, Ds), memberchk(var(V, input, _, named(_, St), _, _, _), Ds),
    struct(St, Fs), memberchk(field(F, _, _), Fs).

subst(E, X, R, R) :- E == id([], X, none), !.
subst(let(Ids, E1, E2), X, R, let(Ids, F1, E2)) :- memberchk(X, Ids), !, subst(E1, X, R, F1).    % (rebound: hidden in the body)
subst(E, _, _, E) :- \+ compound(E), !.
subst(E0, X, R, E) :- E0 =.. [F|As0], subst_all(As0, X, R, As), E =.. [F|As].

subst_all([], _, _, []).
subst_all([A0|As0], X, R, [A|As]) :- subst(A0, X, R, A), subst_all(As0, X, R, As).

subst_arg(In-A, E0, E1) :- subst(E0, In, A, E1).

subst_each([], _, _, []).
subst_each([D0|Ds0], X, R, [D|Ds]) :- subst(D0, X, R, D), subst_each(Ds0, X, R, Ds).

subst_params([], [], E, E).
subst_params([Pm-_|Ps], [A|As], E0, E) :- subst(E0, Pm, A, E1), subst_params(Ps, As, E1, E).


		 /*******************************
		 *            TESTS             *
		 *******************************/

%   A test scope (#[test]) that calls a root scope as a sub-scope: its
%   definitions of the sub-scope's inputs are the case's facts, its
%   assertions on the sub-scope's outputs the answers it expects.
test_case(Mid, Roots, TS, Case) :-
    (   whole_case(Mid, Roots, TS, Case)
    ;   subject_case(Mid, Roots, TS, Case)
    ).

whole_case(Mid, Roots, TS, Case) :-
    scope_decl(TS, _, Ds),
    member(sub(Sub, scoped(_, Root), _, _), Ds), memberchk(Root, Roots), !,
    root_prefix(Roots, Root, P),
    findall(K-V, ( scope_def(TS, none, def(none, none, [Sub, Var], [], none, none, X, _), _),
                   data_value(TS, X, V), input_key(Root, P, Var, IK), format(atom(K), '~w#input.~w', [Mid, IK]) ), InPairs0),
    findall(O, ( scope_def(TS, none, def(none, none, [Sub, Var], [], none, none, X, _), _),
                 scope_decl(Root, _, RDs0), memberchk(var(Var, _, _, VT, _, _, _), RDs0), structured(VT), \+ VT = list(_),
                 atom_concat(P, Var, Base), flatten_value(TS, VT, X, [], Os), member(O0, Os), out_named(Base, O0, O) ), Outs),
    findall(K-V, ( member(leaf(N, V), Outs), format(atom(K), '~w#input.~w', [Mid, N]), \+ memberchk(K-_, InPairs0) ), SPairs0),
    list_to_set(SPairs0, SPairs),
    findall(St-(Key-(Flag-Fs)), member(elem(Flag, St, Key, Fs), Outs), SRows),
    list_individuals(Mid, TS, Sub, Root, P, SRows, IndPairs),
    append([InPairs0, SPairs, IndPairs], InPairs),
    findall(A, scope_def(TS, none, assertion(A, _), _), As),
    findall(K-V, ( member(A, As), assertion_value(TS, A, Sub, Var, V), format(atom(K), '~w#~w~w', [Mid, P, Var]) ), OutPairs0),
    %  an assertion on a value of the test scope that is the sub-scope's
    %  function of one of its values: that function's rule for it
    findall(K-V, ( member(A, As), call_assertion(TS, Root, P, Sub, A, N, V), format(atom(K), '~w#~w', [Mid, N]) ), OutPairs1),
    append(OutPairs0, OutPairs1, OutPairs),
    findall(A, ( member(A, As), \+ assertion_value(TS, A, Sub, _, _), \+ call_assertion(TS, Root, P, Sub, A, _, _),
                 \+ subject_assertion(TS, A, Sub, _, _, _, _) ), Unread),
    length(Unread, NU),
    dict_pairs(In, _, InPairs), dict_pairs(Out, _, OutPairs),
    Case0 = _{name: TS, input: In, output: Out},
    (   NU > 0 -> Case = Case0.put(unread_assertions, NU) ; Case = Case0 ),
    %  a test whose assertions are all about subjects is its subject cases only
    (   OutPairs \== [] ; NU > 0 ; \+ ( member(A1, As), subject_assertion(TS, A1, Sub, _, _, _, _) ) ), !.
call_assertion(TS, Root, P, Sub, binop(eq, id([], V, none), X), N, Val) :-
    catala_value(X, Val),
    scope_def(TS, none, def(none, none, [V], [], none, none,
                            call(dot(id([], Sub, none), [], F), [dot(id([], Sub, none), [], Arg)]), _), _),
    value_function(Root, F),
    scope_decl(Root, _, Ds), memberchk(var(F, _, _, _, _, States, _), Ds),
    ( States == [] -> St = none ; last(States, St) ),
    spec_name(P, F, St, States, Arg, N).

%   The input a test sets: the variable, or the first state of an input
%   defined in states.
input_key(Root, P, Var, K) :-
    (   scope_decl(Root, _, Ds), memberchk(var(Var, input, _, _, _, [St|Sts], _), Ds)
    ->  state_name(P, Var, St, [St|Sts], K)
    ;   atom_concat(P, Var, K)
    ).

%   An assertion about one value of a definition of a parameter (`f.droit_ouvert
%   de données.enfant1`): a case of its own, whose subject is the structure
%   given (its fields the subject's inputs), with the test's inputs.
subject_case(Mid, Roots, TS, Case) :-
    scope_decl(TS, _, Ds),
    member(sub(Sub, scoped(_, Root), _, _), Ds), memberchk(Root, Roots), !,
    root_prefix(Roots, Root, P),
    findall(K-V, ( scope_def(TS, none, def(none, none, [Sub, Var], [], none, none, X, _), _),
                   catala_value(X, V), format(atom(K), '~w#input.~w~w', [Mid, P, Var]) ), InPairs),
    scope_def(TS, none, assertion(A, _), _),
    subject_assertion(TS, A, Sub, Var, Struct, Value, Label),
    findall(K-V, ( member(F-FX, Struct), catala_value(FX, V), format(atom(K), '~w#input.~w', [Mid, F]) ), SPairs),
    append(InPairs, SPairs, Ins),
    format(atom(K), '~w#~w~w', [Mid, P, Var]),
    dict_pairs(In, _, Ins), dict_pairs(Out, _, [K-Value]),
    format(atom(Name), '~w_~w_~w', [TS, Var, Label]),
    Case = _{name: Name, input: In, output: Out, scope: TS}.

%   An assertion the case can expect: an output equal to a constant, a
%   condition that holds, or does not.
assertion_value(TS, binop(eq, A, X), Sub, Var, V) :- output_of(TS, A, Sub, Var), catala_value(X, V).
assertion_value(TS, A, Sub, Var, true) :- output_of(TS, A, Sub, Var).
assertion_value(TS, unop(not, A), Sub, Var, false) :- output_of(TS, A, Sub, Var).

output_of(_, dot(id([], Sub, none), [], Var), Sub, Var).
%   An assertion on a variable of the test scope itself, which the test
%   defines as the sub-scope's output (`définition éligible égal à
%   éligibilité.éligibilité`, then `assertion éligible`): it asserts that
%   output. The housing allowance's test scopes are written that way.
output_of(TS, id([], Local, none), Sub, Var) :-
    scope_def(TS, none, def(none, none, [Local], [], none, none,
                            dot(id([], Sub, none), [], Var), _), _).

%   A test's value: a constant, or a value its data scope defines
%   (`data_.date_of_sale_or_exchange`).
data_value(_, X, V) :- catala_value(X, V), !.
data_value(TS, dot(id([], D, none), [], N), V) :-
    data_def(TS, D, N, X, DS), !, data_value(DS, X, V).
data_value(DS, id([], N, none), V) :-
    scope_def(DS, none, def(none, none, [N], [], none, none, X, _), _), !, data_value(DS, X, V).

data_def(TS, D, N, X, DS) :-
    scope_decl(TS, _, Ds), memberchk(sub(D, scoped(_, DS), _, _), Ds),
    scope_def(DS, none, def(none, none, [N], [], none, none, X, _), _).

%   A structure a test gives: its fields (each a value), and a key that names
%   it (the data scope's name for it, or the literal itself).
test_struct(TS, struct(_, _, Fs0), Fs, lit(Fs0)) :- !,
    findall(F-V, ( member(F-X, Fs0), data_value(TS, X, V) ), Fs).
test_struct(TS, id([], N, none), Fs, N) :-              % (inside the data scope itself)
    scope_def(TS, none, def(none, none, [N], [], none, none, struct(_, _, Fs0), _), _), !,
    findall(F-V, ( member(F-X1, Fs0), data_value(TS, X1, V) ), Fs).
test_struct(TS, dot(id([], D, none), [], N), Fs, N) :-
    data_def(TS, D, N, X, DS), X = struct(_, _, Fs0), !,
    findall(F-V, ( member(F-X1, Fs0), data_value(DS, X1, V) ), Fs).

%   The elements of the lists a test gives the scope (a list of structures):
%   one individual each, with its fields and the lists it is in, as the case's
%   individuals of the structure's type.
list_individuals(Mid, TS, Sub, Root, P, SRows, Pairs) :-
    findall(St-(Key-(Flag-Fs)),
            ( scope_def(TS, none, def(none, none, [Sub, Var], [], none, none, list(Es), _), _),
              scope_decl(Root, _, RDs), memberchk(var(Var, _, _, list(named(_, St)), _, _, _), RDs),
              format(atom(Flag), 'is_in_~w~w', [P, Var]),
              member(E, Es), test_struct(TS, E, Fs, Key) ), Rows0),
    append(Rows0, SRows, Rows),
    findall(St, member(St-_, Rows), Sts0), sort(Sts0, Sts),
    findall(K-Items,
            ( member(St, Sts),
              findall(Key, member(St-(Key-_), Rows), Keys0), list_to_set(Keys0, Keys),
              findall(Item, ( member(Key, Keys),
                              findall(KF-VF, ( member(St-(Key-(_-Fs)), Rows), !, member(F-VF, Fs), subject_field(St, F, _),
                                               format(atom(KF), '~w#input.~w', [Mid, F]) ), FPs),
                              findall(KL-true, ( member(St-(Key-(Flag-_)), Rows), format(atom(KL), '~w#input.~w', [Mid, Flag]) ), LPs0),
                              list_to_set(LPs0, LPs), append(FPs, LPs, IPs), dict_pairs(Item, _, IPs) ), Items),
              format(atom(K), '~w#individuals.~w', [Mid, St]) ), Pairs).

%   flatten_value(+TestScope, +Type, +Expr, +Segments, -Out): the facts a
%   structured value a test gives is made of: leaf(Segments, Value) for a
%   leaf, elem(Segments, Struct, Key, Fields) for an element of a list.
flatten_value(TS, T, X0, Segs, Out) :-
    resolve(TS, X0, TS1, X),
    (   T = named(_, E), enum(E, Cs)
    ->  (   X = inject(_, C, Y) -> true ; X = id(Pa, C, _), Pa \== [], Y = none ),
        Out0 = [leaf(Segs, C)],
        (   Y \== none, memberchk(case(C, CT), Cs), CT \== none
        ->  append(Segs, [C], Segs1), flatten_value(TS1, CT, Y, Segs1, Out1)
        ;   Out1 = []
        ),
        append(Out0, Out1, Out)
    ;   T = named(_, St), struct(St, Fs), X = struct(_, _, FXs)
    ->  findall(O, ( member(field(F, FT, []), Fs), memberchk(F-FX, FXs), append(Segs, [F], Segs1),
                     flatten_value(TS1, FT, FX, Segs1, Os), member(O, Os) ), Out)
    ;   T = list(named(_, St)), X = list(Es)
    ->  findall(elem(Segs, St, Key, EFs), ( member(E1, Es), test_struct(TS1, E1, EFs, Key) ), Out)
    ;   data_value(TS1, X, V)
    ->  Out = [leaf(Segs, V)]
    ;   Out = []
    ).

resolve(TS, dot(id([], D, none), [], N), TS2, X) :- data_def(TS, D, N, X1, DS), !, resolve(DS, X1, TS2, X).
resolve(TS, id([], N, none), TS2, X) :- scope_def(TS, none, def(none, none, [N], [], none, none, X1, _), _), !, resolve(TS, X1, TS2, X).
resolve(TS, X, TS, X).

%   A flattened fact, named after its variable.
out_named(Base, leaf(Segs, V), leaf(N, V)) :- atomic_list_concat([Base|Segs], '_', N).
out_named(Base, elem(Segs, St, K, Fs), elem(Flag, St, K, Fs)) :-
    atomic_list_concat([Base|Segs], '_', N), atom_concat(is_in_, N, Flag).

%   `f.v de données.enfant1` (or its negation): the definition v of the
%   sub-scope f, of the structure enfant1 that the test's data scope gives.
subject_assertion(TS, unop(not, A), Sub, Var, Fields, false, Label) :- !,
    subject_assertion(TS, A, Sub, Var, Fields, _, Label).
subject_assertion(TS, call(dot(id([], Sub, none), [], Var), [Arg]), Sub, Var, Fields, true, Label) :-
    data_struct(TS, Arg, Fields, Label).

data_struct(TS, dot(id([], D, none), [], X), Fields, X) :-
    scope_decl(TS, _, Ds), memberchk(sub(D, scoped(_, DS), _, _), Ds),
    scope_def(DS, none, def(none, none, [X], [], none, none, struct(_, _, Fields), _), _), !.

%!  catala_value(+Expr, -Value) is semidet.
%
%   A constant of a test: a number, an amount, a date, a constructor.
catala_value(lit(int(I)), I).
catala_value(lit(dec(N, _)), N).
catala_value(lit(percent(P)), X) :- X is P / 100.
catala_value(lit(money(C)), X) :- X is C / 100.
catala_value(lit(bool(B)), B).
catala_value(lit(date(Y, M, D)), S) :- format(string(S), "~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, D]).
catala_value(id(P, C, _), S) :- P \== [], atom_string(C, S).
catala_value(inject(_, C, none), S) :- atom_string(C, S).
catala_value(unop(minus, X), V) :- catala_value(X, V0), number(V0), V is -V0.

/*  Step 6 of the design notes rune.md, the way back: a reporting rule written
    in Logical English, in the vocabulary of a twin, written as Rune that
    DRR's own tools compile (java_back/RuneBack.java) and DRR's Java runs.

    ./myswipl.sh -q migration/rune/le_to_rune.pl -- <LE file> <scenario> <template prefix> <Rune name> <out.rosetta>

    The LE file includes a twin (its <twin>.templates.pl, written by
    build.pl, says which Rune each template stands for). The rules whose
    head's template starts with <template prefix> become one reporting rule
    <Rune name> from TransactionReportInstruction, in namespace
    drr.lpsplus.back.

    What it reads back (the shapes rune_twin.pl writes, and the ones an
    author writes in the same vocabulary):

    - the instruction of the head is Rune's `item`;
    - `the A of X is Y` (an attribute's template) is `X -> A`;
    - a function's or a rule's template is a call (a rule called on the
      instruction is the rule's name: Rune applies it to `item`);
    - `a list L is the list of each W such that G` followed by `the value
      or nothing of L is V` is the expression G gives W (Rune's value of an
      input of one value or none);
    - `it is not the case that it is not the case that C` is the test C;
      `it is not the case that C` is `C = False`;
    - a comparison with a constant; the constant is written as the
      enumeration value the other side's type asks for (`RegimeNameEnum ->
      UKEMIR`);
    - the rules of the template, in order, are one `if ... then ... else if
      ...`: a condition of a later rule that is the negation of an earlier
      one's is the `else`.

    Anything else stops the translation with the condition it cannot read.
*/
:- module(le_to_rune, [
    twin_templates/2,       % +Dir, +KB: the twin's template map, under the KB's names
    rule_expression/4,      % +KB, +Functor, +Q, -RuneText: a rule's clauses as one Rune expression
    rule_functor/2,         % ?Q, ?Functor: a reporting rule and the LE predicate that stands for it
    main/1                  % the command line (le_to_rune_cli.pl)
]).
:- use_module(parser/rune_reader).
:- use_module(rune_paths).
:- use_module(rune_twin, []).
:- use_module(rune_data, [type_feature/3, value_type/2]).
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- use_module(library(main)).

%  (its command line is le_to_rune_cli.pl: a module loaded into a server
%  must not declare a main goal)

%   The way back's entry points (rune_export.pl): the templates of the twin
%   in Dir under the names LE2 gave them in KB; a rule's clauses as Rune.
twin_templates(Dir, KB) :-
    retractall(tmpl(_, _, _, _)), retractall(twin_tmpl(_, _, _, _)), retractall(lib_tmpl(_, _)),
    %  the library's templates (lib/rune.le), under the KB's names
    forall(( rune_twin:lib_template(P, T), text_key(T, Key),
             KB:le_dict(dict([F|_], _, WV, _, _, _, _)), maplist(word_text, WV, Ws),
             atomic_list_concat(Ws, ' ', Key) ),
           assertz(lib_tmpl(P, F))),
    directory_files(Dir, Fs),
    forall(( member(F, Fs), atom_concat(_, '.templates.pl', F) ),
           ( directory_file_path(Dir, F, P), load_terms(P) )),
    kb_templates(KB).

rule_functor(Q, F) :- tmpl(rule(Q), F, _, _).

rule_expression(KB, F, Q, Text) :-
    once(current_predicate(KB:F/Ar)), functor(H1, F, Ar),
    findall(H1-B, clause(KB:H1, B), Cls), Cls \== [],
    rune_model:rune_rule(_, Q, In, _, _, _),
    b_setval(le_to_rune_input, In), b_setval(le_to_rune_kb, KB),
    %  the rule's own type, for a constant it gives (an enumeration's value)
    ( catch(rune_closure:rule_typed(Q, _, ty(OTy, _)), _, fail) -> true ; OTy = none ),
    b_setval(le_to_rune_out, OTy),
    maplist(clause_branch_kind(Ar), Cls, Bs),
    else_chain(Bs, [], Text).

clause_branch_kind(Ar, C, B) :- ( Ar == 2 -> K = value ; K = test ), clause_branch(K, C, B).

:- dynamic tmpl/4, twin_tmpl/4, lib_tmpl/2.

main([File, Scenario, Prefix, Name, Out]) :-
    json_dir(JD), load_rune_model(JD),
    le_kbs:load(File, KB, [skip_tests]),
    template_map(File),
    kb_templates(KB),
    head_functor(KB, Prefix, F, Ar),
    functor(H, F, Ar),
    findall(H-B, clause(KB:H, B), Cls),
    Cls \== [],
    format("~w: ~w rules of ~w~n", [File, F, Ar]),
    rule_text(Cls, Name, Text),
    setup_call_cleanup(open(Out, write, S), write(S, Text), close(S)),
    format("written ~w~n~w", [Out, Text]),
    _ = Scenario.

%   The templates of the twins the file includes, read from their
%   <twin>.templates.pl beside them.
template_map(File) :-
    file_directory_name(File, D),
    directory_files(D, Fs),
    forall(( member(F, Fs), atom_concat(_, '.templates.pl', F) ),
           ( directory_file_path(D, F, P), load_terms(P) )).

load_terms(P) :-
    setup_call_cleanup(open(P, read, S),
        ( repeat, read_term(S, T, []), ( T == end_of_file -> ! ; T = tmpl(K, F, X, A), assertz(twin_tmpl(K, F, X, A)), fail ) ),
        close(S)).

%   The twin's templates under the names LE2 gives them: a template of the
%   knowledge base and one of the map are the same when their words are,
%   each place a blank (tmpl(Kind, LEFunctor, Text, Arity)).
kb_templates(KB) :-
    forall(( KB:le_dict(dict([F|Args], _, WV, _, _, _, _)), maplist(word_text, WV, Ws),
             atomic_list_concat(Ws, ' ', Key), twin_tmpl(K, _, Text, _), text_key(Text, Key) ),
           ( length(Args, Ar), assertz(tmpl(K, F, Text, Ar)) )).

text_key(Text, Key) :-
    atom_codes(Text, Cs), blank_places(Cs, Ds), atom_codes(Key0, Ds),
    split_string(Key0, " ", " ", Ws0), exclude(==(""), Ws0, Ws), atomic_list_concat(Ws, ' ', Key).

blank_places([], []).
blank_places([0'*|Cs], [0'_|Ds]) :- !, append(_, [0'*|Rest], Cs), !, blank_places(Rest, Ds).
blank_places([C|Cs], [C|Ds]) :- blank_places(Cs, Ds).

head_functor(KB, Prefix, F, Ar) :-
    KB:le_dict(dict([F|Args], _, WV, _, _, _, _)),
    maplist(word_text, WV, Ws), atomic_list_concat(Ws, ' ', Text),
    sub_atom(Text, 0, _, _, Prefix), !,
    length(Args, Ar).

word_text(W, T) :- ( var(W) -> T = '_' ; T = W ).

% ---------------------------------------------------------------- rules

rule_text(Cls, Name, Text) :-
    Cls = [H0-_|_], H0 =.. [_|As0], length(As0, Ar),
    ( Ar == 2 -> Kind = value ; Kind = test ),
    maplist(clause_branch(Kind), Cls, Bs),
    else_chain(Bs, [], Expr),
    format(string(Text),
           "namespace drr.lpsplus.back~nversion \"0.1\"~n~n// Written by LE2 migration/rune/le_to_rune.pl from Logical English.~n~nreporting rule ~w from drr.regulation.common.TransactionReportInstruction:~n    ~w~n",
           [Name, Expr]).

%   A rule as a branch: br(Tests, Value), Tests the pairs Cond-Text of its
%   tests (the conditions kept to recognise an else), Value the Rune of its
%   value. Conditions that only define a variable are not tests.
clause_branch(Kind, H-B, br(Tests, ValueText)) :-
    H =.. [_, X|Rest],
    conjuncts(B, Cs0),
    ( catch(b_getval(le_to_rune_input, In), _, fail) -> true ; In = 'drr.regulation.common.TransactionReportInstruction' ),
    Env0 = [X-e("item", In, single)],
    (   Kind == value, Rest = [V], var(V)
    ->  %  the value is given by one of the conditions, not always the last
        steps(Cs0, Env0-[], Env-Ts0),
        (   member(V1-e(ValueText0, _, _), Env), V1 == V -> ValueText = given(ValueText0)
        ;   member(C-_, Ts0), strip(C, le_equal_to(V2, K)), V2 == V, \+ var(K) -> out_constant(K, ValueText)
        ;   last(Cs0, Last), throw(cannot_read(value_of(Last)))
        )
    ;   Kind == value, Rest = [V]
    ->  steps(Cs0, Env0-[], Env-Ts0), out_constant(V, ValueText)
    ;   steps(Cs0, Env0-[], Env-Ts0), ValueText = "True"
    ),
    ( Rest = [VV] -> true ; VV = none ),
    existence_tests(Cs0, Env0, Env, Ts0, VV, Ts1),
    reverse(Ts1, Tests).

%   A value the rule names and then reads only inside negated tests must
%   exist for the LE rule to hold; in Rune a negated test of an empty value
%   is true. `x exists` is added for it (`the central counterparty of ...
%   is a party and it is not the case that ...`).
existence_tests(Cs, Env0, Env, Ts0, VV, Ts) :-
    append(New, Env0, Env),
    findall(exists(V)-T,
            ( member(V-e(VT, _, _), New), V \== VV,
              \+ used_positively(V, Cs, Ts0),
              occurs_negated(V, Ts0),
              format(string(T), "~w exists", [VT]) ),
            Es),
    append(Es, Ts0, Ts).

%   V is given to another definition, or read by a test outside a negation.
used_positively(V, Cs, Ts0) :-
    member(C, Cs), \+ ( member(C1-_, Ts0), C1 == C ),
    term_variables(C, Vs), member(V1, Vs), V1 == V,
    \+ defines_only(C, V), !.
used_positively(V, _, Ts0) :-
    member(C-_, Ts0), positive_vars(C, Vs), member(V1, Vs), V1 == V, !.

%   C is the definition of V (V its last argument, the only place it is).
defines_only(C0, V) :- strip(C0, C), compound(C), C =.. [_|As], last(As, L), L == V,
    append(Fs, [_], As), term_variables(Fs, FVs), \+ ( member(F, FVs), F == V ).

occurs_negated(V, Ts0) :- member(C-_, Ts0), term_variables(C, Vs), member(V1, Vs), V1 == V, !.

positive_vars(C0, Vs) :- strip(C0, C), ( C = not(_) -> Vs = [] ; C =.. [_|As], foldl(pos_arg, As, [], Vs) ).
pos_arg(A, Vs0, Vs) :- ( var(A) -> Vs = [A|Vs0] ; compound(A), A \= not(_), A \= le_at(not(_), _, _) -> A =.. [_|Bs], foldl(pos_arg, Bs, Vs0, Vs) ; Vs = Vs0 ).

branch_step(C, Env0-Ts0, Env-Ts) :-
    (   defines_any(C, Env0, Env) -> Ts = Ts0
    ;   test(C, Env0, T), Env = Env0, Ts = [C-T|Ts0]
    ).

%   The conditions in order, a condition that names a variable not yet
%   given a value put after the others (LE may test a value before the
%   condition that gives it: `the thing is equal to "A" or ... and the thing
%   is equal to the nature of party`).
steps(Cs, Acc0, Acc) :- steps(Cs, [], Acc0, Acc).
steps([], [], Acc, Acc) :- !.
steps([], Deferred, Acc0, Acc) :-
    reverse(Deferred, Ds), length(Ds, N0),
    steps_once(Ds, [], Acc0, Acc1, Left),
    length(Left, N1),
    (   Left == [] -> Acc = Acc1
    ;   N1 < N0 -> steps([], Left, Acc1, Acc)
    ;   Left = [C|_], branch_step(C, Acc1, _), Acc = Acc1     % (throws its reason)
    ).
steps([C|Cs], Deferred, Acc0, Acc) :-
    (   catch(branch_step(C, Acc0, Acc1), cannot_read(unbound), fail)
    ->  steps(Cs, Deferred, Acc1, Acc)
    ;   steps(Cs, [C|Deferred], Acc0, Acc)
    ).
steps_once([], Left, Acc, Acc, Left).
steps_once([C|Cs], Left0, Acc0, Acc, Left) :-
    (   catch(branch_step(C, Acc0, Acc1), cannot_read(unbound), fail)
    ->  steps_once(Cs, Left0, Acc1, Acc, Left)
    ;   append(Left0, [C], Left1), steps_once(Cs, Left1, Acc0, Acc, Left)
    ).

%   A constant the rule gives, as the rule's own type asks.
out_constant(V, T) :-
    ( catch(b_getval(le_to_rune_out, OTy), _, fail), OTy \== none -> const_text(V, OTy, T) ; value_constant(V, T) ).

value_constant(V, T) :- ( number(V) -> format(string(T), "~w", [V]) ; format(string(T), "\"~w\"", [V]) ).

%   if T1 then V1 else if T2 then V2 ...; a test of a later branch that
%   negates a test of an earlier one is its else.
else_chain([br(Ts, V0)], Prev, Text) :- !,
    ( V0 = given(V) -> true ; V = V0 ),
    branch_tests(Ts, Prev, Conds),
    ( Conds == [] -> Text = V ; atomic_list_concat(Conds, " and ", C), format(string(Text), "if ~w~n    then ~w", [C, V]) ).
else_chain([br(Ts, V0)|Bs], Prev, Text) :-
    branch_tests(Ts, Prev, Conds1),
    %  a value given by a condition holds only when there is one: Rune's
    %  `if` takes its branch even when the value is empty, and the later
    %  branches (a default when there is none) are then never reached
    ( V0 = given(V), Conds1 \== [] -> format(string(VE), "~w exists", [V]), append(Conds1, [VE], Conds) ; ( V0 = given(V) -> true ; V = V0 ), Conds = Conds1 ),
    findall(C, member(C-_, Ts), Cs), append(Prev, Cs, Prev1),
    else_chain(Bs, Prev1, Rest),
    ( Conds == [] -> throw(cannot_read(unconditional_branch)) ; true ),
    atomic_list_concat(Conds, " and ", C),
    format(string(Text), "if ~w~n    then ~w~n    else ~w", [C, V, Rest]).

branch_tests(Ts, Prev, Conds) :-
    findall(T, ( member(C-T, Ts), \+ negates_one_of(Prev, C) ), Conds).

negates_one_of(Prev, T) :-
    strip(T, not(G0)), strip(G0, G), member(P, Prev), strip(P, P1), P1 =@= G, !.
negates_one_of(Prev, T) :-       % it is not the case that it is not the case that X, earlier; not X here
    strip(T, not(G0)), strip(G0, G), member(P, Prev), strip(P, not(PN)), strip(PN, not(P20)), strip(P20, P2), P2 =@= G, !.

% ---------------------------------------------------------------- tests

strip(le_at(G, _, _), S) :- !, strip(G, S).
strip(G, G).

%   A term without its positions, for a message.
strip_all(V, V) :- var(V), !.
strip_all(le_at(G, _, _), S) :- !, strip_all(G, S).
strip_all(T, S) :- compound(T), !, T =.. [F|As], maplist(strip_all, As, Bs), S =.. [F|Bs].
strip_all(T, T).

%   A condition as a Rune boolean: a double negation is the test itself,
%   a negation is `= False`, a conjunction its tests joined by and.
test(C0, Env, T) :-
    strip(C0, C),
    (   C = not(N0), strip(N0, not(P0))
    ->  inner_test(P0, Env, T)
    ;   C = not(N0)
    ->  inner_test(N0, Env, T0), format(string(T), "(~w) = False", [T0])
    ;   ( C = and(_, _) ; C = (_, _) )
    ->  inner_test(C, Env, T)
    ;   C = or(A, B)
    ->  test(A, Env, TA), test(B, Env, TB), format(string(T), "(~w or ~w)", [TA, TB])
    ;   atom_test(C, Env, T)
    ).

%   occurrences_in(+V, +Conds, ?N): V occurs in N of the conditions.
occurrences_in(V, Cs, N) :-
    aggregate_all(count, ( member(C, Cs), term_variables(C, Vs), member(V1, Vs), V1 == V ), N).

%   Its definitions, then its tests.
inner_test(G0, Env, T) :-
    conjuncts(G0, Cs),
    steps(Cs, Env-[], Env1-Ts0), reverse(Ts0, Ts1), findall(T1, member(_-T1, Ts1), Ts2),
    %  a value defined and used by no other condition is a test that there
    %  is one (`the financial unit of the unit type is a financial unit`)
    append(New0, Env, Env1),
    findall(E, ( member(V-e(VT, _, _), New0), occurrences_in(V, Cs, 1), format(string(E), "~w exists", [VT]) ), Es0),
    reverse(Es0, Es),
    ( Ts2 == [] -> Ts = [] ; append(Ts2, Es, Ts) ),
    (   Ts == []
    ->  %  only definitions: the last one has a value (Rune's `exists`)
        (   append(New, Env, Env1), New = [_-e(LT, _, _)|_]
        ->  format(string(T), "~w exists", [LT])
        ;   throw(cannot_read(no_test(G0)))
        )
    ;   Ts = [T] -> true
    ;   atomic_list_concat(Ts, " and ", T1), format(string(T), "(~w)", [T1])
    ).

inner(C, Env0-Ts0, Env-Ts) :-
    (   defines_any(C, Env0, Env) -> Ts = Ts0
    ;   test(C, Env0, T), Env = Env0, Ts = [T|Ts0]
    ).

% ---------------------------------------------------------------- atoms

%   One condition that is a test: a boolean function or rule, or a
%   comparison.
atom_test(G, Env, T) :-
    G =.. [F|As],
    (   twin_tmpl(aux(_, _), _, AText, _), tmpl(aux(_, _), F, AText, _)
    ->  %  a part of a rule the twin wrote apart, so that core LE can say it
        %  ("a value meets condition 2 of ..."): its own rules, in place
        b_getval(le_to_rune_kb, KB),
        length(As, N), functor(G0, F, N),
        findall(G0-B0, clause(KB:G0, B0), Cls),
        findall(TB, ( member(G1-B1, Cls), G1 = G, test(B1, Env, TB) ), TBs),   % (G itself: its variables are Env's)
        ( TBs == [] -> throw(cannot_read(test(G))) ; true ),
        atomic_list_concat(TBs, " or ", TT), format(string(T), "(~w)", [TT])
    ;   tmpl(func(Q), F, _, _), rune_model:rune_func(Q, Ins, _, _, _, _, _), length(As, N), length(Ins, N)
    ->  maplist(arg_text(Env), As, Ins, ATs), call_text(Q, ATs, T)
    ;   tmpl(rule(Q), F, _, 1)
    ->  As = [X], expr(X, Env, e(XT, _, _)), ( XT == "item" -> rule_ref(Q, T) ; rule_ref(Q, R), format(string(T), "~w then ~w", [XT, R]) )
    ;   G = le_is_in(A, B), is_list(B)
    ->  %  x is in [a, b]: x = a or x = b
        expr(A, Env, e(AT, Ty, _)),
        findall(C, ( member(K, B), const_text(K, Ty, KT), format(string(C), "~w = ~w", [AT, KT]) ), Cs),
        atomic_list_concat(Cs, " or ", CT), format(string(T), "(~w)", [CT])
    ;   G = le_is_in(A, B)
    ->  expr(A, Env, e(AT, _, _)), expr(B, Env, e(BT, _, _)),
        format(string(T), "~w contains ~w", [BT, AT])
    ;   comparison(G, Op, A, B)
    ->  compare_text(Op, A, B, Env, T)
    ;   tmpl(rule(Q), F, _, 2), As = [X, K], nonvar(K)
    ->  expr(X, Env, e(XT, _, _)), rule_ref(Q, R),
        ( catch(rune_closure:rule_typed(Q, _, ty(RTy, _)), _, fail) -> true ; RTy = none ),
        const_text(K, RTy, KT),
        ( XT == "item" -> format(string(T), "~w = ~w", [R, KT]) ; format(string(T), "(~w then ~w) = ~w", [XT, R, KT]) )
    ;   tmpl(func(Q), F, _, _), append(Ins, [K], As), nonvar(K),
        rune_model:rune_func(Q, FIns, out(_, OTy, _), _, _, _, _), length(Ins, N), length(FIns, N)
    ->  maplist(arg_text(Env), Ins, FIns, ATs), call_text(Q, ATs, CT), const_text(K, OTy, KT),
        format(string(T), "~w = ~w", [CT, KT])
    ;   As = [O, K], var(K), tmpl(attr(At), F, _, _), member(K1-e(KT, _, KC), Env), K1 == K
    ->  %  the attribute of an object is a value already given: a comparison
        expr(O, Env, e(OT, OTy, OC)),
        (   ( OC == multi ; KC == multi ; atom(OTy), type_feature(OTy, At, feature(_, card(_, Max), _)), Max \== 1 )
        ->  Q = "any =" ; Q = "="
        ),
        format(string(T), "~w -> ~w ~w ~w", [OT, At, Q, KT])
    ;   As = [O, K], nonvar(K), tmpl(attr(At), F, _, _)
    ->  %  the attribute of an object has a given value: `x -> a = K`
        expr(O, Env, e(OT, OTy, OC)), attr_type(OTy, At, Ty), const_text(K, Ty, KT),
        (   ( OC == multi ; atom(OTy), type_feature(OTy, At, feature(_, card(_, Max), _)), Max \== 1 )
        ->  Q = "any =" ; Q = "="
        ),
        format(string(T), "~w -> ~w ~w ~w", [OT, At, Q, KT])
    ;   lib_tmpl(P, F), append(Ins, [K], As), ( nonvar(K) -> true ; member(K1-_, Env), K1 == K )
    ->  %  a library operation whose value is known already: a comparison
        maplist(lib_arg(Env), Ins, Ts), lib_expr(P, Ts, e(LT, LTy, LC)),
        ( var(K) -> once(( member(K2-e(KT, _, KC), Env), K2 == K )) ; const_text(K, LTy, KT), KC = single ),
        ( ( LC == multi, KC \== multi ; KC == multi, LC \== multi ) -> Q = "any =" ; Q = "=" ),
        format(string(T), "(~w) ~w ~w", [LT, Q, KT])
    ;   G = forall(In, Eq), strip(In, le_is_in(X, L)), strip(Eq, le_equal_to(X1, K)), X1 == X, nonvar(K)
    ->  %  every element of a list is the value: `all =`
        expr(L, Env, e(LT, LTy, _)), const_text(K, LTy, KT),
        format(string(T), "~w all = ~w", [LT, KT])
    ;   throw(cannot_read(test(G)))
    ).

comparison(le_is(A, B), "=", A, B).
comparison(le_equal_to(A, B), "=", A, B).
comparison(le_not_equal_to(A, B), "<>", A, B).
comparison(A = B, "=", A, B).
comparison(A \= B, "<>", A, B).
comparison(A > B, ">", A, B).
comparison(A < B, "<", A, B).
comparison(A >= B, ">=", A, B).
comparison(A =< B, "<=", A, B).

compare_text(Op, A, B, Env, T) :-
    (   B == nothing -> expr(A, Env, e(AT, _, _)),
        ( Op == "<>" -> format(string(T), "~w exists", [AT]) ; format(string(T), "~w is absent", [AT]) )
    ;   var(A), var(B) -> expr(A, Env, EA0), expr(B, Env, EB0),
        retyped(EA0, EB0, e(AT, _, CA)), retyped(EB0, EA0, e(BT, _, CB)),
        quantified(Op, CA, CB, Q), format(string(T), "~w ~w ~w", [AT, Q, BT])
    ;   var(A) -> expr(A, Env, e(AT, Ty, CA)), const_text(B, Ty, BT), quantified(Op, CA, single, Q), format(string(T), "~w ~w ~w", [AT, Q, BT])
    ;   expr(B, Env, e(BT, Ty, CB)), const_text(A, Ty, AT), quantified(Op, single, CB, Q), format(string(T), "~w ~w ~w", [AT, Q, BT])
    ).

%   Constants whose type was left open take the type of what they are
%   compared with: `"Buyer"` becomes `NaturalPersonRoleEnum -> Buyer`.
retyped(e(T0, consts(Ks), C), e(_, Ty0, _), e(T, Ty, C)) :-
    ( Ty0 = enum(Ty) -> true ; Ty = Ty0 ), atom(Ty), Ty \== none, !,
    foldl(retype_constant(Ty), Ks, T0, T).
retyped(E, _, E).

retype_constant(Ty, K, T0, T) :-
    value_constant(K, Old), const_text(K, Ty, New),
    atomic_list_concat(Parts, Old, T0), atomic_list_concat(Parts, New, A), atom_string(A, T).

or_alternatives(G0, Alts) :-
    strip(G0, G),
    (   G = or(A, B) -> or_alternatives(A, AA), or_alternatives(B, BA), append(AA, BA, Alts) ; Alts = [G] ).

equal_constant(W, G0, K) :- strip(G0, le_equal_to(X, K)), X == W, nonvar(K).

%   Rune asks a comparison of a list with one value to say `any` or `all`;
%   an LE condition on a value of a list holds when one element passes:
%   `any`.
quantified(Op, CA, CB, Q) :-
    (   ( CA == multi ; CB == multi ), \+ ( CA == multi, CB == multi ) -> format(string(Q), "any ~w", [Op]) ; Q = Op ).

% ---------------------------------------------------------------- definitions

defines_any(C0, Env0, [V-E|Env0]) :-
    strip(C0, C),
    term_variables(C, Vs), member(V, Vs), \+ ( member(V0-_, Env0), V0 == V ),
    defines(C, Env0, V, E), !.

%   defines(+Cond, +Env, ?V, -e(Text, Type, Card)): the condition gives V
%   its value: an attribute, a call, a list collected and taken as one
%   value or none.
defines(C0, Env, V, E) :- strip(C0, C), defines_(C, Env, V, E).

defines_(and(A, B), Env, V, E) :- !,
    %  a list collected, then its one value or none
    strip(A, list([each, var(_, W)], G, [var(_, L)])), strip(B, the_value_or_nothing_of_is(L1, V)), L1 == L, !,
    conjuncts(G, Gs), foldl(def_step, Gs, Env, Env1),
    expr(W, Env1, E0), E0 = e(T, Ty, _), E = e(T, Ty, opt), _ = V.
defines_(list([each, var(_, W)], G, [var(_, L)]), Env, V, E) :- L == V, !,
    list_expr(W, G, Env, E).
defines_(the_value_or_nothing_of_is(L, V1), Env, V, e(T, Ty, opt)) :- V1 == V, !,
    member(L1-e(T, Ty, _), Env), L1 == L.
%   `the thing is equal to the nature of party`, the thing not yet given a
%   value: it is that value
defines_(le_equal_to(A, B), Env, V, E) :- A == V, var(B), !,
    member(B1-E, Env), B1 == B.
defines_(le_equal_to(A, B), Env, V, E) :- B == V, var(A), !,
    member(A1-E, Env), A1 == A.
defines_(G, Env, V, E) :-
    G =.. [F|As], lib_tmpl(P, F), append(Ins, [V1], As), V1 == V, var(V), !,
    maplist(lib_arg(Env), Ins, Ts),
    lib_expr(P, Ts, E).
defines_(G, Env, V, E) :-
    G =.. [F|As], append(Ins, [V1], As), V1 == V, var(V),
    (   tmpl(attr(A), F, _, _), Ins = [O]
    ->  expr(O, Env, e(OT, OTy, OC)),
        attr_type(OTy, A, Ty),
        %  one value when the object is one and the attribute has at most one
        (   OC \== multi, atom(OTy), type_feature(OTy, A, feature(_, card(_, 1), _)) -> C = single ; C = multi ),
        format(string(T), "~w -> ~w", [OT, A]), E = e(T, Ty, C)
    ;   tmpl(func(Q), F, _, _)
    ->  rune_model:rune_func(Q, FIns, out(_, OTy0, _), _, _, _, _),
        maplist(arg_text(Env), Ins, FIns, ATs), call_text(Q, ATs, T), E = e(T, OTy0, single)
    ;   tmpl(rule(Q), F, _, 2), Ins = [X]
    ->  expr(X, Env, e(XT, _, _)), rule_ref(Q, R),
        ( XT == "item" -> T = R ; format(string(T), "~w then ~w", [XT, R]) ),
        ( catch(rune_closure:rule_typed(Q, _, ty(RTy, _)), _, fail) -> true ; RTy = none ),
        E = e(T, RTy, single)
    ).

%   The library's operations (lib/rune.pl) as Rune's: the list operations
%   after the list, `+` for texts, `to-string`, `to-number`.
lib_arg(Env, A, e(T, Ty, C)) :- ( var(A) -> expr(A, Env, e(T, Ty, C)) ; value_constant(A, T), Ty = none, C = single ).

%   A postfix operation; after a closure (`filter`, `extract`) Rune asks
%   for `then` before it.
postfix(L, Op, T) :-
    (   ( sub_string(L, _, _, _, " filter ") ; sub_string(L, _, _, _, " extract ") )
    ->  format(string(T), "~w then ~w", [L, Op])
    ;   format(string(T), "~w ~w", [L, Op])
    ).

lib_expr(rune_only_element, [e(L, Ty, _)], e(T, Ty, single)) :- postfix(L, "only-element", T).
lib_expr(rune_first, [e(L, Ty, _)], e(T, Ty, single)) :- postfix(L, "first", T).
lib_expr(rune_last, [e(L, Ty, _)], e(T, Ty, single)) :- postfix(L, "last", T).
lib_expr(rune_min, [e(L, Ty, _)], e(T, Ty, single)) :- postfix(L, "min", T).
lib_expr(rune_max, [e(L, Ty, _)], e(T, Ty, single)) :- postfix(L, "max", T).
lib_expr(rune_distinct, [e(L, Ty, _)], e(T, Ty, multi)) :- postfix(L, "distinct", T).
lib_expr(rune_reverse, [e(L, Ty, _)], e(T, Ty, multi)) :- postfix(L, "reverse", T).
lib_expr(rune_sorted, [e(L, Ty, _)], e(T, Ty, multi)) :- postfix(L, "sort", T).
lib_expr(rune_concat, [e(A, _, _), e(B, _, _)], e(T, string, single)) :- format(string(T), "(~w + ~w)", [A, B]).
lib_expr(rune_to_string, [e(A, _, _)], e(T, string, single)) :- format(string(T), "~w to-string", [A]).
lib_expr(rune_to_number, [e(A, _, _)], e(T, number, single)) :- format(string(T), "~w to-number", [A]).
lib_expr(rune_or_nothing, [e(L, Ty, _)], e(L, Ty, opt)).
lib_expr(rune_date_part, [e(A, _, _)], e(T, date, single)) :- format(string(T), "~w -> date", [A]).
lib_expr(rune_time_part, [e(A, _, _)], e(T, time, single)) :- format(string(T), "~w -> time", [A]).
lib_expr(rune_join, [e(L, _, _), e(Sep, _, _)], e(T, string, single)) :- format(string(T), "~w join ~w", [L, Sep]).

def_step(G, Env0, Env) :-
    (   defines_any(G, Env0, Env) -> true ; throw(cannot_read(inside_list(G))) ).

%   A list collected (`a list L is the list of each W such that G`): Rune's
%   filter and extract. With a generator (`a thing is in L0`), the elements
%   of L0 that pass G's tests, each as W; without one, W when G's tests hold.
list_expr(W, G, Env, e(Text, Ty, multi)) :-
    conjuncts(G, Gs),
    (   Gs = [G1], or_alternatives(G1, Alts), Alts = [_, _|_],
        maplist(equal_constant(W), Alts, Ks)
    ->  %  a list of constants (`each T such that T is "A" or T is "B"`):
        %  their type is the one of what they are compared with
        maplist(value_constant, Ks, KTs), atomic_list_concat(KTs, ", ", KT),
        format(string(Text), "[~w]", [KT]), Ty = consts(Ks)
    ;   select(Gen, Gs, Rest), strip(Gen, le_is_in(X, L0)), var(X), var(L0),
        member(L1-e(LT, LTy, _), Env), L1 == L0
    ->  %  the element named (`filter x1 [...]`): Rune's implicit `item`
        %  would hide the instruction, which the conditions may still name
        flag(le_to_rune_element, N, N + 1), format(string(XN), "x~w", [N]),
        Env1 = [X-e(XN, LTy, single)|Env],
        steps(Rest, Env1-[], Env2-Ts0),
        expr(W, Env2, e(WT, Ty, _)),
        reverse(Ts0, Ts1), findall(T, member(_-T, Ts1), Ts),
        (   Ts == [] -> F = "" ; atomic_list_concat(Ts, " and ", TT), format(string(F), " filter ~w [~w]", [XN, TT]) ),
        (   WT == XN -> format(string(Text), "~w~w", [LT, F])
        ;   format(string(Text), "~w~w extract ~w [~w]", [LT, F, XN, WT])
        )
    ;   append(Pre, [Gen|Post], Gs), Post \== [],
        catch(steps(Pre, Env-[], EnvP-[]), cannot_read(_), fail),
        defines(Gen, EnvP, W, e(WT, Ty, multi)),
        \+ ( member(W0-_, EnvP), W0 == W )
    ->  %  the elements of an attribute with several values that pass the
        %  tests: `x -> a filter x1 [...]`, the tests on one element
        flag(le_to_rune_element, N, N + 1), format(string(XN), "x~w", [N]),
        steps(Post, [W-e(XN, Ty, single)|EnvP]-[], _-Ts0),
        reverse(Ts0, Ts1), findall(T, member(_-T, Ts1), Ts),
        (   Ts == [] -> Text = WT
        ;   atomic_list_concat(Ts, " and ", TT), format(string(Text), "(~w filter ~w [~w])", [WT, XN, TT])
        )
    ;   steps(Gs, Env-[], Env2-Ts0),
        expr(W, Env2, e(WT, Ty, _)),
        reverse(Ts0, Ts1), findall(T, member(_-T, Ts1), Ts),
        (   Ts == [] -> Text = WT
        ;   atomic_list_concat(Ts, " and ", TT), format(string(Text), "(if ~w then ~w)", [TT, WT])
        )
    ).

expr(X, Env, E) :- var(X), !, ( member(V-E0, Env), V == X -> E = E0 ; throw(cannot_read(unbound)) ).
expr(X, _, e(T, none, single)) :- value_constant(X, T).

attr_type(OTy, A, Ty) :-
    (   atom(OTy), type_feature(OTy, A, feature(TR, _, _)) -> Ty = TR ; Ty = none ).

arg_text(Env, A, in(_, Ty, _), T) :-
    (   var(A), expr(A, Env, e(T0, none, _)), string(T0),
        sub_string(T0, 0, 1, _, "\""), sub_string(T0, _, 1, 0, "\""), string_length(T0, L), L >= 2
    ->  %  a constant given by a condition: as the input's type asks
        L1 is L - 2, sub_string(T0, 1, L1, _, C), const_text(C, Ty, T)
    ;   var(A) -> expr(A, Env, e(T, _, _))
    ;   A == nothing -> T = "empty"
    ;   const_text(A, Ty, T)
    ).

%   A constant as the type asks: an enumeration's value, a number, a text.
const_text(C, enum(Ty), T) :- !, const_text(C, Ty, T).
const_text(C, Ty, T) :-
    is_list(C), !,
    maplist(const_elem(Ty), C, KTs),
    atomic_list_concat(KTs, ', ', A), format(string(T), "[~w]", [A]).
const_text(C, Ty, T) :-
    %  a list of an enumeration's values, which the twin keeps as "[A, B]"
    atom(Ty), rune_model:rune_enum(Ty, _, _), ( string(C) ; atom(C) ),
    atom_concat('[', R0, C), atom_concat(R, ']', R0), !,
    split_string(R, ",", " ", Ks0), exclude(==(""), Ks0, Ks),
    maplist(const_elem(Ty), Ks, KTs),
    atomic_list_concat(KTs, ', ', A), format(string(T), "[~w]", [A]).
const_text(C, Ty, T) :-
    (   atom(Ty), rune_model:rune_enum(Ty, _, _), rune_reader:enum_value_json(Ty, V, J), atom_string(J, CS), ( string(C) -> CS == C ; atom_string(C, CS) )
    ->  format(string(T), "~w -> ~w", [Ty, V])
    ;   number(C) -> format(string(T), "~w", [C])
    ;   C == "true" -> T = "True"
    ;   C == "false" -> T = "False"
    ;   format(string(T), "\"~w\"", [C])
    ).

const_elem(Ty, K, KT) :- const_text(K, Ty, KT).

call_text(Q, ATs, T) :- atomic_list_concat(ATs, ", ", A), format(string(T), "~w(~w)", [Q, A]).
rule_ref(Q, Q).

%   A condition's conjuncts, with each list collected and its one value or
%   none (`a list L is the list of each ... and the value or nothing of L
%   is V`) kept together: the two are one Rune expression.
conjuncts(G0, Cs) :- flat_conjuncts(G0, Cs).

flat_conjuncts(G0, Cs) :- strip(G0, G), ( G = and(A, B) -> flat_conjuncts(A, CA), flat_conjuncts(B, CB), append(CA, CB, Cs) ; G = (A, B) -> flat_conjuncts(A, CA), flat_conjuncts(B, CB), append(CA, CB, Cs) ; Cs = [G] ).

pair_lists([], []).
pair_lists([C|Cs], [P|Ps]) :-
    strip(C, list(Each, G, [var(N, L)])),
    select(D, Cs, Rest), strip(D, the_value_or_nothing_of_is(L1, V)), L1 == L, !,
    P = and(list(Each, G, [var(N, L)]), the_value_or_nothing_of_is(L1, V)),
    pair_lists(Rest, Ps).
pair_lists([C|Cs], [C|Ps]) :- pair_lists(Cs, Ps).

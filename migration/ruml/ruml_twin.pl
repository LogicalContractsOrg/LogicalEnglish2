/** <module> A RUML rulemap → its Logical English twin (the migration term)

    The mapping of the design notes ruml.md §4, generated. In short:

    - Every node is a sentence with one place, the case:
      `Antragsteller volljährig holds for *a case*`, its words the node's
      label (ruml_names.pl). The root is the query `root`.
    - AND is one rule, OR and XOR a rule per child, NOT_AND, NOT_OR and
      NOT_XOR the negation of a second sentence (`the conditions of ... are
      met for *a case*`), DELEGATED the translation of its expression.
    - A leaf with `ruml:query` is a rule whose conditions are its JSONata
      expression (jsonata_parser.pl). A leaf with no deciding capability is
      a judged sentence: a person decides it. `ruml:ai-query` is a judged
      sentence too (decision 5 of the plan).
    - A data point is a sentence that only scenarios state:
      `the Alter of *a case* is *a number*`. A set is a relation between the
      case and a member, and a sentence for each field of the member.

    RUML has a third result, `undefined`, which Logical English reads as an
    answer that rests on unknowns (§3, experiment E):

        RUML true       the sentence is proved, with no unknowns
        RUML undefined  the sentence is proved only with unknowns, and so is
                        its negation
        RUML false      the sentence is not proved

    The twin reproduces RUML's `complete` mode exactly (decision 3):

    - Where JSONata gives no result for a leaf (a data point it compares is
      missing, §3 experiment C), the leaf has a second rule: the condition
      that says so, and the assumable sentence `... would hold for *a case*`
      (§4.3).
    - A DELEGATED node is undefined as soon as one child is undefined,
      whatever the expression says. Its rule asks that the node be
      `decided`: a sentence defined only where RUML's result is true or
      false, from the data, with no unknown (§4.4). A recursive node is read
      the same way (§5): an exit that holds decides it; with none, RUML's
      evaluator reaches its depth limit and answers undefined.

    Options of model_migration/3:
        program(Name), document(DocName)   names
        tests(Cases)          case(Id, Description, Inputs, Expected),
                              Inputs DataPointId-JSONValue,
                              Expected LexId-Status (true|false|undefined)
        mode(exact|plain|closed)   exact (default): as above; plain: no
                              `decided` (a DELEGATED node answers from its
                              children as logic does); closed: no missing-
                              value rules either (a missing value is false)
        texts(Dir)            where the texts of ruml:text-reference were
                              written (sources/), for the documents (step 4)
        includes(Pairs)       URI-Twin of included rulemaps (tree-include)

        model_migration(+Doc, +Options, -Migration)
        node_query(+LexId, -QueryName), node_negation_query(+LexId, -Q)
*/

:- module(ruml_twin, [model_migration/3, node_query/2, node_negation_query/2,
                      twin_symbol/3, ruml_value/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(pairs)).
:- use_module(ruml_reader).
:- use_module(jsonata_parser).
:- use_module(ruml_names).
:- use_module(ruml_cases, [read_datapoints/2]).

:- dynamic out/1.            % IR items, in order
:- dynamic ledger/1.         % ledger entries
:- dynamic sym/3.            % Kind, Key, functor-and-text: node, would, decided, aux, judged, count, dp, has, field
:- dynamic needs_decided/1.  % LexId
:- dynamic dp_info/4.        % Id, Kind (scalar|object), Type, Set
:- dynamic set_field/4.      % SetId, FieldId, Kind, TypeOrSet
:- dynamic set_noun/2.       % SetId, Noun
:- dynamic mode/1.
:- dynamic doc/1.
:- dynamic counter/1.
:- dynamic node_doc/2.       % LexId, provenance options of its rule

		 /*******************************
		 *          THE RULEMAP         *
		 *******************************/

model_migration(Doc, Options, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    reset,
    assertz(doc(Doc)),
    option(mode(Mode), Options, exact), assertz(mode(Mode)),
    names_reset,
    j(Doc, metadata, Md),
    j(Md, title, Title0, ""), ( Title0 == "" -> nodes_root_label(Doc, Title) ; Title = Title0 ),
    option(program(Program), Options, twin),
    option(document(DocName), Options, 'the rulemap'),
    texts_and_documents(Doc, Options),
    declare_datapoints(Doc),
    nodes(Doc, Ns),
    forall(member(K-N, Ns), declare_node(K, N)),
    forall(sym(computed, Id, E), computed_rule(Id, E)),
    mark_decided(Doc),
    forall(member(K-N, Ns), node_documents(K, N)),
    reachable_order(Doc, Order),
    forall(member(K, Order), ( memberchk(K-N, Ns), translate_node(Doc, K, N) )),
    ledger_metadata(Doc),
    option(tests(Cases), Options, []),
    findall(T, ( member(C, Cases), case_test(DocName, C, T) ), Tests),
    findall(L, ( member(case(_, _, _, Exp), Cases), member(L-_, Exp) ), Ls0), sort(Ls0, Ls1),
    (   option(queries(all), Options) -> nodes(Doc, AllNs), findall(L, member(L-_, AllNs), Ls)
    ;   union(['1'], Ls1, Ls)
    ),
    findall(Q, ( member(L, Ls), node_queries(L, Q) ), Qs0), append(Qs0, Qs),
    findall(I, out(I), Body),
    append(Body, Qs, Items),
    findall(E, ( ledger(E0), labelled_entry(Doc, E0, E) ), Ledger),
    metadata_comment(Doc, DocName, Comment),
    format(atom(KB0), '~w', [Program]), ( atom_codes(KB0, [C0|_]), code_type(C0, alpha) -> KB = KB0 ; atom_concat(r, KB0, KB) ),
    Header = [kb(KB), comment(Comment)],
    ignore(Title = _),
    Meta = [source('RUML'), artifacts([DocName]), translator(ruml_twin), program(Program)].

reset :-
    retractall(out(_)), retractall(ledger(_)), retractall(sym(_, _, _)), retractall(needs_decided(_)),
    retractall(dp_info(_, _, _, _)), retractall(set_field(_, _, _, _)), retractall(set_noun(_, _)),
    retractall(mode(_)), retractall(doc(_)), retractall(counter(_)), retractall(node_doc(_, _)),
    assertz(counter(0)).

emit(I) :- assertz(out(I)).
ledger_entry(E, K, V, M, P, N) :- assertz(ledger(entry(E, K, V, M, P, N))).

nodes_root_label(Doc, L) :- ( node(Doc, '1', R), j(R, label, L) -> true ; L = "" ).

%   The nodes the root reaches, parents before children (a modular node
%   once); nodes no parent reaches come last.
reachable_order(Doc, Order) :-
    walk(Doc, ['1'], [], Rev), reverse(Rev, Reached),
    nodes(Doc, Ns), findall(K, ( member(K-_, Ns), \+ memberchk(K, Reached) ), Rest),
    append(Reached, Rest, Order).
walk(_, [], Seen, Seen).
walk(Doc, [K|Ks], Seen, Out) :-
    (   memberchk(K, Seen) -> walk(Doc, Ks, Seen, Out)
    ;   node(Doc, K, N) -> children(K, N, Cs), append(Ks, Cs, Ks1), walk(Doc, Ks1, [K|Seen], Out)
    ;   walk(Doc, Ks, Seen, Out)
    ).

children(_, N, Cs) :- ( j(N, children, Cs0) -> maplist([S, A]>>atom_string(A, S), Cs0, Cs) ; Cs = [] ).
own_children(K, N, Cs) :- children(K, N, Cs0), exclude(==(K), Cs0, Cs).
recursive(K, N) :- children(K, N, Cs), memberchk(K, Cs).

operator(N, Op) :- ( j(N, operator, O) -> atom_string(Op, O) ; Op = none ).

		 /*******************************
		 *           SYMBOLS            *
		 *******************************/

%!  twin_symbol(?Kind, ?Key, ?FunctorText) is nondet.
%   For the evaluator (ruml_result.pl): node-LexId -> f(Functor, Text).
twin_symbol(K, Key, S) :- sym(K, Key, S).

new_functor(Prefix, F) :-
    retract(counter(N0)), N is N0 + 1, assertz(counter(N)),
    format(atom(F), '~w_~d', [Prefix, N]).

declare(Kind, Key, Text, Arity, Adds, F) :-
    (   sym(Kind, Key, f(F, _)) -> true
    ;   new_functor(Kind, F), assertz(sym(Kind, Key, f(F, Text))),
        emit(template(F, Text, Adds)), ignore(Arity = _)
    ).

lit(Kind, Key, Args, L) :- sym(Kind, Key, f(F, _)), L =.. [F|Args].

declare_node(K, N) :-
    j(N, label, L0, ""), ( L0 == "" -> format(atom(L), "node ~w", [K]) ; L = L0 ),
    unique_label(K, L, Words),
    assertz(sym(words, K, Words)),
    (   leaf_judged(N) -> assertz(sym(answer_leaf, K, yes)) ; true ),
    format(string(T), "~w holds for *a case*", [Words]), declare(node, K, T, 1, [], _).

words(K, W) :- sym(words, K, W).
holds(K, C, L) :- lit(node, K, [C], L).

would(K, C, L) :-
    words(K, W), format(string(T), "~w would hold for *a case*", [W]),
    declare(would, K, T, 1, [assumable], _), lit(would, K, [C], L).
%   A judged leaf has no rule for it: only a scenario can say it is decided.
decided(K, C, L) :-
    words(K, W), format(string(T), "~w is decided for *a case*", [W]),
    declare(decided, K, T, 1, [], _), lit(decided, K, [C], L).

%   A leaf that no capability decides: a person answers it, and the answer
%   is a fact of the case (`the answer to <label> for case 1 is true`).
answer(K, C, V, L) :-
    words(K, W), format(string(T), "the answer to ~w for *a case* is *a truth value*", [W]),
    declare(answer, K, T, 2, [undefined], _), lit(answer, K, [C, V], L).
aux(K, Op, C, L) :-
    words(K, W),
    (   Op == 'NOT_AND' -> format(string(T), "the conditions of ~w are met for *a case*", [W])
    ;   format(string(T), "one of the conditions of ~w is met for *a case*", [W])
    ),
    declare(aux, K, T, 1, [], _), lit(aux, K, [C], L).
judged(K, C, L) :-
    words(K, W), format(string(T), "~w is judged to hold for *a case*", [W]),
    declare(judged, K, T, 1, [judged], _), lit(judged, K, [C], L).

%   A leaf with no deciding capability is a judged sentence itself.
leaf_judged(N) :-
    \+ j(N, children, [_|_]), node_caps(N, Es),
    \+ ( member(cap(Id, _), Es), deciding(Id) ).
deciding(Id) :- doc(D), capability_role(D, Id, decision).

		 /*******************************
		 *         DATA POINTS          *
		 *******************************/

declare_datapoints(Doc) :-
    capabilities(Doc, Cs),
    (   member(C, Cs), j(C, id, "ruml:datapoints"), j(C, payload, P)
    ->  ( j(P, sets, json(Sets)) -> true ; Sets = [] ),
        forall(member(SId=S, Sets), declare_set(SId, S)),
        ( j(P, data, json(D)) -> true ; D = [] ),
        read_datapoints(Doc, Read),
        forall(member(Id=DP, D),
               (   ( memberchk(Id, Read) ; j(DP, binding, Bd), j(Bd, type, "computed") ) -> declare_dp(Id, DP)
               ;   ledger_entry(Id, 'data point', approximated, "declared, and read by no expression: not a sentence of the twin", "", "kept in the original under sources/")
               ))
    ;   true
    ).

declare_set(SId, S) :-
    j(S, name, N0, ""), ( N0 == "" -> atom_string(SId, N1), ( string_concat("set_", N2, N1) -> true ; N2 = N1 ) ; N2 = N0 ),
    label_words(N2, Ws0), maplist(downcase_atom, Ws0, Ws), atomic_list_concat(Ws, ' ', Noun),
    assertz(set_noun(SId, Noun)),
    ( j(S, fields, json(Fs)) -> true ; Fs = [] ),
    forall(member(FId=F, Fs),
           ( j(F, type, T0, "string"), atom_string(T, T0),
             (   T == object -> j(F, set, S2), atom_string(S2a, S2), assertz(set_field(SId, FId, object, S2a))
             ;   assertz(set_field(SId, FId, scalar, T))
             ),
             j(F, name, FN, ""), datapoint_words(FId, FN, FWs), assertz(sym(fieldwords, SId-FId, FWs)) )).

declare_dp(Id, DP) :-
    j(DP, type, T0, "string"), atom_string(T, T0),
    j(DP, name, Name, ""),
    datapoint_words(Id, Name, Ws0), unique_dp_words(Ws0, Ws), atomic_list_concat(Ws, ' ', W),
    j(DP, binding, B, json([])), j(B, type, BT, "input"),
    (   T == object
    ->  j(DP, set, S0), atom_string(S, S0), set_noun(S, Noun),
        ( j(DP, cardinality, Card), j(Card, max, Max), Max > 1 -> Many = many ; Many = one ),
        assertz(dp_info(Id, object(Many), T, S)),
        format(string(Tx), "*a case* has ~w *a ~w*", [W, Noun]),
        declare(has, Id, Tx, 2, [undefined], _),
        ledger_entry(Id, 'data point (set)', encoded, "a relation between the case and each member, and a sentence for each field of the member", Tx, "")
    ;   type_noun(T, Noun),
        assertz(dp_info(Id, scalar, T, none)),
        format(string(Tx), "the ~w of *a case* is *a ~w*", [W, Noun]),
        (   BT == "computed"
        ->  declare(dp, Id, Tx, 2, [], _)
        ;   declare(dp, Id, Tx, 2, [undefined], _)
        ),
        dp_note(DP, Note),
        ledger_entry(Id, 'data point', encoded, "a sentence that the scenarios state", Tx, Note)
    ),
    assertz(sym(dpwords, Id, W)),
    (   BT == "computed", j(B, expression, E) -> assertz(sym(computed, Id, E)) ; true ).

%   A computed data point (§4.7.2): one rule that calculates its value.
computed_rule(Id, ES) :-
    (   jsonata_parse(ES, E),
        catch(compile_val(E, env(C, case, none, none), V, B, _), unsupported(_), fail)
    ->  dp_lit(Id, C, V, H), emit(rule(H, B, [])),
        format(string(M), "a computed data point: ~w", [ES]),
        sym(dpwords, Id, W), format(string(P), "the ~w of *a case*", [W]),
        ledger_entry(Id, 'computed data point', encoded, M, P, "")
    ;   new_functor(r, RId),
        format(string(T), "the computed data point ~w", [Id]),
        emit(residue(RId, [title(T), source(jsonata, ES)])),
        ledger_entry(Id, 'computed data point', residue, ES, "", "")
    ).

unique_dp_words(Ws0, Ws) :-
    atomic_list_concat(Ws0, ' ', W0),
    (   sym(dpwords, _, W0) -> append(Ws0, [two], Ws1), unique_dp_words(Ws1, Ws) ; Ws = Ws0 ).

dp_note(DP, Note) :-
    findall(S, ( member(K, [unit, format, sensitive, validation]), j(DP, K, V), format(string(S), "~w: ~w", [K, V]) ), Ss),
    atomic_list_concat(Ss, "; ", Note).

type_noun(T, Noun) :-
    (   memberchk(T, [number, integer, currency, percentage, count]) -> Noun = number
    ;   T == boolean -> Noun = 'truth value'
    ;   T == date -> Noun = date
    ;   T == datetime -> Noun = 'date and time'
    ;   T == duration -> Noun = duration
    ;   Noun = text
    ).

field_lit(SId, FId, X, V, L) :-
    (   sym(field, SId-FId, f(F, _)) -> true
    ;   set_noun(SId, Noun), sym(fieldwords, SId-FId, FWs), atomic_list_concat(FWs, ' ', FW),
        (   set_field(SId, FId, object, S2) -> set_noun(S2, N2), format(string(T), "*a ~w* has ~w *a ~w*", [Noun, FW, N2])
        ;   set_field(SId, FId, scalar, Ty), type_noun(Ty, N2), format(string(T), "the ~w of *a ~w* is *a ~w*", [FW, Noun, N2])
        ),
        declare(field, SId-FId, T, 2, [undefined], F)
    ),
    L =.. [F, X, V].

%!  ruml_value(+DataPointType, +JSON, -Constant) is det.
%   A value of a case, as the twin states it.
ruml_value(date, S, date(Y, M, D)) :- string(S), split_string(S, "-", "", [Ys, Ms, Ds]),
    number_string(Y, Ys), number_string(M, Ms), number_string(D, Ds), !.
ruml_value(_, @(true), true) :- !.
ruml_value(_, @(false), false) :- !.
ruml_value(_, V, V).

		 /*******************************
		 *     WHICH NODES ARE DECIDED  *
		 *******************************/

%   A DELEGATED node and a recursive node need to know whether each of
%   their children is decided; a child's being decided needs its own
%   children's, down to the leaves.
mark_decided(Doc) :-
    (   mode(exact)
    ->  nodes(Doc, Ns),
        forall(( member(K-N, Ns), ( operator(N, 'DELEGATED') ; recursive(K, N) ) ), need(Doc, K))
    ;   true
    ).
need(Doc, K) :-
    (   needs_decided(K) -> true
    ;   assertz(needs_decided(K)),
        node(Doc, K, N), own_children(K, N, Cs), forall(member(C, Cs), need(Doc, C))
    ).

		 /*******************************
		 *            NODES             *
		 *******************************/

translate_node(Doc, K, N) :-
    words(K, W),
    (   catch(translate_node_(Doc, K, N), unsupported(What), ( residue_node(K, N, What), fail ))
    ->  true
    ;   true
    ),
    ignore(W = _).

translate_node_(Doc, K, N) :-
    own_children(K, N, Cs),
    operator(N, Op),
    (   Cs == []
    ->  translate_leaf(Doc, K, N)
    ;   recursive(K, N)
    ->  translate_recursive(K, N, Op, Cs)
    ;   translate_parent(Doc, K, N, Op, Cs)
    ).

rule_opts(K, Opts) :- ( node_doc(K, O) -> Opts = O ; Opts = [] ).

%   --- parents ---
translate_parent(_, K, _, Op, Cs) :-
    memberchk(Op, ['AND', 'OR', 'XOR']), !,
    Head = H, holds(K, C, H),
    parent_rules(Op, K, C, H, Cs),
    decided_rules(K, Op, Cs),
    format(string(M), "~w over ~w children", [Op, _]), ignore(M = _),
    length(Cs, NC), format(string(Map), "~w of ~d children", [Op, NC]),
    words(K, W), rule_text_ref(K, W, InP),
    ledger_entry(node(K), Op, encoded, Map, InP, ""),
    ignore(Head = _).
translate_parent(_, K, _, Op, Cs) :-
    memberchk(Op-Base, ['NOT_AND'-'AND', 'NOT_OR'-'OR', 'NOT_XOR'-'XOR']), !,
    aux(K, Op, C, A), holds(K, C, H),
    parent_rules(Base, K, C, A, Cs),
    rule_opts(K, Opts),
    emit(rule(H, not(A), Opts)),
    decided_rules(K, Base, Cs),
    length(Cs, NC), format(string(Map), "~w of ~d children: the negation of a second sentence", [Op, NC]),
    words(K, W), rule_text_ref(K, W, InP),
    ledger_entry(node(K), Op, encoded, Map, InP, "").
translate_parent(Doc, K, N, 'DELEGATED', Cs) :- !,
    node_caps(N, Es),
    (   member(cap(Id, P), Es), capability_role(Doc, Id, combiner) -> true ; throw(unsupported("a DELEGATED node without a combiner")) ),
    holds(K, C, H), rule_opts(K, Opts),
    (   Id == 'ruml:expression'
    ->  j(P, expression, ES), j(P, description, Desc, ""),
        (   jsonata_parse(ES, E) -> true ; throw(unsupported(ES)) ),
        Env = env(C, case, Cs, K),
        compile_bool(E, Env, T, U)
    ;   Id == 'org.ruml.test/combiner'
    ->  j(P, pickChildResult, I), ( nth1(I, Cs, CI) -> holds(CI, C, T) ; T = fail ), U = fail,
        j(P, description, Desc, ""), ES = "pickChildResult"
    ;   throw(unsupported(Id))
    ),
    (   mode(exact)
    ->  decided(K, C, D),
        emit(rule(H, and(D, T), [comment(Desc)|Opts])),
        would(K, C, Wd),
        emit(rule(H, and(not(D), Wd), [])),
        dec_all(Cs, C, All),
        ( U == fail -> DB = All ; DB = and(All, not(U)) ),
        emit(rule(D, DB, []))
    ;   emit(rule(H, T, [comment(Desc)|Opts])),
        (   U \== fail, \+ mode(closed) -> would(K, C, Wd), emit(rule(H, and(U, Wd), [])) ; true )
    ),
    format(string(Map), "DELEGATED: ~w", [ES]),
    words(K, W), rule_text_ref(K, W, InP),
    (   mode(exact) -> Note = "exact: undefined whenever a child is undefined, as the combiner contract says (§3.6.4)" ; Note = "" ),
    ledger_entry(node(K), 'DELEGATED', encoded, Map, InP, Note).
translate_parent(_, _, _, Op, _) :-
    format(string(M), "the operator ~w (a draft)", [Op]), throw(unsupported(M)).

parent_rules('AND', K, C, H, Cs) :- !,
    maplist({C}/[Ch, L]>>holds(Ch, C, L), Cs, Ls), conj_list(Ls, B), rule_opts(K, O), emit(rule(H, B, O)).
parent_rules(_, K, C, H, Cs) :-
    rule_opts(K, O),
    forall(member(Ch, Cs), ( holds(Ch, C, L), emit(rule(H, L, O)) )).

%   decided: AND is decided when a child is decided and false, or every
%   child is decided; OR and XOR when a child holds, or every child is
%   decided (§3.6, `complete` mode).
decided_rules(K, Op, Cs) :-
    (   needs_decided(K)
    ->  decided(K, C, D),
        dec_all(Cs, C, All), emit(rule(D, All, [])),
        forall(member(Ch, Cs),
               ( decided(Ch, C, DC), holds(Ch, C, HC),
                 ( Op == 'AND' -> emit(rule(D, and(DC, not(HC)), [])) ; emit(rule(D, and(DC, HC), [])) ) ))
    ;   true
    ).

dec_all(Cs, C, All) :- maplist({C}/[Ch, L]>>decided(Ch, C, L), Cs, Ls), conj_list(Ls, All).

%   --- a recursive node (§6.4, plan §5) ---
translate_recursive(K, _, Op, Cs) :-
    memberchk(Op, ['XOR', 'OR', 'NOT_XOR']), !,
    (   Op == 'NOT_XOR' -> aux(K, Op, C, A), holds(K, C, H0), emit(rule(H0, not(A), [])), H = A
    ;   holds(K, C, H)
    ),
    parent_rules('OR', K, C, H, Cs),
    (   mode(closed) -> true
    ;   decided(K, C, D), would(K, C, Wd),
        emit(rule(H, and(not(D), Wd), [comment("A round that no exit decides: RUML's evaluator goes on to its depth limit, and answers undefined (§6.4).")])),
        forall(( member(Ch, Cs) ), ( decided(Ch, C, DC), holds(Ch, C, HC), emit(rule(D, and(DC, HC), [])) )),
        forall(member(Ch, Cs), need_child(Ch))
    ),
    words(K, W), rule_text_ref(K, W, InP),
    ledger_entry(node(K), Op, approximated, "a recursive node: its exits, and an assumption where no exit decides",
                 InP, "every round of RUML 1.0 sees the same data, so the twin answers as RUML's evaluator does at its depth limit").
translate_recursive(_, _, Op, _) :-
    format(string(M), "a recursive node with the operator ~w", [Op]), throw(unsupported(M)).

need_child(Ch) :- doc(Doc), need(Doc, Ch).

%   --- leaves ---
translate_leaf(Doc, K, N) :-
    node_caps(N, Es),
    findall(D, ( member(cap(Id, P), Es), capability_role(Doc, Id, decision), decision_of(Id, P, D) ), Ds),
    (   Ds == []
    ->  holds(K, C, H), answer(K, C, true, A), rule_opts(K, Opts),
        emit(rule(H, A, Opts)),
        (   mode(closed) -> true
        ;   answer(K, C, _, A0), would(K, C, Wd),
            emit(rule(H, and(not(A0), Wd), [comment("Until a person answers, RUML's answer is undefined: the leaf holds only on the assumption below.")]))
        ),
        (   needs_decided(K) -> decided(K, C, D), answer(K, C, _, A1), emit(rule(D, A1, [])) ; true ),
        words(K, W), rule_text_ref(K, W, InP),
        ledger_entry(node(K), leaf, encoded, "a leaf with no deciding capability: a person's answer, a fact of the case (`the answer to ... is true`)", InP, "RUML: undefined until answered")
    ;   j(N, decisionMode, DM0) -> atom_string(DM, DM0), leaf_rules(Doc, K, DM, Ds)
    ;   leaf_rules(Doc, K, fallback, Ds)
    ).

decision_of('ruml:query', P, query(E, D)) :- !, j(P, expression, E), j(P, description, D, "").
decision_of('ruml:ai-query', P, ai(P)) :- !.
decision_of('ruml:tree-include', P, include(U)) :- !, j(P, uri, U).
decision_of('org.ruml.test/decision', P, fixed(R)) :- !, j(P, result, R0), atom_string(R, R0).
decision_of(Id, _, other(Id)).

leaf_rules(_, _, DM, [_, _|_]) :- memberchk(DM, [agreement, majority]), !,
    format(string(M), "the decision mode ~w over several deciding capabilities", [DM]), throw(unsupported(M)).
leaf_rules(_, K, _, Ds) :-
    holds(K, C, H), rule_opts(K, Opts),
    foldl(leaf_decision(K, C, H, Opts), Ds, true-[], Prior-Notes),
    (   Prior \== fail, \+ mode(closed)
    ->  would(K, C, Wd),
        emit(rule(H, and(Prior, Wd), [comment("Where the expression has no result (a value it needs is missing), RUML's answer is undefined: the leaf holds only on the assumption below.")]))
    ;   true
    ),
    (   needs_decided(K)
    ->  decided(K, C, D), ( Prior == true -> true ; Prior == fail -> emit(rule(D, true, [])) ; neg(Prior, NP), emit(rule(D, NP, [])) )
    ;   true
    ),
    reverse(Notes, Ns), atomic_list_concat(Ns, '; ', Map),
    ( member(approx(_), Ds) -> V = approximated ; V = encoded ),
    words(K, W), rule_text_ref(K, W, InP),
    ledger_entry(node(K), leaf, V, Map, InP, "").

%   Prior: the condition under which no earlier capability decided (true
%   at the start). Each capability adds a rule for the case where it says
%   true, and narrows Prior to where it says nothing.
leaf_decision(K, C, H, Opts0, query(ES, Desc), Prior-Ns, Prior1-[Note|Ns]) :- !,
    (   jsonata_parse(ES, E) -> true ; throw(unsupported(ES)) ),
    compile_bool(E, env(C, case, none, K), T, U),
    ( Desc == "" -> Opts = Opts0 ; Opts = [comment(Desc)|Opts0] ),
    conj(Prior, T, B), ( B == fail -> true ; emit(rule(H, B, Opts)) ),
    ( mode(closed) -> Prior1 = fail ; conj(Prior, U, Prior1) ),
    format(string(Note), "ruml:query ~w", [ES]).
leaf_decision(K, C, H, Opts, ai(P), Prior-Ns, fail-[Note|Ns]) :- !,
    judged(K, C, J), conj(Prior, J, B), emit(rule(H, B, Opts)),
    ( j(P, prompt, Pr) -> true ; Pr = "" ),
    format(string(Note), "ruml:ai-query: a judged sentence (the prompt: ~w)", [Pr]).
leaf_decision(K, C, _, _, include(U), Prior-Ns, Prior-[Note|Ns]) :- !,
    format(string(Note), "ruml:tree-include of ~w: not available here, so the leaf is undefined, as the specification asks (§4.16)", [U]),
    ignore(K = _), ignore(C = _).
leaf_decision(_, _, H, Opts, fixed(R), Prior-Ns, Prior1-[Note|Ns]) :- !,
    (   R == true -> conj(Prior, true, B), emit(rule(H, B, Opts)), Prior1 = fail
    ;   R == false -> Prior1 = fail
    ;   Prior1 = Prior
    ),
    format(string(Note), "a test capability that answers ~w", [R]).
leaf_decision(_, _, _, _, other(Id), _, _) :-
    format(string(M), "the deciding capability ~w", [Id]), throw(unsupported(M)).

%   --- what is not translated ---
residue_node(K, N, What) :-
    words(K, W), holds(K, C, H),
    ( string(What) -> WS = What ; format(string(WS), "~w", [What]) ),
    j(N, label, L, ""),
    format(string(Title), "node ~w: ~w", [K, L]),
    new_functor(r, RId),
    emit(residue(RId, [title(Title), note(WS), concludes([])])),
    assertz(sym(residue_node, K, RId)),
    (   mode(closed) -> true
    ;   would(K, C, Wd), emit(rule(H, Wd, [comment("Not translated (the residue block above): the node is undefined, as RUML's evaluator answers for what it cannot evaluate.")]))
    ),
    (   needs_decided(K) -> decided(K, _, _) ; true ),
    rule_text_ref(K, W, InP),
    ledger_entry(node(K), node, residue, WS, InP, "").

rule_text_ref(_, W, InP) :- format(string(InP), "~w holds for *a case*", [W]).

		 /*******************************
		 *     JSONATA → CONDITIONS     *
		 *******************************/

%   compile_bool(+Expr, +Env, -T, -U): T the conditions under which the
%   expression is true, U those under which it has no boolean result (no
%   result, or one that is not true or false), each an IR body, `true` or
%   `fail`. Env = env(Case, Self, Children, LexId): Self is `case`, or
%   elem(X, Set) inside a filter on a set; Children the node's children
%   (a DELEGATED node) or none.

compile_bool(block([E]), Env, T, U) :- !, compile_bool(E, Env, T, U).
compile_bool(bool(true), _, true, fail) :- !.
compile_bool(bool(false), _, fail, fail) :- !.
compile_bool(bin(Op, A, B), Env, T, U) :-
    memberchk(Op-Ir, ['<'-(<), '<='-(=<), '>'-(>), '>='-(>=)]), !,
    compile_val(A, Env, VA, BA, MA), compile_val(B, Env, VB, BB, MB),
    Cmp =.. [Ir, VA, VB],
    conj_list([BA, BB, Cmp], T), disj(MA, MB, U).
compile_bool(bin(Op, A, B), Env, T, fail) :-
    memberchk(Op, ['=', '!=']), child_status(A, B, Env, Ch, S), !,
    Env = env(C, _, _, _), holds(Ch, C, L),
    (   same_sense(Op, S) -> T = L ; T = not(L) ).
compile_bool(bin('=', A, B), Env, T, fail) :- !,
    eq_literal(A, B, Env, T).
compile_bool(bin('!=', A, B), Env, T, fail) :- !,
    compile_val(A, Env, VA, BA, _), compile_val(B, Env, VB, BB, _),
    conj_list([BA, BB, VA \= VB], T).
compile_bool(bin(in, A, array(Es)), Env, T, fail) :- !,
    maplist({A}/[E, bin('=', A, E)]>>true, Es, Eqs),
    maplist({Env}/[Q, TQ]>>compile_bool(Q, Env, TQ, _), Eqs, Ts), disj_list(Ts, T).
compile_bool(bin(and, A, B), Env, T, fail) :- !,
    cast(A, Env, TA), cast(B, Env, TB), conj(TA, TB, T).
compile_bool(bin(or, A, B), Env, T, fail) :- !,
    cast(A, Env, TA), cast(B, Env, TB), disj(TA, TB, T).
compile_bool(call(not, [X]), Env, T, U) :- !,
    compile_bool(X, Env, TX, UX), neg(UX, NU), neg(TX, NT), conj(NU, NT, T), U = UX.
compile_bool(call(boolean, [X]), Env, T, fail) :- !, cast(X, Env, T).
compile_bool(call(exists, [X]), Env, T, fail) :- !, compile_val(X, Env, _, T, _).
compile_bool(call(lookup, [object(Ps), K]), Env, T, U) :- !,
    findall(Key-B, ( member(str(Key)-bool(B), Ps) ), KBs),
    shared_findall(Env, TK, ( member(Key-true, KBs), eq_literal(K, str(Key), Env, TK) ), Ts), disj_list(Ts, T),
    shared_findall(Env, N, ( member(Key-_, KBs), eq_literal(K, str(Key), Env, TK), neg(TK, N) ), Ns), conj_list(Ns, U).
compile_bool(cond(Cn, A, B), Env, T, U) :- !,
    cast(Cn, Env, TC), neg(TC, NC),
    compile_bool(A, Env, TA, UA),
    ( B == none -> TB = fail, UB = true ; compile_bool(B, Env, TB, UB) ),
    conj(TC, TA, T1), conj(NC, TB, T2), disj(T1, T2, T),
    conj(TC, UA, U1), conj(NC, UB, U2), disj(U1, U2, U).
compile_bool(name(N), Env, T, U) :- dp_boolean(N), !,
    eq_literal(name(N), bool(true), Env, T),
    eq_literal(name(N), bool(false), Env, F), neg(T, NT), neg(F, NF), conj(NT, NF, U).
compile_bool(unsupported(W), _, _, _) :- !, format(string(M), "the JSONata construct ~w", [W]), throw(unsupported(M)).
%   A value where a truth value is expected: RUML reads anything but true
%   and false as undefined.
compile_bool(E, Env, fail, true) :- compile_val(E, Env, _, _, _), !.
compile_bool(E, _, _, _) :- jsonata_text(E, S), format(string(M), "the JSONata expression ~w", [S]), throw(unsupported(M)).

dp_boolean(N) :- dp_info(N, scalar, boolean, _).

%   `and` and `or` read each side as a truth value: no result is false; a
%   number is true unless 0, a text unless empty (JSONata's $boolean).
cast(E, Env, T) :- boolean_expr(E), !, compile_bool(E, Env, T, _).
cast(E, Env, T) :- compile_val(E, Env, V, B, _), conj_list([B, V \= false, V \= 0, V \= ""], T).

boolean_expr(bin(Op, _, _)) :- memberchk(Op, ['<', '<=', '>', '>=', '=', '!=', in, and, or]).
boolean_expr(call(F, _)) :- memberchk(F, [not, boolean, exists, lookup]).
boolean_expr(bool(_)).
boolean_expr(cond(_, _, _)).
boolean_expr(block([E])) :- boolean_expr(E).
boolean_expr(name(N)) :- dp_boolean(N).

%   `x = constant`: the constant in the data point's own sentence, which
%   reads best (`the Bundesland of the case is "BY"`).
eq_literal(A, B, Env, T) :-
    (   constant(B, KB), direct(A, Env, KB, L) -> T = L
    ;   constant(A, KA), direct(B, Env, KA, L) -> T = L
    ;   compile_val(A, Env, VA, BA, _), compile_val(B, Env, VB, BB, _), conj_list([BA, BB, VA = VB], T)
    ).

constant(num(N), N).
constant(str(S), S).
constant(bool(B), B).

direct(name(N), env(C, case, _, _), K, L) :- dp_info(N, scalar, Ty, _), !,
    dp_lit(N, C, V, L), typed_constant(Ty, K, V).
direct(name(F), env(_, elem(X, S), _, _), K, L) :- set_field(S, F, scalar, Ty), !,
    field_lit(S, F, X, V, L), typed_constant(Ty, K, V).

typed_constant(date, S, D) :- string(S), ruml_value(date, S, D), D = date(_, _, _), !.
typed_constant(_, K, K).

dp_lit(N, C, V, L) :- lit(dp, N, [C, V], L).

%   `$children[...].status = 'true'` and its forms (a DELEGATED node).
child_status(A, B, Env, Ch, S) :-
    (   status_ref(A, Env, Ch), B = str(S) -> true
    ;   status_ref(B, Env, Ch), A = str(S)
    ).
status_ref(path(filter(var(children), Sel), name(status)), env(_, _, Cs, _), Ch) :- Cs \== none,
    (   Sel = num(I) -> I1 is I + 1, nth1(I1, Cs, Ch)
    ;   findall(C, ( nth1(I, Cs, C), child_matches(Sel, C, I, true) ), [Ch])
    ).

%   compile_val(+Expr, +Env, -Value, -Bind, -Missing): Bind gives Value
%   when the expression has one; Missing holds when it has none.
compile_val(block([E]), Env, V, B, M) :- !, compile_val(E, Env, V, B, M).
compile_val(num(N), _, N, true, fail) :- !.
compile_val(str(S), _, S, true, fail) :- !.
compile_val(bool(B), _, B, true, fail) :- !.
compile_val(null, _, null, true, fail) :- !.
compile_val(name(N), env(C, case, _, _), V, B, M) :- dp_info(N, scalar, _, _), !,
    dp_lit(N, C, V, B), dp_lit(N, C, _, B1), M = not(B1).
compile_val(name(F), env(_, elem(X, S), _, _), V, B, M) :- set_field(S, F, scalar, _), !,
    field_lit(S, F, X, V, B), field_lit(S, F, X, _, B1), M = not(B1).
compile_val(path(A, name(F)), Env, V, B, M) :-
    member_of(A, Env, X, S, BX), set_field(S, F, scalar, _), !,
    field_lit(S, F, X, V, L), conj(BX, L, B),
    member_of(A, Env, X2, S, BX2), field_lit(S, F, X2, _, L2), conj(BX2, L2, B2), M = not(B2).
compile_val(bin(Op, A, B0), Env, V, B, M) :-
    memberchk(Op-Ir, ['+'-(+), '-'-(-), '*'-(*), '/'-(/), '%'-(mod)]), !,
    compile_val(A, Env, VA, BA, MA), compile_val(B0, Env, VB, BB, MB),
    E =.. [Ir, VA, VB], conj_list([BA, BB, V is E], B), disj(MA, MB, M).
compile_val(neg(A), Env, V, B, M) :- !,
    compile_val(A, Env, VA, BA, M), conj(BA, V is -VA, B).
compile_val(call(F, [A]), Env, V, B, M) :-
    memberchk(F-Ir, [abs-abs, floor-floor, ceil-ceiling, sqrt-sqrt, round-round]), !,
    compile_val(A, Env, VA, BA, M), E =.. [Ir, VA], conj(BA, V is E, B).
compile_val(call(power, [A, P]), Env, V, B, M) :- !,
    compile_val(A, Env, VA, BA, MA), compile_val(P, Env, VP, BP, MP),
    conj_list([BA, BP, V is VA ** VP], B), disj(MA, MP, M).
%   Counting children (a DELEGATED node).
compile_val(call(count, [var(children)]), env(_, _, Cs, _), N, true, fail) :- Cs \== none, !, length(Cs, N).
compile_val(call(count, [filter(var(children), P)]), env(C, _, Cs, K), V, B, fail) :- Cs \== none, !,
    shared_findall(C, I-S, ( nth1(I, Cs, Ch), child_condition(P, Ch, I, C, S) ), IS),
    include([_-S]>>(S == true), IS, Always), length(Always, Off),
    exclude([_-S]>>(S == true ; S == fail), IS, Cond),
    (   Cond == [] -> V = Off, B = true
    ;   words(K, W), format(string(T), "child *a number* of ~w counts for *a case*", [W]),
        new_functor(count, F), assertz(sym(count, K-F, f(F, T))), emit(template(F, T, [])),
        forall(member(I-S, Cond), ( H =.. [F, I, C], emit(rule(H, S, [])) )),
        G =.. [F, J, C],
        (   Off =:= 0 -> B = agg(count, J, G, V)
        ;   B = and(agg(count, J, G, V0), V is V0 + Off)
        )
    ).
%   Counting and adding over a set: `$count(dp_guarantors[dp_income > 1000])`.
compile_val(call(count, [Seq]), Env, V, agg(count, X, G, V), fail) :-
    seq(Seq, Env, X, G), !.
compile_val(call(Op, [path(Seq, name(F))]), Env, V, B, M) :-
    memberchk(Op-Ag, [sum-sum, max-max, min-min, average-average]),
    seq(Seq, Env, X, G0), Seq \= var(children), seq_set(Seq, Env, S), set_field(S, F, scalar, _), !,
    field_lit(S, F, X, Y, L), conj(G0, L, G),
    B = agg(Ag, Y, G, V),
    (   Op == sum -> M = fail ; copy_term(X-G, X2-G2), M = not(G2), ignore(X2 = _) ).
compile_val(E, _, _, _, _) :-
    jsonata_text(E, S), format(string(M), "the JSONata expression ~w", [S]), throw(unsupported(M)).

%   A path to one member of a set: `dp_applicant` (a set without
%   cardinality), `dp_applicant.dp_employer`.
member_of(name(N), env(C, case, _, _), X, S, L) :- dp_info(N, object(one), _, S), lit(has, N, [C, X], L).
member_of(path(A, name(F)), Env, X, S2, B) :-
    member_of(A, Env, Y, S, BY), set_field(S, F, object, S2), field_lit(S, F, Y, X, L), conj(BY, L, B).

%   A sequence of members: a set data point, filtered or not.
seq(name(N), env(C, case, _, _), X, L) :- dp_info(N, object(_), _, _), lit(has, N, [C, X], L).
seq(filter(A, P), Env, X, G) :- A \= var(children), P \= num(_),
    seq(A, Env, X, G0), seq_set(A, Env, S),
    Env = env(C, _, Cs, K), compile_bool(P, env(C, elem(X, S), Cs, K), TP, _),
    conj(G0, TP, G).
seq_set(name(N), _, S) :- dp_info(N, object(_), _, S).
seq_set(filter(A, _), Env, S) :- seq_set(A, Env, S).

%   What a filter on $children says of child Ch (the I-th): its status as
%   the child's sentence, its lexId and label as constants.
child_condition(P, Ch, I, C, S) :-
    child_cond(P, Ch, I, C, S0), simplify(S0, S).
child_cond(bin(and, A, B), Ch, I, C, S) :- !, child_cond(A, Ch, I, C, SA), child_cond(B, Ch, I, C, SB), conj(SA, SB, S).
child_cond(bin(or, A, B), Ch, I, C, S) :- !, child_cond(A, Ch, I, C, SA), child_cond(B, Ch, I, C, SB), disj(SA, SB, S).
child_cond(call(not, [A]), Ch, I, C, S) :- !, child_cond(A, Ch, I, C, SA), neg(SA, S).
child_cond(bin(Op, name(status), str(V)), Ch, _, C, S) :- memberchk(Op, ['=', '!=']), !,
    holds(Ch, C, L), ( same_sense(Op, V) -> S = L ; S = not(L) ).
child_cond(bin(Op, str(V), name(status)), Ch, I, C, S) :- !, child_cond(bin(Op, name(status), str(V)), Ch, I, C, S).
child_cond(P, Ch, I, _, S) :- ( child_matches(P, Ch, I, true) -> S = true ; S = fail ).

%   `status = 'true'` and `status != 'false'` ask that the child hold.
same_sense('=', "true").
same_sense('!=', "false").

child_matches(bin('=', name(lexId), str(L)), Ch, _, R) :- !, atom_string(Ch, CS), ( CS == L -> R = true ; R = false ).
child_matches(bin('!=', name(lexId), str(L)), Ch, _, R) :- !, atom_string(Ch, CS), ( CS \== L -> R = true ; R = false ).
child_matches(bin(in, name(lexId), array(Ls)), Ch, _, R) :- !, atom_string(Ch, CS), ( memberchk(str(CS), Ls) -> R = true ; R = false ).
child_matches(bin('=', name(label), str(L)), Ch, _, R) :- !, doc(D), node(D, Ch, N), j(N, label, L0, ""), ( L0 == L -> R = true ; R = false ).
child_matches(P, _, _, _) :- jsonata_text(P, S), format(string(M), "the filter on $children ~w", [S]), throw(unsupported(M)).

		 /*******************************
		 *          BODIES              *
		 *******************************/

%!  shared_findall(+Shared, +Template, :Goal, -List) is det.
%   findall/3 copies its results: the case variable (and anything else in
%   Shared) would no longer be the rule's. This keeps it shared.
shared_findall(Shared, T, G, L) :-
    findall(T-Shared, G, Ps),
    maplist(unshare(Shared), Ps, L).
unshare(S, T-S, T).

conj(true, B, B) :- !.
conj(A, true, A) :- !.
conj(fail, _, fail) :- !.
conj(_, fail, fail) :- !.
conj(A, B, and(A, B)).
disj(fail, B, B) :- !.
disj(A, fail, A) :- !.
disj(true, _, true) :- !.
disj(_, true, true) :- !.
disj(A, B, or(A, B)).
neg(true, fail) :- !.
neg(fail, true) :- !.
neg(not(A), A) :- !.
neg(A, not(A)).
conj_list(Ls, B) :- foldl([L, B0, B1]>>conj(B0, L, B1), Ls, true, B).
disj_list(Ls, B) :- foldl([L, B0, B1]>>disj(B0, L, B1), Ls, fail, B).
simplify(S, S).

		 /*******************************
		 *   TEXTS, DOCUMENTS (step 4)  *
		 *******************************/

%   The texts of ruml:text-reference are documents of the twin: a text
%   with an address is `published at` it; a text in the file was written
%   by build/import under sources/ (option texts(Dir) gives the relative
%   paths, Key-Path). A node's anchors become the provenance of its rules:
%   `as stated in` the text that it represents, and `at` the element's
%   number where the text has one.
texts_and_documents(Doc, Options) :-
    option(texts(Texts), Options, []),
    capabilities(Doc, Cs),
    (   member(C, Cs), j(C, id, "ruml:text-reference"), j(C, payload, P), j(P, data, json(D))
    ->  forall(member(Key=T, D), text_document(Key, T, Texts))
    ;   true
    ),
    (   member(C2, Cs), j(C2, id, "ruml:context"), j(C2, payload, P2), j(P2, data, json(D2))
    ->  forall(member(Key2=T2, D2), context_document(Key2, T2))
    ;   true
    ).

%   A document's name in the twin: the words of its key (`text_bgb_823`:
%   `bgb 823`), small letters, so that it reads back as a constant; its
%   title goes to the ledger.
doc_name(Key, Name) :-
    atom_string(Key, S),
    (   ( string_concat("text_", R, S) ; string_concat("ctx_", R, S) ), string_codes(R, [C|_]), code_type(C, alpha) -> true
    ;   R = S
    ),
    split_string(R, "_", "", Ps0), exclude(==(""), Ps0, Ps),
    maplist([P, L]>>string_lower(P, L), Ps, Ls), atomic_list_concat(Ls, ' ', Name).

text_document(Key, T, Texts) :-
    doc_name(Key, Name), j(T, title, Title, ""),
    assertz(sym(text, Key, Name)),
    (   j(T, uri, U) -> Opts = [url(U)]
    ;   j(T, url, U) -> Opts = [url(U)]
    ;   memberchk(Key-Path, Texts) -> Opts = [text(Path)]
    ;   Opts = []
    ),
    (   Opts == [] -> true ; emit(document(Name, Opts)) ),
    ( j(T, content, _) -> Kind = "a law carried as Akoma Ntoso" ; j(T, text, _) -> Kind = "a text carried in the file" ; Kind = "a text named by its address" ),
    format(string(Map), "a document of the twin (~w)", [Kind]),
    ledger_entry(text(Key), text, encoded, Map, Name, Title).

context_document(Key, T) :-
    doc_name(Key, Name), j(T, title, Title, ""),
    j(T, category, Cat, ""),
    (   j(T, url, U) -> emit(document(Name, [url(U)])) ; true ),
    format(string(Map), "context material (~w): ~w", [Cat, Title]),
    ledger_entry(context(Key), context, approximated, Map, Name, "context material is listed, not reasoned with").

%   A node's own anchors: the provenance of its rules.
node_documents(K, N) :-
    node_caps(N, Es),
    (   member(cap('ruml:text-reference', P), Es), j(P, refs, Refs), Refs \== []
    ->  (   member(R, Refs), j(R, type, "represents") -> true ; Refs = [R|_] ),
        j(R, id, TK0), atom_string(TK, TK0),
        (   sym(text, TK, DocName)
        ->  ( j(R, element, El) -> element_locator(TK, El, Loc) ; Loc = none ),
            ( Loc == none -> Prov = [as_stated_in(DocName)] ; Prov = [as_stated_in(DocName), at(Loc)] ),
            format(atom(Label), 'node_~w', [K]),
            assertz(node_doc(K, [label(Label), provenance(Prov)]))
        ;   true
        )
    ;   true
    ),
    (   member(cap('ruml:tree-reference', P2), Es)
    ->  findall(U, ( ( j(P2, represents, R2) ; j(P2, refersTo, L2), member(R2, L2) ), j(R2, uri, U) ), Us),
        atomic_list_concat(Us, ', ', UA),
        ledger_entry(node(K), 'tree reference', encoded, "a reference to a node of another rulemap, kept in the ledger", UA, "not evaluated, as in RUML")
    ;   true
    ).

%   The element an anchor names: its `eId` or `num` in the RUML Text, when
%   the text has one; else none.
element_locator(TK, GUID, Loc) :-
    doc(Doc), capabilities(Doc, Cs),
    member(C, Cs), j(C, id, "ruml:text-reference"), j(C, payload, P), j(P, data, D), j(D, TK, T),
    j(T, content, Content), find_element(Content, GUID, El), !,
    (   j(El, attrs, A), j(A, eId, EId) -> Loc = EId
    ;   Loc = GUID
    ).
element_locator(_, G, G).

find_element(E, G, E) :- j(E, attrs, A), j(A, 'GUID', G), !.
find_element(E, G, F) :- j(E, content, Cs), is_list(Cs), member(C, Cs), C = json(_), find_element(C, G, F), !.

		 /*******************************
		 *           METADATA           *
		 *******************************/

metadata_comment(Doc, DocName, C) :-
    j(Doc, metadata, M),
    findall(S, ( member(K, [title, id, version, status, documentType, jurisdiction, language, legalDomain, validFrom, validUntil, organization]),
                 j(M, K, V), format(string(S), "~w: ~w", [K, V]) ), Ss),
    atomic_list_concat(Ss, "\n", Lines),
    format(string(C), "The Logical English twin of the RUML rulemap ~w, written by the RUML translator.\nA case is the subject of every sentence: `... holds for *a case*`. A sentence that holds only with unknowns is RUML's `undefined`.\n~w", [DocName, Lines]).

ledger_metadata(Doc) :-
    j(Doc, metadata, M),
    findall(K, ( member(K=_, json_pairs(M)) ), _),
    ledger_entry(metadata, metadata, approximated, "a comment at the top; the original file under sources/", "", "status, version, validity, authors: data about the file, not rules (decision 6 of the plan)"),
    capabilities(Doc, Cs),
    forall(( member(C, Cs), j(C, id, Id0), atom_string(Id, Id0),
             \+ memberchk(Id, ['ruml:datapoints', 'ruml:query', 'ruml:expression', 'ruml:text-reference', 'ruml:context',
                               'ruml:tree-reference', 'ruml:tree-include', 'org.ruml.test/decision', 'org.ruml.test/combiner']) ),
           capability_ledger(Id)).

json_pairs(json(Ps), Ps).

capability_ledger('ruml:actions') :- !,
    ledger_entry(capability('ruml:actions'), capability, residue, "actions: a reaction, not a rule; the LPS companion is step 7 of the plan (delayed)", "", "").
capability_ledger('ruml:protocol') :- !,
    ledger_entry(capability('ruml:protocol'), capability, encoded, "the record of a run: written by the evaluator (ruml_result.pl)", "", "").
capability_ledger('ruml:ai-query') :- !.
capability_ledger(Id) :-
    ledger_entry(capability(Id), capability, approximated, "a capability the twin does not use: kept in the original under sources/", "", "").

		 /*******************************
		 *            TESTS             *
		 *******************************/

%   A query for a node and for its negation: the three results of RUML are
%   told apart by the two (true: the first answers with no unknowns, the
%   second not at all; false: the reverse; undefined: both answer, with
%   unknowns).
node_query(L, Q) :- format(atom(Q), 'node_~w', [L]).
node_negation_query(L, Q) :- format(atom(Q), 'not_node_~w', [L]).

node_queries(L, [query(Q, H), query(QN, not(H))]) :-
    sym(node, L, _), case_constant(C), holds(L, C, H),
    node_query(L, Q), node_negation_query(L, QN).

case_test(DocName, case(Id, Desc, Inputs, Expected), test(Id, DocName, Loc, Facts, Exps)) :-
    case_constant(C),
    findall(F, ( member(DP-V, Inputs), input_facts(DP, V, C, Fs), member(F, Fs) ), Facts0),
    ( Desc == '' -> Facts = Facts0 ; Facts = [comment(Desc)|Facts0] ),
    format(atom(Loc), '~w', [Id]),
    findall(E, ( member(L-S, Expected), sym(node, L, _), status_expectations(L, S, C, Es), member(E0, Es), pending_residue(L, E0, E) ), Exps).

%   A node that is residue, or above one: its expected results wait for the
%   residue block to be translated (le_migration counts them as pending).
pending_residue(L, E0, E) :-
    (   waits_for_residue(L, R) -> format(string(W), "waits for residue ~w (node ~w)", [R, L]), E = pending(W, E0) ; E = E0 ).
waits_for_residue(L, R) :- sym(residue_node, L, R), !.
waits_for_residue(L, R) :- doc(D), node(D, L, N), j(N, children, Cs), member(S, Cs), atom_string(C, S), C \== L, waits_for_residue(C, R), !.

status_expectations(L, S, C, [expects(Q, A1, U1), expects(QN, A2, U2)]) :-
    node_query(L, Q), node_negation_query(L, QN),
    holds(L, C, H), sym(node, L, f(_, Text)), sub_atom(Text, B, _, 0, '*a case*'), sub_atom(Text, 0, B, _, Pre),
    format(string(Pos), "~w~w", [Pre, C]), format(string(Neg), "it is not the case that ~w~w", [Pre, C]),
    ignore(H = _),
    %   true: the negation has no answer (an answer proved without unknowns
    %   makes its negation false), whatever else the sentence may rest on
    (   S == true -> A1 = [Pos], U1 = any, A2 = [], U2 = []
    ;   S == false -> A1 = [], U1 = [], A2 = [Neg], U2 = []
    ;   A1 = [Pos], U1 = any, A2 = [Neg], U2 = any
    ).

%   The facts of a value of a case: a scalar data point is one sentence; a
%   set's members are constants named after the data point (`guarantor
%   1`), with a sentence for each field.
input_facts(DP0, V, C, Fs) :-
    ( ( atom(DP0) ; compound(DP0) ) -> DP = DP0 ; atom_string(DP, DP0) ),
    (   ( V == null ; V == @(null) ) -> Fs = []
    ;   DP = '$leaf'(K) -> ( V == true -> answer(K, C, true, L), Fs = [L] ; V == false -> answer(K, C, false, L), Fs = [L] ; Fs = [] )
    ;   dp_info(DP, scalar, T, _), number_type(T), \+ number(V) -> Fs = []     % JSONata compares no text with a number
    ;   dp_info(DP, scalar, T, _), lit(dp, DP, [C, X], L) -> ruml_value(T, V, X), Fs = [L]
    ;   dp_info(DP, object(_), _, S), lit(has, DP, [C, _], _)
    ->  ( is_list(V) -> Vs = V ; Vs = [V] ),
        sym(dpwords, DP, W),
        findall(F, ( nth1(I, Vs, O), format(atom(M), '~w ~d', [W, I]), lit(has, DP, [C, M], H),
                     ( F = H ; member_facts(S, M, O, F) ) ), Fs)
    ;   Fs = []
    ).

member_facts(S, M, O, F) :-
    object_pairs(O, Ps), member(FId-V, Ps), V \== null, V \== @(null),
    (   set_field(S, FId, scalar, T) -> ruml_value(T, V, X), field_lit(S, FId, M, X, F)
    ;   set_field(S, FId, object, S2) -> ( is_list(V) -> Vs = V ; Vs = [V] ),
        sym(fieldwords, S-FId, FWs), atomic_list_concat(FWs, ' ', FW),
        nth1(I, Vs, O2), format(atom(M2), '~w ~w ~d', [M, FW, I]),
        ( field_lit(S, FId, M, M2, F) ; member_facts(S2, M2, O2, F) )
    ).

object_pairs(json(Ps), KVs) :- !, findall(K-V, member(K=V, Ps), KVs).
object_pairs(D, KVs) :- is_dict(D), !, dict_pairs(D, _, KVs).
object_pairs(_, []).

%   A node's ledger entry keeps the node's label as RUML wrote it.
labelled_entry(Doc, entry(node(K), Kd, V, M, P, N0), entry(node(K), Kd, V, M, P, N)) :-
    node(Doc, K, Nd), j(Nd, label, L), !,
    (   N0 == "" -> format(string(N), "label: ~w", [L]) ; format(string(N), "label: ~w; ~w", [L, N0]) ).
labelled_entry(_, E, E).

number_type(T) :- memberchk(T, [number, integer, currency, percentage, count]).

/** <module> File ▸ Export ▸ RUML: a Logical English program as a RUML rulemap

    The way back of the design notes ruml.md §6. One `.ruml` file for the
    program's first query about one thing (a RUML file has one root):

    - a sentence that rules conclude is a node: one rule is an AND of its
      conditions, several rules an OR, one per rule; `it is not the case
      that` is a NOT_AND over the sentence it denies (NOT_OR when that
      sentence has several rules);
    - a sentence that no rule concludes is a leaf: a data point of the case
      (`*a case* is resident`: a yes-or-no data point, `ruml:query`
      `dp_resident = true`) when scenarios state it, a leaf that a person
      decides when it is judged or assumable;
    - a value that scenarios state (`the age of *a case* is *a number*`) is
      a data point; the conditions on values are one `ruml:query`
      expression in JSONata; a value that rules calculate is a computed
      data point;
    - the forms the RUML translator writes into a twin (ruml_twin.pl) are
      read back as what they were: `... would hold for` and `... is decided
      for` are RUML's own `undefined` and are dropped, a count over `child
      ... counts for` is a DELEGATED node with `ruml:expression`.

    The Logical English travels as comments (decision 4 of the plan, as
    taken): each node's `description` holds the rules it came from, and the
    file's `metadata.comment` the whole program. The scenarios are context
    materials of the category `example`, with the values they state.

    What RUML cannot say is refused before anything is written, each
    problem on its line (le_import's export_check): relations between
    things, a sentence about two things, rules that use themselves,
    aggregates other than the count of a twin, integrity constraints, LPS.

        export_ruml(+KB, +Options, -Result)    exported(File, Text, Notes, []) | refused(Problems)
        applies_ruml(+KB)
        check_ruml(+KB, +Options, -Problems)
        ruml_export_doc(+KB, +Options, -Doc, -Problems)
*/

:- module(ruml_export, [export_ruml/3, applies_ruml/1, check_ruml/3, ruml_export_doc/4]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(pairs)).
:- use_module(library(sha)).
:- use_module(library(http/json)).
:- use_module(le2(le_writer)).
:- use_module(ruml_reader).
:- use_module(ruml_names).
:- use_module(jsonata_parser).
:- use_module(library(pcre)).
:- use_module(le2(le_kbs)).

:- dynamic problem/2.         % Where, Message
:- dynamic xnode/3.           % Key, LexId, json fields (built)
:- dynamic key_lex/2.         % Key, LexId
:- dynamic counter/1.
:- dynamic dp/4.              % Functor, Id, Name, Type
:- dynamic uses/2.            % LexId of a child, times referenced
:- dynamic tmpl/4.            % Functor, Arity, Text, Additions
:- dynamic rule_/3.           % Head, Body, Position
:- dynamic doc_text/1.
:- dynamic program_name/1.
:- dynamic original/1.        % the original rulemap of a twin
:- dynamic caps_used/1.
:- dynamic children_of/2.

		 /*******************************
		 *        THE REGISTRY          *
		 *******************************/

%!  applies_ruml(+KB) is semidet.
%   A program with a rule whose conclusion is a sentence about one thing (or
%   about nothing): a candidate for a RUML tree.
applies_ruml(KB) :-
    le_writer:kb_to_ir(KB, program(H, Items)),
    \+ memberchk(target(lps), H),
    member(rule(Head, _, _), Items), functor(Head, _, A), A =< 1, !.

check_ruml(KB, Options, Problems) :-
    catch(ruml_export_doc(KB, Options, _, Problems), E,
          ( message_to_codes(E, Cs), string_codes(S, Cs), Problems = [problem(none, S)] )).

export_ruml(KB, Options, Result) :-
    ruml_export_doc(KB, Options, Doc, Problems),
    (   Problems \== [] -> Result = refused(Problems)
    ;   with_output_to(string(Text), json_write(current_output, Doc, [width(100)])),
        program_name(Name),
        format(atom(File), '~w.ruml', [Name]),
        nodes(Doc, Ns), length(Ns, NN),
        findall(I, ( dp(_, I, _, _) ), DPs), length(DPs, ND),
        format(string(N1), "One RUML 1.0 rulemap of ~d nodes and ~d data points: the program's sentences as nodes, its conditions on values as ruml:query expressions in JSONata.", [NN, ND]),
        N2 = "The Logical English text travels as comments: each node's description holds its rules, the metadata's comment the whole program; File > Open of this file in Logical English finds it.",
        N3 = "RUML's undefined result is RUML's own: the sentences that a Logical English twin of a rulemap adds for it (\"would hold\", \"is decided\") are not written.",
        ( original(_) -> N4 = ["The identifiers, the metadata and the data points of the original rulemap (sources/) are kept."] ; N4 = [] ),
        append([N1, N2, N3], N4, Notes),
        Result = exported(File, Text, Notes, [])
    ).

message_to_codes(E, Cs) :- catch(message_to_codes(E, [], Cs0), _, fail), !, Cs = Cs0.
message_to_codes(E, Cs) :- format(codes(Cs), "~q", [E]).

		 /*******************************
		 *          THE PROGRAM         *
		 *******************************/

reset :-
    forall(member(P, [problem/2, xnode/3, key_lex/2, counter/1, dp/4, uses/2, tmpl/4, rule_/3, doc_text/1,
                      program_name/1, original/1, caps_used/1, children_of/2]),
           ( P = N/A, functor(T, N, A), retractall(T) )),
    assertz(counter(1)).

%!  ruml_export_doc(+KB, +Options, -Doc, -Problems) is det.
ruml_export_doc(KB, Options, Doc, Problems) :-
    reset,
    le_writer:kb_to_ir(KB, program(H, Items)),
    ( memberchk(kb(N0), H) -> true ; N0 = program ),
    atomic_list_concat(Ws, ' ', N0), atomic_list_concat(Ws, '_', N1), assertz(program_name(N1)),
    ( option(text(T), Options) -> assertz(doc_text(T)) ; true ),
    load_original(Items, Options),
    (   memberchk(target(lps), H) -> add_problem(none, "A program in Logical English for LPS speaks about time; RUML has no time.") ; true ),
    forall(member(template(F, Tx0, Adds), Items), ( norm_template(Tx0, Tx), template_arity(Tx, A), assertz(tmpl(F, A, Tx, Adds)) )),
    %  a template the IR leaves out (one no rule concludes), from the KB itself
    forall(( catch(le_kbs:template_of(KB, F, A, _, Label), _, fail), \+ tmpl(F, A, _, _) ),
           ( norm_template(Label, Tx), template_additions(KB, F, A, Adds), assertz(tmpl(F, A, Tx, Adds)) )),
    forall(member(rule(Hd, B, _), Items), ( first_position(B, P), assertz(rule_(Hd, B, P)) )),
    constraints(KB),
    (   root_sentence(Items, Root)
    ->  (   sentence_node(Root, _) -> true
        ;   label_of(Root, RL), format(string(RM), "The tree of `~w` could not be written as RUML.", [RL]), add_problem(none, RM)
        ),
        findall(S, ( member(scenario(SN, Ls, _), Items), scenario_context(SN, Ls, S) ), Examples0),
        max_examples(MaxE), ( length(Examples0, NE), NE > MaxE -> length(Examples, MaxE), append(Examples, _, Examples0) ; Examples = Examples0 ),
        assemble(Doc, Examples)
    ;   add_problem(none, "The program has no sentence about one thing that rules conclude, to be the root of a RUML tree."),
        Doc = none
    ),
    findall(problem(W, M), problem(W, M), Problems0), list_to_set(Problems0, Problems).

max_examples(12).

add_problem(W, M) :- ( problem(W, M) -> true ; assertz(problem(W, M)) ).

constraints(KB) :-
    catch(le_import:kb_constraint_problems(KB, "RUML", Ps), _, Ps = []),
    forall(member(problem(W, M), Ps), add_problem(W, M)).

%   `*a case*`, `*an amount*` and `*case*` are the same place.
norm_template(T0, T) :-
    atom_string(T0, S0),
    re_replace("\\*an? "/g, "*", S0, S1), atom_string(T, S1).

template_additions(KB, F, A, Adds) :-
    functor(G, F, A),
    findall(judged, catch(KB:le_judged(G), _, fail), J),
    findall(assumable, catch(KB:le_unknown(G), _, fail), U),
    append(J, U, Adds0), sort(Adds0, Adds).

template_arity(Tx, A) :-
    atomic_list_concat(Parts, '*', Tx), length(Parts, L), A is (L - 1) // 2.

%   The twin's original: `the text of the_rulemap is at "sources/x.ruml"`.
load_original(Items, Options) :-
    (   member(fact(le_text_at(the_rulemap, Rel), _), Items), option(base(Base), Options),
        atomic_list_concat([Base, '/', Rel], F), exists_file(F),
        ruml_read_file(F, D, _), D \== none
    ->  assertz(original(D))
    ;   true
    ).

%   The root: the first query whose goal is one sentence about one thing
%   (or about nothing); else the first sentence that rules conclude and
%   no rule uses.
root_sentence(Items, F) :-
    member(query(_, G0), Items), strip(G0, G), sentence_goal(G, F), !.
root_sentence(_, F) :-
    rule_(H, _, _), functor(H, F, A), A =< 1, node_like(F),
    \+ ( rule_(_, B, _), sub_term(T, B), compound(T), functor(T, F, _) ), !.

sentence_goal(G, F) :- callable(G), functor(G, F, A), A =< 1, node_like(F).

%   A sentence about one thing or nothing that is not one of the twin's
%   own forms.
node_like(F) :- tmpl(F, A, Tx, _), A =< 1, \+ twin_form(Tx, _).

twin_form(Tx, would) :- sub_atom(Tx, _, _, _, ' would hold for *case*').
twin_form(Tx, decided) :- sub_atom(Tx, _, _, _, ' is decided for *case*').
twin_form(Tx, answer) :- sub_atom(Tx, 0, _, _, 'the answer to '), sub_atom(Tx, _, _, 0, ' for *case* is *truth value*').
%   A sentence the LE writer makes up to write a group of conditions
%   (le_writer: hoist_blocks): `condition 1 of <head> ...`. Its rule is
%   read in place of the sentence.
twin_form(Tx, auxiliary) :- sub_atom(Tx, 0, _, _, 'condition '), sub_atom(Tx, _, _, _, ' of ').
twin_form(Tx, count) :- sub_atom(Tx, 0, _, _, 'child *number* of '), sub_atom(Tx, _, _, 0, ' counts for *case*').

form_of(G, Form) :- callable(G), functor(G, F, _), tmpl(F, _, Tx, _), twin_form(Tx, Form).

		 /*******************************
		 *            NODES             *
		 *******************************/

new_lex(L) :- retract(counter(N)), N1 is N + 1, assertz(counter(N1)), atom_number(L, N).

%   sentence_node(+Functor, -LexId): the node of a sentence, made once.
sentence_node(F, L) :-
    (   key_lex(s(F), L) -> bump(L)
    ;   new_lex(L), assertz(key_lex(s(F), L)),
        label_of(F, Label),
        findall(B-P, ( rule_(H, B, P), functor(H, F, _), \+ twin_rule(B) ), Rules),
        tmpl(F, _, Tx, Adds),
        rules_text(F, Desc),
        (   Rules == [], original_untranslated(F, ON)
        ->  from_original(ON, L, Label, Desc)
        ;   Rules == []
        ->  leaf_of_sentence(F, Tx, Adds, L, Label, Desc)
        ;   delegated_form(Rules)
        ->  delegated_node(F, L, Label, Rules, Desc)
        ;   recursion_check(F, Rules),
            parent_of_rules(F, L, Label, Rules, Desc)
        )
    ).

%   A node of the original with this label is its own child (§6.4): the
%   twin wrote the round as an assumption; the way back restores it.
original_recursive(Label) :-
    original_by_words(Label, N), original(D), nodes(D, Ns), member(K-N, Ns),
    j(N, children, Cs), atom_string(K, KS), memberchk(KS, Cs), !.

%   The node of the original whose label gives these words (the twin's
%   template words come from the label, ruml_names:label_text/2).
original_by_words(Words, N) :-
    original(D), atom_string(Words, WS), nodes(D, Ns), member(_-N, Ns), j(N, label, OL),
    label_text(OL, T), atom_string(T, WS), !.

bump(L) :- ( retract(uses(L, N)) -> N1 is N + 1 ; N1 = 2 ), assertz(uses(L, N1)).

%   The twin's DELEGATED node: its rules ask that the node be `decided`.
%   All of them are one expression (an `or` of the rules), over the
%   children that the twin's `decided` rule names.
delegated_form(Rules) :- member(B-_, Rules), sub_term(G, B), compound(G), form_of(G, decided), !.

delegated_node(F, L, Label, Rules, Desc) :-
    (   member(B-_, Rules), strip(B, SB0), unfold(SB0, SB), sub_term(agg(count, _, G, _), SB), compound(G), form_of(G, count), G =.. [CF|_]
    ->  count_children(CF, Kids, Filter), b_setval(ruml_count_filter, CF-Filter)
    ;   decided_children(F, Kids)
    ),
    nb_setval(ruml_delegated, true),
    findall(E, ( member(B-P, Rules), strip(B, SB0), unfold(SB0, SB), conjuncts(SB, Cs0),
                 exclude([C]>>form_of(C, decided), Cs0, Cs1), query_expression(Cs1, P, E) ), Es),
    nb_setval(ruml_delegated, false),
    (   Es = [Expr] -> true ; maplist([E1, E2]>>format(string(E2), "(~w)", [E1]), Es, Ps), atomic_list_concat(Ps, ' or ', EA), atom_string(EA, Expr) ),
    format(string(D), "Written from the Logical English rules of ~w: ~w", [Label, Expr]),
    assertz(caps_used('ruml:expression')),
    finish_parent(L, Label, 'DELEGATED', Kids, [json([id="ruml:expression", payload=json([description=D, expression=Expr])])], Desc).

%   The children of a twin's DELEGATED node without a count: those whose
%   `decided` its own `decided` rule asks for, in order.
decided_children(F, Kids) :-
    label_of(F, Label), format(atom(DT), '~w is decided for *case*', [Label]),
    tmpl(DF, _, DT, _),
    (   rule_(H, B, _), functor(H, DF, _), strip(B, SB), conjuncts(SB, Cs), Cs = [_|_],
        forall(member(C, Cs), form_of(C, decided))
    ->  findall(K, ( member(C, Cs), functor(C, CDF, _), tmpl(CDF, _, CT, _),
                     sub_atom(CT, Bf, _, 0, ' is decided for *case*'), sub_atom(CT, 0, Bf, _, CL),
                     format(atom(HT), '~w holds for *case*', [CL]), tmpl(HF, _, HT, _), sentence_node(HF, K) ), Kids)
    ;   Kids = []
    ).

%   A rule that is one of the twin's forms for RUML's `undefined`: its
%   conditions ask for an assumption, or it concludes `decided`.
twin_rule(B) :- sub_term(G, B), compound(G), form_of(G, would), !.

label_of(F, Label) :-
    tmpl(F, _, Tx, _),
    (   sub_atom(Tx, B, _, 0, ' holds for *case*') -> sub_atom(Tx, 0, B, _, Label0)
    ;   atomic_list_concat(Ps, '*', Tx), findall(P, ( nth0(I, Ps, P0), ( I mod 2 =:= 0 -> P = P0 ; P = P0 ) ), Ps2),
        atomic_list_concat(Ps2, ' ', L0), normalize_space(atom(Label0), L0)
    ),
    ( Label0 == '' -> Label = F ; Label = Label0 ).

%   A sentence no rule concludes. A sentence that only scenarios state is a
%   yes-or-no data point; a judged or assumable one a leaf a person decides.
leaf_of_sentence(F, _, Adds, L, Label, Desc) :-
    \+ memberchk(judged, Adds), \+ memberchk(assumable, Adds),
    tmpl(F, 1, _, _), !,
    datapoint(F, boolean, Id),
    format(string(E), "~w = true", [Id]),
    add_node(L, [label=Label, capabilities=[json([id="ruml:query", payload=json([expression=E])])]], Desc),
    assertz(caps_used('ruml:query')).
leaf_of_sentence(_, _, _, L, Label, Desc) :-
    add_node(L, [label=Label], Desc).

parent_of_rules(F, L, Label, [B-P], Desc) :- !,
    body_children(F, B, P, Kids, Op0, Caps),
    (   Op0 = leaf([json([id=QI, payload=json([expression=E0])])]), open_guard(F, P, G)
    ->  format(string(E), "~w ? (~w)", [G, E0]), Op = leaf([json([id=QI, payload=json([expression=E])])])
    ;   Op = Op0
    ),
    finish_parent(L, Label, Op, Kids, Caps, Desc).

parent_of_rules(F, L, Label, Rules, Desc) :-
    findall(K, ( nth1(I, Rules, B-P), rule_child(F, Label, I, B, P, K) ), Kids),
    finish_parent(L, Label, 'OR', Kids, [], Desc).

%   A twin's leaf whose expression has no result in more places than a
%   comparison of a missing value (a `$lookup` of an unlisted key, a
%   `$not`): its `would hold` rule says where, and the written expression
%   gives no result there, as the original did.
open_guard(F, P, G) :-
    rule_(H, B0, _), functor(H, F, _), twin_rule(B0),
    strip(B0, B), conjuncts(B, Cs0),
    exclude([C]>>( form_of(C, would) ; C = not(D), form_of(D, decided) ), Cs0, Cs),
    Cs \== [],
    \+ only_missing(Cs),
    query_expression(Cs, P, U),
    format(string(G), "$not(~w)", [U]).

only_missing(Cs) :- forall(member(C, Cs), ( C = not(D), value_literal(D, _, _, V), var(V) )).

%   One rule of several: its one child, when its body is one sentence;
%   else a node of its own, `<label> (rule i)`.
rule_child(F, Label, I, B, P, K) :-
    body_children(F, B, P, Kids, Op, Caps),
    (   Op == 'AND', Kids = [K], Caps == [] -> true
    ;   new_lex(K), format(atom(L2), '~w (rule ~d)', [Label, I]),
        finish_parent(K, L2, Op, Kids, Caps, "")
    ).

finish_parent(L, Label, leaf([]), [], _, Desc) :- !,
    add_node(L, [label=Label], Desc).
finish_parent(L, Label, leaf(Caps), [], _, Desc) :- !,
    add_node(L, [label=Label, capabilities=Caps], Desc).
finish_parent(L, Label, Op, Kids0, Caps, Desc) :-
    Kids0 \== [], !,
    (   original_recursive(Label) -> append(Kids0, [L], Kids), bump(L), bump(L) ; Kids = Kids0 ),
    assertz(children_of(L, Kids)),
    ( Caps == [] -> Extra = [] ; Extra = [capabilities=Caps] ),
    atom_string(Op, OpS),
    append([label=Label, operator=OpS], Extra, Fs),
    add_node(L, Fs, Desc).
finish_parent(L, Label, _, [], _, Desc) :-
    add_node(L, [label=Label], Desc).

%   body_children(+Head, +Body, +Pos, -Children, -Operator, -Capabilities)
%   Operator: AND, OR, DELEGATED, NOT_AND, NOT_OR, or leaf(Caps) when the
%   whole body is conditions on values.
body_children(F, B0, P, Kids, Op, Caps) :-
    strip(B0, B), conjuncts(B, Cs0),
    exclude([C]>>form_of(C, decided), Cs0, Cs1),
    foldl(expand_auxiliary, Cs1, [], Cs2), reverse(Cs2, Cs),
    (   Cs = [G], form_of(G, answer)
    ->  Kids = [], Op = leaf([]), Caps = []
    ;   Cs = [not(G)], sentence_goal(G, GF)
    ->  negation_of(GF, P, Kids, Op), Caps = []
    ;   Cs = [not(G)], strip(G, SG), conjuncts(SG, NCs), NCs = [_, _|_], forall(member(X, NCs), sentence_goal(X, _))
    ->  findall(K, ( member(X, NCs), sentence_goal(X, XF), sentence_node(XF, K) ), Kids), Op = 'NOT_AND', Caps = []
    ;   member(agg(count, J, G, _), Cs), form_of(G, count), G =.. [CF, J0, _], J0 == J
    ->  count_children(CF, Kids, Filter), b_setval(ruml_count_filter, CF-Filter),
        query_expression(Cs, P, Expr),
        format(string(Desc), "Written from the Logical English rule of ~w: ~w", [F, Expr]),
        Op = 'DELEGATED', Caps = [json([id="ruml:expression", payload=json([description=Desc, expression=Expr])])],
        assertz(caps_used('ruml:expression'))
    ;   partition(is_sentence, Cs, Sents, Others),
        (   Sents == [], Others \== []
        ->  query_caps(Others, P, Caps0), Op = leaf(Caps0), Kids = [], Caps = []
        ;   maplist(child_of_condition(P), Sents, Kids0),
            (   Others == [] -> Kids = Kids0
            ;   query_caps(Others, P, QC), new_lex(QL),
                expression_label(QC, QLabel),
                add_node(QL, [label=QLabel, capabilities=QC], ""),
                append(Kids0, [QL], Kids)
            ),
            Op = 'AND', Caps = []
        )
    ).

is_sentence(G) :- sentence_goal(G, _), !.
is_sentence(not(G)) :- sentence_goal(G, _), !.
is_sentence(or(_, _)) :- !.

child_of_condition(_, G, K) :- sentence_goal(G, F), !, sentence_node(F, K).
child_of_condition(P, not(G), K) :- !,
    sentence_goal(G, F), negation_node(F, P, K).
child_of_condition(P, or(A, B), K) :-
    new_lex(K), disjuncts(or(A, B), Ds),
    findall(C, ( member(D, Ds), conjuncts(D, Cs), ( Cs = [C1], is_sentence(C1) -> child_of_condition(P, C1, C)
                                                   ; body_children(none, D, P, Ks, Op, Caps), new_lex(C), finish_parent(C, "alternative", Op, Ks, Caps, "") ) ), Kids),
    finish_parent(K, "one of", 'OR', Kids, [], "").

%   `it is not the case that S`: NOT_AND (NOT_OR) over the children of S
%   when S is the twin's second sentence for a NOT_ node, else a NOT_AND
%   over S's own node.
negation_of(GF, P, Kids, Op) :-
    tmpl(GF, _, Tx, _),
    (   ( sub_atom(Tx, 0, _, _, 'the conditions of ') -> Op0 = 'NOT_AND' ; sub_atom(Tx, 0, _, _, 'one of the conditions of ') -> Op0 = 'NOT_OR' )
    ->  findall(B-Pp, ( rule_(H, B, Pp), functor(H, GF, _) ), Rules),
        (   Op0 == 'NOT_AND', Rules = [B1-P1] -> body_children(GF, B1, P1, Kids, _, _)
        ;   findall(K, ( nth1(I, Rules, Bb-Pp2), alternative_child(GF, I, Bb, Pp2, K) ), Kids)
        ),
        Op = Op0, ignore(P = _)
    ;   sentence_node(GF, K), Kids = [K], Op = 'NOT_AND'
    ).

alternative_child(GF, I, B, P, K) :-
    strip(B, Sb), conjuncts(Sb, Cs),
    (   Cs = [G1], sentence_goal(G1, F1) -> sentence_node(F1, K)
    ;   rule_child(GF, "alternative", I, B, P, K)
    ).

negation_node(F, P, K) :-
    new_lex(K), label_of(F, L0), format(atom(Label), 'not: ~w', [L0]),
    negation_of(F, P, Kids, Op),
    finish_parent(K, Label, Op, Kids, [], "").

%   The twin's DELEGATED: `decided` (dropped above) and a count over `child
%   N of X counts for`: the children are those the count's rules name, the
%   filter on $children says which status each must have.
count_children(CF, Kids, Filter) :-
    findall(I-Cond, ( rule_(H, B, _), H =.. [CF, I, _], strip(B, Cond) ), ICs),
    msort(ICs, Sorted),
    findall(K-Sense, ( member(_-Cond, Sorted), child_sense(Cond, F, Sense), sentence_node(F, K) ), KS),
    pairs_keys(KS, Kids),
    (   forall(member(_-S, KS), S == true) -> Filter = "status = 'true'"
    ;   findall(Fi, ( member(K-S, KS), ( S == true -> St = "true" ; St = "false" ), format(string(Fi), "(lexId = '~w' and status = '~w')", [K, St]) ), Fis),
        atomic_list_concat(Fis, ' or ', Filter)
    ).

child_sense(not(G), F, false) :- !, sentence_goal(G, F).
child_sense(G, F, true) :- sentence_goal(G, F).

expression_label([json([id=_, payload=json([expression=E])])|_], L) :- !, format(atom(L), '~w', [E]).
expression_label(_, 'conditions').

recursion_check(F, Rules) :-
    forall(( member(B-P, Rules), sub_term(G, B), callable(G), functor(G, F, _) ),
           ( label_of(F, L), format(string(M), "~w uses itself: RUML has no rules that use themselves (only a modular node that is its own child).", [L]),
             add_problem(P, M) )).

		 /*******************************
		 *     CONDITIONS → JSONATA     *
		 *******************************/

%   The conditions on values of one rule: one ruml:query expression. A
%   value template's literal names a data point and binds its value; a
%   comparison, an assignment or a missing-value test reads them.
query_caps(Conds, P, [json([id="ruml:query", payload=json([expression=E])])]) :-
    assertz(caps_used('ruml:query')),
    query_expression(Conds, P, E).

query_expression(Conds, P, E) :-
    foldl(cond_js(P), Conds, []-[], Env-Parts),
    ignore(Env = _),
    exclude(==(""), Parts, Ps1),
    (   Ps1 == [] -> E = "true"
    ;   reverse(Ps1, Ps), atomic_list_concat(Ps, ' and ', E0), atom_string(E0, E)
    ).

cond_js(P, C, Env0-Ps0, Env-Ps) :-
    (   C = agg(count, _, G, V), form_of(G, count)
    ->  G =.. [CF|_], b_getval(ruml_count_filter, CF-Filter),
        format(atom(X), '$count($children[~w])', [Filter]), Env = [V-X|Env0], Ps = Ps0
    ;   value_literal(C, F, Subject, V)
    ->  value_dp(F, Id), ignore(Subject = _),
        (   var(V) -> Env = [V-Id|Env0], Ps = Ps0
        ;   js_constant(V, VJ), format(string(S), "~w = ~w", [Id, VJ]), Env = Env0, Ps = [S|Ps0]
        )
    ;   C = not(G), value_literal(G, F, _, V), var(V)
    ->  value_dp(F, Id), format(string(S), "$not($exists(~w))", [Id]), Env = Env0, Ps = [S|Ps0]
    ;   comparison(C, X, Op, Y)
    ->  js_term(X, Env0, XJ, P), js_term(Y, Env0, YJ, P), js_op(Op, JOp),
        format(string(S), "~w ~w ~w", [XJ, JOp, YJ]), Env = Env0, Ps = [S|Ps0]
    ;   assignment(C, V, Expr)
    ->  js_term(Expr, Env0, EJ, P), format(atom(Id), '(~w)', [EJ]), Env = [V-Id|Env0], Ps = Ps0
    ;   C = or(_, _)
    ->  disjuncts(C, Ds),
        findall(S1, ( member(D, Ds), conjuncts(D, DCs), foldl(cond_js(P), DCs, Env0-[], _-DPs), reverse(DPs, DPs1),
                      atomic_list_concat(DPs1, ' and ', S0), format(string(S1), "(~w)", [S0]) ), Ss),
        atomic_list_concat(Ss, ' or ', SA), atom_string(SA, S), Env = Env0, Ps = [S|Ps0]
    ;   C = not(G)
    ->  foldl(cond_js(P), [G], Env0-[], _-GPs), Env = Env0,
        ( GPs = [GS] -> format(string(S), "$not(~w)", [GS]), Ps = [S|Ps0] ; Ps = Ps0 )
    ;   sentence_goal_any(C, AF), tmpl(AF, _, ATx, _), twin_form(ATx, auxiliary),
        findall(AB-AP, ( rule_(AH, AB, AP), functor(AH, AF, _) ), [AB0-AP0])
    ->  strip(AB0, SAB), conjuncts(SAB, ACs), query_expression(ACs, AP0, AE),
        format(string(S), "(~w)", [AE]), Env = Env0, Ps = [S|Ps0]
    ;   C = and(_, _)
    ->  conjuncts(C, ACs), foldl(cond_js(P), ACs, Env0-Ps0, Env-Ps)
    ;   nb_current(ruml_delegated, true), child_status_js(C, S)
    ->  Env = Env0, Ps = [S|Ps0]
    ;   condition_problem(C, P), Env = Env0, Ps = Ps0
    ).

%   In a DELEGATED node's expression, a child's sentence is its status.
child_status_js(not(G), S) :- !, sentence_goal(G, F), known_node(F, K),
    format(string(S), "$children[lexId = '~w'].status = 'false'", [K]).
child_status_js(G, S) :- sentence_goal(G, F), known_node(F, K),
    format(string(S), "$children[lexId = '~w'].status = 'true'", [K]).

condition_problem(C, P) :-
    (   C = agg(_, _, _, _) -> M = "An aggregate (a sum, a count, a minimum ...) over things: RUML's expressions read the values of one case, not a set of things that rules find."
    ;   callable(C), functor(C, F, A), tmpl(F, A, Tx, _)
    ->  format(string(M), "The sentence `~w` is about more than one thing, or relates two things: a RUML node is about one case.", [Tx])
    ;   callable(C), functor(C, F, A), A > 0, \+ tmpl(F, A, _, _), \+ comparison(C, _, _, _)
    ->  format(string(M), "A condition that RUML's expressions cannot say: ~w", [F])
    ;   C = not(_) -> M = "A negation of conditions that RUML's expressions cannot say."
    ;   M = "A condition that RUML's expressions cannot say." 
    ),
    add_problem(P, M).

%   `the X of *a case* is *a Y*`: a value of the case.
value_literal(G, F, S, V) :- callable(G), G =.. [F, S, V], tmpl(F, 2, Tx, _), value_template(Tx).
value_template(Tx) :- sub_atom(Tx, _, _, _, ' of *'), sub_atom(Tx, _, _, _, ' is *').

value_dp(F, Id) :-
    (   dp(F, Id, _, _) -> true
    ;   tmpl(F, _, Tx, Adds), place_type(Tx, Type),
        datapoint(F, Type, Id),
        (   memberchk(undefined, Adds) -> true
        ;   memberchk(scenario_element, Adds) -> true
        ;   computed(F, Id)
        )
    ).

%   The noun of the last place of a template: the type of its value.
place_type(Tx, Type) :-
    atomic_list_concat(Ps, '*', Tx), length(Ps, N), N >= 3, I is N - 1, nth1(I, Ps, Last), !,
    place_type_(Last, Type).
place_type(_, string).
place_type_(P, T) :-
    (   sub_atom(P, _, _, 0, number) -> T = number
    ;   sub_atom(P, _, _, 0, amount) -> T = number
    ;   sub_atom(P, _, _, 0, 'truth value') -> T = boolean
    ;   sub_atom(P, _, _, 0, value), sub_atom(P, _, _, _, truth) -> T = boolean
    ;   sub_atom(P, _, _, 0, date) -> T = date
    ;   T = string
    ).

%   A value that rules calculate: a computed data point, when its one rule
%   is arithmetic on other values; else a problem.
computed(F, Id) :-
    (   findall(B-P, ( rule_(H, B, P), functor(H, F, 2) ), [B0-P]),
        rule_(H, B0, P), H =.. [F, _, V], strip(B0, B), conjuncts(B, Cs),
        foldl(cond_js(P), Cs, []-[], Env-_), memberchk(V-Ex, Env)
    ->  retract(dp(F, Id, N, T)), assertz(dp(F, Id, N, computed(T, Ex)))
    ;   findall(P, ( rule_(H, _, P), functor(H, F, 2) ), [P1|_])
    ->  tmpl(F, _, Tx, _), format(string(M), "The value `~w` is calculated by rules that are not one formula: RUML's computed data point is one JSONata expression.", [Tx]),
        add_problem(P1, M)
    ;   true
    ).

%   The name of a value: the words before ` of *a case*`, without `the`.
dp_label(F, Name) :-
    tmpl(F, _, Tx, _),
    (   sub_atom(Tx, B, _, _, ' of *') -> sub_atom(Tx, 0, B, _, N0)
    ;   label_of(F, N0)
    ),
    dp_words(N0, Name).

datapoint(F, Type, Id) :-
    (   dp(F, Id, _, _) -> true
    ;   dp_label(F, Name),
        original_dp(Name, Id0) -> assertz(dp(F, Id0, Name, Type)), Id = Id0
    ;   dp_label(F, Name), dp_id(Name, Id1), unique_dp_id(Id1, Id), assertz(dp(F, Id, Name, Type))
    ).

%   The words of a data point: without `the`, and without the case a
%   yes-or-no sentence is about (`case is resident`: `resident`).
dp_words(L0, L) :-
    atom_string(L0, S),
    (   string_concat("the ", R, S) -> true
    ;   string_concat("case is ", R, S) -> true
    ;   string_concat("case has ", R0, S) -> string_concat("has ", R0, R)
    ;   string_concat("case ", R, S) -> true
    ;   R = S
    ),
    atom_string(L, R).

unique_dp_id(Id0, Id) :- ( dp(_, Id0, _, _) -> atom_concat(Id0, '_2', Id1), unique_dp_id(Id1, Id) ; Id = Id0 ).

%   A data point of the original whose words are these: its id is kept.
original_dp(Name, Id) :-
    original(D), capabilities(D, Cs), member(C, Cs), j(C, id, "ruml:datapoints"), j(C, payload, P), j(P, data, json(DPs)),
    member(Id=DP, DPs), j(DP, name, N0, ""), datapoint_words(Id, N0, Ws), atomic_list_concat(Ws, ' ', Name), !.

dp_id(Name, Id) :-
    atom_codes(Name, Cs0), maplist(ascii_code, Cs0, Css), append(Css, Cs1),
    maplist([C0, C]>>( code_type(C0, alnum) -> code_type(C, to_lower(C0)) ; C = 0'_ ), Cs1, Cs2),
    collapse(Cs2, Cs3), atom_codes(A, Cs3), ( sub_atom(A, 0, 1, _, D), atom_number(D, _) -> atom_concat('dp_', A, Id) ; atom_concat('dp_', A, Id) ).

ascii_code(0'ä, `ae`) :- !.
ascii_code(0'ö, `oe`) :- !.
ascii_code(0'ü, `ue`) :- !.
ascii_code(0'Ä, `ae`) :- !.
ascii_code(0'Ö, `oe`) :- !.
ascii_code(0'Ü, `ue`) :- !.
ascii_code(0'ß, `ss`) :- !.
ascii_code(C, [C]) :- C < 128, !.
ascii_code(_, `_`).

collapse([], []).
collapse([0'_, 0'_|Cs], Ds) :- !, collapse([0'_|Cs], Ds).
collapse([C|Cs], [C|Ds]) :- collapse(Cs, Ds).

comparison(G, X, Op, Y) :- callable(G), G =.. [F, X, Y], memberchk(F-Op, [le_equal_to-(=), le_not_equal_to-(\=), le_gt-(>), le_ge-(>=), le_lt-(<), le_le-(=<), (>)-(>), (>=)-(>=), (<)-(<), (=<)-(=<), (=)-(=), (\=)-(\=), (=:=)-(=), (=\=)-(\=)]).
assignment(G, V, E) :- callable(G), ( G = le_assign(V, E) ; G = (V is E) ), var(V).

js_op('=<', '<=') :- !.
js_op('\\=', '!=') :- !.
js_op(O, O).

js_term(X, Env, J, _) :- var(X), !, ( member(V-I, Env), V == X -> J = I ; J = '$unknown' ).
js_term(X, _, J, _) :- ( number(X) ; string(X) ; atom(X) ; X = date(_, _, _) ), !, js_constant(X, J).
js_term(E, Env, J, P) :- compound(E), E =.. [Op, A, B], memberchk(Op-JO, [(+)-(+), (-)-(-), (*)-(*), (/)-(/), mod-'%']), !,
    js_term(A, Env, AJ, P), js_term(B, Env, BJ, P), format(atom(J), '(~w ~w ~w)', [AJ, JO, BJ]).
js_term(E, Env, J, P) :- compound(E), E =.. [F, A], memberchk(F-JF, [abs-abs, floor-floor, ceiling-ceil, round-round, sqrt-sqrt, (-)-neg]), !,
    js_term(A, Env, AJ, P), ( JF == neg -> format(atom(J), '-~w', [AJ]) ; format(atom(J), '$~w(~w)', [JF, AJ]) ).
js_term(E, _, '$unknown', P) :- format(string(M), "A formula that RUML's expressions are not given: ~q", [E]), add_problem(P, M).

js_constant(X, J) :- number(X), !, format(atom(J), '~w', [X]).
js_constant(true, true) :- !.
js_constant(false, false) :- !.
js_constant(date(Y, M, D), J) :- !, format(atom(J), '"~d-~|~`0t~d~2+-~|~`0t~d~2+"', [Y, M, D]).
js_constant(X, J) :- format(string(S), "~w", [X]), with_output_to(atom(J), json_write(current_output, S)).

		 /*******************************
		 *        THE DOCUMENT          *
		 *******************************/

add_node(L, Fields0, Desc) :-
    node_id(L, Fields0, Id),
    (   selectchk(label=Lb, Fields0, Rest), original_by_words(Lb, ON), j(ON, label, OL) -> Fields = [label=OL|Rest] ; Fields = Fields0 ),
    ( Desc == "" -> Fs = Fields ; append(Fields, [description=Desc], Fs) ),
    assertz(xnode(L, Id, Fs)).

%   A node's identifier: the original's (a node of the same label), or one
%   computed from the program's name and the node's label, so that the next
%   export gives it again.
node_id(_, Fields, Id) :-
    memberchk(label=Label, Fields), original_by_words(Label, N), j(N, id, Id0), !, Id = Id0.
node_id(L, Fields, Id) :-
    program_name(P), memberchk(label=Label, Fields),
    format(string(S), "~w/~w/~w", [P, L, Label]), uuid_of(S, Id).

uuid_of(S, Id) :-
    sha_hash(S, H, [algorithm(sha256)]), hash_atom(H, Hex),
    sub_atom(Hex, 0, 8, _, A), sub_atom(Hex, 8, 4, _, B), sub_atom(Hex, 13, 3, _, C0),
    sub_atom(Hex, 16, 1, _, V0), sub_atom(Hex, 17, 3, _, D0), sub_atom(Hex, 20, 12, _, E),
    atom_codes(V0, [VC]), char_type(VC, xdigit(VW)), VW2 is 8 + (VW mod 4), format(atom(V), '~16r', [VW2]),
    format(string(Id), "~w-~w-4~w-~w~w-~w", [A, B, C0, V, D0, E]).

%   The rules that conclude a sentence, as the program writes them.
rules_text(F, Desc) :-
    (   doc_text(T)
    ->  findall(S, ( rule_(H, B, P), functor(H, F, _), \+ twin_rule(B), P = at(St, _), paragraph(T, St, S) ), Ss0),
        list_to_set(Ss0, Ss),
        (   Ss == [] -> Desc = ""
        ;   atomic_list_concat(Ss, "\n\n", R), format(string(Desc0), "In Logical English:\n~w", [R]),
            ( string_length(Desc0, L), L > 9900 -> sub_string(Desc0, 0, 9900, _, Desc) ; Desc = Desc0 )
        )
    ;   Desc = ""
    ).

%   The paragraph (between blank lines) of the program's text at a position.
paragraph(T, Pos, S) :-
    sub_string(T, 0, Pos, _, Before), sub_string(T, Pos, _, 0, After),
    (   sub_string(Before, B, _, _, "\n\n"), \+ ( sub_string(Before, B2, _, _, "\n\n"), B2 > B ) -> Start is B + 2 ; Start = 0 ),
    (   sub_string(After, A, _, _, "\n\n") -> End is Pos + A ; string_length(T, End) ),
    Len is End - Start, sub_string(T, Start, Len, _, S0), normalize_space(string(S1), S0), S1 \== "",
    sub_string(T, Start, Len, _, S2), split_string(S2, "", "\n ", [S]).

first_position(B, P) :- ( sub_term(le_at(_, S, E), B), integer(S) -> P = at(S, E) ; P = none ).

%   A scenario: an example of the rulemap (`ruml:context`, category
%   `example`), with the values of its case and its text.
scenario_context(Name, Lines, Key=json([title=Title, category="example", timestamp=Ts, content=json(Content)])) :-
    format(atom(K0), 'ctx_scenario_~w', [Name]), dp_id_key(K0, Key),          % `[a-z_][a-z0-9_]*`
    format(string(Title), "Scenario ~w of the Logical English program", [Name]),
    get_time(Now), format_time(string(Ts), "%FT%T%:z", Now),
    findall(Id=V, ( member(L0, Lines), scenario_fact(L0, G), value_literal(G, F, _, V0), dp(F, Id, _, _), json_value(V0, V) ), Ins),
    findall(Id= @(true), ( member(L0, Lines), scenario_fact(L0, G), callable(G), functor(G, F, 1), dp(F, Id, _, boolean) ), Bs),
    append(Ins, Bs, All),
    Content = [inputs=json(All)].

scenario_fact(fact(G), G) :- !.
scenario_fact(fact(G, _), G) :- !.
scenario_fact(G, G) :- callable(G), \+ G = expects(_, _), \+ G = expects(_, _, _).

json_value(date(Y, M, D), S) :- !, format(string(S), "~d-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, D]).
json_value(true, @(true)) :- !.
json_value(false, @(false)) :- !.
json_value(V, V) :- ( number(V) ; string(V) ), !.
json_value(V, S) :- format(string(S), "~w", [V]).

assemble(Doc, Examples) :-
    lex_map(Map),
    findall(K-Fs, ( xnode(L, Id, Fs0), node_fields(L, Id, Fs0, Fs1), original_fields(Id, Fs1, Fs2),
                    renumber(Map, Fs2, Fs), memberchk(L-K, Map) ), Ns0),
    sort(1, @<, Ns0, Ns1), predsort([O, A-_, B-_]>>( atom_number(A, NA), atom_number(B, NB), compare(O, NA, NB) ), Ns1, Ns),
    findall(K=json(Fs), member(K-Fs, Ns), NodeObjs),
    metadata(Meta),
    findall(Id=DPJ, ( dp(_, Id, Name, T), ( original_dp_json(Id, T, DPJ) -> true ; dp_fields(Name, T, DPF), DPJ = json(DPF) ) ), DPs),
    Caps0 = [],
    ( DPs == [] -> Caps1 = Caps0 ; append(Caps0, [json([id="ruml:datapoints", payload=json([data=json(DPs)])])], Caps1) ),
    ( caps_used('ruml:query') -> append(Caps1, [json([id="ruml:query"])], Caps2) ; Caps2 = Caps1 ),
    ( caps_used('ruml:expression') -> append(Caps2, [json([id="ruml:expression", required= @(true)])], Caps3a) ; Caps3a = Caps2 ),
    findall(Decl, ( caps_used(Id0), atom_string(Id0, IdS), \+ memberchk(IdS, ["ruml:query", "ruml:expression"]),
                    \+ ( member(json(F), Caps3a), memberchk(id=IdS, F) ),
                    original(OD), capabilities(OD, OCs), member(Decl, OCs), j(Decl, id, IdS) ), Decls0),
    list_to_set(Decls0, Decls), append(Caps3a, Decls, Caps3),
    ( Examples == [] -> Caps = Caps3 ; append(Caps3, [json([id="ruml:context", payload=json([data=json(Examples)])])], Caps) ),
    ( Caps == [] -> Root = [] ; Root = [capabilities=Caps] ),
    append([['$format'="RUML", '$specVersion'="1.0"], Root, [metadata=Meta, rulemap=json([nodes=json(NodeObjs)])]], All),
    Doc = json(All).

node_fields(L, Id, Fs0, [id=Id|Fs]) :-
    (   children_of(L, Kids) -> ( uses_any(Kids) -> true ; true ), Fs1 = Fs0, append(Fs1, [children=Kids], Fs2) ; Fs2 = Fs0 ),
    (   uses(L, _) -> append(Fs2, [modular= @(true)], Fs3) ; Fs3 = Fs2 ),
    order_fields(Fs3, Fs).
uses_any(_).

%   id, label, operator, children, capabilities, description, modular.
order_fields(Fs0, Fs) :-
    findall(K=V, ( member(K, [label, operator, children, description, modular, capabilities]), memberchk(K=V, Fs0) ), Fs).

dp_fields(Name, computed(T, Ex), [name=NameS, type=TS, binding=json([type="computed", expression=ExS])]) :- !,
    atom_string(Name, NameS), atom_string(T, TS), atom_string(Ex, ExS).
dp_fields(Name, T, [name=NameS, type=TS, binding=json([type="input"])]) :- atom_string(Name, NameS), atom_string(T, TS).

%   The original's metadata (a twin), with `modified` now; else a draft.
metadata(json(Fs)) :-
    get_time(Now), format_time(string(Ts), "%FT%T%:z", Now),
    program_name(P),
    (   doc_text(T) -> format(string(C), "Written by Logical English from this program:\n\n~w", [T]) ; C = "Written by Logical English." ),
    (   original(D), j(D, metadata, json(M0))
    ->  findall(K=V, ( member(K=V, M0), K \== modified, K \== comment ), Kept),
        append(Kept, [modified=Ts, comment=C], Fs)
    ;   format(string(S), "~w/metadata", [P]), uuid_of(S, Id),
        atomic_list_concat(Ws, '_', P), atomic_list_concat(Ws, ' ', Title),
        Fs = [id=Id, version="1.0.0", created=Ts, modified=Ts, status="draft", title=Title, comment=C]
    ).

		 /*******************************
		 *            BODIES            *
		 *******************************/

strip(V, V) :- var(V), !.
strip(le_at(G, _, _), S) :- !, strip(G, S).
strip(and(A, B), and(SA, SB)) :- !, strip(A, SA), strip(B, SB).
strip(','(A, B), and(SA, SB)) :- !, strip(A, SA), strip(B, SB).
strip(or(A, B), or(SA, SB)) :- !, strip(A, SA), strip(B, SB).
strip(';'(A, B), or(SA, SB)) :- !, strip(A, SA), strip(B, SB).
strip(not(A), not(SA)) :- !, strip(A, SA).
strip(\+(A), not(SA)) :- !, strip(A, SA).
strip(T, agg(Op, E, G, R)) :- compound(T), T =.. [Op, [each, var(_, E)], G0, [var(_, R)]], memberchk(Op, [count, sum, min, max, average]), !, strip(G0, G).
strip(agg(Op, E, G0, R), agg(Op, E, G, R)) :- !, strip(G0, G).
strip(T, T).

conjuncts(and(A, B), Cs) :- !, conjuncts(A, CA), conjuncts(B, CB), append(CA, CB, Cs).
conjuncts(true, []) :- !.
conjuncts(G, [G]).
disjuncts(or(A, B), Ds) :- !, disjuncts(A, DA), disjuncts(B, DB), append(DA, DB, Ds).
disjuncts(G, [G]).

%   A sentence goal, a writer's auxiliary one included.
sentence_goal_any(G, F) :- callable(G), functor(G, F, A), A =< 1, tmpl(F, A, _, _).

%   A child already among the node's children: named, not referenced again.
known_node(F, K) :- ( key_lex(s(F), K0) -> K = K0 ; sentence_node(F, K) ).

%   The LE writer's auxiliary sentence (`condition 1 of ...`), with one
%   rule: its conditions in its place, wherever it is in a body.
expand_auxiliary(C, Acc, Out) :-
    unfold(C, C1), conjuncts(C1, Cs), reverse(Cs, RCs), append(RCs, Acc, Out).

unfold(V, V) :- var(V), !.
unfold(and(A, B), and(UA, UB)) :- !, unfold(A, UA), unfold(B, UB).
unfold(or(A, B), or(UA, UB)) :- !, unfold(A, UA), unfold(B, UB).
unfold(not(A), not(UA)) :- !, unfold(A, UA).
unfold(C, U) :-
    sentence_goal_any(C, F), tmpl(F, _, Tx, _), twin_form(Tx, auxiliary),
    findall(H-B, ( rule_(H, B, _), functor(H, F, _) ), [H0-B0]), !,
    copy_term(H0-B0, H1-B1), C = H1,
    strip(B1, SB), unfold(SB, U).
unfold(C, C).

%   The node of the original that has this identifier.
original_node(Id, Key, N) :- original(D), nodes(D, Ns), member(Key-N, Ns), j(N, id, Id), !.

%   The original's numbers for the nodes it has; new numbers after them.
lex_map(Map) :-
    findall(L-Id, xnode(L, Id, _), LIds),
    (   original(D) -> nodes(D, ONs), findall(N, ( member(K-_, ONs), atom_number(K, N) ), Ns0), max_list([0|Ns0], Max) ; Max = 0 ),
    Max1 is max(Max, 1),
    (   selectchk('1'-_, LIds, Rest) -> foldl(map_one, Rest, Max1-['1'-'1'], _-Map) ; foldl(map_one, LIds, Max-[], _-Map) ).
%   The root is node 1, whatever the original numbered it.
map_one(L-Id, M0-Acc, M-[L-K|Acc]) :-
    (   original_node(Id, K0, _), \+ memberchk(_-K0, Acc) -> K = K0, M = M0
    ;   M is M0 + 1, atom_number(K, M)
    ).

%   An OR the original wrote as XOR (the twin reads both as rules per
%   child), and a combiner with the original's own words when its
%   expression is the original's.
original_fields(Id, Fs0, Fs) :-
    (   original_node(Id, _, N)
    ->  (   memberchk(operator=O, Fs0), j(N, operator, OO), memberchk(O-OO, ["OR"-"XOR", "NOT_OR"-"NOT_XOR"])
        ->  selectchk(operator=O, Fs0, operator=OO, Fs1)
        ;   Fs1 = Fs0
        ),
        (   memberchk(capabilities=[json([id="ruml:expression", payload=json(P)])], Fs1),
            node_caps(N, Es), member(cap('ruml:expression', OP), Es), j(OP, expression, OE),
            memberchk(expression=E, P), same_expression(E, OE)
        ->  selectchk(capabilities=_, Fs1, capabilities=[json([id="ruml:expression", payload=OP])], Fs)
        ;   Fs = Fs1
        )
    ;   Fs = Fs0
    ).

same_expression(A, B) :-
    jsonata_parser:jsonata_parse(A, TA), jsonata_parser:jsonata_parse(B, TB),
    canonical_tree(TA, CA), canonical_tree(TB, CB), CA == CB.
canonical_tree(str(S), str(S)) :- !.
canonical_tree(T, T).

renumber(Map, Fs0, Fs) :-
    (   selectchk(children=Cs0, Fs0, children=Cs, Fs) -> maplist({Map}/[C0, C]>>memberchk(C0-C, Map), Cs0, Cs) ; Fs = Fs0 ).

%   The original's own definition of a data point (its type, unit,
%   validation), unless the program now calculates it.
original_dp_json(Id, T, DP) :-
    T \= computed(_, _),
    original(D), capabilities(D, Cs), member(C, Cs), j(C, id, "ruml:datapoints"), j(C, payload, P), j(P, data, Data), j(Data, Id, DP).

%   A sentence whose only rule is the twin's assumption (`would hold`): a
%   node the twin could not translate (residue: a `$random` combiner, an
%   include of another rulemap). The original's node is written back as it
%   was, its children through their own sentences.
original_untranslated(F, ON) :-
    label_of(F, Label), original_by_words(Label, ON),
    rule_(H, B, _), functor(H, F, _), twin_rule(B), !.

from_original(ON, L, Label, Desc) :-
    (   j(ON, children, Cs0), Cs0 \== []
    ->  original(D),
        findall(K, ( member(C0, Cs0), atom_string(C, C0), node(D, C, CN), j(CN, label, CL), ruml_names:label_text(CL, CT),
                     format(atom(HT), '~w holds for *case*', [CT]), tmpl(CF, _, HT, _), known_node(CF, K) ), Kids),
        assertz(children_of(L, Kids))
    ;   true
    ),
    findall(K=V, ( member(K, [operator, capabilities, decisionMode]), j(ON, K, V) ), Fs0),
    forall(( j(ON, capabilities, Es), member(E, Es), j(E, id, Id) ), assertz(caps_used(Id))),
    add_node(L, [label=Label|Fs0], Desc).

dp_id_key(A, K) :-
    atom_codes(A, Cs0), maplist(ascii_code, Cs0, Css), append(Css, Cs1),
    maplist([C0, C]>>( code_type(C0, alnum) -> code_type(C, to_lower(C0)) ; C = 0'_ ), Cs1, Cs2),
    collapse(Cs2, Cs3), atom_codes(K, Cs3).

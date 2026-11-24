/** <module> A DMN model → its Logical English twin (the migration term)

    The mapping of the design notes roadmap.md §5.2, generated:

    - An input, and a decision whose value is one value, is a **function**
      (language.md §2.4) of no place: `the risk category is *a text*`. A
      value used in a formula is then written as an operand
      (`N = the monthly salary * 12`), the form FEEL itself has.
    - A structure (an item definition with components) is a function per
      component: `the rate of the approval is *a text*`.
    - A decision whose value is a list (a COLLECT table without an
      aggregation, RULE ORDER, OUTPUT ORDER) is a relation with one answer
      per element: `the conclusie bijbehorend bouwwerk include *a text*`.
    - A decision table whose cells are values, comparisons and lists of
      them is an LE **decision table** (§17.3) with its hit policy;
      PRIORITY and OUTPUT ORDER are rows reordered by the priority of
      their outputs. Any other table is a rule per row (FIRST: an
      `otherwise` cascade).
    - A literal expression is a rule. FEEL's three values are kept: a
      boolean decision is `true` where its expression holds, `false` where
      it fails, and has no answer where FEEL gives null; a value that is
      null is a value no condition can read.
    - A business knowledge model is a function with places, invoked by
      its words.
    - FEEL's built-in functions are templates of the shared libraries
      (lib/text, lib/rounding, lib/temporal, lib/feel), each included as a
      resource.

    What is not translated is a residue block with the FEEL text, and the
    ledger says so.

        model_migration(+File, +Options, -Migration)
        Options: tests(Cases) (dmn_tests:tck_cases/3), document(Doc),
                 program(Name), collection(C)
*/

:- module(dmn_twin, [model_migration/3, model_symbols/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(pairs)).
:- use_module(dmn_reader).
:- use_module(feel_parser).
:- use_module(dmn_names).

:- dynamic sym/2.           % FEEL name -> symbol
:- dynamic out/1.           % IR items, in order
:- dynamic ledger/1.        % ledger entries
:- dynamic lib_used/1.      % a library the program includes
:- dynamic typedef/3.       % namespace, item definition name -> Def
:- dynamic loaded/2.        % namespace -> model (the model and those it imports)
:- dynamic loaded_file/2.   % namespace -> file
:- dynamic inlined_use/2.   % decision or service name, what of an imported model its rules copy
:- dynamic import_prefix/3. % namespace, prefix -> namespace imported
:- dynamic struct_comp/3.   % Root, Path, Functor
:- dynamic fixed_sym/1.     % an input whose value the model gives

		 /*******************************
		 *          THE MODEL           *
		 *******************************/

model_migration(File, Options, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    reset,
    dmn_read_file(File, Model),
    dmn_info(Model, name, MName),
    dmn_info(Model, namespace, RootNS),
    b_setval(dmn_scope, RootNS), b_setval(dmn_root, RootNS),
    load_imports(File, Model),
    option(program(Program), Options, MName),
    option(document(Doc), Options, 'the DMN model'),
    declare_types(Model),
    declare_inputs(Model),
    declare_bkms(Model),
    declare_decisions(Model),
    declare_implicit(Model),
    bkms_of(Model, Bkms), forall(member(B, Bkms), translate_bkm(Model, B)),
    decisions_in_order(Model, Ds),
    forall(member(D, Ds), translate_decision(Model, D)),
    option(tests(Cases), Options, []),
    findall(T, ( member(C, Cases), case_test(Doc, C, T) ), Tests),
    findall(Q, ( member(test(_, _, _, _, Es), Tests), member(expects(Q, _), Es) ), QNs0), sort(QNs0, QNs),
    findall(Q, ( member(QN, QNs), test_query(QN, Q) ), Qs0),
    question_view(Model, Qs0, Qs),
    findall(I, out(I), Body0), maplist(block_item, Body0, Body),
    append(Body, Qs, Items),
    findall(E, ledger(E), Ledger),
    findall(L, lib_used(L), Libs0), sort(Libs0, Libs),
    name_functor(kb, Program, KB0), atom_concat(kb_, KB, KB0),
    file_base_name(File, Base),
    format(string(C1), "The Logical English twin of the DMN model \"~w\" (~w), written by the DMN translator.", [MName, Base]),
    Header0 = [kb(KB), comment(C1)],
    ( Libs == [] -> Header = Header0 ; Header = [includes(Libs)|Header0] ),
    Meta = [source('DMN'), artifacts([Base]), translator(dmn_twin), program(Program)].

%!  question_view(+Model, +Queries0, -Queries) is det.
%
%   A model whose inputs are questions to a citizen (the bruidsschat's: STTR
%   gives each input its vraagTekst) has a view that asks them one at a
%   time, as the Omgevingsloket does, its result the model's conclusion. The
%   conclusion's query is added when no test asks it.
question_view(model(I, Items), Qs0, Qs) :-
    findall(Ws-Q, question_of(Ws, Q), WQs), WQs \== [], !,
    memberchk(name(MName), I),
    findall(S, ( member(Ws-Q0, WQs), atomic_list_concat(Ws, ' ', W),
                 sym(_, val(F, Noun)), functor_words(F, Ws),
                 place_phrase(Noun, P), quote_free(Q0, Q),
                 format(string(S), "the question for the ~w is ~w is \"~w\"", [W, P, Q]) ), QSs),
    (   member(decision(Id, DN, _, _, _, _), Items), \+ required(Items, Id),
        sym(DN, Sym), sym_functor_arity(Sym, F, A)
    ->  query_name(F, QN), functor(G, F, A),
        ( memberchk(query(QN, _), Qs0) -> Qs = Qs0 ; append(Qs0, [query(QN, G)], Qs) ),
        format(string(R), "the result is the answer to query ~w", [QN]), RSs = [R, "the result shows its reasons"]
    ;   Qs = Qs0, RSs = []
    ),
    quote_free(MName, Title), format(string(T), "the title is \"~w\"", [Title]),
    append([[T, "the case is a scenario", "the facts are asked one at a time"], QSs, RSs], Ss0),
    maplist([S0, S1]>>string_concat(S0, ".", S1), Ss0, Ss),
    emit(view(questions, Ss)).
question_view(_, Qs, Qs).

required(Items, Id) :-
    member(decision(_, _, _, reqs(Ds, _, _), _, _), Items), member(H, Ds), dmn_href_id(H, Id), !.

place_phrase(Noun, P) :- ( sub_atom(Noun, 0, 1, _, V), memberchk(V, [a, e, i, o, u]) -> Art = an ; Art = a ), format(atom(P), '~w ~w', [Art, Noun]).

quote_free(T0, T) :-
    ( atom(T0) -> atom_string(T0, S0) ; S0 = T0 ),
    split_string(S0, "\"", "", Parts), atomic_list_concat(Parts, '\'', A),
    split_string(A, "\n", " ", Ls), atomic_list_concat(Ls, ' ', T1), normalize_space(string(T), T1).

reset :-
    retractall(sym(_, _)), retractall(out(_)), retractall(ledger(_)),
    retractall(lib_used(_)), retractall(typedef(_, _, _)), retractall(struct_comp(_, _, _)),
    retractall(loaded(_, _)), retractall(loaded_file(_, _)), retractall(inlined_use(_, _)), retractall(import_prefix(_, _, _)),
    retractall(functor_taken(_)), retractall(fixed_sym(_)), retractall(rel_listed(_, _)), retractall(question_of(_, _)),
    retractall(service_fn(_, _, _)), retractall(functor_words_(_, _)), retractall(or_null_(_, _)),
    names_reset.

bkms_of(model(_, Items), Bs) :- include([I]>>(I = bkm(_, _, _, _, _)), Items, Bs).

model_symbols(_, Syms) :- findall(N-S, sym(N, S), Syms).

		 /*******************************
		 *            TYPES             *
		 *******************************/

declare_types(model(I, Items)) :-
    memberchk(namespace(NS), I),
    forall(member(itemdef(N, D), Items), assertz(typedef(NS, N, D))),
    forall(( loaded(_, model(I2, Items2)), memberchk(namespace(NS2), I2), NS2 \== NS ),
           forall(member(itemdef(N, D), Items2), assertz(typedef(NS2, N, D)))).

%!  load_imports(+File, +Model) is det.
%
%   The models a model imports, and theirs: each read once, by its
%   location (relative to the importing file, whatever the case of its
%   letters) or else by its namespace among the files beside it.
%   import_prefix(NS, Prefix, NS2): in the model NS, Prefix names NS2.
load_imports(File, Model) :-
    dmn_info(Model, namespace, NS),
    (   loaded(NS, _) -> true
    ;   assertz(loaded(NS, Model)), assertz(loaded_file(NS, File)),
        Model = model(_, Items),
        forall(member(import(P, NS2, Loc, _), Items),
               (   import_file(File, Loc, NS2, F2), catch(dmn_read_file(F2, M2), _, fail)
               ->  assertz(import_prefix(NS, P, NS2)), load_imports(F2, M2)
               ;   true
               ))
    ).

import_file(File, Loc, NS2, F2) :-
    file_directory_name(File, Dir),
    (   Loc \== '', directory_file_path(Dir, Loc, F0), exists_file(F0) -> F2 = F0
    ;   Loc \== '', directory_file_path(Dir, Loc, F0), file_directory_name(F0, D0), file_base_name(F0, B0),
        exists_directory(D0), directory_files(D0, Es), member(E, Es), downcase_atom(E, L), downcase_atom(B0, L)
    ->  directory_file_path(D0, E, F2)
    ;   file_directory_name(Dir, Up), file_directory_name(Up, Up2),
        directory_member(Up2, F2, [recursive(true), extensions([dmn])]),
        catch(dmn_read_file(F2, M), _, fail), dmn_info(M, namespace, NS2), !
    ).

%!  shape(+TypeRef, -Shape) is det.
%
%   value(Noun) | struct([Name-Shape]) | list(Shape)
shape(T0, Shape) :- shape(T0, 0, Shape).

shape(T0, Depth, Shape) :-
    strip_prefix(T0, T),
    (   Depth < 6, scoped_typedef(T, NS, D)
    ->  b_getval(dmn_scope, S0), b_setval(dmn_scope, NS),
        def_shape(D, Depth, Shape), b_setval(dmn_scope, S0)
    ;   type_noun(T, Noun), Shape = value(Noun)
    ).

%   A type's definition, seen from the model in scope: its own, or an
%   imported model's by prefix (`BDT.tSituation`).
scoped_typedef(T, NS, D) :-
    catch(b_getval(dmn_scope, S), _, S = ''),
    (   typedef(S, T, D) -> NS = S
    ;   sub_atom(T, B, 1, _, '.'), sub_atom(T, 0, B, _, P), B1 is B + 1, sub_atom(T, B1, _, 0, T2),
        import_prefix(S, P, NS), typedef(NS, T2, D) -> true
    ;   typedef(NS, T, D) -> true
    ).

def_shape(type(T, _, Coll), Depth, S) :-
    D1 is Depth + 1, shape(T, D1, S0), ( Coll == true -> S = list(S0) ; S = S0 ).
def_shape(struct(Comps, Coll), Depth, S) :-
    D1 is Depth + 1,
    findall(N-CS, ( member(component(N, CD), Comps), def_shape(CD, D1, CS) ), Cs),
    ( Coll == true -> S = list(struct(Cs)) ; S = struct(Cs) ).

strip_prefix(T0, T) :-
    ( atom(T0) -> A = T0 ; atom_string(A, T0) ),
    (   sub_atom(A, B, 1, _, ':'), \+ sub_atom(A, 0, _, _, 'http'), B1 is B + 1
    ->  sub_atom(A, B1, _, 0, T)
    ;   T = A
    ).

		 /*******************************
		 *     INPUTS AND DECISIONS     *
		 *******************************/

declare_inputs(model(_, Items)) :-
    forall(member(input(_, N, T, Meta), Items),
           ( shape(T, S0), merged_input_shape(N, S0, S),
             declare_symbol(N, S, [], input, Meta),
             fixed_input(N, Meta) )).

%   An input a service of an imported model reads too (BDT's `situation`,
%   passed whole): the union of its structure in every model, so that the
%   parts the service reads are inputs of the program as well.
merged_input_shape(N, S0, S) :-
    findall(S1, ( loaded(NS2, model(_, Items2)), b_getval(dmn_root, Root), NS2 \== Root,
                  member(input(_, N, T2, _), Items2),
                  with_scope(NS2, shape(T2, S1)) ), Others),
    foldl(merge_shape, Others, S0, S).

merge_shape(struct(Cs1), struct(Cs0), struct(Cs)) :- !,
    findall(K-V, ( member(K-V0, Cs0), ( memberchk(K-V1, Cs1) -> merge_shape(V1, V0, V) ; V = V0 ) ), A),
    findall(K-V, ( member(K-V, Cs1), \+ memberchk(K-_, Cs0) ), B),
    append(A, B, Cs).
merge_shape(list(S1), list(S0), list(S)) :- !, merge_shape(S1, S0, S).
merge_shape(_, S0, S0).

%   An input whose value the model fixes (STTR's vaste waarde) is a fact
%   of the program, not a question of the case.
fixed_input(N, Meta) :-
    (   memberchk(fixed(V0), Meta), sym(N, val(F, _))
    ->  ( memberchk(V0, [true, 'TRUE']) -> V = true ; memberchk(V0, [false, 'FALSE']) -> V = false
        ; atom_number(V0, V) -> true ; atom_string(V0, V) ),
        G =.. [F, V], emit(fact(G, [])),
        assertz(fixed_sym(N))
    ;   true
    ).

declare_decisions(model(_, Items)) :-
    forall(member(decision(_, N, T, _, Logic, Meta), Items),
           ( decision_shape(T, Logic, S), declare_symbol(N, S, [], decision, Meta) )).

%   A decision's shape: its type's, unless its logic makes it a list (a
%   collecting table) or a structure (several outputs).
decision_shape(T, table(Hit, Agg, _, Outs, _), S) :- !,
    (   T \== '', shape(T, S0), S0 \= value(value) -> true
    ;   Outs = [out(_, OT, _, _)] -> shape(OT, S0)
    ;   findall(ON-OS, ( member(out(ON, OT, _, _), Outs), shape(OT, OS) ), Cs), S0 = struct(Cs)
    ),
    (   collecting(Hit, Agg), S0 \= list(_) -> S = list(S0)
    ;   \+ collecting(Hit, Agg), S0 = list(S1), Outs = [_] -> S = S1
    ;   S = S0
    ).
decision_shape(T, context(Es), struct(Cs)) :-
    \+ memberchk(entry('$result', _), Es),
    \+ ( T \== '', shape(T, struct(_)) ), !,
    findall(N-value(value), member(entry(N, _), Es), Cs).
decision_shape(T, _, S) :- shape(T, S).

%   Names a model reads but does not declare. A Camunda Modeler model names
%   a decision by the name of its table's one output (`basisHoogteSubsidie`
%   for the decision "Bereken Basis Hoogte Subsidie"): that name is the
%   decision. Any other free name is a variable of the process that runs the
%   model, an input in all but its declaration: it is declared as one, with
%   the type of the input column that reads it.
declare_implicit(Model) :-
    Model = model(_, Items),
    forall(( member(decision(_, DN, _, _, table(Hit, Agg, _, [out(ON, _, _, _)], _), _), Items),
             ON \== '', \+ sym(ON, _), \+ collecting(Hit, Agg), sym(DN, S) ),
           assertz(sym(ON, S))),
    %  the same for each output of a table of several outputs: another
    %  decision may read the output by its column's name (RONL's
    %  jaarGebondenBudget, whose plafondEigenaren the plafond table reads)
    forall(( member(decision(_, DN, _, _, table(Hit, Agg, _, [_, _|_], _), _), Items),
             \+ collecting(Hit, Agg), sym(DN, struct(Comps)),
             member(ON-CS, Comps), ON \== '', \+ sym(ON, _),
             \+ passes_through(Items, DN, ON) ),
           assertz(sym(ON, CS))),
    model_scope(Model, Names0),
    bound_names(Model, Bound),
    findall(N-T, ( free_name(Model, Names0, N, T), \+ sym(N, _), \+ memberchk(N, Bound), \+ memberchk(N, Names0) ), NTs0),
    sort(1, @<, NTs0, NTs),
    forall(member(N-T, NTs), ( shape(T, S), declare_symbol(N, S, [], input, [implicit]) )).

%   Names a model binds itself: context entries, the variables of `for`,
%   `some` and `every`, function parameters, and the components of its
%   types and of the types it imports (a filter names an element's fields).
bound_names(model(I, Items), Bound) :-
    memberchk(namespace(NS), I),
    findall(N, ( member(decision(_, _, _, _, L, _), Items), sub_term(entry(N, _), L), N \== '$result' ), B1),
    findall(N, ( member(bkm(_, _, Ps, _, _), Items), member(param(N, _), Ps) ), B2),
    findall(N, ( ( typedef(NS, _, D) ; import_prefix(NS, _, NS2), typedef(NS2, _, D) ), sub_term(component(N, _), D) ), B3),
    findall(N, ( member(decision(_, _, _, _, L, _), Items), logic_texts(L, _-Text-_),
                 catch(feel_parse(Text, [], AST), _, fail), sub_term(iter(N, _), AST) ), B4),
    append([B1, B2, B3, B4, [item]], Bound).

free_name(model(_, Items), Names, N, T) :-
    member(decision(_, _, _, _, L, _), Items),
    logic_texts(L, Kind-Text-TypeRef),
    (   Kind == unary -> feel_unary(Text, Names, AST) ; feel_parse(Text, Names, AST) ),
    sub_term(name(N), AST), atom(N),
    \+ feel_builtin_name(N), \+ memberchk(N, [not, contains, date, decimal, duration, string, count, sum, min, max, all, any, floor, ceiling, abs, today, now, substring, number]),
    ( Kind == input, AST == name(N), TypeRef \== '' -> T = TypeRef ; T = '' ).

logic_texts(table(_, _, Ins, _, Rules), K) :-
    (   member(in(X, TR, _), Ins), K = input-X-TR
    ;   member(rule(_, IT, OT, _), Rules), ( member(X, IT), K = unary-X-'' ; member(X, OT), K = expr-X-'' )
    ).
logic_texts(literal(X), expr-X-'').
logic_texts(context(Es), K) :- member(entry(_, L), Es), logic_texts(L, K).
logic_texts(invocation(_, Bs), K) :- member(binding(_, L), Bs), logic_texts(L, K).

collecting(collect, none).
collecting(rule_order, _).
collecting(output_order, _).

%!  declare_symbol(+Name, +Shape, +Path, +Kind, +Meta) is det.
%
%   The templates of a value of this shape, written into the functions
%   section; the symbol records how a condition reads it.
declare_symbol(N, Shape, _, Kind, Meta) :-
    unique_words(N, N, Ws),
    symbol_for(Ws, Shape, Kind, Meta, Sym),
    assertz(sym(N, Sym)).

symbol_for(Ws, value(Noun), _, Meta, val(F, Noun)) :- !,
    functor_of(Ws, F),
    value_template(Ws, Noun, Text),
    emit(function(F, Text)),
    meta_comment(Meta, Ws).
symbol_for(Ws, struct(Cs), Kind, Meta, struct(Comps)) :- !,
    findall(CN-CSym, ( member(CN-CS, Cs), component_symbol(Ws, CN, CS, Kind, CSym) ), Comps),
    meta_comment(Meta, Ws).
symbol_for(Ws, list(value(Noun)), _, Meta, rel(F, [Noun])) :- !,
    functor_of([rel|Ws], F),
    atomic_list_concat(Ws, ' ', W),
    place(Noun, 1, P),
    format(string(Text), "the ~w include ~w", [W, P]),
    emit(template(F, Text, [])),
    listed_template(F, Ws),
    meta_comment(Meta, Ws).
symbol_for(Ws, list(struct(Cs)), _, Meta, rel(F, Nouns, Names)) :- !,
    functor_of([rel|Ws], F),
    atomic_list_concat(Ws, ' ', W),
    findall(Noun, member(_-value(Noun), Cs), Nouns),
    findall(CN, member(CN-value(_), Cs), Names),
    component_places(Names, Nouns, Ps), atomic_list_concat(Ps, ' with ', PT),
    format(string(Text), "the ~w include ~w", [W, PT]),
    emit(template(F, Text, [])),
    listed_template(F, Ws),
    meta_comment(Meta, Ws).

symbol_for(Ws, Shape, _, _, unsupported(Shape)) :-
    atomic_list_concat(Ws, ' ', W),
    format(string(C), "% ~w: a value of shape ~q has no form in this translation yet", [W, Shape]),
    emit(comment(C)).

%   A list is a relation, one fact per element; whether the list is given
%   at all (FEEL tells an empty list from null) is a sentence of its own.
listed_template(F, Ws) :-
    functor_of([listed|Ws], LF),
    atomic_list_concat(Ws, ' ', W),
    format(string(Text), "the ~w are listed", [W]),
    emit(template(LF, Text, [])),
    assertz(rel_listed(F, LF)).

:- dynamic rel_listed/2.

component_symbol(RootWs, CN, value(Noun), _, val(F, Noun)) :- !,
    name_words(CN, CWs),
    append(CWs, [of, the|RootWs], Ws),
    functor_of(Ws, F),
    value_template(Ws, Noun, Text),
    emit(function(F, Text)).
component_symbol(RootWs, CN, struct(Cs), Kind, struct(Comps)) :- !,
    name_words(CN, CWs), append(CWs, [of, the|RootWs], Ws),
    findall(N-S, ( member(N-CS, Cs), component_symbol(Ws, N, CS, Kind, S) ), Comps).
component_symbol(RootWs, CN, Shape, Kind, Sym) :-
    name_words(CN, CWs), append(CWs, [of, the|RootWs], Ws),
    symbol_for(Ws, Shape, Kind, [], Sym).

value_template(Ws, Noun, Text) :-
    atomic_list_concat(Ws, ' ', W),
    place(Noun, 1, P),
    format(string(Text), "the ~w is ~w", [W, P]).

%   An input that is a question (STTR's vraagTekst) is asked by the
%   program's view (question_view/2).
meta_comment(Meta, Ws) :-
    (   memberchk(question(Q), Meta) -> assertz(question_of(Ws, Q)) ; true ).

:- dynamic question_of/2.

functor_of(Ws, F) :-
    atomic_list_concat([d|Ws], '_', F0),
    atom_codes(F0, Cs), include([C]>>code_type(C, csym), Cs, Ds), atom_codes(F1, Ds),
    unique_functor(F1, F),
    assertz(functor_words_(F, Ws)).

:- dynamic functor_words_/2.

:- dynamic functor_taken/1.
unique_functor(F0, F) :-
    (   \+ functor_taken(F0) -> F = F0
    ;   between(2, inf, N), atomic_list_concat([F0, N], '_', F), \+ functor_taken(F), !
    ),
    assertz(functor_taken(F)).

%   The places of a list of structures, named after its components (`*a
%   delta r* with *an extra dikte mm*`), so that a rule says which value is
%   which; a component whose words are not a usable noun keeps its type.
component_places(Names, Nouns, Ps) :-
    foldl(component_place, Names, Nouns, Ps, []-[], _).

component_place(CN, Noun, P, Seen-Kinds, [W|Seen]-[Noun|Kinds]) :-
    (   name_words(CN, Ws0), Ws0 = [W0|_], \+ memberchk(W0, [a, an, the]),
        \+ ( member(X, Ws0), reserved_place_word(X) ),
        atomic_list_concat(Ws0, ' ', W), \+ memberchk(W, Seen), \+ memberchk(W, [number, text, value, date, list, 'truth value'])
    ->  place(W, 1, P)
    ;   W = '$type'(CN),
        include(==(Noun), Kinds, Same), length(Same, K), I is K + 1, place(Noun, I, P)
    ).

reserved_place_word(W) :- memberchk(W, [is, are, with, and, or, of, if, not, include, includes, listed, which, '*']).
reserved_place_word(W) :- atom(W), atom_number(W, _).

%   A template's place: `*a number*`, `*a second number*`, ...
place(Noun, I, P) :-
    (   I =:= 1 -> Ord = ''
    ;   nth1(I, ['', 'second ', 'third ', 'fourth ', 'fifth ', 'sixth ', 'seventh ', 'eighth ', 'ninth ', 'tenth ',
                 'eleventh ', 'twelfth ', 'thirteenth ', 'fourteenth ', 'fifteenth ', 'sixteenth ', 'seventeenth ',
                 'eighteenth ', 'nineteenth ', 'twentieth ', 'twenty first ', 'twenty second ', 'twenty third ',
                 'twenty fourth ', 'twenty fifth ', 'twenty sixth ', 'twenty seventh ', 'twenty eighth ',
                 'twenty ninth ', 'thirtieth '], Ord) -> true
    ;   throw(unsupported(places_beyond_thirty))
    ),
    atom_concat(Ord, Noun, Phrase),
    ( sub_atom(Phrase, 0, 1, _, V), memberchk(V, [a, e, i, o, u]) -> Art = an ; Art = a ),
    format(atom(P), '*~w ~w*', [Art, Phrase]).

%   Places for a list of nouns, each noun numbered by how often it came.
places(Nouns, Ps) :- places(Nouns, [], Ps).
places([], _, []).
places([N|Ns], Seen, [P|Ps]) :-
    include(==(N), Seen, Same), length(Same, K), I is K + 1,
    place(N, I, P), places(Ns, [N|Seen], Ps).

emit(I0) :- with_provenance(I0, I), assertz(out(I)).

%   A rule of a decision is labelled and cites the model and the decision
%   (and the table's rule, for a rule per row); the decision's description
%   and a row's annotations are its comment.
with_provenance(rule(H, B, Opts0), rule(H, B, Opts)) :-
    Opts0 \== [included],
    \+ memberchk(label(_), Opts0),
    nb_current(dmn_decision, d(Name, Label0, Desc)), Name \== none, !,
    flag(dmn_rule_no, N, N + 1), N1 is N + 1,
    format(atom(Label), '~w_~d', [Label0, N1]),
    (   nb_current(dmn_row, row(I, Ann)), I > 0
    ->  format(atom(Loc), 'decision ~w, rule ~d', [Name, I]), Comments = Ann
    ;   format(atom(Loc), 'decision ~w', [Name]), Comments = []
    ),
    (   N1 =:= 1, Desc \== '' -> AllC = [Desc|Comments] ; AllC = Comments ),
    (   AllC == [] -> CO = [] ; atomic_list_concat(AllC, ' ', C), CO = [comment(C)] ),
    append([Opts0, [label(Label), provenance([as_stated_in('the model'), at(Loc)])], CO], Opts).
with_provenance(I, I).

set_decision(Name, Meta) :-
    (   memberchk(description(D), Meta) -> true ; D = '' ),
    name_words(Name, Ws), atomic_list_concat(Ws, '_', L0),
    atom_codes(L0, Cs), include([C]>>code_type(C, csym), Cs, Ds), atom_codes(L, Ds),
    nb_setval(dmn_decision, d(Name, L, D)), flag(dmn_rule_no, _, 0),
    nb_setval(dmn_row, row(0, [])).

clear_decision :- nb_setval(dmn_decision, d(none, none, '')), nb_setval(dmn_row, row(0, [])).

		 /*******************************
		 *   BUSINESS KNOWLEDGE MODELS  *
		 *******************************/

declare_bkms(model(_, Items)) :-
    forall(member(bkm(_, N, Params, Logic, _), Items),
           ( unique_words(N, N, Ws),
             functor_of(Ws, F),
             findall(Noun, ( member(param(_, T), Params), shape(T, value(Noun0)) -> Noun = Noun0 ; Noun = value ), Nouns0),
             ( length(Params, NP), length(Nouns0, NP) -> Nouns = Nouns0 ; length(Params, NP2), length(Nouns, NP2), maplist(=(value), Nouns) ),
             bkm_out_noun(Logic, ON),
             places(Nouns, Ps), atomic_list_concat(Ps, ' and ', PT),
             include(==(ON), Nouns, SameN), length(SameN, KN), KN1 is KN + 1, place(ON, KN1, OP),
             atomic_list_concat(Ws, ' ', W),
             ( Params == [] -> format(string(Text), "the ~w is ~w", [W, OP])
             ; format(string(Text), "the ~w of ~w is ~w", [W, PT, OP]) ),
             emit(function(F, Text)),
             findall(PN, member(param(PN, _), Params), PNs),
             assertz(sym(N, bkm(F, PNs))) )).

bkm_out_noun(function(_, _, literal(_)), value) :- !.
bkm_out_noun(_, value).

translate_bkm(Model, bkm(_, N, Params, function(_, feel, Body), _)) :-
    sym(N, bkm(F, PNs)), !,
    ignore(Params = _),
    findall(P-'$ref'(P), member(P, PNs), Env),
    (   catch(logic_alts(Model, Body, Env, Alts), E, (unsupported(N, E), fail))
    ->  forall(member(A0, Alts),
               ( length(PNs, NP), length(Vars, NP),
                 pairs_keys_values(Bind, PNs, Vars),
                 resolve_refs(A0, Bind, a(G, T)),
                 append(Vars, [V], Args), Head =.. [F|Args],
                 value_rule(Head, V, G, T) )),
        ledger_entry(N, 'business knowledge model', encoded, 'a function with a place per parameter', N, '')
    ;   residue(N, 'business knowledge model', Body)
    ).
translate_bkm(_, bkm(_, N, _, Logic, _)) :- residue(N, 'business knowledge model', Logic).

		 /*******************************
		 *          DECISIONS           *
		 *******************************/

decisions_in_order(model(_, Items), Ds) :-
    include([I]>>(I = decision(_, _, _, _, _, _)), Items, Ds).

translate_decision(Model, decision(_, N, _, _, Logic, Meta)) :-
    sym(N, Sym),
    set_decision(N, Meta),
    aggregate_all(count, out(_), N0),
    call_cleanup(translate_decision_(Model, N, Sym, Logic), clear_decision),
    inlined_block(N, decision, N0).

translate_decision_(Model, N, Sym, Logic) :-
    (   catch(decision_logic(Model, N, Sym, Logic, Kind, Verdict, Note), E, (unsupported(N, E), fail))
    ->  ledger_entry(N, Kind, Verdict, Kind, N, Note)
    ;   logic_kind(Logic, K), residue(N, K, Logic)
    ).

logic_kind(table(_, _, _, _, _), 'decision table') :- !.
logic_kind(literal(_), 'literal expression') :- !.
logic_kind(L, K) :- functor(L, K, _).

unsupported(N, E) :-
    (   E = unsupported(What) -> true ; What = E ),
    format(user_error, "  ~w: not translated: ~q~n", [N, What]).

residue(N, Kind, Logic) :-
    name_functor(r, N, Id),
    logic_source(Logic, Src),
    format(string(T), "~w ~w", [Kind, N]),
    emit(residue(Id, [title(T), source('FEEL', Src)])),
    ledger_entry(N, Kind, residue, 'left for the assistant', Id, '').

logic_source(literal(T), T) :- !.
logic_source(L, S) :- format(string(S), "~q", [L]).

ledger_entry(Element, Kind, Verdict, Mapping, InProgram, Note) :-
    format(string(E), "~w", [Element]), format(string(K), "~w", [Kind]),
    format(string(M), "~w", [Mapping]), format(string(P), "~w", [InProgram]),
    assertz(ledger(entry(E, K, Verdict, M, P, Note))).

%   A decision's logic, as rules (or a table and its rule).
decision_logic(Model, _N, Sym, table(Hit, Agg, Ins, Outs, Rules), 'decision table', Verdict, Note) :- !,
    table_logic(Model, Sym, Hit, Agg, Ins, Outs, Rules, Verdict, Note).
decision_logic(Model, N, Sym, Logic, Kind, encoded, '') :-
    logic_kind(Logic, Kind),
    (   Sym = val(F, _) -> logic_alts(Model, Logic, [], Alts), value_rules(F, Alts)
    ;   Sym = struct(Comps), Logic = context(Es)
    ->  context_struct(Model, Comps, Es, [])
    ;   Sym = struct(Comps), Logic = literal(_), logic_alts(Model, Logic, [], [a([], '$ctx'(Cs))])
    ->  ctx_struct_rules(Comps, Cs)
    ;   Sym = rel(F, _), logic_alts(Model, Logic, [], Alts), list_rules(F, Alts)
    ;   throw(unsupported(shape(N, Sym)))
    ).

value_rules(F, Alts0) :-
    prune_alternatives(Alts0, Alts),
    forall(member(a(G, T), Alts), ( Head =.. [F, V], value_rule(Head, V, G, T) )).

%   Alternatives, simplified, without those another one subsumes: the same
%   value under fewer conditions (a null test on a structure gives one
%   alternative per part of it, most of them redundant).
prune_alternatives(Alts0, Alts) :-
    findall(a(G, T), ( member(a(G0, T), Alts0), simplify_goals(G0, G) ), Alts1),
    length(Alts1, N),
    (   N =< 200 -> prune_(Alts1, [], Alts) ; Alts = Alts1 ).     % quadratic: not for the largest

prune_([], Kept, Alts) :- reverse(Kept, Alts).
prune_([A|As], Kept, Alts) :-
    (   ( member(B, As) ; member(B, Kept) ), subsumes_alt(B, A)
    ->  prune_(As, Kept, Alts)
    ;   prune_(As, [A|Kept], Alts)
    ).

%   B subsumes A: B's value is A's and B's conditions are some of A's.
subsumes_alt(a(GB, TB), a(GA, TA)) :-
    length(GB, LB), length(GA, LA), LB =< LA,
    \+ GB =@= GA,
    \+ \+ ( copy_term(a(GB, TB), a(GB1, TB1)), subsumes_term(TB1, TA), TB1 = TA,
             subset_goals(GB1, GA) ).

%   One way only: a goal of B matches a goal of A by binding B's variables,
%   never A's (`F(true)` does not match `F(X)`).
subset_goals([], _).
subset_goals([G|Gs], As) :- once(( member(A, As), subsumes_term(G, A) )), G = A, subset_goals(Gs, As).

%   One rule per alternative: the head gives the value the alternative
%   computes.
value_rule(Head, V, G0, T) :-
    simplify_goals(G0, G), !,
    value_rule_(Head, V, G, T).
value_rule(_, _, _, _).                 % an alternative that can never hold

value_rule_(Head, V, G, T) :-
    (   var(T) -> V = T, Goals = G
    ;   T = '$concat'(_, _) -> concat_parts(T, Ps), use_lib(text), append(G, [feel_text_join(Ps, V)], Goals)
    ;   arith_term(T) -> append(G, [V is T], Goals)
    ;   V = T, Goals = G
    ),
    (   Goals == [] -> emit(fact(Head, []))
    ;   conj(Goals, Body), emit(rule(Head, Body, []))
    ).

%   The variables of the goals that are the values of truth-valued
%   functions.
%   (A recursion, not findall/3: the variables must be the goals' own.)
truth_values([], []).
truth_values([G|Gs], Ts) :-
    (   function_read(G, F, _, V), var(V), truth_functor(F) -> Ts = [V|Ts1] ; Ts = Ts1 ),
    truth_values(Gs, Ts1).

truth_functor(F) :- sym(_, val(F, 'truth value')), !.
truth_functor(F) :- sym(_, struct(Cs)), sub_term(val(F, 'truth value'), Cs), !.

%!  simplify_goals(+Goals0, -Goals) is semidet.
%
%   The conditions of an alternative without the constants the three-valued
%   compilation leaves: `true` goes, a `false` (or `not(true)`) makes the
%   alternative impossible (the predicate fails), and `or`/`and`/`not` over
%   constants fold.
simplify_goals(Gs0, Gs) :-
    truth_values(Gs0, Ts),
    maplist(simplify_goal, Gs0, Gs1),
    \+ memberchk(false, Gs1),
    exclude(==(true), Gs1, Gs2),
    merge_reads(Gs2, Gs3),
    fold_truths(Gs3, Ts, Gs).

%   A function has one value: two reads of it with the same inputs are one
%   read (`the x is a truth value and the x is a second truth value`).
merge_reads([], []).
merge_reads([G|Gs], [G|Out]) :-
    function_read(G, F, Ins, V), !,
    exclude_same_read(Gs, F, Ins, V, Gs1),
    merge_reads(Gs1, Out).
merge_reads([G|Gs], [G|Out]) :- merge_reads(Gs, Out).

exclude_same_read([], _, _, _, []).
exclude_same_read([G|Gs], F, Ins, V, Out) :-
    (   function_read(G, F, Ins2, V2), Ins2 == Ins, ( var(V2) ; V2 == V )
    ->  V2 = V, exclude_same_read(Gs, F, Ins, V, Out)
    ;   Out = [G|Out1], exclude_same_read(Gs, F, Ins, V, Out1)
    ).

%   A goal that reads a function's value: its inputs and its value.
function_read(G, F, Ins, V) :-
    compound(G), G =.. [F|Args], is_function_functor(F),
    append(Ins, [V], Args).

is_function_functor(F) :- sym(_, val(F, _)), !.
is_function_functor(F) :- sym(_, struct(Cs)), sub_term(val(F, _), Cs), !.
is_function_functor(F) :- sym(_, bkm(F, _)), !.

%   `V = true` where V is a function's value: the value written in its
%   place (`the x is true`); `V \= true` of a truth value: `V = false`.
fold_truths(Gs0, Ts, Gs) :-
    (   select(E, Gs0, Rest), truth_equality(E, Ts, V, B), var(V),
        member(R, Rest), function_read(R, _, _, V2), V2 == V
    ->  V = B, fold_truths(Rest, Ts, Gs)
    ;   Gs = Gs0
    ).

truth_equality(V = B, _, V, B) :- atomic(B), !.
truth_equality(B = V, _, V, B) :- atomic(B), var(V), !.
truth_equality(V \= true, Ts, V, false) :- var(V), memberchk_eq(V, Ts), !.
truth_equality(V \= false, Ts, V, true) :- var(V), memberchk_eq(V, Ts), !.

memberchk_eq(X, [Y|Ys]) :- ( X == Y -> true ; memberchk_eq(X, Ys) ).

simplify_goal(G, G) :- var(G), !.
simplify_goal(not(A0), G) :- !, simplify_goal(A0, A),
    ( A == true -> G = false ; A == false -> G = true ; A = not(B) -> G = B ; G = not(A) ).
simplify_goal(and(A0, B0), G) :- !, simplify_goal(A0, A), simplify_goal(B0, B),
    ( ( A == false ; B == false ) -> G = false ; A == true -> G = B ; B == true -> G = A ; G = and(A, B) ).
simplify_goal(or(A0, B0), G) :- !, simplify_goal(A0, A), simplify_goal(B0, B),
    ( ( A == true ; B == true ) -> G = true ; A == false -> G = B ; B == false -> G = A ; G = or(A, B) ).
simplify_goal(G, G).

list_rules(F, Alts) :-
    forall(member(a(G, T), Alts),
           (   is_list(T) -> forall(member(X, T), ( H =.. [F, X], value_rule(H, X, G, X) ))
           ;   Head =.. [F, V], value_rule(Head, V, G, T)
           )).

concat_parts(T, Ps) :- nonvar(T), T = '$concat'(A, B), !, concat_parts(A, PA), concat_parts(B, PB), append(PA, PB, Ps).
concat_parts(X, [X]).

arith_term(T) :- compound(T), T =.. [Op|_], memberchk(Op, [+, -, *, /, //, mod, floor, ceiling, round, abs, sqrt, truncate, **]).

%   A context whose components are the decision's structure: each entry
%   with a component of the same name is a function of its own; the
%   entries before it are values in scope.
%   A structure's components from a context value: each a function's rule.
ctx_struct_rules(Comps, Cs) :-
    forall(( member(K-As, Cs), memberchk(K-S, Comps) ),
           (   S = val(F, _) -> value_rules(F, As)
           ;   S = struct(Sub), As = [a([], '$ctx'(SubCs))] -> ctx_struct_rules(Sub, SubCs)
           ;   true
           )).

context_struct(Model, Comps, Es, Env0) :-
    foldl(context_entry(Model, Comps), Es, Env0, _).

context_entry(Model, Comps, entry(Name, Logic), Env, Env1) :-
    logic_alts(Model, Logic, Env, Alts),
    (   memberchk(Name-val(F, _), Comps)
    ->  value_rules(F, Alts),
        Env1 = Env
    ;   Alts = [a([], T)], ( var(T) ; atomic(T) )
    ->  Env1 = [Name-T|Env]
    ;   throw(unsupported(context_entry(Name)))
    ).

		 /*******************************
		 *        DECISION TABLES       *
		 *******************************/

table_logic(Model, Sym, Hit, Agg, Ins, Outs, Rules0, Verdict, Note) :-
    order_rows(Hit, Outs, Rules0, Rules),
    native_policy(Hit, Agg, Policy),
    retractall(null_column),
    (   native_table(Model, Ins, Outs, Rules, InTerms, Cells, OutCells)
    ->  table_annotations(Rules),
        native_table_items(Model, Sym, Policy, Hit, Agg, Ins, Outs, InTerms, Cells, OutCells),
        (   Hit == any -> Verdict = approximated,
            Note = "ANY: the first matching row answers; DMN also reports an error when the matching rows disagree"
        ;   null_column -> Verdict = approximated,
            Note = "a column that compares numbers and has `-` cells: where its input is null the table has no answer, while DMN matches a row with `-`"
        ;   Verdict = encoded, Note = ""
        )
    ;   row_rules(Model, Sym, Hit, Agg, Ins, Outs, Rules),
        Verdict = encoded, Note = "a rule per row"
    ).

native_policy(unique, _, unique).
native_policy(first, _, first).
native_policy(priority, _, first).
%   ANY: the matching rows agree (DMN reports an error when they do not),
%   so the first of them gives the decision's one value.
native_policy(any, _, first).
native_policy(collect, _, all).
native_policy(rule_order, _, all).
native_policy(output_order, _, all).

%   PRIORITY and OUTPUT ORDER: the rows in the order of the priority of
%   their outputs (the order of each output's allowed values), stable.
order_rows(Hit, Outs, Rules0, Rules) :-
    memberchk(Hit, [priority, output_order]), !,
    findall(Ps-R, ( member(R, Rules0), row_priority(Outs, R, Ps) ), Keyed),
    msort_stable(Keyed, Sorted), pairs_values(Sorted, Rules).
order_rows(_, _, Rules, Rules).

msort_stable(Keyed, Sorted) :- sort(1, @=<, Keyed, Sorted).

row_priority(Outs, rule(_, _, OT, _), Ps) :-
    findall(P, ( nth1(I, Outs, out(_, OT0, AV, _)), nth1(I, OT, Text),
                 allowed_list(OT0, AV, Allowed),
                 ( nth1(P0, Allowed, Text) -> P = P0 ; length(Allowed, L), P is L + 1 ) ), Ps).

allowed_list(TypeRef, AV, L) :-
    (   AV \== '' -> T = AV
    ;   strip_prefix(TypeRef, TN), scoped_typedef(TN, _, type(_, T, _)), T \== '' -> true
    ;   T = ''
    ),
    (   T == '' -> L = []
    ;   split_cells(T, L)
    ).

split_cells(T, L) :-
    atom_codes(T, Cs), split_top(Cs, Parts),
    maplist([P, A]>>(atom_codes(A0, P), normalize_space(atom(A), A0)), Parts, L).

%   The cells of a comma-separated list at the top level: not inside a
%   string, brackets or parentheses.
split_top(Cs, Parts) :- split_top(Cs, out, 0, [], Parts).

split_top([], _, _, Acc, [P]) :- reverse(Acc, P).
split_top([C|Cs], In, D, Acc, Parts) :-
    (   In == str
    ->  ( C =:= 0'\\, Cs = [N|Cs1] -> split_top(Cs1, str, D, [N, C|Acc], Parts)
        ; C =:= 0'" -> split_top(Cs, out, D, [C|Acc], Parts)
        ; split_top(Cs, str, D, [C|Acc], Parts) )
    ;   C =:= 0'" -> split_top(Cs, str, D, [C|Acc], Parts)
    ;   C =:= 0', , D =:= 0 -> reverse(Acc, P), Parts = [P|Ps], split_top(Cs, out, 0, [], Ps)
    ;   memberchk(C, `([`) -> D1 is D + 1, split_top(Cs, out, D1, [C|Acc], Parts)
    ;   memberchk(C, `)]`) -> D1 is D - 1, split_top(Cs, out, D1, [C|Acc], Parts)
    ;   split_top(Cs, out, D, [C|Acc], Parts)
    ).

%   A table LE writes as a table: each input expression a value a function
%   reads, each input cell a value, a list of values, a comparison with a
%   number, or `-`; each output cell a value.
native_table(Model, Ins, Outs, Rules, InTerms, Cells, OutCells) :-
    length(Ins, NI), length(Outs, NO), NI + NO =< 30,      % a template's places are named up to the thirtieth
    model_scope(Model, Names),
    maplist(input_value(Model, Names), Ins, InTerms0),
    findall(Row, ( member(rule(_, IT, _, _), Rules), maplist(native_cell(Names), IT, Row) ), Cells),
    length(Rules, NR), length(Cells, NR),
    findall(Row, ( member(rule(_, _, OT, _), Rules), maplist(native_out(Names), OT, Row) ), OutCells),
    length(OutCells, NR),
    length(Outs, _),
    columns(Cells, Columns),
    maplist(null_tolerant_input, Columns, InTerms0, InTerms).

columns([], []) :- !.
columns([R|Rs], Cols) :- length(R, N), numlist(1, N, Is),
    findall(Col, ( member(I, Is), findall(C, ( member(Row, [R|Rs]), nth1(I, Row, C) ), Col) ), Cols).

%   A column some of whose cells hold whatever the value (`-`) or whatever
%   it is not (`not(…)`) matches a row also where the input is null, as
%   DMN's does: the table is asked of `the … or null`, the value or the
%   word null. A column that also compares numbers cannot compare null: it
%   is read as it is, and where its input is null the table has no answer
%   (the ledger says so: null_column/0).
null_tolerant_input(Col, a(G, T), A) :-
    (   member(C, Col), ( C == any ; C = cond((\=)-_) ),
        \+ ( member(C2, Col), C2 = cond(E), \+ E = ((\=)-_) ),
        G = [Goal], Goal =.. [F, T]
    ->  or_null_functor(F, ONF), Goal2 =.. [ONF, V], A = a([Goal2], V)
    ;   member(C, Col), C == any, member(C2, Col), C2 = cond(_)
    ->  A = a(G, T), assertz(null_column)
    ;   A = a(G, T)
    ).

:- dynamic null_column/0.

:- dynamic or_null_/2.
or_null_functor(F, ONF) :-
    (   or_null_(F, ONF) -> true
    ;   functor_words(F, Ws), append(Ws, [or, null], OWs),
        functor_of(OWs, ONF),
        value_noun_of(F, Noun), value_template(OWs, Noun, Text),
        emit(function(ONF, Text)),
        H1 =.. [ONF, X], B1 =.. [F, X], emit(rule(H1, B1, [])),
        H2 =.. [ONF, null], B2 =.. [F, _], emit(rule(H2, not(B2), [])),
        assertz(or_null_(F, ONF))
    ).

value_noun_of(F, Noun) :- ( sym(_, val(F, Noun)) -> true ; sym(_, struct(Cs)), sub_term(val(F, Noun), Cs) -> true ; Noun = value ).

input_value(Model, Names, in(Text, _, _), a(G, T)) :-
    feel_parse(Text, Names, AST),
    ( logic_alts_ast(Model, AST, [], LAs__), LAs__ = [a(G, T)] ),
    var(T).

native_cell(Names, Text, Cell) :-
    feel_unary(Text, Names, Tests),
    cell_of(Tests, Cell).

cell_of(any, any) :- !.
cell_of([test(T)], C) :- !, cell_test(T, C).
cell_of(Tests, or_list(Vs)) :-
    is_list(Tests), Tests = [_, _|_],
    maplist([test(eq(E)), V]>>literal_value(E, V), Tests, Vs).
cell_of(not([test(eq(E))]), cond((\=)-V)) :- literal_value(E, V), \+ string(V).

cell_test(eq(E), V) :- literal_value(E, V).
cell_test(cmp(Op, E), cond(LOp-V)) :- literal_value(E, V), number(V), le_op(Op, LOp).
cell_test(range(LI, A, B, HI), cond(and(LO-VA, HO-VB))) :-
    literal_value(A, VA), literal_value(B, VB), number(VA), number(VB),
    ( LI == true -> LO = (>=) ; LO = (>) ), ( HI == true -> HO = (=<) ; HO = (<) ).

le_op('<', <). le_op('<=', =<). le_op('>', >). le_op('>=', >=). le_op('=', =). le_op('!=', \=).

native_out(Names, Text, V) :-
    feel_parse(Text, Names, E), literal_value(E, V).

literal_value(num(R), N) :- !, number_of(R, N).
literal_value(neg(num(R)), N) :- !, number_of(R, N0), N is -N0.
literal_value(str(S), S) :- !.
literal_value(bool(B), B) :- !.

number_of(R, N) :- ( integer(R) -> N = R ; rational(R, Num, 1) -> N = Num ; N is float(R) ).

%   The annotations of a table's rules (DMN's annotation columns, STTR's
%   explanation of a conclusion): a comment before the table, row by row.
table_annotations(Rules) :-
    findall(L, ( nth1(I, Rules, rule(_, _, _, An)), An \== [], atomic_list_concat(An, ' ', A),
                 format(string(L), "%   row ~d: ~w", [I, A]) ), Ls),
    (   Ls == [] -> true
    ;   atomic_list_concat(Ls, '\n', T), emit(comment(T))
    ).

native_table_items(Model, Sym, Policy, Hit, Agg, Ins, Outs, InTerms, Cells, OutCells) :-
    table_template(Model, Sym, Ins, Outs, TF, TName, NIn),
    findall(Row, ( nth1(I, Cells, InRow), nth1(I, OutCells, OutRow), append(InRow, OutRow, Row) ), Rows),
    findall(H, ( member(in(Text, _, _), Ins), column_heading(Text, H) ), InHs),
    findall(H, ( member(out(ON, _, _, _), Outs), ( ON == '' -> H = value ; column_heading(ON, H) ) ), OutHs0),
    ( OutHs0 == [] -> OutHs = [value] ; OutHs = OutHs0 ),
    append(InHs, OutHs, Heads),
    emit(table(TName, [policy(Policy)], Heads, Rows)),
    decision_from_table(Sym, Hit, Agg, TF, NIn, InTerms, Outs).

column_heading(Text, H) :-
    name_words(Text, Ws), atomic_list_concat(Ws, ' ', H).

%   The template the table encodes: its input columns, then its outputs.
table_template(_Model, Sym, Ins, Outs, TF, TName, NIn) :-
    sym_words(Sym, Ws),
    atomic_list_concat(Ws, '_', TName0), table_name(TName0, TName),
    findall(Noun, ( member(in(_, T, _), Ins), cell_noun(T, Noun) ), InNouns),
    findall(Noun, ( member(out(_, T, _, _), Outs), cell_noun(T, Noun) ), OutNouns0),
    ( OutNouns0 == [] -> OutNouns = [value] ; OutNouns = OutNouns0 ),
    length(InNouns, NIn),
    append(InNouns, OutNouns, AllNouns), places(AllNouns, Ps),
    length(InPs, NIn), append(InPs, OutPs, Ps),
    atomic_list_concat(Ws, ' ', W),
    atomic_list_concat(InPs, ' and ', IT), atomic_list_concat(OutPs, ' with ', OT),
    ( InPs == [] -> format(string(Text), "the ~w by table is ~w under table ~w", [W, OT, TName])
    ; format(string(Text), "the ~w for ~w is ~w under table ~w", [W, IT, OT, TName]) ),
    functor_of([table|Ws], TF),
    emit(template(TF, Text, [])).

table_name(N0, N) :- atom_codes(N0, Cs), include([C]>>code_type(C, csym), Cs, Ds), atom_codes(N, Ds).

cell_noun(T, Noun) :- ( T == '' -> Noun = value ; shape(T, value(Noun)) -> true ; Noun = value ).

sym_words(val(F, _), Ws) :- !, functor_words(F, Ws).
sym_words(rel(F, _), Ws) :- !, functor_words(F, Ws).
sym_words(rel(F, _, _), Ws) :- !, functor_words(F, Ws).
sym_words(struct([_-S|_]), Ws) :- !, sym_words(S, Ws0), ( append(_, [of, the|Ws], Ws0) -> true ; Ws = Ws0 ).

functor_words(F, Ws) :- functor_words_(F, Ws0), !, ( Ws0 = [rel|Ws] -> true ; Ws = Ws0 ).
functor_words(F, Ws) :-
    atomic_list_concat([_|Ws0], '_', F),
    ( Ws0 = [rel|Ws1] -> true ; Ws1 = Ws0 ),
    ( append(Ws2, [N], Ws1), atom_number(N, _) -> Ws = Ws2 ; Ws = Ws1 ).

%   The rules that read the decision from its table.
decision_from_table(Sym, Hit, Agg, TF, _NIn, InTerms, Outs) :-
    maplist([a(G, _), G]>>true, InTerms, Gs0), append(Gs0, InGoals),
    maplist([a(_, T), T]>>true, InTerms, InVs),
    length(Outs, NO0), ( NO0 == 0 -> NO = 1 ; NO = NO0 ),
    length(OutVs, NO),
    append(InVs, OutVs, Args), TableGoal =.. [TF|Args],
    append(InGoals, [TableGoal], Goals),
    (   Sym = val(F, _), OutVs = [V]
    ->  (   Agg \== none, Hit == collect
        ->  agg_op(Agg, Op), conj(Goals, Cond),
            Head =.. [F, R], conj(InGoals, _),
            with_default(Outs, 1, R, agg(Op, V, Cond, R), Body), emit(rule(Head, Body, []))
        ;   Head =.. [F, V], conj(Goals, Body0), with_default(Outs, 1, V, Body0, Body), emit(rule(Head, Body, []))
        )
    ;   Sym = rel(F, _), OutVs = [V]
    ->  Head =.. [F, V], conj(Goals, Body), emit(rule(Head, Body, []))
    ;   Sym = rel(F, _, _)
    ->  Head =.. [F|OutVs], conj(Goals, Body), emit(rule(Head, Body, []))
    ;   Sym = struct(Comps)
    ->  forall(( nth1(I, Outs, out(ON, _, _, _)), memberchk(ON-val(CF, _), Comps) ),
               ( copy_term(Goals-OutVs, Goals1-OutVs1), nth1(I, OutVs1, CV),
                 Head =.. [CF, CV], conj(Goals1, Body0), with_default(Outs, I, CV, Body0, Body),
                 emit(rule(Head, Body, [])) ))
    ;   throw(unsupported(table_shape(Sym)))
    ).

%   A table's default output (defaultOutputEntry): the value where no row
%   matches, as the last alternative of an otherwise cascade.
with_default(Outs, I, V, Body0, Body) :-
    (   nth1(I, Outs, out(_, _, _, D)), D \== '',
        catch(feel_parse(D, [], DA), _, fail), literal_value(DA, DV)
    ->  Body = otherwise([Body0, V = DV])
    ;   Body = Body0
    ).

agg_op(sum, sum). agg_op(count, count). agg_op(min, min). agg_op(max, max).

		 /*******************************
		 *         A RULE PER ROW       *
		 *******************************/

row_rules(Model, Sym, Hit, Agg, Ins, Outs, Rules) :-
    model_scope(Model, Names),
    maplist(input_value_any(Model, Names), Ins, InAlts),
    findall(row(I-An, Conds, OutAlts),
            ( nth1(I, Rules, rule(_, IT, OT, An)),
              row_conditions(Model, Names, InAlts, IT, Conds),
              maplist(out_alts(Model, Names), OT, OutAlts) ),
            Rows0),
    maplist([row(_, C, O), row(C, O)]>>true, Rows0, Rows),
    (   memberchk(Hit, [first, priority, any]), Sym = val(F, _)
    ->  first_cascade(F, Rows)
    ;   memberchk(Hit, [first, priority, any]), Sym = struct(Comps)
    ->  forall(( nth1(I, Outs, out(ON, _, _, _)), memberchk(ON-val(CF, _), Comps) ),
               ( findall(row(C, [OA]), ( member(row(C, OAs), Rows), nth1(I, OAs, OA) ), RowsI),
                 first_cascade(CF, RowsI) ))
    ;   Hit == collect, Agg \== none, Sym = val(F, Noun)
    ->  sym_words(Sym, Ws), functor_of([rows|Ws], RF),
        atomic_list_concat(Ws, ' ', W), place(Noun, 1, P),
        format(string(RT), "the ~w rows give ~w", [W, P]),
        emit(template(RF, RT, [])),
        forall(member(row(I-An, Conds, OutAlts), Rows0),
               ( nb_setval(dmn_row, row(I, An)), row_rule(rel(RF, [Noun]), Outs, Conds, OutAlts), nb_setval(dmn_row, row(0, [])) )),
        agg_op(Agg, Op), Goal =.. [RF, V], Head =.. [F, R],
        with_default(Outs, 1, R, agg(Op, V, Goal, R), Body), emit(rule(Head, Body, []))
    ;   forall(member(row(I-An, Conds, OutAlts), Rows0),
               ( nb_setval(dmn_row, row(I, An)), row_rule(Sym, Outs, Conds, OutAlts), nb_setval(dmn_row, row(0, [])) ))
    ).

input_value_any(Model, Names, in(Text, _, _), Alts) :-
    feel_parse(Text, Names, AST), logic_alts_ast(Model, AST, [], Alts).

out_alts(Model, Names, Text, Alts) :-
    feel_parse(Text, Names, AST), logic_alts_ast(Model, AST, [], Alts).

%   The conditions under which a row matches: for each column, the input's
%   value meets the cell's tests (an alternative list: a disjunction).
row_conditions(Model, Names, InAlts, IT, Conds) :-
    foldl(column_condition(Model, Names), InAlts, IT, [[]], Conds).

column_condition(Model, Names, VAlts, Text, Acc, Out) :-
    feel_unary(Text, Names, Tests0),
    camunda_tests(Model, Tests0, Tests),
    unary_holds(Model, Tests, VAlts, Hs),
    product(Acc, Hs, Out).

row_rule(val(F, _), _, Conds, [OAlts]) :- !,
    forall(( member(C, Conds), member(a(G, T), OAlts) ),
           ( append(C, G, Gs), H =.. [F, V], value_rule(H, V, Gs, T) )).
row_rule(rel(F, _), _, Conds, [OAlts]) :- !,
    forall(( member(C, Conds), member(a(G, T), OAlts) ),
           ( append(C, G, Gs), H =.. [F, V], value_rule(H, V, Gs, T) )).
row_rule(rel(F, _, _), _, Conds, OAltss) :- !,
    forall(( member(C, Conds), maplist([As, a(G, T)]>>member(a(G, T), As), OAltss, Picks) ),
           ( maplist([a(G1, _), G1]>>true, Picks, Gss), append([C|Gss], Gs0),
             maplist([a(_, T1), T1]>>true, Picks, Ts0),
             foldl(output_value, Ts0, Ts, Gs0, Gs),
             H =.. [F|Ts], ( Gs == [] -> emit(fact(H, [])) ; conj(Gs, B), emit(rule(H, B, [])) ) )).

row_rule(struct(Comps), Outs, Conds, OAltss) :- !,
    forall(( nth1(I, Outs, out(ON, _, _, _)), memberchk(ON-val(CF, _), Comps), nth1(I, OAltss, OAlts) ),
           row_rule(val(CF, value), [], Conds, [OAlts])).
row_rule(Sym, _, _, _) :- throw(unsupported(row_shape(Sym))).

%   An output computed by a formula, or joined from texts: a variable the
%   formula gives, after the conditions.
output_value(T, V, G0, G) :-
    (   var(T) -> V = T, G = G0
    ;   T = '$concat'(_, _) -> concat_parts(T, Ps), use_lib(text), append(G0, [feel_text_join(Ps, V)], G)
    ;   arith_term(T) -> append(G0, [V is T], G)
    ;   V = T, G = G0
    ).
%   FIRST as an otherwise cascade: the first row whose conditions hold.
first_cascade(F, Rows) :-
    findall(Alt, ( member(row(Conds, [OAlts]), Rows),
                   member(C, Conds), member(a(G, T), OAlts),
                   alt_body(C, G, T, V, Alt) ), Alts0),
    Alts0 \== [],
    Head =.. [F, V],
    maplist(bind_alt(V), Alts0, Alts),
    emit(rule(Head, otherwise(Alts), [])).

alt_body(C, G, T, V, alt(V, Body)) :-
    append(C, G, Gs00), simplify_goals(Gs00, Gs0),
    (   var(T) -> V = T, Gs = Gs0
    ;   arith_term(T) -> append(Gs0, [V is T], Gs)
    ;   append(Gs0, [V = T], Gs)
    ),
    conj(Gs, Body).

bind_alt(V, alt(V, B), B).

		 /*******************************
		 *       FEEL → CONDITIONS      *
		 *******************************/

model_scope(model(I, Items), Names) :-
    findall(N, ( member(It, Items),
                 ( It = input(_, N, _, _) ; It = decision(_, N, _, _, _, _) ; It = bkm(_, N, _, _, _)
                 ; It = service(_, N, _, _, _, _) ) ), Ns0),
    findall(N, ( member(itemdef(_, D), Items), sub_term(component(N, _), D) ), Cs),
    (   memberchk(namespace(NS), I)
    ->  findall(N, ( import_prefix(NS, P, NS2), loaded(NS2, model(_, Items2)), member(It2, Items2),
                     ( It2 = bkm(_, N0, _, _, _) ; It2 = service(_, N0, _, _, _, _) ; It2 = decision(_, N0, _, _, _, _) ),
                     ( N = N0 ; atomic_list_concat([P, '.', N0], N) ) ), INs),
        findall(N, ( import_prefix(NS, _, NS2), typedef(NS2, _, D2), sub_term(component(N, _), D2) ), ICs)
    ;   INs = [], ICs = []
    ),
    append([Ns0, Cs, INs, ICs], Ns1), sort(Ns1, Names).

%!  logic_alts(+Model, +Logic, +Env, -Alts) is det.
%
%   The value of a boxed expression, as alternatives a(Goals, Term): under
%   Goals the value is Term. No alternative is FEEL's null.
logic_alts(Model, literal(Text), Env, Alts) :- !,
    model_scope(Model, Names0), pairs_keys(Env, ENs), append(ENs, Names0, Names),
    (   feel_parse(Text, Names, AST) -> true ; throw(unsupported(parse(Text))) ),
    logic_alts_ast(Model, AST, Env, Alts).
logic_alts(Model, context(Es), Env, Alts) :- !,
    context_alts(Model, Es, Env, Alts).
logic_alts(Model, invocation(Callee, Bs), Env, Alts) :-
    service_named(Model, Callee, SM, Svc), !,
    findall(P-L, member(binding(P, L), Bs), PLs),
    service_alts(Model, Env, SM, Svc, PLs, Alts).
logic_alts(Model, invocation(Callee, Bs), Env, Alts) :- !,
    (   sym(Callee, bkm(F, PNs)) -> true ; throw(unsupported(invocation(Callee))) ),
    findall(P-A, ( member(P, PNs), ( member(binding(P, L), Bs) -> logic_alts(Model, L, Env, A) ; A = [] ) ), PAs),
    pairs_values(PAs, ArgAlts),
    call_alts(F, ArgAlts, Alts).
logic_alts(_, L, _, _) :- throw(unsupported(L)).

%   A context whose result is its last entry: the entry's logic is the
%   result (no earlier entry can name the last one).
context_alts(Model, Es, Env, Alts) :-
    append(Before, [entry(N, L), entry('$result', literal(T))], Es),
    atom_string(N, NS), split_string(T, "", " \t\n\r", [NS]), !,
    append(Before, [entry('$result', L)], Es1),
    context_alts(Model, Es1, Env, Alts).
context_alts(Model, Es, Env, Alts) :-
    \+ sub_term('$ref'(_), Env),
    nb_current(dmn_decision, d(DName, _, _)), DName \== none,
    append(Before, [entry('$result', R)], Es), !,
    foldl(entry_function(Model, DName), Before, Env, Env1),
    logic_alts(Model, R, Env1, Alts).
context_alts(Model, Es, Env, Alts) :-
    (   append(Before, [entry('$result', R)], Es) -> true ; throw(unsupported(context_without_result)) ),
    foldl(local_entry(Model), Before, Env-[], Env1-Defs0),
    logic_alts(Model, R, Env1, RAlts0),
    partition([D]>>(D = '$bind'(_, _)), Defs0, Binds, Defs),
    findall(A, ( member(A0, RAlts0), expand_locals(A0, Defs, A) ), Alts1),
    foldl([ '$bind'(Ks, Vs), X0, X1]>>bind_refs(Ks, Vs, X0, X1), Binds, Alts1, Alts).

%   An entry of a context evaluated on the program's own inputs (a
%   decision's, a service's invoked on them): a function of the twin, `the
%   <entry> of the <decision> is *a value*`, that the entries after it and
%   the result read. An entry whose value is a list or a structure stays a
%   set of alternatives.
entry_function(Model, DName, entry(N, L), Env, [N-X|Env]) :-
    logic_alts(Model, L, Env, As),
    (   As \== [], forall(member(a(_, T), As), structured(T))
    ->  X = '$alts'(As)
    ;   unique_words(ctx(DName, N), N, EWs0), name_words(DName, DWs),
        ( append(_, [of, the|DWs], EWs0) -> EWs = EWs0 ; append(EWs0, [of, the|DWs], EWs) ),
        functor_of(EWs, F),
        ( As \== [], forall(member(a(_, T), As), ( T == true ; T == false )) -> Noun = 'truth value' ; Noun = value ),
        value_template(EWs, Noun, Text),
        emit(function(F, Text)),
        assertz(sym('$entry'(DName, N), val(F, Noun))),
        value_rules(F, As),
        X = '$fun'(F)
    ).

%   A context entry: a name in scope, a reference its definition replaces
%   in each alternative that uses it (expand_locals/3).
local_entry(Model, entry(N, L), Env-Defs, Env1-Defs1) :-
    logic_alts(Model, L, Env, As),
    (   As \== [], forall(member(a(_, T), As), structured(T))
    ->  groundify(As, AsG, Keys, Vars),
        Env1 = [N-'$alts'(AsG)|Env], Defs1 = ['$bind'(Keys, Vars)|Defs]
    ;   gensym('$local_', Key), Env1 = [N-'$ref'(Key)|Env], Defs1 = [Key-As|Defs]
    ).

structured(T) :- nonvar(T), functor(T, F, _), memberchk(F, ['$elem', '$tuple', '$stream', '$ctx', '$rel', '$struct', '$entries', '$between', '$ym']).

%   Each reference to a local entry: one of its alternatives, its goals
%   first, its value in the reference's place.
expand_locals(a(G00, T00), Defs, A) :-
    foldl(known_entry, Defs, a(G00, T00), a(G0, T0)),
    (   member(Key-As, Defs), sub_term(S, a(G0, T0)), S == '$ref'(Key)
    ->  member(a(GL, TL), As),
        (   ( var(TL) ; atomic(TL) )
        ->  replace_ref(Key, TL, a(G0, T0), a(G1, T1)), append(GL, G1, G2)
        ;   replace_ref(Key, X, a(G0, T0), a(G1, T1)),
            (   arith_term(TL) -> append([GL, [X is TL], G1], G2)
            ;   X = TL, append(GL, G1, G2)
            )
        ),
        expand_locals(a(G2, T1), Defs, A)
    ;   A = a(G0, T0)
    ).

%   `x = null` on a context entry: the entry has a value where one of its
%   definitions holds.
known_entry(Key-As, A0, A) :-
    findall(C, ( member(a(G, _), As), conj(G, C) ), Cs),
    (   Cs == [] -> B = false
    ;   memberchk(true, Cs) -> B = true
    ;   disj(Cs, B)
    ),
    replace_marker('$known'(Key), B, A0, A).

replace_marker(M, B, T0, T) :-
    (   T0 == M -> T = B
    ;   var(T0) -> T = T0
    ;   compound(T0) -> T0 =.. [F|As0], maplist(replace_marker(M, B), As0, As), T =.. [F|As]
    ;   T = T0
    ).

%   The references of an alternative bound to variables (a BKM's
%   parameters): a place always holds a value.
resolve_refs(A0, Bind, A) :-
    foldl([P-V, X0, X]>>( replace_ref(P, V, X0, X1), replace_marker('$known'(P), true, X1, X) ), Bind, A0, A).

replace_ref(Key, V, T0, T) :-
    (   T0 == '$ref'(Key) -> T = V
    ;   var(T0) -> T = T0
    ;   compound(T0) -> T0 =.. [F|As0], maplist(replace_ref(Key, V), As0, As), T =.. [F|As]
    ;   T = T0
    ).

%!  logic_alts_ast(+Model, +AST, +Env, -Alts) is det.
logic_alts_ast(_, num(R), _, [a([], N)]) :- !, number_of(R, N).
logic_alts_ast(_, str(S), _, [a([], S)]) :- !.
logic_alts_ast(_, bool(B), _, [a([], B)]) :- !.
logic_alts_ast(_, null, _, []) :- !.
logic_alts_ast(M, name(N), Env, Alts) :- env_form(N, Env, '$alias'(G)), !, logic_alts_ast(M, name(G), [], Alts).
logic_alts_ast(_, name(N), Env, [a([], S)]) :- env_form(N, Env, '$sym'(S)), !.
logic_alts_ast(_, name(N), Env, As) :- env_form(N, Env, '$alts'(As)), !.
logic_alts_ast(_, name(N), Env, [a([G], V)]) :- env_form(N, Env, '$fun'(F)), !, G =.. [F, V].
logic_alts_ast(_, name(N), Env, [a([], V)]) :- memberchk(N-V, Env), !.
logic_alts_ast(M, name(N), Env, Alts) :- inlined_decision(M, N, Env, Alts), !.
logic_alts_ast(_, q, Env, [a([], V)]) :- memberchk('?'-V, Env), !.
logic_alts_ast(_, name(N), _, Alts) :- !, name_alts(N, Alts).
logic_alts_ast(M, path(E, F), Env, Alts) :- !, path_alts(M, E, F, Env, Alts).
logic_alts_ast(M, neg(E), Env, Alts) :- !,
    logic_alts_ast(M, E, Env, As),
    findall(a(G, T), ( member(a(G, T0), As), neg_term(T0, T) ), Alts).
logic_alts_ast(M, arith(Op, A, B), Env, Alts) :- !,
    logic_alts_ast(M, A, Env, AAs), logic_alts_ast(M, B, Env, BAs),
    findall(a(G, T), ( member(a(GA, TA), AAs), member(a(GB, TB), BAs),
                       append(GA, GB, G0), arith(Op, TA, TB, G0, G, T) ), Alts).
logic_alts_ast(M, if(C, T, E), Env, Alts) :- !,
    holds(M, C, Env, Hs),
    logic_alts_ast(M, T, Env, TAs), logic_alts_ast(M, E, Env, EAs),
    findall(a(G, X), ( member(H, Hs), member(a(GT, X), TAs), append(H, GT, G) ), A1),
    (   Hs == [] -> NotH = []
    ;   disj_body(Hs, HB), NotH = [not(HB)]
    ),
    findall(a(G, X), ( member(a(GE, X), EAs), append(NotH, GE, G) ), A2),
    append(A1, A2, Alts).
logic_alts_ast(M, E, Env, Alts) :-
    boolean_ast(E), !,
    holds(M, E, Env, Hs), fails(M, E, Env, Fs),
    findall(a(H, true), member(H, Hs), A1),
    findall(a(F, false), member(F, Fs), A2),
    append(A1, A2, Alts).
logic_alts_ast(_, call(name('get entries'), [pos(name(D))]), _, [a([], '$entries'(Cs))]) :-
    sym(D, struct(Cs)), !.
logic_alts_ast(M, call(name(F), [pos(L)]), Env, Alts) :-
    memberchk(F-Op, [count-count, sum-sum, min-min, max-max, mean-average]),
    catch(( logic_alts_ast(M, L, Env, LAs__), LAs__ = [a(G0, '$stream'(Es))] ), _, fail), !,
    findall(a(G, R), ( Es \== [], member(a(GE, T), Es), !, conj(GE, C0), ( G0 == [] -> C = C0 ; true ),
                       G = [agg(Op, T, C, R)] ), Alts0),
    ( Alts0 == [] -> Alts = [a([], 0)] ; Alts = Alts0 ), ignore(C = C0).
logic_alts_ast(M, call(name(F), Args), Env, Alts) :-
    temporal_call(M, F, Args, Env, Alts), !.
logic_alts_ast(M, call(name(F), Args), Env, Alts) :- !,
    call_name_alts(M, F, Args, Env, Alts).
logic_alts_ast(M, call(path(name(P), F), Args), Env, Alts) :- !,
    atomic_list_concat([P, '.', F], PF),
    call_name_alts(M, PF, Args, Env, Alts).
%   A list written as an LE list, indexed by position: lib/feel.
logic_alts_ast(M, filter(E, Idx), Env, Alts) :-
    \+ boolean_ast(Idx), \+ sub_term(name(item), Idx),
    logic_alts_ast(M, E, Env, EAs), EAs \== [],
    forall(member(a(_, L), EAs), ( nonvar(L), is_list(L) ; L = '$ref'(_) )), !,
    logic_alts_ast(M, Idx, Env, IAs), use_lib(feel),
    findall(a(G, X), ( member(a(GE, L), EAs), member(a(GI, I), IAs),
                       operand_var(I, VI, GV), append([GE, GI, GV, [feel_item(VI, L, X)]], G) ), Alts).
logic_alts_ast(M, filter(E, num(1)), Env, Alts) :- !,
    logic_alts_ast(M, E, Env, EAs),
    findall(a(G, T), ( member(A, EAs), stream_element(A, a(G, T)) ), Alts).
logic_alts_ast(M, filter(E, Cond), Env, [a([], '$stream'(Alts))]) :-
    \+ Cond = num(_),
    ( logic_alts_ast(M, E, Env, LAs__), LAs__ = [a(G0, '$stream'(Es))] ), !,
    findall(a(G, X), ( member(a(GE, X), Es), element_ref(X, XR, Keys, Vals),
                       holds(M, Cond, [item-XR|Env], Hs), member(H0, Hs), bind_refs(Keys, Vals, H0, H),
                       append([G0, GE, H], G) ), Alts).
logic_alts_ast(M, filter(E, Cond), Env, Alts) :- !,
    logic_alts_ast(M, E, Env, EAs),
    findall(a(G, '$elem'(Names, Vars)),
            ( member(a(G0, R), EAs), relation_tuple(R, G0, Names, Vars, G1),
              ref_keys(Names, Keys, Refs),
              pairs_keys_values(FieldEnv, Names, Refs),
              append(Env, [item-'$tuple'(Names, Refs)|FieldEnv], Env1),
              holds(M, Cond, Env1, Hs), member(H0, Hs),
              bind_refs(Keys, Vars, H0, H), append(G1, H, G) ),
            Alts).
logic_alts_ast(M, for([iter(V, Dom)], Ret), Env, [a([], '$stream'(Elems))]) :- !,
    logic_alts_ast(M, Dom, Env, DAs),
    findall(a(G, T), ( member(a(G0, D), DAs), domain_element(D, G0, X, G1),
                       element_ref(X, XR, Keys, Vals),
                       logic_alts_ast(M, Ret, [V-XR|Env], RAs), member(A0, RAs),
                       bind_refs(Keys, Vals, A0, a(G2, T)), append(G1, G2, G) ),
            Elems).
logic_alts_ast(M, context(KEs), Env, [a([], '$ctx'(Cs))]) :- !,
    findall(K-As, ( member(K-E, KEs), logic_alts_ast(M, E, Env, As) ), Cs).
logic_alts_ast(_, list(Es), _, [a([], L)]) :-
    maplist(literal_value, Es, L), !.
%   A list of expressions is a value: an LE list, one for each choice of
%   its elements' alternatives, their goals first.
logic_alts_ast(M, list(Es), Env, Alts) :- !,
    maplist(arg_alts(M, Env), Es, EAs),
    findall(a(G, Ts), ( pick_all(EAs, Picks),
                        maplist([a(G1, _), G1]>>true, Picks, Gss), append(Gss, G),
                        maplist([a(_, T1), T1]>>true, Picks, Ts) ), Alts).
logic_alts_ast(_, at(S), _, [a([], D)]) :- date_literal(S, D), !.
logic_alts_ast(_, E, _, _) :- throw(unsupported(E)).

neg_term(T0, T) :- ( number(T0) -> T is -T0 ; T = -(T0) ).

arith(+, A, B, G, G, T) :- ( string(A) ; string(B) ; is_concat(A) ; is_concat(B) ), !, T = '$concat'(A, B).
%   LE has no power operator: lib/maths's function, its operands first
%   given names when they are formulas.
arith(**, A, B, G0, G, P) :- !,
    use_lib(maths),
    operand_var(A, VA, GA), operand_var(B, VB, GB),
    append([G0, GA, GB, [feel_power(VA, VB, P)]], G).
arith(+, D, Dur, G0, G, Later) :- duration_months(Dur, N), !,
    use_lib(temporal), operand_var(N, VN, GN), append([G0, GN, [feel_months_after(Later, VN, D)]], G).
arith(+, Dur, D, G0, G, Later) :- duration_months(Dur, N), !,
    use_lib(temporal), operand_var(N, VN, GN), append([G0, GN, [feel_months_after(Later, VN, D)]], G).
arith(-, D, Dur, G0, G, Earlier) :- duration_months(Dur, N), !,
    use_lib(temporal), operand_var(N, VN, GN), append([G0, GN, [feel_months_before(Earlier, VN, D)]], G).
arith(Op, A, B, G, G, T) :- ( number(A), number(B), Op \== (/) -> T0 =.. [Op, A, B], T is T0 ; T =.. [Op, A, B] ).

duration_months(T, N) :- nonvar(T), T = '$ym'(N).

		 /*******************************
		 *       DATES, DURATIONS       *
		 *******************************/

%   date(...), duration(...), years and months duration(...).
temporal_call(M, date, [pos(X)], Env, Alts) :-
    logic_alts_ast(M, X, Env, XAs),
    findall(a(G, D), ( member(a(G0, T), XAs), to_date(T, G0, G, D) ), Alts).
temporal_call(M, date, [pos(Y), pos(Mo), pos(D)], Env, Alts) :-
    maplist(arg_alts(M, Env), [Y, Mo, D], [YA, MA, DA]),
    findall(a(G, T), ( member(a(G1, TY), YA), member(a(G2, TM), MA), member(a(G3, TD), DA),
                       append([G1, G2, G3], G0),
                       (   integer(TY), integer(TM), integer(TD) -> valid_date(TY, TM, TD), T = date(TY, TM, TD), G = G0
                       ;   use_lib(feel), maplist(operand_var, [TY, TM, TD], [VY, VM, VD], GVs), append(GVs, GV),
                           append([G0, GV, [feel_date_of_parts(VY, VM, VD, T)]], G)
                       ) ), Alts),
    Alts \== [].
temporal_call(M, duration, [pos(arith(+, arith(+, str("P"), call(name(string), [pos(X)])), str(U)))], Env, Alts) :-
    memberchk(U-K, ["M"-1, "Y"-12]), !,
    logic_alts_ast(M, X, Env, XAs),
    findall(a(G, '$ym'(N)), ( member(a(G, T), XAs), ( K =:= 1 -> N = T ; N = T * 12 ) ), Alts).
temporal_call(M, duration, [pos(X)], Env, Alts) :-
    logic_alts_ast(M, X, Env, XAs),
    findall(a(G, '$ym'(N)), ( member(a(G, T), XAs), iso_months(T, N) ), Alts),
    Alts \== [].
temporal_call(M, 'years and months duration', [pos(A), pos(B)], Env, Alts) :-
    logic_alts_ast(M, A, Env, AAs), logic_alts_ast(M, B, Env, BAs),
    findall(a(G, '$between'(TA, TB)), ( member(a(GA, TA), AAs), member(a(GB, TB), BAs), append(GA, GB, G) ), Alts).

%   A value as a date: already one, a date written in the program, or a
%   text read as one (lib/feel).
to_date(T, G, G, T) :- nonvar(T), T = date(_, _, _), !.
to_date(T, G, G, D) :- string(T), !, date_literal(T, D).
to_date(T, G, G, T) :- value_noun(T, G, date), !.
to_date(T, G, G, T) :- date_like(T, G), !.
to_date(T, G0, G, D) :- use_lib(feel), append(G0, [feel_date_of_text(T, D)], G).

%   The noun of the place a variable fills in the goal that binds it.
value_noun(T, G, Noun) :-
    var(T), member(L, G), compound(L), L =.. [F|As], last(As, X), X == T,
    sym(_, val(F, Noun)), !.
value_noun(T, G, Noun) :-
    var(T), member(L, G), compound(L), L =.. [F|As], last(As, X), X == T,
    sym(_, struct(Cs)), sub_term(val(F, Noun), Cs), !.

%   An ISO duration of years and months, as months: P18Y, P6M, P1Y2M, and
%   "P" + string(N) + "M" (the RONL models).
iso_months(T, N) :- string(T), !, string_codes(T, Cs), phrase(iso_ym(N), Cs).
iso_months(T, N) :- concat_parts(T, Ps), Ps = ["P", X, U], ( U == "M" -> N = X ; U == "Y" -> N = X * 12 ).

iso_ym(N) --> "P", ym_part(Y, 0'Y), ym_part(M, 0'M), { N is Y * 12 + M, N > 0 }.
ym_part(V, U) --> digits1(Ds), [U], !, { number_codes(V, Ds) }.
ym_part(0, _) --> [].
digits1([D|Ds]) --> [D], { code_type(D, digit) }, digits0(Ds).
digits0([D|Ds]) --> [D], { code_type(D, digit) }, !, digits0(Ds).
digits0([]) --> [].

%   The part of a date or of a duration a path names.
part_of(year, T, G0, G, V) :- date_like(T, G0), !, use_lib(temporal), append(G0, [feel_year_of(T, V)], G).
part_of(month, T, G0, G, V) :- date_like(T, G0), !, use_lib(temporal), append(G0, [feel_month_of(T, V)], G).
part_of(day, T, G0, G, V) :- date_like(T, G0), !, use_lib(feel), append(G0, [feel_day_of(T, V)], G).
part_of(years, T, G0, G, V) :- nonvar(T), T = '$between'(A, B), !, use_lib(temporal), append(G0, [feel_whole_years(A, B, V)], G).
part_of(months, T, G0, G, V) :- nonvar(T), T = '$between'(A, B), !, use_lib(temporal),
    append(G0, [feel_whole_months(A, B, M0), V is M0 mod 12], G).
part_of(years, T, G, G, V) :- nonvar(T), T = '$ym'(N), !, V = N // 12.
part_of(months, T, G, G, V) :- nonvar(T), T = '$ym'(N), !, V = N mod 12.

date_like(T, _) :- nonvar(T), T = date(_, _, _), !.
date_like(T, _) :- nonvar(T), T = '$ref'(_), !.     % a loop's element: `current date.year`
date_like(T, G) :- value_noun(T, G, date), !.
date_like(T, G) :- var(T), member(L, G), date_goal(L, D), D == T, !.

%   The library goals whose result is a date.
date_goal(feel_date_of_text(_, D), D).
date_goal(feel_months_after(D, _, _), D).
date_goal(feel_months_before(D, _, _), D).
date_goal(feel_today(D), D).
date_goal(feel_date_of_parts(_, _, _, D), D).

is_concat(T) :- nonvar(T), T = '$concat'(_, _).

operand_var(X, X, []) :- ( var(X) ; number(X) ; X = '$ref'(_) ), !.
operand_var(X, V, [V is X]).

%   A table whose output entry for ON is ON itself only passes on a value
%   computed elsewhere (RONL's SVB Leeftijds Informatie, beside SVB Bereken
%   Leeftijden): it is not where a reader of ON finds it.
passes_through(Items, DN, ON) :-
    member(decision(_, DN, _, _, table(_, _, _, Outs, Rules), _), Items),
    nth1(I, Outs, out(ON, _, _, _)),
    member(rule(_, _, OT, _), Rules), nth1(I, OT, T),
    normalize_space(atom(TA), T), TA == ON, !.

%!  camunda_reading(+Model) is semidet.
%
%   A model of Camunda Modeler, which Camunda's engine runs: an input entry
%   that is a boolean expression (`date(dagVanAanvraag) <= date("2024-12-31")`,
%   RONL's home-battery subsidy) is the test itself, whatever the input's
%   value; Drools and the DMN standard compare the input with the
%   expression's value instead.
camunda_reading(Model) :-
    dmn_info(Model, exporter, E), sub_atom(E, _, _, _, 'Camunda Modeler'), !.

camunda_tests(Model, Tests0, Tests) :-
    is_list(Tests0), camunda_reading(Model), !,
    maplist([T0, T]>>( T0 = test(eq(E)), boolean_ast(E) -> T = test(expr(E)) ; T = T0 ), Tests0, Tests).
camunda_tests(_, Tests, Tests).

boolean_ast(and(_, _)). boolean_ast(or(_, _)). boolean_ast(cmp(_, _, _)).
boolean_ast(between(_, _, _)). boolean_ast(in(_, _)).
boolean_ast(call(name(F), _)) :- memberchk(F, [not, contains, 'ends with', 'starts with', 'list contains', 'is defined', all, any, odd, even]).
boolean_ast(some(_, _)). boolean_ast(every(_, _)).

%   The entry of the environment for a name, when it has the form asked:
%   an entry whose value is still a variable has no form.
env_form(N, Env, Form) :-
    memberchk(N-X, Env), nonvar(X), functor(Form, F, A), functor(X, F, A), X = Form.

%   A decision of a model the program reaches only through one of its
%   services (dmn_twin's service inlining): its logic, in that model, with
%   the service's inputs as the environment.
inlined_decision(M, N, Env, Alts) :-
    M = model(I, Items), memberchk(namespace(NS), I),
    b_getval(dmn_root, Root), NS \== Root,
    member(decision(_, N, _, _, L, _), Items), !,
    with_scope(NS, logic_alts(M, L, Env, Alts)).

with_scope(NS, G) :-
    b_getval(dmn_scope, S0), b_setval(dmn_scope, NS),
    (   catch(G, E, (b_setval(dmn_scope, S0), throw(E))) -> b_setval(dmn_scope, S0) ; b_setval(dmn_scope, S0), fail ).

%   A name of the model: a function of no place, or a list relation.
name_alts(N, [a([G], V)]) :- sym(N, val(F, _)), !, G =.. [F, V].
name_alts(N, _) :- sym(N, S), !, throw(unsupported(value_of(N, S))).
name_alts(N, _) :- throw(unsupported(unknown_name(N))).

%   A date's year, month and day; the years and months of a duration
%   between two dates.
path_alts(M, E, Field, Env, Alts) :-
    memberchk(Field, [year, month, day, years, months]),
    logic_alts_ast(M, E, Env, EAs), EAs \== [],
    findall(a(G, V), ( member(a(G0, T), EAs), part_of(Field, T, G0, G, V) ), Alts),
    Alts \== [], !.
path_alts(M, E, Field, Env, Alts) :-
    path_root(E, Root0, Path0), append(Path0, [Field], Path),
    (   env_form(Root0, Env, '$alias'(Root)) -> true
    ;   \+ memberchk(Root0-_, Env), Root = Root0
    ),
    sym(Root, struct(Comps)), comp_at(Comps, Path, S), !,
    sym_alts(S, Alts0), ignore(M = M), Alts = Alts0.
path_alts(M, E, Field, Env, Alts) :-
    path_root(E, Root, Path0), memberchk(Root-X, Env), nonvar(X),
    ( X = '$ctx'(_) ; X = '$tuple'(_, _) ; X = '$sym'(_) ; X = '$alts'(_) ), !,
    append(Path0, [Field], Path), env_path(X, Path, M, Alts).
path_alts(M, E, Field, Env, Alts) :-
    logic_alts_ast(M, E, Env, EAs), EAs \== [],
    findall(A, ( member(a(G, T), EAs), nonvar(T), elem_field(T, Field, G, A) ), Alts),
    Alts \== [], !.
path_alts(_, E, F, _, _) :- throw(unsupported(path(E, F))).

%   The alternatives of a symbol reached by a path: a value's goal, a
%   relation as a whole, a structure as one.
sym_alts(val(F, _), [a([G], V)]) :- !, G =.. [F, V].
sym_alts(rel(F, Ns, Names), [a([], '$rel'(F, Ns, Names))]) :- !.
sym_alts(rel(F, Ns), [a([], '$rel'(F, Ns, [item]))]) :- !.
sym_alts(struct(Cs), [a([], '$struct'(Cs))]) :- !.

%   A path into a context the environment holds (a service's parameters),
%   or into an element of a list being walked.
env_path('$sym'('$struct'(Cs)), Path, _, Alts) :- !, comp_at(Cs, Path, S), sym_alts(S, Alts).
env_path('$sym'(R), [], _, [a([], R)]) :- !.
env_path('$alts'(As), [K], _, Alts) :- !,
    findall(A, ( member(a(G, T), As), nonvar(T), elem_field(T, K, G, A) ), Alts).
env_path('$ctx'(Cs), [K], _, Alts) :- !, ( memberchk(K-Alts0, Cs) -> Alts = Alts0 ; Alts = [] ).
env_path('$ctx'(Cs), [K|Ks], M, Alts) :- !, memberchk(K-[a([], X)], Cs), nonvar(X), env_path(X, Ks, M, Alts).
env_path('$tuple'(Names, Vars), [K], _, [a([], V)]) :- !, nth1(I, Names, K), nth1(I, Vars, V).

%   The field of an element value (an element of a relation being walked).
elem_field('$tuple'(Names, Vars), Field, G, a(G, V)) :- nth1(I, Names, Field), nth1(I, Vars, V).
elem_field('$elem'(Names, Vars), Field, G, a(G, V)) :- nth1(I, Names, Field), nth1(I, Vars, V).
elem_field('$stream'(Es), Field, G0, a(G, V)) :- member(a(G1, T), Es), nonvar(T), elem_field(T, Field, G1, a(G2, V)), append(G0, G2, G).
elem_field('$ctx'(Cs), Field, G0, a(G, V)) :- memberchk(Field-As, Cs), member(a(G1, V), As), append(G0, G1, G).
elem_field('$struct'(Cs), Field, G, a(GG, V)) :- memberchk(Field-val(F, _), Cs), C =.. [F, V], append(G, [C], GG).

path_root(name(N), N, []).
path_root(path(E, F), Root, Path) :- path_root(E, Root, P0), append(P0, [F], Path).

comp_at(Comps, [N], S) :- !, memberchk(N-S, Comps).
comp_at(Comps, [N|Ns], S) :- memberchk(N-struct(Cs), Comps), comp_at(Cs, Ns, S).

call_name_alts(M, F, Args, Env, Alts) :-
    service_named(M, F, SM, Svc), !,
    service_params(SM, Svc, PNs),
    (   maplist([pos(_)]>>true, Args) -> findall(P-literal_ast(A), ( nth1(I, Args, pos(A)), nth1(I, PNs, P) ), PLs)
    ;   findall(P-literal_ast(A), member(named(P, A), Args), PLs)
    ),
    service_alts(M, Env, SM, Svc, PLs, Alts).
call_name_alts(M, F, Args, Env, Alts) :-
    \+ sym(F, bkm(_, _)), bkm_named(M, F, BM, Params, Body), !,
    sub_atom(F, Dot, 1, _, '.'), Dot1 is Dot + 1, sub_atom(F, Dot1, _, 0, BN), note_inlined(BM, bkm, BN),
    findall(P, member(param(P, _), Params), PNs),
    (   maplist([pos(_)]>>true, Args) -> findall(P-literal_ast(A), ( nth1(K, Args, pos(A)), nth1(K, PNs, P) ), PLs)
    ;   findall(P-literal_ast(A), member(named(P, A), Args), PLs)
    ),
    findall(P-B, ( member(P, PNs), param_binding(M, Env, P, PLs, B) ), BEnv0),
    groundify(BEnv0, BEnv, Keys, Vars),
    BM = model(BI, _), memberchk(namespace(BNS), BI),
    with_scope(BNS, logic_alts(BM, Body, BEnv, Alts0)),
    bind_refs(Keys, Vars, Alts0, Alts).
call_name_alts(M, F, Args, Env, Alts) :-
    sym(F, bkm(BF, PNs)), !,
    (   maplist([pos(_)]>>true, Args), length(Args, NP), length(PNs, NP)
    ->  findall(A, member(pos(A), Args), Es)
    ;   findall(E, ( member(P, PNs), ( member(named(P, E), Args) -> true ; E = null ) ), Es)
    ),
    maplist(arg_alts(M, Env), Es, ArgAlts),
    call_alts(BF, ArgAlts, Alts).
call_name_alts(M, F, Args, Env, Alts) :-
    builtin_known(F), !,
    (   positional_args(F, Args, Pos)
    ->  (   memberchk(null, Pos) -> Alts = []          % FEEL: a null argument gives null
        ;   builtin_value(M, F, Pos, Env, Alts0) -> Alts = Alts0
        ;   Alts = []                               % wrong arguments: null, as FEEL has it
        )
    ;   Alts = []
    ).
call_name_alts(_, F, Args, _, _) :- throw(unsupported(call(F, Args))).

arg_alts(M, Env, E, As) :- logic_alts_ast(M, E, Env, As).

		 /*******************************
		 *   INLINED LOGIC, MARKED      *
		 *******************************/

%   The logic of an imported model (a decision service, a BKM) is copied
%   into the rules that use it: the twin stays one file, which File ▸ Open
%   needs. The copied rules are enclosed in a BEGIN and an END comment that
%   say what they copy, and suggest moving it to a file of its own,
%   included by this program (the DMN modeller's review, point 7).
note_inlined(model(I, _), Kind, Name) :-
    memberchk(namespace(NS), I),
    b_getval(dmn_root, Root), NS \== Root,
    nb_current(dmn_decision, d(D, _, _)), D \== none, !,
    ( memberchk(name(MN), I) -> true ; MN = NS ),
    ( loaded_file(NS, F) -> file_base_name(F, FB) ; FB = '' ),
    What = what(Kind, Name, MN, FB),
    ( inlined_use(D, What) -> true ; assertz(inlined_use(D, What)) ).
note_inlined(_, _, _).

%   The items emitted since the N0-th, for decision or service Name: when
%   they copy imported logic, the blocks already marked within them first
%   (a service function the decision reads), then the others between a
%   BEGIN and an END comment.
inlined_block(Name, Kind, N0) :-
    findall(W, inlined_use(Name, W), Ws), Ws \== [], !,
    findall(O, out(O), Os), length(Before, N0), append(Before, New, Os),
    nested_blocks(New, Nested, Rest),
    (   Rest == [] -> true
    ;   inlined_texts(Kind, Name, Ws, TB, TE),
        retractall(out(_)),
        append([Before, Nested, [block_begin(TB)], Rest, [block_end(TE)]], All),
        forall(member(O, All), assertz(out(O)))
    ).
inlined_block(_, _, _).

nested_blocks([], [], []).
nested_blocks([block_begin(T)|Os], Nested, Rest) :- !,
    block_tail(Os, 1, In, After),
    nested_blocks(After, N1, Rest),
    append([block_begin(T)|In], N1, Nested).
nested_blocks([O|Os], Nested, [O|Rest]) :- nested_blocks(Os, Nested, Rest).

%   The items up to the END that closes a BEGIN (blocks may nest).
block_tail([block_end(T)|Os], 1, [block_end(T)], Os) :- !.
block_tail([O|Os], D, [O|In], After) :-
    ( O = block_begin(_) -> D1 is D + 1 ; O = block_end(_) -> D1 is D - 1 ; D1 = D ),
    block_tail(Os, D1, In, After).

inlined_texts(Kind, Name, Ws, TB, TE) :-
    maplist(what_text, Ws, WTs), atomic_list_concat(WTs, '; ', WT),
    (   Kind == service
    ->  format(string(Lead), "BEGIN of inlined logic: the function of the decision service ~w, below, copies ~w.", [Name, WT])
    ;   format(string(Lead), "BEGIN of inlined logic: the rules of the decision ~w, below, copy ~w.", [Name, WT])
    ),
    wrap_words(Lead, 74, L1),
    wrap_words("The copy keeps this program in one file. You may want to move the copied logic to a separate file of its own, and include that file in this program and in the other programs that use it (\"the knowledge base ... includes these resources\").", 74, L2),
    format(string(TB), "~w~n~w", [L1, L2]),
    format(string(TE), "END of inlined logic (~w ~w).", [Kind, Name]).

what_text(what(service, N, MN, F), T) :- !, file_part(F, FP), format(string(T), "the decision service ~w of the imported model ~w~w", [N, MN, FP]).
what_text(what(bkm, N, MN, F), T) :- file_part(F, FP), format(string(T), "the business knowledge model ~w of the imported model ~w~w", [N, MN, FP]).

file_part('', '') :- !.
file_part(F, P) :- format(atom(P), " (~w)", [F]).

wrap_words(Text, W, Out) :-
    split_string(Text, " ", "", Words),
    wrap_(Words, W, "", [], Lines),
    atomic_list_concat(Lines, '\n', Out).
wrap_([], _, Cur, Acc, Lines) :- ( Cur == "" -> reverse(Acc, Lines) ; reverse([Cur|Acc], Lines) ).
wrap_([Wd|Ws], W, Cur, Acc, Lines) :-
    (   Cur == "" -> wrap_(Ws, W, Wd, Acc, Lines)
    ;   string_length(Cur, LC), string_length(Wd, LW), LC + 1 + LW =< W
    ->  string_concat(Cur, " ", C1), string_concat(C1, Wd, C2), wrap_(Ws, W, C2, Acc, Lines)
    ;   wrap_(Ws, W, Wd, [Cur|Acc], Lines)
    ).

block_item(block_begin(T), comment(T)) :- !.
block_item(block_end(T), comment(T)) :- !.
block_item(I, I).

		 /*******************************
		 *   SERVICES, ACROSS IMPORTS   *
		 *******************************/

%   A decision service, by the name the caller uses: `P.Service` of an
%   imported model, or a service of the model itself.
service_named(model(I, _), Name, SM, Svc) :-
    memberchk(namespace(NS), I),
    (   sub_atom(Name, B, 1, _, '.'), sub_atom(Name, 0, B, _, P), B1 is B + 1, sub_atom(Name, B1, _, 0, SN),
        import_prefix(NS, P, NS2), loaded(NS2, SM)
    ;   SN = Name, loaded(NS, SM)
    ),
    SM = model(_, Items), member(Svc, Items), Svc = service(_, SN, _, _, _, _), !.

%   A BKM of an imported model, by the name the caller uses (`Age.as of
%   date`, `BDT.spouse id`): it is inlined where it is invoked, its
%   parameters bound to the arguments.
bkm_named(model(I, _), Name, BM, Params, Body) :-
    memberchk(namespace(NS), I),
    sub_atom(Name, B, 1, _, '.'), sub_atom(Name, 0, B, _, P), B1 is B + 1, sub_atom(Name, B1, _, 0, BN),
    import_prefix(NS, P, NS2), loaded(NS2, BM), BM = model(_, Items),
    member(bkm(_, BN, Params, function(_, feel, Body), _), Items), !.

%   The parameters of a service: its input data, then its input decisions,
%   by name.
service_params(model(_, Items), service(_, _, _, _, ID, IN), PNs) :-
    findall(N, ( member(H, IN), dmn_href_id(H, Id), member(input(Id, N, _, _), Items) ), P1),
    findall(N, ( member(H, ID), dmn_href_id(H, Id), member(decision(Id, N, _, _, _, _), Items) ), P2),
    append(P1, P2, PNs).

%   A service invoked: its output decision computed in its own model, the
%   parameters bound to what the caller passes. The caller's own input
%   passed whole (`situation`) is that input there; a context written in
%   place is its entries; anything else, its value.
service_alts(CM, CEnv, SM, Svc, PLs, Alts) :-
    service_params(SM, Svc, PNs),
    findall(P-B, ( member(P, PNs), param_binding(CM, CEnv, P, PLs, B) ), SEnv0),
    (   \+ sub_term('$ref'(_), SEnv0),
        Svc = service(_, SN, [_], _, _, _)
    ->  %  invoked with the program's own inputs only: a function of the
        %  twin, written once, that each caller reads
        service_function(SN, SEnv0, CM, SM, Svc, F),
        G =.. [F, V], Alts = [a([G], V)]
    ;   service_alts_(SM, Svc, SEnv0, Alts)
    ).

:- dynamic service_fn/3.         % service name, its bindings (a variant), functor

%   A service invoked on the program's own inputs is a decision of the twin:
%   `the <service> result is *a value*`, its rules the service's logic with
%   the inputs bound as the caller binds them. Invoked again with the same
%   bindings, it is the same function.
service_function(SN, SEnv0, _CM, SM, Svc, F) :-
    copy_term(SEnv0, Key), numbervars(Key, 0, _),
    (   service_fn(SN, Key, F) -> true
    ;   aggregate_all(count, service_fn(SN, _, _), K),
        name_words(SN, Ws0), append(Ws0, [result], Ws1),
        ( K =:= 0 -> Ws = Ws1 ; number_word(K, NW0), K1 is K + 1, number_word(K1, NW), ignore(NW0 = NW0), append(Ws1, [NW], Ws) ),
        functor_of(Ws, F),
        service_output_noun(SM, Svc, Noun),
        value_template(Ws, Noun, Text),
        emit(function(F, Text)),
        assertz(sym('$service'(SN, Key), val(F, Noun))),
        assertz(service_fn(SN, Key, F)),
        nb_getval(dmn_decision, Saved), flag(dmn_rule_no, NSaved, NSaved),
        set_decision(SN, []),
        aggregate_all(count, out(_), N0),
        note_inlined(SM, service, SN),
        service_output_alts(SM, Svc, SEnv0, Alts0),
        value_rules(F, Alts0),
        nb_setval(dmn_decision, Saved), flag(dmn_rule_no, _, NSaved),
        inlined_block(SN, service, N0)
    ).

number_word(N, W) :- nth1(N, [one, two, three, four, five, six, seven, eight, nine, ten], W), !.
number_word(N, W) :- format(atom(W), 'number_~d', [N]).

service_output_noun(model(_, Items), service(_, _, [H], _, _, _), Noun) :-
    dmn_href_id(H, Id),
    (   member(decision(Id, _, T, _, _, _), Items), T \== '', catch(shape(T, value(Noun)), _, fail) -> true
    ;   Noun = value
    ).

%   The output decision of a service invoked on the program's own inputs:
%   its bindings are alternatives of their own (no reference to the
%   caller), so they need no grounding, and the contexts of its logic can
%   name their entries (context_alts/4).
service_output_alts(SM, Svc, SEnv, Alts) :-
    Svc = service(_, _, [H], _, _, _),
    SM = model(I, Items), memberchk(namespace(NS), I),
    dmn_href_id(H, Id), member(decision(Id, _, _, _, L, _), Items),
    with_scope(NS, logic_alts(SM, L, SEnv, Alts)).

service_alts_(SM, Svc, SEnv0, Alts) :-
    Svc = service(_, SN, _, _, _, _), note_inlined(SM, service, SN),
    groundify(SEnv0, SEnv, Keys, Vars),
    Svc = service(_, _, Outs, _, _, _),
    SM = model(I, Items), memberchk(namespace(NS), I),
    (   Outs = [H], dmn_href_id(H, Id), member(decision(Id, _, _, _, L, _), Items)
    ->  with_scope(NS, logic_alts(SM, L, SEnv, Alts0))
    ;   findall(DN-As, ( member(H, Outs), dmn_href_id(H, Id), member(decision(Id, DN, _, _, L, _), Items),
                         with_scope(NS, logic_alts(SM, L, SEnv, As)) ), Cs),
        Alts0 = [a([], '$ctx'(Cs))]
    ),
    bind_refs(Keys, Vars, Alts0, Alts).

param_binding(CM, CEnv, P, PLs, B) :-
    (   memberchk(P-X, PLs) -> true ; X = none ),
    (   X == none -> B = '$ctx'([])
    ;   ( X = literal(T0) -> feel_scope_parse(CM, CEnv, T0, AST0) ; X = literal_ast(AST0) -> true ; fail ),
        AST0 = path(_, _), catch(( logic_alts_ast(CM, AST0, CEnv, PAs__), PAs__ = [a([], S0)] ), _, fail), nonvar(S0),
        ( S0 = '$rel'(_, _, _) ; S0 = '$struct'(_) )
    ->  B = '$sym'(S0)
    ;   ( X = literal(T) -> feel_scope_parse(CM, CEnv, T, AST) ; X = literal_ast(AST) -> true ; AST = none ),
        AST = name(N), ( env_form(N, CEnv, '$alias'(G)) -> true ; \+ memberchk(N-_, CEnv), G = N ),
        sym(G, struct(_))
    ->  B = '$alias'(G)
    ;   X = context(Es)
    ->  findall(K-As, ( member(entry(K, L), Es), logic_alts(CM, L, CEnv, As) ), Cs), B = '$ctx'(Cs)
    ;   X = literal_ast(AST2)
    ->  logic_alts_ast(CM, AST2, CEnv, As), ( As = [a([], T)] -> B = T ; B = '$alts'(As) )
    ;   logic_alts(CM, X, CEnv, As), ( As = [a([], T)] -> B = T ; B = '$alts'(As) )
    ).

feel_scope_parse(M, Env, T, AST) :-
    model_scope(M, Ns0), pairs_keys(Env, ENs), append(ENs, Ns0, Ns), feel_parse(T, Ns, AST).

call_alts(F, ArgAlts, Alts) :-
    findall(a(G, V), ( pick_all(ArgAlts, Picks),
                       maplist([a(Gi, _), Gi]>>true, Picks, Gss), append(Gss, G0),
                       maplist([a(_, Ti), Ti]>>true, Picks, Ts),
                       append(Ts, [V], As), Goal =.. [F|As], append(G0, [Goal], G) ), Alts).

pick_all([], []).
pick_all([As|Ass], [P|Ps]) :- member(P, As), pick_all(Ass, Ps).

%   A built-in's arguments in the order of its parameters: positional, or
%   named by its parameters' names (DMN §10.3.4).
positional_args(_, Args, Pos) :- maplist([pos(A), A]>>true, Args, Pos), !.
positional_args(F, Args, Pos) :-
    builtin_params(F, Ps), length(Ps, N), length(Args, N),
    maplist(named_arg(Args), Ps, Pos).

named_arg(Args, P, A) :- memberchk(named(P, A), Args).

builtin_known(F) :- ( builtin_(F, _, _) ; builtin_params(F, _) ; memberchk(F, [not, all, any, contains, 'starts with', 'ends with', 'list contains', odd, even]) ), !.

builtin_params(decimal, [n, scale]).
builtin_params(floor, [n]).
builtin_params(ceiling, [n]).
builtin_params(abs, [n]).
builtin_params(modulo, [dividend, divisor]).
builtin_params(sqrt, [number]).
builtin_params('round up', [n, scale]).
builtin_params('round down', [n, scale]).
builtin_params('round half up', [n, scale]).
builtin_params('round half down', [n, scale]).
builtin_params('string length', [string]).
builtin_params('upper case', [string]).
builtin_params('lower case', [string]).
builtin_params(contains, [string, match]).
builtin_params('starts with', [string, match]).
builtin_params('ends with', [string, match]).
builtin_params('substring before', [string, match]).
builtin_params('substring after', [string, match]).
builtin_params(string, [from]).
builtin_params(count, [list]).
builtin_params('list contains', [list, element]).
builtin_params(reverse, [list]).
builtin_params(flatten, [list]).
builtin_params('distinct values', [list]).
builtin_params(product, [list]).
builtin_params(median, [list]).
builtin_params(sublist, ['list', 'start position']).
builtin_params(remove, [list, position]).
builtin_params('index of', [list, match]).
builtin_params(odd, [number]).
builtin_params(even, [number]).

%   The built-in functions with a value.
builtin_value(M, F, Args0, Env, Alts) :-
    varargs(F, Args0, Args),
    maplist(arg_alts(M, Env), Args, ArgAlts),
    length(ArgAlts, NA), builtin(F, NA, How),
    findall(a(G, T), ( pick_all(ArgAlts, Picks),
                       maplist([a(Gi, _), Gi]>>true, Picks, Gss), append(Gss, G0),
                       maplist([a(_, Ti), Ti]>>true, Picks, Ts),
                       builtin_term(How, Ts, G0, G, T) ), Alts).

builtin(F, N, How) :- builtin_(F, N0, How), N0 =:= N, !.

%   min, max, sum, mean, product, concatenate, union, append and string join
%   take their items one by one as well as in one list.
varargs(F, Args, [list(Args)]) :- memberchk(F, [min, max, sum, mean, product, median, concatenate, union]), Args = [_, _|_], !.
varargs(append, [L|Items], [L, list(Items)]) :- !.
varargs(_, Args, Args).

builtin_(floor, 1, arith(floor)).
builtin_(ceiling, 1, arith(ceiling)).
builtin_(floor, 2, lib(rounding, floor2)).
builtin_(ceiling, 2, lib(rounding, ceiling2)).
builtin_('round half up', 2, lib(rounding, half_up)).
builtin_('round up', 2, lib(feel, away)).
builtin_('round down', 2, lib(feel, toward)).
builtin_('round half down', 2, lib(feel, half_down)).
builtin_(abs, 1, arith(abs)).
builtin_(sqrt, 1, arith(sqrt)).
builtin_(exp, 1, arith(exp)).
builtin_(log, 1, arith(log)).
builtin_('substring before', 2, lib(feel, before)).
builtin_('substring after', 2, lib(feel, after)).
builtin_('string join', 1, lib(text, join)).
builtin_('string join', 2, lib(feel, join_with)).
builtin_(product, 1, lib(feel, product)).
builtin_(median, 1, lib(feel, median)).
builtin_(reverse, 1, lib(feel, reverse)).
builtin_('distinct values', 1, lib(feel, distinct)).
builtin_(flatten, 1, lib(feel, flatten)).
builtin_(concatenate, 1, lib(feel, concat)).
builtin_(union, 1, lib(feel, union)).
builtin_(append, 2, lib(feel, append)).
builtin_(sublist, 2, lib(feel, sublist2)).
builtin_(sublist, 3, lib(feel, sublist3)).
builtin_(remove, 2, lib(feel, remove)).
builtin_('insert before', 3, lib(feel, insert)).
builtin_('index of', 2, lib(feel, positions)).
builtin_(decimal, 2, lib(rounding, decimal)).
builtin_('string length', 1, lib(text, length)).
builtin_(string, 1, lib(text, text)).
builtin_(date, 1, date).
builtin_(count, 1, lib(feel, count)).
builtin_(sum, 1, lib(feel, sum)).
builtin_(min, 1, lib(feel, min)).
builtin_(max, 1, lib(feel, max)).
builtin_(mean, 1, lib(feel, mean)).
builtin_(today, 0, lib(feel, today)).
builtin_('upper case', 1, lib(feel, upper)).
builtin_('lower case', 1, lib(feel, lower)).
builtin_(substring, 2, lib(feel, substring2)).
builtin_(substring, 3, lib(feel, substring3)).
builtin_(modulo, 2, lib(feel, remainder)).
builtin_(number, 1, lib(feel, number)).

builtin_term(arith(Op), [X], G, G, T) :- T =.. [Op, X].
builtin_term(lib(feel, append), [L, Items], G0, G, V) :- !,
    use_lib(feel), append(G0, [feel_concat([L, Items], V)], G).
builtin_term(lib(feel, insert), [L, P, X], G0, G, V) :- !,
    use_lib(feel), append(G0, [feel_insert(L, X, P, V)], G).
builtin_term(lib(feel, positions), [L, X], G0, G, V) :- !,
    use_lib(feel), append(G0, [feel_positions(X, L, V)], G).
builtin_term(lib(L, Fn), Ts, G0, G, V) :-
    use_lib(L), lib_functor(Fn, F), append(Ts, [V], As), Goal =.. [F|As], append(G0, [Goal], G).
builtin_term(date, [S], G, G, D) :- string(S), date_literal(S, D).

use_lib(L) :- ( lib_used(L) -> true ; assertz(lib_used(L)), lib_templates(L) ).

lib_functor(decimal, feel_round_half_even).
lib_functor(floor2, feel_round_down).
lib_functor(ceiling2, feel_round_up).
lib_functor(half_up, feel_round_half_up).
lib_functor(away, feel_away).
lib_functor(toward, feel_toward).
lib_functor(half_down, feel_half_down).
lib_functor(before, feel_before).
lib_functor(after, feel_after).
lib_functor(join, feel_text_join).
lib_functor(join_with, feel_join_with).
lib_functor(product, feel_product).
lib_functor(median, feel_median).
lib_functor(reverse, feel_reverse).
lib_functor(distinct, feel_distinct).
lib_functor(flatten, feel_flatten).
lib_functor(concat, feel_concat).
lib_functor(union, feel_union).
lib_functor(append, feel_append2).
lib_functor(sublist2, feel_sublist2).
lib_functor(sublist3, feel_sublist3).
lib_functor(remove, feel_remove).
lib_functor(insert, feel_insert).
lib_functor(positions, feel_positions).
lib_functor(count, feel_count).
lib_functor(sum, feel_sum).
lib_functor(min, feel_min).
lib_functor(max, feel_max).
lib_functor(mean, feel_mean).
lib_functor(today, feel_today).
lib_functor(upper, feel_upper).
lib_functor(lower, feel_lower).
lib_functor(substring2, feel_substring2).
lib_functor(substring3, feel_substring3).
lib_functor(remainder, feel_remainder).
lib_functor(number, feel_number).
lib_functor(length, feel_text_length).
lib_functor(text, feel_text_of).

lib_templates(temporal) :-
    emit(template(feel_whole_years, "the number of whole years from *a date* to *a second date* is *a number*", [included])),
    emit(template(feel_whole_months, "the number of whole months from *a date* to *a second date* is *a number*", [included])),
    emit(template(feel_year_of, "the year of *a date* is *a number*", [included])),
    emit(template(feel_month_of, "the month of *a date* is *a number*", [included])),
    emit(template(feel_months_after, "*a later date* is *a number* calendar months after *a date*", [included])),
    emit(template(feel_months_before, "*an earlier date* is *a number* calendar months before *a date*", [included])).
lib_templates(feel) :-
    emit(template(feel_date_of_text, "the date written as *a text* is *a date*", [included])),
    emit(template(feel_day_of, "the day of the month of *a date* is *a number*", [included])),
    emit(template(feel_count, "the count of the list *a list* is *a number*", [included])),
    emit(template(feel_list_includes, "*a list* includes *a value*", [included])),
    emit(template(feel_today, "today is *a date*", [included])),
    emit(template(feel_date_of_parts, "the date of year *a number* month *a second number* day *a third number* is *a date*", [included])),
    emit(template(feel_sum, "the sum of the list *a list* is *a number*", [included])),
    emit(template(feel_min, "the minimum of the list *a list* is *a number*", [included])),
    emit(template(feel_max, "the maximum of the list *a list* is *a number*", [included])),
    emit(template(feel_mean, "the mean of the list *a list* is *a number*", [included])),
    emit(template(feel_upper, "the upper case of *a text* is *a second text*", [included])),
    emit(template(feel_lower, "the lower case of *a text* is *a second text*", [included])),
    emit(template(feel_substring2, "the substring of *a text* from position *a number* is *a part*", [included])),
    emit(template(feel_substring3, "the substring of *a text* from position *a number* with length *a count* is *a part*", [included])),
    emit(template(feel_remainder, "the remainder of *a number* divided by *a divisor* is *a result*", [included])),
    emit(template(feel_number, "the number written as *a text* is *a number*", [included])),
    emit(template(feel_item, "the item at position *a number* of the list *a list* is *a value*", [included])),
    emit(template(feel_away, "the rounding of *a number* away from zero to *a count* decimals is *a result*", [included])),
    emit(template(feel_toward, "the rounding of *a number* toward zero to *a count* decimals is *a result*", [included])),
    emit(template(feel_half_down, "the rounding of *a number* to *a count* decimals half toward zero is *a result*", [included])),
    emit(template(feel_before, "the part of *a text* before *a part* is *a second text*", [included])),
    emit(template(feel_after, "the part of *a text* after *a part* is *a second text*", [included])),
    emit(template(feel_join_with, "the joining of the list *a list* with *a delimiter* is *a text*", [included])),
    emit(template(feel_product, "the product of the list *a list* is *a number*", [included])),
    emit(template(feel_median, "the median of the list *a list* is *a number*", [included])),
    emit(template(feel_reverse, "the reverse of the list *a list* is *a second list*", [included])),
    emit(template(feel_distinct, "the list of the distinct values of *a list* is *a second list*", [included])),
    emit(template(feel_flatten, "the flattening of the list *a list* is *a second list*", [included])),
    emit(template(feel_concat, "the concatenation of the lists *a list* is *a second list*", [included])),
    emit(template(feel_union, "the union of the lists *a list* is *a second list*", [included])),
    emit(template(feel_sublist2, "the sublist of *a list* from position *a number* is *a second list*", [included])),
    emit(template(feel_sublist3, "the sublist of *a list* from position *a number* with length *a count* is *a second list*", [included])),
    emit(template(feel_remove, "the list *a list* without the item at position *a number* is *a second list*", [included])),
    emit(template(feel_insert, "the list *a list* with *a value* inserted at position *a number* is *a second list*", [included])),
    emit(template(feel_positions, "the list of the positions of *a value* in *a list* is *a second list*", [included])),
    emit(template(feel_all, "the conjunction of the list *a list* is *a truth value*", [included])),
    emit(template(feel_any, "the disjunction of the list *a list* is *a truth value*", [included])),
    emit(template(feel_odd, "*a number* is odd", [included])),
    emit(template(feel_even, "*a number* is even", [included])),
    emit(template(feel_list_includes, "*a list* includes *a value*", [included])).
lib_templates(maths) :-
    emit(template(feel_power, "the power of *a number* to *an exponent* is *a result*", [included])).
lib_templates(rounding) :-
    emit(template(feel_round_half_even, "the rounding of *a number* to *a count* decimals half even is *a result*", [included])),
    emit(template(feel_round_half_up, "the rounding of *a number* to *a count* decimals half up is *a result*", [included])),
    emit(template(feel_round_down, "the rounding of *a number* down to *a count* decimals is *a result*", [included])),
    emit(template(feel_round_up, "the rounding of *a number* up to *a count* decimals is *a result*", [included])).
lib_templates(text) :-
    emit(template(feel_text_length, "the length of *a text* is *a number*", [included])),
    emit(template(feel_text_of, "the text of *a value* is *a text*", [included])),
    emit(template(feel_text_join, "the joining of *a list* is *a text*", [included])),
    emit(template(feel_text_contains, "*a text* contains *a part*", [included])),
    emit(template(feel_text_ends, "*a text* ends with *a part*", [included])).

date_literal(S, date(Y, M, D)) :-
    atom_string(A, S), atomic_list_concat([Ys, Ms, Ds], '-', A),
    atom_length(Ys, 4), atom_length(Ms, 2), atom_length(Ds, 2),
    atom_number(Ys, Y), atom_number(Ms, M), atom_number(Ds, D),
    valid_date(Y, M, D).

%   A date FEEL accepts: a real day of a real month (date(2017, 2, 30) is
%   null).
valid_date(Y, M, D) :-
    integer(Y), integer(M), integer(D), M >= 1, M =< 12, D >= 1,
    (   M == 2 -> ( ( Y mod 4 =:= 0, ( Y mod 100 =\= 0 ; Y mod 400 =:= 0 ) ) -> L = 29 ; L = 28 )
    ;   memberchk(M, [4, 6, 9, 11]) -> L = 30
    ;   L = 31
    ),
    D =< L.

		 /*******************************
		 *      THREE-VALUED LOGIC      *
		 *******************************/

%!  holds(+Model, +AST, +Env, -Alts) is det.
%!  fails(+Model, +AST, +Env, -Alts) is det.
%
%   When a boolean expression is true, and when it is false, each as a
%   disjunction of conjunctions (lists of goals). Neither: null.
holds(_, bool(true), _, [[]]) :- !.
holds(_, bool(false), _, []) :- !.
holds(_, null, _, []) :- !.
holds(M, and(A, B), Env, Hs) :- !, holds(M, A, Env, HA), holds(M, B, Env, HB), product(HA, HB, Hs).
holds(M, or(A, B), Env, Hs) :- !, holds(M, A, Env, HA), holds(M, B, Env, HB), append(HA, HB, Hs).
holds(M, call(name(not), [pos(A)]), Env, Hs) :- !, fails(M, A, Env, Hs).
holds(M, cmp(Op, A, null), Env, Hs) :- !, null_test(M, Op, A, Env, Hs, _).
holds(M, cmp(Op, null, A), Env, Hs) :- !, null_test(M, Op, A, Env, Hs, _).
holds(M, cmp(Op, A, B), Env, Hs) :- !,
    logic_alts_ast(M, A, Env, AAs), logic_alts_ast(M, B, Env, BAs),
    findall(G, ( member(a(GA, TA0), AAs), member(a(GB, TB0), BAs),
                 comparable(TA0, TB0, TA, TB, GC),
                 compare_goal(Op, TA, TB, C), append([GA, GB, GC, [C]], G) ), Hs).
holds(M, between(X, L, H), Env, Hs) :- !,
    holds(M, and(cmp('>=', X, L), cmp('<=', X, H)), Env, Hs).
holds(M, in(X, Tests), Env, Hs) :- !,
    logic_alts_ast(M, X, Env, XAs), unary_holds(M, Tests, XAs, Hs).
holds(M, if(C, T, E), Env, Hs) :- !,
    holds(M, C, Env, HC), holds(M, T, Env, HT), holds(M, E, Env, HE),
    product(HC, HT, H1),
    ( HC == [] -> NotC = [[]] ; disj_body(HC, B), NotC = [[not(B)]] ),
    product(NotC, HE, H2), append(H1, H2, Hs).
holds(M, some([iter(V, Dom)], Cond), Env, Hs) :- !,
    logic_alts_ast(M, Dom, Env, DAs),
    findall(H, ( member(a(G0, D), DAs), domain_element(D, G0, X, G1),
                 element_ref(X, XR, Keys, Vals),
                 holds(M, Cond, [V-XR|Env], HC), member(H0, HC),
                 bind_refs(Keys, Vals, H0, H1), append(G1, H1, H) ), Hs).
holds(M, every([iter(V, Dom)], Cond), Env, [[not(B)]]) :- !,
    fails(M, some([iter(V, Dom)], call(name(not), [pos(Cond)])), Env, _),
    logic_alts_ast(M, Dom, Env, DAs),
    findall(F, ( member(a(G0, D), DAs), domain_element(D, G0, X, G1),
                 element_ref(X, XR, Keys, Vals),
                 fails(M, Cond, [V-XR|Env], FC), member(F0, FC),
                 bind_refs(Keys, Vals, F0, F1), append(G1, F1, F) ), Fs),
    ( Fs == [] -> B = false ; disj_body(Fs, B) ).
holds(M, call(name(all), [pos(L)]), Env, Hs) :-
    stream_alts(M, L, Env, Elems), !,
    findall(H, member(a(H, true), Elems), _),
    elems_truths(Elems, true, HLs), foldl([HL, A0, A]>>product(A0, HL, A), HLs, [[]], Hs).
holds(M, call(name(F), [pos(L)]), Env, Hs) :-
    memberchk(F-GF, [all-feel_all, any-feel_any]),
    \+ stream_alts(M, L, Env, _), !,
    logic_alts_ast(M, L, Env, LAs), use_lib(feel),
    findall(H, ( member(a(G, T), LAs), Goal =.. [GF, T, true], append(G, [Goal], H) ), Hs).
holds(M, call(name(any), [pos(L)]), Env, Hs) :-
    stream_alts(M, L, Env, Elems), !,
    elems_truths(Elems, true, HLs), append(HLs, Hs).
holds(M, call(name(F), Args), Env, Hs) :-
    findall(A, member(pos(A), Args), Pos), boolean_builtin(M, F, Pos, Env, true, Hs), !.
holds(M, E, Env, Hs) :-
    logic_alts_ast(M, E, Env, As),
    findall(G, ( member(a(G0, T), As), truth_goal(T, true, G0, G) ), Hs).

fails(_, bool(true), _, []) :- !.
fails(_, bool(false), _, [[]]) :- !.
fails(_, null, _, []) :- !.
fails(M, and(A, B), Env, Fs) :- !, fails(M, A, Env, FA), fails(M, B, Env, FB), append(FA, FB, Fs).
fails(M, or(A, B), Env, Fs) :- !, fails(M, A, Env, FA), fails(M, B, Env, FB), product(FA, FB, Fs).
fails(M, call(name(not), [pos(A)]), Env, Fs) :- !, holds(M, A, Env, Fs).
fails(M, cmp(Op, A, null), Env, Fs) :- !, null_test(M, Op, A, Env, _, Fs).
fails(M, cmp(Op, null, A), Env, Fs) :- !, null_test(M, Op, A, Env, _, Fs).
fails(M, cmp(Op, A, B), Env, Fs) :- !,
    negate_op(Op, NOp), holds(M, cmp(NOp, A, B), Env, Fs).
fails(M, between(X, L, H), Env, Fs) :- !,
    fails(M, and(cmp('>=', X, L), cmp('<=', X, H)), Env, Fs).
fails(M, in(X, Tests), Env, Fs) :- !,
    logic_alts_ast(M, X, Env, XAs), unary_fails(M, Tests, XAs, Fs).
fails(M, if(C, T, E), Env, Fs) :- !,
    holds(M, C, Env, HC), fails(M, T, Env, FT), fails(M, E, Env, FE),
    product(HC, FT, F1),
    ( HC == [] -> NotC = [[]] ; disj_body(HC, B), NotC = [[not(B)]] ),
    product(NotC, FE, F2), append(F1, F2, Fs).
fails(M, some(Its, Cond), Env, [[not(B)]]) :- !,
    holds(M, some(Its, Cond), Env, Hs), ( Hs == [] -> B = false ; disj_body(Hs, B) ).
fails(M, every([iter(V, Dom)], Cond), Env, Fs) :- !,
    logic_alts_ast(M, Dom, Env, DAs),
    findall(F, ( member(a(G0, D), DAs), domain_element(D, G0, X, G1),
                 element_ref(X, XR, Keys, Vals),
                 fails(M, Cond, [V-XR|Env], FC), member(F0, FC),
                 bind_refs(Keys, Vals, F0, F1), append(G1, F1, F) ), Fs).
fails(M, call(name(all), [pos(L)]), Env, Fs) :-
    stream_alts(M, L, Env, Elems), !,
    elems_truths(Elems, false, FLs), append(FLs, Fs).
fails(M, call(name(F), [pos(L)]), Env, Fs) :-
    memberchk(F-GF, [all-feel_all, any-feel_any]),
    \+ stream_alts(M, L, Env, _), !,
    logic_alts_ast(M, L, Env, LAs), use_lib(feel),
    findall(H, ( member(a(G, T), LAs), Goal =.. [GF, T, false], append(G, [Goal], H) ), Fs).
fails(M, call(name(any), [pos(L)]), Env, Fs) :-
    stream_alts(M, L, Env, Elems), !,
    elems_truths(Elems, false, FLs), foldl([FL, A0, A]>>product(A0, FL, A), FLs, [[]], Fs).
fails(M, call(name(F), Args), Env, Fs) :-
    findall(A, member(pos(A), Args), Pos), boolean_builtin(M, F, Pos, Env, false, Fs), !.
fails(M, E, Env, Fs) :-
    logic_alts_ast(M, E, Env, As),
    findall(G, ( member(a(G0, T), As), truth_goal(T, false, G0, G) ), Fs).

%   The elements of a list known when the program is written (the values
%   of a context's entries): each element's alternatives.
stream_alts(M, L, Env, Elems) :-
    logic_alts_ast(M, L, Env, SAs__), SAs__ = [a([], '$stream'(Es))],
    \+ ( member(a(G, _), Es), G \== [] ; true ), !,
    Elems = Es.
stream_alts(M, L, Env, Groups) :-
    logic_alts_ast(M, L, Env, SAs__), SAs__ = [a([], '$stream'(Es))], !,
    Groups = Es.

%   For each element, the goals under which it is the truth B.
elems_truths(Elems, B, Ls) :-
    findall(L, ( member(a(G, T), Elems), ( truth_goal(T, B, G, L0) -> L = [L0] ; L = [] ) ), Ls0),
    exclude(==([]), Ls0, Ls).

%   A value that is a truth: where its goal binds it, the goal with the
%   truth in its place.
truth_goal(T, B, G0, G) :-
    (   T == B -> G = G0
    ;   atom(T) -> fail
    ;   nonvar(T), T = '$ref'(_) -> append(G0, [T = B], G)
    ;   var(T) -> append(G0, [T = B], G)
    ;   fail
    ).

%   `x = null`: x has no value; `x != null`: it has one.
null_test(M, Op, A, Env, Hs, Fs) :-
    catch(logic_alts_ast(M, A, Env, As0), unsupported(value_of(_, S)), ( struct_leaves(S, As0) )),
    known_alts(As0, As),
    (   As = [a([], R)], nonvar(R), R = '$ref'(K) -> Known = ['$known'(K)]
    ;   As == [] -> Known = []
    ;   findall(B, ( member(a(G, _), As), conj(G, B0), copy_term(B0, B) ), Bs), Known = Bs
    ),
    (   Known == [] -> NotKnown = [[]], KnownAlts = []
    ;   disj(Known, KB), NotKnown = [[not(KB)]], findall([KG], member(KG, Known), KnownAlts)
    ),
    (   Op == '=' -> Hs = NotKnown, Fs = KnownAlts
    ;   Op == '!=' -> Hs = KnownAlts, Fs = NotKnown
    ;   Hs = [], Fs = []
    ).

%   Two durations compared as months; anything else as it is.
comparable(A, B, MA, MB, G) :-
    ( duration_value(A, MA, GA) ; MA = A, GA = [] ),
    ( duration_value(B, MB, GB) ; MB = B, GB = [] ), !,
    append(GA, GB, G).

duration_value(T, M, []) :- nonvar(T), T = '$ym'(M), !.
duration_value(T, M, [feel_whole_months(A, B, M)]) :- nonvar(T), T = '$between'(A, B), use_lib(temporal), !.

%   A structure has a value where some part of it has one.
struct_leaves(struct(Cs), As) :- findall(A, ( member(_-S, Cs), struct_leaves(S, As1), member(A, As1) ), As).
struct_leaves(val(F, _), [a([G], V)]) :- G =.. [F, V].
struct_leaves(rel(F, _, _), [a([LF], x)]) :- rel_listed(F, LF).
struct_leaves(rel(F, _), [a([LF], x)]) :- rel_listed(F, LF).

%   Alternatives whose value is a structure the environment holds count
%   as known with no goal of their own (a parameter context, a relation).
known_alts(As0, As) :-
    findall(a(G, T), ( member(a(G, T), As0) ), As1),
    (   As1 = [a([], T)], nonvar(T), T = '$struct'(Cs) -> struct_leaves(struct(Cs), As)
    ;   As1 = [a([], T)], nonvar(T), T = '$rel'(F, _, _), rel_listed(F, LF) -> As = [a([LF], x)]
    ;   As = As1
    ).

negate_op('=', '!='). negate_op('!=', '='). negate_op('<', '>='). negate_op('>=', '<').
negate_op('>', '<='). negate_op('<=', '>').

numeric_side(X) :- ( number(X) ; arith_term(X) ), !.

%   The value on the left, the formula on the right: the writer writes
%   `=:=` as LE's `=`, which is Prolog's is/2.
simple_first(A, B, G) :-
    (   ( arith_term(A) ; number(A) ), \+ arith_term(B), \+ number(B) -> G = (B =:= A)
    ;   G = (A =:= B)
    ).

%   Equality of numbers is arithmetic (3 = 3.0, floor(x) = x): `=:=`, which
%   the writer writes as LE's `=`, Prolog's is/2 for a bound value.
compare_goal('=', A, B, G) :- ( numeric_side(A) ; numeric_side(B) ), !, simple_first(A, B, G).
compare_goal('!=', A, B, not(G)) :- ( numeric_side(A) ; numeric_side(B) ), !, simple_first(A, B, G).
compare_goal('=', A, B, A = B).
compare_goal('!=', A, B, A \= B).
compare_goal('<', A, B, A < B).
compare_goal('<=', A, B, A =< B).
compare_goal('>', A, B, A > B).
compare_goal('>=', A, B, A >= B).

%   The boolean built-ins: true where …, false where ….
boolean_builtin(M, contains, [S, P], Env, Truth, Alts) :-
    use_lib(text),
    logic_alts_ast(M, S, Env, SAs), logic_alts_ast(M, P, Env, PAs),
    findall(G, ( member(a(GS, TS), SAs), member(a(GP, TP), PAs),
                 Goal = feel_text_contains(TS, TP),
                 ( Truth == true -> C = Goal ; C = not(Goal) ),
                 append([GS, GP, [C]], G) ), Alts).
boolean_builtin(M, F, Args, Env, Truth, Alts) :-
    memberchk(F-(GF/Lib), ['starts with'-(le_starts_with/none), 'list contains'-(feel_list_includes/feel),
                           odd-(feel_odd/feel), even-(feel_even/feel)]), !,
    ( Lib == none -> true ; use_lib(Lib) ),
    maplist(arg_alts(M, Env), Args, ArgAlts),
    findall(G, ( pick_all(ArgAlts, Picks), maplist([a(G1, _), G1]>>true, Picks, Gss), append(Gss, G0),
                 maplist([a(_, T1), T1]>>true, Picks, Ts), Goal =.. [GF|Ts],
                 ( Truth == true -> C = Goal ; C = not(Goal) ), append(G0, [C], G) ), Alts).
boolean_builtin(M, 'ends with', [S, P], Env, Truth, Alts) :-
    use_lib(text),
    logic_alts_ast(M, S, Env, SAs), logic_alts_ast(M, P, Env, PAs),
    findall(G, ( member(a(GS, TS), SAs), member(a(GP, TP), PAs),
                 Goal = feel_text_ends(TS, TP),
                 ( Truth == true -> C = Goal ; C = not(Goal) ),
                 append([GS, GP, [C]], G) ), Alts).

		 /*******************************
		 *          UNARY TESTS         *
		 *******************************/

%!  unary_holds(+Model, +Tests, +ValueAlts, -Alts) is det.
%
%   When the input value meets the cell. `-` holds whatever the value,
%   null too; `not(…)` holds where the tests fail or the value is null.
unary_holds(_, any, _, [[]]) :- !.
unary_holds(M, not(Ts), VAs, Hs) :- !, unary_fails_or_null(M, Ts, VAs, Hs).
unary_holds(M, Ts, VAs, Hs) :-
    findall(H, ( member(test(T), Ts), test_holds(M, T, VAs, H0), member(H, H0) ), Hs).

unary_fails(_, any, _, []) :- !.
unary_fails(M, not(Ts), VAs, Fs) :- !, unary_holds(M, Ts, VAs, Fs0),
    % not(…) is false where some test holds of a known value
    Fs = Fs0.
unary_fails(M, Ts, VAs, Fs) :-
    findall(FL, ( member(test(T), Ts), test_fails(M, T, VAs, FL) ), FLs),
    foldl([FL, A0, A]>>product(A0, FL, A), FLs, [[]], Fs).

%   not(tests): the value is null, or it is known and no test holds.
unary_fails_or_null(M, Ts, VAs, Hs) :-
    (   memberchk(test(eq(null)), Ts) -> NullPart = []
    ;   findall(B, ( member(a(G, _), VAs), conj(G, B) ), Bs),
        ( Bs == [] -> NullPart = [[]] ; disj(Bs, KB), NullPart = [[not(KB)]] )
    ),
    exclude(==(test(eq(null))), Ts, Ts1),
    (   Ts1 == [] -> KnownPart = findall_known(VAs)
    ;   unary_fails(M, Ts1, VAs, KnownPart)
    ),
    (   KnownPart = findall_known(As) -> findall(G, member(a(G, _), As), KP) ; KP = KnownPart ),
    append(NullPart, KP, Hs).

test_holds(_, eq(null), VAs, Hs) :- !,
    findall(B, ( member(a(G, _), VAs), conj(G, B) ), Bs),
    ( Bs == [] -> Hs = [[]] ; disj(Bs, KB), Hs = [[not(KB)]] ).
test_holds(M, eq(E), VAs, Hs) :- !,
    logic_alts_ast(M, E, [], EAs),
    findall(G, ( member(a(GV, TV), VAs), member(a(GE, TE), EAs),
                 equal_goal(TV, TE, C), append([GV, GE, C], G) ), Hs).
test_holds(M, cmp(Op, E), VAs, Hs) :- !,
    logic_alts_ast(M, E, [], EAs),
    findall(G, ( member(a(GV, TV), VAs), member(a(GE, TE), EAs),
                 compare_goal(Op, TV, TE, C), append([GV, GE, [C]], G) ), Hs).
test_holds(M, range(LI, A, B, HI), VAs, Hs) :- !,
    ( LI == true -> LO = '>=' ; LO = '>' ), ( HI == true -> HO = '<=' ; HO = '<' ),
    test_holds(M, cmp(LO, A), VAs, H1), test_holds(M, cmp(HO, B), VAs, H2),
    product(H1, H2, Hs0),
    maplist(dedupe_goals, Hs0, Hs).
%   A test over `?`: where the input has a value, `? = null` is false and
%   `?` is that value; where it has none, `?` is null (STTR's
%   `if ? = null then false else contains(?, "…")`).
test_holds(M, expr(E), VAs, Hs) :- !,
    q_known(E, EK), q_null_case(E, EN),
    holds(M, EK, ['?'-'$ref'('?')], H0),
    findall(H, ( member(a(GV, TV), VAs), member(H1r, H0), replace_ref('?', TV, H1r, H1), append(GV, H1, H) ), Hs1),
    holds(M, EN, [], HN),
    (   HN == [] -> Hs = Hs1
    ;   findall(B, ( member(a(G, _), VAs), conj(G, B) ), Bs),
        ( Bs == [] -> NotKnown = [] ; disj(Bs, KB), NotKnown = [not(KB)] ),
        findall(H, ( member(H2, HN), append(NotKnown, H2, H) ), Hs2),
        append(Hs1, Hs2, Hs)
    ).

%   The expression where `?` has a value, and where it is null, simplified.
q_known(E0, E) :- q_rewrite(known, E0, E1), feel_simplify(E1, E).
q_null_case(E0, E) :- q_rewrite(null, E0, E1), feel_simplify(E1, E).

q_rewrite(known, cmp('=', q, null), bool(false)) :- !.
q_rewrite(known, cmp('=', null, q), bool(false)) :- !.
q_rewrite(known, cmp('!=', q, null), bool(true)) :- !.
q_rewrite(known, cmp('!=', null, q), bool(true)) :- !.
q_rewrite(null, q, null) :- !.
q_rewrite(K, T0, T) :- compound(T0), !, T0 =.. [F|As0], maplist(q_rewrite(K), As0, As), T =.. [F|As].
q_rewrite(_, T, T).

%   Constant folding of what the rewriting leaves: null compared with
%   null, if over a constant, not/and/or of constants, a function of null.
feel_simplify(E0, E) :- compound(E0), \+ E0 = str(_), \+ E0 = num(_), !,
    E0 =.. [F|As0], maplist(feel_simplify_arg, As0, As), E1 =.. [F|As], fold(E1, E).
feel_simplify(E, E).

feel_simplify_arg(A0, A) :- is_list(A0), !, maplist(feel_simplify_arg, A0, A).
feel_simplify_arg(pos(A0), pos(A)) :- !, feel_simplify(A0, A).
feel_simplify_arg(A0, A) :- compound(A0), !, feel_simplify(A0, A).
feel_simplify_arg(A, A).

fold(cmp('=', null, null), bool(true)) :- !.
fold(cmp('!=', null, null), bool(false)) :- !.
fold(cmp(_, null, _), null) :- !.
fold(cmp(_, _, null), null) :- !.
fold(if(bool(true), T, _), T) :- !.
fold(if(bool(false), _, E), E) :- !.
fold(if(null, _, E), E) :- !.
fold(call(name(not), [pos(bool(B))]), bool(R)) :- !, ( B == true -> R = false ; R = true ).
fold(call(name(not), [pos(null)]), null) :- !.
fold(call(name(F), Args), null) :- F \== not, memberchk(pos(null), Args), !.
fold(and(bool(false), _), bool(false)) :- !.
fold(and(_, bool(false)), bool(false)) :- !.
fold(and(bool(true), X), X) :- !.
fold(and(X, bool(true)), X) :- !.
fold(or(bool(true), _), bool(true)) :- !.
fold(or(_, bool(true)), bool(true)) :- !.
fold(or(bool(false), X), X) :- !.
fold(or(X, bool(false)), X) :- !.
fold(E, E).

test_fails(_, eq(null), VAs, Fs) :- !,
    findall(G, member(a(G, _), VAs), Fs).
test_fails(M, eq(E), VAs, Fs) :- !,
    logic_alts_ast(M, E, [], EAs),
    findall(G, ( member(a(GV, TV), VAs), member(a(GE, TE), EAs),
                 unequal_goal(TV, TE, C), append([GV, GE, C], G) ), Fs).
test_fails(M, cmp(Op, E), VAs, Fs) :- !,
    negate_op(Op, NOp), test_holds(M, cmp(NOp, E), VAs, Fs).
test_fails(M, range(LI, A, B, HI), VAs, Fs) :- !,
    ( LI == true -> LO = '<' ; LO = '<=' ), ( HI == true -> HO = '>' ; HO = '>=' ),
    test_holds(M, cmp(LO, A), VAs, F1), test_holds(M, cmp(HO, B), VAs, F2), append(F1, F2, Fs).
test_fails(M, expr(E), VAs, Fs) :- !,
    q_known(E, EK), q_null_case(E, EN),
    fails(M, EK, ['?'-'$ref'('?')], F0),
    findall(F, ( member(a(GV, TV), VAs), member(F1r, F0), replace_ref('?', TV, F1r, F1), append(GV, F1, F) ), Fs1),
    fails(M, EN, [], FN),
    (   FN == [] -> Fs = Fs1
    ;   findall(B, ( member(a(G, _), VAs), conj(G, B) ), Bs),
        ( Bs == [] -> NotKnown = [] ; disj(Bs, KB), NotKnown = [not(KB)] ),
        findall(F, ( member(F2, FN), append(NotKnown, F2, F) ), Fs2),
        append(Fs1, Fs2, Fs)
    ).

%   Ground references for an element's variables, while the conditions over
%   it are compiled (findall/3 would copy the variables themselves).
ref_keys(Names, Keys, Refs) :-
    findall(K-'$ref'(K), ( member(_, Names), gensym('$fld_', K) ), KRs),
    pairs_keys_values(KRs, Keys, Refs).

bind_refs(Keys, Vals, T0, T) :-
    foldl([K, V, X0, X]>>( replace_ref(K, V, X0, X1), replace_marker('$known'(K), true, X1, X) ), Keys, Vals, T0, T).

element_ref(X, XR, Keys, Vars) :- groundify(X, XR, Keys, Vars).

%!  groundify(+Term, -Ground, -Keys, -Vars) is det.
%
%   Term with each of its variables replaced by a reference '$ref'(Key):
%   the environment a FEEL expression is compiled in holds no variable
%   findall/3 could copy apart from the goals that bind it. bind_refs/4
%   puts the variables back in the alternatives compiled.
groundify(X, XG, Keys, Vars) :-
    term_variables(X, Vars),
    findall(K, ( member(_, Vars), gensym('$v_', K) ), Keys),
    copy_term(X-Vars, XG-Copy),
    maplist([K, R]>>(R = '$ref'(K)), Keys, Copy).

%   An element of a relation: its tuple, under the goal that gives it.
relation_tuple('$rel'(F, _, Names), G0, Names, Vars, G) :- !,
    length(Names, N), length(Vars, N), Goal =.. [F|Vars], append(G0, [Goal], G).
relation_tuple('$elem'(Names, Vars), G, Names, Vars, G).

%   What a `for` walks: the elements of a relation, of a filter, or of a
%   context's entries.
domain_element('$rel'(F, Ns, Names), G0, '$tuple'(Names, Vars), G) :- !, relation_tuple('$rel'(F, Ns, Names), G0, Names, Vars, G).
domain_element('$elem'(Names, Vars), G, '$tuple'(Names, Vars), G) :- !.
domain_element('$entries'(Cs), G, '$ctx'([value-As]), G) :- !, member(_-S, Cs), sym_alts(S, As).
domain_element('$stream'(Es), G0, X, G) :- !, member(a(GE, X), Es), append(G0, GE, G).
domain_element(L, G, X, G) :- is_list(L), !, member(X, L).

%   An element of a stream (`(for … return …)[1]`): each solution is one,
%   and the first is taken as any (the ledger notes it).
stream_element(a(G0, '$stream'(Es)), a(G, T)) :- !, member(a(G1, T), Es), append(G0, G1, G).
stream_element(a(G, '$elem'(Names, Vars)), a(G, '$tuple'(Names, Vars))) :- !.
stream_element(A, A).

%   An equality the value can be bound by: a truth or a text in the
%   value's own place (`the answer is true`), a comparison otherwise.
equal_goal(TV, TE, []) :- var(TV), ( atom(TE) ; string(TE) ), !, TV = TE.
equal_goal(TV, TE, [TV = TE]).
unequal_goal(TV, TE, [TV \= TE]).

dedupe_goals(G0, G) :- list_to_set_eq(G0, G).
list_to_set_eq([], []).
list_to_set_eq([X|Xs], [X|Ys]) :- exclude(==(X), Xs, Xs1), list_to_set_eq(Xs1, Ys).

		 /*******************************
		 *            HELPERS           *
		 *******************************/

product(As, Bs, Ps) :- findall(P, ( member(A, As), member(B, Bs), append(A, B, P) ), Ps).

conj([], true) :- !.
conj([G], G) :- !.
conj(Gs, B) :- append(Init, [Last], Gs), conj(Init, B0), B = and(B0, Last).

disj([B], B) :- !.
disj([B|Bs], or(B, R)) :- disj(Bs, R).

disj_body(Hs, B) :- findall(C, ( member(H, Hs), conj(H, C) ), Cs), disj(Cs, B).

		 /*******************************
		 *             TESTS            *
		 *******************************/

%   A test case of the TCK as a source test: its inputs as facts, each
%   expected result as the answers of a query about that decision.
case_test(Doc, case(Id, Desc, Inputs, Results), test(Id, Doc, Loc, Facts, Expects)) :-
    ( Desc == '' -> format(atom(Loc), 'test case ~w', [Id]) ; format(atom(Loc), 'test case ~w (~w)', [Id, Desc]) ),
    findall(F, ( member(N-V, Inputs), value_facts(N, V, Fs), member(F, Fs) ), Facts),
    findall(E, ( member(result(N, _, V), Results), result_expects(N, V, E) ), Expects).

value_facts(N, V, Facts) :-
    (   fixed_sym(N) -> Facts = []
    ;   sym(N, S) -> sym_facts(S, V, Facts) ; Facts = [] ).

sym_facts(_, null, []) :- !.
sym_facts(val(F, _), v(X), [G]) :- !, le_value(X, LX), G =.. [F, LX].
sym_facts(val(F, _), list(Vs), [G]) :- !, maplist([v(X), Y]>>le_value(X, Y), Vs, L), G =.. [F, L].
sym_facts(struct(Comps), ctx(Cs), Facts) :- !,
    findall(F, ( member(CN-CV, Cs), memberchk(CN-CS, Comps), sym_facts(CS, CV, Fs), member(F, Fs) ), Facts).
sym_facts(rel(F, _), list(Vs), [L|Facts]) :- !,
    rel_listed(F, LF), L = LF,
    findall(G, ( member(v(X), Vs), le_value(X, LX), G =.. [F, LX] ), Facts).
sym_facts(rel(F, _, Names), list(Vs), [L|Facts]) :- !,
    rel_listed(F, LF), L = LF,
    findall(G, ( member(ctx(Cs), Vs), findall(LX, ( member(CN, Names), ( memberchk(CN-v(X), Cs) -> le_value(X, LX) ; LX = null ) ), Xs),
                 G =.. [F|Xs] ), Facts).
sym_facts(_, _, []).

le_value(X, Y) :- rational(X), !, number_of(X, Y).
le_value(X, X).

result_expects(N, V, Expect) :-
    sym(N, S),
    sym_expect(S, N, V, Expect).

sym_expect(val(F, _), _, V, expects(Q, Answers)) :- !,
    query_name(F, Q),
    (   V == null -> Answers = []
    ;   V = v(X) -> le_value(X, LX), G =.. [F, LX], Answers = [G]
    ;   V = list(Vs), maplist([v(X), Y]>>le_value(X, Y), Vs, L) -> G =.. [F, L], Answers = [G]
    ;   fail
    ).
sym_expect(struct(Comps), N, ctx(Cs), E) :- !,
    member(CN-CV, Cs), memberchk(CN-CS, Comps), sym_expect(CS, N, CV, E).
sym_expect(struct(Comps), N, null, E) :- !,
    member(_-CS, Comps), sym_expect(CS, N, null, E).
sym_expect(rel(F, _), _, V, expects(Q, Answers)) :- !,
    query_name(F, Q),
    (   V == null -> Answers = []
    ;   V = list(Vs) -> findall(G, ( member(v(X), Vs), le_value(X, LX), G =.. [F, LX] ), Gs0), msort(Gs0, Answers)
    ;   V = v(X) -> le_value(X, LX), G =.. [F, LX], Answers = [G]
    ).
sym_expect(rel(F, _, Names), _, V, expects(Q, Answers)) :- !,
    query_name(F, Q),
    (   V == null -> Answers = []
    ;   V = list(Vs) -> findall(G, ( member(ctx(Cs), Vs), findall(LX, ( member(CN, Names), memberchk(CN-v(X), Cs), le_value(X, LX) ), Xs),
                                      G =.. [F|Xs] ), Gs0), msort(Gs0, Answers)
    ;   V = ctx(Cs) -> findall(LX, ( member(CN, Names), memberchk(CN-v(X), Cs), le_value(X, LX) ), Xs), G =.. [F|Xs], Answers = [G]
    ).

query_name(F, Q) :- atom_concat(q_, F, Q).

test_query(Q, query(Q, Goal)) :-
    atom_concat(q_, F, Q),
    once(( sym(_, S), sym_functor_arity(S, F, A) )),
    functor(Goal, F, A).

sym_functor_arity(val(F, _), F, 1).
sym_functor_arity(rel(F, _), F, 1).
sym_functor_arity(rel(F, Ns, _), F, A) :- length(Ns, A).
sym_functor_arity(struct(Comps), F, A) :- member(_-S, Comps), sym_functor_arity(S, F, A).



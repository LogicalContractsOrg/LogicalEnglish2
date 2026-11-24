/** <module> Epilog -> Logical English: the twins of a ruleset or a game

    Phase 2d (the design notes roadmap.md §5.7, §8). Epilog (Stanford's
    Dynamic Logic Programming language, Sierra, EpilogJS) separates data,
    view definitions and operation definitions. Its sentences are read by
    epilog_syntax.pl (which reads the corpus as EpilogJS does) and written
    as Logical English; EpilogJS (epilog_reader.pl) is the oracle:

      - a *ruleset with a dataset* (the Examples page's theories): the view
        definitions are LE rules (LE2's core Prolog reader, le_writer:
        prolog_to_ir/3, with the built-ins mapped: same, distinct, leq,
        less, evaluate, mutex, countofall, member), the dataset a scenario,
        and each view relation a query whose expected answers are
        **EpilogJS's own** on the ruleset and dataset;
      - a *game* (the Games page: roles, `init`, `legal`, operation
        definitions `a :: cond ==> e1 & ~e2`, `goal`, `terminal`): Logical
        English for LPS. The relations an operation changes (and `init`
        sets) are fluents; the moves are actions; each operation rule is
        causal laws — an addition initiates, a `~` deletion terminates, the
        rule's conditions are the laws' — with the operations a move calls
        (`kerchunk`, `tick(X)`) inlined; the views over the state (`legal`,
        `goal`, `terminal`, `line`, ...) are intensional fluents; the static
        facts and rules (`index`, `succ`, `pace`) timeless. The initial state
        is the game's `init` as EpilogJS evaluates it; the scenario, a
        sequence of legal moves EpilogJS played (reproducibly chosen); the
        test, that LPS2's final state of the twin is EpilogJS's.

    Places are named after the unary relations that type them in the
    source (`index(M)`, `person(X)`, `role(R)`), since Epilog has no `#pred`:
    the naive wording is left to a wording pass (the assistant), as §5.7
    plans.
*/

:- module(epilog_twin, [
    theory_migration/3,     % +Id, +Options, -Migration
    game_migration/3,       % +Id, +Options, -Migration
    build_theory/3,         % +Id, +Options, -Report
    build_game/3,           % +Id, +Options, -Report
    game_run/3,             % +Library, +Options, -Run
    base_state_of/3         % +Run, +Fluents, -FinalState
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module(library(json)).
:- use_module(library(time)).
:- use_module(epilog_reader).
:- use_module(epilog_syntax).
:- use_module('../le2_paths').
:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).

		 /*******************************
		 *          BUILT-INS           *
		 *******************************/

%   An Epilog body literal as a Prolog goal le_writer's reader knows.
builtin_goal(same(X, Y), X = Y) :- !.
builtin_goal(distinct(X, Y), X \= Y) :- !.
builtin_goal(leq(X, Y), X =< Y) :- !.
builtin_goal(less(X, Y), X < Y) :- !.
builtin_goal(evaluate(E, V), G) :- !, arith(E, A, Pre), list_conj(Pre, P), ( P == true -> G = (V is A) ; G = (P, V is A) ).
builtin_goal(mutex(Xs), G) :- !, pairs_distinct([Xs], G).
builtin_goal(countofall(X, Goal, N), aggregate_all(count, G1, N)) :- !, ignore(X = X), body_goal(Goal, G1).
builtin_goal(G, G1) :- compound(G), G =.. [mutex|Xs], Xs = [_, _|_], !, pairs_distinct(Xs, G1).
builtin_goal(symless(X, Y), X @< Y) :- !.
builtin_goal(symleq(X, Y), X @=< Y) :- !.
builtin_goal(not(P), \+ G) :- !, body_goal(P, G).
builtin_goal(and(Ps), G) :- !, maplist(body_goal, Ps, Gs), list_conj(Gs, G).
builtin_goal(G, G1) :- compound(G), G =.. [or|Ps], Ps = [_, _|_], !, maplist(body_goal, Ps, Gs), list_disj(Gs, G1).

list_disj([G], G) :- !.
list_disj([G|Gs], (G ; R)) :- list_disj(Gs, R).

%   A body with a disjunction (`a | b`) as one body per disjunct.
body_alternative([], []).
body_alternative([L|Ls], Bs) :-
    (   compound(L), L =.. [or|Ds], Ds = [_, _|_]
    ->  member(D, Ds), ( D = and(As) -> true ; As = [D] ), append(As, Ls, Ls1), body_alternative(Ls1, Bs)
    ;   Bs = [L|Bs1], body_alternative(Ls, Bs1)
    ).

pairs_distinct(Xs, G) :-
    findall(X \= Y, ( append(_, [X|Rest], Xs), member(Y, Rest) ), Ds),
    list_conj(Ds, G).

%   Epilog's arithmetic functions (plus, times, minus, quotient, max, min)
%   as an expression.
arith(V, V, []) :- var(V), !.
arith(N, N, []) :- number(N), !.
arith(E, A, Pre) :- compound(E), E =.. [F|Args], memberchk(F-Op, [plus-(+), times-(*), minus-(-), quotient-(/)]), !,
    maplist(arith, Args, As, Pres), append(Pres, Pre0),
    As = [A0|Rest], op_fold(Rest, Op, A0, A1),
    ( F == minus, As = [_] -> A = -(A0) ; A = A1 ), Pre = Pre0.
arith(E, M, Pre) :- compound(E), E =.. [F, X, Y], memberchk(F, [max, min]), !,
    arith(X, XA, P1), arith(Y, YA, P2), M =.. [F, XA, YA], append(P1, P2, Pre).
arith(E, E, []).

op_fold([], _, A, A).
op_fold([X|Xs], Op, Acc, A) :- T =.. [Op, Acc, X], op_fold(Xs, Op, T, A).

body_goal(G, G1) :- builtin_goal(G, G1), !.
body_goal(G, G).

list_conj([], true) :- !.
list_conj([G], G) :- !.
list_conj([G|Gs], (G, R)) :- list_conj(Gs, R).

%   A clause for the reader: Head :- Body with the built-ins mapped, and
%   Epilog's lists (X!L, nil) as Prolog's. A proposition (`terminal`,
%   `open`) is wrapped as le_nullary(P) for the reader and unwrapped after
%   (see ir_of/3).
clause_of(rule(H, Bs), (H1 :- B)) :- !,
    lists_of(H, H0), wrap_nullary(H0, H1),
    %  symless and symleq (a symbol order LE has no form for) are dropped:
    %  approximated in the ledger (the view lists a pair in both orders)
    exclude(symbol_order, Bs, Bs0),
    maplist(lists_of, Bs0, Bs1), maplist(wrap_nullary, Bs1, Bs2),
    maplist(body_goal, Bs2, Gs0), maplist(conj_list, Gs0, Gss), append(Gss, Gs1),
    %  max and min in an evaluation: two clauses (LE has no max in expressions)
    unmax(Gs1, Gs), list_conj(Gs, B).
clause_of(fact(F), F1) :- lists_of(F, F0), wrap_nullary(F0, F1).

symbol_order(L) :- compound(L), functor(L, F, 2), memberchk(F, [symless, symleq]).

wrap_nullary(P, le_nullary(P)) :- atom(P), P \== true, !.
wrap_nullary(not(P), not(P1)) :- !, wrap_nullary(P, P1).
wrap_nullary(countofall(X, G, N), countofall(X, G1, N)) :- !, wrap_nullary(G, G1).
wrap_nullary(and(Ps), and(Ps1)) :- !, maplist(wrap_nullary, Ps, Ps1).
wrap_nullary(P, P1) :- compound(P), P =.. [or|Ps], Ps = [_, _|_], !, maplist(wrap_nullary, Ps, Ps1), P1 =.. [or|Ps1].
wrap_nullary(P, P).

%!  ir_of(+Terms, +Options, -IR) is det.
%
%   le_writer:prolog_to_ir/3 on the clauses, with the propositions
%   unwrapped and worded by their names. (The wrapping works around
%   le_writer's typed_by_annotation/5, which takes arg/3 of every literal of
%   a clause and so fails on a proposition beside a literal with a variable:
%   the core fix is in the phase report.)
ir_of(Terms, Options, program(H, Items)) :-
    prolog_to_ir(Terms, Options, program(H, Items0)),
    findall(P, ( member(T-_, Terms), sub_term(X, T), nonvar(X), X = le_nullary(P), atom(P) ), Ps0), sort(Ps0, Ps),
    findall(template(P/0, Text, [arity(0)]),
            ( member(P, Ps), atomic_list_concat(Ws, '_', P), atomic_list_concat(Ws, ' ', Text) ), PTs),
    exclude([I]>>( I = template(le_nullary/1, _, _) ), Items0, Items1),
    unwrap(Items1, Items2),
    exclude(typing_item, Items2, Items3),
    append(PTs, Items3, Items4),
    exclude(typing_item, Items4, Items).

unwrap(V, V) :- var(V), !.
unwrap(le_nullary(P), P) :- !.
unwrap(T, T1) :- compound(T), !, T =.. [F|As], maplist(unwrap, As, Bs), T1 =.. [F|Bs].
unwrap(T, T).

lists_of(V, V) :- var(V), !.
lists_of(nil, []) :- !.
lists_of(cons(H, T), [H1|T1]) :- !, lists_of(H, H1), lists_of(T, T1).
lists_of(T, T1) :- compound(T), !, T =.. [F|As], maplist(lists_of, As, Bs), T1 =.. [F|Bs].
lists_of(T, T).

		 /*******************************
		 *    WHAT LE CANNOT SAY        *
		 *******************************/

%!  unsupported_sentence(+Game, +Sentences, +Sentence, -Why) is semidet.
%
%   A sentence LE cannot state faithfully, and why: a functional term (an
%   LE place holds a constant, not `not(X)` or `cell(a,1)`), a call to a
%   function LE's arithmetic does not have (one defined with `:=`, or an
%   Epilog built-in such as `remainder`), a function definition itself.
%   Such a sentence is not translated but kept as a residue block. In a
%   game (Game == true) the GDL wrappers (`init(cell(1,1,b))`,
%   `legal(mark(M,N))`, ...) hold a literal, not a term.
unsupported_sentence(_, _, definition(H, _), definition(F/N)) :- !, functor(H, F, N).
unsupported_sentence(G, Ss, rule(H, Bs), Why) :- !,
    ( head_unsupported(G, Ss, H, Why) -> true ; member(B, Bs), lit_unsupported(G, Ss, B, Why) ), !.
unsupported_sentence(G, Ss, fact(F), Why) :- !, head_unsupported(G, Ss, F, Why).
unsupported_sentence(G, Ss, handler(A, C, E), Why) :-
    (   lit_unsupported(G, Ss, A, Why) -> true
    ;   member(P, [C, E]), cond_items([P], Ls), member(L, Ls), lit_unsupported(G, Ss, L, Why)
    ), !.

head_unsupported(G, Ss, H, Why) :- lit_unsupported(G, Ss, H, Why).

lit_unsupported(_, _, V, _) :- var(V), !, fail.
lit_unsupported(G, Ss, not(P), Why) :- !, lit_unsupported(G, Ss, P, Why).
lit_unsupported(G, Ss, and(Ps), Why) :- !, member(P, Ps), lit_unsupported(G, Ss, P, Why), !.
lit_unsupported(G, Ss, L, Why) :- compound(L), L =.. [or|Ps], Ps = [_, _|_], !,
    member(P, Ps), lit_unsupported(G, Ss, P, Why), !.
lit_unsupported(true, Ss, L, Why) :- compound(L), functor(L, F, N), gdl_wrapper(F/N, K), !,
    arg(K, L, X), lit_unsupported(true, Ss, X, Why).
lit_unsupported(G, Ss, countofall(_, P, N), Why) :- !,
    ( lit_unsupported(G, Ss, P, Why) -> true ; functional_arg(N, Why) ).
lit_unsupported(_, _, setofall(_, _, _), aggregate(setofall/3)) :- !.
lit_unsupported(_, Ss, evaluate(E, V), Why) :- !,
    ( expr_unsupported(Ss, E, Why) -> true ; functional_arg(V, Why) ).
lit_unsupported(_, _, L, Why) :- compound(L), !, L =.. [_|As], member(A, As), functional_arg(A, Why), !.

gdl_wrapper(init/1, 1).  gdl_wrapper(base/1, 1).  gdl_wrapper(action/1, 1).  gdl_wrapper(legal/1, 1).
gdl_wrapper(next/1, 1).  gdl_wrapper(true/1, 1).  gdl_wrapper(legal/2, 2).  gdl_wrapper(input/2, 2).
gdl_wrapper(does/2, 2).

%   An argument that is a term (not a list of constants).
functional_arg(A, _) :- \+ compound(A), !, fail.
functional_arg(cons(X, L), Why) :- !, ( functional_arg(X, Why) -> true ; functional_arg(L, Why) ).
functional_arg(A, functional(A)).

expr_unsupported(_, E, _) :- \+ compound(E), !, fail.
expr_unsupported(Ss, E, Why) :-
    E =.. [F|As], length(As, N),
    (   ( memberchk(F, [plus, times, minus, quotient]) ; N =:= 2, memberchk(F, [max, min]) )
    ->  member(A, As), expr_unsupported(Ss, A, Why), !
    ;   (   member(definition(D, _)-_, Ss), functor(D, F, N) -> Why = function(F/N, defined)
        ;   Why = function(F/N, builtin)
        )
    ).

why_text(definition(F/N), function_definition, Title, Note) :-
    format(string(Title), "the function definition ~w/~w (:=)", [F, N]),
    Note = "Logical English has no user-defined functions in expressions: the relations that call this function are residue too; restate it as a relation (`the F of X is Y if ...`) and call that".
why_text(functional(T), functional_term, Title, Note) :-
    epilog_term_text(T, TT),
    format(string(Title), "a sentence with the functional term ~w", [TT]),
    Note = "a Logical English place holds a constant, not a term (such as not(X), and(P,Q) or cell(a,1)): restate the term as a relation, or write it in an included Prolog resource".
why_text(function(F/N, defined), function_call, Title, Note) :-
    format(string(Title), "a sentence that calls the function ~w/~w", [F, N]),
    format(string(Note), "~w/~w is defined with := in the program, and Logical English has no user-defined functions in expressions", [F, N]).
why_text(function(F/N, builtin), function_call, Title, Note) :-
    format(string(Title), "a sentence that calls the Epilog function ~w/~w", [F, N]),
    format(string(Note), "Logical English's arithmetic has no form for Epilog's ~w/~w (only plus, times, minus, quotient, max and min are translated)", [F, N]).
why_text(aggregate(F/N), aggregate, Title, Note) :-
    format(string(Title), "a sentence with the aggregate ~w/~w", [F, N]),
    Note = "setofall builds a list of answers, which this translator does not map".

%!  residue_items(+Game, +Sentences, -Kept, -Residues) is det.
%
%   Sentences split into those translated and residue(Item, LedgerEntry)
%   pairs for the others, numbered per kind (`functional_term_1`, ...).
residue_items(Game, Ss, Kept, Residues) :-
    residue_items_(Ss, Game, Ss, [], Kept, Rs0),
    number_kinds(Rs0, [], Residues).

residue_items_([], _, _, _, [], []).
residue_items_([S-Bs|Ss], G, All, C, Kept, Rs) :-
    (   unsupported_sentence(G, All, S, Why0)
    ->  epilog_sentence_text(S-Bs, Text),
        named_copy(S-Why0, Bs, _-Why),
        why_text(Why, Kind, Title, Note),
        ( sentence_head(S, H) -> functor(H, F, N), Concl = [F], El0 = F/N ; Concl = [], El0 = none ),
        Rs = [r(Kind, Title, Note, Text, Concl, El0)|Rs1], Kept = Kept1
    ;   Kept = [S-Bs|Kept1], Rs = Rs1
    ),
    residue_items_(Ss, G, All, C, Kept1, Rs1).

sentence_head(rule(H, _), H).
sentence_head(fact(H), H).
sentence_head(handler(H, _, _), H).

number_kinds([], _, []).
number_kinds([r(Kind, Title, Note, Text, Concl, El)|Rs], Seen, [residue(Item, Entry)|Out]) :-
    aggregate_all(count, member(Kind, Seen), K0), K is K0 + 1,
    format(atom(Id), '~w_~w', [Kind, K]),
    Item = residue(Id, [title(Title), note(Note), source(epilog, Text), concludes(Concl)]),
    (   El = F/N -> format(string(E), "~w/~w: ~w", [F, N, Title]) ; format(string(E), "~w", [Title]) ),
    Entry = entry(E, Kind, residue, Note, Id, none),
    number_kinds(Rs, [Kind|Seen], Out).

%   Insert residue items before the first item of a kind (queries, the
%   initial state), or at the end.
insert_before(Items0, IsBefore, New, Items) :-
    (   append(Front, [I|Back], Items0), call(IsBefore, I)
    ->  append([Front, New, [I|Back]], Items)
    ;   append(Items0, New, Items)
    ), !.

%!  epilog_sentence_text(+Sentence-Bindings, -Text) is det.
%
%   A sentence in Epilog's own syntax, with its variables' names.
epilog_sentence_text(S0-Bs, Text) :-
    named_copy(S0, Bs, S),
    with_output_to(string(Text), write_sentence(S)).

%   A copy of a term with its variables named ('$VAR'(Name)) as in the source.
named_copy(T0, Bs, T) :-
    copy_term(T0-Bs, T-Bs1),
    maplist([N=V]>>( var(V) -> V = '$VAR'(N) ; true ), Bs1),
    numbervars(T, 0, _, [singletons(true)]).

epilog_term_text(T0, Text) :-
    copy_term(T0, T), numbervars(T, 0, _, [singletons(true)]),
    with_output_to(string(Text), write_ep(T)).

write_sentence(rule(H, Bs)) :- write_lit(H), write(' :- '), write_conj(Bs).
write_sentence(fact(F)) :- write_lit(F).
write_sentence(definition(H, E)) :- write_ep(H), write(' := '), write_ep(E).
write_sentence(handler(A, C, E)) :-
    write_lit(A), write(' :: '),
    ( C == true -> true ; write_part(C), write(' ==> ') ),
    write_part(E).

write_part(and(Ls)) :- !, write_conj(Ls).
write_part(P) :- write_lit(P).

write_conj([L]) :- !, write_lit(L).
write_conj([L|Ls]) :- write_lit(L), write(' & '), write_conj(Ls).

%   A literal: `~`, `&` and `|` are connectives here; in an argument, a term
%   not(X) or or(X,Y) is written as a term.
write_lit(not(P)) :- !, write('~'), write_lit(P).
write_lit(and(Ls)) :- is_list(Ls), !, write('('), write_conj(Ls), write(')').
write_lit(T) :- compound(T), T =.. [or|Ps], Ps = [_, _|_], !,
    write('('), write_disj(Ps), write(')').
write_lit(countofall(X, G, N)) :- !,
    write('countofall('), write_ep(X), write(','), write_part(G), write(','), write_ep(N), write(')').
write_lit(T) :- write_ep(T).

write_disj([P]) :- !, write_part(P).
write_disj([P|Ps]) :- write_part(P), write(' | '), write_disj(Ps).

write_ep('$VAR'(N)) :- !, ( atom(N) -> write(N) ; print('$VAR'(N)) ).
write_ep(nil) :- !, write(nil).
write_ep(cons(X, L)) :- !, write_ep(X), write('!'), write_ep(L).
write_ep(and(Ls)) :- is_list(Ls), !, T =.. [and|Ls], write_ep(T).
write_ep(S) :- string(S), !, format('"~w"', [S]).
write_ep(T) :- compound(T), !,
    T =.. [F|As], write(F), write('('), write_args(As), write(')').
write_ep(T) :- write(T).

write_args([A]) :- !, write_ep(A).
write_args([A|As]) :- write_ep(A), write(','), write_args(As).

		 /*******************************
		 *     TYPES FROM THE SOURCE    *
		 *******************************/

%   A variable is typed by a unary relation that holds of it in the same
%   sentence (`index(M)`, `person(X)`): its name becomes that relation's
%   (Index, Person), which is what the reader names places after. Unary
%   relations with facts only (static types) qualify.
type_relations(Sentences, Types) :-
    findall(T, ( member(fact(F)-_, Sentences), compound(F), functor(F, T, 1), \+ gdl_meta(T) ), Ts0),
    sort(Ts0, Types).

gdl_meta(T) :- memberchk(T, [base, action, init, input, legal, goal, terminal, next, does, true]).

rename_by_type(Types, S-Bs, S-Bs1) :-
    typed_vars(S, Types, [], VTs),
    foldl(type_name(VTs), Bs, []-[], _-Bs1r), reverse(Bs1r, Bs1).

%   (a walk, not findall: the variables must stay the sentence's own)
typed_vars(V, _, Acc, Acc) :- var(V), !.
typed_vars(L, Types, Acc, [V-T|Acc1]) :-
    compound(L), functor(L, T, 1), memberchk(T, Types), arg(1, L, V), var(V), !,
    Acc1 = Acc.
typed_vars(L, Types, Acc0, Acc) :- compound(L), !, L =.. [_|As], typed_vars_list(As, Types, Acc0, Acc).
typed_vars(_, _, Acc, Acc).

typed_vars_list([], _, Acc, Acc).
typed_vars_list([A|As], Types, Acc0, Acc) :- typed_vars(A, Types, Acc0, Acc1), typed_vars_list(As, Types, Acc1, Acc).

type_name(VTs, N=V, Used-Acc, Used1-[N1=V|Acc]) :-
    (   member(V0-T, VTs), V0 == V
    ->  sub_atom(T, 0, 1, _, C), sub_atom(T, 1, _, 0, Rest), upcase_atom(C, U), atom_concat(U, Rest, Base),
        aggregate_all(count, member(Base, Used), K),
        ( K =:= 0 -> N1 = Base ; K1 is K + 1, format(atom(N1), '~w~w', [Base, K1]) ),
        Used1 = [Base|Used]
    ;   N1 = N, Used1 = Used
    ).

%   Clauses that only name places (`p(X, Y) :- typing`, dropped from the
%   program: a head, so that a relation named like a Prolog built-in, succ
%   or plus, gets its template too): the terms `base` and `action` declare,
%   with their variables typed (`action(mark(M,N)) :- index(M) & index(N)`
%   names mark's places after index).
typing_clauses(Ss, Clauses) :-
    findall((G :- le_nullary(typing))-Bs,
            ( member(S-Bs, Ss), ( S = rule(D, _) ; S = fact(D) ), compound(D), functor(D, DF, 1),
              memberchk(DF, [base, action, input]), arg(1, D, G0), compound(G0), lists_of(G0, G) ),
            Clauses).

		 /*******************************
		 *     A RULESET AND DATASET    *
		 *******************************/

%!  theory_migration(+Id, +Options, -Migration) is det.
%
%   Options: rules(File), data(File), title(T), source(Doc, Url),
%   oracle(false) (no EpilogJS: the queries get no expected answers).
theory_migration(Id, Options, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    %  rules(none): a data sheet with no rule sheet (the Examples page's Base)
    option(rules(RF0), Options),
    (   RF0 == none
    ->  RS = [], tmp_empty(RF)
    ;   RF = RF0, epilog_file_sentences(RF, RS)
    ),
    (   option(data(DF), Options), exists_file(DF), size_file(DF, Sz), Sz > 0
    ->  epilog_file_sentences(DF, DS0)
    ;   DS0 = [], DF = none
    ),
    %  what LE cannot say (functional terms, functions): residue blocks
    append(RS, DS0, All0),
    residue_items(false, RS, RSKept, RRes),
    residue_items(false, DS0, DS, DRes),
    append(RRes, DRes, Res0),
    append(RSKept, DS, All),
    type_relations(All, Types),
    maplist(rename_by_type(Types), RSKept, RS1),
    findall(S-(C-Bs), ( member(S-Bs, RS1), clause_of(S, C) ), SClauses),
    pairs_values(SClauses, Clauses),
    findall(F, ( member(fact(F0)-_, DS), lists_of(F0, F) ), Data),
    %  the views: the relations rules define (not the data's, not facts only);
    %  a dataset with no rules (the Examples page's Base) is queried by its
    %  own relations
    findall(F/N, ( member(rule(H, _)-_, RS), functor(H, F, N) ), Vs0),
    (   Vs0 == []
    ->  findall(F/N, ( member(G, Data), functor(G, F, N) ), Vs1)
    ;   Vs1 = Vs0
    ),
    sort(Vs1, Views),
    findall(Q-G, ( member(F/N, Views), functor(G, F, N), atom_concat(F, '', Q) ), Queries),
    %  typing clauses: the data's relations with their places typed from use,
    %  and the relations only residue sentences state
    findall(G, ( ( member(G0, Data) ; member(S-_, All0), sentence_head(S, G0), \+ S = handler(_, _, _) ),
                 compound_or_atom(G0), functor(G0, F, N),
                 \+ ( member(C0-_, Clauses), clause_head_fn(C0, F, N) ), functor(G, F, N) ), TG0),
    sort(TG0, TG),
    findall((G1 :- le_nullary(typing))-[], ( member(G, TG), wrap_nullary(G, G1) ), Typing),
    append(Clauses, Typing, Terms0),
    ir_of(Terms0, [kb(Id), queries(Queries)], program(Header0, Items0)),
    exclude(typing_item, Items0, Items1a),
    %  the reader's list-pattern residue blocks, with the Epilog sentence
    list_pattern_residues(SClauses, Items1a, Items1, LRes),
    option(title(Title), Options, Id),
    ( DF == none -> DB = none ; file_base_name(DF, DB) ),
    ( RF0 == none -> RB = DB, DB1 = none ; file_base_name(RF, RB), DB1 = DB ),
    header_comment(Title, Options, RB, DB1, HC),
    select(comment(_), Header0, Header1), Header = [comment(HC)|Header1],
    format(atom(RT), 'sources/~w', [RB]),
    Docs = [document('the ruleset', [text(RT)])],
    findall(I, member(residue(I, _), Res0), ResItems),
    insert_before(Items1, [I]>>(I = query(_, _)), ResItems, Items1b),
    append(Docs, Items1b, Items2),
    unclash_items(Items2, Items),
    %  the test: EpilogJS's answers to every view query on the dataset
    (   option(oracle(false), Options)
    ->  findall(V-unchecked, member(V, Views), Answers)
    ;   theory_answers(RF, DF, Views, Answers)
    ),
    theory_tests(Answers, Data, Tests),
    findall(E, member(residue(_, E), Res0), REntries),
    append(REntries, LRes, ResidueEntries),
    ledger_theory(RS, Answers, ResidueEntries, Ledger),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    exclude(==(none), [RB, DB1], Arts),
    Meta = [program(Id), source('an Epilog ruleset'), artifacts(Arts),
            translator('LE2 migration/epilog (epilog_twin.pl)'), date(Date)].

%   le_writer makes a clause that takes a list apart a residue block
%   (list_pattern_K, in the order of the clauses): its source becomes the
%   Epilog sentence, and it gets a ledger entry.
list_pattern_residues(SClauses, Items0, Items, Entries) :-
    findall(S-Bs, ( member(S-(C-Bs), SClauses), le_writer:partial_list_clause(C) ), Ps),
    list_pattern_items(Items0, Ps, Items, Entries).

list_pattern_items([], _, [], []).
list_pattern_items([residue(Id, Opts0)|Is], [S-Bs|Ps], [residue(Id, Opts)|Os], [Entry|Es]) :-
    sub_atom(Id, 0, _, _, list_pattern_), !,
    epilog_sentence_text(S-Bs, Text),
    option(note(Note), Opts0, ''),
    ( sentence_head(S, H) -> functor(H, F, N), Concl = [F] ; F = '?', N = '?', Concl = [] ),
    Opts = [title("a clause that takes a list apart"), note(Note), source(epilog, Text), concludes(Concl)],
    format(string(E), "~w/~w: a clause that takes a list apart", [F, N]),
    Entry = entry(E, list_pattern, residue, 'LE has no list patterns (X!L in a head): a residue block', Id, none),
    list_pattern_items(Is, Ps, Os, Es).
list_pattern_items([I|Is], Ps, [I|Os], Es) :- list_pattern_items(Is, Ps, Os, Es).

clause_head_fn((H :- _), F, N) :- !, functor(H, F, N).
clause_head_fn(H, F, N) :- functor(H, F, N).

typing_item(rule(typing, _, _)).
typing_item(rule(_, typing, _)).
typing_item(template(typing/0, _, _)).
typing_item(query(typing, _)).

header_comment(Title, Options, RB, DB, HC) :-
    ( option(source(Doc, Url), Options) -> format(string(Src), "~nSource: ~w, ~w", [Doc, Url]) ; Src = "" ),
    ( DB == none -> DS = "" ; format(string(DS), " and ~w", [DB]) ),
    (   option(oracle(false), Options)
    ->  Exp = "Its queries have no expected\nanswers: compare a few with Epilog's, and add them to a scenario (`expects answers`)."
    ;   Exp = "Every expected answer is\nEpilogJS's own (Stanford's Epilog interpreter) on the same ruleset and dataset."
    ),
    format(string(HC), "~w~n~nThe Logical English twin of an Epilog ruleset, written by the Epilog translator~nfrom ~w~w (kept in sources/). ~w~w",
           [Title, RB, DS, Exp, Src]).

%   EpilogJS's answers to each view's open query on the dataset, one
%   EpilogJS run per query (an open query over an infinite relation —
%   lists, sets — runs out of stack or time: that view gets no expectation).
theory_answers(RF, DF, Views, Answers) :-
    ( DF == none -> tmp_empty(DF1) ; DF1 = DF ),
    findall(F/N-A, ( member(F/N, Views), view_answers(RF, DF1, F/N, A) ), Answers).

view_answers(RF, DF, F/N, A) :-
    functor(G, F, N), numbervars(G, 0, _), goal_text(G, Text),
    catch(( epilog_node([query, DF, RF, Text], [R], [timeout(30)]),
            (   get_dict(terms, R, Ts)
            ->  findall(T, ( member(J, Ts), json_term(J, T0, _), lists_of(T0, T) ), As0),
                (   forall(member(T, As0), ground(T)) -> sort(As0, As), A = answers(As)
                ;   A = none("EpilogJS's answers to the open query are not ground (an infinite relation)")
                )
            ;   A = none("EpilogJS runs out of stack on the open query")
            ) ),
          error(epilog_tool_timeout(_, S), _),
          format(string(W), "EpilogJS does not answer the open query in ~w s", [S]) ),
    ( var(A) -> A = none(W) ; true ).

theory_tests(Answers, Data, Tests) :-
    findall(expects(F, As), member(F/_-answers(As), Answers), Expects),
    (   Data == [], Expects == [] -> Tests = []
    ;   Tests = [test(dataset, 'the dataset', none, Data, Expects)]
    ).

goal_text(G, T) :- format(atom(T), '~W', [G, [numbervars(true), quoted(false), ignore_ops(true)]]).

tmp_empty(F) :- tmp_file_stream(text, F, S), close(S).

%   A view whose sentences are all residue has no entry of its own (its
%   residue entries stand for it); one with some residue is approximated.
ledger_theory(RS, Answers, Residues, Ledger) :-
    findall(entry(E, view, St, Note, F, none),
            ( member(F/N-A, Answers), format(string(E), "~w/~w", [F, N]),
              view_residue(RS, Residues, F/N, Total, RIds),
              length(RIds, NR), NR < Total,
              (   A = answers(_) -> St0 = encoded, Note0 = 'a view definition -> an LE rule (naive wording); its query expects EpilogJS\'s answers'
              ;   A == unchecked -> St0 = encoded, Note0 = 'a view definition -> an LE rule (naive wording)'
              ;   A = none(Why), St0 = approximated,
                  format(atom(Note0), 'a view definition -> an LE rule (naive wording); no expected answers: ~w', [Why])
              ),
              (   NR =:= 0 -> St = St0, Note = Note0
              ;   St = approximated, atomic_list_concat(RIds, ', ', IdsA),
                  format(atom(Note), '~w; ~w of its ~w sentence(s) are residue (~w)', [Note0, NR, Total, IdsA])
              ) ),
            L1),
    findall(entry(E, operation, residue, 'an operation definition in a ruleset: open the file as a game (LE for LPS) to translate it', none, none),
            ( member(handler(A0, _, _)-_, RS), functor(A0, F, N), format(string(E), "~w/~w (operation)", [F, N]) ), L0),
    findall(F/N, member(F/N-_, Answers), Vs),
    aggregate_all(count, ( member(fact(Fa)-_, RS), functor(Fa, F, N), \+ memberchk(F/N, Vs),
                           \+ unsupported_sentence(false, RS, fact(Fa), _) ), NF),
    ( NF > 0 -> format(string(E2), "~w fact(s) of the ruleset", [NF]), L2 = [entry(E2, facts, encoded, 'facts -> LE facts', 'the program', none)] ; L2 = [] ),
    symbol_order_entries(RS, L3),
    append([L1, L2, L3, L0, Residues], Ledger).

symbol_order_entries(Ss, Entries) :-
    findall(entry(E, 'built-in', approximated, Note, F, none),
            ( member(rule(H, B)-_, Ss), \+ gdl_meta_head(H), member(S, [symless, symleq]), \+ \+ ( member(L, B), functor(L, S, 2) ),
              \+ unsupported_sentence(false, Ss, rule(H, B), _),
              functor(H, F, N), format(string(E), "~w in ~w/~w", [S, F, N]),
              format(atom(Note), '~w (a symbol order, to list a pair once) has no LE form: dropped, the view lists both orders', [S]) ),
            Entries0),
    list_to_set(Entries0, Entries).

%   The sentences of a view in the ruleset, and the residue blocks among them.
view_residue(RS, Residues, F/N, Total, Ids) :-
    aggregate_all(count, ( member(S-_, RS), sentence_head(S, H), \+ S = handler(_, _, _), functor(H, F, N) ), Total),
    format(string(Pre), "~w/~w: ", [F, N]),
    findall(Id, ( member(entry(E, _, residue, _, Id, _), Residues), sub_string(E, 0, _, _, Pre) ), Ids).

		 /*******************************
		 *            A GAME            *
		 *******************************/

%!  game_run(+Library, +Options, -Run) is det.
%
%   EpilogJS plays the game: Options moves(N) (default 12), seed(S).
%   A program with operations but no game rules: data(File), the state it
%   starts in, and operations([Op, ...]), applied in turn.
game_run(Lib, Options, Run) :-
    option(moves(N), Options, 12), option(seed(S), Options, 0),
    ( option(data(D), Options) -> Env = ['EPILOG_DATA'=D] ; Env = [] ),
    option(operations(Ops), Options, []),
    epilog_node([game, Lib|Ops], Run, [env(['EPILOG_MOVES'=N, 'EPILOG_SEED'=S|Env])]).

%!  game_migration(+Id, +Options, -Migration) is det.
%
%   Options: library(File), title(T), source(Doc, Url), run(Run)
%   (EpilogJS's play, game_run/3: the initial state and the scenario; without
%   it, Prolog evaluates init and there is no scenario).
game_migration(Id, Options, migration(Meta, program(Header, Items), Ledger, [])) :-
    option(library(Lib), Options),
    epilog_file_sentences(Lib, SsAll0),
    maplist(undot_sentence, SsAll0, SsAll),
    %  what LE cannot say (functional terms, functions): residue blocks
    residue_items(true, SsAll, Ss00, Res0),
    maplist(gdl_rename, Ss00, Ss0),
    type_relations(Ss0, Types),
    maplist(rename_by_type(Types), Ss0, Ss),
    ( option(run(Run), Options) -> true ; Run = none ),
    findall(h(A, C, E), member(handler(A, C, E)-_, Ss), Hs),
    findall(F, ( member(h(_, _, E), Hs), effect_literal(E, L), functor(L, F, _), \+ handler_head(Hs, L) ), EF),
    %  the initial state: EpilogJS's evaluation of init (the build), or
    %  Prolog's (File > Open, with no EpilogJS); a program with no init
    %  starts from its facts of the relations the operations change
    (   Run \== none
    ->  Run.steps = [Step0|_],
        findall(F, ( member(T, Step0.terms), json_term(T, F00, _), undot(F00, F0), lists_of(F0, F) ), Init0),
        %  a state fact holding a term (skirmish's location(cell(a,1), ...))
        partition([F]>>( \+ lit_unsupported(false, [], F, _) ), Init0, Init, InitTerms),
        findall(F, ( member(J, Run.steps), member(T, J.terms), json_term(T, F0, _), functor(F0, F, _) ), IF)
    ;   prolog_init(Ss00, EF, Init0),
        partition([F]>>( \+ lit_unsupported(false, [], F, _) ), Init0, Init, InitTerms),
        findall(F, ( member(T, Init), functor(T, F, _) ), IF)
    ),
    %  the state: init's relations and the operations' effects
    append(IF, EF, Fl0), sort(Fl0, FluentNames),
    findall(F/N, ( member(S-_, Ss), sub_term(L, S), compound(L), functor(L, F, N), memberchk(F, FluentNames) ), FA0),
    findall(F/0, ( member(F, FluentNames), \+ memberchk(F/_, FA0) ), FA1),
    append(FA0, FA1, FA2), sort(FA2, Fluents),
    %  moves: handlers no other handler calls, and the operations the game
    %  declares as actions or legal, or EpilogJS played (kono's `kerchunk`
    %  is a move and a sub-operation of the others)
    (   Run == none -> Played0 = []
    ;   findall(M, ( member(St, Run.steps), get_dict(moveterm, St, MT), MT \== null, json_term(MT, M0, _), undot(M0, M) ), Played0)
    ),
    findall(F/N, ( ( member(fact(D)-_, Ss00) ; member(rule(D, _)-_, Ss00) ), compound(D), D =.. [DF, X],
                   memberchk(DF, [action, legal]), compound_or_atom(X), functor(X, F, N)
                 ; member(X, Played0), functor(X, F, N) ), Declared),
    findall(M, ( member(h(A, _, _), Hs), functor(A, F, N), ( \+ called(Hs, A) ; memberchk(F/N, Declared) ),
                 functor(M, F, N) ), Ms0),
    sort_by_functor(Ms0, Moves),
    %  views over the state are intensional; the rest timeless
    findall(rule(H, B), ( member(rule(H, B0)-_, Ss), \+ gdl_meta_head(H), body_alternative(B0, B) ), Rules),
    dynamic_views(Rules, Fluents, DynViews),
    %  every template, worded by the core reader from the typed sentences
    findall(C-Bs, ( member(S-Bs, Ss), \+ gdl_sentence(S), clause_of(S, C) ), Clauses),
    typing_clauses(Ss, TypingD),
    findall((G :- le_nullary(typing))-Bs, ( member(handler(A, C0, E0)-Bs, Ss), handler_literal(A-C0-E0, G0), lists_of(G0, G1), wrap_nullary(G1, G) ), TypingH),
    append([TypingD, Clauses, TypingH], Terms0),
    ir_of(Terms0, [kb(Id)], program(_, IRItems)),
    findall(F/N-Text, ( member(template(F/N, Text, _), IRItems) ), Words0),
    gdl_words(Words0, Moves, Words),
    findall(F, ( member(F/_, Fluents) ; member(F/_, DynViews) ; member(M, Moves), functor(M, F, _) ), Names),
    maplist(fluent_item(Words, Names), Fluents, FItems),
    maplist(action_item(Words, Names), Moves, AItems),
    findall(template(F/N, T, []), ( member(F/N-T, Words), \+ memberchk(F/N, Fluents), \+ memberchk(F/N, DynViews),
                                     \+ ( member(M, Moves), functor(M, F, N) ), F \== typing,
                                     \+ handler_name(Hs, F/N) ), Timeless),
    findall(I, ( member(I, IRItems), static_item(I, Fluents, DynViews) ), StaticItems),
    %  the views over the state as intensional fluents
    findall(lps(l_int(holds(H, T), Conds)),
            ( member(rule(H0, Bs0), Rules), functor(H0, F, N), memberchk(F/N, DynViews),
              lists_of(rule(H0, Bs0), rule(H, Bs)), maplist(state_literal(Fluents, DynViews, T), Bs, Conds0), append(Conds0, Conds1), unmax(Conds1, Conds) ),
            ViewItems),
    maplist(fluent_item(Words, Names), DynViews, VItems),
    %  the laws of every move
    findall(Laws, ( member(M, Moves), move_laws(Hs, Fluents, DynViews, M, Laws) ), LawLists), append(LawLists, LawItems),
    %  operations called deeper than inlining goes: said, not dropped silently
    deep_call_residues(Ss00, Hs, Moves, DeepRes),
    init_term_residue(InitTerms, InitRes),
    append([Res0, DeepRes, InitRes], Res),
    findall(I, member(residue(I, _), Res), ResItems),
    findall(C, legality_constraint(Moves, DynViews, C), LegalItems),
    %  the moves played
    findall(P, ( member(P/0-_, Words) ; member(P/0, Fluents) ; member(P/0, DynViews) ; member(P, Moves), atom(P) ), Props),
    b_setval(epilog_propositions, Props),
    quote_reserved(Played0, Played),
    length(Played, NP), ( NP =:= 0 -> MaxT = 20 ; MaxT is NP + 2 ),
    option(title(Title), Options, Id),
    file_base_name(Lib, LB),
    ( option(source(Doc, Url), Options) -> format(string(Src), "~nSource: ~w, ~w", [Doc, Url]) ; Src = "" ),
    (   Played == []
    ->  Play = "It has no scenario yet: add the moves of a play (`... from 1 to 2.`)"
    ;   option(operations(_), Options)
    ->  Play = "The scenario applies chosen operations to the data sheet (kept in sources/), as EpilogJS\napplied them; LPS2's final state is checked against EpilogJS's (test_epilog.pl)"
    ;   Play = "The scenario is a play EpilogJS made; LPS2's final state of it is checked against EpilogJS's\n(test_epilog.pl)"
    ),
    ( option(operations(_), Options) -> What = "program with operations" ; What = "game" ),
    format(string(HC), "~w~n~nThe Logical English (for LPS) twin of an Epilog ~w, written by the Epilog translator~nfrom ~w (kept in sources/): the operations are causal laws, the~nviews over the state intensional fluents.~n~w.~w", [Title, What, LB, Play, Src]),
    Header = [kb(Id), target(lps), setting(max_time, MaxT), comment(HC)],
    format(atom(LT), 'sources/~w', [LB]),
    append([FItems, VItems, AItems, Timeless,
            [document('the game', [text(LT)])],
            StaticItems, ViewItems, LawItems, LegalItems, ResItems,
            [lps(initial_state(Init))]], Items000),
    unread_static(Items000, Items00, Unread),
    unclash_items(Items00, Items01),
    maplist(quote_reserved_item, Items01, Items0),
    play_scenario(program(Header, Items0), Played, Scen),
    ( Run == none -> FCs = [] ; final_comment(Run, Fluents, FC), FCs = [FC] ),
    append([Items0, Scen, FCs], Items),
    findall(E, member(residue(_, E), Res), REntries0),
    unread_entry(Unread, UEntries),
    append(REntries0, UEntries, REntries),
    ledger_game(Ss, Moves, DynViews, REntries, Ledger),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    Meta = [program(Id), source('an Epilog game (Stanford Epilog, Games page)'), artifacts([LB]),
            translator('LE2 migration/epilog (epilog_twin.pl)'), date(Date)].

%!  prolog_init(+Sentences, +EffectRelations, -Init) is det.
%
%   The game's `init`, evaluated by Prolog over the program's static facts
%   and rules (Epilog's views are stratified Prolog with negation as
%   failure); with no `init`, the facts of the relations the operations
%   change.
prolog_init(Ss, EF, Init) :-
    (   member(S-_, Ss), ( S = fact(init(_)) ; S = rule(init(_), _) )
    ->  variant_sha1(Ss, H), atom_concat(epilog_eval_, H, M),
        %  every relation of the program prefixed (a relation named like a
        %  Prolog built-in, skirmish's number/1, is the program's own)
        findall(C, ( member(S1-_, Ss), \+ S1 = handler(_, _, _), \+ S1 = definition(_, _), eval_clause(S1, C0),
                     eval_rename(C0, C) ), Cs),
        findall(PI, ( member(C, Cs), ( clause_pi(C, PI) ; C = (_ :- B), eval_goal_pi(B, PI) ) ), PIs0), sort(PIs0, PIs),
        forall(member(PI, PIs), dynamic(M:PI)),
        forall(member(C, Cs), assertz(M:C)),
        catch(call_with_time_limit(20, findall(X, M:'epilog:init'(X), Xs)), _, Xs = []),
        forall(member(F/N, PIs), abolish(M:F/N)),
        list_to_set(Xs, Init)
    ;   findall(F, ( member(fact(F0)-_, Ss), lists_of(F0, F), compound_or_atom(F), functor(F, N, _), memberchk(N, EF) ), Init)
    ).

eval_clause(rule(H, Bs), (H1 :- B)) :- !, lists_of(H, H1), maplist(lists_of, Bs, Bs1), maplist(body_goal, Bs1, Gs), list_conj(Gs, B).
eval_clause(fact(F), F1) :- lists_of(F, F1).

eval_rename((H :- B), (H1 :- B1)) :- !, eval_rel(H, H1), eval_body(B, B1).
eval_rename(H, H1) :- eval_rel(H, H1).

eval_rel(G, G1) :- G =.. [F|As], atom_concat('epilog:', F, F1), G1 =.. [F1|As].

eval_body(V, V) :- var(V), !.
eval_body(G, G1) :- compound(G), G =.. [F|As], length(As, N),
    memberchk(F/N, [(',')/2, (;)/2, (\+)/1]), !, maplist(eval_body, As, Bs), G1 =.. [F|Bs].
eval_body(aggregate_all(count, G, N), aggregate_all(count, G1, N)) :- !, eval_body(G, G1).
eval_body(G, G) :- ( atom(G) ; compound(G) ), functor(G, F, N),
    memberchk(F/N, [true/0, (=)/2, (\=)/2, (=<)/2, (<)/2, (>=)/2, (>)/2, (is)/2, (@<)/2, (@=<)/2, member/2]), !.
eval_body(G, G1) :- eval_rel(G, G1).

eval_goal_pi(B, F/N) :- sub_term(G, B), compound_or_atom(G), \+ var(G), functor(G, F, N), sub_atom(F, 0, _, _, 'epilog:').

clause_pi((H :- _), F/N) :- !, functor(H, F, N).
clause_pi(H, F/N) :- functor(H, F, N).

%   A symbol that is one of LE's own words (the columns a, b, c of a
%   board: `a cell 1 with red` would introduce a variable) is written as the
%   text "a" (LPS2 reports it as "a"; test_epilog.pl reads it back as a).
quote_reserved_item(I, I) :- template_like(I), !.
quote_reserved_item(I0, I) :- quote_reserved(I0, I).

quote_reserved(V, V) :- var(V), !.
quote_reserved(A, S) :- atom(A), reserved_word(A), \+ proposition(A), !, atom_string(A, S).
quote_reserved(T, T1) :- compound(T), \+ T = template(_, _, _), !,
    T =.. [F|As], quote_reserved_list(As, Bs), T1 =.. [F|Bs].
quote_reserved(T, T).

quote_reserved_list([], []).
quote_reserved_list([A|As], [B|Bs]) :- quote_reserved(A, B), quote_reserved_list(As, Bs).

%   (a proposition or a move with no arguments, `a` in buttonsandlights,
%   keeps its name: its template is its words)
proposition(A) :- nb_current(epilog_propositions, Ps), memberchk(A, Ps).

reserved_word(W) :-
    (   memberchk(W, [a, an, the, it, not, and, or, if, then, when, is, are, which, each, every, all])
    ->  true
    ;   catch(( member(C, [article, article_narrow, definite_article, reserved, qualifier]), le_i18n:class_member(en, C, W) ), _, fail)
    ), !.

%!  unclash_items(+Items, -Items1) is det.
%
%   A place named like a constant of the program (the place `count` of
%   movecount(Count) beside the constant `count` in add(1, count, Old, New))
%   would make LE read the constant as the place's variable: such a place is
%   renamed `<name> value`. And a seventh place (`*a rank 7*`, le_writer's
%   name) is written `*a rank7*`.
unclash_items(Items0, Items) :-
    findall(A, ( member(I, Items0), \+ template_like(I), sub_term(T, I), compound(T), \+ is_list(T),
                 T =.. [_|As], member(A, As), atom(A), A \== [] ), As0),
    sort(As0, Constants),
    maplist(unclash_item(Constants), Items0, Items).

template_like(template(_, _, _)).  template_like(fluent(_, _, _)).  template_like(action(_, _, _)).
template_like(document(_, _)).  template_like(comment(_)).

unclash_item(Cs, I0, I) :-
    template_like(I0), I0 =.. [K, F, Text0, Adds], K \== document, !,
    unclash_text(Cs, Text0, Text), I =.. [K, F, Text, Adds].
unclash_item(_, I, I).

unclash_text(Cs, Text0, Text) :-
    atomic_list_concat(Parts, '*', Text0),
    unclash_parts(Parts, 1, Cs, Parts1),
    atomic_list_concat(Parts1, '*', Text).

unclash_parts([], _, _, []).
unclash_parts([P|Ps], I, Cs, [Q|Qs]) :-
    (   I mod 2 =:= 0, atomic_list_concat(Ws, ' ', P), last(Ws, W), memberchk(W, Cs)
    ->  atom_concat(P, ' value', Q)
    ;   %  the seventh place and later (`a rank 7`, which LE reads as two
        %  words and a number) as one word: `a rank7`
        I mod 2 =:= 0, atomic_list_concat(Ws, ' ', P), append(Front, [T, K], Ws), atom_number(K, _)
    ->  atom_concat(T, K, TK), append(Front, [TK], Ws1), atomic_list_concat(Ws1, ' ', Q)
    ;   Q = P
    ),
    I1 is I + 1, unclash_parts(Ps, I1, Cs, Qs).

sort_by_functor(Ms0, Ms) :-
    findall(F/N-M, ( member(M, Ms0), functor(M, F, N) ), Ps), sort(1, @<, Ps, S), pairs_values(S, Ms).

%   GDL's relations about moves and outcomes, as LE can word them: a move is
%   a term, which an LE place cannot hold, so `legal(mark(M,N))` is the
%   relation legal_mark(M, N); `goal(R, N)` and `terminal` keep their names.
%   A relation whose name has a dot in it (triples' `student.major`): LE
%   words the dot as a separate token in the laws but not in the template,
%   so the two never match. In a game the relation is `student_major`; the
%   final states compared (base_state_of/3) are renamed the same way.
undot_sentence(S-Bs, S1-Bs) :- undot(S, S1).

undot(T, T) :- var(T), !.
undot(T, T1) :-
    compound(T), !,
    compound_name_arguments(T, F, As), maplist(undot, As, As1),
    ( sub_atom(F, _, _, _, '.') -> atomic_list_concat(Parts, '.', F), atomic_list_concat(Parts, '_', F1) ; F1 = F ),
    compound_name_arguments(T1, F1, As1).
undot(T, T).

gdl_rename(rule(H, B)-Bs, rule(H1, B1)-Bs) :- !, legal_rename(H, H1), maplist(legal_rename_lit, B, B1).
gdl_rename(fact(H)-Bs, fact(H1)-Bs) :- !, legal_rename(H, H1).
gdl_rename(S, S).

legal_rename(legal(M), L) :- ( atom(M) ; compound(M) ), !, M =.. [F|As], atom_concat(legal_, F, LF), L =.. [LF|As].
legal_rename(H, H).
legal_rename_lit(not(L), not(L1)) :- !, legal_rename(L, L1).
legal_rename_lit(L, L1) :- legal_rename(L, L1).

%   The words of GDL's relations and of the moves: a move is `the move mark
%   with *an index* and *a second index* is made` and its legality `the move
%   mark with … is legal` (the places of the reader's template for mark/2),
%   `the goal of *a role* is *a number*`, `the game is terminal`.
gdl_words(Words0, Moves, Words) :-
    findall(F/N-T, ( member(F/N-T0, Words0), gdl_word(F/N, T0, Moves, Words0, T) ), Words).

gdl_word(goal/2, _, _, _, 'the goal of *a role* is *a number*') :- !.
gdl_word(terminal/0, _, _, _, 'the game is terminal') :- !.
gdl_word(LF/N, _, Moves, Words0, T) :-
    atom_concat(legal_, F, LF), member(M, Moves), functor(M, F, N), !,
    move_words(F/N, Words0, is_legal, T).
gdl_word(F/N, _, Moves, Words0, T) :-
    member(M, Moves), functor(M, F, N), !,
    move_words(F/N, Words0, is_made, T).
gdl_word(_, T, _, _, T).

move_words(F/N, Words0, What, T) :-
    (   memberchk(F/N-MT, Words0) -> slots(MT, Slots) ; length(Slots, N), maplist(=('a thing'), Slots) ),
    atomic_list_concat(Ws, '_', F), atomic_list_concat(Ws, ' ', FW),
    ( What == is_legal -> Is = 'is legal' ; Is = 'is made' ),
    (   N =:= 0 -> format(atom(T), 'the move ~w ~w', [FW, Is])
    ;   maplist([S, SS]>>format(atom(SS), '*~w*', [S]), Slots, Ss), and_words(Ss, List),
        format(atom(T), 'the move ~w with ~w ~w', [FW, List, Is])
    ).

slots(Text, Slots) :-
    atomic_list_concat(Parts, '*', Text),
    findall(S, ( nth1(I, Parts, S), I mod 2 =:= 0 ), Slots).

and_words([W], W) :- !.
and_words(Ws, L) :- append(I, [Last], Ws), atomic_list_concat(I, ', ', IL), format(atom(L), '~w and ~w', [IL, Last]).

gdl_sentence(fact(F)) :- gdl_meta_head(F).
gdl_sentence(rule(H, _)) :- gdl_meta_head(H).
gdl_sentence(handler(_, _, _)).

gdl_meta_head(H) :- compound(H), functor(H, F, _), memberchk(F, [role, base, action, init, input]), !.
gdl_meta_head(H) :- atom(H), memberchk(H, [role, base, action, init]).

handler_literal(A-C-E, L) :- ( L = A ; cond_lit(C, L) ; cond_lit(E, L) ), compound_or_atom(L), L \== true, \+ epilog_builtin(L).

epilog_builtin(L) :- functor(L, F, _), memberchk(F, [same, distinct, leq, less, evaluate, mutex, countofall, symless, symleq, member]), !.
cond_lit(and(Cs), L) :- !, member(C, Cs), cond_lit(C, L).
cond_lit(not(C), L) :- !, cond_lit(C, L).
cond_lit(C, C).

handler_head(Hs, L) :- member(h(A, _, _), Hs), \+ A \= L, !.
handler_name(Hs, F/N) :- member(h(A, _, _), Hs), functor(A, F, N), !.

%   A handler called from another handler's effects (a sub-operation).
called(Hs, A) :-
    member(h(A2, _, E), Hs), A2 \== A, effect_call(E, Hs, C), \+ C \= A, !.

effect_call(E, Hs, C) :- effect_item(E, C), C \= not(_), handler_head(Hs, C).

effect_item(and(Es), X) :- !, member(E, Es), effect_item(E, X).
effect_item(E, E).

effect_literal(E, L) :- effect_item(E, X), ( X = not(L) -> true ; L = X ), compound_or_atom(L).
compound_or_atom(L) :- ( atom(L) ; compound(L) ), !.

%   Views whose definition reads the state (a fluent, or such a view).
dynamic_views(Rules, Fluents, Dyn) :-
    findall(F/N, ( member(rule(H, _), Rules), functor(H, F, N) ), All0), sort(All0, All),
    fixpoint(Rules, Fluents, All, [], Dyn).

fixpoint(Rules, Fluents, All, D0, D) :-
    findall(F/N, ( member(F/N, All), \+ memberchk(F/N, D0),
                   member(rule(H, Bs), Rules), functor(H, F, N),
                   member(B, Bs), sub_term(L, B), compound_or_atom(L), \+ var(L), functor(L, G, M),
                   ( memberchk(G/M, Fluents) ; memberchk(G/M, D0) ) ), New0),
    sort(New0, New),
    (   New == [] -> D = D0 ; append(D0, New, D1), fixpoint(Rules, Fluents, All, D1, D) ).

%   A body literal as a state condition at T: a fluent or dynamic view is
%   holds(...), negated holds(not(...)); `countofall` the count aggregate
%   over the state; a static goal (a timeless relation, a comparison, an
%   evaluation) the Prolog goal(s) LPS conditions are.
state_literal(Fl, Dyn, T, not(L), [holds(not(L), T)]) :- dyn_or_fluent(L, Fl, Dyn), !.
state_literal(Fl, Dyn, T, L, [holds(L, T)]) :- dyn_or_fluent(L, Fl, Dyn), !.
state_literal(Fl, Dyn, T, countofall(X, G, N), Cs) :- !,
    state_literal(Fl, Dyn, T, G, Gs),
    (   var(N) -> Cs = [agg(count, X, Gs, T, N)]
    ;   Cs = [agg(count, X, Gs, T, R), R = N]
    ).
state_literal(_, _, _, symless(_, _), []) :- !.     % no LE form: see the ledger
state_literal(_, _, _, symleq(_, _), []) :- !.
%   a static relation negated: `it is not the case that ...` with no time
%   (le_lps_write writes holds(not(G), lps_now) so; LE reads it back as
%   not(G))
state_literal(_, _, _, not(L), [holds(not(L), lps_now)]) :- compound_or_atom(L), \+ epilog_builtin(L), !.
state_literal(_, _, _, L, Gs) :- body_goal(L, G0), conj_list(G0, Gs).

%!  unmax(+Conds, -Conds1) is multi.
%
%   `V is E` with max(A, B) (or min) in E, as two cases LE can say: A >= B
%   and E with A, or A < B and E with B.
unmax(Cs, Cs1) :-
    (   nth0(I, Cs, G), nonvar(G), G = (V is E), sub_term(M, E), nonvar(M), M =.. [Op, A, B], memberchk(Op, [max, min])
    ->  (   Op == max -> ( C = (A >= B), X = A ; C = (A < B), X = B )
        ;   ( C = (A =< B), X = A ; C = (A > B), X = B )
        ),
        replace_sub(E, M, X, E1),
        nth0(I, Cs, _, Rest), nth0(I, Cs2, (V is E1), Rest),
        append(Cs2a, Cs2b, Cs2), length(Cs2a, I), append(Cs2a, [C|Cs2b], Cs3),
        unmax(Cs3, Cs1)
    ;   Cs1 = Cs
    ).

replace_sub(T, M, X, X) :- T == M, !.
replace_sub(T, M, X, T1) :- compound(T), !, T =.. [F|As], replace_subs(As, M, X, Bs), T1 =.. [F|Bs].
replace_sub(T, _, _, T).

replace_subs([], _, _, []).
replace_subs([A|As], M, X, [B|Bs]) :- replace_sub(A, M, X, B), replace_subs(As, M, X, Bs).

conj_list((A, B), L) :- !, conj_list(A, LA), conj_list(B, LB), append(LA, LB, L).
conj_list(true, []) :- !.
conj_list(G, [G]).

dyn_or_fluent(L, Fl, Dyn) :- compound_or_atom(L), functor(L, F, N), ( memberchk(F/N, Fl) ; memberchk(F/N, Dyn) ), !.

%   The IR's comparison forms as the Prolog goals LPS conditions are.
ir_goal(le_equal_to(X, Y), X = Y) :- !.
ir_goal(le_not_equal_to(X, Y), X \= Y) :- !.
ir_goal(le_ge(X, Y), X >= Y) :- !.
ir_goal(le_le(X, Y), X =< Y) :- !.
ir_goal(le_gt(X, Y), X > Y) :- !.
ir_goal(le_lt(X, Y), X < Y) :- !.
ir_goal(le_assign(X, E), X is E) :- !.
ir_goal(prolog(G), G) :- !.
ir_goal(G, G).

%   The laws of a move: its handlers' effects, with the operations it calls
%   inlined (their conditions added), each addition initiating and each
%   deletion terminating its fluent under the conditions, read at T1.
move_laws(Hs, Fl, Dyn, M, Laws) :-
    findall(eff(Kind, M, F, Conds),
            ( member(h(A, C, E), Hs), copy_term(h(A, C, E), h(M, C1, E1)),
              expand(Hs, Fl, [C1], E1, 0, Kind, F, Conds) ),
            Effs),
    findall(lps(Law), ( member(eff(K, M1, F0, Cs0), Effs), law_term(K, M1, F0, Cs0, Fl, Dyn, Law) ), Laws0),
    list_to_set(Laws0, Laws).

%   A move the game says is not legal does not happen (a GDL game manager
%   refuses it; LPS2 drops the observed move): `it must not be true that the
%   move mark with an index and a second index is made and it is not the
%   case that the move mark with the index and the second index is legal.`
legality_constraint(Moves, Dyn, lps(d_pre([happens(M, T1, _), holds(not(L), T1)]))) :-
    member(M0, Moves), functor(M0, F, N),
    atom_concat(legal_, F, LF), memberchk(LF/N, Dyn),
    functor(M, F, N), M =.. [_|As], L =.. [LF|As].

%   (inlining stops below five nested calls: deep_call_residues/4 reports
%   the moves whose effects lie deeper)
expand(_, _, _, _, D, _, _, _) :- D > 5, !, fail.
expand(Hs, Fl, Cs, E, D, Kind, F, Conds) :-
    effect_item(E, X),
    (   X = not(L), \+ handler_head(Hs, L) -> Kind = del, F = L, Conds = Cs
    ;   X \= not(_), handler_head(Hs, X)
    ->  member(h(A, C, E2), Hs), copy_term(h(A, C, E2), h(X, C2, E3)),
        D1 is D + 1, expand(Hs, Fl, [C2|Cs], E3, D1, Kind, F, Conds)
    ;   X \= not(_), X \== true -> Kind = add, F = X, Conds = Cs
    ).

%!  deep_call_residues(+Sentences, +Handlers, +Moves, -Residues) is det.
%
%   A move whose operations call operations more than five levels deep (as
%   expand/8 inlines them) has effects no law states: a residue block with
%   the move's operation definitions, and a ledger entry.
deep_call_residues(Ss, Hs, Moves, Residues) :-
    findall(M, ( member(M, Moves), once(( member(h(A, C, E), Hs), copy_term(h(A, C, E), h(M, _, E1)),
                                            deep_call(Hs, E1, 0) )) ), Deep),
    findall(residue(Item, Entry),
            ( nth1(K, Deep, M), functor(M, F, N),
              format(atom(Id), 'deep_operations_~w', [K]),
              called_operations(Ss, [F/N], [], Ops),
              findall(T, ( member(F1/N1, Ops), member(handler(A, C, E)-Bs, Ss), functor(A, F1, N1),
                           epilog_sentence_text(handler(A, C, E)-Bs, T) ), Ts),
              atomic_list_concat(Ts, '\n', Text),
              format(string(Title), "the move ~w/~w calls operations more than five levels deep", [F, N]),
              Note = "operations are inlined into the move's causal laws to a depth of five calls: the effects reached through deeper calls (or a recursive operation) have no law; state them as laws by hand",
              Item = residue(Id, [title(Title), note(Note), source(epilog, Text), concludes([])]),
              format(string(El), "~w/~w: deeper calls", [F, N]),
              Entry = entry(El, operation, residue, Note, Id, none) ),
            Residues).

%   The operations a move reaches through calls, the move first.
called_operations(_, [], Seen, Ops) :- !, reverse(Seen, Ops).
called_operations(Ss, [F/N|Todo], Seen, Ops) :-
    (   memberchk(F/N, Seen) -> called_operations(Ss, Todo, Seen, Ops)
    ;   findall(G/K, ( member(handler(A, _, E)-_, Ss), functor(A, F, N), effect_item(E, X), compound_or_atom(X),
                       X \= not(_), functor(X, G, K), member(handler(B, _, _)-_, Ss), functor(B, G, K) ), Next0),
        sort(Next0, Next), append(Todo, Next, Todo1),
        called_operations(Ss, Todo1, [F/N|Seen], Ops)
    ).

deep_call(_, _, D) :- D > 5, !.
deep_call(Hs, E, D) :-
    effect_item(E, X), X \= not(_), X \== true, handler_head(Hs, X),
    member(h(A, C, E2), Hs), copy_term(h(A, C, E2), h(X, _, E3)),
    D1 is D + 1, deep_call(Hs, E3, D1), !.

init_term_residue([], []) :- !.
init_term_residue(Ts, [residue(Item, Entry)]) :-
    maplist([T, X]>>epilog_term_text(T, X), Ts, Xs), atomic_list_concat(Xs, '\n', Text),
    length(Ts, N),
    format(string(Title), "~w fact(s) of the initial state with functional terms", [N]),
    Note = "a Logical English place holds a constant, not a term: these facts are not in the initial state",
    Item = residue(init_terms_1, [title(Title), note(Note), source(epilog, Text), concludes([])]),
    Entry = entry(Title, 'initial state', residue, Note, init_terms_1, none).

law_term(K, M, F0, Cs0, Fl, Dyn, Law) :-
    lists_of(F0, F), lists_of(Cs0, Cs1),
    cond_items(Cs1, Ls),
    maplist(state_literal(Fl, Dyn, T1), Ls, CLs), append(CLs, Conds0), unmax(Conds0, Conds),
    (   K == add -> Law = initiated(happens(M, T1, _), F, Conds)
    ;   Law = terminated(happens(M, T1, _), F, Conds)
    ).

%   (no findall: it would copy the variables the conditions share with the
%   law's fluent)
cond_items([], []).
cond_items([true|Cs], Ls) :- !, cond_items(Cs, Ls).
cond_items([and(As)|Cs], Ls) :- !, append(As, Cs, Cs1), cond_items(Cs1, Ls).
cond_items([C|Cs], [C|Ls]) :- cond_items(Cs, Ls).

%   Templates: the core reader's wording of each relation, as the LPS
%   declarations.
%   A name used with two arities (`step(M)`, `step(M,N)`) is two templates,
%   known in LPS as step_1 and step_2 (an LE name has one arity).
fluent_item(Words, Names, F/N, fluent(F/N, Text, [arity(N), known_as(K)])) :- word_of(Words, F/N, Text), known_as(Names, F/N, K).
action_item(Words, Names, M, action(F/N, Text, [arity(N), known_as(K)])) :- functor(M, F, N), word_of(Words, F/N, Text), known_as(Names, F/N, K).

known_as(Names, F/N, K) :- ( aggregate_all(count, member(F, Names), 1) -> K = F ; format(atom(K), '~w_~w', [F, N]) ).

word_of(Words, F/N, Text) :-
    (   memberchk(F/N-T, Words) -> Text = T
    ;   N =:= 0 -> atomic_list_concat(Ws, '_', F), atomic_list_concat(Ws, ' ', Text)
    ;   length(Ps, N), maplist(=('*a thing*'), Ps), atomic_list_concat(Ws, '_', F),
        atomic_list_concat(Ws, ' ', FW), atomic_list_concat([FW|Ps], ' ', Text)
    ).

%   The timeless items of the reader's IR: facts and rules of the static
%   relations (not the state's, not the views over it, not typing).
%!  unread_static(+Items0, -Items, -Unread) is det.
%
%   The static facts no sentence of the twin reads, and their templates, left
%   out. In the source they are read only by the game's declarations — the
%   types of `base` and `action` (`base(current(M)) :- step(M)`), the `init`
%   the build evaluates (`init(cell(R,C,b)) :- row(R) & col(C)`), a `legal(a)`
%   that holds always — which LPS states otherwise: templates, the initial
%   state, and no constraint for a move that is always legal. Written, they
%   would be data nothing consults. Unread is the relations left out, as F/N.
%   A relation's name mentioned anywhere else (a rule, a law, a view, a
%   residue block) keeps its facts.
unread_static(Items0, Items, Unread) :-
    findall(F/N, ( member(fact(H, _), Items0), functor(H, F, N) ), Fs0), sort(Fs0, Fs),
    findall(I, ( member(I, Items0), \+ I = fact(_, _), \+ I = template(_, _, _),
                 \+ I = fluent(_, _, _), \+ I = action(_, _, _), \+ I = event(_, _, _) ), Readers),
    findall(F/N, ( member(F/N, Fs), \+ name_mentioned(F, Readers) ), Unread),
    exclude(unread_item(Unread), Items0, Items).

name_mentioned(F, Terms) :-
    sub_term(S, Terms),
    ( compound(S) -> functor(S, F, _) ; atom(S), S == F ), !.

unread_item(Unread, fact(H, _)) :- functor(H, F, N), memberchk(F/N, Unread).
unread_item(Unread, template(F/N, _, _)) :- memberchk(F/N, Unread).

unread_entry([], []) :- !.
unread_entry(Unread, [entry(E, facts, encoded, Note, none, none)]) :-
    findall(A, ( member(F/N, Unread), format(atom(A), '~w/~w', [F, N]) ), As),
    atomic_list_concat(As, ', ', E),
    Note = 'facts only the game declarations read (base, action, init, a legal move that is always legal): LPS states those as templates, the initial state and no constraint, so the facts are not written'.

static_item(fact(H, O), Fl, Dyn) :- functor(H, F, N), \+ memberchk(F/N, Fl), \+ memberchk(F/N, Dyn), \+ gdl_meta_head(H), F \== typing, ignore(O = O).
static_item(rule(H, B, O), Fl, Dyn) :- functor(H, F, N), F \== typing, \+ memberchk(F/N, Fl), \+ memberchk(F/N, Dyn), \+ gdl_meta_head(H), ignore(B-O = B-O).

play_scenario(_, [], []) :- !.
play_scenario(IR, Moves, [scenario(play, Lines, [])]) :-
    ir_dicts(IR, Dicts),
    length(Moves, N), numlist(1, N, Is),
    findall(raw(L), ( nth1(I, Moves, M), member(I, Is), T2 is I + 1,
                      lists_of(M, M1), render_ground_literal(Dicts, M1, S),
                      format(atom(L), '~w from ~w to ~w.', [S, I, T2]) ), Lines).

final_comment(Run, Fluents, comment(C)) :-
    base_state_of(Run, Fluents, Final),
    findall(S, ( member(F, Final), format(string(S), "  - ~q", [F]) ), Ss),
    atomic_list_concat(Ss, '\n', FT),
    format(string(C), "EpilogJS's state after the play (the twin's final state under LPS2 must be the same):~n~w", [FT]).

%!  base_state_of(+Run, +Fluents, -Final) is det.
%
%   EpilogJS's last state, sorted, as fluent terms.
base_state_of(Run, _Fluents, Final) :-
    last(Run.steps, Last),
    findall(F, ( member(T, Last.terms), json_term(T, F00, _), undot(F00, F0), lists_of(F0, F) ), F1),
    msort(F1, Final).

ledger_game(Ss, Moves, Dyn, Residues, Ledger) :-
    findall(entry(E, operation, St, Note, A, none),
            ( member(M, Moves), functor(M, A, N), format(string(E), "~w/~w", [A, N]),
              Note0 = 'an operation definition -> causal laws (initiates / terminates), the operations it calls inlined',
              format(string(Deep), "~w/~w: deeper calls", [A, N]),
              (   member(entry(Deep, _, _, _, Id, _), Residues)
              ->  St = approximated, format(atom(Note), '~w; the effects of calls deeper than five are not (~w)', [Note0, Id])
              ;   St = encoded, Note = Note0
              ) ),
            L1),
    findall(entry(E, view, encoded, 'a view over the state -> an intensional fluent', F, none),
            ( member(F/N, Dyn), format(string(E), "~w/~w", [F, N]) ), L2),
    findall(entry(E, 'game declaration', encoded, Map, 'the program', none),
            ( member(D-Map, [role-'the roles: the values of the goal and control places (no sentence of their own)',
                             base-'the base relations: the fluents (their templates)',
                             action-'the moves: the actions (their templates name the places)',
                             legal-'the legal moves: an intensional fluent per move, and a constraint: a move that is not legal does not happen',
                             init-'the initial state (`initially`), init evaluated']),
              once(( member(S-_, Ss), sub_term(L, S), compound(L), functor(L, D, _) )),
              format(string(E), "~w", [D]) ), L3),
    symbol_order_entries(Ss, L4),
    append([L1, L2, L3, L4, Residues], Ledger0), list_to_set(Ledger0, Ledger).

		 /*******************************
		 *           BUILDING           *
		 *******************************/

%!  build_theory(+Id, +Options, -Report) is det.
build_theory(Id, Options, Report) :-
    twin_dir(theory, Id, Options, Dir),
    option(rules(RF), Options), ( RF == none -> true ; copy_source(RF, Dir) ),
    ( option(data(DF), Options), exists_file(DF), size_file(DF, S), S > 0 -> copy_source(DF, Dir) ; true ),
    theory_migration(Id, Options, M),
    write_migration(M, Dir, Id, Report).

%!  build_game(+Id, +Options, -Report) is det.
build_game(Id, Options, Report) :-
    twin_dir(game, Id, Options, Dir),
    option(library(Lib), Options), copy_source(Lib, Dir),
    ( option(data(D), Options) -> copy_source(D, Dir) ; true ),
    game_run(Lib, Options, Run),
    format(atom(RF), '~w/sources/~w.epilog.json', [Dir, Id]),
    setup_call_cleanup(open(RF, write, S), json_write_dict(S, Run, [width(100)]), close(S)),
    game_migration(Id, [run(Run)|Options], M),
    write_migration(M, Dir, Id, Report).

%   Where a twin is written: under out(Root) when the options say (a
%   staging directory, validate.pl's), else in the public repository of the
%   language it is written in (le2_paths.pl): a ruleset, timeless Logical
%   English, in LE2's examples/migration/epilog/; a game, Logical English for
%   LPS, in LPS2's.
twin_dir(Kind, Id, Options, Dir) :-
    (   option(out(Root), Options)
    ->  true
    ;   Kind == game
    ->  lps2_dir(L), atomic_list_concat([L, '/examples/migration/epilog'], Root)
    ;   twins_dir(epilog, Root)
    ),
    format(atom(Dir), '~w/~w', [Root, Id]),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD).

copy_source(F, Dir) :-
    file_base_name(F, B), format(atom(D), '~w/sources/~w', [Dir, B]), copy_file(F, D).

/*  The reader's gate (roadmap.md §8, Phase 3a, step 1)

        ./myswipl.sh -q migration/rulespec/gate.pl

    For every module rulespec_oracle.py has run (the JSON files of runs/), every version
    of every derived rule: the reader's parse tree of the formula
    (rulespec_reader:parse_formula/2) must be the engine's own lowering of
    it (the compiled artifact's `kind:`-tagged expression, kept in the run
    file), up to what the lowering does not keep: a number's kind (the
    engine types a literal by where it stands), the grouping of a chain of
    `+`, `*`, `and`, `or` (associative), and the lookup of a scalar
    parameter (the engine reads it at index 0). A `match` is compared as the
    chain of `if`s the engine lowers it to.

    Prints each disagreement and the totals; writes runs/gate.txt.
*/

:- initialization(main, main).

:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(yaml)).
:- use_module(rulespec_reader).

main :-
    module_property(rulespec_reader, file(F)), file_directory_name(F, Dir),
    atomic_list_concat([Dir, '/runs'], Runs),
    directory_files(Runs, Fs0), include([X]>>file_name_extension(_, json, X), Fs0, Fs1), msort(Fs1, Fs),
    nb_setval(gate, counts(0, 0, 0)),
    atomic_list_concat([Runs, '/gate.txt'], Out),
    setup_call_cleanup(open(Out, write, S),
                       ( forall(member(F1, Fs), gate_file(S, Runs, F1)),
                         nb_getval(gate, counts(Same, Diff, NoParse)),
                         format(S, "~nformulas the same as the engine's lowering: ~w; different: ~w; not parsed: ~w~n", [Same, Diff, NoParse]),
                         format("formulas the same as the engine's lowering: ~w; different: ~w; not parsed: ~w~n", [Same, Diff, NoParse]) ),
                       close(S)).

gate_file(S, Runs, F) :-
    atomic_list_concat([Runs, '/', F], P),
    setup_call_cleanup(open(P, read, In), json_read_dict(In, Run), close(In)),
    (   get_dict(lowered, Run, Low), get_dict(module, Run, MId0)
    ->  atom_string(MId, MId0),
        module_closure(MId, Ms),
        kinds(Ms, Kinds),
        dict_pairs(Low, _, Pairs),
        forall(member(Name-Versions, Pairs), gate_rule(S, MId, Ms, Kinds, Name, Versions))
    ;   true
    ).

kinds(Ms, Kinds) :-
    findall(kind(N, K), ( member(module(_, D), Ms), get_dict(rules, D, Rs), is_list(Rs), member(R, Rs),
                          get_dict(name, R, N0), atom_string(N, N0), rule_kind(R, K) ), Kinds).

rule_kind(R, K) :-
    get_dict(kind, R, K0),
    (   K0 == "parameter"
    ->  (   get_dict(versions, R, Vs), member(V, Vs), get_dict(formula, V, F),
            catch(parse_formula(F, T), _, fail), T \= num(_), T \= neg(num(_))
        ->  K = derived            % the engine lowers a computed parameter as a derived value
        ;   K = parameter
        )
    ;   K0 == "derived" -> ( get_dict(dtype, R, T), memberchk(T, ["Judgment", "judgment", "Boolean", "Bool", "boolean", "bool"]) -> K = judgment ; K = derived )
    ;   K = relation
    ).

gate_rule(S, MId, Ms, Kinds, Name, Versions) :-
    (   once(( member(module(_, D), Ms), get_dict(rules, D, Rs), member(R, Rs), get_dict(name, R, N0), atom_string(Name, N0) ))
    ->  get_dict(versions, R, Vs),
        ( memberchk(kind(Name, judgment), Kinds) -> Pos = judgment ; Pos = scalar ),
        forall(nth1(I, Versions, EV),
               (   nth1(I, Vs, V), get_dict(formula, V, Fm), get_dict(expr, EV, Expr)
               ->  (   catch(parse_formula(Fm, Tree), _, fail)
                   ->  mine(Pos, Tree, Kinds, M), engine(Expr, E),
                       (   M =@= E -> count(same)
                       ;   count(diff), format(S, "~w#~w version ~w~n  reader: ~q~n  engine: ~q~n", [MId, Name, I, M, E])
                       )
                   ;   count(noparse), format(S, "~w#~w version ~w: not parsed~n", [MId, Name, I])
                   )
               ;   true
               ))
    ;   true
    ).

count(K) :-
    nb_getval(gate, counts(A, B, C)),
    (   K == same -> A1 is A + 1, nb_setval(gate, counts(A1, B, C))
    ;   K == diff -> B1 is B + 1, nb_setval(gate, counts(A, B1, C))
    ;   C1 is C + 1, nb_setval(gate, counts(A, B, C1))
    ).

		 /*******************************
		 *   ONE CANONICAL FORM: MINE   *
		 *******************************/

mine(P, T, K, C) :- reader_low(P, T, K, C0), flat(C0, C).

reader_low(judgment, and(A, B), K, and([X, Y])) :- !, reader_low(judgment, A, K, X), reader_low(judgment, B, K, Y).
reader_low(judgment, or(A, B), K, or([X, Y])) :- !, reader_low(judgment, A, K, X), reader_low(judgment, B, K, Y).
reader_low(judgment, not(A), K, not(X)) :- !, reader_low(judgment, A, K, X).
reader_low(_, cmp(Op, A, B), K, cmp(Op, X, Y)) :- !, reader_low(scalar, A, K, X), reader_low(scalar, B, K, Y).
reader_low(judgment, id(N), K, R) :- !,
    ( memberchk(kind(N, judgment), K) -> R = derived(N) ; R = cmp(==, input(N), bool(true)) ).
reader_low(judgment, call(exactly_one, As), K, exactly_one(Xs)) :- !, maplist({K}/[A, X]>>reader_low(judgment, A, K, X), As, Xs).
reader_low(judgment, bool(B), _, cmp(==, bool(B), bool(true))) :- !.   % the loader compares a literal with true
reader_low(scalar, num(N), _, num(V)) :- !, V is N * 1.0.
reader_low(scalar, str(S), _, text(S)) :- !.
reader_low(scalar, bool(B), _, bool(B)) :- !.
reader_low(scalar, id(period_start), _, period_start) :- !.
reader_low(scalar, id(period_end), _, period_end) :- !.
reader_low(scalar, id(N), K, R) :- !,
    (   memberchk(kind(N, parameter), K) -> R = param(N, num(0.0))
    ;   ( memberchk(kind(N, derived), K) ; memberchk(kind(N, judgment), K) ) -> R = derived(N)
    ;   R = input(N)
    ).
reader_low(scalar, index(T, I), K, param(T, X)) :- !, reader_low(scalar, I, K, X).
reader_low(scalar, bin(+, A, B), K, add([X, Y])) :- !, reader_low(scalar, A, K, X), reader_low(scalar, B, K, Y).
reader_low(scalar, bin(*, A, B), K, mul([X, Y])) :- !, reader_low(scalar, A, K, X), reader_low(scalar, B, K, Y).
reader_low(scalar, bin(-, A, B), K, sub(X, Y)) :- !, reader_low(scalar, A, K, X), reader_low(scalar, B, K, Y).
reader_low(scalar, bin(/, A, B), K, div(X, Y)) :- !, reader_low(scalar, A, K, X), reader_low(scalar, B, K, Y).
reader_low(scalar, neg(A), K, sub(num(0.0), X)) :- !, reader_low(scalar, A, K, X).
reader_low(scalar, if(C, T, E), K, if(X, Y, Z)) :- !,
    reader_low(judgment, C, K, X), reader_low(scalar, T, K, Y), reader_low(scalar, E, K, Z).
reader_low(scalar, match(S, Arms, D), K, R) :- !,
    match_chain(S, Arms, D, T), reader_low(scalar, T, K, R).
reader_low(scalar, nomatch(S, Ps), K, no_match(X, Ys)) :- !, reader_low(scalar, S, K, X),
    maplist({K}/[P, Y]>>reader_low(scalar, P, K, Y), Ps, Ys).
reader_low(scalar, call(F, [A]), K, R) :- memberchk(F, [floor, ceil]), !, reader_low(scalar, A, K, X), R =.. [F, X].
reader_low(scalar, call(F, As), K, R) :- memberchk(F, [max, min]), !, maplist({K}/[A, X]>>reader_low(scalar, A, K, X), As, Xs), R =.. [F, Xs].
reader_low(scalar, call(len, [id(Rel)]), _, count(Rel, none)) :- !.
reader_low(scalar, call(count_where, [id(Rel), id(P)]), K, count(Rel, PP)) :- !, pred(P, K, PP).
reader_low(scalar, call(sum, [field(Rel, F)]), _, sum(Rel, F, none)) :- !.
reader_low(scalar, call(sum_where, [id(Rel), id(F), id(P)]), K, sum(Rel, F, PP)) :- !, pred(P, K, PP).
reader_low(scalar, call(F, As), K, call(F, Xs)) :- !, maplist({K}/[A, X]>>reader_low(scalar, A, K, X), As, Xs).
reader_low(P, T, _, unread(P, T)).

pred(P, K, R) :- ( memberchk(kind(P, judgment), K) -> R = derived(P) ; R = cmp(==, input(P), bool(true)) ).

match_chain(S, Arms, D, T) :- findall(P, member(P-_, Arms), Ps), match_chain(S, Arms, D, Ps, T).

match_chain(S, [], none, Ps, nomatch(S, Ps)) :- !.
match_chain(_, [], D, _, D) :- !.
match_chain(S, [P-V|As], D, Ps, if(cmp(==, S, P), V, E)) :- match_chain(S, As, D, Ps, E).

		 /*******************************
		 *  ONE CANONICAL FORM: ENGINE  *
		 *******************************/

engine(D, C) :- eng(D, C0), flat(C0, C).

eng(D, R) :- get_dict(kind, D, K0), atom_string(K, K0), eng(K, D, R).

eng(literal, D, R) :- !, get_dict(value, D, V), lit(V, R).
eng(input, D, input(N)) :- !, get_dict(name, D, N0), atom_string(N, N0).
eng(input_or_else, D, input(N)) :- !, get_dict(name, D, N0), atom_string(N, N0).
eng(derived, D, derived(N)) :- !, get_dict(name, D, N0), atom_string(N, N0).
eng(parameter_lookup, D, param(N, I)) :- !,
    get_dict(parameter, D, N0), atom_string(N, N0), get_dict(index, D, I0), eng(I0, I).
eng(K, D, R) :- memberchk(K, [add, mul]), !,
    (   get_dict(items, D, Is) -> maplist(eng, Is, Xs) ; get_dict(left, D, L), get_dict(right, D, Rr), eng(L, X), eng(Rr, Y), Xs = [X, Y] ),
    R =.. [K, Xs].
eng(K, D, R) :- memberchk(K, [sub, div]), !, get_dict(left, D, L), get_dict(right, D, Rr), eng(L, X), eng(Rr, Y), R =.. [K, X, Y].
eng(K, D, R) :- memberchk(K, [max, min]), !, get_dict(items, D, Is), maplist(eng, Is, Xs), R =.. [K, Xs].
eng(K, D, R) :- memberchk(K, [floor, ceil]), !, ( get_dict(value, D, V) -> true ; get_dict(expr, D, V) ), eng(V, X), R =.. [K, X].
eng(if, D, if(C, T, E)) :- !, get_dict(condition, D, C0), get_dict(then_expr, D, T0), get_dict(else_expr, D, E0),
    eng(C0, C), eng(T0, T), eng(E0, E).
eng(comparison, D, cmp(Op, X, Y)) :- !, get_dict(op, D, O), op(O, Op), get_dict(left, D, L), get_dict(right, D, R), eng(L, X), eng(R, Y).
eng(K, D, R) :- memberchk(K, [and, or]), !,
    (   get_dict(items, D, Is) -> maplist(eng, Is, Xs) ; get_dict(left, D, L), get_dict(right, D, Rr), eng(L, X), eng(Rr, Y), Xs = [X, Y] ),
    R =.. [K, Xs].
eng(not, D, not(X)) :- !, ( get_dict(expr, D, E) -> true ; get_dict(value, D, E) -> true ; get_dict(item, D, E) ), eng(E, X).
eng(exactly_one, D, exactly_one(Xs)) :- !, get_dict(items, D, Is), maplist(eng, Is, Xs).
eng(period_start, _, period_start) :- !.
eng(period_end, _, period_end) :- !.
eng(count_related, D, count(Rel, P)) :- !, related(D, Rel, _, P).
eng(sum_related, D, sum(Rel, F, P)) :- !, related(D, Rel, F, P).
eng(no_match, D, no_match(X, Ps)) :- !, get_dict(subject, D, S), eng(S, X), ( get_dict(patterns, D, Ps0) -> maplist(lit_or_eng, Ps0, Ps) ; Ps = [] ).
eng(K, D, other(K, D)).

lit_or_eng(D, R) :- eng(D, R).

related(D, Rel, F, P) :-
    get_dict(relation, D, R0), local_name(R0, Rel),
    ( get_dict(value, D, V), V \== null -> ( get_dict(name, V, F0) -> atom_string(F, F0) ; eng(V, F) ) ; F = none ),
    ( get_dict(where, D, W), W \== null -> ( get_dict(kind, W, _) -> eng(W, P) ; get_dict(name, W, P0) -> atom_string(P1, P0), P = derived(P1) ) ; P = none ).

local_name(S, N) :-
    atom_string(A, S),
    (   sub_atom(A, B, 1, _, '#') -> B1 is B + 1, sub_atom(A, B1, _, 0, F0) ; F0 = A ),
    ( atom_concat('relation.', F, F0) -> N = F ; N = F0 ).

lit(V, R) :-
    get_dict(kind, V, K0), atom_string(K, K0), get_dict(value, V, X),
    (   memberchk(K, [integer, decimal]) -> ( number(X) -> N = X ; number_string(N, X) ), F is N * 1.0, R = num(F)
    ;   K == bool -> ( X == true -> R = bool(true) ; R = bool(false) )
    ;   K == text -> atom_string(_, X), string_to_atom(XS, X), R = text(XS)
    ;   R = lit(K, X)
    ).

op("lt", <).
op("lte", =<).
op("gt", >).
op("gte", >=).
op("eq", ==).
op("ne", \=).

		 /*******************************
		 *        NORMALISATION         *
		 *******************************/

%   Chains of an associative operator as one list; a comparison of a
%   Boolean with true in judgment position and the bare judgment are kept
%   as they are on both sides.
flat(T, R) :-
    (   T =.. [Op, Xs], memberchk(Op, [add, mul, and, or]), is_list(Xs)
    ->  maplist(flat, Xs, Ys), foldl(splice(Op), Ys, [], Zs0), reverse(Zs0, Zs), R =.. [Op, Zs]
    ;   compound(T), \+ T = text(_), \+ T = num(_)
    ->  T =.. [F|As], maplist(flat_arg, As, Bs), R =.. [F|Bs]
    ;   R = T
    ).

flat_arg(A, B) :- ( is_list(A) -> maplist(flat, A, B) ; flat(A, B) ).

splice(Op, Y, Acc, Acc1) :-
    (   Y =.. [Op, Zs], is_list(Zs) -> reverse(Zs, RZ), append(RZ, Acc, Acc1) ; Acc1 = [Y|Acc] ).

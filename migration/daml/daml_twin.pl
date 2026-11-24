/** <module> Daml -> Logical English for LPS: the twin of a Daml project

    Phase 2g (the design notes roadmap.md §6.6, §8). A Daml project (its
    templates and its Daml Script tests, daml_model.pl) becomes a migration
    (le_migration.pl) in LE for LPS:

      - a contract instance is a fluent keyed by its contract id, its
        fields (flattened) the other places: `*an asset* has issuer *an
        issuer*, owner *an owner* and name *a name*`;
      - creating a template is an action of the submitting party, a choice an
        action of its controller on a contract id; the ids of the contracts
        a command creates are places of the action, supplied by the caller —
        the ledger assigns them, a scenario names them (`aliceTV`);
      - a create initiates the new contract's fluent, an archive (and a
        consuming choice, of its own contract) terminates one; `fetch` is a
        condition that the contract is active; `let` computes; a nested
        `exercise` is inlined, and a contract created and consumed in the
        same transaction never reaches the state (Daml's transient
        contracts);
      - who may do what is integrity constraints — the submitter of a create
        must be its signatories, the exerciser of a choice its controllers,
        the contract must be active, and `ensure`, `assert`, `assertMsg`
        and `===` must hold — so a command Daml rejects is a call LPS2
        refuses, which is what `submitMustFail` expects;
      - each Daml Script becomes a scenario: its commands observed one per
        cycle, its parties constants (their hints), its contract ids the
        names the script binds them to.

    What the subset does not cover (keys, interfaces, `case`, time, helper
    functions in choices) is residue, each with its reason.
*/

:- module(daml_twin, [
    project_migrations/3,   % +Project, +Options, -Migrations
    compile_project/3,      % +Model, -Twin, -Notes
    twin_vocabulary/2       % +Twin, -Vocabulary (for the oracle's comparison)
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(pairs)).
:- use_module(daml_syntax).
:- use_module(daml_model).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer)).

		 /*******************************
		 *          VOCABULARY          *
		 *******************************/

%   The fluent of a template T: t(Cid, Leaf1, ...).
tpl_functor(T, F) :- snake(T, F).
create_functor(T, F) :- snake(T, S), atom_concat(create_, S, F).
archive_functor(T, F) :- snake(T, S), atom_concat(archive_, S, F).

%   A choice's action: its name (snake case), prefixed with its template's
%   when two templates have a choice of that name.
choice_functor(Model, T, C, F) :-
    snake(C, S),
    Model = model(_, Ts, _, _, _),
    (   member(tpl(T2, _, _, _, _, _, Chs, _), Ts), T2 \== T, memberchk(ch(_, C, _, _, _, _), Chs)
    ->  snake(T, ST), atomic_list_concat([ST, S], '_', F)
    ;   F = S
    ).

path_words(Path, W) :- maplist([P, Ws]>>words(P, Ws), Path, Wss), append(Wss, Ws1), atomic_list_concat(Ws1, ' ', W).

type_words(T, W) :- words(T, Ws), atomic_list_concat(Ws, ' ', W).

article(W, A) :- sub_atom(W, 0, 1, _, C), ( memberchk(C, [a, e, i, o, u]) -> A = an ; A = a ).

slot(W, S) :- article(W, A), format(atom(S), '*~w ~w*', [A, W]).

%   The words of a place holding a field: `cash amount`, `observers party
%   list` (a list of parties says so: the way back, daml_export.pl, reads a
%   `party list` place as `[Party]`), `values list`.
field_place(fld(Path, Ty), W) :-
    path_words(Path, W0),
    (   Ty = list(con('Party', [])) -> atom_concat(W0, ' party list', W)
    ;   Ty = list(_) -> atom_concat(W0, ' list', W)
    ;   W = W0
    ).

and_list([P], P) :- !.
and_list(Ps, L) :- append(Init, [Last], Ps), atomic_list_concat(Init, ', ', I), format(atom(L), '~w and ~w', [I, Last]).

%   `*an asset* is an asset with issuer *an issuer*, owner *an owner* and
%   name *a name*` — the template's name in the words, so that two
%   templates with the same fields (an invite and what it grants) never
%   read alike.
fluent_text(T, Flat, Text) :-
    type_words(T, TW), slot(TW, S0), article(TW, A),
    (   Flat == [] -> format(atom(Text), '~w is an active ~w', [S0, TW])
    ;   fields_text(Flat, L), format(atom(Text), '~w is ~w ~w with ~w', [S0, A, TW, L])
    ).

fields_text(Flat, L) :-
    findall(P, ( member(F, Flat), field_place(F, W), slot(W, SW), format(atom(P), '~w ~w', [W, SW]) ), Ps),
    and_list(Ps, L).

%   `*a party* creates the asset *an asset* with issuer *an issuer*, ...`
%   (the contract named as its archive and its choices name it)
create_text(T, Flat, Text) :-
    type_words(T, TW), slot(TW, S0),
    (   Flat == [] -> format(atom(Text), '*a party* creates the ~w ~w', [TW, S0])
    ;   fields_text(Flat, L), format(atom(Text), '*a party* creates the ~w ~w with ~w', [TW, S0, L])
    ).

%   `*a party* archives *an asset*` (every template's Archive choice)
archive_text(T, Text) :- type_words(T, TW), slot(TW, S0), format(atom(Text), '*a party* archives the ~w ~w', [TW, S0]).

%   `*a party* exercises give on *an asset* with new owner *a new owner*
%   creating *a second asset*`
choice_text(T, C, Args, NewTs, Text) :-
    type_words(T, TW), words(C, CWs0), chop_template_words(T, CWs0, CWs), atomic_list_concat(CWs, ' ', CW),
    findall(W, ( member(F, Args), field_place(F, W) ), AWs),                % (Args: the flat leaves)
    findall(W, ( member(NT, NewTs), type_words(NT, W) ), NewWs0),
    ordinal_slots([party, TW|NewWs0], [SP, ST|NewSs0], _),
    findall(P, ( member(W, AWs), slot(W, SW), format(atom(P), '~w ~w', [W, SW]) ), APs),
    (   APs == [] -> AT = '' ; and_list(APs, AL), format(atom(AT), ' with ~w', [AL]) ),
    (   NewSs0 == [] -> NT0 = '' ; and_list(NewSs0, NL), format(atom(NT0), ' creating ~w', [NL]) ),
    format(atom(Text), '~w exercises ~w on the ~w ~w~w~w', [SP, CW, TW, ST, AT, NT0]).

%   Iou_Transfer on an iou: `transfer` (the template's name is said by the
%   place already).
chop_template_words(T, CWs0, CWs) :-
    words(T, TWs), ( append(TWs, Rest, CWs0), Rest \== [] -> CWs = Rest ; CWs = CWs0 ).

%   Slots of a list of type words, a repeated one with its ordinal.
ordinal_slots(Ws, Ss, Counts) :-
    foldl([W, C0-Acc, C-[S|Acc]]>>( ( select(W-K0, C0, C1) -> K is K0 + 1 ; K = 1, C1 = C0 ), C = [W-K|C1],
                                    ( K =:= 1 -> W1 = W ; nth1(K, [first, second, third, fourth, fifth], O) -> format(atom(W1), '~w ~w', [O, W]) ; format(atom(W1), '~w ~w', [W, K]) ),
                                    slot(W1, S) ),
          Ws, []-[], Counts-Rev),
    reverse(Rev, Ss).

		 /*******************************
		 *        COMPILING A PROJECT   *
		 *******************************/

%!  compile_project(+Model, -Twin, -Notes) is det.
%
%   Twin = twin(Model, Tpls, Choices): Tpls [tv(T, Flat, Functor)],
%   Choices [cv(T, C, Functor, Args, NewTs, Kind, Items | failed(Why))];
%   Items the IR items (comments, lps laws and constraints) of each.
compile_project(Model, twin(Model, TVs, CVs), Notes) :-
    Model = model(Datas, Ts, _, _, _),
    nb_setval(daml_notes, []), nb_setval(daml_datas, Datas),
    findall(tv(T, Flat, F), ( member(tpl(T, _, Flat, _, _, _, _, _), Ts), tpl_functor(T, F) ), TVs),
    findall(T-Ch, ( member(tpl(T, _, _, _, _, _, Chs, _), Ts), member(Ch, Chs) ), TChs),
    maplist(compile_choice(Model), TChs, CVs),
    nb_getval(daml_notes, N0), reverse(N0, Notes).

note(N) :- nb_getval(daml_notes, Ns), nb_setval(daml_notes, [N|Ns]).

%   The fluent of a contract, with fresh variables for its leaves.
contract_fluent(Model, T, Cid, Pairs, Fluent) :-
    template_named(Model, T, tpl(_, _, Flat, _, _, _, _, _)),
    tpl_functor(T, F),
    findall(P-_, member(fld(P, _), Flat), Pairs),
    pairs_values(Pairs, Vs),
    Fluent =.. [F, Cid|Vs].

%   The create action's laws and constraints.
create_items(Model, T, Items) :-
    template_named(Model, T, tpl(_, _, Flat, Sigs, _, Ens, _, _)),
    create_functor(T, CF),
    contract_fluent(Model, T, Cid, Pairs, Fl),
    pairs_values(Pairs, Vs),
    Act =.. [CF, P, Cid|Vs],
    H = happens(Act, T1, T2),
    contract_record(Model, T, Pairs, This),
    Env = env(Model, T, This, []),
    Law = lps(initiated(H, Fl, [])),
    %  the submitter must be every signatory
    signatory_values(Sigs, Env, SVs),
    findall(lps(d_pre([H|B])), ( member(S, SVs), not_party(S, P, B) ), SigCs),
    ensure_constraints(Ens, Env, [H], EnsCs),
    active_constraint_new(Model, T, Cid, H, T1, NewC),
    format(string(C0), "~w: a party creates one; its signatories must be the one who submits (Daml's authorization)", [T]),
    length(Flat, _), ignore(T2 = _),
    %  Archive, the choice every template has: its controllers are the signatories
    archive_functor(T, AF),
    contract_fluent(Model, T, ACid, APairs, AFl),
    AAct =.. [AF, AP, ACid], AH = happens(AAct, AT1, _),
    AEnv = env(Model, T, rec(T, APairs), []),
    signatory_values(Sigs, AEnv, ASVs),
    findall(lps(d_pre([AH, holds(AFl, AT1)|B])), ( member(S, ASVs), not_party(S, AP, B) ), ASigCs),
    contract_fluent(Model, T, ACid, _, AnyFl),
    format(string(C1), "~w: archiving one (Daml's Archive choice) is for its signatories, and it must be active", [T]),
    append([[comment(C0), Law], SigCs, EnsCs, [NewC],
            [comment(C1), lps(terminated(AH, AFl, [holds(AFl, AT1)]))], ASigCs,
            [lps(d_pre([AH, holds(not(AnyFl), AT1)]))]], Items).

%   A contract id is new (the ledger never reuses one).
active_constraint_new(Model, T, Cid, H, T1, lps(d_pre([H, holds(F, T1)]))) :-
    contract_fluent(Model, T, Cid, _, F).

%   `ensure e`: for each way e can be false, a constraint (a conjunct the
%   twin cannot state is a comment, and a note; the others stay).
ensure_constraints(Ens0, Env, Pre, Items) :-
    foldl([E, A0, A]>>( conjuncts(E, Cs), append(A0, Cs, A) ), Ens0, [], Ens),
    findall(Is, ( member(E, Ens),
                  catch(( findall(lps(d_pre(Body)), ( falsity(E, Env, Neg), append(Pre, Neg, Body) ), Is) -> true ; Is = [] ),
                        unsupported(W), ( why(W, Why), Env = env(_, T, _, _),
                                          format(string(C), "ensure of ~w not stated: ~w", [T, Why]), note(C), Is = [comment(C)] )) ),
            Iss),
    append(Iss, Items).

		 /*******************************
		 *           EXPRESSIONS        *
		 *******************************/

%   env(Model, Template, This, Bindings): Bindings [Name-Value].
%   A value: an IR term (a variable, a constant, arithmetic), rec(T, Pairs)
%   (a record, its leaves by path), cid(T, Term), tuple(Vs), unit.

eval(var(N), env(_, _, This, Bs), V) :- !,
    (   memberchk(N-V0, Bs) -> V = V0
    ;   This = rec(TT, Pairs), sub_record(TT, Pairs, N, V1) -> V = V1
    ;   N == 'True' -> V = true
    ;   throw(unsupported(var(N)))
    ).
eval(this, env(_, _, This, _), This) :- !.
eval(num(N), _, N) :- !.
eval(str(S), _, S) :- !.
eval(con('True'), _, true) :- !.
eval(con('False'), _, false) :- !.
eval(con('None'), _, none) :- !.
eval(unit, _, unit) :- !.
eval(neg(E), Env, V) :- !, eval(E, Env, V0), ( number(V0) -> V is -V0 ; V = -(V0) ).
eval(field(E, F), Env, V) :- !,
    eval(E, Env, R),
    (   nonvar(R), R = rec(RT, Pairs), sub_record(RT, Pairs, F, V1) -> V = V1
    ;   nonvar(R), R = tuple(Vs), atom_concat('_', I0, F), atom_number(I0, I), nth1(I, Vs, V1) -> V = V1
    ;   throw(unsupported(field(E, F)))
    ).
eval(op(Op, A, B), Env, V) :- memberchk(Op-POp, ['+'-(+), '-'-(-), '*'-(*), '/'-(/)]), !,
    eval(A, Env, VA), eval(B, Env, VB),
    (   number(VA), number(VB) -> T =.. [POp, VA, VB], V is T
    ;   V =.. [POp, VA, VB]
    ).
eval(op('<>', A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB),
    ( string(VA), string(VB) -> string_concat(VA, VB, V) ; throw(unsupported(op('<>', A, B))) ).
eval(op('::', A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB),
    ( is_list(VB) -> V = [VA|VB] ; throw(unsupported(list_update(op('::', A, B)))) ).
eval(op('$', F, X), Env, V) :- !, apply_to(F, X, E), eval(E, Env, V).
eval(tuple(Es), Env, tuple(Vs)) :- !, evals(Es, Env, Vs).
eval(list(Es), Env, Vs) :- !, evals(Es, Env, Vs).
eval(app(var(fst), [E]), Env, V) :- !, eval_as(E, Env, tuple([V|_])).
eval(app(var(snd), [E]), Env, V) :- !, eval_as(E, Env, tuple([_, V|_])).
eval(op('&&', A, B), _, _) :- !, throw(unsupported(op('&&', A, B))).
eval(E, _, _) :- E = op(_, _, _), throw(unsupported(E)).
eval(app(con('Some'), [E]), Env, V) :- !, eval(E, Env, V).
eval(app(var(F), [E]), Env, Vs) :- memberchk(F, [signatory, observer]), !,    % `signatory iou`: the record's
    eval_as(E, Env, rec(T, Pairs)), Env = env(M, _, _, _),
    (   template_named(M, T, tpl(_, _, _, Sigs, Obs, _, _, _)) -> true ; throw(unsupported(app(var(F), [E]))) ),
    ( F == signatory -> Es = Sigs ; Es = Obs ),
    party_values(Es, env(M, T, rec(T, Pairs), []), Vs).
eval(rec(E0, Upds), Env, V) :- !, record_value(E0, Upds, Env, V).
eval(E, _, _) :- throw(unsupported(E)).

%   A value of a given shape (a record, a contract id), or the expression
%   is outside the subset.
eval_as(E, Env, Pattern) :-
    eval(E, Env, V),
    (   nonvar(V), V = Pattern -> true ; throw(unsupported(E)) ).

%   (Named helpers rather than lambdas: a lambda copies the variables it
%   closes over, and these values share their variables with the laws.)
evals([], _, []).
evals([E|Es], Env, [V|Vs]) :- eval(E, Env, V), evals(Es, Env, Vs).

eval_args([], _, []).
eval_args([N-E|Es], Env, [N-V|Vs]) :- eval(E, Env, V), eval_args(Es, Env, Vs).

pick(New, Kept, P-_, P-X) :- ( memberchk(P-X, New) -> true ; memberchk(P-X, Kept) ).

let_bindings([], _, _, _, B, B).
let_bindings([N-E|Bs], M, T, Th, B0, B) :- eval(E, env(M, T, Th, B0), V), let_bindings(Bs, M, T, Th, [N-V|B0], B).

created_ensures(Ens0, Env, Cs, Bodies) :-
    foldl([E, A0, A]>>( conjuncts(E, C1), append(A0, C1, A) ), Ens0, [], Ens),
    created_ensures_(Ens, Env, Cs, Bodies).

created_ensures_([], _, _, []).
created_ensures_([En|Ens], Env, Cs, Bodies) :-
    catch(falsities(En, Env, Cs, Bs), unsupported(_), Bs = []),
    created_ensures_(Ens, Env, Cs, More), append(Bs, More, Bodies).

drop_create([], _, []).
drop_create([cr(I, T, P, C)|Cr], Id, Out) :- ( I == Id -> Out = Cr ; Out = [cr(I, T, P, C)|Out1], drop_create(Cr, Id, Out1) ).

apply_to(app(F, As), X, app(F, As1)) :- !, append(As, [X], As1).
apply_to(F, X, app(F, [X])).

%   The part of a record at a field: a leaf's value, or the sub-record.
sub_record(T, Pairs, F, V) :-
    (   memberchk([F]-V0, Pairs) -> V = V0
    ;   prefixed(Pairs, F, Sub), Sub \== []
    ->  ( record_type(T, F, D) -> true ; D = F ),
        V = rec(D, Sub)
    ).

%   The record type of a record-valued field (SimpleIou's cash: Cash).
record_type(T, F, D) :-
    nb_current(daml_datas, Datas),
    memberchk(data(T, Fs), Datas), memberchk(F-con(D, []), Fs), memberchk(data(D, _), Datas).

%   A contract as a record: its leaves the fluent's variables, a contract
%   id leaf a cid(T, Var) (so `fetch` and `exercise` know its template).
contract_record(Model, T, Pairs, rec(T, WPairs)) :-
    template_named(Model, T, tpl(_, _, Flat, _, _, _, _, _)),
    maplist(wrap_cid(Model), Flat, Pairs, WPairs).

wrap_cid(Model, fld(_, Ty), P-V, P-W) :- ( cid_type(Model, Ty, T2) -> W = cid(T2, V) ; W = V ).

%   The pairs under a field, without copying their values (no findall).
prefixed([], _, []).
prefixed([[F|Rest]-X|Ps], F, [Rest-X|Sub]) :- Rest \== [], !, prefixed(Ps, F, Sub).
prefixed([_|Ps], F, Sub) :- prefixed(Ps, F, Sub).

under(F, Sub, Pairs) :- maplist({F}/[P-X, [F|P]-X]>>true, Sub, Pairs).

%   `this with owner = newOwner`, `Asset with issuer = alice ...`,
%   `Cash with amount = 100.0 ...`.
record_value(con(C), Fs, Env, rec(C, Pairs)) :- !,
    Env = env(model(Datas, _, _, _, _), _, _, _),
    (   memberchk(data(C, Decl), Datas) -> true ; throw(unsupported(record(C))) ),
    foldl(decl_field(Fs, Env), Decl, [], Rev), reverse(Rev, Pss), append(Pss, Pairs).
record_value(E0, Upds, Env, rec(T, Pairs)) :-
    eval_as(E0, Env, rec(T, Pairs0)),
    foldl(update_field(Env), Upds, Pairs0, Pairs).

decl_field(Fs, Env, N-_Ty, Acc, [Ps|Acc]) :-
    (   memberchk(N-E, Fs) -> true ; throw(unsupported(missing_field(N))) ),
    eval(E, Env, V),
    (   nonvar(V), V = rec(_, Sub) -> under(N, Sub, Ps) ; Ps = [[N]-V] ).

update_field(Env, F-E, Pairs0, Pairs) :-
    eval(E, Env, V),
    exclude({F}/[P-_]>>( P = [F|_] ), Pairs0, Kept),
    (   nonvar(V), V = rec(_, Sub) -> under(F, Sub, New) ; New = [[F]-V] ),
    ( memberchk([F|_]-_, Pairs0) -> true ; throw(unsupported(no_field(F))) ),
    %  keep the declared order (no findall: the values must not be copied)
    maplist(pick(New, Kept), Pairs0, Pairs).

conjuncts(op('&&', A, B), Cs) :- !, conjuncts(A, CA), conjuncts(B, CB), append(CA, CB, Cs).
conjuncts(E, [E]).

%!  falsity(+Expr, +Env, -Conds) is nondet.
%
%   Each way a boolean expression can be false, as conditions: `a && b` is
%   false when a is or when b is; `a || b` when both are.
falsity(op('&&', A, B), Env, Cs) :- !, ( falsity(A, Env, Cs) ; falsity(B, Env, Cs) ).
falsity(op('||', A, B), Env, Cs) :- !, falsity(A, Env, CA), falsity(B, Env, CB), append(CA, CB, Cs).
falsity(app(var(not), [E]), Env, Cs) :- !, truth(E, Env, Cs).
falsity(E, Env, Cs) :- E = op(Op, _, _), memberchk(Op, ['==', '===']), record_eq_leaves(E, Env, _, _, XYs), !,
    member(X-Y, XYs), Cs = [X \= Y].
falsity(E, Env, Cs) :- E = op(Op, _, _), memberchk(Op, ['/=', '=/=']), record_eq_leaves(E, Env, _, _, XYs), !,
    maplist([X-Y, X = Y]>>true, XYs, Cs).
falsity(E, Env, [C]) :- comparison(E, Env, Op, X, Y), !, negate(Op, NOp), C =.. [NOp, X, Y].
falsity(E, _, _) :- throw(unsupported(condition(E))).

%!  falsities(+Expr, +Env, +Conds, -Bodies) is det.
%
%   Conds followed by each way Expr can be false — sharing the variables of
%   Env and Conds (a findall alone would copy them).
falsities(E, Env, Cs, Bodies) :-
    term_variables(Env-Cs, Vs),
    findall(Vs-Neg, falsity(E, Env, Neg), Ps),
    maplist(reconnect(Vs, Cs), Ps, Bodies).

reconnect(Vs, Cs, Vs-Neg, Body) :- append(Cs, Neg, Body).

truth(op('&&', A, B), Env, Cs) :- !, truth(A, Env, CA), truth(B, Env, CB), append(CA, CB, Cs).
truth(E, Env, [C]) :- comparison(E, Env, Op, X, Y), !, C =.. [Op, X, Y].
truth(E, _, _) :- throw(unsupported(condition(E))).

comparison(op(Op0, A, B), Env, Op, X, Y) :-
    memberchk(Op0-Op, ['=='-(=), '/='-(\=), '<'-(<), '<='-(=<), '>'-(>), '>='-(>=), '==='-(=), '=/='-(\=)]),
    eval(A, Env, X0), eval(B, Env, Y0), uncid(X0, X), uncid(Y0, Y),
    \+ ( nonvar(X), X = rec(_, _) ), \+ ( nonvar(Y), Y = rec(_, _) ).

uncid(V, V) :- var(V), !.
uncid(cid(_, V), V) :- !.
uncid(V, V).

%   Two records are equal when their leaves are (Daml's `==` on records).
record_eq_leaves(E, Env, A, B, XsYs) :-
    E = op(Op, A, B), memberchk(Op, ['==', '===', '/=', '=/=']),
    eval(A, Env, RA), eval(B, Env, RB), nonvar(RA), nonvar(RB),
    RA = rec(_, PA), RB = rec(_, PB),
    findall(P, member(P-_, PA), Ps),
    maplist(leaf_pair(PA, PB), Ps, XsYs).

leaf_pair(PA, PB, P, X-Y) :- memberchk(P-X0, PA), memberchk(P-Y0, PB), uncid(X0, X), uncid(Y0, Y).

negate(=, \=). negate(\=, =). negate(<, >=). negate(=<, >). negate(>, =<). negate(>=, <).

		 /*******************************
		 *            CHOICES           *
		 *******************************/

%   A choice compiled: cv(T, C, Functor, ArgPairs, NewTs, Kind, Result) with
%   Result items(Items, ResultTerm, NewIds) or failed(Why).
compile_choice(Model, T-ch(Kind, C, _Ty, Args, Ctrl, Body), cv(T, C, CF, ArgFlat, NewTs, Kind, Result)) :-
    choice_functor(Model, T, C, CF),
    Model = model(Datas, _, _, _, _), flat_fields(Datas, Args, ArgFlat),   % (a record argument: its leaves)
    catch(( choice_items(Model, T, Kind, C, Args, Ctrl, Body, CF, Items, NewTs0, Res) -> Outcome = ok
          ; Outcome = err(none) ),
          unsupported(What), Outcome = err(What)),
    (   Outcome == ok
    ->  Result = items(Items, Res), NewTs = NewTs0      % Res: NewIds-Value
    ;   Outcome = err(What1),
        ( What1 == none -> Why = "a construct the translator does not read" ; why(What1, Why) ),
        NewTs = [], Result = failed(Why),
        format(string(N), "~w.~w: ~w", [T, C, Why]), note(residue_choice(T, C, N))
    ).

why(var(N), W) :- !, format(string(W), "`~w` is not a field, an argument or a binding of the choice (a helper function?)", [N]).
why(record(C), W) :- !, format(string(W), "`~w` is not a record or template of the project", [C]).
why(list_update(E), W) :- !, expr_text(E, T),
    format(string(W), "`~w` adds to a list held in a place, which LE cannot yet say (a list is a value, not a collection a law changes)", [T]).
why(condition(E), W) :- !, expr_text(E, T), format(string(W), "the condition `~w` has no LE form here", [T]).
why(stmt(S), W) :- !, stmt_text(S, T), format(string(W), "the statement `~w` is outside the subset (time, case, abort, a helper)", [T]).
why(E, W) :- ( catch(expr_text(E, T), _, fail) -> true ; format(string(T), "~q", [E]) ),
    format(string(W), "`~w` is outside the subset", [T]).

stmt_text(bind(_, E), T) :- !, expr_text(E, T).
stmt_text(expr(E), T) :- !, expr_text(E, T).
stmt_text(S, T) :- format(string(T), "~q", [S]).

choice_items(Model, T, Kind, C, Args, Ctrl, Body, CF, Items, NewTs, Res) :-
    contract_fluent(Model, T, Cid, Pairs, Fl),
    maplist(arg_binding(Model), Args, ArgBs, ArgLeaves), append(ArgLeaves, AVs),
    contract_record(Model, T, Pairs, This0),
    authorizers(Model, T, Ctrl, env(Model, T, This0, ArgBs), Auth),
    Env0 = env(Model, T, This0, ['$authorizers'-Auth|ArgBs]),
    St0 = st(Env0, [holds(Fl, T1)], [], [], [], none),
    exec(Body, St0, St1),
    %  a consuming choice archives its own contract
    (   Kind == nonconsuming -> St2 = St1
    ;   St1 = st(E1, Cs1, Cr1, Ar1, Con1, R1), St2 = st(E1, Cs1, Cr1, [ar(T, Cid, Fl, [])|Ar1], Con1, R1)
    ),
    St2 = st(_, _, Creates0, Archives0, Constraints0, Res0),
    reverse(Creates0, Creates), reverse(Archives0, Archives), reverse(Constraints0, Constraints),
    maplist([cr(Id, _, _, _), Id]>>true, Creates, NewIds),     % (not findall: it would copy the ids)
    findall(NT, member(cr(_, NT, _, _), Creates), NewTs),
    Res = NewIds-Res0,
    append([[P, Cid], AVs, NewIds], ActArgs),
    Act =.. [CF|ActArgs],
    H = happens(Act, T1, _T2),
    %  the laws
    maplist(create_law(Model, H), Creates, CLaws),
    %  a contract archived twice in one transaction (merging a contract with
    %  itself): refused
    findall(lps(d_pre([H|B])), double_archive(Archives, B), DblCs),
    maplist(archive_law(H, T1), Archives, ALaws),
    %  the constraints: the exerciser is every controller; the contract is
    %  active; the ones the body states
    Env0 = env(_, _, _, _),
    findall(lps(d_pre([H, holds(Fl, T1), P \= K])), ( member(KE, Ctrl), eval(KE, Env0, K), \+ is_list(K) ), CtrlCs),
    contract_fluent(Model, T, Cid, _, AnyFl),
    ActiveC = lps(d_pre([H, holds(not(AnyFl), T1)])),
    findall(lps(d_pre([H|B])), member(B, Constraints), BodyCs),
    maplist(expr_text, Ctrl, CTs), atomic_list_concat(CTs, ', ', CT),
    format(string(Com), "~w.~w (~w): the controller (~w) must submit it, and the contract must be active", [T, C, Kind, CT]),
    append([[comment(Com)], ALaws, CLaws, CtrlCs, [ActiveC], BodyCs, DblCs], Items).

%   Two archives of contracts of one template, the ids equal.
double_archive(Archives, B) :-
    append(_, [ar(T, C1, _, Cs1)|Rest], Archives), member(ar(T, C2, _, _), Rest),
    append(Cs1, [C1 = C2], B).

%   A choice argument: a ContractId T is cid(T, Var); a record its leaves
%   (each a place of the action); else a plain value.
arg_binding(Model, N-Ty, N-Val, Leaves) :-
    (   cid_type(Model, Ty, T2) -> Val = cid(T2, V), Leaves = [V]
    ;   Ty = con(D, []), Model = model(Datas, _, _, _, _), memberchk(data(D, Fs), Datas)
    ->  flat_fields(Datas, Fs, Flat), findall(P-_, member(fld(P, _), Flat), Pairs), Val = rec(D, Pairs),
        pairs_values(Pairs, Leaves)
    ;   Val = V, Leaves = [V]
    ).

cid_type(_, con('ContractId', [con(T, [])]), T) :- !.
cid_type(Model, con(A, []), T) :- Model = model(_, _, _, _, Aliases), memberchk(A-Ty, Aliases), cid_type(Model, Ty, T).

%   The state of a symbolic transaction: st(Env, Conds, Creates, Archives,
%   Constraints, Result); Creates [cr(Id, T, Pairs, Conds)], Archives
%   [ar(T, Cid, Fluent, Conds)], each in reverse order.
exec([], St, St).
exec([S|Ss], St0, St) :- stmt(S, St0, St1), exec(Ss, St1, St).

stmt(let(Bs), st(env(M, T, Th, B0), Cs, Cr, Ar, Co, R), st(env(M, T, Th, B), Cs, Cr, Ar, Co, R)) :- !,
    let_bindings(Bs, M, T, Th, B0, B).
stmt(bind(P, E), St0, St) :- !, command(E, St0, St1, V), bind_pattern(P, V, St1, St).
stmt(expr(E), St0, St) :-                  % the block's value is its last statement's
    command(E, St0, St1, V),
    (   E = app(var(F), _), memberchk(F, [return, pure]) -> St = St1
    ;   St1 = st(En, Cs, Cr, Ar, Co, _), St = st(En, Cs, Cr, Ar, Co, V)
    ).

bind_pattern(var(N), V, st(env(M, T, Th, B), Cs, Cr, Ar, Co, R), st(env(M, T, Th, [N-V|B]), Cs, Cr, Ar, Co, R)) :- !.
bind_pattern(wild, _, St, St) :- !.
bind_pattern(tuple(Ps), tuple(Vs), St0, St) :- !,
    pairs_keys_values(PVs, Ps, Vs), foldl([P-V, S0, S]>>bind_pattern(P, V, S0, S), PVs, St0, St).
bind_pattern(P, _, _, _) :- throw(unsupported(stmt(bind(P, unit)))).

%   A statement of an Update block, symbolically.
command(op('$', F, X), St0, St, V) :- !, apply_to(F, X, E), command(E, St0, St, V).
command(app(var(create), [E]), St0, St, cid(T, Id)) :- !,
    St0 = st(Env, Cs, Cr, Ar, Co, R), Env = env(M, _, _, _),
    eval_as(E, Env, rec(T, Pairs)),
    ( template_named(M, T, tpl(_, _, _, _, _, Ens, _, _)) -> true ; throw(unsupported(record(T))) ),
    %  the created contract's `ensure`, with its values
    created_ensures(Ens, env(M, T, rec(T, Pairs), []), Cs, EnsCs),        % (an ensure it cannot state is noted at the create)
    %  the created contract's signatories must be among the transaction's
    %  authorizers (the controllers and the exercised contract's signatories)
    (   Env = env(_, _, _, Bs), memberchk('$authorizers'-Auth, Bs),
        template_named(M, T, tpl(_, _, _, CSigs, _, _, _, _))
    ->  signatory_values(CSigs, env(M, T, rec(T, Pairs), []), Sigs),    % (no findall: it would copy)
        foldl(unauthorized(Cs, Auth), Sigs, [], AuthCs)
    ;   AuthCs = []
    ),
    append([EnsCs, AuthCs, Co], Co1),
    St = st(Env, Cs, [cr(Id, T, Pairs, Cs)|Cr], Ar, Co1, R).
command(app(var(archive), [E]), St0, St, unit) :- !,
    St0 = st(Env, Cs, Cr, Ar, Co, R),
    eval_as(E, Env, cid(T, Cid)),
    (   select(cr(Id, _, _, _), Cr, Cr1), Id == Cid
    ->  St = st(Env, Cs, Cr1, Ar, Co, R)              % created in this transaction: never on the ledger
    ;   Env = env(M, _, _, _), contract_fluent(M, T, Cid, _, Fl),
        St = st(Env, [holds(Fl, _)|Cs], Cr, [ar(T, Cid, Fl, Cs)|Ar], Co, R)
    ).
command(app(var(fetch), [E]), St0, St, Rec) :- !,
    St0 = st(Env, Cs, Cr, Ar, Co, R),
    eval_as(E, Env, cid(T, Cid)),
    (   member(cr(Id, T, Pairs, _), Cr), Id == Cid
    ->  St = St0, Rec = rec(T, Pairs)
    ;   Env = env(M, _, _, _), contract_fluent(M, T, Cid, Pairs, Fl), contract_record(M, T, Pairs, Rec),
        contract_fluent(M, T, Cid, _, AnyFl),
        St = st(Env, [holds(Fl, _)|Cs], Cr, Ar, [[holds(not(AnyFl), _)|Cs]|Co], R)
    ).
command(app(var(assert), [E]), St0, St, unit) :- !, assertion_constraints(E, St0, St).
command(app(var(assertMsg), [_, E]), St0, St, unit) :- !, assertion_constraints(E, St0, St).
command(op(Op, A, B), St0, St, unit) :- memberchk(Op, ['===', '=/=']), !, assertion_constraints(op(Op, A, B), St0, St).
command(app(var(F), [E]), St0, St, V) :- memberchk(F, [return, pure]), !,
    St0 = st(Env, _, _, _, _, _), eval(E, Env, V),
    St0 = st(Env, Cs, Cr, Ar, Co, _), St = st(Env, Cs, Cr, Ar, Co, V).
command(app(var(exercise), [CidE, ChE]), St0, St, V) :- !, nested_exercise(CidE, ChE, St0, St, V).
command(app(var(debug), _), St, St, unit) :- !.
command(E, _, _, _) :- throw(unsupported(stmt(expr(E)))).

%   A signatory none of the authorizers is: the create is refused.
%   (none when the signatory is itself one of the authorizers; a list of
%   signatories, members(L): a member of it none of them is. An authorizer
%   that is a list the twin cannot rule out is not stated.)
unauthorized(_, Auth, S, Acc, Acc) :- member(A, Auth), A == S, !.
unauthorized(_, Auth, _, Acc, Acc) :- member(A, Auth), nonvar(A), A = members(_), !.
unauthorized(Cs, Auth, S, Acc, [B|Acc]) :- nonvar(S), S = members(L), !,
    differs_from_all(Auth, X, Ds),
    append(Cs, [member(X, L)|Ds], B).
unauthorized(Cs, Auth, S, Acc, [B|Acc]) :-
    differs_from_all(Auth, S, Ds),
    append(Cs, Ds, B).

%   The conditions of "S is not the party P": a list of signatories has a
%   member that is not P (Daml: each signatory must authorize).
not_party(S, P, [member(X, L), X \= P]) :- nonvar(S), S = members(L), !.
not_party(S, P, [P \= S]).

%   The signatories' values: a party, or members(L) for a list of them
%   (`signatory alreadySigned`).
signatory_values([], _, []).
signatory_values([E|Es], Env, Vs) :-
    (   list_field(E, Env), catch(eval(E, Env, L), unsupported(_), fail), var(L)
    ->  Vs0 = [members(L)]
    ;   party_values([E], Env, Vs0)
    ),
    signatory_values(Es, Env, Vs1), append(Vs0, Vs1, Vs).

list_field(E, env(M, T, _, _)) :-
    ( E = var(N) -> P = [N] ; E = field(var(A), F) -> P = [A, F] ),
    template_named(M, T, tpl(_, _, Flat, _, _, _, _, _)),
    memberchk(fld(P, list(_)), Flat).

differs_from_all([], _, []).
differs_from_all([A|As], S, [S \= A|Ds]) :- differs_from_all(As, S, Ds).

%   Who authorizes a choice's consequences: its controllers and the
%   signatories of its contract.
authorizers(Model, T, Ctrl, Env, Auth) :-
    template_named(Model, T, tpl(_, _, _, Sigs, _, _, _, _)),
    append(Ctrl, Sigs, Es),
    signatory_values(Es, Env, Auth).

%   The parties some expressions name (a list-valued one, `signatory iou`,
%   gives each of its members).
party_values([], _, []).
party_values([E|Es], Env, Vs) :-
    (   catch(eval(E, Env, V0), unsupported(_), fail)
    ->  ( is_list(V0) -> maplist(uncid, V0, Vs0) ; uncid(V0, V), Vs0 = [V] ) ; Vs0 = [] ),
    party_values(Es, Env, Vs1), append(Vs0, Vs1, Vs).

assertion_constraints(E, St0, St) :-
    St0 = st(Env, Cs, Cr, Ar, Co, R),
    falsities(E, Env, Cs, Bs),
    ( Bs == [] -> throw(unsupported(condition(E))) ; true ),
    append(Bs, Co, Co1),
    St = st(Env, Cs, Cr, Ar, Co1, R).

%   `exercise cid Choice with ...` inside a choice: the nested choice's body
%   run in this transaction (its contract fetched, or created earlier in it).
nested_exercise(CidE, ChE, St0, St, V) :-
    St0 = st(Env, Cs, Cr, Ar, Co, R),
    Env = env(M, _, _, _),
    eval_as(CidE, Env, cid(T2, Cid2)),
    (   ChE = rec(con(C2), As) -> true ; ChE = con(C2), As = [] ),
    template_named(M, T2, tpl(_, _, _, _, _, _, Chs2, _)),
    (   memberchk(ch(Kind2, C2, _, Args2, Ctrl2, Body2), Chs2) -> true ; throw(unsupported(con(C2))) ),
    (   member(cr(Id, T2, Pairs2, _), Cr), Id == Cid2
    ->  Transient = true, Cs1 = Cs
    ;   Transient = false, contract_fluent(M, T2, Cid2, Pairs2, Fl2), Cs1 = [holds(Fl2, _)|Cs]
    ),
    findall(N-Val0, ( member(N-_, Args2), ( memberchk(N-AE, As) -> true ; AE = var(N) ), Val0 = AE ), ArgEs),
    eval_args(ArgEs, Env, ArgBs),
    (   Transient == true -> This2 = rec(T2, Pairs2) ; contract_record(M, T2, Pairs2, This2) ),
    authorizers(M, T2, Ctrl2, env(M, T2, This2, ArgBs), Auth2),
    Env2 = env(M, T2, This2, ['$authorizers'-Auth2|ArgBs]),
    exec(Body2, st(Env2, Cs1, Cr, Ar, Co, none), st(_, Cs2, Cr2, Ar2, Co2, V)),
    (   Kind2 == nonconsuming -> Cr3 = Cr2, Ar3 = Ar2
    ;   Transient == true -> drop_create(Cr2, Cid2, Cr3), Ar3 = Ar2
    ;   contract_fluent(M, T2, Cid2, Pairs2, Fl3), Cr3 = Cr2, Ar3 = [ar(T2, Cid2, Fl3, Cs1)|Ar2]
    ),
    St = st(Env, Cs2, Cr3, Ar3, Co2, R).

%   A create's law: the new contract's fluent, its computed leaves
%   materialised as conditions (`a second amount = the amount - 40`).
create_law(Model, H, cr(Id, T, Pairs, Cs), lps(initiated(H, Fl, Conds))) :-
    tpl_functor(T, F),
    foldl(materialise, Pairs, []-[], Vs0-Comps0),
    reverse(Vs0, Vs), reverse(Comps0, Comps),
    Fl =.. [F, Id|Vs],
    fix_times(H, Cs, Cs1),
    append(Cs1, Comps, Conds),
    ignore(Model = _).

materialise(_-X, Vs-Cs, [X|Vs]-Cs) :- ( var(X) ; atomic(X) ; is_list(X) ), !.
materialise(_-cid(_, X), Vs-Cs, [X|Vs]-Cs) :- !.
materialise(_-X, Vs-Cs, [V|Vs]-[is(V, X)|Cs]).

archive_law(H, T1, ar(_, _, Fl, Cs), lps(terminated(H, Fl, Conds))) :-
    fix_times(H, Cs, Cs0),
    ( member(holds(F0, T1), Cs0), F0 == Fl -> Conds = Cs0 ; append(Cs0, [holds(Fl, T1)], Conds) ).

%   Every condition holds at the action's start.
fix_times(happens(_, T1, _), Cs0, Cs) :- maplist(fix_time(T1), Cs0, Cs).
fix_time(T1, holds(F, T), holds(F, T1)) :- !, ( var(T) -> T = T1 ; true ).
fix_time(_, C, C).

		 /*******************************
		 *            SCRIPTS           *
		 *******************************/

%!  script_observations(+Twin, +Fun, -Obs, -Skipped) is det.
%
%   A Daml Script run symbolically: Obs [obs(Action, MustFail, Text)] in
%   order; Skipped the statements with no observation (queries, asserts,
%   user management, time), as notes.
script_observations(Twin, fun(Mod, _N, [], E), Obs, Skipped) :-
    nb_setval(daml_script_ids, 0),
    script_body(E, Ss),
    run_stmts(Ss, Twin, Mod, [], _, [], ObsR, [], SkR, _),
    reverse(ObsR, Obs), reverse(SkR, Skipped).

script_body(app(var(script), [do(Ss)]), Ss) :- !.
script_body(op('$', var(script), do(Ss)), Ss) :- !.
script_body(do(Ss), Ss) :- !.
script_body(E, [expr(E)]).

run_stmts([], _, _, Env, Env, O, O, S, S, unit).
run_stmts([St|Sts], Twin, Mod, Env0, Env, O0, O, S0, S, Res) :-
    catch(run_stmt(St, Twin, Mod, Env0, Env1, O0, O1, S0, S1, R1), E,
          ( script_error(E, Why), Env1 = Env0, O1 = O0, S1 = [Why|S0], R1 = unit )),
    ( Sts == [] -> Res = R1, Env = Env1, O = O1, S = S1
    ; run_stmts(Sts, Twin, Mod, Env1, Env, O1, O, S1, S, Res) ).

run_stmt(let(Bs), _, _, Env0, Env, O, O, S, S, unit) :- !,
    foldl([N-E, E0, [N-V|E0]]>>sval(E, E0, V), Bs, Env0, Env).
run_stmt(bind(P, E), Twin, Mod, Env0, Env, O0, O, S0, S, unit) :- !,
    run_expr(E, Twin, Mod, Env0, Env1, O0, O, S0, S, V, P),
    sbind(P, V, Env1, Env).
run_stmt(expr(E), Twin, Mod, Env0, Env, O0, O, S0, S, V) :-
    run_expr(E, Twin, Mod, Env0, Env, O0, O, S0, S, V, wild).

sbind(var(N), V, Env, [N-V|Env]) :- !.
sbind(as(N, P), V, Env0, Env) :- !, sbind(P, V, [N-V|Env0], Env).
sbind(wild, _, Env, Env) :- !.
sbind(tuple(Ps), tuple(Vs), Env0, Env) :- !, pairs_keys_values(PVs, Ps, Vs), foldl([P-V, E0, E]>>sbind(P, V, E0, E), PVs, Env0, Env).
sbind(list(Ps), Vs, Env0, Env) :- is_list(Vs), length(Ps, N), length(Vs, N), !,
    pairs_keys_values(PVs, Ps, Vs), foldl([P-V, E0, E]>>sbind(P, V, E0, E), PVs, Env0, Env).
sbind(_, _, Env, Env).

%   A script statement's effect: parties, commands, calls of other scripts.
run_expr(op('$', F, X), Tw, M, E0, E, O0, O, S0, S, V, P) :- !, apply_to(F, X, Ex), run_expr(Ex, Tw, M, E0, E, O0, O, S0, S, V, P).
run_expr(app(var(A), [str(Hint)|_]), _, _, E, E, O, O, S, S, party(C), _) :-
    memberchk(A, [allocateParty, allocatePartyWithHint]), !, party_const(Hint, C).
run_expr(app(var(allocatePartyByHint), [app(con('PartyIdHint'), [str(Hint)])]), _, _, E, E, O, O, S, S, party(C), _) :- !,
    party_const(Hint, C).
run_expr(app(var(mapA), [var(allocateParty), LE]), _, _, E, E, O, O, S, S, Ps, _) :- !,   % (makePartiesFrom)
    sval(LE, E, Hints), maplist([H, party(C)]>>party_const(H, C), Hints, Ps).
run_expr(app(var(Sub), [PE, CmdE]), Tw, _, E, E, O0, O, S, S, V, P) :-
    memberchk(Sub-Fail, [submit-false, submitMustFail-true]), !,
    sval(PE, E, party(Party)),
    cmd_body(CmdE, Cmd),
    (   Cmd = app(var(createAndExerciseCmd), [RecE, ChE])
    ->  %  two commands in one transaction: observed as a create, then the
        %  exercise of the contract it created
        created_name(P, RecE, P1),
        command_action(app(var(createCmd), [RecE]), Tw, E, Party, P1, Act1, V1),
        command_action(app(var(exerciseCmd), [var('$created'), ChE]), Tw, ['$created'-V1|E], Party, P, Act2, V),
        O = [obs(Act2, Fail), obs(Act1, Fail)|O0]
    ;   command_action(Cmd, Tw, E, Party, P, Act, V),
        O = [obs(Act, Fail)|O0]
    ).
run_expr(do(Ss), Tw, M, E0, E, O0, O, S0, S, V, _) :- !,
    %  a nested block of a script (queries and asserts, usually)
    run_stmts(Ss, Tw, M, E0, E, O0, O, S0, S, V).
run_expr(Call, Tw, M, E0, E, O0, O, S0, S, V, _) :-
    ( Call = var(F), As = [] ; Call = app(var(F), As) ),
    Tw = twin(Model, _, _), Model = model(_, _, Funs, _, _),
    member(fun(_, F, Ps, Body), Funs), length(Ps, N), length(As, N), !,
    maplist({E0}/[A, SV]>>sval(A, E0, SV), As, AVs),
    pairs_keys_values(PBs, Ps, AVs), append(PBs, E0, Env1),
    script_body(Body, Ss),
    run_stmts(Ss, Tw, M, Env1, _, O0, O, S0, S, V), E = E0.
run_expr(app(var(F), [X]), _, _, E, E, O, O, S, S, V, _) :- memberchk(F, [return, pure]), !, sval(X, E, V).
run_expr(Ex, _, _, E, E, O, O, S, [Note|S], unit, _) :-
    expr_text(Ex, T), format(string(Note), "not observed (a query, an assertion, user management or time): ~w", [T]).

cmd_body(do([expr(C)]), C) :- !.
cmd_body(op('$', F, X), C) :- !, apply_to(F, X, C).
cmd_body(C, C).

party_const(Hint, C) :- string_lower(Hint, L), atom_string(C, L).

%   A script value: parties, contract ids, records, numbers, texts.
sval(var(N), Env, V) :- !, ( memberchk(N-V, Env) -> true ; throw(unsupported(var(N))) ).
sval(num(N), _, N) :- !.
sval(str(S), _, S) :- !.
sval(neg(E), Env, V) :- !, sval(E, Env, V0), V is -V0.
sval(list(Es), Env, L) :- !, maplist({Env}/[E, V]>>sval(E, Env, V), Es, L).
sval(tuple(Es), Env, tuple(Vs)) :- !, maplist({Env}/[E, V]>>sval(E, Env, V), Es, Vs).
sval(app(var(fst), [E]), Env, V) :- !, sval(E, Env, tuple([V|_])).
sval(app(var(snd), [E]), Env, V) :- !, sval(E, Env, tuple([_, V|_])).
sval(con('True'), _, true) :- !.
sval(con('False'), _, false) :- !.
sval(op(Op, A, B), Env, V) :- memberchk(Op, [+, -, *, /]), !, sval(A, Env, VA), sval(B, Env, VB), T =.. [Op, VA, VB], V is T.
sval(field(E, F), Env, V) :- !, sval(E, Env, R),
    (   nonvar(R), R = srec(_, Fs), memberchk(F-V, Fs) -> true
    ;   nonvar(R), R = rec(_, Pairs), memberchk([F]-V, Pairs) -> true      % a choice's result record
    ;   throw(unsupported(field(E, F)))
    ).
sval(rec(con(C), Fs), Env, srec(C, Vs)) :- !, maplist({Env}/[F-E, F-V]>>sval(E, Env, V), Fs, Vs).
sval(E, _, _) :- throw(unsupported(E)).

%   A command as the twin's action (ground): its new contract ids named after
%   what the script binds the result to.
%   The contract a createAndExerciseCmd creates: named after the result's
%   binding and its template (`iou_transfer_alice_cid_iou`).
created_name(var(N), rec(con(T), _), var(N1)) :- !, snake(T, ST), format(atom(N1), '~w_~w', [N, ST]).
created_name(_, _, wild).

command_action(app(var(createCmd), [RecE]), Tw, Env, Party, P, Act, cid(T, Id)) :- !,
    RecE = rec(con(T), Fs),
    Tw = twin(Model, _, _),
    record_leaves(Model, T, Fs, Env, Vals),
    new_id(P, T, 1, 1, Id),
    create_functor(T, CF),
    append([Party, Id], Vals, As), Act =.. [CF|As].
command_action(app(var(exerciseCmd), [CidE, con('Archive')]), Tw, Env, Party, P, Act, Res) :- !,   % (every template's Archive)
    command_action(app(var(archiveCmd), [CidE]), Tw, Env, Party, P, Act, Res).
command_action(app(var(exerciseCmd), [CidE, ChE]), Tw, Env, Party, P, Act, Res) :- !,
    sval(CidE, Env, cid(T, Cid)),
    (   ChE = rec(con(C), As) -> true ; ChE = con(C), As = [] ),
    Tw = twin(_, _, CVs),
    (   member(cv(T, C, CF, Args, NewTs, _, items(_, ResTerm)), CVs) -> true
    ;   member(cv(T, C, _, _, _, _, failed(Why)), CVs) -> throw(residue_choice(T, C, Why))
    ;   throw(unsupported(con(C)))
    ),
    findall(V, ( member(fld(Path, _), Args), leaf_value(Path, As, Env, V) ), AVs),
    length(NewTs, K),
    findall(Id, ( nth1(I, NewTs, NT), new_id(P, NT, I, K, Id) ), Ids),
    maplist(unwrap_party, AVs, AVs1),
    append([[Party, Cid], AVs1, Ids], ActArgs), Act =.. [CF|ActArgs],
    copy_term(ResTerm, Ids-Res).
command_action(app(var(archiveCmd), [CidE]), _, Env, Party, _, Act, unit) :- !,
    sval(CidE, Env, cid(T, Cid)),
    archive_functor(T, AF), Act =.. [AF, Party, Cid].
command_action(C, _, _, _, _, _, _) :- throw(unsupported(C)).

%   The ids a command creates: the name the script binds a single one to,
%   else that name numbered, else c1, c2, ...
new_id(var(N), _, _, 1, Id) :- !, snake(N, Id).
new_id(var(N), _, I, _, Id) :- !, snake(N, S), format(atom(Id), '~w_~w', [S, I]).
new_id(tuple(Ps), _, I, K, Id) :- length(Ps, K), nth1(I, Ps, var(N)), !, snake(N, Id).
new_id(_, _, _, _, Id) :- nb_getval(daml_script_ids, N0), N is N0 + 1, nb_setval(daml_script_ids, N), format(atom(Id), 'c~w', [N]).

record_leaves(Model, T, Fs, Env, Vals) :-
    template_named(Model, T, tpl(_, _, Flat, _, _, _, _, _)),
    findall(V, ( member(fld(Path, _), Flat), leaf_value(Path, Fs, Env, V) ), Vals).

leaf_value([F], Fs, Env, V) :- !, ( memberchk(F-E, Fs) -> true ; E = var(F) ), sval(E, Env, V0), unwrap_party(V0, V).
leaf_value([F|Rest], Fs, Env, V) :-
    ( memberchk(F-E, Fs) -> true ; E = var(F) ),
    (   E = rec(con(_), Sub) -> leaf_value(Rest, Sub, Env, V)
    ;   sval(E, Env, srec(_, SVs)), Rest = [G], memberchk(G-V0, SVs), unwrap_party(V0, V)
    ).

unwrap_party(party(C), C) :- !.
unwrap_party(cid(_, C), C) :- !.
unwrap_party(L, L2) :- is_list(L), !, maplist(unwrap_party, L, L2).
unwrap_party(V, V).

		 /*******************************
		 *         THE MIGRATIONS       *
		 *******************************/

%!  project_migrations(+Project, +Options, -Migrations) is det.
%
%   Project = project(Id, Title, Files): the twin of the project's model
%   (Id.le), its first script as its scenario; each further script a
%   program of its own that extends it (Id_<script>.le). Migrations
%   [mig(Base, Migration)]. Options: sources(Names) (the files as kept
%   under sources/), final_states([Script-Fluents]) (the oracle's, as
%   comments).
project_migrations(project(Id, Title, Files), Options, Migs) :-
    project_model(Files, Model),
    compile_project(Model, Twin, Notes),
    findall(F, ( script_fun(Model, F), F = fun(_, _, [], _) ), Scripts0),
    main_first(Scripts0, Scripts),
    base_items(Twin, Title, Options, Header0, Items0),
    (   Scripts = [S1|More]
    ->  script_scenario(Twin, Header0, Items0, S1, Options, Scen1, Sk1, MaxT1),
        Header = [setting(max_time, MaxT1)|Header0],
        append(Items0, Scen1, Items),
        ledger(Twin, Notes, [S1-Sk1], Ledger),
        meta(Id, Title, Options, Meta),
        Base = mig(Id, migration(Meta, program(Header, Items), Ledger, [])),
        findall(mig(CId, migration(Meta, program([kb(CId), target(lps), extends([Id]), setting(max_time, MaxT), comment(C)], CItems), CLedger, [])),
                ( member(S, More), S = fun(_, SN, _, _), snake(SN, SS), atomic_list_concat([Id, SS], '_', CId),
                  script_scenario(Twin, Header0, Items0, S, Options, CItems, Sk, MaxT),
                  format(string(C), "The Daml Script ~w of the project ~w, run on its twin (~w.le, which this program extends).", [SN, Title, Id]),
                  findall(entry(E, script_statement, approximated, 'a statement with nothing to observe (a query, an assertion, user management, time)', SN, none),
                          member(E, Sk), CLedger) ), Children),
        Migs = [Base|Children]
    ;   Header = [setting(max_time, 2)|Header0],
        ledger(Twin, Notes, [], Ledger), meta(Id, Title, Options, Meta),
        Migs = [mig(Id, migration(Meta, program(Header, Items0), Ledger, []))]
    ).

%   The script to run first: `setup`, `main`, a `test...`, else the first.
main_first(Ss, [S|Rest]) :-
    (   member(P, [setup, main, test]), member(S, Ss), S = fun(_, N, _, _), sub_atom(N, 0, _, _, P) -> true
    ;   Ss = [S|_]
    ), !,
    exclude(==(S), Ss, Rest).
main_first([], []).

meta(Id, Title, Options, [program(Id), source('a Daml project (Daml 3, Canton)'), artifacts(Srcs),
                          translator('the Daml translator'), date(Date)]) :-
    option(sources(Srcs), Options, []),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    ignore(Title = _).

%   The program: templates as fluents, creates and choices as actions,
%   their laws and constraints, the residue.
base_items(Twin, Title, Options, Header, Items) :-
    Twin = twin(Model, TVs, CVs),
    Model = model(_, Ts, _, Others, _),
    option(id(Id), Options, twin),
    format(string(HC), "~w~n~nThe Logical English (for LPS) twin of a Daml project, written by the Daml translator~nfrom its source: each template a fluent keyed by the contract id, each create and choice an action,~nwho may do what integrity constraints. The source is kept in sources/ (File > Show the Original in the~nLogical English editor, View > The original this was converted from in the LPS2 IDE).~nThe ids of the contracts a command creates are places of its action: the ledger assigns them, a scenario names them.~nWho may do what, as one permission per command: the legal view~n(Misc > Legal View of This LPS Program in the Logical English editor, View > Legal view in the LPS2 IDE).", [Title]),
    Header = [kb(Id), target(lps), comment(HC)],
    findall(fluent(F, Text, [known_as(F)]), ( member(tv(T, Flat, F), TVs), fluent_text(T, Flat, Text) ), Fls),
    findall(action(CF, Text, [known_as(CF)]), ( member(tv(T, Flat, _), TVs), create_functor(T, CF), create_text(T, Flat, Text) ), CAs0),
    findall(action(AF, Text, [known_as(AF)]), ( member(tv(T, _, _), TVs), archive_functor(T, AF), archive_text(T, Text) ), AAs),
    append(CAs0, AAs, CAs),
    findall(action(CF, Text, [known_as(CF)]), ( member(cv(T, C, CF, Args, NewTs, _, items(_, _)), CVs), choice_text(T, C, Args, NewTs, Text) ), ChAs),
    option(sources(Srcs), Options, []),
    findall(document(D, [text(P)]), ( member(S, Srcs), atomic_list_concat(['sources/', S], P), format(atom(D), 'the source ~w', [S]) ), Docs),
    findall(I, ( member(tpl(T, _, _, _, _, _, _, Res), Ts),
                 template_items(Twin, T, Res, Is), member(I, Is) ), TItems),
    findall(residue(RId, [title(K), source(daml, Text), note("outside the subset the translator reads (a helper function, a key, an interface, a type class)")]),
            ( nth1(I, Others, other(M, K, Text)), \+ memberchk(K, [definition]), format(atom(RId), 'module_~w_~w', [M, I]) ), MRes0),
    maplist([residue(A, O), residue(B, O)]>>( atom_codes(A, Cs), maplist([C0, C1]>>( code_type(C0, alnum) -> C1 = C0 ; C1 = 0'_ ), Cs, Cs1), atom_codes(B, Cs1) ), MRes0, MRes),
    append([Fls, CAs, ChAs, Docs, TItems, MRes], Items).

%   A template's items: its create, its choices, its residue.
template_items(Twin, T, Res, Items) :-
    Twin = twin(Model, _, CVs),
    create_items(Model, T, CIs),
    findall(I, ( member(cv(T, _, _, _, _, _, items(Is, _)), CVs), member(I, Is) ), ChIs),
    findall(residue(RId, [title(Title), note(Why)]),
            ( member(cv(T, C, _, _, _, _, failed(Why)), CVs), format(atom(Title), 'choice ~w of ~w', [C, T]),
              snake(C, SC), snake(T, ST), format(atom(RId), '~w_~w', [ST, SC]) ), ChRes),
    findall(residue(RId, [title(K), source(daml, Text), note("inside the template, outside the subset (a key, an interface instance, a choice the reader did not parse)")]),
            ( nth1(I, Res, other(K, Text)), snake(T, ST), format(atom(RId), '~w_~w_~w', [ST, K, I]) ), TRes),
    append([CIs, ChIs, ChRes, TRes], Items0),
    maplist([X, Y]>>copy_term(X, Y), Items0, Items).         % each item its own variables

%   A script as a scenario: its commands observed at 1, 2, ...; a command
%   Daml must refuse marked as such.
script_scenario(Twin, Header, Items, Fun, Options, Scen, Skipped, MaxT) :-
    Fun = fun(_, SN, _, _),
    catch(( script_observations(Twin, Fun, Obs, Skipped) -> true ; Obs = [], Skipped = ["the script could not be read"] ),
          E, ( script_error(E, Why), Obs = [], Skipped = [Why] )),
    ir_dicts(program(Header, Items), Dicts),
    findall(Ls, ( nth1(I, Obs, obs(Act, Fail)), T2 is I + 1,
                  render_ground_literal(Dicts, Act, S),
                  format(atom(L), '~w from ~w to ~w.', [S, I, T2]),
                  ( Fail == true -> Ls = [comment("Daml refuses the next command (submitMustFail): the twin's integrity constraints refuse it"), raw(L)]
                  ; Ls = [raw(L)] ) ), LLs),
    append(LLs, Lines0),
    length(Obs, NO), MaxT is NO + 2,
    (   option(final_states(FSs), Options), memberchk(SN-FS, FSs)
    ->  findall(X, ( member(F, FS), format(string(X), "  - ~q", [F]) ), Xs), atomic_list_concat(Xs, '\n', XT),
        format(string(FC), "Daml (the script run on a Canton sandbox, or on the IDE Ledger of Daml Script when the script sets the time) ends with these active contracts (their payloads;~nthe ids are the ledger's):~n~w~nThe twin's final state under LPS2 (`lps state`) is compared with it by test_daml.pl.", [XT]),
        Final = [comment(FC)]
    ;   Final = []
    ),
    snake(SN, SS),
    Scen0 = [scenario(SS, [comment(C0)|Lines0], [])],
    format(string(C0), "the Daml Script ~w", [SN]),
    append(Final, Scen0, Scen).

script_error(unsupported(E), W) :- !, ( catch(expr_text(E, T), _, fail) -> true ; format(string(T), "~q", [E]) ),
    format(string(W), "the script uses `~w`, outside the subset: not observed", [T]).
script_error(residue_choice(T, C, Why), W) :- !, format(string(W), "the script exercises ~w.~w, a residue choice (~w): the scenario stops there", [T, C, Why]).
script_error(E, W) :- format(string(W), "the script could not be read (~q)", [E]).

		 /*******************************
		 *           THE LEDGER         *
		 *******************************/

ledger(Twin, Notes, ScriptSkips, Ledger) :-
    Twin = twin(Model, TVs, CVs),
    Model = model(_, Ts, _, Others, _),
    findall(entry(E, template, encoded, 'template -> a fluent keyed by the contract id; create -> an action (initiates it)', F, none),
            ( member(tv(T, _, F), TVs), format(string(E), "template ~w", [T]) ), L1),
    findall(entry(E, signatory, encoded, 'signatory -> the submitter of a create must be it (an integrity constraint)', T, none),
            ( member(tpl(T, _, _, Sigs, _, _, _, _), Ts), member(S, Sigs), expr_text(S, ST), format(string(E), "signatory ~w of ~w", [ST, T]) ), L2),
    findall(entry(E, observer, approximated, 'observer -> not in the twin: who sees a contract is Daml''s privacy model, not its state', T, none),
            ( member(tpl(T, _, _, _, Obs, _, _, _), Ts), member(O, Obs), expr_text(O, OT), format(string(E), "observer ~w of ~w", [OT, T]) ), L3),
    findall(entry(E, ensure, encoded, 'ensure -> an integrity constraint on every create', T, none),
            ( member(tpl(T, _, _, _, _, Ens, _, _), Ts), member(En, Ens), expr_text(En, ET), format(string(E), "ensure ~w (~w)", [ET, T]) ), L4),
    findall(entry(E, choice, encoded, 'choice -> an action of its controller: laws for its creates and archives, constraints for its controller, the active contract and its assertions', CF, none),
            ( member(cv(T, C, CF, _, _, K, items(_, _)), CVs), format(string(E), "~w choice ~w.~w", [K, T, C]) ), L5),
    findall(entry(E, choice, residue, 'a choice outside the subset', RId, Why),
            ( member(cv(T, C, _, _, _, K, failed(Why)), CVs), format(string(E), "~w choice ~w.~w", [K, T, C]),
              snake(C, SC), snake(T, ST), format(atom(RId), '~w_~w', [ST, SC]) ), L6),
    findall(entry(E, K, residue, 'inside a template, outside the subset', T, none),
            ( member(tpl(T, _, _, _, _, _, _, Res), Ts), member(other(K, Text), Res), first_line(Text, E) ), L7),
    findall(entry(E, K, residue, 'a module declaration outside the subset', M, none),
            ( member(other(M, K, Text), Others), \+ memberchk(K, [definition]), first_line(Text, E) ), L8),
    findall(entry(E, script, encoded, 'a Daml Script -> a scenario (its commands observed one per cycle)', S, none),
            ( member(S-_, ScriptSkips), format(string(E), "script ~w", [S]) ), L9a),
    findall(entry(E, script_statement, approximated, 'a statement with nothing to observe (a query, an assertion, user management, time)', SN, none),
            ( member(fun(_, SN, _, _)-Sk, ScriptSkips), member(E, Sk) ), L9b),
    findall(entry(N, note, approximated, N, none, none), ( member(N0, Notes), N0 \= residue_choice(_, _, _), format(string(N), "~w", [N0]) ), L10),
    append([L1, L2, L3, L4, L5, L6, L7, L8, L9a, L9b, L10], Ledger).

first_line(Text, L) :- split_string(Text, "\n", " ", [L0|_]), string_concat(L0, "", L).

%!  twin_vocabulary(+Twin, -Vocabulary) is det.
%   voc(T, Functor, [Path-Type]) per template: how a fluent's places are the
%   contract's leaves (the oracle's comparison reads the ledger by them).
twin_vocabulary(twin(_, TVs, _), Voc) :-
    findall(voc(T, F, Leaves), ( member(tv(T, Flat, F), TVs), findall(P-Ty, member(fld(P, Ty), Flat), Leaves) ), Voc).

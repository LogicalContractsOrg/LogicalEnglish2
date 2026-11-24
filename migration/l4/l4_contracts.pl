/** <module> L4 contracts → Logical English for LPS (step 3 of the design notes l4.md)

    An L4 file's contracts — its `DEONTIC` definitions — become one document
    in Logical English for LPS (LE for LPS), run by LPS2, and each of its
    `#TRACE` directives becomes a scenario of that document. The reading is
    L4's own evaluator's (jl4-core/src/L4/EvaluateLazy/Machine.hs, the
    `ContractFrame`s), found by reading it and checked by running it:

      - Every obligation, permission or prohibition that a contract can reach
        (a `PARTY … MUST/MAY/SHANT/DO …` of a contract function, in the
        context it is reached in) is a fluent. The fluent holds while the
        obligation is open. Its places are the party, the values the action
        must have, the deadline (a day: the day the obligation started plus
        its `WITHIN`), and the values of the function's inputs that what
        follows it needs.
      - L4's events are events of the document, with the day L4 gives them
        as their last place: `the seller does deliver the goods on day 10`.
        The document's own time only orders them, one event per cycle, so
        that two L4 events on the same day are still one after the other
        and a contract dated in serial days runs in a handful of cycles.
      - L4 looks at the events one by one. For each event, and each open
        obligation: if the event's day is after the obligation's deadline,
        the deadline is missed — noticed then, not when it passed — and the
        event is used up (it does not count towards what follows). Else, if
        the event is the obligation's party doing its action (and PROVIDED
        holds), the obligation is met. So each obligation has at most two
        causal laws: met (`when <the action> …`) and missed (`when something
        happens on day …`, a composite event any event is). There are no
        reactive rules: nothing happens that an event does not cause.
      - `HENCE` is what starts when an obligation is met (for `SHANT`, when
        its deadline passes); `LEST` when it is missed (for `SHANT`, when
        the action is done). Missing `HENCE` is FULFILLED; missing `LEST` is
        a breach that names the party and the deadline. `MAY` and `SHANT`
        with a missed deadline go on with `HENCE`.
      - A contract function called in `HENCE`/`LEST` (the promissory note
        calls itself with what is still owed) is entered there: its
        conditions become the law's conditions, and it starts the
        obligations it gives.
      - `A RAND B` / `A ROR B`: the contract has two parts, each with its own
        obligations and its own end; laws put the two ends together as L4
        does (and: both fulfilled, or the first breach; or: the first
        fulfilment, or both breached).
      - The values a contract computes (a deadline, an amount) are
        timeless rules of the document: L4 functions of numbers become
        function templates (`the next payment due date for … is *a
        number*`), records built at run time are spread over several places,
        records named in the program are individuals with a fact per field.

    What it does not cover it refuses, with the reason, per contract
    function; a trace of a refused contract is a pending scenario.
*/

:- module(l4_contracts, [
    contract_twin/3,          % +File, +Options, -Twin
    twin_migration/3,         % +Twin, +Options, -Migration
    trace_oracle_needs/2,     % +File, -Exprs (their text)
    words_of/2,               % +Name, -Words
    name_atom/2,              % +Name, -Atom
    contract_items/4          % +Ctx, -Items, -Tests, -Ledger (the rules half's hook)
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(pairs)).
:- use_module(library(readutil)).
:- use_module(library(yall)).
:- use_module(library(aggregate)).
:- use_module(l4_reader).
:- use_module(l4_print, []).
:- use_module(corpus).

:- thread_local
    pdef/5,          % Name, Params, Giveth, Body, Pos
    pcon/3,          % Con, Type, Fields
    ptype/2,         % Type, enum(Cons) | record(Fields) | synonym(T)
    passume/2,       % Name, Type
    pstructural/1,   % Type: a record type built while a contract runs
    node/2,          % Key, Info
    node_queue/1,    % Key
    item/2,          % Group, Item
    fn_done/1,       % Name (its rules are written)
    fn_template/3,   % Name, Functor, Arity
    counter/2,
    refused/2,       % Function, Reason
    used_event/1,    % Con
    party_con_fact/3,% Atom, Con, ArgAtoms
    field_fact_done/2.

%   findall/3 that keeps the variables of Ctx — the inputs the goal was
%   given — shared with the solutions: the alternatives of an expression
%   are about the same inputs. (Every other variable is each solution's.)
sfindall(Ctx, T, G, L) :-
    term_variables(Ctx, Vs),
    findall(Vs-T, G, L0),
    maplist(relink(Vs), L0, L).

relink(Vs, Cs-T, T) :- maplist([V, C]>>( var(C) -> C = V ; true ), Vs, Cs).

		 /*******************************
		 *            NAMES             *
		 *******************************/

%!  words_of(+Name, -Words) is det.
%
%   The lower-case words of an L4 name: a name in backquotes is split at
%   its spaces, a plain name at its capitals and digits (`CommissionerActor`
%   → `commissioner actor`, `testCharity` → `test charity`).
words_of(Name, Words) :-
    atom_string(Name, S1),
    split_string(S1, "'", "", [P0|Ps0]),        % `the charity's status`: `the charity status`
    maplist([P, Q]>>( sub_string(P, 0, 1, _, "s") -> sub_string(P, 1, _, 0, Q) ; Q = P ), Ps0, Qs),
    atomic_list_concat([P0|Qs], '', S0),
    split_string(S0, " _-", " _-", Parts0),
    exclude(==(""), Parts0, Parts),
    maplist(camel_words, Parts, Wss),
    append(Wss, Ws0),
    maplist([W, L]>>(string_lower(W, L0), atom_string(L, L0)), Ws0, Words0),
    exclude([W]>>(\+ atom_length(W, _) ; W == ''), Words0, Words).

camel_words(S, Ws) :-
    string_codes(S, Cs),
    camel(Cs, Wcs),
    maplist([C, W]>>string_codes(W, C), Wcs, Ws).

camel([], []).
camel([C|Cs], [[C|W]|Ws]) :-
    take_word(Cs, C, W, Rest),
    camel(Rest, Ws).

take_word([C|Cs], P, [C|W], R) :-
    \+ ( code_type(C, upper), \+ code_type(P, upper) ),
    \+ ( code_type(C, digit), \+ code_type(P, digit) ),
    \+ ( code_type(C, upper), code_type(P, upper), Cs = [N|_], code_type(N, lower) ),
    !, take_word(Cs, C, W, R).
take_word(Cs, _, [], Cs).

%!  name_atom(+Name, -Atom) is det.
%
%   The LE constant for an L4 name: its words joined by underscores.
name_atom(Name, Atom) :-
    words_of(Name, Ws),
    (   Ws == [] -> Atom = x
    ;   atomic_list_concat(Ws, '_', A0),
        ( sub_atom(A0, 0, 1, _, C), char_type(C, digit) -> atom_concat(n_, A0, Atom) ; Atom = A0 )
    ).

name_text(Name, Text) :- words_of(Name, Ws), atomic_list_concat(Ws, ' ', Text).

functor_of(Words, F) :-
    atomic_list_concat(Words, '_', F0),
    atom_codes(F0, Cs), include([C]>>(code_type(C, csym)), Cs, Cs1), atom_codes(F, Cs1).

article(W, A) :- sub_atom(W, 0, 1, _, C), ( memberchk(C, [a, e, i, o, u]) -> A = an ; A = a ).

slot(Noun, S) :- article(Noun, A), format(atom(S), '*~w ~w*', [A, Noun]).

		 /*******************************
		 *           PROGRAM            *
		 *******************************/

%   The program's definitions, its imports' (the libraries the evaluator
%   ships, from the corpus's copy of l4-ide) behind them.
load_program(File, Items) :-
    retract_all_program,
    l4_read_file(File, l4_module(Items, _)),
    forall(member(import(Lib, _), Items), load_library(Lib)),
    index_items(Items, own).

load_library(Lib) :-
    cache_dir(C),
    format(atom(F), '~w/jl4-core/libraries/~w.l4', [C, Lib]),
    (   exists_file(F)
    ->  l4_read_file(F, l4_module(Items, _)),
        forall(member(import(L2, _), Items), ( L2 == Lib -> true ; load_library(L2) )),
        index_items(Items, library)
    ;   true
    ).

retract_all_program :-
    retractall(pdef(_, _, _, _, _)), retractall(pcon(_, _, _)), retractall(ptype(_, _)),
    retractall(passume(_, _)), retractall(pstructural(_)).

index_items(Items, _) :-
    forall(member(I, Items), index_item(I)).

index_item(decide(_, sig(Gs, Giveth), appform(N, Args, _, _), Body, _, Pos)) :- !,
    params(Gs, Args, Ps),
    retractall(pdef(N, _, _, _, _)),       % the program's own wins over a library's
    assertz(pdef(N, Ps, Giveth, Body, Pos)).
index_item(declare(_, appform(T, _, _, _), enum(Cons), _, _)) :- !,
    findall(C, member(con(C, _), Cons), Cs),
    assertz(ptype(T, enum(Cs))),
    forall(member(con(C, Fs), Cons),
           ( findall(f(FN, FT), member(field(FN, FT, _, _), Fs), Fields),
             assertz(pcon(C, T, Fields)) )).
index_item(declare(_, appform(T, _, _, _), record(Fs), _, _)) :- !,
    findall(f(FN, FT), member(field(FN, FT, _, _), Fs), Fields),
    assertz(ptype(T, record(Fields))),
    assertz(pcon(T, T, Fields)).
index_item(declare(_, appform(T, _, _, _), synonym(S), _, _)) :- !,
    assertz(ptype(T, synonym(S))).
index_item(assume(_, appform(N, _, _, _), Ty, _, _)) :- !,
    assertz(passume(N, Ty)).
index_item(_).

%   The parameters of a definition: its GIVEN names (typed), else the names
%   of its application form (`f x y MEANS …`).
params(Gs, _, Ps) :- Gs \== [], !,
    findall(p(N, T), member(param(N, T, _), Gs), Ps).
params([], Args, Ps) :-
    findall(p(A, none), ( member(A, Args), atom(A) ), Ps).

type_name(tyapp('MAYBE', [T]), N) :- !, type_name(T, N).
type_name(tyapp(T, []), T) :- !.
type_name(T, T).

record_fields(T0, Fields) :-
    type_name(T0, T),
    ( ptype(T, synonym(S)) -> record_fields(S, Fields) ; ptype(T, record(Fields)) ).

deontic_type(tyapp('DEONTIC', _)).

		 /*******************************
		 *       THE TWIN OF A FILE     *
		 *******************************/

%!  contract_twin(+File, +Options, -Twin) is det.
%
%   Twin = twin(Id, Title, Items, Traces, Refused), where Items are
%   migration IR items (vocabulary, laws, rules, facts), Traces one
%   trace(Line, Contract, Args, Start, Events, Status) per #TRACE of the
%   file — Status `ok`, or `refused(Why)` — and Refused
%   refused(Function, Why) per contract function left out.
%
%   Options: id(Id), title(T), values(Pairs) — the ground values of trace
%   expressions the evaluator worked out (see ground_value/3).
contract_twin(File, Options, twin(Id, Title, Items, Traces, Refused)) :-
    option(id(Id), Options, contract),
    option(title(Title), Options, Id),
    setup_call_cleanup(
        reset_state,
        ( load_program(File, Model),
          mark_structural(Model),
          findall(tr(L, C, At, Evs), member(directive(trace(C, At, Evs), _, pos(L, _)), Model), Trs0),
          maplist(compile_trace(Options), Trs0, Traces),
          drain_nodes,
          findall(G-I, item(G, I), GIs),
          findall(refused(F, W), refused(F, W), Refused0), sort(Refused0, Refused),
          assemble(GIs, Items) ),
        reset_state).

reset_state :-
    retractall(node(_, _)), retractall(node_queue(_)), retractall(item(_, _)),
    retractall(fn_done(_)), retractall(fn_template(_, _, _)), retractall(counter(_, _)),
    retractall(refused(_, _)), retractall(used_event(_)), retractall(party_con_fact(_, _, _)),
    retractall(field_fact_done(_, _)).

%   A record type is structural — spread over places — when a contract
%   builds one while it runs (in a function that gives a contract, or in
%   the arguments of a call made in HENCE or LEST); else it is nominal: its
%   values are the program's named records, individuals with a fact per
%   field.
mark_structural(_) :-
    forall(( pdef(F, _, _, Body, _), contract_function(F),
             sub_term(S, Body), built_record(S, T) ),
           ( pstructural(T) -> true ; assertz(pstructural(T)) )),
    % a type whose values some such function receives as an argument built
    % by another definition (`Money WITH …` inside `USD n`)
    forall(( pdef(F, Ps, _, _, _), contract_function(F), member(p(_, Ty), Ps),
             type_name(Ty, T), ptype(T, record(_)),
             pdef(_, _, G, B, _), type_name(G, T), sub_term(S, B), built_record(S, T) ),
           ( pstructural(T) -> true ; assertz(pstructural(T)) )).

built_record(app_named(T, _), T) :- ptype(T, record(_)).
built_record(app(T, [_|_]), T) :- ptype(T, record(_)).

%   A function that gives a contract: declared so, or whose body is one.
contract_function(F) :- contract_function(F, 5).

contract_function(F, D) :-
    D > 0,
    pdef(F, _, G, B, _),
    (   deontic_type(G) -> true
    ;   G == none, contract_expr(B) -> true
    ;   G == none, alias_body(B, H), D1 is D - 1, contract_function(H, D1)     % `x MEANS f a b`
    ).

alias_body(app(H, _), H).
alias_body(where(E, _), H) :- alias_body(E, H).

contract_expr(E) :- sub_term(S, E), ( S = deontic(_, _, _, _, _, _, _) ; S = rand(_, _) ; S = ror(_, _) ), !.

		 /*******************************
		 *            TRACES            *
		 *******************************/

compile_trace(Options, tr(L, C, At, Evs), trace(L, C, At, Evs, Status)) :-
    catch(( trace_contract(C, F, Args),
            ( refused(F, Why) -> Status = refused(Why)
            ; start_contract(F, Options) -> trace_data(F, Args, At, Evs, Options, Status)
            ; refused(F, Why) -> Status = refused(Why)
            ; Status = refused("the contract could not be translated") ) ),
          E, ( message_text(E, W), Status = refused(W) )).

		 /*******************************
		 *    A TRACE'S GROUND VALUES   *
		 *******************************/

%   The values of a trace — the contract's inputs, the start, each event —
%   worked out here when the expression is a literal, a named value or a
%   constructor of those, else taken from what L4's evaluator printed for
%   it (Options values(TextPrintedPairs), made by the build from
%   trace_oracle_needs/2). Status: data(F, Start, Inputs, Events), or
%   refused(Why).
trace_data(F, Args, At, Evs, Options, Status) :-
    option(values(VPs), Options, []),
    catch(( fn_done(start_places(F, Places)),
            pdef(F, Ps, _, _, _),
            maplist(ground_value(VPs), Args, AVs),
            param_leaves(Ps, AVs, Inputs), length(Places, NP), length(Inputs, NP),
            ground_value(VPs, At, Start0), number_value(Start0, Start),
            maplist(event_data(VPs), Evs, EData),
            Status = data(F, Start, Inputs, EData) ),
          E, ( message_text(E, W), Status = refused(W) )).

number_value(V, V) :- number(V), !.
number_value(V, _) :- throw(unsupported(value(V))).

param_leaves(Ps, Vs, Leaves) :-
    maplist([p(_, T), V, L]>>value_leaves(T, V, L), Ps, Vs, Ls), append(Ls, Leaves).

value_leaves(T0, V, Leaves) :-
    type_name(T0, T),
    (   pstructural(T), record_fields(T, Fs)
    ->  ( V = rec(FVs) -> true ; throw(unsupported(value(V))) ),
        findall(L, ( member(f(FN, FT), Fs), memberchk(FN-FV, FVs), value_leaves(FT, FV, Ls), member(L, Ls) ), Leaves)
    ;   party_value_ground(V, A), Leaves = [A]
    ).

party_value_ground(V, _) :- var(V), !, throw(unsupported("an unknown value in a trace")).
party_value_ground(nom(A, _), A) :- !.
party_value_ground(V, V) :- ( number(V) ; string(V) ; atom(V) ), !.
party_value_ground(con(C, Vs), A) :- !, maplist(party_value_ground, Vs, As), party_value(con(C, As), A).
party_value_ground(V, _) :- throw(unsupported(value(V))).

event_data(VPs, event(P, A, T), ev(PA, Con, Leaves, Day)) :- !,
    ground_value(VPs, P, PV), party_value_ground(PV, PA),
    ground_value(VPs, T, TV), number_value(TV, Day),
    action_value(VPs, A, Con, Leaves).
event_data(VPs, app('WAIT UNTIL', [T]), clock(Day)) :- !,
    ground_value(VPs, T, TV), number_value(TV, Day).
event_data(_, E, _) :- throw(unsupported(E)).

action_value(VPs, app(C, Args), C, Leaves) :- pcon(C, _, Fields), !,
    maplist(ground_value(VPs), Args, Vs),
    maplist([f(_, FT), V, L]>>value_leaves(FT, V, L), Fields, Vs, Ls), append(Ls, Leaves),
    action_event(C, _, _).
action_value(_, E, _, _) :- throw(unsupported(E)).

%   A ground value: worked out here, or printed by L4's evaluator.
ground_value(_, E, V) :- symbolic_ground(E, V), !.
ground_value(VPs, E, V) :-
    expr_text(E, T),
    (   memberchk(T-Printed, VPs)
    ->  printed_value(Printed, V)
    ;   throw(unsupported(needs_evaluator(T)))
    ).

symbolic_ground(E, V) :- catch(sx(E, [], [a([], V)]), _, fail), ground_ok(V).

ground_ok(V) :- ( number(V) ; string(V) ; atom(V) ), !.
ground_ok(nom(A, _)) :- atom(A).
ground_ok(rec(FVs)) :- forall(member(_-V, FVs), ground_ok(V)).
ground_ok(con(_, Vs)) :- maplist(ground_ok, Vs).

printed_value(Printed, V) :-
    format(string(Src), "x MEANS ~w~n", [Printed]),
    l4_read_text(Src, l4_module(Items, _)),
    (   member(decide(_, _, _, Body, _, _), Items), symbolic_ground(Body, V) -> true
    ;   throw(unsupported(printed(Printed)))
    ).

%!  trace_oracle_needs(+File, -Texts) is det.
%   The expressions of the file's traces that only L4's evaluator can work
%   out (a date, a computed amount): their text, for #EVAL directives.
trace_oracle_needs(File, Texts) :-
    setup_call_cleanup(reset_state,
        ( load_program(File, Model), mark_structural(Model),
          findall(T, ( member(directive(trace(C, At, Evs), _, _), Model),
                       trace_parts(C, At, Evs, E), \+ symbolic_ground(E, _), expr_text(E, T) ), Ts0),
          sort(Ts0, Texts) ),
        reset_state).

trace_parts(app(_, Args), _, _, E) :- member(E, Args).
trace_parts(_, At, _, At).
trace_parts(_, _, Evs, E) :- member(Ev, Evs),
    (   Ev = event(P, A, T) -> ( E = P ; E = T ; A = app(_, As), member(E, As) )
    ;   Ev = app('WAIT UNTIL', [E])
    ).

trace_contract(app(F, Args), F, Args) :- contract_function(F), !.
trace_contract(E, _, _) :- throw(unsupported(trace_contract(E))).

message_text(unsupported(X), W) :- !, describe_unsupported(X, W).
message_text(E, W) :- format(string(W), "~q", [E]).

describe_unsupported(X, W) :- ( catch(expr_text(X, T), _, fail) -> true ; format(string(T), "~q", [X]) ),
    format(string(W), "outside what the translator covers: ~w", [T]).

expr_text(E, T) :- catch(with_output_to(string(T), l4_print:ex(E)), _, fail), !.
expr_text(E, T) :- format(string(T), "~q", [E]).

%   The contract's start: an event with the contract's inputs, and a law
%   that enters its body. Done once per contract function.
start_contract(F, _) :- fn_done(start(F)), !.
start_contract(F, _) :-
    assertz(fn_done(start(F))),
    pdef(F, Ps, _, _, _),
    (   catch(start_law(F, Ps), E, ( message_text(E, W), assertz(refused(F, W)), fail ))
    ->  true
    ;   ( refused(F, _) -> true ; assertz(refused(F, "the contract could not be translated")) ), fail
    ).

start_law(F, Ps) :-
    start_event(F, Ps, Ev, Places),
    Trigger = happens(Ev, _T1, _T2),
    Ev =.. [_, Day|ArgVals],
    places_scope(Places, ArgVals, Scope),
    enter(call(F, Scope), Day, top, Alts),
    Alts \== [],
    forall(member(a(Gs, Effs), Alts),
           ( add_law(start(F), Trigger, Gs, Effs),
             add_item(hist, hist(start(F), Ev, Day, Gs, Effs)) )).

%   The start event of contract F: `the contract <F> starts on day *a day*
%   with <input> *a …* and …`.
start_event(F, Ps, Ev, Places) :-
    maplist(param_places, Ps, Pls), append(Pls, Places),
    words_of(F, FWs),
    maplist(place_phrase, Places, Phr),
    (   Phr == [] -> With = ''
    ;   atomic_list_concat(Phr, ' and ', W0), atom_concat(' with ', W0, With)
    ),
    atomic_list_concat(FWs, ' ', FT),
    format(atom(Text), 'the contract ~w starts on day *a day*~w', [FT, With]),
    append([contract|FWs], [starts], FW), functor_of(FW, Fun),
    length(Places, NP), N is NP + 1, length(As, N),
    Ev =.. [Fun|As],
    declare(event, Fun, Text),
    assertz(fn_done(start_places(F, Places))).

%   The places of a parameter: one, or one per leaf of a structural record.
param_places(p(N, T), Places) :- type_places(N, [], T, Places).

type_places(N, Path, T0, Places) :-
    type_name(T0, T),
    (   pstructural(T), record_fields(T, Fs)
    ->  findall(Pl, ( member(f(FN, FT), Fs), append(Path, [FN], P1), type_places(N, P1, FT, Pl) ), Pls),
        append(Pls, Places)
    ;   Places = [place(N, Path, T)]
    ).

place_phrase(place(N, Path, T), P) :-
    maplist(words_of, [N|Path], Wss), append(Wss, Ws0), content_words(Ws0, Ws), atomic_list_concat(Ws, ' ', Words),
    place_noun(N, Path, T, Noun),
    slot(Noun, S),
    format(atom(P), '~w ~w', [Words, S]).

place_noun(N, Path, _, Noun) :-
    ( Path == [] -> last_words(N, Noun) ; last(Path, L), last_words(L, Noun) ).

last_words(N, W) :- words_of(N, Ws0), content_words(Ws0, Ws), atomic_list_concat(Ws, ' ', W).

%   The words of a name, without those LE reads as its own (`is`, `the`,
%   `of`, …) — a place named `is urgent` is `*an urgent*`.
content_words(Ws0, Ws) :-
    exclude([W]>>memberchk(W, [is, are, was, has, have, the, a, an, of, to, for, and, or, not, if, then, it, that, which, when]), Ws0, Ws1),
    ( Ws1 == [] -> Ws = [value] ; Ws = Ws1 ).

drop_article([A|Ws], Ws) :- memberchk(A, [the, a, an]), Ws \== [], !.
drop_article(Ws, Ws).

%   A scope from places and the variables that fill them.
places_scope(Places, Vals, Scope) :-
    pairs_keys_values(PV, Places, Vals),
    findall(N, member(place(N, _, _)-_, PV), Ns0), list_to_set(Ns0, Ns),
    sfindall(PV, N-v(V), ( member(N, Ns), sfindall(PV, Path-X-T, member(place(N, Path, T)-X, PV), L), rebuild(L, V) ), Scope).

rebuild([[]-X-T], V) :- !, typed_var(T, X, V).
rebuild(L, V) :- rebuild_rec(_, [], L, V).

rebuild_rec(_, Prefix, L, rec(Fs)) :-
    findall(F, ( member(P-_-_, L), append(Prefix, [F|_], P) ), Fs0), list_to_set(Fs0, FNs),
    sfindall(L, F-V, ( member(F, FNs), append(Prefix, [F], P1),
                   ( member(P1-X-T, L) -> typed_var(T, X, V) ; rebuild_rec(_, P1, L, V) ) ), Fs).

%   A runtime value of a nominal record type remembers its type, for the
%   facts a projection needs.
typed_var(T, X, V) :- ( ptype(T, record(_)), \+ pstructural(T) -> V = nom(X, T) ; V = X ).

		 /*******************************
		 *   ENTERING A CONTRACT VALUE  *
		 *******************************/

%   enter(+ContractExpr, +Day, +Ctx, -Alts): what starts when a contract
%   expression is reached on Day: alternatives a(Conditions, Effects), each
%   Effect initiate(Fluent). Ctx is `top`, or part(K) of a RAND/ROR.

enter(call(F, Scope), Day, Ctx, Alts) :- !,
    pdef(F, _, _, Body, _),
    enter_expr(Body, fn(F, Scope), Day, Ctx, Alts).

enter_expr(E, Env, Day, Ctx, Alts) :-
    enter_(E, Env, Day, Ctx, Alts), !.
enter_expr(E, _, _, _, _) :-
    throw(unsupported(E)).

enter_(where(E, Ds), fn(F, Scope), Day, Ctx, Alts) :- !,
    locals(Ds, Scope, Scope1),
    enter_expr(E, fn(F, Scope1), Day, Ctx, Alts).
enter_(let(Ds, E), Env, Day, Ctx, Alts) :- !,
    enter_(where(E, Ds), Env, Day, Ctx, Alts).
enter_(app('FULFILLED', []), _, _, Ctx, [a([], [initiate(Fl)])]) :- !,
    fulfilled_fluent(Ctx, Fl).
enter_(breach(By, Because), fn(_, Scope), _, Ctx, Alts) :- !,
    opt_value(By, Scope, BAlts),
    opt_value(Because, Scope, RAlts),
    sfindall(BAlts-RAlts, a(G, [initiate(Fl)]),
            ( member(a(G1, B), BAlts), member(a(G2, R), RAlts), append(G1, G2, G),
              breach_fluent(Ctx, explicit(B, R), Fl) ), Alts).
enter_(if(C, T, E), Env, Day, Ctx, Alts) :- !,
    Env = fn(_, Scope),
    cond(C, Scope, Yes), ncond(C, Scope, No),
    enter_expr(T, Env, Day, Ctx, TA), enter_expr(E, Env, Day, Ctx, EA),
    cross(Yes, TA, A1), cross(No, EA, A2), append(A1, A2, Alts).
enter_(branch(Cases, Otherwise), Env, Day, Ctx, Alts) :- !,
    branch_to_if(Cases, Otherwise, E), enter_(E, Env, Day, Ctx, Alts).
enter_(consider(X, Branches), Env, Day, Ctx, Alts) :- !,
    Env = fn(F, Scope),
    sx(X, Scope, XAlts),
    sfindall(XAlts-Scope-Day, A, ( member(a(G0, V), XAlts),
                 consider_alts(Branches, V, [], Scope, Pairs),
                 member(Conds-Scope1-Body, Pairs),
                 enter_expr(Body, fn(F, Scope1), Day, Ctx, BA),
                 member(a(G1, Effs), BA), append([G0, Conds, G1], G), A = a(G, Effs) ), Alts).
enter_(rand(A, B), Env, Day, top, Alts) :- !,
    enter_expr(A, Env, Day, part(1, and), A1), enter_expr(B, Env, Day, part(2, and), A2),
    cross_effects(A1, A2, Alts).
enter_(ror(A, B), Env, Day, top, Alts) :- !,
    enter_expr(A, Env, Day, part(1, or), A1), enter_expr(B, Env, Day, part(2, or), A2),
    cross_effects(A1, A2, Alts).
enter_(rand(_, _), _, _, part(_, _), _) :- !,
    throw(unsupported("a RAND or ROR inside a part of another one")).
enter_(ror(_, _), _, _, part(_, _), _) :- !,
    throw(unsupported("a RAND or ROR inside a part of another one")).
enter_(D, Env, Day, Ctx, Alts) :-
    D = deontic(_, _, _, _, _, _, _), !,
    Env = fn(F, Scope),
    node_key(F, D, Scope, Ctx, _Key, Info),
    Info = ninfo(_, _, _, _, Fl0, Needs, _),
    % the values the fluent keeps, worked out on entry
    node_entry(Info, D, Scope, Day, Fl0, Needs, Alts).
enter_(app(G, Args), fn(F, Scope), Day, Ctx, Alts) :-
    memberchk(G-lfn(Ps, Body, S0), Scope), !,
    bind_args(Ps, Args, Scope, S0, BAlts),
    sfindall(BAlts-Day, A, ( member(a(G0, S1), BAlts), enter_expr(Body, fn(F, S1), Day, Ctx, EA),
                 member(a(G1, E), EA), append(G0, G1, GG), A = a(GG, E) ), Alts).
enter_(app(N, []), fn(F, Scope), Day, Ctx, Alts) :-
    memberchk(N-lazy(E, S0), Scope), !,
    enter_expr(E, fn(F, S0), Day, Ctx, Alts).
enter_(app(G, Args), fn(_, Scope), Day, Ctx, Alts) :-
    contract_function(G), !,
    pdef(G, Ps, _, _, _),
    length(Ps, NP), length(Args, NA),
    ( NP == NA -> true ; throw(unsupported("a contract function applied to fewer or more inputs than it takes")) ),
    sfindall(Scope-Args, a(G0, S1), bind_params(Ps, Args, Scope, G0, S1), BAlts),
    sfindall(BAlts-Day, A, ( member(a(G0, S1), BAlts), enter(call(G, S1), Day, Ctx, EA),
                 member(a(G1, E), EA), append(G0, G1, GG), A = a(GG, E) ), Alts).

cross(Condss, Alts, Out) :-
    sfindall(Condss-Alts, a(G, E), ( member(C, Condss), member(a(G0, E), Alts), append(C, G0, G) ), Out).

cross_effects(A1, A2, Out) :-
    sfindall(A1-A2, a(G, E), ( member(a(G1, E1), A1), member(a(G2, E2), A2), append(G1, G2, G), append(E1, E2, E) ), Out).

opt_value(none, _, [a([], none)]) :- !.
opt_value(E, Scope, Alts) :- sx(E, Scope, Alts0), sfindall(Alts0, a(G, V1), ( member(a(G0, V), Alts0), party_term(V, V1, G1), append(G0, G1, G) ), Alts).

branch_to_if([], O, O).
branch_to_if([C-E|Cs], O, if(C, E, R)) :- branch_to_if(Cs, O, R).

%   WHERE and LET: local definitions, worked out where they are used.
locals(Ds, Scope, Scope1) :-
    foldl(local_def, Ds, Scope, Scope1).

local_def(decide(_, sig(Gs, _), appform(N, Args, _, _), Body, _, _), S0, [N-B|S0]) :- !,
    params(Gs, Args, Ps),
    (   Ps == [] -> B = lazy(Body, S1) ; B = lfn(Ps, Body, S1) ),
    S1 = [N-B|S0].      % a local may use itself and the ones before it
local_def(_, S, S).

%   Binding a function's parameters to argument expressions.
bind_params(Ps, Args, Scope, Goals, NewScope) :-
    bind_params_(Ps, Args, Scope, Goals, NewScope).

bind_params_([], [], _, [], []).
bind_params_([p(N, _)|Ps], [A|As], Scope, G, [N-v(V)|S]) :-
    sx(A, Scope, Alts), member(a(G1, V), Alts),
    bind_params_(Ps, As, Scope, G2, S),
    append(G1, G2, G).

bind_args(Ps, Args, Scope, S0, Alts) :-
    sfindall(Scope-S0, a(G, S1), ( bind_params(Ps, Args, Scope, G, S), append(S, S0, S1) ), Alts).

		 /*******************************
		 *             NODES            *
		 *******************************/

%   A node: an obligation of function F (the deontic term D) reached in
%   context Ctx. Its fluent's places: the party, the action's expected
%   values, the inputs its continuation needs, the deadline.
node_key(F, D, Scope, Ctx, Key, Info) :-
    D = deontic(_, Modal, Action, Provided, Within, Hence, Lest),
    Key0 = k(F, D, Ctx),
    (   node(Key1, Info), Key1 =@= Key0
    ->  Key = Key1
    ;   Key = Key0,
        counter_next(node(F), K),
        pattern_parts(Action, Con, PatArgs),
        expected_places(Con, PatArgs, Scope, Expected),
        free_names(Provided, Hence, Lest, PatArgs, Scope, Needs0),
        needs_places(Needs0, Scope, Needs),
        node_fluent(F, K, Ctx, Modal, Con, Expected, Needs, Within, Fun, Text, Arity),
        declare(fluent, Fun, Text),
        length(FA, Arity), Fl0 =.. [Fun|FA],
        Info = ninfo(F, K, Ctx, D, Fl0, Needs, Expected),
        assertz(node(Key, Info)),
        assertz(node_queue(Key))
    ).

counter_next(C, N) :-
    ( retract(counter(C, N0)) -> N is N0 + 1 ; N = 1 ),
    assertz(counter(C, N)).

%   The action's pattern: its constructor and the patterns of its fields.
pattern_parts(papp(C, Ps), C, Ps) :- pcon(C, _, _), !.
pattern_parts(papp(V, []), any(V), []) :- !.
pattern_parts(pexact(app(C, Args)), C, Ps) :- pcon(C, _, _), !,
    maplist([A, pexact(A)]>>true, Args, Ps).
pattern_parts(pexact(app(C, [])), C, []) :- !.
pattern_parts(plit(L), _, _) :- throw(unsupported(L)).
pattern_parts(P, _, _) :- throw(unsupported(P)).

%   Expected values: a field whose pattern is a literal or EXACTLY holds a
%   value the event must have; a field whose pattern is a name binds it.
expected_places(any(_), _, _, []) :- !.
expected_places(Con, Ps, _, Expected) :-
    pcon(Con, _, Fields),
    length(Fields, NF), length(Ps, NP),
    ( NF == NP -> true ; throw(unsupported("an action with a different number of values than its type declares")) ),
    findall(e(I, FN, FT, P),
            ( nth1(I, Ps, P), nth1(I, Fields, f(FN, FT)), expected_pattern(P) ), Expected).

expected_pattern(plit(_)).
expected_pattern(pexact(_)).
expected_pattern(papp(C, [])) :- pcon(C, _, []).
expected_pattern(papp(C, [_|_])) :- throw(unsupported(papp(C, nested))).

%   The names the continuation (PROVIDED, HENCE, LEST) uses that are in
%   scope: the function's inputs and the names bound before; not the names
%   the action binds.
free_names(Provided, Hence, Lest, PatArgs, Scope, Needs) :-
    findall(N, ( member(X, [Provided, Hence, Lest]), X \== none, used_name(X, N) ), Ns0),
    findall(B, ( member(P, PatArgs), pattern_binder(P, B) ), Bs),
    sort(Ns0, Ns1),
    findall(N, ( member(N, Ns1), \+ memberchk(N, Bs) ), Ns2),
    expand_needs(Ns2, Scope, [], Needs).

used_name(E, N) :- sub_term(S, E), ( S = app(N, _) ; S = papp(N, _) ; S = proj(app(N, []), _) ), atom(N).

pattern_binder(papp(N, []), N) :- \+ pcon(N, _, _), !.
pattern_binder(papp(_, Ps), N) :- member(P, Ps), pattern_binder(P, N).

%   A local definition needs what its body uses.
expand_needs([], _, Acc, Needs) :- sort(Acc, Needs).
expand_needs([N|Ns], Scope, Acc, Needs) :-
    (   memberchk(N, Acc) -> expand_needs(Ns, Scope, Acc, Needs)
    ;   memberchk(N-B, Scope)
    ->  (   B = v(_) -> expand_needs(Ns, Scope, [N|Acc], Needs)
        ;   ( B = lazy(E, _) ; B = lfn(_, E, _) )
        ->  findall(M, used_name(E, M), Ms), append(Ms, Ns, Ns1),
            expand_needs(Ns1, Scope, Acc, Needs)
        ;   expand_needs(Ns, Scope, Acc, Needs)
        )
    ;   expand_needs(Ns, Scope, Acc, Needs)
    ).

%   The places of the needed values: a value's shape decides them.
needs_places(Names, Scope, Needs) :-
    findall(need(N, Shape), ( member(N, Names), memberchk(N-v(V), Scope), value_shape(V, Shape) ), Needs).

value_shape(V, leaf) :- var(V), !.
value_shape(nom(_, T), nom(T)) :- !.
value_shape(rec(Fs), rec(Shapes)) :- !,
    findall(F-S, ( member(F-V, Fs), value_shape(V, S) ), Shapes).
value_shape(_, leaf).

shape_vars(leaf, V, [V]) :- !.
shape_vars(nom(_), V, [X]) :- !, ( nonvar(V), V = nom(X, _) -> true ; X = V ).
shape_vars(rec(Shapes), V, Xs) :-
    ( nonvar(V), V = rec(Fs) -> true ; Fs = [] ),
    sfindall(Fs, X, ( member(F-S, Shapes), ( memberchk(F-FV, Fs) -> true ; true ), shape_vars(S, FV, Ys), member(X, Ys) ), Xs).

shape_value(leaf, [X|R], X, R).
shape_value(nom(T), [X|R], nom(X, T), R).
shape_value(rec(Shapes), L, rec(Fs), R) :-
    foldl([F-S, F-V, L0, L1]>>shape_value(S, L0, V, L1), Shapes, Fs, L, R).

shape_phrases(Name, leaf, [P]) :- !, place_phrase(place(Name, [], x), P).
shape_phrases(Name, nom(_), [P]) :- !, place_phrase(place(Name, [], x), P).
shape_phrases(Name, rec(Shapes), Ps) :-
    findall(P, ( member(F-S, Shapes), sub_phrases(Name, [F], S, Ps1), member(P, Ps1) ), Ps).

sub_phrases(Name, Path, rec(Shapes), Ps) :- !,
    findall(P, ( member(F-S, Shapes), append(Path, [F], P1), sub_phrases(Name, P1, S, Ps1), member(P, Ps1) ), Ps).
sub_phrases(Name, Path, _, [P]) :- place_phrase(place(Name, Path, x), P).

%   The node's fluent: `under <F>, *a party* must <action> by day *a day*`
%   (the function's name, the obligation's number in it when there are
%   several, the part of a RAND/ROR, the inputs kept).
node_fluent(F, K, Ctx, Modal, Con, Expected, Needs, Within, Fun, Text, Arity) :-
    words_of(F, FWs), atomic_list_concat(FWs, ' ', FT),
    modal_words(Modal, MW),
    action_phrase(Con, Expected, AP, NE),
    ( Within == none -> By = '', NB = 0 ; By = ' by day *a due day*', NB = 1 ),
    findall(P, ( member(need(N, S), Needs), shape_phrases(N, S, Ps), member(P, Ps) ), NPs),
    length(NPs, NN),
    ( NPs == [] -> For = '' ; atomic_list_concat(NPs, ' and ', F0), atom_concat(' given ', F0, For) ),
    ctx_subject(Ctx, FT, Subj),
    ordinal_word(K, KW),
    format(atom(Text), '~w ~w *a party* to ~w~w as its ~w obligation~w', [Subj, MW, AP, By, KW, For]),
    ( Ctx = part(P1, Op1) -> format(atom(CF), '_~w~w', [Op1, P1]) ; CF = '' ),
    functor_of(FWs, F1), format(atom(Fun), 'o_~w~w_~w', [F1, CF, K]),
    Arity is 1 + NE + NB + NN.

%   Who binds the party: the contract, or a part of it.
ctx_subject(top, FT, FT).
ctx_subject(part(K, Op), FT, S) :-
    ordinal(K, O), op_word(Op, W), format(atom(S), 'the ~w ~w part of ~w', [O, W, FT]).

%   The two parts of `A RAND B` (joint: both must be met) and `A ROR B`
%   (alternative: one is enough).
part_pre(K, Op, Pre, PT) :-
    ordinal(K, O), op_word(Op, W),
    format(atom(Pre), 'the_~w_~w_part', [O, W]),
    format(atom(PT), 'the ~w ~w part of the contract', [O, W]).

op_word(and, joint).
op_word(or, alternative).

ordinal(1, first).
ordinal(2, second).

%   Words, not digits: two templates that differ by a number only are one
%   template to LE.
ordinal_word(K, W) :-
    Ws = [first, second, third, fourth, fifth, sixth, seventh, eighth, ninth, tenth,
          eleventh, twelfth, thirteenth, fourteenth, fifteenth, sixteenth, seventeenth,
          eighteenth, nineteenth, twentieth],
    (   nth1(K, Ws, W) -> true
    ;   K1 is K // 20, K2 is K mod 20 + 1, ordinal_word(K1, W1), nth1(K2, Ws, W2),
        format(atom(W), '~w ~w', [W1, W2])
    ).

modal_words(must, obliges).
modal_words(may, permits).
modal_words(shant, forbids).
modal_words(do, expects).

action_phrase(any(_), [], 'do anything', 0) :- !.
action_phrase(Con, Expected, AP, NE) :-
    name_text(Con, CT),
    findall(Ph, ( member(e(_, FN, FT, _), Expected), place_phrase(place(FN, [], FT), Ph) ), Phs),
    length(Phs, NE),
    ( Phs == [] -> AP = CT ; atomic_list_concat(Phs, ' and ', W), format(atom(AP), '~w with ~w', [CT, W]) ).

%   Entering a node on Day: its party, expected values and deadline are
%   worked out; the needed inputs are the scope's.
node_entry(ninfo(_, _, _, _, _, _, Expected), D, Scope, Day, Fl0, Needs, Alts) :-
    D = deontic(Party, _, _, _, Within, _, _),
    copy_term(Fl0, Fl),
    Fl =.. [Fun|Args],
    sfindall(Scope-Day-Expected-Fl-Needs, a(G, [initiate(Fl1)]),
            ( sx(Party, Scope, PAs), member(a(G1, PV0), PAs), party_term(PV0, PV, GP),
              expected_values(Expected, Scope, G2, EVs),
              within_value(Within, Scope, Day, G3, DL),
              needed_values(Needs, Scope, NVs),
              append([G1, GP, G2, G3], G),
              append([[PV], EVs, DL, NVs], As1),
              length(Args, NA), length(As1, NA),
              Fl1 =.. [Fun|As1] ), Alts).

expected_values([], _, [], []).
expected_values([e(_, _, _, P)|Es], Scope, G, [V|Vs]) :-
    pattern_value(P, Scope, G1, V),
    expected_values(Es, Scope, G2, Vs),
    append(G1, G2, G).

pattern_value(plit(L), _, [], V) :- !, lit_value(L, V).
pattern_value(pexact(E), Scope, G, V) :- !, sx(E, Scope, Alts), member(a(G, V0), Alts), scalar_value(V0, V).
pattern_value(papp(C, []), _, [], V) :- pcon(C, _, []), !, name_atom(C, V).
pattern_value(P, _, _, _) :- throw(unsupported(P)).

lit_value(num(N), N) :- !.
lit_value(str(S), S) :- !.
lit_value(L, _) :- throw(unsupported(L)).

scalar_value(V, V) :- var(V), !.
scalar_value(nom(X, _), X) :- !.
scalar_value(V, V) :- ( var(V) ; atomic(V) ), !.
scalar_value(V, A) :- party_value(V, A).

within_value(none, _, _, [], []) :- !.
within_value(E, Scope, Day, G, [DL]) :-
    sx(E, Scope, Alts), member(a(G0, W), Alts),
    arith(DL, Day + W, G1), append(G0, G1, G).

needed_values(Needs, Scope, Vals) :-
    sfindall(Scope, X, ( member(need(N, S), Needs), memberchk(N-v(V), Scope), shape_vars(S, V, Xs), member(X, Xs) ), Vals).

%   A party value as an individual: an atom, or a constructor applied to a
%   named record (`CharityActor testCharity` → charity_actor_test_charity).
party_value(V, V) :- var(V), !.
party_value(nom(X, _), X) :- !.
party_value(A, A) :- atomic(A), !.
party_value(con(C, Args), A) :-
    maplist(party_value, Args, As), maplist(atom, As), !,
    name_atom(C, CA), atomic_list_concat([CA|As], '_', A),
    ( party_con_fact(A, C, As) -> true ; assertz(party_con_fact(A, C, As)) ).
party_value(con(C, Args), _) :- throw(unsupported(con(C, Args))).
party_value(rec(_), _) :- throw(unsupported("a record as a party")).

%   A party built at run time from a value (CharityActor charity, the
%   charity an input): a condition relating them.
party_term(V, V, []) :- var(V), !.
party_term(con(C, [X0]), P, [G]) :- ( var(X0) -> X = X0 ; X0 = nom(X, _), var(X) ), !,
    party_con_template(C, Fun), G =.. [Fun, P, X].
party_term(V, P, []) :- party_value(V, P).

party_con_template(C, Fun) :-
    party_con_functor(C, Fun),
    words_of(C, Ws), atomic_list_concat(Ws, ' ', CT),
    format(atom(Text), '*a party* is the ~w of *a thing*', [CT]),
    declare(template, Fun, Text),
    (   pcon(C, _, [f(_, AT0)]), type_name(AT0, AT)
    ->  forall(( pdef(N, [], _, _, _), named_type(N, AT) ),
               ( name_atom(N, NA), party_value(con(C, [NA]), _) ))
    ;   true
    ).

party_con_functor(C, Fun) :- words_of(C, Ws), append(Ws, [of], W1), functor_of([party|W1], Fun).

		 /*******************************
		 *        THE NODES' LAWS       *
		 *******************************/

drain_nodes :-
    (   retract(node_queue(Key))
    ->  node(Key, Info),
        Info = ninfo(F, _, _, _, _, _, _),
        (   refused(F, _) -> true
        ;   catch(node_laws(Key, Info), E, ( message_text(E, W), assertz(refused(F, W)) )) -> true
        ;   assertz(refused(F, "an obligation's laws could not be written"))
        ),
        drain_nodes
    ;   true
    ).

%   Met and missed.
node_laws(k(F, _, _), ninfo(F, K, Ctx, D, Fl0, Needs, Expected)) :-
    D = deontic(_, Modal, Action, Provided, Within, Hence, Lest),
    pattern_parts(Action, Con, PatArgs),
    % the fluent's variables
    copy_term(Fl0, Fl), Fl =.. [_, P|Rest],
    length(Expected, NE), length(EVs, NE), append(EVs, R1, Rest),
    ( Within == none -> DL = none, R2 = R1 ; R1 = [DL|R2] ),
    fluent_scope(Needs, R2, NeedScope),
    base_scope(F, NeedScope, Scope0),
    % met: the party does the action, on or before the deadline
    met_event(Con, PatArgs, Expected, EVs, P, Day, Ev, Scope0, Scope1),
    Trig = happens(Ev, _, _),
    ( DL == none -> TG = [] ; TG = [Day =< DL] ),
    provided_alts(Provided, Scope1, PAlts),
    (   Modal == shant
    ->  ( Lest == none -> Next = missed_shant(P, Day) ; Next = expr(Lest) )
    ;   Next = expr_or_fulfilled(Hence)
    ),
    forall(member(PG, PAlts),
           ( continue(Next, F, Scope1, Day, Ctx, CAlts),
             add_item(hist, hist(met(Fl), Ev, Day, PG, TG)),
             forall(member(a(G, Effs), CAlts),
                    ( append([[holds(Fl, _)], TG, PG, G], Conds),
                      add_law(node(F, K), Trig, Conds, [terminate(Fl)|Effs]),
                      add_item(hist, hist(ends(Fl), Ev, Day, G, Effs)) )) )),
    % missed: something happens after the deadline
    (   DL == none -> true
    ;   something_happens(Day, SEv),
        (   memberchk(Modal, [may, shant]) -> MNext = expr_or_fulfilled(Hence)
        ;   Lest == none -> MNext = missed(P, DL)
        ;   MNext = expr(Lest)
        ),
        continue(MNext, F, Scope0, Day, Ctx, MAlts),
        forall(member(a(G, Effs), MAlts),
               ( append([[holds(Fl, _), Day > DL], G], Conds),
                 add_law(node(F, K), happens(SEv, _, _), Conds, [terminate(Fl)|Effs]),
                 add_item(hist, hist(missed(Fl, DL), none, Day, G, Effs)) )),
        add_item(hist, hist(deadline(Fl, DL), none, none, [], []))
    ).

fluent_scope(Needs, Vals, Scope) :-
    foldl([need(N, S), N-v(V), L0, L1]>>shape_value(S, L0, V, L1), Needs, Scope, Vals, []).

%   The scope a node's continuation is compiled in: the kept inputs, and
%   the function's local definitions over them.
base_scope(F, NeedScope, Scope) :-
    pdef(F, _, _, Body, _),
    (   Body = where(_, Ds) -> locals(Ds, NeedScope, Scope)
    ;   Scope = NeedScope
    ).

continue(expr_or_fulfilled(none), _, _, _, Ctx, [a([], [initiate(Fl)])]) :- !, fulfilled_fluent(Ctx, Fl).
continue(expr_or_fulfilled(E), F, Scope, Day, Ctx, Alts) :- !, enter_expr(E, fn(F, Scope), Day, Ctx, Alts).
continue(expr(E), F, Scope, Day, Ctx, Alts) :- !, enter_expr(E, fn(F, Scope), Day, Ctx, Alts).
continue(missed(P, DL), _, _, _, Ctx, [a([], [initiate(Fl)])]) :- !, breach_fluent(Ctx, missed(P, DL), Fl).
continue(missed_shant(P, Day), _, _, _, Ctx, [a([], [initiate(Fl)])]) :- breach_fluent(Ctx, forbidden(P, Day), Fl).

provided_alts(none, _, [[]]) :- !.
provided_alts(E, Scope, Alts) :- cond(E, Scope, Alts).

%   The event that meets a node, with the scope extended by the names the
%   action's pattern binds.
met_event(any(V), [], [], [], P, Day, Ev, Scope, [V-v(_)|Scope]) :- !,
    something_done(P, Day, Ev).
met_event(Con, PatArgs, Expected, EVs, P, Day, Ev, Scope, Scope1) :-
    action_event(Con, Fun, Fields),
    length(Fields, NF), length(FVs0, NF),
    % expected fields take the fluent's values
    link_expected(Expected, EVs, FVs0),
    bind_fields(PatArgs, Fields, FVs0, FVs, Scope, Scope1),
    append([[P], FVs, [Day]], As), Ev =.. [Fun|As].

link_expected([], [], _).
link_expected([e(J, _, _, _)|Es], [X|Xs], FVs) :- nth1(J, FVs, X), link_expected(Es, Xs, FVs).

bind_fields([], [], [], [], S, S).
bind_fields([Pt|Ps], [f(_, FT)|Fs], [X0|Xs0], Places, S0, S) :-
    field_places(FT, X0, XPs, V),
    (   pattern_binder(Pt, N), Pt = papp(N, []) -> S1 = [N-v(V)|S0] ; S1 = S0 ),
    bind_fields(Ps, Fs, Xs0, Rest, S1, S),
    append(XPs, Rest, Places).

%   A field of a structural record type takes one place per leaf.
field_places(FT, X, Xs, V) :-
    type_name(FT, T),
    (   pstructural(T)
    ->  type_places(x, [], T, Pls), length(Pls, N), length(Xs, N),
        places_value(Pls, Xs, V), X = V
    ;   Xs = [X], typed_var(T, X, V)
    ).

places_value(Pls, Xs, V) :-
    pairs_keys_values(PV, Pls, Xs),
    sfindall(PV, Path-X-T, member(place(_, Path, T)-X, PV), L),
    rebuild_rec(_, [], L, V).

%   The event of an action constructor: `*a party* does <action> with
%   <field> *a …* and … on day *a day*`.
action_event(Con, Fun, Fields) :-
    pcon(Con, _, Fields),
    words_of(Con, CWs), functor_of([does|CWs], Fun),
    (   used_event(Con) -> true
    ;   assertz(used_event(Con)),
        findall(Ph, ( member(f(FN, FT), Fields), type_places(FN, [], FT, Pls), member(Pl, Pls), place_phrase(Pl, Ph) ), Phs),
        name_text(Con, CT),
        ( Phs == [] -> With = '' ; atomic_list_concat(Phs, ' and ', W0), atom_concat(' with ', W0, With) ),
        format(atom(Text), '*a party* does ~w~w on day *a day*', [CT, With]),
        declare(event, Fun, Text),
        something_rule(Fun, Fields)
    ).

%   `something happens on day *a day*`: any event, and the clock (L4's WAIT
%   UNTIL): a composite event the missed deadlines are laws of.
something_happens(Day, Ev) :- Ev = something_happens_on_day(Day), ensure_something.

something_done(P, Day, Ev) :- Ev = does_something_on_day(P, Day), ensure_something.

ensure_something :-
    (   fn_done(something) -> true
    ;   assertz(fn_done(something)),
        declare(event, something_happens_on_day, 'something happens on day *a day*'),
        declare(event, does_something_on_day, '*a party* does something on day *a day*'),
        declare(event, the_clock_reaches_day, 'the clock reaches day *a day*'),
        add_item(composite, lps(l_events(happens(something_happens_on_day(D), T1, T2),
                                         [happens(the_clock_reaches_day(D), T1, T2)])))
    ).

something_rule(Fun, Fields) :-
    ensure_something,
    length(Fields, _),
    findall(x, ( member(f(_, FT), Fields), type_places(x, [], FT, Pls), member(_, Pls) ), Xs0),
    length(Xs0, N), length(Xs, N),
    append([[P], Xs, [D]], As), Ev =.. [Fun|As],
    add_item(composite, lps(l_events(happens(something_happens_on_day(D), T1, T2), [happens(Ev, T1, T2)]))),
    add_item(composite, lps(l_events(happens(does_something_on_day(P, D), T1, T2), [happens(Ev, T1, T2)]))).

		 /*******************************
		 *    ENDS: FULFILLED, BREACH   *
		 *******************************/

fulfilled_fluent(top, the_contract_is_fulfilled) :-
    declare(fluent, the_contract_is_fulfilled, 'the contract is fulfilled').
fulfilled_fluent(part(K, Op), Fl) :-
    part_pre(K, Op, Pre, PT),
    atom_concat(Pre, '_is_fulfilled', Fl), atom_concat(PT, ' is fulfilled', T),
    declare(fluent, Fl, T),
    ensure_combination(Op).

%   A breach: explicit (BREACH BY … BECAUSE …), a missed deadline, or a
%   forbidden action done.
breach_fluent(top, B, Fl) :- breach_fluent_(the_contract, 'the contract', B, Fl).
breach_fluent(part(K, Op), B, Fl) :-
    part_pre(K, Op, Pre, PT),
    breach_fluent_(Pre, PT, B, Fl),
    ensure_combination(Op).

breach_fluent_(Pre, PT, explicit(B, R), Fl) :- B == none, R == none, !,
    atom_concat(Pre, '_is_breached', Fun), Fl = Fun,
    format(atom(T), '~w is breached', [PT]), declare(fluent, Fun, T).
breach_fluent_(Pre, PT, explicit(B, R), Fl) :- R == none, !,
    atom_concat(Pre, '_is_breached_by', Fun), Fl =.. [Fun, B],
    format(atom(T), '~w is breached by *a party*', [PT]), declare(fluent, Fun, T).
breach_fluent_(Pre, PT, explicit(B, R), Fl) :- B == none, !,
    atom_concat(Pre, '_is_breached_because', Fun), Fl =.. [Fun, R],
    format(atom(T), '~w is breached because *a reason*', [PT]), declare(fluent, Fun, T).
breach_fluent_(Pre, PT, explicit(B, R), Fl) :- !,
    atom_concat(Pre, '_is_breached_by_because', Fun), Fl =.. [Fun, B, R],
    format(atom(T), '~w is breached by *a party* because *a reason*', [PT]), declare(fluent, Fun, T).
breach_fluent_(Pre, PT, missed(P, DL), Fl) :- !,
    atom_concat(Pre, '_is_breached_by_missing', Fun), Fl =.. [Fun, P, DL],
    format(atom(T), '~w is breached by *a party* missing the deadline of day *a deadline*', [PT]), declare(fluent, Fun, T).
breach_fluent_(Pre, PT, forbidden(P, Day), Fl) :-
    atom_concat(Pre, '_is_breached_by_doing', Fun), Fl =.. [Fun, P, Day],
    format(atom(T), '~w is breached by *a party* doing what was forbidden on day *a day*', [PT]), declare(fluent, Fun, T).


%   L4's RAND and ROR (Machine.hs, RBinOp2): and — both fulfilled, or a
%   breach; or — one fulfilled, or both breached. The laws fire on the
%   event that ends the second part (or the first one that decides).
ensure_combination(Op) :-
    (   fn_done(combination(Op)) -> true
    ;   assertz(fn_done(combination(Op))),
        assertz(fn_done(needs_combination(Op)))
    ).

		 /*******************************
		 *   EXPRESSIONS AND VALUES     *
		 *******************************/

%!  sx(+Expr, +Scope, -Alts) is det.
%
%   The value of an L4 expression: alternatives a(Goals, Value), Goals the
%   conditions (LPS form: timeless literals, comparisons, `X is E`) under
%   which Expr has Value. A Value is a number, a string, an atom (a
%   constructor, a named record), a variable, nom(X, Type) (a named record
%   known at run time), rec([Field-Value]) (a record built here), or
%   con(C, Values) (a constructor with values).
sx(E, Scope, Alts) :-
    (   sx_(E, Scope, Alts0) -> true ; throw(unsupported(E)) ),
    Alts = Alts0.

sx_(num(N), _, [a([], N)]) :- !.
sx_(str(S), _, [a([], S)]) :- !.
sx_(app('TRUE', []), _, [a([], true)]) :- !.
%   MAYBE: JUST x is x, NOTHING the atom nothing.
sx_(app('JUST', [E]), S, Alts) :- !, sx(E, S, Alts).
sx_(app('NOTHING', []), _, [a([], nothing)]) :- !.
sx_(list(Es), Scope, Alts) :- !, args_alts(Es, Scope, Alts).
%   An ASSUMEd value (`ASSUME NaN IS A NUMBER`) has no value the document
%   can work out: the alternative that needs it is left out (noted).
sx_(app(N, []), _, []) :- passume(N, _), \+ pdef(N, _, _, _, _), !,
    add_item(notes, note(assumed(N))).
sx_(app('FALSE', []), _, [a([], false)]) :- !.
sx_(percent(E), S, Alts) :- !, arith_alts(E / 100, S, Alts).
sx_(app(N, []), Scope, Alts) :- memberchk(N-B, Scope), !, binding_value(B, Alts).
sx_(app(N, Args), Scope, Alts) :- memberchk(N-lfn(Ps, Body, S0), Scope), !,
    bind_args(Ps, Args, Scope, S0, BAlts),
    sfindall(BAlts, a(G, V), ( member(a(G0, S1), BAlts), sx(Body, S1, VA), member(a(G1, V), VA), append(G0, G1, G) ), Alts).
sx_(app(C, []), _, [a([], A)]) :- pcon(C, T, []), ptype(T, enum(_)), !, name_atom(C, A).
sx_(app(C, Args), Scope, Alts) :- pcon(C, T, Fields), Args \== [], !,
    sfindall(Scope, a(G, V), ( args_values(Args, Scope, G, Vs),
                       (   ptype(T, record(_))
                       ->  pairs_keys_values(FV, FNs, Vs), findall(FN, member(f(FN, _), Fields), FNs), V = rec(FV)
                       ;   V = con(C, Vs) ) ), Alts).
sx_(app_named(T, FAs), Scope, Alts) :- !,
    findall(F, member(F=_, FAs), Fs), findall(E, member(_=E, FAs), Es),
    sfindall(Scope, a(G, rec(FV)), ( args_values(Es, Scope, G, Vs), pairs_keys_values(FV, Fs, Vs) ), Alts),
    ignore(T = T).
%   A field of a named record the program computes (`Monthly Installment
%   Amount`'s Value): a function of the document, worked out once.
sx_(proj(app(N, []), F), Scope, Alts) :-
    \+ memberchk(N-_, Scope), pdef(N, [], G, B, _), \+ contract_function(N),
    record_valued(G, B), \+ ( named_type(N, T), \+ pstructural(T) ), !,
    field_function(N, F, Fun),
    Alts = [a([L], V)], L =.. [Fun, V].
sx_(proj(E, F), Scope, Alts) :- !,
    sx(E, Scope, EAlts),
    sfindall(EAlts, a(G, V), ( member(a(G0, R), EAlts), project(R, F, G1, V), append(G0, G1, G) ), Alts).
sx_(if(C, T, E), Scope, Alts) :- !,
    cond(C, Scope, Yes), ncond(C, Scope, No),
    sx(T, Scope, TA), sx(E, Scope, EA),
    cross(Yes, TA, A1), cross(No, EA, A2), append(A1, A2, Alts).
sx_(branch(Cases, O), Scope, Alts) :- !, branch_to_if(Cases, O, E), sx(E, Scope, Alts).
sx_(consider(X, Branches), Scope, Alts) :- !,
    sx(X, Scope, XAlts),
    sfindall(XAlts-Scope, a(G, V), ( member(a(G0, XV), XAlts), consider_alts(Branches, XV, [], Scope, Pairs),
                       member(C-S1-B, Pairs), sx(B, S1, BA), member(a(G1, V), BA), append([G0, C, G1], G) ), Alts).
sx_(where(E, Ds), Scope, Alts) :- !, locals(Ds, Scope, S1), sx(E, S1, Alts).
sx_(let(Ds, E), Scope, Alts) :- !, locals(Ds, Scope, S1), sx(E, S1, Alts).
sx_(E, Scope, Alts) :- arith_op(E, Op, A, B), !, arith_alts(Op, A, B, Scope, Alts).
sx_(app(Fn, [X]), Scope, Alts) :- builtin_unary(Fn, Op), !,
    sx(X, Scope, XA),
    sfindall(XA, a(G, V), ( member(a(G0, XV), XA), T =.. [Op, XV], arith(V, T, G1), append(G0, G1, G) ), Alts).
sx_(app(Fn, [A, B]), Scope, Alts) :- builtin_binary(Fn, Op), !,
    args_alts([A, B], Scope, AA),
    sfindall(AA, a(G, V), ( member(a(G0, [X, Y]), AA), T =.. [Op, X, Y], arith(V, T, G1), append(G0, G1, G) ), Alts).
sx_(E, Scope, Alts) :- boolean_expr(E), !,
    cond(E, Scope, Yes), ncond(E, Scope, No),
    sfindall(Yes, a(G, true), member(G, Yes), A1), sfindall(No, a(G, false), member(G, No), A2), append(A1, A2, Alts).
sx_(app(N, Args), Scope, Alts) :- pdef(N, Ps, Giveth, Body, _), \+ contract_function(N), !,
    length(Ps, NP), length(Args, NA),
    (   NP =:= NA -> true ; throw(unsupported("a function applied to fewer or more inputs than it takes")) ),
    (   scalar_function(N, Ps, Giveth, Body)
    ->  function_rules(N),
        fn_template(N, Fun, _),
        sfindall(Scope, a(G, V), ( args_values(Args, Scope, G0, Vs), append(Vs, [V], As), L =.. [Fun|As], append(G0, [L], G) ), Alts)
    ;   Ps == [], record_valued(Giveth, Body)
    ->  % a named record: an individual (nominal type) or its value (structural)
        (   named_type(N, T), \+ pstructural(T)
        ->  name_atom(N, A), Alts = [a([], nom(A, T))], field_facts(N, T)
        ;   sx(Body, [], Alts)
        )
    ;   sfindall(Scope, a(G, S1), bind_params(Ps, Args, Scope, G, S1), BAlts),
        sfindall(BAlts, a(G, V), ( member(a(G0, S1), BAlts), sx(Body, S1, BA), member(a(G1, V), BA), append(G0, G1, G) ), Alts)
    ).
sx_(concat(Es), Scope, Alts) :- !,
    args_alts(Es, Scope, AA),
    sfindall(AA, a(G, V), ( member(a(G0, Vs), AA), G1 = [atomic_list_concat(Vs, V)], append(G0, G1, G) ), Alts).

binding_value(v(V), [a([], V)]) :- !.
binding_value(lazy(E, S), Alts) :- sx(E, S, Alts).
binding_value(lfn(_, _, _), _) :- throw(unsupported("a local function used as a value")).

args_values([], _, [], []).
args_values([E|Es], Scope, G, [V|Vs]) :-
    sx(E, Scope, Alts), member(a(G1, V), Alts),
    args_values(Es, Scope, G2, Vs), append(G1, G2, G).

args_alts(Es, Scope, Alts) :- sfindall(Scope, a(G, Vs), args_values(Es, Scope, G, Vs), Alts).

arith_op(plus(A, B), +, A, B).
arith_op(minus(A, B), -, A, B).
arith_op(times(A, B), *, A, B).
arith_op(div(A, B), /, A, B).
arith_op(mod(A, B), mod, A, B).

arith_alts(Op, A, B, Scope, Alts) :-
    args_alts([A, B], Scope, AA),
    sfindall(AA, a(G, V), ( member(a(G0, [X, Y]), AA), num_val(X, X1), num_val(Y, Y1), T =.. [Op, X1, Y1], arith(V, T, G1), append(G0, G1, G) ), Alts).
arith_alts(E / K, Scope, Alts) :-
    sx(E, Scope, EA), sfindall(EA, a(G, V), ( member(a(G0, X), EA), arith(V, X / K, G1), append(G0, G1, G) ), Alts).

num_val(X, X) :- ( var(X) ; number(X) ), !.
num_val(X, _) :- throw(unsupported(value(X))).

%   V is T: worked out now when T is ground, else a condition.
arith(V, T, []) :- ground(T), catch(V0 is T, _, fail), !, V = V0.
arith(V, T, [V is T]).

builtin_unary('CEILING', ceiling).
builtin_unary('FLOOR', floor).
builtin_unary('ROUND', round).
builtin_unary('TRUNC', truncate).
builtin_unary('ABS', abs).
builtin_unary('SQRT', sqrt).

builtin_binary('MAX', max).
builtin_binary('MIN', min).
builtin_binary('POW', **).
builtin_binary('EXPONENT', **).

boolean_expr(E) :- functor(E, F, _), memberchk(F, [and, or, not, implies, eq, leq, geq, lt, gt]).

%   A field of a value.
project(R, F, _, _) :- var(R), !, throw(unsupported(field_of_unknown(F))).
project(rec(Fs), F, [], V) :- !, ( memberchk(F-V, Fs) -> true ; throw(unsupported(field(F))) ).
project(nom(X, T), F, [L], V) :- !, field_template(T, F, Fun), L =.. [Fun, X, V].
project(con(C, Vs), F, [], V) :- pcon(C, _, Fields), nth1(I, Fields, f(F, _)), !, nth1(I, Vs, V).
project(A, F, G, V) :- atom(A), named_record(A, N, T), !, project(nom(A, T), F, G, V), field_facts(N, T).
project(R, F, _, _) :- throw(unsupported(field_of(F, R))).

named_record(A, N, T) :- pdef(N, [], _, _, _), name_atom(N, A), named_type(N, T), !.

%   The type of a named record: its GIVETH, or the record its body builds.
named_type(N, T) :-
    pdef(N, [], G, B, _),
    (   G \== none -> type_name(G, T)
    ;   B = app_named(T, _) -> true
    ;   B = app(T, [_|_]), ptype(T, record(_)) -> true
    ;   B = app(C, [_|_]), pcon(C, T, _)
    ), !.

record_valued(G, B) :-
    (   G \== none -> type_name(G, T), ( ptype(T, record(_)) ; ptype(T, enum(_)) ; ptype(T, synonym(_)) )
    ;   record_result(B)
    ), !.

%   `the <field> of *a <type>* is *a …*`, and a fact for each named record
%   of the type.
field_template(T, F, Fun) :-
    words_of(F, FWs0), drop_article(FWs0, FWs), words_of(T, TWs),
    append([the|FWs], [of|TWs], W1), functor_of(W1, Fun),
    atomic_list_concat(FWs, ' ', FT), atomic_list_concat(TWs, ' ', TT),
    article(TT, Ar),
    format(atom(Text), 'the ~w of *~w ~w* is *a value*', [FT, Ar, TT]),
    declare(template, Fun, Text),
    forall(( pdef(N, [], _, _, _), named_type(N, T) ), field_facts(N, T)).

field_facts(N, T) :-
    (   field_fact_done(N, T) -> true
    ;   assertz(field_fact_done(N, T)),
        (   record_fields(T, Fields), pdef(N, [], _, Body, _), record_args(Body, Fields, FEs)
        ->  name_atom(N, A),
            forall(( member(F-E, FEs), catch(sx(E, [], [a([], V0)]), _, fail), ground_fact_value(V0, V) ),
                   ( field_template(T, F, Fun), Fact =.. [Fun, A, V], add_item(facts, fact(Fact, [])) ))
        ;   true
        )
    ).

%   The expression of each field of a named record's definition.
record_args(app_named(_, FAs), _, FEs) :- !, findall(F-E, member(F=E, FAs), FEs).
record_args(app(_, Args), Fields, FEs) :- length(Args, N), length(Fields, N), !,
    findall(F-E, ( nth1(I, Fields, f(F, _)), nth1(I, Args, E) ), FEs).

ground_fact_value(V, V) :- ( number(V) ; string(V) ; atom(V) ), !.
ground_fact_value(L, L1) :- is_list(L), ground(L), !, maplist(ground_fact_value, L, L1).
ground_fact_value(nom(A, _), A) :- atom(A), !.
ground_fact_value(con(C, Vs), A) :- Vs \== [], maplist(atom, Vs), !, party_value(con(C, Vs), A).
%   A choice with values that are not names (`Suspended "reason"`): its
%   constructor, which is what the program compares it with.
ground_fact_value(con(C, _), A) :- !, name_atom(C, A).

%   CONSIDER: each WHEN's conditions, with the names its pattern binds.
consider_alts([], _, _, _, []).
consider_alts([otherwise(E)|_], _, Prev, Scope, [G-Scope-E]) :- !, negations(Prev, G).
consider_alts([when(P, E)|Bs], V, Prev, Scope, [G-S1-E|Rest]) :-
    match_pattern(P, V, Scope, G0, S1, Test),
    negations(Prev, GN), append(GN, G0, G),
    consider_alts(Bs, V, [Test|Prev], Scope, Rest).

negations(Prev, G) :- sfindall(Prev, \+ T, member(T, Prev), G0), exclude(==(\+ true), G0, G).

match_pattern(papp('NOTHING', []), V, S, [V = nothing], S, V = nothing) :- !.
match_pattern(papp('JUST', [P]), V, S, [V \= nothing|G], S1, V \= nothing) :- !,
    match_pattern(P, V, S, G, S1, _).
match_pattern(papp(C, []), V, S, [V = A], S, V = A) :- pcon(C, _, []), !, name_atom(C, A).
match_pattern(plit(L), V, S, [V = X], S, V = X) :- !, lit_value(L, X).
match_pattern(papp(N, []), V, S, [], [N-v(V)|S], true) :- \+ pcon(N, _, _), !.
match_pattern(P, _, _, _, _, _) :- throw(unsupported(P)).

		 /*******************************
		 *          CONDITIONS          *
		 *******************************/

%!  cond(+Expr, +Scope, -Alts) is det.
%   The conditions under which a boolean expression is true: a list of
%   alternatives, each a list of goals.
cond(E, Scope, Alts) :- ( cond_(E, Scope, Alts) -> true ; throw(unsupported(E)) ).

cond_(and(A, B), S, Alts) :- !, cond(A, S, AA), cond(B, S, BA),
    sfindall(AA-BA, G, ( member(X, AA), member(Y, BA), append(X, Y, G) ), Alts).
cond_(or(A, B), S, Alts) :- !, cond(A, S, AA), cond(B, S, BA), append(AA, BA, Alts).
cond_(implies(A, B), S, Alts) :- !, cond_(or(not(A), B), S, Alts).
cond_(not(A), S, Alts) :- !, ncond(A, S, Alts).
cond_(app('TRUE', []), _, [[]]) :- !.
cond_(app('FALSE', []), _, []) :- !.
cond_(E, S, Alts) :- compare_op(E, Op, A, B), !, compare_alts(Op, A, B, S, Alts).
cond_(E, S, Alts) :-
    sx(E, S, VA),
    sfindall(VA, G, ( member(a(G0, V), VA), truth(V, G1), append(G0, G1, G) ), Alts).

ncond(E, Scope, Alts) :- ( ncond_(E, Scope, Alts) -> true ; throw(unsupported(not(E))) ).

ncond_(and(A, B), S, Alts) :- !, cond_(or(not(A), not(B)), S, Alts).
ncond_(or(A, B), S, Alts) :- !, cond_(and(not(A), not(B)), S, Alts).
ncond_(implies(A, B), S, Alts) :- !, cond_(and(A, not(B)), S, Alts).
ncond_(not(A), S, Alts) :- !, cond(A, S, Alts).
ncond_(app('TRUE', []), _, []) :- !.
ncond_(app('FALSE', []), _, [[]]) :- !.
ncond_(E, S, Alts) :- compare_op(E, Op, A, B), !, negate_op(Op, NOp), compare_alts(NOp, A, B, S, Alts).
ncond_(E, S, Alts) :-
    sx(E, S, VA),
    (   VA = [a(G0, V)], var(V) ; VA = [a(G0, V)], atom(V) )
    ->  ( G0 == [] -> Alts = [[V \= true]] ; Alts = [[\+ (G0, V = true)]] )
    ;   VA = [a([L], true)] -> Alts = [[\+ L]]
    ;   sfindall(VA, G, ( member(a(G0, V), VA), falsity(V, G1), append(G0, G1, G) ), Alts).

truth(V, [V = true]) :- var(V), !.
truth(true, []) :- !.
truth(false, _) :- !, fail.
truth(V, [V = true]).

falsity(V, [V \= true]) :- var(V), !.
falsity(false, []) :- !.
falsity(true, _) :- !, fail.
falsity(V, [V \= true]).

compare_op(eq(A, B), eq, A, B).
compare_op(lt(A, B), <, A, B).
compare_op(gt(A, B), >, A, B).
compare_op(leq(A, B), =<, A, B).
compare_op(geq(A, B), >=, A, B).

negate_op(eq, neq).
negate_op(neq, eq).
negate_op(<, >=).
negate_op(>=, <).
negate_op(>, =<).
negate_op(=<, >).

compare_alts(Op, A, B, S, Alts) :-
    args_alts([A, B], S, AA),
    sfindall(AA, G, ( member(a(G0, [X, Y]), AA), compare_goal(Op, X, Y, G1), append(G0, G1, G) ), Alts).

compare_goal(eq, X, Y, G) :- !, eq_goal(X, Y, G).
compare_goal(neq, X, Y, G) :- !, scalar_or(X, X1), scalar_or(Y, Y1),
    (   ground(X1-Y1) -> \+ same_value(X1, Y1), G = []
    ;   G = [X1 \= Y1] ).

compare_goal(Op, X, Y, G) :- num_val(X, X1), num_val(Y, Y1),
    (   ground(X1-Y1) -> T =.. [Op, X1, Y1], ( call(T) -> G = [] ; fail )
    ;   T =.. [Op, X1, Y1], G = [T] ).

same_value(X, Y) :- X == Y, !.
same_value(X, Y) :- number(X), number(Y), X =:= Y.

eq_goal(X, Y, G) :- scalar_or(X, X1), scalar_or(Y, Y1),
    (   ground(X1-Y1) -> ( X1 == Y1 -> G = [] ; ( number(X1), number(Y1), X1 =:= Y1 ) -> G = [] ; fail )
    ;   G = [X1 = Y1] ).

scalar_or(V, V) :- var(V), !.
scalar_or(nom(X, _), X) :- !.
scalar_or(con(C, Vs), A) :- !, party_value(con(C, Vs), A).
scalar_or(rec(R), _) :- !, ( getenv('L4DBG', _) -> print(user_error, rec(R)), nl(user_error), backtrace(12) ; true ), throw(unsupported("a comparison of two records")).
scalar_or(X, X).

		 /*******************************
		 *   FUNCTIONS AS TIMELESS RULES *
		 *******************************/

%   A function of numbers or text (or a yes/no one) becomes a template of
%   the document and rules: `the <name> of *a …* and … is *a value*`.
scalar_function(N, Ps, Giveth, Body) :-
    \+ record_valued(Giveth, Body),
    \+ ( Giveth == none, record_result(Body) ),
    forall(member(p(_, T), Ps), scalar_type(T)),
    ignore(N = N).

record_result(B) :- record_result(B, 6).

record_result(B, D) :- D > 0, D1 is D - 1,
    (   B = app_named(_, _)
    ;   B = app(C, [_|_]), pcon(C, _, _)
    ;   ( B = where(E, _) ; B = let(_, E) ), record_result(E, D1)
    ;   B = if(_, T, _), record_result(T, D1)
    ;   B = app(G, _), \+ pcon(G, _, _), pdef(G, _, GT, GB, _),
        (   GT \== none -> type_name(GT, T), ( ptype(T, record(_)) ; ptype(T, enum(_)), \+ ( pcon(C2, T, Fs), Fs == [], C2 == C2 ) )
        ;   record_result(GB, D1) )
    ), !.

scalar_type(none) :- !.
scalar_type(T0) :- type_name(T0, T), ( memberchk(T, ['NUMBER', 'STRING', 'BOOLEAN']) ; ptype(T, enum(Cs)), forall(member(C, Cs), pcon(C, _, [])) ), !.

field_function(N, F, Fun) :-
    words_of(F, FWs0), content_words(FWs0, FWs), words_of(N, NWs0), content_words(NWs0, NWs),
    append([FWs, [of], NWs], W), functor_of([value, of|W], Fun),
    (   fn_done(field(N, F)) -> true
    ;   assertz(fn_done(field(N, F))),
        atomic_list_concat(W, ' ', WT),
        format(atom(Text), 'the value of ~w is *a value*', [WT]),
        declare(function, Fun, Text),
        pdef(N, [], _, Body, _),
        sx(proj(Body, F), [], Alts),
        forall(member(a(G, V), Alts),
               ( scalar_or(V, V1), H =.. [Fun, V1], add_item(rules, lps(l_timeless(H, G))) ))
    ).

function_rules(N) :- fn_done(rules(N)), !.
function_rules(N) :-
    assertz(fn_done(rules(N))),
    pdef(N, Ps, _, Body, _),
    words_of(N, NWs),
    findall(Ph, ( member(p(P, T), Ps), place_phrase(place(P, [], T), Ph) ), Phs),
    ( Phs == [] -> Of = '' ; atomic_list_concat(Phs, ' and ', O0), atom_concat(' for ', O0, Of) ),
    atomic_list_concat(NWs, ' ', NT),
    format(atom(Text), 'the value of ~w~w is *a value*', [NT, Of]),
    functor_of([value, of|NWs], Fun),
    length(Ps, NP), Ar is NP + 1,
    assertz(fn_template(N, Fun, Ar)),
    declare(function, Fun, Text),
    length(Vs, NP),
    sfindall(Vs, P-v(V), ( nth1(I, Ps, p(P, _)), nth1(I, Vs, V) ), Scope),
    sx(Body, Scope, Alts),
    forall(member(a(G, V), Alts),
           ( scalar_or(V, V1), append(Vs, [V1], As), H =.. [Fun|As],
             add_item(rules, lps(l_timeless(H, G))) )).

		 /*******************************
		 *         THE DOCUMENT         *
		 *******************************/

declare(Kind, Fun, Text0) :-
    (   item(vocabulary, decl(_, Fun, _)) -> true
    ;   distinct_places(Text0, Text),
        add_item(vocabulary, decl(Kind, Fun, Text))
    ).

%   Two places of one template with the same words would be one variable
%   to LE: a later one gets `input` added (`*an amount input*`).
distinct_places(Text0, Text) :-
    atom_codes(Text0, Cs),
    distinct_(Cs, [], Out),
    atom_codes(Text, Out).

distinct_([], _, []).
distinct_([0'*|Cs], Seen, Out) :-
    append(Ph, [0'*|Rest], Cs), !,
    atom_codes(P, Ph),
    (   memberchk(P, Seen) -> unique_phrase(P, Seen, P1) ; P1 = P ),
    atom_codes(P1, Ph1),
    append([[0'*], Ph1, [0'*]], Head),
    distinct_(Rest, [P1|Seen], Out1),
    append(Head, Out1, Out).
distinct_([C|Cs], Seen, [C|Out]) :- distinct_(Cs, Seen, Out).

unique_phrase(P, Seen, P1) :-
    atom_concat(P, ' input', P0),
    (   memberchk(P0, Seen) -> unique_phrase(P0, Seen, P1) ; P1 = P0 ).

add_item(G, I) :- ( item(G, J), J =@= I -> true ; assertz(item(G, I)) ).

%   A law: its trigger, conditions and effects (initiate/terminate).
add_law(Owner, happens(Ev, T1, T2), Conds0, Effects) :-
    maplist(state_goal(T1), Conds0, Conds),
    include([E]>>(E = initiate(_)), Effects, Ins0), maplist([initiate(F), initiated(F)]>>true, Ins0, Ins),
    include([E]>>(E = terminate(_)), Effects, Outs0), maplist([terminate(F), terminated(F)]>>true, Outs0, Outs),
    append(Ins, Outs, Es),
    add_item(laws(Owner), law(happens(Ev, T1, T2), Conds, Es)).

state_goal(T, holds(F, _), holds(F, T)) :- !.
state_goal(_, G, G).

%   Items in the document's order.
assemble(GIs, Items) :-
    findall(I, ( member(vocabulary-decl(K, F, T), GIs), decl_item(K, F, T, I) ), Voc),
    findall(I, member(facts-I, GIs), Facts),
    findall(I, member(rules-I, GIs), Rules),
    findall(I, member(composite-I, GIs), Comp),
    findall(law(O, L), member(laws(O)-L, GIs), Laws0),
    combine_parts(Laws0, Laws1),
    append(Laws0, Laws1, Laws),
    findall(fact(F, []), ( party_con_fact(A, C, As), party_con_functor(C, Fun), F =.. [Fun, A|As] ), PFacts),
    append(Facts, PFacts, Facts1),
    findall(I, ( member(vocabulary-decl(K, F, T), GIs), decl_item(K, F, T, I) ), Voc1),
    ( Voc1 == Voc -> true ; true ),
    findall(I, ( item(vocabulary, decl(K, F, T)), decl_item(K, F, T, I) ), VocAll),
    findall(Fun-D, ( node(_, ninfo(_, _, _, D, Fl0, _, _)), functor(Fl0, Fun, _) ), Nodes),
    findall(H, member(hist-H, GIs), Hist),
    Items = items(VocAll, Facts1, Rules, Comp, Laws, Nodes-Hist).

decl_item(event, F, T, event(F, T, [])).
decl_item(fluent, F, T, fluent(F, T, [])).
decl_item(template, F, T, template(F, T, [])).
decl_item(function, F, T, template(F, T, [])).

%   RAND/ROR (Machine.hs, RBinOp2): a law that ends a part also ends the
%   contract when that decides it — and: a breach, or a fulfilment when the
%   other part is already fulfilled; or: a fulfilment, or a breach when the
%   other part has already ended in a breach. (Two parts that end on the
%   same event are not put together: neither law sees the other's end.)
combine_parts(Laws0, Laws) :-
    findall(law(combination, law(Tr, Conds, [initiated(Top)|Es])),
            ( member(law(_, law(Tr, Conds0, Es)), Laws0),
              Tr = happens(_, T1, _),
              member(initiated(PF), Es), part_end(PF, K, Op, Kind, Top),
              combined(Op, Kind, K, T1, Extra),
              append(Conds0, Extra, Conds) ), Laws).

%   A part's end: which part, of which operator, fulfilled or breached, and
%   the contract's end it would be.
part_end(PF, K, Op, Kind, Top) :-
    PF =.. [F|Args],
    member(K, [1, 2]), member(Op, [and, or]),
    part_pre(K, Op, Pre, PT),
    atom_concat(Pre, Rest, F),
    atom_concat(the_contract, Rest, TopF),
    Top =.. [TopF|Args],
    ( Rest == '_is_fulfilled' -> Kind = fulfilled ; Kind = breached ),
    item(vocabulary, decl(fluent, F, FT)),
    atom_concat(PT, RT, FT), atom_concat('the contract', RT, TT),
    declare(fluent, TopF, TT).

combined(and, breached, _, _, []).
combined(and, fulfilled, K, T, [holds(Other, T)]) :-
    other_part(K, K2), part_pre(K2, and, Pre, _), atom_concat(Pre, '_is_fulfilled', Other).
combined(or, fulfilled, _, _, []).
combined(or, breached, K, T, [holds(OB, T)]) :-
    other_part(K, K2), part_pre(K2, or, Pre, _), atom_concat(Pre, '_is_breached', Pre1),
    item(vocabulary, decl(fluent, F, _)), atom_concat(Pre1, _, F),
    functor_arity(F, N), length(As, N), OB =.. [F|As].

other_part(1, 2).
other_part(2, 1).

functor_arity(F, N) :- item(vocabulary, decl(fluent, F, T)), aggregate_all(count, sub_atom(T, _, _, _, '*'), S), N is S // 2.

		 /*******************************
		 *         THE MIGRATION        *
		 *******************************/

%!  twin_migration(+Twin, +Options, -Migration) is det.
%
%   The migration (le_migration.pl) of a twin: the document's header,
%   vocabulary, facts, rules, composite events, laws, and a scenario per
%   trace whose values are known. Options: title(T), source(Rel) (the L4
%   file as kept under sources/), results([Line-Text]) (L4's result of
%   each trace, written as the scenario's comment).
twin_migration(twin(Id, Title, items(Voc, Facts, Rules, Comp, Laws, _), Traces, Refused), Options, Migration) :-
    option(source(Src), Options, 'source.l4'),
    option(results(Results), Options, []),
    format(string(HC),
"~w~n~nThe Logical English (for LPS) twin of the contracts of an L4 file (~w), written~nby the L4 translator (the design notes l4.md, step 3). Each obligation, permission or~nprohibition is a fluent that holds while it is open; the events are L4's, with the day~nL4 gives them as their last place. As L4's evaluator does, a missed deadline is~nnoticed when something next happens, and that event does not count towards what~nfollows. Each #TRACE of the file is a scenario; the comment above it is L4's result.", [Title, Src]),
    maplist(decl_ir, Voc, VocIR),
    findall(lps(L), ( member(law(_, law(Tr, Conds, Es)), Laws), member(E, Es), law_term(E, Tr, Conds, L) ), LawIR0),
    law_comments(Laws, LawIR0, LawIR),
    maplist(fact_ir, Facts, FactIR),
    findall(S, ( member(T, Traces), trace_scenario(T, Results, S) ), Scens),
    findall(N, ( member(sc(_, N, _), Scens) ), Ns), max_list([2|Ns], MaxT),
    findall(scenario(Name, Lines, []), member(sc(Name, _, Lines), Scens), ScenIR),
    findall(comment(C), ( member(refused(F, W), Refused), format(string(C), "Not translated: the contract ~w (~w).", [F, W]) ), RefIR),
    format(atom(SrcDoc), 'the L4 source ~w', [Src]), atom_concat('sources/', Src, SrcPath),
    append([[document(SrcDoc, [text(SrcPath)])], RefIR, FactIR, Rules, Comp, LawIR, ScenIR], Items0),
    append(VocIR, Items0, Items),
    Header = [kb(Id), target(lps), setting(max_time, MaxT), comment(HC)],
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    Meta = [program(Id), source('an L4 file (smucclaw/l4-ide)'), artifacts([Src]), translator('the L4 translator'), date(Date)],
    ledger(Laws, Traces, Refused, Ledger),
    Migration = migration(Meta, program(Header, Items), Ledger, []).

decl_ir(event(F, T, _), event(F, T, [known_as(F)])).
decl_ir(fluent(F, T, _), fluent(F, T, [known_as(F)])).
decl_ir(template(F, T, _), template(F, T, [known_as(F)])).
decl_ir(function(F, T), function(F, T, [known_as(F)])).

fact_ir(fact(F, O), fact(F, O)).

law_term(initiated(F), Tr, Conds, initiated(Tr, F, Conds)).
law_term(terminated(F), Tr, Conds, terminated(Tr, F, Conds)).

%   A comment before the laws of each obligation.
law_comments(Laws, IR0, IR) :-
    findall(O, member(law(O, _), Laws), Os0), list_to_set(Os0, Os),
    findall(X, ( member(O, Os), owner_comment(O, C), X = comment(C) ), _),
    law_comments_(Laws, IR0, none, IR).

law_comments_([], [], _, []).
law_comments_([law(O, law(_, _, Es))|Ls], IR0, Prev, IR) :-
    length(Es, N), length(Mine, N), append(Mine, Rest, IR0),
    (   O == Prev -> IR = IR1 ; owner_comment(O, C), IR = [comment(C)|IR1] ),
    append(Mine, IR2, IR1),
    law_comments_(Ls, Rest, O, IR2).

owner_comment(start(F), C) :- format(string(C), "The contract ~w starts: its first obligations.", [F]).
owner_comment(node(F, K), C) :- ordinal_word(K, W), format(string(C), "The ~w obligation of ~w: met, or its deadline missed.", [W, F]).
owner_comment(combination, "The two parts of the contract (RAND, ROR), put together as L4 does.").

%   A trace as a scenario: the start, then each event, one per cycle.
trace_scenario(trace(L, C, _, _, data(F, Start, Inputs, Events)), Results, sc(Name, MaxT, Lines)) :- !,
    format(atom(Name), 'trace_~w', [L]),
    start_literal(F, Start, Inputs, SL),
    findall(Lit, ( member(E, Events), event_literal(E, Lit) ), ELs),
    length(ELs, NE), MaxT is NE + 2,
    findall(raw(Line), ( nth1(I, [SL|ELs], Lit), T1 is I, T2 is I + 1,
                         lit_text(Lit, S), format(atom(Line), '~w from ~w to ~w.', [S, T1, T2]) ), Raw),
    expr_text(C, CT),
    (   memberchk(L-R, Results) -> result_comment(R, RC) ; RC = "(not run)" ),
    format(string(Com0), "#TRACE ~w (line ~w): L4's evaluator ends with~n~w", [CT, L, RC]),
    days_as_dates([Start|Events], DC),
    ( DC == "" -> Com = Com0 ; format(string(Com), "~w~n~w", [Com0, DC]) ),
    Lines = [comment(Com)|Raw].

trace_scenario(trace(L, C, _, _, refused(Why)), _, sc(Name, 2, [comment(Com)])) :-
    format(atom(Name), 'trace_~w', [L]), expr_text(C, CT),
    format(string(Com), "#TRACE ~w (line ~w) is not translated: ~w", [CT, L, Why]).

%   L4 counts a date as a day number (1 January 2025 is day 739616); a trace
%   on dates says which date each day of its scenario is, for the reader.
days_as_dates(Things, Text) :-
    findall(D, ( member(T, Things), ( T = ev(_, _, _, D) -> true ; D = T ), integer(D), D > 100000 ), Ds0),
    sort(Ds0, Ds),
    (   Ds == [] -> Text = ""
    ;   findall(P, ( member(D, Ds), day_date_text(D, DT), format(string(P), "~w is ~w", [D, DT]) ), Ps),
        atomic_list_concat(Ps, ', ', PT),
        format(string(Text), "The days as dates: ~w.", [PT])
    ).

day_date_text(Day, Text) :-
    Stamp is (Day - 719527) * 86400,
    stamp_date_time(Stamp, date(Y, M, D, _, _, _, _, _, _), 'UTC'),
    nth1(M, ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
             'September', 'October', 'November', 'December'], MN),
    format(string(Text), "~w ~w ~w", [D, MN, Y]).

result_comment(R, C) :-
    split_string(R, "\n", "", Ls), maplist([X, Y]>>string_concat("    ", X, Y), Ls, Ls1),
    atomic_list_concat(Ls1, '\n', C).

start_literal(F, Start, Inputs, Lit) :-
    words_of(F, FWs), append([contract|FWs], [starts], FW), functor_of(FW, Fun),
    Lit =.. [Fun, Start|Inputs].

event_literal(ev(P, Con, Leaves, Day), Lit) :- !,
    words_of(Con, CWs), functor_of([does|CWs], Fun),
    append([[P], Leaves, [Day]], As), Lit =.. [Fun|As].
event_literal(clock(Day), the_clock_reaches_day(Day)).

%   A literal's text, through the vocabulary (set by the build as
%   b_setval(l4_dicts, Dicts)).
lit_text(Lit, S) :-
    b_getval(l4_dicts, Dicts),
    le_writer:render_ground_literal(Dicts, Lit, S).

%   The ledger: one entry per obligation and contract, and per trace.
ledger(Laws, Traces, Refused, Ledger) :-
    findall(entry(E, obligation, encoded, 'an obligation -> a fluent; met -> a law of its action; missed -> a law of any later event', F, none),
            ( member(law(node(F, K), _), Laws), format(string(E), "~w, obligation ~w", [F, K]) ), L0),
    list_to_set(L0, L1),
    findall(entry(E, contract, residue, W, F, none), ( member(refused(F, W), Refused), format(string(E), "contract ~w", [F]) ), L2),
    findall(entry(E, trace, Verdict, M, N, none),
            ( member(trace(L, C, _, _, S), Traces), expr_text(C, CT), format(string(E), "#TRACE ~w (line ~w)", [CT, L]),
              format(atom(N), 'trace_~w', [L]),
              (   S = data(_, _, _, _) -> Verdict = encoded, M = 'a #TRACE -> a scenario (its events one per cycle)'
              ;   S = refused(W) -> Verdict = residue, format(atom(M), 'not translated: ~w', [W])
              ) ), L3),
    append([L1, L2, L3], Ledger).

		 /*******************************
		 *   THE RULES HALF'S HOOK      *
		 *******************************/

%!  contract_items(+Ctx, -Items, -Tests, -Ledger) is det.
%
%   The hook of l4_twin.pl (step 2): what the rules half's twin of a file
%   says about the file's contracts. The contracts are twins of their own —
%   in LE for LPS (LPS2's examples/migration/l4/<name>/<name>.le) and as a
%   history view (<name>_history.le beside the rules twin), both written by
%   l4_contracts_build.pl — so the rules twin carries a comment that points
%   to them and a ledger entry per contract, and no copy of them.
contract_items(ctx(l4_module(Items0, _), Options, _), Items, [], Ledger) :-
    findall(N, ( member(decide(_, sig(_, G), appform(N, _, _, _), B, _, _), Items0),
                 ( G = tyapp('DEONTIC', _) -> true ; G == none, contract_expr(B) ) ), Ns0),
    sort(Ns0, Ns),
    (   Ns == [] -> Items = [], Ledger = []
    ;   option(name(Name), Options, twin),
        atomic_list_concat(Ns, ', ', NT),
        (   option(contracts_beside(CF), Options)
        ->  %  a file opened in the editor (l4_import.pl): its contracts twin is beside it
            format(string(C), "The contracts of this file (~w) are a twin of their own, in LE for LPS,~nwritten beside this program (~w): open the L4 file in the LPS2 IDE to run them,~neach #TRACE a scenario.", [NT, CF])
        ;   format(string(C), "The contracts of this file (~w) are twins of their own, written by step 3 of~nthe L4 translator: in LE for LPS, run by LPS2 (LPS2's examples/migration/l4/~w/~w.le,~neach #TRACE a scenario), and as a history view read over a finished history of~nevents (~w_history.le, beside this program).", [NT, Name, Name, Name])
        ),
        Items = [comment(C)],
        findall(entry(N, contract, encoded, 'a contract -> LE for LPS (LPS2) and a history view (step 3)', N, ''), member(N, Ns), Ledger)
    ).

/** <module> L4 contracts → timeless Logical English: the history view

    Step 3 of the design notes l4.md, the second reading of a contract (§4.1):
    the same obligations as the LE for LPS twin (l4_contracts.pl), read over
    a finished history of events. The program says when each obligation
    starts, its deadline, and which events meet it; four rules per
    obligation say how it ends — met, missed, or still pending. Those rules
    are the draft library's (lib_draft/deontic_history.le), written out in
    each obligation's own words: the library itself is not used, because a
    single `*a sentence*` template shared by every obligation makes the
    program unstratified and too slow (lib_draft/README.md). The question the view answers is the one a lawyer is
    asked: given these events, where does the contract stand, and why.

    It is written from what l4_contracts.pl recorded while it compiled the
    contract (the `hist` items: each start, each met law, each missed law,
    with their conditions), so the two twins say the same thing, and each
    history scenario expects what the LPS twin's run ended with — which the
    build checked against L4's evaluator first.
*/

:- module(l4_history, [history_migration/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(yall)).
:- use_module(l4_contracts).

%   The draft library's templates (lib_draft/deontic_history.le), kept for
%   reference and for the node templates they are specialised into.
lib_template(obl_starts,   "the obligation that *a sentence* starts on day *a day*").
lib_template(obl_deadline, "the obligation that *a sentence* has deadline day *a day*").
lib_template(obl_met,      "the obligation that *a sentence* is met on day *a day*").
lib_template(something,    "something happens on day *a day*").
lib_template(can_start,    "an obligation can start on day *a day*").
lib_template(obl_ends,     "the obligation that *a sentence* ends on day *a day*").
lib_template(obl_missed,   "the obligation that *a sentence* is missed on day *a day*").
lib_template(obl_pending,  "the obligation that *a sentence* is pending since day *a day*").
lib_template(obl_passed,   "the deadline of the obligation that *a sentence* has passed on day *a day*").

%!  history_migration(+Twin, +Options, -Migration) is det.
%
%   Options: expected([Line-State]) — the LPS twin's final state for each
%   trace whose scenario agreed with L4 (the others get no expectation),
%   source(Rel), dicts(Dicts) (for rendering the scenario lines).
history_migration(twin(Id0, Title, items(Voc, Facts, Rules, _, Laws, _-Hist), Traces, Refused), Options, Migration) :-
    atom_concat(Id0, '_history', Id),
    option(source(Src), Options, 'source.l4'),
    option(expected(Expected), Options, []),
    option(slow(Slow), Options, []),
    format(string(HC),
"~w: the history view~n~nThe timeless Logical English twin of the contracts of an L4 file (~w), written~nby the L4 translator (the design notes l4.md, step 3): the contracts read over a finished~nhistory of events. For each obligation the program says when it starts, its deadline~nand which events meet it, and four rules say how it ends: met, missed, or still~nopen when the history stops. The same obligations, in the same words, as the LE for LPS twin in LPS2's~nexamples/migration/l4/; each scenario expects what that twin's run ended with, which~nagrees with L4's evaluator.", [Title, Src]),
    %  lib/deontic_history.le's rules, written out for each obligation with
    %  the obligation's own words: first-order templates run much faster than
    %  the library's `*a sentence*` places (the design notes l4.md §8, step 3)
    node_vocabulary(Voc, NodeT, NodeRules),
    LibT = [template(something, "something happens on day *a day*", []),
            template(can_start, "an obligation can start on day *a day*", [])|NodeT],
    findall(I, ( member(V, Voc), voc_item(V, I) ), VocIR),
    findall(fact(F, O), member(fact(F, O), Facts), FactIR),
    findall(rule(H, B, []), ( member(lps(l_timeless(H, Gs)), Rules), conj(Gs, B) ), RuleIR),
    findall(R, ( member(H, Hist), hist_rules(H, R0), member(R1, R0), specialise(R1, R) ), HistIR0),
    list_to_set_variant(HistIR0, HistIR1),
    append(HistIR1, NodeRules, HistIR),
    event_rules(Voc, EvIR),
    part_rules(Voc, PartIR),
    open_rule(OpenIR),
    queries(Voc, Queries),
    findall(S, ( member(T, Traces), history_scenario(T, Voc, Expected, Slow, S) ), Scens),
    findall(comment(C), ( member(refused(F, W), Refused), format(string(C), "Not translated: the contract ~w (~w).", [F, W]) ), RefIR),
    format(atom(SrcDoc), 'the L4 source ~w', [Src]), atom_concat('sources/', Src, SrcPath),
    append([LibT, VocIR,
            [document(SrcDoc, [text(SrcPath)])], RefIR, FactIR, RuleIR, EvIR, HistIR, PartIR, OpenIR, Queries, Scens], Items),
    Header = [kb(Id), target(prolog), comment(HC)],
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    Meta = [program(Id), source('an L4 file (smucclaw/l4-ide)'), artifacts([Src]), translator('the L4 translator'), date(Date)],
    history_ledger(Laws, Traces, Refused, Expected, Slow, Ledger),
    Migration = migration(Meta, program(Header, Items), Ledger, []).

%   The ledger: one entry per obligation, per contract not translated, and
%   per trace, with the verdicts of the LE for LPS twin's ledger
%   (l4_contracts:ledger/4); a trace whose scenario keeps no expectation
%   says why in its note.
history_ledger(Laws, Traces, Refused, Expected, Slow, Ledger) :-
    findall(entry(E, obligation, encoded, 'an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends', F, none),
            ( member(law(node(F, K), _), Laws), format(string(E), "~w, obligation ~w", [F, K]) ), L0),
    list_to_set(L0, L1),
    findall(entry(E, contract, residue, W, F, none), ( member(refused(F, W), Refused), format(string(E), "contract ~w", [F]) ), L2),
    findall(Entry, ( member(T, Traces), trace_entry(T, Expected, Slow, Entry) ), L3),
    append([L1, L2, L3], Ledger).

trace_entry(trace(L, C, _, _, S), Expected, Slow, entry(E, trace, Verdict, M, N, Note)) :-
    l4_contracts:expr_text(C, CT), format(string(E), "#TRACE ~w (line ~w)", [CT, L]),
    format(atom(N), 'trace_~w', [L]),
    (   S = refused(W)
    ->  Verdict = residue, format(atom(M), 'not translated: ~w', [W]), Note = none
    ;   M = 'a #TRACE -> a scenario (its events as facts, each on its day)',
        S = data(_, _, _, Events),
        (   findall(D, member(ev(_, _, _, D), Events), Ds), msort(Ds, SDs), \+ sort(Ds, SDs)
        ->  Verdict = approximated,
            Note = 'two events are on the same day: L4 takes them one after the other, a history read by days cannot order them; no expectation'
        ;   memberchk(L, Slow)
        ->  Verdict = encoded, Note = 'no expectation: longer than the test runner\'s time limit (the LE for LPS twin runs it)'
        ;   memberchk(L-_, Expected)
        ->  Verdict = encoded, Note = none
        ;   Verdict = encoded, Note = 'no expectation: the LE for LPS twin did not reproduce L4\'s result'
        )
    ).

list_to_set_variant([], []).
list_to_set_variant([X|Xs], [X|Ys]) :- exclude(variant_of(X), Xs, Xs1), list_to_set_variant(Xs1, Ys).

variant_of(X, Y) :- Y =@= X.

%   Events and the contract's start are the case's facts; obligations are
%   sentences of the program; ends are concluded.
voc_item(event(does_something_on_day, T, _), template(does_something_on_day, T, [])) :- !.
voc_item(event(F, T, _), template(F, T, [undefined])) :- F \== something_happens_on_day.
voc_item(fluent(F, T, _), template(F, T, [])).
%   The values the contract computes (`the value of … is *a value*`) are
%   asked again and again over a history: worked out once (memorable).
voc_item(template(F, T, _), template(F, T, A)) :- ( sub_atom(F, 0, 9, _, value_of_) -> A = [memorable] ; A = [] ).
voc_item(function(F, T), function(F, T, [])).

conj([], true) :- !.
conj([G], G1) :- !, goal_ir(G, G1).
conj([G|Gs], B) :- goal_ir(G, G1), conj_(Gs, G1, B).

conj_([], B, B).
conj_([G|Gs], Acc, B) :- goal_ir(G, G1), conj_(Gs, and(Acc, G1), B).

goal_ir(\+ G, not(G1)) :- !, goal_ir(G, G1).
goal_ir(X \= Y, not(X = Y)) :- !.
goal_ir(G, G).

%   Rules from what the compiler recorded.
hist_rules(hist(start(_), Ev, Day, Gs, Effs), Rs) :- !,
    findall(R, ( member(initiate(X), Effs), start_rule(X, Day, [Ev|Gs], R) ), Rs0),
    Rs = [rule(can_start(Day), Ev, [])|Rs0].
%   Met: the action, done after the obligation started (L4 looks only at
%   the events after the one that started it) and by its deadline.
hist_rules(hist(met(Fl), Ev, Day, PG, TG), [rule(obl_met(Fl, Day), B, [])]) :- !,
    append([[Ev, obl_starts(Fl, S), S < Day], PG, TG], Gs),
    conj(Gs, B).
hist_rules(hist(ends(Fl), Ev, Day, G, Effs), Rs) :- !,
    findall(R, ( member(initiate(X), Effs), start_rule(X, Day, [obl_ends(Fl, Day), Ev|G], R) ), Rs).
hist_rules(hist(missed(Fl, _), none, Day, G, Effs), Rs) :- !,
    findall(R, ( member(initiate(X), Effs), start_rule(X, Day, [obl_missed(Fl, Day)|G], R) ), Rs).
hist_rules(hist(deadline(Fl, DL), none, none, _, _), [rule(obl_deadline(Fl, DL), obl_starts(Fl, _), [])]) :- !.
hist_rules(_, []).

%   What starts: an obligation (it starts on the day), or an end (the
%   contract fulfilled or breached — concluded outright).
start_rule(X, Day, Conds, rule(H, B, [])) :-
    conj(Conds, B),
    (   functor(X, F, _), sub_atom(F, 0, 2, _, 'o_') -> H = obl_starts(X, Day) ; H = X ).

%   something happens on a day: every event of the case, and the clock.
event_rules(Voc, Rs) :-
    findall(rule(something(D), E, []),
            ( member(event(F, T, _), Voc), \+ memberchk(F, [something_happens_on_day, does_something_on_day]),
              \+ sub_atom(F, 0, 9, _, contract_),
              places(T, N), functor(E, F, N), arg(N, E, D) ), R1),
    findall(rule(can_start(D), something(D), []), true, R2),
    %  `*a party* does something on day *a day*`: any action of the party
    findall(rule(does_something_on_day(P, D), E, []),
            ( memberchk(event(does_something_on_day, _, _), Voc),
              member(event(F, T, _), Voc), sub_atom(F, 0, 5, _, 'does_'), F \== does_something_on_day,
              places(T, N), functor(E, F, N), arg(1, E, P), arg(N, E, D) ), R3),
    append([R1, R2, R3], Rs).

places(T, N) :- aggregate_all(count, sub_atom(T, _, _, _, '*'), S), N is S // 2.

%   RAND and ROR: the two parts' ends put together, as in the LPS twin.
%   Joint parts (RAND): fulfilled when both are, breached as either is.
%   Alternative parts (ROR): fulfilled when either is, breached when both
%   are (as the second is).
part_rules(Voc, Rs) :-
    findall(rule(the_contract_is_fulfilled, and(the_first_joint_part_is_fulfilled, the_second_joint_part_is_fulfilled), []),
            memberchk(fluent(the_first_joint_part_is_fulfilled, _, _), Voc), R1),
    findall(rule(the_contract_is_fulfilled, P, []),
            ( member(P, [the_first_alternative_part_is_fulfilled, the_second_alternative_part_is_fulfilled]),
              memberchk(fluent(P, _, _), Voc) ), R2),
    findall(rule(Top, Part, []),
            ( part_breach(Voc, joint, _, Part, Top) ), R3),
    findall(rule(Top, and(Part, Other), []),
            ( part_breach(Voc, alternative, second, Part, Top),
              part_breach(Voc, alternative, first, Other, _) ), R4),
    append([R1, R2, R3, R4], Rs).

part_breach(Voc, W, O, Part, Top) :-
    member(fluent(PF, T, _), Voc),
    member(O, [first, second]), format(atom(Pre), 'the_~w_~w_part', [O, W]),
    atom_concat(Pre, Rest, PF), sub_atom(Rest, 0, _, _, '_is_breached'),
    places(T, N), atom_concat(the_contract, Rest, TopF),
    length(As, N), Part =.. [PF|As], Top =.. [TopF|As].

open_rule([]).

%   Per obligation (a node fluent F): its seven templates, and the
%   library's four rules over them.
node_vocabulary(Voc, Ts, Rs) :-
    findall(F-T, ( member(fluent(F, T, _), Voc), sub_atom(F, 0, 2, _, 'o_') ), FTs),
    findall(X, ( member(F-T, FTs), node_templates(F, T, Xs), member(X, Xs) ), Ts),
    findall(R, ( member(F-T, FTs), node_rules(F, T, Rs0), member(R, Rs0) ), Rs).

kind_text(starts,   'the obligation that ~w starts on day *a day*').
kind_text(deadline, 'the obligation that ~w has deadline day *a day*').
kind_text(met,      'the obligation that ~w is met on day *a day*').
kind_text(ends,     'the obligation that ~w ends on day *a day*').
kind_text(missed,   'the obligation that ~w is missed on day *a day*').
kind_text(passed,   'the deadline of the obligation that ~w has passed on day *a day*').
kind_text(pending,  'the obligation that ~w is pending since day *a day*').
kind_text(open,     'the obligation that ~w is still open').

kind_functor(K, F, KF) :- atomic_list_concat([K, '_', F], KF).

node_templates(F, T, Ts) :-
    findall(template(KF, Text, Adds),
            ( kind_text(K, Fmt), kind_functor(K, F, KF), format(atom(Text), Fmt, [T]),
              ( memberchk(K, [starts, ends, passed]) -> Adds = [memorable] ; Adds = [] ) ), Ts).

%   A node literal: the node's fluent term with the kind's extra place.
node_lit(K, Fl, D, L) :- Fl =.. [F|As], kind_functor(K, F, KF), ( K == open -> L =.. [KF|As] ; append(As, [D], As1), L =.. [KF|As1] ).

node_rules(F, T, [R1, R2, R3, R4, R5]) :-
    places(T, N), length(As, N), Fl =.. [F|As],
    node_lit(passed, Fl, D, Passed), node_lit(starts, Fl, S, Starts), node_lit(deadline, Fl, DL, Deadline),
    node_lit(met, Fl, D, Met), node_lit(ends, Fl, D, Ends),
    node_lit(passed, Fl, E, PassedE), node_lit(met, Fl, O, MetO),
    node_lit(missed, Fl, D, Missed), node_lit(ends, Fl, _, EndsAny), node_lit(missed, Fl, _, MissedAny),
    node_lit(pending, Fl, S, Pending), node_lit(open, Fl, _, Open), node_lit(pending, Fl, _, PendingAny),
    %  the deadline passed on a day something happened, after the start
    R1 = rule(Passed, and(and(and(and(Starts, Deadline), something(D)), S < D), D > DL), []),
    %  met (in time: the program's rule says so) and not met before
    R2 = rule(Ends, and(Met, not(and(MetO, O < D))), []),
    %  missed: the first day the deadline is seen passed, if never met
    R3 = rule(Missed, and(and(Passed, not(EndsAny)), not(and(PassedE, E < D))), []),
    R4 = rule(Pending, and(and(Starts, not(EndsAny)), not(MissedAny)), []),
    R5 = rule(Open, PendingAny, []).

%   The recorded rules in the per-obligation templates.
specialise(rule(H0, B0, O), rule(H, B, O)) :- spec(H0, H), spec(B0, B).

spec(V, V) :- var(V), !.
spec(obl_starts(Fl, D), L) :- !, node_lit(starts, Fl, D, L).
spec(obl_deadline(Fl, D), L) :- !, node_lit(deadline, Fl, D, L).
spec(obl_met(Fl, D), L) :- !, node_lit(met, Fl, D, L).
spec(obl_ends(Fl, D), L) :- !, node_lit(ends, Fl, D, L).
spec(obl_missed(Fl, D), L) :- !, node_lit(missed, Fl, D, L).
spec(and(A, B), and(A1, B1)) :- !, spec(A, A1), spec(B, B1).
spec(not(A), not(A1)) :- !, spec(A, A1).
spec(X, X).

%   The queries: fulfilled, each kind of breach, what is still open.
queries(Voc, Qs) :-
    Q1 = query(fulfilled, the_contract_is_fulfilled),
    findall(query(QN, Lit),
            ( member(fluent(F, T, _), Voc), sub_atom(F, 0, _, _, the_contract_is_breached),
              places(T, N), length(As, N), Lit =.. [F|As], atom_concat(q_, F, QN) ), Q2),
    findall(query(QN, L), ( member(fluent(F, T, _), Voc), sub_atom(F, 0, 2, _, 'o_'), places(T, N), length(As, N),
                            Fl =.. [F|As], node_lit(open, Fl, _, L), atom_concat(q_open_, F, QN) ), Q3),
    append([[Q1], Q2, Q3], Qs).

%   A trace as a case: its facts, and the answers the LPS twin ended with.
history_scenario(trace(L, C, _, _, data(F, Start, Inputs, Events)), Voc, Expected, Slow, scenario(Name, Lines, [])) :- !,
    format(atom(Name), 'trace_~w', [L]),
    words_of(F, FWs), append([contract|FWs], [starts], FW), atomic_list_concat(FW, '_', SF0),
    atom_codes(SF0, Cs), include([X]>>code_type(X, csym), Cs, Cs1), atom_codes(SF, Cs1),
    SL =.. [SF, Start|Inputs],
    findall(Lit, ( member(E, Events), event_lit(E, Lit) ), ELs),
    findall(fact(X), member(X, [SL|ELs]), Facts),
    l4_contracts:expr_text(C, CT),
    format(string(Com0), "#TRACE ~w (line ~w) of the L4 source", [CT, L]),
    l4_contracts:days_as_dates([Start|Events], DC),
    ( DC == "" -> Com = Com0 ; format(string(Com), "~w~n~w", [Com0, DC]) ),
    (   findall(D, member(ev(_, _, _, D), Events), Ds), msort(Ds, SDs), \+ sort(Ds, SDs)
    ->  Exps = [comment("no expectation: two events of this history are on the same day, which L4 takes one after the other and a history read by days cannot order")]
    ;   memberchk(L, Slow)
    ->  Exps = [comment("no expectation: this history is longer than the test runner's time limit allows the view to read (the LE for LPS twin in LPS2 runs it, and agrees with L4)")]
    ;   memberchk(L-State, Expected)
    ->  expectations(Voc, State, Exps)
    ;   Exps = [comment("no expectation: the LPS twin did not reproduce L4's result for this trace")]
    ),
    append([[comment(Com)], Facts, Exps], Lines).
history_scenario(trace(L, C, _, _, refused(Why)), _, _, _, scenario(Name, [comment(Com)], [])) :-
    format(atom(Name), 'trace_~w', [L]), l4_contracts:expr_text(C, CT),
    format(string(Com), "#TRACE ~w (line ~w) is not translated: ~w", [CT, L, Why]).

event_lit(ev(P, Con, Leaves, Day), Lit) :- !,
    words_of(Con, CWs), atomic_list_concat([does|CWs], '_', F0),
    atom_codes(F0, Cs), include([X]>>code_type(X, csym), Cs, Cs1), atom_codes(F, Cs1),
    append([[P], Leaves, [Day]], As), Lit =.. [F|As].
event_lit(clock(Day), the_clock_reaches_day(Day)).

expectations(Voc, State, Exps) :-
    ( memberchk(the_contract_is_fulfilled, State) -> F = [the_contract_is_fulfilled] ; F = [] ),
    Exps0 = [expects(fulfilled, F)],
    findall(expects(QN, Bs),
            ( member(fluent(BF, _, _), Voc), sub_atom(BF, 0, _, _, the_contract_is_breached), atom_concat(q_, BF, QN),
              findall(S, ( member(S, State), compound_or_atom_functor(S, BF) ), Bs) ), Exps1),
    findall(expects(QN, Os),
            ( member(fluent(F, _, _), Voc), sub_atom(F, 0, 2, _, 'o_'), atom_concat(q_open_, F, QN),
              findall(L, ( member(S, State), compound(S), functor(S, F, _), node_lit(open, S, _, L) ), Os) ), Exps2),
    append([Exps0, Exps1, Exps2], Exps).

compound_or_atom_functor(S, F) :- ( atom(S) -> S == F ; functor(S, F, _) ).

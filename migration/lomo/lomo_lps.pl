/** <module> Step 5: a case of a LOMO register, through time, in LPS

    lps_case(+Register, +Scenario, +LastDate, +OutFile, -Expected)
        Writes OutFile, a program of Logical English for LPS that extends
        lomo_calendar.le (LPS2 examples/migration/lomo/): the duties of the
        case start when their triggers happen, end when they are met, and
        are breached when the clock passes their due days. Expected is what
        the timeless reading of the register (lib/lomo.le, in LE2) says of
        the last day: [open(P, A, R, Day), met(P, A, R), breached(P, A, R, Day)].
    lps_gate(-Results)
        Every case of lps_cases/4: the program written, run by LPS2
        (`lps state`), its final state against Expected.

    Who is bound, by which rule, to which action, after which event and
    within which length of time is the timeless reading's: the translator
    asks it, with the case's facts, and writes the answers as facts of the
    LPS program. LE for LPS counts days, not calendar dates (it refuses date
    arithmetic, `not_lps`): each date of the case becomes a day number, day
    1 being the day before the first date of the case, and each length of
    time after an event a fact `the period "P12M" after day 1 is day 366`,
    calculated by lib/temporal.pl. This is the simple way of the plan
    (LOMO.md §4, item 8).

    Copyright Miguel Calejo; Apache License 2.0.
*/

:- module(lomo_lps, [lps_case/5, lps_gate/1, lps_gate_main/0, lps_cases/4]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(le2(le_kbs)).

:- dynamic rows_/2.

%   lps_cases(Name, Register (under examples/migration/lomo), Scenario, LastDate)
lps_cases(probe_to_1_april_2026, 'cases/probe.le', case_one, date(2026, 4, 1)).
lps_cases(probe_to_15_january_2027, 'cases/probe.le', case_one, date(2027, 1, 15)).
lps_cases(financial_reporting_2027, 'other/financial_reporting_dir_2013_34_lomo_manual.le', reporting_2027, date(2027, 2, 1)).

%   ---- the timeless reading ---------------------------------------------

rows(Text, Rows) :- rows_(Text, Rows), !.
rows(Text, Rows) :-
    nb_getval(lomo_lps_kb, KB-SM),
    parse_custom_query(KB, Text, G),
    term_variables(G, Vs),
    findall(Vs, reasoner:without_explanations(reasoner:i(G, SM, _, _)), Rows0),
    sort(Rows0, Rows),
    assertz(rows_(Text, Rows)).
r2(T, X, Y) :- rows(T, Rs), member([X, Y], Rs).
r3(T, X, Y, Z) :- rows(T, Rs), member([X, Y, Z], Rs).
r4(T, X, Y, Z, W) :- rows(T, Rs), member([X, Y, Z, W], Rs).

with_case(Register, Scenario, Goal) :-
    load(Register, KB), createSession(KB, SM),
    setScenarion(SM, Scenario),
    nb_setval(lomo_lps_kb, KB-SM),
    retractall(rows_(_, _)),
    call(Goal),
    retractall(rows_(_, _)),
    destroySession(SM).

%   A duty of the case: binds(Rule, Party, Action, Event, Duration).
binding(binds(R, P, A, E, Du)) :-
    r2("which rule applies to which party", R, P),
    r2("which rule produces which action", R, A),
    ( r2("which rule has the modality which modality", R, obligation) ; r2("which rule has the modality which modality", R, right) ),
    r3("which thing has which temporal specification as which function", A, S, deadline),
    r2("which temporal specification is later than which second temporal specification", S, S2),
    r2("which temporal specification has the duration which duration", S, Du),
    r2("which temporal specification has the temporal label which text", S2, E).

timeless(Last, Expected) :-
    findall(open(P, A, R, D), ( r4("which party must perform which action by which date under which rule", P, A, D, R),
                                \+ r3("which party met which action under which rule", P, A, R),
                                \+ date_after(Last, D) ), Open),
    findall(met(P, A, R), r3("which party met which action under which rule", P, A, R), Met),
    findall(breached(P, A, R, D), ( r4("which party must perform which action by which date under which rule", P, A, D, R),
                                    \+ r3("which party met which action under which rule", P, A, R),
                                    date_after(Last, D) ), Breached),
    append([Open, Met, Breached], E0), sort(E0, Expected).

date_after(D1, D2) :- day_number(D1, N1), day_number(D2, N2), N1 > N2.

day_number(D, N) :- lomo_temporal:le_temporal_day_number(D, N).

:- prolog_load_context(directory, D),
   atomic_list_concat([D, '/../../lib/temporal.pl'], T),
   ( catch(lomo_temporal:le_temporal_day_number(date(2000,1,1), _), _, fail) -> true ; lomo_temporal:consult(T) ).

%   ---- the program ------------------------------------------------------

lps_case(Register, Scenario, Last, Out, Expected) :-
    with_case(Register, Scenario, case_parts(Last, Bindings, Happens, Performs, Expected0)),
    Expected0 = Expected,
    findall(D, ( member(h(_, _, D), Happens) ; member(p(_, _, D), Performs) ), Ds0),
    ( Ds0 == [] -> Ds = [Last] ; Ds = Ds0 ),
    findall(N, ( member(D, Ds), day_number(D, N) ), Ns), min_list(Ns, Min),
    Base is Min - 1,                                  % day 1 is the day before the first date
    day_of(Base, Last, LastDay),
    %  the periods after each triggering event of the case
    findall(period(Du, Day, DueDay),
            ( member(binds(_, P, _, E, Du), Bindings), member(h(E, P, D), Happens),
              day_of(Base, D, Day),
              lomo_temporal:le_temporal_add_period(D, Du, 1, DD), day_of(Base, DD, DueDay) ),
            Periods0), sort(Periods0, Periods),
    %  the timeline: the events of the case, and the clock on each day after a due day, and on the last day
    findall(Day-happens(E, P), ( member(h(E, P, D), Happens), day_of(Base, D, Day), Day =< LastDay ), T1),
    findall(Day-performs(P, A), ( member(p(P, A, D), Performs), day_of(Base, D, Day), Day =< LastDay ), T2),
    findall(Day-clock, ( member(period(_, _, DueDay), Periods), Day is DueDay + 1, Day =< LastDay ), T3),
    append([T1, T2, T3, [LastDay-clock]], T0), sort(T0, Timeline),
    findall(Day, member(Day-_, Timeline), Days0), sort(Days0, Days),
    length(Days, NC), MaxTime is NC + 2,
    expected_days(Base, Expected, ExpectedDays),
    write_program(Out, Register, Scenario, Last, Base, MaxTime, Bindings, Periods, Days, Timeline, ExpectedDays).

case_parts(Last, Bindings, Happens, Performs, Expected) :-
    findall(B, binding(B), Bs0), sort(Bs0, Bindings),
    findall(h(E, P, D), r3("which event happens to which party on which date", E, P, D), Happens),
    findall(p(P, A, D), r3("which party performs which action on which date", P, A, D), Performs),
    timeless(Last, Expected).

day_of(Base, D, Day) :- day_number(D, N), Day is N - Base.

expected_days(Base, Es, Ds) :-
    findall(F, ( member(E, Es), expected_day(Base, E, F) ), Ds0),
    sort(Ds0, Ds).

expected_day(Base, open(P, A, R, D), lomo_owes(P, A, R, N)) :- day_of(Base, D, N).
expected_day(_, met(P, A, R), lomo_met(P, A, R)).
expected_day(Base, breached(P, A, R, D), lomo_breached(P, A, R, N)) :- day_of(Base, D, N).

write_program(Out, Register, Scenario, Last, Base, MaxTime, Bindings, Periods, Days, Timeline, Expected) :-
    file_base_name(Register, RB), file_name_extension(RS, _, RB),
    file_base_name(Out, OB), file_name_extension(KB, _, OB),
    lomo_temporal:le_temporal_date_of_day(Base, date(Y0, M0, Dd0)),
    format(atom(D0), "~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+", [Y0, M0, Dd0]),
    Last = date(YL, ML, DL), format(atom(LastT), "~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+", [YL, ML, DL]),
    setup_call_cleanup(open(Out, write, S, [encoding(utf8)]),
        (   format(S, "% The case `~w` of the LOMO register ~w, through time.~n", [Scenario, RS]),
            format(S, "% Written by LE2's LOMO translator (migration/lomo/lomo_lps.pl) from the~n", []),
            format(S, "% register and the case: who is bound, to what, after which event, is the~n", []),
            format(S, "% timeless reading of LE2 (lib/lomo.le). Day 0 is ~w; each date of the~n", [D0]),
            format(S, "% case is a day number. Do not edit: build it again.~n%~n", []),
            format(S, "% What the timeless reading says of the last day, ~w, and what the run~n", [LastT]),
            format(S, "% must end with:~n", []),
            forall(member(E, Expected), ( lps_sentence(E, Txt), format(S, "%     ~w~n", [Txt]) )),
            ( Expected == [] -> format(S, "%     (no duty)~n", []) ; true ),
            format(S, "~nthe target language is: lps.~n~nthe maximum time is ~w.~n~n", [MaxTime]),
            format(S, "the knowledge base ~w extends lomo_calendar.~n~n", [KB]),
            format(S, "the knowledge base ~w includes:~n~n", [KB]),
            forall(member(binds(R, P, A, E, Du), Bindings),
                   format(S, "~w binds ~w to ~w after ~q within ~q.~n", [R, P, A, E, Du])),
            nl(S),
            forall(member(period(Du, Day, DD), Periods),
                   format(S, "the period ~q after day ~w is day ~w.~n", [Du, Day, DD])),
            format(S, "~nscenario ~w is:~n", [Scenario]),
            forall(nth1(I, Days, Day),
                   ( I1 is I + 1,
                     forall(member(Day-Ev, Timeline), ( event_text(Ev, Day, Txt), format(S, "    ~w from ~w to ~w.~n", [Txt, I, I1]) )) ))
        ),
        close(S)).

event_text(happens(E, P), Day, T) :- format(string(T), "~q happens to ~w on day ~w", [E, P, Day]).
event_text(performs(P, A), Day, T) :- format(string(T), "~w performs ~w on day ~w", [P, A, Day]).
event_text(clock, Day, T) :- format(string(T), "the clock reaches day ~w", [Day]).

lps_sentence(lomo_owes(P, A, R, N), T) :- format(string(T), "~w owes ~w under ~w by day ~w", [P, A, R, N]).
lps_sentence(lomo_met(P, A, R), T) :- format(string(T), "~w met ~w under ~w", [P, A, R]).
lps_sentence(lomo_breached(P, A, R, N), T) :- format(string(T), "~w breached ~w under ~w by day ~w", [P, A, R, N]).

%   ---- the gate -----------------------------------------------------------

lps_dir(D) :- le2_paths:lps2_dir(L), atomic_list_concat([L, '/examples/migration/lomo'], D).

lps_gate(Results) :-
    twins_dir(lomo, Root), lps_dir(LD),
    findall(R, ( lps_cases(Name, Rel, Scen, Last),
                 atomic_list_concat([Root, '/', Rel], Reg),
                 atomic_list_concat([LD, '/', Name, '.le'], Out),
                 lps_case(Reg, Scen, Last, Out, Exp),
                 expected_of(Out, Expected),
                 lps_final(Out, Scen, Final),
                 R = case(Name, Expected, Final, Exp) ), Results).

expected_of(Out, Expected) :-
    read_file_to_string(Out, S, []),
    split_string(S, "\n", "", Ls),
    findall(T, ( member(L, Ls), string_concat("%     ", T0, L), T0 \== "(no duty)", T = T0 ), Expected0),
    sort(Expected0, Expected).

lps_final(File, Scen, Final) :-
    le2_paths:lps2_dir(L), le2_paths:le2_dir(LE2),
    atomic_list_concat([L, '/lps'], Lps),
    process_create(Lps, [state, File, '--scenario', Scen],
                   [cwd(L), stdout(pipe(Out)), stderr(null), environment(['LPS_LE2_LIB'=LE2]), process(Pid)]),
    read_string(Out, _, S), close(Out), process_wait(Pid, _),
    split_string(S, "\n", " \t", Lines),
    findall(T, ( member(Ln, Lines), Ln \== "", catch(term_string(T0, Ln), _, fail), lomo_fluent(T0),
                 lps_sentence(T0, T) ), Final0),
    sort(Final0, Final).

lomo_fluent(T) :- compound(T), functor(T, F, _), memberchk(F, [lomo_owes, lomo_met, lomo_breached]).

lps_gate_main :-
    lps_gate(Rs),
    forall(member(case(N, E, F, _), Rs),
           (   E == F -> format("~w: the same (~w)~n", [N, E])
           ;   format("~w: DIFFERENT~n   timeless ~q~n   LPS      ~q~n", [N, E, F])
           )).

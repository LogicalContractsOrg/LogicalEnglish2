/** <module> Step 5: a case of a LOMO register, through time, in LPS

    lps_case(+Register, +Scenario, +Last, +OutFile, -Expected)
        Writes OutFile, a program of Logical English for LPS that extends
        lomo_calendar.le (LPS2 examples/migration/lomo/): the duties of the
        case start when their triggers happen, end when they are met, and
        are breached when the clock passes their due times; a repeating duty
        starts its next occurrence when the clock passes the due time of the
        current one. Last is the last date (or moment) of the run. Expected
        is what the timeless reading of the register (lib/lomo.le, in LE2)
        says of Last, as the fluents the run must end with.
    lps_gate(-Results)
        Every case of lps_cases/4: the program written, run by LPS2
        (`lps state`), its final state against Expected.

    Who is bound, by which rule, to which action, after which event, within
    which length of time, and the due dates of each occurrence of a
    repeating duty: all of it is the timeless reading's. The translator asks
    LE2 with the case's facts and writes the answers as facts of the LPS
    program. LE for LPS counts, it does not do calendar arithmetic (date
    arithmetic is `not_lps`): each date of the case becomes a time, a number
    of days, or a number of minutes when the case gives moments
    ("2026-03-01T14:30"); time 1 is the first day (or minute) of the case,
    and each length of time after an event is a fact `the period "PT72H"
    after time 1 is time 4321`, calculated by lib/temporal.pl.

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

%   lps_cases(Name, Register (under examples/migration/lomo), Scenario, Last)
lps_cases(probe_to_1_april_2026, 'cases/probe.le', case_one, date(2026, 4, 1)).
lps_cases(probe_to_15_january_2027, 'cases/probe.le', case_one, date(2027, 1, 15)).
lps_cases(probe_to_the_minute, 'cases/probe.le', to_the_minute, "2026-03-05T00:00").
lps_cases(financial_reporting_2027, 'other/financial_reporting_dir_2013_34_lomo_manual.le', reporting_2027, date(2027, 2, 1)).
lps_cases(annual_report_to_30_june_2027, 'cases/annual_report.le', three_reports, date(2027, 6, 30)).

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
r5(T, X, Y, Z, W, V) :- rows(T, Rs), member([X, Y, Z, W, V], Rs).

with_case(Register, Scenario, Goal) :-
    load(Register, KB), createSession(KB, SM),
    setScenarion(SM, Scenario),
    nb_setval(lomo_lps_kb, KB-SM),
    retractall(rows_(_, _)),
    call(Goal),
    retractall(rows_(_, _)),
    destroySession(SM).

%   A one-off duty of the case: binds(Rule, Party, Action, Event, Duration).
binding(binds(R, P, A, E, Du)) :-
    r2("which rule applies to which party", R, P),
    r2("which rule produces which action", R, A),
    ( r2("which rule has the modality which modality", R, obligation) ; r2("which rule has the modality which modality", R, right) ),
    r3("which thing has which temporal specification as which function", A, S, deadline),
    r2("which temporal specification is later than which second temporal specification", S, S2),
    r2("which temporal specification has the duration which duration", S, Du),
    r2("which temporal specification has the temporal label which text", S2, E).

%   A repeating duty: rhythm(Rule, Party, Action, Duration, [K-DueDate, ...]).
rhythm(Last, rhythm(R, P, A, Du, Occs)) :-
    last_day(Last, Day), date_text(Day, DT),
    format(string(Q), "the occurrence which number of which action under which rule for which party is due on which date as of ~w", [DT]),
    rows(Q, Rows),
    setof(R-P-A, K^D^member([K, A, R, P, D], Rows), RPAs),
    member(R-P-A, RPAs),
    findall(K-D, member([K, A, R, P, D], Rows), Occs0), sort(Occs0, Occs),
    once(( r3("which thing has which temporal specification as which function", A, S, deadline),
           r2("which temporal specification has the frequency which duration", S, Du) )).

%   The timeless reading of Last: open(P,A,R,Due), met(P,A,R,Due), breached(P,A,R,Due).
timeless(Last, Expected) :-
    last_day(Last, Day), date_text(Day, DT),
    findall(E, one_off_date(Last, E), E1),
    findall(E, one_off_moment(Last, E), E2),
    format(string(QM), "which party met the occurrence which number of which action under which rule as of ~w", [DT]),
    format(string(QB), "which party breached the occurrence which number of which action under which rule as of ~w", [DT]),
    format(string(QO), "which party owes the occurrence which number of which action under which rule as of ~w", [DT]),
    format(string(QD), "the occurrence which number of which action under which rule for which party is due on which date as of ~w", [DT]),
    findall(met(P, A, R, D), ( r4(QM, P, K, A, R), r5(QD, K, A, R, P, D) ), E3),
    findall(breached(P, A, R, D), ( r4(QB, P, K, A, R), r5(QD, K, A, R, P, D) ), E4),
    findall(open(P, A, R, D), ( r4(QO, P, K, A, R), r5(QD, K, A, R, P, D) ), E5),
    append([E1, E2, E3, E4, E5], E0), sort(E0, Expected).

one_off_date(Last, E) :-
    r4("which party must perform which action by which date under which rule", P, A, D, R),
    (   r3("which party met which action under which rule", P, A, R) -> E = met(P, A, R, D)
    ;   after(Last, D) -> E = breached(P, A, R, D)
    ;   E = open(P, A, R, D)
    ).
one_off_moment(Last, E) :-
    r4("which party must perform which action by the moment which moment under which rule", P, A, M, R),
    (   r3("which party met which action in time under which rule", P, A, R) -> E = met(P, A, R, M)
    ;   after(Last, M) -> E = breached(P, A, R, M)
    ;   E = open(P, A, R, M)
    ).

last_day(date(Y, M, D), date(Y, M, D)) :- !.
last_day(Moment, Date) :- lomo_temporal:le_temporal_moment(Moment, Date, _).

date_text(date(Y, M, D), T) :- format(string(T), "~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, D]).

:- prolog_load_context(directory, D),
   atomic_list_concat([D, '/../../lib/temporal.pl'], T),
   ( catch(lomo_temporal:le_temporal_day_number(date(2000,1,1), _), _, fail) -> true ; lomo_twin:load_clauses(T, lomo_temporal) ).

%   ---- times: days, or minutes when the case gives moments -----------------

%   absolute(+Unit, +DateOrMoment, -N): days since 1970, or minutes.
absolute(days, date(Y, M, D), N) :- !, lomo_temporal:le_temporal_day_number(date(Y, M, D), N).
absolute(days, Moment, N) :- lomo_temporal:le_temporal_moment(Moment, Date, _), lomo_temporal:le_temporal_day_number(Date, N).
absolute(minutes, date(Y, M, D), N) :- !, lomo_temporal:le_temporal_day_number(date(Y, M, D), DN), N is DN * 1440.
absolute(minutes, Moment, N) :- lomo_temporal:le_temporal_moment_seconds(Moment, S), N is S // 60.

after(A, B) :- absolute(minutes, A, NA), absolute(minutes, B, NB), NA > NB.

add_period(date(Y, M, D), Du, Later) :- !, lomo_temporal:le_temporal_add_period(date(Y, M, D), Du, 1, Later).
add_period(Moment, Du, Later) :- lomo_temporal:le_temporal_add_period_moment(Moment, Du, 1, Later).

%   ---- the program ------------------------------------------------------

lps_case(Register, Scenario, Last, Out, Expected) :-
    with_case(Register, Scenario, case_parts(Last, Bindings, Rhythms, Happens, Performs, Expected)),
    unit(Happens, Performs, Last, Unit),
    findall(X, ( member(h(_, _, X), Happens) ; member(p(_, _, X), Performs) ;
                 member(rhythm(_, _, _, _, Os), Rhythms), member(_-X, Os) ), Xs0),
    ( Xs0 == [] -> Xs = [Last] ; Xs = Xs0 ),
    findall(N, ( member(X, Xs), absolute(Unit, X, N) ), Ns), min_list(Ns, Min),
    Base is Min - 1,                                    % time 1: the first day (or minute) of the case
    time_of(Unit, Base, Last, LastT),
    %  one-off duties: the due time after each triggering event of the case
    findall(period(Du, T, DT),
            ( member(binds(_, P, _, E, Du), Bindings), member(h(E, P, X), Happens),
              time_of(Unit, Base, X, T), add_period(X, Du, DX), time_of(Unit, Base, DX, DT) ),
            Periods0), sort(Periods0, Periods),
    %  repeating duties: the due time of each occurrence
    findall(occurrence(R, P, K, T),
            ( member(rhythm(R, P, _, _, Os), Rhythms), member(K-D, Os), time_of(Unit, Base, D, T) ), Occs),
    %  the timeline: the clock after each due time and at the end first, then
    %  the triggers, then the actions, each kind of event at one time in a
    %  cycle of its own
    findall(T-0-clock, ( ( member(period(_, _, DT), Periods) ; member(occurrence(_, _, _, DT), Occs) ),
                         T is DT + 1, T =< LastT ), C1),
    findall(T-1-happens(E, P), ( member(h(E, P, X), Happens), time_of(Unit, Base, X, T), T =< LastT ), C2),
    findall(T-2-performs(P, A), ( member(p(P, A, X), Performs), time_of(Unit, Base, X, T), T =< LastT ), C3),
    append([C1, C2, C3, [LastT-0-clock]], C0), sort(C0, Timeline),
    findall(T-O, member(T-O-_, Timeline), Slots0), sort(Slots0, Slots),
    length(Slots, NC), MaxTime is NC + 2,
    expected_times(Unit, Base, Expected, ExpectedFluents),
    write_program(Out, Register, Scenario, Last, Unit, Base, MaxTime, Bindings, Periods, Rhythms, Occs, Slots, Timeline, ExpectedFluents).

%   Minutes when the case gives a moment anywhere, else days.
unit(Happens, Performs, Last, Unit) :-
    (   ( member(h(_, _, X), Happens) ; member(p(_, _, X), Performs) ; X = Last ), \+ X = date(_, _, _)
    ->  Unit = minutes ; Unit = days
    ).

case_parts(Last, Bindings, Rhythms, Happens, Performs, Expected) :-
    findall(B, binding(B), Bs0), sort(Bs0, Bindings),
    findall(Rh, rhythm(Last, Rh), Rhythms),
    findall(h(E, P, D), ( r3("which event happens to which party on which date", E, P, D)
                        ; r3("which event happens to which party at which moment", E, P, D) ), Happens),
    findall(p(P, A, D), ( r3("which party performs which action on which date", P, A, D)
                        ; r3("which party performs which action at which moment", P, A, D) ), Performs),
    timeless(Last, Expected).

time_of(Unit, Base, X, T) :- absolute(Unit, X, N), T is N - Base.

expected_times(Unit, Base, Es, Fs) :-
    findall(F, ( member(E, Es), expected_time(Unit, Base, E, F) ), Fs0),
    sort(Fs0, Fs).

expected_time(U, B, open(P, A, R, D), lomo_owes(P, A, R, N)) :- time_of(U, B, D, N).
expected_time(U, B, met(P, A, R, D), lomo_met(P, A, R, N)) :- time_of(U, B, D, N).
expected_time(U, B, breached(P, A, R, D), lomo_breached(P, A, R, N)) :- time_of(U, B, D, N).

write_program(Out, Register, Scenario, Last, Unit, Base, MaxTime, Bindings, Periods, Rhythms, Occs, Slots, Timeline, Expected) :-
    file_base_name(Register, RB), file_name_extension(RS, _, RB),
    file_base_name(Out, OB), file_name_extension(KB, _, OB),
    origin_text(Unit, Base, Origin),
    last_text(Last, LastText),
    setup_call_cleanup(open(Out, write, S, [encoding(utf8)]),
        (   format(S, "% The case `~w` of the LOMO register ~w, through time.~n", [Scenario, RS]),
            format(S, "% Written by LE2's LOMO translator (migration/lomo/lomo_lps.pl) from the~n", []),
            format(S, "% register and the case: who is bound, to what, after which event, and the~n", []),
            format(S, "% due dates of each occurrence of a repeating duty, are the timeless reading~n", []),
            format(S, "% of LE2 (lib/lomo.le). A time is a number of ~w; time 0 is ~w.~n", [Unit, Origin]),
            format(S, "% Do not edit: build it again.~n%~n", []),
            format(S, "% What the timeless reading says of the last ~w, ~w, and what the run~n", [Unit, LastText]),
            format(S, "% must end with:~n", []),
            forall(member(E, Expected), ( lps_sentence(E, Txt), format(S, "%     ~w~n", [Txt]) )),
            ( Expected == [] -> format(S, "%     (no duty)~n", []) ; true ),
            format(S, "~nthe target language is: lps.~n~nthe maximum time is ~w.~n~n", [MaxTime]),
            format(S, "the knowledge base ~w extends lomo_calendar.~n~n", [KB]),
            format(S, "the knowledge base ~w includes:~n~n", [KB]),
            forall(member(binds(R, P, A, E, Du), Bindings),
                   format(S, "~w binds ~w to ~w after ~q within ~q.~n", [R, P, A, E, Du])),
            forall(member(period(Du, T, DT), Periods),
                   format(S, "the period ~q after time ~w is time ~w.~n", [Du, T, DT])),
            forall(member(rhythm(R, P, A, Du, _), Rhythms),
                   format(S, "~w binds ~w to ~w every ~q.~n", [R, P, A, Du])),
            forall(member(occurrence(R, P, K, T), Occs),
                   format(S, "the occurrence ~w of ~w for ~w is due by time ~w.~n", [K, R, P, T])),
            forall(( member(rhythm(R, P, A, _, _), Rhythms), member(occurrence(R, P, 1, T1), Occs) ),
                   format(S, "initially the rhythm of ~w for ~w is at occurrence 1.~ninitially ~w owes ~w under ~w by time ~w.~n", [R, P, P, A, R, T1])),
            format(S, "~nscenario ~w is:~n", [Scenario]),
            forall(nth1(I, Slots, Slot),
                   ( I1 is I + 1,
                     Slot = T-O,
                     forall(member(T-O-Ev, Timeline), ( event_text(Ev, T, Txt), format(S, "    ~w from ~w to ~w.~n", [Txt, I, I1]) )) ))
        ),
        close(S)).

origin_text(days, Base, T) :- lomo_temporal:le_temporal_date_of_day(Base, D), date_text(D, T).
origin_text(minutes, Base, T) :-
    DN is Base // 1440, Min is Base mod 1440,
    lomo_temporal:le_temporal_date_of_day(DN, D), Secs is Min * 60,
    lomo_temporal:le_temporal_moment_text(D, Secs, T).

last_text(date(Y, M, D), T) :- !, date_text(date(Y, M, D), T).
last_text(M, M).

event_text(happens(E, P), T, Txt) :- format(string(Txt), "~q happens to ~w at time ~w", [E, P, T]).
event_text(performs(P, A), T, Txt) :- format(string(Txt), "~w performs ~w at time ~w", [P, A, T]).
event_text(clock, T, Txt) :- format(string(Txt), "the clock reaches time ~w", [T]).

lps_sentence(lomo_owes(P, A, R, N), T) :- format(string(T), "~w owes ~w under ~w by time ~w", [P, A, R, N]).
lps_sentence(lomo_met(P, A, R, N), T) :- format(string(T), "~w met ~w under ~w by time ~w", [P, A, R, N]).
lps_sentence(lomo_breached(P, A, R, N), T) :- format(string(T), "~w breached ~w under ~w by time ~w", [P, A, R, N]).

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

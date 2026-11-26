/*  lib/temporal.pl — the date arithmetic behind lib/temporal.le

    Extension E3 of the design notes roadmap.md (§7.2): a
    library, not syntax. Dates are LE's own date(Year, Month, Day) terms.
    Pure arithmetic only (days from the civil calendar, no clock).

    The predicates at the end are the templates of temporal.le, under the
    names LE gives them (a template's words, its slots left out), with their
    arguments in the order of the slots: LE calls them directly.

    Loaded assert-only as a Prolog resource (docs/user/reference/language.md §14.1).
*/

%   Days since 1970-01-01 of a civil date (Howard Hinnant's algorithm).
le_temporal_day_number(date(Y0, M, D), N) :-
    ( M =< 2 -> Y is Y0 - 1 ; Y = Y0 ),
    Era is Y // 400,
    YoE is Y - Era * 400,
    ( M > 2 -> MP is M - 3 ; MP is M + 9 ),
    DoY is (153 * MP + 2) // 5 + D - 1,
    DoE is YoE * 365 + YoE // 4 - YoE // 100 + DoY,
    N is Era * 146097 + DoE - 719468.

le_temporal_date_of_day(N, date(Y, M, D)) :-
    Z is N + 719468,
    Era is Z // 146097,
    DoE is Z - Era * 146097,
    YoE is (DoE - DoE // 1460 + DoE // 36524 - DoE // 146096) // 365,
    Y0 is YoE + Era * 400,
    DoY is DoE - (365 * YoE + YoE // 4 - YoE // 100),
    MP is (5 * DoY + 2) // 153,
    D is DoY - (153 * MP + 2) // 5 + 1,
    ( MP < 10 -> M is MP + 3 ; M is MP - 9 ),
    ( M =< 2 -> Y is Y0 + 1 ; Y = Y0 ).

le_temporal_leap(Y) :- Y mod 4 =:= 0, ( Y mod 100 =\= 0 ; Y mod 400 =:= 0 ).

%   No cuts in this file: LE's reasoner runs a resource's clauses itself
%   (for the explanations), and a cut there does not prune.
le_temporal_days_in_month(Y, M, L) :-
    (   M =:= 2 -> ( le_temporal_leap(Y) -> L = 29 ; L = 28 )
    ;   memberchk(M, [4, 6, 9, 11]) -> L = 30
    ;   L = 31
    ).

%   The number of days from the first date to the second (negative when the
%   second is earlier).
le_temporal_days_between(D1, D2, N) :-
    le_temporal_day_number(D1, N1), le_temporal_day_number(D2, N2),
    N is N2 - N1.

%   The number of WHOLE years from the first date to the second: an age.
le_temporal_years_between(date(Y1, M1, D1), date(Y2, M2, D2), N) :-
    N0 is Y2 - Y1,
    ( ( M2 < M1 ; M2 =:= M1, D2 < D1 ) -> N is N0 - 1 ; N = N0 ).

%   The number of WHOLE calendar months from the first date to the second.
le_temporal_months_between(date(Y1, M1, D1), date(Y2, M2, D2), N) :-
    N0 is (Y2 - Y1) * 12 + (M2 - M1),
    ( D2 < D1, \+ le_temporal_last_day(date(Y2, M2, D2)) -> N is N0 - 1 ; N = N0 ).

le_temporal_last_day(date(Y, M, D)) :- le_temporal_days_in_month(Y, M, D).

%   The date N calendar months after a date (N may be negative): the same
%   day, or the last day of a shorter month (31 August + 6 months = 28/29
%   February), as LE's own `months after` does.
le_temporal_add_months(date(Y, M, D), N, date(Y2, M2, D2)) :-
    T is Y * 12 + (M - 1) + N,
    Y2 is T // 12, M2 is T mod 12 + 1,
    le_temporal_days_in_month(Y2, M2, L),
    D2 is min(D, L).

le_temporal_sub_months(Date, N, Earlier) :-
    M is -N,
    le_temporal_add_months(Date, M, Earlier).

le_temporal_add_years(Date, N, Later) :-
    M is N * 12,
    le_temporal_add_months(Date, M, Later).

le_temporal_add_days(Date, N, Later) :-
    le_temporal_day_number(Date, K), K2 is K + N,
    le_temporal_date_of_day(K2, Later).

le_temporal_month_start(date(Y, M, _), date(Y, M, 1)).

le_temporal_month_end(date(Y, M, _), date(Y, M, L)) :-
    le_temporal_days_in_month(Y, M, L).

le_temporal_year(date(Y, _, _), Y).
le_temporal_month(date(_, M, _), M).
le_temporal_day(date(_, _, D), D).

%   A date is in the period from Start to End, both included.
le_temporal_in_period(Date, Start, End) :-
    le_temporal_day_number(Date, N), le_temporal_day_number(Start, S), le_temporal_day_number(End, E),
    N >= S, N =< E.

%   "in the last N months" before a reference date: after the date N
%   calendar months before it, up to and including the reference date.
le_temporal_within_months_before(Date, N, Ref) :-
    Back is -N,
    le_temporal_add_months(Ref, Back, Start),
    le_temporal_day_number(Start, S), le_temporal_day_number(Date, K), le_temporal_day_number(Ref, R),
    K > S, K =< R.

le_temporal_within_days_before(Date, N, Ref) :-
    le_temporal_day_number(Date, K), le_temporal_day_number(Ref, R),
    K =< R, R - K < N.

%   ISO weekday, 1 (Monday) to 7 (Sunday).
le_temporal_weekday(Date, W) :-
    le_temporal_day_number(Date, N),
    W is (N + 3) mod 7 + 1.

%   Bitcoin lock times (BIP 65 / BIP 68): an absolute lock time below
%   500000000 is a block height, otherwise a Unix time; a relative lock
%   (nSequence, older(n)) counts blocks.
le_temporal_lock_is_height(T) :- integer(T), T < 500000000.
le_temporal_lock_is_time(T) :- integer(T), T >= 500000000.


%   ---- ISO 8601 lengths of time: P1Y, P12M, P20D, P1W, P4Y1D, PT72H --------
%
%   A length of time written the ISO way: P, then years (Y), months (M),
%   weeks (W) and days (D), then T and hours (H), minutes (M) and seconds (S).
%   Dates in LE are days: hours, minutes and seconds count as whole days,
%   rounded up (PT72H is 3 days, PT1H is 1 day). No cut: LE's reasoner runs
%   these clauses itself.

le_temporal_iso(Text, period(Y, Mo, D, Secs)) :-
    ( string(Text) -> string_codes(Text, Cs) ; atom(Text) -> atom_codes(Text, Cs) ),
    Cs = [0'P|Rest], Rest \== [],
    le_temporal_iso_scan(Rest, date, 0-0-0-0-0-0-0, Y-Mo-W-D0-H-Mi-S),
    D is D0 + 7 * W,
    Secs is H * 3600 + Mi * 60 + S.

%   Scan "<number><letter>" pairs; Part is date before the T, time after.
le_temporal_iso_scan([], time, Acc, Acc) :- Acc \== 0-0-0-0-0-0-0.
le_temporal_iso_scan([], date, Acc, Acc).
le_temporal_iso_scan([0'T|Cs], date, Acc0, Acc) :-
    Cs \== [],
    le_temporal_iso_scan(Cs, time, Acc0, Acc).
le_temporal_iso_scan([C|Cs], Part, Acc0, Acc) :-
    code_type(C, digit),
    le_temporal_iso_number([C|Cs], NCs, Rest),
    Rest = [L|Rest1],
    number_codes(N, NCs),
    le_temporal_iso_unit(Part, L, N, Acc0, Acc1),
    le_temporal_iso_scan(Rest1, Part, Acc1, Acc).

le_temporal_iso_number([C|Cs], [C|Ns], Rest) :-
    ( code_type(C, digit) ; C == 0'. ),
    (   Cs = [C2|_], ( code_type(C2, digit) ; C2 == 0'. )
    ->  le_temporal_iso_number(Cs, Ns, Rest)
    ;   Ns = [], Rest = Cs
    ).

le_temporal_iso_unit(date, 0'Y, N, _-Mo-W-D-H-Mi-S, N-Mo-W-D-H-Mi-S).
le_temporal_iso_unit(date, 0'M, N, Y-_-W-D-H-Mi-S, Y-N-W-D-H-Mi-S).
le_temporal_iso_unit(date, 0'W, N, Y-Mo-_-D-H-Mi-S, Y-Mo-N-D-H-Mi-S).
le_temporal_iso_unit(date, 0'D, N, Y-Mo-W-_-H-Mi-S, Y-Mo-W-N-H-Mi-S).
le_temporal_iso_unit(time, 0'H, N, Y-Mo-W-D-_-Mi-S, Y-Mo-W-D-N-Mi-S).
le_temporal_iso_unit(time, 0'M, N, Y-Mo-W-D-H-_-S, Y-Mo-W-D-H-N-S).
le_temporal_iso_unit(time, 0'S, N, Y-Mo-W-D-H-Mi-_, Y-Mo-W-D-H-Mi-N).

%   The date K times a length of time after a date (K negative: before).
%   Years and months first, as calendar months, then the days.
le_temporal_add_period(Date, Text, K, Later) :-
    le_temporal_iso(Text, period(Y, Mo, D, Secs)),
    Months is K * (Y * 12 + Mo),
    le_temporal_add_months(Date, Months, D1),
    Days is K * (D + ceiling(Secs / 86400)),
    le_temporal_add_days(D1, Days, Later).

le_temporal_has_time_of_day(Text) :-
    le_temporal_iso(Text, period(_, _, _, Secs)), Secs > 0.

%   The dates of a rhythm (once every length of time, from a date) that fall
%   in a period, both ends included: the first one length after the start.
%   At most Max of them from the start (0: no limit).
le_temporal_rhythm_date(Text, Start, Max, From, To, Date) :-
    le_temporal_iso(Text, period(Y, Mo, D, Secs)),
    Step is Y * 12 + Mo + D + Secs, Step > 0,
    le_temporal_rhythm_k(Text, Start, Max, From, To, 1, Date).

le_temporal_rhythm_k(Text, Start, Max, From, To, K, Date) :-
    ( Max =:= 0 -> true ; K =< Max ),
    le_temporal_add_period(Start, Text, K, D0),
    le_temporal_day_number(D0, N0), le_temporal_day_number(To, TN),
    N0 =< TN,
    (   le_temporal_in_period(D0, From, To), Date = D0
    ;   K1 is K + 1, le_temporal_rhythm_k(Text, Start, Max, From, To, K1, Date)
    ).

%   ---- a date without its year: "30 September", "September 30" ----------

le_temporal_month_name(january, 1).  le_temporal_month_name(february, 2).
le_temporal_month_name(march, 3).    le_temporal_month_name(april, 4).
le_temporal_month_name(may, 5).      le_temporal_month_name(june, 6).
le_temporal_month_name(july, 7).     le_temporal_month_name(august, 8).
le_temporal_month_name(september, 9). le_temporal_month_name(october, 10).
le_temporal_month_name(november, 11). le_temporal_month_name(december, 12).

le_temporal_day_of_year(Text, Year, date(Year, M, D)) :-
    ( string(Text) -> string_lower(Text, L) ; atom(Text) -> atom_string(Text, S), string_lower(S, L) ),
    split_string(L, " ,", " ,", Ws0),
    exclude(==(""), Ws0, Ws1),
    exclude([W]>>memberchk(W, ["of", "the", "on"]), Ws1, Ws),
    ( Ws = [DS, MS] ; Ws = [MS, DS] ),
    atom_string(MA, MS), le_temporal_month_name(MA, M),
    le_temporal_day_text(DS, D),
    le_temporal_days_in_month(Year, M, Last), D >= 1, D =< Last.

le_temporal_day_text(S, D) :-
    string_codes(S, Cs), include([C]>>code_type(C, digit), Cs, Ds), Ds \== [],
    number_codes(D, Ds).

%   The templates of temporal.le.
the_age_on_of_someone_born_on_is(Date, Birth, N) :- le_temporal_years_between(Birth, Date, N).
the_number_of_whole_years_from_to_is(D1, D2, N) :- le_temporal_years_between(D1, D2, N).
the_number_of_whole_months_from_to_is(D1, D2, N) :- le_temporal_months_between(D1, D2, N).
the_number_of_days_from_to_is(D1, D2, N) :- le_temporal_days_between(D1, D2, N).
is_years_after(Later, N, Date) :- le_temporal_add_years(Date, N, Later).
is_calendar_months_after(Later, N, Date) :- le_temporal_add_months(Date, N, Later).
is_calendar_months_before(Earlier, N, Date) :- le_temporal_sub_months(Date, N, Earlier).
is_in_the_period_from_to(Date, Start, End) :- le_temporal_in_period(Date, Start, End).
is_within_the_last_months_before(Date, N, Ref) :- le_temporal_within_months_before(Date, N, Ref).
is_within_the_last_days_before(Date, N, Ref) :- le_temporal_within_days_before(Date, N, Ref).
the_first_day_of_the_month_of_is(Date, First) :- le_temporal_month_start(Date, First).
the_last_day_of_the_month_of_is(Date, Last) :- le_temporal_month_end(Date, Last).
the_year_of_is(Date, Y) :- le_temporal_year(Date, Y).
the_month_of_is(Date, M) :- le_temporal_month(Date, M).
the_weekday_of_is(Date, W) :- le_temporal_weekday(Date, W).
is_in_a_leap_year(Date) :- le_temporal_year(Date, Y), le_temporal_leap(Y).
the_lock_time_is_a_block_height(T) :- le_temporal_lock_is_height(T).
the_lock_time_is_a_time(T) :- le_temporal_lock_is_time(T).
is_the_period_after(Later, Text, Date) :- le_temporal_add_period(Date, Text, 1, Later).
is_the_period_before(Earlier, Text, Date) :- le_temporal_add_period(Date, Text, -1, Earlier).
is_a_length_of_time_in_the_standard_form(Text) :- le_temporal_iso(Text, _).
counts_hours_as_whole_days(Text) :- le_temporal_has_time_of_day(Text).
the_occurrence_of_every_after_is(K, Text, Date, Later) :- integer(K), K >= 1, le_temporal_add_period(Date, Text, K, Later).
is_a_date_of_every_from_in_the_period_from_to(Date, Text, Start, From, To) :- le_temporal_rhythm_date(Text, Start, 0, From, To, Date).
the_day_in_the_year_is(Text, Year, Date) :- le_temporal_day_of_year(Text, Year, Date).

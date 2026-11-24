/** <module> Three encodings of SNAP: the Massachusetts sheet against the statute's twin

    the design notes Excel.md §5 and §7.7 (phase 2). The Massachusetts SNAP
    calculator (MLRI, October 2026) is compared with the RuleSpec twin of
    7 USC 2017(a) (LE2 examples/migration/rulespec/snap): for each household
    below, the sheet engine computes the sheet's deductions, net income and
    allotment; the deductions are given to the statute's twin, and the two
    allotments are compared. What differs is either a Massachusetts option
    or a difference of year (the twin's tables), and the report says which.

    swipl -g "consult('crosscheck/snap_crosscheck'), main, halt."
    -> crosscheck/snap_crosscheck.md
*/

:- use_module('../xlsx_ir').
:- use_module('../../le2_paths').
:- use_module(le2(le_kbs)).
:- use_module(library(readutil)).

%   household(Id, Size, Elderly, MonthlyEarned, MonthlyUnearned, Rent, Heat, Homeless)
household(h1, 1, n, 1200, 0,    700, y, n).
household(h2, 1, y, 0,    943,  550, y, n).
household(h3, 2, n, 1800, 0,    900, n, n).
household(h4, 3, n, 2400, 0,   1300, y, n).
household(h5, 3, n, 0,    600,    0, n, y).
household(h6, 4, n, 3100, 200, 1500, y, n).
household(h7, 5, n, 2000, 500, 1100, n, n).
household(h8, 6, y, 2600, 900, 1700, y, n).
household(h9, 2, y, 0,    1400, 400, n, n).
household(h10, 4, n, 4600, 0,  1900, y, n).

sheet('ma_snap_2026_10.xlsx').
calc('SNAP calculation').

inputs(household(_, Size, Eld, Earned, Unearned, Rent, Heat, Homeless), _{
    'SNAP calculation!B14': Eld, 'SNAP calculation!B18': Earned, 'SNAP calculation!B22': Unearned,
    'SNAP calculation!B29': Size, 'SNAP calculation!B63': Homeless, 'SNAP calculation!B67': Rent,
    'SNAP calculation!B72': Heat, 'SNAP calculation!B73': y, 'SNAP calculation!B74': y}).

%   The sheet's cells read for the comparison.
cell(earned, 'B20'). cell(unearned, 'B24'). cell(standard, 'B40'). cell(medical, 'B46').
cell(dependent_care, 'B54'). cell(child_support, 'B58'). cell(shelter, 'B83').
cell(homeless, 'B86'). cell(gross_test, 'B35'). cell(net_test, 'B101'). cell(net_income, 'B98').
cell(max_allotment, 'B109'). cell(allotment, 'B112').

main :-
    module_property(xlsx_ir, file(F)), file_directory_name(F, Dir),
    sheet(S), atomic_list_concat([Dir, '/.cache/files/', S], Sheet),
    findall(H, ( household(Id, A, B, C, D, E, G, I), H = household(Id, A, B, C, D, E, G, I) ), Hs),
    findall(_{id: Id, inputs: In}, ( member(H, Hs), arg(1, H, Id), inputs(H, In0), quote_inputs(In0, In) ), Cases),
    findall(R, ( cell(_, A1), atom_concat('\'SNAP calculation\'!', A1, R) ), Outs),
    run_front(eval, Sheet, _{outputs: Outs, cases: Cases}, Res),
    le2_dir(LE2), atomic_list_concat([LE2, '/examples/migration/rulespec/snap/us_statutes_7_2017_a.le'], Twin),
    read_file_to_string(Twin, TwinText, []),
    findall(row(H, V, Fed), ( member(H, Hs), arg(1, H, Id), member(R0, Res), atom_string(Id, R0.id),
                              sheet_values(R0.values, V), federal(TwinText, H, V, Fed) ), Rows),
    atomic_list_concat([Dir, '/crosscheck/snap_crosscheck.md'], Out),
    setup_call_cleanup(open(Out, write, O), report(O, Rows), close(O)),
    format("~w~n", [Out]).

quote_inputs(D0, D) :-
    dict_pairs(D0, _, Ps0),
    findall(K-V, ( member(K0-V0, Ps0), atomic_list_concat([Sh, C], '!', K0), format(atom(K), '\'~w\'!~w', [Sh, C]),
                   ( atom(V0) -> atom_string(V0, V) ; V = V0 ) ), Ps),
    dict_pairs(D, _, Ps).

sheet_values(VD, V) :-
    findall(Name-X, ( cell(Name, A1), atom_concat('\'SNAP calculation\'!', A1, R), atom_string(R, RS),
                      dict_pairs(VD, _, Ps), member(K-X, Ps), atom_string(K, RS) ), V).

num(V, Name, X) :- ( memberchk(Name-X0, V), number(X0) -> X = X0 ; X = 0 ).

%   The statute's twin, given the sheet's deductions: its regular month allotment.
federal(TwinText, household(_, Size, _, _, _, _, _, Homeless), V, Fed) :-
    num(V, earned, E), num(V, unearned, U), num(V, standard, Std), num(V, medical, Med),
    num(V, dependent_care, DC), num(V, child_support, CS),
    ( Homeless == y -> num(V, homeless, Sh) ; num(V, shelter, Sh) ),
    Income is E + U,
    (   memberchk(gross_test-"PASSED", V), memberchk(net_test-"PASSED", V) -> Elig = "    household_1 is snap eligible.\n" ; Elig = "" ),
    format(string(Sc), "~nscenario xcheck is:~n    household_1 is a household.~n    the calculation date is 2026-10-01.~n    the household size of household_1 is ~w.~n    the snap countable earned income of household_1 is ~w.~n    the work supplementation earned income of household_1 is 0.~n    the child support deduction of household_1 is ~w.~n    the dependent care deduction of household_1 is ~w.~n    the medical deduction of household_1 is ~w.~n    the snap excess shelter deduction of household_1 is ~w.~n    the snap monthly household income of household_1 is ~w.~n    the snap standard deduction of household_1 is ~w.~n~w",
           [Size, E, CS, DC, Med, Sh, Income, Std, Elig]),
    string_concat(TwinText, Sc, Text),
    load_text(Text, KB), createSession(KB, SM), setScenarion(SM, xcheck),
    findall(A, reasoner:i(the_snap_regular_month_allotment_of_is(household_1, A), SM, _, _), As0),
    findall(M, reasoner:i(the_snap_maximum_allotment_of_is(household_1, M), SM, _, _), Ms0),
    destroySession(SM),
    sort(As0, As), sort(Ms0, Ms),
    ( As = [Fed0|_] -> true ; Fed0 = none ), ( Ms = [Max|_] -> true ; Max = none ),
    Fed = fed(Fed0, Max).

report(O, Rows) :-
    format(O, "# The Massachusetts SNAP sheet against the twin of 7 USC 2017(a)~n~n", []),
    format(O, "*Generated by crosscheck/snap_crosscheck.pl. For each household the sheet engine computes the Massachusetts sheet (MLRI, October 2026); its deductions are given to the RuleSpec twin of 7 USC 2017(a) (LE2 examples/migration/rulespec/snap) with the calculation date 1 October 2026, and the allotments are compared.*~n~n", []),
    format(O, "| Household | Size | Earned + unearned | Net income (sheet) | Maximum allotment: sheet / twin | Allotment: sheet / twin | Difference explained by |~n|---|---|---|---|---|---|---|~n", []),
    forall(member(row(H, V, fed(Fed, FMax)), Rows),
           ( H = household(Id, Size, _, E, U, _, _, _),
             ( memberchk(net_income-NI0, V), number(NI0) -> format(atom(NI), "~2f", [NI0]) ; NI = '—' ),
             ( memberchk(max_allotment-SM0, V) -> true ; SM0 = '—' ),
             ( memberchk(allotment-SA1, V), number(SA1) -> SA0 is round(SA1 * 100) / 100 ; SA0 = "—" ),
             H = household(_, _, _, _, _, _, _, Hl), explain(Hl, SA0, SM0, Fed, FMax, Why),
             format(O, "| ~w | ~w | ~w + ~w | ~w | ~w / ~w | ~w / ~w | ~w |~n", [Id, Size, E, U, NI, SM0, FMax, SA0, Fed, Why]) )),
    format(O, "~nThe twin's maximum-allotment tables run to fiscal year 2026 (from 1 October 2025): the corpus it was built from (rulespec-us at the commit corpus.pl pins) has not yet published the fiscal year 2027 adjustment the sheet uses (one person: $306 against $298). Where only that table differs, the allotments differ by the same amount.~n~nThe rounding is a finding about the sheet: the federal rules round 30% of net income up to the next dollar and the allotment down (7 CFR 273.10(e)(2)(ii)), and the RuleSpec twin, read from the statute and its tests, does; the Massachusetts calculator keeps the cents, so its estimate can exceed the benefit by up to one dollar. The homeless case shows the sheet relying on its user: it computes a shelter deduction whenever utilities are entered, and its note tells a homeless household to skip that step.~n~nNot compared here: the PolicyEngine twin (lpsPlus examples/migration/policyengine/snap), whose cases describe each person of a household with some sixty facts; see the review report.~n", []).

explain(Homeless, SA, SM, Fed, FMax, Why) :-
    (   number(SA), number(Fed), SA =:= Fed -> Why = "the same"
    ;   number(SA), number(Fed), number(SM), number(FMax), abs((SA - Fed) - (SM - FMax)) < 0.01
    ->  Why = "the year of the maximum-allotment table only"
    ;   number(SA), number(Fed), number(SM), number(FMax), floor(SA + 1.0e-9) =:= Fed + SM - FMax
    ->  Why = "the year of the table, and rounding: the sheet keeps cents where the statute's twin rounds 30% of net income up and the allotment down to whole dollars (7 CFR 273.10(e)(2)(ii))"
    ;   Homeless == y, number(SA), number(Fed), SA > Fed
    ->  Why = "a homeless household: the sheet also gives it the shelter deduction with a utility allowance when utilities are entered; its own note tells the user to skip that step"
    ;   number(SA), SA =:= 0, Fed == none -> Why = "both: not eligible"
    ;   Why = "to examine"
    ).

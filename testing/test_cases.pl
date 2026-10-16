/** <module> Case searches: every case in which a goal holds, and properties

    docs/user/reference/language.md §17.11; le_cases.pl.

    Run with:  swipl -q -g run_tests -t halt testing/test_cases.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_cases, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module('../le_kbs').

%   The cases of a query, each as cs(Words, CoveredBy, ScenarioText).
cases_of(KB, Query, Cases) :-
    createSession(KB, SM),
    KB:query_info(Query, le_cases(Goal, Mode, _), _),
    le_cases:cases(Goal, Mode, SM, KB, Cs),
    destroySession(SM),
    findall(cs(Text, Covered, Scenario),
            ( member(C-_, Cs),
              le_cases:case_words(KB, C, Ws), atomic_list_concat(Ws, ' ', Text),
              le_cases:case_json(KB, C, J),
              ( get_dict(coveredBy, J, Covered) -> true ; Covered = none ),
              ( get_dict(scenario, J, Scenario) -> true ; Scenario = none ) ),
            Cases).

answers(KB, Scenario, Query, Answers) :-
    createSession(KB, SM),
    setScenarion(SM, Scenario),
    findall(A, ( query(SM, Query, I, _, _), canonical_string(I, A) ), Answers0),
    destroySession(SM),
    msort(Answers0, Answers).

:- begin_tests(cases).

% Six ways to British citizenship by birth; the program's scenarios cover
% three of them (`harry` states the father as a fact, which no rule reads as
% a scenario element, so it covers none).
test(citizenship_cases, [nondet]) :-
    load_text("the target language is: prolog.

the templates are:
*a person* acquires British citizenship on *a date*.
*a person* is born in *a place* on *a date*,
*a date* is after commencement,
*a person* is the mother of *a person*,
*a person* is the father of *a person*,
*a person* is a British citizen on *a date*,
*a person* is settled in the UK on *a date*,
*a person* says that *a sentence*,
*a person* is qualified to determine fatherhood.

the knowledge base citizenship cases includes:

a person acquires British citizenship on a date
if the person is born in the UK on the date
	and the date is after commencement
	and an other person is the mother of the person
    	or the other person is the father of the person
	and the other person is a British citizen on the date
    	or the other person is settled in the UK on the date.

a person is the father of an other person
if a third person says
    that the person is the father of the other person
    and the third person is qualified to determine fatherhood.

a person X is the father of a person Y
    if X says that X is the father of Y.

scenario alice is:
    John is born in the UK on 2021-10-09.
	2021-10-09 is after commencement.
	Alice is the mother of John.
	Alice is a British citizen on 2021-10-09.

scenario trust_harry is:
	John is born in the UK on 2021-10-09.
	2021-10-09 is after commencement.
	Harry says that Harry is the father of John.
	Harry is settled in the UK on 2021-10-09.

query paths is:
    which cases make it the case that
        a person acquires British citizenship on a date.
", KB),
    cases_of(KB, paths, Cases),
    length(Cases, 6),
    Cases = [cs(T1, C1, S1)|_],
    sub_atom(T1, 0, _, _, 'case 1 of 6: a person is born in the UK on a date and the date is after commencement and an other person is the mother of the person'),
    C1 == [alice],
    sub_string(S1, _, _, _, "person_2 is the mother of person_1."),
    findall(C, member(cs(_, C, _), Cases), Covers),
    msort(Covers, Sorted),
    Sorted == [[], [], [], [], [alice], [trust_harry]].

test(numbers_and_negation, [nondet]) :-
    load('examples/regulatory/case_search.le', KB),
    cases_of(KB, 'support cases', [cs(T, Covered, _)]),
    Covered == [ana],
    sub_atom(T, _, _, _, 'the amount is less than or equal to 15000'),
    sub_atom(T, _, _, _, 'it is not the case that the person receives other benefits'),
    sub_atom(T, _, _, _, 'it is not the case that the person is excluded from rent support').

% A property the rules break: the case is found, with an income in the gap
% between the exclusion and the income limit.
test(broken_property, [nondet]) :-
    load('examples/regulatory/case_search.le', KB),
    cases_of(KB, 'both eligible and excluded', Cases),
    length(Cases, 2),
    member(cs(T, [], S), Cases),
    sub_atom(T, _, _, _, 'the amount is greater than 15000 and the amount is less than 20000'),
    sub_string(S, _, _, _, "person_1 has an income of 17500.").

test(property_that_holds) :-
    load('examples/regulatory/case_search.le', KB),
    cases_of(KB, 'support for a student', [cs(T, none, none)]),
    T == 'there is no such case: the search covered every case'.

% The ready-made scenario of a case meets it: added to the program, the
% goal holds in it.
test(scenario_meets_its_case, [nondet]) :-
    load('examples/regulatory/case_search.le', KB),
    cases_of(KB, 'both eligible and excluded', Cases),
    member(cs(_, [], Scenario), Cases),
    read_file_to_string('examples/regulatory/case_search.le', Src, []),
    format(string(Src1), "~w~n~w~n~nquery check is:~n    which person is eligible for rent support~n    and the person is excluded from rent support.~n", [Src, Scenario]),
    load_text(Src1, KB1),
    answers(KB1, case_2, check, As),
    As \== [].

test(answers_render_the_case) :-
    load('examples/regulatory/case_search.le', KB),
    answers(KB, ana, 'support for a student', As),
    As == ["there is no such case: the search covered every case"].

:- end_tests(cases).

/** <module> LE for LPS: `initially` in a scenario, and several fluents on a line

    Two fixes of 27 November 2026, found in a first program of a new user
    (lps2's docs/user/reference/le-for-lps.md §3.2 and §3.9):

    - An `initially` sentence written in a scenario is part of the initial
      state of the run of that scenario. It was read and then dropped without
      a message, so the run started with no fluents.
    - `initially bob is hungry and bob is sleepy.` on one line, or the same
      with a comma, is two fluents. It was one fluent, `is sleepy` of
      `hungry and bob`.

    Run with:  swipl -q -g run_tests -t halt testing/test_lps_initially.pl
*/

:- module(test_lps_initially, []).

:- use_module(library(plunit)).
:- use_module('../le_lps').

lines(Doc, Lines, Issues) :-
    le_lps_text(Doc, Text, _, Issues),
    split_string(Text, "\n", "", Lines).

doc(Tail, Doc) :-
    string_concat("the target language is: lps.

the maximum time is 5.

the fluents are:
    *a person* is sleepy.
    *a person* is hungry.
    the owners are *some names*.

the knowledge base people includes:

", Tail, Doc).

:- begin_tests(lps_initially).

test(in_a_scenario_with_a_comma) :-
    doc("scenario one is:
    initially bob is hungry, bob is sleepy.
", Doc),
    lines(Doc, Lines, Issues),
    assertion(\+ memberchk(le_lps_issue(error, _, _, _, _), Issues)),
    assertion(member("initial_state([is_hungry(bob),is_sleepy(bob)]).", Lines)).

test(only_the_scenario_of_the_run) :-
    doc("scenario one is:
    initially bob is hungry.

scenario two is:
    initially ann is sleepy.
", Doc),
    le_lps_with_scenario(two, lines(Doc, Lines, _)),
    assertion(member("initial_state([is_sleepy(ann)]).", Lines)),
    assertion(\+ member("initial_state([is_hungry(bob)]).", Lines)).

test(the_knowledge_base_and_the_scenario_together) :-
    doc("initially ann is hungry.

scenario one is:
    initially bob is sleepy.
", Doc),
    lines(Doc, Lines, _),
    assertion(member("initial_state([is_hungry(ann)]).", Lines)),
    assertion(member("initial_state([is_sleepy(bob)]).", Lines)).

test(and_on_one_line) :-
    doc("initially bob is hungry and bob is sleepy.
", Doc),
    lines(Doc, Lines, _),
    assertion(member("initial_state([is_hungry(bob),is_sleepy(bob)]).", Lines)).

test(and_on_two_lines_as_before) :-
    doc("initially bob is hungry
    and bob is sleepy.
", Doc),
    lines(Doc, Lines, _),
    assertion(member("initial_state([is_hungry(bob),is_sleepy(bob)]).", Lines)).

%   `alice and bob` is one value: `bob` alone is no sentence of a fluent, so
%   the line is not cut.
test(and_inside_a_value_stays) :-
    doc("initially the owners are alice and bob.
", Doc),
    lines(Doc, Lines, _),
    assertion(member("initial_state([the_owners_are('alice and bob')]).", Lines)).

:- end_tests(lps_initially).

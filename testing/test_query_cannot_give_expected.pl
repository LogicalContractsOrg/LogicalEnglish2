/** <module> Unit tests for the verifier check query_cannot_give_expected.

    A query that can never give its expected answers: a constant where a
    `which` variable was meant ("the proposal may proceed"), or a query that
    matches a more general template than its answers do. Both used to show
    only "Expected [...], Actual []".

    Run with:  swipl -q -g run_tests -t halt testing/test_query_cannot_give_expected.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_query_cannot_give_expected, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

qcge_program(Query, Expected, Doc) :-
    format(string(Doc),
"the target language is: prolog.

the templates are:
    *a proposal* may proceed.
    *a check* has result *a result* for *a proposal*.
    *a provider* has *a licence* for *an activity*.
    *a proposal* is complete.

the knowledge base qcge includes:

a proposal may proceed
    if the proposal is complete.

a check has result passes for a proposal
    if the proposal is complete.

scenario one is:
    proposal 1 is complete.
    q expects answers [\"~w\"].

query q is:
    ~w.
", [Expected, Query]).

qcge_issues(Query, Expected, Types) :-
    qcge_program(Query, Expected, Doc),
    le_kbs:set_le_issue_reporting(false),
    call_cleanup(le_kbs:load_text(Doc, KB), le_kbs:set_le_issue_reporting(true)),
    findall(T, KB:le_issue(_, T, _, _, _, _), Types).

:- begin_tests(query_cannot_give_expected).

test(constant_where_which_was_meant) :-
    qcge_issues("the proposal may proceed", "proposal 1 may proceed", Types),
    assertion(memberchk(query_cannot_give_expected, Types)).

test(query_matches_a_more_general_template) :-
    qcge_issues("which check has which result for which proposal",
                "uk exemption has result passes for proposal 1", Types),
    assertion(memberchk(query_cannot_give_expected, Types)).

test(a_query_that_can_answer_is_not_reported) :-
    qcge_issues("which check has result which result for which proposal",
                "uk exemption has result passes for proposal 1", Types),
    assertion(\+ memberchk(query_cannot_give_expected, Types)).

test(which_query_is_not_reported) :-
    qcge_issues("which proposal may proceed", "proposal 1 may proceed", Types),
    assertion(\+ memberchk(query_cannot_give_expected, Types)).

% A conjunctive query: its expected answer is the instance of the whole
% query, not of one literal (examples/moreExamples/collections/
% logical-thinking-talk/heart_failure.le was reported, and the editor then
% refused to run its queries).
test(a_conjunctive_query_is_not_reported) :-
    qcge_issues("which proposal may proceed and it is not the case that the proposal is complete",
                "proposal 1 may proceed and it is not the case that proposal 1 is complete", Types),
    assertion(\+ memberchk(query_cannot_give_expected, Types)).

:- end_tests(query_cannot_give_expected).

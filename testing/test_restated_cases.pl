/* test_restated_cases.pl — three things a Contract Assistant run of 4
   November 2026 showed (examples/private/CaseStudy_Oct30_c in lpsPlus):

   - restated_cases_rule: a rule whose conditions are its own conclusion with
     a name in place of a variable (`... under a paragraph if ... under
     paragraph a or ... under paragraph b ...`) calls itself, and a test of
     23 paragraphs never ended;
   - negation_only_variable: a thing of the conclusion that only a negation
     names, so the answer is `_ has the ... check with result more
     information needed`;
   - an expected answer that leaves out an article the answer has ("has uk
     exemption check" for "has the uk exemption check") passes, as the query
     with the same words found the template.
*/

:- use_module(library(plunit)).
:- use_module('../le_kbs').

restated_program("the target language is: prolog.

the templates are:
    *a provider* qualifies under *a paragraph*.
    *a provider* is a dealer; undefined.
    *a provider* is a trustee; undefined.
    *a proposal* passes the *a check* check.
    *a proposal* has the *a check* check with result *a result*.
    *a proposal* occurs on *a date*; undefined.

the knowledge base restated includes:

a provider qualifies under paragraph a
    if the provider is a dealer.

a provider qualifies under paragraph b
    if the provider is a trustee.

a provider qualifies under a paragraph
    if the provider qualifies under paragraph a
    or the provider qualifies under paragraph b.

a proposal passes the uk exemption check
    if the proposal occurs on 2026-11-15.

a proposal has the uk exemption check with result passes
    if the proposal passes the uk exemption check.

a proposal has the uk exemption check with result more information needed
    if it is not the case that
        the proposal passes the uk exemption check.

scenario one is:
    proposal one occurs on 2026-11-15.
    bob is a dealer.

query result is:
    which proposal has uk exemption check with result which result.

query qualifies is:
    which provider qualifies under paragraph a.
").

issue_types(Text, Types) :-
    le_kbs:load_text(Text, KB),
    findall(T, ( le_verifier:check_issue(KB, [skip_tests], issue(T, _, _, _, _)) ), Ts),
    sort(Ts, Types).

:- begin_tests(restated_cases).

test(restated_cases_rule_warned) :-
    restated_program(P),
    issue_types(P, Types),
    assertion(memberchk(restated_cases_rule, Types)).

test(negation_only_variable_warned) :-
    restated_program(P),
    issue_types(P, Types),
    assertion(memberchk(negation_only_variable, Types)).

test(the_rules_for_each_case_are_not_warned) :-
    %  without the general rule, no rule restates its cases
    restated_program(P0),
    once(sub_string(P0, B, _, _, "a provider qualifies under a paragraph\n")),
    once(sub_string(P0, E, _, _, "a proposal passes the uk")),
    sub_string(P0, 0, B, _, Before), sub_string(P0, E, _, 0, After),
    string_concat(Before, After, P),
    issue_types(P, Types),
    assertion(\+ memberchk(restated_cases_rule, Types)).

test(recursion_over_other_things_is_not_warned) :-
    issue_types("the target language is: prolog.

the templates are:
    *a person* is an ancestor of *a person*.
    *a person* is a parent of *a person*; undefined.

the knowledge base anc includes:

a person is an ancestor of a second person
    if the person is a parent of the second person.

a person is an ancestor of a second person
    if the person is a parent of a third person
    and the third person is an ancestor of the second person.
", Types),
    assertion(\+ memberchk(restated_cases_rule, Types)),
    assertion(\+ memberchk(negation_only_variable, Types)).

test(an_article_left_out_still_matches) :-
    assertion(le_kbs:answers_match(["proposal one has #article uk exemption check with result fails"],
                                   ["proposal one has #article uk exemption check with result fails"])),
    le_kbs:normalize_string("proposal one has uk exemption check with result fails", E),
    le_kbs:normalize_string("proposal one has the uk exemption check with result fails", A),
    assertion(le_kbs:answers_match([E], [A])),
    le_kbs:normalize_string("proposal one has the uk exemption check with result passes", A2),
    assertion(\+ le_kbs:answers_match([E], [A2])).

:- end_tests(restated_cases).

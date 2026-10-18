/** <module> LE for LPS: `it is not the case that` over several conditions

    A negated conjunction that reads the state was written as a Prolog
    `not(…)` around goals that included `holds(F, T)`; LPS2 then called
    `holds/2` as an ordinary predicate, which no program defines, and the run
    stopped with an existence error. It is now `holds(not [G1, …], T)`, LPS's
    own form of a negated conjunction (lps2 src/core/lps_query.pl), and the
    writer back to English (le_lps_write.pl) reads it as the same sentence.

    Run with:  swipl -q -g run_tests -t halt testing/test_lps_negated_conjunction.pl
*/

:- module(test_lps_negated_conjunction, []).

:- use_module(library(plunit)).
:- use_module('../le_lps').
:- use_module('../le_lps_write').

doc("the target language is: lps.

the maximum time is 5.

the events are:
    *a person* arrives; known as arrives.

the actions are:
    *a person* is greeted; known as greeted.

the fluents are:
    *a person* is present; known as present.
    *a person* is the first; known as first.

the templates are:
    *a person* is ranked *a number*.

the knowledge base nc includes:

alice is ranked 1.
bob is ranked 2.

when a person arrives
then the person is present.

a person is the first at a time if
    the person is present at the time
    and the person is ranked a number N
    and it is not the case that
        an other person is ranked a number M
        and M < N
        and the other person is present at the time.

if a person is the first
then the person is greeted.

scenario one is:
    bob arrives from 1 to 2.
    alice arrives from 2 to 3.
").

:- begin_tests(lps_negated_conjunction).

test(negated_conjunction_is_lps_form) :-
    doc(Doc),
    le_lps_text(Doc, Text, _, _),
    split_string(Text, "\n", "", Lines),
    assertion(member("l_int(holds(first(A),B),[holds(present(A),B),is_ranked(A,C),holds(not([is_ranked(D,E),E<C,holds(present(D),B)]),B)]).", Lines)).

test(a_single_negated_fluent_is_unchanged) :-
    doc(Doc0),
    atomic_list_concat(Parts, "and it is not the case that\n        an other person is ranked a number M\n        and M < N\n        and the other person is present at the time.", Doc0),
    atomic_list_concat(Parts, "and it is not the case that the person is present at the time.", Doc),
    le_lps_text(Doc, Text, _, _),
    assertion(sub_string(Text, _, _, _, "holds(not(present(A)),B)")).

test(written_back_as_the_same_sentence) :-
    Terms = [ fluents([first(_), present(_)]),
              l_int(holds(first(A), B), [holds(present(A), B), is_ranked(A, C),
                    holds(not([is_ranked(D, E), E < C, holds(present(D), B)]), B)]) ],
    le_lps_write:le_lps_from_internal(Terms, [], Text, _),
    assertion(sub_string(Text, _, _, _, "it is not the case that\n        ")),
    assertion(\+ sub_string(Text, _, _, _, "[is_ranked")),
    assertion(\+ sub_string(Text, _, _, _, "*a list*")).

:- end_tests(lps_negated_conjunction).

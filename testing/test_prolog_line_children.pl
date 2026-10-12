/** <module> A `prolog` line with lines nested under it

    The writer (le_writer) anchors an `otherwise` cascade that follows other
    conditions under the condition before it, and that condition may be an
    embedded Prolog goal (language.md §15.6). The grammar read a `prolog`
    line only when nothing was nested under it, so such a rule lost its
    cascade (a missing-template error). The spreadsheet importer's twins
    compare a number with a text that way (Excel puts every number before
    every text).

    Run with:  swipl -q -g run_tests -t halt testing/test_prolog_line_children.pl
*/

:- module(test_prolog_line_children, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

text("the target language is: prolog.

the templates are:
    the amount is *a number*; undefined.
    the limit is *a value*.
    the result is *a text*.

the knowledge base k includes:

the limit is a value if
    the value is equal to \"No limit\".

the result is a text if
    the amount is a number
    and the limit is a value
    and prolog (compare(<, the number, the value))
        and the text is equal to \"PASSED\"
        otherwise the text is equal to \"FAILED\".

scenario s is:
    the amount is 3.5.
").

:- begin_tests(prolog_line_children).

test(cascade_under_a_prolog_line) :-
    text(T),
    load_text(T, KB),
    createSession(KB, SM),
    setScenarion(SM, s),
    findall(X, reasoner:i(the_result_is(X), SM, _, _), Xs),
    destroySession(SM),
    assertion(Xs == ["PASSED"]).

:- end_tests(prolog_line_children).

/* test_homonym_templates.pl — two templates that differ only in the names
   of their argument places are one predicate, and the verifier says so
   (LawAndOrder.md §5.6); a name that is the head noun of the other (a kind
   of it) is not reported. Also: an expected answer that writes a line label
   `1z` matches the answer the tokenizer reads as `1 z`; and the numeric
   hints of le_issue_feedback for a failed amount (§5.5). */

:- use_module(library(plunit)).
:- use_module('../le_kbs').

homonym_program("the target language is: prolog.

the templates are:
    *an interest form* shows federal income tax withheld of *an amount*; undefined.
    *a dividend form* shows federal income tax withheld of *an amount*; undefined.
    *a funding record* has an effective date of *a date*; undefined.
    *a record* has an effective date of *a date*; undefined.
    *a return* has dividend withholding of *an amount*.

the knowledge base k includes:

a return has dividend withholding of an amount T
    if T is the sum of each W such that
        a dividend form shows federal income tax withheld of W.

scenario s is:
    i1 shows federal income tax withheld of 10.
    d1 shows federal income tax withheld of 5.
    r1 has an effective date of 2024-01-01.

query q is:
    which return has dividend withholding of which amount.
").

line_label_program("the target language is: prolog.

the templates are:
    *a return* has wages of *an amount*; undefined.
    the amount on line 1z of Form 1040 for *a return* is *an amount*.

the knowledge base k includes:

the amount on line 1z of Form 1040 for a return is an amount A
    if the return has wages of A.

scenario s is:
    r1 has wages of 150.
    q expects answers [\"the amount on line 1z of Form 1040 for r1 is 150\"].

query q is:
    the amount on line 1z of Form 1040 for which return is which amount.
").

:- begin_tests(homonym_templates).

test(sibling_names_reported_once) :-
    homonym_program(T),
    le_kbs:load_text(T, KB),
    findall(D, KB:le_issue(warning, homonym_templates, D, _, _, _), Ds),
    assertion(Ds = [_]),
    Ds = [D],
    assertion(sub_string(D, _, _, _, "dividend form")),
    assertion(sub_string(D, _, _, _, "interest form")).

%   The shape of the Form 1040 program: the form's variable is linked to a
%   second condition, but that one has the same words as another template
%   too, so only the names tell the kinds of form apart.
linked_program("the target language is: prolog.

the templates are:
    *an interest form* belongs to *a return*; undefined.
    *a dividend form* belongs to *a return*; undefined.
    *an interest form* shows tax withheld of *an amount*; undefined.
    *a dividend form* shows tax withheld of *an amount*; undefined.
    *a person* has a name of *a text*; undefined.
    *a company* has a name of *a text*; undefined.
    *a company* is registered; undefined.
    *a return* has dividend withholding of *an amount*.
    *a company* is listed under *a text*.

the knowledge base k includes:

a return has dividend withholding of an amount T
    if T is the sum of each X such that
        a dividend form belongs to the return
        and the dividend form shows tax withheld of X.

a company is listed under a text
    if the company is registered
    and the company has a name of the text.

scenario s is:
    i1 belongs to r1.
    i1 shows tax withheld of 10.
    c1 is registered.
    c1 has a name of acme.

query q is:
    which return has dividend withholding of which amount.

query l is:
    which company is listed under which text.
").

test(linked_condition_of_the_same_kind) :-
    linked_program(T),
    le_kbs:load_text(T, KB),
    findall(D, KB:le_issue(warning, homonym_templates, D, _, _, _), Ds),
    % both pairs of the forms; not the names, which `is registered` fixes
    assertion(length(Ds, 2)),
    assertion(\+ ( member(D, Ds), sub_string(D, _, _, _, "name of") )).

test(line_label_with_letter_matches) :-
    line_label_program(T),
    le_kbs:load_text(T, KB),
    findall(R, ( KB:le_expected(Q, S, A, U), le_kbs:run_one_test(KB, test(Q, S, A, U), R) ), Rs),
    assertion(Rs == [pass(q, s)]).

:- end_tests(homonym_templates).

:- use_module('../le_issue_feedback').

:- begin_tests(numeric_hints).

test(classes) :-
    le_issue_feedback:numeric_hints(
        ["line 16 is 13382", "line 25b is 1235", "line 9 is 300", "line 12 is 100", "line 3 is 10.00"],
        ["line 16 is 13383", "line 25b is 2470", "line 9 is 400", "line 12 is 100.4", "line 3 is 10.01"],
        [100], Hs),
    assertion(length(Hs, 5)),
    assertion(( member(H1, Hs), sub_string(H1, _, _, _, "exactly 1") )),
    assertion(( member(H2, Hs), sub_string(H2, _, _, _, "factor of 2") )),
    assertion(( member(H3, Hs), sub_string(H3, _, _, _, "another line") )),
    assertion(( member(H4, Hs), sub_string(H4, _, _, _, "not rounded") )),
    assertion(( member(H5, Hs), sub_string(H5, _, _, _, "off by 0.01") )).

:- end_tests(numeric_hints).

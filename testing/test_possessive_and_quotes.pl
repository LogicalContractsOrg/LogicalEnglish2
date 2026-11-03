/* test_possessive_and_quotes.pl — two possessives after argument places are
   not one quoted string; a possessive template is a warning; a template
   named like Prolog's is/2 is dropped. */

:- use_module(library(plunit)).
:- use_module('../le_kbs').

two_possessives("the target language is: prolog.

the templates are:
    *a provider* has relevant FCA permissions; undefined.
    *a provider*'s licence covers *a class*; undefined.
    *an offer* is covered by *a licensee*'s licence; undefined.
    *a provider* is *a named provider*; undefined.
    *a provider* is ok.

the knowledge base k includes:

a provider is ok
    if the provider has relevant FCA permissions
    and 2026-01-01 is before 2027-01-01.

scenario s is:
    ann has relevant FCA permissions.
    q expects answers [\"ann is ok\"].

query q is:
    which provider is ok.
").

:- begin_tests(possessive_and_quotes).

test(templates_kept_and_warned) :-
    two_possessives(T),
    le_kbs:load_text(T, KB),
    % the template between the two apostrophes is not lost
    assertion(KB:le_dict(dict([has_relevant_FCA_permissions|_], _, _, _, _, _, _))),
    assertion(KB:le_dict(dict([is_ok|_], _, _, _, _, _, _))),
    aggregate_all(count, KB:le_issue(warning, possessive_template, _, _, _, _), NP),
    assertion(NP =:= 2),
    assertion(KB:le_issue(error, builtin_template, _, _, _, _)),
    \+ KB:le_dict(dict([is, _, _], _, _, _, _, _, _)),
    findall(test(Q, S, A, U), KB:le_expected(Q, S, A, U), [Test]),
    le_kbs:run_one_test(KB, Test, R),
    assertion(R = pass(_, _)).

:- end_tests(possessive_and_quotes).

/* test_detached_condition.pl — a condition whose arguments appear nowhere
   else in its rule (and the rule has other conditions) is reported. */

:- use_module(library(plunit)).
:- use_module('../le_kbs').

detached_program("the target language is: prolog.

the templates are:
    *a proposal* has a basis for *a provider*.
    *a proposal* involves *a provider*; undefined.
    *a provider* holds *a licence*; undefined.
    *a licence* is current on *a date*; undefined.
    *a provider* is licensed.

the knowledge base k includes:

a proposal has a basis for a provider
    if the proposal involves the provider
    and the provider holds a licence
    and an Australian financial services licence is current on a date.

a provider is licensed
    if the provider holds a licence
    and the licence is current on a date.

a provider is licensed
    if a licence is current on a date.

scenario s is:
    p1 involves ann.
    ann holds l1.
    l1 is current on 2026-11-15.

query q is:
    which proposal has a basis for which provider.
").

:- begin_tests(detached_condition).

test(reported_once) :-
    detached_program(T),
    le_kbs:load_text(T, KB),
    findall(S, KB:le_issue(warning, detached_condition, _, _, S, _), Ss),
    % the first rule's last condition; not the linked one, not a lone condition
    assertion(length(Ss, 1)),
    once(KB:le_issue(warning, detached_condition, D, _, _, _)),
    assertion(sub_string(D, _, _, _, "is current on")).

:- end_tests(detached_condition).

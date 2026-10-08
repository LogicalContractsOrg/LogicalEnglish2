/* test_builtin_template.pl — a template that would become one of Prolog's
   own predicates (`*the amount of X* is *an amount*` is is/2) is an error,
   since every "... is ..." sentence of the program, the date comparisons
   included, would be read as one of its instances. */

:- use_module(library(plunit)).
:- use_module('../le_kbs').

bt_prog(Template, P) :-
    format(string(P), "the target language is: prolog.

the templates are:
    ~w
    *a loss* occurs on *a date*.
    *a loss* is late.

the knowledge base k includes:

a loss is late
    if the loss occurs on a date D
    and D is after or equal to 2025-06-01.

scenario s is:
    loss one occurs on 2025-07-01.
    q expects answers [\"loss one is late\"].

query q is:
    which loss is late.
", [Template]).

:- begin_tests(builtin_template).

test(is_template_is_an_error) :-
    bt_prog("*the amount of other insurance* is *an amount*; undefined.", P),
    load_text(P, KB),
    assertion(KB:le_issue(error, builtin_template, _, _, _, _)).

test(ordinary_template_is_fine) :-
    bt_prog("the amount of other insurance under *a policy* is *an amount*; undefined.", P),
    load_text(P, KB),
    assertion(\+ KB:le_issue(_, builtin_template, _, _, _, _)).

:- end_tests(builtin_template).

bt_agg_prog(Cond, P) :-
    format(string(P), "the target language is: prolog.

the templates are:
    the benefit for *a component* is *an amount*.
    the capped amount for *a component* is *an amount*.
    *a component* is a component.

the knowledge base k includes:

the capped amount for a component is an amount P
    if ~wP is the max of each V such that
        the benefit for the component is the amount V.

scenario s is:
    component a is a component.
    the benefit for component a is 20.
", [Cond]).

:- begin_tests(unbound_aggregate_variable).

test(warned_when_nothing_names_it) :-
    bt_agg_prog("", P), load_text(P, KB),
    assertion(KB:le_issue(warning, unbound_aggregate_variable, _, _, _, _)).

test(quiet_when_named_first) :-
    bt_agg_prog("the component is a component\n    and ", P), load_text(P, KB),
    assertion(\+ KB:le_issue(_, unbound_aggregate_variable, _, _, _, _)).

:- end_tests(unbound_aggregate_variable).

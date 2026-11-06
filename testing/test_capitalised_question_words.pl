/** <module> A query may begin with a capital question word.

    `Which person is happy.` asks the same as `which person is happy.`. The
    capital `Which` used to be no question word at all, so the query asked
    about a person named "Which person" and had no answer (a user's report,
    November 2026). The same holds for `What`, `Each`, and the question words
    of the other languages (`Cuál`).

    Run with:  swipl -q -g run_tests -t halt testing/test_capitalised_question_words.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_capitalised_question_words, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

program(Query, Text) :-
    format(string(Text),
"the target language is: prolog.

the templates are:
    *a person* is happy.

the knowledge base k includes:

a person is happy if
    the person is a dragon.

query q is:
    ~w.
", [Query]).

spanish_program(Query, Text) :-
    format(string(Text),
"el lenguaje objetivo es: prolog.

las plantillas son:
    *una persona* es feliz.

la base de conocimiento k incluye:

una persona es feliz si
    la persona es un dragón.

consulta q es:
    ~w.
", [Query]).

%   The goal of query q, loaded in core LE (without the extensions).
query_goal(Program, Query, Goal) :-
    call(Program, Query, Text),
    le_entitlements:with_entitlements([],
        ( le_kbs:load_text(Text, KB), KB:query_info(q, Goal0, _) )),
    Goal = Goal0.

:- begin_tests(capitalised_question_words).

test(which_lower) :-
    query_goal(program, "which person is happy", G),
    assertion((G = is_happy(V), var(V))).

test(which_capital) :-
    query_goal(program, "Which person is happy", G),
    assertion((G = is_happy(V), var(V))).

test(what_capital) :-
    query_goal(program, "What person is happy", G),
    assertion((G = is_happy(V), var(V))).

test(each_capital) :-
    query_goal(program, "Each person is happy", G),
    assertion((G = is_happy(V), var(V))).

test(spanish_cual_capital) :-
    query_goal(spanish_program, "Cuál persona es feliz", G),
    assertion((G = es_feliz(V), var(V))).

:- end_tests(capitalised_question_words).

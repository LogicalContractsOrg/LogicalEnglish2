% Facts given to the query tool (MCP, REST, the light assistant) on one line:
% "a is b. c is d." A sentence is read only where a line starts, so these were
% once dropped, all but the first, without a word (le_kbs:facts_one_per_line/2).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_tools').

:- begin_tests(facts_one_line).

test(split_after_full_stop) :-
    le_kbs:facts_one_per_line("a is b. c is d.  e is f.", S),
    S == "a is b.\nc is d.\ne is f.".

test(numbers_dates_and_quotes_kept) :-
    le_kbs:facts_one_per_line("x has 1.5 on 2021-10-09. y says \"go. now\".", S),
    S == "x has 1.5 on 2021-10-09.\ny says \"go. now\".".

test(query_reads_every_fact_on_one_line) :-
    le_tool_query(_{example_name: "citizenship", query: "one",
                    facts: "John is born in the UK on 2021-10-09. 2021-10-09 is after commencement. Alice is the mother of John. Alice is a British citizen on 2021-10-09."}, R),
    R.results = [A|_],
    A.answer == "John acquires British citizenship on 2021-10-09".

:- end_tests(facts_one_line).

:- begin_tests(facts_headings_and_word_dates).

test(heading_line_dropped) :-
    le_kbs:facts_one_per_line("the knowledge base includes:\na is b.\nscenario x is:\nc is d.", S),
    S == "a is b.\nc is d.".

test(word_date_noted) :-
    once(le_tools:word_date_notes("Carl is born on 3 March 1986. Ann is born on the 1st of January 1990.", Notes)),
    length(Notes, 2),
    Notes = [N1, N2],
    once(sub_string(N1, _, _, _, "1986-03-03")),
    once(sub_string(N2, _, _, _, "1990-01-01")).

test(iso_date_not_noted) :-
    le_tools:word_date_notes("Carl is born on 1986-03-03.", []).

test(query_with_word_date_noted) :-
    once(le_tool_query(_{example_name: "citizenship", query: "which person acquires British citizenship on 9 October 2021",
                         scenario_name: "alice"}, R)),
    R.notes = [N|_],
    once(sub_string(N, _, _, _, "2021-10-09")).

:- end_tests(facts_headings_and_word_dates).

:- begin_tests(query_and_value).

test(two_sentences_joined_by_and) :-
    once(le_tool_query(_{example_name: "regulatory/bna", scenario_name: "descent",
                         query: "the question is asked on 1990-01-01 and which person is a british citizen by descent on 1990-01-01"}, R)),
    R.results = [A],
    once(sub_string(A.answer, _, _, _, "carl is a british citizen by descent on 1990-01-01")).

test(one_sentence_unchanged) :-
    once(le_tool_query(_{example_name: "citizenship", query: "which person acquires British citizenship on which date",
                         scenario_name: "alice"}, R)),
    R.results = [A],
    A.answer == "John acquires British citizenship on 2021-10-09".

:- end_tests(query_and_value).

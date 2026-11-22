% Tests for conditional negation (reasoner.pl, solve_real_actual/8 on not/1,
% one_decision/3; le_tables.pl, the first-match policy with an open input):
% `it is not the case that G`, when G holds only by assuming a judgment
% nobody made, holds if that judgment is false, and the answer says so.
% docs/user/reference/language.md §17.1.5.
%
% The fixture is testing/fixtures/le/conditional_negation.le.

:- use_module('../le_kbs').

cn_kb(KB) :- load('testing/fixtures/le/conditional_negation.le', KB).

% Code-[Assumption] pairs of the query in a scenario, as text
cn_answers(Scenario, Answers) :-
    cn_kb(KB),
    createSession(KB, SM), setScenarion(SM, Scenario),
    findall(C-As,
            ( query(SM, subheading, I, Us, _), last(I, C0), term_string(C0, C),
              findall(A, ( member(U, Us), u_text(U, A) ), As0), sort(As0, As) ),
            Answers0),
    destroySession(SM),
    sort(Answers0, Answers).

u_text(not(G), S) :- !, G =.. [_|Args], last(Args, V), format(string(S), "not ~w", [V]).
u_text(G, S) :- G =.. [_|Args], last(Args, V), ( var(V) -> S = "open" ; format(string(S), "~w", [V]) ).

:- begin_tests(conditional_negation).

test(the_residual_heading_holds_if_the_judgment_is_denied) :-
    cn_answers(open, As),
    assertion(memberchk("\"26.90\""-["not kitchen use", "not office use", "not ornament", "not table use", "open"], As)).

test(each_row_of_a_first_match_table_answers_for_its_values) :-
    cn_answers(open, As),
    forall(member(C-U, ["\"24.10\""-["kitchen use"], "\"24.10\""-["table use"],
                        "\"26.10\""-["office use"], "\"26.40\""-["ornament"]]),
           assertion(memberchk(C-U, As))).

test(one_decision_for_each_subject) :-
    % heading 24 assumes kitchen use, so its subheading cannot assume
    % another use, nor take the "any" row that excludes kitchen use
    cn_answers(open, As),
    assertion(\+ ( member("\"24.90\""-U, As), member("kitchen use", U) )),
    assertion(\+ ( member(_-U2, As), member(X, U2), member(Y, U2), X \== Y,
                   \+ sub_string(X, 0, _, _, "not"), \+ sub_string(Y, 0, _, _, "not"),
                   X \== "open", Y \== "open" )).

test(a_recorded_judgment_gives_one_firm_answer) :-
    cn_answers(decided, As),
    assertion(As == ["\"26.40\""-[]]).

test(a_recorded_judgment_blocks_the_residual_heading) :-
    cn_answers(household, As),
    assertion(As == ["\"24.10\""-[]]).

test(the_flag_turns_conditional_negation_off) :-
    setup_call_cleanup(set_prolog_flag(le_conditional_negation, false),
                       cn_answers(open, As),
                       set_prolog_flag(le_conditional_negation, true)),
    assertion(\+ memberchk("\"26.90\""-_, As)).

% the values a reader is offered for the judgment include those that only the
% table's column compares it with (le_verifier:slot_values/5): a reader who
% is not offered "ornament" cannot state it
test(the_values_of_a_judgment_include_the_table_cells) :-
    cn_kb(KB),
    le_verifier:slot_values(KB, the_principal_use_of_is, 2, 2, Vs),
    assertion(subtract(['kitchen use', 'office use', ornament, 'table use'], Vs, [])).


% A negation sees what its answer has already assumed. Heading "plastics"
% assumes that the sole is rubber; heading "other" can be proved by assuming
% that the sole is of a class left open, and not rubber. That proof
% cannot be denied fact by fact, so "no other heading applies" used to fail,
% and the answer "plastics" was lost. In the answer that assumes a rubber
% sole, the proof of "other" contradicts the answer (one value of the sole),
% so it does not count.
branch_program("the target language is: prolog.

the templates are:
    the sole of *a shoe* is *a class*; one value; assumable.
    *a shoe* is described by *a heading*.
    *a shoe* goes to *a heading*.
    the colour of *a shoe* is *a colour*.

the knowledge base k includes:

a shoe is described by plastics if
    the sole of the shoe is rubber.

a shoe is described by other if
    the sole of the shoe is a class
    and it is not the case that
        the shoe is described by plastics.

a shoe goes to a heading if
    the shoe is described by the heading
    and it is not the case that
        the shoe is described by an other heading
        and the other heading is different from the heading.

scenario s is:
    the colour of shoe1 is red.

query q is:
    shoe1 goes to which heading.
").

test(a_negation_sees_the_assumptions_of_its_answer) :-
    branch_program(P),
    load_text(P, test_conditional_negation_branch, KB),
    createSession(KB, SM), setScenarion(SM, s),
    findall(H-N, ( query(SM, q, I, Us, _), last(I, H), length(Us, N) ), As0),
    destroySession(SM),
    sort(As0, As),
    assertion(memberchk(plastics-1, As)),
    assertion(memberchk(other-2, As)).

:- end_tests(conditional_negation).

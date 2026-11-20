% Tests for the facts background (docs/user/reference/language.md §14.5;
% lpsPlus docs/strategy/FactsBackground.md): the section
% `the facts background includes these resources:`, the reading step that
% runs the background programs on the facts a reader wrote
% (le_background.pl), and the verifier's checks of the section.
%
% The fixture is testing/fixtures/le/facts_background/: main.le (a small
% rule base), background/garments.le (bridges) and
% background/presumptions.le (presumptions), and cases.le, which includes
% main.le.

:- use_module('../le_kbs').
:- use_module('../le_background').
:- use_module('../le_tools').
:- use_module('../le_assistant_light').

fb_file(Name, Path) :-
    atom_concat('testing/fixtures/le/facts_background/', Name, Path).

fb_main(KB) :-
    fb_file('main.le', F), load(F, KB).

% the answers of a named query in a scenario, as text
answers(KB, Scenario, Query, Answers) :-
    findall(S, ( createSession(KB, SM), setScenarion(SM, Scenario),
                 query(SM, Query, I, [], _), canonical_string(I, S) ), As),
    sort(As, Answers).

% the main program, with the section removed
main_without_section(Text) :-
    fb_file('main.le', F), read_file_to_string(F, T0, []),
    re_replace("the facts background includes these resources:\n    background/garments, background/presumptions.\n"/s,
               "", T0, Text).

stub_lines([ "item one is called \"Tee Shirt\", confer \"Men Tee Shirt\".",
             "the field \"Craft of Weaving\" of item one reads \"Knit\", confer \"Craft of Weaving: Knit\"." ]).

result_lines(KB, Lines, Out) :-
    apply_background(KB, Lines, R), Out = R.lines.

has_line_with(Lines, Sub) :- member(L, Lines), sub_string(L, _, _, _, Sub), !.

:- begin_tests(facts_background).

% --- the language --------------------------------------------------------

test(the_section_is_recorded_and_resolved) :-
    fb_main(KB),
    findall(N-Id, KB:le_facts_background(N, Id, _, _), Pairs),
    Pairs = ['background/garments'-G, 'background/presumptions'-_],
    assertion(sub_atom(G, _, _, 0, 'facts_background/background/garments.le')),
    assertion(\+ ( KB:le_issue(error, _, _, _, _, _) )).

% The program never reasons with its background: its queries answer exactly
% as they do without the section, and the background's templates are not
% the program's.
test(the_section_does_not_change_the_answers) :-
    fb_main(KB),
    main_without_section(Text),
    fb_file('', Dir0), absolute_file_name(Dir0, Dir),
    load_text(Text, Dir, KB0),
    forall(member(Sc-Q, [stated-headings, read-readings, read-headings]),
           ( answers(KB, Sc, Q, A1), answers(KB0, Sc, Q, A0),
             assertion(A1 == A0) )),
    assertion(\+ current_predicate(KB:is_called/2)).

% A file that includes the rule base gets its facts background (decision 3).
test(an_included_program_brings_its_background) :-
    fb_file('cases.le', F), load(F, KB),
    findall(N, KB:le_facts_background(N, _, _, _), Ns),
    assertion(Ns == ['background/garments', 'background/presumptions']),
    facts_background(KB, Programs),
    assertion(forall(member(bg(_, _, _, St), Programs), St = loaded(_, _, _, _))).

test(the_section_reads_in_portuguese) :-
    Text = "a linguagem alvo é: prolog.\n\no contexto dos factos inclui estes recursos:\n    fundo.\n\nos modelos são:\n    *uma coisa* é boa.\n\na base de conhecimento k inclui:\n\nlua é boa.\n",
    load_text(Text, KB),
    assertion(KB:le_facts_background(fundo, _, _, _)).

% --- the background step ---------------------------------------------------

test(background_templates_noted_and_shared) :-
    fb_main(KB),
    background_templates(KB, Noted, Shared),
    findall(L, member(n(L, _, _), Noted), Labels),
    assertion(Labels == ["*a thing* is called *a name*",
                         "the field *a field* of *a thing* reads *a value*"]),
    assertion(Shared == [the_fabric_construction_of_is/2, the_fabric_of_is_lightweight/1, the_kind_of_is/2]).

% The noted facts stay behind; the facts they give come back with their
% origin: the background program, the rule, the passage.
test(derived_facts_carry_their_origin) :-
    fb_main(KB), stub_lines(Lines),
    result_lines(KB, Lines, Out),
    assertion(Out == [
        "the fabric construction of item one is knitted, according to garments background, because \"construction_by_field\", confer \"Craft of Weaving: Knit\".",
        "the kind of item one is T-shirt, according to garments background, because \"kind_by_name\", confer \"Men Tee Shirt\".",
        "the fabric of item one is lightweight, according to customs presumptions, because \"tshirt_fabric\", confer \"Men Tee Shirt\"."
    ]).

% A program later in the list reads the facts that the ones before it
% derived; the fact it gives rests on the reader's own line.
test(a_presumption_rests_on_the_noted_fact) :-
    fb_main(KB), stub_lines(Lines),
    apply_background(KB, Lines, R),
    member(D, R.derived), D.rule == "tshirt_fabric", !,
    assertion(D.from == ["item one is called \"tee shirt\", confer \"Men Tee Shirt\"."]),
    member(N, R.noted), sub_string(N.fact, _, _, _, "is called"), !,
    assertion(memberchk("the fabric of item one is lightweight", N.produced)).

% A stated fact beats a derived fact of a template with one value.
test(a_stated_fact_beats_a_derived_one) :-
    fb_main(KB),
    apply_background(KB, ["item four is called \"t-shirt\", confer \"T-shirt\".",
                          "the fabric construction of item four is woven, confer \"woven\"."], R),
    assertion(memberchk("the fabric construction of item four is woven, confer \"woven\".", R.lines)),
    assertion(\+ has_line_with(R.lines, "item four is knitted")),
    R.notes = [Note],
    assertion(sub_string(Note, _, _, _, "The text states that the fabric construction of item four is woven")).

% Two background rules that give two values give no fact, and a question.
test(two_derived_values_are_a_question) :-
    fb_main(KB),
    apply_background(KB, ["item three is called \"t-shirt\", confer \"Tee\".",
                          "the field \"craft of weaving\" of item three reads \"woven\", confer \"Craft: Woven\"."], R),
    assertion(\+ has_line_with(R.lines, "fabric construction of item three")),
    R.questions = [Q],
    assertion(sub_string(Q, _, _, _, "Which is right?")),
    % the fabric of the T-shirt is still presumed
    assertion(has_line_with(R.lines, "the fabric of item three is lightweight")).

% A word that no rule of the background knows is shown, with no expected
% answer in sight.
test(a_noted_word_nothing_knows_is_unused) :-
    fb_main(KB),
    apply_background(KB, ["item five is called \"boyshorts\", confer \"Boyshorts\"."], R),
    assertion(R.unused == ["item five is called \"boyshorts\", confer \"Boyshorts\"."]),
    assertion(R.lines == []).

test(without_a_background_the_lines_come_back) :-
    load_text("the target language is: prolog.\n\nthe templates are:\n    *a thing* is good.\n\nthe knowledge base k includes:\n\nmoon is good.\n", KB),
    apply_background(KB, ["sun is good."], R),
    assertion(R.lines == ["sun is good."]).

% The two readings: with the lines that the step returns, the strict
% reading (no presumptions admitted) does not classify the T-shirt; the
% full reading does.
test(the_two_readings_of_a_read_case) :-
    fb_main(KB), stub_lines(Lines),
    result_lines(KB, Lines, Out),
    fb_file('main.le', F), read_file_to_string(F, T0, []),
    findall(S, ( member(L, Out), format(string(S), "    ~w", [L]) ), Ind),
    atomic_list_concat(Ind, "\n", Body),
    format(string(Text), "~w\nscenario fresh is, as stated in the listing:\n~w\n", [T0, Body]),
    fb_file('', Dir0), absolute_file_name(Dir0, Dir),
    load_text(Text, Dir, KB2),
    answers(KB2, fresh, readings, As),
    assertion(As == ["item one is classified in 6109 by full reading"]).

% --- the verifier ----------------------------------------------------------

issue_types(Text, Types) :-
    fb_file('', Dir0), absolute_file_name(Dir0, Dir),
    load_text(Text, Dir, KB),
    findall(T, KB:le_issue(_, T, _, _, _, _), Ts), sort(Ts, Types).

main_with(Section, Extra, Text) :-
    format(string(Text), "the target language is: prolog.\n\nthe facts background includes these resources:\n    ~w.\n\nthe templates are:\n    the kind of *a good* is *a kind*; undefined.\n    the fabric of *a garment* is lightweight; undefined.\n    the heading of *a good* is *a heading*.\n\nthe knowledge base t includes:\n\nthe heading of a good is 6109\n    if the kind of the good is T-shirt\n    and the fabric of the good is lightweight.\n~w\nscenario s is:\n    the kind of box is T-shirt.\n    the fabric of box is lightweight.\n    q expects answers [\"the heading of box is 6109\"].\n\nquery q is:\n    the heading of which good is which heading.\n", [Section, Extra]).

test(the_fixture_has_no_background_warning) :-
    fb_main(KB),
    assertion(\+ ( KB:le_issue(_, T, _, _, _, _), sub_atom(T, 0, _, _, background_) )).

test(a_missing_background_is_reported) :-
    main_with('background/nowhere', "", Text),
    issue_types(Text, Types),
    assertion(memberchk(background_missing, Types)).

test(checks_of_a_background_program, [setup(write_bad_background), cleanup(delete_bad_background)]) :-
    main_with('background/bad_tmp', "", Text),
    issue_types(Text, Types),
    assertion(memberchk(background_decides, Types)),
    assertion(memberchk(background_unread_value, Types)),
    assertion(memberchk(background_unused_noted, Types)),
    assertion(memberchk(background_without_source, Types)).

test(a_background_that_shares_nothing, [setup(write_lonely_background), cleanup(delete_lonely_background)]) :-
    main_with('background/lonely_tmp', "", Text),
    issue_types(Text, Types),
    assertion(memberchk(background_shares_nothing, Types)).

% --- the assistants -------------------------------------------------------

test(the_tool_for_assistants_reads_facts) :-
    fb_file('main.le', F), read_file_to_string(F, Text, []),
    fb_file('', Dir0), absolute_file_name(Dir0, Dir),
    le_tool_read_facts(_{program_text: Text, program_base: Dir}, R0),
    assertion(R0.noted_templates == ["*a thing* is called *a name*",
                                     "the field *a field* of *a thing* reads *a value*"]),
    stub_lines(Lines), atomic_list_concat(Lines, "\n", Facts),
    le_tool_read_facts(_{program_text: Text, program_base: Dir, facts: Facts}, R),
    assertion(has_line_with(R.lines, "the kind of item one is T-shirt, according to garments background")).

test(the_light_assistant_is_told_of_the_background) :-
    fb_file('main.le', F), read_file_to_string(F, Text, []),
    fb_file('', Dir0), absolute_file_name(Dir0, Dir),
    b_setval(le_assistant_base, Dir),
    le_assistant_light:facts_background_part(Text, Part),
    assertion(sub_string(Part, _, _, _, "used ONLY to read the facts")),
    assertion(sub_string(Part, _, _, _, "*a thing* is called *a name*")),
    assertion(sub_string(Part, _, _, _, "read_facts")).

:- end_tests(facts_background).

bad_path(P) :- fb_file('background/bad_tmp.le', P).
lonely_path(P) :- fb_file('background/lonely_tmp.le', P).

write_bad_background :-
    bad_path(P),
    setup_call_cleanup(open(P, write, S), format(S, "~w", ["the target language is: prolog.

the templates are:
    *a thing* is called *a name*; undefined.
    *a thing* has the label *a label*; undefined.
    the kind of *a good* is *a kind*.
    the heading of *a good* is *a heading*.

the knowledge base bad background includes:

the kind of a good is tee
    if the good is called \"tee\".

the heading of a good is 6109
    if the good is called \"tee\".
"]), close(S)).
delete_bad_background :- bad_path(P), ( exists_file(P) -> delete_file(P) ; true ).

write_lonely_background :-
    lonely_path(P),
    setup_call_cleanup(open(P, write, S), format(S, "~w", ["the target language is: prolog.

the templates are:
    *a thing* is called *a name*; undefined.
    *a thing* is red.

the knowledge base lonely background includes:

rule red with provenance nothing:
a thing is red
    if the thing is called \"red\".
"]), close(S)).
delete_lonely_background :- lonely_path(P), ( exists_file(P) -> delete_file(P) ; true ).

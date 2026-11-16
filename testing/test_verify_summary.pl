% Tests of the MCP verify tool's summary and several_amounts warning
% (le_tools:verify_summary/5), of program_file (llm/mcp.pl), and of the
% spacing of embedded prolog goals (le_grammar:resolve_prolog_tokens/5).
:- use_module('../le_kbs').
:- use_module('../le_tools').
:- use_module('../llm/mcp').

:- begin_tests(verify_summary).

two_rules_program("the target language is: prolog.

the templates are:
    *a household* has *a number* members.
    *a household* has earned income of *an amount*.
    the deduction of *a household* is *an amount*.

the knowledge base deductions includes:
the deduction of a household is an amount D
    if the household has earned income of an amount E
    and D = E * 0.2.

the deduction of a household is 0
    if the household has a number members
    and it is not the case that
        the household hasearned income of an amount.

scenario one is:
    smith has 2 members.
    smith has earned income of 100.
    deduction expects answers [\"the deduction of smith is 20\"].

query deduction is:
    the deduction of which household is which amount.
").

max_program("the target language is: prolog.

the templates are:
    *a claim* is paid *an amount* under *a cover*.
    the payment for *a claim* is *an amount*.

the knowledge base payments includes:
c1 is paid 0 under cover a.
c1 is paid 300 under cover b.

the payment for a claim is an amount P
    if P is the max of each amount A such that
        the claim is paid the amount A under a cover.

scenario one is:
    c2 is paid 5 under cover a.

query paid is:
    which claim is paid which amount under which cover.
").

test(summary_counts_and_several_amounts) :-
    two_rules_program(T),
    le_tool_verify(T, R),
    get_dict(summary, R, S),
    assertion(S.tests == 1),
    assertion(S.tests_failed == 1),
    assertion(S.scenarios == 1),
    get_dict(issues, R, Is),
    assertion(( member(I, Is), get_dict(type, I, several_amounts) )).

test(different_things_are_not_several_amounts) :-
    % c1 has two amounts, one under each cover: the cover differs, so they
    % are not two values of one thing; and the max reads the template.
    max_program(T),
    le_tool_verify(T, R),
    get_dict(issues, R, Is),
    assertion(\+ ( member(I, Is), get_dict(type, I, several_amounts) )).

test(program_file_refused_without_stdio) :-
    retractall(mcp:mcp_local_files),
    mcp:program_file_args(_{program_file: "/etc/hostname"}, _, Error),
    assertion(string(Error)).

test(program_file_read_over_stdio, [cleanup(retractall(mcp:mcp_local_files))]) :-
    tmp_file_stream(text, F, St), write(St, "the target language is: prolog.\n"), close(St),
    assertz(mcp:mcp_local_files),
    atom_string(F, FS),
    mcp:program_file_args(_{program_file: FS}, Args, Error),
    assertion(var(Error)),
    assertion(get_dict(program_text, Args, "the target language is: prolog.\n")),
    delete_file(F).

:- end_tests(verify_summary).

:- begin_tests(prolog_goal_spacing).

test(is_with_le_variables) :-
    T = "the target language is: prolog.

the templates are:
    *a sale* is on *a date*.
    the start of *a sale* is *a date*.

the knowledge base pg includes:
the start of a sale is a date W
    if the sale is on a date T
    and prolog (T = date(Y, M, D), YW is Y - 5, W = date(YW, M, D)).

scenario one is:
    s is on 2026-01-22.
    t expects answers [\"the start of s is 2021-01-22\"].

query t is:
    the start of s is which date.
",
    le_tool_verify(T, R),
    get_dict(test_results, R, [Res]),
    assertion(Res.status == "pass").

:- end_tests(prolog_goal_spacing).

/** <module> Scenarios included from other files

    `the knowledge base <name> includes these scenarios: <file>, ...`
    (docs/user/reference/language.md §14) reads each file as an included
    resource is read, but keeps its scenarios and its queries, with their
    `expects` lines. Two scenarios, or two queries, with one name are an
    error on that line. The example suite runs such a file through the
    program that includes it, not again on its own.

    Run with:  swipl -q -g run_tests -t halt testing/test_include_scenarios.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_include_scenarios, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_grammar').
:- use_module('../le_writer').
:- use_module('../tokenizer').

rules_text("the target language is: prolog.

the templates are:
    *a person* is eligible.
    *a person* is resident.

the knowledge base rules includes:

a person is eligible if the person is resident.

scenario rules own is:
    zed is resident.
").

cases_text("the target language is: prolog.

the knowledge base cases includes these resources:
    rules.

the knowledge base cases includes:

scenario ann is:
    ann is resident.
    q expects answers [\"ann is eligible\"].

query q is:
    which person is eligible.
").

main_text("the target language is: prolog.

the knowledge base main includes these resources:
    rules.

the knowledge base main includes these scenarios:
    cases.

the knowledge base main includes:

scenario bob is:
    bob is resident.
    q expects answers [\"bob is eligible\"].
").

clash_text("the target language is: prolog.

the knowledge base clash includes these resources:
    rules.

the knowledge base clash includes these scenarios:
    cases.

the knowledge base clash includes:

scenario ann is:
    bob is resident.

query q is:
    which person is resident.
").

with_programs(Goal) :-
    tmp_file(le_scen, Dir),
    make_directory(Dir),
    forall(member(F-P, ['rules.le'-rules_text, 'cases.le'-cases_text,
                        'main.le'-main_text, 'clash.le'-clash_text]),
           ( directory_file_path(Dir, F, Path), call(P, T), write_file(Path, T) )),
    setup_call_cleanup(true, call(Goal, Dir), delete_directory_and_contents(Dir)).

write_file(Path, Text) :-
    setup_call_cleanup(open(Path, write, S), write(S, Text), close(S)).

load_in(Dir, File, KB) :-
    directory_file_path(Dir, File, Path),
    load(Path, KB).

:- begin_tests(include_scenarios).

%   (a list of resources ends where the next section starts)
test(parses_header) :-
    le_grammar:parse_le_text("the target language is: prolog.\n\nthe knowledge base k includes these scenarios:\n    cases/a,\n    b.le.\n\nthe knowledge base k includes:\n", doc(Secs), -),
    memberchk(scenario_resources(k, ['cases/a', 'b.le'], _, _), Secs).

test(parses_header_pt) :-
    le_grammar:parse_le_text("a linguagem alvo é: prolog.\n\na base de conhecimento k inclui estes cenários:\n    casos.\n\na base de conhecimento k inclui:\n", doc(Secs), -),
    memberchk(scenario_resources(_, [casos], _, _), Secs).

test(scenarios_and_queries_come_in) :-
    with_programs([Dir]>>(
        load_in(Dir, 'main.le', KB),
        findall(N, KB:scenario(N, _), Ns), msort(Ns, Sorted),
        assertion(Sorted == [ann, bob]),         % not "rules own": an include's
        assertion(KB:query_info(q, _, _)),
        findall(S, KB:le_expected(q, S, _, _), Es), msort(Es, SEs),
        assertion(SEs == [ann, bob]),
        assertion(\+ KB:le_issue(error, _, _, _, _, _)) )).

test(their_tests_run) :-
    with_programs([Dir]>>(
        directory_file_path(Dir, 'main.le', Main),
        runTestsFor(Main, test_file(_, Results)),
        msort(Results, Sorted),
        assertion(Sorted == [pass(q, ann), pass(q, bob)]) )).

test(name_clash_is_an_error_on_the_line, [nondet]) :-
    with_programs([Dir]>>(
        load_in(Dir, 'clash.le', KB),
        clash_text(Text),
        sub_string(Text, Line, _, _, "the knowledge base clash includes these scenarios"),
        findall(D, ( KB:le_issue(error, included_case_clash, D, _, S, _), S == Line ), Ds),
        assertion(length(Ds, 2)),
        assertion(( member(D1, Ds), sub_atom(D1, _, _, _, 'cases.le, line 8') )) )).

test(writer_keeps_the_line) :-
    with_programs([Dir]>>(
        load_in(Dir, 'main.le', KB),
        le_write_kb(KB, Text),
        assertion(sub_string(Text, _, _, _, "includes these scenarios:\n    cases.")),
        assertion(\+ sub_string(Text, _, _, _, "scenario ann is")) )).

test(suite_runs_the_file_once) :-
    with_programs([Dir]>>(
        directory_file_path(Dir, 'main.le', Main),
        findall(F, le_kbs:included_scenario_file(Main, F), Fs),
        directory_file_path(Dir, 'cases.le', Cases0), absolute_file_name(Cases0, Cases),
        assertion(Fs == [Cases]),
        le_kbs:runTestsInDir(Dir, core, Results),
        findall(B, ( member(test_file(P, _), Results), file_base_name(P, B) ), Bs),
        assertion(\+ memberchk('cases.le', Bs)),
        assertion(memberchk('main.le', Bs)) )).

:- end_tests(include_scenarios).

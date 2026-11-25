%   A scenario fact must not be lost in silence (found by the review of
%   Logisches Deutsch, 25 November 2026; the two defects were in every
%   language):
%   - a scenario fact that matches no template is reported (missing_template);
%   - a fact that starts with a name with points ("R.J.") keeps its citation.
:- use_module(library(plunit)).
:- use_module('../le_kbs').

:- begin_tests(scenario_fact_checks).

program("the target language is: prolog.

the templates are:
    *a beneficiary* tests blood glucose *a number* times per day.
    *a beneficiary* is busy.

the knowledge base checks includes:

a beneficiary is busy
    if the beneficiary tests blood glucose a number times per day
    and the number >= 5.

scenario dotted is:
    R.J. tests blood glucose 12 times per day, confer \"the record\".
    one expects answers [\"R.J. is busy\"].

scenario unmatched is:
    Bert was born in the year 2000 in Bern.

query one is:
    which beneficiary is busy.
").

test(unmatched_scenario_fact_is_reported, [nondet]) :-
    program(Text),
    le_kbs:load_text(Text, M),
    findall(Desc, M:le_issue(_, missing_template, Desc, _, _, _), Descs),
    Descs = [Desc],
    sub_atom(Desc, _, _, _, 'Bert was born').

test(dotted_name_keeps_its_citation) :-
    program(Text),
    tmp_file_stream(text, File0, S0), close(S0),
    atom_concat(File0, '.le', File),
    setup_call_cleanup(
        ( open(File, write, S, [encoding(utf8)]), write(S, Text), close(S) ),
        le_kbs:runTestsFor(File, test_file(_, Results)),
        ( catch(delete_file(File), _, true), catch(delete_file(File0), _, true) )),
    Results = [pass(_, _)].

:- end_tests(scenario_fact_checks).

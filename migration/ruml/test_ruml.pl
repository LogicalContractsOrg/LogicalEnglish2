/** <module> Tests of the RUML translator (the design notes ruml.md)

    swipl -q -g run_tests -t halt migration/ruml/test_ruml.pl      (from the LE2 checkout)

    The JSONata reader, the reader's checks, the three results of a twin,
    the evaluator in both modes, the way back and its refusals, File ▸ Open.
    The gates (gate.pl, build.pl, ruml_roundtrip.pl) measure the whole
    corpus; these tests stay small and fast. They need fetch_sources.sh for
    the two examples of the specification they read, and Node for the
    oracle of File ▸ Open (skipped without it).
*/

:- module(test_ruml, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(readutil)).
:- use_module('../le2_paths').
:- use_module(le2(le_kbs)).
:- use_module(jsonata_parser).
:- use_module(ruml_reader).
:- use_module(ruml_twin).
:- use_module(ruml_result).
:- use_module(ruml_export).
:- use_module(ruml_names).
:- use_module(corpus).
:- use_module(le2(le_migration)).

example(Rel, F) :- ruml_repo(R), atomic_list_concat([R, '/spec/en/', Rel], F).
foerder(F) :- example('05-result-format/5-1-result-model.examples/foerderantrag.ruml', F).
haertefall(F) :- example('04-capabilities/4-14-ruml-expression.examples/haertefall.ruml', F).
%   The fetched sources of RUML (fetch_sources.sh puts the specification in
%   .cache/ruml): the tests that read one of its two examples are skipped
%   without it. fetch_sources.sh installs the oracle's Node packages too
%   (node_modules/): File ▸ Open asks the oracle, and is skipped without them.
fetched(Example) :- call(Example, F), exists_file(F).
oracle_installed :-
    cache_dir(C), file_directory_name(C, Dir),
    atomic_list_concat([Dir, '/node_modules/jsonata'], M), exists_directory(M).

minimal(Extra, Text) :-
    format(string(Text), '{"$format": "RUML", "$specVersion": "1.0", ~w "metadata": {"id": "ec36948d-fbb2-4815-985a-bd5e9375d934", "version": "1.0.0", "created": "2024-01-01T00:00:00Z", "modified": "2024-01-01T00:00:00Z", "status": "draft"}, "rulemap": {"nodes": {"1": {"id": "0eb360a6-626a-406d-89a1-9f434ced141b", "label": "Root"}}}}', [Extra]).

%   The status of the root of a rulemap for a case, as the twin says it.
root_status(File, Data, Mode, S) :-
    ruml_evaluate(File, Data, [mode(Mode)], R),
    j(R, evaluation, E), j(E, results, Rs), j(Rs, '1', N), j(N, status, S0), atom_string(S, S0).

:- begin_tests(ruml).

test(jsonata_reads_the_public_forms) :-
    forall(member(E, ["dp_age >= 18", "$lookup({'yes': true, 'no': false}, dp_answer_1)",
                      "$count($children[status = 'true']) >= 2", "dp_alter >= 65 or $count($children[status = 'true']) = 3",
                      "$children[lexId = \"4\"].status = \"false\" and $children[lexId = \"5\"].status = \"true\"",
                      "2024 - dp_birth_year >= 18", "$count(dp_buergen[dp_income > 1000]) >= 2"]),
           assertion(jsonata_parse(E, _))),
    jsonata_parse("2024 - dp_birth_year >= 18", T), jsonata_names(T, Ns), assertion(Ns == [dp_birth_year]).

test(labels_keep_their_words) :-
    label_text("Antragsteller volljährig", A), assertion(A == 'Antragsteller volljährig'),
    label_text("§ 2 (1) GmbHG", B), assertion(B == '§ 2 1 GmbHG'),
    label_text("Income > 30,000 EUR", C), assertion(C == 'Income more than 30000 eur'),
    label_text("If a person is BOLD", D), assertion(D == 'If_person is_bold').

test(a_minimal_file_is_accepted) :-
    minimal('', T), ruml_read_text(T, Doc, Is), assertion(Doc \== none), assertion(\+ member(issue(error, _, _, _), Is)).

test(an_unknown_required_capability_is_refused) :-
    minimal('"capabilities": [{"id": "com.example/thing", "required": true, "role": "data"}],', T),
    ruml_read_text(T, _, Is), assertion(memberchk(issue(error, 'CAP-01', _, _), Is)).

test(a_reserved_prefix_is_refused) :-
    minimal('"capabilities": [{"id": "ruml:mine"}],', T),
    ruml_read_text(T, _, Is), assertion(memberchk(issue(error, 'CAP-21', _, _), Is)).

%   The three results of RUML, from the twin (the funding example of §5.1).
test(complete_mode_three_values, [condition(fetched(foerder))]) :-
    foerder(F),
    root_status(F, [dp_age-25, dp_income-35000, dp_hardship- @(false), dp_state-"BY"], complete, S1), assertion(S1 == true),
    root_status(F, [dp_age-16, dp_income-35000, dp_state-"BY"], complete, S2), assertion(S2 == false),
    root_status(F, [dp_income-35000, dp_state-"BY"], complete, S3), assertion(S3 == undefined),
    root_status(F, [dp_income-50000, dp_state-"BY"], complete, S4), assertion(S4 == false).

%   The modes differ (§3.6; issue 2 of the format's repository).
test(optimized_mode_stops_at_the_first_open_child, [condition(fetched(foerder))]) :-
    foerder(F),
    root_status(F, [dp_income-50000, dp_state-"BY"], optimized, S), assertion(S == undefined),
    ruml_evaluate(F, [dp_income-50000, dp_state-"BY"], [mode(optimized)], R),
    j(R, evaluation, E), j(E, results, Rs), j(Rs, '1.2', N), j(N, status, St), assertion(St == ignored).

%   The specification's own result for its hardship case (§4.14).
test(the_specification_s_hardship_case, [condition(fetched(haertefall))]) :-
    haertefall(F),
    root_status(F, [dp_pflegegrad-4, dp_eigenanteil-640, dp_alleinlebend- @(true), dp_wohnsitz- @(true)], complete, S),
    assertion(S == true).

%   An undefined leaf's reason names the missing value.
test(reason_of_a_missing_value, [condition(fetched(foerder))]) :-
    foerder(F),
    ruml_evaluate(F, [dp_income-35000, dp_state-"BY"], [mode(complete)], R),
    j(R, evaluation, E), j(E, results, Rs), j(Rs, '1.1', N), j(N, reason, Re), j(Re, message, M),
    assertion(sub_string(M, _, _, _, "no value for Alter des Antragstellers (dp_age)")).

%   The way back: a small program, and a program RUML cannot say.
test(export_a_program) :-
    P = "the target language is: prolog.\n\nthe templates are:\n    *a case* is eligible.\n    *a case* is resident; scenario element.\n    the age of *a case* is *a number*; scenario element.\n\nthe knowledge base elig includes:\n\na case is eligible if\n    the case is resident\n    and the age of the case is a number N\n    and N >= 18.\n\nquery q is:\n    which case is eligible.\n",
    le_kbs:set_le_issue_reporting(false), le_kbs:load_text(P, KB), le_kbs:set_le_issue_reporting(true),
    export_ruml(KB, [text(P)], R),
    assertion(R = exported(_, _, _, _)),
    R = exported(_, Text, _, _),
    assertion(sub_string(Text, _, _, _, "\"operator\":\"AND\"")),
    assertion(sub_string(Text, _, _, _, "dp_age >= 18")),
    assertion(sub_string(Text, _, _, _, "dp_resident = true")),
    assertion(sub_string(Text, _, _, _, "In Logical English:")),
    ruml_read_text(Text, _, Is), assertion(\+ member(issue(error, _, _, _), Is)).

test(export_refuses_a_relation) :-
    P = "the target language is: prolog.\n\nthe templates are:\n    *a person* is an ancestor of *a person*.\n    *a person* is a parent of *a person*.\n    *a person* is happy.\n\nthe knowledge base anc includes:\n\na person is happy if\n    the person is an ancestor of a second person.\n\na person is an ancestor of a second person if\n    the person is a parent of the second person.\n\nquery q is:\n    which person is happy.\n",
    le_kbs:set_le_issue_reporting(false), le_kbs:load_text(P, KB), le_kbs:set_le_issue_reporting(true),
    export_ruml(KB, [text(P)], R),
    assertion(R = refused([_|_])).

%   Node, wherever it is installed.
node_on_path :- absolute_file_name(path(node), _, [access(execute), file_errors(fail)]).

%   File ▸ Open of a rulemap, through LE2's registry.
test(file_open, [condition(( fetched(haertefall), oracle_installed, node_on_path ))]) :-
    haertefall(F), read_file_to_string(F, C, []),
    le_import:import_upload("haertefall.ruml", text(C), R, []),
    assertion(sub_string(R.document, _, _, _, "Härtefall liegt vor holds for a case if")),
    assertion(sub_string(R.document, _, _, _, "expects answers")).

:- end_tests(ruml).

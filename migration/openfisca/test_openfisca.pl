/** <module> Tests of the OpenFisca / PolicyEngine translator (Phase 3b)

    Run from the LE2 checkout (/work), after fetch_sources.sh:

        ./myswipl.sh -q -g run_tests -t halt migration/openfisca/test_openfisca.pl

    The twins are read as built (of_build.pl); the static reader, the import
    and the export run here; the check on openfisca-core is skipped when the
    environment of fetch_sources.sh is missing.
*/

:- module(test_openfisca, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(filesex)).
:- use_module(library(process)).
:- use_module('../le2_paths', [twins_dir/2, le2_dir/1]).
:- use_module(le2(le_kbs)).
:- use_module(of_import).
:- use_module(of_export).

:- dynamic dir/1.
:- prolog_load_context(directory, D), retractall(dir(_)), assertz(dir(D)).

twin(Group, P, F) :- twins_dir(Group, D), format(atom(F), '~w/~w/~w.le', [D, P, P]).
%   A twin of OpenFisca is not published (the sources are AGPL-3.0):
%   of_build.pl writes it to the private place (le2_paths:private_root/1),
%   and the tests that read it are skipped without it.
twin_built(Group, P) :- twin(Group, P, F), exists_file(F).

passes(File, Pass, Fail) :-
    runTestsFor(File, R0), ( R0 = test_file(_, Rs) -> true ; Rs = R0 ),
    aggregate_all(count, member(pass(_, _), Rs), Pass),
    length(Rs, All), Fail is All - Pass.

venv :- dir(D), atomic_list_concat([D, '/.cache/venv/bin/python'], P), exists_file(P).
template :- dir(D), atomic_list_concat([D, '/.cache/country-template/openfisca_country_template'], P), exists_directory(P).

:- begin_tests(openfisca_twins).

test(country_template_twin, [condition(twin_built(openfisca, country_template)), true(F == 0)]) :-
    twin(openfisca, country_template, File), passes(File, P, F), P >= 11.

test(the_twin_cites_the_package, [condition(twin_built(openfisca, country_template))]) :-
    twin(openfisca, country_template, File), read_file_to_string(File, T, []),
    sub_string(T, _, _, _, "openfisca_country_template"),
    sub_string(T, _, _, _, "the social security contribution of a person is an amount").

:- end_tests(openfisca_twins).

:- begin_tests(openfisca_import, [condition(template)]).

test(import_without_the_engine) :-
    dir(D), atomic_list_concat([D, '/.cache/country-template/openfisca_country_template'], Pkg),
    tmp_file(of, Out), make_directory_path(Out),
    import_openfisca(Pkg, Out, imported(LE, [N|_])),
    exists_file(LE),
    sub_string(N, _, _, _, "pass, 0 fail"),
    delete_directory_and_contents(Out).

:- end_tests(openfisca_import).

:- begin_tests(openfisca_export).

test(export_of_the_country_twin, [condition(twin_built(openfisca, country_template))]) :-
    twin(openfisca, country_template, File),
    read_file_to_string(File, Text, []), file_directory_name(File, Dir),
    le_kbs:load_text(Text, Dir, KB),
    openfisca_module(KB, M, T),
    sub_string(M, _, _, _, "class social_security_contribution(Variable):"),
    sub_string(M, _, _, _, "max_(0, "),
    sub_string(T, _, _, _, "output:").

test(runs_on_openfisca_core, [condition(( venv, twin_built(openfisca, country_template) ))]) :-
    dir(D), twin(openfisca, country_template, File),
    atomic_list_concat([D, '/of_roundtrip.pl'], RT),
    le2_dir(L), atomic_list_concat([L, '/myswipl.sh'], SW),
    process_create(SW, ['-q', RT, '--', File], [stdout(pipe(O)), cwd(L)]),
    read_string(O, _, S), close(O),
    sub_string(S, _, _, _, " 0 fail, 0 error").

:- end_tests(openfisca_export).

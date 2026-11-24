/** <module> Tests of the RuleSpec translator (Phase 3a)

    Run from the LE2 checkout (/work), after fetch_sources.sh and
    prepare_root.py:

        ./myswipl.sh -q -g run_tests -t halt migration/rulespec/test_rulespec.pl

    The engine's answers are read from runs/ (rulespec_oracle.py writes
    them); the round-trip test is skipped when the engine has not been built
    (fetch_oracle.sh).
*/

:- module(test_rulespec, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(filesex)).
:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(le2(le_kbs)).
:- use_module(le2(le_migration)).
:- use_module(rulespec_reader).
:- use_module(rulespec_twin).
:- use_module(rulespec_import).
:- use_module(rulespec_export).

:- dynamic dir/1.
:- prolog_load_context(directory, D), retractall(dir(_)), assertz(dir(D)).

twin_file(Group, Id, F) :-
    twins_dir(rulespec, Root), module_twin_name(Id, N),
    format(atom(F), '~w/~w/~w.le', [Root, Group, N]).

%   The fetched sources of RuleSpec (fetch_sources.sh, then prepare_root.py,
%   put rulespec-us in .cache/root/): the tests that read a module of the
%   corpus are skipped without it.
fetched(Id) :- module_file(Id, F), exists_file(F).

passes(File, Pass, Fail) :-
    runTestsFor(File, R0),
    ( R0 = test_file(_, Rs) -> true ; Rs = R0 ),
    aggregate_all(count, member(pass(_, _), Rs), Pass),
    length(Rs, All), Fail is All - Pass.

:- begin_tests(rulespec_reader).

test(formula_grammar) :-
    parse_formula("if household_size <= limit:\n    floor((cost * rate) + 0.5)\nelse:\n    0", T),
    T == if(cmp(=<, id(household_size), id(limit)), call(floor, [bin(+, bin(*, id(cost), id(rate)), num(0.5))]), num(0)).

test(precedence) :-
    parse_formula("a or b and not c", T),
    T == or(id(a), and(id(b), not(id(c)))),
    parse_formula("x - 2 * y + 1", T2),
    T2 == bin(+, bin(-, id(x), bin(*, num(2), id(y))), num(1)).

test(match_with_and_without_fallback) :-
    parse_formula("match n:\n  0 => 0.0765\n  1 => 0.34\n  _ => 0.45", T1),
    T1 == match(id(n), [num(0)-num(0.0765), num(1)-num(0.34)], num(0.45)),
    parse_formula("match n:\n  0 => a[0]\n  1 => a[1]", T2),
    T2 == match(id(n), [num(0)-index(a, num(0)), num(1)-index(a, num(1))], none).

test(table_and_aggregates) :-
    parse_formula("t[max(min(size, 8), 1)] + sum_where(member_of_household, income, counted)", T),
    T = bin(+, index(t, call(max, [call(min, [id(size), num(8)]), num(1)])),
            call(sum_where, [id(member_of_household), id(income), id(counted)])).

test(a_yaml_number_is_a_formula) :-
    parse_formula(150000.0, num(150000.0)).

test(closure_imports_first, [condition(fetched('us:statutes/7/2017/a'))]) :-
    module_closure('us:statutes/7/2017/a', Ms),
    findall(I, member(module(I, _), Ms), Ids),
    last(Ids, 'us:statutes/7/2017/a'),
    memberchk('us:policies/usda/snap/fy-2026-cola/maximum-allotments', Ids),
    nth1(P1, Ids, 'us:statutes/7/2014/e/2'), nth1(P2, Ids, 'us:statutes/7/2014/e/6/A'), P1 < P2.

test(path_identifier) :-
    path_module_id('/x/rulespec-us/us/statutes/7/2017/a.yaml', Id), Id == 'us:statutes/7/2017/a',
    path_module_id('/up/us-co/regulations/10-ccr-2506-1/4.207.3.yaml', Id2), Id2 == 'us-co:regulations/10-ccr-2506-1/4.207.3'.

:- end_tests(rulespec_reader).

:- begin_tests(rulespec_twin).

test(wording) :-
    judgment_text(snap_eligible, 'Household', T1), T1 == "*a household* is snap eligible",
    judgment_text(household_fails_gross_income_standard, 'Household', T2), T2 == "*a household* fails gross income standard",
    judgment_text(snap_net_income_exceeds_poverty_line, 'Household', T3), T3 == "the snap net income of *a household* exceeds poverty line",
    words_of(is_a_member_if_eligible, W), W == [is, member, when, eligible].

test(snap_allotment_twin, [true(P-F == 17-0)]) :-
    twin_file(snap, 'us:statutes/7/2017/a', File), passes(File, P, F).

test(eitc_twin_reproduces_the_engine, [true(F == 0)]) :-
    twin_file(eitc, 'us:statutes/26/32', File), passes(File, P, F), P > 20.

test(no_residue_in_the_snap_twin, [condition(fetched('us:statutes/7/2017/a'))]) :-
    module_migration('us:statutes/7/2017/a', [], migration(_, _, Ledger, _)),
    \+ member(entry(_, _, residue, _, _, _), Ledger).

%   A French twin spells each word of a name as the source's own labels
%   spell it: openfisca-france calls a variable `credit_impot_logement` and
%   labels it *Crédit d'impôt pour le logement*, so the twin's sentence reads
%   *le crédit impôt logement*. A word the labels write oftener without its
%   accent keeps the name's own spelling (`controle` here).
test(a_french_twin_takes_the_accents_of_the_labels) :-
    tmp_file(rs, D), make_directory_path(D),
    atomic_list_concat([D, '/m.yaml'], F),
    setup_call_cleanup(open(F, write, O),
        format(O, "format: rulespec/v1~nmodule:~n  title: Impôt sur le revenu~nrules:~n  - name: credit_impot_logement~n    kind: derived~n    entity: FoyerFiscal~n    dtype: Money~n    source: Crédit d'impôt pour le logement, un crédit d'impôt de plus~n    versions:~n      - effective_from: '2020-01-01'~n        formula: taux_controle * 2~n  - name: taux_controle~n    kind: parameter~n    dtype: Decimal~n    source: Taux du controle (ce controle, un contrôle)~n    versions:~n      - effective_from: '2020-01-01'~n        formula: 0.5~n", []),
        close(O)),
    atom_concat('of:', F, Id),
    with_upload([Id-F], [],
                module_migration(Id, [language(fr)], migration(_, program(_, Items), _, _))),
    once(( member(template(_, T, _), Items), sub_atom(T, _, _, _, 'crédit impôt logement') )),
    once(( member(template(_, T2, _), Items), sub_atom(T2, _, _, _, 'taux controle') )),
    delete_directory_and_contents(D).

test(an_import_that_is_not_there_becomes_inputs) :-
    tmp_file(rs, D), make_directory_path(D),
    atomic_list_concat([D, '/m.yaml'], F),
    setup_call_cleanup(open(F, write, O),
        format(O, "format: rulespec/v1~nimports:~n  - us:statutes/99/no/such~nrules:~n  - name: pay~n    kind: derived~n    entity: Person~n    dtype: Money~n    versions:~n      - effective_from: '2020-01-01'~n        formula: base * 2~n", []),
        close(O)),
    atomic_list_concat([D, '/out'], Out),
    import_rulespec(F, Out, imported(LE, Notes)),
    exists_file(LE),
    once(( member(N, Notes), sub_string(N, _, _, _, "us:statutes/99/no/such") )),
    read_file_to_string(LE, Text, []),
    sub_string(Text, _, _, _, "the base of *a person* is"),
    delete_directory_and_contents(D).

:- end_tests(rulespec_twin).

:- begin_tests(rulespec_export).

engine_built :-
    dir(D), atomic_list_concat([D, '/.cache/engine-src/target/release/axiom-rules-engine'], E), exists_file(E).

test(export_of_the_snap_twin) :-
    twin_file(snap, 'us:statutes/7/2017/a', File),
    read_file_to_string(File, Text, []), file_directory_name(File, Dir),
    le_kbs:load_text(Text, Dir, KB),
    applies_rulespec(KB),
    export_files(KB, 'us:policies/logical-english/t', M, T),
    sub_string(M, _, _, _, "  - name: snap_regular_month_allotment"),
    sub_string(M, _, _, _, "max(snap_allotment_before_minimum, snap_minimum_monthly_allotment)"),
    sub_string(M, _, _, _, "indexed_by: household_size"),
    sub_string(T, _, _, _, "us:policies/logical-english/t#snap_regular_month_allotment: 182").

test(a_value_under_conditions_only_is_refused) :-
    Text = "the target language is: prolog.\n\nthe templates are:\n    the pay of *a person* is *an amount*.\n    the base of *a person* is *an amount*.\n    *a person* is employed.\n\nthe knowledge base t includes:\n\nthe pay of a person is an amount if\n    the person is employed\n    and the base of the person is a base\n    and the amount = the base * 2.\n",
    le_kbs:load_text(Text, '.', KB),
    check_rulespec(KB, [], Problems),
    member(problem(_, M), Problems), sub_string(M, _, _, _, "only under conditions"), !.

test(round_trip_on_the_engine, [condition(engine_built)]) :-
    dir(D), atomic_list_concat([D, '/runs/roundtrip.txt'], R),
    exists_file(R), read_file_to_string(R, S, []),
    sub_string(S, _, _, _, "the engine disagrees or fails: 0").

:- end_tests(rulespec_export).

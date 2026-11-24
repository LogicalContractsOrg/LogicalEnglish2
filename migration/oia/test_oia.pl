/*  Tests of the Oracle Intelligent Advisor translator.

    ./myswipl.sh -q -g run_tests -t halt migration/oia/test_oia.pl

    Synthetic projects (tests/synthetic_xgen: a Word rule document compiled
    to .xgen; tests/synthetic_rulebase: a rulebase.xml + .stxt with an
    entity, a relationship and rule tables) exercise the reader and the
    mapping; an Excel test file made on the fly (openpyxl) runs through
    oia_tests.py into scenarios. One real project, VIBECT (when
    sources/fetch.sh has fetched it), is translated end to end and must
    keep every source test (269 expectations).
*/

:- use_module(library(plunit)).
:- use_module(library(filesex)).
:- use_module(library(process)).
:- use_module(library(lists)).
:- use_module(oia_migrate).
:- use_module(oia_reader).
:- use_module(oia_ir).
:- use_module(le2(le_migration)).

:- dynamic test_dir/1.
:- prolog_load_context(directory, D), retractall(test_dir(D)), assertz(test_dir(D)).

fixture(Name, Path) :- test_dir(D), atomic_list_concat([D, '/tests/', Name], Path).

tmp_root(Root) :-
    tmp_file(oia_test, Root), make_directory_path(Root).

%   The synthetic project's test cases, as OIA's Excel test files are: a
%   sheet "Test Cases", its columns marked by the named styles.
make_xlsx(File) :-
    Script = "import sys, openpyxl
from openpyxl.styles import NamedStyle
wb = openpyxl.Workbook(); ws = wb.active; ws.title = 'Test Cases'
for n in ['OPM - Input Heading', 'OPM - Input', 'OPM - Expected Heading', 'OPM - Expected']:
    wb.add_named_style(NamedStyle(name=n))
heads = [('Test Case', None), ('the claim was lodged in time', 'Input'), ('the product is faulty', 'Input'),
         ('the customer misused the product', 'Input'), ('the price', 'Input'),
         ('the claim is covered', 'Expected'), ('the fee', 'Expected')]
rows = [['T1', True, None, None, 1000, True, 70], ['T2', False, True, False, 200, True, 14],
        ['T3', False, True, True, 500, False, 0]]
for c, (h, role) in enumerate(heads, 1):
    cell = ws.cell(row=1, column=c, value=h)
    if role: cell.style = 'OPM - ' + role + ' Heading'
    for r, row in enumerate(rows, 2):
        v = ws.cell(row=r, column=c, value=row[c-1])
        if role: v.style = 'OPM - ' + role
wb.save(sys.argv[1])
",
    process_create(path(python3), ['-c', Script, File], [stderr(null)]).

synthetic(Kind, Name, TestFiles, Migration) :-
    fixture(Name, Dir),
    oia_read_project(Dir, Kind, syn, Model),
    oia_migrate:with_line_start(oia_migration(Model, TestFiles, [title("Synthetic")], Migration)).

ir_items(migration(_, program(_, Items), _, _), Items).

mom_fetched :- oia_migrate:cache_dir(C), atomic_list_concat([C, '/opa_demo/MOM_Paternity_Leave'], D), exists_directory(D).
warranty_fetched :- oia_migrate:cache_dir(C), atomic_list_concat([C, '/nixon/Warranty Claims (Intro)'], D), exists_directory(D).

:- begin_tests(oia_text).

test(key) :-
    oia_key('The claim’s amount is true', K), K == 'claim\'s amount'.
test(key_same_across_docs) :-
    oia_key('the  Claim is covered.', K1), oia_key('The claim is covered', K2), K1 == K2.
test(sanitize_reserved_and_punctuation) :-
    oia_sanitize('If the self-employed person\'s income (net) is 50% of A/B', T),
    T == 'in case the self employed person\'s income net is 50 percent of A or B'.
test(sanitize_keeps_decimals) :-
    oia_sanitize('the rate is 0.07.', T), T == 'the rate is 0.07'.
test(negation_after_auxiliary) :-
    oia_negation('the customer is a gold member', [], N), N == 'the customer is not a gold member'.
test(negation_from_oracle_parse) :-
    oia_negation('the claim occurred within 8 months',
                 [parse(s(ver('12'), v(occur, t(simple, past, normal)), sb('the claim', singular), o('')))], N),
    N == 'the claim did not occur within 8 months'.
test(negation_authored_form_first) :-
    oia_negation('the reference is missing', [negative('The reference is present.')], N),
    N == 'the reference is present'.

:- end_tests(oia_text).

:- begin_tests(oia_xgen).

test(reader) :-
    fixture(synthetic_xgen, Dir),
    oia_read_project(Dir, xgen, syn, oia(_, Attrs, Rules, Docs)),
    memberchk(attr('price', 'the price', currency, global, _), Attrs),
    memberchk(rule('0', 'Synthetic Rules.docx', _, '1',
                   conclude('claim is covered', global, true,
                            or([att('claim was lodged in time'),
                                and([att('product is faulty'), not(att('customer misused the product'))])]),
                            false)), Rules),
    memberchk(rule('1', _, _, _, conclude(fee, global, mul(att(price), num(0.07)), att('claim is covered'), num(0))), Rules),
    memberchk(doc('Synthetic Rules.docx', Paras), Docs), length(Paras, 7).

test(nested_levels_numbered_negation_written) :-
    synthetic(xgen, synthetic_xgen, [], M), ir_items(M, Items),
    member(rule(_, B, Opts), Items), memberchk(label(synthetic_rules_r0), Opts), !,
    B = or(_, and(_, not(_))),
    memberchk(numbered(true), Opts),
    memberchk(label(synthetic_rules_r0), Opts).

test(decimal_as_fraction_relational_arithmetic) :-
    synthetic(xgen, synthetic_xgen, [], M), ir_items(M, Items),
    member(rule(H, otherwise([B1, _]), _), Items), H =.. [_, F], !,
    once(sub_term(F is (_ * 7) / 100, B1)).

test(excel_tests_as_scenarios, [setup(tmp_root(Root)), cleanup(delete_directory_and_contents(Root))]) :-
    atomic_list_concat([Root, '/TC_Synthetic.xlsx'], X),
    make_xlsx(X),
    synthetic(xgen, synthetic_xgen, [X], M),
    M = migration(_, _, _, Tests), length(Tests, 3),
    fixture(synthetic_xgen, Dir), oia_read_project(Dir, xgen, syn, Model),
    atomic_list_concat([Root, '/syn'], Out), make_directory_path(Out),
    oia_migrate:write_doc_texts(Model, Out),
    oia_migrate:with_line_start(write_migration(M, Out, syn, report(_, Issues, _, Fidelity))),
    \+ memberchk(issue(error, _, _), Issues),
    Fidelity = fidelity(6, 0, 0, _).

:- end_tests(oia_xgen).

:- begin_tests(oia_rulebase).

test(reader_entities) :-
    fixture(synthetic_rulebase, Dir),
    oia_read_project(Dir, rulebase, syn, oia(_, Attrs, Rules, Docs)),
    memberchk(attr('error code', 'the error code', text, 'e-1', _), Attrs),
    memberchk(entity('e-1', 'the error', 'error code'), Docs),
    memberchk(relationship(r_err, global, 'e-1', _), Docs),
    memberchk(rule(2, _, _, _, table(global, _, [concl(rel(r_err), [str("E-1"), str("E-2")])])), Rules).

test(global_table_is_decision_table) :-
    synthetic(rulebase, synthetic_rulebase, [], M), ir_items(M, Items),
    %  named after what it concludes, its columns after the attributes they test
    memberchk(table(rate_table, [policy(first)|_], [row, type, rate], Rows), Items),
    Rows = [[r1, "A", 1], [r2, "B", 2], [r3, any, 0]].

test(relationship_table_infers_instances_every_row) :-
    synthetic(rulebase, synthetic_rulebase, [], M), ir_items(M, Items),
    member(rule(H, or(_, _), Opts), Items), memberchk(label(rulebase_r2), Opts), !,
    functor(H, _, 1).

test(entity_table_per_instance) :-
    synthetic(rulebase, synthetic_rulebase, [], M), ir_items(M, Items),
    member(rule(H, and(IG, TG), Opts), Items), memberchk(label(rulebase_r3), Opts), !,
    H =.. [_, X, V], IG =.. [_, X1], X1 == X, TG =.. [_, X2, V2], X2 == X, V2 == V.

test(written_without_errors, [setup(tmp_root(Root)), cleanup(delete_directory_and_contents(Root))]) :-
    synthetic(rulebase, synthetic_rulebase, [], M),
    oia_migrate:with_line_start(write_migration(M, Root, syn, report(_, Issues, counts(_, _, 0), _))),
    \+ memberchk(issue(error, _, _), Issues).

:- end_tests(oia_rulebase).

:- begin_tests(oia_real).

vibect_fetched :- oia_migrate:cache_dir(C), atomic_list_concat([C, '/oia-dmn-tree/example/VIBECT/rulebase.xml'], F), exists_file(F).

test(vibect_end_to_end, [condition(vibect_fetched), setup(tmp_root(Root)), cleanup(delete_directory_and_contents(Root))]) :-
    migrate(vibect, Root, report(_, Issues, counts(_, _, Residue), fidelity(Pass, Fail, Errors, _))),
    \+ memberchk(issue(error, _, _), Issues),
    Residue == 0, Pass == 269, Fail == 0, Errors == 0.


%   The MOM project ships no tests: two hand-made cases check the date
%   arithmetic path (addmonths(date of birth of child, -3) -> lib/temporal).
test(mom_temporal_path, [condition(mom_fetched), setup(tmp_root(Root)), cleanup(delete_directory_and_contents(Root))]) :-
    migrate(mom_paternity_leave, Root, report(File, Issues, _, _)),
    \+ memberchk(issue(error, _, _), Issues),
    Case = "~nscenario ~w is:~n    the Nationality of the Child is \"SG\".~n    the marriage status is \"MARRIED\".~n    the employment status of the Father is \"EMPLOYED\".~n    the last employment start date of the Father is ~w.~n    date of birth of child is 2017-06-01.~n    the date of birth is 2017-06-01.~n    the Father fulfils the minimum work period.~n    number of working days a week is 5.~n    q_days_gppl_father_entitled_to expects [~w].~n",
    setup_call_cleanup(open(File, append, S),
                       ( format(S, Case, [served, '2016-01-01', '"days of GPPL the Father is entitled to is 10"']),
                         format(S, Case, [too_recent, '2017-04-01', '']) ),
                       close(S)),
    le_kbs:runTestsFor(File, test_file(_, Results)),
    memberchk(pass(_, served), Results),
    memberchk(pass(_, too_recent), Results).

%   The roles of the global entity: "the Father" is a typed place of the
%   templates that speak about him, and a named constant (`the constants
%   are:`) that the rules keep using — what `; defines global` used to say
%   before LE2 removed it.
test(mom_roles, [condition(mom_fetched)]) :-
    oia_migrate:project(mom_paternity_leave, Rel, Kind, _, _),
    oia_migrate:cache_dir(C), atomic_list_concat([C, '/', Rel], Dir),
    oia_read_project(Dir, Kind, mom, Model),
    oia_migrate:with_line_start(oia_migration(Model, [], [], migration(_, program(_, Items), _, Tests))),
    memberchk(constant(_, 'the Father', "the Father"), Items),
    memberchk(template(_, 'the employment status of *a father* is *a status*', _), Items),
    memberchk(template(_, '*a child* is a Singapore citizen', _), Items),
    %  no source tests: the rules' own analysis, cited as such
    Tests = [test(_, 'the analysis of the rules', _, _, _)|_],
    length(Tests, N), N > 10.

:- end_tests(oia_real).

:- begin_tests(oia_analysis).

:- use_module(oia_analysis).

%   Warranty Claims: three ways to a covered claim, two to a discount; each
%   path holds its goal, each near miss (the requirement flipped) does not —
%   as the analysis' own evaluator says, and as the written twin answers.

test(warranty_paths, [condition(warranty_fetched)]) :-
    oia_migrate:project(warranty_claims, Rel, Kind, _, _),
    oia_migrate:cache_dir(C), atomic_list_concat([C, '/', Rel], Dir),
    oia_read_project(Dir, Kind, w, Model),
    analysis_cases(Model, [], [], Cases),
    include([case(Id, _, _, _)]>>sub_atom(Id, _, _, 0, '_path_1'), Cases, P1),
    length(P1, 2),
    forall(( member(case(Id, _, _, Out), Cases), \+ sub_atom(Id, _, _, _, miss) ),
           ( member(_-true, Out) )),
    forall(( member(case(Id, _, In, Out), Cases), sub_atom(Id, _, _, _, miss) ),
           ( \+ member(true, [])  , In \== [], Out \== [] )).

test(warranty_twin_agrees, [condition(warranty_fetched), setup(tmp_root(Root)), cleanup(delete_directory_and_contents(Root))]) :-
    migrate(warranty_claims, Root, report(_, _, _, fidelity(Pass, Fail, Errors, _))),
    Pass >= 20, Fail == 0, Errors == 0.

%   The evaluator: three-valued, first match in a table.
test(evaluator_three_valued) :-
    Model = oia(m, [attr(a, 'the a', boolean, global, []), attr(b, 'the b', boolean, global, []),
                    attr(g, 'the g', boolean, global, [])],
                [rule('1', d, g, none, conclude(g, global, true, and([att(a), not(att(b))]), false))], []),
    oia_eval_goal(Model, [a-true, b-false], g, V1), V1 == true,
    oia_eval_goal(Model, [a-true], g, V2), V2 == unknown,
    oia_eval_goal(Model, [a-false], g, V3), V3 == false.

%   Generated expectations print numbers as LE does: a whole-number result
%   of decimal arithmetic is 70, not 70.0; exact decimals, not 70.35000000000001.
test(evaluator_numbers_as_le_prints_them) :-
    Model = oia(m, [attr(p, 'the price', currency, global, []), attr(f, 'the fee', currency, global, [])],
                [rule('1', d, f, none, conclude(f, global, mul(att(p), num(0.07)), true, num(0)))], []),
    oia_eval_goal(Model, [p-num(1000)], f, V1), V1 == num(70),
    oia_eval_goal(Model, [p-num(1005)], f, V2), V2 == num(70.35).

%   A project with no test files: the generated scenarios pass on the twin.
test(import_no_tests_numbers_agree, [setup(tmp_root(Root)), cleanup(delete_directory_and_contents(Root))]) :-
    fixture(synthetic_xgen, Dir),
    atomic_list_concat([Dir, '/bin/Synthetic Rules.docx.xgen'], X),
    oia_import:import_oia(X, Root, imported(LE, _)),
    read_file_to_string(LE, T, []),
    \+ sub_string(T, _, _, _, "70.0\""),
    le_kbs:runTestsFor(LE, test_file(_, Rs)), Rs \== [],
    forall(member(R, Rs), R = pass(_, _)), !.

:- end_tests(oia_analysis).

:- begin_tests(oia_import).

:- use_module(oia_import).

%   File ▸ Open: a project folder as an extracted archive, and a single
%   compiled rule document.
test(import_project_folder, [condition(warranty_fetched), setup(tmp_root(Root)), cleanup(delete_directory_and_contents(Root))]) :-
    oia_migrate:cache_dir(C), atomic_list_concat([C, '/nixon/Warranty Claims (Intro)'], Src),
    atomic_list_concat([Root, '/in/Warranty Claims (Intro)'], In),
    atomic_list_concat([Root, '/out'], Out),
    make_directory_path(In), make_directory_path(Out),
    copy_directory(Src, In),
    atomic_list_concat([Root, '/in'], Upload),
    detect_oia(Upload),
    import_oia(Upload, Out, imported(LE, Notes)),
    exists_file(LE), file_base_name(LE, 'warranty_claims_intro.le'),
    Notes \== [],
    le_kbs:runTestsFor(LE, test_file(_, Rs)), Rs \== [],
    forall(member(R, Rs), R = pass(_, _)), !.

test(import_single_xgen, [condition(mom_fetched), setup(tmp_root(Root)), cleanup(delete_directory_and_contents(Root))]) :-
    oia_migrate:cache_dir(C),
    atomic_list_concat([C, '/opa_demo/MOM_Paternity_Leave/bin/MOM_Paternity_Leave Rules.docx.xgen'], Src),
    atomic_list_concat([Root, '/in'], In), atomic_list_concat([Root, '/out'], Out),
    make_directory_path(In), make_directory_path(Out),
    atomic_list_concat([In, '/MOM_Paternity_Leave Rules.docx.xgen'], F), copy_file(Src, F),
    detect_oia(F),
    import_oia(F, Out, imported(LE, _)),
    read_file_to_string(LE, T, []),
    once(sub_string(T, _, _, _, "the Father is \"the Father\".")),
    atomic_list_concat([Out, '/temporal.le'], Lib), exists_file(Lib).

%   An .xgen that cannot be read becomes a TODO in the program, not a
%   failed import.
test(import_unreadable_document_is_todo, [setup(tmp_root(Root)), cleanup(delete_directory_and_contents(Root))]) :-
    fixture(synthetic_xgen, Src),
    atomic_list_concat([Root, '/in/proj'], In), atomic_list_concat([Root, '/out'], Out),
    make_directory_path(In), make_directory_path(Out),
    copy_directory(Src, In),
    atomic_list_concat([In, '/bin/Broken.docx.xgen'], B),
    setup_call_cleanup(open(B, write, S), format(S, "<root><rules><rule", []), close(S)),
    catch(import_oia(In, Out, imported(LE, _)), _, fail),
    read_file_to_string(LE, T, []),
    once(sub_string(T, _, _, _, "TODO")),
    once(sub_string(T, _, _, _, "Broken.docx.xgen")).

test(detect_rejects_other_material, [setup(tmp_root(Root)), cleanup(delete_directory_and_contents(Root))]) :-
    atomic_list_concat([Root, '/x.json'], F),
    setup_call_cleanup(open(F, write, S), format(S, "{}", []), close(S)),
    \+ detect_oia(F),
    \+ detect_oia(Root).

:- end_tests(oia_import).


		 /*******************************
		 *   RULE TEXT (Word, ruletxt,  *
		 *   Hub JSON), ENTITIES        *
		 *******************************/

%   Added 15 October 2026 with the second corpus (README.md, "The second
%   corpus"): the rules as authors write them, entity functions, chains of
%   inferred instances, Assess exchanges as tests.

:- begin_tests(oia_rule_text).

:- use_module(oia_text).
:- use_module(oia_assess).

cache(Rel, Dir) :- oia_migrate:cache_dir(C), atomic_list_concat([C, '/', Rel], Dir).
extra(Rel, Dir) :- oia_migrate:extra_path(Rel, Dir).
extra_there(Rel) :- extra(Rel, F), exists_file(F).
fetched(Rel) :- cache(Rel, D), exists_directory(D).

%   A rule's shape with citations and inline conclusions left out, and/or
%   lists flattened and sorted: what the Word document and Policy Modeling's
%   compilation of it must agree on.
norm(cite(_, E), N) :- !, norm(E, N).
norm(and(L), N) :- !, maplist(norm, L, L1), flatten_op(and, L1, L2), ( L2 = [X] -> N = X ; msort(L2, L3), N = and(L3) ).
norm(or(L), N) :- !, maplist(norm, L, L1), flatten_op(or, L1, L2), ( L2 = [X] -> N = X ; msort(L2, L3), N = or(L3) ).
norm(inline(conclude(K, _, _, _, _)), att(K)) :- !.
norm(num(X), num(Y)) :- !, Y is X * 1.0.
norm(T, N) :- compound(T), !, T =.. [F|As], maplist(norm, As, Bs), N =.. [F|Bs].
norm(T, T).
flatten_op(Op, L, Out) :- foldl({Op}/[E, A0, A]>>( E =.. [Op, S] -> append(A0, S, A) ; append(A0, [E], A) ), L, [], Out).

rule_shapes(oia(_, _, Rs, _), Shapes) :-
    findall(K-c(V, C, E), ( member(rule(_, _, _, _, conclude(K, _, V0, C0, E0)), Rs),
                            norm(V0, V), norm(C0, C), norm(E0, E) ), Shapes).

%   Every rule Oracle compiled from MOM's Word document, read again from the
%   Word document itself.
test(word_equals_oracle_compilation, [condition(fetched('opa_demo/MOM_Paternity_Leave'))]) :-
    cache('opa_demo/MOM_Paternity_Leave', Dir),
    read_model(Dir, xgen, mom, MX), read_model(Dir, docx, mom, MT),
    rule_shapes(MX, SX), rule_shapes(MT, ST),
    forall(member(S, SX), memberchk(S, ST)).

test(ruletxt_table_cascade_and_switched_off_lines, [condition(fetched('ministryofjustice_laa-ccms-opa-feedback-form-v23-ruletxt'))]) :-
    cache('ministryofjustice_laa-ccms-opa-feedback-form-v23-ruletxt', Dir),
    oia_read_text_project(ruletxt(Dir), laa, oia(_, _, Rs, _)),
    member(rule(_, _, _, _, table(_, [col(none, Cells)], [concl('parent form', Vals)])), Rs), !,
    length(Cells, 4), last(Cells, empty), last(Vals, str("Not known")),
    %  "the new PUI questions are displayed": the active line only
    memberchk(rule(_, _, _, _, conclude('new pui questions are displayed', _, true, Cond, _)), Rs),
    Cond = eq(att('parent form name from load'), str("_beta")).

test(hub_table_boolean_cells, [condition(fetched(oracle_ds))]) :-
    cache('oracle_ds/doINeedToFile.json', F),
    oia_read_text_project(hub(F), ds, oia(_, As, Rs, _)),
    memberchk(attr('person exceeds the income threshold', _, boolean, _, _), As),
    member(rule(_, _, _, _, table(global, [col(att('person\'s filing status'), _)], [concl(_, Vals)])), Rs), !,
    Vals = [cond(gt(att('person\'s gross income'), num(12950)))|_].

%   (Oracle's Assess exchanges of Simple Benefits may not be published: they
%   are in the private place, oia_migrate:extra_path/2, and the test that
%   replays them is skipped without them)
test(entity_functions_and_assess_tests, [condition(extra_there('simple_benefits/assess/oracle_10_4_request.xml')),
                                         setup(tmp_root(Root)), cleanup(delete_directory_and_contents(Root))]) :-
    migrate(simple_benefits, Root, report(File, _, _, fidelity(P, 0, 0, _))),
    P >= 18,
    read_file_to_string(File, S, []),
    sub_string(S, _, _, _, "is the count of each"),
    sub_string(S, _, _, _, "is one of the claimant's children").

test(for_all_and_tables, [setup(tmp_root(Root)), cleanup(delete_directory_and_contents(Root))]) :-
    migrate(social_services_screening, Root, report(File, _, _, fidelity(_, 0, 0, _))),
    read_file_to_string(File, S, []),
    sub_string(S, _, _, _, "for all cases in which").

test(chain_of_inferred_instances, [condition(fetched(loan_advisor))]) :-
    cache(loan_advisor, Dir),
    read_model(Dir, rulebase, la, M),
    oia_migrate:with_line_start(oia_migration(M, [], [analysis(false)], migration(_, program(_, Items), _, _))),
    memberchk(template(_, 'the payments from *a payment* are *a list*', [memorable]), Items),
    once(( member(rule(H, _, O), Items), memberchk(label(L), O), sub_atom(L, _, _, 0, '_chain_end') )),
    compound(H).

test(assess_exchange_as_case, [condition(extra_there('simple_benefits/assess/oracle_12_2_tutorial_request.xml'))]) :-
    extra('simple_benefits/assess/oracle_12_2_tutorial_request.xml', Req),
    extra('simple_benefits/assess/oracle_12_2_tutorial_response.xml', Resp),
    assess_soap_case(Req, Resp, C),
    get_dict(claimant_income, C.inputs, 13000.0),
    get_dict(child, C.inputs, [_, _]),
    get_dict(low_income_allowance_payment, C.expected, 70.0).

test(string_literal_spaces_kept, [condition(fetched('moj_check_answers/CheckAnswers'))]) :-
    cache('moj_check_answers/CheckAnswers', Dir),
    forall(member(K, [xgen, docx]),
           ( read_model(Dir, K, ca, oia(_, _, Rs, _)),
             once(( member(rule(_, _, _, _, T), Rs), sub_term(str("  <div>    <dt class='cya-question'>      "), T) )) )).

:- end_tests(oia_rule_text).

		 /*******************************
		 *         THE ADAPTER          *
		 *******************************/

:- begin_tests(oia_adapter).

:- use_module(oia_adapter).
:- use_module(oia_assess).

mapped(Name) :-
    le2_paths:private_root(R),
    atomic_list_concat([R, '/examples/migration/oia/', Name, '/', Name, '.oia_map.json'], F),
    exists_file(F).


test(decision_service_contract, [condition(mapped(do_i_need_to_file))]) :-
    oia_decide(doINeedToFile, _{filing_status: "Single", gross_income: 13000}, contract, [], R1),
    get_dict(tax_return_needed, R1.outputs, true),
    oia_decide('do_i_need_to_file', _{filing_status: "Married filing jointly", gross_income: 15000,
                                      spouses_gross_income: 10000}, contract, [], R2),
    get_dict(tax_return_needed, R2.outputs, false).

%   Oracle's published 12.2 tutorial case, through the adapter: Oracle's
%   published answers, with a decision report.
test(oracle_published_case_with_report, [condition(mapped(simple_benefits))]) :-
    oia_decide('SimpleBenefits',
               _{claimant_income: 13000, claimant_public_housing_client: true,
                 claimantschildren: [_{'@id': "child1", child_age: 16}, _{'@id': "child2", child_age: 8}]},
               [eligible_low_income_allowance, low_income_allowance_payment, eligible_teenage_allowance],
               [reports([low_income_allowance_payment])], R),
    get_dict(eligible_low_income_allowance, R.outputs, true),
    get_dict(low_income_allowance_payment, R.outputs, 70),
    get_dict(eligible_teenage_allowance, R.outputs, true),
    get_dict(low_income_allowance_payment, R.reports, Rep),
    sub_string(Rep.text, _, _, _, "70").

test(lookup_table_dates, [condition(mapped(taxpayer_information))]) :-
    oia_decide(taxpayerInformation, _{theCustomerID: "5555"}, contract, [], R),
    get_dict(date_of_birth, R.outputs, "1990-02-02"),
    oia_decide(taxpayerInformation, _{theCustomerID: "9999"}, contract, [], R2),
    get_dict(filing_status, R2.outputs, null).

%   A chain of inferred instances (Loan Advisor's 361 payments) answered
%   through the decision service: the outcomes of one case share their
%   remembered answers (reasoner:with_shared_memo/1), so the schedule is
%   worked out once, not once per outcome (20 October 2026: 25 s a case
%   before, about 2 s after). The values are tests.json's.
test(chain_outcomes_share_the_schedule, [condition(mapped(loan_advisor))]) :-
    oia_decide(loan_advisor,
               _{loan_type: "Home", loan_purchase_price: 500000, loan_down_payment: 100000,
                 loan_interest_rate: 6, customer_age: 34, customer_employed: true,
                 customer_resident: true, customer_job_period: "2 years or more",
                 assets: [_{'@id': "asset_1", asset_name: "savings account", asset_type: "Cash", asset_value: 60000}],
                 liabilities: [_{'@id': "liability_1", liability_name: "car loan", liability_type: "Loan", liability_value: 15000}],
                 income_sources: [_{'@id': "income_1", income_source_name: "salary", income_source_amount: 96000,
                                    income_source_frequency: "per year"}]},
               contract, [], R),
    get_dict(total_interest, R.outputs, 463353),
    get_dict(loan_duration, R.outputs, "30 yrs 1 mths"),
    get_dict(goal_eligible, R.outputs, true).

test(swagger, [condition(mapped(do_i_need_to_file))]) :-
    oia_swagger(doINeedToFile, S),
    S.swagger == "2.0",
    get_dict(filing_status, S.definitions.input.properties, _),
    get_dict(tax_return_needed, S.definitions.output.properties, _).

test(soap_response_round_trip) :-
    assess_soap_response('12.2', [result(x, boolean, true, none), result(y, currency, 70, none)], XML),
    soap_assess_dom(XML, DOM),
    sub_term(element(_, A, _), DOM), memberchk(id=y, A), !.

:- end_tests(oia_adapter).

%   The editor's File ▸ Open and Import from Another System reach the
%   translator only through the extensions of its row in
%   migration/le_importers.pl: each kind of file detect_oia/1 recognises must
%   be there (Word, .ruletxt and Hub JSON were missing until 19 October 2026,
%   so such an upload fell back to a TODO comment).
:- begin_tests(oia_registry).

test(every_detected_kind_is_registered) :-
    once(le_import:importer(oia, _, Exts, _, _, _)),
    forall(member(E, [docx, json, ruletxt, xgen, xprj, xml, stxt, zip]),
           assertion(memberchk(E, Exts))).

oracle_sample_fetched(F) :-
    oia_migrate:cache_dir(C),
    atomic_list_concat([C, '/oracle_ds/doINeedToFile.json'], F),
    exists_file(F).

test(hub_json_upload_is_translated, [condition(oracle_sample_fetched(_)),
                                     setup(tmp_root(Root)), cleanup(delete_directory_and_contents(Root))]) :-
    oracle_sample_fetched(F),
    read_file_to_string(F, Text, []),
    le_import:import_upload("doINeedToFile.json", text(Text), R, [root(Root)]),
    assertion(R.importer == "Oracle Intelligent Advisor project or rulebase"),
    assertion(sub_string(R.document, _, _, _, "the person exceeds the income threshold if")),
    assertion(\+ sub_string(R.document, _, _, _, "% TODO: translate")).

:- end_tests(oia_registry).

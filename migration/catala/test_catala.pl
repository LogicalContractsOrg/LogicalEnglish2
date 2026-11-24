/*  Tests of the Catala translator (Phase 3c).

        ./myswipl.sh -q -g run_tests -t halt migration/catala/test_catala.pl
*/
:- use_module('../le2_paths').
:- use_module(le2(le_kbs)).
:- use_module(catala_reader).
:- use_module(catala_lower).
:- use_module(catala_import).
:- use_module(catala_export).

dir(D) :- module_property(catala_reader, file(F)), file_directory_name(F, D).
examples(E) :- dir(D), atomic_list_concat([D, '/.cache/catala-examples'], E).
have_examples :- examples(E), exists_directory(E).
twin(P, F) :- twins_dir(catala, D), atomic_list_concat([D, '/', P, '/', P, '.le'], F), exists_file(F).

:- begin_tests(catala_reader).

test(english_scope) :-
    read_catala_text(en, "# T\n\n```catala\ndeclaration scope S:\n  input x content money\n  output y content money\n\nscope S:\n  label base definition y equals x * 20%\n  exception base definition y under condition x > $1,000 consequence equals $0\n```\n", Items),
    memberchk(code(code, CIs, _), Items),
    memberchk(scope_decl('S', [var(x, input, false, prim(money), [], [], _), var(y, internal, true, prim(money), [], [], _)], [], _), CIs),
    memberchk(scope_use('S', none, [def(base, none, [y], [], none, none, binop(mult, id([], x, none), lit(percent(20))), _),
                                    def(none, to(base), [y], [], none, binop(gt, id([], x, none), lit(money(100000))), lit(money(0)), _)], [], _), CIs).

test(french_scope) :-
    read_catala_text(fr, "```catala\nchamp d'application Smic:\n  définition brut_horaire sous condition résidence = Mayotte et date_courante >= |2019-01-01| conséquence égal à 7,57 €\n```\n", Items),
    memberchk(code(code, [scope_use('Smic', none, [def(none, none, [brut_horaire], [], none, C, lit(money(757)), _)], [], _)], _), Items),
    C = binop(and, binop(eq, id([], 'résidence', none), inject([], 'Mayotte', none)), binop(gte, id([], date_courante, none), lit(date(2019, 1, 1)))).

test(corpus_files, [condition(have_examples)]) :-
    examples(E),
    forall(member(F, ['us_tax_code/section_121.catala_en', 'smic/Smic.catala_fr', 'allocations_familiales/securite_sociale_L.catala_fr']),
           ( atomic_list_concat([E, '/', F], P), read_catala_file(P, catala(_, [_|_])) )).

:- end_tests(catala_reader).

:- begin_tests(catala_lower, [condition(have_examples)]).

test(section_132) :-
    examples(E),
    atomic_list_concat([E, '/us_tax_code/section_132.catala_en'], F1),
    atomic_list_concat([E, '/us_tax_code/tests/test_section_132.catala_en'], F2),
    lower_programme(section_132, [F1, F2], ['QualifiedEmployeeDiscount'], module(Rules, Tests, _)),
    length(Tests, 3),
    member(R, Rules), get_dict(name, R, qualified_employee_discount), !,
    get_dict(versions, R, [V]), get_dict(formula, V, F),
    sub_string(F, 0, _, _, "(if (is_property)").

:- end_tests(catala_lower).

:- begin_tests(catala_twins).

test(section_132, [condition(twin(section_132, _)), true(F == 0)]) :-
    twin(section_132, File), runTestsFor(File, R), test_counts(R, P, F), P > 0.
test(smic_in_french, [condition(twin(smic, _)), true(F == 0)]) :-
    twin(smic, File), read_file_to_string(File, T, []),
    sub_string(T, _, _, _, "le brut horaire est *un montant*"),
    runTestsFor(File, R), test_counts(R, P, F), P > 0.

test_counts(R, P, F) :-
    term_to_atom(R, A),
    aggregate_all(count, sub_atom(A, _, _, _, 'passed('), P0),
    aggregate_all(count, sub_atom(A, _, _, _, 'failed('), F0),
    ( P0 + F0 > 0 -> P = P0, F = F0 ; findall(x, sub_atom(A, _, _, _, pass), Ps), length(Ps, P), F = 0 ).

:- end_tests(catala_twins).

:- begin_tests(catala_import, [condition(have_examples)]).

test(open_section_132) :-
    examples(E), tmp_file(cat, Up), make_directory_path(Up),
    forall(member(F, ['us_tax_code/section_132.catala_en', 'us_tax_code/tests/test_section_132.catala_en']),
           ( atomic_list_concat([E, '/', F], From), file_base_name(F, B), atomic_list_concat([Up, '/', B], To), copy_file(From, To) )),
    tmp_file(out, Out), make_directory_path(Out),
    import_catala(Up, Out, imported(LE, [N|_])),
    exists_file(LE),
    sub_string(N, _, _, _, "8 pass, 0 fail"),
    delete_directory_and_contents(Up), delete_directory_and_contents(Out).

:- end_tests(catala_import).

:- begin_tests(catala_export).

test(section_132_as_catala, [condition(twin(section_132, _))]) :-
    twin(section_132, File), read_file_to_string(File, Text, []), file_directory_name(File, Dir),
    le_kbs:load_text(Text, Dir, KB),
    catala_module(KB, M, T),
    sub_string(M, _, _, _, "declaration scope Program:"),
    sub_string(M, _, _, _, "else impossible"),
    sub_string(M, _, _, _, "declaration enumeration DiscountTypeCode:"),
    sub_string(T, _, _, _, "assertion program.qualified_employee_discount = 500.0").

:- end_tests(catala_export).

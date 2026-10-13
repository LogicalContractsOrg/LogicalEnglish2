/** <module> A spreadsheet as a service: the sheet: address (language.md §17.6)

    A template backed by `sheet:<workbook>` is answered by the workbook in
    the program's folder, evaluated by services/sheet/sheet_service.mjs under
    Node, in the cells the program names in `the cells of service <name>
    are:` (le_sheet_cells.pl). The example is
    examples/regulatory/medicare/vitamin_d_bmi.le. The tests that ask the
    workbook are skipped where Node or the sheet engine's packages are
    missing; those of the declarations and their issues always run.

    Run with:  swipl -q -g run_tests -t halt testing/test_sheet_service.pl
*/

:- module(test_sheet_service, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_services').

engine_ready :-
    absolute_file_name(path(node), _, [access(execute), file_errors(fail)]),
    module_property(le_services, file(F)), file_directory_name(F, D),
    atomic_list_concat([D, '/services/sheet/node_modules/formualizer'], M),
    exists_directory(M).

example(F) :-
    module_property(le_services, file(L)), file_directory_name(L, D),
    atomic_list_concat([D, '/examples/regulatory/medicare/vitamin_d_bmi.le'], F).

:- begin_tests(sheet_service, [condition(engine_ready)]).

test(answer_from_the_workbook) :-
    example(F),
    load(F, KB, [skip_tests]),
    createSession(KB, SM),
    setScenarion(SM, obesity_class_three),
    findall(C, reasoner:i(the_diagnosis_code_of_is('Ann', C), SM, _, _), Cs),
    destroySession(SM),
    assertion(Cs == ['Z68.41']).

test(address_resolved_inside_the_folder_only) :-
    example(F), load(F, KB, [skip_tests]),
    le_services:resolve_address(KB, 'sheet:sources/bmi/adult_bmi.xlsx', A1),
    assertion(sub_atom(A1, _, _, 0, '/examples/regulatory/medicare/sources/bmi/adult_bmi.xlsx')),
    le_services:resolve_address(KB, 'sheet:../../../le_kbs.pl', A2),
    assertion(A2 == 'sheet:../../../le_kbs.pl').

%   A fixed cell: the height is the workbook's for every question.
test(fixed_cell) :-
    folder(D),
    load_text("the target language is: prolog.

the knowledge base fixed height includes these services:
    bmi at sheet:sources/bmi/adult_bmi.xlsx as a calculator.

the templates are:
    the code for *a number* kg is *a code*; via service bmi.

the cells of service bmi are:
    the code for \"'BMI'!B1\" kg is \"'BMI'!B4\".
    the cell \"'BMI'!B2\" is 170.
", D, KB),
    createSession(KB, SM),
    findall(C, reasoner:i(the_code_for_kg_is(118, C), SM, _, _), Cs),
    destroySession(SM),
    assertion(Cs == ['Z68.41']).

:- end_tests(sheet_service).

folder(D) :-
    example(F), file_directory_name(F, D).

cells_issues(KB, Types) :-
    findall(T, ( KB:le_issue(_, T, _, _, _, _),
                 ( sub_atom(T, 0, _, _, cells_) ; sub_atom(T, 0, _, _, sheet_) ) ), Ts),
    msort(Ts, Types).

:- begin_tests(sheet_cells).

test(cells_of_the_example) :-
    example(F), load(F, KB, [skip_tests]),
    le_sheet_cells:sheet_cells(KB, bmi, 'the_ICD10_code_of_the_BMI_of_kg_and_cm_is'/3, Cells),
    dict_pairs(Cells, _, Pairs),
    assertion(Pairs == [fixed-[], inputs-["B1", "B2"], output-"B4", sheet-"BMI"]),
    cells_issues(KB, Issues),
    assertion(Issues == []).

test(issues) :-
    folder(D),
    load_text("the target language is: prolog.

the knowledge base faults includes these services:
    bmi at sheet:sources/bmi/adult_bmi.xlsx as a calculator,
    old at sheet:sources/bmi/adult_bmi.xlsx#bmi as a calculator,
    gone at sheet:sources/none.xlsx as a calculator.

the templates are:
    the code of *a number* and *a number* is *a code*; via service bmi.
    the class of *a number* is *a class*; via service bmi.
    the colour of *a thing* is *a colour*.

the cells of service bmi are:
    the sheet is \"BMI\".
    the code of \"B1\" and \"B2\" is \"B4\".
    the code of \"B1\" and \"B2\" is \"B3\".
    the colour of \"A1\" is \"A2\".
    the class of \"nowhere\" is \"B3\".
    whatever this is.
    the cell \"Z\" is 3.

the cells of service nobody are:
    the code of \"B1\" and \"B2\" is \"B4\".
", D, KB),
    cells_issues(KB, Issues),
    assertion(Issues == [cells_missing, cells_not_a_cell, cells_not_a_cell, cells_not_backed,
                         cells_not_backed, cells_twice, cells_unknown_sentence,
                         cells_unknown_service, sheet_address_port, sheet_no_workbook]).

%   The section is written in the program's language.
test(portuguese) :-
    folder(D),
    load_text("a linguagem alvo é: prolog.

a base de conhecimento imc inclui estes serviços:
    imc em sheet:sources/bmi/adult_bmi.xlsx como uma calculadora.

os modelos são:
    o código de *um número* kg e *um número* cm é *um código*; via serviço imc.

as células do serviço imc são:
    a folha é \"BMI\".
    o código de \"B1\" kg e \"B2\" cm é \"B4\".
", D, KB),
    cells_issues(KB, Issues),
    assertion(Issues == []),
    once(le_sheet_cells:sheet_cells(KB, imc, F/3, Cells)),
    assertion(atom(F)),
    assertion(Cells.inputs == ["B1", "B2"]).

:- end_tests(sheet_cells).

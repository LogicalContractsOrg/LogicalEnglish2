/** <module> A spreadsheet as a service: the sheet: address (language.md §17.6)

    A template backed by `sheet:<workbook>#<output>` is answered by the
    workbook beside the program, through the SheetPort manifest beside it,
    evaluated by services/sheet/sheet_service.mjs under Node. The example is
    examples/regulatory/medicare/vitamin_d_bmi.le. Skipped where Node or the
    sheet engine's packages are missing.

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
    le_services:resolve_address(KB, 'sheet:sources/bmi/adult_bmi.xlsx#bmi', A1),
    assertion(sub_atom(A1, _, _, 0, '/examples/regulatory/medicare/sources/bmi/adult_bmi.xlsx#bmi')),
    le_services:resolve_address(KB, 'sheet:../../../le_kbs.pl', A2),
    assertion(A2 == 'sheet:../../../le_kbs.pl').

:- end_tests(sheet_service).

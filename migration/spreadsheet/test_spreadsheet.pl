/*  Tests of the spreadsheet importer (the design notes Excel.md §7.2).

    swipl -g run_tests -t halt test_spreadsheet.pl

    Needs Node and LE2's sheet engine (services/sheet: npm ci). The fixture
    testdata/tax.xlsx is written by testdata/make_fixtures.py.
*/

:- use_module(library(plunit)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module(xlsx_import).
:- use_module(xlsx_ir).

fixture_named(N, F) :-
    module_property(xlsx_import, file(M)), file_directory_name(M, D),
    atomic_list_concat([D, '/testdata/', N], F).

fixture(F) :-
    module_property(xlsx_import, file(M)), file_directory_name(M, D),
    atomic_list_concat([D, '/testdata/tax.xlsx'], F).

:- begin_tests(spreadsheet_labels).

test(numbering_and_brackets) :-
    xlsx_ir:label_words("3-1-B. Earned Income Deduction (see §364.400)", W),
    assertion(W == [earned, income, deduction]).
test(instruction_cut) :-
    xlsx_ir:label_words("Is the household currently homeless? Enter y if yes.", W),
    assertion(W == [is, household, currently, homeless]).
test(symbols) :-
    xlsx_ir:label_words("200% FPL / gross income", W),
    assertion(W == ['200', percent, fpl, or, gross, income]).

:- end_tests(spreadsheet_labels).

:- begin_tests(spreadsheet_import).

test(probe_workbook, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    fixture(F),
    import_workbook(F, D, [cases(6)], imported(LE, [Note])),
    read_file_to_string(LE, Text, []),
    %  the input, the table and the cascade
    assertion(sub_string(Text, _, _, _, "the income is *a number*; scenario element")),
    assertion(sub_string(Text, _, _, _, "the table rate is, with first match")),
    assertion(sub_string(Text, _, _, _, ">= 12000 and < 50000")),
    assertion(sub_string(Text, _, _, _, "otherwise")),
    %  the sheet's own values as expectations, all reproduced
    assertion(sub_string(Note, _, _, _, ", 0 fail, 0 errors")),
    atomic_list_concat([D, '/sources/tax.xlsx'], Src),
    assertion(exists_file(Src)),
    %  the draft of asking the workbook instead, in Logical English
    assertion(sub_string(Text, _, _, _, "%   the cells of service workbook are:")),
    atomic_list_concat([D, '/sources/tax.sheetport.yaml'], MF),
    assertion(\+ exists_file(MF)).

%   The draft, copied out of its comment, asks the workbook.
test(draft_asks_the_workbook, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    fixture(F),
    import_workbook(F, D, [cases(6)], imported(LE, _)),
    read_file_to_string(LE, Text, []),
    sub_string(Text, B, _, _, "%   the knowledge base"),
    sub_string(Text, E, _, _, "%   The cells the import read"), E > B,
    L is E - B, sub_string(Text, B, L, _, Block),
    split_string(Block, "\n", "", Lines0),
    maplist(uncomment, Lines0, Lines),
    atomic_list_concat(["the target language is: prolog.\n"|Lines], "\n", Program),
    le_kbs:load_text(Program, D, KB),
    assertion(\+ ( KB:le_issue(_, T, _, _, _, _), sub_atom(T, 0, _, _, cells_) )),
    le_kbs:createSession(KB, SM),
    findall(C, reasoner:i(the_surcharge_for_income_and_taxpayer_resident_is(50000, n, C), SM, _, _), Cs),
    le_kbs:destroySession(SM),
    assertion(Cs == [250]).

%   The review's idioms: CHOOSE, COUNTIF/SUMIF, dates, a percentage input.
test(idioms, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    fixture_named('grant.xlsx', F),
    import_workbook(F, D, [cases(6)], imported(LE, [Note|_])),
    read_file_to_string(LE, Text, []),
    assertion(sub_string(Note, _, _, _, "0 residue")),
    assertion(sub_string(Note, _, _, _, ", 0 fail, 0 errors")),
    assertion(sub_string(Text, _, _, _, "the date of application is 2026-03-15")),
    assertion(sub_string(Text, _, _, _, "months after")),
    assertion(sub_string(Text, _, _, _, "the applicant region is *a text*")),
    assertion(sub_string(Text, _, _, _, "the table uplift is")).

test(refuses_xls, [throws(error(format(_, _), _))]) :-
    tmp_dir(D),
    atomic_list_concat([D, '/old.xls'], F),
    setup_call_cleanup(open(F, write, S), write(S, x), close(S)),
    import_workbook(F, D, [], _).

:- end_tests(spreadsheet_import).

uncomment(L0, L) :-
    ( sub_string(L0, 0, 4, _, "%   ") -> sub_string(L0, 4, _, 0, L) ; L = "" ).

tmp_dir(D) :-
    tmp_file(xlsx_test, D), make_directory(D).

/*  File ▸ Open of an L4 file (l4_import.pl), as LE2's upload door sees it.

    From the LE2 checkout:
        ./myswipl.sh -q -g run_tests -t halt migration/l4/test_l4_import.pl
*/

:- use_module(library(plunit)).
:- use_module(library(readutil)).
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- use_module(le2(le_import)).

sale_contract(Text) :-
    le2_paths:lps2_dir(LPS2),
    atomic_list_concat([LPS2, '/examples/migration/l4/sale_contract/sources/sale-contract.l4'], F),
    read_file_to_string(F, Text, [encoding(utf8)]).

:- begin_tests(l4_import).

test(le_editor_opens_the_rules_and_names_the_contracts) :-
    sale_contract(T),
    import_upload("sale-contract.l4", text(T), R, []),
    assertion(sub_atom(R.fileName, _, _, _, sale_contract)),
    assertion(\+ sub_atom(R.fileName, _, _, _, '_contracts')),
    assertion(( member(N, R.notes), sub_string(N, _, _, _, "LPS2 IDE") )),
    assertion(memberchk("sources/sale-contract.l4", R.files)),
    assertion(( member(F, R.files), sub_string(F, _, _, _, "_contracts.le") )).

test(lps2_ide_opens_the_contracts) :-
    sale_contract(T),
    import_upload("sale-contract.l4", text(T), R, [target(lps)]),
    assertion(sub_atom(R.fileName, _, _, _, '_contracts')),
    assertion(sub_string(R.document, _, _, _, "the target language is: lps")).

test(a_file_of_rules_only_opens_as_rules_everywhere) :-
    T = "GIVEN n IS A NUMBER\nGIVETH A BOOLEAN\nDECIDE n `is big` IF n > 10\n\n#EVAL 12 `is big`\n",
    import_upload("big.l4", text(T), R, [target(lps)]),
    assertion(\+ sub_atom(R.fileName, _, _, _, '_contracts')),
    assertion(sub_string(R.document, _, _, _, "is big")).

:- end_tests(l4_import).

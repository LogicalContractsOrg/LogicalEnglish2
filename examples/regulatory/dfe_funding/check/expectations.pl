/*  expectations.pl — print, for every scenario and query of a file, the
    answers as the test runner writes them, as JSON lines
    {"scenario": S, "query": Q, "answers": [...]}. build_examples.py turns
    them into `expects answers` lines. */
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- initialization(main, main).
main :-
    current_prolog_flag(argv, [File|_]),
    absolute_file_name(File, Abs),
    le_kbs:load(Abs, KB, [skip_tests]),
    findall(S, KB:scenario(S, _), Ss0), sort(Ss0, Ss),
    findall(Q, KB:query_info(Q, _, _), Qs0), sort(Qs0, Qs),
    forall(( member(S, Ss), member(Q, Qs) ),
           ( le_kbs:run_one_test(KB, test(Q, S, ["__none__"], []), R),
             (   R = fail(_, _, _, Actual, _, _) -> true
             ;   R = fail(_, _, _, Actual) -> true
             ;   Actual = error(R)
             ),
             atom_string(S, SS), atom_string(Q, QS),
             ( Actual = error(E) -> term_string(E, ES), J = _{scenario: SS, query: QS, error: ES}
             ; J = _{scenario: SS, query: QS, answers: Actual} ),
             json_write_dict(current_output, J, [width(0)]), nl )).

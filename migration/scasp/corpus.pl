/** <module> The s(CASP) corpus the twins are built from

    The SWI-Prolog sCASP pack's tests (Apache 2.0): test/le_programs, the
    15 s(CASP) programs LE1 generated from its own examples — the nearest
    thing to an LE1 -> LE2 migration corpus — and a few classics of
    test/all_programs that use what LE1's do not (classical negation,
    abducibles, denials).
*/

:- module(scasp_corpus, [corpus_file/1, scasp_test_dir/1]).

:- use_module(library(lists)).

scasp_test_dir(D) :- getenv('SCASP_TEST_DIR', D), !.
scasp_test_dir(D) :-
    absolute_file_name(library(scasp), F, [file_type(prolog), access(read)]),
    file_directory_name(F, P), file_directory_name(P, Pack),
    atomic_list_concat([Pack, '/test'], D).

corpus_file(F) :-
    scasp_test_dir(T),
    atomic_list_concat([T, '/le_programs'], D),
    directory_files(D, Es), msort(Es, Sorted),
    member(E, Sorted), file_name_extension(_, pl, E),
    atomic_list_concat([D, '/', E], F).
corpus_file(F) :-
    scasp_test_dir(T),
    member(E, ['birds.pl', 'family.pl', 'classic_negation_inconstistent.pl', 'abdbirds.pl']),
    atomic_list_concat([T, '/all_programs/', E], F),
    exists_file(F).

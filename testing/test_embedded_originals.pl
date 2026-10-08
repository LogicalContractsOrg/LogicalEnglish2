/** <module> An upload is kept inside the program it became (le_import:embed_originals/2)

    A translator's twin in the examples keeps the file it was translated from
    in a `sources/` folder beside it. An upload has no such folder that
    lasts: the directory it is put in is forgotten after a day, and a program
    the reader saves to their own disk takes nothing with it but its own
    text. So the text of every uploaded file is appended to the program as
    one big comment (docs/dev/migration.md). These tests check that the
    comment holds the file verbatim, that a comment can never be ended early
    by what is inside it, and that what cannot be carried — a file that is
    not text, text beyond the budget — is named instead of being dropped
    silently.

    Run with:  swipl -q -g run_tests -t halt testing/test_embedded_originals.pl
*/

:- module(test_embedded_originals, []).

:- use_module(library(plunit)).
:- use_module(library(filesex)).
:- use_module('../le_import').

:- begin_tests(embedded_originals).

%   A directory of this test's own, emptied first.
work(Dir) :-
    tmp_file(embedded_originals, Dir0), atom_concat(Dir0, '_d', Dir),
    ( exists_directory(Dir) -> delete_directory_and_contents(Dir) ; true ),
    make_directory_path(Dir).

write_file(Path, Text) :-
    setup_call_cleanup(open(Path, write, S, [encoding(utf8)]), write(S, Text), close(S)).

write_bytes(Path, Bytes) :-
    setup_call_cleanup(open(Path, write, S, [type(binary)]),
                       forall(member(B, Bytes), put_byte(S, B)),
                       close(S)).

%   The program as it is after an upload of Text named Name was embedded in it.
embedded(Name, Text, Program) :-
    work(Dir),
    atomic_list_concat([Dir, '/', Name], Upload), write_file(Upload, Text),
    atomic_list_concat([Dir, '/p.le'], LE), write_file(LE, "the target language is: prolog.\n"),
    le_import:embed_originals(Upload, LE),
    read_file_to_string(LE, Program, [encoding(utf8)]),
    delete_directory_and_contents(Dir).

test(the_text_is_there_line_by_line) :-
    embedded('a.txt', "first line\nsecond line\n", P),
    assertion(sub_string(P, _, _, _, "% first line")),
    assertion(sub_string(P, _, _, _, "% second line")).

test(the_file_is_named_where_it_begins_and_ends) :-
    embedded('MyToken.sol', "contract MyToken {}\n", P),
    assertion(sub_string(P, _, _, _, "MyToken.sol begins")),
    assertion(sub_string(P, _, _, _, "MyToken.sol ends")).

test(the_program_itself_is_untouched) :-
    embedded('a.txt', "x\n", P),
    assertion(sub_string(P, 0, _, _, "the target language is: prolog.")).

%   Every line of the original starts with a per cent sign, so no sequence in
%   it — `*/` above all, which would end a block comment — can end the
%   comment early and let the original be read as rules.
test(nothing_in_the_original_ends_the_comment) :-
    embedded('a.c', "/* a block */\nthe person is liable.\n", P),
    assertion(sub_string(P, _, _, _, "% /* a block */")),
    assertion(sub_string(P, _, _, _, "% the person is liable.")),
    assertion(\+ sub_string(P, _, _, _, "\nthe person is liable.")).

test(a_file_that_is_not_text_is_named_not_carried) :-
    work(Dir),
    atomic_list_concat([Dir, '/i.png'], Upload),
    write_bytes(Upload, [0x89, 0x50, 0x4e, 0x47, 0, 0, 1, 2]),
    le_import:upload_texts(Upload, Texts, Omitted),
    assertion(Texts == []),
    assertion(Omitted == ['i.png']),
    delete_directory_and_contents(Dir).

test(a_binary_upload_leaves_the_program_as_it_was) :-
    work(Dir),
    atomic_list_concat([Dir, '/i.png'], Upload),
    write_bytes(Upload, [0x89, 0x50, 0x4e, 0x47, 0, 0, 1, 2]),
    atomic_list_concat([Dir, '/p.le'], LE),
    write_file(LE, "the target language is: prolog.\n"),
    le_import:embed_originals(Upload, LE),
    read_file_to_string(LE, P, [encoding(utf8)]),
    assertion(P == "the target language is: prolog.\n"),
    delete_directory_and_contents(Dir).

test(text_beyond_the_budget_is_named_not_carried) :-
    work(Dir),
    le_import:max_embedded_bytes(Max), Over is Max + 10,
    length(Cs, Over), maplist(=(0'x), Cs), string_codes(Big, Cs),
    atomic_list_concat([Dir, '/big.txt'], Upload), write_file(Upload, Big),
    le_import:upload_texts(Upload, Texts, Omitted),
    assertion(Texts == []),
    assertion(Omitted == ['big.txt']),
    delete_directory_and_contents(Dir).

%   An archive is opened into a directory, and every text file of it is
%   carried, under its own name.
test(every_text_file_of_an_uploaded_tree_is_carried) :-
    work(Dir),
    atomic_list_concat([Dir, '/tree'], Tree), make_directory_path(Tree),
    atomic_list_concat([Tree, '/one.sol'], F1), write_file(F1, "contract One {}\n"),
    atomic_list_concat([Tree, '/two.sol'], F2), write_file(F2, "contract Two {}\n"),
    le_import:upload_texts(Tree, Texts, Omitted),
    assertion(Omitted == []),
    findall(N, member(N-_, Texts), Names), msort(Names, Sorted),
    assertion(Sorted == ['one.sol', 'two.sol']),
    delete_directory_and_contents(Dir).

%   The writing has to be finished before the caller reads the program: a
%   goal left with a choice point would keep the stream open, and the text
%   would reach the file only when the process ended.
test(the_program_is_complete_when_embedding_returns) :-
    work(Dir),
    atomic_list_concat([Dir, '/a.txt'], Upload), write_file(Upload, "one line\n"),
    atomic_list_concat([Dir, '/p.le'], LE), write_file(LE, "the target language is: prolog.\n"),
    size_file(LE, Before),
    le_import:embed_originals(Upload, LE),
    size_file(LE, After),
    assertion(After > Before),
    delete_directory_and_contents(Dir).

:- end_tests(embedded_originals).

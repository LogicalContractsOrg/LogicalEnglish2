/** <module> Opening another system's files as Logical English

    File ▸ Open in the editor accepts, besides `.le`, the files of the
    systems a translator is registered for (InsurLE2/docs/
    InsurLE2/docs/migration/roadmap.md, docs/dev/migration.md). This module is the
    door they all go through; it knows no source system. A translator
    registers itself with one clause of importer/6:

        le_import:importer(Id, Title, Extensions, File, Import, Detect)

      - Id           an atom naming the source (`solidity`)
      - Title        what the editor says it is ("Solidity contract")
      - Extensions   the file extensions it reads, lower case, no dot
                     (`[sol]`); `zip` for an archive of a source tree
      - File         the Prolog file defining Import and Detect, loaded on
                     first use (so registering costs nothing at start-up)
      - Import       Module:Name, called as call(Import, +Input, +OutDir,
                     -imported(LEFile, Notes)): Input is the uploaded file,
                     or the directory an uploaded archive was extracted into;
                     the translation (the .le and what it includes or cites)
                     is written into the empty directory OutDir; Notes is a
                     list of strings. An importer may take the upload's
                     options too, as call(Import, +Input, +OutDir,
                     +Options, -imported(LEFile, Notes)); Options then holds
                     target(lps) when the LPS2 IDE is the one opening the
                     file (import_call/5). A fragment the translator cannot
                     translate is written into the .le as a comment block
                     carrying the word TODO and the fragment verbatim — it
                     never makes the whole import fail.
      - Detect       Module:Name, call(Detect, +Input) succeeds when Input
                     is this source's material; it decides between
                     translators that share an extension (`zip`, `xml`).

    An upload is kept in its own directory under tmp/imports/, and the
    program is opened as `imported/<id>/<name>`, which le_example_relpath/2
    resolves there: the program's includes and the documents it cites are
    found beside it, exactly as for an example.

    The upload is also kept INSIDE the program, as one big comment at the end
    of the `.le` (embed_originals/2): a text file that was translated is
    appended line by line, under a line that names it. The copy beside the
    program, in `sources/`, is forgotten with the upload's directory after a
    day, and a program the reader saves to their own disk takes nothing with
    it but its own text; the comment is how a translation stays readable
    against the file it came from. Only text is carried — a comment can hold
    nothing else — and only as much as max_embedded_bytes/1 allows, with a
    line naming whatever was left out.

    When no translator accepts a text file, or the one that claimed it
    fails outright, the result is still a program: the file's text as a TODO
    comment, with the reason.

    ## The other way: exporting a program to another system

    File ▸ Export to Another System… (and the LPS2 IDE's Misc menu) writes a
    loaded program in another system's format. An exporter registers itself
    with one clause of exporter/6:

        le_import:exporter(Id, Title, Extension, File, Export, Applies)

      - Id, Title    as for importers (`legalruleml`, "LegalRuleML (OASIS)")
      - Extension    the extension of the file it writes, no dot (`xml`)
      - File         the Prolog file defining Export and Applies, loaded on
                     first use
      - Export       Module:Name, call(Export, +KB, +Options, -Result):
                     Result is exported(FileName, Text, Notes, Links), or
                     refused(Problems) (below); KB is the loaded knowledge
                     base module (le_kbs:load_text/3), so the exporter reads
                     it through le_writer:kb_to_ir/2 or the LPS translation,
                     never the text; Options holds text(Doc) and base(Dir);
                     Notes is a list of strings (what did not carry over
                     without loss of meaning, and why); Links a list of
                     link(Title, Url) — a public sandbox or playground the
                     result can be opened in.
      - Applies      Module:Name, call(Applies, +KB) succeeds when the
                     program is one this exporter can write (the menus list
                     only those).

    What an exporter cannot express it says — never silently. There are two
    kinds of it, and they are treated differently:

      - a PROBLEM loses meaning: a rule, fact, condition or declaration the
        target has no faithful form for (an aggregate in LegalRuleML, a
        reactive rule in Daml, a condition outside Miniscript's vocabulary).
        A program with a problem is REFUSED: nothing is written, and the
        reply lists every problem with the line it comes from, so that the
        user can change the program or choose another target. A translation
        that silently means something else than its program would be worse
        than none;
      - a NOTE loses no meaning: comments, explanation texts, queries and
        expected answers (tests, not the program), layout, a key named after
        its role. Notes travel with the written text.

    The check comes before the text. An exporter registers it with one
    clause of export_check/2 (optional, but every exporter that can meet a
    problem should have one):

        le_import:export_check(Id, Check)

      - Check        Module:Name, called as call(Check, +KB, +Options,
                     -Problems), in the exporter's File (loaded first);
                     Problems is a list of problem(Where, Message): Where is
                     `at(Start, End)` (character offsets in the program's
                     text, as le_at/3 carries them), `line(N)`, or `none`;
                     Message a string. [] lets the export go ahead.

    export_kb/4 runs the check before Export, and calls Export with
    checked(true) added to Options when it passed (so that an exporter whose
    Export also checks, for its direct callers, need not check twice).
    Export may still answer `refused(Problems)` instead of `exported(...)`:
    a problem found only while translating. Either way the reply is the
    refusal, `error` plus `problems`, and no `document`.

    Where a problem is matters twice: the refusal shows its line, and a
    partial export (below) leaves out exactly the clauses it names. Where is
    one of
      - at(Start, End)   character offsets in the program's text (le_at/3,
                         le_source_info/4, an IR item's source/3 option);
      - line(N)          a line of the program's text;
      - predicate(F/N)   every clause of F/N: a problem about a template
                         (too many places for the target) or about a rule
                         whose own position is unknown (one of an included
                         resource). The refusal shows the template's line;
      - none             nowhere: such a problem cannot be left out, and a
                         partial export of the program is refused.
    An exporter gives the most precise place it knows, and `none` only for a
    problem that is about the program as a whole.

    ## Provenance: where each part of the output came from

    Every exporter writes, beside each element of its output that comes from
    a rule, fact or constraint of the program, the line it came from: as a
    comment in the target's syntax (`<!-- Logical English line 74 -->`,
    `-- Logical English line 74`, `# Logical English line 74`), or with the
    target's own provenance construct where it has one. The line comes from
    the IR: le_writer:kb_to_ir/3 with the Options' text(Doc) adds
    source(Line, Start, End) to the options of every rule, fact and
    constraint (kb_to_ir/2 does not, so that nothing comparing IRs sees a
    change); item_source_line/2 reads it. A comment carries the line and,
    where the target's comments allow it, the start of the sentence; never
    so much of it that the output becomes the program twice.

    Applies and the check are deliberately two things: Applies says the
    program is of the kind the exporter writes (a spending policy, an LE
    for LPS program), so the menus offer it; the check says whether this
    program of that kind uses something the target cannot say. An offered
    exporter can therefore refuse — and the refusal is the useful answer,
    since it says what to change.
*/

:- module(le_import, [import_upload/4, import_formats/1, imported_dir/1,
                      evaluate_upload/5, evaluate_formats/1,
                      export_formats/2, export_kb/4, export_refusal/4, item_source_line/2,
                      kb_constraint_problems/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module(library(zip)).
:- use_module(library(base64)).
:- use_module(library(option)).
:- use_module(library(modules)).      % in_temporary_module/3: partial exports
:- use_module(library(occurs)).       % sub_term/2
:- use_module(library(yall)).
:- use_module(library(pairs)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(le_i18n).           % the messages the comments and the fallbacks say

:- multifile importer/6.
:- dynamic importer/6.
:- multifile exporter/6.
:- dynamic exporter/6.
:- multifile export_check/2.
:- dynamic export_check/2.
:- multifile evaluator/5.
:- dynamic evaluator/5.

%!  imported_dir(-Dir) is det.
%
%   Where uploads and their translations are kept (relative to the server's
%   working directory, like the example trees).
imported_dir('tmp/imports').

%!  import_formats(-Formats:list(dict)) is det.
%
%   The registered translators, for the editor's file picker and its help:
%   `{id, title, extensions}`.
import_formats(Formats) :-
    findall(_{id: Id, title: Title, extensions: Exts},
            importer(Id, Title, Exts, _, _, _),
            Formats).

%!  import_upload(+FileName, +Content, -Reply:dict, +Options) is det.
%
%   Content is `text(String)` or `base64(String)` (a binary upload, such as
%   a zip archive). Reply is a dict: `document` (the program's text),
%   `fileName` (`<stem>.le`), `source` (`imported/<id>/<stem>`: open it as
%   that, so its includes resolve), `importer` (the translator's title, or
%   null), `notes` (strings), `files` (what was written beside it). Or
%   `error` when nothing could be read. Options: `importer(Id)` forces a
%   translator; `root(Dir)` keeps the upload elsewhere than imported_dir/1
%   (another server embedding LE, with a scratch directory of its own);
%   `target(lps)` says the file is opened by the LPS2 IDE (import_call/5).
import_upload(FileName0, Content, Reply, Options) :-
    atom_string(FileName1, FileName0),
    file_base_name(FileName1, FileName),
    safe_name(FileName),
    ( memberchk(root(Root), Options) -> true ; imported_dir(Root) ),
    new_upload_dir(Root, Id, Dir),
    atomic_list_concat([Dir, '/in'], InDir),
    atomic_list_concat([Dir, '/out'], OutDir),
    make_directory_path(InDir), make_directory_path(OutDir),
    atomic_list_concat([InDir, '/', FileName], InFile),
    write_upload(InFile, Content),
    file_name_extension(Stem0, Ext0, FileName),
    downcase_atom(Ext0, Ext),
    (   Ext == zip
    ->  atomic_list_concat([InDir, '/', Stem0], Tree),
        extract_zip(InFile, Tree),
        single_subdir(Tree, Input)
    ;   Input = InFile
    ),
    le_stem(Stem0, Stem),
    (   choose_importer(Ext, Input, Options, importer(_, Title, _, File, Import, _))
    ->  load_importer(File),
        catch(( import_call(Import, Input, OutDir, Options, imported(LEFile0, Notes0)) -> Outcome = ok(LEFile0, Notes0)
              ; Outcome = failed("the translator failed") ),
              E, ( error_text(E, Msg), Outcome = failed(Msg) )),
        keep_originals(Input, OutDir),
        (   Outcome = ok(LEFile, Notes)
        ->  embed_originals(Input, LEFile),
            prepend_ledger_summary(LEFile),
            imported_reply(Id, OutDir, LEFile, Title, Notes, Reply)
        ;   Outcome = failed(Why),
            fallback(Id, OutDir, Stem, Input, Title, Why, Reply)
        )
    ;   Ext == zip
    ->  le_i18n:le_msg(import_no_translator, [file-FileName], M),
        Reply = _{error: M}
    ;   le_i18n:le_msg(import_no_translator, [file-FileName], Why),
        keep_originals(Input, OutDir),
        fallback(Id, OutDir, Stem, Input, null, Why, Reply)
    ).

%   An importer that defines its predicate with one more argument is also
%   given the upload's options: `target(lps)` when the LPS2 IDE opens the
%   file, so a source with both rules and contracts (L4) can answer with the
%   reading the editor asking wants.
import_call(M:N, Input, OutDir, Options, Result) :-
    (   current_predicate(M:N/4)
    ->  call(M:N, Input, OutDir, Options, Result)
    ;   call(M:N, Input, OutDir, Result)
    ).

%   What was uploaded, beside the program in sources/: the editor's File ▸
%   Show the Original lists that folder. An importer that keeps the sources
%   it cites there itself (under the paths its citations use) is left alone.
keep_originals(Input, OutDir) :-
    atomic_list_concat([OutDir, '/sources'], SDir),
    (   exists_directory(SDir)
    ->  true
    ;   exists_directory(Input)
    ->  catch(copy_directory(Input, SDir), _, true)
    ;   make_directory_path(SDir),
        file_base_name(Input, B), atomic_list_concat([SDir, '/', B], To),
        catch(copy_file(Input, To), _, true)
    ).

%!  embed_originals(+Input, +LEFile) is det.
%
%   The upload kept INSIDE the program it became: the text of every file
%   that was uploaded, appended to the `.le` as one big comment.
%
%   The copy in `sources/` beside the program (keep_originals/2) is what the
%   editors show as "the original this was converted from", and it does not
%   last: the upload's directory is forgotten after a day
%   (forget_old_uploads/1), and a program the reader saves to their own disk
%   takes nothing but its own text with it. A program that carries its
%   original in a comment can still be read against the file it came from a
%   year later, wherever it has travelled.
%
%   Only text is carried, since a comment can hold nothing else: a binary
%   upload (an archive, a PDF, a spreadsheet) is left out, and so is text
%   beyond the budget of max_embedded_bytes/1, with a line that names the
%   files left out. Every line is prefixed with `% `, so no sequence in the
%   original can end the comment early (which `/* ... */` would allow).
%   Nothing here knows any source system: it is the same for every
%   translator (docs/dev/migration.md).
%
%   It never fails and never throws: the translation is what was asked for,
%   and a comment that could not be written is worth no more than a comment.
embed_originals(Input, LEFile) :-
    (   catch(embed_originals_(Input, LEFile), _, fail)
    ->  true
    ;   true
    ).

embed_originals_(Input, LEFile) :-
    exists_file(LEFile),
    upload_texts(Input, Texts, Omitted),
    Texts \== [],
    %  `once`, so that the writing is finished — and the stream therefore
    %  closed — before this returns: a goal that leaves a choice point keeps
    %  setup_call_cleanup/3's cleanup pending, and the text would reach the
    %  file only when the process ends, long after the caller read it.
    setup_call_cleanup(
        open(LEFile, append, Out, [encoding(utf8)]),
        once(write_originals(Out, Texts, Omitted)),
        close(Out)).

%!  prepend_ledger_summary(+LEFile) is det.
%
%   The ledger of the translation (`<stem>.ledger.json` beside the program,
%   le_migration.pl), summed up in a comment at the top of the program: how
%   many elements of the source were encoded, approximated and left as
%   residue, how many of the source's own test expectations the program
%   reproduces, and the file that holds the whole ledger (the editor's File ▸
%   Show the Ledger opens it). The whole ledger is not put in the program: it
%   can be longer than the program, and it describes the translation, not
%   the program the reader goes on to change. The summary travels with the
%   program wherever it is saved; the ledger's file stays beside it on the
%   server, and the ledger window offers to save it.
%
%   Like embed_originals/2, it never fails and never throws, and nothing in
%   it knows any source system.
prepend_ledger_summary(LEFile) :-
    (   catch(prepend_ledger_summary_(LEFile), _, fail)
    ->  true
    ;   true
    ).

prepend_ledger_summary_(LEFile) :-
    ledger_json_of(LEFile, JsonFile),
    setup_call_cleanup(open(JsonFile, read, In, [encoding(utf8)]),
                       json_read_dict(In, Ledger), close(In)),
    C = Ledger.counts,
    le_i18n:le_msg(import_ledger_summary,
                   [encoded-C.encoded, approximated-C.approximated, residue-C.residue], Summary),
    (   get_dict(fidelity, Ledger, F), is_dict(F)
    ->  Total is F.passed + F.failed + F.errors,
        le_i18n:le_msg(import_ledger_tests, [passed-F.passed, total-Total], Tests),
        Lines0 = [Summary, Tests]
    ;   Lines0 = [Summary]
    ),
    file_name_extension(Stem, _, LEFile), file_base_name(Stem, Base),
    atom_concat(Base, '.ledger.md', MdName),
    le_i18n:le_msg(import_ledger_where, [file-MdName], Where),
    append(Lines0, [Where], Lines),
    read_file_to_string(LEFile, Program, [encoding(utf8)]),
    with_output_to(string(Header),
                   ( format("% ~`=t~70|~n", []),
                     forall(member(L, Lines), comment_lines(current_output, L)),
                     format("% ~`=t~70|~n~n", []) )),
    setup_call_cleanup(open(LEFile, write, Out, [encoding(utf8)]),
                       ( write(Out, Header), write(Out, Program) ),
                       close(Out)).

%   The ledger written beside a program: `<stem>.ledger.json`.
ledger_json_of(LEFile, JsonFile) :-
    file_name_extension(Stem, _, LEFile),
    atom_concat(Stem, '.ledger.json', JsonFile),
    exists_file(JsonFile).

write_originals(Out, Texts, Omitted) :-
    le_i18n:le_msg(import_original_kept, [], Kept),
    format(Out, "~n~n% ~`=t~70|~n", []),
    comment_lines(Out, Kept),
    forall(member(Name-Text, Texts), write_original(Out, Name, Text)),
    (   Omitted == []
    ->  true
    ;   atomic_list_concat(Omitted, ', ', Names),
        le_i18n:le_msg(import_original_omitted, [files-Names], Left),
        format(Out, "%~n", []),
        comment_lines(Out, Left)
    ),
    format(Out, "% ~`=t~70|~n", []).

write_original(Out, Name, Text) :-
    le_i18n:le_msg(import_original_begins, [file-Name], Begins),
    le_i18n:le_msg(import_original_ends, [file-Name], Ends),
    format(Out, "%~n% ~w~n%~n", [Begins]),
    split_string(Text, "\n", "\r", Ls0),
    trim_trailing_blanks(Ls0, Ls),
    forall(member(L, Ls),
           ( L == "" -> format(Out, "%~n", []) ; format(Out, "% ~w~n", [L]) )),
    format(Out, "%~n% ~w~n", [Ends]).

%   The blank lines a text ends with, dropped: they would read as a gap
%   between the original and the line that says where it ends.
trim_trailing_blanks(Ls0, Ls) :-
    reverse(Ls0, R0),
    drop_blanks(R0, R),
    reverse(R, Ls).

drop_blanks([L|Ls], R) :- L == "", !, drop_blanks(Ls, R).
drop_blanks(Ls, Ls).

%   A paragraph as comment lines of about 76 characters, so that it reads in
%   an editor that does not wrap.
comment_lines(Out, Text) :-
    atom_string(Text, S),
    split_string(S, " ", " ", Words0),
    exclude(==(""), Words0, Words),
    comment_words(Out, Words, []).

comment_words(Out, [], Acc) :-
    ( Acc == [] -> true ; reverse(Acc, Ws), atomic_list_concat(Ws, ' ', L), format(Out, "% ~w~n", [L]) ).
comment_words(Out, [W|Ws], Acc) :-
    reverse([W|Acc], Try), atomic_list_concat(Try, ' ', L), string_length(L, N),
    (   N > 74, Acc \== []
    ->  reverse(Acc, Done), atomic_list_concat(Done, ' ', DL), format(Out, "% ~w~n", [DL]),
        comment_words(Out, [W|Ws], [])
    ;   comment_words(Out, Ws, [W|Acc])
    ).

%!  max_embedded_bytes(-N) is det.
%
%   How much of an upload a program carries in its comment. A translation is
%   read, and a program whose comment is ten times its own rules is not.
max_embedded_bytes(400000).

%!  upload_texts(+Input, -Texts:list(Name-Text), -Omitted:list(atom)) is det.
%
%   The text files of the upload, by name, within the budget; Omitted names
%   those that did not fit, and the files that are not text.
upload_texts(Input, Texts, Omitted) :-
    (   exists_file(Input)
    ->  Files = [Input]
    ;   exists_directory(Input)
    ->  findall(F, ( directory_member(Input, F, [recursive(true)]), exists_file(F) ), Fs0),
        msort(Fs0, Files)
    ;   Files = []
    ),
    max_embedded_bytes(Max),
    upload_texts_(Files, Max, Texts, Omitted).

upload_texts_([], _, [], []).
upload_texts_([F|Fs], Left, Texts, Omitted) :-
    file_base_name(F, Name),
    (   upload_text(F, Text), string_length(Text, N), N =< Left
    ->  Left1 is Left - N,
        Texts = [Name-Text|Texts1], Omitted = Omitted1
    ;   Left1 = Left, Texts = Texts1, Omitted = [Name|Omitted1]
    ),
    upload_texts_(Fs, Left1, Texts1, Omitted1).

%   Text, as a comment can only hold text. Asked of the content, so that a
%   translator's own extension needs no row in a table here: the bytes are
%   read first, and a file holding a zero byte, or more than one control
%   byte in a hundred, is not text — which is also why the bytes are looked
%   at before the characters, since reading an image as UTF-8 says so on the
%   server's console instead of here.
upload_text(File, Text) :-
    catch(read_file_to_string(File, Raw, [encoding(octet)]), _, fail),
    string_codes(Raw, Bytes),
    \+ memberchk(0, Bytes),
    include(control_byte, Bytes, Controls),
    length(Bytes, N), length(Controls, C), N > 0, C * 100 =< N,
    catch(read_file_to_string(File, Text, [encoding(utf8)]), _, fail).

%   A byte no text has, the three a text does have — tab, newline, carriage
%   return — excepted.
control_byte(B) :- B < 32, \+ memberchk(B, [9, 10, 13]).
control_byte(127).

%   A file name from the client is a name, not a path.
safe_name(Name) :-
    Name \== '', Name \== '.', Name \== '..',
    \+ sub_atom(Name, _, _, _, '/'),
    \+ sub_atom(Name, _, _, _, '\\').

new_upload_dir(Root, Id, Dir) :-
    catch(forget_old_uploads(Root), _, true),
    repeat,
    random_between(0, 0xffffffff, R),
    get_time(T), S is floor(T),
    format(atom(Id), '~36r~36r', [S, R]),
    atomic_list_concat([Root, '/', Id], Dir),
    \+ exists_directory(Dir), !,
    make_directory_path(Dir).

%   Uploads are kept a day: long enough to work on the translation (its
%   includes and cited documents are read from there), not forever.
forget_old_uploads(Root) :-
    exists_directory(Root), !,
    get_time(Now),
    directory_files(Root, Es),
    forall(( member(E, Es), \+ sub_atom(E, 0, 1, _, '.'),
             atomic_list_concat([Root, '/', E], D),
             exists_directory(D),
             time_file(D, T), Now - T > 86400 ),
           catch(delete_directory_and_contents(D), _, true)).
forget_old_uploads(_).

%!  max_upload_bytes(-N) is det.
max_upload_bytes(20000000).

write_upload(File, text(S)) :- !,
    setup_call_cleanup(open(File, write, Out, [encoding(utf8)]),
                       write(Out, S), close(Out)).
write_upload(File, base64(B64)) :-
    atom_string(A, B64),
    base64(Bytes, A),                    % an atom whose characters are the bytes
    atom_codes(Bytes, Codes),
    setup_call_cleanup(open(File, write, Out, [type(binary)]),
                       forall(member(C, Codes), put_byte(Out, C)),
                       close(Out)).

%   A program's name is an atom LE reads back: letters, digits, underscores.
le_stem(Stem0, Stem) :-
    downcase_atom(Stem0, L),
    atom_codes(L, Cs0),
    maplist(stem_code, Cs0, Cs1),
    atom_codes(S1, Cs1),
    atomic_list_concat(Parts0, '_', S1),
    exclude(==(''), Parts0, Parts),
    (   Parts == [] -> Stem = imported
    ;   atomic_list_concat(Parts, '_', S2),
        ( sub_atom(S2, 0, 1, _, F), char_type(F, digit) -> atom_concat(p_, S2, Stem) ; Stem = S2 )
    ).
stem_code(C, C) :- code_type(C, alnum), C < 128, !.
stem_code(_, 0'_).

		 /*******************************
		 *          ARCHIVES            *
		 *******************************/

%   Every member of the archive, below Tree. A member whose name would leave
%   Tree (an absolute path, `..`) is skipped.
extract_zip(Zip, Tree) :-
    make_directory_path(Tree),
    setup_call_cleanup(
        zip_open(Zip, read, Z, []),
        ( zipper_goto(Z, first)
        ->  extract_members(Z, Tree)
        ;   true ),
        zip_close(Z)).

extract_members(Z, Tree) :-
    zipper_file_info(Z, Name, _Info),
    (   safe_member(Name)
    ->  atomic_list_concat([Tree, '/', Name], Path),
        (   sub_atom(Name, _, 1, 0, '/')
        ->  make_directory_path(Path)
        ;   file_directory_name(Path, PD), make_directory_path(PD),
            setup_call_cleanup(zipper_open_current(Z, In, [type(binary)]),
                               setup_call_cleanup(open(Path, write, Out, [type(binary)]),
                                                  copy_stream_data(In, Out),
                                                  close(Out)),
                               close(In))
        )
    ;   true
    ),
    (   zipper_goto(Z, next)
    ->  extract_members(Z, Tree)
    ;   true
    ).

safe_member(Name) :-
    atom_string(Name, S),
    S \== "",
    \+ sub_string(S, 0, 1, _, "/"),
    split_string(S, "/\\", "", Parts),
    \+ memberchk("..", Parts),
    \+ ( sub_string(S, 1, 1, _, ":") ),
    \+ sub_string(S, 0, _, _, "__MACOSX").

%   An archive of one folder is that folder.
single_subdir(Tree, Input) :-
    directory_files(Tree, Es0),
    exclude(hidden_entry, Es0, Es),
    (   Es = [One],
        atomic_list_concat([Tree, '/', One], Sub),
        exists_directory(Sub)
    ->  Input = Sub
    ;   Input = Tree
    ).
hidden_entry(E) :- sub_atom(E, 0, 1, _, '.').

		 /*******************************
		 *     CHOOSING A TRANSLATOR    *
		 *******************************/

choose_importer(_, _, Options, Imp) :-
    memberchk(importer(Id0), Options), !,
    atom_string(Id, Id0),
    Imp = importer(Id, _, _, _, _, _),
    call(Imp), !,
    load_importer_of(Imp).
choose_importer(Ext, Input, _, Imp) :-
    findall(importer(Id, T, Es, F, I, D),
            ( importer(Id, T, Es, F, I, D), memberchk(Ext, Es) ),
            Cands),
    Cands \== [],
    (   Cands = [Imp0], \+ generic_extension(Ext)
    ->  Imp = Imp0,
        load_importer_of(Imp)
    ;   member(Imp, Cands),
        load_importer_of(Imp),
        Imp = importer(_, _, _, _, _, Detect),
        catch(call(Detect, Input), _, fail)
    ), !.

%   Extensions many systems use: the translator's Detect decides even when
%   only one translator is registered for them. A specific extension (`sol`)
%   goes to its translator, which reports what it cannot read.
generic_extension(zip).
generic_extension(txt).
generic_extension(json).
generic_extension(xml).

load_importer_of(importer(_, _, _, File, _, _)) :-
    exists_file(File),
    catch(load_importer(File), E, ( print_message(warning, E), fail )).

load_importer(File) :-
    load_files(File, [if(not_loaded)]).

		 /*******************************
		 *   ANSWERS IN ANOTHER FORMAT  *
		 *******************************/

%!  evaluator(?Id, ?Title, ?Extensions, ?File, ?Evaluate) is nondet.
%
%   A translator that can also answer a case of another system's program in
%   that system's own result format: Logical English acting as the other
%   system's evaluator. Registered like an importer (one clause, in
%   lpsPlus `migration/le_importers.pl`):
%
%       le_import:evaluator(Id, Title, Extensions, File, Module:Evaluate).
%       %   call(Evaluate, +InputFile, +Data, +Options, -Reply)
%       %   Data: the case, a dict; Options: a dict (the format's own,
%       %   such as `mode`); Reply: {result: <dict>, fileName, notes}
%
%   The first is RUML's: a rulemap and the values of a case in, a
%   `.ruml-result` out (docs/migration/ruml.md §7 in lpsPlus).

%!  evaluate_formats(-Formats:list(dict)) is det.
evaluate_formats(Formats) :-
    findall(_{id: Id, title: Title, extensions: Exts}, evaluator(Id, Title, Exts, _, _), Formats).

%!  evaluate_upload(+Evaluator, +FileName, +Content, +Data, -Reply) is det.
%
%   The program (Content as for import_upload/4) is kept like an upload;
%   Data is a dict with `data` (the case) and `options`. Reply as the
%   evaluator gives it, or {error: Message}.
evaluate_upload(Id0, FileName0, Content, Data, Reply) :-
    atom_string(Id, Id0),
    atom_string(FileName1, FileName0), file_base_name(FileName1, FileName), safe_name(FileName),
    (   evaluator(Id, _, _, File, Evaluate)
    ->  imported_dir(Root), new_upload_dir(Root, _, Dir),
        atomic_list_concat([Dir, '/in'], InDir), make_directory_path(InDir),
        atomic_list_concat([InDir, '/', FileName], InFile),
        write_upload(InFile, Content),
        ( get_dict(data, Data, Case) -> true ; Case = _{} ),
        ( get_dict(options, Data, Opts) -> true ; Opts = _{} ),
        load_importer(File),
        catch(( call(Evaluate, InFile, Case, Opts, Reply0) -> Reply = Reply0
              ; Reply = _{error: "The evaluator gave no result."} ),
              E, ( message_to_codes(E, Cs), string_codes(M, Cs), Reply = _{error: M} ))
    ;   format(string(M), "No evaluator ~w on this server.", [Id]), Reply = _{error: M}
    ).

message_to_codes(error(format(F, A), _), Cs) :- !, format(codes(Cs), F, A).
message_to_codes(E, Cs) :- catch(message_to_codes(E, [], Cs0), _, fail), !, Cs = Cs0.
message_to_codes(E, Cs) :- format(codes(Cs), "~q", [E]).

		 /*******************************
		 *            REPLIES           *
		 *******************************/

imported_reply(Id, OutDir, LEFile, Title, Notes, Reply) :-
    read_file_to_string(LEFile, Text, [encoding(utf8)]),
    atomic_list_concat([OutDir, '/'], OutSlash),
    (   atom_concat(OutSlash, Rel, LEFile) -> true ; file_base_name(LEFile, Rel) ),
    file_name_extension(RelStem, _, Rel),
    file_base_name(LEFile, Base),
    format(atom(Source), 'imported/~w/~w', [Id, RelStem]),
    written_files(OutDir, Files),
    maplist(to_string, Notes, NoteStrs),
    ( ledger_json_of(LEFile, _) -> Ledger = true ; Ledger = false ),
    Reply = _{document: Text, fileName: Base, source: Source,
              importer: Title, notes: NoteStrs, files: Files, ledger: Ledger}.

error_text(E, S) :-
    catch(( '$messages':translate_message(E, Lines, []),
            with_output_to(string(S0), print_message_lines(current_output, '', Lines)),
            normalize_space(string(S), S0) ), _, fail), !.
error_text(E, S) :- format(string(S), "~q", [E]).

to_string(X, S) :- ( string(X) -> S = X ; atomic(X) -> atom_string(X, S) ; format(string(S), "~w", [X]) ).

written_files(OutDir, Files) :-
    atomic_list_concat([OutDir, '/'], OutSlash),
    findall(Rel,
            ( directory_member(OutDir, F, [recursive(true)]),
              exists_file(F),
              atom_concat(OutSlash, Rel0, F), atom_string(Rel0, Rel) ),
            Files0),
    msort(Files0, Files).

%   Nothing translated: the source itself, as a TODO, in a program that
%   says why. Only text is copied; an archive has nothing to show.
fallback(Id, OutDir, Stem, Input, Title, Why, Reply) :-
    (   exists_file(Input),
        catch(read_file_to_string(Input, Src, [encoding(utf8)]), _, fail),
        string_length(Src, Len), Len < 2000000
    ->  true
    ;   Src = ""
    ),
    file_base_name(Input, InName),
    to_string(Why, Why0),
    ( string_concat(WhyBare, ".", Why0) -> true ; WhyBare = Why0 ),
    le_i18n:le_msg(import_fallback_todo, [file-InName, reason-WhyBare], Todo),
    with_output_to(string(Text),
        ( format("the target language is: prolog.~n~n"),
          format("the knowledge base ~w includes:~n~n", [Stem]),
          format("% TODO: ~w~n", [Todo]),
          (   Src == "" -> true
          ;   format("%~n"),
              split_string(Src, "\n", "\r", Ls),
              forall(member(L, Ls), format("%   | ~w~n", [L]))
          ) )),
    atomic_list_concat([OutDir, '/', Stem, '.le'], LEFile),
    setup_call_cleanup(open(LEFile, write, S, [encoding(utf8)]), write(S, Text), close(S)),
    to_string(Why, WhyS),
    imported_reply(Id, OutDir, LEFile, Title, [WhyS], Reply).

		 /*******************************
		 *           EXPORTING          *
		 *******************************/

%!  export_formats(+KB, -Formats:list(dict)) is det.
%
%   The exporters that can write the loaded program KB: `{id, title,
%   extension}`.
export_formats(KB, Formats) :-
    findall(_{id: Id, title: Title, extension: Ext},
            ( exporter(Id, Title, Ext, File, _, Applies),
              load_exporter(File),
              catch(call(Applies, KB), _, fail) ),
            Formats).

%!  export_kb(+Id, +KB, +Options, -Reply:dict) is det.
%
%   Reply: `document` (the text written), `fileName`, `exporter` (its
%   title), `notes`, `links` (`{title, url}`); or `error` — and, when the
%   program was refused, `exporter` and `problems` (`{line, message,
%   text}`: line null when the program cannot say where; text the
%   program's own words there, when known).
export_kb(Id0, KB, Options, Reply) :-
    atom_string(Id, Id0),
    (   exporter(Id, Title, Ext, File, Export, _)
    ->  load_exporter(File),
        export_outcome(Id, KB, Export, Options, Outcome0),
        (   Outcome0 = refused(Problems0),
            option(partial(true), Options)
        ->  partial_export(Id, Ext, Export, Problems0, Options, Outcome)
        ;   Outcome = Outcome0
        ),
        (   Outcome = ok(Name, Text, Notes, Links, Residues)
        ->  maplist(to_string, Notes, NoteStrs),
            findall(_{title: LT, url: LU},
                    ( member(link(LT0, LU0), Links), to_string(LT0, LT), to_string(LU0, LU) ),
                    LinkDicts),
            to_string(Text, TextS), to_string(Name, NameS),
            Reply0 = _{document: TextS, fileName: NameS, exporter: Title,
                       notes: NoteStrs, links: LinkDicts},
            (   Residues == []
            ->  Reply = Reply0
            ;   maplist(residue_dict, Residues, RDs),
                Reply = Reply0.put(_{partial: true, residues: RDs})
            )
        ;   Outcome = refused(Problems1)
        ->  resolve_problem_places(KB, Problems1, Problems),
            export_refusal(Title, Problems, Options, Reply1),
            (   option(partial(true), Options)
            ->  le_i18n:le_msg(export_partial_impossible, [], PM),
                Reply = Reply1.put(partial_impossible, PM)
            ;   Reply = Reply1
            )
        ;   Outcome = failed(Msg),
            to_string(Msg, MsgS),
            Reply = _{error: MsgS}
        )
    ;   le_i18n:le_msg(export_no_exporter, [id-Id], M),
        Reply = _{error: M}
    ).

%   The check, then the export: ok(Name, Text, Notes, Links, []),
%   refused(Problems) or failed(Message).
export_outcome(Id, KB, Export, Options, Outcome) :-
    (   export_check(Id, Check)
    ->  catch(( call(Check, KB, Options, Problems0) -> true
              ; Problems0 = [problem(none, "the exporter's check failed")] ),
              E0, ( error_text(E0, M0), Problems0 = [problem(none, M0)] ))
    ;   Problems0 = []
    ),
    (   Problems0 \== []
    ->  Outcome = refused(Problems0)
    ;   Options1 = [checked(true)|Options],
        catch(( call(Export, KB, Options1, R) ->
                ( R = exported(Name, Text, Notes, Links) -> Outcome = ok(Name, Text, Notes, Links, [])
                ; R = refused(Ps) -> Outcome = refused(Ps)
                ; Outcome = failed("the exporter failed") )
              ; Outcome = failed("the exporter failed") ),
              E, ( error_text(E, Msg0), Outcome = failed(Msg0) ))
    ).

		 /*******************************
		 *        PARTIAL EXPORTS       *
		 *******************************/

/*  A refused program can still be written in part, when the reader asks for
    it (partial(true) in Options: the "Write anyway, with residues" button of
    the refusal). Nothing about the refusal changes; this is a second answer
    the reader chooses, knowing what it lacks.

      1. The program is loaded again, into a temporary module of its own (the
         one export_kb/4 was given is shared: le_kbs:load_text/3 caches it).
      2. Every problem is placed on the clauses it is about: at(Start, End)
         and line(N) on the clauses whose text they overlap, predicate(F/N)
         on every clause of F/N. A problem with no place (`none`) cannot be
         left out, and the export stays refused.
      3. Those clauses are removed, and with them every clause that uses a
         predicate one of them defined, transitively: a rule left in the
         output that calls a predicate which lost a clause would mean less
         than it says. Queries that use one are removed too.
      4. The exporter's check runs again on what is left, and 2–3 repeat
         until it passes (or nothing more can be removed: then refused).
      5. The exporter writes what is left, with partial(Residues) in its
         Options, and every residue is appended to its text as a comment in
         the target's syntax (export_comment_style/2): its line, why it was
         left out, and its Logical English text.

    The reply is the export's, with `partial: true` and `residues` ({line,
    reason, text}). */

%!  export_comment_style(?Id, ?Style) is nondet.
%
%   How the exporter Id's target writes a comment: line(Prefix),
%   block(Open, Close), or prose (a literate format: the text outside the
%   code is free text, as in Catala). Without a clause, the style follows the
%   extension of the file the exporter writes (comment_style_of_extension/2).
:- multifile export_comment_style/2.

comment_style(Id, Ext, Style) :-
    (   export_comment_style(Id, S) -> Style = S
    ;   comment_style_of_extension(Ext, S) -> Style = S
    ;   Style = line("#")
    ).

comment_style_of_extension(Ext, block("<!--", "-->")) :- memberchk(Ext, [xml, lrml, dmn, bpmn, rdf, owl, html]).
comment_style_of_extension(Ext, line("--")) :- memberchk(Ext, [daml, hs, sql, lean, elm]).
comment_style_of_extension(Ext, line("#")) :- memberchk(Ext, [py, yaml, yml, toml, sh, rb, r, policy]).
comment_style_of_extension(Ext, line("//")) :- memberchk(Ext, [sol, js, ts, java, c, cpp, rosetta, go, rs, scala, kt, minsc, drl]).
comment_style_of_extension(Ext, line("%")) :- memberchk(Ext, [pl, le, lps, tex]).
comment_style_of_extension(Ext, prose) :- memberchk(Ext, [catala_en, catala_fr, md]).
comment_style_of_extension(json, none).

partial_export(Id, Ext, Export, Problems0, Options, Outcome) :-
    (   memberchk(text(Doc0), Options), ( string(Doc0) ; atom(Doc0) )
    ->  to_string(Doc0, Doc),
        option(base(Base), Options, (-)),
        catch(in_temporary_module(M, true,
                  partial_in(M, Doc, Base, Id, Ext, Export, Problems0, Options, Outcome1)),
              E, ( print_message(warning, E), Outcome1 = refused(Problems0) ))
    ->  (   Outcome1 = refused(Ps)          % a later round's problems, with the first's
        ->  append(Problems0, Ps, Ps1), list_to_set(Ps1, Ps2), Outcome = refused(Ps2)
        ;   Outcome = Outcome1
        )
    ;   Outcome = refused(Problems0)
    ).

partial_in(M, Doc, Base, Id, Ext, Export, Problems0, Options, Outcome) :-
    le_kbs:load_text(Doc, Base, M),
    partial_loop(M, Doc, Id, Export, Problems0, Options, [], 0, Outcome0),
    (   Outcome0 = ok(Name, Text0, Notes, Links, Residues), Residues \== []
    ->  comment_style(Id, Ext, Style),
        residue_comments(Style, Residues, Comments),
        (   Style == none
        ->  Text = Text0
        ;   string_concat(Text0, Comments, Text)
        ),
        length(Residues, NR),
        le_i18n:le_msg(export_partial_note, [n-NR], Note),
        Outcome = ok(Name, Text, [Note|Notes], Links, Residues)
    ;   Outcome = Outcome0
    ).

partial_loop(M, Doc, Id, Export, Problems, Options, Done, Round, Outcome) :-
    problems_clauses(M, Doc, Problems, Placed, Unplaced),
    (   Unplaced \== []
    ->  Outcome = refused(Problems)
    ;   Round > 20
    ->  Outcome = refused(Problems)
    ;   cascade(M, Placed, Removed),
        Removed \== []
    ->  maplist(removed_residue(M, Doc), Removed, New),
        maplist(erase_removed, Removed),
        append(Done, New, Done1),
        Options1 = [partial(Done1)|Options],
        export_outcome(Id, M, Export, Options1, O1),
        (   O1 = ok(Name, Text, Notes, Links, _)
        ->  sort_residues(Done1, Residues),
            Outcome = ok(Name, Text, Notes, Links, Residues)
        ;   O1 = refused(Ps)
        ->  Round1 is Round + 1,
            partial_loop(M, Doc, Id, Export, Ps, Options, Done1, Round1, Outcome)
        ;   Outcome = O1
        )
    ;   Outcome = refused(Problems)
    ).

%   The program's own clauses: Ref-c(Head, Body, Start, End).
own_clause(M, Ref, c(H, B, S, E)) :-
    current_predicate(M:F/N),
    (   \+ le_kbs:is_system_predicate(F/N)
    ;   memberchk(F/N, [le_constraint/1, query_info/3, le_lps_item/3])
    ),
    functor(H, F, N),
    le_kbs:kb_own_predicate(M, H),
    clause(M:H, B, Ref),
    catch(M:le_source_info(Ref, S, E, _), _, fail),
    integer(S),                     % an included resource's clauses too (S >= 10000000)
    \+ H = le_lps_item(setting, _, _).

%   Each problem's clauses: Placed is a list of Ref-Reason, Unplaced the
%   problems that name no place.
problems_clauses(M, Doc, Problems, Placed, Unplaced) :-
    foldl(problem_clauses(M, Doc), Problems, []-[], Placed0-Unplaced),
    keep_first(Placed0, Placed).    % one entry per clause, however many problems name it

problem_clauses(M, Doc, P, Pl0-Un0, Pl-Un) :-
    (   P = problem(Where, Msg0) -> true ; Where = none, Msg0 = P ),
    to_string(Msg0, Msg),
    findall(Ref-because(Msg), where_clause(M, Doc, Where, Ref), Refs),
    (   Refs == []
    ->  Pl = Pl0, Un = [P|Un0]
    ;   append(Pl0, Refs, Pl), Un = Un0
    ).

where_clause(M, _, at(S, E), Ref) :-
    integer(S), ( integer(E) -> E1 = E ; E1 = S ),
    own_clause(M, Ref, c(_, _, CS, CE)),
    CS =< E1, S =< CE.
where_clause(M, Doc, line(L), Ref) :-
    integer(L),
    line_offsets(Doc, L, S, E),
    where_clause(M, Doc, at(S, E), Ref).
where_clause(M, _, predicate(F/N), Ref) :-
    own_clause(M, Ref, _),
    clause_defines(Ref, F/N).       % its clauses, or the LPS sentences that change it

line_offsets(Doc, L, S, E) :-
    split_string(Doc, "\n", "", Lines),
    length(Before, L0), L0 is L - 1,
    append(Before, [Line|_], Lines), !,
    foldl([X, A0, A]>>(string_length(X, XL), A is A0 + XL + 1), Before, 0, S),
    string_length(Line, LL), E is S + LL.

%   The placed clauses and every clause that depends on one, transitively:
%   Ref-Reason, Reason because(Message) or uses(F/N).
cascade(M, Placed, Removed) :-
    findall(F/N, ( member(Ref-_, Placed), clause_defines(Ref, F/N) ), PIs0),
    sort(PIs0, PIs),
    cascade_(M, PIs, Placed, Removed).

cascade_(M, PIs, Acc, Removed) :-
    findall(Ref-uses(F/N),
            ( own_clause(M, Ref, c(H, B, _, _)),
              \+ memberchk(Ref-_, Acc),
              body_of(H, B, Body),
              member(F/N, PIs),
              uses_predicate(Body, F/N) ),
            New0),
    keep_first(New0, New),
    (   New == []
    ->  Removed = Acc
    ;   append(Acc, New, Acc1),
        findall(F/N, ( member(Ref-_, New), clause_defines(Ref, F/N) ), More0),
        append(PIs, More0, PIs1), sort(PIs1, PIs2),
        cascade_(M, PIs2, Acc1, Removed)
    ).

keep_first(Pairs, Kept) :-
    foldl([R-W, K0, K]>>( memberchk(R-_, K0) -> K = K0 ; K = [R-W|K0] ), Pairs, [], Rev),
    reverse(Rev, Kept).

%   What leaving a clause out takes away: the predicates whose meaning it
%   changes. A rule or fact: its own. A query or a constraint: none (nothing
%   calls them). An LPS sentence of a Logical English for LPS program
%   (le_lps_item/3, read by le_lps.pl): a head rule its head; a causal law
%   (`when`) the fluents it changes; `initially` the fluents it sets; a
%   reactive rule, a constraint or a goal none — what they call keeps its
%   meaning in the target, it is only not acted on, or not refused.
clause_defines(Ref, PI) :-
    clause(H0, _, Ref), strip_module(H0, _, H),
    (   H = le_lps_item(Kind, Payload, _)
    ->  lps_item_defines(Kind, Payload, PI)
    ;   functor(H, F, N),
        \+ memberchk(F/N, [le_constraint/1, query_info/3]),
        PI = F/N
    ).

lps_item_defines(head_rule, h(Head, _), PI) :- !, goal_pis(Head, PI).
lps_item_defines(when, r(_, Effects), PI) :- !, goal_pis(Effects, PI).
lps_item_defines(initially, Facts, PI) :- !, goal_pis(Facts, PI).

%   The predicates a goal of an LPS sentence names, through its wrappers.
goal_pis(G, _) :- var(G), !, fail.
goal_pis(le_at(G, _, _), PI) :- !, goal_pis(G, PI).
goal_pis(lps_at(G, _), PI) :- !, goal_pis(G, PI).
goal_pis(not(G), PI) :- !, goal_pis(G, PI).
goal_pis(lps_becomes(F, _, _), PI) :- !, goal_pis(F, PI).
goal_pis(and(A, B), PI) :- !, ( goal_pis(A, PI) ; goal_pis(B, PI) ).
goal_pis((A, B), PI) :- !, ( goal_pis(A, PI) ; goal_pis(B, PI) ).
goal_pis([X|Xs], PI) :- !, ( goal_pis(X, PI) ; goal_pis(Xs, PI) ).
goal_pis(G, F/N) :- callable(G), G \== [], G \== true, functor(G, F, N).

clause_head_pi(Ref, F/N) :-
    clause_property(Ref, predicate(_:F/N)), !.
clause_head_pi(Ref, F/N) :-
    clause(H, _, Ref), strip_module(H, _, H1), functor(H1, F, N).

%   What a clause's conditions are: a rule's body; a query's goal; a
%   constraint's body.
body_of(query_info(_, G, _), true, G) :- !.
body_of(le_lps_item(_, Payload, _), true, Payload) :- !.
body_of(_, B, B).

uses_predicate(Body, F/N) :-
    sub_term(T, Body), callable(T), functor(T, F, N), !.

%   erase/1 fails on a clause already erased: never let that fail the export.
erase_removed(Ref-_) :- ( catch(erase(Ref), _, true) -> true ; true ).

%   A clause about to be removed, as a residue: its line and text, read
%   before the clause is erased (its source info is keyed by its reference).
removed_residue(M, Doc, Ref-Why, residue(Line, Reason, Text)) :-
    (   catch(M:le_source_info(Ref, S, E, _), _, fail),
        string_length(Doc, Len), integer(S), S < Len
    ->  where_line(at(S, E), Doc, Line, Text)
    ;   %  a clause of an included resource: no line of this document
        Line = null,
        (   catch(clause(H, B, Ref), _, fail)
        ->  strip_module(H, _, H1),
            ( B == true -> format(string(Text), "~q", [H1]) ; format(string(Text), "~q :- ~q", [H1, B]) )
        ;   Text = null
        )
    ),
    why_text(M, Why, Reason).

why_text(_, because(Msg), Msg) :- !.
why_text(M, uses(F/N), Msg) :- !,
    (   catch(le_writer:kb_templates(M, Ts), _, fail),
        member(template(F, T, _), Ts)
    ->  format(string(P), "\"~w\"", [T])
    ;   format(string(P), "~w/~w", [F, N])
    ),
    le_i18n:le_msg(export_residue_uses, [predicate-P], Msg).

sort_residues(Rs0, Rs) :-
    list_to_set(Rs0, Rs1),
    predsort([O, residue(LA, RA, TA), residue(LB, RB, TB)]>>(
                 line_key(LA, KA), line_key(LB, KB),
                 compare(O0, KA-TA-RA, KB-TB-RB), ( O0 == (=) -> O = (<) ; O = O0 )),
             Rs1, Rs).

residue_dict(residue(L, R, T), _{line: L, reason: R, text: T}).

%   The residues as one comment block, in the target's syntax.
residue_comments(Style, Residues, Text) :-
    length(Residues, N),
    le_i18n:le_msg(export_residues_heading, [n-N], Heading),
    findall(Ls, ( member(residue(L, R, T), Residues), residue_lines(L, R, T, Ls) ), Lss),
    append(Lss, Body),
    comment_block(Style, [Heading, ""|Body], Text).

residue_lines(L, R, T, Lines) :-
    (   L == null
    ->  le_i18n:le_msg(export_residue_included, [reason-R], Head)
    ;   format(string(LS), "~w", [L]),
        le_i18n:le_msg(export_residue_line, [line-LS, reason-R], Head)
    ),
    ( T == null -> TL = [] ; wrap_text(T, 76, TL0), maplist([X, Y]>>string_concat("    ", X, Y), TL0, TL) ),
    append([[Head], TL, [""]], Lines).

comment_block(line(P), Lines, Text) :-
    maplist(prefixed_line(P), Lines, Os),
    atomic_list_concat(["\n"|Os], T), atom_string(T, Text).
comment_block(block(Open, Close), Lines, Text) :-
    maplist(block_line(Close), Lines, Os),
    atomic_list_concat(["\n", Open, "\n"|Os], T0),
    atomic_list_concat([T0, Close, "\n"], T), atom_string(T, Text).
comment_block(prose, Lines, Text) :-
    maplist([L, O]>>format(string(O), "~w~n", [L]), Lines, Os),
    atomic_list_concat(["\n"|Os], T), atom_string(T, Text).
comment_block(none, _, "").

prefixed_line(P, L, O) :-
    (   L == "" -> format(string(O), "~w~n", [P]) ; format(string(O), "~w ~w~n", [P, L]) ).

block_line(Close, L, O) :-
    safe_in_block(Close, L, L1),
    format(string(O), "  ~w~n", [L1]).

%   A comment's closing mark (`-->`) and, for XML, `--` may not occur in it.
safe_in_block("-->", L, L1) :- !,
    split_string(L, "", "", [L0]),
    atomic_list_concat(Parts, '--', L0), atomic_list_concat(Parts, '- -', A), atom_string(A, L1).
safe_in_block(Close, L, L1) :-
    atomic_list_concat(Parts, Close, L), atomic_list_concat(Parts, ' ', A), atom_string(A, L1).

wrap_text(T, W, Lines) :-
    split_string(T, " \n\t", " \n\t", Ws0), exclude(==(""), Ws0, Ws),
    wrap_words(Ws, W, "", Lines).
wrap_words([], _, "", []) :- !.
wrap_words([], _, Cur, [Cur]).
wrap_words([X|Xs], W, "", Ls) :- !, wrap_words(Xs, W, X, Ls).
wrap_words([X|Xs], W, Cur, Ls) :-
    string_length(Cur, CL), string_length(X, XL),
    (   CL + 1 + XL =< W
    ->  string_concat(Cur, " ", C1), string_concat(C1, X, C2), wrap_words(Xs, W, C2, Ls)
    ;   Ls = [Cur|Ls1], wrap_words(Xs, W, X, Ls1)
    ).

%!  resolve_problem_places(+KB, +Problems0, -Problems) is det.
%
%   predicate(F/N) shown at the template that declares F/N (or its first
%   clause), so that the refusal still names a line for it.
resolve_problem_places(KB, Ps0, Ps) :-
    maplist(resolve_place(KB), Ps0, Ps).

resolve_place(KB, problem(predicate(F/N), Msg), problem(Where, Msg)) :- !,
    (   template_span(KB, F/N, S, E) -> Where = at(S, E)
    ;   own_clause(KB, _, c(H, _, S, E)), functor(H, F, N) -> Where = at(S, E)
    ;   Where = none
    ).
resolve_place(_, P, P).

template_span(KB, F/N, S, E) :-
    current_predicate(KB:le_dict/1),
    clause(KB:le_dict(dict([F|Args], _, _, _, _, _, _)), true, Ref),
    length(Args, N),
    catch(KB:le_source_info(Ref, S, E, _), _, fail), !.

%!  item_source_line(+ItemOptions, -Line) is semidet.
%
%   The program line an IR item (rule, fact, constraint) came from, when the
%   IR was made with le_writer:kb_to_ir/3 and the program's text.
item_source_line(Opts, Line) :-
    is_list(Opts), memberchk(source(Line, _, _), Opts), integer(Line).

%!  export_refusal(+Target, +Problems, +Options, -Reply:dict) is det.
%
%   The reply of a refused translation, shared by every converter of an LE
%   or LPS program into another system (the exporters here, See s(CASP),
%   LE to LPS): `error` (one sentence naming the target and how many
%   problems), `exporter` (Target) and `problems`, each `{line, message,
%   text}`, in the order of the program's lines, those with no line last.
%   Options' text(Doc) turns character offsets into lines.
export_refusal(Target, Problems0, Options, Reply) :-
    ( memberchk(text(Doc0), Options), ( string(Doc0) ; atom(Doc0) ) -> to_string(Doc0, Doc) ; Doc = "" ),
    list_to_set(Problems0, Problems1),
    maplist(problem_dict(Doc), Problems1, Dicts1),
    predsort(problem_order, Dicts1, Dicts),
    length(Dicts, N),
    to_string(Target, TargetS),
    le_i18n:le_msg(export_refused, [target-TargetS, n-N], Msg),
    Reply = _{error: Msg, exporter: TargetS, problems: Dicts}.

%!  kb_constraint_problems(+KB, +Target, -Problems) is det.
%
%   A problem for each integrity constraint of the program (`it must not be
%   true that …`, le_constraint/1 clauses: docs/user/reference/language.md), for an
%   exporter whose target has no constraints: the Migration IR does not
%   carry them (they are LE's own predicate), so an exporter that reads only
%   the IR would drop them without a word.
kb_constraint_problems(KB, Target, Problems) :-
    findall(problem(at(S, E), Msg),
            ( current_predicate(KB:le_constraint/1),
              clause(KB:le_constraint(_), _, Ref),
              ( catch(KB:le_source_info(Ref, S, E, _), _, fail) -> true ; S = none, E = none ),
              le_i18n:le_msg(export_constraint_problem, [target-Target], Msg) ),
            Problems).

problem_dict(Doc, problem(Where, Msg0), _{line: Line, message: Msg, text: Text}) :- !,
    to_string(Msg0, Msg),
    where_line(Where, Doc, Line, Text).
problem_dict(Doc, Msg, D) :- problem_dict(Doc, problem(none, Msg), D).

where_line(line(L), Doc, L, Text) :- integer(L), !, line_text(Doc, L, Text).
where_line(at(S, E), Doc, Line, Text) :-
    integer(S), string_length(Doc, Len), S < Len, !,
    sub_string(Doc, 0, S, _, Before),
    split_string(Before, "\n", "", Parts), length(Parts, Line),
    (   integer(E), E > S, E =< Len
    ->  L is E - S, sub_string(Doc, S, L, _, T0), normalize_space(string(Text), T0)
    ;   line_text(Doc, Line, Text)
    ).
where_line(_, _, null, null).

line_text(Doc, L, Text) :-
    split_string(Doc, "\n", "", Lines),
    (   nth1(L, Lines, T0) -> normalize_space(string(Text), T0) ; Text = null ).

problem_order(O, A, B) :-
    line_key(A.line, KA), line_key(B.line, KB),
    compare(O0, KA-A.message, KB-B.message),
    ( O0 == (=) -> O = (<) ; O = O0 ).

line_key(null, 1.0Inf) :- !.
line_key(L, L).

load_exporter(File) :-
    exists_file(File),
    catch(load_files(File, [if(not_loaded)]), E, ( print_message(warning, E), fail )).

/** <module> Opening an Oracle Intelligent Advisor project in the LE editor

    The adapter LE2's File ▸ Open registry (`le_import.pl`, importer/6)
    calls for OIA material: the same translation as oia_migrate.pl's twins,
    over whatever was uploaded —

      - one compiled Word/Excel rule document, `<doc>.docx.xgen`;
      - a deployed rulebase, `rulebase.xml` (its sentence forms are read from
        `rulebase.stxt` beside it when the upload has one);
      - a zip of a Policy Modeling project folder (the .xprj, the bin folder's
        .xgen files, `projectDataModel.xml`, Excel test files,
        `testResults.xml`) or of a
        deployed rulebase, extracted by the registry, possibly one folder
        deep;
      - since October 2026, the rules as their authors write them
        (oia_text.pl): Word rule documents (`.docx`, one or a project's
        `Rules` folder zipped, with `projectDataModel.xml` when there is one),
        `.ruletxt` files, and a Hub project exported as JSON (a decision
        service or a flow). A project with both its Word documents and its
        compiled `.xgen` files is read from the compiled ones, which Policy
        Modeling checked.

    The program, its ledger, the rule documents' paragraphs (which the rules
    quote) and lib/temporal when the rules need it are written into the
    output directory. A rule the translator cannot map is a residue block
    in the program (le_writer writes it as a TODO comment holding the rule's
    XML); an .xgen that cannot be read at all is a TODO comment of its own;
    neither stops the import. A project without test files gets the cases of
    its rules' own analysis (oia_analysis.pl) as scenarios.
*/

:- module(oia_import, [import_oia/3, detect_oia/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module(library(process)).
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).
:- use_module(oia_reader).
:- use_module(oia_ir).
:- use_module(oia_migrate, []).

%!  detect_oia(+Input) is semidet.
%
%   Input (a file, or the directory an archive was extracted into) is OIA
%   material.
detect_oia(Input) :-
    exists_directory(Input), !,
    (   oia_files(Input, xgen, [_|_]) -> true
    ;   oia_files(Input, rulebase, [_|_]) -> true
    ;   oia_files(Input, xprj, [_|_]) -> true
    ;   oia_files(Input, docx, [_|_]) -> true
    ;   oia_files(Input, ruletxt, [_|_]) -> true
    ;   oia_files(Input, hub, [_|_])
    ).
detect_oia(Input) :-
    exists_file(Input),
    file_name_extension(_, Ext0, Input), downcase_atom(Ext0, Ext),
    (   memberchk(Ext, [xgen, stxt, xprj, ruletxt]) -> true
    ;   Ext == xml, rulebase_xml(Input) -> true
    ;   Ext == docx, opm_docx(Input) -> true
    ;   Ext == json, hub_json(Input)
    ).

%   A Word document with Policy Modeling's paragraph styles.
opm_docx(File) :-
    catch(( process_create(path(python3),
                           ['-c', "import sys, zipfile; z = zipfile.ZipFile(sys.argv[1]); print('OPM' in z.read('word/styles.xml').decode('utf-8', 'ignore'))", File],
                           [stdout(pipe(Out)), stderr(null), process(Pid)]),
            read_string(Out, _, Res), close(Out), process_wait(Pid, _),
            sub_string(Res, 0, 4, _, "True") ), _, fail).

%   A Hub project exported as JSON: rule documents and a contract or a flow.
hub_json(File) :-
    catch(( setup_call_cleanup(open(File, read, S, [encoding(utf8)]), read_string(S, 20000, Head), close(S)),
            sub_string(Head, _, _, _, "\"rule-block\"") ;
            setup_call_cleanup(open(File, read, S2, [encoding(utf8)]), read_string(S2, _, All), close(S2)),
            sub_string(All, _, _, _, "\"rule-block\"") ), _, fail), !.

rulebase_xml(File) :-
    setup_call_cleanup(open(File, read, S, [encoding(utf8)]),
                       read_string(S, 4000, Head), close(S)),
    sub_string(Head, _, _, _, "<rulebase").

oia_files(Dir, xgen, Fs) :- findall(F, ( dir_file(Dir, F), file_name_extension(_, xgen, F) ), Fs).
oia_files(Dir, rulebase, Fs) :- findall(F, ( dir_file(Dir, F), file_base_name(F, 'rulebase.xml') ), Fs).
oia_files(Dir, xprj, Fs) :- findall(F, ( dir_file(Dir, F), file_name_extension(_, xprj, F) ), Fs).
oia_files(Dir, docx, Fs) :- findall(F, ( dir_file(Dir, F), file_name_extension(_, docx, F),
                                         file_base_name(F, B), \+ sub_atom(B, 0, _, _, '~'), opm_docx(F) ), Fs).
oia_files(Dir, ruletxt, Fs) :- findall(F, ( dir_file(Dir, F), file_name_extension(_, ruletxt, F) ), Fs).
oia_files(Dir, hub, Fs) :- findall(F, ( dir_file(Dir, F), file_name_extension(_, json, F), hub_json(F) ), Fs).

dir_file(Dir, F) :-
    directory_member(Dir, F, [recursive(true)]),
    \+ sub_atom(F, _, _, _, '/out/'),
    \+ sub_atom(F, _, _, _, '/__MACOSX/'),
    exists_file(F).

%!  import_oia(+Input, +OutDir, -Result) is det.
%
%   Result = imported(LEFile, Notes).
import_oia(Input, OutDir, Result) :-
    once(import_oia_(Input, OutDir, Result)).

import_oia_(Input, OutDir, imported(LEFile, Notes)) :-
    project_of(Input, Dir, Kind, Name, Notes0),
    catch(read_project(Dir, Kind, Name, Model, Unread), E, ( message_to_codes(E, M), fail_read(Dir, Kind, M) )),
    test_files(Dir, Kind, TestFiles, Notes1),
    atomic_list_concat([Dir, '/testResults.xml'], TR),
    ( exists_file(TR) -> Opts0 = [test_results(TR)] ; Opts0 = [] ),
    project_title(Input, Dir, Name, Title),
    Opts = [title(Title), licence('as uploaded to the editor'),
            artifacts([Input])|Opts0],
    oia_migrate:with_line_start(oia_migration(Model, TestFiles, Opts, Migration)),
    Migration = migration(Meta, program(Header0, Items0), Ledger, Tests),
    append(Unread, Items0, Items),
    Header = Header0,
    Migration1 = migration(Meta, program(Header, Items), Ledger, Tests),
    oia_migrate:write_doc_texts(Model, OutDir),
    forall(( memberchk(includes(Inc), Header), member(Lib, Inc) ), copy_library(Lib, OutDir)),
    oia_migrate:with_line_start(write_migration(Migration1, OutDir, Name, Report)),
    atomic_list_concat([OutDir, '/', Name, '.le'], LEFile),
    report_notes(Report, Ledger, Tests, Notes2),
    ( Unread == [] -> Notes3 = [] ; length(Unread, NU), format(string(N3), "~w rule document(s) could not be read: TODO comments in the program", [NU]), Notes3 = [N3] ),
    append([Notes0, Notes1, Notes3, Notes2], Notes).

fail_read(Dir, Kind, M) :-
    format(string(S), "could not read the ~w project in ~w: ~s", [Kind, Dir, M]),
    throw(error(oia_import(S), _)).

message_to_codes(E, Codes) :-
    catch(message_to_codes(E, [], Codes0), _, fail), !, Codes = Codes0.
message_to_codes(E, Codes) :- format(codes(Codes), "~q", [E]).

%   The project directory, its kind and a program name from what was
%   uploaded. A single file is a project of one document (its directory
%   holds nothing else the reader would take: the upload's own folder).
project_of(Input, Dir, Kind, Name, Notes) :-
    exists_directory(Input), !,
    (   oia_files(Input, xgen, [F|_])
    ->  Kind = xgen, project_root(Input, F, Dir)
    ;   oia_files(Input, rulebase, [F|_])
    ->  Kind = rulebase, file_directory_name(F, Dir)
    ;   oia_files(Input, docx, [F|_])
    ->  Kind = docx, project_root(Input, F, Dir)
    ;   oia_files(Input, ruletxt, [F|_])
    ->  Kind = ruletxt, file_directory_name(F, Dir)
    ;   oia_files(Input, hub, [F|_])
    ->  Kind = hub(F), file_directory_name(F, Dir)
    ;   throw(error(oia_import("no rules in the upload: neither Word rule documents nor .ruletxt files, a Hub project's JSON, compiled .xgen files or a rulebase.xml"), _))
    ),
    project_name(Input, Dir, Name),
    ( Kind == rulebase, \+ exists_file_in(Dir, 'rulebase.stxt')
    ->  Notes = ["rulebase.stxt is not in the upload: the attributes' authored sentence forms (negative, question) are missing; the sentences are the rulebase's own text"]
    ;   Notes = [] ).
project_of(Input, Dir, Kind, Name, Notes) :-
    file_directory_name(Input, Dir),
    file_base_name(Input, Base),
    file_name_extension(_, Ext0, Base), downcase_atom(Ext0, Ext),
    (   Ext == xgen -> Kind = xgen, Notes = [],
        ( atom_concat(D0, '.xgen', Base) -> true ; D0 = Base ),
        file_name_extension(Stem, _, D0)
    ;   Ext == docx -> Kind = docx, Notes = [], file_name_extension(Stem, _, Base)
    ;   Ext == ruletxt -> Kind = ruletxt, Notes = [], file_name_extension(Stem, _, Base)
    ;   Ext == json -> Kind = hub(Input), Notes = [], file_name_extension(Stem, _, Base)
    ;   memberchk(Ext, [xml, stxt]) -> Kind = rulebase,
        file_name_extension(Stem, _, Base),
        (   exists_file_in(Dir, 'rulebase.xml') -> true
        ;   Ext == xml -> rename_to_rulebase(Input, Dir)
        ;   throw(error(oia_import("a rulebase.stxt alone has no rules: upload rulebase.xml (or both, zipped)"), _))
        ),
        ( exists_file_in(Dir, 'rulebase.stxt') -> Notes = []
        ; Notes = ["rulebase.stxt was not uploaded with rulebase.xml: the authored sentence forms (negative, question) are missing"] )
    ),
    name_from(Stem, Name).

exists_file_in(Dir, F) :- atomic_list_concat([Dir, '/', F], P), exists_file(P).

rename_to_rulebase(Input, Dir) :-
    atomic_list_concat([Dir, '/rulebase.xml'], RB),
    copy_file(Input, RB).

%   A Policy Modeling project: the folder with the .xprj, else the one
%   above the .xgen's bin folder, else the .xgen's own.
project_root(Input, XgenFile, Dir) :-
    (   oia_files(Input, xprj, [P|_]) -> file_directory_name(P, Dir)
    ;   file_directory_name(XgenFile, D0), file_base_name(D0, B0), memberchk(B0, [bin, 'Rules']) -> file_directory_name(D0, Dir)
    ;   file_directory_name(XgenFile, Dir)
    ).

project_name(Input, Dir, Name) :-
    (   oia_files(Input, xprj, [P|_]) -> file_base_name(P, B), file_name_extension(S, _, B)
    ;   file_base_name(Dir, S0), S0 \== in, S0 \== '' -> S = S0
    ;   file_base_name(Input, S)
    ),
    name_from(S, Name).

%   The project's own name for the title (its .xprj, or its folder).
project_title(Input, Dir, Name, Title) :-
    (   exists_directory(Input), oia_files(Input, xprj, [P|_]) -> file_base_name(P, B), file_name_extension(T, _, B)
    ;   exists_directory(Input), file_base_name(Dir, T0), T0 \== in -> T = T0
    ;   T = Name
    ),
    format(string(Title), "~w", [T]).

name_from(S0, Name) :-
    downcase_atom(S0, L), atom_codes(L, Cs0),
    maplist(name_code, Cs0, Cs1),
    atom_codes(A, Cs1), atomic_list_concat(Ps0, '_', A), exclude(==(''), Ps0, Ps),
    (   Ps == [] -> Name = oia_project
    ;   atomic_list_concat(Ps, '_', N0),
        ( sub_atom(N0, 0, 1, _, F), char_type(F, digit) -> atom_concat(p_, N0, Name) ; Name = N0 )
    ).

name_code(C, D) :- ( code_type(C, alnum), C < 128 -> D = C ; D = 0'_ ).

%   The model, read as oia_reader reads a project, from the documents it can
%   read: an .xgen that is not well-formed XML, or that the reader cannot
%   take, is left out, and becomes a residue block (a TODO comment holding
%   the start of its XML) instead of failing the import.
read_project(Dir, xgen, Name, oia(Name, Attrs, Rules, Docs), Unread) :- !,
    oia_files(Dir, xgen, Fs0), msort(Fs0, Fs),
    oia_reader:data_model_types(Dir, Types),
    partition(readable_xgen(Types), Fs, Good, Bad),
    foldl(oia_reader:read_xgen(Types), Good, a([], [], []), a(Attrs0, Rules0, Docs0)),
    oia_reader:merge_attrs(Attrs0, Attrs),
    reverse(Rules0, Rules), reverse(Docs0, Docs),
    findall(residue(Id, [title(B), locator(B), source(xml, Head),
                         note("TODO: this rule document could not be read by the translator; its rules are not in the program")]),
            ( member(F, Bad), file_base_name(F, B),
              oia_ir:doc_slug(B, Id0), atom_concat(unreadable_, Id0, Id),
              xml_head(F, Head) ),
            Unread).
read_project(Dir, Kind, Name, Model, []) :-
    memberchk(Kind, [rulebase]), !,
    oia_read_project(Dir, Kind, Name, Model).
read_project(Dir, Kind, Name, Model, []) :-
    %  the rules as written: Word, .ruletxt, a Hub project (oia_text.pl)
    (   Kind = hub(F) -> file_base_name(F, B), Kind1 = hub(B) ; Kind1 = Kind ),
    oia_migrate:read_model(Dir, Kind1, Name, Model).

%   A complete document (Policy Modeling writes the closing root tag last;
%   the XML parser would silently mend a truncated one) that the reader
%   takes without error — its complaints silenced while trying.
readable_xgen(Types, F) :-
    read_file_to_string(F, S, [encoding(utf8)]),
    sub_string(S, _, _, _, "</root>"),
    setup_call_cleanup(asserta((user:message_hook(_, error, _) :- true), Ref),
                       catch(oia_reader:read_xgen(Types, F, a([], [], []), _), _, fail),
                       erase(Ref)), !.

xml_head(F, Head) :-
    read_file_to_string(F, S, [encoding(utf8)]),
    ( string_length(S, L), L > 1500 -> sub_string(S, 0, 1500, _, H0), string_concat(H0, " ...", Head) ; Head = S ).

%   Excel test files: every .xlsx of the project that is not a rule
%   document (a rule document has a compiled .xgen of its own) and in which
%   oia_tests.py finds cases. Without python3 + openpyxl: none, and a note.
test_files(Dir, _Kind, Files, Notes) :-
    findall(F, ( dir_file(Dir, F), file_name_extension(_, Ext, F), downcase_atom(Ext, xlsx),
                 \+ rule_document(Dir, F) ), Cands),
    (   Cands == [] -> Files = [], Notes = []
    ;   \+ openpyxl_available
    ->  Files = [],
        length(Cands, N),
        format(string(Note), "~w Excel test file(s) not read: python3 with openpyxl is needed (pip install openpyxl)", [N]),
        Notes = [Note]
    ;   include(has_cases, Cands, Files),
        Notes = []
    ).

rule_document(Dir, F) :-
    file_base_name(F, B),
    atomic_list_concat([B, '.xgen'], X),
    oia_files(Dir, xgen, Xs), member(XF, Xs), file_base_name(XF, X), !.

has_cases(F) :-
    catch(( oia_load_tests([F], [file(_, Cases)]), Cases \== [] ), _, fail).

openpyxl_available :-
    catch(( process_create(path(python3), ['-c', 'import openpyxl'],
                           [stdout(null), stderr(null), process(P)]),
            process_wait(P, exit(0)) ), _, fail).

%   What the editor tells the user about the translation.
report_notes(report(_, _, Counts, Fidelity), Ledger, Tests, Notes) :-
    (   Counts = counts(E, A, R)
    ->  format(string(N1), "ledger: ~w encoded, ~w approximated, ~w residue (TODO in the program)", [E, A, R])
    ;   format(string(N1), "ledger: ~w", [Counts])
    ),
    length(Tests, NT),
    (   member(test(_, 'the analysis of the rules', _, _, _), Tests)
    ->  format(string(N2), "~w scenario(s) generated from the rules' own analysis (no test files)", [NT])
    ;   format(string(N2), "~w scenario(s) from the project's test files", [NT])
    ),
    (   Fidelity = fidelity(P, F, U, _)
    ->  format(string(N3), "the scenarios run: ~w pass, ~w fail, ~w error", [P, F, U])
    ;   N3 = "the scenarios were not run"
    ),
    (   member(entry(_, _, approximated, _, _, _), Ledger)
    ->  N4 = ["approximated: OIA's unknown and uncertain states are read with LE's closed world (see the ledger)"]
    ;   N4 = []
    ),
    append([[N1, N2, N3], N4], Notes).
report_notes(_, _, _, []).

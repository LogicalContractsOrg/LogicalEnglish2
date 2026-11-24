/** <module> File ▸ Open of a spreadsheet: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    an Excel workbook (.xlsx, .xlsm). The program opened is the workbook's
    twin (xlsx_ir.pl): its inputs as templates a scenario states, its
    parameters as constants, its lookup ranges as decision tables, each
    formula a rule, and one query for each output. Its scenarios are the
    workbook's own answers (xlsx_tests.pl): the values Excel saved, and
    cases the sheet computed through LE2's sheet engine. The ledger lists
    every formula, table, input and parameter as encoded, approximated or
    residue.

    `.xls` and `.ods` files are refused with the reason: save them as .xlsx
    first (the sheet engine reads Office Open XML only).

    Options (import_workbook/4): inputs([Ref...]) the cells to take as inputs
    (when the workbook does not say: no protection, no validation),
    cases(N) the number of generated cases (default 12; 0 for none),
    seed(S), max_outputs(N) (default 200), name(Base).
*/

:- module(xlsx_import, [import_spreadsheet/3, detect_spreadsheet/1, import_workbook/4, workbook_migration/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(yall)).
:- use_module(library(option)).
:- use_module(library(filesex)).
:- use_module(library(zip)).
:- use_module(library(process)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module('../le2_paths').
:- use_module(le2(le_migration)).
:- use_module(xlsx_ir).
:- use_module(xlsx_tests).

%!  detect_spreadsheet(+Input) is semidet.
detect_spreadsheet(Input) :-
    exists_file(Input),
    file_name_extension(_, Ext0, Input), downcase_atom(Ext0, Ext),
    memberchk(Ext, [xlsx, xlsm, xls, ods]).

%!  import_spreadsheet(+Input, +OutDir, -Result) is det.
import_spreadsheet(Input, OutDir, Result) :-
    import_workbook(Input, OutDir, [], Result).

%!  import_workbook(+Input, +OutDir, +Options, -Result) is det.
import_workbook(Input, OutDir0, Options, imported(LEFile, Notes)) :-
    file_name_extension(_, Ext0, Input), downcase_atom(Ext0, Ext),
    (   memberchk(Ext, [xls, ods])
    ->  throw(error(format("~w is an .~w file: save it as .xlsx (Excel's own format) and open that; the sheet engine reads .xlsx and .xlsm", [Input, Ext]), _))
    ;   true
    ),
    absolute_file_name(OutDir0, OutDir),
    make_directory_path(OutDir),
    workbook_migration(Input, Options, Migration),
    Migration = migration(Meta, _, _, _),
    memberchk(program(Base), Meta),
    copy_original(Input, OutDir),
    write_macros(Input, OutDir),
    write_migration(Migration, OutDir, Base, Report0),
    known_departures(Migration, Options, OutDir, Base, Report0, report(LEFile, Issues, counts(E, A, R), Fid)),
    append_service_draft(Input, Base, LEFile),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    Migration = migration(_, _, _, Tests), length(Tests, NT),
    (   Fid = fidelity(P, F, U, _)
    ->  format(string(N1), "~w: ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors; ~w scenarios from the sheet's own values, their expectations: ~w pass, ~w fail, ~w errors.",
               [Base, E, A, R, NE, NT, P, F, U])
    ;   format(string(N1), "~w: ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors.", [Base, E, A, R, NE])
    ),
    workbook_migration_info(NI),
    (   NI > 500
    ->  format(string(N2), "The workbook has ~w cells taken as inputs (empty cells a formula reads, on sheets that do not say which cells are inputs): if that is too many, name the inputs (option inputs([...])) or the answer cells (option outputs([...])).", [NI]),
        Notes = [N1, N2]
    ;   Notes = [N1]
    ).

workbook_migration_info(NI) :- xlsx_ir:input_cells(Is), length(Is, NI).

%   known_departures([Scenario-Reason, ...]): the expectations of those
%   scenarios the twin does not reproduce, for a reason the ledger documents,
%   are written as pending with that reason (le_migration), and the program
%   is written again. Only the scenarios named, and only what fails there.
known_departures(Migration, Options, OutDir, Base, Report0, Report) :-
    (   option(known_departures(KD), Options), KD \== [],
        Report0 = report(_, _, _, fidelity(_, _, _, Rows)),
        findall(S-Q, ( member(row(S, Q, R, _), Rows), R \== pass, memberchk(S-_, KD) ), Failing),
        Failing \== []
    ->  Migration = migration(Meta, IR, Ledger, Tests0),
        maplist(pend_test(KD, Failing), Tests0, Tests),
        write_migration(migration(Meta, IR, Ledger, Tests), OutDir, Base, Report)
    ;   Report = Report0
    ).

pend_test(KD, Failing, test(N, D, L, F, Es0), test(N, D, L, F, Es)) :-
    maplist(pend_expect(KD, Failing, N), Es0, Es).

pend_expect(KD, Failing, S, expects(Q, A), E) :-
    memberchk(S-Q, Failing), memberchk(S-Why, KD), !,
    atom_string(W, Why), E = pending(W, expects(Q, A)).
pend_expect(_, _, _, E, E).

%   Asking the workbook instead of the translation (LE2's `sheet:` services
%   address, docs/user/integrations/spreadsheets.md): a draft at the end of
%   the twin, in comments, of the Logical English that does it — the service
%   line, a template for each answer the import found (when the inputs are
%   few enough to be the places of one sentence) and the section that says
%   which cells answer it. Copied rows are not one cell, and are left out.
append_service_draft(Input, Base, LEFile) :-
    file_base_name(Input, B),
    xlsx_ir:input_cells(Ins0), exclude(xlsx_ir:rowish, Ins0, Ins),
    xlsx_ir:output_cells(Outs0), exclude(xlsx_ir:rowish, Outs0, Outs),
    (   Ins \== [], Outs \== []
    ->  maplist(draft_cell(in), Ins, InCells),
        maplist(draft_cell(out), Outs, OutCells),
        append(InCells, OutCells, All),
        (   All = [dc(Sheet, _, _, _)|_], forall(member(dc(S1, _, _, _), All), S1 == Sheet)
        ->  SheetLine = [Sheet], Plain = true
        ;   SheetLine = [], Plain = false
        ),
        setup_call_cleanup(open(LEFile, append, O, [encoding(utf8)]),
            write_service_draft(O, B, Base, InCells, OutCells, SheetLine, Plain),
            close(O))
    ;   true
    ).

draft_cell(Dir, Cell, dc(Sheet, A1, Words, Type)) :-
    Cell = cell(S, R, C), xlsx_ir:cell_ref_text(cell(S, R, C), Ref0),
    atomic_list_concat(Parts, '!', Ref0), append(SPs, [A1], Parts), !, atomic_list_concat(SPs, '!', Sheet),
    xlsx_ir:cell_label_text(Cell, L0),
    atomic_list_concat(Ws00, ' ', L0),
    %  "is taxpayer resident": a verb first would read as the template's own
    ( Ws00 = [V|Ws0], Ws0 \== [], memberchk(V, [is, are, does, do, has, have, was, were]) -> true ; Ws0 = Ws00 ),
    ( length(Ws0, NW), NW > 6 -> length(Ws, 6), append(Ws, _, Ws0) ; Ws = Ws0 ),   % six words at most
    atomic_list_concat(Ws, ' ', Words),
    port_type(Dir, Cell, Type).

%   Written in the twin's language: the keywords of i18n/keywords.csv, the
%   other words of i18n/writer_words.csv (sheet_draft_*).
write_service_draft(O, B, Base, Ins, Outs, SheetLine, Plain) :-
    xlsx_ir:workbook_language(L),
    le_i18n:le_active_language(Old),
    setup_call_cleanup(le_i18n:set_le_language(L),
                       service_draft(O, B, Base, Ins, Outs, SheetLine, Plain),
                       le_i18n:set_le_language(Old)).

service_draft(O, B, Base, Ins, Outs, SheetLine, Plain) :-
    length(Ins, NI), length(Outs, NO),
    ww(sheet_draft_intro, Intro0), format(atom(Intro), Intro0, [B]),
    nl(O), comment_paragraph(O, Intro), format(O, "%~n", []),
    kw(kb_open, KB), kw(services_include, Include), kw(service_at, At),
    ww(sheet_draft_kb, KBSuffix), ww(sheet_draft_service, Svc), ww(sheet_draft_kind, Kind),
    le_writer:article_for(Kind, Kind, KArt), service_as(KArt, As),
    format(O, "%   ~w ~w ~w ~w:~n%       ~w ~w sheet:sources/~w ~w ~w ~w.~n%~n",
           [KB, Base, KBSuffix, Include, Svc, At, B, As, KArt, Kind]),
    kw(templates, Templates), kw(via_service, Via),
    cells_header(Svc, CellsHeader), kw(cells_sheet, SheetIs),
    MaxPlaces = 6, MaxAnswers = 12,
    (   NI =< MaxPlaces
    ->  ( NO > MaxAnswers -> length(Shown, MaxAnswers), append(Shown, _, Outs) ; Shown = Outs ),
        format(O, "%   ~w:~n", [Templates]),
        forall(member(Out, Shown), ( draft_template(Ins, Out, T), format(O, "%       ~w; ~w ~w.~n", [T, Via, Svc]) )),
        format(O, "%~n%   ~w~n", [CellsHeader]),
        forall(member(Sh, SheetLine), format(O, "%       ~w \"~w\".~n", [SheetIs, Sh])),
        forall(member(Out, Shown), ( draft_instance(Plain, Ins, Out, T), format(O, "%       ~w.~n", [T]) ))
    ;   format(O, "%   ~w~n", [CellsHeader]),
        forall(member(Sh, SheetLine), format(O, "%       ~w \"~w\".~n", [SheetIs, Sh])),
        ww(sheet_draft_each, Each), format(O, "%       ~w~n", [Each])
    ),
    ww(sheet_draft_inputs, InH), ww(sheet_draft_answers, OutH),
    format(O, "%~n%   ~w~n", [InH]),
    draft_list(O, Plain, Ins),
    format(O, "%   ~w~n", [OutH]),
    draft_list(O, Plain, Outs).

ww(Key, W) :- le_writer:writer_word(Key, W).
kw(Key, T) :- le_i18n:kw_main_words(Key, Ws), atomic_list_concat(Ws, ' ', T).

cells_header(Svc, H) :-
    kw(cells_open, Open), kw(cells_are, Are),
    format(atom(H), "~w ~w ~w:", [Open, Svc, Are]).

%   "as a" / "como uma": the synonym of `as` whose article fits the kind
service_as(Art, As) :-
    le_i18n:le_active_language(L),
    (   le_i18n:kw_syn(L, _, service_as, [As, Art]) -> true
    ;   le_i18n:kw_main_words(service_as, [As|_])
    ).

%   A paragraph of a comment, at most 78 characters a line.
comment_paragraph(O, Text) :-
    split_string(Text, " ", "", Ws),
    foldl(comment_word(O), Ws, 0, _), nl(O).

comment_word(O, W, Col0, Col) :-
    string_length(W, N),
    (   Col0 =:= 0 -> format(O, "% ~w", [W]), Col is 2 + N
    ;   Col0 + 1 + N > 78 -> format(O, "~n% ~w", [W]), Col is 2 + N
    ;   format(O, " ~w", [W]), Col is Col0 + 1 + N
    ).

draft_list(O, Plain, Cells) :-
    length(Cells, N),
    ( N > 40 -> length(Shown, 40), append(Shown, _, Cells), More is N - 40 ; Shown = Cells, More = 0 ),
    forall(member(C, Shown), ( draft_ref(Plain, C, R), C = dc(_, _, W, _), format(O, "%       \"~w\" ~w~n", [R, W]) )),
    (   More > 0
    ->  ww(sheet_draft_more, M0), format(atom(M), M0, [More]), format(O, "%       ~w~n", [M])
    ;   true
    ).

%   the <answer> for <input> *a number* and <input> *a text* is *a number*
draft_template(Ins, dc(_, _, W, Ty), T) :-
    maplist(template_place, Ins, Ps),
    kw(and, And), kw(marker_is, Is), ww(sheet_draft_for, For),
    format(atom(Sep), " ~w ", [And]), atomic_list_concat(Ps, Sep, PsT),
    place(Ty, Pl), le_writer:definite_for(W, The),
    format(atom(T), "~w ~w ~w ~w ~w ~w", [The, W, For, PsT, Is, Pl]).

template_place(dc(_, _, IW, ITy), P) :-
    place(ITy, Pl), format(atom(P), "~w ~w", [IW, Pl]).

draft_instance(Plain, Ins, Out, T) :-
    maplist(instance_place(Plain), Ins, Ps),
    kw(and, And), kw(marker_is, Is), ww(sheet_draft_for, For),
    format(atom(Sep), " ~w ", [And]), atomic_list_concat(Ps, Sep, PsT),
    Out = dc(_, _, W, _), draft_ref(Plain, Out, OR), le_writer:definite_for(W, The),
    format(atom(T), "~w ~w ~w ~w ~w \"~w\"", [The, W, For, PsT, Is, OR]).

instance_place(Plain, C, P) :-
    C = dc(_, _, IW, _), draft_ref(Plain, C, R),
    format(atom(P), "~w \"~w\"", [IW, R]).

draft_ref(true, dc(_, A1, _, _), A1) :- !.
draft_ref(false, dc(S, A1, _, _), R) :- format(atom(R), "'~w'!~w", [S, A1]).

%   *a number*, *um número*, *a text*, *um texto*
place(Ty, P) :-
    ( Ty == string -> Key = type_text ; Key = type_number ),
    ww(Key, Noun), le_writer:article_for(Noun, Noun, Art),
    format(atom(P), "*~w ~w*", [Art, Noun]).

port_type(in, Cell, Ty) :- !, ( xlsx_ir:input_type(Cell, text) -> Ty = string ; Ty = number ).
port_type(out, cell(S, R, C), Ty) :-
    xlsx_ir:ast_type(ref(S, R, C, R, C), T),
    (   T == text -> Ty = string
    ;   Ty = number
    ).

%   The macro modules of a workbook that hold code: macro(Module, Lines).
%   Read with oletools' olevba when it is installed (optional: it is Python);
%   without it, a workbook with macros has one entry, its whole VBA project.
:- thread_local macro_code/2.
macro_modules(File, Dict, Macros) :-
    retractall(macro_code(_, _)),
    (   get_dict(macros, Dict, true)
    ->  (   catch(olevba_modules(File, Ms), _, fail)
        ->  findall(macro(M, L), ( member(M-Code, Ms), Code \== "", split_string(Code, "\n", "", Ls), length(Ls, L),
                                   assertz(macro_code(M, Code)) ), Macros)
        ;   Macros = [macro('xl/vbaProject.bin', unknown)]
        )
    ;   Macros = []
    ).

olevba_modules(File, Ms) :-
    absolute_file_name(path(olevba), Exe, [access(execute), file_errors(fail)]),
    setup_call_cleanup(
        process_create(Exe, ['-j', File], [stdout(pipe(Out)), stderr(null), process(P)]),
        ( set_stream(Out, encoding(utf8)), json_read_dict(Out, J, [value_string_as(string)]) ),
        ( close(Out), process_wait(P, _) )),
    findall(N-Code, ( member(F, J), is_dict(F), get_dict(macros, F, MsJ), is_list(MsJ), member(M, MsJ),
                      atom_string(N, M.vba_filename), Code = M.code ), Ms).

write_macros(Input, OutDir) :-
    (   macro_code(_, _)
    ->  file_base_name(Input, B), file_name_extension(Stem, _, B),
        atomic_list_concat([OutDir, '/sources/', Stem, '.vba.txt'], VF),
        setup_call_cleanup(open(VF, write, O, [encoding(utf8)]),
            forall(macro_code(M, Code), format(O, "' ===== ~w =====~n~w~n~n", [M, Code])),
            close(O))
    ;   true
    ).

copy_original(Input, OutDir) :-
    atomic_list_concat([OutDir, '/sources'], SD), make_directory_path(SD),
    file_base_name(Input, B), atomic_list_concat([SD, '/', B], To),
    ( same_file(Input, To) -> true ; copy_file(Input, To) ).

%!  workbook_migration(+File, +Options, -Migration) is det.
workbook_migration(File, Options, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    xlsx_ir:stream_workbook(File, Dict),
    file_base_name(File, Doc),
    retractall(xlsx_ir:wb_name(_)), assertz(xlsx_ir:wb_name(Doc)),
    retractall(xlsx_ir:query_taken(_, _)), retractall(xlsx_tests:cand_memo(_, _, _)), retractall(xlsx_tests:near_memo(_, _)), retractall(xlsx_tests:thresholds_indexed), retractall(xlsx_tests:num_compared(_, _)), retractall(xlsx_tests:key_looked_up(_, _)),
    workbook_items(Options, Items, Info),
    workbook_tests(File, Info, Options, Tests),
    ledger_entries(Ledger0),
    macro_modules(File, Dict, Macros),
    findall(entry(M, macro, residue, Desc, "-", "a macro (VBA) is a program, not a formula: not translated; an output only a macro computes is not tested"),
            ( member(macro(M, Lines), Macros), format(string(Desc), "VBA module, ~w lines", [Lines]) ), MEntries),
    append(Ledger0, MEntries, Ledger),
    (   option(name(Base), Options) -> true ; base_name(File, Base) ),
    Info = info(Inputs, Outputs, _),
    length(Inputs, NI), length(Outputs, NO),
    sheet_list(Sheets),
    (   Macros == [] -> MacroNote = ""
    ;   length(Macros, NM), format(string(MacroNote), "~nThe workbook also holds ~w macro module(s) with code (VBA programs run by its buttons): not translated (the ledger lists them; their code is in sources/ when oletools is installed).", [NM])
    ),
    format(string(C0), "The workbook ~w (sheets: ~w) as Logical English: ~w inputs, ~w outputs.~nEach formula is a rule; each output has a query; the scenarios expect the values the workbook itself computes (as saved by Excel, and cases computed by the sheet engine).~nTranslated by LE2 migration/spreadsheet (the design notes Excel.md §7.2).",
           [Doc, Sheets, NI, NO]),
    string_concat(C0, MacroNote, C),
    workbook_language(Lang),
    ( Lang == en -> Header = [kb(Base), comment(C)] ; Header = [kb(Base), comment(C), language(Lang)] ),
    get_time(T), format_time(atom(Date), '%F', T),
    Meta = [source('Spreadsheet (Excel)'), artifacts([Doc]), translator('LE2 migration/spreadsheet'),
            program(Base), date(Date), licence('as the workbook\'s publisher states')].

sheet_list(T) :-
    findall(S, xlsx_ir:sheet_info(_, S, _, _), Ss), atomic_list_concat(Ss, ', ', T).

base_name(File, Base) :-
    file_base_name(File, B), file_name_extension(N, _, B),
    atom_codes(N, Cs0),
    maplist([C0, C]>>( code_type(C0, alnum) -> C = C0 ; C = 0'_ ), Cs0, Cs1),
    atom_codes(A, Cs1), downcase_atom(A, Base0),
    atomic_list_concat(Ps0, '_', Base0), exclude(==(''), Ps0, Ps), atomic_list_concat(Ps, '_', Base1),
    ( Base1 == '' -> Base = workbook ; Base = Base1 ).

/** <module> A workbook as Logical English: structure recovery and formulas as rules

    the design notes Excel.md §7.2 (Mode A). The front end (xlsx_front.mjs, over
    LE2's sheet engine) gives the workbook as JSON: cells, formulas and their
    syntax trees, the values Excel saved, styles, names, validations. This
    module recovers what a spreadsheet does not declare and writes the
    Migration IR of LE2's le_writer:

      - **inputs**: the cells a person fills in — unlocked cells of a
        protected sheet, cells with a validation list, and empty cells a
        formula reads — each a template `; undefined`, stated by a scenario;
      - **parameters**: the other constant cells formulas read, each a named
        constant (`the constants are:`);
      - **lookup ranges** read by LOOKUP, VLOOKUP, HLOOKUP and INDEX/MATCH:
        decision tables (language.md §17.3);
      - **formula cells**: one rule each, `the <label> is a value if ...`,
        an IF written as an `otherwise` cascade (§17.2);
      - **outputs**: the formula cells no other formula reads; each has a
        query, and the scenarios expect their values.

    The words of a template come from the cell's label: the text to its
    left, or above it, made into words LE reads (label_words/2); two cells
    with the same label are told apart by the heading above them.

    What cannot be translated (a function with no counterpart, a formula
    reading a deleted cell, text joined with &) is a residue block naming
    the formula; the expectations that depend on it are pending
    (le_migration). Nothing here knows any particular workbook.
*/

:- module(xlsx_ir, [
    read_workbook/3,            % +File, +Options, -Dict
    load_workbook/1,            % +Dict
    workbook_items/3,           % +Options, -Items, -Info
    cell_functor/2,             % +Cell, -F
    input_cells/1,              % -[cell(S,R,C)]
    output_cells/1,             % -[cell(S,R,C)]
    cell_ref_text/2,            % +Cell, -'Sheet'!A1
    cell_label_text/2,          % +Cell, -Text
    ledger_entries/1,           % -Entries
    workbook_language/1,        % -Lang
    rowish/1,                   % +Cell
    serial_date/2,              % ?Serial, ?Date
    date_cell/1,                % +Cell
    row_atom/2,                 % +Row, -Atom
    copied_rows_of/2,           % +Cell, -[Row]
    run_front/4                 % +Mode, +File, +Stdin, -Dict
]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(yall)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(option)).
:- use_module(library(pairs)).
:- use_module(library(aggregate)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module('../le2_paths').

:- discontiguous ast_term/4.
:- use_module(le2(le_i18n)).

:- thread_local wb_lang/1.

%!  frame(+Lang, +Key, -Format) is semidet.
%
%   The sentence frames of the templates the translator writes, in the
%   program's language: a cell's value, a question's answer, a table's
%   value, the arithmetic reading of a value; and the type words.
frame(en, value,    "the ~w is *~w*").
frame(en, question, "the answer to ~w is *~w*").
frame(en, table,    "the ~w for *a key* is *a value* under table ~w").
frame(en, counts,   "*a value* counts in arithmetic as *a number*").
frame(en, table2,   "the ~w for *a key* and column *a number* is *a value* under table ~w").
frame(pt, table2,   "o valor de ~w para *uma chave* e a coluna *um número* é *um valor* segundo a tabela ~w").
frame(es, table2,   "el valor de ~w para *una clave* y la columna *un número* es *un valor* según la tabla ~w").
frame(fr, table2,   "la valeur de ~w pour *une clé* et la colonne *un nombre* est *une valeur* en application de la table ~w").
frame(it, table2,   "il valore di ~w per *una chiave* e la colonna *un numero* è *un valore* secondo la tabella ~w").
frame(pt, value,    "o valor de ~w é *~w*").
frame(pt, question, "a resposta a ~w é *~w*").
frame(pt, table,    "o valor de ~w para *uma chave* é *um valor* segundo a tabela ~w").
frame(pt, counts,   "*um valor* conta na aritmética como *um número*").
frame(es, value,    "el valor de ~w es *~w*").
frame(es, question, "la respuesta a ~w es *~w*").
frame(es, table,    "el valor de ~w para *una clave* es *un valor* según la tabla ~w").
frame(es, counts,   "*un valor* cuenta en la aritmética como *un número*").
frame(fr, value,    "la valeur de ~w est *~w*").
frame(fr, question, "la réponse à ~w est *~w*").
frame(fr, table,    "la valeur de ~w pour *une clé* est *une valeur* en application de la table ~w").
frame(fr, counts,   "*une valeur* compte en arithmétique comme *un nombre*").
frame(it, value,    "il valore di ~w è *~w*").
frame(it, question, "la risposta a ~w è *~w*").
frame(it, table,    "il valore di ~w per *una chiave* è *un valore* secondo la tabella ~w").
frame(it, counts,   "*un valore* conta in aritmetica come *un numero*").

%   the name of a cell with no label, and "at" before an address
frame(en, column, "column ~w of ~w"). frame(pt, column, "coluna ~w de ~w"). frame(es, column, "columna ~w de ~w").
frame(fr, column, "colonne ~w de ~w"). frame(it, column, "colonna ~w di ~w").
frame(en, row, "~w of *a row*"). frame(pt, row, "~w de *uma linha*"). frame(es, row, "~w de *una fila*").
frame(fr, row, "~w d'*une ligne*"). frame(it, row, "~w di *una riga*").
frame(en, shown, "text shown for ~w"). frame(pt, shown, "texto mostrado para ~w").
frame(es, shown, "texto mostrado para ~w"). frame(fr, shown, "texte affiché pour ~w").
frame(it, shown, "testo mostrato per ~w").
frame(en, for, for). frame(pt, for, para). frame(es, for, para). frame(fr, for, pour). frame(it, for, per).
frame(en, cell, "cell ~w of ~w"). frame(en, at, at).
frame(pt, cell, "célula ~w de ~w"). frame(pt, at, em).
frame(es, cell, "celda ~w de ~w"). frame(es, at, en).
frame(fr, cell, "cellule ~w de ~w"). frame(fr, at, en).
frame(it, cell, "cella ~w di ~w"). frame(it, at, in).

type_word(en, date, 'a date'). type_word(pt, date, 'uma data'). type_word(es, date, 'una fecha').
type_word(fr, date, 'une date'). type_word(it, date, 'una data').
type_word(en, number, 'a number'). type_word(en, text, 'a text'). type_word(en, value, 'a value').
type_word(en, amount, 'an amount'). type_word(en, rate, 'a rate').
type_word(pt, number, 'um número'). type_word(pt, text, 'um texto'). type_word(pt, value, 'um valor').
type_word(pt, amount, 'uma quantia'). type_word(pt, rate, 'uma taxa').
type_word(es, number, 'un número'). type_word(es, text, 'un texto'). type_word(es, value, 'un valor').
type_word(es, amount, 'un importe'). type_word(es, rate, 'una tasa').
type_word(fr, number, 'un nombre'). type_word(fr, text, 'un texte'). type_word(fr, value, 'une valeur').
type_word(fr, amount, 'un montant'). type_word(fr, rate, 'un taux').
type_word(it, number, 'un numero'). type_word(it, text, 'un testo'). type_word(it, value, 'un valore').
type_word(it, amount, 'un importo'). type_word(it, rate, 'un tasso').

lang(L) :- ( wb_lang(L0) -> L = L0 ; L = en ).

%   The language of a workbook: the one whose common small words its labels
%   use most (English when none stands out).
detect_language(Lang) :-
    findall(W, ( wcell(_, _, _, text, T, _, _, _), string(T), string_length(T, N), N < 200,
                 string_lower(T, TL), split_string(TL, " ,.;:()?!", " ,.;:()?!", Ws0), member(W0, Ws0), atom_string(W, W0) ), Ws),
    findall(Score-L, ( member(L, [en, pt, es, fr, it]), marker_words(L, Ms),
                       aggregate_all(count, ( member(W, Ws), memberchk(W, Ms) ), Score) ), Scores),
    max_member(Best-Lang0, Scores),
    memberchk(En-en, Scores),
    %  another language only when it clearly outweighs English
    ( Lang0 \== en, Best >= 3, Best > 1.5 * En -> Lang = Lang0 ; Lang = en ).

marker_words(en, [the, of, and, for, is, with, to, are]).
marker_words(pt, [do, da, dos, das, não, para, é, ou, com, ao, no, na, pelo, pela]).
marker_words(es, [del, los, las, el, y, para, es, por]).
marker_words(fr, [du, des, les, le, et, pour, est, avec, aux]).
marker_words(it, [di, della, delle, il, gli, è, dal, nel, alla, degli]).


:- thread_local
    sheet_info/4,           % Idx, Name, State, Protected
    wcell/8,                % S, R, C, Type, Value, Locked, Fill, Format
    wformula/5,             % S, R, C, Text, AST
    wcomment/4,             % S, R, C, Text
    wname/3,                % Name, Scope, Target
    wvalid/4,               % S, R, C, Values
    wnormalised/4,          % S, R, C, From
    reads/2,                % cell(S,R,C), cell(S2,R2,C2): a formula reads a cell
    lookup_range/5,         % S, R1, C1, R2, C2
    role/2,                 % cell(S,R,C), input | param | formula | blank
    cell_label/2,           % cell(S,R,C), Words (a list of atoms)
    template_text/2,        % cell(S,R,C), Text
    table_def/6,            % Id, Name, Key, Spec, Rows, Note
    ledger/1,               % entry(...)
    residue_count/1,
    used_constant/1,        % cell(S,R,C)
    input_type/2,           % cell(S,R,C), number | text
    wvalid_range/3,         % S, Ranges, range(...): a list of allowed values taken from cells
    wsig/4,                 % S, R, C, Sig: the formula in R1C1 terms (copies share it)
    col_group/4,            % S, C, R1, R2: a column of copies of one formula
    row_col/4,              % S, C, R1, R2: the cells copied rows read at their own row
    canon/2.                % Cell, Canonical: a cell of copied rows, and the first of its column

		 /*******************************
		 *           FRONT END          *
		 *******************************/

%!  run_front(+Mode, +File, +Stdin, -Dict) is det.
%
%   Runs xlsx_front.mjs (read, eval or survey) under Node and reads its JSON.
%   Stdin is a dict written to the front end's standard input, or none.
run_front(Mode, File, Stdin, Dict) :-
    le2_dir(LE2),
    front_script(Script),
    absolute_file_name(File, Abs),
    tmp_file_stream(text, Out, S0), close(S0),
    tmp_file_stream(text, Err, S1), close(S1),
    maplist(shell_quote, ['--no-warnings', Script, Mode, LE2, Abs], Qs),
    atomic_list_concat(Qs, ' ', ArgText),
    shell_quote(Out, QO), shell_quote(Err, QE),
    (   Stdin == none
    ->  format(atom(Cmd), 'exec node ~w > ~w 2> ~w < /dev/null', [ArgText, QO, QE]),
        process_create(path(sh), ['-c', Cmd], [process(P)])
    ;   format(atom(Cmd), 'exec node ~w > ~w 2> ~w', [ArgText, QO, QE]),
        process_create(path(sh), ['-c', Cmd], [stdin(pipe(In)), process(P)]),
        set_stream(In, encoding(utf8)),
        json_write_dict(In, Stdin, [width(0)]), close(In)
    ),
    process_wait(P, Status),
    (   Status == exit(0)
    ->  setup_call_cleanup(open(Out, read, S, [encoding(utf8)]),
                           json_read_dict(S, Dict, [value_string_as(string), tag('')]),
                           close(S)),
        delete_file(Out), delete_file(Err)
    ;   read_file_to_string(Err, E, []), delete_file(Out), delete_file(Err),
        throw(error(xlsx_front_failed(Status, E), _))
    ).

shell_quote(A, Q) :-
    atomic_list_concat(Ps, '\'', A), atomic_list_concat(Ps, '\'\\\'\'', B),
    format(atom(Q), '\'~w\'', [B]).

front_script(S) :-
    module_property(xlsx_ir, file(F)), file_directory_name(F, D),
    atomic_list_concat([D, '/xlsx_front.mjs'], S).

%!  read_workbook(+File, +Options, -Dict) is det.
%
%   The workbook as a dict (front end `read`): for a filled example.
read_workbook(File, _Options, Dict) :-
    run_front(read, File, none, Dict).

%!  stream_workbook(+File, -Head) is det.
%
%   The workbook loaded as facts as the front end streams it, one cell per
%   line (`stream`): Head holds the rest (file, macros, names, sheets).
stream_workbook(File, Head) :-
    le2_dir(LE2), front_script(Script), absolute_file_name(File, Abs),
    tmp_file_stream(text, Out, S0), close(S0),
    tmp_file_stream(text, Err, S1), close(S1),
    maplist(shell_quote, ['--no-warnings', Script, stream, LE2, Abs], Qs),
    atomic_list_concat(Qs, ' ', ArgText), shell_quote(Out, QO), shell_quote(Err, QE),
    format(atom(Cmd), 'exec node ~w > ~w 2> ~w < /dev/null', [ArgText, QO, QE]),
    process_create(path(sh), ['-c', Cmd], [process(P)]),
    process_wait(P, Status),
    (   Status == exit(0)
    ->  setup_call_cleanup(open(Out, read, S, [encoding(utf8)]),
                           ( json_read_dict(S, Head, [value_string_as(string), tag('')]),
                             load_head(Head),
                             load_cells(S),
                             load_list_validations ),
                           close(S)),
        delete_file(Out), delete_file(Err)
    ;   read_file_to_string(Err, E, []), delete_file(Out), delete_file(Err),
        throw(error(xlsx_front_failed(Status, E), _))
    ).

load_head(D) :-
    reset,
    forall(nth1(I, D.sheets, Sh), ( atom_string(S, Sh.name), atom_string(St, Sh.state),
                                    assertz(sheet_info(I, S, St, Sh.protected)) )),
    forall(member(N, D.names), load_name(N)),
    forall(( nth1(_, D.sheets, Sh), atom_string(S, Sh.name), member(V, Sh.validations) ), load_validation(S, V)),
    forall(member(Nm, D.normalised),
           ( atom_string(S, Nm.sheet), split_a1(Nm.cell, R, C), assertz(wnormalised(S, R, C, Nm.from)) )).

load_cells(In) :-
    repeat,
    (   catch(json_read_dict(In, C, [value_string_as(string), tag(''), end_of_file(eof)]), _, fail),
        C \== eof
    ->  sheet_info(C.sheet, S, _, _), load_cell(S, C), fail
    ;   !
    ).

		 /*******************************
		 *        LOADING THE FACTS     *
		 *******************************/

reset :-
    retractall(sheet_info(_, _, _, _)), retractall(wcell(_, _, _, _, _, _, _, _)),
    retractall(wformula(_, _, _, _, _)), retractall(wcomment(_, _, _, _)),
    retractall(wname(_, _, _)), retractall(wvalid(_, _, _, _)), retractall(wnormalised(_, _, _, _)),
    retractall(reads(_, _)), retractall(lookup_range(_, _, _, _, _)), retractall(role(_, _)),
    retractall(cell_label(_, _)), retractall(template_text(_, _)), retractall(table_def(_, _, _, _, _, _)),
    retractall(ledger(_)), retractall(residue_count(_)), assertz(residue_count(0)),
    retractall(used_constant(_)), retractall(input_type(_, _)), retractall(type_memo(_, _)), retractall(counts_used),
    retractall(wsig(_, _, _, _)), retractall(wvalid_range(_, _, _)), retractall(reached(_)), retractall(col_group(_, _, _, _)), retractall(row_col(_, _, _, _)), retractall(canon(_, _)).

%!  load_workbook(+Dict) is det.
load_workbook(D) :-
    reset,
    forall(nth1(I, D.sheets, Sh), ( atom_string(S, Sh.name), atom_string(St, Sh.state),
                                    assertz(sheet_info(I, S, St, Sh.protected)) )),
    forall(member(N, D.names), load_name(N)),
    forall(member(Sh, D.sheets), load_sheet(Sh)),
    load_list_validations,
    forall(member(Nm, D.normalised), ( atom_string(S, Nm.sheet), split_a1(Nm.cell, R, C), assertz(wnormalised(S, R, C, Nm.from)) )).

%   Lists of allowed values taken from cells: read once the cells are there.
load_list_validations :-
    forall(retract(wvalid_range(S, Ranges, range(TS, R1, C1, R2, C2))),
           ( findall(V, ( between(R1, R2, R), between(C1, C2, C), wcell(TS, R, C, T, V0, _, _, _),
                          memberchk(T, [text, number]), format(string(V), "~w", [V0]) ), Vals),
             forall(( member(Rg, Ranges), range_cells(S, Rg, R, C) ), assertz(wvalid(S, R, C, Vals))) )).

load_sheet(Sh) :-
    atom_string(S, Sh.name),
    forall(member(C, Sh.cells), load_cell(S, C)),
    forall(member(V, Sh.validations), load_validation(S, V)).

load_cell(S, C) :-
    R = C.row, Col = C.col,
    atom_string(T, C.type),
    json_cell_value(C.value, V),
    ( get_dict(fill, C, F0), F0 \== null -> F = F0 ; F = none ),
    ( get_dict(format, C, Fm0), Fm0 \== null -> Fm = Fm0 ; Fm = "General" ),
    ( C.locked == true -> L = true ; L = false ),
    assertz(wcell(S, R, Col, T, V, L, F, Fm)),
    (   get_dict(formula, C, Text)
    ->  ast_term(C.ast, S, AST),
        assertz(wformula(S, R, Col, Text, AST)),
        sig_term(C.ast, R, Col, Full), variant_sha1(Full, H),
        findall(Rf, ( sub_term(Rf, Full), compound(Rf), Rf = ref(_, _, _, _, _) ), Refs),
        assertz(wsig(S, R, Col, sig(H, Refs)))
    ;   true
    ),
    ( get_dict(comment, C, Cm) -> assertz(wcomment(S, R, Col, Cm)) ; true ).

json_cell_value(null, blank) :- !.
json_cell_value(V, error(E)) :- is_dict(V), get_dict(error, V, E0), !, atom_string(E, E0).
json_cell_value(V, V).

load_validation(S, V) :-
    (   V.type == "list", V.formula1 \== null,
        string_concat("\"", Rest, V.formula1), string_concat(Body, "\"", Rest)
    ->  split_string(Body, ",", " ", Vals0), exclude(==(""), Vals0, Vals),
        forall(( member(Rg, V.ranges), range_cells(S, Rg, R, C) ), assertz(wvalid(S, R, C, Vals)))
    ;   V.type == "list", V.formula1 \== null, list_range(S, V.formula1, Target0)
    ->  ( Target0 = cell(TS, TR, TC) -> Target = range(TS, TR, TC, TR, TC) ; Target = Target0 ),
        assertz(wvalid_range(S, V.ranges, Target))
    ;   V.type == "list"
    ->  forall(( member(Rg, V.ranges), range_cells(S, Rg, R, C) ), assertz(wvalid(S, R, C, list)))
    ;   true
    ).

%   A list of allowed values given as a range of cells: Sheet!$A$2:$A$7, or
%   $A$2:$A$7 on the validation's own sheet.
list_range(S, F1, Target) :-
    (   sub_string(F1, _, _, _, "!") -> Text = F1 ; format(string(Text), "'~w'!~w", [S, F1]) ),
    catch(parse_ref_text(Text, Target), _, fail).

range_cells(_S, Rg, R, C) :-
    (   split_string(Rg, ":", "", [A, B])
    ->  split_a1(A, R1, C1), split_a1(B, R2, C2), between(R1, R2, R), between(C1, C2, C)
    ;   split_a1(Rg, R, C)
    ).

load_name(N) :-
    atom_string(Name, N.name),
    ( N.scope == null -> Scope = global ; atom_string(Scope, N.scope) ),
    (   catch(parse_ref_text(N.ref, Target), _, fail) -> true ; Target = broken ),
    assertz(wname(Name, Scope, Target)).

%   'Sheet name'!$B$29 | Sheet!$A$1:$B$3 -> cell(S,R,C) | range(S,R1,C1,R2,C2)
parse_ref_text(Text, Target) :-
    split_string(Text, "!", "", Parts),
    (   append(SheetParts, [Cells], Parts), SheetParts \== []
    ->  atomic_list_concat(SheetParts, '!', S0), unquote_sheet(S0, S)
    ;   throw(no_sheet)
    ),
    (   split_string(Cells, ":", "", [A, B])
    ->  split_a1(A, R1, C1), split_a1(B, R2, C2),
        ( R1 == R2, C1 == C2 -> Target = cell(S, R1, C1) ; Target = range(S, R1, C1, R2, C2) )
    ;   split_a1(Cells, R, C), Target = cell(S, R, C)
    ).

unquote_sheet(S0, S) :-
    atom_string(A, S0),
    (   sub_atom(A, 0, 1, _, ''''), sub_atom(A, _, 1, 0, '''')
    ->  sub_atom(A, 1, _, 1, B), atomic_list_concat(Ps, '''''', B), atomic_list_concat(Ps, '''', S)
    ;   S = A
    ).

split_a1(Text, R, C) :-
    string_codes(Text, Cs0), exclude(==(0'$), Cs0, Cs),
    phrase(a1(Letters, Digits), Cs),
    foldl([L, A0, A]>>(A is A0 * 26 + (L - 0'A + 1)), Letters, 0, C),
    number_codes(R, Digits).

a1([L|Ls], Ds) --> [L0], { code_type(L0, alpha), upcase_code(L0, L) }, a1_more(Ls, Ds).
a1_more([L|Ls], Ds) --> [L0], { code_type(L0, alpha), upcase_code(L0, L) }, !, a1_more(Ls, Ds).
a1_more([], [D|Ds]) --> [D], { code_type(D, digit) }, digits(Ds).
digits([D|Ds]) --> [D], { code_type(D, digit) }, !, digits(Ds).
digits([]) --> [].

upcase_code(C0, C) :- ( C0 >= 0'a, C0 =< 0'z -> C is C0 - 32 ; C = C0 ).

col_name(C, Name) :-
    col_codes(C, Cs), atom_codes(Name, Cs).
col_codes(C, Cs) :-
    (   C =< 0 -> Cs = []
    ;   M is (C - 1) mod 26, C1 is (C - 1) // 26, L is 0'A + M,
        col_codes(C1, Cs0), append(Cs0, [L], Cs)
    ).

%!  cell_ref_text(+Cell, -Text) is det.
cell_ref_text(cell(S, R, C), T) :-
    col_name(C, CN), format(atom(T), '~w!~w~w', [S, CN, R]).

a1_text(R, C, T) :- col_name(C, CN), format(atom(T), '~w~w', [CN, R]).

		 /*******************************
		 *       SYNTAX TREES           *
		 *******************************/

%   The front end's tree as a term:
%     num(N) text(S) bool(B) ref(S,R1,C1,R2,C2) name(N) fn(NAME, Args)
%     bin(Op, L, R) un(Op, X) err(Message) array(Rows) omitted
ast_term(J, S, T) :-
    get_dict(type, J, Ty0), atom_string(Ty, Ty0),
    ast_term(Ty, J, S, T), !.
ast_term(J, _, err(J)).

ast_term(number, J, _, num(J.value)).
ast_term(text, J, _, text(J.value)).
ast_term(boolean, J, _, bool(J.value)).
ast_term(omitted, _, _, omitted).
ast_term(reference, J, S0, ref(S, R1, C1, R2, C2)) :-
    Rf = J.reference,
    ( get_dict(sheet, Rf, SS), SS \== null -> atom_string(S, SS) ; S = S0 ),
    R1 = Rf.rowStart, C1 = Rf.colStart, R2 = Rf.rowEnd, C2 = Rf.colEnd,
    integer(R1), integer(C1), R1 > 0, C1 > 0.
ast_term(name, J, S, T) :- atom_string(N, J.name), resolve_name(N, S, T).
ast_term(function, J, S, fn(N, As)) :-
    string_upper(J.name, NU), atom_string(N0, NU),
    ( atom_concat('_XLFN.', N, N0) -> true ; N = N0 ),
    ast_terms(J.args, S, As).
ast_term(binaryOp, J, S, T) :-
    atom_string(Op, J.op), ast_term(J.left, S, L), ast_term(J.right, S, R),
    (   Op == ':', L = ref(Sh, A1, B1, A2, B2), R = ref(Sh, C1, D1, C2, D2)
    ->  %  a range whose two ends both name the sheet ('Pt 2'!D14:'Pt 2'!D17)
        Ra is min(A1, C1), Ca is min(B1, D1), Rb is max(A2, C2), Cb is max(B2, D2),
        T = ref(Sh, Ra, Ca, Rb, Cb)
    ;   T = bin(Op, L, R)
    ).
ast_term(unaryOp, J, S, un(Op, X)) :-
    atom_string(Op, J.op), ast_term(J.operand, S, X).
ast_term(array, J, S, array(Rows)) :-
    ast_rows(J.elements, S, Rows).
ast_terms([], _, []).
ast_terms([A|As], S, [B|Bs]) :- ast_term(A, S, B), ast_terms(As, S, Bs).
ast_rows([], _, []).
ast_rows([R|Rs], S, [T|Ts]) :- ast_terms(R, S, T), ast_rows(Rs, S, Ts).

ast_term(error, J, _, err(M)) :- ( get_dict(message, J, M) -> true ; M = "error" ).

resolve_name(N, S, T) :-
    (   wname(N, S, Target) -> true
    ;   wname(N, global, Target) -> true
    ;   downcase_atom(N, ND), wname(N2, Sc, Target), downcase_atom(N2, ND), memberchk(Sc, [S, global]) -> true
    ;   Target = unknown
    ),
    (   Target = cell(TS, R, C) -> T = ref(TS, R, C, R, C)
    ;   Target = range(TS, R1, C1, R2, C2) -> T = ref(TS, R1, C1, R2, C2)
    ;   format(string(M), "the name ~w, which does not name a cell", [N]), T = err(M)
    ).

		 /*******************************
		 *     STRUCTURE RECOVERY       *
		 *******************************/

%   Which cells each formula reads, and which ranges are lookup tables.
%   With named answer cells (outputs([...])), only the formulas they reach
%   are read: a model of 50,000 formulas is walked from its answers.
dependencies(Options) :-
    option(outputs(Refs), Options), is_list(Refs), !,
    maplist(given_cell, Refs, Starts),
    nb_setval(xl_collecting, true),
    retractall(reached(_)),
    reach_formulas(Starts),
    nb_setval(xl_collecting, false),
    %  copies of a reached formula down its column are reached too (they are
    %  rows of the same rule)
    retractall(unreached_sig(_, _, _)),
    forall(( wsig(S, R, C, _), \+ reached(cell(S, R, C)) ), assertz(unreached_sig(S, R, C))),
    forall(unreached_sig(S, R, C), retract(wsig(S, R, C, _))).
dependencies(_) :- dependencies.

:- thread_local reached/1, unreached_sig/3.

reach_formulas([]).
reach_formulas([Cell|Cells]) :-
    (   reached(Cell) -> reach_formulas(Cells)
    ;   assertz(reached(Cell)),
        Cell = cell(S, R, C),
        (   wformula(S, R, C, _, AST)
        ->  retractall(pending_read(_)),
            ast_reads(AST, Cell),
            findall(To, retract(pending_read(To)), Tos0), sort(Tos0, Tos),
            forall(member(To, Tos), assertz(reads(Cell, To))),
            include([T]>>( T = cell(TS, TR, TC), wformula(TS, TR, TC, _, _) ), Tos, Fs),
            append(Fs, Cells, Next)
        ;   Next = Cells
        ),
        reach_formulas(Next)
    ).

dependencies :-
    nb_setval(xl_collecting, true),
    forall(wformula(S, R, C, _, AST),
           ( retractall(pending_read(_)),
             ast_reads(AST, cell(S, R, C)),
             findall(To, retract(pending_read(To)), Tos0), sort(Tos0, Tos),
             forall(member(To, Tos), assertz(reads(cell(S, R, C), To))) )),
    nb_setval(xl_collecting, false).

:- thread_local pending_read/1.

ast_reads(ref(S, R1, C1, R2, C2), From) :- !,
    %  a range of more than 400 cells outside a lookup (a whole code list in
    %  COUNTIF or MATCH) is not read cell by cell: the formula using it is
    %  residue anyway (range_terms/8), and its cells are not the case's
    (   (R2 - R1 + 1) * (C2 - C1 + 1) > 400 -> true
    ;   forall(( between(R1, R2, R), between(C1, C2, C) ), note_read(From, cell(S, R, C)))
    ).
ast_reads(fn(F, As), From) :-
    lookup_function(F, As, Key, Range, _), !,
    ast_reads(Key, From),
    Range = ref(S, R1, C1, R2, C2),
    ( lookup_range(S, R1, C1, R2, C2) -> true ; assertz(lookup_range(S, R1, C1, R2, C2)) ),
    %  a formula inside the table's range is still read
    forall(( between(R1, R2, R), between(C1, C2, C), wformula(S, R, C, _, _) ), note_read(From, cell(S, R, C))).
ast_reads(T, _) :- is_dict(T), !.
ast_reads(T, From) :-
    compound(T), !, T =.. [_|As], forall(member(A, As), ( is_list(A) -> forall(member(X, A), ( is_list(X) -> forall(member(Y, X), ast_reads(Y, From)) ; ast_reads(X, From) )) ; ast_reads(A, From) )).
ast_reads(_, _).

%   (while the dependencies are collected: a formula's reads, sorted after;
%   afterwards, one read added if it is new)
note_read(_, To) :- nb_current(xl_collecting, true), !, assertz(pending_read(To)).
note_read(From, To) :- ( reads(From, To) -> true ; assertz(reads(From, To)) ).

%   lookup_function(+F, +Args, -Key, -TableRange, -Spec)
%   Spec: lookup(KeyCols, ResultCol, Match) over rows, or hlookup(...).
lookup_function('VLOOKUP', [K, ref(S, R1, C1, R2, C2), num(Col)|Rest], K, ref(S, R1, C1, R2, C2),
                spec(rows, C1, RC, Match)) :-
    RC is C1 + Col - 1, RC =< C2, match_mode(Rest, Match).
lookup_function('HLOOKUP', [K, ref(S, R1, C1, R2, C2), num(Row)|Rest], K, ref(S, R1, C1, R2, C2),
                spec(cols, R1, RR, Match)) :-
    RR is R1 + Row - 1, RR =< R2, match_mode(Rest, Match).
%   VLOOKUP with a computed column (MIN(children + 2, 8)): a table of two
%   keys, the row's band and the column's number.
lookup_function('VLOOKUP', [K, ref(S, R1, C1, R2, C2), ColAST|Rest], K, ref(S, R1, C1, R2, C2),
                spec(by_column(ColAST), C1, C2, Match)) :-
    \+ ColAST = num(_), C2 > C1, match_mode(Rest, Match).
lookup_function('LOOKUP', [K, ref(S, R1, C1, R2, C2)], K, ref(S, R1, C1, R2, C2), Spec) :-
    (   C2 > C1, R2 - R1 >= C2 - C1 -> Spec = spec(rows, C1, C2, approximate)
    ;   R2 > R1 -> Spec = spec(cols, R1, R2, approximate)
    ;   Spec = spec(rows, C1, C2, approximate)
    ).
lookup_function('LOOKUP', [K, ref(S, R1, C1, R2, C1), ref(S, R1b, C2, R2b, C2)], K, ref(S, R1, C1, R2, C2),
                spec(rows, C1, C2, approximate)) :-
    R1b == R1, R2b == R2.
lookup_function('INDEX', [ref(S, R1, C, R2, C), fn('MATCH', [K, ref(S, R1, KC, R2, KC)|Rest])], K,
                ref(S, R1, Lo, R2, Hi), spec(rows, KC, C, Match)) :-
    match_type(Rest, Match), Lo is min(C, KC), Hi is max(C, KC).

match_mode([], approximate).
match_mode([bool(false)|_], exact) :- !.
match_mode([num(0)|_], exact) :- !.
match_mode([num(N)|_], exact) :- N =:= 0, !.
match_mode([_|_], approximate).

match_type([], approximate).
match_type([num(0)|_], exact) :- !.
match_type([num(N)|_], exact) :- N =:= 0, !.
match_type([num(1)|_], approximate) :- !.
match_type([_|_], unsupported).

		 /*******************************
		 *         COPIED ROWS          *
		 *******************************/

%   A formula in R1C1 terms: each reference as offsets from the cell where
%   it is relative and as it stands where it is absolute ($A$2), so that the
%   copies of one formula down a column have one signature.
sig_term(J, R, C, T) :- is_dict(J), get_dict(type, J, "reference"), !,
    Rf = J.reference,
    ( get_dict(sheet, Rf, Sh) -> true ; Sh = self ),
    rc(Rf.rowStart, Rf.rowAbsStart, R, A), rc(Rf.colStart, Rf.colAbsStart, C, B),
    rc(Rf.rowEnd, Rf.rowAbsEnd, R, A2), rc(Rf.colEnd, Rf.colAbsEnd, C, B2),
    T = ref(Sh, A, B, A2, B2).
sig_term(J, R, C, T) :- is_dict(J), !,
    dict_pairs(J, _, Ps0),
    exclude([K-_]>>memberchk(K, [sourceStart, sourceEnd, sourceTokenType, sourceTokenSubtype]), Ps0, Ps),
    sig_pairs(Ps, R, C, T).
sig_term(L, R, C, T) :- is_list(L), !, sig_list(L, R, C, T).
sig_term(X, _, _, X).

sig_pairs([], _, _, []).
sig_pairs([K-V|Ps], R, C, [K-W|Ws]) :- sig_term(V, R, C, W), sig_pairs(Ps, R, C, Ws).
sig_list([], _, _, []).
sig_list([X|Xs], R, C, [Y|Ys]) :- sig_term(X, R, C, Y), sig_list(Xs, R, C, Ys).

rc(N, Abs, Base, T) :- ( integer(N) -> ( Abs == true -> T = abs(N) ; D is N - Base, T = rel(D) ) ; T = N ).

%   Columns of copies: a run of at least four cells down a column holding
%   the same formula in R1C1 terms. Each becomes one rule over each row; the
%   cells those rules read at their own row, columns of inputs most often,
%   are copied rows too.
copied_rows :-
    findall(k(S, C)-(R-Sig), wsig(S, R, C, Sig), KVs0), keysort(KVs0, KVs),
    group_pairs_by_key(KVs, Cols),
    forall(member(k(S, C)-RSigs, Cols), column_runs(S, C, RSigs)),
    forall(col_group(S, C, R1, R2), row_reads(S, C, R1, R2)),
    forall(( col_group(S, C, R1, R2), between(R1, R2, R) ), assertz(canon(cell(S, R, C), cell(S, R1, C)))),
    forall(( row_col(S, C, R1, R2), between(R1, R2, R), \+ canon(cell(S, R, C), _) ),
           assertz(canon(cell(S, R, C), cell(S, R1, C)))),
    %  what a copy reads is what the first row reads: one read per column
    (   \+ canon(_, _) -> true
    ;   redirect_reads
    ).

redirect_reads :-
    findall(KF-KT, ( reads(From, To), once(( canon(From, KF0) -> KF = KF0 ; KF = From )),
                     once(( canon(To, KT0) -> KT = KT0 ; KT = To )),
                     \+ ( canon(From, K1), K1 \== From ) ), Pairs),
    retractall(reads(_, _)),
    forall(member(A-B, Pairs), note_read(A, B)).

column_runs(S, C, Rs0) :-
    keysort(Rs0, Rs),
    runs(Rs, Runs),
    forall(( member(run(R1, R2), Runs), R2 - R1 >= 3, wsig(S, R1, C, Sig), row_aligned(Sig) ),
           assertz(col_group(S, C, R1, R2))).

%   One record per row: every relative reference stays on the formula's own
%   row (a copy that reads the row 14 lines below is a shifted copy, each
%   cell of its own).
row_aligned(Sig) :-
    \+ ( sub_term(ref(_, A, _, B, _), Sig), ( A = rel(DA), DA =\= 0 ; B = rel(DB), DB =\= 0 ) ).

runs([], []).
runs([R-Sig|Rest], [run(R, End)|Runs]) :- run_end(Rest, R, Sig, End, After), runs(After, Runs).
run_end([R1-Sig1|Rest], Prev, Sig, End, After) :- R1 =:= Prev + 1, Sig1 =@= Sig, !, run_end(Rest, R1, Sig, End, After).
run_end(Rest, Prev, _, Prev, Rest).

%   The cells the first copy reads at its own row: their columns, over the
%   same rows, are copied rows (inputs, or other columns of copies).
row_reads(S, C, R1, R2) :-
    R2 >= R1,
    wsig(S, R1, C, Sig),
    forall(( sub_term(ref(Sh, rel(0), CS, rel(0), CS), Sig),
             ( Sh == self -> S2 = S ; atom_string(S2, Sh) ),
             ( CS = rel(D) -> C2 is C + D ; CS = abs(C2) ),
             \+ row_col(S2, C2, R1, R2) ),
           assertz(row_col(S2, C2, R1, R2))).
row_reads(_, _, _, _).

%!  rowish(+Cell) is semidet: Cell is the first cell of copied rows.
rowish(Cell) :- canon(Cell, Cell), Cell = cell(S, R, C), ( col_group(S, C, R, R2) ; row_col(S, C, R, R2) ), R2 > R, !.

row_atom(R, A) :- format(atom(A), 'row_~w', [R]).

%!  copied_rows_of(+Cell, -Rows) is det: the rows of the copied rows Cell starts.
copied_rows_of(cell(S, R, C), Rows) :-
    ( col_group(S, C, R, R2) -> true ; row_col(S, C, R, R2) ),
    numlist(R, R2, Rows).

in_lookup_range(cell(S, R, C)) :-
    lookup_range(S, R1, C1, R2, C2), between(R1, R2, R), between(C1, C2, C), !.

%   Roles: formula, input, param (a constant a formula reads), blank.
roles(Options) :-
    option(inputs(Given0), Options, []),
    maplist(given_cell, Given0, Given),
    forall(( wformula(S, R, C, _, _), \+ ( canon(cell(S, R, C), K), K \== cell(S, R, C) ),
             ( reached(_) -> reached(cell(S, R, C)) ; true ) ),
           assertz(role(cell(S, R, C), formula))),
    forall(( reads(_, Cell), \+ role(Cell, _) ),
           ( cell_role(Cell, Given, Role), assertz(role(Cell, Role)) )),
    %  a protected sheet's unlocked cells, or validated ones, a formula reads
    %  through a lookup table's key only, are inputs too: nothing to add.
    true.

given_cell(Ref, Cell) :-
    (   Ref = cell(_, _, _) -> Cell = Ref
    ;   parse_ref_text(Ref, Cell)
    ).

cell_role(Cell, Given, input) :- memberchk(Cell, Given), !.
cell_role(cell(S, R, C), _, Role) :-
    (   wcell(S, R, C, T, _, L, _, _) -> true ; T = blank, L = true ),
    sheet_info(_, S, _, Prot),
    (   Prot == true, L == false -> Role = input
    ;   wvalid(S, R, C, _) -> Role = input
    ;   T == blank, \+ in_lookup_range(cell(S, R, C)) -> Role = input
    ;   T == blank -> Role = blank
    ;   T == error -> Role = blank
    ;   Role = param
    ).

%   The outputs: formula cells no other formula reads and that depend on an
%   input (a cell that computes the same thing in every case is a heading or
%   a constant, not an answer).
outputs(Os) :-
    findall(Cell, ( role(Cell, formula), \+ reads(_, Cell), depends_on_input(Cell),
                    Cell = cell(S, _, _), sheet_info(_, S, _, _) ), Os0),
    sort(Os0, Os).

:- thread_local dep_memo/2.
depends_on_input(Cell) :-
    retractall(dep_memo(_, _)),
    dep_input(Cell, []).
dep_input(Cell, _) :- dep_memo(Cell, R), !, R == true.
dep_input(Cell, Seen) :-
    (   role(Cell, input) -> R = true
    ;   memberchk(Cell, Seen) -> R = false
    ;   reads(Cell, D), dep_input(D, [Cell|Seen]) -> R = true
    ;   R = false
    ),
    assertz(dep_memo(Cell, R)), R == true.

%!  input_cells(-Cells) is det.
input_cells(Cs) :- findall(C, role(C, input), Cs0), sort(Cs0, Cs).
%!  output_cells(-Cells) is det.
output_cells(Os) :- outputs(Os).

		 /*******************************
		 *            LABELS            *
		 *******************************/

%   The text a person reads beside a cell: to its left on the same row (the
%   nearest text, skipping numbers and formulas that give numbers), or above
%   it in the same column, or the name of a defined name pointing at it.
raw_label(cell(S, R, C), Text) :-
    (   left_text(S, R, C, Text) -> true
    ;   above_text(S, R, C, 4, Text) -> true
    ;   R1 is R - 1, R1 > 0, \+ value_cell(S, R1, C), left_text(S, R1, C, Text) -> true
    ;   wname(N, _, cell(S, R, C)), \+ sub_atom(N, 0, _, _, '_'), atom_string(N, Text) -> true
    ;   fail
    ).

left_text(S, R, C, Text) :-
    C1 is C - 1, C1 >= 1,
    (   text_cell(S, R, C1, Text0), meaningful(Text0) -> Text = Text0
    ;   left_text(S, R, C1, Text)
    ).

above_text(S, R, C, N, Text) :-
    N > 0, R1 is R - 1, R1 >= 1,
    (   text_cell(S, R1, C, Text0), meaningful(Text0) -> Text = Text0
    ;   value_cell(S, R1, C) -> fail
    ;   N1 is N - 1, above_text(S, R1, C, N1, Text)
    ).

%   A formula that shows a text only once an answer is given (a guided
%   question, blank as saved) labels with the text it would show.
text_cell(S, R, C, Text) :-
    wformula(S, R, C, _, AST), \+ reads(_, cell(S, R, C)),
    \+ ( wcell(S, R, C, text, T0, _, _, _), T0 \== "" ),
    findall(L-T, ( sub_ast(text(T), AST), string_length(T, L), L > 3 ), LTs), LTs \== [],
    max_member(_-Text, LTs), !.
text_cell(S, R, C, Text) :-
    wcell(S, R, C, text, Text, L, _, _), string(Text),
    \+ ( wformula(S, R, C, _, _), reads(_, cell(S, R, C)) ),
    \+ wvalid(S, R, C, _),
    \+ ( L == false, sheet_info(_, S, _, true) ).

value_cell(S, R, C) :-
    wcell(S, R, C, T, _, _, _, _), T \== blank.

number_cell(S, R, C) :-
    (   wformula(S, R, C, _, _), \+ wcell(S, R, C, text, _, _, _, _) -> true
    ;   wcell(S, R, C, number, _, _, _, _)
    ).

meaningful(T) :- label_words(T, Ws), member(W, Ws), atom_codes(W, Cs), member(Ch, Cs), code_type(Ch, alpha), !.

%   The heading of the block a cell is in: the nearest row above, within 8
%   rows, whose first text is left of the cell and which holds no number.
heading(cell(S, R, C), Text) :-
    between(1, 8, K), R1 is R - K, R1 >= 1,
    once(( between(1, C, HC), text_cell(S, R1, HC, Text), meaningful(Text) )),
    \+ number_cell(S, R1, _),
    !.

%!  label_words(+Text, -Words) is det.
%
%   A label as the words of a template: lower case, without the numbering
%   of steps ("3-1-B."), what is in brackets, symbols, articles (`a`, `the`
%   would read as variables and references) and the words LE reserves; at
%   most eight words.
label_words(Text0, Words) :-
    string_lower(Text0, T00),
    foldl(replace_sym, ["'s "-" ", "’s "-" ", "'"-"", "’"-""], T00, T0),
    cut_instruction(T0, T1),
    drop_brackets(T1, T2),
    foldl(replace_sym, ["%"-" percent ", "&"-" and ", "/"-" or ", "+"-" plus ", "#"-" number ", "§"-" section ", "@"-" at "], T2, T3),
    split_string(T3, "", " \t\n\r", [T4]),
    strip_numbering(T4, T5),
    split_string(T5, " \t\n\r-_.,;:!?\"'()[]{}<>=*$€£►▼•…–—’‘“”|\\^`~", " \t\n\r-_.,;:!?\"'()[]{}<>=*$€£►▼•…–—’‘“”|\\^`~", Ps0),
    exclude(==(""), Ps0, Ps1),
    maplist([P, A]>>atom_string(A, P), Ps1, As00),
    join_digit_words(As00, As0),
    include(word_ok, As0, As1),
    exclude(stop_word, As1, As2),
    drop_leading(As2, As3),
    ( length(As3, N), N > 8 -> length(As, 8), append(As, _, As3) ; As = As3 ),
    Words = As.

%   "Is the household homeless? Enter y if yes." keeps the question: an
%   instruction after the first words is not part of the name.
cut_instruction(T0, T) :-
    (   member(Mark, [" - enter ", "- enter ", ". enter ", "? enter ", " enter y", " (enter", "; enter "]),
        sub_string(T0, B, _, _, Mark), B > 0
    ->  sub_string(T0, 0, B, _, T1),
        ( sub_string(Mark, 0, 1, _, "?") -> string_concat(T1, "?", T) ; T = T1 )
    ;   T = T0
    ).

replace_sym(From-To, S0, S) :-
    atomic_list_concat(Ps, From, S0), atomic_list_concat(Ps, To, S1), atom_string(S1, S).

drop_brackets(S0, S) :-
    (   sub_string(S0, B, _, _, "("), sub_string(S0, E0, 1, _, ")"), E0 > B
    ->  sub_string(S0, 0, B, _, Pre), E is E0 + 1, sub_string(S0, E, _, 0, Post),
        string_concat(Pre, " ", P1), string_concat(P1, Post, S1), drop_brackets(S1, S)
    ;   S = S0
    ).

%   "3-1-B. Earned income", "Step 2: Gross income test", "(a) ..." (already
%   gone with the brackets), "2. Result" -> the words after the numbering.
strip_numbering(S0, S) :-
    (   re_numbering(S0, S1) -> strip_numbering(S1, S) ; S = S0 ).
re_numbering(S0, S) :-
    string_codes(S0, Cs),
    (   append(`step `, Rest0, Cs) -> true ; Rest0 = Cs ),
    phrase(numbering, Rest0, Rest), Rest \== Rest0,
    string_codes(S1, Rest), split_string(S1, "", " ", [S]), S \== S0.
numbering --> num_part, num_more, [C], { memberchk(C, `.:)`) }, !, spaces.
num_part --> [D], { code_type(D, digit) }, !, digits_(_).
num_part --> [L], { code_type(L, lower) }, [C], { memberchk(C, `.)`) }.
num_more --> [0'-], ( [L], { code_type(L, alnum) }, digits_(_) ; num_part ), !, num_more.
num_more --> [].
digits_([D|Ds]) --> [D], { code_type(D, digit) }, !, digits_(Ds).
digits_([]) --> [].
spaces --> [C], { code_type(C, space) }, !, spaces.
spaces --> [].

%   "Level 2A" -> level2a: LE splits a word that starts with a digit and goes
%   on with letters ("2a" is 2 and a, and "a" then reads as an article), so
%   such a word is joined to the word before it (or starts with n).
join_digit_words([], []).
join_digit_words([P, W|Ws], Out) :- digit_word(W), \+ digit_word(P), !,
    atom_concat(P, W, PW), join_digit_words([PW|Ws], Out).
join_digit_words([W|Ws], [W1|Out]) :- digit_word(W), !, atom_concat(n, W, W1), join_digit_words(Ws, Out).
join_digit_words([W|Ws], [W|Out]) :- join_digit_words(Ws, Out).

digit_word(W) :- atom_codes(W, [C|Cs]), code_type(C, digit), member(L, Cs), code_type(L, alpha), !.

word_ok(A) :- atom_codes(A, Cs), Cs \== [], forall(member(C, Cs), code_type(C, alnum)).

%   Words a template cannot hold: the articles (they would read as variables
%   and references) and the words LE reserves, in the program's language.
stop_word(W) :-
    lang(L),
    (   memberchk(W, [a, an, the, if, unless, either, expects, which, otherwise, whose]) -> true
    ;   L \== en, le_i18n:class_member(L, article_narrow, W) -> true
    ;   L \== en, member(K, [if, unless, otherwise, expects, which, either]),
        le_i18n:kw_synonym_words(L, K, Ws), Ws = [W]
    ).

%   A label opening with an instruction keeps what is to be entered.
drop_leading([W|Ws], Out) :- memberchk(W, [enter, input, insert, type, select, please, your, my, our]), Ws \== [], !, drop_leading(Ws, Out).
drop_leading(Ws, Ws).

question(Text) :-
    split_string(Text, "", " \t\n\r", [T]),
    (   sub_string(T, _, 1, 0, "?")
    ;   label_words(T, [W|_]), memberchk(W, [is, are, does, do, has, have, can, will, should, was, were, did])
    ), !.

%   Labels, and from them the template of each cell that needs one.
labels(Cells) :-
    forall(member(Cell, Cells), ( base_label(Cell, Ws, Q), assertz(cell_label(Cell, l(Ws, Q))) )),
    disambiguate(Cells),
    forall(member(Cell, Cells), make_template(Cell)).

base_label(Cell, Ws, Q) :-
    %  a formula showing the question of an input to its right: "the text
    %  shown for <the input's label>"
    Cell = cell(S, R, C), wformula(S, R, C, _, _),
    role(cell(S, R, C2), input), C2 > C,
    raw_label(cell(S, R, C2), Text), text_cell(S, R, C, Text), !,
    label_words(Text, Ws0), atomic_list_concat(Ws0, ' ', W0),
    lang(L), frame(L, shown, Fm), format(string(T), Fm, [W0]),
    split_string(T, " ", "", Ps), maplist([P, A]>>atom_string(A, P), Ps, Ws), Q = false.
base_label(Cell, Ws, Q) :-
    %  a column of copied rows: the header above it
    rowish(Cell), Cell = cell(S, R, C),
    (   above_text(S, R, C, 10, Text), label_words(Text, Ws), Ws \== []
    ->  ( question(Text) -> Q = true ; Q = false )
    ;   col_name(C, CN), downcase_atom(CN, CL), lang(L), frame(L, column, Fm),
        format(string(T), Fm, [CL, S]), label_words(T, Ws), Q = false
    ), !.
base_label(Cell, Ws, Q) :-
    (   raw_label(Cell, Text), label_words(Text, Ws0), Ws0 \== []
    ->  Ws = Ws0, ( question(Text) -> Q = true ; Q = false )
    ;   Cell = cell(S, R, C), a1_text(R, C, A), downcase_atom(A, AD),
        lang(L), frame(L, cell, Fm), format(string(T), Fm, [AD, S]),
        label_words(T, Ws), Q = false
    ).

%   Two cells with the same words: each gets the column header above it, or
%   the heading of its block, in front; then, still alike, its address.
disambiguate(Cells) :-
    findall(Ws-Cell, ( member(Cell, Cells), cell_label(Cell, l(Ws, _)) ), Ps),
    keysort(Ps, Sorted), group_pairs_by_key(Sorted, Groups),
    forall(( member(_-Cs, Groups), Cs = [_, _|_] ), qualify_group(Cs)),
    findall(Ws-Cell, ( member(Cell, Cells), cell_label(Cell, l(Ws, _)) ), Ps2),
    keysort(Ps2, Sorted2), group_pairs_by_key(Sorted2, Groups2),
    forall(( member(_-Cs2, Groups2), Cs2 = [_, _|_] ), forall(member(Cell2, Cs2), address_suffix(Cell2))),
    %  still alike: the address, which is unique
    findall(Ws-Cell, ( member(Cell, Cells), cell_label(Cell, l(Ws, _)) ), Ps3),
    keysort(Ps3, Sorted3), group_pairs_by_key(Sorted3, Groups3),
    forall(( member(_-Cs3, Groups3), Cs3 = [_, _|_] ), forall(member(Cell3, Cs3), address_only(Cell3))).

address_only(Cell) :-
    cell_label(Cell, l(Ws, Q)), Cell = cell(_, R, C), a1_text(R, C, A), downcase_atom(A, AD),
    lang(L), frame(L, at, At), append(Ws, [At, AD], Ws1),
    retract(cell_label(Cell, _)), assertz(cell_label(Cell, l(Ws1, Q))).

%   Of the cells of one row sharing a label, the leftmost keeps it and the
%   others take their column's header; cells on different rows take the
%   heading of their block.
qualify_group(Cs) :-
    %  one input among them keeps the plain name: it is what a person types
    include([C]>>role(C, input), Cs, [In]), !,
    exclude(==(In), Cs, Others),
    forall(member(O, Others), ( O = cell(_, R, _), In = cell(_, R, _) -> address_suffix(O) ; qualify(O, heading) )).
qualify_group(Cs) :-
    findall(R, member(cell(_, R, _), Cs), Rs0), sort(Rs0, Rs),
    forall(member(R, Rs),
           ( findall(C-cell(S, R, C), member(cell(S, R, C), Cs), Row0), keysort(Row0, Row),
             (   member(_-In, Row), role(In, input)          % an input keeps its label
             ->  First = In, exclude(value_is(In), Row, Others)
             ;   Row = [_-First|Others]
             ),
             ( Rs = [_, _|_] -> qualify(First, heading) ; true ),
             forall(member(_-O, Others), ( role(First, input) -> address_suffix(O) ; qualify(O, column) )) )).

value_is(V, _-X) :- X == V.

%   The header of a cell's column: the nearest text above it, over the
%   numbers and formulas of a grid, within 40 rows.
column_header(S, R, C, Text) :-
    between(1, 40, K), R1 is R - K, R1 >= 1,
    (   text_cell(S, R1, C, T), \+ wformula(S, R1, C, _, _), meaningful(T) -> !, Text = T
    ;   fail
    ).

qualify(Cell, How) :-
    cell_label(Cell, l(Ws, Q)),
    Cell = cell(S, R, C),
    (   How == column, column_header(S, R, C, H), label_words(H, HW), HW \== [], HW \== Ws
    ->  true
    ;   heading(Cell, H), label_words(H, HW), HW \== [], HW \== Ws
    ->  true
    ;   HW = []
    ),
    ( length(HW, NH), NH > 5 -> length(HW5, 5), append(HW5, _, HW) ; HW5 = HW ),
    (   How == column -> append(HW5, Ws, Ws1)
    ;   append(Ws, HW5, Ws1)
    ),
    retract(cell_label(Cell, _)), assertz(cell_label(Cell, l(Ws1, Q))).

address_suffix(Cell) :-
    cell_label(Cell, l(Ws, Q)), Cell = cell(S, R, C),
    column_header(S, R, C, H), label_words(H, HW), HW \== [], \+ append(_, HW, Ws), !,
    ( length(HW, NH), NH > 5 -> length(HW5, 5), append(HW5, _, HW) ; HW5 = HW ),
    lang(L), frame(L, for, For),
    append(Ws, [For|HW5], Ws1),
    retract(cell_label(Cell, _)), assertz(cell_label(Cell, l(Ws1, Q))).
address_suffix(Cell) :-
    cell_label(Cell, l(Ws, Q)), Cell = cell(_, R, C), a1_text(R, C, A), downcase_atom(A, AD),
    lang(L), frame(L, at, At),
    append(Ws, [At, AD], Ws1),
    retract(cell_label(Cell, _)), assertz(cell_label(Cell, l(Ws1, Q))).

make_template(Cell) :-
    cell_label(Cell, l(Ws, Q)),
    atomic_list_concat(Ws, ' ', W),
    place_type(Cell, Ty),
    lang(L),
    (   Q == true -> frame(L, question, Fm) ; frame(L, value, Fm) ),
    (   rowish(Cell)
    ->  frame(L, row, RF), format(string(W1), RF, [W]),
        atomic_list_concat(Ps, ' ', W1), atomic_list_concat(Ps, ' ', W2)
    ;   W2 = W
    ),
    format(string(T), Fm, [W2, Ty]),
    assertz(template_text(Cell, T)).

%!  workbook_language(-Lang) is det.
workbook_language(L) :- lang(L).

%!  cell_label_text(+Cell, -Text) is det.
cell_label_text(Cell, T) :-
    cell_label(Cell, l(Ws, _)), atomic_list_concat(Ws, ' ', T).

%   The type of a cell's place, from the values it holds: an amount (a
%   currency format), a rate (a percentage), a number, a text, a value.
place_type(cell(S, R, C), Ty) :-
    (   wcell(S, R, C, T, _, _, _, Fm) -> true ; T = blank, Fm = "General" ),
    lang(L), type_word(L, text, TText), type_word(L, value, TValue),
    (   ( input_type(cell(S, R, C), date) ; role(cell(S, R, C), formula), ast_type(ref(S, R, C, R, C), date) )
    ->  type_word(L, date, Ty)
    ;   input_type(cell(S, R, C), text) -> Ty = TText
    ;   role(cell(S, R, C), input), input_type(cell(S, R, C), number) -> number_type(Fm, Ty)
    ;   role(cell(S, R, C), formula), ast_type(ref(S, R, C, R, C), FT), FT \== any
    ->  ( FT == number -> number_type(Fm, Ty) ; FT == text -> Ty = TText ; Ty = TValue )
    ;   T == number -> number_type(Fm, Ty)
    ;   T == text, \+ role(cell(S, R, C), formula) -> Ty = TText
    ;   Ty = TValue
    ).

number_type(Fm, Ty) :-
    (   ( sub_string(Fm, _, _, _, "$") ; sub_string(Fm, _, _, _, "€") ; sub_string(Fm, _, _, _, "£") ) -> K = amount
    ;   sub_string(Fm, _, _, _, "%") -> K = rate
    ;   K = number
    ),
    lang(L), type_word(L, K, Ty).

%   A date format: d, m, y codes outside quotes and brackets, no digit
%   placeholders (m/d/yyyy, dd-mmm-yy, [$-409]d mmmm yyyy).
date_format(Fm) :-
    string(Fm), Fm \== "General",
    string_lower(Fm, F0),
    re_strip(F0, F1),
    sub_string(F1, _, _, _, "y"), ( sub_string(F1, _, _, _, "d") ; sub_string(F1, _, _, _, "m") ),
    \+ sub_string(F1, _, _, _, "0"), \+ sub_string(F1, _, _, _, "#"), !.

re_strip(S0, S) :-
    string_codes(S0, Cs0), strip_q(Cs0, Cs), string_codes(S, Cs).
strip_q([], []).
strip_q([0'"|T], R) :- !, ( append(_, [0'"|T1], T) -> strip_q(T1, R) ; R = [] ).
strip_q([0'[|T], R) :- !, ( append(_, [0']|T1], T) -> strip_q(T1, R) ; R = [] ).
strip_q([C|T], [C|R]) :- strip_q(T, R).

date_cell(cell(S, R, C)) :- wcell(S, R, C, _, _, _, _, Fm), date_format(Fm).

%!  serial_date(?Serial, ?Date) is det: Excel's day number and LE's date(Y,M,D).
serial_date(N, date(Y, M, D)) :-
    number(N), !,
    Stamp is (N - 25569) * 86400,
    stamp_date_time(Stamp, date(Y, M, D, _, _, _, _, _, _), 'UTC').
serial_date(N, date(Y, M, D)) :-
    date_time_stamp(date(Y, M, D, 0, 0, 0, 0, -, -), Stamp),
    N is round(Stamp / 86400) + 25569.

%!  cell_functor(+Cell, -F) is det.
%
%   The translator's name for the template of a cell: x<sheet>_<address>.
cell_functor(cell(S, R, C), F) :-
    sheet_info(I, S, _, _), a1_text(R, C, A), downcase_atom(A, AD),
    format(atom(F), 'x~w_~w', [I, AD]).

		 /*******************************
		 *        INPUT TYPES           *
		 *******************************/

%   Whether an input holds text or a number: its validation list, its value,
%   or how the formulas use it (compared with text, or computed with).
input_types(Inputs) :-
    index_uses,
    forall(member(Cell, Inputs), ( input_type_of(Cell, T), assertz(input_type(Cell, T)) )).

%   One pass over the formulas: which cells are compared with which texts,
%   and which are computed with (for input_type_of/2).
:- thread_local text_compared/2, number_used/1.
index_uses :-
    retractall(text_compared(_, _)), retractall(number_used(_)),
    forall(( wformula(_, _, _, _, AST), sub_ast(bin(Op, A, B), AST), memberchk(Op, ['=', '<>']),
             ( A = text(T), B = ref(S, R, C, R, C) ; B = text(T), A = ref(S, R, C, R, C) ) ),
           ( text_compared(cell(S, R, C), T) -> true ; assertz(text_compared(cell(S, R, C), T)) )),
    forall(( wformula(_, _, _, _, AST),
             (   sub_ast(bin(Op, A, B), AST), ( arith(Op, _) ; memberchk(Op, ['<', '<=', '>', '>=']) ), member(X, [A, B])
             ;   sub_ast(fn(F, As), AST), memberchk(F, ['SUM', 'MIN', 'MAX', 'ROUND', 'ABS']), member(X, As)
             ),
             X = ref(S, R, C, R, C) ),
           ( number_used(cell(S, R, C)) -> true ; assertz(number_used(cell(S, R, C))) )).

input_type_of(cell(S, R, C), T) :-
    (   date_cell(cell(S, R, C)) -> T = date
    ;   wvalid(S, R, C, Vals), is_list(Vals), \+ ( member(V, Vals), number_string(_, V) ) -> T = text
    ;   wcell(S, R, C, text, _, _, _, _) -> T = text
    ;   wcell(S, R, C, number, _, _, _, _) -> T = number
    ;   compared_with_text(cell(S, R, C)), \+ only_empty_text(cell(S, R, C)) -> T = text
    ;   compared_with_text(cell(S, R, C)), \+ used_as_number(cell(S, R, C)) -> T = text
    ;   T = number
    ).

%   An input compared with "" only (Excel's test for an empty cell) and
%   computed with as well is a number: Excel reads an empty cell as 0 in
%   arithmetic and in a reference (=C13 gives 0), and as "" only in that
%   comparison, which is written as a comparison with 0 (empty_test/3).
only_empty_text(Cell) :- \+ ( text_compared(Cell, T), T \== "" ).

used_as_number(Cell) :- number_used(Cell), !.

compared_with_text(Cell) :- text_compared(Cell, _), !.

refers(ref(S, R, C, R, C), _, cell(S, R, C)).

sub_ast(_, T) :- ( var(T) ; is_dict(T) ), !, fail.
sub_ast(X, X).
sub_ast(X, T) :- compound(T), T =.. [_|As], member(A, As), ( is_list(A) -> member(B, A), ( is_list(B) -> member(Y, B), sub_ast(X, Y) ; sub_ast(X, B) ) ; sub_ast(X, A) ).

		 /*******************************
		 *      FORMULAS AS RULES       *
		 *******************************/

%   val(+AST, +Ctx, -Expr, -Goals0, ?Goals): the value of AST is Expr once
%   Goals hold. cond(+AST, +Ctx, -Body): the conditions under which AST is
%   true. A formula LE cannot express throws residue(Reason).

val(num(N), _, N) --> !.
val(text(S), _, S) --> !.
val(bool(B), _, V) --> !, { bool_atom(B, V) }.
val(omitted, _, 0) --> !.
val(err(M), _, _) --> !, { err_reason(M, R), throw(residue(R)) }.
val(ref(S, R, C, R, C), _, V) --> !, cell_value(cell(S, R, C), V).
val(ref(_, _, _, _, _), _, _) --> !, { throw(residue("a range of cells used as one value")) }.
val(bin(Op, A, B), Ctx, Z) --> { memberchk(Op, ['+', '-']), ast_type(A, TA), ast_type(B, TB),
                                  ( TA == date ; TB == date ) }, !,
    val(A, Ctx, X0), computed(X0, X), val(B, Ctx, Y0), computed(Y0, Y),
    (   { TA == date, TB == date } -> [le_is_days_after(X, Z, Y)]       % the days from Y to X
    ;   { TA == date, Op == '+' } -> [le_is_days_after(Z, Y, X)]
    ;   { TB == date, Op == '+' } -> [le_is_days_after(Z, X, Y)]
    ;   { TA == date, Op == '-' } -> [le_is_days_after(X, Y, Z)]
    ;   { throw(residue("a number minus a date")) }
    ).
val(bin(Op, A, B), Ctx, E) --> { arith(Op, F) }, !,
    val(A, Ctx, X0), as_number(A, X0, X), val(B, Ctx, Y0), as_number(B, Y0, Y), { E =.. [F, X, Y] }.
val(bin('^', A, num(N)), Ctx, E) --> { integer_value(N, K), K >= 1, K =< 4 }, !,
    val(A, Ctx, X), { power_expr(K, X, E) }.
val(bin('^', _, _), _, _) --> !, { throw(residue("a power with an exponent that is not a small whole number")) }.
val(bin('&', _, _), _, _) --> !, { throw(residue("text joined with &")) }.
val(bin(Op, A, B), Ctx, V) --> { comparison(Op, _) }, !, boolean_value(bin(Op, A, B), Ctx, V).
val(un('-', A), Ctx, -(X)) --> !, val(A, Ctx, X0), as_number(A, X0, X).
val(un('+', A), Ctx, X) --> !, val(A, Ctx, X).
val(un('%', A), Ctx, X / 100) --> !, val(A, Ctx, X0), as_number(A, X0, X).
val(fn(F, As), Ctx, V) --> fn_val(F, As, Ctx, V), !.
val(fn(F, _), _, _) --> !, { format(string(R), "the function ~w, which this translator does not read", [F]), throw(residue(R)) }.
val(T, _, _) --> { format(string(R), "a part of a formula this translator does not read (~q)", [T]), throw(residue(R)) }.

%   Arithmetic on a value that may not be a number reads it as Excel does:
%   TRUE as 1, FALSE as 0, a text of digits as its number, any other text as
%   no value (Excel shows #VALUE!). The program then carries the helper
%   template `*a value* counts in arithmetic as *a number*` (counts_items/1).
as_number(AST, X, N) -->
    (   { ast_type(AST, number) } -> { N = X }
    ;   { number(X) } -> { N = X }
    ;   { note_counts }, [xl_counts_as(X, N)]
    ).

:- thread_local counts_used/0.
note_counts :- ( counts_used -> true ; assertz(counts_used) ).

counts_items([template(xl_counts_as, CT, []),
              rule(xl_counts_as(V, V), prolog(number(V)), [comment("A value as Excel reads it in arithmetic: a number as itself, TRUE as 1, FALSE as 0, a text of digits as its number; any other text has no number (Excel shows #VALUE!).")]),
              rule(xl_counts_as(T, N), and(prolog(string(T)), prolog(number_string(N, T))), []),
              fact(xl_counts_as(true, 1), []),
              fact(xl_counts_as(false, 0), [])]) :- counts_used, !, lang(L), frame(L, counts, CT).
counts_items([]).

err_reason(M, R) :-
    (   sub_string(M, _, _, _, "Ref") -> R = "a reference to a deleted cell (#REF!)"
    ;   sub_string(M, _, _, _, "open row/col") -> R = "a whole column or row as a range"
    ;   format(string(R), "a part of the formula the reader could not place (~w)", [M])
    ).

arith('+', +). arith('-', -). arith('*', *). arith('/', /).
comparison('=', eq). comparison('<>', ne). comparison('<', lt). comparison('<=', le).
comparison('>', gt). comparison('>=', ge).

bool_atom(true, true) :- !.
bool_atom(false, false) :- !.
bool_atom(X, X).

integer_value(N, K) :- number(N), K is integer(N), K =:= N.
power_expr(1, X, X).
power_expr(K, X, X * E) :- K > 1, K1 is K - 1, power_expr(K1, X, E).

%   The value of a cell: its template's literal, or a parameter's constant,
%   or 0 for an empty cell.
cell_value(Cell0, V) -->
    {   ( canon(Cell0, K0), rowish(K0) -> Cell = Cell0, Role = row ; Cell = Cell0 ) },
    { nonvar(Role) }, !, cell_value(Role, Cell, V).
cell_value(Cell, V) -->
    {   role(Cell, Role) -> true
    ;   Cell = cell(S, R, C), ( wformula(S, R, C, _, _) -> Role = formula ; wcell(S, R, C, T, _, _, _, _), T \== blank -> Role = param ; Role = blank )
    },
    cell_value(Role, Cell, V).

cell_value(blank, _, 0) --> !.
cell_value(param, Cell, V) --> !,
    {   Cell = cell(S, R, C), wcell(S, R, C, T, Val, _, _, _),
        (   T == error -> throw(residue("a cell holding an error value"))
        ;   T == text, sheet_formula_reads_text(Cell) -> true
        ;   true
        ),
        ( used_constant(Cell) -> true ; assertz(used_constant(Cell)) ),
        cell_functor(Cell, F), L =.. [F, V], _ = Val
    },
    [L].
cell_value(_, Cell, V) -->
    { canon(Cell, K), rowish(K) }, !,
    {   cell_functor(K, F), Cell = cell(_, R, _),
        (   nb_current(xl_row, row(RV, R)) -> Row = RV            % the rule's own row
        ;   nb_current(xl_row, row(_, _)) -> throw(residue("a reference to another row of copied rows"))
        ;   row_atom(R, Row)                                       % one row, from outside
        ),
        L =.. [F, Row, V] },
    [L].
cell_value(_, Cell, V) -->
    { cell_functor(Cell, F), L =.. [F, V] },
    [L].

sheet_formula_reads_text(_).

%   A comparison, AND, OR or NOT used as a value: TRUE or FALSE.
boolean_value(AST, Ctx, V) -->
    { pcond(AST, Ctx, Pre, T) },
    Pre,
    [otherwise([and(T, V = true), V = false])].

fn_val('IF', [C, A|Rest], Ctx, V) -->
    { pcond(C, Ctx, Pre, CB) },
    Pre,
    {
      ( Rest = [B|_] -> true ; B = bool(false) ),
      branch(A, Ctx, V, BA), branch(B, Ctx, V, BB) },
    [otherwise([and(CB, BA), BB])].
%   CHOOSE(i, v1, v2, ...): the i-th value, a cascade over i.
fn_val('CHOOSE', [I|Vs], Ctx, V) --> { Vs \== [] }, !,
    val(I, Ctx, X0), computed(X0, X),
    { choose_alts(Vs, 1, X, Ctx, V, Alts) },
    [otherwise(Alts)].
%   SUMIF(range, criterion[, sum range]), COUNTIF(range, criterion), and the
%   plural forms: over a range of at most 400 cells, a sum of one term per
%   cell, the cell's value where every criterion holds, else 0.
fn_val('SUMIF', [Rg, Crit], Ctx, E) --> !, fn_val('SUMIFS', [Rg, Rg, Crit], Ctx, E).
fn_val('SUMIF', [Rg, Crit, SumRg], Ctx, E) --> !, fn_val('SUMIFS', [SumRg, Rg, Crit], Ctx, E).
fn_val('COUNTIF', [Rg, Crit], Ctx, E) --> !, fn_val('COUNTIFS', [Rg, Crit], Ctx, E).
fn_val('SUMIFS', [SumRg|Pairs], Ctx, E) --> { criteria_pairs(Pairs, Ps) }, !, conditional_sum(sum(SumRg), Ps, Ctx, E).
fn_val('COUNTIFS', Pairs, Ctx, E) --> { criteria_pairs(Pairs, Ps), Ps = [Rg-_|_] }, !, conditional_sum(count(Rg), Ps, Ctx, E).
fn_val('IFERROR', [A, B], Ctx, V) -->
    { branch(A, Ctx, V, BA), branch(B, Ctx, V, BB) },
    [otherwise([BA, BB])].
fn_val(F, As, Ctx, V) --> { memberchk(F, ['AND', 'OR', 'NOT']) }, !,
    boolean_value(fn(F, As), Ctx, V).
fn_val(F, As, Ctx, V) --> { memberchk(F, ['ISERROR', 'ISNA', 'ISERR', 'ISNUMBER', 'ISTEXT', 'ISBLANK', 'TRUE', 'FALSE']) }, !,
    boolean_value(fn(F, As), Ctx, V).
fn_val('SUM', As, Ctx, E) -->
    sum_terms(As, Ctx, Es), { sum_expr(Es, E) }.
fn_val('AVERAGE', As, Ctx, E) -->
    sum_terms(As, Ctx, Es), { Es \== [], sum_expr(Es, S), length(Es, N), E = S / N }.
fn_val('MIN', As, Ctx, E) --> sum_terms(As, Ctx, Es), { Es \== [] }, min_max(min, Es, E).
fn_val('MAX', As, Ctx, E) --> sum_terms(As, Ctx, Es), { Es \== [] }, min_max(max, Es, E).
fn_val('ABS', [A], Ctx, abs(X)) --> val(A, Ctx, X).
fn_val('INT', [A], Ctx, floor(X)) --> val(A, Ctx, X).
fn_val('TRUNC', [A], Ctx, truncate(X)) --> val(A, Ctx, X).
fn_val('TRUNC', [A, num(N)], Ctx, E) --> val(A, Ctx, X), { scaled(truncate, X, N, E) }.
fn_val('ROUND', [A, num(N)], Ctx, E) --> val(A, Ctx, X), { round_expr(X, N, E) }.
fn_val('ROUND', [A], Ctx, E) --> val(A, Ctx, X), { round_expr(X, 0, E) }.
fn_val('ROUNDDOWN', [A, num(N)], Ctx, E) --> val(A, Ctx, X), { scaled(truncate, X, N, E) }.
fn_val('ROUNDUP', [A, num(N)], Ctx, E) --> val(A, Ctx, X), { scaled(roundup, X, N, E) }.
fn_val('MOD', [A, B], Ctx, X - Y * floor(X / Y)) --> val(A, Ctx, X), val(B, Ctx, Y).
fn_val('POWER', [A, num(N)], Ctx, E) --> { integer_value(N, K), K >= 1, K =< 4 }, val(A, Ctx, X), { power_expr(K, X, E) }.
fn_val('SQRT', [A], Ctx, sqrt(X)) --> val(A, Ctx, X).
%   EDATE(d, n): the date n months after d (LE's months: the same day, or the
%   month's last day).
fn_val('EDATE', [D, N], Ctx, Z) --> val(D, Ctx, X), val(N, Ctx, K0), computed(K0, K), [le_is_months_after(Z, K, X)].
fn_val('YEAR', [D], Ctx, Y) --> val(D, Ctx, X), [prolog(arg(1, X, Y))].
fn_val('MONTH', [D], Ctx, Y) --> val(D, Ctx, X), [prolog(arg(2, X, Y))].
fn_val('DAY', [D], Ctx, Y) --> val(D, Ctx, X), [prolog(arg(3, X, Y))].
fn_val('SIGN', [A], Ctx, sign(X)) --> val(A, Ctx, X).
fn_val('VALUE', [A], Ctx, X) --> val(A, Ctx, X).
fn_val('N', [A], Ctx, X) --> val(A, Ctx, X).
fn_val(F, As, Ctx, V) --> { lookup_function(F, As, Key, Range, Spec) }, !,
    lookup_value(Key, Range, Spec, Ctx, V).

choose_alts([], _, _, _, _, []).
choose_alts([VK|Vs], K, X, Ctx, V, [and(K = X, B)|Alts]) :-
    branch(VK, Ctx, V, B), K1 is K + 1, choose_alts(Vs, K1, X, Ctx, V, Alts).

criteria_pairs([], []).
criteria_pairs([R, C|T], [R-C|Ps]) :- R = ref(_, _, _, _, _), criteria_pairs(T, Ps).

range_cells_list(ref(S, R1, C1, R2, C2), Cells) :-
    N is (R2 - R1 + 1) * (C2 - C1 + 1),
    ( N > 400 -> throw(residue("a conditional sum over more than 400 cells")) ; true ),
    findall(cell(S, R, C), ( between(R1, R2, R), between(C1, C2, C) ), Cells).

conditional_sum(What, Pairs, Ctx, E) -->
    { ( What = sum(SR) -> range_cells_list(SR, Cells) ; What = count(CR), range_cells_list(CR, Cells) ),
      length(Cells, N),
      findall(Cs, ( member(Rg-_, Pairs), range_cells_list(Rg, Cs), length(Cs, N) ), Css),
      length(Pairs, NP), length(Css, NC), ( NP == NC -> true ; throw(residue("criteria ranges of different sizes")) ) },
    criteria_values(Pairs, Ctx, Crits),
    cond_terms(Cells, 1, What, Css, Crits, Ctx, Ts),
    { sum_expr(Ts, E) }.

criteria_values([], _, []) --> [].
criteria_values([_-C|Ps], Ctx, [Op-V|Cs]) --> criterion(C, Ctx, Op, V), criteria_values(Ps, Ctx, Cs).

%   ">0", "<>x", "Yes", 5, ">"&B7, B7: an operator and a value.
criterion(text(T), _, Op, V) --> !, { crit_text(T, Op, V) }.
criterion(num(N), _, eq, N) --> !.
criterion(bin('&', text(OpT), X), Ctx, Op, V) --> !, { crit_text(OpT, Op, "") }, val(X, Ctx, V0), computed(V0, V).
criterion(X, Ctx, eq, V) --> val(X, Ctx, V0), computed(V0, V).

crit_text(T, Op, V) :-
    member(P-Op, [">="-ge, "<="-le, "<>"-ne, ">"-gt, "<"-lt, "="-eq]), string_concat(P, Rest, T), !,
    ( Rest == "" -> V = "" ; number_string(V, Rest) -> true ; V = Rest ).
crit_text(T, eq, V) :- ( number_string(V, T) -> true ; V = T ).

cond_terms([], _, _, _, _, _, []) --> [].
cond_terms([Cell|Cells], I, What, Css, Crits, Ctx, [T|Ts]) -->
    {   cells_criteria(Css, Crits, I, CCs) },
    cell_tests(CCs, Tests),
    (   { What = sum(_) } -> cell_value(Cell, V0), computed(V0, V) ; { V = 1 } ),
    { conj(Tests, Test), T = Tv },
    [otherwise([and(Test, Tv = V), Tv = 0])],
    { I1 is I + 1 },
    cond_terms(Cells, I1, What, Css, Crits, Ctx, Ts).

cells_criteria([], [], _, []).
cells_criteria([Cs|Css], [Crit|Crits], I, [C-Crit|CCs]) :- nth1(I, Cs, C), cells_criteria(Css, Crits, I, CCs).

%   Excel's criteria: a comparison holds only for a number; equality with a
%   text is with that text.
cell_tests([], []) --> [].
cell_tests([C-(Op-V)|CCs], [T|Ts]) -->
    cell_value(C, X),
    {   Op == eq -> T = (V = X)
    ;   Op == ne -> T = (X \= V)
    ;   cmp_goal(Op, X, V, G), T = and(prolog(number(X)), G)
    },
    cell_tests(CCs, Ts).

%   A branch of IF: V takes the branch's value.
branch(AST, Ctx, V, Body) :-
    phrase(val(AST, Ctx, E), Gs),
    (   var(E), \+ ( member(G, Gs), sub_term(X, G), X == V )
    ->  E = V, conj(Gs, Body)
    ;   assign(V, E, A), append(Gs, [A], Gs1), conj(Gs1, Body)
    ).

assign(V, E, V is E) :- compound(E), \+ string(E), !.
assign(V, E, V = E).

conj([], true).
conj([G], G) :- !.
conj([G|Gs], B) :- foldl([X, A0, and(A0, X)]>>true, Gs, G, B).

sum_terms([], _, []) --> [].
sum_terms([A|As], Ctx, Es) -->
    (   { A = ref(S, R1, C1, R2, C2), ( R1 \== R2 ; C1 \== C2 ) }
    ->  range_terms(S, R1, C1, R2, C2, Es1)
    ;   val(A, Ctx, E), { Es1 = [E] }
    ),
    sum_terms(As, Ctx, Es2), { append(Es1, Es2, Es) }.

%   The cells of a range that count in SUM, MIN, MAX: formulas, inputs and
%   numbers (text and empty cells are left out, as Excel does).
range_terms(S, R1, C1, R2, C2, [Sum]) -->
    { C1 == C2, R2 > R1, canon(cell(S, R1, C1), K), rowish(K),
      copied_rows_of(K, Rows), Rows = [R1|_], last(Rows, R2) }, !,       % the whole column: an aggregate
    { cell_functor(K, F), L =.. [F, Row, X] },
    [agg(sum, X, L, Sum)], { _ = Row }.
range_terms(S, R1, C1, R2, C2, Es) -->
    { findall(cell(S, R, C), ( between(R1, R2, R), between(C1, C2, C), counts_in_sum(cell(S, R, C)) ), Cells),
      length(Cells, N),
      ( N > 400 -> throw(residue("a sum over more than 400 cells")) ; true ) },
    cells_values(Cells, Es).

counts_in_sum(Cell) :-
    canon(Cell, K), K \== Cell, !, counts_in_sum(K).        % a copied row counts as its column's first
counts_in_sum(cell(S, R, C)) :-
    (   wformula(S, R, C, _, _) -> true
    ;   role(cell(S, R, C), input) -> \+ input_type(cell(S, R, C), text)
    ;   wcell(S, R, C, number, _, _, _, _)
    ).

cells_values([], []) --> [].
cells_values([C|Cs], [E|Es]) --> cell_value(C, E), cells_values(Cs, Es).

sum_expr([E], E) :- !.
sum_expr([E|Es], S) :- foldl([X, A0, A0 + X]>>true, Es, E, S).

%   The least (greatest) of several values: LE's conditions `the minimum of X
%   and Y is Z` (it has no min or max function), one per pair.
min_max(_, [E], E) --> !.
min_max(F, [A0, B0|Es], E) --> computed(A0, A), computed(B0, B), { le_min_max(F, LF), G =.. [LF, A, B, Z] }, [G], min_max(F, [Z|Es], E).

le_min_max(min, le_minimum).
le_min_max(max, le_maximum).

%   A value the conditions of LE take as given: a formula is worked out first.
computed(X, X) --> { \+ compound(X) ; string(X) }, !.
computed(X, Y) --> [Y is X].

fold_fn(_, [E], E) :- !.
fold_fn(F, [E|Es], R) :- fold_fn_(Es, F, E, R).
fold_fn_([], _, R, R).
fold_fn_([X|Xs], F, A0, R) :- T =.. [F, A0, X], fold_fn_(Xs, F, T, R).

scaled(F, X, N0, E) :-
    integer_value(N0, N),
    (   N =:= 0 -> E0 = X ; P is 10 ** N, E0 = X * P ),
    (   F == truncate -> T = truncate(E0)
    ;   F == roundup -> T = sign(E0) * ceiling(abs(E0))
    ),
    (   N =:= 0 -> E = T ; P is 10 ** N, E = T / P ).

%   Excel rounds half away from zero on the decimal it shows: 2.675 to two
%   decimals is 2.68, though the binary number is a little less. LE's round/1
%   on the scaled number, nudged by a relative 1e-12 (far below the 15 digits
%   a cell shows), gives the same.
round_expr(X, N0, E) :-
    integer_value(N0, N),
    (   N =:= 0 -> E = round(X * (1 + 1.0e-12))
    ;   P is 10 ** N, E = round(X * P * (1 + 1.0e-12)) / P
    ).

		 /*******************************
		 *          CONDITIONS          *
		 *******************************/

%   pcond(+AST, +Ctx, -Pre, -Test): the condition AST as the goals that
%   must hold first (reading cells, arithmetic: where Excel would show an
%   error, LE answers nothing, so an error in an IF's condition is an error
%   of the IF, as in Excel) and a test over their values. A cascade then
%   tests only Test, so its guards are exact.
cond(AST, Ctx, Body) :-
    pcond(AST, Ctx, Pre, Test), append(Pre, [Test], Gs), conj(Gs, Body).

pcond(bin(Op, A0, B0), Ctx, Pre, G) :- comparison(Op, K), memberchk(K, [eq, ne]),
    ( empty_test(A0, B0, A, B) ; empty_test(B0, A0, B, A) ), !,
    pcond(bin(Op, A, B), Ctx, Pre, G).
pcond(bin(Op, A, B), Ctx, Pre, G) :- comparison(Op, K), !,
    phrase(( val(A, Ctx, X), val(B, Ctx, Y) ), Pre),
    (   K == eq -> eq_goal(A, B, X, Y, G)
    ;   K == ne -> cmp_goal(K, X, Y, G)
    ;   ast_type(A, number), ast_type(B, number) -> cmp_goal(K, X, Y, G)
    ;   ( ast_type(A, date) ; ast_type(B, date) ) -> date_goal(K, X, Y, G)
    ;   order_goal(K, X, Y, G)          % a number below any text, as Excel orders them
    ).
pcond(fn('AND', As), Ctx, Pre, Test) :- !,
    pconds(As, Ctx, Pres, Tests), append(Pres, Pre), conj(Tests, Test).
%   OR as alternatives that exclude each other — the first that holds — so
%   that a case meeting two of them is still one answer.
pcond(fn('OR', As), Ctx, Pre, Test) :- !,
    pconds(As, Ctx, Pres, Tests), append(Pres, Pre), exclusive_or(Tests, Test).
pcond(fn('NOT', [A]), Ctx, Pre, not(T)) :- !, pcond(A, Ctx, Pre, T).
pcond(fn('TRUE', []), _, [], true) :- !.
pcond(fn('FALSE', []), _, [], fail) :- !.
pcond(bool(true), _, [], true) :- !.
pcond(bool(false), _, [], fail) :- !.
%   IF inside a condition: its condition first, its branches only when taken.
pcond(fn('IF', [C, A, B]), Ctx, Pre, or(and(TC, AB), and(not(TC), BB))) :- !,
    pcond(C, Ctx, Pre, TC), cond(A, Ctx, AB), cond(B, Ctx, BB).
%   ISERROR(x), ISNA(x): x has no value (LE answers nothing where Excel shows
%   an error; the ledger notes the approximation).
pcond(fn(F, [A]), Ctx, [], not(B)) :- memberchk(F, ['ISERROR', 'ISNA', 'ISERR']), !,
    phrase(val(A, Ctx, X), Gs),
    (   compound(X), \+ string(X) -> append(Gs, [_ is X], Gs1)    % computed: a division by zero has no value
    ;   Gs == [] -> Gs1 = [X = X]
    ;   Gs1 = Gs
    ),
    conj(Gs1, B).
pcond(fn('ISNUMBER', [A]), Ctx, [], Body) :- !,
    phrase(val(A, Ctx, X), Gs), append(Gs, [prolog(number(X))], Gs1), conj(Gs1, Body).
pcond(fn('ISTEXT', [A]), Ctx, [], Body) :- !,
    phrase(val(A, Ctx, X), Gs), append(Gs, [prolog(string(X))], Gs1), conj(Gs1, Body).
pcond(fn('ISBLANK', [A]), Ctx, Pre, X = Empty) :- !,
    (   A = ref(S, R, C, R, C), role(cell(S, R, C), input)
    ->  phrase(val(A, Ctx, X), Pre),
        ( input_type(cell(S, R, C), text) -> Empty = "" ; Empty = 0 )
    ;   throw(residue("ISBLANK of a cell that is not an input"))
    ).
%   Any other value used as a condition: true unless it is 0 or FALSE.
pcond(AST, Ctx, Pre, and(X \= 0, X \= false)) :-
    phrase(val(AST, Ctx, X), Pre).

pconds([], _, [], []).
pconds([A|As], Ctx, [P|Ps], [T|Ts]) :- pcond(A, Ctx, P, T), pconds(As, Ctx, Ps, Ts).

%   Tests over values already read: "one of them holds" as "it is not the
%   case that none holds" — true once however many hold, and with no
%   cascade to nest inside the IF's own.
exclusive_or([T], T) :- !.
exclusive_or(Ts, not(All)) :- negations(Ts, Ns), conj(Ns, All).

negations([], []).
negations([T|Ts], [not(T)|Ns]) :- negations(Ts, Ns).

conds([], _, []).
conds([A|As], Ctx, [B|Bs]) :- cond(A, Ctx, B), conds(As, Ctx, Bs).

%   (Prolog's standard order of terms puts every number before every text,
%   as Excel does.)
%   An equality inside a cascade is a test only if LE can see it is one
%   (language.md §17.2: `X is equal to "y"` whose X no other condition of the
%   alternative names reads as setting X): the constant first, and two
%   values compared with Prolog's own equality.
eq_goal(_, _, X, Y, G) :- var(X), \+ var(Y), !, G = (Y = X).
eq_goal(_, _, X, Y, G) :- \+ var(X), !, G = (X = Y).
eq_goal(A, B, X, Y, prolog(X =:= Y)) :- ast_type(A, number), ast_type(B, number), !.
eq_goal(_, _, X, Y, prolog(X == Y)).

%   ="" on a numeric input: Excel's test for an empty cell; the twin states an
%   empty input as 0, so the test is = 0 (an entered 0 counts as empty).
empty_test(text(""), ref(S, R, C, R, C), num(0), ref(S, R, C, R, C)) :-
    role(cell(S, R, C), input), \+ input_type(cell(S, R, C), text).

date_goal(lt, X, Y, le_lt(X, Y)).
date_goal(le, X, Y, le_le(X, Y)).
date_goal(gt, X, Y, le_gt(X, Y)).
date_goal(ge, X, Y, le_ge(X, Y)).

order_goal(lt, X, Y, prolog(compare(<, X, Y))).
order_goal(le, X, Y, not(prolog(compare(>, X, Y)))).
order_goal(gt, X, Y, prolog(compare(>, X, Y))).
order_goal(ge, X, Y, not(prolog(compare(<, X, Y)))).

%   ast_type(+AST, -Type): number, text, bool or any — what a formula always
%   gives, as far as its form says.
:- thread_local type_memo/2.
ast_type(AST, T) :- catch(ast_type_(AST, [], T), _, T = any).

ast_type_(num(_), _, number) :- !.
ast_type_(text(_), _, text) :- !.
ast_type_(bool(_), _, bool) :- !.
ast_type_(ref(S, R, C, R, C), Seen, T) :- !, cell_type(cell(S, R, C), Seen, T).
ast_type_(bin(Op, A, B), Seen, T) :- memberchk(Op, ['+', '-']),
    ast_type_(A, Seen, TA), ast_type_(B, Seen, TB),
    (   TA == date, TB == date -> T = number          % days between
    ;   ( TA == date ; TB == date ) -> T = date
    ), !.
ast_type_(fn(F, _), _, date) :- memberchk(F, ['EDATE', 'TODAY', 'DATE']), !.
ast_type_(fn(F, _), _, number) :- memberchk(F, ['YEAR', 'MONTH', 'DAY']), !.
ast_type_(bin(Op, _, _), _, number) :- arith(Op, _), !.
ast_type_(bin('^', _, _), _, number) :- !.
ast_type_(bin('&', _, _), _, text) :- !.
ast_type_(bin(Op, _, _), _, bool) :- comparison(Op, _), !.
ast_type_(un(_, _), _, number) :- !.
ast_type_(fn('IF', [_, A|Rest]), Seen, T) :- !,
    ast_type_(A, Seen, TA), ( Rest = [B|_] -> ast_type_(B, Seen, TB) ; TB = bool ), lub(TA, TB, T).
ast_type_(fn('IFERROR', [A, B]), Seen, T) :- !, ast_type_(A, Seen, TA), ast_type_(B, Seen, TB), lub(TA, TB, T).
ast_type_(fn(F, _), _, number) :-
    memberchk(F, ['SUM', 'AVERAGE', 'MIN', 'MAX', 'ABS', 'INT', 'TRUNC', 'ROUND', 'ROUNDUP', 'ROUNDDOWN', 'MOD', 'POWER', 'SQRT', 'SIGN', 'VALUE', 'N', 'COUNT', 'COUNTIF']), !.
ast_type_(fn(F, _), _, bool) :-
    memberchk(F, ['AND', 'OR', 'NOT', 'ISERROR', 'ISNA', 'ISERR', 'ISNUMBER', 'ISTEXT', 'ISBLANK', 'TRUE', 'FALSE']), !.
ast_type_(fn(F, As), _, T) :-
    lookup_function(F, As, _, ref(S, R1, C1, R2, C2), spec(Dir, _, RIdx, _)), !,
    (   Dir == rows -> findall(V, ( between(R1, R2, R), wcell(S, R, RIdx, _, V, _, _, _), V \== blank ), Vs)
    ;   findall(V, ( between(C1, C2, C), wcell(S, RIdx, C, _, V, _, _, _), V \== blank ), Vs)
    ),
    ( Vs \== [], forall(member(V, Vs), number(V)) -> T = number ; T = any ).
ast_type_(_, _, any).

cell_type(Cell, _, T) :- type_memo(Cell, T), !.
cell_type(Cell, Seen, any) :- memberchk(Cell, Seen), !.
cell_type(Cell, Seen, T) :-
    Cell = cell(S, R, C),
    (   wformula(S, R, C, _, AST) -> ast_type_(AST, [Cell|Seen], T0),
        ( T0 == number, date_cell(Cell) -> T = date ; T = T0 )
    ;   role(Cell, input), input_type(Cell, date) -> T = date
    ;   role(Cell, input) -> ( input_type(Cell, text) -> T = text ; T = number )
    ;   wcell(S, R, C, number, _, _, _, _) -> T = number
    ;   wcell(S, R, C, text, _, _, _, _) -> T = text
    ;   wcell(S, R, C, boolean, _, _, _, _) -> T = bool
    ;   T = number                      % an empty cell reads as 0
    ),
    assertz(type_memo(Cell, T)).

lub(T, T, T) :- !.
lub(_, _, any).

cmp_goal(eq, X, Y, X = Y).
cmp_goal(ne, X, Y, X \= Y).
cmp_goal(lt, X, Y, X < Y).
cmp_goal(le, X, Y, X =< Y).
cmp_goal(gt, X, Y, X > Y).
cmp_goal(ge, X, Y, X >= Y).

		 /*******************************
		 *        LOOKUP TABLES         *
		 *******************************/

%   A lookup is a decision table over the lookup range: one row per row (or
%   column) of the range, the key column a condition (an approximate match
%   is a band, `>= k and < next`, with first match), the result column the
%   answer.
lookup_value(Key, ref(S, R1, C1, R2, C2), spec(by_column(ColAST), KC, LC, M), Ctx, V) --> !,
    val(Key, Ctx, K), val(ColAST, Ctx, N),
    { table_for(S, R1, C1, R2, C2, spec(by_column, KC, LC, M), _, F) },
    { L =.. [F, K, N, V] },
    [L].
lookup_value(Key, ref(S, R1, C1, R2, C2), Spec, Ctx, V) -->
    val(Key, Ctx, K),
    { table_for(S, R1, C1, R2, C2, Spec, Id, F) },
    { L =.. [F, K, V] },
    [L],
    { _ = Id }.

table_for(S, R1, C1, R2, C2, Spec, Id, F) :-
    Key = key(S, R1, C1, R2, C2, Spec),
    (   table_def(Id, _, Key, _, _, _) -> true
    ;   make_table(Key, Id)
    ),
    table_def(Id, _, Key, _, _, _),
    atom_concat(t_, Id, F).

make_table(Key, Id) :-
    Key = key(S, R1, C1, R2, _, spec(by_column, KC, LC, Match)), !,
    findall(KV, ( between(R1, R2, R), const_value(S, R, KC, KV) ), Keys0),
    (   Keys0 == [] -> throw(residue("a lookup table with no constant rows")) ; true ),
    findall(KV-R, ( between(R1, R2, R), const_value(S, R, KC, KV) ), KRs),
    pairs_keys(KRs, Ks),
    (   Match == approximate, forall(member(K0, Ks), number(K0)) -> bands_of(Ks, Conds) ; Conds = Ks ),
    findall([Cond, N, V], ( nth1(I, KRs, _-R), nth1(I, Conds, Cond), between(KC, LC, C), C > KC,
                            const_value(S, R, C, V), N is C - KC + 1 ), Rows),
    table_name(S, R1, C1, rows, KC, Name0), unique_table_name(Name0, Name), Id = Name,
    assertz(table_def(Id, Name, Key, first, Rows, "")).
make_table(Key, Id) :-
    Key = key(S, R1, C1, R2, C2, spec(Dir, KIdx, RIdx, Match)),
    (   Match == unsupported -> throw(residue("a MATCH with a match type other than 0 or 1")) ; true ),
    (   Dir == rows
    ->  findall(KV-RV, ( between(R1, R2, R), const_value(S, R, KIdx, KV), const_value(S, R, RIdx, RV) ), Pairs)
    ;   findall(KV-RV, ( between(C1, C2, C), const_value(S, KIdx, C, KV), const_value(S, RIdx, C, RV) ), Pairs)
    ),
    (   Pairs == [] -> throw(residue("a lookup table with no constant rows")) ; true ),
    (   ( between(R1, R2, R), between(C1, C2, C), wformula(S, R, C, _, _) )
    ->  Note = "the table holds formulas; their values as saved are its rows"
    ;   Note = ""
    ),
    table_rows(Match, Pairs, Rows, Policy, Note2),
    table_name(S, R1, C1, Dir, KIdx, RIdx, Name0),
    unique_table_name(Name0, Name),
    Id = Name,
    ( Note2 == "" -> N = Note ; Note == "" -> N = Note2 ; format(string(N), "~w; ~w", [Note, Note2]) ),
    assertz(table_def(Id, Name, Key, Policy, Rows, N)).

const_value(S, R, C, V) :-
    wcell(S, R, C, T, V0, _, _, _),
    memberchk(T, [number, text, boolean]),
    ( T == boolean -> bool_atom(V0, V) ; V = V0 ).

%   Approximate match on numbers: Excel takes the largest key not above the
%   value (keys in ascending order); on text, a key equal to the value
%   (Excel's own order of text is not LE's: the ledger says so).
table_rows(exact, Pairs, Rows, first, "") :- !,
    findall([KV, RV], member(KV-RV, Pairs), Rows).
table_rows(approximate, Pairs, Rows, first, Note) :-
    (   forall(member(K-_, Pairs), number(K))
    ->  bands(Pairs, Rows), Note = ""
    ;   findall([KV, RV], member(KV-RV, Pairs), Rows),
        Note = "an approximate match on text keys, read as an exact match"
    ).

bands_of([K], [cond((>=)-K)]) :- !.
bands_of([K, K2|Ks], [cond(and((>=)-K, (<)-K2))|Cs]) :- bands_of([K2|Ks], Cs).

bands([K-V], [[cond((>=)-K), V]]) :- !.
bands([K-V, K2-V2|Ps], [[cond(and((>=)-K, (<)-K2)), V]|Rows]) :- bands([K2-V2|Ps], Rows).

table_name(S, R1, C1, Dir, KIdx, Name) :- table_name(S, R1, C1, Dir, KIdx, KIdx, Name).
%   named after the column the lookup returns (its header), else the key's
table_name(S, R1, C1, Dir, KIdx, RIdx, Name) :-
    Dir == rows, RIdx \== KIdx,
    between(1, 3, D), R0 is R1 - D, R0 >= 1, text_cell(S, R0, RIdx, T),
    label_words(T, Ws), Ws \== [], !,
    ( length(Ws, N), N > 6 -> length(W6, 6), append(W6, _, Ws) ; W6 = Ws ),
    atomic_list_concat(W6, '_', Name0), atom_string(Name0, _), Name = Name0, _ = C1.
table_name(S, R1, C1, Dir, KIdx, _, Name) :-
    (   Dir == rows -> KC = KIdx ; KC = C1 ),
    (   between(1, 3, D), R0 is R1 - D, R0 >= 1,
        ( text_cell(S, R0, KC, T) ; text_cell(S, R0, 1, T) ), label_words(T, Ws), Ws \== []
    ->  true
    ;   label_words(S, SW), a1_text(R1, C1, A), downcase_atom(A, AD), append(SW, [AD], Ws)
    ),
    ( length(Ws, N), N > 6 -> length(W6, 6), append(W6, _, Ws) ; W6 = Ws ),
    atomic_list_concat(W6, '_', Name).

unique_table_name(N00, N) :-
    %  a table's name must start with a letter (LE reads a leading digit as a number)
    ( sub_atom(N00, 0, 1, _, Ch), char_type(Ch, alpha) -> N0 = N00 ; atom_concat(table_, N00, N0) ),
    (   \+ table_def(_, N0, _, _, _, _) -> N = N0
    ;   between(2, 99, I), format(atom(N), '~w_~w', [N0, I]), \+ table_def(_, N, _, _, _, _) -> true
    ).

		 /*******************************
		 *         THE PROGRAM          *
		 *******************************/

%!  workbook_items(+Options, -Items, -Info) is det.
%
%   Info = info(Inputs, Outputs, Queries): the input cells, the output
%   cells, and Cell-QueryName for each output.
workbook_items(Options, Items, info(Inputs, Outputs, QNames)) :-
    retractall(wb_lang(_)),
    (   option(language(Lang), Options) -> true ; detect_language(Lang) ),
    assertz(wb_lang(Lang)),
    dependencies(Options),
    copied_rows,
    roles(Options),
    input_cells(Inputs),
    input_types(Inputs),
    (   option(outputs(all), Options)
    ->  outputs(Os1), reach(Os1, Outputs0)      % every formula cell checked: a diagnosis
    ;   option(outputs(Refs), Options), is_list(Refs)
    ->  %  the answer cells the author names: only what they need is translated
        maplist(given_cell, Refs, Cs0),
        maplist([C0, C]>>( canon(C0, K) -> C = K ; C = C0 ), Cs0, Cs1), sort(Cs1, Outputs0)
    ;   outputs(Outputs0)
    ),
    option(max_outputs(MaxO), Options, 200),
    ( length(Outputs0, NO), NO > MaxO -> length(Outputs, MaxO), append(Outputs, _, Outputs0) ; Outputs = Outputs0 ),
    reach(Outputs, Formulas),
    findall(C, ( member(F, Formulas), reads(F, C), role(C, param) ), Params0), sort(Params0, Params),
    append([Inputs, Params, Formulas], Named0), sort(Named0, Named),
    labels(Named),
    findall(Cell-R, ( member(Cell, Formulas), cell_rule(Cell, Options, R) ), CellRules),
    pairs_values(CellRules, RuleItems0),
    % templates: inputs, constants actually used, formulas
    findall(template(F, T, [undefined]), ( member(C, Inputs), cell_functor(C, F), template_text(C, T) ), TIn),
    findall(I, ( member(C, Params), used_constant(C), constant_items(C, I0), member(I, I0) ), TConst0),
    partition([X]>>(X = template(_, _, _)), TConst0, TConstT, TConstF),
    %  each formula is asked many times within one query (every cell reading
    %  it asks again): remembered once worked out (language.md §2.5)
    ( option(memorable(false), Options) -> FAdds = [] ; FAdds = [memorable] ),
    findall(template(F, T, FAdds), ( member(C, Formulas), cell_functor(C, F), template_text(C, T) ), TF),
    findall(template(F, T, []), ( table_def(Id, _, _, _, _, _), table_template(Id, F, T) ), TT),
    findall(table(N, [policy(P), provenance(Pv)], Cols, Rows),
            ( table_def(Id, N, Key, P, Rows0, _), table_columns(Id, Key, Cols), table_items_rows(Rows0, Rows),
              table_provenance(Key, Pv) ), Tables),
    findall(Cell-Q, ( member(Cell, Outputs), query_name(Cell, Q) ), QNames),
    findall(query(Q, G), ( member(Cell-Q, QNames), cell_functor(Cell, F),
                           ( rowish(Cell) -> G =.. [F, _, _] ; G =.. [F, _] ) ), Queries),
    flatten(RuleItems0, RuleItems),
    counts_items(CItems),
    partition([X]>>(X = template(_, _, _)), CItems, CT, CR),
    append([TIn, TConstT, TF, TT, CT, Tables, TConstF, CR, RuleItems, Queries], Items).

%   The formula cells the outputs need, in the order of the sheet.
reach(Outputs, Cells) :-
    reach_(Outputs, [], Cs0), sort(Cs0, Cells).
reach_([], Acc, Acc).
reach_([C|Cs], Acc, Out) :-
    (   memberchk(C, Acc) -> reach_(Cs, Acc, Out)
    ;   findall(D, ( reads(C, D), role(D, formula) ), Ds),
        append(Ds, Cs, Next), reach_(Next, [C|Acc], Out)
    ).

%   A parameter: a template and the fact the sheet states, citing its cell.
constant_items(Cell, [template(F, T, []), fact(L, [provenance([as_stated_in(Doc), at(Loc)])])]) :-
    cell_functor(Cell, F),
    Cell = cell(S, R, C), wcell(S, R, C, Ty0, V0, _, _, _),
    ( Ty0 == boolean -> bool_atom(V0, V) ; V = V0 ),
    L =.. [F, V],
    template_text(Cell, T),
    workbook_name(Doc), a1_text(R, C, A), format(atom(Loc), '~w ~w', [S, A]).

table_template(Id, F, T) :-
    table_def(Id, Name, key(_, _, _, _, _, spec(Dir, _, _, _)), _, _, _), atom_concat(t_, Id, F),
    atomic_list_concat(Ws, '_', Name), atomic_list_concat(Ws, ' ', W),
    lang(L), ( Dir == by_column -> frame(L, table2, Fm) ; frame(L, table, Fm) ),
    format(string(T), Fm, [W, Name]).

table_columns(_, key(_, _, _, _, _, spec(by_column, _, _, _)), [row, key, column, value]) :- !.
table_columns(_, _, [row, key, value]).

table_items_rows(Rows0, Rows) :-
    findall([RN|Row], ( nth1(I, Rows0, Row), format(atom(RN), 'r~w', [I]) ), Rows).

table_provenance(key(S, R1, C1, R2, C2, _), [as_stated_in(Doc), at(Loc)]) :-
    workbook_name(Doc),
    a1_text(R1, C1, A), a1_text(R2, C2, B),
    format(atom(Loc), '~w ~w to ~w', [S, A, B]).

:- thread_local wb_name/1.
workbook_name(N) :- ( wb_name(N0) -> N = N0 ; N = 'workbook.xlsx' ).

query_name(Cell, Q) :-
    cell_label(Cell, l(Ws, _)),
    ( length(Ws, N), N > 5 -> length(W5, 5), append(W5, _, Ws) ; W5 = Ws ),
    atomic_list_concat([q|W5], '_', Q0),
    (   cell_functor(Cell, F), \+ ( query_taken(Q0, F2), F2 \== F ) -> Q = Q0
    ;   cell_functor(Cell, F), atomic_list_concat([Q0, F], '_', Q)
    ),
    ( query_taken(Q, _) -> true ; assertz(query_taken(Q, F)) ).

:- thread_local query_taken/2.

%   One formula cell: its rule, or a residue block.
cell_rule(Cell, _Options, Items) :-
    Cell = cell(S, R, C), wformula(S, R, C, Text, AST),
    cell_functor(Cell, F),
    (   rowish(Cell) -> Head =.. [F, RV, V], b_setval(xl_row, row(RV, R)) ; Head =.. [F, V], b_setval(xl_row, none) ),
    catch(( phrase(val(AST, ctx(Cell), E), Gs),
            rule_body(V, E, Gs, Body),
            Items = [rule(Head, Body, [comment(Comment)])],
            formula_comment(Cell, Text, Comment),
            ledger_formula(Cell, Text, encoded, "") ),
          residue(Reason),
          ( residue_item(Cell, Text, Reason, Items),
            ledger_formula(Cell, Text, residue, Reason) )).

rule_body(V, E, Gs, Body) :-
    (   var(E), \+ ( member(G, Gs), sub_term(X, G), X == V ), Gs \== []
    ->  E = V, conj(Gs, Body)
    ;   assign(V, E, A), append(Gs, [A], Gs1), conj(Gs1, Body)
    ).

formula_comment(cell(S, R, C), Text, Comment) :-
    a1_text(R, C, A),
    (   wnormalised(S, R, C, From)
    ->  format(string(Comment), "~w!~w: =~w (in the file: =~w)", [S, A, Text, From])
    ;   format(string(Comment), "~w!~w: =~w", [S, A, Text])
    ).

residue_item(Cell, Text, Reason, [residue(Id, [title(Title), locator(Loc), source(excel, Src), note(Reason),
                                               concludes([F])])]) :-
    retract(residue_count(N0)), N is N0 + 1, assertz(residue_count(N)),
    format(atom(Id), 'r~w', [N]),
    cell_functor(Cell, F),
    cell_ref_text(Cell, Loc),
    template_text(Cell, T),
    format(string(Title), "~w", [T]),
    format(string(Src), "=~w", [Text]).

		 /*******************************
		 *            LEDGER            *
		 *******************************/

ledger_formula(Cell, Text, Verdict0, Note0) :-
    cell_ref_text(Cell, Ref),
    Cell = cell(S, R, C),
    (   Verdict0 == encoded, wnormalised(S, R, C, From)
    ->  Verdict = approximated,
        format(string(Note), "the text ~w in the file is read as the number it stands for (Excel reads it so in arithmetic)", [From])
    ;   Verdict0 == encoded, approximation(Text, Note1)
    ->  Verdict = approximated, Note = Note1
    ;   Verdict = Verdict0, Note = Note0
    ),
    template_text(Cell, T),
    format(string(Map), "=~w", [Text]),
    assertz(ledger(entry(Ref, formula, Verdict, Map, T, Note))).

approximation(Text, Note) :-
    (   sub_string(Text, _, _, _, "IFERROR") ; sub_string(Text, _, _, _, "ISERROR") ; sub_string(Text, _, _, _, "ISNA") )
    ->  Note = "an error in Excel is no answer in LE"
    ;   ( sub_string(Text, _, _, _, "=\"") ; sub_string(Text, _, _, _, "<>\"") )
    ->  Note = "text compared as LE compares it: exactly (Excel ignores the case of letters)".

%!  ledger_entries(-Entries) is det.
ledger_entries(Es) :-
    findall(E, ledger(E), Es0),
    findall(entry(Ref, input, encoded, "a cell the user fills in", T, Why),
            ( role(Cell, input), template_text(Cell, T), cell_ref_text(Cell, Ref), input_why(Cell, Why) ), Es1),
    findall(entry(Ref, parameter, encoded, V, Name, ""),
            ( used_constant(Cell), cell_ref_text(Cell, Ref), Cell = cell(S, R, C), wcell(S, R, C, _, V0, _, _, _),
              format(string(V), "~w", [V0]), cell_label_text(Cell, Name) ), Es2),
    findall(entry(Loc, table, Verdict, Map, Name, Note),
            ( table_def(_, Name, Key, P, Rows, Note), table_provenance(Key, [_, at(Loc)]),
              length(Rows, NR), format(string(Map), "~w rows, with ~w match", [NR, P]),
              ( Note == "" -> Verdict = encoded ; Verdict = approximated ) ), Es3),
    append([Es1, Es2, Es3, Es0], Es).

input_why(cell(S, R, C), Why) :-
    (   sheet_info(_, S, _, true), wcell(S, R, C, _, _, false, _, _) -> Why = "unlocked on a protected sheet"
    ;   wvalid(S, R, C, _) -> Why = "has a list of allowed values"
    ;   Why = "empty, and read by a formula"
    ).

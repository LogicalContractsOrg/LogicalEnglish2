/** <module> OIA rule TEXT -> the OIA model (Word documents, .ruletxt, Hub JSON)

    oia_reader.pl reads what Policy Modeling COMPILES (`.xgen`, the deployed
    `rulebase.xml`). This module reads what rule authors WRITE, in the three
    forms it is kept in, into the same neutral model, so oia_ir.pl translates
    either without knowing which it was given:

      - Word rule documents (`Rules/....docx`), through oia_docx.py: the
        paragraphs with Policy Modeling's styles ("OPM - conclusion",
        "OPM - level 1" ... ), and rule tables;
      - `.ruletxt`, the plain-text form of those documents that projects keep
        under version control (the Ministry of Justice's opa_tools writes it:
        `[OPM-level1]<tab>text`, tables as `value | [n] condition`);
      - Intelligent Advisor Hub projects exported as JSON — decision services
        and flows — whose rule documents are `rule-block`s of levelled lines
        and tables, with an input and output contract.

    The project's data model (`projectDataModel.xml`, or a Hub project's
    contracts) gives the entities, relationships, attribute types and public
    names; what it does not list is created as the rules mention it, as
    Policy Modeling does.

    ## How a rule is read

    A conclusion line starts a rule: `<attribute> if` (its conditions follow,
    one level deeper), `<attribute> = <expression>` (a value, unconditional or
    with `if`), or a sentence alone (true). Consecutive conclusions of the
    same value attribute are its alternatives, tried in order, the last
    without conditions its default — one rule, an `otherwise` cascade.

    Conditions are the levels under it. At each level the lines are joined by
    the connectors that end them (`... and`, `... or`) or that stand on lines
    of their own (`and`, `or`); a line `any` / `either` / `all` / `both`
    opens a group of the lines one level deeper; a line with deeper lines
    under it and no connector is an inline conclusion (its own rule), as
    Policy Modeling reads it.

    A line is a comparison (`=`, `<>`, `<`, `>`, `<=`, `>=`, with `+ - * /`
    and the functions of OIA: AddMonths, DayDifference, InstanceCount,
    InstanceSum, Exists, ForAll, Round, Text, Contains, CurrentDate, ...), a
    state of knowledge (`X is known`, `X is unknown`, `X is currently known`,
    `it is certain whether X`, `X = null`), or a boolean attribute — in its
    positive form, or in a negative form ("the system state is not test")
    whose positive form another line or conclusion uses.

    A bracketed tag at the start of a line (`[s 6]`) is a citation, kept.

    The model (oia_reader.pl's), with what text adds:
        attr(Key, Text, Type, Entity, Forms)    Forms may hold public(Name)
        expressions as oia_reader.pl's, plus inst_count(R), inst_sum(R, E),
        inst_min(R, E), inst_max(R, E), inst_count_if(R, C), exists(R, C),
        forall(R, C), via(R, E), concat(A, B), text(E), contains(A, B),
        mod(A, B), pow(A, B), min(A, B), max(A, B), round(A, N), trunc(A, N),
        day_difference(A, B), month_difference(A, B), year_difference(A, B),
        length(E), date_of(Y, M, D), current_datetime
        R is rel(RelationshipId).
*/

:- module(oia_text, [
    oia_read_text_project/3,     % +Spec, +Name, -Model
    oia_text_expr/3              % +Text, +Ctx, -Expr     (tests)
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).
:- use_module(library(process)).
:- use_module(library(json)).
:- use_module(library(sgml)).
:- use_module(library(xpath)).
:- use_module(library(dcg/basics)).
:- use_module(oia_reader, [oia_key/2]).

:- dynamic known_attr/3.        % known_attr(Key, Text, Entity)
:- dynamic dm_attr/5.           % dm_attr(Key, Text, Type, Entity, Public)
:- dynamic dm_entity/4.         % dm_entity(Id, Text, IdKey, ContainmentRel)
:- dynamic dm_rel/7.            % dm_rel(Id, Src, Tgt, Text, Type, RevId, RevText)
:- dynamic seen_attr/3.         % seen_attr(Key, Text, Entity) — met in the rules
:- dynamic attr_type_hint/2.    % attr_type_hint(Key, Type)
:- dynamic inline_rule/1.
:- dynamic dm_output/1.         % dm_output(Key): an output of a decision service's contract

		 /*******************************
		 *          THE PROJECT         *
		 *******************************/

%!  oia_read_text_project(+Spec, +Name, -Model) is det.
%
%   Spec:
%     docx(Dir)      Dir/....docx (Rules/), Dir/projectDataModel.xml
%     ruletxt(Dir)   Dir/*.ruletxt (+ projectDataModel.xml if there)
%     hub(File)      a Hub decision service or flow project (.json)
%     mixed(Dir)     the Word documents and the .ruletxt files of Dir
oia_read_text_project(Spec, Name, oia(Name, Attrs, Rules, Docs)) :-
    reset,
    spec_documents(Spec, DataModelDocs, Documents),
    %  pass 1: what the rules conclude, so a condition can be recognised as
    %  an attribute's negative form
    forall(( member(doc(_, Blocks), Documents), member(B, Blocks),
             conclusion_text(B, T0) ),
           ignore(note_conclusion(T0))),
    findall(Rs, ( member(doc(D, Blocks), Documents), doc_rules(D, Blocks, Rs) ), Rss),
    append(Rss, Rules0),
    findall(R, retract(inline_rule(R)), Inline),
    append(Rules0, Inline, Rules1),
    number_rules(Rules1, Rules),
    model_attrs(Rules, Attrs),
    findall(doc(D, Paras), ( member(doc(D, Blocks), Documents), doc_paras(Blocks, Paras) ), Docs0),
    append(Docs0, DataModelDocs, Docs).

reset :-
    retractall(known_attr(_, _, _)), retractall(dm_attr(_, _, _, _, _)),
    retractall(dm_entity(_, _, _, _)), retractall(dm_rel(_, _, _, _, _, _, _)),
    retractall(seen_attr(_, _, _)), retractall(attr_type_hint(_, _)),
    retractall(inline_rule(_)), retractall(dm_output(_)), nb_setval(oia_text_inline, 0).

%   The documents of a project as doc(Name, Blocks), Blocks the levelled
%   lines and tables of the document:
%     line(Para, Kind, Text)   Kind conclusion | level(N) | alt | comment |
%                              heading | text | ruletype | blank
%     table(Para, Rows)        Rows [[Cell, ...], ...], Cell [line(...), ...]
%     hub_table(Para, Columns, Rows)  a Hub table: columns col(condition|conclusion, Text)
spec_documents(docx(Dir), DMDocs, Docs) :- !,
    data_model(Dir, DMDocs),
    files_with_ext(Dir, '.docx', Files),
    maplist(docx_document, Files, Docs).
spec_documents(ruletxt(Dir), DMDocs, Docs) :- !,
    data_model(Dir, DMDocs),
    files_with_ext(Dir, '.ruletxt', Files),
    maplist(ruletxt_document, Files, Docs).
spec_documents(mixed(Dir), DMDocs, Docs) :- !,
    data_model(Dir, DMDocs),
    files_with_ext(Dir, '.docx', F1), maplist(docx_document, F1, D1),
    files_with_ext(Dir, '.ruletxt', F2), maplist(ruletxt_document, F2, D2),
    append(D1, D2, Docs).
spec_documents(hub(File), DMDocs, Docs) :- !,
    read_file_to_string(File, S, [encoding(utf8)]),
    atom_json_dict(S, J, [value_string_as(string)]),
    hub_data_model(J, DMDocs),
    hub_documents(J, Docs).

files_with_ext(Dir, Ext, Files) :-
    findall(F, ( directory_member(Dir, F, [recursive(true)]),
                 sub_atom(F, _, _, 0, Ext),
                 file_base_name(F, B), \+ sub_atom(B, 0, _, _, '~'),
                 \+ sub_atom(F, _, _, _, '/out/') ), Fs),
    msort(Fs, Files).

		 /*******************************
		 *          WORD (.docx)        *
		 *******************************/

docx_document(File, doc(Name, Blocks)) :-
    file_base_name(File, Name),
    source_file(oia_text:reset, Me), file_directory_name(Me, Here),
    atomic_list_concat([Here, '/oia_docx.py'], Script),
    process_create(path(python3), [Script, File], [stdout(pipe(Out)), stderr(null)]),
    set_stream(Out, encoding(utf8)),
    json_read_dict(Out, D, [value_string_as(string)]),
    close(Out),
    maplist(docx_block, D.blocks, Blocks).

docx_block(B, line(P, Kind, Text)) :-
    B.kind == "p", !,
    P = B.para, style_kind(B.style, Kind), Text = B.text.
docx_block(B, table(P, Rows)) :-
    P = B.para,
    maplist(maplist(docx_cell(P)), B.rows, Rows).

docx_cell(P, Paras, Lines) :-
    maplist(docx_cell_line(P), Paras, Lines).
docx_cell_line(P, Para, line(P, Kind, Para.text)) :- style_kind(Para.style, Kind).

%!  style_kind(+StyleName, -Kind) is det.
%
%   Policy Modeling's paragraph styles, by name ("OPM - level 2") or by id
%   ("OPM-level2", as .ruletxt writes them, with the parentheses opa_tools
%   adds to grouped levels: "OPM-level2(").
style_kind(Style0, Kind) :-
    atom_string(Style0, S0),
    string_lower(S0, S1),
    split_string(S1, "", " ()", [S2]),
    atomic_list_concat(Parts, ' ', S2), atomic_list_concat(Parts, '', S3),   % "opm - level 2" -> "opm-level2"
    atom_string(S3, S),
    (   sub_string(S, 0, _, _, "table-") -> sub_string(S, 6, _, 0, S4) ; S4 = S ),
    (   sub_string(S4, 0, _, _, "comment") -> Kind = comment
    ;   S4 == "opm-conclusion" -> Kind = conclusion
    ;   S4 == "opm-alternativeconclusion" -> Kind = alt
    ;   sub_string(S4, 0, _, _, "opm-level"), sub_string(S4, 9, 1, _, D), number_string(N, D) -> Kind = level(N)
    ;   S4 == "opm-ruletype" -> Kind = ruletype
    ;   S4 == "opm-blankline" -> Kind = blank
    ;   sub_string(S4, 0, _, _, "heading") -> Kind = heading
    ;   sub_string(S4, 0, _, _, "opm-heading") -> Kind = heading
    ;   Kind = text
    ).

		 /*******************************
		 *           .ruletxt           *
		 *******************************/

%   `[Style]<spaces>text`; in a table, `value | [n] condition` and
%   `[table-cell-continued]  | [n] condition` lines.
ruletxt_document(File, doc(Name, Blocks)) :-
    file_base_name(File, Name),
    read_file_to_string(File, S0, [encoding(utf8)]),
    ( sub_string(S0, 0, 1, _, "﻿") -> sub_string(S0, 1, _, 0, S) ; S = S0 ),
    split_string(S, "\n", "\r", Lines0),
    findall(N-L, ( nth1(N, Lines0, L), L \== "" ), NLs),
    ruletxt_blocks(NLs, Blocks).

ruletxt_blocks([], []).
ruletxt_blocks([N-L|T], Blocks) :-
    ruletxt_line(L, Style, Text),
    (   sub_string(Style, 0, _, _, "table-")
    ->  %  a table: this header row, then its rows
        style_kind(Style, HK),
        take_table(T, RowsT, Rest),
        Header = [[line(N, HK, Text)]],
        Blocks = [table(N, [Header|RowsT])|BT],
        ruletxt_blocks(Rest, BT)
    ;   style_kind(Style, Kind),
        Blocks = [line(N, Kind, Text)|BT],
        ruletxt_blocks(T, BT)
    ).

ruletxt_line(L, Style, Text) :-
    (   sub_string(L, 0, 1, _, "["), sub_string(L, B, 1, _, "]")
    ->  B1 is B - 1, sub_string(L, 1, B1, _, Style),
        B2 is B + 1, sub_string(L, B2, _, 0, Text0),
        squash(Text0, Text)
    ;   Style = "Normal", squash(L, Text)
    ).

%   The rows of a table: a `[table-OPM-level1]` or `[table-OPM-Alternative...]`
%   line starts a row (`value | [n] condition`), `[table-cell-continued]`
%   lines continue its condition; anything else ends the table.
take_table([N-L|T], Rows, Rest) :-
    ruletxt_line(L, Style, Text),
    sub_string(Style, 0, _, _, "table-"), Style \== "table-cell-continued",
    \+ sub_string(Style, _, _, _, "conclusion"), !,
    split_bar(Text, N, Value, Cond1),
    take_continued(T, Conds, T1),
    style_kind(Style, VK0),
    (   VK0 == comment                       % a row the author switched off
    ->  Rows = Rows1
    ;   ( VK0 = level(_) -> VK = conclusion ; VK = VK0 ),
        ValueCell = [line(N, VK, Value)],
        Row = [ValueCell, [Cond1|Conds]],
        Rows = [Row|Rows1]
    ),
    take_table(T1, Rows1, Rest).
take_table([N-L|T], [Row|Rows], Rest) :-
    ruletxt_line(L, Style, Text),
    sub_string(Style, _, _, _, "Alternativeconclusion"), !,
    split_bar(Text, N, Value, line(_, _, _)),
    Row = [[line(N, conclusion, Value)], [line(N, alt, "otherwise")]],
    take_table(T, Rows, Rest).
take_table(Rest, [], Rest).

take_continued([N-L|T], [C|Cs], Rest) :-
    ruletxt_line(L, "table-cell-continued", Text), !,
    (   sub_string(Text, 0, _, _, "|") -> sub_string(Text, 1, _, 0, T1) ; T1 = Text ),
    level_cell(N, T1, C),
    take_continued(T, Cs, Rest).
take_continued(Rest, [], Rest).

%   `value | [1] condition`: the value, and the condition with its level.
split_bar(Text, N, Value, Cond) :-
    (   sub_string(Text, B, 1, _, "|"), \+ ( sub_string(Text, B2, 1, _, "|"), B2 > B )
    ->  sub_string(Text, 0, B, _, V0), B1 is B + 1, sub_string(Text, B1, _, 0, C0),
        squash(V0, Value),
        level_cell(N, C0, Cond)
    ;   Value = Text, Cond = line(N, level(1), "")
    ).

level_cell(N, T0, line(N, Kind, Text)) :-
    squash(T0, T1),
    (   sub_string(T1, 0, 1, _, "["), sub_string(T1, B, 1, _, "]"),
        B1 is B - 1, sub_string(T1, 1, B1, _, DS), number_string(D, DS)
    ->  B2 is B + 1, sub_string(T1, B2, _, 0, T2), squash(T2, Text),
        ( string_lower(Text, "otherwise") -> Kind = alt ; D =:= 0 -> Kind = level(1) ; Kind = level(D) )
    ;   Text = T1, Kind = level(1)
    ).

		 /*******************************
		 *        HUB PROJECTS (JSON)   *
		 *******************************/

%   A decision service or flow exported from the Hub: `rules` maps each rule
%   document's name to its content; a `rule-block` holds lines (level 0 a
%   conclusion) and tables.
hub_documents(J, Docs) :-
    (   get_dict(rules, J, R), is_dict(R) -> dict_pairs(R, _, Pairs) ; Pairs = [] ),
    findall(doc(DN, Blocks),
            ( member(K-Content, Pairs), is_list(Content),
              atom_string(K, KS), atom_concat(KS, '', DN),
              hub_blocks(Content, Blocks) ),
            Docs).

hub_blocks(Content, Blocks) :-
    foldl(hub_block, Content, 1-[], _-Rev),
    reverse(Rev, Blocks0), append(Blocks0, Blocks).

hub_block(B, N0-Acc, N-[Bs|Acc]) :-
    (   get_dict(type, B, "rule-block")
    ->  ( get_dict(object, B, Obj) -> true ; Obj = "" ),
        foldl(hub_line(Obj), B.lines, N0-[], N-Rev), reverse(Rev, Bs)
    ;   N is N0 + 1,
        ( get_dict(text, B, T) -> true ; T = "" ),
        ( get_dict(style, B, St), sub_string(St, 0, _, _, "heading") -> K = heading ; K = text ),
        Bs = [line(N0, K, T)]
    ).

hub_line(Obj, L, N0-Acc, N-[Bl|Acc]) :-
    N is N0 + 1,
    (   get_dict(type, L, "table")
    ->  findall(col(Ty, Tx), ( member(C, L.columns), atom_string(Ty, C.type),
                              ( get_dict(text, C, Tx0) -> Tx = Tx0 ; Tx = "" ) ), Cols),
        Bl = hub_table(N0, Obj, Cols, L.rows)
    ;   ( get_dict(type, L, Ty), memberchk(Ty, ["comment", "inactive"]) -> Kind = comment
        ; L.level =:= 0 -> Kind = conclusion
        ; Kind = level(L.level)
        ),
        Bl = line(N0, Kind, L.text)
    ).

%   The contracts: the input and output fields, each with its public name
%   (`name`), its text (`value`) and its type; a field of type `array` is a
%   relationship to an entity whose attributes are its `properties`.
hub_data_model(J, Docs) :-
    findall(F, ( member(C, [inputContract, outputContract]), get_dict(C, J, CD),
                 get_dict(properties, CD, Ps), member(F, Ps) ), Fields),
    forall(member(F, Fields), hub_field(global, F)),
    %  the output contract's fields are the decision service's outcomes
    forall(( get_dict(outputContract, J, OC), get_dict(properties, OC, OPs), member(OF, OPs) ),
           ( ( get_dict(value, OF, OT) -> true ; OT = OF.name ), oia_key(OT, OK), assert_once(dm_output(OK)) )),
    data_model_docs(Docs).

hub_field(Ent, F) :-
    ( get_dict(value, F, Text) -> true ; Text = F.name ),
    atom_string(Ty0, F.type),
    (   Ty0 == array
    ->  atom_string(RelId, F.name),
        singular_entity(Text, EntText),
        atom_concat(e_, RelId, EntId),
        assert_once(dm_entity(EntId, EntText, none, RelId)),
        assert_once(dm_rel(RelId, Ent, EntId, Text, 'OneToMany', none, none)),
        ( get_dict(properties, F, Ps) -> forall(member(P, Ps), hub_field(EntId, P)) ; true )
    ;   hub_type(Ty0, Ty),
        oia_key(Text, K), atom_string(Pub, F.name),
        assert_once(dm_attr(K, Text, Ty, Ent, Pub))
    ).

hub_type(string, text).
hub_type(number, number).
hub_type(boolean, boolean).
hub_type(date, date).
hub_type(object, text).

		 /*******************************
		 *   projectDataModel.xml       *
		 *******************************/

data_model(Dir, Docs) :-
    atomic_list_concat([Dir, '/projectDataModel.xml'], F),
    (   exists_file(F) -> read_data_model(F) ; true ),
    data_model_docs(Docs).

read_data_model(F) :-
    oia_reader_dom(F, DOM),
    forall(xpath(DOM, //entity, E), dm_entity_el(E)),
    forall(xpath(DOM, //relationship, R), dm_rel_el(R)).

dm_entity_el(element(entity, A, C)) :-
    (   memberchk(ref=global, A) -> Ent = global
    ;   memberchk(id=Ent, A) -> true
    ;   memberchk(name=Ent, A)
    ),
    forall(( member(element(attribute, AA, AC), C) ),
           ( memberchk(name=Id, AA),
             ( member(element(text, _, TC), AC), member(element(base, _, [Text]), TC) -> true ; Text = Id ),
             ( memberchk(type=T0, AA) -> downcase_atom(T0, Ty) ; Ty = auto ),
             ( memberchk('public-name'=Pub, AA), Pub \== '' -> true ; Pub = Id ),
             oia_key(Text, K),
             assert_once(dm_attr(K, Text, Ty, Ent, Pub)) )),
    (   Ent \== global
    ->  ( memberchk(name=ET, A) -> true ; ET = Ent ),
        ( memberchk('identifying-attribute-name'=IdA, A),
          member(element(attribute, IA, IC), C), memberchk(name=IdA, IA),
          member(element(text, _, ITC), IC), member(element(base, _, [IT]), ITC)
        -> oia_key(IT, IdKey) ; IdKey = none ),
        ( memberchk('containment-relationship-id'=CR, A) -> true ; CR = none ),
        assert_once(dm_entity(Ent, ET, IdKey, CR))
    ;   true
    ).

dm_rel_el(element(relationship, A, _)) :-
    memberchk('relationship-id'=Id, A), memberchk(source=S, A), memberchk(target=T, A),
    ( memberchk(text=Tx, A) -> true ; memberchk('relationship-text'=Tx, A) -> true ; Tx = Id ),
    ( memberchk(type=Ty, A) -> true ; Ty = 'OneToMany' ),
    ( memberchk('reverse-relationship-id'=RI, A) -> true ; RI = none ),
    ( memberchk('reverse-text'=RT, A), RT \== '' -> true ; RT = none ),
    ( memberchk('public-id'=Pub, A), Pub \== '' -> PId = Pub ; PId = Id ),
    assert_once(dm_rel(PId, S, T, Tx, Ty, RI, RT)).

oia_reader_dom(File, DOM) :-
    read_file_to_string(File, S0, [encoding(utf8)]),
    ( sub_string(S0, 0, 1, _, "﻿") -> sub_string(S0, 1, _, 0, S) ; S = S0 ),
    setup_call_cleanup(open_string(S, In),
                       load_structure(In, DOM, [dialect(xml), space(remove)]),
                       close(In)).

%   The data model as the model's entity(...) and relationship(...) terms
%   (oia_reader.pl's, for the entities oia_ir.pl maps), plus the
%   relationships' kinds.
data_model_docs(Docs) :-
    findall(entity(E, T, IdKey), dm_entity(E, T, IdKey, _), Es),
    findall(relationship(R, S, T, Tx), dm_rel(R, S, T, Tx, _, _, _), Rs),
    findall(relationship_info(R, Ty, RI, RT, Cont),
            ( dm_rel(R, S, T, _, Ty, RI, RT),
              ( dm_entity(T, _, _, R) -> Cont = true ; S == global, Ty == 'OneToMany' -> Cont = true ; Cont = false ) ),
            Is),
    append([Es, Rs, Is], Docs).

singular_entity(Text, EntText) :-
    oia_key(Text, K), atomic_list_concat(Ws, ' ', K), last(Ws, W),
    singular(W, S),
    format(atom(EntText), 'the ~w', [S]).

singular(children, child) :- !.
singular(people, person) :- !.
singular(W, S) :- atom_concat(B, ies, W), !, atom_concat(B, y, S).
singular(W, S) :- atom_concat(B, sses, W), !, atom_concat(B, ss, S).
singular(W, S) :- atom_concat(B, s, W), \+ atom_concat(_, ss, W), !, S = B.
singular(W, W).

assert_once(F) :- ( call(F) -> true ; assertz(F) ).

		 /*******************************
		 *       PARAGRAPHS (sources)   *
		 *******************************/

doc_paras(Blocks, Paras) :-
    findall(para(P, S, T), ( member(B, Blocks), block_para(B, P, S, T) ), Paras0),
    sort(1, @<, Paras0, Paras).

block_para(line(P, K, T), P, S, T) :- T \== "", kind_style(K, S).
block_para(table(P, Rows), P, 'OPM - table', T) :-
    findall(X, ( member(R, Rows), member(C, R), member(line(_, _, X), C), X \== "" ), Xs),
    atomic_list_concat(Xs, ' | ', T).
block_para(hub_table(P, _, Cols, Rows), P, 'OPM - table', T) :-
    findall(X, ( member(col(_, X), Cols) ; member(R, Rows), member(X0, R), cell_string(X0, X) ), Xs),
    atomic_list_concat(Xs, ' | ', T).

kind_style(conclusion, 'OPM - conclusion').
kind_style(level(N), S) :- format(atom(S), 'OPM - level ~w', [N]).
kind_style(alt, 'OPM - Alternative conclusion').
kind_style(comment, 'Comment').
kind_style(heading, 'Heading').
kind_style(text, 'Normal').
kind_style(ruletype, 'OPM - rule type').
kind_style(blank, 'OPM - blank line').

cell_string(X, S) :- ( string(X) -> S = X ; X == null -> S = "" ; is_dict(X) -> S = X.text ; term_string(X, S) ).

		 /*******************************
		 *       PASS 1: CONCLUSIONS    *
		 *******************************/

conclusion_text(line(_, conclusion, T), T).
conclusion_text(table(_, [Header|_]), T) :- member(C, Header), member(line(_, conclusion, T), C).
conclusion_text(hub_table(_, _, Cols, _), T) :- member(col(conclusion, T), Cols).

%   A conclusion's attribute is known: a condition that reads it (or its
%   negative form) is about that attribute.
note_conclusion(T0) :-
    strip_cite(T0, _, T1),
    strip_if(T1, T2, _),
    (   split_assign(T2, L, _) -> Attr = L ; Attr = T2 ),
    clean_phrase(Attr, A), A \== "",
    \+ connective_word(A),
    oia_key(A, K),
    (   \+ dm_attr(K, _, _, _, _), negative_of(A, Pos), oia_key(Pos, PK), dm_attr(PK, _, _, _, _)
    ->  assert_once(known_attr(PK, Pos, any))
    ;   assert_once(known_attr(K, A, any))
    ).

		 /*******************************
		 *       PASS 2: THE RULES      *
		 *******************************/

%   The rules of one document: walk its blocks; a conclusion takes the
%   level lines after it (up to the next conclusion, table or non-rule
%   paragraph), a table is one rule. Consecutive value conclusions of one
%   attribute are merged into one cascade.
doc_rules(Doc, Blocks, Rules) :-
    nb_setval(oia_text_doc, Doc),
    rule_units(Blocks, Units),
    merge_alternatives(Units, Units1),
    findall(R, ( member(U, Units1), unit_rule(Doc, U, R) ), Rules).

rule_units([], []).
rule_units([line(P, conclusion, T)|Bs], [unit(P, T, Conds)|Us]) :- !,
    take_levels(Bs, Conds, Rest),
    rule_units(Rest, Us).
rule_units([table(P, Rows)|Bs], [table_unit(P, Rows)|Us]) :- !,
    rule_units(Bs, Us).
rule_units([hub_table(P, Obj, Cols, Rows)|Bs], [hub_table_unit(P, Obj, Cols, Rows)|Us]) :- !,
    rule_units(Bs, Us).
rule_units([_|Bs], Us) :- rule_units(Bs, Us).

take_levels([line(P, level(N), T)|Bs], [l(N, P, T)|Ls], Rest) :- !, take_levels(Bs, Ls, Rest).
%   Lines the author switched off (Word's Comment styles) and blank lines
%   inside a rule are skipped, when a level line of the rule follows them.
take_levels([line(_, K, _)|Bs], Ls, Rest) :-
    memberchk(K, [comment, blank]), level_after_skipped(Bs), !,
    take_levels(Bs, Ls, Rest).
take_levels(Rest, [], Rest).

level_after_skipped([line(_, level(_), _)|_]) :- !.
level_after_skipped([line(_, K, _)|Bs]) :- memberchk(K, [comment, blank]), level_after_skipped(Bs).

%   `the x = "a" if ...`, `the x = "b" if ...`, `the x = "c"`: one cascade.
merge_alternatives([], []).
merge_alternatives([U1|Us], Out) :-
    U1 = unit(P, T, _),
    value_conclusion_key(T, K),
    take_same(K, Us, Same, Rest), Same \== [], !,
    Out = [cascade(P, K, [U1|Same])|Out1],
    merge_alternatives(Rest, Out1).
merge_alternatives([U|Us], [U|Out]) :- merge_alternatives(Us, Out).

take_same(K, [U|Us], [U|Same], Rest) :-
    U = unit(_, T, _), value_conclusion_key(T, K), !,
    take_same(K, Us, Same, Rest).
take_same(_, Rest, [], Rest).

value_conclusion_key(T0, K) :-
    strip_cite(T0, _, T1), strip_if(T1, T2, _),
    split_assign(T2, L, _), clean_phrase(L, A), oia_key(A, K).

%!  unit_rule(+Doc, +Unit, -Rule) is semidet.
unit_rule(Doc, unit(P, T0, Conds), rule(P, Doc, Name, P, Tree)) :-
    strip_cite(T0, Cite, T1),
    strip_if(T1, T2, _HasIf),
    (   split_assign(T2, L, R)
    ->  attr_ref(L, K, Ent, value),
        Name = K,
        expr_text(R, Ent, V),
        conditions(Conds, Ent, Cond0)
    ;   clean_phrase(T2, A), A \== "",
        boolean_conclusion(A, K, Ent, V),
        Name = K,
        conditions(Conds, Ent, Cond0)
    ),
    wrap_cite(Cite, Cond0, Cond),
    %  a boolean conclusion has Policy Modeling's automatic "otherwise false"
    ( V == true, Cond \== true -> Else = false ; V == false, Cond \== true -> Else = true ; Else = none ),
    Tree = conclude(K, Ent, V, Cond, Else).
unit_rule(Doc, cascade(P, K, Units), rule(P, Doc, K, P, table(Ent, [col(none, Cells)], [concl(K, Vals)]))) :-
    attr_entity(K, Ent),
    findall(Cell-V,
            ( member(unit(_, T0, Conds), Units),
              strip_cite(T0, _, T1), strip_if(T1, T2, _),
              split_assign(T2, _, R), expr_text(R, Ent, V),
              conditions(Conds, Ent, C),
              ( C == true -> Cell = empty ; Cell = cond(C) ) ),
            CVs),
    pairs_keys_values(CVs, Cells, Vals).
unit_rule(Doc, table_unit(P, [Header|Rows]), rule(P, Doc, K, P, table(Ent, [col(none, Cells)], Concls))) :-
    %  Word rule table: the header names the conclusion(s); each row its
    %  value(s), then its condition
    findall(T, ( member(C, Header), member(line(_, _, T0), C), strip_cite(T0, _, T), T \== "" ), HTs),
    HTs = [_|_],
    maplist(header_attr, HTs, Keys, Ents),
    Keys = [K|_], Ents = [Ent|_],
    length(Keys, NK),
    findall(Cell-Vs,
            ( member(Row, Rows), length(Row, NC), NC > NK,
              length(VCells, NK), append(VCells, [CondCell|_], Row),
              maplist(cell_value(Ent), VCells, Vs),
              cell_condition(CondCell, Ent, Cell) ),
            CVs),
    pairs_keys_values(CVs, Cells, VRows),
    findall(concl(Ki, Col), ( nth1(I, Keys, Ki), findall(V, ( member(VR, VRows), nth1(I, VR, V) ), Col) ), Concls).
unit_rule(Doc, hub_table_unit(P, Obj, Cols, Rows), rule(P, Doc, K, P, table(Ent, CondCols, Concls))) :-
    ( Obj \== "" -> object_entity(Obj, Ent) ; Ent = global ),
    findall(I-T, nth1(I, Cols, col(condition, T)), CIs),
    findall(I-T, nth1(I, Cols, col(conclusion, T)), OIs), OIs = [_-T1|_],
    findall(col(H, Cells),
            ( member(I-T, CIs),
              attr_ref(T, HK, Ent, value), H = att(HK),
              findall(Cell, ( member(R, Rows), nth1(I, R, X), cell_string(X, S), hub_cond_cell(S, HK, Ent, Cell) ), Cells) ),
            CondCols),
    findall(concl(OK, Vals),
            ( member(I-T, OIs), header_attr(T, OK, _),
              findall(V, ( member(R, Rows), nth1(I, R, X), cell_string(X, S), hub_value_cell(S, OK, Ent, V) ), Vals) ),
            Concls),
    header_attr(T1, K, _).

header_attr(T0, K, Ent) :-
    clean_phrase(T0, T), attr_ref(T, K, Ent, value).

cell_value(Ent, Lines, V) :-
    findall(T, ( member(line(_, _, T), Lines), T \== "" ), Ts),
    atomic_list_concat(Ts, ' ', T0),
    (   string_lower(T0, "uncertain") -> V = uncertain_value
    ;   expr_text(T0, Ent, V)
    ).

cell_condition(Lines, Ent, Cell) :-
    findall(L, ( member(line(P, Kind, T), Lines), T \== "",
                 ( Kind = level(N) -> true ; Kind == alt -> N = 1 ; N = 1 ),
                 L = l(N, P, T) ), Ls),
    (   ( Ls == [] ; Ls = [l(_, _, O)], string_lower(O, "otherwise") )
    ->  Cell = empty
    ;   conditions(Ls, Ent, C), Cell = cond(C)
    ).

%   A Hub table's condition cell: a value ("Single", 3), a comparison
%   ("> 12950"), a whole condition, or empty.
hub_cond_cell("", _, _, empty) :- !.
hub_cond_cell(S, HK, Ent, Cell) :-
    squash(S, S1),
    (   member(Op-Tag, [">="-'greater-than-equals', "<="-'less-than-equals', "<>"-'not-equals',
                        ">"-'greater-than', "<"-'less-than', "="-equals]),
        sub_string(S1, 0, L, _, Op)
    ->  sub_string(S1, L, _, 0, R), expr_text(R, Ent, E), Cell = op(Tag, [E]), Tag \== none
    ;   catch(expr_text(S1, Ent, E), _, fail), E \= att(_)
    ->  Cell = op(equals, [E])
    ;   condition_text(S1, Ent, C) -> Cell = cond(C)
    ;   Cell = cond(eq(att(HK), str(S1)))
    ).

hub_value_cell("", _, _, uncertain_value) :- !.
hub_value_cell(S, OK, Ent, V) :-
    (   boolean_literal(S, V) -> assert_once(attr_type_hint(OK, boolean))
    ;   ( attr_known_type(OK, boolean) ; has_comparison(S) )
    ->  %  a boolean conclusion whose value is a condition: "the person's
        %  gross income > $12,950" (the row concludes whether it holds)
        assert_once(attr_type_hint(OK, boolean)),
        condition_text(S, Ent, V0), V = cond(V0)
    ;   expr_text(S, Ent, V)
    ).

has_comparison(S) :-
    catch(tokens(S, Toks), _, fail), member(op(O), Toks), cmp_op(O, _), !.

boolean_literal(S, V) :- string_lower(S, L), ( L == "true" -> V = true ; L == "false" -> V = false ).

		 /*******************************
		 *         CONDITIONS           *
		 *******************************/

%!  conditions(+Lines, +Entity, -Expr) is det.
%
%   The levelled lines under a conclusion as one condition.
conditions(Lines, Ent, E) :- conditions(Lines, Ent, and, E).

%   Def is the connective of lines that end with none: `and` under a
%   conclusion, the group's under `any` / `either` / `all` / `both` — as
%   Policy Modeling compiles them.
conditions([], _, _, true) :- !.
conditions(Lines, Ent, Def, E) :-
    Lines = [l(L0, _, _)|_],
    min_level(Lines, L0, L),
    level_items(Lines, L, Ent, Items),
    combine(Items, Def, E).

min_level([], L, L).
min_level([l(N, _, _)|T], L0, L) :- L1 is min(N, L0), min_level(T, L1, L).

%   Items at level L: each a line at L with the deeper lines under it.
%   Result: a list of item(Expr, Connector) and conn(C) entries.
level_items([], _, _, []).
level_items([l(N, P, T)|Rest], L, Ent, Items) :-
    N =< L, !,
    split_children(Rest, L, Kids, After),
    item(T, P, Kids, After, Ent, L, Items0, After1),
    level_items(After1, L, Ent, Items1),
    append(Items0, Items1, Items).
level_items([_|Rest], L, Ent, Items) :-          % a stray deeper line
    level_items(Rest, L, Ent, Items).

split_children([l(N, P, T)|Rest], L, [l(N, P, T)|Kids], After) :- N > L, !,
    split_children(Rest, L, Kids, After).
split_children(After, _, [], After).

item(T0, P, Kids, After, Ent, _L, Items, After1) :-
    strip_cite(T0, Cite, T1),
    trailing_connector(T1, T2, Conn),
    string_lower(T2, Low),
    (   memberchk(Low, ["and", "or"])                 % a connector line
    ->  Items = [conn(Low)], After1 = After
    ;   group_word(Low, G)                            % any / all / either / both
    ->  conditions(Kids, Ent, G, GE),
        wrap_cite(Cite, GE, E), Items = [item(E, Conn)], After1 = After
    ;   Kids \== []                                   % a line with deeper lines: inline conclusion
    ->  conditions(Kids, Ent, KE),
        inline_conclusion(T2, P, Ent, KE, E0), wrap_cite(Cite, E0, E),
        Items = [item(E, Conn)], After1 = After
    ;   condition_text(T2, Ent, E0), wrap_cite(Cite, E0, E),
        Items = [item(E, Conn)], After1 = After
    ).

group_word(W, G) :-
    memberchk(W-G, ["any"-or, "either"-or, "one or more of the following"-or, "any of the following"-or,
                    "all"-and, "both"-and, "all of the following"-and]).

%   Combine items with their connectors: `and` binds tighter than `or`.
combine(Items, Def, E) :-
    items_terms(Items, Def, Terms),
    (   Terms = [x(E1)] -> E = E1
    ;   split_or(Terms, Groups),
        maplist(and_group, Groups, Ands),
        ( Ands = [A] -> E = A ; E = or(Ands) )
    ).

%   x(E) and c(and|or) in sequence: a connector between two items comes from
%   the first one's trailing word, or a connector line between them.
items_terms([], _, []).
items_terms([item(E, C)|T], Def, [x(E)|Out]) :- !,
    (   T = [conn(C2)|T2] -> Out = [c(C2)|Out1], items_terms(T2, Def, Out1)
    ;   T == [] -> Out = []
    ;   C == none -> Out = [c(Def)|Out1], items_terms(T, Def, Out1)
    ;   Out = [c(C)|Out1], items_terms(T, Def, Out1)
    ).
items_terms([conn(_)|T], Def, Out) :- items_terms(T, Def, Out).

split_or(Terms, Groups) :-
    foldl(or_step, Terms, [[]], Gs0),
    reverse(Gs0, Gs1), maplist(reverse, Gs1, Groups0),
    exclude(==([]), Groups0, Groups).
or_step(c("or"), Gs, [[]|Gs]) :- !.
or_step(c(or), Gs, [[]|Gs]) :- !.
or_step(c(_), Gs, Gs) :- !.
or_step(x(E), [G|Gs], [[E|G]|Gs]).

and_group([E], E) :- !.
and_group(Es, and(Es)).

trailing_connector(T0, T, Conn) :-
    squash(T0, T1),
    (   T1 \== "", strip_trailing_punct(T1, T2),
        member(Suf-C, [" and"-"and", " or"-"or", ";and"-"and", "; and"-"and", "; or"-"or"]),
        string_lower(T2, L), sub_string(L, B, _, 0, Suf), B > 0
    ->  sub_string(T2, 0, B, _, T3), squash(T3, T), Conn = C
    ;   strip_trailing_punct(T1, T), Conn = none
    ).

strip_trailing_punct(T0, T) :-
    (   sub_string(T0, B, 1, 0, C), memberchk(C, [".", ";", ","]), B > 0
    ->  sub_string(T0, 0, B, _, T1), squash(T1, T)
    ;   T = T0
    ).

%   An inline conclusion: its own rule, and its attribute as the condition.
inline_conclusion(T, P, Ent, Cond, att(K)) :-
    clean_phrase(T, A),
    boolean_conclusion(A, K, Ent, V),
    nb_getval(oia_text_inline, I0), I is I0 + 1, nb_setval(oia_text_inline, I),
    nb_getval(oia_text_doc, Doc),
    assertz(inline_rule(inl(I, Doc, P, conclude(K, Ent, V, Cond, false)))).

number_rules(Rules0, Rules) :-
    foldl(number_rule, Rules0, 0-[], _-Rev), reverse(Rev, Rules).
number_rule(rule(_, D, N, P, T), I0-Acc, I-[rule(I, D, N, P, T)|Acc]) :- !, I is I0 + 1.
number_rule(inl(_, Doc, P, T), I0-Acc, I-[rule(I, Doc, Name, P, T)|Acc]) :-
    I is I0 + 1, T = conclude(Name, _, _, _, _).

%   Spaces collapsed and trimmed, except inside quoted text: a string
%   literal keeps its spaces, as Policy Modeling keeps them ("  <div>    ").
squash(T0, T) :-
    format(string(S0), "~w", [T0]),
    string_codes(S0, Cs0),
    squash_codes(Cs0, out, Cs1),
    string_codes(S1, Cs1),
    split_string(S1, "", " \t\n\r", [T]).

squash_codes([], _, []).
squash_codes([C|Cs], out, Out) :-
    code_type(C, space), !,
    skip_spaces(Cs, Rest),
    ( Rest == [] -> Out = [] ; Out = [0' |Out1], squash_codes(Rest, out, Out1) ).
squash_codes([C|Cs], out, [C|Out]) :- quote_mark(C), !, squash_codes(Cs, in, Out).
squash_codes([C|Cs], in, [C|Out]) :- quote_mark(C), !, squash_codes(Cs, out, Out).
squash_codes([C|Cs], St, [C|Out]) :- squash_codes(Cs, St, Out).

skip_spaces([C|Cs], R) :- code_type(C, space), !, skip_spaces(Cs, R).
skip_spaces(R, R).

quote_mark(C) :- memberchk(C, `"“”`).

wrap_cite(none, E, E) :- !.
wrap_cite(C, E, cite(C, E)).

		 /*******************************
		 *        ONE CONDITION         *
		 *******************************/

%!  condition_text(+Text, +Entity, -Expr) is det.
condition_text(T0, Ent, E) :-
    squash(T0, T1),
    strip_trailing_punct(T1, T),
    string_lower(T, L),
    (   knowledge_condition(T, L, Ent, E) -> true
    ;   catch(tokens(T, Toks), _, fail),
        comparison_tokens(Toks, Ent, E) -> true
    ;   catch(tokens(T, Toks), _, fail),
        Toks = [fn(F), lp|_], boolean_function(F),
        phrase(expr(Ent, E), Toks) -> true
    ;   clean_phrase(T, A),
        boolean_reference(A, Ent, E)
    ).

knowledge_condition(T, L, Ent, E) :-
    member(Pre-Op, ["it is currently known whether or not "-known, "it is known whether or not "-known,
                    "it is currently known whether "-known, "it is known whether "-known,
                    "it is currently unknown whether or not "-unknown, "it is unknown whether or not "-unknown,
                    "it is unknown whether "-unknown,
                    "it is certain whether or not "-known, "it is certain whether "-known,
                    "it is uncertain whether or not "-uncertain, "it is uncertain whether "-uncertain]),
    sub_string(L, 0, N, _, Pre), !,
    sub_string(T, N, _, 0, Rest), clean_phrase(Rest, A),
    boolean_reference(A, Ent, R0), strip_not(R0, R),
    E =.. [Op, R].
knowledge_condition(T, L, Ent, E) :-
    member(Suf-Op, [" is currently known"-known, " is currently unknown"-unknown,
                    " is known"-known, " is unknown"-unknown,
                    " is certain"-known, " is uncertain"-uncertain]),
    sub_string(L, B, _, 0, Suf), B > 0, !,
    sub_string(T, 0, B, _, Rest), clean_phrase(Rest, A),
    any_reference(A, Ent, R),
    E =.. [Op, R].
knowledge_condition(T, _, Ent, E) :-
    catch(tokens(T, Toks), _, fail),
    append(LT, [op(Op), word(N)], Toks), string_lower(N, "null"),
    memberchk(Op-Kn, ["="-unknown, "<>"-known, "!="-known]), !,
    phrase(expr(Ent, A), LT),
    E =.. [Kn, A].

strip_not(not(E), E) :- !.
strip_not(E, E).

%   "X is known": X may be a value or a boolean — the test says nothing of
%   its type, which other rules decide.
any_reference(A, Ent, R) :-
    (   catch(tokens(A, Toks), _, fail), Toks = [fn(_), lp|_], phrase(expr(Ent, R), Toks) -> true
    ;   oia_key(A, K), ( known_value_attr(K) ; known_attr(K, _, _) ; dm_attr(K, _, _, _, _) )
    ->  R = att(K), note_attr(K, A, Ent)
    ;   negative_of(A, Pos), oia_key(Pos, PK), ( known_attr(PK, _, _) ; dm_attr(PK, _, boolean, _, _) )
    ->  note_attr(PK, Pos, Ent), R = not(att(PK))
    ;   oia_key(A, K), note_attr(K, A, Ent), R = att(K)
    ).

known_value_attr(K) :- dm_attr(K, _, Ty, _, _), Ty \== boolean.

comparison_tokens(Toks, Ent, E) :-
    append(LT, [op(Op)|RT], Toks), cmp_op(Op, F), LT \== [], RT \== [], !,
    phrase(expr(Ent, A0), LT),
    rhs_expr(RT, A0, Ent, B),
    hint_from(A0, B),
    E =.. [F, A0, B].

%   The right side of `=`: an expression; or, when it is a bare phrase that
%   is no attribute ("= Refugee", "= citizen"), the text constant it spells.
rhs_expr(RT, _, Ent, B) :-
    (   RT = [word(_)|_], \+ ( member(X, RT), X \= word(_) ),
        words_text(RT, W), oia_key(W, K), \+ known_attr(K, _, _), \+ dm_attr(K, _, _, _, _)
    ->  B = str(W)
    ;   RT = [word(_)|_], memberchk(comma, RT), \+ ( member(X, RT), X \= word(_), X \= comma )
    ->  %  a listed value with commas in it ("Victim of human trafficking, T-visa")
        findall(P, ( member(X, RT), ( X = word(P) ; X == comma, P = "," ) ), Ps),
        atomic_list_concat(Ps, ' ', B0), atomic_list_concat(Parts, ' ,', B0),
        atomic_list_concat(Parts, ',', B1), atom_string(B1, BS), B = str(BS)
    ;   phrase(expr(Ent, B), RT)
    ).

cmp_op("=", eq). cmp_op("==", eq). cmp_op("<>", ne). cmp_op("!=", ne).
cmp_op(">", gt). cmp_op(">=", ge). cmp_op("<", lt). cmp_op("<=", le).

%   The type an attribute is compared with tells its type.
hint_from(att(K), B) :- const_type(B, T), !, assert_once(attr_type_hint(K, T)).
hint_from(A, att(K)) :- const_type(A, T), !, assert_once(attr_type_hint(K, T)).
hint_from(_, _).

const_type(str(_), text).
const_type(num(_), number).
const_type(date(_, _, _), date).

%   A boolean attribute, in its positive form or in a negative one whose
%   positive form is known.
boolean_reference(A, Ent, E) :-
    oia_key(A, K),
    (   known_attr(K, _, _) -> note_attr(K, A, Ent), E = att(K)
    ;   negative_of(A, Pos), oia_key(Pos, PK), ( known_attr(PK, _, _) ; dm_attr(PK, _, boolean, _, _) )
    ->  note_attr(PK, Pos, Ent), E = not(att(PK))
    ;   dm_attr(K, _, _, _, _) -> note_attr(K, A, Ent), E = att(K)
    ;   note_attr(K, A, Ent), assert_once(attr_type_hint(K, boolean)), E = att(K)
    ).

%   "the system state is not test" -> "the system state is test";
%   "X does not Y" -> "X Ys" is not attempted (Policy Modeling's own parse
%   would be needed); "is not", "are not", "has not", "was not", ... are.
negative_of(A, Pos) :-
    atomic_list_concat(Ws, ' ', A),
    append(Pre, [Aux, Not|Post], Ws),
    downcase_atom(Not, not),
    downcase_atom(Aux, AuxL),
    memberchk(AuxL, [is, are, was, were, has, have, had, can, could, will, would, must, should, may, does, do]),
    (   AuxL == does, Post = [V|Rest] -> third_person(V, V3), PWs0 = [V3|Rest], append(Pre, PWs0, PWs)
    ;   AuxL == do, Post = [_|_] -> append(Pre, Post, PWs)
    ;   append(Pre, [Aux|Post], PWs)
    ),
    atomic_list_concat(PWs, ' ', Pos).

%   "contain" -> "contains", "carry" -> "carries", "have" -> "has".
third_person(have, has) :- !.
third_person(be, is) :- !.
third_person(V, V3) :- atom_concat(B, y, V), atom_length(B, L), L > 0, sub_atom(B, _, 1, 0, C), \+ memberchk(C, [a, e, i, o, u]), !, atom_concat(B, ies, V3).
third_person(V, V3) :- ( atom_concat(_, s, V) ; atom_concat(_, sh, V) ; atom_concat(_, ch, V) ; atom_concat(_, x, V) ; atom_concat(_, z, V) ; atom_concat(_, o, V) ), !, atom_concat(V, es, V3).
third_person(V, V3) :- atom_concat(V, s, V3).

boolean_conclusion(A, K, Ent, V) :-
    oia_key(A, K0),
    (   \+ dm_attr(K0, _, _, _, _), negative_of(A, Pos), oia_key(Pos, PK),
        ( known_attr(PK, _, _), PK \== K0 ; dm_attr(PK, _, _, _, _) )
    ->  K = PK, V = false, note_attr(PK, Pos, Ent0)
    ;   K = K0, V = true, note_attr(K, A, Ent0)
    ),
    attr_entity(K, Ent), ( var(Ent0) -> Ent0 = Ent ; true ),
    assert_once(attr_type_hint(K, boolean)).

%   An attribute named on the left of `=`, or as a table's header.
attr_ref(T0, K, Ent, _Kind) :-
    clean_phrase(T0, A),
    oia_key(A, K),
    note_attr(K, A, _),
    attr_entity(K, Ent).

attr_entity(K, Ent) :-
    (   dm_attr(K, _, _, E, _) -> Ent = E
    ;   Ent = global
    ).

attr_known_type(K, T) :-
    (   dm_attr(K, _, T0, _, _), T0 \== auto -> T = T0
    ;   attr_type_hint(K, T)
    ).

note_attr(K, A, Ent) :-
    (   seen_attr(K, _, _) -> true
    ;   ( var(Ent) -> attr_entity(K, E) ; E = Ent ),
        assertz(seen_attr(K, A, E))
    ).

object_entity(Obj, Ent) :-
    oia_key(Obj, K),
    (   dm_entity(Ent, T, _, _), oia_key(T, K) -> true
    ;   dm_rel(R, _, Ent, T, _, _, _), ( oia_key(T, K) ; atom_string(R, Obj) ) -> true
    ;   Ent = global
    ).

		 /*******************************
		 *   CLEANING A PHRASE          *
		 *******************************/

%   A bracketed tag at the start: "[s 6] The margin scheme applies".
strip_cite(T0, Cite, T) :-
    squash(T0, T1),
    (   sub_string(T1, 0, 1, _, "["), sub_string(T1, B, 1, _, "]"), B > 1
    ->  B1 is B - 1, sub_string(T1, 1, B1, _, C), atom_string(Cite, C),
        B2 is B + 1, sub_string(T1, B2, _, 0, T3), squash(T3, T)
    ;   Cite = none, T = T1
    ).

%   "<conclusion> if" -> the conclusion.
strip_if(T0, T, HasIf) :-
    squash(T0, T1),
    strip_trailing_punct(T1, T2),
    string_lower(T2, L),
    (   sub_string(L, B, _, 0, " if"), B > 0
    ->  sub_string(T2, 0, B, _, T3), squash(T3, T), HasIf = true
    ;   T = T2, HasIf = false
    ).

%   "the x = expr": split at the first `=` outside quotes and brackets that
%   is not part of `<=`, `>=`, `==`.
split_assign(T, L, R) :-
    catch(tokens(T, Toks), _, fail),
    append(LT, [op("=")|RT], Toks), LT \== [], RT \== [],
    \+ ( member(op(O), LT), cmp_op(O, _) ),
    LT = [word(_)|_], \+ ( member(X, LT), X \= word(_) ), !,
    words_text(LT, L),
    tokens_text(T, RT, R).

%   The text of the right side, as written (the expression is re-read).
tokens_text(T, RT, R) :-
    (   sub_string(T, B, 1, _, "="), \+ ( sub_string(T, B0, 1, _, "="), B0 < B )
    ->  B1 is B + 1, sub_string(T, B1, _, 0, R0), squash(R0, R)
    ;   words_text(RT, R)
    ).

clean_phrase(T0, A) :-
    squash(T0, T1),
    strip_trailing_punct(T1, T2),
    split_string(T2, "", " “”\"", [A0]),
    squash(A0, A).

connective_word(A) :- string_lower(A, L), memberchk(L, ["and", "or", "any", "all", "either", "both", "otherwise"]).

		 /*******************************
		 *         EXPRESSIONS          *
		 *******************************/

%!  oia_text_expr(+Text, +Ctx, -Expr) is semidet.
oia_text_expr(T, Ent, E) :- expr_text(T, Ent, E).

expr_text(T0, Ent, E) :-
    squash(T0, T),
    (   T == "" -> E = str("")
    ;   tokens(T, Toks), phrase(expr(Ent, E), Toks)
    ).

%   Tokens: str(S), num(N), date(Y,M,D), op(O), lp, rp, comma, fn(Name)
%   (a function name followed by its bracket), word(W).
tokens(T, Toks) :-
    string_codes(T, Cs),
    phrase(toks(Toks0), Cs),
    merge_paren_words(Toks0, Toks).

toks([]) --> blanks_to_end, !.
toks([T|Ts]) --> blanks, tok(T), !, toks(Ts).

blanks_to_end --> blanks, eos.

tok(str(S)) --> open_quote(Q), string_without_close(Q, Cs), close_quote(Q), !, { string_codes(S, Cs) }.
tok(date(Y, M, D)) --> digits4(Y), "-", digits2(M), "-", digits2(D), !.
tok(date(Y, M, D)) --> digits2(A), "/", digits2(B), "/", digits4(Y), !,
    { ( B > 12 -> M = A, D = B ; D = A, M = B ) }.
tok(num(N)) --> "$", !, number_codes_c(Cs), { number_codes_clean(Cs, N) }.
tok(num(N)) --> number_codes_c(Cs), \+ word_char_ahead, !, { number_codes_clean(Cs, N) }.
tok(op(O)) --> op_codes(O), !.
tok(lp) --> "(", !.
tok(rp) --> ")", !.
tok(comma) --> ",", !.
tok(fn(F)) --> word_codes(Cs), { Cs \== [] }, peek("("), { atom_codes(A, Cs), downcase_atom(A, F), function_name(F) }, !.
tok(word(W)) --> word_codes(Cs), { Cs \== [], string_codes(W, Cs) }.

open_quote(0'") --> "\"".
open_quote(0'") --> "“".
open_quote(0'") --> "”".
close_quote(_) --> "\"".
close_quote(_) --> "”".
close_quote(_) --> "“".
string_without_close(_, []) --> peek_any_close, !.
string_without_close(Q, [C|Cs]) --> [C], string_without_close(Q, Cs).
peek_any_close, [C] --> [C], { memberchk(C, `"“”`) }.

peek(S), S --> S.
word_char_ahead, [C] --> [C], { code_type(C, alpha) }.

digits4(N) --> digit(A), digit(B), digit(C), digit(D), { number_codes(N, [A, B, C, D]) }.
digits2(N) --> digit(A), digit(B), { number_codes(N, [A, B]) }.

number_codes_c([C|Cs]) --> digit(C), num_rest(Cs).
number_codes_c([0'0, 0'., C|Cs]) --> ".", digit(C), num_rest(Cs).
num_rest([C|Cs]) --> digit(C), !, num_rest(Cs).
num_rest(Cs) --> ",", digit(A), digit(B), digit(C), \+ digit(_), !, { Cs = [A, B, C|Cs1] }, num_rest(Cs1).
num_rest([0'., C|Cs]) --> ".", digit(C), !, num_rest(Cs).
num_rest([]) --> [].

number_codes_clean(Cs, N) :- number_codes(N, Cs).

op_codes("<>") --> "<>".
op_codes("<=") --> "<=".
op_codes(">=") --> ">=".
op_codes("!=") --> "!=".
op_codes("==") --> "==".
op_codes("=") --> "=".
op_codes("<") --> "<".
op_codes(">") --> ">".
op_codes("+") --> "+".
op_codes("*") --> "*".
op_codes("/") --> "/", \+ peek_alpha.
op_codes("-") --> "-", peek_space_or_digit.

peek_alpha, [C] --> [C], { code_type(C, alpha) }.
peek_space_or_digit, [C] --> [C], { ( code_type(C, space) ; code_type(C, digit) ; C == 0'( ) }.

%   A word: letters, digits and the characters attribute texts use inside
%   words (apostrophes, hyphens and slashes between letters, %, &, _, .).
word_codes([C|Cs]) --> [C], { word_start(C) }, word_rest(Cs).
word_rest([C|Cs]) --> [C], { word_char(C) }, !, word_rest(Cs).
word_rest([0'-|Cs]) --> "-", peek_alnum, !, word_rest(Cs).
word_rest([0'/|Cs]) --> "/", peek_alpha, !, word_rest(Cs).
word_rest([0'.|Cs]) --> ".", peek_alnum, !, word_rest(Cs).
word_rest([]) --> [].
peek_alnum, [C] --> [C], { code_type(C, alnum) }.

word_start(C) :- code_type(C, alnum) ; memberchk(C, `'’‘_%&#?:;[]`).
word_char(C) :- code_type(C, alnum) ; memberchk(C, `'’‘_%&#?:`).

%   Brackets that belong to an attribute's text: "the loan to value ratio
%   (LVR)", "the Child's estimated delivery date (EDD)" — words only inside,
%   right after a word, not a function's.
merge_paren_words([], []).
merge_paren_words([word(A), lp|T], Out) :-
    append(Inner, [rp|Rest], T), Inner = [_|_],
    forall(member(X, Inner), X = word(_)), !,
    words_text(Inner, IT),
    format(string(W), "~w (~w)", [A, IT]),
    merge_paren_words([word(W)|Rest], Out).
merge_paren_words([X|T], [X|Out]) :- merge_paren_words(T, Out).

words_text(Toks, T) :-
    findall(W, member(word(W), Toks), Ws),
    atomic_list_concat(Ws, ' ', T0), atom_string(T0, T).

function_name(F) :- function_arity(F, _, _).

%   OIA's functions (case-insensitive), with the model's functor.
function_arity(addmonths, 2, add_months).
function_arity(adddays, 2, add_days).
function_arity(addyears, 2, add_years).
function_arity(addweeks, 2, add_weeks).
function_arity(daydifference, 2, day_difference).
function_arity(monthdifference, 2, month_difference).
function_arity(yeardifference, 2, year_difference).
function_arity(weekdifference, 2, week_difference).
function_arity(currentdate, 0, current_date).
function_arity(currentdatetime, 0, current_datetime).
function_arity(round, 2, round).
function_arity(trunc, 2, trunc).
function_arity(roundup, 2, ceiling).
function_arity(rounddown, 2, floor).
function_arity(maximum, 2, max).
function_arity(minimum, 2, min).
function_arity(max, 2, max).
function_arity(min, 2, min).
function_arity(abs, 1, abs).
function_arity(text, 1, text).
function_arity(number, 1, number).
function_arity(length, 1, length).
function_arity(contains, 2, contains).
function_arity(startswith, 2, starts_with).
function_arity(endswith, 2, ends_with).
function_arity(concatenate, 2, concat).
function_arity(instancecount, 1, inst_count).
function_arity(instancesum, 2, inst_sum).
function_arity(instanceminimum, 2, inst_min).
function_arity(instancemaximum, 2, inst_max).
function_arity(instancecountif, 2, inst_count_if).
function_arity(exists, 2, exists).
function_arity(forall, 2, forall).
function_arity(for, 2, via).
function_arity(date, 3, date_of).
function_arity(yearssince, 1, years_since).
function_arity(if, 3, if).
function_arity(temporalyearssince, 2, temporal('temporal-years-since')).
function_arity(temporalyearssince, 1, temporal('temporal-years-since')).
function_arity(temporalbefore, 1, temporal('temporal-before')).
function_arity(temporalafter, 1, temporal('temporal-after')).
function_arity(temporalonorafter, 1, temporal('temporal-on-or-after')).
function_arity(temporalonorbefore, 1, temporal('temporal-on-or-before')).

boolean_function(F) :- memberchk(F, [contains, startswith, endswith, exists, forall, temporalbefore, temporalafter,
                                     temporalonorafter, temporalonorbefore]).

%   expr: additive, multiplicative, unary, primary.
expr(Ent, E) --> term(Ent, T), expr_rest(Ent, T, E).
expr_rest(Ent, Acc, E) --> [op("+")], !, term(Ent, T), { plus(Acc, T, A1) }, expr_rest(Ent, A1, E).
expr_rest(Ent, Acc, E) --> [op("-")], !, term(Ent, T), expr_rest(Ent, sub(Acc, T), E).
expr_rest(_, E, E) --> [].

%   `+` joins texts when either side is one (OIA overloads it).
plus(A, B, concat(A, B)) :- ( textual(A) ; textual(B) ), !,
    forall(( member(X, [A, B]), X = att(K), \+ attr_known_type(K, _) ), assert_once(attr_type_hint(K, text))).
plus(A, B, add(A, B)).

textual(str(_)).
textual(concat(_, _)).
textual(text(_)).
textual(att(K)) :- attr_known_type(K, text).

term(Ent, E) --> factor(Ent, F), term_rest(Ent, F, E).
term_rest(Ent, Acc, E) --> [op("*")], !, factor(Ent, F), term_rest(Ent, mul(Acc, F), E).
term_rest(Ent, Acc, E) --> [op("/")], !, factor(Ent, F), term_rest(Ent, div(Acc, F), E).
term_rest(_, E, E) --> [].

factor(Ent, neg(E)) --> [op("-")], !, factor(Ent, E).
factor(Ent, E) --> [lp], !, expr(Ent, E), [rp].
factor(_, str(S)) --> [str(S)], !.
factor(_, num(N)) --> [num(N)], !.
factor(_, date(Y, M, D)) --> [date(Y, M, D)], !.
factor(Ent, E) --> [fn(F), lp], !, args(Ent, F, Args), [rp], { fn_expr(F, Args, E) }.
factor(Ent, E) --> words(Ws), { Ws \== [], phrase_value(Ws, Ent, E) }.

words([W|Ws]) --> [word(W)], !, words(Ws).
words([]) --> [].

args(_, F, []) --> { function_arity(F, 0, _) }, !.
args(Ent, F, Args) --> { scoped_function(F) }, !, rel_arg(Ent, R, Tgt), arg_rest(Tgt, Rest), { Args = [R|Rest] }.
args(Ent, _, [A|As]) --> expr(Ent, A), args_rest(Ent, As).
args_rest(Ent, [A|As]) --> [comma], !, expr(Ent, A), args_rest(Ent, As).
args_rest(_, []) --> [].
arg_rest(Tgt, [A]) --> [comma], !, arg_condition(Tgt, A).
arg_rest(_, []) --> [].

%   The second argument of ForAll/Exists/InstanceCountIf/InstanceSum: read
%   in the scope of the related entity, as the remaining tokens' text.
arg_condition(Tgt, E, Toks, Rest) :-
    upto_close(Toks, 0, Inner, Rest),
    toks_condition(Inner, Tgt, E).

%   The tokens up to the bracket that closes the function's (not consumed).
upto_close([rp|T], 0, [], [rp|T]) :- !.
upto_close([X|T], D, [X|In], Rest) :-
    ( X == lp -> D1 is D + 1 ; X == rp -> D1 is D - 1 ; X = fn(_) -> D1 = D ; D1 = D ),
    upto_close(T, D1, In, Rest).

toks_condition(Toks, Ent, E) :-
    (   comparison_tokens(Toks, Ent, E) -> true
    ;   phrase(expr(Ent, E0), Toks), E0 = att(K), attr_known_type(K, boolean) -> E = E0
    ;   phrase(expr(Ent, E), Toks)
    ).

scoped_function(F) :- memberchk(F, [instancecount, instancesum, instanceminimum, instancemaximum,
                                    instancecountif, exists, forall, for]).

rel_arg(_, rel(R), Tgt) --> words(Ws), { Ws \== [], atomic_list_concat(Ws, ' ', T), relationship_named(T, R, Tgt) }.

relationship_named(T, R, Tgt) :-
    oia_key(T, K),
    (   dm_rel(R, _, Tgt, RT, _, _, _), oia_key(RT, K) -> true
    ;   dm_rel(R0, _, Tgt0, _, _, RI, RT), RT \== none, oia_key(RT, K)
    ->  ( RI \== none -> R = RI ; R = R0 ), dm_rel(R0, Tgt, Tgt0, _, _, _, _)   % the reverse
    ;   dm_rel(R, _, Tgt, _, _, _, _), atom_string(R, T) -> true
    ;   dm_entity(Tgt, ET, _, R), oia_key(ET, EK), atomic_list_concat(Ws, ' ', K), last(Ws, Last),
        singular(Last, S), atomic_list_concat(EWs, ' ', EK), last(EWs, S)
    ).

fn_expr(F, Args, E) :-
    length(Args, NA),
    function_arity(F, N, Functor),
    (   NA =:= N -> true
    ;   memberchk(F, [round, trunc, roundup, rounddown]), NA =:= 1
    ), !,
    (   Functor = temporal(T) -> E = temporal(T, Args)
    ;   Functor == current_date -> E = current_date
    ;   Functor == current_datetime -> E = current_datetime
    ;   memberchk(F, [round, trunc, roundup, rounddown]), Args = [A] -> E =.. [Functor, A, num(0)]
    ;   E =.. [Functor|Args]
    ).

%   A phrase: true/false/uncertain, an attribute, or (in a value) text.
phrase_value(Ws, Ent, E) :-
    atomic_list_concat(Ws, ' ', T0), atom_string(T0, T),
    string_lower(T, L),
    (   L == "true" -> E = true
    ;   L == "false" -> E = false
    ;   L == "uncertain" -> E = uncertain_value
    ;   memberchk(L, ["currentdate", "the current date", "current date", "today"]) -> E = current_date
    ;   oia_key(T, K),
        note_attr(K, T, Ent),
        E = att(K)
    ).

		 /*******************************
		 *         THE ATTRIBUTES       *
		 *******************************/

%   Every attribute the rules read or conclude, with its type: the data
%   model's, else what the rules do with it (oia_ir.pl infers the rest).
model_attrs(Rules, Attrs) :-
    findall(K, ( member(rule(_, _, _, _, T), Rules), sub_term(att(K), T) ), K1),
    findall(K, ( member(rule(_, _, _, _, T), Rules), ( T = conclude(K, _, _, _, _) ; T = table(_, _, Cs), member(concl(K, _), Cs) ) ), K2),
    findall(K, dm_attr(K, _, _, _, _), K3),
    append([K2, K1, K3], Ks0), list_to_set(Ks0, Ks),
    findall(attr(K, Text, Type, Ent, Forms),
            ( member(K, Ks), atom(K),
              attr_record(K, Text, Type, Ent, Forms) ),
            Attrs).

attr_record(K, Text, Type, Ent, Forms) :-
    (   dm_attr(K, Text0, Ty0, Ent0, Pub) -> Forms0 = [public(Pub)] ; Ty0 = auto, Forms0 = [] ),
    (   nonvar(Ent0) -> Ent = Ent0 ; seen_attr(K, _, Ent1) -> Ent = Ent1 ; Ent = global ),
    (   nonvar(Text0) -> Text = Text0
    ;   seen_attr(K, Text1, _) -> Text = Text1
    ;   known_attr(K, Text1, _) -> Text = Text1
    ;   Text = K
    ),
    (   Ty0 \== auto -> Type = Ty0
    ;   attr_type_hint(K, Ty1) -> Type = Ty1
    ;   Type = auto
    ),
    ( dm_output(K) -> Forms = [output|Forms0] ; Forms = Forms0 ).

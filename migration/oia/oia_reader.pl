/** <module> Oracle Intelligent Advisor (Oracle Policy Automation) -> the OIA model

    Reads the artefacts of an OIA project into a neutral model that
    oia_ir.pl translates to Logical English (the design notes
    roadmap.md §5.1). Two sources are understood, both
    documented in README.md from the real files:

      - the per-document generated XML, `bin/<doc>.docx.xgen` (Policy
        Modeling writes one per Word/Excel rule document at every compile):
        the document's attributes with LOCAL ids (b1, p1, ...) and their
        sentence text, its rules as `rule-xml`, and its source paragraphs
        with their Word styles ("OPM - conclusion", "OPM - level 1", ...);
      - the compiled rulebase, `rulebase.xml`, with GLOBAL attribute ids,
        plus `rulebase.stxt` (the sentence forms of every attribute:
        positive, negative, question, uncertain).

    `projectDataModel.xml` gives every attribute's type, keyed by its text.

    ## The model

        oia(Name, Attrs, Rules, Docs)
        Attrs  [attr(Key, Text, Type, Entity, Forms), ...]
               Key    the attribute's text, normalised (lower case, single
                      spaces, no leading article, no punctuation) — what
                      links the documents of a project and the columns of
                      its test files, which name attributes by their text
               Type   boolean | number | currency | text | date | datetime | auto
               Forms  [negative(T), question(T), uncertain(T), ...]
        Rules  [rule(Id, Doc, Name, Para, Tree), ...]
               Tree   conclude(Key, Entity, Value, Cond, Else)
                      table(Entity, CondCols, ConclCols)
                      conclude_instance(rel(R), SourceEntity, Identity, Cond)
                      event(Action, Cond)
                      unsupported(XMLText)
        Docs   [doc(Name, Paragraphs)]  Paragraphs [para(N, Style, Text)]

    Expressions: att(Key), and(L), or(L), not(E), eq(A, B), ne(A, B),
    gt/ge/lt/le(A, B), known(E), unknown(E), uncertain(E), str(S), num(N),
    date(Y, M, D), true, false, uncertain_value, mul/div/add/sub(A, B),
    neg(A), add_months(A, B), add_days(A, B), add_years(A, B),
    current_date, temporal(Name, Args), inline(Conclude), cite(Tag, E),
    via(rel(R), E) (an attribute of the instance a relationship leads to),
    inst_count(rel(R)), inst_sum(rel(R), E), inst_min/inst_max(rel(R), E),
    inst_count_if(rel(R), C), exists(rel(R), C), forall(rel(R), C),
    text(E), mod(A, B), pow(A, B), min(A, B), max(A, B), round(A, num(D)),
    contains/starts_with/ends_with(A, B), concat(A, B) (oia_ir.pl reads a
    `plus` of texts as one), unsupported(Tag, XMLText).

    Docs also carries the entities and relationships: entity(Id, Text,
    IdKey), relationship(Id, Source, Target, Text), relationship_info(Id,
    Type, ReverseId, ReverseText, Containment).
*/

:- module(oia_reader, [
    oia_read_project/4,          % +Dir, +Kind, +Name, -Model
    oia_key/2,                   % +Text, -Key
    oia_attr_type/3              % +Model, +Key, -Type
  ]).

:- use_module(library(sgml)).
:- use_module(library(xpath)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).

		 /*******************************
		 *           THE PROJECT        *
		 *******************************/

%!  oia_read_project(+Dir, +Kind, +Name, -Model) is det.
%
%   Kind is `xgen` (bin/**/*.xgen) or `rulebase` (rulebase.xml + .stxt).
oia_read_project(Dir, xgen, Name, oia(Name, Attrs, Rules, Docs)) :-
    directory_files_recursive(Dir, '.xgen', Files0),
    msort(Files0, Files),
    data_model_types(Dir, Types),
    foldl(read_xgen(Types), Files, a([], [], []), a(Attrs0, Rules0, Docs0)),
    merge_attrs(Attrs0, Attrs),
    reverse(Rules0, Rules), reverse(Docs0, Docs).
oia_read_project(Dir, rulebase, Name, oia(Name, Attrs, Rules, [doc('rulebase.xml', [])|EntRels])) :-
    atomic_list_concat([Dir, '/rulebase.xml'], RB),
    atomic_list_concat([Dir, '/rulebase.stxt'], ST),
    data_model_types(Dir, Types),
    sentence_forms(ST, Forms),
    load_dom(RB, DOM),
    DOM = [element(rulebase, _, Content)],
    findall(A, rulebase_attr(Content, Forms, Types, A), Attrs0),
    merge_attrs(Attrs0, Attrs),
    ids_to_keys_rulebase(Attrs0, Map),
    (   member(element(rules, _, RuleEls), Content)
    ->  true
    ;   RuleEls = []
    ),
    findall(R, ( nth1(I, RuleEls, El), El = element(_, _, _),
                 rulebase_rule(Map, I, El, R) ), Rules),
    %  the entities and relationships, for entity-level rules
    findall(entity(E, T, IdKey),
            ( member(element(entity, EA, _), Content), memberchk(name=E, EA), E \== global,
              ( memberchk(text=T, EA) -> true ; T = E ),
              ( memberchk('identifying-attribute-name'=IdA, EA), memberchk(IdA-IdKey, Map) -> true ; IdKey = none ) ),
            Ents),
    findall(relationship(RId, Src, Tgt, RT),
            ( member(element(relationship, RA, _), Content), memberchk('relationship-id'=RId, RA),
              memberchk(source=Src, RA), memberchk(target=Tgt, RA),
              ( memberchk('relationship-text'=RT, RA) -> true ; RT = RId ) ),
            Rels),
    findall(relationship_info(RId, Ty, Rev, RevT, Cont),
            ( member(element(relationship, RA, _), Content), memberchk('relationship-id'=RId, RA),
              ( memberchk(type=Ty, RA) -> true ; Ty = 'OneToMany' ),
              ( memberchk('reverse-relationship-id'=Rev, RA) -> true ; Rev = none ),
              ( memberchk('reverse-relationship-text'=RevT, RA) -> true ; RevT = none ),
              ( memberchk('is-containment'=true, RA) -> Cont = true ; Cont = false ) ),
            Infos),
    append([Ents, Rels, Infos], EntRels).

directory_files_recursive(Dir, Ext, Files) :-
    findall(F, ( directory_member(Dir, F, [recursive(true)]),
                 sub_atom(F, _, _, 0, Ext),
                 \+ sub_atom(F, _, _, _, '/out/') ), Files).

%   The files start with a byte-order mark, which the XML parser would read
%   as text before the root element.
load_dom(File, DOM) :-
    read_file_to_string(File, S0, [encoding(utf8)]),
    ( sub_string(S0, 0, 1, _, "\uFEFF") -> sub_string(S0, 1, _, 0, S1) ; S1 = S0 ),
    keep_literal_spaces(S1, S),
    setup_call_cleanup(open_string(S, In),
                       load_structure(In, DOM, [dialect(xml), space(remove)]),
                       close(In)).

%   The parser drops and collapses white space (space(remove)), which is
%   right for the markup and wrong for a string literal: "  <div>    <dt"
%   is the text the rule builds. Its spaces are kept as no-break spaces
%   through the parse, and given back by expr/3 (`string-value`).
keep_literal_spaces(S0, S) :-
    (   sub_string(S0, _, _, _, "<string-value")
    ->  split_string(S0, "", "", [_]),
        string_codes(S0, Cs0),
        literal_spaces(Cs0, out, Cs),
        string_codes(S, Cs)
    ;   S = S0
    ).

literal_spaces([], _, []).
literal_spaces(Cs0, out, Out) :-
    (   append(`<string-value`, Rest, Cs0) -> Open = `<string-value`
    ), !,
    append(Open, R1, Out), copy_to_gt(Rest, R1, Rest1, Out1),
    literal_spaces_in(Rest1, Out1).
literal_spaces([C|Cs], out, [C|Out]) :- literal_spaces(Cs, out, Out).

copy_to_gt([0'>|Cs], [0'>|T], Cs, T) :- !.
copy_to_gt([C|Cs], [C|Out], Rest, T) :- copy_to_gt(Cs, Out, Rest, T).

%   Inside a string-value, up to its end tag: spaces become no-break spaces.
literal_spaces_in(Cs0, Out) :-
    append(`</string-value>`, Rest, Cs0), !,
    append(`</string-value>`, Out1, Out),
    literal_spaces(Rest, out, Out1).
literal_spaces_in([0' |Cs], [0'\u00A0|Out]) :- !, literal_spaces_in(Cs, Out).
literal_spaces_in([C|Cs], [C|Out]) :- literal_spaces_in(Cs, Out).
literal_spaces_in([], []).

		 /*******************************
		 *           NORMALISING        *
		 *******************************/

%!  oia_key(+Text, -Key) is det.
%
%   The attribute's text normalised for matching across documents and test
%   files: lower case, curly quotes straightened, punctuation dropped,
%   single spaces, without a leading article or a trailing "is true".
oia_key(Text, Key) :-
    format(string(S0), "~w", [Text]),
    string_lower(S0, S1),
    string_codes(S1, Cs0),
    maplist(key_code, Cs0, Cs1),
    string_codes(S2, Cs1),
    split_string(S2, " ", " ", Ws0),
    exclude(==(""), Ws0, Ws1),
    ( append(Ws2, ["is", "true"], Ws1) -> true ; Ws2 = Ws1 ),
    ( Ws2 = [Art|Rest], memberchk(Art, ["the", "a", "an"]), Rest \== [] -> Ws = Rest ; Ws = Ws2 ),
    atomic_list_concat(Ws, ' ', Key).

key_code(C, D) :-
    (   code_type(C, alnum) -> D = C
    ;   memberchk(C, `'’‘`) -> D = 0''
    ;   D = 32
    ).

		 /*******************************
		 *   projectDataModel.xml TYPES *
		 *******************************/

%   Key-Type for every attribute of the data model, by its text.
data_model_types(Dir, Types) :-
    atomic_list_concat([Dir, '/projectDataModel.xml'], F),
    (   exists_file(F)
    ->  load_dom(F, DOM),
        findall(K-T, ( xpath(DOM, //attribute(@type=T0), A),
                       xpath(A, text/base(text), Base),
                       oia_key(Base, K), downcase_atom(T0, T) ), Types0),
        list_to_set(Types0, Types)
    ;   Types = []
    ).

		 /*******************************
		 *            .xgen             *
		 *******************************/

read_xgen(Types, File, a(A0, R0, D0), a(A, R, D)) :-
    load_dom(File, DOM),
    DOM = [element(root, _, Content)],
    file_base_name(File, Base),
    ( atom_concat(DocName, '.xgen', Base) -> true ; DocName = Base ),
    %  local id -> key, and the attributes
    findall(Id-attr(Key, Text, Type, Entity, Forms),
            ( xpath(element(root, [], Content), //entity, EntEl),
              xgen_entity_name(EntEl, Entity),
              xpath(EntEl, attribute(@name=Id, @type=T0), AEl),
              xpath(AEl, text/base(text), Text),
              oia_key(Text, Key),
              downcase_atom(T0, T1),
              ( T1 == auto, memberchk(Key-T2, Types), T2 \== auto -> Type = T2 ; Type = T1 ),
              xgen_forms(AEl, Text, Forms) ),
            IdAttrs),
    pairs_keys_values(IdAttrs, _, NewAttrs),
    append(A0, NewAttrs, A),
    findall(Id-Key, member(Id-attr(Key, _, _, _, _), IdAttrs), Map),
    (   member(element(rules, _, RuleEls), Content) -> true ; RuleEls = [] ),
    %  the document's local entity and relationship ids, as the project's
    %  (an entity by its name, a relationship by its text)
    findall(LId-EName, ( xpath(element(root, [], Content), //entity(@id=LId), EE),
                         xgen_entity_name(EE, EName) ), EntMap),
    findall(RId0-RT, ( xpath(element(root, [], Content), //relationship(@'relationship-id'=RId0, @text=RT0), _),
                       atom_string(RT0, RTS), oia_key(RTS, RT) ), RelMap),
    b_setval(oia_xgen_ids, ids(EntMap, RelMap)),
    findall(rule(RId, DocName, RName, Para, Tree),
            ( member(element(rule, RA, RC), RuleEls),
              memberchk(id=RId, RA),
              ( memberchk(name=RName, RA) -> true ; RName = '' ),
              ( memberchk('source-offset'=Para, RA) -> true ; Para = none ),
              member(element('rule-xml', _, [Top]), RC),
              tree(Map, Top, Tree0), local_ids(Tree0, Tree) ),
            Rules),
    b_setval(oia_xgen_ids, none),
    reverse(Rules, RulesRev), append(RulesRev, R0, R),
    (   member(element(source, _, Ps), Content)
    ->  findall(para(N, S, T), ( member(element(p, PA, _), Ps),
                                 memberchk(para=N, PA), memberchk(s=S, PA),
                                 memberchk(t=T, PA) ), Paras)
    ;   Paras = []
    ),
    %  the entities and relationships the document declares
    findall(entity(EN, EN, none), ( xpath(element(root, [], Content), //entity(@id=_), EE2), xgen_entity_name(EE2, EN) ), DEnts),
    findall(relationship(RT, Src, Tgt, RT),
            ( xpath(element(root, [], Content), //relationship(@'relationship-id'=_, @text=RT0, @source=S0, @target=T0r), _),
              atom_string(RT0, RTS), oia_key(RTS, RT),
              xgen_local_entity(EntMap, S0, Src), xgen_local_entity(EntMap, T0r, Tgt) ),
            DRels),
    findall(relationship_info(RT, Ty, none, none, true),
            ( xpath(element(root, [], Content), //relationship(@'relationship-id'=_, @text=RT0, @type=Ty, @'is-containment'=true), _),
              atom_string(RT0, RTS), oia_key(RTS, RT) ), DInfo),
    append([DEnts, DRels, DInfo], DM),
    D = [doc(DocName, Paras)|DM0], append(D0, DM, DM0).

xgen_entity_name(EntEl, Name) :-
    (   xpath(EntEl, /self(@ref=Name), _) -> true
    ;   EntEl = element(entity, A, _), memberchk(name=N0, A), oia_key(N0, Name)
    ).

xgen_local_entity(_, global, global) :- !.
xgen_local_entity(Map, L, N) :- ( memberchk(L-N, Map) -> true ; N = L ).

%   An expression's local entity and relationship ids replaced by the
%   project's (inside one .xgen, `ent0`, `rel0`).
local_ids(T0, T) :-
    (   b_getval(oia_xgen_ids, ids(EM, RM))
    ->  local_ids(EM, RM, T0, T)
    ;   T = T0
    ).
local_ids(EM, RM, X, Y) :-
    (   var(X) -> Y = X
    ;   X = rel(R0), atom(R0) -> ( memberchk(R0-R, RM) -> Y = rel(R) ; Y = X )
    ;   X = conclude(K, E0, V0, C0, O0) -> xgen_local_entity(EM, E0, E), maplist(local_ids(EM, RM), [V0, C0, O0], [V, C, O]), Y = conclude(K, E, V, C, O)
    ;   X = table(E0, A0, B0) -> xgen_local_entity(EM, E0, E), local_ids(EM, RM, A0, A), local_ids(EM, RM, B0, B), Y = table(E, A, B)
    ;   compound(X) -> X =.. [F|As], maplist(local_ids(EM, RM), As, Bs), Y =.. [F|Bs]
    ;   Y = X
    ).

%   The authored sentence forms of an .xgen attribute: only its base text
%   and Oracle's own parse, s(ver(..), v(Verb, t(Aspect, Tense, Mood)),
%   Subject, Object) — from which the negative form is derived.
xgen_forms(AEl, _Text, Forms) :-
    (   xpath(AEl, text/parse(text), P), catch(term_string(PT, P), _, fail)
    ->  Forms = [parse(PT)]
    ;   Forms = []
    ).

		 /*******************************
		 *   rulebase.xml + .stxt       *
		 *******************************/

sentence_forms(File, Forms) :-
    (   exists_file(File)
    ->  load_dom(File, DOM),
        findall(Id-F, ( xpath(DOM, //attribute(@'attr-id'=Id), A),
                        attr_forms(A, F) ), Forms)
    ;   Forms = []
    ).

attr_forms(A, Forms) :-
    findall(basic(B), xpath(A, basic(text), B), F1),
    findall(F, ( xpath(A, 'third-person', TP), TP = element(_, _, TC),
                 member(element(Tag, _, [T]), TC),
                 memberchk(Tag, [positive, negative, question, uncertain, unknown, text]),
                 F =.. [Tag, T] ), F2),
    append(F1, F2, Forms).

rulebase_attr(Content, Forms, Types, attr(Key, Text, Type, Entity, AF)) :-
    member(element(entity, EA, EC), Content),
    memberchk(name=Entity, EA),
    member(element(attribute, AA, _), EC),
    memberchk(name=Id, AA),
    ( memberchk(Id-AF0, Forms) -> true ; AF0 = [] ),
    ( memberchk(basic(Text), AF0) -> true ; Text = Id ),
    AF = [id(Id)|AF0],
    oia_key(Text, Key),
    ( memberchk(type=T0, AA) -> downcase_atom(T0, T1) ; T1 = auto ),
    ( T1 == auto, memberchk(Key-T2, Types) -> Type = T2 ; Type = T1 ).

ids_to_keys_rulebase(Attrs, Map) :-
    findall(Id-Key, ( member(attr(Key, _, _, _, F), Attrs), memberchk(id(Id), F) ), Map).

rulebase_rule(Map, I, El, rule(I, 'rulebase.xml', Name, none, Tree)) :-
    tree(Map, El, Tree),
    (   Tree = conclude(K, _, _, _, _) -> Name = K
    ;   Tree = table(_, _, Cols), Cols = [concl(K, _)|_] -> Name = K
    ;   Name = ''
    ).

		 /*******************************
		 *  rule-xml -> expression tree *
		 *******************************/

tree(Map, element(conclude, A, C), conclude(Key, Entity, Value, Cond, Else)) :- !,
    attr_key(Map, A, Key),
    ( memberchk('entity-id'=Entity, A) -> true ; Entity = global ),
    (   member(element(value, _, [V]), C) -> expr(Map, V, Value) ; Value = true ),
    (   member(element(condition, _, [CE]), C) -> expr(Map, CE, Cond0) ; Cond0 = true ),
    cite(A, Cond0, Cond),
    (   member(element(otherwise, _, [O]), C) -> expr(Map, O, Else) ; Else = none ).
tree(Map, element('table-conclude', A, C), table(Entity, CondCols, ConclCols)) :- !,
    ( memberchk('entity-id'=Entity, A) -> true ; Entity = global ),
    findall(CC, ( member(element('condition-col', _, CCC), C), cond_col(Map, CCC, CC) ), CondCols),
    findall(concl(Key, Vals),
            ( member(element('conclusion-col', CA, CCC2), C),
              ( memberchk('relationship-id'=R, CA) -> Key = rel(R) ; attr_key(Map, CA, Key) ),
              findall(V, ( member(element(value, VA, [VE]), CCC2), expr(Map, VE, V0),
                           span(VA, N), length(Vs0, N), maplist(=(V0), Vs0), member(V, Vs0) ), Vals0),
              %  an empty cell of a conclusion column: nothing concluded
              findall(V, ( member(El, CCC2), cell_value(Map, El, V0, N),
                           length(Vs0, N), maplist(=(V0), Vs0), member(V, Vs0) ), Vals1),
              ( Vals1 == [] -> Vals = Vals0 ; Vals = Vals1 ) ),
            ConclCols).
tree(Map, element('conclude-instance', A, C), conclude_instance(rel(R), Src, Id, Cond)) :- !,
    memberchk('relationship-id'=R, A),
    ( memberchk(source=Src, A) -> true ; Src = global ),
    (   member(element(identity, _, [I]), C) -> expr(Map, I, Id) ; Id = none ),
    (   member(element(condition, _, [CE]), C) -> expr(Map, CE, Cond) ; Cond = true ).
tree(Map, element(event, A, C), event(Action, Cond)) :- !,
    ( memberchk(action=Action, A) -> true ; Action = '' ),
    (   member(element(condition, _, [CE]), C) -> expr(Map, CE, Cond) ; Cond = true ).
tree(_, El, unsupported(Text)) :-
    xml_text(El, Text).

%   A condition column: its header (the attribute every cell tests), and its
%   cells, a merged cell (span=N) repeated N times.
cond_col(Map, C, col(Header, Cells)) :-
    (   member(element(header, _, [H]), C) -> expr(Map, H, Header) ; Header = none ),
    (   member(element(rows, _, Rs), C) -> true ; Rs = [] ),
    findall(Cell, ( member(element(T, A, CC), Rs), cell(Map, T, A, CC, Cell0),
                    span(A, N), length(L, N), maplist(=(Cell0), L), member(Cell, L) ), Cells).

cell_value(Map, element(value, VA, [VE]), V, N) :- !, expr(Map, VE, V), span(VA, N).
cell_value(_, element(empty, EA, _), uncertain_value, N) :- span(EA, N).

cell(_, empty, _, _, empty) :- !.
cell(Map, condition, _, [E], cond(X)) :- !, expr(Map, E, X).
cell(Map, T, _, Args, op(T, Xs)) :- maplist(expr(Map), Args, Xs).

span(A, N) :- ( memberchk(span=S, A), atom_number(S, N) -> true ; N = 1 ).

%   A citation tag on a condition ("[s 6:x=1-4],y=12"): the text before the
%   colon, kept with the condition.
cite(A, E, Out) :-
    (   memberchk(tags=Tags, A), tag_citation(Tags, Cite)
    ->  Out = cite(Cite, E)
    ;   Out = E
    ).

tag_citation(Tags, Cite) :-
    sub_atom(Tags, 0, 1, _, '['),
    sub_atom(Tags, B, _, _, ':x='), B > 1,
    sub_atom(Tags, 1, _, _, _), L is B - 1,
    sub_atom(Tags, 1, L, _, Cite).

attr_key(Map, A, Key) :-
    memberchk('attr-id'=Id, A),
    ( memberchk(Id-Key, Map) -> true ; Key = Id ).

expr(Map, element(attribute, A, _), E) :- !, attr_key(Map, A, K), cite(A, att(K), E).
expr(Map, element(and, _, C), and(L)) :- !, maplist(expr(Map), C, L).
expr(Map, element(or, _, C), or(L)) :- !, maplist(expr(Map), C, L).
expr(Map, element(not, A, [X]), E) :- !, expr(Map, X, Y), cite(A, not(Y), E).
expr(Map, element(condition, _, [X]), E) :- !, expr(Map, X, E).
expr(Map, element(for, _, C), E) :-                 % an attribute through a relationship
    member(element(relationship, RA, _), C), memberchk('relationship-id'=R, RA), !,
    exclude(is_relationship, C, [X]), expr(Map, X, EX), E = via(rel(R), EX).
expr(Map, element(for, _, C), E) :- !,              % a global attribute from an entity's scope
    exclude(scope_ref, C, [X]), expr(Map, X, E).
expr(Map, element('scope-for', _, C), E) :- !,
    exclude(scope_ref, C, [X]), expr(Map, X, E).
expr(Map, element(Tag, _, C), E) :-                 % InstanceSum, InstanceCountIf, Exists, ForAll, ...
    instance_function(Tag, F),
    member(element(relationship, RA, _), C), memberchk('relationship-id'=R, RA), !,
    exclude(is_relationship, C, Rest),
    maplist(expr(Map), Rest, Args),
    E =.. [F, rel(R)|Args].
expr(Map, element(round, _, [X, element('number-value', _, [N])]), round(EX, num(D))) :- !,
    expr(Map, X, EX), atom_number(N, D).
expr(Map, element(text, _, [X]), text(EX)) :- !, expr(Map, X, EX).
expr(Map, element(conclude, A, C), inline(T)) :- !, tree(Map, element(conclude, A, C), T).
expr(_, element('string-value', _, T), str(S)) :- !,
    ( T = [S0] -> atom_string(S0, S1), split_string(S1, "\u00A0", "", Ps), atomic_list_concat(Ps, ' ', SA), atom_string(SA, S) ; S = "" ).
expr(_, element('number-value', _, [T]), num(N)) :- !, atom_number(T, N).
expr(_, element('date-value', _, [T]), date(Y, M, D)) :- !,
    split_string(T, "-", "", [YS, MS, DS]), number_string(Y, YS), number_string(M, MS), number_string(D, DS).
expr(_, element('true-value', _, _), true) :- !.
expr(_, element('false-value', _, _), false) :- !.
expr(_, element('uncertain-value', _, _), uncertain_value) :- !.
expr(_, element('current-date', _, _), current_date) :- !.
expr(Map, element(Tag, A, C), E) :-
    binary(Tag, F0), C = [X, Y], !,
    expr(Map, X, EX), expr(Map, Y, EY),
    (   F0 == add, ( textual(EX) ; textual(EY) ) -> F = concat ; F = F0 ),   % OIA's `+` of texts
    E0 =.. [F, EX, EY], cite(A, E0, E).
expr(Map, element(Tag, A, [X]), E) :-
    unary(Tag, F), !,
    expr(Map, X, EX), E0 =.. [F, EX], cite(A, E0, E).
expr(Map, element(Tag, _, C), temporal(Tag, Args)) :-
    sub_atom(Tag, 0, _, _, 'temporal-'), !,
    maplist(expr(Map), C, Args).
expr(_, El, unsupported(Tag, Text)) :-
    El = element(Tag, _, _), xml_text(El, Text).

scope_ref(element('scope-ref', _, _)).

textual(str(_)).
textual(concat(_, _)).
textual(text(_)).
is_relationship(element(relationship, _, _)).

instance_function('instance-count', inst_count).
instance_function('instance-sum', inst_sum).
instance_function('instance-minimum', inst_min).
instance_function('instance-maximum', inst_max).
instance_function('instance-count-if', inst_count_if).
instance_function(exists, exists).
instance_function('for-all', forall).
instance_function(forall, forall).

binary(equals, eq).        binary('not-equals', ne).
binary('greater-than', gt). binary('greater-than-equals', ge).
binary('less-than', lt).   binary('less-than-equals', le).
binary(multiply, mul).     binary(divide, div).
binary(add, add).          binary(plus, add).
binary(subtract, sub).     binary(minus, sub).
binary('add-months', add_months). binary('add-days', add_days). binary('add-years', add_years).
binary(min, min).          binary(max, max).
binary(minimum, min).      binary(maximum, max).
binary(modulo, mod).       binary(xy, pow).
binary(contains, contains). binary('starts-with', starts_with). binary('ends-with', ends_with).
binary('day-difference', day_difference). binary('month-difference', month_difference).
binary('year-difference', year_difference).

unary(known, known).       unary(unknown, unknown).
unary(uncertain, uncertain). unary(negate, neg).
unary(round, round).       unary('round-down', floor). unary('round-up', ceiling).
unary(certain, known).     unary(length, length).

xml_text(El, Text) :-
    with_output_to(string(Text),
        catch(xml_write(current_output, El, [header(false), layout(false)]), _,
              print(El))).

		 /*******************************
		 *        MERGING ATTRIBUTES    *
		 *******************************/

%   One attribute per key: the documents of a project share attributes by
%   their text, each document giving it a local id. A typed record wins
%   over an `auto` one, and the sentence forms are pooled.
merge_attrs(Attrs0, Attrs) :-
    findall(K, member(attr(K, _, _, _, _), Attrs0), Ks0),
    list_to_set(Ks0, Ks),
    maplist(merge_one(Attrs0), Ks, Attrs).

merge_one(Attrs0, K, attr(K, Text, Type, Entity, Forms)) :-
    findall(T-Ty-E-F, member(attr(K, T, Ty, E, F), Attrs0), All),
    All = [Text-_-Entity-_|_],
    (   member(_-Ty1-_-_, All), Ty1 \== auto -> Type = Ty1 ; Type = auto ),
    findall(F1, ( member(_-_-_-Fs, All), member(F1, Fs) ), Forms0),
    list_to_set(Forms0, Forms).

%!  oia_attr_type(+Model, +Key, -Type) is det.
oia_attr_type(oia(_, Attrs, _, _), Key, Type) :-
    ( memberchk(attr(Key, _, Type, _, _), Attrs) -> true ; Type = auto ).

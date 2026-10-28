/** <module> A Logical English program as a readable document

    The readable document of a program is the program itself, set out for a
    person who reads it outside the editor: the domain expert who must check
    that the rules say what the regulation, the contract or the policy says.
    It follows the idea of literate programming (Knuth): the program is a
    text for people first, and a reader moves through it by its own
    cross-references.

    What the document shows:
    - every statement exactly as the author wrote it, with its words and its
      line breaks and indentation (the indentation of a rule is part of its
      meaning, language.md §4), and nothing else from the source;
    - each word coloured for what it is: a word of Logical English itself (a
      keyword), a word of a template, a variable, a value;
    - each sentence of a rule, a scenario or a query linked to where its
      template is defined (the first rule or fact that concludes it, else the
      template's declaration); a sentence whose template an included
      resource defines is linked to that resource's own readable document;
    - for each definition, the statements that use it; for each template,
      where it is defined and used, in an index at the end;
    - the sections as headings, a table of contents, decision tables as
      tables, and a short legend of the colours.

    Comments are left out: they are the author's notes, and a document that
    is passed around should not carry them unless the author asks
    (option comments(true)). A comment that starts with a notice word (i18n
    keywords.csv, `notice_start`: "Copyright", "©", "Licence",
    "Disclaimer", ...) is a notice, not a note: it is always kept, at the
    head of the document. That is how a program states its copyright
    (language.md §10).

    How it is made: the program is loaded once more, into a module of its
    own, while le_grammar:literal_parsed_hook/3 records where each sentence
    is and which template it matched — the grammar's own reading, not a
    second guess. The loaded program says what each statement is (rule,
    fact, LPS law, ...) and where each predicate is defined. The result is a
    document term (readable_ir/3), which three writers turn into Markdown,
    HTML (one self-contained file, with its styles inline and a menu to pick
    one) and Word (.docx). A PDF is the HTML printed by the browser (format
    `pdf` is the HTML that opens the print dialog).

    The same predicate serves a program in LE for LPS (`the target language
    is: lps.`): its laws, reactive rules, constraints and `initially`
    sentences are statements of their own kinds.
*/

:- module(le_readable, [
    readable_document/3,        % +Text, +Options, -Result:dict
    readable_ir/3,              % +Text, +Options, -Doc:dict
    readable_styles/1,          % -Styles:list(atom)
    readable_formats/1          % -Formats:list(atom)
]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(base64)).
:- use_module(library(zip)).
:- use_module(le_i18n).

:- thread_local recording/0, rec_span/5.

%!  readable_styles(-Styles) is det.
%
%   The looks of the HTML document, picked from its menu: `plain` (the
%   default: sober, for reading), `compact` (dense, for a long program),
%   `legal` (set like a statute), `cute` (more colour and an icon for each
%   kind of statement, for younger readers) and `editor` (the colours of the
%   editor, for a reader who moves between the two).
readable_styles([plain, compact, legal, cute, editor]).

%!  readable_formats(-Formats) is det.
readable_formats([html, md, docx, pdf]).

		 /*******************************
		 *        THE ENTRY POINT       *
		 *******************************/

%!  readable_document(+Text, +Options, -Result) is det.
%
%   Result is _{content, mime, fileName, encoding}: the document of the
%   program Text in the format of Options; `encoding` is "base64" for the
%   binary .docx, "utf8" otherwise. Options:
%     - format(F): html (default), md, docx or pdf
%     - style(S): one of readable_styles/1, the look the HTML opens with
%     - comments(Bool): keep the author's comments (default false)
%     - base(Dir): where the program's includes resolve (default '-')
%     - name(Name): the program's name (an example name or a file name)
%     - link_base(URL): the address of the server whose /readable/ route
%       renders an included resource; none for no links to resources
%     - date(Date): the date written in the document (default today)
readable_document(Text, Options, Result) :-
    once(readable_document_(Text, Options, Result)).

readable_document_(Text, Options, Result) :-
    readable_ir(Text, Options, Doc),
    option_or(format(Format0), Options, html),
    ( atom(Format0) -> Format = Format0 ; atom_string(Format, Format0) ),
    file_stem(Doc, Stem),
    (   Format == md
    ->  md_document(Doc, Content),
        file_name_extension(Stem, md, FN0), atom_string(FN0, FN),
        Result = _{content: Content, mime: "text/markdown; charset=utf-8",
                   fileName: FN, encoding: "utf8"}
    ;   Format == docx
    ->  docx_document(Doc, Bytes),
        base64_bytes(Bytes, B64),
        file_name_extension(Stem, docx, FN0), atom_string(FN0, FN),
        Result = _{content: B64,
                   mime: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                   fileName: FN, encoding: "base64"}
    ;   Format == pdf
    ->  html_document(Doc, [autoprint(true)], Content),
        file_name_extension(Stem, html, FN0), atom_string(FN0, FN),
        Result = _{content: Content, mime: "text/html; charset=utf-8",
                   fileName: FN, encoding: "utf8"}
    ;   html_document(Doc, [], Content),
        file_name_extension(Stem, html, FN0), atom_string(FN0, FN),
        Result = _{content: Content, mime: "text/html; charset=utf-8",
                   fileName: FN, encoding: "utf8"}
    ).

file_stem(Doc, Stem) :-
    (   Doc.name \== "", file_base_name(Doc.name, B), file_name_extension(S0, _, B), S0 \== ''
    ->  true
    ;   S0 = Doc.title
    ),
    format(atom(S1), "~w", [S0]),
    atomic_list_concat(Parts, ' ', S1), atomic_list_concat(Parts, '_', Stem0),
    atom_string(Stem0, Stem).

option_or(Opt, Options, Default) :-
    (   memberchk(Opt, Options), arg(1, Opt, V), nonvar(V) -> true
    ;   arg(1, Opt, Default)
    ).

base64_bytes(Bytes, B64) :-
    atom_codes(A, Bytes),
    base64(A, B64A),
    atom_string(B64A, B64).

		 /*******************************
		 *   THE DOCUMENT OF A PROGRAM  *
		 *******************************/

%!  readable_ir(+Text, +Options, -Doc) is det.
%
%   The document term of the program Text: a dict with
%     title, name, lang, target, date, style, notices:[string],
%     headings:[_{anchor, level, text}],
%     blocks:[Block], index:[Entry]
%   A Block is one of
%     _{type: heading, level, anchor, kind, text, source:Segs}
%     _{type: statement, n, anchor, kind, label:Segs, lines:[_{indent, segs}],
%       targets:[PredAnchor], xref:[_{what, refs:[N]}]}
%     _{type: (table), n, anchor, kind, header:Segs, rows:[[Cell]], targets, xref}
%     _{type: comment, text}
%   and a Seg is _{class, text, link} where class is one of k (a keyword), t
%   (a word of a template), d (a word of a template's declaration), p (a place
%   of a declaration), v (a variable), c (a value), n (a number), s (a quoted
%   text), o (anything else) and link is "" or "#anchor" or a URL.
readable_ir(Text, Options, Doc) :-
    once(readable_ir0(Text, Options, Doc)).

readable_ir0(Text, Options, Doc) :-
    option_or(base(Base0), Options, (-)),
    ( Base0 == "" -> Base = (-) ; atom(Base0) -> Base = Base0 ; atom_string(Base, Base0) ),
    le_grammar:tokenize_for_language(Text, Tokens0),
    (   once(le_i18n:detect_language_tokens(Tokens0, Lang0)) -> Lang = Lang0 ; Lang = en ),
    le_i18n:with_le_language(Lang, le_readable:readable_ir_(Text, Tokens0, Base, Lang, Options, Doc)).

%   Nothing of a document stays on the server once it is made: the program
%   is loaded into a module of the thread's own (one name per worker
%   thread, so neither modules nor their mutexes pile up), and the module's
%   clauses, the recorded sentences and the templates cached for it are
%   dropped when the document is done, or fails.
readable_ir_(Text, Tokens0, Base, Lang, Options, Doc) :-
    thread_self(Me),
    ( atom(Me) -> Id = Me ; thread_property(Me, id(Id)) ),
    atom_concat(le_readable_kb_, Id, M),
    setup_call_cleanup(
        destroy_module_clauses(M),
        (   nb_setval(le_readable_base, Base),
            load_recording(Text, Base, M),
            build_doc(Text, Tokens0, M, Lang, Options, Doc)
        ),
        forget_document(M)).

forget_document(M) :-
    destroy_module_clauses(M),
    retractall(rec_span(_, _, _, _, _)),
    nb_setval(le_readable_base, (-)),
    (   nb_current(le_prepared_templates, k(M, _, _, _)-_)
    ->  nb_delete(le_prepared_templates)
    ;   true
    ).

load_recording(Text, Base, M) :-
    retractall(rec_span(_, _, _, _, _)),
    setup_call_cleanup(
        assertz(recording),
        catch(le_kbs:load_text(Text, Base, M, [skip_tests]), E,
              ( print_message(warning, E) )),
        retractall(recording)).

destroy_module_clauses(M) :-
    (   current_module(M)
    ->  forall(current_predicate(M:F/N), catch(abolish(M:F/N), _, true))
    ;   true
    ).

%   The grammar's report of each sentence it matched (le_grammar.pl): where
%   it is, its predicate, and for each word of the matched template whether
%   it is a word (w(Word)), a variable (v) or a value (c).
:- multifile le_grammar:literal_parsed_hook/3.
le_grammar:literal_parsed_hook(Tokens, Literal, Instance) :-
    recording,
    callable(Literal),
    include(has_loc, Tokens, LTokens),
    LTokens = [T0|_],
    last(LTokens, TN),
    tok_loc(T0, S, _), tok_loc(TN, _, E),
    functor(Literal, F, A),
    Literal =.. [_|Args],
    (   is_list(Instance) -> maplist(skel_elem(Args), Instance, Skel) ; Skel = [] ),
    findall(TS, ( member(T, LTokens), tok_loc(T, TS, _) ), Starts),
    assertz(rec_span(S, E, F/A, Skel, Starts)).

has_loc(T) :- compound(T), functor(T, _, 2), arg(2, T, loc(_, _)).
tok_loc(T, S, E) :- arg(2, T, loc(S, E)).

skel_elem(_, X, v) :- var(X), !.
skel_elem(Args, X, C) :-
    member_eq(X, Args), !,
    (   compound(X), \+ is_arith(X) -> C = m ; C = c ).
skel_elem(_, X, w(X)).

is_arith(X) :- compound(X), functor(X, F, 2), memberchk(F, [+, -, *, /, mod, //, ^, **, min, max]).
is_arith(X) :- compound(X), functor(X, F, 1), memberchk(F, [-, abs, ceiling, floor, round, truncate, integer, sqrt, sign]).

member_eq(X, [Y|_]) :- X == Y, !.
member_eq(X, [_|Ys]) :- member_eq(X, Ys).

		 /*******************************
		 *       WHAT THE KB SAYS       *
		 *******************************/

%   ctx(Text, Len, M, Lang, LineStarts, Elements, Templates, Defs, LinkBase, RawTokens)
%   Elements: el(Start, End, Kind) of the program's own text
%   Templates: tmpl(F/A, Start) of every template with a source (own or not)
%   Defs: def(F/A, Start) of every definition (own or not)

build_doc(Text, Tokens0, M, Lang, Options, Doc) :-
    string_length(Text, Len),
    kb_elements(M, Elements),
    kb_templates(M, Templates),
    kb_definitions(M, Templates, Elements, Defs),
    ( kb_target(M, Target) -> true ; Target = prolog ),
    option_or(link_base(LB0), Options, none),
    ( LB0 == "" -> LinkBase = none ; LinkBase = LB0 ),
    option_or(comments(Comments0), Options, false),
    ( Comments0 == true -> Comments = true ; Comments = false ),
    maplist(norm_token, Tokens0, Tokens1),
    exclude(==(none), Tokens1, Tokens),
    line_starts(Text, LineStarts),
    units(Tokens, Units, CommentToks),
    notices(Text, CommentToks, Lang, Notices, NoticeStarts),
    Ctx = ctx(Text, Len, M, Lang, LineStarts, Elements, Templates, Defs, LinkBase, Tokens0),
    unit_blocks(Units, Ctx, Blocks0),
    (   Comments == true
    ->  comment_blocks(CommentToks, NoticeStarts, CBlocks),
        merge_by_start(Blocks0, CBlocks, Blocks1)
    ;   Blocks1 = Blocks0
    ),
    number_blocks(Blocks1, 1, 1, Blocks2),
    link_blocks(Blocks2, Ctx, Blocks3, Index),
    strip_starts(Blocks3, Blocks),
    findall(_{anchor: A, level: L, text: T},
            ( member(B, Blocks), get_dict(type, B, heading),
              get_dict(anchor, B, A), get_dict(level, B, L), get_dict(text, B, T) ),
            Headings),
    doc_title(M, Options, Title),
    option_or(name(Name0), Options, ""),
    format(string(Name), "~w", [Name0]),
    option_or(date(Date0), Options, today),
    (   Date0 == today
    ->  get_time(Now), format_time(string(Date), "%Y-%m-%d", Now)
    ;   format(string(Date), "~w", [Date0])
    ),
    option_or(style(Style0), Options, plain),
    format(atom(Style1), "~w", [Style0]),
    readable_styles(Styles),
    ( memberchk(Style1, Styles) -> Style = Style1 ; Style = plain ),
    Doc = _{title: Title, name: Name, lang: Lang, target: Target, date: Date,
            style: Style, notices: Notices, headings: Headings,
            blocks: Blocks, index: Index, comments: Comments}.

kb_target(M, T) :- catch(M:le_target_language(T), _, fail), !.

doc_title(M, Options, Title) :-
    (   catch(M:le_kb(N), _, fail), N \== '', N \== none
    ->  format(string(Title), "~w", [N])
    ;   option_or(name(Name), Options, ""), Name \== ""
    ->  file_base_name(Name, B), file_name_extension(S, _, B),
        format(string(Title), "~w", [S])
    ;   ui(document_untitled, Title)
    ).

%   el(Start, End, Kind): what the program's own statements are.
kb_elements(M, Elements) :-
    findall(el(S, E, Kind),
            ( catch(M:le_source_info(Ref, S, E, ID), _, fail),
              Ref \== none, integer(S), S >= 0,
              element_kind(M, Ref, ID, Kind) ),
            Elements0),
    sort(Elements0, Elements).

element_kind(_M, Ref, ID, Kind) :-
    catch(clause(H0, B, Ref), _, fail),
    strip_module(H0, _, H),
    (   H = le_dict(D) -> dict_fa(D, FA), Kind = template(FA)
    ;   H = le_lps_item(K, P, _) -> Kind = lps(K, P)
    ;   H = scenario(N, _) -> Kind = scenario(N)
    ;   H = query_info(N, _, _) -> Kind = query(N)
    ;   H = le_expected(Q, _, _, _) -> Kind = expectation(Q)
    ;   H = le_expected_changes(Q, _, _) -> Kind = expectation(Q)
    ;   H = le_kb(N) -> Kind = kb(N)
    ;   H = ontology(_) -> Kind = ontology
    ;   H = le_service(_, _, _) -> Kind = service
    ;   H = le_provenance_required -> Kind = setting
    ;   B = le_table(_, _) -> functor(H, F, A), Kind = table(F/A)
    ;   callable(H), functor(H, F, A),
        findall(BF/BA, ( B \== true, catch(le_verifier:find_in_body(B, L), _, fail),
                         callable(L), functor(L, BF, BA) ), Fs0),
        sort([F/A|Fs0], Fs),
        (   B == true -> Kind = clause(fact, F/A, ID, Fs) ; Kind = clause(rule, F/A, ID, Fs) )
    ).

dict_fa(D, F/A) :- D =.. [dict, [F|Args]|_], length(Args, A).

%   tmpl(F/A, Start, Words): each template with a source, own or included,
%   Words its declaration's words (atoms and '*' places) for the index.
kb_templates(M, Templates) :-
    findall(tmpl(FA, S),
            ( catch(M:le_source_info(Ref, S, _, template), _, fail),
              catch(clause(M:le_dict(D), true, Ref), _, fail),
              dict_fa(D, FA) ),
            T0),
    sort(2, @<, T0, T1),
    keep_first_template(T1, Templates).

keep_first_template(Ts, Out) :-
    findall(FA, member(tmpl(FA, _), Ts), FAs0), sort(FAs0, FAs),
    findall(tmpl(FA, S), ( member(FA, FAs), once(member(tmpl(FA, S), Ts)) ), Out).

%   def(F/A, Start): where each predicate of a template is concluded — the
%   rules and facts with that head, the decision table that answers it, and
%   (LPS) the causal laws and `initially` sentences that make its fluent true.
kb_definitions(M, Templates, Elements, Defs) :-
    findall(FA, member(tmpl(FA, _), Templates), TFAs0), sort(TFAs0, TFAs),
    findall(def(FA, S),
            ( catch(M:le_source_info(Ref, S, _, _), _, fail), Ref \== none,
              catch(clause(H0, B, Ref), _, fail), strip_module(H0, _, H),
              callable(H), functor(H, F, A), FA = F/A,
              ord_memberchk(FA, TFAs),
              ( B == true -> true ; true ) ),
            D0),
    findall(def(FA, S),
            ( member(el(S, _, lps(K, P)), Elements),
              lps_defined(K, P, Lit), callable(Lit), functor(Lit, F, A), FA = F/A,
              ord_memberchk(FA, TFAs) ),
            D1),
    append(D0, D1, D2),
    sort(D2, Defs).

lps_defined(when, r(_, Effect), Lit) :- effect_literal(Effect, Lit).
lps_defined(initially, P, Lit) :- effect_literal(P, Lit).
lps_defined(head_rule, h(H, _), Lit) :- once(effect_literal(H, Lit)).

effect_literal(le_at(L, _, _), L) :- \+ L = and(_, _), \+ L = not(_).
effect_literal(le_at(L, _, _), Lit) :- effect_literal(L, Lit).
effect_literal(and(A, B), L) :- ( effect_literal(A, L) ; effect_literal(B, L) ).
effect_literal(lps_becomes(L, _, _), L).
effect_literal(lps_from_to(L0, _, _), L) :- effect_literal(L0, L).
effect_literal(lps_at(L0, _), L) :- effect_literal(L0, L).
effect_literal(lps_from(L0, _), L) :- effect_literal(L0, L).
effect_literal(lps_to(L0, _), L) :- effect_literal(L0, L).
effect_literal(L, L) :- callable(L), \+ L = le_at(_, _, _), \+ L = and(_, _),
    \+ L = h(_, _),
    \+ L = lps_becomes(_, _, _), \+ L = not(_), \+ L = r(_, _), functor(L, F, _),
    \+ sub_atom(F, 0, _, _, lps_).

		 /*******************************
		 *            TOKENS            *
		 *******************************/

%   tok(Type, Start, End, Value): Type is word, num, str, punct, indent or
%   comment.
norm_token(word(W, loc(S, E)), tok(word, S, E, W)) :- !.
norm_token(number(N, loc(S, E)), tok(num, S, E, N)) :- !.
norm_token(doubleQuoteString(V, loc(S, E)), tok(str, S, E, V)) :- !.
norm_token(quoteString(V, loc(S, E)), tok(str, S, E, V)) :- !.
norm_token(punctuation(P, loc(S, E)), tok(punct, S, E, P)) :- !.
norm_token(punct(P, loc(S, E)), tok(punct, S, E, P)) :- !.
norm_token(indent(_, loc(S, E)), tok(indent, S, E, nl)) :- !.
norm_token(line_comment(C, loc(S, E)), tok(comment, S, E, C)) :- !.
norm_token(multi_comment(C, loc(S, E)), tok(comment, S, E, C)) :- !.
norm_token(T, tok(word, S, E, W)) :-
    compound(T), functor(T, _, 2), arg(2, T, loc(S, E)), arg(1, T, W0), !,
    format(atom(W), "~w", [W0]).
norm_token(_, none).

		 /*******************************
		 *   STATEMENTS AND HEADINGS    *
		 *******************************/

%   units(+Tokens, -Units, -Comments): the program's statements, in order.
%   A unit is u(Kind, Start, End, Toks), Kind `header(HKind)` for a line that
%   opens a section (it ends with a colon) or `statement`; Toks its tokens,
%   without comments and line breaks.
%
%   A statement ends with a full stop at the end of a line; a declaration of
%   a section of templates ends at the end of its line; a row of a decision
%   table is one line with a `|`.
units(Tokens, Units, Comments) :-
    partition([T]>>(T = tok(comment, _, _, _)), Tokens, Comments, Code),
    units_(Code, [], top, top, Units).

units_([], Cur, Mode, _Prev, Units) :-
    (   Cur == [] -> Units = []
    ;   reverse(Cur, Toks), make_unit(Toks, Mode, U, _), Units = [U]
    ).
units_([tok(indent, _, _, _)|Ts], Cur, Mode, Prev, Units) :- !,
    (   Cur \== [], closes(Mode, Cur)
    ->  reverse(Cur, Toks),
        make_unit(Toks, Mode, U, Mode1),
        next_mode(U, Mode, Prev, Mode1, Mode2, Prev2),
        Units = [U|Us],
        units_(Ts, [], Mode2, Prev2, Us)
    ;   units_(Ts, Cur, Mode, Prev, Units)
    ).
units_([T|Ts], Cur, Mode, Prev, Units) :-
    units_(Ts, [T|Cur], Mode, Prev, Units).

closes(_, [tok(punct, _, _, P)|_]) :- memberchk(P, ['.', ':']), !.
closes(templates(_), _) :- !.
closes((table), Cur) :- !, memberchk(tok(punct, _, _, '|'), Cur).
closes(table_first, _) :- !.

%   make_unit(+Toks, +Mode, -Unit, -HeaderMode)
make_unit(Toks, Mode, u(Kind, S, E, Toks), HMode) :-
    Toks = [tok(_, S, _, _)|_], last(Toks, tok(_, _, E, _)),
    (   last(Toks, tok(punct, _, _, ':')), header_kind(Toks, HKind)
    ->  Kind = header(HKind), header_mode(HKind, Mode, HMode)
    ;   Mode == (table), \+ memberchk(tok(punct, _, _, '|'), Toks)
    ->  Kind = statement, HMode = none
    ;   Mode == (table)
    ->  Kind = row, HMode = none
    ;   Mode == table_first
    ->  Kind = row, HMode = none
    ;   Kind = statement, HMode = none
    ).

%   The mode after a unit: a header sets it; a table ends at its first line
%   without a `|`, back to the mode before it.
next_mode(u(header(_), _, _, _), _Mode, Prev, HMode, Mode2, Prev2) :- !,
    (   HMode == (table) -> Mode2 = table_first, ( Prev == (table) -> Prev2 = top ; Prev2 = Prev )
    ;   HMode == label -> Mode2 = Prev, Prev2 = Prev
    ;   Mode2 = HMode, Prev2 = HMode
    ).
next_mode(u(row, _, _, _), _Mode, Prev, _, (table), Prev) :- !.
next_mode(u(statement, _, _, _), Mode, Prev, _, Mode2, Prev) :-
    ( memberchk(Mode, [(table), table_first]) -> Mode2 = Prev ; Mode2 = Mode ).

header_mode(HKind, Mode, HMode) :-
    (   memberchk(HKind, [templates(_)]) -> HMode = HKind
    ;   HKind == (table) -> HMode = (table)
    ;   HKind == label -> ( memberchk(Mode, [(table), table_first]) -> HMode = label ; HMode = label )
    ;   HKind == section -> HMode = kb
    ;   HMode = HKind
    ).

%   header_kind(+Toks, -Kind): which section a header opens, from its
%   words (the keywords of the program's language).
header_kind(Toks, Kind) :-
    words_of(Toks, Words),
    (   kw_inside(resources_include, Words) -> Kind = resources
    ;   kw_inside(services_include, Words) -> Kind = services
    ;   kw_prefix(kb_open, Words) -> Kind = kb
    ;   kw_prefix(contract_open, Words) -> Kind = kb
    ;   kw_prefix(annexes, Words) -> Kind = section
    ;   kw_prefix(scenario, Words) -> Kind = scenario
    ;   kw_prefix(query, Words) -> Kind = query
    ;   kw_prefix(ontology, Words) -> Kind = ontology
    ;   member(K-T, [predicates-template, templates-template, fluents-fluent,
                     events-event, actions-action, prolog_events-event,
                     constants-constant, functions-function]),
        kw_prefix(K, Words)
    ->  Kind = templates(T)
    ;   kw_prefix(table_open, Words) -> Kind = (table)
    ;   kw_prefix(view_open, Words) -> Kind = view
    ;   kw_prefix(cells_open, Words) -> Kind = cells
    ;   kw_prefix(marker, Words) -> Kind = section
    ;   kw_prefix(rule, Words) -> Kind = label
    ;   Kind = other
    ).

words_of(Toks, Words) :-
    findall(W, ( member(tok(Type, _, _, W0), Toks), memberchk(Type, [word, num]),
                 lower_word(W0, W) ), Words).

lower_word(W0, W) :-
    (   atom(W0) -> downcase_atom(W0, W)
    ;   number(W0) -> W = W0
    ;   format(atom(W1), "~w", [W0]), downcase_atom(W1, W)
    ).

kw_prefix(Key, Words) :-
    kw_synonym_words(Key, Phrase0),
    maplist(lower_word, Phrase0, Phrase),
    append(Phrase, _, Words), !.

kw_inside(Key, Words) :-
    kw_synonym_words(Key, Phrase0),
    maplist(lower_word, Phrase0, Phrase),
    append(_, Rest, Words), append(Phrase, _, Rest), !.

		 /*******************************
		 *            NOTICES           *
		 *******************************/

%   notices(+Text, +CommentToks, +Lang, -Notices, -Starts): the comments
%   that are notices (a copyright, a licence, a disclaimer), each from the
%   comment line that starts with a notice word to an empty comment line or
%   the end of the run of comment lines; Starts the offsets of the comment
%   tokens they took, so that with comments(true) they are not shown twice.
notices(Text, CommentToks, _Lang, Notices, Starts) :-
    comment_runs(Text, CommentToks, Runs),
    findall(N-Ss, ( member(Run, Runs), run_notice(Run, N, Ss) ), Pairs),
    pairs_keys_values(Pairs, Notices, SsL),
    append(SsL, Starts).

%   comment_runs: consecutive comment tokens with only white space between.
comment_runs(_, [], []) :- !.
comment_runs(Text, [C|Cs], [[C|Run]|Runs]) :-
    run_rest(Text, C, Cs, Run, Rest),
    comment_runs(Text, Rest, Runs).

run_rest(Text, Prev, [C|Cs], [C|Run], Rest) :-
    Prev = tok(comment, _, PE, _), C = tok(comment, CS, _, _),
    L is CS - PE, L >= 0, sub_string(Text, PE, L, _, Gap),
    split_string(Gap, "", " \t\r\n", [""]),
    sub_string(Gap, _, _, _, "\n"), !,     % on the next line, not after code
    run_rest(Text, C, Cs, Run, Rest).
run_rest(_, _, Cs, [], Cs).

%   One notice per run at most: from its first notice line to the next
%   empty comment line.
run_notice(Run, Notice, Starts) :-
    maplist(comment_lines, Run, LinesL),
    pairs_from_runs(Run, LinesL, Lines),       % [Start-Line]
    append(_, [S0-L0|After], Lines),
    notice_line(L0), !,
    take_until_empty(After, More),
    findall(L, member(_-L, [S0-L0|More]), Ls),
    atomic_list_concat(Ls, '\n', NA),
    atom_string(NA, Notice),
    findall(S, member(S-_, [S0-L0|More]), Starts0), sort(Starts0, Starts).

pairs_from_runs([], [], []).
pairs_from_runs([tok(_, S, _, _)|Ts], [Ls|Lss], Out) :-
    (   Ls == [] -> P = [S-""]           % an empty comment line ends a notice
    ;   findall(S-L, member(L, Ls), P)
    ),
    pairs_from_runs(Ts, Lss, Rest),
    append(P, Rest, Out).

take_until_empty([], []).
take_until_empty([_-L|_], []) :- L == "", !.
take_until_empty([P|Ps], [P|Qs]) :- take_until_empty(Ps, Qs).

%   The lines of a comment, without the comment marks.
comment_lines(tok(comment, _, _, C), Lines) :-
    format(string(S), "~w", [C]),
    split_string(S, "\n", "", Ls0),
    maplist([L0, L]>>( split_string(L0, "", " \t\r*", [L1]), strip_percent(L1, L) ), Ls0, Ls1),
    trim_empty_ends(Ls1, Lines).

strip_percent(L0, L) :-
    (   ( sub_string(L0, 0, 1, _, "%") ; sub_string(L0, 0, 1, _, "#") ) -> sub_string(L0, 1, _, 0, L1), strip_percent(L1, L)
    ;   split_string(L0, "", " \t", [L])
    ).

trim_empty_ends(Ls0, Ls) :-
    exclude_leading_empty(Ls0, Ls1), reverse(Ls1, R1),
    exclude_leading_empty(R1, R2), reverse(R2, Ls).
exclude_leading_empty([""|Ls], Out) :- !, exclude_leading_empty(Ls, Out).
exclude_leading_empty(Ls, Ls).

notice_line(Line) :-
    string_lower(Line, Lower),
    kw_synonym_words(notice_start, Phrase0),
    atomic_list_concat(Phrase0, ' ', P0),
    downcase_atom(P0, P),
    sub_string(Lower, 0, _, After, P),
    (   After =:= 0 -> true
    ;   sub_string(Lower, _, After, 0, Rest), sub_string(Rest, 0, 1, _, C),
        \+ char_type(C, alnum)
    ), !.

comment_blocks(CommentToks, NoticeStarts, Blocks) :-
    findall(_{type: comment, start: S, text: T},
            ( member(tok(comment, S, E, C), CommentToks),
              \+ memberchk(S, NoticeStarts),
              comment_lines(tok(comment, S, E, C), Ls), Ls \== [],
              atomic_list_concat(Ls, '\n', TA), atom_string(TA, T) ),
            Blocks).

merge_by_start(As, Bs, Out) :-
    append(As, Bs, All),
    map_list_to_pairs([B, S]>>get_dict(start, B, S), All, Ps),
    keysort(Ps, Sorted),
    pairs_values(Sorted, Out).

		 /*******************************
		 *       LINES AND COLUMNS      *
		 *******************************/

line_starts(Text, Starts) :-
    string_codes(Text, Cs),
    line_starts_(Cs, 0, Os),
    Starts =.. [s, 0|Os].

line_starts_([], _, []).
line_starts_([0'\n|Cs], I, [I1|Os]) :- !, I1 is I + 1, line_starts_(Cs, I1, Os).
line_starts_([_|Cs], I, Os) :- I1 is I + 1, line_starts_(Cs, I1, Os).

line_of(Starts, Offset, Line) :-
    functor(Starts, _, N),
    line_search(Starts, Offset, 1, N, Line).
line_search(Starts, Offset, Lo, Hi, Line) :-
    (   Lo >= Hi -> Line = Lo
    ;   Mid is (Lo + Hi + 1) // 2, arg(Mid, Starts, S),
        (   S =< Offset -> line_search(Starts, Offset, Mid, Hi, Line)
        ;   Hi1 is Mid - 1, line_search(Starts, Offset, Lo, Hi1, Line)
        )
    ).

%   The column of an offset, a tab counting four.
column_of(Text, Starts, Offset, Col) :-
    line_of(Starts, Offset, Line), arg(Line, Starts, LS),
    L is Offset - LS, sub_string(Text, LS, L, _, Prefix),
    string_codes(Prefix, Cs),
    foldl([C, A0, A]>>( C == 0'\t -> A is (A0 // 4 + 1) * 4 ; A is A0 + 1 ), Cs, 0, Col).

		 /*******************************
		 *    FROM UNITS TO BLOCKS      *
		 *******************************/

%   unit_blocks(+Units, +Ctx, -Blocks): headings, statements and tables, with
%   their segments; the numbers and the links come after (number_blocks/4,
%   link_blocks/4). A statement keeps `start`, `uses` ([F/A-Start]) and
%   `defines` ([F/A]) for those.
unit_blocks(Units, Ctx, Blocks) :-
    unit_blocks_(Units, Ctx, top, none, Blocks).

unit_blocks_([], _, _, _, []).
unit_blocks_([u(header(label), S, E, Toks)|Us], Ctx, Sec, _, Blocks) :- !,
    segs_of_label(Toks, Ctx, Segs),
    unit_blocks_(Us, Ctx, Sec, label(S, E, Segs), Blocks).
unit_blocks_([u(header((table)), S, E, Toks)|Us], Ctx, Sec, Label, [B|Blocks]) :- !,
    take_rows(Us, Rows, Rest),
    table_block(S, E, Toks, Rows, Ctx, Label, B),
    unit_blocks_(Rest, Ctx, Sec, none, Blocks).
unit_blocks_([u(header(K), S, E, Toks)|Us], Ctx, _Sec, _, [B|Blocks]) :- !,
    heading_block(K, S, E, Toks, Ctx, B),
    unit_blocks_(Us, Ctx, K, none, Blocks).
unit_blocks_([u(row, S, E, Toks)|Us], Ctx, Sec, Label, Blocks) :- !,
    unit_blocks_([u(statement, S, E, Toks)|Us], Ctx, Sec, Label, Blocks).
unit_blocks_([u(statement, S, E, Toks)|Us], Ctx, Sec, Label, [B|Blocks]) :-
    statement_block(Sec, S, E, Toks, Ctx, Label, B),
    unit_blocks_(Us, Ctx, Sec, none, Blocks).

take_rows([u(row, S, E, T)|Us], [row(S, E, T)|Rows], Rest) :- !, take_rows(Us, Rows, Rest).
take_rows(Us, [], Us).

heading_block(K, S, _E, Toks, Ctx, B) :-
    kind_key(K, KindKey),
    heading_level(K, Level),
    header_name(K, Toks, Name),
    ui(KindKey, KindText),
    (   Name == "" -> Text = KindText
    ;   format(string(Text), "~w: ~w", [KindText, Name])
    ),
    plain_segs(Toks, Ctx, Segs),
    format(atom(Anchor), "h~w", [S]),
    B = _{type: heading, start: S, level: Level, anchor: Anchor, kind: KindKey,
          text: Text, source: Segs}.

heading_level(section, 3) :- !.
heading_level(cells, 3) :- !.
heading_level(_, 2).

kind_key(kb, heading_kb).
kind_key(resources, heading_resources).
kind_key(services, heading_services).
kind_key(scenario, heading_scenario).
kind_key(query, heading_query).
kind_key(ontology, heading_ontology).
kind_key(templates(template), heading_templates).
kind_key(templates(fluent), heading_fluents).
kind_key(templates(event), heading_events).
kind_key(templates(action), heading_actions).
kind_key(templates(constant), heading_constants).
kind_key(templates(function), heading_functions).
kind_key((table), heading_table).
kind_key(view, heading_view).
kind_key(cells, heading_cells).
kind_key(section, heading_section).
kind_key(label, heading_section).
kind_key(other, heading_other).

%   The name a header gives: its words after the opening phrase, up to the
%   phrase that closes it (`is`, `includes`, `are`, ...) or a comma.
header_name(K, _, "") :-
    ( K = templates(_) ; K == ontology ; K == other ), !.
header_name(K, Toks, Name) :-
    word_toks(Toks, Ws),
    words_of(Toks, Words),
    (   opening_key(K, Key), kw_synonym_words(Key, P0), maplist(lower_word, P0, P),
        append(P, _, Words)
    ->  length(P, NP)
    ;   NP = 0
    ),
    length(Pre, NP), append(Pre, After, Ws), !,
    take_name(After, NameToks),
    findall(W, ( member(tok(_, _, _, W0), NameToks), format(atom(W), "~w", [W0]) ), Wl),
    atomic_list_concat(Wl, ' ', NA), atom_string(NA, Name).
header_name(_, _, "").

word_toks(Ts, Ws) :- include([tok(T, _, _, _)]>>memberchk(T, [word, num]), Ts, Ws).

opening_key(kb, kb_open).
opening_key(resources, kb_open).
opening_key(services, kb_open).
opening_key(scenario, scenario).
opening_key(query, query).
opening_key((table), table_open).
opening_key(view, view_open).
opening_key(cells, cells_open).
opening_key(section, marker).

take_name([], []).
take_name([tok(word, _, _, W)|_], []) :-
    lower_word(W, L),
    memberchk(L, [is, includes, are, extends, states, é, inclui, são, es, incluye, son, est, comprend, sont, è, comprende, sono]), !.
take_name([T|Ts], [T|Ns]) :- take_name(Ts, Ns).

%   A statement: its kind (from what the loaded program made of it, else the
%   section it is in), its lines of segments, and what it defines and uses.
statement_block(Sec, S, E, Toks, Ctx, Label, B) :-
    Ctx = ctx(_, _, _, _, _, Elements, _, _, _, _),
    (   Label = label(LS, _, LabelSegs) -> true ; LS = S, LabelSegs = [] ),
    (   ( member(el(S, _, K0), Elements) ; member(el(LS, _, K0), Elements) ),
        \+ K0 = kb(_), \+ K0 = scenario(_), \+ K0 = query(_), \+ K0 = ontology
    ->  ElKind = K0
    ;   ElKind = none
    ),
    statement_kind(Sec, ElKind, Toks, Kind),
    (   Sec = templates(_)
    ->  template_classes(Toks, Classes), Uses = [],
        ( ElKind = template(FA) -> Defines = [], Declares = [FA] ; Defines = [], Declares = [] )
    ;   ( ElKind = clause(_, _, _, Allowed) -> true ; Allowed = any ),
        statement_classes(S, E, Toks, Ctx, Allowed, Classes0, Uses0),
        defines_of(ElKind, Defines),
        head_use(Defines, Uses0, Uses, HeadStart),
        mark_head(HeadStart, Toks, Classes0, Classes),
        Declares = []
    ),
    lines_of(Toks, Classes, Ctx, Lines0),
    (   Sec == resources -> maplist(resource_line(Ctx), Lines0, Lines) ; Lines = Lines0 ),
    format(atom(Anchor), "s~w", [S]),
    B = _{type: statement, start: S, anchor: Anchor, kind: Kind, label: LabelSegs,
          lines: Lines, uses: Uses, defines: Defines, declares: Declares}.

%   A line of `includes these resources:` names a resource: the name links
%   to the resource's own readable document (an example of the server), or
%   to the resource itself (a web address).
resource_line(Ctx, L0, L) :-
    Ctx = ctx(_, _, _, _, _, _, _, _, LinkBase, _),
    findall(T, ( member(S, L0.segs), get_dict(text, S, T) ), Ts),
    atomic_list_concat(Ts, '', A0),
    normalize_space(atom(A1), A0),
    (   sub_atom(A1, _, 1, 0, C), memberchk(C, [',', '.']) -> sub_atom(A1, 0, _, 1, R0) ; R0 = A1 ),
    normalize_space(atom(R), R0),
    (   R \== '', resource_link(R, LinkBase, URL)
    ->  ( sub_atom(A1, _, 1, 0, P), memberchk(P, [',', '.']) -> atom_string(P, PS), Tail = [_{class: o, text: PS, pred: -}] ; Tail = [] ),
        atom_string(R, RS),
        L = L0.put(segs, [_{class: r, text: RS, pred: -, link: URL}|Tail])
    ;   L = L0
    ).

resource_link(R, LinkBase, URL) :-
    (   nb_current(le_readable_base, Base0), Base0 \== (-) -> Base = Base0 ; working_directory(Base, Base) ),
    catch(le_kbs:resolve_resource(R, Base, Kind, Id), _, fail),
    (   Kind = le_url(U) -> atom_string(U, URL)
    ;   Kind = pl_url(U) -> atom_string(U, URL)
    ;   LinkBase \== none,
        catch(le_kbs:example_name_for_file(Id, Example), _, fail)
    ->  format(string(URL), "~w/readable/~w?format=html", [LinkBase, Example])
    ).

%   A rule's own head is not a use of its predicate: the first sentence of a
%   statement that defines the predicate is dropped from the uses.
head_use([], Uses, Uses, none) :- !.
head_use(Defines, Uses0, Uses, Head) :-
    (   Uses0 = [FA-HS|Rest], memberchk(FA, Defines) -> Uses = Rest, Head = FA-HS
    ;   Uses = Uses0, Head = none
    ).

%   The words of the head's template take the class h: the place where the
%   predicate is defined, shown as such and not linked to itself.
mark_head(none, _, C, C) :- !.
mark_head(FA-HS, Toks, C0, C) :-
    (   rec_span(HS, HE, FA, _, _) -> true ; HE = HS ),
    foldl({FA, HS, HE}/[tok(_, TS, _, _), A0, A]>>(
              TS >= HS, TS =< HE, get_assoc(TS, A0, c(t, FA)) -> put_assoc(TS, A0, c(h, FA), A)
          ;   A = A0 ), Toks, C0, C).

defines_of(clause(_, FA, _, _), [FA]) :- !.
defines_of(table(FA), [FA]) :- !.
defines_of(lps(K, P), FAs) :- !,
    findall(FA, ( lps_defined(K, P, L), callable(L), functor(L, F, A), FA = F/A ), FAs0),
    sort(FAs0, FAs).
defines_of(_, []).

statement_kind(templates(T), _, _, K) :- !, atom_concat(template_, T, K).
statement_kind(_, clause(fact, _, _, _), _, fact) :- !.
statement_kind(_, clause(rule, _, _, _), _, rule) :- !.
statement_kind(_, table(_), _, (table)) :- !.
statement_kind(_, lps(K, _), _, Kind) :- lps_kind(K, Kind), !.
statement_kind(_, expectation(_), _, expectation) :- !.
statement_kind(_, template(_), _, template_template) :- !.
statement_kind(_, service, _, service) :- !.
statement_kind(_, setting, _, setting) :- !.
statement_kind(Sec, _, Toks, constraint) :-
    Sec \== scenario, words_of(Toks, Ws), kw_prefix(lps_must_not, Ws), !.
statement_kind(scenario, _, _, scenario_fact) :- !.
statement_kind(query, _, _, query) :- !.
statement_kind(resources, _, _, resource) :- !.
statement_kind(services, _, _, service) :- !.
statement_kind(view, _, _, view) :- !.
statement_kind(cells, _, _, view) :- !.
statement_kind(ontology, _, _, ontology) :- !.
statement_kind(top, _, _, setting) :- !.
statement_kind(_, _, _, statement).

lps_kind(when, law).
lps_kind(head_rule, rule).
lps_kind(if, reactive).
lps_kind(denial, constraint).
lps_kind(initially, initially).
lps_kind(goal, goal).
lps_kind(setting, setting).
lps_kind(observation, scenario_fact).
lps_kind(_, statement).

		 /*******************************
		 *     THE CLASS OF EACH WORD   *
		 *******************************/

%   Classes: an assoc from a token's start offset to c(Class, Pred), Pred a
%   predicate F/A for a word of a template (the link to its definition) or -.

%   In a declaration: the places between asterisks, the template's own
%   words, and the additions after `;`.
template_classes(Toks, Classes) :-
    template_classes_(Toks, out, Pairs),
    list_to_assoc(Pairs, Classes).

template_classes_([], _, []).
template_classes_([tok(punct, S, _, '*')|Ts], out, [S-c(hide, -)|Ps]) :- !,
    template_classes_(Ts, in, Ps).
template_classes_([tok(punct, S, _, '*')|Ts], in, [S-c(hide, -)|Ps]) :- !,
    template_classes_(Ts, out, Ps).
template_classes_([tok(_, S, _, _)|Ts], in, [S-c(p, -)|Ps]) :- !,
    template_classes_(Ts, in, Ps).
template_classes_([tok(punct, S, _, ';')|Ts], _, [S-c(o, -)|Ps]) :- !,
    addition_classes(Ts, Ps).
template_classes_([tok(punct, S, _, _)|Ts], out, [S-c(o, -)|Ps]) :- !,
    template_classes_(Ts, out, Ps).
template_classes_([tok(_, S, _, _)|Ts], out, [S-c(d, -)|Ps]) :-
    template_classes_(Ts, out, Ps).

addition_classes(Ts, Ps) :-
    keyword_classes(Ts, Ps0),
    findall(S-C, ( member(S-C0, Ps0), ( C0 = c(o, -) -> C = c(o, -) ; C = C0 ) ), Ps).

%   In a statement: the sentences the grammar matched (rec_span/5), each
%   word aligned with the template's words; the rest by keyword.
statement_classes(S, E, Toks, Ctx, Allowed, Classes, Uses) :-
    Ctx = ctx(_, Len, M, _, _, _, _, _, _, _),
    findall(span(SS, SE, FA, Skel, Starts),
            ( rec_span(SS, SE, FA, Skel, Starts), SS >= S, SE =< E, SS < Len ),
            Spans00),
    reverse(Spans00, Spans0),
    last_readings(Spans0, Spans1),
    exclude(unknown_predicate(M), Spans1, Spans2a),
    (   Allowed == any -> Spans2 = Spans2a
    ;   include({Allowed}/[span(_, _, FA, _, _)]>>memberchk(FA, Allowed), Spans2a, Spans2b),
        ( Spans2b == [] -> Spans2 = Spans2a ; Spans2 = Spans2b )
    ),
    drop_crossing(Spans2, Spans),
    sort_by_length_desc(Spans, ByLen),
    keyword_classes(Toks, KPairs),
    list_to_assoc(KPairs, K0),
    foldl(apply_span(Toks), ByLen, K0, Classes1),
    meta_spans(Toks, Classes1, Ctx, MSpans),
    sort_by_length_desc(MSpans, MByLen),
    foldl(apply_span(Toks), MByLen, Classes1, Classes2),
    unmeta(Classes2, Classes),
    append(Spans, MSpans, AllSpans),
    findall(FA-SS, ( member(span(SS, _, FA, _, _), AllSpans), \+ system_pred(M, FA) ), Uses0),
    sort(2, @=<, Uses0, Uses).

%   A sentence inside a sentence (`*a person* says that *a sentence*`): the
%   grammar matched the inner one without telling the hook, so its words are
%   matched again here, with the program's templates.
meta_spans(Toks, Classes, Ctx, Spans) :-
    Ctx = ctx(_, Len, M, _, _, _, _, _, _, Raw),
    meta_runs(Toks, Classes, Runs),
    (   Runs == [] -> Spans = []
    ;   catch(le_kbs:prepared_templates(M, Templates), _, fail)
    ->  findall(Sp,
                ( member(RS-RE, Runs),
                  include({RS, RE}/[T]>>( has_loc(T), tok_loc(T, TS, TE), TS >= RS, TE =< RE ), Raw, RT),
                  RT \== [],
                  setup_call_cleanup(assertz(recording),
                      ignore(catch(once(le_grammar:parse_literal(RT, Templates, [], _, _, _)), _, true)),
                      retractall(recording)),
                  rec_span(SS, SE, FA, Sk, St), SS >= RS, SE =< RE, SS < Len,
                  \+ unknown_predicate(M, span(SS, SE, FA, Sk, St)),
                  Sp = span(SS, SE, FA, Sk, St) ),
                Spans0),
        sort(Spans0, Spans1), drop_crossing(Spans1, Spans)
    ;   Spans = []
    ).

meta_runs(Toks, Classes, Runs) :-
    findall(S-E, ( member(tok(T, S, E, _), Toks), T \== indent, get_assoc(S, Classes, c(m, -)) ), Ms),
    join_runs(Ms, Runs).
join_runs([], []).
join_runs([S-E|Ms], Runs) :- join_runs_(Ms, S, E, Runs).
join_runs_([], S, E, [S-E]).
join_runs_([S2-E2|Ms], S, E, Runs) :-
    (   S2 - E =< 2 -> join_runs_(Ms, S, E2, Runs)
    ;   Runs = [S-E|Rest], join_runs_(Ms, S2, E2, Rest)
    ).

unmeta(C0, C) :-
    assoc_to_list(C0, Ps0),
    maplist([K-V0, K-V]>>( V0 = c(m, P) -> V = c(o, P) ; V = V0 ), Ps0, Ps),
    list_to_assoc(Ps, C).

%   The same words may be read more than once while the grammar backtracks;
%   the last reading recorded is the one it kept. Spans: latest first.
last_readings(Spans, Out) :-
    foldl([Sp, A0-K0, A-K]>>( Sp = span(S, E, FA, _, _),
                              ( memberchk(S-E-FA, K0) -> A = A0, K = K0
                              ; A = [Sp|A0], K = [S-E-FA|K0] ) ),
          Spans, []-[], Out0-_),
    sort(Out0, Out).

unknown_predicate(M, span(_, _, F/A, _, _)) :-
    \+ ( catch(M:le_dict(D), _, fail), dict_fa(D, F/A) ),
    \+ memberchk(F/A, [is_a/2]).

%   A system template (comparisons, arithmetic) has no definition to link to.
system_pred(M, F/A) :-
    \+ ( catch(M:le_source_info(Ref, _, _, template), _, fail),
         catch(clause(M:le_dict(D), true, Ref), _, fail),
         dict_fa(D, F/A) ).

%   Two sentences found by the grammar cannot cross: one that starts inside
%   another and ends after it was a reading the grammar tried and dropped.
%   Identical spans are kept once.
drop_crossing(Spans, Kept) :-
    drop_dups(Spans, Spans1),
    sort_by_length_desc(Spans1, ByLen),
    foldl(keep_unless_crossing, ByLen, [], Kept0),
    sort(Kept0, Kept).

drop_dups([], []).
drop_dups([X], [X]) :- !.
drop_dups([X, Y|Xs], Out) :-
    X = span(S, E, FA, _, _), Y = span(S, E, FA, _, _), !,
    drop_dups([X|Xs], Out).
drop_dups([X|Xs], [X|Out]) :- drop_dups(Xs, Out).

keep_unless_crossing(Sp, Kept, Out) :-
    Sp = span(S, E, _, _, _),
    (   member(span(S2, E2, _, _, _), Kept),
        (   S2 == S, E2 == E               % the same words read twice: keep the first
        ;   S < S2, E > S2, E < E2
        ;   S > S2, S < E2, E > E2
        )
    ->  Out = Kept
    ;   Out = [Sp|Kept]
    ).

sort_by_length_desc(Spans, Sorted) :-
    map_list_to_pairs([span(S, E, _, _, _), L]>>(L is S - E), Spans, Ps),
    keysort(Ps, P1), pairs_values(P1, Sorted).

%   The words of one sentence: the template's own words take the class t and
%   the link; the places take v (a variable), c (a value) or o (a sentence
%   inside a sentence, which keeps the classes of its own words).
apply_span(Toks, span(S, E, FA, Skel, _), C0, C) :-
    include({S, E}/[tok(T, TS, TE, _)]>>(T \== indent, TS >= S, TE =< E), Toks, SToks),
    align(Skel, SToks, FA, Pairs),
    foldl([TS-Cl, A0, A]>>( Cl = c(o, -), get_assoc(TS, A0, Old), Old \= c(k, -) -> A = A0
                          ; put_assoc(TS, A0, Cl, A) ),
          Pairs, C0, C).

align(_, [], _, []) :- !.
align([], Ts, _, Ps) :- !,
    findall(S-c(o, -), member(tok(_, S, _, _), Ts), Ps).
align([w(W)|Sk], [T|Ts], FA, [S-c(t, FA)|Ps]) :-
    T = tok(_, S, _, V), same_word(V, W), !,
    align(Sk, Ts, FA, Ps).
align([w(_)|Sk], Ts, FA, Ps) :- !,
    align(Sk, Ts, FA, Ps).
align([A|Sk], Ts, FA, Ps) :-
    (   member(w(NW), Sk) -> true ; NW = '$none' ),
    take_arg(Ts, NW, ArgToks, Rest),
    arg_class(A, ArgToks, Cl),
    findall(S-Cl1, ( member(tok(Ty, S, _, _), ArgToks), tok_class(Ty, Cl, Cl1) ), Ps0),
    align(Sk, Rest, FA, Ps1),
    append(Ps0, Ps1, Ps).

%   An argument is at least one word, up to the next word of the template.
take_arg([T|Ts], NW, [T|As], Rest) :- take_arg_(Ts, NW, As, Rest).
take_arg_([], _, [], []).
take_arg_([T|Ts], NW, [], [T|Ts]) :- T = tok(_, _, _, V), same_word(V, NW), !.
take_arg_([T|Ts], NW, [T|As], Rest) :- take_arg_(Ts, NW, As, Rest).

arg_class(v, _, c(v, -)).
arg_class(c, _, c(c, -)).
arg_class(m, _, c(m, -)).

tok_class(num, c(c, -), c(n, -)) :- !.
tok_class(str, c(c, -), c(s, -)) :- !.
tok_class(_, C, C).

same_word(V, W) :-
    (   V == W -> true
    ;   lower_word(V, LV), lower_word(W, LW), LV == LW
    ).

%   The words outside sentences: the phrases of Logical English (longest
%   first) are keywords; a time after `at`, `from` or `to` (LPS) is a
%   variable; numbers and quoted texts are values; the rest is plain.
keyword_classes(Toks, Pairs) :-
    keyword_phrases(Phrases),
    exclude([tok(T, _, _, _)]>>(T == indent), Toks, Ts),
    kw_classes(Ts, Phrases, none, Pairs).

kw_classes([], _, _, []).
kw_classes([tok(punct, S, _, _)|Ts], Ph, _, [S-c(o, -)|Ps]) :- !, kw_classes(Ts, Ph, none, Ps).
kw_classes([tok(num, S, _, _)|Ts], Ph, _, [S-c(n, -)|Ps]) :- !, kw_classes(Ts, Ph, none, Ps).
kw_classes([tok(str, S, _, _)|Ts], Ph, _, [S-c(s, -)|Ps]) :- !, kw_classes(Ts, Ph, none, Ps).
kw_classes(Ts, Ph, _, Ps) :-
    member(Phrase-Key, Ph),
    length(Phrase, N), length(Pre, N), append(Pre, Rest, Ts),
    maplist([tok(word, _, _, V), W]>>same_word(V, W), Pre, Phrase), !,
    findall(S-c(k, -), member(tok(_, S, _, _), Pre), P0),
    ( memberchk(Key, [lps_at, lps_from, lps_to]) -> After = time ; After = none ),
    kw_classes(Rest, Ph, After, P1),
    append(P0, P1, Ps).
kw_classes([tok(_, S, _, _)|Ts], Ph, After, [S-C|Ps]) :-
    ( After == time -> C = c(v, -) ; C = c(o, -) ),
    kw_classes(Ts, Ph, After, Ps).

%   Every phrase of the keyword categories, longest first. The word classes
%   (articles, copulas, ...) are not keywords.
keyword_phrases(Phrases) :-
    le_active_language(Lang),
    (   nb_current(le_readable_phrases, Lang-Cached) -> Phrases = Cached
    ;   findall(NL-(P-Key),
                ( kw_category_key(Cat, Key),
                  \+ memberchk(Cat, [class, isa, notice, constant, answer]),
                  kw_synonym_words(Key, P0), maplist(lower_word, P0, P),
                  length(P, L), NL is -L ),
                Ps0),
        keysort(Ps0, Ps1), pairs_values(Ps1, Phrases),
        nb_setval(le_readable_phrases, Lang-Phrases)
    ).

segs_of_label(Toks, Ctx, Segs) :-
    plain_segs(Toks, Ctx, Segs).

plain_segs(Toks, Ctx, Segs) :-
    keyword_classes(Toks, Pairs), list_to_assoc(Pairs, A),
    lines_of(Toks, A, Ctx, Lines),
    findall(Ss, ( nth1(I, Lines, L), ( I > 1 -> Ss = [_{class: o, text: " ", pred: -}|L.segs] ; Ss = L.segs ) ), SsL),
    append(SsL, Segs0),
    merge_segs(Segs0, Segs).

%   lines_of(+Toks, +Classes, +Ctx, -Lines): the statement's lines, each with
%   its depth of indentation (0 for the statement's own margin) and its
%   segments; a word's text is the source's, and the space between two
%   words is one space when the source has any.
lines_of(Toks0, Classes, Ctx, Lines) :-
    Ctx = ctx(Text, _, _, _, Starts, _, _, _, _, _),
    exclude([tok(T, _, _, _)]>>(T == indent), Toks0, Toks),
    map_list_to_pairs({Starts}/[tok(_, S, _, _), L]>>line_of(Starts, S, L), Toks, Ps),
    group_pairs_by_key(Ps, Groups),
    findall(Col, ( member(_-[tok(_, S, _, _)|_], Groups), column_of(Text, Starts, S, Col) ), Cols0),
    sort(Cols0, Cols),
    findall(_{indent: D, segs: Segs},
            ( member(_-LToks, Groups), LToks = [tok(_, S0, _, _)|_],
              column_of(Text, Starts, S0, Col), nth0(D, Cols, Col),
              line_segs(LToks, Classes, Text, Segs) ),
            Lines).

line_segs(Toks, Classes, Text, Segs) :-
    line_segs_(Toks, Classes, Text, none, Segs0),
    merge_segs(Segs0, Segs).

line_segs_([], _, _, _, []).
line_segs_([tok(_, S, E, _)|Ts], Classes, Text, PrevEnd, Segs) :-
    ( get_assoc(S, Classes, c(Cl, P)) -> true ; Cl = o, P = (-) ),
    L is E - S, sub_string(Text, S, L, _, W),
    (   PrevEnd == none -> Sp = ""
    ;   G is S - PrevEnd, G > 0 -> Sp = " "
    ;   Sp = ""
    ),
    (   Cl == hide
    ->  Segs = Rest0, ( Sp == "" -> Rest0 = Rest ; Rest0 = [_{class: o, text: Sp, pred: -}|Rest] )
    ;   Sp == "" -> Segs = [_{class: Cl, text: W, pred: P}|Rest]
    ;   Segs = [_{class: o, text: Sp, pred: -}, _{class: Cl, text: W, pred: P}|Rest]
    ),
    line_segs_(Ts, Classes, Text, E, Rest).

%   Neighbouring segments of the same class and link become one (a space
%   between two words of a template stays inside the template's segment).
merge_segs([], []).
merge_segs([A, B, C|Rest], Out) :-
    B.class == o, B.text == " ", A.class == C.class, A.pred == C.pred, A.class \== o, !,
    string_concat(A.text, " ", T1), string_concat(T1, C.text, T),
    merge_segs([A.put(text, T)|Rest], Out).
merge_segs([A, B|Rest], Out) :-
    A.class == B.class, A.pred == B.pred, !,
    string_concat(A.text, B.text, T),
    merge_segs([A.put(text, T)|Rest], Out).
merge_segs([A|Rest], [A|Out]) :- merge_segs(Rest, Out).

		 /*******************************
		 *        DECISION TABLES       *
		 *******************************/

table_block(S, _E, Toks, Rows, Ctx, Label, B) :-
    Ctx = ctx(Text, _, _, _, _, Elements, _, _, _, _),
    plain_segs(Toks, Ctx, HSegs),
    (   Label = label(_, _, LabelSegs) -> true ; LabelSegs = [] ),
    findall(Cells, ( member(row(_, _, RT), Rows), row_cells(RT, Text, Cells) ), CellRows),
    (   member(el(ES, _, table(FA)), Elements), ES >= S,
        ( Rows = [row(_, RE, _)|_] -> true ; RE = ES ), ES =< RE + 1
    ->  Defines = [FA]
    ;   member(el(ES, _, table(FA)), Elements), ES == S -> Defines = [FA]
    ;   Defines = []
    ),
    format(atom(Anchor), "s~w", [S]),
    B = _{type: (table), start: S, anchor: Anchor, kind: (table), header: HSegs,
          label: LabelSegs, rows: CellRows, defines: Defines, uses: [], declares: []}.

row_cells(Toks, Text, Cells) :-
    exclude([tok(T, _, _, _)]>>(T == indent), Toks, Ts),
    split_cells(Ts, Groups),
    maplist({Text}/[G, C]>>( G == [] -> C = ""
                    ; G = [tok(_, S, _, _)|_], last(G, tok(_, _, E, _)),
                      L is E - S, sub_string(Text, S, L, _, C) ), Groups, Cells).

split_cells(Ts, [G|Gs]) :-
    (   append(G, [tok(punct, _, _, '|')|Rest], Ts) -> split_cells(Rest, Gs)
    ;   G = Ts, Gs = []
    ).

		 /*******************************
		 *     NUMBERS AND LINKS        *
		 *******************************/

number_blocks([], _, _, []).
number_blocks([B|Bs], N, H, [B1|Out]) :-
    (   memberchk(B.type, [statement, (table)])
    ->  B1 = B.put(n, N), N1 is N + 1, H1 = H
    ;   B1 = B, N1 = N, H1 = H
    ),
    number_blocks(Bs, N1, H1, Out).

%   link_blocks(+Blocks0, +Ctx, -Blocks, -Index): each word of a template
%   gets its link; each definition, the statements that use it; each
%   template's declaration, where it is defined and used; and the index.
link_blocks(Blocks0, Ctx, Blocks, Index) :-
    Ctx = ctx(_, Len, _, _, _, _, Templates, Defs, LinkBase, _),
    findall(FA-N, ( member(B, Blocks0), memberchk(B.type, [statement, (table)]),
                    member(FA, B.defines), N = B.n ), DefNs0),
    sort(DefNs0, DefNs),
    findall(FA-N, ( member(B, Blocks0), B.type == statement,
                    member(FA, B.declares), N = B.n ), DeclNs0),
    sort(DeclNs0, DeclNs),
    findall(FA-N, ( member(B, Blocks0), memberchk(B.type, [statement, (table)]),
                    member(FA-_, B.uses), N = B.n ), UseNs0),
    sort(UseNs0, UseNs),
    findall(FA, ( member(FA-_, DefNs) ; member(FA-_, DeclNs) ; member(FA-_, UseNs) ), FAs0),
    sort(FAs0, FAs),
    findall(FA-Target,
            ( member(FA, FAs), pred_target(FA, DefNs, DeclNs, Templates, Defs, Len, LinkBase, Target) ),
            Targets),
    list_to_assoc(Targets, TA),
    maplist(link_block(TA, DefNs, DeclNs, UseNs), Blocks0, Blocks),
    index_entries(Blocks, DefNs, DeclNs, UseNs, Index).

%   Where a link to F/A goes: the first own statement that defines it, else
%   its own declaration (an anchor of this document); else, for a predicate
%   of an included resource, that resource's document (a URL), when the
%   document knows the server's address.
pred_target(FA, DefNs, _, _, _, _, _, local(N)) :- memberchk(FA-N, DefNs), !.
pred_target(FA, _, DeclNs, _, _, _, _, local(N)) :- memberchk(FA-N, DeclNs), !.
pred_target(FA, _, _, Templates, Defs, Len, LinkBase, url(URL)) :-
    LinkBase \== none,
    (   member(def(FA, S), Defs), S >= Len
    ;   member(tmpl(FA, S), Templates), S >= Len
    ),
    catch(le_kbs:resource_range_info(S, S, Info), _, fail),
    Example = Info.resourceExample, Example \== null, !,
    pred_anchor(FA, PA),
    format(string(URL), "~w/readable/~w?format=html#~w", [LinkBase, Example, PA]).
pred_target(FA, _, _, Templates, Defs, Len, _, url(URL)) :-
    (   member(def(FA, S), Defs), S >= Len
    ;   member(tmpl(FA, S), Templates), S >= Len
    ),
    catch(le_kbs:resource_range_info(S, S, Info), _, fail),
    Path = Info.resourcePath, le_kbs:is_url(Path), !,
    atom_string(Path, URL).

pred_anchor(F/A, Anchor) :-
    atom_codes(F, Cs),
    maplist([C, D]>>( code_type(C, alnum) -> D = C ; D = 0'_ ), Cs, Ds),
    atom_codes(F1, Ds),
    format(atom(Anchor), "p-~w-~w", [F1, A]).

link_block(TA, DefNs, _DeclNs, UseNs, B0, B) :-
    (   B0.type == statement
    ->  maplist(link_line(TA), B0.lines, Lines),
        B1 = B0.put(lines, Lines)
    ;   B1 = B0
    ),
    (   memberchk(B1.type, [statement, (table)])
    ->  N = B1.n,
        findall(PA, ( get_assoc(FA, TA, local(N)), pred_anchor(FA, PA) ), Ts0),
        sort(Ts0, Targets),
        findall(_{what: used_in, pred: FA, refs: Refs},
                ( member(FA, B1.defines), get_assoc(FA, TA, local(N)),
                  findall(U, ( member(FA-U, UseNs), U \== N ), Refs0), sort(Refs0, Refs),
                  Refs \== [] ),
                X1),
        findall(_{what: also_defined_in, pred: FA, refs: Refs},
                ( member(FA, B1.defines), get_assoc(FA, TA, local(N)),
                  findall(D, ( member(FA-D, DefNs), D \== N ), Refs0), sort(Refs0, Refs),
                  Refs \== [] ),
                X2),
        findall(X, ( member(FA, B1.declares),
                     ( findall(D, member(FA-D, DefNs), Ds), Ds \== [],
                       X = _{what: defined_in, pred: FA, refs: Ds}
                     ; findall(U, member(FA-U, UseNs), Us0), sort(Us0, Us), Us \== [],
                       X = _{what: used_in, pred: FA, refs: Us} ) ),
                X3),
        append([X2, X1, X3], Xref),
        B = B1.put(_{targets: Targets, xref: Xref})
    ;   B = B1
    ).

link_line(TA, L0, L) :-
    maplist(link_seg(TA), L0.segs, Segs),
    L = L0.put(segs, Segs).

link_seg(_, S0, S) :-
    get_dict(link, S0, L), L \== "", !, S = S0.
link_seg(TA, S0, S) :-
    (   S0.class == t, S0.pred \== (-), get_assoc(S0.pred, TA, Target)
    ->  (   Target = local(N) -> format(string(Link), "#s~w", [N]) ; Target = url(Link) )
    ;   Link = ""
    ),
    S = S0.put(link, Link).

%   The index: one entry per template declared in this document, in
%   alphabetical order of its words.
index_entries(Blocks, DefNs, DeclNs, UseNs, Index) :-
    findall(Key-_{text: T, n: N, defined: Ds, used: Us},
            ( member(FA-N, DeclNs),
              member(B, Blocks), B.type == statement, B.n == N,
              decl_text(B, T),
              string_lower(T, Key),
              findall(D, member(FA-D, DefNs), Ds0), sort(Ds0, Ds),
              findall(U, member(FA-U, UseNs), Us0), sort(Us0, Us) ),
            Pairs),
    keysort(Pairs, Sorted),
    pairs_values(Sorted, Index).

decl_text(B, T) :-
    B.lines = [L|_],
    findall(X, ( member(S, L.segs), memberchk(S.class, [d, p, o]),
                 ( S.class == p -> format(string(X), "~w", [S.text]) ; X = S.text ) ),
            Xs),
    atomic_list_concat(Xs, '', TA0),
    split_string(TA0, "", " ,.;", [T0|_]),
    ( sub_string(T0, B0, _, _, ";") -> sub_string(T0, 0, B0, _, T1) ; T1 = T0 ),
    split_string(T1, "", " ", [T]).

strip_starts(Bs0, Bs) :-
    maplist([B0, B]>>( del_dict(start, B0, _, B1) -> B = B1 ; B = B0 ), Bs0, Bs).

		 /*******************************
		 *        CHROME STRINGS        *
		 *******************************/

%   ui(+Key, -Text): a string of the document's own chrome, in the
%   program's language (i18n/ui.csv, keyed by the English text).
ui(Key, Text) :-
    ui_english(Key, En),
    le_active_language(Lang),
    (   catch(ui_text(Lang, En, T0), _, fail), T0 \== '' -> true ; T0 = En ),
    format(string(Text), "~w", [T0]).

ui_english(document_untitled, "Untitled program").
ui_english(heading_kb, "Knowledge base").
ui_english(heading_resources, "Included resources").
ui_english(heading_services, "Services").
ui_english(heading_scenario, "Scenario").
ui_english(heading_query, "Query").
ui_english(heading_ontology, "Kinds of things").
ui_english(heading_templates, "Templates").
ui_english(heading_fluents, "Fluents").
ui_english(heading_events, "Events").
ui_english(heading_actions, "Actions").
ui_english(heading_constants, "Constants").
ui_english(heading_functions, "Functions").
ui_english(heading_table, "Decision table").
ui_english(heading_view, "View").
ui_english(heading_cells, "Cells of a service").
ui_english(heading_section, "Section").
ui_english(heading_other, "Section").
ui_english(subtitle_prolog, "A program in Logical English").
ui_english(subtitle_lps, "A program in Logical English for LPS (Logic Production System)").
ui_english(contents, "Contents").
ui_english(notices, "Notices").
ui_english(index, "Index of templates").
ui_english(index_intro, "Each template of the program, with the number of the statement that declares it, the statements that define it, and the statements that use it.").
ui_english(declared, "declared in").
ui_english(defined_in, "defined in").
ui_english(also_defined_in, "also defined in").
ui_english(used_in, "used in").
ui_english(not_defined, "not defined by a rule").
ui_english(generated, "Made from {name} on {date}.").
ui_english(no_comments, "The comments of the program are not shown.").
ui_english(with_comments, "The comments of the program are shown in grey.").
ui_english(style, "Style").
ui_english(style_plain, "Plain").
ui_english(style_compact, "Compact").
ui_english(style_legal, "Legal").
ui_english(style_cute, "Colourful").
ui_english(style_editor, "Editor colours").
ui_english(print, "Print or save as PDF").
ui_english(legend, "How to read this document").
ui_english(legend_text, "This document is the program, word for word. Each numbered statement is one statement of the program.").
ui_english(legend_k, "Words of Logical English itself, such as if, and, or").
ui_english(legend_h, "The words of a template where a rule or a fact defines it").
ui_english(legend_t, "The words of a template: select them to go to where the sentence is defined").
ui_english(legend_v, "A variable: it stands for any thing of its kind").
ui_english(legend_c, "A value: one fixed thing, number or text").
ui_english(legend_p, "A place of a template, which a sentence fills").
ui_english(kind_template_template, "Template").
ui_english(kind_template_fluent, "Fluent").
ui_english(kind_template_event, "Event").
ui_english(kind_template_action, "Action").
ui_english(kind_template_constant, "Constant").
ui_english(kind_template_function, "Function").
ui_english(kind_rule, "Rule").
ui_english(kind_fact, "Fact").
ui_english(kind_table, "Decision table").
ui_english(kind_law, "Causal law").
ui_english(kind_reactive, "Reactive rule").
ui_english(kind_constraint, "Constraint").
ui_english(kind_initially, "Initial state").
ui_english(kind_goal, "Goal").
ui_english(kind_setting, "Setting").
ui_english(kind_expectation, "Expected answers").
ui_english(kind_scenario_fact, "Fact of the scenario").
ui_english(kind_query, "Query").
ui_english(kind_resource, "Included resource").
ui_english(kind_service, "Service").
ui_english(kind_view, "Sentence of a view").
ui_english(kind_ontology, "Kind of thing").
ui_english(kind_statement, "Statement").
ui_english(comment, "Comment").

kind_text(Kind, Text) :-
    atom_concat(kind_, Kind, Key),
    (   ui_english(Key, _) -> ui(Key, Text) ; ui(kind_statement, Text) ).

		 /*******************************
		 *           MARKDOWN           *
		 *******************************/

md_document(Doc, Content) :-
    with_output_to(string(Content), md_write(Doc)).

md_write(Doc) :-
    format("# ~w~n~n", [Doc.title]),
    subtitle(Doc, Sub), format("*~w*~n~n", [Sub]),
    made_from(Doc, Made), format("~w~n~n", [Made]),
    (   Doc.notices \== []
    ->  ui(notices, NT), format("> **~w**~n>~n", [NT]),
        forall(member(N, Doc.notices),
               ( split_string(N, "\n", "", NLs),
                 forall(member(NL, NLs), ( md_escape(NL, E), format("> ~w  ~n", [E]) )),
                 format(">~n") )),
        nl
    ;   true
    ),
    ui(contents, CT), format("## ~w~n~n", [CT]),
    forall(member(H, Doc.headings),
           ( Ind is (H.level - 2) * 2, tab(Ind),
             md_escape(H.text, HE), format("- [~w](#~w)~n", [HE, H.anchor]) )),
    ui(index, IT), format("- [~w](#index)~n~n", [IT]),
    forall(member(B, Doc.blocks), md_block(B)),
    md_index(Doc).

md_block(B) :- B.type == heading, !,
    format("<a id=\"~w\"></a>~n~n", [B.anchor]),
    ( B.level =:= 2 -> H = "##" ; H = "###" ),
    md_escape(B.text, T),
    format("~w ~w~n~n", [H, T]),
    md_source_segs(B.source, SS), format("~w~n~n", [SS]).
md_block(B) :- B.type == comment, !,
    split_string(B.text, "\n", "", Ls),
    forall(member(L, Ls), ( md_escape(L, E), format("> *~w*  ~n", [E]) )),
    nl.
md_block(B) :- B.type == (table), !,
    md_anchors(B),
    md_label(B),
    md_segs(B.header, HS), format("**~w.** ~w~n~n", [B.n, HS]),
    (   B.rows = [Head|Rows]
    ->  md_row(Head),
        length(Head, NC), findall("---", between(1, NC, _), Dashes), md_row(Dashes),
        forall(member(R, Rows), md_row(R))
    ;   true
    ),
    nl, md_xref(B).
md_block(B) :-
    md_anchors(B),
    md_label(B),
    B.lines = [First|Rest],
    md_segs(First.segs, FS),
    format("**~w.** ~w", [B.n, FS]),
    forall(member(L, Rest),
           ( md_segs(L.segs, LS), Ems is L.indent + 1, format("  ~n"),
             forall(between(1, Ems, _), format("&emsp;")), format("~w", [LS]) )),
    format("~n~n"),
    md_xref(B).

md_anchors(B) :-
    format("<a id=\"s~w\"></a>", [B.n]),
    forall(member(T, B.targets), format("<a id=\"~w\"></a>", [T])),
    nl.

md_label(B) :-
    (   B.label \== [] -> md_segs(B.label, LS), format("~w  ~n", [LS]) ; true ).

md_row(Cells) :-
    maplist([C, E]>>( md_escape(C, E0), E = E0 ), Cells, Es),
    atomic_list_concat(Es, ' | ', Row),
    format("| ~w |~n", [Row]).

md_xref(B) :-
    (   B.xref == [] -> true
    ;   findall(X, ( member(R, B.xref), xref_md(R, X) ), Xs),
        atomic_list_concat(Xs, '; ', XA),
        format("<small>~w</small>~n~n", [XA])
    ).

xref_md(R, X) :-
    ui(R.what, W),
    findall(L, ( member(N, R.refs), format(string(L), "[~w](#s~w)", [N, N]) ), Ls),
    atomic_list_concat(Ls, ', ', LA),
    format(string(X), "~w ~w", [W, LA]).

md_index(Doc) :-
    format("<a id=\"index\"></a>~n~n"),
    ui(index, IT), format("## ~w~n~n", [IT]),
    ui(index_intro, II), format("~w~n~n", [II]),
    ui(declared, Dc), ui(defined_in, Df), ui(used_in, Us), ui(not_defined, ND),
    forall(member(E, Doc.index),
           ( md_escape(E.text, T),
             format("- **~w** — ~w [~w](#s~w)", [T, Dc, E.n, E.n]),
             (   E.defined == [] -> format("; ~w", [ND])
             ;   md_refs(E.defined, DR), format("; ~w ~w", [Df, DR])
             ),
             (   E.used == [] -> true ; md_refs(E.used, UR), format("; ~w ~w", [Us, UR]) ),
             nl )),
    nl.

md_refs(Ns, Text) :-
    findall(L, ( member(N, Ns), format(string(L), "[~w](#s~w)", [N, N]) ), Ls),
    atomic_list_concat(Ls, ', ', A), atom_string(A, Text).

md_segs(Segs, Text) :-
    findall(X, ( member(S, Segs), md_seg(S, X) ), Xs),
    atomic_list_concat(Xs, '', A), atom_string(A, Text).

md_source_segs(Segs, Text) :-
    findall(X, ( member(S, Segs), md_seg(S, X) ), Xs),
    atomic_list_concat(Xs, '', A), atom_string(A, Text).

md_seg(S, X) :-
    md_escape(S.text, E),
    (   get_dict(link, S, L), L \== "" -> format(string(X), "[~w](~w)", [E, L])
    ;   memberchk(S.class, [k, h, d]) -> ( E == "" -> X = E ; format(string(X), "**~w**", [E]) )
    ;   S.class == v -> format(string(X), "*~w*", [E])
    ;   S.class == p -> format(string(X), "*~w*", [E])
    ;   X = E
    ).

md_escape(S0, S) :-
    format(string(S1), "~w", [S0]),
    string_codes(S1, Cs),
    foldl([C, A0, A]>>( memberchk(C, `\\*_[]<>#|\``) -> A = [C, 0'\\|A0] ; A = [C|A0] ), Cs, [], R),
    reverse(R, Out), string_codes(S, Out).

subtitle(Doc, Sub) :-
    ( Doc.target == lps -> ui(subtitle_lps, Sub) ; ui(subtitle_prolog, Sub) ).

made_from(Doc, Text) :-
    ui(generated, G0),
    (   Doc.name \== "" -> Name = Doc.name ; Name = Doc.title ),
    fill(G0, "{name}", Name, G1), fill(G1, "{date}", Doc.date, G),
    (   Doc.comments == true -> ui(with_comments, C) ; ui(no_comments, C) ),
    format(string(Text), "~w ~w", [G, C]).

fill(S0, Key, Value, S) :-
    format(string(V), "~w", [Value]),
    (   sub_string(S0, B, L, A, Key)
    ->  sub_string(S0, 0, B, _, Pre), sub_string(S0, _, A, 0, Post), ignore(L = _),
        string_concat(Pre, V, S1), string_concat(S1, Post, S)
    ;   S = S0
    ).

		 /*******************************
		 *             HTML             *
		 *******************************/

html_document(Doc, Opts, Content) :-
    with_output_to(string(Content), html_write(Doc, Opts)).

html_write(Doc, Opts) :-
    html_escape(Doc.title, T),
    format("<!DOCTYPE html>~n<html lang=\"~w\">~n<head>~n<meta charset=\"utf-8\">~n", [Doc.lang]),
    format("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">~n"),
    format("<title>~w</title>~n<style>~n", [T]),
    css(CSS), format("~w", [CSS]),
    format("</style>~n</head>~n"),
    ( memberchk(autoprint(true), Opts) -> AP = " data-autoprint=\"1\"" ; AP = "" ),
    format("<body class=\"rd style-~w\" data-default-style=\"~w\"~w>~n", [Doc.style, Doc.style, AP]),
    html_style_menu(Doc),
    format("<div class=\"page\">~n<header class=\"top\">~n<h1>~w</h1>~n", [T]),
    subtitle(Doc, Sub), html_escape(Sub, SubE),
    format("<p class=\"subtitle\">~w</p>~n", [SubE]),
    made_from(Doc, Made), html_escape(Made, MadeE),
    format("<p class=\"made\">~w</p>~n", [MadeE]),
    html_notices(Doc),
    format("</header>~n"),
    html_contents(Doc),
    html_legend,
    format("<main>~n"),
    forall(member(B, Doc.blocks), html_block(B)),
    format("</main>~n"),
    html_index(Doc),
    html_footer(Doc),
    format("</div>~n"),
    script(JS), format("<script>~n~w</script>~n", [JS]),
    format("</body>~n</html>~n").

html_style_menu(Doc) :-
    ui(style, ST), ui(print, PT),
    format("<nav class=\"bar\" aria-label=\"~w\"><button type=\"button\" class=\"bar-btn\" id=\"rd-style-btn\" aria-haspopup=\"true\" aria-expanded=\"false\">~w ▾</button>", [ST, ST]),
    format("<ul class=\"menu\" id=\"rd-style-menu\" role=\"menu\" hidden>"),
    readable_styles(Styles),
    forall(member(S, Styles),
           ( atom_concat(style_, S, K), ui(K, Name), html_escape(Name, NE),
             ( S == Doc.style -> Cur = " aria-checked=\"true\"" ; Cur = " aria-checked=\"false\"" ),
             format("<li role=\"menuitemradio\"~w data-style=\"~w\" tabindex=\"0\">~w</li>", [Cur, S, NE]) )),
    format("</ul><button type=\"button\" class=\"bar-btn\" id=\"rd-print\">~w</button></nav>~n", [PT]).

html_notices(Doc) :-
    (   Doc.notices == [] -> true
    ;   ui(notices, NT),
        format("<aside class=\"notices\"><h2>~w</h2>~n", [NT]),
        forall(member(N, Doc.notices),
               ( html_escape(N, NE), split_string(NE, "\n", "", Ls),
                 atomic_list_concat(Ls, '<br>', LA),
                 format("<p>~w</p>~n", [LA]) )),
        format("</aside>~n")
    ).

html_contents(Doc) :-
    ui(contents, CT), ui(index, IT),
    format("<nav class=\"toc\"><h2>~w</h2><ul>~n", [CT]),
    forall(member(H, Doc.headings),
           ( html_escape(H.text, HT),
             format("<li class=\"l~w\"><a href=\"#~w\">~w</a></li>~n", [H.level, H.anchor, HT]) )),
    format("<li class=\"l2\"><a href=\"#index\">~w</a></li>~n</ul></nav>~n", [IT]).

html_legend :-
    ui(legend, LT), ui(legend_text, LX),
    format("<details class=\"legend\"><summary>~w</summary><p>~w</p><ul>~n", [LT, LX]),
    forall(member(C-K, [k-legend_k, t-legend_t, h-legend_h, v-legend_v, c-legend_c, p-legend_p]),
           ( ui(K, Tx), html_escape(Tx, TE), sample(C, Sm),
             format("<li><span class=\"~w\">~w</span> — ~w</li>~n", [C, Sm, TE]) )),
    format("</ul></details>~n").

sample(k, "if").
sample(t, "is entitled to").
sample(h, "is entitled to").
sample(v, "a person").
sample(c, "Alice").
sample(p, "a person").

html_block(B) :- B.type == heading, !,
    html_escape(B.text, T),
    format("<section class=\"sec sec-~w\"><h~w id=\"~w\">~w</h~w>~n", [B.kind, B.level, B.anchor, T, B.level]),
    format("<p class=\"src\">"), html_segs(B.source), format("</p></section>~n").
html_block(B) :- B.type == comment, !,
    ui(comment, CT),
    html_escape(B.text, E), split_string(E, "\n", "", Ls), atomic_list_concat(Ls, '<br>', LA),
    format("<aside class=\"note\" title=\"~w\">~w</aside>~n", [CT, LA]).
html_block(B) :- B.type == (table), !,
    kind_text((table), KT),
    format("<div class=\"st st-table\" id=\"s~w\">", [B.n]),
    forall(member(T, B.targets), format("<span id=\"~w\"></span>", [T])),
    format("<div class=\"no\" title=\"~w\">~w</div><div class=\"body\">", [KT, B.n]),
    html_label(B),
    format("<div class=\"ln\">"), html_segs(B.header), format("</div>"),
    (   B.rows = [Head|Rows]
    ->  format("<div class=\"tw\"><table><thead><tr>"),
        forall(member(C, Head), ( html_escape(C, CE), format("<th>~w</th>", [CE]) )),
        format("</tr></thead><tbody>~n"),
        forall(member(R, Rows),
               ( format("<tr>"),
                 forall(member(C, R), ( html_escape(C, CE), format("<td>~w</td>", [CE]) )),
                 format("</tr>~n") )),
        format("</tbody></table></div>")
    ;   true
    ),
    html_xref(B),
    format("</div></div>~n").
html_block(B) :-
    kind_text(B.kind, KT),
    format("<div class=\"st st-~w\" id=\"s~w\">", [B.kind, B.n]),
    forall(member(T, B.targets), format("<span id=\"~w\"></span>", [T])),
    format("<div class=\"no\" title=\"~w\">~w</div><div class=\"body\">", [KT, B.n]),
    html_label(B),
    forall(member(L, B.lines),
           ( format("<div class=\"ln\" style=\"--i:~w\">", [L.indent]),
             html_segs(L.segs), format("</div>") )),
    html_xref(B),
    format("</div></div>~n").

html_label(B) :-
    (   B.label \== [] -> format("<div class=\"lbl\">"), html_segs(B.label), format("</div>") ; true ).

html_xref(B) :-
    (   B.xref == [] -> true
    ;   format("<div class=\"xref\">"),
        forall(nth1(I, B.xref, R),
               ( ( I > 1 -> format(" · ") ; true ),
                 ui(R.what, W),
                 format("~w ", [W]),
                 html_refs(R.refs) )),
        format("</div>")
    ).

html_refs(Ns) :-
    forall(nth1(I, Ns, N),
           ( ( I > 1 -> format(", ") ; true ),
             format("<a href=\"#s~w\">~w</a>", [N, N]) )).

html_segs(Segs) :-
    forall(member(S, Segs), html_seg(S)).

html_seg(S) :-
    html_escape(S.text, E),
    (   get_dict(link, S, L), L \== ""
    ->  html_escape(L, LE),
        ( sub_atom(L, 0, _, _, '#') -> Ext = "" ; Ext = " rel=\"noopener\"" ),
        format("<a class=\"~w\" href=\"~w\"~w>~w</a>", [S.class, LE, Ext, E])
    ;   S.class == o -> format("~w", [E])
    ;   format("<span class=\"~w\">~w</span>", [S.class, E])
    ).

html_index(Doc) :-
    ui(index, IT), ui(index_intro, II),
    ui(declared, Dc), ui(defined_in, Df), ui(used_in, Us), ui(not_defined, ND),
    format("<section class=\"index\"><h2 id=\"index\">~w</h2><p class=\"intro\">~w</p><dl>~n", [IT, II]),
    forall(member(E, Doc.index),
           ( html_escape(E.text, T),
             format("<dt><a href=\"#s~w\">~w</a></dt><dd>~w <a href=\"#s~w\">~w</a>", [E.n, T, Dc, E.n, E.n]),
             (   E.defined == [] -> format("; ~w", [ND])
             ;   format("; ~w ", [Df]), html_refs(E.defined)
             ),
             ( E.used == [] -> true ; format("; ~w ", [Us]), html_refs(E.used) ),
             format("</dd>~n") )),
    format("</dl></section>~n").

html_footer(Doc) :-
    (   Doc.notices == [] -> true
    ;   format("<footer class=\"foot\">"),
        forall(member(N, Doc.notices),
               ( split_string(N, "\n", "", [First|_]), html_escape(First, FE),
                 format("<p>~w</p>", [FE]) )),
        format("</footer>~n")
    ).

html_escape(S0, S) :-
    format(string(S1), "~w", [S0]),
    string_codes(S1, Cs),
    foldl([C, A0, A]>>( C == 0'& -> append(`;pma&`, A0, A)
                      ; C == 0'< -> append(`;tl&`, A0, A)
                      ; C == 0'> -> append(`;tg&`, A0, A)
                      ; C == 0'" -> append(`;touq&`, A0, A)
                      ; A = [C|A0] ), Cs, [], R),
    reverse(R, Out), string_codes(S, Out).

%   The styles, all inline, so that the document is one file. Each style is a
%   class of <body>; the menu changes it (script/1). Print always uses the
%   style on screen, without the menu and with the links' numbers.
css(CSS) :- CSS =
":root{--ink:#1b1f24;--muted:#5d6670;--rule:#d9dde2;--bg:#fff;--k:#1b1f24;--t:#123d6b;--d:#123d6b;--v:#5a2d82;--c:#7a3b00;--p:#5a2d82;--hl:#fff6cf;--card:transparent;--font:Georgia,'Iowan Old Style','Palatino Linotype',Palatino,serif;--mono:ui-monospace,'SF Mono',Menlo,Consolas,monospace;--size:17px;--lh:1.55;--gap:0.9rem}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body.rd{margin:0;background:var(--bg);color:var(--ink);font-family:var(--font);font-size:var(--size);line-height:var(--lh)}
.page{max-width:46rem;margin:0 auto;padding:2.5rem 1rem 4rem}
h1{font-size:2rem;line-height:1.2;margin:0 0 .3rem;font-weight:600}
h2{font-size:1.3rem;margin:2.2rem 0 .2rem;font-weight:600;border-bottom:1px solid var(--rule);padding-bottom:.2rem}
h3{font-size:1.1rem;margin:1.6rem 0 .2rem;font-weight:600}
.subtitle{margin:0;color:var(--muted);font-style:italic}
.made{margin:.4rem 0 0;color:var(--muted);font-size:.85em}
.notices{margin:1.2rem 0;padding:.6rem .9rem;border:1px solid var(--rule);font-size:.85em}
.notices h2{font-size:.9rem;margin:0 0 .3rem;border:0;padding:0;text-transform:uppercase;letter-spacing:.06em}
.notices p{margin:.3rem 0}
.toc h2{font-size:1rem;text-transform:uppercase;letter-spacing:.06em;border:0}
.toc ul{list-style:none;padding:0;margin:0;columns:2;column-gap:2rem}
.toc li{break-inside:avoid;margin:.1rem 0}
.toc li.l3{padding-left:1rem;font-size:.92em}
.toc a{color:var(--ink);text-decoration:none}
.toc a:hover{text-decoration:underline}
.legend{margin:1.2rem 0;font-size:.85em;color:var(--muted)}
.legend summary{cursor:pointer}
.legend ul{padding-left:1.2rem}
.src{margin:.1rem 0 .6rem;color:var(--muted);font-size:.9em}
.st{display:flex;gap:.8rem;margin:var(--gap) 0;scroll-margin-top:3rem}
.st:target .body{background:var(--hl)}
.no{flex:0 0 2.2rem;text-align:right;color:var(--muted);font-size:.8em;padding-top:.2em;font-variant-numeric:tabular-nums}
.body{flex:1;min-width:0;background:var(--card)}
.ln{padding-left:calc(var(--i,0) * 1.6em + 0em);text-indent:0}
.ln+.ln{margin-top:.05em}
.st-rule .ln+.ln,.st-reactive .ln+.ln,.st-law .ln+.ln,.st-constraint .ln+.ln{padding-left:calc(var(--i,0) * 1.6em + 1.6em)}
.lbl{color:var(--muted);font-size:.9em}
.xref{margin-top:.25rem;color:var(--muted);font-size:.78em}
.xref a,.index a{color:var(--muted)}
.k{font-variant:small-caps;letter-spacing:.03em;font-weight:600;color:var(--k)}
.t,.d{color:var(--t)}
a.t{text-decoration:none;border-bottom:1px dotted currentColor}
a.t:hover{border-bottom-style:solid;background:var(--hl)}
.d{font-weight:600}
a.r{color:var(--t)}
.h{color:var(--t);font-weight:600}
.v{font-style:italic;color:var(--v)}
.c,.n,.s{color:var(--c)}
.p{font-style:italic;color:var(--p);border-bottom:1px solid currentColor}
.note{margin:.6rem 0 .6rem 3rem;color:var(--muted);font-style:italic;font-size:.9em;border-left:2px solid var(--rule);padding-left:.6rem}
.tw{overflow-x:auto;margin:.4rem 0}
table{border-collapse:collapse;font-size:.92em}
th,td{border:1px solid var(--rule);padding:.2rem .6rem;text-align:left;vertical-align:top}
th{font-weight:600;background:rgba(0,0,0,.03)}
.index dl{margin:0}
.index dt{margin-top:.5rem;font-weight:600}
.index dt a{color:var(--t);text-decoration:none}
.index dd{margin:0 0 0 1.2rem;color:var(--muted);font-size:.85em}
.intro{color:var(--muted);font-size:.9em}
.foot{margin-top:3rem;border-top:1px solid var(--rule);padding-top:.6rem;color:var(--muted);font-size:.78em}
.bar{position:fixed;top:.6rem;right:.6rem;z-index:10;display:flex;gap:.4rem;font-family:system-ui,sans-serif;font-size:13px}
.bar-btn{font:inherit;padding:.3rem .7rem;border:1px solid var(--rule);background:var(--bg);color:var(--ink);border-radius:4px;cursor:pointer}
.menu{position:absolute;top:2rem;right:0;margin:0;padding:.3rem 0;list-style:none;background:var(--bg);border:1px solid var(--rule);border-radius:4px;box-shadow:0 4px 14px rgba(0,0,0,.12);min-width:11rem}
.menu li{padding:.35rem .9rem;cursor:pointer;color:var(--ink)}
.menu li:hover,.menu li:focus{background:var(--hl);outline:none}
.menu li[aria-checked=true]::before{content:'✓ ';}
.menu li[aria-checked=false]::before{content:'\\2003';}
/* compact: dense, for a long program */
body.style-compact{--size:14px;--lh:1.32;--gap:.25rem;--font:-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif}
.style-compact .page{max-width:60rem}
.style-compact h2{margin-top:1.2rem}
.style-compact .src{display:none}
.style-compact .toc ul{columns:3}
.style-compact .xref{display:inline;margin-left:.6rem}
.style-compact .k{font-variant:normal;font-weight:700;letter-spacing:0}
/* legal: set like a statute */
body.style-legal{--font:'Times New Roman',Times,'Liberation Serif',serif;--size:17px;--t:#1b1f24;--d:#1b1f24;--v:#1b1f24;--c:#1b1f24;--p:#1b1f24;--lh:1.6}
.style-legal h1,.style-legal h2{text-align:center;text-transform:uppercase;letter-spacing:.08em;border:0;font-weight:normal}
.style-legal h2{font-size:1.05rem;margin-top:2.6rem}
.style-legal h3{text-align:center;font-style:italic;font-weight:normal}
.style-legal .src{text-align:center;font-style:italic}
.style-legal .no::after{content:'.'}
.style-legal .no{font-size:1em;color:var(--ink);font-weight:bold}
.style-legal .body{text-align:justify;hyphens:auto}
.style-legal .k{font-weight:normal;font-variant:small-caps;letter-spacing:.06em}
.style-legal .v{font-style:italic}
.style-legal a.t{border-bottom:1px solid #b9bec4}
.style-legal .p{border:0}
.style-legal .xref{font-style:italic}
/* cute: more colour, an icon for each kind of statement */
body.style-cute{--font:'Nunito','Trebuchet MS','Segoe UI',system-ui,sans-serif;--bg:#fffdf7;--rule:#f0dcc0;--k:#c2185b;--t:#00695c;--d:#00695c;--v:#6a1b9a;--c:#e65100;--p:#6a1b9a;--hl:#fff1a8;--card:#fff;--size:17px;--gap:.8rem}
.style-cute h1{color:#c2185b}
.style-cute h2{border-bottom:3px dotted var(--rule);color:#00695c}
.style-cute .st .body{border:1px solid var(--rule);border-radius:12px;padding:.5rem .8rem;box-shadow:0 2px 0 var(--rule)}
.style-cute .k{font-variant:normal;letter-spacing:0;font-weight:800}
.style-cute .no{flex-basis:3.4rem}
.style-cute .no::before{display:block;font-size:1.5rem;line-height:1}
.style-cute .st-rule .no::before{content:'📜'}
.style-cute .st-fact .no::before{content:'📌'}
.style-cute .st-scenario_fact .no::before{content:'🎬'}
.style-cute .st-query .no::before{content:'❓'}
.style-cute .st-expectation .no::before{content:'🎯'}
.style-cute .st-table .no::before{content:'🧮'}
.style-cute .st-law .no::before{content:'⚡'}
.style-cute .st-reactive .no::before{content:'🔔'}
.style-cute .st-constraint .no::before{content:'🚧'}
.style-cute .st-initially .no::before{content:'🌱'}
.style-cute .st-goal .no::before{content:'🏁'}
.style-cute .st-setting .no::before{content:'⚙️'}
.style-cute .st-resource .no::before{content:'📎'}
.style-cute .st-view .no::before{content:'🖼️'}
.style-cute .st-ontology .no::before{content:'🌳'}
.style-cute [class*='st-template_'] .no::before{content:'🧩'}
.style-cute .st-template_fluent .no::before{content:'🌊'}
.style-cute .st-template_event .no::before{content:'💥'}
.style-cute .st-template_action .no::before{content:'🏃'}
.style-cute .st-statement .no::before{content:'💬'}
.style-cute .p{border-bottom:2px dashed currentColor}
.style-cute a.t{border-bottom:2px solid #80cbc4}
/* editor: the colours of the Logical English editor */
body.style-editor{--font:var(--mono);--size:14.5px;--bg:#1e1e1e;--ink:#d4d4d4;--muted:#8a8f98;--rule:#3a3d41;--k:#569cd6;--t:#dcdcaa;--d:#dcdcaa;--v:#9cdcfe;--c:#ce9178;--p:#9cdcfe;--hl:#264f78;--lh:1.5}
.style-editor .k{font-variant:normal;letter-spacing:0;font-weight:normal}
.style-editor .v,.style-editor .p{font-style:normal}
.style-editor .n{color:#b5cea8}
.style-editor .page{max-width:62rem}
.style-editor .toc a,.style-editor h1,.style-editor h2,.style-editor h3{color:#e6e6e6}
@media (max-width:600px){.page{padding:3rem .9rem 3rem}.toc ul{columns:1}.no{flex-basis:1.6rem}.style-cute .no{flex-basis:2.4rem}.ln{padding-left:calc(var(--i,0) * 1em)}.st-rule .ln+.ln,.st-reactive .ln+.ln,.st-law .ln+.ln,.st-constraint .ln+.ln{padding-left:calc(var(--i,0) * 1em + 1em)}}
@page{margin:18mm 16mm}
@media print{.bar,.legend{display:none}.page{max-width:none;padding:0}body.rd{background:#fff;font-size:11pt}.st{break-inside:avoid}h2,h3{break-after:avoid}a.t{border:0}a{color:inherit}.toc ul{columns:2}.st:target .body{background:none}body.style-editor{--bg:#fff;--ink:#000;--k:#0000c0;--t:#5a4b00;--d:#5a4b00;--v:#00507a;--c:#a31515;--p:#00507a}}
".

%   The style menu, the print button, and a printed PDF on opening (format
%   pdf). The style chosen is remembered in the reader's browser when it
%   can be; the page works the same when it cannot.
script(JS) :- JS =
"(function(){
var b=document.body,btn=document.getElementById('rd-style-btn'),m=document.getElementById('rd-style-menu');
function setStyle(s){b.className=b.className.replace(/\\bstyle-\\S+/g,'').trim()+' style-'+s;
[].forEach.call(m.querySelectorAll('li'),function(li){li.setAttribute('aria-checked',li.getAttribute('data-style')===s?'true':'false');});
try{localStorage.setItem('le-readable-style',s);}catch(e){}}
try{var saved=localStorage.getItem('le-readable-style');if(saved&&!/[?&]style=/.test(location.search)&&m.querySelector('[data-style=\"'+saved+'\"]'))setStyle(saved);}catch(e){}
function close(){m.hidden=true;btn.setAttribute('aria-expanded','false');}
btn.addEventListener('click',function(e){e.stopPropagation();m.hidden=!m.hidden;btn.setAttribute('aria-expanded',m.hidden?'false':'true');if(!m.hidden){var c=m.querySelector('[aria-checked=true]')||m.querySelector('li');c&&c.focus();}});
m.addEventListener('click',function(e){var li=e.target.closest('li');if(li){setStyle(li.getAttribute('data-style'));close();}});
m.addEventListener('keydown',function(e){var li=e.target.closest('li');if(!li)return;if(e.key==='Enter'||e.key===' '){e.preventDefault();setStyle(li.getAttribute('data-style'));close();btn.focus();}
else if(e.key==='ArrowDown'){e.preventDefault();(li.nextElementSibling||m.firstElementChild).focus();}
else if(e.key==='ArrowUp'){e.preventDefault();(li.previousElementSibling||m.lastElementChild).focus();}
else if(e.key==='Escape'){close();btn.focus();}});
document.addEventListener('click',close);
document.getElementById('rd-print').addEventListener('click',function(){window.print();});
if(b.getAttribute('data-autoprint')==='1')window.addEventListener('load',function(){setTimeout(function(){window.print();},300);});
})();
".

		 /*******************************
		 *         WORD (.docx)         *
		 *******************************/

%   docx_document(+Doc, -Bytes): a Word document of Doc, the plain style:
%   one paragraph per line of a statement, indented as the statement is;
%   each word in a character style of its class (LE Keyword, LE Template,
%   LE Variable, LE Value, LE Place), so that a reader can restyle them in
%   Word; bookmarks for the statements and internal hyperlinks to them.
docx_document(Doc, Bytes) :-
    tmp_file_stream(binary, File, S0), close(S0),
    setup_call_cleanup(
        true,
        (   docx_write(Doc, File),
            read_file_to_codes(File, Bytes, [type(binary)])
        ),
        catch(delete_file(File), _, true)).

docx_write(Doc, File) :-
    with_output_to(string(Body), docx_body(Doc, Rels)),
    docx_document_xml(Body, DocXml),
    docx_rels_xml(Rels, DocRels),
    html_escape(Doc.title, TE),
    format(string(Core), "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><dc:title>~w</dc:title><dc:language>~w</dc:language></cp:coreProperties>", [TE, Doc.lang]),
    docx_styles(Styles),
    setup_call_cleanup(
        zip_open(File, write, Zip, []),
        (   zip_add(Zip, '[Content_Types].xml', "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/><Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/><Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/></Types>"),
            zip_add(Zip, '_rels/.rels', "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties\" Target=\"docProps/core.xml\"/></Relationships>"),
            zip_add(Zip, 'word/document.xml', DocXml),
            zip_add(Zip, 'word/styles.xml', Styles),
            zip_add(Zip, 'word/_rels/document.xml.rels', DocRels),
            zip_add(Zip, 'docProps/core.xml', Core)
        ),
        zip_close(Zip)).

zip_add(Zip, Name, Text) :-
    setup_call_cleanup(
        zipper_open_new_file_in_zip(Zip, Name, S, []),
        ( set_stream(S, encoding(utf8)), write(S, Text) ),
        close(S)).

docx_document_xml(Body, Xml) :-
    format(string(Xml), "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:body>~w<w:sectPr><w:pgSz w:w=\"11906\" w:h=\"16838\"/><w:pgMar w:top=\"1300\" w:right=\"1300\" w:bottom=\"1300\" w:left=\"1300\" w:header=\"708\" w:footer=\"708\" w:gutter=\"0\"/></w:sectPr></w:body></w:document>", [Body]).

docx_rels_xml(Rels, Xml) :-
    with_output_to(string(Rs),
        forall(member(rel(Id, URL), Rels),
               ( html_escape(URL, UE),
                 format("<Relationship Id=\"~w\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"~w\" TargetMode=\"External\"/>", [Id, UE]) ))),
    format(string(Xml), "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rIdStyles\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>~w</Relationships>", [Rs]).

%   The body, written to current output; Rels the external links it uses.
docx_body(Doc, Rels) :-
    nb_setval(le_readable_rels, []),
    nb_setval(le_readable_bm, 0),
    docx_par('Title', [], [r(none, Doc.title)]),
    subtitle(Doc, Sub), docx_par('Subtitle', [], [r(none, Sub)]),
    made_from(Doc, Made), docx_par('LEMeta', [], [r(none, Made)]),
    (   Doc.notices \== []
    ->  ui(notices, NT), docx_par('Heading2', [], [r(none, NT)]),
        forall(member(N, Doc.notices),
               ( split_string(N, "\n", "", Ls),
                 forall(member(L, Ls), docx_par('LENotice', [], [r(none, L)])) ))
    ;   true
    ),
    ui(legend, LT), docx_par('Heading2', [], [r(none, LT)]),
    ui(legend_text, LX), docx_par('LEMeta', [], [r(none, LX)]),
    forall(member(C-K, [k-legend_k, t-legend_t, v-legend_v, c-legend_c, p-legend_p]),
           ( ui(K, Tx), sample(C, Sm), class_style(C, CS),
             format(string(Dash), " — ~w", [Tx]),
             docx_par('LEMeta', [], [r(CS, Sm), r(none, Dash)]) )),
    forall(member(B, Doc.blocks), docx_block(B)),
    docx_index(Doc),
    nb_getval(le_readable_rels, Rels0), reverse(Rels0, Rels).

docx_block(B) :- B.type == heading, !,
    ( B.level =:= 2 -> St = 'Heading1' ; St = 'Heading2' ),
    docx_par(St, [bookmark(B.anchor)], [r(none, B.text)]),
    docx_segs_runs(B.source, Runs),
    docx_par('LESource', [], Runs).
docx_block(B) :- B.type == comment, !,
    split_string(B.text, "\n", "", Ls),
    forall(member(L, Ls), docx_par('LEComment', [], [r(none, L)])).
docx_block(B) :- B.type == (table), !,
    format(string(NT), "~w.\t", [B.n]),
    docx_label(B),
    docx_segs_runs(B.header, HRuns),
    format(atom(A), "s~w", [B.n]),
    docx_par('LEStatement', [bookmark(A)], [r('LENumber', NT)|HRuns]),
    (   B.rows = [_|_]
    ->  format("<w:tbl><w:tblPr><w:tblStyle w:val=\"LETable\"/><w:tblW w:w=\"0\" w:type=\"auto\"/><w:tblInd w:w=\"567\" w:type=\"dxa\"/><w:tblBorders><w:top w:val=\"single\" w:sz=\"4\" w:color=\"BFC4CA\"/><w:left w:val=\"single\" w:sz=\"4\" w:color=\"BFC4CA\"/><w:bottom w:val=\"single\" w:sz=\"4\" w:color=\"BFC4CA\"/><w:right w:val=\"single\" w:sz=\"4\" w:color=\"BFC4CA\"/><w:insideH w:val=\"single\" w:sz=\"4\" w:color=\"BFC4CA\"/><w:insideV w:val=\"single\" w:sz=\"4\" w:color=\"BFC4CA\"/></w:tblBorders></w:tblPr>"),
        B.rows = [Head0|_], length(Head0, NCols), ColW is max(600, 8500 // max(1, NCols)),
        format("<w:tblGrid>"), forall(between(1, NCols, _), format("<w:gridCol w:w=\"~w\"/>", [ColW])), format("</w:tblGrid>"),
        forall(nth1(I, B.rows, R),
               ( format("<w:tr>"),
                 forall(member(C, R),
                        ( format("<w:tc>"),
                          ( I =:= 1 -> docx_par('LECell', [], [r(bold, C)]) ; docx_par('LECell', [], [r(none, C)]) ),
                          format("</w:tc>") )),
                 format("</w:tr>") )),
        format("</w:tbl>")
    ;   true
    ),
    docx_xref(B).
docx_block(B) :-
    docx_label(B),
    format(atom(A), "s~w", [B.n]),
    format(string(NT), "~w.\t", [B.n]),
    B.lines = [First|Rest],
    docx_segs_runs(First.segs, FRuns),
    findall(bookmark(T), member(T, B.targets), TBs),
    docx_par('LEStatement', [bookmark(A)|TBs], [r('LENumber', NT)|FRuns]),
    forall(member(L, Rest),
           ( docx_segs_runs(L.segs, Runs),
             Ind is 567 + (L.indent + 1) * 425,
             docx_par('LEStatementCont', [indent(Ind)], Runs) )),
    docx_xref(B).

docx_label(B) :-
    (   B.label \== [] -> docx_segs_runs(B.label, LR), docx_par('LELabel', [], LR) ; true ).

docx_xref(B) :-
    (   B.xref == [] -> true
    ;   findall(Run, ( nth1(I, B.xref, R), ui(R.what, W),
                       ( I > 1 -> Sep = " · " ; Sep = "" ),
                       format(string(WS), "~w~w ", [Sep, W]),
                       (   Run = r(none, WS)
                       ;   nth1(J, R.refs, N), ( J > 1 -> Run = r(none, ", ") ; fail )
                       ;   nth1(_, R.refs, N), format(atom(BA), "s~w", [N]), format(string(NS), "~w", [N]),
                           Run = link(local(BA), 'LEXref', NS)
                       ) ), Runs0),
        interleave_refs(Runs0, Runs),
        docx_par('LEXref', [], Runs)
    ).

%   (the findall above yields, for each reference list, the word, then the
%   separators, then the links; put each separator after its link)
interleave_refs(Runs0, Runs) :-
    interleave_(Runs0, Runs).
interleave_([], []).
interleave_([r(none, W)|Rest], [r(none, W)|Out]) :-
    \+ sub_string(W, _, _, _, ", "), !,
    split_group(Rest, Seps, Links, Rest1),
    weave(Links, Seps, Woven),
    interleave_(Rest1, Out0),
    append(Woven, Out0, Out).
interleave_([X|Rest], [X|Out]) :- interleave_(Rest, Out).

split_group(Rs, Seps, Links, Rest) :-
    split_group_(Rs, Seps, Links, Rest).
split_group_([r(none, ", ")|Rs], [r(none, ", ")|Ss], Ls, Rest) :- !, split_group_(Rs, Ss, Ls, Rest).
split_group_([L|Rs], Ss, [L|Ls], Rest) :- L = link(_, _, _), !, split_group_(Rs, Ss, Ls, Rest).
split_group_(Rest, [], [], Rest).

weave([], _, []).
weave([L], _, [L]) :- !.
weave([L|Ls], [S|Ss], [L, S|Out]) :- weave(Ls, Ss, Out).
weave([L|Ls], [], [L|Out]) :- weave(Ls, [], Out).

docx_index(Doc) :-
    ui(index, IT), docx_par('Heading1', [bookmark(index)], [r(none, IT)]),
    ui(index_intro, II), docx_par('LEMeta', [], [r(none, II)]),
    ui(declared, Dc), ui(defined_in, Df), ui(used_in, Us), ui(not_defined, ND),
    forall(member(E, Doc.index),
           ( format(atom(A), "s~w", [E.n]), format(string(NS), "~w", [E.n]),
             format(string(DcS), " — ~w ", [Dc]),
             Runs0 = [link(local(A), 'LETemplate', E.text), r(none, DcS), link(local(A), 'LEXref', NS)],
             (   E.defined == [] -> format(string(NDS), "; ~w", [ND]), DRuns = [r(none, NDS)]
             ;   format(string(DfS), "; ~w ", [Df]), ref_runs(E.defined, RR), DRuns = [r(none, DfS)|RR]
             ),
             (   E.used == [] -> URuns = []
             ;   format(string(UsS), "; ~w ", [Us]), ref_runs(E.used, UR), URuns = [r(none, UsS)|UR]
             ),
             append([Runs0, DRuns, URuns], Runs),
             docx_par('LEIndex', [], Runs) )).

ref_runs(Ns, Runs) :-
    findall(R, ( nth1(I, Ns, N),
                 ( I > 1, R = r(none, ", ")
                 ; format(atom(A), "s~w", [N]), format(string(S), "~w", [N]),
                   R = link(local(A), 'LEXref', S) ) ), Runs).

docx_segs_runs(Segs, Runs) :-
    findall(R, ( member(S, Segs), seg_run(S, R) ), Runs).

seg_run(S, R) :-
    class_style(S.class, St),
    (   get_dict(link, S, L), L \== ""
    ->  (   sub_atom(L, 0, 1, _, '#') -> sub_atom(L, 1, _, 0, A), R = link(local(A), St, S.text)
        ;   R = link(url(L), St, S.text)
        )
    ;   R = r(St, S.text)
    ).

class_style(k, 'LEKeyword') :- !.
class_style(t, 'LETemplate') :- !.
class_style(h, 'LETemplateDecl') :- !.
class_style(d, 'LETemplateDecl') :- !.
class_style(v, 'LEVariable') :- !.
class_style(p, 'LEPlace') :- !.
class_style(c, 'LEValue') :- !.
class_style(n, 'LEValue') :- !.
class_style(s, 'LEValue') :- !.
class_style(_, none).

%   docx_par(+Style, +Opts, +Runs): one paragraph. Opts: bookmark(Name),
%   indent(Twips). A bookmark name in Word is at most 40 characters of
%   letters, digits and underscores: each anchor of the document gets one,
%   by its number.
docx_par(Style, Opts, Runs) :-
    format("<w:p><w:pPr><w:pStyle w:val=\"~w\"/>", [Style]),
    (   memberchk(indent(I), Opts) -> format("<w:ind w:left=\"~w\"/>", [I]) ; true ),
    format("</w:pPr>"),
    forall(member(bookmark(B), Opts),
           ( bookmark_name(B, BN), nb_getval(le_readable_bm, K0), K is K0 + 1, nb_setval(le_readable_bm, K),
             format("<w:bookmarkStart w:id=\"~w\" w:name=\"~w\"/><w:bookmarkEnd w:id=\"~w\"/>", [K, BN, K]) )),
    forall(member(R, Runs), docx_run(R)),
    format("</w:p>").

bookmark_name(Anchor, Name) :-
    format(atom(A), "~w", [Anchor]),
    atom_codes(A, Cs),
    maplist([C, D]>>( ( between(0'a, 0'z, C) ; between(0'A, 0'Z, C) ; between(0'0, 0'9, C) ) -> D = C ; D = 0'_ ), Cs, Ds0),
    atom_codes(N0, Ds0),
    (   atom_length(N0, L), L =< 38 -> N1 = N0
    ;   term_hash(A, H), sub_atom(N0, 0, 28, _, P), format(atom(N1), "~w_~w", [P, H])
    ),
    atom_concat(b_, N1, Name).

docx_run(r(Style, Text)) :- !,
    docx_text_runs(Style, Text).
docx_run(link(local(A), Style, Text)) :- !,
    bookmark_name(A, BN),
    format("<w:hyperlink w:anchor=\"~w\" w:history=\"1\">", [BN]),
    docx_text_runs(Style, Text),
    format("</w:hyperlink>").
docx_run(link(url(URL), Style, Text)) :-
    nb_getval(le_readable_rels, Rels0),
    length(Rels0, N), format(atom(Id), "rIdL~w", [N]),
    nb_setval(le_readable_rels, [rel(Id, URL)|Rels0]),
    format("<w:hyperlink r:id=\"~w\" w:history=\"1\">", [Id]),
    docx_text_runs(Style, Text),
    format("</w:hyperlink>").

%   A text with tabs: Word wants a <w:tab/> for each.
docx_text_runs(Style, Text) :-
    format(string(T0), "~w", [Text]),
    split_string(T0, "\t", "", Parts),
    format("<w:r>"),
    (   Style == none -> true
    ;   Style == bold -> format("<w:rPr><w:b/></w:rPr>")
    ;   format("<w:rPr><w:rStyle w:val=\"~w\"/></w:rPr>", [Style])
    ),
    forall(nth1(I, Parts, P),
           ( ( I > 1 -> format("<w:tab/>") ; true ),
             ( P == "" -> true ; html_escape(P, PE), format("<w:t xml:space=\"preserve\">~w</w:t>", [PE]) ) )),
    format("</w:r>").

docx_styles(Xml) :-
    Xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<w:styles xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">
<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii=\"Georgia\" w:hAnsi=\"Georgia\" w:cs=\"Georgia\" w:eastAsia=\"Georgia\"/><w:sz w:val=\"22\"/><w:szCs w:val=\"22\"/><w:lang w:val=\"en-GB\"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after=\"60\" w:line=\"276\" w:lineRule=\"auto\"/></w:pPr></w:pPrDefault></w:docDefaults>
<w:style w:type=\"paragraph\" w:default=\"1\" w:styleId=\"Normal\"><w:name w:val=\"Normal\"/><w:qFormat/></w:style>
<w:style w:type=\"paragraph\" w:styleId=\"Title\"><w:name w:val=\"Title\"/><w:basedOn w:val=\"Normal\"/><w:qFormat/><w:pPr><w:spacing w:after=\"60\"/></w:pPr><w:rPr><w:b/><w:sz w:val=\"44\"/></w:rPr></w:style>
<w:style w:type=\"paragraph\" w:styleId=\"Subtitle\"><w:name w:val=\"Subtitle\"/><w:basedOn w:val=\"Normal\"/><w:qFormat/><w:rPr><w:i/><w:color w:val=\"5D6670\"/></w:rPr></w:style>
<w:style w:type=\"paragraph\" w:styleId=\"Heading1\"><w:name w:val=\"heading 1\"/><w:basedOn w:val=\"Normal\"/><w:next w:val=\"Normal\"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before=\"360\" w:after=\"60\"/><w:pBdr><w:bottom w:val=\"single\" w:sz=\"4\" w:space=\"1\" w:color=\"D9DDE2\"/></w:pBdr><w:outlineLvl w:val=\"0\"/></w:pPr><w:rPr><w:b/><w:sz w:val=\"30\"/></w:rPr></w:style>
<w:style w:type=\"paragraph\" w:styleId=\"Heading2\"><w:name w:val=\"heading 2\"/><w:basedOn w:val=\"Normal\"/><w:next w:val=\"Normal\"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before=\"240\" w:after=\"40\"/><w:outlineLvl w:val=\"1\"/></w:pPr><w:rPr><w:b/><w:sz w:val=\"25\"/></w:rPr></w:style>
<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"LEMeta\"><w:name w:val=\"LE Meta\"/><w:basedOn w:val=\"Normal\"/><w:rPr><w:color w:val=\"5D6670\"/><w:sz w:val=\"19\"/></w:rPr></w:style>
<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"LENotice\"><w:name w:val=\"LE Notice\"/><w:basedOn w:val=\"Normal\"/><w:pPr><w:ind w:left=\"284\"/><w:spacing w:after=\"0\"/></w:pPr><w:rPr><w:sz w:val=\"19\"/></w:rPr></w:style>
<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"LESource\"><w:name w:val=\"LE Section Line\"/><w:basedOn w:val=\"Normal\"/><w:pPr><w:spacing w:after=\"120\"/></w:pPr><w:rPr><w:color w:val=\"5D6670\"/><w:sz w:val=\"20\"/></w:rPr></w:style>
<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"LEStatement\"><w:name w:val=\"LE Statement\"/><w:basedOn w:val=\"Normal\"/><w:pPr><w:keepNext/><w:tabs><w:tab w:val=\"left\" w:pos=\"567\"/></w:tabs><w:spacing w:before=\"140\" w:after=\"0\"/><w:ind w:left=\"567\" w:hanging=\"567\"/></w:pPr></w:style>
<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"LEStatementCont\"><w:name w:val=\"LE Statement Line\"/><w:basedOn w:val=\"Normal\"/><w:pPr><w:keepNext/><w:spacing w:after=\"0\"/><w:ind w:left=\"992\"/></w:pPr></w:style>
<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"LELabel\"><w:name w:val=\"LE Label\"/><w:basedOn w:val=\"Normal\"/><w:pPr><w:keepNext/><w:spacing w:before=\"140\" w:after=\"0\"/><w:ind w:left=\"567\"/></w:pPr><w:rPr><w:color w:val=\"5D6670\"/><w:sz w:val=\"20\"/></w:rPr></w:style>
<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"LEXref\"><w:name w:val=\"LE Cross-reference\"/><w:basedOn w:val=\"Normal\"/><w:pPr><w:ind w:left=\"567\"/><w:spacing w:before=\"20\" w:after=\"60\"/></w:pPr><w:rPr><w:color w:val=\"5D6670\"/><w:sz w:val=\"17\"/></w:rPr></w:style>
<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"LEComment\"><w:name w:val=\"LE Comment\"/><w:basedOn w:val=\"Normal\"/><w:pPr><w:ind w:left=\"851\"/><w:spacing w:after=\"0\"/></w:pPr><w:rPr><w:i/><w:color w:val=\"5D6670\"/><w:sz w:val=\"20\"/></w:rPr></w:style>
<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"LEIndex\"><w:name w:val=\"LE Index\"/><w:basedOn w:val=\"Normal\"/><w:pPr><w:ind w:left=\"284\" w:hanging=\"284\"/><w:spacing w:after=\"40\"/></w:pPr><w:rPr><w:sz w:val=\"20\"/></w:rPr></w:style>
<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"LECell\"><w:name w:val=\"LE Table Cell\"/><w:basedOn w:val=\"Normal\"/><w:pPr><w:spacing w:after=\"0\"/></w:pPr><w:rPr><w:sz w:val=\"20\"/></w:rPr></w:style>
<w:style w:type=\"character\" w:customStyle=\"1\" w:styleId=\"LEKeyword\"><w:name w:val=\"LE Keyword\"/><w:rPr><w:b/><w:smallCaps/></w:rPr></w:style>
<w:style w:type=\"character\" w:customStyle=\"1\" w:styleId=\"LETemplate\"><w:name w:val=\"LE Template\"/><w:rPr><w:color w:val=\"123D6B\"/></w:rPr></w:style>
<w:style w:type=\"character\" w:customStyle=\"1\" w:styleId=\"LETemplateDecl\"><w:name w:val=\"LE Template Declaration\"/><w:rPr><w:b/><w:color w:val=\"123D6B\"/></w:rPr></w:style>
<w:style w:type=\"character\" w:customStyle=\"1\" w:styleId=\"LEVariable\"><w:name w:val=\"LE Variable\"/><w:rPr><w:i/><w:color w:val=\"5A2D82\"/></w:rPr></w:style>
<w:style w:type=\"character\" w:customStyle=\"1\" w:styleId=\"LEPlace\"><w:name w:val=\"LE Place\"/><w:rPr><w:i/><w:color w:val=\"5A2D82\"/><w:u w:val=\"single\"/></w:rPr></w:style>
<w:style w:type=\"character\" w:customStyle=\"1\" w:styleId=\"LEValue\"><w:name w:val=\"LE Value\"/><w:rPr><w:color w:val=\"7A3B00\"/></w:rPr></w:style>
<w:style w:type=\"character\" w:customStyle=\"1\" w:styleId=\"LENumber\"><w:name w:val=\"LE Statement Number\"/><w:rPr><w:color w:val=\"5D6670\"/><w:sz w:val=\"18\"/></w:rPr></w:style>
</w:styles>".

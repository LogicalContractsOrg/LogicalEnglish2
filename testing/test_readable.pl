/** <module> The readable document of a program (le_readable.pl)

    File ▸ Save as a Readable Document and the /readable/ route: a program as
    a document for a person who reads it without the editor. Checked here:
    the words are the program's, each sentence links to where its template
    is defined, the head of a rule is not a link to itself, comments are left
    out but notices are kept, decision tables are tables, LPS sentences have
    kinds of their own, every link of the HTML lands on an anchor, and the
    Word document is a well-formed package.

    Run with:  swipl -q -g run_tests -t halt testing/test_readable.pl
*/

:- module(test_readable, []).

:- use_module(library(plunit)).
:- use_module(library(zip)).
:- use_module(library(sgml)).
:- use_module(library(base64)).
:- use_module('../le_kbs').
:- use_module('../le_readable').
:- use_module('../le_api').

program(Text) :-
    Text = "% Copyright 2026 Example Ltd. All rights reserved.
% Licensed under the Apache License, Version 2.0.
%
% A private note: check rule two with the client before sending.
the target language is: prolog.

the templates are:
    *a person* is eligible.
    *a person* is a resident.
    *a person* earns *an amount*.

the knowledge base benefits includes:

% The main rule.
a person is eligible
    if the person is a resident
    and the person earns an amount
    and the amount < 1000.

scenario ann is:
    ann is a resident.
    ann earns 500.

query eligible is:
    which person is eligible.
".

ir(Text, Options, Doc) :-
    readable_ir(Text, [date('2026-10-28')|Options], Doc).

statements(Doc, Ss) :-
    include([B]>>get_dict(n, B, _), Doc.blocks, Ss).

segs_of(B, Segs) :-
    findall(S, ( member(L, B.lines), member(S, L.segs) ), Segs).

statement_starting(Doc, Prefix, B) :-
    statements(Doc, Ss), member(B, Ss),
    \+ sub_atom(B.kind, 0, _, _, template_),
    get_dict(lines, B, [L|_]),
    findall(T, ( member(S, L.segs), get_dict(text, S, T) ), Ts),
    atomic_list_concat(Ts, '', A),
    sub_atom(A, 0, _, _, Prefix), !.

:- begin_tests(readable).

test(sentence_links_to_its_definition) :-
    program(Text), ir(Text, [], Doc),
    statement_starting(Doc, 'a person is eligible', Rule),
    statement_starting(Doc, 'ann is a resident', Fact),
    %  the rule's condition links to the template's declaration (no rule defines it)
    segs_of(Rule, RSegs),
    member(S, RSegs), S.text == "is a resident", S.class == t,
    sub_string(S.link, 0, 2, _, "#s"),
    %  the fact of the scenario links to the same place
    segs_of(Fact, FSegs),
    member(F, FSegs), F.text == "is a resident", F.link == S.link, !.

test(head_is_not_a_link_to_itself) :-
    program(Text), ir(Text, [], Doc),
    statement_starting(Doc, 'a person is eligible', Rule),
    segs_of(Rule, Segs),
    member(H, Segs), H.text == "is eligible", !,
    assertion(H.class == h),
    assertion(H.link == "").

test(query_links_to_the_rule) :-
    program(Text), ir(Text, [], Doc),
    statement_starting(Doc, 'a person is eligible', Rule),
    statement_starting(Doc, 'which person', Q),
    segs_of(Q, Segs), member(S, Segs), S.text == "is eligible", !,
    format(string(Expected), "#s~w", [Rule.n]),
    assertion(S.link == Expected),
    %  and the rule says where it is used
    member(X, Rule.xref), X.what == used_in, !,
    assertion(X.refs == [Q.n]).

test(variables_values_and_keywords) :-
    program(Text), ir(Text, [], Doc),
    statement_starting(Doc, 'a person is eligible', Rule),
    segs_of(Rule, Segs),
    assertion(has_seg(Segs, "if", k)),
    assertion(has_seg(Segs, "the person", v)),
    assertion(has_seg(Segs, "1000", n)),
    statement_starting(Doc, 'ann earns', Fact),
    segs_of(Fact, FSegs),
    assertion(has_seg(FSegs, "ann", c)).

test(comments_left_out_notices_kept) :-
    program(Text), ir(Text, [format(md)], Doc), !,
    assertion(Doc.notices == ["Copyright 2026 Example Ltd. All rights reserved.\nLicensed under the Apache License, Version 2.0."]),
    readable_document(Text, [format(html), date('2026-10-28')], R),
    assertion(sub_string(R.content, _, _, _, "Copyright 2026 Example Ltd.")),
    assertion(\+ sub_string(R.content, _, _, _, "private note")),
    assertion(\+ sub_string(R.content, _, _, _, "The main rule")).

test(comments_on_request) :-
    program(Text),
    readable_document(Text, [format(html), comments(true), date('2026-10-28')], R),
    assertion(sub_string(R.content, _, _, _, "private note")),
    assertion(sub_string(R.content, _, _, _, "The main rule")),
    %  a notice is not shown twice
    aggregate_all(count, sub_string(R.content, _, _, _, "All rights reserved"), N),
    assertion(N =< 2).

test(every_internal_link_lands) :-
    program(Text),
    forall(member(F, [html, md]),
           ( readable_document(Text, [format(F), date('2026-10-28')], R),
             links_land(R.content) )).

test(index_lists_each_template) :-
    program(Text), ir(Text, [], Doc),
    length(Doc.index, 3),
    member(E, Doc.index), E.text == "a person is eligible", !,
    assertion(E.defined \== []).

test(decision_table_is_a_table) :-
    readable_document_of('../examples/regulatory/otherwise_table.le', html, R),
    assertion(sub_string(R.content, _, _, _, "<table>")),
    assertion(sub_string(R.content, _, _, _, "<td>&gt; 1 and &lt;= 10</td>")).

test(lps_sentences_have_kinds) :-
    readable_document_of('fixtures/lps/badlight.le', md, _),
    file_text('fixtures/lps/goat.le', Text),
    ir(Text, [base('fixtures/lps')], Doc), !,
    assertion(Doc.target == lps),
    statements(Doc, Ss),
    findall(K, ( member(B, Ss), get_dict(kind, B, K) ), Ks),
    assertion(memberchk(law, Ks)),
    assertion(memberchk(initially, Ks)),
    assertion(memberchk(template_fluent, Ks)).

test(word_document_is_well_formed) :-
    program(Text),
    readable_document(Text, [format(docx), date('2026-10-28')], R),
    assertion(R.encoding == "base64"),
    base64(Bytes, R.content),
    tmp_file_stream(binary, File, S), write(S, Bytes), close(S),
    setup_call_cleanup(zip_open(File, read, Z, []),
                       ( zip_entry_text(Z, 'word/document.xml', Xml),
                         zip_entry_text(Z, 'word/styles.xml', Styles) ),
                       zip_close(Z)),
    delete_file(File),
    xml_ok(Xml), xml_ok(Styles),
    assertion(sub_string(Xml, _, _, _, "w:bookmarkStart")),
    assertion(sub_string(Xml, _, _, _, "<w:hyperlink w:anchor=")),
    assertion(sub_string(Xml, _, _, _, "Copyright 2026 Example Ltd.")),
    %  every internal hyperlink has its bookmark
    findall(A, sub_anchor(Xml, "w:anchor=\"", A), As),
    forall(member(A, As),
           ( format(string(P), "w:name=\"~w\"", [A]), assertion(sub_string(Xml, _, _, _, P)) )).

test(operation_reads_an_example) :-
    handle_operation(_{token: "myToken123", operation: "readableDocument",
                       source: "citizenship", format: "md"}, R),
    assertion(sub_string(R.content, _, _, _, "# citizenship")),
    assertion(R.fileName == "citizenship.md").

test(operation_reads_editor_text) :-
    program(Text),
    handle_operation(_{token: "myToken123", operation: "readableDocument",
                       text: Text, format: "html", style: "legal"}, R),
    assertion(sub_string(R.content, _, _, _, "style-legal")).

:- end_tests(readable).

has_seg(Segs, Text, Class) :-
    member(S, Segs), get_dict(text, S, Text), get_dict(class, S, Class), !.

readable_document_of(Rel, Format, R) :-
    file_text(Rel, Text),
    file_directory_name(Rel, Dir),
    readable_document(Text, [format(Format), base(Dir), name(Rel), date('2026-10-28')], R).

file_text(Rel, Text) :-
    module_property(test_readable, file(Me)), file_directory_name(Me, D),
    directory_file_path(D, Rel, P),
    read_file_to_string(P, Text, []).

links_land(Content) :-
    findall(A, sub_until(Content, "href=\"#", "\"", A), As),
    findall(A, sub_until(Content, "](#", ")", A), Bs),
    append(As, Bs, Cs0), sort(Cs0, Cs),
    forall(member(A, Cs),
           (   format(string(P), "id=\"~w\"", [A]),
               (   sub_string(Content, _, _, _, P) -> true
               ;   format(user_error, "no anchor for #~w~n", [A]), fail
               ) )).

sub_anchor(Content, Prefix, A) :- sub_until(Content, Prefix, "\"", A).

sub_until(Content, Prefix, End, A) :-
    sub_string(Content, B, L, _, Prefix), S is B + L,
    sub_string(Content, S, _, 0, Rest),
    (   sub_string(Rest, E, 1, _, End) -> true ; string_length(Rest, E) ),
    sub_string(Rest, 0, E, _, A).

zip_entry_text(Z, Name, Text) :-
    zipper_goto(Z, file(Name)),
    zipper_open_current(Z, S, []),
    set_stream(S, encoding(utf8)),
    read_string(S, _, Text),
    close(S).

xml_ok(Xml) :-
    open_string(Xml, S),
    catch(load_structure(S, _, [dialect(xml), space(preserve)]), E,
          ( print_message(error, E), fail )),
    close(S).

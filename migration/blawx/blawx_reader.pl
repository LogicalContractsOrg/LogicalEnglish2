/** <module> Reading a Blawx project: the Act, its sections' s(CASP), its tests

    A Blawx project (an example of Blawx v1.6.22-alpha, or a `.blawx`
    export: the same YAML of Django fixtures) holds one `blawx.ruledoc` —
    the legislation in Blawx's "Clean" markdown (rule_text) — one
    `blawx.workspace` per section, whose `scasp_encoding` is the s(CASP)
    Blawx generated from that section's blocks, and `blawx.blawxtest`
    entries, each an s(CASP) text of facts, `#abducible` lines and one
    `?- query.`.

        blawx_project(+File, -Project)

    Project = project(Title, RuleDocName, RuleText, Sections, Tests):
      Sections = [section(Id, Clauses)], in the file's order;
      Tests    = [test(Name, Clauses, Query)], Query = query(Goal, Bindings)
                 or none;
      Clause   = c(Term, Bindings, Comments): the term read with s(CASP)'s
                 operators, its variable names (Name = Var) and the comment
                 lines just before it.
    A term Blawx wrote that does not parse (Blawx's generator has typos in
    some boilerplate) is c(syntax_error(Text), [], []).
*/

:- module(blawx_reader, [blawx_project/2, blawx_text_clauses/2, section_locator/2,
                         section_constant/2, is_blawx_project/1]).

:- use_module(library(yaml)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).

%   s(CASP)'s operators, in a module of their own (as le_writer reads them).
:- op(1150, fx, blawx_ops:(#)).
:- op(1100, fx, blawx_ops:pred).
:- op(1100, fx, blawx_ops:abducible).
:- op(1000, xfx, blawx_ops:(::)).
:- op(900, fy, blawx_ops:not).
:- op(700, xfx, blawx_ops:(#=)).  :- op(700, xfx, blawx_ops:(#<>)).
:- op(700, xfx, blawx_ops:(#<)).  :- op(700, xfx, blawx_ops:(#>)).
:- op(700, xfx, blawx_ops:(#=<)). :- op(700, xfx, blawx_ops:(#>=)).

%!  is_blawx_project(+File) is semidet.
is_blawx_project(File) :-
    exists_file(File),
    catch(yaml_read(File, DOM), _, fail),
    is_list(DOM),
    member(E, DOM), is_dict(E), get_dict(model, E, M), M == "blawx.ruledoc", !.

%!  blawx_project(+File, -Project) is det.
blawx_project(File, project(Title, Name, Text, Sections, Tests)) :-
    yaml_read(File, DOM),
    (   member(R, DOM), R.model == "blawx.ruledoc"
    ->  F = R.fields, Name = F.ruledoc_name, Text0 = F.rule_text
    ;   throw(error(format("~w holds no Blawx rule document", [File]), _))
    ),
    text_title(Text0, Name, Title),
    normalize_newlines(Text0, Text),
    findall(section(Id, Cs),
            ( member(W, DOM), W.model == "blawx.workspace",
              atom_string(Id, W.fields.workspace_name),
              blawx_text_clauses(W.fields.scasp_encoding, Cs) ),
            Sections),
    findall(test(TN, Cs, Q),
            ( member(T, DOM), T.model == "blawx.blawxtest",
              atom_string(TN, T.fields.test_name),
              blawx_text_clauses(T.fields.scasp_encoding, Cs0),
              test_query(Cs0, Cs, Q) ),
            Tests).

%   The Act's title is the first line of its text (Blawx's rule_text starts
%   with it); the rule document's name otherwise.
text_title(Text, Name, Title) :-
    split_string(Text, "\n", " \r\t", [First|_]),
    (   First \== "" -> Title = First ; Title = Name ).

normalize_newlines(T0, T) :-
    split_string(T0, "\n", "\r", Ls), atomic_list_concat(Ls, '\n', A), atom_string(A, T).

%   The query, out of the clauses; its comments stay, as c('$comments', [], Lines).
test_query(Cs0, Cs, Q) :-
    (   select(c((?- G), Bs, Cm), Cs0, Cs1)
    ->  Q = query(G, Bs), append(Cs1, [c('$comments', [], Cm)], Cs)
    ;   Cs = Cs0, Q = none
    ).

%!  blawx_text_clauses(+Text, -Clauses) is det.
blawx_text_clauses(Text, Clauses) :-
    (   Text == "" -> Clauses = []
    ;   setup_call_cleanup(open_string(Text, In),
                           read_all(Text, In, Clauses),
                           close(In))
    ).

read_all(Text, In, Cs) :-
    character_count(In, C0),
    catch(read_term(In, T, [variable_names(Bs), comments(Cm), module(blawx_ops),
                            term_position(_)]),
          E, ( E = error(syntax_error(_), _) -> T = '$syntax_error' ; throw(E) )),
    (   T == end_of_file -> Cs = []
    ;   T == '$syntax_error'
    ->  skip_to_full_stop(In, _),
        character_count(In, C1), L is C1 - C0,
        sub_string(Text, C0, L, _, Bad0), normalize_space(string(Bad), Bad0),
        Cs = [c(syntax_error(Bad), [], [])|Rest], read_all(Text, In, Rest)
    ;   comment_lines(Cm, Lines),
        Cs = [c(T, Bs, Lines)|Rest], read_all(Text, In, Rest)
    ).

%   After a syntax error the reader has stopped inside the term; the rest of
%   it, up to its full stop, is dropped.
skip_to_full_stop(In, Text) :-
    read_line_to_string(In, L),
    (   L == end_of_file -> Text = ""
    ;   sub_string(L, _, 1, 0, ".") -> Text = L
    ;   skip_to_full_stop(In, T1), string_concat(L, T1, Text)
    ).

comment_lines(Cm, Lines) :-
    findall(L, ( member(_-C, Cm), string(C), comment_text(C, L) ), Lines0),
    append(Lines0, Lines1), exclude(==(""), Lines1, Lines).

comment_text(C, Lines) :-
    split_string(C, "\n", "", Ls),
    maplist(strip_percent, Ls, Lines).

strip_percent(L0, L) :-
    string_codes(L0, Cs0), phrase(percents, Cs0, Cs1), string_codes(L1, Cs1),
    normalize_space(string(L), L1).
percents --> "%", !, percents.
percents --> " ", !, percents.
percents --> [].

		 /*******************************
		 *           SECTIONS           *
		 *******************************/

%!  section_locator(+SectionId, -Locator) is det.
%
%   `sec_34__subsec_1__para_b_section` is section 34(1)(b); a span
%   (`sec_5__span_pingu_section`) is the words `pingu` of section 5; the
%   root is the Act as a whole.
section_locator(root_section, 'the Act as a whole') :- !.
section_locator(Id, Loc) :-
    section_parts(Id, Parts, Span),
    Parts = [N|Subs],
    maplist([P, S]>>format(string(S), "(~w)", [P]), Subs, SubS),
    atomic_list_concat(SubS, SubA),
    (   Span == none -> format(atom(Loc), 'section ~w~w', [N, SubA])
    ;   format(atom(Loc), 'section ~w~w, the words "~w"', [N, SubA, Span])
    ).

%!  section_constant(+SectionId, -Constant) is det.
%
%   The provision as an LE constant: `section_34_1_b`, `section_5_pingu`.
section_constant(root_section, the_act) :- !.
section_constant(Id, C) :-
    section_parts(Id, Parts, Span),
    ( Span == none -> All = Parts ; append(Parts, [Span], All) ),
    atomic_list_concat([section|All], '_', C).

section_parts(Id, Parts, Span) :-
    atom_string(Id, S0),
    ( string_concat(S1, "_section", S0) -> true ; S1 = S0 ),
    atomic_list_concat(Segs, '__', S1),
    foldl(section_seg, Segs, []-none, Parts0-Span),
    reverse(Parts0, Parts1),
    ( Parts1 == [] -> Parts = [S1] ; Parts = Parts1 ).

section_seg(Seg, Ps-Sp, Ps1-Sp1) :-
    atomic_list_concat(Ws, '_', Seg),
    (   Ws = [span|Rest] -> atomic_list_concat(Rest, ' ', Sp1), Ps1 = Ps
    ;   Ws = [K, V|_], memberchk(K, [sec, subsec, para, subpara, clause, subclause]) -> Ps1 = [V|Ps], Sp1 = Sp
    ;   Ps1 = [Seg|Ps], Sp1 = Sp
    ).

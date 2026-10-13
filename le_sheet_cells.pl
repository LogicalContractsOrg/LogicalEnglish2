/** <module> The cells of a service: which cells of a workbook answer a template

    A workbook declared as a service (docs/user/reference/language.md §17.6,
    the `sheet:` address of le_services.pl) is told which of its cells a
    template reads and which cell holds the answer by a section of the
    program, written in Logical English:

        the knowledge base child support includes these services:
            oklahoma at sheet:sources/ok_child_support.xlsm as a calculator.

        the templates are:
            the father's obligation for *a number* children with incomes *a number* and *a number* is *an amount*; via service oklahoma.

        the cells of service oklahoma are:
            the sheet is "Child Support Comp Entry".
            the father's obligation for "B4" children with incomes "C5" and "D5" is "C17".
            the cell "B30" is "monthly".

    Each sentence that is not one of the two fixed forms is an instance of a
    template the service backs, with a cell reference in each place: the
    values a goal gives for the first places are written into those cells, the
    workbook is recalculated, and the last place's cell is the answer. `the
    sheet is` names the sheet of the references that do not name their own
    ("'Rates'!B2"), the workbook's first sheet otherwise; `the cell ... is`
    gives a cell a value for every question. The sentence forms are keyword
    phrases of i18n/keywords.csv (category `service_cells`), so the section
    is written in the program's language.

    As for a view (le_views.pl), the parser keeps the lines as tokens
    (le_grammar.pl, section service_cells/4); record_cells_source/5 splits
    them into sentences, and they are read against the whole loaded program
    when a goal first asks the workbook (sheet_cells/4) and by the verifier
    (cells_issue/2).
*/

:- module(le_sheet_cells, [
    record_cells_source/5,  % +M, +Name, +Rows, +Start, +End
    sheet_cells/4,          % +KM, +Service, +F/A, -Cells:dict
    cells_issue/2           % +KB, -Issue
]).

:- use_module(le_i18n).
:- use_module(library(apply)).
:- use_module(library(lists)).
:- use_module(library(pcre)).

% ---------------------------------------------------------------------------
% Recording (second pass)
% ---------------------------------------------------------------------------

%!  record_cells_source(+M, +Name, +Rows, +Start, +End) is det.
%
%   Recorded as le_sheet_cells_source(Name, Sentences, Start, End), Sentences
%   a list of sentence(Tokens, S, E), as le_views records a view.
record_cells_source(M, Name, Rows, Start, End) :-
    (   nonvar(M), M \== (-)
    ->  findall(T, ( member(row(Ts, _, _), Rows), member(T, Ts) ), Tokens0),
        exclude(le_grammar:is_indent_or_comment, Tokens0, Tokens),
        le_views:split_sentences(Tokens, Sentences),
        assertz(M:le_sheet_cells_source(Name, Sentences, Start, End))
    ;   true
    ).

% ---------------------------------------------------------------------------
% The cells a goal asks
% ---------------------------------------------------------------------------

%!  sheet_cells(+KM, +Service, +FA, -Cells:dict) is semidet.
%
%   Cells = _{sheet: Sheet|null, inputs: [Ref, ...], output: Ref, fixed:
%   [[Ref, Value], ...]}: what the workbook of Service is asked for a goal
%   on template F/A. Fails when the program does not say.
sheet_cells(KM, Service, F/A, Cells) :-
    compiled(KM, Service, Items, _),
    member(item(answers(F/A, Refs), _, _), Items),
    append(Inputs, [Output], Refs), !,
    ( member(item(sheet(Sheet), _, _), Items) -> true ; Sheet = null ),
    findall([Ref, V], member(item(fixed(Ref, V), _, _), Items), Fixed),
    Cells = _{sheet: Sheet, inputs: Inputs, output: Output, fixed: Fixed}.

% Read once per loaded program: the sentences of all the sections of the
% service, in order, with their issues.
compiled(KM, Service, Items, Issues) :-
    catch(KM:le_sheet_cells_compiled(Service, Items, Issues), _, fail), !.
compiled(KM, Service, Items, Issues) :-
    current_predicate(KM:le_sheet_cells_source/4),
    findall(S, ( KM:le_sheet_cells_source(Service, Ss, _, _), member(S, Ss) ), Sents),
    Sents \== [],
    catch(le_kbs:ensure_kb_language(KM), _, true),
    findall(D, KM:le_dict(D), Dicts),
    le_grammar:prepare_templates(Dicts, Templates),
    foldl(compile_sentence(KM, Templates, Service), Sents, st([], []), st(Items0, Issues0)),
    reverse(Items0, Items),
    reverse(Issues0, Issues),
    assertz(KM:le_sheet_cells_compiled(Service, Items, Issues)).

compile_sentence(KM, Templates, Service, sentence(Toks, S, E), st(Items, Issues), st(Items1, Issues1)) :-
    (   Toks == []
    ->  Items1 = Items, Issues1 = Issues
    ;   catch(phrase(fixed_sentence(Item), Toks), _, fail)
    ->  check_refs(Item, Service, Toks, S, E, New),
        Items1 = [item(Item, S, E)|Items], append(New, Issues, Issues1)
    ;   catch(le_grammar:parse_literal(Toks, Templates, [], _, Literal0, _, true), _, fail),
        le_views:strip_extra(Literal0, Literal),
        compound(Literal), functor(Literal, F, A), F \== unknown_template
    ->  sentence_text(Toks, Text),
        Literal =.. [_|Args],
        (   \+ ( current_predicate(KM:le_service_template/2), KM:le_service_template(F/A, Service) )
        ->  issue(cells_not_backed, [name-Service, text-Text], S, E, I),
            Items1 = Items, Issues1 = [I|Issues]
        ;   member(item(answers(F/A, _), _, _), Items)
        ->  issue(cells_twice, [name-Service, text-Text], S, E, I),
            Items1 = Items, Issues1 = [I|Issues]
        ;   maplist(cell_text, Args, Refs)
        ->  Items1 = [item(answers(F/A, Refs), S, E)|Items], Issues1 = Issues
        ;   member(Arg, Args), \+ cell_text(Arg, _)
        ->  value_text(Arg, V),
            issue(cells_not_a_cell, [name-Service, value-V], S, E, I),
            Items1 = Items, Issues1 = [I|Issues]
        )
    ;   sentence_text(Toks, Text),
        issue(cells_unknown_sentence, [name-Service, text-Text], S, E, I),
        Items1 = Items, Issues1 = [I|Issues]
    ).

check_refs(fixed(Ref, _), Service, _, S, E, Issues) :- !,
    (   cell_text(Ref, _) -> Issues = []
    ;   issue(cells_not_a_cell, [name-Service, value-Ref], S, E, I), Issues = [I]
    ).
check_refs(_, _, _, _, _, []).

kw(Key) --> le_grammar:kw(Key).

fixed_sentence(sheet(Sheet)) --> kw(cells_sheet), [doubleQuoteString(S0, _)], { atom_string(S0, Sheet) }.
fixed_sentence(fixed(Ref, V)) --> kw(cells_cell), [doubleQuoteString(R0, _)], kw(marker_is), fixed_value(V),
    { atom_string(R0, Ref) }.

fixed_value(V) --> [doubleQuoteString(V0, _)], !, { atom_string(V0, V) }.
fixed_value(V) --> [number(V, _)], { number(V) }.
fixed_value(V) --> [punctuation('-', _), number(N, _)], { number(N), V is -N }.

%   A place filled with a cell reference: "B4", "$B$4", "Rates!B4" or
%   "'Child Support'!B4" (a sheet name with spaces in single quotes).
cell_text(Arg, Ref) :-
    ( string(Arg) ; atom(Arg) ), !,
    atom_string(Arg, Ref),
    re_match("^(?:(?:'(?:[^']|'')+'|[A-Za-z_][A-Za-z0-9_.]*)!)?\\$?[A-Za-z]{1,3}\\$?[1-9][0-9]*$", Ref).

value_text(V, T) :- ( var(V) -> T = "_" ; format(string(T), "~w", [V]) ).

sentence_text(Toks, Text) :- le_views:sentence_text(Toks, Text).

% ---------------------------------------------------------------------------
% Issues (the verifier)
% ---------------------------------------------------------------------------

%!  cells_issue(+KB, -Issue) is nondet.
%
%   issue(Type, Description, Fix, Start, End) for each problem of the cells
%   of a service, and of a workbook service the program asks.
cells_issue(KB, Issue) :-
    atom(KB), KB \== none,
    catch(le_kbs:ensure_kb_language(KB), _, true),
    (   % a sentence that is not understood, or not about the service
        current_predicate(KB:le_sheet_cells_source/4),
        setof(N, Ss^S^E^(KB:le_sheet_cells_source(N, Ss, S, E)), Names),
        member(Name, Names),
        compiled(KB, Name, _, Issues),
        member(Issue, Issues)
    ;   % cells of a service that is not a workbook the program declares
        current_predicate(KB:le_sheet_cells_source/4),
        KB:le_sheet_cells_source(Name, _, S, E),
        \+ ( current_predicate(KB:le_service/3), KB:le_service(Name, Address, _),
             atom_concat('sheet:', _, Address) ),
        issue(cells_unknown_service, [name-Name], S, E, Issue)
    ;   % a template a workbook answers, with no cells said for it
        sheet_service(KB, Name, _, _),
        current_predicate(KB:le_service_template/2),
        KB:le_service_template(F/A, Name),
        \+ sheet_cells(KB, Name, F/A, _),
        (   catch(le_kbs:template_of(KB, F, A, Dict, Label), _, fail)
        ->  le_verifier:template_source(KB, Dict, S, E)
        ;   Label = F, S = 0, E = 0
        ),
        issue(cells_missing, [name-Name, text-Label], S, E, Issue)
    ;   % a port after '#': the manifests that address once named
        sheet_service(KB, Name, Address, Ref),
        once(sub_atom(Address, B, 1, _, '#')), B1 is B + 1, sub_atom(Address, B1, _, 0, Port),
        service_location(KB, Ref, S, E),
        issue(sheet_address_port, [name-Name, port-Port], S, E, Issue)
    ;   % the workbook is not where the address says
        sheet_service(KB, Name, Address0, Ref),
        \+ sub_atom(Address0, _, _, _, '#'),
        catch(le_services:resolve_address(KB, Address0, Address), _, fail),
        atom_concat('sheet:', File, Address),
        is_absolute_file_name(File), \+ exists_file(File),
        atom_concat('sheet:', Rel, Address0),
        service_location(KB, Ref, S, E),
        issue(sheet_no_workbook, [name-Name, file-Rel], S, E, Issue)
    ).

sheet_service(KB, Name, Address, Ref) :-
    current_predicate(KB:le_service/3),
    clause(KB:le_service(Name, Address, _), true, Ref),
    atom_concat('sheet:', _, Address).

service_location(KB, Ref, S, E) :-
    (   current_predicate(KB:le_source_info/4), KB:le_source_info(Ref, S0, E0, service)
    ->  S = S0, E = E0
    ;   S = 0, E = 0
    ).

issue(Type, Pairs, S, E, issue(Type, Desc, Fix, S, E)) :-
    atom_concat(Type, '_desc', D), atom_concat(Type, '_fix', F),
    le_msg(D, Pairs, Desc),
    le_msg(F, Pairs, Fix).

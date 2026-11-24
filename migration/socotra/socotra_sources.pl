/** <module> Where a Socotra twin's rules come from: documents and passages

    Every rule of a twin cites the source file it was translated from
    (`rule premium_1 with provenance "Pet/policy/exposures/Pet/perils/
    accident.premium.liquid"`). This module makes those citations
    navigable:

      - each cited file is a DOCUMENT of the twin — for the product library,
        its page on GitHub at the pinned commit (`is published at`) and its
        raw text there (`the text of ... is at`), so nothing of the carrier's
        is redistributed; for an imported configuration, the copy beside
        the program;
      - each rule points at its PASSAGE of the file: the Liquid lines that
        compute it, quoted (`confer "{% assign ... %}"`, which the source
        viewer highlights) when the passage is short and quotable, else a
        line locator (`at lines 12 to 20`).

    The passage is found in the script's text from what the rule is: the
    k-th quantity of a variable V (rule_label/4's `<script>_<v>_<k>`) is at
    the lines assigning V, widened to the if/case block around them; an
    output rule (`..._yearly_premium_final`) at the line of its set_* filter;
    the i-th add_* output (`..._note_one_final`) at the i-th add_* filter.
*/

:- module(socotra_sources, [
    source_documents/1,        % -Mode: library(Sha) | local
    set_source_documents/1,    % +Mode
    locate_rules/3,            % +RootDir, +Items0, -Items
    document_items/3           % +Items, +Extra, -DocumentItems
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).
:- use_module(library(uri)).
:- use_module(library(aggregate)).

:- dynamic mode/1.

%   The commit of socotra/product-library the twins were translated from
%   (fetch_sources.sh).
library_sha('df4a7f851ac6e3a79ecf6b2c007d75bd6c22c9e8').

source_documents(M) :- ( mode(M0) -> M = M0 ; library_sha(S), M = library(S) ).
set_source_documents(M) :- retractall(mode(_)), assertz(mode(M)).

		 /*******************************
		 *          DOCUMENTS           *
		 *******************************/

%!  document_items(+Items, +Extra, -Docs) is det.
%
%   One document item per file the rules cite, plus Extra
%   (document(Name, Options) items of the caller: the rating quotes).
document_items(Items, Extra, Docs) :-
    findall(F, ( member(rule(_, _, Os), Items), memberchk(provenance(P), Os),
                 memberchk(as_stated_in(F), P) ), Fs0),
    sort(Fs0, Fs),
    source_documents(Mode),
    maplist(file_document(Mode), Fs, Docs0),
    append(Docs0, Extra, Docs).

%   The text is the copy in sources/ beside the twin (the editors' Show the
%   Original lists that folder); a library file is also published on GitHub
%   at the pinned commit.
file_document(library(Sha), F, document(F, [url(Blob), text(Local)])) :- !,
    encoded_path(F, E),
    format(string(Blob), "https://github.com/socotra/product-library/blob/~w/~w", [Sha, E]),
    format(string(Local), "sources/~w", [F]).
file_document(local, F, document(F, [text(Local)])) :-
    format(string(Local), "sources/~w", [F]).

encoded_path(F, E) :-
    atomic_list_concat(Segs, '/', F),
    maplist([S, ES]>>uri_encoded(path, S, ES), Segs, ESegs),
    atomic_list_concat(ESegs, '/', E).

		 /*******************************
		 *           PASSAGES           *
		 *******************************/

%!  locate_rules(+Root, +Items0, -Items) is det.
%
%   Root: the directory the cited paths are relative to (the product
%   library). A rule whose passage is found gets `at(Locator)` or
%   `confer(Quote)` in its provenance; the others are left as they are.
locate_rules(Root, Items0, Items) :-
    findall(L, ( member(rule(_, _, Os), Items0), memberchk(label(L), Os) ), Labels),
    b_setval(socotra_labels, Labels),
    maplist(locate_item(Root), Items0, Items).

locate_item(Root, rule(H, B, Os0), rule(H, B, Os)) :-
    select(provenance(P0), Os0, provenance(P), Os),
    P0 = [as_stated_in(File)],
    memberchk(label(Label), Os0),
    file_extension_ok(File),
    atomic_list_concat([Root, '/', File], Path),
    exists_file(Path),
    script_lines(Path, Lines),
    passage(File, Lines, Label, A, B1), !,
    passage_citation(Lines, A, B1, Cite),
    append(P0, [Cite], P).
locate_item(_, I, I).

file_extension_ok(File) :- file_name_extension(_, liquid, File).

:- dynamic cached_lines/2.
script_lines(Path, Lines) :-
    (   cached_lines(Path, L0) -> Lines = L0
    ;   read_file_to_string(Path, S, [encoding(utf8)]),
        split_string(S, "\n", "\r", Lines),
        assertz(cached_lines(Path, Lines))
    ).

%   The quotation of a short passage without double quotes (LE strings
%   cannot hold them), else its lines.
passage_citation(Lines, A, B, Cite) :-
    findall(T, ( between(A, B, I), nth1(I, Lines, L), normalize_space(string(T), L), T \== "" ), Ts),
    atomic_list_concat(Ts, ' ', Q0), atom_string(Q0, Q),
    (   B - A =< 12, string_length(Q, N), N =< 600, N > 0,
        \+ sub_string(Q, _, _, _, "\"")
    ->  Cite = confer(Q)
    ;   A =:= B -> format(atom(Loc), 'line ~w', [A]), Cite = at(Loc)
    ;   format(atom(Loc), 'lines ~w to ~w', [A, B]), Cite = at(Loc)
    ).

%   passage(+File, +Lines, +Label, -First, -Last)
passage(File, Lines, Label, A, B) :-
    label_key(File, Lines, Label, Key),
    key_lines(Key, Lines, Ns), Ns \== [],
    min_list(Ns, A0), max_list(Ns, B0),
    widen(Key, Lines, A0, B0, A, B).

%   What the label names: assign(V) — a quantity of the variable V;
%   filter(F) — the output of a set_* filter; add(I) — the i-th add_*
%   output (and its description, for a fee).
label_key(File, Lines, Label, Key) :-
    (   set_var(F, Var),
        socotra_reader:rule_label(File, Var, final, Label)
    ->  Key = filter(F)
    ;   set_var(F, Var), between(1, 40, K),         % a branch merge of a set_* filter's value
        socotra_reader:rule_label(File, Var, K, Label)
    ->  Key = filter_merge(F)
    ;   add_count(Lines, NAdd), NAdd > 0,
        between(1, NAdd, I),
        member(Kind, [year_commission, month_commission, note, fee]),
        format(atom(Tag), '~w_~w', [Kind, I]),
        socotra_reader:rule_label(File, Tag, final, L0),
        ( Label == L0 ; atom_concat(L0, '_description', Label) )
    ->  Key = add(I)
    ;   assigned_vars(Lines, Vs),
        member(V, Vs), between(1, 40, K),
        socotra_reader:rule_label(File, V, K, Label)
    ->  b_getval(socotra_labels, Labels),
        aggregate_all(count, ( between(1, 40, K1), socotra_reader:rule_label(File, V, K1, L1),
                               memberchk(L1, Labels) ), NRules),
        Key = assign(V, K, NRules)
    ).

set_var(F, V) :-
    member(F-V, [set_year_premium-'$year_premium', set_year_technical_premium-'$year_technical_premium',
                 set_month_premium-'$month_premium', set_month_technical_premium-'$month_technical_premium',
                 set_underwriting_decision-'$decision', set_peril_tax-'$tax']).

key_lines(assign(V, _, _), Lines, Ns) :-
    findall(N, ( nth1(N, Lines, L), line_tag(L, T), tag_assigns(T, V) ), Ns0), sort(Ns0, Ns).
key_lines(filter_merge(F), Lines, Ns) :- key_lines(filter(F), Lines, Ns).
key_lines(filter(F), Lines, Ns) :-
    findall(N, ( nth1(N, Lines, L), word_in(F, L) ), Ns).
key_lines(add(I), Lines, [N]) :-
    add_occurrences(Lines, Ns), nth1(I, Ns, N).

%   The k-th of n quantities of a variable: the reader numbers a variable's
%   quantities from its last value back (the output forces the latest value,
%   which forces the one before, ...), and each is the merge of one block
%   (if/case/unless/for) assigning it. So when the file has as many blocks
%   assigning V as the twin has quantities of V, the k-th quantity is the
%   k-th block from the end — with the plain assignments of V just before
%   it, which give its "otherwise" value. Otherwise, every line assigning V,
%   widened to the blocks around them.
widen(assign(V, K, N), Lines, A0, B0, A, B) :- !,
    depths(Lines, Ds),
    blocks_assigning(Lines, Ds, V, Blocks),
    length(Blocks, NB),
    (   NB =:= N, N > 0
    ->  I is N - K + 1,
        nth1(I, Blocks, S-E),
        ( I > 1 -> I0 is I - 1, nth1(I0, Blocks, _-PrevEnd) ; PrevEnd = 0 ),
        findall(L, ( nth1(L, Lines, Ln), L > PrevEnd, L < S, nth1(L, Ds, 0-_),
                     line_tag(Ln, T), tag_assigns(T, V) ), Plain),
        ( Plain = [P|_] -> A = P ; A = S ),
        B = E
    ;   nth1(A0, Ds, D0-_), nth1(B0, Ds, D1-_),
        ( D0 > 0 -> opening(Ds, A0, D0, A) ; A = A0 ),
        ( D1 > 0 -> closing(Ds, B0, D1, B) ; B = B0 )
    ).
widen(filter_merge(_), Lines, A0, B0, A, B) :- !,
    depths(Lines, Ds),
    nth1(A0, Ds, D0-_), nth1(B0, Ds, D1-_),
    ( D0 > 0 -> opening(Ds, A0, D0, A) ; A = A0 ),
    ( D1 > 0 -> closing(Ds, B0, D1, B) ; B = B0 ).
widen(_, _, A, B, A, B).

%   The top-level blocks (opened at depth 0) with a line assigning V.
blocks_assigning(Lines, Ds, V, Blocks) :-
    findall(S-E, ( nth1(S, Ds, 0-DE), DE > 0,
                   closing(Ds, S, 1, E),
                   once(( between(S, E, L), nth1(L, Lines, Ln), line_tag(Ln, T), tag_assigns(T, V) )) ),
            Blocks).

%   Ds: per line, Depth-DepthAfter (depth of if/case/unless/for nesting at
%   its start and end).
depths(Lines, Ds) :- foldl(line_depth, Lines, Ds, 0, _).
line_depth(L, D-D1, D, D1) :-
    findall(T, line_tag(L, T), Ts),
    foldl(tag_depth, Ts, D, D1).
tag_depth(T, D0, D) :-
    (   tag_word(T, W), memberchk(W, [if, case, unless, for]) -> D is D0 + 1
    ;   tag_word(T, W), memberchk(W, [endif, endcase, endunless, endfor]) -> D is max(0, D0 - 1)
    ;   D = D0
    ).

%   The line opening the block the line A is in (depth D at its start).
opening(Ds, A, D, O) :-
    A1 is A - 1,
    (   A1 >= 1, nth1(A1, Ds, DS-DE), ( DS < D, DE >= D ) -> O = A1
    ;   A1 >= 1 -> opening(Ds, A1, D, O)
    ;   O = A
    ).
closing(Ds, B, D, C) :-
    length(Ds, N), B1 is B + 1,
    (   B1 =< N, nth1(B1, Ds, _-DE), DE < D -> C = B1
    ;   B1 =< N -> closing(Ds, B1, D, C)
    ;   C = B
    ).

		 /*******************************
		 *         LIQUID TAGS          *
		 *******************************/

%   The contents of the {% ... %} tags of a line.
line_tag(L, T) :-
    sub_string(L, B, 2, _, "{%"),
    B2 is B + 2, sub_string(L, B2, _, 0, Rest),
    (   sub_string(Rest, E, 2, _, "%}") -> sub_string(Rest, 0, E, _, T0) ; T0 = Rest ),
    string_codes(T0, Cs0), ( Cs0 = [0'-|Cs1] -> true ; Cs1 = Cs0 ),
    string_codes(T1, Cs1), normalize_space(string(T), T1).

tag_word(T, W) :- split_string(T, " ", "", [W0|_]), atom_string(W, W0).

tag_assigns(T, V) :-
    split_string(T, " =", " ", Parts0), exclude(==(""), Parts0, ["assign", VS|_]),
    atom_string(V, VS).

assigned_vars(Lines, Vs) :-
    findall(V, ( member(L, Lines), line_tag(L, T), tag_assigns(T, V) ), Vs0),
    sort(Vs0, Vs).

%   W occurs in L as a word (not inside a longer identifier).
word_in(W, L) :-
    atom_string(W, WS), sub_string(L, B, N, A, WS),
    \+ ( B > 0, B1 is B - 1, sub_string(L, B1, 1, _, C), csym_string(C) ),
    \+ ( A > 0, E is B + N, sub_string(L, E, 1, _, C2), csym_string(C2) ), !.

csym_string(C) :- string_chars(C, [Ch]), char_type(Ch, csym).

add_filters([add_year_commission, add_month_commission, add_underwriting_note, add_fee]).

%   The line of each add_* filter, in order (a line with two, twice).
add_occurrences(Lines, Ns) :-
    add_filters(Fs),
    findall(N, ( nth1(N, Lines, L), member(F, Fs), atom_string(F, FS),
                 aggregate_all(count, sub_string(L, _, _, _, FS), C), between(1, C, _) ), Ns).

add_count(Lines, N) :- add_occurrences(Lines, Ns), length(Ns, N).

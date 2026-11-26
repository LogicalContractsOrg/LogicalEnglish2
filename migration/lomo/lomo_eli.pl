/** <module> The text of a provision from its ELI (step 6)

    eli_celex(+ELI, -CELEX)
        http://data.europa.eu/eli/reg/2016/679/art_33/par_1/oj -> 32016R0679
        (a regulation R, a directive L, a decision D; the act's number in
        four digits). Only acts with such an ELI: a proposal's ELI
        (`.../eli/dl/proc/...`) has no CELEX of this form.
    act_file(+CELEX, -File)
        The act as the Publications Office's repository (Cellar) serves it,
        in XHTML, by content negotiation on
        http://publications.europa.eu/resource/celex/<CELEX> (English). Kept
        in migration/lomo/.cache/eli/ (not in the repository). EUR-Lex itself
        answers automated clients with a challenge page; Cellar does not.
    provision_text(+ELI, -Text)
        The words of the article, paragraph or point that the ELI names, cut
        from the act by the ids of its XHTML (`art_33`, `033.001`), with the
        spaces made single.
    write_provision_texts(+ELIs, +Dir, -Documents)
        One text file per provision under Dir/sources/eli/, and the documents
        of the IR (`the text of "<ELI>" is at "sources/eli/..."`), so that a
        program that quotes a provision (`confer "..."`) has its quote
        checked, and File > Show the Original shows the provision.

    The texts of EU legislation may be reused with acknowledgement of the
    source (Commission Decision 2011/833/EU); each text file names it.

    Copyright Miguel Calejo; Apache License 2.0.
*/

:- module(lomo_eli, [eli_celex/2, act_file/2, provision_text/2, write_provision_texts/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(sgml)).
:- use_module(library(xpath)).
:- use_module(library(process)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).

:- dynamic here/1, dom_/2.
:- prolog_load_context(directory, D), retractall(here(D)), assertz(here(D)).

eli_celex(ELI, CELEX) :-
    eli_parts(ELI, Type, Year, Num, _),
    type_letter(Type, L),
    format(atom(CELEX), '3~w~w~|~`0t~w~4+', [Year, L, Num]).

type_letter(reg, 'R').
type_letter(dir, 'L').
type_letter(dec, 'D').
type_letter(reg_impl, 'R').
type_letter(reg_del, 'R').
type_letter(dir_impl, 'L').
type_letter(dir_del, 'L').
type_letter(dec_impl, 'D').
type_letter(dec_del, 'D').

%   eli_parts(+ELI, -Type, -Year, -Number, -Subdivisions)
eli_parts(ELI, Type, Year, Num, Subs) :-
    ( string(ELI) -> atom_string(A, ELI) ; A = ELI ),
    atomic_list_concat(Segs, '/', A),
    append(_, [eli, Type, Year, Num|Rest], Segs),
    type_letter(Type, _),
    atom_number(Year, _),
    include([S]>>( sub_atom(S, B, 1, _, '_'), sub_atom(S, 0, B, _, K), memberchk(K, [art, par, pnt, sub, anx]) ), Rest, Subs).

cache_dir(D) :- here(H), atomic_list_concat([H, '/.cache/eli'], D).

act_file(CELEX, File) :-
    cache_dir(D), make_directory_path(D),
    atomic_list_concat([D, '/', CELEX, '.xhtml'], File),
    (   exists_file(File) -> true
    ;   atomic_list_concat(['http://publications.europa.eu/resource/celex/', CELEX], URL),
        atomic_list_concat([File, '.part'], Part),
        process_create(path(curl), ['-sLf', '-o', Part, '-H', 'Accept: application/xhtml+xml', '-H', 'Accept-Language: eng', URL],
                       [process(Pid), stderr(null)]),
        process_wait(Pid, exit(0)),
        rename_file(Part, File)
    ).

act_dom(CELEX, DOM) :- dom_(CELEX, DOM), !.
act_dom(CELEX, DOM) :-
    act_file(CELEX, F),
    load_xml(F, DOM0, [space(remove), syntax_errors(quiet)]),
    strip_ns(DOM0, DOM),
    assertz(dom_(CELEX, DOM)).

provision_text(ELI, Text) :-
    eli_celex(ELI, CELEX),
    eli_parts(ELI, _, _, _, Subs),
    act_dom(CELEX, DOM),
    provision_element(DOM, Subs, El0),
    (   member(P, Subs), atom_concat('pnt_', L, P)
    ->  format(atom(Label), '(~w)', [L]),
        (   xpath(El0, //tr, Row), Row = element(_, _, Cells),
            include([C]>>( C = element(td, _, _) ), Cells, [First, Second|_]),
            element_text(First, FT), atom_string(Label, FT)
        ->  element_text(Second, T2), format(string(Text), "~w ~w", [Label, T2])
        ;   element_text(El0, Text)
        )
    ;   element_text(El0, Text)
    ).

strip_ns(element(N0, A, Cs0), element(N, A, Cs)) :- !,
    ( N0 = _:N -> true ; N = N0 ),
    maplist(strip_ns, Cs0, Cs).
strip_ns(X, X).

provision_element(DOM, Subs, El) :-
    (   member(S, Subs), atom_concat('art_', N, S) -> true ),
    atom_concat('art_', N, ArtId),
    xpath(DOM, //div(@id=ArtId), Art), !,
    (   member(P, Subs), atom_concat('par_', K, P)
    ->  paragraph_id(N, K, PId),
        (   xpath(Art, //div(@id=PId), El) -> true
        ;   row_of(Art, K, El) -> true              % a numbered point of a list: Article 2(1)
        ;   El = Art
        )
    ;   El = Art
    ).

row_of(El, K, element(div, [], [element(p, [], [Label]), Second])) :-
    format(atom(Label), '(~w)', [K]),
    xpath(El, //tr, element(_, _, Cells)),
    include([C]>>( C = element(td, _, _) ), Cells, [First, Second|_]),
    element_text(First, FT), atom_string(Label, FT), !.

%   Article 33, paragraph 1 -> "033.001"; Article 1a, paragraph 2 -> "01a.002"? the
%   Publications Office pads the article to three characters.
paragraph_id(N, K, Id) :-
    format(atom(A), '~|~`0t~w~3+', [N]),
    format(atom(P), '~|~`0t~w~3+', [K]),
    atomic_list_concat([A, '.', P], Id).

element_text(El, Text) :-
    findall(T, ( xpath(El, //text, T0), T0 = T ), _),
    phrase(texts(El), Parts),
    atomic_list_concat(Parts, ' ', A),
    normalize_space(string(Text), A).

texts(element(_, _, Cs)) --> !, texts_list(Cs).
texts(T) --> { atom(T) }, !, [T].
texts(T) --> { string(T) }, !, [T].
texts(_) --> [].
texts_list([]) --> [].
texts_list([C|Cs]) --> texts(C), texts_list(Cs).

%   The provisions a register cites, as documents beside it.
write_provision_texts(ELIs, Dir, Documents) :-
    atomic_list_concat([Dir, '/sources/eli'], SD), make_directory_path(SD),
    findall(document(ES, [text(Rel)]),
            ( member(E, ELIs), catch(provision_text(E, T), _, fail), T \== "",
              ( string(E) -> ES = E ; atom_string(E, ES) ),
              eli_file_name(ES, FN),
              atomic_list_concat(['sources/eli/', FN], Rel),
              atomic_list_concat([Dir, '/', Rel], Path),
              eli_celex(E, CELEX),
              setup_call_cleanup(open(Path, write, S, [encoding(utf8)]),
                  format(S, "~w~n~nSource: ~w (CELEX ~w), as the Publications Office of the European Union serves it at http://publications.europa.eu/resource/celex/~w. (c) European Union; reuse authorised, Commission Decision 2011/833/EU.~n", [T, ES, CELEX, CELEX]),
                  close(S)) ),
            Documents).

eli_file_name(ELI, FN) :-
    ( sub_string(ELI, B, _, _, "/eli/") -> B1 is B + 5, sub_string(ELI, B1, _, 0, R) ; R = ELI ),
    split_string(R, "/", "", Ps), atomic_list_concat(Ps, '_', A0),
    atom_concat(A0, '.txt', FN).

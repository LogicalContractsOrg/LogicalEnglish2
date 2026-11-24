/** <module> Writing the RUML twins

    build_collection(+Collection, +Filter): every rulemap of the collection
    (corpus:collection/3) whose file name contains Filter, written as a twin
    with its tests, its ledger, and its original under sources/. Its tests
    are the conformance tests of the format that name the rulemap (their
    `complete` mode; the `optimized` mode is the evaluator's, ruml_result.pl)
    and the cases ruml_cases.pl generates, answered by the oracle. A summary
    line per rulemap and a total go to runs/build-<collection>.txt.

    A rulemap that the reader rejects for a reason that changes what it
    means (an unknown required capability, a missing root, ...) is not
    built, and the log says why.
*/

:- module(ruml_build, [build_collection/2, build_file/5, collection_files/2, twin_root/2,
                       twin_name/3, rulemap_migration/4, fatal_issue/1, write_texts/3]).

:- use_module(library(filesex)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module('../le2_paths', [twins_dir/2, private_root/1]).
:- use_module(le2(le_migration)).
:- use_module(corpus).
:- use_module(ruml_reader).
:- use_module(ruml_twin).
:- use_module(ruml_tests).
:- use_module(ruml_paths).
:- use_module(ruml_cases).

here(D) :- module_property(ruml_build, file(F)), file_directory_name(F, D).

twin_root(C, Root) :-
    (   twin_place(C, private)
    ->  private_root(R), atomic_list_concat([R, '/examples/migration/ruml/', C], Root)
    ;   twins_dir(ruml, D), atomic_list_concat([D, '/', C], Root)
    ).

%!  collection_files(+C, -Files) is det.
%   The spec's examples; the fixtures of the tests that an evaluation test
%   names, or that a validation test accepts.
collection_files(spec, Fs) :- !,
    ruml_repo(R), atomic_list_concat([R, '/spec/en'], D),
    findall(F, ( directory_member(D, F, [recursive(true), extensions([ruml])]) ), Fs0), msort(Fs0, Fs).
collection_files(tests, Fs) :-
    evaluation_tests(E), validation_tests(V),
    findall(F, ( member(evaluation(_, F, _, _, _), E) ; member(validation(_, F, _, accept, _), V) ), Fs0),
    sort(Fs0, Fs).

%!  twin_name(+Collection, +File, -Name) is det.
%   `4-14-ruml-expression.examples/haertefall.ruml` → `4_14_haertefall`.
twin_name(_, File, Name) :-
    file_base_name(File, B), file_name_extension(Stem, _, B),
    file_directory_name(File, Dir), file_base_name(Dir, DB),
    (   split_string(DB, "-", "", [A, Bn|_]), number_string(_, A), number_string(_, Bn)
    ->  format(atom(N0), '~w_~w_~w', [A, Bn, Stem])
    ;   N0 = Stem
    ),
    atom_codes(N0, Cs), maplist([C0, C]>>( code_type(C0, alnum) -> code_type(C, to_lower(C0)) ; C = 0'_ ), Cs, Ds),
    atom_codes(Name, Ds).

%!  fatal_issue(+Issue) is semidet.
%   An error that leaves no rulemap to translate, or one the specification
%   says must not be processed (an unknown required capability).
fatal_issue(issue(error, R, _, _)) :-
    memberchk(R, ['FMT-01', 'FMT-02', 'FMT-03', 'FMT-04', 'FMT-06', 'FMT-08', 'FMT-09', 'NODE-10', 'NODE-12',
                  'MOD-04', 'MOD-05', 'CAP-01', 'CAP-21', 'CONT']).

build_collection(C, Filter) :-
    collection_files(C, Fs0),
    include({Filter}/[F]>>( Filter == '' -> true ; file_base_name(F, B), sub_atom(B, _, _, _, Filter) ), Fs0, Fs),
    twin_root(C, Root),
    here(H), atomic_list_concat([H, '/runs/build-', C, '.txt'], Log),
    setup_call_cleanup(open(Log, write, Out),
        ( foldl(build_one(C, Root, Out), Fs, t(0, 0, 0, 0, 0)-t(0, 0, 0), T-L),
          T = t(NM, NB, P, Fl, E), L = t(En, Ap, Re),
          format(string(S), "TOTAL ~w: ~d rulemaps, ~d built; tests ~d pass, ~d fail, ~d error; ledger ~d encoded, ~d approximated, ~d residue",
                 [C, NM, NB, P, Fl, E, En, Ap, Re]),
          format(Out, "~s~n", [S]), format("~s~n", [S]) ),
        close(Out)).

build_one(C, Root, Out, File, T0-L0, T-L) :-
    T0 = t(M0, B0, P0, F0, E0), M1 is M0 + 1,
    twin_name(C, File, Name),
    (   catch(build_file(C, Root, File, Name, Result), Err, ( message_to_codes(Err, Msg), Result = error(Msg) ))
    ->  true
    ;   Result = error("the build failed")
    ),
    (   Result = built(report(_, Issues, counts(En, Ap, Re), Fid))
    ->  fid_counts(Fid, P, F, E), length(Issues, NI),
        format(Out, "~w  ledger(~d,~d,~d)  pass ~d fail ~d error ~d  ~d writer issue(s)~n", [Name, En, Ap, Re, P, F, E, NI]),
        format("~w  ledger(~d,~d,~d)  pass ~d fail ~d error ~d~n", [Name, En, Ap, Re, P, F, E]),
        B1 is B0 + 1, P1 is P0 + P, F1 is F0 + F, E1 is E0 + E, T = t(M1, B1, P1, F1, E1),
        L0 = t(A0, Bb0, C0), A1 is A0 + En, Bb1 is Bb0 + Ap, C1 is C0 + Re, L = t(A1, Bb1, C1)
    ;   Result = refused(Why)
    ->  format(Out, "~w  NOT BUILT: ~w~n", [Name, Why]), format("~w  NOT BUILT: ~w~n", [Name, Why]),
        T = t(M1, B0, P0, F0, E0), L = L0
    ;   Result = error(Msg),
        format(Out, "~w  ERROR: ~s~n", [Name, Msg]), format("~w  ERROR: ~s~n", [Name, Msg]),
        T = t(M1, B0, P0, F0, E0), L = L0
    ).

message_to_codes(E, Cs) :- catch(message_to_codes(E, [], Cs0), _, fail), !, Cs = Cs0.
message_to_codes(E, Cs) :- format(codes(Cs), "~q", [E]).

fid_counts(fidelity(P, F, E, _), P, F, E) :- !.
fid_counts(_, 0, 0, 0).

%!  build_file(+Collection, +Root, +File, +Name, -Result) is det.
%   Result: built(Report) | refused(Why).
build_file(C, Root, File, Name, Result) :-
    ruml_read_file(File, Doc, Issues),
    (   Doc == none -> Result = refused("not a rulemap")
    ;   include(fatal_issue, Issues, [issue(_, R, _, M)|_]) -> format(string(Why), "~w ~w", [R, M]), Result = refused(Why)
    ;   atomic_list_concat([Root, '/', Name], Dir),
        make_directory_path(Dir),
        cases_of(C, File, Doc, Cases),
        file_base_name(File, Base),
        write_texts(Doc, Dir, Texts),
        rulemap_migration(Doc, Base, [tests(Cases), program(Name), texts(Texts)], Migration0),
        with_sources(Migration0, File, Dir, C, Migration),
        write_migration(Migration, Dir, Name, Report),
        Result = built(Report)
    ).

%!  rulemap_migration(+Doc, +DocName, +Options, -Migration) is det.
rulemap_migration(Doc, DocName, Options, Migration) :-
    model_migration(Doc, [document(DocName)|Options], Migration).

%   The original beside the twin, under sources/, and cited; with the
%   notice of the Apache licence of the examples (decision 9).
with_sources(migration(Meta, program(H, Items), L, T), File, Dir, C, migration(Meta, program(H2, [document(the_rulemap, [text(Rel)])|Items]), L, T)) :-
    atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
    file_base_name(File, B), atomic_list_concat([SD, '/', B], Dst),
    copy_file(File, Dst),
    atomic_list_concat(['sources/', B], Rel),
    (   collection_licence(C, Lic)
    ->  ( selectchk(comment(C0), H, H1) -> true ; C0 = "", H1 = H ),
        format(string(C1), "~w\nThe original is ~w (RUML 1.0.0, ~w).", [C0, Rel, Lic]),
        H2 = [comment(C1)|H1]
    ;   H2 = H
    ).

%!  write_texts(+Doc, +Dir, -Texts) is det.
%
%   The texts that a rulemap carries (ruml:text-reference, `text` or
%   `content`), each written under sources/ for the twin's documents: plain
%   text as `<key>.txt`; a law in RUML Text (Akoma Ntoso as JSON) as
%   `<key>.xml`, by the conversion of §4.12, and its words as `<key>.txt`.
write_texts(Doc, Dir, Texts) :-
    capabilities(Doc, Cs),
    (   member(C, Cs), j(C, id, "ruml:text-reference"), j(C, payload, P), j(P, data, json(D))
    ->  atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
        findall(K-Rel, ( member(K=T, D), write_text(SD, K, T, Rel) ), Texts)
    ;   Texts = []
    ).

write_text(SD, K, T, Rel) :-
    (   j(T, content, Content)
    ->  format(atom(X), '~w/~w.xml', [SD, K]),
        setup_call_cleanup(open(X, write, O, [encoding(utf8)]), ( format(O, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>~n", []), akn_xml(O, Content) ), close(O)),
        with_output_to(string(Words), akn_text(Content)),
        format(atom(Tx), '~w/~w.txt', [SD, K]),
        setup_call_cleanup(open(Tx, write, O2, [encoding(utf8)]), write(O2, Words), close(O2)),
        format(atom(Rel), 'sources/~w.txt', [K])
    ;   j(T, text, S)
    ->  format(atom(Tx), '~w/~w.txt', [SD, K]),
        setup_call_cleanup(open(Tx, write, O, [encoding(utf8)]), write(O, S), close(O)),
        format(atom(Rel), 'sources/~w.txt', [K])
    ).

%   RUML Text → XML: each node an element named `type`, `attrs` its
%   attributes, `content` its children; strings are character data.
akn_xml(O, S) :- string(S), !, xml_escape(S, E), write(O, E).
akn_xml(O, E) :-
    j(E, type, T), format(O, "<~w", [T]),
    (   j(E, attrs, json(As)) -> forall(member(K=V, As), ( xml_escape_attr(V, VE), format(O, " ~w=\"~w\"", [K, VE]) )) ; true ),
    (   j(E, content, Cs), Cs \== [] -> write(O, '>'), forall(member(C, Cs), akn_xml(O, C)), format(O, "</~w>", [T])
    ;   write(O, '/>')
    ).
akn_text(S) :- string(S), !, write(S).
akn_text(E) :- ( j(E, content, Cs) -> forall(member(C, Cs), akn_text(C)) ; true ),
    ( j(E, type, T), memberchk(T, ["p", "paragraph", "article", "section", "heading", "num", "point", "intro"]) -> nl ; true ).
xml_escape(S, E) :- split_string(S, "", "", _), atomic_list_concat(P1, '&', S), atomic_list_concat(P1, '&amp;', S1),
    atomic_list_concat(P2, '<', S1), atomic_list_concat(P2, '&lt;', S2), atomic_list_concat(P3, '>', S2), atomic_list_concat(P3, '&gt;', E).
xml_escape_attr(V, E) :- format(string(S), "~w", [V]), xml_escape(S, E1), atomic_list_concat(P, '"', E1), atomic_list_concat(P, '&quot;', E).

		 /*******************************
		 *            CASES             *
		 *******************************/

%   The conformance tests of a fixture, in the `complete` mode: one case
%   each, its expected statuses per node (a modular node reached by two
%   paths with two results has none). Then the generated cases.
cases_of(C, File, Doc, Cases) :-
    (   C == tests
    ->  evaluation_tests(Ts),
        findall(case(Name, Desc, Inputs, Exp),
                ( member(evaluation(Name, File, complete, Inputs, As), Ts),
                  Desc = '',
                  findall(L-S, ( member(P-S, As), S \== ignored, path_lexid(Doc, P, L) ), Exp0),
                  consistent(Exp0, Exp) ),
                Own)
    ;   Own = []
    ),
    generated_cases(Doc, File, Gen),
    append(Own, Gen, Cases).

consistent(Exp0, Exp) :-
    sort(Exp0, Exp1),
    findall(L-S, ( member(L-S, Exp1), \+ ( member(L-S2, Exp1), S2 \== S ) ), Exp).

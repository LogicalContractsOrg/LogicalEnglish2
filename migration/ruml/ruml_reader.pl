/** <module> RUML files → a checked document

    Reads the three file kinds of RUML 1.0 (the design notes ruml.md §1.4):
    a rulemap (`.ruml`), a sidecar (`.ruml-ext`, merged into its rulemap
    after its identifier and its hash are checked), and a container
    (`.rumlc`, a zip archive: its manifest names the rulemap and its
    sidecars). A result file (`.ruml-result`) is read by ruml_result_read/2.

        ruml_read_file(+File, -Doc, -Issues)
        ruml_read_files(+Files, -Doc, -Issues)    a rulemap and its sidecars
        ruml_check(+Json, -Issues)                the checks alone

    Doc is the rulemap as SWI-Prolog's classic JSON term (json([K=V, ...]),
    the order of the keys kept). Issues is a list of
    issue(Severity, Rule, Where, Message): Severity `error` or `warning`,
    Rule an identifier of the rule catalogue of the specification's chapter
    8 (FMT-03, OP-02, ...), Where a JSON pointer.

    The checks are those that change what a rulemap means, and those that the
    JSON Schema cannot state (the 'semantic' layer of chapter 8). The schema
    itself is checked by the gate (gate.pl), with the published schemas and
    a JSON Schema validator; a file that only the schema rejects still
    opens here, so that the reader can show what it has.

    Accessors for the rest of the translator: j/3, j/4, node/3, nodes/2,
    capabilities/2, capability_role/3, node_caps/2, known_capability/2.
*/

:- module(ruml_reader, [
    ruml_read_file/3, ruml_read_files/3, ruml_read_text/3, ruml_check/2,
    ruml_result_read/2, ruml_json_read/3,
    j/3, j/4, nodes/2, node/3, capabilities/2, capability_role/3, node_caps/2,
    known_capability/2, is_error/1, ruml_kind/2, official_capability/2,
    references/3, file_bytes_utf8/2, canonical_json/2
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(zip)).
:- use_module(library(crypto)).
:- use_module(jsonata_parser).

		 /*******************************
		 *            ACCESS            *
		 *******************************/

%!  j(+Object, +Key, -Value) is semidet.
j(json(Ps), K, V) :- memberchk(K=V, Ps).
%!  j(+Object, +Key, -Value, +Default) is det.
j(O, K, V, D) :- ( j(O, K, V0) -> V = V0 ; V = D ).

%!  nodes(+Doc, -Pairs) is det.   LexId-Node, in the file's order.
nodes(Doc, Ps) :-
    (   j(Doc, rulemap, RM), j(RM, nodes, json(Ns)) -> findall(K-N, member(K=N, Ns), Ps) ; Ps = [] ).
node(Doc, LexId, N) :- nodes(Doc, Ps), memberchk(LexId-N, Ps).

%!  capabilities(+Doc, -Decls) is det.   The root declarations.
capabilities(Doc, Cs) :- ( j(Doc, capabilities, Cs0), is_list(Cs0) -> Cs = Cs0 ; Cs = [] ).

%!  node_caps(+Node, -Entries) is det.   cap(Id, Payload), in order.
node_caps(N, Es) :-
    ( j(N, capabilities, L), is_list(L) -> true ; L = [] ),
    findall(cap(Id, P), ( member(E, L), j(E, id, Id0), atom_string(Id, Id0), j(E, payload, P, json([])) ), Es).

%!  official_capability(?Id, ?Role) is nondet.   The `ruml:` registry (§4.4).
official_capability('ruml:datapoints', data).
official_capability('ruml:query', decision).
official_capability('ruml:ai-query', decision).
official_capability('ruml:actions', reaction).
official_capability('ruml:context', data).
official_capability('ruml:text-reference', data).
official_capability('ruml:protocol', reaction).
official_capability('ruml:expression', combiner).
official_capability('ruml:tree-reference', data).
official_capability('ruml:tree-include', decision).

%!  known_capability(?Id, ?Role) is nondet.
%
%   What this translator implements: the official capabilities, and the
%   three of the conformance tests (appendix A, "Test capabilities"), which
%   a test runner must recognise.
known_capability(Id, R) :- official_capability(Id, R).
known_capability('org.ruml.test/data', data).
known_capability('org.ruml.test/decision', decision).
known_capability('org.ruml.test/combiner', combiner).

%!  capability_role(+Doc, +Id, -Role) is semidet.
capability_role(_, Id, R) :- official_capability(Id, R), !.
capability_role(Doc, Id, R) :-
    capabilities(Doc, Cs), member(C, Cs), j(C, id, Id0), atom_string(Id, Id0), j(C, role, R0), !,
    atom_string(R, R0).
capability_role(_, Id, R) :- known_capability(Id, R).

is_error(issue(error, _, _, _)).

		 /*******************************
		 *           READING            *
		 *******************************/

%!  ruml_json_read(+File, -Json, -Issues) is det.
%
%   The JSON of a file, or the issues that say why there is none: a file
%   that is not UTF-8 (FMT-01) or not JSON (FMT-02).
ruml_json_read(File, Json, Issues) :-
    read_file_to_codes(File, Bytes, [type(binary)]),
    (   \+ utf8_bytes(Bytes)
    ->  Json = none, Issues = [issue(error, 'FMT-01', '', "The file is not UTF-8 encoded.")]
    ;   phrase(utf8_codes(Cs), Bytes), string_codes(S, Cs),
        ruml_text_json(S, Json, Issues)
    ).

ruml_text_json(S, Json, Issues) :-
    (   catch(( open_string(S, In), json_read(In, Json, [value_string_as(string), end_of_file(error)]),
                close(In) ), E, ( Json = none, message_to_codes(E, M), true ))
    ->  (   Json == none -> string_codes(MS, M), format(string(Msg), "The file is not JSON: ~w", [MS]),
            Issues = [issue(error, 'FMT-02', '', Msg)]
        ;   Issues = []
        )
    ;   Json = none, Issues = [issue(error, 'FMT-02', '', "The file is not JSON.")]
    ).

message_to_codes(E, Cs) :- catch(message_to_codes(E, [], Cs0), _, fail), !, Cs = Cs0.
message_to_codes(E, Cs) :- format(codes(Cs), "~q", [E]).

file_bytes_utf8(File, S) :-
    read_file_to_codes(File, Bytes, [type(binary)]), phrase(utf8_codes(Cs), Bytes), string_codes(S, Cs).

%   A strict check of UTF-8 (RFC 3629).
utf8_bytes([]).
utf8_bytes([B|Bs]) :-
    (   B < 0x80 -> utf8_bytes(Bs)
    ;   B >= 0xC2, B =< 0xDF -> cont(1, Bs, R), utf8_bytes(R)
    ;   B >= 0xE0, B =< 0xEF -> cont(2, Bs, R), utf8_bytes(R)
    ;   B >= 0xF0, B =< 0xF4 -> cont(3, Bs, R), utf8_bytes(R)
    ).
cont(0, R, R) :- !.
cont(N, [B|Bs], R) :- B >= 0x80, B =< 0xBF, N1 is N - 1, cont(N1, Bs, R).

utf8_codes([C|Cs]) --> utf8_code(C), !, utf8_codes(Cs).
utf8_codes([]) --> [].
utf8_code(C) --> [B], { B < 0x80 }, !, { C = B }.
utf8_code(C) --> [B, B1], { B >= 0xC0, B < 0xE0 }, !, { C is ((B /\ 0x1F) << 6) \/ (B1 /\ 0x3F) }.
utf8_code(C) --> [B, B1, B2], { B >= 0xE0, B < 0xF0 }, !,
    { C is ((B /\ 0x0F) << 12) \/ ((B1 /\ 0x3F) << 6) \/ (B2 /\ 0x3F) }.
utf8_code(C) --> [B, B1, B2, B3], { C is ((B /\ 0x07) << 18) \/ ((B1 /\ 0x3F) << 12) \/ ((B2 /\ 0x3F) << 6) \/ (B3 /\ 0x3F) }.

%!  ruml_kind(+Json, -Kind) is semidet.   ruml, ext, result.
ruml_kind(J, K) :- j(J, '$format', F), ( F == "RUML" -> K = ruml ; F == "RUML-EXT" -> K = ext ; F == "RUML-Result" -> K = result ).

%!  ruml_read_file(+File, -Doc, -Issues) is det.
ruml_read_file(File, Doc, Issues) :-
    (   file_name_extension(_, rumlc, File)
    ->  container_files(File, Files, CIssues),
        ruml_read_files(Files, Doc, I0), append(CIssues, I0, Issues)
    ;   ruml_read_files([File], Doc, Issues)
    ).

%!  ruml_read_text(+Text, -Doc, -Issues) is det.
ruml_read_text(Text, Doc, Issues) :-
    ruml_text_json(Text, Json, I0),
    (   Json == none -> Doc = none, Issues = I0
    ;   ruml_check(Json, I1), Doc = Json, Issues = I1
    ).

%!  ruml_read_files(+Files, -Doc, -Issues) is det.
%
%   One rulemap and any number of sidecars for it: each sidecar is checked
%   against the rulemap (CAP-22 to CAP-27) and merged into it.
ruml_read_files(Files, Doc, Issues) :-
    maplist([F, F-J-I]>>ruml_json_read(F, J, I), Files, Read),
    partition([_-J-_]>>( J \== none, ruml_kind(J, ruml) ), Read, Maps, Others),
    findall(I, ( member(_-none-Is, Read), member(I, Is) ), ReadIssues),
    (   Maps = [_-Doc0-_|More]
    ->  ( More == [] -> MI = [] ; MI = [issue(warning, 'FMT-03', '', "More than one rulemap: the first was read.")] ),
        ruml_check(Doc0, CheckIssues),
        include([_-J-_]>>( J \== none, ruml_kind(J, ext) ), Others, Exts),
        foldl(merge_ext, Exts, Doc0-[], Doc-ExtIssues),
        append([ReadIssues, MI, CheckIssues, ExtIssues], Issues)
    ;   Read = [_-J1-_|_], J1 \== none, \+ ruml_kind(J1, ruml)
    ->  Doc = none,
        (   j(J1, '$format', F) -> format(string(M), "`$format` is \"~w\", not \"RUML\".", [F])
        ;   M = "The file has no `$format`."
        ),
        append(ReadIssues, [issue(error, 'FMT-03', '/$format', M)], Issues)
    ;   Doc = none, Issues = ReadIssues
    ).

		 /*******************************
		 *          SIDECARS            *
		 *******************************/

%   A sidecar is merged when its base id is the rulemap's and its hash the
%   rulemap's hash (CAP-24; the hash over the canonical form, RFC 8785). Its
%   node entries are keyed by node UUID, each an object from capability id
%   to payload (§4.5). A capability both inline and in the sidecar, on one
%   node, is an error (CAP-27).
merge_ext(_-Ext-_, Doc0-Is0, Doc-Is) :-
    j(Ext, '$base', Base), j(Base, id, BId), j(Doc0, metadata, Meta), j(Meta, id, MId),
    (   BId \== MId
    ->  Doc = Doc0, append(Is0, [issue(error, 'CAP-24', '/$base/id', "The sidecar names another rulemap.")], Is)
    ;   j(Base, hash, H), \+ hash_matches(Doc0, H)
    ->  Doc = Doc0, append(Is0, [issue(error, 'CAP-24', '/$base/hash', "The sidecar was made for another version of the rulemap (its hash differs): not merged.")], Is)
    ;   j(Ext, nodes, json(ENs)), capabilities(Ext, ECaps),
        nodes(Doc0, Ns0),
        findall(I, ( member(U=_, ENs), \+ ( member(_-N, Ns0), j(N, id, U0), atom_string(U, U0) ),
                     format(string(M), "The sidecar names node ~w, which the rulemap does not have.", [U]),
                     I = issue(error, 'CAP-26', '/nodes', M) ), Unknown),
        maplist(merge_node(ENs), Ns0, Ns, Conflicts0), append(Conflicts0, Conflicts),
        capabilities(Doc0, RootCaps0),
        foldl(add_decl, ECaps, RootCaps0, RootCaps),
        set_nodes(Doc0, Ns, Doc1), set_key(Doc1, capabilities, RootCaps, Doc),
        append([Is0, Unknown, Conflicts], Is)
    ).

hash_matches(Doc, H) :-
    split_string(H, ":", "", [Alg, Hex]),
    canonical_json(Doc, Canon),
    (   Alg == "sha3-256" -> crypto_data_hash(Canon, D, [algorithm(sha3_256), encoding(utf8)])
    ;   Alg == "sha256" -> crypto_data_hash(Canon, D, [algorithm(sha256), encoding(utf8)])
    ;   fail
    ),
    string_lower(Hex, D0), atom_string(D, D0).

merge_node(ENs, K-N0, K-N, Conflicts) :-
    j(N0, id, U0), atom_string(U, U0),
    (   memberchk(U=json(Caps), ENs)
    ->  node_caps(N0, Inline),
        findall(issue(error, 'CAP-27', '/nodes', M),
                ( member(C=_, Caps), memberchk(cap(C, _), Inline),
                  format(string(M), "Node ~w has ~w both inline and in the sidecar.", [K, C]) ), Conflicts),
        ( j(N0, capabilities, L0) -> true ; L0 = [] ),
        findall(json([id=CS, payload=P]), ( member(C=P, Caps), \+ memberchk(cap(C, _), Inline), atom_string(C, CS) ), Add),
        append(L0, Add, L), set_key(N0, capabilities, L, N)
    ;   N = N0, Conflicts = []
    ).

add_decl(D, Cs0, Cs) :-
    j(D, id, Id), ( member(C, Cs0), j(C, id, Id) -> Cs = Cs0 ; append(Cs0, [D], Cs) ).

set_nodes(Doc0, Ns, Doc) :-
    j(Doc0, rulemap, RM0), findall(K=N, member(K-N, Ns), L),
    set_key(RM0, nodes, json(L), RM), set_key(Doc0, rulemap, RM, Doc).

set_key(json(Ps0), K, V, json(Ps)) :-
    (   selectchk(K=_, Ps0, K=V, Ps) -> true ; append(Ps0, [K=V], Ps) ).

%!  canonical_json(+Json, -String) is det.   RFC 8785, for the values RUML has.
canonical_json(J, S) :- with_output_to(string(S), canon(J)).
canon(json(Ps)) :- !,
    msort_by_key(Ps, Sorted), write('{'),
    foldl([K=V, F0, F]>>( ( F0 == first -> true ; write(',') ), atom_string(K, KS), canon_string(KS), write(':'), canon(V), F = next ),
          Sorted, first, _),
    write('}').
canon(L) :- is_list(L), !, write('['), foldl([V, F0, F]>>( ( F0 == first -> true ; write(',') ), canon(V), F = next ), L, first, _), write(']').
canon(S) :- string(S), !, canon_string(S).
canon(@(true)) :- !, write(true).
canon(@(false)) :- !, write(false).
canon(@(null)) :- !, write(null).
canon(true) :- !, write(true).
canon(false) :- !, write(false).
canon(null) :- !, write(null).
canon(N) :- integer(N), !, write(N).
canon(N) :- float(N), !, ( N =:= truncate(N), abs(N) < 1.0e21 -> I is truncate(N), write(I) ; format("~w", [N]) ).
canon(A) :- atom(A), !, atom_string(A, S), canon_string(S).
canon_string(S) :- json_write(current_output, S, [width(0)]).
msort_by_key(Ps, Sorted) :-
    map_list_to_pairs([K=_, Key]>>( atom_string(K, S), string_codes(S, Cs), utf16_units(Cs, Key) ), Ps, KPs),
    keysort(KPs, S0), pairs_values(S0, Sorted).
utf16_units([], []).
utf16_units([C|Cs], Us) :-
    (   C > 0xFFFF -> H is 0xD800 + ((C - 0x10000) >> 10), L is 0xDC00 + ((C - 0x10000) /\ 0x3FF), Us = [H, L|Us1]
    ;   Us = [C|Us1]
    ), utf16_units(Cs, Us1).

		 /*******************************
		 *         CONTAINERS           *
		 *******************************/

%   A container is a zip archive (§7): the manifest lists the files; the
%   rulemap and its sidecars are read, the others (texts, documents) stay
%   in the extracted folder for the translator (ruml_twin: texts under
%   sources/). Signatures are reported, not verified; an encrypted
%   container is refused.
container_files(File, Files, Issues) :-
    tmp_file(rumlc, Dir), make_directory_path(Dir),
    zip_extract(File, Dir),
    findall(F, ( directory_member(Dir, F, [recursive(true)]),
                 ( file_name_extension(_, ruml, F) ; file_name_extension(_, 'ruml-ext', F) ) ), Files0),
    msort(Files0, Files),
    findall(issue(warning, 'CONT', '', "The container is signed; the signature was not checked."),
            ( directory_member(Dir, S, [recursive(true)]), sub_atom(S, _, _, _, signature) ), Sig0),
    ( Sig0 = [S1|_] -> Sig = [S1] ; Sig = [] ),
    (   directory_member(Dir, E, [recursive(true)]), file_name_extension(_, jwe, E)
    ->  Issues = [issue(error, 'CONT', '', "The container is encrypted, and cannot be read.")|Sig]
    ;   Issues = Sig
    ),
    b_setval(ruml_container_dir, Dir).

zip_extract(File, Dir) :-
    setup_call_cleanup(zip_open(File, read, Z, []),
        ( zip_goto(Z, first), extract_all(Z, Dir) ),
        zip_close(Z)).
extract_all(Z, Dir) :-
    zip_file_info_(Z, Name),
    (   sub_atom(Name, _, 1, 0, '/') -> true
    ;   \+ sub_atom(Name, _, _, _, '..'),
        atomic_list_concat([Dir, '/', Name], Out), file_directory_name(Out, OD), make_directory_path(OD),
        setup_call_cleanup(zip_open_current(Z, In, [type(binary)]),
            setup_call_cleanup(open(Out, write, O, [type(binary)]), copy_stream_data(In, O), close(O)),
            close(In))
    ),
    (   catch(zip_goto(Z, next), _, fail) -> extract_all(Z, Dir) ; true ).
zip_file_info_(Z, Name) :- zip_file_info(Z, Name, _).

		 /*******************************
		 *           RESULTS            *
		 *******************************/

%!  ruml_result_read(+File, -Result) is semidet.
ruml_result_read(File, J) :-
    ruml_json_read(File, J, []), J \== none, ruml_kind(J, result).

		 /*******************************
		 *            CHECKS            *
		 *******************************/

%!  ruml_check(+Doc, -Issues) is det.
ruml_check(Doc, Issues) :-
    findall(I, check(Doc, I), Issues0),
    list_to_set(Issues0, Issues).

err(Rule, Where, Fmt, Args, issue(error, Rule, Where, M)) :- format(string(M), Fmt, Args).
warn(Rule, Where, Fmt, Args, issue(warning, Rule, Where, M)) :- format(string(M), Fmt, Args).

status(Doc, S) :- ( j(Doc, metadata, M), j(M, status, S0) -> atom_string(S, S0) ; S = none ).

%   --- the file ---
check(Doc, I) :-
    j(Doc, '$format', F), F \== "RUML", err('FMT-03', '/$format', "`$format` must be \"RUML\", not \"~w\".", [F], I).
check(Doc, I) :-
    (   j(Doc, '$specVersion', V) -> \+ memberchk(V, ["1.0"]),
        err('FMT-09', '/$specVersion', "Version ~w of RUML is not supported: this reader implements 1.0.", [V], I)
    ;   err('FMT-04', '/$specVersion', "The file has no `$specVersion`.", [], I)
    ).
check(json(Ps), I) :-
    \+ ( Ps = [K1=_, K2=_|_], K1 == '$format', K2 == '$specVersion' ),
    err('FMT-05', '', "`$format` and `$specVersion` must be the first two fields.", [], I).
check(json(Ps), I) :-
    member(K=_, Ps), \+ memberchk(K, ['$format', '$specVersion', capabilities, metadata, rulemap]),
    err('FMT-07', '', "The root object has a field `~w` that RUML does not define.", [K], I).
check(Doc, I) :-
    member(K, [metadata, rulemap]), \+ j(Doc, K, _),
    err('FMT-06', '', "The file has no `~w`.", [K], I).
check(Doc, I) :-
    j(Doc, rulemap, _), \+ node(Doc, '1', _),
    err('FMT-08', '/rulemap/nodes', "There is no root node (LexID 1).", [], I).
check(Doc, I) :-
    j(Doc, metadata, M), member(K, [id, version, created, modified, status]), \+ j(M, K, _),
    err('META-01', '/metadata', "The metadata has no `~w`.", [K], I).

%   --- nodes ---
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns),
    member(F, [id, label]), \+ j(N, F, _),
    err('NODE-01', '/rulemap/nodes', "Node ~w has no `~w`.", [K, F], I).
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns), j(N, children, Cs), member(C0, Cs), atom_string(C, C0),
    \+ memberchk(C-_, Ns),
    err('NODE-10', '/rulemap/nodes', "Node ~w names child ~w, which does not exist.", [K, C], I).
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns), j(N, children, Cs), member("1", Cs),
    err('NODE-05', '/rulemap/nodes', "Node ~w names the root node as its child.", [K], I).
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns), j(N, children, []),
    err('NODE-06', '/rulemap/nodes', "Node ~w has an empty `children` array.", [K], I).
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns), j(N, children, [_|_]), \+ j(N, operator, _),
    err('NODE-12', '/rulemap/nodes', "Node ~w has children and no operator.", [K], I).
check(Doc, I) :-
    status(Doc, S), S \== draft,
    nodes(Doc, Ns), member(K-N, Ns), \+ j(N, children, [_|_]), j(N, operator, _),
    err('NODE-07', '/rulemap/nodes', "Leaf node ~w has an operator; only a draft may.", [K], I).
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns), j(N, operator, O),
    \+ memberchk(O, ["AND", "NOT_AND", "OR", "NOT_OR", "XOR", "NOT_XOR", "DELEGATED", "undefined"]),
    err('OP-01', '/rulemap/nodes', "Node ~w has the operator ~w, which RUML does not define.", [K, O], I).
check(Doc, I) :-
    status(Doc, S), S \== draft,
    nodes(Doc, Ns), member(K-N, Ns), j(N, operator, "undefined"),
    err('OP-07', '/rulemap/nodes', "Node ~w has the operator `undefined`, which only a draft may have.", [K], I).
check(Doc, I) :-
    nodes(Doc, Ns), findall(U, ( member(_-N, Ns), j(N, id, U) ), Us),
    ( j(Doc, metadata, M), j(M, id, MI) -> All = [MI|Us] ; All = Us ),
    msort(All, S), append(_, [X, X|_], S),
    err('NODE-08', '/rulemap/nodes', "The identifier ~w is used twice.", [X], I).

%   --- modular nodes (chapter 6) ---
check(Doc, I) :-
    references(Doc, C, Count), Count > 1, node(Doc, C, N), \+ j(N, modular, @(true)), \+ j(N, modular, true),
    err('MOD-01', '/rulemap/nodes', "Node ~w is referenced ~w times, so it is modular, and has no `modular: true`.", [C, Count], I).
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns), ( j(N, modular, @(true)) ; j(N, modular, true) ),
    references(Doc, K, Count), Count < 2,
    warn('MOD-01', '/rulemap/nodes', "Node ~w is marked modular, and is referenced only once.", [K], I).
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns), j(N, children, [C0|_]), atom_string(K, C0),
    err('MOD-04', '/rulemap/nodes', "Node ~w is its own first child.", [K], I).
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns), j(N, children, Cs), atom_string(K, KS), memberchk(KS, Cs),
    \+ ( member(C, Cs), C \== KS ),
    err('MOD-05', '/rulemap/nodes', "Recursive node ~w has no child other than itself.", [K], I).
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns), j(N, children, Cs), atom_string(K, KS), memberchk(KS, Cs),
    j(N, operator, O), memberchk(O, ["AND", "NOT_AND", "OR", "NOT_OR"]),
    warn('MOD-03', '/rulemap/nodes', "Recursive node ~w uses ~w, which can block its evaluation.", [K, O], I).

%   --- capabilities (chapter 4) ---
check(Doc, I) :-
    capabilities(Doc, Cs), member(C, Cs), j(C, id, Id0), atom_string(Id, Id0),
    \+ valid_capability_id(Id),
    err('CAP-21', '/capabilities', "`~w` is not a valid capability identifier.", [Id], I).
check(Doc, I) :-
    capabilities(Doc, Cs), member(C, Cs), j(C, id, Id0), atom_string(Id, Id0),
    sub_atom(Id, 0, _, _, 'ruml:'), \+ sub_atom(Id, 0, _, _, 'ruml:draft/'), \+ official_capability(Id, _),
    err('CAP-21', '/capabilities', "`~w` uses the reserved prefix `ruml:` and is not defined by RUML 1.0.", [Id], I).
check(Doc, I) :-
    capabilities(Doc, Cs), findall(Id, ( member(C, Cs), j(C, id, Id) ), Ids),
    msort(Ids, S), append(_, [X, X|_], S),
    err('CAP-10', '/capabilities', "The capability `~w` is declared twice.", [X], I).
check(Doc, I) :-
    capabilities(Doc, Cs), member(C, Cs), j(C, id, Id0), atom_string(Id, Id0),
    \+ official_capability(Id, _), \+ j(C, role, _),
    err('CAP-03', '/capabilities', "The capability `~w` is not official and declares no role.", [Id], I).
check(Doc, I) :-
    capabilities(Doc, Cs), member(C, Cs), j(C, id, Id0), atom_string(Id, Id0),
    official_capability(Id, _), j(C, role, _),
    err('CAP-05', '/capabilities', "The official capability `~w` must not declare a role.", [Id], I).
check(Doc, I) :-
    capabilities(Doc, Cs), member(C, Cs), j(C, id, Id0), atom_string(Id, Id0),
    j(C, role, R0), atom_string(R, R0), known_capability(Id, R1), R1 \== R,
    err('CAP-04', '/capabilities', "The capability `~w` is declared with the role ~w; it has the role ~w.", [Id, R, R1], I).
check(Doc, I) :-
    capabilities(Doc, Cs), member(C, Cs), j(C, id, Id0), atom_string(Id, Id0),
    ( j(C, required, @(true)) ; j(C, required, true) ), \+ known_capability(Id, _),
    err('CAP-01', '/capabilities', "The file requires the capability `~w`, which this translator does not implement.", [Id], I).
check(Doc, I) :-
    capabilities(Doc, Cs), member(C, Cs), j(C, id, "ruml:expression"),
    \+ ( j(C, required, @(true)) ; j(C, required, true) ),
    err('CAP-11', '/capabilities', "`ruml:expression` must be declared with `required: true`.", [], I).
check(Doc, I) :-
    capabilities(Doc, []), nodes(Doc, Ns), member(K-N, Ns), j(N, capabilities, _),
    err('CAP-14', '/rulemap/nodes', "Node ~w has capabilities, and the file declares none.", [K], I).
check(Doc, I) :-
    capabilities(Doc, Cs), Cs \== [],
    findall(Id, ( member(C, Cs), j(C, id, Id0), atom_string(Id, Id0) ), Ids),
    nodes(Doc, Ns), member(K-N, Ns), node_caps(N, Es), member(cap(Id, _), Es), \+ memberchk(Id, Ids),
    err('CAP-15', '/rulemap/nodes', "Node ~w uses the capability `~w`, which the file does not declare.", [K, Id], I).
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns), node_caps(N, Es),
    findall(Id, ( member(cap(Id, _), Es), capability_role(Doc, Id, data) ), Ds),
    msort(Ds, S), append(_, [X, X|_], S),
    err('CAP-06', '/rulemap/nodes', "Node ~w carries the data capability `~w` twice.", [K, X], I).
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns), j(N, children, [_|_]), node_caps(N, Es),
    member(cap(Id, _), Es), capability_role(Doc, Id, decision),
    err('CAP-07', '/rulemap/nodes', "Node ~w has children and the decision capability `~w`.", [K, Id], I).
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns), node_caps(N, Es),
    member(cap(Id, _), Es), capability_role(Doc, Id, combiner), \+ j(N, operator, "DELEGATED"),
    err('CAP-08', '/rulemap/nodes', "Node ~w carries the combiner `~w` and its operator is not DELEGATED.", [K, Id], I).
check(Doc, I) :-
    status(Doc, S), S \== draft,
    nodes(Doc, Ns), member(K-N, Ns), j(N, operator, "DELEGATED"), j(N, children, [_|_]),
    node_caps(N, Es), findall(Id, ( member(cap(Id, _), Es), capability_role(Doc, Id, combiner) ), Cbs),
    length(Cbs, L), L =\= 1,
    err('OP-02', '/rulemap/nodes', "DELEGATED node ~w must carry exactly one combiner; it carries ~w.", [K, L], I).
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns), j(N, operator, "DELEGATED"), node_caps(N, Es),
    member(cap(Id, P), Es), capability_role(Doc, Id, combiner), \+ j(P, description, _),
    err('OP-04', '/rulemap/nodes', "The combiner of node ~w has no description.", [K], I).
check(Doc, I) :-
    nodes(Doc, Ns), member(K-N, Ns), node_caps(N, Es),
    member(cap(Id, P), Es), memberchk(Id, ['ruml:query', 'ruml:expression']),
    j(P, expression, E), \+ jsonata_parse(E, _),
    err('CAP-29', '/rulemap/nodes', "The expression of node ~w is not JSONata: ~w", [K, E], I).

%   --- data points (§4.7) ---
check(Doc, I) :-
    datapoint_ids(Doc, DPs),
    nodes(Doc, Ns), member(K-N, Ns), node_caps(N, Es),
    member(cap(Id, P), Es), memberchk(Id, ['ruml:query', 'ruml:expression']),
    j(P, expression, E), jsonata_parse(E, T), jsonata_names(T, Names),
    member(Nm, Names), \+ memberchk(Nm, DPs),
    err('DP-18', '/rulemap/nodes', "The expression of node ~w reads `~w`, which is not a declared data point.", [K, Nm], I).

datapoint_ids(Doc, Ids) :-
    capabilities(Doc, Cs),
    (   member(C, Cs), j(C, id, "ruml:datapoints"), j(C, payload, P), j(P, data, json(D))
    ->  findall(Id, member(Id=_, D), Ids)
    ;   Ids = []
    ).

valid_capability_id(Id) :-
    atom_length(Id, L), L =< 128,
    atom_codes(Id, Cs), forall(member(C, Cs), ( code_type(C, lower) ; code_type(C, digit) ; memberchk(C, `_-.:/`) )),
    (   sub_atom(Id, 0, _, _, 'ruml:') -> true
    ;   sub_atom(Id, B, 1, A, '/'), B > 0, A > 0, sub_atom(Id, 0, B, _, Dom), sub_atom(Dom, _, _, _, '.')
    ).

%!  references(+Doc, ?LexId, -Count) is nondet.
%   How many times a node is named in `children` arrays.
references(Doc, C, Count) :-
    nodes(Doc, Ns),
    findall(C0, ( member(_-N, Ns), j(N, children, Cs), member(S, Cs), atom_string(C0, S) ), All),
    msort(All, Sorted), clumped_pairs(Sorted, Pairs), member(C-Count, Pairs).

clumped_pairs(L, Ps) :- clumped(L, Ps).

/** <module> The gate of step 1: the reader against L4's evaluator

    the design notes l4.md §8, step 1. For every file of the corpus that L4's
    evaluator accepts (runs/<Id>.json, success true):

      - the reader reads it with nothing left unread (no `unparsed` item);
      - every directive the evaluator ran (#EVAL, #TRACE, #ASSERT, …) is a
        directive item of the reader's, starting on the same line;
      - on a sample of names with a declared type (the parameters after
        GIVEN, the fields after HAS, the values after GIVETH), the type the
        reader recorded is the type L4's hover reports at that name
        (l4_oracle.mjs hover), compared as text.

    From /work:
        ./myswipl.sh -q -g "consult('migration/l4/gate.pl'), gate:main" -t halt

    Writes runs/gate.txt, which test_l4.pl checks.
*/

:- module(gate, [main/0, gate_file/3, type_text/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(corpus).
:- use_module(l4_reader).
:- use_module(l4_print).

here(D) :- module_property(gate, file(F)), file_directory_name(F, D).

main :-
    here(H),
    findall(Id, corpus_file(Id, _, _), Ids),
    maplist(gate_file_line, Ids, Lines0),
    exclude(==(skip), Lines0, Lines),
    include([l(_, ok, _)]>>true, Lines, Oks),
    length(Lines, N), length(Oks, NOk),
    findall(Id, member(l(Id, _, _), Lines), Accepted),
    round_trip(Accepted, RT),
    include([rt(_, same, _)]>>true, RT, RTSame), length(RTSame, NRT),
    exclude([rt(_, same, _)]>>true, RT, RTBad),
    hover_sample(HovOk, HovAll, HovBad),
    corpus_commit(Commit), build(Build),
    atomic_list_concat([H, '/runs/gate.txt'], Out),
    setup_call_cleanup(open(Out, write, S, [encoding(utf8)]),
        ( format(S, "# L4 reader gate (step 1): files the evaluator accepts, read by l4_reader.pl~n", []),
          format(S, "# corpus ~w, evaluator ~w~n", [Commit, Build]),
          forall(member(l(Id, St, Note), Lines), format(S, "~w ~w ~w~n", [St, Id, Note])),
          format(S, "total ~w of ~w files read in full, every directive found~n", [NOk, N]),
          format(S, "hover ~w of ~w declared types agree with L4's~n", [HovOk, HovAll]),
          format(S, "round-trip ~w of ~w files give L4's results when written back~n", [NRT, N]),
          forall(member(rt(Id, St, Note), RTBad), format(S, "round-trip-~w ~w ~w~n", [St, Id, Note])),
          forall(member(B, HovBad), format(S, "hover-differs ~w~n", [B]))
        ),
        close(S)),
    format("~w of ~w files; hover ~w of ~w; round trip ~w of ~w~n", [NOk, N, HovOk, HovAll, NRT, N]).

% ---------------------------------------------------------------------------
% The round trip: read, write back (l4_print.pl), run again, compare

round_trip(Ids, RT) :-
    tmp_file(l4rt, Dir), make_directory(Dir),
    findall(Id-F, ( member(Id, Ids), corpus_path(Id, P), l4_read_file(P, M),
                    l4_print_module(M, T),
                    atomic_list_concat([Dir, '/', Id, '.l4'], F),
                    setup_call_cleanup(open(F, write, S, [encoding(utf8)]), write(S, T), close(S)) ),
            Pairs),
    pairs_values(Pairs, Files),
    here(H), atomic_list_concat([H, '/l4_oracle.mjs'], JS),
    process_create(path(node), [JS, eval|Files], [stdout(pipe(Out))]),
    set_stream(Out, encoding(utf8)),
    maplist(rt_pair(Out), Pairs, RT),
    close(Out),
    delete_directory_and_contents(Dir).

rt_pair(Out, Id-_, rt(Id, St, Note)) :- json_read_dict(Out, New), compare_runs(Id, New, St, Note).

compare_runs(Id, New, St, Note) :-
    run(Id, Old),
    get_dict(results, Old, OldResults),
    maplist(result_text, OldResults, Rs0),
    (   get_dict(success, New, Ok), Ok \== true
    ->  St = refused,
        get_dict(diagnostics, New, [D1|_]), get_dict(message, D1, M), squash(M, M1),
        ( string_length(M1, Len), Len > 120 -> sub_string(M1, 0, 120, _, Note) ; Note = M1 )
    ;   get_dict(results, New, NewResults),
        maplist(result_text, NewResults, Rs1),
        maplist(squash, Rs0, S0), maplist(squash, Rs1, S1),
        (   S0 == S1 -> St = same, Note = ''
        ;   St = differs, first_difference(S0, S1, Note)
        )
    ).

%   A result compared without spaces, brackets or backquotes: the text
%   written back has more of each than the original.
squash(X, S) :-
    ( string(X) -> T = X ; format(string(T), "~w", [X]) ),
    string_codes(T, Cs),
    exclude([C]>>memberchk(C, `() \n\t\``), Cs, Cs1),
    string_codes(S, Cs1).

result_text(D, R) :-
    get_dict(result, D, R0),
    (   R0 == null -> get_dict(error, D, R) ; R = R0 ).

first_difference(S0, S1, Note) :-
    length(S0, N0), length(S1, N1),
    (   nth1(I, S0, A), nth1(I, S1, B), A \== B
    ->  sub_atom_icasechk_safe(A, A1), sub_atom_icasechk_safe(B, B1),
        format(atom(Note), "result ~w: ~w | ~w", [I, A1, B1])
    ;   format(atom(Note), "~w results, ~w written back", [N0, N1])
    ).

sub_atom_icasechk_safe(S, T) :-
    ( string_length(S, L), L > 80 -> sub_string(S, 0, 80, _, T) ; T = S ).

build(B) :-
    here(H), atomic_list_concat([H, '/oracle/BUILD'], F),
    ( exists_file(F) -> read_file_to_string(F, S, []), split_string(S, "", " \n", [B0]), atom_string(B, B0) ; B = unknown ).

run(Id, Dict) :-
    here(H), atomic_list_concat([H, '/runs/', Id, '.json'], F),
    exists_file(F),
    setup_call_cleanup(open(F, read, S, [encoding(utf8)]), json_read_dict(S, Dict), close(S)).

gate_file_line(Id, Line) :-
    (   run(Id, R), R.success == true
    ->  gate_file(Id, St, Note), Line = l(Id, St, Note)
    ;   Line = skip
    ).

%!  gate_file(+Id, -Status, -Note) is det.
gate_file(Id, Status, Note) :-
    corpus_path(Id, Path),
    run(Id, R),
    catch(l4_read_file(Path, l4_module(Items, Issues)), E, (Items = [], Issues = [error(E)])),
    findall(L, member(directive(_, _, pos(L, _)), Items), DLines),
    findall(L, ( member(D, R.results), L = D.start.line ), OLines),
    subtract(OLines, DLines, Missing),
    length(Items, NI), length(DLines, ND),
    (   Issues == [], Missing == []
    ->  Status = ok, format(atom(Note), "(~w items, ~w directives)", [NI, ND])
    ;   Status = fail,
        (   Issues = [I|_] -> issue_note(I, INote) ; INote = '' ),
        format(atom(Note), "(~w unread; directives missing at lines ~w) ~w", [Issues, Missing, INote])
    ).

issue_note(unparsed(T, _, pos(L, _)), N) :- !,
    sub_string(T, 0, _, _, _), ( string_length(T, Len), Len > 60 -> sub_string(T, 0, 60, _, T1) ; T1 = T ),
    format(atom(N), "first at line ~w: ~w", [L, T1]).
issue_note(I, N) :- format(atom(N), "~q", [I]).

% ---------------------------------------------------------------------------
% The hover sample: every declared type of a few files

hover_files([legal_promissory_note, legal_british_citizen_act, foundation_module_4_examples,
             advanced_module_a3_contracts_examples, reference_regulative_deontic_example]).

hover_sample(Ok, All, Bad) :-
    hover_files(Ids),
    foldl(hover_file, Ids, 0-0-[], Ok-All-Bad0),
    reverse(Bad0, Bad).

hover_file(Id, Ok0-All0-Bad0, Ok-All-Bad) :-
    corpus_path(Id, Path),
    l4_read_file(Path, l4_module(Items, _)),
    findall(p(L, C, T), declared(Items, L, C, T), Ps0),
    sort(Ps0, Ps),
    (   Ps == [] -> Ok = Ok0, All = All0, Bad = Bad0
    ;   findall(A, ( member(p(L, C, _), Ps), format(atom(A), "~w:~w", [L, C]) ), Args),
        here(H), atomic_list_concat([H, '/l4_oracle.mjs'], JS),
        process_create(path(node), [JS, hover, Path|Args], [stdout(pipe(Out))]),
        json_read_dict(Out, Hovers), close(Out),
        foldl(compare_hover(Id, Hovers), Ps, Ok0-All0-Bad0, Ok-All-Bad)
    ).

%   A name with a declared type: a GIVEN parameter, whose type is the one
%   declared, or a HAS field, which L4 shows as the function from its record
%   (or its choice's type) to the field's type.
declared(Items, L, C, T) :-
    member(I, Items),
    (   arg(_, I, sig(Gs, _)), member(param(_, T, pos(L, C)), Gs), T \== none,
        T \== type
    ;   I = declare(_, appform(R, RArgs, _, _), record(Fs), _, _),
        member(field(_, T0, _, pos(L, C)), Fs), record_type(R, RArgs, RT), T = fun([RT], T0)
    ;   I = declare(_, appform(R, RArgs, _, _), enum(Cs), _, _), member(con(_, Fs), Cs),
        member(field(_, T0, _, pos(L, C)), Fs), record_type(R, RArgs, RT), T = fun([RT], T0)
    ).

record_type(R, [], tyapp(R, [])) :- !.
record_type(R, Args, forall_app(R, Args)).

compare_hover(Id, Hovers, p(L, C, T), Ok0-All0-Bad0, Ok-All-Bad) :-
    format(atom(K), "~w:~w", [L, C]),
    All is All0 + 1,
    type_text_top(T, Mine),
    (   get_dict(K, Hovers, H), is_dict(H), hover_type(H, Theirs)
    ->  (   Mine == Theirs
        ->  Ok is Ok0 + 1, Bad = Bad0
        ;   Ok = Ok0, format(atom(B), "~w ~w: reader ~w, L4 ~w", [Id, K, Mine, Theirs]), Bad = [B|Bad0]
        )
    ;   Ok = Ok0, format(atom(B), "~w ~w: reader ~w, L4 no type", [Id, K, Mine]), Bad = [B|Bad0]
    ).

hover_type(H, T) :-
    V = H.contents.value,
    split_string(V, "\n", " ", Parts),
    exclude([P]>>( P == "" ; sub_string(P, 0, _, _, "```") ), Parts, [T0|_]),
    atom_string(T, T0).

%!  type_text(+Type, -Text) is det.
%
%   A type of the reader's model, written as L4's hover writes it.
type_text(type, 'TYPE') :- !.
type_text(tyapp(N, []), A) :- !, name_text(N, A).
type_text(tyapp(N, Args), A) :- !,
    name_text(N, NA), maplist(arg_text, Args, As),
    atomic_list_concat(As, ', ', AA),
    format(atom(A), "~w OF ~w", [NA, AA]).
type_text(forall_app(R, Ns), A) :- !,
    maplist([N, tyapp(N, [])]>>true, Ns, Ts),
    type_text(tyapp(R, Ts), A).
type_text(fun(As, R), A) :- !,
    maplist(type_text, As, Ts), atomic_list_concat(Ts, ' AND ', AT), type_text(R, RT),
    format(atom(A), "FUNCTION FROM ~w TO ~w", [AT, RT]).
type_text(forall(Ns, T), A) :- !,
    atomic_list_concat(Ns, ' AND ', NA), type_text(T, TA), format(atom(A), "FOR ALL ~w ~w", [NA, TA]).
type_text(T, A) :- format(atom(A), "~w", [T]).

arg_text(tyapp(N, []), A) :- !, name_text(N, A).
arg_text(T, A) :- type_text(T, A0), format(atom(A), "(~w)", [A0]).

%   A record with type parameters: L4 shows its fields' functions for all of
%   those parameters (FOR ALL a FUNCTION FROM Maybe OF a TO a).
type_text_top(fun([forall_app(R, Ns)], T), A) :- !,
    type_text(fun([forall_app(R, Ns)], T), A0),
    atomic_list_concat(Ns, ' AND ', NA),
    format(atom(A), "FOR ALL ~w ~w", [NA, A0]).
type_text_top(T, A) :- type_text(T, A).

name_text(N, A) :-
    (   atom_codes(N, [C|Cs]), code_type(C, alpha), forall(member(X, Cs), (code_type(X, csym)))
    ->  A = N
    ;   format(atom(A), "`~w`", [N])
    ).

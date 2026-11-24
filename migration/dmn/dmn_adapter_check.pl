/*  The DMN adapter, checked on the collections' own test cases

        swipl -q migration/dmn/dmn_adapter_check.pl [-- tck bdt ronl clients]

    For every twin with a mapping (dmn_adapter_map.pl), every case of its
    model's tests (the TCK's test cases, BDT's Bruno requests, the cases
    answered by the oracles: dmn_build:tests_of/4) goes through the adapter
    as a caller sends it, the inputs as JSON named as the model names them,
    and every expected result is compared with the decision the adapter
    gives back, as JSON. This checks the mapping and LE2's adapter kit
    (le_adapter.pl), not the twins: the twins' own scenarios do that.
    Results per collection in runs/adapter-check.txt.
*/

:- initialization(main, main).

:- use_module(dmn_home).
:- use_module(library(main)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module('../le2_paths').
:- use_module(le2(le_adapter)).
:- use_module(dmn_build).
:- use_module(dmn_oracle).
:- use_module(dmn_adapter).
:- use_module(gate, [collection_files/2]).
:- use_module(dmn_reader).

main(Argv) :-
    ( Argv == [] -> Cs = [tck, bdt, ronl, clients] ; maplist([A, C]>>atom_string(C, A), Argv, Cs0), Cs = Cs0 ),
    findall(Line, ( member(C, Cs), check_collection(C, Line) ), Lines),
    dmn_path('runs/adapter-check.txt', Out),
    setup_call_cleanup(open(Out, write, S), forall(member(L, Lines), format(S, "~w~n", [L])), close(S)),
    forall(member(L, Lines), format("~w~n", [L])).

check_collection(C, Line) :-
    twin_root(C, Root),
    dmn_build:distinct_files(C, Files),
    foldl(check_file(C, Root), Files, t(0, 0, 0, []), t(NM, P, F, Fails)),
    format(string(Line), "~w: ~d models, ~d of ~d expected results equal through the adapter~@",
           [C, NM, P, P + F, fails_text(Fails)]).

fails_text([]) :- !.
fails_text(Fails) :- reverse(Fails, Fs), forall(member(X, Fs), format("~n  ~w", [X])).

check_file(C, Root, File, t(M0, P0, F0, X0), t(M, P, F, X)) :-
    model_dir_name(File, Name),
    atomic_list_concat([Root, '/', Name, '/', Name, '.adapter_map.json'], MF),
    (   exists_file(MF),
        adapter_deployment(dmn, Name, Map, _),
        catch(dmn_build:tests_of(C, File, Cases, _), _, Cases = [])
    ->  M is M0 + 1,
        foldl(check_case(Name, Map), Cases, P0-F0-X0, P-F-X)
    ;   M = M0, P = P0, F = F0, X = X0
    ).

check_case(Name, Map, case(Id, _, Inputs, Results), P0-F0-X0, P-F-X) :-
    foldl([N-V, D0, D]>>( dmn_oracle:value_json(V, JV0), plain_json(JV0, JV), atom_string(N, NS), atom_string(K, NS), put_dict(K, D0, JV, D) ),
          Inputs, _{}, In),
    findall(DN, ( member(result(DN0, _, _), Results), atom_string(DN0, DN) ), Wanted),
    (   catch(dmn_adapter_decide(Map, In, Wanted, [], R), E, ( print_message(error, E), fail ))
    ->  foldl(compare_result(Name, Id, R.outputs), Results, P0-F0-X0, P-F-X)
    ;   length(Results, N), P = P0, F is F0 + N,
        format(atom(Msg), "~w ~w: the adapter failed", [Name, Id]), X = [Msg|X0]
    ).

%   The oracle's JSON writes a date as {"@type": "date", "value": ...}; a
%   caller sends the date's text.
plain_json(D, S) :- is_dict(D), get_dict('@type', D, date), !, get_dict(value, D, S).
plain_json(D, P) :- is_dict(D), !, dict_pairs(D, T, Ps), maplist([K-V, K-W]>>plain_json(V, W), Ps, Ps2), dict_pairs(P, T, Ps2).
plain_json(L, P) :- is_list(L), !, maplist(plain_json, L, P).
plain_json(X, X).

compare_result(Name, Id, Outputs, result(DN, _, Expected), P0-F0-X0, P-F-X) :-
    atom_string(DN, DS), atom_string(K, DS),
    ( get_dict(K, Outputs, Got) -> true ; Got = null ),
    dmn_oracle:value_json(Expected, EJ0), plain_json(EJ0, EJ),
    (   same_json(EJ, Got)
    ->  P is P0 + 1, F = F0, X = X0
    ;   P = P0, F is F0 + 1,
        format(atom(Msg), "~w ~w ~w: expected ~q, got ~q", [Name, Id, DN, EJ, Got]), X = [Msg|X0]
    ).

same_json(A, B) :- number(A), number(B), !, ( A =:= B -> true ; abs(A - B) =< 1.0e-9 * max(1, abs(A)) ).
%   An expected structure may name only some components (a Bruno request
%   asserts `res.body.checks.OwnerOccupant` alone): those must be equal.
same_json(A, B) :- is_dict(A), is_dict(B), !,
    dict_pairs(A, _, PA), forall(member(K-V, PA), ( get_dict(K, B, W) -> same_json(V, W) ; V == null )).
same_json(A, B) :- is_list(A), is_list(B), !,
    (   maplist(same_json, A, B) -> true
    ;   msort(A, SA), msort(B, SB), maplist(same_json, SA, SB)
    ).
same_json(A, B) :- string(A), atom(B), !, atom_string(B, A).
same_json(A, B) :- A == B.

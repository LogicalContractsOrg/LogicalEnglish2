/*  Step 4 of the design notes rune.md: a credit support annex read by cdmLOG
    (CDM 8.0.0-dev.4) as the legal agreement of DRR's CDM (6.29), the
    mapping decision 5 of rune.md §10 asks for.

    ./myswipl.sh -q migration/rune/csa_map.pl -- 'migration/rune/data/csa1/CSA 1.md.GOLDEN.pl' [Out.json]

    cdmLOG's extraction is a list of labelled values, each with the path of
    CDM attributes from LegalAgreement down to it (extracted/4). The path is
    walked in DRR's CDM: an attribute of the same name in the type reached
    so far is the same attribute; where CDM 8 renamed a type or an
    attribute, the table rewrite/3 says what CDM 6.29 calls it. A label
    whose path cannot be walked is reported, with the step where the two
    versions part. The values mapped become a LegalAgreement in DRR's JSON
    (Out.json), the party-specific ones (Party1, Party2) as the two items of
    the partyElection list.
*/
:- use_module(parser/rune_reader).
:- use_module(rune_paths).
:- use_module(rune_data, [type_feature/3, value_type/2]).
:- use_module(library(main)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.

:- initialization(main, main).

:- dynamic extracted/4, extraction/6, extractionFingerprints/1, extractedRootType/1,
           extractionMissed/5, extractedObjectArray/5.


main([Gold|Rest]) :-
    json_dir(JD), load_rune_model(JD),
    load_files(Gold, [module(user)]),
    findall(r(L, V, Steps, F), ( user:extracted(L, V, P, F), maplist(step_name, P, Steps) ), Rs),
    root(Root),
    maplist(walk(Root), Rs, Ws),
    include(mapped, Ws, Ok), exclude(mapped, Ws, Bad),
    length(Ws, N), length(Ok, NO),
    format("~w: ~w of ~w labels map to CDM 6.29~n", [Gold, NO, N]),
    forall(member(w(L, _, _, part(At, T, A)), Bad),
           format("  ~w: no attribute ~w in ~w (step ~w)~n", [L, A, T, At])),
    (   Rest = [Out|_]
    ->  instance(Ok, J),
        setup_call_cleanup(open(Out, write, S), json_write_dict(S, J, [width(100)]), close(S)),
        format("written ~w~n", [Out])
    ;   true
    ).

root('cdm.legaldocumentation.common.LegalAgreement').

step_name(attr(N, _, _, _), N).

mapped(w(_, _, _, ok(_))).

%   walk(+Root, +r(Label, Value, Steps, Filters), -w(Label, Value, Filters, ok(Path) | part(I, T, A)))
walk(Root, r(L, V, Steps, F), w(L, V, F, R)) :-
    walk_steps(Steps, 1, Root, Path, R0),
    ( R0 == ok -> R = ok(Path) ; R = R0 ).

walk_steps([], _, _, [], ok).
walk_steps(As0, I, T, Ps, R) :-
    short(T, S), rewrite(S, As0, As1), As1 \== As0, rewrite_fits(T, As0, As1), !,
    walk_steps(As1, I, T, Ps, R).
walk_steps([A|As], I, T, [s(A, Card, T, T1)|Ps], R) :-
    (   type_feature(T, A, feature(TR, Card, _))
    ->  ( value_type(TR, object(T1)) -> true ; T1 = none ),
        I1 is I + 1,
        ( As == [] -> Ps = [], R = ok ; T1 == none -> Ps = [], R = part(I1, TR, As) ; walk_steps(As, I1, T1, Ps, R) )
    ;   Ps = [], T1 = none, R = part(I, T, A)
    ).

%   rewrite(+CDM629Type, +CDM8Steps, -CDM629Steps): where the two versions
%   name the same thing differently, at a type of DRR's CDM.
rewrite(_, [A, A], [A]).                      % cdmLOG's step for an option named as its attribute

%   cdmLOG's double step (deliveryAmount -> deliveryAmount) is one attribute
%   in CDM 6.29 only where that attribute is a text or an enumeration
%   there (CreditSupportAmount is an object in 6.29).
rewrite_fits(T, [A, A], [A]) :- !,
    type_feature(T, A, feature(TR, _, _)), \+ value_type(TR, object(_)).
rewrite_fits(_, _, _).
rewrite('ElectiveAmountElection', [fixedAmount|R], R).
rewrite('CalculationAndTiming', [valuationDate|R], [legacyValuationDate|R]).
rewrite('CalculationAndTiming', [valuationTime|R], [legacyValuationTime|R]).
rewrite('CalculationAndTiming', [valuationAgent|R], [legacyValuationAgent|R]).

short(T, S) :- atomic_list_concat(Ps, '.', T), last(Ps, S).

% ---------------------------------------------------------------- the instance

%   The mapped values as one JSON object: a party filter (Party1, Party2)
%   puts the value in the first or the second item of the nearest list
%   attribute on its path (partyElection, 2..2), with its party role.
instance(Ws, J) :-
    foldl(put_value, Ws, _{}, J).

put_value(w(_, V, F, ok(Path)), J0, J) :-
    ( member(filter(_, Party), F) -> party_index(Party, I) ; I = none ),
    json_value(V, JV),
    put_path(Path, I, Party, JV, J0, J).

party_index('Party1', 0).
party_index('Party2', 1).

json_value(V, V) :- number(V), !.
json_value(L, L) :- is_list(L), !.
json_value(V, S) :- atom_string(V, S).

put_path([s(A, _, Owner, _)], _, _, V0, J0, J) :- !,
    %  a value with metadata (a currency, a scheme) is DRR's FieldWithMeta
    (   type_feature(Owner, A, feature(_, _, Meta)), is_dict(Meta), dict_pairs(Meta, _, [_|_])
    ->  ( is_list(V0) -> findall(_{value: X}, member(X, V0), V) ; V = _{value: V0} )
    ;   V = V0 ),
    put_dict(A, J0, V, J).
put_path([s(A, card(_, Max), _, T)|Ps], I, Party, V, J0, J) :-
    (   Max \== 1, I \== none
    ->  ( get_dict(A, J0, L0) -> true ; role_attribute(T, RA), dict_pairs(E1, _, [RA-"Party1"]), dict_pairs(E2, _, [RA-"Party2"]), L0 = [E1, E2] ),
        nth0(I, L0, E0),
        put_path(Ps, I, Party, V, E0, E),
        replace_nth0(I, L0, E, L),
        put_dict(A, J0, L, J)
    ;   ( get_dict(A, J0, E0) -> true ; E0 = _{} ),
        put_path(Ps, I, Party, V, E0, E),
        put_dict(A, J0, E, J)
    ).

%   The attribute of a party's election that says whose it is (party,
%   partyRole: a CounterpartyRoleEnum).
role_attribute(T, RA) :-
    type_feature(T, RA, feature('cdm.base.staticdata.party.CounterpartyRoleEnum', _, _)), !.
role_attribute(_, party).

replace_nth0(I, L0, E, L) :- nth0(I, L0, _, R), nth0(I, L, E, R).

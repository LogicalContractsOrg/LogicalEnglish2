/** <module> Generated cases for a rulemap, answered by the oracle

    A rulemap comes with no tests (the design notes ruml.md §8). For each
    one, cases are made from what its expressions compare: for a number
    compared with N, the values N-1, N and N+1; for a text, the texts it is
    compared with and one more; for a truth value, both; for a date, the
    day before, the day, the day after; and each data point missing in
    turn. The first case gives every data point its first value; each
    further case changes one data point; then a few cases change several.
    A set that can repeat gets zero, one and two members.

    The oracle (ruml_oracle.mjs) answers each case in the `complete` mode;
    the expected status of a node is the one its paths agree on.

        generated_cases(+Doc, +File, -Cases)    case(Id, Desc, Inputs, Expected)
        oracle_results(+File, +Cases, +Mode, -Results)   Id-[Path-(LexId-Status)]
        case_inputs(+Doc, -InputSets)
*/

:- module(ruml_cases, [generated_cases/3, second_opinion/1, oracle_results/4, case_inputs/2, max_cases/1, read_datapoints/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(http/json)).
:- use_module(library(sha)).
:- use_module(library(filesex)).
:- use_module(ruml_reader).
:- use_module(jsonata_parser).

max_cases(40).

here(D) :- module_property(ruml_cases, file(F)), file_directory_name(F, D).

generated_cases(Doc, File, Cases) :-
    case_inputs(Doc, Inputs),
    findall(case(Id, Desc, In, []), ( nth1(I, Inputs, In-Desc), format(atom(Id), 'generated_~d', [I]) ), Cases0),
    oracle_results(File, Cases0, complete, Rs),
    nodes(Doc, Ns), length(Ns, NN),
    findall(case(Id, Desc, In, Exp),
            ( member(case(Id, Desc, In, _), Cases0), memberchk(Id-PRs, Rs),
              findall(L-S, ( member(_-(L-S), PRs), S \== ignored, ( NN =< 12 -> true ; L == '1' ; node(Doc, L, N), j(N, children, [_|_]) ) ), E0),
              agreed(E0, Exp), Exp \== [] ),
            Cases).

agreed(E0, E) :- sort(E0, E1), findall(L-S, ( member(L-S, E1), \+ ( member(L-S2, E1), S2 \== S ) ), E).

		 /*******************************
		 *          THE VALUES          *
		 *******************************/

%!  case_inputs(+Doc, -Inputs) is det.   [Pairs-Description]
case_inputs(Doc, Inputs) :-
    datapoints(Doc, DPs),
    read_datapoints(Doc, Read),
    findall(Id-Vs, ( member(Id-DP, DPs), memberchk(Id, Read), values_of(Doc, Id, DP, Vs) ), IdVs),
    (   IdVs == [] -> leaf_cases(Doc, [], LCs), append([[]-'no data'], LCs, Inputs)
    ;   findall(Id-V, ( member(Id-[V|_], IdVs) ), Base),
        findall(In-Desc,
                ( member(Id-Vs, IdVs), member(V, [missing|Vs]),
                  \+ memberchk(Id-V, Base),
                  replace(Base, Id, V, In), describe(Id, V, Desc) ),
                One),
        mixes(IdVs, Base, Mixed),
        append([[Base-'every data point its first value'], One, Mixed], All0a),
        leaf_cases(Doc, Base, LCs), append(All0a, LCs, All0),
        dedupe(All0, All),
        max_cases(Max), length(All, L), ( L > Max -> length(Inputs0, Max), append(Inputs0, _, All) ; Inputs0 = All ),
        maplist(without_missing, Inputs0, Inputs)
    ).

%   Leaves that no capability decides: a person's answer (the oracle's
%   `leaves`, Appendix A's leaf statuses). Every one true; each false in
%   turn; every one false.
leaf_cases(Doc, Base, Cases) :-
    answer_leaves(Doc, Ls),
    (   Ls == [] -> Cases = []
    ;   findall('$leaf'(L)-true, member(L, Ls), AllTrue),
        findall('$leaf'(L)-false, member(L, Ls), AllFalse),
        append(Base, AllTrue, C1),
        findall(In-D, ( member(L, Ls), replace(AllTrue, '$leaf'(L), false, LT), append(Base, LT, In),
                        format(atom(D), 'the leaf ~w answered no, the others yes', [L]) ), Each),
        append(Base, AllFalse, C2),
        append([[C1-'every leaf answered yes'], Each, [C2-'every leaf answered no']], Cases)
    ).

%   The leaves with no deciding capability.
answer_leaves(Doc, Ls) :-
    nodes(Doc, Ns),
    findall(L, ( member(L-N, Ns), \+ j(N, children, [_|_]), node_caps(N, Es),
                 \+ ( member(cap(Id, _), Es), capability_role(Doc, Id, decision) ) ), Ls).

%   A case's inputs without those marked missing.
without_missing(In0-D, In-D) :- exclude(is_missing, In0, In).
is_missing(_-V) :- V == missing.

replace(Base, Id, V, In) :- maplist({Id, V}/[K-V0, K-V1]>>( K == Id -> V1 = V ; V1 = V0 ), Base, In).
describe(Id, missing, D) :- !, format(atom(D), '~w has no value', [Id]).
describe(Id, @(V), D) :- !, format(atom(D), '~w is ~w', [Id, V]).
describe(Id, V, D) :- format(atom(D), '~w is ~q', [Id, V]).

%   A few cases that change several data points at once: the last value of
%   each, and, alternately, the second.
mixes(IdVs, _, Mixed) :-
    findall(Id-V, ( member(Id-Vs, IdVs), last(Vs, V) ), Last),
    findall(Id-V, ( nth1(I, IdVs, Id-Vs), ( I mod 2 =:= 0, Vs = [_, V|_] -> true ; Vs = [V|_] ) ), Alt),
    findall(Id-missing, member(Id-_, IdVs), None),
    Mixed = [Last-'every data point its last value', Alt-'every second data point changed', None-'no data'].

dedupe(L0, L) :- foldl([X-D, Acc0, Acc]>>( memberchk(X-_, Acc0) -> Acc = Acc0 ; append(Acc0, [X-D], Acc) ), L0, [], L).

datapoints(Doc, DPs) :-
    capabilities(Doc, Cs),
    (   member(C, Cs), j(C, id, "ruml:datapoints"), j(C, payload, P), j(P, data, json(D))
    ->  findall(Id-DP, ( member(Id=DP, D), j(DP, binding, B), \+ j(B, type, "computed") ), DPs)
    ;   DPs = []
    ).

%   The values of a data point worth trying.
values_of(Doc, Id, DP, Vs) :-
    j(DP, type, T0, "string"), atom_string(T, T0),
    findall(K, compared_constant(Doc, Id, K), Ks0), sort(Ks0, Ks),
    (   T == object -> object_values(Doc, DP, Vs)
    ;   T == boolean -> Vs = [@(true), @(false)]
    ;   j(DP, options, Os), Os \== [] -> findall(V, ( member(O, Os), j(O, value, V) ), Vs0), append(Vs0, ["other"], Vs)
    ;   memberchk(T, [number, integer, currency, percentage, count])
    ->  findall(V, ( member(K, Ks), number(K), member(D, [0, -1, 1]), V is K + D ), Vs0),
        ( Vs0 == [] -> Vs1 = [0, 100] ; Vs1 = Vs0 ), list_to_set(Vs1, Vs)
    ;   T == date
    ->  findall(V, ( member(K, Ks), string(K), member(D, [0, -1, 1]), day_shift(K, D, V) ), Vs0),
        ( Vs0 == [] -> Vs = ["2024-01-01"] ; list_to_set(Vs0, Vs) )
    ;   findall(K, ( member(K, Ks), string(K) ), Ss), append(Ss, ["other"], Vs)
    ).

day_shift(S, D, V) :-
    split_string(S, "-", "", [Y, M, Dd]), number_string(Yn, Y), number_string(Mn, M), number_string(Dn, Dd),
    date_time_stamp(date(Yn, Mn, Dn, 12, 0, 0, 0, -, -), St), St1 is St + D * 86400,
    format_time(string(V), "%F", St1).

%   A set: zero, one and two members, their fields given their first values.
object_values(Doc, DP, Vs) :-
    j(DP, set, S0), datapoints_sets(Doc, Sets), j(Sets, S0, Set), j(Set, fields, json(Fs)),
    findall(F-V, ( member(F=FD, Fs), \+ j(FD, type, "object"), values_of(Doc, F, FD, [V|_]) ), Base),
    findall(F-V, ( member(F=FD, Fs), \+ j(FD, type, "object"), values_of(Doc, F, FD, FVs), last(FVs, V) ), Other),
    M1 = json(Base), M2 = json(Other),
    (   j(DP, cardinality, Card), j(Card, max, Max), Max > 1 -> Vs = [[M1], [M1, M2], []]
    ;   Vs = [M1, M2]
    ).
datapoints_sets(Doc, Sets) :-
    capabilities(Doc, Cs), member(C, Cs), j(C, id, "ruml:datapoints"), j(C, payload, P), j(P, sets, Sets), !.

%   A constant that an expression compares a data point (or a field) with.
compared_constant(Doc, Id, K) :-
    expression(Doc, E), jsonata_parse(E, T),
    sub_term(bin(Op, A, B), T), memberchk(Op, ['<', '<=', '>', '>=', '=', '!=']),
    (   names(A, Id), constant(B, K) ; names(B, Id), constant(A, K) ).
compared_constant(Doc, Id, K) :-
    expression(Doc, E), jsonata_parse(E, T),
    sub_term(bin(in, A, array(Es)), T), names(A, Id), member(X, Es), constant(X, K).
compared_constant(Doc, Id, K) :-
    expression(Doc, E), jsonata_parse(E, T),
    sub_term(call(lookup, [object(Ps), A]), T), names(A, Id), member(str(K)-_, Ps).
%   A data point used in arithmetic: the constant the result is compared
%   with, roughly (`2024 - dp_birth_year >= 18` tries 2006).
compared_constant(Doc, Id, K) :-
    expression(Doc, E), jsonata_parse(E, T),
    sub_term(bin(Op, bin('-', num(A), name(Id)), num(B)), T), memberchk(Op, ['<', '<=', '>', '>=']),
    K is A - B.

%!  read_datapoints(+Doc, -Ids) is det.
%   The data points that an expression reads (a computed data point's
%   expression included): only those are worth a value in a case.
read_datapoints(Doc, Ids) :-
    findall(Id, ( expression(Doc, E), jsonata_parse(E, T), jsonata_names(T, Ns), member(Id0, Ns), atom_string(Id0, S), atom_string(Id, S) ), Ids0),
    sort(Ids0, Ids).

names(name(Id), Id).
names(path(_, name(Id)), Id).
constant(num(N), N).
constant(str(S), S).

expression(Doc, E) :-
    nodes(Doc, Ns), member(_-N, Ns), node_caps(N, Es), member(cap(_, P), Es), j(P, expression, E).
expression(Doc, E) :-
    capabilities(Doc, Cs), member(C, Cs), j(C, id, "ruml:datapoints"), j(C, payload, P), j(P, data, json(D)),
    member(_=DP, D), j(DP, binding, B), j(B, expression, E).

		 /*******************************
		 *          THE ORACLE          *
		 *******************************/

%!  oracle_results(+File, +Cases, +Mode, -Results) is det.
%   Id-[Path-(LexId-Status)], cached by the hash of the request in
%   runs/oracle/ (gitignored).
oracle_results(_, [], _, []) :- !.
oracle_results(File, Cases, Mode, Results) :-
    findall(json([id=Id, inputs=json(KVs), leaves=json(LVs), mode=Mode]),
            ( member(case(Id, _, In, _), Cases),
              findall(K=V, ( member(K-V0, In), atom(K), json_input(V0, V) ), KVs),
              findall(L=S, ( member('$leaf'(L)-B, In), atom_string(B, S) ), LVs) ), Js),
    with_output_to(string(Req), json_write(current_output, json([file=File, cases=Js]), [width(0)])),
    read_file_to_string(File, Content, []),            % the file's content, not only its path
    string_concat(Req, Content, Key),
    sha_hash(Key, H0, []), hash_atom(H0, H),
    here(D), atomic_list_concat([D, '/runs/oracle'], CD), make_directory_path(CD),
    atomic_list_concat([CD, '/', H, '.jsonl'], Cache),
    (   exists_file(Cache) -> read_file_to_string(Cache, Out, [])
    ;   atomic_list_concat([D, '/ruml_oracle.mjs'], Script),
        process_create(path(node), [Script], [stdin(pipe(In)), stdout(pipe(O)), stderr(null)]),
        write(In, Req), close(In), read_string(O, _, Out), close(O),
        setup_call_cleanup(open(Cache, write, W), write(W, Out), close(W))
    ),
    split_string(Out, "\n", "", Ls),
    findall(Id-PRs, ( member(L, Ls), L \== "", atom_json_dict(L, J, []), atom_string(Id, J.id),
                      dict_pairs(J.results, _, Ps),
                      findall(P-(Lx-S), ( member(P-R, Ps), atom_string(Lx, R.lexId), atom_string(S, R.status) ), PRs) ),
            Results).

		 /*******************************
		 *       THE SECOND OPINION     *
		 *******************************/

%!  second_opinion(+Collections) is det.
%   The generated cases of every rulemap of the collections, written for
%   second_opinion.mjs, which runs it.
second_opinion(Cols) :-
    findall(json([file=File, cases=Js]),
            ( member(C, Cols), ruml_build:collection_files(C, Fs), member(File, Fs),
              ruml_read_file(File, Doc, Is), Doc \== none, \+ ( member(I, Is), ruml_build:fatal_issue(I) ),
              case_inputs(Doc, Ins),
              findall(json([id=Id, inputs=json(KVs)]),
                      ( nth1(N, Ins, In-_), format(atom(Id), 'generated_~d', [N]), findall(K=V, member(K-V, In), KVs) ), Js) ),
            Req),
    here(D), atomic_list_concat([D, '/runs/second-opinion-cases.json'], F),
    setup_call_cleanup(open(F, write, O), json_write(O, Req, [width(0)]), close(O)),
    atomic_list_concat([D, '/second_opinion.mjs'], Script),
    process_create(path(node), [Script, F], [stdout(pipe(Out))]), read_string(Out, _, S), close(Out),
    write(S).

json_input(true, @(true)) :- !.
json_input(false, @(false)) :- !.
json_input(V, V).

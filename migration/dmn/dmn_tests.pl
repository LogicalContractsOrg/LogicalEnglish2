/** <module> The tests of a DMN model

    The DMN TCK's `testCases` files (the schema TestCases/testCases.xsd of
    the kit): each test case gives the values of input nodes and the
    expected values of result nodes (decisions, or BKMs and decision
    services invoked). A value is

        v(Atomic)          a decimal (an exact rational), string, boolean,
                           or a temporal value date(Y,M,D) / text of its kind
        null
        list([Value])
        ctx([Name-Value])  a context (a structure of components)

        tck_cases(+TestFile, -ModelName, -Cases)
        Cases = [case(Id, Description, Inputs, Results)]
        Inputs = [Name-Value], Results = [result(Name, Type, Value)]
*/

:- module(dmn_tests, [tck_cases/3, tck_test_files/2, bruno_cases/3]).

:- use_module(library(sgml)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(http/json)).
:- use_module(library(readutil)).

%!  tck_test_files(+ModelFile, -TestFiles) is det.
tck_test_files(ModelFile, Files) :-
    file_directory_name(ModelFile, Dir),
    directory_files(Dir, Es),
    findall(F, ( member(E, Es), sub_atom(E, _, _, 0, '.xml'), sub_atom(E, _, _, _, '-test-'),
                 directory_file_path(Dir, E, F) ), Fs),
    msort(Fs, Files).

tck_cases(File, ModelName, Cases) :-
    load_structure(File, DOM, [dialect(xmlns), space(remove), keep_prefix(false)]),
    member(element(_:testCases, _, C), DOM), !,
    ( member(element(_:modelName, _, [ModelName]), C) -> true ; ModelName = '' ),
    findall(Case, ( member(element(_:testCase, A, TC), C), test_case(A, TC, Case) ), Cases).

test_case(A, C, case(Id, Desc, Inputs, Results)) :-
    ( memberchk(id=Id, A) -> true ; Id = '' ),
    ( member(element(_:description, _, [Desc0]), C) -> normalize_space(atom(Desc), Desc0) ; Desc = '' ),
    findall(N-V, ( member(element(_:inputNode, IA, IC), C), memberchk(name=N, IA), node_value(IC, V) ), Inputs),
    findall(result(N, T, V),
            ( member(element(_:resultNode, RA, RC), C), memberchk(name=N, RA),
              ( memberchk(type=T, RA) -> true ; T = decision ),
              ( member(element(_:expected, _, EC), RC) -> node_value(EC, V) ; V = null ) ),
            Results).

%   The value an inputNode / expected / component / item holds.
node_value(C, V) :-
    (   member(element(_:value, A, VC), C) -> value(A, VC, V)
    ;   member(element(_:list, LA, LC), C) -> list_value(LA, LC, V)
    ;   findall(N-CV, ( member(element(_:component, CA, CC), C), memberchk(name=N, CA), node_value(CC, CV) ), Cs),
        Cs \== [] -> V = ctx(Cs)
    ;   V = null
    ).

list_value(A, _, null) :- nil(A), !.
list_value(_, C, list(Vs)) :-
    findall(V, ( member(element(_:item, _, IC), C), node_value(IC, V) ), Vs).

value(A, _, null) :- nil(A), !.
value(A, C, V) :-
    ( member(K=T0, A), local(K, type) -> local_type(T0, T) ; T = string ),
    ( C = [Text] -> true ; C == [] -> Text = '' ; Text = '' ),
    typed(T, Text, V).

nil(A) :- member(K=V, A), local(K, nil), V == true.

local(_:L, L) :- !.
local(L, L).

local_type(T0, T) :- ( sub_atom(T0, B, 1, _, ':') -> B1 is B + 1, sub_atom(T0, B1, _, 0, T) ; T = T0 ).

typed(decimal, Text, v(N)) :- !, decimal_value(Text, N).
typed(double, Text, v(N)) :- !, decimal_value(Text, N).
typed(integer, Text, v(N)) :- !, decimal_value(Text, N).
typed(int, Text, v(N)) :- !, decimal_value(Text, N).
typed(long, Text, v(N)) :- !, decimal_value(Text, N).
typed(boolean, Text, v(B)) :- !, ( Text == true -> B = true ; B = false ).
typed(date, Text, v(date(Y, M, D))) :- atom(Text), atomic_list_concat([Ys, Ms, Ds], '-', Text),
    atom_number(Ys, Y), atom_number(Ms, M), atom_number(Ds, D), !.
typed(dateTime, Text, v(datetime(Text))) :- !.
typed(time, Text, v(time(Text))) :- !.
typed(duration, Text, v(duration(Text))) :- !.
typed(_, Text, v(S)) :- atom_string(Text, S).

decimal_value(Text, N) :-
    normalize_space(atom(T), Text),
    (   catch(feel_parser:feel_parse(T, [], num(N0)), _, fail) -> N = N0
    ;   sub_atom(T, 0, 1, _, '-'), sub_atom(T, 1, _, 0, T1), catch(feel_parser:feel_parse(T1, [], num(N1)), _, fail)
    ->  N is -N1
    ;   atom_number(T, N0) -> N is rationalize(N0)
    ;   N = 0
    ).

		 /*******************************
		 *     BRUNO REQUESTS (BDT)     *
		 *******************************/

%!  bruno_cases(+TestRoot, +ModelName, -Cases) is det.
%
%   The Benefit Decision Toolkit tests a model by Bruno requests to its
%   decision service, in a folder named after the model: each `.bru` file
%   posts a JSON body (the inputs) and asserts `res.body.<decision>: eq
%   <value>` (a component of a decision: `res.body.checks.OwnerOccupant`).
bruno_cases(Root, ModelName, Cases) :-
    findall(F, ( directory_member(Root, F, [recursive(true), extensions([bru])]),
                 file_directory_name(F, D), file_base_name(D, ModelName) ), Fs0),
    msort(Fs0, Fs),
    findall(C, ( member(F, Fs), bruno_case(F, C) ), Cases).

bruno_case(F, case(Id, '', Inputs, Results)) :-
    file_base_name(F, B), file_name_extension(Id, _, B),
    read_file_to_string(F, S, [encoding(utf8)]),
    sub_string(S, BJ, _, _, "body:json {"), !,
    sub_string(S, BJ, _, 0, Rest0), sub_string(Rest0, 11, _, 0, Rest1),
    sub_string(Rest1, BO, _, _, "{"), !, sub_string(Rest1, BO, _, 0, Rest),     % the JSON inside Bruno's block
    json_block(Rest, JsonText),
    catch(term_string_json(JsonText, Dict), _, fail),
    dict_pairs(Dict, _, Pairs),
    findall(N-V, ( member(K-J, Pairs), atom_string(K, NS), atom_string(N, NS), json_v(J, V) ), Inputs),
    split_string(S, "\n", "", Lines),
    findall(R, ( member(L0, Lines), split_string(L0, "", " \t", [L]), bruno_assert(L, R) ), Rs0),
    merge_results(Rs0, Results),
    Results \== [].

%   The JSON object that starts the string: up to its matching brace.
json_block(S, J) :-
    string_codes(S, Cs), json_end(Cs, 0, 0, N), N > 0, sub_string(S, 0, N, _, J).

json_end([], _, _, 0).
json_end([C|Cs], I, D, N) :-
    I1 is I + 1,
    (   C =:= 0'{ -> D1 is D + 1, json_end(Cs, I1, D1, N)
    ;   C =:= 0'}, D =:= 1 -> N = I1
    ;   C =:= 0'} -> D1 is D - 1, json_end(Cs, I1, D1, N)
    ;   C =:= 0'" -> json_string_end(Cs, I1, D, N)
    ;   json_end(Cs, I1, D, N)
    ).
json_string_end([0'\\, _|Cs], I, D, N) :- !, I2 is I + 2, json_string_end(Cs, I2, D, N).
json_string_end([0'"|Cs], I, D, N) :- !, I1 is I + 1, json_end(Cs, I1, D, N).
json_string_end([_|Cs], I, D, N) :- I1 is I + 1, json_string_end(Cs, I1, D, N).
json_string_end([], _, _, 0).

term_string_json(Text, Dict) :-
    open_string(Text, In), json_read_dict(In, Dict, [value_string_as(string)]).

json_v(null, null) :- !.
json_v(true, v(true)) :- !.
json_v(false, v(false)) :- !.
json_v(N, v(R)) :- number(N), !, ( integer(N) -> R = N ; R is rationalize(N) ).
json_v(S, v(D)) :- string(S), split_string(S, "-", "", [Y, M, Dd]), string_length(Y, 4),
    number_string(YN, Y), number_string(MN, M), number_string(DN, Dd), !, D = date(YN, MN, DN).
json_v(S, v(S)) :- string(S), !.
json_v(L, list(Vs)) :- is_list(L), !, maplist(json_v, L, Vs).
json_v(D, ctx(Cs)) :- is_dict(D), dict_pairs(D, _, Ps),
    findall(N-V, ( member(K-J, Ps), atom_string(K, NS), atom_string(N, NS), json_v(J, V) ), Cs).

%   `res.body.isEligible: eq true`, `res.body.checks.OwnerOccupant: eq null`
bruno_assert(L, R) :-
    sub_string(L, 0, _, _, "res.body."),
    split_string(L, ":", " ", [Path, Rhs]),
    split_string(Rhs, " ", "", ["eq"|Vs]), atomic_list_concat(Vs, ' ', VT),
    sub_string(Path, 9, _, 0, P), split_string(P, ".", "", Parts),
    atom_string(VA, VT), value_text(VA, V),
    maplist([X, Y]>>atom_string(Y, X), Parts, As),
    path_result(As, V, R).

value_text(true, v(true)) :- !.
value_text(false, v(false)) :- !.
value_text(null, null) :- !.
value_text(A, v(N)) :- atom_number(A, N0), !, N is rationalize(N0).
value_text(A, v(S)) :- atom_string(A, S0), ( sub_string(S0, 0, 1, _, "\""), sub_string(S0, 1, _, 1, S) -> true ; S = S0 ).

path_result([D], V, result(D, decision, V)) :- !.
path_result([D|Ps], V, result(D, decision, ctx([C]))) :- nest(Ps, V, C).
nest([P], V, P-V) :- !.
nest([P|Ps], V, P-ctx([C])) :- nest(Ps, V, C).

%   The assertions on components of one decision, as one structure.
merge_results(Rs0, Rs) :-
    findall(D, member(result(D, _, _), Rs0), Ds0), list_to_set(Ds0, Ds),
    findall(R, ( member(D, Ds), findall(V, member(result(D, _, V), Rs0), Vs), merge_values(Vs, MV), R = result(D, decision, MV) ), Rs).

merge_values([V], V) :- !.
merge_values(Vs, ctx(Cs)) :- findall(C, member(ctx([C]), Vs), Cs).

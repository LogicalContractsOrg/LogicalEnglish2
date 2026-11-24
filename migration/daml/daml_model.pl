/** <module> A Daml project as the translator sees it: templates, flat fields, choices, scripts

    The parsed modules of a project (daml_syntax.pl) gathered into one model:
    data records, templates with their fields FLATTENED (a record-valued
    field such as SimpleIou's `cash : Cash`, or IouTransfer's `iou : Iou`,
    becomes its leaves, `cash.currency`, `cash.amount`), and the test
    scripts (functions whose `do` block submits commands).

      project_model(+Files, -model(Datas, Templates, Funs, Others, Aliases))
        Datas     [data(Name, Fields)]
        Templates [tpl(Name, Module, Flat, Signatories, Observers, Ensures,
                       Choices, Residue)]
                  Flat [fld(Path, Type)] (Path a list of field names)
                  Choices [ch(Kind, Name, RetType, Args, Controllers, Body)]
                  Residue [other(Kind, Text)] (keys, interface instances, ...)
        Funs      [fun(Module, Name, Args, Expr)]
        Others    [other(Module, Kind, Text)] — module-level residue
        Aliases   [Name-Type] (`type IouCid = ContractId Iou`)
*/

:- module(daml_model, [project_model/2, flat_fields/3, template_named/3, script_fun/2,
                       snake/2, words/2, base_type/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(daml_syntax).

project_model(Files, model(Datas, Tpls, Funs, Others, Aliases)) :-
    maplist(daml_module, Files, Mods),
    findall(data(N, Fs), ( member(module(_, Ds), Mods), member(data(N, _, Fs), Ds) ), Datas0),
    findall(tpl0(N, M, Fs, B), ( member(module(M, Ds), Mods), member(template(N, Fs, B), Ds) ), T0),
    %  the twin names a template by its name: two of one name would merge
    (   member(tpl0(N, M1, _, _), T0), member(tpl0(N, M2, _, _), T0), M1 @< M2
    ->  throw(error(domain_error(one_template_per_name, N), context(project_model/2, M1-M2)))
    ;   true
    ),
    %  a template's type is a record too (IouTransfer's `iou : Iou`)
    findall(data(N, Fs), member(tpl0(N, _, Fs, _), T0), TData),
    append(Datas0, TData, Datas),
    maplist(template(Datas), T0, Tpls),
    findall(fun(M, N, As, E), ( member(module(M, Ds), Mods), member(fun(N, As, E), Ds) ), Funs),
    findall(other(M, K, T), ( member(module(M, Ds), Mods), member(other(K, T), Ds),
                              \+ memberchk(K, [import]) ), Others),
    findall(N-Ty, ( member(module(_, Ds), Mods), member(type_alias(N, Ty), Ds) ), Aliases).

template(Datas, tpl0(N, M, Fs, Body), tpl(N, M, Flat, Sigs, Obs, Ens, Chs, Res)) :-
    flat_fields(Datas, Fs, Flat),
    findall(E, ( member(signatory(Es), Body), member(E, Es) ), Sigs),
    findall(E, ( member(observer(Es), Body), member(E, Es) ), Obs),
    findall(E, member(ensure(E), Body), Ens),
    findall(ch(K, C, Ty, As, Ctrl, B), member(choice(K, C, Ty, As, Ctrl, B), Body), Chs),
    findall(other(K, T), member(other(K, T), Body), Res).

%!  flat_fields(+Datas, +Fields, -Flat) is det.
flat_fields(Datas, Fs, Flat) :-
    findall(F, ( member(N-Ty, Fs), flat(Datas, [N], Ty, F) ), Flat).

flat(Datas, P, con(D, []), F) :- memberchk(data(D, Fs), Datas), !,
    member(N-Ty, Fs), append(P, [N], P1), flat(Datas, P1, Ty, F).
flat(_, P, Ty, fld(P, Ty)).

template_named(model(_, Ts, _, _, _), N, T) :- member(T, Ts), T = tpl(N, _, _, _, _, _, _, _), !.

%   A script: a function whose body submits commands or allocates parties.
script_fun(model(_, _, Funs, _, _), fun(M, N, As, E)) :-
    member(fun(M, N, As, E), Funs),
    once(( sub_term(X, E), X = var(V), memberchk(V, [submit, submitMustFail, allocateParty, allocatePartyByHint,
                                                    submitMulti, createCmd, exerciseCmd]) )).

%   Types a place holds directly.
base_type(con(T, [])) :- memberchk(T, ['Party', 'Text', 'Decimal', 'Int', 'Bool', 'Date', 'Time', 'Numeric']), !.
base_type(con('ContractId', _)).
base_type(list(_)).
base_type(con('Optional', _)).

%   Names: IouTransfer -> iou_transfer; newOwner -> new owner.
snake(A, S) :- words(A, Ws), atomic_list_concat(Ws, '_', S).

words(A, Ws) :-
    atom_codes(A, Cs),
    split_words(Cs, Groups),
    findall(W, ( member(G, Groups), G \== [], atom_codes(W0, G), downcase_atom(W0, W) ), Ws).

split_words([], [[]]).
split_words([C|Cs], [[]|Gs]) :- ( C == 0'_ ; C == 0'. ), !, split_words(Cs, Gs).
split_words([C|Cs], [[C|G]|Gs]) :-
    (   Cs = [N|_], code_type(N, upper), \+ code_type(C, upper)
    ->  G = [], split_words(Cs, Gs)                  % a new word starts at N
    ;   split_words(Cs, [G|Gs])
    ).

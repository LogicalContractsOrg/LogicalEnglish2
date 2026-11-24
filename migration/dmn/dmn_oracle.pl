/** <module> The oracle: Apache KIE Drools DMN 10.2.0 on given cases

    oracle_answers(+ModelFiles, +Cases, -Answered) runs oracle/dmn-oracle.jar
    (oracle/README.md) on the cases of one model and gives each case back
    with the oracle's results as its expected results:

        Cases    = [case(Id, Desc, Inputs, Decisions)]   Inputs = [Name-Value]
        Answered = [case(Id, Desc, Inputs, Results)]     Results = [result(Name, decision, Value)]

    Values as dmn_tests.pl writes them (v(X), null, list(Vs), ctx(Cs)).
    The run is kept in runs/oracle/<key>.json, the key a hash of the model
    files and the cases: a run is redone only when either changes. The
    type check is off (`--no-typecheck`), as Kogito runs: with it, STTR's
    COLLECT decisions declared `feel:string` give null instead of their
    list (oracle/README.md).
*/

:- module(dmn_oracle, [oracle_answers/3, oracle_answers/4, camunda_answers/3, camunda_file/1]).

:- use_module(dmn_home).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(process)).
:- use_module(library(sha)).
:- use_module(library(http/json)).
:- use_module(library(readutil)).

oracle_jar(J) :- dmn_path('oracle/target/dmn-oracle.jar', J).
camunda_jar(J) :- dmn_path('oracle-camunda/target/camunda-dmn-oracle.jar', J).
runs_dir(D) :- dmn_path('runs/oracle', D).

oracle_answers(Models, Cases, Answered) :- oracle_answers(Models, Cases, [], Answered).

%   Options: normalise (the oracle's --normalise, for Camunda Modeler
%   files: oracle/README.md).
oracle_answers(_, [], _, []) :- !.
oracle_answers(Models, Cases, Opts, Answered) :-
    runs_dir(Dir), make_directory_path(Dir),
    maplist(case_json, Cases, Js0),
    (   Models = [Main, _|_]
    ->  atom_string(Main, MS), maplist(with_model(MS), Js0, Js)
    ;   Js = Js0
    ),
    with_output_to(string(CasesText), json_write_dict(current_output, Js, [width(0)])),
    maplist([F, T]>>read_file_to_string(F, T, []), Models, MTs),
    format(atom(OptText), "~w", [Opts]),
    atomic_list_concat([OptText, CasesText|MTs], Key0), sha_hash(Key0, H, []), hash_atom(H, Key),
    atomic_list_concat([Dir, '/', Key, '.cases.json'], CF),
    atomic_list_concat([Dir, '/', Key, '.results.json'], RF),
    (   exists_file(RF) -> true
    ;   setup_call_cleanup(open(CF, write, O, [encoding(utf8)]), write(O, CasesText), close(O)),
        oracle_jar(Jar),
        ( memberchk(normalise, Opts) -> Norm = ['--normalise'] ; Norm = [] ),
        append([['-Xmx2g', '-jar', Jar, eval, '--no-typecheck'], Norm, ['--models'], Models,
                ['--cases', CF, '--out', RF]], Args),
        process_create(path(java), Args, [stdout(null), stderr(null), process(P)]),
        process_wait(P, _)
    ),
    (   exists_file(RF)
    ->  setup_call_cleanup(open(RF, read, In, [encoding(utf8)]), json_read_dict(In, Rs, [value_string_as(string)]), close(In)),
        maplist(answered(Rs), Cases, Answered0),
        include([case(_, _, _, R)]>>(R \== []), Answered0, Answered)
    ;   Answered = []
    ).

with_model(M, J0, J) :- put_dict(model, J0, M, J).

case_json(case(Id, _, Inputs, Decisions), J) :-
    format(string(SId), "~w", [Id]),
    foldl([N-V, D0, D]>>( value_json(V, JV), atom_string(N, NS), atom_string(KA, NS), put_dict(KA, D0, JV, D) ),
          Inputs, _{}, InD),
    (   Decisions == all -> J = _{id: SId, inputs: InD}
    ;   maplist([D, S]>>atom_string(D, S), Decisions, DS), J = _{id: SId, inputs: InD, decisions: DS}
    ).

value_json(null, null) :- !.
value_json(v(X), J) :- !, atomic_json(X, J).
value_json(list(Vs), J) :- !, maplist(value_json, Vs, J).
value_json(ctx(Cs), J) :- !, foldl([N-V, D0, D]>>( value_json(V, JV), atom_string(N, NS), atom_string(K, NS), put_dict(K, D0, JV, D) ), Cs, _{}, J).

atomic_json(X, J) :- rational(X), \+ integer(X), !, J is float(X).
atomic_json(date(Y, M, D), _{'@type': date, value: S}) :- !, format(string(S), "~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, D]).
atomic_json(true, true) :- !.
atomic_json(false, false) :- !.
atomic_json(X, X).

answered(Rs, case(Id, Desc, Inputs, Decisions), case(Id, Desc, Inputs, Results)) :-
    format(string(SId), "~w", [Id]),
    (   member(R, Rs), get_dict(id, R, SId), get_dict(results, R, RD), get_dict(status, R, "ok")
    ->  dict_pairs(RD, _, Pairs),
        ( get_dict(decisionStatus, R, SD) -> true ; SD = _{} ),
        findall(result(N, decision, V),
                ( member(K-JV, Pairs), atom_string(K, NS), atom_string(N, NS),
                  ( Decisions == all -> true ; memberchk(N, Decisions) ),
                  %  a decision the oracle could not evaluate is no expectation
                  ( get_dict(K, SD, St) -> St == "SUCCEEDED" ; true ),
                  json_value(JV, V) ),
                Results)
    ;   Results = []
    ).

json_value(null, null) :- !.
json_value(@(null), null) :- !.
json_value(true, v(true)) :- !.
json_value(false, v(false)) :- !.
json_value(@(true), v(true)) :- !.
json_value(@(false), v(false)) :- !.
json_value(N, v(R)) :- number(N), !, ( integer(N) -> R = N ; R is rationalize(N) ).
json_value(S, v(S)) :- string(S), !.
json_value(L, list(Vs)) :- is_list(L), !, maplist(json_value, L, Vs).
json_value(D, V) :- is_dict(D),
    (   get_dict('@type', D, T), get_dict(value, D, S)
    ->  temporal_value(T, S, V)
    ;   dict_pairs(D, _, Ps), findall(N-CV, ( member(K-J, Ps), atom_string(K, NS), atom_string(N, NS), json_value(J, CV) ), Cs), V = ctx(Cs)
    ).

temporal_value("date", S, v(date(Y, M, D))) :- !,
    split_string(S, "-", "", [Ys, Ms, Ds]), number_string(Y, Ys), number_string(M, Ms), number_string(D, Ds).
temporal_value(T, S, v(V)) :- atom_string(TA, T), V =.. [TA, S].

		 /*******************************
		 *   CAMUNDA'S ENGINE (SECOND)  *
		 *******************************/

%!  camunda_file(+File) is semidet.
%
%   A model of Camunda Modeler in Camunda 7's dialect (DMN 1.1 with type
%   names unqualified, process variables as the tables' inputs), which
%   Drools does not run: its oracle is Camunda's own engine
%   (oracle-camunda/, described in README.md).
camunda_file(File) :-
    read_file_to_string(File, S, []),
    sub_string(S, _, _, _, "http://camunda.org/schema/1.0/dmn"),
    (   sub_string(S, _, _, _, "20151101")
    ;   sub_string(S, _, _, _, "exporter=\"Camunda Modeler\"")
    ), !.

%!  camunda_answers(+File, +Cases, -Answered) is det.
%
%   As oracle_answers/3, by Camunda 7's DMN engine. A decision's value is
%   read from its result list as DMN defines it: one output of a single
%   hit table, its value; a collecting table, the list of its values; a
%   table of several outputs, a structure (a list of them when it collects).
camunda_answers(_, [], []) :- !.
camunda_answers(File, Cases, Answered) :-
    runs_dir(Dir), make_directory_path(Dir),
    maplist(camunda_case_json, Cases, Js),
    with_output_to(string(CasesText), json_write_dict(current_output, Js, [width(0)])),
    read_file_to_string(File, MT, []),
    atomic_list_concat([camunda, CasesText, MT], Key0), sha_hash(Key0, H, []), hash_atom(H, Key),
    atomic_list_concat([Dir, '/', Key, '.camunda-cases.json'], CF),
    atomic_list_concat([Dir, '/', Key, '.camunda-results.json'], RF),
    (   exists_file(RF) -> true
    ;   setup_call_cleanup(open(CF, write, O, [encoding(utf8)]), write(O, CasesText), close(O)),
        camunda_jar(Jar),
        process_create(path(java), ['-Xmx1g', '-jar', Jar, '--model', File, '--cases', CF, '--out', RF],
                       [stdout(null), stderr(null), process(P)]),
        process_wait(P, _)
    ),
    (   exists_file(RF)
    ->  setup_call_cleanup(open(RF, read, In, [encoding(utf8)]), json_read_dict(In, Rs, [value_string_as(string)]), close(In)),
        dmn_reader:dmn_read_file(File, Model),
        maplist(camunda_answered(Model, Rs), Cases, Answered0),
        include([case(_, _, _, R)]>>(R \== []), Answered0, Answered)
    ;   Answered = []
    ).

camunda_case_json(case(Id, _, Inputs, _), _{id: SId, variables: Vars}) :-
    format(string(SId), "~w", [Id]),
    foldl([N-V, D0, D]>>( value_json(V, JV), atom_string(N, NS), atom_string(KA, NS), put_dict(KA, D0, JV, D) ),
          Inputs, _{}, Vars).

camunda_answered(model(_, Items), Rs, case(Id, Desc, Inputs, _), case(Id, Desc, Inputs, Results)) :-
    format(string(SId), "~w", [Id]),
    (   member(R, Rs), get_dict(id, R, SId), get_dict(error, R, null)
    ->  dict_pairs(R.decisions, _, Pairs),
        findall(result(Name, decision, V),
                ( member(_-D, Pairs), atom_string(Name, D.name),
                  member(decision(_, Name, _, _, Logic, _), Items),
                  camunda_value(Logic, D.resultList, V) ),
                Results)
    ;   Results = []
    ).

camunda_value(table(Hit, Agg, _, Outs, _), List, V) :- !,
    maplist({Outs}/[E, EV]>>( dict_pairs(E, _, Ps),
                       (   Outs = [_]
                       ->  Ps = [_-J|_], json_value(J, EV)
                       ;   findall(N-CV, ( member(K-J, Ps), atom_string(K, NS), atom_string(N, NS), json_value(J, CV) ), Cs),
                           EV = ctx(Cs)
                       ) ), List, Vs),
    (   memberchk(Hit, [collect, rule_order, output_order]), Agg == none -> V = list(Vs)
    ;   Vs = [V0|_] -> V = V0
    ;   V = null
    ).
camunda_value(_, [E|_], V) :- !, dict_pairs(E, _, [_-J|_]), json_value(J, V).
camunda_value(_, [], null).

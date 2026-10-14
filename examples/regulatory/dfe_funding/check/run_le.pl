/*  run_le.pl — ask every output query of every scenario of a cases file.

    swipl run_le.pl CASES.le      (from the LE2 repository root, or with
                                   LE2 on the library path)

    Prints one JSON line per scenario: {"case": Name, "out": {Query: Value}}.
    A query with no answer gives null; a yes/no query gives true or false;
    a query with more than one answer gives the list of its values, which
    the comparison reports as a fault in itself.
*/
:- use_module(library(http/json)).
:- initialization(main, main).

main :-
    current_prolog_flag(argv, [File|_]),
    absolute_file_name(File, Abs),
    le_kbs:load(Abs, KB, [skip_tests]),
    findall(S, KB:scenario(S, _), Scenarios0), sort(Scenarios0, Scenarios),
    findall(Q-G, KB:query_info(Q, G, _), Queries),
    forall(member(S, Scenarios), run_scenario(KB, S, Queries)).

run_scenario(KB, S, Queries) :-
    le_kbs:createSession(KB, SM),
    (   le_kbs:setScenarion(SM, S)
    ->  findall(Q-V, ( member(Q-G, Queries), statistics(cputime, T0), answer(Q, G, SM, V), statistics(cputime, T1), T is T1 - T0, ( T > 0.5 -> format(user_error, "~w ~w ~3f~n", [S, Q, T]) ; true ) ), Pairs),
        dict_pairs(Out, _, Pairs),
        atom_string(S, SN),
        json_write_dict(current_output, _{case: SN, out: Out}, [width(0)]), nl
    ;   format(user_error, "no scenario ~w~n", [S])
    ),
    le_kbs:destroySession(SM).

answer(Q, G0, SM, V) :-
    copy_term(G0, G),
    term_variables(G, Vars),
    catch(call_with_time_limit(60,
              findall(Vals, ( reasoner:without_explanations(reasoner:i(G, SM, _, _)), maplist(json_value, Vars, Vals) ), All0)),
          E, (print_message(error, E), All0 = [error])),
    sort(All0, All),
    (   All == [error] -> V = "ERROR"
    ;   yes_no(Q), All == [] -> V = false
    ;   yes_no(Q), All = [_] -> V = true
    ;   All == [] -> V = null
    ;   All = [Vals] -> last(Vals, V)
    ;   maplist(last, All, Vs), V = Vs
    ).

json_value(date(Y, M, D), S) :- !, format(string(S), "~d-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, D]).
json_value(X, X) :- number(X), !.
json_value(X, S) :- string(X), !, S = X.
json_value(X, S) :- atom(X), !, atom_string(X, S).
json_value(X, S) :- term_string(X, S).

%   The outputs that are yes/no (booleans on page 35).
yes_no('AcadProg').
yes_no('StartFund').
yes_no('TLevelStudent').
yes_no('TransitionStudent').
yes_no('Year3ofTlevelStudyProgramme').

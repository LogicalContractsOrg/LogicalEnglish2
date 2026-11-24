/*  Asking a twin a question in one of its scenarios, from Prolog: for
    finding out why a field differs from DRR's.

    swipl -g "consult('migration/rune/ask.pl')" -- File Scenario
    ?- ask('the CFTC cleared of').         % every template whose words start so
    ?- ask('the reporting side of', [instruction, X]).

    ask(+Words): the templates whose text starts with Words, and their
    answers with every place open; ask(+Words, +Args): with the places given.
*/
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- dynamic ask_session/2.

open_twin(File, Scenario) :-
    le_kbs:load(File, KB, [skip_tests]),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, Scenario),
    retractall(ask_session(_, _)), assertz(ask_session(KB, SM)).

template_goal(Prefix, Goal, Text) :-
    ask_session(KB, _),
    KB:le_dict(dict([F|Args], _, WV, _, _, _, _)),
    maplist(word_text, WV, Ws), atomic_list_concat(Ws, ' ', Text),
    sub_atom(Text, 0, _, _, Prefix),
    Goal =.. [F|Args].

word_text(W, T) :- ( var(W) -> T = '_' ; T = W ).

ask(Prefix) :- ask(Prefix, _).
ask(Prefix, Args) :-
    ask_session(_, SM),
    forall(( template_goal(Prefix, Goal, Text), Goal =.. [_|GA], ( var(Args) -> true ; GA = Args ) ),
           (
             format("~w~n", [Text]),
             catch(call_with_time_limit(30,
                 forall(limit(20, reasoner:i(Goal, SM, _, _)), ( format("  ~q~n", [GA]) ))),
                 E, format("  ~w~n", [E])) )).

:- initialization((current_prolog_flag(argv, [F, S|_]) -> open_twin(F, S) ; true)).

%   step(+Prefix, +Args): the clauses of the template, each condition of
%   each tried in turn with the arguments given, saying where it fails.
step(Prefix, Args) :-
    ask_session(KB, SM),
    forall(( template_goal(Prefix, Goal, Text), Goal =.. [_|GA], GA = Args ),
           ( format("~w~n", [Text]),
             forall(clause(KB:Goal, Body),
                    ( and_list(Body, Cs), format("  clause of ~w conditions~n", [Cs]) ->
                      true ; true )) )),
    forall(( template_goal(Prefix, Goal, _), Goal =.. [_|GA], GA = Args, clause(KB:Goal, Body) ),
           ( and_list(Body, Cs), length(Cs, N), format("clause (~w conditions)~n", [N]),
             ( walk(Cs, 1, SM) -> true ; true ) )).

walk([], _, _) :- format("  all hold~n").
walk([C|Cs], I, SM) :-
    (   catch(call_with_time_limit(30, once(reasoner:i(C, SM, _, _))), E, (format("  ~w: ~w~n", [I, E]), fail))
    ->  ( C = le_at(G, _, _) -> true ; G = C ), functor(G, F, _), format("  ~w holds: ~w~n", [I, F]),
        I1 is I + 1, walk(Cs, I1, SM)
    ;   ( C = le_at(G, _, _) -> true ; G = C ), format("  ~w fails: ~q~n", [I, G])
    ).

and_list(and(A, B), L) :- !, and_list(A, LA), and_list(B, LB), append(LA, LB, L).
and_list((A, B), L) :- !, and_list(A, LA), and_list(B, LB), append(LA, LB, L).
and_list(G, [G]).

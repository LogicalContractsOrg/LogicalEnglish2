/*  The measure of a twin (the design notes rune.md §5), quickly: each
    scenario's whole report in one query (the twin's memorable templates are
    then worked out once per instruction), compared with DRR's expected
    report field by field.

    ./myswipl.sh -q migration/rune/check.pl -- <scenario file> [<seconds per instruction>]

    Prints, per instruction and in total: the expected field values the
    twin gives (agree), those it does not give (missing), and the values it
    gives that DRR's report does not have (extra); writes the details to
    <scenario file>.check.txt.

    RUNE_STACK_LIMIT (bytes, e.g. 2000000000) bounds each instruction's
    Prolog stacks, so that one instruction that grows without end is
    counted as failed instead of exhausting the machine's memory.
*/
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- use_module(library(main)).

:- initialization(main, main).

main([File|Rest]) :-
    ( Rest = [L|_] -> atom_number(L, Limit) ; Limit = 300 ),
    ( getenv('RUNE_STACK_LIMIT', SL), atom_number(SL, Bytes) -> set_prolog_flag(stack_limit, Bytes) ; true ),
    le_kbs:load(File, KB, [skip_tests]),
    set_prolog_flag(le_failure_explanations, false),    % answers only
    findall(S, KB:le_expected(_, S, _, _), Ss0), sort(Ss0, Ss),
    atom_concat(File, '.check.txt', Out),
    setup_call_cleanup(open(Out, write, O),
        foldl(check_scenario(KB, Limit, O), Ss, t(0, 0, 0, 0), t(A, M, X, T)),
        close(O)),
    format("~w instructions: ~w expected field values agree, ~w missing, ~w extra (~w timed out or failed)~n",
           [File, A, M, X, T]).

check_scenario(KB, Limit, O, S, t(A0, M0, X0, T0), t(A, M, X, T)) :-
    findall(E, ( KB:le_expected(_, S, Es, _), member(E0, Es), normalize_string(E0, E) ), Exp0),
    sort(Exp0, Exp),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, S),
    %  the fields' expectations by the whole report, once; any other
    %  expectation (eligible) by its own query
    findall(Q, ( KB:le_expected(Q, S, _, _), \+ sub_atom(Q, 0, _, _, field_) ), Qs0), sort(Qs0, Qs),
    get_time(T1),
    catch(call_with_time_limit(Limit,
            findall(Str, ( member(Q, [report|Qs]), KB:query_info(Q, Goal, Items),
                           reasoner:i(Goal, SM, _, _),
                           maplist(le_kbs:item_to_instance(KB), Items, Is), flatten(Is, Inst),
                           le_kbs:canonical_string(Inst, At), atom_string(At, Str0),
                           normalize_string(Str0, Str) ), Got0)),
          E, ( E == time_limit_exceeded -> Got0 = timeout ; Got0 = error(E) )),
    get_time(T2), D is T2 - T1,
    le_kbs:destroySession(SM),
    (   ( Got0 == timeout ; Got0 = error(_) )
    ->  length(Exp, NM), A = A0, M is M0 + NM, X = X0, T is T0 + 1,
        ( Got0 = error(Err) -> true ; Err = timeout ),
        format(O, "~w: ~q after ~2fs~n", [S, Err, D])
    ;   sort(Got0, Got),
        ord_intersection(Exp, Got, Ag), ord_subtract(Exp, Got, Mi), ord_subtract(Got, Exp, Ex),
        length(Ag, NA), length(Mi, NM), length(Ex, NX),
        A is A0 + NA, M is M0 + NM, X is X0 + NX, T = T0,
        format(O, "~w: ~w agree, ~w missing, ~w extra (~2fs)~n", [S, NA, NM, NX, D]),
        forall(member(Y, Mi), format(O, "  missing: ~w~n", [Y])),
        forall(member(Y, Ex), format(O, "  extra:   ~w~n", [Y]))
    ),
    format(user_error, "~w ~w/~w (~2fs)~n", [S, A, M, D]).

normalize_string(S0, S) :- le_kbs:normalize_string(S0, S).

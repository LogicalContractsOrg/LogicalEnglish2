/*  The reader's gate (the design notes rune.md §4.1): every expression of the
    corpus parsed, and printed back, gives the tokens of its source.

    ./myswipl.sh -q migration/rune/gate.pl            # DRR 7.14.0
    ./myswipl.sh -q migration/rune/gate.pl -- <json dir>

    Writes runs/gate.txt: the counts, then every expression that fails.
*/
:- use_module(parser/rune_reader).
:- use_module(parser/rune_expr).
:- use_module(library(main)).

:- initialization(main, main).

main(Argv) :-
    source_file(main(_), F), file_directory_name(F, Here),
    ( Argv = [Dir|_] -> true ; directory_file_path(Here, '.cache/json', Dir) ),
    load_rune_model(Dir),
    findall(W-ok, gate_one(W, ok), Ok), length(Ok, NOk),
    findall(W-R, ( gate_one(W, R), R \== ok ), Bad), length(Bad, NBad),
    N is NOk + NBad,
    directory_file_path(Here, runs, RunDir), make_directory_path(RunDir),
    directory_file_path(RunDir, 'gate.txt', Out),
    setup_call_cleanup(open(Out, write, S),
        ( format(S, "Rune gate: ~w expressions, ~w print back to their own tokens, ~w do not~n",
                 [N, NOk, NBad]),
          forall(member(W-R, Bad), report(S, W, R)) ),
        close(S)),
    format("Rune gate: ~w expressions, ~w print back to their own tokens, ~w do not (~w)~n",
           [N, NOk, NBad, Out]),
    ( NBad =:= 0 -> halt(0) ; halt(1) ).

gate_one(W, R) :-
    rune_expression(W, Text, AST),
    (   AST = error(E) -> R = unparsed(E)
    ;   rune_tokens(Text, T1), rune_print_tokens(AST, T2),
        ( T1 == T2 -> R = ok ; R = differs(T2) )
    ).

report(S, W, R) :-
    rune_expression(W, Text, _),
    format(S, "~n~q: ~w~n~s~n", [W, R, Text]).

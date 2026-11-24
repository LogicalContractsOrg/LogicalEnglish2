/*  Run the Miniscript twins' spending attempts on a real chain.

    From /work (the LE2 checkout):

        ./myswipl.sh -q migration/miniscript/chain.pl                  # every twin, on Tape
        ./myswipl.sh -q migration/miniscript/chain.pl -- cosigning_service
        NETWORK=regtest ./myswipl.sh -q migration/miniscript/chain.pl -- cosigning_service

    Each run is recorded in chain/runs/<id>.<network>.json; build.pl then
    writes the Tape run into the twin as its chain scenarios (what the
    chain's node accepted and what it refused).
    Needs node and `npm install` in chain/ (and, for regtest, bitcoind:
    fetch_bitcoind.sh).
*/

:- initialization(main, main).

:- use_module(library(main)).
:- use_module(ms_twin).
:- use_module(ms_chain).
:- use_module(policies).
:- use_module(library(option)).

main(Argv) :-
    (   getenv('NETWORK', N0) -> atom_string(Net, N0) ; Net = tape ),
    (   Argv == [] -> findall(Id, twin(Id, _), Ids) ; maplist([A, I]>>atom_string(I, A), Argv, Ids) ),
    forall(member(Id, Ids),
           ( twin(Id, Opts),
             format("~w on ~w ... ", [Id, Net]), flush_output,
             catch(( twin_policy(twin(Id, Opts), Policy, Names, Sets),
                     option(policy(Text), Opts), miniscript:ms_parse(Text, Tree),
                     chain_run(Id, src(Tree, Policy), Names-Sets, Net),
                     chain_record(Id, Net, Rec),
                     findall(V, ( member(A, Rec.attempts), atom_string(V, A.verdict) ), Vs),
                     msort(Vs, SVs), clumped_pairs(SVs, Counts),
                     format("~w~n", [Counts]) ),
                   E, ( message_to_codes(E, M), format("failed: ~s~n", [M]) )) )).

clumped_pairs(L, P) :- clumped(L, P).

message_to_codes(E, C) :- message_to_codes(E, [], C0), !, C = C0.
message_to_codes(E, _, C) :- format(codes(C), "~q", [E]).

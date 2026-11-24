/** <module> Validation by replay (§6.1): the twin against the chain

    Takes what replay_fetch.js read from a public Ethereum node — a window of
    a token's Transfer, Mint and Burn logs, the balances of the accounts they
    touch and the total supply before and after the window, the minters and
    their allowances — and:

      1. binds the FiatToken twin (the E11 reference model of USDC) to the
         state before the window: `initially` facts for every touched
         account's balance, the total supply, the minters;
      2. renders each log, in chain order, as an observed call at its own
         cycle: a Transfer between accounts as `transfer`, one from the zero
         address as `mint` by the minter its Mint log names, one to the zero
         address as `burn` by the account burning;
      3. runs the twin with LPS2 and compares the state it reaches with the
         balances and the total supply the chain reports after the window.

    A divergence names the account and the amount, and so localises a
    translation error to a function and a transaction; there is no LLM in
    this loop.

        ./myswipl.sh -q -g "consult('migration/solidity/sol_replay.pl')" \
            -g "sol_replay:replay('<window>.json')" -t halt

    Approximated (and reported as such): a Transfer made by `transferFrom`
    is replayed as a `transfer` by the owner of the funds — the same effect
    on balances; the allowance it spends is not in the logs.
*/

:- module(sol_replay, [replay/1, replay/2, replay_ir/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(sol_migrate).
:- use_module(sol_front).
:- use_module(le2(le_writer)).

%!  replay(+WindowJSON) is det.
%!  replay(+WindowJSON, -Report) is det.
%
%   Writes <window>.le beside the JSON (the bound twin with the observed
%   calls), runs it, writes <window>.results.md and .results.json.
replay(File) :- replay(File, _).

replay(File, Report) :-
    read_window(File, W),
    replay_ir(W, IR, Meta),
    le_write(IR, Text, Issues),
    forall(member(issue(error, C, M), Issues), print_message(error, format("~w: ~w", [C, M]))),
    file_name_extension(Base, _, File),
    atomic_list_concat([Base, '.le'], LEFile),
    write_file(LEFile, Text),
    statistics(walltime, [T0, _]),
    run_state(LEFile, Fluents),
    statistics(walltime, [T1, _]),
    Secs is (T1 - T0) / 1000,
    compare_state(W, Fluents, Rows),
    include([row(_, _, _, ok)]>>true, Rows, Agree),
    length(Rows, NR), length(Agree, NA),
    Report = report(NA, NR, Rows, Meta.put(seconds, Secs)),
    results_markdown(W, Report, MD),
    atomic_list_concat([Base, '.results.md'], MDFile),
    write_file(MDFile, MD),
    format("replay ~w: ~w of ~w values agree with the chain (~w s)~n", [File, NA, NR, Secs]).

read_window(File, W) :-
    setup_call_cleanup(open(File, read, In, [encoding(utf8)]),
                       json_read_dict(In, W, [value_string_as(atom)]),
                       close(In)).

%   The twin, bound to the state before the window, with the calls observed.
replay_ir(W, program(H, Items), _{events: NE, transfers: NT, mints: NM, burns: NB}) :-
    sol_migrate:twin(fiat_token, Src, Contract, Opts0),
    sol_migrate:here(Here), atomic_list_concat([Here, '/', Src], SrcFile),
    initial_facts(W, Init),
    format(string(Cm),
"Replay of ~w (USDC) on Ethereum mainnet, blocks ~w to ~w, against the FiatToken twin (E11).
Instance binding: the proxy's implementation at block ~w is ~w,
a full Sourcify match of FiatTokenV2_2 (solc 0.6.12); the twin is contracts/FiatTokenSubset.sol,
the FiatTokenV1 logic that V2_2 keeps for transfer, mint and burn.
The initial state is the chain's at block ~w; each log of the window is one observed call.
Data: replay_fetch.js over ~w, fetched ~w.

How the files relate. This program IS the FiatToken twin (../fiat_token/fiat_token.le): the same declarations,
laws and constraints, written by the same translator from the same contract (test_solidity.pl checks they are
the twin's, term by term), bound to the chain's state instead of the twin's own initial state, with the window's
logs as its scenario. The .json of the same name is the chain data it was built from (replay_fetch.js); the
.results.md of the same name compares its final state, as LPS2 computes it, with the chain's (sol_replay.pl).
It does not extend the twin (`extends` would take its laws and leave its initial state and scenario out): a
replay must also run when opened as bare text, where no base resolves, and its negative control swaps in a
deliberately wrong translation.",
           [W.token, W.window.first, W.window.last, W.window.last, W.implementation,
            W.window.before, W.rpc, W.fetched]),
    exclude(ignored_option, Opts0, Opts1),
    sol_translate([SrcFile], Contract, [comment(Cm), kb('usdc replay'), initially(Init)|Opts1],
                  program(H0, Items0), _),
    findall(Obs, ( nth1(I, W.events, E), event_obs(E, I, Obs) ), Observations),
    observation_lines(program(H0, Items0), Observations, Lines),
    length(Observations, NE), MT is NE + 2,
    select(setting(max_time, _), H0, H1), H = [setting(max_time, MT)|H1],
    append(Items0, [scenario(window, Lines, [])], Items),
    count_kind(W.events, transfer, NT), count_kind(W.events, mint, NM), count_kind(W.events, burn, NB).

ignored_option(constructor_args(_)).
ignored_option(scenario(_)).
ignored_option(related(_)).
ignored_option(kb(_)).
ignored_option(expected(_)).

count_kind(Es, K, N) :- aggregate_all(count, ( member(E, Es), get_dict(kind, E, K) ), N).

initial_facts(W, Facts) :-
    dict_pairs(W.pre.balances, _, Bs),
    findall(balance(A, V), ( member(A0-V0, Bs), atom_number(V0, V), V > 0, addr(A0, A) ), BFs),
    atom_number(W.pre.totalSupply, TS),
    dict_pairs(W.pre.minters, _, Ms),
    findall(F, ( member(M0-Info, Ms), get_dict(isMinter, Info, true), addr(M0, M),
                 get_dict(allowance, Info, Al0), atom_number(Al0, Al),
                 member(F, [minter(M), minting_allowance(M, Al)]) ), MFs),
    append([[total_supply(TS)], BFs, MFs], Facts).

%   An address as an LE constant: a string, so the tokenizer does not read
%   0x... as a number.
addr(A0, A) :- atom_string(A0, A).

event_obs(E, I, obs(Act, I, I1)) :-
    I1 is I + 1,
    atom_number(E.value, V),
    addr(E.from, From), addr(E.to, To),
    (   E.kind == transfer -> Act = transfer(From, V, To)
    ;   E.kind == mint -> addr(E.minter, M), Act = mint(M, V, To)
    ;   E.kind == burn -> Act = burn(From, V)
    ).

		 /*******************************
		 *      THE COMPARISON          *
		 *******************************/

%   row(Account | total_supply, Chain, Twin, ok | differs)
compare_state(W, Fluents, [TSRow|Rows]) :-
    atom_number(W.post.totalSupply, TS),
    ( memberchk(total_supply(TT), Fluents) -> true ; TT = 0 ),
    ( TT =:= TS -> R0 = ok ; R0 = differs ),
    TSRow = row('total supply', TS, TT, R0),
    dict_pairs(W.post.balances, _, Bs),
    findall(row(A, V, TV, R),
            ( member(A0-V0, Bs), atom_number(V0, V), addr(A0, A),
              ( memberchk(balance(A, TV), Fluents) -> true ; TV = 0 ),
              ( TV =:= V -> R = ok ; R = differs ) ),
            Rows).

results_markdown(W, report(NA, NR, Rows, Meta), MD) :-
    include([row(_, _, _, differs)]>>true, Rows, Diffs),
    with_output_to(string(MD), (
        format("# Replay: ~w against its LE twin~n~n", [W.token]),
        format("Ethereum mainnet blocks ~w–~w (state before: block ~w), fetched ~w from ~w.~n~n",
               [W.window.first, W.window.last, W.window.before, W.fetched, W.rpc]),
        format("Implementation behind the proxy: ~w (Sourcify full match: FiatTokenV2_2).~n~n", [W.implementation]),
        format("| | |~n|---|---|~n| logs replayed | ~w (~w transfers, ~w mints, ~w burns) |~n",
               [Meta.events, Meta.transfers, Meta.mints, Meta.burns]),
        format("| values compared | ~w (the total supply and the balance of every account the logs touch) |~n", [NR]),
        format("| **agree with the chain** | **~w of ~w** |~n| LPS2 run | ~2f s |~n~n", [NA, NR, Meta.seconds]),
        (   Diffs == []
        ->  format("Every balance and the total supply the twin reaches are the chain's.~n~n")
        ;   format("## Divergences~n~n| Account | Chain | Twin |~n|---|---|---|~n"),
            forall(member(row(A, V, T, _), Diffs), format("| ~w | ~w | ~w |~n", [A, V, T])),
            nl
        ),
        format("Approximated: a Transfer made by `transferFrom` is replayed as a `transfer` by the owner of the funds (the same balances; the allowance spent is not in the logs). Approval logs are not replayed.~n")
    )).

write_file(File, Text) :-
    setup_call_cleanup(open(File, write, Out, [encoding(utf8)]), write(Out, Text), close(Out)).

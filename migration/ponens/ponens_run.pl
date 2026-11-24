/** <module> Run a twin's scenarios on LPS2, in one process

    The gate (ponens_gate.py) asks for the breaches each scenario of a twin
    records. `lps run TWIN --scenario NAME` would load LE2 and LPS2 again for
    every scenario; this loads them once and runs every scenario in turn:

        LPS_LE2_LIB=/work swipl -g "consult('migration/ponens/ponens_run'), \
            run_scenarios('twin.le', 'names.json', 'out.json'), halt."

    out.json: {"<scenario>": {"at": [[policy, step], …], "whole": [policy, …],
    "outcome": "success"}, …}.
*/

:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(time)).

%   Seconds a scenario may take (PONENS_RUN_SECONDS, default 300).
scenario_seconds(S) :-
    ( getenv('PONENS_RUN_SECONDS', A), atom_number(A, S) -> true ; S = 300 ).

:- use_module('../le2_paths', []).
:- ( getenv('LPS2_DIR', D) -> true ; le2_paths:lps2_dir(D) ),
   atomic_list_concat([D, '/src/lps'], Lps), use_module(Lps),
   atomic_list_concat([D, '/src/edges/lps_cli'], Cli), use_module(Cli),
   atomic_list_concat([D, '/src/edges/lps_le'], Le), use_module(Le),
   atomic_list_concat([D, '/src/core/lps_session'], Ses), use_module(Ses).

run_scenarios(Twin, NamesJson, OutJson) :-
    setup_call_cleanup(open(NamesJson, read, In), json_read_dict(In, Names0), close(In)),
    maplist([N0, N]>>atom_string(N, N0), Names0, Names),
    foldl(run_one(Twin), Names, _{}, Results),
    setup_call_cleanup(open(OutJson, write, Out, [encoding(utf8)]),
                       json_write_dict(Out, Results, [width(0)]),
                       close(Out)).

run_one(Twin, Name, R0, R) :-
    scenario_seconds(Max),
    get_time(T0),
    (   catch(call_with_time_limit(Max,
              ( lps_le_with_scenario(Name, lps_cli:compile_source(le, Twin, [], P, _Diags)),
                lps_session_new(P, [dc], S0),
                lps_session_run(S0, end, S, _Trace),
                lps_session_state(S, Fluents),
                lps_session_status(S, Status) )), E, ( Error = E, fail ))
    ->  findall([Pol, Step], member(broken_at(Pol, Step), Fluents), At),
        findall(Pol, member(broken(Pol), Fluents), Whole),
        term_string(Status, St),
        R = R0.put(Name, _{at: At, whole: Whole, outcome: St})
    ;   Error == time_limit_exceeded
    ->  format(string(M), "the scenario did not finish in ~w seconds", [Max]),
        R = R0.put(Name, _{error: M})
    ;   ( nonvar(Error) -> print_message(warning, Error) ; true ),
        R = R0.put(Name, _{error: "the scenario did not run"})
    ),
    get_time(T1), Sec is round(T1 - T0),
    format(user_error, "~w: ~w s~n", [Name, Sec]).

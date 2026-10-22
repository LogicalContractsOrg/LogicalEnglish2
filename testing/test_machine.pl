% A server of several machines (le_machine.pl): the ids of sessions and jobs
% name the machine that made them, and a request that names another
% machine's id is sent back to it, once, when its body can be sent again.
% The machine is set with LE_MACHINE_ID, as fly.io sets FLY_MACHINE_ID.

:- use_module(library(plunit)).
:- use_module('../le_machine').
:- use_module('../le_kbs').

%   Run Goal as machine M (none: off fly.io), restoring the environment.
as_machine(M, Goal) :-
    ( getenv('LE_MACHINE_ID', Old) -> true ; Old = none ),
    ( getenv('FLY_MACHINE_ID', OldFly) -> true ; OldFly = none ),
    unsetenv('FLY_MACHINE_ID'),
    setup_call_cleanup(
        ( M == none -> unsetenv('LE_MACHINE_ID') ; setenv('LE_MACHINE_ID', M) ),
        Goal,
        ( ( Old == none -> unsetenv('LE_MACHINE_ID') ; setenv('LE_MACHINE_ID', Old) ),
          ( OldFly == none -> true ; setenv('FLY_MACHINE_ID', OldFly) ) )).

:- begin_tests(machine).

test(no_machine_keeps_ids) :-
    as_machine(none, ( machine_tagged_id(s123, A), machine_tagged_id("job_4", S) )),
    A == s123, S == "job_4".

test(ids_name_their_machine) :-
    as_machine('148e21ea7d4e89', ( machine_tagged_id(s123, A), machine_tagged_id("job_4", S) )),
    A == 's123__m148e21ea7d4e89',
    S == "job_4__m148e21ea7d4e89",
    id_machine(A, M1), M1 == '148e21ea7d4e89',
    id_machine(S, M2), M2 == '148e21ea7d4e89'.

test(plain_ids_name_no_machine, [fail]) :-
    ( id_machine('s1f2e3d4-0000-11f1-a1b2-dead6d680f27', _)
    ; id_machine("caj_abc", _)
    ; id_machine('s1__m', _)
    ).

test(a_session_names_its_machine) :-
    as_machine(m1, le_kbs:createSession(none, SM)),
    id_machine(SM, M), M == m1,
    le_kbs:clearSession(SM).

test(another_machines_session_goes_back) :-
    as_machine(m2, replay_machine([content_length(200)], _{sessionModule: "sabc__mm1"}, M)),
    M == m1.

test(own_session_stays) :-
    \+ as_machine(m1, replay_machine([], _{sessionModule: "sabc__mm1"}, _)).

test(jobs_go_back_too) :-
    as_machine(m2, replay_machine([], _{operation: "assistant_status", job_id: "job_3__mm1"}, M1)),
    as_machine(m2, replay_machine([], _{operation: "contract_status", job: "caj_x__mm3"}, M2)),
    M1 == m1, M2 == m3.

test(sent_back_once_only) :-
    \+ as_machine(m2, replay_machine([fly_replay_src('instance=m1;region=lhr')],
                                     _{sessionModule: "sabc__mm1"}, _)).

test(too_large_to_send_again) :-
    \+ as_machine(m2, replay_machine([content_length(2000000)], _{sessionModule: "sabc__mm1"}, _)).

test(off_fly_nothing_goes_back) :-
    \+ as_machine(none, replay_machine([], _{sessionModule: "sabc__mm1"}, _)).

test(replay_turned_off) :-
    setenv('LE_MACHINE_REPLAY', off),
    call_cleanup(\+ as_machine(m2, replay_machine([], _{sessionModule: "sabc__mm1"}, _)),
                 unsetenv('LE_MACHINE_REPLAY')).

:- end_tests(machine).

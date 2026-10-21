% The limits of the public tools (le_throttle.pl): the budget of a client
% without a key, of a session behind a shared address, of an event key; the
% size of a call; who a request is from; the time limit. The time is given
% to admit_at/5, so nothing waits.

:- use_module(library(plunit)).
:- use_module('../le_throttle').

anon(Address, Session, _{level: anonymous, id: Address, address: Address, session: Session}).

%   Call admit_at N times at time T; the verdicts.
admits(Id, N, T, Verdicts) :-
    findall(V, ( between(1, N, _), admit_at(Id, 1, [], T, V) ), Verdicts).

allowed(Vs, N) :- include(==(allow), Vs, As), length(As, N).

:- begin_tests(throttle, [setup(throttle_reset), cleanup(throttle_reset)]).

test(anonymous_burst_then_wait) :-
    throttle_reset,
    anon('203.0.113.5', none, Id),
    admits(Id, 11, 1000, Vs),
    allowed(Vs, 10),
    last(Vs, refuse(429, Wait, Message)),
    Wait >= 1,
    once(sub_string(Message, _, _, _, "10 calls a minute")).

test(anonymous_refills) :-
    throttle_reset,
    anon('203.0.113.6', none, Id),
    admits(Id, 10, 1000, _),
    admit_at(Id, 1, [], 1000, refuse(_, _, _)),
    admit_at(Id, 1, [], 1006.5, allow).        % 10 a minute: one every 6 seconds

test(sessions_share_a_larger_address_budget) :-
    throttle_reset,
    anon('203.0.113.7', s1, A), anon('203.0.113.7', s2, B),
    admits(A, 11, 1000, VA), allowed(VA, 10),
    admits(B, 10, 1000, VB), allowed(VB, 10).

test(address_cap_for_many_sessions) :-
    throttle_reset,
    findall(V, ( between(1, 12, S), anon('203.0.113.8', S, Id),
                 between(1, 10, _), admit_at(Id, 1, [], 1000, V) ), Vs),
    allowed(Vs, 100).                           % ten times one client's burst

test(daily_limit) :-
    throttle_reset,
    anon('203.0.113.9', none, Id),
    findall(V, ( between(0, 200, K), T is 1000 + K * 10, admit_at(Id, 1, [], T, V) ), Vs),
    allowed(Vs, 200),
    last(Vs, refuse(429, 0, M)),
    once(sub_string(M, _, _, _, "200")).

test(text_too_long) :-
    throttle_reset,
    anon('203.0.113.10', none, Id),
    admit_at(Id, 1, [100, 30000], 1000, refuse(413, 0, M)),
    once(sub_string(M, _, _, _, "30000")).

test(event_budget_and_days) :-
    throttle_reset,
    get_time(Now), format_time(string(Today), '%F', Now),
    Ev = _{level: event, id: 'event:class', event: "class", budget: 5,
           from: Today, until: Today, address: '198.51.100.1', session: none},
    findall(V, ( between(1, 6, _), admit_at(Ev, 1, [], Now, V) ), Vs),
    allowed(Vs, 5),
    last(Vs, refuse(429, 0, M)),
    once(sub_string(M, _, _, _, "class")),
    Old = Ev.put(_{event: "old", from: "2020-01-01", until: "2020-01-02"}),
    admit_at(Old, 1, [], Now, refuse(429, 0, M2)),
    once(sub_string(M2, _, _, _, "2020-01-02")).

test(local_is_not_limited) :-
    throttle_reset,
    Id = _{level: local, id: local, address: '127.0.0.1', session: none},
    admits(Id, 500, 1000, Vs), allowed(Vs, 500).

test(identity_local_and_proxied) :-
    throttle_identity([peer(ip(127,0,0,1))], L), L.level == local,
    throttle_identity([peer(ip(10,0,0,2)), fly_client_ip('203.0.113.11')], A),
    A.level == anonymous, A.id == '203.0.113.11',
    throttle_identity([peer(ip(127,0,0,1)), x_forwarded_for('198.51.100.7, 10.0.0.1'),
                       mcp_session_id(abc)], B),
    B.level == anonymous, B.address == '198.51.100.7', B.session == abc.

test(identity_event_key_from_environment, [cleanup(unsetenv('LE_MCP_EVENT_KEYS'))]) :-
    setenv('LE_MCP_EVENT_KEYS', 'ulster-2026:5000:2026-10-22:2026-10-22'),
    throttle_identity([fly_client_ip('203.0.113.12'), authorization('Bearer ulster-2026')], E),
    E.level == event, E.budget == 5000, E.event == "ulster-2026",
    throttle_identity([fly_client_ip('203.0.113.12'), search([key='ulster-2026'])], E2),
    E2.level == event.

test(time_limit, [cleanup(unsetenv('LE_MCP_TIME_LIMIT'))]) :-
    setenv('LE_MCP_TIME_LIMIT', 1),
    anon('203.0.113.13', none, Id),
    throttle_run(Id, sleep(3), timeout(M)),
    once(sub_string(M, _, _, _, "1 seconds")).

test(run_done_and_failed) :-
    anon('203.0.113.14', none, Id),
    throttle_run(Id, true, done),
    throttle_run(Id, fail, failed).

test(key_in_address_when_header_holds_another_token, [cleanup(unsetenv('LE_MCP_EVENT_KEYS'))]) :-
    setenv('LE_MCP_EVENT_KEYS', 'ws:100:2026-01-01:2099-12-31'),
    throttle_identity([fly_client_ip('203.0.113.15'), authorization('Bearer deployment-token'),
                       search([key=ws])], E),
    E.level == event.

:- end_tests(throttle).

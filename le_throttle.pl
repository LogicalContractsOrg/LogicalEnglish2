/** <module> How much one client may ask of a public server's tools

    The tools of `/mcp` (and, in LE2, the four plain web addresses beside it)
    answer anyone, without signing in. This module keeps one client from
    taking the server for itself (docs/project/plans/MCPThrottling.md):

      - **who asks** (throttle_identity/2): a key, a sign-in, or the address
        the request came from; each has a *level* with its own budget;
      - **a budget** for each client (throttle_admit/4): a token bucket (a
        counter that refills at a fixed rate up to a maximum; each call spends
        from it), a total for the day, and for an event key a total for the
        event; and a limit on the size of the texts a call sends;
      - **the calls running at once, and their time** (throttle_run/3): at
        most a few tool calls run together, so that the editor keeps its
        workers, and each has a time limit.

    It knows nothing of Logical English or LPS, so that both servers load the
    same file: LE2 from here, LPS2 from its copy in vendor/le2.

    Who a key belongs to is the private lpsPlus repository's business
    (`accounts/lc_accounts.pl`): it answers the multifile hook
    client_identity/2. Without it, a key is one of the event keys of the
    environment variable `LE_MCP_EVENT_KEYS`, and every other client is
    known by its address.

    A request from this machine (the LE Assistant's own calls, a developer's
    server) is not limited, unless `LE_MCP_THROTTLE_LOCAL=true`; and
    `LE_MCP_THROTTLE=off` turns every limit off.

    The settings, all optional (environment variables):

      LE_MCP_RATE, LE_MCP_BURST, LE_MCP_DAILY
                         calls a minute, the largest burst, and calls a day,
                         for a client without a key (10, 10, 200)
      LE_MCP_CONCURRENT  tool calls that may run at once (4)
      LE_MCP_TIME_LIMIT  seconds a tool call may run (60)
      LE_MCP_EVENT_KEYS  event keys: `name:budget:from:until`, separated by
                         commas, dates as 2026-10-22
      LE_MCP_STATE_DIR   a directory where the totals of the event keys are
                         kept across restarts (a fly.io volume)
      LE_MCP_CONTACT     an address a refused client may write to for a key
*/

:- module(le_throttle, [
    throttle_identity/2,        % +Request, -Identity
    throttle_admit/4,           % +Identity, +Cost, +TextLengths, -Verdict
    throttle_check/3,           % +Identity, +Need, -Verdict
    throttle_charge/2,          % +Identity, +Cost
    throttle_client_run/3,      % +Identity, :Goal, -Outcome
    check_at/4,                 % +Identity, +Need, +Now, -Verdict
    charge_at/3,                % +Identity, +Cost, +Now
    throttle_run/3,             % +Identity, :Goal, -Outcome
    throttle_new_session/1,     % -SessionId
    request_key/2,              % +Request, -Key                    nondet
    client_address/2,           % +Request, -Address
    level_limits/2,             % +Level, -Limits
    admit_at/5,                 % +Identity, +Cost, +TextLengths, +Now, -Verdict
    throttle_reset/0
    ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(time)).
:- use_module(library(readutil)).
:- use_module(library(crypto)).
:- use_module(le_i18n).

:- meta_predicate throttle_run(+, 0, -), throttle_client_run(+, 0, -).

%!  client_identity(+Request, -Identity) is semidet.
%
%   Who sent Request, when a key, a token or a sign-in says so: answered by
%   lpsPlus's accounts (lc_accounts.pl). Identity is a dict with at least
%   `level` (person, event, licence or program) and `id` (an atom, the
%   client's name for its budget, never the key itself); an event also has
%   `event`, `budget`, `from` and `until`; and `email` and `caps` (the
%   capabilities of its licences) when the client is a person.
:- multifile client_identity/2.
:- dynamic client_identity/2.

:- dynamic bucket/3.            % Key, Tokens, LastTime
:- dynamic day_count/3.         % Key, Day, Calls
:- dynamic event_used/2.        % Event, Calls
:- dynamic events_loaded/0.
:- dynamic events_saved_at/1.   % Time
:- dynamic cleaned_at/1.        % Time
:- dynamic slot_queue/1.        % Queue
:- dynamic client_running/2.    % Key, Count

%!  throttle_reset is det.
%
%   Forget every count (the tests).
throttle_reset :-
    with_mutex(le_throttle,
               ( retractall(bucket(_, _, _)), retractall(day_count(_, _, _)),
                 retractall(event_used(_, _)), retractall(events_loaded),
                 retractall(events_saved_at(_)), retractall(cleaned_at(_)) )).

		 /*******************************
		 *          WHO ASKS            *
		 *******************************/

%!  throttle_identity(+Request, -Identity) is det.
%
%   Identity is a dict: `level` (local, anonymous, person, event, licence,
%   program), `id`, `address`, `session` (the MCP session, or `none`), and
%   what the level adds (see client_identity/2).
throttle_identity(Request, Identity) :-
    client_address(Request, Address),
    ( memberchk(mcp_session_id(S0), Request) -> atom_string(Session, S0) ; Session = none ),
    (   throttle_off
    ->  Identity0 = _{level: local, id: local}
    ;   catch(client_identity(Request, Identity1), E,
              ( print_message(warning, E), fail ))
    ->  Identity0 = Identity1
    ;   request_key(Request, Key), env_event_key(Key, Event)
    ->  Identity0 = Event
    ;   local_address(Request, Address), \+ env_true('LE_MCP_THROTTLE_LOCAL')
    ->  Identity0 = _{level: local, id: local}
    ;   Identity0 = _{level: anonymous, id: Address}
    ),
    Identity = Identity0.put(_{address: Address, session: Session}).

throttle_off :- getenv('LE_MCP_THROTTLE', V), downcase_atom(V, off).

%!  request_key(+Request, -Key:string) is nondet.
%
%   A key the request carries: `Authorization: Bearer KEY`, then `?key=KEY`
%   in the address (for a client that cannot set a header, or a server whose
%   own token, LPS2's LPS_TOKEN, takes the header).
request_key(Request, Key) :-
    (   memberchk(authorization(Auth), Request),
        text_to_string(Auth, S),
        string_concat("Bearer ", K0, S),
        split_string(K0, "", " ", [Key])
    ;   memberchk(search(Search), Request),
        memberchk(key=K0, Search),
        atom_string(K0, Key)
    ),
    Key \== "".

%!  client_address(+Request, -Address:atom) is det.
%
%   The address of the client. Behind fly.io's proxy the connection comes
%   from the proxy, and fly.io names the client in `Fly-Client-IP`; other
%   proxies use the first address of `X-Forwarded-For`.
client_address(Request, Address) :-
    (   memberchk(fly_client_ip(A0), Request)
    ->  atom_string(Address, A0)
    ;   memberchk(x_forwarded_for(F), Request),
        split_string(F, ",", " ", [First|_]), First \== ""
    ->  atom_string(Address, First)
    ;   memberchk(peer(Peer), Request)
    ->  peer_atom(Peer, Address)
    ;   Address = unknown
    ).

peer_atom(ip(A, B, C, D), Address) :- !, format(atom(Address), '~w.~w.~w.~w', [A, B, C, D]).
peer_atom(ip(A, B, C, D, E, F, G, H), Address) :- !,
    format(atom(Address), '~16r:~16r:~16r:~16r:~16r:~16r:~16r:~16r', [A, B, C, D, E, F, G, H]).
peer_atom(Peer, Address) :- term_to_atom(Peer, Address).

%   A request from this machine, not relayed by a proxy.
local_address(Request, Address) :-
    \+ memberchk(fly_client_ip(_), Request),
    \+ memberchk(x_forwarded_for(_), Request),
    memberchk(Address, ['127.0.0.1', '0:0:0:0:0:0:0:1', '::1']).

%   An event key of LE_MCP_EVENT_KEYS: `name:budget:from:until`. The key a
%   client sends is the name itself (it is written on a slide).
env_event_key(Key, _{level: event, id: Id, event: Name, budget: Budget, from: From, until: Until}) :-
    getenv('LE_MCP_EVENT_KEYS', Spec),
    split_string(Spec, ",", " ", Entries),
    member(Entry, Entries),
    split_string(Entry, ":", " ", [Name, B, From, Until]),
    Name == Key, !,
    number_string(Budget, B),
    atom_concat('event:', Name, Id).

		 /*******************************
		 *          THE LEVELS          *
		 *******************************/

%!  level_limits(+Level, -Limits) is det.
%
%   Limits is a dict: `per_minute` and `burst` (the token bucket), `daily`
%   (calls a day, or `none`), `max_text` (characters a call may send).
level_limits(anonymous, _{per_minute: R, burst: B, daily: D, max_text: 20000}) :-
    env_number('LE_MCP_RATE', 10, R),
    env_number('LE_MCP_BURST', R, B),
    env_number('LE_MCP_DAILY', 200, D).
level_limits(person,  _{per_minute: 30,  burst: 30,  daily: 2000,  max_text: 200000}).
level_limits(event,   _{per_minute: 60,  burst: 60,  daily: none,  max_text: 200000}).
level_limits(licence, _{per_minute: 300, burst: 300, daily: 50000, max_text: 1000000}).
level_limits(program, _{per_minute: 300, burst: 300, daily: 50000, max_text: 1000000}).

%   The address behind many sessions of anonymous clients (a class behind
%   one university address): ten times one client's budget.
address_limits(L0, L) :-
    L = L0.put(_{per_minute: L0.per_minute * 10, burst: L0.burst * 10,
                 daily: L0.daily * 10}).

env_number(Var, Default, N) :-
    (   getenv(Var, V), atom_number(V, N0), N0 > 0 -> N = N0 ; N = Default ).

env_true(Var) :- getenv(Var, V), downcase_atom(V, true).

		 /*******************************
		 *          THE BUDGET          *
		 *******************************/

%!  throttle_admit(+Identity, +Cost, +TextLengths, -Verdict) is det.
%
%   Whether a call that costs Cost and sends texts of TextLengths characters
%   may run now. Verdict is `allow`, or `refuse(Status, Seconds, Message)`:
%   Status is the HTTP status a plain web address replies (429 or 413),
%   Seconds how long to wait (0 when waiting does not help).
throttle_admit(Identity, Cost, Lengths, Verdict) :-
    get_time(Now),
    admit_at(Identity, Cost, Lengths, Now, Verdict).

%!  admit_at(+Identity, +Cost, +TextLengths, +Now, -Verdict) is det.
%
%   throttle_admit/4 at the time Now, so that a test needs no waiting.
admit_at(Identity, _, _, _, allow) :-
    get_dict(level, Identity, local), !.
admit_at(Identity, Cost, Lengths, Now, Verdict) :-
    get_dict(level, Identity, Level),
    level_limits(Level, Limits),
    (   max_list([0|Lengths], Longest), Longest > Limits.max_text
    ->  refusal(throttle_too_long, Identity, [length-Longest, max-(Limits.max_text)], 0, Message),
        Verdict = refuse(413, 0, Message)
    ;   with_mutex(le_throttle, admit_(Identity, Level, Limits, Cost, Now, spend, Verdict))
    ).

%!  throttle_check(+Identity, +Need, -Verdict) is det.
%
%   Whether the client has Need left in its budget, without spending it: for
%   a call whose cost is known only once it has run (a program run, charged
%   by its seconds with throttle_charge/2 afterwards).
throttle_check(Identity, Need, Verdict) :-
    get_time(Now),
    check_at(Identity, Need, Now, Verdict).

%!  check_at(+Identity, +Need, +Now, -Verdict) is det.
check_at(Identity, _, _, allow) :-
    get_dict(level, Identity, local), !.
check_at(Identity, Need, Now, Verdict) :-
    get_dict(level, Identity, Level),
    level_limits(Level, Limits),
    with_mutex(le_throttle, admit_(Identity, Level, Limits, Need, Now, check, Verdict)).

%!  throttle_charge(+Identity, +Cost) is det.
%
%   Spend Cost from the client's budget, whatever is left: a bucket may go
%   below nothing, and the client then waits until it refills.
throttle_charge(Identity, Cost) :-
    get_time(Now),
    charge_at(Identity, Cost, Now).

%!  charge_at(+Identity, +Cost, +Now) is det.
charge_at(Identity, _, _) :-
    get_dict(level, Identity, local), !.
charge_at(Identity, Cost, Now) :-
    get_dict(level, Identity, Level),
    level_limits(Level, Limits),
    with_mutex(le_throttle, charge_(Identity, Level, Limits, Cost, Now)).

charge_(Identity, Level, Limits, Cost, Now) :-
    day(Now, Day),
    buckets(Identity, Level, Limits, Buckets),
    forall(member(b(Key, L, _), Buckets), spend(Key, L, Cost, Now, Day)),
    ( Level == event -> spend_event(Identity.event, Cost, Now) ; true ).

%   Mode `spend` spends Cost when the call may run; `check` only says whether
%   it may.
admit_(Identity, Level, Limits, Cost, Now, Mode, Verdict) :-
    clean_up(Now),
    day(Now, Day),
    buckets(Identity, Level, Limits, Buckets),
    (   Level == event, event_refusal(Identity, Day, Cost, Verdict0)
    ->  Verdict = Verdict0
    ;   member(b(Key, L, Who), Buckets),
        L.daily \== none,
        ( day_count(Key, Day, Used) -> true ; Used = 0 ),
        Used + Cost > L.daily
    ->  refusal(throttle_daily, Identity, [who-Who, daily-(L.daily)], 0, Message),
        Verdict = refuse(429, 0, Message)
    ;   member(b(Key, L, Who), Buckets),
        tokens(Key, L, Now, Tokens),
        Tokens < Cost
    ->  Wait is max(1, ceiling((Cost - Tokens) * 60 / L.per_minute)),
        %  A run is charged by its seconds (throttle_check/3, then
        %  throttle_charge/2): its refusal speaks of time, not of calls.
        ( Mode == check -> RateMsg = throttle_run_rate ; RateMsg = throttle_rate ),
        refusal(RateMsg, Identity, [who-Who, seconds-Wait, per_minute-(L.per_minute)], Wait, Message),
        Verdict = refuse(429, Wait, Message)
    ;   Mode == check
    ->  Verdict = allow
    ;   forall(member(b(Key, L, _), Buckets), spend(Key, L, Cost, Now, Day)),
        ( Level == event -> spend_event(Identity.event, Cost, Now) ; true ),
        Verdict = allow
    ).

%   The buckets a call spends from: b(Key, Limits, Who), Who naming the
%   client in a refusal. A client without a key in an MCP session has a
%   bucket for its session and shares a larger one with its address; an
%   event key, one for each session (or address) using it.
buckets(Identity, anonymous, Limits, Buckets) :- !,
    Address = Identity.address,
    address_limits(Limits, AddressLimits),
    (   Identity.session \== none
    ->  Buckets = [b(session(Identity.session), Limits, session),
                   b(address(Address), AddressLimits, address)]
    ;   Buckets = [b(address(Address), Limits, address)]
    ).
buckets(Identity, event, Limits, [b(event(Identity.event, Who), Limits, session)]) :- !,
    ( Identity.session \== none -> Who = Identity.session ; Who = Identity.address ).
buckets(Identity, _, Limits, [b(key(Identity.id), Limits, key)]).

%   The tokens in a bucket now: what was left, plus what has refilled since.
tokens(Key, L, Now, Tokens) :-
    (   bucket(Key, T0, Last)
    ->  Tokens is min(L.burst, T0 + (Now - Last) * L.per_minute / 60)
    ;   Tokens = L.burst
    ).

spend(Key, L, Cost, Now, Day) :-
    tokens(Key, L, Now, T),
    T1 is T - Cost,
    retractall(bucket(Key, _, _)),
    assertz(bucket(Key, T1, Now)),
    ( retract(day_count(Key, Day, N0)) -> true ; N0 = 0 ),
    N is N0 + Cost,
    assertz(day_count(Key, Day, N)).

%   An event key outside its days, or with its budget spent.
event_refusal(Identity, Day, Cost, refuse(429, 0, Message)) :-
    Event = Identity.event,
    text_to_string(Identity.from, From), text_to_string(Identity.until, Until),
    (   ( Day @< From ; Day @> Until )
    ->  refusal(throttle_event_dates, Identity,
                [event-Event, from-From, until-Until], 0, Message)
    ;   load_events,
        ( event_used(Event, Used) -> true ; Used = 0 ),
        Used + Cost > Identity.budget
    ->  refusal(throttle_event_used, Identity, [event-Event, budget-(Identity.budget)], 0, Message)
    ).

spend_event(Event, Cost, Now) :-
    load_events,
    ( retract(event_used(Event, N0)) -> true ; N0 = 0 ),
    N is N0 + Cost,
    assertz(event_used(Event, N)),
    save_events(Now).

%   The totals of the event keys outlive a restart when LE_MCP_STATE_DIR
%   names a directory: written at most once a minute, read once.
events_file(File) :-
    getenv('LE_MCP_STATE_DIR', Dir), Dir \== '',
    exists_directory(Dir),
    directory_file_path(Dir, 'mcp_event_totals.txt', File).

load_events :- events_loaded, !.
load_events :-
    assertz(events_loaded),
    (   events_file(File), exists_file(File)
    ->  catch(( read_file_to_terms(File, Terms, []),
                forall(member(event_used(E, N), Terms), assertz(event_used(E, N))) ),
              Err, print_message(warning, Err))
    ;   true
    ).

save_events(Now) :-
    (   events_file(File),
        \+ ( events_saved_at(T), Now - T < 60 )
    ->  retractall(events_saved_at(_)), assertz(events_saved_at(Now)),
        catch(setup_call_cleanup(open(File, write, S),
                                 forall(event_used(E, N), portray_clause(S, event_used(E, N))),
                                 close(S)),
              Err, print_message(warning, Err))
    ;   true
    ).

%   Every ten minutes: forget the buckets idle for a day, and the counts of
%   earlier days.
clean_up(Now) :-
    (   cleaned_at(T), Now - T < 600
    ->  true
    ;   retractall(cleaned_at(_)), assertz(cleaned_at(Now)),
        Old is Now - 86400,
        forall(( bucket(K, _, Last), Last < Old ), retractall(bucket(K, _, _))),
        day(Now, Today),
        forall(( day_count(K, D, _), D \== Today ), retractall(day_count(K, D, _)))
    ).

day(Now, Day) :- format_time(string(Day), '%F', Now).

%   A refusal, in the words of the message catalogue, and how to get more:
%   for a client without a key, where to ask for one.
refusal(Id, Identity, Pairs, _Wait, Message) :-
    maplist(who_words, Pairs, Pairs1),
    le_msg(Id, Pairs1, M0),
    (   get_dict(level, Identity, anonymous)
    ->  (   getenv('LE_MCP_CONTACT', C), C \== ''
        ->  le_msg(throttle_more_contact, [contact-C], More)
        ;   le_msg(throttle_more, [], More)
        ),
        format(string(Message), "~w ~w", [M0, More])
    ;   atom_string(M0, Message)
    ).

who_words(who-W, who-Words) :- !,
    atom_concat(throttle_who_, W, Id),
    le_msg(Id, [], Words).
who_words(P, P).

		 /*******************************
		 *     AT ONCE, AND IN TIME     *
		 *******************************/

%!  throttle_run(+Identity, :Goal, -Outcome) is det.
%
%   Run Goal once, as one of at most LE_MCP_CONCURRENT tool calls at a time,
%   within LE_MCP_TIME_LIMIT seconds. Outcome is `done`, `failed`,
%   `busy(Message)` (no turn came within five seconds), `timeout(Message)`,
%   or `error(E)`. A local client runs at once, without a time limit.
throttle_run(Identity, Goal, Outcome) :-
    get_dict(level, Identity, local), !,
    run_outcome(Goal, Outcome).
throttle_run(_Identity, Goal, Outcome) :-
    slots(Queue),
    (   thread_get_message(Queue, slot, [timeout(5)])
    ->  env_number('LE_MCP_TIME_LIMIT', 60, Limit),
        setup_call_cleanup(
            true,
            catch(( call_with_time_limit(Limit, run_outcome(Goal, Outcome0)), Outcome = Outcome0 ),
                  time_limit_exceeded,
                  ( le_msg(throttle_time, [seconds-Limit], M), atom_string(M, S), Outcome = timeout(S) )),
            thread_send_message(Queue, slot))
    ;   le_msg(throttle_busy, [seconds-10], M),
        atom_string(M, S),
        Outcome = busy(S)
    ).

run_outcome(Goal, Outcome) :-
    catch(( once(Goal) -> Outcome = done ; Outcome = failed ),
          E,
          ( E == time_limit_exceeded -> throw(E) ; Outcome = error(E) )).

slots(Queue) :- slot_queue(Queue), !.
slots(Queue) :-
    with_mutex(le_throttle,
               (   slot_queue(Queue) -> true
               ;   message_queue_create(Queue),
                   env_number('LE_MCP_CONCURRENT', 4, N),
                   forall(between(1, N, _), thread_send_message(Queue, slot)),
                   assertz(slot_queue(Queue))
               )).

%!  throttle_client_run(+Identity, :Goal, -Outcome) is det.
%
%   Run Goal once, as one of at most LE_THROTTLE_CLIENT_RUNS (2) calls of the
%   same client at a time: one client cannot keep the server busy with many
%   long program runs at once, each within its own time limit. Outcome is
%   `done`, `failed`, `busy(Message)` (the client has its runs going
%   already; nothing waits) or `error(E)`. A local client is not counted.
throttle_client_run(Identity, Goal, Outcome) :-
    get_dict(level, Identity, local), !,
    run_outcome_all(Goal, Outcome).
throttle_client_run(Identity, Goal, Outcome) :-
    client_key(Identity, Key),
    env_number('LE_THROTTLE_CLIENT_RUNS', 2, Max),
    with_mutex(le_throttle,
               (   ( client_running(Key, N0) -> true ; N0 = 0 ),
                   (   N0 < Max
                   ->  retractall(client_running(Key, _)), N1 is N0 + 1,
                       assertz(client_running(Key, N1)), Got = true
                   ;   Got = false
                   )
               )),
    (   Got == true
    ->  setup_call_cleanup(true, run_outcome_all(Goal, Outcome), release_client(Key))
    ;   le_msg(throttle_client_busy, [runs-Max], M), atom_string(M, S),
        Outcome = busy(S)
    ).

release_client(Key) :-
    with_mutex(le_throttle,
               (   retract(client_running(Key, N0)), N is N0 - 1,
                   ( N > 0 -> assertz(client_running(Key, N)) ; true )
               -> true ; true )).

%   The client, for the runs at once: the key or sign-in, else the session,
%   else the address.
client_key(Identity, Key) :-
    (   get_dict(level, Identity, anonymous)
    ->  (   Identity.session \== none -> Key = session(Identity.session) ; Key = address(Identity.address) )
    ;   Key = key(Identity.id)
    ).

%   As run_outcome/2, but an exception (a time limit included) is passed on
%   as the outcome rather than thrown.
run_outcome_all(Goal, Outcome) :-
    catch(( once(Goal) -> Outcome = done ; Outcome = failed ), E, Outcome = error(E)).

%!  throttle_new_session(-SessionId:atom) is det.
%
%   A new MCP session identifier, for the `Mcp-Session-Id` header of the
%   reply to `initialize`: a client sends it back with every later request,
%   so that the clients behind one address have a budget each.
throttle_new_session(Id) :-
    crypto_n_random_bytes(12, Bytes),
    hex_bytes(Hex, Bytes),
    atom_string(Id, Hex).

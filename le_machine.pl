/** <module> Which machine keeps a session: requests find their way back

    A server keeps a reasoning session (the program the editor loaded), an
    LE Assistant job and a Contract Assistant job in its own memory (or on
    its own disk). When the server runs on two or more machines, the proxy
    in front of them (fly.io's) may send the next request of an editor to a
    machine that does not have its session, which then answers "Session
    expired".

    The fix has two halves:

      - **an id names its machine** (machine_tagged_id/2): the id of each
        session and job ends with `__m` and the id of the machine that
        made it (`s3f2…__m148e21ea7d4e89`). Off a fly.io machine (a
        developer's server, the browser version) there is no machine id
        and ids are as before;
      - **a request goes back** (replay_machine/3): a request that names an
        id of another machine is answered with the header
        `fly-replay: prefer_instance=<machine>`. The fly.io proxy then
        sends the same request to that machine, starting it if it is
        stopped; the browser sees only the answer of the right machine.
        `prefer_instance` falls back to any machine when that one no longer
        exists: the request then arrives with `fly-replay-src`, is not sent
        back again, and the server answers as before ("Session expired":
        the editor loads the program again).

    The machine id is `FLY_MACHINE_ID` (set by fly.io on each machine);
    `LE_MACHINE_ID` overrides it, for tests that run two servers on one
    computer. `LE_MACHINE_REPLAY=off` turns the sending back off (ids still
    carry their machine).
*/

:- module(le_machine, [
    machine_id/1,               % -Id
    machine_tagged_id/2,        % +Id0, -Id
    id_machine/2,               % +Id, -Machine
    replay_machine/3,           % +Request, +Fields, -Machine
    id_field/1                  % ?Field
    ]).

%   No HTTP library here: the browser version (wasm/) loads this module
%   with le_kbs.pl. The replies are classic_web_api.pl's.

:- use_module(library(lists)).

%!  machine_id(-Id:atom) is semidet.
%
%   The id of the machine this server runs on; fails off fly.io.
machine_id(Id) :-
    (   getenv('LE_MACHINE_ID', Id0) -> true
    ;   getenv('FLY_MACHINE_ID', Id0)
    ),
    Id0 \== '',
    atom_string(Id, Id0).

%!  machine_tagged_id(+Id0, -Id) is det.
%
%   Id0 with the id of this machine at its end, of the same type (atom or
%   string); Id0 itself off fly.io.
machine_tagged_id(Id0, Id) :-
    (   machine_id(M)
    ->  (   string(Id0)
        ->  format(string(Id), "~w__m~w", [Id0, M])
        ;   format(atom(Id), "~w__m~w", [Id0, M])
        )
    ;   Id = Id0
    ).

%!  id_machine(+Id, -Machine:atom) is semidet.
%
%   The machine that made Id (an atom or a string); fails for an id that
%   names no machine.
id_machine(Id, Machine) :-
    ( atom(Id) -> true ; string(Id) ),
    atomic_list_concat(Parts, '__m', Id),
    Parts = [_, _|_],
    last(Parts, Machine0),
    Machine0 \== '',
    forall(sub_atom(Machine0, _, 1, _, C), char_type(C, alnum)),
    atom_string(Machine, Machine0).

%   The fields of a request that name something a machine keeps: the
%   session of the editor, the LE Assistant's job, the Contract
%   Assistant's job.
id_field(sessionModule).
id_field(job_id).
id_field(job).

%   fly.io does not replay a request whose body is larger than this.
replay_body_limit(1000000).

%!  replay_machine(+Request, +Fields:dict, -Machine:atom) is semidet.
%
%   Machine, another machine than this one, keeps what the request names
%   (Fields: the request's JSON body, or its query parameters as a dict),
%   and the request may be sent to it: it was not sent back already, and
%   its body is small enough to be sent again.
replay_machine(Request, Fields, Machine) :-
    \+ getenv('LE_MACHINE_REPLAY', off),
    machine_id(Me),
    \+ memberchk(fly_replay_src(_), Request),
    (   memberchk(content_length(Length), Request)
    ->  replay_body_limit(Limit), Length =< Limit
    ;   true
    ),
    is_dict(Fields),
    id_field(Field),
    get_dict(Field, Fields, Id),
    id_machine(Id, Machine),
    Machine \== Me,
    !.

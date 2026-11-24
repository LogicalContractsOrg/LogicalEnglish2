/** <module> Who may call the adapters (OIA, DMN)

    LE2's adapter kit (le_adapter.pl) asks its access hook whether a call
    may go ahead.

    On a server with no accounts (a clone of this repository, run on one's
    own machine) every call may: there is nobody to ask.

    On a server that has accounts (the hosted one, whose sign-in is the
    private lc_accounts module), a call may when it carries either

      - `Authorization: Bearer <token>`, a token from one of the adapters'
        sign-in routes (OIA's /opa-hub/api/{v}/auth, the DMN adapter's
        /dmn-adapter/oauth/token), or
      - `Authorization: Basic <id:secret>`, the id and secret of an API
        client, as KIE Server's and Camunda 7's clients send them.

    The adapters are free, as the translators are: any account's API client
    may call them, and the limits on use count against that account.

    The environment switches ADAPTERS_OPEN=true, OIA_ADAPTER_OPEN=true,
    DMN_ADAPTER_OPEN=true and NO_RESTRICTIONS=true turn the check off
    (le_adapter:adapter_open_access/1).

    Copyright Miguel Calejo; Apache License 2.0 (../NOTICE). Published
    "as is".
*/

:- module(adapter_access, [adapter_capability/1, adapter_sign_in/3, adapter_sign_in_jwt/3]).

:- use_module(library(base64)).
:- use_module(library(json)).
:- use_module('le2_paths').
:- use_module(le2(le_adapter)).

:- multifile le_adapter:access_hook/3.
:- multifile le_adapter:open_access_variable/2.

le_adapter:open_access_variable(oia, 'OIA_ADAPTER_OPEN').
le_adapter:open_access_variable(dmn, 'DMN_ADAPTER_OPEN').

%!  adapter_capability(-Capability) is det.
%
%   The capability the adapters go with: the translators', which every
%   account has.
adapter_capability(converters).

le_adapter:access_hook(Request, _Dialect, OK) :-
    (   current_predicate(lc_accounts:lc_verify_api_token/2)
    ->  (   caller_email(Request, _Email)
        ->  OK = ok
        ;   OK = error(401, _{error: "unauthorized",
                              error_description: "Send 'Authorization: Bearer <token>' (a token from the adapter's sign-in route) or 'Authorization: Basic' with an API client's id and secret."})
        )
    ;   OK = ok
    ).

caller_email(Request, Email) :-
    memberchk(authorization(Auth), Request),
    (   atom_concat('Bearer ', Token0, Auth)
    ->  jwt_inner(Token0, Token),
        lc_accounts:lc_verify_api_token(Token, Email)
    ;   atom_concat('Basic ', B64, Auth)
    ->  base64(Pair, B64), sub_atom(Pair, Before, 1, After, ':'), !,
        sub_atom(Pair, 0, Before, _, Id), sub_atom(Pair, _, After, 0, Secret),
        lc_accounts:lc_check_api_client(Id, Secret, Email)
    ).

%!  adapter_sign_in(+ClientId, +Secret, -Token) is semidet.
%   An OAuth client-credentials sign-in: the API client's token for an
%   hour; "open" when access is open and the client unknown.
adapter_sign_in(Id, Secret, Token) :-
    (   current_predicate(lc_accounts:lc_check_api_client/3),
        lc_accounts:lc_check_api_client(Id, Secret, Email)
    ->  lc_accounts:lc_api_token(Email, Id, Token)
    ;   ( adapter_open_access(oia) ; adapter_open_access(dmn) )
    ->  Token = "open"
    ).

%!  adapter_sign_in_jwt(+ClientId, +Secret, -Token) is semidet.
%
%   The same sign-in, its token shaped as a JSON Web Token: clients such as
%   Camunda's SDK read a token's expiry from its middle part (they do not
%   check its signature, which is the server's business). The middle part
%   holds `exp` and, as `lc`, the signed token of adapter_sign_in/3, which
%   is what the server checks (jwt_inner/2).
adapter_sign_in_jwt(Id, Secret, JWT) :-
    adapter_sign_in(Id, Secret, Token),
    get_time(Now), Exp is integer(Now) + 3600,
    atom_string(Id, IdS), atom_string(Token, TS),
    atom_json_dict(H, _{alg: "none", typ: "JWT"}, [width(0)]),
    atom_json_dict(P, _{exp: Exp, sub: IdS, lc: TS}, [width(0)]),
    base64url(H, HB), base64url(P, PB),
    atomic_list_concat([HB, PB, lc], '.', JWT).

%   The signed token inside a JWT-shaped one; any other token as it is.
jwt_inner(T0, T) :-
    (   atomic_list_concat([_, PB, lc], '.', T0),
        catch(( base64url(P, PB), atom_json_dict(P, D, [value_string_as(string)]), get_dict(lc, D, S) ), _, fail)
    ->  atom_string(T, S)
    ;   T = T0
    ).

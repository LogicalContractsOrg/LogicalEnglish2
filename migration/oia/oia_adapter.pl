/** <module> The OIA adapter: Oracle Intelligent Advisor's APIs, answered by LE twins

    An organisation that moves rules from Oracle Intelligent Advisor (OIA)
    to Logical English has applications that call OIA: a claims system
    posting a case to Batch Assess, a portal's JavaScript calling a decision
    service, a Siebel or Java client built on the SOAP Assess WSDL. This
    module answers those calls, in OIA's own shapes, from the Logical
    English twin the OIA translator wrote — so that the migration changes
    the address the callers use, not the callers (the user guides
    docs/user/integrations/oia.md and adapters.md describe it).

    This module is not an Oracle product. It holds no Oracle code, WSDL or
    schema: it reads and writes the requests and replies that Oracle
    documents publicly. It answers the calls listed below and nothing else
    of OIA.

    Routes (registered on LE2's server: classic_web_api.pl loads this file):

      POST /opa-hub/api/{version}/auth
           OIA's OAuth client-credentials sign-in (grant_type,
           client_id, client_secret): an `access_token` for an hour.
      POST /determinations-server/v2/{deployment}
      POST /determinations-server/v2/{deployment}/batch
      GET  /determinations-server/v2/{deployment}/swagger.json
           the decision service API: the input contract's fields in, the
           output contract's out; a list of cases for /batch; the OpenAPI
           2.0 description of both.
      POST /determinations-server/project/v2/{deployment}/{version}[/batch]
           the same, by project and version (the version is not checked).
      POST /determinations-server/batch/{12.2.x}/policy-models/{deployment}/assessor
           Batch Assess: `{"outcomes": [...], "cases": [{"@id": 1, ...}]}`
           in, `{"cases": [...], "summary": {...}}` out; an outcome asked
           `{"id": a, "knownOutcomeStyle": "decision-report"}` gets its
           explanation in `@decisionReports`.
      POST /determinations-server/assess/soap/generic/{10.4|12.2}/{deployment}
           SOAP Assess (the generic WSDL's `assess-request`), answered with
           an `assess-response` in the same version, decision reports where
           an outcome asks for them.
      GET  /oia-adapter
           a page listing the deployments, their endpoints, and how to call
           them.

    A DEPLOYMENT is a twin with its mapping, `<name>.oia_map.json`, which
    the translator writes beside the twin (oia_ir:oia_adapter_map/3): every
    attribute's public name, type, entity and template. The deployments are
    the twins under examples/migration/oia/ of the private place
    (le2_paths:private_root/1: most of the public OIA projects carry no
    licence that lets their twins be published) and under the
    directories of $OIA_ADAPTER_DIRS (colon-separated: a customer's twins),
    each found by any of its names (`do_i_need_to_file`, `doINeedToFile`,
    "Do I Need to File"), case ignored.

    ACCESS is ../adapter_access.pl's business, for every adapter: on a
    server that has accounts, a call carries `Authorization: Bearer <token>`
    from the auth route, whose client id and secret are an API client of an
    account; a server with no accounts asks for nothing. With
    `OIA_ADAPTER_OPEN=true` (or LE2's `NO_RESTRICTIONS=true`) no token is
    asked for — a developer's machine, a demonstration.

    How a case is answered is the work of LE2's adapter kit (le_adapter.pl),
    which the DMN adapter shares: the twin is loaded once (and again when
    its file changes); for each case a session gets the case's values as
    facts —
    each written as the twin's own sentence, read by LE's own parser — and
    each outcome is asked as a question of the twin, its answer the value of
    the template's last place; a boolean is true when the twin proves it.
    The closed world of the twin gives `false` where OIA could say
    *unknown* for a boolean, and no value (`null`) where OIA has none.
*/

:- module(oia_adapter, [
    oia_deployments/1,           % -Names
    oia_decide/5,                % +Deployment, +Case, +Outcomes, +Options, -Result
    oia_swagger/2                % +Deployment, -Dict
  ]).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_client)).
:- use_module(library(http/html_write)).
:- use_module(library(json)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).
:- use_module('../le2_paths').
:- use_module(le2(le_kbs)).
:- use_module(le2(le_adapter)).
:- use_module('../adapter_access').
:- use_module(oia_assess).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(D)), assertz(here(D)).

		 /*******************************
		 *            ROUTES            *
		 *******************************/

:- http_handler(root('opa-hub/api'), oia_auth, [prefix]).
:- http_handler(root('determinations-server/v2'), oia_v2, [prefix]).
:- http_handler(root('determinations-server/project/v2'), oia_project_v2, [prefix]).
:- http_handler(root('determinations-server/batch'), oia_batch, [prefix]).
:- http_handler(root('determinations-server/assess/soap'), oia_soap, [prefix]).
:- http_handler(root('oia-adapter'), oia_page, [prefix]).

%!  oia_auth(+Request) is det.
%
%   POST /opa-hub/api/{version}/auth — form fields grant_type
%   (client_credentials), client_id, client_secret.
oia_auth(Request) :- preflight(Request), !.
oia_auth(Request) :-
    memberchk(path_info(PI), Request), sub_atom(PI, _, _, 0, '/auth'), !,
    catch(http_read_data(Request, Form, [form_data(form)]), _, Form = []),
    (   memberchk(client_id=Id, Form), memberchk(client_secret=Secret, Form),
        adapter_sign_in(Id, Secret, Token)
    ->  reply(Request, 200, _{access_token: Token, token_type: "Bearer", expires_in: 3600})
    ;   open_access
    ->  reply(Request, 200, _{access_token: "open", token_type: "Bearer", expires_in: 3600})
    ;   reply(Request, 401, _{error: "invalid_client",
                              error_description: "Unknown client, or wrong secret."})
    ).
oia_auth(Request) :-
    reply(Request, 404, _{error: "not_found"}).

%   The decision service API (v2).
oia_v2(Request) :- preflight(Request), !.
oia_v2(Request) :-
    memberchk(path_info(PI0), Request),
    atomic_list_concat(Parts0, '/', PI0), exclude(==(''), Parts0, Parts),
    v2_route(Parts, Request).

oia_project_v2(Request) :- preflight(Request), !.
oia_project_v2(Request) :-
    memberchk(path_info(PI0), Request),
    atomic_list_concat(Parts0, '/', PI0), exclude(==(''), Parts0, Parts),
    (   Parts = [Dep, _Version|Rest] -> v2_route([Dep|Rest], Request)
    ;   reply(Request, 404, _{error: "not_found"})
    ).

v2_route([Dep0, 'swagger.json'], Request) :- !,
    with_deployment(Request, Dep0, Dep, ( oia_swagger(Dep, S), reply(Request, 200, S) )).
v2_route([Dep0], Request) :- !,
    when_authorised(Request,
        with_deployment(Request, Dep0, Dep,
            ( http_read_json_dict(Request, Case, [value_string_as(string)]),
              oia_decide(Dep, Case, contract, [], R),
              get_dict(outputs, R, Out),
              reply(Request, 200, Out) ))).
v2_route([Dep0, batch], Request) :- !,
    when_authorised(Request,
        with_deployment(Request, Dep0, Dep,
            ( http_read_json_dict(Request, Cases, [value_string_as(string)]),
              is_list(Cases),
              findall(O, ( member(C, Cases), oia_decide(Dep, C, contract, [], R), get_dict(outputs, R, O) ), Os),
              reply(Request, 200, Os) ))).
v2_route(_, Request) :-
    reply(Request, 404, _{error: "not_found"}).

%   Batch Assess.
oia_batch(Request) :- preflight(Request), !.
oia_batch(Request) :-
    memberchk(path_info(PI0), Request),
    atomic_list_concat(Parts0, '/', PI0), exclude(==(''), Parts0, Parts),
    (   append(_, ['policy-models', Dep0, assessor], Parts)
    ->  when_authorised(Request, with_deployment(Request, Dep0, Dep, batch_assess(Request, Dep)))
    ;   append(_, ['policy-models'], Parts)
    ->  oia_deployments(Ds),
        findall(_{name: N}, member(N, Ds), Items),
        reply(Request, 200, _{items: Items})
    ;   reply(Request, 404, _{error: "not_found"})
    ).

batch_assess(Request, Dep) :-
    http_read_json_dict(Request, Body, [value_string_as(string)]),
    ( get_dict(outcomes, Body, Outs0) -> true ; Outs0 = [] ),
    ( get_dict(cases, Body, Cases) -> true ; Cases = [] ),
    maplist(outcome_spec, Outs0, Outs),
    get_time(T0),
    findall(Res, ( member(C, Cases), batch_case(Dep, Outs, C, Res) ), Results),
    get_time(T1), Dur is T1 - T0,
    length(Cases, N),
    ( Dur > 0 -> Rate is N / Dur ; Rate = N ),
    reply(Request, 200, _{cases: Results,
                          summary: _{casesRead: N, casesProcessed: N, casesIgnored: 0,
                                     processorDurationSec: Dur, processorCasesPerSec: Rate}}).

outcome_spec(O, out(Id, Style)) :-
    (   is_dict(O) -> Id = O.id, ( get_dict(knownOutcomeStyle, O, S) -> Style = S ; Style = "value-only" )
    ;   Id = O, Style = "value-only"
    ).

batch_case(Dep, Outs, Case, Result) :-
    ( get_dict('@id', Case, Id) -> true ; Id = null ),
    findall(O, member(out(O, _), Outs), Names),
    findall(O, ( member(out(O, S), Outs), S \== "value-only" ), Reported),
    ( Names == [] -> Which = goals ; Which = Names ),
    oia_decide(Dep, Case, Which, [reports(Reported)], R),
    Res0 = R.outputs.put('@id', Id),
    get_dict(reports, R, Reps),
    (   dict_pairs(Reps, _, []) -> Result = Res0 ; Result = Res0.put('@decisionReports', Reps) ).

%   SOAP Assess (the generic WSDL).
oia_soap(Request) :- preflight(Request), !.
oia_soap(Request) :-
    memberchk(path_info(PI0), Request),
    atomic_list_concat(Parts0, '/', PI0), exclude(==(''), Parts0, Parts),
    last(Parts, Dep0),
    http_read_data(Request, XML, [to(string)]),
    soap_assess_dom(XML, DOM),
    (   soap_authorised(Request, DOM)
    ->  with_deployment(Request, Dep0, Dep, soap_assess(Request, Dep, DOM))
    ;   soap_fault(Request, 401, "Unauthorised: a bearer token, or a WS-Security user name token of an API client.")
    ).

soap_assess(Request, Dep, DOM) :-
    assess_soap_request(DOM, request(Inputs, Outcomes, Version)),
    soap_report_requests(DOM, Reported),
    oia_decide(Dep, Inputs, Outcomes, [reports(Reported)], R),
    deployment_map(Dep, Map),
    findall(result(Id, Type, V, Rep),
            ( member(Id0, Outcomes), atom_string(Id0, IdS), atom_string(Id, IdS),
              ( get_dict(Id, R.outputs, V0) -> ( V0 == null -> V = unknown ; V = V0 ) ; V = unknown ),
              ( attr_by_public(Map, IdS, A) -> atom_string(Type, A.type) ; Type = text ),
              ( get_dict(Id, R.reports, Tree) -> report_term(Tree, Rep) ; Rep = none ) ),
            Results),
    assess_soap_response(Version, Results, Out),
    cors_headers(Request),
    format("Content-Type: text/xml; charset=UTF-8~n~n~w", [Out]).

%   The outcomes a SOAP request asks a decision report for.
soap_report_requests(DOM, Ids) :-
    findall(Id, ( sub_term(element(N, A, _), DOM), oia_assess_local(N, attribute),
                  memberchk(id=Id, A),
                  ( memberchk('outcome-style'='decision-report', A)
                  ; memberchk('known-outcome-style'='decision-report', A)
                  ; memberchk('unknown-outcome-style'='decision-report', A) ) ), Ids0),
    maplist([X, Y]>>atom_string(X, Y), Ids0, Ids).

oia_assess_local(_:L, L) :- !.
oia_assess_local(L, L).

report_term(Dict, decision_node(T, K, Ks)) :-
    T = Dict.text, K = Dict.kind,
    maplist(report_term, Dict.children, Ks).

soap_fault(Request, Status, Msg) :-
    cors_headers(Request),
    format("Status: ~w~nContent-Type: text/xml; charset=UTF-8~n~n", [Status]),
    format("<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\"><SOAP-ENV:Body><SOAP-ENV:Fault><faultcode>SOAP-ENV:Client</faultcode><faultstring>~w</faultstring></SOAP-ENV:Fault></SOAP-ENV:Body></SOAP-ENV:Envelope>", [Msg]).

		 /*******************************
		 *            ACCESS            *
		 *******************************/

%   The kit's access check (le_adapter:adapter_access/3, with the hook of
%   ../adapter_access.pl: on a server with accounts, a token or an API
%   client of an account; OIA_ADAPTER_OPEN or NO_RESTRICTIONS turn it off).
open_access :- adapter_open_access(oia).

%   Run Goal when the call may; otherwise reply with the error.
when_authorised(Request, Goal) :-
    adapter_access(Request, oia, OK),
    (   OK == ok -> call(Goal)
    ;   OK = error(Status, Body), reply(Request, Status, Body)
    ).

soap_authorised(Request, DOM) :-
    (   adapter_access(Request, oia, ok) -> true
    ;   sub_term(element(UN, _, [U]), DOM), oia_assess_local(UN, 'Username'),
        sub_term(element(PN, _, [P]), DOM), oia_assess_local(PN, 'Password'),
        current_predicate(lc_accounts:lc_check_api_client/3),
        lc_accounts:lc_check_api_client(U, P, Email),
        adapter_capability(Cap),
        lc_accounts:lc_user_capabilities(Email, Caps), memberchk(Cap, Caps)
    ).

reply(Request, Status, Dict) :- adapter_reply(Request, Status, Dict).
cors_headers(Request) :- adapter_cors_headers(Request).
preflight(Request) :- adapter_preflight(Request).

		 /*******************************
		 *          DEPLOYMENTS         *
		 *******************************/

%   The deployments are the kit's (le_adapter.pl), dialect `oia`: the maps
%   `<twin>.oia_map.json` under the private place's examples/migration/oia/ and the
%   directories of $OIA_ADAPTER_DIRS.
:- multifile le_adapter:adapter_dialect/3.
le_adapter:adapter_dialect(oia, '.oia_map.json', Roots) :-
    deployment_roots(Roots).

%!  oia_deployments(-Names) is det.
oia_deployments(Names) :-
    adapter_deployments(oia, Ms),
    findall(P, ( member(M, Ms), P = M.project ), Ps0),
    sort(Ps0, Names).

deployment_roots(Roots) :-
    %  the twins of the public OIA projects are not published: they are in
    %  the private place (../le2_paths.pl, private_root/1)
    le2_paths:private_root(LP),
    atomic_list_concat([LP, '/examples/migration/oia'], Own),
    (   getenv('OIA_ADAPTER_DIRS', Extra), Extra \== ''
    ->  atomic_list_concat(More, ':', Extra)
    ;   More = []
    ),
    Roots = [Own|More].

%   The deployment a route names, by any of its names, case ignored; a
%   404 when there is none.
with_deployment(Request, Dep0, Dep, Goal) :-
    uri_encoded(path, Dep1, Dep0),
    (   adapter_deployment(oia, Dep1, M, _)
    ->  atom_string(Dep, M.project),
        catch(Goal, E, ( print_message(error, E), error_reply(Request, E) ))
    ;   reply(Request, 404, _{error: "not_found", error_description: "No deployment of that name."})
    ).

error_reply(Request, E) :-
    message_to_codes(E, Msg),
    reply(Request, 400, _{error: "bad_request", error_description: Msg}).

message_to_codes(E, S) :-
    catch(( message_to_codes(E, [], Cs), string_codes(S, Cs) ), _, format(string(S), "~q", [E])).
message_to_codes(E, _, Cs) :- format(codes(Cs), "~q", [E]).

deployment_map(Dep, Map) :- adapter_deployment(oia, Dep, Map, _).

		 /*******************************
		 *        ANSWERING A CASE      *
		 *******************************/

%!  oia_decide(+Deployment, +Case, +Outcomes, +Options, -Result) is det.
%
%   The kit's adapter_decide/6 on the deployment's twin and map. Case: a
%   dict, attributes by public name, a relationship's (or entity's)
%   instances under its public name as a list of dicts with "@id".
%   Outcomes: a list of public names, `contract` (a decision service's
%   output contract, else its goals) or `goals` (the conclusions no rule
%   reads). Options: reports(Names), the outcomes whose decision report is
%   wanted. Result: `_{outputs: Dict, reports: Dict}`; an outcome with no
%   value is null; an entity attribute's outcome is a list of
%   `{"@id": instance, name: value}`.
oia_decide(Dep, Case, Outcomes, Opts, Result) :-
    adapter_deployment(oia, Dep, Map, Twin),
    adapter_decide(Map, Twin, Case, Outcomes, Opts, Result).

attr_by_public(Map, N, A) :- adapter_attribute(Map, N, A).
outcome_attrs(Map, Outcomes, OAs) :- adapter_outcome_attributes(Map, Outcomes, OAs).

		 /*******************************
		 *        OPENAPI (swagger)     *
		 *******************************/

%!  oia_swagger(+Deployment, -Swagger) is det.
%
%   The OpenAPI 2.0 description a deployed decision service publishes
%   (`swagger.json`): its inputs (what no rule concludes) and its outputs.
oia_swagger(Dep, S) :-
    deployment_map(Dep, Map),
    findall(P-Prop, ( member(A, Map.attributes), A.entity == "global", A.derived == false,
                      atom_string(P, A.name), swagger_type(A, Prop) ), InPs),
    outcome_attrs(Map, contract, OAs),
    findall(P-Prop, ( member(A, OAs), atom_string(P, A.name), swagger_type(A, Prop) ), OutPs),
    dict_pairs(InProps, _, InPs), dict_pairs(OutProps, _, OutPs),
    format(string(Path), "/~w", [Map.project]),
    format(string(BPath), "/~w/batch", [Map.project]),
    Op = _{operationId: "assess", consumes: ["application/json"], produces: ["application/json"],
           parameters: [_{in: "body", name: "body", required: true, schema: _{'$ref': "#/definitions/input"}}],
           responses: _{'200': _{description: "The outcomes", schema: _{'$ref': "#/definitions/output"}}}},
    BOp = _{operationId: "assessBatch", consumes: ["application/json"], produces: ["application/json"],
            parameters: [_{in: "body", name: "body", required: true,
                           schema: _{type: array, items: _{'$ref': "#/definitions/input"}}}],
            responses: _{'200': _{description: "The outcomes of each case",
                                  schema: _{type: array, items: _{'$ref': "#/definitions/output"}}}}},
    atom_string(PathA, Path), atom_string(BPathA, BPath),
    dict_pairs(Paths, _, [PathA-_{post: Op}, BPathA-_{post: BOp}]),
    S = _{swagger: "2.0",
          info: _{title: Map.title, version: "1",
                  description: "The decision service of an Oracle Intelligent Advisor project, answered by its Logical English twin. This server is not an Oracle product."},
          basePath: "/determinations-server/v2",
          securityDefinitions: _{bearer: _{type: apiKey, name: "Authorization", in: header}},
          security: [_{bearer: []}],
          paths: Paths,
          definitions: _{input: _{type: object, properties: InProps},
                         output: _{type: object, properties: OutProps}}}.

swagger_type(A, P) :-
    T = A.type,
    (   T == "boolean" -> P0 = _{type: boolean}
    ;   memberchk(T, ["number", "currency"]) -> P0 = _{type: number}
    ;   memberchk(T, ["date", "datetime"]) -> P0 = _{type: string, format: date}
    ;   P0 = _{type: string}
    ),
    P = P0.put(description, A.text).

		 /*******************************
		 *         THE STATUS PAGE      *
		 *******************************/

oia_page(Request) :- preflight(Request), !.
oia_page(Request) :-
    adapter_reload(oia),
    adapter_deployments(oia, Ms),
    ( open_access -> Access = 'open (OIA_ADAPTER_OPEN): no token is asked for'
    ; Access = 'a bearer token from /opa-hub/api/12.2.23/auth, for an API client of an account on this server (a server with no accounts asks for nothing)' ),
    findall(tr([td(b(T)), td(Ns), td(code(V2)), td(code(BA)), td(code(SO))]),
            ( member(M, Ms), T = M.title,
              atomic_list_concat(M.deployments, ', ', Ns),
              format(atom(V2), 'POST /determinations-server/v2/~w', [M.project]),
              format(atom(BA), 'POST /determinations-server/batch/12.2.26/policy-models/~w/assessor', [M.project]),
              format(atom(SO), 'POST /determinations-server/assess/soap/generic/12.2/~w', [M.project]) ),
            Rows),
    reply_html_page(title('OIA adapter'),
        [ h1('The OIA adapter'),
          p(['Oracle Intelligent Advisor\'s APIs, answered by the Logical English twins of OIA projects. This server is not an Oracle product. Access: ', Access, '.']),
          table([border(1), cellpadding(4)],
                [ tr([th('Deployment'), th('Names'), th('Decision service'), th('Batch Assess'), th('SOAP Assess')])
                | Rows ]),
          p(['Each also publishes its OpenAPI description: GET /determinations-server/v2/<deployment>/swagger.json.'])
        ]),
    Request = Request.     % (the request carries nothing the page needs)

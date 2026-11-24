/** <module> The DMN adapter: DMN engines' APIs, answered by Logical English twins

    An organisation whose decision models (DMN, with FEEL) moved to Logical
    English has applications that call a DMN engine: a Quarkus service
    built on Kogito, a Java client of Red Hat's KIE Server, a process
    application on Camunda 7, a Node or Java worker on Camunda 8. This
    module answers those calls, in each engine's own shapes, from the
    model's twin, written by the DMN translator (dmn_twin.pl) with its
    mapping (dmn_adapter_map.pl), so that the move changes the address the
    callers use, not the callers. It is a dialect of LE2's adapter kit
    (le_adapter.pl), which also serves the OIA adapter.

    Routes (registered on LE2's server, which loads this file):

      Kogito and Apache KIE's generated decision services, under /kogito
      (a Kogito application serves them at its root: the callers change
      their base address from http://host:8080 to http://host/kogito):
        GET  /kogito/{model}                the model's DMN file
        POST /kogito/{model}                the inputs in, the whole context
                                            (inputs and every decision) out
        POST /kogito/{model}/dmnresult      the same as a DMN result:
                                            decisionResults, messages
        POST /kogito/{model}/{service}[/dmnresult]   a decision service
        GET  /kogito/q/openapi[.json]       the OpenAPI 3 description
        Add ?explain=true to a dmnresult call for each decision's
        explanation (`explanations`, an addition no Kogito client reads).

      KIE Server (Red Hat Decision Manager, IBM BAMOE), its REST API in JSON:
        GET  /kie-server/services/rest/server                  server info
        GET  /kie-server/services/rest/server/containers       containers
        GET  /kie-server/services/rest/server/containers/{c}/dmn   models
        POST /kie-server/services/rest/server/containers/{c}/dmn   evaluate:
             {"model-namespace", "model-name", "decision-name" | "decision-id"
              | "decision-service-name", "dmn-context"}
        Every twin is in every container: the model is found by its
        namespace and name.

      Camunda 7's REST API:
        GET  /engine-rest/engine, /engine-rest/version
        GET  /engine-rest/decision-definition[?key=]
        GET  /engine-rest/decision-definition/key/{key}
        POST /engine-rest/decision-definition/key/{key}[/tenant-id/{t}]/evaluate
        POST /engine-rest/decision-definition/{id}/evaluate
        GET  /engine-rest/decision-definition/{id}/xml, .../key/{key}/xml
        GET  /engine-rest/history/variable-instance[/count]  (empty: no processes)
             {"variables": {"season": {"value": "Spring", "type": "String"}}}
             in, the decision's result list out (one map per matched rule).

      Camunda 8's Orchestration Cluster REST API (what @camunda8/sdk's
      evaluateDecision calls):
        POST /v2/decision-definitions/evaluation  (also under /camunda8)
             {"decisionDefinitionId" | "decisionDefinitionKey", "variables"}
        POST /dmn-adapter/oauth/token   a client-credentials sign-in, for
             clients set up with OAuth (CAMUNDA_OAUTH_URL)

      GET /dmn-adapter     a page listing the deployments and their routes.

    A DEPLOYMENT is a twin with its mapping `<twin>.adapter_map.json`: the
    twins of LE2's examples/migration/dmn/, the private place's
    examples/migration/dmn/ (le2_paths:private_root/1), and the directories of $DMN_ADAPTER_DIRS
    (colon-separated: a customer's twins).

    ACCESS: as the OIA adapter's (../adapter_access.pl): a bearer token, or
    an API client's id and secret as HTTP Basic (KIE Server's and Camunda
    7's clients send these), of an account on a server that has accounts;
    DMN_ADAPTER_OPEN=true or NO_RESTRICTIONS=true for a
    developer's machine.

    What is not offered: KIE Server's XML formats (JAXB, XStream), its
    containers' life cycle, Camunda's deployments, process instances and
    history, the rules matched by a decision table (Camunda 8's
    `matchedRules` is empty), Kogito's tracing and explainability services.
    A boolean or a value the twin cannot conclude comes back null, as DMN
    gives it.
*/

:- module(dmn_adapter, [
    dmn_adapter_decide/5,        % +Deployment, +Inputs, +Decisions, +Options, -Result
    dmn_adapter_deployments/1    % -Maps
  ]).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_client)).
:- use_module(library(http/html_write)).
:- use_module(library(json)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).
:- use_module(library(sha)).
:- use_module(library(uri)).
:- use_module('../le2_paths').
:- use_module(le2(le_adapter)).
:- use_module('../adapter_access').

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(D)), assertz(here(D)).

		 /*******************************
		 *          DEPLOYMENTS         *
		 *******************************/

:- multifile le_adapter:adapter_dialect/3.
le_adapter:adapter_dialect(dmn, '.adapter_map.json', Roots) :-
    twins_dir(dmn, Public),
    private_root(LP), atomic_list_concat([LP, '/examples/migration/dmn'], Private),
    (   getenv('DMN_ADAPTER_DIRS', Extra), Extra \== ''
    ->  atomic_list_concat(More, ':', Extra)
    ;   More = []
    ),
    append([Public, Private], More, Roots).

%!  dmn_adapter_deployments(-Maps) is det.
dmn_adapter_deployments(Maps) :-
    adapter_deployments(dmn, Ms),
    include(dmn_map, Ms, Maps).

dmn_map(M) :- get_dict(source, M, "DMN").

%   A deployment by its model's name (and namespace, when given).
deployment_by_model(Name, NS, Map, Twin) :-
    (   NS \== none, NS \== null
    ->  dmn_adapter_deployments(Ms),
        member(Map, Ms), Map.dmn.namespace == NS,
        ( Map.dmn.name == Name ; Map.project == Name ), !,
        adapter_deployment(dmn, Map.project, _, Twin)
    ;   adapter_deployment(dmn, Name, Map, Twin)
    ).

%   A decision by its id (Camunda's key), in any deployment.
deployment_by_decision_key(Key0, Map, Twin, D) :-
    atom_string(Key0, Key),
    dmn_adapter_deployments(Ms),
    member(Map, Ms), member(D, Map.dmn.decisions), D.id == Key, !,
    adapter_deployment(dmn, Map.project, _, Twin).

		 /*******************************
		 *      ANSWERING A CASE        *
		 *******************************/

%!  dmn_adapter_decide(+Map, +Inputs, +Decisions, +Options, -Result) is det.
%
%   Inputs: a dict of the model's inputs by name. Decisions: `all` or a
%   list of decision names. Result: the kit's `_{outputs, reports}`, the
%   outputs by decision name. Options as the kit's (reports(Names)).
dmn_adapter_decide(Map, Inputs, Decisions, Opts, Result) :-
    adapter_deployment(dmn, Map.project, _, Twin),
    (   Decisions == all
    ->  findall(N, ( member(A, Map.attributes), A.role == "decision", N = A.name ), Names)
    ;   Names = Decisions
    ),
    adapter_decide(Map, Twin, Inputs, Names, Opts, Result).

%   The decisions a decision requires, and those they require: the
%   decision last, after what it rests on.
with_required(Map, Names, All) :-
    foldl(add_required(Map), Names, [], All0),
    reverse(All0, All).

add_required(Map, N, Acc0, Acc) :-
    (   memberchk(N, Acc0) -> Acc = Acc0
    ;   (   member(D, Map.dmn.decisions), D.name == N -> Req = D.required ; Req = [] ),
        foldl(add_required(Map), Req, Acc0, Acc1),
        Acc = [N|Acc1]
    ).

decision_info(Map, Name, D) :- member(D, Map.dmn.decisions), D.name == Name, !.

%   The inputs of a request: names as the model gives them; a value the
%   map does not know is kept (a Kogito context echoes it back).
known_inputs(Map, In, Known) :-
    dict_pairs(In, _, Ps),
    include(input_pair(Map), Ps, KPs),
    dict_pairs(Known, _, KPs).

input_pair(Map, K-_) :-
    adapter_attribute(Map, K, A),
    get_dict(role, A, "input").

		 /*******************************
		 *            ROUTES            *
		 *******************************/

:- http_handler(root(kogito), kogito, [prefix]).
:- http_handler(root('kie-server/services/rest/server'), kie_server, [prefix]).
:- http_handler(root('engine-rest'), camunda7, [prefix]).
:- http_handler(root('v2/decision-definitions'), camunda8, [prefix]).
:- http_handler(root('camunda8/v2/decision-definitions'), camunda8, [prefix]).
:- http_handler(root('dmn-adapter/oauth/token'), oauth_token, []).
:- http_handler(root('dmn-adapter'), status_page, []).

path_parts(Request, Parts) :-
    memberchk(path_info(PI0), Request), !,
    atomic_list_concat(Parts0, '/', PI0), exclude(==(''), Parts0, Parts1),
    maplist([E, D]>>uri_encoded(path, D, E), Parts1, Parts).
path_parts(_, []).

when_authorised(Request, Goal) :-
    adapter_access(Request, dmn, OK),
    (   OK == ok -> catch(Goal, E, error_reply(Request, E))
    ;   OK = error(Status, Body), adapter_reply(Request, Status, Body)
    ).

error_reply(Request, E) :-
    print_message(error, E),
    message_text(E, Msg),
    adapter_reply(Request, 400, _{error: "bad_request", message: Msg}).

message_text(E, S) :- catch(( message_to_codes(E, Cs), string_codes(S, Cs) ), _, format(string(S), "~q", [E])).
message_to_codes(E, Cs) :- format(codes(Cs), "~q", [E]).

read_json(Request, Dict) :-
    http_read_json_dict(Request, Dict, [value_string_as(string)]).

%   POST /dmn-adapter/oauth/token: grant_type, client_id, client_secret.
oauth_token(Request) :- adapter_preflight(Request), !.
oauth_token(Request) :-
    catch(http_read_data(Request, Form, [form_data(form)]), _, Form = []),
    (   memberchk(client_id=Id, Form), memberchk(client_secret=Secret, Form),
        adapter_sign_in_jwt(Id, Secret, Token)
    ->  adapter_reply(Request, 200, _{access_token: Token, token_type: "Bearer", expires_in: 3600})
    ;   adapter_open_access(dmn)
    ->  adapter_reply(Request, 200, _{access_token: "open", token_type: "Bearer", expires_in: 3600})
    ;   adapter_reply(Request, 401, _{error: "invalid_client", error_description: "Unknown client, or wrong secret."})
    ).

		 /*******************************
		 *            KOGITO            *
		 *******************************/

kogito(Request) :- adapter_preflight(Request), !.
kogito(Request) :-
    path_parts(Request, Parts),
    memberchk(method(Method), Request),
    kogito_route(Method, Parts, Request).

kogito_route(get, [q, OA], Request) :- memberchk(OA, [openapi, 'openapi.json']), !,
    kogito_openapi(OpenAPI), adapter_reply(Request, 200, OpenAPI).
kogito_route(get, [Model], Request) :- !,
    (   deployment_by_model(Model, none, Map, Twin)
    ->  model_file(Map, Twin, File),
        adapter_cors_headers(Request),
        format("Content-Type: application/xml; charset=UTF-8~n~n"),
        read_file_to_string(File, S, []), write(S)
    ;   kogito_not_found(Request, Model)
    ).
kogito_route(post, [Model|Rest], Request) :- !,
    (   deployment_by_model(Model, none, Map, _)
    ->  when_authorised(Request, kogito_post(Request, Map, Rest))
    ;   kogito_not_found(Request, Model)
    ).
kogito_route(_, _, Request) :-
    adapter_reply(Request, 404, _{error: "not_found"}).

kogito_not_found(Request, Model) :-
    format(string(M), "No model named ~w", [Model]),
    adapter_reply(Request, 404, _{error: "not_found", message: M}).

kogito_post(Request, Map, Rest) :-
    read_json(Request, In),
    (   Rest = [] -> Service = none, Style = context
    ;   Rest = [dmnresult] -> Service = none, Style = dmnresult
    ;   Rest = [S] -> Service = S, Style = context
    ;   Rest = [S, dmnresult] -> Service = S, Style = dmnresult
    ),
    (   Service == none
    ->  findall(N, ( member(D, Map.dmn.decisions), N = D.name ), Names)
    ;   member(Sv, Map.dmn.services), Sv.name == Service
    ->  Names = Sv.outputs
    ;   throw(error(existence_error(decision_service, Service), _))
    ),
    explain_wanted(Request, Names, Reports),
    known_inputs(Map, In, Known),
    dmn_adapter_decide(Map, Known, Names, [reports(Reports)], R),
    (   Style == context
    ->  (   Service == none
        ->  dict_pairs(In, _, IPs), dict_pairs(R.outputs, _, OPs), append(IPs, OPs, Ps),
            dict_pairs(Ctx, _, Ps)
        ;   Ctx = R.outputs
        ),
        adapter_reply(Request, 200, Ctx)
    ;   findall(DR, ( member(N, Names), decision_info(Map, N, D), atom_string(NA, N),
                      ( get_dict(NA, R.outputs, V) -> true ; V = null ),
                      DR = _{decisionId: D.id, decisionName: N, result: V, messages: [],
                             evaluationStatus: "SUCCEEDED"} ), DRs),
        dict_pairs(In, _, IPs), dict_pairs(R.outputs, _, OPs), append(IPs, OPs, Ps),
        dict_pairs(Ctx, _, Ps),
        Res0 = _{namespace: Map.dmn.namespace, modelName: Map.dmn.name, dmnContext: Ctx,
                 messages: [], decisionResults: DRs},
        (   Reports == [] -> Res = Res0 ; Res = Res0.put(explanations, R.reports) ),
        adapter_reply(Request, 200, Res)
    ).

explain_wanted(Request, Names, Reports) :-
    (   memberchk(search(Q), Request), memberchk(explain=E, Q), memberchk(E, [true, '1', yes])
    ->  Reports = Names
    ;   Reports = []
    ).

model_file(Map, Twin, File) :-
    file_directory_name(Twin, Dir),
    atomic_list_concat([Dir, '/sources/', Map.dmn.file], File).

%   OpenAPI 3, as Kogito generates it: one path per model (and per
%   decision service), the inputs in, the context out.
kogito_openapi(_{openapi: "3.0.3",
                 info: _{title: "Decision models answered by their Logical English twins", version: "1"},
                 paths: Paths, components: _{schemas: Schemas}}) :-
    dmn_adapter_deployments(Ms),
    findall(P-Op, ( member(M, Ms), model_path(M, P, Op) ), Ps0),
    sort(1, @<, Ps0, Ps),
    dict_pairs(Paths, _, Ps),
    findall(K-S, ( member(M, Ms), member(Role-Suffix, ["input"-"_input", "decision"-"_output"]),
                   schema_name(M, Suffix, K), model_schema(M, Role, S) ), Ss0),
    sort(1, @<, Ss0, Ss),
    dict_pairs(Schemas, _, Ss).

model_path(M, P, _{post: _{summary: M.title, operationId: Op,
                           requestBody: _{content: _{'application/json': _{schema: _{'$ref': In}}}},
                           responses: _{'200': _{description: "The inputs and every decision",
                                                 content: _{'application/json': _{schema: _{'$ref': Out}}}}}}}) :-
    format(atom(P), '/kogito/~w', [M.dmn.name]),
    schema_name(M, "_input", IK), schema_name(M, "_output", OK),
    format(string(In), "#/components/schemas/~w", [IK]),
    format(string(Out), "#/components/schemas/~w", [OK]),
    format(string(Op), "evaluate_~w", [M.twin]).

schema_name(M, Suffix, K) :- atomic_list_concat([M.twin, Suffix], K).

model_schema(M, Role, _{type: object, properties: Props}) :-
    findall(K-S, ( member(A, M.attributes), ( Role == "input" -> A.role == "input" ; true ),
                   atom_string(K, A.name), attr_schema(A, S) ), Ps),
    dict_pairs(Props, _, Ps).

attr_schema(A, S) :-
    (   A.kind == "structure"
    ->  findall(K-CS, ( member(C, A.components), atom_string(K, C.name), attr_schema(C, CS) ), Ps),
        dict_pairs(Pr, _, Ps), S = _{type: object, properties: Pr}
    ;   A.kind == "list" -> type_schema(A.type, IS), S = _{type: array, items: IS}
    ;   A.kind == "records"
    ->  findall(K-CS, ( member(C, A.components), atom_string(K, C.name), type_schema(C.type, CS) ), Ps),
        dict_pairs(Pr, _, Ps), S = _{type: array, items: _{type: object, properties: Pr}}
    ;   type_schema(A.type, S)
    ).

type_schema("number", _{type: number}) :- !.
type_schema("string", _{type: string}) :- !.
type_schema("boolean", _{type: boolean}) :- !.
type_schema("date", _{type: string, format: date}) :- !.
type_schema(_, _{}).

		 /*******************************
		 *          KIE SERVER          *
		 *******************************/

kie_server(Request) :- adapter_preflight(Request), !.
kie_server(Request) :-
    path_parts(Request, Parts),
    memberchk(method(Method), Request),
    kie_route(Method, Parts, Request).

kie_route(get, [], Request) :- !,
    adapter_reply(Request, 200,
        _{type: "SUCCESS", msg: "Kie Server info",
          result: _{'kie-server-info': _{id: "le-dmn-twins", version: "7.74.1.Final",
                                        name: "Logical English (KIE Server DMN API)",
                                        location: "", capabilities: ["KieServer", "BRM", "DMN"],
                                        messages: []}}}).
kie_route(get, [containers], Request) :- !,
    kie_containers(Cs),
    adapter_reply(Request, 200, _{type: "SUCCESS", msg: "List of created containers",
                                  result: _{'kie-containers': _{'kie-container': Cs}}}).
kie_route(get, [containers, C, dmn], Request) :- !,
    dmn_adapter_deployments(Ms),
    findall(I, ( member(M, Ms), kie_model_info(M, I) ), Is),
    format(string(Msg), "OK models successfully retrieved from container '~w'", [C]),
    adapter_reply(Request, 200, _{type: "SUCCESS", msg: Msg,
                                  result: _{'dmn-model-info-list': _{models: Is}}}).
kie_route(post, [containers, C, dmn], Request) :- !,
    when_authorised(Request, kie_evaluate(Request, C)).
kie_route(_, _, Request) :-
    adapter_reply(Request, 404, _{type: "FAILURE", msg: "Not found", result: null}).

%   Every twin is in every container; the containers listed are the
%   collections of twins, and `le-twins`.
kie_containers(Cs) :-
    dmn_adapter_deployments(Ms),
    findall(Coll, ( member(M, Ms), adapter_deployment(dmn, M.project, _, T),
                    file_directory_name(T, D1), file_directory_name(D1, D2), file_base_name(D2, Coll) ), Colls0),
    sort(['le-twins'|Colls0], Colls),
    findall(_{'container-id': C, status: "STARTED",
              'release-id': _{'group-id': "org.logicalenglish.twins", 'artifact-id': C, version: "1.0.0"},
              messages: []}, member(C, Colls), Cs).

kie_model_info(M, _{'model-namespace': M.dmn.namespace, 'model-name': M.dmn.name, 'model-id': M.twin,
                   decisions: Ds, inputs: Is, itemDefinitions: [], decisionServices: Ss}) :-
    findall(_{'decision-id': D.id, 'decision-name': D.name}, member(D, M.dmn.decisions), Ds),
    findall(_{'inputdata-id': I.id, 'inputdata-name': I.name, typeRef: null}, member(I, M.dmn.inputs), Is),
    findall(_{'decisionservice-id': S.id, 'decisionservice-name': S.name}, member(S, M.dmn.services), Ss).

kie_evaluate(Request, C) :-
    read_json(Request, B),
    ( get_dict('model-name', B, MN) -> true ; MN = none ),
    ( get_dict('model-namespace', B, NS) -> true ; NS = none ),
    ( get_dict('dmn-context', B, In) -> true ; In = _{} ),
    (   MN \== none, deployment_by_model(MN, NS, Map, _)
    ->  kie_wanted(Map, B, Wanted),
        with_required(Map, Wanted, Names),
        known_inputs(Map, In, Known),
        dmn_adapter_decide(Map, Known, Names, [], R),
        findall(Id-DR, ( member(N, Names), decision_info(Map, N, D), atom_string(Id, D.id), atom_string(NA, N),
                         ( get_dict(NA, R.outputs, V) -> true ; V = null ),
                         DR = _{messages: [], 'decision-id': D.id, 'decision-name': N, result: V,
                                status: "SUCCEEDED"} ), DRPs),
        dict_pairs(DRs, _, DRPs),
        dict_pairs(In, _, IPs), dict_pairs(R.outputs, _, OPs), append(IPs, OPs, Ps),
        dict_pairs(Ctx, _, Ps),
        ( get_dict('decision-name', B, DNs) -> true ; DNs = [] ),
        format(string(Msg), "OK from container '~w'", [C]),
        adapter_reply(Request, 200,
            _{type: "SUCCESS", msg: Msg,
              result: _{'dmn-evaluation-result':
                          _{messages: [], 'model-namespace': Map.dmn.namespace, 'model-name': Map.dmn.name,
                            'decision-name': DNs, 'dmn-context': Ctx, 'decision-results': DRs}}})
    ;   format(string(Msg), "Error evaluating decision: no model ~w in container '~w'", [MN, C]),
        adapter_reply(Request, 404, _{type: "FAILURE", msg: Msg, result: null})
    ).

%   The decisions a KIE request asks for: by name, by id, a decision
%   service's outputs, or all.
kie_wanted(Map, B, Names) :-
    (   get_dict('decision-name', B, DN0), DN0 \== null, DN0 \== []
    ->  as_list(DN0, Names)
    ;   get_dict('decision-id', B, DI0), DI0 \== null, DI0 \== []
    ->  as_list(DI0, Ids),
        findall(N, ( member(Id, Ids), member(D, Map.dmn.decisions), D.id == Id, N = D.name ), Names)
    ;   get_dict('decision-service-name', B, SN), SN \== null,
        member(S, Map.dmn.services), S.name == SN
    ->  Names = S.outputs
    ;   findall(N, ( member(D, Map.dmn.decisions), N = D.name ), Names)
    ).

as_list(X, L) :- ( is_list(X) -> L = X ; L = [X] ).

		 /*******************************
		 *           CAMUNDA 7          *
		 *******************************/

camunda7(Request) :- adapter_preflight(Request), !.
camunda7(Request) :-
    path_parts(Request, Parts),
    memberchk(method(Method), Request),
    c7_route(Method, Parts, Request).

c7_route(get, [engine], Request) :- !, adapter_reply(Request, 200, [_{name: "default"}]).
c7_route(get, [version], Request) :- !, adapter_reply(Request, 200, _{version: "7.23.0"}).
c7_route(get, ['decision-definition'], Request) :- !,
    ( memberchk(search(Q), Request) -> true ; Q = [] ),
    findall(Def, ( c7_definition(_, _, Def), ( memberchk(key=K, Q) -> atom_string(K, Def.key) ; true ) ), Defs),
    adapter_reply(Request, 200, Defs).
c7_route(get, ['decision-definition', key, Key], Request) :- !,
    (   c7_definition(Key, _, Def) -> adapter_reply(Request, 200, Def)
    ;   c7_not_found(Request, Key)
    ).
c7_route(post, ['decision-definition', key, Key, evaluate], Request) :- !,
    c7_evaluate(Request, Key).
c7_route(post, ['decision-definition', key, Key, 'tenant-id', _, evaluate], Request) :- !,
    c7_evaluate(Request, Key).
c7_route(post, ['decision-definition', Id, evaluate], Request) :- !,
    (   sub_atom(Id, B, _, _, ':') -> sub_atom(Id, 0, B, _, Key) ; Key = Id ),
    c7_evaluate(Request, Key).
c7_route(get, ['decision-definition', Id], Request) :- !,
    (   sub_atom(Id, B, _, _, ':') -> sub_atom(Id, 0, B, _, Key) ; Key = Id ),
    (   c7_definition(Key, _, Def) -> adapter_reply(Request, 200, Def)
    ;   c7_not_found(Request, Key)
    ).
%   The DMN file of a decision, as Camunda 7 serves it ({id, dmnXml}): the
%   original model the twin was translated from.
c7_route(get, ['decision-definition', key, Key, xml], Request) :- !,
    c7_xml(Request, Key).
c7_route(get, ['decision-definition', Id, xml], Request) :- !,
    (   sub_atom(Id, B, _, _, ':') -> sub_atom(Id, 0, B, _, Key) ; Key = Id ),
    c7_xml(Request, Key).
%   The history of process variables: the adapter runs no processes, so it
%   has none (RONL's Linked Data Explorer asks it for variable names).
c7_route(get, [history, 'variable-instance'], Request) :- !,
    adapter_reply(Request, 200, []).
c7_route(get, [history, 'variable-instance', count], Request) :- !,
    adapter_reply(Request, 200, _{count: 0}).
c7_route(_, _, Request) :-
    adapter_reply(Request, 404, _{type: "RestException", message: "Not found"}).

c7_xml(Request, Key) :-
    (   deployment_by_decision_key(Key, Map, Twin, _),
        c7_definition(Key, Map, Def)
    ->  model_file(Map, Twin, File),
        read_file_to_string(File, Xml, []),
        adapter_reply(Request, 200, _{id: Def.id, dmnXml: Xml})
    ;   c7_not_found(Request, Key)
    ).

c7_not_found(Request, Key) :-
    format(string(M), "No matching decision definition with key: ~w and no tenant-id", [Key]),
    adapter_reply(Request, 404, _{type: "RestException", message: M}).

c7_definition(Key, Map, Def) :-
    dmn_adapter_deployments(Ms),
    member(Map, Ms), member(D, Map.dmn.decisions),
    ( var(Key) -> true ; atom_string(Key, D.id) ),
    format(string(Id), "~w:1:~w", [D.id, Map.twin]),
    Def = _{id: Id, key: D.id, category: Map.dmn.namespace, name: D.name, version: 1,
            resource: Map.dmn.file, deploymentId: Map.twin,
            decisionRequirementsDefinitionId: null, decisionRequirementsDefinitionKey: null,
            tenantId: null, versionTag: null, historyTimeToLive: null}.

c7_evaluate(Request, Key) :-
    (   deployment_by_decision_key(Key, Map, _, D)
    ->  when_authorised(Request, c7_evaluate(Request, Map, D))
    ;   c7_not_found(Request, Key)
    ).

c7_evaluate(Request, Map, D) :-
    read_json(Request, B),
    ( get_dict(variables, B, Vars) -> true ; Vars = _{} ),
    dict_pairs(Vars, _, VPs),
    findall(K-V, ( member(K-TV, VPs), c7_plain(TV, V) ), Ps),
    dict_pairs(In, _, Ps),
    known_inputs(Map, In, Known),
    with_required(Map, [D.name], Names),
    dmn_adapter_decide(Map, Known, Names, [], R),
    atom_string(NA, D.name),
    ( get_dict(NA, R.outputs, V) -> true ; V = null ),
    result_list(D, V, Entries),
    maplist(c7_entry, Entries, List),
    adapter_reply(Request, 200, List).

%   A typed variable's value ({"value": .., "type": "Date"}: its day).
c7_plain(TV, V) :-
    (   is_dict(TV), get_dict(value, TV, V0)
    ->  (   get_dict(type, TV, T), memberchk(T, ["Date", "date"]), string(V0), sub_string(V0, 0, 10, _, Day)
        ->  V = Day
        ;   get_dict(type, TV, T2), memberchk(T2, ["Json", "Object"]), string(V0),
            catch(atom_json_dict(V0, V1, [value_string_as(string)]), _, fail)
        ->  V = V1
        ;   V = V0
        )
    ;   V = TV
    ).

%   A decision's value as Camunda's result list: one entry (a list of
%   output name-value pairs) per matched rule. A table that collects gives
%   one per element; a table of several outputs, its components; anything
%   else, one entry named after the table's output or the decision.
result_list(D, V, Entries) :-
    (   D.logic == "DECISION_TABLE"
    ->  findall(O, ( member(Out, D.outputs), O = Out.name ), ONs),
        (   is_list(V), D.hitPolicy \== "UNIQUE", D.hitPolicy \== "FIRST", D.aggregation == "NONE"
        ->  maplist(entry_of(ONs), V, Entries)
        ;   V == null -> Entries = []
        ;   entry_of(ONs, V, E), Entries = [E]
        )
    ;   V == null -> Entries = [[D.name-null]]
    ;   Entries = [[D.name-V]]
    ).

entry_of([ON], V, [Name-V]) :- !, out_name(ON, Name).
entry_of(ONs, V, Ps) :-
    is_dict(V), !,
    findall(N-X, ( member(N, ONs), atom_string(K, N), ( get_dict(K, V, X) -> true ; X = null ) ), Ps).
entry_of([ON|_], V, [N-V]) :- out_name(ON, N).

out_name(ON, N) :- ( ON == "" -> N = "result" ; N = ON ).

c7_entry(Ps, Dict) :-
    findall(K-TV, ( member(N-V, Ps), atom_string(K, N), c7_typed(V, TV) ), KPs),
    dict_pairs(Dict, _, KPs).

c7_typed(null, _{type: "Null", value: null, valueInfo: _{}}) :- !.
c7_typed(V, _{type: "Boolean", value: V, valueInfo: _{}}) :- memberchk(V, [true, false]), !.
c7_typed(V, _{type: T, value: V, valueInfo: _{}}) :- integer(V), !,
    ( abs(V) < 2147483648 -> T = "Integer" ; T = "Long" ).
c7_typed(V, _{type: "Double", value: V, valueInfo: _{}}) :- number(V), !.
c7_typed(V, _{type: "String", value: V, valueInfo: _{}}) :- string(V), !.
c7_typed(V, _{type: "Json", value: S, valueInfo: _{}}) :-
    with_output_to(string(S), json_write_dict(current_output, V, [width(0)])).

		 /*******************************
		 *           CAMUNDA 8          *
		 *******************************/

camunda8(Request) :- adapter_preflight(Request), !.
camunda8(Request) :-
    path_parts(Request, Parts),
    (   Parts == [evaluation], memberchk(method(post), Request)
    ->  when_authorised(Request, c8_evaluate(Request))
    ;   c8_problem(Request, 404, "NOT_FOUND", "No such endpoint")
    ).

c8_problem(Request, Status, Title, Detail) :-
    memberchk(path(P), Request),
    adapter_reply(Request, Status, _{type: "about:blank", title: Title, status: Status, detail: Detail, instance: P}).

c8_evaluate(Request) :-
    read_json(Request, B),
    (   get_dict(decisionDefinitionId, B, Id), Id \== null
    ->  true
    ;   get_dict(decisionDefinitionKey, B, K)
    ->  ( c8_key_decision(K, Id) -> true ; Id = none )
    ;   Id = none
    ),
    (   Id \== none, deployment_by_decision_key(Id, Map, _, D)
    ->  ( get_dict(variables, B, In) -> true ; In = _{} ),
        ( get_dict(tenantId, B, Tenant) -> true ; Tenant = "<default>" ),
        known_inputs(Map, In, Known),
        with_required(Map, [D.name], Names),
        dmn_adapter_decide(Map, Known, Names, [], R),
        findall(ED, ( member(N, Names), decision_info(Map, N, DI),
                      c8_evaluated(Map, DI, In, R.outputs, Tenant, ED) ), EDs),
        last(EDs, Top),
        c8_key(Map, "drg", Map.twin, DRGKey), c8_key(Map, "eval", In, EvalKey),
        adapter_reply(Request, 200,
            _{decisionDefinitionId: D.id, decisionDefinitionName: D.name, decisionDefinitionVersion: 1,
              decisionRequirementsId: Map.twin, output: Top.output,
              failedDecisionDefinitionId: "", failureMessage: "", tenantId: Tenant,
              decisionDefinitionKey: Top.decisionDefinitionKey, decisionRequirementsKey: DRGKey,
              decisionInstanceKey: EvalKey, decisionEvaluationKey: EvalKey,
              evaluatedDecisions: EDs})
    ;   format(string(Det), "Expected to evaluate decision '~w', but no decision found for id '~w'", [Id, Id]),
        c8_problem(Request, 404, "NOT_FOUND", Det)
    ).

c8_evaluated(Map, D, In, Outputs, Tenant,
             _{decisionDefinitionId: D.id, decisionDefinitionName: D.name, decisionDefinitionVersion: 1,
               decisionDefinitionType: D.logic, output: Out, tenantId: Tenant,
               matchedRules: [], evaluatedInputs: EIs, decisionDefinitionKey: Key,
               decisionEvaluationInstanceKey: Key}) :-
    atom_string(NA, D.name),
    ( get_dict(NA, Outputs, V) -> true ; V = null ),
    compact_json(V, Out),
    c8_key(Map, "decision", D.id, Key),
    (   D.logic == "DECISION_TABLE"
    ->  findall(_{inputId: IId, inputName: IT, inputValue: IV},
                ( member(I, D.inputs), IT = I.text, atom_string(IK, IT),
                  format(string(IId), "Input_~w", [I.index]),
                  input_value(Map, IK, In, Outputs, X),
                  compact_json(X, IV) ), EIs)
    ;   EIs = []
    ).

%   The value an input column reads: an input of the case, or a decision
%   (by its name or its table's output name).
input_value(Map, K, In, Outputs, X) :-
    (   get_dict(K, In, X) -> true
    ;   adapter_attribute(Map, K, A), atom_string(AK, A.name), get_dict(AK, Outputs, X) -> true
    ;   X = null
    ).

%   JSON as Camunda writes it in its `output` texts: no spaces.
compact_json(V, S) :- with_output_to(string(S), compact(V)).

compact(V) :- is_dict(V), !,
    dict_pairs(V, _, Ps), write('{'),
    foldl([K-X, I0, I]>>( ( I0 > 0 -> write(',') ; true ), atom_string(K, KS), compact(KS), write(':'), compact(X), I is I0 + 1 ), Ps, 0, _),
    write('}').
compact(V) :- is_list(V), !,
    write('['),
    foldl([X, I0, I]>>( ( I0 > 0 -> write(',') ; true ), compact(X), I is I0 + 1 ), V, 0, _),
    write(']').
compact(V) :- json_write_dict(current_output, V, [width(0)]).

%   Camunda's keys are numbers written as text; a decision's here is made
%   from its model and id, the same on every call.
c8_key(Map, Kind, X, Key) :-
    format(string(S), "~w/~w/~w", [Map.dmn.namespace, Kind, X]),
    sha_hash(S, H, []), hash_atom(H, Hex), sub_atom(Hex, 0, 12, _, H12),
    atom_concat('0x', H12, HA), atom_number(HA, N), N2 is 2251799813685248 + N mod 1000000000000,
    number_string(N2, Key).

c8_key_decision(K, Id) :-
    dmn_adapter_deployments(Ms), member(M, Ms), member(D, M.dmn.decisions),
    c8_key(M, "decision", D.id, K0), K0 == K, !, Id = D.id.

		 /*******************************
		 *        THE STATUS PAGE       *
		 *******************************/

status_page(Request) :- adapter_preflight(Request), !.
status_page(_Request) :-
    adapter_reload(dmn),
    dmn_adapter_deployments(Ms),
    ( adapter_open_access(dmn) -> Access = 'open (DMN_ADAPTER_OPEN or NO_RESTRICTIONS): no sign-in is asked for'
    ; Access = 'a bearer token from /dmn-adapter/oauth/token, or an API client\'s id and secret as HTTP Basic, of an account on this server (a server with no accounts asks for nothing)' ),
    findall(tr([td(b(T)), td(code(KG)), td(code(KIE)), td(Keys)]),
            ( member(M, Ms), T = M.title,
              format(atom(KG), 'POST /kogito/~w', [M.dmn.name]),
              format(atom(KIE), 'model-name "~w"', [M.dmn.name]),
              findall(K, ( member(D, M.dmn.decisions), K = D.id ), Ks), atomic_list_concat(Ks, ', ', Keys) ),
            Rows),
    length(Ms, N),
    reply_html_page(title('DMN adapter'),
        [ h1('The DMN adapter'),
          p(['The APIs of Kogito, KIE Server, Camunda 7 and Camunda 8, answered by the Logical English twins of ', N, ' DMN models. Access: ', Access, '.']),
          ul([ li(['Kogito: ', code('POST /kogito/<model>'), ', ', code('/kogito/<model>/dmnresult'), ', ', code('GET /kogito/q/openapi')]),
               li(['KIE Server: ', code('POST /kie-server/services/rest/server/containers/<any>/dmn')]),
               li(['Camunda 7: ', code('POST /engine-rest/decision-definition/key/<decision id>/evaluate')]),
               li(['Camunda 8: ', code('POST /v2/decision-definitions/evaluation'), ' with ', code('decisionDefinitionId')]) ]),
          table([border(1), cellpadding(4)],
                [ tr([th('Model'), th('Kogito'), th('KIE Server'), th('Camunda decision ids')]) | Rows ])
        ]).

/** <module> Oracle Intelligent Advisor Assess messages <-> cases

    An OIA rulebase is called with a CASE: the values of some attributes, the
    instances of some entities with theirs, and the outcomes wanted. Oracle
    has carried that case in three shapes over the years, all still in use:

      - the SOAP Assess service of the Determinations Server (10.x to 12.2),
        `assess-request` with a `global-instance` of `attribute` elements
        (`boolean-val`, `number-val`, `text-val`, `date-val`, ...), `entity`
        elements holding `instance`s, and attributes without a value naming
        the outcomes wanted (`outcome-style`, `known-outcome-style`);
      - the Batch Assess REST API (`/determinations-server/batch/12.2.x/
        policy-models/{name}/assessor`): `{"outcomes": [...], "cases":
        [{"@id": 1, attr: value, relationship: [{"@id": ...}]}]}`;
      - the decision service REST API (`/determinations-server/v2/{name}`):
        the input contract's fields as a flat JSON object.

    This module reads the SOAP shape into the case dicts the translator's
    test files use (oia_ir.pl: `inputs`, `expected`, keyed by public name,
    a relationship's or entity's instances a list of dicts with "@id") — so
    that a customer's logged Assess traffic replays as regression tests —
    and writes Assess responses back (oia_adapter.pl). The JSON shapes are
    dicts already.
*/

:- module(oia_assess, [
    assess_soap_case/3,          % +RequestFile, +ResponseFile, -CaseDict
    assess_soap_request/2,       % +RequestDOM, -request(Inputs, Outcomes, Version)
    assess_soap_response/3,      % +Version, +Results, -XMLString
    soap_assess_dom/2            % +XMLString, -DOM
  ]).

:- use_module(library(sgml)).
:- use_module(library(sgml_write)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).

%!  assess_soap_case(+Request, +Response, -Case) is det.
%
%   A published or logged Assess exchange as a test case: the request's
%   values are the inputs, the response's values of the attributes the
%   request asked for are the expected outcomes.
assess_soap_case(ReqFile, RespFile, Case) :-
    file_dom(ReqFile, ReqDOM), file_dom(RespFile, RespDOM),
    assess_soap_request(ReqDOM, request(Inputs, Outcomes, _)),
    response_values(RespDOM, Values),
    findall(K-V, ( member(O, Outcomes), memberchk(O-V, Values), atom_string(K, O) ), EPs),
    dict_pairs(Expected, _, EPs),
    file_base_name(ReqFile, B), file_name_extension(Id0, _, B),
    ( atom_concat(Id, '_request', Id0) -> true ; Id = Id0 ),
    Case = _{id: Id, inputs: Inputs, expected: Expected,
             description: "An Assess exchange published by Oracle: the request, and the outcomes Oracle's engine returned."}.

file_dom(File, DOM) :-
    read_file_to_string(File, S, [encoding(utf8)]),
    soap_assess_dom(S, DOM).

%!  soap_assess_dom(+XML, -DOM) is det.
soap_assess_dom(S, DOM) :-
    setup_call_cleanup(open_string(S, In),
                       load_structure(In, DOM, [dialect(xmlns), space(remove)]),
                       close(In)).

%!  assess_soap_request(+DOM, -request(Inputs, Outcomes, Version)) is det.
%
%   Inputs a dict: an attribute's value under its id, an entity's instances
%   under the entity's id. Outcomes the ids of the attributes asked for (an
%   attribute with an outcome style and no value). Version the namespace's
%   (`10.4`, `12.2`), to answer in the same.
assess_soap_request(DOM, request(Inputs, Outcomes, Version)) :-
    sub_element(DOM, 'assess-request', Req, NS),
    namespace_version(NS, Version),
    sub_element(Req, 'global-instance', GI, _),
    instance_values(GI, Pairs, Outcomes),
    dict_pairs(Inputs, _, Pairs).

instance_values(element(_, _, Content), Pairs, Outcomes) :-
    findall(Id-V, ( member(El, Content), local(El, attribute), attr(El, id, Id), attribute_value(El, V) ), APs),
    findall(Id, ( member(El, Content), local(El, attribute), attr(El, id, Id), \+ attribute_value(El, _) ), Outcomes),
    findall(Id-Insts,
            ( member(E, Content), local(E, entity), attr(E, id, Id),
              E = element(_, _, EC),
              findall(I, ( member(IE, EC), local(IE, instance), instance_dict(IE, I) ), Insts) ),
            EPs),
    append(APs, EPs, Pairs).

instance_dict(IE, I) :-
    attr(IE, id, IId),
    instance_values(IE, Ps, _),
    dict_pairs(I0, _, Ps),
    atom_string(IId, IS),
    put_dict('@id', I0, IS, I).

%   The value of an attribute element: its *-val child.
attribute_value(element(_, _, C), V) :-
    member(VE, C), VE = element(N, _, VC), local_name(N, L),
    sub_atom(L, _, 4, 0, '-val'),
    typed_val(L, VC, V), !.

typed_val('boolean-val', [T], V) :- !, ( T == true -> V = true ; V = false ).
typed_val('number-val', [T], V) :- !, atom_number(T, V).
typed_val('currency-val', [T], V) :- !, atom_number(T, V).
typed_val('date-val', [T], V) :- !, atom_string(T, V).
typed_val('datetime-val', [T], V) :- !, atom_string(T, V).
typed_val('text-val', [T], V) :- !, atom_string(T, V).
typed_val('text-val', [], "") :- !.
typed_val('uncertain-val', _, "(uncertain)") :- !.
typed_val('unknown-val', _, "(unknown)") :- !.
typed_val(_, [T], V) :- atom_string(T, V).

%   The values a response gives, global and per instance, by attribute id.
response_values(DOM, Values) :-
    sub_element(DOM, 'assess-response', Resp, _),
    sub_element(Resp, 'global-instance', GI, _),
    GI = element(_, _, C),
    findall(Id-V, ( member(El, C), local(El, attribute), attr(El, id, Id), attribute_value(El, V) ), Values).

		 /*******************************
		 *         THE RESPONSE         *
		 *******************************/

%!  assess_soap_response(+Version, +Results, -XML) is det.
%
%   Results: a list of result(Id, Type, Value, Report) for the global
%   instance — Value `unknown` for an outcome the twin could not decide —
%   and entity(Id, [instance(IId, [result(...)])]) for the entities.
%   Report is `none` or a decision report as decision_node(Text, Kind,
%   Children); the SOAP response writes it as OIA's `decision-report` with
%   `relationship-node`-free `attribute-node`s.
assess_soap_response(Version, Results, XML) :-
    format(atom(NS), 'http://oracle.com/determinations/server/~w/rulebase/assess/types', [Version]),
    maplist(result_element, Results, Els),
    Body = element('typ:assess-response', [], [element('typ:global-instance', [], Els)]),
    Env = element('SOAP-ENV:Envelope',
                  ['xmlns:SOAP-ENV'='http://schemas.xmlsoap.org/soap/envelope/', 'xmlns:typ'=NS],
                  [element('SOAP-ENV:Body', [], [Body])]),
    with_output_to(string(XML), xml_write(current_output, Env, [header(true), layout(true)])).

result_element(result(Id, Type, Value, Report), element('typ:attribute', Attrs, Kids)) :- !,
    ( Value == unknown -> Attrs = [id=Id, type=Type] ; Attrs = [id=Id, type=Type, inferred=true] ),
    value_elements(Type, Value, VEls),
    report_elements(Report, REls),
    append(VEls, REls, Kids).
result_element(entity(Id, Insts), element('typ:entity', [id=Id], IEls)) :-
    findall(element('typ:instance', [id=IId], REls),
            ( member(instance(IId, Rs), Insts), maplist(result_element, Rs, REls) ),
            IEls).

value_elements(_, unknown, [element('typ:unknown-val', [], [])]) :- !.
value_elements(boolean, V, [element('typ:boolean-val', [], [VA])]) :- !, format(atom(VA), '~w', [V]).
value_elements(number, V, [element('typ:number-val', [], [VA])]) :- !, format(atom(VA), '~w', [V]).
value_elements(currency, V, [element('typ:number-val', [], [VA])]) :- !, format(atom(VA), '~w', [V]).
value_elements(date, V, [element('typ:date-val', [], [VA])]) :- !, format(atom(VA), '~w', [V]).
value_elements(_, V, [element('typ:text-val', [], [VA])]) :- format(atom(VA), '~w', [V]).

report_elements(none, []) :- !.
report_elements(Node, [element('typ:decision-report', [], [E])]) :- report_node(Node, E).

report_node(decision_node(Text, Kind, Kids), element('typ:attribute-node', [text=Text, kind=Kind], KEls)) :-
    maplist(report_node, Kids, KEls).

		 /*******************************
		 *           HELPERS            *
		 *******************************/

%   An element by local name, anywhere below, with its namespace.
sub_element(DOM, Name, El, NS) :-
    ( is_list(DOM) -> member(X, DOM) ; X = DOM ),
    sub_element_(X, Name, El, NS), !.

sub_element_(El, Name, El, NS) :-
    El = element(N, _, _), local_name(N, Name), name_ns(N, NS).
sub_element_(element(_, _, C), Name, El, NS) :-
    member(X, C), X = element(_, _, _), sub_element_(X, Name, El, NS).

local(element(N, _, _), L) :- local_name(N, L).
local_name(_:L, L) :- !.
local_name(L, L).
name_ns(NS:_, NS) :- !.
name_ns(_, '').

attr(element(_, A, _), K, V) :- memberchk(K=V, A).

namespace_version(NS, V) :-
    (   atomic_list_concat(Parts, '/', NS), append(_, [V0, rulebase|_], Parts) -> V = V0 ; V = '12.2' ).

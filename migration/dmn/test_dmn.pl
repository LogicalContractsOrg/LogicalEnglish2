/*  The DMN translator's tests (the design notes roadmap.md, Phase 4).

        swipl -q -g run_tests -t halt migration/dmn/test_dmn.pl

    The FEEL parser, the names, the twin of small models written here (so
    the tests need no corpus), the hit policies, FEEL's three values, the
    STTR idiom of a multiple-choice answer, the oracle's JSON, File ▸ Open,
    and — when the corpus is fetched (fetch_sources.sh) — a TCK model and
    the last gate run.
*/

:- use_module(dmn_home).
:- use_module(library(plunit)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module('../le2_paths').
:- use_module(le2(le_migration)).
:- use_module(feel_parser).
:- use_module(dmn_names).
:- use_module(dmn_reader).
:- use_module(dmn_twin).
:- use_module(dmn_tests).
:- use_module(dmn_import).

:- begin_tests(feel_parser).

test(names_with_spaces_and_operators) :-
    feel_parse('Monthly Income - Gross * 12', ['Monthly Income - Gross'], A),
    assertion(A == arith(*, name('Monthly Income - Gross'), num(12))).

%   An import's BKM: one qualified name when the scope has it, a path into
%   the import otherwise.
test(path_into_an_import) :-
    feel_parse('Age.as of date(dob, today())', ['Age.as of date', dob], A),
    assertion(A = call(name('Age.as of date'), [_, _])),
    feel_parse('Age.as of date(dob, today())', ['as of date', dob], B),
    assertion(B = call(path(name('Age'), 'as of date'), [_, _])).

test(decimals_are_exact) :-
    feel_parse('0.1 + 0.2', [], arith(+, num(A), num(B))),
    assertion(A =:= 1r10), assertion(B =:= 1r5).

test(unary_tests) :-
    feel_unary('not(null, "Ja")', [], T1),
    assertion(T1 == not([test(eq(null)), test(eq(str("Ja")))])),
    feel_unary('if ?=null then false else contains(?,"x")', [], [test(expr(_))]),
    feel_unary('[1..5)', [], [test(range(true, num(1), num(5), false))]),
    feel_unary('-', [], any).

:- end_tests(feel_parser).

:- begin_tests(dmn_names).

test(words) :-
    name_words(isAffordable, A), assertion(A == [is_affordable]),
    name_words('nieuw bouwwerk _of _ uitbreiding daarvan Op Artikel 22.28 a', B),
    assertion(B == [nieuw, bouwwerk, of, uitbreiding, daarvan, op, artikel_22_28_a]),
    name_words('Vaste Waarde TRUE', C), assertion(C == [vaste, waarde, true]),
    name_words('HTTPServer', D), assertion(D == [http, server]).

:- end_tests(dmn_names).

:- begin_tests(dmn_twins).

%   A table with an ANY policy and `-` cells, a literal with three-valued
%   logic, and a COLLECT with a sum, in one model written here.
test(tables_and_three_values, [setup(tmp_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    write_model(Dir, 'm.dmn', model_xml),
    atomic_list_concat([Dir, '/m.dmn'], F),
    Cases = [case(c1, '', ['Age'-v(30), 'Member'-v(true)], [result('Discount', decision, v(10)), result('Adult member', decision, v(true)), result('Points', decision, v(5))]),
             %  false and null is false, as FEEL has it
             case(c2, '', ['Age'-v(16)], [result('Discount', decision, v(0)), result('Adult member', decision, v(false)), result('Points', decision, v(2))]),
             %  true and null is null
             case(c3, '', ['Age'-v(30)], [result('Adult member', decision, null)])],
    model_migration(F, [tests(Cases), document(here), program(m)], Mg),
    with_libraries(Mg, Dir),
    write_migration(Mg, Dir, m, report(_, Issues, counts(E, A, R), Fid)),
    assertion(\+ member(issue(error, _, _), Issues)),
    assertion(R =:= 0), assertion(E + A =:= 3),
    assertion(Fid = fidelity(7, 0, 0, _)),
    atomic_list_concat([Dir, '/m.le'], LE), read_file_to_string(LE, Text, []),
    %  the table is an LE table, its `-` read through `… or null`
    assertion(sub_string(Text, _, _, _, "the table discount is, with first match:")),
    assertion(sub_string(Text, _, _, _, "the member or null")),
    %  FEEL's and over a null: true, false, or no answer
    assertion(sub_string(Text, _, _, _, "the adult member is false if")).

%   STTR's multiple-choice idiom: `if ? = null then false else contains(?, "x")`
%   is a condition on the answer's text, and false where it has none.
test(sttr_choice, [setup(tmp_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    write_model(Dir, 's.dmn', sttr_xml),
    atomic_list_concat([Dir, '/s.dmn'], F),
    Cases = [case(c1, '', ['Kleur'-v("rood en blauw")], [result('Rood gekozen', decision, v(true))]),
             case(c2, '', ['Kleur'-v("groen")], [result('Rood gekozen', decision, v(false))]),
             case(c3, '', [], [result('Rood gekozen', decision, v(false))])],
    model_migration(F, [tests(Cases), document(here), program(s)], Mg),
    with_libraries(Mg, Dir),
    write_migration(Mg, Dir, s, report(LE, _, _, Fid)),
    assertion(Fid = fidelity(3, 0, 0, _)),
    read_file_to_string(LE, Text, []),
    assertion(sub_string(Text, _, _, _, "contains \"rood\"")).

%   File ▸ Open: a DMN model is recognised by its namespace and opens as
%   its twin, its TCK test file beside it giving the scenarios.
test(file_open, [setup(tmp_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    write_model(Dir, 'm.dmn', model_xml),
    atomic_list_concat([Dir, '/m.dmn'], F),
    assertion(detect_dmn(F)),
    atomic_list_concat([Dir, '/out'], Out),
    import_dmn(F, Out, imported(LE, [Note|_])),
    assertion(exists_file(LE)),
    assertion(sub_string(Note, _, _, _, "no test file beside it")).

tmp_dir(Dir) :- tmp_file(dmn, Dir), make_directory(Dir).

with_libraries(migration(_, program(H, _), _, _), Dir) :-
    (   memberchk(includes(Ls), H) -> forall(member(L, Ls), copy_library(L, Dir)) ; true ).

write_model(Dir, Name, Which) :-
    call(Which, Text),
    atomic_list_concat([Dir, '/', Name], F),
    setup_call_cleanup(open(F, write, O), write(O, Text), close(O)).

model_xml('<?xml version="1.0" encoding="UTF-8"?>
<definitions xmlns="https://www.omg.org/spec/DMN/20230324/MODEL/" namespace="http://example.com/m" name="M" id="m">
  <inputData id="i1" name="Age"><variable name="Age" typeRef="number"/></inputData>
  <inputData id="i2" name="Member"><variable name="Member" typeRef="boolean"/></inputData>
  <decision id="d1" name="Discount"><variable name="Discount" typeRef="number"/>
    <informationRequirement><requiredInput href="#i1"/></informationRequirement>
    <informationRequirement><requiredInput href="#i2"/></informationRequirement>
    <decisionTable hitPolicy="ANY">
      <input><inputExpression typeRef="number"><text>Age</text></inputExpression></input>
      <input><inputExpression typeRef="boolean"><text>Member</text></inputExpression></input>
      <output name="Discount" typeRef="number"/>
      <rule><inputEntry><text>&gt;= 18</text></inputEntry><inputEntry><text>true</text></inputEntry><outputEntry><text>10</text></outputEntry></rule>
      <rule><inputEntry><text>&lt; 18</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>0</text></outputEntry></rule>
      <rule><inputEntry><text>&gt;= 18</text></inputEntry><inputEntry><text>false</text></inputEntry><outputEntry><text>0</text></outputEntry></rule>
    </decisionTable>
  </decision>
  <decision id="d2" name="Adult member"><variable name="Adult member" typeRef="boolean"/>
    <literalExpression><text>Age &gt;= 18 and Member</text></literalExpression>
  </decision>
  <decision id="d3" name="Points"><variable name="Points" typeRef="number"/>
    <decisionTable hitPolicy="COLLECT" aggregation="SUM">
      <input><inputExpression typeRef="number"><text>Age</text></inputExpression></input>
      <output name="Points" typeRef="number"/>
      <rule><inputEntry><text>&gt; 0</text></inputEntry><outputEntry><text>2</text></outputEntry></rule>
      <rule><inputEntry><text>&gt;= 18</text></inputEntry><outputEntry><text>3</text></outputEntry></rule>
    </decisionTable>
  </decision>
</definitions>').

sttr_xml('<?xml version="1.0" encoding="UTF-8"?>
<semantic:definitions xmlns:semantic="http://www.omg.org/spec/DMN/20151101/dmn.xsd" namespace="http://example.com/s" name="S" id="s">
  <semantic:inputData id="i1" name="Kleur"><semantic:variable name="Kleur" typeRef="feel:string"/></semantic:inputData>
  <semantic:decision id="d1" name="Rood gekozen"><semantic:variable name="Rood gekozen" typeRef="feel:boolean"/>
    <semantic:informationRequirement><semantic:requiredInput href="#i1"/></semantic:informationRequirement>
    <semantic:decisionTable hitPolicy="UNIQUE">
      <semantic:input><semantic:inputExpression typeRef="feel:string"><semantic:text>Kleur</semantic:text></semantic:inputExpression></semantic:input>
      <semantic:output/>
      <semantic:rule><semantic:inputEntry><semantic:text>if ?=null then false else contains(?,"rood")</semantic:text></semantic:inputEntry><semantic:outputEntry><semantic:text>true</semantic:text></semantic:outputEntry></semantic:rule>
      <semantic:rule><semantic:inputEntry><semantic:text>if ?=null then true else not(contains(?,"rood"))</semantic:text></semantic:inputEntry><semantic:outputEntry><semantic:text>false</semantic:text></semantic:outputEntry></semantic:rule>
    </semantic:decisionTable>
  </semantic:decision>
</semantic:definitions>').

:- end_tests(dmn_twins).

tck_fetched :- dmn_path('.cache/tck', D), exists_directory(D).

:- begin_tests(dmn_corpus, [condition(tck_fetched)]).

test(tck_0004) :-
    dmn_path('.cache/tck/TestCases/compliance-level-2/0004-simpletable-U/0004-simpletable-U.dmn', F),
    tck_test_files(F, [TF|_]), tck_cases(TF, _, Cases),
    tmp_file(dmn, Dir), make_directory(Dir),
    model_migration(F, [tests(Cases), document(tck), program(t)], Mg),
    write_migration(Mg, Dir, t, report(_, _, _, Fid)),
    delete_directory_and_contents(Dir),
    assertion(Fid = fidelity(3, 0, 0, _)).

test(last_gate_runs) :-
    dmn_path('runs/gate.txt', GF), read_file_to_string(GF, G, []),
    assertion(sub_string(G, _, _, _, "sttr: 196 models, 43343 of 43343 texts parse")),
    dmn_path('runs/drg-gate.txt', DF), read_file_to_string(DF, D, []),
    assertion(sub_string(D, _, _, _, "sttr: 196 models, 196 compiled by Drools, 196 of 196 with the same DRG")).

:- end_tests(dmn_corpus).

%   The DMN adapter (dmn_adapter.pl): the four engines' APIs, over HTTP, on
%   a server of this process with only the adapter's routes, answered by
%   the twins of the client examples (LE2 examples/migration/dmn/clients/):
%   the requests are those of Kogito's README, Red Hat's KIE Server client,
%   Camunda 7's REST API and Camunda 8's SDK; the answers those of Drools
%   and of Camunda's engine on the original models (clients/*.cases.json,
%   runs/adapter-check.txt).
:- begin_tests(dmn_adapter, [setup(adapter_server), cleanup(adapter_server_stop)]).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_open)).
:- use_module(library(http/http_json)).
:- use_module(dmn_adapter).

:- dynamic adapter_port/1.

adapter_server :-
    setenv('DMN_ADAPTER_OPEN', true),
    http_server(http_dispatch, [port(localhost:Port)]),
    retractall(adapter_port(_)), assertz(adapter_port(Port)).
adapter_server_stop :-
    ( adapter_port(P) -> http_stop_server(localhost:P, []) ; true ),
    unsetenv('DMN_ADAPTER_OPEN').

post(Path, Body, Reply) :-
    adapter_port(P), format(atom(U), 'http://localhost:~w~w', [P, Path]),
    http_open(U, In, [post(json(Body)), request_header('Accept'='application/json')]),
    call_cleanup(json_read_dict(In, Reply, [value_string_as(string)]), close(In)).

test(kogito_readme) :-
    post('/kogito/Traffic%20Violation',
         _{'Driver': _{'Points': 2}, 'Violation': _{'Type': "speed", 'Actual Speed': 120, 'Speed Limit': 100}}, R),
    assertion(R.'Fine'.'Amount' =:= 500),
    assertion(R.'Should the driver be suspended?' == "No"),
    assertion(R.'Driver'.'Points' =:= 2).

test(kogito_dmnresult) :-
    post('/kogito/Traffic%20Violation/dmnresult',
         _{'Driver': _{'Points': 15}, 'Violation': _{'Type': "speed", 'Actual Speed': 140, 'Speed Limit': 100}}, R),
    assertion(R.modelName == "Traffic Violation"),
    member(D, R.decisionResults), D.decisionName == "Should the driver be suspended?", !,
    assertion(D.result == "Yes"),
    assertion(D.evaluationStatus == "SUCCEEDED").

test(kie_server_evaluate_all) :-
    post('/kie-server/services/rest/server/containers/traffic-violation/dmn',
         _{'model-namespace': "https://github.com/kiegroup/drools/kie-dmn/_A4BCA8B8-CF08-433F-93B2-A2598F19ECFF",
           'model-name': "Traffic Violation",
           'dmn-context': _{'Driver': _{'Points': 2}, 'Violation': _{'Type': "parking", 'Actual Speed': 0, 'Speed Limit': 0}}}, R),
    assertion(R.type == "SUCCESS"),
    Res = R.result.'dmn-evaluation-result',
    assertion(Res.'dmn-context'.'Fine'.'Points' =:= 1).

test(camunda7_result_list) :-
    post('/engine-rest/decision-definition/key/beverages/evaluate',
         _{variables: _{season: _{value: "Spring", type: "String"}, guestCount: _{value: 6, type: "Integer"},
                        guestsWithChildren: _{value: true, type: "Boolean"}}}, R),
    findall(V, ( member(E, R), V = E.beverages.value ), Vs),
    assertion(Vs == ["Pinot Noir", "Apple Juice", "Water"]),
    R = [E1|_], assertion(E1.beverages.type == "String").

get(Path, Reply) :-
    adapter_port(P), format(atom(U), 'http://localhost:~w~w', [P, Path]),
    http_open(U, In, [request_header('Accept'='application/json')]),
    call_cleanup(json_read_dict(In, Reply, [value_string_as(string)]), close(In)).

%   The calls of RONL's Linked Data Explorer (operaton.service.ts): the
%   definition by key, then its DMN file by the definition's id.
test(camunda7_definition_xml) :-
    get('/engine-rest/decision-definition/key/beverages', Def),
    format(atom(XP), '/engine-rest/decision-definition/~w/xml', [Def.id]),
    get(XP, X),
    assertion(X.id == Def.id),
    assertion(sub_string(X.dmnXml, _, _, _, "id=\"beverages\"")).

test(camunda7_variable_history) :-
    get('/engine-rest/history/variable-instance?processDefinitionKey=p&firstResult=0&maxResults=500', R),
    assertion(R == []).

test(camunda8_evaluation) :-
    post('/v2/decision-definitions/evaluation',
         _{decisionDefinitionId: "dish", variables: _{season: "Spring", guestCount: 6}}, R),
    assertion(R.output == "\"Steak\""),
    assertion(R.decisionDefinitionName == "Dish"),
    length(R.evaluatedDecisions, 1).

test(camunda8_unknown_decision) :-
    adapter_port(P), format(atom(U), 'http://localhost:~w/v2/decision-definitions/evaluation', [P]),
    http_open(U, In, [post(json(_{decisionDefinitionId: "nope", variables: _{}})), status_code(S)]),
    close(In),
    assertion(S == 404).

:- end_tests(dmn_adapter).

%   The way back (dmn_export.pl): a Logical English program as a DMN 1.6
%   model with its scenarios as TCK test cases. Whether the models run is
%   dmn_roundtrip.pl's (Drools, the TCK's runner: runs/roundtrip.txt).
:- begin_tests(dmn_export).

:- use_module(dmn_export).

le2_program(Rel, KB) :-
    le2_dir(D), atomic_list_concat([D, '/', Rel], F),
    le_kbs:load(F, KB).

test(tck_twin_table) :-
    le2_program('examples/migration/dmn/tck/0004_simpletable_u/0004_simpletable_u.le', KB),
    dmn_files(KB, t, DMN, Tests),
    assertion(sub_string(DMN, _, _, _, "xmlns=\"https://www.omg.org/spec/DMN/20240513/MODEL/\"")),
    assertion(sub_string(DMN, _, _, _, "hitPolicy=\"UNIQUE\"")),
    assertion(sub_string(DMN, _, _, _, "<inputData id=")),
    assertion(sub_string(Tests, _, _, _, "<testCase id=\"t001\">")).

%   A program about applicants: each applicant of a scenario is a test
%   case; the table's row ids leave it; the subject's place leaves the
%   names.
test(one_subject_program) :-
    le2_program('examples/regulatory/dmn_export/childcare_support.le', KB),
    dmn_files(KB, childcare, DMN, Tests),
    assertion(sub_string(DMN, _, _, _, "name=\"household income of the applicant\"")),
    assertion(sub_string(DMN, _, _, _, "hitPolicy=\"FIRST\"")),
    aggregate_all(count, sub_string(Tests, _, _, _, "<testCase "), N),
    assertion(N =:= 3).

test(abduction_refused) :-
    le2_program('examples/moreExamples/language/abduction/grass_is_wet.le', KB),
    check_dmn(KB, [], Ps),
    assertion(( member(problem(_, M), Ps), sub_string(M, _, _, _, "assumed") )).

test(registered_exporter) :-
    once(le_import:exporter(dmn, _, dmn, _, dmn_export:export_dmn, _)).

:- end_tests(dmn_export).

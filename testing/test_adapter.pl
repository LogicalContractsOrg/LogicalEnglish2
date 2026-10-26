/** <module> Unit tests for the adapter kit (le_adapter.pl)

    docs/user/integrations/adapters.md. The kit answers another system's
    callers from a Logical English twin and its mapping file. Pinned here,
    on two twins of examples/migration/dmn/clients/ (the models of Kogito's
    and Camunda's client examples) and their mapping files:
      * a case given as JSON, structures included, is answered as the
        original engine answers it (Kogito's README case of Traffic
        Violation: a fine of 500 and 3 points, no suspension);
      * a table that matches nothing gives null, not an object of nulls;
      * a decision that is a list gives a JSON list, in the table's order;
      * a name the callers use for a table's output (Camunda's
        `desiredDish`) finds the decision;
      * an explanation comes back as a tree of sentences when asked for;
      * the API operation `adapterDecide` finds the mapping beside the twin.

    Run with:  swipl -q -g run_tests -t halt testing/test_adapter.pl
*/

:- use_module(library(plunit)).
:- use_module('../le_adapter').
:- use_module('../le_api').

:- begin_tests(le_adapter).

twin(Name, Twin) :-
    module_property(le_adapter, file(F)), file_directory_name(F, Root),
    atomic_list_concat([Root, '/examples/migration/dmn/clients/', Name, '/', Name, '.le'], Twin).

decide(Name, Case, Outcomes, Opts, R) :-
    twin(Name, Twin),
    adapter_twin_map(Twin, Map),
    adapter_decide(Map, Twin, Case, Outcomes, Opts, R).

test(kogito_readme_case) :-
    decide(traffic_violation,
           _{'Driver': _{'Points': 2},
             'Violation': _{'Type': "speed", 'Actual Speed': 120, 'Speed Limit': 100}},
           all, [], R),
    Fine = R.outputs.'Fine',
    assertion(Fine.'Amount' =:= 500),
    assertion(Fine.'Points' =:= 3),
    assertion(R.outputs.'Should the driver be suspended?' == "No").

test(no_match_is_null) :-
    decide(traffic_violation,
           _{'Driver': _{'Points': 3},
             'Violation': _{'Type': "speed", 'Actual Speed': 105, 'Speed Limit': 100}},
           ["Fine"], [], R),
    assertion(R.outputs.'Fine' == null).

test(list_decision_in_table_order) :-
    decide(dinnerdecisions, _{season: "Winter", guestCount: 12, guestsWithChildren: true},
           ["Beverages"], [], R),
    assertion(R.outputs.'Beverages' == ["Guiness", "Apple Juice", "Water"]).

test(output_name_alias) :-
    twin(dinnerdecisions, Twin), adapter_twin_map(Twin, Map),
    adapter_attribute(Map, "desiredDish", A),
    assertion(A.name == "Dish").

test(explanation_tree) :-
    decide(dinnerdecisions, _{season: "Fall", guestCount: 4}, ["Dish"], [reports(["Dish"])], R),
    assertion(R.outputs.'Dish' == "Spareribs"),
    Rep = R.reports.'Dish',
    assertion(Rep.kind == "proved"),
    assertion(sub_string(Rep.text, _, _, _, "Spareribs")).

test(api_operation) :-
    le_api:handle_adapter_decide(
        _{file: "migration/dmn/clients/dinnerdecisions/dinnerdecisions",
          case: _{season: "Spring", guestCount: 6}, outcomes: ["Dish"]}, R),
    assertion(R.outputs.'Dish' == "Steak").

:- end_tests(le_adapter).

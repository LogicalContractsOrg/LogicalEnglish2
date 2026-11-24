/** <module> RUML's conformance tests, read

    The test suite of the format (appendix A of the specification) is data:
    the `.test.yaml` files under `tests/`, each naming a fixture. Two kinds:

        validation(Name, File, Layer, Expect, Rules)
            Layer schema | semantic, Expect accept | reject
        evaluation(Name, File, Mode, Inputs, Assertions)
            Mode optimized | complete; Inputs DataPointId-Value;
            Assertions Path-Status (from `evaluation.results.`P`.status`),
            Status true | false | undefined | ignored

    validation_tests/1 and evaluation_tests/1 give all of them, in the
    order of the files.
*/

:- module(ruml_tests, [validation_tests/1, evaluation_tests/1, test_files/1]).

:- use_module(library(yaml)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(corpus).

test_files(Fs) :-
    ruml_repo(R), atomic_list_concat([R, '/tests'], D),
    findall(F, ( directory_member(D, F, [recursive(true)]), atom_concat(_, '.test.yaml', F) ), Fs0),
    msort(Fs0, Fs).

validation_tests(Ts) :-
    test_files(Fs),
    findall(validation(Name, File, Layer, Expect, Rules),
            ( member(F, Fs), test_of(F, T, Dir), get_dict(kind, T, "validation"),
              atom_string(Name, T.name), fixture(Dir, T, File),
              atom_string(Layer, T.layer), atom_string(Expect, T.expect),
              ( get_dict(rules, T, Rs) -> maplist([R, A]>>atom_string(A, R), Rs, Rules) ; Rules = [] ) ),
            Ts).

evaluation_tests(Ts) :-
    test_files(Fs),
    findall(evaluation(Name, File, Mode, Inputs, Assertions),
            ( member(F, Fs), test_of(F, T, Dir), get_dict(kind, T, "evaluation"),
              atom_string(Name, T.name), fixture(Dir, T, File),
              atom_string(Mode, T.run.mode),
              dict_pairs(T.inputs, _, Inputs),
              findall(P-S, ( member(A, T.assertions), assertion(A, P, S) ), Assertions) ),
            Ts).

test_of(F, T, Dir) :-
    file_directory_name(F, Dir),
    yaml_read(F, D), member(T, D.tests).

fixture(Dir, T, File) :- atomic_list_concat([Dir, '/', T.ruml], File).

%   `evaluation.results.`1.2`.status` with its expected value.
assertion(A, Path, Status) :-
    string_concat("evaluation.results.`", Rest, A.query),
    sub_string(Rest, B, _, _, "`.status"), sub_string(Rest, 0, B, _, P),
    atom_string(Path, P),
    V = A.expectedValue, ( atom(V) -> Status = V ; atom_string(Status, V) ).

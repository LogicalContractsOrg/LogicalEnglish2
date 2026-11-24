/** <module> The gates of the RUML translator

    Step 1 (the design notes ruml.md §10): RUML's 90 validation tests. A file
    is accepted when the published JSON Schema accepts it (schema_check.mjs,
    with the format's own schemas) and the reader's checks find no error
    (ruml_reader:ruml_check/2, the rules no schema can state). Each test
    passes when that verdict is the one it expects.

        swipl -q -g "use_module('migration/ruml/gate'), gate:validation_gate" -t halt

    The result is written to runs/validation-gate.txt.

    Step 5: RUML's 103 evaluation tests, through Logical English
    (ruml_result.pl), in the mode each test names; and every result file
    valid against the published schema of results.

        swipl -q -g "use_module('migration/le2_paths'), use_module('migration/ruml/gate'), gate:evaluation_gate" -t halt

    The result is written to runs/evaluation-gate.txt, the result files to
    runs/results/ (gitignored).
*/

:- module(gate, [validation_gate/0, validation_gate/2, schema_verdicts/3, evaluation_gate/0, evaluation_gate/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(http/json)).
:- use_module(ruml_tests).
:- use_module(ruml_reader).
:- use_module(library(filesex)).
:- use_module(ruml_result).

here(D) :- module_property(gate, file(F)), file_directory_name(F, D).

%!  schema_verdicts(+Kind, +Files, -Verdicts) is det.
%   Verdicts: File-valid | File-invalid(Errors), by the published schema.
schema_verdicts(_, [], []) :- !.
schema_verdicts(Kind, Files, Verdicts) :-
    here(D), atomic_list_concat([D, '/schema_check.mjs'], Script),
    process_create(path(node), [Script, Kind|Files], [stdout(pipe(Out)), stderr(null)]),
    read_string(Out, _, S), close(Out),
    split_string(S, "\n", "", Ls),
    findall(F-V, ( member(L, Ls), L \== "", atom_json_dict(L, J, []),
                   atom_string(F, J.file), ( J.valid == true -> V = valid ; V = invalid(J.errors) ) ), Verdicts).

validation_gate :-
    validation_gate(Pass, Total),
    format("validation gate: ~d of ~d~n", [Pass, Total]).

validation_gate(Pass, Total) :-
    validation_tests(Ts),
    findall(F, member(validation(_, F, _, _, _), Ts), Fs0), sort(Fs0, Fs),
    schema_verdicts(ruml, Fs, SV),
    here(D), atomic_list_concat([D, '/runs/validation-gate.txt'], Log),
    setup_call_cleanup(open(Log, write, Out),
        ( foldl(run_validation(SV, Out), Ts, 0-0, Pass-Total),
          format(Out, "TOTAL ~d of ~d~n", [Pass, Total]) ),
        close(Out)).

run_validation(SV, Out, validation(Name, File, Layer, Expect, Rules), P0-T0, P-T) :-
    T is T0 + 1,
    ( memberchk(File-SVer, SV) -> true ; SVer = invalid([]) ),
    ruml_read_file(File, _, Issues),
    include(is_error, Issues, Errors),
    (   SVer == valid, Errors == [] -> Got = accept ; Got = reject ),
    findall(R, member(issue(error, R, _, _), Errors), Found0), sort(Found0, Found),
    (   Got == Expect -> P is P0 + 1, Mark = pass ; P = P0, Mark = 'FAIL' ),
    (   SVer == valid -> SchemaSays = accept ; SchemaSays = reject ),
    format(Out, "~w  ~w  ~w expects ~w ~w; schema ~w; reader ~w~n", [Mark, Name, Layer, Expect, Rules, SchemaSays, Found]).

evaluation_gate :-
    evaluation_gate(Pass, Total),
    format("evaluation gate: ~d of ~d~n", [Pass, Total]).

evaluation_gate(Pass, Total) :-
    evaluation_tests(Ts),
    here(D), atomic_list_concat([D, '/runs/results'], RD), make_directory_path(RD),
    atomic_list_concat([D, '/runs/evaluation-gate.txt'], Log),
    setup_call_cleanup(open(Log, write, Out),
        ( foldl(run_evaluation(Out, RD), Ts, 0-0-[], Pass0-Total-Files),
          schema_verdicts('ruml-result', Files, SV),
          findall(F, member(F-invalid(_), SV), Bad), length(Bad, NB),
          forall(member(F-invalid(E), SV), format(Out, "INVALID RESULT ~w ~q~n", [F, E])),
          Pass is Pass0, length(Files, NF), Valid is NF - NB,
          format(Out, "TOTAL ~d of ~d; result files valid against the schema: ~d of ~d~n", [Pass, Total, Valid, NF]),
          format("result files valid against the schema: ~d of ~d~n", [Valid, NF]) ),
        close(Out)).

run_evaluation(Out, RD, evaluation(Name, File, Mode, Inputs, As), P0-T0-F0, P-T-F) :-
    T is T0 + 1,
    (   catch(ruml_evaluate(File, Inputs, [mode(Mode), evaluation_id("39d467ac-8e6a-4fa5-bb36-eebbf6aec1a7"), clock("2026-08-20T12:00:00Z")], R), E,
              ( print_message(error, E), fail ))
    ->  j(R, evaluation, Ev), j(Ev, results, Rs),
        findall(Pa-Want-Got, ( member(Pa-Want, As), ( j(Rs, Pa, NR), j(NR, status, G0) -> atom_string(Got, G0) ; Got = none ), Got \== Want ), Bad),
        atomic_list_concat([RD, '/', Name, '.ruml-result'], RF),
        result_json_text(R, Text), setup_call_cleanup(open(RF, write, O, [encoding(utf8)]), write(O, Text), close(O)),
        F = [RF|F0],
        (   Bad == [] -> P is P0 + 1, format(Out, "pass  ~w  (~w)~n", [Name, Mode])
        ;   P = P0, format(Out, "FAIL  ~w  (~w) ~q~n", [Name, Mode, Bad])
        )
    ;   P = P0, F = F0, format(Out, "ERROR ~w~n", [Name])
    ).

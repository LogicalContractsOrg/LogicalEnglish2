/** <module> Validate the translation of one Epilog program against EpilogJS

    Translates an Epilog program into Logical English and checks the
    translation against EpilogJS, Stanford's own Epilog interpreter: a
    ruleset's queries must give EpilogJS's answers, and a game (or another
    program with operations) must end a play in the state EpilogJS ends it
    in. Prints one verdict line and exits 0 when the twin agrees.

    From an LE2 checkout, with LPS2 beside it or named by LPS2_DIR (a game's
    check runs LPS2's `lps state`):

        swipl migration/epilog/validate.pl -- ruleset RULES [DATA] [--out DIR]
        swipl migration/epilog/validate.pl -- game LIBRARY [--moves N] [--out DIR]
        swipl migration/epilog/validate.pl -- program LIBRARY DATA OPERATION... [--out DIR]

    `ruleset`: a rule sheet and, optionally, a data sheet. `game`: a game
    library (role, init, legal, operations, ...); EpilogJS plays N moves
    (default 12) by a fixed rule. `program`: operations with no game rules;
    the state starts as DATA and the operations are applied in turn
    (`convert_to_triples`, `invert(a)`). The twin is written under DIR
    (default ./epilog-twins/<name>/).

    **EpilogJS is needed, and is not distributed with this file.** Its
    licence allows academic, non-commercial use only and forbids
    redistribution. Fetch it yourself (fetch_sources.sh, or
    http://epilog.stanford.edu/javascript/epilog.js) into
    migration/epilog/.cache/epilog.js, or name it with EPILOG_JS, and use it
    only as that licence allows — or obtain a commercial licence from
    Stanford. node must be on the PATH.
*/

:- module(epilog_validate, [
    validate/4,              % +Kind, +Files, +Options, -Verdict
    twin_final_state/2       % +LEFile, -Fluents
  ]).

:- use_module(library(main)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(json)).
:- use_module(library(filesex)).
:- use_module(epilog_twin).
:- use_module(epilog_reader).
:- use_module('../le2_paths').
:- use_module(le2(le_kbs)).

%   The command line only when this file is the script (`swipl validate.pl
%   -- ...`), not when the tests or build load it as a library.
:- if(( current_prolog_flag(associated_file, AF), file_base_name(AF, 'validate.pl') )).
:- initialization(main, main).
:- endif.

main(Argv) :-
    args_options(Argv, Pos, Opts),
    (   epilogjs_present
    ->  (   Pos = [K|Files], atom_string(Kind, K), memberchk(Kind, [ruleset, game, program])
        ->  validate(Kind, Files, Opts, Verdict),
            print_verdict(Verdict),
            ( Verdict = agrees(_) -> halt(0) ; halt(1) )
        ;   format(user_error, "usage: validate.pl -- ruleset RULES [DATA] | game LIBRARY [--moves N] | program LIBRARY DATA OPERATION... [--out DIR]~n", []),
            halt(2)
        )
    ;   format(user_error, "EpilogJS is not here: put epilog.js in migration/epilog/.cache/ (fetch_sources.sh) or name it with EPILOG_JS. Its licence allows academic, non-commercial use only.~n", []),
        halt(2)
    ).

%   `--out DIR`, `--moves N` (or `--out=DIR`); the rest positional.
args_options([], [], []).
args_options([A, V|As], Ps, [O|Os]) :-
    atom_concat('--', Name, A), memberchk(Name, [out, moves]), !,
    opt_value(Name, V, O), args_options(As, Ps, Os).
args_options([A|As], Ps, [O|Os]) :-
    atom_concat('--', NV, A), sub_atom(NV, B, 1, _, '='), !,
    sub_atom(NV, 0, B, _, Name), B1 is B + 1, sub_atom(NV, B1, _, 0, V),
    opt_value(Name, V, O), args_options(As, Ps, Os).
args_options([A|As], [A|Ps], Os) :- args_options(As, Ps, Os).

opt_value(moves, V, moves(N)) :- !, atom_number(V, N).
opt_value(Name, V, O) :- O =.. [Name, V].

epilogjs_present :-
    (   getenv('EPILOG_JS', J), J \== '' -> true
    ;   module_property(epilog_twin, file(F)), file_directory_name(F, M),
        atomic_list_concat([M, '/.cache/epilog.js'], J)
    ),
    exists_file(J).

%!  validate(+Kind, +Files, +Options, -Verdict) is det.
%
%   Kind is ruleset (Files [Rules] or [Rules, Data]), game ([Library]) or
%   program ([Library, Data, Operation, ...]). Verdict is agrees(Detail),
%   differs(Detail) or unchecked(Detail): unchecked when the translation
%   leaves nothing EpilogJS's answers can be compared with (every query in a
%   residue block, say). Options: out(Dir), moves(N), id(Id), title(T),
%   source(Doc, Url).
validate(Kind, Files, Options, Verdict) :-
    Files = [Main|_],
    file_base_name(Main, B), file_name_extension(Id0, _, B),
    option(id(Id), Options, Id0),
    option(out(Out), Options, 'epilog-twins'),
    absolute_file_name(Out, OutAbs),
    option(title(Title), Options, Id),
    option(source(Doc, Url), Options, source("an Epilog program", Main)),
    Common = [title(Title), source(Doc, Url), out(OutAbs)],
    catch(validate_(Kind, Id, Files, Options, Common, Verdict), E,
          Verdict = differs(error(E))).

validate_(ruleset, Id, Files, _Options, Common, Verdict) :-
    (   Files = [R, D] -> true
    ;   Files = [R] -> D = none
    ),
    ( D == none -> DOpts = [] ; DOpts = [data(D)] ),
    append([[rules(R)], DOpts, Common], Opts),
    build_theory(Id, Opts, report(LE, _Issues, Counts, Fid)),
    (   Fid = fidelity(P, F, U, _), P + F + U > 0
    ->  (   F =:= 0, U =:= 0
        ->  Verdict = agrees(ruleset(LE, queries(P), Counts))
        ;   Verdict = differs(ruleset(LE, passed(P), failed(F), unknown(U), Counts))
        )
    ;   Verdict = unchecked(ruleset(LE, Counts))
    ).
validate_(game, Id, [Lib], Options, Common, Verdict) :-
    option(moves(N), Options, 12),
    build_game(Id, [library(Lib), moves(N)|Common], report(LE, _, Counts, _)),
    final_state_verdict(LE, Id, Counts, Verdict).
validate_(program, Id, [Lib, Data|Ops], _Options, Common, Verdict) :-
    Ops \== [],
    build_game(Id, [library(Lib), data(Data), operations(Ops)|Common], report(LE, _, Counts, _)),
    final_state_verdict(LE, Id, Counts, Verdict).

%   The twin's final state under LPS2 against EpilogJS's, recorded beside it.
final_state_verdict(LE, Id, Counts, Verdict) :-
    file_directory_name(LE, Dir),
    format(atom(J), '~w/sources/~w.epilog.json', [Dir, Id]),
    setup_call_cleanup(open(J, read, S), json_read_dict(S, Run, [value_string_as(atom)]), close(S)),
    base_state_of(Run, _, Expected),
    length(Run.steps, NS), Moves is NS - 1,
    twin_final_state(LE, Actual),
    (   Expected == Actual
    ->  length(Expected, NF), Verdict = agrees(play(LE, moves(Moves), fluents(NF), Counts))
    ;   subtract(Expected, Actual, Missing), subtract(Actual, Expected, Extra),
        Verdict = differs(play(LE, moves(Moves), missing(Missing), extra(Extra), Counts))
    ).

print_verdict(agrees(D)) :- format("AGREES with EpilogJS: ~q~n", [D]).
print_verdict(differs(D)) :- format("DIFFERS from EpilogJS: ~q~n", [D]).
print_verdict(unchecked(D)) :- format("NOT CHECKED (nothing to compare with EpilogJS): ~q~n", [D]).

%!  twin_final_state(+LEFile, -Fluents) is det.
%
%   The twin run by LPS2 (`lps state`): its final fluents, sorted, with a
%   name used at two arities given back its Epilog name (step_2(1,2) is
%   step(1,2)) and a symbol written as text given back as a symbol.
twin_final_state(LEFile, Fluents) :-
    lps2_dir(D), atomic_list_concat([D, '/lps'], Lps),
    le2_dir(LE2),
    setup_call_cleanup(
        process_create(Lps, [state, LEFile], [stdout(pipe(O)), stderr(null), process(P),
                                              environment(['LPS_LE2_LIB'=LE2])]),
        ( read_string(O, _, S), process_wait(P, _) ),
        close(O)),
    split_string(S, "\n", " ", Lines),
    findall(T, ( member(L, Lines), L \== "", \+ sub_string(L, 0, _, _, "warning"),
                 catch(term_string(T0, L), _, fail), epilog_name(T0, T) ), Ts),
    msort(Ts, Fluents).

epilog_name(T0, T) :-
    compound(T0), !, T0 =.. [F0|As0], maplist(symbol, As0, As), length(As, N),
    format(atom(Suffix), '_~w', [N]),
    ( atom_concat(F, Suffix, F0) -> true ; F = F0 ),
    T =.. [F|As].
epilog_name(T, T).

%   A symbol the twin wrote as text (a board's column a: "a") is the symbol.
symbol(S, A) :- string(S), !, atom_string(A, S).
symbol(T, T).

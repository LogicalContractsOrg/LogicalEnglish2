/** <module> File ▸ Open of an L4 file: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    a `.l4` file. An L4 file has two halves (the design notes l4.md): its
    rules, which become timeless Logical English (l4_twin.pl), and its
    contracts, which become Logical English for LPS (l4_contracts.pl). Which
    one the editor opens depends on who asks:

      - the LE editor opens the rules twin; a file that also has contracts
        gets their LE for LPS twin written beside it, and a note naming it;
      - the LPS2 IDE (which passes target(lps)) opens the contracts twin
        when the file has contracts, and the rules twin otherwise; the rules
        twin is then written beside it.

    The L4 file is kept under sources/, so File ▸ Show the Original shows it.
    What the translators cannot say is kept in the program as residue, with
    its reason, never dropped. When L4's own evaluator is installed here
    (fetch_oracle.sh and Node.js), the file's #EVAL, #ASSERT and #TRACE
    results become the scenarios' expected answers; without it the twins
    have their scenarios and no expectations.
*/

:- module(l4_import, [import_l4/3, import_l4/4, detect_l4/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(yall)).
:- use_module(library(option)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module(library(process)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(l4_reader).
:- use_module(l4_twin).
:- use_module(l4_contracts, [contract_twin/3, trace_oracle_needs/2]).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer), [ir_dicts/2]).
:- use_module(le2(le_migration)).

here(D) :- module_property(l4_import, file(F)), file_directory_name(F, D).

%!  detect_l4(+Input) is semidet.
%   A file the L4 reader reads as at least one definition, declaration or
%   assumption.
detect_l4(Input) :-
    exists_file(Input),
    catch(( l4_read_file(Input, l4_module(Items, _)),
            member(I, Items), functor(I, F, _), memberchk(F, [decide, declare, assume]) ), _, fail), !.

%!  import_l4(+Input, +OutDir, -Result) is det.
%!  import_l4(+Input, +OutDir, +Options, -Result) is det.
import_l4(Input, OutDir, Result) :- import_l4(Input, OutDir, [], Result).

import_l4(Input, OutDir0, Options, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    file_base_name(Input, Base),
    atomic_list_concat([OutDir, '/sources'], SD), make_directory_path(SD),
    atomic_list_concat([SD, '/', Base], Copy), copy_file(Input, Copy),
    licence_note(SD),
    twin_name(Input, Name),
    oracle_run(Input, OutDir, RunOpts, OracleNote),
    rules_twin(Input, OutDir, Name, Base, RunOpts, RulesLE, RulesNote),
    contracts_twin(Input, OutDir, Name, Base, RunOpts, ContractsLE, ContractsNote),
    (   option(target(lps), Options), ContractsLE \== none
    ->  LEFile = ContractsLE,
        file_base_name(RulesLE, RB),
        format(string(Beside), "The rules of the same file are the Logical English program ~w, written beside this one.", [RB]),
        Notes0 = [ContractsNote, RulesNote, Beside]
    ;   LEFile = RulesLE,
        (   ContractsLE == none
        ->  Notes0 = [RulesNote]
        ;   file_base_name(ContractsLE, CB),
            format(string(Beside), "The file's contracts are the LE for LPS program ~w, written beside this one: open the L4 file in the LPS2 IDE to run them.", [CB]),
            Notes0 = [RulesNote, ContractsNote, Beside]
        )
    ),
    append(Notes0, [OracleNote], Notes1),
    exclude(==(""), Notes1, Notes).

%   The rules half: timeless LE (l4_twin.pl).
rules_twin(Input, OutDir, Name, Base, RunOpts, LEFile, Note) :-
    atom_concat(Name, '_contracts.le', CF),
    append([[name(Name), source_copy(Base), contracts_beside(CF)], RunOpts], TOpts),
    twin_migration(Input, TOpts, Migration),
    (   Migration = migration(_, program(Hd, _), _, _), memberchk(includes(Libs), Hd)
    ->  forall(member(Lb, Libs), copy_library(Lb, OutDir))
    ;   true
    ),
    write_migration(Migration, OutDir, Name, report(LEFile, Issues, counts(E, A, R), Fid)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    (   Fid = fidelity(P, F, U, _)
    ->  format(string(Note), "Rules (~w): ~w source elements encoded, ~w approximated, ~w residue; ~w writer errors; L4's own answers: ~w expectations pass, ~w fail, ~w errors.",
               [Name, E, A, R, NE, P, F, U])
    ;   format(string(Note), "Rules (~w): ~w source elements encoded, ~w approximated, ~w residue; ~w writer errors.", [Name, E, A, R, NE])
    ).

%   The contracts half: LE for LPS (l4_contracts.pl), or none when the file
%   has no contract.
contracts_twin(Input, OutDir, Name, Base, RunOpts, LEFile, Note) :-
    atom_concat(Name, '_contracts', CName),
    trace_values(Input, VPs),
    catch(contract_twin(Input, [id(CName), title(Base), values(VPs)], Twin), _, fail),
    Twin = twin(_, _, items(Voc, _, _, _, Laws, _), Traces, Refused),
    ( Laws \== [] ; Traces \== [] ; Refused \== [] ), !,
    findall(I, ( member(V, Voc), decl_ir(V, I) ), VocIR),
    ir_dicts(program([target(lps)], VocIR), Dicts),
    b_setval(l4_dicts, Dicts),
    trace_results(RunOpts, Results),
    l4_contracts:twin_migration(Twin, [source(Base), results(Results)], Mig),
    write_migration(Mig, OutDir, CName, report(LEFile, Issues, counts(E, A, R), _)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    length(Traces, NT), include([T]>>( arg(5, T, St), St = data(_, _, _, _) ), Traces, OkT), length(OkT, NOk),
    length(Refused, NR),
    format(string(Note), "Contracts (~w): ~w source elements encoded, ~w approximated, ~w residue; ~w writer errors; ~w of the file's ~w #TRACE runs are scenarios; ~w contract(s) not translated, each with its reason in the program.",
           [CName, E, A, R, NE, NOk, NT, NR]).
contracts_twin(_, _, _, _, _, none, "").

%   L4's result of each #TRACE (Line-Text), written above its scenario.
trace_results(RunOpts, Results) :-
    memberchk(run(F), RunOpts), !,
    setup_call_cleanup(open(F, read, S, [encoding(utf8)]), json_read_dict(S, J), close(S)),
    findall(L-T, ( member(R, J.results), L = R.start.line,
                   ( string(R.result) -> T = R.result ; get_dict(error, R, E), E \== null -> format(string(T), "error: ~w", [E]) ; T = "" ) ), Results).
trace_results(_, []).

decl_ir(event(F, T, _), event(F, T, [known_as(F)])).
decl_ir(fluent(F, T, _), fluent(F, T, [known_as(F)])).
decl_ir(template(F, T, _), template(F, T, [known_as(F)])).
decl_ir(function(F, T), function(F, T, [known_as(F)])).

		 /*******************************
		 *      L4'S OWN EVALUATOR      *
		 *******************************/

oracle_available(Oracle) :-
    here(H),
    atomic_list_concat([H, '/l4_oracle.mjs'], Oracle),
    atomic_list_concat([H, '/oracle/jl4-core.wasm'], W),
    exists_file(W),
    catch(absolute_file_name(path(node), _, [access(execute)]), _, fail).

%   The evaluator's results for the file, as the rules twin's run(File).
oracle_run(Input, OutDir, [run(RunFile)], "The expected answers are L4's own evaluator's.") :-
    oracle_available(_),
    eval_text_file(Input, J), is_dict(J), get_dict(results, J, _), !,
    atomic_list_concat([OutDir, '/l4_results.json'], RunFile),
    setup_call_cleanup(open(RunFile, write, S, [encoding(utf8)]), json_write_dict(S, J, [width(0)]), close(S)).
oracle_run(_, _, [], "L4's own evaluator is not installed here, so the scenarios have no expected answers (migration/l4/fetch_oracle.sh installs it).").

eval_text_file(File, J) :-
    oracle_available(Oracle),
    catch(( process_create(path(timeout), ['120', node, Oracle, eval, File], [stdout(pipe(Out)), stderr(null)]),
            read_string(Out, _, JS), close(Out),
            split_string(JS, "\n", "\n", [L|_]),
            atom_json_dict(L, J, []) ), _, fail).

%   The values of trace expressions only L4 can work out (dates, amounts):
%   each appended to the file as an #EVAL.
trace_values(Input, VPs) :-
    catch(trace_oracle_needs(Input, Texts), _, Texts = []),
    (   Texts == [] -> VPs = []
    ;   oracle_available(_)
    ->  read_file_to_string(Input, Text0, [encoding(utf8)]),
        findall(E, ( member(T, Texts), format(string(E), "#EVAL ~w", [T]) ), Evals),
        atomic_list_concat(Evals, '\n', EvalText),
        split_string(Text0, "\n", "", Ls), length(Ls, N0),
        tmp_file_stream(text, TF, S), format(S, "~w~n~n~w~n", [Text0, EvalText]), close(S),
        (   eval_text_file(TF, J)
        ->  findall(T-P, ( nth1(I, Texts, T), Line is N0 + 1 + I, member(R, J.results),
                           R.start.line =:= Line, string(R.result), P = R.result ), VPs)
        ;   VPs = []
        ),
        delete_file(TF)
    ;   VPs = []
    ).

licence_note(SD) :-
    atomic_list_concat([SD, '/NOTICE.txt'], N),
    setup_call_cleanup(open(N, write, S),
        format(S, "The L4 file here is the one that was opened. The L4 translator is described in~nthe design notes l4.md; L4 itself is https://github.com/smucclaw/l4-ide.~n", []),
        close(S)).

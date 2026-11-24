:- module(rune_runner, [
    rune_runner_available/0,    % Java and DRR's files are on this machine
    rune_runner_start/0,        % start the runner, and warm it, in the background
    run_rune/4                  % +RuneFile, +PairsFile, +ExpectedFile, -Result
]).
/** <module> Running Rune written back from Logical English, on DRR's own engine

The way back of the design notes rune.md §13: a Rune file that rune_writeback
wrote is validated by Rune's own validator, turned into Java by Rune's own
generator and run by DRR's Java on the instructions of the report's test
pack (java_back/RuneRunner.java). The runner is one Java process for the
whole server, started once and kept: loading DRR's Rune and DRR's runtime
takes minutes the first time, and about forty seconds a report after.

    run_rune(+RuneFile, +Pairs, +Expected, -Result)

Result is ran(Summary) — Summary a dict: reports, same (reports equal to
DRR's own, field for field), agree and differ (field values), fields (the
fields that differ, most often first), function (the report function), seconds
— or not_run(Why), or invalid(Issues) when Rune's validator refuses the file.
*/
:- use_module(library(process)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(readutil)).
:- use_module(rune_paths).

:- dynamic runner/3.        % runner(Pid, In, Out)

rune_runner_available :-
    rune_home(H),
    directory_file_path(H, '.cache/classpath.txt', CP), exists_file(CP),
    directory_file_path(H, '.cache/lib/rosetta-source-7.14.0.jar', J), exists_file(J),
    absolute_file_name(path(java), _, [access(execute), file_errors(fail)]).

%!  rune_runner_start is det.
%
%   Starts the runner unless it runs, and sends it a first request in a
%   thread of its own, so that the first export does not pay for the warm-up.
rune_runner_start :-
    (   rune_runner_available
    ->  with_mutex(rune_runner, ensure_runner),
        (   catch(thread_property(rune_runner_warm, status(_)), _, fail) -> true
        ;   catch(thread_create(warm_up, _, [alias(rune_runner_warm), detached(true)]), _, true)
        )
    ;   true
    ).

ensure_runner :-
    (   runner(Pid, _, _), \+ process_dead(Pid) -> true
    ;   retractall(runner(_, _, _)), start_runner
    ).

%   (a process that still runs answers `timeout`)
process_dead(Pid) :- catch(process_wait(Pid, S, [timeout(0)]), _, S = gone), S \== timeout.

start_runner :-
    rune_home(H),
    format(atom(C), '~w/.cache', [H]),
    format(atom(LibDir), '~w/lib', [C]),
    directory_files(LibDir, Fs), msort(Fs, Sorted),
    findall(P, ( member(F, Sorted), file_name_extension(_, jar, F), directory_file_path(LibDir, F, P) ), Jars),
    format(atom(JR), '~w/java_back/resources', [H]), format(atom(JC), '~w/java_back/classes', [H]),
    atomic_list_concat([JR, JC|Jars], ':', CP),
    format(atom(RCP), '~w/classpath.txt', [C]),
    findall(J, ( member(N, ['rune-runtime-9.95.0.jar', 'cdm-java-6.29.0.jar', 'rosetta-source-1.46.0.jar',
                            'rosetta-source-2.9.0.jar', 'rosetta-source-7.14.0.jar']),
                 directory_file_path(LibDir, N, J) ), RuneJars),
    process_create(path(java), ['-Xmx5g', '-cp', CP, 'RuneRunner', RCP|RuneJars],
                   [stdin(pipe(In)), stdout(pipe(Out)), stderr(null), process(Pid)]),
    set_stream(In, encoding(utf8)), set_stream(Out, encoding(utf8)),
    read_line_to_string(Out, Ready),
    (   sub_string(Ready, 0, _, _, "ready")
    ->  assertz(runner(Pid, In, Out))
    ;   process_kill(Pid), throw(error(rune_runner(Ready), _))
    ).

%   The warm-up: the twin of a small report written back unchanged.
warm_up :-
    catch(( twins_dir(TD), directory_file_path(TD, 'cftc_valuation', _),
            tmp_file(rune_warm, W), make_directory_path(W),
            directory_file_path(W, 'warm.rosetta', R),
            warm_text(T), setup_call_cleanup(open(R, write, S), write(S, T), close(S)),
            directory_file_path(W, 'pairs.txt', PF), setup_call_cleanup(open(PF, write, S2), true, close(S2)),
            request(R, W, PF, 'drr.regulation.common.ValuationReportInstruction', _) ), _, true).

warm_text("namespace drr.lpsplus.warm\nversion \"0.1\"\n\nimport drr.regulation.common.*\nimport drr.regulation.cftc.*\nimport drr.regulation.cftc.rewrite.*\nimport drr.regulation.cftc.rewrite.valuation.*\n\ntype CFTCValuationReportLE extends drr.regulation.cftc.rewrite.valuation.CFTCValuationReport:\n    // a warm-up\n\nreport CFTC Valuation in T+1\n    from drr.regulation.common.ValuationReportInstruction\n    when drr.regulation.cftc.rewrite.valuation.ReportableProduct\n    with type CFTCValuationReportLE\n").

%   One request at a time: the runner holds one written-back file.
request(RuneFile, Work, Pairs, InType, Reply) :-
    with_mutex(rune_runner,
      ( ensure_runner,
        runner(_, In, Out),
        format(In, "~w\t~w\t~w\t~w~n", [RuneFile, Work, Pairs, InType]), flush_output(In),
        read_reply(Out, [], Reply) )).

read_reply(Out, Issues0, Reply) :-
    read_line_to_string(Out, L),
    (   L == end_of_file -> retractall(runner(_, _, _)), Reply = not_run("the runner stopped")
    ;   split_string(L, "\t", "", ["issue", Sev, Line, Msg|_])
    ->  read_reply(Out, [issue(Sev, Line, Msg)|Issues0], Reply)
    ;   split_string(L, "\t", "", ["done", "ok", Ok, Err, Fn, Secs|_])
    ->  reverse(Issues0, Is), Reply = ok(Ok, Err, Fn, Secs, Is)
    ;   split_string(L, "\t", "", ["done", "error"|Why])
    ->  reverse(Issues0, Is), Reply = error(Why, Is)
    ;   read_reply(Out, Issues0, Reply)
    ).

%!  run_rune(+RuneFile, +PairsFile, +ExpectedFile, -Result) is det.
run_rune(RuneFile, Pairs, Expected, Result) :-
    (   \+ rune_runner_available
    ->  Result = not_run("Java and DRR's files (migration/rune/fetch_sources.sh) are not on this machine")
    ;   file_name_extension(Base, _, RuneFile), atom_concat(Base, '.work', Work),
        in_type(RuneFile, InType),
        request(RuneFile, Work, Pairs, InType, Reply),
        (   Reply = ok(_, _, Fn, Secs, _)
        ->  compare_reports(Expected, Summary0),
            Result = ran(Summary0.put(_{function: Fn, seconds: Secs}))
        ;   Reply = error(Why, Issues)
        ->  ( Issues == [] -> atomic_list_concat(Why, ' ', W), Result = not_run(W) ; Result = invalid(Issues) )
        ;   Result = Reply
        )
    ).

in_type(RuneFile, InType) :-
    read_file_to_string(RuneFile, T, []), split_string(T, "\n", "", Ls),
    (   member(L, Ls), split_string(L, " ", " ", ["from", IT]) -> atom_string(InType, IT)
    ;   InType = 'drr.regulation.common.TransactionReportInstruction'
    ).

% ---------------------------------------------------------------- comparing

%   Each report the runner wrote against DRR's expected one, field by field
%   (a field is a path through the report's objects).
compare_reports(ExpectedFile, _{reports: N, same: Same, agree: A, differ: D, fields: Fields}) :-
    read_file_to_string(ExpectedFile, T, []), split_string(T, "\n", "", Ls0), exclude(==(""), Ls0, Ls),
    foldl(compare_one, Ls, c(0, 0, 0, 0, []), c(N, Same, A, D, Diffs)),
    msort(Diffs, Sorted), clumped(Sorted, Counts),
    findall(C-F, member(F-C, Counts), CF), keysort(CF, CF1), reverse(CF1, CF2),
    findall(_{field: F, reports: C}, ( member(C-F, CF2) ), Fields).

compare_one(Line, c(N0, S0, A0, D0, Df0), c(N, S, A, D, Df)) :-
    split_string(Line, "\t", "", [O, E]),
    N is N0 + 1,
    read_json_file(E, JE), ( exists_file(O) -> read_json_file(O, JO) ; JO = _{} ),
    flat(JE, '', FE), flat(JO, '', FO),
    findall(K, ( member(K-V, FE), \+ memberchk(K-V, FO) ), Miss),
    findall(K, ( member(K-V, FO), \+ memberchk(K-V, FE) ), Extra),
    length(FE, NE), length(Miss, NM), Agree is NE - NM,
    append(Miss, Extra, Ds0), sort(Ds0, Ds),
    length(Ds, ND),
    ( Ds == [] -> S is S0 + 1 ; S = S0 ),
    A is A0 + Agree, D is D0 + ND,
    findall(F, ( member(K, Ds), field_name(K, F) ), Fs), sort(Fs, Fs1),
    append(Df0, Fs1, Df).

read_json_file(F, J) :- setup_call_cleanup(open(F, read, S, [encoding(utf8)]), json_read_dict(S, J), close(S)).

flat(D, P, Ps) :- is_dict(D), !,
    dict_pairs(D, _, KVs),
    findall(X, ( member(K-V, KVs), key_path(P, K, P1), flat(V, P1, Xs), member(X, Xs) ), Ps).
flat(L, P, Ps) :- is_list(L), !,
    findall(X, ( nth0(I, L, V), format(atom(P1), '~w[~w]', [P, I]), flat(V, P1, Xs), member(X, Xs) ), Ps).
flat(V, P, [P-V]).

key_path('', K, K) :- !.
key_path(P, K, P1) :- format(atom(P1), '~w.~w', [P, K]).

field_name(K, F) :- ( sub_atom(K, B, _, _, '[') -> sub_atom(K, 0, B, _, F) ; F = K ).

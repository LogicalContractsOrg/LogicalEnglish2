/*  The reach of the way back (the design notes rune.md §13, step 3), measured:
    for each twin, every rule of its main file written back as Rune
    (rune_writeback, mode `all`), the result run on DRR's engine
    (rune_runner) and compared with DRR's expected reports.

    ./myswipl.sh -q migration/rune/measure_back.pl -- [twin ...]     (all 28 by default)

    Appends one line per twin to runs/back.txt: the rules written back of
    those the main file holds, the reports exactly DRR's, the field values.
*/
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- use_module(rune_paths).
:- use_module(rune_writeback).
:- use_module(rune_runner).
:- use_module(le_to_rune).
:- use_module(library(main)).

:- initialization(main, main).

main(Argv) :-
    ( Argv == [] -> findall(T, report_pack(_, _, T), Ts) ; maplist([A, T]>>atom_string(T, A), Argv, Ts) ),
    ensure_rune_model,
    rune_home(H), ( getenv('RUNE_BACK_OUT', Out) -> true ; format(atom(Out), '~w/runs/back.txt', [H]) ),
    forall(member(T, Ts), catch(measure(T, Out), E, ( print_message(error, E), format("~w: ~q~n", [T, E]) ))).

measure(Twin, Out) :-
    report_pack(Report, Pack, Twin),
    twins_dir(TD), directory_file_path(TD, Twin, Dir),
    directory_file_path(Dir, Twin, F0), file_name_extension(F0, le, File),
    le_kbs:load(File, KB, [skip_tests]),
    twin_templates(Dir, KB),
    rune_writeback(Report, Twin, Dir, KB, all, written(Text, Lines)),
    aggregate_all(count, ( member(L, Lines), sub_atom(L, _, _, 0, 'written back') ), NW),
    aggregate_all(count, ( member(L, Lines), sub_atom(L, 0, _, _, 'not written back') ), NN),
    NAll is NW + NN,
    tmp_file(rune_back, W), make_directory_path(W),
    format(atom(RF), '~w/~w_all.rosetta', [W, Twin]),
    setup_call_cleanup(open(RF, write, S), write(S, Text), close(S)),
    atom_concat(RF, '.pairs.txt', PF), write_pairs(Pack, RF, PF),
    atom_concat(RF, '.expected.txt', EF),
    run_rune(RF, PF, EF, Res),
    result_line(Twin, NW, NAll, Res, Line),
    writeln(Line),
    ( Res = invalid(Is) -> true ; Is = [] ),
    setup_call_cleanup(open(Out, append, O),
        ( writeln(O, Line),
          forall(member(issue(_, IL, IM), Is), format(O, "    Rune's validator, line ~w: ~w~n", [IL, IM])),
          ( Res = ran(Sum), get_dict(fields, Sum, Fds) -> forall(( member(Fd, Fds), get_dict(reports, Fd, FR), get_dict(field, Fd, FF) ), format(O, "    differs in ~w reports: ~w~n", [FR, FF])) ; true ),
          forall(( member(L, Lines), sub_atom(L, 0, _, _, 'not written back') ), format(O, "    ~w~n", [L])) ),
        close(O)).

result_line(Twin, NW, NAll, ran(S), Line) :- !,
    format(string(Line), "~w: ~w of ~w rules of the main file written back; run on DRR's engine: ~w of ~w reports exactly DRR's own, ~w field values agree, ~w differ (~w)",
           [Twin, NW, NAll, S.same, S.reports, S.agree, S.differ, S.seconds]).
result_line(Twin, NW, NAll, invalid(Is), Line) :- !,
    length(Is, N), Is = [issue(_, L1, M1)|_],
    format(string(Line), "~w: ~w of ~w rules written back; Rune's validator refused the file (~w issues; first, line ~w: ~w)", [Twin, NW, NAll, N, L1, M1]).
result_line(Twin, NW, NAll, R, Line) :-
    format(string(Line), "~w: ~w of ~w rules written back; not run: ~q", [Twin, NW, NAll, R]).

/*  The command line of rune_writeback.pl. The way back for a whole report (the design notes rune.md §13, steps 2 and
    3): a twin, perhaps edited in Logical English, written as Rune that
    DRR's own tools compile and run.

    ./myswipl.sh -q migration/rune/rune_export.pl -- <twin dir> <program.le> <out.rosetta> [all]

    What it writes, in the namespace drr.lpsplus.<twin>:
    - each reporting rule of the report's own namespace whose LE rules
      changed since the twin was written (<twin>.fingerprints.pl), as Rune
      again (le_to_rune.pl), under its name with `LE` after it; with `all`,
      every rule of the twin's main file, changed or not (the measure of the
      way back's reach);
    - the report's type again, as a subtype (`<Type>LE extends <Type>`)
      that overrides each attribute holding a field whose rule was written
      back, with every rule reference under that attribute (`for` paths for
      the nested fields), as DRR attaches its rules. (A rule source cannot
      do it: Rune 9.95 resolves a `for` path on a type's attribute only, and
      a rule source loses a rule a field inherits through an `override`);
    - the report again, with that type: Rune's generator makes its report
      function, which DRR's Java runs (run_back.sh).
    Untouched rules are DRR's own, unchanged. A change it cannot write back
    (a function of a layer below, a field's own rule, a condition le_to_rune
    does not read) is a problem: it is listed, and nothing is written.

    Writes <out.rosetta>, <out>.pairs.txt (the test pack's instructions and
    where their reports go) and prints one line per rule, then `written` or
    `refused`.
*/
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- use_module(rune_paths).
:- use_module(rune_writeback).
:- use_module(le_to_rune).
:- use_module(library(main)).

:- initialization(main, main).

main([Dir, Program, Out|Opt]) :-
    ( Opt = [all|_] -> Mode = all ; Mode = changed ),
    file_base_name(Dir, Twin),
    (   report_pack(Report, Pack, Twin) -> true
    ;   format("refused: ~w is not the twin of one of DRR's reports~n", [Twin]), halt(1)
    ),
    took(ensure_rune_model, model),
    took(le_kbs:load(Program, KB, [skip_tests]), program),
    took(twin_templates(Dir, KB), templates),
    took(rune_writeback(Report, Twin, Dir, KB, Mode, Result), export),
    (   Result = written(Text, Lines)
    ->  setup_call_cleanup(open(Out, write, S), write(S, Text), close(S)),
        forall(member(L, Lines), format("~w~n", [L])),
        atom_concat(Out, '.pairs.txt', PF), write_pairs(Pack, Out, PF),
        format("written ~w~n", [Out])
    ;   Result = refused(Problems),
        forall(member(P, Problems), format("problem: ~w~n", [P])),
        format("refused~n"), halt(1)
    ).

took(G, What) :- get_time(T0), call(G), get_time(T1), T is T1 - T0, format(user_error, "~w: ~1fs~n", [What, T]).

took(G, What) :- get_time(T0), call(G), get_time(T1), T is T1 - T0, format(user_error, "~w: ~1fs~n", [What, T]).

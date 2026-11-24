/** <module> File ▸ Export to Another System ▸ Rune, for a twin of a DRR report

    The adapter LE2's le_import.pl calls (le_importers.pl registers it):
    the rules a user changed in the twin's main file are written back as
    Rune (rune_writeback.pl), and the Rune is run on DRR's own engine when
    this machine has it (rune_runner.pl): Rune's validator and generator,
    then DRR's Java on the report's test pack, every report compared with
    DRR's expected one.

    A problem is about a predicate whose change cannot be written back, so
    its place is predicate(F/A) (le_import.pl): a partial export leaves out
    that predicate's clauses, and every clause that uses one, and the rules
    it changed are DRR's own again (rune_writeback/8, original(KB0)). Each
    rule written back has a `//` comment with the lines it came from.
*/
:- module(rune_le_export, [export_rune/3, applies_rune/1, check_rune/3]).
:- use_module(le2(le_kbs)).
:- use_module(le2(le_writer)).
:- use_module(rune_paths).
:- use_module(rune_writeback).
:- use_module(rune_runner).
:- use_module(le_to_rune).

%!  applies_rune(+KB) is semidet.
%
%   A twin of one of DRR's reports: its main file, which includes the
%   twin's DRR layer.
applies_rune(KB) :-
    twin_of(KB, Twin, _),
    atom_concat(Twin, '_drr', Drr),
    catch(KB:le_resource_stats(R, _, _), _, fail), atom_string(R, RS), atom_string(Drr, RS), !,
    catch(rune_runner_start, _, true).  % (warm the runner while the user decides)

twin_of(KB, Twin, Report) :-
    le_writer:kb_to_ir(KB, program(H, _)), memberchk(kb(Twin), H),
    report_pack(Report, _, Twin).

%!  check_rune(+KB, +Options, -Problems) is det.
check_rune(KB, Options, Problems) :-
    (   writeback(KB, Options, refused(_), Placed)
    ->  Problems = Placed
    ;   Problems = []
    ).

%!  export_rune(+KB, +Options, -Result) is det.
export_rune(KB, Options, Result) :-
    writeback(KB, Options, R, Placed),
    (   R = refused(_)
    ->  Result = refused(Placed)
    ;   R = written(Text, Lines, Twin, Report),
        format(atom(File), '~w_from_le.rosetta', [Twin]),
        run_notes(Text, Twin, Report, RunNotes),
        (   Lines == []
        ->  N1 = "No rule was changed in Logical English: the file is DRR's report as it is, with its own type."
        ;   atomic_list_concat(Lines, '; ', LT),
            format(string(N1), "Written back from Logical English: ~w. Every other rule is DRR's own, untouched.", [LT])
        ),
        N2 = "The report's type is written again as a subtype that overrides only the fields whose rule changed (Rune attaches a rule to a field on its type).",
        append([N1, N2], RunNotes, Notes),
        Result = exported(File, Text, Notes,
                          [link("Rosetta Community edition (REGnosys, free, non-commercial): open a model and paste the file there", "https://ui.rosetta-technology.io")])
    ).

writeback(KB, Options, Result, Placed) :-
    twin_of(KB, Twin, Report),
    (   memberchk(base(Dir0), Options) -> absolute_file_name(Dir0, Dir) ; throw(error(rune_export("no folder for the program"), _)) ),
    ensure_rune_model,
    findall(text(Doc), ( memberchk(text(Doc), Options), ( string(Doc) ; atom(Doc) ) ), WOs0),
    (   partial_original(Options, Dir0, KB0) -> WOs = [original(KB0)|WOs0] ; WOs = WOs0 ),
    with_mutex(rune_writeback,
      ( twin_templates(Dir, KB),
        rune_writeback(Report, Twin, Dir, KB, changed, WOs, R0, Placed) )),
    (   R0 = written(Text, Lines) -> Result = written(Text, Lines, Twin, Report) ; Result = R0 ).

%   In a partial export (partial(Residues) in Options, a list: the reader's
%   request is partial(true)), the program as it was: le_kbs caches the
%   module of a text, so this is the one export_kb/4 was given.
partial_original(Options, Base, KB0) :-
    member(partial(Rs), Options), is_list(Rs), Rs \== [], !,
    memberchk(text(Doc), Options),
    le_kbs:load_text(Doc, Base, KB0).

%   Run it on DRR's engine, when this machine has it.
run_notes(Text, Twin, Report, Notes) :-
    (   rune_runner_available
    ->  report_pack(Report, Pack, Twin),
        tmp_file(rune_export, W), make_directory_path(W),
        format(atom(RF), '~w/~w_from_le.rosetta', [W, Twin]),
        setup_call_cleanup(open(RF, write, S), write(S, Text), close(S)),
        atom_concat(RF, '.pairs.txt', PF), write_pairs(Pack, RF, PF),
        atom_concat(RF, '.expected.txt', EF),
        catch(run_rune(RF, PF, EF, Res), E, ( message_to_codes(E, [], Cs) -> string_codes(ES, Cs), Res = not_run(ES) ; Res = not_run("the runner failed") )),
        result_notes(Res, Report, Notes)
    ;   Notes = ["To run it: LE2 migration/rune/run_back.sh <file> on a machine with Java and DRR's files (fetch_sources.sh), or in Rosetta."]
    ).

result_notes(ran(S), Report, [N|Fs]) :-
    format(string(N), "Run on DRR's own engine: Rune's validator accepted the file, Rune's generator made ~w, and DRR's Java computed the report of each of the ~w instructions of DRR's test pack for ~w (~w). ~w of the ~w reports are exactly DRR's own; ~w field values agree, ~w differ.",
           [S.function, S.reports, Report, S.seconds, S.same, S.reports, S.agree, S.differ]),
    findall(F, ( member(D, S.fields), D = _{field: Fd, reports: C}, format(string(F), "The field ~w differs from DRR's report in ~w instructions.", [Fd, C]) ), Fs0),
    ( length(Fs0, L), L > 8 -> length(Fs, 8), append(Fs, _, Fs0) ; Fs = Fs0 ).
result_notes(invalid(Is), _, [N|Ms]) :-
    N = "Rune's validator refused the file:",
    findall(M, ( member(issue(Sev, Line, Msg), Is), format(string(M), "~w at line ~w: ~w", [Sev, Line, Msg]) ), Ms).
result_notes(not_run(Why), _, [N]) :-
    format(string(N), "Not run on DRR's engine: ~w", [Why]).
result_notes(Other, _, [N]) :-
    format(string(N), "Not run on DRR's engine: ~q", [Other]).

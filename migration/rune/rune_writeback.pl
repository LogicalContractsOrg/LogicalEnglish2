:- module(rune_writeback, [
    rune_writeback/6,       % +Report, +Twin, +Dir, +KB, +Mode, -Result
    rune_writeback/8,       % +Report, +Twin, +Dir, +KB, +Mode, +Options, -Result, -Placed
    write_pairs/3,          % +Pack, +RuneFile, +PairsFile
    ensure_rune_model/0     % DRR's model loaded, once per process
]).
/*  The way back for a whole report (the design notes rune.md §13, steps 2 and
    3): a twin, perhaps edited in Logical English, written as Rune that
    DRR's own tools compile and run.

    ./myswipl.sh -q migration/rune/rune_export.pl   (the command line; this module is its logic) -- <twin dir> <program.le> <out.rosetta> [all]

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

    Each rule written back has a comment above it with the lines of the
    Logical English rules it came from (`// Logical English lines 74, 80`),
    when the program's text is given (rune_writeback/8, text(Doc)).

    A partial export (File ▸ Export, "Write anyway": le_import.pl leaves out
    the clauses of a refused program, and every clause that uses one) is a
    Rune file in which each rule the export had to leave out, or that lost a
    clause with it, is DRR's own again: a predicate the partial export
    changed is not written back (original(KB0), the program as it was).
    Writing back a rule that lost one of its clauses would state something
    the program never said.
*/
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- use_module(parser/rune_reader).
:- use_module(rune_paths).
:- use_module(rune_closure).
:- use_module(rune_twin).
:- use_module(rune_data, [type_feature/3]).
:- use_module(rune_fingerprint).
:- use_module(le_to_rune).

%!  ensure_rune_model is det.
%
%   DRR 7.14.0's model in rune_model, read once per process (about ten
%   seconds, about 90 MB).
:- dynamic model_loaded/0.
ensure_rune_model :-
    (   model_loaded -> true
    ;   with_mutex(rune_model_load, ( model_loaded -> true ; json_dir(JD), load_rune_model(JD), assertz(model_loaded) ))
    ).

%!  rune_writeback(+Report, +Twin, +Dir, +KB, +Mode, -Result) is det.
%
%   Result is written(RuneText, ReportLines) or refused(Problems).
rune_writeback(Report, Twin, Dir, KB, Mode, Result) :-
    rune_writeback(Report, Twin, Dir, KB, Mode, [], Result, _).

%!  rune_writeback(+Report, +Twin, +Dir, +KB, +Mode, +Options, -Result, -Placed) is det.
%
%   As rune_writeback/6. Placed is each problem with the predicate it is
%   about, problem(predicate(F/A), Message) (le_import.pl's places).
%   Options: text(Doc), the program's text (the lines of the comments);
%   original(KB0), the program before a partial export left clauses out.
rune_writeback(Report, Twin, Dir, KB, Mode, Options, Result, Placed) :-
    directory_file_path(Dir, Twin, F0), atom_concat(F0, '.fingerprints.pl', FP),
    read_fingerprints(FP, Old),
    own_functors(KB, Fs),
    kb_fingerprints(KB, Fs, New),
    (   memberchk(original(KB0), Options)
    ->  kb_fingerprints(KB0, Fs, Orig)
    ;   Orig = New
    ),
    findall(F/A, ( member(F/A-H, New), ( Mode == all -> true ; \+ memberchk(F/A-H, Old) ),
                   memberchk(F/A-H, Orig) ), Changed),     % (a partial export's change is not the user's)
    rune_model:rune_report(Report, _, _, _, _, RT), rune_twin:q_namespace(RT, RNS),
    foldl(write_back(KB, RNS, Mode), Changed, []-[], Rules-Problems0),
    reverse(Problems0, ProblemPairs),
    pairs_values(ProblemPairs, Problems),
    findall(problem(predicate(PI), M), ( member(PI-P, ProblemPairs), format(string(M), "~w", [P]) ), Placed),
    (   Problems \== [], Mode == changed
    ->  Result = refused(Problems)
    ;   reverse(Rules, Rules1),
        (   memberchk(text(Doc), Options), ( string(Doc) ; atom(Doc) )
        ->  findall(Q-Ls, ( member(rule(Q, _, _), Rules1), rule_functor(Q, F), rule_lines(KB, F, Doc, Ls) ), Sources)
        ;   Sources = []
        ),
        b_setval(rune_writeback_sources, Sources),
        rune_text(Report, Twin, RNS, Rules1, Text),
        findall(L, ( member(rule(Q, _, _), Rules1), format(atom(L), "rule ~w: written back", [Q]) ), Ls1),
        findall(L, ( member(P, Problems), format(atom(L), "not written back: ~w", [P]) ), Ls2),
        append(Ls1, Ls2, Lines),
        Result = written(Text, Lines)
    ).

%   A changed predicate: a reporting rule of the report's namespace is
%   written back; anything else is a problem.
write_back(KB, RNS, Mode, F/A, Rs0-Ps0, Rs-Ps) :-
    (   rule_functor(Q, F), rune_twin:q_namespace(Q, RNS)
    ->  catch(( rule_expression(KB, F, Q, E) -> R = ok(E) ; R = failed ), cannot_read(Why), R = cannot(Why)),
        (   R = ok(E)
        ->  rune_twin:short(Q, Short), atom_concat(Short, 'LE', New),
            Rs = [rule(Q, New, E)|Rs0], Ps = Ps0
        ;   ( R = cannot(W) -> le_to_rune:strip_all(W, W1), term_string(W1, WS) ; WS = "no rule" ),
            format(atom(P), "~w: a condition the way back does not read yet: ~w", [Q, WS]),
            Rs = Rs0, Ps = [F/A-P|Ps0]
        )
    ;   rule_functor(Q, F)
    ->  (   Mode == all -> Ps = Ps0
        ;   format(atom(P), "~w: a rule of another namespace (~w); the way back writes the report's own rules", [Q, F]), Ps = [F/A-P|Ps0]
        ),
        Rs = Rs0
    ;   ( F == report_field ; sub_atom(F, _, _, _, '_field_of_is') )
    ->  (   Mode == all -> Ps = Ps0
        ;   format(atom(P), "a field's own rule (~w) changed: change the rule it reads instead", [F]), Ps = [F/A-P|Ps0]
        ),
        Rs = Rs0
    ;   (   Mode == all -> Ps = Ps0
        ;   format(atom(P), "~w is not a reporting rule of the report: the way back writes reporting rules", [F]), Ps = [F/A-P|Ps0]
        ),
        Rs = Rs0
    ).

% ---------------------------------------------------------------- the Rune text

rune_text(Report, Twin, RNS, Rules, Text) :-
    rune_model:rune_report(Report, Body, Corpora, In, Elig, RT),
    rune_reader:loaded_dict(RNS, D),
    ( get_dict(imports, D, Is0) -> true ; Is0 = [] ),
    sort([RNS|Is0], Is),
    format(atom(NS), 'drr.lpsplus.~w', [Twin]),
    report_fields(Report, Fields),
    findall(Top-Rest-Q, ( member(field([Top|Rest], Ref, _), Fields), rune_twin:field_rule_q(Ref, Q) ), TRQs),
    %  the attributes of the report type that hold a field whose rule was
    %  written back: overridden, with every rule reference under them
    findall(Top, ( member(Top-_-Q, TRQs), memberchk(rule(Q, _, _), Rules) ), Tops0), sort(Tops0, Tops),
    rune_twin:short(RT, RTS), atom_concat(RTS, 'LE', NewType),
    with_output_to(string(Text),
      ( format("namespace ~w~nversion \"0.1\"~n~n", [NS]),
        forall(member(I, Is), format("import ~w.*~n", [I])),
        format("~n// Written by LE2 migration/rune/rune_export.pl from the Logical English twin ~w:~n", [Twin]),
        format("// the rules changed in Logical English, the report's type with the fields that use~n// them, and the report with that type. Every other rule is DRR's own.~n~n"),
        forall(member(rule(Q, New, E), Rules),
               ( rule_label(Q, Label),
                 %  the rule's own input (a field under a repeated part of
                 %  the report reads that part: `from TransferState`)
                 ( rune_model:rune_rule(_, Q, RIn, _, _, _), atom(RIn) -> true ; RIn = In ),
                 rule_comment(Q),
                 format("reporting rule ~w from ~w: <\"~w\">~n    ~w~n~n", [New, RIn, Label, E]) )),
        format("type ~w extends ~w:~n", [NewType, RT]),
        forall(member(Top, Tops),
               ( rune_data:type_feature(RT, Top, feature(AT, card(Min, Max), _)),
                 ( Max == inf -> MaxT = '*' ; MaxT = Max ),
                 format("    override ~w ~w (~w..~w)~n", [Top, AT, Min, MaxT]),
                 forall(member(Top-Rest-Q, TRQs), ( field_reference(Rest, Q, Rules, L), format("        ~w~n", [L]) )) )),
        ( Tops == [] -> format("    // no field's rule was changed: DRR's own report~n") ; true ),
        atomic_list_concat([Body|Corpora], ' ', Reg),
        atomic_list_concat(Elig, ' and ', EligT),
        format("~nreport ~w in T+1~n    from ~w~n    when ~w~n    with type ~w~n", [Reg, In, EligT, NewType]) )).

%   The Logical English lines a rule written back came from, as a Rune
%   comment (le_import.pl, "Provenance").
rule_comment(Q) :-
    (   nb_current(rune_writeback_sources, Ss), memberchk(Q-Ls, Ss), Ls \== []
    ->  (   Ls = [L] -> format("// Logical English line ~w~n", [L])
        ;   atomic_list_concat(Ls, ', ', LT), format("// Logical English lines ~w~n", [LT])
        )
    ;   true
    ).

%   The lines of the program's own clauses of F (not those of a resource it
%   includes, whose positions are in a range of their own).
rule_lines(KB, F, Doc, Ls) :-
    string_length(Doc, Len),
    findall(L, ( current_predicate(KB:F/A), functor(H, F, A),
                 catch(clause(KB:H, _, Ref), _, fail),
                 catch(KB:le_source_info(Ref, S, _, _), _, fail), integer(S), S < Len,
                 sub_string(Doc, 0, S, _, Before), split_string(Before, "\n", "", Parts), length(Parts, L) ), Ls0),
    sort(Ls0, Ls).

%   A field's rule reference: the rule written back, or DRR's.
field_reference(Rest, Q, Rules, Line) :-
    ( memberchk(rule(Q, New, _), Rules) -> R = New ; R = Q ),
    (   Rest == [] -> format(atom(Line), "[ruleReference ~w]", [R])
    ;   atomic_list_concat(Rest, ' -> ', P), format(atom(Line), "[ruleReference for ~w ~w]", [P, R])
    ).

rule_label(Q, Label) :-
    (   rune_model:rune_rule(_, Q, _, _, _, Doc), ( string(Doc) ; atom(Doc) ), Doc \== '', Doc \== ""
    ->  Label = Doc
    ;   rune_twin:short(Q, Label)
    ).

% ---------------------------------------------------------------- the test pack

%   The instructions of the report's test pack, and where the report of each
%   goes (beside the Rune file): DrrOracle's input.
write_pairs(Pack, Out, PF) :-
    test_pack_pairs(Pack, Pairs),
    atom_concat(Out, '.out', OD),
    atom_concat(Out, '.expected.txt', EF),
    setup_call_cleanup(( open(PF, write, S), open(EF, write, SE) ),
        forall(member(pair(Name, In, Exp), Pairs),
               ( format(atom(O), '~w/~w.json', [OD, Name]),
                 format(S, "~w\t~w~n", [In, O]), format(SE, "~w\t~w~n", [O, Exp]) )),
        ( close(S), close(SE) )).

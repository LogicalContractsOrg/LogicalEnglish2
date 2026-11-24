/*  Step 1 of the design notes rune.md: a report's fields, checked against
    DRR's generated Java, and the closure of what computes them.

    ./myswipl.sh -q migration/rune/measure.pl                  # CFTC Part45
    ./myswipl.sh -q migration/rune/measure.pl -- 'ESMA EMIR Trade'

    Writes runs/closure_<report>.txt.
*/
:- use_module(parser/rune_reader).
:- use_module(rune_closure).
:- use_module(rune_paths).
:- use_module(library(main)).
:- use_module(library(process)).

:- initialization(main, main).

%   The report function of DRR's Java, for the field check.
report_function('CFTC Part45', 'drr/regulation/cftc/rewrite/trade/reports/CFTCPart45ReportFunction.java').
report_function('ESMA EMIR Trade', 'drr/regulation/esma/emir/refit/trade/reports/ESMAEMIRTradeReportFunction.java').
report_function('FCA UKEMIR Trade', 'drr/regulation/fca/ukemir/refit/trade/reports/FCAUKEMIRTradeReportFunction.java').
report_function('CFTC Margin', 'drr/regulation/cftc/rewrite/margin/reports/CFTCMarginReportFunction.java').

main(Argv) :-
    ( Argv = [R|_] -> true ; R = 'CFTC Part45' ),
    json_dir(JD), load_rune_model(JD),
    report_fields(R, Fs), length(Fs, NF),
    findall(P-Q, ( member(field(Path, Ref, _), Fs), atomic_list_concat(Path, '.', P),
                   ( field_rule_q(Ref, Q) -> true ; Q = unresolved(Ref) ) ), Mine),
    java_check(R, Mine, Check),
    report_closure(R, closure(Rs, Fns, As, Es, Us)),
    maplist(length, [Rs, Fns, As, Es], [NR, NFn, NA, NE]),
    findall(A, member(_-A, As), An0), sort(An0, An), length(An, NAN),
    findall(T, member(T-_, As), Ts0), sort(Ts0, Ts), length(Ts, NT),
    findall(F, ( member(F, Fns), rune_model:rune_func(F, _, _, _, _, Ann, _),
                 get_dict(codeImplementation, Ann, _) ), CI),
    length(CI, NCI),
    format(atom(Name), 'closure_~w.txt', [R]), atomic_list_concat(NP, ' ', Name),
    atomic_list_concat(NP, '_', File),
    rune_home(H), directory_file_path(H, runs, RD), make_directory_path(RD),
    directory_file_path(RD, File, Out),
    with_output_to(string(Text),
        ( format("~w: ~w fields~n", [R, NF]),
          print_check(Check),
          format("closure: ~w rules, ~w functions (~w implemented in Java), ~w attributes (~w names, on ~w types), ~w enumerations, ~w names unresolved~n",
                 [NR, NFn, NCI, NA, NAN, NT, NE, Us]),
          format("functions implemented in Java: ~w~n", [CI]),
          format("~nfields:~n"),
          forall(member(P-Q, Mine), format("  ~w  ~w~n", [P, Q])) )),
    setup_call_cleanup(open(Out, write, S), write(S, Text), close(S)),
    once(sub_string(Text, B, _, _, "\nfields:")), sub_string(Text, 0, B, _, Head),
    format("~s~n(~w)~n", [Head, Out]).

java_check(R, Mine, check(Agree, Diff)) :-
    report_function(R, JF), !,
    drr_dir(D), atom_concat(D, '-java/', JD0), atom_concat(JD0, JF, Java),
    rune_home(H), directory_file_path(H, 'java_fields.py', Py),
    process_create(path(python3), [Py, Java], [stdout(pipe(Out))]),
    read_string(Out, _, S), close(Out),
    split_string(S, "\n", "", Ls),
    findall(P-Q, ( member(L, Ls), L \== "", split_string(L, "\t", "", [P0, Q0]),
                   atom_string(P, P0), atom_string(Q, Q0),
                   \+ sub_atom(P, 0, _, _, nonReportable) ), Java0),
    findall(P-Q, ( member(P-Q, Mine), memberchk(P-Q, Java0) ), Agree),
    findall(d(P, java(QJ), mine(QM)),
            ( member(P-QM, Mine), \+ memberchk(P-QM, Java0), ( memberchk(P-QJ, Java0) -> true ; QJ = null ) ), D1),
    findall(d(P, java(QJ), mine(none)), ( member(P-QJ, Java0), \+ memberchk(P-_, Mine) ), D2),
    append(D1, D2, Diff).
java_check(_, _, none).

print_check(none) :- format("fields: not checked against the Java~n").
print_check(check(A, D)) :-
    length(A, NA), length(D, ND),
    format("fields checked against DRR's generated Java: ~w agree, ~w differ~n", [NA, ND]),
    forall(member(X, D), format("  differs: ~w~n", [X])).

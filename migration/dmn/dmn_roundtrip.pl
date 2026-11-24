/*  The way back, checked: each twin written as DMN (dmn_export.pl) and its
    scenarios, written as the model's TCK test cases, run by the TCK's
    runner on Apache KIE Drools 10.2 (oracle/, command `tck`).

        swipl -q migration/dmn/dmn_roundtrip.pl [-- tck bdt ronl clients | twin.le ...]

    Without arguments, the twins of LE2's examples/migration/dmn/ (the
    collections tck, ronl, bdt and clients) and the hand-written programs
    of examples/regulatory/dmn_export/. The exported models and their test
    files go to .cache/roundtrip/compliance-level-2/<twin>/, the layout the
    runner reads. A test case passes when Drools evaluates every result
    node of it to the value the scenario expects. Results, one line per
    program and the totals, in runs/roundtrip.txt.
*/

:- initialization(main_entry, main).
main_entry :- current_prolog_flag(argv, A), catch_with_backtrace(main(A), E, (print_message(error, E), halt(1))).

:- use_module(dmn_home).
:- use_module(library(main)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(http/json)).
:- use_module(library(aggregate)).
:- use_module('../le2_paths').
:- use_module(le2(le_kbs)).
:- use_module(dmn_export).

gen_dir(D) :- dmn_path('.cache/roundtrip', D).

main(Argv) :-
    programs(Argv, Fs),
    gen_dir(G), ( exists_directory(G) -> delete_directory_and_contents(G) ; true ),
    atomic_list_concat([G, '/compliance-level-2'], Root), make_directory_path(Root),
    findall(R, ( member(F, Fs), export_one(Root, F, R) ), Rs),
    run_tck(G, Cases),
    findall(Line, ( member(R, Rs), result_line(R, Cases, Line) ), Lines),
    totals(Rs, Cases, Total),
    dmn_path('runs/roundtrip.txt', Out),
    setup_call_cleanup(open(Out, write, S),
                       ( forall(member(L, Lines), format(S, "~w~n", [L])), format(S, "~w~n", [Total]) ),
                       close(S)),
    forall(member(L, Lines), format("~w~n", [L])),
    format("~w~n", [Total]).

programs([], Fs) :- !,
    twins_dir(dmn, D),
    findall(F, ( member(C, [tck, ronl, bdt, clients]), atomic_list_concat([D, '/', C], CD),
                 twin_files(CD, F) ), Fs1),
    le2_dir(LE2), atomic_list_concat([LE2, '/examples/regulatory/dmn_export'], HD),
    ( exists_directory(HD) -> findall(F, directory_member(HD, F, [extensions([le])]), Fs20), sort(Fs20, Fs2) ; Fs2 = [] ),
    append(Fs1, Fs2, Fs).
programs(Argv, Fs) :-
    twins_dir(dmn, D),
    findall(F, ( member(A, Argv),
                 (   sub_atom(A, _, _, 0, '.le') -> F = A
                 ;   atomic_list_concat([D, '/', A], CD), twin_files(CD, F)
                 ) ), Fs).

twin_files(Dir, F) :-
    exists_directory(Dir),
    findall(X, ( directory_member(Dir, X, [recursive(true), extensions([le])]),
                 \+ sub_atom(X, _, _, _, '/sources/'),
                 file_base_name(X, B), file_name_extension(Stem, _, B),
                 file_directory_name(X, XD), file_base_name(XD, Stem) ), Xs0),
    sort(Xs0, Xs), member(F, Xs).

%   r(Stem, exported(NCases) | refused(Problems) | failed(Why))
export_one(Root, File, r(Stem, What)) :-
    file_base_name(File, B), file_name_extension(Stem, _, B),
    (   catch(le_kbs:load(File, KB), E, ( message_text(E, M), What = failed(M), fail ))
    ->  %  with the program's text, as File > Export gives it: the model then
        %  carries its provenance (the lines), and Drools reads that too
        read_file_to_string(File, Doc, [encoding(utf8)]),
        (   catch(dmn_files(KB, Stem, [text(Doc)], DMN, Tests), Err, true)
        ->  (   nonvar(Err)
            ->  ( Err = error(dmn_export_refused(Ps), _) -> What = refused(Ps) ; message_text(Err, M2), What = failed(M2) )
            ;   atomic_list_concat([Root, '/', Stem], MD), make_directory_path(MD),
                atomic_list_concat([MD, '/', Stem, '.dmn'], DF), write_text(DF, DMN),
                count_cases(Tests, N),
                (   N > 0
                ->  atomic_list_concat([MD, '/', Stem, '-test-01.xml'], TF), write_text(TF, Tests)
                ;   true
                ),
                What = exported(N)
            )
        ;   What = failed("the exporter failed")
        )
    ;   ( var(What) -> What = failed("the program does not load") ; true )
    ).

message_text(E, S) :- catch(message_to_codes(E, S), _, format(string(S), "~q", [E])).
message_to_codes(E, S) :- format(string(S), "~q", [E]).

write_text(F, T) :- setup_call_cleanup(open(F, write, S, [encoding(utf8)]), write(S, T), close(S)).

count_cases(Tests, N) :-
    atomic_list_concat(Parts, '<testCase ', Tests), length(Parts, L), N is L - 1.

run_tck(G, Cases) :-
    atomic_list_concat([G, '/tck-results.json'], Out),
    dmn_path('oracle/target/dmn-oracle.jar', OracleJar),
    process_create(path(java), ['-Xmx2g', '-jar', OracleJar, tck, G, '--out', Out],
                   [stdout(null), stderr(null), process(P)]),
    process_wait(P, _),
    (   exists_file(Out)
    ->  setup_call_cleanup(open(Out, read, In), json_read_dict(In, D, [value_string_as(string)]), close(In)),
        ( get_dict(cases, D, Cases) -> true ; Cases = [] )
    ;   Cases = []
    ).

model_cases(Stem, Cases, Mine) :-
    atom_string(Stem, SS),
    include(case_of(SS), Cases, Mine).

case_of(SS, C) :- get_dict(folder, C, F), ( F == SS ; string_concat("/", SS, Tail), sub_string(F, _, _, 0, Tail) ), !.

result_line(r(Stem, exported(N)), Cases, Line) :- !,
    model_cases(Stem, Cases, Mine),
    count_status(Mine, P, F, E),
    (   N =:= 0 -> format(string(Line), "~w: exported, no test cases (the program has no scenario that expects an answer of a decision)", [Stem])
    ;   findall(Fx, ( member(C, Mine), \+ get_dict(status, C, "pass"), case_failure(C, Fx) ), Fxs0), first_n(3, Fxs0, Fxs),
        format(string(Line), "~w: ~d pass, ~d fail, ~d error of ~d~@", [Stem, P, F, E, N, failures_text(Fxs)])
    ).
result_line(r(Stem, refused(Ps)), _, Line) :- !,
    findall(M, member(problem(_, M), Ps), Ms0), sort(Ms0, Ms), first_n(2, Ms, M2),
    atomic_list_concat(M2, '; ', MT),
    format(string(Line), "~w: refused: ~w", [Stem, MT]).
result_line(r(Stem, failed(M)), _, Line) :-
    format(string(Line), "~w: not exported: ~w", [Stem, M]).

failures_text([]) :- !.
failures_text(Fs) :- forall(member(F, Fs), format("~n    ~w", [F])).

case_failure(C, S) :-
    ( get_dict(failures, C, Fs) -> true ; Fs = [] ),
    format(string(S), "~w: ~w ~q", [C.id, C.status, Fs]).

first_n(N, L, F) :- length(L, LL), ( LL =< N -> F = L ; length(F, N), append(F, _, L) ).

count_status(Cs, P, F, E) :-
    aggregate_all(count, ( member(C, Cs), get_dict(status, C, "pass") ), P),
    aggregate_all(count, ( member(C, Cs), get_dict(status, C, "fail") ), F),
    aggregate_all(count, ( member(C, Cs), get_dict(status, C, "error") ), E).

totals(Rs, Cases, Line) :-
    length(Rs, NP),
    aggregate_all(count, member(r(_, exported(_)), Rs), NE),
    aggregate_all(count, member(r(_, refused(_)), Rs), NR),
    aggregate_all(sum(N), member(r(_, exported(N)), Rs), NT),
    count_status(Cases, P, F, E), NN is NP - NE - NR,
    format(string(Line), "TOTAL: ~d programs: ~d exported, ~d refused, ~d not exported; ~d test cases: ~d pass, ~d fail, ~d error (Drools 10.2, the TCK runner)",
           [NP, NE, NR, NN, NT, P, F, E]).

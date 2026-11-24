/** <module> The contract twins of the L4 corpus, built and checked

    Step 3 of the design notes l4.md. For each corpus file with a `#TRACE`:

      1. The expressions of its traces that only L4's evaluator can work out
         (a date, a computed amount) are evaluated by it (`#EVAL`s appended
         to the file), cached in runs/contracts/<Id>.values.json.
      2. l4_contracts.pl writes the file's contracts as LE for LPS, one
         scenario per trace, into LPS2's examples/migration/l4/<Id>/, with
         the source in sources/.
      3. Each scenario is run by LPS2 (`lps state --scenario trace_<line>`)
         and its final state compared with L4's result for the trace
         (runs/<Id>.json): fulfilled, the breach (who, why, which deadline),
         or the obligations still open. An open obligation's deadline is
         checked by asking L4 again: the same trace, then the clock read on
         the twin's deadline (the obligation must still be open) and just
         after it (it must not). Those probes are cached in
         runs/contracts/<Id>.probes.json.

    Results: runs/contracts/gate.txt.

        ./myswipl.sh -q -g "consult('migration/l4/l4_contracts_build.pl')" -g "l4cb:main" -t halt
*/

:- module(l4cb, [main/0, build/2, check/3, contract_ids/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(yall)).
:- use_module(library(readutil)).
:- use_module(library(process)).
:- use_module(library(filesex)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(sha)).
:- use_module(l4_reader).
:- use_module(l4_contracts).
:- use_module(corpus).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).
:- use_module(l4_history).

:- dynamic lps_final/3.     % Id, Line, State

here(D) :- module_property(l4cb, file(F)), file_directory_name(F, D).

%!  contract_ids(-Ids) is det.
%   The corpus files with a #TRACE.
contract_ids(Ids) :-
    findall(Id, ( corpus_file(Id, _, _), \+ l4_corpus:unpublished(Id), corpus_path(Id, P), exists_file(P),
                  l4_read_file(P, l4_module(Items, _)),
                  memberchk(directive(trace(_, _, _), _, _), Items) ), Ids).

twins_root(D) :- le2_paths:lps2_dir(L), atomic_list_concat([L, '/examples/migration/l4'], D).

%   A twin's name: the L4 file's, as the rules half names it (l4_twin.pl,
%   twin_name/2), so a file's twins sit in directories of one name in LE2
%   (rules, history view) and LPS2 (contracts).
twin_name(Id, Name) :-
    corpus_file(Id, Rel, _),
    file_base_name(Rel, B), file_name_extension(S, _, B),
    atom_codes(S, Cs), maplist([C, D]>>( code_type(C, alnum) -> D = C ; D = 0'_ ), Cs, Ds),
    atom_codes(N0, Ds), downcase_atom(N0, Name).

main :-
    contract_ids(Ids),
    here(H), atomic_list_concat([H, '/runs/contracts'], RD), make_directory_path(RD),
    maplist([Id, R]>>( format(user_error, "~w ...~n", [Id]), catch(build_and_check(Id, R), E, ( print_message(error, E), R = error(Id, E) )) ), Ids, Rs),
    atomic_list_concat([RD, '/gate.txt'], G),
    setup_call_cleanup(open(G, write, S), report(S, Rs), close(S)),
    report(user_output, Rs).

build_and_check(Id, result(Id, Checks, History)) :-
    build(Id, Twin),
    check(Id, Twin, Checks),
    catch(build_history(Id, Twin, Checks, History), E, ( print_message(error, E), History = error(E) )).

		 /*******************************
		 *            BUILD             *
		 *******************************/

%!  build(+Id, -TwinInfo) is det.
build(Id, info(Id, File, Twin)) :-
    corpus_path(Id, Src),
    corpus_file(Id, Rel, _),
    file_base_name(Rel, Base),
    oracle_values(Id, Src, VPs),
    twin_name(Id, Name),
    contract_twin(Src, [id(Name), title(Title), values(VPs)], Twin),
    Title = Base,
    results(Id, Results),
    Twin = twin(_, _, items(Voc, _, _, _, _, _), _, _),
    findall(I, ( member(V, Voc), decl_ir_(V, I) ), VocIR),
    ir_dicts(program([target(lps)], VocIR), Dicts),
    b_setval(l4_dicts, Dicts),
    twin_migration(Twin, [source(Base), results(Results)], Mig),
    twins_root(Root), atomic_list_concat([Root, '/', Name], Dir),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
    atomic_list_concat([SD, '/', Base], Copy), copy_file(Src, Copy),
    notice(SD, Rel),
    write_migration(Mig, Dir, Name, report(File, Issues, _, _)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs),
    ( Errs == [] -> true ; format(user_error, "  writer errors: ~q~n", [Errs]) ).

decl_ir_(event(F, T, _), event(F, T, [known_as(F)])).
decl_ir_(fluent(F, T, _), fluent(F, T, [known_as(F)])).
decl_ir_(template(F, T, _), template(F, T, [known_as(F)])).
decl_ir_(function(F, T), function(F, T, [known_as(F)])).

notice(SD, Rel) :-
    corpus_commit(C),
    atomic_list_concat([SD, '/NOTICE.txt'], N),
    setup_call_cleanup(open(N, write, S),
        format(S, "The L4 source here is `~w` of the repository smucclaw/l4-ide at commit ~w,~nCopyright 2025 Singapore Management University, licensed under the Apache License,~nVersion 2.0 (LICENSE). It is unmodified.~n", [Rel, C]),
        close(S)),
    cache_dir(CD), atomic_list_concat([CD, '/LICENSE'], L),
    atomic_list_concat([SD, '/LICENSE'], L1),
    ( exists_file(L) -> copy_file(L, L1) ; true ).

%   L4's result for each trace of the file: Line-Text.
results(Id, Results) :-
    here(H), atomic_list_concat([H, '/runs/', Id, '.json'], F),
    (   exists_file(F)
    ->  read_json(F, J),
        findall(L-T, ( member(R, J.results), L = R.start.line, result_text(R, T) ), Results)
    ;   Results = []
    ).

result_text(R, T) :- ( string(R.result) -> T = R.result ; R.error \== null -> format(string(T), "error: ~w", [R.error]) ; T = "" ).

read_json(F, J) :- setup_call_cleanup(open(F, read, S, [encoding(utf8)]), json_read_dict(S, J), close(S)).

		 /*******************************
		 *    WHAT L4 WORKS OUT FOR US  *
		 *******************************/

%   The trace expressions only L4's evaluator can work out: #EVAL each,
%   appended to the file; cached by the text evaluated.
oracle_values(Id, Src, VPs) :-
    trace_oracle_needs(Src, Texts),
    (   Texts == [] -> VPs = []
    ;   read_file_to_string(Src, Text0, [encoding(utf8)]),
        findall(E, ( member(T, Texts), format(string(E), "#EVAL ~w", [T]) ), Evals),
        atomic_list_concat(Evals, '\n', EvalText),
        format(string(Probe), "~w~n~n~w~n", [Text0, EvalText]),
        split_string(Text0, "\n", "", Ls), length(Ls, N0),
        oracle_cached(Id, values, Probe, J),
        findall(T-P, ( nth1(I, Texts, T), Line is N0 + 1 + I, member(R, J.results), R.start.line =:= Line, string(R.result), P = R.result ), VPs)
    ).

%   The evaluator on a text, cached under runs/contracts/<Id>.<Kind>.json
%   keyed by the text's hash.
oracle_cached(Id, Kind, Text, J) :-
    here(H),
    atomic_list_concat([H, '/runs/contracts'], RD), make_directory_path(RD),
    atomic_list_concat([H, '/runs/contracts/', Id, '.', Kind, '.json'], CF),
    sha_hash(Text, Hash0, []), hash_atom(Hash0, Hash),
    (   exists_file(CF), read_json(CF, C), get_dict(Hash, C, J0) -> J = J0
    ;   tmp_file_stream(text, TF, S), write(S, Text), close(S),
        atomic_list_concat([H, '/l4_oracle.mjs'], O),
        process_create(path(node), [O, eval, TF], [stdout(pipe(Out)), stderr(null)]),
        read_string(Out, _, JS), close(Out), delete_file(TF),
        atom_json_dict(JS, J, []),
        ( exists_file(CF), read_json(CF, C0) -> true ; C0 = _{} ),
        put_dict(Hash, C0, J, C1),
        setup_call_cleanup(open(CF, write, W), json_write_dict(W, C1, [width(0)]), close(W))
    ).

		 /*******************************
		 *            CHECK             *
		 *******************************/

%!  check(+Id, +Info, -Checks) is det.
%   Checks: check(Line, Verdict, Detail) per trace; Verdict pass, fail or
%   pending (a trace not translated).
check(Id, info(Id, File, Twin), Checks) :-
    Twin = twin(_, _, items(Voc, _, _, _, _, _), Traces, _),
    findall(F-T, member(fluent(F, T, _), Voc), FTs),
    b_setval(l4_dicts_state, FTs),
    results(Id, Results),
    corpus_path(Id, Src),
    findall(C, ( member(T, Traces), check_trace(Id, Src, File, Twin, Results, T, C) ), Checks).

check_trace(_, _, _, _, _, trace(L, _, _, _, refused(Why)), check(L, pending, Why)) :- !.
check_trace(Id, Src, File, Twin, Results, trace(L, _, _, _, data(_, _, _, _)), check(L, V, D)) :-
    (   memberchk(L-R, Results)
    ->  format(atom(Scen), 'trace_~w', [L]),
        lps_state(File, Scen, State),
        retractall(lps_final(Id, L, _)), assertz(lps_final(Id, L, State)),
        catch(compare_result(Id, Src, Twin, L, R, State, V, D), E, ( V = fail, format(string(D), "comparison failed: ~q", [E]) ))
    ;   V = pending, D = "L4's evaluator gave no result"
    ).

%   The final state LPS2 reaches with one scenario of the twin.
lps_state(File, Scen, State) :-
    le2_paths:lps2_dir(L), le2_paths:le2_dir(LE2),
    atomic_list_concat([L, '/lps'], Lps),
    process_create(Lps, [state, File, '--scenario', Scen],
                   [cwd(L), stdout(pipe(Out)), stderr(null), environment(['LPS_LE2_LIB'=LE2]), process(Pid)]),
    read_string(Out, _, S), close(Out),
    process_wait(Pid, _),
    split_string(S, "\n", " \t", Lines),
    findall(T, ( member(Ln, Lines), Ln \== "", catch(term_string(T, Ln), _, fail) ), State).

		 /*******************************
		 *      L4'S RESULT vs STATE    *
		 *******************************/

compare_result(Id, Src, Twin, L, R, State, V, D) :-
    (   R == "FULFILLED"
    ->  ( memberchk(the_contract_is_fulfilled, State) -> V = pass, D = "fulfilled" ; V = fail, format(string(D), "L4: fulfilled; twin: ~q", [State]) )
    ;   sub_string(R, 0, _, _, "DEONTIC BREACHED:")
    ->  breach_expected(R, Exp),
        (   breach_in_state(Exp, State) -> V = pass, format(string(D), "breached (~q)", [Exp])
        ;   V = fail, format(string(D), "L4: ~q; twin: ~q", [Exp, State]) )
    ;   residual_check(Id, Src, Twin, L, R, State, V, D)
    ).

%   L4's breach: explicit — BREACH, BY p, BECAUSE r — or a missed
%   deadline: the obligation's party and its deadline.
breach_expected(R, Exp) :-
    split_string(R, "\n", " ", Ls0), exclude(==(""), Ls0, [_|Ls]),
    (   Ls = ["BREACH"|More]
    ->  ( member(B, More), string_concat("BY ", P, B) -> party_atom(P, PA) ; PA = none ),
        ( member(B2, More), string_concat("BECAUSE ", Q, B2) -> string_unquote(Q, RA) ; RA = none ),
        Exp = explicit(PA, RA)
    ;   append(_, ["surpassed the deadline of party", P, _, M|Rest], Ls), last(Rest, DS)
    ->  party_atom(P, PA), number_string(DL, DS),
        ( sub_string(M, 0, _, _, "MUST NOT") -> Exp = forbidden(PA, DL) ; Exp = missed(PA, DL) )
    ;   Exp = unknown(R)
    ).

string_unquote(Q, S) :- ( sub_string(Q, 0, 1, _, "\"") -> sub_string(Q, 1, _, 1, S) ; S = Q ).

party_atom(P, A) :-
    format(string(Src), "x MEANS ~w~n", [P]),
    (   catch(l4_read_text(Src, l4_module(Items, _)), _, fail),
        member(decide(_, _, _, Body, _, _), Items), party_expr_atom(Body, A)
    ->  true
    ;   A = P
    ).

party_expr_atom(app(N, []), A) :- !, name_atom(N, A).
party_expr_atom(app(C, Args), A) :- maplist(party_expr_atom, Args, As), name_atom(C, CA), atomic_list_concat([CA|As], '_', A).

breach_in_state(explicit(none, none), S) :- memberchk(the_contract_is_breached, S).
breach_in_state(explicit(P, none), S) :- P \== none, memberchk(the_contract_is_breached_by(P), S).
breach_in_state(explicit(none, R), S) :- R \== none, member(the_contract_is_breached_because(R1), S), same_text(R, R1).
breach_in_state(explicit(P, R), S) :- P \== none, R \== none, member(the_contract_is_breached_by_because(P, R1), S), same_text(R, R1).
breach_in_state(missed(P, DL), S) :- member(the_contract_is_breached_by_missing(P, D1), S), D1 =:= DL.
breach_in_state(forbidden(P, DL), S) :- member(the_contract_is_breached_by_doing(P, D1), S), D1 =:= DL.

same_text(A, B) :- atom_string(A, SA), atom_string(B, SB), SA == SB.

%   A remaining contract: the obligations still open, each the same
%   obligation of the source as the twin's open fluent, and each deadline
%   the twin's (checked by probes). Parts already fulfilled (L4 prints
%   `FULFILLED AND …`) are the twin's part fluents.
residual_check(Id, Src, Twin, L, R, State, V, D) :-
    %  L4 prints a remaining contract without indentation; on one line, its
    %  top obligation's party, modal, action and PROVIDED read unambiguously
    split_string(R, "\n", " ", Ls), atomic_list_concat(Ls, ' ', One),
    format(string(RSrc), "x MEANS ~w~n", [One]),
    (   catch(l4_read_text(RSrc, l4_module(Items, _)), _, fail),
        member(decide(_, _, _, Body, _, _), Items)
    ->  leaves(Body, 1, Leaves),
        open_nodes(State, Twin, Opens),
        match_leaves(Leaves, Opens, State, Twin, Mism),
        (   Mism == []
        ->  deadline_probes(Id, Src, L, Opens, PV, PD),
            ( PV == pass -> V = pass, format(string(D), "open: ~w", [PD]) ; V = fail, D = PD )
        ;   V = fail, format(string(D), "L4 remaining ~q; twin ~q (~q)", [Leaves, Opens, Mism])
        )
    ;   V = fail, format(string(D), "L4's result not read: ~w", [R])
    ).

indent_residual(R, RI) :-
    split_string(R, "\n", "", Ls), maplist([X, Y]>>string_concat("  ", X, Y), Ls, Ls1),
    atomic_list_concat(Ls1, '\n', RI).

leaves(rand(A, B), K, Ls) :- !, leaves_part(A, 1-joint, K, L1), leaves_part(B, 2-joint, K, L2), append(L1, L2, Ls).
leaves(ror(A, B), K, Ls) :- !, leaves_part(A, 1-alternative, K, L1), leaves_part(B, 2-alternative, K, L2), append(L1, L2, Ls).
leaves(and(A, B), K, Ls) :- !, leaves(rand(A, B), K, Ls).
leaves(or(A, B), K, Ls) :- !, leaves(ror(A, B), K, Ls).
leaves(D, _, [open(D)]) :- D = deontic(_, _, _, _, _, _, _), !.
leaves(app('FULFILLED', []), _, [fulfilled]) :- !.
leaves(E, _, [other(E)]).

leaves_part(E, P, _, Ls) :- leaves(E, P, Ls0), wrap_part(Ls0, P, Ls).

wrap_part([], _, []).
wrap_part([X|Xs], P, [part(P, X)|Ys]) :- wrap_part(Xs, P, Ys).

%   The twin's open obligations: fluents of nodes, with their deontic term.
open_nodes(State, _, Opens) :-
    findall(o(F, Args), ( member(S, State), compound(S), S =.. [F|Args], sub_atom(F, 0, 2, _, 'o_') ), Opens).

%   Each obligation L4 leaves open is one the twin leaves open: the same
%   obligation of the source (its modal, action and PROVIDED), and the
%   same number of them.
match_leaves(Leaves, Opens, State, twin(_, _, items(_, _, _, _, _, Nodes-_), _, _), Mism) :-
    findall(D, ( member(open(D), Leaves) ; member(part(_, open(D)), Leaves) ), LDs),
    length(LDs, N), length(Opens, NO),
    findall(M, ( member(part(K-W, fulfilled), Leaves), ordinal_(K, O), format(atom(PF), 'the_~w_~w_part_is_fulfilled', [O, W]), \+ memberchk(PF, State), M = missing(PF) ), M1),
    ( N =:= NO -> M2 = [] ; M2 = [count(N, NO)] ),
    findall(other(E), ( member(other(E), Leaves) ; member(part(_, other(E)), Leaves) ), M3),
    findall(unmatched(LD), ( member(LD, LDs), \+ ( member(o(F, _), Opens), memberchk(F-SD, Nodes), same_obligation(LD, SD) ) ), M4),
    append([M1, M2, M3, M4], Mism).

%   The same obligation of the source: the same modal and the same action
%   (its constructor; L4 prints a remaining contract on lines of its own,
%   so on one line an EXACTLY value may take the next field as its
%   argument), and PROVIDED on both or neither.
same_obligation(deontic(_, M, A, P, _, _, _), deontic(_, M2, A2, P2, _, _, _)) :-
    M == M2, action_con(A, C), action_con(A2, C), ( P == none -> P2 == none ; P2 \== none ).

action_con(papp(C, _), C).
action_con(pexact(app(C, _)), C).
action_con(pexact(app(C)), C).

ordinal_(1, first).
ordinal_(2, second).

%   Each open obligation's deadline, checked by L4: the trace, then the
%   clock read on the deadline — the obligation still open — and just
%   after it — no longer open (a different result).
deadline_probes(_, _, _, [], pass, "0") :- !.
deadline_probes(Id, Src, L, Opens, V, D) :-
    findall(DL, ( member(o(F, Args), Opens), fluent_deadline(F, Args, DL) ), DLs),
    length(Opens, NO),
    (   DLs == [] -> V = pass, format(string(D), "~w", [NO])
    ;   trace_text(Src, L, TT),
        findall(P, ( member(DL, DLs), member(Dt, [0, 0.001]), T is DL + Dt, probe_text(TT, T, P) ), Ps),
        read_file_to_string(Src, S0, [encoding(utf8)]),
        split_string(S0, "\n", "", Ls), length(Ls, N0),
        atomic_list_concat(Ps, '\n', PT),
        format(string(Probe), "~w~n~n~w~n", [S0, PT]),
        oracle_cached(Id, probes, Probe, J),
        probe_results(J, N0, Ps, Rs),
        probe_verdicts(DLs, Rs, V, D0),
        format(string(D), "~w obligation(s), deadline(s) ~w ~w", [NO, DLs, D0])
    ).

%   The deadline of an open obligation's fluent: its place after the
%   party and the expected values — read from the fluent's text.
fluent_deadline(F, Args, DL) :-
    b_getval(l4_dicts_state, Voc), memberchk(F-Text, Voc),
    sub_atom(Text, B, _, _, 'by day *a due day*'), !,
    sub_atom(Text, 0, B, _, Before),
    aggregate_all(count, sub_atom(Before, _, _, _, '*'), Stars), Pos is Stars // 2 + 1,
    nth1(Pos, Args, DL), number(DL).

trace_text(Src, L, Text) :-
    read_file_to_string(Src, S, [encoding(utf8)]),
    split_string(S, "\n", "", Ls),
    nth1(L, Ls, First),
    L1 is L + 1,
    findall(X, ( nth1(I, Ls, X), I >= L1, event_line_run(Ls, L1, I) ), More),
    atomic_list_concat([First|More], '\n', Text).

event_line_run(Ls, From, I) :-
    forall(between(From, I, J), ( nth1(J, Ls, X), split_string(X, "", " \t", [T]), T \== "", sub_string(X, 0, 1, _, C), memberchk(C, [" ", "\t"]) )).

probe_text(TT, T, P) :-
    split_string(TT, "\n", "", Ls),
    (   Ls = [_, L2|_], sub_string(L2, B, _, _, "PARTY") -> true ; B = 2 ),
    length(Sp, B), maplist(=(0' ), Sp), string_codes(Ind, Sp),
    format(string(P), "~w~n~w(`WAIT UNTIL` ~w)", [TT, Ind, T]).

probe_results(J, N0, Ps, Rs) :-
    S0 is N0 + 2,
    probe_starts(Ps, S0, Starts),
    get_dict(results, J, JRs),
    maplist(result_at(JRs), Starts, Rs).

result_at(JRs, Start, R) :-
    (   member(X, JRs), get_dict(start, X, St), get_dict(line, St, Start) -> get_dict(result, X, R) ; R = none ).

probe_starts([], _, []).
probe_starts([P|Ps], S, [S|Ss]) :-
    split_string(P, "\n", "", PLs), length(PLs, K), S1 is S + K,
    probe_starts(Ps, S1, Ss).

%   At the deadline the result is the same obligation; just after, not.
probe_verdicts([], [], pass, "checked by L4").
probe_verdicts([_|Ds], [At, After|Rs], V, D) :-
    (   At \== After, string(At), \+ sub_string(At, 0, _, _, "DEONTIC BREACHED"), At \== "FULFILLED"
    ->  probe_verdicts(Ds, Rs, V, D)
    ;   V = fail, format(string(D), "L4 at the twin's deadline: ~w / just after: ~w", [At, After])
    ).

		 /*******************************
		 *       THE HISTORY VIEW       *
		 *******************************/

%   The timeless twin (l4_history.pl) into LE2's examples/migration/l4/<Id>/,
%   the library beside it; each scenario expects the LPS twin's final state
%   where that agreed with L4. Its tests are then run by LE2.
build_history(Id, info(Id, _, Twin), Checks, history(File, Passed, Failed)) :-
    corpus_path(Id, Src), corpus_file(Id, Rel, _), file_base_name(Rel, Base),
    findall(L-State, ( member(check(L, pass, _), Checks), lps_final(Id, L, State) ), Expected),
    history_write(Twin, Base, Expected, [], Id, Rel, Src, File0, Failed0),
    %  a history the runner cannot finish in its time limit keeps no
    %  expectation (said in the scenario), and the view is written again
    findall(T, ( member(X, Failed0), sub_string(X, _, _, _, "Timeout exceeded"),
                 sub_string(X, B, _, _, "trace_"), sub_string(X, B, _, 0, R0),
                 split_string(R0, ",)", "", [TS|_]), sub_string(TS, 6, _, 0, NS), number_string(T, NS) ), Slow0),
    sort(Slow0, Slow),
    (   Slow == [] -> File = File0
    ;   history_write(Twin, Base, Expected, Slow, Id, Rel, Src, File, _)
    ),
    history_tests(File, Passed, Failed).

history_write(Twin, Base, Expected, Slow, Id, Rel, Src, File, Failed) :-
    history_migration(Twin, [source(Base), expected(Expected), slow(Slow)], Mig),
    twin_name(Id, Name),
    le2_paths:le2_dir(LE2), atomic_list_concat([LE2, '/examples/migration/l4/', Name], Dir),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
    atomic_list_concat([SD, '/', Base], Copy), copy_file(Src, Copy),
    notice(SD, Rel),
    atom_concat(Name, '_history', HId),
    write_migration(Mig, Dir, HId, report(File, Issues, _, _)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs),
    ( Errs == [] -> true ; format(user_error, "  history writer errors: ~q~n", [Errs]) ),
    history_tests(File, _, Failed).

history_tests(File, Passed, Failed) :-
    le2_paths:le2_dir(LE2), atomic_list_concat([LE2, '/myswipl.sh'], Sw),
    format(atom(G), "use_module(le_kbs), runTestsFor('~w', R), print_test_result(R), halt.", [File]),
    process_create(Sw, ['-g', G], [cwd(LE2), stdout(pipe(Out)), stderr(null), process(Pid)]),
    read_string(Out, _, S), close(Out), process_wait(Pid, _),
    split_string(S, "\n", " ", Ls),
    aggregate_all(count, ( member(X, Ls), sub_string(X, 0, _, _, "PASS:") ), Passed),
    findall(X, ( member(X, Ls), ( sub_string(X, 0, _, _, "FAIL:") ; sub_string(X, 0, _, _, "ERROR:") ) ), Failed).

		 /*******************************
		 *            REPORT            *
		 *******************************/

report(S, Rs) :-
    format(S, "L4 contracts (the design notes l4.md, step 3): each #TRACE's scenario under LPS2 against L4's evaluator~n~n", []),
    forall(member(R, Rs), report_one(S, R)),
    findall(V, ( member(result(_, Cs, _), Rs), member(check(_, V, _), Cs) ), Vs),
    aggregate_all(sum(P), member(result(_, _, history(_, P, _)), Rs), HP),
    aggregate_all(sum(N), ( member(result(_, _, history(_, _, F)), Rs), length(F, N) ), HF),
    aggregate_all(count, member(pass, Vs), P), aggregate_all(count, member(fail, Vs), F), aggregate_all(count, member(pending, Vs), Pe),
    length(Vs, N),
    format(S, "~nTotal: ~w traces, ~w agree with L4, ~w differ, ~w not translated~n", [N, P, F, Pe]),
    format(S, "History views: ~w expectations pass, ~w fail~n", [HP, HF]).

report_one(S, result(Id, Cs, H)) :- !,
    format(S, "~w~n", [Id]),
    forall(member(check(L, V, D), Cs), format(S, "  ~w ~w  ~w~n", [L, V, D])),
    (   H = history(_, P, F) -> length(F, NF), format(S, "  history view: ~w passed, ~w failed~n", [P, NF]),
        forall(member(X, F), format(S, "    ~w~n", [X]))
    ;   format(S, "  history view: ~q~n", [H])
    ).
report_one(S, error(Id, E)) :- format(S, "~w~n  ERROR ~q~n", [Id, E]).

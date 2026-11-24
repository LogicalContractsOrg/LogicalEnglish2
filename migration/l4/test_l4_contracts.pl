/** <module> Tests of the contracts half (the design notes l4.md, step 3)

    From the LE2 checkout (/work), after fetch_sources.sh:

        ./myswipl.sh -q -g run_tests -t halt migration/l4/test_l4_contracts.pl

    What L4's evaluator says about each trace is read from runs/ (making it
    needs Node.js: l4_oracle.mjs, fetch_oracle.sh). A small contract is
    compiled here and its scenarios run by LPS2 (when /lps2, or $LPS2_DIR,
    is there) and its history view by LE2; the whole corpus's results are the
    build's last run, runs/contracts/gate.txt (l4_contracts_build.pl).
*/

:- module(test_l4_contracts, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(readutil)).
:- use_module(library(process)).
:- use_module(l4_reader).
:- use_module(l4_contracts).
:- use_module(l4_history).
:- use_module(corpus).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).

here(D) :- module_property(test_l4_contracts, file(F)), file_directory_name(F, D).

%   The sale of L4's foundation course and the regulative reference's
%   contracts, compiled from a text.
sale_text("DECLARE Actor IS ONE OF Buyer, Seller
DECLARE Action IS ONE OF deliver, pay HAS amount IS A NUMBER

GIVETH A DEONTIC Actor Action
sale MEANS
    PARTY Seller
    MUST deliver
    WITHIN 14
    HENCE
        PARTY Buyer
        MUST pay 100
        WITHIN 30
        HENCE FULFILLED
        LEST BREACH BY Buyer BECAUSE \"failed to pay\"
    LEST BREACH BY Seller BECAUSE \"failed to deliver\"

GIVETH A DEONTIC Actor Action
choice MEANS (PARTY Seller MUST deliver WITHIN 7) ROR (PARTY Buyer MUST pay 5 WITHIN 7)

#TRACE sale AT 0 WITH
    PARTY Seller DOES deliver AT 10
    PARTY Buyer DOES pay 100 AT 20
#TRACE sale AT 0 WITH
    PARTY Seller DOES deliver AT 10
    PARTY Buyer DOES pay 100 AT 50
#TRACE sale AT 0 WITH
    PARTY Seller DOES deliver AT 10
#TRACE choice AT 0 WITH
    PARTY Buyer DOES pay 5 AT 3
").

with_sale(Goal) :-
    sale_text(T), tmp_file_stream(text, F, S), write(S, T), close(S),
    call_cleanup(call(Goal, F), delete_file(F)).

twin_of(F, Twin) :- contract_twin(F, [id(sale_test)], Twin).

lps2_available :- catch(le2_paths:lps2_dir(_), _, fail).

:- begin_tests(l4_contracts_compile).

test(names) :-
    words_of('CommissionerActor', W1), assertion(W1 == [commissioner, actor]),
    words_of('the charity', W2), assertion(W2 == [the, charity]),
    name_atom('Spouse1', A), assertion(A == spouse_1).

%   Every trace compiled; each obligation a fluent with its deadline; met
%   and missed laws for each; the breach names who and why.
test(sale_compiles) :-
    with_sale([F]>>( twin_of(F, twin(_, _, items(Voc, _, _, _, Laws, _), Traces, Refused)),
        assertion(Refused == []),
        assertion(forall(member(trace(_, _, _, _, S), Traces), S = data(_, _, _, _))),
        assertion(memberchk(fluent(the_contract_is_breached_by_because, _, _), Voc)),
        findall(T, ( member(fluent(Fn, T, _), Voc), sub_atom(Fn, 0, 2, _, 'o_') ), Obls),
        assertion(length(Obls, 4)),
        assertion(forall(member(T, Obls), sub_atom(T, _, _, _, 'as its'))),
        aggregate_all(count, member(law(node(sale, _), _), Laws), NL),
        assertion(NL >= 4) )).

%   ROR: a part's fulfilment ends the contract (a combination law).
test(ror_combination) :-
    with_sale([F]>>( twin_of(F, twin(_, _, items(Voc, _, _, _, Laws, _), _, _)),
        assertion(memberchk(fluent(the_first_alternative_part_is_fulfilled, _, _), Voc)),
        assertion(( member(law(combination, law(_, _, Es)), Laws), memberchk(initiated(the_contract_is_fulfilled), Es) )) )).

%   Pattern names bind, as in L4: `MUST pay amount` with `amount` an input
%   is any payment; its value is not a place of the obligation.
test(pattern_names_bind) :-
    corpus_path(advanced_module_a2_cross_cutting_examples, P),
    contract_twin(P, [id(a2)], twin(_, _, items(Voc, _, _, _, _, _), _, _)),
    once(( member(fluent(_, T, _), Voc), sub_atom(T, 0, _, _, 'payment with grace obliges') )),
    assertion(\+ sub_atom(T, _, _, _, 'the payment amount')).

%   The history view's ledger names each obligation and trace, as the LE
%   for LPS twin's does (it was once empty); a trace with two events on one
%   day is an approximation.
test(history_ledger) :-
    with_sale([F]>>( twin_of(F, Twin),
        history_migration(Twin, [expected([])], migration(_, _, Ledger, _)),
        aggregate_all(count, member(entry(_, obligation, encoded, _, _, _), Ledger), NO),
        assertion(NO =:= 4),
        aggregate_all(count, member(entry(_, trace, _, _, _, _), Ledger), NT),
        assertion(NT =:= 4) )),
    Twin2 = twin(t, t, items([], [], [], [], [], []-[]),
                 [trace(9, x, _, _, data(f, 0, [], [ev(p, c, [], 3), ev(p, c, [], 3)]))], []),
    catch(history_migration(Twin2, [], migration(_, _, [E], _)), _, fail),
    assertion(E = entry(_, trace, approximated, _, trace_9, _)).

:- end_tests(l4_contracts_compile).

decl(event(F, T, _), event(F, T, [known_as(F)])).
decl(fluent(F, T, _), fluent(F, T, [known_as(F)])).
decl(template(F, T, _), template(F, T, [known_as(F)])).
decl(function(F, T), function(F, T, [known_as(F)])).

l4cb_state(File, Scen, State) :-
    le2_paths:lps2_dir(L), le2_paths:le2_dir(LE2),
    atomic_list_concat([L, '/lps'], Lps),
    process_create(Lps, [state, File, '--scenario', Scen],
                   [cwd(L), stdout(pipe(Out)), stderr(null), environment(['LPS_LE2_LIB'=LE2]), process(Pid)]),
    read_string(Out, _, S), close(Out), process_wait(Pid, _),
    split_string(S, "\n", " \t", Lines),
    findall(T, ( member(Ln, Lines), Ln \== "", catch(term_string(T, Ln), _, fail) ), State).

:- begin_tests(l4_contracts_run, [condition(lps2_available)]).

%   The twin run by LPS2 ends where L4 does: fulfilled; breached by the
%   buyer; the payment still open with its deadline (day 10 + 30).
test(sale_runs_as_l4) :-
    with_sale([F]>>( tmp_file(sale, Dir), make_directory(Dir),
        twin_of(F, Twin),
        Twin = twin(_, _, items(Voc, _, _, _, _, _), _, _),
        findall(I, ( member(V, Voc), decl(V, I) ), VocIR),
        ir_dicts(program([target(lps)], VocIR), Dicts), b_setval(l4_dicts, Dicts),
        twin_migration(Twin, [source('sale.l4')], Mig),
        write_migration(Mig, Dir, sale, report(File, _, _, _)),
        [T1, T2, T3, T4] = [trace_20, trace_23, trace_26, trace_28],
        l4cb_state(File, T1, S1), assertion(memberchk(the_contract_is_fulfilled, S1)),
        l4cb_state(File, T2, S2), assertion(memberchk(the_contract_is_breached_by_because(buyer, "failed to pay"), S2)),
        l4cb_state(File, T3, S3), assertion(( member(O, S3), O =.. [_, buyer, 100, 40] )),
        l4cb_state(File, T4, S4), assertion(memberchk(the_contract_is_fulfilled, S4)),
        delete_directory_and_contents(Dir) )).



:- end_tests(l4_contracts_run).

:- begin_tests(l4_contracts_corpus).

%   The build's last run: every trace translated agrees with L4, and the
%   history views pass (runs/contracts/gate.txt, l4_contracts_build.pl).
test(gate_last_run) :-
    here(H), atomic_list_concat([H, '/runs/contracts/gate.txt'], G),
    read_file_to_string(G, T, []),
    once(sub_string(T, _, _, _, "Total: ")),
    split_string(T, "\n", "", Ls),
    once(( member(L, Ls), sub_string(L, 0, _, _, "Total:") )),
    split_string(L, " ,", " ,", Ws),
    nth1(I, Ws, "differ"), I0 is I - 1, nth1(I0, Ws, D),
    assertion(D == "0"),
    once(( member(L2, Ls), sub_string(L2, 0, _, _, "History views:") )),
    assertion(sub_string(L2, _, _, _, " 0 fail")).

:- end_tests(l4_contracts_corpus).

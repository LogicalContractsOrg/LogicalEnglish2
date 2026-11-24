/*  The CDM on its own (the design notes rune.md §13, step 5): the twin of the
    Common Domain Model's product qualification, checked against the CDM's
    own Java.

    ./myswipl.sh -q migration/rune/cdm_build.pl

    The CDM (Community Specification License 1.0) is open: its twins can be
    shown to anyone, unlike DRR's. This one is the namespace
    cdm.product.qualification of the CDM 6.29 that DRR 7.14.0 builds on: the
    Qualify_ functions that say what a product is (an interest rate swap,
    fixed against floating; a credit default swap on an index; ...), as
    sentences about the product's economic terms.

    The products are those of the trades in DRR's test pack (the after-trade
    of each instruction's event): each is a scenario with the economic terms
    and what they refer to, and its expectations are what the CDM's Java
    says of it (CdmQualifyOracle.java: every Qualify_ function on the economic
    terms, references resolved as DRR resolves them). The scenarios come from
    DRR's test pack, so this folder is private like the others; the rules
    alone are publishable.

    Writes examples/migration/rune/cdm_product_qualification/: the twin (its
    rules, the CDM layer it includes), one file of scenarios per group of
    the test pack, and runs/cdm_product_qualification.txt (every function on
    every product, the twin against the CDM's Java).
*/
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- use_module(parser/rune_reader).
:- use_module(rune_paths).
:- use_module(ledger_json).
:- use_module(rune_twin).
:- use_module(rune_data).
:- use_module(library(main)).
:- use_module(library(process)).
:- consult(build).

:- initialization(main, main).

ns('cdm.product.qualification').
twin(cdm_product_qualification).

main(_) :-
    json_dir(JD), load_rune_model(JD),
    ns(NS), twin(Twin),
    namespace_twin([NS], [], twin(Layers, Ledger, _)),
    twins_dir(TD), directory_file_path(TD, Twin, Dir), make_directory_path(Dir),
    write_rules('CDM product qualification', Twin, Dir, Layers, Ledger),
    ledger_json(Dir),
    oracle(Answers),
    length(Answers, NA), format("the CDM's Java on ~w instructions~n", [NA]),
    qualify_functions(Fns),
    write_cdm_scenarios(Twin, Dir, Fns, Answers, Files),
    format("~w files of scenarios~n", [Files]),
    twin_sources(Twin),
    check(Twin, Dir, Fns, Answers).

%   The Qualify_ functions of the namespace that take the economic terms.
qualify_functions(Fns) :-
    ns(NS),
    findall(Q-F, ( rune_model:rune_func(Q, [in(_, 'cdm.product.template.EconomicTerms', _)], _, _, _, _, _),
                   rune_twin:q_namespace(Q, NS),
                   rune_twin:short(Q, S), sub_atom(S, 0, _, _, 'Qualify_'),
                   rune_twin:tmpl(func(Q), F, _, 1) ), Fns0),
    sort(Fns0, Fns).

% ---------------------------------------------------------------- the oracle

oracle(Answers) :-
    drr_dir(D),
    format(atom(P), '~w/enrich/output/fpml-record-keeping-to-reportable-event/transaction-report-instruction-test-pack-default', [D]),
    findall(F1, directory_member(P, F1, [extensions([json]), recursive(true)]), Fs0), msort(Fs0, Fs),
    rune_home(H), format(atom(C), '~w/.cache', [H]),
    format(atom(CPF), '~w/classpath.txt', [C]), read_file_to_string(CPF, CP0, []), normalize_space(atom(CP), CP0),
    format(atom(Jar), '~w/lib/cdm-java-6.29.0.jar', [C]),
    process_create(path(java), ['-cp', CP, 'CdmQualifyOracle', Jar],
                   [cwd(C), stdin(pipe(In)), stdout(pipe(Out)), stderr(null), process(Pid)]),
    forall(member(F, Fs), format(In, "~w~n", [F])), close(In),
    read_string(Out, _, S), close(Out), process_wait(Pid, _),
    split_string(S, "\n", "", Ls),
    findall(F-Holds, ( member(L, Ls), split_string(L, "\t", "", [F0, HS]), HS \== "error",
                       atom_string(F, F0), split_string(HS, ",", "", Hs0), exclude(==(""), Hs0, Hs),
                       maplist([X, Y]>>atom_string(Y, X), Hs, Holds) ), Answers).

% ---------------------------------------------------------------- the scenarios

%   One scenario per instruction: the economic terms of its after-trade and
%   the objects they refer to; it expects each function that the CDM's Java
%   says holds, and no other asset class.
write_cdm_scenarios(Twin, Dir, Fns, Answers, NFiles) :-
    findall(G-(F-Holds), ( member(F-Holds, Answers), group_of(F, G) ), GAs),
    findall(G, member(G-_, GAs), Gs0), sort(Gs0, Gs), length(Gs, NFiles),
    findall(template(Fn, T, [included]), rune_twin:tmpl(_, Fn, T, _), Ts0), list_to_set(Ts0, Ts),
    %  each query starts from the economic terms the scenario is about: a
    %  qualification that counts the payouts of its economic terms names
    %  them nowhere else, and would answer for none in particular
    findall(query(QN, (the_economic_terms_of_the_instruction_is(V), G1)), ( member(Q-Fn, Fns), query_name_of(Q, QN), G1 =.. [Fn, V] ), Qs),
    Bind = template(the_economic_terms_of_the_instruction_is, "the economic terms of the instruction is *an economic terms*", []),
    forall(member(G, Gs),
           ( findall(Sc, ( member(G-(F-Holds), GAs), scenario_of(F, Holds, Fns, Sc) ), Scs),
             append([Ts, [Bind], Qs, Scs], Items),
             format(atom(C), "The products of DRR's test pack, group ~w: the economic terms of each instruction's trade, with what the CDM's own Java says each is (CdmQualifyOracle.java).", [G]),
             atom_concat(G, '_products', KB),
             IR = program([kb(KB), includes([Twin]), comment(C)], Items),
             le_write(IR, Text, _),
             directory_file_path(Dir, KB, F0), file_name_extension(F0, le, File),
             setup_call_cleanup(open(File, write, S), write(S, Text), close(S)) )).

query_name_of(Q, QN) :- rune_twin:short(Q, S), downcase_atom(S, L), atom_concat(q_, L, QN).

scenario_of(File, Holds, Fns, scenario(Name, Lines, [])) :-
    file_base_name(File, B), file_name_extension(B0, _, B), group_of(File, G),
    rune_paths:scenario_name(G, B0, Name),
    instance_facts(File, 'drr.regulation.common.TransactionReportInstruction', instruction, Fs),
    economic_terms(Fs, ET),
    reachable(Fs, ET, Objs),
    ordered_facts_from(Fs, ET, Objs, Facts),
    findall(expects(QN, Ans),
            ( member(Q-Fn, Fns), rune_twin:short(Q, S),
              ( memberchk(S, Holds) -> answer_string(Fn, ET, A1), Ans = [A1]
              ; sub_atom(S, 0, _, _, 'Qualify_AssetClass_') -> Ans = []
              ),
              query_name_of(Q, QN) ), Exps),
    append([[the_economic_terms_of_the_instruction_is(ET)], Facts, Exps], Lines).

%   The answer as LE writes it: the query's two conditions, the economic
%   terms in both.
answer_string(Fn, ET, A) :-
    rune_twin:tmpl(_, Fn, T, _),
    atom_codes(T, Cs), place_filled(Cs, ET, Ds), atom_codes(Q, Ds),
    format(string(A), "the economic terms of the instruction is ~w and ~w", [ET, Q]).
place_filled([0'*|Cs], X, Ds) :- !, append(_, [0'*|Rest], Cs), !, atom_codes(X, XC), append(XC, Rest, Ds).
place_filled([C|Cs], X, [C|Ds]) :- place_filled(Cs, X, Ds).

%   instruction -> originatingWorkflowStep -> businessEvent -> after[0] ->
%   trade -> product -> economicTerms
economic_terms(Fs, ET) :-
    memberchk(f(instruction, originatingWorkflowStep, o(W)), Fs),
    memberchk(f(W, businessEvent, o(B)), Fs),
    memberchk(f(B, after, o(A)), Fs),
    memberchk(f(A, trade, o(T)), Fs),
    memberchk(f(T, product, o(P)), Fs),
    memberchk(f(P, economicTerms, o(ET)), Fs).

reachable(Fs, Root, Objs) :- reach([Root], Fs, [Root], Objs).
reach([], _, Seen, Seen).
reach([O|Os], Fs, Seen, All) :-
    findall(S, ( member(f(O, _, o(S)), Fs), \+ memberchk(S, Seen) ), New0), list_to_set(New0, New),
    append(Seen, New, Seen1), append(Os, New, Q), reach(Q, Fs, Seen1, All).

ordered_facts_from(Fs, _, Objs, Lines) :-
    findall(fact(L), ( member(O, Objs), member(Fct, Fs), fact_of(O, Fct, L) ), Lines).

% ---------------------------------------------------------------- the check

%   Every function on every product: the twin's answer against the CDM's.
check(Twin, Dir, Fns, Answers) :-
    directory_files(Dir, Fs0), msort(Fs0, Fs),
    set_prolog_flag(le_failure_explanations, false),
    findall(r(A, D, Ds), ( member(F, Fs), atom_concat(_, '_products.le', F), directory_file_path(Dir, F, P),
                           check_file(P, Fns, A, D, Ds) ), Rs),
    aggregate_all(sum(A), member(r(A, _, _), Rs), Agree), aggregate_all(sum(D), member(r(_, D, _), Rs), Differ),
    findall(X, ( member(r(_, _, Ds), Rs), member(X, Ds) ), Diffs),
    Total is Agree + Differ, length(Answers, NP), length(Fns, NF),
    format(string(Line), "~w of ~w answers agree with the CDM's Java (~w functions on each of ~w products), ~w differ", [Agree, Total, NF, NP, Differ]),
    writeln(Line),
    rune_home(H), format(atom(R), '~w/runs/~w.txt', [H, Twin]),
    setup_call_cleanup(open(R, write, S),
        ( writeln(S, Line), forall(member(d(Sc, Q, Exp, Got), Diffs), format(S, "  ~w: ~w expected ~w, the twin ~w~n", [Sc, Q, Exp, Got])) ),
        close(S)).

check_file(P, Fns, Agree, Differ, Diffs) :-
    le_kbs:load(P, KB, [skip_tests]),
    findall(Sc, KB:le_expected(_, Sc, _, _), Ss0), sort(Ss0, Ss),
    foldl(check_scenario(KB, Fns), Ss, t(0, 0, []), t(Agree, Differ, Diffs)).

%   Each function's query in the scenario: it holds when the query has an
%   answer; the CDM's Java says it holds when the scenario expects an answer.
check_scenario(KB, Fns, Sc, T0, T) :-
    le_kbs:createSession(KB, SM), le_kbs:setScenarion(SM, Sc),
    foldl(check_function(KB, SM, Sc), Fns, T0, T),
    le_kbs:destroySession(SM).

check_function(KB, SM, Sc, Q-_, t(A0, D0, Ds0), t(A, D, Ds)) :-
    query_name_of(Q, QN),
    ( KB:le_expected(QN, Sc, [_|_], _) -> Exp = holds ; Exp = no ),
    (   KB:query_info(QN, Goal, _),
        catch(call_with_time_limit(20, once(reasoner:i(Goal, SM, _, _))), _, fail)
    ->  Got = holds ; Got = no
    ),
    (   Exp == Got -> A is A0 + 1, D = D0, Ds = Ds0
    ;   A = A0, D is D0 + 1, Ds = [d(Sc, QN, Exp, Got)|Ds0]
    ).

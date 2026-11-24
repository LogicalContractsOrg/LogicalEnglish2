/*  Step 2 of the design notes rune.md: a report's twin, its scenarios, and the
    measure (N of M expected field values agree, R residue, D disagree).

    ./myswipl.sh -q migration/rune/build.pl                      # CFTC Part45
    ./myswipl.sh -q migration/rune/build.pl -- 'ESMA EMIR Trade'
    ./myswipl.sh -q migration/rune/build.pl -- 'CFTC Part45' rates

    Writes examples/migration/rune/<report>/ of the private place (rune_paths:twins_dir/1): <report>.le (the rules,
    which include ../lib/rune), <report>.ledger.md, and one file of
    scenarios per group of DRR's test pack (<group>.le, which includes the
    rules), then runs each group's tests and writes runs/<report>.txt.
*/
:- use_module(parser/rune_reader).
:- use_module(rune_data).
:- use_module(rune_closure).
:- use_module(rune_twin).
:- use_module(rune_paths).
:- use_module(ledger_json).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer)).
:- use_module(le2(le_kbs)).
:- use_module(rune_fingerprint).
:- use_module(le2(le_migration), [ledger_counts/2]).
:- use_module(library(main)).
:- use_module(library(json)).

:- initialization(main, main).

main(Argv) :-
    ( Argv = [R|Rest] -> true ; R = 'CFTC Part45', Rest = [] ),
    report_pack(R, Pack, Base),
    nb_setval(rune_report, R),
    json_dir(JD), load_rune_model(JD),
    report_twin_layers(R, [], twin(Layers, Ledger, Fields)),
    twins_dir(TD), directory_file_path(TD, Base, Dir), make_directory_path(Dir),
    test_pack_pairs(Pack, Pairs0),
    ( Rest = [Only|_] -> include(in_group(Only), Pairs0, Pairs) ; Pairs = Pairs0 ),
    %  the scenario files, named in the main file's opening comment
    findall(G, ( member(pair(_, I, _), Pairs), group_of(I, G) ), Gs0), sort(Gs0, Gs),
    nb_setval(rune_scenario_groups, Gs),
    write_rules(R, Base, Dir, Layers, Ledger),
    ledger_json(Dir),
    write_scenarios(R, Base, Dir, Fields, Pairs, Files),
    format("~w scenario files~n", [Files]),
    twin_sources(Base).


in_group(G, pair(_, In, _)) :- group_of(In, G).

%   The twin in three files, each including the next (rune_twin.pl,
%   report_twin_layers/3): <base>.le, what a user opens (the report's own
%   namespace and its fields); <base>_drr.le, DRR's other namespaces;
%   <base>_cdm.le, the CDM's, with the attributes' templates; then the
%   library rune.le.
write_rules(R, Base, Dir, Layers, Ledger) :-
    (   rune_model:rune_report(R, _, _, _, _, _)
    ->  format(atom(C), "~w (DRR 7.14.0), the report's rules as Logical English: written by LE2 migration/rune/build.pl from ISDA's Digital Regulatory Reporting, read by rosetta2json and LE2 migration/rune. Each rule cites the passage of the regulation DRR's Rune cites (as stated in ... confer ...), and the industry's reading as according to. A definition the translator cannot write yet is a residue block. DRR is ISDA's, under the ISDA DRR License (September 2023), which allows its use without modifications: this twin is private (rune.md, section 6).", [R]),
        glossary(G)
    ;   sub_atom(Base, 0, _, _, cdm_)
    ->  format(atom(C), "~w (the Common Domain Model 6.29, as DRR 7.14.0 builds on it), its functions as Logical English: written by LE2 migration/rune from the CDM's Rune, read by rosetta2json and LE2 migration/rune. The CDM is FINOS's, under the Community Specification License 1.0. A definition the translator cannot write yet is a residue block.", [R]),
        G = ''
    ;   format(atom(C), "~w, its rules and functions as Logical English: written by LE2 migration/rune from Rune, read by rosetta2json and LE2 migration/rune. A definition the translator cannot write yet is a residue block.", [R]),
        G = ''
    ),
    % the library (lib/ of this folder), beside the program (an include must
    % be under its folder)
    rune_home(RH), forall(member(X, ['rune.le', 'rune.pl']),
        ( directory_file_path(RH, lib, LD), directory_file_path(LD, X, From),
          directory_file_path(Dir, X, To), copy_file(From, To) )),
    layer_order(Order),
    foldl(write_layer(R, Base, Dir, C, G, Layers, Order), Order, 0, NI),
    ledger_counts(Ledger, Counts),
    directory_file_path(Dir, Base, F0), file_name_extension(F0, le, File),
    format("~w: rules written to ~w and its two layers (~w writer issues); ledger ~w~n", [R, File, NI, Counts]),
    write_ledger(Dir, Base, R, Ledger),
    write_template_map(Dir, Base),
    write_main_fingerprints(Dir, Base, Layers).

%   The fingerprints of the main file's own predicates (its templates and
%   the fields), for the way back (rune_export.pl writes back what changed).
write_main_fingerprints(Dir, Base, Layers) :-
    _ = Layers,
    directory_file_path(Dir, Base, F0), file_name_extension(F0, le, File),
    le_kbs:load(File, KB, [skip_tests]),
    own_functors(KB, Fs),
    atom_concat(F0, '.fingerprints.pl', FP),
    write_fingerprints(FP, KB, Fs),
    length(Fs, N), format("~w fingerprints written~n", [N]).

write_layer(R, Base, Dir, C, G, Layers, Order, L, N0, N) :-
    memberchk(L-Items0, Layers),
    %  the templates of the layers below, declared there (the writer needs
    %  them to write the rules that use them)
    nextto_all(L, Order, Lower),
    findall(template(F, T, [included]), ( member(B, Lower), memberchk(B-BIs, Layers), member(template(F, T, _), BIs) ), Inc0),
    append(Inc0, Items0, Items),
    layer_file(Base, L, KB),
    ( nextto(L, Below, Order) -> layer_file(Base, Below, Inc) ; Inc = rune ),
    layer_comment(L, R, Base, C, G, Comment),
    IR = program([kb(KB), includes([Inc]), comment(Comment)], Items),
    le_write(IR, Text, Issues),
    directory_file_path(Dir, KB, F0), file_name_extension(F0, le, File),
    setup_call_cleanup(open(File, write, S), write(S, Text), close(S)),
    length(Issues, NI), N is N0 + NI,
    format(atom(IFN), 'writer_issues_~w.txt', [L]), directory_file_path(Dir, IFN, IF),
    setup_call_cleanup(open(IF, write, S2), forall(member(I, Issues), format(S2, "~q~n", [I])), close(S2)).

nextto_all(L, Order, Below) :- append(_, [L|Below], Order).

layer_file(Base, main, Base) :- !.
layer_file(Base, L, KB) :- format(atom(KB), '~w_~w', [Base, L]).

layer_comment(main, R, Base, C, G, Comment) :-
    (   rune_model:rune_report(R, _, _, _, _, _)
    ->  format(atom(Comment0), "~w ~w This file holds the report's own rules and its fields; the rules of DRR's other namespaces it uses are in ~w_drr.le, and those of the CDM in ~w_cdm.le.", [C, G, Base, Base]),
        scenarios_sentence(Sentence),
        atomic_list_concat([Comment0, Sentence], Comment)
    ;   format(atom(Comment), "~w ~w This file holds the namespace's own functions and rules; those of other namespaces it uses are in ~w_drr.le (DRR's) and ~w_cdm.le (the CDM's).", [C, G, Base, Base])
    ).
%   Where the scenarios are: this file has none, and a query needs one.
scenarios_sentence(S) :-
    (   catch(nb_getval(rune_scenario_groups, Gs), _, fail), Gs \== []
    ->  maplist([G, F]>>format(atom(F), '~w.le', [G]), Gs, Fs),
        atomic_list_concat(Fs, ', ', FL),
        format(atom(S), " The scenarios of DRR's test pack, one per instruction with the values of DRR's report, are in the files beside this one (~w): open one of them to ask a query or to run the tests.", [FL])
    ;   S = ''
    ).

layer_comment(drr, R, Base, _, _, Comment) :-
    format(atom(Comment), "~w (DRR 7.14.0): the rules and functions of DRR's other namespaces that it uses (the critical data elements, DRR's common rules), included by ~w.le. Written by LE2 migration/rune/build.pl. DRR is ISDA's, under the ISDA DRR License: private.", [R, Base]).
layer_comment(cdm, R, Base, _, _, Comment) :-
    format(atom(Comment), "~w (DRR 7.14.0): the functions of the Common Domain Model and the other models DRR builds on that it uses, with the templates of the objects' attributes and the reference data, included by ~w_drr.le. Written by LE2 migration/rune/build.pl. The CDM is FINOS's, under the Community Specification License 1.0.", [R, Base]).

%   The templates and the Rune they stand for, for the way back
%   (le_to_rune.pl): tmpl(Kind, Functor, Text, Arity), Kind attr(A),
%   func(Q), rule(Q), alias(Q, N, K), meta(A), field, reference(R).
write_template_map(Dir, Base) :-
    directory_file_path(Dir, Base, F0), atom_concat(F0, '.templates.pl', File),
    setup_call_cleanup(open(File, write, S),
        ( format(S, "% The templates of ~w and the Rune they stand for (build.pl).~n", [Base]),
          forall(rune_twin:tmpl(K, F, T, A), format(S, "~q.~n", [tmpl(K, F, T, A)])) ),
        close(S)).

%   The words of the rules a reader of the regulation does not know: said
%   once, at the top of each twin (the review of step 5).
glossary("How to read the rules. CDE 1, CDE 2 and CDE 3 are the three versions, in DRR, of the critical data elements of CPMI-IOSCO's Harmonisation of Critical Data Elements: the definitions of a field that every regulator's report reuses. A value that may be missing is passed on as nothing when it is (Rune's empty value): 'a list L is the list of each V such that ... and the value or nothing of L is a value' is the value, or nothing when there is none. 'The object built at \"PriceFormat 3\" with ...' is an object a rule makes (Rune's PriceFormat { ... }), named after the place in the source that makes it.").

write_ledger(Dir, Base, R, Ledger) :-
    directory_file_path(Dir, Base, F0), atom_concat(F0, '.ledger.md', File),
    ledger_counts(Ledger, Counts),
    setup_call_cleanup(open(File, write, S),
        ( format(S, "# ~w: ledger of the translation~n~n", [R]),
          format(S, "Each definition of the report's closure (its rules and the functions they call), and what became of it.~n~n~w~n~n", [Counts]),
          format(S, "| Definition | Kind | Verdict | Note |~n|---|---|---|---|~n", []),
          forall(member(entry(El, K, V, _, _, N), Ledger),
                 format(S, "| `~w` | ~w | ~w | ~w |~n", [El, K, V, N])) ),
        close(S)).

% ---------------------------------------------------------------- scenarios

write_scenarios(R, Base, Dir, Fields, Pairs, NFiles) :-
    rune_model:rune_report(R, _, _, In, _, _),
    findall(G, ( member(pair(_, I, _), Pairs), group_of(I, G) ), Gs0), sort(Gs0, Gs),
    length(Gs, NFiles),
    findall(template(F, T, [included]), rune_twin:tmpl(_, F, T, _), Ts0), list_to_set(Ts0, Ts),
    forall(member(G, Gs),
           ( include(pair_in_group(G), Pairs, GPs),
             maplist(scenario(In, Fields), GPs, Scs),
             findall(query(QN, report_field(L, instruction, _)), member(field(_, _, QN, L, _), Fields), Qs0),
             sort(Qs0, Qs1),
             eligibility_goal(R, instruction, EG),
             Qs = [query(report, report_field(_, instruction, _)), query(eligible, EG)|Qs1],
             append([Ts, Qs, Scs], Items),
             format(atom(C), "~w: the scenarios of DRR's test pack, group ~w, one per instruction, with the values of DRR's expected report.", [R, G]),
             IR = program([kb(G), includes([Base]), comment(C)], Items),
             le_write(IR, Text, _),
             directory_file_path(Dir, G, F0), file_name_extension(F0, le, File),
             setup_call_cleanup(open(File, write, S), write(S, Text), close(S)) )).

group_of(In, G) :- file_directory_name(In, D), file_base_name(D, G0),
    atom_codes(G0, Cs), maplist([C, E]>>( code_type(C, alnum) -> E = C ; E = 0'_ ), Cs, Es),
    atom_codes(G1, Es), downcase_atom(G1, G).
pair_in_group(G, pair(_, In, _)) :- group_of(In, G).

scenario(InType, Fields, pair(Name, In, Exp), scenario(Name, Lines, [])) :-
    instance_facts(In, InType, instruction, Fs),
    ordered_facts(Fs, instruction, Facts),
    expected_flat(Exp, Flat0),
    %  the items of a list of objects without their place in the list
    %  (otherPayment[0].amount -> otherPayment.amount): the twin answers
    %  with a set of values
    maplist([P0-V0, P1-V0]>>( atomic_list_concat(Bits, '[', P0), unindex(Bits, P1) ), Flat0, Flat),
    findall(expects(QN, Answers),
            ( member(field(Path, _, QN, Label, _), Fields),
              atomic_list_concat(Path, '.', P),
              findall(report_field(Label, instruction, V), ( member(P-V0, Flat), normal_value(V0, V) ), Answers),
              Answers \== [] ),
            Exps),
    %  every instruction of the test pack is one DRR reports: its
    %  eligibility rule holds
    eligibility_goal(_, instruction, EG),
    append([Facts, [expects(eligible, [EG])], Exps], Lines).

unindex([P], P) :- !.
unindex([P|Bits], Out) :-
    maplist([B, R]>>( sub_atom(B, I, 1, _, ']') -> I1 is I + 1, sub_atom(B, I1, _, 0, R) ; R = B ), Bits, Rs),
    atomic_list_concat([P|Rs], Out).

%   The report's eligibility rule, as a goal of the twin (the first, when it
%   has several).
eligibility_goal(R, X, G) :-
    ( var(R) -> nb_getval(rune_report, R1) ; R1 = R, nb_setval(rune_report, R) ),
    rune_model:rune_report(R1, _, _, _, [E|_], _),
    rune_twin:tmpl(rule(E), F, _, _), G =.. [F, X].

normal_value(true, "true") :- !.
normal_value(false, "false") :- !.
normal_value(V0, V) :- float(V0), V0 =:= truncate(V0), abs(V0) < 1.0e15, !, V is truncate(V0).
normal_value(V, V).

%   The facts the twin reads, from the root down (breadth first), each
%   object's facts together.
ordered_facts(Fs, Root, Lines) :-
    bfs([Root], Fs, [Root], Order),
    findall(fact(L), ( member(O, Order), member(Fct, Fs), fact_of(O, Fct, L) ), Lines).

fact_of(O, f(O, A, V), L) :- rune_twin:tmpl(attr(A), F, _, _), ir_value(V, IV), L =.. [F, O, IV].
fact_of(O, m(O, A, scheme, S), L) :- rune_twin:tmpl(meta(A), F, _, _), L =.. [F, O, S].

bfs([], _, Seen, Seen).
bfs([O|Os], Fs, Seen, All) :-
    findall(S, ( member(f(O, A, o(S)), Fs), rune_twin:tmpl(attr(A), _, _, _), \+ memberchk(S, Seen) ), New0),
    list_to_set(New0, New),
    append(Seen, New, Seen1), append(Os, New, Q),
    bfs(Q, Fs, Seen1, All).

ir_value(o(Id), Id) :- !.
ir_value(V, N) :- normal_value(V, N).

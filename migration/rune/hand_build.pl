/*  Step 0 of the design notes rune.md: the scenarios of the hand-made CFTC
    Part 45 twin, one per instruction of DRR's test pack, with the five
    fields' expected values (DRR's own expected reports).

    ./myswipl.sh -q migration/rune/hand_build.pl

    Writes examples/migration/rune/hand/cftc_part45_hand.le of the private place, which
    includes the rules (cftc_part45_hand_rules.le, written by hand).
*/
:- use_module(parser/rune_reader).
:- use_module(rune_data).
:- use_module(rune_paths).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer)).
:- use_module(library(main)).
:- use_module(library(json)).

:- initialization(main, main).

%   The attributes the hand rules read, with their templates.
hand_attribute(reportingSide,         "the reporting side of *an instruction* is *a reporting side*").
hand_attribute(reportingParty,        "the reporting party of *a reporting side* is *a party*").
hand_attribute(reportingCounterparty, "the reporting counterparty of *a reporting side* is *a party*").
hand_attribute(reportSubmittingParty, "the report submitting party of *a reporting side* is *a party*").
hand_attribute(partyId,               "the party id of *a party* is *a party identifier*").
hand_attribute(identifier,            "the identifier of *an identifier object* is *an identifier*").
hand_attribute(identifierType,        "the identifier type of *an identifier object* is *an identifier type*").
hand_attribute(person,                "the person of *a party* is *a natural person*").
hand_attribute(personRole,            "the person role of *a party* is *a natural person role*").
hand_attribute(role,                  "the role of *a natural person role* is *a role*").
hand_attribute(personReference,       "the person reference of *a natural person role* is *a natural person*").
hand_attribute(personId,              "the person id of *a natural person* is *a person identifier*").

%   The five fields: the query, the field's path in DRR's report, its template.
hand_field(counterparty_1, counterparty1, "the counterparty 1 of *an instruction* is *a value*").
hand_field(report_submitting_entity, reportSubmittingEntityID, "the report submitting entity of *an instruction* is *a value*").
hand_field(counterparty_2_identifier_source, counterparty2IdentifierSource, "the counterparty 2 identifier source of *an instruction* is *a value*").
hand_field(submitting_party_id_type, 'dtccAdditionalFields.submittingPartyIDType', "the submitting party ID type of *an instruction* is *a value*").
hand_field(submitted_for_party, 'dtccAdditionalFields.submittedForParty', "the submitted for party of *an instruction* is *a value*").

main(_) :-
    json_dir(JD), load_rune_model(JD),
    test_pack_pairs('cftc-part45', Pairs),
    findall(template(F, T, [included]), hand_attribute(F, T), ATs),
    findall(template(Q, T, [included]), hand_field(Q, _, T), FTs),
    findall(query(Q, G), ( hand_field(Q, _, _), G =.. [Q, instruction, _] ), Qs),
    maplist(scenario, Pairs, Scs),
    append([ATs, FTs, Qs, Scs], Items),
    IR = program([kb(cftc_part45_hand), includes([cftc_part45_hand_rules]),
                  comment("CFTC Part 45, five fields: the hand-made twin's scenarios, one per instruction of DRR 7.14.0's test pack (transaction-report-instruction-test-pack-default), each with the values DRR's expected report gives the five fields. Written by LE2 migration/rune/hand_build.pl. DRR is ISDA's (ISDA DRR License, September 2023): private.")],
                 Items),
    le_write(IR, Text, Issues),
    forall(member(I, Issues), print_message(warning, format("~q", [I]))),
    twins_dir(TD), directory_file_path(TD, 'hand/cftc_part45_hand.le', Out),
    setup_call_cleanup(open(Out, write, S), write(S, Text), close(S)),
    length(Pairs, N), format("~w scenarios written to ~w~n", [N, Out]).

scenario(pair(Name, In, Exp), scenario(Name, Lines, [])) :-
    instance_facts(In, 'drr.regulation.common.TransactionReportInstruction', instruction, Fs),
    reachable_facts(Fs, instruction, Keep),
    findall(fact(G), ( member(f(O, A, V), Keep), hand_attribute(A, _),
                       ir_value(V, IV), G =.. [A, O, IV] ), Facts),
    expected_flat(Exp, Flat),
    findall(expects(Q, Answers),
            ( hand_field(Q, Path, _),
              findall(G, ( member(Path-V, Flat), G =.. [Q, instruction, V] ), Answers) ),
            Exps),
    append(Facts, Exps, Lines).

ir_value(o(Id), Id) :- !.
ir_value(V, V).

%   Only the facts reachable from the root through the attributes the rules
%   read.
reachable_facts(Fs, Root, Keep) :-
    reach([Root], Fs, [Root], Objs),
    include(kept(Objs), Fs, Keep).
reach([], _, Seen, Seen).
reach([O|Os], Fs, Seen, All) :-
    findall(S, ( member(f(O, A, o(S)), Fs), hand_attribute(A, _), \+ memberchk(S, Seen) ), New0),
    list_to_set(New0, New),
    append(Seen, New, Seen1), append(Os, New, Queue),
    reach(Queue, Fs, Seen1, All).
kept(Objs, f(O, A, _)) :- memberchk(O, Objs), hand_attribute(A, _).

/*  Step 4 of the design notes rune.md, §7 question 5: "Where did the
    collateral numbers come from?" — from a credit support annex to DRR's
    margin report, in Logical English all the way.

    ./myswipl.sh -q migration/rune/csa_chain.pl

    1. cdmLOG's gold-standard reading of CSA 1 (CDM 8.0.0-dev.4) is mapped
       to DRR's CDM 6.29 by csa_map.pl: .cache/chain/csa1_cdm629.json.
    2. This script writes examples/migration/rune/cftc_margin/csa1_margin_call.le:
       the annex's terms as facts (each citing its paragraph), the margin
       call of the 1995 ISDA Credit Support Annex (paragraphs 2 and 10) as
       rules, and four valuation dates as scenarios.
    3. It asks the program each valuation date's new credit support balance,
       and writes, for each, DRR's collateral report instruction with that
       balance (.cache/chain/input/csa1/<date>.json) — the shape of DRR's
       own Collateral-ex01, with CSA 1 as the portfolio's legal agreement.
    4. chain.sh then runs DRR's Java on the instructions (the oracle) and
       build.pl writes the margin twin's scenarios from them (csa1.le), each
       with DRR's report as its expectations; in csa1.le the balance is not
       a number but the margin call's answer (csa1.le includes
       csa1_margin_call.le).

    The parties: CSA 1's Party A (Hemingway Limited) is DRR's party1, Party
    B (Bank A) is party2, the reporting counterparty of Collateral-ex01.
*/
:- use_module(rune_paths).
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- use_module(library(main)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(process)).

:- initialization(main, main).

%   cdmLOG's gold-standard reading of the annex, copied into data/csa1/
%   (cdmLOG is private; the copy is kept beside the annex it reads).
gold(G) :-
    (   rune_home(H), format(atom(G0), '~w/data/csa1/CSA 1.md.GOLDEN.pl', [H]), exists_file(G0)
    ->  G = G0
    ;   %  the annex is ISDA's text and is not in this repository: it is
        %  looked for in the private place (../le2_paths.pl, private_root/1)
        le2_paths:private_root(R),
        format(atom(G), '~w/migration/rune/data/csa1/CSA 1.md.GOLDEN.pl', [R])
    ).

%   The valuation dates: the transferee's exposure, and the value of the
%   credit support balance before the date (Party A's, held by Party B).
valuation(csa1_vd1, '2026-10-01', 3250000, 1000000).
valuation(csa1_vd2, '2026-10-02', 2400000, 2250000).
valuation(csa1_vd3, '2026-10-05', 2380000, 1400000).
valuation(csa1_vd4, '2026-10-06', 500000, 1400000).

main([link]) :- !, link.
main(_) :-
    rune_home(H),
    format(atom(CD), '~w/.cache/chain', [H]), make_directory_path(CD),
    format(atom(MJ), '~w/csa1_cdm629.json', [CD]),
    gold(G), format(atom(CM), '~w/csa_map.pl', [H]),
    current_prolog_flag(executable, SW),
    process_create(SW, ['-q', file(CM), '--', G, MJ], [process(P)]), process_wait(P, exit(0)),
    read_json(MJ, CSA),
    load_files(G, [module(csa_gold)]),
    twins_dir(TD), format(atom(LE), '~w/cftc_margin/csa1_margin_call.le', [TD]),
    setup_call_cleanup(open(LE, write, S), write_program(S, CSA), close(S)),
    format("written ~w~n", [LE]),
    le_kbs:load(LE, KB, [skip_tests]),
    format(atom(ID), '~w/input/csa1', [CD]), make_directory_path(ID),
    forall(valuation(Sc, Date, _, _),
           ( new_balance(KB, Sc, B),
             format("~w: the credit support balance after the valuation date is ~w~n", [Sc, B]),
             instruction(CSA, Date, B, J),
             format(atom(F), '~w/~w.json', [ID, Sc]),
             setup_call_cleanup(open(F, write, S2), json_write_dict(S2, J, [width(100)]), close(S2)) )).

read_json(F, D) :- setup_call_cleanup(open(F, read, S), json_read_dict(S, D, [value_string_as(string)]), close(S)).

%   The program's answer: the balance after the valuation date.
new_balance(KB, Sc, B) :-
    le_kbs:createSession(KB, SM), le_kbs:setScenarion(SM, Sc),
    KB:query_info(new_balance, Goal, [query_clause(G, _, _, _, _)|_]),
    once(reasoner:i(Goal, SM, _, _)),
    le_kbs:destroySession(SM),
    G =.. [_|Args], last(Args, B).

% ---------------------------------------------------------------- the program

gold_value(L, V) :- csa_gold:extracted(L, V, _, _).

party_index('Party1', 0, party_a).
party_index('Party2', 1, party_b).

election(CSA, What, Party, V) :-
    Obl = CSA.agreementTerms.agreement.creditSupportAgreementElections.creditSupportObligations,
    get_dict(What, Obl, X), party_index(Party, I, _),
    nth0(I, X.partyElection, E), V = E.amount.value.

write_program(S, CSA) :-
    El = CSA.agreementTerms.agreement.creditSupportAgreementElections,
    R = El.creditSupportObligations.rounding,
    findall(N, ( member(X, CSA.contractualParty.name), unwrapped(X, N) ), Names),
    format(S, "% CSA 1 (~w, ISDA ~w Credit Support Annex, governed by English law), its margin call.~n", [CSA.agreementDate, 1995]),
    format(S, "% Written by LE2 migration/rune/csa_chain.pl. The terms are cdmLOG's gold-standard reading~n% of the annex (checked by hand, 5 March 2026), mapped to DRR's CDM 6.29 by csa_map.pl; the~n% independent amounts have no place in CDM 6.29 and come from cdmLOG's CDM 8 reading.~n% The margin call is paragraphs 2 and 10 of the 1995 annex. Private (rune.md, section 6).~n~n", []),
    format(S, "the target language is: prolog.~n~n", []),
    format(S, "the templates are:~n", []),
    forall(template(T), format(S, "    ~w.~n", [T])),
    format(S, "~nthe knowledge base csa1_margin_call includes:~n~n", []),
    %  the terms
    format(S, "% The parties (the front page of the annex): Party A is ~w, Party B is ~w.~n", Names),
    forall(party_index(P, _, Id), format(S, "~w is a party to the annex.~n", [Id])),
    nl(S),
    forall(( member(W-Lab-Para, [threshold-'AMT08'-'11(b)(iii)(B)', minimumTransferAmount-'AMT04'-'11(b)(iii)(C)']),
             party_index(P, _, Id), election(CSA, W, P, V) ),
           ( term_words(W, TW), passage(Para, P, Q), ( P == 'Party1' -> Lt = 'A' ; Lt = 'B' ),
             format(S, "% cdmLOG label ~w~w~nthe CSA ~w of ~w is ~w,~n    as stated in CSA 1 at paragraph ~w, confer \"~w\".~n~n", [Lab, Lt, TW, Id, V, Para, Q]) )),
    forall(( member(L-Id-P, ['AMT12A'-party_a-'Party1', 'AMT12B'-party_b-'Party2']), gold_value(L, V) ),
           ( passage('11(b)(iii)(A)', P, Q),
             format(S, "% cdmLOG label ~w; read from CDM 8: CDM 6.29 has no place for it~nthe CSA independent amount of ~w is ~w,~n    as stated in CSA 1 at paragraph 11(b)(iii)(A), confer \"~w\".~n~n", [L, Id, V, Q]) )),
    passage('11(b)(iii)(D)', any, QR),
    format(S, "the CSA delivery amount is rounded ~q to a multiple of ~w,~n    as stated in CSA 1 at paragraph 11(b)(iii)(D), confer \"~w\".~n~n", [R.deliveryDirection, R.deliveryAmount, QR]),
    format(S, "the CSA return amount is rounded ~q to a multiple of ~w,~n    as stated in CSA 1 at paragraph 11(b)(iii)(D), confer \"~w\".~n~n", [R.returnDirection, R.returnAmount, QR]),
    unwrapped(El.baseAndEligibleCurrency.baseCurrency, BC),
    format(S, "% Paragraph 11(a)(i)~nthe CSA base currency is ~q.~n~n", [BC]),
    rules(Rules), format(S, "~w", [Rules]),
    %  the valuation dates
    forall(valuation(Sc, Date, E, B),
           format(S, "scenario ~w is:~n    the valuation date is ~w.~n    the exposure of party_b to party_a is ~w.~n    the credit support balance of party_a held by party_b is ~w.~n~n", [Sc, Date, E, B])),
    format(S, "query new_balance is:~n    the new credit support balance of party_a held by party_b is which amount.~n~n", []),
    format(S, "query transfer is:~n    which party transfers which amount to which second party.~n", []).

unwrapped(X, V) :- ( is_dict(X), get_dict(value, X, V0) -> V = V0 ; V = X ).

%   The passage of CSA 1 that states a term (its Paragraph 11), quoted
%   without its inner quotation marks.
passage('11(b)(iii)(A)', 'Party1', 'Independent Amount means with respect to Party A: zero').
passage('11(b)(iii)(A)', 'Party2', 'Independent Amount means with respect to Party B: 1,000,000').
passage('11(b)(iii)(B)', 'Party1', 'Threshold means with respect to Party A: zero').
passage('11(b)(iii)(B)', 'Party2', 'Threshold means with respect to Party B: zero').
passage('11(b)(iii)(C)', 'Party1', 'Minimum Transfer Amount means with respect to Party A: 250,000').
passage('11(b)(iii)(C)', 'Party2', 'Minimum Transfer Amount means with respect to Party B: 250,000').
passage('11(b)(iii)(D)', any, 'The Delivery Amount and the Return Amount will be rounded up and down to the nearest integral multiple of 10,000, respectively').

term_words(threshold, threshold).
term_words(minimumTransferAmount, 'minimum transfer amount').

template('*a party* is a party to the annex').
template('the valuation date is *a date*').
template('the CSA threshold of *a party* is *an amount*').
template('the CSA minimum transfer amount of *a party* is *an amount*').
template('the CSA independent amount of *a party* is *an amount*').
template('the CSA delivery amount is rounded *a direction* to a multiple of *a number*').
template('the CSA return amount is rounded *a direction* to a multiple of *a number*').
template('the CSA base currency is *a currency*').
template('the exposure of *a party* to *a second party* is *an amount*').
template('the credit support balance of *a party* held by *a second party* is *an amount*').
template('the credit support amount of *a transferor* to *a transferee* is *an amount*').
template('the delivery amount of *a transferor* to *a transferee* is *an amount*').
template('the return amount of *a transferee* to *a transferor* is *an amount*').
template('*a party* transfers *an amount* to *a second party*').
template('the new credit support balance of *a party* held by *a second party* is *an amount*').
template('*an amount* rounded *a direction* to a multiple of *a number* is *a rounded amount*').
template('*a money* measures the credit support balance').

rules("% Paragraph 10, \"Credit Support Amount\": the Transferee's Exposure plus all Independent
% Amounts applicable to the Transferor, minus all Independent Amounts applicable to the
% Transferee, minus the Transferor's Threshold; zero whenever that is less than zero.
rule credit_support_amount with provenance 1995 ISDA Credit Support Annex at paragraph 10,
        confer \"Credit Support Amount means, with respect to a Transferor on a Valuation Date, (i) the Transferee's Exposure plus (ii) all Independent Amounts applicable to the Transferor, if any, minus (iii) all Independent Amounts applicable to the Transferee, if any, minus (iv) the Transferor's Threshold\":
the credit support amount of a transferor to a transferee is an amount if
    the transferor is a party to the annex
    and the transferee is a party to the annex
    and the transferor is different from the transferee
    and the exposure of the transferee to the transferor is EXP
    and the CSA independent amount of the transferor is IAOR
    and the CSA independent amount of the transferee is IAEE
    and the CSA threshold of the transferor is TH
    and RAW = EXP + IAOR - IAEE - TH
    and the maximum of RAW and 0 is the amount.

% Paragraph 2(a): the Delivery Amount is the amount by which the Credit Support Amount
% exceeds the Value of the Transferor's Credit Support Balance.
rule delivery_amount with provenance 1995 ISDA Credit Support Annex at paragraph 2(a):
the delivery amount of a transferor to a transferee is an amount if
    the credit support amount of the transferor to the transferee is CSA
    and the credit support balance of the transferor held by the transferee is BAL
    and CSA > BAL
    and the amount = CSA - BAL.

% Paragraph 2(b): the Return Amount is the amount by which the Value of the Transferor's
% Credit Support Balance exceeds the Credit Support Amount.
rule return_amount with provenance 1995 ISDA Credit Support Annex at paragraph 2(b):
the return amount of a transferee to a transferor is an amount if
    the credit support amount of the transferor to the transferee is CSA
    and the credit support balance of the transferor held by the transferee is BAL
    and BAL > CSA
    and the amount = BAL - CSA.

% Paragraph 2(a): the Transferor transfers the Delivery Amount, rounded pursuant to
% Paragraph 11(b)(iii)(D), if it equals or exceeds the Transferor's Minimum Transfer Amount.
rule delivery with provenance 1995 ISDA Credit Support Annex at paragraph 2(a),
        confer \"if the Delivery Amount for that Valuation Date equals or exceeds the Transferor's Minimum Transfer Amount, then the Transferor will transfer to the Transferee Eligible Credit Support\":
a transferor transfers an amount to a transferee if
    the delivery amount of the transferor to the transferee is DA
    and the CSA minimum transfer amount of the transferor is MTA
    and DA >= MTA
    and the CSA delivery amount is rounded a direction to a multiple of M
    and DA rounded the direction to a multiple of M is the amount.

% Paragraph 2(b): the Transferee transfers back the Return Amount, rounded pursuant to
% Paragraph 11(b)(iii)(D), if it equals or exceeds the Transferee's Minimum Transfer Amount.
rule return with provenance 1995 ISDA Credit Support Annex at paragraph 2(b),
        confer \"if the Return Amount for that Valuation Date equals or exceeds the Transferee's Minimum Transfer Amount, then the Transferee will transfer to the Transferor Equivalent Credit Support\":
a transferee transfers an amount to a transferor if
    the return amount of the transferee to the transferor is RA
    and the CSA minimum transfer amount of the transferee is MTA
    and RA >= MTA
    and the CSA return amount is rounded a direction to a multiple of M
    and RA rounded the direction to a multiple of M is the amount.

% Paragraph 11(b)(iii)(D): rounding up and down to the nearest integral multiple.
an amount rounded \"Up\" to a multiple of M is R if
    R = M * ceiling(the amount / M).

an amount rounded \"Down\" to a multiple of M is R if
    R = M * floor(the amount / M).

% The Transferor's Credit Support Balance once the transfers of the valuation date are made.
the new credit support balance of a transferor held by a transferee is an amount if
    the credit support balance of the transferor held by the transferee is BAL
    and the transferor transfers D to the transferee
    and the amount = BAL + D.

the new credit support balance of a transferor held by a transferee is an amount if
    the credit support balance of the transferor held by the transferee is BAL
    and the transferee transfers R to the transferor
    and the amount = BAL - R.

the new credit support balance of a transferor held by a transferee is an amount if
    the credit support balance of the transferor held by the transferee is the amount
    and it is not the case that
        the transferor transfers a second amount to the transferee
    and it is not the case that
        the transferee transfers a third amount to the transferor.

").

% ---------------------------------------------------------------- the instruction

%   DRR's Collateral-ex01 with one portfolio: CSA 1 as its legal agreement
%   (a variation margin agreement: the 1995 annex is one — a reading for the
%   former ISDA lawyer to confirm), and Party A's credit support balance
%   held by Party B (the reporting counterparty) before and after haircut
%   (cash in the base currency: a valuation percentage of 100%).
instruction(CSA0, Date, B, J) :-
    drr_dir(D), format(atom(F), '~w/regulatory-reporting/input/collateral/Collateral-ex01.json', [D]),
    read_json(F, J0),
    %  the agreement as DRR reads it: its identification and date, and the
    %  credit support obligations (the parts whose values are DRR's own
    %  enumerations; cdmLOG's "London" is not a BusinessCenterEnum)
    Obl = CSA0.agreementTerms.agreement.creditSupportAgreementElections.creditSupportObligations,
    CSA1 = _{agreementDate: CSA0.agreementDate, legalAgreementIdentification: CSA0.legalAgreementIdentification,
             agreementTerms: _{agreement: _{creditSupportAgreementElections: _{creditSupportObligations: Obl}}}},
    CSA = CSA1.put(legalAgreementIdentification, CSA0.legalAgreementIdentification.put(agreementName,
              CSA0.legalAgreementIdentification.agreementName.put(creditSupportAgreementMarginType, "VariationMargin"))),
    unwrapped(CSA0.agreementTerms.agreement.creditSupportAgreementElections.baseAndEligibleCurrency.baseCurrency, Cur),
    PR = _{payerPartyReference: _{globalReference: "6ed88044", externalReference: "party1"},
           receiverPartyReference: _{globalReference: "bb49950e", externalReference: "party2"}},
    findall(_{collateralBalanceStatus: "FullAmount", haircutIndicator: H,
              amountBaseCurrency: _{value: B, unit: _{currency: _{value: Cur}}}, payerReceiver: PR},
            member(H, ["PreHaircut", "PostHaircut"]), Bal),
    C0 = J0.collateralDetails.collateral,
    C = C0.put(collateralPortfolio, [_{value: _{collateralBalance: Bal, legalAgreement: _{value: CSA}}}]),
    format(atom(TS), '~wT18:00:00Z', [Date]), atom_string(TS, TSS),
    CDs = J0.collateralDetails.put(collateral, C).put(collateralTimestamp, TSS).put(action, "MARU"),
    J = J0.put(collateralDetails, CDs).

% ---------------------------------------------------------------- the link

%   csa_chain.pl -- link: in the margin twin's scenarios of the chain
%   (csa1.le, written by build.pl from the instructions above), the
%   balance's amount is the margin call's answer instead of a number, and
%   each scenario states its valuation date's exposure and prior balance.
link :-
    twins_dir(TD), format(atom(F), '~w/cftc_margin/csa1.le', [TD]),
    read_file_to_string(F, Tx, []),
    (   sub_string(Tx, _, _, _, "cftc_margin, csa1_margin_call.")
    ->  %  linked already: only the view again
        ( sub_string(Tx, B, _, _, "\nquery new_balance is:") -> sub_string(Tx, 0, B, _, T0) ; T0 = Tx )
    ;   split_string(Tx, "\n", "", Ls0),
        link_lines(Ls0, none, [], Ls),
        atomic_list_concat(Ls, '\n', T0)
    ),
    view(V), string_concat(T0, V, T),
    setup_call_cleanup(open(F, write, S), write(S, T), close(S)),
    format("linked ~w~n", [F]).

link_lines([], _, _, []).
link_lines([L|Ls], Sc, Ms, Out) :-
    (   L == "    cftc_margin."
    ->  Out = ["    cftc_margin, csa1_margin_call."|R], link_lines(Ls, Sc, Ms, R)
    ;   L == "the knowledge base csa1 includes:"
    ->  Out = [L, "",
               "% The amount of the credit support balance is the margin call's answer",
               "% (csa1_margin_call.le: the annex's paragraphs 2 and 10), not a number.",
               "the value attribute of a money is an amount if",
               "    the money measures the credit support balance",
               "    and the new credit support balance of party_a held by party_b is the amount."|R],
        link_lines(Ls, Sc, Ms, R)
    ;   sub_string(L, 0, _, _, "scenario csa1_"), split_string(L, " ", "", [_, Name|_]),
        atom_string(NA, Name), atom_concat(csa1_, V, NA), valuation(V, Date, E, B)
    ->  format(string(L1), "    % the valuation date ~w: the margin call of csa1_margin_call.le", [Date]),
        format(string(L2), "    the exposure of party_b to party_a is ~w.", [E]),
        format(string(L3), "    the credit support balance of party_a held by party_b is ~w.", [B]),
        Out = [L, L1, L2, L3|R], link_lines(Ls, V, [], R)
    ;   split_string(L, " ", "", ["", "", "", "", "the", "amount", "base", "currency", "of", _, "is", M0])
    ->  sub_string(M0, 0, _, 1, M), Out = [L|R], link_lines(Ls, Sc, [M|Ms], R)
    ;   split_string(L, " ", "", ["", "", "", "", "the", "value", "attribute", "of", M1, "is", _]),
        memberchk(M1, Ms)
    ->  format(string(L4), "    ~w measures the credit support balance.", [M1]),
        Out = [L4|R], link_lines(Ls, Sc, Ms, R)
    ;   Out = [L|R], link_lines(Ls, Sc, Ms, R)
    ).

%   A screen for the chain (an LE view, LE2 language.md §17.10): a valuation
%   date's exposure and prior balance, the new balance the annex gives, and
%   the CFTC margin report that follows from it.
view("
query new_balance is:
    the new credit support balance of party_a held by party_b is which amount.

query margin_report is:
    the CFTC Margin field which field of instruction is which value.

the view margin desk is:
    the title is \"CSA 1: from the annex to the CFTC margin report\".
    the case is a scenario.
    the facts about \"the valuation date\" are
        the exposure of party_b to party_a is an amount,
        the credit support balance of party_a held by party_b is a second amount.
    the result is the answer to query new_balance, headed by the amount, in USD.
    the result shows its citations.
    the result shows its reasons.
    the answers to \"the CFTC Margin field which field of instruction is which value\" are listed as \"The CFTC margin report\".
    the result can be flipped.
    the cases are listed with their results.
").

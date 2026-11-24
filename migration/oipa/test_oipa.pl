/*  Tests of the OIPA translator (Phase 2b).

    From the LE2 checkout (/work), after build.pl:

        ./myswipl.sh -q -g run_tests -t halt migration/oipa/test_oipa.pl
*/

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module(oipa_reader).
:- use_module(oipa_twin).
:- use_module(oipa_import).
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).

:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).
:- dynamic here/1.

corpus(P, Dir) :- here(D), atomic_list_concat([D, '/corpus/', P], Dir).
examples_dir(E) :- le2_paths:twins_dir(oipa, E).

:- begin_tests(oipa_reader).

test(operators) :-
    parse_oipa_expr('IssueAgeMV < 18 Or IssueAgeMV > 65', E),
    assertion(E == or(cmp(<, ref('IssueAgeMV'), num(18)), cmp(>, ref('IssueAgeMV'), num(65)))),
    parse_oipa_expr('(GrossAmountMV - PremiumTaxMV) * BonusRateMV', E2),
    assertion(E2 == (ref('GrossAmountMV') - ref('PremiumTaxMV')) * ref('BonusRateMV')),
    parse_oipa_expr('DaysDiffOf(PaidToDateMV,EffectiveDateMV)', E3),
    assertion(E3 == call('DaysDiffOf', [ref('PaidToDateMV'), ref('EffectiveDateMV')])).

test(withdrawal) :-
    corpus(annuity, P), atomic_list_concat([P, '/Withdrawal'], T),
    read_transaction(T, transaction('Withdrawal', _, Math, Checks, [spawn('FullSurrender', [_])], [copy('RemainingValueMV', 'AccountValue')])),
    assertion(memberchk(mathif(_, [mv('SurrenderChargeMV', 'VALUE', _, _, value('0'))]), Math)),
    assertion(length(Checks, 2)).

:- end_tests(oipa_reader).

:- begin_tests(oipa_twins).

%   Every twin reproduces the independent interpreter's values.
test(twins_pass) :-
    examples_dir(E),
    forall(( directory_member(E, F, [extensions([le]), recursive(true)]), file_base_name(F, B), B \== 'temporal.le' ),
           ( runTestsFor(F, R), with_output_to(string(S), print_test_result(R)),
             aggregate_all(count, sub_string(S, _, _, _, "FAIL"), NF), assertion(NF == 0) )).

:- end_tests(oipa_twins).

:- begin_tests(oipa_import).

test(file_open) :-
    corpus(annuity, P), atomic_list_concat([P, '/Withdrawal/Transaction.xml'], F),
    tmp_file(oipa, In), make_directory(In), atomic_list_concat([In, '/Withdrawal.xml'], W), copy_file(F, W),
    assertion(detect_oipa(W)),
    tmp_file(oipa, Out), make_directory(Out),
    once(import_oipa(W, Out, imported(LE, _))),
    assertion(exists_file(LE)),
    delete_directory_and_contents(In), delete_directory_and_contents(Out).

test(lrml_is_not_oipa) :-
    le2_paths:le2_dir(LE2),
    atomic_list_concat([LE2, '/migration/legalruleml/corpus/oasis/ex5-section29new-normal.lrml'], F),
    \+ detect_oipa(F).

%   A lone Transaction.xml: named Transaction, its citations open (the file
%   is where they point), and the note says what was not read.
test(lone_transaction_xml, [setup(( tmp_file(oipa, In), make_directory(In), tmp_file(oipa, Out), make_directory(Out) )),
                            cleanup(( delete_directory_and_contents(In), delete_directory_and_contents(Out) ))]) :-
    corpus(annuity, P), atomic_list_concat([P, '/Withdrawal/Transaction.xml'], F),
    atomic_list_concat([In, '/Transaction.xml'], W), copy_file(F, W),
    import_oipa(W, Out, imported(LE, Notes)),
    file_base_name(LE, B), assertion(B == 'oipa_transaction.le'),
    read_file_to_string(LE, T, []),
    assertion(sub_string(T, _, _, _, "the text of \"Transaction/Transaction.xml\" is at \"sources/Transaction/Transaction.xml\"")),
    atomic_list_concat([Out, '/sources/Transaction/Transaction.xml'], Cited), assertion(exists_file(Cited)),
    assertion(( member(N, Notes), sub_string(N, _, _, _, "not read: ValidateExpressions.xml, SpawnActivities.xml, CopyToPolicyFields.xml, Rates.csv, PlanFields.csv") )).

%   A zipped plan folder (as le_import extracts it): the attached rules and
%   the plan's CSV files are read, the citations open, the other
%   transactions are named.
test(plan_folder, [setup(( tmp_file(oipa, In), make_directory(In), tmp_file(oipa, Out), make_directory(Out) )),
                   cleanup(( delete_directory_and_contents(In), delete_directory_and_contents(Out) ))]) :-
    corpus(annuity, P), atomic_list_concat([In, '/annuity'], Plan), copy_directory(P, Plan),
    assertion(detect_oipa(Plan)),
    import_oipa(Plan, Out, imported(LE, Notes)),
    file_base_name(LE, B), assertion(B == 'annuity_deposit.le'),
    assertion(( member(N, Notes), sub_string(N, 0, _, _, "Read: Transaction.xml, ValidateExpressions.xml, CopyToPolicyFields.xml, PlanFields.csv, Rates.csv.") )),
    assertion(( member(N2, Notes), sub_string(N2, _, _, _, "FullSurrender, Withdrawal") )),
    atomic_list_concat([Out, '/sources/Deposit/Transaction.xml'], Cited), assertion(exists_file(Cited)),
    read_file_to_string(LE, T, []),
    assertion(sub_string(T, _, _, _, "fails the check")).

%   A MathVariable read before a later MathIF reassigns what it reads uses
%   the earlier value; a MathLoop and an SQL MathVariable are residue blocks
%   with ledger rows.
test(order_loops_and_residue, [setup(( tmp_file(oipa, In), make_directory(In), tmp_file(oipa, Out), make_directory(Out) )),
                               cleanup(( delete_directory_and_contents(In), delete_directory_and_contents(Out) ))]) :-
    atomic_list_concat([In, '/Payout.xml'], X),
    setup_call_cleanup(open(X, write, S), format(S, "~s", [
"<Transaction><Fields><Field><Name>GrossAmount</Name><DataType>Money</DataType></Field></Fields><Math><MathVariables>
<MathVariable VARIABLENAME=\"GrossAmountMV\" TYPE=\"FIELD\" DATATYPE=\"DECIMAL\">Activity:GrossAmount</MathVariable>
<MathVariable VARIABLENAME=\"ChargeMV\" TYPE=\"VALUE\" DATATYPE=\"DECIMAL\">100</MathVariable>
<MathVariable VARIABLENAME=\"FirstNetMV\" TYPE=\"EXPRESSION\" DATATYPE=\"DECIMAL\" LOG=\"Yes\">GrossAmountMV - ChargeMV</MathVariable>
<MathIF IF=\"GrossAmountMV &gt; 1000\"><MathVariable VARIABLENAME=\"ChargeMV\" TYPE=\"VALUE\" DATATYPE=\"DECIMAL\">0</MathVariable></MathIF>
<MathVariable VARIABLENAME=\"SecondNetMV\" TYPE=\"EXPRESSION\" DATATYPE=\"DECIMAL\" LOG=\"Yes\">GrossAmountMV - ChargeMV</MathVariable>
<MathLoop VARIABLENAME=\"FundLoop\" TYPE=\"COLLECTION\"><MathVariable VARIABLENAME=\"FundTotalMV\" TYPE=\"EXPRESSION\" DATATYPE=\"DECIMAL\">FundTotalMV + 1</MathVariable></MathLoop>
<MathVariable VARIABLENAME=\"BalanceMV\" TYPE=\"SQL\" DATATYPE=\"DECIMAL\">SELECT Balance FROM AsPolicy</MathVariable>
</MathVariables></Math></Transaction>"]), close(S)),
    import_oipa(X, Out, imported(LE, _)),
    %  a case: the first net amount is read with the charge as it was then
    read_file_to_string(LE, T0, []),
    string_concat(T0, "\nscenario s is:\n    the gross amount of a1 is 5000.\n    the effective date of a1 is 2024-01-01.\n    first_net expects answers [\"the first net of a1 is 4900\"].\n    second_net expects answers [\"the second net of a1 is 5000\"].\n", T1),
    atomic_list_concat([Out, '/case.le'], Case),
    setup_call_cleanup(open(Case, write, S2), write(S2, T1), close(S2)),
    runTestsFor(Case, test_file(_, Rs)),
    assertion(Rs = [_, _]), assertion(forall(member(R, Rs), R = pass(_, _))),
    read_file_to_string(LE, T, []),
    assertion(sub_string(T, _, _, _, "% RESIDUE r1 BEGIN: Payout/Transaction.xml MathVariable BalanceMV")),
    assertion(sub_string(T, _, _, _, "MathLoop FundLoop")),
    assertion(\+ sub_string(T, _, _, _, "unknown")),
    atomic_list_concat([Out, '/oipa_payout.ledger.md'], L), read_file_to_string(L, LT, []),
    assertion(sub_string(LT, _, _, _, "| mathloop | residue |")),
    assertion(sub_string(LT, _, _, _, "MathVariable BalanceMV | mathvariable | residue |")).

:- end_tests(oipa_import).

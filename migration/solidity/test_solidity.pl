/** <module> Tests of the Solidity -> LE-for-LPS pipeline (Phase 1e)

    Run from anywhere (needs `npm install` here, LE2 at /work, LPS2 at /lps2):

        /work/myswipl.sh -q -g "consult('migration/solidity/test_solidity.pl')" \
                         -g "run_tests" -t halt

    The twins are run with LPS2 (`lps state`), a subprocess per run.
*/

:- module(test_solidity, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(sol_front).
:- use_module(sol_migrate).
:- use_module(sol_replay).
:- use_module(sol_import).
:- use_module(le2(le_writer)).
:- use_module(le2(le_kbs)).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).

path_of(Rel, Abs) :- here(H), atomic_list_concat([H, '/', Rel], Abs).

contract(File, Name, C) :-
    path_of(File, Abs),
    sol_compile([Abs], JSON), sol_load(JSON, M), sol_contract(M, Name, C).

%   The LPS laws and constraints of a written program (its bases, when it
%   extends others, found beside it).
laws_of_file(File, Laws) :-
    le_lps:le_lps_file(File, Internal, _, _),
    setup_call_cleanup(open_string(Internal, In), sol_migrate:read_terms(In, Terms), close(In)),
    include(is_law, Terms, Laws).

is_law(T) :- functor(T, F, _), memberchk(F, [d_pre, initiated, terminated, updated]).

same_laws(Laws1, Laws2) :-
    length(Laws1, N), length(Laws2, N),
    forall(member(L, Laws1), ( member(L2, Laws2), L2 =@= L )).

:- begin_tests(solidity_front_end).

%   ERC20.transfer through MyToken's _update override (whenNotPaused):
%   one success path, three revert paths — and `super._update` resolved.
%   (ERC20InvalidSender cannot happen on transfer: msg.sender is never the
%   zero address, and the executor knows it.)
test(transfer_paths) :-
    contract('contracts/MyToken.sol', 'MyToken', C),
    sol_paths(C, transfer, _-Paths),
    include([path(_, _, ok, _)]>>true, Paths, Ok),
    include([path(_, _, revert(_), _)]>>true, Paths, Rev),
    assertion(length(Ok, 1)),
    assertion(length(Rev, 3)),
    findall(R, member(path(_, _, revert(error(R, _)), _), Rev), Rs),
    assertion(msort(Rs, ['ERC20InsufficientBalance', 'ERC20InvalidReceiver', 'EnforcedPause'])),
    %  both writes of the success path are relative: they compose in LPS
    Ok = [path(_, Ws, ok, _)],
    assertion(forall(member(w(_, _, V), Ws), V = rel(_, _))).

%   A contract call the executor does not read is RESIDUE, not a revert.
test(external_call_is_residue) :-
    contract('contracts/Vault.sol', 'Vault', C),
    sol_twin(C, [], program(_, Items), Ledger),
    assertion(memberchk(residue('Vault_borrow', _), Items)),
    assertion(memberchk(entry(borrow, function, residue, _, _, _), Ledger)),
    \+ ( member(lps(d_pre([happens(A, _, _)|_])), Items), functor(A, call_borrow, _) ).

%   The reverts' reasons head their constraints.
test(constraints_carry_their_reasons, [nondet]) :-
    sol_migrate:twin_ir(erc20, program(_, Items), _),
    assertion(memberchk(comment('reverts: ERC20InsufficientBalance'), Items)).

		 /*******************************
		 *  ARITHMETIC THAT CAN REVERT  *
		 *******************************/

%   E3.3/E3.4 of the design notes ExtendingLanguagesCoverage.md §2.1.5.
%   A checked `+ - *` reverts on overflow and a checked `/ %` on a zero
%   divisor, and the twin has to say so — except where it cannot happen, which
%   is most places, and except inside `unchecked`.

%   A contract compiled from text, for the small cases below.
contract_text(Src, Name, C) :-
    tmp_file(soltxt, T), make_directory(T),
    atomic_list_concat([T, '/', Name, '.sol'], F),
    setup_call_cleanup(open(F, write, S), write(S, Src), close(S)),
    sol_compile([F], JSON), sol_load(JSON, M), sol_contract(M, Name, C).

panic_reasons(C, Fn, Reasons) :-
    sol_paths(C, Fn, _-Paths),
    findall(P, member(path(_, _, revert(panic(P)), _), Paths), Reasons).

%   Nothing guards this addition, so the contract has a revert path the
%   program would otherwise not have.
test(unguarded_addition_is_a_revert_path) :-
    contract_text("// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
contract Adder {
    mapping(address => uint256) public total;
    function add(uint256 n) external { total[msg.sender] += n; }
}", 'Adder', C),
    panic_reasons(C, add, Rs),
    assertion(Rs == [17]).

%   And the same addition under a guard that makes it impossible has none:
%   the path's own conditions settle it, so nothing is emitted (sol_prune.pl).
test(guarded_addition_is_pruned) :-
    contract_text("// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
contract Capped {
    uint256 constant CAP = 1000;
    mapping(address => uint256) public total;
    function add(uint256 n) external {
        if (n > CAP) revert('too much');
        if (total[msg.sender] > CAP) revert('full');
        total[msg.sender] += n;
    }
}", 'Capped', C),
    panic_reasons(C, add, Rs),
    assertion(Rs == []).

%   A division whose divisor nothing forbids being zero is Panic 0x12.
test(zero_divisor_is_a_revert_path) :-
    contract_text("// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
contract Divider {
    uint256 public share;
    function split(uint256 total, uint256 parts) external { share = total / parts; }
}", 'Divider', C),
    panic_reasons(C, split, Rs),
    assertion(memberchk(18, Rs)).

%   `unchecked` with its reason: no revert path, the plain arithmetic, and a
%   ledger row carrying the assumption (E3.4).
test(unchecked_with_a_reason_is_a_ledger_row) :-
    contract_text("// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
contract Wrapper {
    mapping(address => uint256) public total;
    function add(uint256 n) external {
        unchecked {
            // Overflow not possible: the caller cannot hold that much
            total[msg.sender] += n;
        }
    }
}", 'Wrapper', C),
    panic_reasons(C, add, Rs),
    assertion(Rs == []),
    sol_twin(C, [], program(_, Items), Ledger),
    assertion(( member(entry(add, 'unchecked block', approximated, M, _, _), Ledger),
                sub_atom(M, _, _, _, 'assumes Overflow not possible') )),
    %  the arithmetic is written plainly: no wrap in the program
    assertion(\+ ( member(lps(updated(_, _, _, Cs)), Items),
                   member(_ is E, Cs),
                   sub_term(S, E), nonvar(S), S = _ mod _ )).

%   `unchecked` with no reason, where the wrap really can happen: the twin
%   wraps as the EVM does, and the ledger says the contract never explained
%   it.
test(unchecked_without_a_reason_wraps) :-
    contract_text("// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
contract Silent {
    mapping(address => uint256) public total;
    function add(uint256 n) external {
        unchecked { total[msg.sender] += n; }
    }
}", 'Silent', C),
    sol_twin(C, [], program(_, Items), Ledger),
    assertion(( member(entry(add, 'unchecked block', approximated, M, _, _), Ledger),
                sub_atom(M, _, _, _, 'no reason given') )),
    assertion(( member(lps(updated(_, _, _, Cs)), Items),
                member(_ is E, Cs),
                W is 2^256, sub_term(S, E), nonvar(S), S = _ mod W )).

:- end_tests(solidity_front_end).

:- begin_tests(solidity_twins).

%   Each reference model's scenario, run by LPS2, ends in the state the EVM
%   reaches for the same calls (the reverting ones leaving no trace).
twin_ends_as_expected(Name) :-
    sol_migrate:twin_text(Name, Text, _),
    %  a directory of its own, with the bases the twin extends beside it
    tmp_file(twin, Dir), make_directory(Dir),
    sol_migrate:copy_bases(Name, Dir),
    atomic_list_concat([Dir, '/', Name, '.le'], File),
    setup_call_cleanup(open(File, write, O), write(O, Text), close(O)),
    run_state(File, Fluents),
    sol_migrate:twin(Name, _, _, Opts),
    memberchk(expected(Exp), Opts),
    forall(member(E, Exp),
           (   E = not(G) -> assertion(\+ member(G, Fluents))
           ;   assertion(memberchk(E, Fluents))
           )).

%   Call by call, the twin (LPS2) refuses exactly the calls the EVM reverts
%   (the catalogue's reverts(Why) marks, which the written scenario shows as
%   comments) and accepts every other.
twin_refuses_what_the_evm_reverts(Name) :-
    sol_migrate:twin(Name, _, _, Opts), memberchk(scenario(Obs), Opts),
    sol_migrate:twins_dir(D), atomic_list_concat([D, '/', Name, '/', Name, '.le'], File),
    sol_migrate:run_trace(File, _, Events),
    forall(( member(O, Obs), sol_migrate:obs_parts(O, E, _, T2, Rev) ),
           (   (   memberchk(T2-Es, Events), memberchk(E, Es) -> Accepted = true ; Accepted = false ),
               (   Rev = reverts(_) -> assertion(Accepted == false) ; assertion(Accepted == true) )
           )).

test(erc20_call_by_call) :- twin_refuses_what_the_evm_reverts(erc20).
test(ownable_call_by_call) :- twin_refuses_what_the_evm_reverts(ownable).
test(pausable_call_by_call) :- twin_refuses_what_the_evm_reverts(pausable).
test(mytoken_call_by_call) :- twin_refuses_what_the_evm_reverts(mytoken).
test(fiat_token_call_by_call) :- twin_refuses_what_the_evm_reverts(fiat_token).
test(airdrop_call_by_call) :- twin_refuses_what_the_evm_reverts(airdrop).

test(erc20, [nondet]) :- twin_ends_as_expected(erc20).
test(ownable, [nondet]) :- twin_ends_as_expected(ownable).
test(pausable, [nondet]) :- twin_ends_as_expected(pausable).
test(mytoken, [nondet]) :- twin_ends_as_expected(mytoken).
test(fiat_token, [nondet]) :- twin_ends_as_expected(fiat_token).
test(airdrop, [nondet]) :- twin_ends_as_expected(airdrop).

%   The LPS terms the front end generates and those LE reads back from the
%   written twin are the same, term by term (up to variable names).
lps_round_trip(Name) :-
    sol_migrate:twin_ir(Name, IR, _), IR = program(_, Items),
    findall(T, ( member(lps(T), Items), T \= initial_state(_) ), Gen),
    le_write(IR, Text),
    lps_terms_of_text(Text, Parsed0),
    include([T]>>( functor(T, F, _), memberchk(F, [d_pre, initiated, terminated, updated]) ), Parsed0, Parsed),
    length(Gen, N), length(Parsed, N),
    forall(member(T, Gen), assertion(( member(P, Parsed), P =@= T ))).

test(round_trip_erc20, [nondet]) :- lps_round_trip(erc20).
test(round_trip_fiat_token, [nondet]) :- lps_round_trip(fiat_token).
test(round_trip_airdrop, [nondet]) :- lps_round_trip(airdrop).

:- end_tests(solidity_twins).

%   the design notes roadmap.md Phase 1e: the five changes that made the
%   twins shorter, each checked on the written twins.
:- begin_tests(solidity_phase_1e).

twin_file(Name, File) :-
    sol_migrate:twins_dir(D), atomic_list_concat([D, '/', Name, '/', Name, '.le'], File).
twin_file_text(Name, Text) :- twin_file(Name, F), read_file_to_string(F, Text, [encoding(utf8)]).

%   (a) Solidity's zero default is the fluent's: no law materialises it, no
%   read has an absent variant.
test(a_defaults) :-
    twin_file_text(erc20, T),
    assertion(sub_string(T, _, _, _, "the balance of *an account* is *an amount*; known as balance; 0 by default.")),
    assertion(\+ sub_string(T, _, _, _, "is a thing")),
    assertion(\+ sub_string(T, _, _, _, "is 0.")),
    twin_file(erc20, F), test_solidity:laws_of_file(F, Laws), length(Laws, N),
    assertion(N =:= 18).

%   (b) MyToken is what it adds to erc20 and pausable (whose files are beside
%   it), and flattened it is the contract's whole translation.
test(b_extends, [nondet]) :-
    twin_file_text(mytoken, T),
    assertion(sub_string(T, _, _, _, "the knowledge base my token extends erc20, pausable.")),
    twin_file(mytoken, F), test_solidity:laws_of_file(F, Laws),
    sol_migrate:twin_full_ir(mytoken, program(_, Items), _),
    findall(L, ( member(lps(L), Items), is_law(L) ), Full),
    assertion(same_laws(Laws, Full)),
    %  the bases beside it are the base twins' own files
    sol_migrate:twins_dir(D),
    forall(member(B, [erc20, pausable, ownable]),
           ( atomic_list_concat([D, '/mytoken/', B, '.le'], Copy), atomic_list_concat([D, '/', B, '/', B, '.le'], Orig),
             read_file_to_string(Copy, CT, []), read_file_to_string(Orig, OT, []), assertion(CT == OT) )).

%   (c) no time is written where no sentence relates two moments.
test(c_no_times) :-
    forall(member(N, [erc20, ownable, pausable, mytoken, fiat_token, vault, airdrop]),
           ( twin_file_text(N, T), assertion(\+ sub_string(T, _, _, _, "from a time")),
             assertion(\+ sub_string(T, _, _, _, "at the time")) )).

%   (d) a batch write over a list: one law per key, by the count of its
%   occurrences; a reduction: a sum over the list; an order-dependent loop:
%   residue.
test(d_loops) :-
    twin_file_text(airdrop, T),
    assertion(sub_string(T, _, _, _, "and an account is in the list\n    and a number is the count of each an element such that")),
    assertion(sub_string(T, _, _, _, "a total is the sum of each an element such that")),
    assertion(sub_string(T, _, _, _, "% RESIDUE Airdrop_payFirstEmpty BEGIN")).

%   (e) `type(uint256).max` is a named constant, read by its name.
test(e_constants) :-
    twin_file_text(erc20, T),
    assertion(sub_string(T, _, _, _, "the constants are:\n    the unlimited allowance is 115792089237316195423570985008687907853269984665640564039457584007913129639935.")),
    assertion(sub_string(T, _, _, _, "and the second amount is different from the unlimited allowance")).

:- end_tests(solidity_phase_1e).

:- begin_tests(solidity_replay).

%   The stored USDC window: every balance and the total supply agree with the
%   chain; a deliberately wrong twin (no zero-default materialisation) does
%   not.
window(File) :- sol_migrate:twins_dir(D), atomic_list_concat([D, '/replay/usdc_window.json'], File).

copy_window(Copy) :-
    window(W), tmp_file(usdc, T), atom_concat(T, '.json', Copy), copy_file(W, Copy).

test(usdc_window_agrees, [setup(copy_window(F)), nondet]) :-
    replay(F, report(NA, NR, _, _)),
    assertion(NR > 100),
    assertion(NA =:= NR).

test(mutant_twin_diverges, [setup(copy_window(F)), cleanup(retractall(sol_front:sol_mutation(_))), nondet]) :-
    assertz(sol_front:sol_mutation(no_default)),
    replay(F, report(NA, NR, _, _)),
    assertion(NA < NR).

%   A replay program is the FiatToken twin with other state and calls: its
%   laws and constraints are the twin's, term by term.
test(replays_are_the_twin, [nondet]) :-
    sol_migrate:twins_dir(D),
    atomic_list_concat([D, '/fiat_token/fiat_token.le'], Twin),
    test_solidity:laws_of_file(Twin, TwinLaws),
    forall(member(R, ['replay/usdc_window.le', 'replay/usdc_window_12.le']),
           ( atomic_list_concat([D, '/', R], RF), test_solidity:laws_of_file(RF, RLaws),
             assertion(test_solidity:same_laws(RLaws, TwinLaws)) )).

:- end_tests(solidity_replay).

:- begin_tests(solidity_e13).

%   LPS atomicity, established by experiment (e13/*.le, README "E13").
state_of(File, Fluents) :- path_of(File, Abs), run_state(Abs, Fluents).

test(a_refused_call_has_no_effect) :-
    state_of('e13/refused_call.le', F),
    assertion(msort(F, [balance(bob, 10), balance(fariba, 90)])).

test(independent_laws_can_lose_tokens) :-
    state_of('e13/vanishing_tokens.le', F),
    assertion(msort(F, [balance(bob, 0), balance(fariba, 90)])).

test(an_unguarded_default_compounds) :-
    state_of('e13/compounding_default.le', F),
    assertion(memberchk(balance(carol, 15), F)).

test(two_writes_of_one_entry_compose) :-
    state_of('e13/self_transfer.le', F),
    assertion(F == [balance(bob, 100)]).

:- end_tests(solidity_e13).

:- begin_tests(solidity_views).

%   The legal view (E10) and the E12 examples answer their questions.
le_tests_pass(Rel) :-
    sol_migrate:twins_dir(D), atomic_list_concat([D, '/', Rel], F),
    le_kbs:runTestsFor(F, test_file(_, Results)),
    assertion(Results \== []),
    assertion(forall(member(R, Results), R = pass(_, _))).

%   Every twin's legal view (LE2's le_lps_legal.pl, computed from the twin
%   and its run, as the editors draw it) agrees with the twin on every call
%   of the twin's own scenario: "may <the call>?" holds exactly when LPS2
%   accepted it, and the effects of an accepted call are the entries it
%   changed.
legal_view_agrees(Name) :-
    sol_migrate:legal_view_text(Name, Text),
    le_kbs:load_text(Text, KB),
    findall(test(Q, S, A, U), KB:le_expected(Q, S, A, U), Ts0),
    (   current_predicate(KB:le_expected_changes/3)
    ->  findall(test_changes(Q, S, Sets), KB:le_expected_changes(Q, S, Sets), Cs)
    ;   Cs = []
    ),
    append(Ts0, Cs, Ts),
    assertion(Ts0 \== []),
    maplist(le_kbs:run_one_test(KB), Ts, Rs),
    assertion(forall(member(R, Rs), R = pass(_, _))),
    sol_migrate:twin(Name, _, _, Opts), memberchk(scenario(Obs), Opts), length(Obs, NObs),
    aggregate_all(count, ( member(pass(Q, _), Rs), sub_atom(Q, 0, _, _, may_call_) ), NMay),
    assertion(NMay =:= NObs).

test(legal_view_erc20, [nondet]) :- legal_view_agrees(erc20).
test(legal_view_ownable, [nondet]) :- legal_view_agrees(ownable).
test(legal_view_pausable, [nondet]) :- legal_view_agrees(pausable).
test(legal_view_mytoken, [nondet]) :- legal_view_agrees(mytoken).
test(legal_view_fiat_token, [nondet]) :- legal_view_agrees(fiat_token).
test(legal_view_vault, [nondet]) :- legal_view_agrees(vault).
test(legal_view_airdrop, [nondet]) :- legal_view_agrees(airdrop).

test(e12_assumable_price) :- le_tests_pass('vault/vault_view.le').

%   vault_oracle.le extends the vault twin: every law and constraint of
%   vault.le is one of its own.
test(e12_oracle_extends_the_twin, [nondet]) :-
    sol_migrate:twins_dir(D),
    atomic_list_concat([D, '/vault/vault.le'], Twin),
    atomic_list_concat([D, '/vault/vault_oracle.le'], Oracle),
    test_solidity:laws_of_file(Twin, TL), test_solidity:laws_of_file(Oracle, OL),
    assertion(TL \== []),
    forall(member(L, TL), assertion(( member(O, OL), O =@= L ))).

test(e12_price_feed_in_the_twin) :-
    sol_migrate:twins_dir(D), atomic_list_concat([D, '/vault/vault_oracle.le'], F),
    run_state(F, Fl),
    assertion(memberchk(feed_price(1), Fl)),
    assertion(memberchk(debt(alice, 150), Fl)).

:- end_tests(solidity_views).

:- begin_tests(solidity_import).

%   File > Open of a .sol (sol_import.pl, the adapter le_import.pl calls).
import_into(Src, Name, LEFile, Notes) :-
    tmp_file(solimp, T), make_directory(T),
    atomic_list_concat([T, '/', Name], In), atomic_list_concat([T, '/out'], Out),
    make_directory(Out),
    setup_call_cleanup(open(In, write, S), write(S, Src), close(S)),
    import_solidity(In, Out, imported(LEFile, Notes)).

%   A reference contract opens as its twin: the same laws and constraints.
test(import_is_the_twin, [nondet]) :-
    path_of('contracts/MyToken.sol', F), read_file_to_string(F, Src, []),
    import_into(Src, 'MyToken.sol', LEFile, Notes),
    %  the three extra rows of each count are the `unchecked` blocks the calls
    %  run through (E3.4): one row per block per call, saying whether the wrap
    %  is impossible along the path or merely assumed by the contract's own
    %  comment
    assertion(member("contract MyToken: 27 elements encoded, 11 approximated, 0 residue (marked TODO)", Notes)),
    sol_migrate:twins_dir(D), atomic_list_concat([D, '/mytoken/mytoken.le'], Twin),
    test_solidity:laws_of_file(Twin, TL), test_solidity:laws_of_file(LEFile, IL),
    assertion(test_solidity:same_laws(IL, TL)),
    read_file_to_string(LEFile, T, []),
    assertion(sub_string(T, _, _, _, "the owner of the token is the initial owner")),
    %  no legal view is written beside it: the editors compute it
    file_directory_name(LEFile, Dir), atomic_list_concat([Dir, '/mytoken_legal_view.le'], LV),
    assertion(\+ exists_file(LV)),
    assertion(le_lps_legal:legal_view_text(T, [], _, _)).

%   A loop over a list parameter that adds to an entry per element is
%   translated (Phase 1e (d)); one whose effect depends on the order (an early
%   exit) is residue: the function's source, verbatim, under a TODO, and the
%   legal view says nothing governs it.
test(import_loop_is_translated, [nondet]) :-
    Src = "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\ncontract Loopy {\n    mapping(address => uint256) public points;\n    address public admin;\n    constructor(address initialAdmin) { admin = initialAdmin; }\n    function award(address who, uint256 n) external {\n        require(msg.sender == admin, \"not admin\");\n        points[who] += n;\n    }\n    function awardMany(address[] calldata who, uint256 n) external {\n        for (uint256 i = 0; i < who.length; i++) { points[who[i]] += n; }\n    }\n    function awardFirst(address[] calldata who, uint256 n) external {\n        for (uint256 i = 0; i < who.length; i++) { if (points[who[i]] == 0) { points[who[i]] += n; break; } }\n    }\n}\n",
    import_into(Src, 'Loopy.sol', LEFile, Notes),
    assertion(member("contract Loopy: 5 elements encoded, 0 approximated, 1 residue (marked TODO)", Notes)),
    read_file_to_string(LEFile, T, []),
    assertion(sub_string(T, _, _, _, "and an account is in the list")),
    assertion(sub_string(T, _, _, _, "% TODO")),
    assertion(sub_string(T, _, _, _, "if (points[who[i]] == 0)")),
    %  not a token: the state belongs to "the contract" (sol_names:holder_noun/2)
    assertion(sub_string(T, _, _, _, "initially the admin of the contract is the initial admin.")),
    test_solidity:laws_of_file(LEFile, Laws), assertion(Laws \== []),
    le_lps_legal:legal_view_text(T, [], VT, _),
    assertion(sub_string(VT, _, _, _, "nothing in the program governs call_award_first")).

%   Sources that do not compile: the program is a TODO with the compiler's
%   reason and the source, verbatim.
test(import_broken_is_todo, [nondet]) :-
    import_into("pragma solidity ^0.8.20;\ncontract Broken { function f( external {} }\n", 'Broken.sol', LEFile, [Why]),
    assertion(sub_string(Why, _, _, _, "compiler refused")),
    read_file_to_string(LEFile, T, []),
    assertion(sub_string(T, 0, _, _, "% TODO")),
    assertion(sub_string(T, _, _, _, "contract Broken { function f( external {} }")).

:- end_tests(solidity_import).

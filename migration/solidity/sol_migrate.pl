/** <module> Solidity twins: the catalogue, the writer, the runner

    Drives sol_front.pl over the reference models (E11) and writes each twin
    as a directory under lps2/examples/migration/solidity/ (le2_paths:twins_dir/2):

        <name>/<name>.le            the LE-for-LPS twin, with a scenario
        <name>/<name>.ledger.md     the migration ledger (le_migration.pl)
        <name>/<name>.ledger.json
        <name>/sources/<Contract>.sol  the contract it was translated from

    (Its legal view is not written: LE2's le_lps_legal.pl computes it from
    the twin whenever it is asked for — the editors' Legal View command;
    legal_view_text/2 draws it with the twin's run, and test_solidity.pl
    checks its questions against that run.)

    and runs twins with LPS2 (`lps state`), which is how the tests and the
    replay (sol_replay.pl) check them.

        ./myswipl.sh -q -g "consult('migration/solidity/sol_migrate.pl')" \
                     -g "sol_migrate:migrate_all" -t halt

    Needs `npm install` in this directory (solcjs, OpenZeppelin), node on
    PATH, and LE2 and LPS2 where ../le2_paths.pl finds them (the ones this
    process runs in, $LE2_DIR and $LPS2_DIR, or checkouts beside this
    repository).
*/

:- module(sol_migrate, [
    migrate_all/0,
    migrate/1,                  % +TwinName
    legal_view_text/2,          % +TwinName, -Text (the twin written first)
    twin_text/3,                % +TwinName, -Text, -Ledger
    twin_ir/3,                  % +TwinName, -IR, -Ledger
    run_state/2,                % +LEFile, -Fluents
    run_state/3,                % +LEFile, +Options, -Fluents
    lps_terms_of_text/2,        % +LEText, -Terms
    observation_lines/3,        % +IR, +Observations, -ScenarioLines
    le2_dir/1, lps2_dir/1, twins_dir/1
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.

% LE2 and LPS2: the ones this process runs in, the environment's, or
% checkouts beside this repository (../le2_paths.pl)
:- use_module('../le2_paths', []).
le2_dir(D) :- le2_paths:le2_dir(D).
lps2_dir(D) :- le2_paths:lps2_dir(D).

:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).
:- use_module(le2(le_lps)).
:- use_module(sol_front).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).

twins_dir(D) :- le2_paths:twins_dir(solidity, D).

		 /*******************************
		 *        THE CATALOGUE         *
		 *******************************/

%   twin(Name, Source, Contract, Options)
%   Options: kb(KB), constructor_args(Args), scenario(Obs), binding(Text),
%   licence(Text), artifact(Text), extends([Twin, ...]) — the twin is written
%   as what it adds to those (the design notes roadmap.md Phase 1e (b)),
%   which must come earlier in the catalogue
twin(erc20, 'contracts/RefERC20.sol', 'RefERC20',
     [ kb('erc20 reference model'),
       constructor_args(["Reference Token", "REF", alice, 1000]),
       artifact('OpenZeppelin Contracts 5.0.2, token/ERC20/ERC20.sol'),
       licence('MIT (OpenZeppelin Contracts)'),
       scenario([ obs(transfer(alice, 300, bob), 1, 2),
                  obs(transfer(bob, 500, carol), 2, 3, reverts('ERC20InsufficientBalance')),
                  obs(approve(bob, dan, 200), 3, 4),
                  obs(transfer_from(dan, 150, bob, carol), 4, 5),
                  obs(transfer_from(dan, 100, bob, carol), 5, 6, reverts('ERC20InsufficientAllowance')),
                  obs(transfer(carol, 150, carol), 6, 7) ]),  % to oneself: unchanged
       expected([ balance(alice, 700), balance(bob, 150), balance(carol, 150),
                  allowance(bob, dan, 50), total_supply(1000) ]) ]).
twin(ownable, 'contracts/RefOwnable.sol', 'RefOwnable',
     [ kb('ownable reference model'),
       constructor_args([alice]),
       artifact('OpenZeppelin Contracts 5.0.2, access/Ownable.sol'),
       licence('MIT (OpenZeppelin Contracts)'),
       scenario([ obs(transfer_ownership(bob, carol), 1, 2, reverts('not the owner')),
                  obs(transfer_ownership(alice, bob), 2, 3),
                  obs(renounce_ownership(alice), 3, 4, reverts('no longer the owner')),
                  obs(renounce_ownership(bob), 4, 5) ]),
       expected([ not(owner(_)) ]) ]).
twin(pausable, 'contracts/RefPausable.sol', 'RefPausable',
     [ kb('pausable reference model'),
       extends([ownable]),
       constructor_args([alice]),
       artifact('OpenZeppelin Contracts 5.0.2, utils/Pausable.sol with access/Ownable.sol'),
       licence('MIT (OpenZeppelin Contracts)'),
       scenario([ obs(pause(bob), 1, 2, reverts('not the owner')),
                  obs(pause(alice), 2, 3),
                  obs(pause(alice), 3, 4, reverts('EnforcedPause')),
                  obs(unpause(alice), 4, 5),
                  obs(pause(alice), 5, 6) ]),
       expected([ owner(alice), paused ]) ]).
twin(mytoken, 'contracts/MyToken.sol', 'MyToken',
     [ kb('my token'),
       extends([erc20, pausable]),
       constructor_args([alice]),
       artifact('an OpenZeppelin Wizard token: ERC20 + Ownable + Pausable (OpenZeppelin Contracts 5.0.2)'),
       licence('MIT (OpenZeppelin Contracts)'),
       scenario([ obs(mint(alice, 1000, bob), 1, 2),
                  obs(transfer(bob, 300, carol), 2, 3),
                  obs(transfer(bob, 5000, carol), 3, 4, reverts('ERC20InsufficientBalance')),
                  obs(mint(bob, 10, bob), 4, 5, reverts('OwnableUnauthorizedAccount')),
                  obs(pause(alice), 5, 6),
                  obs(transfer(carol, 1, bob), 6, 7, reverts('EnforcedPause')),
                  obs(unpause(alice), 7, 8),
                  obs(transfer(carol, 100, carol), 8, 9) ]),
       expected([ total_supply(1000), balance(bob, 700), balance(carol, 300), owner(alice) ]) ]).
twin(fiat_token, 'contracts/FiatTokenSubset.sol', 'FiatTokenSubset',
     [ kb('fiat token subset'),
       constructor_args(['the master minter', 'the pauser', 'the blacklister', 'the owner']),
       artifact('Circle stablecoin-evm contracts/v1 (FiatTokenV1, Ownable, Pausable, Blacklistable), transcribed to Solidity 0.8 in contracts/FiatTokenSubset.sol'),
       licence('Apache-2.0 (Circle stablecoin-evm)'),
       related("Related: ../replay/usdc_window.le and usdc_window_12.le are this twin, laws unchanged, bound to USDC's\nmainnet state and run on a window of its logs (their .results.md: every value agrees with the chain)."),
       scenario([ obs(configure_minter('the master minter', m1, 1000), 1, 2),
                  obs(mint(m1, 600, bob), 2, 3),
                  obs(mint(m1, 600, bob), 3, 4, reverts('exceeds minterAllowance')),
                  obs(transfer(bob, 100, carol), 4, 5),
                  obs(blacklist('the blacklister', carol), 5, 6),
                  obs(transfer(carol, 10, bob), 6, 7, reverts('account is blacklisted')),
                  obs(transfer(bob, 10, carol), 7, 8, reverts('account is blacklisted')),
                  obs(unblacklist('the blacklister', carol), 8, 9),
                  obs(approve(bob, dan, 50), 9, 10),
                  obs(transfer_from(dan, 30, bob, eve), 10, 11),
                  obs(transfer_from(dan, 30, bob, eve), 11, 12, reverts('exceeds allowance')),
                  obs(burn(m1, 1), 12, 13, reverts('exceeds balance')),
                  obs(pause('the pauser'), 13, 14),
                  obs(transfer(bob, 1, eve), 14, 15, reverts('paused')) ]),
       expected([ total_supply(600), balance(bob, 470), balance(carol, 100), balance(eve, 30),
                  allowance(bob, dan, 20), minting_allowance(m1, 400), minter(m1), paused ]) ]).

twin(airdrop, 'contracts/Airdrop.sol', 'Airdrop',
     [ kb('airdrop token'),
       constructor_args([alice, 1000]),
       artifact('contracts/Airdrop.sol: batch calls, the loops over arrays of Phase 1e (d)'),
       licence('MIT'),
       scenario([ obs(airdrop(alice, 5, [bob, carol, bob]), 1, 2),        % bob, listed twice, gets 10
                  obs(burn_each(bob, [3, 4]), 2, 3),
                  obs(burn_each(bob, [30]), 3, 4, reverts('insufficient balance')),
                  obs(airdrop(alice, 1, [dan, 'the zero address']), 4, 5, reverts('zero recipient')) ]),
       expected([ balance(alice, 985), balance(bob, 3), balance(carol, 5), total_supply(993) ]) ]).
twin(vault, 'contracts/Vault.sol', 'Vault',
     [ kb('vault'),
       artifact('contracts/Vault.sol: a collateral vault reading a price feed (the E12 worked example)'),
       related("Related: vault_oracle.le is this twin with the borrow residue below filled in by the E12 convention\n(the price feed as an event and a fluent) — a hand-written extension whose deposit laws are these, checked\nby test_solidity.pl; vault_view.le is its legal-readable view with the price as an assumable question."),
       licence('MIT'),
       scenario([ obs(call_deposit(alice, 100), 1, 2),
                  obs(call_deposit(alice, 50), 2, 3) ]),
       expected([ collateral(alice, 150) ]) ]).

		 /*******************************
		 *          WRITING             *
		 *******************************/

migrate_all :-
    forall(twin(Name, _, _, _), migrate(Name)).

%!  migrate(+Name) is det.
migrate(Name) :-
    twin_text(Name, Text, Ledger),
    twins_dir(Root),
    atomic_list_concat([Root, '/', Name], Dir),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/', Name, '.le'], File),
    write_file(File, Text),
    twin(Name, Src, Contract, Opts),
    copy_source(Src, Dir),
    copy_bases(Name, Dir),
    run_state(File, Fluents),
    option(expected(Exp), Opts, []),
    expected_rows(Name, Exp, Fluents, Rows),
    fidelity_counts(Rows, Fidelity),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    option(artifact(Art), Opts, Src),
    option(licence(Lic), Opts, unknown),
    Meta = [program(Name), source('Solidity'), artifacts([Art, Src]),
            translator('the Solidity translator (with solcjs)'),
            date(Date), licence(Lic)],
    M = migration(Meta, program([], []), Ledger, []),
    ledger_markdown(M, Fidelity, MD0),
    atomic_list_concat([Dir, '/', Name, '.ledger.md'], MDF),
    format(string(Note), "~n## The scenario~n~nThe twin's scenario runs under LPS2 (`lps state ~w.le`); each row of *Source tests* above compares one fluent of the final state with the value the EVM gives for the same calls (the Solidity semantics, worked by hand in sol_migrate.pl's catalogue). Calls the scenario marks `reverts` are refused by the twin's integrity constraints: they leave no trace in the state.~n~nContract: ~w (~w).~n", [Name, Contract, Src]),
    cost_section(File, CostMD, CostDict),
    atomic_list_concat([MD0, Note, CostMD], MD),
    write_file(MDF, MD),
    ledger_dict(M, Fidelity, Dict0),
    Dict = Dict0.put(_{cost: CostDict}),
    atomic_list_concat([Dir, '/', Name, '.ledger.json'], JF),
    setup_call_cleanup(open(JF, write, Out, [encoding(utf8)]), json_write_dict(Out, Dict, [width(100)]), close(Out)),
    format("~w: ~w~n", [Name, File]).

		 /*******************************
		 *   WHAT IT COSTS TO DEPLOY    *
		 *******************************/

%!  cost_section(+LEFile, -Markdown, -Dict) is det.
%
%   The round trip's other half, measured. This twin came *from* a Solidity
%   contract; *Deploy as Solidity* writes it back as one, and a reader of the
%   ledger wants to know what that contract costs before believing any of it —
%   whether it fits under EIP-170 at all, and what a call of the scenario
%   spends. lps_solidity_cost.pl measures it (solc, then a replay on an EVM),
%   so the figures here are of the same fork and optimiser as the ones
%   `lps solidity --cost` prints; where the tools are missing the section says
%   so and the ledger is written without figures rather than with guesses.
cost_section(File, MD, Dict) :-
    (   catch(twin_cost(File, Report), E, ( print_message(warning, E), fail) )
    ->  true
    ;   Report = not_measured('the translator or the EVM tools are not installed here')
    ),
    report_dict(Report, Dict),
    cost_markdown(Report, MD).

report_dict(measured(D), D) :- !.
report_dict(not_measured(W), _{measured: false, reason: W}).

twin_cost(File, Report) :-
    ensure_translator,
    lps_cli:compile_source(le, File, [], P, _), P \== none,
    read_file_to_string(File, Text, []),
    catch(lps_le:lps_le_templates(Text, File, Ts), _, Ts = []),
    lps_solidity:lps_to_solidity(P, [interface(I), templates(Ts), source(Text), origin(File)], R),
    (   R = solidity(Sol, Contract, _)
    ->  lps_solidity_cost:solidity_cost(P, Sol, Contract, I, [], Report)
    ;   %  a twin with residue in it, or one that uses something Solidity has
        %  no straight translation for, is not written back as a contract at
        %  all — which is a fact about this twin and belongs in its ledger,
        %  not a missing tool
        R = refused(Ds), Ds = [D|_], lps_diag:diag_message(D, M),
        format(atom(W), 'this twin is not translated back to Solidity: ~w', [M]),
        Report = not_measured(W)
    ).

%   The translator back to Solidity is LPS2's (src/syntax/lps_solidity.pl in
%   the LPS2 repository), reached through LPS2's lps_plus.pl, exactly as the
%   IDE and the CLI reach it. Loaded on demand: writing a twin needs LE2, not
%   LPS2's translator, and a machine without an LPS2 checkout still writes
%   every twin.
ensure_translator :-
    current_predicate(lps_solidity:lps_to_solidity/3), !.
ensure_translator :-
    use_module(lps2('src/syntax/lps_plus')),
    use_module(lps2('src/edges/lps_le')),
    use_module(lps2('src/edges/lps_cli'), []),
    use_module(lps2('src/syntax/lps_solidity_cost')),
    current_predicate(lps_solidity:lps_to_solidity/3).

cost_markdown(not_measured(W), MD) :- !,
    format(string(MD), "~n## What it costs to deploy~n~nNot measured: ~w~n", [W]).
cost_markdown(measured(C), MD) :-
    ( get_dict(fork, C, Fork) -> true ; Fork = cancun ),
    ( get_dict(optimizer, C, Opt), get_dict(runs, Opt, Runs) -> true ; Runs = 200 ),
    ( get_dict(solc, C, Solc) -> true ; Solc = unknown ),
    get_dict(size, C, Sz),
    ( get_dict(deployed, Sz, Dep) -> true ; Dep = 0 ),
    ( get_dict(creation, Sz, Cre) -> true ; Cre = 0 ),
    DepPct is round(1000 * Dep / 24576) / 10,
    CrePct is round(1000 * Cre / 49152) / 10,
    ( get_dict(deployGas, C, DGS) -> number_string(DG, DGS) ; DG = 0 ),
    ( get_dict(calls, C, Rows) -> true ; Rows = [] ),
    findall(R, ( member(Row, Rows), cost_row(Row, R) ), Rs),
    atomic_list_concat(Rs, '', Table),
    format(string(MD),
"~n## What it costs to deploy~n~n*Deploy as Solidity* writes this twin back as a contract; these are that contract's figures, measured with solc ~w at the ~w fork, optimiser ~w runs. Gas is what the EVM used; *intrinsic* is the 21,000 a transaction pays plus its calldata (EIP-2028); *total* is what the sender is charged.~n~n| | Bytes | Limit | |~n|---|---|---|---|~n| deployed bytecode | ~w | 24,576 (EIP-170) | ~w% |~n| creation code | ~w | 49,152 (EIP-3860) | ~w% |~n~nDeployment: ~w gas.~n~n| Call | Gas | Intrinsic | Total | |~n|---|---|---|---|---|~n~w~n",
        [Solc, Fork, Runs, Dep, DepPct, Cre, CrePct, DG, Table]).

cost_row(Row, S) :-
    get_dict(fn, Row, Fn), get_dict(args, Row, Vs), get_dict(from, Row, From),
    get_dict(gas, Row, G), get_dict(intrinsic, Row, In), get_dict(total, Row, T),
    get_dict(ok, Row, Ok),
    atomic_list_concat(Vs, ', ', A),
    ( From == "" -> Who = '' ; format(atom(Who), '~w: ', [From]) ),
    ( Ok == true -> Note = '' ; Note = 'reverted' ),
    format(string(S), "| `~w~w(~w)` | ~w | ~w | ~w | ~w |~n", [Who, Fn, A, G, In, T, Note]).

expected_rows(Name, Exp, Fluents, Rows) :-
    findall(row(Name, FS, Result, Detail),
            ( member(F, Exp),
              \+ \+ ( numbervars(F, 0, _), format(atom(FS0), '~p', [F]), nb_setval(sol_fs, FS0) ),
              nb_getval(sol_fs, FS),
              (   F = not(G) -> ( \+ member(G, Fluents) -> Result = pass, Detail = none
                               ; Result = fail, format(atom(Detail), 'final state: ~q', [Fluents]) )
              ;   memberchk(F, Fluents) -> Result = pass, Detail = none
              ;   Result = fail, format(atom(Detail), 'final state: ~q', [Fluents])
              ) ),
            Rows).

fidelity_counts(Rows, fidelity(P, F, 0, Rows)) :-
    aggregate_all(count, member(row(_, _, pass, _), Rows), P),
    aggregate_all(count, member(row(_, _, fail, _), Rows), F).

%!  twin_ir(+Name, -IR, -Ledger) is det.
%
%   The twin as written: for a twin that extends others, what it adds to
%   them (its bases' laws, constraints and templates are theirs), with the
%   `extends` sentence in its header. If the contract takes away anything its
%   bases have (a law it overrides), it is written whole instead, and the
%   ledger says why: a replacement would need the bases' laws labelled.
twin_ir(Name, program(H, Items), Ledger) :-
    twin_full_ir(Name, program(H0, Items0), Ledger0),
    twin(Name, _, _, Opts),
    (   option(extends(Bases), Opts), Bases \== []
    ->  bases_items(Bases, BaseItems),
        delta_items(Items0, BaseItems, Items1, Missing),
        (   Missing == []
        ->  Items = Items1,
            atomic_list_concat(Bases, ' and ', BAnd),
            twin(Name, _, Contract, _),
            format(string(XC), "It extends ~w (their twins' files are beside it): their laws, constraints and templates are its own,~nand what follows is what ~w adds to them.", [BAnd, Contract]),
            (   select(comment(C0), H0, H1)
            ->  format(string(C1), "~w~n~w", [C0, XC]), H = [extends(Bases), comment(C1)|H1]
            ;   H = [extends(Bases), comment(XC)|H0]
            ),
            atomic_list_concat(Bases, ', ', BT),
            format(atom(EM), 'the laws, constraints and templates of ~w: theirs, by `extends`; this twin is what the contract adds', [BT]),
            append(Ledger0, [entry(extends, inheritance, encoded, EM, extends(Bases), none)], Ledger)
        ;   Items = Items0, H = H0,
            length(Missing, NM),
            format(atom(EM), '~w law(s) or constraint(s) of the bases are not the contract''s: written whole', [NM]),
            append(Ledger0, [entry(extends, inheritance, approximated, EM, none, none)], Ledger)
        )
    ;   H = H0, Items = Items0, Ledger = Ledger0
    ).

%   Everything the bases have, flattened (a base's own bases included).
bases_items(Bases, Items) :-
    findall(I, ( member(B, Bases), twin_full_ir(B, program(_, BI), _), member(I, BI) ), Items).

%!  delta_items(+Items, +BaseItems, -Delta, -Missing) is det.
%
%   Items without what the bases already have: templates of the same
%   functor, constants, and laws and constraints equal up to variable names,
%   with the comments that head them. Missing: the bases' laws and
%   constraints the contract does not have.
delta_items(Items, BaseItems, Delta, Missing) :-
    findall(T, member(lps(T), BaseItems), BaseTerms0),
    exclude(instance_term, BaseTerms0, BaseTerms),
    findall(T, ( member(T, BaseTerms), \+ ( member(lps(C), Items), C =@= T ) ), Missing),
    exclude(inherited(BaseTerms), Items, Items1),
    maplist(declared_by_base(BaseItems), Items1, Items2),
    drop_orphan_comments(Items2, Delta).

instance_term(initial_state(_)).

inherited(BaseTerms, lps(T)) :- T \= initial_state(_), member(B, BaseTerms), B =@= T, !.

%   A template (or a constant) a base declares stays in the program, for the
%   writer to render its sentences, marked as declared elsewhere (`included`:
%   not written again).
declared_by_base(BaseItems, I0, I) :-
    (   I0 = constant(F, Name, V), memberchk(constant(F, _, _), BaseItems)
    ->  le_writer:constant_template_text(Name, V, Text),
        I = template(F, Text, [included, defines_global(Name)])
    ;   template_like(I0, F), I0 \= constant(_, _, _),
        member(BI, BaseItems), template_like(BI, F)
    ->  I0 =.. [K, F, Text, Adds], I =.. [K, F, Text, [included|Adds]]
    ;   I = I0
    ).

template_like(fluent(F, _, _), F).
template_like(action(F, _, _), F).
template_like(event(F, _, _), F).
template_like(template(F, _, _), F).
template_like(constant(F, _, _), F).

%   A `reverts:` comment whose constraint is gone, and a function's heading
%   comment with nothing of its own left under it.
drop_orphan_comments(Items0, Items) :-
    drop_reverts(Items0, Items1),
    drop_headings(Items1, Items).

drop_reverts([], []).
drop_reverts([comment(C), Next|Rest], Out) :-
    sub_atom(C, 0, _, _, 'reverts: '), Next \= lps(d_pre(_)), !,
    drop_reverts([Next|Rest], Out).
drop_reverts([comment(C)], []) :- sub_atom(C, 0, _, _, 'reverts: '), !.
drop_reverts([I|Is], [I|Os]) :- drop_reverts(Is, Os).

drop_headings([], []).
drop_headings([comment(C)|Rest], Out) :-
    heading(C),
    ( Rest = [] ; Rest = [N|_], ( N = comment(C2), heading(C2) ; \+ law_item(N) ) ), !,
    drop_headings(Rest, Out).
drop_headings([I|Is], [I|Os]) :- drop_headings(Is, Os).

heading(C) :- atom(C), \+ sub_atom(C, 0, _, _, 'reverts: '), \+ sub_atom(C, _, _, _, '\n').
law_item(lps(T)) :- T \= initial_state(_).
law_item(comment(C)) :- sub_atom(C, 0, _, _, 'reverts: ').
law_item(residue(_, _)).

%   The twin with every law, as translated: what its bases' twins are
%   compared with.
twin_full_ir(Name, program(H, Items), Ledger) :-
    twin(Name, Src, Contract, Opts),
    here(Here), atomic_list_concat([Here, '/', Src], SrcFile),
    option(artifact(Art), Opts, Src),
    file_base_name(Src, SrcBase),
    format(string(Cm0), "Twin of ~w (~w), translated by the Solidity translator.~nOne law per success path of each state-changing function, one integrity constraint per revert path;~nthe reverts' reasons are the comments above the constraints. See ~w.ledger.md;~nthe contract itself: sources/~w (File > Show the Original in the Logical English editor, View > The original this was converted from in the LPS2 IDE).~nWho may do what, when, with which effect: the legal view, computed from this program~n(Misc > Legal View of This LPS Program in the Logical English editor, View > Legal view in the LPS2 IDE).", [Contract, Art, Name, SrcBase]),
    (   option(related(Rel), Opts) -> format(string(Cm), "~w~n~w", [Cm0, Rel]) ; Cm = Cm0 ),
    sol_translate([SrcFile], Contract, [comment(Cm)|Opts], program(H0, Items0), Ledger),
    (   option(scenario(Obs), Opts)
    ->  observation_lines(program(H0, Items0), Obs, Lines),
        length(Obs, NObs), MT is NObs + 2,
        (   option(expected(Exp), Opts), Exp \== []
        ->  expected_state_comment(program(H0, Items0), Exp, ExpCm0),
            ExpCm0 = comment(ECT0), atomic_list_concat(Parts, '<twin>', ECT0),
            atomic_list_concat(Parts, Name, ECT), ExpItems = [comment(ECT)]
        ;   ExpItems = []
        ),
        append([Items0, [scenario(one, Lines, [])], ExpItems], Items),
        select(setting(max_time, _), H0, H1), H = [setting(max_time, MT)|H1]
    ;   Items = Items0, H = H0
    ).

twin_text(Name, Text, Ledger) :-
    twin_ir(Name, IR, Ledger),
    le_write(IR, Text, Issues),
    forall(member(issue(error, C, M), Issues), print_message(error, format("~w: ~w", [C, M]))).

%!  observation_lines(+IR, +Observations, -Lines) is det.
%
%   obs(Action, T1, T2) as scenario lines `<the action> from T1 to T2.`;
%   obs(Action, T1, T2, reverts(Why)) — a call the EVM reverts — with a
%   comment line saying so (the twin's constraints refuse it: it leaves no
%   trace in the state).
observation_lines(IR, Obs, Lines) :-
    ir_dicts(IR, Dicts),
    findall(Ls,
            ( member(O, Obs), obs_parts(O, E, T1, T2, Rev),
              render_ground_literal(Dicts, E, S),
              format(atom(L), '~w from ~w to ~w.', [S, T1, T2]),
              (   Rev = reverts(Why)
              ->  format(string(C), "the EVM reverts the next call (~w): the twin's integrity constraints refuse it", [Why]),
                  Ls = [comment(C), raw(L)]
              ;   Ls = [raw(L)]
              ) ),
            LLs),
    append(LLs, Lines).

obs_parts(obs(E, T1, T2), E, T1, T2, accepted).
obs_parts(obs(E, T1, T2, Rev), E, T1, T2, Rev).

%   The state the EVM reaches, as a comment after the twin's scenario — the
%   rows test_solidity.pl checks against LPS2's run of the twin.
expected_state_comment(IR, Exp, comment(Text)) :-
    ir_dicts(IR, Dicts),
    IR = program(_, Items),
    findall(Line,
            ( member(F, Exp),
              (   F = not(G)
              ->  functor(G, GF, _), member(fluent(GF, GT, _), Items),
                  format(string(Line), "  - no fact of the form: ~w", [GT])
              ;   render_ground_literal(Dicts, F, FS), format(string(Line), "  - ~w", [FS])
              ) ),
            Lines),
    atomic_list_concat(Lines, '\n', Body),
    format(string(Text), "The final state of the scenario below: what the EVM gives for the same calls, and what the twin's run~nunder LPS2 reaches (checked by the translator's tests; the calls the scenario marks~nas reverted leave no trace):~n~w~nRun it: Misc > Run in LPS in the Logical English editor, or open it in the LPS2 IDE.~nWho may do what, as queries: the legal view (Misc > Legal View of This LPS Program in the Logical English editor, View > Legal view in the LPS2 IDE).", [Body]).

%   The contract beside its twin, in sources/: the editors' Show the Original
%   opens it from there.
%   A twin that extends others finds its bases the way includes are found,
%   beside it (a local include may not reach a sibling directory): their
%   files are copied into its directory, a base's own bases too.
copy_bases(Name, Dir) :-
    twin(Name, _, _, Opts),
    (   option(extends(Bases), Opts)
    ->  twins_dir(Root),
        forall(member(B, Bases),
               ( atomic_list_concat([Root, '/', B, '/', B, '.le'], From),
                 atomic_list_concat([Dir, '/', B, '.le'], To),
                 copy_file(From, To),
                 copy_bases(B, Dir) ))
    ;   true
    ).

copy_source(Src, Dir) :-
    here(Here), atomic_list_concat([Here, '/', Src], From),
    atomic_list_concat([Dir, '/sources'], SDir), make_directory_path(SDir),
    file_base_name(Src, Base), atomic_list_concat([SDir, '/', Base], To),
    copy_file(From, To).

write_file(File, Text) :-
    setup_call_cleanup(open(File, write, Out, [encoding(utf8)]), write(Out, Text), close(Out)).

		 /*******************************
		 *        RUNNING (LPS2)        *
		 *******************************/

%!  run_state(+LEFile, -Fluents) is det.
%
%   The final state of a run of the twin under LPS2 (`lps state`).
run_state(File, Fluents) :- run_state(File, [], Fluents).

run_state(File, Options, Fluents) :-
    lps2_dir(L), le2_dir(LE),
    atomic_list_concat([L, '/lps'], Lps),
    absolute_file_name(File, Abs),
    option(extra_args(Extra), Options, []),
    append([state, Abs], Extra, Args),
    setup_call_cleanup(
        process_create(Lps, Args,
                       [environment(['LPS_LE2_DIR'=LE]), stdout(pipe(Out)), stderr(pipe(Err)), process(Pid)]),
        ( read_string(Out, _, Text), read_string(Err, _, ErrText) ),
        ( close(Out), close(Err) )),
    process_wait(Pid, _),
    (   catch(term_string(_, "x"), _, true),
        split_string(Text, "\n", "", Lines),
        findall(T, ( member(Line, Lines), Line \== "",
                     catch(term_string(T, Line), _, fail) ), Fluents),
        Fluents \== []
    ->  true
    ;   Fluents = [],
        print_message(warning, format("lps state ~w: ~w", [File, ErrText]))
    ).

%!  lps_terms_of_text(+LEText, -Terms) is det.
%
%   LE -> LPS internal terms, as LPS2 receives them (the getLps payload).
lps_terms_of_text(Text, Terms) :-
    le_lps:le_lps_text(Text, Internal, _, _),
    setup_call_cleanup(open_string(Internal, In), read_terms(In, Terms), close(In)).

read_terms(In, Terms) :-
    read_term(In, T, []),
    ( T == end_of_file -> Terms = [] ; Terms = [T|Rest], read_terms(In, Rest) ).

		 /*******************************
		 *     THE LEGAL VIEW (E10)     *
		 *******************************/

%   The legal view is LE2 core's (le_lps_legal.pl): a fixed transformation of
%   any LE-for-LPS program, computed whenever it is asked for (the editors'
%   Legal View command), never stored. Given the program's run — here LPS2's
%   `lps run` — its scenarios are the states just before each call of the
%   twin's scenario, and its questions whether each call may be made (expected
%   to hold exactly when the run accepted it) and what an accepted call
%   changes. What this module adds, for the tests only, is the run and two
%   hand-reviewed FiatToken scenarios.
:- use_module(le2(le_lps_legal)).

%   Hand-reviewed questions kept beside the generated ones.
legal_view_extra(fiat_token,
    [ scenario(freeze, [ fact(owner('the owner')), fact(blacklister('the blacklister')),
                         fact(pauser('the pauser')), fact(master_minter('the master minter')),
                         fact(balance(carol, 100)), fact(blacklisted(carol)),
                         expects(who_may_blacklist, ["the blacklister may blacklist carol"]),
                         expects(carol_may_transfer, []),
                         expects(unfreeze, [[ "remove: carol is on the blacklist" ]]) ], []),
      scenario(ordinary, [ fact(owner('the owner')), fact(blacklister('the blacklister')),
                           fact(balance(carol, 100)),
                           expects(carol_may_transfer, ["carol may transfer 10 to bob"]),
                           expects(effect_of_transfer,
                                   ["carol transferring 10 to bob results in the balance of bob being 10",
                                    "carol transferring 10 to bob results in the balance of carol being 90"]) ], []) ],
    [ query(who_may_blacklist, may_blacklist(_, carol)),
      query(carol_may_transfer, may_transfer(carol, 10, bob)),
      query(unfreeze, flip(may_transfer(carol, 10, bob))),
      query(effect_of_transfer, results_transfer_balance(carol, 10, bob, _, _)) ]).

%!  legal_view_text(+Name, -Text) is det.
%
%   The twin's legal view, as the editors draw it from the twin and its run,
%   with the hand-reviewed scenarios of legal_view_extra/3 beside the run's.
legal_view_text(Name, Text) :-
    twins_dir(Root),
    atomic_list_concat([Root, '/', Name, '/', Name, '.le'], TwinFile),
    read_file_to_string(TwinFile, TwinText, [encoding(utf8)]),
    run_trace(TwinFile, States, Events),
    file_directory_name(TwinFile, TwinDir),
    le_kbs:load_text(TwinText, TwinDir, KB),
    (   legal_view_extra(Name, XS, XQ)
    ->  maplist(fix_changes, XS, XS1), More = [more_scenarios(XS1), more_queries(XQ)]
    ;   More = []
    ),
    legal_view_kb(KB, [run(States, Events)|More], IR),
    legal_view_write(IR, Text, _).

%!  run_trace(+LEFile, -States, -Events) is det.
%
%   LPS2's run (`lps run`): the state at each time (T-Fluents) and the
%   events it accepted at each time (T-Events).
run_trace(File, States, Events) :-
    lps2_dir(L), le2_dir(LE),
    atomic_list_concat([L, '/lps'], Lps),
    absolute_file_name(File, Abs),
    setup_call_cleanup(
        process_create(Lps, [run, Abs],
                       [environment(['LPS_LE2_DIR'=LE]), stdout(pipe(Out)), stderr(null), process(Pid)]),
        read_string(Out, _, Text),
        close(Out)),
    process_wait(Pid, _),
    split_string(Text, "\n", "", Lines),
    findall(T-Fs, ( member(Line, Lines), trace_line(Line, fluents, T, Fs) ), States),
    findall(T-Es, ( member(Line, Lines), trace_line(Line, events, T, Es) ), Events).

trace_line(Line, Kind, T, Terms) :-
    atom_string(Kind, KS),
    string_concat(KS, "/", Pre), string_concat(Pre, Rest, Line),
    sub_string(Rest, B, _, A, " "), !,
    sub_string(Rest, 0, B, _, TS), number_string(T, TS),
    sub_string(Rest, _, A, 0, TermS0), normalize_space(string(TermS), TermS0),
    term_string(Terms, TermS).

%   A flip expectation's change sets are given as lists of strings.
fix_changes(scenario(N, Lines0, O), scenario(N, Lines, O)) :-
    maplist(fix_line, Lines0, Lines).
fix_line(expects(Q, [[S|Ss]|Sets]), expects_changes(Q, [[S|Ss]|Sets])) :- string(S), !.
fix_line(L, L).

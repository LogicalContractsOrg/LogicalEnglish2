/** <module> Tests of the Miniscript -> LE translator (Phase 1d)

    Run from the LE2 checkout (/work):

        ./myswipl.sh -q -g run_tests -t halt migration/miniscript/test_miniscript.pl
*/

:- module(test_miniscript, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(ms_twin).          % loads LE2 (le2 search path) and miniscript
:- use_module(miniscript).
:- use_module(policies).
:- use_module(le2(le_kbs)).
:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).

:- begin_tests(miniscript_parser).

test(every_catalogue_policy_parses) :-
    forall(twin(Id, Opts),
           ( memberchk(policy(T), Opts),
             assertion(( catch(ms_text_policy(T, _), _, fail) -> true ; print(Id), nl, fail )) )).

test(policy_language) :-
    ms_text_policy("or(99@pk(key_likely),pk(key_unlikely))", P),
    assertion(P == or(pk(key_likely), pk(key_unlikely))).

test(miniscript_fragments_lift_by_bip379) :-
    ms_text_policy("wsh(or_d(pk(A),and_v(v:pkh(B),older(3))))", P1),
    assertion(P1 == or(pk('A'), and(pk('B'), older(3)))),
    ms_text_policy("andor(pk(A),pk(B),and_v(v:pk(C),older(10)))", P2),
    assertion(P2 == or(and(pk('A'), pk('B')), and(pk('C'), older(10)))),
    ms_text_policy("thresh(2,c:pk_h(K),s:sha256(H1),a:hash160(H2))", P3),
    assertion(P3 == thresh(2, [pk('K'), hash(sha256, 'H1'), hash(hash160, 'H2')])),
    ms_text_policy("wsh(multi(2,A,B,C))", P4),
    assertion(P4 == thresh(2, [pk('A'), pk('B'), pk('C')])),
    ms_text_policy("wsh(multi(3,A,B,C))", P5),              % k = n: a conjunction
    assertion(P5 == and(and(pk('A'), pk('B')), pk('C'))).

test(taproot_is_the_key_or_any_leaf) :-
    ms_text_policy("tr(K,{pk(X),and_v(v:older(2),pk(Z))})", P),
    assertion(P == or(pk('K'), or(pk('X'), and(older(2), pk('Z'))))).

test(checksums_and_key_origins) :-
    ms_text_policy("wsh(pk([a5c6b76e/48'/1'/0'/2']tpubX/<0;1>/*))#8ldsjayd", P),
    assertion(P == pk('[a5c6b76e/48\'/1\'/0\'/2\']tpubX/<0;1>/*')).

test(policy_text_round_trip) :-
    forall(twin(_, Opts),
           ( memberchk(policy(T), Opts), ms_text_policy(T, P),
             ms_policy_text(P, T2), ms_text_policy(T2, P2),
             assertion(P2 == P) )).

:- end_tests(miniscript_parser).

:- begin_tests(miniscript_semantics).

test(relative_locks_in_blocks_and_seconds) :-
    assertion(ms_eval(older(1008), attempt([], [], rel(1008, 0), none))),
    assertion(\+ ms_eval(older(1008), attempt([], [], rel(1007, 0), none))),
    ms_older_blocks(4209713, S), assertion(S == seconds(7889408)),
    assertion(ms_eval(older(4209713), attempt([], [], rel(0, 7889408), none))).

test(absolute_locks_keep_their_kind) :-
    assertion(ms_eval(after(840000), attempt([], [], rel(0, 0), 840000))),
    assertion(\+ ms_eval(after(840000), attempt([], [], rel(0, 0), 1735689600))),
    assertion(\+ ms_eval(after(1735689600), attempt([], [], rel(0, 0), 900000))).

test(thresholds) :-
    P = thresh(2, [pk(a), pk(b), older(10)]),
    assertion(ms_eval(P, attempt([a], [], rel(10, 0), none))),
    assertion(\+ ms_eval(P, attempt([a], [], rel(9, 0), none))).

test(satisfactions_are_the_minimal_paths) :-
    ms_text_policy("or(pk(R),and(pk(M),or(and(pk(L),hash160(H)),older(1008))))", P),
    ms_satisfactions(P, Sets),
    assertion(Sets == [[older(1008), sig('M')], [preimage('H'), sig('L'), sig('M')], [sig('R')]]).

%   What consensus reads otherwise is said: a relative lock with bits BIP 68
%   does not read, a path mixing lock kinds.
test(consensus_warnings) :-
    ms_text_policy("and(pk(a),older(65664))", P1), ms_lock_warnings(P1, [W1]),
    assertion(sub_string(W1, _, _, _, "older(128)")),
    ms_text_policy("and(pk(a),older(65535))", P2), assertion(ms_lock_warnings(P2, [])),
    ms_text_policy("or(and(pk(a),and(after(100),after(1700000000))),pk(b))", P3), ms_lock_warnings(P3, [W3]),
    assertion(sub_string(W3, _, _, _, "timelock mixing")).

test(mixed_lock_kinds_never_satisfy) :-
    ms_satisfactions(and(after(100), after(1735689600)), Sets),
    assertion(Sets == []).

:- end_tests(miniscript_semantics).

:- begin_tests(miniscript_twins).

twin_text(Id, Dir, Text) :-
    twin(Id, Opts),
    twin_migration(twin(Id, Opts), Dir, M),
    migration_text(M, Text, Issues),
    assertion(\+ memberchk(issue(error, _, _), Issues)).

%   A twin written, loaded beside its library, run: every expectation of
%   its satisfaction analysis and flip analysis passes.
test(bolt3_received_htlc_end_to_end, [setup(tmp(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    twin(bolt3_received_htlc, Opts),
    build_twin(twin(bolt3_received_htlc, Opts), Dir, report(_, _, counts(_, _, 0), fidelity(P, 0, 0, _))),
    assertion(P >= 15).

%   The LE program and the policy's own semantics agree on EVERY attempt
%   over the policy's keys and preimages, before and after its delays —
%   not just on the analysis's paths.
test(le_agrees_with_the_policy_everywhere, [setup(tmp(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    forall(member(Id, [liana_inheritance, bolt3_received_htlc, hash_threshold, decaying_multisig]),
           agreement(Id, Dir)).

agreement(Id, Root) :-
    twin(Id, Opts),
    atomic_list_concat([Root, '/', Id], Dir), make_directory_path(Dir),
    copy_library(temporal, Dir),
    twin_migration(twin(Id, Opts), Dir, migration(Meta, IR, Ledger, _)),
    memberchk(policy(T), Opts), ms_text_policy(T, Policy),
    ms_keys(Policy, Keys), ms_hashes(Policy, Hs), findall(H, member(hash(_, H), Hs), Pres),
    ms_satisfactions(Policy, Sets),
    ms_twin:all_delays(Policy, Sets, s(_, _, Age, Secs, Lock)),
    ms_twin:features(Policy, Fs),
    memberchk(legend(Legend), Opts), ms_twin:naming(Policy, Legend, Names),
    findall(test(Tid, none, none, Facts, [expects(spendable, Ans)]),
            ( sub_list(Keys, Sigs), sub_list(Pres, Ps),
              member(D, [early, late]),
              ( D == early -> St = s(Sigs, Ps, 0, 0, 0) ; St = s(Sigs, Ps, Age, Secs, Lock) ),
              ms_twin:state_facts(St, Names, Fs, Facts),
              ms_twin:answer(Policy, St, Ans),
              gensym(attempt_, Tid) ),
            Tests),
    atomic_list_concat([Dir, '/agreement.le'], File),
    migration_text(migration(Meta, IR, Ledger, Tests), Text, _),
    setup_call_cleanup(open(File, write, O), write(O, Text), close(O)),
    le_kbs:runTestsFor(File, test_file(_, Results)),
    include(is_spendable_result, Results, Rs),
    length(Tests, NT), length(Rs, NR),
    assertion(NR =:= NT),
    assertion(forall(member(R, Rs), R = pass(_, _))).

is_spendable_result(R) :- arg(1, R, spendable).

sub_list([], []).
sub_list([X|Xs], [X|Ys]) :- sub_list(Xs, Ys).
sub_list([_|Xs], Ys) :- sub_list(Xs, Ys).

tmp(Dir) :- tmp_file(ms_twin, Dir), make_directory(Dir).

:- end_tests(miniscript_twins).

:- begin_tests(miniscript_import).

:- use_module(ms_import).

%   File ▸ Open of a policy file (le_import's adapter): a program per
%   policy, the unreadable line a TODO block, the file's own tests green.
test(policy_file_import) :-
    plunit_miniscript_twins:tmp(Dir), atomic_list_concat([Dir, '/in'], In), make_directory(In),
    atomic_list_concat([Dir, '/out'], Out), make_directory(Out),
    atomic_list_concat([In, '/Custody Policies.policy'], F),
    setup_call_cleanup(open(F, write, S),
        format(S, "# The BOLT #3 to_local policy~nkey_revocation = the revocation key~nkey_local = the local node~nor(pk(key_revocation),and(pk(key_local),older(1008)))~nnot a policy(~nwsh(multi(2,A,B,C))~n", []),
        close(S)),
    assertion(detect_miniscript(F)),
    import_miniscript(F, Out, imported(LE, Notes)),
    assertion(file_base_name(LE, 'custody_policies.le')),
    read_file_to_string(LE, Text, []),
    assertion(sub_string(Text, _, _, _, "% TODO")),
    assertion(sub_string(Text, _, _, _, "not a policy(")),
    assertion(sub_string(Text, _, _, _, "the revocation key <- key_revocation")),
    atomic_list_concat([Out, '/custody_policies_2.le'], LE2), assertion(exists_file(LE2)),
    assertion(( member(N, Notes), sub_string(N, _, _, _, "TODO") )),
    forall(member(File, [LE, LE2]),
           ( le_kbs:runTestsFor(File, test_file(_, Rs)),
             assertion(Rs \== []),
             assertion(forall(member(R, Rs), functor(R, pass, _))) )).

test(not_a_policy_file, [fail]) :-
    plunit_miniscript_twins:tmp(Dir), atomic_list_concat([Dir, '/x.txt'], F),
    setup_call_cleanup(open(F, write, S), format(S, "hello world~n", []), close(S)),
    detect_miniscript(F).

:- end_tests(miniscript_import).

		 /*******************************
		 *  ORIGINALS, EXPORT, THE CHAIN *
		 *******************************/

:- begin_tests(miniscript_way_back).

:- use_module(ms_export).
:- use_module(ms_chain).
:- use_module('../le2_paths', []).
:- use_module(ms_import).

twins_dir(D) :- le2_paths:twins_dir(miniscript, D).

%   A policy with its keys and hashes by role, in the normal form.
role_policy(P, Map, C) :- rolify(P, Map, R), canonical_policy(R, C).

rolify(pk(K), Map, pk(R)) :- !, ( memberchk(K-R, Map) -> true ; R = K ).
rolify(hash(F, H), Map, hash(F, R)) :- !, ( memberchk(H-R, Map) -> true ; R = H ).
rolify(and(A, B), M, and(A1, B1)) :- !, rolify(A, M, A1), rolify(B, M, B1).
rolify(or(A, B), M, or(A1, B1)) :- !, rolify(A, M, A1), rolify(B, M, B1).
rolify(thresh(K, Ps), M, thresh(K, Qs)) :- !, rolify_list(Ps, M, Qs).
rolify(P, _, P).
rolify_list([], _, []).
rolify_list([P|Ps], M, [Q|Qs]) :- rolify(P, M, Q), rolify_list(Ps, M, Qs).

source_roles(Id, C) :-
    twin(Id, Opts), twin_policy(twin(Id, Opts), P, Names, _),
    findall(K-R, ( member(pk(K)-R, Names) ; member(hash(K)-R, Names) ), Map),
    role_policy(P, Map, C).

program_roles(File, C) :-
    file_directory_name(File, D), read_file_to_string(File, S, []),
    le_kbs:load_text(S, D, KB), le_writer:kb_to_ir(KB, IR),
    kb_policy(IR, P, info(_, Legend, _, _)),
    role_policy(P, Legend, C).

%   File ▸ Export of every twin gives back the source's policy: the same
%   spending paths, keys and hashes by role, locks and hash functions.
test(export_gives_back_the_source_policy) :-
    twins_dir(D),
    forall(twin(Id, _),
           ( format(atom(F), '~w/~w/~w.le', [D, Id, Id]),
             source_roles(Id, CS), program_roles(F, CP),
             assertion(( CS == CP -> true ; print(Id-CS-CP), nl, fail )) )).

%   sources/<id>.policy, opened again through File ▸ Open, is the twin:
%   the same policy, and its own tests pass.
test(the_policy_original_reimports, [setup(tmp_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    twins_dir(D),
    forall(twin(Id, _),
           ( format(atom(PF), '~w/~w/sources/~w.policy', [D, Id, Id]),
             assertion(exists_file(PF)),
             format(atom(Out), '~w/~w', [Dir, Id]), make_directory(Out),
             ms_import:import_miniscript(PF, Out, imported(LE, _)),
             source_roles(Id, CS), program_roles(LE, CI),
             assertion(( CS == CI -> true ; print(Id-CS-CI), nl, fail )) )).

%   A satisfaction scenario is named after the rule its path satisfies
%   (`revocation`, or `family_2` for the second path of rule `family`), not
%   by the order the analysis finds the paths in; and it satisfies that rule.
test(scenarios_named_after_their_rules) :-
    twin(bolt3_received_htlc, Opts),
    twin_policy(twin(bolt3_received_htlc, Opts), _, _, Named),
    pairs_keys(Named, Ns),
    assertion(Ns == [remote_with_preimage_or_timeout_1, remote_with_preimage_or_timeout_2, revocation]),
    twins_dir(D),
    forall(twin(Id, _),
           ( format(atom(F), '~w/~w/~w.le', [D, Id, Id]), read_file_to_string(F, S, []),
             forall(( sub_string(S, B, _, _, "\nscenario "), B1 is B + 10,
                      sub_string(S, B1, _, 0, Rest), once(sub_string(Rest, NL, _, _, "\n")), sub_string(Rest, 0, NL, _, Line),
                      sub_string(Line, E, _, 0, " is, as stated in the satisfaction analysis of the policy:"),
                      sub_string(Line, 0, E, _, Name), Name \== "no_witness",
                      \+ sub_string(Name, _, _, _, "_without_") ),
                    ( rule_of_scenario(S, Name) -> true ; format("~w: no rule for scenario ~w~n", [Id, Name]), fail )),
             assertion(sub_string(S, _, _, _, " is, as stated in the satisfaction analysis of the policy:")) )).

rule_of_scenario(Text, Name) :-
    (   format(string(R), "rule ~w with", [Name]), sub_string(Text, _, _, _, R)
    ->  true
    ;   sub_string(Name, B, _, A, "_"), A > 0, sub_string(Name, _, A, 0, K), number_string(_, K),
        sub_string(Name, 0, B, _, L), format(string(R), "rule ~w with", [L]), sub_string(Text, _, _, _, R)
    ).

%   The chain run of a twin is in it as scenarios citing the run.
test(chain_runs_are_scenarios) :-
    twins_dir(D),
    forall(( twin(Id, _), chain_record(Id, tape, _) ),
           ( format(atom(F), '~w/~w/~w.le', [D, Id, Id]), read_file_to_string(F, S, []),
             assertion(sub_string(S, _, _, _, "scenario chain_")),
             assertion(sub_string(S, _, _, _, "is, as stated in the Tape run")),
             assertion(\+ sub_string(S, _, _, _, "scenario chain_path_1 ")),
             format(atom(J), '~w/~w/sources/~w.chain.json', [D, Id, Id]),
             assertion(exists_file(J)) )).

test(minsc_link_carries_the_code) :-
    minsc_url("pk(A) && older(10)", U),
    assertion(sub_atom(U, 0, _, _, 'https://min.sc/#c=')),
    sub_atom(U, 18, _, 0, E), uri_encoded(fragment, Back, E),
    assertion(Back == 'pk(A) && older(10)').

tmp_dir(Dir) :- tmp_file(msway, Dir), make_directory(Dir).

%   A condition outside the policy vocabulary is not dropped (the coin
%   would be spendable in cases the program forbids): the export refuses,
%   at that condition. Every twin passes the check.
test(unreadable_condition_refused) :-
    T = "the target language is: prolog.\n\nthe templates are:\n    the coin can be spent.\n    the witness contains a signature by *a key*; scenario element.\n    the owner is happy.\n\nthe knowledge base t includes:\n\nthe coin can be spent if\n    the witness contains a signature by key 1\n    and the owner is happy.\n",
    le_kbs:load_text(T, KB),
    export_miniscript(KB, [text(T)], R),
    assertion(R = refused([problem(at(_, _), _)])),
    twins_dir(D),
    forall(twin(Id, _),
           ( format(atom(F), '~w/~w/~w.le', [D, Id, Id]),
             read_file_to_string(F, TT, []), file_directory_name(F, FD), le_kbs:load_text(TT, FD, KB1),
             check_miniscript(KB1, [text(TT)], Ps),
             assertion(( Ps == [] -> true ; print(Id-Ps), nl, fail )) )).

:- end_tests(miniscript_way_back).

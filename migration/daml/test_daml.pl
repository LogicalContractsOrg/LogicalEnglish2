/** <module> Tests of the Daml translator (Phase 2g)

    From the LE2 checkout (/work), after fetch_sources.sh and build.pl:

        ./myswipl.sh -q -g run_tests -t halt migration/daml/test_daml.pl

    The oracle's runs (runs/, Daml on a Canton sandbox) are read, not made:
    making them is daml_oracle.pl's (daml_oracle:oracle_run/2). The gate of the
    way back (daml_gate.pl) runs Daml too; its last results are in
    runs/gate.txt and are checked here.
*/

:- module(test_daml, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module(library(process)).
:- use_module(daml_syntax).
:- use_module(daml_model).
:- use_module(daml_twin).
:- use_module(daml_oracle).
:- use_module(daml_export).
:- use_module(daml_import).
:- use_module(corpus).
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).

here(D) :- module_property(test_daml, file(F)), file_directory_name(F, D).
twins_dir(D) :- le2_paths:twins_dir(daml, D).
%   LPS2's Logical English example Name (or, for '', their directory).
lps2_le_example(Name, Path) :-
    le2_paths:lps2_dir(L),
    (   Name == '' -> atomic_list_concat([L, '/examples/le'], Path)
    ;   atomic_list_concat([L, '/examples/le/', Name], Path)
    ).

:- begin_tests(daml_reader).

%   Every file of the corpus reads (what the subset does not cover is kept
%   as other(Kind, Text), never an error).
test(corpus_reads) :-
    cache_dir(C),
    forall(( project(_, _, Tpl, Rels), member(R, Rels) ),
           ( atomic_list_concat([C, '/', Tpl, '/', R], F), assertion(daml_module(F, module(_, _))) )).

test(layout_and_records) :-
    daml_text_module("module M where\n\ntemplate Asset\n  with\n    issuer : Party\n    owner  : Party\n  where\n    signatory issuer\n    choice Give : ContractId Asset\n      with newOwner : Party\n      controller owner\n      do create this with owner = newOwner\n", module('M', [template('Asset', Fs, Body)])),
    assertion(Fs == [issuer-con('Party', []), owner-con('Party', [])]),
    assertion(memberchk(choice(consuming, 'Give', _, [newOwner-con('Party', [])], [var(owner)],
                               [expr(app(var(create), [rec(this, [owner-var(newOwner)])]))]), Body)).

:- end_tests(daml_reader).

:- begin_tests(daml_twins).

%   Every script Daml ran (runs/): the twin, run by LPS2, ends with the
%   active contracts Daml ends with (their payloads; the ids are the
%   ledger's).
test(final_state_is_damls, [forall(( project(Id, _, _, _), oracle_final_states(Id, States), member(S-Fs, States) ))]) :-
    twins_dir(D), snake(S, SS),
    format(atom(F1), '~w/~w/~w.le', [D, Id, Id]), format(atom(F2), '~w/~w/~w_~w.le', [D, Id, Id, SS]),
    ( exists_file(F2) -> F = F2 ; F = F1 ),
    twin_final_state(F, Twin),
    (   expected_difference(Id, S, Why) -> assertion(Twin \== Fs), print_message(informational, format("~w ~w: ~w", [Id, S, Why]))
    ;   assertion(Twin == Fs)
    ).

%   File ▸ Open of a .daml file.
test(file_open, [setup(( tmp_file(daml, D), make_directory(D) )), cleanup(delete_directory_and_contents(D))]) :-
    cache_dir(C), atomic_list_concat([C, '/daml-intro-choices/daml/SimpleIou.daml'], F),
    assertion(detect_daml(F)),
    import_daml(F, D, imported(LE, Notes)),
    assertion(exists_file(LE)),
    %  what the user reads names no path of this repository
    read_file_to_string(LE, LET, []),
    assertion(\+ ( member(T, [LET|Notes]), sub_string(T, _, _, _, "lpsPlus") )),
    le2_paths:le2_dir(LE2), atom_concat(LE2, '/examples/moreExamples/citizenship.le', Cit),
    assertion(\+ detect_daml(Cit)).

%   The translation does not depend on what was loaded before it. A server
%   that loads library(sandbox) first (LE2's le_service, the LPS2 IDE) makes
%   library(apply_macros) global, which compiles yall lambdas: a variable
%   of the clause used inside a lambda without `{V}/` is then a fresh one
%   (under plain call/N it is copied with its binding). Every choice was
%   residue that way.
test(file_open_load_order, [setup(( tmp_file(dm, D), make_directory(D) )), cleanup(delete_directory_and_contents(D))]) :-
    cache_dir(C), atomic_list_concat([C, '/daml-intro-choices/daml/SimpleIou.daml'], F),
    import_in_process(D, plain, F, T1),
    import_in_process(D, macros, F, T2),
    assertion(T1 == T2),
    assertion(\+ sub_string(T1, _, _, _, "RESIDUE")).

import_in_process(D, Mode, F, Text) :-
    here(H), atomic_list_concat([H, '/daml_import'], M),
    atomic_list_concat([D, '/', Mode], Out), make_directory(Out),
    ( Mode == macros -> Pre = "use_module(library(apply_macros)), " ; Pre = "" ),
    format(string(G), "~wuse_module('~w'), import_daml('~w', '~w', imported(LE, _)), write(LE)", [Pre, M, F, Out]),
    current_prolog_flag(executable, Swipl),
    process_create(Swipl, ['-q', '-g', G, '-t', halt], [stdout(pipe(S)), stderr(null)]),
    read_string(S, _, LE), close(S),
    read_file_to_string(LE, Text, []).

:- end_tests(daml_twins).

%   Where the twin cannot follow Daml, and why (README, Results).
:- multifile expected_difference/3.
:- dynamic expected_difference/3.

expected_difference(restrictions, test_restrictions,
    "Redeem reads the ledger's time (getTime) and branches on a case; the ensure's T.length/T.isUpper conjuncts are Text functions: residue, so the twin keeps IOUs Daml redeems").
expected_difference(compose, test_trade,
    "the script passes a value it queried from the ledger (queryContractId) into Trade's create: the symbolic run of the script does not know ledger values").
expected_difference(coin_issuance, coinIssuance,
    "Lock takes a maturity time (addRelTime now (days 2)) and Clawback/Unlock compare it with getTime: time is not stated, so the lock and what follows are skipped").
expected_difference(multiparty, multiplePartyAgreementTest,
    "Sign asserts elem of the function toSign (a record pattern, filter, notElem) and Finalize compares sorted lists: both residue, so the twin ends with the Pending contract Daml finalizes into an Agreement").

:- begin_tests(daml_export).

%   The way back refuses what it cannot state, with the reason.
test(refusals) :-
    lps2_le_example('bank_transfer.le', BT), read_file_to_string(BT, T, []),
    lps2_le_example('', LeDir), le_kbs:load_text(T, LeDir, KB),
    export_daml(KB, [text(T)], Result),
    assertion(Result = refused(_)),
    Result = refused(Problems),
    assertion(( member(problem(line(L), N), Problems), integer(L), sub_string(N, _, _, _, "reactive rule") )).

%   A Daml twin written back as Daml: one State contract, a choice per
%   action, the script.
test(twin_back_to_daml) :-
    twins_dir(D), atomic_list_concat([D, '/skeleton/skeleton.le'], F),
    read_file_to_string(F, T, []),
    le_kbs:load_text(T, D, KB),
    export_daml(KB, [text(T)], exported(_, Daml, _, _)),
    assertion(sub_string(Daml, _, _, _, "template State")),
    assertion(sub_string(Daml, _, _, _, "choice Give : ContractId State")),
    assertion(sub_string(Daml, _, _, _, "trySubmit")).

%   LE2's own token (defaults, a constant, a list and counting) and its
%   fee variant (a party a law names) are written back.
test(token_back_to_daml) :-
    lps2_le_example('token.le', TokF), lps2_le_example('fee_token.le', FeeF),
    forall(member(F-Wants, [TokF-["firstOr 0.0", "list : [Party]", "account : Party", "1000000.0", "intToDecimal (length"],
                            FeeF-["p_thetreasury : Party", "p_thetreasury = p_thetreasury"]]),
           ( read_file_to_string(F, T, []),
             lps2_le_example('', LeDir), le_kbs:load_text(T, LeDir, KB),
             export_daml(KB, [text(T)], exported(_, Daml, _, _)),
             forall(member(W, Wants), assertion(sub_string(Daml, _, _, _, W))) )).

%   A twin's list of parties (Daml's `observers : [Party]`, the place
%   `observers party list`) goes back as `[Party]`, never `[Text]`; the
%   header names no path of this repository.
test(party_lists_back_to_daml) :-
    twins_dir(D), atomic_list_concat([D, '/quickstart/quickstart.le'], F),
    read_file_to_string(F, T, []),
    le_kbs:load_text(T, D, KB),
    export_daml(KB, [text(T)], exported(_, Daml, _, _)),
    assertion(sub_string(Daml, _, _, _, "observersPartyList : [Party]")),
    assertion(\+ sub_string(Daml, _, _, _, "[Text]")),
    assertion(\+ sub_string(Daml, _, _, _, "lpsPlus")).

%   The gate's last run (daml_gate:gate_main, on a Canton sandbox): every
%   program the exporter accepts ends, on Canton, in LPS2's final state.
test(gate, [condition(( here(H), atomic_list_concat([H, '/runs/gate.txt'], G), exists_file(G) ))]) :-
    here(H), atomic_list_concat([H, '/runs/gate.txt'], G),
    read_file_to_string(G, S, []),
    assertion(\+ sub_string(S, _, _, _, "DIFFERS")),
    assertion(sub_string(S, _, _, _, "SAME")).

:- end_tests(daml_export).

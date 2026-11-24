/** <module> Tests of the Drools -> LE translator (Phase 2e)

    Run from the LE2 checkout (/work), with the oracle built and the model
    compiled (see README):

        ./myswipl.sh -q -g run_tests -t halt migration/drools/test_drools.pl
*/

:- module(test_drools, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(drl_twin).
:- use_module(drl_import).
:- use_module(corpus).
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).

twins_dir(D) :- le2_paths:twins_dir(drools, D).

%   The Drools oracle, built (`mvn -q package` in oracle/), and the fact
%   model, compiled (compile_model.sh): a case written against Java classes
%   asks the oracle for their fields, and is skipped without them.
oracle_built :-
    here(H),
    atomic_list_concat([H, '/oracle/target/drl-oracle-1.0.jar'], Jar), exists_file(Jar),
    atomic_list_concat([H, '/model'], Model), exists_directory(Model).
model_there(Opts) :- ( memberchk(model([_|_]), Opts) -> oracle_built ; true ).

:- begin_tests(drools_twins).

%   Every stateful twin, run by LPS2, ends in the working memory Drools
%   ends in on the same facts and steps (the oracle's run, recorded beside
%   the twin).
test(final_state_is_drools, [forall(( case(Id, Opts), model_there(Opts) ))]) :-
    twins_dir(D),
    format(atom(LE), '~w/~w/~w.le', [D, Id, Id]),
    format(atom(J), '~w/~w/sources/~w.drools.json', [D, Id, Id]),
    setup_call_cleanup(open(J, read, S), json:json_read_dict(S, Reply), close(S)),
    %  Drools' final facts, read as the twin reads them (the world reading
    %  of the rule base: a boolean field a state of its own, a field every
    %  fact gives one value left out)
    drl_twin:case_world(case(Id, Opts), _),
    once(case_final_state(Reply, Expected)),
    once(twin_final_state(LE, Actual)),
    assertion(Expected == Actual).

%   The decision-service twins pass the Drools run's expectations.
test(decision_twins_pass, [forall(( twins_dir(D), case(Id, _),
                                    format(atom(F), '~w/~w/~w_decision.le', [D, Id, Id]), exists_file(F) ))]) :-
    le_kbs:runTestsFor(F, test_file(_, Rs)),
    assertion(Rs \== []),
    assertion(forall(member(R, Rs), functor(R, pass, _))).

%   File ▸ Open of a .drl: LE for LPS, and the decision twin when it only
%   inserts.
test(file_open_adapter, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    module_property(drl_twin, file(F)), file_directory_name(F, M),
    atomic_list_concat([M, '/corpus/drl/discount.drl'], DRL),
    assertion(detect_drl(DRL)),
    import_drl(DRL, D, imported(LE, Notes)),
    assertion(exists_file(LE)),
    assertion(Notes = [_, _]),
    atomic_list_concat([D, '/discount_decision.le'], LE2), assertion(exists_file(LE2)).

%   File ▸ Open with no working memory and no fact model: a field a
%   condition compares with a constant is kept (`not Customer( tier == "gold"
%   )` is not "no customer"), and the note counts each salience once.
test(file_open_keeps_compared_fields, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    corpus_drl('discount.drl', DRL),
    import_drl(DRL, D, imported(LE, [N1|_])),
    read_file_to_string(LE, S, []),
    assertion(sub_string(S, _, _, _, "it is not the case that there is a customer called the customer with tier gold")),
    assertion(sub_string(N1, _, _, _, "0 rule(s) encoded, 2 approximated (salience, a rule attribute, a value computed in Java)")).

%   A rule base written against Java classes, opened without them: the
%   politician keeps the name its Java reads, and insertLogical is an
%   intensional fluent.
test(file_open_undeclared_types, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    corpus_drl('HonestPolitician.drl', DRL),
    import_drl(DRL, D, imported(LE, [N1])),
    read_file_to_string(LE, S, []),
    assertion(sub_string(S, _, _, _, "there is a politician called *a name*")),
    assertion(sub_string(S, _, _, _, "there is a hope at a time if")),
    assertion(sub_string(N1, _, _, _, "1 approximated (salience, a rule attribute, a value computed in Java), 2 left as residue")),
    assertion(sub_string(N1, _, _, _, "1 other approximation")).

%   A rule LPS2's reader does not translate is a residue block with its DRL
%   and the reason, and counted as residue.
test(file_open_untranslated_rules, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    fixture_drl('unsupported.drl', DRL),
    import_drl(DRL, D, imported(LE, [N1|_])),
    read_file_to_string(LE, S, []),
    assertion(sub_string(S, _, _, _, "% RESIDUE rule_an_eval BEGIN")),
    assertion(sub_string(S, _, _, _, "`eval` is not translated")),
    assertion(sub_string(S, _, _, _, "if there is an order with id an id and value a value")),
    assertion(sub_string(N1, _, _, _, "1 rule(s) encoded, 0 approximated (salience, a rule attribute, a value computed in Java), 3 left as residue")).

%   An accumulate is an aggregate sentence (`a total is the sum of each a
%   value such that …`), not a residue block; the program compiles to the
%   reading LPS2's reader makes (findall and sum_list, length) and, on the
%   facts the fixture was checked on, ends where Drools ends (Big(110),
%   Many(2)).
test(accumulate_is_an_aggregate, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    fixture_drl('accumulate.drl', DRL),
    import_drl(DRL, D, imported(LE, [N1|_])),
    read_file_to_string(LE, S, []),
    assertion(sub_string(S, _, _, _, "a total is the sum of each a value such that")),
    assertion(\+ sub_string(S, _, _, _, "RESIDUE")),
    assertion(sub_string(N1, _, _, _, "2 rule(s) encoded")),
    fixture_final_state(D, 'accumulate.drl', acc, [order(o1, 60), order(o2, 50)], Fs),
    assertion(memberchk(big(110), Fs)), assertion(memberchk(many(2), Fs)).

%   Rule attributes (tools/drools_fixtures/attributes.drl, checked against
%   Drools 10): no-loop is a condition, and the rule fires once, as in
%   Drools; enabled false leaves the rule out, with a comment; an attribute
%   not translated is named in the rule's comment and makes its ledger entry
%   approximated.
test(rule_attributes, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    fixture_drl('attributes.drl', DRL),
    import_drl(DRL, D, imported(LE, [N1|_])),
    read_file_to_string(LE, S, []),
    assertion(sub_string(S, _, _, _, "and the balance is different from 100")),
    assertion(sub_string(S, _, _, _, "Rule \"switched off\" has `enabled false` in the source")),
    assertion(sub_string(S, _, _, _, "agenda-group \"audit\", date-expires \"01-Jan-2020\", timer (int: 1s)")),
    assertion(sub_string(N1, _, _, _, "2 rule(s) encoded, 3 approximated")),
    atomic_list_concat([D, '/attributes.ledger.md'], LF), read_file_to_string(LF, L, []),
    assertion(sub_string(L, _, _, _, "enabled false -> left out")),
    fixture_final_state(D, 'attributes.drl', attrs,
                        [account(acc1, 150, false), account(acc2, -5, false), counter(k, 0)], Fs),
    %  as in Drools: capped once, flagged once
    assertion(memberchk(account(acc1, 100), Fs)),
    assertion(memberchk(account_flagged(acc2, -5), Fs)).

%   Values computed in Java (tools/drools_fixtures/values.drl, checked
%   against Drools 10): `$total.intValue()`, `$c.getCount() + 1` and
%   `$p.getName()` are computed, so the twin ends where Drools ends; the insert
%   whose value is `$p.getName().toUpperCase()` is a residue block, never a
%   constant.
test(java_values, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    fixture_drl('values.drl', DRL),
    import_drl(DRL, D, imported(LE, _)),
    read_file_to_string(LE, S, []),
    assertion(sub_string(S, _, _, _, "% RESIDUE rule_shout_an_adult_s_name BEGIN")),
    assertion(\+ sub_string(S, _, _, _, "ref(")),
    fixture_final_state(D, 'values.drl', vals,
                        [order(o1, 60), order(o2, 50), counter(k, 0), person(ann, 10), person(bob, 40)], Fs),
    assertion(memberchk(big(110), Fs)),
    assertion(memberchk(counter(3), Fs)),
    assertion(memberchk(label(ann, minor), Fs)).

%   The fixtures are those of LPS2's DRL front end (tools/drools_fixtures/
%   in the LPS2 repository).
fixture_drl(B, DRL) :-
    le2_paths:lps2_dir(L), atomic_list_concat([L, '/tools/drools_fixtures/', B], DRL).

%   The stateful twin of a fixture with a working memory, run by LPS2.
fixture_final_state(Dir, B, Id, Facts, Fluents) :-
    fixture_drl(B, DRL),
    atomic_list_concat([Dir, '/', Id], D), make_directory_path(D),
    once(drl_migration(case(Id, [drl_path(DRL), facts(Facts), title(Id)]), [], M)),
    once(le_migration:write_migration(M, D, Id, _)),
    format(atom(LE), '~w/~w.le', [D, Id]),
    once(twin_final_state(LE, Fluents)).

corpus_drl(B, DRL) :-
    module_property(drl_twin, file(F)), file_directory_name(F, M),
    atomic_list_concat([M, '/corpus/drl/', B], DRL).

tmp_dir(D) :- tmp_file(drl, D), make_directory(D).

:- end_tests(drools_twins).

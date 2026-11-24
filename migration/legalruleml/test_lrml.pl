/*  Tests of the LegalRuleML translator (Phase 2f).

    From the LE2 checkout (/work), after build.pl (and oracle/fetch_spindle.sh
    for the oracle's tests):

        ./myswipl.sh -q -g run_tests -t halt migration/legalruleml/test_lrml.pl
*/

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module(lrml_reader).
:- use_module(lrml_spindle).
:- use_module(lrml_twin).
:- use_module(lrml_export).
:- use_module(lrml_import).
:- use_module(roundtrip).
:- use_module(corpus).
:- use_module('../le2_paths', [twins_dir/2]).

%   A file of the LE2 this translator is part of.
le2_file(Rel, F) :- le2_paths:le2_dir(LE2), atomic_list_concat([LE2, '/', Rel], F).
:- use_module(le2(le_kbs)).

:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).
:- dynamic here/1.

examples_dir(E) :- twins_dir(legalruleml, E).

:- begin_tests(lrml_reader).

%   The two serialisations of each of the specification's fifteen examples
%   read to the same model.
test(compact_is_normalized) :-
    corpus_dir(D),
    forall(( directory_member(D, N, [extensions([lrml])]), sub_atom(N, B, _, 0, '-normal.lrml') ),
           ( sub_atom(N, 0, B, _, Stem), atom_concat(Stem, '-compact.lrml', C),
             read_lrml(N, M1), read_lrml(C, M2),
             assertion(M1 =@= M2) )).

test(section29) :-
    corpus_dir(D), atomic_list_concat([D, '/ex5-section29new-normal.lrml'], F),
    read_lrml(F, M), M = model(Is),
    assertion(memberchk(override(ps2, ps1), Is)),
    assertion(memberchk(reparation(_, pen1, ps1), Is)),
    memberchk(statement(ps1, prescriptive, _, rule(defeasible, _, suborder([deontic(prohibition, none, _)]), _)), Is).

:- end_tests(lrml_reader).

:- begin_tests(lrml_oracle, [condition(spindle_available)]).

test(section29_by_spindle) :-
    corpus_dir(D), atomic_list_concat([D, '/ex5-section29new-normal.lrml'], F),
    read_lrml(F, M),
    spindle_conclusions(M, scenario(t, [lit(person, [alice]), lit(engageCreditActivity, [alice]),
                                        lit(person, [bob]), lit(engageCreditActivity, [bob]), lit(hasLicence, [bob])], []), C),
    assertion(memberchk(deontic(prohibition, alice, lit(engageCreditActivity, [alice])), C)),
    assertion(memberchk(deontic(permission, bob, lit(engageCreditActivity, [bob])), C)),
    assertion(\+ memberchk(deontic(prohibition, bob, _), C)),
    assertion(memberchk(violated(prohibition, alice, _), C)).

:- end_tests(lrml_oracle).

:- begin_tests(lrml_twins).

%   Every built twin meets SPINdle's answers on its drafted scenarios.
test(twins_pass) :-
    examples_dir(E),
    forall(( directory_member(E, F, [extensions([le]), recursive(true)]),
             file_base_name(F, B), B \== 'deontic.le' ),
           ( runTestsFor(F, R), result_failures(R, NF),
             assertion(NF == 0) )).

result_failures(R, NF) :-
    with_output_to(string(S), print_test_result(R)),
    aggregate_all(count, sub_string(S, _, _, _, "FAIL"), NF).

:- end_tests(lrml_twins).

:- begin_tests(lrml_export).

%   LE -> LegalRuleML -> LE keeps the rules, facts and scenario facts.
test(round_trip) :-
    forall(member(R, ['examples/moreExamples/citizenship.le', 'examples/moreExamples/tea_party.le',
                      'examples/moreExamples/collections/kowalski-book/underground_emergency.le']),
           ( le2_file(R, F), roundtrip_file(F, O), assertion(O == same) )).

%   An LE for LPS program's reading as norms: an obligation for a reactive
%   rule, a prohibition for a constraint on an action.
test(lps_as_norms) :-
    T = "the target language is: lps.

the actions are:
    *a payer* pays *an amount* to *a payee*.
    *a payer* is reminded.

the fluents are:
    *a payer* owes *an amount*.

the knowledge base norms includes:

if a payer owes an amount at a time
    and the amount > 0
then the payer pays the amount to bank from the time to a second time.

when a payer pays an amount to a payee
then it is not the case that the payer owes the amount.

it must not be true that
    a payer pays an amount to a payee
    and the amount > 1000.

initially alice owes 10.
",
    le_kbs:load_text(T, KB),
    export_lrml(KB, [text(T)], exported(_, XML, Notes, _)),
    assertion(sub_string(XML, _, _, _, "lrml:Obligation")),
    assertion(sub_string(XML, _, _, _, "lrml:Prohibition")),
    assertion(( member(N, Notes), sub_string(N, _, _, _, "no time") )).

%   What LegalRuleML cannot state refuses the export, each with its line:
%   bank_transfer's constraints relate two actions.
test(lps_refused_with_lines) :-
    le2_paths:lps2_dir(LPS2),
    atomic_list_concat([LPS2, '/examples/le'], LeDir),
    atomic_list_concat([LeDir, '/bank_transfer.le'], BT),
    read_file_to_string(BT, T, []),
    le_kbs:load_text(T, LeDir, KB),
    export_lrml(KB, [text(T)], R),
    assertion(R = refused(_)),
    R = refused(Ps),
    assertion(( member(problem(line(L), M), Ps), integer(L), sub_string(M, _, _, _, "two actions") )).

%   A rule with an aggregate is not left out of the document: the export
%   refuses, at the rule.
test(aggregate_refused) :-
    T = "the target language is: prolog.\n\nthe templates are:\n    *a person* owes *an amount*.\n    *a person* has a debt of *an amount*.\n\nthe knowledge base t includes:\n\na person has a debt of a total if\n    the total is the sum of each amount such that\n        the person owes the amount.\n",
    le_kbs:load_text(T, KB),
    check_lrml(KB, [text(T)], Ps),
    assertion(( member(problem(at(_, _), M), Ps), sub_string(M, _, _, _, "sum") )).

%   An LE for LPS program's IR has templates only (its rules are its LPS
%   reading's terms): the exporter still applies, so both IDEs' export menus
%   (le_import:export_formats/2) offer it.
test(lps_program_offered) :-
    T = "the target language is: lps.\n\nthe actions are:\n    *a payer* pays *an amount* to *a payee*.\n\nthe fluents are:\n    *a payer* owes *an amount*.\n\nthe knowledge base norms includes:\n\nif a payer owes an amount at a time\n    and the amount > 0\nthen the payer pays the amount to bank from the time to a second time.\n\ninitially alice owes 10.\n",
    le_kbs:load_text(T, KB),
    assertion(applies_lrml(KB)),
    le_import:export_formats(KB, Fs),
    assertion(( member(F, Fs), get_dict(id, F, legalruleml) )).

%   `according to` inside `it is not the case that`: the problem names the
%   `according to`, at its own line (not not/1 at the rule's first
%   condition); the decision table's problem has the table's line.
test(refusal_names_construct_and_lines) :-
    le2_file('examples/regulatory/eu261_integration.le', F),
    read_file_to_string(F, T, []), file_directory_name(F, D),
    le_kbs:load_text(T, D, KB),
    le_import:export_kb(legalruleml, KB, [text(T), base(D)], R),
    get_dict(problems, R, Ps),
    split_string(T, "\n", "", Lines),
    once(( nth1(AL, Lines, L1), sub_string(L1, _, _, _, "according to the carrier") )),
    once(( nth1(TL, Lines, L2), sub_string(L2, 0, _, _, "the table article_7 is") )),
    assertion(\+ ( member(P, Ps), get_dict(message, P, M), sub_string(M, _, _, _, "not/1") )),
    assertion(( member(P1, Ps), get_dict(message, P1, M1), sub_string(M1, _, _, _, "according to"),
                get_dict(line, P1, AL) )),
    assertion(( member(P2, Ps), get_dict(message, P2, M2), sub_string(M2, _, _, _, "decision table"),
                get_dict(line, P2, TL) )).

%   Negation alone is written, as Naf.
test(negation_exports_as_naf) :-
    T = "the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is sad.\n\nthe knowledge base t includes:\n\na person is happy if\n    it is not the case that\n        the person is sad.\n",
    le_kbs:load_text(T, KB),
    export_lrml(KB, [text(T)], exported(_, XML, _, _)),
    assertion(sub_string(XML, _, _, _, "ruleml:Naf")).

%   An `otherwise` cascade is an Or whose later alternatives are guarded by
%   the Naf of the earlier ones. A guard's own variable (`a kind`, bound by
%   nothing before the guard) is scoped by an Exists inside the Naf: under
%   the rule's universal closure a bare Naf(p(X1, X2)) would read "for some
%   X2 not p", not LE's "for no X2". The reader takes the Exists back to the
%   same condition, and the round trip keeps the rule.
test(otherwise_guard_scoped) :-
    T = "the target language is: prolog.\n\nthe templates are:\n    *a customer* is a member.\n    *a customer* is a student.\n    *a customer* is a pensioner.\n    *a customer* gets a discount.\n    *a customer* holds a card of *a kind*.\n\nthe knowledge base discounts includes:\n\na customer gets a discount\n    if the customer is a member\n    otherwise the customer is a student\n        and the customer holds a card of a kind\n    otherwise the customer is a pensioner.\n",
    le_kbs:load_text(T, KB),
    export_lrml(KB, [text(T)], exported(_, XML, _, _)),
    assertion(sub_string(XML, _, _, _, "ruleml:Or")),
    once(sub_string(XML, B1, _, _, "<ruleml:Naf>")),
    sub_string(XML, B1, 200, _, First),
    assertion(\+ sub_string(First, _, _, _, "ruleml:Exists")),      % the member guard binds nothing of its own
    assertion(sub_string(XML, _, _, _, "<ruleml:Exists>")),
    tmp_file_stream(text, Tmp, Out), write(Out, XML), close(Out),
    read_lrml(Tmp, model(Items)), delete_file(Tmp),
    assertion(\+ ( sub_term(X, Items), X == true )),
    assertion(( sub_term(naf(and(Fs)), Items), length(Fs, 2) )),
    le_writer:kb_to_ir(KB, program(H, Is)),
    tmp_file(lrml, Dir), make_directory(Dir), atomic_list_concat([Dir, '/discounts.le'], F),
    le_writer:le_write(program(H, Is), Text, _),
    setup_call_cleanup(open(F, write, S), write(S, Text), close(S)),
    roundtrip_file(F, O), delete_directory_and_contents(Dir),
    assertion(O == same).

%   A negation with a variable of its own, outside any cascade, likewise.
test(negation_local_variable_scoped) :-
    T = "the target language is: prolog.\n\nthe templates are:\n    *a person* is lonely.\n    *a person* is a person.\n    *a person* has *a friend*.\n\nthe knowledge base t includes:\n\na person is lonely if\n    the person is a person\n    and it is not the case that\n        the person has a friend.\n",
    le_kbs:load_text(T, KB),
    export_lrml(KB, [text(T)], exported(_, XML, _, _)),
    split_string(XML, " \t\n", " \t\n", Ws0), exclude(==(""), Ws0, Ws), atomic_list_concat(Ws, Flat),
    assertion(sub_atom(Flat, _, _, _, '<ruleml:Naf><ruleml:Exists><ruleml:Var>X2</ruleml:Var><ruleml:Atom>')).

%   A template answered by a service has no rule or fact in the document:
%   the export refuses, at the template's line.
test(service_template_refused) :-
    le2_file('examples/regulatory/semantic_match.le', F),
    read_file_to_string(F, T, []), file_directory_name(F, D),
    le_kbs:load_text(T, D, KB),
    le_import:export_kb(legalruleml, KB, [text(T), base(D)], R),
    get_dict(problems, R, Ps),
    split_string(T, "\n", "", Lines),
    once(( nth1(TL, Lines, L1), sub_string(L1, _, _, _, "*a category*; via service matcher") )),
    assertion(( member(P, Ps), get_dict(message, P, M), sub_string(M, _, _, _, "service matcher"),
                get_dict(line, P, TL) )).

%   A rule whose body is a Prolog goal is refused naming the goal, not the
%   conjunction it sits in ("uses and/2").
test(prolog_goal_named) :-
    le2_file('examples/moreExamples/language/includes/prolog_resources/postcodes_layer.le', F),
    read_file_to_string(F, T, []), file_directory_name(F, D),
    le_kbs:load_text(T, D, KB),
    le_import:export_kb(legalruleml, KB, [text(T), base(D)], R),
    get_dict(problems, R, Ps),
    assertion(Ps \== []),
    forall(member(P, Ps), ( get_dict(message, P, M),
                            assertion(sub_string(M, _, _, _, "Prolog goal")),
                            assertion(\+ sub_string(M, _, _, _, "and/2")) )).

%   A judged template and the facts' provenance are exported with a note
%   (they are about answering and explaining a case, not about what the
%   rules conclude); a flip query is a query, noted too.
test(judged_and_flip_noted) :-
    forall(member(B-Word, ['judged_damage'-"judged", 'judged_damage'-"provenance", 'flip_housing'-"flip"]),
           ( le2_file('examples/regulatory/', Reg), atomic_list_concat([Reg, B, '.le'], F),
             read_file_to_string(F, T, []), file_directory_name(F, D),
             le_kbs:load_text(T, D, KB),
             export_lrml(KB, [text(T), base(D)], R),
             assertion(R = exported(_, _, _, _)),
             R = exported(_, _, Notes, _),
             assertion(( member(N, Notes), sub_string(N, _, _, _, Word) )) )).

%   An integrity constraint (LE for Prolog) and a fluent's default (LE for
%   LPS) have no LegalRuleML form: refused, each at its line.
test(constraint_and_default_refused) :-
    T1 = "the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is sad.\n\nthe knowledge base t includes:\n\nit must not be true that\n    a person is happy\n    and the person is sad.\n\na person is happy if\n    the person is a person.\n",
    le_kbs:load_text(T1, KB1),
    le_import:export_kb(legalruleml, KB1, [text(T1)], R1),
    get_dict(problems, R1, P1s),
    assertion(( member(P1, P1s), get_dict(line, P1, 9) )),
    T2 = "the target language is: lps.\n\nthe actions are:\n    *a payer* pays *an amount*.\n\nthe fluents are:\n    the balance of *an account* is *an amount*; 0 by default.\n\nthe knowledge base b includes:\n\nwhen a payer pays an amount\nthen the balance of the payer is the amount.\n",
    le_kbs:load_text(T2, KB2),
    le_import:export_kb(legalruleml, KB2, [text(T2)], R2),
    get_dict(problems, R2, P2s),
    assertion(( member(P2, P2s), get_dict(message, P2, M2), sub_string(M2, _, _, _, "default"), get_dict(line, P2, 7) )).

%   A document named with a date keeps the date as written in its
%   LegalSource key (2026-09-14, not 2026-9-14).
test(legal_source_key_keeps_date) :-
    T = "the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n\nthe knowledge base t includes:\n\nthe run of 2026-09-14 is published at \"https://example.org/run\".\n\na person is happy if\n    the person is a person.\n",
    le_kbs:load_text(T, KB),
    export_lrml(KB, [text(T)], exported(_, XML, _, _)),
    assertion(sub_string(XML, _, _, _, "key=\"the_run_of_2026-09-14\"")),
    assertion(\+ sub_string(XML, _, _, _, "2026-9-14")).

:- end_tests(lrml_export).

:- begin_tests(lrml_import).

test(file_open) :-
    corpus_dir(D), atomic_list_concat([D, '/ex5-section29new-normal.lrml'], F),
    assertion(detect_lrml(F)),
    tmp_file(lrml, Out), make_directory(Out),
    once(import_lrml(F, Out, imported(LE, _))),
    assertion(exists_file(LE)),
    atomic_list_concat([Out, '/deontic.le'], Lib), assertion(exists_file(Lib)),
    delete_directory_and_contents(Out).

%   A translated document says where its sources are (`the text of … is
%   at`, `… is published at`): the way back writes them as LegalSources, it
%   does not refuse them.
test(imported_document_exports_back) :-
    corpus_dir(D), atomic_list_concat([D, '/ex10-mix-compact.lrml'], F),
    tmp_file(lrml, Out), make_directory(Out),
    once(import_lrml(F, Out, imported(LE, _))),
    read_file_to_string(LE, Text, []),
    le_kbs:load_text(Text, Out, KB),
    le_import:export_kb(legalruleml, KB, [text(Text), base(Out)], R),
    delete_directory_and_contents(Out),
    assertion(\+ get_dict(error, R, _)),
    get_dict(document, R, Xml),
    assertion(sub_string(Xml, _, _, _, "lrml:LegalSource")).

test(prolog_is_not_lrml) :-
    le2_file('examples/moreExamples/citizenship.le', F),
    \+ detect_lrml(F).

:- end_tests(lrml_import).

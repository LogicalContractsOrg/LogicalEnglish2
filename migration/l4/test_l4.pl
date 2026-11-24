/** <module> Tests of the L4 reader (the design notes l4.md, steps 0 and 1)

    From the LE2 checkout (/work), after fetch_sources.sh:

        ./myswipl.sh -q -g run_tests -t halt migration/l4/test_l4.pl

    The evaluator's runs (runs/) and the gate's last results (runs/gate.txt)
    are read, not made: making them needs Node.js and the evaluator
    (fetch_oracle.sh, l4_oracle.mjs cache, gate.pl). The step 0 twins are run:
    the timeless one by LE2, the LPS one by LPS2 when /lps2 (or $LPS2_DIR)
    is there.
*/

:- module(test_l4, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(readutil)).
:- use_module(library(process)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(l4_lex).
:- use_module(l4_reader).
:- use_module(l4_print).
:- use_module(corpus).
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).

here(D) :- module_property(test_l4, file(F)), file_directory_name(F, D).

read_text(Lines, Items) :-
    atomic_list_concat(Lines, '\n', T),
    l4_read_text(T, l4_module(Items, Issues)),
    assertion(Issues == []).

:- begin_tests(l4_lexer).

test(ditto_copies_the_token_above) :-
    l4_tokens("  LIST Place OF \"Anguilla\"\n       ^     ^  \"Bermuda\"\n", Ts),
    findall(V, member(tok(_, V, 2, _, _, _), Ts), Line2),
    assertion(Line2 == ['Place', 'OF', "Bermuda"]).

test(names_numbers_genitive) :-
    l4_tokens("`the applicant`'s age >= 21 AND x IS -1.5 PLUS 15%", Ts),
    findall(K-V, member(tok(K, V, _, _, _, _), Ts), KVs),
    assertion(KVs == [q-'the applicant', gen-'\'s', id-age, op-'>=', num-21, kw('AND')-'AND',
                      id-x, kw('IS')-'IS', num-(-1.5), kw('PLUS')-'PLUS', num-15, sym-'%']).

test(comments_and_annotations) :-
    l4_tokens("{- a {- nested -} comment -}\n-- line\nGIVEN p IS A Person @desc who asks\n", Ts),
    assertion(memberchk(tok(ann(desc), "who asks", 3, _, _, _), Ts)),
    assertion(\+ memberchk(tok(_, comment, _, _, _, _), Ts)).

:- end_tests(l4_lexer).

:- begin_tests(l4_reader).

%   The operators of an expression over several lines group by column.
test(layout_groups_and_or) :-
    read_text(["DECIDE x IF",
               "      a",
               "  AND    b",
               "      OR c",
               "  AND d"], [decide(decide, _, _, E, _, _)]),
    assertion(E == and(app(a, []), and(or(app(b, []), app(c, [])), app(d, [])))).

test(one_line_follows_priorities) :-
    read_text(["x MEANS a OR b AND c"], [decide(means, _, _, E, _, _)]),
    assertion(E == or(app(a, []), and(app(b, []), app(c, [])))).

test(mixfix_definition_and_use) :-
    read_text(["GIVEN a IS A NUMBER, b IS A NUMBER",
               "GIVETH A NUMBER",
               "a `plus` b MEANS a + b",
               "#EVAL 1 `plus` 2"], [_, directive(eval(E), _, _)]),
    assertion(E == mixfix([arg(num(1)), kw(plus), arg(num(2))])).

%   An inner obligation's LEST is its own; the outer one's LEST is the
%   outer's (the sale of the design notes l4.md §2).
test(nested_obligations) :-
    here(H), atomic_list_concat([H, '/spike/sale.l4'], F),
    l4_read_file(F, l4_module(Items, [])),
    memberchk(decide(means, _, appform(sale, [], [], _), D, _, _), Items),
    assertion(D = deontic(app('Seller', []), must, papp(deliver, []), none, num(14),
                          deontic(app('Buyer', []), must, papp(pay, [plit(num(100))]), none, num(30),
                                  app('FULFILLED', []), breach(app('Buyer', []), str("failed to pay"))),
                          breach(app('Seller', []), str("failed to deliver")))),
    aggregate_all(count, member(directive(trace(_, _, _), _, _), Items), NT),
    assertion(NT == 8).

test(records_and_choices) :-
    read_text(["DECLARE Action IS ONE OF",
               "    deliver",
               "    pay HAS amount IS A NUMBER"], [declare(_, appform('Action', [], [], _), enum(Cs), _, _)]),
    assertion(Cs = [con(deliver, []), con(pay, [field(amount, tyapp('NUMBER', []), none, _)])]).

test(where_is_local) :-
    read_text(["GIVEN i IS A NUMBER",
               "tax MEANS",
               "    a * 0.1",
               "    WHERE",
               "        a MEANS i"], [decide(means, _, _, where(times(app(a, []), num(0.1)), [D]), _, _)]),
    assertion(D = decide(means, sig([], none), appform(a, [], [], _), app(i, []), [], _)).

test(annotation_attached) :-
    read_text(["@export default the tax",
               "GIVEN i IS A NUMBER @desc the income",
               "tax MEANS i"], [decide(means, _, _, _, Anns, _)]),
    assertion(Anns == [a(export, "default the tax", 1), a(desc, "the income", 2)]).

test(unreadable_is_kept) :-
    l4_read_text("x MEANS 1\n)) nonsense\ny MEANS 2\n", l4_module(Items, Issues)),
    assertion(Issues = [unparsed(_, parse, pos(2, 2))]),
    assertion(length(Items, 3)).

%   Every corpus file L4's evaluator accepts reads with nothing left over.
test(corpus_files_read_in_full) :-
    forall(( corpus_file(Id, _, _), accepted(Id) ),
           ( corpus_path(Id, P), l4_read_file(P, l4_module(_, Issues)),
             assertion(Issues-Id == []-Id) )).

%   Written back, a file reads again to the same model.
test(written_back_reads_the_same) :-
    forall(member(Id, [legal_promissory_note, legal_anti_social, foundation_module_4_examples,
                       advanced_module_a3_contracts_examples]),
           ( corpus_path(Id, P), l4_read_file(P, M1), l4_print_module(M1, T),
             l4_read_text(T, M2), strip(M1, S1), strip(M2, S2), assertion(S1-Id == S2-Id) )).

:- end_tests(l4_reader).

accepted(Id) :-
    here(H), atomic_list_concat([H, '/runs/', Id, '.json'], F),
    exists_file(F),
    setup_call_cleanup(open(F, read, S), json_read_dict(S, D), close(S)),
    D.success == true.

%   A model without positions and annotations, for comparing two readings.
strip(l4_module(Items, _), S) :- strip_(Items, S).
strip_(T, T) :- var(T), !.
strip_(pos(_, _), p) :- !.
strip_(appform(N, A, K, _), appform(N, A, K)) :- !.
strip_(param(N, T, _), param(N, T1)) :- !, strip_(T, T1).
strip_(field(N, T, C, _), field(N, T1, C1)) :- !, strip_(T, T1), strip_(C, C1).
strip_(decide(_, Sig, AF, E, _, _), decide(Sig1, AF1, E1)) :- !, strip_(Sig, Sig1), strip_(AF, AF1), strip_(E, E1).
strip_(T, T) :- atomic(T), !.
strip_(T, S) :- T =.. [F|As], maplist(strip_, As, Bs), S =.. [F|Bs].

:- begin_tests(l4_oracle).

test(every_corpus_file_has_a_run) :-
    forall(corpus_file(Id, _, _),
           ( here(H), atomic_list_concat([H, '/runs/', Id, '.json'], F), assertion(exists_file(F)) )).

test(gate_last_run) :-
    here(H), atomic_list_concat([H, '/runs/gate.txt'], F),
    read_file_to_string(F, S, []),
    assertion(sub_string(S, _, _, _, "total 82 of 82 files read in full")),
    assertion(sub_string(S, _, _, _, "hover 155 of 155")),
    assertion(sub_string(S, _, _, _, "round-trip 82 of 82")).

:- end_tests(l4_oracle).

:- begin_tests(l4_step0).

%   The promissory note, timeless: every answer is L4's.
test(timeless_twin, [timeout(300)]) :-
    here(H), atomic_list_concat([H, '/step0/promissory_note.le'], F),
    runTestsFor(F, R),
    R = test_file(_, Results),
    assertion(Results \== []),
    forall(member(X, Results), assertion(X = pass(_, _))).

%   The promissory note, LPS: every final state is L4's.
test(lps_twin, [condition(lps2_there(_)), timeout(600)]) :-
    lps2_there(L),
    here(H), atomic_list_concat([H, '/step0/check_lps.py'], Py),
    le2_paths:le2_dir(LE2),
    process_create(path(python3), [Py, L, LE2], [stdout(pipe(Out)), process(P)]),
    read_string(Out, _, S), close(Out), process_wait(P, Status),
    assertion(Status == exit(0)),
    assertion(sub_string(S, _, _, _, "20 passed, 0 failed")).

:- end_tests(l4_step0).

lps2_there(L) :- catch(le2_paths:lps2_dir(L), _, fail).

		 /*******************************
		 *   STEP 2: THE RULES HALF     *
		 *******************************/

:- use_module(l4_twin, [twin_migration/3, variant_jobs/3, variants_hash/2, l4_value_text/2,
                         l4_rules_file/1, l4_twin_dir_name/2]).

:- begin_tests(l4_rules).

%   The twin of a small program: records, a phrase name with its input in
%   place, and the evaluator's answers as expectations
test(eligibility_rule_twin) :-
    corpus_path(foundation_eligibility_rule, F),
    twin_migration(F, [id(foundation_eligibility_rule)], migration(_, program(_, Is), _, Tests)),
    assertion(memberchk(function(_, "the age of *an applicant* is *a number*"), Is)),
    assertion(memberchk(template(_, "*an applicant* is eligible", []), Is)),
    assertion(memberchk(fact(l4_field_applicant_the_applicants_age(alice_the_adult, 25), []), Is)),
    length(Tests, 3).

test(values_of_the_evaluator) :-
    assertion(l4_value_text("TRUE", true)),
    assertion(l4_value_text("assertion failed", false)),
    assertion(l4_value_text("LIST 1, 2, 3", [1, 2, 3])),
    assertion(l4_value_text("DATE OF 3, 9, 2025", date(2025, 9, 3))),
    assertion(l4_value_text("JUST OF 4", 4)),
    assertion(l4_value_text("\"minor\"", "minor")).

%   The variants of the alcohol act (its facts ASSUMEd): every combination
%   of the facts each decision rests on, and their cached results current
test(alcohol_act_variants) :-
    corpus_path(legal_imaginary_alcohol_act, F),
    l4_read_file(F, M), variant_jobs(F, M, Jobs),
    length(Jobs, 152),
    variants_hash(Jobs, H), atom_string(H, HS),
    here(D), atomic_list_concat([D, '/runs/variants/legal_imaginary_alcohol_act.json'], VF),
    setup_call_cleanup(open(VF, read, S), json_read_dict(S, Cache), close(S)),
    assertion(Cache.hash == HS).

%   Every rules twin in LE2 passes its expectations (the evaluator's answers)
test(every_rules_twin_passes, [timeout(1800)]) :-
    le2_paths:twins_dir(l4, Dir),
    findall(Id, l4_rules_file(Id), Ids),
    forall(member(Id, Ids),
           ( l4_twin_dir_name(Id, Name),
             atomic_list_concat([Dir, '/', Name, '/', Name, '.le'], LE),
             (   exists_file(LE)
             ->  le_kbs:runTestsFor(LE, test_file(_, Rs)),
                 findall(R, ( member(R, Rs), R \= pass(_, _) ), Bad),
                 assertion(Bad == [])
             ;   true
             ) )).

:- end_tests(l4_rules).

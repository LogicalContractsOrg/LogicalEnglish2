/*  Tests of the LOMO door (migration/lomo/README.md).

        ./myswipl.sh -q -g run_tests -t halt migration/lomo/test_lomo.pl

    The tests that need a judge (rdflib, pySHACL: oracle/setup.sh) are
    skipped without it.
*/

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).
:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(le2(le_kbs)).
:- use_module(lomo_words).
:- use_module(lomo_reader).
:- use_module(lomo_twin).
:- use_module(lomo_gate).
:- use_module(lomo_shacl).
:- use_module(corpus).

lib_text(T) :-
    le2_paths:le2_dir(D),
    findall(S, ( member(L, ['lomo.le', 'deontic.le', 'temporal.le']), atomic_list_concat([D, '/lib/', L], F),
                 read_file_to_string(F, S, []) ), Ss),
    atomic_list_concat(Ss, '\n', T).

:- begin_tests(lomo_words).

test(every_template_is_in_the_library) :-
    lib_text(Lib),
    forall(( ( class_word(_, _, T) ; property_word(_, _, T, _) ; generic_template(_, _, T) ; lomo_twin:derived(_, T) ) ),
           (   sub_string(Lib, _, _, _, T) -> true
           ;   format(user_error, "not in lib/lomo.le: ~s~n", [T]), fail
           )).

test(every_word_has_its_label_in_the_library) :-
    lib_text(Lib),
    forall(vocabulary_term(I, W),
           (   \+ sub_atom(I, _, _, _, '/role/')
           ->  format(string(S), "~w has the preferred label", [W]), sub_string(Lib, _, _, _, S)
           ;   true
           )).

:- end_tests(lomo_words).

:- begin_tests(lomo_reader).

test(names_are_unique_and_safe) :-
    forall(lomo_file(_, F),
           ( read_lomo(F, lomo(_, Nodes, _)),
             findall(N, member(node(_, N, _), Nodes), Ns),
             msort(Ns, S), length(S, L), sort(S, U), length(U, L),
             forall(member(N, Ns), ( atomic_list_concat([W|_], ' ', N), \+ lomo_reader:reserved_start(W) )) )).

test(words_of) :-
    words_of('Norm_PublicationObligation', [norm, publication, obligation]),
    words_of('REG20121219ART2PAR1_Action1', [reg, '20121219', art, '2', par, '1', action, '1']),
    words_of('addressee-european-commission', [addressee, european, commission]).

test(eli_names) :-
    lomo_file(other, F), sub_atom(F, _, _, _, 'dir_2013_34'),
    read_lomo(F, lomo(_, Nodes, _)),
    memberchk(node('http://data.europa.eu/eli/dir/2013/34/oj', 'eli dir 2013 34 oj', _), Nodes).

:- end_tests(lomo_reader).

:- begin_tests(lomo_registers).

register(LE) :-
    twins_dir(lomo, Root),
    member(Set, [examples, other, lfds, spec, cases]),
    atomic_list_concat([Root, '/', Set], Dir),
    directory_files(Dir, Fs), member(F, Fs), file_name_extension(_, le, F), F \== 'lomo.le',
    atomic_list_concat([Dir, '/', F], LE).

test(every_register_passes_its_scenario) :-
    findall(LE-R, ( register(LE), runTestsFor(LE, R) ), Rs),
    length(Rs, N), N >= 128,
    forall(member(LE-R, Rs),
           (   R = test_file(_, Ts), forall(member(T, Ts), T = pass(_, _)) -> true
           ;   format(user_error, "~w: ~q~n", [LE, R]), fail
           )).

:- end_tests(lomo_registers).

:- begin_tests(lomo_gates, [condition(judge_available)]).

%  Step 1: LOMO's seven search queries give the same rows on the RDF data
%  (rdflib) and on every register.
test(the_seven_tables_are_the_same, [timeout(1200)]) :-
    gate(Results),
    length(Results, NR), NR >= 128,
    forall(member(file(F, Qs), Results),
           forall(member(query(Q, _, _, M, E), Qs),
                  (   M == [], E == [] -> true
                  ;   format(user_error, "~w ~w: ~q ~q~n", [F, Q, M, E]), fail
                  ))).

%  Step 2: our validity check agrees with pySHACL on every file.
test(validity_agrees_with_pyshacl, [timeout(600)]) :-
    shacl_gate(Rs),
    length(Rs, N), N >= 131,
    forall(member(shacl(F, _, M, E), Rs),
           (   M == [], E == [] -> true
           ;   format(user_error, "~w: ~q ~q~n", [F, M, E]), fail
           )).

:- end_tests(lomo_gates).

:- begin_tests(lomo_validity).

test(messages_in_words) :-
    corpus_dir(_),
    lomo_gate:here(D), atomic_list_concat([D, '/corpus/broken/rules.ttl'], F),
    check_file(F, Rs),
    memberchk(result('http://example.org/broken#P1', _, 'InConstraintComponent', 'http://example.org/Duty', Msg), Rs),
    sub_string(Msg, _, _, _, "not one of the words LOMO allows").

test(no_unsupported_constraint) :-
    \+ unsupported(_, _).

:- end_tests(lomo_validity).

:- use_module(lomo_lps).

lps2_there :- catch(le2_paths:lps2_dir(_), _, fail).

:- begin_tests(lomo_lps, [condition(lps2_there)]).

%  Step 5: every case run by LPS2 ends with the duties that the timeless
%  reading gives for its last day.
test(lps_runs_end_as_the_timeless_reading_says, [timeout(900)]) :-
    lps_gate(Rs),
    length(Rs, N), N >= 3,
    forall(member(case(Name, E, F, _), Rs),
           (   E == F, E \== [] -> true
           ;   format(user_error, "~w: ~q ~q~n", [Name, E, F]), fail
           )).

:- end_tests(lomo_lps).

:- use_module(lomo_roundtrip, [roundtrip/1]).

:- begin_tests(lomo_way_back, [condition(judge_available)]).

%  Step 7: every register goes back to Turtle as the same graph (rdflib's
%  isomorphism, blank nodes included).
test(every_register_gives_its_description_again, [timeout(3000)]) :-
    roundtrip(Rs),
    length(Rs, N), N >= 128,
    forall(member(rt(F, V), Rs),
           (   V = same(_) -> true
           ;   format(user_error, "~w: ~q~n", [F, V]), fail
           )).

%  A program with no LOMO facts and no rule that cites a provision is
%  refused, with the reason.
test(refused_with_its_reason) :-
    le2_paths:le2_dir(D), atomic_list_concat([D, '/examples/moreExamples/citizenship.le'], F),
    load(F, KB),
    lomo_export:export_lomo(KB, [file(F)], R),
    R = refused([problem(_, M)|_]),
    sub_string(M, _, _, _, "nothing to describe").

:- end_tests(lomo_way_back).

/*  Tests of le_ontology.pl on a tiny WordNet (testing/fixtures/ontologies/
    wordnet_mini): the conversion of the WordNet database format, plurals,
    phrases read by their ending, distances, the first sense under a class.
    No download: the cache is a temporary folder.
*/
:- use_module('../le_ontology').

:- begin_tests(le_ontology).

mini_setup :-
    tmp_file(ontology, Dir), make_directory(Dir),
    ontology_use_cache(wordnet, Dir),
    module_property(le_ontology, file(F)), file_directory_name(F, Root),
    directory_file_path(Root, 'testing/fixtures/ontologies/wordnet_mini', Mini),
    directory_file_path(Dir, 'wordnet_2025.pl', Pl),
    ontology_convert(wordnet, Mini, Pl).

mini_cleanup :-
    ontology_use_cache(wordnet, default).

test(plural_and_distance, [setup(mini_setup), cleanup(mini_cleanup)]) :-
    once(wordnet_ancestor("Slippers", "footwear", D, S)),
    assertion(D == 1), assertion(S == 'oewn-00000005-n').

test(phrase_by_its_ending, [setup(mini_setup), cleanup(mini_cleanup)]) :-
    once(wordnet_ancestor("women's slippers", "footwear", D, _)),
    assertion(D == 2).

test(synonym_at_distance_zero, [setup(mini_setup), cleanup(mini_cleanup)]) :-
    once(wordnet_ancestor("slipper", "carpet slipper", D, _)),
    assertion(D == 0).

test(two_senses, [setup(mini_setup), cleanup(mini_cleanup)]) :-
    findall(S, wordnet_ancestor(loafers, entity, _, S), Ss0), sort(Ss0, Ss),
    assertion(Ss == ['oewn-00000006-n', 'oewn-00000008-n']).

test(first_sense_under_a_class, [setup(mini_setup), cleanup(mini_cleanup)]) :-
    wordnet_first_sense(loafers, person, S),
    assertion(S == 'oewn-00000008-n'),
    wordnet_first_sense(loafers, footwear, S2),
    assertion(S2 == 'oewn-00000006-n'),
    assertion(\+ wordnet_first_sense(bag, footwear, _)).

test(gloss_and_words, [setup(mini_setup), cleanup(mini_cleanup)]) :-
    wordnet_gloss("oewn-00000003-n", G),
    assertion(G == "covering for a person's feet"),
    wordnet_words('oewn-00000003-n', W),
    assertion(W == "footwear, footgear").

test(irregular_plural, [setup(mini_setup), cleanup(mini_cleanup)]) :-
    assertion(\+ wordnet_ancestor(feet, _, _, _)).

:- end_tests(le_ontology).

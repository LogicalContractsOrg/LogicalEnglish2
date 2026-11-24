/** <module> The RUML sources and where their twins live

    fetch_sources.sh clones each repository at the commit pinned here into
    .cache/<name> (gitignored). The format's own repository holds the
    specification (CC BY-SA 4.0), the schemas, the conformance tests and the
    examples (Apache-2.0, copyright Rulemapping Group GmbH). The examples of
    the specification and the fixtures of the tests are the only public
    rulemaps (the design notes ruml.md §1.5), so they are the collections.

    collection(Id, Dir, Pattern): the `.ruml` files of a collection under
    .cache/ruml. twin_place(Id, public | private): both are Apache-2.0 and
    published in LE2's examples/migration/ruml/<Id>/ with the notice
    (decision 9 of the plan).
*/

:- module(ruml_corpus, [source_commit/3, collection/3, twin_place/2, collection_title/2,
                        collection_licence/2, cache_dir/1, ruml_repo/1, second_opinion_repo/1]).

source_commit(ruml, 'https://github.com/Law-as-Code-Institute/ruml.git',
              'd2ac818f6ed87c2bcf5b69430adf2efa8ba3c6a4').          % 16 November 2026, release 1.0.0
source_commit('ruml-js', 'https://github.com/Law-as-Code-Institute/ruml-js.git',
              'cb7d754b42ff53940e154ae924b7f72f7fa8b218').
source_commit('ruml-python', 'https://github.com/Law-as-Code-Institute/ruml-python.git',
              '1a421333ba0a2b4d134054417dc418c1142916ec').
%   The unofficial tooling with an evaluator (MIT licence), the second
%   opinion of the oracle (plan §8): fetched by fetch_sources.sh.
source_commit('ruml-tooling', 'https://github.com/TechPrototyper/ruml-tooling.git',
              '6b061f5bd2d2f065f810d462dc84fa99397ac77f').

cache_dir(D) :- module_property(ruml_corpus, file(F)), file_directory_name(F, Dir),
                atomic_list_concat([Dir, '/.cache'], D).

ruml_repo(D) :- cache_dir(C), atomic_list_concat([C, '/ruml'], D).
second_opinion_repo(D) :- cache_dir(C), atomic_list_concat([C, '/ruml-tooling'], D).

%   The examples of the specification (English pages) and the fixtures of
%   the conformance tests.
collection(spec, 'spec/en', '.ruml').
collection(tests, tests, '.ruml').

twin_place(spec, public).
twin_place(tests, public).

collection_title(spec, "The examples of the RUML 1.0.0 specification").
collection_title(tests, "The fixtures of the RUML 1.0.0 conformance tests").

collection_licence(spec, "Apache-2.0, Copyright 2026 Rulemapping Group GmbH (the examples inside the specification)").
collection_licence(tests, "Apache-2.0, Copyright 2026 Rulemapping Group GmbH").

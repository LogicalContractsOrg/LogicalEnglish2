/** <module> The DMN collections and where their twins live

    fetch_sources.sh clones each collection at the commit pinned here into
    .cache/<dir> (gitignored) and unpacks the bruidsschat's STTR files of
    the final July 2023 release into .cache/sttr. Counts, licences and the
    reasons for each choice: the design notes landscape.md §2.3.

    collection(Id, Dir, Pattern): the files of a collection under .cache.
    twin_place(Id, public | private): the bruidsschat stays private until
    KOOP confirms its terms of reuse (Phase 4 decision 2); the TCK's level 3
    stays here too, as the measurement of the FEEL runtime it is (its
    failures are FEEL that LE has no type for, and would turn LE2's example
    suite red); the others are published in LE2's examples/migration/dmn/<Id>/.
*/

:- module(dmn_corpus, [collection/3, source_commit/3, twin_place/2, collection_title/2,
                       collection_licence/2, client_file/3]).

source_commit(tck, 'https://github.com/dmn-tck/tck.git',
              '1e349176e5ae689d924a2a2c7a8df25c220d8b07').          % 19 October 2026
source_commit(bruidsschat, 'https://gitlab.com/koop/PR04/bruidsschat-teruglevering.git',
              'af4cd7c55646fbf4e68a80f0fb991f60d4f90f25').          % 6 December 2024
source_commit(ronl, 'https://github.com/sgort/linked-data-explorer.git',
              'a87f64ba8764a99ddc5f81305a129840bab6e719').          % 10 October 2026
source_commit(bdt, 'https://github.com/CodeForPhilly/benefit-decision-toolkit.git',
              '6fcf6911369f9c99c5e8981cca6d964e72d33cf7').          % 22 October 2026
%   The models that the client examples of Kogito and Camunda call (the
%   adapter's demonstrations, dmn_adapter.pl): single files, fetched at
%   these commits by fetch_sources.sh.
source_commit(kogito_examples, 'https://github.com/apache/incubator-kie-kogito-examples.git',
              '740ddbe35d79f05a684abb10b58475f77e2d932c').          % 26 October 2026
source_commit(camunda_examples, 'https://github.com/camunda/camunda-bpm-examples.git',
              '6c7f4c4adb4beb9a2f5d4c5e49fc1ddfc6dab3fc').          % 26 October 2026

%   client_file(Repository, Path in it, File under .cache/clients)
client_file(kogito_examples, 'kogito-quarkus-examples/dmn-quarkus-example/src/main/resources/Traffic Violation.dmn',
            'kogito/Traffic Violation.dmn').
client_file(camunda_examples, 'dmn-engine/dmn-engine-drg/src/main/resources/org/camunda/bpm/example/drg/dinnerDecisions.dmn',
            'camunda/dinnerDecisions.dmn').

collection(tck, 'tck/TestCases/compliance-level-2', '*.dmn').
collection(tck3, 'tck/TestCases/compliance-level-3', '*.dmn').
collection(sttr, sttr, '*.xml').
collection(ronl, ronl, '*.dmn').
collection(bdt, bdt, '*.dmn').
collection(clients, clients, '*.dmn').

twin_place(tck, public).
twin_place(tck3, private).    % a measurement of lib/feel, not examples: it fails where LE has no type (times)
twin_place(ronl, public).
twin_place(bdt, public).
twin_place(clients, public).
twin_place(sttr, private).

collection_title(tck, "The DMN Technology Compatibility Kit, compliance level 2 (decision tables and simple expressions)").
collection_title(tck3, "The DMN Technology Compatibility Kit, compliance level 3 (FEEL)").
collection_title(sttr, "The applicable rules of the Dutch Environment and Planning Act (the Omgevingswet's bruidsschat), in STTR").
collection_title(ronl, "Rules for Government (RONL) examples of Dutch municipalities and agencies").
collection_title(bdt, "The Benefit Decision Toolkit of Code for Philly (Philadelphia tax relief)").
collection_title(clients, "The decision models of the client examples of Kogito (Traffic Violation) and Camunda (Dinner Decisions)").

collection_licence(tck, "Apache-2.0").
collection_licence(tck3, "Apache-2.0").
collection_licence(sttr, "none stated; Dutch official rules carry no copyright (Auteurswet art. 11), to be confirmed with KOOP").
collection_licence(ronl, "EUPL-1.2").
collection_licence(bdt, "MIT").
collection_licence(clients, "Apache-2.0").

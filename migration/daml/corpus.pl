/** <module> The Daml corpus: the SDK's own templates

    Each project: its sources (under .cache/<template>/, made by
    fetch_sources.sh with the SDK's `dpm new`; Apache-2.0, Digital Asset)
    and a title. The twin of a project is lps2/examples/migration/daml/<Id>/.
*/

:- module(daml_corpus, [project/4, cache_dir/1]).

:- prolog_load_context(directory, D), atomic_list_concat([D, '/.cache'], C),
   retractall(cache_dir_(_)), assertz(cache_dir_(C)).
:- dynamic cache_dir_/1.

cache_dir(D) :- cache_dir_(D).

%!  project(?Id, -Title, -Template, -Files) is nondet.
project(skeleton, "The SDK's skeleton: an asset its owner gives away", skeleton,
        ['main/daml/Main.daml', 'test/daml/Test.daml']).
project(token, "Daml intro, Daml Script: tokens a party may only issue to itself", 'daml-intro-daml-scripts',
        ['daml/Token_Test.daml']).
project(simple_iou, "Daml intro, choices: an IOU transferred along a chain of owners", 'daml-intro-choices',
        ['daml/SimpleIou.daml']).
project(contact, "Daml intro, choices: a contact whose owner and party update it", 'daml-intro-choices',
        ['daml/Contact.daml']).
project(restrictions, "Daml intro, constraints: an IOU with ensure and assertMsg", 'daml-intro-constraints',
        ['daml/Restrictions.daml']).
project(parties, "Daml intro, parties: proposals, authorization and delegation", 'daml-intro-parties',
        ['daml/Parties.daml']).
project(quickstart, "The quickstart IOU: issue, transfer, split, merge, and a delivery-versus-payment trade", 'quickstart-java',
        ['daml/Iou.daml', 'daml/IouTrade.daml', 'daml/Tests/Iou.daml', 'daml/Tests/Trade.daml']).
project(compose, "Daml intro, composing choices: assets, roles and an atomic trade", 'daml-intro-compose',
        ['daml/Intro/Asset.daml', 'daml/Intro/Asset/Role.daml', 'daml/Intro/Asset/Trade.daml',
         'daml/Test/Intro/Asset.daml', 'daml/Test/Intro/Asset/Role.daml', 'daml/Test/Intro/Asset/Trade.daml']).
project(coin_issuance, "Daml patterns: coin issuance by an issuer's invitation (propose and accept)", 'daml-patterns',
        ['daml/CoinIssuance.daml', 'daml/Utilities.daml']).
project(locking, "Daml patterns: locking a coin by changing its state", 'daml-patterns',
        ['daml/LockingByChangingState.daml', 'daml/Utilities.daml']).
project(multiparty, "Daml patterns: a multiple-party agreement signed one party at a time", 'daml-patterns',
        ['daml/MultiplePartyAgreement.daml', 'daml/Utilities.daml']).

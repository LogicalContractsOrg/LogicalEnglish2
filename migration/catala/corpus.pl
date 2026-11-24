/** <module> The Catala corpus and the programmes written as twins

    fetch_sources.sh clones catala-examples at the commit below into .cache/
    and unpacks the Catala toolchain beside it. The commit is the last whose
    project file the toolchain reads: the toolchain is the Catala team's own
    build of 22 August 2026 (1.2.0+git20260822r08832f46b, the newest built
    package; 1.3.0, of 1 October 2026, publishes no build). The examples are
    Apache-2.0: the twins are published in LE2, with attribution.

    programme(Name, Lang, Files, Roots, Includes): the twin of the scopes
    Roots, read from Files (paths relative to catala-examples/, the files of
    the module and of its tests), with the module folders the interpreter
    needs (Includes).
*/

:- module(catala_corpus, [repo_commit/3, catala_build/1, programme/5, generated/4]).

:- discontiguous programme/5.

repo_commit('catala-examples', 'https://github.com/CatalaLang/catala-examples.git',
            'e67e42414c8bcd2dca450a6a21c94db593fc909b').

catala_build('1.2.0+git20260822r08832f46b').

programme(section_132, en,
          ['us_tax_code/section_132.catala_en', 'us_tax_code/tests/test_section_132.catala_en'],
          ['QualifiedEmployeeDiscount'], [us_tax_code]).
programme(section_121, en,
          ['us_tax_code/section_121.catala_en', 'us_tax_code/tests/test_section_121.catala_en'],
          ['Section121SinglePerson', 'Section121TwoPersons'], [us_tax_code]).
programme(smic, fr,
          ['smic/Smic.catala_fr'],
          ['Smic'], [smic, prologue_france]).
programme(bmaf, fr,
          ['base_mensuelle_allocations_familiales/Bmaf.catala_fr'],
          ['BaseMensuelleAllocationsFamiliales'], [base_mensuelle_allocations_familiales]).
programme(prestations_familiales, fr,
          ['prestations_familiales/prologue.catala_fr', 'prestations_familiales/sécurité_sociale_L.catala_fr',
           'prestations_familiales/sécurité_sociale_R.catala_fr', 'smic/Smic.catala_fr',
           'prologue_france/France.catala_fr',
           'prestations_familiales/tests/tests_ouverture_droits.catala_fr'],
          ['ÉligibilitéPrestationsFamiliales'], [prestations_familiales, smic, prologue_france]).

%   The housing allowance (aides_logement, the CNAF's programme), scope by
%   scope: its law and the modules it uses, one twin per scope with the
%   test scopes that call it.
aides_logement_files(Test, Files) :-
    Files = ['aides_logement/prologue.catala_fr', 'aides_logement/code_construction_legislatif.catala_fr',
             'aides_logement/code_construction_reglementaire.catala_fr', 'aides_logement/code_sécurité_sociale.catala_fr',
             'aides_logement/arrete_2019-09-27.catala_fr', 'aides_logement/autres_sources.catala_fr',
             'aides_logement/archives.catala_fr', 'prologue_france/France.catala_fr',
             'base_mensuelle_allocations_familiales/Bmaf.catala_fr', 'prestations_familiales/prologue.catala_fr',
             'prestations_familiales/sécurité_sociale_L.catala_fr', 'prestations_familiales/sécurité_sociale_R.catala_fr',
             'smic/Smic.catala_fr', Test].
aides_logement_includes([aides_logement, prologue_france, base_mensuelle_allocations_familiales,
                         prestations_familiales, allocations_familiales, smic]).

programme(apl_locatif, fr, Files, ['CalculAidePersonnaliséeLogementLocatif'], Inc) :-
    aides_logement_includes(Inc),
    aides_logement_files('aides_logement/tests/tests_calcul_apl_locatif.catala_fr', Files).
%   The other scopes of the housing allowance (Phase 3c work left, 8 October):
%   the allowance for a residence (logement-foyer), for an owner buying a home
%   (accession à la propriété), the allocation logement in a rented home, the
%   eligibility scope, and the whole calculator the CNAF calls.
programme(apl_foyer, fr, Files, ['CalculAidePersonnaliséeLogementFoyer'], Inc) :-
    aides_logement_includes(Inc),
    aides_logement_files('aides_logement/tests/tests_calcul_apl_logement_foyer.catala_fr', Files).
programme(apl_accession, fr, Files, ['CalculAidePersonnaliséeLogementAccessionPropriété'], Inc) :-
    aides_logement_includes(Inc),
    aides_logement_files('aides_logement/tests/tests_calcul_apl_accession_propriete.catala_fr', Files).
programme(al_locatif, fr, Files, ['CalculAllocationLogementLocatif'], Inc) :-
    aides_logement_includes(Inc),
    aides_logement_files('aides_logement/tests/tests_calcul_al_locatif.catala_fr', Files).
programme(eligibilite_apl, fr, Files, ['ÉligibilitéAidePersonnaliséeLogement'], Inc) :-
    aides_logement_includes(Inc),
    aides_logement_files('aides_logement/tests/tests_eligibilite_apl.catala_fr', Files).
%   The same test file's other two scopes (Exemple2, Exemple3) are about the
%   allocation logement's eligibility, which answers with a kind of allowance
%   rather than a yes or no.
programme(eligibilite_al, fr, Files, ['ÉligibilitéAllocationLogement'], Inc) :-
    aides_logement_includes(Inc),
    aides_logement_files('aides_logement/tests/tests_eligibilite_apl.catala_fr', Files).
programme(calculette_globale, fr, Files, ['CalculetteAidesAuLogement'], Inc) :-
    aides_logement_includes(Inc),
    aides_logement_files('aides_logement/tests/tests_calculette_globale.catala_fr', Files).

%   generated(Name, SubScope, Usages, Grid): a programme without test scopes
%   of its own is checked on cases made from Grid (each input with the
%   values to try, every combination), the expected answers being Catala's
%   own, from its interpreter. The values are Catala text.
:- multifile generated/4.
generated(smic, 'Smic.Smic', ['Smic', 'France'],
          [ date_courante-['|2019-06-15|', '|2020-06-15|', '|2021-06-15|', '|2022-03-15|', '|2022-06-15|',
                           '|2022-10-15|', '|2023-03-15|', '|2023-08-15|', '|2024-06-15|', '|2024-12-15|'],
            'résidence'-['France.Collectivité.Métropole', 'France.Collectivité.Mayotte', 'France.Collectivité.Guyane'] ]).
generated(bmaf, 'Bmaf.BaseMensuelleAllocationsFamiliales', ['Bmaf'],
          [ date_courante-['|2019-06-15|', '|2020-06-15|', '|2021-06-15|', '|2022-06-15|', '|2023-06-15|',
                           '|2024-06-15|'] ]).

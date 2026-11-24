/** <module> The OpenFisca and PolicyEngine corpora and the programmes written as twins

    fetch_sources.sh clones each repository at the commit below into .cache/
    and installs it (with its engine, openfisca-core or policyengine-core,
    from pip) into .cache/venv, which both of_extract.py and of_oracle.py
    run in. All the packages are AGPL-3.0, and a twin is a translation of
    its package: the twins are never written into this repository, they go
    to the private place of ../le2_paths.pl (decision 2 of the October plan).

    programme(Name, Dialect, Group, Roots, Tests): the twin of the variables
    that Roots read, with the package's tests under Tests (paths relative to
    .cache/). programme_within(Name, Dirs): the folders of the package's
    variables the programme keeps; a variable elsewhere is a fact the case
    states, as the programme's own tests state it.
*/

:- module(openfisca_corpus, [repo_commit/3, programme/5, programme_within/2]).

%  Each programme is written with its folders beside it, so the two
%  predicates alternate down the file.
:- discontiguous programme/5.
:- discontiguous programme_within/2.

repo_commit('country-template', 'https://github.com/openfisca/country-template.git', '9877d0f514c13a616333bbbbd9e7e2886807e985').
repo_commit('policyengine-us', 'https://github.com/PolicyEngine/policyengine-us.git', 'b44d435ce4a3b06617380476709013aebc653421').
repo_commit('policyengine-uk', 'https://github.com/PolicyEngine/policyengine-uk.git', 'b5b092312df7aa56a4e89c4b9b7c133507dea114').
%  openfisca-france needs an openfisca-core below 45 (the country template
%  was installed with 45; the PolicyEngine packages run on policyengine-core),
%  so it is installed in an environment of its own (.cache/venv-fr; Phase 3b′).
repo_commit('openfisca-france', 'https://github.com/openfisca/openfisca-france.git', '16b2e69').


programme(country_template, template, openfisca,
          [disposable_income, housing_tax, total_taxes, total_benefits, income_tax, social_security_contribution,
           basic_income, housing_allowance, parenting_allowance, meal_price, age, household_income, pension],
          ['country-template/openfisca_country_template/tests']).

programme(snap, us, policyengine, [snap], ['policyengine-us/policyengine_us/tests/policy/baseline/gov/usda/snap']).
:- dynamic programme_within/2.
programme_within(snap, ['gov/usda/snap']).
programme(eitc, us, policyengine, [eitc], ['policyengine-us/policyengine_us/tests/policy/baseline/gov/irs/credits/earned_income']).
programme_within(eitc, ['gov/irs/credits/earned_income']).
programme(ctc, us, policyengine, [ctc], ['policyengine-us/policyengine_us/tests/policy/baseline/gov/irs/credits/ctc']).
programme_within(ctc, ['gov/irs/credits/ctc']).
programme(universal_credit, uk, policyengine, [universal_credit], ['policyengine-uk/policyengine_uk/tests/policy/baseline/finance/benefit/family/universal_credit']).
programme_within(universal_credit, ['gov/dwp/universal_credit']).
programme(child_benefit, uk, policyengine, [child_benefit], ['policyengine-uk/policyengine_uk/tests/policy/baseline/gov/hmrc/child_benefit']).
programme_within(child_benefit, ['gov/hmrc']).

%  openfisca-france (Phase 3b′ of the roadmap): the programmes in the order
%  the plan sets. The folders are those of the package's `model/` tree; a
%  variable elsewhere is a fact the case states (its value at each period the
%  calculation reads among them).
programme(impot_revenu, france, openfisca,
          [impot_revenu_restant_a_payer, irpp_economique, iai, rfr, rbg, rni, nbptr, ip_net],
          ['openfisca-france/tests/calculateur_impots/yaml',
           'openfisca-france/tests/impot_revenu']).
programme_within(impot_revenu, ['prelevements_obligatoires/impot_revenu']).

programme(aides_logement, france, openfisca,
          [aide_logement, aide_logement_montant, aide_logement_montant_brut],
          ['openfisca-france/tests/formulas/aides_logement.yaml',
           'openfisca-france/tests/formulas/aides_logement_2018.yaml',
           'openfisca-france/tests/formulas/aides_logement_etudiant.yaml',
           'openfisca-france/tests/formulas/aides_logement_reforme_janvier_2021.yaml']).
programme_within(aides_logement, ['prestations/aides_logement']).

%  The same variables, on the situations of the cross-check with the Catala
%  twin of Catala's example (of_crosscheck.py gen writes the tests; the
%  package's engine gives their expected values; roadmap Phase 3b′, step 5).
programme(aides_logement_croise, france, openfisca,
          [aide_logement_montant, aide_logement_loyer_plafond, aide_logement_charges,
           aide_logement_participation_minimale, aide_logement_taux_famille, aide_logement_participation_personnelle],
          ['../runs/croise/aides_logement_croise.yaml']).
programme_within(aides_logement_croise, ['prestations/aides_logement']).

programme(prestations_familiales, france, openfisca,
          [af, af_base, af_majoration, cf, paje_base, asf],
          ['openfisca-france/tests/formulas/af.yaml',
           'openfisca-france/tests/formulas/af_2018_01.yaml',
           'openfisca-france/tests/formulas/af_2018_04.yaml',
           'openfisca-france/tests/formulas/af_2020_04.yaml',
           'openfisca-france/tests/formulas/cf.yaml',
           'openfisca-france/tests/formulas/cf_2018.yaml',
           'openfisca-france/tests/formulas/cf_2018_04.yaml',
           'openfisca-france/tests/formulas/asf']).
programme_within(prestations_familiales, ['prestations/prestations_familiales']).

programme(rsa, france, openfisca,
          [rsa, rsa_socle, ppa],
          ['openfisca-france/tests/formulas/rsa.yaml',
           'openfisca-france/tests/formulas/rsa',
           'openfisca-france/tests/formulas/ppa']).
programme_within(rsa, ['prestations/minima_sociaux']).

programme(cotisations_sociales, france, openfisca,
          [cotisations_salariales, cotisations_employeur, salaire_net, salaire_super_brut],
          ['openfisca-france/tests/fiches_de_paie']).
programme_within(cotisations_sociales, ['prelevements_obligatoires/prelevements_sociaux']).

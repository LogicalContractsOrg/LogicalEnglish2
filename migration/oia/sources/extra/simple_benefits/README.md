# Simple Benefits — reconstructed from Oracle's documentation

Oracle shipped *SimpleBenefits* with the Oracle Policy Automation runtime
(`examples/rulebases/compiled/SimpleBenefits.zip`) and used it in every
Determinations Server tutorial. The project itself is not published; its
rules are, in Oracle's own words, across the documentation:

- *Test a rulebase using a web service* (Oracle Policy Automation 10.4,
  docs.oracle.com/html/E48376_01): the attributes and their public names
  (`eligible_teenage_allowance`, `eligible_low_income_allowance`,
  `claimant_income`, `claimant_public_housing_client`,
  `claimant_date_of_birth`, `child_age`), the containment relationship
  `claimantschildren`, an Assess request and its response;
- *Tutorial: Create and use a JAX-WS web service client* (12.2,
  docs.oracle.com/html/E79064_01) and the C# tutorial (E20344_01): the third
  goal, `low_income_allowance_payment`, a second request and its results.

The rule document here (`project/Rules/Simple Benefits Rules.ruletxt`, and
the `.docx` written from it by `../make_docx.py`) states those rules as
Policy Modeling would hold them:

- low income allowance: the claimant is a public housing client and earns
  less than 20,000 a year (the 10.4 page adds "the claimant's date of birth
  is known"; the 12.2 tutorial's request gives no date of birth and is
  answered *eligible*, so the later rule is the one kept);
- teenage child allowance: one of the claimant's children is 13 to 19;
- the low income allowance amount: **reconstructed** — Oracle publishes its
  value (70 for a claimant with two children) but not its rule; the rule
  here, 50 + 10 for each child, gives 70 for both published cases and is an
  assumption, marked as such in the rule document.

Oracle's two published Assess exchanges (request and response, SOAP) are
not copied into this repository: they are text of Oracle's documentation.
When they are in the private place (`oia_migrate:extra_path/2`, under
`assess/`), the translator replays them as test cases: the outcomes Oracle's
own engine returned. Without them, the project is translated with the five
cases of `tests.json`.

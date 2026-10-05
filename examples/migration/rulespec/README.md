# Axiom RuleSpec twins

United States benefit and tax rules that the Axiom Foundation publishes as
programs in its RuleSpec format (`rulespec-us`, commit `f468c8d` of 4
October 2026, CC-BY-4.0), each rewritten in Logical English by a
translator. Such a rewrite is a **twin**: each program holds one provision
and every provision it uses, each rule citing its provision, and the
provision's tests as scenarios. Axiom's own engine gives the same answers.

## Start here
- [7 U.S.C. 2017(a), the SNAP allotment](snap/us_statutes_7_2017_a.le?scenario=one_person_eligible_household_receives_thrifty_food_plan_less_thirty_percent_income&query=q_snap_regular_month_allotment) — the monthly food assistance of a household.
- [26 U.S.C. 32, the Earned Income Tax Credit](eitc/us_statutes_26_32.le?scenario=one_child_phase_in_and_allowed&query=q_eitc) — the credit of a family with one child.
- [42 U.S.C. 1382(e)(1), Supplemental Security Income in an institution](ssi/us_statutes_42_1382_e_1.le) — who may receive it while in a hospital or a public institution.

## Try this
1. Open [the SNAP allotment](snap/us_statutes_7_2017_a.le?scenario=one_person_eligible_household_receives_thrifty_food_plan_less_thirty_percent_income&query=q_snap_regular_month_allotment) and click **Query**: "the snap regular month allotment of household_1 is 182".
2. Click the answer: the explanation follows the household's income through sections 2014(e) and 2017(a).
3. Put the cursor on a rule and choose **File > View Original Text**: the RuleSpec file it comes from.
4. Choose **File > Export to Another System… > Axiom RuleSpec**: the program written back as RuleSpec, with its tests.

## More
- `snap/`: the Supplemental Nutrition Assistance Program (7 U.S.C. 2012-2017 and the USDA cost-of-living tables); `ctc/`: the Child Tax Credit (26 U.S.C. 24); `eitc/`: the Earned Income Tax Credit (26 U.S.C. 32); `ssi/`: Supplemental Security Income (42 U.S.C. 1382, 1382a, 1382b).
- Each twin's migration ledger (`<name>.ledger.md`) says what was translated from what; each folder's `sources/` holds the RuleSpec originals and their tests.
- [Axiom RuleSpec and Logical English](/docs/user/integrations/rulespec): how the translation works.
- Axiom Foundation: https://axiom.org and https://github.com/TheAxiomFoundation/rulespec-us
- Written by `lpsPlus/migration/rulespec/build.pl`; do not edit by hand.

## Disclaimer
A twin is written by a translator (a program that rewrites another
system's program in Logical English), and it is provided **"as is", without
warranty of any kind**, express or implied, including any warranty that it
is accurate, complete or fit for a particular purpose. A translation may be
wrong: check a twin against its source before relying on it. A twin is not
legal, tax, insurance, financial or other professional advice. Its authors
accept no liability for any loss or damage arising from its use. Every twin
repeats this notice in its opening comment.

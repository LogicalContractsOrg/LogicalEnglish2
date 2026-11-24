/** <module> The RuleSpec corpus and the engine the twins are checked against

    rulespec-us (Axiom Foundation, CC-BY-4.0) at corpus_commit/1, fetched by
    fetch_sources.sh into .cache/rulespec-us and normalised by prepare_root.py
    into .cache/root/rulespec-us; the engine axiom-rules-engine (MIT) at
    engine_commit/1, built from source by fetch_oracle.sh. The released
    binaries (v0.2.2, 20 August 2026) are older than the corpus: they refuse
    fields the corpus uses since September, so the oracle is the engine's
    `main` of the same day as the corpus commit.

    twin_module(Id, Group): the modules written as twins, in
    examples/migration/rulespec/<Group>/ of LE2. A twin holds its module and
    every module that one imports.
*/

:- module(rulespec_corpus, [corpus_commit/1, engine_commit/1, twin_module/2, group_title/2]).

corpus_commit('f468c8daeb3c0e7184b85be7fb97585475d74a1b').    % rulespec-us, 4 October 2026
engine_commit('e9757b47c9983ac3a0873827e064b790e03c29a4').    % axiom-rules-engine main, 5 October 2026

group_title(snap, "SNAP, the Supplemental Nutrition Assistance Program (7 U.S.C. 2011-2036, 7 CFR 273, the USDA FY 2026 cost-of-living adjustments)").
group_title(ctc, "The Child Tax Credit (26 U.S.C. 24)").
group_title(eitc, "The Earned Income Tax Credit (26 U.S.C. 32)").
group_title(ssi, "Supplemental Security Income (42 U.S.C. 1382, 1382a, 1382b)").

:- dynamic twin_module/2.

twin_module('us:policies/usda/snap/fy-2024-cola/deductions', snap).
twin_module('us:policies/usda/snap/fy-2024-cola/income-eligibility-standards', snap).
twin_module('us:policies/usda/snap/fy-2024-cola/maximum-allotments', snap).
twin_module('us:policies/usda/snap/fy-2026-cola/deductions', snap).
twin_module('us:policies/usda/snap/fy-2026-cola/income-eligibility-standards', snap).
twin_module('us:policies/usda/snap/fy-2026-cola/maximum-allotments', snap).
twin_module('us:statutes/26/24', ctc).
twin_module('us:statutes/26/24/d', ctc).
twin_module('us:statutes/26/24/h', ctc).
twin_module('us:statutes/26/32', eitc).
twin_module('us:statutes/26/32/c/2', eitc).
twin_module('us:statutes/42/1382/a/1', ssi).
twin_module('us:statutes/42/1382/a/2', ssi).
twin_module('us:statutes/42/1382/a/3', ssi).
twin_module('us:statutes/42/1382/b', ssi).
twin_module('us:statutes/42/1382/e/1', ssi).
twin_module('us:statutes/42/1382a/b/2', ssi).
twin_module('us:statutes/42/1382a/b/4', ssi).
twin_module('us:statutes/42/1382b/a', ssi).
twin_module('us:statutes/7/2012/j', snap).
twin_module('us:statutes/7/2012/m/4', snap).
twin_module('us:statutes/7/2014/a', snap).
twin_module('us:statutes/7/2014/c', snap).
twin_module('us:statutes/7/2014/d', snap).
twin_module('us:statutes/7/2014/e/2', snap).
twin_module('us:statutes/7/2014/e/2/B', snap).
twin_module('us:statutes/7/2014/e/6/A', snap).
twin_module('us:statutes/7/2014/g', snap).
twin_module('us:statutes/7/2015/b/1', snap).
twin_module('us:statutes/7/2015/d/2', snap).
twin_module('us:statutes/7/2015/d/2/A', snap).
twin_module('us:statutes/7/2015/d/2/B', snap).
twin_module('us:statutes/7/2015/d/2/C', snap).
twin_module('us:statutes/7/2015/d/2/D', snap).
twin_module('us:statutes/7/2015/d/2/E', snap).
twin_module('us:statutes/7/2015/d/2/F', snap).
twin_module('us:statutes/7/2015/e', snap).
twin_module('us:statutes/7/2015/f', snap).
twin_module('us:statutes/7/2017/a', snap).

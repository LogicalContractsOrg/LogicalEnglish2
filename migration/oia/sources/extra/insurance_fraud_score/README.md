# Insurance Fraud Score — reconstructed from Oracle's description

Oracle Policy Modeling installed an example project *Insurance Fraud Score*:
"Calculates the fraud score for an insurance claim based on current claim
and previous claims average. Demonstrates Excel rule tables with merged
cells, 'Apply Sheet' for time-varying attributes, entity-level functions and
calculations, rule visualizations and test scripts" (Oracle Policy Modeling
User's Guide, *Example rulebases*). The project is not published.

This is a reconstruction in its spirit, written for this repository: a claim
scored on its amount against the average of the claimant's previous claims
(entity functions InstanceCount, InstanceSum, InstanceCountIf, Exists), the
age of the policy (DayDifference) and claims in the last twelve months
(AddMonths), the claim type (rule tables), and a referral threshold. Every
rule is ours; none is Oracle's text. The expected values of `tests.json` are
computed by `make_tests.py`, a Python model of these rules, independently
of the twin. "Apply Sheet" and time-varying attributes are not reconstructed
(the translator reads OIA's temporal functions of the current date, not
change points: README of the translator, *Gaps*).

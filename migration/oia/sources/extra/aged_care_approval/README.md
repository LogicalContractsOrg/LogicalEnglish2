# Aged Care Approval — reconstructed from Oracle's description

Oracle Policy Modeling installed an example project *Aged Care Approval*:
"A rulebase that investigates the validity of an Aged Care Approval with one
Word rule document and one imported test case. Rules demonstrate temporal
functions operating together" (Oracle Policy Modeling User's Guide,
*Example rulebases*). The project is not published.

This reconstruction is ours, in that spirit, loosely after Australia's aged
care approvals (an assessment, an approval made within 30 days of it, a
time-limited approval for respite and restorative care that lapses twelve
months after it is made unless the person entered care, 63 days of
residential respite a year). It is not a statement of Australian law. It
uses the date functions together: YearDifference (age at assessment),
DayDifference (approval made in time; days left; length of each respite
stay), AddMonths (the end of a time-limited approval), the current date, and
an entity (the person's respite stays) summed with InstanceSum. Expected
values: `make_tests.py`, a Python model of the rules, independent of the
twin. The current date is case data (the translator's documented
approximation of OIA's CurrentDate()).

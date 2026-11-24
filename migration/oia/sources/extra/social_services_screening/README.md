# Social Services Screening — reconstructed from Oracle's description

Oracle Policy Modeling installed an example project *Social Services
Screening*: "A comprehensive rulebase that investigates the household
member's eligibility for a range of social services. It contains rules
written in Word and Excel, system rules (interpretative, procedural,
validation and visibility), rule visualizations and test scripts" (Oracle
Policy Modeling User's Guide, *Example rulebases*). The project is not
published.

This reconstruction is ours, in that spirit: a household and its members (an
entity), screened for food assistance (household income against a limit by
household size, a rule table with a formula row; countable assets), child
care assistance (a child in the household, Exists, and every member
available for child care, ForAll) and energy assistance (members aged 60 or
over or with a disability, InstanceCountIf; a credit by a rule table). The
figures are illustrative, not any agency's. Expected values: `make_tests.py`,
a Python model of the rules, independent of the twin.

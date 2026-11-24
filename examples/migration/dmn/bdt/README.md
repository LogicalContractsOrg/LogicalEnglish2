# The Benefit Decision Toolkit (Code for Philly)

The decision models of the Benefit Decision Toolkit of Code for Philly
(`CodeForPhilly/benefit-decision-toolkit`, commit `6fcf691` of 22 October
2026, MIT): the checks (age, income, residence, enrolment) and the
Philadelphia benefits built from them (the homestead exemption, the senior
citizen and low-income tax freezes, LOOP, RETIP, the owner-occupied payment
agreement). A benefit invokes the decision services of the checks it needs,
in other models. A service that a benefit invokes on its own inputs is a
function of the twin (`the owner occupant service result is *a truth
value*`), written once; another service has its logic written where it is
used. The toolkit's own Bruno requests (the test requests in its folder
`library-api/test/`) are the scenarios.

## Start here
- [The homestead exemption](homestead_exemption/homestead_exemption.le?scenario=Eligible&query=q_d_is_eligible).
- [Person minimum age](person_min_age/person_min_age.le): a person found in a list by id, and an age from two dates.

## Licence

The models (`sources/*.dmn`) are copied unchanged from the repository named
above. They are © Code for Philly, under the MIT Licence. The file
[BDT_LICENSE](BDT_LICENSE) in this folder is the copyright notice and the
text of that licence, copied from that repository. Each twin is a changed
form of its model: the DMN translator of Logical English wrote the twins
from the models in October 2026.

Code for Philly, a group of volunteers, makes the toolkit. A model, and its
twin, is not the official text of a rule of the City of Philadelphia.

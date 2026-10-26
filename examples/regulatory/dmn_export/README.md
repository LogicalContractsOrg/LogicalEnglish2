# Programs written in Logical English, exported to DMN

A program of this folder is written in Logical English, and **File ▸ Export
to Another System… ▸ DMN** writes it as a DMN 1.6 decision model, with its
scenarios as test cases of the DMN Technology Compatibility Kit (TCK).

## Start here
- [Childcare support](childcare_support.le?scenario=two_families&query=support) — values of one applicant, a decision table with first match, arithmetic, a list and its count. Each applicant of a scenario becomes a test case of the DMN model; on Drools, the three test cases pass.

## Try this
1. Open [childcare support](childcare_support.le?scenario=two_families&query=support) and click **Query**: the monthly support of ana is 600.
2. Select **File ▸ Export to Another System…**, then **DMN**.
3. Read the model: the table `income_bands` is a DMN decision table with the hit policy FIRST, and each rule is a FEEL expression.

## More
- What becomes what, and what the export refuses: [the DMN guide](/docs/user/integrations/dmn#the-way-back-from-logical-english-to-dmn).

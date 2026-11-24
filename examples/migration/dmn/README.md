# DMN twins

DMN (Decision Model and Notation) is a standard for decision models: inputs,
decisions, decision tables and expressions in FEEL, the expression language
of DMN. A translator rewrote the DMN models below in Logical English. Such a
rewrite is a **twin**. Each twin keeps its model in `sources/`, a **ledger**
that tells what each decision became, and scenarios with the answers that
the model's own tests give. Where a model has no tests, a DMN engine (Apache
KIE Drools, or the DMN engine of Camunda 7) gives the answers.

## Start here
- [The TCK's loan approval table](tck/0004_simpletable_u/0004_simpletable_u.le?scenario=t001&query=q_d_approval_status) — a decision table with the hit policy UNIQUE, as an LE decision table.
- [Philadelphia's homestead exemption](bdt/homestead_exemption/homestead_exemption.le?scenario=Eligible&query=q_d_is_eligible) — four checks from four other models, and FEEL's three values: true, false, or no answer.
- [A Dutch home-battery subsidy](ronl/rechtenhoogtesubsidiethuisbatterij/rechtenhoogtesubsidiethuisbatterij.le) — dates and amounts of a province's subsidy.

## The folders
- [tck/](tck/README.md) — the 28 models of compliance level 2 of the DMN Technology Compatibility Kit (Apache License 2.0).
- [ronl/](ronl/README.md) — example models about Dutch municipalities and agencies (RONL). These models and their twins are under the EUPL-1.2, not under the Apache License of this repository.
- [bdt/](bdt/README.md) — the Benefit Decision Toolkit of Code for Philly: Philadelphia tax relief (MIT Licence).
- [clients/](clients/README.md) — the models that the client examples of Kogito and Camunda call (Traffic Violation, Dinner Decisions), each with the mapping file of the DMN adapter (Apache License 2.0).

## Try this
1. Open [the homestead exemption](bdt/homestead_exemption/homestead_exemption.le?scenario=Eligible&query=q_d_is_eligible) and click **Query**: the answer is "the is_eligible is true".
2. Select the scenario `Ineligible` and click **Query** again.
3. Click the answer: each step names the decision of the model that it comes from.
4. Choose **File > Show the Original…**: the DMN model.

## More
- How DMN maps to Logical English, the way back to DMN, and the DMN adapter: [the DMN guide](/docs/user/integrations/dmn).
- The DMN translator writes the twins. The translator is open source, in the folder `migration/dmn/` of Logical English 2. Do not edit the twins by hand.
- Each model keeps the copyright and the licence of its authors. The README of each folder gives them. DMN is a trademark of the Object Management Group. The other names belong to their owners. No project named here took part in this work.

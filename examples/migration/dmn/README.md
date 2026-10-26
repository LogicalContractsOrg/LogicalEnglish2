# DMN twins

DMN (Decision Model and Notation) is a standard for decision models: inputs,
decisions, decision tables and expressions in FEEL, the expression language
of DMN. A translator rewrote the DMN models below in Logical English. Such a
rewrite is a **twin**. Each twin keeps its model in `sources/`, a **ledger**
that tells what each decision became, and scenarios with the answers that
the model's own tests (or the Drools engine) give.

## Start here
- [The TCK's loan approval table](tck/0004_simpletable_u/0004_simpletable_u.le?scenario=t001&query=q_d_approval_status) — a decision table with the hit policy UNIQUE, as an LE decision table.
- [Philadelphia's homestead exemption](bdt/homestead_exemption/homestead_exemption.le?scenario=Eligible&query=q_d_is_eligible) — four checks from four other models, and FEEL's three values: true, false, or no answer.
- [A Dutch home-battery subsidy](ronl/rechtenhoogtesubsidiethuisbatterij/rechtenhoogtesubsidiethuisbatterij.le) — dates and amounts of a province's subsidy.

## The folders
- [tck/](tck/README.md) — the 28 models of compliance level 2 of the DMN Technology Compatibility Kit.
- [ronl/](ronl/README.md) — rules of Dutch municipalities and agencies (RONL examples).
- [bdt/](bdt/README.md) — the Benefit Decision Toolkit of Code for Philly: Philadelphia tax relief.
- [clients/](clients/README.md) — the models that the client examples of Kogito and Camunda call (Traffic Violation, Dinner Decisions), each with the mapping file of the DMN adapter.

## Try this
1. Open [the homestead exemption](bdt/homestead_exemption/homestead_exemption.le?scenario=Eligible&query=q_d_is_eligible) and click **Query**: the answer is "the is_eligible is true".
2. Select the scenario `Ineligible` and click **Query** again.
3. Click the answer: each step names the decision of the model that it comes from.
4. Choose **File > Show the Original…**: the DMN model.

## More
- How DMN maps to Logical English, the way back to DMN, and the DMN adapter: [the DMN guide](/docs/user/integrations/dmn).
- The twins are written by the DMN translator of `lpsPlus/migration/dmn` (not public); do not edit them by hand.

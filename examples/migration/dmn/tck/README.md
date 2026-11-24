# The DMN TCK, compliance level 2

The 28 models of compliance level 2 of the DMN Technology Compatibility Kit
(`dmn-tck/tck`, commit `1e34917` of 19 October 2026, Apache-2.0), each
rewritten in Logical English by a translator: input data, decision tables
with each hit policy, simple FEEL arithmetic and logic, a business
knowledge model. The kit's own test cases are the scenarios.

## Start here
- [0004, a decision table with the hit policy UNIQUE](0004_simpletable_u/0004_simpletable_u.le?scenario=t001&query=q_d_approval_status).
- [0106, FEEL's three values](0106_feel_ternary_logic/0106_feel_ternary_logic.le): `and`, `or` and `not` over true, false and null.
- [0119, COLLECT with several outputs](0119_multi_collect_hitpolicy/0119_multi_collect_hitpolicy.le).

The 28 models have 116 test cases. A test case can expect more than one
value, and the twins hold 138 expected answers in all. The other part of the
kit, compliance level 3 (FEEL), is not here: the translator gives 1,745 of
its 3,559 expected answers (refer to [the DMN guide](/docs/user/integrations/dmn#what-is-not-supported-yet)).
The twins are examples of a translation. They are not a claim of conformance
to DMN.

## Licence

The models (`sources/*.dmn`) are copied unchanged from the repository named
above. They are © the DMN TCK contributors, under the Apache License 2.0,
whose text is the file `LICENSE` at the root of this repository. Each twin is
a changed form of its model: the DMN translator of Logical English wrote the
twins from the models in October 2026.

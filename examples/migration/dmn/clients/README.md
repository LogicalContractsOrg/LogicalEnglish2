# The models of the DMN client examples (Kogito, Camunda)

The decision models that two well-known client examples call, rewritten in
Logical English by the DMN translator:

- **Traffic Violation**, the model of Kogito's example `dmn-quarkus-example`
  (`apache/incubator-kie-kogito-examples`, commit `740ddbe` of 26 October
  2026, Apache-2.0): a fine and penalty points for a violation, and whether
  the driver is suspended. Its scenarios include the request of the
  example's own README.
- **Dinner Decisions**, the model of Camunda's example `dmn-engine-drg`
  (`camunda/camunda-bpm-examples`, commit `6c7f4c4`, Apache-2.0): the dish
  for the season and the number of guests, and the beverages (a COLLECT
  table).

The scenarios hold the answers of the original engines on the same cases:
Apache KIE Drools 10.2 for Traffic Violation, and Camunda 7.23's own DMN
engine for Dinner Decisions (its dialect of DMN 1.1 runs on Camunda only).
Next to each twin, a **mapping file** (`.adapter_map.json`) tells the DMN
adapter which sentence of the twin each name of the model is. With it, the
clients of Kogito, KIE Server and Camunda call these twins without a change
to their code: refer to [the DMN guide](/docs/user/integrations/dmn).

## Start here
- [Traffic Violation](traffic_violation/traffic_violation.le?scenario=readme&query=q_d_should_the_driver_be_suspended) — the case of Kogito's README: a fine of 500, 3 points, no suspension.
- [Dinner Decisions](dinnerdecisions/dinnerdecisions.le?scenario=spring_6&query=q_d_rel_beverages) — spring, six guests with children: steak, and three drinks.

The models are © the Apache KIE (Kogito) and Camunda contributors, under the
Apache License 2.0.

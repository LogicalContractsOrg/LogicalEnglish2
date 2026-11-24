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
engine for Dinner Decisions (the model is in the DMN 1.1 dialect of Camunda
Modeler, which Drools does not run unchanged).
Next to each twin, a **mapping file** (`.adapter_map.json`) tells the DMN
adapter which sentence of the twin each name of the model is. With it, the
clients of Kogito, KIE Server and Camunda call these twins without a change
to their code: refer to [the DMN guide](/docs/user/integrations/dmn).

## Start here
- [Traffic Violation](traffic_violation/traffic_violation.le?scenario=readme&query=q_d_should_the_driver_be_suspended) — the case of Kogito's README: a fine of 500, 3 points, no suspension.
- [Dinner Decisions](dinnerdecisions/dinnerdecisions.le?scenario=spring_6&query=q_d_rel_beverages) — spring, six guests with children: steak, and three drinks.

## Licence

The two models (`sources/*.dmn`) are copied unchanged from the repositories
named above. Both are under the Apache License 2.0, whose text is the file
`LICENSE` at the root of this repository:

- Traffic Violation is from the examples of Apache KIE, a project in the
  Incubator of the Apache Software Foundation. Its contributors license the
  model to the Apache Software Foundation, which licenses it to the public.
- Dinner Decisions is from the examples of Camunda. The `NOTICE` file of
  that repository says: "Camunda. Copyright 2013-2025 Camunda Services GmbH".

Each twin is a changed form of its model: the DMN translator of Logical
English wrote the twins from the models in October 2026. Neither Apache KIE
nor Camunda took part in this work.

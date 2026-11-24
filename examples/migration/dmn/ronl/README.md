# Dutch government rules (RONL examples)

Example models about Dutch municipalities and agencies, from the Linked Data
Explorer of the *Regels Overheid Nederland* (RONL) initiative
(`sgort/linked-data-explorer`, commit `a87f64b` of 10 October 2026,
EUPL-1.2): the social assistance and city pass of Heusden, the age
rules of the Social Insurance Bank (SVB), the home-battery subsidy of
Flevoland, a roof-insulation calculation, tree-felling permits, and the
checks of an application under the General Administrative Law Act. The
models are the examples and the test files of that repository (its folders
`examples/`, `e2e-fixtures/` and `packages/frontend/public/examples/`). A
model, and its twin, is not the official text of a rule of the body that it
names. The repository keeps most models in two or three copies; each is
translated once. The models have no tests of their own: the scenarios are
generated from the rows of their tables, and a DMN engine gives the expected
answers. For the 13 models made with Camunda Modeler, that engine is the DMN
engine of Camunda 7.23 (the Linked Data Explorer itself runs them on
Operaton, the open-source fork of Camunda 7). For the 3 other models, that
engine is Apache KIE Drools 10.2.0.

## Start here
- [The home-battery subsidy of Flevoland](rechtenhoogtesubsidiethuisbatterij/rechtenhoogtesubsidiethuisbatterij.le).
- [The roof-insulation calculation](dakisolatie_berekening_final/dakisolatie_berekening_final.le?scenario=g003&query=q_d_rel_bereken_isolatie_opties): FEEL formulas, written as formulas, with rounding half to even.
- [The age rules of the SVB](ronl_svb_leeftijden/ronl_svb_leeftijden.le): dates, ages and the state pension age.

## Licence

The models (`sources/*.dmn`) are copied unchanged from the repository named
above. That repository names RONL (Regels Overheid Nederland) as its author,
and licenses its content under the European Union Public Licence, version
1.2 (EUPL-1.2). The file [LICENSE](LICENSE) in this folder is the
text of that licence, copied from that repository.

Each twin (the `.le` file named after its folder, its ledger and its mapping
file) is a changed form of its model: the DMN translator of Logical English
wrote the twins from the models on 26 and 27 October 2026. The twins are
under the EUPL-1.2 too, not under the Apache License of the rest of this
repository. They come with no warranty, as the licence says.

The library files beside some twins (`feel`, `temporal`, `rounding`, `text`)
are copies of the libraries of Logical English. They are not made from the
models, and they keep the Apache License 2.0.

# Dutch government rules (RONL examples)

Models of Dutch municipalities and agencies, from the Rules for Government
examples (`sgort/linked-data-explorer`, commit `a87f64b` of 10 October
2026, EUPL-1.2): the social assistance and city pass of Heusden, the age
rules of the Social Insurance Bank (SVB), the home-battery subsidy of
Flevoland, a roof-insulation calculation, tree-felling permits, and the
checks of an application under the General Administrative Law Act. The
repository keeps most models in two or three copies; each is translated
once. The models have no tests of their own: the scenarios are generated
from the rows of their tables, and Apache KIE Drools 10.2.0 gives the
expected answers. One model has no scenarios: the age rules of the SVB,
whose inputs are dates without a declared type, so no values can be
generated for them.

## Start here
- [The home-battery subsidy of Flevoland](rechtenhoogtesubsidiethuisbatterij/rechtenhoogtesubsidiethuisbatterij.le).
- [The roof-insulation calculation](dakisolatie_berekening_final/dakisolatie_berekening_final.le?scenario=g003&query=q_d_rel_bereken_isolatie_opties): FEEL formulas, written as formulas, with rounding half to even.
- [The age rules of the SVB](ronl_svb_leeftijden/ronl_svb_leeftijden.le): dates, ages and the state pension age.

The models are licensed under the European Union Public Licence, version
1.2 (EUPL-1.2), by their authors; the twins, derived from them, are under
the same licence.

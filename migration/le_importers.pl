/** <module> The translators File ▸ Open and File ▸ Export offer (the registry of le_import.pl)

    One row per source system: what the editor calls it, the file
    extensions it reads (or the one it writes), the adapter file and its two
    predicates (see ../le_import.pl for the contract). le_kbs.pl loads this
    file; an adapter is loaded only when a file of its kind is opened, or a
    program is exported.

    Copyright Miguel Calejo; Apache License 2.0, as the rest of this
    repository (../NOTICE). The translators are published "as is".
*/

:- module(le_importers, []).

:- use_module(le2(le_import)).

:- multifile le_import:importer/6.
:- multifile le_import:exporter/6.
:- multifile le_import:export_check/2.

:- dynamic importers_dir/1.

%  Where the adapters are: this file's own directory.
:- (   prolog_load_context(directory, D),
       retractall(importers_dir(_)),
       assertz(importers_dir(D))
   ).

%  Every row below reaches its translator through adapter/2, so this is the
%  one place that asks whether the request being served may use them (the
%  capability `converters` of ../le_entitlements.pl). The translators are
%  free: on the command line, in the test suites and on a server without a
%  sign-in, every request may use them. A server that has a sign-in (the
%  hosted one) offers them to every signed-in visitor, so that the limits
%  on use (../le_throttle.pl) have somebody to count against.
adapter(Rel, File) :-
    allowed,
    importers_dir(D),
    atomic_list_concat([D, '/', Rel], File).

allowed :-
    catch(le_entitlements:entitled(converters),
          error(existence_error(_, _), _), true).

le_import:importer(miniscript, "Bitcoin Miniscript policy or descriptor",
                   [miniscript, ms, policy, desc, txt], File,
                   ms_import:import_miniscript, ms_import:detect_miniscript) :-
    adapter('miniscript/ms_import.pl', File).
%  OIA: every file kind oia_import:detect_oia/1 recognises — Word rule
%  documents, .ruletxt, a Hub project's JSON, compiled .xgen, .xprj, .stxt, a
%  rulebase.xml, a project folder zipped.
le_import:importer(oia, "Oracle Intelligent Advisor project or rulebase",
                   [docx, json, ruletxt, xgen, xprj, xml, stxt, zip], File,
                   oia_import:import_oia, oia_import:detect_oia) :-
    adapter('oia/oia_import.pl', File).
le_import:importer(socotra, "Socotra product configuration",
                   [zip, json], File,
                   socotra_import:import_socotra, socotra_import:detect_socotra) :-
    adapter('socotra/socotra_import.pl', File).
le_import:importer(solidity, "Solidity contract (LE for LPS)",
                   [sol, zip], File,
                   sol_import:import_solidity, sol_import:detect_solidity) :-
    adapter('solidity/sol_import.pl', File).

le_import:importer(scasp, "s(CASP) or Prolog program (LE1's s(CASP) translations too)",
                   [pl, scasp, lp], File,
                   scasp_import:import_scasp, scasp_import:detect_scasp) :-
    adapter('scasp/scasp_import.pl', File).

le_import:importer(blawx, "Blawx version 1 project (.blawx export or example YAML)",
                   [blawx, yaml, yml, zip], File,
                   blawx_import:import_blawx, blawx_import:detect_blawx) :-
    adapter('blawx/blawx_import.pl', File).

le_import:importer(drools, "Drools rule base (DRL): LE for LPS, and a decision service when it only inserts",
                   [drl], File,
                   drl_import:import_drl, drl_import:detect_drl) :-
    adapter('drools/drl_import.pl', File).

le_import:importer(epilog, "Epilog program (Stanford): a ruleset, or a game in LE for LPS",
                   [epilog, epi, hrf, txt], File,
                   epilog_import:import_epilog, epilog_import:detect_epilog) :-
    adapter('epilog/epilog_import.pl', File).

le_import:importer(legalruleml, "LegalRuleML document (OASIS): obligations, permissions and prohibitions as LE",
                   [lrml, xml], File,
                   lrml_import:import_lrml, lrml_import:detect_lrml) :-
    adapter('legalruleml/lrml_import.pl', File).

le_import:importer(oipa, "Oracle Insurance Policy Administration transaction (Rules Palette XML)",
                   [xml, zip], File,
                   oipa_import:import_oipa, oipa_import:detect_oipa) :-
    adapter('oipa/oipa_import.pl', File).

le_import:importer(daml, "Daml source (Daml 3, Canton): templates, choices and scripts as LE for LPS",
                   [daml, zip], File,
                   daml_import:import_daml, daml_import:detect_daml) :-
    adapter('daml/daml_import.pl', File).

le_import:importer(ponens, "Ponens policies: each policy a law of LE for LPS, a trace its scenario",
                   [json], File,
                   ponens_import:import_ponens, ponens_import:detect_ponens) :-
    adapter('ponens/ponens_import.pl', File).
le_import:importer(l4, "L4 file (Legalese, SMU): its rules as LE, its contracts as LE for LPS",
                   [l4], File,
                   l4_import:import_l4, l4_import:detect_l4) :-
    adapter('l4/l4_import.pl', File).

le_import:importer(rulespec, "Axiom RuleSpec module (YAML, rulespec/v1), alone or zipped with its imports",
                   [yaml, yml, zip], File,
                   rulespec_import:import_rulespec, rulespec_import:detect_rulespec) :-
    adapter('rulespec/rulespec_import.pl', File).

le_import:importer(openfisca, "OpenFisca or PolicyEngine code (Python variables, YAML parameters and tests), read without running it",
                   [py, zip], File,
                   of_import:import_openfisca, of_import:detect_openfisca) :-
    adapter('openfisca/of_import.pl', File).

le_import:importer(catala, "Catala (.catala_en, .catala_fr): scopes, their exceptions and their test scopes, read without running Catala",
                   [catala_en, catala_fr, zip], File,
                   catala_import:import_catala, catala_import:detect_catala) :-
    adapter('catala/catala_import.pl', File).
le_import:importer(rune, "Rune (.rosetta: ISDA's Digital Regulatory Reporting, the CDM, or a model of one's own): its reports and rules as LE, over DRR 7.14.0 and the CDM 6.29",
                   [rosetta, zip], File,
                   rune_import:import_rune, rune_import:detect_rune) :-
    adapter('rune/rune_import.pl', File).
%  RUML (the Rulemapping Logic Format, Law as Code Institut): a rulemap, its
%  sidecars and containers; ruml/README.md.
le_import:importer(ruml, "RUML rulemap (Rulemapping Logic Format 1.0, Law as Code Institut): its tree, data points and JSONata as LE",
                   [ruml, rumlc, 'ruml-ext', json, zip], File,
                   ruml_import:import_ruml, ruml_import:detect_ruml) :-
    adapter('ruml/ruml_import.pl', File).
%  ... and answers a case of a rulemap in RUML's own result format
%  (`.ruml-result`): Logical English as a RUML evaluator (LE2's operation
%  evaluateForeign).
le_import:evaluator(ruml, "RUML result (.ruml-result) of a case, decided by the rulemap's Logical English twin",
                    [ruml, rumlc, json, zip], File, ruml_import:evaluate_ruml) :-
    adapter('ruml/ruml_import.pl', File).
:- multifile le_import:evaluator/5.

le_import:importer(dmn, "DMN decision model (OMG DMN 1.1 to 1.6, FEEL; the Dutch STTR files too): decisions, tables and their tests as LE",
                   [dmn, xml, zip], File,
                   dmn_import:import_dmn, dmn_import:detect_dmn) :-
    adapter('dmn/dmn_import.pl', File).
le_import:importer(spreadsheet, "Spreadsheet (Excel .xlsx, .xlsm): formulas as rules, lookup ranges as decision tables, the sheet's own values as tests",
                   [xlsx, xlsm, xls, ods], File,
                   xlsx_import:import_spreadsheet, xlsx_import:detect_spreadsheet) :-
    adapter('spreadsheet/xlsx_import.pl', File).

%  LOMO (the Legal Obligation Metadata Ontology of the European
%  institutions): a description in Turtle becomes its register; lomo/README.md.
le_import:importer(lomo, "LOMO description (Turtle, Legal Obligation Metadata Ontology 1.1.0): one fact for each statement, with LOMO's questions as queries",
                   [ttl, turtle], File,
                   lomo_import:import_lomo, lomo_import:detect_lomo) :-
    adapter('lomo/lomo_import.pl', File).

%   The other way: a program written in another system's format.
le_import:exporter(miniscript, "Bitcoin Miniscript policy (with its Miniscript and a Minsc link)",
                   policy, File,
                   ms_export:export_miniscript, ms_export:applies_miniscript) :-
    adapter('miniscript/ms_export.pl', File).

le_import:exporter(legalruleml, "LegalRuleML (OASIS): rules, obligations and their sources",
                   lrml, File,
                   lrml_export:export_lrml, lrml_export:applies_lrml) :-
    adapter('legalruleml/lrml_export.pl', File).

le_import:exporter(daml, "Daml (Canton): the program as one State contract, each action a choice, with its scenario as a Daml Script",
                   daml, File,
                   daml_export:export_daml, daml_export:applies_daml) :-
    adapter('daml/daml_export.pl', File).

le_import:exporter(ponens, "Ponens policies: each law that records a breach as a policy, for ponens trace check",
                   json, File,
                   ponens_import:export_ponens, ponens_import:applies_ponens) :-
    adapter('ponens/ponens_import.pl', File).

le_import:exporter(rulespec, "Axiom RuleSpec module (YAML), with the scenarios as its test cases",
                   yaml, File,
                   rulespec_export:export_rulespec, rulespec_export:applies_rulespec) :-
    adapter('rulespec/rulespec_export.pl', File).

le_import:exporter(openfisca, "OpenFisca (Python, openfisca-core): a tax and benefit system with the scenarios as its tests",
                   py, File,
                   of_export:export_openfisca, of_export:applies_openfisca) :-
    adapter('openfisca/of_export.pl', File).

le_import:exporter(catala, "Catala (English dialect): one scope with the program's values and conditions, the scenarios as test scopes",
                   catala_en, File,
                   catala_export:export_catala, catala_export:applies_catala) :-
    adapter('catala/catala_export.pl', File).
le_import:exporter(ruml, "RUML rulemap (Rulemapping Logic Format 1.0): the program's first query as a tree, its conditions as JSONata, its text in the comments",
                   ruml, File,
                   ruml_export:export_ruml, ruml_export:applies_ruml) :-
    adapter('ruml/ruml_export.pl', File).
le_import:exporter(dmn, "DMN 1.6 decision model (OMG), FEEL expressions and decision tables, with the scenarios as DMN TCK test cases",
                   dmn, File,
                   dmn_export:export_dmn, dmn_export:applies_dmn) :-
    adapter('dmn/dmn_export.pl', File).
le_import:exporter(rune, "Rune (a twin of a DRR report): the rules changed in Logical English, run on DRR's own engine",
                   rosetta, File,
                   rune_le_export:export_rune, rune_le_export:applies_rune) :-
    adapter('rune/rune_le_export.pl', File).

le_import:exporter(lomo, "LOMO description (Turtle): a register written back, or the rules that cite their provisions described in LOMO's words",
                   ttl, File,
                   lomo_export:export_lomo, lomo_export:applies_lomo) :-
    adapter('lomo/lomo_export.pl', File).

%   The check each exporter runs before it writes (le_import.pl): a program
%   that uses something the target cannot say is refused, with the list.
le_import:export_check(miniscript, ms_export:check_miniscript).
le_import:export_check(legalruleml, lrml_export:check_lrml).
le_import:export_check(daml, daml_export:check_daml).
le_import:export_check(rulespec, rulespec_export:check_rulespec).
le_import:export_check(openfisca, of_export:check_openfisca).
le_import:export_check(catala, catala_export:check_catala).
le_import:export_check(rune, rune_le_export:check_rune).
le_import:export_check(dmn, dmn_export:check_dmn).
le_import:export_check(ruml, ruml_export:check_ruml).
le_import:export_check(lomo, lomo_export:check_lomo).

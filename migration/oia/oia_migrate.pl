/** <module> Migrate the public Oracle Intelligent Advisor projects to LE twins

    ./myswipl.sh -q -g "consult('migration/oia/oia_migrate.pl')" \
        -g "oia_migrate:main" -t halt          (run from /work)

    Reads the projects fetched by sources/fetch.sh (sources/.cache/) and
    writes one directory per project under examples/migration/oia/ of the
    private place (le2_paths:private_root/1; these twins are not published):
    <name>.le (the twin, its source tests as scenarios, a View), the ledger
    (<name>.ledger.md / .json), sources/<document>.txt (the Word rule
    documents' paragraphs, which the rules quote) and, when the rules use
    it, lib/temporal (copied).
*/

:- module(oia_migrate, [main/0, migrate/1, migrate/3, project/5, read_model/4]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(json)).
:- use_module('../le2_paths').
:- use_module(le2(le_kbs)).
:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).
:- use_module(oia_reader).
:- use_module(oia_text).
:- use_module(oia_ir).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(D)), assertz(here(D)).

%!  project(?Name, ?Dir, ?Kind, ?TestFiles, ?Options) is nondet.
%
%   Dir and TestFiles relative to sources/.cache.
project(warranty_claims, 'nixon/Warranty Claims (Intro)', xgen, [],
        [title("Warranty Claims (Intro)"),
         artifacts(['github.com/NixonS24/Oracle-Policy-Modeling: Warranty Claims (Intro)'])]).
project(mom_paternity_leave, 'opa_demo/MOM_Paternity_Leave', xgen, [],
        [title("MOM Paternity Leave"),
         artifacts(['github.com/yihsiang/opa_demo: MOM_Paternity_Leave'])]).
project(gst_at_settlement, 'nixon/IT_Law_Assignment_Final_Submission/GST_AT_SETTLEMENT', xgen,
        ['nixon/IT_Law_Assignment_Final_Submission/GST_AT_SETTLEMENT/Tests/Witholding_Amount.xlsx',
         'nixon/IT_Law_Assignment_Final_Submission/GST_AT_SETTLEMENT/Tests/Purchaser.xlsx',
         'nixon/IT_Law_Assignment_Final_Submission/GST_AT_SETTLEMENT/Tests/User_Flow_Logic.xlsx',
         'nixon/IT_Law_Assignment_Final_Submission/GST_AT_SETTLEMENT/Tests/Form_One.xlsx',
         'nixon/IT_Law_Assignment_Final_Submission/GST_AT_SETTLEMENT/Tests/Form_Two.xlsx'],
        [title("GST at Settlement"),
         artifacts(['github.com/NixonS24/Oracle-Policy-Modeling: IT_Law_Assignment_Final_Submission/GST_AT_SETTLEMENT'])]).
project(vibect, 'oia-dmn-tree/example/VIBECT', rulebase,
        ['oia-dmn-tree/example/TC_VAT.xlsx', 'oia-dmn-tree/example/TC_Direct Debit.xlsx',
         'oia-dmn-tree/example/TC_Delivery Method.xlsx', 'oia-dmn-tree/example/New Excel Testing Document.xlsx'],
        [title("Validate Invoice Business Event Content Type"),
         artifacts(['github.com/Intelligent-Advisor/oia-dmn-tree: example/VIBECT (rulebase.xml, rulebase.stxt, projectDataModel.xml) and example/TC_*.xlsx'])]).
project(dctad, 'oia-dmn-tree/example/DCTAD', rulebase, [],
        [title("Determine Cash Transaction Aggregation Decision"),
         artifacts(['github.com/Intelligent-Advisor/oia-dmn-tree: example/DCTAD'])]).

project(loan_advisor, 'loan_advisor', rulebase, ['extra/loan_advisor/tests.json'],
        [title("Loan Advisor"),
         artifacts(['Oracle Policy Automation demonstration rulebase "Loan Advisor" (rulebase.xml, rulebase.stxt), as deployed in github.com/NealOKelly/govuk-opa-maf-template: .adf/META-INF/Loan Advisor.zip'])]).
project(do_i_need_to_file, 'oracle_ds', hub('doINeedToFile.json'), ['extra/do_i_need_to_file/tests.json'],
        [title("Do I Need to File"), deployments([doINeedToFile]),
         artifacts(['github.com/oracle-samples/ia-tools-samples: llm/llm_ds_chat/decision-services/doINeedToFile.json (an Intelligent Advisor decision service; UPL licence)'])]).
project(taxpayer_information, 'oracle_ds', hub('taxpayerInformation.json'), ['extra/taxpayer_information/tests.json'],
        [title("Taxpayer Information"), deployments([taxpayerInformation]),
         artifacts(['github.com/oracle-samples/ia-tools-samples: llm/llm_ds_chat/decision-services/taxpayerInformation.json (an Intelligent Advisor decision service; UPL licence)'])]).
project(student_benefits, 'oracle_ds', hub('student_benefits.json'), ['extra/student_benefits/tests.json'],
        [title("Student Benefits"),
         artifacts(['github.com/oracle-samples/ia-tools-samples: samples/flows/student-benefits/Student Benefits.json (an Intelligent Advisor flow project; UPL licence)'])]).
project(laa_feedback_form, 'ministryofjustice_laa-ccms-opa-feedback-form-v23-ruletxt', ruletxt, ['extra/laa_feedback_form/tests.json'],
        [title("LAA CCMS Feedback Form"),
         artifacts(['github.com/ministryofjustice/laa-ccms-opa-feedback-form-v23-ruletxt: the .ruletxt form of the Legal Aid Agency\'s OPA Feedback Form rulebase'])]).
project(check_answers, 'moj_check_answers/CheckAnswers', docx, ['extra/check_answers/tests.json'],
        [title("Check Answers"),
         artifacts(['github.com/ministryofjustice/govuk-elements-for-oracle-policy-automation: CheckAnswers.zip (a Policy Modeling project: Rules/CheckAnswers Rules.docx, projectDataModel.xml)'])]).

project(simple_benefits, 'extra:simple_benefits/project', docx,
        ['extra/simple_benefits/assess/oracle_10_4_request.xml',
         'extra/simple_benefits/assess/oracle_12_2_tutorial_request.xml',
         'extra/simple_benefits/tests.json'],
        [title("Simple Benefits"),
         licence('reconstructed in this repository from Oracle\'s public documentation of the SimpleBenefits example rulebase (sources/extra/simple_benefits/README.md)'),
         artifacts(['Oracle Policy Automation documentation: "Test a rulebase using a web service" (10.4, E48376_01), the JAX-WS and C# Determinations Server tutorials (E79064_01, E20344_01); rules reconstructed in sources/extra/simple_benefits'])]).

project(insurance_fraud_score, 'extra:insurance_fraud_score/project', docx, ['extra/insurance_fraud_score/tests.json'],
        [title("Insurance Fraud Score"),
         licence('reconstructed in this repository after Oracle\'s description of its Insurance Fraud Score example project; the rules are this repository\'s (sources/extra/insurance_fraud_score/README.md)'),
         artifacts(['Oracle Policy Modeling User\'s Guide, "Example rulebases": Insurance Fraud Score (description only); rules reconstructed in sources/extra/insurance_fraud_score'])]).

project(aged_care_approval, 'extra:aged_care_approval/project', docx, ['extra/aged_care_approval/tests.json'],
        [title("Aged Care Approval"),
         licence('reconstructed in this repository after Oracle\'s description of its Aged Care Approval example project; the rules are this repository\'s (sources/extra/aged_care_approval/README.md)'),
         artifacts(['Oracle Policy Modeling User\'s Guide, "Example rulebases": Aged Care Approval (description only); rules reconstructed in sources/extra/aged_care_approval'])]).
project(social_services_screening, 'extra:social_services_screening/project', docx, ['extra/social_services_screening/tests.json'],
        [title("Social Services Screening"),
         licence('reconstructed in this repository after Oracle\'s description of its Social Services Screening example project; the rules are this repository\'s (sources/extra/social_services_screening/README.md)'),
         artifacts(['Oracle Policy Modeling User\'s Guide, "Example rulebases": Social Services Screening (description only); rules reconstructed in sources/extra/social_services_screening'])]).

cache_dir(D) :- here(H), atomic_list_concat([H, '/sources/.cache'], D).
extra_dir(D) :- here(H), atomic_list_concat([H, '/sources/extra'], D).

%!  extra_path(+Rel, -Path) is det.
%
%   A file or folder of sources/extra/. The cases of projects whose text
%   may not be published (Oracle's documentation, repositories with no
%   licence) are not in this repository: they are looked for in the private
%   place too (le2_paths:private_root/1, under migration/oia/sources/extra/),
%   and a project whose cases are in neither is migrated without them.
extra_path(Rel, Path) :-
    (   extra_dir(X)
    ;   private_root(R), atomic_list_concat([R, '/migration/oia/sources/extra'], X)
    ),
    atomic_list_concat([X, '/', Rel], Path),
    ( exists_file(Path) ; exists_directory(Path) ), !.
extra_path(Rel, Path) :-
    extra_dir(X), atomic_list_concat([X, '/', Rel], Path).
out_root(D) :- private_root(R), atomic_list_concat([R, '/examples/migration/oia'], D).

main :-
    forall(project(Name, _, _, _, _),
           (   catch(migrate(Name), E, ( print_message(error, E), fail ))
           ->  true
           ;   format("~w: FAILED~n", [Name])
           )).

%!  migrate(+Name) is det.
migrate(Name) :-
    out_root(Root),
    migrate(Name, Root, report(File, Issues, Counts, Fidelity)),
    format("~w: ~w~n  writer issues: ~w~n  ledger ~w~n", [Name, File, Issues, Counts]),
    (   Fidelity = fidelity(P, F, U, Rows)
    ->  format("  fidelity: ~w pass, ~w fail, ~w error~n", [P, F, U]),
        forall(( member(Row, Rows), Row = row(_, _, St, _), St \== pass ), format("    ~q~n", [Row]))
    ;   format("  fidelity: ~w~n", [Fidelity])
    ).

%!  migrate(+Name, +OutRoot, -Report) is det.
%
%   The twin written to OutRoot/Name/; Report is write_migration/4's.
migrate(Name, Root, Report) :-
    project(Name, Rel, Kind, TestRels, Opts),
    cache_dir(C),
    project_dir(C, Rel, Dir),
    maplist(cache_file(C), TestRels, TestFiles0),
    %  a test file that is not here (cases kept in the private place, when
    %  that place is not on this machine) is left out, and said
    partition(exists_file, TestFiles0, TestFiles, Missing),
    forall(member(MF, Missing),
           print_message(informational, format("~w: test file not found, left out: ~w", [Name, MF]))),
    read_model(Dir, Kind, Name, Model),
    atomic_list_concat([Dir, '/testResults.xml'], TR),
    ( exists_file(TR) -> Opts1 = [test_results(TR)|Opts] ; Opts1 = Opts ),
    with_line_start(oia_migration(Model, TestFiles, Opts1, Migration)),
    atomic_list_concat([Root, '/', Name], Out),
    make_directory_path(Out),
    write_doc_texts(Model, Out),
    copy_project_sources(Dir, Out),
    Migration = migration(_, program(Header, _), _, _),
    forall(( memberchk(includes(Inc), Header), member(Lib, Inc) ), copy_library(Lib, Out)),
    oia_adapter_map(Model, Opts, Map),
    atomic_list_concat([Out, '/', Name, '.oia_map.json'], MapFile),
    setup_call_cleanup(open(MapFile, write, MS, [encoding(utf8)]),
                       json_write_dict(MS, Map, [width(100)]),
                       close(MS)),
    with_line_start(write_migration(Migration, Out, Name, Report)).

%!  read_model(+Dir, +Kind, +Name, -Model) is det.
%
%   Kind: what the project gives — Policy Modeling's compiled forms (`xgen`,
%   `rulebase`: oia_reader.pl) or the rules as written (`docx`, `ruletxt`,
%   `mixed`, `hub(File)`: oia_text.pl).
read_model(Dir, Kind, Name, Model) :-
    (   memberchk(Kind, [xgen, rulebase])
    ->  oia_read_project(Dir, Kind, Name, Model)
    ;   Kind = hub(F)
    ->  atomic_list_concat([Dir, '/', F], File),
        oia_read_text_project(hub(File), Name, Model)
    ;   Spec =.. [Kind, Dir],
        oia_read_text_project(Spec, Name, Model)
    ).

%   The Word documents' paragraphs, one per line, beside the twin: the text
%   the rules' `confer` quotations are checked against (white space aside,
%   so the blank line before each rule, which makes the text readable, does
%   not change what a quotation matches).
write_doc_texts(oia(_, _, _, Docs), Out) :-
    forall(( member(doc(D, Paras), Docs), Paras \== [] ),
           ( oia_ir:doc_text_path(D, Rel),
             atomic_list_concat([Out, '/', Rel], P),
             file_directory_name(P, PD), make_directory_path(PD),
             setup_call_cleanup(open(P, write, S, [encoding(utf8)]),
                                write_doc_paras(Paras, none, S),
                                close(S)) )).

write_doc_paras([], _, _).
write_doc_paras([para(_, Style, T)|Paras], Previous, S) :-
    (   Previous \== none, \+ para_continues(Style), \+ heading_style(Previous)
    ->  nl(S)
    ;   true
    ),
    oia_ir:quote_text(T, Q), format(S, "~w~n", [Q]),
    write_doc_paras(Paras, Style, S).

%   A paragraph that belongs to the rule above it: a condition (OPM - level
%   N), an alternative conclusion of a rule table, a blank line of OPM's.
para_continues(Style) :-
    downcase_atom(Style, L),
    (   sub_atom(L, _, _, _, level) -> true
    ;   sub_atom(L, _, _, _, alternative) -> true
    ;   sub_atom(L, _, _, _, blank)
    ).

heading_style(Style) :-
    downcase_atom(Style, L),
    sub_atom(L, 0, _, _, heading).

%   A project fetched into the cache, or one this repository holds itself
%   (`extra:<dir>`: reconstructed from Oracle's documentation).
project_dir(C, Rel, Dir) :-
    (   atom_concat('extra:', R, Rel) -> extra_path(R, Dir)
    ;   atomic_list_concat([C, '/', Rel], Dir)
    ).

%   A test file of the project's own (in the fetched cache), or one this
%   repository adds (`extra/...`: synthetic cases, replayed Assess calls).
cache_file(C, R, F) :-
    (   sub_atom(R, 0, _, _, 'extra/')
    ->  sub_atom(R, 6, _, 0, Rest), extra_path(Rest, F)
    ;   atomic_list_concat([C, '/', R], F)
    ).

%   The project's own text files (the compiled rule documents .xgen, the
%   rulebase .xml/.stxt, the project and data model files) beside the twin,
%   in sources/project/: what the editors' Show the Original lists, next to
%   the rule documents' texts. Word, Excel and image files are left out (the
%   viewer shows text). They share the twin's licence status (fetch.sh).
copy_project_sources(Dir, Out) :-
    atomic_list_concat([Out, '/sources/project'], PDir),
    forall(( directory_member(Dir, F, [recursive(true)]),
             file_name_extension(_, Ext0, F), downcase_atom(Ext0, Ext),
             memberchk(Ext, [xgen, xml, stxt, xint, xprj, txt, properties]),
             atom_concat(Dir, '/', DS), atom_concat(DS, Rel, F) ),
           ( atomic_list_concat([PDir, '/', Rel], Dst),
             file_directory_name(Dst, DD), make_directory_path(DD),
             copy_file(F, Dst) )).

%   The writer reads a template's words through le_grammar's DCG, whose
%   section-start guard ("the contract", "scenario", ...) applies only at the
%   start of a line once the line starts of the text are recorded — and at
%   every word when none are (a standalone template text). Recording offset 0
%   as the only line start lets a template contain "the contract price" or
%   "the other country scenario" mid-sentence, as LE itself allows.
%   (Proposed core fix: le_writer:template_text_dict/2 records the line
%   starts of the text it parses.)
:- meta_predicate with_line_start(0).
with_line_start(Goal) :-
    findall(O, le_grammar:line_start_offset(O), Saved),
    setup_call_cleanup(
        ( retractall(le_grammar:line_start_offset(_)), assertz(le_grammar:line_start_offset(0)) ),
        Goal,
        ( retractall(le_grammar:line_start_offset(_)),
          forall(member(O, Saved), assertz(le_grammar:line_start_offset(O))) )).

/** <module> The L4 corpus

    The files of smucclaw/l4-ide (Apache-2.0, Singapore Management
    University) that the L4 translator is built and checked on
    (the design notes l4.md §1, §8): the legal examples, the foundation and
    advanced courses, the reference examples, the prelude and daydate
    libraries, the Jersey charities law and the Singapore Personal Data
    Protection Act experiments. fetch_sources.sh puts the repository, at the
    commit below, in .cache/l4-ide. The evaluator's results for each file are
    cached in runs/<Id>.json (l4_oracle.mjs cache).
*/

:- module(l4_corpus, [corpus_commit/1, corpus_file/3, corpus_path/2, cache_dir/1, unpublished/1]).

%!  unpublished(?Id) is nondet.
%
%   Corpus files whose twins are built and checked (gate.pl, test_l4.pl)
%   but not written into the published examples of LE2 and LPS2. The NY
%   environmental regulation is records and dates rather than obligations:
%   its LPS twin was mostly facts nothing reads, under names no reader
%   would choose, and the weakest thing a reader of the published twins
%   could open first. The
%   builders still build it when asked for by name.
unpublished(legal_ny_environmental_7_3).

:- dynamic here_/1.
:- prolog_load_context(directory, D), retractall(here_(_)), assertz(here_(D)).

%!  corpus_commit(-Sha) is det.
corpus_commit('5e082cf1ecd9876969293edd8afff0f6577aa56e').

%!  cache_dir(-Dir) is det.
cache_dir(D) :- here_(H), atomic_list_concat([H, '/.cache/l4-ide'], D).

%!  corpus_path(+Id, -Path) is semidet.
corpus_path(Id, Path) :-
    corpus_file(Id, Rel, _), cache_dir(D), atomic_list_concat([D, '/', Rel], Path).

%!  corpus_file(?Id, ?RelativePath, ?Group) is nondet.
corpus_file(legal_anti_social, 'jl4/examples/legal/anti-social.l4', legal).
corpus_file(legal_british_citizen_act, 'jl4/examples/legal/british-citizen-act.l4', legal).
corpus_file(legal_ceo_performance_award, 'jl4/examples/legal/ceo-performance-award.l4', legal).
corpus_file(legal_directive_showcase, 'jl4/examples/legal/directive-showcase.l4', legal).
corpus_file(legal_imaginary_alcohol_act, 'jl4/examples/legal/imaginary-alcohol-act.l4', legal).
corpus_file(legal_ny_environmental_7_3, 'jl4/examples/legal/ny-environmental-7.3.l4', legal).
corpus_file(legal_promissory_note, 'jl4/examples/legal/promissory-note.l4', legal).
corpus_file(foundation_charity_obligation, 'doc/courses/foundation/charity-obligation.l4', foundation).
corpus_file(foundation_eligibility_rule, 'doc/courses/foundation/eligibility-rule.l4', foundation).
corpus_file(foundation_hello, 'doc/courses/foundation/hello.l4', foundation).
corpus_file(foundation_module_1_examples, 'doc/courses/foundation/module-1-examples.l4', foundation).
corpus_file(foundation_module_2_examples, 'doc/courses/foundation/module-2-examples.l4', foundation).
corpus_file(foundation_module_3_examples, 'doc/courses/foundation/module-3-examples.l4', foundation).
corpus_file(foundation_module_4_examples, 'doc/courses/foundation/module-4-examples.l4', foundation).
corpus_file(foundation_module_5_examples, 'doc/courses/foundation/module-5-examples.l4', foundation).
corpus_file(foundation_module_6_examples, 'doc/courses/foundation/module-6-examples.l4', foundation).
corpus_file(foundation_sale_contract, 'doc/courses/foundation/sale-contract.l4', foundation).
corpus_file(foundation_type_declaration, 'doc/courses/foundation/type-declaration.l4', foundation).
corpus_file(advanced_module_a1_regulatory_examples, 'doc/courses/advanced/module-a1-regulatory-examples.l4', advanced).
corpus_file(advanced_module_a2_cross_cutting_examples, 'doc/courses/advanced/module-a2-cross-cutting-examples.l4', advanced).
corpus_file(advanced_module_a3_contracts_examples, 'doc/courses/advanced/module-a3-contracts-examples.l4', advanced).
corpus_file(reference_builtins_http_json_example, 'doc/reference/builtins/http-json-example.l4', reference).
corpus_file(reference_control_flow_consider_example, 'doc/reference/control-flow/consider-example.l4', reference).
corpus_file(reference_control_flow_if_example, 'doc/reference/control-flow/if-example.l4', reference).
corpus_file(reference_functions_aka_example, 'doc/reference/functions/aka-example.l4', reference).
corpus_file(reference_functions_decide_example, 'doc/reference/functions/decide-example.l4', reference).
corpus_file(reference_functions_given_example, 'doc/reference/functions/given-example.l4', reference).
corpus_file(reference_functions_giveth_example, 'doc/reference/functions/giveth-example.l4', reference).
corpus_file(reference_functions_let_example, 'doc/reference/functions/let-example.l4', reference).
corpus_file(reference_functions_means_example, 'doc/reference/functions/means-example.l4', reference).
corpus_file(reference_functions_where_example, 'doc/reference/functions/where-example.l4', reference).
corpus_file(reference_functions_yield_example, 'doc/reference/functions/yield-example.l4', reference).
corpus_file(reference_libraries_currency_example, 'doc/reference/libraries/currency-example.l4', reference).
corpus_file(reference_libraries_datetime_example, 'doc/reference/libraries/datetime-example.l4', reference).
corpus_file(reference_libraries_daydate_example, 'doc/reference/libraries/daydate-example.l4', reference).
corpus_file(reference_libraries_import_example, 'doc/reference/libraries/import-example.l4', reference).
corpus_file(reference_libraries_legal_persons_example, 'doc/reference/libraries/legal-persons-example.l4', reference).
corpus_file(reference_libraries_math_example, 'doc/reference/libraries/math-example.l4', reference).
corpus_file(reference_libraries_prelude_example, 'doc/reference/libraries/prelude-example.l4', reference).
corpus_file(reference_libraries_time_example, 'doc/reference/libraries/time-example.l4', reference).
corpus_file(reference_libraries_timezone_example, 'doc/reference/libraries/timezone-example.l4', reference).
corpus_file(reference_operators_and_example, 'doc/reference/operators/and-example.l4', reference).
corpus_file(reference_operators_associativity_example, 'doc/reference/operators/associativity-example.l4', reference).
corpus_file(reference_operators_asyndetic_example, 'doc/reference/operators/asyndetic-example.l4', reference).
corpus_file(reference_operators_implies_example, 'doc/reference/operators/implies-example.l4', reference).
corpus_file(reference_operators_not_example, 'doc/reference/operators/not-example.l4', reference).
corpus_file(reference_operators_or_example, 'doc/reference/operators/or-example.l4', reference).
corpus_file(reference_operators_precedence_example, 'doc/reference/operators/precedence-example.l4', reference).
corpus_file(reference_operators_textual_vs_symbolic_example, 'doc/reference/operators/textual-vs-symbolic-example.l4', reference).
corpus_file(reference_operators_unless_example, 'doc/reference/operators/unless-example.l4', reference).
corpus_file(reference_regulative_because_example, 'doc/reference/regulative/because-example.l4', reference).
corpus_file(reference_regulative_deontic_example, 'doc/reference/regulative/deontic-example.l4', reference).
corpus_file(reference_regulative_may_example, 'doc/reference/regulative/may-example.l4', reference).
corpus_file(reference_regulative_must_example, 'doc/reference/regulative/must-example.l4', reference).
corpus_file(reference_regulative_party_example, 'doc/reference/regulative/party-example.l4', reference).
corpus_file(reference_regulative_shant_example, 'doc/reference/regulative/shant-example.l4', reference).
corpus_file(reference_syntax_annotation_example, 'doc/reference/syntax/annotation-example.l4', reference).
corpus_file(reference_syntax_comment_example, 'doc/reference/syntax/comment-example.l4', reference).
corpus_file(reference_syntax_directive_example, 'doc/reference/syntax/directive-example.l4', reference).
corpus_file(reference_syntax_ditto_example, 'doc/reference/syntax/ditto-example.l4', reference).
corpus_file(reference_syntax_genitive_example, 'doc/reference/syntax/genitive-example.l4', reference).
corpus_file(reference_syntax_identifier_example, 'doc/reference/syntax/identifier-example.l4', reference).
corpus_file(reference_syntax_layout_example, 'doc/reference/syntax/layout-example.l4', reference).
corpus_file(reference_syntax_section_example, 'doc/reference/syntax/section-example.l4', reference).
corpus_file(reference_types_a_an_example, 'doc/reference/types/a-an-example.l4', reference).
corpus_file(reference_types_assume_example, 'doc/reference/types/assume-example.l4', reference).
corpus_file(reference_types_coercion_example, 'doc/reference/types/coercion-example.l4', reference).
corpus_file(reference_types_computed_fields_example, 'doc/reference/types/computed-fields-example.l4', reference).
corpus_file(reference_types_declare_example, 'doc/reference/types/declare-example.l4', reference).
corpus_file(reference_types_either_example, 'doc/reference/types/either-example.l4', reference).
corpus_file(reference_types_enum_example, 'doc/reference/types/enum-example.l4', reference).
corpus_file(reference_types_for_all_example, 'doc/reference/types/for-all-example.l4', reference).
corpus_file(reference_types_function_type_example, 'doc/reference/types/function-type-example.l4', reference).
corpus_file(reference_types_list_example, 'doc/reference/types/list-example.l4', reference).
corpus_file(reference_types_maybe_example, 'doc/reference/types/maybe-example.l4', reference).
corpus_file(reference_types_polymorphic_example, 'doc/reference/types/polymorphic-example.l4', reference).
corpus_file(reference_types_record_example, 'doc/reference/types/record-example.l4', reference).
corpus_file(reference_types_type_inference_example, 'doc/reference/types/type-inference-example.l4', reference).
corpus_file(library_prelude, 'jl4-core/libraries/prelude.l4', library).
corpus_file(library_daydate, 'jl4-core/libraries/daydate.l4', library).
corpus_file(experiment_jerseycharities_genesis, 'jl4/experiments/jerseyCharities-genesis.l4', experiment).
corpus_file(experiment_jerseycharities_types, 'jl4/experiments/jerseyCharities-types.l4', experiment).
corpus_file(experiment_jerseycharities, 'jl4/experiments/jerseyCharities.l4', experiment).
corpus_file(experiment_jerseycharities2_annual_returns, 'jl4/experiments/jerseyCharities2-annual-returns.l4', experiment).
corpus_file(experiment_jerseycharities2_tests, 'jl4/experiments/jerseyCharities2-tests.l4', experiment).
corpus_file(experiment_jerseycharities2, 'jl4/experiments/jerseyCharities2.l4', experiment).
corpus_file(experiment_singapore_data_protection_act, 'jl4/experiments/Singapore-Data-Protection-Act.l4', experiment).

/** <module> Tests of the Socotra reader (Phase 1a of the design notes roadmap.md §8)

    The Liquid parser, the translation of Liquid snippets into rules (symbolic
    execution), the reading of values as the LE table loader reads them, and
    one whole product end to end (Drone: the oracle, the twin, its ledger and
    its scenarios), when the sources have been fetched (fetch_sources.sh).

    Run with (LE2_HOME defaults to /work):
        swipl -q -g run_tests -t halt test_socotra.pl
*/

:- module(test_socotra, []).

:- use_module(library(plunit)).
:- use_module(liquid).
:- use_module(socotra_reader).
:- use_module(library(process)).
:- use_module(library(filesex)).

:- prolog_load_context(directory, D), asserta(user:socotra_test_dir(D)).

%   The rules of a snippet compiled in a scope, and its ledger.
snippet(Text, Scope, Rules, Ledger) :-
    compile_script_text(Text, Scope, Items, Ledger),
    findall(H-B, member(rule(H, B, _), Items), Rules).

residue_in(Text, Scope) :-
    compile_script_text(Text, Scope, Items, _),
    memberchk(residue(_, _), Items).

:- begin_tests(socotra_liquid).

test(assign_and_output) :-
    liquid_parse("{% assign x = data.a.b | times: 2 %}{{ x | set_year_premium }}", AST),
    assertion(AST = [assign(x, filtered(path(data, [key(a), key(b)]), [filter(times, [num(2)])])),
                     output(filtered(path(x, []), [filter(set_year_premium, [])]))]).

test(if_elsif_else) :-
    liquid_parse("{% if a > 1 %}{% assign x = 1 %}{% elsif a == 'k' %}{% assign x = 2 %}{% else %}{% assign x = 3 %}{% endif %}", [if(Bs, Else)]),
    assertion(length(Bs, 2)),
    assertion(Else = [assign(x, _)]).

test(case_is_an_if_chain) :-
    liquid_parse("{% case t %}{% when 'a' %}{% assign x = 1 %}{% when 'b' %}{% assign x = 2 %}{% endcase %}", [if(Bs, _)]),
    assertion(length(Bs, 2)).

test(for_loop) :-
    liquid_parse("{% for e in data.policy.exposures %}{% assign n = n | plus: 1 %}{% endfor %}", [for(e, _, [assign(n, _)])]).

test(comments_are_dropped) :-
    liquid_parse("{% comment %} {% assign x = 1 %} {% endcomment %}{% assign y = 2 %}", AST),
    assertion(AST = [assign(y, _)]).

:- end_tests(socotra_liquid).

:- begin_tests(socotra_translation).

test(branch_merge_is_an_otherwise_cascade) :-
    snippet("{% assign a = data.peril_characteristics.field_values.age %}{% if a > 30 %}{% assign p = 100 %}{% else %}{% assign p = 50 %}{% endif %}{{ p | set_year_premium }}",
            peril(fire, vehicle), Rules, _),
    assertion(( member(_-otherwise([_, _]), Rules) )),
    assertion(( member(H-_, Rules), functor(H, out_year_premium, 3) )).

test(arithmetic_in_the_conclusion) :-
    snippet("{{ data.peril_characteristics.indemnity_in_aggregate | times: 0.02 | set_year_premium }}",
            peril(fire, vehicle), Rules, _),
    once(member(H-B, Rules)),
    assertion(functor(H, out_year_premium, 3)),
    assertion(sub_term(_ is _ * 0.02, B)).

test(lookup_is_a_table_with_a_default,
     [setup(assertz(socotra_reader:g_table_exists(rates))),
      cleanup(retractall(socotra_reader:g_table_exists(rates)))]) :-
    snippet("{% assign r = 'rates' | lookup: data.peril_characteristics.field_values.kind %}{{ r | set_year_premium }}",
            peril(fire, vehicle), Rules, _),
    assertion(( member(H-otherwise([T, _ = 0]), Rules), functor(H, lookup_rates, 2), functor(T, table_rates, 2) )).

test(underwriting_decision_and_note) :-
    snippet("{% assign v = data.policy.characteristics[0].field_values %}{% if v.fraud == 'Yes' %}{{ 'reject' | set_underwriting_decision }}{{ 'No fraud' | add_underwriting_note }}{% endif %}",
            policy, Rules, _),
    assertion(( member(H1-_, Rules), functor(H1, out_decision, 2) )),
    assertion(( member(H2-_, Rules), functor(H2, out_note, 2) )).

test(undefined_variable_is_nil_in_the_ledger) :-
    snippet("{% assign p = missing | plus: 5 %}{{ p | set_year_premium }}", peril(fire, vehicle), _, Ledger),
    assertion(memberchk(entry(_, 'source defect', approximated, _, missing, _), Ledger)).

test(an_unknown_filter_is_residue) :-
    residue_in("{{ data.peril_characteristics.deductible | frobnicate | set_year_premium }}", peril(fire, vehicle)).

test(a_group_loop_is_residue) :-
    residue_in("{% assign t = 0 %}{% for c in data.exposure_characteristics.field_values.countries %}{% assign t = t | plus: 1 %}{% endfor %}{{ t | set_year_premium }}",
               peril(fire, vehicle)).

test(a_table_the_product_lacks_reads_zero) :-
    snippet("{% assign r = 'nosuch' | lookup: 'k' %}{{ r | set_year_premium }}", peril(fire, vehicle), _, Ledger),
    assertion(memberchk(entry(nosuch, 'source defect', approximated, _, 0, _), Ledger)).

%   round: d, as the reference Liquid computes it (half away from zero, a
%   double), not residue.
test(round_to_decimals) :-
    snippet("{{ data.peril_characteristics.deductible | times: 1.2345 | round: 2 | set_year_premium }}",
            peril(fire, vehicle), Rules, _),
    once(member(H-B, Rules)),
    assertion(functor(H, out_year_premium, 3)),
    assertion(sub_term(_ is round(_ * 100) / 100.0, B)),
    X = 1000, V is round(X * 1.2345 * 100) / 100.0, assertion(V == 1234.5).

%   A quantity whose branches give texts is a value, not a number — and it is
%   declared a FUNCTION (declaration_item/4): every quantity is one value per
%   key, so the twin may write it where it is used.
test(text_quantity_is_a_value,
     [setup(assertz(socotra_reader:g_table_exists(rates))),
      cleanup(retractall(socotra_reader:g_table_exists(rates)))]) :-
    compile_script_text("{% if data.peril_characteristics.deductible <= 500 %}{% assign k = 'A' %}{% else %}{% assign k = 'B' %}{% endif %}{% assign r = 'rates' | lookup: k %}{{ r | set_year_premium }}",
                        peril(fire, vehicle), Items, _),
    assertion(( member(function(F, T, _), Items), atom_concat(q_, _, F),
                sub_atom(T, _, _, 0, 'is *a value*') )),
    assertion(\+ ( member(I2, Items), ( I2 = function(F2, T2, _) ; I2 = template(F2, T2, _) ),
                   atom_concat(q_, _, F2),
                   sub_atom(T2, _, _, _, 'is *a number*') )).

:- end_tests(socotra_translation).

:- begin_tests(socotra_values).

test(numbers_as_the_csv_loader_reads_them) :-
    socotra_reader:le_value("1.5", A), assertion(A == 1.5),
    % a code with a leading zero stays a code, as the CSV loader reads it
    socotra_reader:le_value("0005", B), assertion(B == "0005"),
    socotra_reader:le_value("Low Risk Co", C), assertion(C == "Low Risk Co").

test(a_comparison_sign_is_spelled_out) :-
    socotra_reader:reset_gen,
    socotra_reader:le_value("<50%", V), assertion(V == "under 50%").

:- end_tests(socotra_values).

:- begin_tests(socotra_product, [condition(drone_fetched)]).

drone_fetched :-
    user:socotra_test_dir(D),
    atomic_list_concat([D, '/sources/.cache/product-library/Drone/policy/policy.json'], F),
    exists_file(F).

%   The reference run needs python-liquid; without it, the quotes of the
%   published twin (the run is deterministic).
oracle_options(Out, Opts) :-
    (   catch(( process_create(path(python3), ['-c', 'import liquid'], [stderr(null), process(Pid)]),
                process_wait(Pid, exit(0)) ), _, fail)
    ->  Opts = []
    ;   le2_paths:twins_dir(socotra, TD),
        atomic_list_concat([TD, '/drone/quotes.json'], Q),
        atomic_list_concat([Out, '/drone'], OD), make_directory_path(OD),
        atomic_list_concat([OD, '/quotes.json'], Q2), copy_file(Q, Q2),
        Opts = [reuse_quotes(true)]
    ).

test(drone_end_to_end) :-
    user:socotra_test_dir(D),
    atomic_list_concat([D, '/sources/.cache/product-library/Drone'], Src),
    tmp_file(socotra, Out), make_directory(Out),
    oracle_options(Out, Opts),
    build_product(Src, Out, report(LE, Errors, counts(Enc, _, Res), fidelity(P, F, E, _)), Opts),
    assertion(exists_file(LE)),
    assertion(\+ memberchk(issue(error, _, _), Errors)),     % a quoted document name is only info
    assertion(Enc > 0), assertion(Res =:= 0),
    assertion(P > 0), assertion(F =:= 0), assertion(E =:= 0),
    atomic_list_concat([Out, '/drone/drone.ledger.md'], MD), assertion(exists_file(MD)),
    read_file_to_string(LE, Text, []),
    assertion(sub_string(Text, _, _, _, "quote desk")).

%   Every cited file is a document (its page at the pinned commit, its text
%   the copy in the twin's sources/), and each rule
%   points at its passage: a quotation, or the lines of an if block.
test(documents_and_passages) :-
    user:socotra_test_dir(D),
    atomic_list_concat([D, '/sources/.cache/product-library/Contract Surety'], Src),
    tmp_file(socotra, Out), make_directory(Out),
    le2_paths:twins_dir(socotra, TD),
    atomic_list_concat([TD, '/contract_surety/quotes.json'], Q),
    atomic_list_concat([Out, '/contract_surety'], OD), make_directory_path(OD),
    atomic_list_concat([OD, '/quotes.json'], Q2), copy_file(Q, Q2),
    build_product(Src, Out, report(LE, _, _, fidelity(_, 0, 0, _)), [reuse_quotes(true)]),
    read_file_to_string(LE, Text, []),
    assertion(sub_string(Text, _, _, _, "is published at \"https://github.com/socotra/product-library/blob/df4a7f851ac6e3a79ecf6b2c007d75bd6c22c9e8/Contract%20Surety/policy/")),
    %  the text is the copy beside the twin, in sources/
    assertion(sub_string(Text, _, _, _, "the text of \"Contract Surety/policy/taxes/sales.premium.liquid\" is at \"sources/Contract Surety/policy/taxes/sales.premium.liquid\"")),
    atomic_list_concat([OD, '/sources/Contract Surety/policy/taxes/sales.premium.liquid'], Copy),
    assertion(exists_file(Copy)),
    assertion(sub_string(Text, _, _, _, "license.premium.liquid\" at lines 3 to 9:")),
    assertion(sub_string(Text, _, _, _, "confer \"{{ premium | set_year_premium }}\"")),
    assertion(sub_string(Text, _, _, _, "the text of Contract Surety rating quotes is at \"quotes.json\"")).

%   File > Open of a configuration (socotra_import): the product found one
%   folder down, translated with its residue as a TODO block, its files
%   copied beside it in sources/ and cited there (quotations checked), no quotes
%   without the reference run.
test(import_a_configuration) :-
    user:socotra_test_dir(D),
    atomic_list_concat([D, '/sources/.cache/product-library/Homeowners'], Src),
    tmp_file(socotra, Tmp),
    atomic_list_concat([Tmp, '/in/products/Homeowners'], In), make_directory_path(In),
    copy_directory(Src, In),
    atomic_list_concat([Tmp, '/out'], Out), make_directory_path(Out),
    atomic_list_concat([Tmp, '/in'], Upload),
    atomic_list_concat([D, '/socotra_import'], ImportModule),
    use_module(ImportModule),
    assertion(socotra_import:detect_socotra(Upload)),
    socotra_import:import_socotra(Upload, Out, imported(LE, Notes)),
    assertion(Notes \== []),
    read_file_to_string(LE, Text, []),
    assertion(sub_string(Text, _, _, _, "% TODO")),
    assertion(sub_string(Text, _, _, _, "the text of \"Homeowners/policy/taxes/sales.premium.liquid\" is at \"sources/Homeowners/policy/taxes/sales.premium.liquid\"")),
    atomic_list_concat([Out, '/sources/Homeowners/policy/taxes/sales.premium.liquid'], Copied),
    assertion(exists_file(Copied)),
    le_kbs:load(LE, KB),
    assertion(\+ KB:le_issue(error, _, _, _, _, _)),
    assertion(\+ KB:le_issue(_, quote_not_found, _, _, _, _)).

:- end_tests(socotra_product).

:- begin_tests(socotra_import).

import_module :-
    user:socotra_test_dir(D),
    atomic_list_concat([D, '/socotra_import'], M), use_module(M).

write_text(File, Text) :-
    file_directory_name(File, Dir), make_directory_path(Dir),
    setup_call_cleanup(open(File, write, S), write(S, Text), close(S)).

%   A synthetic product: one exposure, one peril, a text-valued key.
synthetic_product(Root, PD) :-
    atomic_list_concat([Root, '/Gadget'], PD),
    atomic_list_concat([PD, '/policy/policy.json'], P),
    write_text(P, "{\"fields\": [{\"name\": \"channel\", \"type\": \"select\", \"values\": [\"Direct\", \"Agent\"]}], \"documents\": []}"),
    atomic_list_concat([PD, '/policy/exposures/Phone/exposure.json'], E),
    write_text(E, "{\"name\": \"Phone\", \"fields\": [{\"name\": \"value\", \"type\": \"number\"}]}"),
    atomic_list_concat([PD, '/policy/exposures/Phone/perils/theft.json'], TJ),
    write_text(TJ, "{\"name\": \"theft\", \"fields\": []}"),
    atomic_list_concat([PD, '/policy/exposures/Phone/perils/theft.premium.liquid'], TL),
    write_text(TL, "{% assign v = data.exposure_characteristics.field_values.value %}{{ v | times: 0.0375 | round: 2 | set_year_premium }}").

%   Without the reference run the note says that the quote scenarios were
%   skipped, and why (here: no python3 on the PATH); the files are in
%   sources/<Product>/, as the note says.
test(import_without_reference_run_says_why,
     [setup(( tmp_file(socotra, T), make_directory(T), getenv('PATH', Path) )),
      cleanup(( setenv('PATH', Path), delete_directory_and_contents(T) ))]) :-
    import_module,
    synthetic_product(T, _),
    atomic_list_concat([T, '/out'], Out), make_directory(Out),
    setenv('PATH', '/nonexistent'),
    socotra_import:import_socotra(T, Out, imported(LE, Notes)),
    setenv('PATH', Path),
    assertion(( member(N, Notes), sub_string(N, 0, _, _, "Quote scenarios skipped: "),
                sub_string(N, _, _, _, "python3") )),
    assertion(( member(N2, Notes), sub_string(N2, _, _, _, "copied into sources/Gadget/") )),
    atomic_list_concat([Out, '/sources/Gadget/policy/policy.json'], Copied),
    assertion(exists_file(Copied)),
    read_file_to_string(LE, Text, []),
    assertion(sub_string(Text, _, _, _, "No quote scenarios: ")),
    assertion(sub_string(Text, _, _, _, "round(")),
    assertion(\+ sub_string(Text, _, _, _, "% TODO")),
    le_kbs:load(LE, KB),
    assertion(\+ KB:le_issue(error, _, _, _, _, _)).

%   A python3 without python-liquid: that is the reason given.
test(import_without_python_liquid_says_why,
     [setup(( tmp_file(socotra, T), make_directory(T), getenv('PATH', Path) )),
      cleanup(( setenv('PATH', Path), delete_directory_and_contents(T) ))]) :-
    import_module,
    synthetic_product(T, PD),
    atomic_list_concat([T, '/bin/python3'], Py),
    write_text(Py, "#!/bin/sh\nexit 1\n"),
    chmod(Py, +x),
    atomic_list_concat([T, '/bin:/usr/bin:/bin'], P2), setenv('PATH', P2),
    atomic_list_concat([T, '/out'], Out), make_directory(Out),
    socotra_import:quotes_run(PD, '/nonexistent/quotes.json', Outcome),
    setenv('PATH', Path),
    assertion(( Outcome = skipped(Why), sub_string(Why, _, _, _, "python-liquid") )).

%   A lone policy.json is a Socotra configuration file: its fields become
%   the facts of a quote, and the note says what else the folder holds.
test(import_lone_policy_json,
     [setup(( tmp_file(socotra, T), make_directory(T) )),
      cleanup(delete_directory_and_contents(T))]) :-
    import_module,
    synthetic_product(T, PD),
    atomic_list_concat([PD, '/policy/policy.json'], P),
    atomic_list_concat([T, '/out'], Out), make_directory(Out),
    assertion(socotra_import:detect_socotra(P)),
    socotra_import:import_socotra(P, Out, imported(LE, Notes)),
    assertion(( member(N, Notes), sub_string(N, 0, _, _, "Only policy.json was uploaded") )),
    read_file_to_string(LE, Text, []),
    assertion(sub_string(Text, _, _, _, "the channel of *a policy* is *a value*")),
    le_kbs:load(LE, KB),
    assertion(\+ KB:le_issue(error, _, _, _, _, _)),
    atomic_list_concat([T, '/other.json'], O),
    write_text(O, "{\"items\": [1, 2]}"),
    assertion(\+ socotra_import:detect_socotra(O)).

:- end_tests(socotra_import).

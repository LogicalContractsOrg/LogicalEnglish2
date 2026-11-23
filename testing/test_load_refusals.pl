/*  A load that cannot give a session answers why, instead of failing: a
    failed operation was a 500 and a Sentry report "the operation failed
    without an exception" that said nothing of what had happened.
*/
:- use_module('../le_api').
:- use_module('../le_telemetry').

:- begin_tests(load_refusals).

%   An example that does not exist (an old link, a mistyped ?example=).
test(missing_example_is_not_found) :-
    le_api:handle_load(_{file: "no/such/example_zzz"}, R),
    assertion(get_dict(notFound, R, true)),
    assertion(( get_dict(error, R, E), sub_string(E, _, _, _, "no/such/example_zzz") )).

%   A program that loads still gets its session.
test(loadable_text_gets_a_session) :-
    le_api:handle_load(_{le: "the target language is: prolog.\n\nthe templates are:\n    *a thing* is fine.\n\nthe knowledge base t includes:\n    a thing is fine if the thing is fine.\n"}, R),
    assertion(get_dict(sessionModule, R, _)).

%   A failure inside the server names its stage in the report.
test(failure_report_names_the_stage) :-
    le_telemetry:error_type_value(failed(load_text), Type, Value, Level, _),
    assertion(Type == failure), assertion(Level == error),
    assertion(sub_string(Value, _, _, _, "at load_text")).

%   A constant line with a `;` in it read a template with no name, and the
%   failed `the constants are:` section failed the whole load: the 500 that
%   Sentry reported as "the operation failed without an exception, at
%   load_text". The line is now an issue, and the program loads.
test(constant_with_semicolon_is_an_issue) :-
    le_api:handle_load(_{le: "the constants are:\n    the rate is 5 ; opposite: the rate is 6.\n"}, R),
    assertion(get_dict(sessionModule, R, _)),
    assertion(( get_dict(issues, R, Is), member(I, Is), get_dict(severity, I, error) )).

%   A section that cannot be processed is an error at that section, with
%   its kind, instead of a failed load.
test(failed_section_is_an_issue) :-
    M = test_load_refusals_failed_section,
    dynamic(M:le_issue/6),
    le_kbs:process_section_or_issue(constants([dict(x)], [], 5, 9), M),
    assertion(M:le_issue(error, section_not_processed, _, _, 5, 9)),
    assertion(( M:le_issue(_, _, Desc, _, _, _), sub_atom(Desc, _, _, _, constants) )).

:- end_tests(load_refusals).

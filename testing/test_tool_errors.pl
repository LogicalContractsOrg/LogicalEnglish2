% The errors the tools give a caller (MCP, REST, the light assistant) when a
% query names an example that does not exist: the example is named, not the
% tool, and a folder's name leads to the program in it.

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_tools').
:- use_module('../llm/mcp').

%   error_mentions(+Text, +Part): Part occurs in Text.
error_mentions(Text, Part) :- once(sub_string(Text, _, _, _, Part)).

:- begin_tests(tool_errors).

test(folder_name_suggests_program) :-
    le_tool_query(_{example_name: "migration/blawx/rps", query: "bobjane"}, R),
    error_mentions(R.error, "Example 'migration/blawx/rps' not found"),
    error_mentions(R.error, "did you mean 'migration/blawx/rps/rps'?").

test(unknown_example_named) :-
    le_tool_query(_{example_name: "no_such_example", query: "which person is happy"}, R),
    error_mentions(R.error, "Example 'no_such_example' not found"),
    error_mentions(R.error, "list_examples").

test(known_example_still_answers) :-
    le_tool_query(_{example_name: "citizenship", query: "one", scenario_name: "alice"}, R),
    R.results = [A|_],
    A.answer == "John acquires British citizenship on 2021-10-09".

test(mcp_failed_tool_is_not_unknown) :-
    mcp:call_tool("get_example_details", _{}, R),
    \+ error_mentions(R.error, "Unknown tool"),
    error_mentions(R.error, "get_example_details").

test(mcp_unknown_tool) :-
    mcp:call_tool("no_such_tool", _{}, R),
    error_mentions(R.error, "Unknown tool: no_such_tool").

:- end_tests(tool_errors).

% What the MCP tools send a language model that has only the tools: a long
% program's text is left out of get_example_details unless asked for (a client
% refuses a reply over its limit, templates and all), list_examples takes a
% filter, and a name given without its tree is answered with the full name.

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_tools').
:- use_module('../llm/mcp').

mentions(Text, Part) :- once(sub_string(Text, _, _, _, Part)).

:- begin_tests(mcp_compact).

test(long_text_left_out) :-
    once(mcp:call_tool("get_example_details", _{example_name: "regulatory/bna"}, R)),
    \+ get_dict(program_text, R, _),
    R.program_text_omitted > 30000,
    mentions(R.note, "include_program_text"),
    R.templates \== [].

test(long_text_on_request) :-
    once(mcp:call_tool("get_example_details", _{example_name: "regulatory/bna", include_program_text: true}, R)),
    mentions(R.program_text, "British Nationality Act").

test(short_text_kept) :-
    once(mcp:call_tool("get_example_details", _{example_name: "citizenship"}, R)),
    mentions(R.program_text, "acquires British citizenship").

test(name_without_tree_suggested) :-
    once(mcp:call_tool("get_example_details", _{example_name: "bna"}, R)),
    mentions(R.error, "did you mean 'regulatory/bna'?").

test(list_filter) :-
    once(mcp:call_tool("list_examples", _{filter: "regulatory/bna"}, R)),
    R.examples \== [],
    forall(member(E, R.examples), mentions(E.name, "bna")).

:- end_tests(mcp_compact).

/** <module> Logical English MCP Server
    
    This module implements the Model Context Protocol (MCP) for Logical English.
    It allows LLMs to interact with Logical English KBs through tools,
    prompts, and resources. It supports both STDIO (untested) and HTTP transports.
*/

:- module(mcp, [handle_mcp/1, handle_rest_list_examples/1, handle_rest_query/1, handle_rest_verify/1, handle_rest_example_details/1, handle_mcp_stdio/0]).

:- use_module(library(http/http_json)).
:- use_module(library(http/http_dispatch)).
:- use_module('../le_kbs').
:- use_module('../tokenizer').
:- use_module('../le_grammar').
:- use_module('../reasoner').
:- use_module('../le_system_templates').
:- use_module('../le_tools').
:- use_module('../le_docs_search', [docs_search_answer/4]).
:- use_module('../restricted_paths', [is_path_allowed/2]).
:- use_module('../le_throttle').
:- use_module('../le_entitlements').
:- use_module('../le_i18n').

%   The client of the request being served over HTTP (le_throttle.pl's
%   identity), for the tools that answer differently to a remote client.
:- thread_local mcp_identity/1.

:- dynamic mcp_only_query_verify/0.
% mcp_only_query_verify. % Uncomment to enable the flag

% --- STDIO Handler ---

handle_mcp_stdio :-
    set_stream(user_input, encoding(utf8)),
    set_stream(user_output, encoding(utf8)),
    loop_mcp_stdio.

loop_mcp_stdio :-
    catch(json_read_dict(user_input, Dict), _, Dict = end_of_file),
    (   Dict == end_of_file -> true
    ;   (   get_dict(method, Dict, Method) ->
            (   get_dict(id, Dict, ID) ->
                (   handle_method(Method, Dict, Response) ->
                    json_write_dict(user_output, Response, [width(0)]),
                    nl(user_output),
                    flush_output(user_output)
                ;   json_write_dict(user_output, _{jsonrpc: "2.0", id: ID, error: _{code: -32601, message: "Method not found"}}, [width(0)]),
                    nl(user_output),
                    flush_output(user_output)
                )
            ;   % Notification
                (handle_method(Method, Dict, _) -> true ; true)
            )
        ;   true
        ),
        loop_mcp_stdio
    ).

% --- HTTP Handler ---

handle_mcp(Request) :-
    (   member(method(post), Request) ->
        http_read_json_dict(Request, Dict),
        % Who asks (a key, a sign-in or the address), and so the budget of the
        % call and what it may open (le_throttle.pl).
        throttle_identity(Request, Identity),
        identity_entitlements(Identity),
        retractall(mcp_identity(_)), assertz(mcp_identity(Identity)),
        new_session_header(Request, Dict),
        % Attribute any verify captures during this request to the calling job,
        % so concurrent assistant jobs cannot recover each other's work.
        mcp_job_token(Request, JobToken),
        (   tool_call(Dict, Tool, Args),
            admit_tool(Identity, Tool, Args, refuse(_, _, Message))
        ->  reply_tool_refusal(Dict, Message)
        ;   setup_call_cleanup(
                set_verify_job(JobToken),
                throttle_run(Identity, handle_mcp_post(Dict), Outcome),
                clear_verify_job),
            mcp_outcome(Outcome, Dict)
        )
    ;   member(method(get), Request) ->
        % mcp-remote or other clients might try GET for SSE
        reply_json_dict(_{error: "SSE not implemented, use POST JSON-RPC"}, [status(405)])
    ;   reply_json_dict(_{error: "Method not allowed"}, [status(405)])
    ).

%   A key's licences apply to the call it carries: the sign-in cookie set the
%   request's entitlements already (classic_web_api.pl), and a key replaces
%   them.
identity_entitlements(Identity) :-
    (   get_dict(caps, Identity, Caps), is_list(Caps)
    ->  set_request_entitlements(Caps)
    ;   true
    ).

%   The reply to `initialize` names a new MCP session (`Mcp-Session-Id`),
%   which the client sends back with every later request: the clients behind
%   one address then have a budget each. A header line written before the
%   reply's own goes out with it.
new_session_header(Request, Dict) :-
    (   get_dict(method, Dict, M), match_method(initialize, M),
        \+ memberchk(mcp_session_id(_), Request)
    ->  throttle_new_session(S),
        format('Mcp-Session-Id: ~w~n', [S])
    ;   true
    ).

tool_call(Dict, Tool, Args) :-
    get_dict(method, Dict, M), match_method('tools/call', M),
    Params = Dict.get(params, _{}),
    Tool = Params.get(name, ""),
    Args = Params.get(arguments, _{}).

%!  admit_tool(+Identity, +Tool, +Args, -Verdict) is det.
%
%   Whether the client's budget allows this call: a query or a check costs
%   three, a look-up one; the texts it sends count against the size limit.
admit_tool(Identity, Tool, Args, Verdict) :-
    ( memberchk(Tool, ["query", "verify", query, verify]) -> Cost = 3 ; Cost = 1 ),
    (   is_dict(Args)
    ->  findall(L, ( member(K, [program_text, facts, query]),
                     get_dict(K, Args, V), ( string(V) ; atom(V) ), string_length(V, L) ), Ls)
    ;   Ls = []
    ),
    throttle_admit(Identity, Cost, Ls, Verdict).

%   A refused call is a tool result marked isError, with a message the model
%   can read and repeat: some clients take an HTTP error for a broken link.
reply_tool_refusal(Dict, Message) :-
    ( get_dict(id, Dict, ID) -> true ; ID = null ),
    format(user_error, "MCP Refused: ~w~n", [Message]),
    reply_json_dict(_{jsonrpc: "2.0", id: ID,
                      result: _{content: [_{type: "text", text: Message}], isError: true}}).

%   A call that waited too long for its turn, or ran out of time, is told
%   so; one that failed or raised an error was not answered at all.
mcp_outcome(done, _) :- !.
mcp_outcome(busy(Message), Dict) :- !, reply_tool_refusal(Dict, Message).
mcp_outcome(timeout(Message), Dict) :- !, reply_tool_refusal(Dict, Message).
mcp_outcome(Outcome, Dict) :-
    ( get_dict(id, Dict, ID) -> true ; ID = null ),
    format(user_error, "MCP Error: ~q~n", [Outcome]),
    reply_json_dict(_{jsonrpc: "2.0", id: ID,
                      error: _{code: -32603, message: "Internal error during tool execution"}}).

%   The roles (capabilities) the tools open the example trees with: the
%   request's entitlements on a server, none otherwise.
mcp_roles(Roles) :-
    (   current_entitlements(C), is_list(C) -> Roles = C ; Roles = [] ).

%!  mcp_job_token(+Request, -Token) is det.
%
%   Extracts the LE Assistant job token threaded through the MCP URL by the
%   assistant backend (e.g. .../mcp?job=job_7), falling back to the X-LE-Job
%   header. Yields 'none' when absent (REST clients, manual calls, etc.).
mcp_job_token(Request, Token) :-
    (   member(search(Search), Request),
        member(job=Raw, Search),
        Raw \== '', Raw \== ""
    ->  to_token_atom(Raw, Token)
    ;   member(x_le_job(Raw), Request),
        Raw \== '', Raw \== ""
    ->  to_token_atom(Raw, Token)
    ;   Token = none
    ).

to_token_atom(X, A) :- ( atom(X) -> A = X ; atom_string(A, X) ).

handle_mcp_post(Dict) :-
        % Log request for debugging
        ( get_dict(method, Dict, Method) -> true ; Method = unknown ),
        ( Method \== 'tools/call' -> format(user_error, "MCP Request: ~w~n", [Method]) ; 
          get_dict(params, Dict, Params), get_dict(name, Params, ToolName0),
          (   sub_atom(ToolName0, Before, _, _, '<')
          ->  sub_atom(ToolName0, 0, Before, _, ToolName),
              format(user_error, "MCP Request: tools/call ~w (cleaned)~n", [ToolName])
          ;   ToolName = ToolName0,
              format(user_error, "MCP Request: tools/call ~w~n", [ToolName])
          )
        ),
        (   get_dict(method, Dict, Method) ->
            (   get_dict(id, Dict, ID) ->
                (   handle_method(Method, Dict, Response) ->
                    % format(user_error, "MCP Response: ~w~n", [Response]),
                    reply_json_dict(Response)
                ;   format(user_error, "MCP Method not found: ~w~n", [Method]),
                    reply_json_dict(_{jsonrpc: "2.0", id: ID, error: _{code: -32601, message: "Method not found"}}, [status(404)])
                )
            ;   % Notification
                (handle_method(Method, Dict, _) -> true ; true),
                reply_json_dict(_{result: "ok"})
            )
        ;   reply_json_dict(_{jsonrpc: "2.0", error: _{code: -32600, message: "Invalid Request"}}, [status(400)])
        ).

% Helper to match method names as either strings or atoms
match_method(Target, Method) :-
    (   string(Method) -> atom_string(Target, Method)
    ;   Target == Method
    ).

handle_method(Method, Dict, Response) :-
    match_method('initialize', Method), !,
    get_dict(id, Dict, ID),
    Response = _{
        jsonrpc: "2.0",
        id: ID,
        result: _{
            protocolVersion: "2024-11-05",
            capabilities: _{
                tools: _{},
                prompts: _{},
                resources: _{}
            },
            serverInfo: _{
                name: "Logical English MCP Server",
                version: "1.0.0"
            }
        }
    }.

handle_method(Method, Dict, Response) :-
    match_method('resources/list', Method), !,
    get_dict(id, Dict, ID),
    Response = _{
        jsonrpc: "2.0",
        id: ID,
        result: _{
            resources: [
                _{
                    uri: "le://docs/syntax",
                    name: "Logical English language reference",
                    mimeType: "text/markdown",
                    description: "The Logical English language reference: every construct, with examples"
                }
            ]
        }
    }.

handle_method(Method, Dict, Response) :-
    match_method('resources/read', Method), !,
    get_dict(id, Dict, ID),
    Params = Dict.get(params, _{}),
    URI = Params.get(uri, ""),
    (   URI == "le://docs/syntax" ->
        read_file_to_string('docs/user/reference/language.md', Text, []),
        Response = _{
            jsonrpc: "2.0",
            id: ID,
            result: _{
                contents: [
                    _{
                        uri: URI,
                        mimeType: "text/markdown",
                        text: Text
                    }
                ]
            }
        }
    ;   fail
    ).

handle_method(Method, Dict, Response) :-
    match_method('prompts/list', Method), !,
    get_dict(id, Dict, ID),
    Response = _{
        jsonrpc: "2.0",
        id: ID,
        result: _{
            prompts: [
                _{
                    name: "use_logical_english",
                    description: "Set up the LLM to work with a specific Logical English program",
                    arguments: [
                        _{
                            name: "example_name",
                            description: "The name of the LE program to use (e.g., 'citizenship')",
                            required: true
                        }
                    ]
                },
                _{
                    name: "massage_query",
                    description: "Help massage a user's natural language question into a valid Logical English query based on available templates",
                    arguments: [
                        _{
                            name: "user_question",
                            description: "The question as asked by the user",
                            required: true
                        },
                        _{
                            name: "templates",
                            description: "Available Logical English templates for the program",
                            required: true
                        }
                    ]
                },
                _{
                    name: "massage_facts",
                    description: "Help massage a sequence of natural language facts into valid Logical English template instances based on available templates",
                    arguments: [
                        _{
                            name: "user_facts",
                            description: "The facts as described by the user in natural language",
                            required: true
                        },
                        _{
                            name: "templates",
                            description: "Available Logical English templates for the program",
                            required: true
                        }
                    ]
                }
            ]
        }
    }.

handle_method(Method, Dict, Response) :-
    match_method('prompts/get', Method), !,
    get_dict(id, Dict, ID),
    Params = Dict.get(params, _{}),
    PromptName = Params.get(name, ""),
    Args = Params.get(arguments, _{}),
    (   PromptName == "use_logical_english" ->
        ExampleName = Args.get(example_name, ""),
        format(string(PromptText), 
               "You are an expert in Logical English. You are working with the program '~w'. ~n~nFollow these steps for every user request:~n1. Call 'get_example_details' with example_name: \"~w\" to understand the available templates and queries.~n2. If the user provides facts in natural language, use your internal reasoning to rewrite them into valid Logical English facts that match the templates EXACTLY. Each fact must end with a period.~n3. Rewrite the user's question into a single Logical English query that matches one of the templates exactly. Do not add a period.~n4. Call the 'query' tool with the massaged facts and query.~n5. Explain the results to the user in natural language, using the provided explanation tree.~n~nRead the resource 'le://docs/syntax' if you need a refresher on Logical English syntax.", 
               [ExampleName, ExampleName]),
        Response = _{
            jsonrpc: "2.0",
            id: ID,
            result: _{
                description: "Set up LE expert persona",
                messages: [
                    _{
                        role: "user",
                        content: _{
                            type: "text",
                            text: PromptText
                        }
                    }
                ]
            }
        }
    ;   PromptName == "massage_query" ->
        UserQuestion = Args.get(user_question, ""),
        Templates = Args.get(templates, ""),
        format(string(PromptText), 
               "The user wants to ask: \"~w\"~n~nAvailable Logical English templates are:~n~w~n~nYour task is to rewrite the user's question into a single Logical English query that matches one of the templates exactly. ~n- Use variables (starting with an uppercase letter) for unknown values.~n- Do not add a period at the end.~n- Return ONLY the massaged query text.", 
               [UserQuestion, Templates]),
        Response = _{
            jsonrpc: "2.0",
            id: ID,
            result: _{
                description: "Massage user question into LE query",
                messages: [
                    _{
                        role: "user",
                        content: _{
                            type: "text",
                            text: PromptText
                        }
                    }
                ]
            }
        }
    ;   PromptName == "massage_facts" ->
        UserFacts = Args.get(user_facts, ""),
        Templates = Args.get(templates, ""),
        format(string(PromptText), 
               "The user provides these facts: \"~w\"~n~nAvailable Logical English templates are:~n~w~n~nYour task is to rewrite the user's facts into a sequence of Logical English facts, each matching one of the templates exactly. ~n- Each fact must end with a period.~n- Use specific values from the user's input.~n- Return ONLY the massaged facts text, one per line.", 
               [UserFacts, Templates]),
        Response = _{
            jsonrpc: "2.0",
            id: ID,
            result: _{
                description: "Massage user facts into LE facts",
                messages: [
                    _{
                        role: "user",
                        content: _{
                            type: "text",
                            text: PromptText
                        }
                    }
                ]
            }
        }
    ;   fail
    ).

handle_method(Method, Dict, Response) :-
    match_method('tools/list', Method), !,
    get_dict(id, Dict, ID),
    AllTools = [
        _{
            name: "list_examples",
            description: "List Logical English program example names and their summaries. The full list is long: give a filter (words that the name or the summary must contain) to get only the examples about a subject",
            inputSchema: _{
                type: "object",
                properties: _{
                    filter: _{ type: "string", description: "Optional: words that each listed example's name or summary must contain, e.g. \"nationality\" or \"tax\"" }
                }
            }
        },
        _{
            name: "get_example_details",
            description: "Get the templates, queries and scenarios of a specific example, and its text when the text is short (or when include_program_text is true)",
            inputSchema: _{
                type: "object",
                properties: _{
                    example_name: _{ type: "string", description: "Name of the example program" },
                    include_program_text: _{ type: "boolean", description: "Optional: send the program's text even when it is long (by default a text of more than 30000 characters is left out; the templates and queries are enough to query the program)" }
                },
                required: ["example_name"]
            }
        },
        _{
            name: "query",
            description: "Execute a query. MANDATORY: You MUST call get_example_details first to get the correct templates. Your 'facts' and 'query' strings MUST match those templates EXACTLY, word-for-word, or the query will fail. Do not paraphrase or hallucinate templates.",
            inputSchema: _{
                type: "object",
                properties: _{
                    example_name: _{ type: "string", description: "Name of the example program" },
                    program_text: _{ type: "string", description: "Logical English program text" },
                    scenario_name: _{ type: "string", description: "Name of a scenario defined in the program" },
                    facts: _{ type: "string", description: "Additional Logical English facts (MUST match templates exactly)" },
                    query: _{ type: "string", description: "The query to execute (MUST match a template exactly)" }
                },
                required: ["query"]
            }
        },
        _{
            name: "search_documentation",
            description: "Search the user documentation of Logical English and its editor (the language reference, tutorials, guides, integrations) for a few keywords; returns the sections found, each with a link relative to the server. Use it to answer a question about the language or the editor, citing at most three of the links.",
            inputSchema: _{
                type: "object",
                properties: _{
                    query: _{ type: "string", description: "A few keywords, as the documentation would word them (a phrase in double quotes must occur as it is)" }
                },
                required: ["query"]
            }
        },
        _{
            name: "verify",
            description: "Parse and verify a Logical English program, returning all issues found",
            inputSchema: _{
                type: "object",
                properties: _{
                    program_text: _{ type: "string", description: "Logical English program text" }
                },
                required: ["program_text"]
            }
        }
    ],
    (   mcp_only_query_verify
    ->  include(mcp:is_query_or_verify, AllTools, Tools)
    ;   Tools = AllTools
    ),
    Response = _{
        jsonrpc: "2.0",
        id: ID,
        result: _{
            tools: Tools
        }
    }.

handle_method(Method, Dict, Response) :-
    match_method('tools/call', Method), !,
    get_dict(id, Dict, ID),
    Params = Dict.get(params, _{}),
    ToolName0 = Params.get(name, ""),
    % Clean tool name from potential LLM hallucinations like <|channel|>commentary
    (   sub_atom(ToolName0, Before, _, _, '<')
    ->  sub_atom(ToolName0, 0, Before, _, ToolName)
    ;   ToolName = ToolName0
    ),
    Args = Params.get(arguments, _{}),
    (   catch(call_tool(ToolName, Args, ToolResult), E, (term_string(E, ErrorMsg), ToolResult = _{error: ErrorMsg})) ->
        % Log summary of result
        log_tool_result(ToolName, ToolResult),
        (   get_dict(error, ToolResult, Error) ->
            Response = _{
                jsonrpc: "2.0",
                id: ID,
                result: _{
                    content: [_{type: "text", text: Error}],
                    isError: true
                }
            }
        ;   with_output_to(string(TextResult), json_write_dict(current_output, ToolResult, [width(0)])),
            Response = _{
                jsonrpc: "2.0",
                id: ID,
                result: _{
                    content: [_{type: "text", text: TextResult}]
                }
            }
        )
    ;   Response = _{
            jsonrpc: "2.0",
            id: ID,
            error: _{code: -32603, message: "Internal error during tool execution"}
        }
    ).

handle_method(Method, _Dict, _Response) :-
    match_method(initialized, Method), !, fail. % Notification, no response

% --- REST Handlers for ChatGPT Actions ---

handle_rest_list_examples(Request) :-
    rest_tool(Request, "list_examples", _{}).

handle_rest_query(Request) :-
    http_read_json_dict(Request, Args),
    rest_tool(Request, "query", Args).

handle_rest_verify(Request) :-
    http_read_json_dict(Request, Args),
    rest_tool(Request, "verify", Args).

handle_rest_example_details(Request) :-
    http_read_json_dict(Request, Args),
    rest_tool(Request, "get_example_details", Args).

%   The same limits as /mcp. A refusal is HTTP status 429 (too many calls)
%   or 413 (a text too long), with Retry-After when waiting helps.
rest_tool(Request, Tool, Args) :-
    throttle_identity(Request, Identity),
    identity_entitlements(Identity),
    retractall(mcp_identity(_)), assertz(mcp_identity(Identity)),
    (   admit_tool(Identity, Tool, Args, refuse(Status, Wait, Message))
    ->  ( Wait > 0 -> format('Retry-After: ~w~n', [Wait]) ; true ),
        reply_json_dict(_{error: Message}, [status(Status)])
    ;   throttle_run(Identity, ( call_tool(Tool, Args, Result), reply_json_dict(Result) ), Outcome),
        (   Outcome == done -> true
        ;   Outcome = busy(M) -> format('Retry-After: 10~n'), reply_json_dict(_{error: M}, [status(503)])
        ;   Outcome = timeout(M) -> reply_json_dict(_{error: M}, [status(504)])
        ;   reply_json_dict(_{error: "Internal error during tool execution"}, [status(500)])
        )
    ).

% --- Tool Implementations ---

examples_dir(AbsDir) :-
    working_directory(CWD, CWD),
    % Remove trailing slash from CWD if present
    ( sub_atom(CWD, _, 1, 0, '/') -> sub_atom(CWD, 0, _, 1, CWD0) ; CWD0 = CWD ),
    le_examples_dir(ExDir),
    format(atom(AbsDir), "~w/~w/", [CWD0, ExDir]).

call_tool("list_examples", Args, Result) :-
    examples_dir(Dir),
    get_time(T0), list_summary_budget(B), Deadline is T0 + B,
    b_setval(mcp_list_deadline, Deadline),
    list_examples_with_summaries(Dir, '', Main),
    % The other example trees, under the names get_example_details resolves
    % (le_kbs:le_example_relpath/2): 'regulatory/x', 'migration/blawx/..', 'pt/x'.
    findall(Es,
            ( (   le_kbs:le_extra_examples_dir(Root, TreeDir)
              ;   le_kbs:language_examples_dir(Root, TreeDir)
              ),
              exists_directory(TreeDir),
              absolute_file_name(TreeDir, AbsTree, [file_type(directory)]),
              atomic_list_concat([AbsTree, '/'], TreeSlash),
              atomic_list_concat([Root, '/'], TreePrefix),
              list_examples_with_summaries(TreeSlash, TreePrefix, Es) ),
            Others),
    append([Main|Others], Examples0),
    (   get_dict(filter, Args, Filter), Filter \== "", Filter \== null
    ->  split_string(Filter, " ,", " ,", Words0), exclude(==(""), Words0, Words),
        include(example_matches(Words), Examples0, Examples)
    ;   Examples = Examples0
    ),
    Result = _{examples: Examples}.

call_tool("get_example_details", Args, Result) :-
    get_dict(example_name, Args, ExampleName),
    % le_example_relpath also resolves per-language names ('pt/cidadania' ->
    % examples/pt/cidadania); relative paths are fine, the server runs from
    % the repo root. A restricted example (restricted_paths.pl) is not read for
    % an MCP/REST client, which has no session and so no roles.
    mcp_roles(Roles),
    catch(( le_tools:example_path_for(ExampleName, Roles, Path) -> Outcome = path(Path) ; Outcome = missing ),
          error(permission_error(access, example, _), _),
          Outcome = restricted),
    (   Outcome = path(P)
    ->  example_details(P, Args, Result)
    ;   Outcome == restricted
    ->  format(string(Msg), "Example '~w' requires login", [ExampleName]),
        Result = _{error: Msg}
    ;   le_tools:unknown_example_message(ExampleName, Msg),
        Result = _{error: Msg}
    ).

call_tool("query", Args, Result) :-
    mcp_roles(Roles),
    le_tools:le_tool_query(Args, Roles, Result0),
    cap_answers(Result0, Result).

call_tool("verify", Args, Result) :-
    le_tools:le_tool_verify(Args, Result).

call_tool("search_documentation", Args, _{sections: Text}) :-
    ( get_dict(query, Args, Q) -> true ; Q = "" ),
    module_property(mcp, file(F)), file_directory_name(F, LLMDir), file_directory_name(LLMDir, Root0),
    directory_file_path(Root0, 'docs/user', Root),
    le_docs_search:docs_search_answer(Root, Q, [], Text).

%   Reached when a tool's own clause failed, as well as for a name that is
%   no tool: only the second is an unknown tool.
call_tool(ToolName, _Args, Result) :-
    mcp_tool_name(ToolName),
    !,
    format(user_error, "MCP Error: tool ~w failed~n", [ToolName]),
    format(string(Msg), "The tool ~w could not answer with these arguments.", [ToolName]),
    Result = _{error: Msg}.
call_tool(ToolName, _Args, Result) :-
    format(user_error, "MCP Error: Unknown tool called: ~w~n", [ToolName]),
    format(string(Msg), "Unknown tool: ~w. Available tools are: list_examples, get_example_details, query, verify, search_documentation.", [ToolName]),
    Result = _{error: Msg}.

%   A remote client gets at most the first 50 answers of a query, with a note
%   that says how many there were.
cap_answers(R0, R) :-
    (   mcp_identity(Identity), \+ get_dict(level, Identity, local),
        get_dict(results, R0, Rs), length(Rs, N), N > 50
    ->  length(First, 50), append(First, _, Rs),
        le_msg(throttle_answers_cut, [shown-50, count-N], Note0), atom_string(Note0, Note),
        ( get_dict(notes, R0, Ns) -> true ; Ns = [] ),
        append(Ns, [Note], Ns1),
        R = R0.put(_{results: First, notes: Ns1})
    ;   R = R0
    ).

mcp_tool_name(Name) :-
    atom_string(Tool, Name),
    memberchk(Tool, [list_examples, get_example_details, query, verify, search_documentation]).

%   Read the metadata under a module reference (and retry if the module was
%   reclaimed between load and reference) — same race as the listing above.
%   The goal is explicitly mcp-qualified: relying on compile-time
%   meta-argument qualification across the explicit le_kbs: call proved
%   fragile (the goal ran in the wrong module and the catch masked it).
example_details(Path, Args, Result) :-
    between(1, 3, _),
    le_kbs:load(Path, KB),
    catch(le_kbs:with_kb_reference(KB, mcp:example_details_result(KB, Result0)), _, fail),
    !,
    read_file_to_string(Path, Text, [encoding(utf8)]),
    string_length(Text, Length),
    %  A long text is left out unless asked for: a client caps what one tool
    %  call may return (Claude Code at about 25000 tokens), and a reply that
    %  holds the text of the British Nationality Act (100000 characters) was
    %  refused whole, templates included, so the model never saw the sentences
    %  it must use.
    (   ( get_dict(include_program_text, Args, true) ; Length =< 30000 )
    ->  Result = Result0.put(program_text, Text)
    ;   format(string(Note), "The program's text (~D characters) is left out: it is longer than many clients accept from one tool call. The templates and queries above are enough to query the program; write facts with the templates, and dates as 2026-03-01. Only if you must read the rules, ask again with include_program_text: true.", [Length]),
        Result = Result0.put(_{program_text_omitted: Length, note: Note})
    ).

%   An example whose name or summary contains every word (any case).
example_matches(Words, Example) :-
    get_dict(name, Example, N), get_dict(summary, Example, S),
    format(string(Hay0), "~w ~w", [N, S]), string_lower(Hay0, Hay),
    forall(member(W0, Words), ( string_lower(W0, W), sub_string(Hay, _, _, _, W) )).

example_details_result(KB, Result) :-
    le_kbs:get_kb_metadata(KB, Metadata),
    ( current_predicate(KB:scenario/2) -> findall(_{name: Name}, KB:scenario(Name, _), Scenarios); Scenarios = []),
    Result = Metadata.put(_{scenarios: Scenarios}).

%   Seconds a listing may spend loading programs for their summaries. A
%   summary is cached per file (le_kbs:kb_summary_safe/3), but the first
%   listing of a large tree would load every program in it — minutes, with
%   the example corpus of the InsurLE repository mounted — so past the budget
%   a program not yet summarised is described by its opening comment.
list_summary_budget(20).

example_summary(Path, Summary) :-
    (   nb_current(mcp_list_deadline, Deadline) -> true ; get_time(Deadline) ),
    le_kbs:example_summary(Path, Deadline, Summary).

%!  list_examples_with_summaries(+Dir:atom, +Prefix:atom, -Examples:list) is det.
%
%   Collects example dicts (name, summary) from Dir and its subdirectories.
%   Subdirectory examples have names of the form "subdir/name".
%   An MCP/REST client has no session and so no roles: like the editor's own
%   listing (le_api:list_examples_in_dir/4), the listing leaves out
%   the role-gated trees (restricted_paths.pl) — which also spares it loading
%   every program of them for a summary.
list_examples_with_summaries(Dir, Prefix, Examples) :-
    directory_files(Dir, Files),
    findall(_{name: ExPath, summary: Summary}, (
        member(F, Files),
        sub_atom(F, _, _, 0, '.le'),
        \+ sub_atom(F, _, _, 0, '.le.tests'),
        file_name_extension(Base, le, F),
        atom_concat(Prefix, Base, ExPath),
        directory_file_path(Dir, F, Path),
        mcp_roles(Roles), restricted_paths:is_path_allowed(Path, Roles),
        \+ library_copy_in(Dir, Base),
        example_summary(Path, Summary)
    ), DirectExamples),
    findall(SubExamples, (
        member(F, Files),
        \+ sub_atom(F, 0, 1, _, '.'),
        \+ memberchk(F, [sources, node_modules]),   % a twin's originals, not programs
        directory_file_path(Dir, F, SubDir),
        exists_directory(SubDir),
        mcp_roles(Roles), restricted_paths:is_path_allowed(SubDir, Roles),
        atomic_list_concat([Prefix, F, '/'], SubPrefix),
        list_examples_with_summaries(SubDir, SubPrefix, SubExamples)
    ), SubExamplesLists),
    append(SubExamplesLists, SubExamplesFlat),
    append(DirectExamples, SubExamplesFlat, Examples).

%   A copy of a lib/ library beside the programs that include it
%   (le_api:library_copy/2), when the web API is loaded.
library_copy_in(Dir, Base) :-
    ( sub_atom(Dir, _, 1, 0, '/') -> D = Dir ; atom_concat(Dir, '/', D) ),
    catch(le_api:library_copy(D, Base), _, fail).

% --- MCP Helpers ---

is_query_or_verify(Tool) :-
    member(Tool.name, ["query", "verify", "search_documentation"]).

log_tool_result("verify", Result) :- !,
    Issues = Result.get(issues, []),
    Tests = Result.get(test_results, []),
    length(Issues, NI),
    length(Tests, NT),
    include(mcp:is_error, Issues, Errors),
    length(Errors, NE),
    include(mcp:is_fail, Tests, Fails),
    length(Fails, NF),
    format(user_error, "MCP Result: verify -> ~w issues (~w errors), ~w tests (~w failed)~n", [NI, NE, NT, NF]).
log_tool_result("query", Result) :- !,
    (   get_dict(results, Result, Answers)
    ->  length(Answers, N),
        format(user_error, "MCP Result: query -> ~w answers~n", [N])
    ;   get_dict(error, Result, Msg)
    ->  format(user_error, "MCP Result: query -> Error: ~w~n", [Msg])
    ;   format(user_error, "MCP Result: query -> No answers~n", [])
    ).
log_tool_result(Tool, _) :-
    format(user_error, "MCP Result: ~w completed~n", [Tool]).

is_error(Issue) :- Issue.get(severity) == "error".
is_fail(Test) :- Test.get(status) == "fail".

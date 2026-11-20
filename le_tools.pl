/** <module> Logical English Shared Tools
    
    This module provides shared, in-process implementations of the 'verify'
    and 'query' tools for Logical English. These are used by both the MCP server
    and the Light Assistant.
*/

:- module(le_tools, [
    le_tool_verify/2,
    le_tool_query/2,
    le_tool_read_facts/2,
    le_tool_query/3,
    example_path_for/3,
    convert_test_result/2,
    convert_why/3,
    run_query/4,
    get_last_verified_program/3,
    set_verify_job/1,
    clear_verify_job/0
]).

:- use_module(le_kbs).
:- use_module(tokenizer).
:- use_module(le_grammar).
:- use_module(reasoner).
:- use_module(le_system_templates).
:- use_module(restricted_paths, [is_path_allowed/2]).
:- use_module(le_background, []).

%!  le_tool_verify(+ProgramTextOrArgs, -Result) is det.
%
%   Parses and verifies a Logical English program, returning all issues found
%   and running any embedded tests. Args may give `program_base`: where the
%   program is (a folder or a URL), against which its included resources
%   resolve (le_kbs:load_text/3); without it they resolve against the
%   server's folder, and a twin's `includes temporal` is not found.
%!  le_tool_read_facts(+Args, -Result) is det.
%
%   The facts background step (le_background.pl, language.md §14.5) for an
%   assistant: Args has `program_text`, maybe `program_base`, and `facts`
%   (the facts the assistant noted from a text, one a line: sentences of the
%   program's scenario templates or of the background's noted templates).
%   Result: the noted templates the background offers, and, when facts are
%   given, what the step returns (lines to put in a scenario, derived facts
%   with their origin, unused noted facts, notes and questions).
le_tool_read_facts(Args, Result) :-
    get_dict(program_text, Args, ProgramText),
    ( get_dict(program_base, Args, Base) -> true ; Base = (-) ),
    le_kbs:load_text(ProgramText, Base, KB),
    le_background:background_templates(KB, Noted0, _),
    findall(L, member(n(L, _, _), Noted0), Noted),
    (   get_dict(facts, Args, Facts), Facts \== "", Facts \== null
    ->  ( is_list(Facts) -> Lines = Facts
        ; split_string(Facts, "\n", " \t\r", Ls0), exclude(==(""), Ls0, Lines) ),
        le_background:apply_background(KB, Lines, R),
        Result = R.put(noted_templates, Noted)
    ;   Result = _{noted_templates: Noted}
    ).

le_tool_verify(Args, Result) :-
    is_dict(Args), !,
    get_dict(program_text, Args, ProgramText),
    ( get_dict(program_base, Args, Base) -> true ; Base = (-) ),
    le_tool_verify_(ProgramText, Base, Result).
le_tool_verify(ProgramText, Result) :-
    le_tool_verify_(ProgramText, (-), Result).

le_tool_verify_(ProgramText, Base, Result) :-
    le_kbs:load_text(ProgramText, Base, KB),
    findall(_{severity: Sev, type: Type, message: Msg, fix: Fix, start: Start, end: End},
            KB:le_issue(Sev, Type, Msg, Fix, Start, End),
            Issues),
    % Run the embedded tests (`expects answers ...`, le_expected/4, and
    % `expects changes ...`, le_expected_changes/3), as runTestsFor/2 does.
    ( current_predicate(KB:le_expected/4)
    ->  findall(test(Q, S, A, U), KB:le_expected(Q, S, A, U), Tests0)
    ;   Tests0 = []
    ),
    ( current_predicate(KB:le_expected_changes/3)
    ->  findall(test_changes(Q, S, Sets), KB:le_expected_changes(Q, S, Sets), Tests1)
    ;   Tests1 = []
    ),
    append(Tests0, Tests1, Tests),
    maplist(le_kbs:run_one_test(KB), Tests, TestResults),
    maplist(convert_test_result, TestResults, JSONTestResults),
    % Capture this program so the LE Assistant can recover the agent's work
    % even if its file edits failed or the job was interrupted (see le_assistant).
    record_verified_program(ProgramText),
    verify_summary(KB, ProgramText, TestResults, Summary, AmountIssues),
    append(Issues, AmountIssues, AllIssues),
    Result = _{issues: AllIssues, test_results: JSONTestResults, summary: Summary}.

%!  verify_summary(+KB, +Text, +TestResults, -Summary, -Issues) is det.
%
%   What a client needs to see at a glance after a verification: the size of
%   the text checked (a client that retypes a program can check a shorter
%   copy than its file), the tests passed and failed, and the queries that
%   answer in no scenario. Each query also runs in each scenario (within
%   flag le_verify_answers_seconds, default 10, 2 seconds a run), and an
%   amount of money with two different values for the same thing is reported
%   (several_amounts): two rules that both apply, often through a template
%   typed wrong in one of them. Only arguments whose type is a word of the
%   class money_type (amount, price, fee, ...) count: a query may rightly
%   give several numbers, and a thing may rightly have several amounts in
%   different roles, so the other arguments must be the same.
:- create_prolog_flag(le_verify_answers_seconds, 10, [type(integer), keep(true)]).

verify_summary(KB, Text, TestResults, Summary, Issues) :-
    split_string(Text, "\n", "", Ls), length(Ls, Lines),
    ( current_predicate(KB:scenario/2) -> findall(S, KB:scenario(S, _), Ss) ; Ss = [] ),
    length(Ss, NS),
    ( current_predicate(KB:query_info/3) -> findall(Q, KB:query_info(Q, _, _), Qs0), sort(Qs0, Qs) ; Qs = [] ),
    length(Qs, NQ),
    length(TestResults, NT),
    aggregate_all(count, member(pass(_, _), TestResults), NP),
    NF is NT - NP,
    current_prolog_flag(le_verify_answers_seconds, Budget),
    get_time(T0), Deadline is T0 + Budget,
    findall(Q-S-R,
            ( member(Q, Qs), member(S, Ss),
              get_time(Now), Now < Deadline,
              verify_query_run(KB, Q, S, R) ),
            Runs),
    length(Runs, Checked),
    findall(Q, ( member(Q, Qs), memberchk(Q-_-_, Runs), \+ memberchk(Q-_-answers(_), Runs) ), Unanswered),
    aggregated_functors(KB, Aggregated),
    %  one warning for each query: the first scenario where it happens
    %  a test of the query that passes in the scenario vouches for its answers
    findall(Q-I, ( member(Q-S-answers(Sols), Runs),
                   \+ ( member(pass(QP, SP), TestResults), QP == Q, SP == S ),
                   several_amounts(KB, Aggregated, Q, S, Sols, I) ), QIs),
    findall(I, ( member(Q, Qs), memberchk(Q-I, QIs) ), Issues),
    maplist([X, Y]>>term_string(X, Y), Unanswered, UnansweredS),
    le_i18n:le_msg(verify_summary_note, [lines-Lines, scenarios-NS, tests-NT, passed-NP, failed-NF], Note),
    Summary = _{lines: Lines, scenarios: NS, queries: NQ, tests: NT, tests_passed: NP, tests_failed: NF,
                queries_without_answers: UnansweredS, query_runs_checked: Checked, note: Note}.

% One query in one scenario: answers(Solutions) (each the query's items,
% bound), none, or error (an error or the time limit).
verify_query_run(KB, Q, S, R) :-
    KB:query_info(Q, FullGoal, Items),
    le_kbs:createSession(KB, SM),
    current_prolog_flag(le_failure_explanations, FE),
    setup_call_cleanup(
        set_prolog_flag(le_failure_explanations, false),
        catch(( le_kbs:setScenarion(SM, S),
                call_with_time_limit(2,
                    findall(Items, reasoner:without_explanations(reasoner:i(FullGoal, SM, _, _)), Sols0)) ),
              _, Sols0 = error),
        ( set_prolog_flag(le_failure_explanations, FE), le_kbs:destroySession(SM) )),
    (   Sols0 == error -> R = error
    ;   Sols0 == [] -> R = none
    ;   R = answers(Sols0)
    ), !.
verify_query_run(_, _, _, error).

several_amounts(KB, Aggregated, Q, S, Sols, Issue) :-
    Sols = [Items0|_],
    nth1(K, Items0, query_clause(G0, _, _, Start, End)),
    G0 =.. [F|Args0], length(Args0, A),
    \+ memberchk(F/A, Aggregated),
    money_positions(KB, F, A, MPs), MPs \== [],
    findall(Key-Money-Items,
            ( member(Items, Sols), nth1(K, Items, query_clause(G, _, _, _, _)),
              G =.. [_|Args],
              money_split(Args, 1, MPs, Key, Money),
              ground(Key), Money \== [], maplist(number, Money) ),
            Triples),
    msort(Triples, Sorted),
    group_by_key(Sorted, Groups),
    member(Key-Group, Groups),
    findall(M, member(M-_, Group), Ms0), sort(Ms0, Ms),
    length(Ms, N), N >= 2, !,
    findall(Str, ( member(M, Ms), memberchk(M-Items, Group), nth1(K, Items, Clause),
                   le_kbs:item_to_instance(KB, Clause, Inst), flatten(Inst, Flat),
                   le_kbs:canonical_string(Flat, At), atom_string(At, Str0),
                   format(string(Str), "'~w'", [Str0]) ),
           Strs0),
    length(Strs0, NStrs), ( NStrs > 4 -> length(Strs, 4), append(Strs, _, Strs0) ; Strs = Strs0 ),
    atomic_list_concat(Strs, ', ', Examples),
    le_i18n:le_msg(several_amounts_desc, [scenario-S, query-Q, count-N, examples-Examples], Msg),
    le_i18n:le_msg(several_amounts_fix, [], Fix),
    Issue = _{severity: warning, type: several_amounts, message: Msg, fix: Fix, start: Start, end: End}.

% The templates that an aggregate of the program reads (`the max of each
% amount A such that we will pay A ...`): the author expects them to have
% several amounts for one thing, and chooses among them.
aggregated_functors(KB, Fs) :-
    findall(F/A,
            ( current_predicate(KB:P/N), functor(H, P, N),
              \+ predicate_property(KB:H, imported_from(_)),
              catch(clause(KB:H, B), _, fail),
              sub_term(T, B), compound(T), T =.. [Op, _, G, _],
              memberchk(Op, [max, min, sum, count, list, average]),
              sub_term(L, G), compound(L), \+ L = le_at(_, _, _), functor(L, F, A) ),
            Fs0),
    sort(Fs0, Fs).

group_by_key([], []).
group_by_key([K-M-I|T], [K-[M-I|Ms]|Gs]) :-
    take_key(T, K, Ms, Rest),
    group_by_key(Rest, Gs).
take_key([K1-M-I|T], K, [M-I|Ms], Rest) :- K1 == K, !, take_key(T, K, Ms, Rest).
take_key(Rest, _, [], Rest).

money_split([], _, _, [], []).
money_split([X|Xs], P, MPs, Key, Money) :-
    P1 is P + 1,
    (   memberchk(P, MPs) -> Money = [X|Money1], Key = Key1
    ;   Key = [X|Key1], Money = Money1
    ),
    money_split(Xs, P1, MPs, Key1, Money1).

% The positions of a template's arguments whose type is money (the last word
% of the type is in the class money_type).
money_positions(KB, F, A, MPs) :-
    current_predicate(KB:le_dict/1),
    KB:le_dict(D), D =.. [dict, [F|DArgs], VTs|_], length(DArgs, A), !,
    findall(P, ( nth1(P, DArgs, V), member(V1-T, VTs), V1 == V, money_type(T) ), MPs).
money_positions(_, _, _, []).

money_type(T) :-
    atom(T),
    split_string(T, " _", "", Ws), last(Ws, W0), atom_string(W, W0),
    le_i18n:class_member(money_type, W).

% --- Capture of the most recent program submitted to the verify tool ---
% The verify tool runs in-process (same server as the LE Assistant), so the
% full program_text the agent verifies is available here. We keep a small,
% time-stamped history so the assistant can deliver the agent's latest verified
% program to the editor even when its surgical file edits never landed.
%
% Captures are keyed by a per-job token so that concurrent assistant jobs (or
% other MCP clients) cannot recover each other's work. The token is supplied by
% the MCP HTTP handler (via set_verify_job/1) for the duration of a tool call;
% callers without a token (REST endpoints, light assistant) record under 'none'.

:- dynamic last_verified_program/3.   % Token, Timestamp, ProgramText
:- thread_local verify_context_job/1.

%!  set_verify_job(+Token) is det.
%   Establishes the job token attributed to verify captures on this thread.
set_verify_job(Token) :-
    retractall(verify_context_job(_)),
    ( Token == none -> true ; assertz(verify_context_job(Token)) ).

%!  clear_verify_job is det.
clear_verify_job :-
    retractall(verify_context_job(_)).

current_verify_job(Token) :-
    ( verify_context_job(T) -> Token = T ; Token = none ).

record_verified_program(ProgramText) :-
    ( (var(ProgramText) ; \+ (string(ProgramText) ; atom(ProgramText)) ; ProgramText == "") ->
        true
    ;   current_verify_job(Token),
        get_time(Now),
        assertz(last_verified_program(Token, Now, ProgramText)),
        % Bound the history to the 50 most recent entries (across all tokens).
        findall(T, last_verified_program(_, T, _), Times),
        sort(0, @>=, Times, Sorted),
        ( nth0(50, Sorted, Cutoff) ->
            forall((last_verified_program(Tk, T2, P2), T2 =< Cutoff),
                   retract(last_verified_program(Tk, T2, P2)))
        ; true
        )
    ).

%!  get_last_verified_program(+Token, +AfterTime, -ProgramText) is semidet.
%
%   Unifies ProgramText with the most recent program submitted to the verify
%   tool under the given job Token at or after AfterTime (an epoch timestamp).
%   Fails if none exists for that token.
get_last_verified_program(Token0, AfterTime, ProgramText) :-
    % Keys are stored as atoms; normalize so a string JobID also matches.
    ( atom(Token0) -> Token = Token0 ; atom_string(Token, Token0) ),
    findall(T-P, (last_verified_program(Token, T, P), T >= AfterTime), Pairs),
    Pairs \== [],
    keysort(Pairs, Sorted),
    last(Sorted, _-ProgramText).

%!  le_tool_query(+Args, -Result) is det.
%!  le_tool_query(+Args, +UserRoles:list, -Result) is det.
%
%   Executes a query against a Logical English program or example. An example
%   is read only if UserRoles may read it (le_tool_query/2: no roles, as for
%   an anonymous client). The scenario is `scenario_name` (the MCP tool's
%   field) or `scenario` (the light assistant's action). A `program_text`
%   resolves its included resources against `program_base`, as for
%   le_tool_verify/2.
le_tool_query(Args, Result) :-
    le_tool_query(Args, [], Result).
le_tool_query(Args, UserRoles, Result) :-
    catch(le_tool_query_(Args, UserRoles, Result),
          error(permission_error(access, example, Name), _),
          ( format(string(Msg), "Example '~w' requires login", [Name]),
            Result = _{error: Msg} )),
    !.
le_tool_query(Args, _UserRoles, Result) :-
    get_dict(example_name, Args, ExampleName),
    ExampleName \== "",
    \+ catch(example_path_for(ExampleName, [], _), _, true),
    !,
    unknown_example_message(ExampleName, Msg),
    Result = _{error: Msg}.
le_tool_query(Args, _UserRoles, _{error: Msg}) :-
    ( get_dict(query, Args, Query) -> true ; Query = "" ),
    format(string(Msg), "The query '~w' could not be run on this program", [Query]).

%   The message for an example name that names no example: with the name
%   meant, when the name is the example's folder (examples in folders of
%   their own are named folder/program, as in migration/blawx/rps/rps).
unknown_example_message(ExampleName, Msg) :-
    (   file_base_name(ExampleName, Base),
        atomic_list_concat([ExampleName, '/', Base], Suggestion),
        catch(example_path_for(Suggestion, [], _), _, fail)
    ->  format(string(Msg), "Example '~w' not found; did you mean '~w'?", [ExampleName, Suggestion])
    ;   %  a name given without its tree ('bna' for 'regulatory/bna')
        \+ sub_atom(ExampleName, _, _, _, '/'),
        le_kbs:le_extra_examples_dir(Root, _),
        (   atomic_list_concat([Root, '/', ExampleName], Suggestion)
        ;   atomic_list_concat([Root, '/', ExampleName, '/', ExampleName], Suggestion)
        ),
        catch(example_path_for(Suggestion, [], _), _, fail)
    ->  format(string(Msg), "Example '~w' not found; did you mean '~w'?", [ExampleName, Suggestion])
    ;   format(string(Msg), "Example '~w' not found; list_examples gives the names of the examples", [ExampleName])
    ).

le_tool_query_(Args, UserRoles, Result) :-
    get_dict(query, Args, Query),
    ( get_dict(example_name, Args, ExampleName) -> true ; ExampleName = "" ),
    ( get_dict(program_text, Args, ProgramText) -> true ; ProgramText = "" ),
    (   get_dict(scenario_name, Args, ScenarioName) -> true
    ;   get_dict(scenario, Args, ScenarioName) -> true
    ;   ScenarioName = ""
    ),
    ( get_dict(facts, Args, Facts) -> true ; Facts = "" ),
    (   ExampleName \== "" ->
        % le_example_relpath also resolves per-language names ('pt/cidadania'
        % -> examples/pt/cidadania); relative paths are fine, the server runs
        % from the repo root.
        example_path_for(ExampleName, UserRoles, Path),
        le_kbs:load(Path, KB)
    ;   ProgramText \== "" ->
        ( get_dict(program_base, Args, Base) -> true ; Base = (-) ),
        le_kbs:load_text(ProgramText, Base, KB)
    ;   KB = none
    ),
    le_kbs:createSession(KB, SM),
    % Single-use session: always free it when done.
    setup_call_cleanup(
        true,
        (   (   (ScenarioName \== "", ScenarioName \== null) ->
                ( atom_string(ScenarioAtom, ScenarioName), le_kbs:setScenarion(SM, ScenarioAtom) -> true ; true )
            ;   true
            ),
            (   (Facts \== "", Facts \== null) ->
                catch(le_kbs:parse_custom_facts(KB, Facts, FactTerms), error(le_parse_error(Msg), _), ErrorFacts = Msg),
                ( var(ErrorFacts) -> forall(member(F, FactTerms), le_kbs:addSessionFact(SM, F)) ; true )
            ;   true
            ),
            (   nonvar(ErrorFacts) -> Result = _{error: ErrorFacts}
            ;   catch(run_query(SM, Query, KB, Result0), error(le_parse_error(Msg), _), Result0 = _{error: Msg}),
                fact_notes(KB, Facts, Notes0),
                word_date_notes(Query, QueryNotes),
                append(Notes0, QueryNotes, Notes),
                ( Notes == [] -> Result = Result0 ; Result = Result0.put(notes, Notes) )
            )
        ),
        le_kbs:destroySession(SM)
    ).

run_query(SM, QueryStr, KB, Result) :-
    findall(Answer, (
        le_kbs:query(SM, QueryStr, Instance, _, Why),
        le_kbs:canonical_string(Instance, AnswerStr),
        convert_why(Why, KB, JSONWhy),
        Answer0 = _{answer: AnswerStr, explanation: JSONWhy},
        (   answer_case(KB, Why, Case) ->  Answer = Answer0.put(case, Case)
        ;   Answer = Answer0
        )
    ), Results),
    (   Results \== [] ->
        Result = _{results: Results}
    ;   % Try to get negative explanation
        (   le_kbs:query_explain(SM, QueryStr, _, _, Why) ->
            convert_why(Why, KB, JSONWhy),
            Result = _{results: [], explanation: JSONWhy}
        ;   Result = _{results: [], error: "No answer and no explanation found"}
        )
    ).

%   Notes on the facts a caller gave: each fact with a variable in it. A
%   language model writing facts from a case often writes "claim 1 is for a
%   quad cane", which is about every quad cane, where the case named one;
%   the answer then fails for a reason the explanation does not name.
fact_notes(KB, Facts, Notes) :-
    (   ( Facts == "" ; Facts == null ; KB == none )
    ->  Notes = []
    ;   split_string(Facts, "\n", " \t\r", Lines),
        %   read before parsing: a sentence that matches no template is
        %   given a template of its own as it is parsed
        findall(F/A, ( catch(KB:le_dict(dict([F|Args], _, _, _, _, _, _)), _, fail), length(Args, A) ), Declared0),
        sort(Declared0, Declared),
        findall(Note,
                ( member(Line, Lines), Line \== "",
                  catch(le_kbs:parse_custom_facts(KB, Line, Terms), _, fail),
                  exclude([T]>>( T = le_provenance(_, _, _, _, _) ), Terms, Facts1),
                  fact_note_key(KB, Declared, Facts1, Key),
                  ( string_concat(Fact, ".", Line) -> true ; Fact = Line ),
                  le_i18n:le_msg(Key, [fact-Fact], Note0),
                  atom_string(Note0, Note) ),
                Notes1),
        word_date_notes(Facts, Notes2),
        append(Notes1, Notes2, Notes)
    ).

%!  word_date_notes(+Text, -Notes:list) is det.
%
%   A note for each date written in words ("3 March 1986", "the 1st of
%   January 1990", "March 3, 1986"): Logical English reads a date only as
%   2026-03-03, and a date in words is read as a name, silently, so a rule
%   that compares dates never applies. Language models often write them so.
word_date_notes(Text, Notes) :-
    (   ( Text == "" ; Text == null ; \+ string(Text), \+ atom(Text) )
    ->  Notes = []
    ;   split_string(Text, " \n\t", " \t\r.,;", Words0),
        exclude(==(""), Words0, Words),
        findall(Note,
                ( word_date(Words, Shown, Iso),
                  le_i18n:le_msg(tool_word_date, [date-Shown, iso-Iso], Note0),
                  atom_string(Note0, Note) ),
                Notes0),
        list_to_set(Notes0, Notes)
    ).

word_date(Words, Shown, Iso) :-
    append(_, Rest, Words),
    word_date_at(Rest, Used, D, M, Y),
    atomic_list_concat(Used, ' ', ShownA), atom_string(ShownA, Shown),
    format(string(Iso), "~d-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, D]).

word_date_at([D0, M0, Y0|_], [D0, M0, Y0], D, M, Y) :- day(D0, D), month(M0, M), year(Y0, Y).
word_date_at([D0, Of, M0, Y0|_], [D0, Of, M0, Y0], D, M, Y) :- string_lower(Of, "of"), day(D0, D), month(M0, M), year(Y0, Y).
word_date_at([M0, D0, Y0|_], [M0, D0, Y0], D, M, Y) :- month(M0, M), day(D0, D), year(Y0, Y).

day(S, D) :-
    (   member(Suffix, ["st", "nd", "rd", "th"]), string_concat(N, Suffix, S) -> true ; N = S ),
    catch(number_string(D, N), _, fail), integer(D), D >= 1, D =< 31.
year(S, Y) :- string_length(S, 4), catch(number_string(Y, S), _, fail), integer(Y).
month(S, M) :-
    string_lower(S, L),
    nth1(M, ["january", "february", "march", "april", "may", "june", "july",
             "august", "september", "october", "november", "december"], L).

%   What is worth saying about the terms one line of facts gave: a variable
%   in a fact, or a fact no template of the program declares (a sentence
%   that matched none becomes a relation of its own, which no rule reads).
fact_note_key(_, _, Terms, tool_fact_has_variable) :-
    member(T, Terms), \+ ground(T), !.
fact_note_key(KB, Declared, Terms, tool_fact_no_template) :-
    member(T, Terms), callable(T), T \= (_ :- _),
    (   T = is_a(_, Kind)
    ->  \+ known_kind(KB, Kind)
    ;   functor(T, F, A), \+ declared_relation(Declared, F, A)
    ), !.

%   A kind the program speaks of: a type of a template's place, or a kind of
%   its ontology.
known_kind(KB, Kind) :-
    (   catch(KB:le_dict(dict(_, NTs, _, _, _, _, _)), _, fail), memberchk(_-Kind, NTs)
    ;   catch(KB:is_a(Kind, _), _, fail)
    ;   catch(KB:is_a(_, Kind), _, fail)
    ), !.

declared_relation(Declared, F, A) :-
    memberchk(F/A, Declared), !.
declared_relation(_, F, A) :-
    catch(le_system_templates:le_system_template(dict([F|Args], _, _)), _, fail),
    length(Args, A), !.

%   An answer of a case search (le_cases.pl) also carries the case: its
%   conditions, the scenarios that cover it, and a ready-made scenario that
%   meets it (`scenario`), as the editor's answers do (le_api.pl).
answer_case(KB, Why, CaseJSON) :-
    sub_term(Node, Why), compound(Node), functor(Node, success, _),
    arg(1, Node, Head), compound(Head), Head = le_case(Case, _), nonvar(Case),
    catch(le_cases:case_json(KB, Case, CaseJSON), _, fail), !.

% --- Helpers ---

convert_why(success(_Goal, range(Start, End), LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "success", literal: LE, start: Start, end: End, children: JSONChildren}.
convert_why(success(_Goal, _Ref, LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "success", literal: LE, children: JSONChildren}.
convert_why(failure(_Goal, range(Start, End), LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "failure", literal: LE, start: Start, end: End, children: JSONChildren}.
convert_why(failure(_Goal, _Ref, LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "failure", literal: LE, children: JSONChildren}.
convert_why(Whys, KB, JSON) :-
    is_list(Whys), !,
    maplist(convert_why_child(KB), Whys, JSON).
convert_why(Other, _, JSON) :-
    term_string(Other, JSON).

convert_why_child(KB, Child, JSON) :-
    convert_why(Child, KB, JSON).

convert_test_result(pass(Q, S), _{status: "pass", query: Q, scenario: S}).
convert_test_result(fail(Q, S, E, A), _{status: "fail", query: Q, scenario: S, expected: EJ, actual: AJ}) :-
    json_value(E, EJ), json_value(A, AJ).
convert_test_result(fail(Q, S, E, A, EU, AU),
                    _{status: "fail", query: Q, scenario: S, expected: EJ, actual: AJ,
                      expected_unknowns: EUJ, actual_unknowns: AUJ}) :-
    maplist(json_value, [E, A, EU, AU], [EJ, AJ, EUJ, AUJ]).
convert_test_result(error(Q, S, Msg), _{status: "error", query: Q, scenario: S, message: MJ}) :-
    json_value(Msg, MJ).

%   A test's value as JSON can carry it: strings, numbers and lists of them
%   as they are, anything else as its text.
json_value(V, V) :- ( string(V) ; number(V) ; atom(V) ), !.
json_value(L, J) :- is_list(L), !, maplist(json_value, L, J).
json_value(T, S) :- format(string(S), '~w', [T]).

%!  example_path_for(+ExampleName, +UserRoles:list, -Path) is semidet.
%
%   The file of an example, when UserRoles may read it (restricted_paths.pl):
%   the tools answer an example by name, and a restricted one's name must not
%   be enough to read it. Fails for an unknown example; throws
%   error(permission_error(access, example, Name), _) for a restricted one.
example_path_for(ExampleName, UserRoles, Path) :-
    le_kbs:le_example_relpath(ExampleName, Path0),
    (exists_file(Path0) -> Path = Path0; atom_concat(Path0, '.le', Path), exists_file(Path)),
    (   restricted_paths:is_path_allowed(Path, UserRoles)
    ->  true
    ;   throw(error(permission_error(access, example, ExampleName), _))
    ).

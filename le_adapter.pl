/** <module> The adapter kit: answering another system's callers from a Logical English twin

    When an organisation moves its rules from another system to Logical
    English, the applications that call that system can keep working
    unchanged if our server answers them in the old system's own format.
    The part of our server that does this is an ADAPTER. Each adapter is a
    DIALECT (the addresses, requests and replies of one system: Oracle
    Intelligent Advisor, a DMN engine, ...) on top of this kit, which does
    what every adapter does:

      - it finds the DEPLOYMENTS: each a twin (a `.le` program) with a
        MAPPING FILE beside it, which says, for every name the callers use,
        which sentence of the twin says it;
      - it loads each twin once (and again when its file changes);
      - it answers a CASE (the values the caller sends, as JSON) by
        writing each value as the twin's own sentence, read by Logical
        English's own parser, into a fresh session, and by asking each
        wanted OUTCOME as a question of the twin; where the caller wants
        it, the answer's explanation comes back as a tree of sentences.

    The mapping format (docs/user/integrations/adapters.md) is the one the
    OIA translator first wrote, made general. A map is a JSON object:

        title, project            the deployment's title and main name
        deployments               its other names (any of them finds it)
        current_date_template     a sentence with one place, filled with
                                  today's date unless the case gives it, or
                                  null
        entities                  (OIA) the kinds of instance a case holds
        attributes                one per name the callers use

    and an attribute has a `name` (also `key`, `text`, `aliases`: other
    names the callers may use), a `type` (number, string, boolean, date,
    any, ...), whether it is `derived` (concluded by the twin's rules) or
    an input, and a `kind`:

        value       `template`/`display` with one place: `the age is *a number*`
        boolean     `display` a sentence with no place, true when the twin
                    proves it; `opposite` its negative form, or null
        evalue,     (OIA) a value, or a condition, of an entity's instance:
        ebool       the template's first place is the instance
        structure   `components`: a list of attributes, one per component
                    of the structure (a JSON object); as an outcome, null
                    when no component has a value, unless `null_when_empty`
                    is false (a DMN context: an object of nulls)
        list        `template` with one place, one sentence per element,
                    and `listed` (a sentence with no place: the list is
                    given, even if empty)
        records     a list of structures: `template` with one place per
                    component, `components` their names in order, `listed`

    Dialects register what they serve with one clause of adapter_dialect/3
    and call:

        adapter_deployment(+Dialect, +Name, -Map, -Twin)
        adapter_deployments(+Dialect, -Maps)
        adapter_decide(+Map, +Twin, +Case, +Outcomes, +Options, -Result)
        adapter_attribute(+Map, +PublicName, -Attribute)

    and the helpers for their routes: adapter_preflight/1,
    adapter_cors_headers/1, adapter_reply/3, adapter_access/3,
    adapter_open_access/1.

    The kit is part of the open engine (Apache-2.0); the dialects of
    commercial platforms live with the translators (lpsPlus), as the
    strategy report on adapters recommends.
*/

:- module(le_adapter, [
    adapter_deployment/4,       % +Dialect, +Name, -Map, -Twin
    adapter_deployments/2,      % +Dialect, -Maps
    adapter_reload/1,           % +Dialect
    adapter_decide/6,           % +Map, +Twin, +Case, +Outcomes, +Options, -Result
    adapter_twin_map/2,         % +Twin, -Map
    adapter_attribute/3,        % +Map, +PublicName, -Attribute
    adapter_outcome_attributes/3, % +Map, +Outcomes, -Attributes
    adapter_json_value/2,       % +LEValue, -JSON
    adapter_preflight/1,        % +Request
    adapter_cors_headers/1,     % +Request
    adapter_reply/3,            % +Request, +Status, +Dict
    adapter_access/3,           % +Request, +Dialect, -OK
    adapter_open_access/1,      % +Dialect
    adapter_twin_kb/2           % +Twin, -KB
  ]).

:- autoload(library(http/http_json), [reply_json_dict/2]).
:- use_module(library(json)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module(le_kbs).

%!  adapter_dialect(?Dialect, -Suffix, -Roots) is nondet.
%
%   A dialect's mapping files end in Suffix (`.oia_map.json`,
%   `.adapter_map.json`) and are found under the directories Roots, each
%   twin the `.le` file of the same base name beside its map. Multifile:
%   each dialect adds its clause.
:- multifile adapter_dialect/3.
:- dynamic adapter_dialect/3.

%!  access_hook(+Request, +Dialect, -OK) is semidet.
%
%   Who may call. The first hook that answers decides: OK is `ok` or
%   error(Status, Dict). Without a hook, a call is allowed when the
%   dialect's access is open (adapter_open_access/1) and otherwise refused
%   with 401.
:- multifile access_hook/3.

%!  open_access_variable(?Dialect, ?EnvironmentVariable) is nondet.
%   A dialect's own switch, besides ADAPTERS_OPEN and NO_RESTRICTIONS.
:- multifile open_access_variable/2.

:- dynamic deployment_/5.        % deployment_(Dialect, LowerName, Map, TwinFile, MapFile)
:- dynamic loaded_/1.            % loaded_(Dialect)
:- dynamic kb_cache/3.           % kb_cache(TwinFile, Time, KB)

		 /*******************************
		 *          DEPLOYMENTS         *
		 *******************************/

%!  adapter_deployments(+Dialect, -Maps) is det.
%   Every deployment's map, once each, ordered by project.
adapter_deployments(Dialect, Maps) :-
    ensure_loaded_dialect(Dialect),
    findall(MF-M, deployment_(Dialect, _, M, _, MF), Ps0),
    sort(1, @<, Ps0, Ps),
    pairs_values(Ps, Ms0),
    sort(project, @<, Ms0, Maps).

pairs_values([], []).
pairs_values([_-V|T], [V|Vs]) :- pairs_values(T, Vs).

%!  adapter_deployment(+Dialect, +Name, -Map, -Twin) is semidet.
%   The deployment of that name (any of its names, case ignored; spaces,
%   `-` and `_` alike); the maps are read again when the name is unknown.
adapter_deployment(Dialect, Name0, Map, Twin) :-
    name_key(Name0, Key),
    ensure_loaded_dialect(Dialect),
    (   deployment_(Dialect, Key, Map, Twin, _) -> true
    ;   adapter_reload(Dialect),
        deployment_(Dialect, Key, Map, Twin, _)
    ), !.

name_key(N0, K) :-
    (   atom(N0) -> A = N0 ; atom_string(A, N0) ),
    downcase_atom(A, L),
    atom_codes(L, Cs0),
    maplist([C0, C]>>( memberchk(C0, `-_ `) -> C = 0'_ ; C = C0 ), Cs0, Cs),
    atom_codes(K, Cs).

ensure_loaded_dialect(D) :-
    (   loaded_(D) -> true ; adapter_reload(D) ).

%!  adapter_reload(+Dialect) is det.
adapter_reload(D) :-
    with_mutex(le_adapter_load,
        (   retractall(deployment_(D, _, _, _, _)),
            retractall(loaded_(D)),
            forall(( adapter_dialect(D, Suffix, Roots),
                     member(Root, Roots), exists_directory(Root),
                     directory_member(Root, MF, [recursive(true), extensions([json])]),
                     \+ sub_atom(MF, _, _, _, '/sources/'),
                     sub_atom(MF, _, _, 0, Suffix) ),
                   (   catch(read_map(MF, Suffix, Map, Twin), _, fail)
                   ->  forall(map_name(Map, N0),
                              ( name_key(N0, K),
                                ( deployment_(D, K, _, _, _) -> true
                                ; assertz(deployment_(D, K, Map, Twin, MF)) ) ))
                   ;   true )),
            assertz(loaded_(D))
        )).

map_name(Map, N) :-
    (   get_dict(project, Map, N)
    ;   get_dict(deployments, Map, Ns), member(N, Ns)
    ).

read_map(MF, Suffix, Map, Twin) :-
    read_file_to_string(MF, S, [encoding(utf8)]),
    atom_json_dict(S, Map, [value_string_as(string)]),
    atom_concat(Base, Suffix, MF),
    atom_concat(Base, '.le', Twin),
    exists_file(Twin).

%!  adapter_twin_map(+Twin, -Map) is semidet.
%   The mapping file beside a twin: `<twin>.adapter_map.json`, or the OIA
%   translator's `<twin>.oia_map.json`.
adapter_twin_map(Twin, Map) :-
    file_name_extension(Base, le, Twin),
    member(Suffix, ['.adapter_map.json', '.oia_map.json']),
    atom_concat(Base, Suffix, MF), exists_file(MF), !,
    read_file_to_string(MF, S, [encoding(utf8)]),
    atom_json_dict(S, Map, [value_string_as(string)]).

%!  adapter_twin_kb(+Twin, -KB) is det.
%   The twin's knowledge base, loaded once, again when the file changes.
adapter_twin_kb(Twin, KB) :-
    time_file(Twin, T),
    (   kb_cache(Twin, T, KB) -> true
    ;   with_mutex(le_adapter_kb,
            (   kb_cache(Twin, T, KB) -> true
            ;   le_kbs:load(Twin, KB),
                retractall(kb_cache(Twin, _, _)),
                assertz(kb_cache(Twin, T, KB))
            ))
    ).

		 /*******************************
		 *        ANSWERING A CASE      *
		 *******************************/

%!  adapter_decide(+Map, +Twin, +Case, +Outcomes, +Options, -Result) is det.
%
%   Case: a dict, values by public name; a structure's value a dict; a
%   list's a list; an entity's instances (OIA) a list of dicts with "@id".
%   Outcomes: a list of public names, `contract` (the attributes whose
%   `output` is "contract", else the goals), `goals` (those whose `goal` is
%   true) or `all` (every derived attribute). Options: reports(Names), the
%   outcomes whose explanation (decision report) is wanted.
%   Result: `_{outputs: Dict, reports: Dict}`; an outcome with no value is
%   null; a report is `{text, kind, children}`.
adapter_decide(Map, Twin, Case, Outcomes, Opts, _{outputs: Outputs, reports: Reports}) :-
    adapter_twin_kb(Twin, KB),
    adapter_outcome_attributes(Map, Outcomes, OAs),
    ( memberchk(reports(Rep0), Opts) -> true ; Rep0 = [] ),
    maplist([X, Y]>>( atom(X) -> atom_string(X, Y) ; Y = X ), Rep0, Reported),
    case_facts(Map, Case, FactText),
    le_kbs:createSession(KB, SM),
    setup_call_cleanup(
        true,
        (   (   FactText == ""
            ->  true
            ;   catch(le_kbs:parse_custom_facts(KB, FactText, Terms), error(le_parse_error(PM), _),
                      throw(error(domain_error(adapter_case, PM), _))),
                forall(member(F, Terms), le_kbs:addSessionFact(SM, F))
            ),
            % The outcomes without a report share one memory of the case's
            % remembered answers (a loan's schedule of payments is worked
            % out once, not once per outcome); each outcome with a report is
            % a query of its own, with its explanation.
            partition(reported_outcome(Reported), OAs, WithReport, Plain),
            reasoner:with_shared_memo(
                le_adapter:findall(P-V-none, ( member(A, Plain), P = A.name,
                                               outcome_value(KB, SM, A, false, V, _) ), PVRs1)),
            findall(P-V-R, ( member(A, WithReport), P = A.name,
                             outcome_value(KB, SM, A, true, V, R) ), PVRs2),
            append(PVRs1, PVRs2, PVRs)
        ),
        le_kbs:destroySession(SM)),
    findall(PA-V, ( member(P-V-_, PVRs), atom_string(PA, P) ), OPs),
    dict_pairs(Outputs, _, OPs),
    findall(PA-R, ( member(P-_-R, PVRs), R \== none, atom_string(PA, P) ), RPs),
    dict_pairs(Reports, _, RPs).

reported_outcome(Reported, A) :-
    get_dict(name, A, P),
    memberchk(P, Reported).

%!  adapter_outcome_attributes(+Map, +Outcomes, -Attributes) is det.
adapter_outcome_attributes(Map, contract, OAs) :- !,
    get_dict(attributes, Map, As),
    (   include(field_is(output, "contract"), As, OAs), OAs \== [] -> true
    ;   adapter_outcome_attributes(Map, goals, OAs)
    ).
adapter_outcome_attributes(Map, goals, OAs) :- !,
    get_dict(attributes, Map, As),
    include(field_is(goal, true), As, OAs).
adapter_outcome_attributes(Map, all, OAs) :- !,
    get_dict(attributes, Map, As),
    include(field_is(derived, true), As, OAs).
adapter_outcome_attributes(Map, Names, OAs) :-
    findall(A, ( member(N0, Names), atom_string(N0, N),
                 adapter_attribute(Map, N, A) ), OAs).

field_is(F, V, D) :- get_dict(F, D, V).

%!  adapter_attribute(+Map, +PublicName, -Attribute) is semidet.
%   By its name, key, text or an alias; then the same, case ignored.
adapter_attribute(Map, N0, A) :-
    ( string(N0) -> N = N0 ; atom_string(N0, N) ),
    get_dict(attributes, Map, As),
    (   member(A, As), attr_named(A, N) -> true
    ;   string_lower(N, L), member(A, As), attr_named_lower(A, L)
    ), !.

attr_named(A, N) :-
    (   get_dict(name, A, N) -> true
    ;   get_dict(key, A, N) -> true
    ;   get_dict(text, A, N) -> true
    ;   get_dict(aliases, A, Al), memberchk(N, Al)
    ).

attr_named_lower(A, L) :-
    (   member(F, [name, key, text]), get_dict(F, A, V), string(V), string_lower(V, L) -> true
    ;   get_dict(aliases, A, Al), member(V, Al), string_lower(V, L)
    ).

		 /*******************************
		 *   THE CASE AS LE SENTENCES   *
		 *******************************/

%   The case's facts, each the twin's own sentence for the attribute: its
%   template with the value written in (a text quoted, a date as
%   2026-10-15); a boolean only when true, or in its opposite form when
%   false and the twin has one.
case_facts(Map, Case, Text) :-
    dict_pairs(Case, _, Pairs),
    findall(S, ( member(K-V, Pairs), atom_string(K, KS), KS \== "@id",
                 case_sentence(Map, KS, V, S) ), Ss0),
    (   get_dict(current_date_template, Map, CDT), CDT \== null,
        \+ memberchk(currentDate-_, Pairs)
    ->  get_time(Now), stamp_date_time(Now, DT, local), date_time_value(date, DT, date(Y, M, D)),
        format(string(Today), "~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, D]),
        fill_slots(CDT, [lit(Today)], CDS0), atom_concat(CDS0, '.', CDS),
        Ss = [CDS|Ss0]
    ;   Ss = Ss0
    ),
    atomic_list_concat(Ss, '\n', A), atom_string(A, Text).

case_sentence(Map, K, V, S) :-
    adapter_attribute(Map, K, A), get_dict(kind, A, Kind),
    memberchk(Kind, ["structure", "list", "records"]), !,
    attr_sentence(A, none, V, S).
case_sentence(Map, K, V, S) :-
    is_list(V), get_dict(entities, Map, Es), Es \== [], !,
    entity_named(Map, K, E),
    member(I, V), instance_sentence(Map, E, I, S).
case_sentence(Map, K, V, S) :-
    adapter_attribute(Map, K, A), get_dict(entity, A, "global"),
    attr_sentence(A, none, V, S).

instance_sentence(Map, E, I, S) :-
    instance_name(Map, E, I, Name),
    (   E.inferred == false, fill_slots(E.instance_template, [lit(Name)], S0), atom_concat(S0, '.', S)
    ;   dict_pairs(I, _, Ps), member(K-V, Ps), atom_string(K, KS), KS \== "@id",
        adapter_attribute(Map, KS, A), A.entity \== "global",
        KS \== E.identifying_attribute,
        attr_sentence(A, Name, V, S)
    ).

instance_name(_, E, I, Name) :-
    (   E.identifying_attribute \== null, atom_string(IA, E.identifying_attribute), get_dict(IA, I, V)
    ->  value_literal(V, Name)
    ;   get_dict('@id', I, Id) -> value_literal(Id, Name)
    ).

entity_named(Map, K, E) :-
    member(E, Map.entities),
    (   E.relationship == K -> true
    ;   E.id == K -> true
    ;   E.relationship_text == K
    ), !.

%   The sentences of one value of an attribute (several for a structure or
%   a list).
attr_sentence(A, Instance, V, S) :-
    V \== null,
    get_dict(kind, A, Kind),
    (   Kind == "boolean"
    ->  (   V == true -> fill_slots(A.display, [], S0)
        ;   V == false, A.opposite \== null -> fill_slots(A.opposite, [], S0)
        )
    ;   Kind == "ebool"
    ->  V == true, fill_slots(A.template, [lit(Instance)], S0)
    ;   Kind == "value"
    ->  scalar(V), value_literal(V, L), fill_slots(A.display, [lit(L)], S0)
    ;   Kind == "evalue"
    ->  scalar(V), value_literal(V, L), fill_slots(A.template, [lit(Instance), lit(L)], S0)
    ;   Kind == "structure"
    ->  is_dict(V), dict_pairs(V, _, Ps),
        member(K-CV, Ps), atom_string(K, KS),
        member(C, A.components), attr_named(C, KS),
        attr_sentence(C, Instance, CV, S00), atom_concat(S0, '.', S00)
    ;   Kind == "list"
    ->  is_list(V),
        (   A.listed \== null, S0 = A.listed
        ;   member(X, V), scalar(X), X \== null, value_literal(X, L), fill_slots(A.template, [lit(L)], S0)
        )
    ;   Kind == "records"
    ->  is_list(V),
        (   A.listed \== null, S0 = A.listed
        ;   member(R, V), is_dict(R),
            findall(lit(L), ( member(C, A.components), atom_string(CK, C.name),
                              ( get_dict(CK, R, X), scalar(X) -> true ; X = null ),
                              value_literal(X, L) ), Fills),
            fill_slots(A.template, Fills, S0)
        )
    ),
    atom_concat(S0, '.', S).

scalar(V) :- \+ is_dict(V), \+ is_list(V).

%   A value as LE writes it: a number as it is, a date (YYYY-MM-DD) as it
%   is, a boolean or null as a word, any other text in double quotes.
value_literal(V, L) :- number(V), !, format(atom(L), '~w', [V]).
value_literal(true, true) :- !.
value_literal(false, false) :- !.
value_literal(null, null) :- !.
value_literal(V, L) :-
    atom_string(V, S),
    (   date_text(S) -> atom_string(L, S)
    ;   split_string(S, "\"", "", Parts), atomic_list_concat(Parts, '”', S1),
        format(atom(L), '"~w"', [S1])
    ).

date_text(S) :-
    string_length(S, 10), sub_string(S, 4, 1, _, "-"), sub_string(S, 7, 1, _, "-"),
    split_string(S, "-", "", [Y, M, D]), forall(member(X, [Y, M, D]), number_string(_, X)).

%   The template's places, in order, filled: lit(Text) writes Text, which
%   writes `which <noun>`, anything left keeps its place.
fill_slots(T, Fills, S) :-
    atomic_list_concat(Parts, '*', T),
    fill_parts(Parts, 0, Fills, Out),
    atomic_list_concat(Out, S0), normalize_space(atom(S), S0).

fill_parts([], _, _, []).
fill_parts([P|Ps], I, Fills, [Q|Qs]) :-
    (   I mod 2 =:= 0 -> Q = P, Fills1 = Fills
    ;   Fills = [F|Fills1] -> fill_one(F, P, Q)
    ;   Fills1 = [], format(atom(Q), '*~w*', [P])
    ),
    I1 is I + 1,
    fill_parts(Ps, I1, Fills1, Qs).

fill_one(lit(L), _, L).
fill_one(which, Slot, Q) :-
    atomic_list_concat([_|Ws], ' ', Slot), atomic_list_concat(Ws, ' ', N),
    format(atom(Q), 'which ~w', [N]).

		 /*******************************
		 *     ASKING THE OUTCOMES      *
		 *******************************/

%   The value of one outcome, with its report (the twin's explanation) when
%   Want is true and the outcome is a value or a condition.
outcome_value(KB, SM, A, Want, V, Report) :-
    get_dict(kind, A, Kind),
    (   Kind == "boolean"
    ->  fill_slots(A.display, [], Q),
        (   ask(KB, SM, Q, Want, _, Why) -> V = true, why_report(Want, Why, Report)
        ;   V = false, Report = none
        )
    ;   Kind == "value"
    ->  fill_slots(A.display, [which], Q),
        (   ask(KB, SM, Q, Want, Vars, Why), last(Vars, X)
        ->  typed_json(A, X, V), why_report(Want, Why, Report)
        ;   V = null, Report = none
        )
    ;   Kind == "evalue"
    ->  fill_slots(A.template, [which, which], Q),
        atom_string(PA, A.name),
        findall(Item, ( ask_all(KB, SM, Q, [I, X]), adapter_json_value(I, IJ), typed_json(A, X, XJ),
                        dict_pairs(Item, _, ['@id'-IJ, PA-XJ]) ), Items),
        V = Items, Report = none
    ;   Kind == "ebool"
    ->  fill_slots(A.template, [which], Q),
        atom_string(PA, A.name),
        findall(Item, ( ask_all(KB, SM, Q, [I]), adapter_json_value(I, IJ),
                        dict_pairs(Item, _, ['@id'-IJ, PA-true]) ), Items),
        V = Items, Report = none
    ;   Kind == "structure"
    ->  findall(CK-CV, ( member(C, A.components), atom_string(CK, C.name),
                         outcome_value(KB, SM, C, false, CV, _) ), Ps),
        (   \+ get_dict(null_when_empty, A, false), forall(member(_-X, Ps), X == null)
        ->  V = null
        ;   dict_pairs(V, _, Ps)
        ),
        Report = none
    ;   Kind == "list"
    ->  fill_slots(A.template, [which], Q),
        findall(XJ, ( ask_all(KB, SM, Q, [X]), typed_json(A, X, XJ) ), V),
        Report = none
    ;   Kind == "records"
    ->  length(A.components, N), length(Whichs, N), maplist(=(which), Whichs),
        fill_slots(A.template, Whichs, Q),
        findall(R, ( ask_all(KB, SM, Q, Xs),
                     findall(CK-XJ, ( nth1(I, A.components, C), nth1(I, Xs, X),
                                      atom_string(CK, C.name), typed_json(C, X, XJ) ), RPs),
                     dict_pairs(R, _, RPs) ), V),
        Report = none
    ;   V = null, Report = none
    ).

%   A question of the twin, in its own words: the goal LE reads it as, its
%   `which` places the goal's variables, in order. Without a report (Want
%   false), the reasoner is asked directly: the explanation, put into
%   sentences, is most of the time of a long proof, and nobody reads it.
ask(KB, SM, Q, Want, Vars, Why) :-
    question_goal(KB, Q, Goal),
    term_variables(Goal, Vars),
    (   Want == true
    ->  once(le_kbs:query(SM, Goal, _, _, Why))
    ;   once(reasoner:without_explanations(reasoner:i(Goal, SM, _, _))), Why = []
    ).

ask_all(KB, SM, Q, Vars) :-
    question_goal(KB, Q, Goal),
    term_variables(Goal, Vars),
    reasoner:without_explanations(reasoner:i(Goal, SM, _, _)).

question_goal(KB, Q, Goal) :-
    le_kbs:ensure_tokens(Q, Tokens),
    once(le_kbs:parse_query_to_goal(KB, Tokens, Goal, _)).

%   true and false are JSON's, unless the attribute is a text; null is
%   JSON's null.
typed_json(A, X, J) :-
    (   memberchk(X, [true, false]),
        \+ ( get_dict(type, A, T), memberchk(T, ["string", "text"]) )
    ->  J = X
    ;   adapter_json_value(X, J)
    ).

%!  adapter_json_value(+LEValue, -JSON) is det.
adapter_json_value(date(Y, M, D), S) :- !,
    format(string(S), "~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, D]).
adapter_json_value(null, null) :- !.
adapter_json_value(X, J) :- rational(X), \+ integer(X), !, J is float(X).
adapter_json_value(X, X) :- number(X), !.
adapter_json_value(X, X) :- string(X), !.
adapter_json_value(X, S) :- atom(X), !, atom_string(X, S).
adapter_json_value(X, S) :- format(string(S), "~w", [X]).

%   The twin's explanation as a report: each step's sentence, as the editor
%   shows it, and what it rests on.
why_report(false, _, none) :- !.
why_report(true, Why, Report) :-
    (   Why = [W|_] -> true ; W = Why ),
    (   why_node(W, Report) -> true ; Report = none ).

why_node(success(_, _, LE, Kids), _{text: T, kind: "proved", children: Ks}) :- !,
    format(string(T), "~w", [LE]),
    exclude(==(omitted), Kids, Kids1),
    maplist(why_child, Kids1, Ks).
why_node(failure(_, _, LE, Kids), _{text: T, kind: "not proved", children: Ks}) :- !,
    format(string(T), "~w", [LE]),
    maplist(why_child, Kids, Ks).
why_node(repeated_group(_, W), N) :- !, why_node(W, N).
why_node(W, _{text: T, kind: "step", children: []}) :- format(string(T), "~w", [W]).

why_child(K, N) :- ( why_node(K, N) -> true ; N = _{text: "", kind: "step", children: []} ).

		 /*******************************
		 *     HELPERS FOR THE ROUTES   *
		 *******************************/

%!  adapter_cors_headers(+Request) is det.
%   Every route allows any origin: a page served elsewhere (a portal, a
%   demonstration) calls the adapter as it called the old system.
adapter_cors_headers(Request) :-
    (   memberchk(origin(O), Request) -> true ; O = '*' ),
    format("Access-Control-Allow-Origin: ~w~n", [O]),
    format("Access-Control-Allow-Headers: Authorization, Content-Type, SOAPAction, X-KIE-ContentType, Accept~n"),
    format("Access-Control-Allow-Methods: GET, POST, OPTIONS~n"),
    format("Vary: Origin~n").

%!  adapter_preflight(+Request) is semidet.
%   Answers a browser's preflight (OPTIONS).
adapter_preflight(Request) :-
    memberchk(method(options), Request), !,
    adapter_cors_headers(Request),
    format("Content-Type: text/plain~n~n").

%!  adapter_reply(+Request, +Status, +JSON) is det.
adapter_reply(Request, Status, Dict) :-
    adapter_cors_headers(Request),
    format("Status: ~w~n", [Status]),
    reply_json_dict(Dict, [width(0)]).

%!  adapter_open_access(+Dialect) is semidet.
%   No sign-in is asked for: ADAPTERS_OPEN=true, the dialect's own switch,
%   or LE2's NO_RESTRICTIONS=true (a developer's machine, a demonstration).
adapter_open_access(Dialect) :-
    (   getenv('ADAPTERS_OPEN', true) -> true
    ;   open_access_variable(Dialect, V), getenv(V, true) -> true
    ;   getenv('NO_RESTRICTIONS', true)
    ).

%!  adapter_access(+Request, +Dialect, -OK) is det.
%   OK is `ok`, or error(Status, Dict) to reply with.
adapter_access(Request, Dialect, OK) :-
    (   adapter_open_access(Dialect) -> OK = ok
    ;   access_hook(Request, Dialect, OK0) -> OK = OK0
    ;   OK = error(401, _{error: "unauthorized",
                          error_description: "This server asks callers of its adapters to sign in."})
    ).

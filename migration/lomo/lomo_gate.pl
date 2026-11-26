/** <module> The gate of step 1: LOMO's search queries, on the RDF data and on the register

    The LOMO repository ships seven search queries (SPARQL) that make the
    tables of a digital statement from a description
    (scripts/rdf-to-table/queries/). No engine for LOMO exists, so a search
    tool for RDF data is the judge: oracle/sparql_judge.py runs the seven
    queries with rdflib over each data file (with the ontology and its word
    lists). This module makes the same seven tables from the register, with
    Logical English queries of one sentence each ("which thing has the label
    which text", "which agent acts as which role in which action"), and
    compares them row by row.

    The Logical English queries give the facts and what lib/lomo.le derives
    from them (the kinds of rule, the roles); this module only puts them
    together as a SPARQL query does (its OPTIONAL parts, GROUP BY,
    GROUP_CONCAT, COALESCE, MAX). A grouped column is compared as a set of
    values, without the empty ones.

        gate(-Results)              every file of the corpus
        gate_file(+TTL, +LE, -R)    one file and its register
        gate_tests(+TTL, -Tests)    the scenario of a register: the answers
                                    of three questions, from the judge
        judge_rows(+TTL, -PerQuery) the judge's rows (cached in oracle/cache/)

    From the LE2 checkout:
        ./myswipl.sh -q -g "use_module(migration/lomo/lomo_gate), gate_main" -t halt

    Copyright Miguel Calejo; Apache License 2.0, as the rest of this
    repository (../../NOTICE). Published "as is".
*/

:- module(lomo_gate, [gate/1, gate_file/3, gate_tests/2, judge_rows/2, gate_main/0, judge_available/0, shacl_gate/1, shacl_gate_main/0]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(process)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(semweb/rdf_db), [rdf_is_bnode/1]).
:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(le2(le_kbs)).
:- use_module(corpus).
:- use_module(lomo_reader).
:- use_module(lomo_twin, [twin_name/2]).
:- use_module(lomo_words).
:- use_module(lomo_shacl).

:- dynamic here/1.
:- discontiguous gate_table/3.
:- prolog_load_context(directory, D), retractall(here(D)), assertz(here(D)).

%   ---- the judge -------------------------------------------------------

python(P) :- here(D), atomic_list_concat([D, '/oracle/.venv/bin/python'], P), exists_file(P).

judge_available :- python(_).

cache_file(F) :- here(D), atomic_list_concat([D, '/oracle/cache/judge.json'], F).

%   The judge runs once over the whole corpus (25 s); its rows are kept in
%   oracle/cache/judge.json until a data file is newer.
judge_rows(TTL, PerQuery) :-
    ensure_judged,
    cache_file(C),
    judged(C, Dict),
    absolute_file_name(TTL, K),
    (   get_dict(K, Dict, PerQuery) -> true
    ;   judge_files([TTL], D1), get_dict(K, D1, PerQuery)
    ).

:- dynamic judged_/2.
judged(C, D) :- judged_(C, D), !.
judged(C, D) :- read_json(C, D), assertz(judged_(C, D)).

read_json(F, D) :- setup_call_cleanup(open(F, read, S, [encoding(utf8)]), json_read_dict(S, D, [value_string_as(string)]), close(S)).

ensure_judged :-
    cache_file(C),
    findall(F, lomo_file(_, F), Fs),
    (   exists_file(C), time_file(C, TC), forall(member(F, Fs), ( time_file(F, TF), TF =< TC ))
    ->  true
    ;   python(_) -> file_directory_name(C, CD), make_directory_path(CD), run_judge(C, Fs), retractall(judged_(_, _))
    ;   throw(error(existence_error(judge, 'migration/lomo/oracle/.venv (run oracle/setup.sh)'), _))
    ).

judge_files(Fs, D) :-
    tmp_file_stream(text, Out, S), close(S),
    run_judge(Out, Fs), read_json(Out, D), delete_file(Out).

run_judge(Out, Fs) :-
    python(P), here(H), corpus_dir(C),
    atomic_list_concat([H, '/oracle/sparql_judge.py'], Script),
    process_create(P, [Script, Out, C|Fs], [process(Pid)]),
    process_wait(Pid, exit(0)).

%   ---- Logical English queries on a register ---------------------------

:- dynamic rows_/2.

%   rows(+Sentence, -Rows): every answer of a query of one sentence, as the
%   list of the values of its `which` places.
rows(Text, Rows) :- rows_(Text, Rows), !.
rows(Text, Rows) :-
    nb_getval(lomo_gate_kb, KB-SM),
    parse_custom_query(KB, Text, G),
    term_variables(G, Vs),
    findall(Vs, reasoner:without_explanations(reasoner:i(G, SM, _, _)), Rows0),
    sort(Rows0, Rows),
    assertz(rows_(Text, Rows)).

r1(Text, X) :- rows(Text, Rows), member([X], Rows).
r2(Text, X, Y) :- rows(Text, Rows), member([X, Y], Rows).
r3(Text, X, Y, Z) :- rows(Text, Rows), member([X, Y, Z], Rows).

%   The text of a value, as SPARQL's STR() gives it: a thing's address
%   (a blank node: `_:`, as no two tools name blank nodes alike), a word of
%   a word list its address, a date in ISO form.
str(V, S) :-
    (   atom(V), r2("which thing is identified by which address", V, A) -> S = A
    ;   atom(V), vocabulary_term(IRI, V) -> atom_string(IRI, S)
    ;   V = date(Y, M, D) -> format(string(S), "~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, D])
    ;   atom(V) -> S = "_:"
    ;   number(V) -> number_string(V, S)
    ;   string(V) -> S = V
    ;   format(string(S), "~w", [V])
    ).

label_or_empty(Template, X, L) :-
    (   findall(L0, r2(Template, X, L0), Ls), Ls \== [] -> member(L, Ls) ; L = "" ).

values_set(Goal-V, Set) :- findall(S, ( call(Goal), str_or_text(V, S), S \== "" ), L), sort(L, Set).
str_or_text(V, S) :- ( string(V) -> S = V ; str(V, S) ).

one_or_empty(Template, X, V) :-
    (   findall(V0, r2(Template, X, V0), Vs), Vs \== [] -> member(V, Vs) ; V = "" ).

%   ---- the seven tables, from the register -----------------------------

gate_table('lomo-requirements', [rule, ref, description, elis, actors, processes, categories], Rows) :-
    findall(row([K, Ref, Desc, Elis, Actors, Procs, Cats]),
            ( r1("which thing is a legal rule", R), str(R, K),
              one_or_empty("which thing has the label which text", R, Ref),
              one_or_empty("which thing has the description which text", R, Desc),
              values_set(r2("which thing is established in which provision", R, E)-E, Elis),
              values_set(( r2("which rule produces which action", R, A),
                           \+ r2("which action has the result which result", A, _),
                           r2("which action has the agent role which agent role", A, Ro),
                           r2("which agent role is for the agent which agent", Ro, Ag),
                           label_or_empty("which thing has the label which text", Ag, AL) )-AL, Actors),
              values_set(( r2("which rule involves the process which process", R, P),
                           r2("which thing has the preferred label which text", P, PL) )-PL, Procs),
              values_set(( r2("which rule has the digital dimension which dimension", R, C),
                           r2("which thing has the preferred label which text", C, CL) )-CL, Cats) ),
            Rows).

gate_table('lomo-data-flows', [action, dataType, elis, providers, receivers, triggers, frequencies], Rows) :-
    findall(row([K, DT, Elis, Provs, Recvs, Trigs, Freqs]),
            ( r1("which thing is an action", A), once(r2("which action has the result which result", A, _)),
              str(A, K),
              one_or_empty("which thing has the label which text", A, DT),
              values_set(( r2("which rule produces which action", R, A),
                           r2("which thing is established in which provision", R, E) )-E, Elis),
              values_set(role_agent_label(A, addresser, L1)-L1, Provs),
              values_set(role_agent_label(A, addressee, L2)-L2, Recvs),
              values_set(( r2("which thing has the time specification which temporal specification", A, S),
                           r2("which temporal specification has the function which function", S, trigger),
                           r2("which temporal specification has the temporal label which text", S, TL) )-TL, Trigs),
              values_set(( r2("which thing has the time specification which temporal specification", A, S2),
                           r2("which temporal specification has the function which function", S2, deadline),
                           frequency_or_label(S2, FL) )-FL, Freqs) ),
            Rows),
    L1 = _, L2 = _.

role_agent_label(A, Role, L) :-
    r2("which action has the agent role which agent role", A, Ro),
    r2("which agent role has the role which role", Ro, Role),
    r2("which agent role is for the agent which agent", Ro, Ag),
    label_or_empty("which thing has the label which text", Ag, L).

frequency_or_label(S, V) :-
    (   findall(F, r2("which temporal specification has the frequency which duration", S, F), Fs), Fs \== []
    ->  member(V, Fs)
    ;   findall(L, r2("which temporal specification has the temporal label which text", S, L), Ls), Ls \== []
    ->  member(V, Ls)
    ;   V = ""
    ).

gate_table('lomo-data', [dataset, datasetLabel, elis, standards], Rows) :-
    findall(row([K, T, Elis, Stds]),
            ( r1("which thing is a dataset", D),
              r2("which thing has the title which text", D, T),
              once(r2("which thing is established in which provision", D, _)),
              str(D, K),
              values_set(r2("which thing is established in which provision", D, E)-E, Elis),
              values_set(( r2("which thing conforms to which standard", D, St),
                           r2("which thing has the title which text", St, SL) )-SL, Stds) ),
            Rows).

gate_table('lomo-digital-solutions', [software, title, publisher, elis, capabilities], Rows) :-
    findall(row([K, T, Pub, Elis, Caps]),
            ( r1("which thing is a software", S),
              r2("which thing has the title which text", S, T),
              str(S, K),
              publisher(S, Pub),
              values_set(r2("which thing is established in which provision", S, E)-E, Elis),
              values_set(r2("which thing has the capability which text", S, C)-C, Caps) ),
            Rows).

publisher(S, Pub) :-
    (   findall(P, r2("which thing is published by which agent", S, P), Ps), Ps \== []
    ->  member(P, Ps),
        (   findall(L, r2("which thing has the label which text", P, L), Ls), Ls \== []
        ->  member(Pub, Ls)
        ;   str(P, PS), strip_through(PS, "/agent/", Pub)
        )
    ;   Pub = ""
    ).

%   REPLACE(text, "^.*/x/", ""): the text after the last /x/.
strip_through(S, Sep, Out) :-
    (   sub_string(S, B, L, _, Sep), \+ ( sub_string(S, B2, _, _, Sep), B2 > B )
    ->  E is B + L, sub_string(S, E, _, 0, Out)
    ;   Out = S
    ).

gate_table('lomo-dps', [service, title, description, elis, solutions], Rows) :-
    findall(row([K, T, Desc, Elis, Sols]),
            ( r1("which thing is a public service", S),
              r2("which thing has the title which text", S, T),
              str(S, K),
              one_or_empty("which thing has the description which text", S, Desc),
              values_set(r2("which thing is established in which provision", S, E)-E, Elis),
              values_set(solution(S, Sol)-Sol, Sols) ),
            Rows),
    Sol = _.

solution(S, Sol) :-
    r2("which thing cites which resource", S, R),
    (   findall(T, r2("which thing has the title which text", R, T), Ts), Ts \== []
    ->  member(Sol, Ts)
    ;   str(R, RS), strip_through(RS, "/ie-solution/", Sol)
    ).

gate_table('lomo-assessment-table', [row, label, caption, measures, barriers], Rows) :-
    findall(Row-Label-(St-Type-J), assessment_statement(Row, Label, St, Type, J), Xs),
    findall(Row-Label, member(Row-Label-_, Xs), Ks0), sort(Ks0, Ks),
    findall(row([Row, Label, caption(Caps), M, B]),
            ( member(Row-Label, Ks),
              findall(C, ( member(Row-Label-(St-_-_), Xs), caption(St, C) ), Caps0), sort(Caps0, Caps),
              findall(V, ( member(Row-Label-(_-T-J), Xs), ( string_concat(_, "Measure", T) -> V = J ; V = "" ) ), Ms), max_member(M, Ms),
              findall(V, ( member(Row-Label-(_-T-J), Xs), ( string_concat(_, "Barrier", T) -> V = J ; V = "" ) ), Bs), max_member(B, Bs) ),
            Rows).

assessment_statement(Row, Label, St, Type, J) :-
    r1("which thing is an assessment", A),
    r2("which assessment results in which assessment statement", A, St),
    r2("which assessment statement has the statement type which type", St, Type),
    r2("which assessment statement has the judgement which text", St, J),
    r2("which thing has the description which text", St, Label),
    str(St, SS),
    (   ( string_concat(Base, "/measure", SS) ; string_concat(Base, "/barrier", SS) ) -> Row = Base ; Row = SS ).

caption(St, C) :-
    (   r2("which thing concerns the service which service", St, Svc),
        r2("which thing has the title which text", Svc, C)
    ;   \+ ( r2("which thing concerns the service which service", St, Svc2),
             r2("which thing has the title which text", Svc2, _) ),
        r2("which thing has the title which text", St, C)
    ;   \+ ( r2("which thing concerns the service which service", St, Svc3),
             r2("which thing has the title which text", Svc3, _) ),
        \+ r2("which thing has the title which text", St, _),
        C = ""
    ).

gate_table('lomo-assessment', [assessment, assessmentType, assessmentDesc, policy, statement, statementType, interpretation, judgement], Rows) :-
    findall(row([AK, AT, AD, Pol, SK, Type, I, J]),
            ( r1("which thing is an assessment", A),
              r2("which assessment results in which assessment statement", A, St),
              r2("which assessment statement has the judgement which text", St, J),
              r2("which assessment statement has the statement type which type", St, Type),
              r2("which assessment statement has the interpretation which text", St, I),
              str(A, AK), str(St, SK),
              opt_str(( r3("which thing has for which property the resource which resource", A, "dcterms:type", V1) ; r3("which thing has for which property the value which value", A, "dcterms:type", V1) ), V1, AT),
              opt_str(r2("which thing has the description which text", A, V2), V2, AD),
              opt_str(r2("which thing cites which resource", A, V3), V3, Pol) ),
            Rows0),
    sort(Rows0, Rows).

opt_str(Goal, V, S) :-
    (   findall(V, Goal, Vs), Vs \== [] -> member(V0, Vs), str_or_text(V0, S) ; S = "" ).

%   ---- the judge's rows, in the same form ------------------------------

grouped('lomo-requirements', [elis, actors, processes, categories]).
grouped('lomo-data-flows', [elis, providers, receivers, triggers, frequencies]).
grouped('lomo-data', [elis, standards]).
grouped('lomo-digital-solutions', [elis, capabilities]).
grouped('lomo-dps', [elis, solutions]).
grouped('lomo-assessment-table', []).
grouped('lomo-assessment', []).

judge_table(PerQuery, Q, Cols, Rows) :-
    atom_string(Q, QS), atom_string(QA, QS),
    get_dict(QA, PerQuery, Rows0),
    grouped(Q, G),
    findall(row(Vals),
            ( member(D, Rows0),
              findall(V, ( member(C, Cols), get_dict(C, D, V0), cell(C, G, V0, V) ), Vals) ),
            Rows1),
    sort(Rows1, Rows).

cell(C, G, V0, V) :-
    (   memberchk(C, G)
    ->  split_string(V0, "|", "", Parts0), exclude(==(""), Parts0, Parts), sort(Parts, V)
    ;   V = V0
    ).

%   ---- comparing --------------------------------------------------------

%   A blank node has no address that both tools share: `_:` in both.
blank_keys(row([K|Vs]), row([K1|Vs])) :- ( blank_id(K) -> K1 = "_:" ; K1 = K ).

blank_id(K) :- string(K), sub_string(K, 0, 2, _, "_:"), !.
blank_id(K) :-                                   % rdflib: N and 32 hexadecimal digits
    string(K), string_length(K, 33), sub_string(K, 0, 1, _, "N"),
    sub_string(K, 1, _, 0, H), string_codes(H, Cs), forall(member(C, Cs), code_type(C, xdigit(_))).

same_rows(Q, Judge0, Ours0, Missing, Extra) :-
    maplist(blank_keys, Judge0, Judge1), msort(Judge1, Judge),
    maplist(blank_keys, Ours0, Ours1), msort(Ours1, Ours),
    (   Q == 'lomo-assessment-table'
    ->  caption_match(Judge, Ours, Missing, Extra)
    ;   subtract_ms(Judge, Ours, Missing), subtract_ms(Ours, Judge, Extra)
    ).

%   SAMPLE() picks one caption of the group; ours lists every candidate.
caption_match(Judge, Ours, Missing, Extra) :-
    findall(J, ( member(J, Judge), J = row([R, L, C, M, B]),
                 \+ ( member(row([R, L, caption(Cs), M, B]), Ours), memberchk(C, Cs) ) ), Missing),
    findall(O, ( member(O, Ours), O = row([R, L, caption(Cs), M, B]),
                 \+ ( member(row([R, L, C, M, B]), Judge), memberchk(C, Cs) ) ), Extra).

subtract_ms([], _, []).
subtract_ms([X|Xs], Ys, R) :-
    (   selectchk(X, Ys, Ys1) -> R = R1 ; R = [X|R1], Ys1 = Ys ),
    subtract_ms(Xs, Ys1, R1).

%!  gate_file(+TTL, +LEFile, -Result)
%   Result = file(TTL, [query(Q, NJudge, NOurs, Missing, Extra), ...])
gate_file(TTL, LE, file(TTL, Results)) :-
    judge_rows(TTL, PerQuery),
    load(LE, KB), createSession(KB, SM),
    nb_setval(lomo_gate_kb, KB-SM),
    retractall(rows_(_, _)),
    findall(query(Q, NJ, NO, Missing, Extra),
            ( grouped(Q, _),
              gate_table(Q, Cols, Ours),
              judge_table(PerQuery, Q, Cols, Judge),
              length(Judge, NJ), length(Ours, NO),
              same_rows(Q, Judge, Ours, Missing, Extra) ),
            Results),
    retractall(rows_(_, _)),
    destroySession(SM).

register_file(TTL, LE) :-
    lomo_file(Set, TTL), twins_dir(lomo, Root), twin_name(TTL, Name),
    atomic_list_concat([Root, '/', Set, '/', Name, '.le'], LE).

gate(Results) :-
    findall(R, ( lomo_file(_, TTL), register_file(TTL, LE), exists_file(LE), gate_file(TTL, LE, R) ), Results).

gate_main :-
    gate(Results),
    forall(member(file(T, Qs), Results),
           ( file_base_name(T, B),
             forall(member(query(Q, NJ, NO, M, E), Qs),
                    (   M == [], E == [] -> true
                    ;   length(M, LM), length(E, LE),
                        format("~w ~w: judge ~w rows, register ~w; ~w missing, ~w extra~n", [B, Q, NJ, NO, LM, LE]),
                        forall(( member(X, M), nth1(I, M, X), I =< 3 ), format("    missing ~q~n", [X])),
                        forall(( member(X, E), nth1(I, E, X), I =< 3 ), format("    extra   ~q~n", [X]))
                    )) )),
    findall(Q-(NJ-ok), ( member(file(_, Qs), Results), member(query(Q, NJ, _, [], []), Qs) ), Oks),
    findall(Q-(NJ-bad), ( member(file(_, Qs), Results), member(query(Q, NJ, _, M, E), Qs), ( M \== [] ; E \== [] ) ), Bads),
    length(Results, NF),
    format("~nfiles: ~w~n", [NF]),
    forall(grouped(Q, _),
           ( aggregate_all(sum(N), member(Q-(N-_), Oks), RowsOk),
             aggregate_all(sum(N), member(Q-(N-_), Bads), RowsBad),
             aggregate_all(count, member(Q-_, Oks), FOk),
             aggregate_all(count, member(Q-_, Bads), FBad),
             format("~w: ~w files the same (~w rows), ~w files differ (~w rows)~n", [Q, FOk, RowsOk, FBad, RowsBad]) )).

%   ---- the scenario of a register ---------------------------------------
%   Three questions, with the judge's answers as the expectations: which rule
%   has which modality, which rule produces which action, which agent acts as
%   which role in which action. An answer about a blank node cannot be named
%   from the judge's rows: then that question gets no expectation.

gate_tests(TTL, Tests) :-
    (   catch(judge_rows(TTL, PerQuery), _, fail)
    ->  read_lomo(TTL, lomo(_, Nodes, _)),
        findall(E, gate_expectation(PerQuery, Nodes, E), Es),
        (   Es == [] -> Tests = []
        ;   Tests = [test(description, 'the source description', none, [], Es)]
        )
    ;   Tests = []
    ).

gate_expectation(PQ, Nodes, expects(modalities, Answers)) :-
    expect_rows(PQ, 'x-modalities', [rule, modality], Nodes, Rows),
    findall(lomo_modality(R, M), member([R, M], Rows), Answers).
gate_expectation(PQ, Nodes, expects(actions_of_rules, Answers)) :-
    expect_rows(PQ, 'x-actions-of-rules', [rule, action], Nodes, Rows),
    findall(lomo_produces(R, A), member([R, A], Rows), Answers).
gate_expectation(PQ, Nodes, expects(actions_of_agents, Answers)) :-
    expect_rows(PQ, 'x-agents-in-roles', [agent, role, action], Nodes, Rows),
    findall(lomo_acts_as(G, Ro, A), member([G, Ro, A], Rows), Answers).

expect_rows(PQ, Q, Cols, Nodes, Rows) :-
    get_dict(Q, PQ, Rows0), Rows0 \== [],
    findall(Vals, ( member(D, Rows0), maplist(named(D, Nodes), Cols, Vals) ), Rows1),
    length(Rows0, N), length(Rows1, N),          % every value named
    sort(Rows1, Rows).

named(D, Nodes, C, V) :-
    get_dict(C, D, S), atom_string(A, S),
    (   vocabulary_term(A, W) -> V = W
    ;   memberchk(node(A, V, _), Nodes)
    ).

%   ---- step 2: our validity check against pySHACL ------------------------

shacl_cache(F) :- here(D), atomic_list_concat([D, '/oracle/cache/shacl.json'], F).

%   The files of the check: the 63 data files and the 65 examples of the
%   specification (several of them abbreviated, so not valid), and three
%   descriptions broken on purpose (corpus/broken/).
shacl_files(Fs) :-
    findall(F, lomo_file(_, F), Fs1),
    here(D), atomic_list_concat([D, '/corpus/spec-examples'], SD),
    directory_files(SD, Ns0), msort(Ns0, Ns),
    findall(F, ( member(N, Ns), file_name_extension(_, ttl, N), atomic_list_concat([SD, '/', N], F) ), Fs2),
    atomic_list_concat([D, '/corpus/broken'], BD),
    directory_files(BD, Bs0), msort(Bs0, Bs),
    findall(F, ( member(N, Bs), file_name_extension(_, ttl, N), atomic_list_concat([BD, '/', N], F) ), Fs3),
    append([Fs1, Fs2, Fs3], Fs).

ensure_shacl_judged(Fs) :-
    shacl_cache(C),
    (   exists_file(C), time_file(C, TC), forall(member(F, Fs), ( time_file(F, TF), TF =< TC )) -> true
    ;   python(P), here(H), corpus_dir(CD),
        atomic_list_concat([H, '/oracle/shacl_judge.py'], Script),
        process_create(P, [Script, C, CD|Fs], [process(Pid), stderr(null)]),
        process_wait(Pid, exit(0))
    ).

%!  shacl_gate(-Results): [shacl(File, Same, Missing, Extra)]
shacl_gate(Results) :-
    shacl_files(Fs), ensure_shacl_judged(Fs),
    shacl_cache(C), read_json(C, D),
    findall(shacl(F, Same, Missing, Extra),
            ( member(F, Fs), get_dict(F, D, J),
              findall(r(Fo, Pa, Co, Va), ( member(X, J.results), atom_string(Fo, X.focus), atom_string(Pa, X.path),
                                          atom_string(Co, X.component), atom_string(Va, X.value) ), Judge0),
              msort(Judge0, Judge),
              lomo_shacl:check_file(F, Ours0),
              findall(r(Fo, Pa, Co, Va), member(result(Fo, Pa, Co, Va, _), Ours0), Ours1), msort(Ours1, Ours),
              subtract_ms(Judge, Ours, Missing), subtract_ms(Ours, Judge, Extra),
              length(Judge, Same0), length(Missing, NM), Same is Same0 - NM ),
            Results).

shacl_gate_main :-
    shacl_gate(Rs),
    forall(( member(shacl(F, _, M, E), Rs), ( M \== [] ; E \== [] ) ),
           ( file_base_name(F, B), format("~w: missing ~q~n   extra ~q~n", [B, M, E]) )),
    length(Rs, N),
    aggregate_all(count, member(shacl(_, _, [], []), Rs), Agree),
    aggregate_all(sum(S), member(shacl(_, S, _, _), Rs), Same),
    format("validity: ~w of ~w files agree with pySHACL, result by result (~w results in all)~n", [Agree, N, Same]).

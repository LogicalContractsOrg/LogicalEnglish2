/** <module> s(CASP) -> Logical English: the twin of an s(CASP) program

    Phase 2c (the design notes roadmap.md §5.7, §8). An s(CASP) program —
    in particular one of LE1's own s(CASP) translations, the sCASP pack's
    test/le_programs — becomes a migration (le_migration.pl): LE2's core
    reader (le_writer:prolog_to_ir/3, which knows `#pred`, classical
    negation, `#abducible`, denials and the CLP(Q) comparisons) gives the
    program; this module adds what the source says around it and the tests:

      - LE1's scenarios (scasp_source.pl) become scenarios, and each of the
        source's `?-` queries is asked in each of them;
      - every expected answer is computed by **s(CASP) itself on the
        source** (library(scasp), in a separate process: the fidelity
        oracle), never by the LE program; an answer that is a constraint
        rather than a value is written as pending;
      - each denial is an LE integrity constraint (`it must not be true
        that …`, LE2 le_summary.md §3.3): as in s(CASP), a scenario whose
        facts meet it answers nothing, and no answer assumes what would;
      - LE1's dates (Unix times in the places its `#pred` types as dates)
        become dates, and its undefined `is_days_after/3` LE2's built-in
        `*a date* is *a number* days after *a date*` — the oracle runs the
        source with LE1's meaning of it (86400 seconds a day).
*/

:- module(scasp_twin, [
    twin_migration/3,      % +File, +Options, -Migration
    build_twin/3,          % +File, +OutRoot, -Report
    oracle_answers/4       % +Program, +Facts, +Queries, -Answers
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module(library(ordsets)).
:- use_module(scasp_source).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).

		 /*******************************
		 *            THE TWIN          *
		 *******************************/

%!  build_twin(+File, +Root, -Report) is det.
%
%   Writes Root/<Name>/<Name>.le with its ledger and the source under
%   sources/.
build_twin(File, Root, Report) :-
    twin_name(File, Name),
    atomic_list_concat([Root, '/', Name], Dir),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
    file_base_name(File, B), atomic_list_concat([SD, '/', B], Copy),
    copy_file(File, Copy),
    twin_migration(File, [name(Name), source_copy(B)], Migration),
    write_migration(Migration, Dir, Name, Report).

%   citizenshiptrust-scasp.pl -> citizenshiptrust
twin_name(File, Name) :-
    file_base_name(File, B), file_name_extension(S0, _, B),
    ( sub_atom(S0, Bf, _, 0, '-scasp') -> sub_atom(S0, 0, Bf, _, S1) ; S1 = S0 ),
    downcase_atom(S1, S2),
    atom_codes(S2, Cs0), maplist(name_code, Cs0, Cs),
    atom_codes(Name, Cs).

name_code(C0, C) :- ( code_type(C0, alnum) -> C = C0 ; C = 0'_ ).

%!  twin_migration(+File, +Options, -Migration) is det.
twin_migration(File, Options, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    read_source(File, source(Program00, Scenarios0, Queries)),
    partition([T-_]>>(T = '$not_scasp'(_, _, _)), Program00, NotScasp, Program0),
    not_scasp_residues(NotScasp, NotScaspItems),
    ( option(name(Name), Options) -> true ; twin_name(File, Name) ),
    b_setval(scasp_twin_program, Name),
    ( option(source_copy(Copy), Options) -> true ; file_base_name(File, Copy) ),
    maplist(integral_floats, Program0, Program1),
    own_forall(Program1, Program, ForallNotes),
    findall(scenario(N, Fs), ( member(scenario(N, Fs0), Scenarios0), maplist(integral_floats_t, Fs0, Fs) ), Scenarios),
    findall((?- G)-Bs, member(G-Bs, Queries), QueryTerms),
    %  the scenarios' clauses give templates too (LE1 puts rules in them),
    %  but they are the scenarios', not the program's
    findall(T-[], ( member(scenario(_, Fs), Scenarios), member(T, Fs) ), ScenTerms),
    append([Program, QueryTerms, ScenTerms], Terms),
    prolog_to_ir(Terms, [kb(Name)], program(Header0, Items00)),
    findall(I, ( member(T-_, ScenTerms), scenario_clause_item(T, I) ), ScenItems),
    exclude(variant_of_any(ScenItems), Items00, Items0),
    dates_and_builtins(Items0, Items1a, DateNotes0),
    source_diagnostics(Program, Scenarios, Queries, Inputs, PredNotes, ProgramNotes),
    maplist(mark_input(Inputs), Items1a, Items1),
    append(DateNotes0, ForallNotes, DateNotes),
    template_types(Items1, Types),
    findall(Q, member(query(Q, _), Items1), QNames),
    %  the header: what it is and where from
    format(string(C0), "The Logical English twin of an s(CASP) program, written by the s(CASP) translator~nfrom ~w (kept in sources/).~nEvery expected answer in the scenarios is s(CASP)'s own answer on the source.", [Copy]),
    select(comment(_), Header0, Header1),
    Header = [comment(C0)|Header1],
    atomic_list_concat(['sources/', Copy], CopyRel),
    Doc = 'the source program',
    DocItems = [document(Doc, [text(CopyRel)])],
    append([DocItems, Items1, NotScaspItems], Items),
    %  the tests: s(CASP) on the source, per scenario and query
    (   Scenarios == [] -> Runs = [scenario(the_program, [])] ; Runs = Scenarios ),
    findall(QG, member(QG-_, Queries), QGoals),
    maplist(scenario_test(Program, QGoals, QNames, Items1, Types, Doc), Runs, Tests0),
    unreadable_pending(NotScaspItems, Tests0, Tests),
    append(Items1, NotScaspItems, LedgerItems),
    ledger(LedgerItems, Scenarios, Queries, DateNotes, PredNotes-ProgramNotes, Ledger),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    Meta = [program(Name), source('an s(CASP) program'), artifacts([Copy]),
            translator('LE2 migration/scasp (scasp_twin.pl)'), date(Date)].

%   A statement s(CASP) does not have — clingo's choice rules, disjunctive
%   heads, cardinality bounds, aggregates, ranges, weak constraints and
%   `#` directives, or anything that does not read — is a residue block
%   with its text: LE (and s(CASP), the oracle) cannot state it, and writing
%   it as a sentence would mean something else. What it concludes (the
%   names in its head) makes the expectations that depend on it pending.
not_scasp_residues(Terms, Items) :-
    findall(residue(Id, [title(Title), locator(Loc), source(Lang, Text), note(Note), concludes(Fs)]),
            ( nth1(I, Terms, '$not_scasp'(Kind, Text, Line)-_),
              format(atom(Id), 'not_scasp_~w', [I]),
              format(string(Loc), "line ~w", [Line]),
              not_scasp_title(Kind, Title), ( Kind == clingo -> Lang = clingo ; Lang = scasp ),
              not_scasp_note(Kind, Note),
              concluded_names(Text, Fs) ), Items).

not_scasp_title(clingo, "a statement in clingo (ASP) syntax, which s(CASP) does not have").
not_scasp_title(unreadable, "a statement that does not read as s(CASP) or Prolog (clingo syntax?)").

not_scasp_note(clingo, "A choice rule ({a;b}) or a disjunctive head (a;b) chooses among stable models: s(CASP) and Logical English have neither. State the choice another way (for example with abducibles, `; unknown`, or each alternative as a rule with a negated condition) or leave it to the assistant.").
not_scasp_note(unreadable, "s(CASP)'s reader does not read this statement; clingo-only syntax (cardinality bounds l { ... } u, #count/#sum aggregates, ranges 1..n, weak constraints :~, #const, #minimize) has no s(CASP) or Logical English form. Restate it, or leave it to the assistant.").

%   The names a statement's head (the text before `:-`) may conclude; a
%   weak constraint or a `#` directive concludes nothing.
concluded_names(Text, Fs) :-
    split_string(Text, "", " \t\r\n", [T]),
    (   ( sub_string(T, 0, _, _, ":~") ; sub_string(T, 0, _, _, "#") ; sub_string(T, 0, _, _, ":-") )
    ->  Fs = []
    ;   ( sub_string(T, B, _, _, ":-") -> sub_string(T, 0, B, _, Head) ; Head = T ),
        string_codes(Head, Cs),
        findall(F, ( phrase(names(Ns), Cs), member(F, Ns) ), Fs0),
        sort(Fs0, Fs)
    ).

names(Ns) --> [C], { code_type(C, lower) }, !, name_rest(Cs), { atom_codes(N, [C|Cs]) },
    names(Ns0), { ( memberchk(N, [not]) -> Ns = Ns0 ; Ns = [N|Ns0] ) }.
names(Ns) --> [C], { code_type(C, csym) }, !, name_rest(_), names(Ns).
names(Ns) --> [_], !, names(Ns).
names([]) --> [].

name_rest([C|Cs]) --> [C], { code_type(C, csym) }, !, name_rest(Cs).
name_rest([]) --> [].

%   A statement that concludes nothing nameable (a weak constraint, a
%   `#const`) may still change every answer: when there is one, s(CASP)'s
%   answers on the rest of the source are not the source's, and every
%   expectation is pending.
unreadable_pending(Items, Tests0, Tests) :-
    (   member(residue(Id, O), Items), memberchk(concludes([]), O)
    ->  format(string(Why), "s(CASP) cannot run the whole source: residue ~w (clingo syntax) may change every answer", [Id]),
        maplist(all_pending(Why), Tests0, Tests)
    ;   Tests = Tests0
    ).

all_pending(Why, test(N, D, L, F, Es0), test(N, D, L, F, Es)) :-
    maplist(pending_because(Why), Es0, Es).

pending_because(_, pending(W, E), pending(W, E)) :- !.
pending_because(Why, E, pending(Why, E)).

%   A program that defines forall/2 itself (LE1's list example: forall by
%   double negation through a wrong/2 with once/1) means the universal both
%   s(CASP) and LE have built in: its own definitions go.
own_forall(Program0, Program, Notes) :-
    (   member(T-_, Program0), clause_head_of(T, forall(_, _))
    ->  exclude(forall_definition, Program0, Program),
        Notes = ["the program's own forall/2 (by double negation, through wrong/2 and once/1) is the universal built into s(CASP) and LE (for all cases in which ...): its definitions are left out"]
    ;   Program = Program0, Notes = []
    ).

forall_definition(T-_) :- ( clause_head_of(T, forall(_, _)) ; clause_head_of(T, wrong(_, _)) ), !.

clause_head_of((H :- _), H) :- !.
clause_head_of(H, H).

scenario_clause_item((H :- B), rule(H, G, [])) :- !, prolog_goal_ir(B, G).
scenario_clause_item(F, fact(F, [])).

variant_of_any(Items, I) :- member(J, Items), J =@= I, !.

%   A scenario's clause as a line of it: a fact, or a rule of the scenario.
scenario_line((H :- B), rule(H, G)) :- !, prolog_goal_ir(B, G).
scenario_line(F, F).

%   LE1 writes whole numbers as floats (1633737600.0); s(CASP)'s CLP(Q)
%   and LE's dates want integers.
integral_floats(T-Bs, T1-Bs) :- integral_floats_t(T, T1).
integral_floats_t(T, T) :- var(T), !.
integral_floats_t(F, I) :- float(F), F =:= truncate(F), !, I is truncate(F).
integral_floats_t(T, T1) :- compound(T), !, T =.. [F|As], maplist(integral_floats_t, As, Bs), T1 =.. [F|Bs].
integral_floats_t(T, T).

		 /*******************************
		 *      DATES AND BUILT-INS     *
		 *******************************/

%   is_days_after/3 (LE1's, undefined in the programs) -> LE2's built-in;
%   its naive template goes. Unix times in date places -> dates.
dates_and_builtins(Items0, Items, Notes) :-
    (   \+ ( member(I, Items0), ( I = rule(H, _, _) ; I = fact(H, _) ), functor(H, is_days_after, 3) ),
        select(template(is_days_after/3, _, _), Items0, Items1)
    ->  Notes = ["is_days_after/3, which LE1's programs call but do not define, is LE2's built-in *a date* is *a number* days after *a date*"]
    ;   Items1 = Items0, Notes = []
    ),
    (   Notes == [] -> b_setval(scasp_days_builtin, false) ; b_setval(scasp_days_builtin, true) ),
    maplist(rename_builtin, Items1, Items2),
    template_types(Items2, Types),
    maplist(item_dates(Types), Items2, Items).

rename_builtin(T, T) :- var(T), !.
rename_builtin(is_days_after(A, N, B), le_is_days_after(A, N, B)) :- nb_current(scasp_days_builtin, true), !.
rename_builtin(T, T1) :- compound(T), !, T =.. [F|As], maplist(rename_builtin, As, Bs), T1 =.. [F|Bs].
rename_builtin(T, T).

%   Types: [F/N-[Type, ...]] from the template texts' places.
template_types(Items, Types) :-
    findall(F/N-Ts, ( member(template(F/N, Text, _), Items), text_types(Text, Ts) ), Types).

text_types(Text, Types) :-
    atom_string(Text, S),
    split_string(S, "*", "", Parts),
    findall(T, ( nth1(I, Parts, P), I mod 2 =:= 0,
                 split_string(P, " ", "", Ws), last(Ws, W), atom_string(T, W) ), Types).

item_dates(Types, rule(H, B, O), rule(H1, B1, O)) :- !, lit_dates(Types, H, H1), lit_dates(Types, B, B1).
item_dates(Types, fact(H, O), fact(H1, O)) :- !, lit_dates(Types, H, H1).
item_dates(Types, query(N, G), query(N, G1)) :- !, lit_dates(Types, G, G1).
item_dates(_, I, I).

lit_dates(_, V, V) :- var(V), !.
lit_dates(Types, L, L1) :-
    compound(L), functor(L, F, N), memberchk(F/N-Ts, Types), !,
    L =.. [F|As], maplist(arg_date(Types), Ts, As, Bs), L1 =.. [F|Bs].
lit_dates(Types, L, L1) :- compound(L), !, L =.. [F|As], maplist(lit_dates(Types), As, Bs), L1 =.. [F|Bs].
lit_dates(_, L, L).

arg_date(_, date, A, D) :- integer(A), A > 100000000, !, unix_date(A, D).
arg_date(Types, _, A, B) :- lit_dates(Types, A, B).

unix_date(S, date(Y, M, D)) :- stamp_date_time(S, date(Y, M, D, _, _, _, _, _, _), 'UTC').

		 /*******************************
		 *         THE TESTS            *
		 *******************************/

scenario_test(Program, QGoals, QNames, Items, Types, Doc, scenario(Name, Facts), test(Name, Doc, Loc, Facts1, Expects)) :-
    (   Name == the_program -> Loc = none ; format(atom(Loc), 'scenario ~w', [Name]) ),
    maplist(scenario_line, Facts, Lines0),
    maplist(rename_builtin, Lines0, FactsB),
    maplist(lit_dates(Types), FactsB, Facts1),
    findall(F-[], member(F, Facts), FactTerms),
    oracle_answers(Program, FactTerms, QGoals, Answers),
    findall(E, ( nth1(I, QNames, QN), sub_atom(QN, 0, _, _, query_), nth1(I, Answers, A),
                 ( adjudication(Doc, Name, QN, Why) -> Key = QN-adjudicated(Why) ; Key = QN ),
                 query_expectation(Key, A, Items, Types, E) ), Es0),
    Expects = Es0.

query_expectation(QN-Adj, A, Items, Types, E) :- !,
    query_expectation(QN, A, Items, Types, E0),
    ( Adj = adjudicated(Why) -> E = pending(Why, E0) ; E = E0 ).
query_expectation(QN, answers(As), Items, Types, expects(QN, As1)) :- !,
    maplist(rename_builtin, As, AsB), maplist(lit_dates(Types), AsB, As2),
    maplist(negated_answer(Items), As2, As3), sort(As3, As1).
query_expectation(QN, constraint, _, _, pending('s(CASP) answers with a constraint, not a value', expects(QN, []))) :- !.
query_expectation(QN, error(error(existence_error(scasp_predicate, _), _)), _, _, expects(QN, [])) :- !.
query_expectation(QN, error(E), _, _, pending(Why, expects(QN, []))) :-
    format(string(Why), "s(CASP) did not answer on the source (~w)", [E]).

%   A negated query's answer is written as LE shows it: "it is not the case
%   that ..." with the literal's sentence.
negated_answer(Items, not(G), S) :- !,
    ir_dicts(program([], Items), Dicts),
    render_ground_literal(Dicts, G, T),
    format(string(S), "it is not the case that ~w", [T]).
negated_answer(_, A, A).

%!  oracle_answers(+Program, +Facts, +Queries, -Answers) is det.
%
%   s(CASP) on the source program with a scenario's facts, in a process of
%   its own: for each query, answers(GroundInstances), `constraint` when an
%   answer binds a variable to a constraint, or error(Why). LE1's
%   is_days_after/3 is given its meaning (86400 seconds a day).
oracle_answers(Program, Facts, Queries, Answers) :-
    tmp_file_stream(text, File, S),
    format(S, ":- use_module(library(scasp)).~n:- style_check(-singleton).~n:- style_check(-discontiguous).~n", []),
    (   member(T0-_, Program), ( T0 = (is_days_after(_, _, _) :- _) ; T0 = is_days_after(_, _, _) )
    ->  true                                % the program's own
    ;   format(S, "is_days_after(A, N, B) :- A #= B + N*86400.~n", [])
    ),
    lloyd_topor(Program, Program1),
    forall(member(T-_, Program1), write_clause(S, T)),
    forall(member(T-_, Facts), write_clause(S, T)),
    close(S),
    length(Queries, NQ),
    format(string(Goal),
           "consult('~w'), forall(between(1, ~w, I), ( nth1(I, ~q, Q), catch(call_with_time_limit(30, findall(Q, scasp(Q, []), L)), E, (L = error(E))), ( L = error(Er) -> R = error(Er) ; ( ground(L) -> R = answers(L) ; R = constraint ) ), format(\"~~k~~n\", [I-R]) )), halt",
           [File, NQ, Queries]),
    le2_swipl(Swipl),
    setup_call_cleanup(
        process_create(Swipl, ['-q', '-g', Goal, '-t', 'halt(1)'], [stdout(pipe(Out)), stderr(null), process(Pid)]),
        ( read_string(Out, _, Str), process_wait(Pid, _) ),
        ( close(Out), delete_file(File) )),
    split_string(Str, "\n", " ", Lines),
    findall(I-R, ( member(Line, Lines), Line \== "",
                   catch(term_string(I-R, Line), _, fail) ), Pairs),
    findall(R, ( between(1, NQ, I), ( memberchk(I-R, Pairs) -> true ; R = error(no_answer) ) ), Answers).

%   s(CASP) has no Prolog forall(Condition, Goal) (its forall/2 quantifies a
%   variable) and no call/1: a forall in a body becomes the negation of a
%   helper that looks for a counterexample (Lloyd–Topor), which is what the
%   universal means and what s(CASP) runs.
lloyd_topor(Program, Out) :-
    foldl(lt_clause, Program, 1-[], _-Rev), reverse(Rev, Out0), append(Out0, Out).

lt_clause(T-Bs, K0-Acc, K-[Cls|Acc]) :-
    (   T = (H :- B), sub_term(F, B), nonvar(F), F = forall(_, _)
    ->  lt_body(B, H, B, K0, K, B1, Aux),
        Cls = [(H :- B1)-Bs|Aux]
    ;   K = K0, Cls = [T-Bs]
    ).

lt_body(V, _, _, K, K, V, []) :- var(V), !.
lt_body((A, B), H, Whole, K0, K, (A1, B1), Aux) :- !,
    lt_body(A, H, Whole, K0, K1, A1, AuxA), lt_body(B, H, Whole, K1, K, B1, AuxB), append(AuxA, AuxB, Aux).
lt_body(forall(C, G), H, Whole, K0, K, not(Aux), [(Aux :- (C, not(G)))-[]]) :- !,
    K is K0 + 1,
    term_variables(forall(C, G), FVs),
    include(shared_outside(forall(C, G), H, Whole), FVs, Shared),
    format(atom(AF), 'le1_forall_counterexample_~w', [K0]),
    Aux =.. [AF|Shared].
lt_body(G, _, _, K, K, G, []).

%   A variable of the forall that occurs in the head or elsewhere in the body.
shared_outside(Forall, H, Whole, V) :-
    ( occurs_in(V, H) -> true ; replace_once(Whole, Forall, true, Rest), occurs_in(V, Rest) ).

occurs_in(V, T) :- term_variables(T, Vs), member(X, Vs), X == V, !.

replace_once(T, Old, New, New) :- T == Old, !.
replace_once(T, Old, New, R) :- compound(T), !, T =.. [F|As], replace_args(As, Old, New, Bs), R =.. [F|Bs].
replace_once(T, _, _, T).
replace_args([], _, _, []).
replace_args([A|As], Old, New, [B|Bs]) :- replace_once(A, Old, New, B), ( B \== A -> Bs = As ; replace_args(As, Old, New, Bs) ).

%   A denial `:- Body.` is written `false :- Body.`: in a consulted file,
%   library(scasp) reads only that form as a global constraint, and would
%   run `:- Body.` as a Prolog directive (so the oracle used to ignore the
%   source's constraints).
write_clause(S, T) :-
    (   T = (:- G), \+ G = (_, _), functor(G, F, _), memberchk(F, [use_module, module]) -> true
    ;   T = (:- G), \+ prolog_directive(G)
    ->  format(S, "~k.~n", [(false :- G)])
    ;   format(S, "~k.~n", [T])
    ).

prolog_directive(G) :- var(G), !, fail.
prolog_directive(G) :- functor(G, F, _),
    memberchk(F, [dynamic, discontiguous, set_prolog_flag, style_check, ensure_loaded, include,
                  multifile, table, initialization, op]).

%   $SWIPL is a path (./myswipl.sh) or a command name (`SWIPL=swipl`, which
%   testing/run_tests.sh accepts): a name is looked for on the PATH, as a
%   shell does.
le2_swipl(path(swipl)) :- \+ getenv('SWIPL', _), !.
le2_swipl(P) :- getenv('SWIPL', P0), ( sub_atom(P0, _, _, _, /) -> P = P0 ; P = path(P0) ).

%   Where s(CASP)'s answer on the source is not what the source's own
%   rules say, checked by hand: the expectation is kept, as pending, with
%   the reason. (The twin is never the oracle.)
:- multifile adjudicated/4.
adjudication(_, Scenario, Query, Why) :- adjudicated(Program, Scenario, Query, Why), nb_current(scasp_twin_program, Program), !.

adjudicated(loanwithcure, payment, query_1,
    "adjudicated: s(CASP) (sCASP pack, scasp_forall prev or not) answers that the borrower defaults on 2016-06-06, yet cures_the_failure_of_on_or_before(the_borrower, obligation2, 2016-06-06) succeeds on its own (payment on 2016-06-05, notice on 2016-06-06), so by the program's rules the default's not-cured condition fails: constructive negation over the anonymous variable in is_that/2. The twin follows the rules (no default)").

		 /*******************************
		 *           THE LEDGER         *
		 *******************************/

ledger(Items, Scenarios, Queries, DateNotes, PredNotes-ProgramNotes, Ledger) :-
    findall(entry(E, predicate, encoded, 'a template (the #pred wording, else a naive one)', T, Note),
            ( member(template(F/N, T, _), Items), format(string(E), "~w/~w", [F, N]),
              ( memberchk(F/N-Note, PredNotes) -> true ; Note = none ) ), L1),
    findall(entry(E, rule, encoded, 'a clause -> an LE rule', 'the rules', none),
            ( member(rule(H, _, _), Items), functor(H, F, N), format(string(E), "a clause of ~w/~w", [F, N]) ), L2a),
    list_to_set(L2a, L2),
    findall(C, member(constraint(C, _), Items), Cs),
    findall(entry(E, denial, encoded, 'a denial -> an integrity constraint, it must not be true that …', 'the constraints', none),
            ( nth1(I, Cs, _), format(string(E), "denial ~w", [I]) ), L3),
    findall(entry(E, scenario, encoded, 'an LE1 scenario -> a scenario', N, none),
            ( member(scenario(N, _), Scenarios), format(string(E), "Scenario ~w", [N]) ), L4),
    findall(entry(E, query, encoded, 'a ?- query -> a query, asked in every scenario', 'the queries', none),
            ( member(G-_, Queries), format(string(E), "?- ~q", [G]) ), L5),
    findall(entry(N0, dates, encoded, 'LE1 dates and date arithmetic -> LE2 dates and built-ins', 'the program', N0), member(N0, DateNotes), L6),
    findall(entry(Src, clause, residue, Title, Id, Note),
            ( member(residue(Id, O), Items), memberchk(source(_, Src), O), memberchk(note(Note), O),
              (   sub_atom(Id, 0, _, _, not_scasp_), memberchk(title(Title), O) -> true
              ;   Title = 'a clause taking a list apart (no list patterns in LE)'
              ) ), L7),
    findall(entry(E, source, encoded, 'as the source has it', 'the rules', Note),
            member(E-Note, ProgramNotes), L8),
    append([L1, L2, L3, L4, L5, L6, L7, L8], Ledger).

		 /*******************************
		 *     WHAT THE SOURCE LEAVES   *
		 *******************************/

/*  What the source program says about its own predicates, beyond its
    clauses, and what the twin does with it. The verifier's warnings on a
    twin then have one of two explanations: a translation this module
    fixes, or a property of the source, which the ledger names.

      - A predicate the source declares `dynamic` and gives no clause, and
        that its rules or queries read, is data the user supplies: in LE a
        scenario element (`; undefined`, language.md §2), which is what
        LE1 meant by declaring it dynamic.
      - A predicate its rules read and nothing defines (not declared
        dynamic, no clause anywhere): a defect of the source, or a built-in
        of LE1 that s(CASP) does not have (has_as_head_before/3). s(CASP)
        answers nothing through it, and neither does the twin.
      - A predicate declared (`#pred`, `dynamic`) and never used; facts
        stated and never read; a fact with a variable (it holds for every
        value); a predicate defined only by a rule inside a scenario; rules
        that depend on themselves through negation (not stratified).
*/
source_diagnostics(Program, Scenarios, Queries, Inputs, PredNotes, ProgramNotes) :-
    findall(F/N, ( member((:- dynamic(Spec))-_, Program), spec_member(Spec, F/N) ), Dyn0),
    sort(Dyn0, Dynamic),
    findall(F/N, ( member(T-_, Program), sub_term(pred('::'(D, _)), T), nonvar(D), functor(D, F, N) ), Decl0),
    sort(Decl0, Declared),
    findall(F/N, ( member(T-_, Program), sub_term(abducible(G), T), nonvar(G), head_key(G, F/N) ), Abd0),
    sort(Abd0, Abducible),
    findall(F/N-Kind, ( member(T-_, Program), program_clause(T, H, _), head_key(H, F/N),
                        ( T = (_ :- _) -> Kind = rule ; Kind = fact ) ), PDef0),
    sort(PDef0, ProgDef),
    findall(F/N-S-Kind, ( member(scenario(S, Fs), Scenarios), member(T, Fs),
                          program_clause(T, H, _), head_key(H, F/N),
                          ( T = (_ :- _) -> Kind = rule ; Kind = fact ) ), SDef0),
    sort(SDef0, ScenDef),
    findall(F/N, ( ( member(T-_, Program), program_clause(T, _, B) ; member(scenario(_, Fs), Scenarios), member(T, Fs), program_clause(T, _, B)
                   ; member((:- B)-_, Program), \+ directive_goal(B)
                   ; member(B-_, Queries) ),
                   mentioned(B, F/N) ), Read0),
    sort(Read0, Read),
    findall(F/N, member(F/N-_, ProgDef), PD0), sort(PD0, PD),
    findall(F/N, member(F/N-_-_, ScenDef), SD0), sort(SD0, SD),
    ord_union([Declared, Dynamic, PD, SD, Read], All0),
    exclude(builtin_key, All0, All),
    findall(P, ( member(P, All), memberchk(P, Dynamic), \+ memberchk(P, PD), memberchk(P, Read) ), Inputs),
    ord_union(PD, Abducible, PDA),
    findall(P-Note, ( member(P, All), pred_note(P, Dynamic, Declared, ProgDef, ScenDef, Read, PDA, SD, Note) ), PNs),
    %  the facts of a classical negation -p are notes on p's entry (one template)
    findall(F/N-Note, ( member(NK-Note0, PNs), NK = NF/N, atom_concat('-', F, NF),
                        format(string(Note), "Its opposite (-~w): ~w", [F, Note0]) ), OppNotes),
    %  facts under a built-in's name (member/2): the source's rules call the built-in
    findall(F/N-Note, ( ( member(T-_, Program) ; member(scenario(_, Fs), Scenarios), member(T, Fs) ),
                        program_clause(T, H, true), head_key(H, F/N), builtin_key(F/N),
                        format(string(Note), "Source defect: the source states facts of ~w/~w, the name of a built-in, and its rules call only the built-in, so nothing reads them (the verifier reports the facts unconsumed).", [F, N]) ), BNs),
    append([PNs, OppNotes, BNs], AllNotes),
    merge_notes(AllNotes, PredNotes0),
    findall(K-Note, ( member(K-Note0, PredNotes0),
                      ( hand_note(K, Extra) -> format(string(Note), "~w ~w", [Note0, Extra]) ; Note = Note0 ) ), PN1),
    findall(K-Extra, ( hand_note(K, Extra), \+ memberchk(K-_, PN1) ), PN2),
    append(PN1, PN2, PredNotes),
    universal_facts(Program, Scenarios, UF),
    negation_cycles(Program, Cycles),
    findall(E-Note, ( member(F/N, UF),
                      format(string(E), "a fact of ~w/~w with a variable", [F, N]),
                      Note = "As in the source: a fact with a variable holds for every value of it (the verifier notes a fact that introduces a variable)." ), N1),
    findall(E-Note, ( member(Cycle, Cycles),
                      atomic_list_concat(Cycle, ', ', CA),
                      format(string(E), "the rules of ~w", [CA]),
                      Note = "As in the source: these predicates depend on one another through negation (the program is not stratified). s(CASP) gives them its stable-model meaning; LE's Prolog engine may loop or differ, and the verifier says so." ), N2),
    append(N1, N2, ProgramNotes).

spec_member(V, _) :- var(V), !, fail.
spec_member((A, B), P) :- !, ( spec_member(A, P) ; spec_member(B, P) ).
spec_member([H|T], P) :- !, ( spec_member(H, P) ; spec_member(T, P) ).
spec_member(F/N, F/N).

%   A clause of the program proper: a fact or a rule, not a directive, a
%   `#` declaration or a query.
program_clause(T, _, _) :- var(T), !, fail.
program_clause((:- _), _, _) :- !, fail.
program_clause((?- _), _, _) :- !, fail.
program_clause(T, _, _) :- functor(T, '#', _), !, fail.
program_clause(T, _, _) :- T = '$not_scasp'(_, _, _), !, fail.
program_clause((H :- B), H, B) :- !.
program_clause(H, H, true).

%   A classical negation -p(X) is p's opposite: it defines and reads -p.
head_key(H, _) :- var(H), !, fail.
head_key(-(G), K) :- !, callable(G), functor(G, F, N), atom_concat('-', F, NF), K = NF/N.
head_key(H, F/N) :- callable(H), functor(H, F, N).

directive_goal(G) :- var(G), !.
directive_goal(G) :- callable(G), functor(G, F, _),
    memberchk(F, [use_module, module, dynamic, discontiguous, set_prolog_flag, style_check,
                  ensure_loaded, include, multifile, table, initialization, op]).

%   F/N is mentioned in Body: called, or a sentence an argument of a call.
mentioned(B, K) :-
    sub_term(S, B), nonvar(S), callable(S), \+ control(S),
    head_key(S, K).

control(S) :- functor(S, F, N), memberchk(F/N, [','/2, ';'/2, '->'/2, not/1, '\\+'/1, forall/2, findall/3, '#'/1, '::'/2]).

builtin_key(F/N) :- functor(G, F, N), predicate_property(system:G, defined), !.
builtin_key(F/_) :- sub_atom(F, 0, _, _, '#'), !.
builtin_key(F/_) :- memberchk(F, [member, append, reverse, length, is_list, msort, sort, '-', '+', '*', '/',
                                  '=', '\\=', '<', '>', '=<', '>=', is, true, false, fail, not, once,
                                  is_days_after, le_is_days_after]), !.

pred_note(P, Dynamic, _Declared, _ProgDef, _ScenDef, Read, PD, _SD, Note) :-
    memberchk(P, Dynamic), \+ memberchk(P, PD), memberchk(P, Read), !,
    Note = "Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined).".
pred_note(P, Dynamic, _, _, _, Read, PD, SD, Note) :-
    memberchk(P, Read), \+ memberchk(P, PD), \+ memberchk(P, SD), \+ memberchk(P, Dynamic), !,
    (   le1_builtin(P, What)
    ->  format(string(Note), "Source defect: the source reads it and defines it nowhere. It is ~w, a built-in of LE1 that s(CASP) does not have, so s(CASP) answers nothing through it, and neither does the twin (the verifier reports it undefined).", [What])
    ;   Note = "Source defect: the source reads it and defines it nowhere (and does not declare it dynamic), so nothing makes it true; s(CASP) answers nothing through it, and neither does the twin (the verifier reports it undefined)."
    ).
pred_note(P, _, _, _, _, Read, PD, SD, Note) :-
    \+ memberchk(P, Read), \+ memberchk(P, PD), \+ memberchk(P, SD), !,
    Note = "As in the source: declared and never used (the verifier reports the template unused).".
pred_note(P, _, _, ProgDef, ScenDef, Read, _, _, Note) :-
    \+ memberchk(P, Read),
    \+ memberchk(P-rule, ProgDef), \+ ( member(P-_-rule, ScenDef) ),
    ( memberchk(P-fact, ProgDef) ; member(P-_-fact, ScenDef) ), !,
    Note = "As in the source: facts are stated and no rule or query of the source reads them (the verifier reports the facts unconsumed).".
pred_note(P, _, _, _, ScenDef, _, PD, _, Note) :-
    \+ memberchk(P, PD), member(P-S-rule, ScenDef), !,
    format(string(Note), "As in the source: defined only by a rule inside scenario ~w, not by the program.", [S]).

le1_builtin(has_as_head_before/3, "has_as_head_before/3 (a list, its head, its rest)").

merge_notes(PNs, Notes) :-
    findall(P-N, ( member(P-_, PNs), findall(X, member(P-X, PNs), [N|_]) ), Notes0),
    sort(Notes0, Notes).

%   Facts of the program or of a scenario with a variable in them.
universal_facts(Program, Scenarios, Keys) :-
    findall(K, ( ( member(T-_, Program) ; member(scenario(_, Fs), Scenarios), member(T, Fs) ),
                 program_clause(T, H, true), T \= (_ :- _),
                 \+ ground(H), head_key(H, K) ), K0),
    sort(K0, Keys).

%   What a reading of one program found by hand, for its ledger.
hand_note(K, Note) :-
    nb_current(scasp_twin_program, Program),
    hand_note(Program, K, Note).

%   None at present. The obligation twin's note on its nested `that`
%   sentences was retired on 23 September 2026, when LE2's parser learnt to
%   read the template that starts first as the outer one
%   (le_grammar:outer_first/3).
hand_note(_, _, _) :- fail.

%   Sets of predicates that depend on one another with a negation on the way.
negation_cycles(Program, Cycles) :-
    findall(HK-BK-Sign, ( member(T-_, Program), program_clause(T, H, B), head_key(H, HK),
                          body_dep(B, pos, BK, Sign) ), Edges0),
    sort(Edges0, Edges),
    findall(A-B, member(A-B-_, Edges), Plain0), sort(Plain0, Plain),
    findall(Cyc, ( member(A-B-neg, Edges), reaches(Plain, B, A),
                   findall(X, ( member(X-_, Plain), reaches(Plain, X, A), reaches(Plain, A, X) ), Xs0),
                   sort([A|Xs0], Xs),
                   findall(F, member(F/_, Xs), Cyc) ), Cycles0),
    sort(Cycles0, Cycles).

body_dep(V, _, _, _) :- var(V), !, fail.
body_dep((A, B), S, K, S1) :- !, ( body_dep(A, S, K, S1) ; body_dep(B, S, K, S1) ).
body_dep((A ; B), S, K, S1) :- !, ( body_dep(A, S, K, S1) ; body_dep(B, S, K, S1) ).
body_dep(not(G), _, K, S1) :- !, body_dep(G, neg, K, S1).
body_dep(\+(G), _, K, S1) :- !, body_dep(G, neg, K, S1).
body_dep(forall(A, B), _, K, S1) :- !, ( body_dep(A, neg, K, S1) ; body_dep(B, neg, K, S1) ).
body_dep(G, S, K, S) :- callable(G), head_key(G, K), \+ builtin_key(K).

reaches(Edges, A, B) :- reaches(Edges, A, B, [A]).
reaches(Edges, A, B, _) :- memberchk(A-B, Edges), !.
reaches(Edges, A, B, Seen) :- member(A-C, Edges), \+ memberchk(C, Seen), reaches(Edges, C, B, [C|Seen]), !.

%   An input's template is a scenario element.
mark_input(Inputs, template(F/N, T, Adds), template(F/N, T, [undefined|Adds])) :-
    memberchk(F/N, Inputs), \+ memberchk(undefined, Adds), !.
mark_input(_, I, I).

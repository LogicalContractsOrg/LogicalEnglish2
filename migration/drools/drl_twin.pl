/** <module> Drools DRL -> Logical English: the twins of a rule base

    Phase 2e (the design notes roadmap.md §5.3, §8). LPS2 reads DRL into
    LPS (src/syntax/lps_drools.pl: `when … then` a reactive rule, `insert`,
    `modify`, `delete` actions with their causal laws); this module writes
    that reading as Logical English, in two readings of one parse:

      - *stateful* (every rule base): Logical English for LPS, in LPS2's
        *world reading* — the facts are states of the world (`there is a fire
        in *a room*`, `the sprinkler in *a room* is on`), the rules `if …
        then …` reactive rules with no times, what a rule does to working
        memory an event in the world with its causal law (`an alarm goes
        on`, `the sprinkler in *a room* turns on`), worded by default or by
        the rule base's wording table (`<stem>.wording` beside the DRL); the
        initial working memory as `initially`, the facts a Java driver
        inserts or deletes between two runs as observed events (a fire
        starting); a rule whose whole consequence is Java (println) is a
        residue block;
      - *stateless* (a rule base that only inserts — a decision service):
        timeless Logical English, the inserted facts' types concluded by
        rules, rules concluding one type ordered by salience into an
        `otherwise` cascade, the refraction guard (`not Discount(...)` in the
        rule that inserts a Discount) left out, and the Drools run's inserted
        facts as the scenario's expected answers.

    The fidelity oracle is **Drools itself** (oracle/, a KieSession with an
    agenda listener): the same working memory and steps, the rules that
    fired and the final working memory — against which the stateful twin's
    final state under LPS2 (`lps state`) and the stateless twin's answers
    are checked.
*/

:- module(drl_twin, [
    drl_migration/3,       % +Case, +Options, -Migration
    build_case/3,          % +Case, +OutRoot, -Report
    oracle_run/2,          % +Case, -Reply
    case_final_state/2,    % +OracleReply, -Fluents
    twin_final_state/2     % +LEFile, -Fluents
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module(library(json)).
:- use_module('../le2_paths').
:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).

%   The DRL front end is LPS2's (src/syntax/lps_drools.pl in the LPS2
%   repository). LPS2 loads it through its src/syntax/lps_plus.pl, which
%   declares the `lps2_src` paths it is written against, so that module is
%   loaded first. Without an LPS2 (../le2_paths.pl: a checkout beside LE2, or
%   $LPS2_DIR) there is no Drools door, and loading this file says so.
lps2_module(Rel, M) :- lps2_dir(D), atomic_list_concat([D, '/src/syntax/', Rel], M).
:- (   lps2_module(lps_plus, M)
   ->  use_module(M, []),
       lps2_module(lps_drools, F), use_module(F)
   ;   print_message(warning, format("migration/drools: no LPS2 found (set LPS2_DIR, or put a checkout beside LE2): DRL cannot be read", []))
   ).


path_of(Rel, Abs) :- here(H), atomic_list_concat([H, '/', Rel], Abs).

		 /*******************************
		 *           THE CASES          *
		 *******************************/

%   A case: case(Id, Options) (corpus.pl) with drl(File), model(Classes),
%   facts([Fact, ...]) — Type(Field1, ...), in the type's field order, an
%   object-valued field by the object's name — steps([step(Inserts,
%   Deletes), ...]), title(T), source(Doc, Url), max_time(N).

%!  case_declares(+Case, -Declares) is det.
%
%   The field order of every type: the DRL's `declare`s, and for a rule
%   base written against Java classes, the classes' fields (the oracle's
%   describe mode) — with each field's kind (object:T for a reference).
case_declares(Case, Declares) :-
    model_declares(Case, MDs),
    case_drl(Case, DRL),
    drl_parse(DRL, _, DDs0),
    findall(declare(T, FKs), ( member(declare(T, Fs), DDs0), \+ memberchk(declare(T, _), MDs),
                               findall(F-plain, member(F, Fs), FKs) ), DDs),
    append(MDs, DDs, Declares).

model_declares(case(_, Opts), Declares) :-
    (   option(model(Classes), Opts), Classes \== []
    ->  model_dir(MD),
        oracle_tool(Tool),
        process_create(Tool, [describe, MD|Classes], [stdout(pipe(O)), stderr(null), process(P)]),
        read_string(O, _, S), close(O), process_wait(P, _),
        atom_json_dict(S, Dict, []),
        dict_pairs(Dict, _, Pairs),
        findall(declare(T, Fs), ( member(T0-Fields, Pairs), downcase_atom(T0, T),
                                  findall(F-K, ( member(Fd, Fields), atom_string(F, Fd.name), atom_string(K, Fd.type) ), Fs) ),
                Declares)
    ;   Declares = []
    ).

model_dir(D) :- path_of(model, D).

%   The DRL of a case: its corpus file, or a path given as is (File ▸ Open).
case_drl(case(_, Opts), DRL) :-
    (   option(drl_path(DRL), Opts) -> true
    ;   option(drl(Rel), Opts), corpus_file(Rel, DRL)
    ).
oracle_tool(T) :- path_of('oracle/drl-oracle.sh', T).
corpus_file(Rel, F) :- path_of(corpus, C), atomic_list_concat([C, '/', Rel], F).

		 /*******************************
		 *           THE ORACLE         *
		 *******************************/

%!  oracle_run(+Case, -Reply) is det.
%
%   Drools on the case: its firings and final working memory (a dict).
oracle_run(Case, Reply) :-
    Case = case(_, Opts),
    option(drl(Rel), Opts), corpus_file(Rel, DRL),
    case_declares(Case, Declares),
    drl_package(DRL, Pkg),
    option(facts(Facts), Opts, []),
    maplist(oracle_fact(Pkg, Declares, Opts), Facts, FactDicts),
    option(steps(Steps), Opts, []),
    maplist(oracle_step(Pkg, Declares, Opts), Steps, StepDicts),
    (   option(model(_), Opts) -> model_dir(MD), Extra = _{classes: MD} ; Extra = _{} ),
    Spec0 = _{drl: [DRL], facts: FactDicts, steps: StepDicts, maxFirings: 500},
    Spec = Spec0.put(Extra),
    tmp_file_stream(text, SF, S), json_write_dict(S, Spec, [width(0)]), close(S),
    oracle_tool(Tool),
    setup_call_cleanup(
        process_create(Tool, [SF], [stdout(pipe(O)), stderr(null), process(P)]),
        ( read_string(O, _, Out), process_wait(P, _) ),
        ( close(O), delete_file(SF) )),
    atom_json_dict(Out, Reply, []).

drl_package(DRL, Pkg) :-
    read_file_to_string(DRL, S, []),
    (   sub_string(S, B, _, _, "package "), B1 is B + 8, sub_string(S, B1, _, 0, R),
        split_string(R, ";\n", " ", [P0|_])
    ->  atom_string(Pkg, P0)
    ;   Pkg = ''
    ).

%   A fact: a declared type of the DRL (fields by name) or a model class
%   (constructor arguments in field order, a reference by the object's id).
oracle_fact(Pkg, Declares, Opts, Fact, D) :-
    Fact =.. [T|Vals],
    fact_id(Fact, Id),
    (   option(model(Classes), Opts), member(C, Classes), class_type(C, T)
    ->  memberchk(declare(T, Fs), Declares),
        maplist(arg_json, Fs, Vals, Args),
        D0 = _{class: C, args: Args}
    ;   declared_name(Opts, T, TN), atomic_list_concat([Pkg, '.', TN], Full),
        drl_declared_fields(Opts, T, Fields),
        maplist([F, V, F-J]>>json_value(V, J), Fields, Vals, Pairs), dict_pairs(FD, _, Pairs),
        D0 = _{declared: Full, fields: FD}
    ),
    D = D0.put(id, Id).

oracle_step(Pkg, Declares, Opts, step(Ins, Del), _{insert: I, delete: D}) :-
    maplist(oracle_fact(Pkg, Declares, Opts), Ins, I),
    maplist(fact_id, Del, D).

%   A fact's id: its type and first value (`room:kitchen`), which is how
%   a reference names it.
fact_id(Fact, Id) :-
    Fact =.. [T|Vals],
    ( Vals = [V|_] -> format(atom(Id), '~w:~w', [T, V]) ; format(atom(Id), '~w', [T]) ).

arg_json(_-K, V, _{ref: Id}) :- sub_atom(K, 0, _, _, 'object:'), !,
    sub_atom(K, 7, _, 0, T0), downcase_atom(T0, T), format(atom(Id), '~w:~w', [T, V]).
arg_json(_, V, J) :- json_value(V, J).

json_value(V, V) :- number(V), !.
json_value(true, true) :- !.
json_value(false, false) :- !.
json_value(V, S) :- atom_string(V, S).

class_type(C, T) :- atomic_list_concat(Ps, '.', C), last(Ps, L), downcase_atom(L, T).
%   The type's name as the DRL declares it (the reader lowercases it).
declared_name(Opts, T, N) :-
    option(drl(Rel), Opts), corpus_file(Rel, DRL), read_file_to_string(DRL, S, []),
    split_string(S, "\n", " \t", Lines),
    member(L, Lines), split_string(L, " ", " ", ["declare", N0|_]),
    atom_string(N, N0), downcase_atom(N, T), !.

drl_declared_fields(Opts, T, Fields) :-
    option(drl(Rel), Opts), corpus_file(Rel, DRL),
    drl_parse(DRL, _, Ds), memberchk(declare(T, Fields), Ds).

%!  case_final_state(+Reply, -Fluents) is det.
%
%   The final working memory as the reading's fluents, sorted: each Drools
%   fact Type(field values), in the type's field order (the oracle writes an
%   object by its name), read as the twin reads it (lps_drools's world
%   reading: `sprinkler(kitchen, true)` is sprinkler(kitchen) and
%   sprinkler_on(kitchen)). Needs case_terms/3 (or case_world/2) first.
case_final_state(Reply, Fluents) :-
    findall(F, ( member(Fact, Reply.final), fact_fluent(Fact, F) ), Fs0),
    b_getval(drl_world, W),
    drl_world_facts(W, Fs0, Fs1),
    msort(Fs1, Fluents).

%!  case_world(+Case, -World) is det.
case_world(Case, World) :- case_terms(Case, _, _), b_getval(drl_world, World).

fact_fluent(Fact, F) :-
    atom_string(T0, Fact.type), downcase_atom(T0, T),
    nb_current(drl_case_declares, Ds), memberchk(declare(T, Fields), Ds), !,
    findall(V, ( member(Fd, Fields), field_name(Fd, N), get_dict(N, Fact.fields, V0), value_atom(V0, V) ), Vs),
    F =.. [T|Vs].

field_name(F-_, F) :- !.
field_name(F, F).

value_atom(V, V) :- number(V), !.
value_atom(true, true) :- !.
value_atom(false, false) :- !.
value_atom(V, A) :- atom_string(A, V).

%!  twin_final_state(+LEFile, -Fluents) is det.
%
%   The stateful twin run by LPS2 (`lps state`): its final fluents, sorted.
twin_final_state(LEFile, Fluents) :-
    lps2_dir(D), atomic_list_concat([D, '/lps'], Lps),
    le2_dir(LE2),
    setup_call_cleanup(
        process_create(Lps, [state, LEFile], [stdout(pipe(O)), stderr(null), process(P),
                                              environment(['LPS_LE2_LIB'=LE2])]),
        ( read_string(O, _, S), process_wait(P, _) ),
        close(O)),
    split_string(S, "\n", " ", Lines),
    findall(T, ( member(L, Lines), L \== "", catch(term_string(T, L), _, fail) ), Ts),
    msort(Ts, Fluents).

		 /*******************************
		 *           THE TWINS          *
		 *******************************/

%!  build_case(+Case, +Root, -Report) is det.
%
%   Root/<Id>/<Id>.le (the stateful twin, LE for LPS) and, for a rule base
%   that only inserts, Root/<Id>/<Id>_decision.le (the stateless twin),
%   each with its ledger; the DRL (its wording table, and the model's Java
%   sources) under sources/; the Drools run recorded in
%   sources/<Id>.drools.json.
build_case(Case, Root, report(Files, Reports)) :-
    Case = case(Id, Opts),
    atomic_list_concat([Root, '/', Id], Dir),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
    option(drl(Rel), Opts), corpus_file(Rel, DRL), file_base_name(DRL, DB),
    atomic_list_concat([SD, '/', DB], DCopy), copy_file(DRL, DCopy),
    %  the rule base's wording table goes with it (lps_drools reads it
    %  beside the DRL)
    file_name_extension(DStem, _, DRL), file_name_extension(DStem, wording, WF),
    (   exists_file(WF)
    ->  file_base_name(WF, WB), atomic_list_concat([SD, '/', WB], WCopy), copy_file(WF, WCopy)
    ;   true
    ),
    forall(( option(model(Classes), Opts), member(C, Classes) ), copy_model_source(C, SD)),
    oracle_run(Case, Reply),
    format(atom(RF), '~w/~w.drools.json', [SD, Id]),
    setup_call_cleanup(open(RF, write, S), json_write_dict(S, Reply, [width(100)]), close(S)),
    drl_migration(Case, [oracle(Reply), sources(DB)], Migration),
    write_migration(Migration, Dir, Id, R1),
    format(atom(F1), '~w/~w.le', [Dir, Id]),
    (   stateless(Case)
    ->  format(atom(Id2), '~w_decision', [Id]),
        drl_decision_migration(Case, [oracle(Reply), sources(DB)], M2),
        write_migration(M2, Dir, Id2, R2),
        format(atom(F2), '~w/~w.le', [Dir, Id2]),
        Files = [F1, F2], Reports = [R1, R2]
    ;   Files = [F1], Reports = [R1]
    ).

copy_model_source(Class, SD) :-
    atomic_list_concat(Ps, '.', Class), atomic_list_concat(Ps, '/', P),
    corpus_file(java, JD), format(atom(Src), '~w/~w.java', [JD, P]),
    (   exists_file(Src)
    ->  last(Ps, L), format(atom(Dst), '~w/~w.java', [SD, L]), copy_file(Src, Dst)
    ;   true
    ).

%   A rule base that only inserts (no modify, no delete) is also a decision
%   service.
stateless(Case) :-
    case_terms(Case, Terms, _),
    \+ ( member(T, Terms), ( T = updated(_, _, _, _) ; T = terminated(_, _, _) ; T = l_int(_, _) ) ),
    %  and every rule has a timeless reading: translated, with no aggregate
    %  and no negated conjunction
    case_drl(Case, DRL), drl_parse(DRL, Rules, _),
    \+ member(rule(_, _, unsupported(_), _, _), Rules),
    \+ ( member(T, Terms), sub_term(S, T), nonvar(S),
          ( S = findall(_, _, _) ; S = holds(not(L), _), is_list(L) ) ).

case_terms(Case, Terms, Diags) :-
    case_drl(Case, DRL),
    case_declares(Case, Declares),
    b_setval(drl_case_declares, Declares),
    Case = case(_, Opts),
    option(facts(Facts0), Opts, []),
    option(steps(Steps), Opts, []),
    findall(F, ( member(step(Ins, Del), Steps), ( member(F, Ins) ; member(F, Del) ) ), SFs),
    append(Facts0, SFs, Facts),
    once(drl_reading(DRL, [declares(Declares), facts(Facts)], reading(Ts0, Diags, World))),
    drl_parse(DRL, _, _, RAttrs),
    b_setval(drl_world, World),
    b_setval(drl_terms_src, Ts0),
    b_setval(drl_diags, Diags),
    b_setval(drl_rule_attrs, RAttrs),
    findall(T, member(t(T, _), Ts0), Terms).

%!  drl_migration(+Case, +Options, -Migration) is det.
%
%   The stateful twin: LE for LPS.
drl_migration(Case, Options, migration(Meta, program(Header, Items), Ledger, [])) :-
    Case = case(Id, Opts),
    case_terms(Case, Terms0, Diags),
    b_getval(drl_world, W),
    case_drl(Case, DRL),
    drl_parse(DRL, Rules, _),
    option(steps(Steps), Opts, []),
    %  the fluents and actions of the reading; the events of the driver's
    %  steps (a fire starting) are the world's, not the rules' actions
    memberchk(fluents(Fls), Terms0),
    ( memberchk(actions(Acts0), Terms0) -> true ; Acts0 = [] ),
    rule_items(DRL, Terms0, Rules, RuleItems),
    %  the actions some rule performs (an insertLogical's is not one: its
    %  fact is an intensional fluent)
    findall(A, ( member(A, Acts0), \+ functor(A, java_leaf, _), performed(RuleItems, A) ), Acts),
    driver_events(W, Steps, DEvs0),
    exclude(same_functor_in(Acts), DEvs0, DEvs1),
    list_to_set_by_functor(DEvs1, DEvs),
    drl_templates(W, Tmpls),
    maplist(template_item(Tmpls, fluent), Fls, FTs),
    maplist(template_item(Tmpls, event), DEvs, ETs),
    maplist(template_item(Tmpls, action), Acts, ATs),
    driver_laws(W, DEvs, DriverLaws),
    option(facts(Facts0), Opts, []),
    drl_world_facts(W, Facts0, Facts),
    ( Facts == [] -> Init = [] ; Init = [lps(initial_state(Facts))] ),
    length(Steps, NS), MaxT is 10 * (NS + 1),
    option(title(Title), Opts, Id),
    ( option(sources(DB), Options) -> true ; file_base_name(DRL, DB) ),
    final_state_comment(Options, FinalComment),
    format(string(HC), "~w~n~nThe Logical English (for LPS) twin of a Drools rule base, written by the DRL translator~nfrom LPS2's reading of ~w (kept in sources/).~nEach Drools rule is a reactive rule. Its facts are states of the world, and what it does to~nworking memory (insert, modify, delete) is something happening in the world, with its causal law.", [Title, DB]),
    Header = [kb(Id), target(lps), setting(max_time, MaxT), comment(HC)],
    atomic_list_concat(['sources/', DB], DocText),
    append([FTs, ETs, ATs,
            [document('the rule base', [text(DocText)])],
            RuleItems, DriverLaws, Init], Items0),
    step_scenario(W, program(Header, Items0), Steps, 10, Scen),
    append([Items0, Scen, FinalComment], Items),
    ledger(Rules, Diags, stateful, Ledger),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    Meta = [program(Id), source('a Drools rule base (DRL)'), artifacts([DB]),
            translator('LE2 migration/drools (drl_twin.pl, over LPS2''s lps_drools.pl)'), date(Date)].

performed(Items, A) :-
    functor(A, N, Ar),
    member(lps(R), Items), ( R = reactive_rule(_, Cons) ; R = reactive_rule(_, Cons, _) ),
    member(happens(E, _, _), Cons), functor(E, N, Ar), !.

same_functor_in(As, E) :- functor(E, N, Ar), member(A, As), functor(A, N, Ar), !.

list_to_set_by_functor(As, Set) :-
    findall(N/Ar-A, ( member(A, As), functor(A, N, Ar) ), Ps),
    sort(1, @<, Ps, Sorted), pairs_values(Sorted, Set).

%   A fluent, event or action with the reading's words (lps_drools's
%   drl_templates/2: its defaults, or the rule base's wording table).
template_item(Tmpls, Kind, T, Item) :-
    functor(T, N, Ar),
    memberchk(template(N/Ar, _, Text), Tmpls),
    Item =.. [Kind, N, Text, [known_as(N)]].

%   The events of the driver's steps: what its inserts and deletes are in
%   the world.
driver_events(W, Steps, Events) :-
    findall(E, ( member(step(Ins, Del), Steps),
                 ( member(F, Ins), drl_driver_events(W, insert, F, Es)
                 ; member(F, Del), drl_driver_events(W, delete, F, Es) ),
                 member(E, Es) ),
            Events).

%   Each rule: a comment naming it (with its salience, which LPS does not
%   have), its reactive rule(s) — one per alternative of an `or` — and
%   causal laws, or its intensional fluent (insertLogical); a rule whose
%   consequence is Java only is a residue block with the Java; a rule LPS2's
%   reader does not translate, or whose reading Logical English for LPS
%   cannot write, a residue block with the DRL and the reason.
rule_items(DRL, Terms, Rules, Items) :-
    findall(I, ( member(rule(Name, Sal, Body, RHS, Line), Rules),
                 rule_item(DRL, Terms, Name, Sal, Body, RHS, Line, I) ), Is),
    append(Is, Items).

rule_item(DRL, Terms, Name, Sal, Body, RHS, Line, Items) :-
    format(atom(RId0), 'rule_~w', [Name]), sanitise(RId0, RId),
    rules_at(Line, Rs0), ints_at(Line, Ints),
    (   disabled_at(Line)
    ->  format(string(C), "Rule \"~w\" has `enabled false` in the source: Drools never fires it, so it is left out", [Name]),
        Items = [comment(C)]
    ;   rule_residue(Body, Rs0, Ints, Why)
    ->  rule_source(DRL, Line, Code),
        Items = [residue(RId, [title(Name), source(drl, Code), note(Why)])]
    ;   Ints == [], Rs0 = [R], java_only(R)
    ->  java_code(RHS, Code0),
        (   attribute_notes(Line, [_|_], ANote)
        ->  format(string(Code), "~w~n// (~w)", [Code0, ANote])
        ;   Code = Code0
        ),
        Items = [residue(RId, [title(Name), source(java, Code),
                               note("the rule's whole consequence is Java (no working-memory change): not translated")])]
    ;   exclude(java_only, Rs0, Rs),
        (   Ints == [] -> IItems = []
        ;   format(string(C0), "Rule \"~w\": insertLogical, so the fact holds as long as its conditions do (Drools' truth maintenance) — an intensional fluent", [Name]),
            java_note(Line, RHS, Rs, C0, C),
            findall(lps(I), member(I, Ints), IIs),
            IItems = [comment(C)|IIs]
        ),
        maplist(reaction_items(Terms, Name, Sal, RHS), Rs, RIss),
        append([IItems|RIss], Items0),
        dedupe_items(Items0, Items)
    ).

%   Why a rule is a residue block, if it is one.
rule_residue(unsupported(Why0), _, _, Why) :- !,
    format(string(Why), "LPS2's reader does not translate this rule: ~w", [Why0]).
rule_residue(_, Rs, Ints, Why) :-
    (   member(R, Rs) ; member(R, Ints) ),
    sub_term(S, R), nonvar(S), S = holds(not(L), _), is_list(L), !,
    Why = "a pattern under `not` with a comparison (no such fact with a value over the limit, say): LPS2 reads it as the negation of a conjunction, which Logical English for LPS does not write yet".

%   The reactive rules and intensional fluents LPS2 made of the rule at
%   Line (its source position).
rules_at(Line, Rules) :-
    b_getval(drl_terms_src, Ts),
    findall(R, ( member(t(R, src(_, Line, _, _)), Ts),
                 ( R = reactive_rule(_, _) ; R = reactive_rule(_, _, _) ) ), Rules).

ints_at(Line, Ints) :-
    b_getval(drl_terms_src, Ts),
    findall(l_int(H, B), member(t(l_int(H, B), src(_, Line, _, _)), Ts), Ints).

rule_at(Line, Rule) :- rules_at(Line, [Rule|_]).

%   One reactive rule of a rule, with its causal laws; the Java is a comment
%   (LPS2 performs java_leaf in its place, which says nothing in English).
reaction_items(Terms, Name, Sal, RHS, Rule, Items) :-
    strip_salience(Rule, reactive_rule(Ante, Cons0)),
    exclude([happens(A, _, _)]>>( nonvar(A), functor(A, java_leaf, _) ), Cons0, Cons),
    R2 = reactive_rule(Ante, Cons),
    laws_of(Terms, R2, Laws),
    (   R2 = reactive_rule(Ante2, [_]), last(Ante2, holds(not(G), _)),
        member(initiated(_, F2, _), Laws), F2 == G
    ->  Guard = true
    ;   Guard = false
    ),
    rule_comment(Name, Sal, RHS, Rule, Guard, C),
    findall(lps(L), member(L, Laws), LawItems),
    Items = [comment(C), lps(R2)|LawItems].

%   (a causal law two alternatives of an `or` share, once)
dedupe_items([], []).
dedupe_items([I|Is], [I|Out]) :-
    (   I = lps(L), L \= reactive_rule(_, _), L \= reactive_rule(_, _, _)
    ->  exclude(=@=(I), Is, Is1)
    ;   Is1 = Is
    ),
    dedupe_items(Is1, Out).

java_only(reactive_rule(_, [happens(java_leaf(_), _, _)])).
java_only(reactive_rule(_, [happens(java_leaf(_), _, _)], _)).

java_code(RHS, Code) :- atomic_list_concat(RHS, '\n', Code).

%   An intensional fluent's comment names the rule's Java when no reactive
%   rule carries it.
java_note(Line, RHS, Rs, C0, C) :-
    java_lines(Line, RHS, Java),
    (   ( Java == [] ; Rs \== [] ) -> C = C0
    ;   atomic_list_concat(Java, ' ', J), format(string(C), "~w; its Java, not translated: ~w", [C0, J])
    ).

%   The line of the rule a reactive rule was made from.
rule_line(Rule, Line) :-
    b_getval(drl_terms_src, Ts),
    member(t(R, src(_, Line, _, _)), Ts), R =@= Rule, !.
rule_line(_, 0).

%   The statements of a rule's consequence that LPS2's reader left as Java
%   (its diagnostics name each: a println, a change with a value it does not
%   compute).
java_lines(Line, RHS, Java) :-
    rule_diags_at(Line, Ds),
    findall(L, ( member(L, RHS), L \== "",
                 member(diag(warning, drools_java_leaf, _, M, _), Ds),
                 format(atom(Q), '`~w`', [L]), sub_atom(M, _, _, _, Q) ), Java0),
    list_to_set(Java0, Java).

rule_diags_at(Line, Ds) :-
    b_getval(drl_diags, All),
    findall(D, ( member(D, All), D = diag(_, _, src(_, Line, _, _), _, _) ), Ds).

disabled_at(Line) :-
    rule_diags_at(Line, Ds), memberchk(diag(info, drools_disabled, _, _, _), Ds).

no_loop_read(Line) :-
    rule_diags_at(Line, Ds),
    (   memberchk(diag(info, drools_no_loop, _, _, _), Ds) -> true
    ;   member(diag(warning, drools_attribute, _, M, _), Ds), sub_atom(M, _, _, _, 'lock-on-active is read as no-loop'),
        \+ ( member(diag(warning, drools_attribute, _, M2, _), Ds), sub_atom(M2, _, _, _, 'is not translated: its consequence computes') )
    ).

%   The rule attributes LPS2's reader ignores or approximates (a warning
%   each), for a comment and the ledger: `agenda-group "audit", timer (int:
%   1s): not translated (Drools fires the rule only …)`.
attribute_notes(Line, Warnings, Note) :-
    rule_diags_at(Line, Ds),
    findall(M, member(diag(warning, drools_attribute, _, M, _), Ds), Warnings),
    Warnings \== [],
    b_getval(drl_rule_attrs, RAttrs),
    ( memberchk(attrs(Line, _, Attrs), RAttrs) -> true ; Attrs = [] ),
    findall(T, ( member(a(A, V), Attrs), A \== salience, A \== dialect,
                 attr_text(A, V, T),
                 ( A == '?' -> V = str(W), atom_string(WA, W) ; WA = A ),
                 member(M, Warnings), sub_atom(M, _, _, _, WA) ), Ts0),
    list_to_set(Ts0, Ts),
    (   Ts == [] -> Note = "a rule attribute is not translated (see the ledger)"
    ;   atomic_list_concat(Ts, ', ', TL),
        format(string(Note), "attributes not translated, or only in part (LPS has no agenda, calendar or clock; see the ledger): ~w", [TL])
    ).

attr_text('?', str(W), W) :- !.
attr_text(A, none, A) :- !.
attr_text(A, str(S), T) :- !, format(atom(T), '~w "~w"', [A, S]).
attr_text(A, expr(S), T) :- !, format(atom(T), '~w (~w)', [A, S]).
attr_text(A, V, T) :- format(atom(T), '~w ~w', [A, V]).

%   The DRL of the rule that starts at Line, to its `end`.
rule_source(DRL, Line, Code) :-
    read_file_to_string(DRL, S, []),
    split_string(S, "\n", "\r", Lines),
    findall(L, ( nth1(N, Lines, L), N >= Line ), After),
    take_rule(After, Ls),
    atomic_list_concat(Ls, '\n', Code).

take_rule([], []).
take_rule([L|Ls], [L|Out]) :-
    normalize_space(string(N), L),
    ( N == "end" -> Out = [] ; take_rule(Ls, Out) ).

sanitise(A, B) :- atom_codes(A, Cs), maplist([C, D]>>( code_type(C, alnum) -> D = C ; D = 0'_ ), Cs, Ds), atom_codes(B, Ds).

rule_comment(Name, Sal, RHS, Rule, Guard, C) :-
    rule_line(Rule, Line),
    java_lines(Line, RHS, Java),
    (   Sal =\= 0 -> format(string(S1a), "; salience ~w in the source (LPS has no conflict-resolution priority)", [Sal]) ; S1a = "" ),
    (   attribute_notes(Line, _, ANote) -> format(string(S1b), "; ~w", [ANote]) ; S1b = "" ),
    string_concat(S1a, S1b, S1),
    (   Guard == true -> S0b = "; its last condition keeps it from firing again while what it brings about holds, as Drools fires a rule once"
    ;   no_loop_read(Line) -> S0b = "; no-loop: its last condition keeps it from firing when its change is made already, as Drools does not fire it again on its own change"
    ;   S0b = ""
    ),
    S0a = S0b,
    (   member(L0, RHS), sub_string(L0, _, _, _, "insertLogical")
    ->  string_concat(S0a, "; its insertLogical is read as an insert, so the fact stays when these conditions stop holding (Drools would withdraw it)", S0)
    ;   S0 = S0a
    ),
    (   Java == [] -> S2 = ""
    ;   atomic_list_concat(Java, ' ', J), format(string(S2), "; its Java, not translated: ~w", [J])
    ),
    format(string(C), "Rule \"~w\"~w~w~w", [Name, S0, S1, S2]).

strip_salience(reactive_rule(A, C, _), reactive_rule(A, C)) :- !.
strip_salience(R, R).

%   The causal laws of a rule's actions (initiated/updated/terminated whose
%   action is one of the rule's consequences).
laws_of(Terms, reactive_rule(_, Cons), Laws) :-
    findall(L, ( member(happens(A, _, _), Cons), member(L0, Terms), law_action(L0, A0), A0 =@= A,
                 split_update(L0, Ls), member(L, Ls) ), Laws0),
    list_to_set(Laws0, Laws).

%   `modify(s) { setOn(true) }` with the old value a constant is written as
%   the old fact ending and the new one starting (the update form, `... that
%   is false becomes true`, does not read back with a constant old value).
split_update(updated(H, F, Old-New, Cs), [terminated(H, F, Cs), initiated(H, F1, Cs)]) :-
    atomic(Old), \+ var(Old), !,
    F =.. [T|Args], replace_first(Args, Old, New, Args1), F1 =.. [T|Args1].
%   With the old value a variable (a value computed from it, `count + 1`), the
%   update form needs a fluent worded `… is *a value*`, which the world
%   reading's `there is …` is not: the old fact, as it holds when the event
%   happens, ends and the new one starts.
split_update(updated(H, F, Old-New, Cs), [terminated(H, F, Cs1), initiated(H, F1, Cs1)]) :-
    var(Old), !,
    H = happens(_, T1, _), append(Cs, [holds(F, T1)], Cs1),
    F =.. [T|Args], replace_first(Args, Old, New, Args1), F1 =.. [T|Args1].
split_update(L, [L]).

replace_first([X|Xs], Old, New, [New|Xs]) :- X == Old, !.
replace_first([X|Xs], Old, New, [X|Ys]) :- replace_first(Xs, Old, New, Ys).

law_action(initiated(happens(A, _, _), _, _), A).
law_action(terminated(happens(A, _, _), _, _), A).
law_action(updated(happens(A, _, _), _, _, _), A).

%   What the driver's events do (a fire starting, a fire being put out):
%   the laws of the events no rule causes.
driver_laws(W, DEvs, Items) :-
    findall(lps(L),
            ( member(E0, DEvs), functor(E0, N, Ar), functor(E, N, Ar),
              drl_event_laws(W, E, Ls), member(L, Ls) ),
            Items0),
    ( Items0 == [] -> Items = [] ; Items = [comment("What happens between two runs of the rules: the Java driver's inserts and deletes, as events in the world.")|Items0] ).

%   The driver's steps as a scenario: step k's inserts and deletes, as the
%   events they are, observed at cycle k * Gap, after the rules have settled
%   (the LPS counterpart of the Java driver's fireAllRules between steps).
step_scenario(_, _, [], _, []) :- !.
step_scenario(W, IR, Steps, Gap, [scenario(driver, Lines, [])]) :-
    ir_dicts(IR, Dicts),
    length(Steps, N), numlist(1, N, Is),
    findall(Ls,
            ( nth1(I, Steps, step(Ins, Del)), member(I, Is), T1 is I * Gap, T2 is T1 + 1,
              findall(E, ( member(F, Ins), drl_driver_events(W, insert, F, Es), member(E, Es) ), E1),
              findall(E, ( member(F, Del), drl_driver_events(W, delete, F, Es), member(E, Es) ), E2),
              append(E1, E2, Evs),
              format(string(C), "the driver's step ~w (then the rules run again)", [I]),
              findall(raw(L), ( member(E, Evs), render_ground_literal(Dicts, E, S),
                                format(atom(L), '~w from ~w to ~w.', [S, T1, T2]) ), Raws),
              Ls = [comment(C)|Raws] ),
            LLs),
    append(LLs, Lines).

final_state_comment(Options, Items) :-
    (   option(oracle(Reply), Options)
    ->  case_final_state(Reply, Fs),
        findall(S, ( member(F, Fs), format(string(S), "  - ~q", [F]) ), Ss),
        atomic_list_concat(Ss, '\n', FT),
        length(Reply.firings, NF),
        format(string(C), "Drools (a KieSession on the same working memory and steps) fired ~w rule(s) and ended with~n(its facts as this twin's fluents):~n~w~nThe twin's final state under LPS2 (`lps state`) is compared with it by test_drools.pl.", [NF, FT]),
        Items = [comment(C)]
    ;   Items = []
    ).

		 /*******************************
		 *     THE DECISION SERVICE     *
		 *******************************/

%!  drl_decision_migration(+Case, +Options, -Migration) is det.
%
%   The stateless reading (a rule base that only inserts): timeless LE.
drl_decision_migration(Case, Options, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    Case = case(Id, Opts),
    case_terms(Case, Terms, Diags),
    b_getval(drl_world, W),
    case_drl(Case, DRL),
    drl_parse(DRL, Rules, _),
    memberchk(fluents(Fls), Terms),
    findall(F/N, ( member(Fl, Fls), functor(Fl, F, N) ), Types),
    drl_templates(W, Tmpls),
    %  the concluded fluents (a thing starting is its fact: `discount_starts`
    %  initiates discount), and each rule's (salience-ordered) alternative
    findall(Sal-alt(Name, Head, Body),
            ( member(rule(Name, _, _, _, Line), Rules), rules_at(Line, Rs), member(R, Rs),
              strip_salience_of(R, reactive_rule(Ante, Cons), Sal),
              member(happens(A, _, _), Cons), functor(A, AN, AAr),
              drl_meaning(W, AN/AAr, starts(_)),
              drl_event_laws(W, A, Ls), memberchk(initiated(_, Head, _), Ls),
              functor(Head, HT, _),
              decision_body(Ante, HT, Body) ),
            Alts0),
    findall(T, ( member(_-alt(_, H, _), Alts0), functor(H, T, _) ), CTs0), sort(CTs0, CTs),
    findall(template(T, Text, []), ( member(T/N, Types), memberchk(template(T/N, _, Text), Tmpls) ), TTs),
    findall(I, ( member(T, CTs), cascade(T, Alts0, I) ), RuleItems0), append(RuleItems0, RuleItems),
    option(title(Title), Opts, Id),
    ( option(sources(DB), Options) -> true ; file_base_name(DRL, DB) ),
    format(string(HC), "~w (the decision-service reading)~n~nThe timeless Logical English twin of a Drools rule base that only inserts facts (a decision~nservice), written by the DRL translator from ~w: each inserted~ntype is concluded by rules; each Drools rule is a rule, in salience order.", [Title, DB]),
    Header = [kb(Id), target(prolog), comment(HC)],
    atomic_list_concat(['sources/', DB], DocText),
    findall(query(QN, G), ( member(T, CTs), memberchk(T/N, Types), functor(G, T, N), format(atom(QN), '~w', [T]) ), Queries),
    append([TTs, [document('the rule base', [text(DocText)])], RuleItems, Queries], Items),
    decision_tests(Options, Opts, CTs, Types, Tests),
    ledger(Rules, Diags, stateless, Ledger),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    Meta = [program(Id), source('a Drools rule base (DRL), as a decision service'), artifacts([DB]),
            translator('LE2 migration/drools (drl_twin.pl)'), date(Date)].

strip_salience_of(reactive_rule(A, C, S), reactive_rule(A, C), S) :- !.
strip_salience_of(reactive_rule(A, C), reactive_rule(A, C), 0).

%   The antecedent without its times, and without the refraction guard: a
%   `not T(...)` on the very fluent the rule inserts (the DRL's own, or the
%   one the reading adds) is Drools' way of firing once, which a timeless
%   rule does by itself.
decision_body(Ante, T, Body) :-
    exclude(refraction_guard(T), Ante, Ante1),
    maplist(untimed, Ante1, Goals),
    (   Goals == [] -> Body = true ; Goals = [G|Gs], foldl([X, A, and(A, X)]>>true, Gs, G, Body) ).

refraction_guard(T, holds(not(F), _)) :- functor(F, T, _).

untimed(holds(not(F), _), not(F)) :- !.
untimed(holds(F, _), F) :- !.
untimed(G, G).

%   The alternatives concluding T: one rule per DRL rule, in salience order
%   (highest first), as the rule base has them. Drools fires only the first
%   (by salience) of the rules that match one case, when each guards itself
%   with `not T(...)`: a rule whose conditions do not already exclude those
%   of a rule of higher salience (one of them the negation of one of the
%   other's) says so, `it is not the case that` the other's own conditions
%   (those not shared). Deterministic, and closest to the DRL: no `otherwise`.
cascade(T, Alts0, Items) :-
    findall(S-A, ( member(S-A, Alts0), A = alt(_, H, _), functor(H, T, _) ), As0),
    sort(1, @>=, As0, As),
    (   As = [_-alt(Name, H, B)]
    ->  format(string(C), "Rule \"~w\"", [Name]),
        Items = [comment(C), rule(H, B, [])]
    ;   As = [_-alt(_, H0, _)|_], functor(H0, T, N), functor(H, T, N), H =.. [_|Vs],
        maplist(alt_of(Vs), As, Bodies),
        maplist(conj_list, Bodies, Lists),
        common_prefix(Lists, Prefix, Rests),
        cascade_rules(As, Lists, Rests, Prefix, [], H, Items0),
        append(Items0, Items)
    ).

cascade_rules([], [], [], _, _, _, []).
cascade_rules([Sal-alt(Name, _, _)|As], [L|Ls], [R|Rs], Prefix, Higher, H, [[comment(C), rule(H1, B1, [])]|Items]) :-
    exclude(excluded_by(R), Higher, Open),
    maplist(negated_rest, Open, Nots),
    trailing_bindings(L, Conds, Binds),
    append([Conds, Nots, Binds], Goals),
    list_conj(Goals, B),
    copy_term(H-B, H1-B1),
    format(string(C), "Rule \"~w\" (salience ~w)", [Name, Sal]),
    cascade_rules(As, Ls, Rs, Prefix, [R|Higher], H, Items).

%   A higher rule's own conditions R2 cannot hold with R1's: one is the
%   negation of the other's.
excluded_by(R1, R2) :-
    (   member(not(G), R1), member(G2, R2), G2 =@= G
    ->  true
    ;   member(not(G), R2), member(G1, R1), G1 =@= G
    ).

%   The conditions that bind only the head's values (`the rate is equal to
%   best`) say nothing of the case: they are left out of the negation.
negated_rest(R, not(C)) :-
    exclude(value_binding, R, R1),
    ( R1 == [] -> R2 = R ; R2 = R1 ),
    list_conj(R2, C).

value_binding(le_equal_to(_, _)).

%   The head's values, bound last in an alternative, stay last.
trailing_bindings(L, Conds, Binds) :-
    reverse(L, R),
    split_bindings(R, RB, RC),
    reverse(RC, Conds), reverse(RB, Binds).

split_bindings([G|Gs], [G|Bs], Cs) :- value_binding(G), !, split_bindings(Gs, Bs, Cs).
split_bindings(Gs, [], Gs).

alt_of(Vs, _-alt(_, Hi, Bi), Alt) :- alt_body(Hi, Bi, Vs, Alt).

conj_list(and(A, B), L) :- !, conj_list(A, LA), conj_list(B, LB), append(LA, LB, L).
conj_list(true, []) :- !.
conj_list(G, [G]).

list_conj([], true) :- !.
list_conj([G|Gs], C) :- foldl([X, A, and(A, X)]>>true, Gs, G, C).

common_prefix(Lists, [G|Prefix], Rests) :-
    Lists = [[G|_]|_],
    maplist(starts_with(G), Lists, Tails),
    \+ memberchk([], Tails), !,
    common_prefix(Tails, Prefix, Rests).
common_prefix(Lists, [], Lists).

starts_with(G, [H|T], T) :- H == G.

%   (no findall here: it copies, and the alternative must share the head's
%   variables)
alt_body(Hi, Bi, Vs, Body) :-
    Hi =.. [_|Args],
    link_args(Vs, Args, Eqs),
    append_goals(Bi, Eqs, Body).

%   A variable of the alternative's head is the cascade head's; a constant
%   is a condition that the head's value is that constant.
link_args([], [], []).
link_args([X|Xs], [V|Vs], Eqs) :-
    (   var(V) -> X = V, Eqs = Eqs1
    ;   Eqs = [le_equal_to(X, V)|Eqs1]
    ),
    link_args(Xs, Vs, Eqs1).

append_goals(B, [], B) :- !.
append_goals(true, [E|Es], G) :- !, foldl([X, A, and(A, X)]>>true, Es, E, G).
append_goals(B, Es, G) :- foldl([X, A, and(A, X)]>>true, Es, B, G).

%   The scenario: the initial working memory; the expected answers: what
%   Drools inserted of each concluded type.
decision_tests(Options, Opts, CTs, _Types, [test(drools_run, 'the Drools run', none, Facts, Expects)]) :-
    b_getval(drl_world, W),
    option(facts(Facts0), Opts, []),
    drl_world_facts(W, Facts0, Facts),
    (   option(oracle(Reply), Options)
    ->  findall(expects(T, As),
                ( member(T, CTs),
                  findall(F, ( member(Fi, Reply.firings), member(Fact, Fi.inserted), fact_fluent(Fact, F0),
                               drl_world_facts(W, [F0], Fs), member(F, Fs), functor(F, T, _) ), As0),
                  sort(As0, As) ),
                Expects)
    ;   Expects = []
    ).

		 /*******************************
		 *           THE LEDGER         *
		 *******************************/

ledger(Rules, Diags, Reading, Ledger) :-
    findall(E, ( member(rule(Name, Sal, Body, RHS, Line), Rules), rule_entry(Reading, Name, Sal, Body, RHS, Line, E) ), L1),
    %  (a salience is on its rule's entry: an entry of its own counted it twice)
    findall(entry(M, diagnostic, approximated, 'an LPS2 diagnostic of the reading', 'the program', M),
            ( member(diag(warning, Code, _, M0, _), Diags),
              memberchk(Code, [drools_undeclared_type, drools_insert_logical]),
              format(string(M), "~w", [M0]) ), L2),
    findall(entry(M, field, encoded, 'a field every fact gives one same value -> left out of the fluent', 'the program', M),
            ( member(diag(_, drools_field_dropped, _, M0, _), Diags), format(string(M), "~w", [M0]) ), L3),
    append([L1, L2, L3], Ledger).

rule_entry(_, Name, _, _, _, Line, entry(E, rule, encoded, M, Name, none)) :-
    disabled_at(Line), !,
    format(string(E), "rule \"~w\" (line ~w)", [Name, Line]),
    M = 'enabled false -> left out (Drools never fires the rule)'.
rule_entry(Reading, Name, Sal, Body, RHS, Line, Entry) :-
    rule_entry_(Reading, Name, Sal, Body, RHS, Line, Entry0),
    Entry0 = entry(E, rule, V0, M, Name, N0),
    %  what the reader ignores or approximates of the rule: an attribute, a
    %  change whose value is Java
    rule_diags_at(Line, Ds),
    findall(S, ( member(diag(warning, drools_java_leaf, _, M1, _), Ds),
                 sub_atom(M1, _, _, _, 'changes working memory with the value'), V0 \== residue,
                 S = "a change with a value computed in Java is left out (the rule performs java_leaf in its place)" ), JNs),
    findall(S, ( member(diag(warning, drools_attribute, _, M2, _), Ds), atom_string(M2, S) ), AWs),
    append(AWs, JNs, Extra0),
    (   Extra0 == []
    ->  Entry = Entry0
    ;   ( V0 == encoded -> V = approximated ; V = V0 ),
        ( N0 == none -> Ns0 = [] ; Ns0 = [N0] ),
        append(Ns0, Extra0, Ns),
        atomic_list_concat(Ns, '; ', N),
        Entry = entry(E, rule, V, M, Name, N)
    ).

rule_entry_(_, Name, _, unsupported(Why), _, Line, entry(E, rule, residue, M, Name, N)) :- !,
    format(string(E), "rule \"~w\" (line ~w)", [Name, Line]),
    M = 'not translated by LPS2''s reader', format(atom(N), 'kept as a residue block: ~w', [Why]).
rule_entry_(stateful, Name, Sal, Body, RHS, Line, entry(E, rule, V, M, Name, N)) :-
    format(string(E), "rule \"~w\" (line ~w)", [Name, Line]),
    rules_at(Line, Rs), ints_at(Line, Ints),
    (   rule_residue(Body, Rs, Ints, Why)
    ->  V = residue, M = 'not written: Logical English for LPS cannot express its reading', format(atom(N), 'kept as a residue block: ~w', [Why])
    ;   Ints == [], forall(member(R, Rs), java_only(R))
    ->  V = residue, M = 'a consequence in Java only', N = 'kept as a residue block'
    ;   Sal =\= 0
    ->  V = approximated, M = 'when ... then ... -> a reactive rule; its inserts, modifies and deletes -> events in the world with their causal laws',
        format(atom(N), 'salience ~w: LPS fires every rule whose conditions hold, with no priority', [Sal])
    ;   Ints \== []
    ->  V = encoded, M = 'insertLogical -> an intensional fluent (the fact holds while the conditions do)', N = none
    ;   V = encoded, M = 'when ... then ... -> a reactive rule; its inserts, modifies and deletes -> events in the world with their causal laws', N = none
    ),
    ignore(RHS = RHS).
rule_entry_(stateless, Name, Sal, _, _, Line, entry(E, rule, encoded, M, Name, N)) :-
    format(string(E), "rule \"~w\" (line ~w)", [Name, Line]),
    M = 'an insert -> a rule concluding the inserted fact; salience -> the order of the rules (a rule not excluded by one of higher salience says it does not apply)',
    ( Sal =\= 0 -> format(atom(N), 'salience ~w', [Sal]) ; N = none ).

/** <module> File ▸ Export to Another System ▸ DMN: the way back of Phase 4

    A Logical English program written as one DMN 1.6 decision model, with
    FEEL for its expressions, and its scenarios as the model's test cases in
    the format of the DMN Technology Compatibility Kit (TCK), so that any
    DMN engine (Drools, Camunda, Trisotech, ...) runs the model and its
    tests. What becomes what:

      - a value (`the age is *a number*`) that no rule concludes: an input
        (`inputData`), typed by its noun (number, string, boolean, date);
        a sentence with no place (`the applicant is a student`) that no rule
        concludes: a boolean input, false unless a scenario states it;
      - a value that rules conclude: a decision. Its rules, in order, are
        one FEEL literal expression: `if <conditions of rule 1> then <its
        value> else if ... else null` (a rule whose conditions fail gives
        no value, and DMN's null is "no value");
      - a sentence that rules conclude: a boolean decision, true when one of
        its rules holds and false otherwise (Logical English's closed world);
      - a list (`the beverages include *a text*`, with `the beverages are
        listed`): a list input, or a decision whose value is the list of
        what its rules conclude;
      - a decision table (language.md §17.3): a business knowledge model
        (BKM) whose logic is the table, invoked where a rule reads it; a
        decision whose one rule only reads the table's inputs and the table
        is the decision table itself. Hit policies: unique match UNIQUE,
        first match FIRST, all matches COLLECT;
      - conditions: a value read (`age`, guarded `age != null`, since a
        Logical English condition on a value fails where the value is
        missing), comparisons, arithmetic, `it is not the case that`
        (`not(...)`), `or`, the `otherwise` cascade, `the count / sum /
        minimum / maximum of each ...` (count(), sum(), min(), max()), a
        reading of a list (`some x in L satisfies ...`), and the templates of
        lib/temporal, lib/rounding, lib/maths, lib/text and lib/feel that
        FEEL has as built-in functions (dates, years between dates,
        rounding half even, powers, ...);
      - each scenario: a TCK test case, its facts the input nodes and the
        answers its queries expect the result nodes (a query that expects no
        answer: null for a value, false for a sentence, [] for a list).

    Names: a template's words (`the risk category is *a text*` → `risk
    category`); a name with a word FEEL reserves (and, or, not, in, if,
    then, else, for, some, every, null, true, false, ...) is written with
    underscores (`risk_category_or_null`).

    Refused, with the reason (le_import's export check): a template with
    places for things (a person, a contract: a DMN model decides one case
    at a time, without entities), dated values, a rule that reads the same
    list twice, a table read with different inputs at different places, an
    aggregate over something other than one list or table, and conditions
    FEEL has no form for here (a string operation other than `contains`,
    an embedded Prolog goal), a function with places that no rule or fact
    defines (only scenarios state it: a DMN input has no places), and an
    integrity constraint (DMN has none).

        export_dmn(+KB, +Options, -Result)       the exporter of le_import
        dmn_files(+KB, +Name, -DMN, -Tests)      the model and its test file
                                                 (throws dmn_export_refused)
        dmn_files(+KB, +Name, +Options, -DMN, -Tests)   the same, with the
                                                 program's text (text(Doc))

    Where each problem is (le_import's contract): a problem found in a rule
    or fact is placed at(Start, End) on it (from its IR item's source/3,
    which kb_to_ir/3 adds when the Options carry the program's text), or
    predicate(F/N) when its position is unknown; a problem about a
    predicate as a whole (a template DMN has no form for, a table, an
    assumable template) is placed predicate(F/N); only a problem about the
    whole program (an LPS program) is `none`. That is what lets a partial
    export leave out exactly the clauses DMN cannot say, and write the rest.

    Provenance: every decision and business knowledge model written from
    rules or facts has a `<description>` with the Logical English lines they
    came from (`Logical English lines 12 and 14`: a decision's FEEL merges
    all its rules), and every rule of a decision table the line of its row.
*/

:- module(dmn_export, [export_dmn/3, applies_dmn/1, check_dmn/3, dmn_files/4, dmn_files/5]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(sha)).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer), []).
:- use_module(le2(le_import), []).       % item_source_line/2, kb_constraint_problems/3

:- dynamic sym_/3.          % sym_(Functor, Kind, Info): what each template becomes
:- dynamic problem_/2.      % problem_(Where, Message)
:- dynamic bkm_used_/1.     % a table invoked as a BKM
:- dynamic table_io_/2.     % table_io_(Table, InOutPattern)
:- dynamic gensym_n/1.
:- dynamic prov_/2.         % prov_(Functor, Lines): the program lines of its rules and facts
:- dynamic row_lines_/2.    % row_lines_(Table, Lines): each row's line (or none), in order

		 /*******************************
		 *     THE EXPORTER'S CONTRACT  *
		 *******************************/

%!  applies_dmn(+KB) is semidet.
%   A timeless program with at least one rule or table.
applies_dmn(KB) :-
    le_writer:kb_to_ir(KB, program(H, Items)),
    \+ memberchk(target(lps), H),
    ( memberchk(rule(_, _, _), Items) -> true ; memberchk(table(_, _, _, _), Items) ), !.

%!  check_dmn(+KB, +Options, -Problems) is det.
%   Options: text(Doc), the program's text, places each problem on its
%   clause (at(Start, End)); without it a problem in a rule is placed on its
%   predicate.
check_dmn(KB, Options, Problems) :-
    catch(( analyse(KB, Options, _), placed_problems(Problems0),
            %  the IR does not carry LE's integrity constraints, and DMN has
            %  none: said here, not dropped
            le_import:kb_constraint_problems(KB, "DMN", CPs),
            append(Problems0, CPs, Problems) ),
          E, ( message_to_string(E, S), Problems = [problem(none, S)] )).

message_to_string(E, S) :- catch(( message_to_codes(E, [], Cs), string_codes(S, Cs) ), _, format(string(S), "~q", [E])).
message_to_codes(E, _, Cs) :- format(codes(Cs), "~q", [E]).

%!  export_dmn(+KB, +Options, -Result) is det.
export_dmn(KB, Options, Result) :-
    le_writer:kb_to_ir(KB, program(H, _)),
    ( memberchk(kb(Name0), H) -> true ; Name0 = program ),
    atomic_list_concat(Ws, ' ', Name0), atomic_list_concat(Ws, '_', Name1), atom_string(Name1, Name),
    catch(dmn_files(KB, Name, Options, DMN, Tests), error(dmn_export_refused(Ps), _), true),
    (   nonvar(Ps)
    ->  Result = refused(Ps)
    ;   split_string(Tests, "", "", [T]),
        replace_all(T, "--", "- -", TC),
        format(string(Text), "~s~n<!-- The program's scenarios as test cases of the DMN TCK (testCases.xsd). Save what follows, without this comment's first and last lines, as ~w-test-01.xml beside the model; the TCK runner (github.com/dmn-tck/tck) and most DMN engines' test tools run it.~n~s~n-->~n", [DMN, Name, TC]),
        format(atom(File), '~w.dmn', [Name]),
        Result = exported(File, Text,
                          ["One DMN 1.6 decision model: the program's values and sentences as inputs and decisions, its decision tables as DMN decision tables, its rules as FEEL expressions.",
                           "The scenarios follow the model as a test file of the DMN TCK, in a comment: save it as <name>-test-01.xml beside the model.",
                           "Checked on Apache KIE Drools 10.2: LE2 migration/dmn/dmn_roundtrip.pl exports each program and runs its tests with the TCK's runner."],
                          [link("Apache KIE DMN editor (sandbox)", "https://sandbox.kie.org")])
    ).

replace_all(S, A, B, R) :-
    atomic_list_concat(Parts, A, S), atomic_list_concat(Parts, B, R0), atom_string(R0, R).

%!  dmn_files(+KB, +Name, -DMN, -Tests) is det.
dmn_files(KB, Name, DMN, Tests) :-
    dmn_files(KB, Name, [], DMN, Tests).

%!  dmn_files(+KB, +Name, +Options, -DMN, -Tests) is det.
%   With text(Doc) in Options, the provenance comments name lines and the
%   problems' places are the clauses' own.
dmn_files(KB, Name, Options, DMN, Tests) :-
    analyse(KB, Options, model(Inputs, Decisions, BKMs, Cases)),
    placed_problems(Problems0),
    (   memberchk(checked(true), Options) -> CPs = []
    ;   le_import:kb_constraint_problems(KB, "DMN", CPs)
    ),
    append(Problems0, CPs, Problems),
    (   Problems \== [] -> throw(error(dmn_export_refused(Problems), _)) ; true ),
    model_xml(Name, Inputs, Decisions, BKMs, DMN),
    tests_xml(Name, Inputs, Decisions, Cases, Tests).

		 /*******************************
		 *           ANALYSIS           *
		 *******************************/

%   sym_(F, Kind, Info):
%     value(Name, Type)            a function `the X is *a T*`
%     sentence(Name)               a template with no place
%     list(Name, Type, Listed)     `the X include *a T*`; Listed its `are listed` functor or none
%     records(Name, Comps, Listed) `the X include *a* with *b*`: Comps = [CompName-Type]
%     listed(ListFunctor)          `the X are listed`
%     table(Table, NIn)            `... under table T`
%     lib(Key)                     a library template FEEL has a function for
%   Name: the DMN name; the role (input or decision) is concluded/1.

%   The program as it is, or, when DMN has no form for it as it is, lowered
%   to its one subject (lower_subject/2), if that has a form.
analyse(KB, Options, Model) :-
    analyse(KB, Options, false, Model0),
    (   \+ problem_(_, _) -> Model = Model0
    ;   findall(W-M, problem_(W, M), Ps0),
        (   analyse(KB, Options, true, Model1), subject_(_), \+ problem_(_, _)
        ->  Model = Model1
        ;   retractall(problem_(_, _)), forall(member(W-M, Ps0), assertz(problem_(W, M))),
            Model = Model0
        )
    ).

analyse(KB, Options, Lower, model(Inputs, Decisions, BKMs, Cases)) :-
    retractall(sym_(_, _, _)), retractall(problem_(_, _)), retractall(bkm_used_(_)),
    retractall(prov_(_, _)), retractall(row_lines_(_, _)), retractall(place_pred_(_, _)), here(none),
    retractall(table_io_(_, _)), retractall(gensym_n(_)), assertz(gensym_n(0)),
    retractall(concluded_(_)), retractall(query_(_, _)), retractall(template_text_(_, _)), retractall(req_(_)),
    retractall(original_text_(_, _)), retractall(subject_(_)), retractall(query0_(_, _)),
    %  with the program's text, each rule and fact carries source(Line, S, E)
    (   memberchk(text(Doc), Options), ( string(Doc) ; atom(Doc) )
    ->  le_writer:kb_to_ir(KB, [text(Doc)], program(Header, Items0))
    ;   Doc = none, le_writer:kb_to_ir(KB, program(Header, Items0))
    ),
    nb_setval(dmn_export_kb, KB),
    maplist(strip_at, Items0, Items1),
    forall(( member(I, Items1), ( I = function(F0, T0, _) ; I = template(F0, T0, _) ) ),
           ( atom_string(T0, TS0), assertz(original_text_(F0, TS0)) )),
    forall(member(query(Q0, G0), Items1), assertz(query0_(Q0, G0))),
    (   Lower == true, lower_subject(Items1, Items) -> true ; Items = Items1 ),
    here(none),
    (   memberchk(target(lps), Header) -> problem(none, "an LPS program: DMN has no events or actions", []) ; true ),
    findall(F-T-O, ( member(I, Items), ( I = function(F, T, O) ; I = template(F, T, O) ) ), Ts),
    forall(member(F-T-O, Ts), ( atom_string(T, TS), assertz(template_text_(F, TS)), classify(F, T, O) )),
    forall(member(query(Q, G), Items), assertz(query_(Q, G))),
    link_listed,
    findall(T, member(table(T, _, _, _), Items), Tables),
    table_infos(Items),
    table_row_lines(KB, Doc, Tables),
    %  rule(Head, Body, p(Where, Line)): where a problem in it is placed,
    %  and the line its provenance names
    findall(rule(H, B, P), ( member(rule(H, B, O), Items), item_place(H, O, P) ), Rules0),
    findall(rule(H, true, P), ( member(fact(H, O), Items), \+ ignorable_fact(H), item_place(H, O, P) ), Facts),
    append(Rules0, Facts, Rules1),
    maplist(split_disjunctive_rule, Rules1, RuleLists), append(RuleLists, Rules),
    %  (a template DMN has no form for is said once, about its predicate,
    %  by decision/6; here only a conclusion with no template of its own)
    forall(( member(rule(H, _, p(W, _)), Rules), \+ concludable(H),
             functor(H, HF, HA), \+ ( sym_(HF, K, _), K \== listed ) ),
           problem(W, "a rule concludes ~w/~w, which has no form in DMN here", [HF, HA])),
    findall(F, ( member(rule(H, _, _), Rules), functor(H, F, _) ), Concluded0), sort(Concluded0, Concluded),
    forall(member(F, Concluded), assertz(concluded_(F))),
    forall(member(F, Concluded),
           ( findall(L, ( member(rule(H, _, p(_, L)), Rules), functor(H, F, _), integer(L) ), Ls0),
             sort(Ls0, Ls), assertz(prov_(F, Ls)) )),
    findall(input(N, F, K), ( sym_(F, K, I), input_kind(K), \+ memberchk(F, Concluded), sym_name(K, I, N) ), Inputs0),
    findall(F, ( member(input(_, F, _), Inputs0) ), InFs),
    findall(D, ( member(F, Concluded), sym_(F, K, I), \+ K == listed,
                 include(rule_of(F), Rules, Rs),
                 decision(F, K, I, Rs, Items, D) ), Decisions0),
    here(none),
    used_bkms(Items, Tables, BKMs0),
    here(none),
    findall(fbkm(N, Ps, T, L, Rq), member(function(N, _, Ps, T, L, Rq), Decisions0), FBKMs),
    append(BKMs0, FBKMs, BKMs),
    forall(( member(I, Items1), ( I = template(F, T, O) ; I = function(F, T, O) ), memberchk(assumable, O) ),
           ( template_arity(T, N),
             problem(predicate(F/N), "\"~w\" may be assumed (abduction): a DMN model has no assumptions", [T]) )),
    %  a scenario is no clause of the program: the problem is placed on the
    %  rules it contradicts (left out, the value is an input the scenario
    %  gives), or on the table it gives rows of
    forall(( member(scenario(Id, SItems, _), Items1), member(Fact, SItems), ( Fact = fact(H, _) ; Fact = fact(H) ),
             functor(H, F, A), functor(H0, F, A), lowered_functor(F, LF), concluded_(LF), \+ ignorable_fact(H0) ),
           ( template_text_or(F, T), problem(predicate(F/A), "scenario ~w states \"~w\", which rules also conclude: in DMN a value is an input or a decision, not both", [Id, T]) )),
    forall(( member(scenario(Id, SItems, _), Items1), member(table(TN, _, _, _), SItems) ),
           ( ( table_predicate(TN, TPI) -> W = predicate(TPI) ; W = none ),
             problem(W, "scenario ~w gives table ~w its own rows: a DMN model has one table for every case", [Id, TN]) )),
    findall(case(Id, Fs, Es), ( member(scenario(Id, SItems, _), Items), scenario_case(Id, SItems, Fs, Es) ), Cases),
    Inputs = Inputs0, exclude(is_function, Decisions0, Decisions),
    ignore(InFs = _).

rule_of(F, rule(H, _, _)) :- functor(H, F, _).

%!  item_place(+Head, +ItemOptions, -Place) is det.
%   p(Where, Line): an IR rule's or fact's own place, at(Start, End), and
%   line; predicate(F/N) and `none` when the IR carries no source (no text
%   given, or a clause of an included resource).
item_place(H, O, p(W, L)) :-
    functor(H, F, N),
    (   is_list(O), memberchk(source(L0, S, E), O), integer(S)
    ->  W = at(S, E), ( integer(L0) -> L = L0 ; L = none ),
        ( place_pred_(W, _) -> true ; assertz(place_pred_(W, F/N)) )
    ;   W = predicate(F/N), L = none
    ).

:- dynamic place_pred_/2.      % place_pred_(at(S, E), F/N): the predicate of the clause there

%!  placed_problems(-Problems) is det.
%
%   The problems found, at most one for each clause: a partial export
%   leaves out every clause a problem names, once (le_import erases each
%   named clause, and a clause named twice cannot be erased twice). So the
%   messages about one place are joined, and a problem about a rule whose
%   predicate has a problem of its own is left to that one: the rule
%   leaves with its predicate either way.
placed_problems(Problems) :-
    findall(W-M, problem_(W, M), WMs),
    findall(PI, member(predicate(PI)-_, WMs), PIs0), sort(PIs0, PIs),
    exclude(subsumed(PIs), WMs, WMs1),
    findall(W, member(W-_, WMs1), Ws0), list_to_set(Ws0, Ws),
    findall(problem(W, M),
            ( member(W, Ws), findall(M0, member(W-M0, WMs1), Ms),
              ( W == none -> member(M, Ms) ; atomic_list_concat(Ms, '; ', MA), atom_string(MA, M) ) ),
            Problems).

subsumed(PIs, at(S, E)-_) :- place_pred_(at(S, E), PI), memberchk(PI, PIs).

%   Where the problems found from now on are placed: the rule or table
%   being translated (problem_here/2 and refuse/2 read it).
here(p(W, _)) :- !, nb_setval(dmn_here, W).
here(W) :- nb_setval(dmn_here, W).

current_here(W) :- ( catch(nb_getval(dmn_here, W0), _, fail) -> W = W0 ; W = none ).

template_arity(T, N) :- atom_string(T, S), template_places(S, Ps), length(Ps, N).

%   A table's template predicate, F/N.
table_predicate(T, F/N) :- sym_(F, table, table(T, Ps)), !, length(Ps, N).

%   The line of each of a table's rows (le_table_row/6 keeps its offsets),
%   in the order of the IR's rows; `none` where unknown (a CSV table).
table_row_lines(KB, Doc, Tables) :-
    forall(member(T, Tables),
           ( findall(L, ( current_predicate(KB:le_table_row/6),
                          KB:le_table_row(Key, _, _, _, RS, _),
                          le_tables:table_name(Key, T), Key \= in_scenario(_, _),
                          offset_line(Doc, RS, L) ), Ls),
             assertz(row_lines_(T, Ls)) )).

offset_line(Doc, S, L) :-
    (   ( string(Doc) ; atom(Doc) ), integer(S), S > 0, string_length(Doc, Len), S < Len
    ->  sub_string(Doc, 0, S, _, Before),
        aggregate_all(count, sub_string(Before, _, _, _, "\n"), NL), L is NL + 1
    ;   L = none
    ).

is_function(function(_, _, _, _, _, _)).

input_kind(value).
input_kind(sentence).
input_kind(list).
input_kind(records).

sym_name(_, I, N) :- arg(1, I, N).

strip_at(X, Y) :- var(X), !, Y = X.
strip_at(le_at(X, _, _), Y) :- !, strip_at(X, Y).
strip_at(X, Y) :- compound(X), \+ is_list(X), !, X =.. [F|As], maplist(strip_at, As, Bs), Y =.. [F|Bs].
strip_at(X, Y) :- is_list(X), !, maplist(strip_at, X, Y).
strip_at(X, X).

ignorable_fact(H) :- functor(H, F, _), memberchk(F, [le_text_at, le_published_at, le_cites]), !.
ignorable_fact(H) :- functor(H, F, 2), \+ sym_(F, _, _), arg(2, H, A), atom(A), sub_atom(A, 0, _, _, 'at '), !.   % `the text of D is at "file"`

%   The same message at two places is two problems: a partial export
%   leaves out each place.
problem(W, Fmt, Args) :-
    format(string(M), Fmt, Args),
    (   problem_(W, M) -> true ; assertz(problem_(W, M)) ).

%   A problem in the rule or table being translated (here/1).
problem_here(Fmt, Args) :- current_here(W), problem(W, Fmt, Args).

refuse(Fmt, Args) :- problem_here(Fmt, Args), fail.

%   What each template is.
classify(F, Text, Opts) :-
    atom_string(Text, T),
    template_places(T, Places),
    length(Places, NP),
    (   memberchk(included, Opts)
    ->  ( lib_template(F, Key) -> assertz(sym_(F, lib, lib(Key))) ; true )
    ;   sub_string(T, B, _, _, " under table ")
    ->  sub_string(T, B, _, 0, Tail), string_concat(" under table ", TN, Tail), atom_string(Table, TN),
        assertz(sym_(F, table, table(Table, Places)))
    ;   NP =:= 0, string_concat(Pre, " are listed", T), string_concat("the ", W, Pre)
    ->  feel_name(W, N), assertz(sym_(F, listed, listed(N)))
    ;   NP =:= 0
    ->  sentence_words(T, W), feel_name(W, N), assertz(sym_(F, sentence, sentence(N)))
    ;   NP =:= 1, string_concat(Pre, P1, T), string_concat(" is ", Place, P1), place_text(Place),
        string_concat("the ", W, Pre), \+ sub_string(W, _, _, _, "*")
    ->  feel_name(W, N), place_type(Place, Ty), assertz(sym_(F, value, value(N, Ty)))
    ;   NP =:= 1, \+ sub_string(T, _, _, _, " include "), \+ string_concat(_, " are listed", T),
        Places = [P0], place_noun(P0, PN), value_noun(PN)
    ->  %  a value whose place is not at the end: `the order of the customer
        %  weighs *a number* kg`, named by its words without the place
        Places = [Place], place_type(Place, Ty),
        format(string(Star), "*~w*", [Place]), atomic_list_concat(Ps2, Star, T), atomic_list_concat(Ps2, ' ', W1),
        normalize_space(string(W2), W1), ( string_concat("the ", W3, W2) -> true ; W3 = W2 ),
        feel_name(W3, N), assertz(sym_(F, value, value(N, Ty)))
    ;   sub_string(T, B, _, _, " include "), string_concat("the ", _, T),
        sub_string(T, 4, _, 0, W0), sub_string(W0, BW, _, _, " include "), !, sub_string(W0, 0, BW, _, W),
        \+ sub_string(W, _, _, _, "*"),
        sub_string(T, B, _, 0, After), string_concat(" include ", Rest, After),
        split_with(Rest, PlaceTexts), maplist(place_text, PlaceTexts)
    ->  feel_name(W, N),
        (   PlaceTexts = [P]
        ->  place_type(P, Ty), assertz(sym_(F, list, list(N, Ty, none)))
        ;   maplist(component, PlaceTexts, Comps), assertz(sym_(F, records, records(N, Comps, none)))
        )
    ;   NP >= 2, string_concat("the ", W0, T), sub_string(W0, B1, _, _, " *"), sub_string(W0, 0, B1, _, Pre0),
        \+ sub_string(Pre0, _, _, _, "*"), last(Places, Last), string_concat(_, "*", T),
        append(ParamPlaces, [Last], Places)
    ->  ( string_concat(Pre1, " of", Pre0) -> true ; Pre1 = Pre0 ),
        feel_name(Pre1, N0), fun_name(N0, N),
        maplist(place_param, ParamPlaces, Ps0), unique_params(Ps0, Ps),
        place_type(Last, Ty),
        assertz(sym_(F, fun, fun(N, Ps, Ty)))
    ;   assertz(sym_(F, other, other(T)))
    ).

%   A function's name, an identifier (FEEL invokes a function by its name).
fun_name(N0, N) :-
    atomic_list_concat(Ws, ' ', N0), atomic_list_concat(Ws, '_', A), atom_string(A, N).

place_param(Place, P) :-
    ( string_concat("*", P1, Place), string_concat(P2, "*", P1) -> true ; P2 = Place ),
    split_string(P2, " ", "", [_Art|Ws]), atomic_list_concat(Ws, ' ', W), feel_param(W, P).

%   A template's places, `*a number*` → "a number".
template_places(T, Ps) :-
    split_string(T, "*", "", Parts),
    findall(P, ( nth0(I, Parts, P), I mod 2 =:= 1 ), Ps).

place_text(P) :- string_concat("*", R, P), string_concat(_, "*", R).

split_with(S, Ps) :-
    atomic_list_concat(Parts, ' with ', S), maplist([A, B]>>atom_string(A, B), Parts, Ps).

place_type(Place0, Ty) :-
    ( string_concat("*", P1, Place0), string_concat(P2, "*", P1) -> true ; P2 = Place0 ),
    split_string(P2, " ", "", Ws), last(Ws, Noun0),
    ( append(_, ["truth", "value"], Ws) -> Noun = "truth value" ; Noun = Noun0 ),
    noun_type(Noun, Ty).

noun_type("number", number) :- !.
noun_type("amount", number) :- !.
noun_type("count", number) :- !.
noun_type("text", string) :- !.
noun_type("truth value", boolean) :- !.
noun_type("date", date) :- !.
noun_type(_, any).

component(Place, Name-Ty) :-
    ( string_concat("*", P1, Place), string_concat(P2, "*", P1) -> true ; P2 = Place ),
    split_string(P2, " ", "", [_Art|Ws]), atomic_list_concat(Ws, ' ', W),
    feel_name(W, Name), place_type(Place, Ty).

sentence_words(T, W) :- ( string_concat("the ", W0, T) -> W = W0 ; W = T ).

%   The `are listed` sentence of each list.
link_listed :-
    forall(( sym_(LF, listed, listed(N)), sym_(F, K, I), memberchk(K, [list, records]), arg(1, I, N) ),
           ( retract(sym_(F, K, I)), setarg(3, I, LF), assertz(sym_(F, K, I)) )).

%!  feel_name(+Words, -Name) is det.
%   A template's words as a DMN name: as they are, or joined with
%   underscores when a word is one FEEL reserves.
feel_name(W0, N) :-
    ( string(W0) -> W = W0 ; atom_string(W0, W) ),
    split_string(W, " ", " ", Ws0), exclude(==(""), Ws0, Ws),
    (   (   member(X, Ws), reserved(X)
        ;   Ws = [First|_], sub_atom(First, 0, 1, _, C), char_type(C, digit)
        )
    ->  atomic_list_concat(Ws, '_', A0),
        ( sub_atom(A0, 0, 1, _, C0), char_type(C0, digit) -> atom_concat('n_', A0, A) ; A = A0 ),
        atom_string(A, N)
    ;   atomic_list_concat(Ws, ' ', A), atom_string(A, N)
    ).

reserved(W) :- memberchk(W, ["and", "or", "not", "in", "if", "then", "else", "for", "some", "every",
                             "satisfies", "return", "between", "instance", "null", "true", "false",
                             "function", "external", "date", "time", "duration", "list", "context"]).

concludable(H) :- functor(H, F, _), sym_(F, K, _), memberchk(K, [value, sentence, list, records, fun]).

%   `A or (not A and B)`, the `otherwise` cascade, and any other disjunction
%   whose branches each give the head its value: one rule per branch, in
%   order (the first that holds decides, as DMN's `if ... else if`).
split_disjunctive_rule(rule(H, B, P), Rules) :-
    term_variables(H, HVs),
    (   HVs \== []
    ->  value_alts(B, HVs, Ds), findall(rule(H, D, P), member(D, Ds), Rules)
    ;   B = otherwise(Alts)
    ->  findall(rule(H, A, P), member(A, Alts), Rules)
    ;   Rules = [rule(H, B, P)]
    ).

%   The alternatives of a body that give the head's value: a disjunction
%   that mentions the value is split, and distributed over the conditions
%   around it (`C and (A or B)` is `C and A`, then `C and B`); any other
%   disjunction stays one condition.
value_alts(or(A, B), HVs, Ds) :- mentions(or(A, B), HVs), !,
    value_alts(A, HVs, DA), value_alts(B, HVs, DB), append(DA, DB, Ds).
value_alts(otherwise(Alts), HVs, Ds) :- !,
    maplist(value_alts_of(HVs), Alts, Dss), append(Dss, Ds).
value_alts(and(A, B), HVs, Ds) :- !,
    value_alts(A, HVs, DA), value_alts(B, HVs, DB),
    and_product(DA, DB, Ds).
value_alts(G, _, [G]).

value_alts_of(HVs, A, Ds) :- value_alts(A, HVs, Ds).

%   (not findall/3, which would copy the rule's variables apart)
and_product([], _, []).
and_product([X|Xs], Ys, Ds) :-
    and_with(Ys, X, D1), and_product(Xs, Ys, D2), append(D1, D2, Ds).
and_with([], _, []).
and_with([Y|Ys], X, [and(X, Y)|Ds]) :- and_with(Ys, X, Ds).

mentions(G, Vs) :- term_variables(G, GVs), member(V, Vs), member(W, GVs), V == W, !.

disjuncts(or(A, B), Ds) :- !, disjuncts(A, DA), disjuncts(B, DB), append(DA, DB, Ds).
disjuncts(B, [B]).

		 /*******************************
		 *    ONE SUBJECT: THE CASE     *
		 *******************************/

:- dynamic original_text_/2.   % a template's text before the lowering
:- dynamic subject_/1.         % the program's subject noun, when lowered

%!  lower_subject(+Items0, -Items) is semidet.
%
%   A program about one kind of thing (`the discount for *a customer* is
%   *a rate*`, `*a customer* is a member`), each rule about one of them,
%   becomes a decision model about one case: the subject's place leaves
%   every template (`the discount for the customer is *a rate*`), and each
%   subject a scenario names becomes a test case of its own, with the
%   scenario's other facts. Fails (and the program is analysed as it is)
%   when the program is not of that shape.
lower_subject(Items0, Items) :-
    findall(F-T, ( member(I, Items0), ( I = function(F, T0, O) ; I = template(F, T0, O) ),
                   \+ memberchk(included, O), atom_string(T0, T),
                   \+ sub_string(T, _, _, _, " under table ") ), FTs),
    %  the subject: the noun of the most places, lists left aside (a list's
    %  elements are not the subject)
    findall(N, ( member(_-T, FTs), \+ sub_string(T, _, _, _, " include "),
                 template_places(T, Ps), member(P, Ps), place_noun(P, N) ), Ns0),
    msort(Ns0, Ns1), clumped(Ns1, Counts),
    findall(C-N, ( member(N-C, Counts), \+ value_noun(N) ), CNs), CNs \== [],
    max_member(_-Subject, CNs),
    findall(F-K, ( member(F-T, FTs), template_places(T, Ps),
                   findall(I, ( nth1(I, Ps, P), place_noun(P, Subject) ), [K]) ), Lowered),
    Lowered \== [],
    %  every template: at most one place of the subject, at most one other
    forall(( member(_-T, FTs), template_places(T, Ps) ),
           ( include(is_noun(Subject), Ps, SPs), length(SPs, NS), NS =< 1,
             length(Ps, NP), NP - NS =< 1 )),
    assertz(subject_(Subject)),
    maplist(lower_item(Subject, Lowered), Items0, Items1),
    lower_scenarios(Subject, Lowered, Items1, Items).

place_noun(P0, N) :-
    ( string_concat("*", P1, P0), string_concat(P2, "*", P1) -> true ; P2 = P0 ),
    split_string(P2, " ", "", [_|Ws]), Ws \== [],
    ( append(_, ["truth", "value"], Ws) -> N = "truth value" ; last(Ws, N) ).

is_noun(S, P) :- place_noun(P, S).

value_noun(N) :- memberchk(N, ["number", "amount", "count", "text", "date", "truth value", "value", "rate", "cost",
                               "price", "percentage", "sum", "total", "fee", "age", "name", "result", "part", "year",
                               "month", "day", "score", "level", "status", "category", "type", "code", "list"]).

lowered(Lowered, F, K, F1) :- memberchk(F-K, Lowered), atom_concat(F, '_of_the_case', F1).

lower_item(S, L, function(F, T, O), function(F1, T1, O)) :- lowered(L, F, _, F1), !, lower_text(S, T, T1).
lower_item(S, L, template(F, T, O), template(F1, T1, O)) :- lowered(L, F, _, F1), !, lower_text(S, T, T1).
lower_item(_, L, rule(H, B, O), rule(H1, B1, O)) :- !,
    item_place(H, O, P), here(P),
    ( subject_var(L, H, V) -> true ; true ),
    lower_term(L, V, H, H1), lower_term(L, V, B, B1).
lower_item(_, L, fact(H, O), fact(H1, O)) :- !, item_place(H, O, P), here(P), lower_term(L, _, H, H1).
lower_item(_, L, query(Q, G), query(Q, G1)) :- !, lower_term(L, _, G, G1).
lower_item(_, _, I, I).

%   The place of the subject written as `the <subject>`.
lower_text(S, T0, T) :-
    atom_string(T0, T1),
    split_string(T1, "*", "", Parts),
    findall(X, ( nth0(I, Parts, P),
                 (   I mod 2 =:= 1, place_noun(P, S) -> format(string(X), "the ~w", [S])
                 ;   I mod 2 =:= 1 -> format(string(X), "*~w*", [P])
                 ;   X = P ) ), Xs),
    atomic_list_concat(Xs, T2), normalize_space(atom(T), T2).

subject_var(L, H, V) :- functor(H, F, _), memberchk(F-K, L), arg(K, H, V).

%   A term with every lowered literal's subject argument left out; the
%   subject must be the rule's own subject (a variable, the same one), or
%   the rule is about two things.
lower_term(_, _, X, X) :- var(X), !.
lower_term(L, V, X, Y) :- compound(X), functor(X, F, _), lowered(L, F, K, F1), !,
    arg(K, X, A),
    (   var(A), ( var(V) -> V = A ; V == A ) -> true
    ;   nonvar(A), var(V) -> true                   % a fact or a scenario's fact: its subject is a constant
    ;   problem_here("a rule about two ~ws at once (a DMN model decides one case)", [the_subject]), fail
    ),
    X =.. [_|As], nth1(K, As, _, Rest), maplist(lower_term(L, V), Rest, Rest1), Y =.. [F1|Rest1].
lower_term(L, V, X, Y) :- compound(X), \+ is_list(X), !, X =.. [F|As], maplist(lower_term(L, V), As, Bs), Y =.. [F|Bs].
lower_term(L, V, X, Y) :- is_list(X), !, maplist(lower_term(L, V), X, Y).
lower_term(_, _, X, X).

%   Each scenario as one scenario per subject it names: the subject's facts
%   and the facts about no subject; its expectations, read from the
%   answers about that subject.
lower_scenarios(S, L, Items0, Items) :-
    findall(I, ( member(I, Items0), \+ I = scenario(_, _, _) ), Rest),
    findall(scenario(Id1, SItems, []),
            ( member(scenario(Id, SI0, _), Items0),
              scenario_subjects(L, SI0, Subjects),
              member(C, Subjects),
              format(atom(Id1), '~w_~w', [Id, C]),
              subject_scenario(S, L, C, SI0, SItems) ),
            Scs),
    append(Rest, Scs, Items).

scenario_subjects(L, SI0, Subjects) :-
    findall(C, ( member(Fact, SI0), ( Fact = fact(H, _) ; Fact = fact(H) ), functor(H, F, _),
                 memberchk(F-K, L), arg(K, H, C) ), Cs1),
    findall(C, ( member(expects(Q, As, _), SI0), query_original(Q, G), functor(G, F, _), memberchk(F-K, L),
                 member(A, As), answer_args(F, A, Args), nth1(K, Args, C0), subject_constant(C0, C) ), Cs2),
    append(Cs1, Cs2, Cs0), maplist(subject_atom, Cs0, Cs3), sort(Cs3, Subjects).

subject_atom(C, A) :- ( atom(C) -> A = C ; atom_string(A, C) ).
subject_constant(S, A) :- atom_string(A, S).

:- dynamic query0_/2.

lowered_functor(F, LF) :- ( atom_concat(F, '_of_the_case', LF), sym_(LF, _, _) -> true ; LF = F ).
template_text_or(F, T) :- ( original_text_(F, T) -> true ; T = F ).
query_original(Q, G) :- query0_(Q, G), !.

subject_scenario(_, L, C, SI0, SItems) :-
    findall(fact(H1, []), ( member(Fact, SI0), ( Fact = fact(H, _) ; Fact = fact(H) ), functor(H, F, _),
                            (   memberchk(F-K, L) -> arg(K, H, C0), subject_atom(C0, C), lower_term(L, _, H, H1)
                            ;   H1 = H ) ), Facts),
    findall(expect_value(F1, Val), ( member(expects(Q, As, _), SI0), query_original(Q, G),
                                     subject_expectation(L, C, G, As, F1, Val) ), Exps),
    append(Facts, Exps, SItems).

%   What the answers say about subject C: a value (the first), or none; a
%   condition, true or false.
subject_expectation(L, C, G, As, F1, Val) :-
    functor(G, F, A), memberchk(F-K, L), lowered(L, F, K, F1),
    forall(member(Ans, As), answer_args(F, Ans, _)),      % (answers in a synonym's words: no expectation)
    findall(Args, ( member(Ans, As), answer_args(F, Ans, Args), nth1(K, Args, C0), subject_atom(C0, C) ), Mine),
    (   A =:= 1
    ->  ( Mine == [] -> Val = value(false) ; Val = value(true) )
    ;   original_noun_type(F, K, Ty),
        (   Mine = [Args1|_] -> nth1(VK, Args1, VT), VK \== K, typed_text(Ty, VT, V), Val = value(V)
        ;   Val = value(null)
        )
    ).

original_noun_type(F, K, Ty) :-
    original_text_(F, T), template_places(T, Ps),
    (   nth1(I, Ps, P), I \== K -> place_type(P, Ty) ; Ty = any ).

%   The texts in an answer's places, by the template's literal parts.
answer_args(F, A, Args) :-
    original_text_(F, T), split_string(T, "*", "", Parts),
    findall(Lit, ( nth0(I, Parts, Lit), I mod 2 =:= 0 ), Lits),
    split_by_literals(Lits, A, Args).

		 /*******************************
		 *           DECISIONS          *
		 *******************************/

%   decision(Name, F, Kind, Logic, Requires): Logic is literal(FEEL) or
%   table(Table, Hit, Ins, Outs, Rows) (a decision that is its table).
%   Each rule is translated with here/1 set to its place, so that a problem
%   in it is placed on it.
decision(F, value, value(N, Ty), Rules, Items, decision(N, F, value(Ty), Logic, Req)) :- !,
    (   Rules = [rule(H, B, P)], here(P), table_decision(H, B, Items, Logic, Req) -> true
    ;   findall(C-V, ( member(rule(H, B, P), Rules), here(P), arg(1, H, HV), rule_feel(B, HV, C, V, Req0), assertz(req_(Req0)) ), CVs),
        cascade(CVs, "null", E),
        Logic = literal(E), collect_req(Req)
    ).
decision(F, sentence, sentence(N), Rules, _, decision(N, F, value(boolean), literal(E), Req)) :- !,
    findall(C, ( member(rule(_, B, P), Rules), here(P), rule_feel(B, none, C, _, R0), assertz(req_(R0)) ), Cs),
    (   memberchk("true", Cs) -> E = "true"
    ;   atomic_list_concat(Cs, ') or (', J), format(string(E), "if (~w) then true else false", [J])
    ),
    collect_req(Req).
decision(F, list, list(N, Ty, _), Rules, Items, decision(N, F, list(Ty), Logic, Req)) :- !,
    (   Rules = [rule(H, B, P)], here(P), table_decision(H, B, Items, Logic, Req) -> true
    ;   findall(L, ( member(rule(H, B, P), Rules), here(P), arg(1, H, HV), rule_list_feel(B, HV, L, R0), assertz(req_(R0)) ), Ls),
        (   Ls = [E] -> true
        ;   atomic_list_concat(Ls, ', ', J), format(string(E), "flatten([~w])", [J])
        ),
        Logic = literal(E), collect_req(Req)
    ).
decision(F, records, records(N, Comps, _), Rules, _, decision(N, F, records(N), literal(E), Req)) :- !,
    findall(L, ( member(rule(H, B, P), Rules), here(P), H =.. [_|HVs], rule_records_feel(B, HVs, Comps, L, R0), assertz(req_(R0)) ), Ls),
    (   Ls = [E] -> true
    ;   atomic_list_concat(Ls, ', ', J), format(string(E), "flatten([~w])", [J])
    ),
    collect_req(Req).
decision(F, fun, fun(N, Ps, Ty), Rules, _, function(N, F, Ps, value(Ty), literal(E), Req)) :- !,
    findall(C-V, ( member(rule(H, B, P), Rules), here(P), H =.. [_|Args], append(PArgs, [HV], Args),
                   fun_rule_feel(PArgs, Ps, B, HV, C, V, R0), assertz(req_(R0)) ), CVs),
    cascade(CVs, "null", E),
    collect_req(Req).
decision(F, K, _, Rules, _, _) :-
    %  about the predicate as a whole: every clause of it
    ( Rules = [rule(H, _, _)|_] -> functor(H, F, N), here(predicate(F/N)) ; here(none) ),
    refuse("~w (~w) is concluded by rules, but DMN has no form for it here", [F, K]).

:- dynamic req_/1.
collect_req(Req) :-
    findall(R, ( retract(req_(Rs)), member(R, Rs) ), R0), sort(R0, Req).

%   `if C1 then V1 else if C2 then V2 else Default`, a rule that always
%   holds ending the cascade.
cascade([], D, D).
cascade([C-V|Rest], D, E) :-
    (   C == "true" -> E = V
    ;   cascade(Rest, D, E1), format(string(E), "if ~w then ~w else ~w", [C, V, E1])
    ).

%   A decision whose one rule reads values and then the table, with the
%   table's output its value: the decision table itself.
table_decision(H, B, Items, table(Table, Hit, InExprs, OutCols, Rows), Req) :-
    arg(1, H, HV),
    conj_list(B, Lits),
    append(Reads, [TG], Lits),
    functor(TG, TF, _), sym_(TF, table, table(Table, _)),
    TG =.. [_|Args],
    member(table(Table, [policy(P)|_], Cols0, Rows0), Items),
    table_columns(Table, Cols0, Rows0, Cols, Rows1),
    length(Args, NA), length(Cols, NC), NA =:= NC,
    last(Args, Out), Out == HV,
    append(InArgs, [_], Args),
    foldl(read_env, Reads, env([], []), env(Env, Req0)),
    maplist(arg_expr(Env), InArgs, InExprs),
    sort(Req0, Req),
    hit_policy(P, Hit),
    (   H =.. [HF, _], sym_(HF, list, _) -> P == all ; P \== all ),
    append(InCols, [OutCol], Cols), length(InCols, _),
    OutCols = [OutCol],
    current_here(W0),
    functor(TG, TF, TN), here(predicate(TF/TN)),         % a cell's problem is the table's
    maplist(row_cells, Rows1, Rows),
    here(W0).

read_env(L, env(E0, R0), env([X-N|E0], [N|R0])) :-
    functor(L, F, 1), sym_(F, value, value(N, _)), arg(1, L, X), var(X).

arg_expr(Env, A, E) :-
    (   var(A) -> member(V-E, Env), V == A, !
    ;   feel_constant(A, E)
    ).

hit_policy(unique, "UNIQUE").
hit_policy(first, "FIRST").
hit_policy(all, "COLLECT").

%   A table's columns without its row ids: a table with one column more
%   than its template has places names its rows in its first column.
table_columns(T, Cols0, Rows0, Cols, Rows) :-
    (   sym_(_, table, table(T, Places)), length(Places, NP), length(Cols0, NC), NC =:= NP + 1
    ->  Cols0 = [_|Cols], maplist(drop_first, Rows0, Rows)
    ;   Cols = Cols0, Rows = Rows0
    ).

drop_first([_|T], T).

row_cells(Row, Cells) :- maplist(cell_feel, Row, Cells).

%   A cell as a FEEL unary test (inputs) or expression (outputs).
cell_feel(any, "-") :- !.
cell_feel(raw(oneof(Vs)), T) :- !, maplist(feel_constant, Vs, Ts), atomic_list_concat(Ts, ', ', A), atom_string(A, T).
cell_feel(or_list(Vs), T) :- !, maplist(feel_constant, Vs, Ts), atomic_list_concat(Ts, ', ', A), atom_string(A, T).
cell_feel(cond(E), T) :- !, ( simple_test(E, T) -> true ; test_expr(E, T0), format(string(T), "~w", [T0]) ).
cell_feel(raw(R), _) :- !, refuse("a table cell DMN has no form for here: ~q", [R]).
cell_feel(V, T) :- feel_constant(V, T).

simple_test(Op-V, T) :- !, test_op(Op, O), feel_constant(V, VT), ( O == "=" -> T = VT ; format(string(T), "~w ~w", [O, VT]) ).
simple_test(or(A, B), T) :- simple_test(A, TA), simple_test(B, TB), format(string(T), "~w, ~w", [TA, TB]).

test_expr(and(A, B), T) :- !, test_expr(A, TA), test_expr(B, TB), format(string(T), "~w and ~w", [TA, TB]).
test_expr(or(A, B), T) :- !, test_expr(A, TA), test_expr(B, TB), format(string(T), "(~w or ~w)", [TA, TB]).
test_expr(Op-V, T) :- test_op(Op, O), feel_constant(V, VT), format(string(T), "? ~w ~w", [O, VT]).

test_op(>=, ">=").  test_op(=<, "<=").  test_op(<=, "<=").
test_op(>, ">").    test_op(<, "<").    test_op(=, "=").
test_op(\=, "!=").  test_op('!=', "!=").

		 /*******************************
		 *        RULES AS FEEL         *
		 *******************************/

%!  rule_feel(+Body, +HeadValue, -Condition, -Value, -Requires) is semidet.
%
%   A rule's conditions as one FEEL boolean (with a guard `x != null` for
%   every value it reads, so that a missing value fails the rule as in
%   Logical English) and the head's value as a FEEL expression.
rule_feel(Body, HV, Cond, Val, Req) :-
    conj_list(Body, Lits),
    catch(lits_feel(Lits, st([], [], [], []), st(Env, Conds, Gens, Req0)), dmn_no_form(M), ( problem_here("~w", [M]), fail )),
    sort(Req0, Req),
    (   HV == none -> Val0 = "true"
    ;   var(HV) -> ( member(V-E, Env), V == HV -> Val0 = E ; refuse("a rule whose value is not given by its conditions", []) )
    ;   feel_constant(HV, Val0)
    ),
    conds_feel(Conds, C0),
    (   Gens == [] -> Cond = C0, Val = Val0
    ;   HV \== none, var(HV)
    ->  %  a value taken from the first element that satisfies the
        %  conditions (the first answer, in the list's order)
        (   Gens = [gen(X, L)]
        ->  (   C0 == "true" -> format(string(Ls), "for ~w in ~w return ~w", [X, L, Val0])
            ;   format(string(Ls), "flatten(for ~w in ~w return if ~w then [~w] else [])", [X, L, C0, Val0])
            ),
            format(string(Cond), "count(~w) > 0", [Ls]), format(string(Val), "(~w)[1]", [Ls])
        ;   refuse("a value chosen from the elements of two lists", [])
        )
    ;   gens_some(Gens, C0, Cond), Val = Val0
    ).

%   A list decision's rule: the list of the values its rule gives, one per
%   element of the list it reads, or one when its conditions hold.
rule_list_feel(Body, HV, L, Req) :-
    conj_list(Body, Lits),
    catch(lits_feel(Lits, st([], [], [], []), st(Env, Conds, Gens, Req0)), dmn_no_form(M), ( problem_here("~w", [M]), fail )),
    sort(Req0, Req),
    (   var(HV) -> ( member(V-E, Env), V == HV -> Val = E ; refuse("a rule whose value is not given by its conditions", []) )
    ;   feel_constant(HV, Val)
    ),
    conds_feel(Conds, C),
    (   Gens == []
    ->  ( C == "true" -> format(string(L), "[~w]", [Val]) ; format(string(L), "if ~w then [~w] else []", [C, Val]) )
    ;   Gens = [gen(X, LE)]
    ->  (   C == "true", Val == X -> L = LE
        ;   C == "true" -> format(string(L), "for ~w in ~w return ~w", [X, LE, Val])
        ;   format(string(L), "flatten(for ~w in ~w return if ~w then [~w] else [])", [X, LE, C, Val])
        )
    ;   refuse("a rule that reads two lists", [])
    ).

%   A rule of a list of structures: one context per element.
rule_records_feel(Body, HVs, Comps, L, Req) :-
    conj_list(Body, Lits),
    catch(lits_feel(Lits, st([], [], [], []), st(Env, Conds, Gens, Req0)), dmn_no_form(M), ( problem_here("~w", [M]), fail )),
    sort(Req0, Req),
    findall(KV, ( nth1(I, HVs, HV), nth1(I, Comps, CN-_), comp_value(HV, Env, CV), format(string(KV), "\"~w\": ~w", [CN, CV]) ), KVs),
    atomic_list_concat(KVs, ', ', J), format(string(Ctx), "{~w}", [J]),
    conds_feel(Conds, C),
    (   Gens == []
    ->  ( C == "true" -> format(string(L), "[~w]", [Ctx]) ; format(string(L), "if ~w then [~w] else []", [C, Ctx]) )
    ;   Gens = [gen(X, LE)]
    ->  (   C == "true" -> format(string(L), "for ~w in ~w return ~w", [X, LE, Ctx])
        ;   format(string(L), "flatten(for ~w in ~w return if ~w then [~w] else [])", [X, LE, C, Ctx])
        )
    ;   refuse("a rule that reads two lists", [])
    ).

comp_value(HV, Env, CV) :-
    (   var(HV) -> ( member(V-E, Env), V == HV -> CV = E ; no_form("a rule whose value is not given by its conditions", []) )
    ;   feel_constant(HV, CV)
    ).

%   A rule of a function with places: its places are the function's
%   parameters.
fun_rule_feel(PArgs, Ps, Body, HV, Cond, Val, Req) :-
    param_env(PArgs, Ps, [], Env0, [], Conds0),
    conj_list(Body, Lits),
    catch(lits_feel(Lits, st(Env0, Conds0, [], []), st(Env, Conds, Gens, Req0)), dmn_no_form(M), ( problem_here("~w", [M]), fail )),
    sort(Req0, Req),
    (   Gens \== [] -> refuse("a function whose rule reads a list", []) ; true ),
    (   var(HV) -> ( member(V-E, Env), V == HV -> Val = E ; refuse("a rule whose value is not given by its conditions", []) )
    ;   feel_constant(HV, Val)
    ),
    conds_feel(Conds, Cond).

param_env([], [], E, E, C, C).
param_env([A|As], [P|Ps], E0, E, C0, C) :-
    (   var(A), \+ bound_in(A, E0) -> E1 = [A-P|E0], C1 = C0
    ;   expr_feel(A, E0, AF), format(string(Cnd), "~w = ~w", [P, AF]), E1 = E0, C1 = [Cnd|C0]
    ),
    param_env(As, Ps, E1, E, C1, C).

gens_some([gen(X, L)], C, S) :- !, format(string(S), "some ~w in ~w satisfies ~w", [X, L, C]).
gens_some([gen(X, L)|Gs], C, S) :- gens_some(Gs, C, S0), format(string(S), "some ~w in ~w satisfies ~w", [X, L, S0]).

conds_feel([], "true") :- !.
conds_feel(Cs0, C) :- reverse(Cs0, Cs), atomic_list_concat(Cs, ' and ', A), atom_string(A, C).

conj_list(true, []) :- !.
conj_list(and(A, B), L) :- !, conj_list(A, LA), conj_list(B, LB), append(LA, LB, L).
conj_list(G, [G]).

%   st(Env, Conds, Generators, Requires): Env pairs each variable bound so
%   far with its FEEL expression; Conds (newest first) the conditions.
lits_feel([], St, St).
lits_feel([L|Ls], St0, St) :- lit_feel(L, St0, St1), lits_feel(Ls, St1, St).

no_form(Fmt, Args) :- format(string(M), Fmt, Args), throw(dmn_no_form(M)).

lit_feel(true, St, St) :- !.
lit_feel(not(G), st(E, C, Gs, R), st(E, [NC|C], Gs, R1)) :- !,
    conj_list(G, Lits),
    lits_feel(Lits, st(E, [], [], []), st(_, C1, Gs1, R0)),
    conds_feel(C1, In0),
    ( Gs1 == [] -> In = In0 ; gens_some(Gs1, In0, In) ),
    format(string(NC), "not(~w)", [In]),
    append(R0, R, R1).
lit_feel(or(A, B), st(E, C, Gs, R), st(E, [OC|C], Gs, R2)) :- !,
    branch_feel(A, E, CA, RA), branch_feel(B, E, CB, RB),
    format(string(OC), "(~w or ~w)", [CA, CB]),
    append([RA, RB, R], R2).
lit_feel(otherwise(Alts), St0, St) :- !,
    lit_feel_or(Alts, St0, St).
lit_feel(le_assign(V, X), st(E, C, Gs, R), St) :- !,
    expr_feel(X, E, XF),
    (   var(V), \+ ( member(V0-_, E), V0 == V )
    ->  St = st([V-XF|E], C, Gs, R)
    ;   expr_feel(V, E, VF), format(string(Cnd), "~w = ~w", [VF, XF]), St = st(E, [Cnd|C], Gs, R)
    ).
lit_feel(G, st(E, C, Gs, R), St) :-
    G =.. [Cmp, A, B], cmp_op(Cmp, Op), !,
    (   memberchk(Cmp, [le_equal_to, le_is]), var(A), \+ bound_in(A, E)
    ->  expr_feel(B, E, BF), St = st([A-BF|E], C, Gs, R)
    ;   memberchk(Cmp, [le_equal_to, le_is]), var(B), \+ bound_in(B, E)
    ->  expr_feel(A, E, AF), St = st([B-AF|E], C, Gs, R)
    ;   expr_feel(A, E, AF), expr_feel(B, E, BF),
        format(string(Cnd), "~w ~w ~w", [AF, Op, BF]), St = st(E, [Cnd|C], Gs, R)
    ).
lit_feel(G, st(E, C, Gs, R), St) :-
    functor(G, F, A), sym_(F, K, I), !,
    sym_lit(K, I, G, A, st(E, C, Gs, R), St).
lit_feel(G, St0, St) :-
    G =.. [Agg, [each, var(_, X)], Goal, [var(_, Res)]], memberchk(Agg, [count, sum, min, max]), !,
    agg_feel(Agg, X, Goal, Res, St0, St).
lit_feel(G, _, _) :-
    functor(G, F, A), no_form("a condition DMN has no form for here: ~w/~w", [F, A]).

lit_feel_or([A], St0, St) :- !, lit_feel(A, St0, St).
lit_feel_or(Alts, st(E, C, Gs, R), st(E, [OC|C], Gs, R1)) :-
    findall(CA-RA, ( member(A, Alts), branch_feel(A, E, CA, RA) ), Ps),
    pairs_keys_values(Ps, Cs, Rs), append(Rs, RR), append(RR, R, R1),
    atomic_list_concat(Cs, ' or ', J), format(string(OC), "(~w)", [J]).

branch_feel(G, E, C, R) :-
    conj_list(G, Lits),
    lits_feel(Lits, st(E, [], [], []), st(_, C1, Gs, R)),
    conds_feel(C1, C0),
    ( Gs == [] -> C = C0 ; gens_some(Gs, C0, C) ).

bound_in(V, E) :- member(V0-_, E), V0 == V, !.

cmp_op(le_equal_to, "=").
cmp_op(le_is, "=").
cmp_op(le_not_equal_to, "!=").
cmp_op(le_ge, ">=").
cmp_op(le_gt, ">").
cmp_op(le_le, "<=").
cmp_op(le_lt, "<").

%   A read of a template, by its kind.
sym_lit(value, value(N, _), G, 1, st(E, C, Gs, R), St) :- !,
    arg(1, G, X),
    (   var(X), \+ bound_in(X, E)
    ->  format(string(Gd), "~w != null", [N]), St = st([X-N|E], [Gd|C], Gs, [N|R])
    ;   expr_feel(X, E, XF), format(string(Cnd), "~w = ~w", [N, XF]), St = st(E, [Cnd|C], Gs, [N|R])
    ).
sym_lit(sentence, sentence(N), _, 0, st(E, C, Gs, R), st(E, [Cnd|C], Gs, [N|R])) :- !,
    format(string(Cnd), "~w = true", [N]).
sym_lit(listed, listed(N), _, 0, st(E, C, Gs, R), st(E, [Cnd|C], Gs, [N|R])) :- !,
    format(string(Cnd), "~w != null", [N]).
sym_lit(list, list(N, _, _), G, 1, st(E, C, Gs, R), St) :- !,
    arg(1, G, X),
    (   var(X), \+ bound_in(X, E)
    ->  fresh_var(V), null_safe(N, NL), St = st([X-V|E], C, [gen(V, NL)|Gs], [N|R])
    ;   expr_feel(X, E, XF), format(string(Cnd), "list contains(~w, ~w)", [N, XF]), St = st(E, [Cnd|C], Gs, [N|R])
    ).
sym_lit(records, records(N, Comps, _), G, _, st(E, C, Gs, R), st(E1, C1, [gen(V, NL)|Gs], [N|R])) :- !,
    fresh_var(V), null_safe(N, NL), G =.. [_|Args],
    foldl(record_arg(V), Comps, Args, E-C, E1-C1).
sym_lit(table, table(T, _), G, _, St0, St) :- !,
    table_lit(T, G, St0, St).
sym_lit(lib, lib(Key), G, _, St0, St) :- !,
    lib_lit(Key, G, St0, St).
sym_lit(fun, fun(N, _, _), G, A, st(E, C, Gs, R), St) :- !,
    %  a function no rule or fact defines (only scenarios state it) would
    %  be invoked in FEEL with no business knowledge model behind it; a DMN
    %  input has no places to take it
    functor(G, F, _),
    (   concluded_(F) -> true
    ;   no_form("a condition on ~w/~w, which only scenarios state: a DMN input has no places", [F, A])
    ),
    G =.. [_|Args], append(Ins, [Out], Args),
    exprs_feel(Ins, E, InFs), atomic_list_concat(InFs, ', ', J),
    format(string(Call), "~w(~w)", [N, J]),
    (   var(Out), \+ bound_in(Out, E)
    ->  format(string(Gd), "~w != null", [Call]), St = st([Out-Call|E], [Gd|C], Gs, [N|R])
    ;   expr_feel(Out, E, OF), format(string(Cnd), "~w = ~w", [Call, OF]), St = st(E, [Cnd|C], Gs, [N|R])
    ).
sym_lit(K, _, G, _, _, _) :-
    functor(G, F, A), no_form("a condition on ~w/~w (~w) DMN has no form for here", [F, A, K]).

%   A list the case may not give (null) read as an empty list, as Logical
%   English reads a list that is not listed: FEEL's `for` and `some` stop
%   with an error on null.
null_safe(N, NL) :- format(string(NL), "(if ~w = null then [] else ~w)", [N, N]).

record_arg(V, CN-_, A, E0-C0, E-C) :-
    format(string(Fld), "~w.~w", [V, CN]),
    (   var(A), \+ bound_in(A, E0) -> E = [A-Fld|E0], C = C0
    ;   expr_feel(A, E0, AF), format(string(Cnd), "~w = ~w", [Fld, AF]), E = E0, C = [Cnd|C0]
    ).

fresh_var(V) :- retract(gensym_n(N)), N1 is N + 1, assertz(gensym_n(N1)), format(string(V), "x~w", [N1]).

%   A table read: the table's business knowledge model invoked on the
%   bound columns; its value, the unbound ones.
table_lit(T, G, st(E, C, Gs, R), St) :-
    G =.. [_|Args],
    findall(B, ( member(A, Args), ( var(A), \+ bound_in(A, E) -> B = out ; B = in ) ), Pattern),
    (   table_io_(T, P0) -> ( P0 == Pattern -> true ; no_form("table ~w is read with different inputs at different places", [T]) )
    ;   assertz(table_io_(T, Pattern))
    ),
    assertz(bkm_used_(T)),
    findall(AF, ( nth1(I, Args, A), nth1(I, Pattern, in), expr_feel(A, E, AF) ), InFs),
    atomic_list_concat(InFs, ', ', J),
    bkm_name(T, BN),
    format(string(Call), "~w(~w)", [BN, J]),
    findall(I, nth1(I, Pattern, out), OutIs),
    table_policy(T, P),
    (   P == all
    ->  (   OutIs = [OI]
        ->  nth1(OI, Args, X), fresh_var(V), St = st([X-V|E], C, [gen(V, Call)|Gs], [BN|R])
        ;   fresh_var(V),
            out_fields(OutIs, Args, T, V, XFs),
            append(XFs, E, E1), St = st(E1, C, [gen(V, Call)|Gs], [BN|R])
        )
    ;   OutIs = [OI]
    ->  nth1(OI, Args, X), format(string(Gd), "~w != null", [Call]),
        St = st([X-Call|E], [Gd|C], Gs, [BN|R])
    ;   OutIs == []
    ->  format(string(Gd), "~w != null", [Call]), St = st(E, [Gd|C], Gs, [BN|R])
    ;   out_fields(OutIs, Args, T, Call, XFs),
        format(string(Gd), "~w != null", [Call]),
        append(XFs, E, E1), St = st(E1, [Gd|C], Gs, [BN|R])
    ).

:- dynamic table_info_/3.     % table_info_(Table, Policy, ParamNames)
table_policy(T, P) :- table_info_(T, P, _), !.
table_policy(_, unique).
column_param(T, I, CN) :- table_info_(T, _, Ps), nth1(I, Ps, CN).

bkm_name(T, N) :- format(string(N), "~w_table", [T]).

%   The output columns' variables, each paired with its field of the
%   table's value (not findall/3: it would copy the variables).
out_fields([], _, _, _, []).
out_fields([OI|OIs], Args, T, Of, [X-F|XFs]) :-
    nth1(OI, Args, X), column_param(T, OI, CN), format(string(F), "~w.~w", [Of, CN]),
    out_fields(OIs, Args, T, Of, XFs).

%   An aggregate over the solutions of a goal: count, sum, min or max of
%   the list its one generator (a list, an all-matches table) gives.
agg_feel(Agg, X, Goal, Res, st(E, C, Gs, R), St) :-
    conj_list(Goal, Lits),
    lits_feel(Lits, st(E, [], [], []), st(E1, C1, Gs1, R1)),
    (   member(V-XF, E1), V == X -> true ; no_form("an aggregate whose value is not given by its conditions", []) ),
    conds_feel(C1, Cond),
    (   Gs1 = [gen(G, L)]
    ->  (   Cond == "true", XF == G -> LE = L
        ;   Cond == "true" -> format(string(LE), "for ~w in ~w return ~w", [G, L, XF])
        ;   format(string(LE), "flatten(for ~w in ~w return if ~w then [~w] else [])", [G, L, Cond, XF])
        )
    ;   Gs1 == []
    ->  format(string(LE), "if ~w then [~w] else []", [Cond, XF])
    ;   no_form("an aggregate over two lists", [])
    ),
    agg_fun(Agg, LE, AF),
    append(R1, R, R2),
    (   var(Res), \+ bound_in(Res, E) -> St = st([Res-AF|E], C, Gs, R2)
    ;   expr_feel(Res, E, RF), format(string(Cnd), "~w = ~w", [RF, AF]), St = st(E, [Cnd|C], Gs, R2)
    ).

agg_fun(count, L, F) :- format(string(F), "count(~w)", [L]).
agg_fun(sum, L, F) :- format(string(F), "(if count(~w) = 0 then 0 else sum(~w))", [L, L]).
agg_fun(min, L, F) :- format(string(F), "min(~w)", [L]).
agg_fun(max, L, F) :- format(string(F), "max(~w)", [L]).

%   An expression of a rule: arithmetic, a variable bound earlier, a
%   constant.
expr_feel(V, E, F) :- var(V), !,
    (   member(V0-F0, E), V0 == V -> F = F0 ; no_form("a value used before a condition gives it", []) ).
expr_feel(X, E, F) :- compound(X), X =.. [Op, A, B], arith(Op, O), !,
    expr_feel(A, E, AF), expr_feel(B, E, BF), format(string(F), "(~w ~w ~w)", [AF, O, BF]).
expr_feel(-(A), E, F) :- !, expr_feel(A, E, AF), format(string(F), "(-~w)", [AF]).
expr_feel(X, E, F) :- compound(X), X =.. [Fn, A], arith1(Fn, FF), !,
    expr_feel(A, E, AF), format(string(F), "~w(~w)", [FF, AF]).
expr_feel(X, E, F) :- is_list(X), !, exprs_feel(X, E, Fs), atomic_list_concat(Fs, ', ', J), format(string(F), "[~w]", [J]).
expr_feel(X, _, F) :- feel_constant(X, F), !.
expr_feel(X, _, _) :- no_form("an expression DMN has no form for here: ~q", [X]).

arith(+, "+"). arith(-, "-"). arith(*, "*"). arith(/, "/"). arith(**, "**"). arith(^, "**").
arith1(floor, "floor"). arith1(ceiling, "ceiling"). arith1(abs, "abs"). arith1(sqrt, "sqrt").
arith1(round, "round half up"). arith1(truncate, "floor").

%!  feel_constant(+Value, -FEEL) is semidet.
feel_constant(V, F) :- integer(V), !, format(string(F), "~w", [V]).
feel_constant(V, F) :- float(V), !, format(string(F), "~w", [V]).
feel_constant(V, F) :- rational(V), !, X is float(V), format(string(F), "~w", [X]).
feel_constant(date(Y, M, D), F) :- !, format(string(F), "date(\"~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+\")", [Y, M, D]).
feel_constant(true, "true") :- !.
feel_constant(false, "false") :- !.
feel_constant(null, "null") :- !.
feel_constant(V, F) :- ( string(V) ; atom(V) ), !,
    atom_string(V, S), split_string(S, "\"", "", Ps), atomic_list_concat(Ps, '\\"', Esc),
    format(string(F), "\"~w\"", [Esc]).

		 /*******************************
		 *   LIBRARY TEMPLATES AS FEEL  *
		 *******************************/

%   The templates of LE2's libraries that are FEEL's built-in functions.
lib_template(the_date_written_as_is, date_text).
lib_template(the_date_of_year_month_day_is, date_ymd).
lib_template(the_year_of_is, year).
lib_template(the_month_of_is, month).
lib_template(the_day_of_the_month_of_is, day).
lib_template(the_number_of_whole_years_from_to_is, whole_years).
lib_template(today_is, today).
lib_template(the_power_of_to_is, power).
lib_template(the_rounding_of_to_decimals_half_even_is, decimal).
lib_template(the_count_of_the_list_is, count).
lib_template(the_item_at_position_of_the_list_is, item).
lib_template(contains, contains).
lib_template(the_joining_of_is, join).
lib_template(is_calendar_months_after, months_after).
lib_template(the_absolute_value_of_is, abs).
lib_template(the_square_root_of_is, sqrt).
lib_template(the_upper_case_of_is, upper).
lib_template(the_lower_case_of_is, lower).

%   A library template's call: its last place is its value (a function of
%   the others), or, for a test (contains), a condition.
lib_lit(Key, G, st(E, C, Gs, R), St) :-
    G =.. [_|Args],
    (   Key == contains
    ->  exprs_feel(Args, E, [T, P]),
        format(string(Cnd), "contains(~w, ~w)", [T, P]), St = st(E, [Cnd|C], Gs, R)
    ;   Key == months_after
    ->  Args = [Later, N, D],
        expr_feel(N, E, NF), expr_feel(D, E, DF),
        format(string(X), "(~w + duration(\"P\" + string(~w) + \"M\"))", [DF, NF]),
        bind_or_test(Later, X, st(E, C, Gs, R), St)
    ;   append(Ins, [Out], Args),
        exprs_feel(Ins, E, InFs),
        lib_feel(Key, InFs, X),
        bind_or_test(Out, X, st(E, C, Gs, R), St)
    ).

exprs_feel([], _, []).
exprs_feel([A|As], E, [F|Fs]) :- expr_feel(A, E, F), exprs_feel(As, E, Fs).

bind_or_test(V, X, st(E, C, Gs, R), St) :-
    (   var(V), \+ bound_in(V, E) -> St = st([V-X|E], C, Gs, R)
    ;   expr_feel(V, E, VF), format(string(Cnd), "~w = ~w", [VF, X]), St = st(E, [Cnd|C], Gs, R)
    ).

lib_feel(date_text, [T], X) :- format(string(X), "date(~w)", [T]).
lib_feel(date_ymd, [Y, M, D], X) :- format(string(X), "date(~w, ~w, ~w)", [Y, M, D]).
lib_feel(year, [D], X) :- format(string(X), "~w.year", [D]).
lib_feel(month, [D], X) :- format(string(X), "~w.month", [D]).
lib_feel(day, [D], X) :- format(string(X), "~w.day", [D]).
lib_feel(whole_years, [A, B], X) :- format(string(X), "years and months duration(~w, ~w).years", [A, B]).
lib_feel(today, [], "today()").
lib_feel(power, [A, B], X) :- format(string(X), "(~w ** ~w)", [A, B]).
lib_feel(decimal, [N, S], X) :- format(string(X), "decimal(~w, ~w)", [N, S]).
lib_feel(count, [L], X) :- format(string(X), "count(~w)", [L]).
lib_feel(join, [L], X) :- format(string(X), "string join(~w)", [L]).
lib_feel(item, [P, L], X) :- format(string(X), "~w[~w]", [L, P]).
lib_feel(abs, [A], X) :- format(string(X), "abs(~w)", [A]).
lib_feel(sqrt, [A], X) :- format(string(X), "sqrt(~w)", [A]).
lib_feel(upper, [A], X) :- format(string(X), "upper case(~w)", [A]).
lib_feel(lower, [A], X) :- format(string(X), "lower case(~w)", [A]).

		 /*******************************
		 *    TABLES AS BUSINESS        *
		 *    KNOWLEDGE MODELS          *
		 *******************************/

%   bkm(Name, Params, Hit, OutCols, Rows): each table a rule invokes.
table_infos(Items) :-
    retractall(table_info_(_, _, _)),
    forall(( member(table(T, [policy(P)|_], Cols0, Rows0), Items), table_columns(T, Cols0, Rows0, Cols, _) ),
           ( maplist(feel_param, Cols, Ps0), unique_params(Ps0, Ps),
             assertz(table_info_(T, P, Ps)) )).

used_bkms(Items, _Tables, BKMs) :-
    findall(bkm(T, Ins, Hit, Outs, Rows),
            ( bkm_used_(T), \+ ( bkm_used_(T2), T2 @< T, T2 == T ),
              member(table(T, [policy(P)|_], Cols0, Rows0), Items),
              table_columns(T, Cols0, Rows0, _, Rows1),
              table_info_(T, P, Params),
              table_io_(T, Pattern),
              findall(N, ( nth1(I, Params, N), nth1(I, Pattern, in) ), Ins),
              findall(I-N, ( nth1(I, Params, N), nth1(I, Pattern, out) ), Outs),
              hit_policy(P, Hit),
              ( table_predicate(T, TPI) -> here(predicate(TPI)) ; here(none) ),
              maplist(row_cells, Rows1, Rows) ),
            BKMs0),
    sort(BKMs0, BKMs).

feel_param(C, N) :-
    format(string(S), "~w", [C]),
    split_string(S, " ", " ", Ws0), exclude(==(""), Ws0, Ws),
    atomic_list_concat(Ws, '_', A0),
    atom_codes(A0, Cs0), include([X]>>code_type(X, csym), Cs0, Cs1),
    ( Cs1 = [D|_], code_type(D, digit) -> Cs = [0'p, 0'_|Cs1] ; Cs = Cs1 ),
    atom_codes(A, Cs), atom_string(A, N0),
    ( reserved(N0) -> string_concat(N0, "_", N) ; N = N0 ).

unique_params(Ps0, Ps) :- foldl(uniq_param, Ps0, []-[], _-Rev), reverse(Rev, Ps).
uniq_param(P, Seen-Acc, [Q|Seen]-[Q|Acc]) :-
    (   memberchk(P, Seen) -> between(2, 99, K), format(string(Q), "~w_~w", [P, K]), \+ memberchk(Q, Seen), !
    ;   Q = P
    ).

		 /*******************************
		 *           SCENARIOS          *
		 *******************************/

%   A scenario as a test case: input values by DMN name, expected results.
scenario_case(Id, SItems, Inputs, Expected) :-
    findall(F-V, ( member(Fact, SItems), ( Fact = fact(H, _) ; Fact = fact(H) ), fact_value(H, F, V) ), FVs),
    findall(N-Val, input_value(FVs, N, Val), Inputs0), sort(1, @<, Inputs0, Inputs),
    findall(e(N, Val), ( member(expects(Q, Answers, _), SItems), expected(Q, Answers, N, Val0),
                         in_program_order(Id, Q, Val0, Val) ), Expected0),
    findall(e(N, Val), ( member(expect_value(F, Val), SItems), sym_(F, _, I), arg(1, I, N) ), Expected1),
    append(Expected0, Expected1, Expected).

%   A Logical English expectation of several answers is a set; a DMN list
%   is in order. The expected elements are put in the order the program
%   itself gives them in the scenario (its rows' order, which DMN's COLLECT
%   keeps), when the program gives the same elements.
in_program_order(Id, Q, Val0, Val) :-
    (   ( Val0 = list(Vs0) ; Val0 = records(_, Vs0) ), Vs0 = [_, _|_],
        nb_current(dmn_export_kb, KB), query_goal(Q, G0),
        catch(( le_kbs:createSession(KB, SM),
                findall(G, ( copy_term(G0, G), le_kbs:queryScenario(SM, Id, G, _, _, _) ), Gs),
                le_kbs:destroySession(SM) ), _, fail),
        maplist(goal_values(Val0), Gs, Vs1),
        msort(Vs1, S1), msort(Vs0, S0), same_values(S0, S1)
    ->  ( Val0 = list(_) -> Val = list(Vs1) ; Val0 = records(Cs, _), Val = records(Cs, Vs1) )
    ;   Val = Val0
    ).

goal_values(list(_), G, V) :- arg(1, G, V0), value_of(V0, V).
goal_values(records(_, _), G, Vs) :- G =.. [_|Vs0], maplist(value_of, Vs0, Vs).

value_of(V0, V) :- ( atom(V0), \+ memberchk(V0, [true, false, null]) -> atom_string(V0, V) ; V = V0 ).

same_values([], []).
same_values([A|As], [B|Bs]) :- same_value(A, B), same_values(As, Bs).
same_value(A, B) :- is_list(A), is_list(B), !, same_values(A, B).
same_value(A, B) :- number(A), number(B), !, A =:= B.
same_value(A, B) :- ( string(A) ; atom(A) ), ( string(B) ; atom(B) ), !, atom_string(A, S), atom_string(B, S).
same_value(A, B) :- A == B.

fact_value(H, F, V) :-
    functor(H, F, A), sym_(F, K, _),
    (   K == value, A =:= 1 -> arg(1, H, V)
    ;   K == sentence -> V = true
    ;   K == list -> arg(1, H, V)
    ;   K == records -> H =.. [_|V]
    ;   K == listed -> V = listed
    ).

%   Every input the scenario states; a sentence it does not state is false.
input_value(FVs, N, Val) :-
    sym_(F, K, I), arg(1, I, N), input_kind(K), \+ concluded_by_rules(F),
    (   K == value -> ( memberchk(F-V, FVs) -> Val = value(V) ; Val = value(null) )
    ;   K == sentence -> ( memberchk(F-true, FVs) -> Val = value(true) ; Val = value(false) )
    ;   K == list -> arg(3, I, LF), findall(V, member(F-V, FVs), Vs),
        ( Vs \== [] -> Val = list(Vs) ; LF \== none, memberchk(LF-listed, FVs) -> Val = list([]) ; Val = value(null) )
    ;   K == records -> arg(2, I, Comps), arg(3, I, LF), findall(V, member(F-V, FVs), Rs),
        (   ( Rs \== [] ; LF \== none, memberchk(LF-listed, FVs) ) -> Val = records(Comps, Rs)
        ;   Val = value(null)
        )
    ).

:- dynamic concluded_/1.
concluded_by_rules(F) :- concluded_(F).

%   An expectation: the query's template, its answers' values.
expected(Q, Answers, N, Val) :-
    query_goal(Q, G), functor(G, F, _), sym_(F, K, I), arg(1, I, N),
    (   K == value -> arg(2, I, Ty),
        ( Answers = [A|_] -> answer_value(A, F, Ty, V), Val = value(V) ; Val = value(null) )
    ;   K == sentence -> ( Answers == [] -> Val = value(false) ; forall(member(A, Answers), template_text(F, A)), Val = value(true) )
    ;   K == list -> arg(2, I, Ty), answer_values(Answers, F, Ty, Vs), Val = list(Vs)
    ;   K == records -> arg(2, I, Comps), answer_records(Answers, F, Comps, Rs), Val = records(Comps, Rs)
    ).

answer_records([], _, _, []).
answer_records([A|As], F, Comps, [R|Rs]) :-
    template_text(F, T), split_string(T, "*", "", Parts),
    findall(Lit, ( nth0(I, Parts, Lit), I mod 2 =:= 0 ), Lits),
    split_by_literals(Lits, A, Texts),
    findall(V, ( nth1(K, Texts, Tx), nth1(K, Comps, _-Ty), typed_text(Ty, Tx, V) ), R),
    answer_records(As, F, Comps, Rs).

%   The texts between a template's literal parts in an answer.
split_by_literals([First|Rest], A, Texts) :-
    string_concat(First, A1, A), between_lits(Rest, A1, Texts).
between_lits([""], A, [A]) :- !.
between_lits([], "", []) :- !.
between_lits([Lit|Rest], A, [T|Ts]) :-
    sub_string(A, B, _, _, Lit), sub_string(A, 0, B, _, T), string_length(Lit, LL), B2 is B + LL,
    sub_string(A, B2, _, 0, A2), !, between_lits(Rest, A2, Ts).

:- dynamic query_/2.
query_goal(Q, G) :- query_(Q, G), !.

answer_values([], _, _, []).
answer_values([A|As], F, Ty, [V|Vs]) :- answer_value(A, F, Ty, V), answer_values(As, F, Ty, Vs).

%   The value in an expected answer: the answer is the template with its
%   place filled, as the editor writes it ("the approval status is Approved").
answer_value(A, F, Ty, V) :-
    template_text(F, T),
    split_string(T, "*", "", [Pre|_]),
    (   string_concat(Pre, Rest, A) -> true ; sub_string(A, B, _, 0, _), sub_string(A, 0, B, _, P0), string_lower(P0, L), string_lower(Pre, L), sub_string(A, B, _, 0, Rest) ),
    typed_text(Ty, Rest, V).

:- dynamic template_text_/2.
template_text(F, T) :- template_text_(F, T), !.

typed_text(number, S, V) :- number_string(V, S), !.
typed_text(boolean, "true", true) :- !.
typed_text(boolean, "false", false) :- !.
typed_text(date, S, date(Y, M, D)) :- split_string(S, "-", "", [Ys, Ms, Ds]), maplist(number_string, [Y, M, D], [Ys, Ms, Ds]), !.
typed_text(any, S, V) :- ( number_string(V, S) -> true ; S == "true" -> V = true ; S == "false" -> V = false ; typed_text(date, S, V) -> true ; V = S ), !.
typed_text(_, S, S).

		 /*******************************
		 *            WRITING           *
		 *******************************/

model_xml(Name, Inputs, Decisions, BKMs, XML) :-
    id_of(Name, "defs", DefId),
    model_ns(Name, NS),
    with_output_to(string(XML), (
        format("<?xml version=\"1.0\" encoding=\"UTF-8\"?>~n"),
        format("<definitions xmlns=\"https://www.omg.org/spec/DMN/20240513/MODEL/\" id=\"~w\" name=\"~w\" namespace=\"~w\"~n", [DefId, Name, NS]),
        format("             expressionLanguage=\"https://www.omg.org/spec/DMN/20240513/FEEL/\" typeLanguage=\"https://www.omg.org/spec/DMN/20240513/FEEL/\"~n"),
        format("             exporter=\"Logical English (LE2 migration/dmn)\" exporterVersion=\"1\">~n"),
        format("  <description>Written from the Logical English program ~w.</description>~n", [Name]),
        item_definitions(Inputs, Decisions),
        forall(member(I, Inputs), input_xml(I)),
        forall(member(D, Decisions), decision_xml(Inputs, Decisions, BKMs, D)),
        forall(member(B, BKMs), bkm_xml(BKMs, B)),
        format("</definitions>~n") )).

model_ns(Name, NS) :- format(string(NS), "https://logicalenglish.org/dmn/~w", [Name]).

id_of(Prefix, X, Id) :-
    format(string(S), "~w/~w", [Prefix, X]), sha_hash(S, H, []), hash_atom(H, Hex),
    sub_atom(Hex, 0, 12, _, Short), format(string(Id), "_~w", [Short]).

xml_text(S0, S) :-
    ( string(S0) -> S1 = S0 ; format(string(S1), "~w", [S0]) ),
    split_string(S1, "&", "", P1), atomic_list_concat(P1, '&amp;', A1),
    atomic_list_concat(P2, '<', A1), atomic_list_concat(P2, '&lt;', A2),
    atomic_list_concat(P3, '>', A2), atomic_list_concat(P3, '&gt;', A3),
    atomic_list_concat(P4, '"', A3), atomic_list_concat(P4, '&quot;', A4),
    atom_string(A4, S).

type_ref(value(any), "") :- !.
type_ref(value(T), R) :- !, atom_string(T, R).
type_ref(list(T), R) :- !, format(string(R), "tList_~w", [T]).
type_ref(records(N), R) :- !, type_name(N, R0), format(string(R), "tList_~w", [R0]).
type_ref(_, "").

type_name(N, T) :- atom_codes(N, Cs0), include([C]>>code_type(C, csym), Cs0, Cs), atom_codes(A, Cs), atom_string(A, T).

typeref_attr(T) :- ( T == "" -> true ; xml_text(T, X), format(" typeRef=\"~w\"", [X]) ).

item_definitions(Inputs, Decisions) :-
    findall(T, ( member(input(N, F, list), Inputs), sym_(F, list, list(N, T, _))
               ; member(decision(_, _, list(T), _, _), Decisions) ), Ts0), sort(Ts0, Ts),
    forall(member(T, Ts),
           ( format(string(TN), "tList_~w", [T]), id_of(TN, item, Id),
             ( T == any -> format("  <itemDefinition id=\"~w\" name=\"~w\" isCollection=\"true\"/>~n", [Id, TN])
             ; format("  <itemDefinition id=\"~w\" name=\"~w\" isCollection=\"true\">~n    <typeRef>~w</typeRef>~n  </itemDefinition>~n", [Id, TN, T]) ) )),
    forall(( ( member(input(N, F, records), Inputs) ; member(decision(N, F, records(_), _, _), Decisions) ),
             sym_(F, records, records(N, Comps, _)) ),
           ( type_name(N, TN0), format(string(TN), "tList_~w", [TN0]), id_of(TN, item, Id),
             format("  <itemDefinition id=\"~w\" name=\"~w\" isCollection=\"true\">~n", [Id, TN]),
             forall(member(CN-CT, Comps),
                    ( id_of(TN, CN, CId), xml_text(CN, CX),
                      ( CT == any -> format("    <itemComponent id=\"~w\" name=\"~w\"/>~n", [CId, CX])
                      ; format("    <itemComponent id=\"~w\" name=\"~w\"><typeRef>~w</typeRef></itemComponent>~n", [CId, CX, CT]) ) )),
             format("  </itemDefinition>~n") )).

input_xml(input(N, F, K)) :-
    sym_(F, K, I),
    (   K == value -> arg(2, I, Ty), type_ref(value(Ty), T)
    ;   K == sentence -> T = "boolean"
    ;   K == list -> arg(2, I, Ty), type_ref(list(Ty), T)
    ;   K == records -> type_ref(records(N), T)
    ),
    id_of(input, N, Id), xml_text(N, NX),
    format("  <inputData id=\"~w\" name=\"~w\">~n    <variable name=\"~w\"", [Id, NX, NX]), typeref_attr(T), format("/>~n  </inputData>~n").

decision_xml(Inputs, Decisions, BKMs, decision(N, F, Type, Logic, Req)) :-
    id_of(decision, N, Id), xml_text(N, NX),
    type_ref(Type, T),
    format("  <decision id=\"~w\" name=\"~w\">~n", [Id, NX]),
    provenance_xml(F, 4),
    format("    <variable name=\"~w\"", [NX]), typeref_attr(T), format("/>~n"),
    forall(( member(R, Req), member(input(R, _, _), Inputs) ),
           ( id_of(input, R, RId), id_of(Id, RId, IRId), format("    <informationRequirement id=\"~w\"><requiredInput href=\"#~w\"/></informationRequirement>~n", [IRId, RId]) )),
    forall(( member(R, Req), R \== N, member(decision(R, _, _, _, _), Decisions) ),
           ( id_of(decision, R, RId), id_of(Id, RId, IRId), format("    <informationRequirement id=\"~w\"><requiredDecision href=\"#~w\"/></informationRequirement>~n", [IRId, RId]) )),
    forall(( member(R, Req), member(fbkm(R, _, _, _, _), BKMs) ),
           ( id_of(bkm, R, RId), id_of(Id, RId, KRId), format("    <knowledgeRequirement id=\"~w\"><requiredKnowledge href=\"#~w\"/></knowledgeRequirement>~n", [KRId, RId]) )),
    forall(( member(R, Req), member(bkm(Tb, _, _, _, _), BKMs), bkm_name(Tb, R) ),
           ( id_of(bkm, Tb, RId), id_of(Id, RId, KRId), format("    <knowledgeRequirement id=\"~w\"><requiredKnowledge href=\"#~w\"/></knowledgeRequirement>~n", [KRId, RId]) )),
    logic_xml(Id, T, Logic),
    format("  </decision>~n").

logic_xml(Id, T, literal(E)) :- !,
    id_of(Id, lit, LId), xml_text(E, EX),
    format("    <literalExpression id=\"~w\"", [LId]), typeref_attr(T), format(">~n      <text>~w</text>~n    </literalExpression>~n", [EX]).
logic_xml(Id, _, table(Table, Hit, InExprs, [OutCol], Rows)) :-
    id_of(Id, table, TId),
    format("    <decisionTable id=\"~w\" hitPolicy=\"~w\">~n", [TId, Hit]),
    forall(nth1(I, InExprs, E),
           ( id_of(TId, in-I, IId), xml_text(E, EX),
             format("      <input id=\"~w\" label=\"~w\"><inputExpression id=\"~w_e\"><text>~w</text></inputExpression></input>~n", [IId, EX, IId, EX]) )),
    id_of(TId, out, OId), format(string(OC), "~w", [OutCol]), xml_text(OC, OCX),
    format("      <output id=\"~w\" name=\"~w\"/>~n", [OId, OCX]),
    rows_xml(Table, TId, Rows),
    format("    </decisionTable>~n").

rows_xml(Table, TId, Rows) :-
    forall(nth1(R, Rows, Cells),
           ( id_of(TId, row-R, RId),
             format("      <rule id=\"~w\">~n", [RId]),
             row_provenance_xml(Table, R, 8),
             length(Cells, NC), NI is NC - 1,
             forall(nth1(C, Cells, Cell),
                    ( xml_text(Cell, CX), id_of(RId, C, CId),
                      ( C =< NI -> Tag = inputEntry ; Tag = outputEntry ),
                      format("        <~w id=\"~w\"><text>~w</text></~w>~n", [Tag, CId, CX, Tag]) )),
             format("      </rule>~n") )).

%   (DMN's order: the encapsulated logic, then the knowledge requirements)
bkm_xml(BKMs, fbkm(N, Ps, Type, literal(E), Req)) :- !,
    id_of(bkm, N, Id), xml_text(N, NX),
    format("  <businessKnowledgeModel id=\"~w\" name=\"~w\">~n", [Id, NX]),
    ( sym_(F, fun, fun(N, _, _)) -> provenance_xml(F, 4) ; true ),
    format("    <variable name=\"~w\"/>~n", [NX]),
    id_of(Id, fn, FId),
    format("    <encapsulatedLogic id=\"~w\" kind=\"FEEL\">~n", [FId]),
    forall(member(P, Ps), ( id_of(FId, P, PId), format("      <formalParameter id=\"~w\" name=\"~w\"/>~n", [PId, P]) )),
    type_ref(Type, T), id_of(FId, lit, LId), xml_text(E, EX),
    format("      <literalExpression id=\"~w\"", [LId]), typeref_attr(T), format(">~n        <text>~w</text>~n      </literalExpression>~n", [EX]),
    format("    </encapsulatedLogic>~n"),
    forall(( member(R, Req), R \== N, member(fbkm(R, _, _, _, _), BKMs) ),
           ( id_of(bkm, R, RId), id_of(Id, RId, KRId), format("    <knowledgeRequirement id=\"~w\"><requiredKnowledge href=\"#~w\"/></knowledgeRequirement>~n", [KRId, RId]) )),
    forall(( member(R, Req), member(bkm(Tb, _, _, _, _), BKMs), bkm_name(Tb, R) ),
           ( id_of(bkm, Tb, RId), id_of(Id, RId, KRId), format("    <knowledgeRequirement id=\"~w\"><requiredKnowledge href=\"#~w\"/></knowledgeRequirement>~n", [KRId, RId]) )),
    format("  </businessKnowledgeModel>~n").

%   A table's business knowledge model: its inputs the parameters, its
%   outputs a value (one) or a context (several).
bkm_xml(_, bkm(T, Ins, Hit, Outs, Rows)) :-
    id_of(bkm, T, Id), bkm_name(T, BN),
    format("  <businessKnowledgeModel id=\"~w\" name=\"~w\">~n", [Id, BN]),
    table_provenance_xml(T, 4),
    format("    <variable name=\"~w\"/>~n", [BN]),
    id_of(Id, fn, FId),
    format("    <encapsulatedLogic id=\"~w\" kind=\"FEEL\">~n", [FId]),
    forall(member(P, Ins), ( id_of(FId, P, PId), format("      <formalParameter id=\"~w\" name=\"~w\"/>~n", [PId, P]) )),
    id_of(FId, table, TId),
    format("      <decisionTable id=\"~w\" hitPolicy=\"~w\">~n", [TId, Hit]),
    forall(nth1(I, Ins, P), ( id_of(TId, in-I, IId), format("        <input id=\"~w\" label=\"~w\"><inputExpression id=\"~w_e\"><text>~w</text></inputExpression></input>~n", [IId, P, IId, P]) )),
    forall(member(_-ON, Outs), ( id_of(TId, out-ON, OId), format("        <output id=\"~w\" name=\"~w\"/>~n", [OId, ON]) )),
    findall(OI, member(OI-_, Outs), OIs),
    length(Ins, NI0), _ = NI0,
    forall(nth1(R, Rows, Cells0),
           ( findall(C, ( nth1(K, Cells0, C), \+ memberchk(K, OIs) ), InCells),
             findall(C, ( member(K, OIs), nth1(K, Cells0, C) ), OutCells),
             id_of(TId, row-R, RId),
             format("        <rule id=\"~w\">~n", [RId]),
             row_provenance_xml(T, R, 10),
             forall(nth1(K, InCells, Cell), ( xml_text(Cell, CX), id_of(RId, in-K, CId), format("          <inputEntry id=\"~w\"><text>~w</text></inputEntry>~n", [CId, CX]) )),
             forall(nth1(K, OutCells, Cell), ( output_cell(Cell, OC), xml_text(OC, CX), id_of(RId, out-K, CId), format("          <outputEntry id=\"~w\"><text>~w</text></outputEntry>~n", [CId, CX]) )),
             format("        </rule>~n") )),
    format("      </decisionTable>~n    </encapsulatedLogic>~n  </businessKnowledgeModel>~n").

%   Provenance: a DMNElement's own <description> (the first thing in it, in
%   DMN's order), which these elements otherwise lack. A decision's FEEL
%   merges all its rules and facts: every line is named.
provenance_xml(F, In) :-
    (   prov_(F, Ls), Ls \== []
    ->  lines_text(Ls, T), tab(In), format("<description>Logical English ~w</description>~n", [T])
    ;   true
    ).

%   A table's model: the lines of its rows.
table_provenance_xml(T, In) :-
    (   row_lines_(T, Ls0), include(integer, Ls0, Ls1), sort(Ls1, Ls), Ls = [First|_]
    ->  last(Ls, Last),
        (   First == Last -> format(string(X), "line ~w", [First])
        ;   format(string(X), "lines ~w to ~w", [First, Last])
        ),
        xml_text(T, TX), tab(In), format("<description>Logical English ~w, table ~w</description>~n", [X, TX])
    ;   true
    ).

%   A decision table's rule R: its row's line.
row_provenance_xml(T, R, In) :-
    (   row_lines_(T, Ls), nth1(R, Ls, L), integer(L)
    ->  tab(In), format("<description>Logical English line ~w</description>~n", [L])
    ;   true
    ).

lines_text([L], T) :- !, format(string(T), "line ~w", [L]).
lines_text(Ls, T) :-
    append(Init, [Last], Ls), atomic_list_concat(Init, ', ', I),
    format(string(T), "lines ~w and ~w", [I, Last]).

output_cell("-", "null") :- !.
output_cell(C, C).

		 /*******************************
		 *        THE TEST CASES        *
		 *******************************/

tests_xml(Name, _Inputs, Decisions, Cases, XML) :-
    with_output_to(string(XML), (
        format("<?xml version=\"1.0\" encoding=\"UTF-8\"?>~n"),
        format("<testCases xmlns=\"http://www.omg.org/spec/DMN/20160719/testcase\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">~n"),
        format("  <modelName>~w.dmn</modelName>~n", [Name]),
        forall(member(case(Id, Ins, Es), Cases), case_xml(Decisions, Id, Ins, Es)),
        format("</testCases>~n") )).

expects_decision(Decisions, e(N, _)) :- memberchk(decision(N, _, _, _, _), Decisions).

case_xml(Decisions, Id, Ins, Es) :-
    include(expects_decision(Decisions), Es, Es1),
    (   Es1 == [] -> true
    ;   xml_text(Id, IdX),
        format("  <testCase id=\"~w\">~n", [IdX]),
        forall(member(N-V, Ins), ( xml_text(N, NX), format("    <inputNode name=\"~w\">~n", [NX]), value_xml(V, 6), format("    </inputNode>~n") )),
        forall(member(e(N, V), Es1), ( xml_text(N, NX), format("    <resultNode name=\"~w\" type=\"decision\">~n      <expected>~n", [NX]), value_xml(V, 8), format("      </expected>~n    </resultNode>~n") )),
        format("  </testCase>~n")
    ).

value_xml(value(V), In) :- !, scalar_xml(V, In).
value_xml(list(Vs), In) :- !,
    tab(In), format("<list>~n"), In2 is In + 2,
    forall(member(V, Vs), ( tab(In2), format("<item>~n"), In4 is In2 + 2, scalar_xml(V, In4), tab(In2), format("</item>~n") )),
    tab(In), format("</list>~n").
value_xml(records(Comps, Rs), In) :- !,
    tab(In), format("<list>~n"), In2 is In + 2, In4 is In + 4, In6 is In + 6,
    forall(member(R, Rs), ( tab(In2), format("<item>~n"),
        forall(nth1(K, Comps, CN-_), ( nth1(K, R, V), xml_text(CN, CX), tab(In4), format("<component name=\"~w\">~n", [CX]), scalar_xml(V, In6), tab(In4), format("</component>~n") )),
        tab(In2), format("</item>~n") )),
    tab(In), format("</list>~n").

scalar_xml(null, In) :- !, tab(In), format("<value xsi:nil=\"true\"/>~n").
scalar_xml(V, In) :- integer(V), !, tab(In), format("<value xsi:type=\"xsd:decimal\">~w</value>~n", [V]).
scalar_xml(V, In) :- number(V), !, X is float(V), tab(In), format("<value xsi:type=\"xsd:decimal\">~w</value>~n", [X]).
scalar_xml(true, In) :- !, tab(In), format("<value xsi:type=\"xsd:boolean\">true</value>~n").
scalar_xml(false, In) :- !, tab(In), format("<value xsi:type=\"xsd:boolean\">false</value>~n").
scalar_xml(date(Y, M, D), In) :- !, tab(In), format("<value xsi:type=\"xsd:date\">~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+</value>~n", [Y, M, D]).
scalar_xml(V, In) :- xml_text(V, X), tab(In), format("<value xsi:type=\"xsd:string\">~w</value>~n", [X]).

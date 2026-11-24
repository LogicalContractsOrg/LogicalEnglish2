/** <module> The OIA model -> Migration IR, ledger and source tests

    The mapping of the design notes roadmap.md §5.1, as
    implemented (README.md has the table). Input: oia_reader.pl's model and
    the project's Excel test files (oia_tests.py). Output: a le_migration
    migration(Meta, IR, Ledger, Tests) term, written by write_migration/4.

    Everything the translator does is deterministic. What it cannot map is
    residue (a `% RESIDUE` block holding the rule's XML, for the Contract
    Assistant's residue mode); what it maps with a change of meaning is
    `approximated` in the ledger — above all OIA's three-valued logic, read
    here with LE's closed world (an unknown input is false, `unknown`
    results and `false` ones both give no answer).
*/

:- module(oia_ir, [
    oia_migration/4,             % +Model, +TestFiles, +Options, -Migration
    oia_adapter_map/3,           % +Model, +Options, -Dict   (after oia_migration/4)
    oia_load_tests/2,            % +XlsxFiles, -Sheets
    oia_sanitize/2,              % +Text, -LEText
    oia_negation/3               % +Text, +Forms, -Negative
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(process)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(readutil)).
:- use_module(oia_reader).
:- use_module(oia_analysis).
:- use_module(oia_assess, []).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer)).

:- dynamic tpl/4.          % tpl(Key, Functor, Kind, Text)   Kind boolean|value|uncertain|opposite|error|table|current_date|temporal
:- dynamic derived/1.      % derived(Key)
:- dynamic needs/2.        % needs(What, Key)  What: opposite | uncertain
:- dynamic ledger/6.
:- dynamic extra_rule/1.   % rules made from inline conclusions
:- dynamic float_attr/1.   % a value attribute computed with a float or a division
:- dynamic lib_use/1.      % temporal library templates used
:- dynamic counter/2.
:- dynamic qname/2.        % qname(Key, QueryName)
:- dynamic ent/4.          % ent(Entity, Text, IdKey, IdNoun)
:- dynamic rel/3.          % rel(RelationshipId, TargetEntity, Text)
:- dynamic inferred/1.     % inferred(Entity): a table infers its instances
:- dynamic role/3.         % role(Word, Phrase, Functor): a role of the global entity (below)
:- dynamic attr_roles/2.   % attr_roles(Key, [Phrase, ...]): the roles of a template's places
:- dynamic disp/2.         % disp(Key, Text): the sentence, the roles named
:- dynamic rtext/2.        % rtext(Key, Text): the sentence as its template has it (roles as places)
:- dynamic ent_mode/2.     % ent_mode(Entity, by_table | general): how its instances are named (below)
:- dynamic rel_info/7.     % rel_info(Rel, Source, Target, Type, Reverse, ReverseText, Containment)
:- dynamic inferred_by/2.  % inferred_by(Entity, Rel): a conclude-instance rule infers its instances
:- dynamic attr_ent/2.     % attr_ent(Key, Entity) for the attributes of an entity
:- dynamic extra_query/1.  % queries the tests of entity attributes need
:- dynamic chain/5.        % chain(Entity, FirstRel, NextRel, Step, Reverse): instances inferred one after another

		 /*******************************
		 *            TESTS             *
		 *******************************/

%!  oia_load_tests(+Files, -Sheets) is det.
%
%   The Excel test files as file(Path, Cases) with cases as dicts, through
%   oia_tests.py (openpyxl).
oia_load_tests(Files, Loaded) :-
    maplist(load_test_file, Files, Loaded).

load_test_file(File, file(File, [Case])) :-
    file_name_extension(Base, xml, File), atom_concat(Stem, '_request', Base), !,
    %  an Assess exchange: <name>_request.xml and <name>_response.xml
    atomic_list_concat([Stem, '_response.xml'], Resp),
    oia_assess:assess_soap_case(File, Resp, C0),
    Case = C0.put(_{row: 1}).
load_test_file(File, file(File, Cases)) :-
    file_name_extension(_, json, File), !,
    %  test cases written as JSON (tests.json): the form this repository's
    %  synthetic cases and replayed Assess calls take — see README.md
    read_file_to_string(File, S, [encoding(utf8)]),
    atom_json_dict(S, D, [value_string_as(string)]),
    findall(C, ( nth1(I, D.cases, C0), json_case(I, C0, C) ), Cases).
load_test_file(File, file(File, Cases)) :-
    source_file(oia_ir:oia_load_tests(_, _), Me), file_directory_name(Me, Dir),
    atomic_list_concat([Dir, '/oia_tests.py'], Script),
    process_create(path(python3), [Script, File], [stdout(pipe(Out)), stderr(null)]),
    json_read_dict(Out, D, [value_string_as(string)]),
    close(Out),
    (   get_dict(sheets, D, [Sheet|_]) -> get_dict(cases, Sheet, Cases) ; Cases = [] ).

%   A JSON case as an Excel one: row, id, inputs, expected (dicts keyed by
%   an attribute's text or public name; a relationship's value a list of
%   instances, each a dict with "@id").
json_case(I, C0, C) :-
    ( get_dict(id, C0, Id) -> true ; format(string(Id), "~w", [I]) ),
    ( get_dict(inputs, C0, In) -> true ; In = _{} ),
    ( get_dict(expected, C0, Ex) -> true ; Ex = _{} ),
    ( get_dict(description, C0, De) -> true ; De = "" ),
    C = _{row: I, id: Id, inputs: In, expected: Ex, description: De}.

		 /*******************************
		 *         THE MIGRATION        *
		 *******************************/

%!  oia_migration(+Model, +TestFiles, +Options, -Migration) is det.
%
%   Options: title(T), licence(L), artifacts(As), source_dir(D) (where the
%   project's files are, for the ledger), library_dir(Dir) (set when the
%   temporal library is used, so it can be copied).
oia_migration(Model, TestFiles, Opts, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    reset,
    Model = oia(Name, Attrs, Rules, Docs),
    option(title(Title), Opts, Name),
    oia_load_tests(TestFiles, TestSheets),
    infer_types(Attrs, Rules, TestSheets, Types),
    forall(rule_concludes(Rules, K), assertz(derived(K))),
    note_needs(Rules),
    note_float_attrs(Rules),
    used_keys(Rules, TestSheets, Used),
    note_entities(Attrs, Docs, Rules),
    note_roles(Attrs),
    make_templates(Attrs, Types, Used, TemplateItems00),
    role_items(RoleConstants, RoleFacts),
    append(RoleConstants, TemplateItems00, TemplateItems0),
    entity_templates(Attrs, Types, Used, Rules, EntItems),
    append(TemplateItems0, EntItems, TemplateItems),
    uncertain_templates(Attrs, Types, UItems),
    translate_rules(Model, Types, RuleItems0),
    findall(R, retract(extra_rule(R)), Extra0),
    ( getenv('OIA_NO_MERGE', _) -> RuleItems = RuleItems0 ; maplist(merge_reads, RuleItems0, RuleItems) ),
    maplist(merge_reads, Extra0, Extra),
    library_templates(LibItems, Includes),
    event_templates(EItems),
    table_templates(TItems),
    doc_items(Docs, DocItems),
    source_tests(TestSheets, Attrs, Types, Tests0, Queries0),
    entity_queries(EQueries0),
    findall(Q, extra_query(Q), XQs), append(EQueries0, XQs, EQueries),
    (   TestSheets == [], \+ option(analysis(false), Opts)
    ->  analysis_tests(Model, Types, ATests, AQueries)
    ;   ATests = [], AQueries = []
    ),
    append(Tests0, ATests, Tests),
    append([Queries0, AQueries, EQueries], Queries1), unique_queries(Queries1, Queries),
    view_item(Title, Attrs, Types, Rules, Queries, TestSheets, ViewItems),
    ( option(test_results(TR), Opts) -> source_runs(TR, Runs) ; Runs = [] ),
    ledger_rows(Attrs, Types, Used, TestSheets, Runs, Ledger),
    append([TemplateItems, UItems, LibItems, EItems, TItems,
            DocItems, RoleFacts, RuleItems, Extra, Queries, ViewItems], Items0),
    tables_first(Items0, Items),
    option(licence(Lic), Opts, 'none stated by the source repository; this twin is a derived work, kept private and not redistributed'),
    option(artifacts(Arts), Opts, []),
    Meta = [program(Title), source('Oracle Intelligent Advisor (Oracle Policy Automation)'),
            artifacts(Arts), translator('LE2 migration/oia (oia_reader.pl, oia_ir.pl)'),
            licence(Lic)],
    format(string(Comment),
           "~w: an LE twin of the Oracle Intelligent Advisor project, translated by\nthe OIA translator. Source licence: ~w.\nThe ledger is ~w.ledger.md.",
           [Title, Lic, Name]),
    Header = [kb(Name), comment(Comment)|Includes].

%   A rule that reads one attribute twice in the same conjunction (or in a
%   branch below it) reads one value: the second read takes the first's
%   variable. An attribute has one value, so this changes nothing but the
%   number of lines. Not across a negation, a universal or an aggregate,
%   whose reads are their own.
merge_reads(rule(H, B0, O), rule(H, B, O)) :- !,
    term_variables(H, HVs),
    (   catch(setup_call_cleanup(b_setval(oia_head_vars, HVs), merge_body(B0, [], B1), b_setval(oia_head_vars, [])), _, fail),
        \+ cyclic_term(H-B1)
    ->  B = B1
    ;   B = B0
    ).
merge_reads(I, I).

merge_body(B0, Scope, B) :-
    conj_list(B0, L0),
    (   L0 = [_, _|_]
    ->  foldl(merge_one, L0, Scope-[], _-Rev), reverse(Rev, L), conj(L, B)
    ;   L0 = [G0] -> merge_goal(G0, Scope, B)
    ;   B = B0
    ).

merge_one(G0, Scope-Acc, Scope1-[G|Acc]) :-
    merge_goal(G0, Scope, G),
    ( functional_read(G, Key) -> Scope1 = [Key-G|Scope] ; Scope1 = Scope ).

merge_goal(G0, Scope, G) :-
    (   var(G0) -> G = G0
    ;   G0 = or(A0, B0) -> merge_body(A0, Scope, A), merge_body(B0, Scope, B), G = or(A, B)
    ;   G0 = otherwise(Alts0) -> merge_alts(Alts0, Scope, Alts), G = otherwise(Alts)
    ;   G0 = and(_, _) -> merge_body(G0, Scope, G)
    ;   functional_read(G0, Key), member(Key2-Prev, Scope), Key2 == Key
    ->  G0 =.. L0, last(L0, V0), Prev =.. LP, last(LP, VP),
        %  never the rule's result: an `otherwise` guard keeps a condition
        %  on a variable two conditions share, and a result bound by the
        %  question ("is the parent form "Not known"?") would then pass it
        (   var(V0), b_getval(oia_head_vars, HVs), \+ ( member(HV, HVs), ( HV == V0 ; HV == VP ) )
        ->  V0 = VP, G = true
        ;   G = G0
        )
    ;   G = G0
    ).

merge_alts([], _, []).
merge_alts([A0|As0], Scope, [A|As]) :- merge_body(A0, Scope, A), merge_alts(As0, Scope, As).

conj_list(V, [V]) :- var(V), !.
conj_list(and(A, B), L) :- !, conj_list(A, LA), conj_list(B, LB), append(LA, LB, L).
conj_list(true, []) :- !.
conj_list(G, [G]).

%   A read of a single-valued template: a value attribute (of the case or
%   of an instance), or a one-to-one relationship; its key is the functor
%   with every argument but the value.
functional_read(G, F-Init) :-
    compound(G), G =.. [F|Args], Args \== [],
    (   tpl(_, F, Kind, _), memberchk(Kind, [value, evalue]) -> true
    ;   tpl(rel(R), F, relation, _), one_to_one(R)
    ),
    append(Init, [_], Args).

one_to_one(R) :-
    (   rel_info(R, _, _, 'OneToOne', _, _, _) -> true
    ;   rel_info(F, _, _, 'OneToOne', R, _, _), F \== R
    ).

%   Tables are sections of their own, written before the knowledge base by
%   the writer whatever their place in the list; nothing to do.
tables_first(Items, Items).

reset :-
    retractall(tpl(_, _, _, _)), retractall(derived(_)), retractall(needs(_, _)),
    retractall(ledger(_, _, _, _, _, _)), retractall(extra_rule(_)),
    retractall(float_attr(_)), retractall(lib_use(_)), retractall(counter(_, _)),
    retractall(qname(_, _)), retractall(ent(_, _, _, _)), retractall(rel(_, _, _)), retractall(inferred(_)),
    retractall(role(_, _, _)), retractall(attr_roles(_, _)), retractall(disp(_, _)), retractall(rtext(_, _)),
    retractall(ent_mode(_, _)), retractall(rel_info(_, _, _, _, _, _, _)), retractall(inferred_by(_, _)),
    retractall(attr_ent(_, _)), retractall(extra_query(_)), retractall(chain(_, _, _, _, _)),
    b_setval(oia_instance, none).

next(Kind, N) :-
    ( retract(counter(Kind, N0)) -> true ; N0 = 0 ),
    N is N0 + 1, assertz(counter(Kind, N)).

		 /*******************************
		 *        WHAT IS DERIVED       *
		 *******************************/

rule_concludes(Rules, K) :-
    member(rule(_, _, _, _, T), Rules),
    tree_concludes(T, K).

tree_concludes(conclude(K, _, _, _, _), K).
tree_concludes(conclude(_, _, _, C, _), K) :- sub_inline(C, K).
tree_concludes(table(_, _, Cols), K) :- member(concl(K, _), Cols).
tree_concludes(table(_, CCols, _), K) :- member(col(_, Cells), CCols), member(cond(E), Cells), sub_inline(E, K).

sub_inline(E, K) :-
    sub_term(inline(T), E), tree_concludes(T, K).

note_needs(Rules) :-
    forall(( member(rule(_, _, _, _, T), Rules), sub_term(S, T), compound(S),
             ( S = known(att(K)) ; S = unknown(att(K)) ; S = uncertain(att(K))
             ; S = known(cite(_, att(K))) ; S = uncertain(cite(_, att(K))) ) ),
           (   S = uncertain(_) -> assert_once(needs(uncertain, K))
           ;   assert_once(needs(known, K))
           )),
    forall(( member(rule(_, _, _, _, T), Rules), sub_term(conclude(K, _, false, _, _), T) ),
           assert_once(needs(opposite, K))).

assert_once(F) :- ( call(F) -> true ; assertz(F) ).

note_float_attrs(Rules) :-
    forall(( member(rule(_, _, _, _, T), Rules), value_expr_of(T, K, E),
             ( sub_term(num(F), E), float(F) ; sub_term(div(_, _), E) ) ),
           assert_once(float_attr(K))).

value_expr_of(conclude(K, _, E, _, _), K, E) :- E \== true, E \== false.
value_expr_of(table(_, _, Cols), K, E) :- member(concl(K, Vs), Cols), member(E, Vs).

		 /*******************************
		 *            TYPES             *
		 *******************************/

%   Key-Type for every attribute: the data model's, else what the rules and
%   the tests do with it.
infer_types(Attrs, Rules, Sheets, Types) :-
    findall(K-T, ( member(attr(K, _, T0, _, _), Attrs),
                   ( T0 \== auto -> T = T0 ; usage_type(K, Rules, Sheets, T) ) ), Types0),
    text_fixpoint(Rules, Types0, Types).

%   OIA's `+` joins texts as well as adding numbers: a value built with `+`
%   from a text is a text, and so on until nothing changes ("the system
%   email message = the beginning of the feedback + the middle ...", each
%   of them built from quoted pieces).
text_fixpoint(Rules, Types0, Types) :-
    (   member(rule(_, _, _, _, T), Rules), value_expr_of(T, K, E),
        memberchk(K-KT, Types0), KT \== text, \+ memberchk(KT, [boolean, date, datetime]),
        text_valued(Types0, E)
    ->  selectchk(K-KT, Types0, Types1),
        text_fixpoint(Rules, [K-text|Types1], Types)
    ;   Types = Types0
    ).

text_valued(Types, cite(_, E)) :- !, text_valued(Types, E).
text_valued(_, str(_)) :- !.
text_valued(_, concat(_, _)) :- !.
text_valued(_, text(_)) :- !.
text_valued(Types, add(A, B)) :- !, ( text_valued(Types, A) ; text_valued(Types, B) ), !.
text_valued(Types, att(K)) :- memberchk(K-text, Types).

usage_type(K, Rules, _, T) :-
    member(rule(_, _, _, _, Tree), Rules),
    sub_term(S, Tree), compound(S),
    S =.. [Op, A, B], memberchk(Op, [eq, ne, gt, ge, lt, le]),
    ( strip_cite(A, att(K)), const_type(B, T) ; strip_cite(B, att(K)), const_type(A, T) ), !.
usage_type(K, Rules, _, number) :-
    member(rule(_, _, _, _, Tree), Rules), sub_term(S, Tree), compound(S),
    S =.. [Op|Args], memberchk(Op, [mul, div, add, sub]), member(A, Args), strip_cite(A, att(K)), !.
usage_type(K, Rules, _, date) :-
    member(rule(_, _, _, _, Tree), Rules), sub_term(S, Tree), compound(S),
    S =.. [Op, A, _], memberchk(Op, [add_months, add_years, add_days]), strip_cite(A, att(K)), !.
%   compared with a date computed from another ("the Father's last work start
%   date < AddMonths(the date of birth of the child, -3)")
usage_type(K, Rules, _, date) :-
    member(rule(_, _, _, _, Tree), Rules), sub_term(S, Tree), compound(S),
    S =.. [Op, A, B], memberchk(Op, [eq, ne, gt, ge, lt, le]),
    ( strip_cite(A, att(K)), strip_cite(B, D) ; strip_cite(B, att(K)), strip_cite(A, D) ),
    compound(D), functor(D, DF, _), memberchk(DF, [add_months, add_years, add_days]), !.
usage_type(K, _, Sheets, T) :-
    member(file(_, Cases), Sheets), member(C, Cases),
    ( get_dict(inputs, C, In), dict_pairs(In, _, Ps) ; get_dict(expected, C, Ex), dict_pairs(Ex, _, Ps) ),
    member(H-V, Ps), oia_key(H, K),
    json_type(V, T), !.
usage_type(_, _, _, text).

const_type(str(_), text).
const_type(num(_), number).
const_type(date(_, _, _), date).

json_type(V, boolean) :- ( V == true ; V == false ), !.
json_type(V, number) :- number(V), !.
json_type(V, date) :- string(V), date_string(V, _), !.
json_type(_, text).

date_string(S, date(Y, M, D)) :-
    split_string(S, "-", "", [YS, MS, DS]),
    number_string(Y, YS), number_string(M, MS), number_string(D, DS),
    string_length(YS, 4).

strip_cite(cite(_, E), X) :- !, strip_cite(E, X).
strip_cite(E, E).

type_of(Types, K, T) :- ( memberchk(K-T, Types) -> true ; T = text ).

		 /*******************************
		 *           TEMPLATES          *
		 *******************************/

%   The attributes a rule mentions (or a test states and a rule reads).
used_keys(Rules, _Sheets, Used) :-
    findall(K, ( member(rule(_, _, _, _, T), Rules), sub_term(att(K), T) ), K1),
    findall(K, rule_concludes(Rules, K), K2),
    append(K1, K2, Ks), list_to_set(Ks, Used).

make_templates(Attrs, Types, Used, Items) :-
    include(used_attr(Used), Attrs, UA),
    findall(Text-K, ( member(attr(K, T0, Ty, _, _), UA), Ty == boolean,
                      oia_sanitize(T0, Text) ), BoolTexts),
    foldl(template_item(Types, BoolTexts), UA, [], Rev),
    reverse(Rev, Items).

used_attr(Used, attr(K, _, _, E, _)) :- memberchk(K, Used), E == global.

		 /*******************************
		 *    ENTITIES (rulebase.xml)   *
		 *******************************/

%   Entities other than the global one: their instances are identified by the
%   value of the identifying attribute (an error by its code), inferred by a
%   table concluding the relationship that contains them, and described by
%   rules concluding their attributes — OIA's inferred entity instances,
%   §5.1: `*a code* identifies the error`, `the error description of *a
%   code* is *a description*`.
note_entities(Attrs, Docs, Rules) :-
    forall(member(relationship(R, Src, Tgt, RT), Docs),
           ( assertz(rel(R, Tgt, RT)),
             ( member(relationship_info(R, Ty, Rev, RevT, Cont), Docs) -> true
             ; Ty = 'OneToMany', Rev = none, RevT = none, ( Src == global -> Cont = true ; Cont = false ) ),
             assertz(rel_info(R, Src, Tgt, Ty, Rev, RevT, Cont)) )),
    forall(( member(rule(_, _, _, _, conclude_instance(rel(R), _, _, _)), Rules), rel(R, Tgt, _) ),
           assert_once(inferred_by(Tgt, R))),
    forall(( member(attr(K, _, _, E, _), Attrs), E \== global ), assert_once(attr_ent(K, E))),
    forall(member(entity(E, T, IdKey0), Docs),
         ( ( table_inferred(Rules, E)
           ->  %  instances a relationship table infers: named by their
               %  identifying value (`*a code* identifies the error`)
               ( IdKey0 \== none, memberchk(attr(IdKey0, IdT, _, _, _), Attrs)
               -> oia_sanitize(IdT, IdS), atomic_list_concat(Ws, ' ', IdS), last(Ws, IdNoun0),
                  downcase_atom(IdNoun0, IdNoun)
               ;  IdNoun = identifier ),
               IdKey = IdKey0, Mode = by_table
           ;   %  any other entity: an instance is named by its identifying
               %  value when it has one, by the case's own name for it
               %  otherwise; its sentences speak of `*an asset*`
               entity_noun(T, IdNoun), IdKey = IdKey0, Mode = general
           ),
           oia_sanitize(T, TS),
           assertz(ent(E, TS, IdKey, IdNoun)),
           assertz(ent_mode(E, Mode)) )),
    note_chains(Rules).

%   A CHAIN of instances, OIA's way of laying out a schedule (a loan's
%   payments, a benefit's periods): the case infers the first instance
%   (`the first payment`, identity 0), and each instance infers the next
%   (`the next payment`, identity "the payment index + 1") while a condition
%   holds. Written as OIA writes it, the instances would be found by a
%   left recursion — a payment is one if the next payment of one is it —
%   which a backward-chaining engine walks one round per instance. The twin
%   walks the chain forward instead, from the first instance, each step
%   remembered: `the payments from *a payment* are *a list*`, and an instance
%   is one of the list from the first. The previous instance is the one
%   whose index is one step less, when its next one is this.
note_chains(Rules) :-
    forall(( member(rule(_, _, _, _, conclude_instance(rel(F), global, _, _)), Rules),
             rel(F, E, _),
             member(rule(_, _, _, _, conclude_instance(rel(N), E, Id, _)), Rules),
             rel(N, E, _),
             ent(E, _, IdKey, _), IdKey \== none,
             strip_cite(Id, Id1), Id1 = add(A, num(K)), strip_cite(A, att(IdKey)), integer(K) ),
           ( ( rel_info(N, _, _, _, Rev, _, _) -> true ; Rev = none ),
             assert_once(chain(E, F, N, K, Rev)) )).

table_inferred(Rules, E) :-
    member(rule(_, _, _, _, table(_, _, Cs)), Rules), member(concl(rel(R), _), Cs), rel(R, E, _), !.

%   "the income source" -> "income source".
entity_noun(T, N) :-
    oia_sanitize(T, S0), downcase_atom(S0, S1),
    atomic_list_concat(Ws0, ' ', S1),
    ( Ws0 = [the|Ws] -> true ; Ws = Ws0 ),
    atomic_list_concat(Ws, ' ', N).

plural_noun(N, P) :-
    atomic_list_concat(Ws, ' ', N), append(Pre, [W], Ws),
    plural_word(W, PW), append(Pre, [PW], PWs), atomic_list_concat(PWs, ' ', P).

plural_word(child, children) :- !.
plural_word(person, people) :- !.
plural_word(W, P) :- atom_concat(B, y, W), sub_atom(B, _, 1, 0, C), \+ memberchk(C, [a, e, i, o, u]), !, atom_concat(B, ies, P).
plural_word(W, P) :- ( atom_concat(_, s, W) ; atom_concat(_, x, W) ; atom_concat(_, ch, W) ; atom_concat(_, sh, W) ), !, atom_concat(W, es, P).
plural_word(W, P) :- atom_concat(W, s, P).

entity_templates(Attrs, Types, Used, Rules, Items) :-
    findall(E, ( ent(E, _, _, _),
                 ( member(attr(K, _, _, E, _), Attrs), memberchk(K, Used)
                 ; member(rule(_, _, _, _, table(E, _, _)), Rules)
                 ; member(rule(_, _, _, _, table(_, _, Cs)), Rules), member(concl(rel(R), _), Cs), rel(R, E, _)
                 ; member(rule(_, _, _, _, T), Rules), sub_term(rel(R), T), rel(R, E, _)
                 ; inferred_by(E, _) ) ),
            Es0),
    list_to_set(Es0, Es),
    findall(Is, ( member(E, Es), entity_items(E, Attrs, Types, Used, Rules, Is) ), Iss),
    append(Iss, Items0),
    relationship_templates(Rules, RItems),
    chain_templates(CItems),
    append([Items0, RItems, CItems], Items).

entity_items(E, Attrs, Types, Used, Rules, [template(IF, IT, IAdds)|AttrItems]) :-
    ent(E, ET, IdKey, IdNoun),
    article(IdNoun, A),
    format(atom(Place), '*~w ~w*', [A, IdNoun]),
    instance_template_text(E, ET, Place, IT),
    next(attr, N), format(atom(IF), 'e~w', [N]),
    assertz(tpl(inst(E), IF, instance, IT)),
    (   ( member(rule(_, _, _, _, table(_, _, Cs)), Rules), member(concl(rel(R), _), Cs), rel(R, E, _)
        ; inferred_by(E, _) )
    ->  IAdds0 = [], assertz(inferred(E)) ; IAdds0 = [undefined] ),
    ( inferred_by(E, _) -> append(IAdds0, [memorable], IAdds) ; IAdds = IAdds0 ),
    %  an inferred entity's values are asked again and again along its
    %  chain of instances (a payment's balance from the previous one's):
    %  remembered per query (`; memorable`, language.md §2.5)
    ( inferred_by(E, _) -> Mem = [memorable] ; Mem = [] ),
    findall(template(F, T, Adds),
            ( member(attr(K, Text0, _, E, _), Attrs), K \== IdKey, memberchk(K, Used),
              type_of(Types, K, Ty),
              oia_sanitize(Text0, Text),
              (   Ty == boolean
              ->  entity_boolean_text(Text, IdNoun, Place, T),
                  Kind = ebool
              ;   slot_noun(Text, Ty, Slot0), distinct_slot(Slot0, IdNoun, Slot),
                  entity_value_text(Text, IdNoun, Place, Phrase),
                  format(atom(T), '~w is *~w*', [Phrase, Slot]),
                  Kind = evalue
              ),
              next(attr, M), format(atom(F), 'e~w', [M]),
              assertz(tpl(K, F, Kind, T)),
              ( derived(K) -> Adds0 = [] ; Adds0 = [undefined] ),
              ( Kind == evalue, derived(K) -> append(Adds0, Mem, Adds) ; Adds = Adds0 ) ),
            AttrItems).

%   The instance template: VIBECT's errors as before (`*a code* identifies
%   the error`); an entity the case lists, `*an asset* is one of the
%   assets` — after its containment relationship, "the claimant's
%   children" giving `*a child* is one of the claimant's children`.
instance_template_text(E, ET, Place, IT) :-
    (   ent_mode(E, by_table)
    ->  format(atom(IT), '~w identifies ~w', [Place, ET])
    ;   ent(E, _, _, Noun),
        (   rel_info(R, global, E, _, _, _, true), rel(R, E, RT0), RT0 \== R,
            oia_sanitize(RT0, RT1), downcase_atom(RT1, RT2), \+ sub_atom(RT2, 0, _, _, 'all instances of')
        ->  RT = RT2
        ;   plural_noun(Noun, PN), atom_concat('the ', PN, RT)
        ),
        unguarded_phrase(RT, RT3),
        format(atom(IT), '~w is one of ~w', [Place, RT3])
    ).

unguarded_phrase(T, T).

%   "the asset's known value" -> "the known value of *an asset*"; "the
%   payment balance" -> "the payment balance of *a payment*"; "the
%   customer's monthly income from the income source" -> "the customer's
%   monthly income from *an income source*".
entity_value_text(Text, Noun, Place, Phrase) :-
    atomic_list_concat(Ws, ' ', Text),
    atomic_list_concat(NWs, ' ', Noun),
    (   Ws = [The|Rest], downcase_atom(The, the), noun_possessive(Rest, NWs, After), After \== []
    ->  atomic_list_concat(After, ' ', AT), format(atom(Phrase), 'the ~w of ~w', [AT, Place])
    ;   append(Pre, [The2|Rest2], Ws), Pre \== [], downcase_atom(The2, the),
        append(NWs, After2, Rest2)
    ->  append(Pre, [Place|After2], PWs), atomic_list_concat(PWs, ' ', Phrase)
    ;   format(atom(Phrase), '~w of ~w', [Text, Place])
    ).

%   "the child is a teenager" -> "*a child* is a teenager"; "the claimant
%   is a parent of the child" -> "the claimant is a parent of *a child*";
%   otherwise the sentence "for *a child*".
entity_boolean_text(Text, Noun, Place, T) :-
    atomic_list_concat(Ws, ' ', Text),
    atomic_list_concat(NWs, ' ', Noun),
    (   Ws = [The|Rest], downcase_atom(The, the), append(NWs, After, Rest), After = [Aux|_], aux_word(Aux)
    ->  atomic_list_concat([Place|After], ' ', T)
    ;   Ws = [The|Rest], downcase_atom(The, the), noun_possessive(Rest, NWs, After), After \== []
    ->  atomic_list_concat(After, ' ', AT), format(atom(T), 'the ~w of ~w', [AT, Place])
    ;   append(Pre, [The2|Rest2], Ws), Pre \== [], downcase_atom(The2, the), append(NWs, After2, Rest2)
    ->  append(Pre, [Place|After2], PWs), atomic_list_concat(PWs, ' ', T)
    ;   format(atom(T), '~w for ~w', [Text, Place])
    ).

%   ["asset's", known, value] with noun [asset] -> [known, value].
noun_possessive(Ws, NWs, After) :-
    append(Init, [Last], NWs),
    append(Init, [Tok|After], Ws),
    possessive(Tok, LastL), downcase_atom(Last, LastL).

%   A value slot that would read as the instance's own (`*an asset*` and
%   `*an asset*`): the type's noun instead.
distinct_slot(Slot0, Noun, Slot) :-
    (   atomic_list_concat([_|Ws], ' ', Slot0), atomic_list_concat(Ws, ' ', N0), N0 == Noun
    ->  atom_concat('a value of the ', Noun, Slot)
    ;   Slot = Slot0
    ).

%   The relationships the rules follow: `the first payment is *a payment*`
%   (from the case), `the next payment of *a payment* is *a second
%   payment*` (from an instance), and the reverse of each when the rules
%   use it (`the previous payment of ...`). A containment relationship is
%   its entity's instance template (above).
chain_templates(Items) :-
    findall(template(CF, CT, [memorable]),
            ( chain(E, _, _, _, _), ent(E, _, _, Noun), plural_noun(Noun, PN), article(Noun, A),
              format(atom(CT), 'the ~w from *~w ~w* are *a list*', [PN, A, Noun]),
              format(atom(CF), 'c_~w', [E]), atom_codes(CF, _),
              assertz(tpl(chain(E), CF, chain, CT)) ),
            Items),
    ( Items \== [] -> lib_template(followed_by, _) ; true ).

relationship_templates(Rules, Items) :-
    findall(R, ( member(rule(_, _, _, _, T), Rules), sub_term(rel(R), T), atom(R) ), Rs0),
    findall(R, ( rel_info(R, _, _, _, Rev, _, _), Rev \== none, memberchk(Rev, Rs0) ), Rs1),
    append(Rs0, Rs1, Rs2), list_to_set(Rs2, Rs),
    findall(template(F, T, Adds),
            ( member(R, Rs), \+ rel_info(R, global, _, _, _, _, true),
              \+ ( rel_info(R, _, _, _, _, _, true), \+ inferred_by(_, R) ),
              relationship_template(R, F, T),
              ( ( inferred_by(_, R) ; rel_info(R2, _, _, _, R, _, _), inferred_by(_, R2) ) -> Adds = [memorable] ; Adds = [undefined] ) ),
            Items).

relationship_template(R, F, T) :-
    rel_text_of(R, Src, Tgt, Text0),
    oia_sanitize(Text0, Text1), downcase_atom(Text1, Text2),
    ( sub_atom(Text2, 0, _, _, 'the ') -> Text = Text2 ; atom_concat('the ', Text2, Text) ),
    ent(Tgt, _, _, TN), article(TN, TA),
    (   Src == global
    ->  format(atom(T), '~w is *~w ~w*', [Text, TA, TN])
    ;   ent(Src, _, _, SN), article(SN, SA),
        ( SN == TN -> format(atom(TSlot), 'a second ~w', [TN]) ; format(atom(TSlot), '~w ~w', [TA, TN]) ),
        format(atom(T), '~w of *~w ~w* is *~w*', [Text, SA, SN, TSlot])
    ),
    next(attr, N), format(atom(F), 'r~w', [N]),
    assertz(tpl(rel(R), F, relation, T)).

%   A relationship's source, target and text; a reverse relationship's
%   from its forward one.
rel_text_of(R, Src, Tgt, Text) :-
    rel_info(R, Src, Tgt, _, _, _, _), rel(R, Tgt, Text), !.
rel_text_of(R, Src, Tgt, Text) :-
    rel_info(F, Tgt, Src, _, R, RevText, _), F \== R,
    ( RevText \== none -> Text = RevText ; atom_concat(R, '', Text) ).

%   The goal that holds of an instance Y of the relationship R, from the
%   context's instance X (or the case).
rel_goal(R, X, Y, G) :-
    (   rel_info(R, global, Tgt, _, _, _, true), tpl(inst(Tgt), IF, instance, _)
    ->  G =.. [IF, Y]
    ;   tpl(rel(R), F, relation, _), rel_text_of(R, Src, _, _)
    ->  ( Src == global -> G =.. [F, Y] ; G =.. [F, X, Y] )
    ;   rel_info(R, _, Tgt, _, _, _, _), tpl(inst(Tgt), IF, instance, _)
    ->  G =.. [IF, Y]
    ;   throw(oia_residue(relationship(R)))
    ).

rel_target(R, T) :-
    (   rel_info(R, _, T0, _, _, _, _) -> T = T0
    ;   rel_text_of(R, _, T0, _) -> T = T0
    ;   rel(R, T, _)
    ).

%   A query listing the instances a table infers (`which code identifies
%   the error`): the errors a case raises.
entity_queries(Qs) :-
    findall(query(QN, G),
            ( tpl(inst(E), IF, instance, _), inferred(E), ent(E, ET, _, _),
              G =.. [IF, _],
              query_base_name(ET, QN0), atom_concat(QN0, '_instances', QN1),
              unique_qname(QN1, 1, QN), assertz(qname(inst(E), QN)) ),
            Qs1),
    %  and the attributes the tables conclude for them
    findall(query(QN, G),
            ( tpl(K, F, evalue, _), derived(K), G =.. [F, _, _],
              query_base_name(K, QN0), unique_qname(QN0, 1, QN), assertz(qname(K, QN)) ),
            Qs2),
    append(Qs1, Qs2, Qs).

article(N, A) :- ( sub_atom(N, 0, 1, _, C), memberchk(C, [a, e, i, o, u]) -> A = an ; A = a ).

template_item(Types, BoolTexts, attr(K, Text0, _, _, Forms), Acc, [Item|Acc]) :-
    type_of(Types, K, Type),
    oia_sanitize(Text0, Text1),
    subject_np(Forms, SubjNP),
    with_roles(Text1, Type, SubjNP, TextR0, Disp0, Roles0),
    %  Two attributes whose sentences differ only in the role ("the supply
    %  / the property is of potential residential land") would be one LE
    %  predicate once the role is a place: the later one keeps its words.
    %  And a sentence a rule concludes in its negative form keeps its words
    %  too: LE compiles an opposite-form head holding a global as a
    %  predicate of its own (reported for LE core), which the positive
    %  sentence's conditions would then not reach.
    (   Roles0 \== [],
        (   skeleton(TextR0, Sk), member(template(_, T2, _), Acc),
            skeleton(T2, Sk2), ( Sk2 == Sk ; atom_concat(Sk, ' is', Sk2) )
        ;   needs(opposite, K)
        )
    ->  TextR = Text1, Disp = Text1, Roles = []
    ;   TextR = TextR0, Disp = Disp0, Roles = Roles0
    ),
    unguarded(Type, TextR, Text),
    unguarded(Type, Disp, DispU),
    ( Roles == [] -> true ; assertz(attr_roles(K, Roles)) ),
    assertz(rtext(K, TextR)),
    next(attr, N), format(atom(F), 'a~w', [N]),
    ( derived(K) -> Adds0 = [] ; Adds0 = [undefined] ),
    (   Type == boolean
    ->  (   ( needs(known, K), \+ derived(K) ; needs(opposite, K) ),
            oia_negation(Text0, Forms, Neg0), oia_sanitize(Neg0, Neg1),
            oia_key(Neg1, NegKey), \+ memberchk(_-NegKey, BoolTexts), NegKey \== K,
            with_roles(Neg1, Type, none, Neg, _, Roles)     % the same places, in the same order
        ->  Adds = [opposite(Neg)|Adds0],
            le_writer:template_text_dict(Neg, dict([OF|_], _, _)),
            assertz(tpl(K, OF, opposite, Neg))
        ;   Adds = Adds0
        ),
        assertz(tpl(K, F, boolean, Text)),
        assertz(disp(K, DispU)),
        Item = template(F, Text, Adds)
    ;   slot_noun(Text1, Type, Noun),
        (   member(BT-_, BoolTexts), atom_concat(Text1, ' is ', P), sub_atom(BT, 0, _, _, P)
        ->  format(atom(TT), 'the value of ~w is *~w*', [TextR, Noun]),
            format(atom(DT), 'the value of ~w is *~w*', [Disp, Noun])
        ;   format(atom(TT), '~w is *~w*', [Text, Noun]),
            format(atom(DT), '~w is *~w*', [DispU, Noun])
        ),
        assertz(tpl(K, F, value, TT)),
        assertz(disp(K, DT)),
        Item = template(F, TT, Adds0)
    ).

		 /*******************************
		 *   ROLES OF THE GLOBAL ENTITY  *
		 *******************************/

%   OIA's global entity is the case, and its attributes are sentences about
%   the people and things of the case: "the Father is an employee", "the
%   Child's Nationality". Written as they stand, those sentences were
%   propositions with no argument — "the Father" mere words of a sentence,
%   and the rules about him rules without variables. A ROLE is a definite
%   phrase `the <noun>` that Oracle's own parse gives as the subject of an
%   attribute and that at least two attributes speak about (as subject, or
%   as possessor: "the Father's employment status"). Each becomes
%
%     - a typed place of the templates that speak about it:
%         `*a father* is an employee`,
%         `the employment status of *a father* is *a status*`;
%     - a GLOBAL (le_summary.md §2, `; defines global`) that the rules keep
%       using as OIA's authors wrote them, bound to the case's individual:
%         `the Father in the case is *a father*; defines global the Father.`
%       with the knowledge base naming the one Father the global entity has:
%         `the Father in the case is "the Father".`
%
%   So the rules read as the source does ("the Father is entitled to ... if
%   the Child is a Singapore citizen ..."), the templates are general, and
%   a scenario states its facts about "the Father" as OIA's tests do.

%   The subject noun phrase of Oracle's parse, sanitized; `none` without one.
subject_np(Forms, NP) :-
    (   memberchk(parse(s(_, _, Subj, _)), Forms), compound(Subj), arg(1, Subj, NP0)
    ->  oia_sanitize(NP0, NP)
    ;   NP = none
    ).

note_roles(Attrs) :-
    findall(W-Ph, ( member(attr(_, _, _, global, Forms), Attrs),
                    subject_np(Forms, NP), NP \== none, role_np(NP, W, Ph) ),
            Confirmed),
    findall(W, member(W-_, Confirmed), Ws0), list_to_set(Ws0, Ws),
    forall(( member(W, Ws),
             aggregate_all(count, K, ( member(attr(K, T0, _, global, Fs), Attrs), mentions(T0, Fs, W) ), N),
             N >= 2,
             \+ ( member(attr(_, T1, Ty, global, _), Attrs), Ty \== boolean,
                  oia_sanitize(T1, S1), atomic_list_concat([the, W1], ' ', S1), downcase_atom(W1, W) ),
             role_phrase(W, Confirmed, Ph) ),
           ( format(atom(F), 'role_~w', [W]), assertz(role(W, Ph, F)) )).

%   `the Father` -> father; one alphabetic word after the article, not a
%   word that opens an LE section.
role_np(NP, W, NP) :-
    atomic_list_concat([the, W0], ' ', NP),
    atom_codes(W0, Cs), Cs \== [], forall(member(C, Cs), code_type(C, alpha)),
    downcase_atom(W0, W),
    \+ ( guard_words(G), G = [the, W|_] ).

%   The phrase as the authors capitalised it, when any did ("the Father").
role_phrase(W, Confirmed, Ph) :-
    (   member(W-Ph, Confirmed), sub_atom(Ph, 4, 1, _, C), char_type(C, upper(_)) -> true
    ;   memberchk(W-Ph, Confirmed)
    ).

%   An attribute speaks about role W: as its subject (Oracle's parse), or as
%   the possessor opening it ("the Father's employment status"), or opening
%   a sentence Oracle did not parse with W followed by an auxiliary.
mentions(T0, Forms, W) :-
    oia_sanitize(T0, S), atomic_list_concat(Ts, ' ', S),
    subject_np(Forms, NP),
    (   NP \== none, role_np(NP, W, _) -> true
    ;   Ts = [The, Tok|_], downcase_atom(The, the), possessive(Tok, W) -> true
    ;   NP == none, Ts = [The, Tok, Aux|_], downcase_atom(The, the), downcase_atom(Tok, W), aux_word(Aux)
    ).

possessive(Tok, W) :-
    atom_concat(Base, '''s', Tok), downcase_atom(Base, W).

aux_word(A) :-
    downcase_atom(A, L),
    memberchk(L, [is, are, was, were, has, have, had, must, may, can, could, should, would,
                  will, shall, does, do, did]).

%!  with_roles(+Text, +Type, +SubjNP, -TemplateText, -DisplayText, -Roles) is det.
%
%   The attribute's words with each role it mentions made a place (at most
%   once per role): as the subject, `*a father* ...`; as a possessor, `the
%   X of *a father*` — X the rest of the phrase at the start of a value
%   attribute (its whole name), up to the verb at the start of a sentence,
%   one word elsewhere ("the Child's Mother"); standing before a verb inside
%   the sentence ("days of GPPL the Father is entitled to"). DisplayText is
%   the same sentence with the role phrases for the places; Roles their
%   phrases, in order.
with_roles(Text, Type, SubjNP, TT, DT, Roles) :-
    (   role(_, _, _)
    ->  atomic_list_concat(Ts, ' ', Text),
        roles_walk(Ts, 0, Type, SubjNP, [], TTs, DTs, Roles),
        atomic_list_concat(TTs, ' ', TT), atomic_list_concat(DTs, ' ', DT)
    ;   TT = Text, DT = Text, Roles = []
    ).

roles_walk([], _, _, _, _, [], [], []).
roles_walk([The, Tok|Rest], I, Type, SubjNP, Used, TTs, DTs, Roles) :-
    downcase_atom(The, the),
    possessive(Tok, W), role(W, Ph, _), \+ memberchk(W, Used), !,
    (   I =:= 0, Type \== boolean -> X = Rest, After = []
    ;   I =:= 0 -> ( append(X, [A|As], Rest), aux_word(A) -> After = [A|As] ; X = Rest, After = [] )
    ;   Rest = [X1|After] -> X = [X1]
    ;   X = [], After = []
    ),
    X \== [],
    place(W, Pl),
    append([[the|X], [of, Pl]], TT0), append([[the|X], [of, Ph]], DT0),
    length([The, Tok|X], Len), I1 is I + Len,
    roles_walk(After, I1, Type, SubjNP, [W|Used], TTr, DTr, Rr),
    append(TT0, TTr, TTs), append(DT0, DTr, DTs), Roles = [Ph|Rr].
roles_walk([The, Tok|Rest], I, Type, SubjNP, Used, [Pl|TTr], [Ph|DTr], [Ph|Rr]) :-
    downcase_atom(The, the), downcase_atom(Tok, W),
    role(W, Ph, _), \+ memberchk(W, Used),
    (   I =:= 0, SubjNP \== none -> role_np(SubjNP, W, _)
    ;   Rest = [A|_], aux_word(A)
    ), !,
    place(W, Pl),
    I1 is I + 2,
    roles_walk(Rest, I1, Type, SubjNP, [W|Used], TTr, DTr, Rr).
roles_walk([T|Ts], I, Type, SubjNP, Used, [T|TTr], [T|DTr], Roles) :-
    I1 is I + 1,
    roles_walk(Ts, I1, Type, SubjNP, Used, TTr, DTr, Roles).

place(W, Pl) :- article(W, A), format(atom(Pl), '*~w ~w*', [A, W]).

%   The roles of the case, as named values: `the constants are:` with one line
%   each, `the Father is "the Father".` (LE2's language reference §2.3). The
%   name is what the rules keep using, exactly as OIA's authors wrote them,
%   and the value is the one individual the case gives that role.
%
%   This was a template with `; defines global the Father` and a fact of its
%   own until LE2 removed that addition (§2.3 and §2.4 say between them what it
%   used to say). A constant is the same thing written once, and the rules
%   above it did not change a word.
role_items(Constants, BodyItems) :-
    findall(constant(F, Ph, S), ( role(_, Ph, F), atom_string(Ph, S) ), Constants),
    (   Constants == [] -> BodyItems = []
    ;   findall(Ph, role(_, Ph, _), Phs), atomic_list_concat(Phs, ', ', PhT),
        format(string(Cm), "OIA's global entity is the case, with one of each of its roles (~w):\nthe rules speak of them as OIA's do, and `the constants are:` says which individual each one is.", [PhT]),
        BodyItems = [comment(Cm)]
    ).

%!  klit(+Key, +Kind, +Extra, -Literal) is semidet.
%
%   The literal of attribute Key (template kind boolean, value, opposite or
%   uncertain): its roles' globals, then Extra (a value).
klit(K, Kind, Extra, G) :-
    ekind(Kind, EKind), tpl(K, F, EKind, _), !,
    instance_var(K, X),
    G =.. [F, X|Extra].
klit(K, Kind, Extra, G) :-
    tpl(K, F, Kind, _),
    ( attr_roles(K, Rs) -> true ; Rs = [] ),
    append(Rs, Extra, Args),
    G =.. [F|Args].

ekind(boolean, ebool).
ekind(value, evalue).

%   The instance an entity attribute is read of: the context's (a rule of
%   that entity, or the scope of InstanceSum, ForAll, ...).
instance_var(K, X) :-
    (   b_getval(oia_instance, X0-E), ( attr_ent(K, E) ; \+ attr_ent(K, _) ) -> X = X0
    ;   b_getval(oia_instance, _-E), attr_ent(K, E2)
    ->  throw(oia_residue(attribute_of_other_entity(K, E2, E)))
    ;   throw(oia_residue(entity_attribute_outside_its_entity(K)))
    ).

%   A template's words without its places: "*a supply* is of land" and
%   "*a property* is of land" have the same.
skeleton(T, Sk) :-
    atomic_list_concat(Parts, '*', T),
    findall(P, ( nth1(I, Parts, P), I mod 2 =:= 1 ), Ws0),
    atomic_list_concat(Ws0, ' ', S0),
    downcase_atom(S0, S1), atomic_list_concat(Ws1, ' ', S1), exclude(==(''), Ws1, Ws),
    atomic_list_concat(Ws, ' ', Sk).

%   A sentence may not open with the words that open an LE section ("the
%   contract price" reads as `the contract <name> states that:`, and ends the
%   section the sentence is in): such a value is written `the value of the
%   contract price`, such a proposition `it holds that ...`.
unguarded(Type, Text0, Text) :-
    atomic_list_concat(Ws, ' ', Text0),
    (   guard_words(G), append(G, _, Ws)
    ->  ( Type == boolean -> atom_concat('it holds that ', Text0, Text)
        ; atom_concat('the value of ', Text0, Text) )
    ;   Text = Text0
    ).

guard_words(Ws) :-
    le_i18n:kw_synonym_words(guard, Ws0),
    maplist(downcase_atom, Ws0, Ws).
%   A sentence opening with the word that opens a rule's label, a scenario or
%   a query ("rule base version", OIA's built-in attribute) would read as one.
guard_words([rule]).
guard_words([scenario]).
guard_words([query]).

%   The slot of a value attribute: its own head noun when that is a noun
%   one would name a value by, otherwise the type's.
slot_noun(Text, Type, Slot) :-
    atomic_list_concat(Ws, ' ', Text), last(Ws, W0), downcase_atom(W0, W),
    (   memberchk(W, [amount, price, date, number, id, code, type, status, name, value, count,
                      percentage, rate, total, fee, method, mode, flag, period, reference,
                      nationality, output, endpoint, state, country, address, email, title,
                      postcode, suburb, sequence, response, decision, result, message, description])
    ->  Noun = W
    ;   type_noun(Type, Noun)
    ),
    ( sub_atom(Noun, 0, 1, _, C), memberchk(C, [a, e, i, o, u]) -> Art = an ; Art = a ),
    format(atom(Slot), '~w ~w', [Art, Noun]).

type_noun(number, number).
type_noun(currency, amount).
type_noun(date, date).
type_noun(datetime, date).
type_noun(boolean, value).
type_noun(text, value).
type_noun(auto, value).

uncertain_templates(Attrs, Types, Items) :-
    findall(template(F, T, [undefined]),
            ( needs(uncertain, K), memberchk(attr(K, Text0, _, _, _), Attrs),
              oia_sanitize(Text0, Text1), type_of(Types, K, Ty),
              ( rtext(K, Text) -> true ; Text = Text1 ),
              ( Ty == boolean -> format(atom(T), 'it is uncertain whether ~w', [Text])
              ; format(atom(T), 'it is uncertain what ~w is', [Text]) ),
              next(attr, N), format(atom(F), 'u~w', [N]),
              assertz(tpl(K, F, uncertain, T)) ),
            Items).

		 /*******************************
		 *   SENTENCES: LE-SAFE TEXT    *
		 *******************************/

%!  oia_sanitize(+Text, -LEText) is det.
%
%   An OIA sentence as an LE template's words: no punctuation that ends or
%   splits an LE sentence (, . ; : % and quotes), no reserved connective
%   (`if`, `unless`, ...) — which a template cannot contain — and no curly
%   quotes. The words are otherwise the author's.
oia_sanitize(Text0, Text) :-
    format(string(S0), "~w", [Text0]),
    string_codes(S0, Cs0),
    sanitize_codes(Cs0, Cs1),
    string_codes(S1, Cs1),
    split_string(S1, " ", " ", Ws0), exclude(==(""), Ws0, Ws1),
    reserved_words(Ws1, Ws2),
    atomic_list_concat(Ws2, ' ', Text1),
    first_lower(Text1, Text).

sanitize_codes([], []).
sanitize_codes([0'%|T], Out) :- !, append(` percent `, R, Out), sanitize_codes(T, R).
sanitize_codes([0'&|T], Out) :- !, append(` and `, R, Out), sanitize_codes(T, R).
sanitize_codes([D1, 0'., D2|T], [D1, 0'., D2|R]) :- code_type(D1, digit), code_type(D2, digit), !,
    sanitize_codes(T, R).
sanitize_codes([A, 0'-, B|T], [A, 32, B|R]) :-         % self-employed: self employed
    code_type(A, alnum), code_type(B, alnum), !,
    sanitize_codes(T, R).
sanitize_codes([0'/|T], Out) :- !, append(` or `, R, Out), sanitize_codes(T, R).
sanitize_codes([0'_|T], [32|R]) :- !, sanitize_codes(T, R).   % Hub texts write "(GED)" as "_GED_"
sanitize_codes([A, Q, B|T], [A, 0'', B|R]) :-          % an apostrophe inside a word
    memberchk(Q, `'’`), code_type(A, alpha), code_type(B, alpha), !,
    sanitize_codes(T, R).
sanitize_codes([C|T], [D|R]) :-
    (   memberchk(C, `,.;:!?"“”‘’'\`[]{}()*#|=<>+~^$\\`) -> D = 32 ; D = C ),
    sanitize_codes(T, R).

reserved_words([], []).
reserved_words(["only", "if"|T], ["only", "when"|R]) :- !, reserved_words(T, R).
reserved_words(["any", "of"|T], ["any", "one", "among"|R]) :- !, reserved_words(T, R).
reserved_words(["all", "of"|T], ["all"|R]) :- !, reserved_words(T, R).
reserved_words([W|T], [W1|R]) :-
    string_lower(W, L),
    (   L == "if" -> W1 = "in case"
    ;   L == "unless" -> W1 = "except where"
    ;   L == "either" -> W1 = "whichever of"
    ;   L == "expects" -> W1 = "requires"
    ;   L == "otherwise" -> W1 = "else"
    ;   W1 = W
    ),
    reserved_words(T, R).

first_lower(T0, T) :-
    (   sub_atom(T0, 0, 1, A, C), char_type(C, upper(L)),
        sub_atom(T0, 1, 1, _, C2), \+ char_type(C2, upper(_))
    ->  sub_atom(T0, 1, A, 0, Rest), atom_concat(L, Rest, T)
    ;   T = T0
    ).

%!  oia_negation(+Text, +Forms, -Negative) is det.
%
%   The negative sentence form: the one rulebase.stxt authored, else derived
%   from Oracle's own parse of the sentence (its verb and tense) — `not`
%   after the first auxiliary, `does not`/`did not` before a main verb.
oia_negation(_, Forms, Neg) :-
    memberchk(negative(N0), Forms), !,
    atom_string(N0, S), ( string_concat(S1, ".", S) -> true ; S1 = S ),
    atom_string(Neg1, S1), first_lower(Neg1, Neg).
oia_negation(Text, Forms, Neg) :-
    atomic_list_concat(Ws, ' ', Text),
    (   append(Pre, [Aux|Post], Ws), memberchk(Aux, [is, are, was, were, has, have, had, will, must,
                                                     may, can, should, would, could, shall, does, do, did]),
        Post \= [not|_]
    ->  append(Pre, [Aux, not|Post], NWs)
    ;   memberchk(parse(s(_, v(Verb0, t(_, Tense, _)), Subj, _)), Forms),
        verb_stem(Verb0, Verb),
        append(Pre, [W|Post], Ws), Pre \== [], sub_atom(W, 0, _, _, Verb)
    ->  ( Tense == past -> Do = did ; Subj =.. [_, _, plural] -> Do = do ; Do = does ),
        append(Pre, [Do, not, Verb|Post], NWs)
    ;   NWs = [it, is, false, that|Ws]
    ),
    atomic_list_concat(NWs, ' ', Neg).

verb_stem(V0, V) :- atomic_list_concat(Parts, '+', V0), last(Parts, V1), V = V1.

		 /*******************************
		 *            RULES             *
		 *******************************/

translate_rules(oia(_, _, Rules, Docs), Types, Items) :-
    findall(Doc-Id, ( member(R, Rules), R = rule(Id, Doc, _, _, _), unread_constant(Rules, R) ), Unread),
    nb_setval(oia_unread_constants, Unread),
    foldl(translate_rule(Docs, Types), Rules, [], Rev),
    reverse(Rev, Items0),
    append(Items0, Items).

%   A rule with no conditions whose conclusion no rule reads states a fact the
%   project never uses. In the Word document that is a paragraph written in
%   the conclusion style that is not a rule: gst_at_settlement's heading
%   "Property Details", styled "OPM - conclusion", which Policy Modeling
%   compiles into an attribute that is always true. The twin states it too
%   (it is the source's), and its ledger entry says why the verifier reports
%   it as a fact nothing reads (ledger_rule/6).
unread_constant(Rules, rule(_, _, _, _, conclude(K, _, true, C, _))) :-
    \+ sub_term(att(_), C),
    \+ ( member(rule(_, _, _, _, T), Rules),
          ( sub_term(att(K), T) ; sub_term(inline(conclude(K, _, _, _, _)), T) ) ).

translate_rule(Docs, Types, rule(Id, Doc, Name, Para, Tree), Acc, [Items|Acc]) :-
    rule_label(Doc, Id, Label),
    b_setval(oia_label, Label),
    rule_prov(Docs, Doc, Para, Prov),
    (   catch(tree_items(Types, Label, Prov, Tree, Items0), oia_residue(Why), ( residue_items(Label, Doc, Name, Tree, Why, Items0), true ))
    ->  Items = Items0
    ;   residue_items(Label, Doc, Name, Tree, 'the translator could not map it', Items)
    ),
    ledger_rule(Doc, Id, Name, Tree, Items, Label).

rule_label(Doc, Id, Label) :-
    doc_slug(Doc, S),
    format(atom(Label), '~w_r~w', [S, Id]).

doc_slug(Doc, Slug) :-
    ( sub_atom(Doc, B, _, _, '.') -> sub_atom(Doc, 0, B, _, D0) ; D0 = Doc ),
    downcase_atom(D0, D1), atom_codes(D1, Cs),
    maplist(slug_code, Cs, Es),
    atom_codes(Slug0, Es),
    atomic_list_concat(Parts, '_', Slug0), exclude(==(''), Parts, P1),
    atomic_list_concat(P1, '_', Slug).

slug_code(C, E) :- ( code_type(C, alnum) -> E = C ; E = 0'_ ).

%   The rule cites the Word document and the paragraph of its conclusion,
%   quoting that paragraph (checked against the document's text, which the
%   twin keeps beside it).
rule_prov(Docs, Doc, Para, Prov) :-
    (   Para \== none, memberchk(doc(Doc, Paras), Docs), memberchk(para(Para, _, PT), Paras)
    ->  quote_text(PT, Q),
        format(atom(Loc), 'paragraph ~w', [Para]),
        ( Q \== '' -> Prov = [as_stated_in(Doc), at(Loc), confer(Q)] ; Prov = [as_stated_in(Doc), at(Loc)] )
    ;   Prov = [as_stated_in(Doc)]
    ).

quote_text(PT, Q) :-
    atom_string(PT, S0), normalize_space(string(S1), S0),
    split_string(S1, "\"", "", Parts), atomic_list_concat(Parts, '”', Q).

tree_items(Types, Label, Prov, conclude(K, Ent, V, C, Else), Items) :-
    Ent == global, !,
    conclude_items(Types, Label, Prov, K, V, C, Else, Items).
tree_items(Types, Label, Prov, conclude(K, Ent, V, C, Else), Items) :- !,
    %  a conclusion about each instance of an entity
    (   ent(Ent, _, _, _), tpl(inst(Ent), _, instance, _) -> true ; throw(oia_residue(entity(Ent))) ),
    setup_call_cleanup(b_setval(oia_instance, entity(Ent)),
                       findall(R, instance_rule(conclude_one(Types, Label, Prov, K, V, C, Else), R), Items),
                       b_setval(oia_instance, none)),
    Items \== [].
tree_items(Types, Label, Prov, conclude_instance(rel(R), Src, Id, C), Items) :- !,
    conclude_instance_items(Types, Label, Prov, R, Src, Id, C, Items).
tree_items(Types, Label, Prov, table(Ent, CCols, Concls), Items) :-
    Ent \== global, !,
    (   ent(Ent, _, _, _), tpl(inst(Ent), _, instance, _) -> true ; throw(oia_residue(entity(Ent))) ),
    setup_call_cleanup(b_setval(oia_instance, entity(Ent)),
                       table_items(Types, Label, Prov, CCols, Concls, Items),
                       b_setval(oia_instance, none)),
    Items \== [].
tree_items(Types, Label, Prov, table(_, CCols, Concls), Items) :- !,
    table_items(Types, Label, Prov, CCols, Concls, Items).
tree_items(Types, Label, Prov, event(Action, C), [rule(Head, Body, [label(Label), provenance(Prov)])]) :- !,
    event_message(Action, Kind, Msg),
    error_functor(Kind, F),
    Head =.. [F, Msg],
    body(Types, C, Body).
tree_items(_, _, _, unsupported(Text), _) :-
    throw(oia_residue(unsupported(Text))).

conclude_one(Types, Label, Prov, K, V, C, Else, R) :-
    conclude_items(Types, Label, Prov, K, V, C, Else, [R]).

%   Inferred instances (OIA's `conclude-instance`): the relationship holds
%   of the instance its identity names, when the condition does — from the
%   case (`the first payment is 0`) or from an instance (`the next payment
%   of a payment is N if ... and N = the payment index + 1`) — and that
%   instance is one of its entity's. The reverse relationship (`the
%   previous payment`) is the same pairs the other way round.
conclude_instance_items(Types, Label, Prov, R, global, Id, C, Items) :-
    chain(Tgt, R, _, _, _), !,
    %  the first instance of a chain: the relationship only (the instances
    %  are the walk from it, chain_items/4)
    tpl(rel(R), RF, relation, _),
    body(Types, C, B0), value_term(Types, Id, GI, TI), assign(Y, TI, GI, BI),
    conj([B0, BI], B), H =.. [RF, Y],
    Items = [rule(H, B, [label(Label), provenance(Prov)])],
    Tgt = Tgt.
conclude_instance_items(Types, Label, Prov, R, Src, Id, C, Items) :-
    chain(Src, F, R, K, Rev), !,
    tpl(rel(R), RF, relation, _),
    setup_call_cleanup(b_setval(oia_instance, entity(Src)),
                       instance_rule(ci_rule(Types, Label, Prov, RF, Id, C), NextRule),
                       b_setval(oia_instance, none)),
    (   Rev \== none, tpl(rel(Rev), RevF, relation, _)
    ->  format(atom(L3), '~w_reverse', [Label]),
        RevH =.. [RevF, Q, P], RevB = and(P is Q - K, NB), NB =.. [RF, P, Q],
        RevRules = [rule(RevH, RevB, [label(L3), provenance(Prov)])]
    ;   RevRules = []
    ),
    chain_items(Types, Src, F, RF, C, Label, Prov, ChainRules),
    append([[NextRule], RevRules, ChainRules], Items).
conclude_instance_items(Types, Label, Prov, R, Src, Id, C, Items) :-
    rel_target(R, Tgt),
    tpl(inst(Tgt), IF, instance, _),
    tpl(rel(R), RF, relation, _),
    (   Src == global
    ->  body(Types, C, B0), value_term(Types, Id, GI, TI), assign(Y, TI, GI, BI),
        conj([B0, BI], B),
        RelRule = rule(H, B, [label(Label), provenance(Prov)]), H =.. [RF, Y],
        IG =.. [IF, Y2], RG =.. [RF, Y2]
    ;   setup_call_cleanup(b_setval(oia_instance, entity(Src)),
                           instance_rule(ci_rule(Types, Label, Prov, RF, Id, C), RelRule),
                           b_setval(oia_instance, none)),
        IG =.. [IF, Y2], RG =.. [RF, _, Y2]
    ),
    format(atom(L2), '~w_instance', [Label]),
    InstRule = rule(IG, RG, [label(L2), provenance(Prov)]),
    (   rel_info(R, _, _, _, Rev, _, _), Rev \== none, tpl(rel(Rev), RevF, relation, _), Src \== global
    ->  format(atom(L3), '~w_reverse', [Label]),
        RevH =.. [RevF, P, Q], RevB =.. [RF, Q, P],
        RevRules = [rule(RevH, RevB, [label(L3), provenance(Prov)])]
    ;   RevRules = []
    ),
    append([RelRule, InstRule], RevRules, Items).

%   The walk: the instances from X are X followed by those from the next
%   one, or X alone at the end; an instance is one of those from the first.
chain_items(Types, E, F, NF, C, Label, Prov, [WalkRule, EndRule, InstRule]) :-
    tpl(chain(E), CF, chain, _), tpl(inst(E), IF, instance, _), tpl(rel(F), FF, relation, _),
    lib_template(followed_by, LF),
    format(atom(L1), '~w_chain', [Label]), format(atom(L2), '~w_instance', [Label]),
    WH =.. [CF, X, L], NG =.. [NF, X, Y], CG =.. [CF, Y, T],
    L1G =.. [LF, L, X, T],
    %  two rules, not an `otherwise`: the second alternative's guard would
    %  hold the recursive walk under a negation, proved there again without
    %  being remembered — once per step of the chain, and so on down it
    WalkRule = rule(WH, and(NG, and(CG, L1G)), [label(L1), provenance(Prov)]),
    format(atom(L1e), '~w_chain_end', [Label]),
    %  the end: the condition of a next instance does not hold — written as
    %  its opposite ("the balance is 0 or less, or the index has reached
    %  the number of months"), not as a negation of the next instance,
    %  whose explanation of why there is none would be the whole chain's
    WH2 =.. [CF, X2, Last], L2G2 =.. [LF, Last, X2, []],
    (   negated_condition(C, NC)
    ->  setup_call_cleanup(b_setval(oia_instance, X2-E), body(Types, NC, EB), b_setval(oia_instance, none))
    ;   NG2 =.. [NF, X2, _], EB = not(NG2)
    ),
    EndRule = rule(WH2, and(EB, L2G2), [label(L1e), provenance(Prov)]),
    IH =.. [IF, Z], FG =.. [FF, Fst], AG =.. [CF, Fst, All],
    InstRule = rule(IH, and(FG, and(AG, le_is_in(Z, All))), [label(L2), provenance(Prov)]).

%   The opposite of a condition made of comparisons, and/or and booleans
%   (De Morgan; `>` becomes `<=`, ...); fails on anything else.
negated_condition(cite(_, E), N) :- !, negated_condition(E, N).
negated_condition(and(L), or(NL)) :- !, maplist(negated_condition, L, NL).
negated_condition(or(L), and(NL)) :- !, maplist(negated_condition, L, NL).
negated_condition(not(E), E) :- !.
negated_condition(att(K), not(att(K))) :- !.
negated_condition(E, N) :-
    E =.. [Op, A, B], memberchk(Op-NOp, [gt-le, ge-lt, lt-ge, le-gt, eq-ne, ne-eq]), !,
    N =.. [NOp, A, B].

ci_rule(Types, Label, Prov, RF, Id, C, rule(H, B, [label(Label), provenance(Prov)])) :-
    b_getval(oia_instance, X-_),
    body(Types, C, B0), value_term(Types, Id, GI, TI), assign(Y, TI, GI, BI),
    conj([B0, BI], B),
    H =.. [RF, X, Y].

%   A conclusion. Boolean: the head holds when the condition does (the
%   automatic `otherwise false` is LE's negation as failure); a value: the
%   head's value is the expression, relationally.
conclude_items(Types, Label, Prov, K, true, C, _, [rule(H, B, Opts)]) :- !,
    klit(K, boolean, [], H),
    body(Types, C, B),
    rule_opts(Label, Prov, C, Opts).
conclude_items(Types, Label, Prov, K, false, C, _, [rule(not(H), B, Opts)]) :- !,
    klit(K, boolean, [], H),
    body(Types, C, B),
    rule_opts(Label, Prov, C, Opts).
conclude_items(Types, Label, Prov, K, V, C, Else, [rule(H, B, Opts)]) :-
    klit(K, value, [X], H),
    body(Types, C, BC),
    value_term(Types, V, GV, TV),
    (   ( Else == none ; Else == false ; Else == uncertain_value )
    ->  assign(X, TV, GV, BV),
        conj([BC, BV], B)
    ;   assign_result(X, TV, GV, BV),
        value_term(Types, Else, GE, TE), assign_result(X, TE, GE, BE),
        conj([BC, BV], B1),
        B = otherwise([B1, BE])
    ),
    rule_opts(Label, Prov, C, Opts).

assign(X, T, Goals, Body) :-
    (   var(T) -> X = T, conj(Goals, Body)
    ;   ( atomic(T) ; T = date(_, _, _) )
    ->  append(Goals, [le_equal_to(X, T)], G1), conj(G1, Body)
    ;   append(Goals, [X is T], G1), conj(G1, Body)
    ).

%   The same in an alternative of an `otherwise` cascade: a value read
%   from an attribute is given to the result by `is equal to`, which LE
%   leaves out of the next alternative's guard (language.md §17.2), and the
%   read itself is not the result — a question that fixes the result ("is
%   the parent form "Not known"?") would otherwise make the read fail, the
%   guard hold, and a later alternative answer.
assign_result(X, T, Goals, Body) :-
    (   var(T) -> append(Goals, [le_equal_to(X, T)], G1), conj(G1, Body)
    ;   assign(X, T, Goals, Body)
    ).

rule_opts(Label, Prov, C, Opts) :-
    findall(Ci, sub_term(cite(Ci, _), C), Cites0), list_to_set(Cites0, Cites),
    (   Cites == [] -> CO = []
    ;   atomic_list_concat(Cites, '; ', CT), format(string(Cm), "cites: ~w", [CT]), CO = [comment(Cm)]
    ),
    ( numbered_shape(C) -> NO = [numbered(true)] ; NO = [] ),
    append([[label(Label), provenance(Prov)], CO, NO], Opts).

%   A table's rule: its label, provenance and the citations of its rows.
table_opts(Label, Prov, CCols, Opts) :-
    rule_opts(Label, Prov, and([]), Opts0),
    findall(Ci, sub_term(cite(Ci, _), CCols), Cites0), list_to_set(Cites0, Cites),
    (   Cites == [] -> Opts = Opts0
    ;   atomic_list_concat(Cites, '; ', CT), format(string(Cm), "cites: ~w", [CT]),
        append(Opts0, [comment(Cm)], Opts)
    ).

%   Word levels mixing `and` and `or` are written as a numbered outline, as
%   OIA's own document shows them.
%   (Not over an `or` group: le_writer numbers the items under a negated
%   `either` with an unbound prefix — proposed core fix in the report.)
numbered_shape(C) :-
    sub_term(and(_), C), sub_term(or(_), C),
    \+ sub_term(known(_), C), \+ sub_term(unknown(_), C),
    \+ ( sub_term(not(N), C), strip_cite(N, or(_)) ).

		 /*******************************
		 *          CONDITIONS          *
		 *******************************/

%!  body(+Types, +Expr, -Goal) is det.
body(_, true, true) :- !.
body(Types, cite(_, E), G) :- !, body(Types, E, G).
body(Types, and(L0), G) :- !, flat(and, L0, L), maplist(body(Types), L, Gs), conj(Gs, G).
body(Types, or(L0), G) :- !, flat(or, L0, L), maplist(body(Types), L, Gs),
    ( memberchk(true, Gs) -> G = true ; disj(Gs, G) ).
body(Types, not(E), G) :- !, body(Types, E, G0),
    ( G0 == true -> G = prolog(fail) ; G = not(G0) ).
body(_, att(K), G) :- !, attr_condition(K, G).
body(Types, inline(T), G) :- !,
    T = conclude(K, _, _, _, _),
    attr_condition(K, G0),
    (   nb_current(oia_label, L0), L0 \== [] -> true ; L0 = oia ),
    functor(G0, GF0, _), format(atom(Label), '~w_~w', [L0, GF0]),
    (   tree_items(Types, Label, [], T, Rs) -> forall(member(R, Rs), assertz(extra_rule(R))) ; true ),
    G = G0.
body(Types, E, G) :- comparison(E, Op, A, B), !,
    (   Op == eq, strip_cite(A, att(K)), b_getval(oia_instance, X-Ent), ent(Ent, _, K, _), constant(B, C)
    ->  G = le_equal_to(X, C)                 % the instance's own identifying value
    ;   Op == eq, strip_cite(A, att(K)), tpl(K, _, value, _), constant(B, C)
    ->  klit(K, value, [C], G)                % "the person is "Purchaser""
    ;   Op == eq, strip_cite(A, att(K)), tpl(K, _, evalue, _), b_getval(oia_instance, _-_), constant(B, C)
    ->  val_goal(K, C, G)                     % "the carrier id of the decision is "144""
    ;   Op == eq, strip_cite(B, att(K)), tpl(K, _, value, _), constant(A, C)
    ->  klit(K, value, [C], G)
    ;   value_term(Types, A, GA, TA), value_term(Types, B, GB, TB),
        cmp_goal(Op, TA, TB, CG),
        append([GA, GB, [CG]], Gs), conj(Gs, G)
    ).
body(_, known(E), G) :- !, strip_cite(E, att(K)), known_goal(K, G).
body(_, unknown(E), G) :- !, strip_cite(E, att(K)), known_goal(K, G0),
    ( G0 == true -> G = prolog(fail) ; G = not(G0) ).
body(_, uncertain(E), G) :- !, strip_cite(E, att(K)), klit(K, uncertain, [], G).
body(Types, temporal(T, Args), G) :- !, temporal_condition(Types, T, Args, G).
body(_, false, prolog(fail)) :- !.
body(Types, exists(rel(R), C), G) :- !, scoped(R, _, Types, C, G, _).
body(Types, forall(rel(R), C), forall(RG, BC)) :- !,
    b_getval(oia_instance, Ctx),
    ( Ctx = X-_ -> true ; X = none ),
    rel_goal(R, X, Y, RG), rel_target(R, T),
    setup_call_cleanup(b_setval(oia_instance, Y-T), body(Types, C, BC), b_setval(oia_instance, Ctx)).
body(Types, E, G) :-
    E =.. [F, A, B], memberchk(F, [contains, starts_with, ends_with]), !,
    value_term(Types, A, GA, TA0), bind(TA0, TA, BA),
    value_term(Types, B, GB, TB0), bind(TB0, TB, BB),
    (   F == starts_with -> L = le_starts_with(TA, TB)          % LE's own (language.md §7)
    ;   lib_template(F, LF), L =.. [LF, TA, TB]
    ),
    append([GA, BA, GB, BB, [L]], Gs), conj(Gs, G).
body(Types, via(rel(R), C), G) :- !,                 % a boolean of a related instance
    b_getval(oia_instance, Ctx),
    ( Ctx = X-_ -> true ; X = none ),
    rel_goal(R, X, Y, RG), rel_target(R, T),
    setup_call_cleanup(b_setval(oia_instance, Y-T), body(Types, C, BC), b_setval(oia_instance, Ctx)),
    conj([RG, BC], G).
body(_, E, _) :- throw(oia_residue(condition(E))).

attr_condition(K, G) :-
    (   tpl(K, _, ebool, _) -> klit(K, boolean, [], G)
    ;   tpl(K, F, evalue, _), b_getval(oia_instance, X-_) -> G =.. [F, X, _]
    ;   tpl(K, _, boolean, _) -> klit(K, boolean, [], G)
    ;   tpl(K, _, value, _) -> klit(K, value, [_], G)    % a value attribute tested for being known
    ;   throw(oia_residue(no_template(K)))
    ).

known_goal(K, G) :-
    (   tpl(K, _, boolean, _), derived(K)
    ->  G = true      % a conclusion with OIA's automatic "otherwise false" is always known
    ;   tpl(K, _, boolean, _)
    ->  klit(K, boolean, [], F),
        ( klit(K, opposite, [], OF) -> G = or(F, OF) ; G = true )
    ;   tpl(K, _, value, _) -> klit(K, value, [_], G)
    ;   G = true
    ).

%   Nested and(...) lists (Word levels without a connective of their own)
%   flattened: the same conjunction, written as sibling lines.
flat(Op, L0, L) :-
    foldl(flat_one(Op), L0, [], Rev), reverse(Rev, L).

flat_one(Op, E, Acc, Out) :-
    (   E =.. [Op, Sub] -> flat(Op, Sub, SL), reverse(SL, RSL), append(RSL, Acc, Out)
    ;   Out = [E|Acc]
    ).

comparison(E0, Op, A, B) :-
    strip_cite(E0, E), compound(E), E =.. [Op, A, B], memberchk(Op, [eq, ne, gt, ge, lt, le]).

cmp_goal(eq, A, B, le_equal_to(A, B)).
cmp_goal(ne, A, B, le_not_equal_to(A, B)).
cmp_goal(gt, A, B, A > B).
cmp_goal(ge, A, B, A >= B).
cmp_goal(lt, A, B, A < B).
cmp_goal(le, A, B, A =< B).

constant(E, C) :- strip_cite(E, E1), const(E1, C).
const(str(S0), S) :- safe_string(S0, S).
const(num(N), N).
const(date(Y, M, D), date(Y, M, D)).
const(true, true).
const(false, false).

%!  value_term(+Types, +Expr, -Goals, -Term)
%
%   An expression, relationally: every attribute it reads is a condition
%   binding a variable (`the contract price is an amount A`), and Term is
%   the arithmetic over those variables.
value_term(Types, cite(_, E), G, T) :- !, value_term(Types, E, G, T).
value_term(_, att(K), G, X) :-                     % an instance's own identifying value
    b_getval(oia_instance, I-E), ent(E, _, K, _), !,
    X = I, G = [].
value_term(_, att(K), [G], X) :- !,
    (   tpl(K, _, evalue, _), b_getval(oia_instance, _-_) -> klit(K, value, [X], G)
    ;   tpl(K, _, ebool, _) -> klit(K, boolean, [], G), X = true
    ;   tpl(K, _, value, _) -> klit(K, value, [X], G)
    ;   tpl(K, _, boolean, _) -> klit(K, boolean, [], G), X = true
    ;   throw(oia_residue(no_template(K)))
    ).
value_term(_, E, [], C) :- const(E, C), !.
%   A decimal constant (0.07) as a fraction (7 / 100), multiplied first:
%   `C * 7 / 100` is exact where `C * 0.07` is a binary float, and OIA's
%   arithmetic is decimal (1000000 * 0.07 is 70000, not 70000.00000000001).
value_term(Types, mul(A, B), G, T) :- decimal(B, M, D), !,
    value_term(Types, A, G, TA), ( M =:= 1 -> T = TA / D ; T = (TA * M) / D ).
value_term(Types, mul(A, B), G, T) :- decimal(A, M, D), !,
    value_term(Types, B, G, TB), ( M =:= 1 -> T = TB / D ; T = (M * TB) / D ).
value_term(Types, div(A, B), G, T) :- decimal(B, M, D), !,
    value_term(Types, A, G, TA), T = (TA * D) / M.
value_term(Types, add(A, B), G, T) :-
    ( text_valued(Types, A) ; text_valued(Types, B) ), !,
    value_term(Types, concat(A, B), G, T).
value_term(Types, E, G, T) :-
    E =.. [Op, A, B], arith(Op, POp), !,
    value_term(Types, A, GA, TA), value_term(Types, B, GB, TB),
    append(GA, GB, G), T =.. [POp, TA, TB].
value_term(Types, neg(A), G, T) :- !,
    value_term(Types, A, G, TA),
    ( number(TA) -> T is -TA ; T = 0 - TA ).
value_term(Types, round(A), G, round(TA)) :- !, value_term(Types, A, G, TA).
value_term(Types, add_months(D, N), G, Later) :- !,
    value_term(Types, D, GD, TD), value_term(Types, N, GN, TN),
    lib_template(months_after, F),
    L =.. [F, Later, TN, TD],
    append([GD, GN, [L]], G).
value_term(Types, add_years(D, N), G, Later) :- !,
    value_term(Types, D, GD, TD), value_term(Types, N, GN, TN),
    lib_template(years_after, F),
    L =.. [F, Later, TN, TD],
    append([GD, GN, [L]], G).
value_term(_, current_date, [G], X) :- !,
    current_date_template(F), G =.. [F, X].
value_term(Types, temporal('temporal-years-since', [D]), G, N) :- !,
    value_term(Types, temporal('temporal-years-since', [D, current_date]), G, N).
value_term(Types, temporal('temporal-years-since', [D, To]), G, N) :- !,
    value_term(Types, D, GD, TD), value_term(Types, To, GT, TT),
    lib_template(years_between, F), L =.. [F, TD, TT, N],
    append([GD, GT, [L]], G).
%   Over the instances of a relationship: InstanceCount, InstanceSum,
%   InstanceMinimum, InstanceMaximum, InstanceCountIf — LE's aggregates
%   (language.md §5): `N is the sum of each V such that X is one of the
%   assets and the known value of X is V`.
value_term(Types, inst_count(rel(R)), [agg(count, Y, MG, N)], N) :- !,
    scoped(R, Y, Types, true, MG, _).
value_term(Types, inst_count_if(rel(R), C), [agg(count, Y, G, N)], N) :- !,
    scoped(R, Y, Types, C, G, _).
value_term(Types, E, [agg(Op, V, G, S)], S) :-
    E =.. [F, rel(R), VE], memberchk(F-Op, [inst_sum-sum, inst_min-min, inst_max-max]), !,
    scoped_value(R, Y, Types, VE, G, V), Y = Y.
value_term(Types, via(rel(R), VE), G, V) :- !,
    b_getval(oia_instance, Ctx),
    ( Ctx = X-_ -> true ; X = none ),
    rel_goal(R, X, Y, RG), rel_target(R, T),
    setup_call_cleanup(b_setval(oia_instance, Y-T),
                       value_term(Types, VE, GV, TV),
                       b_setval(oia_instance, Ctx)),
    bind(TV, V, BV),
    append([[RG], GV, BV], G).
value_term(Types, concat(A, B), G, T) :- !,
    concat_parts(concat(A, B), Parts0),
    foldl(part_term(Types), Parts0, []-[], Gs-Ts0), reverse(Ts0, Ts),
    lib_template(joining, F), L =.. [F, Ts, T],
    append(Gs, [L], G).
value_term(Types, text(A), G, T) :- !,
    value_term(Types, A, GA, TA0), bind(TA0, TA, BA),
    lib_template(text_of, F), L =.. [F, TA, T],
    append([GA, BA, [L]], G).
value_term(Types, length(A), G, N) :- !,
    value_term(Types, A, GA, TA0), bind(TA0, TA, BA),
    lib_template(length_of, F), L =.. [F, TA, N],
    append([GA, BA, [L]], G).
value_term(Types, mod(A, B), G, TA mod TB) :- !,
    value_term(Types, A, GA, TA), value_term(Types, B, GB, TB), append(GA, GB, G).
value_term(Types, pow(A, B), G, P) :- !,
    value_term(Types, A, GA, TA0), bind(TA0, TA, BA),
    value_term(Types, B, GB, TB0), bind(TB0, TB, BB),
    lib_template(power, F), L =.. [F, TA, TB, P],
    append([GA, BA, GB, BB, [L]], G).
value_term(Types, E, G, Z) :-
    E =.. [F, A, B], memberchk(F-S, [min-le_minimum, max-le_maximum]), !,
    value_term(Types, A, GA, TA0), bind(TA0, TA, BA),
    value_term(Types, B, GB, TB0), bind(TB0, TB, BB),
    L =.. [S, TA, TB, Z],
    append([GA, BA, GB, BB, [L]], G).
value_term(Types, round(A, num(D)), G, T) :- !,
    value_term(Types, A, GA, TA),
    (   D =:= 0 -> G = GA, T = round(TA)
    ;   bind(TA, V, BV), lib_template(round_half_up, F), L =.. [F, V, D, T],
        append([GA, BV, [L]], G)
    ).
value_term(Types, trunc(A, num(D)), G, T) :- !,
    value_term(Types, A, GA, TA),
    (   D =:= 0 -> G = GA, T = truncate(TA)
    ;   bind(TA, V, BV), lib_template(round_down, F), L =.. [F, V, D, T],
        append([GA, BV, [L]], G)
    ).
value_term(Types, E, G, T) :-
    E =.. [F, A, num(D)], memberchk(F-Fn, [floor-floor, ceiling-ceiling]), D =:= 0, !,
    value_term(Types, A, G, TA), T =.. [Fn, TA].
value_term(Types, E, G, N) :-
    E =.. [F, A, B], memberchk(F-Lib, [day_difference-days_between, month_difference-months_between,
                                      year_difference-years_between]), !,
    value_term(Types, A, GA, TA0), bind(TA0, TA, BA),
    value_term(Types, B, GB, TB0), bind(TB0, TB, BB),
    lib_template(Lib, LF), L =.. [LF, TA, TB, N],
    append([GA, BA, GB, BB, [L]], G).
value_term(Types, add_days(D, N), G, Later) :- !,
    value_term(Types, D, GD, TD0), bind(TD0, TD, BD),
    value_term(Types, N, GN, TN),
    append([GD, BD, GN, [le_is_days_after(Later, TN, TD)]], G).
value_term(Types, current_datetime, G, X) :- !,
    value_term(Types, current_date, G, X).
value_term(_, uncertain_value, _, _) :- !, fail.
value_term(_, E, _, _) :- throw(oia_residue(value(E))).

%   An expression's value as a variable: a variable as it is, anything else
%   bound by `V is ...` (a number or a text is a value already).
bind(T, V, G) :-
    (   var(T) -> V = T, G = []
    ;   ( atomic(T) ; T = date(_, _, _) ) -> V = T, G = []
    ;   G = [V is T]
    ).

concat_parts(concat(A, B), Ps) :- !, concat_parts(A, PA), concat_parts(B, PB), append(PA, PB, Ps).
concat_parts(add(A, B), Ps) :- !, concat_parts(A, PA), concat_parts(B, PB), append(PA, PB, Ps).
concat_parts(cite(_, E), Ps) :- !, concat_parts(E, Ps).
concat_parts(E, [E]).

part_term(Types, E, G0-T0, G-[T|T0]) :-
    value_term(Types, E, GE, TE0), bind(TE0, T, BE),
    append([G0, GE, BE], G).

%   The goals of "Y is one of the instances R leads to" with the condition
%   C read of Y (InstanceCountIf, Exists, ForAll).
scoped(R, Y, Types, C, G, T) :-
    b_getval(oia_instance, Ctx),
    ( Ctx = X-_ -> true ; X = none ),
    rel_goal(R, X, Y, RG), rel_target(R, T),
    setup_call_cleanup(b_setval(oia_instance, Y-T),
                       body(Types, C, BC),
                       b_setval(oia_instance, Ctx)),
    conj([RG, BC], G).

%   ... and the value of E for Y (InstanceSum).
scoped_value(R, Y, Types, VE, G, V) :-
    b_getval(oia_instance, Ctx),
    ( Ctx = X-_ -> true ; X = none ),
    rel_goal(R, X, Y, RG), rel_target(R, T),
    setup_call_cleanup(b_setval(oia_instance, Y-T),
                       value_term(Types, VE, GV, TV),
                       b_setval(oia_instance, Ctx)),
    bind(TV, V, BV),
    append([[RG], GV, BV], Gs), conj(Gs, G).

arith(mul, *). arith(div, /). arith(add, +). arith(sub, -).

decimal(E, M, D) :-
    strip_cite(E, num(F)), float(F), F =\= float_integer_part(F),
    format(atom(A), '~15g', [F]), atom_number(A, F1), F1 =:= F,
    between(1, 9, K), D is 10^K, M0 is F * D, R is round(M0), abs(M0 - R) < 1.0e-9, !,
    M = R.

%   OIA's temporal functions of the current date (change points are not
%   modelled: the current date is case data — ledger: approximated).
temporal_condition(Types, 'temporal-on-or-after', [D], G) :- !,
    value_term(Types, D, GD, TD), current_date_template(CF), CG =.. [CF, Now],
    append(GD, [CG, Now >= TD], Gs), conj(Gs, G).
temporal_condition(Types, 'temporal-before', [D], G) :- !,
    value_term(Types, D, GD, TD), current_date_template(CF), CG =.. [CF, Now],
    append(GD, [CG, Now < TD], Gs), conj(Gs, G).
temporal_condition(Types, 'temporal-on-or-before', [D], G) :- !,
    value_term(Types, D, GD, TD), current_date_template(CF), CG =.. [CF, Now],
    append(GD, [CG, Now =< TD], Gs), conj(Gs, G).
temporal_condition(Types, 'temporal-after', [D], G) :- !,
    value_term(Types, D, GD, TD), current_date_template(CF), CG =.. [CF, Now],
    append(GD, [CG, Now > TD], Gs), conj(Gs, G).
temporal_condition(_, T, Args, _) :- throw(oia_residue(temporal(T, Args))).

current_date_template(F) :-
    (   tpl(current_date, F, current_date, _) -> true
    ;   F = oia_current_date,
        assertz(tpl(current_date, F, current_date, 'the current date is *a date*'))
    ).

%   A template of lib/temporal.le, included beside the twin.
lib_template(Name, F) :-
    lib_text(Name, F, Text),
    assert_once(lib_use(Name)),
    (   tpl(Name, F, temporal, _) -> true ; assertz(tpl(Name, F, temporal, Text)) ).

lib_text(months_after, lib_months_after, '*a later date* is *a number* calendar months after *a date*').
lib_text(years_after, lib_years_after, '*a later date* is *a number* years after *a date*').
lib_text(years_between, lib_years_between, 'the number of whole years from *a date* to *a second date* is *a number*').
lib_text(months_between, lib_months_between, 'the number of whole months from *a date* to *a second date* is *a number*').
lib_text(days_between, lib_days_between, 'the number of days from *a date* to *a second date* is *a number*').
lib_text(joining, lib_joining, 'the joining of *a list* is *a text*').
lib_text(text_of, lib_text_of, 'the text of *a value* is *a text*').
lib_text(length_of, lib_length_of, 'the length of *a text* is *a number*').
lib_text(contains, lib_contains, '*a text* contains *a part*').
lib_text(ends_with, lib_ends_with, '*a text* ends with *a part*').
lib_text(power, lib_power, 'the power of *a number* to *an exponent* is *a result*').
lib_text(followed_by, lib_followed_by, '*a list* is *an item* followed by *a second list*').
lib_text(round_half_up, lib_round_half_up, 'the rounding of *a number* to *a count* decimals half up is *a result*').
lib_text(round_down, lib_round_down, 'the rounding of *a number* down to *a count* decimals is *a result*').

%   The library each template comes from (lib/<name>.le in LE2).
lib_of(N, temporal) :- memberchk(N, [months_after, years_after, years_between, months_between, days_between]), !.
lib_of(N, text) :- memberchk(N, [joining, text_of, length_of, contains, ends_with]), !.
lib_of(power, maths) :- !.
lib_of(followed_by, lists) :- !.
lib_of(N, rounding) :- memberchk(N, [round_half_up, round_down]), !.

library_templates(Items, Includes) :-
    findall(template(F, T, [included]), ( lib_use(N), lib_text(N, F, T) ), LibItems),
    findall(template(F, T, [undefined]), tpl(current_date, F, current_date, T), CD),
    append(LibItems, CD, Items),
    findall(L, ( lib_use(N), lib_of(N, L) ), Ls0), list_to_set(Ls0, Ls),
    ( Ls == [] -> Includes = [] ; Includes = [includes(Ls)] ).

conj([], true) :- !.
conj(Gs0, G) :- exclude(==(true), Gs0, Gs), ( Gs == [] -> G = true ; foldl_and(Gs, G) ).
foldl_and([G], G) :- !.
foldl_and([G1, G2|Gs], G) :- foldl_and([and(G1, G2)|Gs], G).

disj([G], G) :- !.
disj([G1, G2|Gs], G) :- disj([or(G1, G2)|Gs], G).

		 /*******************************
		 *    EVENTS (errors, warnings) *
		 *******************************/

event_message(Action, Kind, Msg) :-
    atom_string(Action, S),
    (   sub_string(S, B, _, _, "(\""), sub_string(S, 0, B, _, K0),
        sub_string(S, _, 2, 0, "\")")
    ->  string_lower(K0, K1), atom_string(Kind, K1),
        B2 is B + 2, sub_string(S, B2, _, 2, Msg0), string_concat(Msg0, "", Msg)
    ;   Kind = error, Msg = S
    ).

error_functor(Kind, F) :-
    format(atom(F), 'oia_~w', [Kind]),
    (   tpl(Kind, F, error, _) -> true
    ;   format(atom(T), 'the rulebase raises the ~w *a message*', [Kind]),
        assertz(tpl(Kind, F, error, T))
    ).

event_templates(Items) :-
    findall(template(F, T, []), tpl(_, F, error, T), Items).

		 /*******************************
		 *            TABLES            *
		 *******************************/

%   A rule table. When every condition column tests one attribute (a header)
%   with constants, and every conclusion is a constant, it is an LE decision
%   table, first match (OIA's rows are read top down, an empty row the
%   `Else`), one per conclusion column; otherwise an `otherwise` cascade.
%   Several conclusion columns give several rules: `<label>_<column>`.
table_items(Types, Label, Prov, CCols, Concls, Items) :-
    length(Concls, NC),
    (   decision_table_shape(CCols, Concls)
    ->  findall(Is, ( nth1(I, Concls, Concl), col_label(NC, Label, I, L),
                      ( NC =:= 1 -> format(atom(TName), '~w_1', [L]) ; TName = L ),
                      dtable_items(Types, L, TName, Prov, CCols, Concl, Is) ), Iss),
        append(Iss, Items)
    ;   findall(R, ( nth1(I, Concls, Concl), col_label(NC, Label, I, L),
                     instance_rule(cascade_rule(Types, L, Prov, CCols, Concl), R) ), Items)
    ).

col_label(1, Label, _, Label) :- !.
col_label(_, Label, I, L) :- format(atom(L), '~w_~w', [Label, I]).

decision_table_shape(CCols, Concls) :-
    CCols \== [],
    forall(member(col(H, Cells), CCols),
           ( H = att(K), value_tpl(K), forall(member(C, Cells), table_cell(C, _)) )),
    forall(member(concl(K, Vs), Concls),
           ( K \= rel(_), value_tpl(K), last(Vs, Last),
             append(Init, [Last], Vs),
             forall(member(V, Init), const(V, _)),
             ( const(Last, _) ; Last == uncertain_value ) )).

table_cell(empty, any).
table_cell(op(equals, [E]), C) :- const(E, C).
table_cell(op(Tag, [E]), cond(Op-C)) :-
    memberchk(Tag-Op, ['not-equals'-'!=', 'greater-than'-'>', 'greater-than-equals'-'>=',
                       'less-than'-'<', 'less-than-equals'-'<=']),
    const(E, C).

dtable_items(Types, Label, TName0, Prov, CCols, concl(K, Vals), [Table|Rules]) :-
    findall(HK, member(col(att(HK), _), CCols), InKeys),
    %  the columns named as the Excel sheet heads them: by the attributes
    %  they test and conclude ("organization country id", not "id")
    maplist(heading_noun(Types), InKeys, InNouns),
    heading_noun(Types, K, OutNoun),
    table_name(OutNoun, TName0, TName),
    distinct_nouns([OutNoun|InNouns], [OutSlot|InSlots]),
    atomic_list_concat(InSlots, '* with *', InS),
    format(atom(TText), 'table ~w for *~w* gives *~w*', [TName, InS, OutSlot]),
    format(atom(TF), 't_~w', [TName]),
    assertz(tpl(TName, TF, table, TText)),
    findall(Row, table_row(CCols, Vals, Row), Rows),
    maplist(slot_word, [OutSlot|InSlots], [OutH|Hs]),
    append([[row], Hs, [OutH]], Header),
    Table = table(TName, [policy(first), provenance(Prov)], Header, Rows),
    findall(R, instance_rule(dtable_rule(Label, Prov, InKeys, TF, K), R), Rules).

dtable_rule(Label, Prov, InKeys, TF, K, rule(H, B, [label(Label), provenance(Prov)])) :-
    length(InKeys, NIn), length(Vars, NIn),
    maplist(val_goal, InKeys, Vars, InGoals),
    append(Vars, [X], TArgs), TG =.. [TF|TArgs],
    val_goal(K, X, H),
    append(InGoals, [TG], BGs), conj(BGs, B).

%   The value template of an attribute, in the current instance context: an
%   entity attribute has one only inside a table of its entity.
value_tpl(K) :-
    (   tpl(K, _, value, _) -> true
    ;   b_getval(oia_instance, Ctx), Ctx \== none,
        ( tpl(K, _, evalue, _) -> true ; instance_entity(Ctx, E), ent(E, _, K, _) )
    ).

instance_entity(entity(E), E).
instance_entity(_-E, E).

%   `the branch id is V` / `the carrier id of X is V`.
val_goal(K, V, G) :-
    (   b_getval(oia_instance, X-E), ent(E, _, K, _) -> V = X, G = true   % the instance itself
    ;   tpl(K, F, evalue, _), b_getval(oia_instance, X-_) -> G =.. [F, X, V]
    ;   tpl(K, _, value, _) -> klit(K, value, [V], G)
    ).

table_row(CCols, Vals, [RowId|Cells]) :-
    nth1(R, Vals, V), V \== uncertain_value,
    format(atom(RowId), 'r~w', [R]),
    findall(C, ( member(col(_, Cs), CCols), nth1(R, Cs, Cell), table_cell(Cell, C) ), InCells),
    const(V, Out),
    append(InCells, [Out], Cells).

%   A column header: the slot's noun (`second id`), without its article.
slot_word(Slot, W) :- atomic_list_concat([_|Ws], ' ', Slot), atomic_list_concat(Ws, ' ', W).

key_noun(Types, K, N) :- oia_attr_noun(Types, K, N).

%   A table column's heading: the attribute's own name, the words of its
%   sentence before the first place (`the organization country id is *an
%   id*` gives `organization country id`, `the carrier id of *a decision* is
%   *an id*` gives `carrier id`), else the noun of its value slot.
heading_noun(Types, K, N) :-
    (   ( tpl(K, _, value, T) ; tpl(K, _, evalue, T) ),
        sub_atom(T, B, _, _, '*'), !,
        sub_atom(T, 0, B, _, Before0),
        normalize_space(atom(Before1), Before0),
        atomic_list_concat(Ws0, ' ', Before1),
        exclude(==(''), Ws0, Ws1),
        ( Ws1 = [the|Ws2] -> true ; Ws2 = Ws1 ),
        ( append(Ws3, [Last], Ws2), memberchk(Last, [is, of, are]) -> true ; Ws3 = Ws2 ),
        ( append(Ws4, [Last2], Ws3), memberchk(Last2, [is, of, are]) -> true ; Ws4 = Ws3 ),
        Ws4 \== [],
        forall(member(W, Ws4), ( atom(W), \+ sub_atom(W, _, _, _, '"'), \+ sub_atom(W, _, _, _, '*') )),
        atomic_list_concat(Ws4, ' ', N0), downcase_atom(N0, N)
    ->  true
    ;   oia_attr_noun(Types, K, N)
    ).

%   A table named by what it concludes (`notification_type_table`), unless
%   another table already is.
table_name(OutNoun, Fallback, Name) :-
    atomic_list_concat(Ws, ' ', OutNoun),
    atomic_list_concat(Ws, '_', Base0),
    atom_codes(Base0, BCs0), include([C]>>( code_type(C, alnum) ; C == 0'_ ), BCs0, BCs), atom_codes(Base, BCs),
    atom_concat(Base, '_table', Name0),
    (   \+ tpl(Name0, _, table, _), Name0 \== '_table' -> Name = Name0 ; Name = Fallback ).


%   The noun of the value slot (the last one: `the carrier id of *a
%   decision* is *an id*`).
oia_attr_noun(_, K, N) :-
    ( tpl(K, _, value, T) ; tpl(K, _, evalue, T) ),
    atomic_list_concat(Parts, '*', T), length(Parts, NP), NP >= 3,
    NS is NP - 1, nth1(NS, Parts, Slot0),
    atomic_list_concat([_|Ws], ' ', Slot0), atomic_list_concat(Ws, ' ', N), !.
oia_attr_noun(_, K, N) :- ent(_, _, K, N), !.
oia_attr_noun(_, _, value).

%   Distinct slot nouns: `a value`, `a second value`...
distinct_nouns(Ns, Slots) :-
    foldl(noun_step, Ns, []-[], _-Rev),
    reverse(Rev, Slots).

noun_step(N, C0-Acc, C1-[S|Acc]) :-
    ( select(N-K0, C0, C2) -> K is K0 + 1 ; K = 1, C2 = C0 ),
    C1 = [N-K|C2],
    ordinal_slot(K, N, S).

ordinal_slot(1, N, S) :- !, ( sub_atom(N, 0, 1, _, C), memberchk(C, [a, e, i, o, u]) -> A = an ; A = a ), format(atom(S), '~w ~w', [A, N]).
ordinal_slot(K, N, S) :- nth1(K, [first, second, third, fourth, fifth, sixth, seventh, eighth, ninth, tenth], O), !, format(atom(S), 'a ~w ~w', [O, N]).
ordinal_slot(K, N, S) :- format(atom(S), 'a ~w ~w', [N, K]).

%   A table of an entity is read for each instance: the rule's first
%   condition names it (`the decision identifies the aggregation decision
%   details`), and the entity's own attributes in the rows are that
%   instance's. The context (global oia_instance) is `none`, entity(E) while
%   a table of E is translated, or X-E while one of its rules is built, X
%   the instance variable.
:- meta_predicate instance_rule(1, -).
instance_rule(Build, Rule) :-
    b_getval(oia_instance, Ctx),
    (   Ctx = entity(E)
    ->  tpl(inst(E), IF, instance, _),
        ( chain(E, _, _, _, _) -> IG = true ; IG =.. [IF, X] ),   % a chain's rules hold of any index
        b_setval(oia_instance, X-E),
        (   call(Build, rule(H, B0, O))
        ->  b_setval(oia_instance, entity(E))
        ;   b_setval(oia_instance, entity(E)), fail
        ),
        conj([IG, B0], B),
        Rule = rule(H, B, O)
    ;   call(Build, Rule)
    ).

%   A table concluding a relationship infers its instances: unlike a table
%   concluding an attribute, every row whose condition holds adds one (two
%   errors can be raised at once), so the rows are alternatives, not a
%   first-match cascade.
%   (A loop, not findall/3: the alternatives share the head's variable.)
cascade_rule(Types, Label, Prov, CCols, concl(rel(R), Vals), rule(H, B, Opts)) :- !,
    rel(R, E, _), tpl(inst(E), IF, instance, _),
    H =.. [IF, X],
    length(Vals, NR), numlist(1, NR, Rs),
    foldl(instance_row(Types, Vals, CCols, X), Rs, [], Rev),
    reverse(Rev, Alts), Alts \== [],
    disj(Alts, B),
    table_opts(Label, Prov, CCols, Opts).
cascade_rule(Types, Label, Prov, CCols, concl(K, Vals), rule(H, otherwise(Alts), Opts)) :-
    length(Vals, NR),
    numlist(1, NR, Rs),
    foldl(cascade_row(Types, K, Vals, NR, CCols, H), Rs, [], Rev),
    reverse(Rev, Alts),
    Alts \== [],
    table_opts(Label, Prov, CCols, Opts).

instance_row(Types, Vals, CCols, X, R, Acc, Out) :-
    nth1(R, Vals, V),
    (   V == uncertain_value -> Out = Acc
    ;   row_condition(CCols, R, RC),
        body(Types, RC, B0),
        const(V, C), conj([B0, le_equal_to(X, C)], Alt),
        Out = [Alt|Acc]
    ).

cascade_row(Types, K, Vals, NR, CCols, H, R, Acc, Out) :-
    nth1(R, Vals, V),
    row_condition(CCols, R, RC),
    cascade_alt(Types, K, V, R, NR, RC, Alt, H),
    ( Alt == none -> Out = Acc ; Out = [Alt|Acc] ).

row_condition(CCols, R, and(Cs)) :-
    findall(C, ( member(col(H, Cells), CCols), nth1(R, Cells, Cell), cell_condition(H, Cell, C) ), Cs).

cell_condition(_, empty, true).
cell_condition(_, cond(E), E).
cell_condition(H, op(Tag, [E]), C) :-
    binary_tag(Tag, Op), C =.. [Op, H, E].

binary_tag(equals, eq). binary_tag('not-equals', ne). binary_tag('greater-than', gt).
binary_tag('greater-than-equals', ge). binary_tag('less-than', lt). binary_tag('less-than-equals', le).

%   One alternative of the cascade: the row's condition, then the row's
%   value. A boolean conclusion column: `true` concludes, `false` stops the
%   cascade; an uncertain value concludes nothing (a last row is dropped).
cascade_alt(Types, K, V, R, NR, RC, Alt, H) :-
    body(Types, RC, B00),
    instance_test_first(B00, B0),
    (   ( tpl(K, _, boolean, _) ; tpl(K, _, ebool, _) )
    ->  klit(K, boolean, [], H),
        (   V == true -> Alt = B0
        ;   V = cond(C)
        ->  %  the row concludes whether C holds (a Hub table's cell
            %  "the person's gross income > $12,950")
            body(Types, C, BC), conj([B0, BC], Alt)
        ;   R =:= NR -> Alt = none
        ;   conj([B0, prolog(fail)], Alt)
        )
    ;   val_goal(K, X, H),
        (   V == uncertain_value
        ->  ( R =:= NR -> Alt = none ; conj([B0, prolog(fail)], Alt) )
        ;   value_term(Types, V, GV, TV), assign_result(X, TV, GV, BV),
            conj([B0, BV], Alt)
        )
    ).

%   In an alternative of a cascade over an entity's instances, the test of
%   the instance's identifying value is written constant first ("1-DCTA-
%   EVENT-MISSING" is equal to the code): LE leaves a conjunct `V is equal
%   to C` whose V no other conjunct of the alternative mentions out of the
%   next alternative's guard, taking it for an output (le_summary.md §17.2)
%   — but the instance is bound by the rule already, and the test must
%   stay in the guard, or a later row never applies to another instance.
instance_test_first(B0, B) :-
    (   b_getval(oia_instance, X-_), var(X)
    ->  swap_instance_test(X, B0, B)
    ;   B = B0
    ).

swap_instance_test(X, G0, G) :-
    (   var(G0) -> G = G0
    ;   G0 = le_equal_to(Y, C), Y == X, nonvar(C) -> G = le_equal_to(C, X)
    ;   compound(G0), G0 =.. [F|As0], memberchk(F, [and, or, not])
    ->  maplist(swap_instance_test(X), As0, As), G =.. [F|As]
    ;   G = G0
    ).

table_templates(Items) :-
    findall(template(F, T, []), tpl(_, F, table, T), Items).

		 /*******************************
		 *           RESIDUE            *
		 *******************************/

residue_items(Label, Doc, Name, Tree, Why, [residue(Label, [title(Title), locator(Loc), source(xml, Src), note(Note)])]) :-
    format(atom(Title), '~w', [Name]),
    format(atom(Loc), '~w, rule ~w', [Doc, Label]),
    format(string(Note), "not translated: ~q", [Why]),
    ( Tree = unsupported(Src0) -> Src = Src0 ; format(string(Src), "~q", [Tree]) ).

		 /*******************************
		 *          DOCUMENTS           *
		 *******************************/

doc_items(Docs, Items) :-
    findall(document(D, [text(P)]),
            ( member(doc(D, Paras), Docs), Paras \== [], doc_text_path(D, P) ),
            Items).

doc_text_path(D, P) :- doc_slug(D, S), format(atom(P), 'sources/~w.txt', [S]).

		 /*******************************
		 *         SOURCE TESTS         *
		 *******************************/

%   Every test case: its inputs as facts, its expected values as
%   expectations of one query per expected attribute.
source_tests(Sheets, Attrs, Types, Tests, Queries) :-
    findall(K, ( member(file(_, Cases), Sheets), member(C, Cases),
                 get_dict(expected, C, Ex), dict_pairs(Ex, _, Ps), member(H-V, Ps), \+ is_list(V),
                 attr_key_named(Attrs, H, K),
                 ( tpl(K, _, boolean, _) ; tpl(K, _, value, _) ) ), Ks0),
    list_to_set(Ks0, QKeys),
    findall(query(QN, Goal), ( member(K, QKeys), query_of(K, QN, Goal) ), Queries),
    findall(T, ( member(file(F, Cases), Sheets), member(C, Cases),
                 test_case(F, Cases, C, Attrs, Types, T) ), Tests).

%   A query per expected attribute, named after its words (letters only: a
%   digit or a wh-word in a query name does not read back).
query_of(K, QN, Goal) :-
    (   tpl(K, _, boolean, _) -> klit(K, boolean, [], Goal)
    ;   tpl(K, _, value, _), klit(K, value, [_], Goal)
    ),
    (   qname(K, QN) -> true
    ;   query_base_name(K, QN0), unique_qname(QN0, 1, QN), assertz(qname(K, QN))
    ).

unique_qname(B, N, QN) :-
    ( N =:= 1 -> Q = B ; nth1(N, [x, b, c, d, e, f, g, h, i, j, k, l], S), atomic_list_concat([B, S], '_', Q) ),
    ( qname(_, Q) -> N1 is N + 1, unique_qname(B, N1, QN) ; QN = Q ).

query_base_name(K, QN) :-
    atomic_list_concat(Ws00, ' ', K),
    include(query_word, Ws00, Ws01),
    findall(W, ( member(W0, Ws01), qword(W0, W) ), Ws1),
    ( length(Ws1, N), N > 7 -> length(Ws2, 7), append(Ws2, _, Ws1) ; Ws2 = Ws1 ),
    ( Ws2 == [] -> Ws = [result] ; Ws = Ws2 ),
    atomic_list_concat([q|Ws], '_', QN0),
    atom_codes(QN0, Cs0), include(query_code, Cs0, Cs), atom_codes(QN, Cs).

query_word(W) :- \+ memberchk(W, [the, a, an, which, what, who, is, of]).

%   A word of a query name: letters only, a digit spelled out.
qword(W0, W) :-
    atom_codes(W0, Cs0), include(code_alpha_or_digit, Cs0, Cs), Cs \== [],
    (   forall(member(C, Cs), code_type(C, digit))
    ->  atom_codes(A, Cs), atom_number(A, N),
        ( nth0(N, [zero,one,two,three,four,five,six,seven,eight,nine,ten], W) -> true ; W = n )
    ;   include(code_alpha, Cs, Cs1), atom_codes(W, Cs1)
    ).
code_alpha_or_digit(C) :- code_type(C, alnum).
code_alpha(C) :- code_type(C, alpha).
query_code(C) :- ( code_type(C, alpha) ; C == 0'_ ).


%   A case is named by its Test Case cell, or by its row when that is
%   missing or not unique in the file.
test_case(File, Cases, C, Attrs, Types, test(Id, Doc, Loc, Facts, Expects)) :-
    file_base_name(File, Doc),
    get_dict(row, C, Row),
    (   get_dict(id, C, Id0), \+ ( member(C2, Cases), C2 \== C, get_dict(id, C2, Id2), Id2 == Id0 )
    ->  format(atom(Loc), 'test case ~w', [Id0])
    ;   format(atom(Id0), 'row~w', [Row]), format(atom(Loc), 'row ~w', [Row])
    ),
    file_name_extension(Base, _, Doc), doc_slug(Base, Slug),
    (   sub_atom(Base, _, _, 0, '_request')            % an Assess exchange: named by its case
    ->  format(atom(Id), 'assess_~w', [Id0])
    ;   format(atom(Id), '~w_~w', [Slug, Id0])
    ),
    get_dict(inputs, C, InD), dict_pairs(InD, _, Ins),
    findall(Fact, ( member(H-V, Ins), \+ is_list(V), attr_key_named(Attrs, H, K), input_fact(Types, K, V, Fact) ), Facts1),
    findall(Fact, ( member(H-V, Ins), is_list(V), instance_facts(Attrs, Types, H, V, Fs), member(Fact, Fs) ), Facts2),
    append(Facts1, Facts2, Facts0),
    list_to_set(Facts0, Facts),
    get_dict(expected, C, ExD), dict_pairs(ExD, _, Exps),
    findall(E, ( member(H-V, Exps), \+ is_list(V), attr_key_named(Attrs, H, K), expectation(Types, K, V, E) ), Expects0a),
    findall(E, ( member(H-V, Exps), is_list(V), instance_expectations(Attrs, Types, H, V, E) ), Expects0b),
    append(Expects0a, Expects0b, Expects0),
    (   known_divergence(Id, Why)
    ->  findall(pending(Why, E), member(E, Expects0), Expects)
    ;   Expects = Expects0
    ).

%   A source expectation the twin departs from in a documented way (an
%   approximated element of the ledger): kept, as a pending expectation with
%   its reason, rather than a test the twin fails by design.
known_divergence(witholding_amount_5,
    'approximated — the source leaves an input uncertain, which in Oracle Intelligent Advisor stops the rule table; the closed-world twin falls through to the next row').


%   A test names an attribute by its text (as Excel test files head their
%   columns) or by its public name (as an Assess call does).
attr_key_named(Attrs, H, K) :-
    oia_key(H, K0),
    atom_string(HA, H),
    (   memberchk(K0, ['current date', 'currentdate', 'today']), tpl(current_date, _, current_date, _) -> K = current_date
    ;   member(attr(K, _, _, _, Fs), Attrs), ( memberchk(public(HA), Fs) ; memberchk(id(HA), Fs) ) -> true
    ;   memberchk(attr(K0, _, _, _, _), Attrs) -> K = K0
    ;   K = K0
    ).

%   A relationship named by a test: its id or public name, its text, or its
%   entity's plural.
rel_named(H, R) :-
    atom_string(HA, H), oia_key(H, HK),
    (   rel(HA, _, _) -> R = HA
    ;   ent(HA, _, _, _), rel_info(R, global, HA, _, _, _, true) -> true      % an entity by its id (SOAP Assess)
    ;   rel(R, _, RT), oia_key(RT, HK) -> true
    ;   rel(R, E, _), ent(E, _, _, Noun), plural_noun(Noun, P), oia_key(P, HK) -> true
    ).

%   The facts of a relationship's instances: each instance is one of them,
%   named by its identifying value or else its "@id", and its attributes.
instance_facts(Attrs, Types, H, Instances, Facts) :-
    rel_named(H, R), rel_target(R, E),
    tpl(inst(E), IF, instance, _),
    findall(F, ( member(I, Instances), instance_name(E, Attrs, I, Name),
                 (   \+ inferred(E), F =.. [IF, Name]
                 ;   dict_pairs(I, _, Ps), member(AH-AV, Ps), AH \== '@id', \+ is_list(AV),
                     attr_key_named(Attrs, AH, K), \+ ent(E, _, K, _),
                     entity_fact(Types, K, Name, AV, F)
                 ) ),
            Facts).

instance_name(E, Attrs, I, Name) :-
    (   ent(E, _, IdKey, _), IdKey \== none,
        dict_pairs(I, _, Ps), member(AH-AV, Ps), attr_key_named(Attrs, AH, IdKey)
    ->  typed_value([], IdKey, AV, Name)
    ;   get_dict('@id', I, Id) -> safe_string(Id, Name)
    ).

entity_fact(Types, K, Name, V, F) :-
    (   tpl(K, EF, ebool, _) -> V == true, F =.. [EF, Name]
    ;   tpl(K, EF, evalue, _), V \== null, typed_value(Types, K, V, TV), F =.. [EF, Name, TV]
    ).

%   Expected attributes of instances: one expectation per attribute, its
%   answers the instances' values.
instance_expectations(Attrs, Types, H, Instances, expects(QN, As)) :-
    rel_named(H, R), rel_target(R, E),
    findall(K, ( member(I, Instances), dict_pairs(I, _, Ps), member(AH-_, Ps), AH \== '@id',
                 attr_key_named(Attrs, AH, K), \+ ent(E, _, K, _) ), Ks0),
    list_to_set(Ks0, Ks), member(K, Ks),
    entity_query(K, QN),
    findall(A, ( member(I, Instances), instance_name(E, Attrs, I, Name),
                 dict_pairs(I, _, Ps), member(AH-AV, Ps), attr_key_named(Attrs, AH, K),
                 entity_answer(Types, K, Name, AV, A) ), As).

entity_query(K, QN) :-
    (   qname(K, QN) -> true
    ;   query_base_name(K, QN0), unique_qname(QN0, 1, QN), assertz(qname(K, QN)),
        ( tpl(K, F, evalue, _) -> G =.. [F, _, _] ; tpl(K, F, ebool, _), G =.. [F, _] ),
        assertz(extra_query(query(QN, G)))
    ).

entity_answer(Types, K, Name, V, A) :-
    (   tpl(K, F, ebool, _) -> V == true, ground_answer(F, [Name], A)
    ;   tpl(K, F, evalue, _), V \== null, typed_value(Types, K, V, TV), ground_answer(F, [Name, TV], A)
    ).

input_fact(_, current_date, V, F) :- !,         % the case's current date (OIA's CurrentDate())
    tpl(current_date, CF, current_date, _), string(V), date_string(V, D), F =.. [CF, D].
input_fact(_, K, V, F) :-
    tpl(K, _, boolean, _), !,
    klit(K, boolean, [], G),
    (   V == true -> F = G
    ;   V == false -> tpl(K, _, opposite, _), \+ derived(K), F = not(G)
    ;   V == "(uncertain)" -> klit(K, uncertain, [], F)
    ;   fail
    ).
input_fact(Types, K, V, F) :-
    tpl(K, _, value, _), !,
    (   V == "(uncertain)" -> klit(K, uncertain, [], F)
    ;   V == "(unknown)" -> fail
    ;   typed_value(Types, K, V, TV), klit(K, value, [TV], F)
    ).

typed_value(Types, K, V, TV) :-
    type_of(Types, K, T),
    (   memberchk(T, [date, datetime]), string(V), date_string(V, D) -> TV = D
    ;   memberchk(T, [number, currency]), number(V) -> TV = V
    ;   memberchk(T, [number, currency]), string(V), number_string(N, V) -> TV = N
    ;   string(V) -> safe_string(V, TV)
    ;   number(V) -> ( T == text -> number_string(V, S), TV = S ; TV = V )
    ;   V == true -> TV = "true"
    ;   V == false -> TV = "false"
    ;   format(string(TV), "~w", [V])
    ).

%   A text as the twin writes it: as the source has it. (Until 15 October
%   2026 a straight apostrophe became a typographic one, for an LE
%   tokenizer that no longer needs it — and the text a rule builds, HTML
%   with class='cya-question' in it, must be the source's to the byte.)
safe_string(S0, S) :- atom_string(S0, S).

%   The expected value, as the answer the twin must give — or no answer,
%   for `false`, `(unknown)` and `(uncertain)` (the closed world reads them
%   alike: an approximation the ledger records).
expectation(_, K, V, expects(QN, As)) :-
    tpl(K, _, boolean, _), !, query_of(K, QN, _),
    ( V == true -> klit(K, boolean, [], G), As = [G] ; As = [] ).
expectation(Types, K, V, expects(QN, As)) :-
    tpl(K, _, value, _), !, query_of(K, QN, _),
    (   memberchk(V, ["(unknown)", "(uncertain)"]) -> As = []
    ;   typed_value(Types, K, V, TV),
        answer_string(K, TV, A), As = [A]
    ).

%   The expected answer as the engine renders it: numbers printed by LE
%   itself (le_kbs:canonical_string/2: 7.0e+04, 30333.333333333332), not by
%   the writer's fixed-point format.
answer_string(K, TV, S) :-
    (   ( number(TV) ; string(TV) ; TV = date(_, _, _) )
    ->  klit(K, value, [zzqqnum], A0),
        answer_dicts(Dicts),
        le_writer:render_ground_literal(Dicts, A0, T0),
        le_kbs:canonical_string([TV], NS),
        atomic_list_concat(Parts, zzqqnum, T0), atomic_list_concat(Parts, NS, S0),
        atom_string(S0, S)
    ;   klit(K, value, [TV], S)
    ).

answer_dicts(Dicts) :-
    findall(template(F, T, []), ( tpl(_, F, Kind, T), memberchk(Kind, [value, boolean]) ), Items),
    le_writer:ir_dicts(program([], Items), Dicts).

		 /*******************************
		 *  TESTS FROM THE RULES' OWN   *
		 *          ANALYSIS            *
		 *******************************/

%   A project without test files: its cases derived from its rules
%   (oia_analysis.pl) — the paths to each goal and their near misses, every
%   expected outcome computed by the analysis' own evaluator of the OIA
%   model, not by the twin. Cited as the analysis of the rules.
analysis_tests(Model, Types, Tests, Queries) :-
    analysis_cases(Model, Types, [], Cases),
    findall(T, ( member(C, Cases), analysis_test(Types, C, T) ), Tests),
    findall(QN, ( member(test(_, _, _, _, Es), Tests), member(expects(QN, _), Es) ), QNs0),
    list_to_set(QNs0, QNs),
    findall(query(QN, G), ( member(QN, QNs), qname(K, QN), query_goal(K, G) ), Queries).

unique_queries(Qs0, Qs) :-
    foldl(unique_query, Qs0, []-[], _-Rev), reverse(Rev, Qs).
unique_query(query(N, G), Seen-Acc, Seen1-Acc1) :-
    (   memberchk(N, Seen) -> Seen1 = Seen, Acc1 = Acc
    ;   Seen1 = [N|Seen], Acc1 = [query(N, G)|Acc]
    ).

query_goal(inst(E), G) :- !, tpl(inst(E), IF, instance, _), G =.. [IF, _].
query_goal(K, G) :- tpl(K, F, evalue, _), !, G =.. [F, _, _].
query_goal(K, G) :- query_of(K, _, G).

analysis_doc('the analysis of the rules').

analysis_test(Types, case(Id, Loc, Inputs, Outcomes), test(Id, Doc, none, [comment(Cm)|Facts], Expects)) :-
    analysis_doc(Doc),
    format(string(Cm), "~w (generated from the rules, expected outcomes by an evaluator of the OIA model)", [Loc]),
    findall(K-V, ( member(K-V, Inputs), V \== unknown ), KVs0),
    predsort(by_template_order, KVs0, KVs),
    findall(F, ( member(K-V, KVs), json_value(V, JV), input_fact(Types, K, JV, F) ), Facts),
    findall(E, ( member(O, Outcomes), outcome_expect(Types, O, E) ), Expects),
    Expects \== [].

%   The facts in the order of the templates (a1, a2, ... a10).
by_template_order(Ord, K1-_, K2-_) :-
    tpl_rank(K1, R1), tpl_rank(K2, R2),
    compare(Ord0, R1-K1, R2-K2), ( Ord0 == (=) -> Ord = (<) ; Ord = Ord0 ).

tpl_rank(K, R) :-
    (   tpl(K, F, Kind, _), memberchk(Kind, [boolean, value]),
        sub_atom(F, 1, _, 0, NA), atom_number(NA, R0) -> R = R0
    ;   R = 1000000
    ).

json_value(true, true).
json_value(false, false).
json_value(unknown, "(unknown)").
json_value(str(S), S).
json_value(num(N), N).
json_value(date(Y, M, D), S) :- format(string(S), "~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, D]).

outcome_expect(Types, K-V, E) :- atom(K), !,
    json_value(V, JV), expectation(Types, K, JV, E).
outcome_expect(_, inst(E)-Ids, expects(QN, As)) :- !,
    qname(inst(E), QN), tpl(inst(E), IF, instance, _),
    findall(A, ( member(Id, Ids), plain(Id, P), ground_answer(IF, [P], A) ), As).
outcome_expect(_, ek(_, K)-IVs, expects(QN, As)) :-
    qname(K, QN), tpl(K, F, evalue, _),
    findall(A, ( member(Id-V, IVs), V \== unknown, plain(Id, PI), plain(V, PV),
                 ground_answer(F, [PI, PV], A) ), As).

plain(str(S), S) :- !.
plain(num(N), N) :- !.
plain(date(Y, M, D), date(Y, M, D)) :- !.
plain(X, X).

%   An answer as the engine renders it: the literal through its template,
%   each argument printed by LE itself.
ground_answer(F, Args, S) :-
    length(Args, N), numlist(1, N, Is),
    maplist(placeholder, Is, Ps),
    L =.. [F|Ps],
    answer_dicts_all(Dicts),
    le_writer:render_ground_literal(Dicts, L, T0),
    pairs_keys_values(PAs, Ps, Args),
    foldl(subst_arg, PAs, T0, T),
    atom_string(T, S).

placeholder(I, P) :- format(atom(P), 'zzqqa~w', [I]).

subst_arg(P-A, T1, T2) :-
    le_kbs:canonical_string([A], AS),
    atomic_list_concat(Parts, P, T1), atomic_list_concat(Parts, AS, T2).

answer_dicts_all(Dicts) :-
    findall(template(F, T, []), ( tpl(_, F, Kind, T), memberchk(Kind, [value, boolean, evalue, instance]) ), Items),
    le_writer:ir_dicts(program([], Items), Dicts).

		 /*******************************
		 *             VIEW             *
		 *******************************/

%   The interview as a View: the input attributes asked one at a time, the
%   top goal as the result (§17.10).
view_item(Title, Attrs, _Types, Rules, Queries, _Sheets, [view(interview, Sentences)|QItems]) :-
    %  the result: the goal attribute, else (a project whose decisions are
    %  entity instances) the instances the case raises
    (   goal_key(Rules, Queries, GK) -> true
    ;   qname(inst(_), IQN), memberchk(query(IQN, _), Queries) -> GK = query(IQN)
    ),
    findall(I, ( member(attr(K, _, _, _, _), Attrs), \+ derived(K), instance_text(K, I) ), Ins0),
    list_to_set(Ins0, Ins),
    Ins \== [], !,
    format(atom(S1), 'the title is "~w".', [Title]),
    atomic_list_concat(Ins, ',\n        ', InT),
    format(atom(S2), 'the facts about "the case" are\n        ~w.', [InT]),
    (   GK = query(QN0)
    ->  format(atom(S3), 'the result is the answer to query ~w.', [QN0])
    ;   tpl(GK, _, boolean, _), disp(GK, GT)
    ->  format(atom(S3), 'the result is whether ~w.', [GT])
    ;   query_of(GK, QN, QG), format(atom(S3), 'the result is the answer to query ~w.', [QN])
    ),
    (   nonvar(QN), \+ memberchk(query(QN, _), Queries) -> QItems = [query(QN, QG)] ; QItems = [] ),
    findall(Q, ( member(attr(K, _, _, _, Fs), Attrs), \+ derived(K), memberchk(question(QT0), Fs),
                 instance_text(K, I), quote_text(QT0, QT),
                 format(atom(Q), 'the question for ~w is "~w".', [I, QT]) ), Qs),
    append([[S1, S2, 'the facts are asked one at a time.', S3, 'the result shows its reasons.',
             'the result can be flipped.'], Qs], Sentences).
view_item(_, _, _, _, _, _, []).

%   The result: the attribute the most expectations ask about, else a
%   conclusion no rule reads.
goal_key(_, Queries, K) :-
    member(query(_, G), Queries), functor(G, F, _), tpl(K, F, Kind, _), memberchk(Kind, [boolean, value]), !.
goal_key(Rules, _, K) :-
    member(rule(_, _, _, _, conclude(K, _, _, _, _)), Rules),
    \+ ( member(rule(_, _, _, _, T), Rules),
         ( sub_term(att(K), T) ; sub_term(inline(conclude(K, _, _, _, _)), T) ) ), !.

instance_text(K, I) :-
    (   tpl(K, _, boolean, _), disp(K, T) -> I = T
    ;   tpl(K, _, value, _), disp(K, T),
        sub_atom(T, B, _, _, '*'), sub_atom(T, 0, B, _, Pre), B1 is B + 1,
        sub_atom(T, B1, _, 1, Slot), atom_concat(Pre, Slot, I)
    ).

		 /*******************************
		 *            LEDGER            *
		 *******************************/

ledger_rows(Attrs, Types, Used, Sheets, Runs, Ledger) :-
    findall(entry(E, attribute, V, M, In, N),
            ( member(attr(K, Text, _, _, _), Attrs),
              type_of(Types, K, T),
              format(atom(E), '~w', [Text]),
              (   memberchk(K, Used), ( tpl(K, F, boolean, TT) ; tpl(K, F, value, TT) ; tpl(K, F, evalue, TT) )
              ->  V = encoded,
                  ( T == boolean -> M = 'boolean attribute -> template' ; format(atom(M), '~w attribute -> value template', [T]) ),
                  format(atom(In), 'template "~w"', [TT]),
                  ( tpl(K, _, opposite, Neg) -> format(atom(N), 'opposite: ~w', [Neg]) ; N = none ), F = F
              ;   ent(Ent, _, K, _), tpl(inst(Ent), _, instance, IT)
              ->  V = encoded, M = 'identifying attribute -> the instance itself',
                  format(atom(In), 'template "~w"', [IT]), N = none
              ;   V = encoded, M = 'attribute no rule reads', In = '(not declared)', N = 'screen or form data'
              ) ),
            AttrRows0),
    findall(entry(E, entity, encoded, 'entity -> instances named by their identifying value', In, N),
            ( ent(Ent, ET, _, _), tpl(inst(Ent), _, instance, IT),
              format(atom(E), '~w', [ET]), format(atom(In), 'template "~w"', [IT]),
              ( rel(_, Ent, RT) -> format(atom(N), 'relationship: ~w', [RT]) ; N = none ) ),
            EntRows),
    findall(entry(Ph, role, encoded,
                  'a role of the global entity (the subject of its sentences) -> a typed place of those templates, and a named constant standing for the case''s one individual',
                  In, N),
            ( role(_, Ph, _),
              format(atom(In), 'constant "~w is \"~w\""', [Ph, Ph]),
              aggregate_all(count, K, ( attr_roles(K, Rs), memberchk(Ph, Rs) ), NK),
              format(atom(N), '~w attribute(s) speak about it', [NK]) ),
            RoleRows),
    append([AttrRows0, EntRows, RoleRows], AttrRows),
    findall(entry(E, rule, V, M, In, N), ledger(E, rule, V, M, In, N), RuleRows),
    findall(entry(F, 'test file', V, 'Excel test cases -> scenarios with expectations', 'scenarios', N),
            ( member(file(F0, Cases), Sheets), file_base_name(F0, F), length(Cases, NC),
              (   memberchk(run(F, Date, Total, Pass), Runs)
              ->  format(atom(N0), '~w case(s); OIA''s own run of ~w (testResults.xml): ~w of ~w passed', [NC, Date, Pass, Total])
              ;   format(atom(N0), '~w case(s)', [NC])
              ),
              (   member(C, Cases), get_dict(expected, C, Ex), dict_pairs(Ex, _, Ps),
                  member(_-U, Ps), memberchk(U, ["(unknown)", "(uncertain)"])
              ->  V = approximated,
                  atomic_list_concat([N0, '; an expected (unknown) or (uncertain) value is expected as no answer (closed world): where OIA''s unknown stops a rule table, the twin falls through to a later row and answers'], N)
              ;   V = encoded, N = N0
              ) ),
            TestRows),
    append([AttrRows, RuleRows, TestRows], Ledger).

%   testResults.xml, Policy Modeling's record of its own test run: one
%   run(File, Date, Total, Passed) per testing document.
source_runs(File, Runs) :-
    load_structure(File, DOM, [dialect(xml), space(remove)]),
    findall(run(F, Date, Total, Pass),
            ( member(element('policy-model', _, Docs), DOM),
              member(element('testing-document', A, _), Docs),
              memberchk(name=N0, A), atomic_list_concat(Ps, '\\', N0), last(Ps, F),
              memberchk(total=Total, A), memberchk(pass=Pass, A),
              ( memberchk(started=St, A), sub_atom(St, 0, 10, _, Date) -> true ; Date = '?' ) ),
            Runs).

ledger_rule(Doc, Id, Name, Tree, Items, Label) :-
    format(atom(E), '~w rule ~w: ~w', [Doc, Id, Name]),
    (   member(residue(_, _), Items)
    ->  V = residue, M = 'no mapping', In = Label,
        ( member(residue(_, O), Items), memberchk(note(N00), O) -> N0 = N00 ; N0 = none )
    ;   approximation(Tree, Why)
    ->  V = approximated, rule_mapping(Tree, Items, M), In = Label, N0 = Why
    ;   V = encoded, rule_mapping(Tree, Items, M), In = Label, N0 = none
    ),
    (   nb_current(oia_unread_constants, Unread), memberchk(Doc-Id, Unread)
    ->  Note = 'source: a conclusion with no conditions that no rule reads -- in the document, a paragraph in the conclusion style that is not a rule (a heading?); the twin states it as the source does, and the verifier reports it as a fact nothing reads',
        ( N0 == none -> N1 = Note ; atomic_list_concat([N0, '; ', Note], N1) )
    ;   N1 = N0
    ),
    assertz(ledger(E, rule, V, M, In, N1)).

rule_mapping(conclude(_, _, true, _, _), _, 'conclusion if conditions -> rule') :- !.
rule_mapping(conclude(_, _, false, _, _), _, 'negative conclusion -> rule concluding the opposite form') :- !.
rule_mapping(conclude(_, _, _, _, _), _, 'value conclusion -> relational arithmetic rule') :- !.
rule_mapping(table(_, _, Cs), _, 'relationship table -> the instances it infers (every matching row)') :-
    memberchk(concl(rel(_), _), Cs), !.
rule_mapping(table(E, _, _), Items, M) :- !,
    ( memberchk(table(_, _, _, _), Items) -> M0 = 'rule table -> LE decision table (first match)' ; M0 = 'rule table -> otherwise cascade' ),
    ( E == global -> M = M0 ; atom_concat(M0, ', per entity instance', M) ).
rule_mapping(event(_, _), _, 'error/warning event -> rule concluding the error') :- !.
rule_mapping(_, _, 'rule').

approximation(T, 'uncertain: a stated "it is uncertain whether" fact; with an unknown input the condition is read as false (closed world)') :-
    sub_term(uncertain(_), T), !.
approximation(T, 'known/unknown: a value is known when a fact states it; a boolean when it or its opposite is stated') :-
    ( sub_term(known(_), T) ; sub_term(unknown(_), T) ), !.
approximation(T, 'the current date is case data: OIA change points are not modelled (E3 scope)') :-
    ( sub_term(current_date, T) ; sub_term(temporal(_, _), T) ), !.
approximation(T, 'negation: an unknown input makes OIA''s `not` unknown, LE''s negation true (closed world)') :-
    sub_term(not(_), T), !.
approximation(T, 'not-equals: an unknown value makes the comparison false here, unknown in OIA') :-
    sub_term(ne(_, _), T), !.


		 /*******************************
		 *     THE ADAPTER'S MAPPING    *
		 *******************************/

%!  oia_adapter_map(+Model, +Options, -Map) is det.
%
%   What the OIA adapter (oia_adapter.pl) needs to answer an Oracle
%   Intelligent Advisor call with the twin just translated: for every
%   attribute, its public name (the name an Assess call or a decision
%   service's contract uses), its type, its entity, and the twin's template
%   for it — the sentence a fact about it is written in, and the places the
%   case's roles fill; for every entity, its public name, its relationship
%   and its instance template. Called right after oia_migration/4, whose
%   state (the templates it made) it reads; written beside the twin as
%   <name>.oia_map.json by oia_migrate.pl.
oia_adapter_map(Model, Opts, Map) :-
    Model = oia(Name, Attrs, _, Docs),
    option(title(Title), Opts, Name),
    Model = oia(_, _, Rules, _),
    findall(A, ( member(attr(K, Text, Ty0, Ent, Forms), Attrs), adapter_attr(Rules, K, Text, Ty0, Ent, Forms, A) ), As),
    findall(E, ( ent(Id, _, IdKey, _), adapter_entity(Id, IdKey, Attrs, Docs, E) ), Es),
    (   tpl(current_date, _, current_date, CDT) -> CD = CDT ; CD = null ),
    findall(R, role(_, R, _), Roles0), maplist(atom_string, Roles0, Roles),
    atom_string(Name, NS), format(string(TS), "~w", [Title]),
    deployment_names(Name, Title, Opts, Deps),
    Map = _{project: NS, title: TS, deployments: Deps, attributes: As, entities: Es,
            current_date_template: CD, roles: Roles}.

adapter_attr(Rules, K, Text, Ty0, Ent, Forms, A) :-
    (   tpl(K, _, Kind0, T), memberchk(Kind0, [boolean, value, ebool, evalue]) -> Kind = Kind0 ; fail ),
    public_name(K, Forms, Pub),
    ( attr_type_final(K, Ty0, Ty) -> true ; Ty = Ty0 ),
    ( disp(K, D) -> true ; D = T ),
    ( attr_roles(K, Rs0) -> maplist(atom_string, Rs0, Rs) ; Rs = [] ),
    ( tpl(K, _, opposite, O) -> Opp = O ; Opp = null ),
    ( derived(K) -> Der = true ; Der = false ),
    %  output: in a decision service's output contract (`contract`), or a
    %  conclusion; goal: a conclusion no rule reads (what a caller asks for)
    ( memberchk(output, Forms) -> Out = contract ; Out = Der ),
    (   Der == true, \+ ( member(rule(_, _, _, _, RT), Rules), \+ tree_concludes(RT, K), sub_term(att(K), RT) )
    ->  Goal = true ; Goal = false ),
    format(string(TextS), "~w", [Text]),
    atom_string(K, KS), atom_string(Ent, ES),
    A = _{key: KS, name: Pub, text: TextS, type: Ty, entity: ES, kind: Kind,
          template: T, display: D, roles: Rs, opposite: Opp, derived: Der, output: Out, goal: Goal}.

attr_type_final(K, _, Ty) :- tpl(K, _, Kind, _), memberchk(Kind, [boolean, ebool]), !, Ty = boolean.
attr_type_final(_, Ty0, Ty) :- ( Ty0 == auto -> Ty = text ; Ty = Ty0 ).

%   The public name: the data model's, a rulebase attribute's id, else the
%   attribute's words joined by underscores.
public_name(K, Forms, Pub) :-
    (   memberchk(public(P), Forms) -> atom_string(P, Pub)
    ;   memberchk(id(P), Forms) -> atom_string(P, Pub)
    ;   atomic_list_concat(Ws, ' ', K), atomic_list_concat(Ws, '_', P0),
        atom_codes(P0, Cs0), include([C]>>( code_type(C, alnum) ; C == 0'_ ), Cs0, Cs),
        atom_codes(P, Cs), atom_string(P, Pub)
    ).

adapter_entity(Id, IdKey, Attrs, _Docs, E) :-
    tpl(inst(Id), _, instance, IT),
    (   rel_info(R, global, Id, _, _, _, true) -> atom_string(R, RS) ; RS = null ),
    (   rel(R2, Id, RT), rel_info(R2, global, Id, _, _, _, true) -> format(string(RTS), "~w", [RT]) ; RTS = null ),
    (   IdKey \== none, member(attr(IdKey, _, _, _, Fs), Attrs) -> public_name(IdKey, Fs, IdPub) ; IdPub = null ),
    ( inferred(Id) -> Inf = true ; Inf = false ),
    atom_string(Id, IdS),
    E = _{id: IdS, relationship: RS, relationship_text: RTS, instance_template: IT,
          identifying_attribute: IdPub, inferred: Inf}.

%   The names a caller may deploy the twin under: the project's own name,
%   its title, and the title without spaces (Oracle's deployment names:
%   "SimpleBenefits", "doINeedToFile").
deployment_names(Name, Title, Opts, Deps) :-
    option(deployments(D0), Opts, []),
    format(atom(TA), "~w", [Title]),
    atomic_list_concat(Ws, ' ', TA), atomic_list_concat(Ws, '', Compact),
    append([[Name, TA, Compact], D0], Ds0), list_to_set(Ds0, Ds1),
    maplist(atom_string, Ds1, Deps).

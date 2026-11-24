/** <module> Blawx -> Logical English: the twin of a Blawx project

    the design notes roadmap.md §5.7 (the Blawx bullet) and
    §8, Phase 2c. A Blawx project (blawx_reader.pl) becomes a migration
    (le_migration.pl): the Migration IR of an LE program in the Act's own
    words, citing it section by section, the ledger, and the project's tests
    as scenarios whose expected answers are Blawx's own (oracle.py runs
    Blawx's reasoner on them).

    ## What Blawx generates, and what the twin says

      blawx_category(C) + #pred C(X)          template `*a thing* is a C` (the
                                              #pred wording)
      blawx_attribute(Cat, A, Type) + #pred   template in the #pred wording,
      blawx_relationship(R, T1, ...) + #pred  places typed by Cat / Type
      according_to(S, P, Xs) :- Body          a rule concluding P, `as stated
                                              in <the Act> at <section S>`
      holds(S, P, Xs) :- according_to(...)    plumbing: collapsed into the
      P(Xs) :- holds(S, P, Xs)                rules (the BLAWX CHECK
                                              DUPLICATES copies too)
      holds(S, P, Xs) :- according_to(...),   a defeasible conclusion: the
          not blawx_defeated(S, P, Xs)        rule's guard is `it is not the
      blawx_defeated(S, P, Xs) :-             case that <the defeater's
          holds(S2, P2, Ys)                   conclusion> under <section S2>`
      -P(Xs)                                  P's opposite form (`; opposite:`)
      holds(S, P, Xs) / according_to(S, P, Xs) in a body or a test:
                                              `<P's wording> under <S>`, a
                                              template of its own
      facts in a section                      facts citing the section
      false :- Body                           an integrity constraint, `it must
                                              not be true that …` (LE2
                                              le_summary.md §3.3)
      date(T), datetime(T), duration(T)       T, seconds since 1970 (UTC), as
                                              Blawx stores them
      date_add, date_compare, duration_compare, blawx_comparison, blawx_diseq
                                              arithmetic and comparisons
      blawx_as_of / blawx_during per          left out (no rule reads them);
      predicate (the temporal boilerplate)    events (blawx_becomes,
                                              blawx_initially, blawx_ultimately)
                                              are residue
      findall and Blawx's list aggregates     residue

    ## Defeasibility: the decision on this corpus (E2)

    Blawx states an override between *sections*, and on this corpus the
    sections that override one another conclude different things (`flies`
    against `-flies`; `may_accept` against `must_not_accept`), never
    alternatives of one conclusion. So `otherwise` (alternatives of one
    conclusion) does not fit, and a priority construct is not needed either:
    Blawx's own layer — each defeasible conclusion guarded by the failure of
    its defeaters, each defeater's conclusion held per section — is written as
    ordinary LE rules, with the section-scoped conclusions as templates of
    their own (`*a thing* can fly under *a provision*`). The guard is a
    negation as failure; a cycle of defeats (none in the corpus) would need
    the s(CASP) target and is reported.
*/

:- module(blawx_twin, [
    project_migration/4,         % +File, +Id, +Options, -Migration
    build_twin/4,                % +File, +Id, +OutRoot, -Report
    oracle_answers/4,            % +File, +Id, +Options, -Answers
    oracle_available/0,
    oracle_unavailable/1         % -Why
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(pairs)).
:- use_module(library(process)).
:- use_module(library(json)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module(blawx_reader).
:- use_module(blawx_cases).
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).

blawx_commit('3de892f67854292b304c9a55c5e2cd2058d3d418').
blawx_release('v1.6.22-alpha').
clock_date('2026-09-14').

		 /*******************************
		 *           THE TWIN           *
		 *******************************/

%!  build_twin(+File, +Id, +OutRoot, -Report) is det.
%
%   Writes OutRoot/Id/Id.le with its ledger and sources/ (the project file
%   and the Act's text).
build_twin(File, Id, Root, Report) :-
    atomic_list_concat([Root, '/', Id], Dir),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
    file_base_name(File, B),
    atomic_list_concat([SD, '/', B], Copy), copy_file(File, Copy),
    %  Blawx's MIT licence travels with the copy of its example
    here(H), format(atom(Lic), '~w/.cache/blawx/LICENSE', [H]),
    ( exists_file(Lic) -> atomic_list_concat([SD, '/BLAWX_LICENSE'], LicCopy), copy_file(Lic, LicCopy) ; true ),
    project_migration(File, Id, [dir(Dir), example(true)], Migration),
    write_migration(Migration, Dir, Id, Report).

%!  project_migration(+File, +Id, +Options, -Migration) is det.
%
%   Options: dir(Dir) — where the Act's text is written (sources/<Id>.md);
%   oracle(Answers) — the tests' answers, else computed by oracle.py;
%   example(true) — the project is one of the examples of Blawx itself
%   (build.pl): only then do the header and the ledger name Blawx's release,
%   its commit and its licence. A project that a user opens (File ▸ Open) is
%   the user's own, and nothing is said about its licence.
project_migration(File, Id, Opts, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    blawx_project(File, Project),
    Project = project(Title, RDName, RuleText, Sections, BTests),
    act_document(Title, Doc),
    file_base_name(File, FB),
    format(atom(ActText), 'sources/~w.md', [Id]),
    format(atom(ProjText), 'sources/~w', [FB]),
    (   option(dir(Dir), Opts)
    ->  atomic_list_concat([Dir, '/', ActText], AF),
        setup_call_cleanup(open(AF, write, S, [encoding(utf8)]), write(S, RuleText), close(S))
    ;   true
    ),
    collect(Sections, Decls, Clauses),
    predicates(Decls, Clauses, BTests, Preds),
    scoped_pairs(Clauses, BTests, Scoped),
    defeats(Clauses, Defeats),
    defeasible(Clauses, Defeasible),
    negated_preds(Clauses, BTests, Preds, Scoped, Defeats, Negs),
    findall(F/N, member(abducible(F/N), Decls), Abds),
    input_preds(Clauses, Preds, Inputs),
    Ctx = ctx(Doc, Preds, Scoped, Defeats, Defeasible, Negs, Abds, Inputs),
    templates(Ctx, Templates, TLedger),
    rules(Ctx, Clauses, RuleItems, RLedger),
    denials(Ctx, Clauses, DenialItems, DLedger),
    clock_items(Ctx, Clauses, ClockItems, CLedger),
    blawx_documents(Doc, ActText, ProjText, Docs),
    (   option(oracle(Oracle), Opts) -> true
    ;   oracle_available -> oracle_answers(File, Id, Opts, Oracle)
    ;   Oracle = []
    ),
    tests(Ctx, Id, BTests, Oracle, Tests0, Queries, XLedger0),
    (   oracle_available
    ->  generated_tests(Ctx, File, Id, Opts, Decls, Clauses, Queries, GTests, GQueries, GLedger)
    ;   GTests = [], GQueries = [], GLedger = []
    ),
    append(Tests0, GTests, Tests),
    append(XLedger0, GLedger, XLedger),
    conclusion_queries(Ctx, RuleItems, Queries, CQueries0),
    not_asked(CQueries0, GQueries, CQueries1),
    append(GQueries, CQueries1, CQueries),
    (   ( CQueries \== [] ; Queries \== [] )
    ->  view_item(Title, Ctx, RuleItems, CQueries, Queries, View), Views = [View]
    ;   Views = []                         % nothing to ask: no screen
    ),
    header_comment(Title, RDName, FB, Sections, Opts, Header0),
    Header = [kb(Id), comment(Header0)],
    append([Templates, Docs, ClockItems, [comment("The Act, section by section.")], RuleItems,
            DenialItems, Queries, CQueries, Views], Items),
    boilerplate_ledger(Sections, BLedger),
    template_notes(Ctx, Id, Templates, Items, Tests, TLedger, TLedger1),
    append([TLedger1, CLedger, RLedger, DLedger, BLedger, XLedger], Ledger),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    (   option(example(true), Opts)
    ->  blawx_commit(Commit), atom_concat('https://github.com/Lexpedite/blawx/tree/', Commit, CommitUrl),
        Meta = [program(Id), source(Title),
                artifacts([ProjText, CommitUrl]),
                translator('LE2 migration/blawx (blawx_twin.pl)'), date(Date),
                licence('Blawx: MIT')]
    ;   Meta = [program(Id), source(Title),
                artifacts([ProjText]),
                translator('LE2 migration/blawx (blawx_twin.pl)'), date(Date)]
    ).

		 /*******************************
		 *     WHAT THE SOURCE LEAVES   *
		 *******************************/

/*  Why a template of the twin is undefined, unused or unread, when it is:
    the verifier's warnings on a twin then have one explanation each, in
    the ledger. A template is read by a rule's conditions, a constraint or
    a query; defined by a rule's conclusion or a fact, in the program or a
    test; and "in a residue" when the Blawx clauses the twin keeps as
    residue blocks mention its predicate (their source text names it).
*/
template_notes(Ctx, Id, Templates, Items, Tests, Ledger0, Ledger) :-
    ctx_preds(Ctx, Preds), ctx_scoped(Ctx, Scoped),
    findall(Code, ( member(residue(_, O), Items), memberchk(source(_, Code), O) ), Codes),
    maplist(template_note_entry(Id, Preds, Scoped, Templates, Items, Tests, Codes), Ledger0, Ledger).

template_note_entry(Id, Preds, Scoped, Templates, Items, Tests, Codes, entry(E, K, V, M, Text, none), entry(E, K, V, M, Text, Note)) :-
    member(template(IRF0, Text, Adds), Templates),
    ( IRF0 = IRF/_ -> true ; IRF = IRF0 ),
    template_source_name(Preds, Scoped, IRF, Text, SrcF),
    template_note(Id, IRF, SrcF, Adds, Items, Tests, Codes, Note), !.
template_note_entry(_, _, _, _, _, _, _, E, E).

template_source_name(Preds, _, _, Text, F) :- member(p(F/_, _, Text, _), Preds), !.
template_source_name(_, Scoped, _, Text, C) :-
    member(_-C0, Scoped), ( C0 = neg(C) -> true ; C = C0 ),
    sub_atom(Text, _, _, _, ' under '), !.
template_source_name(_, _, IRF, _, IRF).

template_note(Id, IRF, _, _, _, _, _, Note) :- hand_template_note(Id, IRF, Note), !.
template_note(_, IRF, SrcF, Adds, Items, Tests, Codes, Note) :-
    ( in_residue(SrcF, Codes) -> Res = true ; Res = false ),
    ( ir_defined(IRF, Items, Tests, rule) -> DefR = true ; DefR = false ),
    ( ir_defined(IRF, Items, Tests, fact) -> DefF = true ; DefF = false ),
    ( ir_read(IRF, Items, Tests) -> Read = true ; Read = false ),
    ( ( memberchk(undefined, Adds) ; memberchk(assumable, Adds) ) -> Input = true ; Input = false ),
    template_note_(Read, DefR, DefF, Input, Res, Note).

template_note_(true, false, false, false, true,
    "Defined in the source only by clauses this twin keeps as residue blocks (see the residue entries), so nothing defines it here: the verifier reports it undefined.").
template_note_(true, false, false, false, false,
    "Source defect: the source reads it and defines it nowhere, so nothing makes it true (the verifier reports it undefined).").
template_note_(false, false, false, _, true,
    "Used in the source only by clauses this twin keeps as residue blocks (see the residue entries): the verifier reports the template unused.").
template_note_(false, false, false, _, false,
    "As in the source: declared (a category, attribute or relationship) and never used; the verifier reports the template unused.").
template_note_(false, false, true, _, true,
    "Read in the source only by clauses this twin keeps as residue blocks (see the residue entries), so no rule here reads its facts: the verifier reports them unconsumed.").
template_note_(false, false, true, _, false,
    "As in the source: facts are stated and no rule, constraint or test of the source reads them (the verifier reports them unconsumed).").

%   F is a word of a residue's code: called, or named as a conclusion
%   (according_to(Section, F, ...)).
in_residue(F, Codes) :-
    atom(F), atom_length(F, L),
    member(C, Codes), sub_string(C, B, L, A, F),
    ( B =:= 0 -> true ; B1 is B - 1, sub_string(C, B1, 1, _, Prev), \+ is_name_char(Prev) ),
    ( A =:= 0 -> true ; B2 is B + L, sub_string(C, B2, 1, _, Next), \+ is_name_char(Next) ), !.

is_name_char(C) :- string_code(1, C, K), code_type(K, csym).

ir_defined(F, Items, _, rule) :- member(rule(H, _, _), Items), ir_functor(H, F), !.
ir_defined(F, Items, Tests, fact) :-
    (   member(fact(H, _), Items)
    ;   member(test(_, _, _, Fs, _), Tests), member(L0, Fs), ( L0 = fact(H, _) -> true ; L0 = rule(H, _) -> true ; H = L0 )
    ),
    ir_functor(H, F), !.

ir_read(F, Items, Tests) :-
    (   member(rule(_, B, _), Items)
    ;   member(constraint(B, _), Items)
    ;   member(query(_, B), Items)
    ;   member(test(_, _, _, Fs, _), Tests), member(rule(_, B), Fs)
    ),
    sub_term(L, B), ir_functor(L, F), !.

ir_functor(L, F) :- nonvar(L), callable(L), functor(L, F, _).

%   What a reading of one project found by hand, for its ledger.
hand_template_note(bird, applies_to, "As in the source: section 5's \"except for pingu\" states the opposite of this template (*a provision* does not apply to *a thing*) only under section_5_pingu (holds(sec_5__span_pingu_section, -blawx_applies, ...)); Blawx's encoding never derives -blawx_applies from it, so nothing concludes the opposite and pingu with a jetpack can fly in Blawx too (see the scenario's note). The verifier reports the opposite used as a condition with nothing concluding it.").
hand_template_note(bird, does_not_apply_to_under, "As in the source: the fact of section 5 that it does not apply to pingu is stated under section_5_pingu and nothing in Blawx's encoding reads it (see the note on the opposite of *a provision* applies to *a thing*); the verifier reports it unconsumed.").

act_document(Title0, Doc) :-
    atom_string(Title0, S0),
    ( string_concat(S1, ".", S0) -> true ; S1 = S0 ),
    normalize_space(string(S2), S1),
    (   sub_string(S2, 0, 4, _, "The ") -> sub_string(S2, 4, _, 0, S3), format(atom(Doc), 'the ~w', [S3])
    ;   format(atom(Doc), 'the ~w', [S2])
    ).

blawx_documents(Doc, ActText, ProjText, [document(Doc, [text(ActText)]),
                                          document('the Blawx project', [text(ProjText)])]).

header_comment(Title, RDName, FB, Sections, Opts, C) :-
    length(Sections, NS),
    format(string(C0),
"~w~n~nThe Logical English twin of a Blawx encoding, written by Logical English's translator for Blawx.~nEach rule is a rule of the Act as Blawx encodes it,~nin the words of Blawx's own sentence forms, citing its section; the project's~ntests are the scenarios, with Blawx's own answers as the expectations.~n~nSource: the Blawx project \"~w\" (~w, ~w sections)",
           [Title, RDName, FB, NS]),
    (   option(example(true), Opts)
    ->  blawx_release(Rel), blawx_commit(Commit),
        format(string(C), "~w, an example of~n        Blawx ~w (Lexpedite, MIT licence), commit ~w.", [C0, Rel, Commit])
    ;   string_concat(C0, ".", C)
    ).

		 /*******************************
		 *    WHAT THE SECTIONS HOLD    *
		 *******************************/

%   Decls: cat(C), attr(A, Cat, Type), rel(R, Types), wording(F/N, Spec, Words),
%   abducible(Spec). Clauses: cl(Section, Term, Comments) for everything else
%   (the declarations, the #pred lines and the temporal boilerplate left out).
collect(Sections, Decls, Clauses) :-
    findall(D, ( member(section(_, Cs), Sections), member(c(T, Bs, _), Cs), decl(T, Bs, D) ), Decls0),
    list_to_set(Decls0, Decls),
    findall(cl(S, T, Cm), ( member(section(S, Cs), Sections), member(c(T, Bs, Cm), Cs),
                            \+ decl(T, Bs, _), \+ boilerplate(T) ), Clauses).

bind_names(Bs) :- maplist([N=V]>>( var(V) -> V = '$VAR'(N) ; true ), Bs).

decl(blawx_category(C), _, cat(C)) :- !.
decl(blawx_attribute(Cat, A, T), _, attr(A, Cat, T)) :- !.
decl(T, _, rel(R, Ts)) :- compound(T), T =.. [blawx_relationship, R|Ts], !.
decl(#(pred('::'(Spec, W))), Bs, wording(F/N, Spec1, W)) :-
    callable(Spec), \+ Spec = -(_), \+ Spec = not(_),
    functor(Spec, F, N), \+ plumbing_functor(F), !,
    copy_term(Spec-Bs, Spec1-Bs1), bind_names(Bs1).
decl(#(abducible(Spec)), _, abducible(F/N)) :- callable(Spec), functor(Spec, F, N), !.
decl(T, _, rel_nlg) :- compound(T), functor(T, F, _),
    memberchk(F, [blawx_category_nlg, blawx_attribute_nlg, blawx_relationship_nlg]), !.
decl(#(pred(_)), _, pred_other) :- !.

plumbing_functor(F) :- memberchk(F, [holds, according_to, blawx_defeated, defeated, blawx_initially,
                                     blawx_ultimately, blawx_as_of, blawx_during, blawx_becomes,
                                     blawx_diseq, blawx_comparison, date_add, date_compare,
                                     duration_compare]).

boilerplate(T) :- var(T), !, fail.
boilerplate(#(_)) :- !.
boilerplate((:- _)) :- !.
boilerplate(T) :- compound(T), functor(T, F, _),
    memberchk(F, [blawx_category_nlg, blawx_attribute_nlg, blawx_relationship_nlg]), !.
boilerplate((H :- _)) :- nonvar(H), functor(H, F, _), memberchk(F, [blawx_as_of, blawx_during, blawx_not_interrupted]), !.
boilerplate(syntax_error(Text)) :-   % Blawx's generator's typos in the temporal boilerplate
    member(P, ["blawx_as_of", "blawx_during", "blawx_not_interrupted"]),
    sub_string(Text, 0, _, _, P), !.

%   The ledger's line for the boilerplate each section carries.
boilerplate_ledger(Sections, Ledger) :-
    aggregate_all(count, ( member(section(_, Cs), Sections), member(c(T, _, _), Cs),
                           T = (H :- _), nonvar(H), functor(H, F, _), memberchk(F, [blawx_as_of, blawx_during]) ), NT),
    aggregate_all(count, ( member(section(_, Cs), Sections), member(c(syntax_error(_), _, _), Cs) ), NE),
    aggregate_all(count, ( member(section(_, Cs), Sections), member(c(#(pred(_)), _, _), Cs) ), NP),
    format(string(E1), "~w blawx_as_of / blawx_during clauses", [NT]),
    format(string(N1), "Blawx writes these for every attribute and relationship; no rule or test of this project reads them~w",
           [NE]),
    ( NE > 0 -> format(string(N1b), "~w (~w of them do not parse: typos of Blawx's generator)", [N1, NE]) ; N1b = N1 ),
    format(string(E2), "~w #pred annotations", [NP]),
    Ledger = [entry(E1, 'temporal boilerplate', encoded, 'left out: nothing reads it', 'nothing', N1b),
              entry(E2, 'natural language', encoded, 'the wording of each template; the holds / according_to / defeated forms are the rules themselves', 'the templates', none)].

		 /*******************************
		 *          PREDICATES          *
		 *******************************/

%   Preds: [p(F/N, IRF, Text, Kind)] — Kind template | builtin. The IR
%   functor is the one LE derives from the template's words.
predicates(Decls, Clauses, Tests, Preds) :-
    %  the declarations no rule, fact or test uses are not written (the
    %  ledger lists them)
    findall(F/N, used_predicate(Clauses, Tests, F/N), Used0),
    list_to_set(Used0, Used),
    include(templated(Decls), Used, Ts),
    maplist(pred_entry(Decls), Ts, Preds0),
    distinct_functors(Preds0, Preds).

used_predicate(Clauses, Tests, F/N) :-
    (   member(cl(_, T, _), Clauses), clause_literal(T, L)
    ;   member(test(_, Cs, Q), Tests),
        ( member(c(T, _, _), Cs), clause_literal(T, L) ; Q = query(G, _), goal_literal(G, L) )
    ),
    literal_pred(L, F/N).

literal_pred(L, F/N) :-
    compound(L), L =.. [K, _, P0|Args], memberchk(K, [holds, according_to, blawx_defeated]),
    ( P0 = -(P) -> true ; P = P0 ), atom(P), !,
    F = P, length(Args, N).
literal_pred(-(G), F/N) :- !, callable(G), functor(G, F, N).
literal_pred(L, F/N) :- callable(L), functor(L, F, N).

%   The literals of a clause: its head (a fact's term) and its conditions,
%   through conjunctions, disjunctions and negations.
clause_literal(T, _) :- var(T), !, fail.
clause_literal((H :- B), L) :- !, ( goal_literal(H, L) ; goal_literal(B, L) ).
clause_literal(#(_), _) :- !, fail.
clause_literal((:- _), _) :- !, fail.
clause_literal(syntax_error(_), _) :- !, fail.
clause_literal('$comments', _) :- !, fail.
clause_literal(T, L) :- goal_literal(T, L).

clause_body_literal((_ :- B), L) :- nonvar(B), goal_literal(B, L).

goal_literal(G, _) :- var(G), !, fail.
goal_literal((A, B), L) :- !, ( goal_literal(A, L) ; goal_literal(B, L) ).
goal_literal((A ; B), L) :- !, ( goal_literal(A, L) ; goal_literal(B, L) ).
goal_literal(not(G), L) :- !, goal_literal(G, L).
goal_literal(\+(G), L) :- !, goal_literal(G, L).
goal_literal(findall(_, G, _), L) :- !, goal_literal(G, L).
goal_literal(G, G) :- callable(G).

templated(_, F/_) :- builtin_functor(F), !, fail.
templated(Decls, F/N) :- memberchk(wording(F/N, _, _), Decls), !.
templated(Decls, F/1) :- memberchk(cat(F), Decls), !.
templated(Decls, F/N) :- memberchk(attr(F, _, T), Decls), ( T == boolean -> N =:= 1 ; N =:= 2 ), !.
templated(Decls, F/N) :- member(rel(F, Ts), Decls), length(Ts, N), !.
templated(_, blawx_applies/2) :- !.
templated(_, blawx_today/1) :- !.
templated(_, blawx_now/1) :- !.
templated(_, F/_) :- \+ builtin_functor(F), \+ plumbing_functor(F).

builtin_functor(F) :- memberchk(F, [=, \=, is, <, >, =<, >=, #=, #<>, #<, #>, #=<, #>=, not, ',', ';', findall,
                                    count_blawx_list, sum_blawx_list, average_blawx_list, max_blawx_list,
                                    min_blawx_list, blawx_list_not_between, blawx_list_not_before,
                                    blawx_list_not_after, blawx_not_between, datetime_add, not_after,
                                    false, true, '$VAR']).
builtin_functor(F) :- plumbing_functor(F).

%   The template of F/N: the #pred wording, its places named by the types
%   the declarations give them.
pred_entry(Decls, F/N, p(F/N, IRF, Text, template(Perm))) :-
    place_types(Decls, F/N, Types),
    (   clock_wording(F/N, Text0) -> Text = Text0, numlist1(N, Perm)
    ;   member(wording(F/N, Spec, W), Decls)
    ->  Spec =.. [_|Vs], atom_string(W, WS), wording_text(WS, Vs, Types, Text, Perm)
    ;   F == blawx_applies, N =:= 2
    ->  Text = "*a provision* applies to *a thing*", Perm = [1, 2]
    ;   naive_wording(F, Types, Text), numlist1(N, Perm)
    ),
    once(template_text_dict(Text, dict([IRF|_], _, _))).

numlist1(0, []) :- !.
numlist1(N, L) :- numlist(1, N, L).

%   A literal's arguments in the order of its template's places (LE's
%   order), from Blawx's order (the #pred head's).
text_args([], _, []).
text_args([I|Is], Args, [A|As]) :- nth1(I, Args, A), text_args(Is, Args, As).

%   A category's place is the category itself when the category is the
%   type of some attribute or relationship (`*a test* is a test`, so that a
%   test found by it is "the test" afterwards), else a thing (`*a thing* is
%   a penguin`).
place_types(Decls, F/1, [T]) :- memberchk(cat(F), Decls), !,
    (   ( member(attr(_, F, _), Decls) ; member(attr(_, _, F), Decls) ; member(rel(_, Ts), Decls), memberchk(F, Ts) )
    ->  type_name(F, T) ; T = thing ).
place_types(Decls, F/N, Ts) :- memberchk(attr(F, Cat, T), Decls), !,
    type_name(Cat, CT), ( T == boolean -> N =:= 1, Ts = [CT] ; type_name(T, TT), Ts = [CT, TT] ).
place_types(Decls, F/N, Ts) :- member(rel(F, Ts0), Decls), length(Ts0, N), !, maplist(type_name, Ts0, Ts).
place_types(_, blawx_applies/2, [provision, thing]) :- !.
place_types(_, blawx_today/1, [time]) :- !.
place_types(_, blawx_now/1, [time]) :- !.
place_types(_, _/N, Ts) :- length(Ts, N), maplist(=(thing), Ts).

type_name(T, N) :-
    (   memberchk(T-N0, [number-number, date-time, datetime-time, time-time, duration-duration,
                          true_false-thing, list-list, boolean-thing]) -> N = N0
    ;   atomic_list_concat(Ws, '_', T), atomic_list_concat(Ws, ' ', N)
    ).

%   @(X) -> a slot of the place's type; `X 's noun phrase` (Blawx's
%   possessive) -> `the noun phrase of X`, LE's way. Perm: for each place of
%   the text, in order, the position of its variable in the #pred head.
wording_text(W0, Vs, Types, Text, Perm) :-
    replace_all(W0, "\\'s", "'s", W1), replace_all(W1, " 's", "'s", W2),
    normalize_space(string(W3), W2),
    possessive(W3, W4),
    var_names(Vs, Names),
    findall(B-I, ( nth1(I, Names, Nm), format(string(Pat), "@(~w)", [Nm]), sub_string(W4, B, _, _, Pat) ), BIs0),
    keysort(BIs0, BIs), pairs_values(BIs, Perm0),
    length(Vs, NV), numlist1(NV, All), subtract(All, Perm0, Missing), append(Perm0, Missing, Perm),
    text_args(Perm, Types, TextTypes),
    distinct_places(TextTypes, TextPlaces),
    text_args(Perm, Names, TextNames),
    foldl(drop_type_words, TextNames, TextTypes, W4, W4b),
    foldl(slot_for, TextNames, TextPlaces, W4b, W5),
    replace_all(W5, "_", " ", W6),
    citations(W6, W7),
    normalize_space(string(Text), W7).

%   LE splits a word at a parenthesis or a hyphen, and writes the pieces
%   spaced (`s3 ( 1 ) ( a )`, `non - pensioner`): a citation glued to a word
%   is written with underscores, as the section constants are (`s3_1_a`,
%   `3_1_b_ii`), and a hyphen is a space.
citations(S0, S) :-
    string_codes(S0, Cs0), phrase(cit(Cs), Cs0), string_codes(S1, Cs),
    replace_all(S1, "-", " ", S).

cit([C|Out]) --> [C], { code_type(C, alnum) }, "(", !, group(G), cit_more(M), { append([0'_|G], M, GM), append(GM, Rest, Out) }, cit(Rest).
cit([C|Out]) --> [C], !, cit(Out).
cit([]) --> [].

group(G) --> alnums(G), ")".
cit_more(M) --> "(", !, group(G), cit_more(M1), { append([0'_|G], M1, M) }.
cit_more([]) --> [].
alnums([C|Cs]) --> [C], { code_type(C, alnum) }, !, alnums(Cs).
alnums([]) --> [].

%   "business @(X) involves ..." with X a business: the slot says it already
%   ("*a business* involves ..."); likewise "the business entity @(Y)".
drop_type_words(Nm, Type, S0, S) :-
    format(string(Pat), "@(~w)", [Nm]),
    atom_string(Type, TS),
    (   member(Pre, ["the ", ""]), format(string(Full), "~w~w ~w", [Pre, TS, Pat]),
        sub_string(S0, B, L, A, Full),
        %  at the start of the sentence, or as "the <type> X" anywhere — not
        %  inside a phrase ("took a covid test X" keeps its words)
        ( B =:= 0 -> true ; Pre == "the ", B1 is B - 1, sub_string(S0, B1, 1, _, " ") )
    ->  sub_string(S0, 0, B, _, Before), sub_string(S0, _, A, 0, After),
        ignore(L = _), format(string(S), "~w~w~w", [Before, Pat, After])
    ;   S = S0
    ).

var_names(Vs, Names) :- maplist([V, N]>>( V = '$VAR'(N0) -> N = N0 ; format(atom(N), '~w', [V]) ), Vs, Names).

slot_for(N, Place, S0, S) :-
    format(string(Pat), "@(~w)", [N]),
    ( Place = [O, T] -> format(string(Slot), "*a ~w ~w*", [O, T]) ; article_slot(Place, Slot) ),
    replace_all(S0, Pat, Slot, S).

article_slot(T, Slot) :-
    atom_string(T, TS), sub_string(TS, 0, 1, _, F),
    ( sub_atom(aeiou, _, 1, _, F) -> A = an ; A = a ),
    format(string(Slot), "*~w ~w*", [A, TS]).

%   [person, person] -> [person, [second, person]].
distinct_places(Types, Places) :-
    foldl(place_step, Types, []-[], _-Rev), reverse(Rev, Places).
place_step(T, Seen, Seen1-[P|Acc]) :-
    Seen = S0-Acc,
    ( select(T-K0, S0, S2) -> K is K0 + 1 ; K = 1, S2 = S0 ),
    Seen1 = [T-K|S2],
    ( K =:= 1 -> P = T ; nth1(K, [first, second, third, fourth, fifth, sixth], O) -> P = [O, T] ; P = [other, T] ).

%   "@(X)'s facial hair is below the chin" -> "the facial hair of @(X) is below
%   the chin"; "... with @(Y)'s availability to practice law" -> "... with the
%   availability to practice law of @(Y)".
possessive(S0, S) :-
    (   sub_string(S0, B, _, A, ")'s ")
    ->  sub_string(S0, 0, B, _, Pre0), string_concat(Pre0, ")", PreV),
        sub_string(S0, _, A, 0, Post),
        (   sub_string(PreV, VB, _, 0, _), sub_string(PreV, VB, 2, _, "@("), \+ ( sub_string(PreV, VB2, 2, _, "@("), VB2 > VB )
        ->  sub_string(PreV, 0, VB, _, Before), sub_string(PreV, VB, _, 0, Var)
        ;   Before = "", Var = PreV
        ),
        (   sub_string(Post, IB, _, IA, " is ")
        ->  sub_string(Post, 0, IB, _, NP), sub_string(Post, _, IA, 0, Rest),
            format(string(S1), "~wthe ~w of ~w is ~w", [Before, NP, Var, Rest])
        ;   format(string(S1), "~wthe ~w of ~w", [Before, Post, Var])
        ),
        possessive(S1, S)
    ;   S = S0
    ).

%   Blawx's clock (dates.py): the twin fixes it (clock_date/1).
clock_wording(blawx_today/1, "the date today is *a time*").
clock_wording(blawx_now/1, "the time now is *a time*").

naive_wording(F, Types, Text) :-
    atomic_list_concat(Ws, '_', F), atomic_list_concat(Ws, ' ', FW),
    distinct_places(Types, Places),
    maplist([P, Sl]>>( P = [O, T] -> format(string(Sl), "*a ~w ~w*", [O, T]) ; article_slot(P, Sl) ), Places, Slots),
    (   Slots = [] -> Text = FW
    ;   Slots = [S1] -> format(string(Text), "~w ~w", [S1, FW])
    ;   Slots = [S1|Rest], atomic_list_concat(Rest, ' and ', RT),
        format(string(Text), "~w ~w ~w", [S1, FW, RT])
    ).

%   Two templates whose words give the same LE functor (`player/1` "is a
%   player" and `player/2` "played in") differ in arity; LE keeps them apart.
distinct_functors(Ps, Ps).

ctx_preds(ctx(_, Preds, _, _, _, _, _, _), Preds).
ctx_scoped(ctx(_, _, Scoped, _, _, _, _, _), Scoped).
ctx_defeats(ctx(_, _, _, Defeats, _, _, _, _), Defeats).
ctx_defeasible(ctx(_, _, _, _, Ds, _, _, _), Ds).
ctx_negs(ctx(_, _, _, _, _, Negs, _, _), Negs).
ctx_doc(ctx(Doc, _, _, _, _, _, _, _), Doc).
ctx_abds(ctx(_, _, _, _, _, _, As, _), As).
ctx_inputs(ctx(_, _, _, _, _, _, _, Is), Is).

%   The predicates a case states: no rule concludes them and no section
%   states them (`; scenario element`).
input_preds(Clauses, Preds, Inputs) :-
    findall(F/N, ( member(cl(_, T, _), Clauses), concluded(T, F/N) ), Cs0), list_to_set(Cs0, Cs),
    findall(F/N, ( member(p(F/N, _, _, _), Preds), \+ memberchk(F/N, Cs),
                   \+ memberchk(F, [blawx_today, blawx_now]) ), Inputs).

concluded((H :- _), F/N) :- !, nonvar(H), head_pred(H, F/N).
concluded(H, F/N) :- nonvar(H), \+ H = (:- _), \+ H = #(_), \+ H = syntax_error(_), head_pred(H, F/N).

head_pred(H, F/N) :- H =.. [K, _, P0|Args], memberchk(K, [according_to, holds]), !,
    ( P0 = -(P) -> true ; P = P0 ), atom(P), F = P, length(Args, N).
head_pred(-(H), F/N) :- !, callable(H), functor(H, F, N).
head_pred(H, F/N) :- callable(H), functor(H, F, N).

		 /*******************************
		 *   OPPOSITES AND SCOPES       *
		 *******************************/

%   The opposite wording of a template: `is` -> `is not`, `can` -> `cannot`,
%   `may` -> `may not`, `must` -> `must not`, `has` -> `does not have`,
%   `was` -> `was not`, anything else `it is false that ...`.
opposite_text(Text, Opp) :-
    atom_string(Text, S),
    (   member(From-To, [" is "-" is not ", " can "-" cannot ", " may "-" may not ", " must "-" must not ",
                         " was "-" was not ", " has "-" does not have ", " are "-" are not "]),
        sub_string(S, B, _, A, From)
    ->  sub_string(S, 0, B, _, Pre), sub_string(S, _, A, 0, Post),
        format(string(Opp), "~w~w~w", [Pre, To, Post])
    ;   split_string(S, " ", "", Ws), append(Pre, [V|Post], Ws), Pre \== [],
        last(Pre, LastPre), sub_string(LastPre, _, 1, 0, "*"),       % the word after the first place
        verb_base(V, Base)
    ->  append(Pre, ["does", "not", Base|Post], Ws1), atomic_list_concat(Ws1, ' ', OA), atom_string(OA, Opp)
    ;   format(string(Opp), "it is false that ~w", [S])
    ).

%   applies -> apply, carries -> carry, beats -> beat (a verb in the third
%   person: the word after the first place, ending in s but not ss).
verb_base(V, B) :-
    (   sub_string(V, Bf, 3, 0, "ies") -> sub_string(V, 0, Bf, _, S0), string_concat(S0, "y", B)
    ;   sub_string(V, _, 1, 0, "s"), \+ sub_string(V, _, 2, 0, "ss"), string_length(V, L), L > 2,
        L1 is L - 1, sub_string(V, 0, L1, _, B)
    ).

%   The (Section, Conclusion) pairs a body or a test reads as a conclusion
%   of that section (holds/according_to), or that a fact states: each gets
%   the template `<conclusion> under *a provision*`. Conclusion is P or neg(P).
scoped_pairs(Clauses, Tests, Pairs) :-
    findall(S-C, ( ( member(cl(_, T, _), Clauses), reading_clause(T), clause_body_literal(T, L)
                   ; member(cl(_, T, _), Clauses), compound(T), T =.. [holds, _, _|_], L = T
                   ; member(test(_, Cs, Q), Tests),
                     ( member(c(T0, _, _), Cs), clause_literal(T0, L) ; Q = query(G, _), goal_literal(G, L) ) ),
                   scoped_literal(L, S, C, _) ), Pairs0),
    list_to_set(Pairs0, Pairs).

%   The clauses whose conditions are the Act's: the rules of the sections
%   and the defeats (not Blawx's holds/according_to plumbing).
reading_clause((H :- B)) :- nonvar(H),
    (   H =.. [according_to|_] -> true
    ;   H =.. [blawx_defeated|_] -> true
    ;   H =.. [holds|_] -> fail
    ;   nonvar(B), B =.. [holds|_] -> fail            % P(Xs) :- holds(S, P, Xs): plumbing
    ;   true
    ).

scoped_literal(L, S, C, Args) :-
    compound(L), L =.. [K, S0, P0|Args], memberchk(K, [holds, according_to]),
    atom(S0), S0 \== user, S = S0, conclusion(P0, C), !.
scoped_literal(L, S, C, Args) :-                       % according_to(S, p(X)): the two-place form
    compound(L), L = according_to(S0, G), atom(S0), callable(G), \+ atom(G),
    S = S0, ( G = -(G1) -> C = neg(F) ; G1 = G, C = F ), functor(G1, F, _), G1 =.. [_|Args].

conclusion(-(P), neg(P)) :- atom(P), !.
conclusion(P, P) :- atom(P).

defeats(Clauses, Ds) :-
    retractall(defeat_clause(_, _, _, _)),
    forall(( member(cl(_, (H :- B), _), Clauses), nonvar(H),
             H =.. [blawx_defeated, S1, P1|HArgs], conclusion(P1, C1),
             B =.. [holds, S2, P2|BArgs], conclusion(P2, C2),
             \+ ( defeat_clause(S1-C1, S2-C2, HA0, BA0), HA0-BA0 =@= HArgs-BArgs ) ),
           assertz(defeat_clause(S1-C1, S2-C2, HArgs, BArgs))),
    findall(defeat(A, B), defeat_clause(A, B, _, _), Ds0),
    list_to_set(Ds0, Ds).

defeasible(Clauses, Ds) :-
    findall(S-C, ( member(cl(_, (H :- B), _), Clauses), nonvar(H), H =.. [holds, S, P|_],
                   conclusion(P, C), sub_term(X, B), compound(X), functor(X, blawx_defeated, _) ),
            Ds0),
    list_to_set(Ds0, Ds).

		 /*******************************
		 *           TEMPLATES          *
		 *******************************/

templates(Ctx, Templates, Ledger) :-
    ctx_preds(Ctx, Preds), ctx_scoped(Ctx, Scoped), ctx_negs(Ctx, Negs), ctx_abds(Ctx, Abds),
    findall(template(IRF, Text, Adds)-entry(E, K, encoded, M, Text, none),
            ( member(p(F/N, IRF, Text, template(_)), Preds),
              ( memberchk(F/N, Negs) -> opposite_text(Text, O), A1 = [opposite(O)] ; A1 = [] ),
              ( memberchk(F/N, Abds) -> A2 = [assumable] ; A2 = [] ),
              ( ctx_inputs(Ctx, Ins), memberchk(F/N, Ins), A2 == [] -> A3 = [undefined] ; A3 = [] ),
              append([A1, A2, A3], Adds),
              format(string(E), "~w/~w", [F, N]),
              K = 'category, attribute or relationship',
              M = 'its #pred wording -> a template' ),
            P1),
    findall(template(SF, ST, [])-entry(E, 'section conclusion', encoded, M, ST, none),
            ( member(S-C, Scoped), scoped_template(Ctx, S-C, SF, ST),
              format(string(E), "holds(~w, ~w, ...)", [S, C]),
              M = 'the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>`' ),
            P2),
    append(P1, P2, Ps0), list_to_set(Ps0, Ps),
    pairs_keys_values(Ps, Templates0, Ledger),
    list_to_set(Templates0, Templates).

%   The predicates the program uses classically negated (-p anywhere).
negated_preds(Clauses, Tests, Preds, Scoped, Defeats, Negs) :-
    findall(F, ( member(_-neg(F), Scoped) ; member(defeat(_-neg(F), _), Defeats) ; member(defeat(_, _-neg(F)), Defeats)
               ; member(cl(_, T, _), Clauses), sub_term(X, T), neg_functor(X, F)
               ; member(test(_, Cs, Q), Tests), ( member(c(T, _, _), Cs) ; Q = query(T, _) ), sub_term(X, T), neg_functor(X, F) ),
            Fs0),
    list_to_set(Fs0, Fs),
    findall(F/N, ( member(F, Fs), member(p(F/N, _, _, _), Preds) ), Negs).

neg_functor(X, F) :- compound(X), X = -(G), callable(G), \+ number(G), functor(G, F, _), F \== '$VAR'.
neg_functor(X, F) :- compound(X), X =.. [K, _, -(F)|_], memberchk(K, [holds, according_to, blawx_defeated]), atom(F).

scoped_template(Ctx, S-C, SF, ST) :-
    ctx_preds(Ctx, Preds),
    ( C = neg(F) -> true ; F = C ),
    member(p(F/_, _, Text, _), Preds), !,
    ( C = neg(_) -> opposite_text(Text, T1) ; atom_string(Text, T1) ),
    format(string(ST), "~w under *a provision*", [T1]),
    once(template_text_dict(ST, dict([SF|_], _, _))),
    ignore(S = _).

		 /*******************************
		 *            RULES             *
		 *******************************/

%   Items and ledger entries for every clause of the sections.
rules(Ctx, Clauses, Items, Ledger) :-
    foldl(clause_item(Ctx), Clauses, s([], [], []), s(ItemsR, LedgerR, _)),
    reverse(ItemsR, Items1), reverse(LedgerR, Ledger0),
    append(Items1, Items2),
    temporal_residues(Ctx, Items2, Items, TLedger),
    append(Ledger0, TLedger, Ledger).

%   The event calculus of a section (blawx_becomes, blawx_initially,
%   blawx_ultimately, and what Blawx generates around them) is one residue
%   block per section, where the section's first such clause was.
temporal_residues(Ctx, Items0, Items, Ledger) :-
    findall(S, member(temporal(S, _), Items0), Ss0), list_to_set(Ss0, Ss),
    foldl(temporal_block(Ctx, Items0), Ss, Items0-[], Items1-Ledger),
    exclude([X]>>(X = temporal(_, _)), Items1, Items).

temporal_block(Ctx, All, S, Items0-L0, Items-[Entry|L0]) :-
    findall(T, member(temporal(S, T), All), Ts), length(Ts, N),
    with_output_to(string(Code), forall(member(T, Ts), portray_clause(T))),
    section_locator(S, Loc), section_constant(S, SC), ctx_doc(Ctx, Doc),
    format(atom(Id), '~w_events', [SC]),
    format(string(Title), "the events of ~w of ~w", [Loc, Doc]),
    findall(F, ( member(T, Ts), residue_concludes(Ctx, T, Fs), member(F, Fs) ), Cs0), list_to_set(Cs0, Cs),
    Why = "Blawx's event calculus (blawx_becomes, blawx_initially, blawx_ultimately, blawx_as_of, blawx_during): a value that events change belongs in an LPS twin (a fluent), or in lib/temporal's periods; not translated automatically",
    Opts = [title(Title), locator(Loc), source('s(CASP), as Blawx generated it', Code), note(Why), concludes(Cs)],
    nth1(P, Items0, temporal(S, _)), !,
    nth1(P, Items0, _, Rest), nth1(P, Items, residue(Id, Opts), Rest),
    format(string(E), "~w clause(s) of events in ~w", [N, Loc]),
    Entry = entry(E, events, residue, 'not translated: kept verbatim as a residue block', Id, Why).

%   s(Items, Ledger, Seen): Seen holds the labels used and the scoped
%   conclusions already linked to their plain form.
clause_item(Ctx, cl(S, T, Cm), s(I0, L0, Seen0), s(I, L, Seen)) :-
    (   clause_kind(T, Kind)
    ->  true
    ;   Kind = other
    ),
    catch(( kind_items(Kind, Ctx, S, T, Cm, Seen0, Seen, Its, Ens) -> true
          ; Its = [], Ens = [], Seen = Seen0 ),
          residue(Why),
          ( residue_item(Ctx, S, T, Why, Seen0, Seen, Its, Ens) )),
    I = [Its|I0],
    append(Ens, L0, L).

clause_kind((H :- _), plumbing) :- nonvar(H), H =.. [F|_], memberchk(F, [holds, blawx_defeated]), !.
clause_kind((H :- B), link) :- nonvar(H), nonvar(B), B =.. [holds|_], \+ H =.. [according_to|_], !.
clause_kind((H :- _), temporal) :- nonvar(H), H =.. [according_to, _, blawx_becomes|_], !.
clause_kind((H :- _), temporal) :- nonvar(H), functor(H, F, _), memberchk(F, [blawx_becomes, blawx_initially, blawx_ultimately]), !.
clause_kind(H, temporal) :- nonvar(H), \+ H = (_ :- _), functor(H, F, _), memberchk(F, [blawx_becomes, blawx_initially, blawx_ultimately]), !.
clause_kind((H :- _), source) :- nonvar(H), H =.. [according_to|_], !.
clause_kind((false :- _), denial) :- !.
clause_kind(#(abducible(_)), abducible) :- !.
clause_kind(syntax_error(_), syntax_error) :- !.
clause_kind(H, scoped_fact) :- nonvar(H), H =.. [holds, S|_], atom(S), !.
clause_kind((_ :- _), rule) :- !.
clause_kind(_, fact).

kind_items(plumbing, _, _, _, _, Seen, Seen, [], []).
kind_items(link, _, _, _, _, Seen, Seen, [], []).
kind_items(abducible, _, _, _, _, Seen, Seen, [], []).
kind_items(denial, _, _, _, _, Seen, Seen, [], []).
kind_items(temporal, _, S, T, _, Seen, Seen, [temporal(S, T)], []).
kind_items(syntax_error, _, _, syntax_error(Text), _, _, _, _, _) :-
    format(string(Why), "Blawx wrote this clause with a syntax error, so s(CASP) cannot load it and it never applies in Blawx: ~w", [Text]),
    throw(residue(Why)).
kind_items(source, _, S, (H :- B), _, Seen, Seen, [], [entry(E, rule, encoded, M, 'nothing', N)]) :-
    H =.. [according_to, S, P0|Args], atom(P0), G0 =.. [P0|Args],
    conj_list(B, Gs), member(G, Gs), G == G0, !,
    format(string(E), "according_to(~w, ~w, ...) :- ... ~w ...", [S, P0, P0]),
    M = 'a rule that needs its own conclusion: it adds nothing (least model, and stable models alike), so it is left out',
    N = "a Prolog reading of it would loop; s(CASP) finds no support for it".
kind_items(source, Ctx, S, (H :- B), Cm, Seen0, Seen, Items, [Entry]) :-
    H =.. [according_to, S1, P0|Args],
    conclusion(P0, C),
    section_prov(Ctx, S1, Prov, Loc),
    translate_body(Ctx, B, Body0),
    guard(Ctx, S1-C, Args, Guard),
    ( Guard == true -> Body = Body0 ; Body = and(Body0, Guard) ),
    ctx_scoped(Ctx, Scoped),
    (   memberchk(S1-C, Scoped)
    ->  section_constant(S1, SC), scoped_lit(Ctx, S1-C, Args, SC, Head),
        (   memberchk(linked(S1-C), Seen0) -> Links = [], Seen1 = Seen0
        ;   length(LArgs, _), length(Args, NA), length(LArgs, NA),
            plain_lit(Ctx, C, LArgs, LHead), scoped_lit(Ctx, S1-C, LArgs, SC, LBody),
            new_label(S1, conclusion, Seen0, LLab, Seen2),
            format(string(LC), "What ~w concludes holds.", [Loc]),
            Links = [rule(LHead, LBody, [label(LLab), provenance(Prov), comment(LC)])],
            Seen1 = [linked(S1-C)|Seen2]
        )
    ;   plain_lit(Ctx, C, Args, Head), Links = [], Seen1 = Seen0
    ),
    new_label(S1, rule, Seen1, Lab, Seen),
    comment_opts(Cm, COpts),
    append([[label(Lab), provenance(Prov)], COpts], ROpts),
    Items = [rule(Head, Body, ROpts)|Links],
    format(string(E), "according_to(~w, ~w, ...) :- ...", [S1, P0]),
    ( Guard == true -> Map = 'a rule of the section, citing it' ; Map = 'a defeasible rule: guarded by the failure of its defeaters under their sections' ),
    Entry = entry(E, rule, encoded, Map, Lab, none).
kind_items(scoped_fact, Ctx, S, H, _, Seen, Seen, [fact(Lit, [provenance(Prov)])], [entry(E, fact, encoded, 'a conclusion stated by a section -> a fact under that section', E, none)]) :-
    H =.. [holds, S1, P0|Args0],
    conclusion(P0, C),
    maplist(unwrap, Args0, Args),
    section_constant(S1, SC),
    scoped_lit(Ctx, S1-C, Args, SC, Lit),
    section_prov(Ctx, S, Prov, _),
    term_string(H, E).
kind_items(fact, Ctx, S, H, Cm, Seen, Seen, [fact(Lit, Opts)], [entry(E, fact, encoded, 'a fact of the section, citing it', E, none)]) :-
    section_prov(Ctx, S, Prov, _),
    literal_ir(Ctx, H, Lit),
    comment_opts(Cm, CO), append([provenance(Prov)], CO, Opts0),
    exclude([comment(_)]>>true, Opts0, Opts),
    term_string(H, E).
kind_items(rule, Ctx, S, (H :- B), Cm, Seen0, Seen, [rule(Head, Body, Opts)], [entry(E, rule, encoded, 'a rule of the section, citing it', Lab, none)]) :-
    section_prov(Ctx, S, Prov, _),
    literal_ir(Ctx, H, Head),
    translate_body(Ctx, B, Body),
    new_label(S, rule, Seen0, Lab, Seen),
    comment_opts(Cm, CO), append([[label(Lab), provenance(Prov)], CO], Opts),
    term_string(H, HS), format(string(E), "~w :- ...", [HS]).

residue_item(Ctx, S, T, Why, Seen0, Seen, [residue(Id, Opts)], [entry(E, rule, residue, Map, Id, Why)]) :-
    new_label(S, residue, Seen0, Id, Seen),
    section_locator(S, Loc),
    (   T = syntax_error(Code0) -> Code = Code0 ; with_output_to(string(Code), portray_clause(T)) ),
    %  a clause that never applies in Blawx (it calls what Blawx does not
    %  define, or does not parse) changes no answer: the expectations that
    %  read its conclusion stand, not pending
    (   sub_string(Why, _, _, _, "never applies in Blawx") -> CO = []
    ;   residue_concludes(Ctx, T, Fs) -> CO = [concludes(Fs)]
    ;   CO = []
    ),
    ctx_doc(Ctx, Doc),
    format(string(Title), "~w of ~w", [Loc, Doc]),
    append([title(Title), locator(Loc), source('s(CASP), as Blawx generated it', Code), note(Why)], CO, Opts),
    term_string(T, E0), sub_atom_trunc(E0, 120, E),
    Map = 'not translated: kept verbatim as a residue block'.

sub_atom_trunc(S, N, T) :- ( string_length(S, L), L > N -> sub_string(S, 0, N, _, T0), string_concat(T0, "...", T) ; T = S ).

%   What an untranslated clause would conclude (its expectations are pending).
residue_concludes(Ctx, syntax_error(Text), Fs) :- !,
    %  what the broken clause would have concluded, read off its head
    sub_string(Text, 0, _, _, "according_to("),
    split_string(Text, "(,", " ", [_, S0, P0|_]),
    atom_string(S, S0), atom_string(P, P0),
    ctx_preds(Ctx, Preds), member(p(P/N, _, _, _), Preds), !,
    length(Args, N), H =.. [according_to, S, P|Args],
    residue_concludes(Ctx, H, Fs).
residue_concludes(Ctx, (H :- _), Fs) :- !, residue_concludes(Ctx, H, Fs).
residue_concludes(Ctx, H, [F]) :-
    nonvar(H), H =.. [according_to, S, P0|Args], atom(S), conclusion(P0, C), C \== blawx_becomes, !,
    ( ctx_scoped(Ctx, Sc), memberchk(S-C, Sc) -> section_constant(S, SC), scoped_lit(Ctx, S-C, Args, SC, L) ; plain_lit(Ctx, C, Args, L) ),
    functor(L, F, _).
residue_concludes(Ctx, H, [F]) :-
    nonvar(H), catch(literal_ir(Ctx, H, L), _, fail), functor(L, F, _).

comment_opts([], []) :- !.
comment_opts(Lines, [comment(C)]) :- atomic_list_concat(Lines, '\n', A), atom_string(A, C).

%   Unique rule labels: <section constant>, then <constant>_2, ...
new_label(S, Kind, Seen0, Lab, [label(Lab)|Seen0]) :-
    section_constant(S, SC),
    (   Kind == conclusion -> format(atom(Base), '~w_conclusion', [SC])
    ;   Kind == residue -> format(atom(Base), '~w_residue', [SC])
    ;   Base = SC
    ),
    (   \+ memberchk(label(Base), Seen0) -> Lab = Base
    ;   between(2, 1000, K), format(atom(Lab), '~w_~w', [Base, K]), \+ memberchk(label(Lab), Seen0) -> true
    ).

%   What the encoding states at the root, outside every section (Rule 34's
%   Jason and ABC LLP), is the encoder's example, not the Act's words: it
%   cites the Blawx project.
section_prov(_, root_section, [as_stated_in('the Blawx project'), at('the root of the encoding')], 'the root of the encoding') :- !.
section_prov(Ctx, S, [as_stated_in(Doc), at(Loc)], Loc) :- ctx_doc(Ctx, Doc), section_locator(S, Loc).

%   The guard of a defeasible conclusion: for each defeater, it is not the
%   case that the defeater's conclusion holds under its section.
guard(Ctx, S-C, Args, Guard) :-
    ctx_defeasible(Ctx, Ds), memberchk(S-C, Ds), !,
    %  findall copies its results: the arguments go with each, and are
    %  unified with the rule's own afterwards
    findall(Args-not(DL), defeater_literal(Ctx, S-C, Args, DL), Ps),
    rejoin(Ps, Args, Gs),
    left_and(Gs, Guard).
guard(_, _, _, true).

defeater_literal(Ctx, S-C, Args, Lit) :-
    ctx_defeats(Ctx, Defeats),
    member(defeat(S-C, S2-C2), Defeats),
    defeat_clause_args(Ctx, S-C, S2-C2, HArgs, BArgs),
    copy_term(HArgs-BArgs, HA-BA),
    HA = Args,
    maplist(unwrap, BA, BA1),
    section_constant(S2, SC2),
    scoped_lit(Ctx, S2-C2, BA1, SC2, Lit).

:- dynamic defeat_clause/4.
defeat_clause_args(_, S-C, S2-C2, HArgs, BArgs) :- defeat_clause(S-C, S2-C2, HArgs, BArgs).

rejoin([], _, []).
rejoin([A-G|Ps], Args, [G|Gs]) :- A = Args, rejoin(Ps, Args, Gs).

join_and([], true) :- !.
join_and([G], G) :- !.
join_and([G|Gs], and(G, R)) :- join_and(Gs, R).

		 /*******************************
		 *           LITERALS           *
		 *******************************/

%   The plain conclusion P(Args) or its opposite.
plain_lit(Ctx, C, Args0, Lit) :-
    maplist(unwrap, Args0, Args),
    length(Args, N),
    ctx_preds(Ctx, Preds),
    ( C = neg(F) -> true ; F = C ),
    (   member(p(F/N, IRF, Text, template(Perm)), Preds) -> true
    ;   throw(residue("a conclusion with no template"))
    ),
    text_args(Perm, Args, TArgs),
    (   C = neg(_) -> opposite_text(Text, OT), once(template_text_dict(OT, dict([OF|_], _, _))), Lit =.. [OF|TArgs]
    ;   Lit =.. [IRF|TArgs]
    ).

scoped_lit(Ctx, S-C, Args0, SC, Lit) :-
    maplist(unwrap, Args0, Args),
    scoped_template(Ctx, S-C, SF, _),
    ctx_preds(Ctx, Preds), ( C = neg(F) -> true ; F = C ), length(Args, N),
    ( member(p(F/N, _, _, template(Perm)), Preds) -> text_args(Perm, Args, TArgs) ; TArgs = Args ),
    append(TArgs, [SC], All),
    Lit =.. [SF|All].

%   A literal of a clause (a fact, a rule head, a scenario fact).
literal_ir(Ctx, t(F, V), Lit) :- !, H =.. [F, V], literal_ir(Ctx, H, Lit).
literal_ir(Ctx, -(G), Lit) :- !, G =.. [F|Args], plain_lit(Ctx, neg(F), Args, Lit).
literal_ir(Ctx, H, Lit) :-
    H =.. [F|Args0], length(Args0, N),
    ctx_preds(Ctx, Preds),
    (   member(p(F/N, IRF, _, template(Perm)), Preds) -> true
    ;   term_string(H, HS), format(string(W), "a literal of no known template: ~w", [HS]), throw(residue(W))
    ),
    maplist(unwrap, Args0, Args1),
    text_args(Perm, Args1, Args),
    Lit =.. [IRF|Args].

%   date(T), datetime(T), duration(T), time(T): the number T (seconds).
unwrap(V, V) :- var(V), !.
unwrap(T, V) :- compound(T), T =.. [W, V0], memberchk(W, [date, datetime, duration, time]), number(V0), !, V = V0.
unwrap(T, S) :- compound(T), T =.. [W|Ns], memberchk(W, [date, datetime]), length(Ns, L), L >= 3, !,
    %  a date written datetime(Y, M, D, h, m, s): no number to Blawx's date
    %  predicates (they fail on it); the twin keeps it as text
    format(string(S), "~w", [T]).
unwrap(T, C) :- atom(T), sub_atom(T, _, _, 0, '_section'), sub_atom(T, 0, 4, _, 'sec_'), !, section_constant(T, C).
unwrap(root_section, the_act) :- !.
unwrap(T, T).

		 /*******************************
		 *            BODIES            *
		 *******************************/

%!  translate_body(+Ctx, +Body, -IR)
%
%   Throws residue(Why) for what the twin does not say (findall, Blawx's
%   list aggregates, predicates Blawx's reasoner does not define).
translate_body(Ctx, B, IR) :-
    conj_list(B, Gs0),
    schedule(Gs0, Gs),
    foldl(goal_ir(Ctx), Gs, []-[], _-IRs0),
    reverse(IRs0, IRs1), exclude(==(true), IRs1, IRs),
    left_and(IRs, IR).

%   s(CASP) reads a comparison as a constraint, wherever it stands; LE tests
%   it when it is reached. A comparison whose variables are not yet bound is
%   moved to just after the condition that binds the last of them.
schedule(Gs, Out) :- schedule(Gs, [], [], Out).

schedule([], _, Wait, Wait).
schedule([G|Gs], Bound, Wait, Out) :-
    (   comparison_goal(G), term_variables(G, Vs), \+ all_bound(Vs, Bound)
    ->  schedule(Gs, Bound, [G|Wait], Out)
    ;   term_variables(G, GVs), append(Bound, GVs, Bound1),
        partition(ready(Bound1), Wait, Ready, Wait1),
        reverse(Ready, ReadyInOrder),
        append([G|ReadyInOrder], Rest, Out),
        schedule(Gs, Bound1, Wait1, Rest)
    ).

ready(Bound, G) :- term_variables(G, Vs), all_bound(Vs, Bound).
all_bound(Vs, Bound) :- forall(member(V, Vs), ( member(B, Bound), B == V )).

comparison_goal(G) :- compound(G), functor(G, F, 2), memberchk(F, [<, >, =<, >=, #<, #>, #=<, #>=, #<>]).
comparison_goal(G) :- compound(G), G =.. [K, _, _, _], memberchk(K, [blawx_comparison, date_compare, duration_compare]).

conj_list(V, [V]) :- var(V), !.
conj_list((A, B), L) :- !, conj_list(A, LA), conj_list(B, LB), append(LA, LB, L).
conj_list(G, [G]).

left_and([], true) :- !.
left_and([G|Gs], IR) :- foldl([X, A, and(A, X)]>>true, Gs, G, IR).

%   Bound0-Acc: the variables bound so far (for the direction of date_add).
goal_ir(Ctx, G, Bound0-Acc, Bound-[IR|Acc]) :-
    goal_ir1(Ctx, G, Bound0, IR),
    term_variables(G, Vs), append(Bound0, Vs, Bound).

goal_ir1(_, V, _, _) :- var(V), !, throw(residue("a variable as a condition")).
goal_ir1(Ctx, (A ; B), Bound, or(IA, IB)) :- !,
    translate_body_b(Ctx, A, Bound, IA), translate_body_b(Ctx, B, Bound, IB).
goal_ir1(Ctx, not(G), Bound, not(I)) :- !, translate_body_b(Ctx, G, Bound, I).
goal_ir1(Ctx, \+(G), Bound, not(I)) :- !, translate_body_b(Ctx, G, Bound, I).
goal_ir1(Ctx, -(G), _, Lit) :- callable(G), !, G =.. [F|Args], plain_lit(Ctx, neg(F), Args, Lit).
goal_ir1(Ctx, G, _, Lit) :- compound(G), scoped_literal(G, S, C, Args), !,
    section_constant(S, SC), scoped_lit(Ctx, S-C, Args, SC, Lit).
goal_ir1(Ctx, G, _, Lit) :- compound(G), G =.. [holds, user, P0|Args], !,
    conclusion(P0, C), plain_lit(Ctx, C, Args, Lit).
goal_ir1(Ctx, G, _, Lit) :- compound(G), G =.. [K, S, P0|Args], memberchk(K, [holds, according_to]), var(S), !,
    %  according to any section: the conclusion itself
    conclusion(P0, C), plain_lit(Ctx, C, Args, Lit).
goal_ir1(_, blawx_diseq(X, Y), _, le_not_equal_to(X1, Y1)) :- !, unwrap(X, X1), unwrap(Y, Y1).
goal_ir1(_, G, _, IR) :- G =.. [K, X, Op, Y], memberchk(K, [blawx_comparison, date_compare, duration_compare]), !,
    unwrap(X, X1), unwrap(Y, Y1), comparison(Op, X1, Y1, IR).
goal_ir1(_, date_add(X, D, Z), Bound, IR) :- !,
    unwrap(X, X1), unwrap(D, D1), unwrap(Z, Z1),
    (   var(Z1), \+ bound_var(Z1, Bound) -> IR = le_assign(Z1, X1 + D1)
    ;   var(X1), \+ bound_var(X1, Bound) -> IR = le_assign(X1, Z1 - D1)
    ;   var(D1), \+ bound_var(D1, Bound) -> IR = le_assign(D1, Z1 - X1)
    ;   IR = le_equal_to(Z1, X1 + D1)
    ).
goal_ir1(_, G, _, _) :- compound(G), functor(G, F, _),
    memberchk(F, [findall, count_blawx_list, sum_blawx_list, average_blawx_list, max_blawx_list, min_blawx_list,
                  blawx_list_not_between, blawx_list_not_before, blawx_list_not_after]), !,
    format(string(W), "a list aggregate (~w): the rule collects values with findall and Blawx's list predicates", [F]),
    throw(residue(W)).
goal_ir1(_, G, _, _) :- compound(G), functor(G, F, _), memberchk(F, [datetime_add, not_after]), !,
    format(string(W), "calls ~w, which Blawx ~w's reasoner does not define: the rule never applies in Blawx", [F, 'v1.6.22']),
    throw(residue(W)).
goal_ir1(_, G, _, IR) :- compound(G), functor(G, F, 2),
    memberchk(F, [=, \=, <, >, =<, >=, #=, #<>, #<, #>, #=<, #>=, is]), !,
    G =.. [F, A, B], unwrap(A, A1), unwrap(B, B1), G1 =.. [F, A1, B1],
    prolog_goal_ir(G1, IR).
goal_ir1(Ctx, G, _, Lit) :- literal_ir(Ctx, G, Lit).

translate_body_b(Ctx, G, _Bound, IR) :- translate_body(Ctx, G, IR).

bound_var(V, Bound) :- member(B, Bound), B == V, !.

comparison(eq, X, Y, le_equal_to(X, Y)).
comparison(ne, X, Y, le_not_equal_to(X, Y)).
comparison(neq, X, Y, le_not_equal_to(X, Y)).
comparison(lt, X, Y, le_lt(X, Y)).
comparison(gt, X, Y, le_gt(X, Y)).
comparison(lte, X, Y, le_le(X, Y)).
comparison(gte, X, Y, le_ge(X, Y)).

		 /*******************************
		 *           DENIALS            *
		 *******************************/

%   `false :- Body`: an LE integrity constraint, `it must not be true that`
%   the body (LE2 le_summary.md §3.3). As in s(CASP), a case whose facts meet
%   the conditions is inconsistent and answers nothing, and no answer may
%   assume what would meet them. (Until LE had timeless constraints this was
%   a query denial_<n> the scenarios expected to have no answer: N1.)
denials(Ctx, Clauses, Items, Ledger) :-
    findall(S-B, member(cl(S, (false :- B), _), Clauses), SBs),
    findall(constraint(IR, [comment(C)])-entry(E, constraint, encoded, M, 'it must not be true that …', Note),
            ( member(S-B, SBs),
              translate_body(Ctx, B, IR),
              section_locator(S, Loc), ctx_doc(Ctx, Doc),
              format(string(C), "The constraint of ~w of ~w: no case may meet these conditions — one that does is inconsistent, and nothing follows from it.", [Loc, Doc]),
              format(string(E), "false :- ... (~w)", [Loc]),
              M = 'a denial -> an integrity constraint, it must not be true that …',
              Note = "as in s(CASP), a model that meets the conditions is rejected: a case whose facts meet them answers nothing" ),
            Pairs),
    pairs_keys_values(Pairs, Items, Ledger).

		 /*******************************
		 *     THE TESTS, AS SCENARIOS  *
		 *******************************/

%!  tests(+Ctx, +Id, +BlawxTests, +Oracle, -Tests, -Queries, -Ledger)
tests(Ctx, Id, BTests, Oracle, Tests, Queries, Ledger) :-
    foldl(test_item(Ctx, Id, Oracle), BTests, []-[], _-Rev),
    reverse(Rev, Triples),
    findall(T, member(t(T, _, _), Triples), Tests0), exclude(==(none), Tests0, Tests),
    findall(Q, ( member(t(_, Qs, _), Triples), member(Q, Qs) ), Queries),
    findall(E, member(t(_, _, E), Triples), Ledger).

test_item(Ctx, Id, Oracle, test(TN, Cs, Q), Names0-Acc, [QN|Names0]-[t(Test, QItems, Entry)|Acc]) :-
    query_name(TN, Names0, QN),
    (   member(R, Oracle), atom_string(TN, TS), get_dict(test, R, TS) -> true ; R = _{status: "missing"} ),
    test_facts(Ctx, Cs, Facts, Abducibles),
    test_comments(Cs, Q, Comments),
    (   Q = query(G, Bs), catch(query_ir(Ctx, G, IRLit, Neg), residue(QWhy), fail)
    ->  QItems = [query(QN, IRLit)],
        expectation(R, QN, IRLit, Neg, Bs, Abducibles, Exp, Verdict, Note)
    ;   Q = query(G0, _)
    ->  QItems = [], term_string(G0, GS),
        ( var(QWhy) -> QWhy = "" ; true ),
        format(string(Note), "the query ~w is not translated: ~w", [GS, QWhy]),
        Exp = [], Verdict = residue
    ;   QItems = [], Exp = [], Verdict = encoded, Note = "the test asks nothing"
    ),
    Exps = Exp, Verdict1 = Verdict,
    atomic_list_concat(['test ', TN], Loc),
    findall(comment(F), ( finding(Id, TN, F) ), FComments),
    append([Comments, FComments, Facts], Lines),
    Test = test(QN, 'the Blawx project', Loc, Lines, Exps),
    format(string(E), "blawxtest ~w", [TN]),
    Entry = entry(E, test, Verdict1, 'a Blawx test -> a scenario; its expected answers are Blawx''s own (oracle.py)', QN, Note).

%   What building the twins found about a test, said where the test is read
%   (README, "Things found"): the twin follows Blawx's answer, never the
%   test's name.
finding(bird, pingu_with_jetpack_cant_fly,
    "NOTE: the test's name and its comment expect that pingu cannot fly; Blawx answers that pingu can fly, because the Act's \"except for pingu\" (section 5) is never wired into the encoding. The twin states Blawx's answer.").

pend(Why, E, pending(Why, E)) :- E \= pending(_, _), !.
pend(_, E, E).

query_name(TN, Seen, QN) :-
    downcase_atom(TN, L), atom_codes(L, Cs0),
    maplist([C0, C]>>( code_type(C0, alnum) -> C = C0 ; C = 0'_ ), Cs0, Cs),
    atom_codes(A0, Cs),
    ( sub_atom(A0, 0, 1, _, F), char_type(F, digit) -> atom_concat(test_, A0, A1) ; A1 = A0 ),
    (   \+ memberchk(A1, Seen) -> QN = A1
    ;   between(2, 100, K), format(atom(QN), '~w_~w', [A1, K]), \+ memberchk(QN, Seen) -> true
    ).

%   The test's facts (and rules), and the predicates it lets s(CASP) assume.
test_facts(Ctx, Cs, Facts, Abds) :-
    findall(F/N, ( member(c(#(abducible(Sp)), _, _), Cs), functor(Sp, F, N) ), Abds),
    findall(L, ( member(c(T, _, _), Cs), test_line(Ctx, T, L) ), Facts).

test_line(_, #(_), _) :- !, fail.
test_line(_, (:- _), _) :- !, fail.
test_line(_, syntax_error(_), _) :- !, fail.
test_line(_, '$comments', _) :- !, fail.
test_line(Ctx, (H :- B), L) :- !,
    catch(( literal_ir(Ctx, H, HI), translate_body(Ctx, B, BI), L = rule(HI, BI) ), residue(W),
          ( term_string((H :- B), S), format(string(C), "not translated: ~w (~w)", [S, W]), L = comment(C) )).
test_line(Ctx, T, L) :-
    (   compound(T), T =.. [holds, user, P0|Args] -> conclusion(P0, C), G = lit(C, Args)
    ;   T = holds(S, P0, A1) -> G = scoped(S, P0, [A1])
    ;   G = plain(T)
    ),
    catch(( test_lit(Ctx, G, Lit), L = Lit ), residue(W),
          ( term_string(T, S), format(string(Cm), "not translated: ~w (~w)", [S, W]), L = comment(Cm) )).

test_lit(Ctx, lit(C, Args), L) :- plain_lit(Ctx, C, Args, L).
test_lit(Ctx, scoped(S, P0, Args), L) :- conclusion(P0, C), section_constant(S, SC), scoped_lit(Ctx, S-C, Args, SC, L).
test_lit(Ctx, plain(T), L) :- literal_ir(Ctx, T, L).

test_comments(Cs, Q, Comments) :-
    findall(C, ( member(c(_, _, Ls), Cs), member(C0, Ls), C = comment(C0) ), C1),
    (   Q = query(_, _), fail -> true ; C2 = [] ),
    append(C1, C2, Comments).

%   The query: one literal (or its negation) of the program's templates.
query_ir(Ctx, not(G), IR, true) :- !, translate_body(Ctx, G, IR).
query_ir(Ctx, \+(G), IR, true) :- !, translate_body(Ctx, G, IR).
query_ir(Ctx, G, IR, false) :- translate_body(Ctx, G, IR).

%   What Blawx answered, as the scenario's expectation.
expectation(R, QN, IR, Neg, Bs, Abds, Exps, Verdict, Note) :-
    get_dict(status, R, St0), atom_string(St, St0),
    (   St == missing -> Exps = [], Verdict = approximated, Note = "no answer from the oracle"
    ;   St == error
    ->  Exps = [], Verdict = approximated,
        Note = "Blawx's own run of this test ends in an error (the query calls a predicate its reasoner does not define); no expectation"
    ;   Abds \== []
    ->  findall(S, ( member(F/N, Abds), format(string(S), "~w/~w", [F, N]) ), AS), atomic_list_concat(AS, ', ', AT),
        format(string(Why), "abductive: the test lets s(CASP) assume ~w (#abducible); Blawx's answers are hypotheses, which an LE scenario states as facts or not at all", [AT]),
        answers_literals(R, IR, Bs, Lits, _),
        ( Neg == true -> E0 = expects(QN, []) ; E0 = expects(QN, Lits) ),
        Exps = [pending(Why, E0)], Verdict = approximated, Note = Why
    ;   \+ single_literal(IR)
    ->  Exps = [], Verdict = approximated, Note = "a query of several conditions: no expectation"
    ;   answers_literals(R, IR, Bs, Lits, Symbolic),
        (   Symbolic == true
        ->  Why = "the answer is symbolic (a variable or a constraint), which LE's answers are not",
            Exps = [pending(Why, expects(QN, Lits))], Verdict = approximated, Note = Why
        ;   Neg == true
        ->  get_dict(answers, R, As),
            (   As \== [] -> Exps = [expects(QN, [])], Verdict = encoded,
                Note = "Blawx proves `not <the query>`: the twin's query expects no answer"
            ;   ground(IR) -> Exps = [expects(QN, [IR])], Verdict = encoded,
                Note = "Blawx cannot prove `not <the query>`: the twin's query expects its answer"
            ;   Exps = [], Verdict = approximated, Note = "a negated query with variables"
            )
        ;   Exps = [expects(QN, Lits)], Verdict = encoded, Note = none
        )
    ).

single_literal(IR) :- callable(IR), \+ ( IR = and(_, _) ; IR = or(_, _) ; IR = not(_) ; IR == true ).

%   Each row of Blawx's answers, as the query literal with its variables
%   bound (Symbolic: some value is a variable or a constraint).
answers_literals(R, IR, Bs, Lits, Symbolic) :-
    get_dict(answers, R, Rows),
    ( get_dict(constraints, R, Cons) -> true ; Cons = [] ),
    findall(L, ( member(Row, Rows), row_literal(Row, IR, Bs, L) ), Lits0),
    variant_set(Lits0, Lits),
    (   ( member(C, Cons), C \== [] ) -> Symbolic = true
    ;   ( member(L, Lits), \+ ground(L) ) -> Symbolic = true
    ;   Symbolic = false
    ).

row_literal(Row, IR, Bs, L) :-
    copy_term(Bs-IR, Bs1-L),
    dict_pairs(Row, _, Pairs),
    bind_row(Pairs, Bs1).

bind_row([], _).
bind_row([K-V|Ps], Bs) :-
    atom_string(KA, K),
    (   memberchk(KA=Var, Bs), var(Var) -> value_term(V, T), Var = T ; true ),
    bind_row(Ps, Bs).

value_term("_", _) :- !.
value_term(S, T) :- catch(term_string(T0, S), _, fail), !, unwrap(T0, T).
value_term(S, S).

		 /*******************************
		 *           THE ORACLE         *
		 *******************************/

%!  oracle_answers(+File, +Id, +Options, -Answers) is det.
%
%   Blawx's answers to the project's tests (oracle.py), kept in
%   runs/<Id>.json (Options: runs(Dir)) so that a build needs Python only
%   when the project changes.

%!  oracle_available is semidet.
%
%   Blawx's reasoner can run here: its preamble is fetched
%   (fetch_sources.sh), Python can read the projects, and the SWI-Prolog
%   oracle.py runs ($SWIPL, else swipl) has library(scasp). Without the
%   last, every run would end in an error — and be kept in runs/ as if it
%   were Blawx's answer.
oracle_available :- \+ oracle_unavailable(_).

%!  oracle_unavailable(-Why) is semidet.
%
%   Why Blawx's reasoner cannot run here (a sentence for the user).
oracle_unavailable(Why) :-
    (   here(H), format(atom(F), '~w/.cache/blawx/blawx/ldap.py', [H]), \+ exists_file(F)
    ->  Why = "Blawx's reasoner preamble is not fetched here (the Blawx translator's fetch_sources.sh): the scenarios carry no expected answers."
    ;   \+ catch(( process_create(path(python3), ['-c', 'import yaml'], [stdout(null), stderr(null), process(P)]),
                   process_wait(P, exit(0)) ), _, fail)
    ->  Why = "Python 3 with PyYAML is not available here, so Blawx's reasoner cannot run: the scenarios carry no expected answers."
    ;   \+ scasp_available
    ->  Why = "Blawx's reasoner cannot run here: the SWI-Prolog it uses has no s(CASP) library (pack_install(scasp)). The scenarios carry no expected answers, so the counts above check nothing."
    ).

:- dynamic scasp_checked/2.

scasp_available :-
    ( getenv('SWIPL', Swipl) -> Exe = Swipl ; Exe = path(swipl) ),
    (   scasp_checked(Exe, Ok) -> true
    ;   (   catch(( process_create(Exe, ['-q', '-g', 'use_module(library(scasp)),halt(0)', '-t', 'halt(1)'],
                                   [stdout(null), stderr(null), process(P)]),
                    process_wait(P, exit(0)) ), _, fail)
        ->  Ok = true ; Ok = false
        ),
        assertz(scasp_checked(Exe, Ok))
    ),
    Ok == true.

runs_dir(Opts, D) :- ( option(runs(D0), Opts) -> D = D0 ; here(H), format(atom(D), '~w/runs', [H]) ).
oracle_answers(File, Id, Opts, Answers) :-
    runs_dir(Opts, RD), format(atom(Run), '~w/~w.json', [RD, Id]),
    (   exists_file(Run), time_file(Run, TR), time_file(File, TF), TR >= TF
    ->  true
    ;   make_directory_path(RD),
        oracle_run(['--all'], File, Out),
        setup_call_cleanup(open(Run, write, S, [encoding(utf8)]), write(S, Out), close(S))
    ),
    setup_call_cleanup(open(Run, read, In, [encoding(utf8)]), json_read_dict(In, Answers), close(In)).

oracle_run(Args, File, Out) :-
    here(H), format(atom(Py), '~w/oracle.py', [H]),
    absolute_file_name(File, Abs),
    process_create(path(python3), [Py, Abs|Args], [stdout(pipe(O)), stderr(null), process(P)]),
    read_string(O, _, Out), close(O), process_wait(P, _).

		 /*******************************
		 *     QUERIES AND THE VIEW     *
		 *******************************/

%   A query per conclusion no other rule reads (what the Act decides).
conclusion_queries(_Ctx, RuleItems, TestQueries, Queries) :-
    findall(F/N, ( member(rule(H, _, _), RuleItems), functor(H, F, N) ), Hs0), list_to_set(Hs0, Hs),
    findall(F/N, ( member(rule(_, B, _), RuleItems), sub_term(L, B), compound(L), functor(L, F, N), memberchk(F/N, Hs) ), Read0),
    list_to_set(Read0, Read),
    findall(query(QN, L),
            ( member(F/N, Hs), \+ memberchk(F/N, Read), \+ sub_atom(F, _, _, 0, '_under'),
              \+ ( member(query(_, TL), TestQueries), functor(TL, F, N), \+ ground(TL) ),
              functor(L, F, N), format(atom(QN), 'which_~w', [F]) ),
            Queries).

view_item(Title, Ctx, RuleItems, CQueries, TQueries, view(VName, Sentences)) :-
    ctx_preds(Ctx, Preds),
    findall(F, ( member(rule(H, _, _), RuleItems), functor(H, F, _) ), Concluded),
    ctx_inputs(Ctx, Inputs), ctx_abds(Ctx, Abds),
    %  the case's facts: its inputs, which the program marks scenario
    %  elements; an assumable one (`; unknown`) is answered as an unknown,
    %  not asked as a fact of the case
    findall(Ph, ( member(p(FN, IRF, Text, template(_)), Preds), memberchk(FN, Inputs),
                  \+ memberchk(FN, Abds),
                  \+ memberchk(IRF, Concluded), phrase_of(Text, Ph) ), Phs0),
    list_to_set(Phs0, Phs1), length(Phs1, NP), ( NP > 14 -> length(Phs, 14), append(Phs, _, Phs1) ; Phs = Phs1 ),
    %  the result: what most sections conclude (the Bird Act's `can fly`)
    (   CQueries \== []
    ->  findall(C-QN, ( member(query(QN, L), CQueries), functor(L, F, _),
                        aggregate_all(count, ( member(rule(H, _, _), RuleItems), functor(H, F, _) ), C) ), CQs),
        max_member(_-Q, CQs)
    ;   TQueries = [query(Q, _)|_] -> true
    ;   Q = none
    ),
    format(atom(VName), 'the act', []),
    format(string(T), "the title is \"~w, as Blawx encodes it\".", [Title]),
    (   Phs == [] -> FactS = []
    ;   atomic_list_concat(Phs, ',\n        ', PT),
        format(string(FS), "the facts about \"the case\" are\n        ~w.", [PT]), FactS = [FS]
    ),
    (   Q == none -> RS = []
    ;   format(string(R1), "the result is the answer to query ~w.", [Q]),
        RS = [R1, "the result shows its reasons.", "the result shows its citations.", "the result can be flipped."]
    ),
    append([[T, "the case is a scenario, with the documents it is stated in."], FactS, RS], Sentences).

phrase_of(Text, Ph) :-
    atom_string(Text, S), split_string(S, "*", "", Parts),
    atomic_list_concat(Parts, '', Ph0), normalize_space(atom(Ph), Ph0).

%   Blawx reads the machine's clock (dates.py); the twin states the day it
%   was built, and so does the oracle.
clock_items(Ctx, Clauses, Items, Ledger) :-
    findall(F, ( member(cl(_, T, _), Clauses), sub_term(X, T), compound(X), functor(X, F, 1),
                 memberchk(F, [blawx_today, blawx_now]) ), Fs0),
    list_to_set(Fs0, Fs),
    (   Fs == [] -> Items = [], Ledger = []
    ;   clock_date(D), oracle_clock(Secs),
        findall(fact(L, []), ( member(F, Fs), literal_ir(Ctx, t(F, Secs), L0), L = L0 ), Facts0),
        format(string(C), "Blawx's clock, fixed at ~w (00:00 UTC, ~w seconds since 1970), the day the twin was built.", [D, Secs]),
        Items = [comment(C)|Facts0],
        format(string(E), "blawx_now / blawx_today (~w)", [D]),
        Ledger = [entry(E, clock, approximated, 'the machine clock -> a fact of the day the twin was built (the oracle uses the same)', 'the date today', "Blawx answers with the day it runs; the twin and the oracle with a fixed one")]
    ).

oracle_clock(1789344000).

replace_all(S0, A, B, S) :-
    atomic_list_concat(Parts, A, S0), atomic_list_concat(Parts, B, S1), atom_string(S1, S).

variant_set([], []).
variant_set([X|Xs], [X|Ys]) :- exclude(=@=(X), Xs, Xs1), variant_set(Xs1, Ys).

		 /*******************************
		 *        GENERATED CASES       *
		 *******************************/

types_of(Decls, F/N, Types) :- templated(Decls, F/N), place_types(Decls, F/N, Types).

%   The cases blawx_cases.pl writes from the rules, answered by Blawx
%   (oracle.py --batch, kept in runs/<Id>.cases.json with the cases asked).
generated_tests(Ctx, File, Id, Opts, Decls, Clauses, TestQueries, Tests, Queries, Ledger) :-
    rule_cases(Clauses, Decls, blawx_twin:types_of(Decls), Cases),
    (   Cases == [] -> Tests = [], Queries = [], Ledger = []
    ;   maplist(case_json, Cases, CJ),
        case_answers(File, Id, Opts, CJ, Answers),
        foldl(case_test(Ctx, TestQueries), Cases, Answers-[]-[], _-TsR-QsR),
        reverse(TsR, Tests0), exclude(==(none), Tests0, Tests),
        reverse(QsR, Qs0), queries_by_name(Qs0, Queries),
        length(Tests, NT),
        format(string(E), "~w cases generated from the rules", [NT]),
        Ledger0 = [entry(E, 'generated cases', encoded,
                        'each rule met by facts, each near miss, each defeat: Blawx''s answers as the expectations', 'the case_ scenarios',
                        "not Blawx's tests: written by blawx_cases.pl from the encoding; the answers are Blawx's own")],
        (   oracle_flags(File, ['--drop-circular'])
        ->  Ledger = [entry("the oracle for the cases", oracle, approximated,
                            'Blawx''s program without its rules that need their own conclusion', 'the case_ scenarios',
                            "s(CASP) 1.1.4 proves nothing at all of a predicate caught in such a rule (with it, nothing is a business in Rule 34, not even a business stated as a fact); without it, the stated ones. The rule adds nothing in the least model or the stable models, and the twin leaves it out too")|Ledger0]
        ;   Ledger = Ledger0
        )
    ).

case_json(C, _{id: Id, facts: FT, query: QT}) :-
    C = case(Id, _, _, _), case_text(C, FT, QT).

case_answers(File, Id, Opts, CJ, Answers) :-
    runs_dir(Opts, RD), make_directory_path(RD), format(atom(Run), '~w/~w.cases.json', [RD, Id]),
    (   exists_file(Run),
        setup_call_cleanup(open(Run, read, In, [encoding(utf8)]), json_read_dict(In, Old), close(In)),
        json_text(Old.cases, K1), json_text(CJ, K2), K1 == K2,      % (dicts read back have other tags)
        time_file(Run, TR), time_file(File, TF), TR >= TF
    ->  Answers = Old.answers
    ;   tmp_file_stream(text, CF, S0), json_write_dict(S0, CJ, [width(0)]), close(S0),
        oracle_flags(File, Flags),
        oracle_run(['--batch', CF|Flags], File, Out),
        atom_json_dict(Out, Answers0, []),
        (   project_has_abducibles(File)
        ->  %  the same cases with nothing assumed: an answer that needs Blawx
            %  to assume a fact the case does not state is marked hypothetical
            oracle_run(['--batch', CF, '--drop-abducibles'|Flags], File, Out2),
            atom_json_dict(Out2, Closed, []),
            maplist(mark_hypothetical, Answers0, Closed, Answers)
        ;   Answers = Answers0
        ),
        delete_file(CF),
        setup_call_cleanup(open(Run, write, S, [encoding(utf8)]),
                           json_write_dict(S, _{cases: CJ, answers: Answers, flags: Flags}, [width(100)]),
                           close(S))
    ).

%   A project with a rule that needs its own conclusion: s(CASP) 1.1.4
%   proves nothing of the predicate caught in it (Rule 34's "business"), so
%   the cases are answered by Blawx's program without such rules — which
%   mean nothing in the least model or the stable models (the twin leaves
%   them out too). The ledger says so.
oracle_flags(File, Flags) :-
    (   blawx_project(File, project(_, _, _, Sections, _)),
        member(section(_, Cs), Sections), member(c((H :- B), _, _), Cs), nonvar(H),
        H =.. [according_to, _, P|Args], atom(P), G =.. [P|Args],
        conj_list(B, Gs), member(X, Gs), X == G
    ->  Flags = ['--drop-circular']
    ;   Flags = []
    ).

project_has_abducibles(File) :-
    blawx_project(File, project(_, _, _, Sections, _)),
    member(section(_, Cs), Sections), member(c(#(abducible(_)), _, _), Cs), !.

mark_hypothetical(A, C, A1) :-
    (   get_dict(answers, A, As), get_dict(answers, C, Cs), msort(As, SA), msort(Cs, SC), SA \== SC
    ->  A1 = A.put(hypothetical, true)
    ;   A1 = A
    ).

case_test(Ctx, TestQueries, case(Id, S, Facts, Q), [R|Rs]-Ts-Qs, Rs-[T|Ts]-Qs1) :-
    (   catch(case_parts(Ctx, Facts, Q, Lines, QLit, QN), residue(_), fail)
    ->  Q =.. [_|Vs0], ( Q = -(G0) -> G0 =.. [_|Vs] ; Vs = Vs0 ),
        length(Vs, NV), numlist1(NV, Ks),
        %  the names the oracle prints the query's variables with: A, B, ...
        maplist([K, V, N=V]>>( C0 is 0'A + K - 1, char_code(N, C0) ), Ks, Vs, Bs),
        (   get_dict(hypothetical, R, true)
        ->  expectation(R.put(status, "ok"), QN, QLit, false, Bs, [], Exps0, _, _),
            HW = "Blawx's answer here needs it to assume a fact the case does not state (the Act declares #abducible), which LE reports as an unknown",
            maplist(pend(HW), Exps0, Exps)
        ;   expectation(R, QN, QLit, false, Bs, [], Exps, _, _)
        ),
        section_locator(S, Loc),
        format(string(C), "a case of the rule of ~w (blawx_cases.pl), answered by Blawx", [Loc]),
        T = test(Id, 'the case analysis of the encoding', Loc, [comment(C)|Lines], Exps),
        (   memberchk(query(QN, _), TestQueries) -> Qs1 = Qs ; Qs1 = [query(QN, QLit)|Qs] )
    ;   T = none, Qs1 = Qs
    ).

case_parts(Ctx, Facts, Q, Lines, QLit, QN) :-
    findall(L, ( member(F, Facts), test_line(Ctx, F, L) ), Lines),
    \+ memberchk(comment(_), Lines),
    (   Q = -(G) -> G =.. [F|Args], plain_lit(Ctx, neg(F), Args, QLit)
    ;   Q =.. [F|Args], plain_lit(Ctx, F, Args, QLit)
    ),
    functor(QLit, QF, _), format(atom(QN), 'which_~w', [QF]).

%   One query per name (each case asks the same conclusion).
queries_by_name([], []).
queries_by_name([query(N, B)|Qs], [query(N, B)|Out]) :-
    other_names(Qs, N, Qs1),
    queries_by_name(Qs1, Out).

other_names([], _, []).
other_names([query(N2, B)|Qs], N, Out) :-
    ( N2 == N -> Out = Out1 ; Out = [query(N2, B)|Out1] ), other_names(Qs, N, Out1).

not_asked([], _, []).
not_asked([query(N, B)|Qs], Asked, Out) :-
    ( memberchk(query(N, _), Asked) -> Out = Out1 ; Out = [query(N, B)|Out1] ),
    not_asked(Qs, Asked, Out1).

json_text(T, S) :- with_output_to(string(S), json_write_dict(current_output, T, [width(0)])).

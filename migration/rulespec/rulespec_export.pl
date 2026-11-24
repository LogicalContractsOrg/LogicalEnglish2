/** <module> File ▸ Export to Another System… → Axiom RuleSpec

    The way back of Phase 3a (roadmap.md §5.10, decision 7 of the October
    plan): a timeless Logical English program as one RuleSpec module
    (`format: rulespec/v1`), and its scenarios as the module's companion
    test cases. What becomes what:

      - a template `the W of *a household* is *an amount*` concluded by rules
        → a `derived` rule `W` of entity Household, dtype Money (an amount),
        Rate (a rate) or Decimal; a sentence `*a household* is W` concluded
        by rules → a derived `Judgment`;
      - a rule's conditions → its formula: a condition reading a value is the
        value's name, `X = A * B` and `the maximum of A and B is C` the
        arithmetic, a comparison a comparison, `it is not the case that` a
        `not`; several rules for one sentence → `or`; an `otherwise` cascade
        → `if … : … else: …`; `the count of each P such that …` over a
        two-place sentence → `count_where`/`len`, `the sum of each …` →
        `sum_where`/`sum`;
      - a fact `the W is 0.3` → a `parameter`; facts `the W for 1 is 298`
        → an indexed parameter with a `values` table; a provenance trailer →
        the rule's `source`;
      - rules guarded by `the calculation date` (on or after D, before E) →
        dated `versions`;
      - a template no rule or fact concludes → an input the test cases give;
        a two-place sentence between two kinds of thing → a `data_relation`;
      - each scenario → a test case: its facts the `input` (a sentence not
        stated is `false`), the answers it expects the `output` (an
        expectation with no answer is `not_holds`), the calculation date the
        `period`.

    Refused, with the reason and the line (le_import's export check): a rule
    reading a value of something other than its own subject outside an
    aggregate over a relation, a rule concluding a value only under
    conditions (RuleSpec has no "no value"), a list, a string operation, a
    template with three places or more, recursion, a fact about a particular
    case outside a scenario.

    export_rulespec(+KB, +Options, -Result): exported(FileName, Text, Notes,
    Links) with the module, and its test cases after it as a commented
    block (a RuleSpec module is one file; the engine reads the test cases
    from a second); export_files(+KB, +ModuleId, -ModuleText, -TestText) for
    the round trip (roundtrip.pl).

    Given the program's text (text(Doc) in the exporter's Options), each
    problem names the rule or template it is about, so that a partial export
    can leave exactly those out, and each rule of the module has a comment
    above it naming the lines of the program it was written from
    (le_import.pl, "Provenance"). OpenFisca's and Catala's exporters share
    both: provenance_text/2, place_problems/3.
*/

:- module(rulespec_export, [export_rulespec/3, applies_rulespec/1, check_rulespec/3, export_files/4,
                            provenance_text/2, place_problems/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pcre)).
:- use_module(library(yaml)).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer), []).

:- dynamic t_/4, name_/2, problem_/2, src_/5, also_/2, prog_/2.

%!  applies_rulespec(+KB) is semidet.
%   A timeless program with at least one rule.
applies_rulespec(KB) :-
    le_writer:kb_to_ir(KB, program(H, Items)),
    \+ memberchk(target(lps), H),
    memberchk(rule(_, _, _), Items), !.

%!  check_rulespec(+KB, +Options, -Problems) is det.
%
%   Each problem is placed (le_import.pl, "Where a problem is matters
%   twice"): at(Start, End) of the rule it is about, predicate(F/N) for a
%   template as a whole or a value whose rules fail only together, `none`
%   only for an error of the analysis itself. A partial export leaves out
%   exactly those clauses.
check_rulespec(KB, Options, Problems) :-
    catch(( analyse(KB, 'lc:program', _, _, Options), findall(problem(W, M), problem_(W, M), Problems) ),
          E, ( message_to_string(E, S), Problems = [problem(none, S)] )).

%!  export_rulespec(+KB, +Options, -Result) is det.
export_rulespec(KB, Options, Result) :-
    le_writer:kb_to_ir(KB, program(H, _)),
    ( memberchk(kb(Name), H) -> true ; Name = program ),
    format(atom(MId), 'us:policies/logical-english/~w', [Name]),
    export_files(KB, MId, Module, Tests, Problems, Options),
    (   Problems \== []
    ->  Result = refused(Problems)
    ;   split_string(Tests, "\n", "", TLs),
        findall(L, ( member(T, TLs), ( T == "" -> L = "#" ; string_concat("# ", T, L) ) ), CLs),
        atomic_list_concat(CLs, '\n', Commented),
        format(string(Text), "~s~n# ---------------------------------------------------------------------~n# The scenarios, as this module's test cases. Save the lines below,~n# without their leading '# ', as ~w.test.yaml beside the module.~n# ---------------------------------------------------------------------~n~s~n",
               [Module, Name, Commented]),
        format(atom(File), '~w.yaml', [Name]),
        Notes = ["The module is one RuleSpec file; its test cases (the program's scenarios, with the answers they expect) follow it as a commented block, to be saved as the companion .test.yaml.",
                 "Run it with Axiom's engine: axiom-rules-engine compile --program <module> --rulespec-root <a rulespec-us checkout>, then run-compiled (with an engine built from its `main` branch)."],
        Result = exported(File, Text, Notes, [])
    ).

%!  export_files(+KB, +ModuleId, -ModuleText, -TestText) is det.
export_files(KB, MId, Module, Tests) :-
    export_files(KB, MId, Module, Tests, Problems),
    (   Problems == [] -> true
    ;   throw(error(rulespec_export_refused(Problems), _))
    ).

export_files(KB, MId, Module, Tests, Problems) :-
    export_files(KB, MId, Module, Tests, Problems, []).

%   With the exporter's Options: text(Doc) gives each rule of the module the
%   lines of the program it came from (the comment above it).
export_files(KB, MId, Module, Tests, Problems, Options) :-
    analyse(KB, MId, Rules, Cases, Options),
    findall(problem(W, M), problem_(W, M), Problems0),
    (   Problems0 == []
    ->  module_yaml(MId, KB, Rules, Module0, Problems),
        (   Problems == []
        ->  Module = Module0, tests_yaml(Cases, Tests)
        ;   Module = "", Tests = ""
        )
    ;   Problems = Problems0, Module = "", Tests = ""
    ).


		 /*******************************
		 *           ANALYSIS           *
		 *******************************/

%   t_(Functor, Arity, Shape, Info): what each template becomes.
%     Shape: derived(scalar|judgment, Entity) | parameter | table(IndexName)
%            | input(scalar|judgment, Entity) | relation(EntityA, EntityB)
%   name_(Functor, RuleSpecName)

analyse(KB, MId, Rules, Cases) :-
    analyse(KB, MId, Rules, Cases, []).

%   With text(Doc) in Options the IR carries each rule's and fact's
%   source(Line, Start, End) (le_writer:kb_to_ir/3), kept as src_/5: where a
%   problem is, and the lines each element of the output came from.
%   Without it nothing is placed more precisely than its template.
analyse(KB, MId, Rules, Cases, Options) :-
    retractall(t_(_, _, _, _)), retractall(name_(_, _)), retractall(problem_(_, _)),
    retractall(src_(_, _, _, _, _)), retractall(also_(_, _)), retractall(prog_(_, _)),
    (   memberchk(text(Doc), Options), ( string(Doc) ; atom(Doc) )
    ->  le_writer:kb_to_ir(KB, [text(Doc)], program(_, Items0))
    ;   le_writer:kb_to_ir(KB, program(_, Items0))
    ),
    forall(( member(It, Items0), ( It = rule(H, _, O) ; It = fact(H, O) ), compound_or_atom(H),
             is_list(O), memberchk(source(L, S, E), O), integer(L) ),
           ( functor(H, F, N), assertz(src_(F, N, L, S, E)) )),
    maplist(strip_at, Items0, Items),
    include([I]>>( I = template(_, _, _) ; I = function(_, _, _) ), Items, Ts),
    findall(rule(H, B, O), member(rule(H, B, O), Items), Rs),
    findall(fact(H, O), ( member(fact(H, O), Items), \+ functor(H, le_text_at, _), \+ functor(H, le_published_at, _) ), Fs),
    assertz(prog_(Rs, Fs)),                 % (where a problem found while writing is)
    forall(member(T, Ts), classify(T, Rs, Fs)),
    given_inputs,
    rules_out(Rs, Fs, Rules0),
    one_problem_per_clause,
    maplist(mark_overridable, Rules0, Rules),
    findall(_, member(scenario(_, _, _), Items), _),
    findall(case(N, Lines), member(scenario(N, Lines, _), Items), Ss),
    findall(Q-G, member(query(Q, G), Items), Qs),
    maplist(case_out(MId, Ts, Qs), Ss, Cases).

%   A value a case may give in place of its rule's (the twin of a Catala
%   `context`: `the X given is V`, the rule's first alternative): not an
%   input of its own, but the rule's value a test sets.
:- dynamic given_t/3, overridden/1.
given_inputs :-
    retractall(given_t(_, _, _)), retractall(overridden(_)),
    findall(GF-GN0-E-Base,
            ( t_(GF, GN0, input(scalar, E), _),
              member(G, ['_given_', '_donné_']), sub_atom(GF, Bf, _, Af, G),
              sub_atom(GF, 0, Bf, _, Pre), sub_atom(GF, _, Af, 0, Post), atomic_list_concat([Pre, '_', Post], DF),
              t_(DF, _, derived(scalar, _), _), name_(DF, Base) ), Gs),
    forall(member(GF-GN0-E-Base, Gs),
           ( assertz(given_t(GF, Base, E)), retract(t_(GF, GN0, input(scalar, E), _)) )).

%   A rule's alternatives without the given value first.
strip_given(H-B0-O, H-B-O) :-
    (   B0 = or(A, and(not(_), Rest)), compound(A), functor(A, GF, _), given_t(GF, Name, _)
    ->  B = Rest, assert_once_(overridden(Name))
    ;   B = B0
    ).
assert_once_(F) :- ( call(F) -> true ; assertz(F) ).

mark_overridable(rs(N, derived, A, Vs), rs(N, derived, [overridable-true|A], Vs)) :- overridden(N), !.
mark_overridable(R, R).

strip_at(V, V) :- var(V), !.
strip_at(le_at(G, _, _), G1) :- !, strip_at(G, G1).
strip_at(T, T) :- \+ compound(T), !.
strip_at(T, T1) :- T =.. [F|As], maplist(strip_at, As, Bs), T1 =.. [F|Bs].

template_parts(Text, Words, Places) :-
    split_string(Text, " ", "", Ws0), exclude(==(""), Ws0, Ws),
    parts(Ws, Words, Places).

%   Words: the template's words with each place as place(Noun).
parts([], [], []).
parts([W|Ws], [place(Noun)|Out], [Noun|Ps]) :-
    sub_string(W, 0, 1, _, "*"), !,
    gather_place([W|Ws], PWs, Rest),
    atomic_list_concat(PWs, ' ', P0), split_string(P0, "", "*", [P1]),
    split_string(P1, " ", "", [_Art|NWs]), atomic_list_concat(NWs, ' ', Noun),
    parts(Rest, Out, Ps).
parts([W|Ws], [W|Out], Ps) :- parts(Ws, Out, Ps).

gather_place([W|Ws], [W], Ws) :- sub_string(W, _, 1, 0, "*"), string_length(W, L), L > 1, !.
gather_place([W|Ws], [W|More], Rest) :- gather_place(Ws, More, Rest).

classify(T, Rs, Fs) :-
    ( T = template(F, Text, Adds) ; T = function(F, Text, Adds) ), !,
    template_parts(Text, Words, Places),
    length(Places, N),
    ( concluded_by_rule(F, N, Rs) -> Ruled = yes ; Ruled = no ),
    ( stated_by_fact(F, N, Fs) -> Facted = yes ; Facted = no ),
    value_place(Words, Places, ValueAt),
    entity_of(Places, ValueAt, Entity),
    (   N =:= 4, Facted == yes, Ruled == no, sub_atom(Text, _, _, _, 'from *a first date* to *a last date*')
    ->  Shape = dated_rows
    ;   N =:= 2, Ruled == yes, ValueAt \== none, selects_dated_rows(F, Rs, _)
    ->  Places = [K|_], Shape = table(K)
    ;   ValueAt == none, N =:= 2, Ruled == no
    ->  Places = [A, B], Shape = relation(A, B)
    ;   N > 2 -> Shape = unsupported(N)
    ;   Ruled == yes, ValueAt \== none,
        findall(H-B-O, ( member(rule(H, B, O), Rs), functor(H, F, N) ), HBs), dated_parameter(HBs, _)
    ->  ( N =:= 1 -> Shape = parameter ; Places = [K|_], Shape = table(K) )
    ;   ValueAt == none, Ruled == yes -> Shape = derived(judgment, Entity)
    ;   ValueAt == none -> Shape = input(judgment, Entity)
    ;   Ruled == yes -> Shape = derived(scalar, Entity)
    ;   Facted == yes, N =:= 1 -> Shape = parameter
    ;   Facted == yes, N =:= 2 -> Places = [K, _], Shape = table(K)
    ;   Shape = input(scalar, Entity)
    ),
    (   label_name(F, N, Rs, Name0) -> Name = Name0 ; rs_name(Words, Shape, Name) ),
    value_noun(Places, ValueAt, VN),
    assertz(t_(F, N, Shape, info(Text, VN, Adds))),
    assertz(name_(F, Name)).

%   The name a rule's label gives (the twins label each rule with the
%   source's own name; alternatives of one rule end `_1`, `_2`, …).
label_name(F, N, Rs, Name) :-
    findall(L, ( member(rule(H, _, O), Rs), functor(H, F, N), memberchk(label(L0), O), atom_string(L, L0) ), Ls),
    Ls = [L1|_],
    (   Ls = [_, _|_], atomic_list_concat(Ps, '_', L1), append(Base, [Last], Ps), atom_number(Last, _)
    ->  atomic_list_concat(Base, '_', Name)
    ;   Name = L1
    ),
    clean_name(Name, Name).

%   The rule of a dated table: the row in force on the calculation date.
selects_dated_rows(F, Rs, DF) :-
    member(rule(H, B, _), Rs), functor(H, F, 2),
    conjuncts(B, Cs), member(G, Cs), compound(G), functor(G, DF, 4),
    ( sub_atom(DF, _, _, 0, '_dated') ; sub_atom(DF, _, _, 0, '_from_to_is') ), !.

iso_of(date(Y, M, D), A) :- !, iso(Y, M, D, A).
iso_of(A, A).

concluded_by_rule(F, N, Rs) :- member(rule(H, _, _), Rs), functor(H, F, N), !.
stated_by_fact(F, N, Fs) :- member(fact(H, _), Fs), functor(H, F, N), !.

%   A template whose last words are `is *a value*` has a value.
value_place(Words, Places, At) :-
    (   append(_, [W, place(_)], Words), is_word(W) -> length(Places, At) ; At = none ).

%   The words of a template that say "is", "of" and "the", in English and in
%   French (a twin of Catala's French dialect is written in Français Logique).
is_word(W) :- memberchk(W, ["is", "are", "est", "sont"]).
of_word(W) :- memberchk(W, ["of", "for", "de", "du", "des", "pour"]).
article_word(W) :- memberchk(W, ["the", "le", "la", "les"]).

entity_of([], _, none) :- !.
entity_of([P|_], At, E) :- ( At == 1 -> E = none ; noun_entity(P, E) ).

noun_entity(Noun, E) :-
    split_string(Noun, " ", "", Ws), maplist([W, C]>>( string_chars(W, [H|T]), upcase_atom(H, U), atom_chars(U, [UH]), atom_chars(C, [UH|T]) ), Ws, Cs),
    atomic_list_concat(Cs, E).

value_noun(Places, At, VN) :- ( integer(At) -> nth1(At, Places, VN) ; VN = none ).

%   The RuleSpec name of a template: its words without its places, `the`
%   first, the subject's `of` and the value's `is`.
rs_name(Words0, Shape, Name) :-
    ( Words0 = [A0|W1], article_word(A0) -> true ; W1 = Words0 ),
    ( Shape = relation(_, _) -> W1a = W1 ; drop_of_place(W1, W1a) ),
    exclude([X]>>( X = place(_) ), W1a, W2),
    (   value_shape(Shape)
    ->  ( append(W3, [Is], W2), is_word(Is) -> true ; W3 = W2 ),
        ( append(W4, [Of], W3), of_word(Of) -> true ; W4 = W3 )
    ;   Shape = relation(_, B)
    ->  ( W2 = ["is", "a"|W5] -> true ; W2 = ["is"|W5] -> true ; W5 = W2 ),
        split_string(B, " ", "", BWs), append(W5, BWs, W4)
    ;   ( W2 = ["is"|W4] -> true ; W4 = W2 )
    ),
    maplist([S, A]>>( string_lower(S, L), atom_string(A, L) ), W4, As),
    atomic_list_concat(As, '_', Name0),
    clean_name(Name0, Name).

%   `of` or `for` before the subject's place says nothing in a name:
%   `the youth exemption of *a person* applies` is youth_exemption_applies.
drop_of_place([], []).
drop_of_place([W, place(P)|Ws], [place(P)|Out]) :- of_word(W), !, drop_of_place(Ws, Out).
drop_of_place([W|Ws], [W|Out]) :- drop_of_place(Ws, Out).

value_shape(derived(scalar, _)).
value_shape(input(scalar, _)).
value_shape(parameter).
value_shape(table(_)).

clean_name(N0, N) :-
    atom_codes(N0, Cs0),
    maplist([C0, C]>>( code_type(C0, csym) -> C = C0 ; C = 0'_ ), Cs0, Cs),
    atom_codes(N1, Cs),
    ( sub_atom(N1, 0, 1, _, F), char_type(F, digit) -> atom_concat(n_, N1, N) ; N = N1 ).

problem(Where, Fmt, Args) :-
    format(string(M), Fmt, Args),
    ( problem_(Where, M) -> true ; assertz(problem_(Where, M)) ).

compound_or_atom(H) :- ( compound(H) ; atom(H) ), !.


		 /*******************************
		 *    PLACES AND PROVENANCE     *
		 *******************************/

%   Where a problem about one rule is: its own text, or (a rule of an
%   included resource, whose position is not in this program) every clause
%   of its predicate.
rule_where(H-_-O, W) :- rule_where_(H, O, W).
rule_where_(H, O, W) :-
    (   is_list(O), memberchk(source(_, S, E), O), integer(S) -> W = at(S, E)
    ;   functor(H, F, N), W = predicate(F/N)
    ).

%   Where a problem about a template as a whole is: every clause of it.
%   A template no clause states (an input) is placed on the rules that read
%   it, which cannot be written without it; one nothing reads is no
%   problem, since nothing of it would be written.
template_wheres(F, N, Rs, Fs, Ws) :-
    (   ( member(rule(H, _, _), Rs) ; member(fact(H, _), Fs) ), functor(H, F, N)
    ->  Ws = [predicate(F/N)]
    ;   findall(W, ( member(rule(H, B, O), Rs), uses(B, F, N), rule_where_(H, O, W) ), Ws0),
        sort(Ws0, Ws)
    ).

uses(B, F, N) :- sub_term(T, B), compound_or_atom(T), functor(T, F, N), !.

%   A clause is named by one problem at most: a partial export erases the
%   clauses each problem names, and le_import's partial_loop fails on a
%   clause erased twice.
one_problem_per_clause :-
    findall(problem(W, M), problem_(W, M), Ps0),
    one_per_clause(Ps0, Ps),
    retractall(problem_(_, _)),
    forall(member(problem(W, M), Ps), assertz(problem_(W, M))).

%   A problem placed on a rule whose template is refused as a whole moves
%   to the template; problems at one place become one, their messages
%   joined.
one_per_clause(Ps0, Ps) :-
    maplist(to_template(Ps0), Ps0, Ps1),
    findall(W, member(problem(W, _), Ps1), Ws0), list_to_set(Ws0, Ws),
    findall(problem(W, J),
            ( member(W, Ws), findall(M, member(problem(W, M), Ps1), Ms0), list_to_set(Ms0, Ms),
              atomic_list_concat(Ms, '; ', A), atom_string(A, J) ),
            Ps).

to_template(Ps, problem(at(S, E), M), problem(predicate(F/N), M)) :-
    src_(F, N, _, S, E), memberchk(problem(predicate(F/N), _), Ps), !.
to_template(_, P, P).

%   Where a problem about an element of the output (by its RuleSpec name)
%   is: the one clause it comes from, or its template's every clause, or
%   (a template no clause states) the rules that read it; none when
%   nothing states or reads it, since nothing of it is written.
rs_wheres(Name, Ws) :-
    once(( name_(F, Name), t_(F, N, _, _) )),
    prog_(Rs, Fs),
    template_wheres(F, N, Rs, Fs, Ws0),
    findall(at(S, E), src_(F, N, _, S, E), Ats),
    (   Ws0 == [predicate(F/N)], Ats = [W0] -> Ws = [W0] ; Ws = Ws0 ).

%!  place_problems(+Name, +Problems0, -Problems) is det.
%
%   Problems found while writing the element Name (OpenFisca's and Catala's
%   own refusals), placed where nothing more precise was known; at most one
%   for each clause (one_per_clause/2).
place_problems(Name, Ps0, Ps) :-
    maplist(place_problem(Name), Ps0, Pss), append(Pss, Ps1),
    one_per_clause(Ps1, Ps).

place_problem(Name, problem(none, M), Ps) :- rs_wheres(Name, Ws), !,
    findall(problem(W, M), member(W, Ws), Ps).
place_problem(_, P, [P]).

%!  provenance_text(+Name, -Text) is semidet.
%
%   "Logical English line 74", "Logical English lines 74, 78" or "lines
%   12-30": the lines of the program the element Name of the output comes
%   from (its template's rules and facts, and the dated rows a table reads).
%   Fails when they are not known (no text(Doc) in the exporter's Options).
provenance_text(Name, Text) :-
    once(( name_(F, Name), t_(F, N, _, _) )),
    findall(L, ( src_(F, N, L, _, _) ; also_(F, DF), src_(DF, _, L, _, _) ), Ls0),
    sort(Ls0, Ls), Ls \== [],
    ranges(Ls, Rs),
    atomic_list_concat(Rs, ', ', RT),
    ( Ls = [_] -> W = line ; W = lines ),
    format(string(Text), "Logical English ~w ~w", [W, RT]).

%   Consecutive lines as one range (a table of facts: 12-30).
ranges([], []).
ranges([L|Ls], [R|Rs]) :-
    run(L, Ls, Last, Rest),
    ( Last =:= L -> R = L ; Last =:= L + 1 -> format(atom(R), '~w, ~w', [L, Last]) ; format(atom(R), '~w-~w', [L, Last]) ),
    ranges(Rest, Rs).
run(L, [M|Ms], Last, Rest) :- M =:= L + 1, !, run(M, Ms, Last, Rest).
run(L, Ms, L, Ms).


		 /*******************************
		 *            RULES             *
		 *******************************/

%   rs_rule(Name, Kind, Dict): the rules of the module.
rules_out(Rs, Fs, Rules) :-
    findall(F/N, t_(F, N, _, _), FNs),
    findall(R, ( member(F/N, FNs), t_(F, N, Shape, Info), rule_out(F, N, Shape, Info, Rs, Fs, R) ), Rules).

rule_out(_, 4, dated_rows, _, _, _, _) :- !, fail.          % read through the table that selects them
rule_out(F, 2, table(K), Info, Rs, Fs, R) :-
    selects_dated_rows(F, Rs, DF), !,
    findall(From-To-I-V, ( member(fact(H, _), Fs), H =.. [DF, I, From0, To0, V],
                           iso_of(From0, From), iso_of(To0, To) ), Rows),
    findall(From-To, member(From-To-_-_, Rows), Ks0), sort(Ks0, Ks),
    findall(version(From, To1, table(Cells)),
            ( member(From-To, Ks), ( To == '9999-12-31' -> To1 = none ; To1 = To ),
              findall(I-V, member(From-To-I-V, Rows), Cells) ), Versions),
    name_(F, Name), Info = info(_, VN, _), name_words(K, IB),
    ( member(fact(H1, O), Fs), functor(H1, DF, 4), opt_prov(O, P) -> true ; P = none ),
    ( also_(F, DF) -> true ; assertz(also_(F, DF)) ),
    R = rs(Name, parameter, [dtype-dtype(VN), indexed_by-IB, source-P], Versions).
rule_out(F, N, Shape, Info, Rs, _, R) :-
    memberchk(Shape, [parameter, table(_)]),
    findall(H-B-O, ( member(rule(H, B, O), Rs), functor(H, F, N) ), HBs), HBs \== [], !,
    rule_out(F, N, derived(scalar, none), Info, Rs, [], R).
rule_out(F, N, parameter, Info, _, Fs, R) :-
    findall(V-P, ( member(fact(H, O), Fs), functor(H, F, N), arg(1, H, V), opt_prov(O, P) ), [V-P|More]),
    ( More \== [] -> problem(predicate(F/N), "~w is stated more than once; RuleSpec gives a parameter one value at a time", [F]) ; true ),
    name_(F, Name), Info = info(_, VN, _),
    R = rs(Name, parameter, [dtype-dtype(VN), source-P], [version('1900-01-01', none, literal(V))]).
rule_out(F, N, table(K), Info, _, Fs, R) :-
    findall(I-V, ( member(fact(H, _), Fs), functor(H, F, N), arg(1, H, I), arg(2, H, V) ), Rows),
    ( member(fact(H, O), Fs), functor(H, F, N), opt_prov(O, P) -> true ; P = none ),
    name_(F, Name), Info = info(_, VN, _), name_words(K, IB),
    R = rs(Name, parameter, [dtype-dtype(VN), indexed_by-IB, source-P], [version('1900-01-01', none, table(Rows))]).
rule_out(F, N, derived(_, _), Info, Rs, _, R) :-
    findall(H-B-O, ( member(rule(H, B, O), Rs), functor(H, F, N) ), HBs),
    dated_parameter(HBs, Versions), !,
    name_(F, Name), Info = info(Text, VN, _),
    template_parts(Text, _, Places),
    (   N =:= 2 -> Places = [K|_], name_words(K, IB), Attrs = [dtype-dtype(VN), indexed_by-IB] ; Attrs = [dtype-dtype(VN)] ),
    R = rs(Name, parameter, Attrs, Versions).
rule_out(F, N, derived(Kind, E), Info, Rs, _, R) :-
    findall(H-B-O, ( member(rule(H, B, O), Rs), functor(H, F, N) ), HBs0),
    maplist(strip_given, HBs0, HBs),
    name_(F, Name), Info = info(_, VN, _),
    ( HBs = [_-_-O1|_], opt_prov(O1, P) -> true ; P = none ),
    catch(versions(Kind, E, HBs, Vs), export_problem(W, M0), ( versions_problems(Kind, E, F/N, Name, HBs, W, M0), Vs = [] )),
    ( Kind == judgment -> DT = 'Judgment' ; DT = dtype(VN) ),
    ( E == none -> EA = [] ; EA = [entity-E] ),
    append(EA, [dtype-DT, source-P], Attrs),
    R = rs(Name, derived, Attrs, Vs).
rule_out(F, N, relation(A, B), _, _, _, rs(Name, data_relation, [arguments-[EA, EB]], [])) :-
    name_(F, Name), noun_entity(A, EA), noun_entity(B, EB), _ = N.
rule_out(F, _, unsupported(N), info(Text, _, _), Rs, Fs, _) :-
    template_wheres(F, N, Rs, Fs, Ws),
    forall(member(W, Ws), problem(W, "the template \"~w\" has ~w places; RuleSpec's values and relations have at most two", [Text, N])),
    fail.

why(format(F, A), M) :- !, format(string(M), F, A).
why(M, M).

%   A value whose rules cannot be written: each rule that cannot be written
%   on its own is placed on its own text; when each can, and only their
%   combination cannot (several rules for one value at once), the problem is
%   the template's.
versions_problems(Kind, E, F/N, Name, HBs, W0, M0) :-
    (   W0 \== none
    ->  why(M0, M), problem(W0, "~w: ~w", [Name, M])
    ;   findall(W-M1, ( member(HB, HBs),
                         catch(( versions(Kind, E, [HB], _), fail ), export_problem(_, M1), true),
                         rule_where(HB, W) ), Alone),
        (   Alone \== []
        ->  forall(member(W-M1, Alone), ( why(M1, M), problem(W, "~w: ~w", [Name, M]) ))
        ;   why(M0, M), problem(predicate(F/N), "~w: ~w", [Name, M])
        )
    ).

%   Rules that only state a value (or a table's rows) under the dates of a
%   version: a parameter with dated versions.
dated_parameter(HBs, Versions) :-
    HBs \== [],
    maplist(dated(any), HBs, Dated),
    forall(member(d(_, _, H, B), Dated), ( B == true, ground(H) )),
    findall(From-To, member(d(From, To, _, _), Dated), Ks0), sort(Ks0, Ks),
    findall(version(From, To, Val),
            ( member(From-To, Ks),
              findall(H, member(d(From, To, H, _), Dated), Hs),
              (   Hs = [H1], functor(H1, _, 1) -> arg(1, H1, V), Val = literal(V)
              ;   findall(I-V, ( member(H, Hs), H =.. [_, I, V] ), Rows), Val = table(Rows)
              ) ),
            Versions).

name_words(K, IB) :- split_string(K, " ", "", Ws), atomic_list_concat(Ws, '_', IB).

dtype(amount, 'Money') :- !.
dtype("amount", 'Money') :- !.
dtype(R, 'Rate') :- memberchk(R, [rate, "rate"]), !.
dtype(D, 'Date') :- memberchk(D, [date, "date"]), !.
dtype(_, 'Decimal').

opt_prov(O, P) :-
    (   memberchk(provenance(Ps), O), memberchk(as_stated_in(D), Ps)
    ->  ( memberchk(confer(Q), Ps) -> format(string(P), "~w, \"~w\"", [D, Q]) ; format(string(P), "~w", [D]) )
    ;   P = none
    ).

%   The versions of a derived rule: its rules grouped by the dates that
%   guard them (one group, from 2000-01-01, when none is guarded).
versions(Kind, E, HBs, Vs) :-
    maplist(dated(Kind), HBs, Dated),
    findall(From-To, member(d(From, To, _, _), Dated), Ks0), sort(Ks0, Ks),
    findall(version(From, To, Formula),
            ( member(From-To, Ks),
              findall(H-B, member(d(From, To, H, B), Dated), Group),
              group_formula(Kind, E, Group, Formula) ),
            Vs).

dated(_, H-B0-_, d(From, To, H, B)) :-
    conjuncts(B0, Cs0),
    (   select(Date, Cs0, Cs1), functor(Date, Fd, 1), date_template(Fd),
        arg(1, Date, D), var(D)
    ->  guard_dates(Cs1, D, From, To, Cs2a),
        %  a date used as a value too (an age on the date): the period's start
        (   member(C, Cs2a), term_variables(C, Vs), member(V, Vs), V == D
        ->  Cs2 = [rs_calc(D)|Cs2a]
        ;   Cs2 = Cs2a
        ),
        list_conj(Cs2, B)
    ;   From = '1900-01-01', To = none, B = B0
    ).

date_template(F) :- ( name_(F, calculation_date) -> true ; sub_atom(F, _, _, _, calculation_date) ).

guard_dates(Cs0, D, From, To, Cs) :-
    (   select(G, Cs0, Cs1), G = le_le(date(Y, M, Dd), D1), D1 == D, ground(Y-M-Dd) -> iso(Y, M, Dd, From) ; From = '1900-01-01', Cs1 = Cs0 ),
    (   select(G2, Cs1, Cs), ( G2 = le_lt(D2, date(Y2, M2, D3)), D2 == D, ground(Y2-M2-D3) -> prev_day(Y2, M2, D3, To)
                             ; G2 = le_le(D2, date(Y2, M2, D3)), D2 == D, ground(Y2-M2-D3) -> iso(Y2, M2, D3, To) )
    ->  true
    ;   To = none, Cs = Cs1
    ).

iso(Y, M, D, A) :- format(atom(A), '~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+', [Y, M, D]).
prev_day(Y, M, D, A) :- date_time_stamp(date(Y, M, D, 0, 0, 0, 0, -, -), S0), S is S0 - 86400,
    stamp_date_time(S, date(Y1, M1, D1, _, _, _, _, _, _), 'UTC'), iso(Y1, M1, D1, A).

%   One version's formula from the rules of that version.
group_formula(judgment, E, Group, Formula) :- !,
    judgment_formulas(Group, E, Fs),
    ( Fs = [F1] -> Formula = F1 ; or_list(Fs, Formula) ).
group_formula(scalar, E, [H-B], Formula) :- !,
    arg_value(H, V), scalar_formula(E, H, V, B, Formula0), no_value_cascade(Formula0, Formula).
group_formula(scalar, _, _, _) :-
    throw(export_problem(none, "several rules conclude its value at once (not an otherwise cascade): RuleSpec gives a value one formula")).

judgment_formulas([], _, []).
judgment_formulas([H-B|HBs], E, [F|Fs]) :- judgment_formula(E, H, B, F), judgment_formulas(HBs, E, Fs).

or_list([F], F) :- !.
or_list([F|Fs], or(F, R)) :- or_list(Fs, R).

arg_value(H, V) :- functor(H, _, N), arg(N, H, V).

judgment_formula(E, H, B, F) :-
    subject(E, H, X),
    conjuncts(B, Cs),
    env_conds(Cs, X, ['$subject'-X], Env, Conds),
    ( Conds == [] -> F = bool(true) ; and_list(Conds, Env, F) ).

and_list([C], Env, F) :- !, cond_expr(C, Env, F).
and_list([C|Cs], Env, and(F, R)) :- cond_expr(C, Env, F), and_list(Cs, Env, R).

subject(none, _, none) :- !.
subject(_, H, X) :- arg(1, H, X).

%   A scalar rule: an otherwise cascade is if/else; the conditions of a
%   plain rule are bindings only (a rule with a condition and no `otherwise`
%   would leave the value undefined, which RuleSpec cannot say).
scalar_formula(E, H, V, B, F) :-
    (   B = or(A, and(not(_), Rest))
    ->  subject(E, H, X), conjuncts(A, Cs), env_conds(Cs, X, ['$subject'-X], Env, Conds),
        value_expr(V, Env, VA),
        ( Conds == [] -> throw(export_problem(none, "an otherwise cascade whose first branch has no condition")) ; true ),
        and_list(Conds, Env, C),
        scalar_formula(E, H, V, Rest, Else),
        F = if(C, VA, Else)
    ;   subject(E, H, X), conjuncts(B, Cs), env_conds(Cs, X, ['$subject'-X], Env, Conds),
        (   Conds == [] -> value_expr(V, Env, F)
        ;   and_list(Conds, Env, C), value_expr(V, Env, VE), F = if(C, VE, nomatch)
        )
    ).

%   A cascade whose last branch has conditions has no value when none
%   holds: RuleSpec says so with a `match` without a `_` arm, when every
%   branch compares one subject with a constant. Otherwise it is refused.
no_value_cascade(F0, F) :-
    (   sub_term(nomatch, F0)
    ->  (   nb_current(rs_export_no_value, keep) -> F = F0     % (a target that has no value: Catala's impossible)
        ;   match_arms(F0, S, Arms) -> F = match(S, Arms)
        ;   throw(export_problem(none, "its value is concluded only under conditions, with no otherwise: RuleSpec has no value for the other cases"))
        )
    ;   F = F0
    ).

match_arms(nomatch, _, []).
match_arms(if(cmp(==, S0, P), V, E), S, [P-V|Arms]) :- P = num(_), ( var(S) -> S = S0 ; S == S0 ), match_arms(E, S, Arms).

conjuncts(and(A, B), Cs) :- !, conjuncts(A, CA), conjuncts(B, CB), append(CA, CB, Cs).
conjuncts(true, []) :- !.
conjuncts(C, [C]).

list_conj([], true).
list_conj([C], C) :- !.
list_conj([C|Cs], and(C, R)) :- list_conj(Cs, R).

%   env_conds(+Conditions, +Subject, +Env0, -Env, -Conds): the bindings a
%   rule's conditions make (Var-Expr), and the conditions that test.
env_conds([], _, Env, Env, []).
env_conds([C|Cs], X, Env0, Env, Conds) :-
    (   C = le_assign(V0, _), var(V0), member(V1-_, Env0), V1 == V0
    ->  Conds = [C|Conds1], env_conds(Cs, X, Env0, Env, Conds1)       % a test: its variable has a value
    ;   C = or(A, and(not(_), B)), otherwise_binding(A, B, X, Env0, V, Expr)
    ->  env_conds(Cs, X, [V-Expr|Env0], Env, Conds)
    ;   binding(C, X, Env0, V, Expr)
    ->  env_conds(Cs, X, [V-Expr|Env0], Env, Conds)
    ;   C = is_a(_, _)
    ->  env_conds(Cs, X, Env0, Env, Conds)                       % the twin's grounding of its subject
    ;   C = rs_subject(_)
    ->  env_conds(Cs, X, Env0, Env, Conds)
    ;   member_of_group(C, X, G)
    ->  env_conds(Cs, X, [G-group|Env0], Env, Conds)        % the group the subject is a member of
    ;   test(C, X)
    ->  Conds = [C|Conds1], env_conds(Cs, X, Env0, Env, Conds1)
    ;   term_string(C, S), throw(export_problem(none, format("a condition RuleSpec has no form for: ~w", [S])))
    ).

binding(le_assign(V, E), _, _, V, arith(E)) :- var(V), !.
%   `the text is equal to "SUA"`, on a variable no condition has given a
%   value yet: the value (a rule concluding a text from a list of cases)
binding(le_equal_to(V, E), _, Env, V, arith(E)) :-
    var(V), \+ ( member(V1-_, Env), V1 == V ), ( string(E) ; number(E) ; atom(E) ), !.
binding(rs_calc(D), _, _, D, done(ref(calculation_date))) :- !.
%   the whole months from a date to another (an age in years is them // 12)
binding(le_is_months_after(L, M, B), _, Env, M, done(call(months_between, [EB, EL]))) :- var(M), \+ bound_in(M, Env), !,
    value_expr(B, Env, EB), value_expr(L, Env, EL).
%   the date some months after a date
binding(le_is_months_after(L, M, B), _, Env, L, done(call(add_months, [EB, EM]))) :- var(L), \+ bound_in(L, Env), !,
    value_expr(B, Env, EB), value_expr(M, Env, EM).
binding(le_maximum(A, B, M), _, _, M, max(A, B)) :- var(M), !.
binding(le_minimum(A, B, M), _, _, M, min(A, B)) :- var(M), !.
binding(count(Each, Goal, [var(_, N)]), X, Env, N, Agg) :- rank_in_group(Each, Goal, X, Env, Agg), !.
binding(count(Each, Goal, [var(_, N)]), X, _, N, Agg) :- !, aggregate(count, Each, Goal, X, Agg).
binding(sum(Each, Goal, [var(_, N)]), X, _, N, Agg) :- !, aggregate(sum, Each, Goal, X, Agg).
binding(max(Each, Goal, [var(_, N)]), X, _, N, Agg) :- !, aggregate(max, Each, Goal, X, Agg).
binding(min(Each, Goal, [var(_, N)]), X, _, N, Agg) :- !, aggregate(min, Each, Goal, X, Agg).
binding(L, X, Env, V, Ref) :-
    compound(L), functor(L, F, N), t_(F, N, Shape, _),
    value_read(Shape, L, X, Env, V, Ref).

%   `the person is a member of a household`, the subject first: the group
%   whose values the rule then reads.
member_of_group(C, X, G) :-
    compound(C), functor(C, F, 2), t_(F, 2, relation(_, _), _),
    arg(1, C, S), S == X, arg(2, C, G), var(G).

%   An entity's key, as the relation from its members names it: TaxUnit,
%   tax_unit.
entity_key(E, K) :-
    atom_codes(E, Cs), entity_snake(Cs, Ds), atom_codes(K0, Ds),
    ( atom_concat('_', K, K0) -> true ; K = K0 ).
entity_snake([], []).
entity_snake([C|Cs], Out) :-
    ( code_type(C, upper(L)) -> Out = [0'_, L|R] ; Out = [C|R] ),
    entity_snake(Cs, R).

%   A value of the group the subject is a member of.
group_arg(L, Env) :- arg(1, L, G), var(G), member(G1-group, Env), G1 == G, !.

value_read(Shape, L, _, Env, V, field(E, Name)) :-
    memberchk(Shape, [derived(scalar, _), input(scalar, _)]), Shape =.. [_, _, E], E \== none,
    functor(L, F, N), arg(N, L, V), var(V), group_arg(L, Env), !,
    name_(F, Name).
value_read(Shape, L, X, _, V, ref(Name)) :-
    memberchk(Shape, [derived(scalar, _), input(scalar, _)]), Shape =.. [_, _, E],
    functor(L, F, N), arg(N, L, V), var(V),
    (   E == none -> true
    ;   arg(1, L, S), ( S == X -> true ; name_(F0, N0), functor(L, F0, _), throw(export_problem(none, format("it reads ~w of something other than its subject (~q, ~q), outside an aggregate over a relation", [N0, S, X]))) )
    ),
    name_(F, Name).
value_read(parameter, L, _, _, V, ref(Name)) :- functor(L, F, _), arg(1, L, V), var(V), name_(F, Name).
value_read(table(_), L, _, _, V, index(Name, K)) :- functor(L, F, _), arg(1, L, K), arg(2, L, V), var(V), name_(F, Name).

%   A member's place among the members of its group (OpenFisca's
%   get_rank): the count of each Y such that Y is a member of the group the
%   subject is a member of [and Y is P] and the K of Y is a number below
%   the subject's own K.
rank_in_group(Each, Goal, _X, Env, rank(Rel, Key, P)) :-
    ( Each = [each, var(_, Y)] -> true ; Each = [each, Y] ),
    conjuncts(Goal, Gs),
    select(RL, Gs, Gs1), compound(RL), functor(RL, RF, 2), t_(RF, 2, relation(_, _), _),
    RL =.. [_, Y1, G], Y1 == Y, member(G1-group, Env), G1 == G, !,
    name_(RF, Rel),
    select(Cmp, Gs1, Gs2), compound(Cmp), Cmp =.. [Op, KY, KX], memberchk(Op, [<, le_lt]), var(KY), var(KX),
    select(KL, Gs2, Gs3), compound(KL), functor(KL, KF, 2), arg(1, KL, Y2), Y2 == Y, arg(2, KL, KY1), KY1 == KY,
    name_(KF, Key),
    member(KX1-ref(Key), Env), KX1 == KX,
    (   Gs3 == [] -> P = none
    ;   Gs3 = [PL], compound(PL), functor(PL, PF, 1), arg(1, PL, Y3), Y3 == Y -> name_(PF, P)
    ).

%   count/sum of each Y such that Y is related to the subject [and Y is P]
%   [and the F of Y is V].
aggregate(Op, Each, Goal, X, Agg) :-
    ( Each = [each, var(_, Elem)] -> true ; Each = [each, Elem] ),
    conjuncts(Goal, Gs),
    (   select(RL, Gs, Gs1), compound(RL), functor(RL, RF, 2), t_(RF, 2, relation(_, _), _),
        RL =.. [_, A1, A2], ( A2 == X -> Y = A1 ; A1 == X -> Y = A2 )
    ->  name_(RF, Rel)
    ;   throw(export_problem(none, "an aggregate that does not range over a relation of its subject"))
    ),
    (   Op \== count
    ->  (   select(FL, Gs1, Gs2), compound(FL), functor(FL, FF, 2), arg(1, FL, Y1), Y1 == Y, arg(2, FL, V1), V1 == Elem
        ->  name_(FF, Field) ; throw(export_problem(none, "a sum whose value is not a value of the related thing")) )
    ;   Elem == Y -> Gs2 = Gs1
    ;   throw(export_problem(none, "a count of something other than the related things"))
    ),
    (   Gs2 == [] -> P = none
    ;   Gs2 = [PL], compound(PL), functor(PL, PF, 1), arg(1, PL, Y2), Y2 == Y -> name_(PF, P)
    ;   Gs2 = [not(PL)], compound(PL), functor(PL, PF, 1), arg(1, PL, Y2), Y2 == Y -> name_(PF, NP)
    ;   throw(export_problem(none, "an aggregate whose condition is more than one sentence about the related thing"))
    ),
    (   memberchk(Op, [max, min])
    ->  ( P == none, var(NP) -> Agg = extreme(Op, Rel, Field) ; throw(export_problem(none, "a largest or smallest value over some of the related things")) )
    ;   nonvar(NP) -> ( Op == count -> Field = none ; true ), Agg = without(Op, Rel, Field, NP)
    ;   Op == count -> ( P == none -> Agg = len(Rel) ; Agg = count_where(Rel, P) )
    ;   ( P == none -> Agg = sum(Rel, Field) ; Agg = sum_where(Rel, Field, P) )
    ).

%   All the related things, less those a test fails: the things it holds of.
%   (The twins count this way, so that a test proved by two rules counts a
%   thing once.)
all_less_without(len(R), without(count, R, none, P), count_where(R, P)).
all_less_without(sum(R, F), without(sum, R, F, P), sum_where(R, F, P)).

test(C, _) :- C = not(_), !.
test(C, _) :- C = le_is_in(_, L), is_list(L), !.
test(C, _) :- C = or(_, _), !.
test(C, _) :- C = le_assign(_, _), !.
test(C, _) :- compound(C), functor(C, F, N), t_(F, N, Shape, _), value_shape(Shape), arg(N, C, V), nonvar(V), !.
test(C, _) :- functor(C, F, _), memberchk(F, [le_equal_to, le_not_equal_to, le_lt, le_le, le_gt, le_ge, le_eq, le_ne, <, >, =<, >=, =, \=, =:=, =\=, le_neq]), !.
test(C, _) :- compound(C), functor(C, F, N), t_(F, N, Shape, _), memberchk(Shape, [derived(judgment, _), input(judgment, _)]), !.
test(C, _) :- atom(C), t_(C, 0, _, _).

%   An otherwise cascade inside a rule's conditions (a value computed by
%   `if … else` in the middle of a formula): both branches give the same
%   variable a value.
otherwise_binding(A, B, X, Env0, V, done(if(CondA, EA, EB))) :-
    conjuncts(A, As), env_conds(As, X, Env0, EnvA, CsA), CsA \== [],
    conjuncts(B, Bs), env_conds(Bs, X, Env0, EnvB, CsB),
    member(V-_, EnvA), var(V), \+ ( member(V0-_, Env0), V0 == V ),
    member(V1-_, EnvB), V1 == V, !,
    and_list(CsA, EnvA, CondA),
    value_expr(V, EnvA, EA0),
    value_expr(V, EnvB, EB0),
    (   CsB == [] -> EB = EB0
    ;   throw(export_problem(none, "an inner otherwise whose last branch has conditions: RuleSpec's `else` has none"))
    ),
    EA = EA0.

%   A condition as a RuleSpec judgment expression.
cond_expr(not(G), Env, not(E)) :- !, branch_expr(G, Env, E).
cond_expr(le_is_in(X, [V|Vs]), Env, F) :- !,                 % x is in [a, b]: x == a or x == b
    value_expr(X, Env, A), eq_each([V|Vs], A, Env, [C|Cs]),
    foldl([C1, F0, or(F0, C1)]>>true, Cs, C, F).

cond_expr(or(A, B), Env, or(EA, EB)) :- !, branch_expr(A, Env, EA), branch_expr(B, Env, EB).
cond_expr(le_assign(V, X), Env, cmp(==, A, B)) :- !, value_expr(V, Env, A), value_expr(X, Env, B).
cond_expr(C, Env, cmp(==, R, B)) :-
    compound(C), functor(C, F, N), t_(F, N, Shape, _), value_shape(Shape), arg(N, C, V), nonvar(V), !,
    name_(F, Name), value_expr(V, Env, B),
    (   N > 1, group_arg(C, Env), Shape =.. [_, _, E] -> R = field(E, Name) ; R = ref(Name) ).
cond_expr(C, Env, field(E, Name)) :-                % a yes-or-no value of the subject's group
    compound(C), functor(C, F, N), t_(F, N, Shape, _), memberchk(Shape, [derived(judgment, E), input(judgment, E)]),
    group_arg(C, Env), !, name_(F, Name).
cond_expr(C, Env, cmp(Op, A, B)) :- C =.. [F, X, Y], cmp_op(F, Op), !, value_expr(X, Env, A), value_expr(Y, Env, B).
cond_expr(C, _, ref(Name)) :- functor(C, F, _), name_(F, Name).

eq_each([], _, _, []).
eq_each([V|Vs], A, Env, [cmp(==, A, B)|Cs]) :- value_expr(V, Env, B), eq_each(Vs, A, Env, Cs).

%   A nested group of conditions (under a negation, in one branch of an
%   `or`): its own bindings, its tests joined by `and`.
branch_expr(G, Env, E) :-
    ( member(K-X0, Env), K == '$subject' -> X = X0 ; X = none ),
    conjuncts(G, Gs), env_conds(Gs, X, Env, Env1, Cs),
    ( Cs == [] -> E = bool(true) ; and_list(Cs, Env1, E) ).

cmp_op(le_lt, <). cmp_op(<, <).
cmp_op(le_le, =<). cmp_op(=<, =<).
cmp_op(le_gt, >). cmp_op(>, >).
cmp_op(le_ge, >=). cmp_op(>=, >=).
cmp_op(le_eq, ==). cmp_op(=, ==). cmp_op(=:=, ==). cmp_op(le_equal_to, ==). cmp_op(le_not_equal_to, \=).
cmp_op(le_ne, \=). cmp_op(le_neq, \=). cmp_op(\=, \=). cmp_op(=\=, \=).

bound_in(V, Env) :- member(V1-_, Env), V1 == V, !.

%   A value: a variable bound by the conditions, a number, arithmetic.
value_expr(V, Env, E) :- var(V), !,
    (   member(V1-B, Env), V1 == V -> bound_expr(B, Env, E)
    ;   throw(export_problem(none, "a value no condition gives"))
    ).
value_expr(N, _, num(N)) :- number(N), !.
value_expr(S, _, str(S)) :- string(S), !.
value_expr(date(Y, M, D), _, date(A)) :- !, iso(Y, M, D, A).
value_expr(A, _, str(S)) :- atom(A), !, atom_string(A, S).
value_expr(A - B, Env, E) :- var(A), var(B),
    member(VA-All, Env), VA == A, member(VB-Without, Env), VB == B,
    all_less_without(All, Without, E), !.
value_expr(T, Env, E) :- T =.. [Op, A, B], memberchk(Op, [+, -, *, /, //]), !,
    value_expr(A, Env, EA), value_expr(B, Env, EB), E = bin(Op, EA, EB).
value_expr(-(A), Env, neg(EA)) :- !, value_expr(A, Env, EA).
value_expr(T, Env, call(G, [EA])) :- T =.. [F, A], fn(F, G), !, value_expr(A, Env, EA).
value_expr(T, _, _) :- term_string(T, S), throw(export_problem(none, format("arithmetic RuleSpec has no form for: ~w", [S]))).

fn(floor, floor).
fn(ceiling, ceil).
fn(round, round).
fn(abs, abs).

bound_expr(done(E), _, E) :- !.
bound_expr(arith(E0), Env, E) :- !, value_expr(E0, Env, E).
bound_expr(max(A, B), Env, call(max, [EA, EB])) :- !, value_expr(A, Env, EA), value_expr(B, Env, EB).
bound_expr(min(A, B), Env, call(min, [EA, EB])) :- !, value_expr(A, Env, EA), value_expr(B, Env, EB).
bound_expr(index(T, K), Env, index(T, EK)) :- !, value_expr(K, Env, EK).
bound_expr(without(count, R, none, P), _, bin(-, len(R), count_where(R, P))) :- !.
bound_expr(without(sum, R, F, P), _, bin(-, sum(R, F), sum_where(R, F, P))) :- !.
bound_expr(E, _, E).


		 /*******************************
		 *         THE YAML TEXT        *
		 *******************************/

%   Problems: what only writing a formula finds (a member's place among its
%   group's members), placed on the rule it is about.
module_yaml(MId, _KB, Rules, Text, Problems) :-
    findall(T-Ps, ( member(R, Rules), rule_yaml(R, T, Ps) ), TPs),
    findall(P, ( member(_-Ps, TPs), member(P, Ps) ), Problems),
    findall(T, member(T-_, TPs), Ts),
    with_output_to(string(Text),
      ( format("format: rulespec/v1~nmodule:~n  summary: |-~n    Written from a Logical English program by Logical English's~n    translator (LE2 migration/rulespec, ~w).~nrules:~n", [MId]),
        forall(member(T, Ts), write(T)) )).

rule_yaml(R, T, Ps) :-
    R = rs(Name, _, _, _),
    catch(( with_output_to(string(T), write_rule(R)), Ps = [] ),
          export_problem(_, M0),
          ( why(M0, M1), format(string(M), "~w: ~w", [Name, M1]), place_problems(Name, [problem(none, M)], Ps), T = "" )).

%   A comment above each rule names the lines of the program it was written
%   from: RuleSpec's own `source` is the legal text a rule cites (a
%   provenance trailer), not the program, so the two are kept apart.
write_rule(rs(Name, Kind, Attrs, Vs)) :-
    ( provenance_text(Name, PT) -> format("  # ~s~n", [PT]) ; true ),
    format("  - name: ~w~n    kind: ~w~n", [Name, Kind]),
    forall(member(K-V, Attrs), write_attr(K, V)),
    (   Kind == data_relation
    ->  memberchk(arguments-[A, B], Attrs),
        format("    data_relation:~n      arity: 2~n      arguments: [~w, ~w]~n", [A, B])
    ;   Kind == derived, \+ memberchk(entity-_, Attrs) -> true
    ;   true
    ),
    (   Vs == [] -> true
    ;   format("    versions:~n"), forall(member(V, Vs), write_version(V))
    ).

write_attr(arguments, _) :- !.
write_attr(source, none) :- !.
write_attr(_, none) :- !.
write_attr(dtype, dtype(VN)) :- !, ( VN == none -> T = 'Decimal' ; dtype(VN, T) ), format("    dtype: ~w~n", [T]).
write_attr(source, P) :- !, yaml_scalar(P, S), format("    source: ~w~n", [S]).
write_attr(K, V) :- format("    ~w: ~w~n", [K, V]).

write_version(version(From, To, F)) :-
    format("      - effective_from: '~w'~n", [From]),
    ( To == none -> true ; format("        effective_to: '~w'~n", [To]) ),
    (   F = table(Rows)
    ->  format("        values:~n"), forall(member(I-V, Rows), format("          ~w: ~w~n", [I, V]))
    ;   F = literal(V)
    ->  format("        formula: |-~n          ~w~n", [V])
    ;   formula_text(F, T),
        format("        formula: |-~n"),
        split_string(T, "\n", "", Ls), forall(member(L, Ls), format("          ~s~n", [L]))
    ).

yaml_scalar(V, S) :-
    format(string(S0), "~w", [V]),
    (   needs_quotes(S0)
    ->  atomic_list_concat(Parts, '\'', S0), atomic_list_concat(Parts, '\'\'', Esc),
        format(string(S), "'~w'", [Esc])
    ;   S = S0
    ).

needs_quotes(S) :- ( sub_string(S, _, _, _, ":") ; sub_string(S, _, _, _, "\"") ; sub_string(S, _, _, _, "#") ; sub_string(S, 0, 1, _, "'") ), !.

%   A formula as text: `if` on lines of its own, everything else inline.
formula_text(if(C, T, E), Text) :- !,
    expr_text(C, CT), formula_text(T, TT), formula_text(E, ET),
    indent(TT, TTi), indent(ET, ETi),
    format(string(Text), "if ~s:~n~s~nelse:~n~s", [CT, TTi, ETi]).
formula_text(match(S, Arms), Text) :- !,
    expr_text(S, ST),
    findall(L, ( member(P-V, Arms), expr_text(P, PT), expr_text(V, VT), format(string(L), "    ~s => ~s", [PT, VT]) ), Ls),
    atomic_list_concat(Ls, '\n', AT),
    format(string(Text), "match ~s:~n~s", [ST, AT]).
formula_text(E, T) :- expr_text(E, T).

indent(T, I) :- split_string(T, "\n", "", Ls), maplist([L, L1]>>string_concat("    ", L, L1), Ls, Ls1), atomic_list_concat(Ls1, '\n', I).

expr_text(num(N), T) :- !, format(string(T), "~w", [N]).
expr_text(str(S), T) :- !, format(string(T), "\"~w\"", [S]).
expr_text(date(A), T) :- !, format(string(T), "\"~w\"", [A]).
expr_text(bool(true), "true") :- !.
expr_text(bool(false), "false") :- !.
expr_text(ref(N), T) :- !, format(string(T), "~w", [N]).
expr_text(field(E, N), T) :- !, entity_key(E, K), format(string(T), "member_of_~w.~w", [K, N]).
expr_text(index(N, K), T) :- !, expr_text(K, KT), format(string(T), "~w[~s]", [N, KT]).
expr_text(len(R), T) :- !, format(string(T), "len(~w)", [R]).
expr_text(rank(_, _, _), _) :- !,
    throw(export_problem(none, "a member's place among the members of its group: RuleSpec has no form for it")).
expr_text(count_where(R, P), T) :- !, format(string(T), "count_where(~w, ~w)", [R, P]).
expr_text(sum(R, F), T) :- !, format(string(T), "sum(~w.~w)", [R, F]).
expr_text(extreme(Op, R, F), T) :- !, format(string(T), "~w(~w.~w)", [Op, R, F]).
expr_text(sum_where(R, F, P), T) :- !, format(string(T), "sum_where(~w, ~w, ~w)", [R, F, P]).
expr_text(call(F, As), T) :- !, maplist(expr_text, As, Ts), atomic_list_concat(Ts, ', ', A), format(string(T), "~w(~w)", [F, A]).
expr_text(bin(Op, A, B), T) :- !, sub_text(A, AT), sub_text(B, BT), format(string(T), "~s ~w ~s", [AT, Op, BT]).
expr_text(neg(A), T) :- !, sub_text(A, AT), format(string(T), "-~s", [AT]).
expr_text(not(A), T) :- !, sub_text(A, AT), format(string(T), "not ~s", [AT]).
expr_text(and(A, B), T) :- !, sub_text(A, AT), sub_text(B, BT), format(string(T), "~s and ~s", [AT, BT]).
expr_text(or(A, B), T) :- !, sub_text(A, AT), sub_text(B, BT), format(string(T), "~s or ~s", [AT, BT]).
expr_text(cmp(Op, A, B), T) :- !, sub_text(A, AT), sub_text(B, BT), op_text(Op, OT), format(string(T), "~s ~w ~s", [AT, OT, BT]).
expr_text(if(C, A, B), T) :- !, formula_text(if(C, A, B), T0), format(string(T), "(~s)", [T0]).

sub_text(E, T) :-
    expr_text(E, T0),
    (   compound(E), functor(E, F, _), memberchk(F, [bin, and, or, cmp, not, neg]) -> format(string(T), "(~s)", [T0]) ; T = T0 ).

op_text(==, '==').
op_text(\=, '!=').
op_text(=<, '<=').
op_text(Op, Op).


		 /*******************************
		 *          TEST CASES          *
		 *******************************/

%   case(Name, Period, Inputs, Outputs)
case_out(MId, Ts, Qs, case(N, Lines), case(N, Period, Inputs, Outputs)) :-
    findall(F, ( member(L, Lines), ( L = fact(F, _) ; L = fact(F) ) ), Fs),
    (   member(D, Fs), functor(D, DF, 1), name_(DF, calculation_date), arg(1, D, date(Y, M, Dd))
    ->  (   Dd =:= 1 -> format(atom(Period), '~|~`0t~d~4+-~|~`0t~d~2+', [Y, M])
        ;   iso(Y, M, Dd, Day), Period = day(Day)       % a day of its own: a custom period
        )
    ;   Period = '2026-01'
    ),
    subject_of(Fs, Subject),
    findall(K-V, ( member(F, Fs), fact_input(MId, Subject, F, K, V) ), In00),
    %  (a target with defaults, Catala: a value a rule gives that the scenario states)
    findall(K-V, ( nb_current(rs_export_no_value, keep), member(F, Fs), compound(F), functor(F, FF, Ar),
                   t_(FF, Ar, derived(scalar, _), _), arg(Ar, F, V0), nonvar(V0), yaml_value(V0, V),
                   name_(FF, Name), format(atom(K), '~w#input.~w', [MId, Name]) ), InD),
    %  (the value a case gives in place of a rule's: the rule's value it sets)
    findall(K-V, ( member(F, Fs), given_input(MId, Subject, F, K, V) ), InG),
    append([In00, InD, InG], In0),
    relation_inputs(MId, Subject, Fs, RIn),
    false_inputs(MId, In0, Fs, Subject, FIn),
    append([In0, RIn, FIn], Inputs),
    findall(K-V, ( member(L, Lines), L = expects(Q, As, _), memberchk(Q-G, Qs), expect_out(MId, G, As, K, V) ), Outputs),
    _ = Ts.

subject_of(Fs, S) :-
    (   member(is_a(S, _), Fs), \+ ( member(F, Fs), functor(F, RF, 2), t_(RF, 2, relation(_, _), _), arg(1, F, S) ) -> true
    ;   member(F, Fs), functor(F, FF, N), N >= 1, t_(FF, N, input(_, E), _), E \== none, arg(1, F, S) -> true
    ;   S = none
    ).

fact_input(MId, Subject, F, Key, V) :-
    compound(F), functor(F, FF, N), t_(FF, N, input(Kind, E), _),
    ( E == none -> true ; arg(1, F, S), S == Subject ),
    name_(FF, Name), Name \== calculation_date, format(atom(Key), '~w#input.~w', [MId, Name]),
    ( Kind == judgment -> V = true ; arg(N, F, V0), yaml_value(V0, V) ).
fact_input(MId, _, F, Key, V) :-
    compound(F), functor(F, FF, 1), t_(FF, 1, input(scalar, none), _),
    name_(FF, Name), Name \== calculation_date, format(atom(Key), '~w#input.~w', [MId, Name]), arg(1, F, V0), yaml_value(V0, V).

%   The value a case gives in place of a rule's, of the subject (or of no
%   one): a person's given value belongs to that person, among a group's
%   members (member_inputs/5), not to the case.
given_input(MId, Subject, F, Key, V) :-
    compound(F), functor(F, GF, Ar), given_t(GF, Name, E),
    ( E == none -> true ; Ar >= 2, arg(1, F, S), S == Subject ),
    arg(Ar, F, V0), yaml_value(V0, V), format(atom(Key), '~w#input.~w', [MId, Name]).

yaml_value(date(Y, M, D), A) :- !, iso(Y, M, D, A).
yaml_value(V, V).

%   A sentence the scenario does not state is false (Logical English reads
%   an unstated sentence as not holding; RuleSpec would call it missing).
false_inputs(MId, In, Fs, Subject, FIn) :-
    subject_entity(Fs, Subject, SE),
    findall(Key-false, ( t_(F, N, input(judgment, E), _), N =< 1, name_(F, Name),
                         ( E == none ; Subject \== none, ( var(SE) ; E == SE ) ),
                         format(atom(Key), '~w#input.~w', [MId, Name]), \+ memberchk(Key-_, In), _ = F ), FIn0),
    sort(FIn0, FIn).

relation_inputs(MId, Subject, Fs, RIn) :-
    findall(Key-Items,
            ( t_(RF, 2, relation(NA, NB), _), name_(RF, Rel), noun_entity(NA, EA), noun_entity(NB, EB),
              findall(Y-ME, ( member(F, Fs), functor(F, RF, 2), F =.. [_, A, B],
                              ( B == Subject -> Y = A, ME = EA ; A == Subject -> Y = B, ME = EB ) ), Ys), Ys \== [],
              format(atom(Key), '~w#relation.~w', [MId, Rel]),
              findall(Item, ( member(Y-ME, Ys), member_inputs(MId, Y, ME, Fs, Item) ), Items) ),
            RIn).

%   The entity of a case's subject: the other side of a relation it is in
%   (unbound when it is in none).
%   (Only a case with members says: in a case of one thing, RuleSpec reads
%   the values of several entities for the same identifier.)
subject_entity(Fs, S, E) :-
    (   S == none -> true
    ;   member(F, Fs), functor(F, RF, 2), t_(RF, 2, relation(NA, NB), _), F =.. [_, A, B],
        ( B == S -> noun_entity(NB, E) ; A == S -> noun_entity(NA, E) ) -> true
    ;   true
    ).

member_inputs(MId, Y, ME, Fs, Item) :-
    findall(K-V, ( member(F, Fs), ( fact_input(MId, Y, F, K, V) ; given_input(MId, Y, F, K, V) ) ), Ps0),
    findall(K-false, ( t_(F, 1, input(judgment, E), _), E \== none, ( var(ME) ; E == ME ), name_(F, Name),
                       format(atom(K), '~w#input.~w', [MId, Name]), \+ memberchk(K-_, Ps0) ), Fls),
    append(Ps0, Fls, Ps), Item = Ps.

%   An expectation: an answer of a value template gives the value; a
%   sentence is holds, or not_holds when nothing is expected.
expect_out(MId, G, As, Key, V) :-
    functor(G, F, N), t_(F, N, Shape, info(Text, _, _)), name_(F, Name),
    format(atom(Key), '~w#~w', [MId, Name]),
    (   Shape = derived(judgment, _) -> ( As == [] -> V = not_holds ; V = holds )
    ;   memberchk(Shape, [derived(scalar, _), parameter]), As = [A], answer_value(Text, A, V)
    ).

answer_value(Text, Answer, V) :-
    template_parts(Text, Words, _),
    maplist([W, P]>>( W = place(_) -> P = "(.+?)" ; escape(W, P) ), Words, Ps),
    atomic_list_concat(Ps, ' ', Re0), atomic_list_concat(['^', Re0, '$'], Re),
    format(string(A), "~w", [Answer]),
    re_matchsub(Re, A, Sub, []),
    dict_pairs(Sub, _, Pairs), last(Pairs, _-VS),
    ( number_string(V, VS) -> true ; atom_string(V, VS) ).

escape(W, P) :- re_replace("([.^$*+?()\\[\\]{}|\\\\])"/g, "\\\\\\1", W, P).

tests_yaml(Cases, Text) :-
    with_output_to(string(Text), forall(member(C, Cases), write_case(C))).

write_case(case(N, Period, In, Out)) :-
    (   Period = day(D)
    ->  format("- name: ~w~n  period:~n    period_kind: custom~n    name: day~n    start: '~w'~n    end: '~w'~n  input:~n", [N, D, D])
    ;   format("- name: ~w~n  period: ~w~n  input:~n", [N, Period])
    ),
    forall(member(K-V, In), write_input(K, V)),
    format("  output:~n"),
    forall(member(K-V, Out), format("    ~w: ~w~n", [K, V])).

write_input(K, Items) :- is_list(Items), !,
    format("    ~w:~n", [K]),
    forall(member(Item, Items),
           (   Item == [] -> format("    - {}~n")
           ;   Item = [K1-V1|Rest], format("    - ~w: ~w~n", [K1, V1]), forall(member(K2-V2, Rest), format("      ~w: ~w~n", [K2, V2]))
           )).
write_input(K, V) :- format("    ~w: ~w~n", [K, V]).

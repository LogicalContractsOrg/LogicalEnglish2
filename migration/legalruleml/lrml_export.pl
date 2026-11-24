/** <module> Logical English -> LegalRuleML: File ▸ Export to Another System

    The second deliverable of Phase 2f (the design notes roadmap.md §8): a
    loaded Logical English program written as a LegalRuleML document in the
    compact serialisation, so that a twin (or any LE program) can be handed
    to a LegalRuleML consumer — and read back by lrml_twin.pl, which is the
    round trip (roundtrip.pl). Registered with LE2's exporter registry by
    migration/le_importers.pl, so both the LE editor and the LPS2 IDE offer
    it.

    LE for Prolog:
      - a template is a relation: `<ruleml:Rel iri="le:F">` whose text is the
        template itself (`*a person* is born in *a place*`), which is how
        the words travel and come back;
      - a rule is a ConstitutiveStatement, or a PrescriptiveStatement when it
        concludes an obligation, permission or prohibition of the deontic
        library (Obligation, Permission, Prohibition with the party as the
        Bearer); every rule is strict (LE has no defeasibility), and its
        Paraphrase is its own Logical English;
      - `and`, `or`, `it is not the case that` are And, Or, Naf; comparisons
        and arithmetic are RIF's built-ins (pred:numeric-less-than,
        func:numeric-add, ...);
      - a rule's label is the statement's key, its provenance a LegalSource
        and an Association; a fact is a FactualStatement; each scenario is a
        Statements block of FactualStatements (key `scenario-<name>`).
      A negation's own variables are declared by an Exists inside its Naf
      (naf_scopes/3), so an `otherwise` cascade, compiled to A or (not A and
      B), is written faithfully.
      What LegalRuleML cannot say without losing meaning — aggregates,
      universals, decision tables, services, structured values — makes
      the export refuse, with each such rule's line (check_lrml/3, run by
      le_import.pl before the document is written); what it leaves out
      without loss — queries and expected answers — is a note (and a
      Comment in the document).

    LE for LPS (the LPS2 IDE's Misc ▸ Export): the program's LPS reading is
    written as norms — a reactive rule is an obligation of the one who acts
    (if the conditions then Obligation(the action)), an integrity constraint
    on an action a prohibition of it under its other conditions, a causal
    law a constitutive rule from the event and its conditions to the effect,
    a timeless rule a constitutive rule, the initial state and the timeless
    facts a block of facts. Time is what LegalRuleML does not have: the
    notes say so. A term with no norm (a composite event, a goal, a
    default, an invariant, a constraint over two actions, a consequent that
    is not an action, a condition it cannot write) makes the export refuse.
*/

:- module(lrml_export, [export_lrml/3, applies_lrml/1, check_lrml/3, kb_lrml_dom/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(sgml)).
:- use_module(library(sgml_write)).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer)).
:- use_module(le2(le_import), []).

%   Every loaded program with a rule or a fact can be written: what does not
%   carry over is noted. (An empty one is not offered: there is nothing to
%   write.) An LE for LPS program's IR holds only its templates — its rules,
%   laws and initial state are its LPS reading's terms — so it is offered
%   when that reading has a term other than a declaration or a setting, or
%   when the reading cannot be made (the refusal then says why).
applies_lrml(KB) :-
    once(le_writer:kb_to_ir(KB, program(Header, Items))),
    (   memberchk(target(lps), Header)
    ->  lps_reading_has_content(KB)
    ;   once(( member(I, Items), ( I = rule(_, _, _) ; I = fact(_, _) ) ))
    ).

lps_reading_has_content(KB) :-
    catch(le_lps:le_lps_module(KB, "", Internal, _, Issues), _, fail),
    (   memberchk(le_lps_issue(error, _, _, _, _), Issues) -> true
    ;   Internal \== "",
        term_string_terms(Internal, Terms),
        once(( member(T, Terms), \+ lps_declaration(T) ))
    ).

lps_declaration(T) :- functor(T, F, N),
    memberchk(F/N, [fluents/1, events/1, actions/1, prolog_events/1, maxTime/1, maxRealTime/1, minCycleTime/1,
                    (:-)/1, end_of_file/0]).
lps_declaration(initial_state([])).

%!  export_lrml(+KB, +Options, -Result) is det.
%
%   Result is exported(FileName, Text, Notes, []), or refused(Problems)
%   when something in the program has no LegalRuleML form (check_lrml/3).
export_lrml(KB, Options, Result) :-
    kb_lrml_dom(KB, Options, dom(Name, DOM, Notes)),
    nb_getval(lrml_export_problems, Problems0), reverse(Problems0, Problems1), list_to_set(Problems1, Problems),
    (   Problems \== []
    ->  Result = refused(Problems)
    ;   with_output_to(string(Text0), xml_write(current_output, DOM, [layout(true), header(true)])),
        provenance_comments(Text0, Text),
        format(atom(FileName), '~w.lrml', [Name]),
        Result = exported(FileName, Text, Notes, [])
    ).

%!  check_lrml(+KB, +Options, -Problems) is det.
%
%   The check before the document is written (le_import.pl,
%   export_check/2): what LegalRuleML cannot state and the document would
%   otherwise leave out — a rule with an aggregate, a universal or a
%   decision table; a template answered by a service; a fact it cannot state; a
%   structured term it could only name; in an LE for LPS program, a term of
%   its LPS reading with no norm for it (a composite event, a goal to plan,
%   a fluent's default, a constraint over two actions or none, a consequent
%   that is not an action, a condition it cannot write). Each with where it
%   is. The translation itself is the check: what it would have noted as
%   left out is a problem, what it notes without loss (the queries, time)
%   stays a note.
check_lrml(KB, Options, Problems) :-
    kb_lrml_dom(KB, Options, dom(_, _, _)),
    nb_getval(lrml_export_problems, Problems0), reverse(Problems0, Problems1), list_to_set(Problems1, Problems).

%!  kb_lrml_dom(+KB, +Options, -dom(Name, Element, Notes)) is det.
kb_lrml_dom(KB, Options, dom(Name, element('lrml:LegalRuleML', NS, Children), Notes)) :-
    %  (with the program's text, each rule and fact has its source line:
    %  the provenance comments, and the place of a problem)
    le_writer:kb_to_ir(KB, Options, program(Header, Items0)),
    ( memberchk(kb(Name0), Header) -> kb_file_name(Name0, Name) ; Name = program ),
    ( memberchk(target(lps), Header) -> Target = lps ; Target = prolog ),
    maplist(strip_at, Items0, Items),
    rule_positions(Items0, Positions), b_setval(lrml_export_positions, Positions),
    rule_bodies(Items0, Bodies), b_setval(lrml_export_bodies, Bodies),
    table_positions(KB, TablePositions), b_setval(lrml_export_tables, TablePositions),
    b_setval(lrml_export_where, none), b_setval(lrml_export_kb, none),
    nb_setval(lrml_export_notes, []), nb_setval(lrml_export_problems, []),
    nb_setval(lrml_export_k, 0), nb_setval(lrml_export_f, 0),
    b_setval(lrml_export_defeasible, []),
    templates(Items, Ts),
    b_setval(lrml_export_templates, Ts),
    (   Target == lps
    ->  b_setval(lrml_export_kb, KB), b_setval(lrml_export_items, Items),
        lps_statements(KB, Options, Items, Stmts0, Facts0)
    ;   b_setval(lrml_export_kb, KB),
        prolog_statements(Items, Stmts0, Facts0),
        prolog_marks(KB, Header, Items),
        %  the IR does not carry LE's integrity constraints: said here
        le_import:kb_constraint_problems(KB, "LegalRuleML", CPs),
        forall(member(problem(W, M), CPs), problem(W, M))
    ),
    maplist(statement_with_provenance, Stmts0, Stmts1), append(Stmts1, Stmts),
    maplist(statement_with_provenance, Facts0, Facts1), append(Facts1, Facts),
    sources(Items, Stmts, SourceEls, AssocEls),
    scenario_blocks(Items, Target, ScenEls),
    nb_getval(lrml_export_notes, Notes0), reverse(Notes0, Notes1), list_to_set(Notes1, Notes),
    format(string(C0), "Exported from the Logical English program ~w (target ~w) by the LegalRuleML translator of Logical English. Relation names are LE's; each relation's text is its LE template.", [Name0, Target]),
    findall(element('lrml:Comment', [], [N]), member(N, Notes), NoteEls),
    (   Facts == [] -> FactEls = []
    ;   FactEls = [element('lrml:Statements', [key=facts], Facts)]
    ),
    append([[element('lrml:Comment', [], [C0])], NoteEls, SourceEls, AssocEls,
            [element('lrml:Statements', [key=rules], Stmts)], FactEls, ScenEls], Children),
    NS = ['xmlns:lrml'='http://docs.oasis-open.org/legalruleml/ns/v1.0/',
          'xmlns:ruleml'='http://ruleml.org/spec',
          'xmlns:xs'='http://www.w3.org/2001/XMLSchema',
          'xmlns:xsi'='http://www.w3.org/2001/XMLSchema-instance'].

kb_file_name(N0, N) :-
    format(atom(A), '~w', [N0]), atomic_list_concat(Ws, ' ', A), atomic_list_concat(Ws, '_', N).

note(N) :- nb_getval(lrml_export_notes, Ns), nb_setval(lrml_export_notes, [N|Ns]).

%   What cannot be stated without losing meaning: a problem, where it is
%   (at(Start, End) in the program's text, line(N), or none).
problem(Where, M) :- nb_getval(lrml_export_problems, Ps), nb_setval(lrml_export_problems, [problem(Where, M)|Ps]).
problem(M) :- ( nb_current(lrml_export_where, W) -> true ; W = none ), problem(W, M).

%   Where each rule of the program starts: its first condition's offsets
%   (the IR keeps them in le_at/3), keyed by the rule without positions.
rule_positions(Items0, Ps) :-
    findall(R-at(S, E),
            ( member(rule(H, B, O), Items0),
              findall(S0-E0, ( sub_term(X, B), compound(X), X = le_at(_, S0, E0), integer(S0) ), SEs),
              SEs \== [], msort(SEs, [S-E|_]),
              strip_at(rule(H, B, O), R) ),
            Ps).

%   Each rule without positions, with its body as the IR gives it (le_at/3
%   around each condition), to say where the construct the export cannot
%   write is.
rule_bodies(Items0, Bs) :-
    findall(R-B, ( member(rule(H, B, O), Items0), strip_at(rule(H, B, O), R) ), Bs).

%   Where each decision table is: the range of the clause that binds its
%   template (le_kbs records it for explanations and the verifier).
table_positions(KB, Ps) :-
    findall(Name-at(S, E),
            ( current_predicate(KB:le_table/6), KB:le_table(Name, _, F/A, _, _, _),
              functor(H, F, A), current_predicate(KB:F/A),
              clause(KB:H, le_table(Name, _), Ref),
              catch(KB:le_source_info(Ref, S, E, _), _, fail), integer(S) ),
            Ps0),
    sort(Ps0, Ps).

rule_where(rule(H, B, O), W) :-
    b_getval(lrml_export_positions, Ps),
    (   member(rule(H1, B1, _)-W, Ps), rule(H1, B1) =@= rule(H, B) -> true
    ;   memberchk(label(L), O), member(rule(_, _, O1)-W, Ps), memberchk(label(L), O1) -> true
    ;   member(rule(H1, _, _)-W, Ps), H1 =@= H -> true
    ;   memberchk(source(_, S, E), O), integer(S) -> W = at(S, E)   % a rule with no condition
    ;   callable(H) -> functor(H, F, N), W = predicate(F/N)   % e.g. a rule of an included resource
    ;   W = none
    ).

%   The IR without its source positions.
strip_at(V, V) :- var(V), !.
strip_at(le_at(G, _, _), G1) :- !, strip_at(G, G1).
strip_at(T, T1) :- compound(T), !, T =.. [F|As], maplist(strip_at, As, Bs), T1 =.. [F|Bs].
strip_at(T, T).

		 /*******************************
		 *          PROVENANCE          *
		 *******************************/

/*  Beside each statement written from a rule, fact or constraint, the line
    of the program it came from, as an XML comment (le_import.pl,
    "Provenance"): `<!-- Logical English line 74 -->`. LegalRuleML's own
    provenance constructs (LegalSources, Associations, Source) are for the
    legal texts a norm comes from; a line of the Logical English program is
    not one, and a comment leaves the document's meaning as it was — a
    LegalRuleML reader (lrml_reader.pl among them) does not see it.

    library(sgml_write) writes no comments, so the document carries an
    empty element in their place (`le-provenance`, which no LegalRuleML
    vocabulary has), and provenance_comments/2 turns each into its
    comment in the written text. */

%   The lines an IR item came from (kb_to_ir/3's source/3 option).
item_lines(O, Ls) :- ( le_import:item_source_line(O, L) -> Ls = [L] ; Ls = [] ).

%   A statement, with the placeholder of its comment before it.
statement_with_provenance(src(Ls0, El), Els) :- !,
    sort(Ls0, Ls),
    (   Ls == [] -> Els = [El]
    ;   Ls = [L] -> format(atom(C), 'Logical English line ~w', [L]), Els = [element('le-provenance', [line=C], []), El]
    ;   atomic_list_concat(Ls, ', ', LT), format(atom(C), 'Logical English lines ~w', [LT]),
        Els = [element('le-provenance', [line=C], []), El]
    ).
statement_with_provenance(El, [El]).

provenance_comments(Text0, Text) :-
    split_string(Text0, "\n", "", Lines0),
    maplist(provenance_line, Lines0, Lines),
    atomic_list_concat(Lines, '\n', A), atom_string(A, Text).

provenance_line(L0, L) :-
    (   sub_string(L0, B, _, A, "<le-provenance line=\""),
        sub_string(L0, 0, B, _, Indent),
        sub_string(L0, _, A, 0, Rest),
        sub_string(Rest, E, _, _, "\"/>")
    ->  sub_string(Rest, 0, E, _, C), format(string(L), "~w<!-- ~w -->", [Indent, C])
    ;   L = L0
    ).

		 /*******************************
		 *           VOCABULARY         *
		 *******************************/

%   t(F, N, Text, Kind): the program's templates; Kind deontic(K) for the
%   library's operators, library for its other relations, own otherwise.
templates(Items, Ts) :-
    findall(t(F, N, Text, Kind),
            ( ( member(template(F, Text0, _), Items) ; member(fluent(F, Text0, _), Items)
              ; member(event(F, Text0, _), Items) ; member(action(F, Text0, _), Items)
              ; member(constant(F, Name, _), Items), format(string(Text0), "~w is *a value*", [Name]) ),
              atom_string(Text0, Text), places(Text, N), template_kind(Text, Kind) ), Ts).

places(Text, N) :- split_string(Text, "*", "", Parts), length(Parts, L), N is (L - 1) // 2.

template_kind(Text, deontic(K)) :- library_operator(Text, K), !.
template_kind(Text, library) :- library_relation(Text), !.
template_kind(_, own).

library_operator("*a party* is obliged that *a sentence*", obligation).
library_operator("*a party* is permitted that *a sentence*", permission).
library_operator("*a party* is forbidden that *a sentence*", prohibition).
library_relation(T) :- memberchk(T, ["the obligation of *a party* that *a sentence* is violated",
                                     "the prohibition of *a party* that *a sentence* is violated",
                                     "*a party* complies with the obligation that *a sentence*",
                                     "*a party* is in breach"]).

template_of(G, T) :-
    callable(G), functor(G, F, N),
    b_getval(lrml_export_templates, Ts),
    memberchk(t(F, N, _, _), Ts), member(T, Ts), T = t(F, N, _, _), !.

		 /*******************************
		 *        LE FOR PROLOG         *
		 *******************************/

prolog_statements(Items0, Stmts, Facts) :-
    defeasibility(Items0, Items, Attacks),
    %  two statements that defeat each other conflict with no priority
    %  between them: both defeasible, no Override (lrml_twin reads the
    %  conflict back as the same two exceptions)
    exclude({Attacks}/[O-U]>>memberchk(U-O, Attacks), Attacks, Overrides),
    findall(K, ( member(O-U, Attacks), ( K = O ; K = U ) ), Ds0), sort(Ds0, Ds),
    b_setval(lrml_export_defeasible, Ds),
    findall(I-R, nth1(I, Items, R), Numbered),
    foldl(item_statement, Numbered, []-[], RevS-RevF),
    reverse(RevS, Stmts0), reverse(RevF, Facts),
    findall(element('lrml:OverrideStatement', [], [element('lrml:Override', [over=O1, under=U1], [])]),
            ( member(O-U, Overrides), atom_concat('#', O, O1), atom_concat('#', U, U1) ), OEls),
    append(OEls, Stmts0, Stmts).

%   A LegalRuleML twin says an Override in words: the rule overridden holds
%   only when `it is not the case that the statement ps2 applies`, and ps2's
%   own rule holds when `the statement ps2 applies`, which is said once
%   (lrml_twin.pl). Written back, they are the Override and ps2's conditions
%   again, and both rules are defeasible. (A defeater's applicability, with
%   no rule of its own to carry it, stays a condition.)
defeasibility(Items0, Items, Overrides) :-
    findall(K-B, ( member(rule(H, B, _), Items0), applies_head(H, K) ), App),
    findall(K, ( member(rule(H, _, O), Items0), \+ applies_head(H, _), rule_key(O, K), memberchk(K-_, App) ), Own0),
    sort(Own0, Own),
    %  a defeater (`the statement cs2 applies if …`, no rule of its own) is
    %  a Defeater statement again when every rule it is an exception of
    %  concludes one thing whose complement the program can say
    findall(S-NH, ( member(S-_, App), \+ memberchk(S, Own), defeater_conclusion(Items0, S, NH) ), Defs),
    foldl(defeasible_item(App, Own, Defs), Items0, []-[], RevItems-RevOv),
    reverse(RevItems, Items), reverse(RevOv, Overrides0), list_to_set(Overrides0, Overrides).

defeater_conclusion(Items, S, NH) :-
    findall(H, ( member(rule(H, B, O), Items), rule_key(O, _), conj_list(B, Gs),
                 member(not(G), Gs), applies_head(G, S) ), Hs),
    Hs = [H1|_], complement(H1, NH),
    forall(member(H, Hs), ( complement(H, NH1), NH1 =@= NH )).

%   The complement of a conclusion, as the program words it: `*a thing* is
%   a rel3` and `*a thing* is not a rel3`.
complement(H, NH) :-
    template_of(H, t(_, N, Text, _)),
    (   sub_string(Text, B, _, A, " is not ") -> sub_string(Text, 0, B, _, Pre), sub_string(Text, _, A, 0, Post), string_concat(Pre, " is ", P1)
    ;   sub_string(Text, B, _, A, "* is "), B1 is B + 1, sub_string(Text, 0, B1, _, Pre), sub_string(Text, _, A, 0, Post), string_concat(Pre, " is not ", P1)
    ), !,
    string_concat(P1, Post, NText),
    b_getval(lrml_export_templates, Ts), member(t(NF, N, NText, _), Ts), !,
    H =.. [_|Args], NH =.. [NF|Args].

defeasible_item(_, Own, _, rule(H, _, _), Is-Os, Is-Os) :- applies_head(H, K), memberchk(K, Own), !.
defeasible_item(_, _, Defs, rule(H, B, O), Is-Os, [rule(NH, B, [label(K), defeater|Src])|Is]-Os) :-
    applies_head(H, K), memberchk(K-NH, Defs), !,
    findall(X, ( member(X, O), X = source(_, _, _) ), Src).
defeasible_item(App, Own, Defs, rule(H, B, O), Is-Os0, [rule(H, B1, O)|Is]-Os) :-
    rule_key(O, K), !,
    conj_list(B, Gs),
    foldl(defeasible_goal(App, Own, Defs, K), Gs, []-Os0, RevGs-Os),
    reverse(RevGs, Gs1),
    ( Gs1 == [] -> B1 = true ; Gs1 = [G|Gt], foldl([X, A0, and(A0, X)]>>true, Gt, G, B1) ).
defeasible_item(_, _, _, I, Is-Os, [I|Is]-Os).

defeasible_goal(App, _, _, K, G, Gs0-Os, Gs-Os) :-
    applies_head(G, K), memberchk(K-B, App), !,
    conj_list(B, Bs), reverse(Bs, RBs), append(RBs, Gs0, Gs).
defeasible_goal(_, Own, Defs, K, not(G), Gs-Os, Gs-[S-K|Os]) :-
    applies_head(G, S), ( memberchk(S, Own) ; memberchk(S-_, Defs) ), !.
defeasible_goal(_, _, _, _, G, Gs-Os, [G|Gs]-Os).

applies_head(H, K) :-
    template_of(H, t(_, 1, "the statement *a statement* applies", _)),
    arg(1, H, K0), atom(K0), key_of(K0, K).

rule_key(O, K) :- memberchk(label(L), O), key_of(L, K).

item_statement(_-rule(H, B, O), S0-F0, S-F0) :- !,
    ( memberchk(label(L), O) -> key_of(L, K) ; statement_counter(K) ),
    rule_where(rule(H, B, O), W), b_setval(lrml_export_where, W),
    (   rule_statement(K, H, B, O, El) -> item_lines(O, Ls), S = [src(Ls, El)|S0]
    ;   note_untranslatable(rule(H, B, O)), S = S0
    ),
    b_setval(lrml_export_where, none).
%   `the text of D is at "U"`: where a document is, which a rule's
%   provenance cites (sources/4) — a declaration, not a statement.
item_statement(_-fact(le_text_at(_, _), _), Acc, Acc) :- !.
%   `D is published at "U"`: a LegalSource (sources/4), not a statement.
item_statement(_-fact(le_published_at(_, _), _), Acc, Acc) :- !.
item_statement(_-fact(H, O), S0-F0, S0-[src(Ls, El)|F0]) :-
    %  (a structured value in it is a problem at the fact)
    fact_where(H, O, W), b_setval(lrml_export_where, W),
    fact_statement(H, El), !,
    b_setval(lrml_export_where, none),
    item_lines(O, Ls).
item_statement(_-fact(H, O), S0-F0, S0-F0) :- !,
    b_setval(lrml_export_where, none),
    format(string(N), "a fact LegalRuleML cannot state: ~q", [H]), fact_where(H, O, W), problem(W, N).
item_statement(_-table(Name, _, _, _), S0-F0, S0-F0) :- !,
    (   nb_current(lrml_export_tables, TPs), memberchk(Name-W, TPs) -> true ; W = none ),
    format(string(N), "the decision table ~w: LegalRuleML has no tables (write its rows as rules to export them)", [Name]), problem(W, N).
item_statement(_, Acc, Acc).

%   Where a fact of the program is: its source (the IR item's options), else
%   its clause's range, else every clause of its predicate.
fact_where(_, O, at(S, E)) :- memberchk(source(_, S, E), O), integer(S), !.
fact_where(H, _, W) :-
    (   nb_current(lrml_export_kb, KB), KB \== none, callable(H),
        catch(( clause(KB:H, true, Ref), KB:le_source_info(Ref, S, E, _) ), _, fail), integer(S)
    ->  W = at(S, E)
    ;   callable(H) -> functor(H, F, N), W = predicate(F/N)
    ;   W = none
    ).

%   What a program's templates and sections say beyond its rules and facts.
%   A template answered by a service (`; via service`, §17.6) has no rule or
%   fact in the document: a LegalRuleML reader would hold it false, so the
%   export refuses, at the template. A judged or assumable template (an
%   unstated instance is open, not false), the decision skeleton's sections
%   and the provenance of the facts are about how a case is answered and
%   explained, not about what the rules conclude from what is stated: notes.
prolog_marks(KB, Header, Items) :-
    %  (the problem is about the template as a whole: every clause of it,
    %  shown at the template's line)
    forall(( member(template(F, Text, O), Items), memberchk(via_service(S), O) ),
           ( atom_string(Text, TS), places(TS, N), W = predicate(F/N),
             format(string(M), "the template \"~w\" is answered by the service ~w at run time: LegalRuleML has no services, and a document without its answers would hold it false", [Text, S]),
             problem(W, M) )),
    (   memberchk(services(Ss), Header), Ss \== [], \+ ( member(template(_, _, O), Items), memberchk(via_service(_), O) )
    ->  note("the program's service declarations are not exported: LegalRuleML has no services")
    ;   true
    ),
    findall(Q, ( member(template(_, Text, O), Items), ( memberchk(judged, O) ; memberchk(assumable, O) ),
                 format(string(Q), "\"~w\"", [Text]) ), Js),
    (   Js == [] -> true
    ;   atomic_list_concat(Js, ', ', JT),
        format(string(JN), "judged or assumable templates (~w): LegalRuleML has no such mark, so an instance a case does not state reads as false there, where LE leaves it open (a judgment needed, an assumption)", [JT]),
        note(JN)
    ),
    (   catch(( current_predicate(KB:le_source_section/2), KB:le_source_section(Sec, _),
                le_sections:section_role(Sec, _) ), _, fail)
    ->  note("the decision skeleton's sections (applicability, question, remedy) are not exported: they only say where a failed query fails")
    ;   true
    ),
    (   ( member(fact(H, O), Items), \+ functor(H, le_text_at, 2), \+ functor(H, le_published_at, 2),
          memberchk(provenance(P), O), P \== []
        ; member(scenario(_, Lines, _), Items), member(fact(_, O), Lines),
          once(( member(X, O), X \= source(_, _, _) ))
        )
    ->  note("the facts' provenance (according to, as stated in, because, confer) is not exported: LegalRuleML associates sources with rules here")
    ;   true
    ).

%   Where a template is declared: the range of its dictionary entry.
template_where(KB, F, _, at(S, E)) :-
    catch(( clause(KB:le_dict(dict([F|_], _, _, _, _, _, _)), true, Ref),
            KB:le_source_info(Ref, S, E, template) ), _, fail), integer(S), !.
template_where(_, _, _, none).

statement_counter(K) :-
    ( nb_current(lrml_export_k, N0) -> true ; N0 = 0 ), N is N0 + 1, nb_setval(lrml_export_k, N),
    format(atom(K), 'rule~w', [N]).

key_of(L, K) :- format(atom(K0), '~w', [L]), atomic_list_concat(Ws, ' ', K0), atomic_list_concat(Ws, '_', K).

%   The problem of a rule the export cannot write names the construct that
%   stops it, where that construct is: the innermost condition LegalRuleML
%   cannot state (`according to` inside `it is not the case that` is the
%   `according to`, at its own line: the negation alone is a Naf).
note_untranslatable(rule(H, B, O)) :-
    (   nb_current(lrml_export_bodies, Bs), member(R-B0, Bs), R =@= rule(H, B, O), R = rule(H, B, O),
        culprit(B0, W0, G)
    ->  construct_name(G, What),
        ( W0 == none -> nb_getval(lrml_export_where, W) ; W = W0 )
    ;   sub_term(X, B), nonvar(X), untranslatable(X, What) -> nb_getval(lrml_export_where, W)
    ;   conj_list(B, Gs), member(G, Gs), \+ formula_ok(G), callable(G) -> construct_name(G, What), nb_getval(lrml_export_where, W)
    ;   What = "a construct", nb_getval(lrml_export_where, W)
    ),
    ( template_of(H, t(_, _, Text, _)) -> true ; format(string(Text), "~q", [H]) ),
    format(string(N), "a rule for \"~w\" uses ~w, which LegalRuleML cannot state", [Text, What]),
    problem(W, N).

%   culprit(+PositionedFormula, -Where, -Goal): the innermost part that has
%   no LegalRuleML form: a part whose own parts (those with positions) all
%   have one, or the first of its parts that does not.
culprit(T, W, G) :- compound(T), T = le_at(X, S, E), !,
    (   culprit_part(X, W, G) -> true
    ;   strip_at(X, G), \+ formula_ok(G), ( integer(S) -> W = at(S, E) ; W = none )
    ).
culprit(T, W, G) :- compound(T),
    (   culprit_part(T, W, G) -> true
    ;   strip_at(T, G), \+ formula_ok(G), W = none
    ).

culprit_part(X, W, G) :-
    compound(X), X =.. [_|As],
    member(A, As), compound(A), once(( sub_term(P, A), compound(P), P = le_at(_, _, _) )),
    culprit(A, W, G), !.

formula_ok(G) :-
    nb_getval(lrml_export_problems, Ps), ( nb_current(lrml_export_vars, Vs) -> true ; Vs = [] ),
    copy_term(G, G1), ( formula_(G1, _) -> Ok = true ; Ok = false ),
    nb_setval(lrml_export_problems, Ps), b_setval(lrml_export_vars, Vs),
    Ok == true.

construct_name(G, What) :- nonvar(G), untranslatable(G, What), !.
%   A conjunction or disjunction names the part that has no form, not itself.
construct_name(G, What) :- compound(G), ( G = and(_, _) ; G = or(_, _) ),
    sub_term(X, G), X \== G, nonvar(X), untranslatable(X, What), !.
construct_name(G, What) :- compound(G), ( G = and(A, B) ; G = or(A, B) ),
    ( \+ formula_ok(A) -> construct_name(A, What) ; construct_name(B, What) ), !.
construct_name(G, What) :- callable(G), !, functor(G, F, A), format(string(What), "~w/~w", [F, A]).
construct_name(_, "a construct").

untranslatable(forall(_, _), "a universal (for all cases in which)").
untranslatable(prolog_call(_), "a Prolog goal (`prolog …`)").
untranslatable(agg(_, _, _, _), "an aggregate").
untranslatable(otherwise(_), "an otherwise cascade").
untranslatable(le_table(_, _), "a decision table").
untranslatable(le_scoped(_, _), "`according to` (who holds a condition true)").
untranslatable(le_semantically_similar(_, _), "a semantic template answered by a service").
untranslatable(le_best_match(_, _, _), "a semantic template answered by a service").
untranslatable(le_satisfies_description(_, _), "a semantic template answered by a service").

rule_statement(K, H, B, O, element(Kind, [key=K], [Rule])) :-
    b_setval(lrml_export_vars, []),
    formula(B, If0),
    head(H, Then, Kind),
    rule_paraphrase(H, B, O, Para),
    format(atom(RK), ':rule-~w', [K]),
    (   memberchk(defeater, O) -> Strength = 'lrml:Defeater'
    ;   nb_current(lrml_export_defeasible, Ds), memberchk(K, Ds)
    ->  Strength = 'lrml:DefeasibleStrength'
    ;   Strength = 'lrml:StrictStrength'
    ),
    If0 = element(_, _, _),
    naf_scopes(If0, Then, If),
    Rule = element('ruleml:Rule', [key=RK, closure=universal],
                   [ element('lrml:Paraphrase', [], [Para]),
                     element('lrml:hasStrength', [], [element(Strength, [], [])]),
                     element('ruleml:if', [], [If]),
                     element('ruleml:then', [], [Then]) ]), !.

head(H, El, 'lrml:PrescriptiveStatement') :-
    template_of(H, t(_, 2, _, deontic(Kind))), !,
    H =.. [_, P, S],
    deontic_element(Kind, P, S, El).
head(H, El, 'lrml:ConstitutiveStatement') :- formula_(H, El), El = element('ruleml:Atom', _, _).

deontic_element(Kind, P, S, element(E, [], [element('ruleml:slot', [], [element('lrml:Bearer', [], []), PE]), SE])) :-
    memberchk(Kind-E, [obligation-'lrml:Obligation', permission-'lrml:Permission', prohibition-'lrml:Prohibition']),
    term_element(P, PE),
    atom_element(S, SE).

fact_statement(H, element('lrml:FactualStatement', [key=K], [El])) :-
    ( nb_current(lrml_export_f, N0) -> true ; N0 = 0 ), N is N0 + 1, nb_setval(lrml_export_f, N),
    format(atom(K), 'fact~w', [N]),
    b_setval(lrml_export_vars, []),
    (   template_of(H, t(_, 2, _, deontic(Kind))) -> H =.. [_, P, S], deontic_element(Kind, P, S, El)
    ;   formula_(H, El), El = element('ruleml:Atom', _, _)
    ).

%   The rule's own Logical English, as its Paraphrase.
rule_paraphrase(H, B, O, Para) :-
    b_getval(lrml_export_templates, Ts),
    findall(template(F, Text, []), member(t(F, _, Text, _), Ts), TIs),
    exclude([X]>>(X = label(_) ; X = provenance(_) ; X = source(_, _, _)), O, O1),
    copy_term(H-B, H1-B1),
    catch(( le_write(program([kb(p), target(prolog)], [rule(H1, B1, O1)|TIs]), T, _),
            sub_string(T, Bf, _, _, "includes:"), sub_string(T, Bf, _, 0, T1),
            sub_string(T1, P1, _, _, "\n\n"), P2 is P1 + 2, sub_string(T1, P2, _, 0, T2),
            normalize_space(string(Para), T2) ), _, fail), !.
rule_paraphrase(_, _, _, "").

		 /*******************************
		 *           FORMULAS           *
		 *******************************/

formula(true, element('ruleml:And', [], [])) :- !.
formula(G, El) :- formula_(G, El), !.

formula_(V, _) :- var(V), !, fail.
formula_(and(A, B), element('ruleml:And', [], Es)) :- !,
    conj_list(and(A, B), Gs), maplist(formula_, Gs, Es).
formula_((A, B), El) :- !, formula_(and(A, B), El).
formula_(or(A, B), element('ruleml:Or', [], [EA, EB])) :- !, formula_(A, EA), formula_(B, EB).
formula_((A ; B), El) :- !, formula_(or(A, B), El).
formula_(not(G), element('ruleml:Naf', [], [E])) :- !, formula_(G, E).
formula_(\+ G, El) :- !, formula_(not(G), El).
formula_(G, El) :- builtin(G, Rel, Args), !,
    maplist(term_element, Args, AEs),
    El = element('ruleml:Atom', [], [element('ruleml:Rel', [iri=Rel], [])|AEs]).
formula_(G, El) :- template_of(G, t(_, 2, _, deontic(Kind))), !,
    G =.. [_, P, S], deontic_element(Kind, P, S, El).
formula_(G, El) :- template_of(G, _), !, atom_element(G, El).

%   The variables of a negation that nothing before it binds.
%
%   A rule's variables are universal over the whole rule (closure
%   universal), so `Naf(p(X, Y))` with Y bound nowhere before it reads
%   "for some Y, p(X, Y) is not provable" — while LE (and Prolog) means
%   "there is no Y with p(X, Y)". An `otherwise` cascade's guards are such
%   negations (`it is not the case that the customer holds a card of a
%   kind`), and so is any `it is not the case that` with a variable of its
%   own. Each is written as Naf(Exists(Vars, G)): the variables that the
%   conclusion and the conditions before the negation (in And order; for an
%   Or, those every alternative binds) do not bind are the Exists's.
naf_scopes(If0, Then, If) :-
    el_vars(Then, HVs),
    scope_nafs(If0, HVs, If, _).

scope_nafs(element(E, A, Cs), B0, element(E, A, Cs1), B) :- E == 'ruleml:And', !,
    scope_seq(Cs, B0, Cs1, B).
scope_nafs(element(E, A, Cs), B0, element(E, A, Cs1), B) :- E == 'ruleml:Or', !,
    scope_alts(Cs, B0, Cs1, Bs),
    (   Bs = [Bf|Br] -> intersections(Br, Bf, B1), union(B0, B1, B) ; B = B0 ).
scope_nafs(element(E, A, [C]), B0, element(E, A, [C2]), B0) :- E == 'ruleml:Naf', !,
    scope_nafs(C, B0, C1, _),
    el_vars(C1, Vs), subtract(Vs, B0, Local),
    (   Local == [] -> C2 = C1
    ;   findall(element('ruleml:Var', [], [V]), member(V, Local), VEs),
        append(VEs, [C1], ECs), C2 = element('ruleml:Exists', [], ECs)
    ).
scope_nafs(El, B0, El, B) :- el_vars(El, Vs), union(B0, Vs, B).

scope_seq([], B, [], B).
scope_seq([C|Cs], B0, [C1|Cs1], B) :- scope_nafs(C, B0, C1, B1), scope_seq(Cs, B1, Cs1, B).

scope_alts([], _, [], []).
scope_alts([C|Cs], B0, [C1|Cs1], [B|Bs]) :- scope_nafs(C, B0, C1, B), scope_alts(Cs, B0, Cs1, Bs).

intersections([], B, B).
intersections([X|Xs], B0, B) :- intersection(B0, X, B1), intersections(Xs, B1, B).

els_vars([], Vs, Vs).
els_vars([C|Cs], Vs0, Vs) :- el_vars(C, CV), union(Vs0, CV, Vs1), els_vars(Cs, Vs1, Vs).

%   The variable names free in an element (an Exists binds its own).
el_vars(element(E, _, Cs), Vs) :- E == 'ruleml:Var', !, Cs = [V], Vs = [V].
el_vars(element(E, _, Cs), Vs) :- E == 'ruleml:Exists', !,
    partition([X]>>(X = element('ruleml:Var', _, _)), Cs, Decl, Rest),
    findall(V, member(element(_, _, [V]), Decl), Ds),
    els_vars(Rest, [], Vs0),
    subtract(Vs0, Ds, Vs).
el_vars(element(_, _, Cs), Vs) :- !,
    els_vars(Cs, [], Vs).
el_vars(_, []).

conj_list(and(A, B), L) :- !, conj_list(A, LA), conj_list(B, LB), append(LA, LB, L).
conj_list((A, B), L) :- !, conj_list(and(A, B), L).
conj_list(G, [G]).

%   Comparisons and arithmetic: RIF's built-ins.
builtin(G, Rel, [X, Y]) :-
    G =.. [Op, X, Y],
    memberchk(Op-Rel, [(<)-'pred:numeric-less-than', le_lt-'pred:numeric-less-than',
                       (=<)-'pred:numeric-less-than-or-equal', le_le-'pred:numeric-less-than-or-equal',
                       (>)-'pred:numeric-greater-than', le_gt-'pred:numeric-greater-than',
                       (>=)-'pred:numeric-greater-than-or-equal', le_ge-'pred:numeric-greater-than-or-equal',
                       (is)-'pred:numeric-equal', le_assign-'pred:numeric-equal', (=:=)-'pred:numeric-equal',
                       (=)-'pred:equal', (\=)-'pred:not-equal', le_not_equal_to-'pred:not-equal',
                       is_a-'rdf:type']).                  % `alice is a person`

atom_element(G, element('ruleml:Atom', [], [RelEl|AEs])) :-
    template_of(G, t(F, _, Text, _)),
    G =.. [_|Args],
    format(atom(Iri), 'le:~w', [F]),
    RelEl = element('ruleml:Rel', [iri=Iri], [Text]),
    maplist(term_element, Args, AEs).

term_element(V, element('ruleml:Var', [], [N])) :- var(V), !, var_name(V, N).
term_element(X, element('ruleml:Data', ['xsi:type'='xs:integer'], [A])) :- integer(X), !, atom_number(A, X).
term_element(X, element('ruleml:Data', ['xsi:type'='xs:decimal'], [A])) :- number(X), !, format(atom(A), '~w', [X]).
term_element(date(Y, M, D), element('ruleml:Data', ['xsi:type'='xs:date'], [A])) :- !,
    format(atom(A), '~d-~|~`0t~d~2+-~|~`0t~d~2+', [Y, M, D]).
term_element(S, element('ruleml:Data', ['xsi:type'='xs:string'], [S])) :- string(S), !.
term_element(E, element('ruleml:Expr', [], [element('ruleml:Fun', [iri=Fun], [])|AEs])) :-
    compound(E), E =.. [Op, X, Y], memberchk(Op-Fun, [(+)-'func:numeric-add', (-)-'func:numeric-subtract',
                                                     (*)-'func:numeric-multiply', (/)-'func:numeric-divide']), !,
    maplist(term_element, [X, Y], AEs).
term_element(A, element('ruleml:Ind', [], [A])) :- atom(A), !.
term_element(L, element('ruleml:Plex', [], Es)) :- is_list(L), !, maplist(term_element, L, Es).
term_element(G, element('ruleml:Reify', [], [El])) :-          % a sentence as a value
    compound(G), template_of(G, _), !,
    (   template_of(G, t(_, 2, _, deontic(Kind))) -> G =.. [_, P, S], deontic_element(Kind, P, S, El)
    ;   atom_element(G, El)
    ).
term_element(T, element('ruleml:Ind', [], [A])) :-
    format(atom(A), '~q', [T]),
    format(string(N), "a structured value (~w): LegalRuleML could only name it, not state what it is made of", [A]), problem(N).

%   Variables named in order of appearance, per statement: X1, X2, ...
var_name(V, N) :-
    (   nb_current(lrml_export_vars, Vs0) -> true ; Vs0 = [] ),
    (   member(V0-N0, Vs0), V0 == V -> N = N0
    ;   length(Vs0, K), K1 is K + 1, format(atom(N), 'X~w', [K1]),
        b_setval(lrml_export_vars, [V-N|Vs0])
    ).

		 /*******************************
		 *    SOURCES AND SCENARIOS     *
		 *******************************/

%   A rule's provenance (as stated in a document) is a LegalSource and an
%   Association of it with the statement.
sources(Items, _, SourceEls, AssocEls) :-
    %  a document published at an address (`D is published at "U"`) is a
    %  LegalSource whether or not a rule cites it
    findall(D-U, member(fact(le_published_at(D, U), _), Items), Pubs),
    findall(D-U, ( member(document(D, O), Items), ( memberchk(url(U), O) -> true ; memberchk(text(U), O) -> true ; U = D ) ), Docs0),
    append(Pubs, Docs0, Docs),
    findall(K-D, ( member(rule(_, _, O), Items), memberchk(label(L), O), memberchk(provenance(P), O),
                   ( is_list(P) -> member(as_stated_in(D), P) ; P = as_stated_in(D) ; atomic(P), D = P ),
                   key_of(L, K) ), Links),
    findall(D, ( member(_-D, Links) ; member(D-_, Pubs) ), Ds0), sort(Ds0, Ds),
    findall(element('lrml:LegalSource', [key=SK, sameAs=U], []),
            ( member(D, Ds), key_of(D, SK), ( memberchk(D-U0, Docs) -> U = U0 ; U = D ) ), LSs),
    (   LSs == [] -> SourceEls = [], AssocEls = []
    ;   SourceEls = [element('lrml:LegalSources', [], LSs)],
        findall(element('lrml:Association', [], [element('lrml:appliesSource', [keyref=SR], []),
                                                 element('lrml:toTarget', [keyref=TR], [])]),
                ( member(K-D, Links), key_of(D, SK), atom_concat('#', SK, SR), atom_concat('#', K, TR) ), As),
        AssocEls = [element('lrml:Associations', [], As)]
    ).

scenario_blocks(Items, _, Els) :-
    findall(element('lrml:Statements', [key=Key], Fs),
            ( member(scenario(N, Lines, _), Items),
              format(atom(Key), 'scenario-~w', [N]),
              findall(F, ( member(L, Lines), ( L = fact(H) ; L = fact(H, _) ),
                           (   fact_statement(H, F) -> true
                           ;   format(string(SN), "a fact of scenario ~w LegalRuleML cannot state is not exported (a test's data, not the program): ~q", [N, H]),
                               note(SN), fail
                           ) ), Fs),
              Fs \== [] ), Els),
    (   (   member(query(_, _), Items)
        ;   member(scenario(_, Lines, _), Items), member(L, Lines),
            ( L = expects(_, _) ; L = expects(_, _, _) ; L = expects_changes(_, _) )
        )
    ->  note("the scenarios' facts are exported (Statements blocks `scenario-<name>`); the queries (flip queries included) and expected answers are not: LegalRuleML has no queries")
    ;   true
    ).

		 /*******************************
		 *          LE FOR LPS          *
		 *******************************/

%   The LPS reading, as norms (see the module comment).
lps_statements(KB, Options, _Items, Stmts, Facts) :-
    (   memberchk(text(Doc), Options) -> true ; Doc = "" ),
    catch(le_lps:le_lps_module(KB, Doc, Internal, Prov, Issues), _, fail),
    \+ memberchk(le_lps_issue(error, _, _, _, _), Issues),
    Internal \== "",
    term_string_terms(Internal, Terms), !,
    lps_names(KB, Names),
    b_setval(lrml_export_lps_names, Names),
    findall(src(Ls, S), ( nth1(I, Terms, T), lps_where(Prov, I), lps_lines(Prov, I, Ls),
                 nb_getval(lrml_export_problems, P0),
                 (   lps_statement(I, T, S) -> true
                 ;   lps_ignored(T) -> fail
                 ;   nb_getval(lrml_export_problems, P1), P1 \== P0 -> fail     % a condition said why
                 ;   lps_problem(T), fail
                 ) ), Stmts),
    b_setval(lrml_export_where, none),
    findall(src(Ls, F), ( nth1(I, Terms, initial_state(Fs)), lps_where(Prov, I), lps_lines(Prov, I, Ls),
                          member(X, Fs), lps_fact_or_problem(X, F) ), Facts0),
    findall(src(Ls, F), ( nth1(I, Terms, T), timeless_fact(T), lps_where(Prov, I), lps_lines(Prov, I, Ls),
                          lps_fact_or_problem(T, F) ), Facts1),
    append(Facts0, Facts1, Facts),
    note("LegalRuleML has no time: the LPS program's reactive rules are written as obligations of the one who acts, its constraints on actions as prohibitions, its causal laws as constitutive rules from the event to the effect; when each holds is not carried"),
    (   member(observe(_, _), Terms)
    ->  note("the scenario's observations (what happens when) are not exported: LegalRuleML has no time")
    ;   true
    ).
lps_statements(KB, Options, _, [], []) :-
    (   memberchk(text(Doc), Options) -> true ; Doc = "" ),
    catch(le_lps:le_lps_module(KB, Doc, _, _, Issues), _, Issues = []),
    (   member(le_lps_issue(error, _, M0, L, _), Issues)
    *-> format(string(M), "~w", [M0]), ( integer(L), L > 0 -> W = line(L) ; W = none ), problem(W, M)
    ;   problem(none, "the program's LPS reading could not be made: there is nothing to write")
    ).

%   The line of the I-th term's sentence (the emitter numbers its terms from
%   0), for the problems met while writing it.
lps_where(Prov, I) :-
    N is I - 1,
    ( memberchk(prov(N, L, _), Prov), integer(L), L > 0 -> W = line(L) ; W = none ),
    b_setval(lrml_export_where, W).

%   The line of the I-th term's sentence, as a list (none: []), for the
%   provenance comment of what it is written as.
lps_lines(Prov, I, Ls) :-
    N is I - 1,
    ( memberchk(prov(N, L, _), Prov), integer(L), L > 0 -> Ls = [L] ; Ls = [] ).

%   LPS terms that carry no norm: declarations, settings, the initial state
%   and the facts (written as facts), the scenario (noted).
lps_ignored(T) :- functor(T, F, N),
    memberchk(F/N, [fluents/1, events/1, actions/1, prolog_events/1, maxTime/1, maxRealTime/1, minCycleTime/1,
                    initial_state/1, observe/2, (:-)/1]), !.
lps_ignored(T) :- timeless_fact(T).

timeless_fact(T) :- compound(T), ground(T), functor(T, F, N),
    \+ memberchk(F/N, [fluents/1, events/1, actions/1, prolog_events/1, maxTime/1, maxRealTime/1, minCycleTime/1,
                       initial_state/1, observe/2, (:-)/1, (:-)/2, defaults/1, achieve/1, reactive_rule/2, d_pre/1,
                       initiated/3, terminated/3, updated/4, l_int/2, l_events/2, l_timeless/2]).
timeless_fact(T) :- atom(T), \+ memberchk(T, [end_of_file]).

%   What a term with no norm is, for its problem.
lps_problem(T) :-
    (   lps_problem_text(T, M) -> true
    ;   format(string(M), "an LPS term with no LegalRuleML form: ~q", [T])
    ),
    (   T = defaults(_), nb_current(lrml_export_where, none),
        nb_current(lrml_export_items, Items), nb_current(lrml_export_kb, KB),
        ( member(fluent(F, Text, O), Items) ; member(template(F, Text, O), Items) ),
        memberchk(default(_), O), template_where(KB, F, Text, W0), W0 \== none
    ->  atom_string(Text, TS), places(TS, N),
        (   fluent_unused(KB, F/N)
        ->  %  nothing written reads or changes the fluent (a partial export
            %  left out everything about it): its default says nothing there
            format(string(NoteS), "the default value of \"~w\" is not exported: LegalRuleML has no defaults, and nothing in this translation uses it", [Text]),
            note(NoteS)
        ;   problem(predicate(F/N), M)      % the fluent as a whole, shown at its template
        )
    ;   problem(M)
    ).

%   No LPS sentence and no clause of the program names F/N.
fluent_unused(KB, F/N) :-
    \+ ( catch(clause(KB:le_lps_item(_, P, _), true), _, fail),
         sub_term(T, P), compound(T), functor(T, F, N) ),
    \+ ( functor(H, F, N), catch(clause(KB:H, _), _, fail) ).

lps_problem_text(initiated(_, _, _), "a causal law whose event, effect or conditions LegalRuleML cannot state").
lps_problem_text(terminated(_, _, _), "a causal law whose event, effect or conditions LegalRuleML cannot state").
lps_problem_text(updated(_, _, _, _), "a causal law whose event, effect or conditions LegalRuleML cannot state").
lps_problem_text(l_events(_, _), "a composite event (an event made of others): LegalRuleML has no events").
lps_problem_text(achieve(_), "a goal to achieve (planning): LegalRuleML has no goals").
lps_problem_text(defaults(_), "a fluent's default value: LegalRuleML has no defaults").
lps_problem_text(d_pre(Cs), M) :-
    aggregate_all(count, member(happens(_, _, _), Cs), N),
    (   N =:= 0 -> M = "a constraint on every state (an invariant): LegalRuleML's prohibitions are of an action"
    ;   N > 1 -> M = "a constraint relating two actions: LegalRuleML's prohibitions are of one action"
    ;   M = "a constraint whose conditions LegalRuleML cannot state"
    ).
lps_problem_text(reactive_rule(_, Cons), M) :-
    (   member(C, Cons), C \= happens(_, _, _)
    ->  M = "a reactive rule whose consequence is not only actions (a computation or a state in the then-part): LegalRuleML's obligations are of an action"
    ;   M = "a reactive rule whose consequence is not an action a party takes, or whose conditions LegalRuleML cannot state"
    ).
lps_problem_text(l_int(_, _), "an intensional fluent whose conditions LegalRuleML cannot state").
lps_problem_text(l_timeless(_, _), "a timeless rule whose conditions LegalRuleML cannot state").

term_string_terms(Text, Terms) :-
    setup_call_cleanup(open_string(Text, In), read_all(In, Terms), close(In)).
read_all(In, Ts) :- read_term(In, T, []), ( T == end_of_file -> Ts = [] ; Ts = [T|R], read_all(In, R) ).

%   The LE templates of the LPS names (known_as).
lps_names(KB, Names) :-
    le_writer:kb_to_ir(KB, program(_, Items)),
    findall(I-F, ( ( member(template(F, _, O), Items) ; member(fluent(F, _, O), Items)
                   ; member(event(F, _, O), Items) ; member(action(F, _, O), Items) ),
                   memberchk(known_as(I), O) ), Names).

lps_goal(G0, G) :-
    b_getval(lrml_export_lps_names, Names),
    G0 =.. [I|As], length(As, N),
    (   member(I-F, Names), b_getval(lrml_export_templates, Ts), memberchk(t(F, N, _, _), Ts) -> G =.. [F|As]
    ;   G = G0
    ).

lps_statement(I, T, S) :- b_setval(lrml_export_vars, []), lps_statement_(I, T, S).

lps_statement_(I, reactive_rule(Ante, Cons), element('lrml:PrescriptiveStatement', [key=K], [Rule])) :-
    format(atom(K), 'reactive~w', [I]),
    lps_conditions(Ante, If),
    findall(El, ( member(happens(A, _, _), Cons), lps_goal(A, G), G =.. [_, P|_],
                  deontic_element(obligation, P, G, El) ), Els), Els \== [],
    length(Cons, NC), length(Els, NC),
    ( Els = [Then] -> true ; Then = element('ruleml:And', [], Els) ),
    lps_rule(K, If, Then, Rule).
lps_statement_(I, d_pre(Conds), element('lrml:PrescriptiveStatement', [key=K], [Rule])) :-
    format(atom(K), 'constraint~w', [I]),
    select(happens(A, _, _), Conds, Rest), \+ memberchk(happens(_, _, _), Rest), !,
    lps_goal(A, G), G =.. [_, P|_],
    lps_conditions(Rest, If),
    deontic_element(prohibition, P, G, Then),
    lps_rule(K, If, Then, Rule).
lps_statement_(I, Law, element('lrml:ConstitutiveStatement', [key=K], [Rule])) :-
    law_parts(Law, Kind, E, F, Conds), !,
    format(atom(K), '~w~w', [Kind, I]),
    lps_conditions([happens(E, _, _)|Conds], If),
    lps_goal(F, FG),
    ( Kind == terminated -> atom_element(FG, FE), Then = element('ruleml:Neg', [], [FE]) ; atom_element(FG, Then) ),
    lps_rule(K, If, Then, Rule).
lps_statement_(I, l_int(H0, B), element('lrml:ConstitutiveStatement', [key=K], [Rule])) :-
    format(atom(K), 'rule~w', [I]),
    ( H0 = holds(H, _) -> true ; H = H0 ),
    lps_goal(H, HG), atom_element(HG, Then),
    lps_conditions(B, If),
    lps_rule(K, If, Then, Rule).
lps_statement_(I, l_timeless(H, B), element('lrml:ConstitutiveStatement', [key=K], [Rule])) :-
    format(atom(K), 'rule~w', [I]),
    lps_goal(H, HG), atom_element(HG, Then),
    lps_conditions(B, If),
    lps_rule(K, If, Then, Rule).

law_parts(initiated(happens(E, _, _), F, Conds), initiated, E, F, Conds).
law_parts(terminated(happens(E, _, _), F, Conds), terminated, E, F, Conds).
law_parts(updated(happens(E, _, _), F0, _Old-New, Conds), updated, E, F, Conds) :-
    F0 =.. [N|As0], append(As1, [_], As0), append(As1, [New], As), F =.. [N|As].

lps_rule(K, If0, Then, element('ruleml:Rule', [key=RK, closure=universal],
                              [element('lrml:hasStrength', [], [element('lrml:StrictStrength', [], [])]),
                               element('ruleml:if', [], [If]), element('ruleml:then', [], [Then])])) :-
    format(atom(RK), ':rule-~w', [K]),
    naf_scopes(If0, Then, If).

%   Every condition, or none: one left out would widen the rule.
lps_conditions(Conds0, element('ruleml:And', [], Es)) :-
    ( is_list(Conds0) -> Conds = Conds0 ; conj_list(Conds0, Conds) ),
    maplist(lps_condition_, Conds, Es).

lps_condition_(C, E) :- lps_condition(C, E), !.
lps_condition_(C, _) :-
    lps_condition_text(C, M), problem(M), fail.

lps_condition_text(holds(findall(_, _, _), _), "a condition that collects values (the count, sum or list of each …): LegalRuleML has no aggregates") :- !.
lps_condition_text(C, M) :-
    lps_goal_of(C, G), format(string(M), "a condition LegalRuleML cannot state: ~q", [G]).

lps_goal_of(holds(F, _), G) :- !, lps_goal_of(F, G).
lps_goal_of(happens(E, _, _), G) :- !, lps_goal_of(E, G).
lps_goal_of(not(C), not(G)) :- !, lps_goal_of(C, G).
lps_goal_of(C, G) :- catch(lps_goal(C, G), _, G = C).

lps_condition(happens(E, _, _), El) :- !, lps_goal(E, G), formula_(G, El).
lps_condition(holds(not(F), _), element('ruleml:Naf', [], [El])) :- !, lps_goal(F, G), formula_(G, El).
lps_condition(holds(F, _), El) :- !, lps_goal(F, G), formula_(G, El).
lps_condition(not(C), element('ruleml:Naf', [], [El])) :- !, lps_condition(C, El).
lps_condition(C, El) :- lps_goal(C, G), formula_(G, El).

lps_fact(F0, El) :- lps_goal(F0, F), fact_statement(F, El).

lps_fact_or_problem(F0, El) :-
    (   lps_fact(F0, El0) -> El = El0
    ;   format(string(M), "a fact LegalRuleML cannot state: ~q", [F0]), problem(M), fail
    ).

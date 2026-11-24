/** <module> LegalRuleML -> Logical English: the twin of a LegalRuleML document

    Phase 2f (the design notes roadmap.md §5.8, §8). A LegalRuleML
    document (lrml_reader.pl) becomes a migration (le_migration.pl) in LE
    for Prolog, with the deontic pattern library lib/deontic.le:

      - a Constitutive statement's rule is an LE rule; `Neg` a relation of
        its own worded negatively (`it is false that ...`), `Naf` `it is not
        the case that`;
      - a Prescriptive statement's Obligation, Prohibition, Permission and
        Right are the library's `*a party* is obliged / forbidden / permitted
        that *a sentence*`, the bearer its Bearer slot (else the one the
        sentence is about); a SuborderList is a chain of rules, each element
        concluded once the one before it is violated (`the obligation of
        ... is violated`); a Reparation gives its penalty's chain on the
        violation of its statement;
      - defeasibility is written out as conditions, the E2 convention: a
        rule another overrides, or one with a conflicting conclusion and no
        order between them, holds only when the other's conditions do not
        (`it is not the case that ...`); a defeater concludes nothing and is
        only such a condition;
      - sources (Associations, Contexts) are provenance: `rule ps1 with
        provenance <source>`, the source a document of the program; a
        paraphrase is the rule's comment; temporal characteristics are a
        period of the relevant date; Alternatives a condition on the
        interpretation adopted;
      - Factual statements are facts; the document's metadata (authorities,
        jurisdictions, agents) the header.

    The tests: none ship with LegalRuleML, so the scenarios are drafted (in
    corpus.pl, from the paraphrases and the text of the law) and every
    expected answer is SPINdle's on the source (lrml_spindle.pl) — never the
    LE program's own.
*/

:- module(lrml_twin, [
    twin_migration/3,      % +File, +Options, -Migration
    build_twin/3,          % +File, +OutRoot, -Report
    twin_name/2            % +File, -Name
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(option)).
:- use_module(library(filesex)).
:- use_module(library(ordsets)).
:- use_module(lrml_reader).
:- use_module(lrml_spindle).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).

		 /*******************************
		 *            THE TWIN          *
		 *******************************/

%!  build_twin(+File, +Root, -Report) is det.
%
%   Writes Root/<Name>/<Name>.le, the deontic library beside it, its ledger,
%   and the source under sources/.
build_twin(File, Root, Report) :-
    twin_name(File, Name),
    atomic_list_concat([Root, '/', Name], Dir),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
    file_base_name(File, B), atomic_list_concat([SD, '/', B], Copy),
    copy_file(File, Copy),
    copy_library(deontic, Dir),
    twin_migration(File, [name(Name), source_copy(B)], Migration),
    write_migration(Migration, Dir, Name, Report).

%   ex5-section29new-normal.lrml -> ex5_section29new; credit.lrml -> credit
twin_name(File, Name) :-
    file_base_name(File, B), file_name_extension(S0, _, B),
    atomic_list_concat(Parts0, '-', S0),
    exclude([P]>>memberchk(P, [normal, compact]), Parts0, Parts1),
    atomic_list_concat(Parts1, '_', Base),
    camel_snake(Base, Name0),
    ( Name0 == '' -> Name = lrml ; Name = Name0 ).

%!  twin_migration(+File, +Options, -Migration) is det.
%
%   Options: name(N), source_copy(Base), wording([Iri-Template]) (the
%   reviewer's wording of relations), scenarios([scenario(Name, Facts,
%   Opts)]) with Facts in the document's own vocabulary (`hasLicence(bob)`)
%   and Opts date(Y-M-D), alternative(Key), comment(Text).
twin_migration(File, Options, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    read_lrml(File, Model),
    ( option(name(Name), Options) -> true ; twin_name(File, Name) ),
    ( option(source_copy(Copy), Options) -> true ; file_base_name(File, Copy) ),
    option(wording(Wording), Options, []),
    option(scenarios(Scenarios0), Options, []),
    maplist(scenario_term, Scenarios0, Scenarios),
    twin_ir(Model, Wording, Name, ir(Header0, Items0, Info)),
    %  the tests: SPINdle on the source, per scenario; else the document's
    %  own scenario blocks (an exported LE program's), with no expectations
    maplist(scenario_test(Model, Info), Scenarios, Tests0, Outcomes),
    (   Tests0 == [] -> document_scenarios(Model, Info, Tests) ; Tests = Tests0 ),
    format(string(C0), "The Logical English twin of a LegalRuleML document, written by the LegalRuleML translator~nfrom ~w (kept in sources/).~nObligations, permissions and prohibitions are the deontic library's (deontic.le).~nEvery expected answer in the scenarios is SPINdle's (defeasible deontic logic) on the source.", [Copy]),
    Header = [comment(C0)|Header0],
    atomic_list_concat(['sources/', Copy], CopyRel),
    drop_unused_templates(Items0, Tests, Items1, Dropped),
    Items = [document('the source document', [text(CopyRel)])|Items1],
    ledger(Model, Info, Outcomes, Ledger0),
    maplist(ledger_dropped(Dropped), Ledger0, Ledger1),
    option(ledger_notes(LNotes), Options, []),
    maplist(ledger_note(LNotes), Ledger1, Ledger),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    Meta = [program(Name), source('a LegalRuleML document (OASIS LegalRuleML Core 1.0)'), artifacts([Copy]),
            translator('LE2 migration/legalruleml (lrml_twin.pl)'), date(Date)].

%   The `scenario-<name>` blocks of a document (lrml_export.pl's), as
%   scenarios with their facts: LegalRuleML has no expectations to carry.
document_scenarios(Model, info(Sigs, _, _, _), Tests) :-
    Model = model(Is),
    b_setval(lrml_sigs, Sigs),
    findall(N, ( member(group(G, _), Is), atom_concat('scenario-', N, G) ), Ns),
    findall(test(N, none, none, Facts, []),
            ( member(N, Ns),
              findall(F, ( member(statement(S, _, _, rule(_, _, Then, _)), Is), scenario_statement(Model, S, N),
                           heads(ctx(Model, _), Then, Hs), member(F-true, Hs) ), Facts) ), Tests).

%   A scenario's facts in the model's terms: hasLicence(bob) -> lit(hasLicence, [bob]).
scenario_term(scenario(N, Fs, Os0), scenario(N, Ls, Os)) :-
    maplist([F, lit(Iri, Vs)]>>( F =.. [Iri|Vs0], maplist(fact_value, Vs0, Vs) ), Fs, Ls),
    maplist([O0, O]>>( O0 = date(Y-M-D) -> O = date(date(Y, M, D)) ; O = O0 ), Os0, Os).

fact_value(Y-M-D, date(Y, M, D)) :- integer(Y), !.
fact_value(V, V).

		 /*******************************
		 *         MODEL -> IR          *
		 *******************************/

%   ir(Header, Items, Info); Info holds what the tests and the ledger need:
%   sigs(Sigs), heads(Kinds), notes(Notes), rules(RuleEntries).
twin_ir(Model, Wording, Name, ir(Header, Items, info(Sigs, Queries, Notes, Entries))) :-
    Model = model(Is),
    nb_setval(lrml_notes, []),
    derived_relations(Model, Derived),
    b_setval(lrml_derived, Derived),
    signatures(Model, Wording, Sigs),
    b_setval(lrml_sigs, Sigs),
    %  sources: documents of the program
    findall(document(DN, [url(U)]),
            ( member(source(K, U0), Is), used_source(Model, K), source_doc_name(K, DN), expand_curie(Is, U0, U) ), Docs0),
    list_to_set(Docs0, Docs),
    %  the rules of each statement, then the reparations no rule concludes
    findall(S, ( member(statement(S, _, _, _), Is), \+ scenario_statement(Model, S, _) ), Stmts),
    foldl(statement_rules(Model), Stmts, [], RevR),
    reverse(RevR, Rules0),
    findall(RK, ( member(reparation(RK, _, _), Is),
                  \+ ( member(statement(_, _, _, rule(_, _, T, _)), Is), sub_term(X, T), X == reparation(RK) ) ), FreeReps),
    foldl(free_reparation_rules(Model), FreeReps, [], RevP),
    reverse(RevP, Rules1),
    append(Rules0, Rules1, Rules2),
    exceptions(Model, Rules2, Rules30),
    applies_rules(Rules30, Rules3),
    maplist([r(S, K, H, B, O0, A), C]>>( exclude([Opt]>>( Opt = names(_) ; Opt = exceptions(_) ), O0, O1), copy_term(r(S, K, H, B, O1, A), C) ),
            Rules3, Rules),                                % each rule its own variables
    %  templates: the document's relations, then the library's and the twin's own
    findall(template(F/N, Text, []), ( member(sig(_, _, F/N, Text, T), Sigs), T \= _-same_as, T \= _-library ), Ts1),
    findall(template(F/N, Text, []), ( twin_template(F/N, Text), used_functor(Rules, F/N) ), Ts2),
    library_templates(LibTs),
    findall(rule(H, B, O), ( member(r(_, K, H, B, O, _), Rules), K \== defeater ), RuleItems0),
    maplist(fact_or_rule, RuleItems0, RuleItems),
    findall(comment(C), ( member(r(S, defeater, _, _, O, _), Rules), \+ memberchk(r(S, applies, _, _, _, _), Rules),
                         memberchk(comment(C), O) ), DefeaterComments),
    queries(Rules, Sigs, Queries),
    findall(query(QN, Q), member(q(QN, Q, _), Queries), QItems),
    metadata_comment(Model, MetaComments),
    %  a relation the rules read that nothing concludes is a fact of the case
    %  (a permission no statement grants, the violation of a statement the
    %  document lacks, a function it names without defining): `; undefined`
    case_fact_functors(RuleItems, CaseFacts),
    maplist(mark_case_fact(CaseFacts), Ts1, Ts1u),
    maplist(mark_case_fact(CaseFacts), Ts2, Ts2u),
    maplist(mark_case_fact(CaseFacts), LibTs, LibTsu),
    findall(F/N, ( member(r(_, defeater, H, _, _, _), Rules), callable(H), functor(H, F, N) ), DefHeads),
    nb_setval(lrml_defeater_heads, DefHeads),
    append([Ts1u, Ts2u, LibTsu, Docs, MetaComments, RuleItems, DefeaterComments, QItems], Items),
    Header = [kb(Name), target(prolog), includes([deontic])],
    nb_getval(lrml_notes, Notes0), reverse(Notes0, Notes),
    findall(e(S, Kind, Label), ( member(r(S, Kind, _, _, O, _), Rules), Kind \== applies,
                                 ( memberchk(label(Label), O) -> true ; Label = none ) ), Entries).

note(N) :- nb_getval(lrml_notes, Ns), nb_setval(lrml_notes, [N|Ns]).

%   The relations the twin's rules read (in a condition, or inside the
%   sentence a deontic condition is about) that no rule, no fact and no rule
%   of the deontic library concludes: the facts of a case, which only a
%   scenario states.
case_fact_functors(RuleItems, CaseFacts) :-
    findall(F/N, ( ( member(rule(H, _, _), RuleItems) ; member(fact(H, _), RuleItems) ),
                   callable(H), functor(H, F, N) ), C0),
    append(C0, [obligation_violated/2, prohibition_violated/2, complies_with/2, is_in_breach/1], C1),
    sort(C1, Concluded),
    findall(F/N, ( member(rule(_, B, _), RuleItems), sub_term(T, B), callable(T), functor(T, F, N) ), R0),
    sort(R0, Read),
    ord_subtract(Read, Concluded, CaseFacts).

%   A template of a fact of the case is marked `; undefined` (a scenario
%   element); one the library declares is declared again, so marked, by the
%   twin, which the library's other users are not bound by.
mark_case_fact(CaseFacts, template(F/N, Text, Opts), template(F/N, Text, Opts1)) :-
    (   memberchk(F/N, CaseFacts), \+ memberchk(undefined, Opts)
    ->  (   memberchk(included, Opts) -> Opts1 = [undefined] ; Opts1 = [undefined|Opts] )
    ;   Opts1 = Opts
    ).

%   The templates something the twin writes uses — a rule, a fact, a query or
%   a scenario, as itself or inside a sentence — and those it drops: a
%   relation that occurs only in what the twin leaves out (the conclusion of
%   a defeater, which concludes nothing; a statement it could not read) has
%   no sentence to declare. The library's templates are the library's.
drop_unused_templates(Items0, Tests, Items, Dropped) :-
    findall(F/N, ( member(I, Items0), \+ I = template(_, _, _), \+ I = comment(_), \+ I = document(_, _),
                   sub_term(T, I), callable(T), functor(T, F, N) ), U0),
    findall(F/N, ( member(test(_, _, _, Facts, _), Tests), sub_term(T, Facts), callable(T), functor(T, F, N) ), U1),
    append(U0, U1, U2), sort(U2, Used),
    findall(I, ( member(I, Items0), \+ unused_template(Used, I) ), Items),
    findall(FN-Text, ( member(I, Items0), unused_template(Used, I), I = template(FN, Text, _) ), Dropped).

unused_template(Used, template(FN, _, O)) :-
    \+ memberchk(included, O),
    \+ memberchk(FN, Used).

%   The ledger of a relation that got no template says why.
ledger_dropped(Dropped, entry(E, relation, _, _, T, N), entry(E, relation, V, M, In, N)) :-
    member(F/Ar-Text, Dropped), string(T), atom_string(Text, T), !,
    nb_getval(lrml_defeater_heads, DH),
    (   memberchk(F/Ar, DH)
    ->  V = encoded, In = none,
        M = 'Rel -> no template: it occurs only as the conclusion of a defeater, which concludes nothing (its rule is an exception of the rules it attacks)'
    ;   V = residue, In = none,
        M = 'Rel -> no template: it occurs only in what the twin leaves out (a statement the translator could not read; see its entry)'
    ).
ledger_dropped(_, E, E).

%   A reviewer's note (corpus.pl, `ledger_notes([Element-Note])`) on the
%   ledger entry of that source element.
ledger_note(Notes, entry(E, K, V, M, T, N0), entry(E, K, V, M, T, N)) :-
    (   member(E0-Note, Notes), atom_string(E0, S), atom_string(E, S)
    ->  ( N0 == none -> N = Note ; N = N0 )
    ;   N = N0
    ).

%   The relations a rule concludes (as itself or negated). The others are
%   the facts of a case, and a case states them all: one not stated is
%   false, so its Neg is `it is not the case that` (SPINdle's reading: the
%   closed world of the case, lrml_spindle.pl).
derived_relations(model(Is), Derived) :-
    findall(Iri, ( member(statement(_, _, _, rule(_, _, T, _)), Is), concluded(T, Iri) ), D1),
    findall(Iri, ( member(penalty(_, Ds), Is), member(D, Ds), concluded(D, Iri) ), D2),
    append(D1, D2, D0), sort(D0, Derived).

concluded(atom(rel(Iri, _), _), Iri).
concluded(neg(F), Iri) :- concluded(F, Iri).
concluded(and(Fs), Iri) :- member(F, Fs), concluded(F, Iri).
concluded(suborder(Fs), Iri) :- member(F, Fs), concluded(F, Iri).

derived(Iri) :- b_getval(lrml_derived, Ds), memberchk(Iri, Ds).

fact_or_rule(rule(H, true, O), fact(H, O1)) :- !, exclude([X]>>( X = label(_) ; X = provenance(_) ; X = comment(_) ), O, O1).
fact_or_rule(R, R).

used_source(model(Is), K) :-
    member(assoc(_, _, Ps), Is), memberchk(source(K), Ps), !.
used_source(_, _).

source_doc_name(K, DN) :- camel_snake(K, DN0), ( DN0 == '' -> DN = source ; DN = DN0 ).

%   A CURIE of the document's prefixes (`UScode:title17-...`) made an IRI.
expand_curie(Is, U0, U) :-
    (   sub_atom(U0, B, 1, _, ':'), sub_atom(U0, 0, B, _, Pre), member(prefix(Pre, I), Is)
    ->  B1 is B + 1, sub_atom(U0, B1, _, 0, Local), atom_concat(I, Local, U)
    ;   U = U0
    ).

metadata_comment(model(Is), Items) :-
    findall(S, ( member(authority(K, I), Is), format(string(S), "authority ~w: ~w", [K, I]) ), As),
    findall(S, ( member(jurisdiction(K, I), Is), format(string(S), "jurisdiction ~w: ~w", [K, I]) ), Js),
    findall(S, member(comment(S), Is), Cs),
    append([Cs, As, Js], All),
    (   All == [] -> Items = []
    ;   atomic_list_concat(All, '\n', T), Items = [comment(T)]
    ).

		 /*******************************
		 *           WORDING            *
		 *******************************/

%   sig(Iri, Arity, F/N, TemplateText, Types): one per relation of the
%   document (a negated one gets its own, `not_F`).
signatures(model(Is), Wording, Sigs) :-
    findall(Iri/N-As, ( member(I, Is), sub_term(A, I), nonvar(A), A = atom(rel(Iri, _), As0), Iri \== none,
                        \+ builtin_relation(Iri, _), length(As0, N), As = As0 ), Occ0),
    findall(Iri/N-Text, ( member(I, Is), sub_term(A, I), nonvar(A), A = atom(rel(Iri, Text), As0), Iri \== none, Text \== '',
                          length(As0, N) ), Texts),
    findall(Iri/N, member(Iri/N-_, Occ0), Keys0), sort(Keys0, Keys),
    findall(Iri/N, ( member(I, Is), sub_term(X, I), nonvar(X), X = neg(atom(rel(Iri, _), As)), length(As, N),
                     ( derived(Iri) -> true ; sub_term(D, I), nonvar(D), D = deontic(_, _, F), sub_term(Y, F), Y == X ) ), Negs0),
    sort(Negs0, Negs),
    foldl(signature(Occ0, Texts, Wording, Negs), Keys, [], Rev),
    reverse(Rev, Sigs00), append(Sigs00, Sigs0),
    same_wording_same_relation(Sigs0, Sigs1),
    %  a function the document names without defining it: a relation
    %  between its arguments and its value
    findall(F/N-As, ( member(I, Is), sub_term(E, I), nonvar(E), E = expr(F, As), \+ arithmetic(F), length(As, N) ), Fs0),
    sort(Fs0, Fs),
    findall(sig(fun(F), N1, FF/N1, Text, Types-naive),
            ( member(F/N-As, Fs), N1 is N + 1, camel_snake(F, FF0), atom_concat(value_, FF0, FF),
              place_types([As], N, Types0), places([number|Types0], [S0|Ss]),
              atom_codes(F, Cs), camel_words(Cs, Ws), atomic_list_concat(Ws, ' ', W),
              atomic_list_concat(Ss, ' and ', SA), format(string(Text), "~w is ~w ~w", [S0, W, SA]),
              Types = [number|Types0] ), FSigs),
    append(Sigs1, FSigs, Sigs).

arithmetic(F) :- arithmetic_op(F, _).

%   RuleML's function names, and RIF's (func:numeric-add), as lrml_export.pl writes them.
arithmetic_op(F, Op) :-
    memberchk(F-Op, [subtract-(-), add-(+), multiply-(*), divide-(/),
                     'numeric-subtract'-(-), 'numeric-add'-(+), 'numeric-multiply'-(*), 'numeric-divide'-(/)]).

signature(Occ, Texts, Wording, Negs, Iri/N, Acc, [Ss|Acc]) :-
    findall(As, member(Iri/N-As, Occ), AllAs),
    place_types(AllAs, N, Types),
    camel_snake(Iri, F0), ( F0 == '' -> F = relation ; F = F0 ),
    (   member(Iri-T0, Wording) -> atom_string(T0, Text), Source = reviewer
    ;   memberchk(Iri/N-Text0, Texts), atom_string(Text0, Text), library_template(LF/N, Text)
    ->  Source = library, F1 = LF
    ;   memberchk(Iri/N-Text0, Texts), sub_atom(Text0, _, _, _, '*') -> atom_string(Text0, Text), Source = document
    ;   N =:= 0, memberchk(Iri/N-Text0, Texts)
    ->  atom_string(Text0, Text), Source = document          % a proposition: its words
    ;   memberchk(Iri/N-Text0, Texts)
    ->  atom_codes(Text0, Cs), phrase_words(Cs, Ws), Source = document,
        naive_template(Ws, Types, as_written, Text)
    ;   atom_codes(Iri, Cs), camel_words(Cs, Ws), Source = naive,
        naive_template(Ws, Types, conjugate, Text)
    ),
    ( var(F1) -> F1 = F ; true ),
    S1 = sig(Iri, N, F1/N, Text, Types-Source),
    (   memberchk(Iri/N, Negs)
    ->  negative_text(Text, NText), atom_concat(not_, F, NF),
        Ss = [S1, sig(neg(Iri), N, NF/N, NText, Types-Source)]
    ;   Ss = [S1]
    ).

%   Two relations the reviewer words alike are one (17 USC 504's
%   claimStatutoryDamages and its misspelling claimStatutoryDamanges): the
%   later takes the earlier's functor, and its template is not repeated.
same_wording_same_relation(Sigs0, Sigs) :-
    foldl(merge_sig, Sigs0, [], Rev), reverse(Rev, Sigs).

merge_sig(sig(K, N, _/N, Text, T), Acc, [sig(K, N, F/N, Text, T-same_as)|Acc]) :-
    member(sig(_, N, F/N, Text, _), Acc), !.
merge_sig(S, Acc, [S|Acc]).

%   A wording's words: commas are `or` (`use, distribute, publish` ->
%   `uses or distributes or publishes`, the first person's verbs made third).
phrase_words(Cs, Ws) :-
    atom_codes(A, Cs), atomic_list_concat(Parts0, ',', A),
    maplist([P, W]>>normalize_space(atom(W), P), Parts0, Parts),
    exclude(==(''), Parts, Parts1),
    (   Parts1 = [_, _|_]
    ->  maplist([P, V]>>( atomic_list_concat([W0|Rest], ' ', P), third_person(W0, W1), atomic_list_concat([W1|Rest], ' ', V) ), Parts1, Vs),
        atomic_list_concat(Vs, ' or ', J), atomic_list_concat(Ws, ' ', J)
    ;   Parts1 = [P1] -> atomic_list_concat(Ws, ' ', P1)
    ;   Ws = [holds]
    ).

%   The type of each place: a Var's type (`lovo:copyrightOwner` -> copyright
%   owner), else an informative Var name (income, year), else what its
%   values are (a number, a date), else `thing`.
place_types(AllAs, N, Types) :-
    numlist_(1, N, Is),
    maplist(place_type(AllAs), Is, Types).

numlist_(L, H, []) :- L > H, !.
numlist_(L, H, [L|T]) :- L1 is L + 1, numlist_(L1, H, T).

place_type(AllAs, I, Type) :-
    findall(A, ( member(As, AllAs), nth1(I, As, A) ), Args),
    (   member(var(_, T), Args), T \== none -> type_words(T, Type)
    ;   member(var(V, _), Args), informative(V) -> type_words(V, Type)
    ;   member(slot(SN, _), Args) -> type_words(SN, Type)
    ;   member(A, Args), arg_value(A, X), number(X) -> Type = number
    ;   member(A, Args), arg_value(A, X), X = date(_, _, _) -> Type = date
    ;   Type = thing
    ).

informative(V) :- atom_length(V, L), L > 2, \+ sub_atom(V, 0, _, _, '_').

type_words(T, W) :- atom_codes(T, Cs), camel_words(Cs, Ws), atomic_list_concat(Ws, ' ', W).

%   The naive template (§5.7): the first place is the subject, the words
%   the verb phrase (a verb made third person: engage -> engages), the other
%   places after it; a lone noun is `is a <noun>`.
naive_template(Ws0, Types, How, Text) :-
    length(Types, N),
    places(Types, Slots),
    (   N =:= 0
    ->  ( Ws0 = [_] -> append(Ws0, [holds], Ws) ; Ws = Ws0 ), atomic_list_concat(Ws, ' ', Text0)
    ;   N =:= 2, How == conjugate, Ws0 = [W], noun_like(W)
    ->  Slots = [S1, S2], atomic_list_concat([the, W, of, S1, is, S2], ' ', Text0)
    ;   ( How == conjugate -> verb_phrase(Ws0, N, VP) ; as_written_phrase(Ws0, N, VP) ),
        Slots = [S1|More],
        (   More == [] -> atomic_list_concat([S1|VP], ' ', Text0)
        ;   More = [S2|Rest],
            findall(X, ( member(S, Rest), member(X, [and, S]) ), Tail),
            (   %  a number after a verb and its object: `pays *a number* penalty units`
                Types = [_, number|_], VP = [V, _|_], \+ memberchk(V, [is, has, does])
            ->  VP = [V|Obj], append([[S1, V, S2], Obj, Tail], All)
            ;   append([[S1], VP, [S2], Tail], All)
            ),
            atomic_list_concat(All, ' ', Text0)
        )
    ),
    atom_string(Text0, Text).

%   A wording the document gives is kept as written (an `is` phrase gets
%   its preposition before a second place).
as_written_phrase([is|Ws], N, VP) :- !, verb_phrase([is|Ws], N, VP).
as_written_phrase(Ws, _, Ws).

noun_like(W) :- member(Suffix, [ment, tion, sion, ance, ence, ity, ness, ship, age, ure]), sub_atom(W, _, _, 0, Suffix), !.

verb_phrase([W], 1, [is, Art, W]) :- \+ adjective_like(W), \+ verb_like(W), !, article(W, Art).
verb_phrase([W], 1, [is, W]) :- adjective_like(W), !.
verb_phrase([W|Ws], _, [is, W|Ws]) :- sub_atom(W, _, _, 0, ed), !.     % earned -> is earned
verb_phrase([is|Ws], N, VP) :- !, append([is|Ws], Prep, VP), ( N > 1, \+ ( last(Ws, L), preposition(L) ) -> preposition_after(Ws, Prep) ; Prep = [] ).
verb_phrase([has|Ws], _, [has|Ws]) :- !.
verb_phrase([not|Ws], N, [does, not|VP]) :- !, verb_phrase_base(Ws, N, VP).
verb_phrase([W|Ws], _, [W1|Ws]) :- third_person(W, W1).

verb_phrase_base(Ws, _, Ws).

preposition_after(Ws, [to]) :- last(Ws, equal), !.
preposition_after(_, [of]).

preposition(W) :- memberchk(W, [of, to, in, on, at, for, with, from, by, than, as, about]).

article(W, an) :- sub_atom(W, 0, 1, _, C), memberchk(C, [a, e, i, o, u]), !.
article(_, a).

adjective_like(W) :- member(Suffix, [ful, less, ous, able, ible, al, ive, ic, ed, ing, ent, ant, ish]), sub_atom(W, _, _, 0, Suffix), !.
verb_like(W) :- sub_atom(W, _, 1, 0, s), \+ ( member(E, [ss, us, is, os, as]), sub_atom(W, _, _, 0, E) ), atom_length(W, L), L > 3.

third_person(W, W) :- verb_like(W), !.
third_person(have, has) :- !.
third_person(be, is) :- !.
third_person(do, does) :- !.
third_person(W, W1) :- ( member(E, [s, sh, ch, x, z, o]), sub_atom(W, _, _, 0, E) ), !, atom_concat(W, es, W1).
third_person(W, W1) :- sub_atom(W, B, 1, 0, y), B > 0, sub_atom(W, _, 1, 1, C), \+ memberchk(C, [a, e, i, o, u]), !,
    sub_atom(W, 0, B, _, S), atom_concat(S, ies, W1).
third_person(W, W1) :- atom_concat(W, s, W1).

places(Types, Slots) :-
    foldl([T, C0-Acc, C-[S|Acc]]>>( ( select(T-K0, C0, C1) -> K is K0 + 1 ; K = 1, C1 = C0 ),
                                    C = [T-K|C1],
                                    ordinal_type(K, T, OT), article_phrase(OT, S) ),
          Types, []-[], _-Rev),
    reverse(Rev, Slots).

ordinal_type(1, T, T) :- !.
ordinal_type(K, T, OT) :- nth1(K, [first, second, third, fourth, fifth, sixth], O), !, format(atom(OT), '~w ~w', [O, T]).
ordinal_type(K, T, OT) :- format(atom(OT), '~w ~w', [T, K]).

article_phrase(T, S) :- article(T, A), format(atom(S), '*~w ~w*', [A, T]).

%   `*a thing* is a person` -> `*a thing* is not a person`; otherwise
%   `it is false that ...`.
negative_text(Text, NText) :-
    (   sub_string(Text, B, _, A, "* is "), \+ sub_string(Text, _, _, _, " is not ")
    ->  sub_string(Text, 0, B, _, Pre), sub_string(Text, _, A, 0, Post),
        string_concat(Pre, "* is not ", P1), string_concat(P1, Post, NText)
    ;   string_concat("it is false that ", Text, NText)
    ).

%   The twin's own templates (beside the library's).
twin_template(relevant_date/1, "the relevant date is *a date*").
twin_template(interpretation_adopted/1, "the interpretation adopted is *an interpretation*").
twin_template(statement_violated/1, "the statement *a statement* is violated").
twin_template(statement_applies/1, "the statement *a statement* applies").

library_template(F, Text) :- library_templates(Ts), member(template(F, T, _), Ts), string(T), T == Text, !.
library_template(F, Text) :- library_templates(Ts), member(template(F, T0, _), Ts), atom_string(T0, T), T == Text.

library_templates([
    template(is_obliged_that/2, "*a party* is obliged that *a sentence*", [included]),
    template(is_permitted_that/2, "*a party* is permitted that *a sentence*", [included]),
    template(is_forbidden_that/2, "*a party* is forbidden that *a sentence*", [included]),
    template(obligation_violated/2, "the obligation of *a party* that *a sentence* is violated", [included]),
    template(prohibition_violated/2, "the prohibition of *a party* that *a sentence* is violated", [included]),
    template(complies_with/2, "*a party* complies with the obligation that *a sentence*", [included]),
    template(is_in_breach/1, "*a party* is in breach", [included])
  ]).

kind_functor(obligation, is_obliged_that).
kind_functor(prohibition, is_forbidden_that).
kind_functor(permission, is_permitted_that).
kind_functor(right, is_permitted_that).

violation_functor(obligation, obligation_violated).
violation_functor(prohibition, prohibition_violated).

used_functor(Rules, F/N) :- member(r(_, _, H, B, _, _), Rules), sub_term(T, H-B), callable(T), functor(T, F, N), !.

		 /*******************************
		 *          STATEMENTS          *
		 *******************************/

%   r(Statement, Kind, Head, Body, Options, Applicability): Kind strict,
%   defeasible or defeater; Applicability the conditions under which the
%   rule applies (its body with its period and alternative), which an
%   exception negates.
statement_rules(Model, S, Acc0, Acc) :-
    (   statement_rules_(Model, S, Acc0, Acc1) -> Acc = Acc1
    ;   note(untranslated(S)), Acc = Acc0
    ).

statement_rules_(Model, S, Acc0, Acc) :-
    Model = model(Is),
    memberchk(statement(S, SKind, _, rule(_, If, Then, Para)), Is),
    statement_strength(Model, S, Strength),
    ( SKind == factual -> Kind = strict ; Kind = Strength ),
    Ctx = ctx(Model, VM),                    % the variables by name, an open list
    body_ir(Ctx, If, B0),
    guards(Model, S, G),
    conj(B0, G, B1),
    heads(Ctx, Then, Heads),
    rule_options(Model, S, Para, Opts00),
    Opts0 = [names(VM)|Opts00],             % (until the exceptions are made)
    (   Kind == defeater
    ->  %  a defeater concludes nothing: it is an exception of the rules it attacks
        format(string(C), "defeater ~w: an exception of the rules whose conclusion it attacks", [S]),
        ( Heads = [H0-_|_] -> true ; H0 = none ),
        Acc = [r(S, defeater, H0, B1, [comment(C)|Opts0], B1)|Acc0]
    ;   label_heads(S, Heads, B1, Opts0, Kind, Rs),
        reverse(Rs, RRs), append(RRs, Acc0, Acc)
    ).

%   Each head's rule applies when its body and its chain's conditions hold
%   (its applicability, what an exception negates).
label_heads(S, Heads, B, Opts0, Kind, Rs) :-
    length(Heads, N),
    findall(r(S, Kind, H, BB, [label(L)|Opts], BB),
            ( nth1(I, Heads, H-Extra), conj(B, Extra, BB),
              rule_label(S, I, N, L), ( I =:= 1 -> Opts = Opts0 ; exclude([X]>>(X = comment(_)), Opts0, Opts) ) ), Rs).

rule_label(S, I, N, L) :-
    camel_snake(S, S1),
    ( N =:= 1 -> L = S1 ; format(atom(L), '~w_~w', [S1, I]) ).

rule_options(Model, S, Para, Opts) :-
    statement_sources(Model, S, Srcs),
    findall(DN, ( member(source(K, _), Srcs), source_doc_name(K, DN) ), DNs),
    forall(member(missing(K), Srcs), note(missing_source(S, K))),
    ( DNs = [D|_] -> O1 = [provenance([as_stated_in(D)])] ; O1 = [] ),
    ( Para \== '' -> O2 = [comment(Para)] ; O2 = [] ),
    append(O1, O2, Opts).

%   The reparations no rule concludes: their penalty on the violation alone.
free_reparation_rules(Model, RK, Acc0, Acc) :-
    Ctx = ctx(Model, VM),
    Model = model(Is),
    memberchk(reparation(RK, Pen, PS), Is),
    reparation_heads(Ctx, RK, Heads),
    ( Heads == [] -> note(empty_reparation(RK)) ; true ),
    guards(Model, PS, G),
    rule_options(Model, Pen, '', Opts00),
    Opts0 = [names(VM)|Opts00],
    format(string(C), "reparation ~w: the penalty ~w for a violation of ~w", [RK, Pen, PS]),
    label_heads(RK, Heads, G, [comment(C)|Opts0], defeasible, Rs),
    reverse(Rs, RRs), append(RRs, Acc0, Acc).

%   The period of the relevant date, and the interpretation adopted.
guards(Model, S, G) :-
    (   statement_period(Model, S, Start, End)
    ->  D = _,
        G1 = relevant_date(D),
        ( Start == none -> G2 = G1 ; G2 = and(G1, le_le(Start, D)) ),
        ( End == none -> GP = G2 ; GP = and(G2, le_lt(D, End)) )
    ;   GP = true
    ),
    (   statement_alternatives(Model, S, _, _)
    ->  camel_snake(S, SA), conj(GP, interpretation_adopted(SA), G)
    ;   G = GP
    ).

conj(true, B, B) :- !.
conj(A, true, A) :- !.
conj(A, B, C) :- conj_list(B, Bs), foldl([X, Y0, Y]>>(Y = and(Y0, X)), Bs, A, C).

conj_list(and(A, B), L) :- !, conj_list(A, LA), conj_list(B, LB), append(LA, LB, L).
conj_list(true, []) :- !.
conj_list(G, [G]).

list_conj([], true).
list_conj([G|Gs], C) :- foldl([X, Y0, Y]>>(Y = and(Y0, X)), Gs, G, C).

		 /*******************************
		 *     FORMULAS -> IR BODIES    *
		 *******************************/

body_ir(_, true, true) :- !.
body_ir(Ctx, and(Fs), B) :- !,
    maplist(body_ir(Ctx), Fs, Bs0), exclude(==(true), Bs0, Bs1),
    foldl([X, L0, L]>>( conj_list(X, XL), append(L0, XL, L) ), Bs1, [], Bs),
    list_conj(Bs, B).
body_ir(Ctx, or(Fs), B) :- !,
    maplist(body_ir(Ctx), Fs, [B0|Bs]),
    foldl([X, Y0, Y]>>(Y = or(Y0, X)), Bs, B0, B).
body_ir(Ctx, naf(F), not(B)) :- !, body_ir(Ctx, F, B).
body_ir(Ctx, neg(atom(Rel, As)), B) :-          % a fact of the case not stated: false
    Rel = rel(Iri, _), \+ derived(Iri), !,
    atom_ir(Ctx, pos, Rel, As, Pre, L), conj(Pre, not(L), B).
body_ir(Ctx, neg(atom(Rel, As)), B) :- !, atom_ir(Ctx, neg, Rel, As, Pre, L), conj(Pre, L, B).
body_ir(Ctx, atom(Rel, As), B) :- !, atom_ir(Ctx, pos, Rel, As, Pre, L), conj(Pre, L, B).
body_ir(Ctx, deontic(K, B0, S), B) :- !,
    ( deontic_lit(Ctx, K, B0, S, Pre, L) -> conj(Pre, L, B) ; note(empty_deontic(S)), B = true ).
body_ir(Ctx, violation(S), B) :- !, violation_ir(Ctx, S, B).
body_ir(Ctx, compliance(S), B) :- !,
    violation_ir(Ctx, S, V),
    ( V = obligation_violated(P, X) -> B = complies_with(P, X) ; B = not(V) ).
body_ir(_, F, true) :- note(unsupported_condition(F)).

%   The violation of a statement's deontic conclusions (the variables of
%   that statement shared by name).
violation_ir(Ctx, S, B) :-
    Ctx = ctx(Model, _),
    Model = model(Is),
    (   memberchk(statement(S, _, _, rule(_, _, Then, _)), Is),
        heads(Ctx, Then, Hs),
        foldl([H-_, A0, A]>>( head_violation(H, V) -> A = [V|A0] ; A = A0 ), Hs, [], Vs0),
        reverse(Vs0, [V1|Vs])
    ->  foldl([X, Y0, Y]>>(Y = or(Y0, X)), Vs, V1, B)
    ;   camel_snake(S, SS), note(missing_statement(S)), B = statement_violated(SS)
    ).

head_violation(H, V) :-
    H =.. [F, P, X], kind_functor(K, F), violation_functor(K, VF), V =.. [VF, P, X].

atom_ir(_, _, none, _, _, _) :- !, note(atom_without_relation), fail.
atom_ir(Ctx, pos, rel(Iri, _), [A, B], Pre, L) :-            % a comparison or an assignment
    builtin_relation(Iri, Op), !,
    expr_ir(Ctx, A, X, P1), expr_ir(Ctx, B, Y, P2), append(P1, P2, Pres), list_conj(Pres, Pre),
    L =.. [Op, X, Y].


atom_ir(Ctx, Sign, rel(Iri, _), As, Pre, L) :-
    length(As, N),
    b_getval(lrml_sigs, Sigs),
    ( Sign == neg -> Key = neg(Iri) ; Key = Iri ),
    memberchk(sig(Key, N, F/N, _, _), Sigs),
    args_ir(Ctx, As, Vs, Pres),
    list_conj(Pres, Pre),
    L =.. [F|Vs].

%   An operand of a comparison: arithmetic stays an expression (X is Y + 1).
expr_ir(Ctx, expr(F, [A, B]), E, Pre) :- arithmetic_op(F, Op), !,
    expr_ir(Ctx, A, X, P1), expr_ir(Ctx, B, Y, P2), append(P1, P2, Pre), E =.. [Op, X, Y].
expr_ir(Ctx, A, V, Pre) :- arg_ir(Ctx, A, V, Pre).

args_ir(_, [], [], []).
args_ir(Ctx, [A|As], [V|Vs], Pres) :-
    arg_ir(Ctx, A, V, P),
    args_ir(Ctx, As, Vs, Ps),
    append(P, Ps, Pres).

arg_ir(ctx(_, VM), var(N, _), V, []) :- !, memberchk(N-V, VM).
arg_ir(Ctx, slot(_, A), V, P) :- !, arg_ir(Ctx, A, V, P).
arg_ir(Ctx, sentence(F), V, []) :- !,
    (   F = deontic(K, B, S) -> deontic_lit(Ctx, K, B, S, _, V) ; sentence_ir(Ctx, F, V, _) ).
arg_ir(Ctx, expr(F, As), V, Pre) :- !,
    args_ir(Ctx, As, Vs, P0),
    (   arithmetic_op(F, Op), Vs = [X, Y]
    ->  E =.. [Op, X, Y], append(P0, [V is E], Pre)
    ;   note(function(F)),
        b_getval(lrml_sigs, Sigs), length(Vs, N), N1 is N + 1,
        memberchk(sig(fun(F), N1, FF/N1, _, _), Sigs),
        append(Vs, [V], Args), L =.. [FF|Args], append(P0, [L], Pre)
    ).
arg_ir(Ctx, list(As), L, Pre) :- !, args_ir(Ctx, As, L, Pre).
arg_ir(_, A, V, []) :- arg_value(A, V).

deontic_lit(Ctx, K, B0, S, Pre, L) :-
    S \== true,
    deontic_bearer(B0, S, BA),
    arg_ir(Ctx, BA, P, Pre0),
    sentence_ir(Ctx, S, X, Pre1),
    kind_functor(K, F), L =.. [F, P, X],
    append(Pre0, Pre1, Pres), list_conj(Pres, Pre).

sentence_ir(Ctx, atom(Rel, As), L, Pres) :- atom_ir(Ctx, pos, Rel, As, Pre, L), conj_list(Pre, Pres).
sentence_ir(Ctx, neg(atom(Rel, As)), L, Pres) :- atom_ir(Ctx, neg, Rel, As, Pre, L), conj_list(Pre, Pres).

		 /*******************************
		 *            HEADS             *
		 *******************************/

%   [Head-ExtraConditions]: a SuborderList's elements after the first hold
%   once the one before is violated; a Reparation is its penalty's chain on
%   the violation of the statement it repairs.
heads(Ctx, Then, Heads) :-
    (   Then = suborder(Ds) -> chain(Ctx, Ds, true, Heads)
    ;   Then = and(Fs) -> maplist(heads(Ctx), Fs, Hss), append(Hss, Heads)
    ;   Then = reparation(RK) -> reparation_heads(Ctx, RK, Heads)
    ;   Then = deontic(K, B, S) -> ( deontic_lit(Ctx, K, B, S, Pre, L) -> Heads = [L-Pre] ; note(empty_deontic(Then)), Heads = [] )
    ;   Then = atom(Rel, As) -> atom_ir(Ctx, pos, Rel, As, Pre, L), Heads = [L-Pre]
    ;   Then = neg(atom(Rel, As)) -> atom_ir(Ctx, neg, Rel, As, Pre, L), Heads = [L-Pre]
    ;   Then == true -> Heads = []
    ;   note(unsupported_conclusion(Then)), Heads = []
    ).

chain(_, [], _, []).
chain(Ctx, [D0|Ds], Extra, Heads) :-
    (   D0 = and(Parts), select(D, Parts, Conds0), D = deontic(_, _, _)
    ->  body_ir(Ctx, and(Conds0), Conds)
    ;   D = D0, Conds = true
    ),
    conj(Extra, Conds, Extra1),
    (   D = deontic(K, B, S), deontic_lit(Ctx, K, B, S, Pre, L)
    ->  conj(Extra1, Pre, E2),
        Heads = [L-E2|Hs],
        (   head_violation(L, V) -> conj(Extra, V, Extra2), chain(Ctx, Ds, Extra2, Hs)
        ;   Ds \== [] -> note(chain_after_permission(D)), Hs = []
        ;   Hs = []
        )
    ;   note(unsupported_conclusion(D)), Heads = []
    ).

reparation_heads(Ctx, RK, Heads) :-
    Ctx = ctx(model(Is), _),
    (   memberchk(reparation(RK, Pen, PS), Is),
        memberchk(penalty(Pen, Ds), Is),
        violation_ir(Ctx, PS, V), V \= statement_violated(_)
    ->  chain(Ctx, Ds, V, Heads)
    ;   note(missing_reparation(RK)), Heads = []
    ).

		 /*******************************
		 *   DEFEASIBILITY AS CONDITIONS  *
		 *******************************/

%   A rule overridden by another, or attacked by one with a conflicting
%   conclusion and no order between them, or by a defeater, holds only when
%   the other's conditions do not (E2's convention: `unless`, written as
%   `it is not the case that`). Strict rules are not attacked.
exceptions(Model, Rules0, Rules) :-
    Model = model(Is),
    findall(O-U, ( member(override(O0, U0), Is), model_statement(Model, O0, O), model_statement(Model, U0, U) ), Ord0),
    sort(Ord0, Ord),
    forall(( member(override(O0, U0), Is), ( \+ model_statement(Model, O0, _) ; \+ model_statement(Model, U0, _) ) ),
           note(missing_override(O0, U0))),
    maplist(rule_exceptions(Ord, Rules0), Rules0, Rules1),
    exclude([r(_, defeater, _, _, _, _)]>>true, Rules1, Rules2),
    findall(r(S, defeater, H, B, O, C), member(r(S, defeater, H, B, O, C), Rules0), Defs),
    append(Rules2, Defs, Rules).

rule_exceptions(_, _, R, R) :- R = r(_, defeater, _, _, _, _), !.
rule_exceptions(Ord, All, r(S, K, H, B, O, App), r(S, K, H, B1, [exceptions(Exs)|O], App)) :-
    %  (no findall: the exceptions share the attacked rule's variables)
    ( memberchk(names(VM), O) -> true ; VM = [] ),
    foldl(attacker_exception(Ord, S, K, H, VM), All, [], Exs0),
    reverse(Exs0, Exs1),
    list_to_set_variant(Exs1, Exs),
    foldl([E, B0, B2]>>conj(B0, not(E), B2), Exs, B, B1).

attacker_exception(Ord, S, K, H, VM, r(S2, K2, H2, _, O2, App2), Exs0, Exs) :-
    (   S2 \== S, attacks(Ord, S, K, H, S2, K2, H2)
    ->  (   ground(H2-App2)
        ->  statement_label(S2, O2, L2), Ex = statement_applies(L2)
        ;   ( memberchk(names(VM2), O2) -> true ; VM2 = [] ),
            exception(H, VM, H2, App2, VM2, Ex)
        ),
        Exs = [Ex|Exs0]
    ;   Exs = Exs0
    ).

statement_label(S, O, L) :- ( memberchk(label(L), O) -> true ; rule_label(S, 1, 1, L) ).

%   An attacker about particular individuals (the OASIS examples' x and y)
%   is named where it is an exception — `it is not the case that the
%   statement ps2_1 applies` — and its applicability said once, after its
%   own rule: `the statement ps2_1 applies if …`. One with variables keeps
%   its conditions in the exception: they speak of the attacked rule's case.
applies_rules(Rules0, Rules) :-
    findall(L, ( member(r(_, K, _, B, _, _), Rules0), K \== defeater,
                 sub_term(X, B), nonvar(X), X = statement_applies(L) ), Ls0),
    sort(Ls0, Ls),
    foldl(with_applies(Ls), Rules0, [], Rev),
    reverse(Rev, Rules).

with_applies(Ls, R, Acc0, Acc) :-
    R = r(S, K, _, _, O, App),
    (   statement_label(S, O, L), memberchk(L, Ls), \+ memberchk(r(_, applies, statement_applies(L), _, _, _), Acc0)
    ->  (   K == defeater
        ->  format(string(C), "defeater ~w: it concludes nothing; the rules whose conclusion it attacks do not apply when it does", [S])
        ;   format(string(C), "when ~w applies, the rules it overrides or attacks do not", [L])
        ),
        A = r(S, applies, statement_applies(L), App, [comment(C)], App),
        (   K == defeater
        ->  Acc = [R, A|Acc0]
        ;   %  its own rule says it once: when it applies, and is not defeated
            ( memberchk(exceptions(Exs), O) -> true ; Exs = [] ),
            foldl([E, B0, B1]>>conj(B0, not(E), B1), Exs, statement_applies(L), Body),
            R = r(S, K, H, _, O, App), R1 = r(S, K, H, Body, O, App),
            Acc = [R1, A|Acc0]
        )
    ;   Acc = [R|Acc0]
    ).

%   A strict rule is never attacked (a priority is between defeasible
%   rules); a defeasible one by the rules that override it, and by those
%   with a conflicting conclusion that are not strict and not below it.
attacks(_, _, strict, _, _, _, _) :- !, fail.
attacks(Ord, S, _, _, S2, _, _) :- memberchk(S2-S, Ord), !.
attacks(Ord, S, _, H, S2, K2, H2) :-
    K2 \== strict,
    \+ memberchk(S-S2, Ord),
    conflict(H, H2).

%   The attacker's conditions, its variables renamed apart, then its
%   conclusion lined up with the attacked one's where they conflict, else
%   its variables shared by name with the attacked rule's (an Override
%   between rules whose conclusions do not conflict: the same case).
exception(H, VM, H2, App2, VM2, Ex) :-
    copy_term(H2-App2-VM2, H2c-Ex-VM2c),
    (   conflict(H, H2c) -> unify_conflict(H, H2c)
    ;   vm_pairs(VM2c, Ps), maplist(share_name(VM), Ps)
    ).

share_name(VM, N-V) :- ( vm_lookup(VM, N, V0) -> V = V0 ; true ).

%   The closed part of an open list of Name-Var.
vm_pairs(VM, []) :- var(VM), !.
vm_pairs([P|T], [P|Ps]) :- vm_pairs(T, Ps).

vm_lookup(VM, _, _) :- var(VM), !, fail.
vm_lookup([N0-V0|T], N, V) :- ( N0 == N -> V = V0 ; vm_lookup(T, N, V) ).

conflict(H1, H2) :- nonvar(H1), nonvar(H2), \+ \+ unify_conflict(H1, H2).

unify_conflict(H1, H2) :-
    H1 =.. [F1|A1], H2 =.. [F2|A2],
    complementary(F1, F2), A1 = A2.

complementary(is_forbidden_that, is_permitted_that).
complementary(is_permitted_that, is_forbidden_that).
complementary(is_obliged_that, is_forbidden_that).
complementary(is_forbidden_that, is_obliged_that).
complementary(F, NF) :- atom(F), atom_concat(not_, F, NF).
complementary(NF, F) :- atom(NF), atom_concat(not_, F, NF).

list_to_set_variant([], []).
list_to_set_variant([X|Xs], [X|Ys]) :- exclude(=@=(X), Xs, Xs1), list_to_set_variant(Xs1, Ys).

		 /*******************************
		 *           QUERIES            *
		 *******************************/

%   q(Name, Goal, Pattern): one per kind of conclusion — obligations,
%   permissions, prohibitions, their violations, and each relation a rule
%   concludes.
queries(Rules, Sigs, Queries) :-
    findall(F/N, ( member(r(_, K, H, _, _, _), Rules), K \== defeater, callable(H), functor(H, F, N) ), Fs0),
    sort(Fs0, Fs),
    findall(q(QN, G, F), ( member(F/N, Fs), \+ only_universal_facts(Rules, F/N), query_for(F, N, Sigs, QN, G) ), Qs1),
    (   ( memberchk(is_obliged_that/2, Fs) ; memberchk(is_forbidden_that/2, Fs) )
    ->  Qs2 = [q(breaches, is_in_breach(_), breach)],
        findall(q(QN, G, V), ( member(K-QN, [obligation-violated_obligations, prohibition-violated_prohibitions]),
                               kind_functor(K, KF), memberchk(KF/2, Fs),
                               violation_functor(K, V), G =.. [V, _, _] ), Qs3)
    ;   Qs2 = [], Qs3 = []
    ),
    append([Qs1, Qs3, Qs2], Queries).

%   A relation only facts with a variable conclude (`a person is an
%   infringer`: everything is): its answer is not a list of individuals.
only_universal_facts(Rules, F/N) :-
    forall(( member(r(_, K, H, B, _, _), Rules), K \== defeater, callable(H), functor(H, F, N) ),
           ( B == true, \+ ground(H) )).

query_for(F, 2, _, QN, G) :- kind_functor(K, F), K \== right, !,
    ( K == obligation -> QN = obligations ; K == permission -> QN = permissions ; QN = prohibitions ),
    G =.. [F, _, _].
query_for(F, N, Sigs, QN, G) :-
    memberchk(sig(_, N, F/N, _, _), Sigs),
    functor(G, F, N), QN = F.

		 /*******************************
		 *           THE TESTS          *
		 *******************************/

%   A scenario as a test: its facts, and for each query SPINdle's answers on
%   the source. (Drafted, not stated in the source: no provenance.)
scenario_test(Model, info(Sigs, Queries, _, _), scenario(Name, Facts, Opts),
              test(Name, none, none, Lines, Expects), Name-Outcome) :-
    b_setval(lrml_sigs, Sigs),
    findall(L, ( member(lit(Iri, Vs), Facts), length(Vs, N), memberchk(sig(Iri, N, F/N, _, _), Sigs), L =.. [F|Vs] ), FLines),
    findall(relevant_date(D), member(date(D), Opts), DLines),
    findall(interpretation_adopted(A), ( member(alternative(A0), Opts), camel_snake(A0, A) ), ALines),
    findall(comment(C), member(comment(C), Opts), CLines),
    append([CLines, FLines, DLines, ALines], Lines),
    spindle_conclusions(Model, scenario(Name, Facts, Opts), Concl),
    (   Concl = unavailable(Why)
    ->  findall(pending(Why, expects(QN, [])), member(q(QN, _, _), Queries), Expects),
        Outcome = unavailable(Why)
    ;   findall(expects(QN, As), ( member(q(QN, _, P), Queries), answers(P, Concl, Sigs, As) ), Expects),
        Outcome = ok
    ).

answers(Pattern, Concl, Sigs, As) :-
    findall(A, ( member(C, Concl), conclusion_ir(C, Sigs, A), answer_matches(Pattern, A) ), As0),
    sort(As0, As).

answer_matches(breach, is_in_breach(_)) :- !.
answer_matches(F, A) :- atom(F), functor(A, F, _).

%   SPINdle's conclusion as the twin's ground literal.
conclusion_ir(lit(Iri, Vs), Sigs, L) :- lit_ir(Iri, Vs, Sigs, L).
conclusion_ir(neg(lit(Iri, Vs)), Sigs, L) :- lit_ir(neg(Iri), Vs, Sigs, L).
conclusion_ir(deontic(K, B, S), Sigs, L) :-
    sentence_lit(S, Sigs, X), kind_functor(K, F), L =.. [F, B, X].
conclusion_ir(violated(K, B, S), Sigs, L) :-
    sentence_lit(S, Sigs, X), violation_functor(K, F), L =.. [F, B, X].
conclusion_ir(violated(_, B, _), _, is_in_breach(B)).

sentence_lit(lit(Iri, Vs), Sigs, L) :- lit_ir(Iri, Vs, Sigs, L).
sentence_lit(neg(lit(Iri, Vs)), Sigs, L) :- lit_ir(neg(Iri), Vs, Sigs, L).

lit_ir(Key, Vs, Sigs, L) :- length(Vs, N), memberchk(sig(Key, N, F/N, _, _), Sigs), L =.. [F|Vs].

		 /*******************************
		 *           THE LEDGER         *
		 *******************************/

ledger(Model, info(Sigs, _, Notes, Entries), Outcomes, Ledger) :-
    Model = model(Is),
    findall(entry(E, relation, V, M, T, none),
            ( member(sig(Iri, N, _, T, Src0), Sigs), Iri \= neg(_), Iri \= fun(_),
              ( Src0 = _-same_as -> Src = same_as ; Src0 = _-Src ),
              format(string(E), "Rel ~w/~w", [Iri, N]),
              wording_verdict(Src, V, M) ), L1),
    findall(entry(E, statement, encoded, M, Label, none),
            ( member(e(S, K, Label), Entries), K \== defeater,
              memberchk(statement(S, SK, _, _), Is),
              format(string(E), "~w statement ~w", [SK, S]),
              statement_mapping(SK, M) ), L2a),
    list_to_set(L2a, L2),
    findall(entry(E, defeater, encoded, 'a defeater -> an exception (it is not the case that ...) of the rules it attacks', S, none),
            ( member(e(S, defeater, _), Entries), format(string(E), "defeater ~w", [S]) ), L3),
    findall(entry(E, override, encoded, 'Override -> the under rule holds only when the over rule does not apply (E2)', U, none),
            ( member(override(O, U), Is), model_statement(Model, O, _), model_statement(Model, U, _),
              format(string(E), "Override ~w over ~w", [O, U]) ), L4a),
    list_to_set(L4a, L4),
    findall(entry(E, reparation, encoded, 'Reparation -> the penalty''s chain of obligations on the violation', RK, none),
            ( member(reparation(RK, P, S), Is), format(string(E), "Reparation ~w (~w for ~w)", [RK, P, S]) ), L5),
    findall(entry(E, source, encoded, 'LegalSource -> a document; the rules it is associated with cite it (with provenance)', K, none),
            ( member(source(K, _), Is), format(string(E), "source ~w", [K]) ), L6),
    findall(entry(E, temporal, encoded, 'TemporalCharacteristics -> a period of the relevant date (Starts / Ends)', K, none),
            ( member(temporal(K, _), Is), format(string(E), "temporal ~w", [K]) ), L7),
    findall(entry(E, alternatives, encoded, 'Alternatives -> each alternative''s rules hold when it is the interpretation adopted', K, none),
            ( member(alternatives(K, _), Is), format(string(E), "Alternatives ~w", [K]) ), L8),
    ( memberchk(keys(Keys), Is) -> true ; Keys = [] ),
    findall(entry(E, context, V, M, T, none),
            ( member(assoc(AK, Ts, _), Is), member(T, Ts), expand_targets(Model, T, []),
              format(string(E), "~w -> ~w", [AK, T]),
              (   memberchk(T, Keys)
              ->  V = approximated, M = 'an Association or Context of an element inside a rule (an atom, a deontic formula): LE cites sources per rule, so it is not carried'
              ;   V = residue, M = 'an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing'
              ) ), L11),
    findall(entry(E, K, V, M, W, none), ( member(N, Notes), note_entry(N, E, K, V, M, W) ), L9a),
    list_to_set(L9a, L9),
    findall(entry(E, oracle, approximated, 'no expected answers: SPINdle could not run on the source', N, Why),
            ( member(N-unavailable(Why), Outcomes), format(string(E), "scenario ~w", [N]) ), L10),
    append([L1, L2, L3, L4, L5, L6, L7, L8, L9, L10, L11], Ledger).

wording_verdict(library, encoded, 'Rel -> the deontic library''s relation (deontic.le)').
wording_verdict(same_as, encoded, 'Rel -> the relation the reviewer words the same way (one relation)').
wording_verdict(reviewer, encoded, 'Rel -> a template (the reviewer''s wording)').
wording_verdict(document, encoded, 'Rel -> a template (the wording the document gives the relation)').
wording_verdict(naive, approximated, 'Rel -> a template (a naive wording of its name, to be improved)').

statement_mapping(constitutive, 'ConstitutiveStatement -> an LE rule').
statement_mapping(prescriptive, 'PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le)').
statement_mapping(factual, 'FactualStatement -> a fact').

note_entry(untranslated(S), E, statement, residue, 'a statement the translator could not read (an atom with no relation, a keyref to nothing): left out', S) :-
    format(string(E), "statement ~w", [S]).
note_entry(atom_without_relation, "an Atom with no Rel", atom, residue, 'an Atom with no relation (a keyref the document does not resolve)', none).
note_entry(missing_source(S, K), E, source, approximated, 'an Association names a source the document does not list: no provenance', S) :-
    format(string(E), "source ~w of ~w", [K, S]).
note_entry(missing_statement(S), E, violation, approximated, 'a Violation of a statement the document does not contain -> `the statement ... is violated`, a fact for the scenarios', S) :-
    format(string(E), "Violation of ~w", [S]).
note_entry(missing_override(O, U), E, override, residue, 'an Override naming a rule the document does not contain: dropped', O) :-
    format(string(E), "Override ~w over ~w", [O, U]).
note_entry(missing_reparation(R), E, reparation, residue, 'a Reparation whose penalty or statement is missing: dropped', R) :-
    format(string(E), "Reparation ~w", [R]).
note_entry(empty_reparation(R), E, reparation, approximated, 'a Reparation with nothing to conclude', R) :-
    format(string(E), "Reparation ~w", [R]).
note_entry(empty_deontic(F), E, deontic, approximated, 'a deontic element with no content: nothing to conclude', none) :-
    format(string(E), "~q", [F]).
note_entry(function(F), E, function, approximated, 'a function the document names but does not define -> a relation between its arguments and its value, for the scenarios to state', F) :-
    format(string(E), "Fun ~w", [F]).
note_entry(unsupported_condition(F), E, condition, residue, 'a condition the translator does not map: dropped', none) :-
    format(string(E), "~q", [F]).
note_entry(unsupported_conclusion(F), E, conclusion, residue, 'a conclusion the translator does not map: dropped', none) :-
    format(string(E), "~q", [F]).
note_entry(chain_after_permission(D), E, suborder, approximated, 'a SuborderList continuing after a permission (which cannot be violated): the rest dropped', none) :-
    format(string(E), "~q", [D]).

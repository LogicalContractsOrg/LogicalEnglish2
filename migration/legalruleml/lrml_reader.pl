/** <module> LegalRuleML (OASIS, 2021) read into the model the translator maps

    The front end of the LegalRuleML -> Logical English translator (Phase 2f,
    the design notes roadmap.md §5.8). Either serialisation of the standard,
    compact or normalized, becomes the same model: the normalized form's edge
    elements that only wrap (`hasStatement`, `hasTemplate`, `formula`, `op`,
    `arg`, ...) are dropped first, and the model is read from what is left.

      model(Items)
        prefix(Pre, Iri)
        source(Key, Iri)                 LegalSource, Source, LegalReference
        authority(Key, Iri)  jurisdiction(Key, Iri)
        time(Key, Value)                 Time (an xs:dateTime or xs:date)
        temporal(Key, [tc(Status, Development, Time)])  TemporalCharacteristics
        assoc(Key, Targets, Props)       Association, and a Context (inScope)
                                         Props: source(K), strength(S),
                                         temporal(K), associations(K),
                                         alternatives(K), jurisdiction(K),
                                         authority(K)
        statement(Key, Kind, RuleKey, Rule)   Constitutive / Prescriptive /
                                         Factual (a RuleKey `none` when the
                                         statement holds no ruleml:Rule)
        penalty(Key, Suborder)           PenaltyStatement
        reparation(Key, Penalty, Statement)   Reparation
        override(Over, Under)            Override
        alternatives(Key, [Statement])   Alternatives
        group(Key, [Member])             a keyed Statements block and the
                                         statements (and blocks) in it
        comment(Text)
        keys([Key])                      every key of the document (last)

      Rule     = rule(Strength, If, Then, Paraphrase)
                 Strength: strict | defeasible | defeater | none (not given:
                 see statement_strength/3)
      Formula  = atom(Rel, Args) | and([F]) | or([F]) | naf(F) | neg(F)
               | deontic(Kind, Bearer, F)      Kind: obligation | permission
                                               | prohibition | right
               | suborder([Deontic])
               | violation(Statement) | compliance(Statement)
               | reparation(Key) | true
      Rel      = rel(Iri, Text)        Text: the element's own wording, or ''
      Arg      = var(Name, Type) | ind(Value) | data(Value, XsdType)
               | expr(Fun, [Arg]) | slot(Name, Arg) | sentence(Formula) | list([Arg])
                 (a Reify: a sentence as a value, `says that *a sentence*`)

    A rule or an atom with a `keyref` to another one keyed in the document
    takes from it what it does not restate: the compact serialisation's
    reuse of a template (ex8: a defeater that restates only its `then`).
*/

:- module(lrml_reader, [
    read_lrml/2,                 % +File, -Model
    read_lrml_dom/2,             % +DOM, -Model
    model_statement/3,           % +Model, +KeyOrRuleKey, -Statement
    expand_targets/3,            % +Model, +Key, -Keys
    statement_props/3,           % +Model, +Key, -Props
    statement_sources/3,         % +Model, +Key, -Sources
    statement_strength/3,        % +Model, +Key, -Strength
    statement_period/4,          % +Model, +Key, -Start, -End
    statement_alternatives/4,    % +Model, +Key, -Set, -Others
    scenario_statement/3,        % +Model, +Key, -ScenarioName
    builtin_relation/2,          % +Iri, -Op
    arg_value/2,                 % +Arg, -Value
    deontic_bearer/3,            % +Bearer, +Sentence, -Who
    camel_words/2,               % +Codes, -Words
    camel_snake/2,               % +Name, -snake_name
    value_date/2,                % +Text, -date(Y,M,D)
    local_name/2,
    clean_key/2
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(sgml)).

%!  read_lrml(+File, -Model) is det.
read_lrml(File, Model) :-
    load_xml(File, DOM, [space(remove)]),
    read_lrml_dom(DOM, Model).

%!  read_lrml_dom(+DOM, -Model) is det.
read_lrml_dom(DOM0, model(Items)) :-
    include(is_element, DOM0, [Root0]),
    unwrap(Root0, [Root]),
    keyed_elements(Root, Keyed),
    b_setval(lrml_keyed, Keyed),
    nb_setval(lrml_anonymous, 0),
    element_items(Root, Items0),
    findall(K, member(K-_, Keyed), Ks0), sort(Ks0, Ks),
    append(Items0, [keys(Ks)], Items).

is_element(element(_, _, _)).

%   Element names without their prefix (lrml:, ruleml:).
local_name(N0, N) :- ( sub_atom(N0, B, 1, _, ':') -> B1 is B + 1, sub_atom(N0, B1, _, 0, N) ; N = N0 ).

name_is(element(N0, _, _), N) :- local_name(N0, N).
children(element(_, _, C), Es) :- include(is_element, C, Es).
attr(element(_, A, _), K, V) :- member(K0=V, A), local_name(K0, K), !.
text(element(_, _, C), T) :-
    include(atomic, C, Ts), atomic_list_concat(Ts, ' ', T0), normalize_space(atom(T), T0).

%   `#ps1`, `:ps1` and `ps1` name the same thing.
clean_key(K0, K) :-
    atom_string(K0, S),
    (   ( sub_string(S, 0, 1, _, "#") ; sub_string(S, 0, 1, _, ":") ) -> sub_string(S, 1, _, 0, S1) ; S1 = S ),
    atom_string(K, S1).

key(E, K) :- attr(E, key, K0), clean_key(K0, K).
keyref(E, K) :- attr(E, keyref, K0), clean_key(K0, K).

		 /*******************************
		 *   NORMALIZED -> COMPACT      *
		 *******************************/

%   The normalized serialisation's edges that only wrap their content.
wrapper(N) :- memberchk(N, [hasStatements, hasStatement, hasTemplate, formula, op, arg, strong,
                            hasContext, hasAssociations, hasAssociation, hasLegalSources,
                            hasLegalSource, hasLegalReferences, hasLegalReference,
                            hasSources, hasSource, hasTemporalCharacteristics,
                            hasTemporalCharacteristic, hasAlternatives, hasComment,
                            hasAgents, hasAgent, hasPrefix, hasFigures, hasFigure,
                            hasRoles, hasRole, hasTimes, hasTime, hasJurisdictions,
                            hasJurisdiction, hasAuthorities, hasAuthority, hasParaphrase]).

unwrap(E, Out) :-
    E = element(N0, A, C0), local_name(N0, N),
    foldl(unwrap_child, C0, [], Rev), reverse(Rev, C1), append(C1, C),
    (   wrapper(N) -> Out = C ; Out = [element(N0, A, C)] ).

unwrap_child(X, Acc, [Xs|Acc]) :- ( is_element(X) -> unwrap(X, Xs) ; Xs = [X] ).

%   Every keyed element, for keyrefs.
keyed_elements(Root, Keyed) :-
    findall(K-E, ( sub_element(Root, E), key(E, K) ), Keyed).

sub_element(E, E).
sub_element(E, S) :- children(E, Cs), member(C, Cs), sub_element(C, S).

keyed(K, E) :- b_getval(lrml_keyed, Ks), memberchk(K-E, Ks).

%   A key for an element the document leaves unkeyed, numbered in document
%   order (so both serialisations number alike).
anonymous_key(Prefix, K) :-
    nb_getval(lrml_anonymous, N0), N is N0 + 1, nb_setval(lrml_anonymous, N),
    atom_concat(Prefix, N, K).

		 /*******************************
		 *        THE TOP LEVEL         *
		 *******************************/

element_items(E, Items) :-
    children(E, Cs),
    foldl(top_items, Cs, [], Rev), reverse(Rev, Iss), append(Iss, Items).

top_items(C, Acc, [Is|Acc]) :- ( top_item(C, Is) -> true ; Is = [] ).

top_item(E, Items) :-
    name_is(E, N),
    top_item(N, E, Items).

top_item('Prefix', E, [prefix(P, I)]) :- attr(E, pre, P), attr(E, refID, I).
top_item(Group, E, Items) :-
    memberchk(Group, ['LegalSources', 'Sources', 'LegalReferences', 'References']), !,
    children(E, Cs),
    findall(source(K, I), ( member(C, Cs), source_of(C, K, I) ), Items).
top_item(Group, E, Items) :-
    memberchk(Group-Kind, ['Authorities'-authority, 'Jurisdictions'-jurisdiction]), !,
    children(E, Cs),
    findall(T, ( member(C, Cs), key(C, K), ( attr(C, sameAs, I) -> true ; I = K ), T =.. [Kind, K, I] ), Items).
top_item('Times', E, Items) :-
    children(E, Cs),
    findall(time(K, V), ( member(C, Cs), key(C, K), children(C, [D|_]), text(D, V) ), Items).
top_item('TemporalCharacteristics', E, [temporal(K, TCs)]) :-
    ( key(E, K) -> true ; K = temporal ),
    children(E, Cs),
    findall(TC, ( member(C, Cs), temporal_characteristic(C, TC) ), TCs).
top_item('Associations', E, Items) :-
    ( key(E, GK) -> true ; GK = none ),
    children(E, Cs),
    findall(A, ( member(C, Cs), association(C, A) ), As),
    findall(K, member(assoc(K, _, _), As), Ks),
    (   GK == none -> Items = As ; Items = [group(GK, Ks)|As] ).
top_item('Association', E, [A]) :- association(E, A).
top_item('Context', E, [assoc(K, Targets, Props)]) :-
    ( key(E, K) -> true ; K = context ),
    children(E, Cs),
    findall(T, ( member(C, Cs), name_is(C, inScope), keyref(C, T) ), Targets),
    findall(P, ( member(C, Cs), assoc_prop(C, P) ), Props).
top_item('Statements', E, Items) :-
    element_items(E, Items0),
    (   key(E, K)
    ->  findall(M, ( member(I, Items0), member_key(I, M) ), Ms),
        Items = [group(K, Ms)|Items0]
    ;   Items = Items0
    ).
top_item('Comment', E, [comment(T)]) :- text(E, T).
top_item('Alternatives', E, [alternatives(K, Ss)]) :-
    ( key(E, K) -> true ; K = alternatives ),
    children(E, Cs),
    findall(S, ( member(C, Cs), name_is(C, hasAlternative), keyref(C, S) ), Ss).
top_item(Q, E, Items) :-
    memberchk(Q, [hasQualification, 'OverrideStatement']), !,
    children(E, Cs),
    findall(override(O, U), ( member(C, Cs), name_is(C, 'Override'),
                              attr(C, over, O0), attr(C, under, U0),
                              clean_key(O0, O), clean_key(U0, U) ), Items).
top_item('ReparationStatement', E, Items) :-
    children(E, Cs),
    findall(R, ( member(C, Cs), name_is(C, 'Reparation'), reparation(C, R) ), Items).
top_item('PenaltyStatement', E, [penalty(K, Suborder)]) :-
    ( key(E, K) -> true ; K = penalty ),
    children(E, Cs),
    findall(D, ( member(C, Cs), formula(C, F), ( F = suborder(L) -> member(D, L) ; D = F ) ), Suborder).
top_item(N, E, [statement(K, Kind, RK, Rule)]) :-
    memberchk(N-Kind, ['ConstitutiveStatement'-constitutive, 'PrescriptiveStatement'-prescriptive,
                       'FactualStatement'-factual]), !,
    ( key(E, K) -> true ; anonymous_key(statement_, K) ),
    children(E, Cs),
    (   member(R, Cs), name_is(R, 'Rule')
    ->  ( key(R, RK) -> true ; RK = none ),
        rule(R, Rule)
    ;   RK = none,
        findall(F, ( member(C, Cs), formula(C, F), F \== true ), Fs),
        ( Fs = [F1] -> Then = F1 ; Then = and(Fs) ),
        Rule = rule(none, true, Then, '')
    ).

member_key(statement(K, _, _, _), K).
member_key(penalty(K, _), K).
member_key(group(K, _), K).
member_key(reparation(K, _, _), K).

source_of(C, K, I) :-
    ( key(C, K) -> true ; attr(C, refersTo, K0) -> clean_key(K0, K) ),
    (   attr(C, sameAs, I) -> true
    ;   attr(C, refID, I) -> true
    ;   I = K
    ).

temporal_characteristic(C, tc(Status, Dev, Time)) :-
    name_is(C, 'TemporalCharacteristic'),
    children(C, Gs),
    ( member(G1, Gs), name_is(G1, forStatus), attr(G1, iri, I1) -> iri_local(I1, Status) ; Status = inForce ),
    ( member(G2, Gs), name_is(G2, hasStatusDevelopment), attr(G2, iri, I2) -> iri_local(I2, Dev) ; Dev = 'Starts' ),
    (   member(G3, Gs), name_is(G3, atTime)
    ->  (   keyref(G3, TK) -> Time = ref(TK)
        ;   children(G3, [T|_]) -> ( children(T, [D|_]) -> text(D, Time) ; text(T, Time) )
        ;   text(G3, Time)
        )
    ;   Time = none
    ).

association(E, assoc(K, Targets, Props)) :-
    name_is(E, 'Association'),
    ( key(E, K) -> true ; anonymous_key(association_, K) ),
    children(E, Cs),
    findall(T, ( member(C, Cs), name_is(C, toTarget), keyref(C, T) ), Targets),
    findall(P, ( member(C, Cs), assoc_prop(C, P) ), Props).

assoc_prop(C, P) :-
    name_is(C, N),
    (   memberchk(N-F, [appliesSource-source, appliesTemporalCharacteristics-temporal,
                        appliesAssociations-associations, appliesAssociation-associations,
                        appliesAlternatives-alternatives, appliesJurisdiction-jurisdiction,
                        appliesAuthority-authority]),
        keyref(C, K)
    ->  P =.. [F, K]
    ;   N == appliesStrength
    ->  (   attr(C, iri, I) -> iri_local(I, S0), strength_word(S0, S)
        ;   children(C, [SE|_]), name_is(SE, SN), strength_element(SN, S)
        ),
        P = strength(S)
    ;   N == appliesModality, attr(C, iri, I), iri_local(I, M), P = modality(M)
    ).

reparation(E, reparation(K, P, S)) :-
    ( key(E, K) -> true ; anonymous_key(reparation_, K) ),
    children(E, Cs),
    member(C1, Cs), name_is(C1, appliesPenalty), keyref(C1, P),
    member(C2, Cs), name_is(C2, toPrescriptiveStatement), keyref(C2, S), !.

%   The local part of an IRI or CURIE: `lovo:isWork` -> isWork,
%   `http://...#defeasible1` -> defeasible1.
iri_local(I, L) :-
    atom_string(I, S),
    split_string(S, "#:/", "", Ps0), exclude(==(""), Ps0, Ps),
    ( last(Ps, L0) -> atom_string(L, L0) ; L = I ).

		 /*******************************
		 *            RULES             *
		 *******************************/

rule(E, rule(Strength, If, Then, Para)) :-
    children(E, Cs),
    (   keyref(E, Ref), keyed(Ref, Base), Base \== E -> rule(Base, rule(S0, If0, Then0, P0)) ; S0 = none, If0 = true, Then0 = true, P0 = '' ),
    (   attr(E, strength, SA) -> strength_word(SA, Strength)
    ;   member(H, Cs), name_is(H, hasStrength), children(H, [SE|_]), name_is(SE, SN) -> strength_element(SN, Strength)
    ;   Strength = S0                        % none: the document does not say
    ),
    (   member(I, Cs), name_is(I, if), children(I, [IF|_]) -> formula(IF, If) ; If = If0 ),
    (   member(T, Cs), name_is(T, then), children(T, [TF|_]) -> formula(TF, Then) ; Then = Then0 ),
    (   member(P, Cs), name_is(P, 'Paraphrase') -> all_text(P, Para) ; Para = P0 ).

%   An element's text with its descendants' (a Paraphrase may hold markup).
all_text(E, T) :-
    findall(X, ( sub_text(E, X) ), Xs), atomic_list_concat(Xs, ' ', T0), normalize_space(atom(T), T0).

sub_text(element(_, _, C), X) :- member(Y, C), ( atomic(Y) -> X = Y ; sub_text(Y, X) ).

strength_word(W, S) :-
    downcase_atom(W, L),
    (   sub_atom(L, 0, _, _, defeater) -> S = defeater
    ;   sub_atom(L, 0, _, _, strict) -> S = strict
    ;   S = defeasible
    ).

strength_element('Defeater', defeater) :- !.
strength_element('StrictStrength', strict) :- !.
strength_element(_, defeasible).

%!  formula(+Element, -Formula) is det.
formula(E, F) :-
    name_is(E, N),
    (   formula(N, E, F0) -> F = F0 ; F = true ).

formula('Atom', E, F) :- atom_formula(E, F).
formula('And', E, and(Fs)) :- children(E, Cs), maplist(formula, Cs, Fs).
formula('Or', E, or(Fs)) :- children(E, Cs), maplist(formula, Cs, Fs).
formula('Naf', E, naf(G)) :- children(E, [C|_]), formula(C, G).
%   An existential inside a condition (the exporter scopes a Naf's own
%   variables with one): its variables are local by name already, so it is
%   the formula it quantifies.
formula('Exists', E, G) :- children(E, Cs), member(C, Cs), \+ name_is(C, 'Var'), !, formula(C, G).
formula('Neg', E, neg(G)) :- children(E, [C|_]), formula(C, G).
formula(N, E, deontic(Kind, Bearer, F)) :-
    memberchk(N-Kind, ['Obligation'-obligation, 'Permission'-permission,
                       'Prohibition'-prohibition, 'Right'-right]),
    children(E, Cs),
    (   member(S, Cs), name_is(S, slot), children(S, [B, V|_]), name_is(B, 'Bearer'), term_of(V, Bearer) -> true
    ;   Bearer = none
    ),
    (   member(C, Cs), \+ name_is(C, slot), formula(C, F), F \== true -> true ; F = true ).
formula('SuborderList', E, suborder(Fs)) :- children(E, Cs), maplist(formula, Cs, Fs).
formula('Violation', E, violation(K)) :- keyref(E, K).
formula('Compliance', E, compliance(K)) :- keyref(E, K).
formula('Reparation', E, reparation(K)) :- ( keyref(E, K) -> true ; key(E, K) ).

atom_formula(E, atom(Rel, Args)) :-
    children(E, Cs),
    (   keyref(E, Ref), keyed(Ref, Base), Base \== E -> atom_formula(Base, atom(Rel0, Args0)) ; Rel0 = none, Args0 = [] ),
    (   member(R, Cs), name_is(R, 'Rel') -> rel_of(R, Rel) ; Rel = Rel0 ),
    findall(T, ( member(C, Cs), \+ name_is(C, 'Rel'), term_of(C, T) ), Args1),
    ( Args1 == [] -> Args = Args0 ; Args = Args1 ).

rel_of(R, rel(Iri, Text)) :-
    ( attr(R, iri, Iri0) -> iri_local(Iri0, Iri) ; text(R, Iri0), Iri = Iri0 ),
    ( attr(R, iri, _) -> text(R, Text) ; Text = '' ).

term_of(C, T) :-
    name_is(C, N),
    term_of(N, C, T).

term_of('Var', C, var(V, Type)) :- text(C, V), ( attr(C, type, T0) -> iri_local(T0, Type) ; Type = none ).
term_of('Ind', C, ind(V)) :- text(C, V0), ( V0 == '', attr(C, iri, I) -> iri_local(I, V) ; V = V0 ).
term_of('Data', C, data(V, Type)) :- text(C, V), ( attr(C, type, T0) -> iri_local(T0, Type) ; Type = untyped ).
term_of('Reify', C, sentence(F)) :- children(C, [E|_]), formula(E, F).
term_of('Plex', C, list(Args)) :- children(C, Cs), findall(A, ( member(X, Cs), term_of(X, A) ), Args).
term_of('Expr', C, expr(Fun, Args)) :-
    children(C, Cs),
    ( member(F, Cs), name_is(F, 'Fun') -> ( attr(F, iri, I) -> iri_local(I, Fun) ; text(F, Fun) ) ; Fun = apply ),
    findall(A, ( member(X, Cs), \+ name_is(X, 'Fun'), term_of(X, A) ), Args).
term_of(slot, C, slot(Name, Arg)) :-
    children(C, [K, V|_]),
    \+ name_is(K, 'Bearer'), \+ name_is(K, 'AuxiliaryParty'),
    ( attr(K, iri, I) -> iri_local(I, Name) ; text(K, Name) ),
    term_of(V, Arg).

		 /*******************************
		 *   WHAT THE MODEL SAYS        *
		 *******************************/

%   What a statement is, whichever key names it (its own, or its Rule's:
%   the specification's examples use both in Overrides and Contexts).
model_statement(model(Is), K, S) :-
    (   memberchk(statement(K, _, _, _), Is) -> S = K
    ;   member(statement(S, _, K, _), Is), K \== none -> true
    ).

%!  expand_targets(+Model, +Key, -Keys) is det.
%
%   The statements and penalties a key stands for: itself, or the members of
%   a Statements block (recursively). [] for a key the document lacks.
expand_targets(M, K, Keys) :-
    expand_targets(M, K, [], Keys0), sort(Keys0, Keys).

expand_targets(M, K0, Seen, Keys) :-
    M = model(Is),
    (   memberchk(K0, Seen) -> Keys = []
    ;   model_statement(M, K0, S) -> Keys = [S]
    ;   memberchk(penalty(K0, _), Is) -> Keys = [K0]
    ;   memberchk(group(K0, Ms), Is)
    ->  foldl({M, K0, Seen}/[Mk, A0, A]>>( expand_targets(M, Mk, [K0|Seen], Ks), append(A0, Ks, A) ), Ms, [], Keys)
    ;   Keys = []
    ).

%!  statement_props(+Model, +Key, -Props) is det.
%
%   The properties the document's Associations and Contexts give a statement
%   or penalty: source(Iri), strength(S), temporal(Key), authority(K),
%   jurisdiction(K). A Context that applies an Associations block passes the
%   block's untargeted properties to the Context's own scope.
statement_props(M, K, Props) :-
    M = model(Is),
    findall(P, ( member(assoc(_, Ts, Ps), Is), Ts \== [],
                 member(T, Ts), expand_targets(M, T, Ks), memberchk(K, Ks),
                 ( member(P, Ps) ; member(associations(G), Ps), untargeted_prop(M, G, P) ),
                 \+ P = associations(_) ), Props0),
    list_to_set(Props0, Props).

untargeted_prop(model(Is), G, P) :-
    (   memberchk(group(G, As), Is) -> member(A, As) ; A = G ),
    memberchk(assoc(A, [], Ps), Is), member(P, Ps), \+ P = associations(_).

%   The sources of a statement, as IRIs (a key the document's LegalSources
%   list gives; else the key itself, reported by the caller).
statement_sources(M, K, Sources) :-
    M = model(Is),
    statement_props(M, K, Ps),
    findall(Src, ( member(source(SK), Ps), ( memberchk(source(SK, I), Is) -> Src = source(SK, I) ; Src = missing(SK) ) ), Sources0),
    list_to_set(Sources0, Sources).

%!  statement_strength(+Model, +Key, -Strength) is det.
%
%   A Context's appliesStrength wins over the Rule's own. A rule whose
%   strength the document does not give is defeasible when an Override
%   names it (an Override is "an instance in a defeasible priority
%   relation", the specification's glossary), strict otherwise.
statement_strength(M, K, S) :-
    M = model(Is),
    (   statement_props(M, K, Ps), memberchk(strength(S0), Ps) -> S = S0
    ;   memberchk(statement(K, _, _, rule(S0, _, _, _)), Is), S0 \== none -> S = S0
    ;   member(override(O, U), Is), ( model_statement(M, O, K) ; model_statement(M, U, K) ) -> S = defeasible
    ;   S = strict
    ).

%!  statement_period(+Model, +Key, -Start, -End) is semidet.
%
%   When a statement is in force (efficacious): its temporal
%   characteristics' Starts and Ends, as date(Y,M,D) or `none`. Fails when
%   the statement has none.
statement_period(M, K, Start, End) :-
    M = model(Is),
    statement_props(M, K, Ps), memberchk(temporal(TK), Ps),
    memberchk(temporal(TK, TCs), Is),
    ( member(tc(_, 'Starts', T1), TCs), time_date(Is, T1, Start) -> true ; Start = none ),
    ( member(tc(_, 'Ends', T2), TCs), time_date(Is, T2, End) -> true ; End = none ),
    \+ ( Start == none, End == none ).

time_date(Is, ref(K), D) :- !, memberchk(time(K, V), Is), value_date(V, D).
time_date(_, V, D) :- value_date(V, D).

%   1978-01-01T01:01:00.0Z, 1978-01-01 -> date(1978, 1, 1)
value_date(V, date(Y, M, D)) :-
    atom_string(V, S), sub_string(S, 0, 10, _, DS),
    split_string(DS, "-", "", [YS, MS, DS1]),
    number_string(Y, YS), number_string(M, MS), number_string(D, DS1).

%   A statement of a scenario block (`scenario-<name>`, as lrml_export.pl
%   writes a Logical English program's scenarios): the facts of a case, not
%   of the program.
scenario_statement(model(Is), S, Name) :-
    member(group(G, Ms), Is), atom_concat('scenario-', Name, G), memberchk(S, Ms), !.

%   The Alternatives a statement is one of.
statement_alternatives(model(Is), K, Set, Others) :-
    member(alternatives(Set, Ss), Is), memberchk(K, Ss), !,
    exclude(==(K), Ss, Others).

variable_like(V) :- atom_codes(V, [C|Cs]), code_type(C, upper), forall(member(D, Cs), code_type(D, digit)).

%   RIF's built-ins (pred:numeric-less-than ...), as lrml_export.pl writes
%   LE's comparisons and assignments: the comparison, not a relation.
builtin_relation('numeric-less-than', (<)).
builtin_relation('numeric-less-than-or-equal', (=<)).
builtin_relation('numeric-greater-than', (>)).
builtin_relation('numeric-greater-than-or-equal', (>=)).
builtin_relation('numeric-equal', (is)).
builtin_relation(equal, (=)).
builtin_relation('not-equal', (\=)).
builtin_relation(type, is_a).                      % rdf:type: `alice is a person`

%!  arg_value(+Arg, -Value) is det.
%
%   A constant of the document as Logical English will hold it: a number, a
%   date, a text (xs:string), a list (Plex), or an atom — an Ind's name as it
%   is, except a variable-like one (`X`, `Y1`), which LE would read as a
%   variable: it is written in lower case.
arg_value(ind(V), X) :- !,
    (   atom_number(V, N) -> X = N
    ;   variable_like(V) -> downcase_atom(V, X)        % Ind X: LE would read `X` as a variable
    ;   X = V
    ).

arg_value(data(V, T), X) :- !,
    (   memberchk(T, [date, dateTime]), value_date(V, D) -> X = D
    ;   T == string -> atom_string(V, X)          % xs:string: a text
    ;   text_value(V, X)
    ).
arg_value(list(As), L) :- !, maplist(arg_value, As, L).
arg_value(A, A).

text_value(V, X) :-
    (   atom_number(V, N) -> X = N
    ;   atom_codes(V, Cs), Cs = [C|_], code_type(C, alpha), forall(member(D, Cs), code_type(D, csym))
    ->  camel_snake(V, X)
    ;   X = V
    ).

%   engageCreditActivity -> engage_credit_activity; JohnDoe -> john_doe;
%   P -> p; ABC -> abc.
camel_snake(A, S) :-
    atom_codes(A, Cs),
    camel_words(Cs, Ws),
    atomic_list_concat(Ws, '_', S).

%   Words at the case changes and separators: `payCivilUnits` pay civil
%   units, `ABCDef` abc def.
camel_words(Cs, Ws) :-
    boundaries(Cs, Groups),
    findall(W, ( member(G, Groups), G \== [], atom_codes(W0, G), downcase_atom(W0, W) ), Ws).

boundaries([], [[]]).
boundaries([C|Cs], Gs) :-
    \+ code_type(C, alnum), !,
    boundaries(Cs, Gs0), Gs = [[]|Gs0].
boundaries([C|Cs], [[C|G]|Gs]) :-
    (   Cs = [N|_], split_before(C, N, Cs) -> boundaries(Cs, Gs0), Gs = [[]|Gs0], G = []
    ;   boundaries(Cs, [G|Gs])
    ).

%   A new word starts at N after C: lower then upper (`yC`), or upper then
%   upper followed by lower (`CDe`: D starts `De`).
split_before(C, N, _) :- code_type(N, upper), \+ code_type(C, upper), code_type(C, alnum), !.
split_before(C, N, [N, L|_]) :- code_type(C, upper), code_type(N, upper), code_type(L, lower).

%!  deontic_bearer(+Bearer, +Sentence, -Who) is det.
%
%   Who bears a deontic statement: its Bearer slot, else the first argument
%   of the sentence it is about (the one who must, may or must not act),
%   else `everyone`.
deontic_bearer(B, _, B) :- B \== none, !.
deontic_bearer(none, S, W) :-
    ( S = neg(S1) -> true ; S1 = S ),
    (   S1 = atom(_, [A|_]), A \= slot(_, _) -> W = A ; W = ind(everyone) ).

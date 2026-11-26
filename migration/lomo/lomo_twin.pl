/** <module> A LOMO description -> its register: a Logical English program of facts

    twin_migration(+File, +Options, -Migration)
        Migration = migration(Meta, program(Header, Items), Ledger, Tests)
        for le_migration:write_migration/4. Options:
            name(Name)          the program's name (default: from the file)
            source_copy(Rel)    where the copy of the file is, beside the program
            tests(Tests)        the scenarios (the gate's, build.pl)
            bearer(Role)        addresser (the default) or addressee: the role
                                whose agent bears a duty (lib/lomo.le)

    One fact for each statement of the description, in the words of
    lib/lomo.le (lomo_words.pl). A statement whose property the library has
    no word for is kept whole in the generic form (`... has for "eli-lo:unit"
    the value "EUR"`). Every thing with a web address has its address in a
    fact (`... is identified by "..."`), so that the way back (lomo_export.pl)
    writes the same description again. Nothing is dropped: the ledger lists
    every thing the description describes, the older words of LOMO it uses
    and what was kept in the generic form.

    Copyright Miguel Calejo; Apache License 2.0, as the rest of this
    repository (../../NOTICE). Published "as is".
*/

:- module(lomo_twin, [twin_migration/3, twin_name/2, register_ir/4, question/4, value_term/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(pairs)).
:- use_module(library(semweb/rdf_db), [rdf_is_bnode/1]).
:- use_module(lomo_reader).
:- use_module(lomo_words).
:- use_module(lomo_shacl, [check_file/2]).
:- use_module(lomo_eli, []).

%!  twin_name(+File, -Name) is det.
twin_name(File, Name) :-
    file_base_name(File, B), file_name_extension(Stem, _, B),
    downcase_atom(Stem, L),
    atom_codes(L, Cs), maplist([C, D]>>( code_type(C, alnum) -> D = C ; D = 0'_ ), Cs, Ds0),
    squeeze(Ds0, Ds1),
    ( Ds1 = [D0|_], code_type(D0, digit) -> Ds = [0'l, 0'o, 0'm, 0'o, 0'_|Ds1] ; Ds = Ds1 ),
    atom_codes(Name0, Ds),
    ( sub_atom(Name0, _, 1, 0, '_') -> sub_atom(Name0, 0, _, 1, Name) ; Name = Name0 ).

squeeze([], []).
squeeze([0'_, 0'_|T], R) :- !, squeeze([0'_|T], R).
squeeze([C|T], [C|R]) :- squeeze(T, R).

twin_migration(File, Options, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    read_lomo(File, Model),
    ( option(name(Name), Options) -> true ; twin_name(File, Name) ),
    ( option(source_copy(Copy), Options) -> true ; file_base_name(File, Copy) ),
    option(tests(Tests), Options, []),
    option(bearer(Bearer), Options, addresser),
    register_ir(Model, [bearer(Bearer)|Options], ir(Items0, Used), LedgerInfo),
    format(string(C0),
"The register of a LOMO description: the Logical English twin of~n~w (kept in sources/), written by the LOMO translator.~nOne fact for each statement of the description, in the words of lomo.le.~nLOMO describes rules; it has no conditions and no cases. A question~nabout a case gets its answer only from the parts of the description that~nhave values (deadlines, agents, derogations).~n~nLOMO and its data: (c) European Union, Creative Commons Attribution 4.0~n(https://creativecommons.org/licenses/by/4.0/); source: the LOMO~nrepository, https://code.europa.eu/drpm/lomo. The description was changed~ninto Logical English by the LOMO translator of Logical English.",
           [Copy]),
    Header = [kb(Name), target(prolog), includes([lomo]), comment(C0)],
    atomic_list_concat(['sources/', Copy], CopyRel),
    templates(Used, Templates0),
    option(templates(Own), Options, []),
    findall(template(F, T, Adds), ( member(Tm, Own), ( Tm = template(F, T, Adds) -> true ; Tm = template(F, T), Adds = [] ) ), OwnItems),
    append(Templates0, OwnItems, Templates),
    questions(Used, Queries0),
    option(queries(Extra), Options, []),
    append(Queries0, Extra, Queries),
    (   option(eli_texts(Dir), Options)
    ->  findall(E, member(fact(lomo_established_in(_, E), _), Items0), Es0), sort(Es0, Es),
        include([E]>>( sub_string(E, _, _, _, "/eli/"), lomo_eli:eli_celex(E, _) ), Es, EliEs),
        lomo_eli:write_provision_texts(EliEs, Dir, Docs)
    ;   Docs = []
    ),
    append([Templates, [document('the source description', [text(CopyRel)])|Docs], Items0, Queries], Items),
    ledger(Model, LedgerInfo, Ledger0),
    validity_entries(File, VEs),
    append(Ledger0, VEs, Ledger),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    Meta = [program(Name), source('a LOMO description (Legal Obligation Metadata Ontology 1.1.0, Turtle)'),
            artifacts([Copy]), translator('LE2 migration/lomo (lomo_twin.pl)'), date(Date),
            licence('Creative Commons Attribution 4.0 (the description); the register: the same, as a changed copy')].

%   ---- the facts -------------------------------------------------------

%!  register_ir(+Model, +Options, -IR, -LedgerInfo)
%   IR = ir(Items, UsedFunctors); LedgerInfo = info(PerSubject, Formats)
register_ir(lomo(Sts, Nodes, Prefixes), Options, ir(Items, Used), info(PerSubject, FormatNotes)) :-
    option(bearer(Bearer), Options, addresser),
    subject_order(Sts, Subjects),
    findall(I-N, member(node(I, N, _), Nodes), NameList),
    list_to_assoc_(NameList, Names),
    formats(Sts, Prefixes, FormatFacts, FormatNotes),
    findall(Block, ( member(S, Subjects), subject_block(S, Sts, Names, Prefixes, Nodes, Block) ), Blocks),
    pairs_values(Blocks, BlockItems0),
    append(BlockItems0, BlockItems),
    pairs_keys(Blocks, PerSubject),
    object_only_nodes(Nodes, Subjects, Names, ExtraItems),
    BearerFact = fact(lomo_bearer(Bearer), []),
    append([[comment("Who bears a duty: the agent of this role of the action (lomo.le)."), BearerFact],
            FormatFacts, BlockItems, ExtraItems], Items),
    findall(F/A, ( member(fact(L, _), Items), functor(L, F, A) ), Fs0),
    sort(Fs0, Used).

list_to_assoc_(Pairs, Assoc) :- list_to_assoc(Pairs, Assoc).

subject_order(Sts, Subjects) :-
    findall(S, member(st(S, _, _), Sts), Ss), list_to_set(Ss, Subjects).

name_of(Names, I, N) :- ( get_assoc(I, Names, N) -> true ; atom_string(I, N) ).

%   A block of facts per subject: a comment with its address, then its
%   statements. Blank nodes follow the thing they belong to in the file.
subject_block(S, Sts, Names, Prefixes, Nodes, (S-Facts)-Items) :-
    name_of(Names, S, Name),
    findall(St, ( member(St, Sts), St = st(S, _, _) ), Mine),
    maplist(statement_fact(Names, Prefixes), Mine, Facts),
    (   rdf_is_bnode(S) -> Id = []
    ;   memberchk(node(S, _, IRI), Nodes), IRI \== '-'
    ->  atom_string(IRI, IS), Id = [fact(lomo_iri(Name, IS), [])]
    ;   Id = []
    ),
    findall(fact(L, []), member(L-_, Facts), FactItems),
    append([[blank], Id, FactItems], Items).

%   An address used as the value of a property whose values are things, and
%   that the description does not describe: a name and its address.
object_only_nodes(Nodes, Subjects, Names, Items) :-
    findall(fact(lomo_iri(N, IS), []),
            ( member(node(I, _, IRI), Nodes), IRI \== '-', \+ memberchk(I, Subjects),
              name_of(Names, I, N), atom_string(IRI, IS) ), Facts),
    (   Facts == [] -> Items = []
    ;   Items = [blank, comment("Things the description names but does not describe: their addresses.")|Facts]
    ).

%!  statement_fact(+Names, +Prefixes, +St, -Literal-How)
%   How: lomo(Property) | generic(Property) | older(Property) | class(C) | type(C)
statement_fact(Names, Prefixes, st(S, P, V), L-How) :-
    name_of(Names, S, SN),
    (   rdf_type(P), V = node(C), class_word(C, F, _)
    ->  L =.. [F, SN], ( older_class(C) -> How = older(C) ; How = class(C) )
    ;   rdf_type(P), V = address(C)
    ->  compact_iri(C, Prefixes, CT), L = lomo_has_type(SN, CT), How = type(C)
    ;   property_word(P, F, _, _)
    ->  value_term(Names, V, VT), L =.. [F, SN, VT],
        ( older(P) -> How = older(P) ; How = lomo(P) )
    ;   compact_iri(P, Prefixes, PT),
        value_term(Names, V, VT),
        (   V = lit(_, _, _) -> L = lomo_value(SN, PT, VT)
        ;   L = lomo_resource(SN, PT, VT)
        ),
        ( lomo_ns(NS), atom_concat(NS, _, P) -> How = older(P) ; How = generic(P) )
    ).

rdf_type('http://www.w3.org/1999/02/22-rdf-syntax-ns#type').

value_term(Names, node(I), N) :- !, name_of(Names, I, N).
value_term(_, word(W, _), W) :- !.
value_term(_, address(A), S) :- !, atom_string(A, S).
value_term(_, lit(_, V, _), V).

%   ---- the forms of the literals ---------------------------------------
%   A property whose texts have no language tag, or whose values carry a
%   datatype other than the usual one of their kind, says so once.

formats(Sts, Prefixes, Facts, Notes) :-
    findall(P, member(st(_, P, lit(_, _, _)), Sts), AllPs0), sort(AllPs0, AllPs),
    findall(PFacts-VFacts,
            ( member(P, AllPs),
              findall(F-(V-Form), ( member(st(_, P, lit(K, V, Form)), Sts), form_of(K, V, Form, F) ), FVs),
              findall(F, member(F-_, FVs), Fs), msort(Fs, SFs), clumped(SFs, Cl),
              sort(2, @>=, Cl, [Major-_|_]),
              compact_iri(P, Prefixes, PT),
              (   Major == usual -> PFacts = [] ; format_fact(Major, PT, Prefixes, PF), PFacts = [PF] ),
              %  a value whose form is not its property's: said of the value
              findall(VF, ( member(F-(V-Form), FVs), F \== Major, value_form_fact(Form, V, Prefixes, VF) ), VFacts0),
              sort(VFacts0, VFacts)
            ), PVs),
    findall(F, ( member(Ps-_, PVs), member(F, Ps) ), Facts1),
    findall(F, ( member(_-Vs, PVs), member(F, Vs) ), Facts2),
    append(Facts1, Facts2, Facts0),
    maplist([F0, fact(F0, [])]>>true, Facts0, Facts),
    Notes = [].

form_of(K, V, Form, F) :- ( usual_form(K, V, Form) -> F = usual ; F = Form ).

%   A value whose form differs from its property's usual one.
value_form_fact(plain, V, _, lomo_value_plain(V)) :- !.
value_form_fact(type(T), V, Prefixes, lomo_value_datatype(V, TT)) :- !, compact_iri(T, Prefixes, TT).
value_form_fact(lang(L), V, _, lomo_value_datatype(V, LS)) :- format(string(LS), "@~w", [L]).

form_is_unusual(K, V, Form, Form) :- \+ usual_form(K, V, Form).

usual_form(text, _, lang(en)).
usual_form(value, _, plain).
usual_form(K, _, type(T)) :- memberchk(K, [date, duration, boolean]), literal_datatype(K, T).
usual_form(number, V, type(T)) :- ( integer(V) -> xsd(integer, T) ; xsd(decimal, T) ).
xsd(L, T) :- atom_concat('http://www.w3.org/2001/XMLSchema#', L, T).

format_fact(plain, PT, _, lomo_plain(PT)).
format_fact(lang(L), PT, _, lomo_value(PT, "language", LS)) :- atom_string(L, LS).
format_fact(type(T), PT, Prefixes, lomo_datatype(PT, TT)) :- compact_iri(T, Prefixes, TT).

%   ---- templates -------------------------------------------------------

templates(Used, Items) :-
    findall(F-T, template_text(F, T), All),
    findall(template(F, T, [included]), ( member(F-T, All) ), Items0),
    %  every template of the library: the questions use the derived ones
    Items = Items0,
    Used = Used.

template_text(F, T) :- class_word(_, F, T).
template_text(F, T) :- property_word(_, F, T, _).
template_text(F, T) :- generic_template(_, F, T).
template_text(F, T) :- derived(F, T).

derived(lomo_bearer,           "the bearer role is *a role*").
derived(lomo_part,             "*a thing* is part of the description").
derived(lomo_kind,             "*a thing* is of the kind *a kind*").
derived(lomo_agent_or_type,    "*a thing* is an agent or agent type").
derived(lomo_derogation,       "*a rule* is a derogation from *a second rule*").
derived(lomo_specification,    "*a rule* is a specification of *a second rule*").
derived(lomo_related,          "*a rule* is related to *a second rule*").
derived(lomo_comes_before,     "*an action* comes before *a second action*").
derived(lomo_gives_meaning,    "*a definition* gives the meaning of *a thing*").
derived(lomo_holds,            "*a dataset* holds *a result*").
derived(lomo_same_meaning,     "*a definition* has the same meaning as *a second definition*").
derived(lomo_start_of,         "*a temporal specification* is the start of *a second temporal specification*").
derived(lomo_end_of,           "*a temporal specification* is the end of *a second temporal specification*").
derived(lomo_acts_as,          "*an agent* acts as *a role* in *an action*").
derived(lomo_concerns,         "*a rule* concerns *an agent*").
derived(lomo_spec_as,          "*a thing* has *a temporal specification* as *a function*").
derived(lomo_by_act,           "*a rule* is established by the act *an act*").
derived(lomo_joint,            "*a rule* is established in more than one provision").
derived(lomo_laid_down,        "*a rule* is laid down in *a place*").
derived(lomo_modality_for,     "*a rule* has the modality *a modality* for *an agent* as *a role*").
derived(lomo_triggered_by,     "*a thing* is triggered by *an event*").
derived(lomo_later_than,       "*a temporal specification* is later than *a second temporal specification*").
derived(lomo_earlier_than,     "*a temporal specification* is earlier than *a second temporal specification*").
derived(lomo_during,           "*a temporal specification* is during *a second temporal specification*").
derived(lomo_overlaps_with,    "*a temporal specification* overlaps with *a second temporal specification*").
derived(lomo_happens_on,       "*an event* happens on *a date*").
derived(lomo_calendar_starts,  "the calendar starts on *a date*").
derived(lomo_first_date,       "the first date of *a temporal specification* is *a date*").
derived(lomo_last_date,        "the last date of *a temporal specification* is *a date*").
derived(lomo_breaks_link,      "*a temporal specification* breaks its link with *a second temporal specification*").
derived(lomo_rhythm_starts,    "the rhythm of *a temporal specification* starts on *a date*").
derived(lomo_falls_on,         "*a temporal specification* falls on *a date* in the period from *a first date* to *a last date*").
derived(lomo_due,              "*an agent* has *an action* due on *a date*").
derived(lomo_due_in,           "*an agent* has *an action* due on *a date* in the period from *a first date* to *a last date*").
derived(lomo_hours_as_days,    "*a temporal specification* has a length of time that counts hours as whole days").
derived(lomo_of_type,          "*a party* is of the type *an agent type*").
derived(lomo_counts_as,        "*a party* counts as *an agent*").
derived(lomo_meets_definition, "*a party* meets the definition *a definition*").
derived(lomo_written_conditions, "*a rule* has written conditions").
derived(lomo_no_conditions,    "*a rule* has no written conditions").
derived(lomo_conditions_hold,  "the conditions of *a rule* hold for *a party*").
derived(lomo_reaches,          "*a rule* reaches *a party*").
derived(lomo_set_aside,        "*a rule* is set aside for *a party* by *a second rule*").
derived(lomo_applies,          "*a rule* applies to *a party*").
derived(lomo_performs,         "*a party* performs *an action*").
derived(lomo_performs_on,      "*a party* performs *an action* on *a date*").
derived(lomo_happens_to,       "*an event* happens to *a party* on *a date*").
derived(lomo_first_date_for,   "the first date of *a temporal specification* for *a party* is *a date*").
derived(lomo_last_date_for,    "the last date of *a temporal specification* for *a party* is *a date*").
derived(lomo_must_perform,     "*a party* must perform *an action* by *a date* under *a rule*").
derived(lomo_met,              "*a party* met *an action* under *a rule*").
derived(lomo_late,             "*a party* is late with *an action* under *a rule* on *a day*").
derived(deontic_obliged,       "*a party* is obliged that *a sentence*").
derived(deontic_permitted,     "*a party* is permitted that *a sentence*").
derived(deontic_forbidden,     "*a party* is forbidden that *a sentence*").
derived(deontic_right,         "*a party* has the right that *a sentence*").
derived(deontic_violated,      "the obligation of *a party* that *a sentence* is violated").
derived(lomo_text,             "*a thing* is described by the text *a text*").
derived(lomo_act_of,           "the act of *a provision* is *an act*").
derived(lomo_place_of,         "the place of *a provision* in its act is *a text*").

%   ---- the questions of LOMO's requirements document --------------------
%   question(Name, Block, Body, Needs): a query of the register, the block of
%   the requirements document it answers, and the facts it needs (a query is
%   written only when the register has at least one fact of each).

questions(Used, Items) :-
    findall(query(N, B), ( question(N, _, B, Needs), forall(member(F, Needs), used(F, Used)) ), Items0),
    (   Items0 == [] -> Items = []
    ;   Items = [blank, comment("The questions of LOMO's requirements document (its competency questions),\nas far as a description can answer them.")|Items0]
    ).

used(F, Used) :- memberchk(F/_, Used).

question(parts,             'search', lomo_part(_), []).
question(kinds,             'actions, agents and roles 5', lomo_kind(_, _), []).
question(bearer,            'who is bound', lomo_bearer(_), [lomo_bearer]).
question(rules_of_act,      'legal rules and legal sources 1', lomo_by_act(_, _), [lomo_established_in]).
question(provisions,        'legal rules and legal sources 2', lomo_established_in(_, _), [lomo_established_in]).
question(places,            'legal rules and legal sources 2', lomo_laid_down(_, _), [lomo_established_in]).
question(legal_texts,       'legal rules and legal sources 3', lomo_legal_text(_, _), [lomo_legal_text]).
question(joint_rules,       'legal rules and legal sources 4', lomo_joint(_), [lomo_established_in]).
question(prescriptive,      'legal rules and legal sources 5', lomo_prescriptive_rule(_), []).
question(constitutive,      'legal rules and legal sources 5', lomo_constitutive_rule(_), []).
question(modalities,        'prescriptive rules 1', lomo_modality(_, _), [lomo_modality]).
question(obligations,       'prescriptive rules 2', lomo_modality_for(_, obligation, _, _), [lomo_modality, lomo_produces]).
question(prohibitions,      'prescriptive rules 3', lomo_modality_for(_, prohibition, _, _), [lomo_modality, lomo_produces]).
question(permissions,       'prescriptive rules 4', lomo_modality_for(_, permission, _, _), [lomo_modality, lomo_produces]).
question(rights,            'prescriptive rules 5', lomo_modality_for(_, right, _, _), [lomo_modality, lomo_produces]).
question(requirement_types, 'prescriptive rules 6', lomo_requirement_type(_, _), [lomo_requirement_type]).
question(oversight_rules,   'prescriptive rules 7', lomo_oversight_rule(_), [lomo_oversight_rule]).
question(triggers,          'prescriptive rules 8', lomo_triggered_by(_, _), [lomo_function, lomo_temporal_label]).
question(definitions,       'constitutive rules 1', lomo_definition(_), [lomo_definition]).
question(definienda,        'constitutive rules 2', lomo_definiendum(_, _), [lomo_definiendum]).
question(definientia,       'constitutive rules 2', lomo_definiens(_, _), [lomo_definiens]).
question(semantic_definitions, 'constitutive rules 3', lomo_semantic_definition(_, _), [lomo_semantic_definition]).
question(equivalent_definitions, 'constitutive rules 4', lomo_same_meaning(_, _), [lomo_equivalent_definition]).
question(definitions_used,  'constitutive rules 5', lomo_uses_definition(_, _), [lomo_uses_definition]).
question(defined_things,    'constitutive rules 6', lomo_gives_meaning(_, _), [lomo_defines]).
question(scope_rules,       'constitutive rules 7', lomo_scope_rule(_), [lomo_scope_rule]).
question(institutional_rules, 'constitutive rules 9', lomo_institutional_rule(_), [lomo_institutional_rule]).
question(actions_of_rules,  'actions, agents and roles 1', lomo_produces(_, _), [lomo_produces]).
question(addressers,        'actions, agents and roles 2', lomo_acts_as(_, addresser, _), [lomo_with_role]).
question(addressees,        'actions, agents and roles 3', lomo_acts_as(_, addressee, _), [lomo_with_role]).
question(beneficiaries,     'actions, agents and roles 4', lomo_acts_as(_, beneficiary, _), [lomo_with_role]).
question(identified_agents, 'actions, agents and roles 5', lomo_agent(_), [lomo_agent]).
question(agent_types,       'actions, agents and roles 5', lomo_agent_type(_), [lomo_agent_type]).
question(actions_of_agents, 'actions, agents and roles 6', lomo_acts_as(_, _, _), [lomo_with_role]).
question(concerned_agents,  'actions, agents and roles 7', lomo_concerns(_, _), [lomo_produces, lomo_with_role]).
question(sequence,          'actions, agents and roles 8', lomo_comes_before(_, _), [lomo_has_next]).
question(deadlines,         'temporal specifications 1', lomo_spec_as(_, _, deadline), [lomo_function]).
question(starting_points,   'temporal specifications 2', lomo_spec_as(_, _, 'starting point'), [lomo_function]).
question(validity,          'temporal specifications 3', lomo_spec_as(_, _, validity), [lomo_function]).
question(durations,         'temporal specifications 1', lomo_duration(_, _), [lomo_duration]).
question(instants,          'temporal specifications 1', lomo_instant(_, _), [lomo_instant]).
question(frequencies,       'temporal specifications 5', lomo_frequency(_, _), [lomo_frequency]).
question(repetitions,       'temporal specifications 5', lomo_repetitions(_, _), [lomo_repetitions]).
question(timed_after,       'temporal specifications 6', lomo_after(_, _), [lomo_after]).
question(timed_before,      'temporal specifications 6', lomo_before(_, _), [lomo_before]).
question(timed_immediately_after, 'temporal specifications 6', lomo_immediately_after(_, _), [lomo_immediately_after]).
question(timed_immediately_before, 'temporal specifications 6', lomo_immediately_before(_, _), [lomo_immediately_before]).
question(starts,            'temporal specifications 6', lomo_start_of(_, _), [lomo_starts]).
question(ends,              'temporal specifications 6', lomo_end_of(_, _), [lomo_finishes]).
question(overlaps,          'temporal specifications 6', lomo_overlaps(_, _), [lomo_overlaps]).
question(timed_within,      'temporal specifications 6', lomo_in(_, _), [lomo_in]).
question(first_dates,       'temporal specifications 1', lomo_first_date(_, _), [lomo_temporal_spec]).
question(last_dates,        'temporal specifications 3', lomo_last_date(_, _), [lomo_temporal_spec]).
question(later_times,       'temporal specifications 6', lomo_later_than(_, _), [lomo_temporal_spec]).
question(times_within,      'temporal specifications 6', lomo_during(_, _), [lomo_temporal_spec]).
question(broken_links,      'temporal specifications 6', lomo_breaks_link(_, _), [lomo_temporal_spec]).
question(due_dates,         'temporal specifications 7', lomo_due(_, _, _), [lomo_function]).
question(due_in_2027,       'temporal specifications 7', lomo_due_in(_, _, _, date(2027, 1, 1), date(2027, 12, 31)), [lomo_function]).
question(hours_as_days,     'temporal specifications 1', lomo_hours_as_days(_), [lomo_duration]).
question(rules_without_conditions, 'conditions', lomo_no_conditions(_), []).
question(applies,           'compliance support 1', lomo_applies(_, _), []).
question(set_aside,         'relations among rules 4', lomo_set_aside(_, _, _), [lomo_derogates_from]).
question(must_perform,      'compliance support 1', lomo_must_perform(_, _, _, _), [lomo_function]).
question(obliged,           'prescriptive rules 2', deontic_obliged(_, _), [lomo_modality]).
question(permitted,         'prescriptive rules 4', deontic_permitted(_, _), [lomo_modality]).
question(forbidden,         'prescriptive rules 3', deontic_forbidden(_, _), [lomo_modality]).
question(holders_of_rights, 'prescriptive rules 5', deontic_right(_, _), [lomo_modality]).
question(violations,        'compliance support 1', deontic_violated(_, _), [lomo_modality]).
question(results,           'action results 1', lomo_has_result(_, _), [lomo_has_result]).
question(result_categories, 'action results 3', lomo_result_category(_, _), [lomo_result_category]).
question(datasets_of_results, 'action results 4', lomo_holds(_, _), [lomo_is_manifested_in]).
question(composed_results,  'action results 1', lomo_is_composed_of(_, _), [lomo_is_composed_of]).
question(digital_dimensions,'digital dimensions 1', lomo_category(_, _), [lomo_category]).
question(processes,         'digital dimensions 1', lomo_involves_process(_, _), [lomo_involves_process]).
question(datasets,          'digital dimensions 3', lomo_dataset(_), [lomo_dataset]).
question(standards,         'digital dimensions 3', lomo_conforms_to(_, _), [lomo_conforms_to]).
question(capabilities,      'digital dimensions 4', lomo_capability(_, _), [lomo_capability]).
question(public_services,   'digital dimensions 5', lomo_public_service(_), [lomo_public_service]).
question(assessments,       'digital dimensions 6', lomo_results_in(_, _), [lomo_results_in]).
question(judgements,        'digital dimensions 7', lomo_judgement(_, _), [lomo_judgement]).
question(derogations,       'relations among rules 3', lomo_derogation(_, _), [lomo_derogates_from]).
question(specifications,    'relations among rules 1', lomo_specification(_, _), [lomo_specifies]).
question(related_rules,     'relations among rules 5', lomo_related(_, _), [lomo_relates_to]).
question(references,        'digital dimensions 3', lomo_references(_, _), [lomo_references]).
question(publishers,        'digital dimensions 4', lomo_publisher(_, _), [lomo_publisher]).
question(cited_resources,   'digital dimensions 5', lomo_cites(_, _), [lomo_cites]).
question(statement_types,   'digital dimensions 7', lomo_statement_type(_, _), [lomo_statement_type]).
question(interpretations,   'digital dimensions 6', lomo_interpretation(_, _), [lomo_interpretation]).
question(services_of_statements, 'digital dimensions 7', lomo_related_service(_, _), [lomo_related_service]).
question(schemes,           'word lists', lomo_in_scheme(_, _), [lomo_in_scheme]).
question(broader_concepts,  'word lists', lomo_broader(_, _), [lomo_broader]).
question(texts,             'search', lomo_text(_, _), []).
question(other_values,      'kept in the generic form', lomo_value(_, _, _), [lomo_value]).
question(other_resources,   'kept in the generic form', lomo_resource(_, _, _), [lomo_resource]).
question(other_types,       'kept in the generic form', lomo_has_type(_, _), [lomo_has_type]).
question(addresses,         'the way back', lomo_iri(_, _), [lomo_iri]).
question(older_conditions,  'older words', lomo_has_condition(_, _), [lomo_has_condition]).
question(definition_flags,  'older words', lomo_semantic_definition(_, _), [lomo_semantic_definition]).
question(literal_forms,     'the way back', lomo_datatype(_, _), [lomo_datatype]).
question(plain_texts,       'the way back', lomo_plain(_), [lomo_plain]).

%   ---- the ledger ------------------------------------------------------

%   What the description breaks of LOMO's own validity rules
%   (lomo_shacl.pl): kept as the description has it, and listed.
validity_entries(File, Es) :-
    (   catch(check_file(File, Rs), _, fail)
    ->  findall(entry(F, 'a validity rule of LOMO', encoded, 'kept as the description has it', '-', Msg),
                member(result(F, _, _, _, Msg), Rs), Es1)
    ;   Es1 = []
    ),
    read_lomo(File, lomo(Sts, Nodes, _)),
    findall(entry(V, 'a length of time', approximated, 'kept as text; no date is calculated from it', N, Msg),
            ( member(st(S, _, lit(duration, V, _)), Sts),
              \+ lomo_temporal:le_temporal_iso(V, _),
              ( memberchk(node(S, N, _), Nodes) -> true ; N = '-' ),
              format(string(Msg), "~q is not a length of time in the standard form of ISO 8601 (P1Y, P12M, PT72H): a calendar cannot count with it", [V]) ),
            Es2),
    append(Es1, Es2, Es).

:- prolog_load_context(directory, D),
   atomic_list_concat([D, '/../../lib/temporal.pl'], T),
   lomo_temporal:consult(T).

ledger(lomo(Sts, Nodes, Prefixes), info(PerSubject, FormatNotes), Ledger) :-
    findall(E, ( member(S-Facts, PerSubject), \+ rdf_is_bnode(S),
                 subject_entry(S, Facts, Sts, Nodes, Prefixes, E) ), Es),
    findall(entry(Note, 'literal form', approximated, 'the form of the values of a property', '-', Note),
            member(Note, FormatNotes), Fs),
    append(Es, Fs, Ledger).

subject_entry(S, Facts0, Sts, Nodes, Prefixes, entry(Element, Kind, encoded, Mapping, Name, Note)) :-
    memberchk(node(S, Name, _), Nodes),
    bnode_facts(S, Sts, Nodes, Prefixes, BFacts),
    append(Facts0, BFacts, Facts),
    length(Facts, NF),
    atom_string(S, Element),
    (   findall(C, member(_-class(C), Facts), [C1|_]) -> class_word(C1, _, T), template_class(T, Kind)
    ;   findall(C, member(_-type(C), Facts), [C2|_]) -> compact_iri(C2, Prefixes, Kind)
    ;   Kind = "thing"
    ),
    format(string(Mapping), "~w statement~w, one fact each", [NF, s(NF)]),
    findall(PT, ( member(_-generic(P), Facts), compact_iri(P, Prefixes, PT) ), Gs0), sort(Gs0, Gs),
    findall(PT, ( member(_-older(P), Facts), compact_iri(P, Prefixes, PT) ), Os0), sort(Os0, Os),
    phrase(note(Gs, Os), Parts),
    (   Parts == [] -> Note = "" ; atomic_list_concat(Parts, '; ', Note) ).

s(1, '') :- !.
s(_, s).

note(Gs, Os) --> generic_note(Gs), older_note(Os).
generic_note([]) --> !.
generic_note(Gs) --> { atomic_list_concat(Gs, ', ', L), format(atom(A), "kept in the generic form (no word in lomo.le): ~w", [L]) }, [A].
older_note([]) --> !.
older_note(Os) --> { atomic_list_concat(Os, ', ', L), format(atom(A), "words of LOMO before 1.1.0: ~w", [L]) }, [A].

template_class(T, K) :-
    (   sub_string(T, B, _, 0, " is a ") -> true ; sub_string(T, B, _, _, " is an ") ),
    sub_string(T, B, _, 0, Rest),
    ( string_concat(" is a ", K, Rest) -> true ; string_concat(" is an ", K, Rest) ), !.
template_class(T, T).

%   The facts of the blank nodes of a thing belong to its ledger row.
bnode_facts(S, Sts, Nodes, Prefixes, Facts) :-
    findall(B, ( member(st(S, _, node(B)), Sts), rdf_is_bnode(B) ), Bs0), list_to_set(Bs0, Bs),
    findall(I-N, member(node(I, N, _), Nodes), NL), list_to_assoc(NL, Names),
    findall(F, ( member(B, Bs), member(st(B, P, V), Sts),
                 statement_fact(Names, Prefixes, st(B, P, V), F) ), Own),
    findall(F, ( member(B, Bs), bnode_facts(B, Sts, Nodes, Prefixes, Fs), member(F, Fs) ), Deeper),
    append(Own, Deeper, Facts).

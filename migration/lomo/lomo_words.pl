/** <module> LOMO's words and the templates of lib/lomo.le that hold them

    One table for the reader (Turtle -> register), the writer of the way
    back (register -> Turtle) and the check that lib/lomo.le declares every
    template the table names (test_lomo.pl). LOMO changes (version 2.0 is
    spoken of): a new word is one row here.

    class_word(ClassIRI, Functor, Template)
        rdf:type ClassIRI  ->  `<thing> is a <words>`.
    property_word(PropertyIRI, Functor, Template, Kind)
        Kind: thing    - the value is a thing of the description (a name);
              address  - the value is a web address, kept as a string;
              word     - the value is a term of a LOMO word list (a name),
                         or an address when the term is not in the list;
              text     - a literal string (a language-tagged one too);
              date, number, duration, boolean - a typed literal.
        older(PropertyIRI) marks a word of an earlier version of LOMO that
        1.1.0 no longer declares (the reader accepts it, the ledger says so).
    vocabulary_term(IRI, Word)
        a term of the four word lists of LOMO, or of the authority table of
        roles, written as a word.

    Copyright Miguel Calejo; Apache License 2.0, as the rest of this
    repository (../../NOTICE). Published "as is".
*/

:- module(lomo_words, [
    lomo_ns/1, ns/2,
    class_word/3, property_word/4, older/1, older_class/1,
    vocabulary_term/2, generic_template/3, literal_datatype/2
]).

lomo_ns('http://data.europa.eu/leg/lomo#').

%   The prefixes the reader writes compact IRIs with (a generic statement's
%   property, a class it does not know) and the writer reads them back.
ns(lomo,    'http://data.europa.eu/leg/lomo#').
ns(rdf,     'http://www.w3.org/1999/02/22-rdf-syntax-ns#').
ns(rdfs,    'http://www.w3.org/2000/01/rdf-schema#').
ns(owl,     'http://www.w3.org/2002/07/owl#').
ns(xsd,     'http://www.w3.org/2001/XMLSchema#').
ns(skos,    'http://www.w3.org/2004/02/skos/core#').
ns(dcterms, 'http://purl.org/dc/terms/').
ns(dctype,  'http://purl.org/dc/dcmitype/').
ns(dcat,    'http://www.w3.org/ns/dcat#').
ns(cpsv,    'http://purl.org/vocab/cpsv#').
ns(cav,     'http://data.europa.eu/2sa/cav#').
ns(iopa,    'http://data.europa.eu/2qy/iopa#').
ns(m8g,     'http://data.europa.eu/m8g/').
ns(adms,    'http://www.w3.org/ns/adms#').
ns(eli,     'http://data.europa.eu/eli/ontology#').
ns('eli-lo','http://data.europa.eu/eli-lo/ontology#').
ns(time,    'http://www.w3.org/2006/time#').
ns(tf,      'http://data.europa.eu/leg/temporal-function/').
ns(dm,      'http://data.europa.eu/leg/deontic-modality/').
ns(dd,      'http://data.europa.eu/leg/digital-dimensions/').
ns(rc,      'http://data.europa.eu/leg/result-category/').
ns(role,    'http://publications.europa.eu/resource/authority/role/').

l(Local, IRI) :- lomo_ns(NS), atom_concat(NS, Local, IRI).
q(Prefix, Local, IRI) :- ns(Prefix, NS), atom_concat(NS, Local, IRI).

%   ---- classes --------------------------------------------------------

class_word(IRI, F, T) :- lomo_class(Local, F, T), l(Local, IRI).
class_word(IRI, F, T) :- other_class(P, Local, F, T), q(P, Local, IRI).

lomo_class('LegalRule',                      lomo_legal_rule,        "*a thing* is a legal rule").
lomo_class('PrescriptiveRule',               lomo_prescriptive_rule, "*a thing* is a prescriptive rule").
lomo_class('SubstantiveRule',                lomo_substantive_rule,  "*a thing* is a substantive rule").
lomo_class('ImplementationAndOversightRule', lomo_oversight_rule,    "*a thing* is an implementation and oversight rule").
lomo_class('ConstitutiveRule',               lomo_constitutive_rule, "*a thing* is a constitutive rule").
lomo_class('Definition',                     lomo_definition,        "*a thing* is a definition").
lomo_class('ScopeRule',                      lomo_scope_rule,        "*a thing* is a scope rule").
lomo_class('InstitutionalRule',              lomo_institutional_rule,"*a thing* is an institutional rule").
lomo_class('Action',                         lomo_action,            "*a thing* is an action").
lomo_class('Agent',                          lomo_agent,             "*a thing* is an agent").
lomo_class('AgentType',                      lomo_agent_type,        "*a thing* is an agent type").
lomo_class('AgentRole',                      lomo_agent_role,        "*a thing* is an agent role").
lomo_class('TemporalSpecification',          lomo_temporal_spec,     "*a thing* is a temporal specification").
lomo_class('ActionResult',                   lomo_action_result,     "*a thing* is an action result").
lomo_class('ActionResultType',               lomo_action_result_type,"*a thing* is an action result type").
%  older classes, kept by the data of the repository
lomo_class('LegalCondition',                 lomo_legal_condition,   "*a thing* is a legal condition").
lomo_class('Process',                        lomo_process_class,     "*a thing* is a process").

older_class(IRI) :- member(L, ['LegalCondition', 'Process', 'Frequency', 'IntervalSpec']), l(L, IRI).

other_class(dcat,    'Dataset',       lomo_dataset,        "*a thing* is a dataset").
other_class(dcterms, 'Standard',      lomo_standard,       "*a thing* is a standard").
other_class(dctype,  'Software',      lomo_software,       "*a thing* is a software").
other_class(cpsv,    'PublicService', lomo_public_service, "*a thing* is a public service").
other_class(cav,     'Assessment',    lomo_assessment,     "*a thing* is an assessment").
other_class(cav,     'Statement',     lomo_assessment_statement, "*a thing* is an assessment statement").
other_class(skos,    'Concept',       lomo_concept,        "*a thing* is a concept").
other_class(skos,    'ConceptScheme', lomo_concept_scheme, "*a thing* is a concept scheme").

%   ---- properties -----------------------------------------------------

property_word(IRI, F, T, K) :- lomo_prop(Local, F, T, K), l(Local, IRI).
property_word(IRI, F, T, K) :- other_prop(P, Local, F, T, K), q(P, Local, IRI).

%  rules and their sources
lomo_prop(establishedIn,      lomo_established_in,   "*a thing* is established in *a provision*", address).
lomo_prop(legalText,          lomo_legal_text,       "*a thing* has the legal text *a text*", text).
lomo_prop(hasDeonticModality, lomo_modality,         "*a rule* has the modality *a modality*", word).
lomo_prop(hasRequirementType, lomo_requirement_type, "*a rule* has the requirement type *a requirement type*", word).
lomo_prop(produces,           lomo_produces,         "*a rule* produces *an action*", thing).
lomo_prop(hasCategory,        lomo_category,         "*a rule* has the digital dimension *a dimension*", word).
lomo_prop(involvesProcess,    lomo_involves_process, "*a rule* involves the process *a process*", thing).
lomo_prop(references,         lomo_references,       "*a rule* references *a resource*", thing).
%  rules about rules
lomo_prop(specifies,          lomo_specifies,        "*a rule* specifies *a second rule*", thing).
lomo_prop(isSpecifiedBy,      lomo_is_specified_by,  "*a rule* is specified by *a second rule*", thing).
lomo_prop(derogatesFrom,      lomo_derogates_from,   "*a rule* derogates from *a second rule*", thing).
lomo_prop(isDerogatedBy,      lomo_is_derogated_by,  "*a rule* is derogated by *a second rule*", thing).
lomo_prop(relatesTo,          lomo_relates_to,       "*a rule* relates to *a second rule*", thing).
%  actions, agents, roles
lomo_prop(hasAgentRole,       lomo_agent_role_of,    "*an action* has the agent role *an agent role*", thing).
lomo_prop(forAgent,           lomo_for_agent,        "*an agent role* is for the agent *an agent*", thing).
lomo_prop(withRole,           lomo_with_role,        "*an agent role* has the role *a role*", word).
lomo_prop(hasResult,          lomo_has_result,       "*an action* has the result *a result*", thing).
lomo_prop(hasNext,            lomo_has_next,         "*an action* is followed by *a second action*", thing).
lomo_prop(hasPrevious,        lomo_has_previous,     "*an action* follows *a second action*", thing).
lomo_prop(atTime,             lomo_at_time,          "*a thing* has the time specification *a temporal specification*", thing).
%  time
lomo_prop(hasFunction,        lomo_function,         "*a temporal specification* has the function *a function*", word).
lomo_prop(instant,            lomo_instant,          "*a temporal specification* has the instant *a date*", date).
lomo_prop(duration,           lomo_duration,         "*a temporal specification* has the duration *a duration*", duration).
lomo_prop(frequency,          lomo_frequency,        "*a temporal specification* has the frequency *a duration*", duration).
lomo_prop(repetitions,        lomo_repetitions,      "*a temporal specification* has the number of repetitions *a number*", number).
lomo_prop(temporalLabel,      lomo_temporal_label,   "*a temporal specification* has the temporal label *a text*", text).
lomo_prop(after,              lomo_after,            "*a temporal specification* is timed after *a second temporal specification*", thing).
lomo_prop(before,             lomo_before,           "*a temporal specification* is timed before *a second temporal specification*", thing).
lomo_prop(immediatelyAfter,   lomo_immediately_after,"*a temporal specification* is timed immediately after *a second temporal specification*", thing).
lomo_prop(immediatelyBefore,  lomo_immediately_before,"*a temporal specification* is timed immediately before *a second temporal specification*", thing).
lomo_prop(starts,             lomo_starts,           "*a temporal specification* starts *a second temporal specification*", thing).
lomo_prop(startedBy,          lomo_started_by,       "*a temporal specification* is started by *a second temporal specification*", thing).
lomo_prop(finishes,           lomo_finishes,         "*a temporal specification* finishes *a second temporal specification*", thing).
lomo_prop(finishedBy,         lomo_finished_by,      "*a temporal specification* is finished by *a second temporal specification*", thing).
lomo_prop(overlaps,           lomo_overlaps,         "*a temporal specification* overlaps *a second temporal specification*", thing).
lomo_prop(in,                 lomo_in,               "*a temporal specification* is timed within *a second temporal specification*", thing).
%  results
lomo_prop(hasResultCategory,  lomo_result_category,  "*a result* has the result category *a category*", word).
lomo_prop(isComposedOf,       lomo_is_composed_of,   "*a result* is composed of *a second result*", thing).
lomo_prop(isManifestedIn,     lomo_is_manifested_in, "*a result* is manifested in *a dataset*", thing).
lomo_prop(manifests,          lomo_manifests,        "*a dataset* manifests *a result*", thing).
%  definitions
lomo_prop(defines,            lomo_defines,          "*a definition* defines *a thing*", thing).
lomo_prop(isDefinedBy,        lomo_is_defined_by,    "*a thing* is defined by *a definition*", thing).
lomo_prop(equivalentDefinition, lomo_equivalent_definition, "*a definition* is equivalent to *a second definition*", thing).
lomo_prop(hasDefiniendum,     lomo_definiendum,      "*a definition* has the definiendum *a text*", text).
lomo_prop(hasDefiniens,       lomo_definiens,        "*a definition* has the definiens *a text*", text).
lomo_prop(termLabel,          lomo_term_label,       "*a definition* has the term label *a text*", text).
%  digital artefacts
lomo_prop(hasCapability,      lomo_capability,       "*a thing* has the capability *a text*", text).
lomo_prop(hasPurpose,         lomo_purpose,          "*a thing* has the purpose *a text*", text).
%  older words (LOMO before 1.1.0), still in the published data
lomo_prop(hasCondition,       lomo_has_condition,    "*a thing* has the condition *a condition*", thing).
lomo_prop(usesDefinition,     lomo_uses_definition,  "*a rule* uses the definition *a definition*", thing).
lomo_prop(isSemanticDefinition, lomo_semantic_definition, "*a definition* has the semantic flag *a truth value*", boolean).

older(IRI) :- member(L, [hasCondition, usesDefinition, isSemanticDefinition]), l(L, IRI).
older(IRI) :- l(L, IRI), \+ lomo_prop(L, _, _, _), \+ lomo_class(L, _, _).

other_prop(rdfs,    label,         lomo_label,          "*a thing* has the label *a text*", text).
other_prop(rdfs,    comment,       lomo_comment,        "*a thing* has the comment *a text*", text).
other_prop(dcterms, title,         lomo_title,          "*a thing* has the title *a text*", text).
other_prop(dcterms, description,   lomo_description,    "*a thing* has the description *a text*", text).
other_prop(dcterms, conformsTo,    lomo_conforms_to,    "*a thing* conforms to *a standard*", thing).
other_prop(dcterms, publisher,     lomo_publisher,      "*a thing* is published by *an agent*", thing).
other_prop(dcterms, references,    lomo_cites,          "*a thing* cites *a resource*", thing).
other_prop(skos,    prefLabel,     lomo_pref_label,     "*a thing* has the preferred label *a text*", text).
other_prop(skos,    definition,    lomo_skos_definition,"*a thing* has the explanation *a text*", text).
other_prop(skos,    inScheme,      lomo_in_scheme,      "*a thing* is in the scheme *a scheme*", thing).
other_prop(skos,    broader,       lomo_broader,        "*a thing* has the broader concept *a concept*", thing).
other_prop(cav,     resultsIn,     lomo_results_in,     "*an assessment* results in *an assessment statement*", thing).
other_prop(cav,     judgement,     lomo_judgement,      "*an assessment statement* has the judgement *a text*", text).
other_prop(cav,     type,          lomo_statement_type, "*an assessment statement* has the statement type *a type*", address).
other_prop(cav,     interpretation,lomo_interpretation, "*an assessment statement* has the interpretation *a text*", text).
other_prop(time,    inXSDDate,     lomo_xsd_date,       "*a temporal specification* has the date *a date*", date).
other_prop(m8g,     hasRelatedService, lomo_related_service, "*a thing* concerns the service *a service*", thing).

%   ---- word lists -----------------------------------------------------

vocabulary_term(IRI, W) :- term(P, Local, W), q(P, Local, IRI).

term(dm, 'Obligation', obligation).
term(dm, 'Permission', permission).
term(dm, 'Prohibition', prohibition).
term(dm, 'Right', right).
term(tf, deadline, deadline).
term(tf, validity, validity).
term(tf, startingPoint, 'starting point').
term(tf, trigger, trigger).
term(role, 'ADDRESSER', addresser).
term(role, 'ADDRESSEE', addressee).
term(role, 'BENEF', beneficiary).
term(dd, 'Data', data).
term(dd, 'Observation', observation).
term(dd, 'DataFlow', 'data flow').
term(dd, 'DigitalPublicService', 'digital public service').
term(dd, 'DigitalSolutions', 'digital solutions').
term(dd, 'ProcessAutomation', 'process automation').
term(rc, report, report).
term(rc, certificate, certificate).

%   ---- what has no word of its own ------------------------------------

%   generic_template(Kind, Functor, Template): a statement whose property
%   the table does not know, kept whole: the property as a compact IRI.
generic_template(type,    lomo_has_type,  "*a thing* has the type *a class*").
generic_template(value,   lomo_value,     "*a thing* has for *a property* the value *a value*").
generic_template(resource,lomo_resource,  "*a thing* has for *a property* the resource *a resource*").
generic_template(iri,     lomo_iri,       "*a thing* is identified by *an address*").
generic_template(datatype,lomo_datatype,  "the values of *a property* have the datatype *a datatype*").
generic_template(plain,   lomo_plain,     "the texts of *a property* have no language").
generic_template(value_datatype, lomo_value_datatype, "the value *a value* has the datatype *a datatype*").
generic_template(value_plain,    lomo_value_plain,    "the text *a text* has no language").

%   The datatype a literal of each kind is written with, on the way back.
literal_datatype(date,     'http://www.w3.org/2001/XMLSchema#date').
literal_datatype(duration, 'http://www.w3.org/2001/XMLSchema#duration').
literal_datatype(boolean,  'http://www.w3.org/2001/XMLSchema#boolean').
literal_datatype(number,   'http://www.w3.org/2001/XMLSchema#integer').

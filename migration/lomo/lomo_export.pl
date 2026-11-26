/** <module> Step 7: Logical English -> LOMO (the way back)

    export_lomo(+KB, +Options, -Result)          File > Export to Another System
        Result = exported(FileName, Turtle, Notes, []) | refused(Problems)
    applies_lomo(+KB)                            is there anything to write?
    check_lomo(+KB, +Options, -Problems)         what would be lost
    kb_triples(+KB, -Triples, -Notes)            the statements of a program

    Two readings, one file:

    1. **The program holds LOMO facts** (a register, or a program that
       includes one and adds to it, as the conditions programs of
       examples/migration/lomo do): every fact in the words of lib/lomo.le
       becomes its statement again, through the table of lomo_words.pl — a
       name becomes its address (`... is identified by "<IRI>"`) or a blank
       node, a word of a word list its term, a text its literal with the form
       the register recorded. The facts of the library itself are not the
       program's and are not written.
    2. **Every other rule with a label and a provision** (`rule r with
       provenance "<address>", confer "<words>":`) is described: a legal
       rule established in that address, with its words as its legal text; a
       rule that concludes an obligation, a permission or a prohibition (the
       deontic library) is a prescriptive rule with that modality, one
       action (the sentence it is about) and the party as addresser; a rule
       whose conditions say that another labelled rule's conclusion is not
       the case is derogated by that rule (the exception wins: the second
       rule derogates from the first). The conditions themselves are not
       LOMO's: the description links to the program (rdfs:seeAlso).

    The file is checked against LOMO's validity rules (lomo_shacl.pl) before
    it is given: a statement that breaks one is a note, not a refusal, when
    it was the program's own (a register keeps what its description had); a
    rule the second reading describes must pass.

    Copyright Miguel Calejo; Apache License 2.0.
*/

:- module(lomo_export, [export_lomo/3, applies_lomo/1, check_lomo/3, kb_triples/3, kb_file_triples/3, write_turtle/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(readutil)).
:- use_module('../le2_paths', []).
:- use_module(lomo_words).
:- use_module(lomo_shacl, [check_triples/2]).
:- use_module(le2(le_kbs)).
:- use_module(le2(le_writer), [kb_to_ir/2]).

rdf_type('http://www.w3.org/1999/02/22-rdf-syntax-ns#type').
xsd(L, I) :- atom_concat('http://www.w3.org/2001/XMLSchema#', L, I).
lomo(L, I) :- lomo_ns(N), atom_concat(N, L, I).

%   ---- 1. the facts of the program, as statements -------------------------

%   The LE goal of a template of the table: asked of LE itself, so that the
%   way back never guesses LE's own names.
:- dynamic goal_of_/3.
goal_of(KB, Text, Goal) :- goal_of_(KB, Text, Goal), !.
goal_of(KB, Text, Goal) :-
    which_query(Text, Q),
    catch(parse_custom_query(KB, Q, G), _, fail),
    strip_goal(G, Goal), !,
    assertz(goal_of_(KB, Text, Goal)).

strip_goal(G, G) :- compound(G), \+ G = (_, _), \+ G = le_holds(_), !.

which_query(Text, Q) :-
    split_string(Text, "*", "", Parts),
    which_parts(Parts, odd, Ws),
    atomic_list_concat(Ws, Q).
which_parts([], _, []).
which_parts([P|Ps], odd, [P|Ws]) :- which_parts(Ps, even, Ws).
which_parts([P|Ps], even, [W|Ws]) :-
    ( sub_string(P, 0, _, _, "an ") -> sub_string(P, 3, _, 0, N) ; sub_string(P, 0, _, _, "a ") -> sub_string(P, 2, _, 0, N) ; N = P ),
    format(string(W), "which ~w", [N]),
    which_parts(Ps, odd, Ws).

%   The facts of the program (and of what it includes) that are not the
%   library's own.
stated(KB, Text, Args) :-
    goal_of(KB, Text, G),
    copy_term(G, G1),
    catch(KB:clause(G1, true), _, fail),
    G1 =.. [_|Args],
    \+ library_fact(Text, Args).

library_fact(Text, Args) :-
    lib_kb(LK), goal_of(LK, Text, G), copy_term(G, G1), G1 =.. [_|Args], catch(LK:clause(G1, true), _, fail).

:- dynamic lib_kb_/1.
lib_kb(K) :- lib_kb_(K), !.
lib_kb(K) :-
    le2_paths:le2_dir(D), atomic_list_concat([D, '/lib/lomo.le'], F),
    load(F, K), assertz(lib_kb_(K)).

%!  kb_triples(+KB, -Triples, -Notes)
kb_triples(KB, Triples, Notes) :-
    findall(N-I, stated(KB, "*a thing* is identified by *an address*", [N, I]), NIs0),
    findall(N-I, ( member(N0-I0, NIs0), name_key(N0, N), atom_string(I, I0) ), NIs),
    prefixes(Prefixes),
    findall(T-How, fact_triple(KB, NIs, Prefixes, T, How), THs0),
    findall(T, member(T-_, THs0), Ts0),
    forms(KB, Prefixes, Forms),
    maplist(apply_form(Forms), Ts0, Ts1),
    list_to_set(Ts1, Triples),
    findall(N, ( member(_-note(N), THs0) ), Ns0), sort(Ns0, Notes).

name_key(N, K) :- ( string(N) -> atom_string(K, N) ; K = N ).

prefixes(Ps) :- findall(P-I, ns(P, I), Ps).

node_iri(NIs, Name0, IRI) :-
    name_key(Name0, Name),
    (   memberchk(Name-IRI, NIs) -> true
    ;   vocabulary_term(IRI, Name) -> true
    ;   bnode_for(Name, IRI)
    ).

:- dynamic bnode_/2.
bnode_for(Name, B) :- bnode_(Name, B), !.
bnode_for(Name, B) :- flag(lomo_export_bnode, N, N + 1), format(atom(B), '_:n~w', [N]), assertz(bnode_(Name, B)).

fact_triple(KB, NIs, _, rdf(S, P, C), class) :-
    rdf_type(P),
    class_word(C, _, T),
    stated(KB, T, [N]),
    node_iri(NIs, N, S).
fact_triple(KB, NIs, Prefixes, rdf(S, P, C), type) :-
    rdf_type(P),
    stated(KB, "*a thing* has the type *a class*", [N, CT]),
    node_iri(NIs, N, S), expand(CT, Prefixes, C).
fact_triple(KB, NIs, _, rdf(S, P, O), prop) :-
    property_word(P, _, T, Kind),
    stated(KB, T, [N, V]),
    node_iri(NIs, N, S),
    object(Kind, NIs, V, O).
fact_triple(KB, NIs, Prefixes, rdf(S, P, O), generic) :-
    stated(KB, "*a thing* has for *a property* the value *a value*", [N, PT, V]),
    node_iri(NIs, N, S), expand(PT, Prefixes, P),
    literal_of(value, V, O).
fact_triple(KB, NIs, Prefixes, rdf(S, P, O), generic) :-
    stated(KB, "*a thing* has for *a property* the resource *a resource*", [N, PT, V]),
    node_iri(NIs, N, S), expand(PT, Prefixes, P),
    (   string(V) -> atom_string(O, V) ; node_iri(NIs, V, O) ).

expand(T, Prefixes, IRI) :-
    ( string(T) -> atom_string(A, T) ; A = T ),
    (   sub_atom(A, B, 1, _, ':'), sub_atom(A, 0, B, _, P), \+ sub_atom(A, _, _, _, '//'),
        memberchk(P-NS, Prefixes)
    ->  B1 is B + 1, sub_atom(A, B1, _, 0, L), atom_concat(NS, L, IRI)
    ;   IRI = A
    ).

object(thing, NIs, V, O) :- !, ( string(V) -> atom_string(O, V) ; node_iri(NIs, V, O) ).
object(word, NIs, V, O) :- !, ( string(V) -> atom_string(O, V) ; vocabulary_term(O, V) -> true ; node_iri(NIs, V, O) ).
object(address, _, V, O) :- !, ( string(V) -> atom_string(O, V) ; atom(V) -> O = V ).
object(Kind, _, V, O) :- literal_of(Kind, V, O).

%   The usual form of a literal of each kind; forms/3 then changes it where
%   the register recorded another one.
literal_of(text, V, literal(lang(en, A))) :- !, text_atom(V, A).
literal_of(date, date(Y, M, D), literal(type(T, A))) :- !, xsd(date, T),
    format(atom(A), "~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, D]).
literal_of(duration, V, literal(type(T, A))) :- !, xsd(duration, T), text_atom(V, A).
literal_of(boolean, V, literal(type(T, V))) :- !, xsd(boolean, T).
literal_of(number, V, literal(type(T, A))) :- number(V), !,
    ( integer(V) -> xsd(integer, T) ; xsd(decimal, T) ), format(atom(A), "~w", [V]).
literal_of(_, date(Y, M, D), O) :- !, literal_of(date, date(Y, M, D), O).
literal_of(_, V, literal(type(T, A))) :- number(V), !, literal_of(number, V, literal(type(T, A))).
literal_of(_, V, literal(lang(en, A))) :- text_atom(V, A).      % a text: English, unless the register says otherwise

text_atom(V, A) :- ( string(V) -> atom_string(A, V) ; atom(V) -> A = V ; format(atom(A), "~w", [V]) ).

forms(KB, Prefixes, forms(PropForms, ValueForms)) :-
    findall(P-plain, ( stated(KB, "the texts of *a property* have no language", [PT]), expand(PT, Prefixes, P) ), F1),
    findall(P-F, ( stated(KB, "the values of *a property* have the datatype *a datatype*", [PT, TT]),
                   expand(PT, Prefixes, P), datatype_of(TT, Prefixes, F) ), F2),
    append(F1, F2, PropForms),
    findall(A-plain, ( stated(KB, "the text *a text* has no language", [V]), text_atom(V, A) ), V1),
    findall(A-F, ( stated(KB, "the value *a value* has the datatype *a datatype*", [V, TT]),
                   value_lexical(V, A), datatype_of(TT, Prefixes, F) ), V2),
    append(V1, V2, ValueForms).

datatype_of(TT, Prefixes, F) :-
    ( string(TT) -> atom_string(A, TT) ; A = TT ),
    (   sub_atom(A, 0, 1, _, '@') -> sub_atom(A, 1, _, 0, L), F = lang(L)
    ;   expand(A, Prefixes, T), F = type(T)
    ).

value_lexical(V, A) :- literal_of(value, V, L), lexical(L, A).

apply_form(forms(PFs, VFs), rdf(S, P, O0), rdf(S, P, O)) :-
    (   O0 = literal(_), lexical(O0, A)
    ->  (   memberchk(A-F, VFs) -> form_literal(F, A, O)
        ;   memberchk(P-F, PFs) -> form_literal(F, A, O)
        ;   O = O0
        )
    ;   O = O0
    ).

lexical(literal(lang(_, A)), A).
lexical(literal(type(_, A)), A).
lexical(literal(A), A) :- atomic(A).

form_literal(plain, A, literal(A)).
form_literal(type(T), A, literal(type(T, A))).
form_literal(lang(L), A, literal(lang(L, A))).

%   ---- 2. rules with a label and a provision, described --------------------

%!  rule_triples(+KB, +Program, -Triples, -Problems)
rule_triples(KB, Program, Triples, Problems) :-
    kb_to_ir(KB, program(_, Items)),
    findall(T, member(template(_, T, _), Items), _),
    documents(KB, Items, Docs),
    %  a rule that cites nothing is not one of the description's: left out
    findall(r(Label, Head, Body, Prov), ( member(rule(Head, Body, Opts), Items), option(label(Label), Opts),
                                          option(provenance(Prov), Opts), Prov \== [] ), Rules),
    findall(Ts-Ps, ( member(R, Rules), describe_rule(R, Rules, Docs, Program, Ts, Ps) ), TPs),
    findall(T, ( member(Ts-_, TPs), member(T, Ts) ), Triples),
    findall(P, ( member(_-Ps, TPs), member(P, Ps) ), Problems).

%   Where each document of the program is published: its `is published at`
%   facts (le_published_at/2), and any document item of the IR with a url.
documents(KB, Items, Docs) :-
    findall(Name-URL, ( member(document(Name, Opts), Items), option(url(URL), Opts) ), D1),
    findall(N-U, ( catch(KB:le_published_at(N0, U), _, fail), name_key(N0, N) ), D2),
    append(D1, D2, Docs).

describe_rule(r(Label, Head, Body, Prov), Rules, Docs, Program, Triples, Problems) :-
    rule_iri(Program, Label, R),
    (   provision_address(Prov, Docs, Address)
    ->  quote(Prov, Quote),
        deontic(Head, Modality, Party, Sentence),
        rdf_type(Type),
        format(atom(LabelT), "~w", [Label]),
        Base = [rdf(R, 'http://www.w3.org/2000/01/rdf-schema#label', literal(lang(en, LabelT))),
                rdf(R, EI, Address),
                rdf(R, 'http://www.w3.org/2000/01/rdf-schema#seeAlso', ProgramIRI)],
        lomo(establishedIn, EI), absolute_file_name(Program, AbsP), atom_concat('file://', AbsP, ProgramIRI),
        ( Quote == none -> QT = [] ; lomo(legalText, LT), QT = [rdf(R, LT, literal(lang(en, Quote)))] ),
        (   Modality == none
        ->  lomo('ConstitutiveRule', C), Kind = [rdf(R, Type, C)], Act = []
        ;   lomo('PrescriptiveRule', C), lomo(hasDeonticModality, HM), vocabulary_word(Modality, MIRI),
            Kind = [rdf(R, Type, C), rdf(R, HM, MIRI)],
            action_triples(R, Party, Sentence, Act)
        ),
        derogations(Label, Body, Rules, Program, R, Der),
        append([Kind, Base, QT, Act, Der], Triples),
        Problems = []
    ;   Triples = [],
        format(string(M), "rule ~w has no web address of the provision it comes from (with provenance \"<address>\", or a document that is published at an address): LOMO names every rule by the ELI of its provision", [Label]),
        Problems = [problem(none, M)]
    ).

vocabulary_word(W, I) :- vocabulary_term(I, W), !.

rule_iri(Program, Label, IRI) :-
    file_base_name(Program, B), file_name_extension(Stem, _, B),
    format(atom(IRI), "urn:logical-english:~w#~w", [Stem, Label]).

provision_address(Prov, Docs, Address) :-
    (   member(P, Prov), P =.. [_, D], address_of(D, Docs, Address) -> true ).
address_of(D, Docs, A) :-
    ( string(D) -> atom_string(DA, D) ; DA = D ),
    (   sub_atom(DA, 0, _, _, 'http') -> A = DA
    ;   member(N-U, Docs), same_doc(N, DA) -> ( string(U) -> atom_string(A, U) ; A = U )
    ).

same_doc(N, D) :- ( N == D -> true ; catch(le_provenance:same_document(N, D), _, fail) ).

quote(Prov, Q) :- ( memberchk(confer(Q0), Prov) -> text_atom(Q0, Q) ; Q = none ).

%   A rule that concludes a deontic sentence of lib/deontic.le.
deontic(Head, Modality, Party, Sentence) :-
    (   Head =.. [F, Party, Sentence], deontic_functor(F, Modality) -> true
    ;   Modality = none, Party = none, Sentence = none
    ).
deontic_functor(F, M) :-
    member(F-M, [is_obliged_that-obligation, is_permitted_that-permission, is_forbidden_that-prohibition,
                 has_the_right_that-right]), !.

action_triples(R, Party, Sentence, Triples) :-
    lomo(produces, Pr), lomo(hasAgentRole, HAR), lomo(forAgent, FA), lomo(withRole, WR), rdf_type(T),
    lomo('Action', AC), lomo('AgentRole', ARC), lomo('AgentType', ATC),
    format(atom(A), "~w-action", [R]), format(atom(Ro), "~w-role", [R]),
    sentence_words(Sentence, Words),
    party_type(Party, PT), format(atom(Ag), "~w-~w", [R, PT]),
    vocabulary_term(Addresser, addresser),
    Triples = [rdf(R, Pr, A), rdf(A, T, AC), rdf(A, 'http://www.w3.org/2000/01/rdf-schema#label', literal(lang(en, Words))),
               rdf(A, HAR, Ro), rdf(Ro, T, ARC), rdf(Ro, FA, Ag), rdf(Ro, WR, Addresser),
               rdf(Ag, T, ATC), rdf(Ag, 'http://www.w3.org/2000/01/rdf-schema#label', literal(lang(en, PT)))].

sentence_words(S, W) :- ( compound(S) -> functor(S, F, _), atomic_list_concat(Ws, '_', F), atomic_list_concat(Ws, ' ', W) ; format(atom(W), "~w", [S]) ).
party_type(P, T) :- ( var(P) -> T = party ; format(atom(T), "~w", [P]) ).

%   An exception: rule A's conditions say that what a second labelled rule
%   B concludes is not the case; B wins where it holds: B derogates from A.
derogations(Label, Body, Rules, Program, R, Triples) :-
    lomo(derogatesFrom, DF),
    findall(rdf(OR, DF, R),
            ( negated(Body, L), member(r(Other, OH, _, _), Rules), Other \== Label,
              functor(L, F, N), functor(OH, F, N),
              rule_iri(Program, Other, OR) ), Ts0),
    sort(Ts0, Triples).

negated(not(L), L) :- \+ L = and(_, _), \+ L = or(_, _), !.
negated(not(B), L) :- negated_inner(B, L).
negated(and(A, B), L) :- ( negated(A, L) ; negated(B, L) ).
negated(or(A, B), L) :- ( negated(A, L) ; negated(B, L) ).
negated((A, B), L) :- ( negated(A, L) ; negated(B, L) ).
negated(\+ G, L) :- negated(not(G), L).
negated_inner(and(A, B), L) :- ( negated_inner(A, L) ; negated_inner(B, L) ).
negated_inner(L, L) :- compound(L), \+ L = and(_, _), \+ L = or(_, _).

%   ---- the exporter -------------------------------------------------------

applies_lomo(KB) :-
    (   once(stated(KB, "*a thing* is identified by *an address*", _)) -> true
    ;   once(( class_word(_, _, T), stated(KB, T, _) )) -> true
    ;   catch(kb_to_ir(KB, program(_, Items)), _, fail),
        member(rule(_, _, Opts), Items), option(provenance(_), Opts), option(label(_), Opts), !
    ).

program_file(KB, Options, F) :-
    (   option(file(F), Options) -> true
    ;   catch(le_kbs:kb_source_file(KB, F), _, fail) -> true
    ;   format(atom(F), "~w.le", [KB])
    ).

kb_file_triples(KB, Options, Result) :-
    retractall(bnode_(_, _)),
    kb_triples(KB, FTs, Notes1),
    program_file(KB, Options, Prog),
    (   FTs == [] -> rule_triples(KB, Prog, RTs, Problems) ; RTs = [], Problems = [] ),
    append(FTs, RTs, Ts),
    Result = triples(Ts, Notes1, Problems).

check_lomo(KB, Options, Problems) :-
    kb_file_triples(KB, Options, triples(Ts, _, Ps0)),
    (   Ts == [], Ps0 == []
    ->  Problems = [problem(none, "the program has no LOMO facts and no rule with a label and the address of its provision: there is nothing to describe")]
    ;   Problems = Ps0
    ).

export_lomo(KB, Options, Result) :-
    check_lomo(KB, Options, Problems),
    (   Problems \== [] -> Result = refused(Problems)
    ;   kb_file_triples(KB, Options, triples(Ts, Notes0, _)),
        check_triples(Ts, Rs),
        findall(N, ( member(result(_, _, _, _, M), Rs), format(string(N), "LOMO's validity rules: ~w", [M]) ), VNotes),
        write_turtle(Ts, [], Turtle),
        program_file(KB, Options, Prog), file_base_name(Prog, B), file_name_extension(Stem, _, B),
        atom_concat(Stem, '.ttl', FileName),
        length(Ts, NT),
        format(string(N0), "~w statements, in the words of LOMO 1.1.0; the conditions of the rules are not LOMO's and stay in the program", [NT]),
        append([[N0], Notes0, VNotes], Notes),
        Result = exported(FileName, Turtle, Notes, [])
    ).

%!  write_turtle(+Triples, +Options, -Text)
%   A Turtle text of the statements, with the prefixes of lomo_words.pl
%   that it uses: one block per subject, in the order of the statements.
%   Written here, not by library(semweb/rdf_db), so that the way back also
%   runs where SWI-Prolog has no RDF database (WebAssembly).
write_turtle(Ts, _Options, Text) :-
    findall(P-I, ns(P, I), Ps0),
    findall(S, member(rdf(S, _, _), Ts), Ss0), list_to_set(Ss0, Ss),
    bnode_labels(Ts, Labels),
    with_output_to(string(Body),
        forall(member(S, Ss),
               ( findall(P-O, member(rdf(S, P, O), Ts), POs),
                 term_text(S, Ps0, Labels, ST),
                 format("~w", [ST]),
                 write_pos(POs, Ps0, Labels, first),
                 format(" .~n~n") ))),
    findall(P-I, ( member(P-I, Ps0), format(atom(Pre), "~w:", [P]), once(sub_string(Body, _, _, _, Pre)) ), Used),
    with_output_to(string(Head), forall(member(P-I, Used), format("@prefix ~w: <~w> .~n", [P, I]))),
    format(string(Text), "~w~n~w", [Head, Body]).

write_pos([], _, _, _).
write_pos([P-O|POs], Ps, Ls, Pos) :-
    term_text(P, Ps, Ls, PT0), ( rdf_type(P) -> PT = a ; PT = PT0 ),
    term_text(O, Ps, Ls, OT),
    ( Pos == first -> format("~n    ~w ~w", [PT, OT]) ; format(" ;~n    ~w ~w", [PT, OT]) ),
    write_pos(POs, Ps, Ls, next).

bnode_labels(Ts, Ls) :-
    findall(B, ( member(rdf(S, _, O), Ts), member(B, [S, O]), blank(B) ), Bs0), list_to_set(Bs0, Bs),
    findall(B-L, ( nth1(I, Bs, B), format(atom(L), "_:b~w", [I]) ), Ls).

blank(B) :- atom(B), ( sub_atom(B, 0, 2, _, '_:') ; sub_atom(B, 0, 4, _, 'bn__') ), !.
blank(B) :- compound(B), B = bnode(_).

term_text(literal(L), _, _, T) :- !, literal_text(L, T).
term_text(B, _, Ls, T) :- memberchk(B-T, Ls), !.
term_text(I, Ps, _, T) :-
    (   member(P-NS, Ps), atom_concat(NS, L, I), L \== '', local_ok(L)
    ->  format(atom(T), "~w:~w", [P, L])
    ;   format(atom(T), "<~w>", [I])
    ).

local_ok(L) :- atom_codes(L, Cs), Cs = [C0|_], code_type(C0, alpha),
    forall(member(C, Cs), ( code_type(C, alnum) ; C == 0'_ ; C == 0'- )).

literal_text(lang(L, A), T) :- !, quoted(A, Q), format(atom(T), "~w@~w", [Q, L]).
literal_text(type(D, A), T) :- !, quoted(A, Q), format(atom(T), "~w^^<~w>", [Q, D]).
literal_text(A, T) :- quoted(A, T).

quoted(A, T) :-
    atom_codes(A, Cs), phrase(escaped(Cs), Es), atom_codes(E, Es),
    format(atom(T), "\"~w\"", [E]).
escaped([]) --> [].
escaped([0'"|Cs]) --> !, "\\\"", escaped(Cs).
escaped([0'\\|Cs]) --> !, "\\\\", escaped(Cs).
escaped([10|Cs]) --> !, "\\n", escaped(Cs).
escaped([13|Cs]) --> !, "\\r", escaped(Cs).
escaped([9|Cs]) --> !, "\\t", escaped(Cs).
escaped([C|Cs]) --> [C], escaped(Cs).

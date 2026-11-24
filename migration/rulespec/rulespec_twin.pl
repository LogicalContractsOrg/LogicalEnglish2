/** <module> A RuleSpec module and its imports as a Logical English twin

    roadmap.md §5.10 and §8, Phase 3a. One twin per module: the module and
    every module it imports, directly or not, in one program (the engine
    merges them into one namespace too), each module's rules under a comment
    naming its provision. What becomes what:

      - a `parameter` → a fact (`the snap minimum allotment rate is 0.08`),
        cited with the rule's `source` (the citation, and the quoted words
        as a `confer`); an indexed table → one fact per row;
      - a `derived` value → a rule concluding a template `the <name> of *a
        household* is *an amount*`; a judgment → a sentence template
        (`*a household* is snap eligible`);
      - a formula → the rule's conditions: every name it reads is a
        condition, the arithmetic a last condition; `if`/`elif`/`else` and
        `match` an otherwise cascade; `max`/`min`/`floor`/`ceil` LE's own;
        `len`, `sum`, `count_where`, `sum_where` over a relation LE's
        `count of each` / `sum of each`;
      - a name no rule defines → an input: a template the scenario states
        (`; undefined`); a Boolean input is a sentence, stated when true;
      - a `data_relation` → a two-place sentence (`*a person* is a member
        of *a household*`);
      - dated versions → each version's rule guarded by `the calculation
        date`, which every scenario states (N9, roadmap §7.5); a rule with
        one version open at its end carries no guard;
      - the companion `.test.yaml` → one scenario per case, its inputs as
        facts, each output an expectation of a query named after the rule.

    What the twin cannot say is residue: a formula using a function with no
    LE counterpart here (`days_between`, `date_add_*`, the `*_over_periods`
    reductions), a `derived_relation`, a reference the translator cannot
    place. Each is a residue block with the formula, and the expectations
    that depend on it are pending.

    module_migration(+Id, +Options, -Migration) builds the le_migration
    term; Options: oracle_runs(Dict) (the run file of rulespec_oracle.py, to
    mark the cases where the engine and the test file disagree),
    sources_dir(Dir) (where the originals are copied, for the citations).
*/

:- module(rulespec_twin, [module_migration/3, module_twin_name/2, judgment_text/3, words_of/2]).

:- dynamic overridable/1.

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(yaml)).
:- use_module(library(pairs)).
:- use_module(rulespec_reader).

:- dynamic sym/3, uses/3, residue_rule/2, rel_swapped/1, cross_entity/3, by_period/1, period_rel_used/1,
           person_ent/1, fr_accent/2.


		 /*******************************
		 *         THE MIGRATION        *
		 *******************************/

%!  module_twin_name(+Id, -Name) is det.
%
%   us:statutes/7/2017/a → us_statutes_7_2017_a
module_twin_name(Id, Name) :-
    atom_codes(Id, Cs0),
    maplist([C0, C]>>( code_type(C0, alnum) -> C = C0 ; C = 0'_ ), Cs0, Cs),
    atom_codes(A, Cs), atomic_list_concat(Ps0, '_', A), exclude(==(''), Ps0, Ps),
    atomic_list_concat(Ps, '_', N0), downcase_atom(N0, Name).

%!  module_migration(+Id, +Options, -Migration) is det.
module_migration(Id, Options, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    retractall(sym(_, _, _)), retractall(uses(_, _, _)), retractall(doc_written(_)), retractall(residue_rule(_, _)), retractall(rel_swapped(_)), retractall(cross_entity(_, _, _)),
    retractall(by_period(_)), retractall(period_rel_used(_)), retractall(person_ent(_)),
    nb_setval(rs_residues, 0),
    nb_setval(rs_period_kind, calc), b_setval(rs_period_var, _),
    option(language(Lang), Options, en), nb_setval(rs_lang, Lang),
    option(subject(Subj), Options, default), nb_setval(rs_subject, Subj),
    option(judgment_subject(JS), Options, none), nb_setval(rs_judgment_subject, JS),
    %  What a rule itself asserts, written as an integrity constraint: off
    %  unless the build asks for it (see must_items/3 for the measurement
    %  that decided the default).
    option(constraints(Cns), Options, false), nb_setval(rs_constraints, Cns),
    module_closure(Id, Modules),
    symbols(Modules),
    accents(Lang, Modules),
    module_twin_name(Id, KB),
    read_module(Id, module(_, Root)),
    title(Id, Root, Title),
    length(Modules, Nm), Nm1 is Nm - 1,
    (   memberchk(header(C1), Options) -> true
    ;   format(string(C1), "~w~nRuleSpec module ~w (Axiom Foundation, rulespec-us, CC-BY-4.0), with the ~w module(s) it imports.~nTranslated by LE2 migration/rulespec.",
               [Title, Id, Nm1])
    ),
    ( Lang == en -> Header = [kb(KB), comment(C1)] ; Header = [kb(KB), comment(C1), language(Lang)] ),
    %  the rules first: they say which period relations the formulas ask for,
    %  and the templates must declare those (Phase 3b′, item 1)
    maplist(module_items(Options), Modules, MItemss), append(MItemss, MItems),
    templates(TItems),
    tests(Id, Options, Tests),
    queries(QItems),
    coverage_constraints(Root, CItems),
    append([TItems, MItems, CItems, QItems], Items),
    ledger(Modules, Ledger),
    get_time(T), format_time(atom(Date), '%F', T),
    findall(F, ( member(module(MI, _), Modules), source_file_rel(MI, F) ), Arts),
    Meta = [source('Axiom RuleSpec'), artifacts(Arts), translator('LE2 migration/rulespec'),
            program(KB), date(Date), licence('CC-BY-4.0 (rulespec-us, Axiom Foundation)')].

%   A module that keeps the parameters of some years only (an OpenFisca
%   twin keeps the values of the years its tests ask about) says so with
%   `covers: [From, To]`: a case dated outside them is refused, with the
%   reason, rather than answered from values the twin does not have (the
%   OpenFisca review's finding 4; LE's integrity constraints, language.md
%   §3.3).
coverage_constraints(Root, Items) :-
    (   get_dict(module, Root, M), get_dict(covers, M, [F0, T0]), uses_calculation_date
    ->  maplist([S, date(Y, Mo, D)]>>( atom_string(A, S), atomic_list_concat([YA, MA, DA], '-', A),
                                       maplist(atom_number, [YA, MA, DA], [Y, Mo, D]) ), [F0, T0], [F, T]),
        ( nb_current(rs_lang, fr) -> Lang = fr ; Lang = en ),
        cover_comment(Lang, F0, T0, Cm),
        Items = [constraint(and(rs_calculation_date(D1), le_lt(D1, F)), [comment(Cm)]),
                 constraint(and(rs_calculation_date(D2), le_lt(T, D2)), [])]
    ;   Items = []
    ).

cover_comment(fr, F, T, C) :- !,
    format(string(C), "Le jumeau ne garde que les valeurs des paramètres du ~w au ~w : un cas daté d'un autre jour est refusé.", [F, T]).
cover_comment(_, F, T, C) :-
    format(string(C), "The twin keeps the parameters' values from ~w to ~w only: a case dated outside them is refused, not answered.", [F, T]).

title(Id, D, Title) :-
    (   get_dict(module, D, M), get_dict(title, M, T) -> true
    ;   citation_of(Id, T)
    ),
    format(string(Title), "~w", [T]).

%   us:statutes/7/2017/a → 7 U.S.C. 2017(a); otherwise the id.
citation_of(Id, Cit) :-
    atomic_list_concat([us, Rest], ':', Id),
    atomic_list_concat([statutes, Title, Sec|Subs], '/', Rest), !,
    maplist([S, P]>>format(atom(P), '(~w)', [S]), Subs, Ps), atomic_list_concat(Ps, PT),
    ( Title == '26' -> Code = 'U.S.C.' ; Code = 'U.S.C.' ),
    format(atom(Cit), '~w ~w ~w~w', [Title, Code, Sec, PT]).
citation_of(Id, Id).

source_file_rel(Id, F) :-
    atomic_list_concat([J, R], ':', Id), atomic_list_concat(['sources/', J, '/', R, '.yaml'], F).


		 /*******************************
		 *           SYMBOLS            *
		 *******************************/

%   sym(Name, Kind, Info)
%     Kind: parameter(Indexed) Indexed = none | by(IndexName)
%           derived(scalar|judgment)
%           relation(Args)                 Args = [EntityA, EntityB]
%           derived_relation
%           input(scalar|judgment)
%     Info: info(Module, Rule, Entity, Dtype)
%   uses(Input, Position, Entity): an input read in Position by a rule of Entity

symbols(Modules) :-
    retractall(overridable(_)),
    forall(( member(module(MId, D), Modules), rules_of(D, Rs), member(R, Rs) ),
           add_rule_symbol(MId, R)),
    %  (a value a test may state although a rule gives it: Catala's context)
    forall(( member(module(_, D), Modules), rules_of(D, Rs), member(R, Rs),
             get_dict(overridable, R, true), rule_name(R, N) ),
           assertz(overridable(N))),
    %  a value of the kind a rule gives, which a case may give instead (the
    %  value a caller or a test gives a Catala `context`): an input of its
    %  own, read before the rule's own definition (roadmap §8, Phase 3c work
    %  left, item 6)
    forall(( overridable(N), sym(N, derived(scalar), info(MId, _, E, T)), given_name(N, GN), \+ sym(GN, _, _) ),
           ( assertz(sym(GN, input(scalar), info(MId, none, E, T))),
             ( by_period(N), \+ by_period(GN) -> assertz(by_period(GN)) ; true ) )),
    forall(( member(module(_, D), Modules), rules_of(D, Rs), member(R, Rs),
             get_dict(kind, R, K), memberchk(K, ["derived", "parameter"]),
             rule_entity(R, E), rule_versions(R, Vs), member(V, Vs), get_dict(formula, V, F),
             catch(parse_formula(F, T), _, fail),
             position_of(R, P) ),
           note_uses(T, P, E)),
    forall(( uses(N, _, E), \+ sym(N, _, _), N \== period_start, N \== period_end ),
           add_input(N)).

rules_of(D, Rs) :- ( get_dict(rules, D, Rs0), is_list(Rs0) -> Rs = Rs0 ; Rs = [] ).

rule_versions(R, Vs) :- ( get_dict(versions, R, Vs0), is_list(Vs0) -> Vs = Vs0 ; Vs = [] ).

rule_name(R, N) :- get_dict(name, R, S), atom_string(N, S).

rule_entity(R, E) :- ( get_dict(entity, R, S), S \== null -> atom_string(E, S) ; E = none ).

rule_dtype(R, T) :- ( get_dict(dtype, R, S), S \== null -> atom_string(T, S) ; T = 'Decimal' ).

judgment_dtype(T) :- memberchk(T, ['Judgment', judgment, 'Boolean', 'Bool', boolean, bool]).

position_of(R, P) :- rule_dtype(R, T), ( judgment_dtype(T) -> P = judgment ; P = scalar ).

add_rule_symbol(MId, R) :-
    rule_name(R, N), get_dict(kind, R, K0), atom_string(K, K0),
    %  a value the case states for each period the calculation reads: its
    %  template has a place for the period (roadmap Phase 3b′, item 1)
    ( get_dict(by_period, R, true) -> ( by_period(N) -> true ; assertz(by_period(N)) ) ; true ),
    rule_entity(R, E), rule_dtype(R, T),
    Info = info(MId, R, E, T),
    (   sym(N, _, _) -> true                      % the first module to define it
    ;   K == parameter -> ( get_dict(indexed_by, R, B), B \== null -> atom_string(BA, B), Ix = by(BA) ; Ix = none ),
        assertz(sym(N, parameter(Ix), Info))
    ;   K == derived -> ( judgment_dtype(T) -> P = judgment ; P = scalar ), assertz(sym(N, derived(P), Info))
    ;   K == data_relation -> relation_args(R, As), note_person_entity(N, As), assertz(sym(N, relation(As), Info))
    ;   K == derived_relation -> assertz(sym(N, derived_relation, Info))
    ;   K == input -> ( judgment_dtype(T) -> P = judgment ; P = scalar ), assertz(sym(N, input(P), Info))
    ;   true                                      % a source_relation: provenance only
    ).

relation_args(R, [A, B]) :-
    get_dict(data_relation, R, DR), get_dict(arguments, DR, [A0, B0]), !,
    atom_string(A, A0), atom_string(B, B0).
relation_args(_, [P, 'Household']) :- person_entity(P).

%!  person_entity(-Entity) is det.
%
%   The entity this module calls a person: the first argument of a
%   `member_of_…` relation, which the reader writes from the package's own
%   name for it — `Person` in the country template and PolicyEngine,
%   `Individu` in openfisca-france, so that a French twin says *un individu*
%   and not *un person*. `Person` when the module has no such relation.
person_entity(E) :- ( person_ent(E0) -> E = E0 ; E = 'Person' ).

%   Read from a membership relation only (`member_of_household`), whose first
%   argument is the person: another two-place relation of the module says
%   nothing about which of its entities is a person.
note_person_entity(Name, [A, _]) :-
    atom_concat(member_of_, _, Name), A \== none, \+ person_ent(_), !,
    assertz(person_ent(A)).
note_person_entity(_, _).

%   Every name a formula reads, with the position it is read in.
note_uses(T, P, E) :- note(T, P, E).

note(id(N), P, E) :- !, assertz(uses(N, P, E)).
note(num(_), _, _) :- !.
note(str(_), _, _) :- !.
note(bool(_), _, _) :- !.
note(and(A, B), _, E) :- !, note(A, judgment, E), note(B, judgment, E).
note(or(A, B), _, E) :- !, note(A, judgment, E), note(B, judgment, E).
note(not(A), _, E) :- !, note(A, judgment, E).
note(cmp(_, A, bool(_)), _, E) :- !, note(A, judgment, E).
note(cmp(_, A, B), _, E) :- !, note(A, scalar, E), note(B, scalar, E).
note(bin(_, A, B), _, E) :- !, note(A, scalar, E), note(B, scalar, E).
note(neg(A), _, E) :- !, note(A, scalar, E).
note(if(C, T, F), P, E) :- !, note(C, judgment, E), note(T, P, E), note(F, P, E).
note(match(S, Arms, D), P, E) :- !, note(S, scalar, E),
    forall(member(_-V, Arms), note(V, P, E)), ( D == none -> true ; note(D, P, E) ).
note(index(_, I), _, E) :- !, note(I, scalar, E).
note(call(at_period, [id(V), _]), P, E) :- !, assertz(uses(V, P, E)).
note(call(sum_over_months, [id(V), _]), _, E) :- !, assertz(uses(V, scalar, E)).
note(call(F, As), _, E) :- relation_call(F, As, R, Field, Pred), !,
    related_entity(R, E, RE),
    ( Field == none -> true ; assertz(uses(Field, scalar, RE)) ),
    ( Pred == none -> true ; assertz(uses(Pred, judgment, RE)) ).
note(call(rank_in_group, [_, K, C]), _, E) :- !, note(K, scalar, E), ( C == id(none) -> true ; note(C, judgment, E) ).
%   A value of the member's group read for another period, or read over the
%   months of one: the field is a read of its own
%   (`member_of_foyer_fiscal.at_period(rev_coll, …)`), and what it uses is
%   the name inside it — the whole call registered as a name of its own left
%   a compound where every later step wanted a word.
note(field(R, call(_, [id(Fd)|_])), P, E) :- !,
    related_entity(R, E, RE), assertz(uses(Fd, P, RE)).
note(field(R, Fd), P, E) :- !,                     % a value of the person's group
    related_entity(R, E, RE), assertz(uses(Fd, P, RE)).
note(call(exactly_one, As), _, E) :- !, forall(member(A, As), note(A, judgment, E)).
note(call(_, As), _, E) :- !, forall(member(A, As), note(A, scalar, E)).
note(_, _, _).

relation_call(len, [id(R)], R, none, none).
relation_call(sum, [field(R, F)], R, F, none).
relation_call(count_where, [id(R), id(P)], R, none, P).
relation_call(sum_where, [id(R), id(F), id(P)], R, F, P).

%   The entity on the other side of a relation from E.
related_entity(R, E, RE) :-
    (   sym(R, relation([A, B]), _)
    ->  ( A == E -> RE = B ; B == E -> RE = A ; RE = A )
    ;   person_entity(RE)
    ).

add_input(N) :-
    (   uses(N, judgment, _), \+ uses(N, scalar, _) -> P = judgment ; P = scalar ),
    (   uses(N, P, E) -> true ; uses(N, _, E) ),
    assertz(sym(N, input(P), info(none, none, E, none))).


		 /*******************************
		 *           WORDING            *
		 *******************************/

%!  words_of(+Name, -Words) is det.
%
%   A rule name's words: `snap_minimum_allotment_rate` → [snap, minimum,
%   allotment, rate]. Articles go (LE would read `a member` in a condition
%   as a variable), and a word LE reads as a connective is replaced. In a
%   French twin the word is then spelled with the accents the source's own
%   labels give it (accents/2): *le crédit d'impôt*, not *le credit impot*.
words_of(N, Ws) :-
    atomic_list_concat(Ws0, '_', N),
    exclude(==(''), Ws0, Ws1),
    letters(Ws1, Ws2),
    exclude([W]>>memberchk(W, [a, an]), Ws2, Ws3),
    maplist(safe_word, Ws3, Ws4),
    reserved_safe(Ws4, Ws5),
    maplist(accented, Ws5, Ws).

%!  accented(+Word, -Spelled) is det.
%
%   The word as the source's own labels spell it, accents and all. A name in
%   a package of variables carries none (`credit_impot_logement`), while the
%   label of each variable, which the rule cites, is written for a reader
%   (*Crédit d'impôt*); the twin's sentences read as French when the name
%   borrows the label's spelling. Only a word the dictionary of accents has
%   (accents/2) changes.
accented(W, S) :- fr_accent(W, S), !.
accented(W, W).

%!  accents(+Language, +Modules) is det.
%
%   The dictionary of accents of a French twin, read from the labels of the
%   modules themselves: each word of a label, without its accents, paired
%   with the spelling the labels use most often for it. A word is accented
%   only when the accented spelling is the commonest one — openfisca-france
%   writes *impôt* 385 times and *impot* less, so the twin says *impôt*;
%   where the plain spelling wins, or the word is shorter than four letters
%   (*a* and *à*, *ou* and *où*), the name's own spelling stands.
accents(Lang, Modules) :-
    retractall(fr_accent(_, _)),
    (   Lang == fr
    ->  findall(W, ( accent_label(Modules, L), accent_label_word(L, W) ), Ws),
        msort(Ws, Sorted), clumped(Sorted, Counts),
        findall(P-(C-W), ( member(W-C, Counts), unaccented(W, P) ), Keyed),
        keysort(Keyed, ByPlain), group_pairs_by_key(ByPlain, Grouped),
        forall(member(P-Spellings, Grouped), accent_entry(P, Spellings))
    ;   true
    ).

%   The commonest spelling of one word; an accent is kept only if that
%   spelling has one, and the word is long enough for an accent to be about
%   a word rather than about a preposition.
accent_entry(P, Spellings) :-
    (   atom_length(P, L), L >= 4,
        sort(0, @>=, Spellings, [_-Best|_]), Best \== P
    ->  assertz(fr_accent(P, Best))
    ;   true
    ).

%   The labels of a twin's modules: each rule's `source` (the variable's own
%   label, the parameter's reference), and the module's title and summary.
accent_label(Modules, L) :-
    member(module(_, D), Modules),
    (   rules_of(D, Rs), member(R, Rs), get_dict(source, R, L0), L0 \== null, atom_string(L, L0)
    ;   get_dict(module, D, M), member(K, [title, summary]),
        get_dict(K, M, L1), L1 \== null, atom_string(L, L1)
    ).

%   A label's words: runs of letters, lower case. Everything else (a digit,
%   a hyphen, the punctuation of a citation, a URL's slashes) separates them,
%   as `_` separates the words of a name.
accent_label_word(L, W) :-
    atom_chars(L, Cs), accent_label_words(Cs, [], Ws), member(W, Ws).

accent_label_words([], Acc, Ws) :- ( Acc == [] -> Ws = [] ; accent_word_of(Acc, W), Ws = [W] ).
accent_label_words([C|Cs], Acc, Ws) :-
    (   char_type(C, alpha), \+ char_type(C, digit), C \== '_'
    ->  accent_label_words(Cs, [C|Acc], Ws)
    ;   Acc == []
    ->  accent_label_words(Cs, [], Ws)
    ;   accent_word_of(Acc, W), accent_label_words(Cs, [], Ws0), Ws = [W|Ws0]
    ).

accent_word_of(Acc, W) :- reverse(Acc, Cs), atom_chars(W0, Cs), downcase_atom(W0, W).

%!  unaccented(+Word, -Plain) is det.
%
%   The word with its accents taken off, as a name in a package of variables
%   spells it: *perçues* → `percues`, *œuvre* → `oeuvre`.
unaccented(W, P) :-
    atom_chars(W, Cs), maplist(plain_char, Cs, Ps), atomic_list_concat(Ps, P).

plain_char(C, P) :- ( accent_of(C, P0) -> P = P0 ; P = C ).

accent_of('à', a). accent_of('â', a). accent_of('ä', a). accent_of('á', a).
accent_of('é', e). accent_of('è', e). accent_of('ê', e). accent_of('ë', e).
accent_of('î', i). accent_of('ï', i). accent_of('í', i).
accent_of('ô', o). accent_of('ö', o). accent_of('ó', o).
accent_of('ù', u). accent_of('û', u). accent_of('ü', u). accent_of('ú', u).
accent_of('ç', c). accent_of('ÿ', y). accent_of('ñ', n).
accent_of('œ', oe). accent_of('æ', ae).

%   A lone `a` after a word of a citation is the letter of a subsection,
%   not an article: `subsection_a_rate` is `subsection_a rate`.
letters([W0, W, a|Ws], [WA|Out]) :- atom_number(W, _), \+ atom_number(W0, _), !,     % section_501_a
    atomic_list_concat([W0, W, a], '_', WA), letters(Ws, Out).
letters([W, a|Ws], [WA|Out]) :- W \== is, W \== has, \+ atom_number(W, _), !, atom_concat(W, '_a', WA), letters(Ws, Out).
letters([W|Ws], [W|Out]) :- !, letters(Ws, Out).
letters([], []).

safe_word(if, when) :- !.
safe_word(W, W).

%!  reserved_safe(+Words, -Safe) is det.
%
%   A word a template cannot contain on its own. LE cuts a template off at a
%   reserved word of the language it is written in — `si` in French (`if`),
%   `attend` (`expects`), `sauf si` (`unless`) — and the rule that uses the
%   whole sentence is then left with no template at all. The word is kept
%   rather than dropped (it is part of the source's own name) and joined to
%   its neighbour with an underscore, which is one word and reserved in no
%   language: openfisca-france's `surplus_si_invalide` gives *surplus
%   si_invalide*. Found on `impot_revenu` (Phase 3b′, step 3).
reserved_safe(Ws0, Ws) :- reserved_safe_(Ws0, [], Ws).

reserved_safe_([], Acc, Ws) :- reverse(Acc, Ws).
reserved_safe_([W|Ws], Acc, Out) :-
    (   \+ reserved_template_word(W)
    ->  reserved_safe_(Ws, [W|Acc], Out)
    ;   Ws = [N|Rest]                      % joined to the word after it
    ->  atomic_list_concat([W, N], '_', WN), reserved_safe_([WN|Rest], Acc, Out)
    ;   Acc = [P|As]                       % the last word: to the one before
    ->  atomic_list_concat([P, W], '_', PW), reserved_safe_([], [PW|As], Out)
    ;   atom_concat(W, '_', W2), reserved_safe_([], [W2|Acc], Out)
    ).

%   The reserved words that end a template instance, in the language the twin
%   is written in (le_grammar:reserved_template_truncator/4): `if`, `only if`,
%   `unless`, `and unless`, `either`, `any of`, `all of`, `expects`. Asked of
%   LE2's own keyword table, so a language's list is never copied here. `and`
%   and `or` are not among them: a template may contain them (`enf3 et sup`).
reserved_template_word(W) :-
    nb_current(rs_lang, Lang),
    current_predicate(le_i18n:kw_synonym_words/3),
    member(Key, [if, only_if, unless, and_unless, either, any_of, all_of, expects]),
    catch(le_i18n:kw_synonym_words(Lang, Key, [W]), _, fail), !.

%   A place's words: no number (a template's place cannot hold one), and
%   at most its last two words.
place_words(Ws0, Ws) :-
    exclude([W]>>atom_number(W, _), Ws0, Ws1),
    (   Ws1 == [] -> Ws = [key]
    ;   length(Ws1, L), L > 2 -> append(_, [A, B], Ws1), Ws = [A, B]
    ;   Ws = Ws1
    ).

entity_noun(none, thing) :- !.
entity_noun(E, Noun) :-
    atom_codes(E, Cs), camel_words(Cs, Ws), atomic_list_concat(Ws, ' ', Noun).

camel_words([], []).
camel_words([C|Cs], [W|Ws]) :-
    take_word(Cs, Rest, Tail), atom_codes(W0, [C|Rest]), downcase_atom(W0, W), camel_words(Tail, Ws).
take_word([C|Cs], [C|R], T) :- \+ code_type(C, upper), !, take_word(Cs, R, T).
take_word(T, [], T).

article(Noun, Art) :-
    sub_atom(Noun, 0, 1, _, F), ( memberchk(F, [a, e, i, o, u]) -> Art = an ; Art = a ).

%   French: the head of a noun phrase is its first word ("montant brut");
%   the article by the writer's guess at its gender (writer_words.csv).
fr_value_noun(T, N) :-
    (   memberchk(T, ['Money', money]) -> N = montant
    ;   memberchk(T, ['Rate', rate]) -> N = taux
    ;   memberchk(T, ['Text', text, 'String', string]) -> N = code
    ;   memberchk(T, ['Date', date]) -> N = date
    ;   N = nombre
    ).

fr_definite(Word, Art) :-
    (   fr_plural(Word) -> Art = les        % (les pensions alimentaires, was le pensions)
    ;   le_i18n:with_le_language(fr, le_writer:definite_for(Word, Art))
    ).

%   A first word that reads as a plural: an ending in -s or -x, but not one of
%   the singular words that end so (le taux, le mois, le prix).
fr_plural(Word) :-
    atom(Word), atom_length(Word, L), L > 3,
    ( sub_atom(Word, _, 1, 0, s) ; sub_atom(Word, _, 1, 0, x) ),
    \+ memberchk(Word, [taux, prix, temps, pays, poids, corps, mois, choix, fois, repas, bras, dos, cours,
                        concours, recours, discours, secours, parcours, compris, tiers, avis, devis, permis,
                        abus, bonus, statut, revenu, prospectus, versus, rabais, relais, palais,
                        processus, consensus, virus, campus, corpus, sinus, minus, jus, cas, bois, croix,
                        voix, paix, noix, perdrix, flux, reflux, influx, index, lynx, sphinx, thorax, larynx]).

fr_indefinite(Noun, Art) :-
    atomic_list_concat([First|_], ' ', Noun),
    le_i18n:with_le_language(fr, le_writer:article_for(First, First, Art)).

value_noun(T, N) :-
    (   memberchk(T, ['Money', money]) -> N = amount
    ;   memberchk(T, ['Rate', rate]) -> N = rate
    ;   memberchk(T, ['Count', 'Integer', integer, int]) -> N = number
    ;   memberchk(T, ['Text', text, 'String', string]) -> N = text
    ;   memberchk(T, ['Date', date]) -> N = date
    ;   N = number
    ).

verbs([is, has, meets, qualifies, receives, satisfies, fails, passes, exceeds, includes, lives,
       claims, files, was, can, may, must, does, owns, pays, resides, elects, works, attends, needs,
       applies, participates, gets, qualified, received, are, have, uses, provides, requires, did,
       takes, would, will, should, makes, earns, holds, wants, chooses, counts, contributes]).

%   `member` is the reader's own word for the relation it writes between a
%   person and a group; the others are the package's own names.
fr_relation_word([member], membre) :- !.
fr_relation_word(Ws, P) :- atomic_list_concat(Ws, ' ', P).

%!  role_words(+Name, -Role, -Group) is semidet.
%
%   The reader's own name for the fact that a person holds a role in a group
%   (`is_declarant_in_foyer_fiscal`): the role, and the group it is held in.
role_words(N, Role, Group) :-
    words_of(N, [is|More]),
    append(RoleWs, [in|GroupWs], More),
    RoleWs \== [], GroupWs \== [],
    \+ memberchk(in, GroupWs),                  % the last `in`: the group is one entity
    atomic_list_concat(RoleWs, ' ', Role),
    atomic_list_concat(GroupWs, ' ', Group).

%!  judgment_text(+Name, +Entity, -Text) is det.
%   A role of a person in its group, in a French twin: *l'individu est
%   déclarant dans le foyer fiscal*, where the package's own words for the
%   role and the group are already French.
judgment_text(N, E, Text) :-
    nb_current(rs_lang, fr), E \== none,
    role_words(N, Role, Group), !,
    entity_noun(E, Noun), fr_indefinite(Noun, Art), fr_definite(Group, DA),
    format(string(Text), "*~w ~w* est ~w dans ~w ~w", [Art, Noun, Role, DA, Group]).
judgment_text(N, none, Text) :-
    nb_current(rs_judgment_subject, Subj), Subj \== none,
    words_of(N, Ws), Ws = [V|_], ( verbs(Vs), memberchk(V, Vs) ; memberchk(V, [est, a, peut, doit, remplit, 'bénéficie']) ), !,
    atomic_list_concat(Ws, ' ', W), format(string(Text), "~w ~w", [Subj, W]).
judgment_text(N, E, Text) :-
    nb_current(rs_lang, fr), !,
    words_of(N, Ws), atomic_list_concat(Ws, ' ', W),
    (   E == none
    ->  format(string(Text), "la condition ~w est remplie", [W])
    ;   entity_noun(E, Noun), fr_indefinite(Noun, Art),
        format(string(Text), "*~w ~w* remplit la condition ~w", [Art, Noun, W])
    ).
judgment_text(N, E, Text) :-
    words_of(N, Ws), verbs(Vs),
    (   E == none
    ->  atomic_list_concat(Ws, ' ', W), format(string(Text), "the rule ~w holds", [W])
    ;   entity_noun(E, Noun), article(Noun, Art), atomic_list_concat(NWs, ' ', Noun),
        (   Ws = [V|_], memberchk(V, Vs)
        ->  Pred = Ws, Subj = none
        ;   append(Pre, [V|Post], Ws), memberchk(V, Vs), Pre \== []
        ->  Pred = [V|Post], ( Pre == NWs -> Subj = none ; Subj = Pre )
        ;   Pred = [is|Ws], Subj = none
        ),
        atomic_list_concat(Pred, ' ', PT),
        (   Subj == none
        ->  format(string(Text), "*~w ~w* ~w", [Art, Noun, PT])
        ;   atomic_list_concat(Subj, ' ', ST),
            format(string(Text), "the ~w of *~w ~w* ~w", [ST, Art, Noun, PT])
        )
    ).

%   A value the case states for each period: the same sentence, with the
%   period named in it.
period_value_text(N, E, T, Text) :-
    nb_current(rs_lang, fr), !,
    words_of(N, Ws), atomic_list_concat(Ws, ' ', W),
    fr_value_noun(T, VN), fr_indefinite(VN, VA),
    Ws = [First|_], fr_definite(First, DA),
    (   E == none
    ->  format(string(Text), "~w ~w pour *une période* est *~w ~w*", [DA, W, VA, VN])
    ;   entity_noun(E, Noun), fr_indefinite(Noun, A),
        format(string(Text), "~w ~w de *~w ~w* pour *une période* est *~w ~w*", [DA, W, A, Noun, VA, VN])
    ).
period_value_text(N, E, T, Text) :-
    words_of(N, Ws), atomic_list_concat(Ws, ' ', W),
    value_noun(T, VN), article(VN, VA),
    (   E == none
    ->  format(string(Text), "the ~w for the period *a period* is *~w ~w*", [W, VA, VN])
    ;   entity_noun(E, Noun), article(Noun, A),
        format(string(Text), "the ~w of *~w ~w* for the period *a period* is *~w ~w*", [W, A, Noun, VA, VN])
    ).

period_judgment_text(N, E, Text) :-
    nb_current(rs_lang, fr), !,
    words_of(N, Ws), atomic_list_concat(Ws, ' ', W),
    (   E == none
    ->  format(string(Text), "la condition ~w est remplie pour *une période*", [W])
    ;   entity_noun(E, Noun), fr_indefinite(Noun, Art),
        format(string(Text), "*~w ~w* remplit la condition ~w pour *une période*", [Art, Noun, W])
    ).
period_judgment_text(N, E, Text) :-
    words_of(N, Ws), atomic_list_concat(Ws, ' ', W),
    (   E == none
    ->  format(string(Text), "the rule ~w holds for the period *a period*", [W])
    ;   entity_noun(E, Noun), article(Noun, Art),
        format(string(Text), "*~w ~w* is ~w for the period *a period*", [Art, Noun, W])
    ).

value_text(N, E, T, Text) :-
    nb_current(rs_lang, fr), !,
    words_of(N, Ws), atomic_list_concat(Ws, ' ', W),
    fr_value_noun(T, VN), fr_indefinite(VN, VA),
    Ws = [First|_], fr_definite(First, DA),
    (   E == none
    ->  format(string(Text), "~w ~w est *~w ~w*", [DA, W, VA, VN])
    ;   entity_noun(E, Noun), fr_indefinite(Noun, A),
        format(string(Text), "~w ~w de *~w ~w* est *~w ~w*", [DA, W, A, Noun, VA, VN])
    ).
value_text(N, E, T, Text) :-
    words_of(N, Ws), atomic_list_concat(Ws, ' ', W),
    value_noun(T, VN), article(VN, VA),
    (   E == none
    ->  format(string(Text), "the ~w is *~w ~w*", [W, VA, VN])
    ;   entity_noun(E, Noun), article(Noun, A),
        format(string(Text), "the ~w of *~w ~w* is *~w ~w*", [W, A, Noun, VA, VN])
    ).

table_text(N, By, T, Text) :-
    words_of(N, Ws), atomic_list_concat(Ws, ' ', W),
    words_of(By, BWs0), place_words(BWs0, BWs), atomic_list_concat(BWs, ' ', B), article(B, BA),
    value_noun(T, VN), article(VN, VA),
    format(string(Text), "the ~w for *~w ~w* is *~w ~w*", [W, BA, B, VA, VN]).

loaded_table_text(N, _By, T, Text) :-
    nb_current(rs_lang, fr), !,
    words_of(N, Ws), atomic_list_concat(Ws, ' ', W), Ws = [First|_], fr_definite(First, DA),
    fr_value_noun(T, VN), fr_indefinite(VN, VA),
    le_i18n:with_le_language(fr, le_tables:table_word(TW)),
    format(string(Text), "~w ~w pour *un code* est *~w ~w* selon la ~w ~w", [DA, W, VA, VN, TW, N]).
loaded_table_text(N, _By, T, Text) :-
    words_of(N, Ws), atomic_list_concat(Ws, ' ', W),
    value_noun(T, VN), article(VN, VA),
    format(string(Text), "the ~w for *a code* is *~w ~w* under table ~w", [W, VA, VN, N]).

%   The columns of such a table, as the reader's CSV file heads them.
loaded_table_columns(Cols) :- ( nb_current(rs_lang, fr) -> Cols = [code, valeur] ; Cols = [code, value] ).

dated_text(N, By, T, Text) :-
    words_of(N, Ws), atomic_list_concat(Ws, ' ', W),
    words_of(By, BWs0), place_words(BWs0, BWs), atomic_list_concat(BWs, ' ', B), article(B, BA),
    value_noun(T, VN), article(VN, VA),
    format(string(Text), "the ~w for *~w ~w* from *a first date* to *a last date* is *~w ~w*", [W, BA, B, VA, VN]).

%   In a French twin, the reader's own names — `member_of_<group>`,
%   `is_<role>_in_<group>` (of_extract.py) — are written in French too, so
%   that no sentence of the twin mixes the two languages.
relation_text(N, [A, B], Text) :-
    nb_current(rs_lang, fr), !,
    words_of(N, Ws), entity_noun(A, NA), entity_noun(B, NB),
    fr_indefinite(NA, AA), fr_indefinite(NB, AB),
    atomic_list_concat(NBWs, ' ', NB), atomic_list_concat(NAWs, ' ', NA),
    (   append(Pre, [of|NBWs], Ws), Pre \== []
    ->  fr_relation_word(Pre, P),
        format(string(Text), "*~w ~w* est ~w de *~w ~w*", [AA, NA, P, AB, NB])
    ;   append(Pre, [of|NAWs], Ws), Pre \== []
    ->  fr_relation_word(Pre, P),
        format(string(Text), "*~w ~w* est ~w de *~w ~w*", [AB, NB, P, AA, NA]),
        assertz(rel_swapped(N))
    ;   atomic_list_concat(Ws, ' ', W),
        format(string(Text), "*~w ~w* est lié à *~w ~w* par ~w", [AA, NA, AB, NB, W])
    ).
relation_text(N, [A, B], Text) :-
    words_of(N, Ws), entity_noun(A, NA), entity_noun(B, NB), article(NA, AA), article(NB, AB),
    atomic_list_concat(NBWs, ' ', NB), atomic_list_concat(NAWs, ' ', NA),
    (   append(Pre, [of|NBWs], Ws), Pre \== []
    ->  atomic_list_concat(Pre, ' ', P), format(string(Text), "*~w ~w* is a ~w of *~w ~w*", [AA, NA, P, AB, NB])
    ;   append(Pre, [of|NAWs], Ws), Pre \== []
    ->  atomic_list_concat(Pre, ' ', P), format(string(Text), "*~w ~w* is a ~w of *~w ~w*", [AB, NB, P, AA, NA]),
        assertz(rel_swapped(N))
    ;   atomic_list_concat(Ws, ' ', W), format(string(Text), "*~w ~w* is related to *~w ~w* by ~w", [AA, NA, AB, NB, W])
    ).

%   The functor of a symbol's template.
functor_of(N, F) :- atom_concat(rs_, N, F).

%   The literal of a symbol: Args the entity (when it has one) then the value.
lit(N, Args, L) :- functor_of(N, F), L =.. [F|Args].

%   The input that gives an overridable value instead of its rule.
given_name(N, GN) :-
    ( nb_current(rs_lang, fr) -> atom_concat(N, '_donné', GN) ; atom_concat(N, '_given', GN) ).

%   Whether a template has an entity place, and a value place.
shape(N, Ent, Val) :-
    sym(N, K, info(_, _, E, _)),
    (   K = parameter(none) -> Ent = no, Val = yes
    ;   K = parameter(by(_)) -> Ent = index, Val = yes
    ;   K = derived(judgment) -> ( E == none -> Ent = no ; Ent = yes ), Val = no
    ;   K = derived(scalar) -> ( E == none -> Ent = no ; Ent = yes ), Val = yes
    ;   K = input(judgment) -> ( E == none -> Ent = no ; Ent = yes ), Val = no
    ;   K = input(scalar) -> ( E == none -> Ent = no ; Ent = yes ), Val = yes
    ;   K = relation(_) -> Ent = two, Val = no
    ).

templates(Items) :-
    findall(N-K-I, sym(N, K, I), Syms),
    findall(T, ( member(N-K-I, Syms), template_item(N, K, I, T) ), Items00),
    findall(template(DF, Text, []),
            ( member(N-parameter(by(B))-info(_, R, _, T), Syms), R \== none, guarded(R),
              dated_functor(N, DF), dated_text(N, B, T, Text) ), Dated),
    append(Items00, Dated, Items0),
    (   uses_calculation_date
    ->  ( nb_current(rs_lang, fr)
          -> CD = "la date de calcul est *une date*"
          ;  CD = "the calculation date is *a date*" ),
        Items1 = [template(rs_calculation_date, CD, [undefined])|Items0]
    ;   Items1 = Items0
    ),
    (   uses(period_end, _, _)
    ->  ( nb_current(rs_lang, fr)
          -> CE = "la période de calcul se termine le *une date*"
          ;  CE = "the calculation period ends on *a date*" ),
        Items2 = [template(rs_calculation_end_date, CE, [undefined])|Items1]
    ;   Items2 = Items1
    ),
    period_templates(PItems),
    append(PItems, Items2, Items).

%   The periods a case names, and how they stand to one another: the period
%   the calculation is about, and the relations between periods the formulas
%   ask for (two years before, the month before, the year it falls in). Each
%   is a sentence the scenario states (roadmap Phase 3b′, item 1, decision
%   (a): a period is named by its text).
period_templates(Items) :-
    (   by_period(_)
    ->  ( nb_current(rs_lang, fr)
          -> C = "la période de calcul est *une période*"
          ;  C = "the calculation period is *a period*" ),
        findall(template(F, T, [undefined]),
                ( period_rel_used(K), period_rel_template(K, F, T) ), Rs),
        Items = [template(rs_calculation_period, C, [undefined])|Rs]
    ;   Items = []
    ).

period_rel_template(years_before, rs_period_years_before, T) :-
    ( nb_current(rs_lang, fr) -> T = "*une période* est *un nombre* années avant *une période*"
    ; T = "*a period* is *a number* years before *a period*" ).
period_rel_template(months_before, rs_period_months_before, T) :-
    ( nb_current(rs_lang, fr) -> T = "*une période* est *un nombre* mois avant *une période*"
    ; T = "*a period* is *a number* months before *a period*" ).
period_rel_template(year_of, rs_period_year_of, T) :-
    ( nb_current(rs_lang, fr) -> T = "*une période* est l'année de *une période*"
    ; T = "*a period* is the year of *a period*" ).
period_rel_template(last_3_months_of, rs_period_last_3_months_of, T) :-
    ( nb_current(rs_lang, fr) -> T = "*une période* est les trois mois avant *une période*"
    ; T = "*a period* is the three months before *a period*" ).
%   The same for any count of months: the count is a place, where three
%   months have a sentence of their own (openfisca-france reads the six
%   months before a month to see whether a child is financially independent).
period_rel_template(last_n_months_of, rs_period_last_n_months_of, T) :-
    ( nb_current(rs_lang, fr) -> T = "*une période* est les *un nombre* mois avant *une période*"
    ; T = "*a period* is the *a number* months before *a period*" ).
period_rel_template(twelve_months_from, rs_period_twelve_months_from, T) :-
    ( nb_current(rs_lang, fr) -> T = "*une période* est les douze mois à partir de *une période*"
    ; T = "*a period* is the twelve months from *a period*" ).
period_rel_template(first_month_of, rs_period_first_month_of, T) :-
    ( nb_current(rs_lang, fr) -> T = "*une période* est le premier mois de *une période*"
    ; T = "*a period* is the first month of *a period*" ).
period_rel_template(first_day, rs_period_first_day, T) :-
    ( nb_current(rs_lang, fr) -> T = "*une date* est le premier jour de *une période*"
    ; T = "*a date* is the first day of *a period*" ).
period_rel_template(month_of, rs_period_month_of, T) :-
    ( nb_current(rs_lang, fr) -> T = "*une période* est un mois de *une période*"
    ; T = "*a period* is a month of *a period*" ).

template_item(N, parameter(none), info(_, _, _, T), template(F, Text, [])) :-
    functor_of(N, F), value_text(N, none, T, Text).
%   A table by code kept as a CSV file beside the twin (a commune's zone,
%   openfisca-france): the template names the table, which binds it.
template_item(N, parameter(by(B)), info(_, R, _, T), template(F, Text, [])) :-
    R \== none, get_dict(table_file, R, _), !,
    functor_of(N, F), loaded_table_text(N, B, T, Text).
template_item(N, parameter(by(B)), info(_, _, _, T), template(F, Text, [])) :-
    functor_of(N, F), table_text(N, B, T, Text).
template_item(N, derived(scalar), info(_, R, E, T), template(F, Text, Adds)) :-
    by_period(N), !, functor_of(N, F), period_value_text(N, E, T, Text), memo_adds(R, Adds).
template_item(N, derived(judgment), info(_, R, E, _), template(F, Text, Adds)) :-
    by_period(N), !, functor_of(N, F), period_judgment_text(N, E, Text), memo_adds(R, Adds).
template_item(N, derived(scalar), info(_, R, E, T), template(F, Text, Adds)) :-
    functor_of(N, F), value_text(N, E, T, Text), memo_adds(R, Adds).
template_item(N, derived(judgment), info(_, R, E, _), template(F, Text, Adds)) :-
    functor_of(N, F), judgment_text(N, E, Text), memo_adds(R, Adds).
template_item(N, input(scalar), info(_, _, E, T), template(F, Text, [undefined])) :-
    by_period(N), !, functor_of(N, F), period_value_text(N, E, T, Text).
template_item(N, input(judgment), info(_, _, E, _), template(F, Text, [undefined])) :-
    by_period(N), !, functor_of(N, F), period_judgment_text(N, E, Text).
template_item(N, input(scalar), info(MId, _, E, T), template(F, Text, [undefined])) :-
    ( MId \== none ; nb_current(rs_lang, L), L \== en ), !,       % (an input declared with its type)
    functor_of(N, F), value_text(N, E, T, Text).
template_item(N, input(scalar), info(_, _, E, _), template(F, Text, [undefined])) :-
    functor_of(N, F), words_of(N, Ws), atomic_list_concat(Ws, ' ', W),
    input_noun(Ws, VN), article(VN, VA),
    (   E == none -> format(string(Text), "the ~w is *~w ~w*", [W, VA, VN])
    ;   entity_noun(E, Noun), article(Noun, A), format(string(Text), "the ~w of *~w ~w* is *~w ~w*", [W, A, Noun, VA, VN])
    ).

template_item(N, input(judgment), info(_, _, E, _), template(F, Text, [undefined])) :-
    functor_of(N, F), judgment_text(N, E, Text).
template_item(N, relation(As), _, template(F, Text, [undefined])) :-
    functor_of(N, F), relation_text(N, As, Text).
%   A value read many times by the rules that follow it (the states of a
%   Catala function, each reading the one before more than once): worked
%   out once per question (`; memorable`, language.md).
memo_adds(R, [memorable]) :- is_dict(R), get_dict(memorable, R, true), !.
memo_adds(_, []).

%   An input's kind of value, from the last word of its name that says one.
input_noun(Ws, N) :-
    reverse(Ws, Rs),
    (   member(W, Rs), word_noun(W, N) -> true ; N = value ).

word_noun(W, amount) :- memberchk(W, [income, pension, pensions, salary, deduction, deductions, amount, cost, costs, expenses, expense, compensation,
                                      wages, wage, earnings, pay, benefit, benefits, credit, tax, resources, payment, payments,
                                      allowance, rent, support, value, assets, liability, contribution, premium, gain, loss]).
word_noun(W, number) :- memberchk(W, [size, count, number, age, months, month, years, year, days, members, children, persons]).
word_noun(W, rate) :- memberchk(W, [fraction, rate, percent, percentage, share, ratio]).
word_noun(W, date) :- memberchk(W, [date]).
word_noun(W, code) :- memberchk(W, [status, code, type, kind, category, state, region, area]).

uses_calculation_date :-
    (   uses(period_start, _, _) -> true
    ;   sym(_, K, info(_, R, _, _)), K \= input(_), R \== none, guarded(R)
    ).

%   A rule whose versions need the calculation date: more than one, or one
%   that ends.
guarded(R) :- rule_versions(R, Vs), version_spans(Vs, Spans), member(_-G, Spans), G \== true, !.


		 /*******************************
		 *            RULES             *
		 *******************************/

module_items(_Options, module(Id, D), Items) :-
    title(Id, D, T),
    (   atom_string(Id, T) -> format(string(C), "~w", [Id]) ; format(string(C), "~w — ~w", [T, Id]) ),
    rules_of(D, Rs),
    findall(I, ( member(R, Rs), rule_name(R, N), sym(N, _, info(Id, _, _, _)), rule_items(N, R, Is), member(I, Is) ), Is0),
    module_documents(Id, Rs, Docs),
    (   Is0 == [] -> Items = [] ; append([blank, comment(C)|Docs], Is0, Items) ).

%   Each provision the module's rules cite is a document whose text is the
%   module's original in sources/ (it holds the provision's summary and every
%   rule's `source`), so a citation opens it and a quotation is checked
%   against it. A provision cited by an earlier module keeps that one.
module_documents(Id, Rs, Docs) :-
    source_file_rel(Id, Path),
    %  (a rule may name the file its citation opens: a Catala file's decree)
    findall(Doc-DP, ( member(R, Rs), provenance(R, P), member(as_stated_in(Doc), P),
                      ( get_dict(source_document, R, SD) -> atom_string(DP, SD) ; DP = Path ) ), Docs0),
    list_to_set(Docs0, Docs1),
    findall(document(Doc, [text(DP)]),
            ( member(Doc-DP, Docs1), \+ nb_current_doc(Doc), assert_doc(Doc) ), Docs).

:- dynamic doc_written/1.
nb_current_doc(Doc) :- doc_written(Doc).
assert_doc(Doc) :- assertz(doc_written(Doc)).

rule_items(N, R, Items) :-
    sym(N, K, _),
    (   K = parameter(_) -> parameter_items(N, K, R, Items0)
    ;   K = derived(P) -> derived_items(N, P, R, Items0)
    ;   K == derived_relation -> residue_items(N, R, 'a derived relation (a relation filtered by a judgment), which this translator does not read', Items0)
    ;   Items0 = []
    ),
    must_items(N, R, Musts),
    append(Items0, Musts, Items).

%!  must_items(+Name, +Rule, -Items) is det.
%
%   A rule's own assertions (`must`), as Logical English's integrity
%   constraints: what the law asserts about the values it reads (an
%   OpenFisca formula's `assert`, a Catala scope's `assertion`), and what
%   must not happen for the twin's answer to stand (two definitions of one
%   Catala variable applying at once, where Catala stops with a conflict).
%   A constraint's body holding is the violation, so each assertion is
%   written as its negation (language.md §3.3).
%   Written only when the build asks for it (`constraints(true)`), and here
%   is why. Logical English checks every integrity constraint when it answers
%   a question, so a constraint costs what its body costs on every answer.
%   The housing allowance's final aid is a chain of six states, each reading
%   the one before it two or three times, and it is already near the time
%   limit: with five constraints in the program — the law's own assertions,
%   each of them reading nothing but parameters — four of the nine test
%   scopes stopped answering. Measured on `apl_locatif`, 9 October 2026:
%   **49 of 49 answers with no constraints, 45 of 49 with five.** The twin
%   keeps its answers, which are the evidence it exists for, and the ledger
%   keeps the note. What this waits on is constraint checking that does not
%   pay the cost of the program again for each answer.
must_items(N, R, Items) :-
    (   nb_current(rs_constraints, true), get_dict(must, R, Ms0), is_list(Ms0)
    ->  rule_entity(R, E),
        findall(I, ( member(M, Ms0), once(must_item(N, E, M, I)) ), Items)
    ;   Items = []
    ).

must_item(N, E, M0, constraint(Body, [comment(C)])) :-
    format(atom(MA), '~w', [M0]),
    catch(parse_formula(MA, T), _, fail),
    ctx_for(E, X, Ctx),
    nb_setval(rs_period_kind, calc), b_setval(rs_period_var, _),
    catch(jbody(T, Ctx, B0), rs_residue(_), fail),
    negated(B0, B00),
    grounded(E, X, B00, B1), unwrap(B1, Body),
    (   nb_current(rs_lang, fr)
    ->  format(string(C), "~w : ce que la règle elle-même affirme ; un cas qui le contredit est refusé.", [N])
    ;   format(string(C), "~w: what the rule itself asserts; a case that contradicts it is refused, not answered.", [N])
    ).
must_item(N, _, M0, comment(C)) :-
    format(string(C), "The rule ~w asserts `~w`, which this translation does not write as a constraint.", [N, M0]).

%   The negation of a condition, without a double negative: the assertion
%   `not (a and b)` is violated when `a and b` holds.
negated(not(B), B) :- !.
negated(cmpgrp(not(B)), B) :- !.
negated(cmpgrp(B), cmpgrp(not(B))) :- !.
negated(B, not(B)).

%   The `source` field: `7 USC 2017(a), "30 per centum"` → the citation and
%   the quoted words.
provenance(R, P) :-
    (   get_dict(source, R, S0), S0 \== null
    ->  format(string(S), "~w", [S0]),
        (   sub_string(S, B, _, _, "\"")
        ->  sub_string(S, 0, B, _, Cit0), split_string(Cit0, "", " ,", [Cit]),
            sub_string(S, B, _, 0, Q0), split_string(Q0, "", "\" ", [Q]),
            ( Cit == "" -> P = [confer(Q)] ; P = [confer(Q), as_stated_in(Cit)] )
        ;   split_string(S, "", " ", [Cit]), P = [as_stated_in(Cit)]
        )
    ;   P = []
    ).

%   A table with dated versions: one fact per row and version, with the
%   version's dates, and one rule reading the row in force on the
%   calculation date.
%   A table by code in a CSV file of its own (the reader's
%   `<programme>.tables/`, copied beside the twin): its rows in the file, the
%   package's default for any other code as the last row, first match.
parameter_items(N, parameter(by(_)), R, [table(N, [loaded_from(File), policy(first), comment(C)], Cols, [])]) :-
    get_dict(table_file, R, File0), !,
    atom_string(File, File0), get_dict(source, R, C), loaded_table_columns(Cols).
parameter_items(N, parameter(by(_)), R, [Rule|Facts]) :-
    guarded(R), !,
    rule_versions(R, Vs), provenance(R, P),
    version_spans(Vs, Spans),
    dated_functor(N, DF),
    findall(fact(L, [provenance(P)]),
            ( member(V-Guard, Spans), span_dates(Guard, From, To),
              get_dict(values, V, Vals), dict_pairs(Vals, _, Rows), member(K-X0, Rows),
              index_value(K, KI), cell_value(X0, X), L =.. [DF, KI, From, To, X] ),
            Facts),
    lit(N, [K1, X1], Head),
    G =.. [DF, K1, F1, T1, X1],
    Rule = rule(Head, and(and(and(rs_calculation_date(D), G), le_le(F1, D)), le_le(D, T1)),
                [comment("The row in force on the calculation date, of the table's dated versions below.")]).
parameter_items(N, parameter(Ix), R, Items) :-
    rule_versions(R, Vs), provenance(R, P),
    version_spans(Vs, Spans),
    findall(I, ( member(V-Guard, Spans), parameter_version(N, Ix, V, Guard, P, I) ), Items0),
    (   Items0 == [] -> residue_items(N, R, 'a parameter without a value this translator reads', Items) ; Items = Items0 ).

parameter_version(N, none, V, Guard, P, Item) :-
    get_dict(formula, V, F), catch(parse_formula(F, T), _, fail),
    (   T = num(X) -> true ; T = neg(num(X0)), X is -X0 ),
    lit(N, [X], L),
    (   Guard == true -> Item = fact(L, [provenance(P)])
    ;   P == [] -> Item = rule(L, Guard, [])
    ;   Item = rule(L, Guard, [label(N), provenance(P)])
    ).
parameter_version(N, none, V, Guard, _P, Item) :-
    get_dict(formula, V, F), catch(parse_formula(F, T), _, fail),
    T \= num(_), T \= neg(num(_)),
    lit(N, [X], L),
    catch(top(T, X, ctx(none, none), Body0), rs_residue(_), fail),
    unwrap(Body0, Body1),
    and_guard(Guard, Body1, Body),
    Item = rule(L, Body, []).
parameter_version(N, by(_), V, Guard, P, Item) :-
    get_dict(values, V, Vals), dict_pairs(Vals, _, Rows), member(K-X0, Rows),
    index_value(K, KI), cell_value(X0, X),
    lit(N, [KI, X], L),
    (   Guard == true -> Item = fact(L, [provenance(P)]) ; Item = rule(L, Guard, []) ).

index_value(K, V) :- ( number(K) -> V = K ; atom_number(K, V) -> true ; atom_string(K, S), V = S ).
cell_value(X, X) :- number(X), !.
cell_value(X, V) :- ( atom_number(X, V) -> true ; string(X), number_string(V, X) -> true ; V = X ).

%   Each version with the guard that selects it: none when the rule has one
%   version open at its end; otherwise the calculation date on or after its
%   start, and before the next version's start or on or before its end.
version_spans([V], [V-true]) :-
    \+ ( get_dict(effective_to, V, To), To \== null ),
    version_from(V, From), From @< '2000-01-01', !.        % in force long before any test
version_spans(Vs, Spans) :-
    maplist([V, From-V]>>version_from(V, From), Vs, Ps0), msort(Ps0, Ps),
    spans(Ps, Spans).

version_from(V, From) :-
    ( get_dict(effective_from, V, F) -> true ; get_dict(from, V, F) -> true ; F = "0001-01-01" ),
    format(atom(From), '~w', [F]).

spans([], []).
spans([From-V|Rest], [V-Guard|Spans]) :-
    date_term(From, DF),
    G1 = and(rs_calculation_date(D), le_le(DF, D)),
    (   ( get_dict(effective_to, V, To0) ; get_dict(to, V, To0) ), To0 \== null
    ->  format(atom(To), '~w', [To0]), date_term(To, DT), Guard = and(G1, le_le(D, DT))
    ;   Rest = [Next-_|_]
    ->  date_term(Next, DN), Guard = and(G1, le_lt(D, DN))
    ;   Guard = G1
    ),
    spans(Rest, Spans).

dated_functor(N, F) :- atomic_list_concat([rs_, N, '_dated'], F).

%   The first and last day of a version, from its guard (an open end is the
%   last day of 9999).
span_dates(Guard, From, To) :-
    conj_list(Guard, Gs),
    member(le_le(From, D0), Gs), nonvar(From), var(D0), !,
    (   member(le_le(D1, To0), Gs), var(D1), nonvar(To0) -> To = To0
    ;   member(le_lt(D2, Next), Gs), var(D2), nonvar(Next) -> prev_day(Next, To)
    ;   To = date(9999, 12, 31)
    ).

conj_list(and(A, B), L) :- !, conj_list(A, LA), conj_list(B, LB), append(LA, LB, L).
conj_list(G, [G]).

prev_day(date(Y, M, D), date(Y1, M1, D1)) :-
    date_time_stamp(date(Y, M, D, 12, 0, 0, 0, -, -), S0), S is S0 - 86400,
    stamp_date_time(S, date(Y1, M1, D1, _, _, _, _, _, _), 'UTC').

date_term(A, date(Y, M, D)) :-
    atomic_list_concat([YA, MA, DA], '-', A), atom_number(YA, Y), atom_number(MA, M), atom_number(DA, D).

and_guard(true, B, B) :- !.
and_guard(G, B, Body) :-                % one list of conditions, as the writer lays it out
    conjuncts(G, Gs), conjuncts(B, Bs), append(Gs, Bs, [C|Cs]), and_fold(Cs, C, Body).

derived_items(N, _P, R, Items) :-
    get_dict(residue_reason, R, Why0), !,
    format(string(Why), "~w", [Why0]),
    residue_items(N, R, Why, Items).
derived_items(N, P, R, Items) :-
    rule_versions(R, Vs), provenance(R, Prov), rule_entity(R, E),
    version_spans(Vs, Spans), length(Spans, NS),
    catch(( findall(I, ( member(V-Guard, Spans), once(derived_version(N, P, E, V, Guard, Prov, I)) ), Itemss),
            ( length(Itemss, NS), NS > 0 -> append(Itemss, Items0), Res = ok(Items0) ; Res = failed ) ),
          rs_residue(Why), Res = residue(Why)),
    (   Res = ok(Items) -> true
    ;   Res = residue(W) -> why_text(W, WT), residue_items(N, R, WT, Items)
    ;   residue_items(N, R, 'a formula this translator could not read', Items)
    ).

%!  decided(+Tree0, -Tree) is det.
%
%   Inside a branch of `if C`, an inner `if C` is already decided: its own
%   branch replaces it (a reader of vector code writes such tests, from
%   `x = where(c, x, d)` read inside `where(c, ...)`).
decided(T, T) :- var(T), !.
decided(if(C, A0, B0), if(C, A, B)) :- !,
    assume(A0, C, true, A1), assume(B0, C, false, B1),
    decided(A1, A), decided(B1, B).
decided(T0, T) :- compound(T0), !,
    T0 =.. [F|As0], maplist(decided, As0, As), T =.. [F|As].
decided(T, T).

assume(T, _, _, T) :- var(T), !.
assume(if(C1, A, B), C, V, T) :- C1 == C, !,
    ( V == true -> assume(A, C, V, T) ; assume(B, C, V, T) ).
assume(T0, C, V, T) :- compound(T0), !,
    T0 =.. [F|As0], assume_all(As0, C, V, As), T =.. [F|As].
assume(T, _, _, T).

assume_all([], _, _, []).
assume_all([A0|As0], C, V, [A|As]) :- assume(A0, C, V, A), assume_all(As0, C, V, As).

why_text(format(F, A), T) :- !, format(string(T), F, A).
why_text(T, T).

derived_version(N, P, E, V, Guard, Prov, Items) :-
    get_dict(formula, V, F),
    (   catch(parse_formula(F, T0), _, throw(rs_residue('a formula this translator could not parse'))) -> true ; true ),
    decided(T0, T),
    ctx_for(E, X, Ctx),
    %  the period the rule is about: its own, when its template has a place
    %  for one, else the calculation period (Phase 3b′, item 1)
    ( by_period(N) -> nb_setval(rs_period_kind, own) ; nb_setval(rs_period_kind, calc) ),
    b_setval(rs_period_var, _Per),
    ( Prov == [] -> Opts = [] ; label_of(N, L), Opts = [label(L), provenance(Prov)] ),
    (   by_period(N) -> b_getval(rs_period_var, Per), Pre = [Per] ; Pre = [] ),
    (   P == judgment
    ->  head_args(E, X, Pre, Args), lit(N, Args, Head),
        jbody(T, Ctx, Body1), disjuncts(Body1, Ds)
    ;   append(Pre, [Val], Post), head_args(E, X, Post, Args), lit(N, Args, Head),
        top(T, Val, Ctx, Body21),
        (   by_period(N), overridable(N)
        ->  %  the rule works the value out for the period the calculation is
            %  about; for any other period the case gives it (Phase 3b′, item 1)
            and_guard(rs_calculation_period(Per), Body21, Body20)
        ;   Body20 = Body21
        ),
        (   overridable(N), given_name(N, GN), sym(GN, input(scalar), _)
        ->  %  the value the case gives, otherwise the rule's own
            lit(GN, Args, Given),
            ( Body20 = otherwise(Bs) -> Body2 = otherwise([Given|Bs]) ; Body2 = otherwise([Given, Body20]) )
        ;   Body2 = Body20
        ),
        Ds = [Body2]
    ),
    %  each alternative of a judgment a rule of its own, labelled in turn
    length(Ds, ND),
    alt_rules(Ds, 1, ND, Head, E, X, Guard, Opts, Items).

alt_rules([], _, _, _, _, _, _, _, []).
alt_rules([D|Ds], I, ND, Head, E, X, Guard, Opts, Items) :-
    D == fail, !,                 % (a judgment that never holds, an empty list: no rule)
    alt_rules(Ds, I, ND, Head, E, X, Guard, Opts, Items).
alt_rules([D|Ds], I, ND, Head, E, X, Guard, Opts, [Item|Items]) :-
    grounded(E, X, D, D1), unwrap(D1, D2), and_guard(Guard, D2, Body),
    alt_opts(Opts, ND, I, Opts1),
    copy_term(rule(Head, Body, Opts1), Item),
    I1 is I + 1,
    alt_rules(Ds, I1, ND, Head, E, X, Guard, Opts, Items).

label_of(N, N).

%   A body, or an alternative of its cascade, that names the entity in no
%   positive condition (`else: 0`, `not is_disqualified`) would answer for
%   any entity, or for none: it starts with `the household is a household`,
%   which each scenario states of its entities.
grounded(none, _, B, B) :- !.
grounded(E, X, otherwise(As), otherwise(Bs)) :- !, maplist(grounded(E, X), As, Bs).
grounded(_, X, B, B) :- positive_mention(B, X), \+ aggregate_first(B, X), !.
grounded(E, X, B, and(is_a(X, T), B)) :- entity_type(E, T).

%   An aggregate comes before any condition that names the subject: Logical
%   English would range it over every subject (the verifier warns), so the
%   subject is named first.
aggregate_first(B, X) :- conjuncts(B, Cs), first_relevant(Cs, X, agg).

first_relevant([C|Cs], X, R) :-
    (   sub_term(A, C), compound(A), A = agg(_, _, _, _) -> R = agg      % (also inside a comparison)
    ;   positive_mention(C, X) -> R = mention
    ;   first_relevant(Cs, X, R)
    ).

positive_mention(and(A, B), X) :- !, ( positive_mention(A, X) ; positive_mention(B, X) ).
positive_mention(or(A, B), X) :- !, positive_mention(A, X), positive_mention(B, X).
positive_mention(not(_), _) :- !, fail.
positive_mention(cmpgrp(B), X) :- !, positive_mention(B, X).
positive_mention(otherwise(As), X) :- !, forall(member(A, As), positive_mention(A, X)).
positive_mention(agg(_, _, _, _), _) :- !, fail.
positive_mention(G, X) :- compound(G), G =.. [F|Args], sub_atom(F, 0, _, _, rs_), member(A, Args), A == X, !.

entity_type(E, T) :- entity_noun(E, Noun), atomic_list_concat(Ws, ' ', Noun), atomic_list_concat(Ws, '_', T).

ctx_for(none, _, ctx(none, none)) :- !.
ctx_for(E, X, ctx(E, X)).

head_args(none, _, Vs, Vs) :- !.
head_args(_, X, Vs, [X|Vs]).

%   A residue block; and, for a value a case may give in place of the rule
%   (an overridable variable), the rule that reads the given value: the
%   block stands for the rest. Without it the value a case gives never
%   reached the variable (the RSA's daily allowances of the case's own
%   month, so the activity income of the prime d'activité answered 0).
residue_items(N, R, Why, Items) :-
    residue_block(N, R, Why, Block),
    (   overridable(N), given_name(N, GN), sym(GN, input(scalar), _), sym(N, derived(scalar), info(_, _, E, _))
    ->  ( by_period(N) -> Pre = [_Per] ; Pre = [] ), append(Pre, [_Val], Post),
        head_args(E, X, Post, Args), lit(N, Args, Head), lit(GN, Args, Given),
        grounded(E, X, Given, Body),
        Items = [Block, rule(Head, Body, [])]
    ;   Items = [Block]
    ).

residue_block(N, R, Why, residue(Id, [title(Title), note(Note), source(Lang, Src), concludes([F])])) :-
    nb_getval(rs_residues, K0), K is K0 + 1, nb_setval(rs_residues, K),
    format(atom(Id), 'r~w', [K]),
    assertz(residue_rule(N, Id)),
    functor_of(N, F),
    sym(N, Kind, info(MId, _, E, T)),
    format(string(Title), "~w#~w", [MId, N]),
    (   Kind = derived(judgment) -> judgment_text(N, E, Text) ; Kind = derived(scalar) -> value_text(N, E, T, Text) ; Text = N ),
    (   nb_current(rs_lang, fr)
    ->  format(string(Note), "Non traduit : ~w.~nConclusion attendue : ~w.", [Why, Text])
    ;   format(string(Note), "Not translated: ~w.~nConclude: ~w.", [Why, Text])
    ),
    (   get_dict(python_source, R, Py), Py \== "" -> Lang = 'Python', Src = Py    % read from another system's code
    ;   get_dict(catala_source, R, Ca), Ca \== "" -> Lang = 'Catala', Src = Ca
    ;   Lang = 'RuleSpec', yaml_text(R, Src)
    ).

yaml_text(R, Src) :-
    with_output_to(string(Src), yaml_write(current_output, R)).


		 /*******************************
		 *           FORMULAS           *
		 *******************************/

%!  top(+Tree, ?Value, +Ctx, -Body) is det.
%
%   The body of a rule whose head holds Value, the value of Tree: an
%   `if`/`elif`/`else` or a `match` is an otherwise cascade, one alternative
%   per branch; anything else is the conditions that read its names, then
%   the arithmetic.
top(T, V, Ctx, Body) :-
    alternatives(T, Ctx, Alts),
    assign_all(Alts, V, Bodies),
    ( Bodies = [B1] -> Body = B1 ; Body = otherwise(Bodies) ).

assign_all([], _, []).
assign_all([alt(Cs, Val)|As], V, [B|Bs]) :- assign(Cs, Val, V, B), assign_all(As, V, Bs).

%   (no findall: the alternatives share the entity's variable)
guard_each([], _, []).
guard_each([CB|CBs], TA, TAs) :- guard_all(TA, CB, TA1), guard_each(CBs, TA, TAs2), append(TA1, TAs2, TAs).

guard_all([], _, []).
guard_all([alt(G, X)|As], CB, [alt(and(CB, G), X)|Bs]) :- guard_all(As, CB, Bs).

%   alt(Conditions, ValueTerm)
alternatives(if(C, T, E), Ctx, Alts) :- !,
    jbody(C, Ctx, CB0), disjuncts(CB0, CBs),
    alternatives(T, Ctx, TA),
    guard_each(CBs, TA, TAs),
    alternatives(E, Ctx, EA),
    append(TAs, EA, Alts).
alternatives(nomatch, _, []) :- !.
alternatives(match(S, Arms, D), Ctx, Alts) :- !,
    match_if(S, Arms, D, If), alternatives(If, Ctx, Alts).
alternatives(T, Ctx, [alt(G, X)]) :-
    scalar(T, Ctx, X, Gs, []), conj(Gs, G).

match_if(_, [], none, nomatch) :- !.      % no `_` arm: no value, as the engine has none
match_if(_, [], D, D) :- !.
match_if(S, [P-V|As], D, if(cmp(==, S, P), V, E)) :- match_if(S, As, D, E).

assign(Cs, X, V, B) :-
    (   var(X) -> V = X, B0 = Cs
    ;   number(X) -> B0 = and(Cs, V is X)
    ;   string(X) -> B0 = and(Cs, V = X)
    ;   B0 = and(Cs, V is X)
    ),
    simplify(B0, B).

simplify(and(true, B), B1) :- !, simplify(B, B1).
simplify(and(A, true), A1) :- !, simplify(A, A1).
simplify(and(A, B), and(A1, B1)) :- !, simplify(A, A1), simplify(B, B1).
simplify(or(A, B), or(A1, B1)) :- !, simplify(A, A1), simplify(B, B1).
simplify(not(A), not(A1)) :- !, simplify(A, A1).
simplify(B, B).

conj([], true) :- !.
conj([G], G) :- !.
conj(Gs, G) :- dedupe(Gs, Gs1), and_fold(Gs1, true, G0), simplify(G0, G).

%   A name read twice in one conjunction is one condition.
dedupe([], []).
dedupe([G|Gs], [G|Out]) :-
    drop_same(Gs, G, Gs1),
    dedupe(Gs1, Out).

drop_same([], _, []).
drop_same([H|T], G, Out) :-
    (   same_read(G, H) -> Out = Out1 ; Out = [H|Out1] ),
    drop_same(T, G, Out1).

same_read(G1, G2) :-
    compound(G1), compound(G2),
    G1 =.. [F|A1], G2 =.. [F|A2], sub_atom(F, 0, _, _, rs_),
    append(K1, [V1], A1), append(K2, [V2], A2), K1 == K2,
    sym_of_functor(F, N), shape(N, _, yes),
    V1 = V2.

sym_of_functor(F, N) :- atom_concat(rs_, N, F).

%!  period_term(+Tree, -Period, +Goals0, ?Goals) is det.
%
%   The period a read names, and the conditions that bind it.
period_term(id(period), P, G0, G) :- !, own_period(P, G0, G).
period_term(call(years_before, [I, num(N)]), Q, G0, G) :- !,
    period_rel(years_before), period_term(I, P, G0, G1), G1 = [rs_period_years_before(Q, N, P)|G].
period_term(call(years_after, [I, num(N)]), Q, G0, G) :- !,
    period_rel(years_before), period_term(I, P, G0, G1), G1 = [rs_period_years_before(P, N, Q)|G].
period_term(call(months_after, [I, num(N)]), Q, G0, G) :- !,
    period_rel(months_before), period_term(I, P, G0, G1), G1 = [rs_period_months_before(P, N, Q)|G].
period_term(call(months_before, [I, num(N)]), Q, G0, G) :- !,
    period_rel(months_before), period_term(I, P, G0, G1), G1 = [rs_period_months_before(Q, N, P)|G].
period_term(call(year_of, [I]), Q, G0, G) :- !,
    period_rel(year_of), period_term(I, P, G0, G1), G1 = [rs_period_year_of(Q, P)|G].
period_term(call(last_3_months_of, [I]), Q, G0, G) :- !,
    period_rel(last_3_months_of), period_term(I, P, G0, G1), G1 = [rs_period_last_3_months_of(Q, P)|G].
period_term(call(last_n_months_of, [I, num(N)]), Q, G0, G) :- !,
    period_rel(last_n_months_of), period_term(I, P, G0, G1), G1 = [rs_period_last_n_months_of(Q, N, P)|G].
period_term(call(twelve_months_from, [I]), Q, G0, G) :- !,
    period_rel(twelve_months_from), period_term(I, P, G0, G1), G1 = [rs_period_twelve_months_from(Q, P)|G].
period_term(call(first_month_of, [I]), Q, G0, G) :- !,
    period_rel(first_month_of), period_term(I, P, G0, G1), G1 = [rs_period_first_month_of(Q, P)|G].
period_term(T, _, _, _) :-
    throw(rs_residue(format("a period this translator does not read: ~q", [T]))).

period_rel(K) :- ( period_rel_used(K) -> true ; assertz(period_rel_used(K)) ).

%   The period the rule being written is about.
own_period(P, G0, G) :-
    (   nb_current(rs_period_kind, own), b_getval(rs_period_var, P) -> G = G0
    ;   b_getval(rs_period_var, P), G0 = [rs_calculation_period(P)|G]
    ).

at_period_lit(V, Ctx, P, X, L) :-
    (   sym(V, K, info(_, _, E, _)) -> true
    ;   throw(rs_residue(format("~w, a name the translator cannot place", [V])))
    ),
    (   memberchk(K, [input(scalar), input(judgment), derived(scalar), derived(judgment)]) -> true
    ;   throw(rs_residue(format("~w read for another period, which is not a value of a case", [V])))
    ),
    entity_arg(E, Ctx, As),
    (   ( K = input(judgment) ; K = derived(judgment) )
    ->  append(As, [P], Args), X = judgment
    ;   append(As, [P, X], Args)
    ),
    lit(V, Args, L).

%!  scalar(+Tree, +Ctx, -Term, -Goals, ?Tail) is det.
%
%   Term the value of Tree as an arithmetic term over variables that Goals
%   bind.
scalar(num(N), _, N, G, G) :- !.
scalar(str(S), _, S, G, G) :- !.
scalar(bool(B), _, B, G, G) :- !.
%   The first day of the period the rule is worked out for: the calculation
%   date, or — in a rule that has a place for its period — the first day of
%   that period, which the case states (Phase 3b′, item 1).
scalar(id(period_start), _, D, G0, G) :- !,
    (   nb_current(rs_period_kind, own)
    ->  period_rel(first_day), b_getval(rs_period_var, P), G0 = [rs_period_first_day(D, P)|G]
    ;   G0 = [rs_calculation_date(D)|G]
    ).
scalar(id(period_end), _, D, [rs_calculation_end_date(D)|G], G) :- !.
scalar(id(N), Ctx, V, G0, G) :-                 % a yes-or-no value as a number: 1 or 0
    sym(N, K, _), ( K = derived(judgment) ; K = input(judgment) ), !,
    scalar(if(id(N), num(1), num(0)), Ctx, V, G0, G).
scalar(id(N), Ctx, V, G0, G) :- !, read_value(N, Ctx, V, G0, G).
%   A yes-or-no expression used as a number, not only a bare name: 1 or 0.
%   openfisca-france adds two of them together and reads the sum as a
%   condition (`(not majeur) + handicap`).
scalar(not(A), Ctx, V, G0, G) :- !, scalar(if(not(A), num(1), num(0)), Ctx, V, G0, G).
scalar(call(at_period, [id(N), PE]), Ctx, V, G0, G) :-
    sym(N, K, _), ( K = derived(judgment) ; K = input(judgment) ), !,
    scalar(if(call(at_period, [id(N), PE]), num(1), num(0)), Ctx, V, G0, G).
scalar(index(T, I), Ctx, V, G0, G) :- !,
    (   sym(T, parameter(by(_)), _) -> true ; throw(rs_residue(format("~w is not a table", [T]))) ),
    scalar(I, Ctx, IX, G0, G1),
    (   ( var(IX) ; number(IX) ) -> K = IX, G1 = [L|G] ; G1 = [K is IX, L|G] ),
    lit(T, [K, V], L).
scalar(bin(Op, A, B), Ctx, X, G0, G) :- !,
    scalar(A, Ctx, XA, G0, G1), scalar(B, Ctx, XB, G1, G),
    X =.. [Op, XA, XB].
scalar(neg(A), Ctx, -(XA), G0, G) :- !, scalar(A, Ctx, XA, G0, G).
%   The largest or smallest value over the members of a group: an aggregate.
scalar(call(F, [field(R, Fd)]), Ctx, X, [agg(F, FV, Goal, X)|G], G) :-
    memberchk(F, [max, min]), sym(R, relation(Args), _), !,
    Ctx = ctx(E, X0),
    rel_lit(R, Args, E, X0, Y, RL), known_name(Fd), lit(Fd, [Y, FV], FG),
    conj([RL, FG], Goal).
%   The largest or smallest value over the members of a group for whom a
%   condition holds (the youngest child of a family: openfisca-france reads a
%   group's aggregate with `role = Famille.ENFANT`).
scalar(call(F0, [id(R), id(Fd), id(P)]), Ctx, X, [agg(F, FV, Goal, X)|G], G) :-
    ( F0 == max_where -> F = max ; F0 == min_where -> F = min ; fail ), !,
    (   sym(R, relation(Args), _) -> true ; throw(rs_residue(format("~w is not a data relation", [R]))) ),
    Ctx = ctx(E, X0),
    rel_lit(R, Args, E, X0, Y, RL), known_name(Fd), lit(Fd, [Y, FV], FG),
    pred_lit(P, Y, PL),
    conj([RL, PL, FG], Goal).
%   A member's place among the members of its group (OpenFisca's
%   get_rank): how many members of the same group, for whom the condition
%   holds, have a smaller key.
scalar(call(rank_in_group, [id(R), id(K), id(C)]), Ctx, N, [RL, KL, agg(count, Y, Goal, N)|G], G) :-
    sym(R, relation(Args), _), Args = [A, _], Ctx = ctx(E, X0), A == E, !,
    rel_lit(R, Args, E, X0, Grp, RL), lit(K, [X0, KX], KL),
    rel_lit(R, Args, E, Y, Grp, RLY), lit(K, [Y, KY], KLY),
    (   C == none -> conj([RLY, KLY, KY < KX], Goal)
    ;   lit(C, [Y], CL), conj([RLY, CL, KLY, KY < KX], Goal)
    ).
%   The same for another period: the group the person is a member of, and
%   that group's value at the period the read names (openfisca-france's
%   `foyer_fiscal(\'rev_coll\', period.n_2)` read for each member of a
%   family, the means test of the family benefits). The reader writes this
%   expression itself, and the twin builder could not read it back.
scalar(field(R, call(at_period, [id(Fd), PE])), Ctx, V, [RL|G1], G) :-
    sym(R, relation(Args), _), Args = [A, _], Ctx = ctx(E, X0), A == E, !,
    rel_lit(R, Args, E, X0, Y, RL),
    period_term(PE, P, G1, G2),
    at_period_lit(Fd, ctx(none_, Y), P, V, L), G2 = [L|G].
%   A year of the group's value as the sum of its months, read from the
%   member's side (an [ADD] read through a relation).
scalar(field(R, call(sum_over_months, [id(Fd), PE])), Ctx, V, [RL|G1], G) :-
    sym(R, relation(Args), _), Args = [A, _], Ctx = ctx(E, X0), A == E, !,
    rel_lit(R, Args, E, X0, Y, RL),
    period_term(PE, P, G1, G2),
    period_rel(month_of),
    at_period_lit(Fd, ctx(none_, Y), M, Val, L),
    conj([rs_period_month_of(M, P), L], Goal),
    G2 = [agg(sum, Val, Goal, V)|G].
%   Any other call after the relation: the translator has no form for it, and
%   said so with a type error before (the RSA reads the members' rente
%   viagère over the months of the year before last).
scalar(field(_, call(F, _)), _, _, _, _) :- !,
    throw(rs_residue(format("~w of a group read through its members", [F]))).
%   A value of the group a member belongs to, read from the member's side
%   (OpenFisca's person.household("x", period)): the group the person is a
%   member of, and its value.
scalar(field(R, Fd), Ctx, V, [RL, FL|G], G) :-
    sym(R, relation(Args), _), Args = [A, _], Ctx = ctx(E, X0), A == E, !,
    rel_lit(R, Args, E, X0, Y, RL),
    known_name(Fd),
    (   sym(Fd, K, _), ( K = derived(judgment) ; K = input(judgment) )
    ->  throw(rs_residue(format("the judgment ~w of a group read as a number", [Fd])))
    ;   lit(Fd, [Y, V], FL)
    ).
scalar(call(F, As), Ctx, X, G0, G) :- memberchk(F, [max, min]), !,
    (   As == [] -> throw(rs_residue('max or min of nothing')) ; true ),
    scalars(As, Ctx, Xs, G0, G),
    Xs = [X1|Xr], fold_op(Xr, F, X1, X).

scalar(call(date, [str(S)]), _, date(Y, M, D), G, G) :- !,        % date("2019-01-01")
    split_string(S, "-", "", [YS, MS, DS]), maplist(number_string, [Y, M, D], [YS, MS, DS]).
%   The sum, over the individuals of a type for which a condition holds, of
%   a value of each (Catala's sum of a map over a list): the value read with
%   the individual as its subject.
scalar(call(sum_over, [id(Ent), id(Pred), Body]), Ctx, X, [agg(sum, V, Goal, X)|G], G) :- !,
    Ctx = ctx(_, _),
    lit(Pred, [Y], PL),
    scalar(Body, ctx(Ent, Y), V, BG, []),
    conj([PL|BG], Goal).
%   How many individuals of a type a condition holds of (Catala's `nombre
%   de` a list of structures, whose elements are individuals of the
%   structure's type and whose membership is a judgment about each).
scalar(call(count_over, [id(Ent), id(Pred)]), Ctx, X, [agg(count, Y, PL, X)|G], G) :- !,
    Ctx = ctx(_, _), _ = Ent,
    lit(Pred, [Y], PL).
%   The days from a date to a later one (a Catala duration in days).
scalar(call(days_between, [A, B]), Ctx, D, G0, G) :- !,
    scalar(A, Ctx, DA, G0, G1), scalar(B, Ctx, DB, G1, [le_is_days_after(DB, D, DA)|G]).
%   A date a number of months after another (a Catala duration, in months):
%   LE's `*a date* is *a number* months after *a date*`.
scalar(call(add_months, [A, N]), Ctx, L, G0, G) :- !,
    scalar(A, Ctx, DA, G0, G1), scalar(N, Ctx, XN, G1, [le_is_months_after(L, XN, DA)|G]).
%   An age in whole years from a date to another: the whole months between
%   them (LE's `*a date* is *a number* months after *a date*`), divided by 12.
scalar(call(whole_years, [A, B]), Ctx, M // 12, G0, G) :- !,
    scalar(A, Ctx, DA, G0, G1), scalar(B, Ctx, DB, G1, [le_is_months_after(DB, M, DA)|G]).
%   A value of another period: the period a read asks about, and the value
%   the case states for it (roadmap Phase 3b′, item 1). The period is the
%   rule's own — the calculation period, unless the rule has a period of its
%   own — or one a case names by its relation to it.
scalar(call(at_period, [id(V), PE]), Ctx, X, G0, G) :- !,
    period_term(PE, P, G0, G1),
    at_period_lit(V, Ctx, P, X, L), G1 = [L|G].
%   A year as the sum of its months (OpenFisca's [ADD] option).
scalar(call(sum_over_months, [id(V), PE]), Ctx, X, G0, G) :- !,
    period_term(PE, P, G0, G1),
    period_rel(month_of),
    at_period_lit(V, Ctx, M, Val, L),
    conj([rs_period_month_of(M, P), L], Goal),
    G1 = [agg(sum, Val, Goal, X)|G].
%   The whole months from a date to a later one (a difference of two dates
%   read as a number of months: openfisca-france's
%   `(fin - debut).astype('timedelta64[M]')`).
scalar(call(months_between, [A, B]), Ctx, M, G0, G) :- !,
    scalar(A, Ctx, DA, G0, G1), scalar(B, Ctx, DB, G1, [le_is_months_after(DB, M, DA)|G]).
scalar(call(floor, [A]), Ctx, floor(XA), G0, G) :- !, scalar(A, Ctx, XA, G0, G).
scalar(call(abs, [A]), Ctx, abs(XA), G0, G) :- !, scalar(A, Ctx, XA, G0, G).
scalar(call(round, [A]), Ctx, round(XA), G0, G) :- !, scalar(A, Ctx, XA, G0, G).
scalar(call(round, [A, num(0)]), Ctx, round(XA), G0, G) :- !, scalar(A, Ctx, XA, G0, G).
scalar(call(round, [A, num(D)]), Ctx, round(XA * P) / P, G0, G) :- integer(D), D > 0, !,
    P is 10^D, scalar(A, Ctx, XA, G0, G).
scalar(call(ceil, [A]), Ctx, ceiling(XA), G0, G) :- !, scalar(A, Ctx, XA, G0, G).
scalar(call(F, As), Ctx, X, G0, G) :- relation_call(F, As, R, Field0, Pred0), !,
    %   the sum of a yes-or-no value over the members: the members it holds of
    (   Pred0 == none, Field0 \== none, sym(Field0, K, _), ( K = derived(judgment) ; K = input(judgment) )
    ->  Field = none, Pred = Field0
    ;   Field = Field0, Pred = Pred0
    ),
    Ctx = ctx(E, X0),
    (   sym(R, relation(Args), _) -> true ; throw(rs_residue(format("~w reads ~w, which is not a data relation", [F, R]))) ),
    member_agg(R, Args, E, X0, Field, _, Op, Elem, All),
    (   Pred == none
    ->  G0 = [agg(Op, Elem, All, X)|G]
    ;   %   A test proved by several rules would count a member once per
        %   rule: all the members, less those that fail the test (a
        %   negation holds once).
        member_agg(R, Args, E, X0, Field, Y2, Op, Elem2, All2),
        pred_lit(Pred, Y2, PL),
        conj([All2, not(PL)], Fail),
        G0 = [agg(Op, Elem, All, N1), agg(Op, Elem2, Fail, N2)|G],
        X = N1 - N2
    ).
scalar(call(F, _), _, _, _, _) :- !,
    throw(rs_residue(format("the function ~w, which has no counterpart in this translation", [F]))).
scalar(if(C, T, E), Ctx, V, [otherwise(Bodies)|G], G) :- !,
    alternatives(if(C, T, E), Ctx, Alts),
    assign_all(Alts, V, Bodies).
scalar(match(S, Arms, D), Ctx, V, G0, G) :- !,
    match_if(S, Arms, D, If), scalar(If, Ctx, V, G0, G).
%   A yes-or-no expression used as a number (Python's True and False are 1
%   and 0): 1 when it holds, else 0.
scalar(T, Ctx, V, G0, G) :-
    functor(T, F, _), memberchk(F, [not, and, or, cmp]), !,
    scalar(if(T, num(1), num(0)), Ctx, V, G0, G).
scalar(T, _, _, _, _) :-
    throw(rs_residue(format("a value this translator does not read: ~q", [T]))).

%   The members Y of relation R and, with Field, their values: what an
%   aggregate Op counts or adds up.
member_agg(R, Args, E, X, Field, Y, Op, Elem, Goal) :-
    rel_lit(R, Args, E, X, Y, RL),
    (   Field == none -> Op = count, Elem = Y, FG = true
    ;   lit(Field, [Y, FV], FG), Op = sum, Elem = FV
    ),
    conj([RL, FG], Goal).

scalars([], _, [], G, G).
scalars([A|As], Ctx, [X|Xs], G0, G) :- scalar(A, Ctx, X, G0, G1), scalars(As, Ctx, Xs, G1, G).

%   The literal reading the value of name N.
read_value(N, Ctx, V, G0, G) :-
    (   sym(N, K, info(_, _, E, _)) -> true ; throw(rs_residue(format("~w, a name the translator cannot place", [N]))) ),
    %  a value the case states for each period, read without naming one: the
    %  period the rule is about — its own, when its template has a place for
    %  one, else the calculation period (Phase 3b′, item 1). `age` is read
    %  that way all over openfisca-france.
    (   by_period(N)
    ->  own_period(P, G0, G1), at_period_lit(N, Ctx, P, V, L), G1 = [L|G]
    ;   G0 = [L|G], read_lit(N, K, E, Ctx, V, L)
    ).

read_lit(N, K, E, Ctx, V, L) :-
    (   K = parameter(none) -> lit(N, [V], L)
    ;   K = parameter(by(_)) -> throw(rs_residue(format("the table ~w read without an index", [N])))
    ;   ( K = derived(scalar) ; K = input(scalar) )
    ->  entity_arg(E, Ctx, As), append(As, [V], Args), lit(N, Args, L),
        note_cross_entity(N, E, Ctx)
    ;   ( K = derived(judgment) ; K = input(judgment) )
    ->  throw(rs_residue(format("the judgment ~w read as a number", [N])))
    ;   throw(rs_residue(format("the relation ~w read as a value", [N])))
    ).

%   A rule of one entity reading a value another entity declares (the
%   engine evaluates it for the same identifier): kept, and noted in the
%   ledger.
note_cross_entity(N, E, ctx(CE, _)) :-
    (   E \== none, CE \== none, E \== CE, \+ cross_entity(N, CE, E)
    ->  assertz(cross_entity(N, CE, E))
    ;   true
    ).

entity_arg(none, _, []) :- !.
entity_arg(_, ctx(_, X), [X]) :- nonvar(X), !.
entity_arg(_, ctx(_, X), [X]).

rel_lit(R, [A, B], E, X, Y, L) :-
    (   A == E -> rel_args_lit(R, X, Y, L)
    ;   B == E -> rel_args_lit(R, Y, X, L)
    ;   rel_args_lit(R, Y, X, L)
    ).

%   The literal of relation R with its arguments in declared order: the
%   template's places are in that order, or the other way round when its
%   sentence names the second argument first (relation_text/3).
rel_args_lit(R, A, B, L) :-
    (   rel_swapped(R) -> lit(R, [B, A], L) ; lit(R, [A, B], L) ).

pred_lit(P, Y, L) :-
    (   sym(P, K, info(_, _, E, _)) -> true ; throw(rs_residue(format("~w, a name the translator cannot place", [P]))) ),
    (   ( K = derived(judgment) ; K = input(judgment) ) -> ( E == none -> lit(P, [], L) ; lit(P, [Y], L) )
    ;   throw(rs_residue(format("~w used as a condition but not a judgment", [P])))
    ).

%!  jbody(+Tree, +Ctx, -Body) is det.
%
%   The conditions under which the judgment Tree holds.
jbody(and(A, B), Ctx, and(BA, BB)) :- !, jbody(A, Ctx, BA), jbody(B, Ctx, BB).
jbody(or(A, B), Ctx, cmpgrp(Body)) :-              % x == "a" or x == "b" or …: x is in [a, b, …]
    or_leaves(or(A, B), Ls), length(Ls, N), N >= 3,
    maplist(eq_text, Ls, Ss, Vs), Ss = [S|Rest], maplist(==(S), Rest), !,
    scalar(S, Ctx, X, G0, [le_is_in(X, Vs)]), conj(G0, Body).
jbody(or(A, B), Ctx, or(BA, BB)) :- !, jbody(A, Ctx, BA), jbody(B, Ctx, BB).
jbody(not(A), Ctx, not(BA)) :- !, jbody(A, Ctx, BA).
jbody(bool(true), _, true) :- !.
jbody(bool(false), _, fail) :- !.
%   A number used as a condition holds when it is not zero (Python's rule,
%   which the reader leaves in place). A literal is decided here; anything
%   arithmetic — a sum of yes-or-no values, say — is compared with zero.
jbody(num(N), _, B) :- !, ( N =:= 0 -> B = fail ; B = true ).
jbody(bin(Op, A, B), Ctx, Body) :- !,
    jbody(cmp(\=, bin(Op, A, B), num(0)), Ctx, Body).
jbody(neg(A), Ctx, Body) :- !, jbody(cmp(\=, neg(A), num(0)), Ctx, Body).
jbody(cmp(==, A, bool(true)), Ctx, B) :- !, jbody(A, Ctx, B).
jbody(cmp(==, A, bool(false)), Ctx, not(B)) :- !, jbody(A, Ctx, B).
jbody(cmp(\=, A, bool(B0)), Ctx, B) :- !, ( B0 == true -> jbody(not(A), Ctx, B) ; jbody(A, Ctx, B) ).
jbody(cmp(Op, A, B), Ctx, cmpgrp(Body)) :- !,
    scalar(A, Ctx, XA, G0, G1), scalar(B, Ctx, XB, G1, [C]),
    comparison(Op, XA, XB, C),
    conj(G0, Body).
%   A yes-or-no value of another period.
jbody(call(at_period, [id(V), PE]), Ctx, cmpgrp(Body)) :-
    sym(V, K, _), ( K = input(judgment) ; K = derived(judgment) ), !,
    period_term(PE, P, G0, G1),
    at_period_lit(V, Ctx, P, _, L), G1 = [L],
    conj(G0, Body).
jbody(call(at_period, [id(V), PE]), Ctx, B) :- !,
    jbody(cmp(\=, call(at_period, [id(V), PE]), num(0)), Ctx, B).
%   The first characters of a text (a commune's code names its department:
%   `starts_with(the depcom, "971")`).
jbody(call(starts_with, [A, B]), Ctx, cmpgrp(Body)) :- !,
    scalar(A, Ctx, XA, G0, G1), scalar(B, Ctx, XB, G1, [le_starts_with(XA, XB)]),
    conj(G0, Body).
jbody(call(exactly_one, As), Ctx, Body) :- !,
    jbodies(As, Ctx, Bs),
    exactly_one_alts(Bs, Bs, 1, Alts),
    or_fold(Alts, fail, Or0), simplify_or(Or0, Body).

jbody(field(R, Fd), Ctx, and(RL, FL)) :-          % a yes-or-no value of the member's group
    sym(R, relation(Args), _), Args = [A, _], Ctx = ctx(E, X0), A == E, !,
    rel_lit(R, Args, E, X0, Y, RL),
    known_name(Fd),
    lit(Fd, [Y], FL).
jbody(id(N), Ctx, L) :- !,
    (   sym(N, K, info(_, _, E, _)) -> true ; throw(rs_residue(format("~w, a name the translator cannot place", [N]))) ),
    (   by_period(N), ( K = derived(judgment) ; K = input(judgment) )
    ->  %  a yes-or-no fact stated for each period, read without naming one
        own_period(P, G0, []), at_period_lit(N, Ctx, P, _, PL),
        conj(G0, GB), ( GB == true -> L = PL ; L = and(GB, PL) )
    ;   ( K = derived(judgment) ; K = input(judgment) )
    ->  entity_arg(E, Ctx, As), lit(N, As, L)
    ;   %   a number used as a condition holds when it is not zero (Python)
        jbody(cmp(\=, id(N), num(0)), Ctx, L)
    ).
jbody(if(C, T, E), Ctx, B) :- !,                % (a branch that is plain false drops out)
    jbody(C, Ctx, BC), jbody(T, Ctx, BT), jbody(C, Ctx, BC2), jbody(E, Ctx, BE),
    branch(BC, BT, A1), branch(not(BC2), BE, A2),
    (   A1 == fail -> B = A2 ; A2 == fail -> B = A1 ; B = or(A1, A2) ).

jbody(match(S, Arms, D), Ctx, B) :- !,           % a yes-or-no match: its cascade
    match_if(S, Arms, D, If), jbody(If, Ctx, B).
jbody(nomatch, _, fail) :- !.
jbody(index(T, K), Ctx, B) :- !,                 % a yes-or-no table: 1 or 0
    jbody(cmp(\=, index(T, K), num(0)), Ctx, B).
jbody(T, _, _) :-
    throw(rs_residue(format("a condition this translator does not read: ~q", [T]))).

branch(_, fail, fail) :- !.
branch(C, true, C) :- !.
branch(C, B, and(C, B)).

%   A name read from a member's group must be one the module declares.
known_name(N) :-
    (   sym(N, _, _) -> true ; throw(rs_residue(format("~w, a name the translator cannot place", [N]))) ).

or_leaves(or(A, B), Ls) :- !, or_leaves(A, LA), or_leaves(B, LB), append(LA, LB, Ls).
or_leaves(L, [L]).

eq_text(cmp(==, S, str(V)), S, V) :- !.
eq_text(cmp(==, str(V), S), S, V).

simplify_or(or(fail, B), B) :- !.
simplify_or(or(A, B), or(A1, B)) :- !, simplify_or(A, A1).
simplify_or(B, B).

comparison(<, A, B, A < B).
comparison(=<, A, B, A =< B).
comparison(>, A, B, A > B).
comparison(>=, A, B, A >= B).
comparison(==, A, B, C) :- ( ( string(A) ; string(B) ) -> C = (A = B) ; C = (A =:= B) ).
comparison(\=, A, B, C) :- ( ( string(A) ; string(B) ) -> C = (A \= B) ; C = not(A =:= B) ).


%   Helpers of scalar/5 and jbody/3.

%!  disjuncts(+Body, -Alternatives) is det.
%
%   A condition as a list of alternatives, each a conjunction (negations
%   pushed inward; a comparison, cmpgrp/1, is one unit, so a negation never
%   separates the reading of a value from its test). Past 12 alternatives
%   the condition is kept as it is, nested.
disjuncts(B, Ds) :-
    (   catch(dnf(B, Ds0), dnf_too_big, fail) -> Ds = Ds0 ; Ds = [B] ).

dnf(and(A, B), Ds) :- !, dnf(A, DA), dnf(B, DB),
    cross(DA, DB, Ds), too_big(Ds).
dnf(or(A, B), Ds) :- !, dnf(A, DA), dnf(B, DB), append(DA, DB, Ds), too_big(Ds).
dnf(not(A), Ds) :- !, neg(A, Ds).
dnf(otherwise(_), _) :- !, throw(dnf_too_big).
dnf(B, [B]).

%   (no findall: the alternatives keep their variables)
cross([], _, []).
cross([X|Xs], Ys, Ds) :- pair_with(Ys, X, D1), cross(Xs, Ys, D2), append(D1, D2, Ds).
pair_with([], _, []).
pair_with([Y|Ys], X, [and(X, Y)|Ds]) :- pair_with(Ys, X, Ds).

neg(and(A, B), Ds) :- !, dnf(or(not(A), not(B)), Ds).
neg(or(A, B), Ds) :- !, dnf(and(not(A), not(B)), Ds).
neg(not(A), Ds) :- !, dnf(A, Ds).
neg(true, [fail]) :- !.
neg(fail, [true]) :- !.
neg(B, [not(B)]).

too_big(Ds) :- length(Ds, N), ( N > 12 -> throw(dnf_too_big) ; true ).

unwrap(cmpgrp(B), B1) :- !, unwrap(B, B1).
unwrap(and(A, B), R) :- !,
    conjuncts(and(A, B), Cs0), maplist(unwrap, Cs0, Cs1), conjuncts_of(Cs1, Cs),
    and_fold(Cs, true, R0), simplify(R0, R).
unwrap(or(A, B), or(A1, B1)) :- !, unwrap(A, A1), unwrap(B, B1).
unwrap(not(A), not(A1)) :- !, unwrap(A, A1).
unwrap(otherwise(As), otherwise(Bs)) :- !, maplist(unwrap, As, Bs).
unwrap(agg(Op, E, G0, R), agg(Op, E, G, R)) :- !, unwrap(G0, G).   % (the body of a sum over a list)
unwrap(B, B).

%   A conjunction as the flat list of its conditions, left to right.


conjuncts(and(A, B), Cs) :- !, conjuncts(A, CA), conjuncts(B, CB), append(CA, CB, Cs).
conjuncts(true, []) :- !.
conjuncts(C, [C]).

conjuncts_of(Bs, Cs) :- maplist(conjuncts, Bs, Css), append(Css, Cs).

alt_opts(Opts, 1, _, Opts) :- !.
alt_opts(Opts0, _, I, Opts) :-
    (   select(label(L0), Opts0, Rest) -> format(atom(L), '~w_~w', [L0, I]), Opts = [label(L)|Rest]
    ;   Opts = Opts0
    ).

fold_op([], _, X, X).
fold_op([Y|Ys], F, A0, X) :- A1 =.. [F, A0, Y], fold_op(Ys, F, A1, X).
jbodies([], _, []).
jbodies([A|As], Ctx, [B|Bs]) :- jbody(A, Ctx, B), jbodies(As, Ctx, Bs).

%   exactly one of Bs: for each, it and not each other one
exactly_one_alts([], _, _, []).
exactly_one_alts([Bi|Rest], All, I, [Alt|Alts]) :-
    others_not(All, 1, I, Ns), and_fold(Ns, Bi, Alt),
    I1 is I + 1, exactly_one_alts(Rest, All, I1, Alts).

others_not([], _, _, []).
others_not([B|Bs], J, I, Ns) :- J1 is J + 1,
    ( J == I -> Ns = Ns1 ; Ns = [not(B)|Ns1] ), others_not(Bs, J1, I, Ns1).

and_fold([], A, A).
and_fold([X|Xs], A, R) :- and_fold(Xs, and(A, X), R).
or_fold([], A, A).
or_fold([X|Xs], A, R) :- or_fold(Xs, or(A, X), R).

		 /*******************************
		 *           QUERIES            *
		 *******************************/

%   One query per derived value or parameter a test of the twin reads.
queries(Items) :-
    findall(query(Q, G), ( wanted_output(N), query_goal(N, G), query_name(N, Q) ), Items0),
    sort(Items0, Items).

:- dynamic wanted_output/1.

query_name(N, Q) :- atom_concat(q_, N, Q).

query_goal(N, G) :-
    sym(N, K, info(_, _, E, _)),
    %  a variable worked out for a period has a place for it (its sentence
    %  is `... pour *une période* ...`): the query asks for the period the
    %  case is about, not for every period the case names (which answered
    %  `rfr` for the case's year and the two before it)
    ( by_period(N) -> Per = [P] ; Per = [] ),
    (   K = parameter(none) -> lit(N, [_], G0)
    ;   K = derived(scalar) -> append(Per, [_], Vs), head_args(E, _, Vs, As), lit(N, As, G0)
    ;   K = derived(judgment) -> head_args(E, _, Per, As), lit(N, As, G0)
    ),
    ( Per = [P] -> G = and(rs_calculation_period(P), G0) ; G = G0 ).


		 /*******************************
		 *            TESTS             *
		 *******************************/

tests(Id, Options, Tests) :-
    retractall(wanted_output(_)),
    module_file(Id, File),
    file_name_extension(Base, yaml, File), atom_concat(Base, '.test.yaml', TF),
    (   exists_file(TF) -> yaml_read(TF, Cases0), ( is_list(Cases0) -> Cases = Cases0 ; Cases = [] ) ; Cases = [] ),
    ( memberchk(oracle_runs(Run), Options) -> true ; Run = none ),
    source_file_rel(Id, Src0), atom_concat(Base0, '.yaml', Src0), atom_concat(Base0, '.test.yaml', Doc),
    findall(T, ( nth1(I, Cases, C), case_test(I, C, Run, Doc, T) ), Tests0),
    %  A case the reader wrote but the twin builder could not turn into a
    %  scenario is dropped by the findall above. Silence there reads as "the
    %  source had no tests", which is the one thing a twin must not say when
    %  it does: 434 cases of `impot_revenu` were lost that way. Say so.
    length(Cases, NC), length(Tests0, NT0),
    (   NC > 0, NT0 =:= 0
    ->  print_message(error, format("~w: ~w test cases read from ~w, none of which could be written as a scenario", [Id, NC, TF]))
    ;   NC > 0, NT0 < NC
    ->  ND is NC - NT0,
        print_message(warning, format("~w: ~w of ~w test cases could not be written as a scenario", [Id, ND, NC]))
    ;   true
    ),
    unique_names(Tests0, [], Tests).

%   Two cases of one name: the second and later ones numbered, so that each
%   scenario has a name of its own.
unique_names([], _, []).
unique_names([test(N0, D, L, F, E)|Ts], Seen, [test(N, D, L, F, E)|Us]) :-
    fresh_name(N0, Seen, 1, N),
    unique_names(Ts, [N|Seen], Us).

fresh_name(N0, Seen, K, N) :-
    (   K =:= 1 -> N1 = N0 ; format(atom(N1), '~w_~w', [N0, K]) ),
    (   memberchk(N1, Seen) -> K1 is K + 1, fresh_name(N0, Seen, K1, N) ; N = N1 ).

%   A key a test's input states: at the top, or in the record of a member.
stated_key(Pairs, K) :-
    member(K0-V, Pairs),
    (   K = K0
    ;   is_list(V), member(D, V), is_dict(D), dict_pairs(D, _, Ps), stated_key(Ps, K)
    ).

case_test(I, C, Run, Doc, test(Name, Doc, Loc, Facts, Expects)) :-
    ( get_dict(name, C, N0) -> atom_string(Name0, N0) ; format(atom(Name0), 'case_~w', [I]) ),
    case_name(Name0, Name),
    ( nb_current(rs_lang, fr) -> format(atom(Loc), 'cas ~w', [I]) ; format(atom(Loc), 'case ~w', [I]) ),
    ( get_dict(period, C, P) -> period_start(P, Start) ; Start = none ),
    ( get_dict(input, C, In) -> dict_pairs(In, _, InPairs0) ; InPairs0 = [] ),
    one_value_per_input(InPairs0, InPairs, Dropped),
    ( get_dict(output, C, Out) -> dict_pairs(Out, _, OutPairs) ; OutPairs = [] ),
    query_entity(OutPairs, QE),
    entity_constant(QE, 1, X),
    oracle_status(Run, I, Status0),
    (   stated_key(InPairs, K), key_local(K, KN), sym(KN, KS, _), ( KS = derived(_) ; KS = parameter(_) ),
        \+ overridable(KN)
    ->  format(atom(OW), 'the test states the value of ~w, which the program computes: the source lets a test override it, Logical English computes it from its rule', [KN]),
        Status = why(untranslated, OW)
    ;   Status = Status0
    ),
    %  the period the case is about, for a value it states without one of
    %  a variable whose sentence has a period place (input_facts/5)
    (   member(KP-VP, InPairs), key_atom(KP, 'input.calculation_period') -> period_value(VP, CP)
    ;   get_dict(period, C, VP), \+ is_dict(VP) -> period_value(VP, CP)   % (PolicyEngine's {start, end}: no period place to fill)
    ;   CP = none
    ),
    b_setval(rs_case_period, CP),
    findall(F, ( member(K-V, InPairs), input_facts(K, V, QE, X, Fs), member(F, Fs) ), Facts0),
    (   Start \== none, uses_calculation_date -> Facts1 = [rs_calculation_date(Start)|Facts0] ; Facts1 = Facts0 ),
    entity_type(QE, QT),
    findall(comment(Cm), ( member(K-V, Dropped),
                           format(string(Cm), "The test file also gives ~w the value ~w; the twin keeps the input's own key.", [K, V]) ), Cms),
    (   QE == none -> append(Facts1, Cms, Facts2) ; append([is_a(X, QT)|Facts1], Cms, Facts2) ),
    list_to_set(Facts2, Facts),
    findall(E, ( member(K-V, OutPairs), expectation(K, V, X, Status, E) ), Expects0),
    merge_expects(Expects0, Expects).

%   Two keys of a case naming one input with two values (one of them not an
%   `#input.` key): the twin keeps the input's own key and says so in the
%   scenario, rather than stating a value twice.
one_value_per_input(Pairs0, Pairs, Dropped) :-
    partition(dropped_key(Pairs0), Pairs0, Dropped, Pairs).

dropped_key(Pairs, K-V) :-
    \+ is_list(V),
    format(atom(KA), '~w', [K]), \+ sub_atom(KA, _, _, _, '#input.'),
    key_local(K, N),
    member(K2-V2, Pairs), K2 \== K, \+ is_list(V2), key_local(K2, N), V2 \== V, !.

case_name(N0, N) :-
    atom_codes(N0, Cs0),
    maplist([C0, C]>>( code_type(C0, alnum) -> C = C0 ; C = 0'_ ), Cs0, Cs),
    atom_codes(N, Cs).

period_start(P, date(Y, M, D)) :-
    (   is_dict(P), get_dict(start, P, S) -> format(atom(A), '~w', [S]), date_term(A, date(Y, M, D))
    ;   format(atom(A), '~w', [P]),
        (   atomic_list_concat([YA, MA], '-', A) -> atom_number(YA, Y), atom_number(MA, M), D = 1
        ;   atomic_list_concat([_, _, _], '-', A) -> date_term(A, date(Y, M, D))
        ;   atom_number(A, Y) -> M = 1, D = 1
        )
    ).

%   The entity of the case's derived outputs (the first one's).
query_entity(Outs, E) :-
    (   member(K-_, Outs), key_local(K, N), sym(N, derived(_), info(_, _, E0, _)), E0 \== none
    ->  E = E0
    ;   member(K-_, Outs), key_local(K, N), uses(N, _, E0), E0 \== none
    ->  E = E0
    ;   nb_current(rs_subject, none)
    ->  E = none                         % (Catala: a scope's values are the case's own)
    ;   E = 'Household'
    ).

entity_constant(E, I, C) :-
    entity_noun(E, Noun), atomic_list_concat(Ws, ' ', Noun), atomic_list_concat(Ws, '_', W),
    format(atom(C), '~w_~w', [W, I]).

key_local(K, N) :-
    format(atom(A), '~w', [K]),
    (   sub_atom(A, B, 1, _, '#') -> sub_atom(A, _, _, 0, F0), B1 is B + 1, sub_atom(A, B1, _, 0, F0) ; F0 = A ),
    (   atom_concat('input.', F, F0) -> N = F
    ;   atom_concat('relation.', F, F0) -> N = F
    ;   atom_concat('at_period.', F, F0) -> N = F
    ;   atom_concat('period_rel.', F, F0) -> N = F
    ;   N = F0
    ).

oracle_status(none, _, unknown) :- !.
oracle_status(Run, I, S) :-
    (   get_dict(cases, Run, Cs), nth1(I, Cs, C), get_dict(status, C, S0)
    ->  atom_string(S1, S0),
        ( get_dict(why, C, W) -> S = why(S1, W) ; S = S1 )
    ;   S = unknown
    ).

%   The facts of one input.
input_facts(_, V, _, _, []) :- V == null, !.     % (a test's empty value: not stated)
%   The period the case is about (roadmap Phase 3b′, item 1).
input_facts(K, V, _, _, [rs_calculation_period(P)]) :-
    key_atom(K, 'input.calculation_period'), !, period_value(V, P).
%   A value the case states for each period the calculation reads:
%   `{"2022": 12000, "2024": 15000}`, one sentence per period.
input_facts(K, V, QE, X, Facts) :-
    key_atom_prefix(K, 'at_period.', N0), is_dict(V), !,
    %  a value the package computes, which the case gives for each period
    %  (`rfr`): stated as the value given, which the rule reads first, not
    %  as the rule's own conclusion, which answered beside the one it works
    %  out (two answers for one period)
    (   overridable(N0), given_name(N0, GN), sym(GN, input(_), _) -> N = GN ; N = N0 ),
    (   sym(N, Kind, info(_, _, E, _)) -> true ; Kind = input(scalar), E = none ),
    input_targets(N, E, QE, X, Ts),
    dict_pairs(V, _, Ps),
    findall(F, ( member(P0-Val, Ps), period_value(P0, P), member(Y-E2, Ts),
                 at_period_fact(N, Kind, E2, Y, P, Val, Fs), member(F, Fs) ), Facts).
%   How the periods a case names stand to one another.
input_facts(K, V, _, _, Facts) :-
    key_atom_prefix(K, 'period_rel.', Kind0), is_list(V), !,
    atom_string(Kind, Kind0),
    %  only a relation a rule reads, which is one the program declares: the
    %  reader names the first day of every period a case names, and a twin
    %  none of whose rules reads it had no template for those sentences
    (   period_rel_used(Kind)
    ->  findall(F, ( member(Row, V), period_rel_fact(Kind, Row, F) ), Facts)
    ;   Facts = []
    ).
input_facts(K, V, _, _, Facts) :-
    key_atom_prefix(K, 'groups.', R), is_list(V), !,
    ( group_facts(R, V, Facts) -> true ; Facts = [] ).
input_facts(K, V, QE, X, Facts) :-
    key_local(K, N),
    (   atom_concat('individuals.', Ent, N), is_list(V)
    ->  %  individuals of another type than the case's subject (a Catala
        %  list's elements): each with its type and its inputs
        entity_type(Ent, ET),
        findall(F, ( nth1(I, V, It), entity_constant(Ent, I, Y),
                     ( F = is_a(Y, ET)
                     ; dict_pairs(It, _, Ps), member(K2-V2, Ps), key_local(K2, N2),
                       sym(N2, input(P2), info(_, _, E2, _)), input_fact(N2, P2, E2, Y, V2, Fs), member(F, Fs) ) ), Facts)
    ;   is_list(V)
    ->  relation_facts(N, V, QE, X, Facts)
    ;   sym(N, input(P), info(_, _, E, _))
    ->  input_targets(N, E, QE, X, Ts),
        %  (a value read for each period, stated without one: the value of
        %  the period the case is about, as overriding_fact/6 states it)
        (   by_period(N), nb_current(rs_case_period, CP), CP \== none
        ->  findall(F, ( member(Y-E2, Ts), at_period_fact(N, input(P), E2, Y, CP, V, Fs), member(F, Fs) ), Facts)
        ;   findall(F, ( member(Y-E2, Ts), input_fact(N, P, E2, Y, V, Fs), member(F, Fs) ), Facts)
        )
    ;   overridable(N), given_name(N, GN), sym(GN, input(P), info(_, _, E, _))
    ->  overriding_fact(GN, input(P), E, X, V, Facts)   % (the value a test gives a Catala context, in place of its rule's)
    ;   overridable(N), sym(N, derived(P), info(_, _, E, _))
    ->  overriding_fact(N, derived(P), E, X, V, Facts)  % (a value a rule gives, which a test may state: Catala's context)
    ;   Facts = []                       % an input no rule of the twin reads
    ).

%   A value a test gives a variable the package computes. When the
%   variable's sentence has a period place (openfisca-france's `rfr`, worked
%   out for a year), the value is the one of the period the case is about:
%   stated without a period, it asked for a sentence of one place fewer
%   than the program declares (63 of the income-tax twin's writer errors).
overriding_fact(N, Kind, E, X, V, Facts) :-
    (   by_period(N), nb_current(rs_case_period, CP), CP \== none
    ->  at_period_fact(N, Kind, E, X, CP, V, Facts)
    ;   Kind =.. [_, P], input_fact(N, P, E, X, V, Facts)
    ).

key_atom(K, A) :- format(atom(KA), '~w', [K]),
    ( sub_atom(KA, B, 1, _, '#') -> B1 is B + 1, sub_atom(KA, B1, _, 0, A) ; KA == A ).

key_atom_prefix(K, Pre, Rest) :- key_atom(K, A), atom_concat(Pre, Rest, A).

%   A period is named by its text: `2024`, `2024-03`.
period_value(V, P) :- ( number(V) -> format(atom(P), '~w', [V]) ; atom_string(P0, V), P = P0 ).

at_period_fact(N, input(judgment), E, X, P, V, Facts) :- !,
    ( truthy(V) -> head_args(E, X, [P], As), lit(N, As, L), Facts = [L] ; Facts = [] ).
at_period_fact(N, derived(judgment), E, X, P, V, Facts) :- !,
    ( truthy(V) -> head_args(E, X, [P], As), lit(N, As, L), Facts = [L] ; Facts = [] ).
at_period_fact(N, _, E, X, P, V0, [L]) :-
    (   ( V0 == true ; V0 == "true" ) -> V = 1
    ;   ( V0 == false ; V0 == "false" ) -> V = 0
    ;   cell_value(V0, V)
    ),
    head_args(E, X, [P, V], As), lit(N, As, L).

period_rel_fact(years_before, Row, rs_period_years_before(A, N, B)) :-
    row_list(Row, [A0, N, B0]), period_value(A0, A), period_value(B0, B).
period_rel_fact(months_before, Row, rs_period_months_before(A, N, B)) :-
    row_list(Row, [A0, N, B0]), period_value(A0, A), period_value(B0, B).
period_rel_fact(year_of, Row, rs_period_year_of(A, B)) :-
    row_list(Row, [A0, B0]), period_value(A0, A), period_value(B0, B).
period_rel_fact(last_3_months_of, Row, rs_period_last_3_months_of(A, B)) :-
    row_list(Row, [A0, B0]), period_value(A0, A), period_value(B0, B).
period_rel_fact(last_n_months_of, Row, rs_period_last_n_months_of(A, N, B)) :-
    row_list(Row, [A0, N, B0]), period_value(A0, A), period_value(B0, B).
period_rel_fact(twelve_months_from, Row, rs_period_twelve_months_from(A, B)) :-
    row_list(Row, [A0, B0]), period_value(A0, A), period_value(B0, B).
period_rel_fact(first_month_of, Row, rs_period_first_month_of(A, B)) :-
    row_list(Row, [A0, B0]), period_value(A0, A), period_value(B0, B).
period_rel_fact(month_of, Row, rs_period_month_of(A, B)) :-
    row_list(Row, [A0, B0]), period_value(A0, A), period_value(B0, B).
period_rel_fact(first_day, Row, rs_period_first_day(D, B)) :-
    row_list(Row, [A0, B0]), period_value(A0, A), date_term(A, D), period_value(B0, B).

row_list(Row, L) :- is_list(Row), !, L = Row.
row_list(Row, L) :- is_dict(Row), !, dict_pairs(Row, _, Ps), pairs_values(Ps, L).

%   Whom a value the case states at its top is about: the subject, when
%   the value is of the subject's kind; otherwise the case's group, when a
%   rule reads it of the group the subject is a member of (a household's
%   state, stated beside a person's facts), and the subject too when a rule
%   reads it of the subject. Neither: the subject.
input_targets(_, none, _, X, [X-none]) :- !.
input_targets(_, E, QE, X, [X-E]) :- E == QE, !.
input_targets(N, E, QE, X, Ts) :-
    findall(E2, ( E2 = E ; uses(N, _, E2) ), Es0), sort(Es0, Es),
    findall(Y-E2, ( member(E2, Es), E2 \== none, input_target(E2, QE, X, Y) ), Ts0), sort(Ts0, Ts1),
    (   Ts1 == [] -> Ts = [X-E] ; Ts = Ts1 ).

input_target(E, QE, X, X) :- E == QE, !.
input_target(E, QE, _, G) :-
    sym(_, relation([A, B]), _), A == QE, B == E, !,
    entity_constant(E, 1, G).
%   A group of another kind than the case's subject, related to it through
%   the person rather than to it directly (a family's people are the people
%   of a tax household): the one group of that kind the case has. Stated of
%   the subject instead, *le rev coll donné de famille_1*, the sentence was
%   one no rule matched — the rules read that value of the tax household —
%   and the means test of the family benefits answered 0.
input_target(E, QE, _, G) :-
    person_entity(P),
    sym(_, relation([PA, GA]), _), PA == P, GA == QE,
    sym(_, relation([PB, GB]), _), PB == P, GB == E, !,
    entity_constant(E, 1, G).

input_fact(N, judgment, E, X, V, Facts) :-
    (   truthy(V) -> head_args(E, X, [], As), lit(N, As, L), Facts = [L] ; Facts = [] ).
input_fact(N, scalar, E, X, V0, [L]) :-
    number_input_value(V0, V), head_args(E, X, [V], As), lit(N, As, L).

%   A value given to a place the rules read as a number: a yes or no there
%   is 1 or 0, as NumPy reads it (openfisca-france's `caseT`, a box of the
%   tax form multiplied by a rate). Stated as `false`, it left the sum it
%   enters unworked: the income-tax twin's number of parts.
number_input_value(V0, V) :-
    (   ( V0 == true ; V0 == "true" ) -> V = 1
    ;   ( V0 == false ; V0 == "false" ) -> V = 0
    ;   fact_value(V0, V)
    ).

truthy(true).
truthy("true").
truthy(N) :- number(N), N =\= 0.        % (a number given to a yes or no: OpenFisca's bool(1000))

fact_value(V0, V) :-
    (   number(V0) -> V = V0
    ;   V0 == true -> V = true
    ;   V0 == false -> V = false
    ;   string(V0), catch(date_term(V0, D), _, fail) -> V = D
    ;   atom(V0), catch(date_term(V0, D), _, fail) -> V = D
    ;   format(string(V), "~w", [V0])
    ).

%   The case's subject a member (a person's case, the members of its group
%   listed): one group, the items its members, the first of them the subject.
relation_facts(R, Items, QE, X, Facts) :-
    sym(R, relation(Args), _), Args = [A, B], A == QE, QE \== none,
    person_entity(PE), B \== PE, !,     % (a tax unit's people: the other clause)
    entity_type(B, BT), entity_type(A, AT),
    findall(F, ( nth1(I, Items, It), ( I == 1 -> M = X ; entity_constant(A, I, M) ),
                 item_group(B, It, G),
                 (   F = is_a(G, BT)
                 ;   I > 1, F = is_a(M, AT)
                 ;   rel_lit(R, Args, A, M, G, F)
                 ;   I > 1,                % (the subject's facts are the case's own)
                     dict_pairs(It, _, Ps), member(K-V, Ps), \+ item_key(K),
                     input_facts(K, V, A, M, Fs), member(F, Fs)
                 ) ), Facts0),
    ( Facts0 == [] -> entity_constant(B, 1, G1), Facts = [is_a(G1, BT)] ; Facts = Facts0 ).
%   The members of another group than the case's subject (a benefit unit's
%   case that names the household its people live in): that group, and the
%   same people, by their place in the lists, its members.
relation_facts(R, Items, QE, _, Facts) :-
    person_entity(PE),
    sym(R, relation(Args), _), Args = [PE, B], QE \== none, QE \== PE, B \== QE, !,
    entity_type(B, BT), entity_type(PE, PT),
    findall(F, ( nth1(I0, Items, It), item_place(It, I0, I), entity_constant(PE, I, Y),
                 item_group(B, It, G),
                 ( F = is_a(G, BT)
                 ; F = is_a(Y, PT)
                 ; lit(R, [Y, G], F)
                 ; dict_pairs(It, _, Ps), member(K-V, Ps), \+ item_key(K),
                   input_facts(K, V, PE, Y, Fs), member(F, Fs) ) ), Facts0),
    ( Facts0 == [] -> entity_constant(B, 1, G1), Facts = [is_a(G1, BT)] ; Facts = Facts0 ).
relation_facts(R, Items, QE, X, Facts) :-
    (   sym(R, relation(Args), _) -> true ; person_entity(PE0), Args = [PE0, QE] ),
    ( Args = [A, B], A == QE -> Other = B ; Args = [A, _] -> Other = A ),
    entity_type(Other, OT),
    findall(F, ( nth1(I0, Items, It), item_place(It, I0, I), entity_constant(Other, I, Y),
                 ( F = is_a(Y, OT)
                 ; rel_lit(R, Args, QE, X, Y, RL), F = RL
                 ; dict_pairs(It, _, Ps), member(K-V, Ps), \+ item_key(K),
                   input_facts(K, V, Other, Y, Fs), member(F, Fs) ) ), Facts).

%   Which person of the case an item of a group's list is: the item's own
%   `id` (its place among the case's people) when the reader gives one, so
%   that two groups listing the same people in different orders, or a group
%   of some of them, name the same individual; its place in the list
%   otherwise.
item_place(It, _, I) :- is_dict(It), get_dict(id, It, I), integer(I), !.
item_place(_, I, I).

%   The group of kind B an item's person is in: the item's `group` (its
%   place among the case's groups of that kind, when the case has several:
%   a family's two tax households), the first group otherwise.
item_group(B, It, G) :-
    ( is_dict(It), get_dict(group, It, GI), integer(GI) -> true ; GI = 1 ),
    entity_constant(B, GI, G).

%   The keys of an item that say which person and group it is, not a value.
item_key(K) :- memberchk(K, [id, entity_id, group]).

%   The values of each group of a kind the case has several of
%   (`groups.member_of_foyer_fiscal`: one record per group, in order).
group_facts(R, Groups, Facts) :-
    sym(R, relation([_, B]), _),
    entity_type(B, BT),
    findall(F, ( nth1(I, Groups, It), entity_constant(B, I, G),
                 ( F = is_a(G, BT)
                 ; is_dict(It), dict_pairs(It, _, Ps), member(K-V, Ps), input_facts(K, V, B, G, Fs), member(F, Fs) ) ),
            Facts).

%   An output: an expectation of the query named after it.
expectation(K, V, X, Status, Exp) :-
    key_local(K, N),
    sym(N, Kind, info(_, _, E, _)),
    (   Kind = parameter(by(_)) -> fail      % a table's row: the twin's facts are the table
    ;   true
    ),
    assertz(wanted_output(N)),
    query_name(N, Q),
    %  the answer of a variable worked out for a period names the case's
    %  period (an expectation of `rfr` without one was a sentence of one
    %  place fewer than the program declares: openfisca-france's income tax)
    (   by_period(N), nb_current(rs_case_period, CP), CP \== none -> Per = [CP] ; Per = [] ),
    (   Kind = derived(judgment)
    ->  judgment_value(V, J),
        ( J == holds -> head_args(E, X, Per, As), lit(N, As, L0),
                        ( Per = [CP] -> L = and(rs_calculation_period(CP), L0) ; L = L0 ),
                        Answers = [L]
        ; Answers = [] )
    ;   fact_value(V, Val), ( Kind = parameter(none) -> lit(N, [Val], L0) ; append(Per, [Val], Vs), head_args(E, X, Vs, As), lit(N, As, L0) ),
        %  the query asks for the case's period too (query_goal/2): its
        %  answer names both
        ( Per = [CP] -> L = and(rs_calculation_period(CP), L0) ; L = L0 ),
        Answers = [L]
    ),
    (   residue_rule(N, _) -> Exp0 = expects(Q, Answers)
    ;   Exp0 = expects(Q, Answers)
    ),
    (   Status == pass -> Exp = Exp0
    ;   Status == unknown -> Exp = Exp0
    ;   Status = why(pass, _) -> Exp = Exp0
    ;   Status = why(_, W) -> format(atom(Why), '~w', [W]), Exp = pending(Why, Exp0)
    ;   format(atom(Why), 'the engine does not reproduce this case of the test file (~w)', [Status]),
        Exp = pending(Why, Exp0)
    ).

judgment_value(V, J) :-
    (   V == true -> J = holds
    ;   V == false -> J = not_holds
    ;   format(atom(A), '~w', [V]), downcase_atom(A, J0), atomic_list_concat(Ps, '-', J0), atomic_list_concat(Ps, '_', J)
    ).

%   Two outputs read by one query in one case: one expectation, both answers.
merge_expects(Es0, Es) :-
    findall(Q, ( member(E, Es0), exp_query(E, Q) ), Qs0), list_to_set(Qs0, Qs),
    maplist(merged(Es0), Qs, Es).

merged(Es0, Q, E) :-
    findall(A, ( member(E0, Es0), exp_query(E0, Q), exp_answers(E0, As), member(A, As) ), All),
    once(( member(E1, Es0), exp_query(E1, Q) )),
    rebuild(E1, All, E).

exp_query(expects(Q, _), Q).
exp_query(pending(_, expects(Q, _)), Q).
exp_answers(expects(_, A), A).
exp_answers(pending(_, expects(_, A)), A).
rebuild(expects(Q, _), A, expects(Q, A)).
rebuild(pending(W, expects(Q, _)), A, pending(W, expects(Q, A))).


		 /*******************************
		 *            LEDGER            *
		 *******************************/

ledger(Modules, Ledger) :-
    findall(entry(El, Kind, Verdict, Mapping, InProgram, Note),
            ( member(module(MId, D), Modules), rules_of(D, Rs), member(R, Rs), rule_name(R, N),
              format(string(El), "~w#~w", [MId, N]),
              ledger_row(N, MId, R, Kind, Verdict, Mapping, InProgram, Note) ),
            L1),
    findall(entry(El, input, encoded, 'a name no rule defines -> a fact the scenario states', F, none),
            ( sym(N, input(_), info(none, _, _, _)), format(string(El), "input ~w", [N]), functor_of(N, F) ), L2),
    findall(entry(El, import, approximated, 'an imported module that is not here: the names it would define are inputs the scenario states', none, none),
            ( missing_import(MI), format(string(El), "import ~w", [MI]) ), L3),
    findall(entry(El, entity, approximated, M, F, none),
            ( cross_entity(N, CE, E), functor_of(N, F),
              format(string(El), "~w read by a rule of ~w", [N, CE]),
              format(string(M), "a value of ~w read for a ~w: the engine evaluates it for the same identifier, and so does the twin", [E, CE]) ), L4),
    append([L1, L2, L3, L4], Ledger).

ledger_row(N, MId, R, Kind, Verdict, Mapping, F, Note) :-
    get_dict(kind, R, K0), atom_string(Kind, K0),
    functor_of(N, F),
    (   \+ sym(N, _, info(MId, _, _, _))
    ->  ( sym(N, _, info(Other, _, _, _)) -> true ; Other = '?' ),
        Verdict = approximated, Mapping = 'a second definition of a name: the twin keeps the first module''s',
        format(string(Note), "defined first by ~w", [Other])
    ;   residue_rule(N, Id)
    ->  Verdict = residue, format(string(Mapping), "residue block ~w with the rule's YAML", [Id]), Note = none
    ;   Kind == source_relation
    ->  Verdict = encoded, Mapping = 'provenance: the citation is kept in sources/, not executed', Note = none
    ;   get_dict(approximated, R, A0)
    ->  Verdict = approximated, kind_mapping(Kind, R, Mapping), format(string(Note), "~w", [A0])
    ;   rule_versions(R, Vs), length(Vs, NV),
        (   guarded(R) -> format(string(VT), ", ~w version(s) guarded by the calculation date", [NV]) ; VT = "" ),
        (   get_dict(rounding, R, Rd), Rd \== null
        ->  Verdict = approximated, format(string(Note), "the engine rounds the output (~w); the twin does not", [Rd])
        ;   Verdict = encoded, Note = none
        ),
        kind_mapping(Kind, R, M0), format(string(Mapping), "~w~w", [M0, VT])
    ).

kind_mapping(parameter, R, M) :- !, ( get_dict(indexed_by, R, B), B \== null -> M = "indexed parameter -> one fact per row" ; M = "parameter -> a fact, cited" ).
kind_mapping(derived, R, M) :- !, rule_dtype(R, T), ( judgment_dtype(T) -> M = "derived judgment -> a rule concluding a sentence" ; M = "derived value -> a rule, the formula's names as conditions" ).
kind_mapping(data_relation, _, "data relation -> a two-place sentence the scenario states") :- !.
kind_mapping(derived_relation, _, "derived relation") :- !.
kind_mapping(input, R, M) :- !,
    (   get_dict(by_period, R, true)
    ->  M = "input of each period -> a sentence with a place for the period, which the scenario states for every period the calculation reads"
    ;   M = "input -> a fact the scenario states"
    ).
kind_mapping(_, _, "rule").

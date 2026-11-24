/** <module> L4 -> Logical English: the twin of an L4 program (its rules)

    Step 2 of the design notes l4.md (§3, §5, §8). An L4 program, read by
    l4_reader.pl, becomes a migration (le_migration.pl) in timeless LE:

      - a record type (`DECLARE T HAS f IS A U`) is a type of individuals;
        each field is a template of its own, `the f of *a t* is *a u*` (a
        function, language.md §2.4), or `*a t* has f` for a yes-or-no field.
        A record written in the program (`alice MEANS Person "Alice" 30`) or
        in a test is an individual with one fact per field;
      - a choice (`DECLARE T IS ONE OF A, B`) is a set of named individuals;
      - `DECIDE x IF …` and a `MEANS` that gives yes or no are rules
        concluding a template; a `MEANS` that gives a value is a rule of a
        function template, `… is *a value*`; the template's words come from
        the `@nlg` annotation, the mixfix name, the phrase name with its
        inputs put where the phrase names them, or the name with its inputs
        appended (flagged in the ledger for review);
      - `ASSUME` is a template the scenarios state (`; undefined`);
      - `IF`, `BRANCH` and `CONSIDER` are `otherwise` cascades (§17.2);
        `WHERE` and `LET` definitions are templates of their own, their
        enclosing function's inputs added as places;
      - arithmetic, comparisons, `all`/`any`/`elem` over a list, and the
        aggregates: `sum`, `length` and `count` over `map`/`filter`, and
        `map`/`filter` kept as a list (`the list of each … such that`);
      - what has no LE form (a function passed as a value, a record built
        inside a rule, text functions, the JSON and web builtins) is kept
        whole as a residue block, never dropped.

    The tests are L4's: every `#EVAL` and `#ASSERT` becomes a query with
    the evaluator's answer (runs/<Id>.json, l4_oracle.mjs). A program whose
    facts are `ASSUME`d has no tests the evaluator can run, so the
    translator writes variants of it — each ASSUME given a value — runs them
    through the evaluator (runs/variants/), and turns each into a scenario:
    every combination when a decision rests on at most eight yes-or-no
    facts, the all-true, all-false and one-flipped cases otherwise.

    The contracts half (`DEONTIC` definitions, `#TRACE`) is step 3's: when
    l4_contracts.pl is loaded, contract_items/4 there supplies its items
    (the hook below); otherwise each is a residue block.

    ## The hook for the contracts half

        l4_contracts:contract_items(+Ctx, -Items, -Tests, -Ledger)

    Ctx = ctx(Model, Options, Symbols): Model the reader's l4_module/2;
    Options those given to twin_migration/3 (target(prolog|lps) among them);
    Symbols the rules half's symbol table, a list of
    sym(Name, Kind, Functor/Arity, Text) (Kind pred | func | undefined),
    so a contract's PROVIDED condition can use the rules' templates. Items
    are Migration IR items, Tests le_migration tests, Ledger ledger entries,
    all appended to the rules half's.
*/

:- module(l4_twin, [
    twin_migration/3,      % +File, +Options, -Migration
    twin_name/2,           % +File, -Name
    l4_value_text/2,       % +OracleText, -Value
    l4_rules_file/1,       % ?CorpusId
    l4_twin_dir_name/2,    % +CorpusId, -Name
    variant_jobs/3,        % +File, +Model, -Jobs
    variants_hash/2        % +Jobs, -Hash
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(readutil)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(dcg/basics)).
:- use_module(library(crypto)).
:- use_module(l4_reader).
:- use_module(l4_print, []).
:- use_module(corpus, []).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).

:- dynamic here_/1.
:- prolog_load_context(directory, D), retractall(here_(_)), assertz(here_(D)).

:- thread_local
    sym_/2,              % Key, s(Kind, Params, Extra, ValType, F, Text)
    field_/3,            % RecType, FieldName, f(F, Bool, FieldType)
    rectype_/2,          % Type, [field(Name, Type)]
    enumcon_/3,          % Con, Type, Fields
    text_used_/1,        % template text
    functor_used_/1,
    template_/3,         % F/N, Text, Additions
    skeleton_/1,         % a template's words, its places as '*'

    item_/1,             % IR items, in order
    ledger_/1,
    counter_/2,
    recfact_/2,          % Id, Literal: facts of a record written in the program
    conpred_/2,          % Constructor, F: `*a t* is a c`
    all_name_/1,         % the words of every name the program defines
    contract_/1.         % a DEONTIC definition's name

		 /*******************************
		 *            ENTRY             *
		 *******************************/

%!  twin_name(+File, -Name) is det.
%   imaginary-alcohol-act.l4 -> imaginary_alcohol_act
twin_name(File, Name) :-
    file_base_name(File, B), file_name_extension(S, _, B),
    atom_codes(S, Cs), maplist([C, D]>>( code_type(C, alnum) -> D = C ; D = 0'_ ), Cs, Ds),
    atom_codes(N0, Ds), downcase_atom(N0, Name).

%!  l4_rules_file(?Id) is nondet.
%
%   The corpus files the rules half is built on (the design notes l4.md §8,
%   step 2), in the plan's order: the foundation course, the legal
%   examples, the advanced regulatory module, the reference examples of the
%   language (not its regulative keywords, which are step 3's, nor its
%   libraries and web builtins), and the Jersey charities law.
l4_rules_file(Id) :- member(Id, [foundation_hello, foundation_eligibility_rule, foundation_type_declaration,
                                 foundation_module_1_examples, foundation_module_2_examples,
                                 foundation_module_3_examples, foundation_module_4_examples,
                                 foundation_module_6_examples,
                                 legal_imaginary_alcohol_act, legal_anti_social, legal_british_citizen_act,
                                 legal_ny_environmental_7_3, legal_ceo_performance_award,
                                 advanced_module_a1_regulatory_examples,
                                 %  files with contracts have rules too (step 4's review)
                                 legal_promissory_note, foundation_sale_contract, foundation_charity_obligation,
                                 foundation_module_5_examples, advanced_module_a2_cross_cutting_examples,
                                 advanced_module_a3_contracts_examples]).
l4_rules_file(Id) :- l4_corpus:corpus_file(Id, _, reference), \+ sub_atom(Id, _, _, _, regulative),
                     \+ sub_atom(Id, _, _, _, libraries), \+ sub_atom(Id, _, _, _, http_json).
l4_rules_file(experiment_jerseycharities).

%!  l4_twin_dir_name(+Id, -Name) is det.
l4_twin_dir_name(Id, Name) :- l4_corpus:corpus_file(Id, Rel, _), twin_name(Rel, Name).

%!  twin_migration(+File, +Options, -Migration) is det.
%
%   Options: name(N), source_copy(Base) (the copy under sources/),
%   run(RunJson) (the evaluator's results for File; default runs/<Id>.json
%   by id(Id)), id(Id), variants(Dir) (the variants' results),
%   target(prolog|lps).
twin_migration(File, Options, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    reset,
    remember_source(File),
    l4_read_file(File, Model),
    Model = l4_module(Is, _),
    ( option(name(Name), Options) -> true ; twin_name(File, Name) ),
    ( option(source_copy(Copy), Options) -> true ; file_base_name(File, Copy) ),
    oracle_results(Options, Results),
    forall(( sub_term(T, Is), compound(T), ( T = decide(_, Sg, AF0, _, _, _) ; T = assume(Sg, AF0, _, _, _) ), af_name(Sg, AF0, N) ),
           ( name_words(N, NWs), assertz(all_name_(NWs)) )),
    declare_types(Is),
    register_defs(Is),
    computed_fields(Is),
    compile_defs(Is),
    atomic_list_concat(['sources/', Copy], CopyRel),
    Doc = 'the source program',
    directive_tests(Is, Results, Doc, Tests0),
    variant_tests(File, Model, Options, Doc, Tests1),
    contract_half(Model, Options, CItems, CTests, CLedger),
    append([Tests0, Tests1, CTests], Tests),
    findall(I, ( template_(F, T, A), template_item(F, T, A, I) ), Ts),
    findall(I, item_(I), Body0),
    findall(fact(L, []), recfact_(_, L), RecFacts),
    append([Ts, [document(Doc, [text(CopyRel)])], Body0, RecFacts, CItems], Items0),
    tests_queries(Tests, Items0, Items),
    findall(E, ledger_(E), Ledger0),
    append(Ledger0, CLedger, Ledger),
    format(string(C0), "The Logical English twin of an L4 program, written by the L4 translator~nfrom ~w (kept in sources/; L4 is Apache-2.0, Singapore Management University).~nEvery expected answer in the scenarios is L4's own evaluator's on the source.", [Copy]),
    option(target(Target), Options, prolog),
    ( template_(l4dd_serial/2, _, _) -> Incl = [includes([l4_daydate])] ; Incl = [] ),
    append([kb(Name), target(Target), comment(C0)], Incl, Header),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    Meta = [program(Name), source('an L4 program (smucclaw/l4-ide)'), artifacts([Copy]),
            translator('LE2 migration/l4 (l4_twin.pl)'), date(Date),
            licence('Apache-2.0, Singapore Management University')].

template_item(F, T, [function], function(F, T)) :- !.
template_item(F, T, [function|A], function(F, T, A)) :- !.
template_item(F, T, A, template(F, T, A)).

%   The program's own lines, for residue blocks
:- thread_local source_line_/2.
remember_source(File) :-
    retractall(source_line_(_, _)),
    read_file_to_string(File, S, [encoding(utf8)]),
    split_string(S, "\n", "", Ls),
    forall(nth1(I, Ls, L), assertz(source_line_(I, L))).

source_text(L1, L2, Text) :-
    findall(L, ( between(L1, L2, I), source_line_(I, L) ), Ls),
    atomic_list_concat(Ls, '\n', A), atom_string(A, Text).

%   What could not be translated, briefly: its L4 text where the reader can
%   print it
residue_detail(E, D) :-
    (   catch(with_output_to(string(D0), l4_print:ex(E)), _, fail) -> true
    ;   format(string(D0), "~q", [E])
    ),
    ( string_length(D0, N), N > 160 -> sub_string(D0, 0, 157, _, D1), string_concat(D1, "...", D) ; D = D0 ).

reset :-
    maplist(retractall, [sym_(_,_), field_(_,_,_), rectype_(_,_), enumcon_(_,_,_), text_used_(_),
                         functor_used_(_), template_(_,_,_), item_(_), ledger_(_), counter_(_,_),
                         recfact_(_,_), contract_(_), skeleton_(_), conpred_(_,_), all_name_(_)]).

oracle_results(Options, Results) :-
    (   option(run(F), Options) -> true
    ;   option(id(Id), Options), here_(H), atomic_list_concat([H, '/runs/', Id, '.json'], F)
    ),
    exists_file(F), !,
    setup_call_cleanup(open(F, read, S, [encoding(utf8)]), json_read_dict(S, D), close(S)),
    Results = D.results.
oracle_results(_, []).

ledger(E) :- assertz(ledger_(E)).

next(K, N) :- ( retract(counter_(K, N0)) -> true ; N0 = 0 ), N is N0 + 1, assertz(counter_(K, N)).

		 /*******************************
		 *            WORDS             *
		 *******************************/

%   The words of a name, as LE can read them: letters and digits kept, an
%   apostrophe dropped, anything else a space; a word lower-cased unless it
%   is an acronym (two or more capitals), so no word reads as a variable.
name_words(Name, Ws) :-
    format(string(S0), "~w", [Name]),
    split_camel(S0, S1),
    string_codes(S1, Cs0),
    exclude(==(0''), Cs0, Cs1),
    maplist([C, D]>>( code_type(C, alnum) -> D = C ; D = 0' ), Cs1, Cs),
    string_codes(S, Cs),
    split_string(S, " ", " ", Ws0), exclude(==(""), Ws0, Ws1),
    maplist(case_word, Ws1, Ws2),
    maplist(keyword_safe, Ws2, Wss), append(Wss, Ws).

%   LE's own words cannot stand inside a template
keyword_safe("if", ["whether"]) :- !.
keyword_safe("and", ["as", "well", "as"]) :- !.
keyword_safe("or", ["else"]) :- !.
keyword_safe("otherwise", ["else"]) :- !.
keyword_safe("unless", ["except", "when"]) :- !.
keyword_safe("then", ["next"]) :- !.
keyword_safe("which", ["what"]) :- !.
keyword_safe("either", ["one", "of"]) :- !.
keyword_safe(W, [W]).

case_word(W, W) :- string_length(W, L), L >= 2, string_upper(W, W), \+ string_lower(W, W), !.
case_word(W0, W) :- string_lower(W0, W).

%   isBOT -> is BOT; payMonthly -> pay Monthly (only a name with no space)
split_camel(S0, S) :-
    ( sub_string(S0, _, _, _, " ") -> S = S0
    ; string_codes(S0, Cs), camel(Cs, Ds), string_codes(S, Ds)
    ).
camel([A, B|T], [A, 0' |R]) :- code_type(A, lower), code_type(B, upper), !, camel([B|T], R).
camel([A|T], [A|R]) :- !, camel(T, R).
camel([], []).

words_text(Ws, T) :- atomic_list_concat(Ws, ' ', A), atom_string(A, T).

article(W, A) :- sub_atom(W, 0, 1, _, C), memberchk(C, [a, e, i, o, u]), !, A = an.
article(_, a).

articles(["the", "a", "an"]).

strip_article([A|Ws], Ws) :- articles(As), memberchk(A, As), !.
strip_article(Ws, Ws).

%   The noun a place of a template is named by: the parameter's own name
%   when it is a word (the part after a possessive: `the person's age` ->
%   age), else its type's.
slot_noun(Name, Type, Noun) :-
    format(string(S), "~w", [Name]),
    possessive_tail(S, After1), ( After1 \== none -> P = After1 ; P = S ),
    name_words(P, Ws0), strip_article(Ws0, Ws),
    (   Ws = [W], string_length(W, L), L =< 2 -> type_noun(Type, Noun)
    ;   Ws = [W|_], verb_word(W) -> type_noun(Type, Noun)
    ;   Ws = [W|_], memberchk(W, ["whether", "not", "as", "else"]) -> type_noun(Type, Noun)
    ;   Ws == [] -> type_noun(Type, Noun)
    ;   member(W, Ws), number_string(_, W) -> type_noun(Type, Noun)
    ;   words_text(Ws, Noun)
    ).

possessive_tail(S, T) :-
    (   sub_string(S, B, 3, _, "'s ") , \+ ( sub_string(S, B2, 3, _, "'s "), B2 > B )
    ->  B3 is B + 3, sub_string(S, B3, _, 0, T)
    ;   T = none
    ).

type_noun(tyapp('NUMBER', []), "number") :- !.
type_noun(tyapp('STRING', []), "text") :- !.
type_noun(tyapp('BOOLEAN', []), "boolean") :- !.
type_noun(tyapp('DATE', []), "date") :- !.
type_noun(tyapp('Date', []), "date") :- !.
type_noun(tyapp('LIST', _), "list") :- !.
type_noun(tyapp('MAYBE', [T]), N) :- !, type_noun(T, N).
type_noun(tyapp(T, _), N) :- !, name_words(T, Ws0), strip_article(Ws0, Ws),
    ( Ws == [] -> N = "thing" ; words_text(Ws, N) ).
type_noun(_, "value").

%   Places of one template: a noun used twice gets an ordinal.
slot_texts(Nouns, Slots) :- slot_texts(Nouns, [], Slots).
slot_texts([], _, []).
slot_texts([N|Ns], Seen, [S|Ss]) :-
    aggregate_all(count, member(N, Seen), K),
    ordinal(K, N, Phrase),
    format(string(S), "*~w*", [Phrase]),
    slot_texts(Ns, [N|Seen], Ss).

ordinal(0, N, P) :- !, sub_atom(N, 0, _, _, _), atom_string(A, N), article(A, Ar), format(string(P), "~w ~w", [Ar, N]).
ordinal(K, N, P) :- nth1(K, ["second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth"], O), !,
    format(string(P), "a ~w ~w", [O, N]).
ordinal(K, N, P) :- K1 is K + 1, format(string(P), "a ~w-th ~w", [K1, N]).

		 /*******************************
		 *            TYPES             *
		 *******************************/

declare_types(Is) :-
    forall(member(declare(_, appform(T, _, _, _), TD, _, _), Is), declare_type(T, TD)),
    forall(rectype_(T, Fs), declare_fields(T, Fs)).

declare_type(T, record(Fs0)) :- !,
    findall(field(N, Ty), member(field(N, Ty, _, _), Fs0), Fs),
    assertz(rectype_(T, Fs)),
    ledger(entry(T, record, encoded, 'a type of individuals, one template per field', T, '')).
declare_type(T, enum(Cs)) :- !,
    forall(member(con(C, Fs), Cs), assertz(enumcon_(C, T, Fs))),
    %  a constructor with fields is a kind of record: `*a t* is a c` and
    %  one template per field
    forall(( member(con(C, Fs0), Cs), Fs0 \== [] ),
           ( findall(field(N, Ty), member(field(N, Ty, _, _), Fs0), Fs),
             assertz(rectype_(C, Fs)),
             type_noun(tyapp(T, []), TN), atom_string(TA, TN), article(TA, Ar),
             name_words(C, CWs), words_text(CWs, CT), atom_string(CA, CT), article(CA, Ar2),
             format(string(Text), "*~w ~w* is ~w ~w", [Ar, TN, Ar2, CT]),
             fresh_functor([is, C], F),
             add_template(template, F/1, Text, []),
             text_skeleton(Text, Sk), assertz(skeleton_(Sk)),
             assertz(conpred_(C, F)) )),
    ledger(entry(T, choice, encoded, 'named individuals', T, '')).
declare_type(T, _) :-
    ledger(entry(T, type, encoded, 'a type', T, '')).

%   A computed field (`age IS A NUMBER MEANS current year - date of birth`)
%   is a rule: its value from the record's other fields
computed_fields(Is) :-
    forall(( member(declare(_, appform(T, _, _, _), record(Fs), _, pos(L1, L2)), Is),
             member(field(N, _, E, _), Fs), E \== none ),
           computed_field(T, N, E, L1-L2)).

computed_field(T, N, E, Lines) :-
    field_(T, N, f(F, Bool, _)),
    rectype_(T, Fs),
    field_env(Fs, R, Env),
    (   catch(( Bool == true -> Head =.. [F, R], cond(E, Env, G)
              ; val(E, Env, V, G), Head =.. [F, R, V] ), residue(Why, X), true)
    ->  (   var(Why) -> rule_item(Head, G, Item), assertz(item_(Item)),
                        ledger(entry(N, computed_field, encoded, 'a rule over the record''s other fields', T, ''))
        ;   residue_item(N, Why, X, Lines, F, pred, [R], [])
        )
    ;   residue_item(N, 'no LE form found', E, Lines, F, pred, [R], [])
    ).

field_env([], _, []).
field_env([field(FN, _)|Fs], R, [e(FN, rfield(R))|Env]) :- field_env(Fs, R, Env).

declare_fields(T, Fs) :-
    type_noun(tyapp(T, []), TN),
    forall(member(field(N, Ty), Fs),
           ( field_template(TN, N, Ty, Text, Bool),
             fresh_functor(['field', T, N], F),
             ( Bool == true -> Ar = 1 ; Ar = 2 ),
             ( Bool == true -> Kind = template ; Kind = function ),
             unique_text(Text, [T], Text1),
             text_skeleton(Text1, Sk), assertz(skeleton_(Sk)),
             add_template(Kind, F/Ar, Text1, []),
             assertz(field_(T, N, f(F, Bool, Ty))) )).

%   A yes-or-no field: `*a t* has f`, or `*a t* f` when f begins with a verb,
%   or the field's own phrase with the type's name put in its place
%   (`the applicant has valid ID`). Any other: `the f of *a t* is *a u*`.
field_template(TN, N, tyapp('BOOLEAN', []), Text, true) :- !,
    name_words(N, Ws0),
    atom_string(TA, TN), article(TA, Ar), format(string(Slot), "*~w ~w*", [Ar, TN]),
    split_string(TN, " ", "", TWs),
    (   substitute(Ws0, TWs, Slot, Ws) -> true
    ;   Ws0 = [W|_], verb_word(W) -> Ws = [Slot|Ws0]
    ;   Ws = [Slot, "has"|Ws0]
    ),
    words_text(Ws, Text).
field_template(TN, N, Ty, Text, false) :-
    name_words(N, Ws0),
    %  `the applicant's age` of an Applicant: age (the possessor is the
    %  record itself); `buyer's age` of a Purchase: age of the buyer
    format(string(NS), "~w", [N]),
    (   possessive_tail(NS, Tail), Tail \== none
    ->  name_words(Tail, TailWs),
        possessor_words(NS, PWs),
        split_string(TN, " ", "", TWs),
        (   ( PWs == [] ; append(_, PWs, TWs) )
        ->  Ws1 = TailWs
        ;   append(TailWs, ["of", "the"|PWs], Ws1)
        )
    ;   strip_article(Ws0, Ws1)
    ),
    ( Ws1 == [] -> Ws2 = Ws0 ; Ws2 = Ws1 ),
    type_noun(Ty, VN0), ( VN0 == TN -> format(string(VN), "second ~w", [VN0]), Ar2 = a ; VN = VN0, atom_string(VA, VN), article(VA, Ar2) ),
    atom_string(TA, TN), article(TA, Ar),
    words_text(Ws2, FW),
    format(string(Text), "the ~w of *~w ~w* is *~w ~w*", [FW, Ar, TN, Ar2, VN]).

possessive(N) :- format(string(S), "~w", [N]), sub_string(S, _, _, _, "'s ").

%   The words before the last "'s " of a name, without an article:
%   "the charity's status" -> [charity]
possessor_words(S, Ws) :-
    sub_string(S, B, 3, _, "'s "), \+ ( sub_string(S, B2, 3, _, "'s "), B2 > B ), !,
    sub_string(S, 0, B, _, P),
    name_words(P, Ws0), strip_article(Ws0, Ws).
possessor_words(_, []).

verb_word(W) :- memberchk(W, ["is", "has", "was", "can", "may", "must", "does", "did", "owns", "holds", "meets",
                              "qualifies", "requires", "affects", "provides", "shall", "will", "should", "needs",
                              "operates", "engages", "resides", "lives", "works", "pays", "receives", "earns"]).

%   Ws with the words Sub (after an optional article) replaced by Slot
substitute(Ws, Sub, Slot, Out) :-
    append(Pre, Rest0, Ws),
    (   Rest0 = [A|Rest1], articles(As), memberchk(A, As), append(Sub, After, Rest1)
    ;   append(Sub, After, Rest0)
    ),
    Sub \== [], !,
    append(Pre, [Slot|After], Out).

%   the words Sub, article included, replaced by Slot
substitute_exact(Ws, Sub, Slot, Out) :-
    append(Pre, Rest0, Ws), append(Sub, After, Rest0), !,
    append(Pre, [Slot|After], Out).

unique_text(Text0, Qual, Text) :-
    (   text_used_(Text0)
    ->  Qual = [Q|_], name_words(Q, QWs), words_text(QWs, QT),
        format(string(Text1), "~w in ~w", [Text0, QT]),
        ( text_used_(Text1) -> next(text, N), format(string(Text), "~w ~w", [Text1, N]) ; Text = Text1 )
    ;   Text = Text0
    ),
    assertz(text_used_(Text)).

fresh_functor(Parts, F) :-
    maplist([P, W]>>( name_words(P, PWs), atomic_list_concat(PWs, '_', W) ), Parts, Ws),
    atomic_list_concat([l4|Ws], '_', F0),
    downcase_atom(F0, F1),
    (   functor_used_(F1) -> next(functor, N), atomic_list_concat([F1, N], '_', F) ; F = F1 ),
    assertz(functor_used_(F)).

add_template(function, FA, Text, Adds) :- !,
    assertz(template_(FA, Text, [function|Adds])).
add_template(_, FA, Text, Adds) :-
    assertz(template_(FA, Text, Adds)).

		 /*******************************
		 *          DEFINITIONS         *
		 *******************************/

%   A definition's symbol: s(Kind, Params, Extra, ValType, F, Text)
%   Kind pred | func | recconst(Id) | undefined_pred | undefined_func |
%   contract; Params and Extra lists of p(Name, Type).

register_defs(Is) :-
    forall(member(I, Is), register_def(I, top)).

register_def(decide(_, Sig, AF, Body, Anns, _), Scope) :- !,
    af_name(Sig, AF, Name),
    (   is_contract(Sig, Body)
    ->  assertz(contract_(Name)), assertz(sym_(key(Scope, Name), s(contract, [], [], none, none, none)))
    ;   Scope == top, Sig = sig([], _), record_literal(Body)
    ->  record_id(Name, Id), assertz(sym_(key(Scope, Name), s(recconst(Id), [], [], none, none, none)))
    ;   Scope == top, Sig = sig([], _), Body = list(Es), Es \== [], forall(member(E, Es), record_literal(E))
    ->  record_id(Name, Id), assertz(sym_(key(Scope, Name), s(reclist(Id), [], [], none, none, none)))
    ;   def_params(Sig, AF, Ps0),
        infer_param_types(Ps0, Body, Ps),
        def_kind(Sig, Body, Ps, Kind),
        guess_sig(Sig, Body, Sig1),
        make_symbol(Name, Kind, Ps, [], Sig1, AF, Anns, Scope)
    ).
register_def(assume(Sig, AF, Type, Anns, _), Scope) :- !,
    af_name(Sig, AF, Name),
    (   Type == type -> true
    ;   Type = fun(ArgTs, ResT)
    ->  maplist([T, p(N, T)]>>( next(arg, K), atom_concat(x, K, N) ), ArgTs, Ps),
        ( ResT == tyapp('BOOLEAN', []) -> K2 = undefined_pred ; K2 = undefined_func ),
        make_symbol(Name, K2, Ps, [], sig(Ps, ResT), AF, Anns, Scope)
    ;   def_params(Sig, AF, Ps),
        ( Type == tyapp('BOOLEAN', []) -> K2 = undefined_pred ; K2 = undefined_func ),
        Sig = sig(G, _), make_symbol(Name, K2, Ps, [], sig(G, Type), AF, Anns, Scope)
    ).
register_def(_, _).

is_contract(sig(_, tyapp('DEONTIC', _)), _) :- !.
is_contract(_, Body) :- sub_term(T, Body), compound(T), T = deontic(_, _, _, _, _, _, _), !.

%   A value's type, when GIVETH does not say it
guess_sig(sig(Gs, none), Body, sig(Gs, T)) :- guess_type(Body, T), !.
guess_sig(Sig, _, Sig).

guess_type(str(_), tyapp('STRING', [])).
guess_type(num(_), tyapp('NUMBER', [])).
guess_type(E, tyapp('NUMBER', [])) :- arith_op(E), !.
guess_type(list(_), tyapp('LIST', [])).
guess_type(if(_, T, E), Ty) :- ( guess_type(T, Ty) -> true ; guess_type(E, Ty) ).
guess_type(branch([_-T|_], _), Ty) :- guess_type(T, Ty).
guess_type(where(E, _), Ty) :- guess_type(E, Ty).
guess_type(let(_, E), Ty) :- guess_type(E, Ty).
guess_type(consider(_, [when(_, E)|_]), Ty) :- guess_type(E, Ty).
guess_type(app(T, _), tyapp(T, [])) :- rectype_(T, _).
guess_type(app(sum, _), tyapp('NUMBER', [])).
guess_type(app(N, _), G) :- sym_(key(_, N), s(K, _, _, G, _, _)), memberchk(K, [func, undefined_func]), G \== none, !.
guess_type(app(length, _), tyapp('NUMBER', [])).

def_params(sig(Gs, _), _, Ps) :- Gs \== [], !,
    findall(p(N, T), member(param(N, T, _), Gs), Ps).
%   a definition after the first under one GIVEN: its inputs are the names
%   after its own (their types found from the fields its body reads)
def_params(_, appform(_, Args, _, _), Ps) :-
    findall(p(A, none), ( member(A, Args), atom(A) ), Ps).

%   The type of an input that GIVEN does not say: the record whose field
%   the body reads from it
infer_param_types(Ps0, Body, Ps) :-
    maplist(infer_param(Body), Ps0, Ps).
infer_param(Body, p(N, none), p(N, T)) :-
    sub_term(proj(app(N, []), F), Body), field_(RT, F, _), !, T = tyapp(RT, []).
infer_param(_, P, P).

def_kind(sig(_, tyapp('BOOLEAN', [])), _, _, pred) :- !.
def_kind(sig(_, G), _, _, func) :- G \== none, !.
def_kind(_, Body, Ps, K) :-
    findall(e(N, var(_, T)), member(p(N, T), Ps), Env),
    ( is_bool(Body, Env) -> K = pred ; K = func ).

record_literal(app(T, Args)) :- rectype_(T, Fs), length(Fs, N), length(Args, N), !.
record_literal(app_named(T, _)) :- rectype_(T, _), !.

record_id(Name, Id) :-
    name_words(Name, Ws), atomic_list_concat(Ws, '_', Id0), downcase_atom(Id0, Id).

make_symbol(Name, Kind, Ps, Extra, Sig, AF, Anns, Scope) :-
    Sig = sig(_, G0),
    ( memberchk(Kind, [func, undefined_func]) -> G = G0 ; G = tyapp('BOOLEAN', []) ),
    ( Scope = local(_, Parent) -> Qual = [Parent] ; Qual = [Name] ),
    def_text(Name, Kind, Ps, Extra, G, AF, Anns, [], Text0, How0),
    text_skeleton(Text0, Sk0),
    (   clash(Sk0), Qual = [QN], QN \== Name
    ->  name_words(QN, QWs),
        def_text(Name, Kind, Ps, Extra, G, AF, Anns, ["in"|QWs], Text00, How)
    ;   Text00 = Text0, How = How0
    ),
    unique_words(Kind, Text00, Qual, Text1),
    unique_text(Text1, Qual, Text),
    text_skeleton(Text, Sk), assertz(skeleton_(Sk)),
    fresh_functor([Name], F),
    append(Extra, Ps, All), length(All, N0),
    ( memberchk(Kind, [func, undefined_func]) -> N is N0 + 1 ; N = N0 ),
    %  only a record's fields are written in the short form of a function:
    %  a definition's value nested in another's phrase can read two ways
    TK = template,
    ( memberchk(Kind, [undefined_pred, undefined_func]) -> Adds = [undefined] ; Adds = [] ),
    add_template(TK, F/N, Text, Adds),
    assertz(sym_(key(Scope, Name), s(Kind, Ps, Extra, G, F, Text))),
    (   How == appended
    ->  ledger(entry(Name, wording, approximated, 'the template''s words made from the name, its inputs appended', Text,
                     'to be reviewed: the name does not say where its inputs go'))
    ;   true
    ).

%   The template of a definition.
def_text(Name, Kind, Ps, Extra, G, AF, Anns, QWs, Text, How) :-
    append(Extra, Ps, All),
    maplist([p(N, T), Noun]>>slot_noun(N, T, Noun), All, Nouns0),
    (   memberchk(Kind, [func, undefined_func]) -> type_noun(G, VN), append(Nouns0, [VN], Nouns1) ; Nouns1 = Nouns0 ),
    slot_texts(Nouns1, Slots1),
    length(All, NA), length(ArgSlots, NA), append(ArgSlots, VSlot, Slots1),
    pairs_keys_values(PSs, All, ArgSlots),
    (   memberchk(a(nlg, Nlg, _), Anns), nlg_text(Nlg, Name, PSs, Ws0)
    ->  How = nlg, Rest = []
    ;   findall(param(PN, PT, none), member(p(PN, PT), Ps), PGs),
        l4_mixfix_signature(sig(PGs, none), AF, Parts0), Parts0 \== [], memberchk(kw(_), Parts0),
        mixfix_words(Parts0, Name, PSs, Ws0)
    ->  How = mixfix, Rest = []
    ;   
        name_words(Name, NWs00), append(NWs00, QWs, NWs),
        (   place_params(PSs, NWs, Ws0a, Rest0),
            \+ ( memberchk(Kind, [func, undefined_func]), Ws0a = [F0|_], sub_atom(F0, 0, 1, _, '*') ),
            skeleton_free(Kind, Ws0a, Rest0)
        ->  Ws0 = Ws0a, Rest = Rest0
        ;   Ws0 = NWs, findall(S, member(_-S, PSs), Rest)
        ),
        ( Rest == [] -> How = phrase ; How = appended )
    ),
    append_rest(Kind, Ws0, Rest, Ws1),
    (   memberchk(Kind, [func, undefined_func])
    ->  VSlot = [VS],
        ( Ws1 = [W1|_], articles(As), memberchk(W1, As) -> Ws2 = Ws1 ; Ws2 = ["the"|Ws1] ),
        append(Ws2, ["is", VS], Ws)
    ;   Ws = Ws1
    ),
    words_text(Ws, Text).

%   A template whose words (its places left out) another template has: the
%   enclosing definition's name added, else a number
unique_words(Kind, Text0, [Q|_], Text) :-
    text_skeleton(Text0, Sk0),
    (   \+ clash(Sk0) -> Text = Text0
    ;   name_words(Q, QWs), words_text(QWs, QT),
        (   sub_string(Text0, _, _, _, QT) -> T1 = Text0
        ;   memberchk(Kind, [func, undefined_func]),
            findall(B0, sub_string(Text0, B0, _, _, " is *"), Bs), last(Bs, B), sub_string(Text0, 0, B, _, Pre)
        ->  sub_string(Text0, B, _, 0, Post), format(string(T1), "~w in ~w~w", [Pre, QT, Post])
        ;   format(string(T1), "~w in ~w", [Text0, QT])
        ),
        text_skeleton(T1, Sk1),
        (   \+ clash(Sk1) -> Text = T1
        ;   next(text, N), ordinal_word(N, OW),
            (   memberchk(Kind, [func, undefined_func]), findall(B0, sub_string(T1, B0, _, _, " is *"), Bs), last(Bs, B)
            ->  sub_string(T1, 0, B, _, Pre), sub_string(T1, B, _, 0, Post), format(string(Text), "~w ~w~w", [Pre, OW, Post])
            ;   format(string(Text), "~w ~w", [T1, OW])
            )
        )
    ).

%   A template clashes with one already made when either could read a
%   sentence of the other: its places matching one or more words
clash(Sk) :- skeleton_(Sk2), ( sk_match(Sk, Sk2) ; sk_match(Sk2, Sk) ), !.

sk_match(Sk1, Sk2) :- sk_words(Sk1, W1), sk_words(Sk2, W2), wm(W1, W2).
sk_words(Sk, Ws) :- foldl([P, A0, A]>>( P == "*" -> append(A0, ['*'], A) ; split_string(P, " ", " ", Ps), exclude(==(""), Ps, Ps1), append(A0, Ps1, A) ), Sk, [], Ws).
wm([], []).
wm(['*'|Ps], Ws) :- !, append([_|_], Rest, Ws), wm(Ps, Rest).
wm([W|Ps], [W|Ws]) :- wm(Ps, Ws).

ordinal_word(N, W) :- nth1(N, ["variant one", "variant two", "variant three", "variant four", "variant five"], W), !.
ordinal_word(N, W) :- format(string(W), "variant ~w", [N]).

text_skeleton(Text, Sk) :-
    split_string(Text, "*", "", Parts),
    findall(P, ( nth1(I, Parts, P0), ( I mod 2 =:= 0 -> P = "*" ; normalize_space(string(P), P0) ) ), Sk0),
    exclude(==(""), Sk0, Sk).

%   Two templates whose words are the same once their places are left out
%   would both match every sentence of either
skeleton(Ws, Sk) :- maplist([W, K]>>( sub_atom(W, 0, 1, _, '*') -> K = '*' ; K = W ), Ws, Sk).
skeleton_free(Kind, Ws0, Rest) :-
    append_rest(Kind, Ws0, Rest, Ws1),
    (   memberchk(Kind, [func, undefined_func]) -> ( Ws1 = [W1|_], articles(As), memberchk(W1, As) -> Ws2 = Ws1 ; Ws2 = ["the"|Ws1] ), append(Ws2, ["is", "*"], Ws)
    ;   Ws = Ws1
    ),
    words_text(Ws, T), text_skeleton(T, Sk), \+ clash(Sk),
    \+ append(_, ["*", "*"|_], Sk).

%   The parameters named inside the phrase take their places there
place_params([], Ws, Ws, []).
place_params([p(N, T)-S|Ps], Ws0, Ws, Rest) :-
    slot_noun(N, T, _),
    name_words(N, NWs0), strip_article(NWs0, NWs),
    (   NWs \== [], \+ ( NWs = [W], string_length(W, L), L =< 1 ),
        (   NWs0 = [Art|_], articles(As), memberchk(Art, As) -> substitute_exact(Ws0, NWs0, S, Ws1)
        ;   substitute(Ws0, NWs, S, Ws1)
        )
    ->  Rest = Rest1
    ;   Ws1 = Ws0, Rest = [S|Rest1]
    ),
    place_params(Ps, Ws1, Ws, Rest1).

%   Inputs the name does not place: a yes-or-no phrase that begins with a
%   verb takes the first before it (`*a person* can vote`); the others follow
%   `for` (`the tax owed for *a number* and *a second number*`).
append_rest(_, Ws, [], Ws) :- !.
append_rest(Kind, Ws0, [S|Ss], Ws) :-
    memberchk(Kind, [pred, undefined_pred]), Ws0 = [W|_], \+ sub_atom(W, 0, 1, _, '*'),
    verb_word(W), !,
    ( Ss == [] -> Ws = [S|Ws0] ; and_list(Ss, And), joiner(Ws0, J), append([S|Ws0], [J|And], Ws) ).
append_rest(_, Ws0, Ss, Ws) :-
    and_list(Ss, And),
    ( last(Ws0, P), preposition(P) -> append(Ws0, And, Ws) ; joiner(Ws0, J), append(Ws0, [J|And], Ws) ).

%   The word before the appended inputs: `for`, unless another name goes on
%   from this one with `for` (`market cap milestone met` and `market cap
%   milestone met for change in control`), where a sentence of the longer
%   would read as the shorter one's with a longer input
joiner(Ws0, J) :-
    findall(W, ( all_name_(NWs), append(Ws0, [W|_], NWs) ), Followers),
    member(J, ["for", "given", "on", "regarding", "as", "concerning"]),
    \+ memberchk(J, Followers), !.
joiner(_, "for").

preposition(W) :- memberchk(W, ["of", "for", "to", "by", "in", "at", "on", "with", "from", "under", "between", "than", "about", "per"]).

and_list([S], [S]) :- !.
and_list([S|Ss], [S, "with"|R]) :- and_list(Ss, R).

%   `@nlg %`the seller`% %`can transfer`% to %`the buyer`%`: the marked
%   names are the function's name (its words) or its parameters (places)
nlg_text(Nlg, Name, PSs, Ws) :-
    format(string(S), "~w", [Nlg]),
    sub_string(S, _, _, _, "%"),
    split_string(S, "%", "", Parts),
    nlg_parts(Parts, Name, PSs, 0, Wss),
    append(Wss, Ws), Ws \== [],
    forall(member(_-Slot, PSs), memberchk(Slot, Ws)).

nlg_parts([], _, _, _, []).
nlg_parts([P|Ps], Name, PSs, I, [Ws|Wss]) :-
    (   I mod 2 =:= 1
    ->  split_string(P, "`", " ", [_|_]), atom_string(A0, P), strip_backquotes(A0, A),
        (   member(p(A, _)-Slot, PSs) -> Ws = [Slot]
        ;   name_words(A, Ws)
        )
    ;   name_words(P, Ws)
    ),
    I1 is I + 1, nlg_parts(Ps, Name, PSs, I1, Wss).

strip_backquotes(A0, A) :-
    atom_string(A0, S0), split_string(S0, "", "` ", [S]), atom_string(A, S).

mixfix_words([], _, _, []).
mixfix_words([param(P)|Ps], Name, PSs, [S|Ws]) :- !,
    ( member(p(P, _)-S, PSs) -> true ; format(string(S), "*a ~w*", [P]) ),
    mixfix_words(Ps, Name, PSs, Ws).
mixfix_words([kw(K)|Ps], Name, PSs, Ws) :-
    name_words(K, KWs), mixfix_words(Ps, Name, PSs, Ws1), append(KWs, Ws1, Ws).

		 /*******************************
		 *        TYPE GUESSES          *
		 *******************************/

is_bool(and(_, _), _) :- !.
is_bool(or(_, _), _) :- !.
is_bool(implies(_, _), _) :- !.
is_bool(not(_), _) :- !.
is_bool(E, _) :- functor(E, Op, 2), memberchk(Op, [eq, lt, gt, leq, geq]), !.
is_bool(app(B, []), _) :- memberchk(B, ['TRUE', 'FALSE']), !.
is_bool(app(N, _), Env) :- lookup(N, Env, var(_, tyapp('BOOLEAN', []))), !.
is_bool(app(N, _), Env) :- \+ lookup(N, Env, _), lookup_sym(N, Env, s(K, _, _, _, _, _)), memberchk(K, [pred, undefined_pred]), !.
is_bool(app(N, _), _) :- memberchk(N, [all, any, elem, null]), !.
is_bool(proj(_, F), _) :- field_(_, F, f(_, true, _)), !.
is_bool(if(_, T, _), Env) :- !, is_bool(T, Env).
is_bool(branch([_-T|_], _), Env) :- !, is_bool(T, Env).
is_bool(consider(_, [when(_, T)|_]), Env) :- !, is_bool(T, Env).
is_bool(where(E, _), Env) :- !, is_bool(E, Env).
is_bool(let(_, E), Env) :- !, is_bool(E, Env).
is_bool(mixfix(Ps), Env) :- resolve_mixfix(Ps, N, _), is_bool(app(N, []), Env).

		 /*******************************
		 *         ENVIRONMENT          *
		 *******************************/

%   Env: [e(Name, var(PrologVar, Type)) | e(Name, local(Key))]
lookup(N, Env, B) :- memberchk(e(N, B0), Env), !, B = B0.

lookup_sym(N, Env, S) :-
    (   lookup(N, Env, local(Key)) -> sym_(Key, S)
    ;   sym_(key(top, N), S)
    ), !.

sym_key(N, Env, Key) :-
    (   lookup(N, Env, local(Key)) -> true ; Key = key(top, N), sym_(Key, _) ).

		 /*******************************
		 *           COMPILING          *
		 *******************************/

compile_defs(Is) :-
    forall(member(I, Is), compile_item(I)).

compile_item(decide(_, Sig, AF, Body, Anns, pos(L1, L2))) :- !,
    af_name(Sig, AF, Name),
    sym_(key(top, Name), S),
    compile_def(S, key(top, Name), Sig, Body, Anns, L1-L2, []).
compile_item(assume(Sig, AF, _, _, _)) :- !,
    af_name(Sig, AF, Name),
    ( sym_(key(top, Name), _) -> ledger(entry(Name, assume, encoded, 'a template the scenarios state (; undefined)', Name, '')) ; true ).
compile_item(section(_, Name, _, _)) :- Name \== none, !,
    name_words(Name, Ws), words_text(Ws, T),
    assertz(item_(section(T))).
compile_item(_).

compile_def(s(contract, _, _, _, _, _), key(_, Name), _, _, _, _, _) :- !,
    ledger(entry(Name, contract, residue, 'the contracts half (step 3)', Name, '')).
compile_def(s(recconst(Id), _, _, _, _, _), key(_, Name), _, Body, _, _, _) :- !,
    (   catch(record_facts(Body, Id, rec_store), residue(R, _), ( ledger(entry(Name, record, residue, R, Name, '')), fail ))
    ->  ledger(entry(Name, record, encoded, 'an individual with one fact per field', Id, ''))
    ;   true
    ).
compile_def(s(reclist(Id), _, _, _, _, _), key(_, Name), _, list(Es), _, _, _) :- !,
    (   catch(( findall(I-E, ( nth1(K, Es, E), format(atom(I), "~w_~w", [Id, K]) ), IEs),
                forall(member(I-E, IEs), record_facts(E, I, rec_store)) ), residue(R, _),
              ( ledger(entry(Name, record, residue, R, Name, '')), fail ))
    ->  ledger(entry(Name, record, encoded, 'a list of individuals, one fact per field', Id, ''))
    ;   true
    ).
compile_def(S, Key, _Sig, Body, Anns, Lines, OuterEnv) :-
    S = s(Kind, Ps, Extra, _G, F, Text),
    Key = key(_, Name),
    append(Extra, Ps, All),
    maplist([p(N, T), e(N, var(_, T))]>>true, All, PEnv),
    append(PEnv, OuterEnv, Env0),
    maplist([e(_, var(V, _)), V]>>true, PEnv, Vars),
    comment_of(Anns, Opts0),
    provenance_of(Anns, Lines, Opts1), append(Opts0, Opts1, Opts),
    (   catch(compile_body(Kind, Body, Env0, Key, Vars, F, Item), residue(R, E), true)
    ->  (   var(R)
        ->  assertz(item_(Item)),
            ledger(entry(Name, definition, encoded, Kind, Text, ''))
        ;   residue_item(Name, R, E, Lines, F, Kind, Vars, Opts)
        )
    ;   residue_item(Name, 'no LE form found', Body, Lines, F, Kind, Vars, Opts)
    ).

comment_of(Anns, [comment(D)]) :- memberchk(a(desc, D0, _), Anns), !, format(string(D), "~w", [D0]).
comment_of(_, []).

provenance_of(Anns, _, [provenance([as_stated_in('the source program'), at(R)])]) :-
    memberchk(a(ref, R0, _), Anns), !, format(string(R), "~w", [R0]).
provenance_of(_, _, []).

residue_item(Name, Reason, E, L1-L2, F, Kind, Vars, _) :-
    next(residue, N), atomic_list_concat([r, N], Id),
    format(string(Loc), "lines ~w-~w", [L1, L2]),
    source_text(L1, L2, Code),
    residue_detail(E, Detail),
    format(string(Note), "~w: ~w", [Reason, Detail]),
    ( memberchk(Kind, [func]) -> append(Vars, [_], Args) ; Args = Vars ),
    ( atom(F) -> Head =.. [F|Args], Conc = [concludes([F])] ; Conc = [] ),
    ignore(Head = none),
    append([title(Name), locator(Loc), source(l4, Code), note(Note)], Conc, Opts),
    assertz(item_(residue(Id, Opts))),
    ledger(entry(Name, definition, residue, Reason, Id, '')).

%   The rule (or fact) a definition becomes
compile_body(Kind, Body0, Env0, Key, Vars, F, Item) :-
    unwrap_locals(Body0, Key, Env0, Body, Env),
    (   memberchk(Kind, [pred])
    ->  Head =.. [F|Vars],
        cond(Body, Env, G),
        rule_item(Head, G, Item)
    ;   memberchk(Kind, [func])
    ->  val(Body, Env, V, G),
        append(Vars, [V], Args), Head =.. [F|Args],
        rule_item(Head, G, Item)
    ).

rule_item(Head, G0, Item) :-
    simp(G0, G),
    (   G == true, ground(Head) -> Item = fact(Head, [])
    ;   G == true -> Item = rule(Head, true, [])
    ;   G == false -> Item = comment("never holds")
    ;   Item = rule(Head, G, [])
    ).

%   TRUE and FALSE written inside a condition, worked out
simp(G, G) :- var(G), !.
simp(and(A, B), G) :- !, simp(A, SA), simp(B, SB),
    ( ( SA == false ; SB == false ) -> G = false ; conj(SA, SB, G) ).
simp(or(A, B), G) :- !, simp(A, SA), simp(B, SB),
    ( ( SA == true ; SB == true ) -> G = true ; SA == false -> G = SB ; SB == false -> G = SA ; G = or(SA, SB) ).
simp(not(A), G) :- !, simp(A, SA),
    ( SA == true -> G = false ; SA == false -> G = true ; G = not(SA) ).
simp(otherwise(As0), G) :- !, maplist(simp, As0, As2),
    ( append(Front, [otherwise(Last)], As2) -> append(Front, Last, As1) ; As1 = As2 ),
    (   As1 = [true|_] -> G = true
    ;   exclude(==(false), As1, As), ( As == [] -> G = false ; As = [A] -> G = A ; G = otherwise(As) )
    ).
simp(forall(C, B), G) :- !, simp(B, SB), ( SB == true -> G = true ; G = forall(C, SB) ).
simp(G, G).

%   WHERE / LET: the local definitions become templates of their own
unwrap_locals(where(E, Ls), Key, Env0, E1, Env) :- !,
    locals(Ls, Key, Env0, Env1),
    unwrap_locals(E, Key, Env1, E1, Env).
unwrap_locals(let(Ls, E), Key, Env0, E1, Env) :- !,
    locals(Ls, Key, Env0, Env1),
    unwrap_locals(E, Key, Env1, E1, Env).
unwrap_locals(E, _, Env, E, Env).

locals(Ls, key(_, Parent), Env0, Env) :-
    next(scope, SN), Scope = local(SN, Parent),
    findall(N, ( member(L, Ls), local_name(L, N) ), Names),
    findall(e(N, local(key(Scope, N))), member(N, Names), LEnv),
    append(LEnv, Env0, Env),
    %  the enclosing inputs each local uses, directly or through another
    findall(N-Used, ( member(L, Ls), local_name(L, N), local_body(L, B), used_vars(B, Env0, Used) ), Direct),
    closure_extras(Direct, Ls, Extras),
    forall(( member(L, Ls), L = decide(_, Sig, AF, B, Anns, _), af_name(Sig, AF, N) ),
           ( memberchk(N-ExNames, Extras),
             findall(p(X, T), ( member(X, ExNames), lookup(X, Env0, var(_, T)) ), Extra),
             def_params(Sig, AF, Ps),
             append(Ps, [], _),
             maplist([p(PN, PT), e(PN, var(_, PT))]>>true, Ps, PsEnv0), append(PsEnv0, Env, EnvK),
             ( Sig = sig(_, tyapp('BOOLEAN', [])) -> K = pred
             ; Sig = sig(_, G), G \== none -> K = func
             ; is_bool(B, EnvK) -> K = pred ; K = func ),
             guess_sig(Sig, B, Sig1),
             make_symbol(N, K, Ps, Extra, Sig1, AF, Anns, Scope) )),
    %  compile each local now, in the enclosing environment
    forall(( member(L, Ls), L = decide(_, Sig, _, B, Anns, pos(L1, L2)), local_name(L, N) ),
           ( sym_(key(Scope, N), S),
             strip_vars(Env, EnvS),
             compile_def(S, key(Scope, N), Sig, B, Anns, L1-L2, EnvS) )).

%   The locals and parameters of the enclosing environment, without its
%   variables: a local's rule has its own.
strip_vars(Env, EnvS) :- include([e(_, B)]>>( B = local(_) ), Env, EnvS).

local_name(decide(_, Sig, AF, _, _, _), N) :- af_name(Sig, AF, N).

%   The name a definition is known by: its first word, except for a mixfix
%   name whose first word is one of its inputs (`n `is big``, `a `plus` b`),
%   which is known by its other words, as its uses are (resolve_mixfix/3).
af_name(Sig, AF, Name) :-
    AF = appform(N, _, _, _),
    (   Sig = sig(Gs, _), Gs \== [],
        l4_mixfix_signature(Sig, AF, [param(_)|Parts]),
        findall(K, member(kw(K), Parts), Ks), Ks \== []
    ->  atomic_list_concat(Ks, ' ', Name)
    ;   Name = N
    ).
local_body(decide(_, _, _, B, _, _), B).

used_vars(B, Env, Used) :-
    findall(N, ( sub_term(app(N, _), B), atom(N), lookup(N, Env, var(_, _)) ), Ns0),
    findall(N, ( sub_term(proj(app(N, []), _), B), lookup(N, Env, var(_, _)) ), Ns1),
    append(Ns0, Ns1, Ns2), sort(Ns2, Used).

closure_extras(Direct, Ls, Extras) :-
    findall(N-Calls, ( member(L, Ls), local_name(L, N), local_body(L, B),
                       findall(M, ( sub_term(app(M, _), B), member(L2, Ls), local_name(L2, M), M \== N ), Calls) ), CallG),
    fix(Direct, CallG, Extras).

fix(D0, G, D) :-
    findall(N-U, ( member(N-U0, D0), memberchk(N-Cs, G),
                   findall(X, ( member(C, Cs), memberchk(C-UC, D0), member(X, UC) ), Xs),
                   append(U0, Xs, U1), sort(U1, U) ), D1),
    ( D1 == D0 -> D = D0 ; fix(D1, G, D) ).

		 /*******************************
		 *          CONDITIONS          *
		 *******************************/

%!  cond(+Expr, +Env, -Goal) is det.   (throws residue(Reason, Expr))
cond(E, Env, G) :- cond_(E, Env, G), !.
cond(E, _, _) :- throw(residue('a condition with no LE form', E)).

cond_(where(E, Ls), Env, G) :- !, unwrap_locals(where(E, Ls), key(top, where), Env, E1, Env1), cond(E1, Env1, G).
cond_(let(Ls, E), Env, G) :- !, unwrap_locals(let(Ls, E), key(top, let), Env, E1, Env1), cond(E1, Env1, G).
cond_(and(A, B), Env, G) :- !, cond(A, Env, GA), cond(B, Env, GB), conj(GA, GB, G).
cond_(or(A, B), Env, G) :- !, cond(A, Env, GA), cond(B, Env, GB), disj(GA, GB, G).
cond_(implies(A, B), Env, or(not(GA), GB)) :- !, cond(A, Env, GA), cond(B, Env, GB).
cond_(not(A), Env, not(GA)) :- !, cond(A, Env, GA).
cond_(app('TRUE', []), _, true) :- !.
cond_(app('FALSE', []), _, false) :- !.
cond_(eq(A, B), Env, G) :- bool_lit(B, BV), !, cond(A, Env, GA), ( BV == true -> G = GA ; G = not(GA) ).
cond_(eq(A, B), Env, G) :- bool_lit(A, BV), !, cond(B, Env, GB), ( BV == true -> G = GB ; G = not(GB) ).
cond_(eq(A, B), Env, G) :- !,
    (   constant_expr(B) -> val(B, Env, C, true), val(A, Env, C, GA), G = GA
    ;   constant_expr(A) -> val(A, Env, C, true), val(B, Env, C, GB), G = GB
    ;   val(A, Env, VA, GA), val(B, Env, VB, GB), conj(GA, GB, G0), conj(G0, VA = VB, G)
    ).
cond_(E, Env, G) :- E =.. [Op, A, B], cmp_op(Op, POp), !,
    arith(A, Env, XA, GA), arith(B, Env, XB, GB),
    C =.. [POp, XA, XB], conj(GA, GB, G0), conj(G0, C, G).
cond_(if(C, T, E), Env, or(G1, G2)) :- !,
    cond(C, Env, GC), cond(T, Env, GT), cond(E, Env, GE),
    conj(GC, GT, G1), conj(not(GC), GE, G2).
cond_(branch(Cases, Other), Env, G) :- !,
    foldr_branch(Cases, Other, E), cond(E, Env, G).
cond_(consider(S, Bs), Env, G) :- maybe_branches(Bs, JBs, NB), !,
    maybe_consider(S, JBs, NB, Env, cond, G).
cond_(consider(S, Bs), Env, G) :- !,
    val(S, Env, SV, GS),
    consider_alts(Bs, SV, Env, cond, Alts),
    ( Alts = [A] -> G1 = A ; G1 = otherwise(Alts) ),
    conj(GS, G1, G).
cond_(mixfix(Ps), Env, G) :- !, resolve_mixfix(Ps, N, Args), cond(app(N, Args), Env, G).
cond_(app(F, [R]), Env, G) :- \+ lookup_sym(F, Env, _), field_(_, F, f(_, true, _)), !, cond(proj(R, F), Env, G).
cond_(proj(R, F), Env, G) :- field_(_, F, f(Fu, true, _)), !,
    val(R, Env, RV, GR), L =.. [Fu, RV], conj(GR, L, G).
cond_(app(N, []), Env, G) :- lookup(N, Env, var(V, _)), !, G = (true = V).
cond_(app(N, []), Env, G) :- lookup(N, Env, rfield(R)), !, cond(proj(pv(R), N), Env, G).
cond_(app(all, [P, L]), Env, G) :- !,
    val(L, Env, LV, GL), elem_cond(P, X, Env, GP), conj(GL, forall(member(X, LV), GP), G).
cond_(app(any, [P, L]), Env, G) :- !,
    val(L, Env, LV, GL), elem_cond(P, X, Env, GP), conj(GL, member(X, LV), G0), conj(G0, GP, G).
cond_(app(elem, [X, L]), Env, G) :- !,
    val(X, Env, XV, GX), val(L, Env, LV, GL), conj(GX, GL, G0), conj(G0, member(XV, LV), G).
cond_(app(null, [L]), Env, G) :- !, val(L, Env, LV, GL), conj(GL, [] = LV, G).
cond_(app(N, Args), Env, G) :-
    lookup_sym(N, Env, s(K, Ps, Extra, _, F, _)), memberchk(K, [pred, undefined_pred]), !,
    length(Ps, NP), length(Args, NP),
    extra_vals(Extra, Env, XVs),
    vals(Args, Env, AVs, GA),
    append(XVs, AVs, All), L =.. [F|All], conj(GA, L, G).
cond_(E, Env, G) :-                       % a value that is TRUE or FALSE
    val(E, Env, V, GV), conj(GV, true = V, G).

bool_lit(app('TRUE', []), true).
bool_lit(app('FALSE', []), false).

cmp_op(lt, <). cmp_op(gt, >). cmp_op(leq, =<). cmp_op(geq, >=).

constant_expr(num(_)).
constant_expr(str(_)).
constant_expr(app(C, [])) :- enumcon_(C, _, []).
constant_expr(app(N, [])) :- sym_(key(top, N), s(recconst(_), _, _, _, _, _)).

%   A function applied to each element of a list: a named one, or one
%   written in place (GIVEN x YIELD …)
elem_cond(lam([P0], B), X, Env, G) :- !, lam_param(P0, P, T), cond(B, [e(P, var(X, T))|Env], G).
elem_cond(app(N, []), X, Env, G) :- !, cond(app(N, [app('$x', [])]), [e('$x', var(X, none))|Env], G).
elem_cond(E, _, _, _) :- throw(residue('a function passed as a value', E)).

elem_val(lam([P0], B), X, Env, V, G) :- !, lam_param(P0, P, T), val(B, [e(P, var(X, T))|Env], V, G).
elem_val(app(N, []), X, Env, V, G) :- !, val(app(N, [app('$x', [])]), [e('$x', var(X, none))|Env], V, G).
elem_val(E, _, _, _, _) :- throw(residue('a function passed as a value', E)).

lam_param(param(P, T, _), P, T) :- !.
lam_param(P, P, none).

foldr_branch([], Other, Other).
foldr_branch([C-T|Cs], Other, if(C, T, E)) :- foldr_branch(Cs, Other, E).

%   A chain of alternatives, left to right as LE reads sibling lines
disj(A, B, G) :- nonvar(B), B = or(B1, B2), !, disj(A, B1, G1), disj(G1, B2, G).
disj(A, B, or(A, B)).

conj(true, G, G) :- !.
conj(G, true, G) :- !.
conj(A, B, G) :- nonvar(B), B = and(B1, B2), !, conj(A, B1, G1), conj(G1, B2, G).
conj(A, B, and(A, B)).

extra_vals(Extra, Env, Vs) :-
    extra_vals_(Extra, Env, Vs).

extra_vals_([], _, []).
extra_vals_([p(N, _)|Ps], Env, [V|Vs]) :-
    ( lookup(N, Env, var(V, _)) -> true ; throw(residue('an input out of scope', N)) ),
    extra_vals_(Ps, Env, Vs).

		 /*******************************
		 *            VALUES            *
		 *******************************/

%!  val(+Expr, +Env, ?Value, -Goal) is det.  (throws residue(Reason, Expr))
val(E, Env, V, G) :- val_(E, Env, V, G), !.
val(E, _, _, _) :- throw(residue('a value with no LE form', E)).

val_(num(N), _, V, G) :- !, bind(V, N, G).
val_(ind(Id), _, V, G) :- !, bind(V, Id, G).
val_(str(S), _, V, G) :- !, bind(V, S, G).
val_(app('TRUE', []), _, V, G) :- !, bind(V, true, G).
val_(app('FALSE', []), _, V, G) :- !, bind(V, false, G).
val_(app('EMPTY', []), _, V, G) :- !, bind(V, [], G).
val_(list(Es), Env, V, G) :- !, vals(Es, Env, Vs, G0), ( ground(Vs) -> bind(V, Vs, G1) ; G1 = (V = Vs) ), conj(G0, G1, G).
val_(where(E, Ls), Env, V, G) :- !, unwrap_locals(where(E, Ls), key(top, where), Env, E1, Env1), val(E1, Env1, V, G).
val_(let(Ls, E), Env, V, G) :- !, unwrap_locals(let(Ls, E), key(top, let), Env, E1, Env1), val(E1, Env1, V, G).
val_(app(N, []), Env, V, G) :- lookup(N, Env, var(X, _)), !, bind(V, X, G).
val_(app(N, []), Env, V, G) :- lookup(N, Env, rfield(R)), !, val(proj(pv(R), N), Env, V, G).
val_(pv(X), _, V, G) :- !, bind(V, X, G).
val_(app(C, []), _, V, G) :- enumcon_(C, _, []), !, con_atom(C, A), bind(V, A, G).
val_(app(N, []), Env, V, G) :- lookup_sym(N, Env, s(recconst(Id), _, _, _, _, _)), !, bind(V, Id, G).
val_(app(N, []), Env, V, G) :- lookup_sym(N, Env, s(reclist(Id), _, _, _, _, _)), !,
    aggregate_all(count, recfact_(_, _), _),
    findall(I, ( between(1, 1000, K), format(atom(I), "~w_~w", [Id, K]), once(recfact_(I, _)) ), Is),
    bind(V, Is, G).
val_(E, Env, V, G) :- arith_op(E), !, arith(E, Env, X, G0), conj(G0, V is X, G).
val_(if(C, T, E), Env, V, G) :- !,
    cond(C, Env, GC), branch_val(T, Env, V, GT), branch_val(E, Env, V, GE),
    conj(GC, GT, A1),
    G = otherwise([A1, GE]).
val_(branch(Cases, Other), Env, V, G) :- !,
    findall(C-T, member(C-T, Cases), _),
    branch_alts(Cases, Other, Env, V, Alts), G = otherwise(Alts).
val_(consider(S, Bs), Env, V, G) :- maybe_branches(Bs, JBs, NB), !,
    maybe_consider(S, JBs, NB, Env, val(V), G).
val_(consider(S, Bs), Env, V, G) :- !,
    val(S, Env, SV, GS),
    consider_alts(Bs, SV, Env, val(V), Alts),
    ( Alts = [A] -> G1 = A ; G1 = otherwise(Alts) ),
    conj(GS, G1, G).
val_(proj(R, F), Env, V, G) :- !,
    val(R, Env, RV, GR),
    (   field_(_, F, f(Fu, false, _)) -> L =.. [Fu, RV, V], conj(GR, L, G)
    ;   field_(_, F, f(Fu, true, _)) -> L =.. [Fu, RV], conj(GR, otherwise([and(L, V = true), V = false]), G)
    ;   throw(residue('a field of a record the program does not declare', proj(R, F)))
    ).
val_(mixfix(Ps), Env, V, G) :- !, resolve_mixfix(Ps, N, Args), val(app(N, Args), Env, V, G).
val_(app(F, [R]), Env, V, G) :- \+ lookup_sym(F, Env, _), field_(_, F, _), !, val(proj(R, F), Env, V, G).
val_(app('NOTHING', []), _, V, G) :- !, bind(V, nothing, G).
val_(app('JUST', [E]), Env, V, G) :- !, val(E, Env, V, G).
val_(app(sum, [L]), Env, V, G) :- !, list_agg(sum, L, Env, V, G).
val_(app(length, [L]), Env, V, G) :- !, list_agg(count, L, Env, V, G).
val_(app(count, [L]), Env, V, G) :- !, list_agg(count, L, Env, V, G).
val_(app(maximum, [L]), Env, V, G) :- !, list_agg(max, L, Env, V, G).
val_(app(minimum, [L]), Env, V, G) :- !, list_agg(min, L, Env, V, G).
val_(app(map, [F, L]), Env, V, G) :- !, list_agg(list, app(map, [F, L]), Env, V, G).
val_(app(filter, [P, L]), Env, V, G) :- !, list_agg(list, app(filter, [P, L]), Env, V, G).
val_(app(N, Args), Env, V, G) :-
    lookup_sym(N, Env, s(K, Ps, Extra, _, F, _)), memberchk(K, [func, undefined_func]), !,
    length(Ps, NP), length(Args, NP),
    extra_vals(Extra, Env, XVs), vals(Args, Env, AVs, GA),
    append([XVs, AVs, [V]], All), L =.. [F|All], conj(GA, L, G).
val_(app(N, Args), Env, V, G) :-
    lookup_sym(N, Env, s(K, _, _, _, _, _)), memberchk(K, [pred, undefined_pred]), !,
    cond(app(N, Args), Env, GC),
    G = otherwise([and(GC, V = true), V = false]).
val_(app(T, _), _, _, _) :- rectype_(T, _), !,
    throw(residue('a record built inside a rule', T)).
val_(app(N, Args), Env, V, G) :- \+ lookup_sym(N, Env, _), daydate(N, Args, Env, V, G), !.
val_(E, Env, V, G) :- is_bool(E, Env), !,
    cond(E, Env, GC), G = otherwise([and(GC, V = true), V = false]).

bind(V, C, true) :- var(V), !, V = C.
bind(V, C, V = C).

%   A branch's value goes straight into V, except a name or a constant,
%   which val/4 would bind to V once and for all
branch_val(E, Env, V, G) :-
    (   atomic_expr(E, Env) -> val(E, Env, X, G0), conj(G0, V = X, G)
    ;   val(E, Env, V, G)
    ).

atomic_expr(num(_), _).
atomic_expr(str(_), _).
atomic_expr(ind(_), _).
atomic_expr(list(_), _).
atomic_expr(app('NOTHING', []), _).
atomic_expr(app('JUST', [E]), Env) :- atomic_expr(E, Env).
atomic_expr(app(N, []), Env) :- ( memberchk(N, ['TRUE', 'FALSE', 'EMPTY']) ; lookup(N, Env, var(_, _)) ; enumcon_(N, _, []) ;
                                  sym_(key(top, N), s(recconst(_), _, _, _, _, _)) ), !.

branch_alts([], Other, Env, V, [G]) :- branch_val(Other, Env, V, G).
branch_alts([C-T|Cs], Other, Env, V, [A|As]) :-
    cond(C, Env, GC), branch_val(T, Env, V, GT), conj(GC, GT, A),
    branch_alts(Cs, Other, Env, V, As).

%   CONSIDER on a value that may be missing (JUST x / NOTHING): the value
%   is looked up in the first alternative, so a missing one (a field with
%   no fact, or NOTHING) falls to the NOTHING branch
maybe_branches(Bs, JBs, NB) :-
    ( memberchk(when(papp('JUST', _), _), Bs) ; memberchk(when(papp('NOTHING', []), _), Bs) ), !,
    include([B]>>( B = when(papp('JUST', _), _) ), Bs, JBs),
    (   member(when(papp('NOTHING', []), E), Bs) -> NB = E
    ;   member(otherwise(E), Bs) -> NB = E
    ;   NB = none
    ).

maybe_consider(S, JBs, NB, Env, How, G) :-
    maybe_alts(JBs, S, Env, How, JAlts),
    (   NB == none -> Alts = JAlts ; branch_goal(How, NB, Env, GN), append(JAlts, [GN], Alts) ),
    ( Alts = [G] -> true ; G = otherwise(Alts) ).

maybe_alts([], _, _, _, []).
maybe_alts([when(papp('JUST', [P]), E)|Bs], S, Env, How, [A|As]) :-
    val(S, Env, SV, GS), pattern(P, SV, Env, Env1, GP), branch_goal(How, E, Env1, GE),
    conj(GS, not(nothing = SV), A0), conj(A0, GP, A1), conj(A1, GE, A),
    maybe_alts(Bs, S, Env, How, As).

%   CONSIDER: one alternative per branch
consider_alts([], _, _, _, []).
consider_alts([B|Bs], SV, Env, How, [A|As]) :-
    consider_alt(B, SV, Env, How, A),
    consider_alts(Bs, SV, Env, How, As).

consider_alt(otherwise(E), _, Env, How, G) :- !, branch_goal(How, E, Env, G).
consider_alt(when(P, E), SV, Env, How, G) :-
    pattern(P, SV, Env, Env1, GP),
    branch_goal(How, E, Env1, GE), conj(GP, GE, G).

branch_goal(cond, E, Env, G) :- cond(E, Env, G).
branch_goal(val(V), E, Env, G) :- branch_val(E, Env, V, G).

pattern(plit(L), SV, Env, Env, G) :- !, val(L, Env, C, true), G = (C = SV).
pattern(papp(C, []), SV, Env, Env, A = SV) :- enumcon_(C, _, []), !, con_atom(C, A).
pattern(papp('TRUE', []), SV, Env, Env, true = SV) :- !.
pattern(papp('FALSE', []), SV, Env, Env, false = SV) :- !.
pattern(papp('EMPTY', []), SV, Env, Env, [] = SV) :- !.
pattern(papp('NOTHING', []), SV, Env, Env, nothing = SV) :- !.
pattern(papp('JUST', [P]), SV, Env0, Env, G) :- !,
    pattern(P, SV, Env0, Env, G0), conj(not(nothing = SV), G0, G).
pattern(pcons(P1, P2), SV, Env0, Env, G) :- !,
    pattern(P1, H, Env0, Env1, G1), pattern(P2, T, Env1, Env, G2),
    conj(prolog(SV = [H|T]), G1, G3), conj(G3, G2, G).
pattern(papp(C, Ps), SV, Env0, Env, G) :- rectype_(C, Fs), length(Fs, N), length(Ps, N), !,
    ( conpred_(C, CF) -> G0 =.. [CF, SV] ; G0 = true ),
    field_patterns(Fs, Ps, C, SV, Env0, Env, G0, G).
pattern(papp(X, []), SV, Env, [e(X, var(SV, none))|Env], true) :- !.   % a name binds
pattern(P, _, _, _, _) :- throw(residue('a pattern with no LE form', P)).

field_patterns([], [], _, _, Env, Env, G, G).
field_patterns([field(FN, _)|Fs], [P|Ps], C, SV, Env0, Env, G0, G) :-
    field_(C, FN, f(F, Bool, _)),
    (   Bool == true -> pattern(P, X, Env0, Env1, GP), L = otherwise([and(L0, true = X), false = X]), L0 =.. [F, SV]
    ;   L =.. [F, SV, X], pattern(P, X, Env0, Env1, GP)
    ),
    conj(G0, L, G1), conj(G1, GP, G2),
    field_patterns(Fs, Ps, C, SV, Env1, Env, G2, G).

con_atom(C, A) :- name_words(C, Ws), atomic_list_concat(Ws, '_', A0), downcase_atom(A0, A).

vals([], _, [], true).
vals([E|Es], Env, [V|Vs], G) :- val(E, Env, V, G1), vals(Es, Env, Vs, G2), conj(G1, G2, G).

arith_op(E) :- compound(E), functor(E, Op, _), memberchk(Op, [plus, minus, times, div, mod, percent]).

arith(num(N), _, N, true) :- !.
arith(percent(E), Env, X / 100, G) :- !, arith(E, Env, X, G).
arith(E, Env, X, G) :- E =.. [Op, A, B], arith_fun(Op, F), !,
    arith(A, Env, XA, GA), arith(B, Env, XB, GB), X =.. [F, XA, XB], conj(GA, GB, G).
arith(app(F, [A]), Env, X, G) :- \+ lookup_sym(F, Env, _), round_fun(F, PF), !,
    arith(A, Env, XA, G), X =.. [PF, XA].
arith(E, Env, X, G) :- val(E, Env, X, G).

round_fun('FLOOR', floor). round_fun('CEILING', ceiling). round_fun('ROUND', round).
round_fun('TRUNC', truncate). round_fun(absNumber, abs). round_fun(sqrt, sqrt).

arith_fun(plus, +). arith_fun(minus, -). arith_fun(times, *). arith_fun(div, /). arith_fun(mod, mod).

%   sum/length/count/maximum/minimum of a list, of map/filter over one, and
%   map/filter kept as a list
list_agg(Op, L, Env, V, G) :-
    elements(L, Env, _, Y, GE),
    (   Op == list -> Agg = agg(list, Y, GE, V) ; Agg = agg(Op, Y, GE, V) ),
    G = Agg,
    note_list(Op).

elements(app(map, [F, L]), Env, X, Y, G) :- !,
    elements(L, Env, _, X, G0), elem_val(F, X, Env, Y, G1), conj(G0, G1, G).
elements(app(filter, [P, L]), Env, X, X, G) :- !,
    elements(L, Env, _, X, G0), elem_cond(P, X, Env, G1), conj(G0, G1, G).
elements(L, Env, X, X, G) :-
    val(L, Env, LV, GL), conj(GL, member(X, LV), G).

note_list(list) :- !, next(list_built, _).
note_list(_).

%   `a `plus` b`: the definition whose words match
resolve_mixfix(Parts, Name, Args) :-
    findall(K, member(kw(K), Parts), Ks),
    findall(A, member(arg(A), Parts), Args),
    sym_(key(_, Name), s(_, Ps, _, _, _, _)),
    mixfix_kws(Name, Ks), length(Ps, NP), length(Args, NP), !.

mixfix_kws(Name, [Name]) :- !.
mixfix_kws(Name, Ks) :- atomic_list_concat(Ks, ' ', Name).

		 /*******************************
		 *   DATES (L4's daydate)       *
		 *******************************/

%   L4's dates are LE dates; what its daydate library does with them is
%   lib/l4_daydate.le's (included by the twin that uses it)
dd_template(serial, l4dd_serial/2, "the day number of *a date* is *a number*").
dd_template(of_serial, l4dd_of_serial/2, "the date of day number *a number* is *a date*").
dd_template(make, l4dd_make/4, "the date with day *a number* month *a second number* year *a third number* is *a date*").
dd_template(day, l4dd_day/2, "the day in the month of *a date* is *a number*").
dd_template(month, l4dd_month/2, "the month number of *a date* is *a number*").
dd_template(year, l4dd_year/2, "the year number of *a date* is *a number*").

uses_daydate :-
    (   template_(l4dd_serial/2, _, _) -> true
    ;   forall(dd_template(_, FA, T), assertz(template_(FA, T, [included])))
    ).

dd_lit(K, Args, L) :- uses_daydate, dd_template(K, F/_, _), L =.. [F|Args].

month_number(N, M) :-
    nth1(M, ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
             'September', 'October', 'November', 'December'], Full),
    ( N == Full ; sub_atom(Full, 0, 3, _, N), N \== 'May' ), !.

daydate_constant('Months in a year', 12).
daydate_constant('Days in a year', 365.2425).
daydate_constant('Days in a month', 30.436875).
daydate_constant('Days in a week', 7).

%   daydate(+Name, +Args, +Env, ?V, -Goal)
daydate(N, [], _, V, G) :- daydate_constant(N, C), !, bind(V, C, G).
daydate(N, [], _, V, G) :- month_number(N, M), !, bind(V, M, G).
daydate(N, [D, M, Y], Env, V, G) :- memberchk(N, ['Date', 'DATE_FROM_DMY']), !,
    make_date(D, M, Y, Env, V, G).
daydate(N, [D, Y], Env, V, G) :- month_number(N, M), !, make_date(D, num(M), Y, Env, V, G).
daydate(N, [S], Env, V, G) :- memberchk(N, ['Date', 'DATE_FROM_SERIAL']), !,
    arith(S, Env, XS, G0), ( number(XS) -> SV = XS, G1 = G0 ; conj(G0, SV is XS, G1) ),
    dd_lit(of_serial, [SV, V], L), conj(G1, L, G).
daydate(N, [X], Env, V, G) :- memberchk(N, ['Day', 'Date to days', 'DATE_SERIAL', 'DATEVALUE']), !,
    val(X, Env, XV, G0), dd_lit(serial, [XV, V], L), conj(G0, L, G).
daydate('Day', [D, M, Y], Env, V, G) :- !,
    make_date(D, M, Y, Env, DV, G0), dd_lit(serial, [DV, V], L), conj(G0, L, G).
daydate(N, [X], Env, V, G) :- memberchk(N-K, ['DATE_DAY'-day, 'DATE_MONTH'-month, 'DATE_YEAR'-year]), !,
    val(X, Env, XV, G0), dd_lit(K, [XV, V], L), conj(G0, L, G).

%   A date from its day, month and year: a constant when they are numbers
make_date(D, M, Y, Env, V, G) :-
    arith(D, Env, XD, GD), arith(M, Env, XM, GM), arith(Y, Env, XY, GY),
    (   integer(XD), integer(XM), integer(XY), catch(l4_date(XD, XM, XY, C), _, fail)
    ->  bind(V, C, G)
    ;   num_var(XD, VD, G1), num_var(XM, VM, G2), num_var(XY, VY, G3),
        dd_lit(make, [VD, VM, VY, V], L),
        conj(GD, GM, A1), conj(A1, GY, A2), conj(A2, G1, A3), conj(A3, G2, A4), conj(A4, G3, A5),
        conj(A5, L, G)
    ).

num_var(X, X, true) :- ( var(X) ; number(X) ), !.
num_var(X, V, V is X).

%   a date written in the program: normalised as L4 does (35 January is
%   4 February)
l4_date(D, M, Y, date(Y1, M1, D1)) :-
    date_time_stamp(date(Y, M, D, 0, 0, 0, 0, -, -), T),
    stamp_date_time(T, date(Y1, M1, D1, _, _, _, _, _, _), 'UTC').

		 /*******************************
		 *           RECORDS            *
		 *******************************/

%   The facts of a record written as a value: Id's fields, each a fact
%   asserted with call(Store, Id, Literal). A record inside it is an
%   individual of its own.
record_facts(app(T, Args), Id, Store) :- rectype_(T, Fs), !,
    length(Fs, N), length(Args, N),
    ( conpred_(T, CF) -> CL =.. [CF, Id], call(Store, Id, CL) ; true ),
    forall(nth1(I, Fs, field(FN, _)), ( nth1(I, Args, A), field_fact(T, FN, A, Id, Store) )).
record_facts(app_named(T, Pairs), Id, Store) :- rectype_(T, _), !,
    ( conpred_(T, CF) -> CL =.. [CF, Id], call(Store, Id, CL) ; true ),
    forall(member(FN=A, Pairs), field_fact(T, FN, A, Id, Store)).
record_facts(E, _, _) :- throw(residue('not a record', E)).

field_fact(T, FN, A, Id, Store) :-
    field_(T, FN, f(F, Bool, _)),
    (   Bool == true
    ->  (   A = app('TRUE', []) -> L =.. [F, Id], call(Store, Id, L)
        ;   A = app('FALSE', []) -> true
        ;   throw(residue('a yes-or-no field that is not TRUE or FALSE', A))
        )
    ;   A = app('NOTHING', []) -> true
    ;   ( A = app('JUST', [A1]) -> true ; A1 = A ),
        (   catch(const_value(A1, Id-FN, Store, C), residue(_, _), fail)
        ->  L =.. [F, Id, C], call(Store, Id, L)
        ;   Store == rec_store
        ->  %  a field the program computes (`IS Trillion 3`): a rule
            val(A1, [], V, G), L =.. [F, Id, V], rule_item(L, G, Item), assertz(item_(Item))
        ;   const_value(A1, Id-FN, Store, _)
        )
    ).

%   A value written in the program or a test, as an LE constant; a record
%   becomes an individual (named after its parent and field)
const_value(num(N), _, _, N) :- !.
const_value(str(S), _, _, S) :- !.
const_value(app('TRUE', []), _, _, true) :- !.
const_value(app('FALSE', []), _, _, false) :- !.
const_value(app('EMPTY', []), _, _, []) :- !.
const_value(list(Es), Ctx, Store, Vs) :- !, const_values(Es, Ctx, Store, Vs).
const_value(percent(num(N)), _, _, V) :- !, V is N / 100.
const_value(app(C, []), _, _, A) :- enumcon_(C, _, []), !, con_atom(C, A).
const_value(app(N, []), _, _, Id) :- sym_(key(top, N), s(recconst(Id), _, _, _, _, _)), !.
const_value(E, Ctx, Store, Id) :- record_literal(E), !,
    fresh_record_id(Ctx, E, Id), record_facts(E, Id, Store).
const_value(app(N, Args), _, _, C) :- \+ sym_(key(top, N), _), daydate(N, Args, [], C, true), ground(C), !.
const_value(E, Ctx, Store, Id) :- fail, record_literal(E), !,
    fresh_record_id(Ctx, E, Id), record_facts(E, Id, Store).
const_value(E, _, _, _) :- throw(residue('a value that is not a constant', E)).

fresh_record_id(_, E, Id) :-
    ( E = app(T, _) ; E = app_named(T, _) ), !,
    name_words(T, Ws), atomic_list_concat(Ws, '_', T0), downcase_atom(T0, T1),
    next(rec(T1), N), atomic_list_concat([T1, N], '_', Id).

		 /*******************************
		 *            TESTS             *
		 *******************************/

%   Each #EVAL / #ASSERT, with the evaluator's result on its line
directive_tests(Is, Results, Doc, Tests) :-
    findall(T, ( member(directive(D, _, pos(L1, _)), Is),
                 directive_test(D, L1, Results, Doc, T) ), Tests).

directive_test(D, Line, Results, Doc, Test) :-
    ( D = eval(E) -> Kind = eval ; D = assert(E) -> Kind = assert ; fail ),
    \+ contract_expr(E),
    (   oracle_at(Line, Results, R)
    ->  catch(( eval_test(E, Line, R, Doc, Test0) -> Test = Test0 ; throw(residue('no LE form', E)) ),
              residue(Why, X), ( residue_test(Kind, Line, Why, X, Doc, _) ))
    ;   format(string(W), "#~w at line ~w: the evaluator gave no result", [Kind, Line]),
        ledger(entry(W, test, residue, 'no oracle result', none, '')), fail
    ).

contract_expr(E) :- sub_term(app(N, _), E), atom(N), contract_(N), !.

oracle_at(Line, Results, R) :-
    member(R0, Results), R0.start.line =:= Line, !,
    R0.success == true, R = R0.result.

residue_test(Kind, Line, Why, X, Doc, test(Id, Doc, At, [], [])) :-
    format(atom(Id), "line_~w", [Line]), format(atom(At), "line ~w", [Line]),
    format(string(W), "#~w at line ~w", [Kind, Line]),
    ( string(X) -> D = X ; residue_detail(X, D) ),
    format(string(N), "~w: ~w", [Why, D]),
    ledger(entry(W, test, residue, N, none, '')), fail.

%   The test of one directive: a query and the evaluator's answer
eval_test(E, Line, R, Doc, test(Id, Doc, At, Facts, [Expect])) :-
    format(atom(Id), "line_~w", [Line]), format(atom(At), "line ~w", [Line]),
    format(atom(QN), "line_~w", [Line]),
    retractall(scen_fact_(_)),
    (   l4_value_text(R, RV) -> true ; throw(residue('the evaluator''s answer is not a value LE writes', R)) ),
    test_query(E, RV, Line, Query, Answers),
    findall(L, scen_fact_(L), Facts),
    Expect = expects(QN, Answers),
    assertz(item_(test_query(QN, Query))),
    format(string(W), "#EVAL at line ~w", [Line]),
    ledger(entry(W, test, encoded, 'a query and the evaluator''s answer', QN, '')).

:- thread_local scen_fact_/1.
rec_store(Id, L) :- assertz(recfact_(Id, L)).
scen_store(_, L) :- assertz(scen_fact_(L)).

%   A yes-or-no definition with constant inputs: the query is its sentence
test_query(app(N, Args), RV, _, Q, Answers) :-
    memberchk(RV, [true, false]),
    sym_(key(top, N), s(K, Ps, [], _, F, _)), memberchk(K, [pred, undefined_pred]),
    length(Ps, NP), length(Args, NP),
    test_args(Args, Cs), !,
    Q =.. [F|Cs],
    ( RV == true -> Answers = [Q] ; Answers = [] ).
%   A value definition with constant inputs, whose answer is not a number
test_query(app(N, Args), RV, _, Q, [A]) :-
    \+ number(RV),
    sym_(key(top, N), s(K, Ps, [], _, F, _)), memberchk(K, [func, undefined_func]),
    length(Ps, NP), length(Args, NP),
    test_args(Args, Cs), !,
    append(Cs, [_], QA), Q =.. [F|QA],
    append(Cs, [RV], AA), A =.. [F|AA].
%   Anything else: the check `L4's answer at line N is reproduced`
test_query(E, RV, Line, Q, [Q]) :-
    check_functor(Line, F),
    Q =.. [F],
    const_args_env(E, E1),
    (   memberchk(RV, [true, false]), is_bool(E1, [])
    ->  cond(E1, [], G0), ( RV == true -> G = G0 ; G = not(G0) )
    ;   number(RV)
    ->  val(E1, [], V, G1), tolerance(RV, S, Lo, Hi),
        conj(G1, V * S >= Lo, G2), conj(G2, V * S =< Hi, G)
    ;   val(E1, [], V, G1), conj(G1, V = RV, G)
    ),
    rule_item(Q, G, It), assertz(item_(It)).

%   L4 prints a number with all its digits and LE may compute it with its
%   last digits different: the check allows one part in a billion
%   (written with whole numbers only: V * S between C - 1 and C + 1)
tolerance(RV, S, Lo, Hi) :-
    M is max(1.0, abs(RV)), K0 is 9 - floor(log10(M)), K is max(0, min(12, K0)),
    S is 10^K, C is round(RV * S),
    Lo is C - 1, Hi is C + 1.

%   One template per check: a check that waits for a residue (le_migration's
%   pending expectations follow templates) holds up no other
check_functor(Line, F) :-
    format(atom(F), 'l4_answer_at_line_~w', [Line]),
    format(string(T), "L4's answer at line ~w is reproduced", [Line]),
    assertz(template_(F/0, T, [])).

test_args([], []).
test_args([A|As], [C|Cs]) :- const_value(A, test, scen_store, C), test_args(As, Cs).

%   records written inside a test expression become scenario individuals
const_args_env(E, ind(Id)) :- record_literal(E), !, const_value(E, test, scen_store, Id).
const_args_env(E, E) :- \+ compound(E), !.
const_args_env(E0, E) :- E0 =.. [F|As0], maplist(const_args_env, As0, As), E =.. [F|As].

%   the query items of the tests, placed after the rules
tests_queries(_Tests, Items0, Items) :-
    findall(query(QN, Q), member(test_query(QN, Q), Items0), Qs),
    exclude([I]>>( I = test_query(_, _) ), Items0, Items1),
    append(Items1, Qs, Items).

%!  l4_value_text(+OracleText, -Value) is semidet.
%
%   The evaluator's printed value as an LE constant: TRUE/FALSE, a number, a
%   string, a constructor of a choice, a list of those.
l4_value_text(T, V) :-
    string_codes(T, Cs), phrase(l4v(V0), Cs), !, V = V0.

l4v(true) --> "TRUE".
l4v(true) --> "assertion satisfied".
l4v(false) --> "assertion failed".
l4v(false) --> "FALSE".
l4v(N) --> number(N).
l4v(S) --> "\"", string_without("\"", Cs), "\"", { string_codes(S, Cs) }.
l4v([]) --> "EMPTY".
l4v(nothing) --> "NOTHING".
l4v(date(Y, M, D)) --> "DATE OF ", integer(D), ", ", integer(M), ", ", integer(Y).
l4v(V) --> "JUST OF ", l4v(V).
l4v(L) --> "LIST ", l4vs(L).
l4v(A) --> "`", string_without("`", Cs), "`", { atom_codes(C, Cs), enumcon_(C, _, []), con_atom(C, A) }.
l4v(A) --> csym_codes(Cs), { atom_codes(C, Cs), enumcon_(C, _, []), con_atom(C, A) }.
l4vs([V|Vs]) --> l4v(V), ( ", " -> l4vs(Vs) ; { Vs = [] } ).

csym_codes([C|Cs]) --> [C], { code_type(C, csymf) }, csyms(Cs).
csyms([C|Cs]) --> [C], { code_type(C, csym) }, !, csyms(Cs).
csyms([]) --> [].

		 /*******************************
		 *   VARIANTS (ASSUMEd FACTS)   *
		 *******************************/

%!  variant_jobs(+File, +Model, -Jobs) is det.
%
%   A program whose facts are ASSUMEd cannot be evaluated as it is. Its
%   variants can: each assumed type (`ASSUME Person IS A TYPE`) is given
%   one individual (`person1`), each assumed yes-or-no fact or function a
%   value (TRUE or FALSE, for that individual), each assumed function to an
%   assumed type that type's individual; and each top-level yes-or-no
%   decision over those types is #EVALed. Jobs are job(Decision,
%   Assignment, Text): every combination of the facts the decision rests on
%   up to eight; else all true, all false and each one flipped.
variant_jobs0(File, l4_module(Is, _), Jobs) :-
    assumed(Is, Types, Facts),
    Facts \== [], !,
    read_file_to_string(File, Src, [encoding(utf8)]),
    split_string(Src, "\n", "", Lines),
    findall(D-Inds-Deps,
            ( member(decide(_, sig(Gs, _), appform(D, _, _, _), B, _, _), Is),
              \+ record_literal(B), \+ is_contract(sig(Gs, none), B),
              findall(I, ( member(param(_, tyapp(T, []), _), Gs), memberchk(T-I, Types) ), Inds),
              length(Gs, NG), length(Inds, NG),
              \+ recursive(D, B, Is),
              depends(B, Is, Facts, Deps), Deps \== [] ), Decisions),
    findall(job(D, Assign, Text),
            ( member(D-Inds-Deps, Decisions),
              assignments(Deps, Assign0),
              member(Assign0v, Assign0),
              findall(P-false, ( member(fact(P, K, _, _), Facts), K \== val, \+ memberchk(P-_, Assign0v) ), Others),
              append(Assign0v, Others, Assign),
              variant_text(Lines, Types, Facts, Assign, D, Inds, Text) ),
            Jobs).
variant_jobs0(_, _, []).

%   The assumed types (Type-Individual) and facts:
%   fact(Name, prop|bool|val, ArgIndividuals, pos(L1, L2))
assumed(Is, Types, Facts) :-
    findall(T-I, ( member(assume(_, appform(T, [], _, _), type, _, _), Is), ind_name(T, I) ), Types),
    findall(fact(N, K, Args, Pos),
            ( member(assume(sig(Gs, _), appform(N, _, _, _), Ty, _, Pos), Is),
              assumed_fact(Ty, Gs, Types, K, Args) ), Facts).

assumed_fact(tyapp('BOOLEAN', []), [], _, prop, []).
assumed_fact(fun(ArgTs, tyapp('BOOLEAN', [])), [], Types, bool, Args) :-
    type_inds(ArgTs, Types, Args).
assumed_fact(fun(ArgTs, tyapp(B, [])), [], Types, val, Args) :-
    memberchk(B-_, Types),
    type_inds(ArgTs, Types, Args).

type_inds([], _, []).
type_inds([tyapp(T, [])|Ts], Types, [I|Is]) :- memberchk(T-I, Types), type_inds(Ts, Types, Is).

const_values([], _, _, []).
const_values([E|Es], Ctx, Store, [V|Vs]) :- const_value(E, Ctx, Store, V), const_values(Es, Ctx, Store, Vs).

ind_name(T, I) :- name_words(T, Ws), atomic_list_concat(Ws, '', A0), downcase_atom(A0, A), atom_concat(A, '1', I).

%   A decision that calls itself: with one individual per type it would
%   never end (a person is their own father), in L4 as in LE
recursive(D, B, Is) :- recursive_(D, B, Is, []).
recursive_(D, B, Is, Seen) :-
    sub_term(app(N, _), B), atom(N),
    (   N == D -> true
    ;   \+ memberchk(N, Seen), member(decide(_, _, appform(N, _, _, _), B2, _, _), Is), recursive_(D, B2, Is, [N|Seen])
    ), !.

depends(B, Is, Facts, Deps) :-
    depends_(B, Is, Facts, [], Deps0), sort(Deps0, Deps).
depends_(B, Is, Facts, Seen, Deps) :-
    findall(N, ( sub_term(app(N, _), B), atom(N) ), Ns0), sort(Ns0, Ns),
    findall(N, ( member(N, Ns), memberchk(fact(N, K, _, _), Facts), K \== val ), D0),
    findall(D1, ( member(N, Ns), \+ memberchk(N, Seen),
                  member(decide(_, _, appform(N, _, _, _), B2, _, _), Is),
                  depends_(B2, Is, Facts, [N|Seen], D1) ), D1s),
    append([D0|D1s], Deps).

assignments(Deps, As) :-
    length(Deps, N),
    (   N =< 8
    ->  findall(A, maplist([D, D-V]>>member(V, [true, false]), Deps, A), As)
    ;   maplist([D, D-true]>>true, Deps, AllT), maplist([D, D-false]>>true, Deps, AllF),
        findall(A, ( nth1(I, Deps, _), findall(D-V, ( nth1(J, Deps, D), ( I == J -> V = false ; V = true ) ), A) ), Flips),
        As = [AllT, AllF|Flips]
    ).

variant_text(Lines, Types, Facts, Assign, D, Inds, Text) :-
    length(Lines, NL),
    findall(Out, ( between(1, NL, I), nth1(I, Lines, Line), variant_line(I, Line, Types, Facts, Assign, Out) ), Outs),
    atomic_list_concat(Inds, ' ', IA),
    format(string(Ev), "#EVAL `~w` ~w", [D, IA]),
    append(Outs, ["", Ev], All),
    atomic_list_concat(All, '\n', A), atom_string(A, Text).

:- thread_local assume_pos_/3.   % Line1, Line2, Kind

variant_line(I, _, Types, Facts, Assign, Out) :-
    assume_at(I, Types, Facts, What), !,
    (   What = first(W) -> variant_def(W, Types, Assign, Out) ; Out = "" ).
variant_line(_, Line, _, _, _, Line).

assume_at(I, Types, Facts, What) :-
    (   member(fact(N, K, Args, pos(L1, L2)), Facts), I >= L1, I =< L2 -> W = fact(N, K, Args)
    ;   b_getval(l4_variant_types, TPs), member(T-pos(L1, L2), TPs), I >= L1, I =< L2 -> W = type(T), memberchk(T-_, Types)
    ), !,
    ( I =:= L1 -> What = first(W) ; What = rest ).

variant_def(type(T), Types, _, Out) :- memberchk(T-Ind, Types), format(string(Out), "DECLARE `~w` IS ONE OF ~w", [T, Ind]).
variant_def(fact(N, prop, []), _, Assign, Out) :- memberchk(N-V, Assign), l4_bool(V, B), format(string(Out), "`~w` MEANS ~w", [N, B]).
variant_def(fact(N, bool, Args), Types, Assign, Out) :-
    memberchk(N-V, Assign), l4_bool(V, B), givens(Args, Types, GT, XS),
    format(string(Out), "GIVEN ~w~nGIVETH A BOOLEAN~n`~w` ~w MEANS ~w", [GT, N, XS, B]).
variant_def(fact(N, val, Args), Types, _, Out) :-
    fact_result_type(N, RT), memberchk(RT-RI, Types), givens(Args, Types, GT, XS),
    format(string(Out), "GIVEN ~w~nGIVETH A `~w`~n`~w` ~w MEANS ~w", [GT, RT, N, XS, RI]).

givens(Args, Types, GT, XS) :-
    findall(G-X, ( nth1(K, Args, I), memberchk(T-I, Types), format(atom(X), "x~w", [K]), format(atom(G), "~w IS A `~w`", [X, T]) ), Ps),
    pairs_keys_values(Ps, Gs, Xs),
    atomic_list_concat(Gs, ', ', GT), atomic_list_concat(Xs, ' ', XS).

fact_result_type(N, RT) :- b_getval(l4_variant_model, Is), member(assume(_, appform(N, _, _, _), fun(_, tyapp(RT, [])), _, _), Is), !.

l4_bool(true, 'TRUE').
l4_bool(false, 'FALSE').

%!  variants_hash(+Jobs, -Hash) is det.
%   What the cached results of the variants were run on
variants_hash(Jobs, Hash) :-
    findall(T, member(job(_, _, T), Jobs), Ts),
    atomic_list_concat(Ts, '\n#---\n', A),
    crypto_data_hash(A, Hash, [algorithm(sha1)]).

%   The entry: variant_jobs0/3 with the model's type positions at hand
variant_jobs(File, Model, Jobs) :-
    Model = l4_module(Is, _),
    findall(T-P, member(assume(_, appform(T, [], _, _), type, _, P), Is), TPs),
    b_setval(l4_variant_types, TPs), b_setval(l4_variant_model, Is),
    variant_jobs0(File, Model, Jobs).

%   The variants' results (runs/variants/<Id>.json, written by build.pl
%   through l4_oracle.mjs) as scenarios
variant_tests(File, Model, Options, Doc, Tests) :-
    option(id(Id), Options),
    here_(H), atomic_list_concat([H, '/runs/variants/', Id, '.json'], F),
    exists_file(F), !,
    setup_call_cleanup(open(F, read, S, [encoding(utf8)]), json_read_dict(S, Cache), close(S)),
    variant_jobs(File, Model, Jobs),
    variants_hash(Jobs, Hash),
    (   atom_string(Hash, HS), Cache.get(hash) == HS -> Runs = Cache.runs ; throw(error(variants_stale(Id), _)) ),
    Model = l4_module(Is, _), assumed(Is, _, Facts),
    findall(T, ( nth1(I, Jobs, job(D, Assign, Text)), nth1(I, Runs, R),
                 variant_test(I, D, Assign, Text, Facts, R, Doc, T) ), Tests).
variant_tests(_, _, _, _, []).

variant_test(I, D, Assign, Text, Facts, R, Doc, test(Id, Doc, 'a variant of the program: each ASSUMEd fact given a value', Lits, [expects(QN, Answers)])) :-
    split_string(Text, "\n", "", TLs), length(TLs, LastLine),
    member(Res, R.results), Res.start.line =:= LastLine, !, Res.success == true,
    sym_(key(top, D), s(pred, _, [], _, F, _)),
    split_string(Text, "\n", "", Ls), last(Ls, EvalLine),
    split_string(EvalLine, " ", "", Ws), last(Ws, _),
    findall(L, ( member(fact(P, K, Args, _), Facts),
                 (   K == val -> fact_result_type(P, RT), ind_name(RT, RI), append(Args, [RI], AAs)
                 ;   memberchk(P-true, Assign), AAs = Args ),
                 sym_(key(top, P), s(_, _, [], _, PF, _)), L =.. [PF|AAs] ), Lits),
    eval_inds(EvalLine, D, Inds),
    format(atom(Id), "variant_~w", [I]),
    Q =.. [F|Inds], name_words(D, Ws2), atomic_list_concat(Ws2, '_', QN0), downcase_atom(QN0, QN),
    ( item_(test_query(QN, _)) -> true ; assertz(item_(test_query(QN, Q))) ),
    ( Res.result == "TRUE" -> Answers = [Q] ; Answers = [] ).

eval_inds(Line, D, Inds) :-
    format(string(Pre), "#EVAL `~w`", [D]),
    string_concat(Pre, Rest, Line),
    split_string(Rest, " ", " ", Ws0), exclude(==(""), Ws0, Ws),
    maplist([W, A]>>atom_string(A, W), Ws, Inds).

		 /*******************************
		 *        THE CONTRACTS HALF    *
		 *******************************/

contract_half(Model, Options, Items, Tests, Ledger) :-
    catch(current_predicate(l4_contracts:contract_items/4), _, fail), !,
    findall(sym(N, K, F/Ar, T), ( sym_(key(top, N), s(K0, Ps, _, _, F, T)), atom(F),
                                  kind_name(K0, K), length(Ps, NP),
                                  ( K == func -> Ar is NP + 1 ; Ar = NP ) ), Syms),
    l4_contracts:contract_items(ctx(Model, Options, Syms), Items, Tests, Ledger).
contract_half(_, _, [], [], []).

kind_name(pred, pred).
kind_name(func, func).
kind_name(undefined_pred, undefined).
kind_name(undefined_func, undefined).

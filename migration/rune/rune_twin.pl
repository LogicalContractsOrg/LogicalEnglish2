:- module(rune_twin, [
    report_twin/3,          % +Report, +Options, -Twin
    report_twin_layers/3,   % +Report, +Options, -twin(Layers, Ledger, Fields)
    namespace_twin/3,       % +Namespaces, +Options, -twin(Layers, Ledger, [])
    layer_order/1,          % -[main, drr, cdm]: from the program a user opens down
    attribute_template/3    % ?Attr, -Functor, -Text: the scenario facts' templates
]).
/** <module> A DRR report as a Logical English twin

    report_twin(+Report, +Options, -twin(IR, Ledger, Fields))

The closure of the report (rune_closure.pl) written as the Migration IR of
LE2's writer (le_writer.pl), in the shape the hand twin fixed (step 0,
examples/migration/rune/hand/ of the private place):

- one template per attribute name the closure reads, `the reporting side of
  *a transaction report instruction* is *a reporting side*` (a general word
  for the owner when several types have the attribute);
- one template per function, `the party LEI of *a list of party
  identifiers* is *a party LEI*`, or a sentence when the function is a
  test (`*a workflow step* is cleared`);
- one template per reporting rule, `the counterparty 1 of *a transaction
  report instruction* is *a value*`;
- one rule per field of the report, `the CFTC Part45 field "13 Counterparty
  1" of an instruction is a value if ...`, with the regulation's passage as
  its provenance and the industry's reading as `according to`.

**The semantics**, Rune's (the runtime's ExpressionOperatorsNullSafe):

| Rune | LE |
|---|---|
| a value is a list; a path over a list flattens | a condition that gives one answer per element, in order |
| `if C then A else B` at the top of a rule | one rule for `C` and `A`, one for `it is not the case that C` and `B` |
| `if` inside an expression | `(C and A) or (not C and B)` |
| `a = b`, one value each | the same value; an absent side makes it false |
| `a = b`, `a` a list | every element is `b`, and there is one (`any =`: one of them is) |
| `a <> b` | it is not the case that `a = b` (an absent side makes it true) |
| `exists`, `is absent` | a value / it is not the case that there is a value |
| `only-element`, `first`, `last`, `distinct`, `count`, `sum` | the list of each value, then the library (`lib/rune.le`) |
| a function's input with one value (`(1..1)`) | the value; with possibly none or several (`(0..1)`, `(0..*)`), a list |
| `filter`, `extract`, `then` | conditions on each element, the implicit item bound |

What cannot be written yet is residue: the definition, or the alternative
of it, is left out, recorded in the ledger, and every expectation that
depends on it is pending (le_migration.pl).
*/

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(assoc)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(parser/rune_reader).
:- use_module(rune_types).
:- use_module(rune_closure).
:- use_module(rune_data, [type_feature/3, value_type/2]).

:- dynamic tmpl/4.            % tmpl(Key, Functor, Text, Arity)
:- dynamic aux_count/1.
:- dynamic cons_site/5.       % cons_site(Site, Type, Pairs, Env, Inputs)
:- dynamic cons_owner/2.      % cons_owner(Site, Q): the definition that builds it

% ---------------------------------------------------------------- entry

%!  report_twin(+Report, +Options, -Twin) is det.
report_twin(Report, _Opts, twin(Items, Ledger, Fields)) :-
    twin_reset,
    report_closure(Report, Closure),
    report_fields(Report, Fields0),
    field_templates(Report),
    closure_items(Closure, Templates, DefItems, RefItems, Ledger),
    report_field_rules(Report, Fields0, Fields, FieldItems),
    append([Templates, DefItems, RefItems, FieldItems], Items).

twin_reset :-
    retractall(tmpl(_, _, _, _)), retractall(single_attr(_)), retractall(cons_site(_, _, _, _, _)), retractall(cons_owner(_, _)), retractall(def_title_of(_, _)),
    nb_setval(rune_cons_counter, 0), nb_setval(rune_def, none), nb_setval(rune_lift_n, 0).

%   The templates, definitions and reference data of a closure.
closure_items(closure(Rules, Funcs, Attrs, _Enums, _), Templates, DefItems, RefItems, Ledger) :-
    attribute_templates(Attrs),
    meta_templates(Rules, Funcs),
    function_templates(Funcs),
    alias_templates(Funcs),
    rule_templates(Rules),
    reference_templates(Funcs),
    unique_templates,
    findall(D, ( member(Q, Funcs), nb_setval(rune_def, Q), ( define(func(Q), D) ; define_alias(Q, D) ) ), FDs),
    findall(D, ( member(Q, Rules), nb_setval(rune_def, Q), define(rule(Q), D) ), RDs),
    cons_definitions(CDs),
    append([FDs, RDs, CDs], Defs),
    defs_items(Defs, DefItems, Ledger),
    %  the definitions' templates are memorable: a test such as "the
    %  instruction is allowable action for CFTC", which most fields ask, is
    %  then worked out once per query
    findall(template(F, T, Adds), ( tmpl(K, F, T, _),
                                    (   memorable_kind(K) -> Adds = [memorable]
                                    ;   single_valued(K) -> Adds = [one_value]
                                    ;   Adds = [] ) ), Ts0),
    list_to_set(Ts0, Ts),
    lib_templates(LibTs),
    append([LibTs, Ts], Templates),
    reference_facts(RefItems).

%!  namespace_twin(+Namespaces, +Options, -twin(Layers, Ledger, [])) is det.
%
%   The twin of every rule and function of the namespaces (a Rune file with
%   no report: the CDM's functions, a user's own namespace), in layers as a
%   report's twin is: main holds the namespaces' own definitions.
namespace_twin(NSs, _Opts, twin(Layers, Ledger, [])) :-
    twin_reset,
    findall(rule(Q), ( rune_model:rune_rule(_, Q, _, _, _, _), q_namespace(Q, NS), memberchk(NS, NSs) ), Rs),
    findall(func(Q), ( rune_model:rune_func(Q, _, _, _, _, _, _), q_namespace(Q, NS), memberchk(NS, NSs) ), Fs),
    append(Rs, Fs, Roots),
    closure_of(Roots, Closure),
    closure_items(Closure, Templates, DefItems, RefItems, Ledger),
    append([Templates, DefItems, RefItems], Items),
    layered(Items, NSs, Layers).

%!  report_twin_layers(+Report, +Options, -twin(Layers, Ledger, Fields)) is det.
%
%   The twin in layers, Layers = [main-Items, drr-Items, cdm-Items], each
%   written to a file of its own, each including the next:
%
%   - main: what the user opens, the report's own namespace (the rules of
%     drr.regulation.cftc.rewrite.trade) and the report's fields;
%   - drr: the definitions of DRR's other namespaces the report needs (the
%     critical data elements, DRR's common rules);
%   - cdm: those of the CDM and of the other models DRR builds on, with the
%     attributes' templates and the reference data.
%
%   A definition goes to the layer of its namespace (an object a rule
%   builds, to the layer of the rule that builds it). Included files are
%   one knowledge base, so a rule may call a predicate of any layer; a
%   template must be declared where it is used or below, so each goes to
%   the lowest layer that defines or uses it.
report_twin_layers(Report, Opts, twin(Layers, Ledger, Fields)) :-
    report_twin(Report, Opts, twin(Items, Ledger, Fields)),
    rune_model:rune_report(Report, _, _, _, _, RT), q_namespace(RT, RNS),
    layered(Items, [RNS], Layers).

%   Items in layers: main for the namespaces MainNSs, then drr, then cdm.
layered(Items, MainNSs, Layers) :-
    partition([I]>>( I = template(_, _, _) ), Items, Templates, Rest),
    layer_items(Rest, MainNSs, LItems),
    layer_order(Order),
    findall(L-Is, ( member(L, Order), findall(I, member(L-I, LItems), Is) ), Layers0),
    maplist(layer_functors, Layers0, Used),
    findall(L-T, ( member(T, Templates), T = template(F, _, _), template_layer(F, Used, Order, L) ), LTs),
    findall(L-All, ( member(L-Is, Layers0), findall(T, member(L-T, LTs), Ts), append(Ts, Is, All) ), Layers).

layer_order([main, drr, cdm]).

%   Each item with its layer: a definition's title comment by the
%   definition, its rules and residue by the title before them, a field's
%   rule and a query in main, reference data in cdm; any other comment (a
%   reading of the industry, a note) goes with the item after it.
layer_items(Items, RNS, LItems) :-
    layer_pass(Items, RNS, cdm, Tagged),
    reverse(Tagged, Rev), pending_pass(Rev, main, LRev), reverse(LRev, LItems).

layer_pass([], _, _, []).
layer_pass([I|Is], RNS, Cur, [L-I|LIs]) :-
    (   I = comment(C), def_title(C, What) -> what_layer(What, RNS, L), Cur1 = L
    ;   I = comment(_) -> L = pending, Cur1 = Cur
    ;   I = rule(H, _, _), functor(H, report_field, _) -> L = main, Cur1 = Cur
    ;   I = query(_, _) -> L = main, Cur1 = Cur
    ;   I = fact(_) -> L = cdm, Cur1 = Cur
    ;   L = Cur, Cur1 = Cur
    ),
    layer_pass(Is, RNS, Cur1, LIs).

pending_pass([], _, []).
pending_pass([L0-I|Rest], Next, [L-I|Out]) :-
    ( L0 == pending -> L = Next ; L = L0 ),
    pending_pass(Rest, L, Out).

%   The definition a comment opens (def_items/3 writes the title first).
:- dynamic def_title_of/2.
def_title(C, What) :- def_title_of(C, What), !.

what_layer(What, RNS, L) :-
    (   What = cons(Site, _) -> ( cons_owner(Site, Q) -> true ; Q = none )
    ;   what_element(What, Q0), ( What = alias(Q1, _) -> Q = Q1 ; Q = Q0 )
    ),
    q_layer(Q, RNS, L).

q_layer(none, _, main) :- !.
q_layer(Q, RNS, L) :-
    q_namespace(Q, NS),
    (   memberchk(NS, RNS) -> L = main
    ;   sub_atom(NS, 0, _, _, 'drr.') -> L = drr
    ;   L = cdm
    ).

%   A qualified name's namespace: cdm.base.datetime.daycount.YearFraction(_1_1)
%   -> cdm.base.datetime.daycount.
q_namespace(Q, NS) :-
    ( sub_atom(Q, B, _, _, '(') -> sub_atom(Q, 0, B, _, Q1) ; Q1 = Q ),
    atomic_list_concat(Parts, '.', Q1), append(NSParts, [_], Parts),
    atomic_list_concat(NSParts, '.', NS).

%   The template functors a layer defines or uses.
layer_functors(L-Items, L-Fs) :-
    findall(F, ( member(I, Items), item_term(I, T), sub_term(S, T), compound(S), functor(S, F, _), tmpl(_, F, _, _) ), Fs0),
    sort(Fs0, Fs).
item_term(rule(H, B, _), H-B) :- !.
item_term(fact(H), H) :- !.
item_term(query(_, G), G) :- !.
item_term(residue(_, Opts), Opts) :- !.
item_term(_, none).

%   The lowest layer in which F is defined or used; a template no layer
%   names goes to the lowest.
template_layer(F, Used, Order, L) :-
    reverse(Order, Low),
    (   member(L, Low), memberchk(L-Fs, Used), ord_memberchk(F, Fs) -> true
    ;   Low = [L|_]
    ).


% ---------------------------------------------------------------- words

%!  words(+CamelCase, -Words) is det.
%
%   originatingWorkflowStep -> [originating, workflow, step];
%   LEIIdentifier -> ['LEI', identifier]; Counterparty1 -> [counterparty, '1'].
words(Name, Ws) :-
    atom_codes(Name, Cs0),
    maplist([C, D]>>( C == 0'_ -> D = 0'  ; D = C ), Cs0, Cs),
    breaks(Cs, Ds),
    atom_codes(A, Ds),
    split_string(A, " ", " ", Ss0), exclude(==(""), Ss0, Ss),
    maplist(word_case, Ss, Ws).

%   A space where a word ends: lower to upper (partyId), an acronym's end
%   (LEIIdentifier: LEI|Identifier), letters to digits and back. An
%   acronym's plural is one word (ClearingSwapUSIs: USIs, not "US Is"), where
%   its s ends the name; MICIsNot is still MIC|Is|Not.
breaks([], []).
breaks([C], [C]) :- !.
breaks([A, B|Cs], [A|Ds]) :-
    (   ( code_type(A, lower), code_type(B, upper)
        ; code_type(A, alpha), code_type(B, digit)
        ; code_type(A, digit), code_type(B, alpha)
        ; code_type(A, upper), code_type(B, upper), Cs = [C|Rest], code_type(C, lower),
          \+ acronym_plural(C, Rest) )
    ->  Ds = [0' |Ds1]
    ;   Ds = Ds1
    ),
    breaks([B|Cs], Ds1).

acronym_plural(0's, Rest) :-
    ( Rest == [] -> true ; Rest = [N|_], \+ code_type(N, alpha) ).

%   A word in lower case, an acronym as it is.
word_case(S, W) :-
    string_codes(S, Cs),
    (   Cs = [_, C2|_], code_type(C2, upper) -> atom_string(W, S)
    ;   string_lower(S, L), atom_string(W, L)
    ).

words_text(Ws, T) :- atomic_list_concat(Ws, ' ', T).

name_words(N, T) :- words(N, Ws), words_text(Ws, T).

short(Q, S) :- atomic_list_concat(Ps, '.', Q), last(Ps, S0),
    ( sub_atom(S0, B, _, _, '(') -> sub_atom(S0, 0, B, _, S) ; S = S0 ).

%   The words of a type, for a place of a template: CFTCPart45Leg ->
%   "CFTC Part 45 leg"; ActionTypeEnum -> "action type".
type_words(T, Text) :-
    short(T, S), words(S, Ws0),
    ( append(Ws1, [enum], Ws0), Ws1 \== [] -> Ws = Ws1 ; Ws = Ws0 ),
    words_text(Ws, Text).

article(Text, A) :-
    sub_atom(Text, 0, 1, _, C), downcase_atom(C, L),
    ( memberchk(L, [a, e, i, o, u]), \+ sub_atom(Text, 0, _, _, 'uni'), \+ sub_atom(Text, 0, _, _, 'UPI') -> A = an
    ; sub_atom(Text, 0, 2, _, Two), upcase_atom(Two, Two), atom_length(Text, N), N > 1,
      memberchk(C, ['F', 'H', 'L', 'M', 'N', 'R', 'S', 'X']) -> A = an      % an LEI, an FX
    ; A = a ).

place(Text0, P) :-
    no_digits(Text0, Text1), no_connectives(Text1, Text),
    article(Text, A), format(atom(P), '*~w ~w*', [A, Text]).

%   A place's name has none of LE's connectives: in `*an adjustable or
%   relative date*` the `or` ends the name, and the variable is read as a
%   constant (AdjustableOrRelativeDate -> `adjustable relative date`).
no_connectives(T0, T) :-
    atomic_list_concat(Ws0, ' ', T0),
    exclude([W]>>memberchk(W, [or, and, if, not, then, otherwise, unless, that, which, each, every, all, case, for]), Ws0, Ws1),
    ( Ws1 == [] -> Ws = [thing] ; Ws = Ws1 ),
    atomic_list_concat(Ws, ' ', T).

%   A place of a template has no digits in its name (LE reads `*a n 1*` as
%   something else): `trade lot 1` -> `trade lot one`.
no_digits(T0, T) :-
    atomic_list_concat(Ws0, ' ', T0),
    maplist([W0, W]>>( atom_number(W0, N), integer(N), N >= 0, N =< 12
                      -> nth0(N, [zero, one, two, three, four, five, six, seven, eight, nine, ten, eleven, twelve], W)
                      ; W = W0 ), Ws0, Ws),
    atomic_list_concat(Ws, ' ', T).

% ---------------------------------------------------------------- templates

%   One per attribute name. A word LE reads as its own (`value`) gets
%   "attribute" after it.
attribute_templates(Attrs) :-
    findall(A, member(_-A, Attrs), As0), sort(As0, As),
    forall(member(A, As), attribute_template_for(A, Attrs)).

attribute_template_for(A, Attrs) :-
    findall(O, member(O-A, Attrs), Os0), sort(Os0, Os),
    ( Os = [O] -> type_words(O, OW) ; OW = thing ),
    findall(VT, ( member(O2, Os), type_feature(O2, A, feature(VT, _, _)) ), VTs0), sort(VTs0, VTs),
    value_words(A, VTs, VW),
    attr_words(A, AW0),
    %  an option of a choice (Payout's InterestRatePayout) is "the interest
    %  rate payout option of a payout", apart from an attribute of the same
    %  words (PayoutLeg's interestRatePayout)
    (   Os \== [], forall(member(O1, Os), rune_model:rune_choice(O1, _))
    ->  atom_concat(AW0, ' option', AW)
    ;   AW = AW0
    ),
    place(OW, OP), place(VW, VP),
    format(atom(Text), 'the ~w of ~w is ~w', [AW, OP, VP]),
    attr_functor(A, F),
    assertz(tmpl(attr(A), F, Text, 2)),
    (   Os \== [], forall(member(O3, Os), type_feature(O3, A, feature(_, card(_, 1), _)))
    ->  assertz(single_attr(A))
    ;   true
    ).

%   An attribute that has at most one value on every type that has it
%   (cardinality (0..1) or (1..1) in Rune): its template is `; one value`,
%   which a case search uses (LE2 language.md, §2).
single_valued(attr(A)) :-
    single_attr(A).

:- dynamic single_attr/1.

attr_words(A, W) :-
    name_words(A, W0),
    ( reserved_words(W0) -> atom_concat(W0, ' attribute', W) ; W = W0 ).

reserved_words(W) :- memberchk(W, [value, count, list, sum, average, min, max, type, date, time,
    name, text, number, it, case, sentence]).

value_words(A, [VT], W) :- !,
    (   value_type(VT, object(Q)) -> type_words(Q, W)
    ;   value_type(VT, enum(Q)) -> type_words(Q, W)
    ;   value_type(VT, basic(boolean)) -> W = flag
    ;   VT == boolean -> W = flag
    ;   value_type(VT, basic(B)), memberchk(B, [date, zonedDateTime, dateTime, time]) -> name_words(A, W)
    ;   name_words(A, W0), ( reserved_words(W0) -> W = W0 ; W = W0 )
    ).
value_words(_, _, value).

attr_functor(A, F) :- atom_concat(a_, A, F).

%!  attribute_template(?Attr, -Functor, -Text) is nondet.
attribute_template(A, F, T) :- tmpl(attr(A), F, T, 2).

%   The metadata of a value: `the identifier scheme of *a party identifier* is *a scheme*`.
meta_templates(Rules, Funcs) :-
    findall(O-A, ( ( member(Q, Rules), rule_typed(Q, T, _)
                   ; member(Q, Funcs), rune_model:rune_func(Q, _, _, Steps, _, _, _),
                     member(St, Steps), rune_closure:step_where(St, W), func_step_typed(Q, W, T, _) ),
                   sub_term(M, T), nonvar(M), M = meta(_, O, A, _) ), OAs0),
    sort(OAs0, OAs),
    findall(A, member(_-A, OAs), As0), sort(As0, As),
    forall(member(A, As),
           ( findall(O, member(O-A, OAs), Os),
             ( Os = [O1] -> type_words(O1, OW) ; OW = thing ),
             name_words(A, AW), place(OW, OP),
             format(atom(Text), 'the ~w scheme of ~w is *a scheme*', [AW, OP]),
             atom_concat(m_, A, F),
             assertz(tmpl(meta(A), F, Text, 2)) )).

%   Functions: a test (boolean output) is a sentence about its first input;
%   any other is `the <name> of <inputs> is <output>`.
function_templates(Funcs) :-
    forall(( member(Q, Funcs), \+ lib_function(Q, _, _) ), function_template(Q, Funcs)).

function_template(Q, Funcs) :-
    rune_model:rune_func(Q, Ins, Out, _, _, _, _),
    short(Q, S), qualified_words(func, Q, S, Funcs, NW),
    maplist(input_place, Ins, Places),
    length(Ins, NI),
    (   boolean_output(Out)
    ->  bool_sentence(S, NW, Places, Text), Arity = NI
    ;   ( Out = out(ON, _, _) -> name_words(ON, OW0), place(OW0, OP) ; OP = '*a value*' ),
        ( Places == [] -> format(atom(Text), 'the ~w is ~w', [NW, OP])
        ; atomic_list_concat(Places, ' with ', PT),
          format(atom(Text), 'the ~w of ~w is ~w', [NW, PT, OP]) ),
        Arity is NI + 1
    ),
    func_functor(Q, F),
    assertz(tmpl(func(Q), F, Text, Arity)).

%   A test: a boolean output that is always there (1..1). One that may be
%   absent (0..1) is a value, "true" or "false" or none, as in Rune.
boolean_output(out(_, T, card(1, _))) :- ( T == boolean ; value_type(T, basic(boolean)) ), !.

input_place(in(N, _, card(_, Max)), P) :-
    name_words(N, W0),
    ( Max == 1, \+ optional_single(N) -> W = W0 ; format(atom(W), 'list of ~w', [W0]) ),
    place(W, P).
optional_single(_) :- fail.

bool_sentence(S, NW, Places, Text) :-
    words(S, Ws),
    (   Places = [P1|Ps] -> true ; P1 = none, Ps = [] ),
    (   Ws = [is|Rest], Rest \== [] -> words_text(Rest, R), format(atom(Core), 'is ~w', [R])
    ;   sub_atom(S, 0, _, _, 'Qualify_') -> sub_atom(S, 8, _, 0, Q0), name_words(Q0, R),
        format(atom(Core), 'qualifies as ~w', [R])
    ;   Ws = [has|Rest], Rest \== [] -> words_text(Rest, R), format(atom(Core), 'has ~w', [R])
    ;   format(atom(Core), 'satisfies ~w', [NW])
    ),
    (   P1 == none -> format(atom(Text), 'it holds that ~w', [NW])
    ;   ( Ps == [] -> Tail = '' ; atomic_list_concat(Ps, ' with ', PT), format(atom(Tail), ' with ~w', [PT]) ),
        format(atom(Text), '~w ~w~w', [P1, Core, Tail])
    ).

func_functor(Q, F) :- short(Q, S), downcase_atom(S, L), term_hash(Q, H), format(atom(F), 'f_~w_~w', [L, H]).
rule_functor(Q, F) :- short(Q, S), downcase_atom(S, L), term_hash(Q, H), format(atom(F), 'r_~w_~w', [L, H]).

%   A name used by two definitions of the closure: the namespace's tag first.
qualified_words(Kind, Q, S, All, NW) :-
    name_words(S, W0),
    (   member(Q2, All), Q2 \== Q, short(Q2, S), \+ (Kind == func, lib_function(Q2, _, _))
    ->  ns_tag(Q, Tag), format(atom(NW), '~w ~w', [Tag, W0])
    ;   NW = W0
    ).

ns_tag(Q, Tag) :-
    atomic_list_concat(Ps, '.', Q), append(NS, [_], Ps),
    (   append(_, [cde, V|_], NS), atom_concat(version, N, V) -> format(atom(Tag), 'CDE ~w', [N])
    ;   NS = [drr, regulation, R|More], R \== common ->
        upcase_atom(R, RU), ( memberchk(dtcc, More) -> format(atom(Tag), '~w DTCC', [RU]) ; Tag = RU )
    ;   NS = [drr, regulation, common|More] ->
        ( memberchk(dtcc, More) -> Tag = 'common DTCC' ; last(More, L) -> format(atom(Tag), 'common ~w', [L]) ; Tag = common )
    ;   NS = [cdm|_] -> last(NS, L), format(atom(Tag), 'CDM ~w', [L])
    ;   last(NS, L), Tag = L
    ).

rule_templates(Rules) :-
    forall(member(Q, Rules), rule_template(Q, Rules)).

rule_template(Q, Rules) :-
    rune_model:rune_rule(Kind, Q, In, _, _, _),
    short(Q, S), qualified_words(rule, Q, S, Rules, NW),
    ( In == none -> IP = '*a thing*' ; type_words(In, IW), place(IW, IP) ),
    rule_functor(Q, F),
    (   Kind == eligibility
    ->  ( words(S, [is|Rest]) -> words_text(Rest, R) ; R = NW ),
        format(atom(Text), '~w is ~w', [IP, R]),
        assertz(tmpl(rule(Q), F, Text, 1))
    ;   format(atom(Text), 'the ~w of ~w is *a value*', [NW, IP]),
        assertz(tmpl(rule(Q), F, Text, 2))
    ).

field_templates(Report) :-
    rune_model:rune_report(Report, _, _, In, _, _),
    type_words(In, IW), place(IW, IP),
    format(atom(Text), 'the ~w field *a field* of ~w is *a value*', [Report, IP]),
    assertz(tmpl(field, report_field, Text, 3)).

%   An alias of a function is a rule of its own, on the function's inputs:
%   `the reporting party lei of *a reporting side* is *a value*`, or a
%   sentence when it is a test. A text another template has already gets
%   the function's words after it.
alias_templates(Funcs) :-
    forall(( member(Q, Funcs), \+ lib_function(Q, _, _),
             rune_model:rune_func(Q, Ins, _, Steps, _, _, _), member(alias(N, W), Steps) ),
           alias_template(Q, Ins, N, W)).

alias_template(Q, Ins, N, W) :-
    maplist(input_place, Ins, Places),
    name_words(N, AW0), attr_words_clean(AW0, AW),
    (   func_step_typed(Q, W, T, _), condition_like(T)
    ->  ( Places == [] -> format(atom(Text0), 'it holds that ~w', [AW]) ; bool_sentence(N, AW, Places, Text0) ),
        length(Ins, Ar), Kind = condition
    ;   ( Places == [] -> format(atom(Text0), 'the ~w is *a value*', [AW])
        ; atomic_list_concat(Places, ' with ', PT), format(atom(Text0), 'the ~w of ~w is *a value*', [AW, PT]) ),
        length(Ins, N0), Ar is N0 + 1, Kind = value
    ),
    Text = Text0,
    term_hash(Q-N, H), format(atom(F), 'al_~w_~w', [N, H]),
    assertz(tmpl(alias(Q, N, Kind), F, Text, Ar)).

attr_words_clean(W, W).

alias_call(N, _, cenv(Vs, _), Want, V, G) :-
    memberchk('$func'-f(Q, Args), Vs),
    tmpl(alias(Q, N, Kind), F, _, _), !,
    (   Kind == condition
    ->  L =.. [F|Args],
        ( Want == condition -> G = L ; G = or(and(L, V = "true"), and(not(L), V = "false")) )
    ;   append(Args, [X], All), L =.. [F|All],
        ( Want == value -> V = X, G = L ; G = and(L, X = "true") )
    ).
alias_call(_, T, Env, value, V, G) :- cs(T, Env, V, G).
alias_call(_, T, Env, condition, _, G) :- cc(T, Env, G).

%   The clauses of an alias.
define_alias(Q, def(alias(Q, N), Clauses, Problems)) :-
    \+ lib_function(Q, _, _),
    rune_model:rune_func(Q, Ins, _, Steps, _, _, _),
    member(alias(N, W), Steps),
    tmpl(alias(Q, N, Kind), F, _, _),
    maplist(input_var, Ins, Bindings, Args),
    Env = cenv(['$func'-f(Q, Args)|Bindings], none),
    (   func_step_typed(Q, W, T, _)
    ->  (   Kind == condition
        ->  Head =.. [F|Args], cond_alternatives(T, Env, Head, Alts)
        ;   append(Args, [V], HA), Head =.. [F|HA], alternatives(T, Env, V, Head, Alts)
        ),
        alts_clauses(Alts, Clauses, Problems)
    ;   Clauses = [], Problems = [untyped]
    ).

%   LE tells templates apart by their words, not by the names of their
%   places: two templates with the same words would be one relation. The
%   attributes' templates come first; a later template whose words another
%   has gets words of its own (its function's, or its namespace's).
unique_templates :-
    findall(L, ( lib_template(_, T), signature(T, L) ), Lib),
    list_to_assoc_keys(Lib, S0),
    findall(K-T, ( member(Kind, [attr, meta, func, rule, alias, field]),
                   tmpl(K, _, T, _), key_kind(K, Kind) ), KTs),
    foldl(unique_one, KTs, S0, _).

memorable_kind(func(_)).
memorable_kind(rule(_)).
memorable_kind(alias(_, _, _)).

key_kind(attr(_), attr).
key_kind(meta(_), meta).
key_kind(func(_), func).
key_kind(rule(_), rule).
key_kind(alias(_, _, _), alias).
key_kind(field, field).
key_kind(reference(_), reference).

list_to_assoc_keys(Ks, A) :- findall(K-x, member(K, Ks), Ps0), sort(Ps0, Ps), list_to_assoc(Ps, A).

unique_one(K-T, S0, S) :-
    signature(T, Sig),
    (   get_assoc(Sig, S0, _)
    ->  distinct_text(K, T, 1, S0, T2, Sig2),
        retract(tmpl(K, F, T, A)), assertz(tmpl(K, F, T2, A))
    ;   Sig2 = Sig
    ),
    put_assoc(Sig2, S0, x, S).

distinct_text(K, T, N, S0, T2, Sig) :-
    qualifier(K, N, Q),
    with_qualifier(T, Q, T1),
    signature(T1, Sig1),
    (   get_assoc(Sig1, S0, _), N < 5 -> N1 is N + 1, distinct_text(K, T, N1, S0, T2, Sig)
    ;   T2 = T1, Sig = Sig1
    ).

qualifier(alias(Q, _, _), 1, W) :- !, short(Q, S), name_words(S, FW), format(atom(W), 'in ~w', [FW]).
qualifier(K, N, W) :- key_q(K, Q), !, ns_tag(Q, Tag),
    ( N == 1 -> format(atom(W), 'in ~w', [Tag]) ; short(Q, S), name_words(S, FW), format(atom(W), 'in ~w ~w ~w', [Tag, FW, N]) ).
qualifier(attr(A), N, W) :- !, format(atom(W), 'as ~w ~w', [A, N]).
qualifier(_, N, W) :- format(atom(W), 'number ~w', [N]).

key_q(func(Q), Q).
key_q(rule(Q), Q).
key_q(alias(Q, _, _), Q).

%   The qualifier goes before the first place: a place takes in the words
%   that follow it up to the template's next word, so `the effective date of
%   *x* for y is *v*` would also read `the effective date of an x for y is a
%   v` as the attribute's own template, with `x for y` as its place. Before
%   the first place the words must match one for one. A template that opens
%   with a place gets the qualifier at its end.
with_qualifier(T, Q, T1) :-
    (   sub_atom(T, B, _, _, ' *'), B > 0
    ->  sub_atom(T, 0, B, _, Pre0), sub_atom(T, B, _, 0, Post0),
        (   member(P, [' of', ' for', ' with']), atom_concat(Pre, P, Pre0)
        ->  atom_concat(P, Post0, Post)
        ;   Pre = Pre0, Post = Post0
        ),
        format(atom(T1), '~w ~w~w', [Pre, Q, Post])
    ;   format(atom(T1), '~w ~w', [T, Q])
    ).

%   The signature by which LE tells two templates apart: the words before
%   the first place (or, for a template that opens with a place, the words
%   that follow it), without the words LE ignores.
signature(T, Sig) :-
    atom_codes(T, Cs), phrase(lead_words(Ws0, Mode), Cs),
    exclude([W]>>memberchk(W, [a, an, the, is, are, was, were, has, have, had, do, does, did, been]), Ws0, Ws),
    atomic_list_concat(Ws, ' ', Sig0),
    ( Mode == after_place -> atom_concat('_ ', Sig0, Sig) ; Sig = Sig0 ).

lead_words(Ws, after_place) --> blanks_, "*", !, skip_place, words_to_place(Ws).
lead_words(Ws, lead) --> words_to_place(Ws).
words_to_place([]) --> "*", !, rest_ignored.
words_to_place([W|Ws]) --> sig_word(Cs), { Cs \== [], atom_codes(W0, Cs), downcase_atom(W0, W) }, !, words_to_place(Ws).
words_to_place(Ws) --> [_], !, words_to_place(Ws).
words_to_place([]) --> [].
rest_ignored --> [_], !, rest_ignored.
rest_ignored --> [].
blanks_ --> [C], { code_type(C, space) }, !, blanks_.
blanks_ --> [].
skip_place --> "*", !.
skip_place --> [_], skip_place.
sig_word([C|Cs]) --> [C], { C \== 0'*, \+ code_type(C, space) }, sig_word_rest(Cs).
sig_word_rest([C|Cs]) --> [C], { C \== 0'*, \+ code_type(C, space) }, !, sig_word_rest(Cs).
sig_word_rest([]) --> [].

% ---------------------------------------------------------------- the library

%   lib/rune.le (included by every twin): the operations on lists and the
%   functions DRR implements in Java.
lib_templates(Ts) :-
    findall(template(F, T, [included]), lib_template(F, T), Ts).

lib_template(rune_only_element, "the only element of *a list* is *a value*").
lib_template(rune_first, "the first element of *a list* is *a value*").
lib_template(rune_last, "the last element of *a list* is *a value*").
lib_template(rune_min, "the least of *a list* is *a value*").
lib_template(rune_max, "the greatest of *a list* is *a value*").
lib_template(rune_distinct, "the distinct values of *a list* are *a second list*").
lib_template(rune_reverse, "the reverse of *a list* is *a second list*").
lib_template(rune_sorted, "the sorted values of *a list* are *a second list*").
lib_template(rune_concat, "the concatenation of *a text* and *a second text* is *a third text*").
lib_template(rune_to_string, "the text of *a value* is *a text*").
lib_template(rune_to_number, "the number of *a value* is *a number*").
lib_template(rune_contains_all, "*a list* contains every element of *a second list*").
lib_template(rune_disjoint, "*a list* shares no element with *a second list*").
lib_template(rune_earlier, "*a value* comes before *a second value*").
lib_template(rune_join, "the joining of *a list* with *a separator* is *a text*").
lib_template(rune_now, "the time of the report is *a time*").
lib_template(rune_or_nothing, "the value or nothing of *a list* is *a value*").
lib_template(rune_min_by, "the element of *a list* with the least of the keys *a second list* is *a value*").
lib_template(rune_max_by, "the element of *a list* with the greatest of the keys *a second list* is *a value*").
lib_template(rune_sorted_by, "the elements of *a list* sorted by the keys *a second list* are *a third list*").
lib_template(rune_object_0, "the object built at *a site* is *a value*").
lib_template(rune_object_1, "the object built at *a site* with *an input* is *a value*").
lib_template(rune_object_2, "the object built at *a site* with *an input* with *a second input* is *a value*").
lib_template(rune_object_3, "the object built at *a site* with *an input* with *a second input* with *a third input* is *a value*").
lib_template(rune_object_4, "the object built at *a site* with *an input* with *a second input* with *a third input* with *a fourth input* is *a value*").
lib_template(rune_object_5, "the object built at *a site* with *an input* with *a second input* with *a third input* with *a fourth input* with *a fifth input* is *a value*").
lib_template(rune_object_6, "the object built at *a site* with *an input* with *a second input* with *a third input* with *a fourth input* with *a fifth input* with *a sixth input* is *a value*").
lib_template(rune_object_7, "the object built at *a site* with *an input* with *a second input* with *a third input* with *a fourth input* with *a fifth input* with *a sixth input* with *a seventh input* is *a value*").
lib_template(rune_object_8, "the object built at *a site* with *an input* with *a second input* with *a third input* with *a fourth input* with *a fifth input* with *a sixth input* with *a seventh input* with *an eighth input* is *a value*").
lib_template(rune_string_contains, "*a text* contains the text *a second text*").
lib_template(rune_day_of_week, "the day of the week of *a date* is *a day*").
lib_template(rune_add_days, "the date *a date* plus *a number* days is *a second date*").
lib_template(rune_date_part, "the date part of *a time* is *a date*").
lib_template(rune_time_part, "the time part of *a time* is *a time of day*").
lib_template(rune_timezone_part, "the time zone part of *a time* is *a zone*").
lib_template(rune_year_part, "the year part of *a date* is *a year*").
lib_template(rune_month_part, "the month part of *a date* is *a month*").
lib_template(rune_day_part, "the day part of *a date* is *a day*").
lib_template(rune_date_difference, "the days from *a date* to *a second date* are *a number*").
lib_template(rune_leap_days, "the leap days from *a date* to *a second date* are *a number*").
lib_template(rune_round_to_precision, "the number *a number* rounded to *a precision* decimal places towards *a direction* is *a value*").
lib_template(rune_round_to_significant, "the number *a number* rounded to *a count* significant figures towards *a direction* is *a value*").

%   The functions DRR implements in Java: the library's template, and how
%   a call maps onto it.
lib_function('cdm.base.datetime.Now', rune_now, []).
lib_function('drr.base.util.string.StringContains', rune_string_contains, [1, 2]).
lib_function('cdm.base.math.RoundToPrecision', rune_round_to_precision, [1, 2, 3]).
lib_function('cdm.base.datetime.AddDays', rune_add_days, [1, 2]).
lib_function('cdm.base.datetime.DayOfWeek', rune_day_of_week, [1]).
lib_function('cdm.base.datetime.DateDifference', rune_date_difference, [1, 2]).
lib_function('cdm.base.datetime.LeapYearDateDifference', rune_leap_days, [1, 2]).
lib_function('cdm.base.math.RoundToSignificantFigures', rune_round_to_significant, [1, 2, 3]).

%   java_reading(+Function, -Clauses): a function DRR implements in Java
%   whose Java only reads the data, written as rules over the twin's own
%   templates (DRR's GetQuantityReferenceImpl and GetQuantityKeysImpl).
java_reading('drr.base.trade.GetQuantityReference', [rule(H, G)]) :-
    %  the location the quantity schedule's address points at
    tmpl(func('drr.base.trade.GetQuantityReference'), F, _, _),
    tmpl(attr(quantitySchedule), QS, _, _), tmpl(attr(location), LO, _, _),
    H =.. [F, P, V],
    G1 =.. [QS, P, S], G2 =.. [LO, S, V],
    G = and(P \= nothing, and(G1, G2)).
java_reading('drr.standards.iso.API_GetMicData', [rule(H, G)]) :-
    %  the venue's record in ISO 10383 (API_GetMicDataImpl)
    tmpl(func('drr.standards.iso.API_GetMicData'), F, _, _),
    tmpl(reference(mic), RF, _, _),
    H =.. [F, M, V], G1 =.. [RF, V, M],
    G = and(M \= nothing, G1).
java_reading('drr.base.trade.GetQuantityKeys', [rule(H, G)]) :-
    %  the locations of the quantities, each a key
    tmpl(func('drr.base.trade.GetQuantityKeys'), F, _, _),
    tmpl(attr(quantity), QU, _, _), tmpl(attr(location), LO, _, _),
    H =.. [F, P, V],
    G1 =.. [QU, P, S], G2 =.. [LO, S, V],
    G = and(P \= nothing, and(G1, G2)).

% ---------------------------------------------------------------- definitions

%   define(+What, -def(What, Clauses, Problems)): the clauses of a rule or
%   a function; each clause rule(Head, Body); Problems the alternatives (or
%   the whole) that could not be written.
define(rule(Q), def(rule(Q), Clauses, Problems)) :-
    rune_model:rune_rule(Kind, Q, _, _, _, _),
    tmpl(rule(Q), F, _, _),
    (   rule_typed(Q, T, _)
    ->  X = _, Env = cenv([], b(single, X)),
        (   Kind == eligibility
        ->  Head =.. [F, X], alternatives(T, Env, _, Head, Alts)
        ;   Head =.. [F, X, V], alternatives(T, Env, V, Head, Alts)
        ),
        alts_clauses(Alts, Clauses, Problems)
    ;   Clauses = [], Problems = [untyped]
    ).
define(func(Q), def(func(Q), [], [])) :- lib_function(Q, _, _), !.
define(func(Q), def(func(Q), Clauses, [])) :- java_reading(Q, Clauses), !.
define(func(Q), def(func(Q), Clauses, Problems)) :-
    rune_model:rune_func(Q, Ins, Out, Steps, _, _, _),
    tmpl(func(Q), F, _, _),
    maplist(input_var, Ins, Bindings, Args),
    Env = cenv(['$func'-f(Q, Args)|Bindings], none),
    (   rune_model:rune_func(Q, _, _, _, _, Ann, _), get_dict(codeImplementation, Ann, _)
    ->  Clauses = [], Problems = [code_implementation]
    ;   Out == none -> Clauses = [], Problems = [no_output]
    ;   Out = out(ON, _, _),
        include(output_step(ON), Steps, OSteps),
        (   OSteps == [] -> Clauses = [], Problems = [no_step]
        ;   member(S, OSteps), \+ S =.. [_, [ON], _] -> Clauses = [], Problems = [builds_object]
        ;   effective_steps(OSteps, ESteps),
            (   boolean_output(Out)
            ->  Head =.. [F|Args],
                findall(A, ( member(St, ESteps), arg(2, St, W), func_step_typed(Q, W, T, _),
                             cond_alternatives(T, Env, Head, As), member(A, As) ), Alts)
            ;   append(Args, [V], HArgs), Head =.. [F|HArgs],
                findall(A, ( member(St, ESteps), arg(2, St, W), func_step_typed(Q, W, T, _),
                             alternatives(T, Env, V, Head, As), member(A, As) ), Alts)
            ),
            alts_clauses(Alts, Clauses, Problems)
        )
    ).

output_step(ON, S) :- S =.. [K, [ON|_], _], memberchk(K, [set, add]).

%   An input of one value or none (0..1) is `nothing` when it has none: the
%   function is still called, as in Rune.
%   (DRR calls a function whose input should have one value with none too:
%   PartyIdentifierFormat of no party is "Lei". Such an input is `nothing`.)
input_var(in(N, _, card(_, Max)), N-B, X) :-
    (   Max == 1 -> B = b(opt, X)
    ;   B = b(list, X)
    ).

%   The steps that make the output: a later `set` replaces the earlier
%   ones; each `add` after it adds.
effective_steps(Steps, Eff) :-
    (   append(_, [S|After], Steps), functor(S, set, _), \+ ( member(S2, After), functor(S2, set, _) )
    ->  Eff = [S|After]
    ;   Eff = Steps
    ).

%   alts_clauses(+Alts, -Clauses, -Problems): each alternative is
%   ok(Head-Goal) or problem(Why).
alts_clauses(Alts, Clauses, Problems) :-
    findall(rule(H, G), ( member(ok(H-G0), Alts), simp(G0, G) ), Clauses0),
    exclude(failing_clause, Clauses0, Clauses),
    findall(W, member(problem(W), Alts), Problems).

failing_clause(rule(_, G)) :- G == fail.

%   simp(+G0, -G): the goal without `true` and `fail` where they decide
%   nothing, and the comparisons of constants worked out.
simp(G, G) :- var(G), !.
simp(and(A0, B0), G) :- !, simp(A0, A), simp(B0, B),
    (   ( A == fail ; B == fail ) -> G = fail
    ;   conj(A, B, G) ).
simp(or(A0, B0), G) :- !, simp(A0, A), simp(B0, B),
    (   A == fail -> G = B
    ;   B == fail -> G = A
    ;   ( A == true ; B == true ) -> G = true
    ;   G = or(A, B) ).
simp(not(A0), G) :- !, simp(A0, A),
    (   A == true -> G = fail ; A == fail -> G = true
    ;   nonvar(A), A = not(not(B)) -> G = not(B)
    ;   G = not(A) ).
simp(X = Y, G) :- ground(X), ground(Y), !, ( X == Y -> G = true ; G = fail ).
simp(X \= Y, G) :- ground(X), ground(Y), !, ( X \== Y -> G = true ; G = fail ).
simp(agg(Op, E, G0, R), G) :- !, simp(G0, G1),
    (   G1 == fail -> ( Op == list -> G = (R = []) ; Op == count -> G = (R = 0) ; Op == sum -> G = (R = 0) ; G = fail )
    ;   G1 == true -> G = agg(Op, E, (E = E), R)
    ;   G = agg(Op, E, G1, R) ).
simp(forall(C0, A0), G) :- !, simp(C0, C), simp(A0, A),
    (   C == fail -> G = true ; A == true -> G = true ; G = forall(C, A) ).
simp(G, G).

% ---------------------------------------------------------------- alternatives

%   alternatives(+T, +Env, ?V, -Alts): the top of a definition as separate
%   alternatives (one LE rule each): Alts = [ok(Head-Goal) | problem(Why)].
%   The head is filled in by alts_clauses/4 through the shared variables.
alternatives(T, Env, V, Head, Alts) :-
    findall(A, alternative(T, Env, V, Head, A), Alts).

alternative(T, Env, V, Head, A) :-
    split(T, Env, V, Branch),
    (   Branch = goal(G) -> A = ok(Head-G)
    ;   Branch = problem(W) -> A = problem(W)
    ).

%   split(+T, +Env, ?V, -Branch): nondeterministically, each top-level
%   branch: goal(G) or problem(Why).
split(paren(T), Env, V, B) :- !, split(T, Env, V, B).
split(if(C, T), Env, V, B) :- !,
    guard(C, Env, GC),
    split(T, Env, V, B0), prefix(GC, B0, B).
split(if(C, T, E), Env, V, B) :- !,
    guard(C, Env, GC),
    (   split(T, Env, V, B0), prefix(GC, B0, B)
    ;   negate(GC, NGC), split(E, Env, V, B0), prefix(NGC, B0, B)
    ).
split(default(L, R), Env, V, B) :- !,
    (   attempt(cs(L, Env, V), B)
    ;   attempt(cs(L, Env, _), GL0), negate(GL0, NGL), split(R, Env, V, B0), prefix(NGL, B0, B)
    ).
split(then(A, F), Env, V, B) :- F \== none, !,
    (   attempt(item_binding(A, F, Env), BI)
    ->  ( BI = goal(GA-Item) -> fn_env(Env, Item, Env2), fn_body(F, FB),
          split(FB, Env2, V, B0), prefix(goal(GA), B0, B)
        ; B = BI )
    ;   B = problem(internal)
    ).
split(extract(A, F), Env, V, B) :- single_receiver(A, Env), !,
    (   attempt(cs(A, Env, X), BA)
    ->  ( BA = goal(GA) -> fn_env(Env, F, b(single, X), Env2), fn_body(F, FB),
          split(FB, Env2, V, B0), prefix(goal(GA), B0, B)
        ; B = BA )
    ;   B = problem(internal)
    ).
split(T, Env, V, B) :- attempt(cs(T, Env, V), B).

%   The alternatives of a test: the cases in which it holds.
cond_alternatives(T, Env, Head, Alts) :-
    findall(A, ( split_cond(T, Env, B), ( B = goal(G) -> A = ok(Head-G) ; B = problem(W), A = problem(W) ) ), Alts).

split_cond(paren(T), Env, B) :- !, split_cond(T, Env, B).
split_cond(or(L, R), Env, B) :- !, ( split_cond(L, Env, B) ; split_cond(R, Env, B) ).
split_cond(if(C, T, E), Env, B) :- !,
    guard(C, Env, GC),
    (   split_cond(T, Env, B0), prefix(GC, B0, B)
    ;   negate(GC, NGC), split_cond(E, Env, B0), prefix(NGC, B0, B)
    ).
split_cond(if(C, T), Env, B) :- !, guard(C, Env, GC), split_cond(T, Env, B0), prefix(GC, B0, B).
split_cond(bool(false), _, _) :- !, fail.
split_cond(bool(true), _, goal(true)) :- !.
split_cond(T, Env, B) :- attempt(cc(T, Env), B).

%   A guard is a test: it holds or not, once. A test that can hold in
%   several ways (a path with several values, a call, an `or`) is written
%   `it is not the case that it is not the case that ...`, which gives one
%   answer: otherwise the rule would give its value once for each way.
guard(C, Env, G) :- attempt(test(C, Env), G).

test(C, Env, G) :-
    cc(C, Env, G0),
    (   deterministic(C, Env) -> G = G0 ; G = not(not(G0)) ).

deterministic(paren(T), Env) :- !, deterministic(T, Env).
deterministic(and(L, R), Env) :- !, deterministic(L, Env), deterministic(R, Env).
deterministic(absent(_), _) :- !.
deterministic(bool(_), _) :- !.
deterministic(exists(none, A), Env) :- !, simple_path(A, Env).
deterministic(eq(=, M, L, R, _, _), Env) :- !, M \== any, simple_path(L, Env), simple_path(R, Env).
deterministic(eq(<>, _, _, _, _, _), _) :- !.
deterministic(cmp(_, _, L, R, _, _), Env) :- !, simple_path(L, Env), simple_path(R, Env).
%   A yes-or-no function or rule on values of one: its template is
%   memorable, and a memorable call's answers are a set (LE2's reasoner), so
%   it holds once or not at all.
deterministic(call(K, Q, Args), Env) :- !,
    ( K == func -> boolean_func(Q) ; K == rule ),
    maplist(simple_arg(Env), Args).
deterministic(call(K, Q), Env) :- !, deterministic(call(K, Q, []), Env).

simple_arg(Env, A) :- ( A == empty -> true ; simple_path(A, Env) ).

%   A path of single values from a variable, or a constant.
simple_path(T, _) :- memberchk(T, [item]), !.
simple_path(paren(T), Env) :- !, simple_path(T, Env).
simple_path(str(_), _) :- !.
simple_path(num(_), _) :- !.
simple_path(bool(_), _) :- !.
simple_path(enum(_, _), _) :- !.
simple_path(var(N), cenv(Vs, _)) :- !, ( memberchk(N-b(single, _), Vs) ; memberchk(N-b(opt, _), Vs) ), !.
simple_path(item, cenv(_, b(single, _))) :- !.
simple_path(attr(R, Owner, A, _), Env) :- !,
    simple_path(R, Env), type_feature(Owner, A, feature(_, card(_, 1), _)).
simple_path(meta(R, _, _, _), Env) :- simple_path(R, Env).

attempt(Goal, B) :-
    catch(( call(Goal, G0) -> B = goal(G0) ; B = problem(internal) ),
          rune_residue(Why), B = problem(Why)).

prefix(goal(G), goal(H), goal(GH)) :- !, conj(G, H, GH).
prefix(problem(W), _, problem(W)) :- !.
prefix(_, problem(W), problem(W)).

negate(goal(G), goal(not(G))) :- !.
negate(P, P).

single_receiver(A, Env) :- receiver_single(A, Env).

%   conj(+A, +B, -C): A and B as one conjunction, left-associated (how LE
%   reads sibling lines: le_writer's IR wants and(and(A, B), C)).
conj(A, B, C) :-
    and_list(A, LA), and_list(B, LB), append(LA, LB, L),
    (   L == [] -> C = true
    ;   L = [G|Gs], foldl([X, A0, and(A0, X)]>>true, Gs, G, C)
    ).

and_list(true, []) :- !.
and_list(and(A, B), L) :- !, and_list(A, LA), and_list(B, LB), append(LA, LB, L).
and_list(G, [G]).

conjs([], true).
conjs([G|Gs], C) :- foldl([X, A0, A]>>conj(A0, X, A), Gs, G, C).

residue(Why) :- throw(rune_residue(Why)).

fn_body(implicit(B), B).
fn_body(fn(_, B), B).

fn_env(cenv(Vs, _), Item, cenv(Vs, Item)).

%   An inline function with a named parameter: the parameter is the element.
fn_env(cenv(Vs, I), fn([P], _), Item, cenv([P-Item|Vs], I)) :- !.
fn_env(Env, _, Item, Env2) :- fn_env(Env, Item, Env2).

% ---------------------------------------------------------------- streams

%   cs(+T, +Env, ?V, -Goal): Goal gives V once for each element of the
%   value of T, in order.
cs(T, Env, V, G) :- cs_(T, Env, V, G), !.
cs(T, _, _, _) :- functor(T, F, N), residue(F/N).

cs_(paren(T), Env, V, G) :- cs(T, Env, V, G).
cs_(str(S), _, S, true).
cs_(num(N), _, X, true) :- atom_number(N, X0), normal_number(X0, X).
cs_(bool(B), _, S, true) :- atom_string(B, S).
cs_(empty, _, _, fail).
cs_(enum(E, Val), _, J, true) :- ( enum_value_json(E, Val, J0) -> atom_string(J0, J) ; atom_string(Val, J) ).
cs_(item, cenv(_, Item), V, G) :- item_stream(Item, V, G).
cs_(var(N), cenv(Vs, _), V, G) :- memberchk(N-B, Vs), item_stream(B, V, G).
cs_(alias(N, T), Env, V, G) :- alias_call(N, T, Env, value, V, G).
cs_(attr(R, _, A, _), Env, V, G) :-
    tmpl(attr(A), F, _, _),
    owner(R, Env, O, GR),
    L =.. [F, O, V], conj(GR, L, G).
cs_(basic_feature(R, F), Env, V, G) :- !,             % a timestamp's date: the library's
    cs(R, Env, X, GR), basic_part(F, P), L =.. [P, X, V], conj(GR, L, G).
cs_(meta(R, _, A, _), Env, V, G) :-
    tmpl(meta(A), F, _, _),
    cs(R, Env, O, GR),
    L =.. [F, O, V], conj(GR, L, G).
cs_(list(Es), Env, V, le_is_in(V, Cs)) :-
    %  a long list of constants (DRR's lists of names): one membership,
    %  not an `or` as deep as the list, which LE's parser holds level by level
    length(Es, N),
    ( N >= 20 -> true ; N >= 2, forall(member(E, Es), E = op('to-string', _)) ),   % (a list of names)
    maplist(constant_elem(Env), Es, Cs), !.
cs_(list(Es), Env, V, G) :-
    maplist(elem_goal(Env, V), Es, Gs),
    ( Gs = [G1|Rest] -> foldl([X, A0, or(A0, X)]>>true, Rest, G1, G) ; G = fail ).
cs_(if(C, T), Env, V, G) :- test(C, Env, GC), cs(T, Env, V, GT), conj(GC, GT, G).
cs_(if(C, T, E), Env, V, or(GA, and(not(GC), GE))) :-
    test(C, Env, GC), cs_into(T, Env, V, GT), conj(GC, GT, GA), cs_into(E, Env, V, GE).
cs_(default(L, R), Env, V, or(GL, and(not(GL2), GR))) :-
    cs_into(L, Env, V, GL), cs(L, Env, _, GL2), cs_into(R, Env, V, GR).
cs_(deep(R, _, Alts), Env, V, G) :-
    cs(R, Env, O, GR),
    maplist(deep_alt(O, V), Alts, Gs),
    ( Gs = [G1|Rest] -> foldl([X, A0, or(A0, X)]>>true, Rest, G1, GO) ; GO = fail ),
    conj(GR, GO, G).
%   A constructor (`PayoutLeg { interestRatePayout: ..., ... }`): the object
%   is made from the place it is built at and the values it is built from;
%   its attributes are rules of their own (cons_definition/1).
cs_(cons(T, _, _), _, _, _) :- \+ value_type(T, object(_)), !, residue(cons_of(T)).
cs_(cons(T, Pairs, _), Env, V, G) :-
    env_inputs(Env, Inputs),
    nb_getval(rune_cons_counter, N0), N is N0 + 1, nb_setval(rune_cons_counter, N),
    short(T, S), format(atom(Site), '~w ~w', [S, N]),
    copy_term(Env-Inputs, EnvC-InputsC),
    assertz(cons_site(Site, T, Pairs, EnvC, InputsC)),
    ( nb_current(rune_def, Q), Q \== none -> assertz(cons_owner(Site, Q)) ; true ),
    object_goal(Site, Inputs, V, G).
%   `x as T`: the option T of a choice (Payout's OptionPayout), else x.
cs_(as(A, T), Env, V, G) :-
    cs(A, Env, O, GA),
    short(T, S),
    (   tmpl(attr(S), F, _, _) -> L =.. [F, O, V], conj(GA, L, G)
    ;   V = O, G = GA
    ).
cs_(switch(A, Cases), Env, V, G) :-
    cs(A, Env, X, GA),
    switch_goal(Cases, X, Env, V, GS),
    conj(GA, GS, G).
cs_(filter(A, F), Env, V, G) :-
    cs(A, Env, V, GA), fn_env(Env, F, b(single, V), Env2), fn_body(F, FB),
    test(FB, Env2, GF), conj(GA, GF, G).
cs_(extract(A, F), Env, V, G) :-
    cs(A, Env, X, GA), fn_env(Env, F, b(single, X), Env2), fn_body(F, FB),
    cs(FB, Env2, V, GF), conj(GA, GF, G).
cs_(then(A, none), Env, V, G) :- cs(A, Env, V, G).
cs_(then(A, F), Env, V, G) :-
    item_binding(A, F, Env, GA-Item), fn_env(Env, Item, Env2), fn_body(F, FB),
    cs(FB, Env2, V, GF), conj(GA, GF, G).
cs_(op(flatten, A), Env, V, G) :- cs(A, Env, V, G).
cs_(op('only-element', A), Env, V, G) :- list_op(A, Env, rune_only_element, V, G).
cs_(op(first, A), Env, V, G) :- list_op(A, Env, rune_first, V, G).
cs_(op(last, A), Env, V, G) :- list_op(A, Env, rune_last, V, G).
cs_(op(distinct, A), Env, V, G) :-
    cl(A, Env, L, GL), Lit = rune_distinct(L, D), conj(GL, Lit, G0), conj(G0, member(V, D), G).
cs_(op(reverse, A), Env, V, G) :-
    cl(A, Env, L, GL), Lit = rune_reverse(L, D), conj(GL, Lit, G0), conj(G0, member(V, D), G).
cs_(op(count, A), Env, N, G) :- cs(A, Env, X, GA), G = agg(count, X, GA, N).
cs_(op(sum, A), Env, N, G) :- cs(A, Env, X, GA), G = agg(sum, X, GA, N).
cs_(max(A, none), Env, N, G) :- list_op(A, Env, rune_max, N, G).
cs_(min(A, none), Env, N, G) :- list_op(A, Env, rune_min, N, G).
cs_(max(A, F), Env, V, G) :- F \== none, by_key(A, F, Env, rune_max_by, V, G).
cs_(min(A, F), Env, V, G) :- F \== none, by_key(A, F, Env, rune_min_by, V, G).
cs_(sort(A, F), Env, V, G) :- F \== none, by_key(A, F, Env, rune_sorted_by, D, G0), conj(G0, member(V, D), G).
cs_(sort(A, none), Env, V, G) :-
    cl(A, Env, L, GL), conj(GL, rune_sorted(L, D), G0), conj(G0, member(V, D), G).
cs_(op('to-string', A), Env, V, G) :- cs(A, Env, X, GA), conj(GA, rune_to_string(X, V), G).
cs_(op('to-number', A), Env, V, G) :- cs(A, Env, X, GA), conj(GA, rune_to_number(X, V), G).
cs_(op('to-int', A), Env, V, G) :- cs(A, Env, X, GA), conj(GA, rune_to_number(X, V), G).
cs_(to_enum(A, E), Env, V, G) :-
    cs(A, Env, V, GA),
    findall(S, ( enum_value_json(E, _, J), atom_string(J, S) ), Ss),
    conj(GA, member(V, Ss), G).
cs_(arith(Op, L, R, K), Env, V, G) :-
    cs(L, Env, X, GL), cs(R, Env, Y, GR), conj(GL, GR, G0),
    (   K == basic(string), Op == (+)
    ->  conj(G0, rune_concat(X, Y, V), G)
    ;   memberchk(Op, [+, -, *, /]), E =.. [Op, X, Y], conj(G0, V is E, G)
    ).
cs_(call(func, Q, Args), Env, V, G) :-
    \+ boolean_func(Q),
    call_goal(Q, Args, Env, [V], G).
cs_(call(func, Q, Args), Env, V, G) :-
    boolean_func(Q),
    call_goal(Q, Args, Env, [], GC0), GC = not(not(GC0)),
    G = or(and(GC, V = "true"), and(not(GC), V = "false")).
cs_(call(rule, Q, [A]), Env, V, G) :-
    rune_model:rune_rule(reporting, Q, _, _, _, _),
    tmpl(rule(Q), F, _, _),
    cs(A, Env, X, GA), L =.. [F, X, V], conj(GA, L, G).
cs_(T, Env, V, G) :- condition_like(T), test(T, Env, GC),
    G = or(and(GC, V = "true"), and(not(GC), V = "false")).

elem_goal(Env, V, E, G) :- cs_into(E, Env, V, G).

%   An element whose value is known when the twin is written: a text, a
%   number, an enumeration's value, or the text of one.
%   Not one (an attribute path, `floatingRateIndexes only-element`): it fails,
%   and the list is translated element by element; cs/4 on such an element
%   leaves a residue, which must not stand for the whole list.
constant_elem(Env, op('to-string', A), C) :- !, constant_stream(A, Env, C0), string(C0), C = C0.
constant_elem(Env, E, C) :- constant_stream(E, Env, C), ground(C), ( string(C) ; number(C) ).

constant_stream(T, Env, C) :-
    catch(once(cs(T, Env, C, G)), rune_residue(_), fail),
    G == true.

%   The owner of an attribute: `nothing` has no attributes, so an input
%   that may be nothing needs no test of its own there.
owner(var(N), cenv(Vs, _), O, true) :- memberchk(N-b(opt, O), Vs), !.
owner(item, cenv(_, b(opt, O)), O, true) :- !.
owner(R, Env, O, G) :- cs(R, Env, O, G).

%   The values a constructor is built from: its definition's inputs and the
%   implicit item, the variables of the environment.
env_inputs(cenv(Vs, Item), Inputs) :-
    binding_vars(Vs, Xs0),          % (not findall/3: it would copy them)
    ( Item = b(_, IX) -> Xs1 = [IX|Xs0] ; Xs1 = Xs0 ),
    ( memberchk('$func'-f(_, Args), Vs) -> append(Xs1, Args, Xs2) ; Xs2 = Xs1 ),
    term_variables(Xs2, Inputs0),
    list_to_set(Inputs0, Inputs1),
    length(Inputs1, N), ( N =< 8 -> Inputs = Inputs1 ; length(Inputs, 8), append(Inputs, _, Inputs1) ).

binding_vars([], []).
binding_vars([_-b(_, X)|Vs], [X|Xs]) :- !, binding_vars(Vs, Xs).
binding_vars([_|Vs], Xs) :- binding_vars(Vs, Xs).

object_goal(Site, Inputs, V, G) :-
    length(Inputs, N), format(atom(F), 'rune_object_~w', [N]),
    atom_string(Site, SS), append([SS|Inputs], [V], Args), G =.. [F|Args].

%   The rules of the attributes of the objects the definitions build, and
%   of the objects those build in turn.
cons_definitions(Defs) :- cons_definitions([], Defs).
cons_definitions(Done, Defs) :-
    (   cons_site(Site, _, _, _, _), \+ memberchk(Site, Done)
    ->  cons_definition(Site, D), cons_definitions([Site|Done], Ds), Defs = [D|Ds]
    ;   Defs = []
    ).

cons_definition(Site, def(cons(Site, T), Clauses, Problems)) :-
    cons_site(Site, T, Pairs, Env, Inputs),
    ( cons_owner(Site, Q) -> nb_setval(rune_def, Q) ; true ),   % (the objects it builds in turn are its owner's)
    findall(A, ( member(K-VT, Pairs), cons_attr_alternatives(Site, K, VT, Env, Inputs, As), member(A, As) ), Alts),
    alts_clauses(Alts, Clauses, Problems).

cons_attr_alternatives(Site, K, VT, Env, Inputs, Alts) :-
    (   tmpl(attr(K), F, _, _)
    ->  object_goal(Site, Inputs, O, OG),
        Head =.. [F, O, V],
        findall(A, ( split(VT, Env, V, B),
                     ( B = goal(G0) -> conj(OG, G0, G), A = ok(Head-G) ; B = problem(W), A = problem(W) ) ), Alts)
    ;   Alts = [problem(no_template(K))]
    ).

%   cs_into(+T, +Env, ?V, -G): T's values into V, a variable other
%   alternatives give a value too (a constant is then a condition).
cs_into(T, Env, V, G) :-
    cs(T, Env, X, G0),
    (   var(X), \+ occurs_in(X, Env) -> X = V, G = G0
    ;   conj(G0, V = X, G)
    ).
occurs_in(X, Env) :- term_variables(Env, Vs), member(Y, Vs), Y == X, !.

%   Rune's ->> : the attribute of whichever option of a choice holds it.
deep_alt(O, V, path(Steps), G) :- deep_steps(Steps, O, V, G).
deep_steps([_-A], O, V, L) :- !, tmpl(attr(A), F, _, _), L =.. [F, O, V].
deep_steps([_-A|As], O, V, and(L, G)) :- tmpl(attr(A), F, _, _), L =.. [F, O, X], deep_steps(As, X, V, G).

%   A switch on values: the first case whose guard is the value.
switch_goal([], _, _, _, fail).
switch_goal([default(E)], _, Env, V, G) :- !, cs_into(E, Env, V, G).
switch_goal([case(Guard, E)|Cs], X, Env, V, or(and(X = GV, GE), and(X \= GV, GR))) :-
    switch_value(Guard, GV), cs_into(E, Env, V, GE), switch_goal(Cs, X, Env, V, GR).
switch_value(str(S), S).
switch_value(num(N), X) :- atom_number(N, X).
switch_value(enum(E, Val), J) :- ( enum_value_json(E, Val, J0) -> atom_string(J0, J) ; atom_string(Val, J) ).

normal_number(X0, X) :- ( float(X0), X0 =:= truncate(X0), abs(X0) < 1.0e15 -> X is truncate(X0) ; X = X0 ).

%   min [key], max [key], sort [key]: the elements, and the list of their
%   keys in the same order (nothing for an element without one).
by_key(A, F, Env, Op, V, G) :-
    cl(A, Env, L, GL),
    cs(A, Env, E, GA),
    fn_env(Env, F, b(single, E), Env2), fn_body(F, FB),
    cl(FB, Env2, KL1, GK),
    conj(GA, GK, G1), conj(G1, rune_or_nothing(KL1, K), GE),
    conj(GL, agg(list, K, GE, KL), G0),
    Lit =.. [Op, L, KL, V],
    conj(G0, Lit, G).

list_op(A, Env, Op, V, G) :-
    cl(A, Env, L, GL), Lit =.. [Op, L, V], conj(GL, Lit, G).

%   cl(+T, +Env, -List, -Goal): the whole value of T, as a list.
cl(item, cenv(_, b(list, L)), L, true) :- !.
cl(var(N), cenv(Vs, _), L, true) :- memberchk(N-b(list, L), Vs), !.
cl(paren(T), Env, L, G) :- !, cl(T, Env, L, G).
cl(empty, _, [], true) :- !.
cl(op(distinct, A), Env, D, G) :- !, cl(A, Env, L, GL), conj(GL, rune_distinct(L, D), G).
cl(op(reverse, A), Env, D, G) :- !, cl(A, Env, L, GL), conj(GL, rune_reverse(L, D), G).
cl(sort(A, none), Env, D, G) :- !, cl(A, Env, L, GL), conj(GL, rune_sorted(L, D), G).
cl(T, Env, L, G) :-
    cs(T, Env, V, GV),
    (   atomic(V), GV == true -> L = [V], G = true          % a constant: the list of it
    ;   atomic(V) -> conj(GV, X = V, GX), G = agg(list, X, GX, L)   % (an element named: LE collects variables)
    ;   G = agg(list, V, GV, L)
    ).

item_stream(b(single, X), X, true).
item_stream(b(opt, X), X, X \= nothing).
item_stream(b(list, L), V, member(V, L)).

%   The implicit item of `A then F`: A's one value, or the list of them.
%   A step that sees an empty value (`then default ...`, `then count`, `then
%   if item exists ...`) gets the list, empty or not.
item_binding(A, Env, G-Item) :- item_binding(A, none, Env, G-Item).
item_binding(A, F, Env, G-Item) :-
    (   receiver_single(A, Env), strict_fn(F) -> cs(A, Env, X, G), Item = b(single, X)
    ;   cl(A, Env, L, G), Item = b(list, L)
    ).

strict_fn(none).
strict_fn(implicit(B)) :- strict(B).
strict_fn(fn(_, B)) :- strict(B).

%   Whether an expression of the item is empty when the item is.
strict(item).
strict(paren(T)) :- strict(T).
strict(attr(R, _, _, _)) :- strict(R).
strict(meta(R, _, _, _)) :- strict(R).
strict(extract(R, _)) :- strict(R).
strict(filter(R, _)) :- strict(R).
strict(then(R, F)) :- strict(R), ( F == none -> true ; strict_fn(F) ).
strict(op(N, R)) :- memberchk(N, ['only-element', first, last, distinct, flatten, reverse,
    'to-string', 'to-number', 'to-int', 'to-date']), strict(R).
strict(to_enum(R, _)) :- strict(R).
strict(call(rule, _, [R])) :- strict(R).

%   Whether a receiver has one value (from the typing of the tree; an
%   unknown one is taken as many).
receiver_single(item, cenv(_, b(single, _))) :- !.
receiver_single(var(N), cenv(Vs, _)) :- !, ( memberchk(N-b(single, _), Vs) -> true ; memberchk(N-b(opt, _), Vs) ).
receiver_single(paren(T), Env) :- !, receiver_single(T, Env).
receiver_single(attr(R, Owner, A, _), Env) :- !,
    receiver_single(R, Env), type_feature(Owner, A, feature(_, card(_, 1), _)).
receiver_single(call(func, Q, _), _) :- !, rune_model:rune_func(Q, _, out(_, _, card(_, 1)), _, _, _, _).
receiver_single(call(rule, Q, [A]), Env) :- !, receiver_single(A, Env), rule_typed(Q, _, ty(_, single)).
receiver_single(op(N, _), _) :- memberchk(N, ['only-element', first, last, count, sum]), !.
receiver_single(filter(A, _), Env) :- !, receiver_single(A, Env).
receiver_single(enum(_, _), _) :- !.
receiver_single(str(_), _) :- !.
receiver_single(num(_), _) :- !.
receiver_single(bool(_), _) :- !.
receiver_single(alias(_, T), Env) :- !, receiver_single(T, Env).
receiver_single(if(_, T, E), Env) :- !, receiver_single(T, Env), receiver_single(E, Env).
receiver_single(extract(A, F), Env) :- !, receiver_single(A, Env), fn_body(F, B),
    ( receiver_single(A, Env) -> X = _, fn_env(Env, b(single, X), E2), receiver_single(B, E2) ).
receiver_single(then(A, F), Env) :- F \== none, !,
    ( receiver_single(A, Env) -> I = b(single, _) ; I = b(list, _) ),
    fn_env(Env, I, E2), fn_body(F, B), receiver_single(B, E2).
receiver_single(T, _) :- condition_like(T).

condition_like(T) :- functor(T, F, _),
    memberchk(F, [eq, cmp, exists, absent, and, or, contains, disjoint, only_exists, choice]), !.
condition_like(call(func, Q, _)) :- boolean_func(Q).
condition_like(call(rule, Q, _)) :- rune_model:rune_rule(eligibility, Q, _, _, _, _).

boolean_func(Q) :- rune_model:rune_func(Q, _, Out, _, _, _, _), boolean_output(Out).

%   A call: each argument as the input wants it (one value or a list).
call_goal(Q, Args, Env, Extra, G) :-
    (   lib_function(Q, LF, Map)
    ->  %  only the arguments the library reads (RoundToPrecision's
        %  fourth, removeTrailingZero, is about how the number is printed)
        findall(A, ( member(I, Map), nth1(I, Args, A) ), UArgs),
        maplist(arg_value(Env, single), UArgs, LArgs, AGs),
        append(LArgs, Extra, All), L =.. [LF|All]
    ;   rune_model:rune_func(Q, _, _, _, _, Ann, _), get_dict(codeImplementation, Ann, _),
        \+ java_reading(Q, _)
    ->  short(Q, S), residue(java(S))
    ;   rune_model:rune_func(Q, Ins, _, _, _, _, _),
        tmpl(func(Q), F, _, _),
        length(Args, NA), length(Ins, NI),
        ( NA =:= NI -> true ; residue(arity(Q)) ),
        maplist(arg_for_input(Env), Args, Ins, AVs, AGs),
        append(AVs, Extra, All), L =.. [F|All]
    ),
    conjs(AGs, GA), conj(GA, L, G).

arg_for_input(Env, A, in(_, _, card(_, Max)), V, G) :-
    (   Max == 1 -> arg_value(Env, opt, A, V, G)
    ;   arg_value(Env, list, A, V, G)
    ).

arg_value(Env, single, A, V, G) :- cs(A, Env, V, G).
arg_value(_, opt, empty, nothing, true) :- !.
arg_value(cenv(Vs, _), opt, var(N), X, true) :- memberchk(N-b(opt, X), Vs), !.   % passed on as it is
arg_value(Env, opt, A, V, G) :-
    cs(A, Env, X, GA),
    (   GA == true -> V = X, G = true
    ;   cl(A, Env, L, GL), conj(GL, rune_or_nothing(L, V), G)
    ).
arg_value(Env, list, A, L, G) :- cl(A, Env, L, G).

% ---------------------------------------------------------------- conditions

%   cc(+T, +Env, -Goal): Goal holds when T is True.
cc(T, Env, G) :- cc_(T, Env, G), !.
cc(T, _, _) :- functor(T, F, N), residue(cond(F/N)).

cc_(paren(T), Env, G) :- cc(T, Env, G).
cc_(bool(true), _, true).
cc_(bool(false), _, fail).
cc_(and(L, R), Env, G) :- cc(L, Env, GL), cc(R, Env, GR), conj(GL, GR, G).
cc_(or(L, R), Env, or(GL, GR)) :- cc(L, Env, GL), cc(R, Env, GR).
cc_(exists(none, A), Env, G) :- cs(A, Env, _, G).
cc_(exists(single, A), Env, and(agg(count, X, GA, N), N = 1)) :- cs(A, Env, X, GA).
cc_(exists(multiple, A), Env, and(agg(count, X, GA, N), N > 1)) :- cs(A, Env, X, GA).
cc_(absent(A), Env, not(G)) :- cs(A, Env, _, G).
cc_(call(func, Q, Args), Env, G) :- boolean_func(Q), call_goal(Q, Args, Env, [], G).
cc_(call(rule, Q, [A]), Env, G) :-
    rune_model:rune_rule(eligibility, Q, _, _, _, _),
    tmpl(rule(Q), F, _, _), cs(A, Env, X, GA), L =.. [F, X], conj(GA, L, G).
cc_(eq(Op, M, L, R, LTy, RTy), Env, G) :- equality(Op, M, L, R, LTy, RTy, Env, G).
cc_(cmp(Op, M, L, R, LTy, _), Env, G) :- comparison(Op, M, L, R, LTy, Env, G).
cc_(only_exists(Ps, _), Env, G) :-
    Ps = [attr(R, Owner, _, _)|_],
    forall(member(P, Ps), P = attr(_, Owner, _, _)),
    cs(R, Env, O, GR),
    findall(A, member(attr(_, _, A, _), Ps), Set),
    include([A]>>tmpl(attr(A), _, _, _), Set, Present),
    maplist(attr_literal(O), Present, Ls),
    findall(B, ( type_feature(Owner, B, _), \+ memberchk(B, Set), tmpl(attr(B), _, _, _) ), Others),
    maplist(absent_literal(O), Others, Ns),
    append(Ls, Ns, Gs), conjs(Gs, GO), conj(GR, GO, G).
cc_(contains(L, R), Env, G) :-
    cl(L, Env, LL, GL), cl(R, Env, RL, GR), conj(GL, GR, G0), conj(G0, rune_contains_all(LL, RL), G).
cc_(disjoint(L, R), Env, G) :-
    cl(L, Env, LL, GL), cl(R, Env, RL, GR), conj(GL, GR, G0), conj(G0, rune_disjoint(LL, RL), G).
cc_(if(C, T, E), Env, or(and(GC, GT), and(not(GC), GE))) :-
    cc(C, Env, GC), cc(T, Env, GT), cc(E, Env, GE).
cc_(if(C, T), Env, and(GC, GT)) :- cc(C, Env, GC), cc(T, Env, GT).
cc_(alias(N, T), Env, G) :- alias_call(N, T, Env, condition, _, G).
cc_(T, Env, G) :- \+ condition_like(T), cs(T, Env, X, G0), conj(G0, X = "true", G).   % a boolean value

attr_literal(O, A, L) :- tmpl(attr(A), F, _, _), L =.. [F, O, _].
absent_literal(O, A, not(L)) :- attr_literal(O, A, L).

% Rune's `=` and `<>` (ExpressionEqualityUtilNullSafe).
equality(Op, M, L, R, _, _, Env, G) :-
    boolean_literal(R, B), condition_like(L), !,
    cc(L, Env, GL),
    (   Op == (=) -> Pos = true ; Pos = false ),
    (   Pos == B -> G = GL ; G = not(GL) ).
equality(Op, M, L, R, LTy, RTy, Env, G) :-
    boolean_literal(R, B), \+ condition_like(L), !,
    atom_string(B, BS), equality(Op, M, L, str(BS), LTy, RTy, Env, G).
equality(Op, M, L, R, LTy, RTy, Env, G) :-
    boolean_literal(L, _), \+ boolean_literal(R, _), !,
    equality(Op, M, R, L, RTy, LTy, Env, G).
equality(=, M, L, R, _, _, Env, G) :-
    (   M == any ; receiver_single(L, Env), receiver_single(R, Env) ), !,
    cs(L, Env, X, GL), cs(R, Env, Y, GR), same(Env, X, Y, GL, GR, G).
equality(=, _, L, R, _, _, Env, G) :-
    receiver_single(R, Env), !,
    cl(L, Env, LL, GL), cs(R, Env, Y, GR), conj(GL, GR, G0),
    conj(G0, and(LL \= [], forall(member(X, LL), X = Y)), G).
equality(=, _, L, R, _, _, Env, G) :- !,
    cl(L, Env, LL, GL), cl(R, Env, RL, GR), conj(GL, GR, G0), conj(G0, LL = RL, G).
equality(<>, any, L, R, _, _, Env, G) :- !,
    cs(L, Env, X, GL), cs(R, Env, Y, GR), conj(GL, GR, G0), conj(G0, X \= Y, G).
equality(<>, _, L, R, _, _, Env, not(G)) :-
    cs(L, Env, X, GL), cs(R, Env, Y, GR), same(Env, X, Y, GL, GR, G).

%   X and Y the same value: made one variable when that changes nothing
%   else (neither is a variable of the definition: an input, the item),
%   else a condition.
same(Env, X, Y, GL, GR, G) :-
    (   ( GL == true, given_by_sentence(GR, Y) ; GR == true, given_by_sentence(GL, X) ; GL == true, GR == true ),
        \+ occurs_in(X, Env), \+ occurs_in(Y, Env)
    ->  ( X = Y -> conj(GL, GR, G) ; G = fail )
    ;   conj(GL, GR, G0), conj(G0, X = Y, G)
    ).

%   The value is the last place of a template's sentence (the last condition
%   of G): `the identifier type of P is "LEI"` reads well with the constant
%   in it. An aggregate's or a formula's result does not take one.
given_by_sentence(G, X) :-
    and_list(G, L), last(L, Lit), compound(Lit),
    \+ memberchk(Lit, [_ = _, _ \= _]),
    functor(Lit, F, N), \+ memberchk(F/N, [agg/4, is/2, member/2, prolog/1, not/1, or/2, forall/2]),
    arg(N, Lit, A), A == X.

boolean_literal(bool(B), B).
boolean_literal(paren(T), B) :- boolean_literal(T, B).

comparison(Op, M, L, R, ty(K, _), Env, G) :-
    cs(R, Env, Y, GR),
    (   M == all, \+ receiver_single(L, Env)
    ->  cl(L, Env, LL, GL), cmp_goal(Op, K, X, Y, C),
        conj(GL, GR, G0), conj(G0, and(LL \= [], forall(member(X, LL), C)), G)
    ;   cs(L, Env, X, GL), cmp_goal(Op, K, X, Y, C), conj(GL, GR, G0), conj(G0, C, G)
    ).

cmp_goal(Op, K, X, Y, C) :-
    (   memberchk(K, [basic(date), basic(zonedDateTime), basic(dateTime), basic(time)])
    ->  (   Op == (<) -> C = rune_earlier(X, Y)
        ;   Op == (>) -> C = rune_earlier(Y, X)
        ;   Op == (=<) -> C = not(rune_earlier(Y, X))
        ;   C = not(rune_earlier(X, Y))
        )
    ;   C =.. [Op, X, Y]
    ).

% ---------------------------------------------------------------- items

basic_part(date, rune_date_part).
basic_part(time, rune_time_part).
basic_part(timezone, rune_timezone_part).
basic_part(year, rune_year_part).
basic_part(month, rune_month_part).
basic_part(day, rune_day_part).

%   The definitions as IR items: each clause a rule, a definition with a
%   problem a residue block, and the ledger.
defs_items(Defs, Items, Ledger) :-
    foldl(def_items, Defs, []-[], Items-Ledger), !.

def_items(def(What, Clauses0, Problems), Is0-Ls0, Is-Ls) :-
    what_text(What, Src, Title),
    assertz(def_title_of(Title, What)),
    ( lift_clauses(What, Clauses0, Clauses) -> true ; throw(lift_failed(What)) ),
    clause_items(What, Clauses, Title, CIs),
    (   Problems == []
    ->  RIs = [], Verdict = encoded, Note = none
    ;   residue_id(What, Id),
        tmpl_of(What, F),
        format(atom(TitleR), '~w: ~w', [Title, Problems]),
        RIs = [residue(Id, [title(TitleR), source(rune, Src), concludes([F])])],
        ( Clauses == [] -> Verdict = residue ; Verdict = approximated ),
        format(atom(Note), '~w', [Problems])
    ),
    what_element(What, El),
    ( tmpl_of(What, F2) -> true ; F2 = none ),
    append([[comment(Title)], CIs, RIs], Mine),
    append(Is0, Mine, Is),
    what_kind(What, Kind),
    append(Ls0, [entry(El, Kind, Verdict, 'Rune definition -> LE rules', F2, Note)], Ls).

% ---------------------------------------------------------------- core LE

%   lift_clauses(+What, +Clauses0, -Clauses): core LE has no form for an
%   alternative of an `or` that opens with a negation, a list or an
%   aggregate (only le_extensions.pl's `either` / `all of` blocks write it).
%   Such an alternative becomes a rule of its own, "the value meets
%   condition N of <the definition>", on the variables it shares with the
%   rest of the clause, and the `or` names it: every alternative then opens
%   with a plain condition, and the twin is core Logical English.
lift_clauses(_, Clauses, Clauses) :- getenv('RUNE_NO_LIFT', _), !.     % (a switch, for a comparison)
lift_clauses(What, Clauses0, Clauses) :-
    %  (the conditions are numbered across the twin: two definitions whose
    %  templates have the same words would otherwise give two conditions
    %  the same sentence, which LE reads as one predicate)
    ( nb_current(rune_lift_n, _) -> true ; nb_setval(rune_lift_n, 0) ),
    foldl(lift_clause(What), Clauses0, []-[], Main-Aux),
    append(Main, Aux, Clauses).

lift_clause(What, rule(H, B0), M0-A0, M-A) :-
    once(lift(B0, [H], What, B, A0, A1)),
    append(M0, [rule(H, B)], M), A = A1.

lift(V, _, _, V, A, A) :- var(V), !.
lift(and(X, Y), Out, W, and(X1, Y1), A0, A) :- !,
    lift(X, [Y|Out], W, X1, A0, A1), lift(Y, [X1|Out], W, Y1, A1, A).
lift(or(X, Y), Out, W, G, A0, A) :- !,
    or_alts(or(X, Y), Alts),
    lift_alts(Alts, Alts, Out, W, Alts1, A0, A),
    or_join(Alts1, G).
lift(not(X), Out, W, not(X1), A0, A) :- !, lift(X, Out, W, X1, A0, A).
lift(agg(Op, E, G0, R), Out, W, agg(Op, E, G1, R), A0, A) :- !,      % (the builder's aggregates)
    lift(G0, [E, R|Out], W, G1, A0, A).
lift(T, Out, W, T1, A0, A) :-
    compound(T), T =.. [F, E, G0, R], memberchk(F, [list, count, sum, max, min]), !,
    lift(G0, [E, R|Out], W, G1, A0, A), T1 =.. [F, E, G1, R].
lift(G, _, _, G, A, A).

or_alts(G, As) :- ( nonvar(G), G = or(X, Y) -> or_alts(X, AX), or_alts(Y, AY), append(AX, AY, As) ; As = [G] ).
or_join([G], G) :- !.
or_join([G|Gs], or(G, R)) :- or_join(Gs, R).

lift_alts([], _, _, _, [], A, A).
lift_alts([X|Xs], All, Out, W, [Y|Ys], A0, A) :-
    exclude(==(X), All, Others),
    once(lift(X, [Others|Out], W, X1, A0, A1)),
    (   first_conjunct(X1, F), \+ le_writer:plain_line(F),
        %  (a variable the alternative shares only with the other
        %  alternatives is its own: each binds it apart)
        term_variables(X1, XV), term_variables(Out, OV),
        shared_vars(XV, OV, Args0), list_to_set_eq(Args0, Args),
        length(Args, NArgs), NArgs =< 20            % (more places than words for them: left as it is)
    ->  aux_template(W, Args, Head),
        Y = Head, A2 = [rule(Head, X1)|A1]
    ;   Y = X1, A2 = A1
    ),
    lift_alts(Xs, All, Out, W, Ys, A2, A).

%   The variables of the first list that are in the second, themselves (a
%   findall would copy them).
shared_vars([], _, []).
shared_vars([V|Vs], OV, Out) :-
    ( member(V2, OV), V2 == V -> Out = [V|Out1] ; Out = Out1 ),
    shared_vars(Vs, OV, Out1).

first_conjunct(G, F) :- nonvar(G), G = and(X, _), !, first_conjunct(X, F).
first_conjunct(F, F).

list_to_set_eq([], []).
list_to_set_eq([V|Vs], [V|Out]) :- exclude(==(V), Vs, Rest), list_to_set_eq(Rest, Out).

%   "*a value* meets condition 2 of the CFTC is allowable action with *a
%   second value*": a template of the definition's own words.
aux_template(What, Args, Head) :-
    nb_getval(rune_lift_n, N0), N is N0 + 1, nb_setval(rune_lift_n, N),
    ( tmpl_of(What, OF) -> true ; OF = rule ),
    format(atom(F), '~w_condition_~w', [OF, N]),
    ( tmpl_of(What, OF), tmpl(_, OF, OT, _) -> owner_words(OT, OW) ; OW = 'the rule' ),
    length(Args, Ar),
    aux_text(Ar, N, OW, Text),
    assertz(tmpl(aux(What, N), F, Text, Ar)),
    Head =.. [F|Args].

%   The definition's template without its places: "the CFTC is allowable
%   action of *a value*" -> "the CFTC is allowable action".
owner_words(T, W) :-
    atom_codes(T, Cs), no_places(Cs, Ds), atom_codes(W0, Ds),
    split_string(W0, " ", " ", Ws0), exclude(==(""), Ws0, Ws1),
    exclude([X]>>memberchk(X, ["of", "with", "is", "a", "an", "the"]), Ws1, Ws2),
    ( Ws2 == [] -> Ws = ["rule"] ; Ws = Ws2 ),
    atomic_list_concat(Ws, ' ', W).
no_places([], []).
no_places([0'*|Cs], Ds) :- !, append(_, [0'*|Rest], Cs), !, no_places(Rest, Ds).
no_places([C|Cs], [C|Ds]) :- no_places(Cs, Ds).

aux_text(0, N, OW, T) :- !, format(atom(T), 'condition ~w of ~w holds', [N, OW]).
aux_text(Ar, N, OW, T) :-
    ordinal_places(Ar, [P1|Ps]),
    format(atom(T0), '~w meets condition ~w of ~w', [P1, N, OW]),
    foldl([P, A0, A1]>>format(atom(A1), '~w beside ~w', [A0, P]), Ps, T0, T).

ordinal_places(N, Ps) :- numlist(1, N, Is), maplist(ordinal_place, Is, Ps).

ordinal_place(1, '*a value*') :- !.
ordinal_place(I, P) :-
    nth1(I, ['', 'second ', 'third ', 'fourth ', 'fifth ', 'sixth ', 'seventh ', 'eighth ', 'ninth ', 'tenth ',
             'eleventh ', 'twelfth ', 'thirteenth ', 'fourteenth ', 'fifteenth ', 'sixteenth ', 'seventeenth ',
             'eighteenth ', 'nineteenth ', 'twentieth '], O),
    format(atom(P), '*a ~wvalue*', [O]).

what_kind(rule(Q), K) :- rune_model:rune_rule(K0, Q, _, _, _, _), format(atom(K), '~w rule', [K0]).
what_kind(func(_), function).
what_kind(cons(_, _), constructor).
what_kind(alias(_, _), alias).

clause_items(What, Clauses, T, Items) :-
    clause_items0(What, Clauses, T, Items0),
    (   What = rule(Q), rune_model:rune_rule(_, Q, _, _, Anns, _), is_dict(Anns),
        get_dict(docReference, Anns, Ds) -> readings(Ds, Cs) ; Cs = [] ),
    append(Cs, Items0, Items).

clause_items0(What, Clauses, _, Items) :-
    citation(What, Opts0),
    (   Opts0 == [] -> findall(rule(H, B, []), member(rule(H, B), Clauses), Items)
    ;   what_element(What, Q), short(Q, S), ns_tag(Q, Tag), format(atom(TS), '~w ~w', [Tag, S]),
        snake_label(TS, L0),
        findall(rule(H, B, [label(L)|Opts0]),
                ( nth1(I, Clauses, rule(H, B)), ( I == 1 -> L = L0 ; format(atom(L), '~w_~w', [L0, I]) ) ),
                Items)
    ).

snake_label(S, L) :-
    atomic_list_concat(Parts, ' ', S), maplist(words, Parts, Wss), append(Wss, Ws0),
    maplist([W, D]>>downcase_atom(W, D), Ws0, Ws),
    atomic_list_concat(Ws, '_', L0),
    ( sub_atom(L0, 0, 1, _, C), char_type(C, digit) -> atom_concat(r_, L0, L) ; L = L0 ).

citation(rule(Q), [provenance(P)]) :-
    rune_model:rune_rule(_, Q, _, _, Anns, _), is_dict(Anns),
    get_dict(docReference, Anns, Ds), Ds \== [], !,
    doc_provenance(Ds, P).
citation(_, []).

%   The first passage of a regulation (not ISDA's) is the provenance: the
%   document with its place in it, and the passage quoted. The industry's
%   readings (ISDA's working groups) are comments above the rule, each
%   with its date and text: LE keeps one document per rule, and the two
%   kinds of citation stay apart.
doc_provenance(Ds, P) :-
    exclude(isda_doc, Ds, Reg),
    (   Reg = [D|_] -> doc_trailers(D, P) ; P = [] ).

readings(Ds, Comments) :-
    include(isda_doc, Ds, Isda),
    findall(comment(C), ( member(D, Isda), isda_reading(D, S),
                          ( get_dict(provision, D, Pr), Pr \== '' -> clean_quote(Pr, Q),
                            format(atom(C), 'Industry reading, ~w: "~w"', [S, Q])
                          ; format(atom(C), 'Industry reading, ~w', [S]) ) ), Comments).

isda_doc(D) :- get_dict(source, D, S), sub_atom(S, 0, _, _, 'ISDA').

isda_reading(D, S) :-
    get_dict(source, D, Src0), document_name(Src0, Src),
    (   get_dict(date, D, Dt), atom_length(Dt, 8)
    ->  sub_atom(Dt, 0, 4, _, Y), sub_atom(Dt, 4, 2, _, M), sub_atom(Dt, 6, 2, _, Dd),
        format(atom(S), '~w, ~w-~w-~w', [Src, Y, M, Dd])
    ;   S = Src
    ).

doc_trailers(D, P) :-
    get_dict(source, D, S0), document_name(S0, Doc0),
    ( get_dict('$order', D, Order) -> true ; dict_keys(D, Order) ),
    findall(T, ( member(K, Order), get_dict(K, D, V), \+ memberchk(K, [source, provision, '$order', for, in, '_extra']),
                 locator_word(K, KW), format(atom(T), '~w ~w', [KW, V]) ), Ts),
    ( Ts == [] -> Doc = Doc0 ; atomic_list_concat(Ts, ', ', Loc), format(atom(Doc), '~w, ~w', [Doc0, Loc]) ),
    (   get_dict(provision, D, Pr), Pr \== '' -> clean_quote(Pr, Q), P = [as_stated_in(Doc), confer(Q)]
    ;   P = [as_stated_in(Doc)]
    ).

dict_keys(D, Ks) :- dict_pairs(D, _, Ps), pairs_keys(Ps, Ks).

locator_word(dataElement, 'data element') :- !.
locator_word(validationRule, 'validation rule') :- !.
locator_word(K, K).

%   "CFTC Part45" -> "CFTC 17 CFR Parts 45 Version 3.0"; "CPMI_IOSCO
%   cdeV1.CDE" -> "CPMI-IOSCO Harmonisation of Critical Data Elements ...":
%   the body, and the name its corpus declaration gives.
document_name(S0, Doc) :-
    atomic_list_concat(Ws, ' ', S0), exclude(==(''), Ws, [Body|Rest]),
    atomic_list_concat(BParts, '_', Body), atomic_list_concat(BParts, '-', B),
    (   Rest = [C0|More], atomic_list_concat(CPs, '.', C0), last(CPs, Alias),
        corpus_name(Alias, Body, Name)
    ->  ( sub_atom(Name, 0, _, _, B) -> D0 = Name ; format(atom(D0), '~w ~w', [B, Name]) ),
        ( More == [] -> Doc = D0 ; atomic_list_concat([D0|More], ' ', Doc) )
    ;   atomic_list_concat([B|Rest], ' ', Doc)
    ).

:- dynamic corpus_table/3.
corpus_name(Alias, Body, Name) :-
    (   corpus_table(_, _, _) -> true
    ;   forall(( rune_reader:loaded_dict(NS, D), member(C, D.get(corpora, [])),
                 get_dict('Alias', C, A), get_dict('CorpusName', C, N), N \== null ),
               assertz(corpus_table(A, NS, N)))
    ),
    downcase_atom(Body, BL),
    (   corpus_table(Alias, NS, Name), sub_atom(NS, _, _, _, BL) -> true
    ;   corpus_table(Alias, _, Name)
    ), !.

clean_quote(P, Q) :-
    atom_string(P, S0), split_string(S0, "\n\t", "", Parts), atomic_list_concat(Parts, ' ', S1),
    atomic_list_concat(Bits, '"', S1), atomic_list_concat(Bits, '\'', S2),
    normalize_space(atom(Q), S2).

what_text(rule(Q), Src, Title) :-
    rune_model:rune_rule(K, Q, In, W, _, Doc), rune_expression(W, Text, _),
    short(In, IS),
    format(atom(Src), '~w rule ~w from ~w:~n    ~w', [K, Q, IS, Text]),
    ( Doc == '' -> format(atom(Title), '~w rule ~w', [K, Q]) ; format(atom(Title), '~w rule ~w: ~w', [K, Q, Doc]) ).
what_text(func(Q), Src, Title) :-
    rune_model:rune_func(Q, _, _, Steps, _, _, Doc),
    findall(L, ( member(St, Steps), St =.. [K, T, W], rune_expression(W, Text, _),
                 ( is_list(T) -> atomic_list_concat(T, ' -> ', TT) ; TT = T ),
                 format(atom(L), '~w ~w: ~w', [K, TT, Text]) ), Ls),
    atomic_list_concat(Ls, '\n', Body),
    format(atom(Src), 'func ~w:~n~w', [Q, Body]),
    ( Doc == '' -> format(atom(Title), 'function ~w', [Q]) ; format(atom(Title), 'function ~w: ~w', [Q, Doc]) ).

what_text(alias(Q, N), Src, Title) :-
    rune_model:rune_func(Q, _, _, Steps, _, _, _), memberchk(alias(N, W), Steps),
    rune_expression(W, Text, _),
    format(atom(Src), 'func ~w:~n    alias ~w: ~w', [Q, N, Text]),
    format(atom(Title), 'alias ~w of function ~w', [N, Q]).

what_text(cons(Site, T), Src, Title) :-
    format(atom(Src), 'the object built at ~w (a ~w)', [Site, T]),
    format(atom(Title), 'the attributes of the ~w built at ~w', [T, Site]).

what_element(cons(Site, _), Site).
what_element(rule(Q), Q).
what_element(func(Q), Q).
what_element(alias(Q, N), E) :- format(atom(E), '~w/~w', [Q, N]).

tmpl_of(rule(Q), F) :- tmpl(rule(Q), F, _, _).
tmpl_of(func(Q), F) :- tmpl(func(Q), F, _, _).
tmpl_of(cons(_, _), none).
tmpl_of(alias(Q, N), F) :- tmpl(alias(Q, N, _), F, _, _).

residue_id(What, Id) :- what_element(What, Q), short(Q, S), term_hash(Q, H), format(atom(Id), '~w_~w', [S, H]).

% ---------------------------------------------------------------- reference data

%   The ISO 10383 records of the venues the test packs name (mic_data.py),
%   for a twin whose closure fetches them (API_GetMicData): DRR's Java reads
%   the same table from iso20022.org.
reference_templates(Funcs) :-
    (   memberchk('drr.standards.iso.API_GetMicData', Funcs)
    ->  assertz(tmpl(reference(mic), iso_10383_record, "*a mic data* is the ISO 10383 record of *a mic*", 2))
    ;   true
    ).

reference_facts(Items) :-
    (   tmpl(reference(mic), RF, _, _), mic_records(Gen, Recs)
    ->  findall(I, ( member(Mic-R, Recs), mic_object(Mic, O),
                      (   I = comment(C), format(atom(C), 'ISO 10383, ~w', [Mic])
                      ;   atom_string(Mic, MS), H =.. [RF, O, MS], I = fact(H)
                      ;   get_dict(K, R, V), K \== mic, tmpl(attr(K), AF, _, _),
                          H =.. [AF, O, V], I = fact(H) ) ), Items0),
        format(atom(C0), 'The ISO 10383 records of the venues named in DRR\'s test packs, as DRR\'s Java fetches them from iso20022.org: the list of ~w. DRR\'s test packs were made with the list of their day; a venue whose record changed since gives another value.', [Gen]),
        Items = [comment(C0)|Items0]
    ;   Items = []
    ).

mic_object(Mic, O) :- downcase_atom(Mic, L), atom_concat(mic_, L, O).

mic_records(Gen, Recs) :-
    module_property(rune_twin, file(F)), file_directory_name(F, D),
    atom_concat(D, '/.cache/mic_records.json', J), exists_file(J),
    setup_call_cleanup(open(J, read, S), json_read_dict(S, Dict, [value_string_as(string)]), close(S)),
    Gen = Dict.generated,
    dict_pairs(Dict.records, _, Recs).

% ---------------------------------------------------------------- the fields

%   One rule per field: the value of the field's rule (its only value, for a
%   field of one value: DRR's Java takes it only when there is exactly one).
report_field_rules(Report, Fields0, Fields, Items) :-
    findall(F-I, ( member(field(Path, Ref, Info), Fields0), field_rule_q(Ref, Q),
                   tmpl(rule(Q), _, _, 2),
                   field_item(Report, Path, Q, Info, F, R),
                   Info = info(_, Docs), readings(Docs, Cs), append(Cs, [R], I) ), FIs),
    pairs_keys_values(FIs, Fields1, Items1), append(Items1, Items0a),
    %  a field whose value is an object is reported by the object's
    %  attributes: strikePrice.monetary
    findall(SF-SI, ( member(field(Path, Q, QN, Label, _), Fields1),
                     object_field(Report, Path, OT),
                     sub_field(Q, Path, QN, Label, OT, SF, SI) ), SFIs),
    pairs_keys_values(SFIs, SubFields, SubItems),
    %  the object itself is not a value of the report
    exclude(object_field_entry(Report), Fields1, Plain),
    findall(L, ( member(field(P, _, _, L, _), Fields1), object_field(Report, P, _) ), ObjLabels),
    exclude(object_field_rule(ObjLabels), Items0a, PlainItems),
    append(Plain, SubFields, Fields),
    append(PlainItems, SubItems, Items0),
    findall(query(QN, report_field(Label, instruction, _)),
            member(field(_, _, QN, Label, _), Fields), Qs),
    append(Items0, Qs, Items).

field_item(Report, Path, Q, info(Label0, Docs), field(Path, Q, QN, Label, Card), rule(Head, Body, Opts)) :-
    atomic_list_concat(Path, '.', P),
    ( Label0 == none -> Label1 = P ; Label1 = Label0 ),
    field_label(Label1, Label),
    query_name(Path, QN),
    rune_model:rune_report(Report, _, _, In, _, T),
    field_card(T, Path, Card),
    tmpl(rule(Q), F, _, _),
    X = _, V = _,
    Head = report_field(Label, X, V),
    RL =.. [F, X, V],
    (   Card == single, \+ rule_typed(Q, _, ty(_, single))
    ->  RL2 =.. [F, X, E], Body0 = and(and(agg(list, E, RL2, L), rune_distinct(L, D)), rune_only_element(D, V))
    ;   Body0 = RL
    ),
    Body = and(Body0, V \= ""),          % an empty text is not reported
    ( Docs \== [], doc_provenance(Docs, Prov), Prov \== [] -> Opts = [label(QN), provenance(Prov)] ; Opts = [] ),
    _ = In.

%   A label with a word of the field's template in it ("Maturity Date of
%   the Underlier") is a text, which LE writes in quotes: bare, the
%   template would end the label at its "of".
field_label(L0, L) :-
    atom_string(L0, S),
    split_string(S, " ", "", Ws),
    (   ( member(W, Ws), memberchk(W, ["of", "is", "with", "field"]) ) -> L = S ; atom_string(L, S) ).

object_field_entry(Report, field(P, _, _, _, _)) :- object_field(Report, P, _).
object_field_rule(Labels, rule(report_field(L, _, _), _, _)) :- memberchk(L, Labels).

object_field(Report, Path, OT) :-
    rune_model:rune_report(Report, _, _, _, _, T),
    append(Pre, [Last], Path),
    foldl(path_type, Pre, T, Owner),
    type_feature(Owner, Last, feature(TR, _, _)),
    value_type(TR, object(OT)).

path_type(A, T0, T1) :- type_feature(T0, A, feature(TR, _, _)), value_type(TR, object(T1)).

sub_field(Q, Path, QN, Label, OT, field(SubPath, Q, SQN, SLabel, multi), rule(Head, Body, [])) :-
    tmpl(rule(Q), F, _, _),
    X = _, O = _, V = _,
    RL =.. [F, X, O],
    sub_attribute(OT, 3, O, V, Bs, AL),
    append(Path, Bs, SubPath),
    atomic_list_concat([QN|Bs], '_', SQN),
    atomic_list_concat([Label|Bs], ' ', SLabel0),
    field_label(SLabel0, SLabel),
    Head = report_field(SLabel, X, V),
    Body = and(RL, AL).

%   sub_attribute(+Type, +Depth, ?Object, ?Value, -Names, -Goal): a value
%   reached from an object of the type by attributes whose last is not an
%   object (an object is reported by its own attributes, Depth deep).
sub_attribute(OT, D, O, V, [B|Bs], Goal) :-
    type_feature(OT, B, feature(TR, _, _)), tmpl(attr(B), AF, _, _),
    (   value_type(TR, object(OB))
    ->  D > 1, D1 is D - 1,
        O1 = _, G1 =.. [AF, O, O1],
        sub_attribute(OB, D1, O1, V, Bs, G2), Goal = and(G1, G2)
    ;   Bs = [], Goal =.. [AF, O, V]
    ).

query_name(Path, QN) :-
    atomic_list_concat(Path, '_', P0), snake(P0, QN0), format(atom(QN), 'field_~w', [QN0]).

snake(A, S) :-
    atom_codes(A, Cs), foldl([C, D0, D]>>( code_type(C, upper(L)) -> append(D0, [0'_, L], D) ; append(D0, [C], D) ), Cs, [], Ds),
    atom_codes(S, Ds).

%   One step of a path: the type of the attribute A of the type T0.
path_step(A, T0, T1) :-
    type_feature(T0, A, feature(TR, _, _)),
    ( value_type(TR, object(T1)) -> true ; T1 = TR ).

field_card(T, Path, Card) :-
    foldl(path_step, Path, T, _),
    append(Pre, [Last], Path),
    foldl([A, T0, T1]>>( type_feature(T0, A, feature(TR, _, _)), value_type(TR, object(T1)) ), Pre, T, Owner),
    ( type_feature(Owner, Last, feature(_, card(_, 1), _)) -> Card = single ; Card = multi ), !.
field_card(_, _, multi).

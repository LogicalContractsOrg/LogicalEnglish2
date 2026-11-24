:- module(rune_closure, [
    report_fields/2,        % +ReportName, -[field(Path, ref(Rule, InType), Info)]
    field_rule_q/2,         % +ref(Rule, InType), -RuleQ
    report_closure/2,       % +ReportName, -closure(Rules, Funcs, Attrs, Enums, Unresolved)
    closure_of/2,           % +Roots ([rule(Q) | func(Q)]), -closure(...)
    rule_typed/3,           % +RuleQ, -Typed, -Type      (memoised)
    func_step_typed/4       % +FuncQ, +Where, -Typed, -Type (memoised)
]).
/** <module> A report's fields, and the closure of what computes them

**The fields.** A report (`report CFTC Part45 ... with type
CFTCPart45TransactionReport`) is computed field by field: each attribute
of its type with `[ruleReference R]` is the value of rule R. An attribute
whose type is a type has fields of its own, and the attribute may name the
rules of its sub-fields: `leg1 CFTCPart45Leg [ruleReference for
notionalAmount NotionalAmountLeg1]`. A type that extends another has the
other's fields; an annotation on the more specific declaration wins (an
`override` in a subtype, then the `for` annotations of the attribute that
contains the field, the outermost first). `[ruleReference empty]` says that
the field is not reported; `[nonReportable]` fields are DRR's working data.

**The closure** of a report: the rules its fields name, the functions and
rules they call, transitively, the attributes all of them read and the
enumerations they name (rune.md §4.2: the twin is the size of what it
uses).
*/

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(assoc)).
:- use_module(parser/rune_reader).
:- use_module(rune_types).
:- use_module(rune_data, [type_feature/3, value_type/2]).

%!  report_fields(+Report, -Fields) is det.
%
%   Fields: field(Path, Rule, info(Label, DocRefs)) in the order of the
%   report type's attributes (its supertypes' first), Path a list of
%   attribute names.
report_fields(Report, Fields) :-
    rune_model:rune_report(Report, _, _, _, _, T),
    findall(F, type_fields(T, [], [], F), Fs0),
    dedup_paths(Fs0, Fields).

same_path(P, field(P2, _, _)) :- P2 == P.

dedup_paths([], []).
dedup_paths([F|Fs], [F|Out]) :-
    F = field(P, _, _),
    exclude(same_path(P), Fs, Rest),
    dedup_paths(Rest, Out).

%   type_fields(+Type, +Prefix, +ForAnns, -Field): ForAnns are the `for`
%   annotations of the attributes that contain this type, outermost first:
%   for(Path, Kind, Value), Path relative to this type.
type_fields(T, Prefix, ForAnns, Field) :-
    attribute_order(T, As),
    member(A, As),
    \+ ( Prefix == [], A == nonReportable ),     % DRR's working data
    attribute_annotations(T, A, Anns),
    type_feature(T, A, feature(AT, card(_, Max), _)),
    append(Prefix, [A], Path),
    (   field_rule([A], ForAnns, Anns, Rule) ->
        Rule \== empty,
        field_info([A], ForAnns, Anns, Info),
        Field = field(Path, Rule, Info)
    ;   % Rune's RuleReferenceService: only an attribute of one value is
        % searched for the rules of its own attributes
        Max == 1,
        value_type(AT, object(Sub)), \+ rune_model:rune_enum(Sub, _, _),
        sub_for_annotations(A, ForAnns, Anns, Sub, SubFor),
        type_fields(Sub, Path, SubFor, Field)
    ).

%   The attributes of a type, its supertypes' first, each once.
attribute_order(T, As) :-
    findall(Anc, type_ancestor(T, Anc), Ancs0), reverse(Ancs0, Ancs),
    findall(A, ( member(Anc, Ancs), rune_model:rune_attr(Anc, A, _, _, _, _) ), As0),
    list_to_set(As0, As).

%   The annotations of an attribute, merged down the hierarchy: a subtype's
%   override adds to (and for the same kind, replaces) its supertype's.
attribute_annotations(T, A, Anns) :-
    findall(Anc, type_ancestor(T, Anc), Ancs0), reverse(Ancs0, Ancs),
    foldl(merge_anns(A), Ancs, _{}, Anns).

merge_anns(A, Anc, Anns0, Anns) :-
    (   rune_model:rune_attr(Anc, A, _, _, _, New), is_dict(New)
    ->  dict_pairs(New, _, Ps0),
        maplist(scoped_ann(Anc), Ps0, Ps),
        foldl(merge_ann, Ps, Anns0, Anns)
    ;   Anns = Anns0
    ).

%   Each annotation remembers the type it is written in: the names in it
%   are resolved there.
scoped_ann(Anc, K-V, K-V1) :-
    (   is_list(V) -> maplist(scoped_value(Anc), V, V1) ; V1 = V ).
scoped_value(Anc, D, D1) :- ( is_dict(D) -> put_dict(in, D, Anc, D1) ; D1 = D ).

merge_ann('$order'-_, D, D) :- !.
merge_ann(K-V, D0, D) :-
    (   memberchk(K, [ruleReference, label, docReference]), is_list(V),
        get_dict(K, D0, Old), is_list(Old)
    ->  % the `for` ones accumulate; the attribute's own one is replaced
        ( include(has_for, V, VF), exclude(has_for, V, VO),
          ( VO == [] -> exclude(has_for, Old, OO) ; OO = [] ),
          include(has_for, Old, OF0), exclude(for_overridden(VF), OF0, OF),
          ( K == docReference, VO \== [] -> OO2 = [] ; OO2 = OO ),
          append([OO2, VO, OF, VF], V1) )
    ;   V1 = V
    ),
    put_dict(K, D0, V1, D).

has_for(D) :- is_dict(D), get_dict(for, D, _).
for_overridden(VF, D) :- get_dict(for, D, P), member(D2, VF), get_dict(for, D2, P), !.

%   The rule of a field: an outer `for` annotation that names it, else its own.
field_rule(Path, ForAnns, Anns, Rule) :-
    (   member(for(Path, ruleReference, R-In), ForAnns) -> true
    ;   get_dict(ruleReference, Anns, RRs), member(RR, RRs), \+ has_for(RR),
        R = RR.value, In = RR.in
    ),
    ( R == empty -> Rule = empty ; Rule = ref(R, In) ).

field_info(Path, ForAnns, Anns, info(Label, Docs)) :-
    (   member(for(Path, label, L), ForAnns) -> Label = L
    ;   get_dict(label, Anns, Ls), member(LD, Ls), \+ has_for(LD) -> Label = LD.value
    ;   Label = none
    ),
    findall(D, ( member(for(Path, docReference, D), ForAnns) ), D1),
    (   get_dict(docReference, Anns, Ds) -> exclude(has_for, Ds, D2) ; D2 = [] ),
    ( D1 \== [] -> Docs = D1 ; Docs = D2 ).

%   The `for` annotations seen from inside attribute A's type: those of
%   the outer attributes that go through A, and A's own.
sub_for_annotations(A, ForAnns, Anns, _Sub, SubFor) :-
    findall(for(Rest, K, V), ( member(for([A|Rest], K, V), ForAnns), Rest \== [] ), Outer),
    findall(for(P, K, V),
            ( member(K, [ruleReference, label, docReference]),
              get_dict(K, Anns, L), member(D, L), get_dict(for, D, PT),
              atomic_list_concat(P0, '->', PT), maplist(trimmed, P0, P),
              ( K == docReference -> V = D ; K == ruleReference -> V = D.value-D.in ; V = D.value ) ),
            Own),
    append(Outer, Own, SubFor).

trimmed(X, Y) :- normalize_space(atom(Y), X).

% ---------------------------------------------------------------- closure

%!  report_closure(+Report, -Closure) is det.
report_closure(Report, C) :-
    rune_model:rune_report(Report, _, _, _, Elig, _),
    report_fields(Report, Fs),
    findall(rule(Q), ( member(field(_, Ref, _), Fs), field_rule_q(Ref, Q) ), Roots0),
    findall(rule(E), member(E, Elig), Roots1),
    append(Roots1, Roots0, Roots),
    closure_of(Roots, C).

%!  field_rule_q(+Ref, -Q) is semidet.
%
%   A rule named in a report type, resolved in the scope of the type whose
%   declaration names it.
field_rule_q(ref(R, In), Q) :-
    sub_type_scope(In, Sc),
    member(K, [rule, eligibility]), resolve_name(Sc, R, K, Q), !.

sub_type_scope(T, scope(NS, File)) :-
    atomic_list_concat(Ps, '.', T), append(NSPs, [N], Ps), atomic_list_concat(NSPs, '.', NS),
    ( rune_model:rune_member(NS, N, _, File) -> true ; File = '*' ).

%!  closure_of(+Roots, -Closure) is det.
closure_of(Roots, closure(Rules, Funcs, Attrs, Enums, Unres)) :-
    empty_assoc(S0),
    walk(Roots, S0, S),
    assoc_to_keys(S, Ks),
    findall(Q, member(rule(Q), Ks), Rules),
    findall(Q, member(func(Q), Ks), Funcs),
    findall(T-A, member(attr(T, A), Ks), Attrs),
    findall(E, member(enum(E), Ks), Enums),
    findall(N, member(unresolved(N), Ks), Unres).

walk([], S, S).
walk([X|Xs], S0, S) :-
    (   get_assoc(X, S0, _) -> walk(Xs, S0, S)
    ;   put_assoc(X, S0, true, S1),
        node_refs(X, Rs),
        append(Xs, Rs, Queue),
        walk(Queue, S1, S)
    ).

node_refs(rule(Q), Rs) :- !,
    ( rule_typed(Q, T, _) -> typed_refs(T, Rs0), maplist(ref_node, Rs0, Rs) ; Rs = [] ).
node_refs(func(Q), Rs) :- !,
    findall(R, ( rune_model:rune_func(Q, _, _, Steps, _, _, _),
                 member(St, Steps), step_where(St, W),
                 func_step_typed(Q, W, T, _), typed_refs(T, Rs0), member(R0, Rs0),
                 ref_node(R0, R) ), Rs1),
    sort(Rs1, Rs).
node_refs(_, []).

ref_node(call(func, Q), func(Q)) :- !.
ref_node(call(rule, Q), rule(Q)) :- !.
ref_node(meta(T, A, _), attr(T, A)) :- !.
ref_node(X, X).

step_where(alias(_, W), W).
step_where(set(_, W), W).
step_where(add(_, W), W).

:- dynamic rule_typed_memo/3, func_step_memo/4.

rule_typed(Q, T, Ty) :- rule_typed_memo(Q, T, Ty), !.
rule_typed(Q, T, Ty) :-
    rule_env(Q, Env), rune_model:rune_rule(_, Q, _, W, _, _),
    typed_expression(W, Env, T, Ty),
    assertz(rule_typed_memo(Q, T, Ty)).

func_step_typed(Q, W, T, Ty) :- func_step_memo(Q, W, T, Ty), !.
func_step_typed(Q, W, T, Ty) :-
    func_env(Q, Env), typed_expression(W, Env, T, Ty),
    assertz(func_step_memo(Q, W, T, Ty)).

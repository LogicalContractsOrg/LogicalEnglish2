/*  Step 3 of the design notes rune.md: how two reports differ, field by
    field (the EU's EMIR Refit and the UK's EMIR, rune.md §7 question 4).

    ./myswipl.sh -q migration/rune/compare.pl -- 'ESMA EMIR Trade' 'FCA UKEMIR Trade'

    Writes runs/compare_<report 1>_<report 2>.md. A field of both reports
    is, in the second report:

    - shared: computed by the same reporting rule;
    - the same: by a rule of its own whose logic is the first report's
      (the same expression, calling rules and functions that are
      themselves the same, or shared);
    - changed: by a rule whose logic differs; the rules where the two
      part are listed, with both texts.

    The passages each rule cites are compared too: the same logic may cite
    a different regulation (the UK's onshored text), which is the point.
*/
:- use_module(parser/rune_reader).
:- use_module(rune_closure).
:- use_module(rune_paths).
:- use_module(library(main)).

:- initialization(main, main).

:- dynamic same_memo/3, assumed/2, parted/2, field_docs/3.

main([R1, R2]) :-
    json_dir(JD), load_rune_model(JD),
    report_fields(R1, F1), report_fields(R2, F2),
    retractall(field_docs(_, _, _)),
    forall(member(field(P, _, info(_, D)), F1), assertz(field_docs(1, P, D))),
    forall(member(field(P, _, info(_, D)), F2), assertz(field_docs(2, P, D))),
    findall(row(P, Q1, Q2, L), ( member(field(P, Ref2, info(L, _)), F2),
                                  field_rule_q(Ref2, Q2),
                                  (   member(field(P, Ref1, _), F1), field_rule_q(Ref1, Q1) -> true
                                  ;   Q1 = none ) ), Rows),
    findall(only(P, L), ( member(field(P, _, info(L, _)), F1), \+ member(field(P, _, _), F2) ), Only1),
    maplist(classify, Rows, Classified),
    atomic_list_concat(W1, ' ', R1), atomic_list_concat(W1, '_', B1),
    atomic_list_concat(W2, ' ', R2), atomic_list_concat(W2, '_', B2),
    runs_file(B1, B2, File),
    setup_call_cleanup(open(File, write, S), write_md(S, R1, R2, Classified, Only1), close(S)),
    aggregate_all(count, member(c(_, shared, _), Classified), NS),
    aggregate_all(count, member(c(_, same, _), Classified), NM),
    aggregate_all(count, member(c(_, changed, _), Classified), NC),
    aggregate_all(count, member(c(_, new, _), Classified), NN),
    length(Only1, NO),
    format("~w vs ~w: ~w shared, ~w the same in a rule of its own, ~w changed, ~w only in the second, ~w only in the first; ~w~n",
           [R1, R2, NS, NM, NC, NN, NO, File]).

runs_file(B1, B2, File) :-
    module_property(rune_closure, file(F)), file_directory_name(F, D),
    format(atom(File), '~w/runs/compare_~w_~w.md', [D, B1, B2]).

classify(row(P, none, Q2, L), c(row(P, none, Q2, L), new, [])) :- !.
classify(row(P, Q, Q, L), c(row(P, Q, Q, L), shared, [])) :- !.
classify(row(P, Q1, Q2, L), c(row(P, Q1, Q2, L), Class, Parts)) :-
    retractall(parted(_, _)),
    (   same_def(rule(Q1), rule(Q2)) -> Class = same, Parts = []
    ;   Class = changed, findall(A-B, parted(A, B), Parts0), sort(Parts0, Parts)
    ).

% ---------------------------------------------------------------- sameness

%   same_def(+Def1, +Def2): two rules or functions compute the same, up to
%   rules and functions that themselves compute the same. A pair being
%   compared is assumed the same (a recursive rule is the same as its
%   copy when nothing else differs).
same_def(D, D) :- !.
same_def(D1, D2) :- same_memo(D1, D2, R), !, R == true.
same_def(D1, D2) :- assumed(D1, D2), !.
same_def(D1, D2) :-
    assertz(assumed(D1, D2)),
    (   def_trees(D1, T1), def_trees(D2, T2), same_trees(T1, T2) -> R = true
    ;   R = false, assertz(parted(D1, D2))
    ),
    retractall(assumed(D1, D2)),
    assertz(same_memo(D1, D2, R)),
    R == true.

def_trees(rule(Q), [T]) :- catch(rule_typed(Q, T, _), _, fail), !.
def_trees(func(Q), Ts) :-
    rune_model:rune_func(Q, _, _, Steps, _, _, _),
    findall(K-T, ( member(St, Steps), St =.. [K, _, W], catch(func_step_typed(Q, W, T, _), _, fail) ), Ts).

same_trees(A, B) :- var(A), !, var(B).
same_trees(call(K, Q1, As1), call(K, Q2, As2)) :- !,
    same_calls(K, Q1, Q2),
    same_trees(As1, As2).
same_trees(A, B) :- atomic(A), !, A == B.
same_trees(A, B) :-
    compound(B), A =.. [F|As], B =.. [F|Bs],
    length(As, N), length(Bs, N),
    maplist(same_trees, As, Bs).

same_calls(_, Q, Q) :- !.
same_calls(rule, Q1, Q2) :- !, same_def(rule(Q1), rule(Q2)).
same_calls(func, Q1, Q2) :- !, same_def(func(Q1), func(Q2)).
same_calls(_, Q1, Q2) :- Q1 == Q2.

% ---------------------------------------------------------------- report

write_md(S, R1, R2, Cs, Only1) :-
    format(S, "# ~w and ~w, field by field~n~n", [R1, R2]),
    format(S, "Written by `migration/rune/compare.pl` from DRR 7.14.0. For each field of the second report: whether it is computed by the first report's own rule (*shared*), by a rule of its own that computes the same (*the same*), or by a rule that computes differently (*changed*, with the rules where the two part). The passages cited are shown when they differ.~n~n", []),
    forall(member(C, [shared, same, changed, new]),
           ( aggregate_all(count, member(c(_, C, _), Cs), N), class_text(C, T),
             format(S, "- ~w: ~w~n", [T, N]) )),
    length(Only1, NO), format(S, "- only in ~w: ~w~n~n", [R1, NO]),
    format(S, "## The fields that differ~n~n", []),
    forall(member(c(row(P, Q1, Q2, L), changed, Parts), Cs),
           write_changed(S, R1, R2, P, Q1, Q2, L, Parts)),
    format(S, "## The fields only in ~w~n~n", [R2]),
    forall(member(c(row(P, _, Q2, L), new, _), Cs),
           ( atomic_list_concat(P, '.', PT), format(S, "- **~w** (`~w`), rule `~w`~n", [L, PT, Q2]) )),
    format(S, "~n## The fields only in ~w~n~n", [R1]),
    forall(member(only(P, L), Only1),
           ( atomic_list_concat(P, '.', PT), format(S, "- **~w** (`~w`)~n", [L, PT]) )),
    format(S, "~n## The fields computed the same~n~n| Field | ~w | ~w | Cited, ~w | Cited, ~w |~n|---|---|---|---|---|~n", [R1, R2, R1, R2]),
    forall(( member(c(row(P, Q1, Q2, L), C, _), Cs), memberchk(C, [shared, same]) ),
           ( cites(1, P, C1), cites(2, P, C2), class_text(C, CT),
             ( C1 == C2 -> C2T = '(the same)' ; C2T = C2 ),
             format(S, "| ~w | `~w` | ~w | ~w | ~w |~n", [L, Q1, CT, C1, C2T]) )).

class_text(shared, 'shared').
class_text(same, 'the same, in a rule of its own').
class_text(changed, 'changed').
class_text(new, 'new').

write_changed(S, R1, R2, P, Q1, Q2, L, Parts) :-
    atomic_list_concat(P, '.', PT),
    format(S, "### ~w (`~w`)~n~n", [L, PT]),
    cites(1, P, C1), cites(2, P, C2),
    format(S, "- ~w: `~w`, citing ~w~n- ~w: `~w`, citing ~w~n", [R1, Q1, C1, R2, Q2, C2]),
    forall(member(D1-D2, Parts),
           ( def_text(D1, T1), def_text(D2, T2),
             D1 =.. [_, N1], D2 =.. [_, N2],
             format(S, "~n`~w`:~n~n```~n~w~n```~n~n`~w`:~n~n```~n~w~n```~n", [N1, T1, N2, T2]) )),
    nl(S).

def_text(rule(Q), T) :- rune_model:rune_rule(_, Q, _, W, _, _), rune_expression(W, T, _), !.
def_text(func(Q), T) :-
    rune_model:rune_func(Q, _, _, Steps, _, _, _),
    findall(X, ( member(St, Steps), St =.. [K, Path, W], rune_expression(W, E, _),
                 atomic_list_concat(Path, ' -> ', PT), format(atom(X), '~w ~w: ~w', [K, PT, E]) ), Xs),
    atomic_list_concat(Xs, '\n', T), !.
def_text(_, '(not found)').

%   The passages a field cites in a report: the regulation's (not the
%   industry's readings), as source, data element and field name.
cites(K, P, T) :-
    field_docs(K, P, Ds), Ds \== [],
    findall(X, ( member(D, Ds), is_dict(D), get_dict(source, D, Src), \+ sub_atom(Src, 0, _, _, 'ISDA'),
                 ( get_dict(dataElement, D, E) -> format(atom(X), '~w, data element ~w', [Src, E]) ; X = Src ) ), Xs0),
    sort(Xs0, Xs), Xs \== [], !,
    atomic_list_concat(Xs, '; ', T).
cites(_, _, '—').

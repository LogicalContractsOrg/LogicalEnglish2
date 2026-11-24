/** <module> Generated cases, for a model whose collection has no tests

    The bruidsschat has no expected results (the design notes roadmap.md,
    Phase 4): its cases are generated here and answered by the oracle
    (dmn_oracle.pl). For each row of each decision table whose columns read
    inputs, one case in which that row's cells hold, its other inputs
    chosen by a fixed pseudo-random sequence; at most max_cases/1 cases per
    model, the rows taken evenly; in every second case only the inputs the
    row reads are given, the others left null. An input's candidate values are the
    literals its cells mention (a text inside `contains(?, "…")` too), the
    other truth value, and for a number the bounds of its comparisons and
    one either side (a number no cell mentions: a few fixed values). An input whose value the model fixes (STTR's vaste
    waarde) has that value. The decisions asked are the model's last ones:
    those no other decision requires.

        generated_cases(+Model, -Cases)   Cases = [case(Id, Desc, Inputs, Decisions)]
*/

:- module(dmn_cases, [generated_cases/2, sink_decisions/2, max_cases/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(dmn_reader).
:- use_module(feel_parser).

max_cases(24).

generated_cases(Model0, Cases) :-
    with_free_inputs(Model0, Model),
    Model = model(_, Items),
    findall(N-T-Meta, member(input(_, N, T, Meta), Items), Ins),
    Ins \== [], !,
    model_names(Model, Names),
    findall(Col-Text, column_cell(Model, Names, Col, Text), ColCells),
    maplist(input_candidates(ColCells, Names), Ins, Cands),
    findall(Row, table_row(Model, Names, Row), Rows),
    max_cases(Max),
    length(Rows, NR),
    (   NR =< Max -> Picked = Rows
    ;   Step is NR / Max, findall(R, ( between(0, Max, K), K < Max, I is floor(K * Step) + 1, nth1(I, Rows, R) ), Picked)
    ),
    sink_decisions(Model, Sinks),
    length(Picked, NP), NC is max(NP, 2),
    findall(case(Id, Desc, Inputs, Sinks),
            ( between(1, NC, K),
              format(atom(Id), 'g~|~`0t~d~3+', [K]),
              ( nth1(K, Picked, Row) -> format(atom(Desc), 'row ~w', [Row.desc]) ; Row = _{cells: []}, Desc = 'pseudo-random values' ),
              maplist(case_value(K, Row.cells), Ins, Cands, Inputs0),
              exclude([_-skip]>>true, Inputs0, Inputs) ),
            Cases).
generated_cases(_, []).

%   A table column may read a name that the model does not declare: a
%   variable of the process that runs the model (Camunda's style, the twin's
%   too). Such a name is an input of the cases, of the column's type. The
%   name of a table's output is not: it is that decision's value.
with_free_inputs(model(I, Items), model(I, Items1)) :-
    model_names(model(I, Items), Names0),
    findall(O, ( member(decision(_, _, _, _, table(_, _, _, Outs, _), _), Items), member(out(O, _, _, _), Outs), O \== '' ), Os),
    append(Names0, Os, Names),
    findall(input(free(N), N, TR, []),
            ( member(decision(_, _, _, _, table(_, _, Cols, _, _), _), Items),
              member(in(X, TR, _), Cols),
              catch(feel_parse(X, Names, name(N)), _, fail),
              \+ memberchk(N, Names) ),
            Free0),
    sort(2, @<, Free0, Free),
    append(Items, Free, Items1).

model_names(model(_, Items), Names) :-
    findall(N, ( member(I, Items), ( I = input(_, N, _, _) ; I = decision(_, N, _, _, _, _) ; I = bkm(_, N, _, _, _) ) ), Ns),
    sort(Ns, Names).

%   The cells of every input column whose expression is an input's name.
column_cell(model(_, Items), Names, Input, Text) :-
    member(decision(_, _, _, _, table(_, _, Ins, _, Rules), _), Items),
    nth1(I, Ins, in(X, _, _)),
    feel_parse(X, Names, name(Input)),
    memberchk(input(_, Input, _, _), Items),
    member(rule(_, IT, _, _), Rules), nth1(I, IT, Text).

input_candidates(ColCells, Names, N-T-Meta, cands(Fixed, Vs)) :-
    (   memberchk(fixed(F0), Meta) -> fixed_value(F0, T, Fixed) ; Fixed = none ),
    findall(V, ( member(N-Text, ColCells), feel_unary(Text, Names, Tests), test_literal(Tests, V) ), Vs0),
    type_class(T, Meta, Class),
    extend(Class, Vs0, Vs1),
    list_to_ord_set(Vs1, Vs2), predsort(by_text, Vs2, Vs).

by_text(O, A, B) :- format(string(SA), "~q", [A]), format(string(SB), "~q", [B]), compare(O0, SA, SB), ( O0 == (=) -> O = (=) ; O = O0 ).

fixed_value(V0, T, V) :-
    (   memberchk(V0, [true, 'TRUE']) -> V = v(true)
    ;   memberchk(V0, [false, 'FALSE']) -> V = v(false)
    ;   atom_number(V0, N) -> V = v(N)
    ;   T == 'feel:boolean' -> ( downcase_atom(V0, true) -> V = v(true) ; V = v(false) )
    ;   atom_string(V0, S), V = v(S)
    ).

type_class(T, Meta, C) :-
    (   sub_atom(T, _, _, _, boolean) -> C = boolean
    ;   memberchk(datatype(boolean), Meta) -> C = boolean
    ;   sub_atom(T, _, _, _, number) -> C = number
    ;   member(N, [double, integer, int, long, decimal, float]), sub_atom(T, _, _, 0, N) -> C = number
    ;   sub_atom(T, _, _, _, string) -> C = string
    ;   C = other
    ).

extend(boolean, _, [v(true), v(false)]) :- !.
extend(number, Vs0, Vs) :-
    \+ ( member(v(N), Vs0), number(N) ), !,
    Vs = [v(0), v(1), v(2.5), v(12), v(100)].
extend(number, Vs0, Vs) :- !,
    findall(v(X), ( member(v(N), Vs0), number(N), ( X = N ; X is N + 1 ; X is N - 1 ) ), Vs1),
    append(Vs1, [v(0)], Vs).
extend(string, Vs0, Vs) :- !,
    include([v(S)]>>string(S), Vs0, Vs1), append(Vs1, [v("anders")], Vs).
extend(_, Vs, Vs).

%   A literal a cell's tests mention.
test_literal(Tests, v(V)) :-
    sub_term(S, Tests), nonvar(S),
    (   S = str(V) ; S = num(R), V = R ; S = bool(V) ).

%   A row of a table, with its cells on input columns.
table_row(model(_, Items), Names, _{desc: Desc, cells: Cells}) :-
    member(decision(_, DN, _, _, table(_, _, Ins, _, Rules), _), Items),
    nth1(RI, Rules, rule(_, IT, _, _)),
    findall(Input-Text, ( nth1(I, Ins, in(X, _, _)), feel_parse(X, Names, name(Input)),
                          memberchk(input(_, Input, _, _), Items), nth1(I, IT, Text) ), Cells),
    Cells \== [],
    format(atom(Desc), '~d of ~w', [RI, DN]).

%   An input's value in case K: fixed; else one meeting the row's cell;
%   else the K-th of a pseudo-random walk over its candidates.
case_value(_, _, N-_-_, cands(Fixed, _), N-Fixed) :- Fixed \== none, !.
case_value(_, _, N-_-_, cands(none, []), N-skip) :- !.
%   Every second case answers only the questions its row reads: the others
%   stay unanswered (null), as most questions do in the Omgevingsloket.
case_value(K, Cells, N-_-_, _, N-skip) :- K mod 2 =:= 0, Cells \== [], \+ memberchk(N-_, Cells), !.
case_value(K, Cells, N-_-_, cands(none, Vs), N-V) :-
    (   memberchk(N-Text, Cells), Text \== '-',
        feel_unary(Text, [N], Tests), member(V, Vs), meets(Tests, V)
    ->  true
    ;   length(Vs, L), term_hash(N-K, H), I is H mod L + 1, nth1(I, Vs, V)
    ).

		 /*******************************
		 *     A SMALL TEST EVALUATOR   *
		 *******************************/

meets(any, _) :- !.
meets(not(Ts), V) :- !, \+ meets(Ts, V).
meets(Ts, V) :- member(test(T), Ts), test_meets(T, V), !.

test_meets(eq(null), null) :- !.
test_meets(eq(E), v(X)) :- !, lit(E, X).
test_meets(cmp(Op, E), v(X)) :- !, number(X), lit(E, Y), number(Y), cmp(Op, X, Y).
test_meets(range(LI, A, B, HI), v(X)) :- !, number(X), lit(A, L), lit(B, H),
    ( LI == true -> X >= L ; X > L ), ( HI == true -> X =< H ; X < H ).
test_meets(expr(E), V) :- ev(E, V, bool(true)).

lit(num(R), R). lit(str(S), S). lit(bool(B), B). lit(neg(num(R)), N) :- N is -R.

cmp('<', X, Y) :- X < Y.  cmp('<=', X, Y) :- X =< Y.  cmp('>', X, Y) :- X > Y.
cmp('>=', X, Y) :- X >= Y. cmp('=', X, Y) :- X =:= Y. cmp('!=', X, Y) :- X =\= Y.

%   FEEL over `?` = V, enough for STTR's cells: if/then/else, = null,
%   contains, not, and, or.
ev(q, V, V0) :- !, ( V = v(X) -> lit_v(X, V0) ; V0 = null ).
ev(null, _, null) :- !.
ev(bool(B), _, bool(B)) :- !.
ev(str(S), _, str(S)) :- !.
ev(num(N), _, num(N)) :- !.
ev(if(C, T, E), V, R) :- !, ( ev(C, V, bool(true)) -> ev(T, V, R) ; ev(E, V, R) ).
ev(cmp('=', A, B), V, bool(R)) :- !, ev(A, V, X), ev(B, V, Y), ( X == Y -> R = true ; R = false ).
ev(cmp('!=', A, B), V, bool(R)) :- !, ev(A, V, X), ev(B, V, Y), ( X == Y -> R = false ; R = true ).
ev(call(name(contains), [pos(A), pos(B)]), V, bool(R)) :- !,
    ev(A, V, X), ev(B, V, Y),
    ( X = str(S), Y = str(P) -> ( sub_string(S, _, _, _, P) -> R = true ; R = false ) ; fail ).
ev(call(name(not), [pos(A)]), V, bool(R)) :- !, ev(A, V, bool(X)), ( X == true -> R = false ; R = true ).
ev(and(A, B), V, bool(R)) :- !, ( ev(A, V, bool(true)), ev(B, V, bool(true)) -> R = true ; R = false ).
ev(or(A, B), V, bool(R)) :- !, ( ( ev(A, V, bool(true)) ; ev(B, V, bool(true)) ) -> R = true ; R = false ).

lit_v(X, str(X)) :- string(X), !.
lit_v(X, bool(X)) :- memberchk(X, [true, false]), !.
lit_v(X, num(X)).

		 /*******************************
		 *        LAST DECISIONS        *
		 *******************************/

%!  sink_decisions(+Model, -Names) is det.
sink_decisions(model(_, Items), Names) :-
    findall(Id, ( member(decision(_, _, _, reqs(Ds, _, _), _, _), Items), member(H, Ds), dmn_href_id(H, Id) ), Req0),
    sort(Req0, Req),
    findall(N, ( member(decision(Id, N, _, _, _, _), Items), \+ ord_memberchk(Id, Req) ), Names).

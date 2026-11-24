/** <module> The sheet as its own oracle: scenarios with the values it computes

    the design notes Excel.md §7.2, step 4. Every scenario's expected answers
    are values the workbook itself computed:

      - **as saved**: the inputs as the file holds them, and the values Excel
        saved for the outputs — computed by Excel itself;
      - **generated cases**: inputs chosen around the thresholds the formulas
        and tables test (just below, on, just above) and at random, each case
        evaluated by LE2's sheet engine (Formualizer), the same evaluation the
        `sheet:` services address uses.

    An output the sheet shows as an error (#N/A, #VALUE!, ...) has no correct
    value, so it is not expected; the scenario says so in a comment. The
    cases are drawn from a fixed seed: an import is reproducible.
*/

:- module(xlsx_tests, [workbook_tests/4]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(yall)).
:- use_module(library(option)).
:- use_module(library(random)).
:- use_module(xlsx_ir).
:- use_module(library(pairs)).
:- use_module(library(ordsets)).

%!  workbook_tests(+File, +Info, +Options, -Tests) is det.
%
%   Options: cases(N) (default 12) generated cases, seed(S) (default 2026).
workbook_tests(File, info(Inputs, Outputs, QNames), Options, Tests) :-
    file_base_name(File, Doc),
    saved_test(Doc, Inputs, Outputs, QNames, Saved),
    option(cases(N), Options, 12),
    option(seed(Seed), Options, 2026),
    (   N > 0, Inputs \== [], Outputs \== []
    ->  set_random(seed(Seed)),
        findall(Case, ( between(1, N, I), once(draw_case(I, Inputs, Case)) ), Cases0),
        sort(Cases0, Cases1),          % the same draw twice is one case
        oracle(File, Cases1, Outputs, Results),
        option(expect_errors(EE), Options, false),
        findall(T, ( member(case(Id, Vals)-Res, Results), generated_test(Doc, Id, Inputs, Vals, Res, Outputs, QNames, EE, T) ), Gen)
    ;   Gen = []
    ),
    option(examples(Exs), Options, []),
    findall(T, ( member(Ex, Exs), example_test(Ex, Inputs, Outputs, QNames, T) ), ExTests),
    append([[Saved], ExTests, Gen], Tests).

		 /*******************************
		 *     PUBLISHED EXAMPLES       *
		 *******************************/

%   A workbook of the same layout filled in by its publisher (CBAM's seven
%   sector examples): its inputs are the scenario's facts, and the values
%   Excel saved in it are the expected answers.
example_test(File, Inputs, Outputs, QNames, test(Name, Doc, 'a filled example workbook', Facts, Expects)) :-
    file_base_name(File, Doc), file_name_extension(Stem, _, Doc),
    atom_codes(Stem, Cs0), maplist([C0, C]>>( code_type(C0, alnum) -> C = C0 ; C = 0'_ ), Cs0, Cs),
    atom_codes(N0, Cs), downcase_atom(N0, N1), atom_concat(example_, N1, Name),
    xlsx_ir:run_front(read, File, none, D),
    retractall(ex_cell(_, _, _, _)),
    forall(( member(Sh, D.sheets), atom_string(S, Sh.name), member(C, Sh.cells) ),
           ( xlsx_ir:json_cell_value(C.value, V0), atom_string(T, C.type),
             ( T == error -> V = error(V0) ; V = V0 ), assertz(ex_cell(S, C.row, C.col, V)) )),
    findall(F, ( member(Cell, Inputs), \+ rowish(Cell), ex_value(Cell, V0), input_value(Cell, V0, V),
                 cell_functor(Cell, Fn), F =.. [Fn, V] ), Facts0),
    findall(F, ( member(Cell, Inputs), rowish(Cell), copied_rows_of(Cell, Rs), member(R, Rs), row_cell(Cell, R, RC),
                 ex_value(RC, V0), V0 \== blank, input_value(Cell, V0, V), row_atom(R, RA),
                 cell_functor(Cell, Fn), F =.. [Fn, RA, V] ), Facts1),
    append(Facts0, Facts1, Facts),
    findall(E, ( member(Cell, Outputs), \+ rowish(Cell), ex_value(Cell, V), ex_plain(V, V1), expectation(Cell, V1, QNames, E) ), Expects).

:- thread_local ex_cell/4.
ex_value(cell(S, R, C), V) :- ( ex_cell(S, R, C, V0) -> V = V0 ; V = blank ).
ex_plain(V, _) :- ( V == blank ; V = error(_) ), !, fail.
ex_plain(V, V).

		 /*******************************
		 *        THE SAVED CASE        *
		 *******************************/

saved_test(Doc, Inputs, Outputs, QNames, test(as_saved, Doc, 'the values saved in the file', Facts, Expects)) :-
    findall(F, ( member(Cell, Inputs), \+ rowish(Cell), saved_input_fact(Cell, F) ), Facts0),
    findall(F, ( member(Cell, Inputs), rowish(Cell), saved_rows_for(Inputs, Cell, Rows), member(R, Rows), row_cell(Cell, R, RC),
                 cell_value_saved(RC, V0), input_value(Cell, V0, V), row_atom(R, RA),
                 cell_functor(Cell, Fn), F =.. [Fn, RA, V] ), Facts1),
    append(Facts0, Facts1, Facts),
    findall(E, ( member(Cell, Outputs), \+ rowish(Cell), saved_value(Cell, V), expectation(Cell, V, QNames, E) ), Expects0a),
    findall(expects(Q, Ls), ( member(Cell, Outputs), rowish(Cell), saved_rows_for(Inputs, Cell, Rows), Rows \== [],
                              memberchk(Cell-Q, QNames), cell_functor(Cell, Fn),
                              findall(L, ( member(R, Rows), row_cell(Cell, R, RC), saved_value(RC, V), row_atom(R, RA), L =.. [Fn, RA, V] ), Ls) ),
            Expects0b),
    append(Expects0a, Expects0b, Expects0),
    findall(comment(C), ( member(Cell, Outputs), saved_error(Cell, Err), error_comment(Cell, Err, C) ), Cms),
    append(Expects0, Cms, Expects).

%   The rows of a column of copied rows a scenario fills: all of them when
%   there are at most 30 (the lines of one form), else, for a generated case,
%   the first three, and for the saved case those where the file gives an
%   input.
rows_for(Cell, Rows) :-
    copied_rows_of(Cell, Rs), length(Rs, N),
    (   N =< 30 -> Rows = Rs
    ;   length(Rows, 3), append(Rows, _, Rs)
    ).

saved_rows_for(Inputs, Cell, Rows) :-
    copied_rows_of(Cell, Rs), length(Rs, N),
    (   N =< 30 -> Rows = Rs
    ;   findall(R, ( member(I, Inputs), rowish(I), copied_rows_of(I, IRs), member(R, IRs), memberchk(R, Rs),
                     row_cell(I, R, RC), cell_value_saved(RC, V), V \== blank ), Rows0),
        sort(Rows0, Rows)
    ).

row_cell(cell(S, _, C), R, cell(S, R, C)).

saved_input_fact(Cell, L) :-
    cell_value_saved(Cell, V0),
    input_value(Cell, V0, V),
    cell_functor(Cell, F), L =.. [F, V].

cell_value_saved(cell(S, R, C), V) :-
    (   xlsx_ir:wcell(S, R, C, _, V0, _, _, _) -> V = V0 ; V = blank ).

%   An input left empty is 0 where the formulas compute with it, and the
%   empty text where they compare it with text (as Excel reads an empty cell).
input_value(Cell, blank, V) :- !,
    (   xlsx_ir:input_type(Cell, text) -> V = "" ; V = 0 ).
input_value(_, error(_), 0) :- !.
input_value(Cell, V0, D) :- xlsx_ir:input_type(Cell, date), number(V0), !, serial_date(V0, D).
input_value(Cell, V0, V) :-
    (   xlsx_ir:input_type(Cell, number), string(V0), number_string(N, V0) -> V = N
    ;   V0 == true -> V = true
    ;   V0 == false -> V = false
    ;   V = V0
    ).

saved_value(cell(S, R, C), V) :-
    xlsx_ir:wcell(S, R, C, T, V0, _, _, _),
    memberchk(T, [number, text, boolean]),
    ( T == boolean -> ( V0 == true -> V = true ; V = false ) ; V = V0 ).

saved_error(cell(S, R, C), E) :-
    xlsx_ir:wcell(S, R, C, error, error(E), _, _, _).

expectation(Cell, V0, QNames, expects(Q, [L])) :-
    memberchk(Cell-Q, QNames),
    out_value(Cell, V0, V),
    cell_functor(Cell, F), L =.. [F, V].

%   An output the workbook shows as a date: Excel's day number as LE's date.
out_value(cell(S, R, C), V0, V) :-
    (   number(V0), xlsx_ir:ast_type(ref(S, R, C, R, C), date) -> serial_date(V0, V) ; V = V0 ).

error_comment(Cell, Err, C) :-
    cell_ref_text(Cell, Ref),
    format(string(C), "The sheet shows ~w in ~w here: no value to expect.", [Err, Ref]).

		 /*******************************
		 *       GENERATED CASES        *
		 *******************************/

%   A case: a value for every input. Half of the time an input takes one of
%   its notable values (a threshold the formulas test, a key of a table it
%   is looked up in, its value as saved), otherwise a value at random.
draw_case(I, Inputs, case(Id, Vals)) :-
    format(atom(Id), 'case_~|~`0t~w~2|', [I]),
    maplist(draw_input, Inputs, Vals).

draw_input(Cell, V) :-
    (   rowish(Cell) -> rows_for(Cell, Rows), findall(R-X, ( member(R, Rows), draw_value(Cell, X) ), V)
    ;   draw_value(Cell, V)
    ).

draw_value(Cell, V) :-
    candidates(Cell, Notable, Random),
    (   Notable \== [], ( Random == none ; maybe(0.5) )
    ->  random_member(V, Notable)
    ;   Random = range(Lo, Hi)
    ->  random_between(Lo, Hi, V)
    ;   Random = frange(Lo, Hi)
    ->  random(F), V is round((Lo + F * (Hi - Lo)) * 100) / 100
    ;   V = ""
    ).

:- thread_local cand_memo/3.

candidates(Cell, Notable, Random) :-
    (   cand_memo(Cell, Notable, Random) -> true
    ;   candidates_(Cell, Notable, Random), assertz(cand_memo(Cell, Notable, Random))
    ).

candidates_(Cell, Notable, none) :-
    Cell = cell(S, R, C),
    xlsx_ir:wvalid(S, R, C, Vals), is_list(Vals), !,
    (   xlsx_ir:input_type(Cell, number)
    ->  maplist([X, N]>>( number_string(N, X) -> true ; N = X ), Vals, Notable)
    ;   Notable = Vals
    ).
candidates_(Cell, Notable, none) :-
    xlsx_ir:input_type(Cell, text), !,
    findall(T, compared_text(Cell, T), Ts0),
    cell_value_saved(Cell, V0), ( string(V0) -> Ts1 = [V0|Ts0] ; Ts1 = Ts0 ),
    sort(Ts1, Ts),
    ( Ts == [] -> Notable = [""] ; Notable = Ts ).
candidates_(Cell, Notable, range(Lo, Hi)) :-
    xlsx_ir:input_type(Cell, date), !,              % within a year or so of the date as saved
    cell_value_saved(Cell, V0), ( number(V0) -> Base = V0 ; Base = 46023 ),
    Lo is integer(Base) - 400, Hi is integer(Base) + 400, Notable = [Base].
candidates_(Cell, Notable, Random) :- candidates_number(Cell, Notable, Random).

%   A percentage (a cell formatted %): drawn between 0 and 100%.
candidates_number(Cell, Notable, frange(0.0, 1.0)) :-
    Cell = cell(S, R, C), xlsx_ir:wcell(S, R, C, _, _, _, _, Fm), sub_string(Fm, _, _, _, "%"), !,
    findall(N, ( threshold(Cell, N), N >= 0, N =< 1 ), Ns0),
    cell_value_saved(Cell, V0), ( number(V0) -> Ns = [V0|Ns0] ; Ns = Ns0 ),
    sort([0|Ns], Notable).
%   A count: an input whose thresholds are all small whole numbers (MIN(n,3),
%   a CHOOSE index, a key of 1 to 8) is drawn among small whole numbers.
candidates_number(Cell, Notable, range(0, Hi)) :-
    findall(N, threshold(Cell, N), Ns), Ns \== [],
    forall(member(N, Ns), ( integer(N), N >= 0, N =< 20 )),
    max_list(Ns, M), M >= 2, !,                % (an amount tested against 0 only is not a count)
    Hi is 2 * M + 2,
    findall(X, ( member(N, Ns), member(D, [-1, 0, 1]), X is N + D, X >= 0 ), Xs), sort([0|Xs], Notable).
candidates_number(Cell, Notable, range(0, Hi)) :-
    findall(N, threshold(Cell, N), Ns0),
    cell_value_saved(Cell, V0), ( number(V0) -> Ns1 = [V0|Ns0] ; Ns1 = Ns0 ),
    findall(X, ( member(N, Ns1), member(D, [-1, 0, 1]), X0 is N + D, X0 >= 0, X = X0 ), Xs0),
    sort([0|Xs0], Notable),
    sheet_scale(Scale),
    (   findall(K, key_threshold(Cell, K), Ks), Ks \== []
    ->  max_list(Ks, MK), Hi is ceiling(MK) + 2      % a key of a table: a count, a code
    ;   Ns1 == [] -> Hi = Scale
    ;   max_list(Ns1, M), Hi is max(Scale, ceiling(2 * M))
    ).

%   The size of the numbers the workbook works with: the largest number its
%   formulas read from a parameter or a table (at least 1,000, at most a
%   million), the range random amounts are drawn from.
sheet_scale(Scale) :-
    findall(N, ( xlsx_ir:role(cell(S, R, C), param), xlsx_ir:wcell(S, R, C, number, N, _, _, _) ), Ns1),
    findall(N, ( xlsx_ir:table_def(_, _, _, _, Rows, _), member(Row, Rows), last(Row, N), number(N) ), Ns2),
    append(Ns1, Ns2, Ns),
    (   Ns == [] -> Scale = 1000
    ;   max_list(Ns, M), Scale is integer(max(1000, min(1000000, M)))
    ).

%   The numbers a formula compares the input with, directly or through a
%   formula cell that is the input plus or times something, and the keys of
%   the tables it is looked up in.
threshold(Cell, N) :-
    index_thresholds,
    near_input(Cell, Near),
    (   num_compared(C, N), ord_memberchk(C, Near)
    ;   key_threshold(Cell, N)
    ).

threshold_key(Cell, N) :-
    index_thresholds,
    near_input(Cell, Near),
    key_looked_up(C, N), ord_memberchk(C, Near).

key_threshold(Cell, N) :- threshold_key(Cell, N).

%   One pass over the formulas: the numbers each cell is compared with, and
%   the keys of the tables each cell is looked up in.
:- thread_local num_compared/2, key_looked_up/2, thresholds_indexed/0.
index_thresholds :- thresholds_indexed, !.
index_thresholds :-
    forall(( xlsx_ir:wformula(_, _, _, _, AST), xlsx_ir:sub_ast(bin(Op, A, B), AST), xlsx_ir:comparison(Op, _),
             ( A = ref(S, R, C, R, C), B = num(N) ; B = ref(S, R, C, R, C), A = num(N) ) ),
           ( num_compared(cell(S, R, C), N) -> true ; assertz(num_compared(cell(S, R, C), N)) )),
    %  MIN(n, 3), MAX(n, 0): the literal bounds n; CHOOSE(i, ...): 1 to the number of choices
    forall(( xlsx_ir:wformula(_, _, _, _, AST), xlsx_ir:sub_ast(fn(F, As), AST),
             (   memberchk(F, ['MIN', 'MAX']), member(ref(S, R, C, R, C), As), member(num(N), As)
             ;   F == 'CHOOSE', As = [I|Cs], length(Cs, NC), xlsx_ir:sub_ast(ref(S, R, C, R, C), I), between(1, NC, N)
             ) ),
           ( num_compared(cell(S, R, C), N) -> true ; assertz(num_compared(cell(S, R, C), N)) )),
    forall(( xlsx_ir:wformula(_, _, _, _, AST), xlsx_ir:sub_ast(fn(F, As), AST),
             xlsx_ir:lookup_function(F, As, ref(S, R, C, R, C), _, _),
             xlsx_ir:table_def(_, _, key(TS, R1, C1, R2, C2, Spec), _, Rows, _),
             lookup_key_matches(F, As, TS, R1, C1, R2, C2, Spec),
             member([K|_], Rows), key_number(K, N) ),
           ( key_looked_up(cell(S, R, C), N) -> true ; assertz(key_looked_up(cell(S, R, C), N)) )),
    assertz(thresholds_indexed).

lookup_key_matches(F, As, S, R1, C1, R2, C2, Spec) :-
    xlsx_ir:lookup_function(F, As, _, ref(S, R1, C1, R2, C2), Spec0), !,
    ( Spec0 = spec(by_column(_), A, B, M) -> Spec = spec(by_column, A, B, M) ; Spec = Spec0 ).

key_number(cond((>=)-N), N) :- number(N), !.
key_number(cond(and((>=)-N, _)), N) :- number(N), !.
key_number(N, N) :- number(N).

%   The input and the cells that read it, a few steps away (=B18,
%   =SUM(C18:C19), =B19*4.333): the cells a threshold compared with says
%   something about the input. Breadth first, at most four steps, once per
%   input.
:- thread_local near_memo/2.

near_input(Input, Near) :-
    (   near_memo(Input, Near) -> true
    ;   near_steps(4, [Input], [Input], Near0), sort(Near0, Near),
        assertz(near_memo(Input, Near))
    ).

near_steps(0, _, Seen, Seen) :- !.
near_steps(_, [], Seen, Seen) :- !.
near_steps(K, Frontier, Seen, Near) :-
    findall(R, ( member(C, Frontier), xlsx_ir:reads(R, C) ), Rs0), sort(Rs0, Rs),
    sort(Seen, SeenS), ord_subtract(Rs, SeenS, New),
    append(Seen, New, Seen1), K1 is K - 1,
    near_steps(K1, New, Seen1, Near).

compared_text(Cell, T) :- xlsx_ir:text_compared(Cell, T).

		 /*******************************
		 *          THE ORACLE          *
		 *******************************/

%   The workbook evaluated on each case by the front end (LE2's sheet
%   engine): Results = [case(Id, Vals)-Values], Values a dict of the outputs.
oracle(_, [], _, []) :- !.
oracle(File, Cases, Outputs, Results) :-
    Cases = [case(_, _)|_],
    xlsx_ir:input_cells(Inputs),
    findall(R-Cell1, ( member(Cell, Outputs), out_cell(Cell, Cell1), cell_ref_text(Cell1, R0), quote_ref(R0, R) ), OPairs),
    pairs_keys(OPairs, ORefs),
    findall(_{id: Id, inputs: D},
            ( member(case(Id, Vals), Cases), case_inputs(Inputs, Vals, Ps), dict_pairs(D, _, Ps) ),
            JCases),
    xlsx_ir:run_front(eval, File, _{outputs: ORefs, cases: JCases}, Res),
    findall(case(Id, Vals)-Values,
            ( member(case(Id, Vals), Cases), member(R, Res), atom_string(Id, R.id),
              dict_pairs(R.values, _, VPs),
              findall(C1-V, ( member(K-V, VPs), atom_string(K, KS), member(Ref-C1, OPairs), atom_string(Ref, KS) ), Values) ),
            Results).

%   The cells an output stands for: itself, or the same column in each filled row.
out_cell(Cell, C1) :-
    (   rowish(Cell) -> rows_for(Cell, Rows), member(R, Rows), row_cell(Cell, R, C1) ; C1 = Cell ).

case_inputs(Inputs, Vals, Ps) :-
    findall(Ref-V, ( nth1(I, Inputs, Cell), nth1(I, Vals, V0),
                     (   rowish(Cell) -> member(R-V, V0), row_cell(Cell, R, C1) ; C1 = Cell, V = V0 ),
                     cell_ref_text(C1, R0), quote_ref(R0, Ref) ), Ps).

quote_ref(R0, R) :-
    atomic_list_concat(Ps, '!', R0), append(SPs, [Cell], Ps),
    atomic_list_concat(SPs, '!', S), atomic_list_concat(Qs, '''', S), atomic_list_concat(Qs, '''''', SQ),
    format(atom(R), '''~w''!~w', [SQ, Cell]).


generated_test(Doc, Id, Inputs, Vals, Values, Outputs, QNames, EE, test(Id, Doc, Loc, Facts, Expects)) :-
    format(atom(Loc), 'a case the sheet computed (~w)', [Id]),
    findall(L, ( nth1(I, Inputs, Cell), nth1(I, Vals, V0), cell_functor(Cell, F),
                 (   rowish(Cell) -> member(R-V1, V0), drawn_fact(Cell, V1, V), row_atom(R, RA), L =.. [F, RA, V]
                 ;   drawn_fact(Cell, V0, V), L =.. [F, V] ) ), Facts),
    findall(E, ( member(Cell, Outputs), \+ rowish(Cell), memberchk(Cell-V0, Values), oracle_value(V0, V), expectation(Cell, V, QNames, E) ), Expects0a),
    findall(expects(Q, Ls), ( member(Cell, Outputs), rowish(Cell), memberchk(Cell-Q, QNames), cell_functor(Cell, F),
                              rows_for(Cell, Rows),
                              findall(L, ( member(R, Rows), row_cell(Cell, R, C1), memberchk(C1-V0, Values),
                                           oracle_value(V0, V), row_atom(R, RA), L =.. [F, RA, V] ), Ls) ), Expects0b),
    append(Expects0a, Expects0b, Expects0),
    (   EE == true      % a diagnosis: where the sheet shows an error, LE should answer nothing
    ->  findall(expects(Q, []), ( member(Cell, Outputs), \+ rowish(Cell), memberchk(Cell-V0, Values), is_dict(V0), memberchk(Cell-Q, QNames) ), Cms)
    ;   findall(comment(C), ( member(Cell, Outputs), memberchk(Cell-V0, Values), is_dict(V0), get_dict(error, V0, Err),
                              error_comment(Cell, Err, C) ), Cms)
    ),
    append(Expects0, Cms, Expects).

%   A value drawn for an input, as the scenario states it (a date input is
%   drawn as Excel's day number, which the oracle is given).
drawn_fact(Cell, V0, V) :- ( xlsx_ir:input_type(Cell, date), number(V0) -> serial_date(V0, V) ; V = V0 ).

oracle_value(V, _) :- is_dict(V), !, fail.
oracle_value(null, "") :- !.
oracle_value(true, true) :- !.
oracle_value(false, false) :- !.
oracle_value(V, V) :- ( number(V) ; string(V) ), !.

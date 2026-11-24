/** <module> OIPA plan configuration read into the model the translator maps

    Phase 2b (the design notes roadmap.md §5.9, §8). A plan directory holds
    one directory per transaction — `Transaction.xml` (Fields and the Math
    section) and its attached rules `ValidateExpressions.xml`,
    `SpawnActivities.xml`, `CopyToPolicyFields.xml` — and the plan's
    `Rates.csv` (AsRate) and `PlanFields.csv` (AsPlanField). The forms are
    those of the OIPA XML Configuration Guide 9.7.

      transaction(Name, Fields, Math, Validations, Spawns, Copies)
        Fields      [field(Name, Display, DataType)]
        Math        [mv(Name, Type, DataType, Attrs, Value) | mathif(Cond, Math)
                     | block(Element, Label, Math, XML)]
                    Attrs: ROUND, DEFAULT, LOG, and '$xml'=XML (the element as
                    written, for a residue block); a block is an element of
                    the Math section the translator does not read (MathLoop):
                    its MathVariables inside, and its XML
                    Value: expr(E) (EXPRESSION, FUNCTION), field(Scope, Name)
                    (FIELD, POLICYFIELD, PLANFIELD), value(Text) (VALUE),
                    iif(Cond, First, Second), rate(Description, [Criterion-MV]),
                    unsupported(Type)
        Validations [check(Number, Type, Message, Cond)]
        Spawns      [spawn(Transaction, [Test])]
        Copies      [copy(FromMV, ToPolicyField)]

      E = num(N) | str(S) | bool(B) | ref(Name) | call(F, [E]) | E1 + E2 ...
        | and(E1, E2) | or(E1, E2) | not(E) | cmp(Op, E1, E2)
*/

:- module(oipa_reader, [read_plan/2, read_transaction/2, parse_oipa_expr/2,
                        mv_references/2, plan_rates/2, plan_fields/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(sgml)).
:- use_module(library(sgml_write)).
:- use_module(library(csv)).
:- use_module(library(dcg/basics)).

%!  read_plan(+Dir, -Plan) is det.
%   plan(Name, Transactions).
read_plan(Dir, plan(Name, Ts)) :-
    file_base_name(Dir, Name),
    directory_files(Dir, Es0), msort(Es0, Es),
    findall(T, ( member(E, Es), E \== '.', E \== '..',
                 atomic_list_concat([Dir, '/', E], TD), exists_directory(TD),
                 atomic_list_concat([TD, '/Transaction.xml'], TX), exists_file(TX),
                 read_transaction(TD, T) ), Ts).

%!  read_transaction(+Dir, -Transaction) is det.
read_transaction(Dir, transaction(Name, Fields, Math, Vs, Ss, Cs)) :-
    file_base_name(Dir, Name),
    atomic_list_concat([Dir, '/Transaction.xml'], TX),
    load_xml(TX, [Root|_], [space(remove)]),
    ( sub_el(Root, 'Fields', FE) -> findall(F, ( child(FE, 'Field', X), field_def(X, F) ), Fields) ; Fields = [] ),
    ( sub_el(Root, 'MathVariables', MVs) -> math_items(MVs, Math) ; Math = [] ),
    attached(Dir, 'ValidateExpressions.xml', R1), findall(V, ( member(X, R1), child(X, 'Expression', E), check(E, V) ), Vs),
    attached(Dir, 'SpawnActivities.xml', R2), findall(S, ( member(X, R2), child(X, 'Spawn', E), spawn(E, S) ), Ss),
    attached(Dir, 'CopyToPolicyFields.xml', R3), findall(C, ( member(X, R3), sub_el(X, 'Fields', FF), child(FF, 'Field', E), copy(E, C) ), Cs).

attached(Dir, File, Roots) :-
    atomic_list_concat([Dir, '/', File], P),
    (   exists_file(P) -> load_xml(P, Ds, [space(remove)]), include(is_el, Ds, Roots) ; Roots = [] ).

is_el(element(_, _, _)).
child(element(_, _, C), N, E) :- member(E, C), E = element(N, _, _).
sub_el(E, N, S) :- E = element(N, _, _), !, S = E.
sub_el(element(_, _, C), N, S) :- member(X, C), is_el(X), sub_el(X, N, S), !.
text(element(_, _, C), T) :- include(atomic, C, Ts), atomic_list_concat(Ts, ' ', T0), normalize_space(atom(T), T0).
attr(element(_, A, _), K, V) :- memberchk(K=V, A).
child_text(E, N, T) :- child(E, N, C), text(C, T).

field_def(E, field(N, D, T)) :-
    child_text(E, 'Name', N),
    ( child_text(E, 'Display', D) -> true ; D = N ),
    ( child_text(E, 'DataType', T) -> true ; T = 'Text' ).

math_items(E, Items) :-
    E = element(_, _, C),
    findall(I, ( member(X, C), is_el(X), math_item(X, I) ), Items).

math_item(element('MathIF', A, C), mathif(Cond, Items)) :- !,
    memberchk('IF'=IfT, A), parse_oipa_expr(IfT, Cond),
    math_items(element('MathIF', A, C), Items).
math_item(E, mv(Name, Type, DT, Attrs, Value)) :-
    E = element('MathVariable', A, _), !,
    memberchk('VARIABLENAME'=Name, A), memberchk('TYPE'=T0, A), upcase_atom(T0, Type),
    ( memberchk('DATATYPE'=DT0, A) -> normalize_space(atom(DT1), DT0), upcase_atom(DT1, DT) ; DT = 'TEXT' ),
    findall(K=V, ( member(K=V, A), memberchk(K, ['ROUND', 'DEFAULT', 'LOG']) ), Attrs0),
    xml_text(E, XML), append(Attrs0, ['$xml'=XML], Attrs),
    ( catch(mv_value(Type, E, Value), _, fail) -> true ; Value = unsupported(Type) ).
%   Any other element of the Math section (MathLoop, ...): not read, kept
%   whole with the MathVariables it sets.
math_item(E, block(El, Label, Items, XML)) :-
    E = element(El, A, _),
    (   member(K, ['VARIABLENAME', 'NAME', 'ID']), memberchk(K=Label, A) -> true ; Label = El ),
    math_items(E, Items),
    xml_text(E, XML).

xml_text(E, XML) :-
    with_output_to(string(XML), xml_write(current_output, E, [header(false)])).

mv_value(Type, E, expr(X)) :- memberchk(Type, ['EXPRESSION', 'FUNCTION']), !, text(E, T), parse_oipa_expr(T, X).
mv_value('FIELD', E, field(Scope, F)) :- !, text(E, T), atomic_list_concat([Scope, F], ':', T).
mv_value('POLICYFIELD', E, field('Policy', F)) :- !, text(E, F).
mv_value('PLANFIELD', E, field('Plan', F)) :- !, text(E, F).
mv_value('VALUE', E, value(T)) :- !, text(E, T).
mv_value('IIF', E, iif(Cond, First, Second)) :- !,
    attr(E, 'EXPRESSION', CT), parse_oipa_expr(CT, Cond),
    text(E, T), atomic_list_concat([F0, S0], ',', T),
    normalize_space(atom(First), F0), normalize_space(atom(Second), S0).
mv_value('RATE', E, rate(Desc, Crit)) :- !,
    sub_el(E, 'Parameters', P), child_text(P, 'RateDescription', Desc),
    findall(N-MV, ( child(P, 'RateCriteria', C), attr(C, 'NAME', N), text(C, MV) ), Crit).
mv_value(Type, _, unsupported(Type)).

check(E, check(Num, Type, Msg, Cond)) :-
    ( attr(E, 'ERRORNUMBER', Num) -> true ; Num = none ),
    ( attr(E, 'TYPE', Type) -> true ; Type = 'ErrorOnTrue' ),
    ( attr(E, 'MESSAGE', Msg) -> true ; Msg = '' ),
    text(E, T), parse_oipa_expr(T, Cond).

spawn(E, spawn(T, Tests)) :-
    child_text(E, 'Transaction', T),
    ( sub_el(E, 'Tests', TE) -> findall(X, ( child(TE, 'Test', TT), text(TT, S), parse_oipa_expr(S, X) ), Tests) ; Tests = [] ).

copy(E, copy(From, To)) :- child_text(E, 'From', From), child_text(E, 'To', To).

		 /*******************************
		 *         EXPRESSIONS          *
		 *******************************/

%!  parse_oipa_expr(+Text, -Expr) is det.
%   The guide's operators: Or < And < Not < comparisons < + - < * / % < ^.
parse_oipa_expr(T, E) :-
    atom_codes(T, Cs), phrase(tokens(Ts), Cs), phrase(or_e(E), Ts), !.
parse_oipa_expr(T, _) :- throw(error(format("cannot read the OIPA expression ~w", [T]), _)).

tokens([T|Ts]) --> blanks, token(T), !, tokens(Ts).
tokens([]) --> blanks.

token(num(N)) --> number_t(N).
token(str(S)) --> "'", string_without(`'`, Cs), "'", { atom_codes(S, Cs) }.
token(op(O)) --> ( "<>" -> { O = (\=) } ; "!=" -> { O = (\=) } ; "<=" -> { O = (=<) } ; ">=" -> { O = (>=) } ).
token(op(O)) --> [C], { memberchk(C-O, [0'+-(+), 0'--(-), 0'*-(*), 0'/-(/), 0'^-(^), 0'%-(mod),
                                         0'=-(=), 0'<-(<), 0'>-(>), 0'(-'(', 0')-')', 0',-',']) }.
token(T) --> csym_first(C), csyms_colon(Cs), { atom_codes(A, [C|Cs]), downcase_atom(A, L),
             ( memberchk(L, [and, or, not]) -> T = op(L) ; memberchk(L, [true, false]) -> T = bool(L) ; T = name(A) ) }.

number_t(N) --> digits(D1), { D1 \== [] }, ( ".", digits(D2) -> { append(D1, [0'.|D2], Ds) } ; { Ds = D1 } ), { number_codes(N, Ds) }.
csym_first(C) --> [C], { code_type(C, csymf) }.
csyms_colon([C|Cs]) --> [C], { code_type(C, csym) ; C == 0': }, !, csyms_colon(Cs).
csyms_colon([]) --> [].

or_e(E) --> and_e(A), or_rest(A, E).
or_rest(A, E) --> [op(or)], !, and_e(B), or_rest(or(A, B), E).
or_rest(E, E) --> [].
and_e(E) --> not_e(A), and_rest(A, E).
and_rest(A, E) --> [op(and)], !, not_e(B), and_rest(and(A, B), E).
and_rest(E, E) --> [].
not_e(not(E)) --> [op(not)], !, not_e(E).
not_e(E) --> cmp_e(E).
cmp_e(E) --> add_e(A), ( [op(O)], { memberchk(O, [=, \=, <, >, =<, >=]) } -> add_e(B), { E = cmp(O, A, B) } ; { E = A } ).
add_e(E) --> mul_e(A), add_rest(A, E).
add_rest(A, E) --> [op(O)], { memberchk(O, [+, -]) }, !, mul_e(B), { X =.. [O, A, B] }, add_rest(X, E).
add_rest(E, E) --> [].
mul_e(E) --> pow_e(A), mul_rest(A, E).
mul_rest(A, E) --> [op(O)], { memberchk(O, [*, /, mod]) }, !, pow_e(B), { X =.. [O, A, B] }, mul_rest(X, E).
mul_rest(E, E) --> [].
pow_e(E) --> un_e(A), ( [op(^)] -> pow_e(B), { E = A^B } ; { E = A } ).
un_e(-(E)) --> [op(-)], !, un_e(E).
un_e(E) --> prim(E).
prim(num(N)) --> [num(N)], !.
prim(str(S)) --> [str(S)], !.
prim(bool(B)) --> [bool(B)], !.
prim(E) --> [op('(')], !, or_e(E), [op(')')].
prim(call(F, Args)) --> [name(F)], [op('(')], !, args(Args), [op(')')].
prim(ref(N)) --> [name(N)].
args([A|As]) --> or_e(A), ( [op(',')] -> args(As) ; { As = [] } ).
args([]) --> [].

%!  mv_references(+Expr, -Names) is det.
mv_references(E, Ns) :- findall(N, sub_term(ref(N), E), Ns0), list_to_set(Ns0, Ns).

		 /*******************************
		 *        PLAN DATA (CSV)       *
		 *******************************/

%   The rate rows: [Description-[Column=Value, ...]]
plan_rates(Dir, Rows) :-
    atomic_list_concat([Dir, '/Rates.csv'], F),
    (   exists_file(F)
    ->  csv_read_file(F, [H|Rs], [convert(false), strip(true)]),
        H =.. [_|Cols],
        findall(D-Pairs, ( member(R, Rs), R =.. [_, D|Vs], Cols = [_|Cs], pairs_eq(Cs, Vs, Pairs) ), Rows)
    ;   Rows = []
    ).

pairs_eq([], [], []).
pairs_eq([C|Cs], [V|Vs], [C=V|Ps]) :- pairs_eq(Cs, Vs, Ps).

plan_fields(Dir, Fields) :-
    atomic_list_concat([Dir, '/PlanFields.csv'], F),
    (   exists_file(F)
    ->  csv_read_file(F, [_|Rs], [convert(false), strip(true)]),
        findall(N-V, member(row(N, V), Rs), Fields)
    ;   Fields = []
    ).

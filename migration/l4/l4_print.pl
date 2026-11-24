/** <module> The reader's model written back as L4

    The second check of the reader (gate.pl): a program read by l4_reader.pl
    is written back as L4 text — every name in backquotes, every
    subexpression in brackets, every list on one line with commas — and L4's
    evaluator runs the text written back. If the reader had grouped an
    operator, an argument or a branch differently from L4, a directive's
    result would change. Annotations are not written back; they change no
    result.
*/

:- module(l4_print, [l4_print_module/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).

%!  l4_print_module(+Model, -Text) is det.
l4_print_module(l4_module(Items, _), Text) :-
    with_output_to(string(Text), forall(member(I, Items), print_item(I))).

print_item(section(Lvl, Name, Aka, _)) :- !,
    forall(between(1, Lvl, _), write('§')),
    ( Name == none -> true ; write(' '), qn(Name) ),
    print_aka(Aka), nl, nl.
print_item(import(N, _)) :- !, write('IMPORT '), qn(N), nl, nl.
print_item(timezone(E, _)) :- !, write('TIMEZONE IS '), ex(E), nl, nl.
print_item(declare(Sig, AF, TD, _, _)) :- !,
    print_sig(Sig), write('DECLARE '), print_appform(AF), write(' '), print_typedecl(TD), nl, nl.
print_item(decide(_, Sig, AF, E, _, _)) :- !,
    print_sig(Sig), write('DECIDE '), print_appform(AF), write(' IS'), nl,
    write('  '), print_body(E, 2), nl, nl.
print_item(assume(Sig, AF, T, _, _)) :- !,
    print_sig(Sig), write('ASSUME '), print_appform(AF),
    ( T == none -> true ; write(' IS '), print_type(T) ), nl, nl.
print_item(directive(D, _, _)) :- !, print_directive(D), nl, nl.
print_item(unparsed(T, _, _)) :- format("-- unread: ~w~n~n", [T]).


print_aka([]) :- !.
print_aka(Ns) :- write(' AKA '), print_commas(Ns, qn).

print_sig(sig(Gs, Gt)) :-
    (   Gs == [] -> true
    ;   write('GIVEN '), print_commas(Gs, print_param), nl
    ),
    (   Gt == none -> true
    ;   write('GIVETH '), print_type(Gt), nl
    ).

print_param(param(N, T, _)) :- qn(N), ( T == none -> true ; write(' IS '), print_type(T) ).

print_appform(appform(N, Args, Aka, _)) :-
    qn(N), forall(member(A, Args), ( write(' '), qn(A) )), print_aka(Aka).

%   Records and choices are written one field, one choice per line: L4 has
%   no brackets around a choice with fields.
print_typedecl(record([])) :- !.
print_typedecl(record(Fs)) :- write('HAS'), forall(member(F, Fs), ( nl, tab(4), print_field(F) )).
print_typedecl(enum(Cs)) :- write('IS ONE OF'), forall(member(C, Cs), ( nl, tab(4), print_con(C) )).
print_typedecl(synonym(T)) :- write('IS '), print_type(T).

print_field(field(N, T, C, _)) :- qn(N), write(' IS '), print_type(T),
    ( C == none -> true ; write(' MEANS '), ex(C) ).

print_con(con(N, [])) :- !, qn(N).
print_con(con(N, Fs)) :- qn(N), write(' HAS'), forall(member(F, Fs), ( nl, tab(8), print_field(F) )).

print_type(type) :- !, write('TYPE').
print_type(tyapp(N, [])) :- !, ty_name(N).
print_type(tyapp(N, Args)) :- !, write('('), ty_name(N), write(' OF '), print_commas(Args, print_type), write(')').
print_type(fun(As, R)) :- !,
    write('(FUNCTION FROM '), print_seps(As, print_type, ' AND '), write(' TO '), print_type(R), write(')').
print_type(forall(Ns, T)) :- !, write('FOR ALL '), print_seps(Ns, qn, ' AND '), write(' '), print_type(T).

ty_name('LIST') :- !, write('LIST').
ty_name(N) :- qn(N).

print_directive(eval(E)) :- write('#EVAL '), ex(E).
print_directive(evaltrace(E)) :- write('#EVALTRACE '), ex(E).
print_directive(check(E)) :- write('#CHECK '), ex(E).
print_directive(assert(E)) :- write('#ASSERT '), ex(E).
print_directive(trace(C, At, Events)) :-
    write('#TRACE '), ex(C), write(' AT '), ex(At), write(' WITH'),
    forall(member(Ev, Events), ( nl, write('  '), ex(Ev) )).

%   A declaration's body: a WHERE goes on lines of its own.
print_body(where(E, Ds), Ind) :- !,
    ex(E), nl, tab(Ind), write('WHERE'),
    I2 is Ind + 2,
    forall(member(D, Ds), ( nl, tab(I2), print_local(D, I2) )).
print_body(E, _) :- ex(E).

print_local(decide(_, sig(Gs, Gt), AF, E, _, _), Ind) :- !,
    (   Gs == [] -> true ; write('GIVEN '), print_commas(Gs, print_param), nl, tab(Ind) ),
    (   Gt == none -> true ; write('GIVETH '), print_type(Gt), nl, tab(Ind) ),
    print_appform(AF), write(' MEANS'), nl, I2 is Ind + 2, tab(I2), print_body(E, I2).
print_local(assume(sig(Gs, Gt), AF, T, _, _), Ind) :-
    (   Gs == [] -> true ; write('GIVEN '), print_commas(Gs, print_param), nl, tab(Ind) ),
    (   Gt == none -> true ; write('GIVETH '), print_type(Gt), nl, tab(Ind) ),
    write('ASSUME '), print_appform(AF), ( T == none -> true ; write(' IS '), print_type(T) ).

% ---------------------------------------------------------------------------
% Expressions: each in brackets

%   Brackets only where needed: none around a name, a number or a string;
%   none inside a chain of one operator (`a OR b OR c`), which L4 reads the
%   same way on one line. L4's own parser takes time exponential in the
%   depth of nested brackets (it tries a bracketed expression as the start
%   of `'s` before reading it again as itself), so fewer is faster, not
%   just tidier.
ex(E) :- atomic_ex(E), !, ex_(E).
ex(E) :- write('('), ex_(E), write(')').

atomic_ex(num(N)) :- N >= 0.
atomic_ex(str(_)).
atomic_ex(app(_, [])).
atomic_ex(let([], E)) :- atomic_ex(E).

ex_(num(N)) :- !, ( N < 0 -> format("~w", [N]) ; format("~w", [N]) ).
ex_(str(S)) :- !, print_string(S).
ex_(app(N, [])) :- !, qn(N).
ex_(app(N, Args)) :- !, qn(N), write(' OF '), print_commas(Args, ex).
ex_(app_named(N, Fs)) :- !, qn(N), write(' WITH '), print_commas(Fs, print_named).
ex_(proj(E, F)) :- !, ex(E), write('\'s '), qn(F).
ex_(not(E)) :- !, write('NOT '), ex(E).
ex_(percent(E)) :- !, ex(E), write('%').
ex_(as(E, T)) :- !, ex(E), write(' AS '), qn(T).
ex_(if(C, T, E)) :- !, write('IF '), ex(C), write(' THEN '), ex(T), write(' ELSE '), ex(E).
ex_(branch(Gs, O)) :- !,
    write('BRANCH'), forall(member(C-E, Gs), ( write(' IF '), ex(C), write(' THEN '), ex(E) )),
    write(' OTHERWISE '), ex(O).
ex_(consider(E, Bs)) :- !, write('CONSIDER '), ex(E), write(' '), print_commas(Bs, print_branch).
ex_(lam(Ps, E)) :- !, write('GIVEN '), print_commas(Ps, print_param), write(' YIELD '), ex(E).
ex_(list(Es)) :- !, write('LIST '), print_commas(Es, ex).
ex_(concat(Es)) :- !, write('CONCAT '), print_commas(Es, ex).
ex_(fetch(E)) :- !, write('FETCH '), ex(E).
ex_(env(E)) :- !, write('ENV '), ex(E).
ex_(post(A, B, C)) :- !, write('POST '), ex(A), write(' '), ex(B), write(' '), ex(C).
%   One binding per LET, nested: L4 reads several bindings of one LET only
%   one per line.
ex_(let([], E)) :- !, ex_(E).
ex_(let([D|Ds], E)) :- !,
    write('LET '), print_let(D), write(' IN '), ex(let(Ds, E)).
ex_(where(E, Ds)) :- !,
    % A WHERE inside an expression: on lines of its own, to the right of
    % the column where the expression began.
    line_position(current_output, C0),
    ex(E), nl, W is C0 + 2, tab(W), write('WHERE'),
    D is W + 2,
    forall(member(L, Ds), ( nl, tab(D), print_local(L, D) )).
ex_(mixfix(Parts)) :- !, print_seps(Parts, print_part, ' ').
ex_(breach(By, Because)) :- !,
    write('BREACH'),
    ( By == none -> true ; write(' BY '), ex(By) ),
    ( Because == none -> true ; write(' BECAUSE '), ex(Because) ).
ex_(event(P, A, T)) :- !, write('PARTY '), ex(P), write(' DOES '), ex(A), write(' AT '), ex(T).
ex_(deontic(P, M, A, Prov, W, H, L)) :- !,
    write('PARTY '), ex(P), write(' '), modal(M), write(' '), pat(A),
    ( Prov == none -> true ; write(' PROVIDED '), ex(Prov) ),
    ( W == none -> true ; write(' WITHIN '), ex(W) ),
    ( H == none -> true ; write(' HENCE '), ex(H) ),
    ( L == none -> true ; write(' LEST '), ex(L) ).
ex_(E) :-
    E =.. [Op, A, B], binop(Op, W), !,
    chain_left(Op, A), format(" ~w ", [W]), chain_right(Op, B).

%   The operand of a chain of one operator: a right-associative operator's
%   right operand, a left-associative one's left operand, is written bare.
chain_right(Op, B) :- right_assoc(Op), B =.. [Op, _, _], !, ex_(B).
chain_right(_, B) :- ex(B).
chain_left(Op, A) :- \+ right_assoc(Op), A =.. [Op, _, _], !, ex_(A).
chain_left(_, A) :- ex(A).

right_assoc(Op) :- memberchk(Op, [implies, or, and, ror, rand, eq, leq, geq, lt, gt, cons]).

binop(implies, 'IMPLIES').
binop(or, 'OR').
binop(and, 'AND').
binop(ror, 'ROR').
binop(rand, 'RAND').
binop(eq, 'EQUALS').
binop(leq, 'AT MOST').
binop(geq, 'AT LEAST').
binop(lt, 'LESS THAN').
binop(gt, 'GREATER THAN').
binop(cons, 'FOLLOWED BY').
binop(plus, 'PLUS').
binop(minus, 'MINUS').
binop(times, 'TIMES').
binop(div, 'DIVIDED BY').
binop(mod, 'MODULO').

modal(must) :- write('MUST').
modal(may) :- write('MAY').
modal(shant) :- write('SHANT').
modal(do) :- write('DO').

print_part(arg(E)) :- ex(E).
print_part(kw(K)) :- qn(K).

print_named(N=E) :- qn(N), write(' IS '), ex(E).

print_branch(when(P, E)) :- write('WHEN '), pat(P), write(' THEN '), ex(E).
print_branch(otherwise(E)) :- write('OTHERWISE '), ex(E).

print_let(decide(_, _, appform(N, Args, _, _), E, _, _)) :-
    qn(N), forall(member(A, Args), ( write(' '), qn(A) )), write(' MEANS '), ex(E).
print_let(D) :- format("-- ~q", [D]).

pat(plit(E)) :- !, ex(E).
pat(pexact(E)) :- !, write('(EXACTLY '), ex(E), write(')').
pat(papp(N, [])) :- !, qn(N).
pat(papp(N, Ps)) :- !, write('('), qn(N), write(' OF '), print_commas(Ps, pat), write(')').
pat(pcons(A, B)) :- !, write('('), pat(A), write(' FOLLOWED BY '), pat(B), write(')').

print_string(S) :-
    string_codes(S, Cs),
    write('"'), forall(member(C, Cs), esc(C)), write('"').

esc(0'") :- !, write('\\"').
esc(0'\\) :- !, write('\\\\').
esc(0'\n) :- !, write('\\n').
esc(C) :- char_code(Ch, C), put_char(Ch).

%   A name, always in backquotes (the reader's names have none).
qn(N) :- format("`~w`", [N]).

print_commas(Xs, P) :- print_seps(Xs, P, ', ').

print_seps([], _, _).
print_seps([X], P, _) :- !, call(P, X).
print_seps([X|Xs], P, Sep) :- call(P, X), write(Sep), print_seps(Xs, P, Sep).

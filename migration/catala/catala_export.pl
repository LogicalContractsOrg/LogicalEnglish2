/** <module> File ▸ Export to Another System ▸ Catala

    The way back of Phase 3c (decision 7 of the October plan: one export per
    phase). A Logical English program is read as the RuleSpec exporter reads
    it (../rulespec/rulespec_export.pl: the same templates, rules and
    refusals) and written as one Catala module in the English dialect:

      - one scope, `Program`, whose inputs are the program's inputs and whose
        outputs are the values and conditions its rules conclude;
      - a value with conditions as one definition, its cascade an `if …
        then … else …` that ends in `impossible` where Logical English has
        no last branch (no value), as Catala's own empty default;
      - a yes-or-no rule as a `rule … under condition … consequence
        fulfilled`;
      - an input whose scenarios give it words as an enumeration of those
        words;
      - each scenario as a test scope (#[test]) that sets the inputs and
        asserts the answers it expects.

    Numbers are written as decimals (Catala does not mix integers and
    decimals); an amount is a decimal, not Catala's money. Refused, with
    the reasons, besides the RuleSpec exporter's refusals: aggregates over a
    relation, dated values, rounding down or up and absolute values (Catala
    keeps them in its standard library, not in its expressions).

    Each definition and rule of the scope has a `#` comment above it naming
    the lines of the program it came from (`# Logical English line 74`),
    when the exporter is given the program's text.
*/

:- module(catala_export, [export_catala/3, applies_catala/1, check_catala/3, catala_module/3, catala_module/4]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module('../rulespec/rulespec_export').

applies_catala(KB) :- applies_rulespec(KB).

check_catala(KB, Options, Problems) :-              % (Catala has a value for no case: impossible)
    setup_call_cleanup(nb_setval(rs_export_no_value, keep),
                       check_rulespec(KB, Options, Problems),
                       nb_setval(rs_export_no_value, refuse)).

export_catala(KB, Options, Result) :-
    le_writer:kb_to_ir(KB, program(H, _)),
    ( memberchk(kb(Name), H) -> true ; Name = program ),
    module_name(Name, Mod),
    catch(b_setval(cat_module, Mod), _, true),
    catch(catala_module(KB, Options, Text0, Tests), error(catala_export_refused(Ps), _), true),
    (   nonvar(Ps)
    ->  Result = refused(Ps)
    ;   format(string(Text), "~s~n~s", [Text0, Tests]),
        format(atom(File), '~w.catala_en', [Mod]),
        Result = exported(File, Text,
                          ["One Catala module (English dialect): the scope Program, its inputs and the values and conditions its rules conclude; each scenario a test scope (#[test]).",
                           "Run it: clerk test, or catala interpret <file> --scope=Test1 for one test."],
                          [])
    ).

%!  catala_module(+KB, -Module, -Tests) is det.
%!  catala_module(+KB, +Options, -Module, -Tests) is det.
%
%   With text(Doc) in Options (the exporter's), each definition and rule of
%   the scope has a `#` comment above it naming the lines of the program it
%   came from (Catala reads `#` to the end of the line as a comment inside
%   its code blocks).
catala_module(KB, Text, Tests) :-
    catala_module(KB, [], Text, Tests).

catala_module(KB, Options, Text, Tests) :-
    setup_call_cleanup(nb_setval(rs_export_no_value, keep),
                       rulespec_export:analyse(KB, 'cat:program', Rules, Cases, Options),
                       nb_setval(rs_export_no_value, refuse)),
    findall(problem(W, M), rulespec_export:problem_(W, M), Problems0),
    (   Problems0 \== [] -> throw(error(catala_export_refused(Problems0), _)) ; true ),
    retractall(enum_value(_, _)), retractall(stated(_)),
    retractall(date_value(_)),
    forall(( member(case(_, _, In, _), Cases), member(K0-V, In), local_key(K0, K) ),
           ( assert_once(stated(K)),
             ( text_value(V) -> assert_once(enum_value(K, V)) ; iso_date(V) -> assert_once(date_value(K)) ; true ) )),
    forall(( member(rs(_, derived, _, Vs), Rules), member(version(_, _, F), Vs), sub_term(cmp(_, ref(X), str(S)), F) ),
           assert_once(enum_value(X, S))),
    %  (a value that copies an input has the input's words)
    forall(( member(rs(N, derived, _, [version(_, _, ref(I))]), Rules), enum_value(N, _) ),
           ( forall(retract(enum_value(N, V)), assert_once(enum_value(I, V))) )),
    check_rules(Rules),
    b_setval(cat_rules, Rules),
    with_output_to(string(Text), module_text(Rules)),
    with_output_to(string(Tests), tests_text(Cases, Rules)).

:- dynamic enum_value/2, stated/1, date_value/1.
assert_once(F) :- ( call(F) -> true ; assertz(F) ).

text_value(V) :- ( atom(V), \+ memberchk(V, [true, false, holds, not_holds]) ; string(V) ), \+ iso_date(V).

iso_date(V) :- ( atom(V) ; string(V) ), atom_string(V, S), split_string(S, "-", "", [Y, M, D]), maplist([X]>>number_string(_, X), [Y, M, D]), string_length(Y, 4).

local_key(K0, K) :-
    format(atom(A), '~w', [K0]),
    ( sub_atom(A, B, 1, _, '#') -> B1 is B + 1, sub_atom(A, B1, _, 0, F) ; F = A ),
    ( atom_concat('input.', K, F) -> true ; K = F ).

%   Each refusal is placed on the rule (or the template's clauses) of the
%   value it is about; a relation nothing states or reads is none, since
%   nothing of it is written.
check_rules(Rules) :-
    findall(Ps1,
            ( member(rs(N, Kind, _, Vs), Rules),
              (   Kind == parameter, Vs = [_, _|_] -> format(string(M), "~w: a value with dates (Catala would read it against a date the scope is given)", [N])
              ;   Kind == data_relation -> format(string(M), "~w: a relation between two things (Catala keeps such facts in lists of structures)", [N])
              ;   member(version(_, _, F), Vs), sub_term(T, F), compound(T), refused_term(T, Why) -> format(string(M), "~w: ~w", [N, Why])
              ),
              place_problems(N, [problem(none, M)], Ps1) ), Pss),
    append(Pss, Ps0),
    rulespec_export:one_per_clause(Ps0, Ps),
    (   Ps \== [] -> throw(error(catala_export_refused(Ps), _)) ; true ).

refused_term(len(_), "a count over a relation").
refused_term(count_where(_, _), "a count over a relation").
refused_term(sum(_, _), "a sum over a relation").
refused_term(sum_where(_, _, _), "a sum over a relation").
refused_term(index(_, _), "a table looked up").
refused_term(call(floor, _), "rounding down").
refused_term(call(ceil, _), "rounding up").
refused_term(call(abs, _), "an absolute value").
refused_term(table(_), "a table").


		 /*******************************
		 *          THE MODULE          *
		 *******************************/

%   Catala names a module after its file: Cat_section_132.catala_en.
module_name(Name, Mod) :-
    atom_codes(Name, [C|Cs]), code_type(C, to_lower(U)), atom_codes(Mod, [U|Cs]).

module_text(Rules) :-
    ( nb_current(cat_module, Mod), Mod \== [] -> true ; Mod = 'Program' ),
    format("> Module ~w~n~n# Written from a Logical English program~n~nWritten by Logical English's translator (LE2 migration/catala).~n~n```catala~n", [Mod]),
    forall(enum_input(N), enum_decl(N)),
    forall(subject_entity(E), struct_decl(E)),
    format("declaration scope Program:~n"),
    forall(input_name(N, T), format("  input ~w content ~w~n", [N, T])),
    forall(( member(rs(N, parameter, _, _), Rules) ), format("  internal ~w content decimal~n", [N])),
    forall(( member(rs(N, derived, Attrs, Vs), Rules) ),
           ( (   ( stated(N) ; memberchk(overridable-true, Attrs) ) -> IO = 'context output' ; IO = output ),
             (   memberchk(entity-E, Attrs) -> param_name(E, X), format(atom(Dep), " depends on ~w content ~w", [X, E]) ; Dep = '' ),
             (   memberchk(dtype-'Judgment', Attrs)
             ->  format("  ~w ~w condition~w~n", [IO, N, Dep])
             ;   derived_type(N, Attrs, Vs, T), format("  ~w ~w content ~w~w~n", [IO, N, T, Dep])
             ) )),
    format("~nscope Program:~n"),
    forall(( member(rs(N, parameter, _, [version(_, _, literal(V))]), Rules) ),
           ( provenance(N), decimal_text(V, VT), format("  definition ~w equals ~w~n", [N, VT]) )),
    forall(( member(rs(N, derived, Attrs, Vs), Rules) ), derived_text(N, Attrs, Vs)),
    format("```~n").

%   The inputs: every name the rules read that no rule gives, with its type
%   (the facts of the individual a rule is about are its structure's
%   fields, not inputs of the scope).
input_name(N, T) :-
    findall(N0, ( rulespec_export:t_(F, _, input(_, none), _), rulespec_export:name_(F, N0), N0 \== calculation_date ), Ns0),
    sort(Ns0, Ns), member(N, Ns),
    input_type(N, T).

input_type(N, T) :-
    (   rulespec_export:name_(F, N), rulespec_export:t_(F, _, input(judgment, _), _) -> T = boolean
    ;   enum_value(N, _) -> enum_type(N, T)
    ;   ( date_input(N) ; date_value(N) ) -> T = date
    ;   months_name(N) -> T = duration
    ;   T = decimal
    ).

%   The individuals the rules are about (a child: Catala's `définition x de
%   enfant`), each a structure whose fields are its facts.
subject_entity(E) :-
    b_getval(cat_rules, Rules),
    findall(E0, ( member(rs(_, derived, A, _), Rules), memberchk(entity-E0, A) ), Es0), sort(Es0, Es), member(E, Es).

entity_field(E, N, T) :-
    findall(N0, ( rulespec_export:t_(F, _, input(_, E0), _), E0 == E, rulespec_export:name_(F, N0) ), Ns0),
    sort(Ns0, Ns), member(N, Ns), input_type(N, T).

struct_decl(E) :-
    format("declaration structure ~w:~n", [E]),
    forall(entity_field(E, N, T), format("  data ~w content ~w~n", [N, T])),
    nl.

%   The name of the individual a rule is about, in the rule: its type's
%   name in lower case (EnfantPrestationsFamiliales: enfant_prestations_familiales).
param_name(E, X) :- atom_codes(E, Cs), param_snake(Cs, Ds), atom_codes(X0, Ds), ( atom_concat('_', X, X0) -> true ; X = X0 ).
param_snake([], []).
param_snake([C|Cs], Out) :- ( code_type(C, upper(L)) -> Out = [0'_, L|R] ; Out = [C|R] ), param_snake(Cs, R).

%   A number of months: a value added to a date (Catala's duration).
months_name(N) :-
    once(( b_getval(cat_rules, Rules), member(rs(_, _, _, Vs), Rules), member(version(_, _, F), Vs),
           sub_term(call(add_months, [_, ref(N)]), F) )).

%   A derived value's type: from its template's kind of value, from the
%   input it copies, a duration for a number of months.
derived_type(N, _, _, duration) :- months_name(N), !.
derived_type(_, A, _, date) :- memberchk(dtype-dtype(VN), A), memberchk(VN, [date, "date"]), !.
derived_type(_, _, [version(_, _, ref(I))], T) :- input_type(I, T), !.
derived_type(N, _, _, T) :- enum_value(N, _), !, enum_type(N, T).
derived_type(_, _, _, decimal).

date_input(N) :- once(( b_getval(cat_rules, Rules), member(rs(_, _, _, Vs), Rules), member(version(_, _, F), Vs),
                        sub_term(cmp(_, A, B), F), ( A == ref(N), B = date(_) ; B == ref(N), A = date(_) ) )).

enum_input(N) :- findall(N0, enum_value(N0, _), Ns0), sort(Ns0, Ns), member(N, Ns).
enum_type(N, T) :- atom_codes(N, [C|Cs]), code_type(C, to_lower(U)), atom_codes(T0, [U|Cs]), atomic_list_concat(Ps, '_', T0),
    maplist(capital, Ps, Ps1), atomic_list_concat(Ps1, T1), atom_concat(T1, 'Code', T).

enum_decl(N) :-
    enum_type(N, T), findall(V, enum_value(N, V), Vs0), sort(Vs0, Vs),
    format("declaration enumeration ~w:~n", [T]),
    forall(member(V, Vs), ( constructor(V, C), format("  -- ~w~n", [C]) )),
    nl.

constructor(V, C) :-
    atom_string(V, S0), split_string(S0, " _-", " _-", Ps0), exclude(==(""), Ps0, Ps),
    maplist(capital, Ps, Ps1), atomic_list_concat(Ps1, C0),
    ( sub_atom(C0, 0, 1, _, F), char_type(F, digit) -> atom_concat('C', C0, C) ; C = C0 ).

capital(P, C) :- atom_string(PA, P), sub_atom(PA, 0, 1, _, F), sub_atom(PA, 1, _, 0, R), upcase_atom(F, FU), atom_concat(FU, R, C).

%   The lines of the program a definition comes from, as a comment above it.
provenance(N) :- ( provenance_text(N, PT) -> format("  # ~s~n", [PT]) ; true ).

%   A refusal found while writing a value is placed on its rule (or its
%   template's rules), so that a partial export can leave them out.
derived_text(N, Attrs, Vs) :-
    catch(derived_text_(N, Attrs, Vs), error(catala_export_refused(Ps0), C),
          ( place_problems(N, Ps0, Ps), throw(error(catala_export_refused(Ps), C)) )).

derived_text_(N, Attrs, [version(_, _, F)]) :- !,
    provenance(N),
    (   memberchk(entity-E, Attrs) -> param_name(E, X), b_setval(cat_subject, E-X), format(atom(Of), " of ~w", [X])
    ;   b_setval(cat_subject, none), Of = ''
    ),
    (   memberchk(dtype-'Judgment', Attrs)
    ->  cond_text(F, C), format("  rule ~w~w under condition~n    ~s~n  consequence fulfilled~n", [N, Of, C])
    ;   months_name(N) -> dur_ca(F, XT), format("  definition ~w~w equals~n    ~s~n", [N, Of, XT])
    ;   ca(F, XT), format("  definition ~w~w equals~n    ~s~n", [N, Of, XT])
    ),
    b_setval(cat_subject, none).
derived_text_(N, _, _) :- format(string(M), "~w: a value with dates", [N]), throw(error(catala_export_refused([problem(none, M)]), _)).

%   A yes-or-no formula as a condition: a cascade of true and false.
cond_text(F, C) :- ca(F, C).

%   A formula of the RuleSpec exporter, in Catala.
ca(num(N), S) :- !, decimal_text(N, S).
ca(str(X), S) :- !, constructor(X, C), format(string(S), "~w", [C]).
ca(date(A), S) :- !, format(string(S), "|~w|", [A]).
ca(bool(true), "true") :- !.
ca(bool(false), "false") :- !.
ca(ref(N), S) :- nb_current(cat_subject, E-X), E \== none, entity_field(E, N, _), !, format(string(S), "~w.~w", [X, N]).
ca(ref(N), S) :- nb_current(cat_subject, E-X), E \== none, b_getval(cat_rules, Rules),
    member(rs(N, derived, A, _), Rules), memberchk(entity-E, A), !, format(string(S), "(~w of ~w)", [N, X]).
ca(ref(N), S) :- !, format(string(S), "~w", [N]).
%   a date some months after a date
ca(call(add_months, [B, M]), S) :- !, ca(B, BS),
    (   M = ref(N), months_name(N) -> ca(M, MS), format(string(S), "(~s + ~s)", [BS, MS])
    ;   M = num(K), integer(K) -> format(string(S), "(~s + ~w month)", [BS, K])
    ;   throw(error(catala_export_refused([problem(none, "months added to a date that are not a number of months the program names")]), _))
    ).
ca(bin(Op, X, Y), S) :- !, ca(X, XS), ca(Y, YS), format(string(S), "(~s ~w ~s)", [XS, Op, YS]).
ca(neg(X), S) :- !, ca(X, XS), format(string(S), "(- ~s)", [XS]).
ca(not(X), S) :- !, ca(X, XS), format(string(S), "(not ~s)", [XS]).
ca(and(X, Y), S) :- !, ca(X, XS), ca(Y, YS), format(string(S), "(~s and ~s)", [XS, YS]).
ca(or(X, Y), S) :- !, ca(X, XS), ca(Y, YS), format(string(S), "(~s or ~s)", [XS, YS]).
ca(cmp(Op, X, Y), S) :- !, ca(X, XS), ca(Y, YS), op_ca(Op, O), format(string(S), "(~s ~w ~s)", [XS, O, YS]).
ca(if(C, X, nomatch), S) :- !, ca(C, CS), ca(X, XS), format(string(S), "(if ~s then ~s else impossible)", [CS, XS]).
ca(if(C, X, Y), S) :- !, ca(C, CS), ca(X, XS), ca(Y, YS), format(string(S), "(if ~s then ~s else ~s)", [CS, XS, YS]).
ca(match(Subj, Arms), S) :- !, match_if(Subj, Arms, If), ca(If, S).
ca(call(max, [X, Y]), S) :- !, ca(X, XS), ca(Y, YS), format(string(S), "(if ~s >= ~s then ~s else ~s)", [XS, YS, XS, YS]).
ca(call(min, [X, Y]), S) :- !, ca(X, XS), ca(Y, YS), format(string(S), "(if ~s <= ~s then ~s else ~s)", [XS, YS, XS, YS]).
ca(call(round, [X]), S) :- !, ca(X, XS), format(string(S), "(round of ~s)", [XS]).
ca(X, _) :- term_string(X, T), format(string(M), "a formula this exporter cannot write: ~w", [T]),
    throw(error(catala_export_refused([problem(none, M)]), _)).

%   A duration's formula: its numbers in months.
dur_ca(num(K), S) :- !, K1 is integer(K), format(string(S), "~w month", [K1]).
dur_ca(if(C, X, Y), S) :- !, ca(C, CS), dur_ca(X, XS), dur_ca(Y, YS), format(string(S), "(if ~s then ~s else ~s)", [CS, XS, YS]).
dur_ca(F, S) :- ca(F, S).

%   A match as its tests in order: the first arm the outermost test.
match_if(_, [], nomatch).
match_if(Subj, [P-X|As], if(cmp(==, Subj, P), X, E)) :- match_if(Subj, As, E).

op_ca(==, '=').
op_ca(\=, '!=').
op_ca(=<, '<=').
op_ca(Op, Op).

decimal_text(N, S) :- ( integer(N) -> format(string(S), "~w.0", [N]) ; format(string(S), "~w", [N]) ).


		 /*******************************
		 *            TESTS             *
		 *******************************/

%   Each scenario a test scope: the inputs it states, the answers it
%   expects as assertions; an input it does not state is 0, false, or the
%   enumeration's first word (Catala needs every input).
tests_text(Cases0, Rules) :-
    include([case(_, _, _, Out)]>>(Out \== []), Cases0, Cases),     % (a scenario that expects nothing proves nothing)
    forall(nth1(I, Cases, C), case_text(I, C, Rules)).

case_text(I, case(N, _, In, Out), Rules) :-
    format("~n## Test ~w: ~w~n~n```catala~n#[test]~ndeclaration scope Test~w:~n  output program scope Program~n~nscope Test~w:~n", [I, N, I, I]),
    forall(input_name(K, T),
           ( (   member(K0-V, In), local_key(K0, K) -> value_text(T, V, VT)
             ;   default_text(T, K, VT)
             ),
             format("  definition program.~w equals ~s~n", [K, VT]) )),
    forall(( member(K0-V, In), local_key(K0, K), member(rs(K, derived, A, Vs), Rules) ),
           ( derived_type(K, A, Vs, T), value_text(T, V, VT), format("  definition program.~w equals ~s~n", [K, VT]) )),
    forall(( member(K0-V, Out), local_key(K0, K), member(rs(K, derived, A, _), Rules) ),
           ( (   memberchk(entity-E, A) -> subject_literal(E, In, Lit), format(atom(Of), " of ~s", [Lit]) ; Of = '' ),
             (   V == holds -> format("  assertion program.~w~w~n", [K, Of])
             ;   V == not_holds -> format("  assertion not (program.~w~w)~n", [K, Of])
             ;   number(V) -> decimal_text(V, VT), format("  assertion program.~w~w = ~s~n", [K, Of, VT])
             ;   true
             ) )),
    format("```~n").

%   The individual a case is about, as its structure: its facts, a field
%   the case does not state its default.
subject_literal(E, In, S) :-
    findall(F, ( entity_field(E, K, T),
                 (   member(K0-V, In), local_key(K0, K) -> value_text(T, V, VT) ; default_text(T, K, VT) ),
                 format(string(F), "-- ~w: ~s", [K, VT]) ), Fs),
    atomic_list_concat(Fs, ' ', FT), format(string(S), "~w { ~w }", [E, FT]).

value_text(boolean, V, S) :- !, ( memberchk(V, [true, holds, "true"]) -> S = "true" ; S = "false" ).
value_text(date, V, S) :- !, format(string(S), "|~w|", [V]).
value_text(duration, V, S) :- !, K is integer(V), format(string(S), "~w month", [K]).
value_text(T, V, S) :- sub_atom(T, _, _, 0, 'Code'), !, constructor(V, C), format(string(S), "~w.~w", [T, C]).
value_text(_, V, S) :- ( number(V) -> decimal_text(V, S) ; format(string(S), "~w", [V]) ).

default_text(boolean, _, "false") :- !.
default_text(date, _, "|2000-01-01|") :- !.
default_text(duration, _, "0 month") :- !.
default_text(T, K, S) :- sub_atom(T, _, _, 0, 'Code'), !,
    findall(V, enum_value(K, V), Vs0), sort(Vs0, [V|_]), constructor(V, C), format(string(S), "~w.~w", [T, C]).
default_text(_, _, "0.0").

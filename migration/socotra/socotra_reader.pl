/** <module> Socotra (classic) product configuration -> Logical English

    Phase 1a of the design notes roadmap.md (§5.9, §8): the
    product-configuration reader. A product directory of the Socotra product
    library (policy.json, exposures/<e>/exposure.json, perils/<p>.json,
    <p>.premium.liquid, underwriting.guidelines.liquid, policy.calculations.liquid,
    taxes/, fees.json, tables/<t>.csv) becomes the Migration IR of le_writer.pl:

      - fields            -> `; undefined` templates (scenario elements)
      - exposures, perils -> `*an exposure* is insured under *a policy*`,
                             `*an exposure* is covered for *a peril*`, a type per
                             exposure kind (`vehicle is an exposure`)
      - lookup tables     -> CSV-loaded decision tables (the carrier's CSV, as is)
      - Liquid scripts    -> rules, by symbolic execution: an assignment is an
                             expression; a branch merge (if/elsif/else, case) is
                             a quantity defined by an `otherwise` cascade; the
                             side-effect filters (set_year_premium, add_fee, ...)
                             are conclusions; a loop over the exposures is an
                             existential guard or an aggregate
      - what it cannot read -> residue blocks for the Contract Assistant

    Every rule and table cites its source file (a rule label with provenance);
    the ledger (le_migration.pl) has one row per source element.
*/

:- module(socotra_reader, [
    product_migration/3,        % +ProductDir, +OracleJSON, -Migration
    product_migration/4,        % +ProductDir, +OracleJSON, +Options, -Migration
    build_product/3,            % +ProductDir, +OutRoot, -Report
    build_all/2,                % +LibraryDir, +OutRoot
    build_all/3,                % +LibraryDir, +OutRoot, +Options
    build_product/4,            % +ProductDir, +OutRoot, -Report, +Options
    compile_script_text/4,      % +Text, +Scope, -Items, -Ledger   (tests)
    set_display_root/1,         % +Dir | none   (imports)
    copy_sources/3              % +ProductDir, +Root, +OutDir
  ]).

:- dynamic socotra_home/1.
:- prolog_load_context(directory, D), retractall(socotra_home(_)), assertz(socotra_home(D)).

% LE2: the one this process runs in, the environment's, or a checkout beside
% this repository (../le2_paths.pl declares it as `le2`)
:- use_module('../le2_paths', []).

:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).
:- use_module(le2(le_kbs)).
:- use_module(liquid).
:- use_module(socotra_sources).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(lists)).
:- use_module(library(filesex)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(readutil)).
:- use_module(library(csv)).
:- use_module(library(pairs)).

:- dynamic
    g_template/3,       % Functor, Text, Additions   (declared on first use)
    g_item/1,           % an IR item (rules, tables, residues), in order
    g_ledger/1,         % a ledger entry
    g_counter/2,        % Key, N
    g_table_used/1,     % table name
    g_field_type/3,     % Scope(policy|exposure|peril), Field, Type
    g_select/3,         % Scope, Field, Values
    g_exposure_noun/2,  % exposure dir, noun
    g_field_noun/2,     % exposure field, noun of its template
    g_residue/2.        % script file, reason

reset_gen :-
    retractall(g_materialized(_, _)),
    retractall(g_template(_, _, _)), retractall(g_item(_)), retractall(g_ledger(_)),
    retractall(g_counter(_, _)), retractall(g_table_used(_)), retractall(g_field_type(_, _, _)),
    retractall(g_select(_, _, _)), retractall(g_exposure_noun(_, _)), retractall(g_field_noun(_, _)),
    retractall(g_residue(_, _)).

next_id(Key, N) :-
    ( retract(g_counter(Key, N0)) -> true ; N0 = 0 ),
    N is N0 + 1, assertz(g_counter(Key, N)).

emit(rule(H, B0, Os)) :- !, flat_body(B0, B), assertz(g_item(rule(H, B, Os))).
emit(Item) :- assertz(g_item(Item)).

%   A conjunction as one flat list of conditions (a nested one would be
%   written as an indented group).
flat_body(B0, B) :-
    (   B0 = and(_, _)
    ->  flat_conj(B0, L), list_goal(L, B)
    ;   B = B0
    ).
ledger(Element, Kind, Verdict, Mapping, InProgram, Note) :-
    assertz(g_ledger(entry(Element, Kind, Verdict, Mapping, InProgram, Note))).

		 /*******************************
		 *          WORDS              *
		 *******************************/

%   Template words from an identifier: split at _ - space and camelCase,
%   lower case, digits spelled out (a number inside template words breaks
%   the parser), connectives dropped (they would split the sentence).
id_words(Id, Words) :-
    format(atom(A), '~w', [Id]),
    atom_codes(A, Cs0),
    camel_split(Cs0, Cs1),
    atom_codes(A1, Cs1),
    split_string(A1, "_- /.,:()'&%$#", "_- /.,:()'&%$#", Parts0),
    exclude(==(""), Parts0, Parts1),
    maplist([S, W]>>(string_lower(S, L), atom_string(W, L)), Parts1, Ws0),
    maplist(spell_word, Ws0, Wss), append(Wss, Ws1),
    exclude(connective, Ws1, Words0),
    ( Words0 == [] -> Words = [item] ; Words = Words0 ).

camel_split([], []).
camel_split([A, B|T], [A, 0'_, B|R]) :- code_type(A, lower), code_type(B, upper), !, camel_split(T, R0), R = R0.
camel_split([C|T], [C|R]) :- camel_split(T, R).

connective(W) :- memberchk(W, [and, or, if, unless, otherwise, either, that, not, says, expects, which, then, when]).

spell_word(W, Ws) :-
    atom_codes(W, Cs),
    (   \+ ( member(C, Cs), code_type(C, digit) ) -> Ws = [W]
    ;   phrase(digit_runs(Rs), Cs), maplist(spell_run, Rs, Wss), append(Wss, Ws)
    ).

digit_runs([R|Rs]) --> [C], { code_type(C, digit) }, !, digits_more(Ds), { atom_codes(A, [C|Ds]), R = num(A) }, digit_runs(Rs).
digit_runs([R|Rs]) --> [C], alpha_more(As), { atom_codes(A, [C|As]), R = w(A) }, digit_runs(Rs).
digit_runs([]) --> [].
digits_more([D|Ds]) --> [D], { code_type(D, digit) }, !, digits_more(Ds).
digits_more([]) --> [].
alpha_more([D|Ds]) --> [D], { \+ code_type(D, digit) }, !, alpha_more(Ds).
alpha_more([]) --> [].

spell_run(w(A), [A]).
spell_run(num(A), Ws) :- atom_number(A, N), number_words(N, Ws).

number_words(N, [W]) :- N < 20, !,
    nth0(N, [zero,one,two,three,four,five,six,seven,eight,nine,ten,eleven,twelve,thirteen,
             fourteen,fifteen,sixteen,seventeen,eighteen,nineteen], W).
number_words(N, Ws) :- N < 100, !,
    T is N // 10, U is N mod 10,
    nth0(T, [_,_,twenty,thirty,forty,fifty,sixty,seventy,eighty,ninety], TW),
    ( U =:= 0 -> Ws = [TW] ; number_words(U, [UW]), Ws = [TW, UW] ).
number_words(N, Ws) :- N < 1000, !,
    H is N // 100, R is N mod 100, number_words(H, HW),
    ( R =:= 0 -> append(HW, [hundred], Ws) ; number_words(R, RW), append([HW, [hundred], RW], Ws) ).
number_words(N, Ws) :-
    atom_number(A, N), atom_chars(A, Cs),
    maplist([C, W]>>(atom_number(C, D), number_words(D, [W])), Cs, Ws).

words_text(Ws, T) :- atomic_list_concat(Ws, ' ', T).

id_text(Id, T) :- id_words(Id, Ws), words_text(Ws, T).

%   A constant from a name: its words, without a leading article.
name_constant(Name, C) :-
    id_words(Name, Ws0),
    ( Ws0 = [A|Rest], Rest \== [], memberchk(A, [a, an, the]) -> Ws = Rest ; Ws = Ws0 ),
    words_text(Ws, C).

functor_of(Prefix, Id, F) :-
    id_words(Id, Ws), atomic_list_concat([Prefix|Ws], '_', F).

		 /*******************************
		 *        FIELD VALUES          *
		 *******************************/

%   A select value, a table key or a string literal as an LE value, read as
%   le_tables.pl reads a CSV cell, so that a scenario value and a table key
%   written the same way are the same value: a number when it reads as one
%   (`1.1`, and also `0005`, which the CSV reader takes for 5), a string
%   otherwise. A text opening with a comparison sign (`<50%`) would be a
%   condition in a CSV cell: its sign is spelled out (`under 50%`), here and
%   in the copied tables alike.
le_value(V, N) :- number(V), !, N = V.
le_value(V, N) :-
    ( atom(V) -> atom_string(V, S) ; S = V ),
    string(S),
    normalize_space(atom(A), S),
    (   A \== '', atom_number(A, N0), \+ le_tables:leading_zero_code(A)
    ->  N = N0
    ;   cell_text(S, N)
    ).

%   A text as a table cell can hold it.
cell_text(S0, S) :-
    normalize_space(string(T), S0),
    (   member(Sign-Words, ["<="-"at most", ">="-"at least", "<"-"under", ">"-"over",
                            "="-"equal to", "!="-"not"]),
        string_concat(Sign, Rest0, T)
    ->  normalize_space(string(Rest), Rest0),
        format(string(S), "~w ~w", [Words, Rest]),
        ( g_ledger(entry(S0, 'value', _, _, _, _)) -> true
        ; ledger(S0, 'value', approximated, 'a value opening with a comparison sign: the sign spelled out', S,
                 'a CSV cell opening with a comparison is a condition in LE') )
    ;   S = S0
    ).

		 /*******************************
		 *         THE MODEL            *
		 *******************************/

read_json(File, Dict) :-
    setup_call_cleanup(open(File, read, In, [encoding(utf8)]),
                       json_read_dict(In, Dict, [value_string_as(string)]),
                       close(In)).

%   model(Name, PolicyDir, PolicyFields, Exposures, Tables, Taxes, Fees)
%   Exposures: exp(Name, Dir, Noun, Fields, Perils)
%   Perils:    peril(Name, File, Const, Json, Script)
product_model(ProductDir, model(Name, PolicyDir, PFields, Exps, Tables, Taxes, Fees)) :-
    file_base_name(ProductDir, Name),
    atomic_list_concat([ProductDir, '/policy'], PolicyDir),
    read_json_file(PolicyDir, 'policy.json', PJ),
    get_dict_default(fields, PJ, [], PFields),
    atomic_list_concat([PolicyDir, '/exposures'], EDir),
    ( exists_directory(EDir) -> directory_files(EDir, Es0) ; Es0 = [] ),
    exclude([E]>>sub_atom(E, 0, _, _, '.'), Es0, Es1), msort(Es1, Es),
    findall(exp(EName, EDirName, Noun, EFields, Perils),
            ( member(EDirName, Es),
              atomic_list_concat([EDir, '/', EDirName], ED),
              atomic_list_concat([ED, '/exposure.json'], EJF), exists_file(EJF),
              read_json(EJF, EJ),
              get_dict_default(name, EJ, EDirName, EName0), atom_string(EName, EName0),
              exposure_noun(EName, Noun),
              get_dict_default(fields, EJ, [], EFields),
              exposure_perils(ED, Perils) ),
            Exps),
    tables_of(PolicyDir, Tables),
    taxes_of(PolicyDir, Taxes),
    ( read_json_file(PolicyDir, 'fees.json', FJ) -> get_dict_default(fees, FJ, [], Fees) ; Fees = [] ).

read_json_file(Dir, Name, J) :-
    atomic_list_concat([Dir, '/', Name], F), exists_file(F), read_json(F, J).

get_dict_default(K, D, Def, V) :- ( get_dict(K, D, V0) -> V = V0 ; V = Def ).

exposure_noun(Name, Noun) :-
    id_words(Name, Ws), words_text(Ws, Noun0),
    ( Noun0 == policy -> Noun = 'policy level exposure' ; Noun = Noun0 ).

exposure_perils(ED, Perils) :-
    atomic_list_concat([ED, '/perils'], PD),
    ( exists_directory(PD) -> directory_files(PD, Fs0) ; Fs0 = [] ),
    include([F]>>file_name_extension(_, json, F), Fs0, Fs1), msort(Fs1, Fs),
    findall(peril(PName, Base, Const, PJ, Script),
            ( member(F, Fs), file_name_extension(Base, json, F),
              atomic_list_concat([PD, '/', F], PF), read_json(PF, PJ),
              get_dict_default(name, PJ, Base, PName0), atom_string(PName, PName0),
              name_constant(PName, Const),
              atomic_list_concat([PD, '/', Base, '.premium.liquid'], S),
              ( exists_file(S) -> Script = S ; Script = none ) ),
            Perils).

tables_of(PolicyDir, Tables) :-
    atomic_list_concat([PolicyDir, '/tables'], TD),
    ( exists_directory(TD) -> directory_files(TD, Fs0) ; Fs0 = [] ),
    include([F]>>file_name_extension(_, csv, F), Fs0, Fs1), msort(Fs1, Fs),
    findall(table(T, Path, Header, Rows),
            ( member(F, Fs), file_name_extension(T, csv, F),
              atomic_list_concat([TD, '/', F], Path),
              read_csv_rows(Path, [Header|Rows]) ),
            Tables).

read_csv_rows(Path, Rows) :-
    read_file_to_string(Path, S0, [encoding(utf8)]),
    ( sub_string(S0, 0, 1, _, "﻿") -> sub_string(S0, 1, _, 0, S) ; S = S0 ),
    split_string(S, "\n", "\r", Lines0), exclude(==(""), Lines0, Lines),
    maplist([L, R]>>( split_string(L, ",", " ", R0), maplist([X, Y]>>normalize_space(string(Y), X), R0, R) ), Lines, Rows).

taxes_of(PolicyDir, Taxes) :-
    atomic_list_concat([PolicyDir, '/taxes'], TD),
    ( exists_directory(TD) -> directory_files(TD, Fs) ; Fs = [] ),
    findall(tax(T, Path),
            ( member(F, Fs), atom_concat(T, '.premium.liquid', F),
              atomic_list_concat([TD, '/', F], Path) ),
            Taxes0),
    msort(Taxes0, Taxes).

field_type(F, Type) :- get_dict_default(type, F, "string", T), atom_string(Type, T).
field_name(F, Name) :- get_dict(name, F, N), atom_string(Name, N).

		 /*******************************
		 *   TEMPLATES, ON FIRST USE    *
		 *******************************/

declare(F, Text, Adds) :-
    ( g_template(F, _, _) -> true ; assertz(g_template(F, Text, Adds)) ).

%!  declaration_item(+F, +Text, +Adds, -Item) is det.
%
%   Which section a template is declared in. Everything Socotra gives that
%   reads "... is *a value*" is ONE value per key — a policy or exposure
%   field, a peril characteristic, a premium, a tax, a fee, a table lookup —
%   so it is a FUNCTION (LE2's language reference §2.4), and the twin may
%   write the value where it is used:
%
%       and the indemnity per item for accident on the pet <= 500.0
%
%   instead of a condition to bind it and another to test it. The writer
%   decides where that is safe: a value that feeds a formula keeps its own
%   condition, since a function applied is not an arithmetic operand.
%
%   A relation is left alone: "*an exposure* is insured under *a policy*",
%   "the underwriting notes for *a policy* include *a note*" and a table's
%   "... is *a value* under table <t>" do not end in their value.
declaration_item(F, Text, Adds, function(F, Text, Adds)) :-
    le_writer:function_shaped(Text), !.
declaration_item(F, Text, Adds, template(F, Text, Adds)).

type_noun(select, value).
type_noun(string, value).
type_noun(email, value).
type_noun(number, number).
type_noun(date, date).
type_noun(_, value).

slot(Noun, S) :- ( sub_atom(Noun, 0, 1, _, C), memberchk(C, [a,e,i,o,u]) -> Art = an ; Art = a ),
    format(atom(S), '*~w ~w*', [Art, Noun]).

t_policy_field(Field, F) :-
    functor_of(policy, Field, F),
    ( g_field_type(policy, Field, T) -> true ; T = string ),
    type_noun(T, TN), slot(TN, S), id_text(Field, W),
    format(atom(Text), 'the ~w of *a policy* is ~w', [W, S]),
    declare(F, Text, [undefined]).

t_exposure_field(Field, F) :-
    functor_of(exposure, Field, F),
    ( g_field_type(exposure, Field, T) -> true ; T = string ),
    ( g_field_noun(Field, Noun) -> true ; Noun = exposure ),
    type_noun(T, TN), slot(TN, S), slot(Noun, ES), id_text(Field, W),
    format(atom(Text), 'the ~w of ~w is ~w', [W, ES, S]),
    declare(F, Text, [undefined]).

t_peril_char(Char, F) :-
    functor_of(peril, Char, F), id_text(Char, W),
    format(atom(Text), 'the ~w for *a peril* on *an exposure* is *an amount*', [W]),
    declare(F, Text, [undefined]).

t_peril_field(Field, F) :-
    functor_of(peril_field, Field, F),
    ( g_field_type(peril, Field, T) -> true ; T = string ),
    type_noun(T, TN), slot(TN, S), id_text(Field, W),
    format(atom(Text), 'the ~w for *a peril* on *an exposure* is ~w', [W, S]),
    declare(F, Text, [undefined]).

t_policy_date(W, F) :-
    atomic_list_concat([policy, W, date], '_', F),
    format(atom(Text), 'the ~w date of *a policy* is *a date*', [W]),
    declare(F, Text, [undefined]).

t_insured(insured_under) :- declare(insured_under, '*an exposure* is insured under *a policy*', [undefined]).
t_covered(covered_for) :- declare(covered_for, '*an exposure* is covered for *a peril*', [undefined]).

t_output(year_premium, out_year_premium, 'the yearly premium for *a peril* on *an exposure* is *an amount*').
t_output(year_technical_premium, out_year_technical_premium, 'the yearly technical premium for *a peril* on *an exposure* is *an amount*').
t_output(month_premium, out_month_premium, 'the monthly premium for *a peril* on *an exposure* is *an amount*').
t_output(month_technical_premium, out_month_technical_premium, 'the monthly technical premium for *a peril* on *an exposure* is *an amount*').
t_output(year_commission, out_year_commission, 'the yearly commission to *a recipient* for *a peril* on *an exposure* is *an amount*').
t_output(month_commission, out_month_commission, 'the monthly commission to *a recipient* for *a peril* on *an exposure* is *an amount*').
t_output(decision, out_decision, 'the underwriting decision for *a policy* is *a decision*').
t_output(note, out_note, 'the underwriting notes for *a policy* include *a note*').
t_output(gross_premium, out_gross_premium, 'the gross premium of *a policy* is *an amount*').

output_functor(Kind, F) :- t_output(Kind, F, Text), !, declare(F, Text, []).

tax_functor(Tax, F) :-
    functor_of(tax, Tax, F), id_text(Tax, W),
    format(atom(Text), 'the ~w tax for *a peril* on *an exposure* is *an amount*', [W]),
    declare(F, Text, []).

fee_functor(Fee, F) :-
    functor_of(fee, Fee, F), id_text(Fee, W),
    format(atom(Text), 'the ~w fee for *a policy* is *an amount*', [W]),
    declare(F, Text, []).

fee_desc_functor(Fee, F) :-
    functor_of(fee_description, Fee, F), id_text(Fee, W),
    format(atom(Text), 'the description of the ~w fee for *a policy* is *a text*', [W]),
    declare(F, Text, []).

%   The lookup filter: the table's value for the key or, for a key the table
%   has no row for, Liquid's nil, which arithmetic reads as 0.
lookup_functor(Table, F) :-
    functor_of(lookup, Table, F),
    (   g_template(F, _, _)
    ->  true
    ;   table_functor(Table, TF), id_text(Table, W),
        format(atom(Text), 'the ~w lookup of *a key* is *a value*', [W]),
        declare(F, Text, []),
        TG =.. [TF, K, V], H =.. [F, K, V],
        atomic_list_concat([lookup, Table], '_', Label),
        table_source(Table, Src),
        emit(rule(H, otherwise([TG, V = 0]), [label(Label), provenance([as_stated_in(Src)])])),
        ledger(Src, lookup, approximated,
               'the lookup filter: the table''s value, or 0 for a key the table has no row for', Label,
               'Liquid reads nil for a missing key; nil is 0 in arithmetic (the twin''s reading) but compares false')
    ).

%   The table's file as the provenance names it (next to the script's own).
table_source(Table, Src) :-
    (   nb_current(socotra_script, File), File \== [],
        sub_atom(File, B, _, _, '/policy/')
    ->  sub_atom(File, 0, B, _, Product),
        atomic_list_concat([Product, '/policy/tables/', Table, '.csv'], Src)
    ;   atomic_list_concat(['tables/', Table, '.csv'], Src)
    ).

table_functor(Table, F) :-
    functor_of(table, Table, F), id_text(Table, W),
    format(atom(Text), 'the ~w entry for *a key* is *a value* under table ~w', [W, Table]),
    declare(F, Text, []),
    ( g_table_used(Table) -> true ; assertz(g_table_used(Table)) ).

		 /*******************************
		 *    SYMBOLIC EVALUATION       *
		 *******************************/

%   The context of one script:
%     ctx(Scope, Script)
%     Scope  peril(PerilConst, ExpNoun) | tax(Tax) | policy
%     Script script(File, Label, Words)   (Words name its quantities)

%   Symbolic values: num(N), str(S), nil, bool(B), in(Kind, Name), q(F, Type),
%   ar(Op, A, B), fn(round, A), lk(Table, Key), obj(Kind), unsupported(Why)

eval_expr(unparsed(S), _, _, unsupported(unparsed(S))) :- !.
eval_expr(filtered(P, Fs), Ctx, Env, V) :-
    eval_primary(P, Ctx, Env, V0),
    foldl(apply_filter(Ctx, Env), Fs, V0, V).

eval_primary(num(N), _, _, num(N)) :- !.
eval_primary(str(S), _, _, str(S)) :- !.
eval_primary(nil, _, _, nil) :- !.
eval_primary(empty, _, _, nil) :- !.
eval_primary(bool(B), _, _, bool(B)) :- !.
eval_primary(path(Root, Steps), Ctx, Env, V) :-
    (   Root == data -> V0 = obj(data)
    ;   memberchk(Root-V0, Env) -> true
    ;   V0 = nil_var(Root)
    ),
    foldl(step(Ctx, Env), Steps, V0, V1),
    (   V0 = nil_var(R) -> undefined_variable(Ctx, R) ; true ),
    ( V1 = nil_var(_) -> V = nil ; V = V1 ).

%   A variable read before any assignment: Liquid reads nil. A source
%   defect, reported once per script.
undefined_variable(ctx(_, script(File, _, _), _), R) :-
    (   g_ledger(entry(File, 'source defect', _, _, R, _)) -> true
    ;   format(atom(M), 'reads the variable ~w, never assigned: Liquid reads nil (0 in arithmetic, false in a test)', [R]),
        ledger(File, 'source defect', approximated, M, R, 'the twin reads it the same way')
    ).

%   Navigating Socotra's data object.
step(_, _, _, unsupported(W), unsupported(W)) :- !.
step(_, _, key(K), obj(O), V) :- !, obj_key(O, K, V).
step(_, _, index(0), obj(O), V) :- !, obj_first(O, V).
step(_, _, first, obj(O), V) :- !, obj_first(O, V).
step(_, _, last, obj(O), V) :- !, obj_last(O, V).
step(_, _, size, obj(O), unsupported(size_of(O))) :- !.
step(_, _, index_expr(_), obj(O), unsupported(index_of(O))) :- !.
step(_, _, _, nil_var(R), nil_var(R)) :- !.          % nil.anything is nil
step(_, _, _, nil, nil) :- !.
step(_, _, S, V, unsupported(step(S, V))).

obj_key(data, policy_characteristics, obj(pchars)).
obj_key(data, exposure_characteristics, obj(echars)).
obj_key(data, peril_characteristics, obj(perchars)).
obj_key(data, policy, obj(policy)).
obj_key(pchars, field_values, obj(pfields)).
obj_key(pchars, gross_premium, in(gross_premium, policy)).
obj_key(pchars, gross_taxes, in(gross_taxes, policy)).
obj_key(pchars, policy_start_timestamp, in(policy_date, start)).
obj_key(pchars, policy_end_timestamp, in(policy_date, end)).
obj_key(pchars, K, unsupported(policy_characteristic(K))) :-
    \+ memberchk(K, [field_values, gross_premium, gross_taxes, policy_start_timestamp, policy_end_timestamp]).
obj_key(pfields, F, in(policy, F)).
obj_key(echars, field_values, obj(efields)).
obj_key(echars, field_groups_by_locator, unsupported(field_groups)).
obj_key(efields, F, in(exposure, F)).
obj_key(perchars, field_values, obj(perfields)).
obj_key(perchars, premium, in(peril_premium, peril)).
obj_key(perchars, K, in(peril_char, K)) :- memberchk(K, [indemnity_in_aggregate, indemnity_per_event, indemnity_per_item, deductible, lump_sum_payment]).
obj_key(perfields, F, in(peril_field, F)).
obj_key(policy, characteristics, obj(pchars_list)).
obj_key(policy, exposures, obj(exposures)).
obj_key(first_exposure, characteristics, obj(first_echars_list)).
obj_key(first_exposure, perils, obj(first_exposure_perils)).
obj_key(first_echars, field_values, obj(first_efields)).
obj_key(first_efields, F, in(any_exposure, F)).
obj_key(loop_exposure(L), name, in(exposure_kind, L)).
obj_key(loop_exposure(L), characteristics, obj(loop_echars_list(L))).
obj_key(loop_exposure(L), perils, obj(loop_perils(L))).
obj_key(loop_echars(L), field_values, obj(loop_efields(L))).
obj_key(loop_efields(L), F, in(loop_exposure_field(L), F)).
obj_key(loop_peril(P, L), name, in(peril_name, P-L)).
obj_key(loop_peril(P, L), characteristics, obj(loop_perchars_list(P, L))).
obj_key(loop_perchars(P, L), field_values, obj(loop_perfields(P, L))).
obj_key(loop_perchars(P, L), K, in(loop_peril_char(P, L), K)) :- K \== field_values.
obj_key(loop_perfields(P, L), F, in(loop_peril_field(P, L), F)).
obj_key(O, K, unsupported(key(O, K))).

obj_first(pchars_list, obj(pchars)).
obj_first(exposures, obj(first_exposure)).
obj_first(first_echars_list, obj(first_echars)).
obj_first(loop_echars_list(L), obj(loop_echars(L))).
obj_first(loop_perchars_list(P, L), obj(loop_perchars(P, L))).
obj_first(O, unsupported(first(O))).
obj_last(O, V) :- obj_first(O, V).         % one characteristics period per quote

%   Filters.
apply_filter(_, _, _, unsupported(W), unsupported(W)) :- !.
apply_filter(Ctx, Env, filter(Name, Args), V0, V) :-
    eval_args(Args, Ctx, Env, AVs),
    filter_value(Name, AVs, V0, V).

eval_args(Args, Ctx, Env, AVs) :- maplist(eval_arg(Ctx, Env), Args, AVs).
eval_arg(Ctx, Env, A, AV) :- eval_primary(A, Ctx, Env, AV).

filter_value(times, [B], A, ar(*, A, B)) :- !.
filter_value(plus, [B], A, ar(+, A, B)) :- !.
filter_value(minus, [B], A, ar(-, A, B)) :- !.
filter_value(divided_by, [B], A, ar(div, A, B)) :- !.
filter_value(round, [], A, fn(round, A)) :- !.
filter_value(round, [num(D)], A, fn(round(D), A)) :- integer(D), D >= 0, !.
filter_value(lookup, [K], str(T), lk(T, K)) :- !.
filter_value(downcase, [], A, A) :- num_type(A, T), T \== str, !.     % a number's text: the number itself
filter_value(downcase, [], str(S), str(L)) :- !, string_lower(S, L).
filter_value(timestamp_millis_print, [str("YYYY")], A, fn(year, A)) :- date_value_sv(A), !.
filter_value(Name, _, V, fx(Name, V)) :- side_effect(Name), !.
filter_value(Name, _, _, unsupported(filter(Name))).

side_effect(N) :- memberchk(N, [set_year_premium, set_year_technical_premium, set_month_premium,
    set_month_technical_premium, add_year_commission, add_month_commission,
    set_underwriting_decision, add_underwriting_note, add_fee, set_peril_tax,
    add_tax, add_premium, add_commission]).

%   A date: the policy's start or end, or a date field. Socotra passes a
%   timestamp (milliseconds) for the one and a date text for the other; the
%   twin has LE dates for both, so only what the scripts do with them (the
%   year, printed as "YYYY") is translated, and arithmetic on them is residue.
date_value_sv(in(policy_date, _)) :- !.
date_value_sv(in(Kind, F)) :-
    memberchk(Kind-Scope, [policy-policy, exposure-exposure, any_exposure-exposure, peril_field-peril]),
    g_field_type(Scope, F, date).

%   Number types, for integer division: int | float | num (unknown) | str
num_type(num(N), T) :- !, ( integer(N) -> T = int ; T = float ).
num_type(str(_), str) :- !.
num_type(in(Kind, F), T) :- !, input_type(Kind, F, T).
num_type(q(_, T), T) :- !.
num_type(lazy(_, _, Alts, Else), T) :- !,
    findall(X, ( ( member(_-SV, Alts) ; Else \== none, SV = Else ), num_type(SV, X) ), Ts), join_types(Ts, T).
num_type(fn(round, _), int) :- !.
num_type(fn(round(_), _), float) :- !.     % round: d is a double in the reference Liquid
num_type(fn(year, _), int) :- !.
num_type(lk(_, _), num) :- !.
num_type(ar(div, A, B), T) :- !, num_type(A, TA), num_type(B, TB), ( TA == int, TB == int -> T = int ; T = float ).
num_type(ar(_, A, B), T) :- !, num_type(A, TA), num_type(B, TB),
    ( TA == int, TB == int -> T = int ; ( TA == float ; TB == float ) -> T = float ; T = num ).
num_type(nil, int) :- !.
num_type(_, num).

input_type(policy, F, T) :- !, ( g_field_type(policy, F, FT) -> ftype_num(FT, T) ; T = num ).
input_type(exposure, F, T) :- !, ( g_field_type(exposure, F, FT) -> ftype_num(FT, T) ; T = num ).
input_type(any_exposure, F, T) :- !, input_type(exposure, F, T).
input_type(loop_exposure_field(_), F, T) :- !, input_type(exposure, F, T).
input_type(peril_field, F, T) :- !, ( g_field_type(peril, F, FT) -> ftype_num(FT, T) ; T = num ).
input_type(loop_peril_field(_, _), F, T) :- !, input_type(peril_field, F, T).
input_type(peril_char, _, int) :- !.
input_type(loop_peril_char(_, _), _, int) :- !.
input_type(_, _, num).

ftype_num(number, int) :- !.   % whole numbers: the product's quotes (approximated where divided)
ftype_num(select, str) :- !.
ftype_num(string, str) :- !.
ftype_num(_, num).

%   Conditions, evaluated.
eval_cond(unparsed(S), _, _, unsupported(unparsed(S))) :- !.
eval_cond(cmp(Op, A, B), Ctx, Env, cmp(Op, VA, VB)) :- !,
    eval_expr(A, Ctx, Env, VA), eval_expr(B, Ctx, Env, VB).
eval_cond(contains(A, B), Ctx, Env, contains(VA, VB)) :- !,
    eval_expr(A, Ctx, Env, VA), eval_expr(B, Ctx, Env, VB).
eval_cond(truthy(A), Ctx, Env, truthy(VA)) :- !, eval_expr(A, Ctx, Env, VA).
eval_cond(and(A, B), Ctx, Env, and(VA, VB)) :- !, eval_cond(A, Ctx, Env, VA), eval_cond(B, Ctx, Env, VB).
eval_cond(or(A, B), Ctx, Env, or(VA, VB)) :- !, eval_cond(A, Ctx, Env, VA), eval_cond(B, Ctx, Env, VB).
eval_cond(not(A), Ctx, Env, not(VA)) :- !, eval_cond(A, Ctx, Env, VA).

		 /*******************************
		 *         STATEMENTS           *
		 *******************************/

%   exec(+Stmts, +Ctx, +Path, +Env0, -Env, +Outs0, -Outs)
%   Outs: out(Kind, Args, Value, Path) of the add_* filters.
exec([], _, _, Env, Env, O, O).
exec([S|Ss], Ctx, Path, Env0, Env, O0, O) :-
    exec1(S, Ctx, Path, Env0, Env1, O0, O1),
    exec(Ss, Ctx, Path, Env1, Env, O1, O).

exec1(assign(V, E), Ctx, _, Env0, Env, O, O) :- !,
    eval_expr(E, Ctx, Env0, SV),
    put_env(V, SV, Env0, Env).
exec1(output(E), Ctx, Path, Env0, Env, O0, O) :- !,
    eval_expr_effect(E, Ctx, Env0, Effect),
    effect(Effect, Ctx, Path, Env0, Env, O0, O).
exec1(if(Branches, Else0), Ctx, Path, Env0, Env, O0, O) :- !,
    exec_branches(Branches, Else0, Ctx, Path, [], Env0, Results, Else, O0, O1),
    findall(C, member(C-_, Results), Conds),
    maplist([C, not(C)]>>true, Conds, Negs),
    append(Path, Negs, ElsePath),
    exec(Else, Ctx, ElsePath, Env0, EnvElse, O1, O),
    (   Results == [] -> Env = EnvElse
    ;   merge_envs(Ctx, Env0, Results, EnvElse, Env)
    ).
exec1(for(LV, Coll, Block), Ctx, Path, Env0, Env, O0, O) :- !,
    exec_for(LV, Coll, Block, Ctx, Path, Env0, Env, O0, O).
exec1(unsupported(T), _, _, Env, Env, O, O) :- !,
    throw(residue(unsupported_tag(T))).
exec1(_, _, _, Env, Env, O, O).

%   The branches that can be taken: a condition known false is left out, a
%   condition known true ends the chain (its block is the else).
exec_branches([], Else, _, _, _, _, [], Else, O, O).
exec_branches([C-B|Bs], Else0, Ctx, Path, Prev, Env0, Rs, Else, O0, O) :-
    eval_cond(C, Ctx, Env0, CV0),
    simplify_cond(CV0, CV),
    (   CV == false
    ->  exec_branches(Bs, Else0, Ctx, Path, Prev, Env0, Rs, Else, O0, O)
    ;   CV == true
    ->  Rs = [], Else = B, O = O0
    ;   maplist([P, not(P)]>>true, Prev, Negs),
        append([Path, Negs, [CV]], BPath),
        exec(B, Ctx, BPath, Env0, Env, O0, O1),
        Rs = [CV-Env|Rs1],
        append(Prev, [CV], Prev1),
        exec_branches(Bs, Else0, Ctx, Path, Prev1, Env0, Rs1, Else, O1, O)
    ).

%   Conditions on constants, decided now (Liquid semantics).
simplify_cond(and(A, B), C) :- !, simplify_cond(A, CA), simplify_cond(B, CB),
    ( CA == false -> C = false ; CB == false -> C = false ; CA == true -> C = CB ; CB == true -> C = CA ; C = and(CA, CB) ).
simplify_cond(or(A, B), C) :- !, simplify_cond(A, CA), simplify_cond(B, CB),
    ( CA == true -> C = true ; CB == true -> C = true ; CA == false -> C = CB ; CB == false -> C = CA ; C = or(CA, CB) ).
simplify_cond(not(A), C) :- !, simplify_cond(A, CA),
    ( CA == true -> C = false ; CA == false -> C = true ; C = not(CA) ).
simplify_cond(cmp(Op, A, B), C) :- const_val(A, VA), const_val(B, VB), !,
    ( const_cmp(Op, VA, VB) -> C = true ; C = false ).
simplify_cond(truthy(A), C) :- const_val(A, V), !,
    ( ( V == nil ; V == false ) -> C = false ; C = true ).
simplify_cond(C, C).

const_val(num(N), N).
const_val(str(S), S).
const_val(nil, nil).
const_val(bool(B), B).

const_cmp(==, A, B) :- !, ( number(A), number(B) -> A =:= B ; A == B ).
const_cmp(\=, A, B) :- !, \+ const_cmp(==, A, B).
const_cmp(Op, A, B) :- number(A), number(B), G =.. [Op, A, B], call(G).

put_env(V, SV, Env0, [V-SV|Env1]) :- exclude(same_key(V), Env0, Env1).

same_key(V, K-_) :- K == V.

%   The value an output filter is applied to, and the filter.
eval_expr_effect(filtered(P, Fs), Ctx, Env, Effect) :-
    append(Pre, [filter(Name, Args)|Post], Fs), side_effect(Name), !,
    eval_expr(filtered(P, Pre), Ctx, Env, V),
    eval_args(Args, Ctx, Env, AVs),
    ( Post == [] -> Effect = effect(Name, V, AVs) ; Effect = unsupported(filter_after_effect) ).
eval_expr_effect(filtered(_, _), _, _, none).
eval_expr_effect(unparsed(S), _, _, unsupported(unparsed(S))).

effect(none, _, _, Env, Env, O, O) :- !.
effect(unsupported(W), _, _, _, _, _, _) :- !, throw(residue(W)).
effect(effect(Name, V, Args), _, Path, Env0, Env, O0, O) :-
    (   set_kind(Name, Var)
    ->  put_env(Var, V, Env0, Env), O = O0
    ;   add_kind(Name, Kind)
    ->  Env = Env0, append(O0, [out(Kind, Args, V, Path)], O)
    ;   throw(residue(unsupported_output(Name)))
    ).

set_kind(set_year_premium, '$year_premium').
set_kind(set_year_technical_premium, '$year_technical_premium').
set_kind(set_month_premium, '$month_premium').
set_kind(set_month_technical_premium, '$month_technical_premium').
set_kind(set_underwriting_decision, '$decision').
set_kind(set_peril_tax, '$tax').

add_kind(add_year_commission, year_commission).
add_kind(add_month_commission, month_commission).
add_kind(add_underwriting_note, note).
add_kind(add_fee, fee).

		 /*******************************
		 *     MERGES -> QUANTITIES     *
		 *******************************/

merge_envs(Ctx, Env0, Results, EnvElse, Env) :-
    findall(V, ( member(_-E, Results), member(V-_, E) ), Vs0),
    findall(V, member(V-_, EnvElse), Vs1),
    append(Vs0, Vs1, Vs2), sort(Vs2, Vs),
    foldl(merge_var(Ctx, Results, EnvElse), Vs, Env0, Env).

merge_var(Ctx, Results, EnvElse, V, Env0, Env) :-
    findall(C-SV, ( member(C-E, Results), env_value(V, E, SV) ), Alts),
    env_value(V, EnvElse, SVElse),
    findall(SV, member(_-SV, Alts), SVs),
    (   forall(member(X, SVs), X == SVElse)
    ->  put_env(V, SVElse, Env0, Env)
    ;   Ctx = ctx(_, _, loop)
    ->  put_env(V, qalts(Alts, SVElse), Env0, Env)
    ;   sub_term(unsupported(W), [SVElse|SVs])
    ->  put_env(V, unsupported(W), Env0, Env)
    ;   sub_atom(V, 0, _, _, '$'), \+ memberchk(V-_, Env0), SVElse == nil
    ->  % a side-effect value set on some paths only: set there, absent elsewhere
        put_env(V, lazy(Ctx, V, Alts, none), Env0, Env)
    ;   % a quantity, written only if something reads it
        put_env(V, lazy(Ctx, V, Alts, SVElse), Env0, Env)
    ).

%   A lazy branch merge, materialised on first use (once).
:- dynamic g_materialized/2.
force_lazy(lazy(Ctx, V, Alts, Else), Q) :-
    Key = lazy(Ctx, V, Alts, Else),
    term_hash(Key, H),
    (   g_materialized(H-Key0, Q0), Key0 =@= Key -> Q = Q0
    ;   materialize(Ctx, V, Alts, Else, Q),
        assertz(g_materialized(H-Key, Q))
    ).

env_value(V, Env, SV) :- ( memberchk(V-SV0, Env) -> SV = SV0 ; SV = nil ).

%   A new quantity for variable V after a branch: one rule, an otherwise
%   cascade of the branches' conditions and values.
materialize(Ctx, V, Alts, Else, q(F, Type)) :-
    Ctx = ctx(Scope, script(File, _Label, SWords), _),
    next_id(q(File, V), K),
    ( Else == none -> AllVals = [] ; AllVals = [Else] ),
    findall(T, ( ( member(_-SV, Alts) ; member(SV, AllVals) ), num_type(SV, T) ), Ts),
    join_types(Ts, Type),
    types_noun(Ts, Noun),
    quantity_template(Scope, SWords, V, K, Noun, F, Text, Out),
    declare(F, Text, []),
    scope_head(Scope, F, Out, Head, RC),
    maplist(alt_goal(RC, Out), Alts, AltGoals),
    (   Else == none -> Goals = AltGoals
    ;   value_assign(RC, Else, Out, EG), append(AltGoals, [EG], Goals)
    ),
    cascade_body(Goals, Body),
    rule_label(File, V, K, Label),
    emit(rule(Head, Body, [label(Label), provenance([as_stated_in(File)])])),
    format(atom(In), '~w (~w)', [Text, Label]),
    ledger(File, 'branch merge', encoded,
           'if/elsif/else or case: a quantity defined by an otherwise cascade (first matching branch)',
           In, none).

%   An otherwise cascade, with the goals every alternative computes the same
%   way (the previous step's value, the fields they all read) computed once,
%   before it: each alternative would otherwise compute them again in its
%   guard and in its body, and a chain of steps would cost 2^n.
cascade_body([Single], Body) :- !,
    flat_conj(Single, L0),
    exclude(var_alias, L0, L),
    list_goal(L, Body).
cascade_body(Goals, Body) :-
    maplist(flat_conj, Goals, Lists0),
    hoist(Lists0, Hoisted, Lists),
    maplist(list_goal, Lists, Alts),
    (   Hoisted == [] -> Body = otherwise(Alts)
    ;   conj([Hoisted], H), Body = and(H, otherwise(Alts))
    ).

%   Out = E between two variables: unifies them (only safe outside a cascade).
var_alias(A = B) :- var(A), var(B), A = B.

flat_conj(and(A, B), L) :- !, flat_conj(A, LA), flat_conj(B, LB), append(LA, LB, L).
flat_conj(true, []) :- !.
flat_conj(G, [G]).

list_goal([], true) :- !.
list_goal(L, G) :- conj([L], G).

hoist([L1|Ls], [C|Hs], Out) :-
    member(C, L1),
    hoistable(C, Key, Val),
    maplist(has_goal(Key, Val), Ls, Rests),
    !,
    exclude(==(C), L1, R1),
    hoist([R1|Rests], Hs, Out).
hoist(Ls, [], Ls).

hoistable(C, Key, Val) :- functional_goal(C, Key, Val), var(Val).

has_goal(Key, Val, L, Rest) :-
    select(C, L, Rest), functional_goal(C, K2, V2), K2 == Key, var(V2), !,
    V2 = Val.

write_alt(Quant, RC, Out, Guard-SV, G) :-
    clear_loop_bindings,
    path_goals([loop(Quant)], RC, BG), cond_goals(Guard, RC, CG),
    value_assign(RC, SV, Out, VG),
    conj([BG, CG, [VG]], G),
    clear_loop_bindings.

join_types(Ts, T) :-
    (   Ts == [] -> T = num
    ;   forall(member(X, Ts), X == int) -> T = int
    ;   forall(member(X, Ts), X == str) -> T = str
    ;   member(float, Ts), \+ member(num, Ts), \+ member(int, Ts) -> T = float
    ;   T = num
    ).

alt_goal(RC, Out, C-SV, G) :-
    cond_goals(C, RC, CGs),
    value_assign(RC, SV, Out, VG),
    conj([CGs, [VG]], G).

%   The value of an output rule: a constant goes straight into its head.
output_value(RC, SV, Out, G) :-
    sv_goals(SV, RC, Gs, Expr),
    (   var(Expr) -> Out = Expr, Asg = []
    ;   ( string(Expr) ; atom(Expr) ; number(Expr) ) -> Out = Expr, Asg = []
    ;   Asg = [Out is Expr]
    ),
    conj([Gs, Asg], G).

%   Goals computing SV into Out, in an alternative of a cascade: always an
%   explicit assignment, never a unification of Out itself (which would bind
%   Out in every alternative).
value_assign(RC, SV, Out, G) :-
    sv_goals(SV, RC, Gs, Expr),
    (   var(Expr) -> Asg = [Out = Expr]
    ;   ( string(Expr) ; atom(Expr) ) -> Asg = [Out = Expr]
    ;   Asg = [Out is Expr]
    ),
    conj([Gs, Asg], G).

conj(Lists, G) :-
    append(Lists, L00),
    %  negations after the goals that bind their variables
    partition([X]>>( X = not(_) ), L00, Negs, Pos),
    append(Pos, Negs, L0),
    dedupe_goals(L0, L),
    ( L == [] -> G = true ; foldl([X, A, and(A, X)]>>true, L, first, G0), strip_first(G0, G) ).

strip_first(and(first, X), X) :- !.
strip_first(and(A, X), and(A1, X)) :- !, strip_first(A, A1).
strip_first(X, X).

%   Functional goals (a field, a characteristic, a quantity, a table entry,
%   the policy of an exposure) with the same inputs are one goal: the first,
%   so that it still comes before the comparisons reading its value.
dedupe_goals(Gs, Out) :- dedupe_goals(Gs, [], Out).

dedupe_goals([], _, []).
dedupe_goals([G|Gs], Seen, Out) :-
    (   functional_goal(G, Key, Val)
    ->  (   dup_in(Seen, Key, Val)
        ->  dedupe_goals(Gs, Seen, Out)
        ;   Out = [G|Out1], dedupe_goals(Gs, [G|Seen], Out1)
        )
    ;   Out = [G|Out1], dedupe_goals(Gs, Seen, Out1)
    ).

dup_in(Gs, Key, Val) :-
    member(G2, Gs), functional_goal(G2, Key2, Val2), Key2 == Key, !,
    Val2 = Val.

functional_goal(G, Key, Val) :-
    compound(G), G \= (_ = _), G \= (_ is _), G \= not(_), G \= and(_, _), G \= or(_, _),
    G \= otherwise(_), G \= covered_for(_, _), G \= le_is_in(_, _),
    \+ comparison(G),
    G =.. [F|Args], append(In, [Val], Args), Key =.. [F|In].

comparison(G) :- functor(G, Op, 2), memberchk(Op, [<, >, =<, >=, =:=, =\=]).

%   The head of a quantity and its rule context.
%   ValNoun: the type name of the quantity's values (types_noun/2): a
%   number, or a value when some branch gives it a text ("A", "reject").
quantity_template(peril(_, Noun), SWords, V, K, ValNoun, F, Text, _Out) :- !,
    q_words(SWords, V, K, Ws), atomic_list_concat([q|Ws], '_', F),
    words_text(Ws, W), slot(Noun, S), slot(ValNoun, VS),
    format(atom(Text), 'the ~w for ~w is ~w', [W, S, VS]).
quantity_template(tax(_), SWords, V, K, ValNoun, F, Text, _) :- !,
    q_words(SWords, V, K, Ws), atomic_list_concat([q|Ws], '_', F),
    words_text(Ws, W), slot(ValNoun, VS),
    format(atom(Text), 'the ~w for *a peril* on *an exposure* is ~w', [W, VS]).
quantity_template(policy, SWords, V, K, ValNoun, F, Text, _) :-
    q_words(SWords, V, K, Ws), atomic_list_concat([q|Ws], '_', F),
    words_text(Ws, W),
    ( V == '$decision' -> Slot = '*a decision*' ; slot(ValNoun, Slot) ),
    format(atom(Text), 'the ~w for *a policy* is ~w', [W, Slot]).

%   The type name of a quantity from the types of the values its branches
%   give: a number when every one is numeric, a value when one is a text.
types_noun(Ts, Noun) :- ( memberchk(str, Ts) -> Noun = value ; Noun = number ).

q_words(SWords, V, K, Ws) :-
    var_words(V, VWs),
    ( K =:= 1 -> Step = [] ; number_words(K, KW), append([at, step], KW, Step) ),
    append([SWords, VWs, Step], Ws).

var_words('$year_premium', [yearly, premium]) :- !.
var_words('$year_technical_premium', [yearly, technical, premium]) :- !.
var_words('$month_premium', [monthly, premium]) :- !.
var_words('$month_technical_premium', [monthly, technical, premium]) :- !.
var_words('$decision', [underwriting, decision]) :- !.
var_words('$tax', [tax]) :- !.
var_words(V, Ws) :- id_words(V, Ws).

scope_head(peril(Peril, _), F, Out, Head, rc(peril(Peril), E, _Pol)) :- Head =.. [F, E, Out].
scope_head(tax(_), F, Out, Head, rc(tax, E-P, _Pol)) :- Head =.. [F, P, E, Out].
scope_head(policy, F, Out, Head, rc(policy, _E, Pol)) :- Head =.. [F, Pol, Out].

rule_label(File, V, K, Label) :-
    file_base_name(File, B), atomic_list_concat([B0|_], '.', B), id_words(B0, BW),
    var_words(V, VW), atomic_list_concat(BW, '_', BA), atomic_list_concat(VW, '_', VA),
    format(atom(Label), '~w_~w_~w', [BA, VA, K]).

		 /*******************************
		 *   SYMBOLIC VALUE -> GOALS    *
		 *******************************/

%   sv_goals(+SV, +RC, -Goals, -Expr): Goals bind what SV reads; Expr is its
%   value (a variable, a constant or an arithmetic expression).
%   RC: rc(Scope, E, Pol) — E the exposure (or E-P for a tax), Pol the policy.
sv_goals(num(N), _, [], N) :- !.
sv_goals(str(S), _, [], V) :- !, le_value(S, V).
sv_goals(nil, _, [], 0) :- !.
sv_goals(bool(true), _, [], 1) :- !.
sv_goals(bool(false), _, [], 0) :- !.
sv_goals(in(policy, F), RC, Gs, V) :- !,
    t_policy_field(F, Fn), policy_var(RC, Pol, PGs),
    G =.. [Fn, Pol, V], append(PGs, [G], Gs).
sv_goals(in(exposure, F), RC, [G], V) :- !,
    t_exposure_field(F, Fn), exposure_var(RC, E), G =.. [Fn, E, V].
sv_goals(in(any_exposure, F), RC, Gs, V) :- !,
    t_exposure_field(F, Fn), policy_var(RC, Pol, PGs), t_insured(Ins),
    IG =.. [Ins, Ex, Pol], G =.. [Fn, Ex, V],
    append(PGs, [IG, G], Gs),
    note_approx(first_exposure).
sv_goals(in(peril_char, C), RC, [G], V) :- !,
    t_peril_char(C, Fn), peril_args(RC, P, E), G =.. [Fn, P, E, V].
sv_goals(in(peril_field, F), RC, [G], V) :- !,
    t_peril_field(F, Fn), peril_args(RC, P, E), G =.. [Fn, P, E, V].
sv_goals(in(peril_premium, _), RC, [G], V) :- !,
    output_functor(year_premium, Fn), peril_args(RC, P, E), G =.. [Fn, P, E, V],
    note_approx(peril_premium).
sv_goals(in(gross_taxes, _), RC, Gs, V) :- !,
    declare(out_gross_taxes, 'the gross taxes of *a policy* is *an amount*', []),
    policy_var(RC, Pol, PGs), append(PGs, [out_gross_taxes(Pol, V)], Gs).
sv_goals(in(gross_premium, _), RC, Gs, V) :- !,
    output_functor(gross_premium, Fn), policy_var(RC, Pol, PGs), G =.. [Fn, Pol, V], append(PGs, [G], Gs).
sv_goals(in(loop_exposure_field(L), F), RC, [G], V) :- !,
    t_exposure_field(F, Fn), loop_var(RC, L, Ex), G =.. [Fn, Ex, V].
sv_goals(in(loop_peril_field(P, L), F), RC, [G], V) :- !,
    t_peril_field(F, Fn), loop_var(RC, L, Ex), loop_var(RC, P, Pe), G =.. [Fn, Pe, Ex, V].
sv_goals(in(loop_peril_char(P, L), C), RC, [G], V) :- !,
    t_peril_char(C, Fn), loop_var(RC, L, Ex), loop_var(RC, P, Pe), G =.. [Fn, Pe, Ex, V].
sv_goals(q(F, _), RC, [G], V) :- !,
    RC = rc(Scope, E, Pol),
    (   Scope = peril(_) -> G =.. [F, E, V]
    ;   Scope == tax -> E = Ex-P, G =.. [F, P, Ex, V]
    ;   G =.. [F, Pol, V]
    ).
sv_goals(ar(_, A, B), _, _, _) :-
    ( date_value_sv(A) ; date_value_sv(B) ), !,
    throw(residue(date_arithmetic)).
sv_goals(ar(Op, A, B), RC, Gs, Expr) :- !,
    sv_goals(A, RC, GA, EA), sv_goals(B, RC, GB, EB),
    append(GA, GB, Gs),
    arith_op(Op, A, B, POp),
    num_operand(EA, EA1), num_operand(EB, EB1),
    Expr =.. [POp, EA1, EB1].
sv_goals(fn(year, A), RC, Gs, Y) :- !,
    sv_goals(A, RC, GA, D),
    declare(year_of, 'the year of *a date* is *a number*', [included]),
    append(GA, [year_of(D, Y)], Gs).
sv_goals(in(policy_date, W), RC, Gs, V) :- !,
    t_policy_date(W, Fn), policy_var(RC, Pol, PGs),
    G =.. [Fn, Pol, V], append(PGs, [G], Gs).
sv_goals(fn(round, A), RC, Gs, round(EA)) :- !,
    sv_goals(A, RC, Gs, EA0), num_operand(EA0, EA).
%   round: d, as the reference Liquid computes it: half away from zero at d
%   decimals, a double (round(x * 10^d) / 10^d, the divisor a double).
sv_goals(fn(round(D), A), RC, Gs, round(EA * M) / MF) :- !,
    sv_goals(A, RC, Gs, EA0), num_operand(EA0, EA),
    M is 10 ^ D, MF is float(M).
sv_goals(lk(T, _), _, [], 0) :-
    atom_string(TA, T), \+ g_table_exists(TA), !,
    format(atom(M), 'looks up table ~w, which the product does not have: Liquid reads nil (0 in arithmetic)', [TA]),
    ( g_ledger(entry(_, 'source defect', _, M, _, _)) -> true
    ; ledger(TA, 'source defect', approximated, M, 0, 'the twin reads 0 too') ).
sv_goals(lk(T, K), RC, Gs, V) :- !,
    sv_goals(K, RC, GK, EK),
    (   compound(EK) -> KV = KX, KG = [KX is EK] ; KV = EK, KG = [] ),
    atom_string(TA, T), lookup_functor(TA, Fn), G =.. [Fn, KV, V],
    append([GK, KG, [G]], Gs).
sv_goals(L, RC, Gs, E) :- L = lazy(_, _, _, _), !, force_lazy(L, Q), sv_goals(Q, RC, Gs, E).
sv_goals(unsupported(W), _, _, _) :- !, throw(residue(W)).
sv_goals(SV, _, _, _) :- throw(residue(value(SV))).

%   A string cannot take part in arithmetic.
num_operand(E, E) :- ( var(E) ; number(E) ; compound(E) ), !.
num_operand(E, _) :- throw(residue(string_in_arithmetic(E))).

arith_op(*, _, _, *).
arith_op(+, _, _, +).
arith_op(-, _, _, -).
arith_op(div, A, B, Op) :-
    num_type(A, TA), num_type(B, TB),
    (   TA == int, TB == int -> Op = (//), note_approx(integer_division)
    ;   ( TA == float ; TB == float ) -> Op = (/)
    ;   Op = (/), note_approx(division_type_unknown)
    ).

note_approx(What) :- ( g_counter(approx(What), _) -> true ; assertz(g_counter(approx(What), 1)) ).

policy_var(rc(policy, _, Pol), Pol, []) :- !.
policy_var(rc(peril(_), E, Pol), Pol, [G]) :- !, t_insured(F), G =.. [F, E, Pol].
policy_var(rc(tax, E-_, Pol), Pol, [G]) :- !, t_insured(F), G =.. [F, E, Pol].
policy_var(rc(_, _, Pol), Pol, []).

exposure_var(rc(peril(_), E, _), E) :- !.
exposure_var(rc(tax, E-_, _), E) :- !.
exposure_var(_, _) :- throw(residue(exposure_outside_exposure_scope)).

peril_args(rc(peril(P), E, _), P, E) :- !.
peril_args(rc(tax, E-P, _), P, E) :- !.
peril_args(_, _, _) :- throw(residue(peril_outside_peril_scope)).

%   Loop items: variables bound while the goals of a loop guard are built
%   (kept with b_setval/2, which does not copy: an asserted binding would
%   come back as a stranger).
loop_var(_, L, V) :-
    (   nb_current(loop_bindings, Bs), is_list(Bs), memberchk(L-V0, Bs) -> V = V0
    ;   throw(residue(loop_item_outside_loop(L)))
    ).

bind_loop(L, V) :-
    ( nb_current(loop_bindings, Bs0), is_list(Bs0) -> true ; Bs0 = [] ),
    b_setval(loop_bindings, [L-V|Bs0]).

clear_loop_bindings :- b_setval(loop_bindings, []).

quant_goals(RC, Qs, BGs) :- maplist(quant_goal(RC), Qs, BGss), append(BGss, BGs).
quant_goal(RC, Q, BG) :- path_goals([loop(Q)], RC, BG).

%   Conditions -> goals (a list: a conjunction).
cond_goals(C0, RC, Gs) :-
    simplify_cond(C0, C),
    (   C == false -> throw(dead_path)
    ;   cond_goals_(C, RC, Gs0), dedupe_goals(Gs0, Gs)
    ).

cond_goals_(true, _, []) :- !.
cond_goals_(not(C), RC, [not(G)]) :- !, cond_goals_(C, RC, Gs), conj([Gs], G).
cond_goals_(and(A, B), RC, Gs) :- !, cond_goals_(A, RC, GA), cond_goals_(B, RC, GB), append(GA, GB, Gs).
cond_goals_(or(A, B), RC, [or(GA, GB)]) :- !,
    cond_goals_(A, RC, LA), cond_goals_(B, RC, LB), conj([LA], GA), conj([LB], GB).
cond_goals_(unsupported(W), _, _) :- !, throw(residue(W)).
cond_goals_(exists(Qs, G), RC, Gs) :- !,
    quant_goals(RC, Qs, BGs),
    cond_goals_(G, RC, GGs), append(BGs, GGs, Gs).
cond_goals_(cmp(==, A, B), RC, Gs) :- equality_kind(A, B, RC, Gs), !.
cond_goals_(cmp(==, B, A), RC, Gs) :- equality_kind(A, B, RC, Gs), !.
cond_goals_(cmp(\=, A, B), RC, [not(G)]) :- equality_kind(A, B, RC, Gs), !, conj([Gs], G).
cond_goals_(cmp(Op, A, nil), RC, Gs) :- !, nil_test(Op, A, RC, Gs).
cond_goals_(cmp(Op, nil, A), RC, Gs) :- !, nil_test(Op, A, RC, Gs).
cond_goals_(cmp(==, A, B), RC, Gs) :- !, equality(A, B, RC, Gs).
cond_goals_(cmp(\=, A, B), RC, [not(G)]) :- !, equality(A, B, RC, Gs0), conj([Gs0], G).
cond_goals_(cmp(Op, A, B), RC, Gs) :- !,
    sv_goals(A, RC, GA, EA), sv_goals(B, RC, GB, EB),
    num_operand(EA, EA1), num_operand(EB, EB1),
    G =.. [Op, EA1, EB1], append([GA, GB, [G]], Gs).
cond_goals_(contains(A, str(S)), RC, Gs) :- !,
    contains_values(A, S, Vals),
    sv_goals(A, RC, GA, EA),
    append(GA, [le_is_in(EA, Vals)], Gs).
cond_goals_(truthy(A), RC, GA) :- !, sv_goals(A, RC, GA, _).
cond_goals_(C, _, _) :- throw(residue(condition(C))).

nil_test(==, A, RC, [not(G)]) :- !, sv_goals(A, RC, GA, _), conj([GA], G).
nil_test(\=, A, RC, GA) :- !, sv_goals(A, RC, GA, _).
nil_test(Op, _, _, _) :- throw(residue(nil_comparison(Op))).

%   a == "Direct": the field goal with the constant in its place.
equality(A, B, RC, Gs) :-
    (   const_sv(B) -> X = A, K = B ; const_sv(A) -> X = B, K = A ; X = none ),
    (   X \== none
    ->  sv_goals(X, RC, GX, EX), sv_goals(K, RC, [], EK),
        (   var(EX) -> EX = EK, Gs = GX
        ;   append(GX, [EX =:= EK], Gs)
        )
    ;   sv_goals(A, RC, GA, EA), sv_goals(B, RC, GB, EB),
        append([GA, GB, [EA = EB]], Gs)
    ).

const_sv(num(_)).
const_sv(str(_)).
const_sv(bool(_)).

%   `field contains "Yes"` on a select field: the field's value is one of the
%   select values that contain the text (the values are enumerated).
contains_values(in(Kind, F), S, Vals) :-
    kind_scope(Kind, Scope), g_select(Scope, F, All), !,
    include(contains_text(S), All, Vals0),
    maplist(le_value, Vals0, Vals).
contains_values(A, _, _) :- throw(residue(contains_on(A))).

contains_text(S, V) :- format(string(VS), '~w', [V]), sub_string(VS, _, _, _, S).

kind_scope(policy, policy).
kind_scope(exposure, exposure).
kind_scope(any_exposure, exposure).
kind_scope(loop_exposure_field(_), exposure).
kind_scope(peril_field, peril).
kind_scope(loop_peril_field(_, _), peril).

		 /*******************************
		 *            LOOPS             *
		 *******************************/

%   A for loop over the policy's exposures (or an exposure's perils). The
%   body runs once, symbolically, on a generic item; inside it a branch merge
%   is not a quantity but a conditional value qalts(Alts, Else). What the
%   body may do to the enclosing scope: add outputs (each rule then reads
%   "for some exposure of the policy ..."), write a side-effect variable (the
%   underwriting decision: written when some item satisfies the guard), and
%   accumulate into a variable defined before the loop (x = x | plus: e: an
%   aggregate). Anything else is residue.
exec_for(LV, Coll, Block, Ctx, Path, Env0, Env, O0, O) :-
    Ctx = ctx(_, Script, _),
    eval_expr(Coll, Ctx, Env0, CV),
    (   CV == nil
    ->  % a loop over an undefined collection: Liquid iterates nothing
        Env = Env0, O = O0,
        Script = script(File, _, _),
        ledger(File, 'source defect', encoded, 'a for loop over an undefined variable: Liquid runs its body for no item; the twin has no rule for it', LV, none)
    ;   exec_for_(LV, CV, Block, Ctx, Path, Env0, Env, O0, O)
    ).

exec_for_(LV, CV, Block, Ctx, Path, Env0, Env, O0, O) :-
    Ctx = ctx(Scope, Script, Mode),
    loop_item(CV, LV, Item, Quant),
    put_env(LV, obj(Item), Env0, EnvL),
    append(Path, [loop(Quant)], LPath),
    exec(Block, ctx(Scope, Script, loop), LPath, EnvL, EnvB, O0, O),
    findall(V-SV, ( member(V-SV, EnvB), V \== LV,
                    ( memberchk(V-SV0, Env0) -> SV \== SV0 ; sub_atom(V, 0, _, _, '$') ) ),
            Changed),
    foldl(loop_result(Ctx, Mode, Quant, Env0), Changed, Env0, Env1),
    % a variable first assigned inside the loop and read after it (the last
    % item's value): not modelled
    findall(V, ( member(V-_, EnvB), V \== LV, \+ memberchk(V-_, Env0), \+ sub_atom(V, 0, _, _, '$') ), New),
    foldl([V, E0, E]>>put_env(V, unsupported(loop_defined(V)), E0, E), New, Env1, Env).

loop_item(obj(exposures), LV, loop_exposure(LV), exposures(LV)) :- !.
loop_item(obj(loop_perils(L)), LV, loop_peril(LV, L), perils(LV, L)) :- !.
loop_item(obj(first_exposure_perils), LV, loop_peril(LV, first), perils(LV, first)) :- !.
loop_item(CV, _, _, _) :- throw(residue(loop_over(CV))).

%   The guarded values a variable ends with, relative to its value Before:
%   first matching branch first (each guard carries the negations of the
%   earlier ones); a path on which it keeps its value is left out.
flatten_value(SV, Before, []) :- SV == Before, !.
flatten_value(qalts(Alts, Else), Before, Pairs) :- !,
    flatten_alts(Alts, [], Before, P1),
    findall(not(G), member(G-_, Alts), Negs),
    flatten_value(Else, Before, P2),
    conj_conds(Negs, NG),
    maplist(guard_with(NG), P2, P2g),
    append(P1, P2g, Pairs).
flatten_value(SV, _, [true-SV]).

flatten_alts([], _, _, []).
flatten_alts([G-V|As], Prev, Before, Pairs) :-
    maplist([P, not(P)]>>true, Prev, Negs),
    conj_conds([G|Negs], Guard),
    flatten_value(V, Before, Inner),
    maplist(guard_with(Guard), Inner, P1),
    append(Prev, [G], Prev1),
    flatten_alts(As, Prev1, Before, P2),
    append(P1, P2, Pairs).

guard_with(G0, G-V, and(G0, G)-V).

conj_conds([], true).
conj_conds([C], C) :- !.
conj_conds([C|Cs], and(C, R)) :- conj_conds(Cs, R).

%   V's value after the loop.
loop_result(Ctx, Mode, Quant, Env0, V-SV, E0, E) :-
    env_value(V, Env0, Before),
    flatten_value(SV, Before, Pairs),
    (   Pairs \== [],
        forall(member(_-X, Pairs), ( X = ar(+, B, _), B == Before ))
    ->  findall(sum([Quant], G, T), member(G-ar(+, _, T), Pairs), Sums0),
        maplist(flatten_sum, Sums0, Sums),
        (   Mode == loop
        ->  foldl([S, A, ar(+, A, S)]>>true, Sums, Before, New)
        ;   aggregate_quantity(Ctx, V, Before, Sums, New)
        ),
        put_env(V, New, E0, E)
    ;   sub_atom(V, 0, _, _, '$')
    ->  (   Mode == loop
        ->  findall(exists([Quant], G)-X, member(G-X, Pairs), NA),
            put_env(V, qalts(NA, Before), E0, E)
        ;   exists_quantity(Ctx, Quant, V, Pairs, Before, New),
            put_env(V, New, E0, E)
        )
    ;   throw(residue(loop_carried_variable(V)))
    ).

%   A sum whose term is itself a sum over an inner loop: one sum over both.
flatten_sum(sum(Qs, G, sum(Qs2, G2, T)), S) :- !,
    append(Qs, Qs2, Qs3), flatten_sum(sum(Qs3, and(G, G2), T), S).
flatten_sum(S, S).

		 /*******************************
		 *   RULES FOR THE OUTPUTS      *
		 *******************************/

%   The rule context for a rule of the script.
new_rc(peril(Peril, _), rc(peril(Peril), _E, _Pol)).
new_rc(tax(_), rc(tax, _E-_P, _Pol)).
new_rc(policy, rc(policy, _E, _Pol)).

%   Path conditions (a loop quantifier first binds the item).
path_goals([], _, []).
path_goals([loop(Q)|Ps], RC, Gs) :- !,
    loop_bind(Q, RC, BGs), path_goals(Ps, RC, G1), append(BGs, G1, Gs).
path_goals([C|Ps], RC, Gs) :-
    cond_goals(C, RC, G0), path_goals(Ps, RC, G1), append(G0, G1, Gs).

loop_bind(exposures(L), RC, [G]) :-
    policy_var(RC, Pol, _), t_insured(F), G =.. [F, Ex, Pol],
    bind_loop(L, Ex).
loop_bind(perils(P, L), RC, Gs) :-
    ( L == first -> loop_bind(exposures(first), RC, G0) ; G0 = [] ),
    loop_var(RC, L, Ex), t_covered(F), G =.. [F, Ex, Pe],
    bind_loop(P, Pe), append(G0, [G], Gs).

%   A test of a loop item's kind: exp.name == "dwelling".
equality_kind(in(exposure_kind, L), str(S), RC, [is_a(Ex, Noun)]) :-
    loop_var(RC, L, Ex), exposure_noun_by_name(S, Noun).
equality_kind(in(peril_name, P-_), str(S), RC, []) :-
    loop_var(RC, P, Pe), name_constant(S, Pe).

exposure_noun_by_name(S, Noun) :- atom_string(A, S), exposure_noun(A, Noun).

%   The output rules of a script, once it has run.
script_outputs(Ctx, Env, Outs) :-
    Ctx = ctx(Scope, script(_, Label, _), _),
    forall(member(V-SV, Env), ( sub_atom(V, 0, _, _, '$'), SV \== nil -> set_output(Ctx, V, SV) ; true )),
    forall(nth1(I, Outs, Out), catch(add_output(Ctx, I, Out), dead_path, true)),
    ignore(Label = Scope).

set_output(Ctx, Var, SV) :-
    Ctx = ctx(Scope, script(File, _, _), _),
    set_head(Scope, Var, SV, File, Head, Out, RCGoals, RC),
    output_value(RC, SV, Out, VG),
    conj([RCGoals, [VG]], Body),
    rule_label(File, Var, final, Label),
    emit(rule(Head, Body, [label(Label), provenance([as_stated_in(File)])])),
    ledger(File, 'output', encoded, 'set_* filter: the conclusion of a rule', Label, none).

set_head(peril(Peril, _), '$year_premium', _, _, H, Out, [G], rc(peril(Peril), E, _)) :- !,
    output_functor(year_premium, F), H =.. [F, Peril, E, Out], t_covered(C), G =.. [C, E, Peril].
set_head(peril(Peril, _), '$year_technical_premium', _, _, H, Out, [G], rc(peril(Peril), E, _)) :- !,
    output_functor(year_technical_premium, F), H =.. [F, Peril, E, Out], t_covered(C), G =.. [C, E, Peril].
set_head(peril(Peril, _), '$month_premium', _, _, H, Out, [G], rc(peril(Peril), E, _)) :- !,
    output_functor(month_premium, F), H =.. [F, Peril, E, Out], t_covered(C), G =.. [C, E, Peril].
set_head(peril(Peril, _), '$month_technical_premium', _, _, H, Out, [G], rc(peril(Peril), E, _)) :- !,
    output_functor(month_technical_premium, F), H =.. [F, Peril, E, Out], t_covered(C), G =.. [C, E, Peril].
set_head(tax(Tax), '$tax', _, _, H, Out, [G], rc(tax, E-P, _)) :- !,
    tax_functor(Tax, F), H =.. [F, P, E, Out],
    output_functor(year_premium, YP), G =.. [YP, P, E, _].
set_head(policy, '$decision', _, _, H, Out, [is_a(Pol, policy)], rc(policy, _, Pol)) :- !,
    output_functor(decision, F), H =.. [F, Pol, Out].
set_head(_, Var, _, _, _, _, _, _) :- throw(residue(output_in_wrong_scope(Var))).

add_output(Ctx, I, out(Kind, Args, SV, Path)) :-
    Ctx = ctx(Scope, script(File, _, _), _),
    clear_loop_bindings,
    new_rc(Scope, RC0), RC0 = RC,
    add_head(Scope, Kind, Args, RC, File, Head, Out, BindGs),
    path_goals(Path, RC, PGs),
    output_value(RC, SV, Out, VG),
    conj([BindGs, PGs, [VG]], Body),
    format(atom(Tag), '~w_~w', [Kind, I]),
    rule_label(File, Tag, final, Label),
    emit(rule(Head, Body, [label(Label), provenance([as_stated_in(File)])])),
    (   Kind == fee, Args = [str(FeeName), str(Desc)|_]
    ->  % the fee's description, under the same conditions
        atom_string(FN, FeeName), fee_desc_functor(FN, DF),
        Head =.. [_, Pol|_], DHead =.. [DF, Pol, DOut],
        le_value(Desc, DV), DOut = DV,
        conj([BindGs, PGs], DBody),
        atom_concat(Label, '_description', DLabel),
        emit(rule(DHead, DBody, [label(DLabel), provenance([as_stated_in(File)])]))
    ;   true
    ),
    clear_loop_bindings,
    ledger(File, 'output', encoded, 'add_* filter: the conclusion of a rule, under the conditions of its branch', Label, none).

add_head(peril(Peril, _), year_commission, [Who], rc(peril(Peril), E, _Pol), _, H, Out, Gs) :- !,
    commission_head(year_commission, Peril, Who, E, H, Out, Gs).
add_head(peril(Peril, _), month_commission, [Who], rc(peril(Peril), E, _Pol), _, H, Out, Gs) :- !,
    commission_head(month_commission, Peril, Who, E, H, Out, Gs).
add_head(policy, note, [], rc(policy, _, Pol), _, H, Out, [is_a(Pol, policy)]) :- !,
    output_functor(note, F), H =.. [F, Pol, Out].
add_head(policy, fee, [str(Name)|_], rc(policy, _, Pol), _, H, Out, [is_a(Pol, policy)]) :- !,
    atom_string(N, Name), fee_functor(N, F), H =.. [F, Pol, Out].
add_head(_, Kind, _, _, _, _, _, _) :- throw(residue(output_in_wrong_scope(Kind))).

commission_head(Kind, Peril, Who, E, H, Out, Gs) :-
    output_functor(Kind, F), t_covered(C), G =.. [C, E, Peril],
    (   Who = str(S) -> le_value(S, WV), H =.. [F, WV, Peril, E, Out], Gs = [G]
    ;   % the recipient is a field of the policy (a broker's name)
        sv_goals(Who, rc(peril(Peril), E, _), WGs, WV), var(WV)
    ->  H =.. [F, WV, Peril, E, Out], append([G], WGs, Gs)
    ;   throw(residue(commission_recipient(Who)))
    ).

		 /*******************************
		 *   QUANTITIES OF LOOPS        *
		 *******************************/

%   x_after = x_before + (the sum of each e over the items whose guard holds)
aggregate_quantity(Ctx, V, Before, Sums, q(F, Type)) :-
    Ctx = ctx(Scope, script(File, _, SWords), _),
    next_id(q(File, V), K),
    findall(TT, ( member(sum(_, _, T), Sums), num_type(T, TT) ), TTs),
    num_type(Before, TB), join_types([TB|TTs], Type),
    quantity_template(Scope, SWords, V, K, number, F, Text, Out),
    declare(F, Text, []),
    scope_head(Scope, F, Out, Head, RC),
    maplist(sum_goal(RC), Sums, SumGoals, SumVars),
    sv_goals(Before, RC, BGs, BE),
    foldl([S, A, A + S]>>true, SumVars, BE, Expr),
    ( Scope == policy -> RC = rc(_, _, Pol), Bind = [is_a(Pol, policy)] ; Bind = [] ),
    append([Bind, BGs, SumGoals, [Out is Expr]], L),
    conj([L], Body),
    rule_label(File, V, K, Label),
    emit(rule(Head, Body, [label(Label), provenance([as_stated_in(File)])])),
    ledger(File, 'loop', encoded, 'for loop accumulating x = x | plus: e: the sum of each e over the items', Label, none).

sum_goal(RC, sum(Qs, G, T), agg(sum, Elem, AggGoal, S), S) :-
    clear_loop_bindings,
    quant_goals(RC, Qs, BGs),
    cond_goals(G, RC, GGs),
    sv_goals(T, RC, TGs, TE),
    ( var(TE) -> Elem = TE, EGs = [] ; EGs = [Elem is TE] ),
    conj([BGs, GGs, TGs, EGs], AggGoal),
    clear_loop_bindings.

%   A side-effect variable written in a loop: the first write (in reverse
%   order of the source) whose guard some item satisfies, else its value
%   before the loop.
exists_quantity(Ctx, Quant, V, Pairs, Before, q(F, Type)) :-
    Writes = Pairs,
    Ctx = ctx(Scope, script(File, _, SWords), _),
    next_id(q(File, V), K),
    findall(T, ( ( member(_-SV, Pairs) ; Before \== nil, SV = Before ), num_type(SV, T) ), Ts),
    ( Ts == [] -> Type = str ; join_types(Ts, Type) ),
    ( Ts == [] -> Noun = value ; types_noun(Ts, Noun) ),
    quantity_template(Scope, SWords, V, K, Noun, F, Text, Out),
    declare(F, Text, []),
    scope_head(Scope, F, Out, Head, RC),
    reverse(Writes, RW),
    maplist(write_alt(Quant, RC, Out), RW, Alts),
    clear_loop_bindings,
    (   Before == nil -> Goals = Alts
    ;   value_assign(RC, Before, Out, EG), append(Alts, [EG], Goals)
    ),
    cascade_body(Goals, Body0),
    ( Scope == policy -> RC = rc(_, _, Pol), Body = and(is_a(Pol, policy), Body0) ; Body = Body0 ),
    rule_label(File, V, K, Label),
    emit(rule(Head, Body, [label(Label), provenance([as_stated_in(File)])])),
    ledger(File, 'loop', approximated,
           'a decision written inside a loop: written when SOME item satisfies its condition',
           Label, 'the order in which the items are visited is not modelled').

		 /*******************************
		 *        SCRIPTS -> IR         *
		 *******************************/

:- dynamic g_table_exists/1.

%!  compile_script(+File, +Scope, +SWords, -Status) is det.
%
%   Status: translated, or residue(Reason) — then the script is a residue
%   block and its outputs are left to the Contract Assistant.
compile_script(File0, Scope, SWords, Status) :-
    liquid_parse_file(File0, Stmts),
    display_path(File0, File),
    Ctx = ctx(Scope, script(File, File, SWords), top),
    b_setval(socotra_script, File),
    catch(transaction(( exec(Stmts, Ctx, [], [], Env, [], Outs),
                        script_outputs(Ctx, Env, Outs) )),
          residue(Why), true),
    clear_loop_bindings,
    (   var(Why)
    ->  Status = translated,
        ledger(File, script, encoded, 'Liquid script: symbolic execution into rules', 'the rules labelled with its name', none)
    ;   Status = residue(Why),
        residue_script(File0, File, Scope, Why)
    ).

%   A source file as the ledger and the provenance name it: its path in the
%   product library (`Personal Auto/policy/...`).
display_path(File, D) :-
    (   g_display_root(Root), atom_concat(Root, '/', RS), atom_concat(RS, D0, File)
    ->  D = D0
    ;   sub_atom(File, B, _, _, 'product-library/')
    ->  sub_atom(File, B, _, 0, D0), atom_concat('product-library/', D, D0)
    ;   file_base_name(File, D)
    ).

%   The directory the display paths are relative to: the product library,
%   or the folder an imported configuration was unpacked in
%   (set_display_root/1).
:- dynamic g_display_root/1.
set_display_root(R) :- retractall(g_display_root(_)), ( R == none -> true ; assertz(g_display_root(R)) ).

display_root(ProductDir, Root) :-
    (   g_display_root(Root0) -> Root = Root0
    ;   file_directory_name(ProductDir, Root)
    ).

%!  compile_script_text(+Text, +Scope, -Items, -Ledger) is det.
%
%   One script, from its text, for the tests.
compile_script_text(Text, Scope, Items, Ledger) :-
    reset_gen,
    tmp_file_stream(text, File, S), write(S, Text), close(S),
    compile_script(File, Scope, [script], _),
    findall(I, ( g_template(F, T, A), declaration_item(F, T, A, I) ), Ts),
    findall(I, g_item(I), Is),
    append(Ts, Is, Items),
    findall(E, g_ledger(E), Ledger),
    delete_file(File).

residue_script(File0, File, Scope, Why) :-
    read_file_to_string(File0, Code, [encoding(utf8)]),
    next_id(residue, N), format(atom(Id), 'r~w', [N]),
    residue_outputs(Scope, Code, Conclusions),
    residue_fields(Code, Read),
    why_text(Why, WhyT),
    atomic_list_concat(Conclusions, '; ', CT),
    (   Read == []
    ->  format(string(Note), "Not translated: ~w.~nConclude: ~w.", [WhyT, CT])
    ;   atomic_list_concat(Read, '; ', RT),
        format(string(Note), "Not translated: ~w.~nConclude: ~w.~nThe quotes state: ~w.", [WhyT, CT, RT])
    ),
    residue_functors(Scope, Code, Fs),
    emit(residue(Id, [title(File), locator(File), note(Note), source(liquid, Code), concludes(Fs)])),
    format(atom(LNote), '~w; the quotes'' expectations of what it concludes (and of what depends on it: taxes, gross premium, fees) fail until it is translated, and the facts the quotes state for it (and a peril only it prices) are data no rule reads until then, which the verifier reports', [WhyT]),
    ledger(File, script, residue, 'Liquid script the symbolic execution cannot read', Id, LNote).

%   Why a script is residue, in words.
why_text(loop_defined(V), T) :- !,
    format(atom(T), 'the variable ~w is assigned inside a loop and read after it (Liquid keeps the last item''s value)', [V]).
why_text(loop_over(in(K, F)), T) :- !,
    format(atom(T), 'a loop over the ~w field ~w, a repeatable field group (its items are read through field_groups_by_locator)', [K, F]).
why_text(loop_over(X), T) :- !, format(atom(T), 'a loop over ~q', [X]).
why_text(policy_characteristic(K), T) :- !,
    format(atom(T), 'it reads the policy characteristic ~w, which the twin does not model', [K]).
why_text(filter(F), T) :- !, format(atom(T), 'it uses the filter ~w, which the translator does not know', [F]).
why_text(date_arithmetic, 'arithmetic on a date (a timestamp in Socotra)') :- !.
why_text(string_in_arithmetic(S), T) :- !, format(atom(T), 'the text ~q in arithmetic', [S]).
why_text(unsupported_tag(G), T) :- !, format(atom(T), 'the Liquid tag ~q', [G]).
why_text(W, T) :- format(atom(T), '~q', [W]).

%   The fields a residue script reads, declared so that the quotes state
%   them and the assistant can read them.
residue_fields(Code, Texts) :-
    findall(Text, ( g_field_type(Scope, F, _), atom_length(F, L), L > 2,
                    atom_string(F, FS), string_concat(".", FS, Dot), sub_string(Code, B, _, A, Dot),
                    B >= 0,
                    \+ ( A > 0, A1 is A - 1, sub_string(Code, _, 1, A1, C), string_chars(C, [Ch]), char_type(Ch, csym) ),
                    residue_field_template(Scope, F, Fn),
                    g_template(Fn, Text, _) ),
            Texts0),
    sort(Texts0, Texts).

residue_field_template(policy, F, Fn) :- t_policy_field(F, Fn).
residue_field_template(exposure, F, Fn) :- t_exposure_field(F, Fn).
residue_field_template(peril, F, Fn) :- t_peril_field(F, Fn).

%   The conclusions a residue script must reach, declared so the assistant
%   can write rules for them.
residue_outputs(Scope, Code, Cs) :-
    findall(C, ( residue_filter(Name, Kind), sub_string(Code, _, _, _, Name),
                 residue_conclusion(Scope, Kind, C) ), Cs0),
    ( Cs0 == [] -> Cs = ['(nothing the twin reads)'] ; sort(Cs0, Cs) ).

%   The IR functors of what the script concludes: the expectations that
%   depend on them are pending until it is translated (le_migration).
residue_functors(Scope, Code, Fs) :-
    findall(F, ( residue_filter(Name, Kind), sub_string(Code, _, _, _, Name),
                 ( Scope = tax(T) -> tax_functor(T, F) ; output_functor(Kind, F) ) ), Fs0),
    sort(Fs0, Fs).

residue_filter("set_year_premium", year_premium).
residue_filter("set_year_technical_premium", year_technical_premium).
residue_filter("set_month_premium", month_premium).
residue_filter("set_month_technical_premium", month_technical_premium).
residue_filter("add_year_commission", year_commission).
residue_filter("add_month_commission", month_commission).
residue_filter("set_underwriting_decision", decision).
residue_filter("add_underwriting_note", note).

residue_conclusion(peril(P, _), Kind, C) :-
    output_functor(Kind, F), g_template(F, Text, _),
    format(atom(C), '~w (the peril: ~w)', [Text, P]).
residue_conclusion(policy, Kind, C) :-
    output_functor(Kind, F), g_template(F, C, _).
residue_conclusion(tax(T), _, C) :- tax_functor(T, F), g_template(F, C, _).

		 /*******************************
		 *        THE PRODUCT           *
		 *******************************/

%!  product_migration(+ProductDir, +OracleJSON, -Migration) is det.
%!  product_migration(+ProductDir, +OracleJSON, +Options, -Migration) is det.
%
%   Options: declare_fields(true) declares a template for every policy and
%   exposure field, read by a rule or not (a configuration with no scripts,
%   such as a lone policy.json, has only its fields to show).
product_migration(ProductDir, OracleFile, M) :-
    product_migration(ProductDir, OracleFile, [], M).

product_migration(ProductDir, OracleFile, Options, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    reset_gen,
    retractall(g_table_exists(_)),
    product_model(ProductDir, Model),
    Model = model(Name, PolicyDir, PFields, Exps, Tables, Taxes, Fees),
    forall(member(table(T, _, _, _), Tables), assertz(g_table_exists(T))),
    register_fields(PFields, Exps),
    (   memberchk(declare_fields(true), Options)
    ->  forall(( member(F, PFields), field_name(F, N) ), t_policy_field(N, _)),
        forall(( member(exp(_, _, _, EFs, _), Exps), member(F, EFs), field_name(F, N) ), t_exposure_field(N, _))
    ;   true
    ),
    t_insured(_), t_covered(_),
    % the perils' scripts
    shared_perils(Exps, Shared),
    forall(( member(exp(_, EDir, Noun, _, Perils), Exps), member(peril(PName, _, Const, _, Script), Perils) ),
           ( assertz(g_exposure_noun(EDir, Noun)),
             (   Script == none
             ->  ledger(PName, peril, encoded, 'a peril with no premium script: coverage only', Const, none)
             ;   id_words(Const, SW),
                 ( memberchk(Const, Shared) -> S = peril(Const, Noun) ; S = peril(Const, Noun) ),
                 compile_script(Script, S, SW, _)
             ) )),
    % taxes, underwriting, fees
    forall(member(tax(T, TF), Taxes), ( id_words(T, TW), compile_script(TF, tax(T), TW, _) )),
    atomic_list_concat([PolicyDir, '/underwriting.guidelines.liquid'], UW),
    ( exists_file(UW) -> compile_script(UW, policy, [provisional], _) ; true ),
    atomic_list_concat([PolicyDir, '/policy.calculations.liquid'], Calc),
    ( exists_file(Calc) -> compile_script(Calc, policy, [fees], _) ; true ),
    fee_descriptions(Calc),
    gross_premium_rule,
    gross_taxes_rule,
    % the policy of an exposure, declared for a rule a residue rolled back
    ( rules_read(insured_under) -> true ; retractall(g_template(insured_under, _, _)) ),
    % the model's elements in the ledger
    ledger_fields(PFields, Exps),
    ledger_tables(Tables),
    forall(g_table_used(T), scan_table(ProductDir, T)),
    ledger_other(PolicyDir, Fees, Taxes),
    % tests from the oracle
    read_json(OracleFile, Oracle),
    oracle_tests(Oracle, Exps, Name, Tests),
    % the IR
    findall(I, ( g_template(F, T, A), declaration_item(F, T, A, I) ), Templates),
    % no ontology ("a work cover is an exposure"): a quote states both kinds
    % of each exposure (le_verifier's unread_value would take the ontology's
    % types for the values its rules read)
    Onto = [],
    findall(table(T, [policy(unique), loaded_from(CSV)], Header, []),
            ( g_table_used(T), memberchk(table(T, _, Header0, _), Tables),
              maplist(header_cell, Header0, Header),
              atomic_list_concat([T, '.csv'], CSV) ),
            TableItems),
    findall(I, g_item(I), RuleItems0),
    %  every cited file a document, every rule at its passage (socotra_sources)
    display_root(ProductDir, Root),
    locate_rules(Root, RuleItems0, RuleItems),
    format(atom(QDoc), '~w rating quotes', [Name]),
    (   get_dict(cases, Oracle, [_|_]) -> QDocs = [document(QDoc, [text("quotes.json")])] ; QDocs = [] ),
    document_items(RuleItems, QDocs, DocItems),
    queries(Queries),
    quote_desk_view(Name, Exps, View),
    append([Templates, Onto, DocItems, TableItems, RuleItems, Queries, [View]], Items),
    product_words(Name, KB),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    licence_note(Licence),
    format(string(C1), "~w: a Logical English twin of the Socotra product library's \"~w\" product,~ntranslated by the Socotra translator (~w).~nSource licence: ~w", [KB, Name, Date, Licence]),
    (   g_template(year_of, _, _)
    ->  Header = [kb(KB), comment(C1), includes([temporal])]
    ;   Header = [kb(KB), comment(C1)]
    ),
    Meta = [program(Name), source('Socotra product library (socotra/product-library, commit df4a7f8)'),
            artifacts(['policy.json', 'exposures/', 'perils/', '*.premium.liquid', 'underwriting.guidelines.liquid',
                       'policy.calculations.liquid', 'taxes/', 'tables/']),
            translator('LE2 migration/socotra/socotra_reader.pl'), date(Date), licence(Licence)],
    findall(E, g_ledger(E), Ledger).

licence_note("socotra/product-library carries no licence file; this twin is a derived work kept in the private InsurLE repository, and publication awaits confirmation of the licence").

header_cell(C, A) :- ( string(C) -> atom_string(A0, C) ; A0 = C ), normalize_space(atom(A), A0).

product_words(Name, KB) :- id_words(Name, Ws), words_text(Ws, KB).

shared_perils(Exps, Shared) :-
    findall(C, ( member(exp(_, D1, _, _, P1), Exps), member(peril(_, _, C, _, _), P1),
                 member(exp(_, D2, _, _, P2), Exps), D2 \== D1, member(peril(_, _, C, _, _), P2) ), S0),
    sort(S0, Shared).

register_fields(PFields, Exps) :-
    forall(( member(F, PFields), field_name(F, N), field_type(F, T) ),
           ( assertz(g_field_type(policy, N, T)), register_select(policy, F, N) )),
    forall(( member(exp(_, _, Noun, EFs, Perils), Exps), member(F, EFs), field_name(F, N), field_type(F, T) ),
           ( ( g_field_type(exposure, N, _) -> true ; assertz(g_field_type(exposure, N, T)), register_select(exposure, F, N) ),
             (   findall(No, ( member(exp(_, _, No, EFs2, _), Exps), member(F2, EFs2), field_name(F2, N) ), Nos0),
                 sort(Nos0, Nos), Nos == [Noun]
             ->  ( g_field_noun(N, _) -> true ; assertz(g_field_noun(N, Noun)) )
             ;   ( g_field_noun(N, _) -> true ; assertz(g_field_noun(N, exposure)) )
             ) )),
    forall(( member(exp(_, _, _, _, Perils), Exps), member(peril(_, _, _, PJ, _), Perils),
             get_dict_default(fields, PJ, [], PFs), member(F, PFs), field_name(F, N), field_type(F, T) ),
           ( g_field_type(peril, N, _) -> true ; assertz(g_field_type(peril, N, T)), register_select(peril, F, N) )).

register_select(Scope, F, N) :-
    (   get_dict(values, F, Vs), is_list(Vs) -> assertz(g_select(Scope, N, Vs)) ; true ).

%   add_fee: its description, a rule of its own beside the amount.
fee_descriptions(_).

gross_taxes_rule :-
    (   g_template(out_gross_taxes, _, _)
    ->  (   findall(F, ( g_template(F, _, _), atom_concat(tax_, _, F) ), [F])
        ->  T =.. [F, P, E, A],
            emit(rule(out_gross_taxes(Pol, S),
                      and(is_a(Pol, policy), agg(sum, A, and(and(insured_under(E, Pol), covered_for(E, P)), T), S)),
                      [label(gross_taxes), comment("The gross taxes Socotra computes: the perils' taxes, summed.")])),
            ledger('policy.characteristics.gross_taxes', 'platform value', approximated,
                   'computed by the platform: the twin derives it as the sum of the perils'' taxes', gross_taxes, none)
        ;   ledger('policy.characteristics.gross_taxes', 'platform value', residue,
                   'the platform''s sum of several taxes', none, none)
        )
    ;   true
    ).

gross_premium_rule :-
    (   g_template(out_gross_premium, _, _)
    ->  output_functor(year_premium, YP),
        G1 = insured_under(E, Pol), G2 = covered_for(E, P), G3 =.. [YP, P, E, A],
        emit(rule(out_gross_premium(Pol, G),
                  and(is_a(Pol, policy), agg(sum, A, and(and(G1, G2), G3), G)),
                  [label(gross_premium), comment("The gross premium Socotra computes: the perils' yearly premiums, summed.")])),
        ledger('policy.characteristics.gross_premium', 'platform value', approximated,
               'computed by the platform: the twin derives it as the sum of the perils'' yearly premiums',
               gross_premium, 'the platform also counts endorsements and term changes; a single quote has none')
    ;   true
    ).

ledger_fields(PFields, Exps) :-
    forall(( member(F, PFields), field_name(F, N) ),
           ledger_field(policy, 'policy.json', F, N)),
    forall(( member(exp(_, EDir, _, EFs, Perils), Exps) ),
           ( atomic_list_concat(['exposures/', EDir, '/exposure.json'], Src),
             forall(( member(F, EFs), field_name(F, N) ), ledger_field(exposure, Src, F, N)),
             forall(member(peril(PN, PFile, Const, PJ, _), Perils),
                    ( atomic_list_concat(['exposures/', EDir, '/perils/', PFile, '.json'], PSrc),
                      ledger(PSrc, peril, encoded, 'a peril: `*an exposure* is covered for *a peril*`, its characteristics scenario facts', Const, none),
                      ignore(PN = _),
                      get_dict_default(fields, PJ, [], PFs),
                      forall(( member(PF, PFs), field_name(PF, PFN) ), ledger_field(peril, PSrc, PF, PFN)) )) )).

ledger_field(Scope, Src, F, N) :-
    field_type(F, T),
    format(atom(El), '~w field ~w', [Src, N]),
    (   field_functor(Scope, N, Fn), g_template(Fn, Text, _)
    ->  ledger(El, T, encoded, 'a field: a scenario-element template', Text, none)
    ;   memberchk(T, [group, media, lookup])
    ->  ledger(El, T, encoded, 'a field no script reads: not declared', none, 'a group, media or lookup field; no rating or underwriting rule depends on it')
    ;   ledger(El, T, encoded, 'a field no script reads: not declared', none, 'no rating or underwriting rule depends on it')
    ).

field_functor(policy, N, F) :- functor_of(policy, N, F).
field_functor(exposure, N, F) :- functor_of(exposure, N, F).
field_functor(peril, N, F) :- functor_of(peril_field, N, F).

ledger_tables(Tables) :-
    forall(member(table(T, _, Header, Rows), Tables),
           (   g_table_used(T)
           ->  length(Rows, NR), length(Header, NC),
               format(atom(Note), '~w rows, ~w columns', [NR, NC]),
               atomic_list_concat(['tables/', T, '.csv'], Src),
               ( NC =:= 2
               ->  ledger(Src, 'rate table', encoded, 'a CSV-loaded decision table (unique match), the carrier''s own file', T, Note)
               ;   ledger(Src, 'rate table', approximated, 'a CSV-loaded decision table reading its first two columns', T, Note)
               )
           ;   atomic_list_concat(['tables/', T, '.csv'], Src),
               ledger(Src, 'rate table', encoded, 'a table no script looks up: not declared', none, none)
           )).

ledger_other(PolicyDir, Fees, Taxes) :-
    forall(member(Fee, Fees), ( get_dict_default(name, Fee, "", FN),
           ledger('fees.json', fee, encoded, 'a fee: the conclusion of the add_fee rules', FN, none) )),
    forall(member(tax(T, _), Taxes), ledger('taxes/taxes.json', tax, encoded, 'a tax: the conclusion of its script''s rules', T, none)),
    forall(( member(Doc, ['lapse.template.liquid', 'cancellation.template.liquid', 'endt.template.liquid',
                          'schedule.template.liquid', 'invoice.template.liquid', 'reinstatement.template.liquid',
                          'regulatory_disclosure.template.liquid', 'gracePeriod.template.liquid']),
             atomic_list_concat([PolicyDir, '/', Doc], P), exists_file(P) ),
           ledger(Doc, 'document template', encoded, 'a document template: presentation, no decision logic; not translated', none, none)),
    forall(( member(g_counter(approx(W), _), []) ), true),
    forall(g_counter(approx(W), _), approx_ledger(W)).

approx_ledger(integer_division) :-
    ledger('divided_by', 'arithmetic', approximated, 'Liquid divides integers with integer division: // in the twin', '//', 'assumes the whole-number inputs the product''s quotes carry').
approx_ledger(division_type_unknown) :-
    ledger('divided_by', 'arithmetic', approximated, 'a division whose operands'' types are not known before run time: / in the twin', '/', 'integer division if both are whole numbers at run time').
approx_ledger(peril_premium) :-
    ledger('data.peril_characteristics.premium', 'data access', approximated, 'the peril''s premium, read by a tax script: its yearly premium, as the reference run passes it', none, 'a product whose perils set only a monthly premium (set_month_premium) concludes no yearly premium, so its taxes are not computed, in the twin as in the reference run; the verifier then reports the yearly premium as an undefined predicate').
approx_ledger(first_exposure) :-
    ledger('data.policy.exposures[0]', 'data access', approximated, 'the first exposure of the policy: read as an exposure of the policy', none, 'equivalent when the policy has one exposure of the kind').

		 /*******************************
		 *   ORACLE QUOTES -> TESTS     *
		 *******************************/

oracle_tests(Oracle, Exps, Name, Tests) :-
    get_dict(cases, Oracle, Cases),
    format(atom(Doc), '~w rating quotes', [Name]),
    findall(T, ( nth1(I, Cases, C), case_test(C, I, Exps, Doc, T) ), Tests).

case_test(Case, _I, Exps, Doc, test(Id, Doc, Loc, Facts, Expects)) :-
    get_dict(id, Case, Id0), atom_string(Id1, Id0),
    atomic_list_concat([quote_, Id1], Id),
    format(atom(Loc), 'quote ~w', [Id1]),
    Pol = 'policy 1',
    get_dict(policy, Case, PF),
    findall(G, ( get_dict(K, PF, V), fact_goal(policy, K, V, Pol, G) ), PGs0),
    findall(G, ( get_dict(policy_dates, Case, PD), get_dict(W, PD, V),
                 atomic_list_concat([policy, W, date], '_', Fn), g_template(Fn, _, _),
                 date_value(V, LV), G =.. [Fn, Pol, LV] ), DGs),
    append(PGs0, DGs, PGs),
    get_dict(exposures, Case, EL),
    get_dict(outputs, Case, Out), get_dict(perils, Out, PerilOuts),
    findall(Gs, ( nth0(EI, EL, E), exposure_facts(E, EI, Exps, Pol, PerilOuts, Gs) ), EGss),
    append(EGss, EGs),
    append([[is_a(Pol, policy)], PGs, EGs], Facts),
    case_expects(Case, Exps, Pol, Expects).

exposure_id(EI, Exps, EId) :-
    nth0(EI, Exps, exp(_, _, Noun, _, _)),
    format(atom(EId), '~w ~w', [Noun, 1]).

exposure_facts(E, EI, Exps, Pol, PerilOuts, Gs) :-
    exposure_id(EI, Exps, EId),
    nth0(EI, Exps, exp(_, _, Noun, _, Perils)),
    get_dict(fields, E, EF),
    findall(G, ( get_dict(K, EF, V), fact_goal(exposure, K, V, EId, G) ), FGs),
    get_dict(perils, E, PL),
    findall(PGs, ( nth0(PI, PL, P), nth0(PI, Perils, peril(_, _, Const, _, _)),
                   \+ peril_failed(PerilOuts, EI, PI, PL),
                   peril_facts(P, Const, EId, PGs) ), PGss),
    append(PGss, PFacts),
    ( Noun == exposure -> Kinds = [is_a(EId, Noun)] ; Kinds = [is_a(EId, Noun), is_a(EId, exposure)] ),
    ( rules_read(insured_under) -> Ins = [insured_under(EId, Pol)] ; Ins = [] ),
    append([Kinds, Ins, FGs, PFacts], Gs).

%   Some rule's conditions read the predicate.
rules_read(F) :-
    g_item(rule(_, B, _)), sub_term(G, B), compound(G), functor(G, F, _), !.

%   A peril whose script the reference Liquid could not run is not covered
%   in the quote: the source has no premium for it to compare with.
peril_failed(PerilOuts, EI, PI, PL) :-
    nth0(PI, PL, P), get_dict(name, P, PN),
    member(R, PerilOuts), get_dict(exposure, R, EI), get_dict(peril, R, PN),
    get_dict(error, R, _), !.

peril_facts(P, Const, EId, [covered_for(EId, Const)|Gs]) :-
    get_dict(chars, P, Ch), get_dict(fields, P, F),
    findall(G, ( get_dict(K, Ch, V), atom_string(KA, K), functor_of(peril, KA, Fn), g_template(Fn, _, _),
                 le_value(V, LV), G =.. [Fn, Const, EId, LV] ), G1),
    findall(G, ( get_dict(K, F, V), atom_string(KA, K), functor_of(peril_field, KA, Fn), g_template(Fn, _, _),
                 le_value(V, LV), G =.. [Fn, Const, EId, LV] ), G2),
    append(G1, G2, Gs).

fact_goal(Scope, K, V, Subject, G) :-
    atom_string(KA, K), field_functor(Scope, KA, Fn), g_template(Fn, _, _),
    ( g_field_type(Scope, KA, date) -> date_value(V, LV) ; le_value(V, LV) ),
    G =.. [Fn, Subject, LV].

date_value(V, date(Y, M, D)) :-
    split_string(V, "-", "", [YS, MS, DS|_]), number_string(Y, YS), number_string(M, MS),
    sub_string(DS, 0, 2, _, D2), number_string(D, D2), !.
date_value(V, V).

%   The expectations of a quote: every output the source computed, as
%   ground literals of the twin's templates (rendered after a first load).
case_expects(Case, Exps, Pol, Expects) :-
    get_dict(outputs, Case, Out), get_dict(perils, Out, POs), get_dict(policy, Out, PolOut),
    findall(Kind-Lit, ( member(R, POs), \+ get_dict(error, R, _), peril_output(R, Exps, Kind, Lit) ), PLits),
    findall(Kind-Lit, policy_output(PolOut, Pol, Kind, Lit), QLits),
    append(PLits, QLits, All),
    findall(Q, ( query_of(Kind, Q, _), g_query_needed(Kind) ), Qs0), sort(Qs0, Qs),
    findall(expects(Q, Lits), ( member(Q, Qs), findall(L, ( member(K-L, All), query_of(K, Q, _) ), Lits) ), Expects).

g_query_needed(Kind) :- query_of(Kind, _, F), g_template(F, _, _).

peril_output(R, Exps, Kind, Lit) :-
    get_dict(exposure, R, EI), exposure_id(EI, Exps, EId),
    get_dict(peril, R, PN0), atom_string(PN, PN0), name_constant(PN, Const),
    get_dict(out, R, O),
    (   member(K-Kind, [set_year_premium-year_premium, set_year_technical_premium-year_technical_premium,
                        set_month_premium-month_premium, set_month_technical_premium-month_technical_premium]),
        get_dict(K, O, V), output_functor(Kind, F), Lit =.. [F, Const, EId, V]
    ;   member(K-Kind, [year_commission-year_commission, month_commission-month_commission]),
        get_dict(K, O, L), member([Who, V], L), le_value(Who, W), output_functor(Kind, F),
        Lit =.. [F, W, Const, EId, V]
    ;   get_dict(taxes, R, Taxes), get_dict(T, Taxes, V), atom_string(TA, T),
        functor_of(tax, TA, F), g_template(F, _, _), Kind = tax(TA),
        Lit =.. [F, Const, EId, V]
    ).

policy_output(PolOut, Pol, Kind, Lit) :-
    (   get_dict(underwriting, PolOut, U)
    ->  (   get_dict(set_underwriting_decision, U, D), atom_string(DA, D), Kind = decision,
            output_functor(decision, F), Lit =.. [F, Pol, DA]
        ;   get_dict(notes, U, Ns), member(N, Ns), le_value(N, NV), Kind = note,
            output_functor(note, F), Lit =.. [F, Pol, NV]
        )
    ;   fail
    ).
policy_output(PolOut, Pol, fee(FA), Lit) :-
    get_dict(fees, PolOut, FO), get_dict(fees, FO, L), member([Name, V, _], L),
    atom_string(FA, Name), functor_of(fee, FA, F), g_template(F, _, _),
    Lit =.. [F, Pol, V].
policy_output(PolOut, Pol, fee_description(FA), Lit) :-
    get_dict(fees, PolOut, FO), get_dict(fees, FO, L), member([Name, _, D], L), D \== "",
    atom_string(FA, Name), functor_of(fee_description, FA, F), g_template(F, _, _),
    le_value(D, DV), Lit =.. [F, Pol, DV].

query_of(year_premium, yearly_premiums, out_year_premium).
query_of(year_technical_premium, yearly_technical_premiums, out_year_technical_premium).
query_of(month_premium, monthly_premiums, out_month_premium).
query_of(month_technical_premium, monthly_technical_premiums, out_month_technical_premium).
query_of(year_commission, yearly_commissions, out_year_commission).
query_of(month_commission, monthly_commissions, out_month_commission).
query_of(decision, underwriting_decision, out_decision).
query_of(note, underwriting_notes, out_note).
query_of(tax(T), Q, F) :- g_template(F, _, _), atom_concat(tax_, T0, F), T = T0, atom_concat(taxes_, T, Q).
query_of(fee(T), Q, F) :- g_template(F, _, _), atom_concat(fee_, T0, F), \+ sub_atom(T0, 0, _, _, description), T = T0, atom_concat(fees_, T, Q).
query_of(fee_description(T), Q, F) :- g_template(F, _, _), atom_concat(fee_description_, T, F), atom_concat(fee_descriptions_, T, Q).

queries(Qs) :-
    findall(query(Q, G), ( query_of(_, Q, F), g_template(F, Text, _),
                           template_text_arity(Text, N), functor(G, F, N) ), Qs0),
    list_to_set(Qs0, Qs1),
    %  the refusal, for the quote desk's banner
    (   g_template(out_decision, _, _)
    ->  append(Qs1, [query(declined, out_decision(_, "reject"))], Qs)
    ;   Qs = Qs1
    ).

template_text_arity(Text, N) :-
    atomic_list_concat(Parts, '*', Text), length(Parts, L), N is (L - 1) // 2.

		 /*******************************
		 *         THE VIEW             *
		 *******************************/

quote_desk_view(Name, Exps, view('quote desk', Sentences)) :-
    format(atom(T1), 'the title is "~w quote desk".', [Name]),
    findall(I, ( g_template(F, Text, [undefined]), atom_concat(policy_, _, F), view_instance(Text, I) ), PIs),
    findall(S, ( member(exp(_, _, Noun, _, _), Exps),
                 findall(I, ( g_template(F, Text, [undefined]), atom_concat(exposure_, _, F),
                              ( g_field_noun(FN, Noun), functor_of(exposure, FN, F) ), view_instance(Text, I) ), EIs),
                 EIs \== [],
                 facts_about(Noun, EIs, S) ), ESs),
    findall(I, ( g_template(F, Text, [undefined]), ( atom_concat(peril_, _, F) ; F == covered_for ; F == insured_under ),
                 view_instance(Text, I) ), CIs),
    ( PIs == [] -> PS = [] ; facts_about(policy, PIs, P1), PS = [P1] ),
    ( CIs == [] -> CS = [] ; facts_about('coverage', CIs, C1), CS = [C1] ),
    findall(S, ( member(Q-Title, [yearly_technical_premiums-'Technical premiums', yearly_commissions-'Commissions',
                                   monthly_premiums-'Monthly premiums', underwriting_decision-'Underwriting decision',
                                   underwriting_notes-'Underwriting notes']),
                 query_of(_, Q, F), g_template(F, Text, _), view_query_body(Text, B),
                 format(atom(S), 'the answers to "~w" are listed as "~w".', [B, Title]) ), Lists),
    findall(S, ( g_template(F, Text, _), ( atom_concat(tax_, _, F) ; atom_concat(fee_, _, F) ),
                 view_query_body(Text, B), view_title(F, Title),
                 format(atom(S), 'the answers to "~w" are listed as "~w".', [B, Title]) ), Lists2),
    %  what the customer pays, first among the lists; a refusal as a banner
    %  above the result; amounts as money; a quote to send (claims-officer
    %  review, a review that is not published (InsuranceClaimsOfficerReport))
    (   g_template(out_gross_premium, GText, _)
    ->  view_query_body(GText, GB),
        format(atom(GS), 'the answers to "~w" are listed as "Total premium".', [GB]), Total = [GS]
    ;   Total = []
    ),
    (   g_template(out_decision, _, _)
    ->  Flags = ['the case is flagged as "Declined by underwriting: this policy cannot be bound" when query declined has an answer.']
    ;   Flags = []
    ),
    (   g_template(out_year_premium, _, _) -> Period = 'Yearly premiums'
    ;   g_template(out_month_premium, _, _) -> Period = 'Monthly premiums'
    ;   Period = 'Underwriting decision'
    ),
    format(atom(Draft), 'the draft reads "~w quote — {the case}\\n\\nThe facts it rests on:\\n{the facts}\\n\\n~w:\\n{the answers}\\n\\nComputed by the rules of the ~w product (Logical English twin); each amount can be traced to its rule and source file." when it holds.', [Name, Period, Name]),
    (   g_template(out_year_premium, _, _)
    ->  Result = ['the result is the answer to query yearly_premiums, headed by the amount.']
    ;   g_template(out_month_premium, _, _)
    ->  Result = ['the result is the answer to query monthly_premiums, headed by the amount.']
    ;   Result = ['the result is the answer to query underwriting_decision, headed by the decision.']
    ),
    append([[T1, 'the case is a scenario.'], PS, ESs, CS, Flags, Result,
            ['the numbers are shown with 2 decimals.',
             'the result shows its reasons.', 'the result shows its citations.'], Total, Lists, Lists2, [Draft]], Sentences).

facts_about(Title, Is, S) :-
    atomic_list_concat(Is, ',\n        ', L),
    format(atom(S), 'the facts about "the ~w" are~n        ~w.', [Title, L]).

view_instance(Text, I) :-
    atomic_list_concat(Parts, '*', Text), atomic_list_concat(Parts, '', I).

view_query_body(Text, B) :-
    atomic_list_concat(Parts0, '*', Text),
    maplist([P, Q]>>( sub_atom(P, 0, 2, _, 'a ') -> sub_atom(P, 2, _, 0, R), atom_concat('which ', R, Q)
                    ; sub_atom(P, 0, 3, _, 'an ') -> sub_atom(P, 3, _, 0, R), atom_concat('which ', R, Q)
                    ; Q = P ), Parts0, Parts),
    atomic_list_concat(Parts, '', B).

view_title(F, T) :- atom_concat(tax_, X, F), !, id_text(X, W), format(atom(T), 'Tax: ~w', [W]).
view_title(F, T) :- atom_concat(fee_, X, F), id_text(X, W), format(atom(T), 'Fee: ~w', [W]).

		 /*******************************
		 *         BUILDING             *
		 *******************************/

%!  build_product(+ProductDir, +OutRoot, -Report) is det.
build_product(ProductDir, OutRoot, Report) :-
    build_product(ProductDir, OutRoot, Report, []).

%!  build_product(+ProductDir, +OutRoot, -Report, +Options) is det.
%
%   Options: reuse_quotes(true) keeps the quotes.json of an earlier run
%   instead of running the oracle (the reference run is deterministic; it
%   needs python-liquid, which a machine may lack).
build_product(ProductDir, OutRoot, Report, Options) :-
    file_base_name(ProductDir, Name),
    id_words(Name, Ws), atomic_list_concat(Ws, '_', Slug),
    atomic_list_concat([OutRoot, '/', Slug], Dir),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/quotes.json'], Quotes),
    (   option(reuse_quotes(true), Options), exists_file(Quotes)
    ->  true
    ;   run_oracle(ProductDir, Quotes)
    ),
    product_migration(ProductDir, Quotes, M0),
    M0 = migration(_, program(Header, _), _, _),
    ( memberchk(includes(Libs), Header) -> forall(member(L, Libs), copy_library(L, Dir)) ; true ),
    copy_tables(ProductDir, Dir),
    display_root(ProductDir, Root),
    copy_sources(ProductDir, Root, Dir),
    render_answers(Dir, M0, M),
    write_migration(M, Dir, Slug, Report).

%   The product's configuration files (Liquid, JSON, CSV; not the PDFs and
%   images of its documents) beside the twin, in sources/ under the paths its
%   rules cite (relative to Root): the documents' texts, and what the editors'
%   Show the Original lists. They share the twin's licence status (see
%   licence_note/1).
copy_sources(PD, Root, OutDir0) :-
    atomic_list_concat([OutDir0, '/sources'], OutDir),
    forall(( directory_member(PD, F, [recursive(true)]),
             file_name_extension(_, Ext0, F), downcase_atom(Ext0, Ext),
             memberchk(Ext, [liquid, json, csv, txt, md]),
             atom_concat(Root, '/', RS), atom_concat(RS, Rel, F) ),
           ( atomic_list_concat([OutDir, '/', Rel], Dst),
             file_directory_name(Dst, DD), make_directory_path(DD),
             copy_file(F, Dst) )).

run_oracle(ProductDir, Out) :-
    socotra_home(H), atomic_list_concat([H, '/oracle.py'], Py),
    process_create(path(python3), [Py, ProductDir, Out, '--max-cases', '10'], [process(Pid)]),
    process_wait(Pid, exit(0)).

%   The tables the twin looks up, as the carrier wrote them, except for a
%   cell opening with a comparison sign (cell_text/2).
copy_tables(ProductDir, Dir) :-
    forall(( g_table_used(T),
             atomic_list_concat([ProductDir, '/policy/tables/', T, '.csv'], Src), exists_file(Src) ),
           ( atomic_list_concat([Dir, '/', T, '.csv'], Dst), copy_table(Src, Dst) )).

%   The cells of a table the copy rewrites, in the ledger (safe_cell/2).
scan_table(ProductDir, T) :-
    atomic_list_concat([ProductDir, '/policy/tables/', T, '.csv'], Src),
    (   exists_file(Src)
    ->  csv_read_file(Src, Rows, [convert(false), strip(true), encoding(utf8)]),
        maplist(safe_row, Rows, _)
    ;   true
    ).

copy_table(Src, Dst) :-
    csv_read_file(Src, Rows0, [convert(false), strip(true), encoding(utf8)]),
    maplist(safe_row, Rows0, Rows),
    (   Rows == Rows0
    ->  copy_file(Src, Dst)
    ;   csv_write_file(Dst, Rows, [encoding(utf8)])
    ).

safe_row(R0, R) :-
    R0 =.. [row|Cs0], maplist(safe_cell, Cs0, Cs), R =.. [row|Cs].

safe_cell(C0, C) :-
    (   atom(C0), atom_string(C0, S0), cell_text(S0, S), S \== S0
    ->  atom_string(C, S)
    ;   atom(C0), leading_point(C0, C1)
    ->  C = C1,
        ( g_ledger(entry(C0, 'value', _, _, _, _)) -> true
        ; ledger(C0, 'value', encoded, 'a number written without its leading 0: written with it in the copied table', C1, none) )
    ;   C = C0
    ).

%   `.9`, a number to the carrier's Liquid, a text to Prolog: 0.9.
leading_point(A, B) :-
    normalize_space(atom(A1), A),
    (   sub_atom(A1, 0, _, _, '.') -> atom_concat('0', A1, B)
    ;   sub_atom(A1, 0, _, _, '-.') -> sub_atom(A1, 1, _, 0, R), atom_concat('-0', R, B)
    ),
    atom_number(B, _).

%   Expected answers as the engine renders them: the program is written and
%   loaded once, and each expected literal is rendered by LE itself.
render_answers(Dir, migration(Meta, IR, Ledger, Tests0), migration(Meta, IR, Ledger, Tests)) :-
    IR = program(H, Items),
    le_writer:le_write(program(H, Items), Text, _),
    le_kbs:set_le_issue_reporting(false),
    retractall(le_kbs:le_include_base(_)), assertz(le_kbs:le_include_base(Dir)),
    call_cleanup(le_kbs:load_text(Text, KB),
                 ( le_kbs:set_le_issue_reporting(true), retractall(le_kbs:le_include_base(_)) )),
    le_writer:ir_dicts(IR, Dicts),
    maplist(test_render(KB, Dicts), Tests0, Tests).

test_render(KB, Dicts, test(Id, D, L, F, E0), test(Id, D, L, F, E)) :-
    maplist(expect_render(KB, Dicts), E0, E).

expect_render(KB, Dicts, expects(Q, Lits), expects(Q, Strings)) :-
    maplist(lit_string(KB, Dicts), Lits, Strings0),
    sort(Strings0, Strings).

lit_string(KB, Dicts, Lit, S) :-
    Lit =.. [F|Args], length(Args, N),
    member(td(F, N, WV, _, _, _, _), Dicts), !,
    le_writer:wv_derives(WV, LEF),
    Goal =.. [LEF|Args],
    le_kbs:item_to_instance(KB, Goal, W), le_kbs:canonical_string(W, A), atom_string(A, S).

%!  build_all(+LibraryDir, +OutRoot) is det.
build_all(Lib, OutRoot) :-
    build_all(Lib, OutRoot, []).

build_all(Lib, OutRoot, Options) :-
    directory_files(Lib, Ps0), exclude([P]>>sub_atom(P, 0, _, _, '.'), Ps0, Ps1), msort(Ps1, Ps),
    forall(member(P, Ps),
           ( atomic_list_concat([Lib, '/', P], PD),
             (   exists_directory(PD)
             ->  format(user_error, "~w ...~n", [P]),
                 catch(( build_product(PD, OutRoot, R, Options), format(user_error, "  ~q~n", [R]) ),
                       E, ( print_message(error, E) ))
             ;   true
             ) )).

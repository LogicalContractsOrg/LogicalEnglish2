/** <module> OIPA -> Logical English: one twin per transaction

    Phase 2b (the design notes roadmap.md §5.9, §8): the timeless reading
    — an activity's values from its fields, the policy it finds and the
    plan — as one LE program per transaction (oipa_reader.pl gives the
    model):

      - an activity field (FIELD Activity:X) is `the <x> of *an activity* is
        ...`, a policy field (POLICYFIELD) `the <x> of the policy before *an
        activity* is ...`, a plan field (PLANFIELD) `the <x> of the plan is
        ...` whose values (PlanFields.csv) are facts of the program, cited;
      - a MathVariable is `the <name> of *an activity* is ...`, its rule the
        EXPRESSION with the variables it reads as conditions (ROUND n as
        `round(E * 10^n) / 10^n`); an IIF, and a MathIF that replaces a value
        set earlier, are `otherwise` cascades (the latest assignment first,
        as OIPA's top-to-bottom evaluation has it); a VALUE set once is a
        constant (`the constants are:`); a RATE is a decision table loaded
        from the plan's rates (the CSV beside the twin), its DEFAULT the
        cascade's last line; the functions are LE's own (DurationOf the age
        between two dates of lib/temporal, DaysDiffOf `... days after`,
        MonthsAdd `... months after`, TruncateNumber `truncate`, MinOf and
        MaxOf `the minimum/maximum of`, ANBAgeOf approximated by the age six
        calendar months later);
      - ValidateExpressions are `*an activity* fails the check *a code*`,
        SpawnActivities `*an activity* spawns *a transaction*` and
        CopyToPolicyFields `the <field> of the policy after *an activity* is
        ...` — the last two only for an activity that fails no check, as
        OIPA refuses such an activity;
      - every rule cites its MathVariable (`as stated in
        Withdrawal/Transaction.xml at MathVariable NetAmountMV`).

    The tests: each activity of the plan's policy lives (cases.json) whose
    transaction this is, with the values the independent interpreter
    oipa_eval.py computes (never the twin).
*/

:- module(oipa_twin, [transaction_migration/4, build_plan/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(filesex)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(oipa_reader).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).

		 /*******************************
		 *            BUILD             *
		 *******************************/

%!  build_plan(+PlanDir, +OutRoot) is det.
%   One twin directory per transaction: OutRoot/<plan>_<transaction>/.
build_plan(PlanDir, OutRoot) :-
    read_plan(PlanDir, plan(Plan, Ts)),
    oracle_steps(PlanDir, Steps),
    forall(member(T, Ts),
           ( T = transaction(TN, _, _, _, _, _),
             twin_name(Plan, TN, Name),
             atomic_list_concat([OutRoot, '/', Name], Dir),
             make_directory_path(Dir),
             copy_sources(PlanDir, TN, Dir),
             copy_library(temporal, Dir),
             transaction_migration(PlanDir, T, Steps, Migration),
             write_rate_tables(PlanDir, T, Dir),
             write_migration(Migration, Dir, Name, report(LE, Issues, Counts, Fid)),
             include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
             ( Fid = fidelity(P, F, U, _) -> true ; P = '-', F = '-', U = '-' ),
             format("~w  ~w  pass ~w fail ~w error ~w  ~w writer error(s)~n", [LE, Counts, P, F, U, NE]) )).

twin_name(Plan, TN, Name) :- snake(TN, S), format(atom(Name), '~w_~w', [Plan, S]).

copy_sources(PlanDir, TN, Dir) :-
    atomic_list_concat([Dir, '/sources/', TN], SD), make_directory_path(SD),
    atomic_list_concat([PlanDir, '/', TN], TD),
    forall(( directory_member(TD, F, [extensions([xml])]) ),
           ( file_base_name(F, B), atomic_list_concat([SD, '/', B], D), copy_file(F, D) )),
    forall(member(F, ['Rates.csv', 'PlanFields.csv']),
           ( atomic_list_concat([PlanDir, '/', F], S), atomic_list_concat([Dir, '/sources/', F], D),
             ( exists_file(S) -> copy_file(S, D) ; true ) )).

%   The oracle: oipa_eval.py over the plan's policy lives.
oracle_steps(PlanDir, Steps) :-
    atomic_list_concat([PlanDir, '/cases.json'], Cases),
    (   exists_file(Cases)
    ->  here(Here), atomic_list_concat([Here, '/oipa_eval.py'], Py),
        setup_call_cleanup(process_create(path(python3), [Py, PlanDir, Cases], [stdout(pipe(Out))]),
                           json_read_dict(Out, D), close(Out)),
        findall(L-S, ( member(Life, D.lives), atom_string(L, Life.life), member(S, Life.steps) ), Steps)
    ;   Steps = []
    ).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).

		 /*******************************
		 *        THE MIGRATION         *
		 *******************************/

%!  transaction_migration(+PlanDir, +Transaction, +Steps, -Migration) is det.
transaction_migration(PlanDir, T, Steps, migration(Meta, program(Header, Items), Ledger, Tests)) :-
    T = transaction(TN, _Fields, Math, Checks, Spawns, Copies),
    file_base_name(PlanDir, Plan),
    twin_name(Plan, TN, Name),
    nb_setval(oipa_notes, []),
    flatten_math(Math, true, Assigns),              % [a(MV, Cond, Item) | blk(...)] in order
    nb_setval(oipa_assigns, Assigns),
    include([X]>>( X = a(_, _, _) ), Assigns, As1),
    findall(I-X, nth1(I, As1, X), Numbered),        % each assignment with its position
    nb_setval(oipa_numbered, Numbered),
    symbols(Assigns, Syms),
    b_setval(oipa_syms, Syms), b_setval(oipa_tn, TN), b_setval(oipa_pos, end),
    plan_fields(PlanDir, PlanValues),
    rate_tables(PlanDir, Syms, Tables),
    plan_facts(Syms, PlanValues, PlanFacts),
    mv_rules(Assigns, Syms, MVRules0),
    block_residues(Assigns, BlockResidues),
    append(MVRules0, BlockResidues, MVRules),
    check_rules(Checks, CheckRules),
    ( Checks == [] -> Accepted = true ; Accepted = no_check ),
    spawn_rules(Accepted, Spawns, SpawnRules),
    copy_rules(Accepted, Copies, CopyRules),
    (   sub_term(K, [MVRules, CheckRules, SpawnRules, CopyRules]), nonvar(K), K = activity_kind(_)
    ->  activity_kind_rule(KR), KRs = [KR], activity_kind_template(KT), KTs = [KT]
    ;   KRs = [], KTs = []
    ),
    templates(Syms, Checks, Spawns, Copies, Templates0),
    version_templates(VTs),
    Templates0 = [T1|Ts1], append([[T1|KTs], Ts1, VTs], Templates),
    queries(Syms, Checks, Spawns, Copies, Queries),
    format(atom(TX), '~w/Transaction.xml', [TN]),
    Docs = [document(TX, [text(DocPath)])],
    format(atom(DocPath), 'sources/~w/Transaction.xml', [TN]),
    view(TN, Plan, Syms, Templates, Queries, View),
    %  (a VALUE set once is written in place: no constants section)
    append([Templates, Docs, PlanFacts, Tables, KRs, MVRules, CheckRules, SpawnRules, CopyRules, Queries, [View]], Items),
    format(string(C0), "The Logical English twin of the OIPA transaction ~w of the plan ~w, written by the OIPA translator~nfrom its XML configuration (kept in sources/).~nEach rule cites the MathVariable it states; the expected values in the scenarios are~ncomputed by an independent interpreter of OIPA math (oipa_eval.py), not by this program.", [TN, Plan]),
    Header = [kb(Name), target(prolog), comment(C0), includes([temporal])],
    findall(test(SN, none, none, Facts, Expects),
            ( member(L-S, Steps), atom_string(TN, S.transaction),
              scenario_of(L, S, Syms, Checks, Spawns, Copies, SN, Facts, Expects) ), Tests),
    nb_getval(oipa_notes, Notes0), reverse(Notes0, Notes1), list_to_set(Notes1, Notes),
    ledger(TN, Assigns, Syms, Checks, Spawns, Copies, Notes, Ledger),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    Meta = [program(Name), source('an OIPA transaction (Rules Palette XML)'), artifacts([TX]),
            translator('LE2 migration/oipa (oipa_twin.pl)'), date(Date)].

note(N) :- nb_getval(oipa_notes, Ns), nb_setval(oipa_notes, [N|Ns]).

%   The MathVariables in evaluation order, each with the MathIF condition it
%   is under: at(P, C), C read after the first P assignments (where the
%   MathIF stands). An element the translator does not read (MathLoop) is
%   blk(Element, Label, Names, XML) before the assignments inside it, which
%   are in_block(Element, Label).
flatten_math(Items, Cond, As) :- flatten_math(Items, Cond, 0, _, As).

flatten_math([], _, P, P, []).
flatten_math([I|Is], Cond, P0, P, As) :-
    flat_item(I, Cond, P0, P1, As1),
    flatten_math(Is, Cond, P1, P, As2),
    append(As1, As2, As).

flat_item(mv(N, T, D, At, V), Cond, P0, P, [a(N, Cond, mv(N, T, D, At, V))]) :- P is P0 + 1.
flat_item(mathif(C, Items), Cond0, P0, P, As) :-
    ( Cond0 == true -> Cond = at(P0, C) ; Cond = and(Cond0, at(P0, C)) ),
    flatten_math(Items, Cond, P0, P, As).
flat_item(block(El, Label, Items, XML), Cond, P0, P, [blk(El, Label, Names, XML)|As]) :-
    flatten_math(Items, Cond, P0, P, As0),
    findall(N, member(a(N, _, _), As0), Ns0), list_to_set(Ns0, Names),
    maplist(in_block(El, Label), As0, As).

in_block(El, Label, a(N, C, mv(N, _, D, At, _)), a(N, C, mv(N, El, D, At, in_block(El, Label)))) :- !.
in_block(_, _, X, X).

		 /*******************************
		 *           SYMBOLS            *
		 *******************************/

%   sym(MV, Kind, F, Type): Kind activity(Field) | policy(Field) |
%   plan(Field, Default) | constant(Value) | computed; F the IR functor.
symbols(Assigns, Syms) :-
    findall(N, member(a(N, _, _), Assigns), Ns0), list_to_set(Ns0, Ns),
    maplist(symbol(Assigns), Ns, Syms).

symbol(Assigns, N, sym(N, Kind, F, Type)) :-
    findall(C-I, member(a(N, C, I), Assigns), [C1-I1|More]),
    I1 = mv(_, T, DT, At, V),
    value_type(N, DT, Type),
    (   member(_-mv(_, _, _, _, in_block(_, Label)), [C1-I1|More])
    ->  Kind = in_block(Label), mv_words(N, Ws), atomic_list_concat(Ws, '_', F)
    ;   More == [], C1 == true, T == 'FIELD', V = field('Activity', FName)
    ->  Kind = activity(FName), field_functor(activity, FName, F)
    ;   More == [], C1 == true, V = field('Policy', FName)
    ->  Kind = policy(FName), field_functor(policy, FName, F)
    ;   More == [], C1 == true, V = field('Plan', FName)
    ->  ( memberchk('DEFAULT'=Df, At) -> true ; Df = none ),
        Kind = plan(FName, Df), field_functor(plan, FName, F)
    ;   More == [], C1 == true, T == 'VALUE', V = value(X)
    ->  Kind = constant(X), mv_words(N, Ws), atomic_list_concat(Ws, '_', S), atom_concat(the_value_of_, S, F0), atom_concat(F0, '_is', F)
    ;   Kind = computed, mv_words(N, Ws), atomic_list_concat(Ws, '_', F)
    ).

field_functor(Scope, Field, F) :- snake(Field, S), format(atom(F), '~w_~w', [Scope, S]).

value_type(N, DT, Type) :-
    mv_words(N, Ws), last(Ws, W),
    (   DT == 'DATE' -> Type = date
    ;   memberchk(W, [rate, percent, factor, ratio]) -> Type = number
    ;   memberchk(DT, ['INTEGER']) -> Type = number
    ;   memberchk(DT, ['DECIMAL', 'CURRENCY']) -> Type = amount
    ;   Type = value
    ).

%   NetDepositMV -> [net, deposit]; the MV suffix is OIPA's naming habit.
mv_words(N, Ws) :-
    atom_codes(N, Cs0), ( append(Cs, `MV`, Cs0) -> true ; Cs = Cs0 ),
    atom_codes(A, Cs), camel_words(A, Ws).

camel_words(A, Ws) :-
    atom_codes(A, Cs), phrase(words(Ws0), Cs), maplist([W0, W]>>downcase_atom(W0, W), Ws0, Ws).
words([W|Ws]) --> [C], { code_type(C, upper) }, lowers(Ls), { atom_codes(W, [C|Ls]) }, !, words(Ws).
words([W|Ws]) --> [C], { code_type(C, alnum) }, lowers(Ls), { atom_codes(W, [C|Ls]) }, !, words(Ws).
words(Ws) --> [_], !, words(Ws).
words([]) --> [].
lowers([C|Cs]) --> [C], { code_type(C, alnum), \+ code_type(C, upper) }, !, lowers(Cs).
lowers([]) --> [].

snake(A, S) :- camel_words(A, Ws), atomic_list_concat(Ws, '_', S).

sym(N, S) :- b_getval(oipa_syms, Syms), memberchk(sym(N, K, F, T), Syms), S = sym(N, K, F, T).

		 /*******************************
		 *          TEMPLATES           *
		 *******************************/

templates(Syms, Checks, Spawns, Copies, Ts) :-
    findall(template(F/2, Text, []), ( member(sym(N, K, F, T), Syms), K \= constant(_), K \= plan(_, _),
                                       sym_text(N, K, T, Text) ), T10),
    (   memberchk(template(activity_effective_date/2, _, _), T10) -> T1 = T10
    ;   T1 = [template(activity_effective_date/2, "the effective date of *an activity* is *a date*", [])|T10]
    ),
    findall(template(F/1, Text, []), ( member(sym(N, plan(Fd, _), F, T), Syms), sym_text(N, plan(Fd, _), T, Text) ), T2),
    ( Checks == [] -> T3 = [] ; T3 = [template(fails_the_check/2, "*an activity* fails the check *a code*", [])] ),
    ( Spawns == [] -> T4 = [] ; T4 = [template(spawns/2, "*an activity* spawns *a transaction*", [])] ),
    findall(template(F/2, Text, []), ( member(copy(_, To), Copies), copy_template(To, F, Text) ), T5),
    list_to_set(T5, T5s),
    library_templates(Syms, T6),
    rate_templates(Syms, T7),
    append([T1, T2, T3, T4, T5s, T6, T7], Ts0),
    maplist(declaration_item, Ts0, Ts).

%!  declaration_item(+Item, -Item) is det.
%
%   Which section a template is declared in. Everything OIPA gives that reads
%   "... is *a value*" is one value per activity, policy or plan — a field, a
%   MathVariable, a computed amount — so it is a FUNCTION (LE2's language
%   reference §2.4) and the twin may write the value where it is used:
%
%       and the face amount of the activity > 100000
%
%   instead of a condition to bind it and another to test it. The writer
%   decides where that is safe (a value that feeds a formula keeps its own
%   condition). A relation, a check, a spawn and a rate table do not end in
%   their value and are left alone; nor is a template an included library
%   declares, which is its to declare.
declaration_item(template(F, Text, Adds), function(F, Text, Adds)) :-
    \+ memberchk(included, Adds),
    le_writer:function_shaped(Text), !.
declaration_item(I, I).

sym_text(_, activity('EffectiveDate'), _, "the effective date of *an activity* is *a date*") :- !.
sym_text(_, activity(Fd), T, Text) :- !, camel_words(Fd, Ws), place(T, P), atomic_list_concat(Ws, ' ', W),
    format(string(Text), "the ~w of *an activity* is ~w", [W, P]).
sym_text(_, policy(Fd), T, Text) :- !, camel_words(Fd, Ws), place(T, P), atomic_list_concat(Ws, ' ', W),
    format(string(Text), "the ~w of the policy before *an activity* is ~w", [W, P]).
sym_text(_, plan(Fd, _), T, Text) :- !, camel_words(Fd, Ws), place(T, P), atomic_list_concat(Ws, ' ', W),
    format(string(Text), "the ~w of the plan is ~w", [W, P]).
sym_text(N, computed, T, Text) :- !, mv_words(N, Ws), place(T, P), atomic_list_concat(Ws, ' ', W),
    format(string(Text), "the ~w of *an activity* is ~w", [W, P]).
sym_text(N, in_block(_), T, Text) :- sym_text(N, computed, T, Text).

%   A value a MathVariable had before a later assignment changed it, for
%   the MathVariables that read it in between: `the first value of the
%   charge of *an activity* is *an amount*`.
version_templates(Ts) :-
    nb_getval(oipa_versions_done, Vs),
    findall(template(F/2, Text, []),
            ( member(N-J, Vs), sym(N, sym(N, computed, F0, T)), total_assigns(N, Tot),
              version_functor(F0, J, Tot, F), version_words(N, J, W), place(T, P),
              format(string(Text), "the ~w of *an activity* is ~w", [W, P]) ), Ts).

version_words(N, J, W) :-
    mv_words(N, Ws), atomic_list_concat(Ws, ' ', W0),
    ordinal(J, O), format(atom(W), '~w value of the ~w', [O, W0]).

ordinal(J, O) :- nth1(J, [first, second, third, fourth, fifth, sixth, seventh, eighth, ninth, tenth, eleventh, twelfth], O), !.
ordinal(J, O) :- format(atom(O), 'value ~w', [J]).

version_functor(F0, J, _, F) :- format(atom(F), '~w_value_~w', [F0, J]).

place(date, "*a date*").
place(number, "*a number*").
place(amount, "*an amount*").
place(value, "*a value*").

copy_template(To, F, Text) :-
    snake(To, S), format(atom(F), 'policy_after_~w', [S]),
    camel_words(To, Ws), atomic_list_concat(Ws, ' ', W),
    format(string(Text), "the ~w of the policy after *an activity* is *a value*", [W]).

%   The functions' templates: lib/temporal's (included) and LE's own.
library_templates(_, [template(age_on_born, "the age on *a date* of someone born on *a birth date* is *a number*", [included])]).

		 /*******************************
		 *   CONSTANTS AND PLAN FACTS   *
		 *******************************/

constants(Syms, Cs) :-
    findall(constant(F, Name, V), ( member(sym(N, constant(X), F, _), Syms), mv_words(N, Ws),
                                   atomic_list_concat(Ws, ' ', Name), value_of(X, V) ), Cs).

value_of(X, V) :- ( atom_number(X, V) -> true ; X = V ).

%   A plan field's value: the plan's (PlanFields.csv), else the
%   MathVariable's DEFAULT (cited as such).
plan_facts(Syms, Values, Facts) :-
    b_getval(oipa_tn, TN), format(atom(TX), '~w/Transaction.xml', [TN]),
    findall(fact(G, [provenance(P)]),
            ( member(sym(N, plan(Fd, Df), F, _), Syms),
              (   memberchk(Fd-X, Values) -> P = [as_stated_in('PlanFields.csv'), at(Fd)]
              ;   Df \== none, X = Df, format(atom(At), 'MathVariable ~w DEFAULT', [N]), P = [as_stated_in(TX), at(At)]
              ),
              value_of(X, V), G =.. [F, V] ), Facts).

		 /*******************************
		 *            RULES             *
		 *******************************/

%   One rule per computed MathVariable: its assignments, the latest first,
%   as an otherwise cascade (a MathIF's condition guarding its line). A
%   MathVariable read between two assignments of another reads the value
%   that one had then: a rule of its own for that value (the cascade of the
%   assignments made so far), `the first value of the charge`. A
%   MathVariable the translator cannot read is a residue block.
mv_rules(_Assigns, Syms, Rules) :-
    nb_setval(oipa_versions_wanted, []), nb_setval(oipa_versions_done, []),
    nb_setval(oipa_residues, []),
    findall(N, member(sym(N, computed, _, _), Syms), Ns),
    findall(N-T-R, ( member(N, Ns), total_assigns(N, T), mv_rule(N, T, R) ), Finals),
    more_versions(Finals, All),
    %  a variable's earlier values just before its rule, in order
    findall(R, ( member(N, Ns), findall(J-R0, member(N-J-R0, All), JRs0), msort(JRs0, JRs),
                 member(_-R, JRs), R \== none ), Rules).

more_versions(Acc, All) :-
    nb_getval(oipa_versions_wanted, W), nb_getval(oipa_versions_done, D),
    (   member(N-J, W), \+ memberchk(N-J, D)
    ->  nb_setval(oipa_versions_done, [N-J|D]),
        findall(R, mv_rule(N, J, R), [R1|_]),
        more_versions([N-J-R1|Acc], All)
    ;   All = Acc
    ).

total_assigns(N, T) :- nb_getval(oipa_numbered, NAs), aggregate_all(count, member(_-a(N, _, _), NAs), T).

%   The number of assignments of N among the first P.
assigns_upto(N, P, J) :-
    nb_getval(oipa_numbered, NAs), aggregate_all(count, ( member(I-a(N, _, _), NAs), I =< P ), J).

want_version(N, J) :-
    nb_getval(oipa_versions_wanted, W),
    ( memberchk(N-J, W) -> true ; nb_setval(oipa_versions_wanted, [N-J|W]) ).

mv_rule(N, J, Item) :-
    sym(N, sym(N, computed, F0, _)),
    total_assigns(N, Tot),
    ( J =:= Tot -> F = F0 ; version_functor(F0, J, Tot, F) ),
    nb_getval(oipa_numbered, NAs),
    findall(I-(C-It), member(I-a(N, C, It), NAs), All),
    length(Upto, J), append(Upto, _, All),
    reverse(Upto, CIs),
    b_getval(oipa_tn, TN), format(atom(TX), '~w/Transaction.xml', [TN]),
    format(atom(At), 'MathVariable ~w', [N]),
    mv_words(N, Ws), atomic_list_concat(Ws, '_', L0),
    ( J =:= Tot -> L = L0 ; ordinal(J, O), format(atom(L), '~w_~w_value', [L0, O]) ),
    catch(( H =.. [F, A, V],
            maplist(alternative(A, V), CIs, Alts0), append(Alts0, Alts1),
            maplist(about_the_activity(A), Alts1, Alts),
            ( Alts = [B] -> Body = B ; Body = otherwise(Alts) ),
            Item = rule(H, Body, [label(L), provenance([as_stated_in(TX), at(At)])]) ),
          oipa_residue(Why),
          residue_item(N, F, All, Why, Item)).

%   A MathVariable the translator cannot read: a residue block with its XML
%   (every assignment of it), concluding its template; once per variable.
residue_item(N, F, All, Why, Item) :-
    nb_getval(oipa_residues, Rs),
    (   memberchk(N-_, Rs)
    ->  Item = none
    ;   length(Rs, K), K1 is K + 1, format(atom(Id), 'r~w', [K1]),
        why_words(Why, WT),
        nb_setval(oipa_residues, [N-res(Id, WT)|Rs]),
        findall(X, ( member(_-(_-mv(_, _, _, At, _)), All), memberchk('$xml'=X, At) ), Xs),
        atomic_list_concat(Xs, '\n', XML),
        b_getval(oipa_tn, TN), format(atom(TX), '~w/Transaction.xml', [TN]),
        format(atom(Title), '~w MathVariable ~w', [TX, N]),
        sym(N, sym(_, _, _, Type)), sym_text(N, computed, Type, Text),
        format(string(Note), "Not translated: ~w.~nConclude: ~w.", [WT, Text]),
        Item = residue(Id, [title(Title), locator(TX), note(Note), source('OIPA XML', XML), concludes([F])])
    ).

why_words(unsupported_type(T), W) :- !, format(atom(W), 'a MathVariable of TYPE ~w, which the translator does not read', [T]).
why_words(field_under_mathif, 'a FIELD MathVariable set inside a MathIF') :- !.
why_words(function(F), W) :- !, format(atom(W), 'the function ~w, which the translator does not know', [F]).
why_words(expression(E), W) :- !, format(atom(W), 'an expression the translator does not read: ~q', [E]).
why_words(unset(R), W) :- !, format(atom(W), 'it reads ~w, which the transaction does not set', [R]).
why_words(read_before_set(R), W) :- !, format(atom(W), 'it reads ~w before the transaction sets it', [R]).
why_words(W0, W) :- format(atom(W), '~q', [W0]).

%   An element the translator does not read (MathLoop): a residue block
%   with its XML, concluding the MathVariables set inside it.
block_residues(Assigns, Items) :-
    findall(Item, ( member(blk(El, Label, Names, XML), Assigns), block_residue(El, Label, Names, XML, Item) ), Items).

block_residue(El, Label, Names, XML, residue(Id, [title(Title), locator(TX), note(Note), source('OIPA XML', XML), concludes(Fs)])) :-
    nb_getval(oipa_residues, Rs), length(Rs, K), K1 is K + 1, format(atom(Id), 'r~w', [K1]),
    format(atom(WT), 'a ~w, which the translator does not read', [El]),
    nb_setval(oipa_residues, [blk(El, Label)-res(Id, WT)|Rs]),
    b_getval(oipa_tn, TN), format(atom(TX), '~w/Transaction.xml', [TN]),
    format(atom(Title), '~w ~w ~w', [TX, El, Label]),
    findall(F, ( member(N, Names), sym(N, sym(_, _, F, _)) ), Fs),
    findall(T, ( member(N, Names), sym(N, sym(_, _, _, Ty)), sym_text(N, computed, Ty, T) ), Ts),
    (   Ts == [] -> CT = 'nothing: it sets no MathVariable' ; atomic_list_concat(Ts, '; ', CT) ),
    format(string(Note), "Not translated: ~w.~nConclude: ~w.", [WT, CT]).

%   An assignment's lines: a condition-free one, or one guarded by its
%   MathIF; an IIF gives two, a RATE with a DEFAULT two. Its reads are of
%   the values set before it (position I - 1); a MathIF's condition, of
%   those set before the MathIF.
alternative(A, V, I-(Cond-mv(_, Type, DT, Attrs, Value)), Lines) :-
    P is I - 1, b_setval(oipa_pos, P),
    value_lines(A, V, Type, DT, Attrs, Value, Lines0),
    (   Cond == true -> Lines = Lines0
    ;   cond_goal(A, Cond, CG), maplist(guarded(CG), Lines0, Lines)
    ),
    b_setval(oipa_pos, end).

guarded(CG, L, and(CG, L)).

%   The variables of a condition outside its negations.
positive_vars(not(_), []) :- !.
positive_vars(G, Vs) :- compound(G), functor(G, F, 2), memberchk(F, [and, or]), !,
    G =.. [_, A, B], positive_vars(A, VA), positive_vars(B, VB), append(VA, VB, Vs).
positive_vars(G, Vs) :- term_variables(G, Vs).

%   A line that reads nothing of the activity (a VALUE, a plan field) is
%   still about it: its effective date says it exists.
about_the_activity(A, L, L) :- positive_vars(L, Vs), member(V, Vs), V == A, !.
about_the_activity(A, L, and(activity_kind(A), L)).

%   What the program processes: `an activity is a full surrender if the
%   effective date of the activity is a date` — the guard of a line that
%   reads nothing of the activity, in words (a twin is one transaction).
activity_kind_template(template(activity_kind/1, Text, [])) :-
    activity_kind_words(W), format(string(Text), "*an activity* is ~w", [W]).

activity_kind_rule(rule(activity_kind(A), activity_effective_date(A, _), [comment(C)])) :-
    b_getval(oipa_tn, TN), activity_kind_words(W),
    format(string(C), "An activity of this program is ~w: the ~w transaction it processes.", [W, TN]).

activity_kind_words(W) :-
    b_getval(oipa_tn, TN), camel_words(TN, Ws), atomic_list_concat(Ws, ' ', W0),
    ( Ws = [F|_], sub_atom(F, 0, 1, _, C), memberchk(C, [a, e, i, o, u]) -> Art = an ; Art = a ),
    format(atom(W), '~w ~w', [Art, W0]).

value_lines(A, V, _, DT, Attrs, expr(E), [G]) :- !,
    arith(A, E, X, Pre),
    finish(DT, Attrs, X, V, Assign),
    list_conj(Pre, Assign, G).
value_lines(A, V, _, _, _, value(X), [G]) :- !, value_of(X, C), ( number(C) -> G = (V is C) ; G = (V = C) ), ignore(A = A).
value_lines(_, _, _, _, _, field(_, _), _) :- !, throw(oipa_residue(field_under_mathif)).
value_lines(A, V, _, _, _, iif(C, First, Second), [G1, G2]) :- !,
    cond_goal(A, C, CG),
    iif_line(A, V, First, [CG], G1), iif_line(A, V, Second, [], G2).

value_lines(A, V, _, _, Attrs, rate(Desc, Crit), Lines) :- !,
    maplist(criterion_goal(A), Crit, Gs0, Xs), append(Gs0, Gs),
    rate_functor(Desc, Crit, RF), append(Xs, [V], Args), RG =.. [RF|Args],
    list_conj(Gs, RG, G1),
    (   memberchk('DEFAULT'=Df, Attrs) -> value_of(Df, DV), Lines = [G1, (V is DV)]
    ;   Lines = [G1]
    ).
value_lines(_, _, Type, _, _, _, _) :- throw(oipa_residue(unsupported_type(Type))).

%   An IIF's value: the MathVariable's own literal gives it, or a VALUE.
iif_line(A, V, N, Pre, G) :-
    ref_goal(A, N, X, Gs),
    (   Gs == [] -> ( number(X) -> E = (V is X) ; E = (V = X) ), list_conj(Pre, E, G)
    ;   ref_goal(A, N, V, Gs1), append(Pre, Gs1, [G0|Gs2]), list_conj([G0|Gs2], true, G)
    ).
criterion_goal(A, _-MV, Gs, X) :- ref_goal(A, MV, X, Gs).

%   ROUND n: round(X * 10^n) / 10^n; an INTEGER from a division: truncate.
finish(_, Attrs, X, V, (V is R)) :- memberchk('ROUND'=RS, Attrs), !,
    atom_number(RS, Nd), P is 10^Nd, R = round(X * P) / P.
finish('INTEGER', _, X, V, (V is truncate(X))) :- sub_term(Y, X), nonvar(Y), Y = (_ / _), !.
finish(_, _, X, V, true) :- var(X), !, V = X.            % the value another condition gives
finish(_, _, X, V, G) :- ( X = date(_, _, _) -> G = (V = X) ; G = (V is X) ).

list_conj([], G, G).
list_conj([P|Ps], G, C) :- foldl([X, Y0, and(Y0, X)]>>true, Ps, P, C0), ( G == true -> C = C0 ; C = and(C0, G) ).

%   A reference to a MathVariable: the literal that gives its value.
%   A computed MathVariable read inside a MathVariable is read as it is at
%   that point (oipa_pos: the assignments made before it): its final value,
%   or an earlier one when a later assignment changes it.
ref_goal(A, N, V, Gs) :-
    (   sym(N, sym(_, constant(X), _, _)) -> value_of(X, V), Gs = []      % a VALUE set once: written in place
    ;   sym(N, sym(_, plan(_, _), F, _)) -> G =.. [F, V], Gs = [G]
    ;   sym(N, sym(_, computed, F0, _)) -> read_version(N, F0, F), G =.. [F, A, V], Gs = [G]
    ;   sym(N, sym(_, _, F, _)) -> G =.. [F, A, V], Gs = [G]
    ;   throw(oipa_residue(unset(N)))
    ).

read_version(N, F0, F) :-
    total_assigns(N, T),
    ( nb_current(oipa_pos, P), integer(P) -> assigns_upto(N, P, J) ; J = T ),
    (   J =:= T -> F = F0
    ;   J =:= 0 -> throw(oipa_residue(read_before_set(N)))
    ;   want_version(N, J), version_functor(F0, J, T, F)
    ).

%   An expression: its value X and the literals it reads (each variable
%   read once per rule).
arith(A, E, X, Pre) :-
    b_setval(oipa_reads, []),
    arith_(A, E, X),
    b_getval(oipa_reads, Reads), reverse(Reads, Pre0), maplist(read_goal, Pre0, Pre).

read_goal(_-_-G, G).      % (no findall: the goals share the rule's variables)

arith_(_, num(N), N) :- !.
arith_(_, str(S), S) :- !.                        % '02' stays the code 02
arith_(_, bool(B), B) :- !.
arith_(A, ref(N), V) :- !, read_ref(A, N, V).
arith_(A, call(F, Args), V) :- !, function(A, F, Args, V).
arith_(A, -(E), -(X)) :- !, arith_(A, E, X).
arith_(A, E, X) :- E =.. [Op, E1, E2], memberchk(Op, [+, -, *, /, mod, ^]), !,
    arith_(A, E1, X1), arith_(A, E2, X2), X =.. [Op, X1, X2].
arith_(_, E, _) :- throw(oipa_residue(expression(E))).

read_ref(A, N, V) :-
    b_getval(oipa_reads, Rs),
    (   memberchk(N-V0-_, Rs) -> V = V0
    ;   ref_goal(A, N, V, Gs), ( Gs = [G] -> b_setval(oipa_reads, [N-V-G|Rs]) ; true )
    ).

%   The OIPA functions the corpus uses, as LE conditions.
function(A, 'DurationOf', [D1, D2], V) :- !,
    arith_(A, D1, X1), arith_(A, D2, X2), add_read(age_on_born(X2, X1, V)).
function(A, 'ANBAgeOf', [Birth, D], V) :- !,
    %  (inside a MathVariable its ledger row says approximated; elsewhere a note)
    (   nb_current(oipa_pos, P), integer(P) -> true
    ;   note("ANBAgeOf (the age at the nearest birthday) is written as the age six calendar months later: it can differ by a day at the half-year")
    ),
    arith_(A, Birth, B), arith_(A, D, X), add_read(le_is_months_after(D6, 6, X)), add_read(age_on_born(D6, B, V)).
function(A, 'DaysDiffOf', [D1, D2], V) :- !,
    arith_(A, D1, X1), arith_(A, D2, X2), add_read(le_is_days_after(X2, V, X1)).
function(A, 'MonthsAdd', [D, N], V) :- !,
    arith_(A, D, X), arith_(A, N, M), add_read(le_is_months_after(V, M, X)).
function(A, 'TruncateNumber', [E, num(0)], truncate(X)) :- !, arith_(A, E, X).
function(A, 'TruncateNumber', [E, num(P)], truncate(X * F) / F) :- !, arith_(A, E, X), F is 10^P.
function(A, 'MinOf', [E1, E2], V) :- !, arith_(A, E1, X1), arith_(A, E2, X2), add_read(min(X1, X2, V)).
function(A, 'MaxOf', [E1, E2], V) :- !, arith_(A, E1, X1), arith_(A, E2, X2), add_read(max(X1, X2, V)).
function(A, 'AbsOf', [E], abs(X)) :- !, arith_(A, E, X).
function(_, F, _, _) :- throw(oipa_residue(function(F))).

add_read(G) :- b_getval(oipa_reads, Rs), b_setval(oipa_reads, [G-_-G|Rs]).

%   A condition: comparisons (text compared as constants), And, Or, Not.
cond_goal(A, C, G) :- b_setval(oipa_reads, []), cond_(A, C, G0),
    b_getval(oipa_reads, Reads), reverse(Reads, Pre0), maplist(read_goal, Pre0, Pre),
    list_conj(Pre, G0, G1), ( Pre == [] -> G = G0 ; G = G1 ).

cond_(A, at(P, X), G) :- !,
    ( nb_current(oipa_pos, P0) -> true ; P0 = end ),
    b_setval(oipa_pos, P), cond_(A, X, G), b_setval(oipa_pos, P0).
cond_(A, and(X, Y), and(GX, GY)) :- !, cond_(A, X, GX), cond_(A, Y, GY).
cond_(A, or(X, Y), or(GX, GY)) :- !, cond_(A, X, GX), cond_(A, Y, GY).
cond_(A, not(X), not(GX)) :- !, cond_(A, X, GX).
cond_(A, cmp(Op, E1, E2), G) :- !,
    arith_(A, E1, X1), arith_(A, E2, X2),
    (   ( E1 = str(_) ; E2 = str(_) ), memberchk(Op, [=, \=]) -> G =.. [Op, X1, X2]
    ;   Op == (=) -> G = (X1 =:= X2)
    ;   Op == (\=) -> G = not(X1 =:= X2)
    ;   G =.. [Op, X1, X2]
    ).
cond_(A, E, G) :- arith_(A, E, X), G = (X = true).

		 /*******************************
		 *   CHECKS, SPAWNS, COPIES     *
		 *******************************/

check_rules(Checks, Rules) :-
    findall(rule(fails_the_check(A, Code), G, [label(L), provenance([as_stated_in(TX), at(At)]), comment(Msg)]),
            ( member(check(Code0, Type, Msg0, C), Checks), message_words(Msg0, Msg),
              check_code(Code0, Code), unread(cond_goal(A, C, CG), check(Code)),
              ( Type == 'ErrorOnFalse' -> G = not(CG) ; G = CG ),
              b_getval(oipa_tn, TN), format(atom(TX), '~w/ValidateExpressions.xml', [TN]),
              format(atom(At), 'Expression ~w', [Code]), downcase_atom(Code, L) ), Rules).

%   A message's $$$GrossAmountMV$$$ placeholders as the values' names:
%   `A withdrawal of [the gross amount] exceeds …`.
message_words(M0, M) :-
    atomic_list_concat(Parts, '$$$', M0),
    placeholders(Parts, 1, Ws), atomic_list_concat(Ws, M).

placeholders([], _, []).
placeholders([P|Ps], I, [W|Ws]) :-
    (   I mod 2 =:= 0, P \== '' -> mv_words(P, Vs), atomic_list_concat(Vs, ' ', V), format(atom(W), '[the ~w]', [V])
    ;   W = P
    ),
    I1 is I + 1, placeholders(Ps, I1, Ws).

check_code(none, check) :- !.
check_code(C, C).

%   An attached rule the translator cannot read is left out, and says so in
%   the ledger.
unread(Goal, What) :-
    catch(Goal, oipa_residue(Why),
          ( why_words(Why, WT),
            format(string(N), "the attached rule ~q is not translated: ~w", [What, WT]), note(N), fail )).

%   What an accepted activity does (an activity failing a check is refused).
accepted(true, _, true).
accepted(no_check, A, not(fails_the_check(A, _))).

spawn_rules(Acc, Spawns, Rules) :-
    findall(rule(spawns(A, T), G, [label(L), provenance([as_stated_in(TX), at(At)])]),
            ( nth1(I, Spawns, spawn(T, Tests)),
              unread(maplist(cond_goal(A), Tests, [G1|Gs]), spawn(T)), foldl([X, Y0, and(Y0, X)]>>true, Gs, G1, G2),
              accepted(Acc, A, NC), ( NC == true -> G = G2 ; G = and(G2, NC) ),
              b_getval(oipa_tn, TN), format(atom(TX), '~w/SpawnActivities.xml', [TN]),
              format(atom(At), 'Spawn ~w', [I]), format(atom(L), 'spawn_~w', [I]) ), Rules).

copy_rules(Acc, Copies, Rules) :-
    findall(rule(H, and(G1, true), [label(L), provenance([as_stated_in(TX), at(At)])]),
            ( member(copy(From, To), Copies), copy_template(To, F, _),
              unread(ref_goal(A, From, V, Gs), copy(To)), ( Gs = [G0] -> true ; G0 = true ),
              accepted(Acc, A, NC), ( NC == true -> G2 = G0 ; G2 = and(G0, NC) ),
              about_the_activity(A, G2, G1),
              H =.. [F, A, V],
              b_getval(oipa_tn, TN), format(atom(TX), '~w/CopyToPolicyFields.xml', [TN]),
              format(atom(At), 'Field ~w', [To]), snake(To, S), atom_concat(copy_, S, L) ), Rules0),
    maplist([rule(H, and(B, true), O), rule(H, B, O)]>>true, Rules0, Rules).

		 /*******************************
		 *         RATE TABLES          *
		 *******************************/

rate_functor(Desc, Crit, F) :-
    snake(Desc, S), findall(C, member(C-_, Crit), Cs), length(Cs, N),
    format(atom(F), 'rate_~w_~w', [S, N]).

rate_templates(Syms, Ts) :-
    b_getval(oipa_tn, _),
    findall(template(F/N1, Text, []),
            ( member(sym(N, computed, _, _), Syms), rate_of(N, Desc, Crit),
              rate_functor(Desc, Crit, F), length(Crit, N0), N1 is N0 + 1,
              rate_text(Desc, Crit, Text) ), Ts0),
    list_to_set(Ts0, Ts).

rate_of(N, Desc, Crit) :- nb_current(oipa_rates, Rs), memberchk(N-Desc-Crit, Rs).

rate_text(Desc, Crit, Text) :-
    camel_words(Desc, Ws), atomic_list_concat(Ws, ' ', W),
    findall(P, ( member(C-_, Crit), camel_words(C, CW), atomic_list_concat(CW, ' ', CT), format(string(P), "~w *a ~w*", [CT, CT]) ), Ps),
    atomic_list_concat(Ps, ' and ', PT),
    snake(Desc, S),
    format(string(Text), "the ~w rate for ~w is *a rate* under table ~w", [W, PT, S]).

%   The rate tables the transaction reads, each loaded from a CSV the twin
%   carries (the plan's rates of that description).
rate_tables(_PlanDir, Syms, Tables) :-
    b_getval(oipa_tn, _),
    findall(N-Desc-Crit, ( member(sym(N, computed, _, _), Syms), assign_rate(N, Desc, Crit) ), Rs0),
    list_to_set(Rs0, Rs), nb_setval(oipa_rates, Rs),
    findall(table(S, [policy(unique), loaded_from(CSV)], Cols, []),
            ( member(_-Desc-Crit, Rs), snake(Desc, S), format(atom(CSV), '~w.csv', [S]),
              findall(C, ( member(C0-_, Crit), camel_words(C0, CW), atomic_list_concat(CW, ' ', C) ), Cs),
              append(Cs, [rate], Cols) ), Tables0),
    list_to_set(Tables0, Tables).

assign_rate(N, Desc, Crit) :-
    nb_current(oipa_assigns, As), member(a(N, _, mv(_, 'RATE', _, _, rate(Desc, Crit))), As).

write_rate_tables(PlanDir, transaction(_, _, Math, _, _, _), Dir) :-
    plan_rates(PlanDir, Rows),
    flatten_math(Math, true, As),
    forall(( member(a(_, _, mv(_, 'RATE', _, _, rate(Desc, Crit))), As) ),
           ( snake(Desc, S), format(atom(F), '~w/~w.csv', [Dir, S]),
             findall(C, member(C-_, Crit), Cs),
             setup_call_cleanup(open(F, write, Out),
                 ( findall(H, ( member(C, Cs), camel_words(C, CW), atomic_list_concat(CW, ' ', H) ), Hs),
                   append(Hs, [rate], Hd), atomic_list_concat(Hd, ',', HL), format(Out, "~w~n", [HL]),
                   forall(( member(Desc-Pairs, Rows), findall(V, ( member(C, Cs), memberchk(C=V, Pairs) ), Vs),
                            memberchk('Rate'=R, Pairs) ),
                          ( append(Vs, [R], Line), atomic_list_concat(Line, ',', L), format(Out, "~w~n", [L]) )) ),
                 close(Out)) )).

		 /*******************************
		 *            THE VIEW          *
		 *******************************/

%   One declaration of the twin, whichever section it is in.
declared_text(Items, Key, Text) :-
    member(I, Items),
    ( I = template(Key, Text, _) ; I = function(Key, Text, _) ).

%   A screen that prices an activity (le_summary.md §17.10): its fields, the
%   policy it finds, the first value OIPA logs as the result, the checks.
view(TN, Plan, Syms, Templates, Queries, view(V, Sentences)) :-
    snake(TN, V),
    format(string(S1), "the title is \"~w (~w)\".", [TN, Plan]),
    %  declared_text/3, not member(template(...)): a field is declared in
    %  `the functions are:` (declaration_item/2), and the view asks for its
    %  facts either way.
    findall(T, ( declared_text(Templates, F/2, T0),
                 ( F == activity_effective_date ; member(sym(_, activity(_), F, _), Syms) ), plain_text(T0, T) ), As0),
    list_to_set(As0, As),
    findall(T, ( declared_text(Templates, F/2, T0), member(sym(_, policy(_), F, _), Syms), plain_text(T0, T) ), Ps),
    group_sentence("the activity", As, SA), group_sentence("the policy it finds", Ps, SP),
    (   member(query(Q, G), Queries), \+ memberchk(Q, [checks, spawns]), \+ sub_atom(Q, 0, _, _, policy_after_), G \= fails_the_check(_, _)
    ->  format(string(SR), "the result is the answer to query ~w.", [Q]), Rs = [SR]
    ;   Rs = []
    ),
    ( memberchk(query(checks, _), Queries) -> Cs = ["the answers to \"which activity fails the check which code\" are listed as \"Checks\"."] ; Cs = [] ),
    append([[S1, "the case is a scenario."], SA, SP, Rs, Cs, ["the result shows its citations."]], Sentences).

plain_text(T0, T) :-
    atom_string(T0, S0), split_string(S0, "*", "", Parts),
    atomic_list_concat(Parts, '', T1), atom_string(T1, T).

group_sentence(_, [], []) :- !.
group_sentence(Title, Ts, [S]) :-
    atomic_list_concat(Ts, ',\n        ', J),
    format(string(S), "the facts about \"~w\" are\n        ~w.", [Title, J]).

		 /*******************************
		 *      QUERIES AND TESTS       *
		 *******************************/

%   A query per logged MathVariable, and for the checks, spawns and copies.
queries(Syms, Checks, Spawns, Copies, Qs) :-
    findall(query(QN, G), ( member(sym(N, computed, F, _), Syms), logged(N), F = QN, G =.. [F, _, _] ), Q1),
    ( Checks == [] -> Q2 = [] ; Q2 = [query(checks, fails_the_check(_, _))] ),
    ( Spawns == [] -> Q3 = [] ; Q3 = [query(spawns, spawns(_, _))] ),
    findall(query(QN, G), ( member(copy(_, To), Copies), copy_template(To, F, _), snake(To, S),
                            atom_concat(policy_after_, S, QN), G =.. [F, _, _] ), Q4),
    list_to_set(Q4, Q4s),
    append([Q1, Q2, Q3, Q4s], Qs).

logged(N) :- nb_current(oipa_assigns, As), member(a(N, _, mv(_, _, _, At, _)), As), memberchk('LOG'='Yes', At), !.

%   An activity of a policy life, as a scenario: its fields, the policy it
%   found, the oracle's values.
scenario_of(Life, S, Syms, Checks, Spawns, Copies, SN, Facts, Expects) :-
    atom_string(Id, S.id), format(atom(SN), '~w_~w', [Life, Id]),
    findall(G, ( member(sym(_, activity(Fd), F, T), Syms), fact_value(S, activity, Fd, T, V), G =.. [F, Id, V] ), F1),
    findall(G, ( member(sym(_, policy(Fd), F, T), Syms), fact_value(S, policy, Fd, T, V), G =.. [F, Id, V] ), F2),
    (   memberchk(sym(_, activity('EffectiveDate'), _, _), Syms) -> F0 = []
    ;   typed_value(date, S.date, D0), F0 = [activity_effective_date(Id, D0)]
    ),
    append([F0, F1, F2], Facts),
    findall(expects(QN, As), ( member(sym(N, computed, F, T), Syms), logged(N), F = QN,
                               findall(G, ( get_dict(values, S, Vals), atom_string(N, NS), atom_string(NA, NS),
                                            get_dict(NA, Vals, X), typed_value(T, X, V), G =.. [F, Id, V] ), As) ), E1),
    (   Checks == [] -> E2 = []
    ;   findall(fails_the_check(Id, C), ( member(Er, S.errors), atom_string(C, Er.number) ), Cs),
        E2 = [expects(checks, Cs)]
    ),
    (   Spawns == [] -> E3 = []
    ;   findall(spawns(Id, T), ( member(T0, S.spawns), atom_string(T, T0) ), Ss), E3 = [expects(spawns, Ss)]
    ),
    findall(expects(QN, As), ( member(copy(_, To), Copies), copy_template(To, F, _), snake(To, Sn),
                               atom_concat(policy_after_, Sn, QN),
                               findall(G, ( get_dict(updates, S, U), atom_string(To, TS), atom_string(TA, TS),
                                            get_dict(TA, U, X), copy_value(X, V), G =.. [F, Id, V] ), As) ), E4a),
    list_to_set(E4a, E4),
    append([E1, E2, E3, E4], Expects).

fact_value(S, activity, 'EffectiveDate', _, V) :- !, atom_string(A, S.date), typed_value(date, A, V).
fact_value(S, activity, Fd, T, V) :- atom_string(Fd, FS), atom_string(K, FS), get_dict(K, S.fields, X), typed_value(T, X, V).
fact_value(S, policy, Fd, T, V) :- atom_string(Fd, FS), atom_string(K, FS), get_dict(K, S.policy, X), typed_value(T, X, V).

typed_value(date, X, date(Y, M, D)) :- !, atom_string(A, X), atomic_list_concat([YS, MS, DS], '-', A),
    atom_number(YS, Y), atom_number(MS, M), atom_number(DS, D).
typed_value(value, X, V) :- !, atom_string(V, X).            % a TEXT: a code stays a code (02)
typed_value(_, X, V) :- atom_string(A, X), ( atom_number(A, N) -> V = N ; V = A ).

copy_value(X, V) :- atom_string(A, X), ( atomic_list_concat([_, _, _], '-', A), typed_value(date, A, V) -> true ; typed_value(value, A, V) ).

		 /*******************************
		 *            LEDGER            *
		 *******************************/

ledger(TN, Assigns, Syms, Checks, Spawns, Copies, Notes, Ledger) :-
    findall(entry(E, mathvariable, V, M, N, none),
            ( member(sym(N, K, _, _), Syms), format(string(E), "~w/Transaction.xml MathVariable ~w", [TN, N]),
              mv_entry(Assigns, N, K, V, M) ), L1a),
    nb_getval(oipa_residues, Rs),
    findall(entry(E, Kind, residue, M, Id, none),
            ( member(blk(El, Label, Names, _), Assigns), memberchk(blk(El, Label)-res(Id, _), Rs),
              downcase_atom(El, Kind),
              format(string(E), "~w/Transaction.xml ~w ~w", [TN, El, Label]),
              ( Names == [] -> NT = none ; atomic_list_concat(Names, ', ', NT) ),
              format(atom(M), '~w is not translated: a residue block with its XML (MathVariables set inside: ~w)', [El, NT]) ), L0),
    append(L0, L1a, L1),
    findall(entry(E, validation, encoded, 'ValidateExpressions Expression -> `the activity fails the check`', C, M),
            ( member(check(C, _, M, _), Checks), format(string(E), "~w/ValidateExpressions.xml ~w", [TN, C]) ), L2),
    findall(entry(E, spawn, encoded, 'Spawn -> `the activity spawns the transaction` (only an activity that fails no check)', T, none),
            ( member(spawn(T, _), Spawns), format(string(E), "~w/SpawnActivities.xml Spawn ~w", [TN, T]) ), L3),
    findall(entry(E, copy, encoded, 'CopyToPolicyFields -> the policy field after the activity (only an activity that fails no check)', To, none),
            ( member(copy(F, To), Copies), format(string(E), "~w/CopyToPolicyFields.xml ~w -> ~w", [TN, F, To]) ), L4),
    findall(entry(N, note, approximated, N, TN, none), member(N, Notes), L5),
    append([L1, L2, L3, L4, L5], Ledger).

mv_entry(_, N, _, residue, M) :-
    nb_current(oipa_residues, Rs), memberchk(N-res(Id, WT), Rs), !,
    format(atom(M), 'not translated (~w): residue block ~w with its XML', [WT, Id]).
mv_entry(Assigns, N, in_block(L), residue, M) :- !,
    ( member(a(N, _, mv(_, El, _, _, in_block(El, L))), Assigns) -> true ; El = 'MathLoop' ),
    nb_getval(oipa_residues, Rs),
    ( memberchk(blk(El, L)-res(Id, _), Rs) -> true ; Id = '?' ),
    format(atom(M), 'set inside the ~w ~w: part of its residue block ~w', [El, L, Id]).
mv_entry(_, _, activity(F), encoded, M) :- format(atom(M), 'FIELD -> the activity field ~w, a fact of the case', [F]).
mv_entry(_, _, policy(F), encoded, M) :- format(atom(M), 'POLICYFIELD -> the policy field ~w the activity finds, a fact of the case', [F]).
mv_entry(_, _, plan(F, _), encoded, M) :- format(atom(M), 'PLANFIELD -> the plan field ~w, a fact of the program (PlanFields.csv)', [F]).
mv_entry(_, _, constant(X), encoded, M) :- format(atom(M), 'VALUE -> the constant ~w', [X]).
mv_entry(As, N, computed, V, M) :-
    findall(T-C, member(a(N, C, mv(_, T, _, _, _)), As), TCs),
    nb_getval(oipa_versions_done, Vs),
    (   member(a(N, _, mv(_, _, _, _, X)), As), sub_term(call('ANBAgeOf', _), X)
    ->  V = approximated, M = 'FUNCTION ANBAgeOf -> the age six calendar months later (lib/temporal)'
    ;   TCs = [_, _|_], memberchk(N-_, Vs)
    ->  V = encoded,
        findall(J, member(N-J, Vs), Js0), sort(Js0, Js), maplist([J, O]>>ordinal(J, O), Js, Os),
        atomic_list_concat(Os, ', ', OT),
        format(atom(M), 'reassigned (MathIF) -> an otherwise cascade, the latest assignment first; read between its assignments, so its ~w value (the assignments made so far) is a rule of its own', [OT])
    ;   TCs = [_, _|_] -> V = encoded, M = 'reassigned (MathIF) -> an otherwise cascade, the latest assignment first'
    ;   TCs = ['IIF'-_] -> V = encoded, M = 'IIF -> an otherwise cascade'
    ;   TCs = ['RATE'-_] -> V = encoded, M = 'RATE -> a decision table loaded from the plan''s rates, DEFAULT as the last line'
    ;   TCs = ['FUNCTION'-_] -> V = encoded, M = 'FUNCTION -> LE''s date and number built-ins'
    ;   V = encoded, M = 'EXPRESSION -> a rule, the MathVariables it reads as conditions'
    ).

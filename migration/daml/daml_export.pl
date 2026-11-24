/** <module> LE for LPS -> Daml: File ▸ Export to Another System

    The way back of Phase 2g, the Daml analogue of Deploy as Solidity: an LE
    for LPS program's LPS reading (le_lps:le_lps_module/5) written as a Daml
    module with a Daml Script, ready for `dpm build` and a Canton sandbox.

      - the whole state is ONE contract, `State` (Daml 3 has no contract
        keys: a fluent cannot be looked up by its values, so the fluents
        are lists of records in one contract); an operator party is its
        signatory, every party of the program an observer;
      - each action is a choice of State, its controller the acting party
        (the action's first place) — or the operator when the action's first
        place is not a party; its other places are the choice's arguments;
      - an integrity constraint on an action is an `assertMsg` before the
        update, one without an action an `assertMsg` on the new state;
      - the causal laws are the update: every termination and every update's
        old value computed on the state before, then every initiation added,
        in LPS's reading (a fluent is a set: `dedup`);
      - `initially` is the created State; the program's scenario is the
        script: each observed action submitted with `trySubmit`, a refused
        one leaving the state as it was (as LPS2 refuses it), and the script
        returns the final State.

    Types come from the program: a place that holds an acting party, or
    shares a variable with one, is a Party; a number, or a place a law
    compares with one or computes with, a Decimal; a list a list of those
    (`[Party]` when a member is a party, or when the place is called a list of
    parties: `*an observers party list*`); anything else Text. A party a law
    names (`the treasury`) is a field of State, allocated by the script. A
    fluent's default (`0 by default`) is its value when no record has it;
    the program's facts (`the unlimited allowance is 1000000`) are
    alternatives; `findall`, `length` and `member` are Daml's list
    functions.

    Rules are functions (RULES AS FUNCTIONS, below): a timeless rule, an
    intensional fluent or a predicate stated as facts, asked with some of
    its places known, is a function from those to the list of the others,
    one per pattern a law, a constraint or another rule asks it in. A
    predicate the program leaves to Prolog (its `.lps` companion) comes from
    a Daml companion, `<knowledge base>.daml` beside the program. A reactive
    rule whose conditions read the state is the operator's choice
    ReactiveCycle, which the script exercises once per LPS cycle.

    What has no straight translation — a reactive rule that reacts to an
    event (a Daml trigger would be one) or takes a party's action, composite
    events, constraints relating two actions, a place that holds a party and
    elsewhere a list, a predicate left to Prolog with no Daml companion — is
    refused, each with its reason, never dropped silently. Each refusal says
    where it is: the line of the sentence whose term the translation was
    writing when it met it (term_where/3), so that a partial export
    (le_import.pl) can leave that sentence out.

    Beside each part of the module written from a law, a constraint, a rule
    or a fact — an assertMsg, a fluent's update, a function, a step of the
    reactive cycle, the initial State — a comment says the line of the
    program it came from (`-- Logical English line 74: when a transferor
    delivers …`; `-- Logical English lines 84, 88` where one part merges
    several sentences).

        lps_daml(+Terms, -Daml, -Notes)
        lps_daml(+Terms, +Prov, -Daml, -Notes)
*/

:- module(daml_export, [export_daml/3, applies_daml/1, lps_daml/3, lps_daml/4, party_key/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(option)).
:- use_module(library(readutil)).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer)).

applies_daml(KB) :-
    le_writer:kb_to_ir(KB, program(H, _)), memberchk(target(lps), H).

%!  export_daml(+KB, +Options, -Result) is det.
%
%   Result is exported(File, Text, Notes, []), or refused(Problems) when
%   the program has something with no straight translation (check_daml/3;
%   not run again when Options has checked(true): le_import ran it).
export_daml(KB, Options, refused(Problems)) :-
    \+ memberchk(checked(true), Options),
    ( memberchk(text(Doc0), Options) -> true ; Doc0 = "" ), companion_setup(Options, Doc0),
    check_daml(KB, Options, Problems), Problems \== [], !.
export_daml(KB, Options, Result) :-
    ( memberchk(text(Doc), Options) -> true ; Doc = "" ),
    le_lps:le_lps_module(KB, Doc, Internal, Prov, _),
    term_string_terms(Internal, Terms),
    slot_names(KB, SlotNames), b_setval(daml_slot_names, SlotNames),
    companion_setup(Options, Doc),
    partial_setup(KB, Options),
    source_setup(Prov, Doc),
    lps_daml_(Terms, Daml, Notes0, Refused),
    (   Daml == none
    ->  maplist(term_where(Prov), Refused, Ps),
        Result = refused(Ps)
    ;   append(Notes0, ["Run it: put Main.daml in a Daml package (dpm new <name> --template empty-skeleton; add daml-script to the dependencies), dpm build, dpm sandbox, then dpm script --dar .daml/dist/<name>-0.0.1.dar --script-name Main:scenario --ledger-host localhost --ledger-port 6865 --upload-dar true --output-file final.json: the final State is the program's final state."], Notes),
        Result = exported('Main.daml', Daml, Notes, [])
    ).

%!  check_daml(+KB, +Options, -Problems) is det.
%
%   The check before the module is written (le_import.pl, export_check/2):
%   the program's LPS reading must exist (an error of LE for LPS is a
%   problem), and every term of it must have a straight translation — the
%   refusals below, each with the line of its sentence, then whatever the
%   translation itself meets (a condition, a term, a type it cannot write).
check_daml(KB, Options, Problems) :-
    ( memberchk(text(Doc), Options) -> true ; Doc = "" ),
    companion_setup(Options, Doc),
    le_lps:le_lps_module(KB, Doc, Internal, Prov, Issues),
    findall(problem(W, M),
            ( member(le_lps_issue(error, _, M0, L, _), Issues),
              format(string(M), "~w", [M0]),
              ( integer(L), L > 0 -> W = line(L) ; W = none ) ),
            LPSProblems),
    (   LPSProblems \== [] -> Problems = LPSProblems
    ;   Internal == "" -> Problems = [problem(none, "the program has no LPS reading: nothing to write")]
    ;   term_string_terms(Internal, Terms),
        slot_names(KB, SlotNames), b_setval(daml_slot_names, SlotNames),
        partial_setup(KB, Options),
        source_setup(Prov, Doc),
        daml_problems(Terms, Ps0),
        maplist(term_where(Prov), Ps0, Problems)
    ).

daml_problems(Terms, Ps) :-
    findall(problem(term(N), R), ( nth0(N, Terms, T), ( refusal(T, R) ) ), Rs0),
    list_to_set(Rs0, Rs),
    (   Rs \== [] -> Ps = Rs
    ;   nb_setval(daml_export_notes, []),
        catch(( module_text(Terms, _) -> Ps = [] ; Ps = [problem(none, "the Daml module could not be written")] ),
              E, refused_problems(E, Ps))
    ).

%   A refusal met while writing the module, as problems: at the term that
%   was being written when it was met (daml_where/1), or, for a predicate
%   left to Prolog with no Daml, at each term that calls it.
refused_problems(daml_refuse(Why), [problem(W, Why)]) :- !,
    ( nb_current(daml_where, W0), W0 \== [] -> W = W0 ; W = none ).
refused_problems(daml_refuse_all(Ps), Ps) :- !.
refused_problems(E, _) :- throw(E).

%   term(N): the N-th term of the LPS reading (from 0), whose sentence's
%   line the provenance has.
term_where(Prov, problem(term(N), M), problem(W, M)) :- !,
    ( memberchk(prov(N, L, _), Prov), integer(L), L > 0 -> W = line(L) ; W = none ).
term_where(_, P, P).

%   The term the translation is writing (term(N)), for the place of a
%   refusal met there; none while it writes what no one sentence states
%   (the declarations, the State's types, the scenario). Not backtrackable:
%   the refusal is a throw, which undoes what b_setval/2 set.
daml_where(N) :- ( integer(N) -> nb_setval(daml_where, term(N)) ; nb_setval(daml_where, none) ).

%   A partial export (le_import.pl): a predicate whose clauses it left out
%   is not one left to Prolog.
partial_setup(KB, Options) :-
    (   member(partial(Rs), Options), is_list(Rs)     % (the request itself is partial(true))
    ->  nb_setval(daml_partial, true),
        %  (the templates' words, to name a predicate the export left out)
        findall(F/N-Text,
                ( catch(le_writer:kb_templates(KB, Ts), _, fail), member(T, Ts),
                  ( T = template(F0, Text, _) ; T = fluent(F0, Text, _) ; T = event(F0, Text, _) ; T = action(F0, Text, _) ),
                  atom_string(Text, TS), split_string(TS, "*", "", Parts), length(Parts, L), N is (L - 1) // 2,
                  ( current_predicate(KB:le_lps_functor/2), KB:le_lps_functor(F0/N, F1) -> F = F1 ; F = F0 ) ),
                Texts),
        nb_setval(daml_template_texts, Texts)
    ;   nb_setval(daml_partial, false)
    ).

%   The fields of a record and the arguments of a choice are named by the
%   places of the LE template (`*an iou* is an iou with issuer *an issuer*,
%   … and observers list *an observers list*` -> iou, issuer, …,
%   observersList): slot(F, N, I)-Name, F the functor LPS knows.
slot_names(KB, Names) :-
    findall(slot(F, N, I)-Nm,
            ( current_predicate(KB:le_dict/1), KB:le_dict(D), D =.. [dict, [F0|Args], NTs|_],
              length(Args, N), N > 0,
              ( current_predicate(KB:le_lps_functor/2), KB:le_lps_functor(F0/N, F1) -> F = F1 ; F = F0 ),
              findall(T, member(_-T, NTs), Ts), length(Ts, N),
              field_names(Ts, Nms), nth1(I, Nms, Nm) ),
            Names0),
    list_to_set(Names0, Names).

field_names(Types, Names) :-
    foldl(field_name_of, Types, []-1, RevNames-_), reverse(RevNames, Names).

field_name_of(T, Seen-I, [Nm|Seen]-I1) :-
    I1 is I + 1,
    format(atom(A), '~w', [T]), split_string(A, " _-", " ", Ws0), exclude(==(""), Ws0, Ws),
    (   Ws = [W|Rest], W \== "", maplist([X, Y]>>( string_chars(X, [C|Cs]), upcase_atom(C, U), atom_chars(Y, [U|Cs]) ), Rest, Caps),
        atomic_list_concat([W|Caps], Nm0), atom_codes(Nm0, [C0|_]), code_type(C0, alpha)
    ->  downcase_first(Nm0, Nm1)
    ;   format(atom(Nm1), 'a~w', [I])
    ),
    (   ( memberchk(Nm1, Seen) ; reserved(Nm1) ) -> format(atom(Nm), '~w~w', [Nm1, I]) ; Nm = Nm1 ).

downcase_first(A, B) :- sub_atom(A, 0, 1, _, X), sub_atom(A, 1, _, 0, R), downcase_atom(X, L), atom_concat(L, R, B).

%   A choice's argument: the place's name, unless the State has a field of
%   that name (a choice argument would hide it), then with `Arg`.
choice_arg(AF, AN, I, Nm) :-
    slot_field(AF, AN, I, Nm0),
    (   nb_current(daml_state_fields, Fs), memberchk(Nm0, Fs) -> atom_concat(Nm0, 'Arg', Nm) ; Nm = Nm0 ).

%   The name of the I-th place of F/N (a1, a2, ... when there is no template).
slot_field(F, N, I, Nm) :-
    (   nb_current(daml_slot_names, Ns), memberchk(slot(F, N, I)-Nm0, Ns) -> Nm = Nm0
    ;   format(atom(Nm), 'a~w', [I])
    ).

term_string_terms(Text, Terms) :-
    setup_call_cleanup(open_string(Text, In), read_all(In, Terms), close(In)).
read_all(In, Ts) :- read_term(In, T, []), ( T == end_of_file -> Ts = [] ; Ts = [T|R], read_all(In, R) ).

		 /*******************************
		 *            THE MODULE        *
		 *******************************/

%!  lps_daml(+Terms, -Daml, -Notes) is det.
%
%   Daml is the module's text, or `none` when the program has a feature
%   with no straight translation (Notes say which).
lps_daml(Terms, Daml, Notes) :-
    lps_daml(Terms, [], Daml, Notes).

%!  lps_daml(+Terms, +Prov, -Daml, -Notes) is det.
%
%   As lps_daml/3, with the provenance of the terms (le_lps_module/5's
%   prov(N, Line, _)): the comment beside each part says its line.
lps_daml(Terms, Prov, Daml, Notes) :-
    source_setup(Prov, ""), nb_setval(daml_partial, false),
    lps_daml_(Terms, Daml, Notes, _).

%   Refused: the problems (problem(term(N) or none, Message)) when Daml is
%   none.
lps_daml_(Terms, Daml, Notes, Refused) :-
    nb_setval(daml_export_notes, []),
    findall(problem(term(N), R), ( nth0(N, Terms, T), refusal(T, R) ), Rs0), list_to_set(Rs0, Refused0),
    (   Refused0 \== []
    ->  Daml = none, findall(R, member(problem(_, R), Refused0), Rs1), list_to_set(Rs1, Notes), Refused = Refused0
    ;   catch(( module_text(Terms, Daml), Refused = [] ), E,
              ( refused_problems(E, Refused), Daml = none, forall(member(problem(_, Why), Refused), note(Why)) )),
        forall(( member(l_timeless(H, _), Terms), functor(H, F, N), \+ fun_requested(F/N) ),
               ( format(string(TN), "the timeless rule for ~w/~w is not written: no law, constraint or rule the module has reads it, and Daml has no queries", [F, N]), note(TN) )),
        nb_getval(daml_export_notes, N0), reverse(N0, Notes)
    ).

note(N) :- nb_getval(daml_export_notes, Ns), ( memberchk(N, Ns) -> true ; nb_setval(daml_export_notes, [N|Ns]) ).

%   A reactive rule is written as the operator's choice ReactiveCycle (the
%   script exercises it once per cycle) when its conditions read the state
%   and the rules, and it takes actions: one whose conditions are events, or
%   whose conclusion is not a list of actions, still has no Daml form.
refusal(reactive_rule(Cs, Ts), "a reactive rule (if ... then the program acts on its own) whose condition is an event, or whose conclusion is not a list of actions: Daml has no agent watching events — a Daml trigger would be one") :-
    \+ cycle_rule(Cs, Ts).
refusal(reactive_rule(_, _, _), "a reactive rule (if ... then the program acts on its own) with times of its own: not translated to Daml").
refusal(d_pre(Cs), "a constraint relating two actions at once: Daml submits one command at a time") :-
    aggregate_all(count, member(happens(_, _, _), Cs), N), N > 1.
refusal(l_events(_, _), "a composite event: not translated to Daml").
refusal(achieve(_), "a goal to achieve (planning): Daml has no planner — a choice is taken by a party, not searched for").

module_text(Terms, Text) :-
    daml_where(none),
    ( memberchk(fluents(Fls0), Terms) -> true ; Fls0 = [] ),
    %  the rules (timeless rules, intensional fluents) are Daml functions,
    %  written on demand, one per pattern of the places a caller knows
    rules_setup(Terms),
    %  an intensional fluent is a function of the state, not a field of it
    exclude(intensional_fluent, Fls0, Fls),
    ( memberchk(actions(Acts0), Terms) -> true ; Acts0 = [] ),
    %  (the actions a program only observes still need a choice)
    findall(A, ( member(observe(Es, _), Terms), member(E, Es), functor(E, F, N), functor(A, F, N) ), ObsA),
    append(Acts0, ObsA, Acts1), sort_by_functor(Acts1, Acts),
    types(Terms, Fls, Acts, Types),
    b_setval(daml_types, Types),
    findall(R, ( member(F, Fls), functor(F, Fn, N), N > 0, rec_name(Fn, R) ), Recs), b_setval(daml_records, Recs),
    ( memberchk(defaults(Dfs), Terms) -> true ; Dfs = [] ), b_setval(daml_defaults, Dfs),
    facts(Terms, Facts), b_setval(daml_facts, Facts),
    ( memberchk(initial_state(Init), Terms) -> true ; Init = [] ),
    findall(E-T, ( member(observe(Es, T), Terms), member(E, Es) ), Obs0),
    sort(2, @=<, Obs0, Obs),
    law_parties(Terms, Types, LawPs), b_setval(daml_law_parties, LawPs),
    findall(Fd, ( member(F0, Fls), functor(F0, Fn0, _), field_name(Fn0, Fd) ), FluentFields),
    findall(V, ( member(P, LawPs), party_var(P, V) ), PartyFields),
    append([[operator, parties], PartyFields, FluentFields], StateFields), b_setval(daml_state_fields, StateFields),
    parties(Types, Init, Obs, Ps0), append(Ps0, LawPs, Ps1), sort(Ps1, Parties),
    with_output_to(string(Body), (
        forall(member(F, Fls), record_decl(F)),
        state_template(Terms, Fls, Acts, LawPs),
        script(Terms, Fls, Acts, Init, Obs, Parties, LawPs) )),
    functions_text(Funs),
    daml_where(none),
    nb_getval(daml_companion_missing, Missing0),
    (   Missing0 \== []
    ->  reverse(Missing0, Missing),
        ( nb_current(daml_companion_file, CF) -> true ; CF = '<knowledge base>.daml' ),
        %  one problem for each term that calls one: there it is used
        findall(W, member(_-W, Missing), Ws0), list_to_set(Ws0, Ws),
        findall(problem(W, M),
                ( member(W, Ws),
                  findall(L, member(L-W, Missing), Ls), list_to_set(Ls, Ls1),
                  missing_message(CF, Ls1, M) ),
                Ps),
        throw(daml_refuse_all(Ps))
    ;   true
    ),
    companion_parts(CImports, CBody),
    %  (DA.Date's `date` would clash with a record field named date)
    ( ( uses_dates(Terms) ; CBody \== "" ) -> DateImport = "import DA.Date hiding (date)\nimport qualified DA.Date as D\n" ; DateImport = "" ),
    with_output_to(string(Text), (
        format("-- Generated from a Logical English (LPS) program by the Daml exporter of Logical English.~n"),
        format("-- The whole state is one contract, State; each action a choice of it.~n"),
        ( Funs \== "" -> format("-- The program's rules are functions, one for each way a law, a constraint or a rule asks them.~n") ; true ),
        format("~nmodule Main where~n~nimport Daml.Script~nimport DA.List (dedup)~n~w~w~n", [DateImport, CImports]),
        format("-- (a fluent's value, or its default)~nfirstOr : a -> [a] -> a~nfirstOr d xs = case xs of~n  [] -> d~n  x :: _ -> x~n~n"),
        write(Body),
        ( Funs \== "" -> format("~n-- The rules~n~n~w", [Funs]) ; true ),
        ( CBody \== "" -> format("~n-- From the companion file (what the program leaves to Prolog, in Daml)~n~n~w~n", [CBody]) ; true ) )).

%   What a term asks of a predicate the module has no Daml for: left to
%   Prolog, or — in a partial export — left out with the clauses that the
%   export could not write (missing(Line) or left_out(F/N)).
missing_message(CF, Ls, M) :-
    findall(L, member(missing(L), Ls), Ms), findall(PI, member(left_out(PI), Ls), Os),
    (   Ms \== []
    ->  atomic_list_concat(Ms, '; ', ML),
        format(string(M), "the program leaves predicates to Prolog (its companion file), which has no Daml: write them in Daml in ~w, beside the program: ~w", [CF, ML])
    ;   maplist(predicate_words, Os, OWs), atomic_list_concat(OWs, ', ', OL),
        format(string(M), "it uses ~w, whose rules the partial export left out", [OL])
    ).

predicate_words(F/N, W) :-
    (   nb_current(daml_template_texts, Ts), memberchk(F/N-T, Ts) -> format(atom(W), '"~w"', [T])
    ;   format(atom(W), '~w/~w', [F, N])
    ).

sort_by_functor(As, Set) :-
    findall(F/N-A, ( member(A, As), functor(A, F, N) ), Ps), sort(1, @<, Ps, S), pairs_values(S, Set).

		 /*******************************
		 *             TYPES            *
		 *******************************/

%   Types: [slot(F, N, I)-Type]. A place's class is the set of places a
%   law or constraint makes it share a variable with (union-find by
%   iteration); the class is a Party when it holds an acting party (an
%   action's first place), a Decimal when it holds numbers, else Text.
types(Terms, Fls, Acts, Types) :-
    findall(S, ( member(X, Fls), slots(X, S) ), S1),
    findall(S, ( member(X, Acts), slots(X, S) ), S2),
    %  the places of the rules' predicates too (a rule's date is a fluent's)
    findall(S, ( member(T, Terms), ( rule_term(T) ; fact_term(T) ), sub_term(X, T), pred_goal(X), slots(X, S) ), S3),
    append([S1, S2, S3], Slots0), list_to_set(Slots0, Slots),
    findall(A-B, ( member(T, Terms), rule_term(T), shared_slots(T, A, B) ), Edges),
    classes(Slots, Edges, Classes),
    findall(C-Ty, ( member(C, Classes), class_type(C, Terms, Acts, Ty) ), CTs0),
    %  a list's elements are parties when one of them is a party elsewhere
    findall(P, ( member(C-'Party', CTs0), member(slot(F, N, I), C), value_at(Terms, F, N, I, P), atomic(P) ), Ps),
    findall(S-Ty, ( member(C-Ty0, CTs0), list_type(Ty0, C, Terms, Ps, CTs0, Ty), member(S, C) ), Types).

%   A list's elements: parties when one is a party elsewhere, or when a law
%   takes a member of it to a party's place (`a recipient is in the list`).
list_type(list, C, Terms, Ps, CTs, Ty) :- !,
    (   list_element(C, Terms, X), memberchk(X, Ps) -> Ty = '[Party]'
    ;   member(slot(F, N, I), C), slot_field(F, N, I, Nm), party_list_name(Nm) -> Ty = '[Party]'
    ;   list_element(C, Terms, X), number(X) -> Ty = '[Decimal]'
    ;   member(S, C), member_slots(Terms, S, ES), member(C2-ETy, CTs), memberchk(ES, C2), ETy \== list -> format(atom(Ty), '[~w]', [ETy])
    ;   Ty = '[Text]'
    ).
list_type(Ty, _, _, _, _, Ty).

%   A place its template calls a list of parties: `*a party list*`,
%   `*an observers party list*` (a Daml twin's `[Party]` field), `*parties*`,
%   `*a list of parties*`.
party_list_name(Nm) :-
    downcase_atom(Nm, L0), atom_codes(L0, Cs0),
    reverse(Cs0, R0), exclude_digits(R0, R), reverse(R, Cs), atom_codes(L, Cs),   % (observersPartyList2)
    (   sub_atom(L, _, _, 0, partylist) ; sub_atom(L, _, _, 0, parties) ), !.

exclude_digits([C|Cs], R) :- code_type(C, digit), !, exclude_digits(Cs, R).
exclude_digits(Cs, Cs).

%   member(X, L) in a law, L at place S, X at place ES.
member_slots(Terms, S, ES) :-
    member(T0, Terms), rule_term(T0), copy_term(T0, T), numbervars(T, 0, _),
    sub_term(M, T), compound(M), M = member(X, L), L = '$VAR'(_),
    sub_term(G0, T), compound(G0), literal_of(G0, G), functor(G, F, N), arg(I, G, V), V == L, S = slot(F, N, I),
    (   Y = X
    ;   sub_term(Cmp, T), compound(Cmp), Cmp =.. [Op, A, B], memberchk(Op, [=, \=, ==]),
        ( A == X -> Y = B ; B == X -> Y = A )
    ),
    sub_term(G1, T), compound(G1), literal_of(G1, H), functor(H, F1, N1), arg(I1, H, W), W == Y, ES = slot(F1, N1, I1).

list_element(C, Terms, X) :- member(slot(F, N, I), C), value_at(Terms, F, N, I, L), is_list(L), member(X, L).

slots(X, slot(F, N, I)) :- functor(X, F, N), between(1, N, I).

rule_term(T) :- functor(T, F, _), memberchk(F, [initiated, terminated, updated, d_pre, l_int, l_timeless, reactive_rule]), !.
%   (a rule with no conditions: `a date adjusted by NotAdjusted is the date`)
rule_term(T) :- compound(T), \+ ground(T), functor(T, F, N), \+ lps_term(F/N).

%   A statement of the program that is a fact: ground, and not LPS's own.
fact_term(T) :- compound(T), ground(T), functor(T, F, N), \+ lps_term(F/N).

%   A goal with places that is a predicate's (not LPS's own, an operator, a
%   list or a value).
pred_goal(X) :-
    compound(X), X \= [_|_], functor(X, F, N),
    \+ memberchk(F/N, [holds/2, happens/3, not/1, findall/3, length/2, member/2, date/3, round/1, '$tuple'/1]),
    \+ memberchk(F, [is, =, \=, <, >, =<, >=, =:=, =\=, ==, \==, +, -, *, /, //, mod, (','), (;), (->)]),
    \+ lps_term(F/N).

%   Two places holding the same variable in one law, or variables a
%   comparison relates (`the party is different from the issuer`).
shared_slots(T0, A, B) :-
    %  (the variables numbered: findall copies each solution apart)
    copy_term(T0, T), numbervars(T, 0, _),
    findall(I1, ( sub_term(L, T), compound(L),
                  (   literal_of(L, G), functor(G, F, N), arg(I, G, V), V = '$VAR'(_), I1 = v(V, slot(F, N, I))
                  ;   L =.. [Op, X, Y], memberchk(Op, [=, \=, <, >, =<, >=]), X = '$VAR'(_), Y = '$VAR'(_), I1 = c(X, Y)
                  ) ), Items),
    (   member(v(V1, A), Items), member(v(V1, B), Items)
    ;   member(c(X1, Y1), Items), member(v(X1, A), Items), member(v(Y1, B), Items)
    ),
    A \== B.

%   The literal of a term, when it has places. A fluent of no places (`the
%   token is paused`, which LPS reads as the atom `paused`) has none, so it
%   is not one here: every caller of literal_of/2 is looking for a place —
%   a slot(Functor, Arity, Index) — and an atom has no argument to look at.
literal_of(happens(E, _, _), E) :- compound(E), E \= '$VAR'(_).
literal_of(holds(F, _), F) :- compound(F), F \= not(_), F \= '$VAR'(_).
literal_of(holds(not(F), _), F) :- compound(F), F \= [_|_].
literal_of(initiated(_, F, _), F) :- compound(F).
literal_of(terminated(_, F, _), F) :- compound(F).
literal_of(updated(_, F, _, _), F) :- compound(F).
literal_of(G, G) :- pred_goal(G).

classes(Slots, Edges, Classes) :-
    maplist([S, [S]]>>true, Slots, C0),
    foldl(merge_edge, Edges, C0, Classes).

merge_edge(A-B, Cs0, Cs) :-
    ( select(CA, Cs0, R1), memberchk(A, CA) -> true ; CA = [A], R1 = Cs0 ),
    (   memberchk(B, CA) -> Cs = Cs0
    ;   ( select(CB, R1, R2), memberchk(B, CB) -> true ; CB = [B], R2 = R1 ),
        append(CA, CB, C), Cs = [C|R2]
    ).

class_type(C, Terms, Acts, Ty) :-
    (   member(slot(F, N, 1), C), member(A, Acts), functor(A, F, N),
        %  (not when the program states facts about it: `the reset date of
        %  term1 is ...` makes term1 a thing the rules know, not a party)
        \+ ( member(slot(F1, N1, _), C), member(T, Terms), fact_term(T), functor(T, F1, N1) ),
        %  (nor when it holds a number or a date: a rate the source publishes)
        \+ ( member(slot(F2, N2, I2), C), value_at(Terms, F2, N2, I2, V2), ( number(V2) ; V2 = date(_, _, _) ) )
    ->  (   member(slot(F1, N1, I1), C), value_at(Terms, F1, N1, I1, V), is_list(V)
        ->  format(string(W), "a place that holds a party and elsewhere a list (~w ~w): Daml's types differ", [F1, V]),
            (   nth0(K, Terms, T1), sub_term(X1, T1), compound(X1), functor(X1, F1, N1), arg(I1, X1, V1), V1 == V
            ->  daml_where(K) ; true
            ),
            throw(daml_refuse(W))
        ;   Ty = 'Party'
        )
    ;   member(slot(F, N, I), C), value_at(Terms, F, N, I, V), is_list(V) -> Ty = list
    ;   member(S, C), member_slots(Terms, S, _) -> Ty = list
    ;   member(slot(F, N, I), C), value_at(Terms, F, N, I, V), V = date(_, _, _) -> Ty = 'Date'
    ;   member(slot(F, N, I), C), value_at(Terms, F, N, I, V), number(V) -> Ty = 'Decimal'
    ;   member(S, C), numeric_slot(Terms, S) -> Ty = 'Decimal'
    %  (a place no statement gives a value, which its template calls a date)
    ;   \+ ( member(slot(F, N, I), C), value_at(Terms, F, N, I, _) ),
        member(slot(F, N, I), C), slot_field(F, N, I, Nm), ( Nm == date ; sub_atom(Nm, _, 4, 0, 'Date') ) -> Ty = 'Date'
    ;   Ty = 'Text'
    ).

%   A place a law or constraint compares with a number, or computes with.
numeric_slot(Terms, slot(F, N, I)) :-
    member(T0, Terms), rule_term(T0),
    copy_term(T0, T), numbervars(T, 0, _),
    sub_term(L, T), compound(L), literal_of(L, G), functor(G, F, N), arg(I, G, V), V = '$VAR'(_),
    sub_term(C, T), compound(C), C =.. [Op, X, Y], memberchk(Op, [<, >, =<, >=, is, =:=, +, -, *, /]),
    (   ( X == V ; Y == V ), ( number(X) ; number(Y) ; Op == is ; memberchk(Op, [+, -, *, /]) )
    ;   Op == is, sub_term(W, Y), W == V
    ), !.

value_at(Terms, F, N, I, V) :-
    (   member(initial_state(Fs), Terms), member(X, Fs)
    ;   member(observe(Es, _), Terms), member(X, Es)
    ;   member(T, Terms), rule_term(T), sub_term(X, T), compound(X)
    ;   member(X, Terms), fact_term(X)
    ),
    functor(X, F, N), arg(I, X, V), nonvar(V).

type_of(F, N, I, Ty) :- b_getval(daml_types, Ts), ( memberchk(slot(F, N, I)-Ty, Ts) -> true ; Ty = 'Text' ).

%   The parties a law or constraint names (`the balance of the treasury`):
%   Daml has no party literals, so each is a field of State, allocated by
%   the script, and a law's `the treasury` is that field.
law_parties(Terms, Types, Ps) :-
    findall(P, ( member(T, Terms), rule_term(T), sub_term(X, T), compound(X), functor(X, F, N), N > 0,
                 \+ memberchk(F, [happens, holds, initiated, terminated, updated, d_pre]),
                 between(1, N, I), memberchk(slot(F, N, I)-'Party', Types), arg(I, X, P), atom(P) ), Ps0),
    sort(Ps0, Ps).

parties(Types, Init, Obs, Parties) :-
    findall(P, ( ( member(X, Init) ; member(X-_, Obs) ), functor(X, F, N), between(1, N, I),
                 (   memberchk(slot(F, N, I)-'Party', Types), arg(I, X, P)
                 ;   memberchk(slot(F, N, I)-'[Party]', Types), arg(I, X, L), is_list(L), member(P, L)
                 ) ), Ps),
    sort(Ps, Parties).

		 /*******************************
		 *         DECLARATIONS         *
		 *******************************/

rec_name(F, R) :- atomic_list_concat(Ws0, '_', F), exclude(==(''), Ws0, Ws), maplist(cap, Ws, Cs), atomic_list_concat(Cs, R).
cap(W, C) :- sub_atom(W, 0, 1, _, X), sub_atom(W, 1, _, 0, Rest), upcase_atom(X, U), atom_concat(U, Rest, C).
field_name(F, Fd) :- rec_name(F, R), sub_atom(R, 0, 1, _, X), sub_atom(R, 1, _, 0, Rest), downcase_atom(X, L),
    atom_concat(L, Rest, Fd0), ( reserved(Fd0) -> atom_concat(Fd0, 'Facts', Fd) ; Fd = Fd0 ).
%   (a choice declares a type of its name: none may be a record's)
choice_name(A, C) :- rec_name(A, C0),
    ( ( reserved_choice(C0) ; nb_current(daml_records, Rs), memberchk(C0, Rs) ) -> atom_concat(C0, 'Action', C) ; C = C0 ).

reserved(W) :- memberchk(W, [operator, parties, this, self, arg, type, data, template, choice, controller, signatory, observer, ensure,
                             agreement, key, maintainer, interface, implements, viewtype, exercise, create, archive, fetch,
                             module, import, case, of, if, then, else, let, in, do, with, where, class, instance, deriving]).
reserved_choice(W) :- memberchk(W, ['Archive', 'State']).

%   data Balance = Balance with owner : Party; amount : Decimal deriving (Eq, Show, Ord)
record_decl(F0) :-
    functor(F0, F, N),
    (   N =:= 0 -> true
    ;   rec_name(F, R),
        format("data ~w = ~w with~n", [R, R]),
        forall(between(1, N, I), ( type_of(F, N, I, Ty), slot_field(F, N, I, Nm), format("    ~w : ~w~n", [Nm, Ty]) )),
        format("  deriving (Eq, Show, Ord)~n~n")
    ).

state_template(Terms, Fls, Acts, LawPs) :-
    format("template State~n  with~n    operator : Party~n    parties : [Party]~n"),
    forall(member(P, LawPs), ( party_var(P, V), format("    ~w : Party~n", [V]) )),
    forall(member(F0, Fls), ( functor(F0, F, N), field_name(F, Fd), ( N =:= 0 -> format("    ~w : Bool~n", [Fd]) ; rec_name(F, R), format("    ~w : [~w]~n", [Fd, R]) ) )),
    format("  where~n    signatory operator~n    observer parties~n"),
    forall(member(A, Acts), choice(Terms, Fls, A)),
    cycle_choice(Terms),
    daml_where(none),
    nl.

		 /*******************************
		 *            CHOICES           *
		 *******************************/

%   A choice: its constraints, then the update in LPS's reading.
choice(Terms, Fls, A0) :-
    functor(A0, AF, AN), choice_name(AF, CN),
    format("~n    choice ~w : ContractId State~n", [CN]),
    ( AN > 0 -> format("      with~n"), forall(between(1, AN, I), ( type_of(AF, AN, I, Ty), choice_arg(AF, AN, I, Nm), format("        ~w : ~w~n", [Nm, Ty]) )) ; true ),
    ( AN > 0, type_of(AF, AN, 1, 'Party') -> choice_arg(AF, AN, 1, Ctrl) ; Ctrl = operator ),
    format("      controller ~w~n      do~n", [Ctrl]),
    functor(A, AF, AN),
    %  the action's constraints, on the state before
    forall(( nth1(K, Terms, d_pre(Cs0)), select(happens(E, _, _), Cs0, Cs), functor(E, AF, AN) ),
           ( K0 is K - 1, daml_where(K0),
             copy_term(E-Cs, A1-Cs1), choice_env(A1, Env1, Guard),
             exists(Cs1, Env1, this, Code0), conj([Guard, Code0], Code),
             format(string(Msg), "refused: the program's constraint ~w on ~w", [K, CN]),
             source_comment([K0], "        "),
             format("        assertMsg ~q (not (~w))~n", [Msg, Code]) )),
    %  the update: each fluent's terminations and initiations
    forall(member(F0, Fls), fluent_update(Terms, A, AF/AN, F0)),
    findall(Fd, ( member(F0, Fls), functor(F0, F, _), field_name(F, Fd) ), Fds),
    findall(S, ( member(Fd, Fds), format(atom(S), '~w = ~wNew', [Fd, Fd]) ), Ss),
    atomic_list_concat(Ss, '; ', SL),
    ( Ss == [] -> format("        let next = this~n") ; format("        let next = this with ~w~n", [SL]) ),
    %  the constraints on states (no action)
    forall(( nth1(K, Terms, d_pre(Cs0)), \+ memberchk(happens(_, _, _), Cs0) ),
           ( K0 is K - 1, daml_where(K0),
             copy_term(Cs0, Cs1), exists(Cs1, [], next, Code),
             format(string(Msg), "refused: the program's constraint ~w on the state", [K]),
             source_comment([K0], "        "),
             format("        assertMsg ~q (not (~w))~n", [Msg, Code]) )),
    daml_where(none),
    format("        create next~n").

%   The new value of a fluent after the action: the records it ends
%   removed, the records it starts added (both computed on the state before).
fluent_update(Terms, A, AF/AN, F0) :-
    functor(F0, F, N), field_name(F, Fd),
    findall(K-Law, ( nth0(K, Terms, Law), law_fluent(Law, AF/AN, F/N) ), KLaws),
    pairs_keys_values(KLaws, Ks, Laws),
    A =.. [_|ArgVs0], length(ArgVs0, AN),
    source_comment(Ks, "        "),
    (   N =:= 0
    ->  ( member(K-L, KLaws), L \= initiated(_, _, []), L \= terminated(_, _, []) -> daml_where(K) ; true ),
        zero_update(Laws, Fd)
    ;   findall(P, ( member(K-L, KLaws), daml_where(K), removal(L, Fd, P) ), Ps),
        findall(X, ( member(K-L, KLaws), daml_where(K), addition(L, X) ), Xs),
        daml_where(none),
        (   Ps == [] -> Kept = Fd
        ;   atomic_list_concat(Ps, ' || ', PC), format(atom(Kept), 'filter (\\r -> not (~w)) ~w', [PC, Fd])
        ),
        (   Xs == [] -> Added = '[]' ; atomic_list_concat(Xs, ' ++ ', Added) ),
        (   Ps == [], Xs == [] -> format("        let ~wNew = ~w~n", [Fd, Fd])
        ;   format("        let ~wNew = dedup (~w ++ ~w)~n", [Fd, Kept, Added])
        )
    ).

law_fluent(initiated(happens(E, _, _), Fl, _), AF/AN, F/N) :- functor(E, AF, AN), functor(Fl, F, N).
law_fluent(terminated(happens(E, _, _), Fl, _), AF/AN, F/N) :- functor(E, AF, AN), functor(Fl, F, N).
law_fluent(updated(happens(E, _, _), Fl, _, _), AF/AN, F/N) :- functor(E, AF, AN), functor(Fl, F, N).

%   Is record r one the law ends? `\r -> r.a1 == a2 && <conditions>`
removal(Law0, _Fd, P) :-
    copy_term(Law0, Law),
    ( Law = terminated(happens(E, _, _), Fl, Cs) ; Law = updated(happens(E, _, _), Fl, _, Cs) ), !,
    choice_env(E, Env0, Guard),
    match_record(Fl, r, Env0, Env1, Bind, Eqs),
    exists_(Cs, Env1, this, CC),
    conj([Guard, Eqs, CC], Body),
    wrap_let(Bind, Body, P).

%   The records the law starts: a list, one per way its conditions hold.
addition(Law0, X) :-
    copy_term(Law0, Law),
    (   Law = initiated(happens(E, _, _), Fl, Cs) -> Cs1 = Cs, New = Fl
    ;   Law = updated(happens(E, _, _), Fl, Old-NewV, Cs),
        before_use(Cs, Old, holds(Fl, _), Cs1), Fl =.. [F|FA], replace_var(FA, Old, NewV, FA1), New =.. [F|FA1]
    ), !,
    choice_env(E, Env0, Guard),
    gen_list(Cs1, Env0, this, New, X0),
    ( Guard == 'True' -> X = X0 ; format(atom(X), '(if ~w then ~w else [])', [Guard, X0]) ).

%   The old value read just before a condition first uses it (the
%   conditions before may bind the fluent's other places).
before_use([], _, H, [H]).
before_use([C|Cs], V, H, Out) :-
    (   term_variables(C, Vs), member(V1, Vs), V1 == V -> Out = [H, C|Cs]
    ;   Out = [C|Out1], before_use(Cs, V, H, Out1)
    ).

replace_var([X|Xs], Old, New, [New|Xs]) :- X == Old, !.
replace_var([X|Xs], Old, New, [X|Ys]) :- replace_var(Xs, Old, New, Ys).

%   The law's action against the choice's arguments a1, a2, ...: its
%   variables named by them; a constant, or a variable met twice, a guard
%   (`a2 == "x"`, `a3 == a1`).
choice_env(E, Env, Guard) :-
    E =.. [AF|Args], length(Args, AN),
    foldl(arg_env(AF/AN), Args, 1-[]-[], _-Env-Gs0),
    reverse(Gs0, Gs), conj(Gs, Guard).

arg_env(AF/AN, V, I-E0-G0, I1-E-G) :-
    I1 is I + 1, choice_arg(AF, AN, I, Nm),
    (   var(V), lookup(V, E0, Nm0) -> E = E0, format(atom(C), '~w == ~w', [Nm, Nm0]), G = [C|G0]
    ;   var(V) -> E = [V-Nm|E0], G = G0
    ;   literal(V, L), E = E0, format(atom(C), '~w == ~w', [Nm, L]), G = [C|G0]
    ).

zero_update(Laws, Fd) :-
    (   member(initiated(_, _, []), Laws) -> format("        let ~wNew = True~n", [Fd])
    ;   member(terminated(_, _, []), Laws) -> format("        let ~wNew = False~n", [Fd])
    ;   Laws == [] -> format("        let ~wNew = ~w~n", [Fd, Fd])
    ;   throw(daml_refuse("a law with conditions on a fluent with no places: not translated"))
    ).

		 /*******************************
		 *          CONDITIONS          *
		 *******************************/

%   exists(+Conds, +Env, +State, -Code): some binding satisfies the
%   conditions, as a Daml boolean.
exists(Cs, Env, St, Code) :- exists_(Cs, Env, St, Code).

exists_([], _, _, 'True').
exists_([C|Cs], Env, St, Code) :- cond(C, Cs, Env, St, Code).

cond(holds(not(L), _), Cs, Env, St, Code) :- is_list(L), !,
    exists_(L, Env, St, In), exists_(Cs, Env, St, Rest),
    format(atom(Code), '(not (~w) && ~w)', [In, Rest]).
cond(holds(not(F), _), Cs, Env, St, Code) :- !,
    exists_([holds(F, _)], Env, St, In), exists_(Cs, Env, St, Rest),
    format(atom(Code), '(not (~w) && ~w)', [In, Rest]).
cond(C, Cs, Env, St, Code) :- binder(C, Env, St, B), !, bind_exists(B, Cs, St, Code).
cond(holds(F, _), Cs, Env, St, Code) :- !,
    functor(F, Fn, N), field_name(Fn, Fd),
    (   N =:= 0 -> exists_(Cs, Env, St, Rest), format(atom(Code), '(~w.~w && ~w)', [St, Fd, Rest])
    ;   fresh_r(R), match_record(F, R, Env, Env1, Bind, Eqs),
        exists_(Cs, Env1, St, Rest0), conj([Eqs, Rest0], Body), wrap_let(Bind, Body, In),
        format(atom(Code), 'any (\\~w -> ~w) ~w.~w', [R, In, St, Fd])
    ).
cond(not(G), Cs, Env, St, Code) :- !, exists_([G], Env, St, In), exists_(Cs, Env, St, Rest),
    format(atom(Code), '(not (~w) && ~w)', [In, Rest]).
cond(C, Cs, Env, St, Code) :-
    comparison(C, Env, CC), !, exists_(Cs, Env, St, Rest),
    format(atom(Code), '(~w && ~w)', [CC, Rest]).
cond(C, _, _, _, _) :- format(string(W), "a condition not translated to Daml: ~q", [C]), throw(daml_refuse(W)).

comparison(C, Env, Code) :-
    C =.. [Op, X, Y], memberchk(Op-DOp, [(<)-(<), (>)-(>), (=<)-(<=), (>=)-(>=), (=)-(==), (\=)-(/=), (is)-(==), (=:=)-(==)]),
    expr(X, Env, XC), expr(Y, Env, YC), format(atom(Code), '(~w ~w ~w)', [XC, DOp, YC]).

%   gen_list(+Conds, +Env, +State, +Template, -Code): the list of the
%   template's values (a record, or val(Expr)), one per binding.
gen_list([], Env, _, val(E), Code) :- !, expr(E, Env, C), format(atom(Code), '[~w]', [C]).
gen_list([], Env, _, Tpl, Code) :- !, record_expr(Tpl, Env, RC), format(atom(Code), '[~w]', [RC]).
gen_list([C|Cs], Env, St, Tpl, Code) :- C \= holds(not(_), _), binder(C, Env, St, B), !, bind_gen(B, Cs, St, Tpl, Code).
gen_list([holds(F, _)|Cs], Env, St, Tpl, Code) :- F \= not(_), !,
    functor(F, Fn, N), field_name(Fn, Fd),
    (   N =:= 0 -> gen_list(Cs, Env, St, Tpl, Rest), format(atom(Code), '(if ~w.~w then ~w else [])', [St, Fd, Rest])
    ;   fresh_r(R), match_record(F, R, Env, Env1, Bind, Eqs),
        gen_list(Cs, Env1, St, Tpl, Rest), format(atom(If), '(if ~w then ~w else [])', [Eqs, Rest]),
        wrap_let(Bind, If, In),
        format(atom(Code), 'concatMap (\\~w -> ~w) ~w.~w', [R, In, St, Fd])
    ).
gen_list([C|Cs], Env, St, Tpl, Code) :-
    exists_([C], Env, St, CC), gen_list(Cs, Env, St, Tpl, Rest),
    format(atom(Code), '(if ~w then ~w else [])', [CC, Rest]).

%   binder(+Cond, +Env, +State, -Binding): a condition that binds (or
%   tests) without ranging over a fluent's records:
%     let(Name, Code, Env1)   one value           (is, =, findall, length, a
%                                                  fluent's value or its default)
%     iter(Name, List, Env1)  each element        (member of a list)
%     test(Code, Env)         a test
%     alts([Env1-Guard])      one way per fact    (a predicate the program states as facts)
binder(G, Env, St, B) :- rule_call(G, Env, St, B), !.
binder(holds(G, _), Env, St, B) :- nonvar(G), G = findall(_, _, _), !, binder(G, Env, St, B).
binder(holds(F, _), Env, St, B) :- compound(F), default_lookup(F, Env, St, LCode, Last), !,
    (   var(Last), \+ bound(Last, Env) -> fresh_v(Nm), B = let(Nm, LCode, [Last-Nm|Env])
    ;   expr(Last, Env, LC), format(atom(T), '(~w == ~w)', [LCode, LC]), B = test(T, Env)
    ).
binder(is(V, E), Env, _, let(Nm, EC, [V-Nm|Env])) :- var(V), \+ bound(V, Env), !, expr(E, Env, EC), fresh_v(Nm).
binder(X = Y, Env, St, B) :- var(X), \+ bound(X, Env), !, binder(is(X, Y), Env, St, B).
binder(X = Y, Env, St, B) :- var(Y), \+ bound(Y, Env), !, binder(is(Y, X), Env, St, B).
binder(member(X, L), Env, _, B) :- !, expr(L, Env, LC),
    (   var(X), \+ bound(X, Env) -> fresh_v(Nm), B = iter(Nm, LC, [X-Nm|Env])
    ;   expr(X, Env, XC), format(atom(T), '(elem ~w ~w)', [XC, LC]), B = test(T, Env)
    ).
binder(findall(X, Gs0, L), Env, St, let(Nm, LC, [L-Nm|Env])) :- var(L), \+ bound(L, Env), !,
    goals(Gs0, Gs), gen_list(Gs, Env, St, val(X), LC), fresh_v(Nm).
binder(length(L, N), Env, _, B) :- !, expr(L, Env, LC), format(atom(Len), '(intToDecimal (length ~w))', [LC]),
    (   var(N), \+ bound(N, Env) -> fresh_v(Nm), B = let(Nm, Len, [N-Nm|Env])
    ;   expr(N, Env, NC), format(atom(T), '(~w == ~w)', [Len, NC]), B = test(T, Env)
    ).
binder(G, Env, _, alts(As)) :- compound(G), functor(G, F, N), fact_predicate(F/N), !,
    %  (no findall: the environment's variables must stay the conditions')
    findall(Fact, fact(F/N, Fact), Facts), maplist(fact_alt(G, Env), Facts, As).

fact_alt(G, Env, Fact, Env1-Guard) :- fact_match(G, Fact, Env, Env1, Guard).

goals(Gs, Gs) :- is_list(Gs), !.
goals((A, B), [A|Gs]) :- !, goals(B, Gs).
goals(G, [G]).

bind_exists(let(Nm, V, E1), Cs, St, Code) :- exists_(Cs, E1, St, R), format(atom(Code), '(let ~w = ~w in ~w)', [Nm, V, R]).
bind_exists(iter(Nm, L, E1), Cs, St, Code) :- exists_(Cs, E1, St, R), format(atom(Code), 'any (\\~w -> ~w) ~w', [Nm, R, L]).
bind_exists(test(T, E), Cs, St, Code) :- exists_(Cs, E, St, R), format(atom(Code), '(~w && ~w)', [T, R]).
bind_exists(alts(As), Cs, St, Code) :-
    maplist(alt_exists(Cs, St), As, Ds),
    ( Ds == [] -> Code = 'False' ; atomic_list_concat(Ds, ' || ', D), format(atom(Code), '(~w)', [D]) ).

bind_gen(let(Nm, V, E1), Cs, St, Tpl, Code) :- gen_list(Cs, E1, St, Tpl, R), format(atom(Code), '(let ~w = ~w in ~w)', [Nm, V, R]).
bind_gen(iter(Nm, L, E1), Cs, St, Tpl, Code) :- gen_list(Cs, E1, St, Tpl, R), format(atom(Code), 'concatMap (\\~w -> ~w) ~w', [Nm, R, L]).
bind_gen(test(T, E), Cs, St, Tpl, Code) :- gen_list(Cs, E, St, Tpl, R), format(atom(Code), '(if ~w then ~w else [])', [T, R]).
bind_gen(alts(As), Cs, St, Tpl, Code) :-
    maplist(alt_gen(Cs, St, Tpl), As, Ds),
    ( Ds == [] -> Code = '[]' ; atomic_list_concat(Ds, ' ++ ', D), format(atom(Code), '(~w)', [D]) ).

alt_exists(Cs, St, E1-G, C) :- exists_(Cs, E1, St, R), conj([G, R], C0), format(atom(C), '(~w)', [C0]).
alt_gen(Cs, St, Tpl, E1-G, C) :- gen_list(Cs, E1, St, Tpl, R), ( G == 'True' -> C = R ; format(atom(C), '(if ~w then ~w else [])', [G, R]) ).

%   A fluent with a default value (`0 by default`), its places but the
%   last known: the value of its record, else the default.
default_lookup(F, Env, St, Code, Last) :-
    nb_current(daml_defaults, Ds), functor(F, Fn, N), member(D0, Ds), functor(D0, Fn, N), !,
    arg(N, D0, Dflt), literal(Dflt, DC),
    F =.. [_|Args], append(Keys, [Last], Args),
    fresh_r(R), key_eqs(Keys, Fn/N, 1, R, Env, EqsL), conj(EqsL, Eqs),
    field_name(Fn, Fd), slot_field(Fn, N, N, LastNm),
    format(atom(Code), '(firstOr ~w (map (\\~w -> ~w.~w) (filter (\\~w -> ~w) ~w.~w)))', [DC, R, R, LastNm, R, Eqs, St, Fd]).

key_eqs([], _, _, _, _, []).
key_eqs([K|Ks], Fn/N, I, R, Env, [Eq|Eqs]) :-
    ( var(K) -> lookup(K, Env, KC) ; literal(K, KC) ),
    slot_field(Fn, N, I, Nm),
    format(atom(Eq), '~w.~w == ~w', [R, Nm, KC]), I1 is I + 1, key_eqs(Ks, Fn/N, I1, R, Env, Eqs).

%   The program's facts: its ground statements that are not LPS's own.
fact_predicate(F/N) :- fact(F/N, _), !.
fact(F/N, Fact) :- nb_current(daml_facts, Fs), member(Fact, Fs), functor(Fact, F, N).

facts(Terms, Facts) :-
    findall(T, ( member(T, Terms), compound(T), ground(T), functor(T, F, N), \+ lps_term(F/N) ), Facts).

lps_term(F/_) :- memberchk(F, [maxTime, fluents, actions, events, defaults, initial_state, observe, initiated, terminated,
                                updated, d_pre, reactive_rule, l_int, l_events, l_timeless, (:-), prolog_events, false]).

fact_match(G, Fact, Env0, Env, Guard) :-
    G =.. [_|As], Fact =.. [_|Vs],
    foldl(fact_arg, As, Vs, Env0-[], Env-Gs), reverse(Gs, Gs1), conj(Gs1, Guard).

fact_arg(A, V, E0-G0, E-G) :-
    literal(V, VC),
    (   var(A), \+ bound(A, E0) -> E = [A-VC|E0], G = G0
    ;   var(A) -> lookup(A, E0, AC), format(atom(C), '~w == ~w', [AC, VC]), E = E0, G = [C|G0]
    ;   A == V -> E = E0, G = G0
    ;   E = E0, G = ['False'|G0]
    ).

%   A record pattern against r: bindings for its unbound variables (let),
%   equalities for its bound ones and its constants.
match_record(F, R, Env0, Env, Bind, Eqs) :-
    F =.. [Fn|Args], length(Args, N),
    foldl(match_arg(R, Fn, N), Args, 1-Env0-[]-[], _-Env-Bind0-Eqs0),
    reverse(Bind0, Bind), reverse(Eqs0, EqsL),
    ( EqsL == [] -> Eqs = 'True' ; atomic_list_concat(EqsL, ' && ', Eqs) ).

match_arg(R, Fn, N, A, I-E0-B0-Q0, I1-E-B-Q) :-
    I1 is I + 1,
    slot_field(Fn, N, I, Nm0), format(atom(Acc), '~w.~w', [R, Nm0]),
    (   var(A), lookup(A, E0, Nm) -> E = E0, B = B0, format(atom(Eq), '~w == ~w', [Acc, Nm]), Q = [Eq|Q0]
    ;   var(A) -> fresh_v(Nm), E = [A-Nm|E0], B = [Nm-Acc|B0], Q = Q0
    ;   literal(A, L), E = E0, B = B0, format(atom(Eq), '~w == ~w', [Acc, L]), Q = [Eq|Q0]
    ).

wrap_let([], Body, Body) :- !.
wrap_let(Bind, Body, Code) :-
    findall(S, ( member(N-A, Bind), format(atom(S), '~w = ~w', [N, A]) ), Ss), atomic_list_concat(Ss, '; ', L),
    format(atom(Code), '(let ~w in ~w)', [L, Body]).

conj(Parts0, C) :- exclude(==('True'), Parts0, Parts), ( Parts == [] -> C = 'True' ; atomic_list_concat(Parts, ' && ', C) ).

fresh_r(R) :- ( nb_current(daml_r, K0) -> true ; K0 = 0 ), K is K0 + 1, nb_setval(daml_r, K), format(atom(R), 'r~w', [K]).
fresh_v(V) :- ( nb_current(daml_v, K0) -> true ; K0 = 0 ), K is K0 + 1, nb_setval(daml_v, K), format(atom(V), 'v~w', [K]).

lookup(V, Env, Nm) :- member(V1-Nm, Env), V1 == V, !.
bound(V, Env) :- lookup(V, Env, _).

expr(V, Env, C) :- var(V), !, ( lookup(V, Env, C) -> true ; throw(daml_refuse("a variable a condition uses before it is bound: not translated")) ).
expr(E, Env, C) :- compound(E), E =.. [Op, A, B], memberchk(Op, [+, -, *, /]), !,
    expr(A, Env, AC), expr(B, Env, BC), format(atom(C), '(~w ~w ~w)', [AC, Op, BC]).
expr(round(X), Env, C) :- !, expr(X, Env, XC), format(atom(C), '(roundCommercial 0 ~w)', [XC]).
expr('$tuple'([E]), Env, C) :- !, expr(E, Env, C).
expr('$tuple'(Es), Env, C) :- !, exprs(Es, Env, Cs), atomic_list_concat(Cs, ', ', C0), format(atom(C), '(~w)', [C0]).
expr(E, _, C) :- literal(E, C).

exprs([], _, []).
exprs([E|Es], Env, [C|Cs]) :- expr(E, Env, C), exprs(Es, Env, Cs).

%   A constant as a Daml literal: numbers Decimal, texts Text, lists; a
%   party a law names is State's field of it (Daml has no party literals).
literal(N, C) :- number(N), !, decimal_text(N, T), ( N < 0 -> format(atom(C), '(~w)', [T]) ; C = T ).

literal(date(Y, M, D), C) :- integer(Y), integer(M), integer(D), !,
    nth1(M, ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'], Mn),
    format(atom(C), '(D.date ~w D.~w ~w)', [Y, Mn, D]).
literal(S, C) :- string(S), !, format(atom(C), '~q', [S]).
literal(L, C) :- is_list(L), !, maplist(literal, L, Cs), atomic_list_concat(Cs, ', ', C0), format(atom(C), '[~w]', [C0]).
literal(A, C) :- atom(A), nb_current(daml_law_parties, Ps), memberchk(A, Ps), !, party_var(A, C).
literal(A, C) :- atom(A), !, atom_string(A, S), format(atom(C), '~q', [S]).
literal(T, _) :- format(string(W), "a term with no Daml literal: ~q", [T]), throw(daml_refuse(W)).

%   A Decimal as Daml writes it: no exponent, at most 10 places.
decimal_text(N, T) :-
    format(atom(A), '~10f', [N]), atom_codes(A, Cs0),
    reverse(Cs0, R0), drop_zeros(R0, R1), reverse(R1, Cs), atom_codes(T, Cs).
drop_zeros([0'0, C|Cs], R) :- C \== 0'., !, drop_zeros([C|Cs], R).
drop_zeros(Cs, Cs).

record_expr(F, Env, C) :-
    F =.. [Fn|Args], rec_name(Fn, R),
    (   Args == [] -> C = R
    ;   length(Args, N), findall(S, ( nth1(I, Args, A), expr(A, Env, AC), slot_field(Fn, N, I, Nm), format(atom(S), '~w = ~w', [Nm, AC]) ), Ss),
        atomic_list_concat(Ss, '; ', L), format(atom(C), '~w with ~w', [R, L])
    ).

		 /*******************************
		 *            THE SCRIPT        *
		 *******************************/

%   The scenario: parties, the initial State, each observed action
%   submitted with trySubmit (a refused one keeps the state), the final
%   State returned.
script(Terms, Fls, _Acts, Init, Obs, Parties, LawPs) :-
    format("~nscenario : Script (Optional State)~nscenario = script do~n"),
    format("  operator <- allocatePartyByHint (PartyIdHint \"Operator\")~n"),
    forall(member(P, Parties), ( party_var(P, V), party_hint(P, H), format("  ~w <- allocatePartyByHint (PartyIdHint ~q)~n", [V, H]) )),
    findall(V, ( member(P, Parties), party_var(P, V) ), Vs), atomic_list_concat(Vs, ', ', PL),
    findall(K, nth0(K, Terms, initial_state(_)), IKs),
    ( IKs = [IK|_] -> daml_where(IK) ; true ),
    source_comment(IKs, "  "),
    format("  s0 <- submit operator do~n    createCmd State with~n      operator = operator~n      parties = [~w]~n", [PL]),
    forall(member(P, LawPs), ( party_var(P, V), format("      ~w = ~w~n", [V, V]) )),
    forall(member(F0, Fls), init_field(F0, Init)),
    daml_where(none),
    (   cycle_rules(Terms, [_|_])
    ->  %  LPS's cycles: on the state at each time, the actions the reactive
        %  rules call for (ReactiveCycle), then the events observed up to the
        %  next time
        ( memberchk(maxTime(Max), Terms) -> true ; Max = 20 ),
        M1 is Max - 1,
        include([_-T]>>(T =< 1), Obs, Obs0), foldl(obs_step, Obs0, 0, K0),
        numfold(cycle_step(Obs), 1, M1, K0, K)
    ;   foldl(obs_step, Obs, 0, K)
    ),
    format("  queryContractId operator s~w~n", [K]).

cycle_step(Obs, T, K0, K) :-
    K1 is K0 + 1,
    format("  -- cycle ~w~n  r~w <- trySubmit operator (exerciseCmd s~w ReactiveCycle)~n  let s~w = either (const s~w) identity r~w~n",
           [T, K1, K0, K1, K0, K1]),
    T1 is T + 1, findall(E-Te, ( member(E-Te, Obs), Te =:= T1 ), ObsT),
    foldl(obs_step, ObsT, K1, K).

%   numfold(G, L, H, V0, V): G called on L..H in turn, threading V.
numfold(_, L, H, V0, V) :- L > H, !, V = V0.
numfold(G, L, H, V0, V) :- call(G, L, V0, V1), L1 is L + 1, numfold(G, L1, H, V1, V).

init_field(F0, Init) :-
    functor(F0, F, N), field_name(F, Fd),
    (   N =:= 0 -> ( member(X, Init), functor(X, F, 0) -> V = 'True' ; V = 'False' ), format("      ~w = ~w~n", [Fd, V])
    ;   findall(C, ( member(X, Init), functor(X, F, N), script_record(X, C) ), Cs),
        atomic_list_concat(Cs, ', ', L), format("      ~w = [~w]~n", [Fd, L])
    ).

obs_step(E-T, K0, K) :-
    K is K0 + 1,
    E =.. [AF|Args], length(Args, N), choice_name(AF, CN),
    (   N > 0, type_of(AF, N, 1, 'Party') -> Args = [P|_], party_var(P, Sub) ; Sub = operator ),
    findall(S, ( nth1(I, Args, A), script_value(AF, N, I, A, V), choice_arg(AF, N, I, Nm), format(atom(S), '~w = ~w', [Nm, V]) ), Ss),
    ( Ss == [] -> W = '' ; atomic_list_concat(Ss, '; ', SL), format(atom(W), ' with ~w', [SL]) ),
    format("  -- observed at ~w~n  r~w <- trySubmit ~w (exerciseCmd s~w ~w~w)~n  let s~w = either (const s~w) identity r~w~n",
           [T, K, Sub, K0, CN, W, K, K0, K]).

script_record(X, C) :-
    X =.. [F|Args], length(Args, N), rec_name(F, R),
    findall(S, ( nth1(I, Args, A), script_value(F, N, I, A, V), slot_field(F, N, I, Nm), format(atom(S), '~w = ~w', [Nm, V]) ), Ss),
    atomic_list_concat(Ss, '; ', L), format(atom(C), '~w with ~w', [R, L]).

script_value(F, N, I, A, V) :-
    (   type_of(F, N, I, 'Party') -> party_var(A, V)
    ;   type_of(F, N, I, '[Party]'), is_list(A) -> maplist(party_var, A, Vs), atomic_list_concat(Vs, ', ', V0), format(atom(V), '[~w]', [V0])
    ;   literal(A, V)
    ).

party_var(P, V) :- format(atom(A), '~w', [P]), atom_codes(A, Cs), include([C]>>code_type(C, alnum), Cs, Cs1),
    atom_codes(V0, Cs1), downcase_atom(V0, V1), atom_concat(p_, V1, V).
%   A party's hint: its name's letters and digits (Canton's hints allow no
%   spaces): `acme bank` -> "acmebank".
party_hint(P, H) :- party_key(P, K), atom_string(K, H).
party_key(P, K) :- format(atom(A), '~w', [P]), atom_codes(A, Cs), include([C]>>code_type(C, alnum), Cs, Cs1), atom_codes(K0, Cs1), downcase_atom(K0, K).

		 /*******************************
		 *     RULES AS FUNCTIONS       *
		 *******************************/

/*  Daml has no rules, but it has functions, and a rule asked with some of
    its places known is a function from those to the list of the others:
    `the preceding business day for a trade of a date is a second date`,
    asked with the trade and the date, is

        thePrecedingBusinessDayForOfIs_bbf : State -> Text -> Date -> [Date]

    one function for each pattern of known places a law, a constraint or
    another rule asks it in, each clause of the rule a list of answers (a
    Bool when every place is known). An intensional fluent is the same, a
    function of the State. A predicate the program leaves to Prolog (its
    companion `.lps` file) has no Logical English to translate: a Daml
    companion, `<knowledge base>.daml` beside the program, gives each
    function under the same name, and the export says which are missing.
*/

rules_setup(Terms) :-
    findall(F/N, ( member(l_int(holds(H, _), _), Terms), functor(H, F, N) ), Is0), sort(Is0, Is),
    nb_setval(daml_intensional, Is),
    %  (cl(Kind, F/N, Head, Body, K): K the clause's term, for its line)
    findall(cl(int, F/N, H, B, K), ( nth0(K, Terms, l_int(holds(H, _), B)), functor(H, F, N) ), IntCls),
    %  (a predicate the program states as facts is a function too: the facts
    %  as alternatives in the conditions would copy what follows them once
    %  per fact, and a few such lookups in a row multiply)
    findall(F/N, ( member(T, Terms), ( clause_head(T, H, _) ; fact_term(T), H = T ), functor(H, F, N) ), Ds0), sort(Ds0, Ds),
    nb_setval(daml_defined, Ds),
    findall(cl(timeless, F/N, H, B, K),
            ( nth0(K, Terms, T),
              (   clause_head(T, H, B)
              ;   fact_term(T), functor(T, F0, N0), memberchk(F0/N0, Ds), H = T, B = []
              ),
              functor(H, F, N) ),
            TCls),
    append(IntCls, TCls, Cls), nb_setval(daml_clauses, Cls),
    nb_setval(daml_fun_requests, []), nb_setval(daml_fun_done, []),
    nb_setval(daml_companion_used, []), nb_setval(daml_companion_missing, []), nb_setval(daml_extra_funs, []).

%   A rule of the program: `l_timeless(Head, Body)`, or a statement with a
%   variable and no conditions (`a date shifted by 0 business days is the date`).
clause_head(l_timeless(H, B), H, B).
clause_head(T, T, []) :- compound(T), \+ ground(T), functor(T, F, N), \+ lps_term(F/N).

intensional_fluent(F0) :- functor(F0, F, N), nb_current(daml_intensional, L), memberchk(F/N, L).
defined_predicate(F/N) :- nb_current(daml_defined, L), memberchk(F/N, L).
fun_requested(F/N) :- nb_current(daml_fun_done, L), memberchk(req(_, F/N, _), L).

%   rule_call(+Goal, +Env, +State, -Binding): a goal that asks a rule (an
%   intensional fluent, a timeless rule, or a companion function).
rule_call(G0, Env, St, B) :-
    (   G0 = holds(F, _), nonvar(F), callable(F), F \= not(_), F \= findall(_, _, _), intensional_fluent(F)
    ->  Kind = int, G = F
    ;   G0 \= holds(_, _), pred_goal(G0), functor(G0, F, N), defined_predicate(F/N)
    ->  Kind = timeless, G = G0
    ;   G0 \= holds(_, _), pred_goal(G0), functor(G0, F, N), \+ fact_predicate(F/N)
    ->  Kind = companion, G = G0
    ),
    G =.. [P|Args], length(Args, N1),
    call_mode(Args, Env, Mode, Bound, Free),
    fun_name(P, Mode, Name),
    (   Kind == companion -> companion_function(P/N1, Mode, Name)
    ;   request_function(req(Kind, P/N1, Mode))
    ),
    exprs(Bound, Env, BCs),
    (   Kind == companion -> Ps = BCs ; Ps = [St|BCs] ),
    (   Ps == [] -> Call = Name ; atomic_list_concat([Name|Ps], ' ', C0), format(atom(Call), '(~w)', [C0]) ),
    (   Free == []
    ->  B = test(Call, Env)
    ;   term_variables(Free, FVs), length(FVs, NF), length(Free, NF0),
        (   NF =\= NF0 -> format(string(W), "a call of ~w/~w that asks for one thing in two places: not translated", [P, N1]), throw(daml_refuse(W)) ; true ),
        maplist([V, V-Nm]>>fresh_v(Nm), Free, Pairs), pairs_values(Pairs, Nms),
        ( Nms = [One] -> Pat = One ; atomic_list_concat(Nms, ', ', P0), format(atom(Pat), '(~w)', [P0]) ),
        append(Pairs, Env, Env1),
        B = iter(Pat, Call, Env1)
    ).

%   The pattern of a call: b for a place it knows (a constant, a bound
%   variable), f for one it asks for.
call_mode([], _, [], [], []).
call_mode([A|As], Env, [M|Ms], Bs, Fs) :-
    (   var(A), \+ bound(A, Env) -> M = f, Fs = [A|Fs1], Bs = Bs1
    ;   M = b, Bs = [A|Bs1], Fs = Fs1
    ),
    call_mode(As, Env, Ms, Bs1, Fs1).

fun_name(P, Mode, Name) :-
    rec_name(P, R), downcase_first(R, R1), atomic_list_concat(Mode, M), format(atom(Name), '~w_~w', [R1, M]).

request_function(Req) :-
    nb_getval(daml_fun_requests, Rs), nb_getval(daml_fun_done, Ds),
    (   ( memberchk(Req, Rs) ; memberchk(Req, Ds) ) -> true ; nb_setval(daml_fun_requests, [Req|Rs]) ).

%   The functions asked for, each written once; writing one may ask for more.
functions_text(Text) :-
    functions_loop([], Parts0), reverse(Parts0, Parts1),
    nb_getval(daml_extra_funs, Extra0), reverse(Extra0, Extra),
    append(Extra, Parts1, Parts), atomic_list_concat(Parts, Text0), atom_string(Text0, Text).

functions_loop(Acc, Parts) :-
    nb_getval(daml_fun_requests, Rs),
    (   Rs = [R|Rest]
    ->  nb_setval(daml_fun_requests, Rest),
        nb_getval(daml_fun_done, Ds), nb_setval(daml_fun_done, [R|Ds]),
        function_text(R, T), functions_loop([T|Acc], Parts)
    ;   Parts = Acc
    ).

function_text(req(Kind, P/N, Mode), Text) :-
    fun_name(P, Mode, Name),
    nb_getval(daml_clauses, Cls),
    findall(K-(H-B), member(cl(Kind, P/N, H, B, K), Cls), KHBs),
    pairs_keys_values(KHBs, Ks, _),
    findall(I, nth1(I, Mode, b), BIs), findall(I, nth1(I, Mode, f), FIs),
    findall(X, ( member(I, BIs), format(atom(X), 'x~w', [I]) ), Xs),
    signature(P/N, BIs, FIs, [state], Sig),
    maplist(clause_code_at(P/N, Mode, FIs), KHBs, Codes),
    daml_where(none),
    with_output_to(string(Comment), source_comment(Ks, "")),
    (   FIs == [] -> ( Codes == [] -> Body = 'False' ; atomic_list_concat(Codes, '\n    || ', Body) )
    ;   ( Codes == [] -> Body = '[]' ; atomic_list_concat(Codes, '\n    ++ ', Body) )
    ),
    atomic_list_concat([st|Xs], ' ', Params),
    format(string(Text), "~w~w : ~w~n~w ~w =~n    ~w~n~n", [Comment, Name, Sig, Name, Params, Body]).

%   Name : State -> T1 -> ... -> [T] (Bool when nothing is asked for).
signature(P/N, BIs, FIs, Pre, Sig) :-
    findall(T, ( member(I, BIs), type_of(P, N, I, T) ), BTs),
    findall(T, ( member(I, FIs), type_of(P, N, I, T) ), FTs),
    (   FTs == [] -> Ret = 'Bool'
    ;   FTs = [T1] -> format(atom(Ret), '[~w]', [T1])
    ;   atomic_list_concat(FTs, ', ', FT), format(atom(Ret), '[(~w)]', [FT])
    ),
    ( Pre == [state] -> Ins = ['State'|BTs] ; Ins = BTs ),
    append(Ins, [Ret], All), atomic_list_concat(All, ' -> ', Sig).

%   (where a refusal met in it is: the clause's term)
clause_code_at(PN, Mode, FIs, K-HB, Code) :- daml_where(K), clause_code(PN, Mode, FIs, HB, Code).

clause_code(P/N, Mode, FIs, H0-B0, Code) :-
    copy_term(H0-B0, H-B),
    H =.. [_|HArgs],
    foldl(head_place, HArgs, Mode, 1-[]-[]-[], _-Env-Gs0-Outs0),
    reverse(Gs0, Gs), reverse(Outs0, Outs),
    catch(( FIs == []
          ->  exists_(B, Env, st, C), append(Gs, [C], All), conj(All, Code0), format(atom(Code), '(~w)', [Code0])
          ;   gen_list(B, Env, st, val('$tuple'(Outs)), L),
              ( Gs == [] -> Code = L ; conj(Gs, G), format(atom(Code), '(if ~w then ~w else [])', [G, L]) )
          ),
          daml_refuse(Why),
          ( format(string(W), "in the rule for ~w/~w: ~w", [P, N, Why]), throw(daml_refuse(W)) )).

head_place(A, b, I-E0-G0-O0, I1-E-G-O0) :- !,
    I1 is I + 1, format(atom(X), 'x~w', [I]),
    (   var(A), \+ bound(A, E0) -> E = [A-X|E0], G = G0
    ;   var(A) -> lookup(A, E0, Nm), E = E0, format(atom(Q), '~w == ~w', [X, Nm]), G = [Q|G0]
    ;   literal(A, L), E = E0, format(atom(Q), '~w == ~w', [X, L]), G = [Q|G0]
    ).
head_place(A, f, I-E-G-O0, I1-E-G-[A|O0]) :- I1 is I + 1.

%   A function the program leaves to Prolog: the Daml companion must have it.
companion_function(P/N, Mode, Name) :-
    nb_getval(daml_companion_used, U),
    (   memberchk(Name, U) -> true
    ;   (   nb_current(daml_companion, Text), Text \== "", companion_defines(Text, Name)
        ->  nb_setval(daml_companion_used, [Name|U])
        ;   findall(I, nth1(I, Mode, b), BIs), findall(I, nth1(I, Mode, f), FIs),
            signature(P/N, BIs, FIs, [], Sig),
            (   nb_current(daml_partial, true), nb_current(daml_slot_names, SNs), memberchk(slot(P, N, _)-_, SNs)
            ->  What = left_out(P/N)          % a template of the program: its rules were left out
            ;   format(atom(Line), "~w : ~w  (for ~w/~w)", [Name, Sig, P, N]), What = missing(Line)
            ),
            ( nb_current(daml_where, W) -> true ; W = none ),
            nb_getval(daml_companion_missing, Ms),
            ( memberchk(What-W, Ms) -> true ; nb_setval(daml_companion_missing, [What-W|Ms]) )
        )
    ).

companion_defines(Text, Name) :-
    split_string(Text, "\n", "", Ls), member(L, Ls),
    string_concat(Name, Rest, L), ( sub_string(Rest, 0, 1, _, " ") ; sub_string(Rest, 0, 1, _, ":") ), !.

%   The companion's text: its imports (moved to the module's head) and its
%   declarations, when the module uses one of them.
companion_parts(Imports, Body) :-
    nb_getval(daml_companion_used, U),
    (   U \== [], nb_current(daml_companion, Text), Text \== ""
    ->  split_string(Text, "\n", "", Ls),
        exclude([L]>>( sub_string(L, 0, _, _, "module ") ), Ls, Ls1),
        partition([L]>>sub_string(L, 0, _, _, "import "), Ls1, Is, Bs),
        exclude([I]>>( sub_string(I, _, _, _, "Daml.Script") ; sub_string(I, _, _, _, "DA.Date") ), Is, Is1),
        ( Is1 == [] -> Imports = "" ; atomic_list_concat(Is1, '\n', I0), format(string(Imports), "~w~n", [I0]) ),
        atomic_list_concat(Bs, '\n', B0), split_string(B0, "", " \n", [Body])
    ;   Imports = "", Body = ""
    ).

%   The Daml companion: <knowledge base>.daml in the program's folder (or
%   the file the option daml_companion(File) names).
companion_setup(Options, Doc) :-
    nb_setval(daml_companion, ""),
    (   memberchk(daml_companion(F), Options) -> true
    ;   memberchk(base(Dir), Options), kb_name(Doc, KBN), format(atom(F), '~w/~w.daml', [Dir, KBN])
    ;   true
    ),
    (   nonvar(F) -> file_base_name(F, FB), nb_setval(daml_companion_file, FB) ; true ),
    (   nonvar(F), exists_file(F) -> read_file_to_string(F, T, [encoding(utf8)]), nb_setval(daml_companion, T) ; true ).

kb_name(Doc, Name) :-
    sub_string(Doc, B, _, _, "the knowledge base "), B1 is B + 19,
    sub_string(Doc, B1, _, 0, Rest), sub_string(Rest, E, _, _, " includes"), !,
    sub_string(Rest, 0, E, _, N0), split_string(N0, " ", " ", Ws), atomic_list_concat(Ws, '_', Name).

uses_dates(Terms) :-
    (   sub_term(X, Terms), compound(X), X = date(Y, _, _), integer(Y) -> true
    ;   nb_current(daml_types, Ts), memberchk(_-'Date', Ts)
    ).

		 /*******************************
		 *        THE REACTIVE CYCLE    *
		 *******************************/

%   A reactive rule with a Daml form: conditions on the state and the rules
%   (no event), and a conclusion of actions.
cycle_rule(Cs, Ts) :-
    is_list(Cs), is_list(Ts), Ts \== [],
    \+ ( member(C, Cs), C = happens(_, _, _) ),
    forall(member(T, Ts), ( T = happens(A, _, _), nonvar(A) )).

cycle_rules(Terms, Rs) :-
    findall(reactive_rule(Cs, Ts), ( member(reactive_rule(Cs, Ts), Terms), cycle_rule(Cs, Ts) ), Rs).

%   The operator's choice ReactiveCycle: on the state as it is, the actions
%   the reactive rules call for, those the constraints allow, taken one
%   after another (LPS takes them together; a program whose actions of one
%   cycle bear on each other may differ).
cycle_choice(Terms) :-
    cycle_rules(Terms, Rs),
    (   Rs == [] -> true
    ;   format("~n    nonconsuming choice ReactiveCycle : ContractId State~n      controller operator~n      do~n"),
        %  (each with its term, for its line)
        findall(T-(R-A), ( nth0(T, Terms, R0), R0 = reactive_rule(Cs0, Ts0), cycle_rule(Cs0, Ts0),
                           copy_term(R0, R), R = reactive_rule(_, Ts), member(happens(A, _, _), Ts) ), TRAs),
        foldl(cycle_action(Terms), TRAs, 0-self, _-Last),
        daml_where(none),
        format("        pure ~w~n", [Last]),
        nb_getval(daml_extra_funs, Ex),
        nb_setval(daml_extra_funs, ["-- (each due action taken in turn, on the state the one before left)\nfoldUpdates : (b -> a -> Update b) -> b -> [a] -> Update b\nfoldUpdates f z xs = case xs of\n  [] -> pure z\n  x :: rest -> do\n    z1 <- f z x\n    foldUpdates f z1 rest\n\n"|Ex]),
        note("The program's reactive rules are the operator's choice ReactiveCycle, which the script exercises once for each of LPS's cycles; the actions one cycle calls for are taken one after another, each on the state the one before left.")
    ).

cycle_action(Terms, T-(reactive_rule(Cs, _)-A), K0-C0, K-C) :-
    daml_where(T),
    K is K0 + 1, format(atom(C), 'c~w', [K]),
    A =.. [AF|Args], length(Args, AN), choice_name(AF, CN),
    (   AN > 0, type_of(AF, AN, 1, 'Party')
    ->  format(string(W), "a reactive rule takes ~w, an action of a party: in Daml only that party can take it, not the operator's cycle", [AF]),
        throw(daml_refuse(W))
    ;   true
    ),
    gen_list(Cs, [], this, val('$tuple'(Args)), Due),
    findall(Y, ( between(1, AN, I), format(atom(Y), 'y~w', [I]) ), Ys),
    ( Ys = [Y1] -> Pat = Y1 ; atomic_list_concat(Ys, ', ', P0), format(atom(Pat), '(~w)', [P0]) ),
    allowed_function(Terms, AF/AN, Allowed),
    atomic_list_concat([Allowed, this|Ys], ' ', AllowedCall),
    findall(S, ( nth1(I, Ys, Y), choice_arg(AF, AN, I, Nm), format(atom(S), '~w = ~w', [Nm, Y]) ), Ss),
    ( Ss == [] -> With = '' ; atomic_list_concat(Ss, '; ', SL), format(atom(With), ' with ~w', [SL]) ),
    source_comment([T], "        "),
    format("        let due~w = dedup (filter (\\~w -> ~w) (~w))~n", [K, Pat, AllowedCall, Due]),
    format("        ~w <- foldUpdates (\\c ~w -> exercise c ~w~w) ~w due~w~n", [C, Pat, CN, With, C0, K]).

%   <choice>Allowed : State -> ... -> Bool, the action's constraints (the
%   choice asserts the same).
allowed_function(Terms, AF/AN, Name) :-
    choice_name(AF, CN), downcase_first(CN, CN1), atom_concat(CN1, 'Allowed', Name),
    nb_getval(daml_extra_funs, Ex),
    (   member(T, Ex), sub_atom(T, 0, _, _, Name) -> true
    ;   nb_current(daml_where, W0),
        findall(K0-C, ( nth0(K0, Terms, d_pre(Cs0)), select(happens(E, _, _), Cs0, Cs), functor(E, AF, AN),
                        daml_where(K0),
                        copy_term(E-Cs, A1-Cs1), choice_env(A1, Env1, Guard),
                        exists(Cs1, Env1, st, Code0), conj([Guard, Code0], Code), format(atom(C), 'not (~w)', [Code]) ), KNs),
        nb_setval(daml_where, W0),
        pairs_keys_values(KNs, Ks, Ns),
        conj(Ns, Body),
        with_output_to(string(Comment), source_comment(Ks, "")),
        findall(Nm, ( between(1, AN, I), choice_arg(AF, AN, I, Nm) ), Nms),
        findall(Ty, ( between(1, AN, I), type_of(AF, AN, I, Ty) ), Tys),
        append([['State'], Tys, ['Bool']], All), atomic_list_concat(All, ' -> ', Sig),
        atomic_list_concat([st|Nms], ' ', Params),
        format(atom(T), "~w~w : ~w~n~w ~w =~n    ~w~n~n", [Comment, Name, Sig, Name, Params, Body]),
        nb_setval(daml_extra_funs, [T|Ex])
    ).

		 /*******************************
		 *          PROVENANCE          *
		 *******************************/

%   The provenance of the terms (prov(N, Line, _)) and the program's text,
%   for the comments; [] and "" write none.
source_setup(Prov, Doc) :-
    ( is_list(Prov) -> nb_setval(daml_prov, Prov) ; nb_setval(daml_prov, []) ),
    ( ( string(Doc) ; atom(Doc) ) -> atom_string(Doc, D), nb_setval(daml_doc, D) ; nb_setval(daml_doc, "") ).

%   source_comment(+Terms, +Indent): the line of the program each term (by
%   its index) came from, as a Daml comment line: one line with the start
%   of its sentence, several as a list. Nothing when no term has a line.
source_comment(Ks, Indent) :-
    (   nb_current(daml_prov, Prov), Prov \== []
    ->  findall(L, ( member(K, Ks), memberchk(prov(K, L, _), Prov), integer(L), L > 0 ), Ls0),
        sort(Ls0, Ls),
        (   Ls == [] -> true
        ;   Ls = [L]
        ->  (   sentence_start(L, Start) -> format("~w-- Logical English line ~w: ~w~n", [Indent, L, Start])
            ;   format("~w-- Logical English line ~w~n", [Indent, L])
            )
        ;   atomic_list_concat(Ls, ', ', LT), format("~w-- Logical English lines ~w~n", [Indent, LT])
        )
    ;   true
    ).

%   The first words of line L of the program (at most 60 characters).
sentence_start(L, Start) :-
    nb_current(daml_doc, Doc), Doc \== "",
    split_string(Doc, "\n", "", Lines), nth1(L, Lines, Line0),
    normalize_space(string(Line), Line0), Line \== "",
    string_length(Line, N),
    (   N =< 60 -> Start = Line
    ;   sub_string(Line, 0, 60, _, S0),
        ( sub_string(S0, B, _, _, " "), \+ ( sub_string(S0, B1, _, _, " "), B1 > B ) -> sub_string(S0, 0, B, _, S1) ; S1 = S0 ),
        string_concat(S1, " …", Start)
    ).

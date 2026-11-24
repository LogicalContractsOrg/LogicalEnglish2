/** <module> The LegalRuleML round trip: LE -> LegalRuleML -> LE

    The gate of Phase 2f's second deliverable (the design notes roadmap.md
    §8): every program of LE2's core example corpus (English) that the
    exporter writes whole (no rule left out),

        LE  ->  LegalRuleML (lrml_export.pl)  ->  LE (lrml_twin.pl)

    must hold the same rules and facts as before, up to the naming of
    variables — the words travel as each relation's text, so the functors
    LE derives from them are the same. Programs with a construct LegalRuleML
    cannot state (a universal, an aggregate, a table, a service) are
    skipped, and said so; the scenarios' facts travel too and are compared.

        ./myswipl.sh -q -g "consult('migration/legalruleml/roundtrip.pl')" -g "roundtrip:main" -t halt
*/

:- module(roundtrip, [main/0, roundtrip_file/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).
:- use_module(library(time)).
:- use_module('../le2_paths', []).
:- use_module(le2(le_kbs)).
:- use_module(le2(le_writer)).
:- use_module(lrml_export).
:- use_module(lrml_twin).

corpus(Files) :-
    le2_paths:le2_dir(LE2),
    findall(F, ( member(Sub, ['/examples/moreExamples', '/examples/regulatory']), atom_concat(LE2, Sub, Dir),
                 directory_member(Dir, F, [extensions([le]), recursive(true)]),
                 \+ sub_atom(F, _, _, _, 'insureLE2'), \+ sub_atom(F, _, _, _, 'InsurLE2'),
                 \+ sub_atom(F, _, _, _, 'lpsPlus'), \+ sub_atom(F, _, _, _, '/private/') ), Fs0),
    sort(Fs0, Files).

%!  roundtrip_file(+File, -Outcome) is det.
%   same, differs(OnlyBefore, OnlyAfter), skipped(Why) or error(Why).
roundtrip_file(File, Outcome) :-
    catch(call_with_time_limit(60, roundtrip_(File, Outcome)), E,
          ( message_to_string(E, S), Outcome = error(S) )), !.
roundtrip_file(_, error(failed)).

roundtrip_(File, Outcome) :-
    read_file_to_string(File, Text, [encoding(utf8)]),
    file_directory_name(File, Dir),
    le_kbs:load_text(Text, Dir, KB1),
    (   le_writer:kb_to_ir(KB1, program(H1, _)), memberchk(target(T), H1), T \== prolog
    ->  Outcome = skipped("not a Prolog-target program")
    ;   export_lrml(KB1, [text(Text), base(Dir)], Result),
        (   Result = refused([problem(_, N)|_])
        ->  Outcome = skipped(N)
        ;   Result = exported(_, XML, _, _),
            tmp_file_stream(text, Tmp, Out), write(Out, XML), close(Out),
            file_base_name(File, B), file_name_extension(Name, _, B),
            twin_migration(Tmp, [name(Name), source_copy(B)], migration(_, IR, _, Tests)),
            delete_file(Tmp),
            le_migration:source_tests_scenarios(Tests, Scen),
            IR = program(Hd, Items), append(Items, Scen, Items2),
            le_write(program(Hd, Items2), LE2, _),
            le_kbs:load_text(LE2, Dir, KB2),
            program_items(KB1, P1), program_items(KB2, P2),
            subtract(P1, P2, Only1), subtract(P2, P1, Only2),
            (   Only1 == [], Only2 == [] -> Outcome = same ; Outcome = differs(Only1, Only2) )
        )
    ).

%   The rules, facts and scenario facts of a loaded program, as strings with
%   their variables named in order, sorted; the deontic library's own rules
%   (included by the twin) are not the program's.
program_items(KB, Items) :-
    le_writer:kb_to_ir(KB, program(_, Is)),
    findall(S, ( member(I, Is), item_key(I, K), \+ library_item(K), normal_string(K, S) ), Ss),
    msort(Ss, Items).

item_key(rule(H, B, _), rule(H, B1)) :- strip(B, B0), flat_and(B0, B1).
item_key(fact(H, _), fact(H)) :- \+ functor(H, le_text_at, _), \+ functor(H, le_published_at, _).
item_key(scenario(N0, Lines, _), scenario_fact(N, F)) :-          % (scenario names: words joined)
    format(atom(A), '~w', [N0]), atomic_list_concat(Ws, ' ', A), atomic_list_concat(Ws, '_', N),
    member(L, Lines), ( L = fact(F) ; L = fact(F, _) ).

library_item(rule(H, _)) :- functor(H, F, _), library_functor(F).
library_functor(F) :- sub_atom(F, _, _, _, obligation_of_that), !.
library_functor(F) :- sub_atom(F, _, _, _, prohibition_of_that), !.
library_functor(F) :- sub_atom(F, _, _, _, complies_with_the_obligation), !.
library_functor(F) :- sub_atom(F, _, _, _, is_in_breach), !.

%   Conjunctions compared flat: the exporter writes an And of all the
%   conditions, the reader rebuilds it left-associated.
flat_and(B, F) :- conjuncts(B, Cs), Cs = [C|Rest], foldl([X, A, and(A, X)]>>true, Rest, C, F0), !, F = F0.
flat_and(B, B).
conjuncts(V, [V]) :- var(V), !.
conjuncts(and(A, B), Cs) :- !, conjuncts(A, CA), conjuncts(B, CB), append(CA, CB, Cs).
conjuncts(G, [G1]) :- compound(G), !, G =.. [F|As], maplist(flat_and, As, Bs), G1 =.. [F|Bs].
conjuncts(G, [G]).

strip(V, V) :- var(V), !.
strip(le_at(G, _, _), G1) :- !, strip(G, G1).
strip(T, T1) :- compound(T), !, T =.. [F|As], maplist(strip, As, Bs), T1 =.. [F|Bs].
strip(T, T).

normal_string(T, S) :-
    copy_term(T, C), numbervars(C, 0, _),
    format(string(S), "~W", [C, [quoted(true), numbervars(true)]]).

main :-
    corpus(Files),
    findall(F-O, ( member(F, Files), roundtrip_file(F, O) ), Rs),
    forall(member(F-O, Rs), report(F, O)),
    aggregate_all(count, member(_-same, Rs), NS),
    aggregate_all(count, member(_-differs(_, _), Rs), ND),
    aggregate_all(count, member(_-skipped(_), Rs), NK),
    aggregate_all(count, member(_-error(_), Rs), NE),
    length(Rs, N),
    format("~nThe LegalRuleML round trip: ~w programs; ~w the same, ~w differ, ~w skipped, ~w errors.~n",
           [N, NS, ND, NK, NE]).

report(F, same) :- !, format("  same     ~w~n", [F]).
report(F, skipped(W)) :- !, format("  skipped  ~w (~w)~n", [F, W]).
report(F, error(W)) :- !, format("  ERROR    ~w: ~w~n", [F, W]).
report(F, differs(A, B)) :-
    format("  DIFFERS  ~w~n", [F]),
    forall(( nth1(I, A, X), I =< 3 ), format("      only before: ~w~n", [X])),
    forall(( nth1(I, B, X), I =< 3 ), format("      only after:  ~w~n", [X])).

/** <module> File ▸ Open of a Drools rule base: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    a `.drl` file: the rule base becomes its Logical English for LPS twin
    (drl_twin.pl, over LPS2's reading of DRL) and, when it only inserts facts
    (a decision service), also its timeless twin `<name>_decision.le`. Types
    come from the file's `declare`s, or from the fields the rules use; a
    rule's Java is kept as a comment or a TODO block; the file is kept under
    sources/. With no working memory given, the twins have no scenario:
    state one with `initially` (LPS) or a scenario (the decision twin).
*/

:- module(drl_import, [import_drl/3, detect_drl/1]).

:- use_module(library(lists)).
:- use_module(library(aggregate)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module(drl_twin).
:- use_module(le2(le_migration)).

%!  detect_drl(+Input) is semidet.
detect_drl(Input) :-
    exists_file(Input),
    read_file_to_string(Input, S, []),
    sub_string(S, _, _, _, "rule "), sub_string(S, _, _, _, "when"),
    sub_string(S, _, _, _, "then"), sub_string(S, _, _, _, "end"), !.

%!  import_drl(+Input, +OutDir, -Result) is det.
import_drl(Input, OutDir0, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    file_base_name(Input, B), file_name_extension(Stem0, _, B),
    le_stem(Stem0, Id),
    atomic_list_concat([OutDir, '/sources'], SD), make_directory_path(SD),
    atomic_list_concat([SD, '/', B], Copy), copy_file(Input, Copy),
    Case = case(Id, [drl_path(Input), title(Stem0)]),
    drl_migration(Case, [sources(B)], M1),
    write_migration(M1, OutDir, Id, report(LEFile, _, _, _)),
    %  counted from the ledger's rule entries: the write's own counts take
    %  in every entry (a field left out, a diagnostic), not only the rules
    M1 = migration(_, _, Ledger, _),
    rule_count(Ledger, encoded, E), rule_count(Ledger, approximated, A), rule_count(Ledger, residue, R),
    aggregate_all(count, member(entry(_, diagnostic, approximated, _, _, _), Ledger), W),
    (   W =:= 0 -> WS = ""
    ;   format(string(WS), "; ~w other approximation(s) of the reading (a type with no declare, an insertLogical read as an insert)", [W])
    ),
    format(string(N1), "~w: ~w rule(s) encoded, ~w approximated (salience, a rule attribute, a value computed in Java), ~w left as residue (Java only, or not translated)~w; ~w.ledger.md says which and why. Logical English for LPS: run it with Misc > Run in LPS, or in the LPS2 IDE.", [Id, E, A, R, WS, Id]),
    (   drl_twin:stateless(Case)
    ->  format(atom(Id2), '~w_decision', [Id]),
        drl_twin:drl_decision_migration(Case, [sources(B)], M2),
        write_migration(M2, OutDir, Id2, _),
        format(string(N2), "It only inserts facts, so it is also a decision service: ~w_decision.le beside it is its timeless reading (one rule per DRL rule, in salience order).", [Id]),
        Notes = [N1, N2]
    ;   Notes = [N1]
    ).

rule_count(Ledger, V, N) :-
    aggregate_all(count, member(entry(_, rule, V, _, _, _), Ledger), N).

le_stem(S0, S) :-
    downcase_atom(S0, L), atom_codes(L, Cs0),
    maplist([C0, C]>>( code_type(C0, alnum) -> C = C0 ; C = 0'_ ), Cs0, Cs), atom_codes(S, Cs).

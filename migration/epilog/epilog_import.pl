/** <module> File ▸ Open of an Epilog program: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    an Epilog file (`.epilog`, `.epi`, `.hrf` — the Epilog pages' own
    extension —, or a `.txt` that reads as Epilog). It needs no EpilogJS:
    the text is read by epilog_syntax.pl.

      - A game or any program with operation definitions (`a :: c ==> e`)
        becomes Logical English for LPS (epilog_twin:game_migration/3): the
        operations causal laws, the views over the state intensional
        fluents, `init` evaluated by Prolog as the initial state. With no
        play recorded, it has no scenario: add one (`mark 2 2 from 1 to 2.`).
      - A ruleset (facts and view definitions) becomes timeless LE
        (epilog_twin:theory_migration/3) with a query per view; its expected
        answers come from EpilogJS only in the build (build.pl).

    The file is kept under sources/.
*/

:- module(epilog_import, [import_epilog/3, detect_epilog/1]).

:- use_module(library(lists)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module(epilog_syntax).
:- use_module(epilog_twin).
:- use_module(le2(le_migration)).

%!  detect_epilog(+Input) is semidet.
%
%   Epilog: it reads as Epilog, has a rule (`:-`) or an operation (`::`),
%   and no sentence ends with a full stop (which would be Prolog).
detect_epilog(Input) :-
    exists_file(Input),
    read_file_to_string(Input, S, []),
    ( sub_string(S, _, _, _, ":-") ; sub_string(S, _, _, _, "::") ),
    \+ prolog_like(S),
    catch(epilog_text_sentences(S, Ss), _, fail),
    Ss = [_, _|_], !.

prolog_like(S) :-
    split_string(S, "\n", " \t\r", Lines),
    member(L, Lines), \+ sub_string(L, 0, _, _, "%"),
    sub_string(L, _, 1, 0, "."), !.

%!  import_epilog(+Input, +OutDir, -Result) is det.
import_epilog(Input, OutDir0, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    file_base_name(Input, B), file_name_extension(Stem0, _, B),
    le_stem(Stem0, Id),
    atomic_list_concat([OutDir, '/sources'], SD), make_directory_path(SD),
    atomic_list_concat([SD, '/', B], Copy), copy_file(Input, Copy),
    epilog_file_sentences(Input, Ss),
    (   dynamic_program(Ss)
    ->  game_migration(Id, [library(Input), title(Stem0)], M),
        write_migration(M, OutDir, Id, report(LEFile, _, counts(E, A, R), _)),
        format(string(N1), "~w: an Epilog program with operations, as Logical English for LPS (~w elements encoded, ~w approximated, ~w residue). The operations are causal laws and the views over the state intensional fluents; add a scenario of moves (`... from 1 to 2.`) and run it with Misc > Run in LPS, or in the LPS2 IDE.", [Id, E, A, R])
    ;   theory_migration(Id, [rules(Input), title(Stem0), oracle(false)], M),
        write_migration(M, OutDir, Id, report(LEFile, _, counts(E, A, R), _)),
        format(string(N1), "~w: an Epilog ruleset, as Logical English (~w elements encoded, ~w approximated, ~w residue), with a query per view. The wording is naive (named after the relations): improve it with the assistant.", [Id, E, A, R])
    ),
    Notes = [N1].

dynamic_program(Ss) :- memberchk(handler(_, _, _)-_, Ss), !.

le_stem(S0, S) :-
    downcase_atom(S0, L), atom_codes(L, Cs0),
    maplist([C0, C]>>( code_type(C0, alnum) -> C = C0 ; C = 0'_ ), Cs0, Cs), atom_codes(S, Cs).

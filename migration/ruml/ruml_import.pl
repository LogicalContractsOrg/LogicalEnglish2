/** <module> File ▸ Open of a RUML file: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    a RUML rulemap: a `.ruml` file, a `.rumlc` container, a `.json` file
    whose `$format` is "RUML", or a zip archive (or folder) with a rulemap
    and its sidecars (`.ruml-ext`). The program opened is the twin
    ruml_twin.pl writes, with the texts the rulemap carries under sources/.

    Its scenarios are cases generated from what the expressions compare,
    answered by the oracle (ruml_oracle.mjs) when Node is installed; without
    Node the program has no scenarios, and the note says so. A rulemap that
    the reader rejects for a reason that changes its meaning (an unknown
    required capability, no root) is not translated: the error says why.
*/

:- module(ruml_import, [import_ruml/3, detect_ruml/1, evaluate_ruml/4]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module(ruml_reader).
:- use_module(ruml_build, [rulemap_migration/4, fatal_issue/1, write_texts/3]).
:- use_module(ruml_cases, [generated_cases/3]).
:- use_module(le2(le_migration)).
:- use_module(ruml_result).
:- use_module(library(http/json)).

%!  detect_ruml(+Input) is semidet.
detect_ruml(Input) :- ruml_files(Input, [_|_]).

ruml_files(Input, Files) :-
    (   exists_directory(Input)
    ->  findall(F, ( directory_member(Input, F, [recursive(true)]), ruml_file(F) ), Fs0), msort(Fs0, Files)
    ;   exists_file(Input), file_name_extension(_, rumlc, Input) -> Files = [Input]
    ;   exists_file(Input), ruml_file(Input) -> Files = [Input]
    ;   Files = []
    ).

%   A file whose `$format` (read from its first characters) is RUML or
%   RUML-EXT.
ruml_file(F) :-
    ( file_name_extension(_, ruml, F) ; file_name_extension(_, 'ruml-ext', F) ; file_name_extension(_, json, F) ), !,
    catch(setup_call_cleanup(open(F, read, In, [encoding(utf8)]), read_string(In, 2000, Head), close(In)), _, fail),
    sub_string(Head, _, _, _, "\"$format\""),
    (   sub_string(Head, _, _, _, "\"RUML\"") ; sub_string(Head, _, _, _, "\"RUML-EXT\"") ), !.

%!  import_ruml(+Input, +OutDir, -Result) is det.
import_ruml(Input, OutDir0, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    ruml_files(Input, Files),
    (   Files == [] -> throw(error(format("~w is not a RUML rulemap (no `$format: \"RUML\"`)", [Input]), _)) ; true ),
    (   Files = [One], file_name_extension(_, rumlc, One) -> ruml_read_file(One, Doc, Issues)
    ;   ruml_read_files(Files, Doc, Issues)
    ),
    (   Doc == none -> throw(error(format("~w could not be read as RUML", [Input]), _)) ; true ),
    (   include(fatal_issue, Issues, [issue(_, Rule, _, Msg)|_])
    ->  throw(error(format("The rulemap is not translated: ~w (RUML rule ~w).", [Msg, Rule]), _))
    ;   true
    ),
    main_file(Files, Main), file_base_name(Main, Base), file_name_extension(Stem, _, Base),
    program_name(Stem, Name),
    (   catch(generated_cases(Doc, Main, Cases), _, fail) -> CaseNote = oracle ; Cases = [], CaseNote = none ),
    write_texts(Doc, OutDir, Texts),
    embedded_program(Doc, OutDir, Name, Embedded),
    rulemap_migration(Doc, Base, [tests(Cases), program(Name), texts(Texts)], Migration0),
    with_original(Migration0, Main, OutDir, Migration),
    write_migration(Migration, OutDir, Name, report(LEFile, WIssues, counts(E, A, R), Fid)),
    include([issue(S, _, _)]>>(S == error), WIssues, Errs), length(Errs, NE),
    (   Fid = fidelity(P, F, U, _), CaseNote == oracle
    ->  format(string(N1), "~w: ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors; generated cases, answered by an evaluator written from the RUML specification: ~w pass, ~w fail, ~w errors.", [Base, E, A, R, NE, P, F, U])
    ;   format(string(N1), "~w: ~w ledger elements encoded, ~w approximated, ~w residue; ~w writer errors; no scenarios (the evaluator that answers the generated cases needs Node).", [Base, E, A, R, NE])
    ),
    (   Embedded = yes(Rel) -> format(string(NE1), "This rulemap was written by Logical English: the program it was written from is ~w.", [Rel]), Notes0 = [N1, NE1] ; Notes0 = [N1] ),
    include([issue(Sv, _, _, _)]>>(Sv == warning ; Sv == error), Issues, Shown0),
    (   Shown0 == [] -> Notes = Notes0
    ;   findall(S, ( member(issue(Sv, Rule, _, M), Shown0), format(string(S), "RUML ~w (~w): ~w", [Rule, Sv, M]) ), Ss),
        length(Ss, NS), ( NS > 5 -> length(Ss5, 5), append(Ss5, _, Ss) ; Ss5 = Ss ),
        append(Notes0, Ss5, Notes)
    ).

%   A rulemap that Logical English wrote carries its program in the
%   metadata's comment (ruml_export.pl): it is kept beside the twin, under
%   sources/, for the reader to compare or to take back.
embedded_program(Doc, Dir, Name, Embedded) :-
    (   j(Doc, metadata, M), j(M, comment, C),
        string_concat("Written by Logical English from this program:\n\n", Program, C)
    ->  atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
        format(atom(Rel), 'sources/~w.original.le', [Name]),
        atomic_list_concat([Dir, '/', Rel], F),
        setup_call_cleanup(open(F, write, O, [encoding(utf8)]), write(O, Program), close(O)),
        Embedded = yes(Rel)
    ;   Embedded = no
    ).

main_file(Files, Main) :-
    (   member(Main, Files), ( file_name_extension(_, ruml, Main) ; file_name_extension(_, rumlc, Main) ) -> true
    ;   Files = [Main|_]
    ).

program_name(Stem, Name) :-
    atom_codes(Stem, Cs), maplist([C0, C]>>( code_type(C0, alnum) -> code_type(C, to_lower(C0)) ; C = 0'_ ), Cs, Ds),
    atom_codes(Name, Ds).

with_original(migration(Meta, program(H, Items), L, T), File, Dir, migration(Meta, program(H, [document(the_rulemap, [text(Rel)])|Items]), L, T)) :-
    atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD),
    file_base_name(File, B), atomic_list_concat([SD, '/', B], Dst),
    ( same_file(File, Dst) -> true ; copy_file(File, Dst) ),
    atomic_list_concat(['sources/', B], Rel).

%!  evaluate_ruml(+Input, +Case, +Options, -Reply) is det.
%
%   LE2's operation evaluateForeign (le_import.pl, evaluator/5): the rulemap
%   (a `.ruml`, or a `.rumlc` or zip with its sidecars) and the values of a
%   case (a dict) in; Reply: {result: the `.ruml-result` as a dict,
%   fileName, notes}. Options: `mode` ("complete", the default, or
%   "optimized"), `caseId`, `maxDepth`.
evaluate_ruml(Input, Case, Opts, _{result: R, fileName: FN, notes: Notes}) :-
    ruml_files(Input, Files),
    (   Files == [] -> throw(error(format("~w is not a RUML rulemap", [Input]), _)) ; true ),
    (   Files = [One], file_name_extension(_, rumlc, One) -> ruml_read_file(One, Doc, Issues)
    ;   ruml_read_files(Files, Doc, Issues)
    ),
    (   include(fatal_issue, Issues, [issue(_, Rule, _, Msg)|_])
    ->  throw(error(format("The rulemap cannot be evaluated: ~w (RUML rule ~w).", [Msg, Rule]), _))
    ;   true
    ),
    main_file(Files, Main), file_base_name(Main, Base), file_name_extension(Stem, _, Base),
    ( get_dict(mode, Opts, M0) -> atom_string(Mode, M0) ; Mode = complete ),
    ( memberchk(Mode, [complete, optimized]) -> true ; throw(error(format("The mode ~w is not one of RUML's (complete, optimized).", [Mode]), _)) ),
    findall(O, ( get_dict(caseId, Opts, C) -> O = case_id(C) ; fail ), O1),
    findall(O, ( get_dict(maxDepth, Opts, D) -> O = max_depth(D) ; fail ), O2),
    append([[mode(Mode)], O1, O2], EO),
    %  a person's answers to leaves that no capability decides (Appendix A's
    %  leaf statuses), by LexId: {"7": "true"}
    (   get_dict(leaves, Opts, LD) -> dict_pairs(LD, _, LPs), findall('$leaf'(L)-B, ( member(L0-V, LPs), atom_string(L, L0), atom_string(B, V) ), Ls) ; Ls = [] ),
    dict_pairs(Case, _, CPs), append(CPs, Ls, CaseData),
    ruml_evaluate_doc(Doc, Base, CaseData, EO, Result),
    result_json_text(Result, Text), atom_json_dict(Text, R, []),
    format(atom(FN), '~w.ruml-result', [Stem]),
    format(string(N1), "~w evaluated by Logical English, in RUML's ~w mode.", [Base, Mode]),
    Notes = [N1].

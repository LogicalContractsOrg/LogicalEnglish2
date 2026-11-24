/** <module> Opening a Solidity contract as Logical English for LPS

    The adapter LE2's File ▸ Open (le_import.pl) and the LPS2 IDE call for a
    `.sol` file, or a `.zip` of a Solidity source tree: the contract is
    translated by the same front end as the reference twins (sol_front.pl)
    into an LE-for-LPS program, with its ledger (its legal view is computed by the editors), written
    into the directory the importer gives.

      - The contract translated is the most derived non-abstract contract the
        uploaded sources define (the one with the longest linearisation; the
        last one on a tie). OpenZeppelin imports resolve through this
        directory's node_modules (solc_ast.js).
      - The constructor is run with its parameters as NAMED CONSTANTS
        (`initialOwner` -> "the initial owner"), so the `initially` facts say
        what the deployment sets without inventing values; when the
        constructor's arithmetic needs numbers, it is not run, and a note
        says so.
      - A function the front end does not follow (loops, external calls,
        assembly, …) is a residue block, which the writer marks TODO, with
        the function's source verbatim; the function's other paths are still
        translated.
      - Sources that do not compile give a program that is a TODO comment:
        the compiler's errors and the source, verbatim.

    There is no scenario: the calls are the user's to add. A comment after
    the laws lists each action's sentence, as the scenario would say it.
*/

:- module(sol_import, [import_solidity/3, detect_solidity/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module(sol_front).
:- use_module(sol_migrate, [le2_dir/1]).

:- use_module(le2(le_writer)).
:- use_module(le2(le_migration)).
:- use_module(le2(le_lps_legal)).
:- use_module(le2(le_i18n)).

%!  detect_solidity(+Input) is semidet.
%
%   A .sol file, or a directory holding one (outside node_modules).
detect_solidity(Input) :-
    sol_files(Input, [_|_]).

%!  import_solidity(+Input, +OutDir, -Result) is det.
%
%   Result = imported(LEFile, Notes).
import_solidity(Input, OutDir, imported(LEFile, Notes)) :-
    sol_files(Input, Files),
    input_stem(Input, Files, Stem),
    atomic_list_concat([OutDir, '/', Stem, '.le'], LEFile),
    catch(( sol_compile(Files, JSON), sol_load(JSON, Model) ), E, true),
    (   var(E)
    ->  (   pick_contract(Model, Files, CName)
        ->  translate(Model, CName, Files, OutDir, Stem, LEFile, Notes)
        ;   no_contract_program(Files, Stem, LEFile, Notes)
        )
    ;   compile_error_text(E, Why),
        todo_program(Files, Stem, Why, LEFile),
        Notes = [Why]
    ).

		 /*******************************
		 *           SOURCES            *
		 *******************************/

sol_files(Input, [Abs]) :-
    exists_file(Input), !,
    file_name_extension(_, Ext, Input), downcase_atom(Ext, sol),
    absolute_file_name(Input, Abs).
sol_files(Dir, Files) :-
    exists_directory(Dir),
    findall(F, dir_sol_file(Dir, F), Files0),
    msort(Files0, Files).

dir_sol_file(Dir, F) :-
    directory_member(Dir, F0, [recursive(true), extensions([sol])]),
    \+ sub_atom(F0, _, _, _, '/node_modules/'),
    absolute_file_name(F0, F).

input_stem(Input, Files, Stem) :-
    (   exists_file(Input) -> file_base_name(Input, B)
    ;   Files = [F|_], file_base_name(F, B)
    ),
    file_name_extension(S0, _, B),
    downcase_atom(S0, S1),
    atom_codes(S1, Cs0), maplist(stem_code, Cs0, Cs), atom_codes(S2, Cs),
    ( sub_atom(S2, 0, 1, _, C), char_type(C, digit) -> atom_concat(c_, S2, Stem) ; Stem = S2 ).

stem_code(C, C) :- code_type(C, alnum), C < 128, !.
stem_code(_, 0'_).

%   The most derived concrete contract defined in the uploaded files.
pick_contract(Model, Files, Name) :-
    findall(L-Name0,
            ( sol_front:contract_node(Model, Name0, D),
              get_dict(contractKind, D, contract),
              \+ get_dict(abstract, D, true),
              defined_in_upload(Model, D, Files),
              length(D.linearizedBaseContracts, L) ),
            Cands),
    Cands \== [],
    max_member(_-Name, Cands).

%   A contract of the upload, not of an imported library.
defined_in_upload(Model, D, Files) :-
    get_dict(src, D, Src), split_string(Src, ":", "", [_, _, IS]), number_string(I, IS),
    sol_front:source_text(Model, I, Text),
    member(F, Files), read_file_to_string(F, FT, [encoding(utf8)]), FT == Text, !.

		 /*******************************
		 *         TRANSLATION          *
		 *******************************/

translate(Model, CName, Files, OutDir, Stem, LEFile, Notes) :-
    sol_contract(Model, CName, C),
    constructor_params(C, Params),
    maplist(param_constant, Params, Consts),
    maplist(file_base_name, Files, Bases),
    atomic_list_concat(Bases, ', ', FilesT),
    format(string(Cm0), "~w, translated from ~w when it was opened, by the Solidity translator.~nOne law per success path of each state-changing function, one integrity constraint per revert path;~nthe reverts' reasons are the comments above the constraints; what was not translated is marked TODO.~nSee ~w.ledger.md. The contract: File > Show the Original in the Logical English editor, View > The original this was converted from in the LPS2 IDE.~nWho may do what: the legal view (Misc > Legal View of This LPS Program in the Logical English editor, View > Legal view in the LPS2 IDE).", [CName, FilesT, Stem]),
    (   Params == []
    ->  Opts = [comment(Cm0), kb(Stem)], CNote = []
    ;   catch_with_backtrace(sol_twin(C, [constructor_args(Consts), comment(Cm0), kb(Stem)], _, _), _, fail)
    ->  Opts = [comment(Cm0), kb(Stem), constructor_args(Consts)],
        atomic_list_concat(Consts, '", "', CT),
        format(string(CN), "the constructor was run with its parameters as named constants: \"~w\"", [CT]),
        CNote = [CN]
    ;   Opts = [comment(Cm0), kb(Stem)],
        CNote = ["the constructor was not run (its arithmetic needs actual values): give the initial state with `initially` facts"]
    ),
    sol_twin(C, Opts, program(H, Items0), Ledger),
    calls_comment(program(H, Items0), CallsCm),
    append(Items0, [CallsCm], Items),
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    Meta = [program(Stem), source('Solidity'), artifacts([FilesT]),
            translator('the Solidity translator (with solcjs), on opening'), date(Date)],
    write_migration(migration(Meta, program(H, Items), Ledger, []), OutDir, Stem, report(LEFile, Issues, counts(E, A, R), _)),
    findall(N, ( member(issue(error, Co, M), Issues), format(string(N), "writer: ~w: ~w", [Co, M]) ), WNotes),
    format(string(Summary), "contract ~w: ~w elements encoded, ~w approximated, ~w residue (marked TODO)", [CName, E, A, R]),
    legal_view_note(LEFile, LNotes),
    append([[Summary], CNote, WNotes, LNotes], Notes).

constructor_params(contract(_, _, [Top|_], _, Fns, _), Params) :-
    (   member(fn(_, _, constructor, _, _, Top, D), Fns)
    ->  findall(N, ( member(P, D.parameters.parameters), atom_string(N0, P.name), N0 \== '',
                     N = N0 ), Params)
    ;   Params = []
    ).

%   `initialOwner`, `_initialOwner`, `initial_owner` -> 'the initial owner'
param_constant(P, C) :-
    atom_codes(P, Cs0),
    split_camel(Cs0, Words0),
    exclude(==(''), Words0, Words),
    atomic_list_concat(Words, ' ', W),
    downcase_atom(W, WL),
    atom_concat('the ', WL, C).

split_camel(Cs, Words) :-
    phrase(camel_words(Ws), Cs), maplist(codes_atom, Ws, Words).

codes_atom(Cs, A) :- atom_codes(A, Cs).

camel_words([W|Ws]) --> sep, camel_word(W), { W \== [] }, !, camel_words(Ws).
camel_words([]) --> sep.
sep --> "_", !, sep.
sep --> [].
camel_word([C|Cs]) --> [C], { C \== 0'_ }, lower_run(Cs).
lower_run([C|Cs]) --> [C], { C \== 0'_, \+ code_type(C, upper) }, !, lower_run(Cs).
lower_run([]) --> [].

%   What each action says in a scenario, as a comment: the calls are the
%   user's to add.
calls_comment(program(_, Items), comment(Text)) :-
    findall(L, ( member(action(_, T, _), Items), format(string(L), "    ~w at 1.", [T]) ), Ls),
    atomic_list_concat(Ls, '\n', LT),
    format(string(Text), "To run it, add a scenario of calls (and `initially` facts for the state it starts from),~neach call a sentence of this form, with its time (`at 1`: from 1 to 2):~n  scenario one is:~n~w", [LT]).

%   The legal view is not written: the editors compute it from the program
%   (Misc > Legal View). The note only says whether it can be drawn.
legal_view_note(LEFile, Notes) :-
    read_file_to_string(LEFile, T, [encoding(utf8)]),
    (   catch(legal_view_text(T, [], _, _), _, fail)
    ->  Notes = ["who may do what, when, with which effect: the legal view, computed from the program (Misc > Legal View of This LPS Program in the Logical English editor, View > Legal view in the LPS2 IDE)"]
    ;   Notes = []
    ).

		 /*******************************
		 *        NOT TRANSLATED        *
		 *******************************/

compile_error_text(error(solidity_compile_failed(T), _), W) :- !,
    split_string(T, "\n", " \r", Ls0), exclude(==(""), Ls0, Ls),
    ( Ls = [L1|_] -> format(string(W), "the Solidity compiler refused it: ~w", [L1]) ; W = "the Solidity compiler refused it" ).
compile_error_text(E, W) :- message_to_codes(E, W).

message_to_codes(E, W) :- catch(( message_to_codes(E, [], Cs), string_codes(W, Cs) ), _, format(string(W), "~q", [E])).

%   The whole upload as a TODO comment, with the reason.
todo_program(Files, _Stem, Why, LEFile) :-
    setup_call_cleanup(open(LEFile, write, Out, [encoding(utf8)]),
                       ( forall(member(F, Files),
                                ( file_base_name(F, B),
                                  le_i18n:le_msg(import_fallback_todo, [file-B, reason-Why], M),
                                  format(Out, "% TODO: ~w~n%~n", [M]),
                                  read_file_to_string(F, T, [encoding(utf8)]),
                                  split_string(T, "\n", "", Ls),
                                  forall(member(L, Ls), format(Out, "%   | ~w~n", [L])),
                                  nl(Out) )),
                         format(Out, "the target language is: lps.~n", []) ),
                       close(Out)).

no_contract_program(Files, Stem, LEFile, [Why]) :-
    Why = "the sources define no concrete contract (only interfaces, libraries or abstract contracts)",
    todo_program(Files, Stem, Why, LEFile).

/** <module> File ▸ Open of a Rune file (DRR, the CDM, a model of one's own)

    The adapter LE2's le_import.pl calls (le_importers.pl registers it). The
    work is done in a child Prolog process (rune_import_run.pl), which
    loads the Rune model, DRR 7.14.0 with the CDM 6.29 and the upload laid
    over it, without touching the server's own state; an upload of DRR's
    own files, unchanged, opens the twin built beforehand.
*/
:- module(rune_import, [import_rune/3, detect_rune/1]).
:- use_module(library(process)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module(library(lists)).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).

%!  detect_rune(+Input) is semidet.
%
%   A .rosetta file, or a folder (an extracted archive) holding one.
detect_rune(Input) :-
    (   exists_directory(Input)
    ->  directory_member(Input, _, [extensions([rosetta]), recursive(true)]), !
    ;   file_name_extension(_, rosetta, Input)
    ).

%!  import_rune(+Input, +OutDir, -imported(LEFile, Notes)) is det.
import_rune(Input, OutDir, imported(LEFile, Notes)) :-
    here(H), directory_file_path(H, 'rune_import_run.pl', Runner),
    current_prolog_flag(executable, SW),
    %  the child is told where this process's own LE2 is (it would find
    %  the one this directory belongs to, which is the same unless LE2 was
    %  loaded from elsewhere)
    (   le2_home(LE2) -> Env = [environment(['LE2_DIR'=LE2])] ; Env = [] ),
    append([[stdout(pipe(Out)), stderr(null), process(P)], Env], Opts),
    process_create(SW, ['-q', file(Runner), '--', Input, OutDir], Opts),
    read_string(Out, _, S), close(Out), process_wait(P, _),
    split_string(S, "\n", " \r", Ls0), exclude(==(""), Ls0, Ls),
    (   last(Ls, J), catch(atom_json_dict(J, D, []), _, fail)
    ->  (   get_dict(file, D, F)
        ->  atom_string(LEFile, F), Notes = D.notes
        ;   get_dict(error, D, E) -> throw(error(rune_import(E), _))
        ;   throw(error(rune_import("the translation gave no program"), _))
        )
    ;   throw(error(rune_import("the translation stopped without an answer"), _))
    ).

%   The directory of the LE2 this server runs (le_kbs.pl is in it).
le2_home(D) :-
    catch(module_property(le_kbs, file(F)), _, fail), !,
    file_directory_name(F, D).
le2_home(D) :-
    user:file_search_path(le2, D0), atom(D0),
    absolute_file_name(D0, D, [file_type(directory), file_errors(fail)]), !.

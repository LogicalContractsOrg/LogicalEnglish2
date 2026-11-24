/** <module> File ▸ Open of Daml source: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    a `.daml` file, or a zip of a Daml project (its .daml files): the
    project becomes its LE for LPS twin (daml_twin.pl) — templates as
    fluents keyed by contract id, creates and choices as actions, who may do
    what as integrity constraints, its first Daml Script as the scenario
    (further scripts are programs of their own that extend the twin). The
    sources are kept under sources/. Expected final states need Daml itself
    (daml_oracle.pl, a Canton sandbox): an upload gets the twin, not the oracle.
*/

:- module(daml_import, [import_daml/3, detect_daml/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module(daml_syntax).
:- use_module(daml_twin).
:- use_module('../le2_paths', []).
:- use_module(le2(le_migration)).

%!  detect_daml(+Input) is semidet.
%   A file (or a directory holding one) that starts a Daml module.
detect_daml(Input) :- daml_files(Input, [_|_]).

daml_files(Input, Files) :-
    (   exists_directory(Input)
    ->  findall(F, ( directory_member(Input, F, [recursive(true), extensions([daml])]), \+ sub_atom(F, _, _, _, '/.daml/') ), Files0)
    ;   exists_file(Input) -> Files0 = [Input]
    ;   Files0 = []
    ),
    include(daml_source, Files0, Files).

daml_source(F) :-
    read_file_to_string(F, S, [encoding(utf8)]),
    sub_string(S, _, _, _, "module "), !,
    catch(daml_text_module(S, module(_, [_|_])), _, fail).

%!  import_daml(+Input, +OutDir, -Result) is det.
import_daml(Input, OutDir0, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    daml_files(Input, Files),
    (   exists_directory(Input) -> Root = Input ; file_directory_name(Input, Root) ),
    findall(R, ( member(F, Files), relative_file_name(F, Root, R) ), Rels),
    forall(( member(F, Files), relative_file_name(F, Root, R), atomic_list_concat([OutDir, '/sources/', R], D),
             file_directory_name(D, DD) ), ( make_directory_path(DD), copy_file(F, D) )),
    file_base_name(Input, B), file_name_extension(Base0, _, B),
    atomic_list_concat(Ws, '.', Base0), atomic_list_concat(Ws, '_', Base1), downcase_atom(Base1, Id),
    project_migrations(project(Id, Base0, Files), [id(Id), sources(Rels)], Migs),
    findall(LE-N1, ( member(mig(Name, Mig), Migs),
                     write_migration(Mig, OutDir, Name, report(LE, _, counts(E, A, Rs), _)),
                     format(string(N1), "~w: ~w source elements encoded, ~w approximated, ~w residue.", [Name, E, A, Rs]) ), Rs0),
    Rs0 = [LEFile-_|_],
    findall(N, member(_-N, Rs0), Notes0),
    append(Notes0, ["The ids of the contracts a command creates are places of its action: the ledger assigns them, a scenario names them."], Notes).

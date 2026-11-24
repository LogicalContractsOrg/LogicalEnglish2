/** <module> File ▸ Open of an s(CASP) or Prolog program: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    a `.pl`, `.scasp` or `.lp` file: the program becomes its Logical English
    twin (scasp_twin.pl) — templates from its `#pred` annotations (else a
    naive wording), classical negation as opposite forms, abducibles as
    assumable, denials as integrity constraints (`it must not be true that`),
    LE1's scenarios and `?-` queries as scenarios whose expected answers are
    s(CASP)'s own on the source (when library(scasp) is installed), and a
    clause LE cannot state (a list pattern) as a TODO block. The file is
    kept under sources/.
*/

:- module(scasp_import, [import_scasp/3, detect_scasp/1]).

:- use_module(library(lists)).
:- use_module(library(filesex)).
:- use_module(library(aggregate)).
:- use_module(library(process)).
:- use_module(scasp_source).
:- use_module(scasp_twin).
:- use_module(le2(le_migration)).

%!  detect_scasp(+Input) is semidet.
%
%   A file of Prolog clauses (read with s(CASP)'s operators) with at least
%   one clause that is not a directive.
detect_scasp(Input) :-
    exists_file(Input),
    catch(read_source(Input, source(Terms, _, _)), _, fail),
    member(T-_, Terms), \+ T = (:- _), \+ T = '#'(_), \+ T = '$not_scasp'(_, _, _), !.

%!  import_scasp(+Input, +OutDir, -Result) is det.
import_scasp(Input, OutDir0, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    file_base_name(Input, B),
    atomic_list_concat([OutDir, '/sources'], SD), make_directory_path(SD),
    atomic_list_concat([SD, '/', B], Copy), copy_file(Input, Copy),
    scasp_twin:twin_name(Input, Name),
    twin_migration(Input, [name(Name), source_copy(B)], Migration),
    write_migration(Migration, OutDir, Name, report(LEFile, Issues, counts(E, A, R), Fid)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    (   Fid = fidelity(P, F, U, _)
    ->  format(string(N1), "~w: ~w source elements encoded, ~w approximated, ~w residue; ~w writer errors; the source's own answers (s(CASP)): ~w expectations pass, ~w fail, ~w errors.",
               [Name, E, A, R, NE, P, F, U])
    ;   format(string(N1), "~w: ~w source elements encoded, ~w approximated, ~w residue; ~w writer errors.", [Name, E, A, R, NE])
    ),
    le_migration:migration_pending(Migration, migration(_, _, _, Tests)),
    aggregate_all(count, ( member(test(_, _, _, _, Es), Tests), member(pending(_, _), Es) ), NP),
    (   NP =:= 0 -> Notes0 = [N1]
    ;   format(string(N2), "~w expectation(s) are pending, written as comments in their scenarios and not counted above.", [NP]),
        Notes0 = [N1, N2]
    ),
    (   NP > 0, \+ scasp_runs
    ->  append(Notes0, ["s(CASP) is not installed with the SWI-Prolog of this server (pack_install(scasp)): the source's own answers could not be computed, so the scenarios check nothing."], Notes)
    ;   Notes = Notes0
    ).

%   The SWI-Prolog the oracle runs ($SWIPL, else swipl) has library(scasp).
scasp_runs :-
    ( getenv('SWIPL', Swipl) -> Exe = Swipl ; Exe = path(swipl) ),
    catch(( process_create(Exe, ['-q', '-g', 'use_module(library(scasp)),halt(0)', '-t', 'halt(1)'],
                           [stdout(null), stderr(null), process(P)]),
            process_wait(P, exit(0)) ), _, fail).

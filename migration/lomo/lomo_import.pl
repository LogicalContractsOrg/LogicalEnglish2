/** <module> File > Open of a LOMO description: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    a `.ttl` file whose statements use LOMO's words: the description becomes
    its register (lomo_twin.pl), with the libraries it includes beside it
    (lomo.le, lomo.pl, temporal.le, temporal.pl, deontic.le) and the
    description kept under sources/. With the judges installed
    (oracle/setup.sh) the register also gets its scenario of expected
    answers (lomo_gate.pl).

    Copyright Miguel Calejo; Apache License 2.0.
*/

:- module(lomo_import, [import_lomo/3, detect_lomo/1]).

:- use_module(library(lists)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module('../le2_paths', []).
:- use_module(le2(le_migration)).
:- use_module(lomo_twin).
:- use_module(lomo_gate, [gate_tests/2]).

%!  detect_lomo(+Input) is semidet.
detect_lomo(Input) :-
    exists_file(Input),
    setup_call_cleanup(open(Input, read, S, [encoding(utf8)]), read_string(S, 200000, Text), close(S)),
    sub_string(Text, _, _, _, "http://data.europa.eu/leg/lomo"), !.

%!  import_lomo(+Input, +OutDir, -Result) is det.
import_lomo(Input, OutDir0, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    file_base_name(Input, B),
    atomic_list_concat([OutDir, '/sources'], SD), make_directory_path(SD),
    atomic_list_concat([SD, '/', B], Copy),
    ( same_file(Input, Copy) -> true ; copy_file(Input, Copy) ),
    forall(member(L, [lomo, temporal, deontic]), copy_library(L, OutDir)),
    twin_name(Input, Name),
    (   catch(gate_tests(Input, Tests), _, fail) -> true ; Tests = [] ),
    twin_migration(Input, [name(Name), source_copy(B), tests(Tests)], Migration),
    write_migration(Migration, OutDir, Name, report(LEFile, Issues, counts(E, A, R), _)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    format(string(N1), "~w: a register of ~w described things (~w approximated, ~w residue), ~w writer errors. One fact for each statement of the description, in the words of lomo.le; the queries are the questions of LOMO's requirements document. A LOMO description has no conditions: a rule's conditions count as holding until a program writes them, and each answer says so.",
           [Name, E, A, R, NE]),
    Notes = [N1].

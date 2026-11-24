/** <module> File ▸ Open of a LegalRuleML document: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    a `.lrml` file, or an `.xml` whose root is `lrml:LegalRuleML`: the
    document becomes its Logical English twin (lrml_twin.pl) with the deontic
    library beside it, its scenario blocks as scenarios, the document kept
    under sources/. A document of the corpus (corpus.pl) gets the reviewer's
    wording and the drafted scenarios with SPINdle's answers.
*/

:- module(lrml_import, [import_lrml/3, detect_lrml/1]).

:- use_module(library(lists)).
:- use_module(library(filesex)).
:- use_module(library(sgml)).
:- use_module(lrml_twin).
:- use_module(corpus).
:- use_module('../le2_paths', []).
:- use_module(le2(le_migration)).

%!  detect_lrml(+Input) is semidet.
detect_lrml(Input) :-
    exists_file(Input),
    catch(load_xml(Input, DOM, [space(remove)]), _, fail),
    member(element(Root, _, _), DOM), !,
    lrml_reader:local_name(Root, 'LegalRuleML').

%!  import_lrml(+Input, +OutDir, -Result) is det.
import_lrml(Input, OutDir0, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    file_base_name(Input, B),
    atomic_list_concat([OutDir, '/sources'], SD), make_directory_path(SD),
    atomic_list_concat([SD, '/', B], Copy), copy_file(Input, Copy),
    copy_library(deontic, OutDir),
    twin_name(Input, Name),
    (   lrml_example(_, CF, O), file_base_name(CF, B) -> Options = O ; Options = [] ),
    twin_migration(Input, [name(Name), source_copy(B)|Options], Migration),
    write_migration(Migration, OutDir, Name, report(LEFile, Issues, counts(E, A, R), Fid)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    (   Fid = fidelity(P, F, U, _)
    ->  format(string(N1), "~w: ~w source elements encoded, ~w approximated, ~w residue; ~w writer errors; SPINdle's answers on the drafted scenarios: ~w expectations pass, ~w fail, ~w errors.",
               [Name, E, A, R, NE, P, F, U])
    ;   format(string(N1), "~w: ~w source elements encoded, ~w approximated, ~w residue; ~w writer errors. Obligations, permissions and prohibitions are the deontic library's (deontic.le, beside the program).", [Name, E, A, R, NE])
    ),
    Notes = [N1].

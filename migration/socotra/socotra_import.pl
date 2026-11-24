/** <module> File ▸ Open of a Socotra product configuration: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls
    when the editor opens a zip archive (or a folder) holding a classic
    Socotra product configuration — a product folder with
    `policy/policy.json`, exposures, perils and their `.premium.liquid`
    scripts, `taxes/`, `fees.json`, `tables/<table>.csv`, as socotra/product-library
    and Socotra's configuration zips lay them out (`products/<name>/policy/...`
    is found too).

    A lone `.json` is taken when it is a classic configuration's
    `policy.json` or an `exposure.json` (a `fields` list of named, typed
    fields): it holds no rating, so the program declares its fields as the
    facts of a quote, and the note says that the scripts and tables need the
    zipped product folder.

    The translation is the reader's (socotra_reader.pl), as for the product
    library's twins: templates from the fields, rules from the Liquid by
    symbolic execution, the CSV rate tables as decision tables, a quote-desk
    view. A script the reader cannot follow is a residue block — a TODO
    comment with the Liquid verbatim — and the rest is translated. The
    product's files are copied into `sources/<Product>/` beside the program,
    and each rule cites its file and its passage there, so the source viewer
    opens it.

    Quotes. The reference run (oracle.py) needs python3 with python-liquid;
    when it is there, the product's own Liquid prices ten generated quotes
    and they become the scenarios; when it is not (or the run fails), the
    program has no scenarios, and the note and the program's header say that
    the quote scenarios were skipped and why.
*/

:- module(socotra_import, [import_socotra/3, detect_socotra/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(socotra_reader).
:- use_module(socotra_sources).
:- use_module(le2(le_migration)).
:- use_module(le2(le_writer)).

%!  detect_socotra(+Input) is semidet.
detect_socotra(Input) :-
    exists_directory(Input),
    product_dirs(Input, [_|_]), !.
detect_socotra(Input) :-
    exists_file(Input),
    lone_json(Input, _, _), !.

%!  import_socotra(+Input, +OutDir, -Result) is det.
import_socotra(Input, OutDir, Result) :-
    exists_file(Input), lone_json(Input, Kind, J), !,
    %  a lone configuration file: the product folder it belongs in, made
    %  in a scratch directory, translated as a folder would be
    file_name_extension(Stem, _, Input), file_base_name(Stem, Base),
    (   Kind == policy
    ->  ( memberchk(Base, [policy, 'Policy']) -> Name = 'Product' ; Name = Base ),
        Rel = 'policy/policy.json'
    ;   ( get_dict(name, J, EN0), atom_string(EN, EN0), EN \== '' -> true ; EN = Base ),
        Name = 'Product',
        atomic_list_concat(['policy/exposures/', EN, '/exposure.json'], Rel)
    ),
    tmp_file(socotra_json, Tmp),
    atomic_list_concat([Tmp, '/', Name], PD),
    atomic_list_concat([PD, '/', Rel], Dst),
    file_directory_name(Dst, DstDir), make_directory_path(DstDir),
    copy_file(Input, Dst),
    (   Kind == exposure
    ->  atomic_list_concat([PD, '/policy/policy.json'], PJ),
        setup_call_cleanup(open(PJ, write, S), format(S, "{\"fields\": []}~n", []), close(S))
    ;   true
    ),
    file_base_name(Input, InName),
    format(string(Lone), "Only ~w was uploaded (a Socotra ~w configuration file): its fields are declared as the facts of a quote, but it holds no rating, taxes, fees or underwriting. Those are the product folder's Liquid scripts and CSV tables: zip the whole product folder (the one holding policy/policy.json) and open the zip to translate them.",
           [InName, Kind]),
    setup_call_cleanup(
        true,
        import_product(PD, [], OutDir, [declare_fields(true), lone(Lone)], Result),
        catch(delete_directory_and_contents(Tmp), _, true)),
    %  sources/ holds what was uploaded, not the empty policy.json made for it
    (   Kind == exposure
    ->  atomic_list_concat([OutDir, '/sources/', Name, '/policy/policy.json'], Made),
        catch(delete_file(Made), _, true)
    ;   true
    ).
import_socotra(Input, OutDir, Result) :-
    (   exists_directory(Input), product_dirs(Input, [PD|Others])
    ->  import_product(PD, Others, OutDir, [], Result)
    ;   throw(error(format("no Socotra product configuration (a folder with policy/policy.json, or a policy.json or exposure.json) in the upload", []), _))
    ).

%   A classic configuration's policy.json or exposure.json: an object with
%   a list of fields, each named and typed; policy.json by its name or its
%   policy-level keys, exposure.json by its name or a `name` of its own.
lone_json(File, Kind, J) :-
    file_name_extension(_, Ext0, File), downcase_atom(Ext0, json),
    catch(socotra_reader:read_json(File, J), _, fail),
    is_dict(J),
    get_dict(fields, J, Fields), is_list(Fields),
    forall(member(F, Fields), ( is_dict(F), get_dict(name, F, _), get_dict(type, F, _) )),
    file_base_name(File, B), downcase_atom(B, LB),
    (   ( LB == 'policy.json'
        ; member(K, [documents, paymentSchedules, defaultPaymentTerms, lapse, invoicing]), get_dict(K, J, _)
        )
    ->  Kind = policy
    ;   ( LB == 'exposure.json' ; get_dict(name, J, _) )
    ->  Kind = exposure
    ), !.

import_product(PD, Others, OutDir0, Options, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    file_base_name(PD, Name),
    file_directory_name(PD, Root),
    socotra_reader:id_words(Name, Ws), atomic_list_concat(Ws, '_', Slug0),
    ( Slug0 == '' -> Slug = product ; Slug = Slug0 ),
    atomic_list_concat([OutDir, '/quotes.json'], Quotes),
    (   memberchk(lone(_), Options) -> Outcome = lone ; quotes_run(PD, Quotes, Outcome) ),
    (   Outcome == lone
    ->  write_empty_quotes(Quotes), QuoteNote = [], Skipped = none
    ;   Outcome == ok
    ->  QuoteNote = ["The quote scenarios are the product's own Liquid run on ten generated quotes (oracle.py)."],
        Skipped = none
    ;   write_empty_quotes(Quotes),
        Outcome = skipped(Why),
        format(string(QN), "Quote scenarios skipped: ~w. The program has no scenarios, so nothing checks its rules against the product's Liquid; state a quote in the Scenario Editor to run it.", [Why]),
        QuoteNote = [QN], Skipped = Why
    ),
    setup_call_cleanup(
        ( set_display_root(Root), set_source_documents(local) ),
        ( product_migration(PD, Quotes, Options, M0),
          retitle(M0, Name, Skipped, M1a),
          ( memberchk(lone(_), Options) -> drop_idle_view(M1a, M1) ; M1 = M1a ),
          M1 = migration(_, program(Header, _), _, _),
          ( memberchk(includes(Libs), Header) -> forall(member(L, Libs), copy_library(L, OutDir)) ; true ),
          socotra_reader:copy_tables(PD, OutDir),
          copy_sources(PD, Root, OutDir),
          socotra_reader:render_answers(OutDir, M1, M),
          write_migration(M, OutDir, Slug, Report) ),
        ( set_display_root(none), socotra_sources:retractall(mode(_)) )),
    Report = report(LEFile, Issues, counts(E, A, R), Fid),
    include(is_error, Issues, Errs), length(Errs, NE),
    (   R > 0
    ->  format(string(N1), "~w: ~w ledger elements encoded, ~w approximated, ~w residue (each a TODO block with its Liquid); ~w writer errors.",
               [Name, E, A, R, NE])
    ;   format(string(N1), "~w: ~w ledger elements encoded, ~w approximated, no residue; ~w writer errors.",
               [Name, E, A, NE])
    ),
    (   Fid = fidelity(P, F, U, _)
    ->  format(string(N2), "The quotes' expectations: ~w pass, ~w fail, ~w errors.", [P, F, U]), FNotes = [N2]
    ;   FNotes = []
    ),
    (   Others == [] -> ONotes = []
    ;   maplist([D, B]>>file_base_name(D, B), Others, OBs),
        atomic_list_concat(OBs, ', ', OT),
        format(string(N3), "The upload holds more products, not translated here (open each on its own): ~w.", [OT]),
        ONotes = [N3]
    ),
    (   memberchk(lone(Lone), Options)
    ->  LNotes = [Lone],
        format(string(N4), "The uploaded file is copied into sources/~w/ beside the program; File > Show the Original lists it.", [Name])
    ;   LNotes = [],
        format(string(N4), "The product's Liquid, JSON and CSV files are copied into sources/~w/ beside the program (File > Show the Original lists them); every rule cites its file and passage there.", [Name])
    ),
    append([[N1], LNotes, QuoteNote, FNotes, [N4], ONotes], Notes).

is_error(issue(error, _, _)).

%   The product folders below Input (Input itself included): those with
%   policy/policy.json, at most three levels down, in name order.
product_dirs(Input, Dirs) :-
    findall(D, ( product_dir(Input, 0, D) ), Ds0),
    sort(Ds0, Dirs).

product_dir(D, _, D) :-
    atomic_list_concat([D, '/policy/policy.json'], P), exists_file(P).
product_dir(D, Depth, P) :-
    Depth < 3,
    \+ ( atomic_list_concat([D, '/policy/policy.json'], F), exists_file(F) ),
    directory_files(D, Es),
    member(E, Es), \+ sub_atom(E, 0, _, _, '.'), E \== '__MACOSX',
    atomic_list_concat([D, '/', E], Sub), exists_directory(Sub),
    Depth1 is Depth + 1,
    product_dir(Sub, Depth1, P).

%   The reference run, or why it did not run: python3 missing, python-liquid
%   missing, or the run itself failing (its last error line).
quotes_run(PD, Quotes, Outcome) :-
    (   \+ exe_on_path(python3)
    ->  Outcome = skipped("the reference run of the product's Liquid needs python3, which is not installed on this server")
    ;   \+ catch(python_ok(['-c', 'import liquid']), _, fail)
    ->  Outcome = skipped("the reference run of the product's Liquid needs the python-liquid package (pip install python-liquid), which this server's python3 lacks")
    ;   catch(run_oracle(PD, Quotes, Status, Err), E, ( format(string(Err), "~q", [E]), Status = error ))
    ->  (   Status == exit(0), exists_file(Quotes)
        ->  Outcome = ok
        ;   last_line(Err, Line),
            format(string(Why), "the reference run of the product's Liquid (oracle.py) failed: ~w", [Line]),
            Outcome = skipped(Why)
        )
    ;   Outcome = skipped("the reference run of the product's Liquid (oracle.py) could not be started")
    ).

exe_on_path(Exe) :- absolute_file_name(path(Exe), _, [access(execute), file_errors(fail)]).

python_ok(Args) :-
    process_create(path(python3), Args, [stdout(null), stderr(null), process(Pid)]),
    process_wait(Pid, exit(0)).

run_oracle(PD, Quotes, Status, Err) :-
    socotra_reader:socotra_home(H), atomic_list_concat([H, '/oracle.py'], Py),
    process_create(path(python3), [Py, PD, Quotes, '--max-cases', '10'],
                   [stdout(null), stderr(pipe(E)), process(Pid)]),
    read_string(E, _, Err), close(E),
    process_wait(Pid, Status).

last_line(Err, Line) :-
    split_string(Err, "\n", " \r\t", Ls0), exclude(==(""), Ls0, Ls),
    (   last(Ls, L) -> Line = L ; Line = "no error output" ).

%   A lone configuration file's program has no queries: its quote desk,
%   whose result is a query, would name one that does not exist.
drop_idle_view(migration(Meta, program(H, Items0), L, T), migration(Meta, program(H, Items), L, T)) :-
    (   memberchk(query(_, _), Items0) -> Items = Items0
    ;   exclude([I]>>( I = view(_, _) ), Items0, Items)
    ).

write_empty_quotes(F) :-
    setup_call_cleanup(open(F, write, S), format(S, "{\"cases\": []}~n", []), close(S)).

%   The header and ledger metadata of an import (not the product library's).
retitle(migration(Meta0, program(H0, Items), Ledger, Tests), Name, Skipped, migration(Meta, program(H, Items), Ledger, Tests)) :-
    get_time(Now), format_time(atom(Date), '%Y-%m-%d', Now),
    (   select(kb(KB), H0, _) -> true ; KB = Name ),
    (   Skipped == none -> SC = ""
    ;   format(string(SC), "~nNo quote scenarios: ~w.", [Skipped])
    ),
    format(string(C), "~w: a Logical English twin of the Socotra product configuration \"~w\",~nimported with File > Open and translated by the Logical English translator for Socotra (~w).~nEvery rule cites the source file it comes from (copied into sources/~w/ beside this program) and its passage there;~na script the translator cannot follow is kept as a TODO block with its Liquid.~w", [KB, Name, Date, Name, SC]),
    maplist(header_comment(C), H0, H),
    exclude([X]>>( X = source(_) ; X = licence(_) ; X = date(_) ), Meta0, Meta1),
    append(Meta1, [source('an imported Socotra product configuration'), date(Date)], Meta).

header_comment(C, comment(_), comment(C)) :- !.
header_comment(_, X, X).

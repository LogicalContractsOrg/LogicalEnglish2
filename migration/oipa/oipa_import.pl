/** <module> File ▸ Open of an OIPA transaction: the importer adapter

    The adapter LE2's importer registry (le_import.pl, importer/6) calls for
    an `.xml` whose root is an OIPA `<Transaction>` with a Math or Fields
    section (the Rules Palette's export of one transaction), or for a `.zip`
    (extracted by le_import into a folder) of a plan directory — one
    directory per transaction, `Transaction.xml` with its attached rules
    (`ValidateExpressions.xml`, `SpawnActivities.xml`,
    `CopyToPolicyFields.xml`), and the plan's `Rates.csv` / `PlanFields.csv`
    — or of one transaction's directory.

    The transaction becomes its Logical English twin (oipa_twin.pl), laid
    out as the example twins are: the XML in `sources/<Transaction>/`, the
    plan's CSV files in `sources/`, so that the rules' citations
    (`sources/<Transaction>/Transaction.xml`) open. The attached rules and
    the plan's CSV files are read when they sit beside the transaction (in
    a zipped folder); a lone `.xml` upload has none, and the note says what
    was read and what was not, and what that leaves out. A folder with
    several transactions translates the first (in name order) and names the
    others.
*/

:- module(oipa_import, [import_oipa/3, detect_oipa/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(sgml)).
:- use_module(oipa_reader).
:- use_module(oipa_twin).
:- use_module('../le2_paths', []).
:- use_module(le2(le_migration)).

attached_file('ValidateExpressions.xml').
attached_file('SpawnActivities.xml').
attached_file('CopyToPolicyFields.xml').

plan_file('Rates.csv').
plan_file('PlanFields.csv').

%!  detect_oipa(+Input) is semidet.
detect_oipa(Input) :-
    exists_file(Input), !,
    transaction_xml(Input, _).
detect_oipa(Input) :-
    exists_directory(Input),
    transaction_files(Input, [_|_]), !.

%   An OIPA transaction: root <Transaction> with a Math or Fields section.
transaction_xml(File, Root) :-
    file_name_extension(_, Ext, File), downcase_atom(Ext, xml),
    catch(load_xml(File, DOM, [space(remove)]), _, fail),
    member(Root, DOM), Root = element('Transaction', _, C), !,
    member(element(E, _, _), C), memberchk(E, ['Math', 'Fields']), !.

%   The transactions below a folder (itself included), at most three
%   levels down, in name order: its XML files whose root is a transaction.
transaction_files(Dir, Files) :-
    findall(F, transaction_file(Dir, 0, F), Fs0),
    sort(Fs0, Files).

transaction_file(D, Depth, F) :-
    directory_files(D, Es0), msort(Es0, Es),
    member(E, Es), \+ sub_atom(E, 0, _, _, '.'), E \== '__MACOSX',
    atomic_list_concat([D, '/', E], P),
    (   exists_file(P)
    ->  \+ attached_file(E), transaction_xml(P, _), F = P
    ;   exists_directory(P), Depth < 3,
        Depth1 is Depth + 1,
        transaction_file(P, Depth1, F)
    ).

%!  import_oipa(+Input, +OutDir, -Result) is det.
import_oipa(Input, OutDir0, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    (   exists_directory(Input)
    ->  (   transaction_files(Input, [TF|Others]) -> true
        ;   throw(error(format("no OIPA transaction (an .xml whose root is <Transaction>) in the upload", []), _))
        ),
        Upload = folder(Input)
    ;   TF = Input, Others = [], Upload = file
    ),
    file_directory_name(TF, SrcDir),
    transaction_name(Upload, TF, TN),
    plan_name(Upload, SrcDir, PlanName, CsvDirs),
    %  a plan directory of OIPA's layout, in a scratch directory
    tmp_file(oipa_plan, Tmp),
    atomic_list_concat([Tmp, '/', PlanName], PlanDir),
    atomic_list_concat([PlanDir, '/', TN], TD), make_directory_path(TD),
    atomic_list_concat([TD, '/Transaction.xml'], Copy), copy_file(TF, Copy),
    findall(A, ( attached_file(A), atomic_list_concat([SrcDir, '/', A], S), exists_file(S),
                 atomic_list_concat([TD, '/', A], D), copy_file(S, D) ), Attached),
    findall(P, ( plan_file(P), member(CD, CsvDirs), atomic_list_concat([CD, '/', P], S), exists_file(S),
                 atomic_list_concat([PlanDir, '/', P], D), \+ exists_file(D), copy_file(S, D) ), PlanFiles0),
    sort(PlanFiles0, PlanFiles),
    setup_call_cleanup(
        true,
        translate(PlanDir, TD, TN, OutDir, report(LEFile, Issues, counts(E, Ap, R), _), Name),
        catch(delete_directory_and_contents(Tmp), _, true)),
    include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE),
    (   R > 0
    ->  format(string(N1), "~w: ~w MathVariables and rules encoded, ~w approximated, ~w residue (each a % RESIDUE block with its XML); ~w writer errors.", [Name, E, Ap, R, NE])
    ;   format(string(N1), "~w: ~w MathVariables and rules encoded, ~w approximated, no residue; ~w writer errors.", [Name, E, Ap, NE])
    ),
    read_note(Upload, TN, Attached, PlanFiles, N2),
    format(string(N3), "The XML is kept in sources/~w/ (the plan's CSV files in sources/), where the rules' citations point; File > Show the Original lists it.", [TN]),
    (   Others == [] -> ONotes = []
    ;   maplist(other_name, Others, OBs), atomic_list_concat(OBs, ', ', OT),
        format(string(N4), "The upload holds more transactions, not translated here: ~w. Zip each transaction's folder with the plan's Rates.csv and PlanFields.csv to translate it.", [OT]),
        ONotes = [N4]
    ),
    append([[N1, N2, N3], ONotes], Notes).

translate(PlanDir, TD, TN, OutDir, Report, Name) :-
    read_transaction(TD, T),
    copy_library(temporal, OutDir),
    transaction_migration(PlanDir, T, [], Migration),
    oipa_twin:write_rate_tables(PlanDir, T, OutDir),
    oipa_twin:copy_sources(PlanDir, TN, OutDir),
    Migration = migration(Meta, _, _, _),
    memberchk(program(Name), Meta),
    write_migration(Migration, OutDir, Name, Report).

%   What was read beside the transaction, and what its absence leaves out.
read_note(Upload, TN, Attached, PlanFiles, Note) :-
    findall(A, ( attached_file(A), \+ memberchk(A, Attached) ), MissingA),
    findall(P, ( plan_file(P), \+ memberchk(P, PlanFiles) ), MissingP),
    append([['Transaction.xml'], Attached, PlanFiles], Read),
    atomic_list_concat(Read, ', ', RT),
    (   MissingA == [], MissingP == []
    ->  format(string(Note), "Read: ~w.", [RT])
    ;   append(MissingA, MissingP, Missing), atomic_list_concat(Missing, ', ', MT),
        findall(W, ( member(A-W, ['ValidateExpressions.xml'-"no checks",
                                  'SpawnActivities.xml'-"no spawns",
                                  'CopyToPolicyFields.xml'-"no copies to policy fields",
                                  'Rates.csv'-"each rate table is empty, so a RATE gives its DEFAULT or no value",
                                  'PlanFields.csv'-"each plan field is its MathVariable's DEFAULT or has no value"]),
                     memberchk(A, Missing) ), Ws),
        atomic_list_concat(Ws, '; ', WT),
        (   Upload == file
        ->  format(string(Note), "Read: ~w. Not found beside the uploaded XML file (an upload of one file has nothing beside it), so not read: ~w — hence ~w. To have them read, zip the plan's folder (~w/ with its attached rules, and Rates.csv and PlanFields.csv) and open the zip.", [RT, MT, WT, TN])
        ;   MissingP == []
        ->  format(string(Note), "Read: ~w. The upload has no ~w for this transaction — hence ~w.", [RT, MT, WT])
        ;   format(string(Note), "Read: ~w. The upload has no ~w for this transaction — hence ~w. Zip the plan's folder with its Rates.csv and PlanFields.csv to have the plan's rates and fields read.", [RT, MT, WT])
        )
    ).

%   The transaction's name: its file's, or its folder's for a Transaction.xml
%   in an uploaded folder; a lone Transaction.xml upload has neither, and
%   takes the name its XML gives (a NAME attribute), else Transaction.
transaction_name(Upload, TF, TN) :-
    file_base_name(TF, B), file_name_extension(TN0, _, B),
    (   TN0 \== 'Transaction'
    ->  TN = TN0
    ;   Upload = folder(_), file_directory_name(TF, D), file_base_name(D, DN), DN \== ''
    ->  TN = DN
    ;   transaction_xml(TF, element(_, Attrs, _)),
        member(K, ['NAME', 'Name', 'TRANSACTIONNAME', 'TransactionName']), memberchk(K=N0, Attrs),
        atom_codes(N0, Cs), include([C]>>code_type(C, csym), Cs, Cs1), Cs1 \== []
    ->  atom_codes(TN, Cs1)
    ;   TN = 'Transaction'
    ).

%   The plan: the folder holding the transaction's folder, when the upload
%   contains it (its name, its CSV files); else `oipa`, with CSV files only
%   beside the transaction itself.
plan_name(folder(Input), SrcDir, PlanName, [SrcDir, PlanDir]) :-
    file_directory_name(SrcDir, PlanDir),
    SrcDir \== Input,
    atom_concat(Input, _, PlanDir), !,
    file_base_name(PlanDir, PN0),
    ( PN0 == '' -> PlanName = oipa ; PlanName = PN0 ).
plan_name(file, SrcDir, oipa, [SrcDir, PlanDir]) :-
    %  a Transaction.xml in its plan's layout, opened where it lies
    file_directory_name(SrcDir, PlanDir), !.
plan_name(_, SrcDir, oipa, [SrcDir]).

other_name(F, N) :-
    file_directory_name(F, D), file_base_name(D, DN), file_base_name(F, B),
    ( B == 'Transaction.xml' -> N = DN ; file_name_extension(N, _, B) ).

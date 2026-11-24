/*  Opening Rune in the LE editor (the design notes rune.md §13, step 1): the
    child process of rune_import.pl, which the editor's File ▸ Open calls.

    ./myswipl.sh -q migration/rune/rune_import_run.pl -- <file.rosetta | folder> <out dir>

    Prints, last, one line of JSON: {"file": <the main .le>, "notes": [...]}
    (or {"error": ...}).

    Where the model comes from. A Rune file is never alone: its types,
    enumerations and functions come from the namespaces it imports. The
    model is DRR 7.14.0 with the CDM 6.29 it builds on, from ISDA's public
    Maven repository (fetch_sources.sh puts it in .cache/drr). The uploaded
    files are laid over it: a file of the same name as one of DRR's replaces
    it, any other is added; the whole is read again by rosetta2json.

    What is written:
    - an upload of DRR's own files, unchanged, that declares a report: the
      prebuilt twin of that report (examples/migration/rune/<twin>/),
      copied: the three files of its rules, the library, and the scenarios
      of DRR's test pack;
    - otherwise the twin is built: for a file that declares a report, the
      twin of the report (its first one) with the scenarios of DRR's test
      pack when DRR has one; for a file without a report (functions, rules),
      the twin of its namespace's rules and functions. In both, the main
      file holds the upload's own namespaces; DRR's other namespaces and
      the CDM are the two files it includes, in Logical English, so that an
      explanation goes all the way down.
*/
:- use_module('../le2_paths', []).
:- use_module(parser/rune_reader).
:- use_module(rune_paths).
:- use_module(rune_twin).
:- use_module(library(main)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(filesex)).
:- use_module(library(process)).

%  build.pl's writers (it is a script: its own `main` is replaced by ours)
:- consult(build).

:- initialization(main, main).

main([Input, Out]) :-
    catch(import(Input, Out, File, Notes), E, ( message_to_codes(E, Msg), reply(_{error: Msg}), halt(1) )),
    reply(_{file: File, notes: Notes}).

message_to_codes(E, S) :- ( E = rune_import(M) -> S = M ; message_to_codes_(E, S) ).
message_to_codes_(E, S) :- catch(message_to_codes(E, [], Cs), _, fail), !, string_codes(S, Cs).
message_to_codes_(E, S) :- term_string(E, S).

reply(D) :- with_output_to(string(S), json_write_dict(current_output, D, [width(0)])), format("~n~w~n", [S]).

import(Input, Out, File, Notes) :-
    rosetta_files(Input, Fs),
    ( Fs == [] -> throw(rune_import("no Rune file (.rosetta) in the upload")) ; true ),
    drr_dir(D), directory_file_path(D, 'drr/rosetta', DRRRosetta),
    partition(unchanged_drr_file(DRRRosetta), Fs, Same, Changed),
    (   Changed == [], \+ upload_test_pack_dir(Input, _),
        declared_reports(Same, DRRRosetta, [R|More]), report_pack(R, _, Twin),
        twins_dir(TD), directory_file_path(TD, Twin, TwinDir), exists_directory(TwinDir)
    ->  copy_twin(TwinDir, Out),
        directory_file_path(Out, Twin, F0), file_name_extension(F0, le, File),
        prebuilt_notes(R, Twin, More, TwinDir, Notes)
    ;   build_twin(Input, Fs, DRRRosetta, Out, File, Notes)
    ).

%   The upload's folder, when it holds a test pack of its own (a
%   `test-pack-*.json` with its pipeline, in Rune's format: rune_paths.pl,
%   report_test_pack/3).
upload_test_pack_dir(Input, Input) :-
    exists_directory(Input),
    directory_member(Input, F, [extensions([json]), recursive(true)]),
    file_base_name(F, B), sub_atom(B, 0, _, _, 'test-pack-'), !.

%   The .rosetta files of the upload: the file, or those under the folder an
%   archive was extracted into.
rosetta_files(Input, Fs) :-
    (   exists_directory(Input)
    ->  findall(F, directory_member(Input, F, [extensions([rosetta]), recursive(true)]), Fs0), msort(Fs0, Fs)
    ;   file_name_extension(_, rosetta, Input) -> Fs = [Input]
    ;   Fs = []
    ).

unchanged_drr_file(DRRRosetta, F) :-
    file_base_name(F, B), directory_file_path(DRRRosetta, B, Orig), exists_file(Orig),
    read_file_to_string(F, T1, []), read_file_to_string(Orig, T2, []),
    normalize_space(string(N1), T1), normalize_space(string(N2), T2), N1 == N2.

%   The reports a DRR file declares, in its order (`report CFTC Part43 in
%   T+1 ...`), by their names in the model.
declared_reports(Fs, _, Rs) :-
    findall(R, ( member(F, Fs), read_file_to_string(F, T, []), split_string(T, "\n", "", Ls),
                 member(L, Ls), split_string(L, " ", " \t", ["report"|Ws0]),
                 append(Ws, ["in"|_], Ws0), atomic_list_concat(Ws, ' ', R) ), Rs0),
    list_to_set(Rs0, Rs).

copy_twin(TwinDir, Out) :-
    make_directory_path(Out),
    directory_files(TwinDir, Fs),
    forall(( member(F, Fs), \+ sub_atom(F, 0, _, _, '.'),
             ( file_name_extension(_, le, F) ; file_name_extension(_, pl, F) ; file_name_extension(_, md, F) ),
             \+ sub_atom(F, 0, _, _, back_) ),
           ( directory_file_path(TwinDir, F, From), directory_file_path(Out, F, To), copy_file(From, To) )).

prebuilt_notes(R, Twin, More, TwinDir, Notes) :-
    directory_file_path(TwinDir, Twin, F0), atom_concat(F0, '.ledger.md', LF),
    (   exists_file(LF), read_file_to_string(LF, LT, []),
        sub_string(LT, B, _, _, "counts("), sub_string(LT, B, _, A0, Rest0), sub_string(Rest0, 7, _, 0, Rest),
        sub_string(Rest, E, 1, _, ")"), sub_string(Rest, 0, E, _, Nums), A0 >= 0,
        split_string(Nums, ",", " ", [EN, AN, RN])
    ->  format(string(C), "~w definitions encoded, ~w approximated, ~w residue.", [EN, AN, RN])
    ;   C = ""
    ),
    format(string(N1), "~w (DRR 7.14.0), translated from ISDA's Rune into Logical English: this file holds the report's own rules and its fields; ~w_drr.le the rules of DRR's other namespaces it uses, and ~w_cdm.le those of the Common Domain Model, both included, so that an explanation goes down to the CDM. ~w", [R, Twin, Twin, C]),
    N2 = "The scenarios of DRR's own test pack are beside it, one file per group (rates, credit, ...), each instruction with the values of DRR's expected report: Misc > Run the Program's Tests on one of them.",
    N3 = "DRR is ISDA's, under the ISDA DRR License (September 2023): this translation is not to be published.",
    (   More == [] -> Ns = [N1, N2, N3]
    ;   atomic_list_concat(More, ', ', MT),
        format(string(N4), "The file also declares ~w; to open it, upload the file again after removing the other report's declaration, or open its twin in the examples.", [MT]),
        Ns = [N1, N2, N3, N4]
    ),
    Notes = Ns.

% ---------------------------------------------------------------- building

build_twin(Input, Fs, DRRRosetta, Out, File, Notes) :-
    %  the model: DRR's files with the upload over them, read again
    tmp_file(rune_import, Tmp), directory_file_path(Tmp, rosetta, RD), directory_file_path(Tmp, json, JD),
    make_directory_path(RD),
    directory_files(DRRRosetta, Ds),
    forall(( member(D, Ds), file_name_extension(_, rosetta, D) ),
           ( directory_file_path(DRRRosetta, D, From), directory_file_path(RD, D, To), copy_file(From, To) )),
    forall(member(F, Fs), ( file_base_name(F, B), directory_file_path(RD, B, To), copy_file(F, To) )),
    rune_home(H), directory_file_path(H, 'parser/rosetta2json.py', R2J),
    process_create(path(python3), [R2J, RD, JD], [stdout(null), stderr(null), process(P)]),
    process_wait(P, _),
    load_rune_model(JD),
    %  the upload's namespaces, and the reports they declare
    findall(NS, ( member(F, Fs), file_namespace(F, NS) ), NSs0), sort(NSs0, NSs),
    (   NSs == [] -> throw(rune_import("the file declares no namespace")) ; true ),
    findall(R, ( rune_model:rune_report(R, _, _, _, _, RT), q_namespace_(RT, RNS), memberchk(RNS, NSs) ), Rs),
    make_directory_path(Out),
    (   Rs = [R|More]
    ->  ( report_pack(R, Pack, Twin) -> true ; report_twin_name(R, Twin), Pack = none ),
        nb_setval(rune_report, R),
        report_twin_layers(R, [], twin(Layers, Ledger, Fields)),
        write_rules(R, Twin, Out, Layers, Ledger),
        (   upload_test_pack_dir(Input, UD), test_pack_in(R, UD, Pairs), Pairs \== []
        ->  write_scenarios(R, Twin, Out, Fields, Pairs, NG),
            length(Pairs, NP),
            format(string(SN), "~w files of scenarios beside it, from the upload's own test pack (~w samples, read from its pipeline and test-pack files): each input with the values of the report it expects.", [NG, NP])
        ;   (   Pack \== none -> test_pack_pairs(Pack, Pairs) ; report_test_pack(R, [], Pairs) ),
            Pairs \== []
        ->  write_scenarios(R, Twin, Out, Fields, Pairs, NG),
            format(string(SN), "~w files of scenarios beside it, from DRR's test pack: each instruction with the values of DRR's expected report (for the report as DRR wrote it: a rule changed in the upload may change the answers).", [NG])
        ;   SN = "No test pack for this report (neither in the upload nor in DRR): no scenarios."
        ),
        Title = R
    ;   last(NSs, NS1), atomic_list_concat(Ps, '.', NS1), atomic_list_concat(Ps, '_', Twin),
        namespace_twin(NSs, [], twin(Layers, Ledger, _)),
        atomic_list_concat(NSs, ', ', Title),
        write_rules(Title, Twin, Out, Layers, Ledger),
        More = [], SN = "A file without a report: its rules and functions, with no scenarios."
    ),
    directory_file_path(Out, Twin, F0), file_name_extension(F0, le, File),
    ledger_counts(Ledger, counts(E, A, Res)),
    atomic_list_concat(NSs, ', ', NST),
    format(string(N1), "~w, translated from Rune into Logical English: this file holds the upload's own namespaces (~w); ~w_drr.le the rules of DRR's other namespaces it uses and ~w_cdm.le those of the Common Domain Model, both included. ~w definitions encoded, ~w approximated, ~w residue (a definition the translator cannot write yet, kept as a TODO block with its Rune).", [Title, NST, Twin, Twin, E, A, Res]),
    N3 = "The model is DRR 7.14.0 with the CDM 6.29, with the uploaded files laid over it (a file of the same name as one of DRR's replaces it).",
    (   More == [] -> Extra = []
    ;   atomic_list_concat(More, ', ', MT), format(string(N4), "The file also declares ~w: this program is the twin of the first report only.", [MT]), Extra = [N4]
    ),
    append([N1, SN, N3], Extra, Notes),
    delete_directory_and_contents(Tmp).

file_namespace(F, NS) :-
    read_file_to_string(F, T, []), split_string(T, "\n", "", Ls),
    member(L, Ls), split_string(L, " :", " :\t", ["namespace", NS0|_]), NS0 \== "", !, atom_string(NS, NS0).

q_namespace_(Q, NS) :- atomic_list_concat(Ps, '.', Q), append(NSPs, [_], Ps), atomic_list_concat(NSPs, '.', NS).

report_twin_name(R, Twin) :-
    downcase_atom(R, L), atomic_list_concat(Ws, ' ', L), atomic_list_concat(Ws, '_', Twin).

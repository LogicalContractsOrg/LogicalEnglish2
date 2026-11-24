:- module(rune_paths, [
    rune_home/1,            % -Dir: migration/rune
    json_dir/1,             % -Dir: rosetta2json's output for DRR 7.14.0
    drr_dir/1,              % -Dir: DRR's archive, unpacked
    twins_dir/1,            % -Dir: examples/migration/rune of the private place (le2_paths:private_root/1)
    twin_sources/1,         % +Twin: its Rune files into <twin>/sources/ (twin_sources.py)
    report_pack/3,          % ?Report, ?Pack, ?Twin: DRR's 28 reports, their test pack, their twin
    test_pack_pairs/2,      % +Pack, -[pair(Name, Input, Expected)]
    report_test_pack/3,     % +Report, +Dirs, -[pair(Name, Input, Expected)]: from test-pack configs
    test_pack_in/3,         % +Report, +Dir, -Pairs: the test pack of Report in Dir alone
    expected_flat/2         % +ExpectedJson, -[Path-Value]
]).
/** <module> Where the Rune door keeps things, and DRR's test packs

The test pack is DRR's own (rune.md §5): for a report (`cftc-part45`), each
expected report under `regulatory-reporting/output/.../<report>/<group>/<name>.json`
and the instruction it was computed from, under
`enrich/output/.../<group>/<name>.json`.
*/

:- use_module(library(json)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(process)).
:- use_module(library(pairs)).
:- use_module(library(filesex)).
:- use_module('../le2_paths', []).

rune_home(D) :-
    source_file(rune_paths:rune_home(_), F), file_directory_name(F, D).

json_dir(D) :- rune_home(H), directory_file_path(H, '.cache/json', D).
drr_dir(D) :- rune_home(H), directory_file_path(H, '.cache/drr', D).
%   The Rune files a twin was translated from, copied into its sources/ by
%   twin_sources.py from the namespaces its ledger names.
twin_sources(Twin) :-
    rune_home(H), directory_file_path(H, 'twin_sources.py', Py),
    catch(( process_create(path(python3), [Py, Twin], [process(P)]), process_wait(P, _) ),
          E, print_message(warning, E)).

%   The folder, whether or not it exists. DRR is ISDA's, under a licence
%   that does not let a changed copy be published, so its twins are never
%   written into this repository: they go to the private place
%   (../le2_paths.pl, private_root/1). A server has no prebuilt twins, and an
%   import then builds the twin (rune_import_run.pl) instead of failing here.
twins_dir(D) :-
    le2_paths:private_root(R),
    directory_file_path(R, 'examples/migration/rune', D).

pack('fpml-record-keeping-to-reportable-event/transaction-report-instruction-test-pack-default').

%!  test_pack_pairs(+Pack, -Pairs) is det.
%
%   Pairs: pair(Name, InputFile, ExpectedFile), Name the scenario's name
%   (`rates_ir_ccs_fixed_fixed_ex01`), sorted by group and file: the test
%   pack of the DRR report whose pack is Pack (report_pack/3), read from DRR's
%   test-pack configuration (report_test_pack/3), then the instructions of
%   the CSA chain (csa_chain.pl) with DRR's reports of them (chain.sh).
test_pack_pairs(Pack, Pairs) :-
    (   report_pack(Report, Pack, _)
    ->  report_test_pack(Report, [], Pairs0)
    ;   Pairs0 = []
    ),
    rune_home(H),
    format(atom(CE), '~w/.cache/chain/output/~w', [H, Pack]),
    format(atom(CI), '~w/.cache/chain/input', [H]),
    (   exists_directory(CE)
    ->  root_pairs(CE, CI, Chain), append(Pairs0, Chain, Pairs)
    ;   Pairs = Pairs0
    ).

%!  report_test_pack(+Report, +Dirs, -Pairs) is det.
%
%   The test pack of a report, as Rune's tooling describes one
%   (com.regnosys.rosetta.common.transform: PipelineModel, TestPackModel):
%   a `pipeline-*.json` names a transform, of type REPORT, its function and
%   its input and output types; a `test-pack-*.json` names its pipeline and
%   lists samples, each an `inputPath` and the `outputPath` of the report
%   expected for it, relative to the root of the model's resources. The
%   pipelines of Report are those whose output type is the report's type
%   (when the model is loaded) or whose function is the report's own
%   (`CFTC Part45` -> `...CFTCPart45ReportFunction`, as Rune names it).
%   Dirs are searched first, in order (an upload's own folder: a model of
%   one's own with its test pack), then DRR's configuration
%   (`regulatory-reporting/config`); the first with samples for the report
%   gives them. A sample's group is the folder of its expected report
%   (`rates`), which with the file names the scenario, as before.
report_test_pack(Report, Dirs, Pairs) :-
    drr_dir(D),
    directory_file_path(D, 'regulatory-reporting/config', DC),
    append(Dirs, [DC], All),
    (   member(Dir, All), exists_directory(Dir),
        dir_pairs(Report, Dir, Pairs0), Pairs0 \== []
    ->  Pairs = Pairs0
    ;   Pairs = []
    ).

%!  test_pack_in(+Report, +Dir, -Pairs) is det.
%
%   The samples for Report of the test-pack configuration under Dir alone
%   (an upload's own test pack), or [].
test_pack_in(Report, Dir, Pairs) :-
    (   exists_directory(Dir) -> dir_pairs(Report, Dir, Pairs) ; Pairs = [] ).

dir_pairs(Report, Dir, Pairs) :-
    findall(F, ( directory_member(Dir, F, [extensions([json]), recursive(true)]),
                 file_base_name(F, B), sub_atom(B, 0, _, _, 'pipeline-') ), PFs),
    findall(Id, ( member(F, PFs), json_file(F, P),
                  get_dict(transform, P, T), get_dict(type, T, "REPORT"),
                  report_transform(Report, T),
                  get_dict(id, P, Id) ), Ids),
    findall(F, ( directory_member(Dir, F, [extensions([json]), recursive(true)]),
                 file_base_name(F, B), sub_atom(B, 0, _, _, 'test-pack-') ), TFs),
    findall(G-(Base-pair(Name, In, Exp)),
            ( member(F, TFs), json_file(F, TP),
              get_dict(pipelineId, TP, PId), memberchk(PId, Ids),
              get_dict(samples, TP, Ss), member(S, Ss),
              get_dict(inputPath, S, IP), get_dict(outputPath, S, OP),
              file_directory_name(F, FD), sample_file(FD, OP, Exp), sample_file(FD, IP, In),
              file_directory_name(Exp, GD), file_base_name(GD, G),
              file_base_name(Exp, EB), file_name_extension(Base, _, EB),
              scenario_name(G, Base, Name) ),
            Keyed0),
    msort(Keyed0, Keyed),
    pairs_values(Keyed, BPs), pairs_values(BPs, Pairs1),
    list_to_set(Pairs1, Pairs).

report_transform(Report, T) :-
    (   catch(rune_model:rune_report(Report, _, _, _, _, TypeQ), _, fail),
        get_dict(outputType, T, OT), atom_string(TypeQ, OT)
    ->  true
    ;   get_dict(function, T, Fn),
        atomic_list_concat(Ws, ' ', Report), atomic_list_concat(Ws, '', N),
        atom_concat(N, 'ReportFunction', Short),
        atom_string(Short, SS),
        string_concat(Pre, SS, Fn), ( Pre == "" ; string_concat(_, ".", Pre) )
    ).

%   A sample's path, relative to the root of the resources: the first folder,
%   from the configuration's own upwards, under which it is a file (or a file
%   of the same name but for its case: DRR's Collateral-ex01 and
%   collateral-ex02).
sample_file(Dir, Rel, File) :-
    atom_string(RelA, Rel),
    sample_file_(Dir, RelA, File).
sample_file_(Dir, Rel, File) :-
    directory_file_path(Dir, Rel, F0),
    (   exists_file(F0) -> File = F0
    ;   file_directory_name(F0, FD), file_base_name(F0, FB), exists_directory(FD),
        directory_files(FD, Fs), downcase_atom(FB, FL),
        member(F2, Fs), downcase_atom(F2, FL)
    ->  directory_file_path(FD, F2, File)
    ;   file_directory_name(Dir, Up), Up \== Dir,
        sample_file_(Up, Rel, File)
    ).

json_file(F, D) :-
    catch(setup_call_cleanup(open(F, read, S, [encoding(utf8)]),
                             json_read_dict(S, D, [value_string_as(string)]),
                             close(S)), _, fail).

root_pairs(ExpRoot, InRoot, Pairs) :-
    directory_files(ExpRoot, Groups0), msort(Groups0, Groups),
    findall(pair(Name, In, Exp),
            ( member(G, Groups), \+ sub_atom(G, 0, _, _, '.'),
              directory_file_path(ExpRoot, G, GD), exists_directory(GD),
              directory_files(GD, Fs0), msort(Fs0, Fs),
              member(F, Fs), file_name_extension(Base, json, F),
              directory_file_path(GD, F, Exp),
              in_file(InRoot, G, F, In),
              scenario_name(G, Base, Name) ),
            Pairs).

%   The input of the same name, or of the same name but for its case
%   (DRR's Collateral-ex01 and collateral-ex02).
in_file(InRoot, G, F, In) :-
    format(atom(In0), '~w/~w/~w', [InRoot, G, F]),
    (   exists_file(In0) -> In = In0
    ;   format(atom(GD), '~w/~w', [InRoot, G]), exists_directory(GD),
        directory_files(GD, Fs), downcase_atom(F, FL),
        member(F2, Fs), downcase_atom(F2, FL), !,
        format(atom(In), '~w/~w', [GD, F2])
    ).

scenario_name(G, Base, Name) :-
    format(atom(A), '~w_~w', [G, Base]),
    atom_codes(A, Cs),
    maplist(name_code, Cs, Ds),
    atom_codes(Name0, Ds),
    downcase_atom(Name0, Name).
name_code(C, C) :- code_type(C, alnum), !.
name_code(_, 0'_).

%!  expected_flat(+File, -Pairs) is det.
%
%   A report as Path-Value pairs: `leg1.notionalAmount`-300000; the items of
%   a list of values under the list's path, in order; the items of a list of
%   objects under `path[i].attr`. `nonReportable` (DRR's working data) is
%   left out.
expected_flat(File, Pairs) :-
    setup_call_cleanup(open(File, read, S, [encoding(utf8)]),
                       json_read_dict(S, D, [value_string_as(string)]),
                       close(S)),
    phrase(flat(D, ''), Pairs).

flat(D, P) --> { is_dict(D) }, !,
    { dict_pairs(D, _, Ps) },
    flat_pairs(Ps, P).
flat(L, P) --> { is_list(L) }, !, flat_list(L, 0, P).
flat(V, P) --> [P-V].

flat_pairs([], _) --> [].
flat_pairs([K-V|Ps], P) -->
    (   { P == '', K == nonReportable } -> []
    ;   { ( P == '' -> Q = K ; atomic_list_concat([P, K], '.', Q) ) }, flat(V, Q)
    ),
    flat_pairs(Ps, P).

flat_list([], _, _) --> [].
flat_list([V|Vs], I, P) -->
    (   { is_dict(V) } -> { format(atom(Q), '~w[~w]', [P, I]) }, flat(V, Q)
    ;   [P-V]
    ),
    { I1 is I + 1 },
    flat_list(Vs, I1, P).

%   The reports, their directory of DRR's test pack, their twin's name.
%   All 28 of DRR 7.14.0: twelve transaction reports (the test pack of
%   DRR's FpML record-keeping events), and a margin and a valuation report
%   for each of eight regulators.
report_pack('CFTC Part45', 'cftc-part45', cftc_part45).
report_pack('CFTC Part43', 'cftc-part43', cftc_part43).
report_pack('ESMA EMIR Trade', 'esma-emir-trade', esma_emir_trade).
report_pack('FCA UKEMIR Trade', 'fca-ukemir-trade', fca_ukemir_trade).
report_pack('ASIC Trade', 'asic-trade', asic_trade).
report_pack('CSA Trade', 'csa-trade', csa_trade).
report_pack('CSA PPD', 'csa-ppd', csa_ppd).
report_pack('HKMA Trade', 'hkma-trade', hkma_trade).
report_pack('JFSA Trade', 'jfsa-trade', jfsa_trade).
report_pack('MAS Trade', 'mas-trade', mas_trade).
report_pack('SEC Trade', 'sec-trade', sec_trade).
report_pack('SEC PPD', 'sec-ppd', sec_ppd).
report_pack(R, Pack, Base) :-
    member(Reg-RegPack, ['ASIC'-asic, 'CFTC'-cftc, 'CSA'-csa, 'ESMA EMIR'-'esma-emir',
                         'FCA UKEMIR'-'fca-ukemir', 'HKMA'-hkma, 'JFSA'-jfsa, 'MAS'-mas]),
    member(Kind-K, ['Margin'-margin, 'Valuation'-valuation]),
    format(atom(R), '~w ~w', [Reg, Kind]),
    format(atom(Pack), '~w-~w', [RegPack, K]),
    atomic_list_concat(Ws, '-', Pack), atomic_list_concat(Ws, '_', Base).

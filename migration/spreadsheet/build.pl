/** <module> The spreadsheet twins: build them all, or one

    swipl -g "consult(build), build_all, halt."
    swipl -g "consult(build), build(ma_snap), halt."

    Each twin is the program File ▸ Open writes for the workbook (xlsx_import),
    with its workbook in sources/ beside it. Where it goes depends on what the
    publisher allows: a public-domain workbook (a US federal work) beside the
    public examples of LE2 (examples/migration/spreadsheet/), any other in this
    repository's examples/migration/spreadsheet/, unpublished. The workbooks
    come from fetch_sources.sh.
*/

:- use_module('../le2_paths').
:- use_module(xlsx_import).

%   twin(Name, Workbook in .cache/files, public | private, Options)
twin(ma_snap,             'ma_snap_2026_10.xlsx',     private, []).   % MLRI: no licence stated
twin(pt_irs_simplificado, 'pt_irs_simplificado.xlsx', private,         % OCC: no licence stated
     [known_departures([case_7-"approximated: the sheet shows an error inside the branch its IF takes (the year of the start of activity is 0); the twin's otherwise cascade answers with the next alternative instead"])]).
twin(sc_mva_ajustada,     'sc_mva_ajustada.xlsx',     private, []).   % SEF/SC: no licence stated
twin(ok_child_support,    'ok_child_support.xlsm',    private, []).   % Oklahoma DHS: no licence stated
twin(cms_mlr,             'cms_mlr_2025.xlsm',        public,  [cases(6)]).   % CMS: a US federal work, public domain
twin(eba_lcr,             'eba_lcr_tool.xlsx',        private, [cases(6)]).   % EBA: information only
twin(ky_withholding,      'ky_withholding_2026.xlsx', private, []).   % Kentucky DOR: no licence stated; one rule over each row

twin_dir(Name, public, Dir) :- !,
    le2_dir(LE2), atomic_list_concat([LE2, '/examples/migration/spreadsheet/', Name], Dir).
twin_dir(Name, private, Dir) :-
    private_root(Root), atomic_list_concat([Root, '/examples/migration/spreadsheet/', Name], Dir).

build_all :- forall(twin(N, _, _, _), build(N)).

build(Name) :-
    twin(Name, File, Home, Options),
    module_property(xlsx_import, file(F)), file_directory_name(F, Here),
    atomic_list_concat([Here, '/.cache/files/', File], Path),
    (   exists_file(Path) -> true ; format("~w: run fetch_sources.sh first~n", [File]), fail ),
    twin_dir(Name, Home, Dir),
    ( exists_directory(Dir) -> delete_directory_and_contents(Dir) ; true ),
    import_workbook(Path, Dir, [name(Name)|Options], imported(_, Notes)),
    forall(member(N, Notes), format("~w~n", [N])).

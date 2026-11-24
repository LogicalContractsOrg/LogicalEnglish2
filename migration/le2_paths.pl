/** <module> Where LE2, LPS2 and the private twins are, for the translators

    The translators of migration/ run inside LE2 (the editor's File ▸ Open),
    inside LPS2 (its IDE opens a .sol through the LE2 it has loaded), or from
    a shell (the tests, the twins). None of those places is a fixed path, so
    every translator asks here.

    LE2 is the repository this directory is part of: the parent of
    migration/, a directory with le_kbs.pl. Loading this module declares it
    as the `le2` file search path (unless the LE2 already loaded in this
    process has), so a translator writes `use_module(le2(le_writer))`.

    LPS2 is the LPS2 this process runs in (its lps_http module), $LPS2_DIR, a
    checkout beside LE2 (../lps2, ../LPS2), or /lps2: a directory with the
    `lps` script in it. Loading this module declares the one found as `lps2`.
    LPS2 is not needed: only the doors that write Logical English for LPS
    (Solidity, Drools, Daml, the contracts of L4, the games of Epilog) run
    their twins with it, and each says so when it is missing.

    The twins a translator writes live in the public repository of the
    language they are written in, under examples/migration/<source>/: LE2 for
    timeless Logical English, LPS2 for Logical English for LPS. The twins of
    sources whose licence does not allow a changed copy to be published
    (Oracle Intelligent Advisor projects, Socotra's product library,
    OpenFisca and PolicyEngine, which are AGPL-3.0, ISDA's reporting rules)
    are never written into either: they go to a private place, private_root/1.
    twins_dir/2 says where.
*/

:- module(le2_paths, [le2_dir/1, lps2_dir/1, private_root/1, twins_dir/2]).

:- dynamic migration_dir/1.
:- prolog_load_context(directory, D), retractall(migration_dir(_)), assertz(migration_dir(D)).

%!  le2_dir(-Dir) is semidet.
%
%   The LE2 this directory belongs to (or, first, the one already loaded in
%   this process: one image cannot hold two copies of LE2's modules).
le2_dir(Dir) :-
    once(( le2_candidate(D0), le2_checkout(D0, Dir) )).

le2_candidate(D) :- user:file_search_path(le2, D), atom(D).
le2_candidate(D) :- migration_dir(M), file_directory_name(M, D).
le2_candidate(D) :- member(V, ['LE2_DIR', 'LE2_HOME', 'LPS_LE2_LIB', 'LPS_LE2_DIR']),
                    getenv(V, D), D \== ''.

le2_checkout(D0, D) :-
    absolute_file_name(D0, D, [file_type(directory), file_errors(fail)]),
    atomic_list_concat([D, '/le_kbs.pl'], F),
    exists_file(F).

%!  private_root(-Dir) is det.
%
%   Where the twins that may not be published are written and read: Dir has
%   them under examples/migration/<source>/, as the public repositories do.
%   In order: $LE_PRIVATE_TWINS_DIR; a private checkout that already holds
%   such twins ($LPS_PLUS_DIR, ../lpsPlus beside LE2, /lpsPlus); and
%   otherwise build/private/ inside LE2, which git ignores.
private_root(Root) :-
    once(( private_candidate(D0),
           absolute_file_name(D0, Root, [file_type(directory), file_errors(fail)]) )), !.
private_root(Root) :-
    le2_dir(LE2),
    atomic_list_concat([LE2, '/build/private'], Root),
    catch(make_directory_path(Root), _, true).

private_candidate(D) :- getenv('LE_PRIVATE_TWINS_DIR', D), D \== ''.
private_candidate(D) :-
    (   member(V, ['LPS_PLUS_DIR', 'LPSPLUS_DIR']), getenv(V, D0), D0 \== ''
    ->  \+ memberchk(D0, [none, '-']),
        ( D1 = D0 ; sibling(['lpsPlus', lpsplus], D1) ; D1 = '/lpsPlus' )
    ;   ( sibling(['lpsPlus', lpsplus], D1) ; D1 = '/lpsPlus' )
    ),
    atomic_list_concat([D1, '/examples/migration'], Twins),
    exists_directory(Twins),
    D = D1.

%!  lps2_dir(-Dir) is semidet.
lps2_dir(Dir) :-
    once(( lps2_candidate(D0), lps2_checkout(D0, Dir) )).

lps2_candidate(Root) :-            % src/edges/lps_http.pl of the running LPS2
    catch(module_property(lps_http, file(F)), _, fail),
    file_directory_name(F, Edges), file_directory_name(Edges, Src),
    file_directory_name(Src, Root).
lps2_candidate(D) :- getenv('LPS2_DIR', D), D \== ''.
lps2_candidate(D) :- sibling([lps2, 'LPS2'], D).
lps2_candidate('/lps2').

lps2_checkout(D0, D) :-
    absolute_file_name(D0, D, [file_type(directory), file_errors(fail)]),
    atomic_list_concat([D, '/lps'], F),
    exists_file(F).

%!  twins_dir(+Source:atom, -Dir:atom) is semidet.
%
%   The directory holding the twins of Source (blawx, daml, ...).
twins_dir(Source, Dir) :-
    twins_home(Source, Home),
    (   Home == le2  -> le2_dir(Root)
    ;   Home == lps2 -> lps2_dir(Root)
    ;   private_root(Root)
    ),
    atomic_list_concat([Root, '/examples/migration/', Source], Dir).

twins_home(blawx, le2).
twins_home(legalruleml, le2).
twins_home(miniscript, le2).
twins_home(scasp, le2).
twins_home(daml, lps2).
twins_home(drools, lps2).
twins_home(solidity, lps2).
twins_home(epilog, le2).           % public (Stanford, October 2026); the rulesets here, the games (LE for LPS) in LPS2: epilog_twin:twin_dir/4
twins_home(socotra, private).      % no licence file: kept private
twins_home(oia, private).          % Oracle's sample projects: no licence that allows publication
twins_home(oipa, le2).
twins_home(l4, le2).              % Apache-2.0 (L4 rules, timeless LE)
twins_home(rulespec, le2).        % CC-BY-4.0 (Axiom RuleSpec), with attribution
twins_home(openfisca, private).     % AGPL-3.0 sources: a twin is a translation of them, so not published here
twins_home(policyengine, private).  % AGPL-3.0, as OpenFisca's
twins_home(catala, le2).          % Apache-2.0 (catala-examples), with attribution
twins_home(dmn, le2).              % DMN: the TCK (Apache-2.0), RONL (EUPL-1.2), BDT (MIT); the bruidsschat is private (dmn/corpus.pl)
twins_home(ruml, le2).             % RUML: the specification's examples and the tests' fixtures (Apache-2.0, Rulemapping Group GmbH)

sibling(Names, D) :-
    migration_dir(M), file_directory_name(M, Root),
    file_directory_name(Root, Parent),
    member(N, Names),
    atomic_list_concat([Parent, '/', N], D).

:- (   le2_dir(D)
   ->  (   user:file_search_path(le2, D) -> true
       ;   asserta(user:file_search_path(le2, D))
       )
   ;   print_message(error, format("migration: no LE2 found: this directory belongs inside an LE2 checkout (a directory with le_kbs.pl)", []))
   ).

%  LPS2, when there is one. Unlike LE2 this is not an error to be without:
%  most of migration/ has nothing to do with LPS, and the translators that
%  do (solidity, drools, daml) say so themselves when they are asked to run.
:- (   lps2_dir(L)
   ->  (   user:file_search_path(lps2, L) -> true
       ;   asserta(user:file_search_path(lps2, L))
       )
   ;   true
   ).

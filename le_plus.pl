/** <module> Where the private lpsPlus repository is, when this installation has one

    Two things the hosted server offers come from the private lpsPlus
    repository rather than from this one:

      - `accounts/lc_accounts.pl` — signing in (Google, GitHub, or an account
        we created), and which licences each account holds;
      - `contract_assistant/` — the LE Contract Assistant, which the licence
        of that name gives.

    Neither is needed: without lpsPlus every visitor is anonymous, and
    everything in this repository works, the translators of other systems
    included (migration/, which was in lpsPlus until November 2026).

    Where it looks, in order — the same order as LPS2's
    `src/syntax/lps_plus.pl`, so one setting serves both:

      $LPS_PLUS_DIR (or $LPSPLUS_DIR)   a checkout, named explicitly — or the
                                        word `none`, which means "no lpsPlus",
                                        whatever is on this machine
      ../lpsPlus, ../lpsplus            a checkout beside this one
      /lpsPlus                          a container's mount
      <this repository>/vendor/lpsplus  what vendor_lpsplus.sh put in the
                                        image (buildPush.sh runs it)

    A directory counts when it has one of the two files above.
*/

:- module(le_plus, [
    le_plus_root/1,      % -Dir
    le_plus_file/2,      % +RelativePath, -AbsolutePath
    le_plus_disabled/0
    ]).

:- use_module(library(lists)).

here(Dir) :- prolog_load_context(directory, Dir).

:- dynamic repo_dir/1.
:- here(D), retractall(repo_dir(_)), assertz(repo_dir(D)).

named(D) :- member(V, ['LPS_PLUS_DIR', 'LPSPLUS_DIR']), getenv(V, D), D \== '', !.

%!  le_plus_disabled is semidet.
%
%   `LPS_PLUS_DIR=none`: behave as a checkout with no lpsPlus beside it.
le_plus_disabled :- named(D), memberchk(D, [none, '-']).

candidate(D) :- named(D).
candidate(D) :- repo_dir(Root), file_directory_name(Root, Parent),
    member(N, ['lpsPlus', lpsplus]), atomic_list_concat([Parent, '/', N], D).
candidate('/lpsPlus').
candidate(D) :- repo_dir(Root), atom_concat(Root, '/vendor/lpsplus', D).

marker('accounts/lc_accounts.pl').
marker('contract_assistant/le_contract_assistant.pl').

%!  le_plus_root(-Dir) is semidet.
%
%   The lpsPlus checkout (or copy) this installation uses.
le_plus_root(Dir) :-
    \+ le_plus_disabled,
    candidate(C),
    absolute_file_name(C, Dir, [file_type(directory), file_errors(fail)]),
    marker(M),
    atomic_list_concat([Dir, '/', M], F),
    exists_file(F), !.

%!  le_plus_file(+Rel, -File) is semidet.
%
%   Rel inside the lpsPlus checkout, when there is one and it has that file.
le_plus_file(Rel, File) :-
    le_plus_root(Dir),
    atomic_list_concat([Dir, '/', Rel], File),
    exists_file(File).

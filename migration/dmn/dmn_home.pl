/** <module> Where the DMN door's own files are

    dmn_path(+Relative, -Absolute): a file or folder of this directory
    (the fetched collections in .cache/, the oracles' jars, runs/), wherever
    the repository is checked out.
*/

:- module(dmn_home, [dmn_path/2]).

:- dynamic home/1.
:- prolog_load_context(directory, D), retractall(home(_)), assertz(home(D)).

dmn_path(Rel, Abs) :-
    home(H),
    atomic_list_concat([H, '/', Rel], Abs).

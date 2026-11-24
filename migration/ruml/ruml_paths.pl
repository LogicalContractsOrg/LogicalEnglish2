/** <module> Paths of a RUML tree

    A node result in RUML is filed under its path (§5.1.2): `1` the root,
    `1.2` its second child, `1.2.1` the first child of that. A modular node
    has several paths.

        path_lexid(+Doc, +Path, -LexId)
        tree_paths(+Doc, +MaxRecursion, -Paths)   Path-LexId, root first
*/

:- module(ruml_paths, [path_lexid/3, tree_paths/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(ruml_reader).

path_lexid(Doc, Path, L) :-
    atomic_list_concat(['1'|Is], '.', Path),
    path_steps(Is, Doc, '1', L).

path_steps([], _, K, K).
path_steps([I|Is], Doc, K0, K) :-
    node(Doc, K0, N), j(N, children, Cs), atom_number(I, IN), nth1(IN, Cs, S), atom_string(K1, S),
    path_steps(Is, Doc, K1, K).

tree_paths(Doc, Max, Paths) :-
    findall(P-L, path_of(Doc, Max, '1', '1', [], P, L), Paths).

path_of(_, _, P, L, _, P, L).
path_of(Doc, Max, P0, L0, Stack, P, L) :-
    node(Doc, L0, N), j(N, children, Cs),
    nth1(I, Cs, S), atom_string(C, S),
    include(==(C), [L0|Stack], Seen), length(Seen, Depth), Depth =< Max,
    format(atom(P1), '~w.~d', [P0, I]),
    path_of(Doc, Max, P1, C, [L0|Stack], P, L).

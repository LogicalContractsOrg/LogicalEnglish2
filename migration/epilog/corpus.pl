/** <module> The Epilog programs that have twins

    Every program of the Epilog site (http://epilog.stanford.edu) was
    translated and checked against EpilogJS (validate.pl); the ones listed
    here agree, and build.pl writes their twins:

      theory(Id, Title)       a ruleset of the Examples page (its rule sheet
                              and data sheet): timeless Logical English, in
                              LE2's examples/migration/epilog/
      program(Id, Title, Ops) a program of the Examples page with operations
                              and no game rules: Logical English for LPS, in
                              LPS2's examples/migration/epilog/; the state
                              starts as its data sheet and Ops are applied in
                              turn
      game(Id, Title, Moves)  a game of the Games page: Logical English for
                              LPS, in LPS2's; EpilogJS plays Moves moves
                              (fewer when the game ends first)

    The programs not listed (they do not agree, or leave nothing to check)
    are in the README of LE2's examples/migration/epilog/, each with why.
    fetch_sources.sh puts the sources in .cache/.
*/

:- module(epilog_corpus, [theory/2, program/3, game/3,
                          theory_files/3, program_files/3, game_file/2, source_url/3]).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).

theory(base,        "Base (the Examples page)").
theory(blocks,      "Blocks world (the Examples page)").
theory(graphs,      "Properties of a graph (the Examples page)").
theory(kinship,     "Kinship (the Examples page)").
theory(mapcoloring, "Map coloring (the Examples page)").
theory(metalevel,   "Metalevel (the Examples page)").

program(triples,     "Triples (the Examples page)",      [convert_to_triples, convert_to_tables]).
program(grapheditor, "Graph editor (the Examples page)", ['copy(a,e)', 'invert(c)', 'insert(x,b)']).

:- include(corpus_games).

theory_files(Id, Rules, Data) :-
    here(H),
    (   Id == base                  % a data sheet with no rule sheet
    ->  Rules = none
    ;   format(atom(Rules), '~w/.cache/theories/~w.rules', [H, Id])
    ),
    (   our_data(Id)
    ->  format(atom(Data), '~w/data/~w.data', [H, Id])
    ;   format(atom(Data), '~w/.cache/theories/~w.data', [H, Id])
    ).

%   The site gives Metalevel no data sheet, and Map Coloring's colours no
%   values (its Sierraplus page lets a visitor choose them): with the site's
%   data alone every query's answer is "none", on both sides. data/ holds
%   ours.
our_data(metalevel).
our_data(mapcoloring).

%   The Graph Editor has no data sheet on the site: data/grapheditor.data is
%   ours.
program_files(Id, Library, Data) :-
    here(H),
    format(atom(Library), '~w/.cache/theories/~w.rules', [H, Id]),
    (   Id == grapheditor
    ->  format(atom(Data), '~w/data/~w.data', [H, Id])
    ;   format(atom(Data), '~w/.cache/theories/~w.data', [H, Id])
    ).

game_file(Id, File) :-
    here(H), format(atom(File), '~w/.cache/games/~w.hrf', [H, Id]).

source_url(theory, base, U) :- !, U = 'http://epilog.stanford.edu/homepage/datasheet.php?theory=base'.
source_url(theory, Id, U) :- format(atom(U), 'http://epilog.stanford.edu/homepage/rulesheet.php?theory=~w', [Id]).
source_url(program, Id, U) :- format(atom(U), 'http://epilog.stanford.edu/homepage/rulesheet.php?theory=~w', [Id]).
source_url(game, Id, U) :- format(atom(U), 'http://epilog.stanford.edu/homepage/game.php?game=~w', [Id]).

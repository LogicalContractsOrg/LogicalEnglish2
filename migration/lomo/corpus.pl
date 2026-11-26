/** <module> The LOMO corpus: the data files of the LOMO repository

    lomo_file(Set, File): Set is the folder of examples/migration/lomo/ the
    register goes to: `examples` (imported from data/examples/batch_1/),
    `other` (imported from all of data/other/), `lfds` (imported from
    data/lfds/ttl/, which a program of the LOMO project generated from the
    digital statements of Commission proposals), `spec` (the Turtle examples
    of the specification page), `cases` (agent-written descriptions).
*/

:- module(lomo_corpus, [lomo_file/2, corpus_dir/1, ontology_file/1, shapes_file/1, query_file/2]).

:- prolog_load_context(directory, D),
   atomic_list_concat([D, '/corpus/lomo-1.1.0'], C),
   asserta(corpus_dir_(C)).

:- dynamic corpus_dir_/1.
:- discontiguous lomo_file/2.
corpus_dir(D) :- corpus_dir_(D).

lomo_file(Set, File) :-
    corpus_dir(C),
    member(Set-Sub, [examples-'data/examples/batch_1', other-'data/other', lfds-'data/lfds/ttl']),
    atomic_list_concat([C, '/', Sub], Dir),
    directory_files(Dir, Fs0), msort(Fs0, Fs),
    member(F, Fs), file_name_extension(_, ttl, F),
    atomic_list_concat([Dir, '/', F], File).

%   The 65 Turtle examples of the specification page (corpus/spec-examples/).
lomo_file(spec, File) :-
    corpus_dir(C), file_directory_name(C, Corpus),
    atomic_list_concat([Corpus, '/spec-examples'], Dir),
    directory_files(Dir, Fs0), msort(Fs0, Fs),
    member(F, Fs), file_name_extension(_, ttl, F),
    atomic_list_concat([Dir, '/', F], File).

%   The descriptions written for the door's own tests (corpus/cases/).
lomo_file(cases, File) :-
    corpus_dir(C), file_directory_name(C, Corpus),
    atomic_list_concat([Corpus, '/cases'], Dir),
    directory_files(Dir, Fs0), msort(Fs0, Fs),
    member(F, Fs), file_name_extension(_, ttl, F),
    atomic_list_concat([Dir, '/', F], File).

ontology_file(F) :- corpus_dir(C), atomic_list_concat([C, '/ontologies/lomo-ontology.ttl'], F).
shapes_file(F) :- corpus_dir(C), atomic_list_concat([C, '/shapes/lomo-shapes.ttl'], F).
query_file(Name, F) :- corpus_dir(C), atomic_list_concat([C, '/queries/', Name, '.rq'], F).

/*  ledger_json.pl — each Rune twin's <twin>.ledger.json, from its ledger and
    its templates.

    LE2's View Original Text (le_original_text.pl) finds the passage of the
    original under the cursor through a twin's <program>.ledger.json: an entry
    whose `in_program` is the template of the construct's predicate gives, as
    its `element`, the name to look for in the originals (the twin's
    sources/, twin_sources.py). The Rune twins wrote their ledger as Markdown
    only (build.pl); this writes the JSON beside it, in le_migration.pl's
    format: for each definition of <twin>.ledger.md, its qualified Rune name
    as the element and, from <twin>.templates.pl, the template it became as
    `in_program`.

        ./myswipl.sh -q -g "ledger_json:run([])" -t halt migration/rune/ledger_json.pl
        ./myswipl.sh -q -g "ledger_json:run([cftc_margin])" -t halt migration/rune/ledger_json.pl

    (No initialization/2 here: build.pl and cdm_build.pl load this module,
    and their own main must stay theirs.)
*/
:- module(ledger_json, [ledger_json/1]).

:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(readutil)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(rune_paths).

run(Argv) :-
    twins_dir(TD),
    (   Argv == []
    ->  directory_files(TD, Ds0), msort(Ds0, Ds)
    ;   Ds = Argv
    ),
    forall(( member(D, Ds), D \== '.', D \== '..',
             directory_file_path(TD, D, Dir), exists_directory(Dir) ),
           ledger_json(Dir)).

%!  ledger_json(+TwinDir) is det.
%
%   Writes <TwinDir>/<twin>.ledger.json for each <twin>.ledger.md there.
ledger_json(Dir) :-
    directory_files(Dir, Fs),
    forall(( member(F, Fs), atom_concat(Base, '.ledger.md', F) ),
           write_json(Dir, Base)).

write_json(Dir, Base) :-
    directory_file_path(Dir, Base, Stem),
    atom_concat(Stem, '.ledger.md', MD),
    atom_concat(Stem, '.templates.pl', TP),
    atom_concat(Stem, '.ledger.json', JF),
    templates(TP, Ts),
    read_file_to_string(MD, Text, [encoding(utf8)]),
    split_string(Text, "\n", "", Lines),
    convlist(row, Lines, Rows),
    maplist(entry(Ts), Rows, Entries),
    counts(Entries, Counts),
    setup_call_cleanup(open(JF, write, Out, [encoding(utf8)]),
                       json_write_dict(Out, _{counts: Counts, entries: Entries}, [width(100)]),
                       close(Out)),
    length(Entries, N),
    include([E]>>( get_dict(in_program, E, P), P \== "" ), Entries, WithT), length(WithT, NT),
    format("~w: ~w entries, ~w with their template~n", [Base, N, NT]).

%   tmpl(What, Functor, Text, Arity) terms of <twin>.templates.pl, as
%   Qualified-Text pairs (a function's or a rule's own name; an alias of a
%   function as "<function>/<alias>", as the ledger names it).
templates(File, Ts) :-
    (   exists_file(File)
    ->  setup_call_cleanup(open(File, read, In, [encoding(utf8)]), read_all(In, Terms), close(In)),
        convlist(template_pair, Terms, Ts)
    ;   Ts = []
    ).

read_all(In, Ts) :-
    read_term(In, T, []),
    ( T == end_of_file -> Ts = [] ; Ts = [T|R], read_all(In, R) ).

template_pair(tmpl(rule(Q), _, T, _), Q-T).
template_pair(tmpl(func(Q), _, T, _), Q-T).
template_pair(tmpl(alias(Q, A, _), _, T, _), QA-T) :- atomic_list_concat([Q, A], '/', QA).

%   A row of the ledger's table: | `element` | kind | verdict | note |
row(Line, row(El, Kind, Verdict, Note)) :-
    string_concat("| `", R0, Line),
    sub_string(R0, B, _, A, "` | "), !,
    sub_string(R0, 0, B, _, El),
    sub_string(R0, _, A, 0, Rest),
    split_string(Rest, "|", " ", [Kind, Verdict, Note|_]).

entry(Ts, row(El, Kind, Verdict, Note), _{element: El, kind: Kind, verdict: Verdict,
                                          mapping: "Rune definition -> LE rules",
                                          in_program: InP, note: Note}) :-
    atom_string(ElA, El),
    (   memberchk(ElA-T, Ts) -> format(string(InP), "template \"~w\"", [T]) ; InP = "" ).

counts(Es, _{encoded: E, approximated: A, residue: R}) :-
    aggregate_all(count, ( member(X, Es), get_dict(verdict, X, "encoded") ), E),
    aggregate_all(count, ( member(X, Es), get_dict(verdict, X, "approximated") ), A),
    aggregate_all(count, ( member(X, Es), get_dict(verdict, X, "residue") ), R).

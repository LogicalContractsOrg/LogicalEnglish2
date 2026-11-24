/** <module> Tests of the Epilog -> LE translator (Phase 2d)

    Run from an LE2 checkout, with LPS2 beside LE2 or named by LPS2_DIR,
    after fetch_sources.sh and build.pl (see README):

        swipl -g run_tests -t halt migration/epilog/test_epilog.pl

    The rulesets' twins (LE2's) pass EpilogJS's answers (recorded in their
    scenarios); each game's and program's twin (LPS2's), run by LPS2 (`lps
    state`), ends in the state EpilogJS ended the same play in (recorded
    under sources/); the Prolog reader of Epilog reads every text fetched
    from the site as EpilogJS does;
    File ▸ Open reads a ruleset and a game. The tests that need EpilogJS
    (the reader's agreement) are skipped when it is not in .cache/.
*/

:- module(test_epilog, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module(library(json)).
:- use_module(epilog_twin).
:- use_module(epilog_syntax).
:- use_module(epilog_reader).
:- use_module(epilog_import).
:- use_module(corpus).
:- use_module(validate).
:- use_module('../le2_paths').
:- use_module(le2(le_kbs)).

%   The rulesets' twins are LE2's, the games' and programs' LPS2's
%   (epilog_twin:twin_dir/4).
twin_file(theory, Id, F) :- !,
    twins_dir(epilog, D), format(atom(F), '~w/~w/~w.le', [D, Id, Id]).
twin_file(_, Id, F) :-
    lps2_dir(L), format(atom(F), '~w/examples/migration/epilog/~w/~w.le', [L, Id, Id]).

epilogjs :- module_property(epilog_twin, file(F)), file_directory_name(F, M),
    atomic_list_concat([M, '/.cache/epilog.js'], J), exists_file(J).

:- begin_tests(epilog_twins).

%   Every ruleset twin passes the answers EpilogJS gives on its dataset.
test(theory_twins_pass, [forall(theory(Id, _))]) :-
    twin_file(theory, Id, F),
    le_kbs:runTestsFor(F, test_file(_, Rs)),
    assertion(Rs \== []),
    assertion(forall(member(R, Rs), functor(R, pass, _))).

%   Every game's and program's twin, run by LPS2, ends where EpilogJS ended
%   the same play.
test(game_final_state_is_epilogs, [forall(( game(Id, _, _) ; program(Id, _, _) ))]) :-
    twin_file(game, Id, LE),
    file_directory_name(LE, D),
    format(atom(J), '~w/sources/~w.epilog.json', [D, Id]),
    setup_call_cleanup(open(J, read, S), json_read_dict(S, Run, [value_string_as(atom)]), close(S)),
    base_state_of(Run, _, Expected),
    twin_final_state(LE, Actual),
    assertion(Expected == Actual).

%   Every twin loads with no error.
test(twins_load, [forall(( theory(Id, _), K = theory ; game(Id, _, _), K = game ; program(Id, _, _), K = game ))]) :-
    twin_file(K, Id, F),
    file_directory_name(F, D),
    read_file_to_string(F, Text, []),
    le_kbs:load_text(Text, D, _KB).

:- end_tests(epilog_twins).

:- begin_tests(epilog_reader).

%   The Prolog reader reads every text of the corpus as EpilogJS does: the
%   same sentences, with the same variables (EpilogJS's JSON writes a term
%   and(X, Y) as it writes a conjunction, and names each `_` `_1`, `_2`,
%   ...: those two are compared as what they are).
test(reads_as_epilogjs, [condition(epilogjs), forall(corpus_text(F))]) :-
    epilog_file_sentences(F, A0), epilog_sentences(F, B0),
    maplist(plain, A0, A1), maplist(plain, B0, B1),
    norm(A1, A), norm(B1, B),
    assertion(A =@= B).

%   Every text fetched from the site (fetch_sources.sh), not only the
%   twins': a rule sheet, data sheet, worksheet program or game library
%   with something in it.
corpus_text(F) :-
    module_property(epilog_twin, file(T)), file_directory_name(T, M),
    member(P, ['/.cache/theories/*', '/.cache/worksheets/*.hrf', '/.cache/worksheets/*.data', '/.cache/games/*.hrf']),
    atom_concat(M, P, Pattern), expand_file_name(Pattern, Fs),
    member(F, Fs), size_file(F, S), S > 1.

plain(S-Bs, S-Bs1) :- exclude([N=_]>>sub_atom(N, 0, _, _, '_'), Bs, Bs1).

norm(V, V) :- var(V), !.
norm(and(L), and(L1)) :- is_list(L), !, maplist(norm, L, L1).
norm(T, and(L1)) :- compound(T), T =.. [and|L], L = [_, _|_], !, maplist(norm, L, L1).
norm(T, T1) :- compound(T), !, T =.. [F|As], maplist(norm, As, Bs), T1 =.. [F|Bs].
norm(T, T).

test(syntax) :-
    epilog_text_sentences("p(a)\nq(X) :- p(X) & ~r(X!nil)\nm(X) :: c(X) ==> ~c(X) & d(X)\nt :: kerchunk\nl(X) :- a(X) | b(X)", Ss),
    Ss = [fact(p(a))-[], rule(q(X), [p(X), not(r(cons(X, nil)))])-_, handler(m(Y), c(Y), and([not(c(Y)), d(Y)]))-_,
          handler(t, true, kerchunk)-[], rule(l(Z), [or(a(Z), b(Z))])-_].

:- end_tests(epilog_reader).

:- begin_tests(epilog_import).

%   File ▸ Open: a ruleset is timeless LE, a game LE for LPS whose initial
%   state Prolog evaluated (no EpilogJS needed).
test(file_open_ruleset, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    tmp_file(kin, F0), atom_concat(F0, '.epilog', F),
    setup_call_cleanup(open(F, write, S),
                       format(S, "parent(art,bob)~nparent(bob,cal)~ngp(X,Z) :- parent(X,Y) & parent(Y,Z)~n", []),
                       close(S)),
    assertion(detect_epilog(F)),
    import_epilog(F, D, imported(LE, _)),
    read_file_to_string(LE, Text, []),
    assertion(sub_string(Text, _, _, _, "the gp of")),
    le_kbs:load_text(Text, D, _).

test(file_open_game, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    game_file(tictactoe, F),
    assertion(detect_epilog(F)),
    import_epilog(F, D, imported(LE, _)),
    read_file_to_string(LE, Text, []),
    assertion(sub_string(Text, _, _, _, "the target language is: lps")),
    assertion(sub_string(Text, _, _, _, "initially")).

test(prolog_is_not_epilog) :-
    tmp_file(pl, F0), atom_concat(F0, '.txt', F),
    setup_call_cleanup(open(F, write, S), format(S, "p(a).~nq(X) :- p(X).~n", []), close(S)),
    assertion(\+ detect_epilog(F)).

tmp_dir(D) :- tmp_file(epi, D), make_directory(D).

%   Opens an Epilog text with File > Open: the LE text and the note.
open_epilog(Ext, Source, D, Text, Note) :-
    tmp_file(epi, F0), file_name_extension(F0, Ext, F),
    setup_call_cleanup(open(F, write, S), write(S, Source), close(S)),
    import_epilog(F, D, imported(LE, [Note])),
    read_file_to_string(LE, Text, []).

residue_count(Text, N) :-
    aggregate_all(count, sub_string(Text, _, _, _, "% RESIDUE "), N2), N is N2 // 2.

%   Functional terms are residue blocks (the Epilog sentence kept), not rules
%   with raw variables or a misplaced negation, and are counted.
test(functional_terms_are_residue, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    open_epilog(epilog, "proposition(p)\nnegation(not(X)) :- sentence(X)\nconjunction(and(X,Y)) :- sentence(X) & sentence(Y)\nsentence(X) :- proposition(X)\nsentence(X) :- negation(X)\n", D, Text, Note),
    assertion(\+ sub_string(Text, _, _, _, "it is not the case that a proposition is a negation")),
    assertion(\+ sub_string(Text, _, _, _, "(_")),
    assertion(\+ sub_string(Text, _, _, _, ",_")),
    assertion(sub_string(Text, _, _, _, "% RESIDUE functional_term_1 BEGIN")),
    assertion(sub_string(Text, _, _, _, "|   negation(not(X)) :- sentence(X)") ; sub_string(Text, _, _, _, "| negation(not(X)) :- sentence(X)")),
    residue_count(Text, 2),
    assertion(sub_string(Note, _, _, _, "2 residue")),
    le_kbs:load_text(Text, D, _).

%   A function definition and the sentences that call it: residue blocks.
test(function_definitions_are_residue, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    open_epilog(epilog, "num(1)\ndouble(X) := times(X,2)\nbig(X,Y) :- num(X) & evaluate(plus(double(X),1),Y)\nsmall(X) :- num(X)\n", D, Text, Note),
    assertion(sub_string(Text, _, _, _, "% RESIDUE function_definition_1 BEGIN")),
    assertion(sub_string(Text, _, _, _, "% RESIDUE function_call_1 BEGIN")),
    assertion(\+ sub_string(Text, _, _, _, "double(_")),
    residue_count(Text, 2),
    assertion(sub_string(Note, _, _, _, "2 residue")),
    le_kbs:load_text(Text, D, _).

%   The reader's list-pattern residue blocks are counted and show the Epilog.
test(list_patterns_counted, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    open_epilog(epilog, "mem(X,X!Y)\nmem(X,Y!Z) :- mem(X,Z)\nappend(nil,Y,Y)\nappend(X!Y,Z,X!W) :- append(Y,Z,W)\n", D, Text, Note),
    residue_count(Text, 3),
    assertion(sub_string(Text, _, _, _, "| mem(X,Y!Z) :- mem(X,Z)")),
    assertion(sub_string(Note, _, _, _, "3 residue")).

%   A ruleset's max: two cases, which give Epilog's answers; no build.pl in
%   the header of a program File > Open made.
test(ruleset_max_two_cases, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    open_epilog(epilog, "num(1)\nnum(7)\nbigger(X,Z) :- num(X) & num(Y) & evaluate(max(X,Y),Z)\n", D, Text0, _),
    assertion(\+ sub_string(Text0, _, _, _, "max(")),
    assertion(\+ sub_string(Text0, _, _, _, "build.pl")),
    once(sub_string(Text0, B, _, _, "query bigger is:")), sub_string(Text0, 0, B, _, Front), sub_string(Text0, B, _, 0, Back),
    atomics_to_string([Front, "scenario s is:\n    bigger expects answers [\"1 is the bigger of 1\", \"1 is the bigger of 7\", \"7 is the bigger of 7\"].\n\n", Back], Text),
    directory_file_path(D, 'max.le', LE),
    setup_call_cleanup(open(LE, write, S), write(S, Text), close(S)),
    le_kbs:runTestsFor(LE, test_file(_, Rs)),
    assertion(Rs = [_|_]),
    assertion(forall(member(R, Rs), functor(R, pass, _))).

%   symless in a ruleset: dropped and approximated (not a broken Prolog goal).
test(ruleset_symless_approximated, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    open_epilog(epilog, "node(a)\nnode(b)\npair(X,Y) :- node(X) & node(Y) & symless(X,Y)\n", D, Text, Note),
    assertion(\+ sub_string(Text, _, _, _, "@<")),
    assertion(sub_string(Note, _, _, _, "1 approximated")).

%   Operations called deeper than the inlining goes: a residue block, the move
%   approximated.
test(deep_operations_reported, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    open_epilog(epilog, "count(0)\ngo :: a1\na1 :: a2\na2 :: a3\na3 :: a4\na4 :: a5\na5 :: a6\na6 :: count(X) & evaluate(plus(X,1),Y) ==> ~count(X) & count(Y)\nreset :: count(X) ==> ~count(X) & count(0)\n", D, Text, Note),
    assertion(sub_string(Text, _, _, _, "% RESIDUE deep_operations_1 BEGIN")),
    assertion(sub_string(Text, _, _, _, "| a6 :: count(X) & evaluate(plus(X,1),Y) ==> ~count(X) & count(Y)")),
    assertion(sub_string(Note, _, _, _, "1 approximated, 1 residue")).

%   A game relation named like a Prolog built-in (skirmish's number/1) does
%   not stop init's evaluation.
test(init_with_builtin_named_relation, [setup(tmp_dir(D)), cleanup(delete_directory_and_contents(D))]) :-
    open_epilog(epilog, "number(1)\nnumber(2)\ninit(count(N)) :- number(N)\nbump :: count(X) & evaluate(plus(X,1),Y) ==> ~count(X) & count(Y)\n", D, Text, _),
    assertion(sub_string(Text, _, _, _, "initially")),
    assertion(sub_string(Text, _, _, _, "2 is a count")).


:- end_tests(epilog_import).

/*  Build the Catala twins (le2_paths:twins_dir/2: LE2's examples/migration/catala).

        ./myswipl.sh -q migration/catala/catala_build.pl [-- programme ...]

    For each programme of corpus.pl: catala_reader.pl reads its files,
    catala_lower.pl lowers its scopes to rules in the shape of RuleSpec
    (.cache/out/cat/<programme>.yaml) and its test scopes to test cases
    (.test.yaml); each test scope is run on Catala's own interpreter (the
    oracle, runs cached in .cache/out/cat/<programme>.run.json); and the twin
    builder of migration/rulespec writes the program, its ledger and its
    originals, in the language of the Catala files.
*/

:- initialization(main, main).

:- use_module(library(main)).
:- use_module(library(filesex)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(yaml)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(le2(le_migration)).
:- use_module(corpus).
:- use_module(catala_reader).
:- use_module(catala_lower).
:- use_module('../rulespec/rulespec_reader').
:- use_module('../rulespec/rulespec_twin').

here(D) :- module_property(catala_corpus, file(F)), file_directory_name(F, D).
examples(E) :- here(H), atomic_list_concat([H, '/.cache/catala-examples'], E).
out_dir(O) :- here(H), atomic_list_concat([H, '/.cache/out/cat'], O).

main(Argv) :-
    (   Argv == [] -> findall(P, programme(P, _, _, _, _), Ps) ; maplist([A, P]>>atom_string(P, A), Argv, Ps) ),
    forall(member(P, Ps), catch(build(P), E, print_message(error, E))).

build(P) :-
    programme(P, Lang, Files0, Roots, Includes),
    examples(Ex), out_dir(Out), make_directory_path(Out),
    maplist({Ex}/[F0, F]>>atomic_list_concat([Ex, '/', F0], F), Files0, Files),
    lower_programme(P, Files, Roots, module(Rules0, Tests0, _Notes)),
    maplist(source_document(Files0), Rules0, Rules),
    atomic_list_concat([Out, '/', P, '.yaml'], ModFile),
    atomic_list_concat([Out, '/', P, '.test.yaml'], TestFile),
    atomic_list_concat([Out, '/', P, '.run.json'], RunFile),
    roots_title(Roots, Title),
    Module = _{format: "rulespec/v1",
               module: _{title: Title, summary: "Scopes of catala-examples, lowered for the twin builder."},
               rules: Rules},
    write_yaml(ModFile, Module),
    generated_cases(P, Lang, Ex, Includes, Gen),
    append(Tests0, Gen, Tests),
    write_yaml(TestFile, Tests),
    oracle(Ex, Files, Includes, Tests, RunFile, Run),
    atom_concat('cat:', P, Id),
    twins_dir(catala, TD0), atomic_list_concat([TD0, '/', P], Dir),
    make_directory_path(Dir),
    copy_sources(Ex, Files0, ModFile, Dir),
    header(Lang, P, Roots, Header),
    ( Lang == fr -> Subj = 'le cas' ; Subj = 'the case' ),
    with_upload([Id-ModFile], [],
                module_migration(Id, [oracle_runs(Run), header(Header), language(Lang), subject(none), judgment_subject(Subj)], Migration0)),
    relabel(Migration0, Migration),
    write_migration(Migration, Dir, P, report(LE, Issues, Counts, Fid)),
    include(issue_of(error), Issues, Errs), length(Errs, NE),
    include(issue_of(warning), Issues, Warns), length(Warns, NW),
    ( Fid = fidelity(Pa, Fa, U, _) -> true ; Pa = '-', Fa = '-', U = '-' ),
    format("~w  ~w  tests ~w pass ~w fail ~w error  ~w writer error(s), ~w warning(s)~n",
           [LE, Counts, Pa, Fa, U, NE, NW]),
    forall(member(E, Errs), ( print(E), nl )),
    forall(member(W, Warns), ( print(W), nl )).

%   A build says what the writer remarked as well as what it could not write:
%   a remark of its own (a group it had to write with the extensions, say) is
%   a reason a twin may answer nothing, and counting only the errors hid it.
issue_of(Severity, issue(Severity, _, _)).

%   A rule's citation opens the Catala file its definitions are in, as kept
%   under sources/.
source_document(Files0, R0, R) :-
    (   get_dict(catala_file, R0, I), nth1(I, Files0, F0)
    ->  atomic_list_concat(['sources/', F0], SD), atom_string(SD, S), del_dict(catala_file, R0, _, R1), R = R1.put(source_document, S)
    ;   del_dict(catala_file, R0, _, R) -> true
    ;   R = R0
    ).

roots_title(Roots, T) :- atomic_list_concat(Roots, ', ', A), format(string(T), "Catala scope(s) ~w", [A]).

header(Lang, P, Roots, H) :-
    atomic_list_concat(Roots, ', ', RA),
    (   Lang == fr
    ->  format(string(H), "~w — jumeau des champs d'application Catala ~w (catala-examples, Apache-2.0), avec les tests de leurs fichiers.~nTraduit par LE2 migration/catala.", [P, RA])
    ;   format(string(H), "~w — a twin of the Catala scope(s) ~w (catala-examples, Apache-2.0), with the tests of their files.~nTranslated by LE2 migration/catala.", [P, RA])
    ).

relabel(migration(Meta0, IR, L, T), migration(Meta, IR, L, T)) :-
    selectchk(source(_), Meta0, Meta1), selectchk(translator(_), Meta1, Meta2),
    selectchk(licence(_), Meta2, Meta3),
    Meta = [source('Catala (catala-examples)'), translator('LE2 migration/catala'),
            licence('Apache-2.0 (catala-examples, Inria and contributors)')|Meta3].

write_yaml(File, Term) :-
    setup_call_cleanup(open(File, write, S, [encoding(utf8)]), yaml_write(S, Term), close(S)).

%   The originals: the Catala files under sources/, and what the lowering
%   made of them, sources/cat/<programme>.yaml, the text the rules cite.
copy_sources(Ex, Files0, ModFile, Dir) :-
    forall(member(F0, Files0),
           ( atomic_list_concat([Ex, '/', F0], From), atomic_list_concat([Dir, '/sources/', F0], To),
             file_directory_name(To, TD), make_directory_path(TD), copy_file(From, To) )),
    atomic_list_concat([Dir, '/sources/cat'], SC), make_directory_path(SC),
    file_base_name(ModFile, B), atomic_list_concat([SC, '/', B], T1), copy_file(ModFile, T1),
    file_name_extension(Stem, yaml, ModFile), atom_concat(Stem, '.test.yaml', TF),
    file_base_name(TF, TB), atomic_list_concat([SC, '/', TB], T2), copy_file(TF, T2).


		 /*******************************
		 *            ORACLE            *
		 *******************************/

%   Each test scope run by Catala's interpreter on the module's compiled
%   objects (clerk test builds them, fetch_sources.sh runs it): pass when
%   its assertions hold. The runs are cached, keyed by the files' text.
oracle(Ex, Files, Includes, Tests, RunFile, Run) :-
    files_key(Files, Tests, Key),
    (   exists_file(RunFile),
        setup_call_cleanup(open(RunFile, read, In), json_read_dict(In, Run0), close(In)),
        get_dict(key, Run0, K0), atom_string(Key, K0)
    ->  Run = Run0
    ;   findall(C, ( member(T, Tests), get_dict(name, T, Name),
                     (   get_dict(why_not, T, W)
                     ->  C = _{name: Name, status: untranslated, why: W}
                     ;   get_dict(generated, T, true)
                     ->  C = _{name: Name, status: pass, why: "a generated case: the expected answers are Catala's"}
                     ;   get_dict(unread_assertions, T, NU)
                     ->  format(string(W), "~w of the test's assertions are not read by the translator (structures, lists)", [NU]),
                         C = _{name: Name, status: untranslated, why: W}
                     ;   %  a case split from a test scope (an assertion about one
                         %  structure) is that scope's run
                         ( get_dict(scope, T, Sc) -> true ; Sc = Name ),
                         run_test(Ex, Files, Includes, Sc, C0), C = C0.put(name, Name) ) ), Cs),
        Run = _{key: Key, engine: "catala interpret", cases: Cs},
        setup_call_cleanup(open(RunFile, write, Out), json_write_dict(Out, Run, [width(0)]), close(Out))
    ).

%   The key covers the Catala files' text and the translator's own reading of
%   their test scopes: which cases it can take and what each expects. Keyed
%   on the text alone, a cached "untranslated" would survive a change in the
%   lowering that makes the case readable, and the interpreter would never be
%   asked for its answer.
files_key(Files, Tests, Key) :-
    maplist([F, T]>>read_file_to_string(F, T, []), Files, Ts),
    atomic_list_concat(Ts, Text),
    findall(N-W,
            ( member(T, Tests), get_dict(name, T, N),
              (   get_dict(why_not, T, W0) -> W = why(W0)
              ;   get_dict(unread_assertions, T, U) -> W = unread(U)
              ;   get_dict(output, T, O) -> W = out(O)
              ;   W = none
              ) ),
            Shape),
    variant_sha1(Text-Shape, Key).

run_test(Ex, Files, Includes, Name, _{name: Name, status: Status, why: Why}) :-
    member(F, Files), read_file_to_string(F, T, []), sub_string(T, _, _, _, Name), !,
    findall(['-I', D1, '-I', D2], ( member(I, Includes),
                                    atomic_list_concat([Ex, '/_build/', I], D1),
                                    atomic_list_concat([Ex, '/', I], D2) ), IAs0), append(IAs0, IAs),
    format(atom(SA), '--scope=~w', [Name]),
    append([[interpret], IAs, [F, SA]], Args),
    catala_env(Env), here(H), atomic_list_concat([H, '/.cache/deb/usr/bin/catala'], Catala),
    catch(( process_create(Catala, Args, [stdout(pipe(O)), stderr(std), cwd(Ex), env(Env), process(Pid)]),
            read_string(O, _, Out), close(O), process_wait(Pid, exit(X)) ), E, ( X = error, Out = "", print_message(error, E) )),
    (   X == 0, ( sub_string(Out, _, _, _, "successful") ; sub_string(Out, _, _, _, "[RESULT]") ),
        \+ sub_string(Out, _, _, _, "[ERROR]")
    ->  Status = pass, Why = ""            % (its assertions held: a scope with outputs prints them)
    ;   Status = fail, ( string_length(Out, L), L > 300 -> sub_string(Out, 0, 300, _, Why) ; Why = Out )
    ).

%   PATH and the OCaml variables of ~/ocamlroot/env.sh (the toolchain).
catala_env(Env) :-
    getenv('HOME', Home), here(H),
    atomic_list_concat([Home, '/ocamlroot'], R),
    atomic_list_concat([R, '/usr/lib/x86_64-linux-gnu/ocaml/5.3.0'], L),
    getenv('PATH', P0),
    atomic_list_concat([R, '/wrap:', R, '/usr/bin:', H, '/.cache/deb/usr/bin:', P0], Path),
    atomic_list_concat([R, '/findlib.conf'], FC),
    atomic_list_concat([L, '/stublibs'], SL),
    Env = ['PATH'=Path, 'OCAMLLIB'=L, 'OCAMLFIND_CONF'=FC, 'CAML_LD_LIBRARY_PATH'=SL, 'HOME'=Home].


		 /*******************************
		 *        GENERATED CASES       *
		 *******************************/

%   A programme without test scopes (corpus.pl, generated/4): one test
%   scope per combination of the grid's values, in a file of its own
%   (.cache/catala-examples/gen/<programme>), run by the interpreter; the
%   case's facts are the grid's values, its expected answers the outputs
%   the interpreter gives.
generated_cases(P, Lang, Ex, Includes, Cases) :-
    (   generated(P, Sub, Usages, Grid)
    ->  findall(Combo, grid_combo(Grid, Combo), Combos),
        length(Combos, N), numlist(1, N, Is),
        atomic_list_concat([Ex, '/gen'], GD), make_directory_path(GD),
        ( Lang == fr -> Ext = catala_fr ; Ext = catala_en ),
        format(atom(GF), '~w/gen_~w.~w', [GD, P, Ext]),
        setup_call_cleanup(open(GF, write, S, [encoding(utf8)]),
                           write_gen_file(S, Lang, Usages, Sub, Is, Combos), close(S)),
        atom_concat('cat:', P, Mid),
        findall(C, ( nth1(I, Combos, Combo), gen_case(Ex, Includes, GF, Mid, I, Combo, C) ), Cases)
    ;   Cases = []
    ).

grid_combo([], []).
grid_combo([V-Vals|Rest], [V-X|Combo]) :- member(X, Vals), grid_combo(Rest, Combo).

write_gen_file(S, Lang, Usages, Sub, Is, Combos) :-
    forall(member(U, Usages), ( Lang == fr -> format(S, "> Usage de ~w~n~n", [U]) ; format(S, "> Using ~w~n~n", [U]) )),
    forall(nth1(I, Combos, Combo), write_gen_scope(S, Lang, Sub, I, Combo)).

write_gen_scope(S, fr, Sub, I, Combo) :-
    format(S, "```catala~n#[test]~ndéclaration champ d'application Gen~w:~n  résultat sous_champ champ d'application ~w~n~n", [I, Sub]),
    format(S, "champ d'application Gen~w:~n", [I]),
    forall(member(V-X, Combo), format(S, "  définition sous_champ.~w égal à ~w~n", [V, X])),
    format(S, "```~n~n", []).
write_gen_scope(S, en, Sub, I, Combo) :-
    format(S, "```catala~n#[test]~ndeclaration scope Gen~w:~n  output sub_scope scope ~w~n~n", [I, Sub]),
    format(S, "scope Gen~w:~n", [I]),
    forall(member(V-X, Combo), format(S, "  definition sub_scope.~w equals ~w~n", [V, X])),
    format(S, "```~n~n", []).

gen_case(Ex, Includes, GF, Mid, I, Combo, Case) :-
    format(atom(Name), 'Gen~w', [I]),
    findall(['-I', D1, '-I', D2], ( member(Inc, Includes),
                                    atomic_list_concat([Ex, '/_build/', Inc], D1),
                                    atomic_list_concat([Ex, '/', Inc], D2) ), IAs0), append(IAs0, IAs),
    format(atom(SA), '--scope=~w', [Name]),
    append([[interpret], IAs, [GF, SA, '-F', json]], Args),
    catala_env(Env), here(H), atomic_list_concat([H, '/.cache/deb/usr/bin/catala'], Catala),
    process_create(Catala, Args, [stdout(pipe(O)), stderr(pipe(E)), cwd(Ex), env(Env), process(Pid)]),
    read_string(O, _, Out0), read_string(E, _, Err), close(O), close(E), process_wait(Pid, _),
    ( Out0 == "" -> Out = Err ; Out = Out0 ),
    findall(K-V, ( member(Var-X, Combo), gen_value(X, V), format(atom(K), '~w#input.~w', [Mid, Var]) ), InPairs),
    dict_pairs(In, _, InPairs),
    (   catch(( atom_json_dict(Out, J, []), get_dict(_, J, Outs) ), _, fail)
    ->  findall(K-V, ( get_dict(Var, Outs, V0), gen_out(V0, V), format(atom(K), '~w#~w', [Mid, Var]) ), OutPairs),
        dict_pairs(Out1, _, OutPairs),
        Case = _{name: Name, input: In, output: Out1, generated: true}
    ;   %  Catala gives no answer (a conflict between definitions): the case is
        %  kept, left out of the twin, with Catala's reason
        ( sub_string(Out, _, _, _, "conflict") -> W = "Catala stops with a conflict: two definitions apply at once" ; W = "Catala gives no answer" ),
        Case = _{name: Name, input: In, output: _{}, generated: true, why_not: W}
    ).

%   A grid value as a fact's value: |2019-06-15| a date, A.B.C the constructor C.
gen_value(X, V) :-
    (   atom_concat('|', R0, X), atom_concat(D, '|', R0) -> atom_string(D, V)
    ;   atomic_list_concat(Ps, '.', X), last(Ps, C) -> atom_string(C, V)
    ).

%   An output of the interpreter: an amount "10.03", a number, a Boolean.
gen_out(V0, V) :-
    (   string(V0), number_string(N, V0) -> V = N
    ;   V = V0
    ).

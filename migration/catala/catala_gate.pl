/*  The gate of Phase 3c (roadmap.md §8): the reader's exception tree of
    every variable of the programmes' scopes, compared with the compiler's
    own (`catala exceptions --output-format=json`).

        ./myswipl.sh -q migration/catala/catala_gate.pl

    A tree is compared by its labels, the lines of the definitions under
    each, and the labels of its exceptions; the compiler's base case
    (unlabelled) is `base_case`. Results in runs/gate.txt.
*/

:- initialization(main, main).

:- use_module(library(main)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(filesex)).
:- use_module(corpus).
:- use_module(catala_reader).

here(D) :- module_property(catala_corpus, file(F)), file_directory_name(F, D).

main(_) :-
    here(H), atomic_list_concat([H, '/.cache/catala-examples'], Ex),
    %  (the housing allowance's files only with CATALA_GATE_ALL=1: Catala's
    %  exceptions command takes some 4 GB and minutes per variable on them)
    findall(P-F-Inc, ( programme(P, _, Files, _, Inc), member(F, Files), \+ sub_atom(F, _, _, _, tests),
                       ( getenv('CATALA_GATE_ALL', _) ; \+ sub_atom(F, 0, _, _, aides_logement) ) ), PFs0),
    sort(PFs0, PFs),
    findall(R, ( member(_-F-Inc, PFs), atomic_list_concat([Ex, '/', F], Path),
                 file_variable(Path, S, V, Mine), compare_tree(Ex, Inc, Path, S, V, Mine, R) ), Rs),
    include(==(same), Rs, Same), length(Same, NS), length(Rs, N),
    atomic_list_concat([H, '/runs'], RD), make_directory_path(RD),
    atomic_list_concat([RD, '/gate.txt'], Out),
    setup_call_cleanup(open(Out, write, St),
        ( format(St, "exception trees equal to the compiler's: ~w of ~w~n", [NS, N]),
          forall(( member(R, Rs), R \== same ), format(St, "~q~n", [R])) ),
        close(St)),
    format("exception trees equal to the compiler's: ~w of ~w~n", [NS, N]),
    forall(( member(R, Rs), R \== same ), ( print(R), nl )).

%   The variables a file defines, with the reader's tree of each.
file_variable(Path, S, V, Tree) :-
    read_catala_file(Path, catala(_, Items)),
    findall(S0-I, ( member(code(_, CIs, _), Items), member(scope_use(S0, _, Is, _, _), CIs), member(I, Is),
                    I =.. [K|_], memberchk(K, [def, rule]) ), SIs),
    findall(S0-V0, ( member(S0-I, SIs), arg(3, I, [V0]) ), SVs0), sort(SVs0, SVs),
    member(S-V, SVs),
    findall(p(L, E, Line), ( member(S-I, SIs), arg(3, I, [V]), arg(1, I, L), arg(2, I, E), arg(8, I, Line) ), Ps),
    reader_tree(Ps, Tree).

%   label-[lines]-[exception labels], sorted; the unlabelled base case is
%   base_case, an unlabelled exception's group anonymous.
reader_tree(Ps, Tree) :-
    findall(G, ( member(p(L, E, _), Ps), group_of(L, E, G) ), Gs0), sort(Gs0, Gs),
    findall(G-Lines-Excs,
            ( member(G, Gs),
              findall(Line, ( member(p(L, E, Line), Ps), group_of(L, E, G) ), Lines0), sort(Lines0, Lines),
              findall(XG, ( member(p(L, E, _), Ps), exception_to(E, G), group_of(L, E, XG) ), Excs0), sort(Excs0, Excs) ),
            Tree).

group_of(none, none, base_case) :- !.
group_of(none, unlabeled, exception(anonymous)) :- !.
group_of(none, to(T), exception(T)) :- !.
group_of(L, _, L).

exception_to(unlabeled, base_case).
exception_to(to(T), T).

compare_tree(Ex, Inc, Path, S, V, Mine, Result) :-
    findall(['-I', D1, '-I', D2], ( member(I, Inc), atomic_list_concat([Ex, '/_build/', I], D1),
                                    atomic_list_concat([Ex, '/', I], D2) ), IAs0), append(IAs0, IAs),
    format(atom(SA), '-s~w', [S]), format(atom(VA), '-v~w', [V]),
    master(Path, Master),
    append([[exceptions], IAs, [Master, SA, VA, '--output-format=json']], Args),
    catala(Ex, Args, Out),
    (   catch(atom_json_dict(Out, J, []), _, fail)
    ->  get_dict(trees, J, Trees), compiler_tree(Trees, Theirs),
        (   normal(Mine, M1), normal(Theirs, T1), M1 == T1 -> Result = same
        ;   Result = differs(S, V, reader(Mine), compiler(Theirs))
        )
    ;   Result = no_answer(S, V)
    ).

%   The file the compiler is given: the module's master file when Path is
%   included by one (> Inclusion: / > Include:), else Path itself.
master(Path, Master) :-
    file_directory_name(Path, D), file_base_name(Path, B),
    directory_files(D, Fs),
    (   member(F, Fs), F \== B, ( file_name_extension(_, catala_fr, F) ; file_name_extension(_, catala_en, F) ),
        atomic_list_concat([D, '/', F], MP), read_file_to_string(MP, T, []),
        sub_string(T, _, _, _, "> Module"), sub_string(T, _, _, _, B)
    ->  Master = MP
    ;   Master = Path
    ).

%   The compiler's trees in the reader's form (the labels of anonymous
%   exceptions are not compared: only that they are exceptions).
compiler_tree(Trees, Tree) :-
    findall(N, ( member(T, Trees), tree_nodes(T, none, N) ), Ns0), append(Ns0, Ns), sort(Ns, Tree).

tree_nodes(T, _, [G-Lines-Excs|Sub]) :-
    get_dict(label, T, L0), atom_string(L, L0), node_group(L, G),
    get_dict(rules, T, Rs), findall(Ln, ( member(R, Rs), get_dict(pos, R, P), get_dict(start_line, P, Ln) ), Lines0), sort(Lines0, Lines),
    get_dict(exceptions, T, Xs),
    findall(XG, ( member(X, Xs), get_dict(label, X, XL0), atom_string(XL, XL0), node_group(XL, XG0), exc_group(XG0, XG) ), Excs0), sort(Excs0, Excs),
    findall(N, ( member(X, Xs), tree_nodes(X, G, N) ), Subs0), append(Subs0, Sub0),
    findall(XG-XLs-XEs, ( member(XG0-XLs-XEs, Sub0), exc_group(XG0, XG) ), Sub).

node_group(L, G) :- ( L == base_case -> G = base_case ; G = L ).
exc_group(G0, G) :-
    (   ( G0 == base_case ; compound(G0) ) -> G = G0      % (a nested group already named)
    ;   ( sub_atom(G0, 0, _, _, '<') ; sub_atom(G0, 0, _, _, exception_to_) ) -> G = exception(anonymous)   % (an unlabelled exception)
    ;   G = G0
    ).

%   Both forms with an exception group named by its label only.
normal(Tree0, Tree) :-
    maplist([G0-Ls-Es0, G-Ls-Es]>>( norm_g(G0, G), maplist(norm_g, Es0, Es1), sort(Es1, Es) ), Tree0, Tree1),
    msort(Tree1, Tree).
norm_g(exception(T), T) :- T \== anonymous, !.
norm_g(G, G).

catala(Ex, Args, Out) :-
    getenv('HOME', Home), here(H),
    atomic_list_concat([Home, '/ocamlroot'], R),
    atomic_list_concat([R, '/usr/lib/x86_64-linux-gnu/ocaml/5.3.0'], L),
    getenv('PATH', P0), atomic_list_concat([R, '/wrap:', R, '/usr/bin:', P0], Path),
    atomic_list_concat([R, '/findlib.conf'], FC), atomic_list_concat([L, '/stublibs'], SL),
    atomic_list_concat([H, '/.cache/deb/usr/bin/catala'], Catala),
    process_create(Catala, Args, [stdout(pipe(O)), stderr(null), cwd(Ex), process(Pid),
                                  env(['PATH'=Path, 'OCAMLLIB'=L, 'OCAMLFIND_CONF'=FC, 'CAML_LD_LIBRARY_PATH'=SL, 'HOME'=Home])]),
    read_string(O, _, Out), close(O), process_wait(Pid, _).

/*  Build the L4 twins into LogicalEnglish2/examples/migration/l4 (le2_paths:twins_dir/2).

    From /work (the LE2 checkout, which provides le_writer and le_migration):

        ./myswipl.sh -q migration/l4/build.pl               # the rules corpus
        ./myswipl.sh -q migration/l4/build.pl -- ID ...     # given corpus ids

    The expected answers are L4's own evaluator's: runs/<Id>.json for the
    directives, runs/variants/<Id>.json for the variants of a program whose
    facts are ASSUMEd (run here through l4_oracle.mjs when missing; needs
    Node.js and fetch_oracle.sh).
*/

:- initialization(main, main).

:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(library(main)).
:- use_module(library(filesex)).
:- use_module(library(process)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(l4_reader).
:- use_module(l4_twin).
:- use_module(corpus).
:- use_module(le2(le_migration)).
:- catch(use_module(l4_contracts, []), _, true).

:- dynamic here_/1.
:- prolog_load_context(directory, D), retractall(here_(_)), assertz(here_(D)).

main(Argv) :-
    twins_dir(l4, Out),
    make_directory_path(Out),
    (   Argv == [] -> rules_corpus(Ids) ; maplist([A, I]>>atom_string(I, A), Argv, Ids) ),
    forall(member(Id, Ids),
           ( format("~w ... ", [Id]), flush_output,
             (   catch(build(Id, Out), E, ( print_message(error, E), fail )) -> true
             ;   format("FAILED~n")
             ) )).

rules_corpus(Ids) :- findall(Id, ( l4_rules_file(Id), \+ l4_corpus:unpublished(Id) ), Ids).

twin_dir_name(Id, Name) :- l4_twin_dir_name(Id, Name).

build(Id, Root) :-
    step((corpus_path(Id, File))),
    step((twin_dir_name(Id, Name))),
    step((atomic_list_concat([Root, '/', Name], Dir))),
    step((make_directory_path(Dir))),
    step((atomic_list_concat([Dir, '/sources'], SD), make_directory_path(SD))),
    step((file_base_name(File, B), atomic_list_concat([SD, '/', B], Copy))),
    step((copy_file(File, Copy))),
    step((cache_dir(CD), atomic_list_concat([CD, '/LICENSE'], Lic))),
    step((( exists_file(Lic) -> atomic_list_concat([SD, '/LICENSE'], LD), copy_file(Lic, LD) ; true ))),
    step((ensure_variants(Id, File))),
    step((twin_migration(File, [id(Id), name(Name), source_copy(B)], Migration))),
    step((( Migration = migration(_, program(Hd, _), _, _), memberchk(includes(Libs), Hd) -> forall(member(Lb, Libs), copy_library(Lb, Dir)) ; true ))),
    step((write_migration(Migration, Dir, Name, report(LE, Issues, Counts, Fid)))),
    step((include([issue(S, _, _)]>>(S == error), Issues, Errs), length(Errs, NE))),
    step((( Fid = fidelity(P, Fa, U, _) -> true ; P = '-', Fa = '-', U = '-' ))),
    step((format("~w  ~w  pass ~w fail ~w error ~w  ~w writer error(s)~n", [LE, Counts, P, Fa, U, NE]))).

step(G) :- ( call(G) -> true ; format("~n  step failed: ~q~n", [G]), fail ).

%   The variants of a program whose facts are ASSUMEd, run by the evaluator
ensure_variants(Id, File) :-
    here_(H), atomic_list_concat([H, '/runs/variants'], VD), make_directory_path(VD),
    atomic_list_concat([VD, '/', Id, '.json'], Out),
    l4_read_file(File, Model),
    variant_jobs(File, Model, Jobs),
    length(Jobs, NJ),
    variants_hash(Jobs, Hash),
    (   NJ =:= 0 -> true
    ;   exists_file(Out), setup_call_cleanup(open(Out, read, S), json_read_dict(S, Old), close(S)),
        atom_string(Hash, HS), Old.get(hash) == HS -> true
    ;   tmp_file(l4v, TD), make_directory_path(TD),
        findall(F, ( nth1(I, Jobs, job(_, _, Text)), format(atom(F), "~w/v~w.l4", [TD, I]),
                     setup_call_cleanup(open(F, write, O, [encoding(utf8)]), write(O, Text), close(O)) ), Fs),
        atomic_list_concat([H, '/l4_oracle.mjs'], Oracle),
        process_create(path(timeout), ['600', node, Oracle, eval|Fs], [stdout(pipe(P))]),
        read_string(P, _, Lines0), close(P),
        split_string(Lines0, "\n", "\n", Ls0), exclude(==(""), Ls0, Ls),
        maplist([L, D]>>atom_json_dict(L, D, []), Ls, Ds),
        setup_call_cleanup(open(Out, write, O2, [encoding(utf8)]), json_write_dict(O2, _{hash: Hash, runs: Ds}, [width(0)]), close(O2)),
        delete_directory_and_contents(TD)
    ).

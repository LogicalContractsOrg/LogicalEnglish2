/*  The way back, checked: each twin exported as Catala (catala_export.pl)
    and its test scopes run by Catala's interpreter.

        ./myswipl.sh -q migration/catala/catala_roundtrip.pl [-- twin.le ...]

    Without arguments, every twin of LE2's examples/migration/catala. A test
    passes when the interpreter computes it with its assertions holding.
    Results in runs/roundtrip.txt.
*/

:- initialization(main, main).

:- use_module(library(main)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(le2(le_kbs)).
:- use_module(catala_export).

here(D) :- module_property(catala_export, file(F)), file_directory_name(F, D).

main(Argv) :-
    (   Argv == []
    ->  twins_dir(catala, TD), findall(F, ( directory_member(TD, F, [recursive(true), extensions([le])]), \+ sub_atom(F, _, _, _, '/sources/') ), Fs0), sort(Fs0, Fs)
    ;   Fs = Argv
    ),
    findall(L, ( member(F, Fs), roundtrip(F, L) ), Ls),
    here(H), atomic_list_concat([H, '/runs'], RD), make_directory_path(RD),
    atomic_list_concat([RD, '/roundtrip.txt'], Out),
    setup_call_cleanup(open(Out, write, S), forall(member(L, Ls), format(S, "~w~n", [L])), close(S)),
    forall(member(L, Ls), format("~w~n", [L])).

roundtrip(File, Line) :-
    file_base_name(File, B), file_name_extension(Stem, _, B),
    read_file_to_string(File, Text, []), file_directory_name(File, Dir),
    (   sub_string(Text, _, _, _, "% RESIDUE")
    ->  format(string(Line), "~w: not exported: the program has residue blocks (untranslated parts would become inputs)", [Stem])
    ;   roundtrip_kb(File, Stem, Text, Dir, Line)
    ).

roundtrip_kb(File, Stem, Text, Dir, Line) :-
    _ = File,
    le_kbs:load_text(Text, Dir, KB),
    atom_codes(Stem, [C|Cs]), code_type(C, to_lower(U)), atom_codes(Mod0, [U|Cs]), atom_concat('Rt_', Stem, Mod1),
    atom_codes(Mod1, Ms), Ms = [_|_], Mod = Mod1, _ = Mod0,
    b_setval(cat_module, Mod),
    (   catch(catala_module(KB, M, T), error(catala_export_refused(Ps), _), ( M = none, T = Ps ))
    ->  (   M == none
        ->  length(T, NP), format(string(Line), "~w: refused (~w problem(s)): ~q", [Stem, NP, T])
        ;   here(H), atomic_list_concat([H, '/.cache/catala-examples/gen'], GD), make_directory_path(GD),
            format(atom(GF), '~w/~w.catala_en', [GD, Mod]),
            format(string(All), "~s~n~s", [M, T]),
            setup_call_cleanup(open(GF, write, S, [encoding(utf8)]), write(S, All), close(S)),
            findall(Sc, ( sub_atom(All, _, _, _, 'declaration scope Test'), fail ; between(1, 10000, I), format(atom(Sc), 'Test~w', [I]),
                          format(atom(Decl), 'declaration scope ~w:', [Sc]), ( sub_atom(All, _, _, _, Decl) -> true ; !, fail ) ), Scs),
            foldl(run(GF), Scs, 0-0, Pa-Fa), length(Scs, N),
            format(string(Line), "~w: ~w pass, ~w fail of ~w", [Stem, Pa, Fa, N])
        )
    ;   format(string(Line), "~w: the exporter failed", [Stem])
    ).

run(GF, Sc, P0-F0, P-F) :-
    format(atom(SA), '--scope=~w', [Sc]),
    catala(['interpret', GF, SA], Out),
    (   sub_string(Out, _, _, _, "[RESULT]") -> P is P0 + 1, F = F0 ; P = P0, F is F0 + 1 ).

catala(Args, Out) :-
    getenv('HOME', Home), here(H),
    atomic_list_concat([Home, '/ocamlroot'], R),
    atomic_list_concat([R, '/usr/lib/x86_64-linux-gnu/ocaml/5.3.0'], L),
    getenv('PATH', P0), atomic_list_concat([R, '/wrap:', R, '/usr/bin:', P0], Path),
    atomic_list_concat([R, '/findlib.conf'], FC), atomic_list_concat([L, '/stublibs'], SL),
    atomic_list_concat([H, '/.cache/deb/usr/bin/catala'], Catala),
    atomic_list_concat([H, '/.cache/catala-examples'], Ex),
    %  (its errors and its output in one stream: read one after the other,
    %  a long error message would block both sides)
    maplist([A, Q]>>format(atom(Q), "'~w'", [A]), [Catala|Args], Qs), atomic_list_concat(Qs, ' ', Cmd0),
    atom_concat(Cmd0, ' 2>&1', Cmd),
    process_create(path(sh), ['-c', Cmd], [stdout(pipe(O)), cwd(Ex), process(Pid),
                                  env(['PATH'=Path, 'OCAMLLIB'=L, 'OCAMLFIND_CONF'=FC, 'CAML_LD_LIBRARY_PATH'=SL, 'HOME'=Home])]),
    read_string(O, _, Out), close(O), process_wait(Pid, _).

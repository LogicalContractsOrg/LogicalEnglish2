/*  Step 7's gates: the way back.

        ./myswipl.sh -q -g "consult('migration/lomo/lomo_roundtrip.pl')" -g "lomo_roundtrip:main" -t halt
        ./myswipl.sh -q -g "consult('migration/lomo/lomo_roundtrip.pl')" -g "lomo_roundtrip:examples" -t halt

    main/0: every register goes back to Turtle (lomo_export.pl), and the
    result is the same graph as the description it came from (rdflib's
    graph isomorphism, oracle/iso_judge.py: blank nodes included).
    examples/0: LE2's examples that cite their provisions and the
    LegalRuleML twins export as descriptions, valid by LOMO's rules, or are
    refused with their reasons.

    Copyright Miguel Calejo; Apache License 2.0.
*/

:- module(lomo_roundtrip, [roundtrip/1, examples_export/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module('../le2_paths', [twins_dir/2]).
:- use_module(le2(le_kbs)).
:- use_module(lomo_export).
:- use_module(lomo_shacl, [check_file/2]).
:- use_module(lomo_twin, [twin_name/2]).
:- use_module(corpus).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(D)), assertz(here(D)).

register_of(TTL, LE) :-
    lomo_file(Set, TTL), twins_dir(lomo, Root), twin_name(TTL, Name),
    atomic_list_concat([Root, '/', Set, '/', Name, '.le'], LE).

iso(A, B, Out) :-
    here(H), atomic_list_concat([H, '/oracle/.venv/bin/python'], Py),
    atomic_list_concat([H, '/oracle/iso_judge.py'], J),
    process_create(Py, [J, A, B], [stdout(pipe(O)), stderr(null), process(P)]),
    read_string(O, _, Out), close(O), process_wait(P, _).

%   roundtrip(-Results): [rt(TTL, same(N) | different(Text))]
roundtrip(Results) :-
    tmp_file_stream(text, Tmp0, S0), close(S0), atom_concat(Tmp0, '.ttl', Tmp),
    findall(rt(TTL, V),
            ( lomo_file(_, TTL), register_of(TTL, LE), exists_file(LE),
              load(LE, KB),
              export_lomo(KB, [file(LE)], R),
              (   R = exported(_, Text, _, _)
              ->  setup_call_cleanup(open(Tmp, write, S, [encoding(utf8)]), write(S, Text), close(S)),
                  iso(TTL, Tmp, Out),
                  ( sub_string(Out, 0, _, _, "same ") -> split_string(Out, " \n", " \n", [_, NS|_]), number_string(N, NS), V = same(N)
                  ; V = different(Out) )
              ;   V = refused(R)
              ) ),
            Results).

main :-
    roundtrip(Rs),
    forall(( member(rt(F, V), Rs), V \= same(_) ), ( file_base_name(F, B), format("~w: ~w~n", [B, V]) )),
    length(Rs, N),
    aggregate_all(count, member(rt(_, same(_)), Rs), NS),
    aggregate_all(sum(K), member(rt(_, same(K)), Rs), NT),
    format("the way back: ~w of ~w registers give the same graph again (~w statements)~n", [NS, N, NT]).

%   ---- LE2's examples and the LegalRuleML twins -------------------------

example_file(F) :-
    le2_paths:le2_dir(D),
    member(Sub, ['examples/moreExamples', 'examples/regulatory', 'examples/migration/legalruleml']),
    atomic_list_concat([D, '/', Sub], Dir),
    directory_member(Dir, F, [extensions([le]), recursive(true)]),
    \+ sub_atom(F, _, _, _, '/sources/'),
    file_base_name(F, B), \+ memberchk(B, ['deontic.le', 'temporal.le', 'lomo.le', 'rounding.le', 'text.le', 'maths.le', 'lists.le', 'feel.le']),
    read_file_to_string(F, T, []),
    sub_string(T, _, _, _, "with provenance"),
    \+ sub_string(T, _, _, _, "target language is: lps").

%   examples_export(-Results): [ex(File, exported(N, Valid) | refused(Reasons) | error(E))]
examples_export(Results) :-
    tmp_file_stream(text, Tmp0, S0), close(S0), atom_concat(Tmp0, '.ttl', Tmp),
    findall(ex(F, V),
            ( example_file(F),
              catch(( load(F, KB),
                      export_lomo(KB, [file(F)], R),
                      (   R = exported(_, Text, _, _)
                      ->  setup_call_cleanup(open(Tmp, write, S, [encoding(utf8)]), write(S, Text), close(S)),
                          check_file(Tmp, VRs), length(VRs, NV),
                          rdf_count(Tmp, NT),
                          V = exported(NT, NV)
                      ;   R = refused(Ps), findall(M, member(problem(_, M), Ps), Ms), V = refused(Ms)
                      ) ), E, V = error(E)) ),
            Results).

rdf_count(F, N) :- semweb_turtle:rdf_read_turtle(F, Ts, []), length(Ts, N).

examples :-
    examples_export(Rs),
    forall(member(ex(F, V), Rs),
           ( le2_paths:le2_dir(D), atom_concat(D, Rel, F),
             (   V = exported(N, 0) -> format("exported, valid: ~w (~w statements)~n", [Rel, N])
             ;   V = exported(N, K) -> format("exported, ~w validity results: ~w (~w statements)~n", [K, Rel, N])
             ;   V = refused(Ms) -> Ms = [M|_], length(Ms, NM), format("refused (~w reasons): ~w~n   e.g. ~w~n", [NM, Rel, M])
             ;   format("ERROR ~w: ~q~n", [Rel, V])
             ) )),
    length(Rs, All),
    aggregate_all(count, member(ex(_, exported(_, 0)), Rs), Valid),
    aggregate_all(count, member(ex(_, exported(_, K)), Rs), Exported), K = K,
    aggregate_all(count, member(ex(_, refused(_)), Rs), Refused),
    format("~nexamples that cite provisions: ~w; exported ~w (valid ~w), refused with reasons ~w~n", [All, Exported, Valid, Refused]).

:- use_module(library(semweb/turtle), []).

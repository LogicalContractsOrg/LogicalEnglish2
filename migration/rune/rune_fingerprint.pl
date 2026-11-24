:- module(rune_fingerprint, [
    kb_fingerprints/3,      % +KB, +Functors, -[F/A-Hash]
    own_functors/2,         % +KB, -[F/A]: those with a clause in the program's own text
    write_fingerprints/3,   % +File, +KB, +Functors
    read_fingerprints/2     % +File, -[F/A-Hash]
]).
/** <module> What a twin's rules were when it was written

The way back writes as Rune only the rules a user changed: build.pl records
a fingerprint of each predicate of the twin's main file
(<twin>.fingerprints.pl), and rune_export.pl compares the program it is
given with them. A fingerprint is a hash of the predicate's clauses as LE2
compiled them, without the positions of their conditions in the text
(le_at/3) and with their variables numbered, so that moving a rule, or
editing another one, does not change it.
*/

kb_fingerprints(KB, Functors, Pairs) :-
    findall(F/A-H, ( member(F/A, Functors), fingerprint(KB, F, A, H) ), Pairs).

fingerprint(KB, F, A, H) :-
    functor(Head, F, A),
    findall(C, ( catch(clause(KB:Head, Body), _, fail), strip((Head :- Body), C0), copy_term(C0, C), numbervars(C, 0, _) ), Cs),
    Cs \== [],
    term_hash(Cs, H).

strip(V, V) :- var(V), !.
strip(le_at(G, _, _), S) :- !, strip(G, S).
strip(T, S) :- compound(T), !, T =.. [F|As], maplist(strip, As, Bs), S =.. [F|Bs].
strip(T, T).

%   The predicates with a clause written in the program itself, not in a
%   resource it includes (LE2 shifts a resource's positions into a range of
%   their own, le_kbs:resource_base/2).
own_functors(KB, Fs) :-
    findall(F/A, ( current_predicate(KB:F/A), \+ sub_atom(F, 0, _, _, '$'),
                   functor(H, F, A), \+ predicate_property(KB:H, imported_from(_)),
                   once(( catch(clause(KB:H, B), _, fail), sub_term(le_at(_, S, _), B), integer(S), S < 10000000 )) ), Fs0),
    sort(Fs0, Fs).

write_fingerprints(File, KB, Functors) :-
    kb_fingerprints(KB, Functors, Pairs),
    setup_call_cleanup(open(File, write, S),
        ( format(S, "% The fingerprints of the twin's own predicates when it was written (rune_fingerprint.pl).~n", []),
          forall(member(P, Pairs), format(S, "~q.~n", [P])) ),
        close(S)).

read_fingerprints(File, Pairs) :-
    (   exists_file(File)
    ->  setup_call_cleanup(open(File, read, S), read_all(S, Pairs), close(S))
    ;   Pairs = []
    ).

read_all(S, Ps) :- read_term(S, T, []), ( T == end_of_file -> Ps = [] ; Ps = [T|Rest], read_all(S, Rest) ).

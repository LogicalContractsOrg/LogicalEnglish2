/** <module> Logical English -> Miniscript: File ▸ Export to Another System

    The reverse of the translator: a Logical English program that says when
    `the coin can be spent`, in the vocabulary the twins use, written back
    as a Bitcoin spending policy — the `.policy` file ms_import.pl reads,
    with sipa's compilation to Miniscript, the descriptor when the program
    states the keys, and a Minsc link. Registered with LE2's exporter
    registry (le_import.pl, exporter/6) by migration/le_importers.pl, so the
    LE editor and the LPS2 IDE both offer it for such a program.

    Read back (by template, in any order, any nesting):

      the witness contains a signature by K         pk(K)
      the witness reveals the preimage of H         <kind>(H), the kind from
                                                    `the hash function of H is F`
      the coin has been confirmed for N blocks,     older(B)
        N >= B    (seconds: older with BIP 68's time flag)
      the spending transaction has the lock time    after(T)
        L, the lock time L is a block height (or a
        time), L >= T  (and the finality condition, which is consensus)
      N is the count of each K such that K is in    thresh(k, ...)
        [...] and ..., N >= k
      the condition C is met                        C's own rule
      rules concluding the coin can be spent        or of their bodies

    Keys are the program's `the public key of K is "..."` when stated (then
    the descriptor is real), else names made from the roles. What the
    exporter cannot read (a condition in another vocabulary) stops the
    export with a note naming it — it never drops a condition. Each problem
    is at the condition it is about (or, when the condition has no position,
    at its rule); one about the program as a whole (no spending rule, a
    policy that cannot be read) is nowhere.

    A partial export (le_import.pl: the refused program's clauses left out,
    the rest written) is refused here. A spending policy is one expression:
    the program without a rule is a policy without a spending path, and the
    program without a condition or a constraint a policy that lets the coin
    be spent where the program does not. The first can lock the coin for
    good (a recovery path left out), the second lets the wrong party spend
    it, and a policy is put on the chain as it is — there is no residue to
    read beside it. So the reply says which lines would have been left out,
    and nothing is written.

    The file says where its policy came from: a comment above it lists the
    lines of the rules and facts it was read from.
*/

:- module(ms_export, [export_miniscript/3, applies_miniscript/1, check_miniscript/3, kb_policy/3, canonical_policy/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(miniscript).
:- use_module(ms_chain).
:- use_module('../le2_paths', []).
:- use_module(le2(le_writer)).
:- use_module(le2(le_import), []).

%!  applies_miniscript(+KB) is semidet.
applies_miniscript(KB) :-
    kb_ir(KB, program(_, Items)),
    role_functor(Items, spendable, _),
    ( role_functor(Items, sig, _) ; role_functor(Items, pre, _) ), !.

%!  check_miniscript(+KB, +Options, -Problems) is det.
%
%   The check before the policy is written (le_import.pl, export_check/2):
%   every condition of a rule the policy is read from that is not in the
%   vocabulary above, with where it is — a policy without it would let the
%   coin be spent in cases the program does not allow. Rules the policy
%   does not read (the definition of a coin's age, say) are not the
%   policy's, and are no problem.
check_miniscript(_KB, Options, Problems) :-
    partial_residues(Options, Residues), !,
    findall(L, ( member(residue(L, _, _), Residues), integer(L) ), Ls0), sort(Ls0, Ls),
    (   Ls == [] -> LT = "of an included resource"
    ;   atomic_list_concat(Ls, ', ', LT0), format(string(LT), "~w", [LT0])
    ),
    format(string(M), "a spending policy cannot be written in part: without the clauses of lines ~w it would lose a spending path (the coin could be locked for good) or a condition (the coin could be spent where the program does not allow it)", [LT]),
    Problems = [problem(none, M)].
check_miniscript(KB, Options, Problems) :-
    kb_ir(KB, Options, IR),
    nb_setval(ms_export_unread, []),
    catch(( kb_policy(IR, _, _) -> Top = [] ; Top = [problem(none, "the program's spending policy could not be read")] ),
          E, ( message_text(E, M0), Top = [problem(none, M0)] )),
    nb_getval(ms_export_unread, Unread0), nb_setval(ms_export_unread, none),
    reverse(Unread0, Unread),
    IR = program(_, Items),
    findall(problem(Where, M),
            ( member(G, Unread), unread_where(Items, G, Where),
              (   Where = at(_, _)
              ->  M = "a condition Miniscript has no form for (a policy says only: signatures, hash preimages, relative and absolute time locks, and thresholds of them)"
              ;   format(string(M), "a condition Miniscript has no form for: ~q", [G])
              ) ),
            Ps0),
    list_to_set(Ps0, Ps),
    le_import:kb_constraint_problems(KB, "Miniscript", CPs),
    append([Top, Ps, CPs], Problems).

%   Where an unread condition stands: the first condition of the program
%   that is the same condition, up to its variables' names; else the rule
%   it is in (kb_to_ir/3's source/3 option).
unread_where(Items, G, at(S, E)) :-
    member(rule(_, B, _), Items), sub_term(X, B), compound(X), X = le_at(G0, S, E),
    strip(G0, G1), G1 =@= G, !.
unread_where(Items, G, at(S, E)) :-
    member(rule(_, B, O), Items), memberchk(source(_, S, E), O), integer(S),
    strip(B, B1), sub_term(X, B1), X =@= G, !.
unread_where(_, _, none).

%   The clauses a partial export left out (partial(Residues), a list: the
%   reader's request is partial(true)).
partial_residues(Options, Rs) :-
    member(partial(Rs), Options), is_list(Rs), Rs \== [], !.

%!  export_miniscript(+KB, +Options, -Result) is det.
%
%   Result is exported(...), or refused(Problems) when check_miniscript/3
%   finds a problem (unless Options has checked(true): le_import ran it).
export_miniscript(KB, Options, refused(Problems)) :-
    \+ memberchk(checked(true), Options),
    check_miniscript(KB, Options, Problems), Problems \== [], !.
export_miniscript(KB, Options, refused(Problems)) :-
    partial_residues(Options, _), !,
    check_miniscript(KB, Options, Problems).
export_miniscript(KB, Options, exported(FileName, Text, Notes, Links)) :-
    kb_ir(KB, Options, IR),
    kb_policy(IR, Policy, Info),
    Info = info(Name, Legend, Kinds, Real),
    ms_policy_text(Policy, PT0), atom_string(PT0, PT),
    policy_names(Policy, Legend, Kinds, Names),
    catch(( compile_named(Policy, Names, MS) -> Compiled = yes ; Compiled = no("the policy does not compile") ),
          E, ( message_text(E, Why0), Compiled = no(Why0) )),
    (   Compiled == yes
    ->  format(string(C1), "# sipa's compiler (P2WSH) makes it the Miniscript:~n#     ~w", [MS]),
        (   Real == true -> format(string(C2), "~n# the descriptor:~n#     wsh(~w)", [MS]) ; C2 = "" ),
        string_concat(C1, C2, CL), CLines = [CL], N1 = []
    ;   CLines = [], Compiled = no(Why),
        format(string(N0), "sipa's compiler does not compile this policy to sane Miniscript (~w); the policy is written, not a descriptor.", [Why]),
        N1 = [N0]
    ),
    (   catch(( minsc_code(Name, Policy, Names, Code), minsc_url(Code, MUrl) ), _, fail)
    ->  Links = [link("Try it in Minsc", MUrl)],
        format(string(ML), "# try it in Minsc (policy -> Miniscript -> Script -> address, in the browser):~n#     ~w", [MUrl]),
        MLines = [ML]
    ;   Links = [], MLines = []
    ),
    findall(L, ( member(K-R, Legend), format(string(L), "~w = ~w", [K, R]) ), LLines),
    format(string(H), "# The spending policy of the Logical English program ~w.", [Name]),
    (   Real == true -> KeyNote = [] ; KeyNote = ["# The program states no public keys: the keys are named after their roles."] ),
    format(string(TL), "# ~w", [Name]),
    provenance_lines(IR, PLines),
    append([[H, "#"], CLines, MLines, KeyNote,
            ["#", "# File > Open in the Logical English editor translates this file back into Logical English.", ""],
            LLines, [""], PLines, [TL, PT, ""]], Lines),
    atomic_list_concat(Lines, '\n', TextA), atom_string(TextA, Text),
    format(atom(FileName), '~w.policy', [Name]),
    length(Legend, NK), or_count(Policy, NP),
    format(string(N2), "~w key(s) and hash(es); the policy has ~w spending path(s).", [NK, NP]),
    append(N1, [N2], Notes).

or_count(or(A, B), N) :- !, or_count(A, NA), or_count(B, NB), N is NA + NB.
or_count(_, 1).

message_text(E, S) :- catch(message_to_codes(E, [], C), _, fail), !, string_codes(S, C).
message_text(E, S) :- format(string(S), "~q", [E]).

kb_ir(KB, IR) :- le_writer:kb_to_ir(KB, IR).
%   (with the program's text in Options, each rule and fact has its line)
kb_ir(KB, Options, IR) :- le_writer:kb_to_ir(KB, Options, IR).

%   Where the policy came from, as comment lines (le_import.pl,
%   "Provenance"): the lines of the rules that say when the coin can be
%   spent (each an `or` of the policy), of the conditions they name, and of
%   the facts that give the keys and hashes. The policy is one expression,
%   so one comment lists them all; the title stays the comment just above
%   the policy (ms_import.pl reads it so).
provenance_lines(program(_, Items), Lines) :-
    findall(R-F, ( role_text(R, _), role_functor(Items, R, F) ), Roles),
    group_lines(Items, Roles, [spendable], rule, "the coin can be spent", G1),
    group_lines(Items, Roles, [met], rule, "the conditions", G2),
    group_lines(Items, Roles, [public_key, hash_function, hash_value], fact, "the keys and hashes", G3),
    append([G1, G2, G3], Gs),
    (   Gs == [] -> Lines = []
    ;   atomic_list_concat(Gs, '; ', GT),
        format(string(L), "# From Logical English: ~w.", [GT]),
        Lines = [L]
    ).

group_lines(Items, Roles, Rs, Kind, What, Groups) :-
    findall(Line, ( member(R, Rs), memberchk(R-F, Roles),
                    ( Kind == rule -> member(rule(H, B, O), Items), B \== true
                    ; ( member(fact(H, O), Items) ; member(rule(H, true, O), Items) ) ),
                    functor(H, F, _), le_import:item_source_line(O, Line) ), Ls0),
    sort(Ls0, Ls),
    (   Ls == [] -> Groups = []
    ;   Ls = [One] -> format(string(G), "~w, line ~w", [What, One]), Groups = [G]
    ;   atomic_list_concat(Ls, ', ', LT), format(string(G), "~w, lines ~w", [What, LT]), Groups = [G]
    ).

		 /*******************************
		 *      THE PROGRAM, READ BACK  *
		 *******************************/

%   What each template of the twins' vocabulary means.
role_text(spendable, "the coin can be spent").
role_text(sig, "the witness contains a signature by *a key*").
role_text(pre, "the witness reveals the preimage of *a hash*").
role_text(age_blocks, "the coin has been confirmed for *a number* blocks").
role_text(age_seconds, "the coin has been confirmed for *a number* seconds").
role_text(locktime, "the spending transaction has the lock time *a number*").
role_text(lock_height, "the lock time *a number* is a block height").
role_text(lock_time, "the lock time *a number* is a time").
role_text(spent_in, "the spending transaction is in block *a height*").
role_text(spent_at, "the spending transaction is at the time *a time*").
role_text(met, "the condition *a condition* is met").
role_text(public_key, "the public key of *a key* is *a text*").
role_text(hash_function, "the hash function of *a hash* is *a function*").
role_text(hash_value, "the hash value of *a hash* is *a text*").

role_functor(Items, Role, F) :-
    role_text(Role, T),
    member(template(F, T0, _), Items), text_eq(T0, T), !.

text_eq(A, B) :- atom_string(A, SA), atom_string(B, SB), normalize_space(string(X), SA), normalize_space(string(X), SB).

%!  kb_policy(+IR, -Policy, -Info) is det.
%
%   Info = info(Name, Legend, Kinds, Real): the program's name; the legend
%   [KeyName-Role] of the written policy; Kinds [Hash-Function]; Real is
%   true when every key (and hash) has its value in the program.
kb_policy(program(Header, Items), Policy, info(Name, Legend, Kinds, Real)) :-
    ( memberchk(kb(Name0), Header) -> Name = Name0 ; Name = policy ),
    findall(R-F, ( role_text(R, _), role_functor(Items, R, F) ), Roles),
    memberchk(spendable-FS, Roles),
    findall(B, ( member(rule(H, B0, _), Items), functor(H, FS, 0), strip(B0, B) ), Bodies),
    (   Bodies == [] -> throw(error(format("the program has no rule concluding that the coin can be spent", []), _)) ; true ),
    maplist(body_policy(Items, Roles), Bodies, Ps),
    join_or(Ps, Policy1),
    facts_of(Items, Roles, public_key, PKs),
    facts_of(Items, Roles, hash_function, HFs),
    facts_of(Items, Roles, hash_value, HVs),
    %  roles -> the names the policy text uses
    miniscript:ms_keys(Policy1, KRoles),
    findall(hash(HR), sub_policy(Policy1, hash(_, HR)), HRoles0), list_to_set(HRoles0, HRoles),
    maplist(key_name(PKs), KRoles, KPairs),
    maplist(hash_name(HVs), HRoles, HPairs),
    append(KPairs, HPairs, Pairs),
    rename(Policy1, Pairs, HFs, Policy),
    findall(Nm-R, ( member(E-Nm, Pairs), arg(1, E, R) ), Legend),
    findall(Nm-K, ( member(hash(R)-Nm, Pairs), memberchk(R-K, HFs) ), Kinds),
    (   KPairs \== [], forall(member(_-N, KPairs), real_value(N)) -> Real = true ; Real = false ).

facts_of(Items, Roles, Role, Pairs) :-
    (   memberchk(Role-F, Roles)
    ->  findall(A-V, ( member(fact(Fact, _), Items), Fact =.. [F, A0, V0], unquote(A0, A), unquote(V0, V) ), Pairs0),
        findall(A-V, ( member(rule(Fact, true, _), Items), Fact =.. [F, A0, V0], unquote(A0, A), unquote(V0, V) ), Pairs1),
        append(Pairs0, Pairs1, Pairs)
    ;   Pairs = []
    ).

unquote(X, A) :- ( string(X) -> atom_string(A, X) ; A = X ).

key_name(PKs, Role, pk(Role)-Name) :-
    (   memberchk(Role-V, PKs) -> Name = V ; ms_chain_var_name(Role, Name) ).
hash_name(HVs, hash(Role), hash(Role)-Name) :-
    (   memberchk(Role-V, HVs) -> Name = V ; ms_chain_var_name(Role, Name) ).

ms_chain_var_name(Role, Name) :- ms_chain:var_name(Role, Name).

real_value(N) :- atom(N), ( ms_chain:real_key(N) -> true ; atom_length(N, L), memberchk(L, [40, 64]), ms_chain:hex_string(N) ).

rename(pk(R), Pairs, _, pk(N)) :- !, memberchk(pk(R)-N, Pairs).
rename(hash(K0, R), Pairs, HFs, hash(K, N)) :- !,
    memberchk(hash(R)-N, Pairs),
    ( memberchk(R-K1, HFs) -> K = K1 ; K = K0 ).
rename(and(A, B), P, H, and(A1, B1)) :- !, rename(A, P, H, A1), rename(B, P, H, B1).
rename(or(A, B), P, H, or(A1, B1)) :- !, rename(A, P, H, A1), rename(B, P, H, B1).
rename(thresh(K, Ps), P, H, thresh(K, Ps1)) :- !, rename_list(Ps, P, H, Ps1).
rename(X, _, _, X).

rename_list([], _, _, []).
rename_list([X|Xs], P, H, [Y|Ys]) :- rename(X, P, H, Y), rename_list(Xs, P, H, Ys).

sub_policy(P, P).
sub_policy(and(A, B), S) :- ( sub_policy(A, S) ; sub_policy(B, S) ).
sub_policy(or(A, B), S) :- ( sub_policy(A, S) ; sub_policy(B, S) ).
sub_policy(thresh(_, Ps), S) :- member(P, Ps), sub_policy(P, S).

join_or([P], P) :- !.
join_or([P|Ps], or(P, Q)) :- join_or(Ps, Q).
join_and([], true) :- !.
join_and([P], P) :- !.
join_and([P|Ps], and(P, Q)) :- join_and(Ps, Q).

%   LE's positions and the IR's variable records, away.
strip(V, V) :- var(V), !.
strip(le_at(G, _, _), S) :- !, strip(G, S).
strip(G, S) :- compound(G), !, G =.. [F|As], maplist(strip, As, Bs), S =.. [F|Bs].
strip(G, G).

%   A body: an and/or tree whose leaves are the vocabulary's literals,
%   comparisons and aggregates. A conjunction is read as a list: each
%   producer (the coin's age, the lock time, a count) with the comparisons
%   on its variable.
body_policy(Items, Roles, B, P) :-
    (   B = or(X, Y)
    ->  body_policy(Items, Roles, X, PX), body_policy(Items, Roles, Y, PY), P = or(PX, PY)
    ;   conj_list(B, Ls),
        conj_policy(Ls, Items, Roles, Ps),
        join_and(Ps, P)
    ).

conj_list(and(A, B), L) :- !, conj_list(A, LA), conj_list(B, LB), append(LA, LB, L).
conj_list(true, []) :- !.
conj_list(G, [G]).

conj_policy([], _, _, []).
conj_policy([G|Gs], Items, Roles, Ps) :-
    (   literal_policy(G, Gs, Items, Roles, P, Used)
    ->  subtract_eq(Gs, Used, Rest),
        ( P == none -> Ps = Ps1 ; Ps = [P|Ps1] ),
        conj_policy(Rest, Items, Roles, Ps1)
    ;   G = or(_, _)
    ->  body_policy(Items, Roles, G, P), Ps = [P|Ps1], conj_policy(Gs, Items, Roles, Ps1)
    ;   nb_current(ms_export_unread, U0), is_list(U0)          % checking: every one, then on
    ->  nb_setval(ms_export_unread, [G|U0]),
        conj_policy(Gs, Items, Roles, Ps)
    ;   term_string(G, GS),
        throw(error(format("a condition the Miniscript exporter does not read: ~w", [GS]), _))
    ).

subtract_eq([], _, []).
subtract_eq([X|Xs], Used, R) :- ( member(U, Used), U == X -> R = R1 ; R = [X|R1] ), subtract_eq(Xs, Used, R1).

role_of(Roles, G, Role, Args) :- compound(G), G =.. [F|Args], memberchk(Role-F, Roles), !.
role_of(Roles, G, Role, []) :- atom(G), memberchk(Role-G, Roles), !.

literal_policy(G, _, _, Roles, pk(K), []) :- role_of(Roles, G, sig, [K0]), !, unquote(K0, K).
literal_policy(G, _, _, Roles, hash(sha256, H), []) :- role_of(Roles, G, pre, [H0]), !, unquote(H0, H).
literal_policy(G, Gs, _, Roles, older(B), [C]) :-
    role_of(Roles, G, age_blocks, [N]), !,
    member(C, Gs), ge(C, N, B).
literal_policy(G, Gs, _, Roles, older(V), [C]) :-
    role_of(Roles, G, age_seconds, [N]), !,
    member(C, Gs), ge(C, N, S),
    U is (S + 511) // 512, V is U \/ 0x400000.
literal_policy(G, Gs, _, Roles, after(T), Used) :-
    role_of(Roles, G, locktime, [L]), !,
    member(C, Gs), ge(C, L, T),
    findall(X, ( member(X, Gs), ( role_of(Roles, X, lock_height, [L1]) ; role_of(Roles, X, lock_time, [L1]) ), L1 == L ), Kinds),
    %  the finality condition (L < the spending block or time) is consensus
    findall(X, ( member(X, Gs), lt(X, L1, _), L1 == L ), Fin),
    findall(X, ( member(X, Gs), ( role_of(Roles, X, spent_in, [M]) ; role_of(Roles, X, spent_at, [M]) ),
                 member(Y, Fin), lt(Y, _, M2), M2 == M ), Spent),
    append([[C], Kinds, Fin, Spent], Used).
literal_policy(G, _, _, Roles, none, []) :-              % finality parts met alone
    ( role_of(Roles, G, lock_height, _) ; role_of(Roles, G, lock_time, _)
    ; role_of(Roles, G, spent_in, _) ; role_of(Roles, G, spent_at, _) ), !.
literal_policy(G, _, _, _, none, []) :- lt(G, _, _), !.
literal_policy(G, Gs, Items, Roles, thresh(K, Ps), [C]) :-
    compound(G), G =.. [count, [each|_], Goal, [var(_, N)]], !,
    member(C, Gs), ge(C, N, K),
    conj_list(Goal, GL),
    member(In, GL), In = le_is_in(E, List0), !,
    maplist(unquote, List0, List),
    (   member(X, GL), role_of(Roles, X, sig, [E1]), E1 == E
    ->  findall(pk(Key), member(Key, List), Ps)
    ;   member(X, GL), role_of(Roles, X, met, [E1]), E1 == E
    ->  memberchk(met-FM, Roles),
        maplist(condition_policy(Items, Roles, FM), List, Ps)
    ).

condition_policy(Items, Roles, FM, C, P) :-
    findall(B, ( member(rule(H, B0, _), Items), H =.. [FM, C0], unquote(C0, C1), C1 == C, strip(B0, B) ), Bs),
    maplist(body_policy(Items, Roles), Bs, Ps),
    join_or(Ps, P).

ge(C, V, B) :- ( C = le_ge(V1, B0) ; C = (V1 >= B0) ), V1 == V, number(B0), !, B = B0.
ge(C, V, B) :- ( C = le_gt(V1, B0) ; C = (V1 > B0) ), V1 == V, number(B0), !, B is B0 + 1.
lt(C, V, M) :- ( C = le_lt(V1, M) ; C = (V1 < M) ), V = V1.

		 /*******************************
		 *      COMPILING THE POLICY    *
		 *******************************/

%   sipa's compiler, with the hashes as the hex of test preimages when the
%   program states none (it reads hashes only as hex), the names put back.
compile_named(Policy, Names, MS) :-
    placeholders(Policy, Names, Pl, Table),
    findall(P-Hex, ( member(hash(H, P, _, _, _), Table), hash_hex(H, Table, P, Hex) ), HHex),
    ms_policy_text(Pl, PT0), atom_string(PT0, PT1),
    foldl([P-Hx, S0, S1]>>replace_word(S0, P, Hx, S1), HHex, PT1, PT),
    ms_compile(PT, MS0), atom_string(MS0, MS1),
    findall(P-K, member(key(K, P, _, _), Table), KBack),
    findall(Hx-H, ( member(P-Hx, HHex), member(hash(H, P, _, _, _), Table) ), HBack),
    append(KBack, HBack, Back),
    foldl([A-B, S0, S1]>>replace_word(S0, A, B, S1), Back, MS1, MS).

hash_hex(H, _, _, H) :- atom_length(H, L), memberchk(L, [40, 64]), ms_chain:hex_string(H), !.
hash_hex(_, Table, P, Hex) :-
    findall(P0-_{kind: K, name: R}, member(hash(_, P0, K, R, _), Table), HP), dict_pairs(Hs, _, HP),
    ms_node(material, _{keys: _{}, hashes: Hs}, M),
    get_dict(P, M.hashes, Hex0), atom_string(Hex, Hex0).

%   A placeholder (K1, H2) replaced where it stands as a whole word.
replace_word(S0, W, R, S) :-
    atom_string(S0, Str), atom_string(W, WS), atom_string(R, RS),
    string_codes(Str, Cs), string_codes(WS, Ws), string_codes(RS, Rs),
    phrase(repl(Ws, Rs, Out), Cs), string_codes(S, Out).

repl(Ws, Rs, Out) --> { Ws = [_|_] }, word_boundary_match(Ws), !, { append(Rs, T, Out) }, repl(Ws, Rs, T).
repl(Ws, Rs, [C|T]) --> [C], !, repl(Ws, Rs, T).
repl(_, _, []) --> [].

word_boundary_match(Ws), [N] --> Ws, [N], { \+ code_type(N, csym) }, !.
word_boundary_match(Ws) --> Ws, eos.
eos([], []).

%   The roles of a policy -> Names as ms_chain wants them ([pk(K)-Role,
%   hash(H)-Role]).
policy_names(Policy, Legend, _Kinds, Names) :-
    miniscript:ms_keys(Policy, Ks),
    findall(hash(H), sub_policy(Policy, hash(_, H)), Hs0), list_to_set(Hs0, Hs),
    findall(pk(K)-R, ( member(K, Ks), ( memberchk(K-R, Legend) -> true ; R = K ) ), KN),
    findall(hash(H)-R, ( member(hash(H), Hs), ( memberchk(H-R, Legend) -> true ; R = H ) ), HN),
    append(KN, HN, Names).

		 /*******************************
		 *     COMPARING TWO POLICIES   *
		 *******************************/

%!  canonical_policy(+Policy, -Canonical) is det.
%
%   A normal form for comparing policies up to the order and nesting of
%   `and`/`or` and the order of a threshold's items: and(SortedList),
%   or(SortedList), thresh(K, SortedList).
canonical_policy(and(A, B), and(L)) :- !,
    flat(and, and(A, B), L0), maplist(canonical_policy, L0, L1), msort(L1, L).
canonical_policy(or(A, B), or(L)) :- !,
    flat(or, or(A, B), L0), maplist(canonical_policy, L0, L1), msort(L1, L).
canonical_policy(thresh(K, Ps), thresh(K, L)) :- !, maplist(canonical_policy, Ps, L0), msort(L0, L).
canonical_policy(older(N), older(B)) :- !, ms_older_blocks(N, B).       % BIP 68 reads 16 bits
canonical_policy(P, P).

flat(Op, T, L) :- T =.. [Op, A, B], !, flat(Op, A, LA), flat(Op, B, LB), append(LA, LB, L).
flat(_, T, [T]).

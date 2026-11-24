/** <module> Bitcoin Miniscript, the policy language and output descriptors

    The front end of the Miniscript -> Logical English translator
    (the design notes roadmap.md §6.4, Phase 1d):

      ms_parse/2          a policy (`or(99@pk(A),and(pk(B),older(1000)))`),
                          a Miniscript (`or_d(pk(A),and_v(v:pkh(B),older(3)))`)
                          or a descriptor around either (`wsh(...)`,
                          `sh(wsh(...))`, `tr(K,{...})`), to a syntax tree;
      ms_policy/2         that tree lifted to the abstract spending POLICY:
                          pk(Key), hash(Kind, Hex), older(N), after(N),
                          and(A, B), or(A, B), thresh(K, [P, ...]), true,
                          false — the semantics column of BIP 379's
                          translation table;
      ms_eval/2           the policy's meaning on a spending attempt,
                          independently of any LE program: the fidelity
                          oracle of the migration;
      ms_satisfactions/2  its minimal satisfying sets (the spending paths),
                          the source of the migration's test scenarios.

    A spending attempt is attempt(Sigs, Preimages, Relative, LockTime):
    the keys that signed, the hashes whose preimage is revealed, the age of
    the coin being spent — rel(Blocks, Seconds), `none` for an unknown part
    — and the spending transaction's lock time (a number or `none`).
*/

:- module(miniscript, [
    ms_parse/2,            % +Text, -Tree
    ms_policy/2,           % +Tree, -Policy
    ms_text_policy/2,      % +Text, -Policy
    ms_eval/2,             % +Policy, +Attempt
    ms_satisfactions/2,    % +Policy, -Sets
    ms_keys/2,             % +Policy, -Keys
    ms_hashes/2,           % +Policy, -Hashes
    ms_older_blocks/2,     % +N, -Blocks | seconds(S)
    ms_lock_warnings/2,    % +Policy, -Warnings  (what consensus reads otherwise)
    ms_policy_text/2,      % +Policy, -Text  (the policy language)
    ms_layout/3            % +Tree, +Labels, -Lines  (the source, laid out)
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(dcg/basics)).

		 /*******************************
		 *            PARSING           *
		 *******************************/

%!  ms_parse(+Text, -Tree) is det.
%
%   Tree: f(Name, Args) for a fragment, w(Wrappers, Tree) for a wrapped
%   one (`sln:after(840000)`), p(Weight, Tree) for a probability-weighted
%   `or` branch (`9@pk(A)`), num(N), key(Text) for a key expression,
%   hex(Text) for a hash, tree(Branches) for a Taproot script tree.
ms_parse(Text0, Tree) :-
    ( string(Text0) -> Text1 = Text0 ; atom_string(Text0, Text1) ),
    strip_checksum(Text1, Text2),
    normalize_space(string(Text), Text2),
    string_codes(Text, Cs0),
    exclude(space_code, Cs0, Cs),
    (   phrase(expr(Tree), Cs)
    ->  true
    ;   throw(error(miniscript_syntax(Text), _))
    ).

space_code(C) :- code_type(C, space).

strip_checksum(T, S) :-
    ( sub_string(T, B, _, _, "#") -> sub_string(T, 0, B, _, S) ; S = T ).

expr(p(W, E)) --> digits(Ds), { Ds \== [] }, "@", !, { number_codes(W, Ds) }, expr(E).
expr(w(Ws, E)) --> wrappers(Ws), ":", !, expr(E).
expr(tree(Bs)) --> "{", !, branches(Bs), "}".
expr(f(Name, Args)) --> name(Name), "(", !, args(Name, Args), ")".
expr(num(N)) --> digits(Ds), { Ds \== [] }, !, { number_codes(N, Ds) }.
expr(atom(A)) --> key_text(Cs), { Cs \== [], atom_codes(A, Cs) }.

branches([B|Bs]) --> expr(B), ( "," -> branches(Bs) ; { Bs = [] } ).

wrappers(Ws) --> wrapper_letters(Cs), { Cs \== [], maplist(code_char_atom, Cs, Ws) }.

code_char_atom(C, A) :- char_code(A, C).
wrapper_letters([C|Cs]) --> [C], { memberchk(C, `asctdvjnlu`) }, wrapper_letters(Cs).
wrapper_letters([]) --> [].

name(Name) --> csym_start(C), csyms(Cs), { atom_codes(Name, [C|Cs]) }.
csym_start(C) --> [C], { code_type(C, alpha) }.
csyms([C|Cs]) --> [C], { code_type(C, csym) }, !, csyms(Cs).
csyms([]) --> [].

%   Fragments whose arguments are keys, hashes or numbers are read as text:
%   a key expression ([fingerprint/path]xpub.../<0;1>/*) is one argument.
args(Name, Args) --> { key_fragment(Name) }, !, key_args(Args).
args(Name, Args) --> { hash_fragment(Name) }, !, key_text(Cs), { atom_codes(H, Cs), Args = [hex(H)] }.
args(tr, [key(K)|Rest]) --> !, key_text(Cs), { atom_codes(K, Cs) }, ( "," -> expr(T), { Rest = [T] } ; { Rest = [] } ).
args(_, [A|As]) --> expr(A), ( "," -> args_rest(As) ; { As = [] } ).
args_rest([A|As]) --> expr(A), ( "," -> args_rest(As) ; { As = [] } ).

key_args(Args) --> key_item(A), ( "," -> key_args(As), { Args = [A|As] } ; { Args = [A] } ).
key_item(num(N)) --> digits(Ds), { Ds \== [] }, peek_sep, !, { number_codes(N, Ds) }.
key_item(key(K)) --> key_text(Cs), { Cs \== [], atom_codes(K, Cs) }.

peek_sep, [C] --> [C], { memberchk(C, `,)`) }.

%   A key or hash: everything up to the next top-level ',' or ')'.
key_text([C|Cs]) --> [C], { \+ memberchk(C, `,()`) }, !, key_text(Cs).
key_text([]) --> [].

key_fragment(pk). key_fragment(pkh). key_fragment(pk_k). key_fragment(pk_h).
key_fragment(multi). key_fragment(multi_a). key_fragment(sortedmulti).
key_fragment(sortedmulti_a).
hash_fragment(sha256). hash_fragment(hash256). hash_fragment(ripemd160). hash_fragment(hash160).

		 /*******************************
		 *     LIFTING TO THE POLICY    *
		 *******************************/

%!  ms_policy(+Tree, -Policy) is det.
%
%   The spending policy of a policy / Miniscript / descriptor tree: the
%   semantics column of BIP 379's translation table. Probabilities and the
%   wrappers (a s c d v j n t l u) do not change the policy; `0` is false,
%   `1` true; and_v, and_b, and_n are `and`; or_b, or_c, or_d, or_i are
%   `or`; andor(X, Y, Z) is (X and Y) or Z; multi(k, keys) is thresh(k) of
%   the keys' signatures. A Taproot output is its internal key's signature
%   or any of its script leaves.
ms_policy(T, P) :- lift(T, P0), simplify(P0, P).

ms_text_policy(Text, P) :- ms_parse(Text, T), ms_policy(T, P).

lift(p(_, E), P) :- !, lift(E, P).
lift(w(_, E), P) :- !, lift(E, P).
lift(num(0), false) :- !.
lift(num(1), true) :- !.
lift(f(Wrap, [E]), P) :- memberchk(Wrap, [wsh, sh]), !, lift(E, P).
lift(f(tr, [key(K)]), pk(K)) :- !.
lift(f(tr, [key(K), Tree]), or(pk(K), P)) :- !, lift(Tree, P).
lift(tree([B]), P) :- !, lift(B, P).
lift(tree([B|Bs]), or(P, Q)) :- !, lift(B, P), lift(tree(Bs), Q).
lift(f(F, [key(K)]), pk(K)) :- memberchk(F, [pk, pkh, pk_k, pk_h]), !.
lift(f(F, [hex(H)]), hash(F, H)) :- hash_fragment(F), !.
lift(f(older, [num(N)]), older(N)) :- !.
lift(f(after, [num(N)]), after(N)) :- !.
lift(f(F, [num(K)|Keys]), thresh(K, Ps)) :-
    memberchk(F, [multi, multi_a, sortedmulti, sortedmulti_a]), !,
    maplist(key_pk, Keys, Ps).
lift(f(thresh, [num(K)|Subs]), thresh(K, Ps)) :- !, maplist(lift, Subs, Ps).
lift(f(F, [A, B]), and(PA, PB)) :- memberchk(F, [and, and_v, and_b, and_n]), !, lift(A, PA), lift(B, PB).
lift(f(F, [A, B]), or(PA, PB)) :- memberchk(F, [or, or_b, or_c, or_d, or_i]), !, lift(A, PA), lift(B, PB).
lift(f(andor, [X, Y, Z]), or(and(PX, PY), PZ)) :- !, lift(X, PX), lift(Y, PY), lift(Z, PZ).
lift(f(F, [A]), P) :- memberchk(F, [c, v, s, a, d, j, n, t, l, u]), !, lift(A, P).
lift(atom(A), pk(A)) :- !.                     % a bare key name in a policy
lift(T, _) :- throw(error(miniscript_unsupported(T), _)).

key_pk(key(K), pk(K)).
key_pk(atom(K), pk(K)).

simplify(and(A0, B0), P) :- !, simplify(A0, A), simplify(B0, B),
    ( A == true -> P = B ; B == true -> P = A
    ; ( A == false ; B == false ) -> P = false ; P = and(A, B) ).
simplify(or(A0, B0), P) :- !, simplify(A0, A), simplify(B0, B),
    ( A == false -> P = B ; B == false -> P = A
    ; ( A == true ; B == true ) -> P = true ; P = or(A, B) ).
simplify(thresh(K, Ps0), P) :- !,
    maplist(simplify, Ps0, Ps1),
    include(==(true), Ps1, Ts), length(Ts, NT),
    exclude(constant_policy, Ps1, Ps),
    K1 is K - NT,
    length(Ps, N),
    (   K1 =< 0 -> P = true
    ;   K1 > N -> P = false
    ;   N =:= 1 -> Ps = [P]
    ;   K1 =:= N -> Ps = [F|R], foldl(and_step, R, F, P)
    ;   K1 =:= 1 -> Ps = [F|R], foldl(or_step, R, F, P)
    ;   P = thresh(K1, Ps)
    ).
simplify(P, P).

constant_policy(true).
constant_policy(false).
and_step(X, A, and(A, X)).
or_step(X, A, or(A, X)).

		 /*******************************
		 *           MEANING            *
		 *******************************/

%!  ms_eval(+Policy, +Attempt) is semidet.
%
%   The attempt attempt(Sigs, Preimages, rel(Blocks, Seconds), LockTime)
%   satisfies the policy — BIP 379's semantics, read straight off the tree.
%   older(n) with bit 22 set (BIP 68) counts 512-second units of the coin's
%   age, otherwise blocks; after(n) below 500000000 is a block height,
%   otherwise a Unix time, and is met by a lock time of the same kind that
%   is at least n (lock times of the other kind never meet it).
ms_eval(true, _) :- !.
ms_eval(false, _) :- !, fail.
ms_eval(pk(K), attempt(Sigs, _, _, _)) :- !, memberchk(K, Sigs).
ms_eval(hash(_, H), attempt(_, Pre, _, _)) :- !, memberchk(H, Pre).
ms_eval(older(N), attempt(_, _, rel(B, S), _)) :- !,
    ms_older_blocks(N, Need),
    (   Need = seconds(Secs) -> number(S), S >= Secs
    ;   number(B), B >= Need
    ).
ms_eval(after(N), attempt(_, _, _, L)) :- !,
    number(L), same_lock_kind(N, L), L >= N.
ms_eval(and(A, B), W) :- !, ms_eval(A, W), ms_eval(B, W).
ms_eval(or(A, B), W) :- !, ( ms_eval(A, W) -> true ; ms_eval(B, W) ).
ms_eval(thresh(K, Ps), W) :- !,
    include(met(W), Ps, Met),
    length(Met, M), M >= K.

met(W, P) :- ms_eval(P, W).

same_lock_kind(N, L) :- ( N < 500000000 -> L < 500000000 ; L >= 500000000 ).

%!  ms_older_blocks(+N, -Need) is det.
%
%   The relative lock older(N) as blocks, or seconds(S) when BIP 68's
%   type flag (bit 22) is set: the low 16 bits count 512-second units.
ms_older_blocks(N, Need) :-
    (   N /\ 0x400000 =\= 0
    ->  S is (N /\ 0xFFFF) * 512, Need = seconds(S)
    ;   Need is N /\ 0xFFFF
    ).

		 /*******************************
		 *   THE SATISFACTION ANALYSIS  *
		 *******************************/

%!  ms_satisfactions(+Policy, -Sets) is det.
%
%   The minimal satisfying sets: each a sorted list of the requirements
%   one spending path needs — sig(Key), preimage(Hex), older(N), after(N)
%   — with no set a superset of another. Sets mixing an after() by height
%   with one by time cannot be met and are dropped (BIP 379 §"timelock
%   mixing").
ms_satisfactions(P, Sets) :-
    sats(P, Sets0),
    exclude(mixed_locks, Sets0, Sets1),
    minimal_sets(Sets1, Sets).

sats(true, [[]]) :- !.
sats(false, []) :- !.
sats(pk(K), [[sig(K)]]) :- !.
sats(hash(_, H), [[preimage(H)]]) :- !.
sats(older(N), [[older(N)]]) :- !.
sats(after(N), [[after(N)]]) :- !.
sats(and(A, B), Sets) :- !,
    sats(A, SA), sats(B, SB),
    findall(S, ( member(X, SA), member(Y, SB), union_sorted(X, Y, S) ), Sets).
sats(or(A, B), Sets) :- !,
    sats(A, SA), sats(B, SB), append(SA, SB, Sets).
sats(thresh(K, Ps), Sets) :- !,
    maplist(sats, Ps, Subs),
    findall(S, ( k_subset(K, Subs, Chosen), combine(Chosen, S) ), Sets).

union_sorted(X, Y, S) :- append(X, Y, XY), sort(XY, S).

k_subset(0, _, []) :- !.
k_subset(K, [X|Xs], [X|Ys]) :- K1 is K - 1, k_subset(K1, Xs, Ys).
k_subset(K, [_|Xs], Ys) :- length(Xs, N), N >= K, k_subset(K, Xs, Ys).

combine([], []).
combine([Opts|Rest], S) :- member(O, Opts), combine(Rest, S1), union_sorted(O, S1, S).

mixed_locks(Set) :-
    member(after(A), Set), member(after(B), Set),
    \+ same_lock_kind(A, B), !.
mixed_locks(Set) :-                     % the same for relative locks
    member(older(A), Set), member(older(B), Set),
    (A /\ 0x400000) =\= (B /\ 0x400000), !.

%!  ms_lock_warnings(+Policy, -Warnings) is det.
%
%   What consensus reads differently from what the policy writes, as
%   strings: an older(n) with bits BIP 68 does not read (above the 16-bit
%   value, other than the type flag: older(65664) is 128 blocks — the
%   longest relative lock is 65535 blocks, or 65535 x 512 seconds), and a
%   spending path that mixes a lock by height with one by time, which no
%   transaction can meet (BIP 379, timelock mixing).
ms_lock_warnings(P, Ws) :-
    findall(W, ( sub_policy(P, older(N)), N /\ \ 0x0040FFFF =\= 0,
                 ms_older_blocks(N, Need), consensus_words(Need, CW),
                 format(string(W), "older(~w) sets bits BIP 68 does not read: consensus reads it as ~w; the longest relative lock is 65535 blocks (about 455 days), or 65535 x 512 seconds (about 388 days)", [N, CW]) ), W1),
    sats(P, Sets0),
    findall(W, ( member(S, Sets0), mixed_locks(S), ms_policy_text(and_all(S), T),
                 format(string(W), "the spending path ~w mixes a lock by block height with one by time: no transaction can meet it (BIP 379, timelock mixing)", [T]) ), W2),
    append(W1, W2, Ws0), list_to_set(Ws0, Ws).

req_text(sig(K), X) :- !, format(string(X), "pk(~w)", [K]).
req_text(preimage(H), X) :- !, format(string(X), "the preimage of ~w", [H]).
req_text(R, X) :- ms_policy_text(R, X).

consensus_words(seconds(S), W) :- !, format(string(W), "a relative lock of ~w seconds", [S]).
consensus_words(B, W) :- format(string(W), "older(~w), ~w blocks", [B, B]).


minimal_sets(Sets0, Sets) :-
    sort(Sets0, Sets1),
    exclude(has_smaller(Sets1), Sets1, Sets).

has_smaller(Sets, S) :- member(T, Sets), T \== S, subset(T, S), !.

		 /*******************************
		 *          INVENTORIES         *
		 *******************************/

ms_keys(P, Keys) :- findall(K, sub_policy(P, pk(K)), Ks), list_to_set(Ks, Keys).
ms_hashes(P, Hs) :- findall(hash(F, H), sub_policy(P, hash(F, H)), Hs0), list_to_set(Hs0, Hs).

sub_policy(P, P).
sub_policy(and(A, B), S) :- ( sub_policy(A, S) ; sub_policy(B, S) ).
sub_policy(or(A, B), S) :- ( sub_policy(A, S) ; sub_policy(B, S) ).
sub_policy(thresh(_, Ps), S) :- member(P, Ps), sub_policy(P, S).

%!  ms_policy_text(+Policy, -Text) is det.
%
%   The policy in the policy language (for the ledger and comments).
ms_policy_text(true, "1").
ms_policy_text(false, "0").
ms_policy_text(pk(K), T) :- format(string(T), "pk(~w)", [K]).
ms_policy_text(hash(F, H), T) :- format(string(T), "~w(~w)", [F, H]).
ms_policy_text(and_all(Reqs), T) :- !,                 % a satisfaction set, for messages
    findall(X, ( member(R, Reqs), req_text(R, X) ), Xs), atomic_list_concat(Xs, ' and ', T0), atom_string(T0, T).
ms_policy_text(older(N), T) :- format(string(T), "older(~w)", [N]).
ms_policy_text(after(N), T) :- format(string(T), "after(~w)", [N]).
ms_policy_text(and(A, B), T) :- ms_policy_text(A, TA), ms_policy_text(B, TB), format(string(T), "and(~w,~w)", [TA, TB]).
ms_policy_text(or(A, B), T) :- ms_policy_text(A, TA), ms_policy_text(B, TB), format(string(T), "or(~w,~w)", [TA, TB]).
ms_policy_text(thresh(K, Ps), T) :-
    maplist(ms_policy_text, Ps, Ts), atomic_list_concat(Ts, ',', In),
    format(string(T), "thresh(~w,~w)", [K, In]).

		 /*******************************
		 *     THE SOURCE, LAID OUT     *
		 *******************************/

%!  ms_layout(+Tree, +Labels, -Lines) is det.
%
%   The syntax tree of a policy, Miniscript or descriptor as indented
%   lines of its own notation: a node that fits in layout_width/1 columns
%   stays on one line, a longer one opens a line and puts each argument on
%   a line of its own, two columns further in. Labels ([Leaf-Label]) show a
%   key or hash by the name of its role; a leaf without a label is written
%   as it is (keys cut to their first and last characters).
ms_layout(Tree, Labels, Lines) :-
    layout(Tree, Labels, 0, Lines0),
    maplist(indent_line, Lines0, Lines).

layout_width(64).

indent_line(I-T, L) :- length(Sp, I), maplist(=(0' ), Sp), string_codes(S, Sp), string_concat(S, T, L).

layout(T, Labels, I, [I-S]) :-
    flat(T, Labels, S),
    string_length(S, N), layout_width(W), I + N =< W, !.
layout(p(Wt, E), Labels, I, [I-L1|Ls]) :- !,
    layout(E, Labels, I, [_-F|Ls]), format(string(L1), "~w@~w", [Wt, F]).
layout(w(Ws, E), Labels, I, [I-L1|Ls]) :- !,
    layout(E, Labels, I, [_-F|Ls]), atomic_list_concat(Ws, WA), format(string(L1), "~w:~w", [WA, F]).
layout(f(Name, [num(K)|Args]), Labels, I, [I-Open|Lines]) :- Args \== [], !,
    format(string(Open), "~w(~w,", [Name, K]),         % thresh(2, / multi(2, on the opening line
    I1 is I + 2,
    args_layout(Args, Labels, I1, Lines0),
    close_last(Lines0, ")", Lines).
layout(f(Name, Args), Labels, I, [I-Open|Lines]) :- !,
    format(string(Open), "~w(", [Name]),
    I1 is I + 2,
    args_layout(Args, Labels, I1, Lines0),
    close_last(Lines0, ")", Lines).
layout(tree(Bs), Labels, I, [I-"{"|Lines]) :- !,
    I1 is I + 2,
    args_layout(Bs, Labels, I1, Lines0),
    close_last(Lines0, "}", Lines).
layout(T, Labels, I, [I-S]) :- flat(T, Labels, S).

args_layout([], _, _, []).
args_layout([A|As], Labels, I, Lines) :-
    layout(A, Labels, I, L0),
    (   As == [] -> L1 = L0 ; close_last(L0, ",", L1) ),
    args_layout(As, Labels, I, Ls),
    append(L1, Ls, Lines).

close_last(Lines0, Suffix, Lines) :-
    append(Init, [I-Last], Lines0), !,
    string_concat(Last, Suffix, Last1),
    append(Init, [I-Last1], Lines).
close_last([], _, []).

%   A node on one line.
flat(p(W, E), L, S) :- !, flat(E, L, F), format(string(S), "~w@~w", [W, F]).
flat(w(Ws, E), L, S) :- !, flat(E, L, F), atomic_list_concat(Ws, WA), format(string(S), "~w:~w", [WA, F]).
flat(f(Name, Args), L, S) :- !,
    flat_list(Args, L, Ts), atomic_list_concat(Ts, ',', In),
    format(string(S), "~w(~w)", [Name, In]).
flat(tree(Bs), L, S) :- !,
    flat_list(Bs, L, Ts), atomic_list_concat(Ts, ',', In),
    format(string(S), "{~w}", [In]).
flat(num(N), _, S) :- !, format(string(S), "~w", [N]).
flat(key(K), L, S) :- !, leaf_text(K, L, S).
flat(atom(K), L, S) :- !, leaf_text(K, L, S).
flat(hex(H), L, S) :- !, leaf_text(H, L, S).
flat(T, _, S) :- format(string(S), "~w", [T]).

flat_list([], _, []).
flat_list([A|As], L, [T|Ts]) :- flat(A, L, T), flat_list(As, L, Ts).

leaf_text(K, Labels, S) :-
    (   memberchk(K-Lab, Labels) -> format(string(S), "<~w>", [Lab])
    ;   atom_length(K, N), N > 24
    ->  sub_atom(K, 0, 10, _, A), sub_atom(K, _, 8, 0, B), format(string(S), "~w...~w", [A, B])
    ;   format(string(S), "~w", [K])
    ).

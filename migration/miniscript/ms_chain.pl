/** <module> A Miniscript twin on a real chain, and in Minsc

    The sandbox half of the Miniscript twins (README, "On a chain"):

      - ms_compile/2       a policy -> Miniscript by sipa's reference compiler
                           (chain/ms_chain.cjs, @bitcoinerlab/miniscript-policies);
      - minsc_url/2        the policy as a Minsc playground link
                           (https://min.sc/#c=<the code>): the policy compiled
                           to Miniscript, Script and an address in the browser;
      - chain_run/4        the spending attempts of a twin's satisfaction
                           analysis put in front of a real chain — Rewind
                           Bitcoin's public Tape network, or a private regtest
                           bitcoind — and recorded (chain/runs/<id>.<net>.json);
      - chain_tests/5      a recorded run as the twin's chain-confirmed
                           scenarios: each attempt's witness and timing as
                           facts, the chain's verdict (accepted or refused) as
                           the expectation, the transaction as the citation.

    The chain sees the policy's structure with TEST keys and hashes (derived
    from the role names; nobody holds the source's private keys), so the run
    checks the meaning of the policy, not its particular keys.
*/

:- module(ms_chain, [
    ms_node/3,              % +Command, +Arg, -Dict
    policy_language/1,      % +Tree
    ms_compile/2,           % +PolicyText, -Miniscript
    placeholders/4,         % +Policy, +Names, -PlPolicy, -Table
    minsc_code/4,           % +Title, +Policy, +Names, -Code
    minsc_url/2,            % +Code, -Url
    chain_attempts/4,       % +Policy, +Names, +Sets, -Attempts
    chain_run/4,            % +Id, +src(Tree, Policy), +Names-NamedSets, +Network
    chain_record/3,         % +Id, +Network, -Record
    chain_tests/5           % +Record, +Names-NamedSets, +Features, +Id, -Tests-Docs
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(json)).
:- use_module(library(uri)).
:- use_module(miniscript).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).

chain_dir(D) :- here(H), atomic_list_concat([H, '/chain'], D).
runs_dir(D) :- chain_dir(C), atomic_list_concat([C, '/runs'], D).

		 /*******************************
		 *          THE NODE TOOL       *
		 *******************************/

%!  ms_node(+Command, +Arg, -Dict) is det.
%
%   Runs chain/ms_chain.cjs Command Arg and reads its JSON reply. Arg is a
%   string (compile) or a dict written to a temporary spec file.
ms_node(Cmd, Arg0, Dict) :-
    chain_dir(Dir),
    atomic_list_concat([Dir, '/ms_chain.cjs'], Tool),
    (   is_dict(Arg0)
    ->  tmp_file_stream(text, Spec, S), json_write_dict(S, Arg0, [width(0)]), close(S), Arg = Spec
    ;   Arg = Arg0, Spec = none
    ),
    setup_call_cleanup(
        process_create(path(node), [Tool, Cmd, Arg], [stdout(pipe(Out)), stderr(pipe(Err)), process(Pid)]),
        ( read_string(Out, _, OutS), read_string(Err, _, ErrS), process_wait(Pid, Status) ),
        ( close(Out), close(Err), ( Spec == none -> true ; delete_file(Spec) ) )),
    (   Status == exit(0)
    ->  atom_json_dict(OutS, Dict, [])
    ;   throw(error(ms_chain_tool_failed(Cmd, ErrS), _))
    ).

%!  ms_compile(+PolicyText, -Miniscript) is det.
%
%   sipa's compiler (P2WSH); a policy that does not compile to sane
%   Miniscript raises an error.
ms_compile(Policy, MS) :-
    ms_node(compile, Policy, D),
    (   D.issane == true -> atom_string(MS, D.miniscript)
    ;   throw(error(miniscript_not_sane(Policy, D.miniscript), _))
    ).

		 /*******************************
		 *         PLACEHOLDERS         *
		 *******************************/

%!  placeholders(+Policy, +Names, -PlPolicy, -Table) is det.
%
%   The policy with its keys as K1, K2, ... and its hashes as H1, H2, ...
%   (identifiers every tool accepts), and Table: [key(K, Pl, Role, Key),
%   hash(H, Pl, Kind, Name, Hex)].
placeholders(Policy, Names, Pl, Table) :-
    ms_keys(Policy, Keys), ms_hashes(Policy, Hashes),
    length(Keys, NK), upto(NK, KIs),
    length(Hashes, NH), upto(NH, HIs),
    maplist(key_row(Names), KIs, Keys, KRows),
    maplist(hash_row(Names), HIs, Hashes, HRows),
    append(KRows, HRows, Table),
    subst(Policy, Table, Pl).

upto(0, []) :- !.
upto(N, L) :- numlist(1, N, L).

key_row(Names, I, K, key(K, Pl, Role, K)) :-
    format(atom(Pl), 'K~w', [I]), memberchk(pk(K)-Role, Names).
hash_row(Names, I, hash(Kind, H), hash(H, Pl, Kind, Role, H)) :-
    format(atom(Pl), 'H~w', [I]), memberchk(hash(H)-Role, Names).

subst(pk(K), T, pk(P)) :- !, memberchk(key(K, P, _, _), T).
subst(hash(F, H), T, hash(F, P)) :- !, memberchk(hash(H, P, _, _, _), T).
subst(and(A, B), T, and(A1, B1)) :- !, subst(A, T, A1), subst(B, T, B1).
subst(or(A, B), T, or(A1, B1)) :- !, subst(A, T, A1), subst(B, T, B1).
subst(thresh(K, Ps), T, thresh(K, Ps1)) :- !, subst_list(Ps, T, Ps1).
subst(P, _, P).

subst_list([], _, []).
subst_list([P|Ps], T, [Q|Qs]) :- subst(P, T, Q), subst_list(Ps, T, Qs).

%   A key or hash as written in the source is a real one when it is hex of
%   the right length or an extended key; a name (key_user, H) is not.
real_key(K) :-
    atom_string(K, S),
    (   sub_string(S, _, _, _, "pub") -> true
    ;   string_length(S, L), memberchk(L, [64, 66]), hex_string(S)
    ).
real_hash(Kind, H) :-
    atom_string(H, S), string_length(S, L), hex_string(S),
    ( memberchk(Kind, [sha256, hash256]) -> L =:= 64 ; L =:= 40 ).

hex_string(S) :- string_codes(S, Cs), forall(member(C, Cs), code_type(C, xdigit(_))).

		 /*******************************
		 *            MINSC             *
		 *******************************/

%!  minsc_code(+Title, +Policy, +Names, -Code) is det.
%
%   The policy as Minsc code: one variable per key and hash, named after
%   its role, holding the key or hash of the source when it has one, else
%   the chain run's test key (or hash of a test preimage), then the policy
%   over the variables. A descriptor key's multipath `/<0;1>/*` is written
%   as its receive branch `/0/*`.
minsc_code(Title, Policy, Names, Code) :-
    placeholders(Policy, Names, Pl, Table),
    material(Table, Mat),
    findall(L, ( member(R, Table), minsc_var(R, Mat, L) ), VarLines),
    maplist(row_var, Table, Vars),
    ms_policy_text(Pl, PT0),
    atom_string(PT0, PT1),
    replace_placeholders(Vars, PT1, PT),
    atomic_list_concat(VarLines, '\n', VT),
    format(string(Code), "// ~w~n// The Logical English twin's policy (the Miniscript translator of Logical English).~n~w~n~n~w~n", [Title, VT, PT]).

row_var(R, P-V) :-
    ( R = key(_, P, Role, _) ; R = hash(_, P, _, Role, _) ), !,
    var_name(Role, V0), atom_concat('$', V0, V).

minsc_var(key(K, P, Role, _), Mat, L) :-
    var_name(Role, V),
    (   real_key(K) -> key_text(K, KT), Note = "as in the source"
    ;   get_dict(P, Mat.keys, KT), Note = "a test key: the source names no key"
    ),
    format(atom(L), '$~w = ~w;   // ~w (~w)', [V, KT, Role, Note]).
minsc_var(hash(H, P, Kind, Role, _), Mat, L) :-
    var_name(Role, V),
    (   real_hash(Kind, H) -> HT = H, Note = "as in the source"
    ;   get_dict(P, Mat.hashes, HT), Note = "the hash of a test preimage: the source names no hash"
    ),
    format(atom(L), '$~w = ~w;   // ~w, ~w (~w)', [V, HT, Role, Kind, Note]).

key_text(K, T) :-
    atom_string(K, S),
    (   sub_string(S, B, _, A, "/<0;1>/*")
    ->  sub_string(S, 0, B, _, S0), sub_string(S, _, A, 0, S1), atomic_list_concat([S0, '/0/*', S1], T)
    ;   T = K
    ).

var_name(Role, V) :-
    downcase_atom(Role, L), atom_codes(L, Cs0),
    maplist([C0, C]>>( code_type(C0, alnum) -> C = C0 ; C = 0'_ ), Cs0, Cs),
    atom_codes(A, Cs), atomic_list_concat(Ps0, '_', A), exclude(==(''), Ps0, Ps1),
    %  a leading article only: "the user" is user, "key A" stays key_a
    (   Ps1 = [Art|Ps2], memberchk(Art, [the, a, an]), Ps2 \== [] -> Ps = Ps2 ; Ps = Ps1 ),
    atomic_list_concat(Ps, '_', V0),
    ( sub_atom(V0, 0, 1, _, F), char_type(F, digit) -> atom_concat(k_, V0, V) ; V = V0 ).

replace_placeholders([], T, T).
replace_placeholders([P-V|Vs], T0, T) :-
    format(string(Pat), "(~w)", [P]), format(string(Rep), "(~w)", [V]),
    format(string(Pat2), "(~w,", [P]), format(string(Rep2), "(~w,", [V]),
    format(string(Pat3), ",~w)", [P]), format(string(Rep3), ",~w)", [V]),
    format(string(Pat4), ",~w,", [P]), format(string(Rep4), ",~w,", [V]),
    foldl([A-B, S0, S]>>replace_all(S0, A, B, S), [Pat-Rep, Pat2-Rep2, Pat3-Rep3, Pat4-Rep4], T0, T1),
    replace_placeholders(Vs, T1, T).

replace_all(S, A, B, R) :-
    atomic_list_concat(Parts, A, S), atomic_list_concat(Parts, B, R0), atom_string(R0, R).

%!  minsc_url(+Code, -Url) is det.
%
%   Minsc's share link: the code itself, URI-encoded, after `#c=` (the
%   playground decodes `location.hash` with decodeURIComponent).
minsc_url(Code, Url) :-
    uri_encoded(fragment, Code, E),
    atomic_list_concat(['https://min.sc/#c=', E], Url).

material(Table, Mat) :-
    findall(P-Role, member(key(_, P, Role, _), Table), KP), dict_pairs(Keys, _, KP),
    findall(P-_{kind: Kind, name: Role}, member(hash(_, P, Kind, Role, _), Table), HP), dict_pairs(Hashes, _, HP),
    ms_node(material, _{keys: Keys, hashes: Hashes}, Mat).

		 /*******************************
		 *           ATTEMPTS           *
		 *******************************/

%!  chain_attempts(+Policy, +Names, +NamedSets, -Attempts) is det.
%
%   The satisfaction analysis as the material spenders bring: for each
%   spending path (Name-Set, named after the rule it satisfies), all it
%   needs, then each signature or preimage left out; and nothing at all.
%   Attempts with the same material are tried once.
chain_attempts(Policy, Names, NamedSets, Attempts) :-
    placeholders(Policy, Names, _, Table),
    findall(A, ( member(Name-S, NamedSets), path_attempt(Table, Name, S, A) ), As0),
    NamedSets = [_-S1|_],
    material_of(Table, S1, Path1),
    append(As0, [attempt(no_witness, material([], []), Path1)], As1),
    dedupe(As1, [], Attempts).

path_attempt(Table, Name, S, attempt(Id, Have, Path)) :-
    material_of(Table, S, Path),
    (   Id = Name, Have = Path
    ;   Path = material(Sigs, Pres),
        (   nth1(J, Sigs, _), nth1(J, Sigs, _, Sigs1), Have = material(Sigs1, Pres)
        ;   length(Sigs, NS), nth1(J0, Pres, _), nth1(J0, Pres, _, Pres1), J is NS + J0, Have = material(Sigs, Pres1)
        ),
        format(atom(Id), '~w_without_~w', [Name, J])
    ).

material_of(Table, S, material(Sigs, Pres)) :-
    findall(P, ( member(sig(K), S), memberchk(key(K, P, _, _), Table) ), Sigs),
    findall(P, ( member(preimage(H), S), memberchk(hash(H, P, _, _, _), Table) ), Pres).

dedupe([], _, []).
dedupe([attempt(Id, material(S, P), Path)|As], Seen, Out) :-
    msort(S, SS), msort(P, PS),
    (   memberchk(SS-PS, Seen) -> Out = Out1
    ;   Out = [attempt(Id, material(S, P), Path)|Out1]
    ),
    dedupe(As, [SS-PS|Seen], Out1).

		 /*******************************
		 *            THE RUN           *
		 *******************************/

%!  chain_run(+Id, +Policy, +Names-Sets, +Network) is det.
%
%   Runs the attempts on Network (tape | regtest) and writes the record to
%   chain/runs/<Id>.<Network>.json.
chain_run(Id, Source, Names-Sets, Network) :-
    (   Source = src(Tree, Policy) -> true ; Policy = Source, Tree = none ),
    placeholders(Policy, Names, Pl, Table),
    ms_policy_text(Pl, PT),
    %  a source written in Miniscript runs as written (its keys and hashes
    %  replaced); a policy is compiled by sipa's compiler
    (   Tree \== none, miniscript_text(Tree, Table, MsText) -> Extra = _{miniscript: MsText} ; Extra = _{} ),
    chain_attempts(Policy, Names, Sets, Attempts),
    findall(P-Role, member(key(_, P, Role, _), Table), KP), dict_pairs(Keys, _, KP),
    findall(P-_{kind: Kind, name: Role}, member(hash(_, P, Kind, Role, _), Table), HP), dict_pairs(Hashes, _, HP),
    maplist(attempt_dict, Attempts, ADs),
    max_older(Policy, Conf),
    Spec0 = _{network: Network, policy: PT, keys: Keys, hashes: Hashes, attempts: ADs, confirmations: Conf},
    Spec = Spec0.put(Extra),
    ms_node(run, Spec, Record0),
    Record = Record0.put(_{twin: Id, attempt_names: rules}),
    runs_dir(RD), make_directory_path(RD),
    format(atom(File), '~w/~w.~w.json', [RD, Id, Network]),
    setup_call_cleanup(open(File, write, S, [encoding(utf8)]),
                       json_write_dict(S, Record, [width(100)]),
                       close(S)).

%!  miniscript_text(+Tree, +Table, -Text) is semidet.
%
%   A source in Miniscript (bare, or in wsh()/sh(wsh())) written back with
%   its keys and hashes as the placeholders of Table; fails for a policy
%   and for Taproot.
miniscript_text(f(wsh, [T]), Tb, S) :- !, miniscript_text(T, Tb, S).
miniscript_text(f(sh, [f(wsh, [T])]), Tb, S) :- !, miniscript_text(T, Tb, S).
miniscript_text(T, Tb, S) :-
    \+ policy_language(T), ms_out(T, Tb, S).

%!  policy_language(+Tree) is semidet.
%
%   Written in the policy language: only its fragments (pk, and, or,
%   thresh, the locks and hashes, probabilities), no Miniscript wrappers or
%   fragments, no descriptor.
policy_language(p(_, T)) :- !, policy_language(T).
policy_language(f(F, Args)) :- !,
    memberchk(F, [pk, and, or, thresh, older, after, sha256, hash256, ripemd160, hash160]),
    forall(member(A, Args), policy_language(A)).
policy_language(num(_)).
policy_language(key(_)).
policy_language(atom(_)).
policy_language(hex(_)).

ms_out(f(tr, _), _, _) :- !, fail.
ms_out(f(F, Args), Tb, S) :- !,
    ms_out_list(Args, Tb, ASs),
    atomic_list_concat(ASs, ',', In), format(string(S), "~w(~w)", [F, In]).
ms_out(w(Ws, T), Tb, S) :- !, atomic_list_concat(Ws, W), ms_out(T, Tb, TS), format(string(S), "~w:~w", [W, TS]).
ms_out(num(N), _, S) :- !, format(string(S), "~w", [N]).
ms_out(key(K), Tb, S) :- !, memberchk(key(K, P, _, _), Tb), atom_string(P, S).
ms_out(atom(K), Tb, S) :- !, memberchk(key(K, P, _, _), Tb), atom_string(P, S).
ms_out(hex(H), Tb, S) :- !, memberchk(hash(H, P, _, _, _), Tb), atom_string(P, S).

ms_out_list([], _, []).
ms_out_list([A|As], Tb, [S|Ss]) :- ms_out(A, Tb, S), ms_out_list(As, Tb, Ss).

attempt_dict(attempt(Id, material(S, P), material(PS, PP)),
             _{id: Id, have: _{sigs: S, preimages: P}, path: _{sigs: PS, preimages: PP}}).

%   On a private regtest the coins are buried under enough blocks for every
%   relative lock by blocks (up to 20000, a few minutes of mining).
max_older(Policy, Conf) :-
    findall(B, ( sub_policy(Policy, older(N)), ms_older_blocks(N, B), integer(B) ), Bs),
    ( Bs == [] -> Conf = 1 ; max_list(Bs, M), Conf is min(M, 20000) ).

sub_policy(P, P).
sub_policy(and(A, B), S) :- ( sub_policy(A, S) ; sub_policy(B, S) ).
sub_policy(or(A, B), S) :- ( sub_policy(A, S) ; sub_policy(B, S) ).
sub_policy(thresh(_, Ps), S) :- member(P, Ps), sub_policy(P, S).

%!  chain_record(+Id, +Network, -Record) is semidet.
chain_record(Id, Network, Record) :-
    runs_dir(RD),
    format(atom(File), '~w/~w.~w.json', [RD, Id, Network]),
    exists_file(File),
    setup_call_cleanup(open(File, read, S, [encoding(utf8)]), json_read_dict(S, Record), close(S)).

		 /*******************************
		 *     THE RUN AS SCENARIOS     *
		 *******************************/

%!  chain_tests(+Record, +Names-NamedSets, +Features, +Id, -TestsDocs) is det.
%
%   TestsDocs = Tests-document(Doc, Options)-RecordFile: one test per
%   attempt the chain judged — the witness's signatures and preimages, the
%   coin's block and the spending transaction's (the chain's next block),
%   its lock time — expecting what the chain said. The scenario cites the
%   run (its document is the recorded JSON, kept under sources/) at the
%   transaction, or at the refusal.
chain_tests(Record, Names-NamedSets, Fs, Id, Tests-document(Doc, [url(Url), text(Text)])-RecFile) :-
    atom_string(Date0, Record.date), sub_atom(Date0, 0, 10, _, Date),
    network_name(Record.network, Net),
    format(atom(Doc), 'the ~w run of ~w', [Net, Date]),
    (   sub_atom(Record.network, _, _, _, 'rewindbitcoin')
    ->  format(atom(Url), 'https://tape.rewindbitcoin.com/explorer/address/~w', [Record.address])
    ;   Url = none
    ),
    format(atom(RecFile), '~w.chain.json', [Id]),
    atomic_list_concat(['sources/', RecFile], Text),
    placeholders_of(Record, Names, PMap),
    findall(T, ( member(A, Record.attempts), A.verdict \== "not_attempted",
                 attempt_name(Record, NamedSets, A.id, Name),
                 attempt_test(A, Name, PMap, Fs, Doc, T) ), Tests).

%   The scenario name of a recorded attempt: the record's own id, which
%   names the rule the path satisfies — except in a run recorded before
%   attempts were named so (no attempt_names in the record), whose
%   `path_<i>` is the i-th minimal satisfying set: renamed after its rule,
%   so chain scenarios and satisfaction scenarios agree.
attempt_name(Record, NamedSets, Id0, Name) :-
    atom_string(Id, Id0),
    (   \+ get_dict(attempt_names, Record, _),
        atomic_list_concat([path, IA|Rest], '_', Id),
        atom_number(IA, I), integer(I),
        nth1(I, NamedSets, SetName-_)
    ->  (   Rest == [] -> Name = SetName
        ;   Rest = [without, JA] -> format(atom(Name), '~w_without_~w', [SetName, JA])
        ;   Name = Id
        )
    ;   Name = Id
    ).

network_name(N, 'Tape') :- sub_atom(N, _, _, _, rewindbitcoin), !.
network_name(_, regtest).

%   Placeholder -> the role's name in the twin (the record keeps the roles).
placeholders_of(Record, _Names, Map) :-
    dict_pairs(Record.roles, _, Ps),
    findall(P-C, ( member(P0-C0, Ps), atom_string(P, P0), atom_string(C, C0) ), Map).

attempt_test(A, Name, PMap, Fs, Doc, test(Tid, Doc, Loc, [comment(C)|Facts], [expects(spendable, Ans)])) :-
    atom_string(AId, A.id), format(atom(Tid), 'chain_~w', [Name]),
    Tip is A.tip + 1,
    (   A.coin_confirmed_at == null -> Conf = Tip ; Conf = A.coin_confirmed_at ),
    findall(sig(R), ( member(P, A.used.sigs), atom_string(PA, P), memberchk(PA-R, PMap) ), F1),
    findall(pre(R), ( member(P, A.used.preimages), atom_string(PA, P), memberchk(PA-R, PMap) ), F2),
    (   memberchk(older_blocks, Fs) -> F3 = [confirmed(Conf), spent_in(Tip)]
    ;   memberchk(after_height, Fs) -> F3 = [spent_in(Tip)]
    ;   F3 = []
    ),
    (   ( memberchk(older_time, Fs) ; memberchk(after_time, Fs) )
    ->  Now = A.tip_time,
        ( A.coin_confirmed_time == null -> CT = Now ; CT = A.coin_confirmed_time ),
        ( memberchk(older_time, Fs) -> F4 = [confirmed_at(CT), spent_at(Now)] ; F4 = [spent_at(Now)] )
    ;   F4 = []
    ),
    (   ( memberchk(after_height, Fs) ; memberchk(after_time, Fs) ) -> F5 = [locktime(A.nlocktime)] ; F5 = [] ),
    append([F1, F2, F3, F4, F5], Facts),
    (   A.verdict == "accepted"
    ->  Ans = [spendable],
        format(atom(Loc), 'transaction ~w', [A.txid]),
        format(string(C), "the chain accepted the spend: transaction ~w", [A.txid])
    ;   Ans = [],
        format(atom(Loc), 'the refusal of attempt ~w', [AId]),
        reason_words(A.reason, R),
        format(string(C), "the chain refused the spend: ~w", [R])
    ).

%   The node's reason, without the RPC framing and the transaction ids.
reason_words(Reason, Words) :-
    atom_string(Reason, S0),
    (   sub_string(S0, B, _, _, "error -26: ") -> B1 is B + 11, sub_string(S0, B1, _, 0, S1) ; S1 = S0 ),
    (   sub_string(S1, E, _, _, ", input ") -> sub_string(S1, 0, E, _, S2) ; S2 = S1 ),
    split_string(S2, "\n", " ", [S3|_]),
    Words = S3.
